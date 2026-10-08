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
    in_water: bool,
    in_bubble_column: bool,
    in_whirlpool: bool,
    burn_timer: f32,

    pub fn init(mob_type: MobType, x: f32, y: f32, z: f32) Mob {
        const w: f32 = switch (mob_type) {
            .sheep => 0.6,
            .pig => 0.55,
            .wolf => 0.6,
        };
        const h: f32 = switch (mob_type) {
            .sheep => 0.9,
            .pig => 0.75,
            .wolf => 0.8,
        };
        const spd: f32 = switch (mob_type) {
            .sheep => 1.4,
            .pig => 1.6,
            .wolf => 3.2,
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
            .health = if (mob_type == .wolf) 5 else 3,
            .in_water = false,
            .in_bubble_column = false,
            .in_whirlpool = false,
            .burn_timer = 0.0,
        };
    }

    /// Update mob AI and physics
    pub fn tick(self: *Mob, solid: *const fn (x: i32, y: i32, z: i32) bool, fluid: *const fn (x: i32, y: i32, z: i32) bool, dt: f32, rng: *std.Random.DefaultPrng) void {
        const clamped_dt = @min(dt, 0.05);

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

        if (self.walk_timer > 0.0) {
            self.walk_timer -= clamped_dt;
            wish_x = @sin(self.yaw) * self.walk_speed;
            wish_z = @cos(self.yaw) * self.walk_speed;
            self.anim_time += clamped_dt * 6.0;
        } else {
            self.anim_time = 0.0;
        }

        // Water detection & current push on mobs
        var cur_x: f32 = 0.0;
        var cur_z: f32 = 0.0;
        const mx_i: i32 = @intFromFloat(@floor(self.pos.x));
        const my_i: i32 = @intFromFloat(@floor(self.pos.y + 0.1));
        const mz_i: i32 = @intFromFloat(@floor(self.pos.z));
        self.in_water = fluid(mx_i, my_i, mz_i);
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

        // If bumped into a 1-block obstacle while on ground, auto-hop over it
        const blocked_x = @abs(self.pos.x - old_x) < @abs(move_dist_x) * 0.5 and @abs(move_dist_x) > 0.001;
        const blocked_z = @abs(self.pos.z - old_z) < @abs(move_dist_z) * 0.5 and @abs(move_dist_z) > 0.001;
        if (self.on_ground and (blocked_x or blocked_z)) {
            const check_p = math.Vec3.init(self.pos.x + move_dist_x * 2.0, self.pos.y + 1.1, self.pos.z + move_dist_z * 2.0);
            if (!aabbHits(check_p, half_w, self.height, solid)) {
                self.vel.y = 5.0; // Small jump / step
                self.on_ground = false;
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
    };
}

test "mob sound mapping" {
    try std.testing.expectEqual(@import("../audio/synth.zig").SoundType.mob_baa, getSound(.sheep).?);
    try std.testing.expectEqual(@import("../audio/synth.zig").SoundType.mob_oink, getSound(.pig).?);
    try std.testing.expectEqual(@import("../audio/synth.zig").SoundType.mob_growl, getSound(.wolf).?);
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
