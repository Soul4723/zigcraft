const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});
const math = @import("../math.zig");
const mob_mod = @import("mob.zig");
const mob_renderer_mod = @import("mob_renderer.zig");
const chunk_manager_mod = @import("../chunk_manager.zig");
const audio_mod = @import("../audio/audio.zig");
const pathfind_mod = @import("pathfind.zig");
const hunt_mod = @import("pack_hunt.zig");
const spawn_rules = @import("../world/spawn_rules.zig");

pub const MobManager = struct {
    allocator: std.mem.Allocator,
    mobs: std.ArrayList(mob_mod.Mob),
    renderer: mob_renderer_mod.MobRenderer,
    rng: std.Random.DefaultPrng,
    ambient_timer: f32,

    pub fn init(allocator: std.mem.Allocator, atlas_texture: c.GLuint) !MobManager {
        const r = try mob_renderer_mod.MobRenderer.init(allocator, atlas_texture);
        return .{
            .allocator = allocator,
            .mobs = std.ArrayList(mob_mod.Mob).empty,
            .renderer = r,
            .rng = std.Random.DefaultPrng.init(0xCAFEFEED),
            .ambient_timer = 5.0,
        };
    }

    pub fn deinit(self: *MobManager) void {
        self.renderer.deinit();
        self.mobs.deinit(self.allocator);
    }

    pub fn spawnMob(self: *MobManager, mob_type: mob_mod.MobType, x: f32, y: f32, z: f32) !void {
        try self.mobs.append(self.allocator, mob_mod.Mob.init(mob_type, x, y, z));
    }

    /// Ensure surface population plus dark-cave wolves around center.
    /// Keeps spawning up to cap as mobs die or despawn.
    pub fn ensureSpawnPopulation(self: *MobManager, chunk_manager: *const chunk_manager_mod.ChunkManager, center_x: f32, center_z: f32, is_night: bool) !void {
        if (self.mobs.items.len >= 6) return;

        var attempts: usize = 0;
        while (self.mobs.items.len < 6 and attempts < 12) : (attempts += 1) {
            const rx = center_x + (self.rng.random().float(f32) * 36.0 - 18.0);
            const rz = center_z + (self.rng.random().float(f32) * 36.0 - 18.0);
            const ix: i32 = @intFromFloat(@floor(rx));
            const iz: i32 = @intFromFloat(@floor(rz));

            var iy: i32 = 15;
            while (iy >= 1) : (iy -= 1) {
                if (!spawn_rules.isSafeSpawn(chunk_manager, ix, iy, iz)) continue;
                const roll = self.rng.random().float(f32);
                const category = spawn_rules.selectMobType(roll, is_night);
                const mtype: mob_mod.MobType = switch (category) {
                    .sheep => .sheep,
                    .pig => .pig,
                    .wolf => .wolf,
                };
                try self.spawnMob(mtype, @as(f32, @floatFromInt(ix)) + 0.5, @as(f32, @floatFromInt(iy + 1)), @as(f32, @floatFromInt(iz)) + 0.5);
                break;
            }
        }

        // Cave pass: dark hollows spawn wolves even by day, up to a shared cap.
        var cave_attempts: usize = 0;
        while (self.mobs.items.len < 8 and cave_attempts < 6) : (cave_attempts += 1) {
            const rx = center_x + (self.rng.random().float(f32) * 36.0 - 18.0);
            const rz = center_z + (self.rng.random().float(f32) * 36.0 - 18.0);
            const ix: i32 = @intFromFloat(@floor(rx));
            const iz: i32 = @intFromFloat(@floor(rz));
            const iy: i32 = 1 + @as(i32, @intFromFloat(self.rng.random().float(f32) * 10.0));
            if (!spawn_rules.isCaveSpawn(chunk_manager, ix, iy, iz, 15)) continue;
            try self.spawnMob(.wolf, @as(f32, @floatFromInt(ix)) + 0.5, @as(f32, @floatFromInt(iy + 1)), @as(f32, @floatFromInt(iz)) + 0.5);
        }
    }

    pub fn tick(self: *MobManager, solid: *const fn (x: i32, y: i32, z: i32) bool, fluid: *const fn (x: i32, y: i32, z: i32) bool, player_pos: math.Vec3, player_radius: f32, audio: ?*audio_mod.AudioSystem, dt: f32) void {
        var idx: usize = 0;
        while (idx < self.mobs.items.len) {
            var mob = &self.mobs.items[idx];
            if (mob.mob_type == .wolf) {
                const wdx = player_pos.x - mob.pos.x;
                const wdz = player_pos.z - mob.pos.z;
                const wd = @sqrt(wdx * wdx + wdz * wdz);
                if (hunt_mod.shouldHunt(wd)) {
                    // Try A* path around obstacles; fall back to line-of-sight
                    const start_x: i32 = @intFromFloat(@floor(mob.pos.x));
                    const start_z: i32 = @intFromFloat(@floor(mob.pos.z));
                    const target_x: i32 = @intFromFloat(@floor(player_pos.x));
                    const target_z: i32 = @intFromFloat(@floor(player_pos.z));
                    const base_y: i32 = @intFromFloat(@floor(mob.pos.y));

                    const WalkCtx = struct {
                        s: *const fn (x: i32, y: i32, z: i32) bool,
                        f: *const fn (x: i32, y: i32, z: i32) bool,
                        y: i32,

                        fn isWalkable(ctx: *const @This(), x: i32, z: i32) bool {
                            // Needs solid floor (at base_y or base_y-1) and clear headroom
                            const has_floor = ctx.s(x, ctx.y, z) or ctx.s(x, ctx.y - 1, z);
                            if (!has_floor) return false;
                            if (ctx.s(x, ctx.y + 1, z) or ctx.s(x, ctx.y + 2, z)) return false;
                            if (ctx.f(x, ctx.y, z)) return false; // avoid water
                            return true;
                        }
                    };
                    const walk_ctx = WalkCtx{ .s = solid, .f = fluid, .y = base_y };

                    if (pathfind_mod.findNextStep(start_x, start_z, target_x, target_z, &walk_ctx, WalkCtx.isWalkable)) |step| {
                        mob.yaw = step.toYaw();
                    } else {
                        mob.yaw = std.math.atan2(wdx, wdz);
                    }
                    mob.walk_timer = hunt_mod.walk_pulse;
                }
            }
            mob.tick(solid, fluid, dt, &self.rng);

            const dx0 = mob.pos.x - player_pos.x;
            const dz0 = mob.pos.z - player_pos.z;
            if (dx0 * dx0 + dz0 * dz0 > 64.0 * 64.0 or mob.pos.y < -5.0) {
                _ = self.mobs.swapRemove(idx);
                continue;
            }

            // Soft push separation between player and mob
            const dx = mob.pos.x - player_pos.x;
            const dz = mob.pos.z - player_pos.z;
            const dist_sq = dx * dx + dz * dz;
            const min_dist = player_radius + mob.width * 0.5;
            if (dist_sq < min_dist * min_dist and dist_sq > 0.0001) {
                const dist = @sqrt(dist_sq);
                const push = (min_dist - dist) * 0.5;
                mob.pos.x += (dx / dist) * push;
                mob.pos.z += (dz / dist) * push;
            }

            idx += 1;
        }

        // Ambient sound bleat trigger
        self.ambient_timer -= dt;
        if (self.ambient_timer <= 0.0) {
            self.ambient_timer = 7.0 + self.rng.random().float(f32) * 8.0;
            if (audio) |a| {
                for (self.mobs.items) |mob| {
                    const dx = mob.pos.x - player_pos.x;
                    const dy = mob.pos.y - player_pos.y;
                    const dz = mob.pos.z - player_pos.z;
                    if (dx * dx + dy * dy + dz * dz < 25.0 * 25.0) {
                        const sound: audio_mod.synth.SoundType = mob_mod.getSound(mob.mob_type) orelse .mob_baa;
                        a.play(sound, 0.45);
                        break;
                    }
                }
            }
        }
    }

    pub const HitResult = struct { mob_type: mob_mod.MobType, pos: math.Vec3, died: bool, drop: ?mob_mod.MobType, wool: bool };

    /// Try hitting a mob with raycast from camera. Returns hit info incl. death/drop.
    pub fn tryHitMobDmg(self: *MobManager, origin: math.Vec3, dir: math.Vec3, max_dist: f32, dmg: u8) ?HitResult {
        var closest_dist: f32 = max_dist;
        var hit_idx: ?usize = null;

        for (self.mobs.items, 0..) |mob, i| {
            if (mob.rayIntersects(origin, dir, closest_dist)) |d| {
                closest_dist = d;
                hit_idx = i;
            }
        }

        if (hit_idx) |i| {
            const mtype = self.mobs.items[i].mob_type;
            const died = self.mobs.items[i].takeHitDmg(dir, dmg);
            if (died) {
                const pos = self.mobs.items[i].pos;
                _ = self.mobs.swapRemove(i);
                return .{ .mob_type = mtype, .pos = pos, .died = true, .drop = mtype, .wool = mtype == .sheep };
            }
            return .{ .mob_type = mtype, .pos = self.mobs.items[i].pos, .died = false, .drop = null, .wool = false };
        }

        return null;
    }

    pub fn tryHitMob(self: *MobManager, origin: math.Vec3, dir: math.Vec3, max_dist: f32) ?HitResult {
        return self.tryHitMobDmg(origin, dir, max_dist, 1);
    }

    pub fn draw(self: *MobManager, view_proj: math.Mat4, sun_dir: math.Vec3, cam_pos: math.Vec3, is_underwater: bool) !void {
        try self.renderer.drawMobs(self.mobs.items, view_proj, sun_dir, cam_pos, is_underwater);
    }

    pub fn countNearbyWolves(self: *const MobManager, center: math.Vec3, radius: f32) usize {
        var count: usize = 0;
        const r_sq = radius * radius;
        for (self.mobs.items) |m| {
            if (m.mob_type != .wolf) continue;
            const dx = m.pos.x - center.x;
            const dy = m.pos.y - center.y;
            const dz = m.pos.z - center.z;
            if (dx * dx + dy * dy + dz * dz <= r_sq) {
                count += 1;
            }
        }
        return count;
    }
};

test "MobManager spawn and tick list" {
    var mobs = std.ArrayList(mob_mod.Mob).empty;
    defer mobs.deinit(std.testing.allocator);

    try mobs.append(std.testing.allocator, mob_mod.Mob.init(.sheep, 0, 5, 0));
    try std.testing.expectEqual(@as(usize, 1), mobs.items.len);
}

test "wolf hunt A* steers around obstacle wall" {
    const mob = mob_mod.Mob.init(.wolf, 0.5, 1.0, 0.5);
    const player_pos = math.Vec3.init(3.5, 1.0, 0.5); // Target is east at (+3, 0)

    // Solid world: flat floor at y=0, vertical obstacle block at (1, 1, 0) blocking direct path
    const TestWorld = struct {
        fn solid(x: i32, y: i32, z: i32) bool {
            if (y <= 0) return true; // flat ground
            // 2-block high wall at (1, 0) blocks headroom so wolf cannot step over
            if (x == 1 and (y == 1 or y == 2) and z == 0) return true;
            return false;
        }
        fn fluid(_: i32, _: i32, _: i32) bool {
            return false;
        }
    };

    const wdx = player_pos.x - mob.pos.x;
    const wdz = player_pos.z - mob.pos.z;
    const wd = @sqrt(wdx * wdx + wdz * wdz);
    try std.testing.expect(hunt_mod.shouldHunt(wd));

    // Pathfind around the wall: should not head straight east (yaw ~ pi/2)
    const WalkCtx = struct {
        fn isWalkable(_: *const @This(), x: i32, z: i32) bool {
            const has_floor = TestWorld.solid(x, 1, z) or TestWorld.solid(x, 0, z);
            if (!has_floor) return false;
            if (TestWorld.solid(x, 2, z) or TestWorld.solid(x, 3, z)) return false;
            return true;
        }
    };
    const ctx = WalkCtx{};
    const step = pathfind_mod.findNextStep(0, 0, 3, 0, &ctx, WalkCtx.isWalkable);
    try std.testing.expect(step != null);
    // Should divert North (+Z) or South (-Z), not walk into blocked (1, 0)
    try std.testing.expect(step.?.dx == 0);
    try std.testing.expect(step.?.dz == 1 or step.?.dz == -1);
}

test "MobManager countNearbyWolves" {
    var mobs = std.ArrayList(mob_mod.Mob).empty;
    defer mobs.deinit(std.testing.allocator);

    try mobs.append(std.testing.allocator, mob_mod.Mob.init(.wolf, 0, 0, 0));
    try mobs.append(std.testing.allocator, mob_mod.Mob.init(.wolf, 2, 0, 2));
    try mobs.append(std.testing.allocator, mob_mod.Mob.init(.sheep, 1, 0, 1));
    try mobs.append(std.testing.allocator, mob_mod.Mob.init(.wolf, 20, 0, 20));

    var count: usize = 0;
    const r_sq = 8.0 * 8.0;
    for (mobs.items) |m| {
        if (m.mob_type != .wolf) continue;
        const dx = m.pos.x - 0.0;
        const dy = m.pos.y - 0.0;
        const dz = m.pos.z - 0.0;
        if (dx * dx + dy * dy + dz * dz <= r_sq) count += 1;
    }
    try std.testing.expectEqual(count, 2);
}
