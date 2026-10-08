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

    /// Ensure initial population of sheep/pigs on surface land around center.
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
                    mob.yaw = std.math.atan2(wdx, wdz);
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

    pub fn draw(self: *MobManager, view_proj: math.Mat4, sun_dir: math.Vec3) !void {
        try self.renderer.drawMobs(self.mobs.items, view_proj, sun_dir);
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
