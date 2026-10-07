const std = @import("std");
const math = @import("../math.zig");

pub const MobType = enum {
    sheep,
    pig,
    wolf,
};

pub const Mob = struct {
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
        };
    }

    /// Update mob AI and physics
    pub fn tick(self: *Mob, solid: *const fn (x: i32, y: i32, z: i32) bool, dt: f32, rng: *std.Random.DefaultPrng) void {
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

        const move_dist_x = (wish_x + self.vel.x) * clamped_dt;
        const move_dist_z = (wish_z + self.vel.z) * clamped_dt;
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

        self.vel.y -= 25.0 * clamped_dt;
        if (self.vel.y < -30.0) self.vel.y = -30.0;

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

test "mob gravity falls and lands" {
    var mob = Mob.init(.sheep, 0.5, 4.0, 0.5);
    var rng = std.Random.DefaultPrng.init(42);
    var i: usize = 0;
    while (i < 200) : (i += 1) {
        mob.tick(&testSolid, 1.0 / 60.0, &rng);
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
        mob.tick(&testSolid, 1.0 / 60.0, &rng);
    }
    try std.testing.expect(mob.yaw != 0.0 or mob.pos.x != 0.5 or mob.pos.z != 0.5);
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
