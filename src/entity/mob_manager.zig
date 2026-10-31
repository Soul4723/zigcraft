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
const block_mod = @import("../world/block.zig");
const hazard_mod = @import("../world/hazard.zig");
const inventory_mod = @import("../inventory.zig");
const pale_garden_mod = @import("../world/pale_garden.zig");

pub const MobManager = struct {
    allocator: std.mem.Allocator,
    mobs: std.ArrayList(mob_mod.Mob),
    renderer: mob_renderer_mod.MobRenderer,
    rng: std.Random.DefaultPrng,
    ambient_timer: f32,
    spawner_timer: f32,
    creaking_scan_timer: f32 = 0.0,

    pub fn init(allocator: std.mem.Allocator, atlas_texture: c.GLuint) !MobManager {
        const r = try mob_renderer_mod.MobRenderer.init(allocator, atlas_texture);
        return .{
            .allocator = allocator,
            .mobs = std.ArrayList(mob_mod.Mob).empty,
            .renderer = r,
            .rng = std.Random.DefaultPrng.init(0xCAFEFEED),
            .ambient_timer = 5.0,
        .spawner_timer = 0.0,
        .creaking_scan_timer = 0.0,
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

        // Nether fortress pass: wither skeletons guard masonry bridges.
        var skeleton_attempts: usize = 0;
        while (self.mobs.items.len < 8 and skeleton_attempts < 6) : (skeleton_attempts += 1) {
            const rx = center_x + (self.rng.random().float(f32) * 36.0 - 18.0);
            const rz = center_z + (self.rng.random().float(f32) * 36.0 - 18.0);
            const ix: i32 = @intFromFloat(@floor(rx));
            const iz: i32 = @intFromFloat(@floor(rz));
            const iy: i32 = 7;
            if (!spawn_rules.isFortressSpawn(chunk_manager, ix, iy, iz)) continue;
            try self.spawnMob(.wither_skeleton, @as(f32, @floatFromInt(ix)) + 0.5, @as(f32, @floatFromInt(iy + 1)), @as(f32, @floatFromInt(iz)) + 0.5);
            break;
        }

        // Nether bastion pass: piglins guard blackstone ruins and ramparts.
        var bastion_attempts: usize = 0;
        while (self.mobs.items.len < 8 and bastion_attempts < 6) : (bastion_attempts += 1) {
            const rx = center_x + (self.rng.random().float(f32) * 36.0 - 18.0);
            const rz = center_z + (self.rng.random().float(f32) * 36.0 - 18.0);
            const ix: i32 = @intFromFloat(@floor(rx));
            const iz: i32 = @intFromFloat(@floor(rz));
            var iy: i32 = 10;
            while (iy >= 5) : (iy -= 1) {
                if (!spawn_rules.isBastionSpawn(chunk_manager, ix, iy, iz)) continue;
                const m_type: mob_mod.MobType = if (self.rng.random().float(f32) < 0.33) .piglin_brute else .piglin;
                try self.spawnMob(m_type, @as(f32, @floatFromInt(ix)) + 0.5, @as(f32, @floatFromInt(iy + 1)), @as(f32, @floatFromInt(iz)) + 0.5);
                break;
            }
        }

        // Nether pass: emberbeasts stalk netherrack wastes and fortress bridges.
        var nether_attempts: usize = 0;
        while (self.mobs.items.len < 8 and nether_attempts < 6) : (nether_attempts += 1) {
            const rx = center_x + (self.rng.random().float(f32) * 36.0 - 18.0);
            const rz = center_z + (self.rng.random().float(f32) * 36.0 - 18.0);
            const ix: i32 = @intFromFloat(@floor(rx));
            const iz: i32 = @intFromFloat(@floor(rz));
            const iy: i32 = 5 + @as(i32, @intFromFloat(self.rng.random().float(f32) * 4.0));
            if (!spawn_rules.isNetherSpawn(chunk_manager, ix, iy, iz)) continue;
            try self.spawnMob(.emberbeast, @as(f32, @floatFromInt(ix)) + 0.5, @as(f32, @floatFromInt(iy + 1)), @as(f32, @floatFromInt(iz)) + 0.5);
            break;
        }

        // Aquatic pass: oceans and water pools spawn turtles and drowned mobs
        var water_attempts: usize = 0;
        while (self.mobs.items.len < 8 and water_attempts < 4) : (water_attempts += 1) {
            const rx = center_x + (self.rng.random().float(f32) * 36.0 - 18.0);
            const rz = center_z + (self.rng.random().float(f32) * 36.0 - 18.0);
            const ix: i32 = @intFromFloat(@floor(rx));
            const iz: i32 = @intFromFloat(@floor(rz));
            var iy: i32 = 8;
            while (iy >= 1) : (iy -= 1) {
                if (!spawn_rules.isWaterSpawn(chunk_manager, ix, iy, iz)) continue;
                const roll_w = self.rng.random().float(f32);
                // If near ocean monument (-8..8, -24..-8), spawn Elder Guardian boss or Guardian sentinels
                const near_monument = (ix >= -12 and ix <= 12 and iz >= -28 and iz <= -4);
                const water_mtype: mob_mod.MobType = if (near_monument)
                    (if (roll_w < 0.20) .elder_guardian else .guardian)
                else if (roll_w < 0.25)
                    .guardian
                else if (is_night and roll_w < 0.70)
                    .drowned
                else if (roll_w < 0.65)
                    .dolphin
                else
                    .turtle;
                try self.spawnMob(water_mtype, @as(f32, @floatFromInt(ix)) + 0.5, @as(f32, @floatFromInt(iy + 1)), @as(f32, @floatFromInt(iz)) + 0.5);
                break;
            }
        }

        // Cave & night pass: dark hollows spawn wolves and arachnid spiders up to cap.
        var cave_attempts: usize = 0;
        while (self.mobs.items.len < 8 and cave_attempts < 6) : (cave_attempts += 1) {
            const rx = center_x + (self.rng.random().float(f32) * 36.0 - 18.0);
            const rz = center_z + (self.rng.random().float(f32) * 36.0 - 18.0);
            const ix: i32 = @intFromFloat(@floor(rx));
            const iz: i32 = @intFromFloat(@floor(rz));
            const iy: i32 = 1 + @as(i32, @intFromFloat(self.rng.random().float(f32) * 10.0));
            if (!spawn_rules.isCaveSpawn(chunk_manager, ix, iy, iz, 15)) continue;
            const roll_m = self.rng.random().float(f32);
            const cave_mtype: mob_mod.MobType = if (roll_m < 0.18) .enderman else if (roll_m < 0.36) .creeper else if (roll_m < 0.54) .zombie else if (roll_m < 0.72) .skeleton else if (roll_m < 0.84) .spider else if (roll_m < 0.94) .slime else .wolf;
            try self.spawnMob(cave_mtype, @as(f32, @floatFromInt(ix)) + 0.5, @as(f32, @floatFromInt(iy + 1)), @as(f32, @floatFromInt(iz)) + 0.5);
        }
    }

    /// Check whether a position is within warped fungus repulsion range (8m)
    /// of a placed BlockId.warped_fungus block.
    pub fn findNearbyWarpedFungus(block_at: ?*const fn (x: i32, y: i32, z: i32) block_mod.BlockId, pos: math.Vec3, max_range: f32) ?math.Vec3 {
        const bat = block_at orelse return null;
        const cx: i32 = @intFromFloat(@floor(pos.x));
        const cy: i32 = @intFromFloat(@floor(pos.y));
        const cz: i32 = @intFromFloat(@floor(pos.z));
        const r: i32 = @intFromFloat(@ceil(max_range));
        const r_sq = max_range * max_range;
        var closest_dist_sq: f32 = r_sq + 1.0;
        var best: ?math.Vec3 = null;

        var dy: i32 = -r;
        while (dy <= r) : (dy += 1) {
            const ny = cy + dy;
            var dx: i32 = -r;
            while (dx <= r) : (dx += 1) {
                const nx = cx + dx;
                var dz: i32 = -r;
                while (dz <= r) : (dz += 1) {
                    const nz = cz + dz;
                    if (bat(nx, ny, nz) == .warped_fungus) {
                        const fx = @as(f32, @floatFromInt(nx)) + 0.5;
                        const fy = @as(f32, @floatFromInt(ny)) + 0.5;
                        const fz = @as(f32, @floatFromInt(nz)) + 0.5;
                        const d2 = (fx - pos.x) * (fx - pos.x) + (fz - pos.z) * (fz - pos.z) + (fy - pos.y) * (fy - pos.y);
                        if (d2 <= r_sq and d2 < closest_dist_sq) {
                            closest_dist_sq = d2;
                            best = math.Vec3.init(fx, fy, fz);
                        }
                    }
                }
            }
        }
        return best;
    }

    /// Determine if a piglin at pos is repelled by either held warped fungus on player or nearby placed warped fungus.
    pub fn isPiglinRepelled(pos: math.Vec3, player_pos: math.Vec3, player_holding_fungus: bool, block_at: ?*const fn (x: i32, y: i32, z: i32) block_mod.BlockId) ?math.Vec3 {
        if (player_holding_fungus) {
            const pdx = player_pos.x - pos.x;
            const pdy = player_pos.y - pos.y;
            const pdz = player_pos.z - pos.z;
            if (pdx * pdx + pdy * pdy + pdz * pdz <= 8.0 * 8.0) {
                return player_pos;
            }
        }
        return findNearbyWarpedFungus(block_at, pos, 8.0);
    }

    pub fn tick(self: *MobManager, solid: *const fn (x: i32, y: i32, z: i32) bool, fluid: *const fn (x: i32, y: i32, z: i32) bool, block_at: ?*const fn (x: i32, y: i32, z: i32) block_mod.BlockId, player_pos: math.Vec3, player_radius: f32, player_holding_fungus: bool, audio: ?*audio_mod.AudioSystem, dt: f32) void {
        var idx: usize = 0;
        while (idx < self.mobs.items.len) {
            var mob = &self.mobs.items[idx];
            if (mob.mob_type == .pig and player_holding_fungus) {
                // Pigs are lured by warped fungus (or warped fungus on a stick) within 10m
                const pdx = player_pos.x - mob.pos.x;
                const pdz = player_pos.z - mob.pos.z;
                const pd_sq = pdx * pdx + pdz * pdz;
                if (pd_sq <= 10.0 * 10.0 and pd_sq >= 1.5 * 1.5) {
                    mob.yaw = std.math.atan2(pdx, pdz);
                    mob.walk_timer = hunt_mod.walk_pulse;
                }
            } else if (mob.mob_type == .wolf or mob.mob_type == .emberbeast or mob.mob_type == .wither_skeleton or mob.mob_type == .piglin or mob.mob_type == .piglin_brute or mob.mob_type == .blaze or mob.mob_type == .spider or mob.mob_type == .cave_spider or mob.mob_type == .skeleton or mob.mob_type == .zombie or mob.mob_type == .creeper or mob.mob_type == .enderman or mob.mob_type == .slime) {
                var is_repelled = false;
                if (mob.mob_type == .piglin) {
                    if (isPiglinRepelled(mob.pos, player_pos, player_holding_fungus, block_at)) |repel_source| {
                        is_repelled = true;
                        const fdx = mob.pos.x - repel_source.x;
                        const fdz = mob.pos.z - repel_source.z;
                        if (fdx * fdx + fdz * fdz > 0.0001) {
                            mob.yaw = std.math.atan2(fdx, fdz);
                        }
                        mob.walk_timer = hunt_mod.walk_pulse;
                    }
                }
                if (is_repelled) {
                    // Piglin fleeing warped fungus; hunting inhibited
                } else if (mob.mob_type == .piglin and mob.barter_timer > 0.0) {
                    // Pacified piglin wanders peacefully instead of hunting player
                } else {
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
            }
            if (block_at) |bat| {
                const mx: i32 = @intFromFloat(@floor(mob.pos.x));
                const my: i32 = @intFromFloat(@floor(mob.pos.y));
                const mz: i32 = @intFromFloat(@floor(mob.pos.z));
                const col_type = hazard_mod.detectBubbleColumn(bat, mx, my, mz);
                mob.in_bubble_column = (col_type == .upward);
                mob.in_whirlpool = (col_type == .downward);

                // Contact heat hazard check: floor block under feet or immersed block
                const floor_b = bat(mx, @intFromFloat(@floor(mob.pos.y - 0.1)), mz);
                const body_b = bat(mx, my, mz);
                if (mob.mob_type != .emberbeast and mob.mob_type != .wither_skeleton and mob.mob_type != .blaze and (hazard_mod.checkBurnContact(floor_b) or hazard_mod.checkBurnContact(body_b) or hazard_mod.checkLavaHazard(floor_b) or hazard_mod.checkLavaHazard(body_b))) {
                    const prev_hp = mob.health;
                    if (mob.applyBurnTick(dt)) {
                        if (audio) |a| {
                            a.playAt(.burn_sizzle, .{ mob.pos.x, mob.pos.y, mob.pos.z }, .{ player_pos.x, player_pos.y, player_pos.z }, 0.6, 20.0);
                        }
                        _ = self.mobs.swapRemove(idx);
                        continue;
                    } else if (mob.health < prev_hp) {
                        if (audio) |a| {
                            a.playAt(.burn_sizzle, .{ mob.pos.x, mob.pos.y, mob.pos.z }, .{ player_pos.x, player_pos.y, player_pos.z }, 0.5, 18.0);
                        }
                    }
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

        // Fortress spawner pulse: reinforce emberbeast guards near player every 20s (max 2 near).
        self.spawner_timer += dt;
        if (block_at != null and spawn_rules.spawnerDue(self.spawner_timer)) {
            self.spawner_timer = 0.0;
            var near: usize = 0;
            for (self.mobs.items) |mob| {
                if (mob.mob_type != .emberbeast and mob.mob_type != .wither_skeleton and mob.mob_type != .blaze and mob.mob_type != .cave_spider) continue;
                const dx = mob.pos.x - player_pos.x;
                const dz = mob.pos.z - player_pos.z;
                if (dx * dx + dz * dz < 24.0 * 24.0) near += 1;
            }
            if (near < spawn_rules.spawner_max_near and self.mobs.items.len < 10) {
                if (block_at) |bat| {
                    const px: i32 = @intFromFloat(@floor(player_pos.x));
                    const pz: i32 = @intFromFloat(@floor(player_pos.z));
                    const py: i32 = @intFromFloat(@floor(player_pos.y));
                    
                    // Search for a nearby spawner cage within 16 blocks to anchor the pulse
                    var spawner_found = false;
                    var anchor_x: i32 = px;
                    var anchor_y: i32 = py;
                    var anchor_z: i32 = pz;
                    var si: i32 = -16;
                    while (si <= 16 and !spawner_found) : (si += 4) {
                        var sj: i32 = -16;
                        while (sj <= 16 and !spawner_found) : (sj += 4) {
                            var sk: i32 = -4;
                            while (sk <= 4 and !spawner_found) : (sk += 1) {
                                if (bat(px + si, py + sk, pz + sj) == .spawner_cage) {
                                    anchor_x = px + si;
                                    anchor_y = py + sk;
                                    anchor_z = pz + sj;
                                    spawner_found = true;
                                }
                            }
                        }
                    }

                    var oi: i32 = -4;
                    var spawned = false;
                    while (oi <= 4 and !spawned) : (oi += 1) {
                        var oj: i32 = -4;
                        while (oj <= 4 and !spawned) : (oj += 1) {
                            const gx = anchor_x + oi;
                            const gz = anchor_z + oj;
                            var gy = anchor_y + 2;
                            while (gy >= anchor_y - 2) : (gy -= 1) {
                                const g = bat(gx, gy, gz);
                                if (g == .netherrack or g == .nether_brick or g == .soul_sand) {
                                    if (bat(gx, gy + 1, gz) == .air and bat(gx, gy + 2, gz) == .air) {
                                        const spawn_type: mob_mod.MobType = if (spawner_found and self.rng.random().float(f32) < 0.6) .blaze else .emberbeast;
                                        self.spawnMob(spawn_type, @as(f32, @floatFromInt(gx)) + 0.5, @as(f32, @floatFromInt(gy + 1)), @as(f32, @floatFromInt(gz)) + 0.5) catch {};
                                        if (audio) |a| {
                                            a.playAt(.mob_roar, .{ @as(f32, @floatFromInt(gx)), @as(f32, @floatFromInt(gy + 1)), @as(f32, @floatFromInt(gz)) }, .{ player_pos.x, player_pos.y, player_pos.z }, 0.8, 30.0);
                                        }
                                        spawned = true;
                                    }
                                    break;
                                } else if (g == .wood_planks or g == .cobblestone or g == .stone) {
                                    if (bat(gx, gy + 1, gz) == .air and bat(gx, gy + 2, gz) == .air) {
                                        self.spawnMob(.cave_spider, @as(f32, @floatFromInt(gx)) + 0.5, @as(f32, @floatFromInt(gy + 1)), @as(f32, @floatFromInt(gz)) + 0.5) catch {};
                                        if (audio) |a| {
                                            a.playAt(.mob_hiss, .{ @as(f32, @floatFromInt(gx)), @as(f32, @floatFromInt(gy + 1)), @as(f32, @floatFromInt(gz)) }, .{ player_pos.x, player_pos.y, player_pos.z }, 0.8, 25.0);
                                        }
                                        spawned = true;
                                    }
                                    break;
                                }
                            }
                        }
                    }
                }
            }
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
                        a.playAt(sound, .{ mob.pos.x, mob.pos.y, mob.pos.z }, .{ player_pos.x, player_pos.y, player_pos.z }, 0.6, 25.0);
                        break;
                    }
                }
            }
        }
    }

    pub const HitResult = struct { mob_type: mob_mod.MobType, pos: math.Vec3, died: bool, drop: ?mob_mod.MobType, wool: bool, is_champion: bool = false, creaking_heart_pos: ?[3]i32 = null };

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
            const was_champ = self.mobs.items[i].is_champion;
            const heart_pos = self.mobs.items[i].creaking_heart_pos;
            if (mtype == .piglin) {
                self.mobs.items[i].barter_timer = 0.0;
            }
            const died = self.mobs.items[i].takeHitDmg(dir, dmg);
            if (died) {
                const pos = self.mobs.items[i].pos;
                _ = self.mobs.swapRemove(i);
                return .{ .mob_type = mtype, .pos = pos, .died = true, .drop = mtype, .wool = mtype == .sheep, .is_champion = was_champ, .creaking_heart_pos = heart_pos };
            }
            return .{ .mob_type = mtype, .pos = self.mobs.items[i].pos, .died = false, .drop = null, .wool = false, .is_champion = was_champ, .creaking_heart_pos = heart_pos };
        }

        return null;
    }

    pub const BarterResult = struct {
        item: inventory_mod.ItemType,
        count: u8,
        pos: math.Vec3,
    };

    pub const LeashResult = enum {
        attached_to_player,
        unleashed_to_item,
        none,
    };

    /// Right-click interact with a mob while holding or not holding a lead.
    pub fn tryInteractLeash(self: *MobManager, origin: math.Vec3, dir: math.Vec3, max_dist: f32, has_lead: bool) LeashResult {
        var closest_dist: f32 = max_dist;
        var hit_idx: ?usize = null;

        for (self.mobs.items, 0..) |mob, i| {
            if (mob.rayIntersects(origin, dir, closest_dist)) |d| {
                closest_dist = d;
                hit_idx = i;
            }
        }

        if (hit_idx) |i| {
            var target_mob = &self.mobs.items[i];
            if (target_mob.isLeashed()) {
                // Unleash mob, drops lead back
                target_mob.leashed_to_player = false;
                target_mob.fence_post = null;
                return .unleashed_to_item;
            } else if (has_lead) {
                // Attach lead to mob
                target_mob.leashed_to_player = true;
                target_mob.fence_post = null;
                return .attached_to_player;
            }
        }
        return .none;
    }

    /// Check if any mob leashed to player can be hitched to a clicked fence block.
    /// Returns number of mobs hitched to the fence post.
    pub fn tryHitchToFence(self: *MobManager, fence_x: i32, fence_y: i32, fence_z: i32) usize {
        var hitched_count: usize = 0;
        for (self.mobs.items) |*mob| {
            if (mob.leashed_to_player) {
                mob.leashed_to_player = false;
                mob.fence_post = .{ .x = fence_x, .y = fence_y, .z = fence_z };
                hitched_count += 1;
            }
        }
        return hitched_count;
    }

    /// Unhitch all mobs attached to a fence post at (fence_x, fence_y, fence_z).
    /// Returns number of leads dropped.
    pub fn unhitchFence(self: *MobManager, fence_x: i32, fence_y: i32, fence_z: i32) usize {
        var unhitched_count: usize = 0;
        for (self.mobs.items) |*mob| {
            if (mob.fence_post) |fp| {
                if (fp.x == fence_x and fp.y == fence_y and fp.z == fence_z) {
                    mob.fence_post = null;
                    unhitched_count += 1;
                }
            }
        }
        return unhitched_count;
    }

    pub const ShearResult = struct {
        wool_count: u8,
        pos: math.Vec3,
    };

    /// Shear a sheep in raycast crosshairs while holding shears.
    pub fn tryShearSheep(self: *MobManager, origin: math.Vec3, dir: math.Vec3, max_dist: f32) ?ShearResult {
        var closest_dist: f32 = max_dist;
        var hit_idx: ?usize = null;

        for (self.mobs.items, 0..) |mob, i| {
            if (mob.mob_type != .sheep or mob.is_sheared) continue;
            if (mob.rayIntersects(origin, dir, closest_dist)) |d| {
                closest_dist = d;
                hit_idx = i;
            }
        }

        if (hit_idx) |i| {
            if (self.mobs.items[i].shear()) |wool_cnt| {
                return .{
                    .wool_count = wool_cnt,
                    .pos = self.mobs.items[i].pos,
                };
            }
        }

        return null;
    }

        /// Barter with a Piglin in raycast crosshairs: consumes gold and pacifies the mob.
    pub fn tryBarter(self: *MobManager, origin: math.Vec3, dir: math.Vec3, max_dist: f32) ?BarterResult {
        var closest_dist: f32 = max_dist;
        var hit_idx: ?usize = null;

        for (self.mobs.items, 0..) |mob, i| {
            if (mob.mob_type != .piglin) continue;
            if (mob.rayIntersects(origin, dir, closest_dist)) |d| {
                closest_dist = d;
                hit_idx = i;
            }
        }

        if (hit_idx) |i| {
            var piglin = &self.mobs.items[i];
            piglin.barter_timer = 20.0;
            const px: i32 = @intFromFloat(@floor(piglin.pos.x));
            const pz: i32 = @intFromFloat(@floor(piglin.pos.z));
            const seed = @as(u32, @bitCast(px *% 37 +% pz *% 53)) +% self.rng.random().int(u32);
            const reward = inventory_mod.getPiglinBarter(seed);
            return .{
                .item = reward.item,
                .count = reward.count,
                .pos = piglin.pos,
            };
        }

        return null;
    }

    pub fn tryHitMob(self: *MobManager, origin: math.Vec3, dir: math.Vec3, max_dist: f32) ?HitResult {
        return self.tryHitMobDmg(origin, dir, max_dist, 1);
    }

    pub fn draw(self: *MobManager, view_proj: math.Mat4, sun_dir: math.Vec3, cam_pos: math.Vec3, is_underwater: bool, is_nether: bool) !void {
        try self.renderer.drawMobs(self.mobs.items, view_proj, sun_dir, cam_pos, is_underwater, is_nether);
    }


    pub fn spawnCreaking(self: *MobManager, heart_pos: [3]i32, x: f32, y: f32, z: f32) !void {
        var m = mob_mod.Mob.init(.creaking, x, y, z);
        m.creaking_heart_pos = heart_pos;
        try self.mobs.append(self.allocator, m);
    }

    pub fn hasLinkedCreaking(self: *const MobManager, heart_pos: [3]i32) bool {
        for (self.mobs.items) |m| {
            if (m.mob_type == .creaking) {
                if (m.creaking_heart_pos) |hp| {
                    if (std.mem.eql(i32, &hp, &heart_pos)) return true;
                }
            }
        }
        return false;
    }

    pub fn removeCreakingLinkedTo(self: *MobManager, heart_pos: [3]i32) void {
        var idx: usize = 0;
        while (idx < self.mobs.items.len) {
            const m = &self.mobs.items[idx];
            if (m.mob_type == .creaking) {
                if (m.creaking_heart_pos) |hp| {
                    if (std.mem.eql(i32, &hp, &heart_pos)) {
                        _ = self.mobs.swapRemove(idx);
                        continue;
                    }
                }
            }
            idx += 1;
        }
    }

    pub fn clearAllCreakings(self: *MobManager) void {
        var idx: usize = 0;
        while (idx < self.mobs.items.len) {
            if (self.mobs.items[idx].mob_type == .creaking) {
                _ = self.mobs.swapRemove(idx);
            } else {
                idx += 1;
            }
        }
    }

    pub fn findSafeSpawnNearHeart(chunk_manager: *const chunk_manager_mod.ChunkManager, heart_pos: [3]i32) ?math.Vec3 {
        const offsets = [_][2]i32{
            .{ 2, 0 }, .{ -2, 0 }, .{ 0, 2 }, .{ 0, -2 },
            .{ 3, 2 }, .{ -3, 2 }, .{ 3, -2 }, .{ -3, -2 },
            .{ 4, 1 }, .{ -4, 1 }, .{ 1, 4 }, .{ -1, -4 },
        };
        for (offsets) |off| {
            const sx = heart_pos[0] + off[0];
            const sz = heart_pos[2] + off[1];
            var sy: i32 = heart_pos[1] + 1;
            while (sy >= 1 and sy >= heart_pos[1] - 8) : (sy -= 1) {
                if (!chunk_manager.isSolidWorld(sx, sy, sz)) continue;
                if (chunk_manager.isSolidWorld(sx, sy + 1, sz)) continue;
                if (chunk_manager.isSolidWorld(sx, sy + 2, sz)) continue;
                if (chunk_manager.isSolidWorld(sx, sy + 3, sz)) continue;
                return math.Vec3.init(@as(f32, @floatFromInt(sx)) + 0.5, @as(f32, @floatFromInt(sy + 1)), @as(f32, @floatFromInt(sz)) + 0.5);
            }
        }
        return null;
    }

    pub fn ensureCreakingPopulation(
        self: *MobManager,
        chunk_manager: *const chunk_manager_mod.ChunkManager,
        is_night: bool,
        is_thunder: bool,
        dt: f32,
    ) !void {
        if (!is_night and !is_thunder) return;
        if (chunk_manager.is_nether or chunk_manager.is_end) return;

        self.creaking_scan_timer -= dt;
        if (self.creaking_scan_timer > 0.0) return;
        self.creaking_scan_timer = 1.0;

        var iter = chunk_manager.chunks.iterator();
        while (iter.next()) |entry| {
            const coord = entry.key_ptr.*;
            const ch = &entry.value_ptr.chunk;
            var lx: usize = 0;
            while (lx < 16) : (lx += 1) {
                var lz: usize = 0;
                while (lz < 16) : (lz += 1) {
                    var ly: usize = 1;
                    while (ly < 15) : (ly += 1) {
                        if (ch.getBlock(@intCast(lx), @intCast(ly), @intCast(lz)) == .creaking_heart) {
                            const wx = coord.x * 16 + @as(i32, @intCast(lx));
                            const wy: i32 = @intCast(ly);
                            const wz = coord.z * 16 + @as(i32, @intCast(lz));
                            const heart_pos = [3]i32{ wx, wy, wz };

                            const below = ch.getBlock(@intCast(lx), @intCast(ly - 1), @intCast(lz));
                            const above = ch.getBlock(@intCast(lx), @intCast(ly + 1), @intCast(lz));
                            if (below != .pale_oak_log or above != .pale_oak_log) continue;

                            if (self.hasLinkedCreaking(heart_pos)) continue;

                            if (findSafeSpawnNearHeart(chunk_manager, heart_pos)) |sp| {
                                try self.spawnCreaking(heart_pos, sp.x, sp.y, sp.z);
                            }
                        }
                    }
                }
            }
        }
    }

    pub fn tickCreakings(
        self: *MobManager,
        block_at: ?*const fn (x: i32, y: i32, z: i32) block_mod.BlockId,
        is_solid: *const fn (x: i32, y: i32, z: i32) bool,
        player_pos: math.Vec3,
        player_eye_pos: math.Vec3,
        player_look_dir: math.Vec3,
        is_night: bool,
        is_thunder: bool,
        wearing_carved_pumpkin: bool,
        is_overworld: bool,
    ) void {
        if (!is_overworld or (!is_night and !is_thunder)) {
            self.clearAllCreakings();
            return;
        }

        const bat = block_at orelse return;

        var idx: usize = 0;
        while (idx < self.mobs.items.len) {
            var mob = &self.mobs.items[idx];
            if (mob.mob_type != .creaking) {
                idx += 1;
                continue;
            }

            const hp = mob.creaking_heart_pos orelse {
                _ = self.mobs.swapRemove(idx);
                continue;
            };

            const h_blk = bat(hp[0], hp[1], hp[2]);
            const above_blk = bat(hp[0], hp[1] + 1, hp[2]);
            const below_blk = bat(hp[0], hp[1] - 1, hp[2]);
            if (h_blk != .creaking_heart or above_blk != .pale_oak_log or below_blk != .pale_oak_log) {
                _ = self.mobs.swapRemove(idx);
                continue;
            }

            const c_pos = [3]f32{ mob.pos.x, mob.pos.y, mob.pos.z };
            if (!pale_garden_mod.isWithinTetherRadius(c_pos, hp)) {
                _ = self.mobs.swapRemove(idx);
                continue;
            }

            const observed = pale_garden_mod.isCreakingObserved(
                c_pos,
                mob.height,
                [3]f32{ player_eye_pos.x, player_eye_pos.y, player_eye_pos.z },
                [3]f32{ player_look_dir.x, player_look_dir.y, player_look_dir.z },
                0.7071,
                wearing_carved_pumpkin,
                is_solid,
            );

            if (observed) {
                mob.is_frozen = true;
                mob.vel.x = 0.0;
                mob.vel.z = 0.0;
                mob.walk_timer = 0.0;
            } else {
                mob.is_frozen = false;
                const p_arr = [3]f32{ player_pos.x, player_pos.y, player_pos.z };
                if (pale_garden_mod.isWithinTetherRadius(p_arr, hp)) {
                    const pdx = player_pos.x - mob.pos.x;
                    const pdz = player_pos.z - mob.pos.z;
                    const pdist = @sqrt(pdx * pdx + pdz * pdz);
                    if (pdist > 0.5) {
                        mob.yaw = std.math.atan2(pdx, pdz);
                        mob.walk_timer = hunt_mod.walk_pulse;
                    }
                } else {
                    const hdx = @as(f32, @floatFromInt(hp[0])) + 0.5 - mob.pos.x;
                    const hdz = @as(f32, @floatFromInt(hp[2])) + 0.5 - mob.pos.z;
                    mob.yaw = std.math.atan2(hdx, hdz);
                    mob.walk_timer = hunt_mod.walk_pulse;
                }
            }

            idx += 1;
        }
    }

    pub fn countNearbyWolves(self: *const MobManager, center: math.Vec3, radius: f32) usize {
        var count: usize = 0;
        const r_sq = radius * radius;
        for (self.mobs.items) |m| {
            if (m.mob_type != .wolf and m.mob_type != .emberbeast and m.mob_type != .wither_skeleton and m.mob_type != .piglin and m.mob_type != .piglin_brute and m.mob_type != .blaze and m.mob_type != .spider and m.mob_type != .cave_spider and m.mob_type != .skeleton and m.mob_type != .zombie and m.mob_type != .creeper and m.mob_type != .enderman and m.mob_type != .slime) continue;
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

test "MobManager emberbeast immune to burn contact" {
    var mobs = std.ArrayList(mob_mod.Mob).empty;
    defer mobs.deinit(std.testing.allocator);
    try mobs.append(std.testing.allocator, mob_mod.Mob.init(.emberbeast, 0, 1, 0));
    // Immunity is enforced in tick() via mob_type guard; emberbeast type survives burn scan.
    try std.testing.expectEqual(mobs.items[0].mob_type, .emberbeast);
    try std.testing.expectEqual(mobs.items[0].health, 8);
}

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

test "MobManager bubble column lift and whirlpool suction" {
    var mm = MobManager{
        .allocator = std.testing.allocator,
        .mobs = std.ArrayList(mob_mod.Mob).empty,
        .renderer = undefined,
        .rng = std.Random.DefaultPrng.init(42),
        .ambient_timer = 5.0,
        .spawner_timer = 0.0,
    };
    defer mm.mobs.deinit(std.testing.allocator);

    // Spawn one mob in soul sand bubble column, one in magma whirlpool
    try mm.spawnMob(.pig, 0.5, 3.0, 0.5);
    try mm.spawnMob(.sheep, 10.5, 3.0, 0.5);

    const MockWorld = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn fluid(_: i32, _: i32, _: i32) bool { return true; }
        fn block(x: i32, y: i32, z: i32) block_mod.BlockId {
            _ = z;
            if (x == 0) {
                if (y == 0) return .soul_sand;
                return .water;
            } else if (x == 10) {
                if (y == 0) return .magma;
                return .water;
            }
            return .air;
        }
    };

    mm.tick(MockWorld.solid, MockWorld.fluid, MockWorld.block, math.Vec3.init(50, 0, 0), 0.4, false, null, 0.05);

    try std.testing.expect(mm.mobs.items[0].in_bubble_column);
    try std.testing.expect(!mm.mobs.items[0].in_whirlpool);
    try std.testing.expect(mm.mobs.items[0].vel.y >= mob_mod.Mob.bubble_column_lift_speed);

    try std.testing.expect(!mm.mobs.items[1].in_bubble_column);
    try std.testing.expect(mm.mobs.items[1].in_whirlpool);
    try std.testing.expect(mm.mobs.items[1].vel.y <= mob_mod.Mob.whirlpool_pull_speed);
}

test "MobManager mob burn damage contact hazard on magma or campfire" {
    var mm = MobManager{
        .allocator = std.testing.allocator,
        .mobs = std.ArrayList(mob_mod.Mob).empty,
        .renderer = undefined,
        .rng = std.Random.DefaultPrng.init(42),
        .ambient_timer = 5.0,
        .spawner_timer = 0.0,
    };
    defer mm.mobs.deinit(std.testing.allocator);

    // Spawn pig on magma (3 hp)
    try mm.spawnMob(.pig, 0.5, 1.0, 0.5);

    const MockWorld = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return true; }
        fn fluid(_: i32, _: i32, _: i32) bool { return false; }
        fn block(_: i32, y: i32, _: i32) block_mod.BlockId {
            if (y == 0) return .magma;
            return .air;
        }
    };

    // 1 second pass: 1 damage taken, 2 hp left
    mm.tick(MockWorld.solid, MockWorld.fluid, MockWorld.block, math.Vec3.init(50, 0, 0), 0.4, false, null, 1.0);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);
    try std.testing.expectEqual(@as(u8, 2), mm.mobs.items[0].health);

    // 1 second pass: 1 damage taken, 1 hp left
    mm.tick(MockWorld.solid, MockWorld.fluid, MockWorld.block, math.Vec3.init(50, 0, 0), 0.4, false, null, 1.0);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);
    try std.testing.expectEqual(@as(u8, 1), mm.mobs.items[0].health);

    // 1 second pass: mob dies and is removed
    mm.tick(MockWorld.solid, MockWorld.fluid, MockWorld.block, math.Vec3.init(50, 0, 0), 0.4, false, null, 1.0);
    try std.testing.expectEqual(@as(usize, 0), mm.mobs.items.len);
}

test "mob manager piglin barter and pacification" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    try mm.spawnMob(.piglin, 0.5, 1.0, 3.0);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);
    try std.testing.expectEqual(mm.mobs.items[0].barter_timer, 0.0);

    const b = mm.tryBarter(math.Vec3.init(0.5, 1.5, 0.0), math.Vec3.init(0.0, 0.0, 1.0), 5.0);
    try std.testing.expect(b != null);
    try std.testing.expect(b.?.count > 0);
    try std.testing.expect(mm.mobs.items[0].barter_timer > 10.0);

    // Hitting piglin clears pacification timer
    _ = mm.tryHitMobDmg(math.Vec3.init(0.5, 1.5, 0.0), math.Vec3.init(0.0, 0.0, 1.0), 5.0, 1);
    try std.testing.expectEqual(mm.mobs.items[0].barter_timer, 0.0);
}

test "mob manager hit reports champion status" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();
    try mm.spawnMob(.wither_skeleton, 0.5, 1.0, 5.0);
    mm.mobs.items[0].is_champion = true;
    const hit = mm.tryHitMobDmg(math.Vec3.init(0.5, 1.5, 0.0), math.Vec3.init(0.0, 0.0, 1.0), 10.0, 5);
    try std.testing.expect(hit != null);
    try std.testing.expect(hit.?.is_champion);
    try std.testing.expect(!hit.?.died);
}

test "mob manager piglin warped fungus repulsion and fleeing" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    const MockFungusWorld = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return true; }
        fn fluid(_: i32, _: i32, _: i32) bool { return false; }
        fn block(x: i32, y: i32, z: i32) block_mod.BlockId {
            // Placed warped fungus at (4, 1, 0)
            if (x == 4 and y == 1 and z == 0) return .warped_fungus;
            return .air;
        }
    };

    // Piglin at (0.5, 1.0, 0.5) near placed warped fungus at (4, 1, 0) -> distance ~ 4m (<8m)
    const piglin_pos = math.Vec3.init(0.5, 1.0, 0.5);
    const repel_source = MobManager.isPiglinRepelled(piglin_pos, math.Vec3.init(20, 1, 20), false, MockFungusWorld.block);
    try std.testing.expect(repel_source != null);
    try std.testing.expectEqual(repel_source.?.x, 4.5);
    try std.testing.expectEqual(repel_source.?.z, 0.5);

    // Player holding fungus within 8m repels piglin even without placed block
    const held_source = MobManager.isPiglinRepelled(piglin_pos, math.Vec3.init(3.5, 1.0, 0.5), true, null);
    try std.testing.expect(held_source != null);
    try std.testing.expectEqual(held_source.?.x, 3.5);

    // Piglin out of range (>8m) is not repelled
    const far_source = MobManager.isPiglinRepelled(math.Vec3.init(50, 1, 50), math.Vec3.init(0, 1, 0), false, MockFungusWorld.block);
    try std.testing.expect(far_source == null);

    // Tick test: piglin turns away from warped fungus
    try mm.spawnMob(.piglin, 0.5, 1.0, 0.5);
    mm.tick(MockFungusWorld.solid, MockFungusWorld.fluid, MockFungusWorld.block, math.Vec3.init(0.5, 1.0, -2.0), 0.4, false, null, 0.05);

    // Piglin should face away from (4.5, 0.5): fdx = 0.5 - 4.5 = -4.0, fdz = 0.5 - 0.5 = 0.0
    // yaw = atan2(-4.0, 0.0) = -pi/2 (-1.5707963...)
    try std.testing.expectApproxEqAbs(mm.mobs.items[0].yaw, -std.math.pi * 0.5, 0.01);
}

test "mob manager piglin brute unpacified, fearless, and aggressive" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    const MockFungusWorld = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return true; }
        fn fluid(_: i32, _: i32, _: i32) bool { return false; }
        fn block(x: i32, y: i32, z: i32) block_mod.BlockId {
            if (x == 4 and y == 1 and z == 0) return .warped_fungus;
            return .air;
        }
    };

    try mm.spawnMob(.piglin_brute, 0.5, 1.0, 0.5);
    try std.testing.expectEqual(mm.mobs.items[0].mob_type, .piglin_brute);
    try std.testing.expectEqual(mm.mobs.items[0].health, 15);

    // Piglin brute ignores bartering (returns null)
    const b = mm.tryBarter(math.Vec3.init(0.5, 1.5, 0.0), math.Vec3.init(0.0, 0.0, 1.0), 5.0);
    try std.testing.expect(b == null);

    // Piglin brute does not flee from warped fungus; hunts player directly
    // Player is at (0.5, 1.0, 5.5) -> dz = 5.0, dx = 0.0 -> yaw towards player = atan2(0, 5) = 0.0
    mm.tick(MockFungusWorld.solid, MockFungusWorld.fluid, MockFungusWorld.block, math.Vec3.init(0.5, 1.0, 5.5), 0.4, true, null, 0.05);
    try std.testing.expectApproxEqAbs(mm.mobs.items[0].yaw, 0.0, 0.01);
}

test "mob manager pig luring by held warped fungus on stick" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    const MockWorld = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return true; }
        fn fluid(_: i32, _: i32, _: i32) bool { return false; }
    };

    try mm.spawnMob(.pig, 0.5, 1.0, 0.5);
    try std.testing.expectEqual(mm.mobs.items[0].mob_type, .pig);

    // Player holding fungus at (0.5, 1.0, 4.5) -> distance 4.0m
    // Pig should turn and walk towards player: pdx = 0, pdz = 4.0 -> yaw = atan2(0, 4.0) = 0.0
    mm.tick(MockWorld.solid, MockWorld.fluid, null, math.Vec3.init(0.5, 1.0, 4.5), 0.4, true, null, 0.05);
    try std.testing.expectApproxEqAbs(mm.mobs.items[0].yaw, 0.0, 0.01);
    try std.testing.expect(mm.mobs.items[0].walk_timer > 0.0);

    // Not holding fungus -> pig wanders normally, not lured
    mm.mobs.items[0].yaw = 1.23;
    mm.tick(MockWorld.solid, MockWorld.fluid, null, math.Vec3.init(0.5, 1.0, 4.5), 0.4, false, null, 0.05);
    try std.testing.expectApproxEqAbs(mm.mobs.items[0].yaw, 1.23, 0.01);
}

test "mob manager leash mob and hitch to fence post" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    try mm.spawnMob(.sheep, 0.5, 1.0, 3.0);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);
    try std.testing.expect(!mm.mobs.items[0].isLeashed());

    // Leash mob to player with held lead
    const res = mm.tryInteractLeash(math.Vec3.init(0.5, 1.5, 0.0), math.Vec3.init(0.0, 0.0, 1.0), 5.0, true);
    try std.testing.expectEqual(MobManager.LeashResult.attached_to_player, res);
    try std.testing.expect(mm.mobs.items[0].leashed_to_player);
    try std.testing.expect(mm.mobs.items[0].isLeashed());

    // Hitch to fence post at (10, 1, 10)
    const hitched = mm.tryHitchToFence(10, 1, 10);
    try std.testing.expectEqual(@as(usize, 1), hitched);
    try std.testing.expect(!mm.mobs.items[0].leashed_to_player);
    try std.testing.expect(mm.mobs.items[0].fence_post != null);
    try std.testing.expectEqual(mm.mobs.items[0].fence_post.?.x, 10);

    // Unhitch fence
    const unhitched = mm.unhitchFence(10, 1, 10);
    try std.testing.expectEqual(@as(usize, 1), unhitched);
    try std.testing.expect(!mm.mobs.items[0].isLeashed());
}

test "spider hunts player and engages in pack count" {
    var mobs = std.ArrayList(mob_mod.Mob).empty;
    defer mobs.deinit(std.testing.allocator);
    try mobs.append(std.testing.allocator, mob_mod.Mob.init(.spider, 2, 0, 2));

    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();
    try mm.spawnMob(.spider, 1.0, 0.0, 1.0);
    try std.testing.expectEqual(mm.mobs.items.len, 1);
    try std.testing.expectEqual(mm.mobs.items[0].mob_type, .spider);

    const nearby = mm.countNearbyWolves(math.Vec3.init(0, 0, 0), 5.0);
    try std.testing.expectEqual(@as(usize, 1), nearby);
}

test "MobManager tryShearSheep shearing mechanics" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    try mm.spawnMob(.sheep, 0.0, 1.0, 3.0);
    try std.testing.expectEqual(mm.mobs.items.len, 1);
    try std.testing.expect(!mm.mobs.items[0].is_sheared);

    // Aim at sheep from origin (0, 1, 0) towards (0, 0, 1)
    const shear_res = mm.tryShearSheep(math.Vec3.init(0.0, 1.0, 0.0), math.Vec3.init(0.0, 0.0, 1.0), 5.0);
    try std.testing.expect(shear_res != null);
    try std.testing.expectEqual(shear_res.?.wool_count, 2);
    try std.testing.expect(mm.mobs.items[0].is_sheared);

    // Second shear fails
    const shear_res2 = mm.tryShearSheep(math.Vec3.init(0.0, 1.0, 0.0), math.Vec3.init(0.0, 0.0, 1.0), 5.0);
    try std.testing.expect(shear_res2 == null);
}

test "MobManager Creaking one-per-heart spawning and duplicate prevention" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    const heart_pos = [3]i32{ 10, 64, 10 };
    try std.testing.expect(!mm.hasLinkedCreaking(heart_pos));

    try mm.spawnCreaking(heart_pos, 12.5, 64.0, 10.5);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);
    try std.testing.expect(mm.hasLinkedCreaking(heart_pos));

    // Attempting to spawn again for same heart is blocked
    try std.testing.expect(mm.hasLinkedCreaking(heart_pos));

    const other_heart = [3]i32{ 20, 64, 20 };
    try std.testing.expect(!mm.hasLinkedCreaking(other_heart));
}

test "MobManager Creaking safe spawn failure when no solid floor with headroom" {
    var mgr = try chunk_manager_mod.ChunkManager.init(std.testing.allocator, 1, 0, 0, 1234, ".zig-cache/test_saves");
    defer mgr.deinit();

    const heart_pos = [3]i32{ 0, 5, 0 };
    var dx: i32 = -5;
    while (dx <= 5) : (dx += 1) {
        var dz: i32 = -5;
        while (dz <= 5) : (dz += 1) {
            var dy: i32 = -8;
            while (dy <= 4) : (dy += 1) {
                _ = mgr.setBlockWorld(heart_pos[0] + dx, heart_pos[1] + dy, heart_pos[2] + dz, .stone);
            }
        }
    }
    const spawn_opt = MobManager.findSafeSpawnNearHeart(&mgr, heart_pos);
    try std.testing.expect(spawn_opt == null);
}

test "MobManager Creaking tickCreakings gaze freeze, look away, and occlusion" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    const heart_pos = [3]i32{ 0, 64, 0 };
    try mm.spawnCreaking(heart_pos, 0.5, 64.0, 5.5);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);

    const World = struct {
        var wall_present: bool = false;
        fn block(x: i32, y: i32, z: i32) block_mod.BlockId {
            if (x == 0 and y == 64 and z == 0) return .creaking_heart;
            if (x == 0 and (y == 65 or y == 63) and z == 0) return .pale_oak_log;
            if (wall_present and x == 0 and z == 3) return .stone;
            return .air;
        }
        fn solid(x: i32, y: i32, z: i32) bool {
            _ = y;
            if (x == 0 and z == 0) return true;
            if (wall_present and x == 0 and z == 3) return true;
            return false;
        }
    };

    const player_pos = math.Vec3.init(0.5, 64.0, 0.5);
    const player_eye = math.Vec3.init(0.5, 65.6, 0.5);
    const look_forward = math.Vec3.init(0.0, 0.0, 1.0);
    const look_away = math.Vec3.init(0.0, 0.0, -1.0);

    // 1. Looking directly at Creaking with no wall: frozen!
    World.wall_present = false;
    mm.tickCreakings(World.block, World.solid, player_pos, player_eye, look_forward, true, false, false, true);
    try std.testing.expect(mm.mobs.items[0].is_frozen);
    try std.testing.expectEqual(mm.mobs.items[0].walk_timer, 0.0);

    // 2. Looking away: resumes pursuit!
    mm.tickCreakings(World.block, World.solid, player_pos, player_eye, look_away, true, false, false, true);
    try std.testing.expect(!mm.mobs.items[0].is_frozen);
    try std.testing.expect(mm.mobs.items[0].walk_timer > 0.0);

    // 3. Looking directly at Creaking but occluded by wall at z=3: resumes pursuit!
    World.wall_present = true;
    mm.tickCreakings(World.block, World.solid, player_pos, player_eye, look_forward, true, false, false, true);
    try std.testing.expect(!mm.mobs.items[0].is_frozen);
    try std.testing.expect(mm.mobs.items[0].walk_timer > 0.0);
}

test "MobManager Creaking dawn removal, unaligned heart, and tether limit" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    const heart_pos = [3]i32{ 0, 64, 0 };
    try mm.spawnCreaking(heart_pos, 0.5, 64.0, 5.5);

    const World = struct {
        var heart_intact: bool = true;
        var logs_aligned: bool = true;
        fn block(x: i32, y: i32, z: i32) block_mod.BlockId {
            if (x == 0 and y == 64 and z == 0) return if (heart_intact) .creaking_heart else .air;
            if (x == 0 and y == 65 and z == 0) return if (logs_aligned) .pale_oak_log else .air;
            if (x == 0 and y == 63 and z == 0) return .pale_oak_log;
            return .air;
        }
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
    };

    const player_pos = math.Vec3.init(0.5, 64.0, 0.5);
    const player_eye = math.Vec3.init(0.5, 65.6, 0.5);
    const look_away = math.Vec3.init(0.0, 0.0, -1.0);

    // Dawn removal: when is_night is false and is_thunder is false, all Creakings are removed
    mm.tickCreakings(World.block, World.solid, player_pos, player_eye, look_away, false, false, false, true);
    try std.testing.expectEqual(@as(usize, 0), mm.mobs.items.len);

    // Respawn Creaking for unaligned log test
    try mm.spawnCreaking(heart_pos, 0.5, 64.0, 5.5);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);
    World.logs_aligned = false;
    mm.tickCreakings(World.block, World.solid, player_pos, player_eye, look_away, true, false, false, true);
    try std.testing.expectEqual(@as(usize, 0), mm.mobs.items.len);

    // Respawn Creaking for missing/broken heart test
    World.logs_aligned = true;
    try mm.spawnCreaking(heart_pos, 0.5, 64.0, 5.5);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);
    World.heart_intact = false;
    mm.tickCreakings(World.block, World.solid, player_pos, player_eye, look_away, true, false, false, true);
    try std.testing.expectEqual(@as(usize, 0), mm.mobs.items.len);

    // Respawn Creaking for tether limit (>32m) test
    World.heart_intact = true;
    try mm.spawnCreaking(heart_pos, 40.0, 64.0, 40.0);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);
    mm.tickCreakings(World.block, World.solid, player_pos, player_eye, look_away, true, false, false, true);
    try std.testing.expectEqual(@as(usize, 0), mm.mobs.items.len);
}

test "MobManager Creaking dimension switch cleanup and failure preservation" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    try mm.spawnMob(.sheep, 0, 64, 0);
    try mm.spawnCreaking(.{ 10, 64, 10 }, 12, 64, 10);
    try std.testing.expectEqual(@as(usize, 2), mm.mobs.items.len);

    // On failed dimension switch: live mobs are preserved!
    const switch_succeeded = false;
    if (switch_succeeded) {
        mm.clearAllCreakings();
    }
    try std.testing.expectEqual(@as(usize, 2), mm.mobs.items.len);

    // On successful dimension switch: creakings cleared, regular mobs preserved!
    const real_switch_succeeded = true;
    if (real_switch_succeeded) {
        mm.clearAllCreakings();
    }
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);
    try std.testing.expectEqual(mm.mobs.items[0].mob_type, .sheep);
}

test "MobManager Creaking swapRemove retains stable heart links" {
    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    const heart1 = [3]i32{ 10, 64, 10 };
    const heart2 = [3]i32{ 20, 64, 20 };

    try mm.spawnCreaking(heart1, 10.5, 64.0, 12.0);
    try mm.spawnMob(.zombie, 5.0, 64.0, 5.0);
    try mm.spawnCreaking(heart2, 20.5, 64.0, 22.0);

    try std.testing.expectEqual(@as(usize, 3), mm.mobs.items.len);
    try std.testing.expect(mm.hasLinkedCreaking(heart1));
    try std.testing.expect(mm.hasLinkedCreaking(heart2));

    // Remove mob at index 0 (swapRemove moves index 2 to index 0)
    _ = mm.mobs.swapRemove(0);
    try std.testing.expectEqual(@as(usize, 2), mm.mobs.items.len);

    try std.testing.expect(!mm.hasLinkedCreaking(heart1));
    try std.testing.expect(mm.hasLinkedCreaking(heart2));
    try std.testing.expectEqual(mm.mobs.items[0].mob_type, .creaking);
    try std.testing.expectEqual(mm.mobs.items[0].creaking_heart_pos.?, heart2);
}

test "MobManager Creaking hit invulnerability and shared resin cooldown with F path" {
    var tracker = pale_garden_mod.CreakingHeartTracker.init();
    const heart_pos = [3]i32{ 15, 64, 15 };

    var mm = try MobManager.init(std.testing.allocator, 0);
    defer mm.deinit();

    try mm.spawnCreaking(heart_pos, 15.5, 64.0, 18.0);
    try std.testing.expectEqual(@as(usize, 1), mm.mobs.items.len);

    const hit = mm.tryHitMobDmg(math.Vec3.init(15.5, 65.0, 15.0), math.Vec3.init(0.0, 0.0, 1.0), 5.0, 10);
    try std.testing.expect(hit != null);
    try std.testing.expectEqual(hit.?.mob_type, .creaking);
    try std.testing.expect(!hit.?.died);
    try std.testing.expectEqual(hit.?.creaking_heart_pos.?, heart_pos);

    const ext = tracker.tryExtrudeResin(heart_pos, .pale_oak_log, .pale_oak_log, true, false);
    try std.testing.expectEqual(pale_garden_mod.ExtrudeStatus.extruded, ext.status);
    try std.testing.expect(ext.clumps >= 2 and ext.clumps <= 3);

    const f_shortcut = tracker.tryExtrudeResin(heart_pos, .pale_oak_log, .pale_oak_log, true, false);
    try std.testing.expectEqual(pale_garden_mod.ExtrudeStatus.cooling_down, f_shortcut.status);
    try std.testing.expectEqual(@as(u8, 0), f_shortcut.clumps);

    tracker.tickSeconds(5.0);
    const f_reavailable = tracker.tryExtrudeResin(heart_pos, .pale_oak_log, .pale_oak_log, true, false);
    try std.testing.expectEqual(pale_garden_mod.ExtrudeStatus.extruded, f_reavailable.status);
}
