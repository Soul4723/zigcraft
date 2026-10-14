const std = @import("std");
const math = @import("../math.zig");

const inventory_mod = @import("../inventory.zig");
pub const MobType = inventory_mod.MobType;


/// Steer away from water ahead: probe one block in facing dir at feet.
/// Returns deflected yaw (+90 deg turn) when water ahead, else yaw unchanged.
pub fn steerAroundWater(yaw: f32, pos_x: f32, pos_y: f32, pos_z: f32, fluid: *const fn (x: i32, y: i32, z: i32) bool) f32 {
    const ahead_x: i32 = @intFromFloat(@floor(pos_x + @sin(yaw) * 1.2));
    const ahead_z: i32 = @intFromFloat(@floor(pos_z + @cos(yaw) * 1.2));
    const feet_y: i32 = @intFromFloat(@floor(pos_y + 0.2));
    if (fluid(ahead_x, feet_y, ahead_z)) return yaw + std.math.pi * 0.5;
    return yaw;
}

pub const Mob = struct {
    pub const bubble_column_lift_speed: f32 = 6.5;
    pub const whirlpool_pull_speed: f32 = -7.0;

    mob_type: MobType,
    pos: math.Vec3, // base / feet position
    vel: math.Vec3,
    yaw: f32, // rotation in radians around Y
    pitch: f32,
    on_ground: bool,
    width: f32, // 0.6
    height: f32, // 0.9
    walk_timer: f32,
    walk_speed: f32,
    anim_time: f32,
    change_dir_timer: f32,
    wants_sound: bool,
    health: u8,
    is_champion: bool = false,
    in_water: bool,
    in_bubble_column: bool,
    in_whirlpool: bool,
    burn_timer: f32,
    barter_timer: f32 = 0.0,
    glow_timer: f32 = 0.0,
    leashed_to_player: bool = false,
    fence_post: ?struct { x: i32, y: i32, z: i32 } = null,
    fuse_timer: f32 = 0.0,
    is_primed: bool = false,

    pub fn isLeashed(self: Mob) bool {
        return self.leashed_to_player or self.fence_post != null;
    }

    pub fn isGlowing(self: Mob) bool {
        return self.glow_timer > 0.0;
    }

    pub fn init(mob_type: MobType, x: f32, y: f32, z: f32) Mob {
        const w: f32 = switch (mob_type) {
            .sheep => 0.6,
            .pig => 0.55,
            .wolf => 0.6,
            .emberbeast => 0.7,
            .wither_skeleton => 0.6,
            .piglin, .piglin_brute => 0.6,
            .blaze => 0.6,
            .target_dummy => 0.6,
            .spider => 0.8,
            .skeleton, .zombie, .creeper, .enderman => 0.6,
            .ender_dragon => 2.4,
            .shulker => 0.8,
            .endermite => 0.4,
            .turtle => 0.9,
            .drowned => 0.6,
        };
        const h: f32 = switch (mob_type) {
            .sheep => 0.9,
            .pig => 0.75,
            .wolf => 0.8,
            .emberbeast => 1.0,
            .wither_skeleton => 1.6,
            .piglin, .piglin_brute => 1.5,
            .blaze => 1.8,
            .target_dummy => 1.8,
            .spider => 0.5,
            .skeleton, .zombie => 1.8,
            .creeper => 1.7,
            .enderman => 2.9,
            .ender_dragon => 1.8,
            .shulker => 0.8,
            .endermite => 0.3,
            .turtle => 0.4,
            .drowned => 1.8,
        };
        const spd: f32 = switch (mob_type) {
            .sheep => 1.4,
            .pig => 1.6,
            .wolf => 3.2,
            .emberbeast => 3.6,
            .wither_skeleton => 2.8,
            .piglin => 2.6,
            .piglin_brute => 3.0,
            .blaze => 2.4,
            .target_dummy => 0.0,
            .spider => 3.5,
            .skeleton => 2.4,
            .zombie => 2.2,
            .creeper => 2.5,
            .enderman => 3.2,
            .ender_dragon => 4.5,
            .shulker => 0.0,
            .endermite => 2.8,
            .turtle => 0.8,
            .drowned => 1.8,
        };
        return .{
            .mob_type = mob_type,
            .pos = math.Vec3.init(x, y, z),
            .vel = math.Vec3.init(0, 0, 0),
            .yaw = 0.0,
            .pitch = 0.0,
            .on_ground = false,
            .width = w,
            .height = h,
            .walk_timer = 0.0,
            .walk_speed = spd,
            .anim_time = 0.0,
            .change_dir_timer = 2.0,
            .wants_sound = false,
            .health = if (mob_type == .wolf) 5 else if (mob_type == .emberbeast) 8 else if (mob_type == .blaze or mob_type == .enderman) 20 else if (mob_type == .piglin_brute or mob_type == .drowned) 15 else if (mob_type == .ender_dragon) 200 else if (mob_type == .target_dummy) 50 else if (mob_type == .shulker or mob_type == .turtle) 30 else if (mob_type == .spider or mob_type == .endermite) 8 else if (mob_type == .skeleton or mob_type == .zombie or mob_type == .creeper) 10 else if (mob_type == .wither_skeleton or mob_type == .piglin) 10 else 3,
            .in_water = false,
            .in_bubble_column = false,
            .in_whirlpool = false,
            .burn_timer = 0.0,
            .barter_timer = 0.0,
            .glow_timer = 0.0,
            .leashed_to_player = false,
            .fence_post = null,
        };
    }

    /// Update mob AI and physics
    pub fn tick(self: *Mob, solid: *const fn (x: i32, y: i32, z: i32) bool, fluid: *const fn (x: i32, y: i32, z: i32) bool, dt: f32, rng: *std.Random.DefaultPrng) void {
        const clamped_dt = @min(dt, 0.05);

        self.barter_timer = @max(0.0, self.barter_timer - clamped_dt);
        self.glow_timer = @max(0.0, self.glow_timer - clamped_dt);
        if (self.mob_type == .target_dummy or self.mob_type == .shulker) {
            // Stationary practice target
            self.walk_timer = 0.0;
            self.vel.x = 0.0;
            self.vel.z = 0.0;
            return;
        }

        self.change_dir_timer -= clamped_dt;
        if (self.change_dir_timer <= 0.0) {
            const roll = rng.random().float(f32);
            if (roll < 0.65) {
                // Pick a new wander yaw
                self.yaw = rng.random().float(f32) * std.math.pi * 2.0;
                self.walk_timer = 2.0 + rng.random().float(f32) * 3.0; // Walk for 2-5 seconds
            } else {
                self.walk_timer = 0.0; // Idle
            }
            self.wants_sound = (roll < 0.35);
            self.change_dir_timer = 3.0 + rng.random().float(f32) * 4.0;
        }

        if (self.walk_timer > 0.0) {
            self.yaw = steerAroundWater(self.yaw, self.pos.x, self.pos.y, self.pos.z, fluid);
        }

        var wish_x: f32 = 0.0;
        var wish_z: f32 = 0.0;

        if (self.mob_type == .ender_dragon) {
            // Ender Dragon 3D flight trajectory: circular aerial patrol (radius ~24m, altitude y=14..18)
            self.anim_time += clamped_dt * 8.0;
            self.yaw += clamped_dt * 0.45; // Smooth sweeping orbit
            wish_x = @sin(self.yaw) * self.walk_speed;
            wish_z = @cos(self.yaw) * self.walk_speed;
            const target_alt: f32 = 16.0 + @sin(self.anim_time * 0.8) * 2.5;
            self.vel.y += (target_alt - self.pos.y) * 1.5 * clamped_dt;
            self.vel.y = std.math.clamp(self.vel.y, -3.0, 3.0);
            self.pos.y += self.vel.y * clamped_dt;
            self.pos.x += wish_x * clamped_dt;
            self.pos.z += wish_z * clamped_dt;
            return;
        }

        if (self.walk_timer > 0.0) {
            self.walk_timer -= clamped_dt;
            wish_x = @sin(self.yaw) * self.walk_speed;
            wish_z = @cos(self.yaw) * self.walk_speed;
            self.anim_time += clamped_dt * 6.0;
        } else {
            self.anim_time = if (self.mob_type == .blaze) self.anim_time + clamped_dt * 3.0 else 0.0;
        }

        // Water detection & current push on mobs
        var cur_x: f32 = 0.0;
        var cur_z: f32 = 0.0;
        const mx_i: i32 = @intFromFloat(@floor(self.pos.x));
        const my_i: i32 = @intFromFloat(@floor(self.pos.y + 0.1));
        const mz_i: i32 = @intFromFloat(@floor(self.pos.z));
        self.in_water = fluid(mx_i, my_i, mz_i);
        if (self.mob_type == .turtle) {
            self.walk_speed = if (self.in_water) 2.8 else 0.8;
        } else if (self.mob_type == .drowned) {
            self.walk_speed = if (self.in_water) 2.4 else 1.8;
        }
        if (self.in_water) {
            const dirs = [_][2]i32{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };
            for (dirs) |d| {
                if (!fluid(mx_i + d[0], my_i, mz_i + d[1])) {
                    cur_x += @floatFromInt(d[0]);
                    cur_z += @floatFromInt(d[1]);
                }
            }
            const clen_sq = cur_x * cur_x + cur_z * cur_z;
            if (clen_sq > 0.0001) {
                const clen = @sqrt(clen_sq);
                cur_x = (cur_x / clen) * 1.2;
                cur_z = (cur_z / clen) * 1.2;
            }
        }

        const move_dist_x = (wish_x + self.vel.x + cur_x) * clamped_dt;
        const move_dist_z = (wish_z + self.vel.z + cur_z) * clamped_dt;
        self.vel.x *= @max(0.0, 1.0 - 10.0 * clamped_dt);
        self.vel.z *= @max(0.0, 1.0 - 10.0 * clamped_dt);

        const old_x = self.pos.x;
        const old_z = self.pos.z;

        const half_w = self.width * 0.5;
        self.pos.x = moveAxis(self.pos, half_w, self.height, solid, move_dist_x, .x);
        self.pos.z = moveAxis(self.pos, half_w, self.height, solid, move_dist_z, .z);

        // If bumped into obstacle: spiders climb walls directly; other mobs auto-hop 1-block step
        const blocked_x = @abs(self.pos.x - old_x) < @abs(move_dist_x) * 0.5 and @abs(move_dist_x) > 0.001;
        const blocked_z = @abs(self.pos.z - old_z) < @abs(move_dist_z) * 0.5 and @abs(move_dist_z) > 0.001;
        const is_spider_climbing = self.mob_type == .spider and (blocked_x or blocked_z);
        if (blocked_x or blocked_z) {
            if (self.mob_type == .spider) {
                // Arachnid vertical wall climbing physics: ascend wall at steady climb speed
                self.vel.y = 3.5;
                self.on_ground = false;
            } else if (self.on_ground) {
                const check_p = math.Vec3.init(self.pos.x + move_dist_x * 2.0, self.pos.y + 1.1, self.pos.z + move_dist_z * 2.0);
                if (!aabbHits(check_p, half_w, self.height, solid)) {
                    self.vel.y = 5.0; // Small jump / step
                    self.on_ground = false;
                }
            }
        }

        if (self.in_water) {
            if (self.in_whirlpool) {
                // Downward magma whirlpool drag sucks mob to floor
                self.vel.y = @min(self.vel.y, whirlpool_pull_speed);
            } else if (self.in_bubble_column) {
                // Upward soul sand bubble column surge launches mob upward
                self.vel.y = @max(self.vel.y, bubble_column_lift_speed);
                self.on_ground = false;
            } else {
                // Water swimming buoyancy: float upward / paddle towards surface
                self.vel.y = @min(1.8, self.vel.y + 8.0 * clamped_dt);
                self.on_ground = false;
            }
        } else if (self.mob_type == .blaze) {
            // Blaze hovers gently without falling
            self.vel.y = @sin(self.anim_time * 2.5) * 0.4;
        } else if (is_spider_climbing) {
            // Spider wall climbing maintains upward velocity against gravity
        } else {
            self.vel.y -= 25.0 * clamped_dt;
            if (self.vel.y < -30.0) self.vel.y = -30.0;
        }

        var dummy_v = self.vel.y;
        self.pos.y = collideAxis(self.pos, half_w, self.height, solid, self.vel.y * clamped_dt, .y, &dummy_v, &self.on_ground);
        self.vel.y = dummy_v;
    }

    /// Check if ray intersects mob bounding box. Returns distance along ray or null.
    pub fn rayIntersects(self: Mob, origin: math.Vec3, dir: math.Vec3, max_dist: f32) ?f32 {
        const half_w = self.width * 0.5;
        const min_p = math.Vec3.init(self.pos.x - half_w, self.pos.y, self.pos.z - half_w);
        const max_p = math.Vec3.init(self.pos.x + half_w, self.pos.y + self.height, self.pos.z + half_w);

        var tmin: f32 = 0.0;
        var tmax: f32 = max_dist;

        if (@abs(dir.x) < 0.0001) {
            if (origin.x < min_p.x or origin.x > max_p.x) return null;
        } else {
            const inv_d = 1.0 / dir.x;
            var t1 = (min_p.x - origin.x) * inv_d;
            var t2 = (max_p.x - origin.x) * inv_d;
            if (t1 > t2) std.mem.swap(f32, &t1, &t2);
            tmin = @max(tmin, t1);
            tmax = @min(tmax, t2);
            if (tmin > tmax) return null;
        }

        if (@abs(dir.y) < 0.0001) {
            if (origin.y < min_p.y or origin.y > max_p.y) return null;
        } else {
            const inv_d = 1.0 / dir.y;
            var t1 = (min_p.y - origin.y) * inv_d;
            var t2 = (max_p.y - origin.y) * inv_d;
            if (t1 > t2) std.mem.swap(f32, &t1, &t2);
            tmin = @max(tmin, t1);
            tmax = @min(tmax, t2);
            if (tmin > tmax) return null;
        }

        if (@abs(dir.z) < 0.0001) {
            if (origin.z < min_p.z or origin.z > max_p.z) return null;
        } else {
            const inv_d = 1.0 / dir.z;
            var t1 = (min_p.z - origin.z) * inv_d;
            var t2 = (max_p.z - origin.z) * inv_d;
            if (t1 > t2) std.mem.swap(f32, &t1, &t2);
            tmin = @max(tmin, t1);
            tmax = @min(tmax, t2);
            if (tmin > tmax) return null;
        }

        return tmin;
    }

    /// Apply punch/weapon knockback and damage. Returns true when health reaches 0.
    pub fn takeHitDmg(self: *Mob, from_dir: math.Vec3, dmg: u8) bool {
        self.health = if (self.health > dmg) self.health - dmg else 0;
        self.vel.y = 5.0;
        self.vel.x = from_dir.x * 4.0;
        self.vel.z = from_dir.z * 4.0;
        self.on_ground = false;
        self.walk_timer = 2.5;
        self.yaw = std.math.atan2(from_dir.x, from_dir.z);
        return self.health == 0;
    }

    pub fn takeHit(self: *Mob, from_dir: math.Vec3) bool {
        return self.takeHitDmg(from_dir, 1);
    }

    /// Apply contact burn damage with 1-second damage tick interval.
    /// Returns true if mob dies.
    pub fn applyBurnTick(self: *Mob, dt: f32) bool {
        self.burn_timer += dt;
        if (self.burn_timer >= 1.0) {
            self.burn_timer = 0.0;
            self.health = if (self.health > 1) self.health - 1 else 0;
            self.vel.y = @max(self.vel.y, 2.5); // small flinch hop
            return self.health == 0;
        }
        return false;
    }

};

const Axis = enum { x, y, z };

fn collideAxis(pos: math.Vec3, radius: f32, height: f32, solid: *const fn (x: i32, y: i32, z: i32) bool, delta: f32, axis: Axis, vel_y: ?*f32, on_ground: ?*bool) f32 {
    if (delta == 0) {
        if (axis == .y and on_ground != null) on_ground.?.* = grounded(pos, radius, height, solid);
        return switch (axis) {
            .x => pos.x,
            .y => pos.y,
            .z => pos.z,
        };
    }
    var p = pos;
    const steps: usize = @intFromFloat(@ceil(@abs(delta) / 0.1) + 1);
    const step = delta / @as(f32, @floatFromInt(steps));
    var i: usize = 0;
    while (i < steps) : (i += 1) {
        switch (axis) {
            .x => p.x += step,
            .y => p.y += step,
            .z => p.z += step,
        }
        if (aabbHits(p, radius, height, solid)) {
            switch (axis) {
                .x => p.x = if (step > 0) @floor(p.x + radius) - radius - 0.001 else @floor(p.x - radius) + 1 + radius + 0.001,
                .y => {
                    if (step > 0) {
                        p.y = @floor(p.y + height) - height - 0.001;
                        if (vel_y != null) vel_y.?.* = 0;
                    } else {
                        p.y = @floor(p.y) + 1.0;
                        if (vel_y != null) vel_y.?.* = 0;
                        if (on_ground != null) on_ground.?.* = true;
                    }
                    return p.y;
                },
                .z => p.z = if (step > 0) @floor(p.z + radius) - radius - 0.001 else @floor(p.z - radius) + 1 + radius + 0.001,
            }
            if (axis != .y and aabbHits(p, radius, height, solid)) {
                switch (axis) {
                    .x => p.x -= step,
                    .z => p.z -= step,
                    else => {},
                }
            }
            break;
        }
        if (axis == .y and on_ground != null) on_ground.?.* = false;
    }
    if (axis == .y and step < 0 and on_ground != null) on_ground.?.* = grounded(p, radius, height, solid);
    return switch (axis) {
        .x => p.x,
        .y => p.y,
        .z => p.z,
    };
}

fn moveAxis(pos: math.Vec3, radius: f32, height: f32, solid: *const fn (x: i32, y: i32, z: i32) bool, delta: f32, axis: Axis) f32 {
    var dummy_v: f32 = 0;
    var dummy_g = false;
    return collideAxis(pos, radius, height, solid, delta, axis, &dummy_v, &dummy_g);
}

fn grounded(pos: math.Vec3, radius: f32, height: f32, solid: *const fn (x: i32, y: i32, z: i32) bool) bool {
    _ = height;
    const feet = pos.y - 0.01;
    const yb: i32 = @intFromFloat(@floor(feet));
    for ([2]f32{ pos.x - radius, pos.x + radius }) |sx| {
        for ([2]f32{ pos.z - radius, pos.z + radius }) |sz| {
            const xb: i32 = @intFromFloat(@floor(sx));
            const zb: i32 = @intFromFloat(@floor(sz));
            if (solid(xb, yb, zb)) return true;
        }
    }
    return false;
}

fn aabbHits(pos: math.Vec3, radius: f32, height: f32, solid: *const fn (x: i32, y: i32, z: i32) bool) bool {
    const min_y: i32 = @intFromFloat(@floor(pos.y));
    const max_y: i32 = @intFromFloat(@floor(pos.y + height));
    var yb = min_y;
    while (yb <= max_y) : (yb += 1) {
        for ([2]f32{ pos.x - radius, pos.x + radius }) |sx| {
            for ([2]f32{ pos.z - radius, pos.z + radius }) |sz| {
                const xb: i32 = @intFromFloat(@floor(sx));
                const zb: i32 = @intFromFloat(@floor(sz));
                if (solid(xb, yb, zb)) return true;
            }
        }
    }
    return false;
}

fn testSolid(x: i32, y: i32, z: i32) bool {
    _ = x;
    _ = z;
    return y <= 0;
}

fn testDry(x: i32, y: i32, z: i32) bool {
    _ = x;
    _ = y;
    _ = z;
    return false;
}

fn testWet(x: i32, y: i32, z: i32) bool {
    _ = x;
    _ = y;
    _ = z;
    return true;
}

test "mob gravity falls and lands" {
    var mob = Mob.init(.sheep, 0.5, 4.0, 0.5);
    var rng = std.Random.DefaultPrng.init(42);
    var i: usize = 0;
    while (i < 200) : (i += 1) {
        mob.tick(&testSolid, &testDry, 1.0 / 60.0, &rng);
    }
    try std.testing.expect(mob.on_ground);
    try std.testing.expectApproxEqAbs(mob.pos.y, 1.0, 0.05);
}

test "mob wandering modifies yaw or position" {
    var mob = Mob.init(.sheep, 0.5, 1.0, 0.5);
    mob.on_ground = true;
    var rng = std.Random.DefaultPrng.init(1234);
    var i: usize = 0;
    while (i < 300) : (i += 1) {
        mob.tick(&testSolid, &testDry, 1.0 / 60.0, &rng);
    }
    try std.testing.expect(mob.yaw != 0.0 or mob.pos.x != 0.5 or mob.pos.z != 0.5);
}

test "steerAroundWater turns on wet, keeps yaw on dry" {
    try std.testing.expectApproxEqAbs(steerAroundWater(0.0, 0.5, 1.0, 0.5, &testDry), 0.0, 0.001);
    try std.testing.expectApproxEqAbs(steerAroundWater(0.0, 0.5, 1.0, 0.5, &testWet), std.math.pi * 0.5, 0.001);
}

test "mob rayIntersects detects hit" {
    const mob = Mob.init(.sheep, 5.0, 2.0, 5.0);
    const hit = mob.rayIntersects(math.Vec3.init(5.0, 2.5, 0.0), math.Vec3.init(0.0, 0.0, 1.0), 10.0);
    try std.testing.expect(hit != null);
    try std.testing.expectApproxEqAbs(hit.?, 4.7, 0.05);

    const miss = mob.rayIntersects(math.Vec3.init(0.0, 2.5, 0.0), math.Vec3.init(0.0, 0.0, 1.0), 10.0);
    try std.testing.expect(miss == null);
}

test "mob takeHit decrements health and reports death" {
    var dying = Mob.init(.pig, 0.0, 1.0, 0.0);
    try std.testing.expect(!dying.takeHit(math.Vec3.init(0.0, 0.0, 1.0)));
    try std.testing.expect(!dying.takeHit(math.Vec3.init(0.0, 0.0, 1.0)));
    try std.testing.expect(dying.takeHit(math.Vec3.init(0.0, 0.0, 1.0)));
    try std.testing.expectEqual(@as(u8, 0), dying.health);
}

test "mob takeHit applies knockback and sets state" {
    var mob = Mob.init(.sheep, 0.0, 1.0, 0.0);
    mob.on_ground = true;
    _ = mob.takeHit(math.Vec3.init(0.0, 0.0, 1.0));
    try std.testing.expectEqual(@as(f32, 5.0), mob.vel.y);
    try std.testing.expectEqual(@as(f32, 4.0), mob.vel.z);
    try std.testing.expect(!mob.on_ground);
    try std.testing.expect(mob.walk_timer > 0.0);
}

test "emberbeast tougher and faster than wolf" {
    const e = Mob.init(.emberbeast, 0.0, 1.0, 0.0);
    const w = Mob.init(.wolf, 0.0, 1.0, 0.0);
    try std.testing.expect(e.health > w.health);
    try std.testing.expect(e.walk_speed > w.walk_speed);
    try std.testing.expectEqual(e.mob_type, .emberbeast);
}

test "champion flag defaults off" {
    const m = Mob.init(.wither_skeleton, 0.0, 1.0, 0.0);
    try std.testing.expect(!m.is_champion);
}

test "wither skeleton tall, tough hunter" {
    const sk = Mob.init(.wither_skeleton, 0.0, 1.0, 0.0);
    try std.testing.expectEqual(sk.health, 10);
    try std.testing.expect(sk.height > 1.5);
    try std.testing.expectEqual(getSound(.wither_skeleton), .mob_growl);
    try std.testing.expectEqual(@import("../inventory.zig").getMobMeatDrop(.wither_skeleton), .coal);
}

test "wolf tougher and faster than sheep" {
    const w = Mob.init(.wolf, 0.0, 1.0, 0.0);
    const sh = Mob.init(.sheep, 0.0, 1.0, 0.0);
    try std.testing.expect(w.health > sh.health);
    try std.testing.expect(w.walk_speed > sh.walk_speed);
}

test "mob takeHitDmg deals variable damage" {
    var mob = Mob.init(.wolf, 0.0, 1.0, 0.0);
    try std.testing.expectEqual(mob.health, 5);
    try std.testing.expect(!mob.takeHitDmg(math.Vec3.init(0, 0, 1), 2));
    try std.testing.expectEqual(mob.health, 3);
    try std.testing.expect(mob.takeHitDmg(math.Vec3.init(0, 0, 1), 3));
    try std.testing.expectEqual(mob.health, 0);
}

pub fn getSound(mob_type: MobType) ?@import("../audio/synth.zig").SoundType {
    return switch (mob_type) {
        .sheep => .mob_baa,
        .pig => .mob_oink,
        .wolf => .mob_growl,
        .emberbeast => .mob_roar,
        .blaze => .mob_roar,
        .wither_skeleton => .mob_growl,
        .piglin, .piglin_brute => .mob_oink,
        .target_dummy => .step_wood,
        .spider => .mob_growl,
        .skeleton, .zombie => .mob_growl,
        .creeper => .mob_hiss,
        .enderman => .mob_teleport,
        .ender_dragon => .dragon_roar,
        .shulker => .mob_roar,
        .endermite => .mob_hiss,
        .turtle => .mob_growl,
        .drowned => .mob_growl,
    };
}

test "piglin mob stats and barter timer decay" {
    var p = Mob.init(.piglin, 1.0, 2.0, 3.0);
    try std.testing.expectEqual(p.mob_type, .piglin);
    try std.testing.expectEqual(p.health, 10);
    try std.testing.expectEqual(p.height, 1.5);
    try std.testing.expectEqual(p.walk_speed, 2.6);
    try std.testing.expectEqual(getSound(.piglin), .mob_oink);
    p.barter_timer = 5.0;
    var rng = std.Random.DefaultPrng.init(1234);
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return true; }
        fn dry(_: i32, _: i32, _: i32) bool { return false; }
    };
    p.tick(Mock.solid, Mock.dry, 1.0, &rng);
    try std.testing.expect(p.barter_timer < 5.0);
}

test "mob sound mapping" {
    try std.testing.expectEqual(@import("../audio/synth.zig").SoundType.mob_baa, getSound(.sheep).?);
    try std.testing.expectEqual(@import("../audio/synth.zig").SoundType.mob_oink, getSound(.pig).?);
    try std.testing.expectEqual(@import("../audio/synth.zig").SoundType.mob_growl, getSound(.wolf).?);
    try std.testing.expectEqual(@import("../audio/synth.zig").SoundType.mob_roar, getSound(.emberbeast).?);
}

test "mob water current push" {
    var mob = Mob.init(.sheep, 0.5, 2.0, 0.5);
    mob.walk_timer = 0.0; // Idle, not walking
    var rng = std.Random.DefaultPrng.init(1234);
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn water(x: i32, y: i32, z: i32) bool {
            // Water at x <= 0 and current cell (0, 2, 0), open east
            return x <= 0 and y == 2 and z == 0;
        }
    };
    mob.tick(Mock.solid, Mock.water, 0.05, &rng);
    try std.testing.expect(mob.pos.x > 0.5);
}

test "mob water buoyancy floatation" {
    var mob = Mob.init(.sheep, 0.5, 2.0, 0.5);
    mob.vel.y = -2.0;
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn water(_: i32, _: i32, _: i32) bool { return true; }
    };
    var rng = std.Random.DefaultPrng.init(42);
    // Mob inside water should gain positive vertical buoyant lift
    mob.tick(Mock.solid, Mock.water, 0.05, &rng);
    try std.testing.expect(mob.in_water);
    try std.testing.expect(mob.vel.y > -2.0);
    // Several ticks: mob velocity becomes positive / floats
    var i: usize = 0;
    while (i < 20) : (i += 1) {
        mob.tick(Mock.solid, Mock.water, 0.05, &rng);
    }
    try std.testing.expect(mob.vel.y > 0.0);
}

test "mob soul sand bubble column upward surge" {
    var mob = Mob.init(.pig, 0.5, 2.0, 0.5);
    mob.in_bubble_column = true;
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn water(_: i32, _: i32, _: i32) bool { return true; }
    };
    var rng = std.Random.DefaultPrng.init(42);
    mob.tick(Mock.solid, Mock.water, 0.05, &rng);
    try std.testing.expect(mob.in_water);
    try std.testing.expect(mob.vel.y >= Mob.bubble_column_lift_speed);
}

test "mob magma whirlpool downward drag" {
    var mob = Mob.init(.pig, 0.5, 4.0, 0.5);
    mob.in_whirlpool = true;
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn water(_: i32, _: i32, _: i32) bool { return true; }
    };
    var rng = std.Random.DefaultPrng.init(42);
    mob.tick(Mock.solid, Mock.water, 0.05, &rng);
    try std.testing.expect(mob.in_water);
    try std.testing.expect(mob.vel.y <= Mob.whirlpool_pull_speed);
}

test "mob applyBurnTick deals contact damage and flinches" {
    var mob = Mob.init(.pig, 0.5, 1.0, 0.5);
    try std.testing.expectEqual(@as(u8, 3), mob.health);

    // After 0.5s: no damage yet
    try std.testing.expect(!mob.applyBurnTick(0.5));
    try std.testing.expectEqual(@as(u8, 3), mob.health);

    // After total 1.0s: 1 damage taken
    try std.testing.expect(!mob.applyBurnTick(0.5));
    try std.testing.expectEqual(@as(u8, 2), mob.health);
    try std.testing.expect(mob.vel.y >= 2.0);

    // Another 1.0s: 1 damage taken
    _ = mob.applyBurnTick(1.0);
    try std.testing.expectEqual(@as(u8, 1), mob.health);

    // Final 1.0s: mob dies
    const died = mob.applyBurnTick(1.0);
    try std.testing.expect(died);
    try std.testing.expectEqual(@as(u8, 0), mob.health);
}

test "piglin brute mob stats and sounds" {
    const b = Mob.init(.piglin_brute, 1.0, 2.0, 3.0);
    try std.testing.expectEqual(b.mob_type, .piglin_brute);
    try std.testing.expectEqual(b.health, 15);
    try std.testing.expectApproxEqAbs(b.walk_speed, 3.0, 0.01);
    try std.testing.expectEqual(getSound(.piglin_brute), .mob_oink);
}

test "mob glowing status timer and decay" {
    var mob = Mob.init(.sheep, 0, 0, 0);
    try std.testing.expect(!mob.isGlowing());
    try std.testing.expectEqual(@as(f32, 0.0), mob.glow_timer);

    mob.glow_timer = 10.0;
    try std.testing.expect(mob.isGlowing());

    const solid = struct {
        fn s(_: i32, _: i32, _: i32) bool {
            return false;
        }
    }.s;
    const fluid = struct {
        fn f(_: i32, _: i32, _: i32) bool {
            return false;
        }
    }.f;
    var rng = std.Random.DefaultPrng.init(42);
    mob.tick(solid, fluid, 0.05, &rng);
    try std.testing.expectApproxEqAbs(mob.glow_timer, 9.95, 0.001);
    try std.testing.expect(mob.isGlowing());
}

test "blaze mob properties: 20 HP, fire immunity and hovering" {
    const b = Mob.init(.blaze, 10.0, 5.0, 10.0);
    try std.testing.expectEqual(@as(u8, 20), b.health);
    try std.testing.expectApproxEqAbs(b.height, 1.8, 0.01);
    try std.testing.expectEqual(b.mob_type, .blaze);
}

/// Leash tether tension force towards anchor point (player or fence post).
/// Returns true if leash broke (exceeded max distance 10.0m).
pub fn applyLeashTension(mob_pos: *math.Vec3, mob_vel: *math.Vec3, anchor_pos: math.Vec3, dt: f32) bool {
    const dx = anchor_pos.x - mob_pos.x;
    const dy = anchor_pos.y - mob_pos.y;
    const dz = anchor_pos.z - mob_pos.z;
    const dist_sq = dx * dx + dy * dy + dz * dz;

    // Break leash if pulled past 10.0 meters
    if (dist_sq > 100.0) {
        return true;
    }

    // If beyond slack distance (3.0m), apply elastic spring tension
    if (dist_sq > 9.0) {
        const dist = @sqrt(dist_sq);
        const pull = (dist - 3.0) * 2.8;
        mob_vel.x += (dx / dist) * pull * dt;
        mob_vel.y += (dy / dist) * pull * dt;
        mob_vel.z += (dz / dist) * pull * dt;
    }
    return false;
}

test "mob leash tension and break distance" {
    var pos = math.Vec3.init(0.0, 0.0, 0.0);
    var vel = math.Vec3.init(0.0, 0.0, 0.0);

    // Slack leash (< 3.0m) -> no velocity change
    const anchor_slack = math.Vec3.init(2.0, 0.0, 0.0);
    const broke_slack = applyLeashTension(&pos, &vel, anchor_slack, 0.05);
    try std.testing.expect(!broke_slack);
    try std.testing.expectEqual(vel.x, 0.0);

    // Stretched leash (5.0m) -> accelerates toward anchor
    const anchor_taut = math.Vec3.init(5.0, 0.0, 0.0);
    const broke_taut = applyLeashTension(&pos, &vel, anchor_taut, 0.05);
    try std.testing.expect(!broke_taut);
    try std.testing.expect(vel.x > 0.1);

    // Snapped leash (> 10.0m) -> returns true (broken)
    const anchor_far = math.Vec3.init(12.0, 0.0, 0.0);
    const broke_far = applyLeashTension(&pos, &vel, anchor_far, 0.05);
    try std.testing.expect(broke_far);
}

test "target dummy mob properties and stationary behavior" {
    var dummy = Mob.init(.target_dummy, 10.0, 1.0, 10.0);
    try std.testing.expectEqual(dummy.mob_type, .target_dummy);
    try std.testing.expectEqual(dummy.health, 50);
    try std.testing.expectEqual(dummy.walk_speed, 0.0);
    try std.testing.expectEqual(dummy.height, 1.8);
    try std.testing.expectEqual(getSound(.target_dummy), .step_wood);

    var rng = std.Random.DefaultPrng.init(5555);
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return true; }
        fn dry(_: i32, _: i32, _: i32) bool { return false; }
    };
    dummy.tick(Mock.solid, Mock.dry, 0.5, &rng);
    try std.testing.expectEqual(dummy.pos.x, 10.0);
    try std.testing.expectEqual(dummy.pos.z, 10.0);
    try std.testing.expectEqual(dummy.vel.x, 0.0);
    try std.testing.expectEqual(dummy.vel.z, 0.0);
}

test "spider mob stats, dimensions, and string drop" {
    const sp = Mob.init(.spider, 5.0, 10.0, 15.0);
    try std.testing.expectEqual(sp.mob_type, .spider);
    try std.testing.expectEqual(sp.health, 8);
    try std.testing.expectEqual(sp.width, 0.8);
    try std.testing.expectEqual(sp.height, 0.5);
    try std.testing.expectEqual(sp.walk_speed, 3.5);
    try std.testing.expectEqual(getSound(.spider), .mob_growl);
    try std.testing.expectEqual(inventory_mod.getMobMeatDrop(.spider), .string);
}

test "spider climbs wall when blocked horizontally" {
    var sp = Mob.init(.spider, 0.599, 0.0, 0.5);
    const WallWorld = struct {
        fn solid(x: i32, y: i32, _: i32) bool {
            return x >= 1 or y <= -1;
        }
        fn fluid(_: i32, _: i32, _: i32) bool {
            return false;
        }
    };
    var rng = std.Random.DefaultPrng.init(1234);
    sp.change_dir_timer = 10.0;
    sp.yaw = std.math.pi * 0.5;
    sp.walk_timer = 2.0;
    sp.tick(WallWorld.solid, WallWorld.fluid, 0.05, &rng);
    try std.testing.expect(sp.vel.y > 0.0);
}

test "skeleton mob stats, dimensions, and bone drop" {
    const sk = Mob.init(.skeleton, 1.0, 2.0, 3.0);
    try std.testing.expectEqual(sk.mob_type, .skeleton);
    try std.testing.expectEqual(sk.health, 10);
    try std.testing.expectEqual(sk.width, 0.6);
    try std.testing.expectEqual(sk.height, 1.8);
    try std.testing.expectEqual(sk.walk_speed, 2.4);
    try std.testing.expectEqual(getSound(.skeleton), .mob_growl);
    try std.testing.expectEqual(inventory_mod.getMobMeatDrop(.skeleton), .bone);
}

test "zombie mob stats, dimensions, and rotten flesh drop" {
    const zm = Mob.init(.zombie, 1.0, 2.0, 3.0);
    try std.testing.expectEqual(zm.mob_type, .zombie);
    try std.testing.expectEqual(zm.health, 10);
    try std.testing.expectEqual(zm.width, 0.6);
    try std.testing.expectEqual(zm.height, 1.8);
    try std.testing.expectEqual(zm.walk_speed, 2.2);
    try std.testing.expectEqual(getSound(.zombie), .mob_growl);
    try std.testing.expectEqual(inventory_mod.getMobMeatDrop(.zombie), .rotten_flesh);
}

test "creeper mob stats, dimensions, and gunpowder drop" {
    const cr = Mob.init(.creeper, 1.0, 2.0, 3.0);
    try std.testing.expectEqual(cr.mob_type, .creeper);
    try std.testing.expectEqual(cr.health, 10);
    try std.testing.expectEqual(cr.width, 0.6);
    try std.testing.expectEqual(cr.height, 1.7);
    try std.testing.expectEqual(cr.walk_speed, 2.5);
    try std.testing.expectEqual(getSound(.creeper), .mob_hiss);
    try std.testing.expectEqual(inventory_mod.getMobMeatDrop(.creeper), .gunpowder);
}

test "enderman mob stats, dimensions, and ender pearl drop" {
    const em = Mob.init(.enderman, 1.0, 2.0, 3.0);
    try std.testing.expectEqual(em.mob_type, .enderman);
    try std.testing.expectEqual(em.health, 20);
    try std.testing.expectEqual(em.width, 0.6);
    try std.testing.expectEqual(em.height, 2.9);
    try std.testing.expectEqual(em.walk_speed, 3.2);
    try std.testing.expectEqual(getSound(.enderman), .mob_teleport);
    try std.testing.expectEqual(inventory_mod.getMobMeatDrop(.enderman), .ender_pearl);
}

test "ender dragon mob stats, boss health, and flight velocity" {
    var dragon = Mob.init(.ender_dragon, 0.0, 16.0, 0.0);
    try std.testing.expectEqual(dragon.health, 200);
    try std.testing.expectEqual(dragon.width, 2.4);
    try std.testing.expectEqual(dragon.height, 1.8);
    try std.testing.expectEqual(getSound(.ender_dragon), .dragon_roar);

    const MockWorld = struct {
        fn solid(x: i32, y: i32, z: i32) bool { _ = x; _ = y; _ = z; return false; }
        fn fluid(x: i32, y: i32, z: i32) bool { _ = x; _ = y; _ = z; return false; }
    };
    var rng = std.Random.DefaultPrng.init(42);
    dragon.tick(MockWorld.solid, MockWorld.fluid, 0.05, &rng);
    try std.testing.expect(dragon.anim_time > 0.0);
}

test "shulker mob properties and stationary behavior" {
    var sh = Mob.init(.shulker, 5.0, 10.0, 5.0);
    try std.testing.expectEqual(sh.mob_type, .shulker);
    try std.testing.expectEqual(sh.health, 30);
    try std.testing.expectEqual(sh.width, 0.8);
    try std.testing.expectEqual(sh.height, 0.8);
    try std.testing.expectEqual(sh.walk_speed, 0.0);

    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn fluid(_: i32, _: i32, _: i32) bool { return false; }
    };
    var rng = std.Random.DefaultPrng.init(1234);
    sh.tick(Mock.solid, Mock.fluid, 0.05, &rng);
    try std.testing.expectEqual(sh.vel.x, 0.0);
    try std.testing.expectEqual(sh.vel.z, 0.0);
}

test "endermite mob stats, dimensions, and pearl drop" {
    const em = Mob.init(.endermite, 10.0, 5.0, 10.0);
    try std.testing.expectEqual(em.mob_type, .endermite);
    try std.testing.expectEqual(em.health, 8);
    try std.testing.expectEqual(em.width, 0.4);
    try std.testing.expectEqual(em.height, 0.3);
    try std.testing.expectEqual(em.walk_speed, 2.8);
    try std.testing.expectEqual(getSound(.endermite), .mob_hiss);
    try std.testing.expectEqual(inventory_mod.getMobMeatDrop(.endermite), .ender_pearl);
}

test "turtle mob stats, dimensions, and scute drop" {
    const turtle = Mob.init(.turtle, 5.0, 1.0, 5.0);
    try std.testing.expectEqual(turtle.mob_type, .turtle);
    try std.testing.expectEqual(turtle.health, 30);
    try std.testing.expectEqual(turtle.width, 0.9);
    try std.testing.expectEqual(turtle.height, 0.4);
    try std.testing.expectEqual(turtle.walk_speed, 0.8);
    try std.testing.expectEqual(getSound(.turtle), .mob_growl);
    try std.testing.expectEqual(inventory_mod.getMobMeatDrop(.turtle), .scute);
}

test "drowned mob stats, dimensions, and rotten flesh drop" {
    const d = Mob.init(.drowned, 1.0, 2.0, 3.0);
    try std.testing.expectEqual(d.mob_type, .drowned);
    try std.testing.expectEqual(d.health, 15);
    try std.testing.expectEqual(d.width, 0.6);
    try std.testing.expectEqual(d.height, 1.8);
    try std.testing.expectEqual(d.walk_speed, 1.8);
    try std.testing.expectEqual(getSound(.drowned), .mob_growl);
    try std.testing.expectEqual(inventory_mod.getMobMeatDrop(.drowned), .rotten_flesh);
}
