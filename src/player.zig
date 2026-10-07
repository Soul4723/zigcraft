const std = @import("std");
const math = @import("math.zig");

pub const Player = struct {
    pos: math.Vec3, // feet position
    vel_y: f32,
    on_ground: bool,
    height: f32,
    radius: f32,
    distance_walked: f32,
    health: f32,
    hunger: f32,
    saturation: f32,
    spawn_point: math.Vec3,
    regen_timer: f32,

    pub fn init(x: f32, y: f32, z: f32) Player {
        return .{
            .pos = math.Vec3.init(x, y, z),
            .vel_y = 0,
            .on_ground = false,
            .height = 1.8,
            .radius = 0.3,
            .distance_walked = 0,
            .health = 20.0,
            .hunger = 20.0,
            .saturation = 5.0,
            .spawn_point = math.Vec3.init(x, y, z),
            .regen_timer = 0.0,
        };
    }

    /// Golden apple: instant heal + regen timer.
    pub fn eatGolden(self: *Player) void {
        self.health = @min(20.0, self.health + 6.0);
        self.hunger = @min(20.0, self.hunger + 4.0);
        self.saturation = @min(20.0, self.saturation + 6.0);
        self.regen_timer = 30.0;
    }

    /// Eat apple: light snack.
    pub fn eatApple(self: *Player) void {
        self.hunger = @min(20.0, self.hunger + 4.0);
        self.saturation = @min(20.0, self.saturation + 3.0);
    }

    /// Eat cooked (or raw) meat. Restores hunger/saturation only.
    pub fn eat(self: *Player, cooked: bool) void {
        if (cooked) {
            self.hunger = @min(20.0, self.hunger + 6.0);
            self.saturation = @min(20.0, self.saturation + 8.0);
        } else {
            self.hunger = @min(20.0, self.hunger + 2.0);
            self.saturation = @min(20.0, self.saturation + 1.0);
        }
    }

    /// True once health hits zero (starve damage is the only source so far).
    pub fn isDead(self: Player) bool {
        return self.health <= 0.0;
    }

    /// Reset vitals + position after death.
    pub fn respawn(self: *Player, x: f32, y: f32, z: f32) void {
        self.pos = math.Vec3.init(x, y, z);
        self.vel_y = 0;
        self.health = 20.0;
        self.hunger = 20.0;
        self.saturation = 5.0;
        self.regen_timer = 0.0;
        self.spawn_point = self.pos;
    }

    pub const hunger_drain: f32 = 0.05;
    pub const regen_rate: f32 = 0.8;
    pub const passive_heal_rate: f32 = 0.4;
    pub const starve_rate: f32 = 0.5;
    pub const heal_hunger_threshold: f32 = 14.0;

    /// Passive drain: hunger falls over time, health regen/suffer follows.
    pub fn tickVitals(self: *Player, dt: f32) void {
        self.regen_timer = @max(0.0, self.regen_timer - dt);
        if (self.regen_timer > 0.0 and self.health < 20.0) {
            self.health = @min(20.0, self.health + dt * regen_rate);
        }
        self.hunger = @max(0.0, self.hunger - dt * hunger_drain);
        if (self.hunger > heal_hunger_threshold and self.health < 20.0) {
            self.health = @min(20.0, self.health + dt * passive_heal_rate);
        } else if (self.hunger <= 0.0 and self.health > 0.0) {
            self.health = @max(0.0, self.health - dt * starve_rate);
        }
    }

    pub fn eyePos(self: Player) math.Vec3 {
        return math.Vec3.init(self.pos.x, self.pos.y + 1.62, self.pos.z);
    }

    /// Advance physics by dt. Optional `ladder` fn detects climbing.
    pub fn tickLadder(self: *Player, solid: *const fn (x: i32, y: i32, z: i32) bool, ladder: ?*const fn (x: i32, y: i32, z: i32) bool, move_x: f32, move_z: f32, jump: bool, dt: f32) void {
        const clamped_dt = @min(dt, 0.05);
        const on_ladder = if (ladder) |l| isInsideLadder(self.pos, self.radius, self.height, l) else false;
        const old_x = self.pos.x;
        const old_z = self.pos.z;

        self.pos.x = moveAxis(self.pos, self.radius, self.height, solid, move_x, .x);
        self.pos.z = moveAxis(self.pos, self.radius, self.height, solid, move_z, .z);

        if (self.on_ground) {
            const dx = self.pos.x - old_x;
            const dz = self.pos.z - old_z;
            self.distance_walked += @sqrt(dx * dx + dz * dz);
        }

        if (on_ladder) {
            // Ladders: gravity halted; jump climbs up, quiet slide down
            self.vel_y = if (jump) 4.5 else 0.0;
            self.on_ground = false;
        } else {
            if (jump and self.on_ground) {
                self.vel_y = 8.0;
                self.on_ground = false;
            }
            self.vel_y -= 25.0 * clamped_dt;
            if (self.vel_y < -30.0) self.vel_y = -30.0;
        }
        self.pos.y = collideAxis(self.pos, self.radius, self.height, solid, self.vel_y * clamped_dt, Axis.y, &self.vel_y, &self.on_ground);
    }

    pub fn tick(self: *Player, solid: *const fn (x: i32, y: i32, z: i32) bool, move_x: f32, move_z: f32, jump: bool, dt: f32) void {
        self.tickLadder(solid, null, move_x, move_z, jump, dt);
    }

};

const Axis = enum { x, y, z };

/// Move one axis, clamped at collision. For y, reports landing/ceiling via out params.
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
            // Re-check horizontal snap: if still colliding (corner), revert.
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

// Horizontal move without velocity/ground reporting.
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
    return y <= 0; // floor plane at y=0
}

test "player falls and lands on floor" {
    var p = Player.init(0.5, 5, 0.5);
    var i: usize = 0;
    while (i < 300) : (i += 1) p.tick(&testSolid, 0, 0, false, 1.0 / 60.0);
    try std.testing.expect(p.on_ground);
    try std.testing.expectApproxEqAbs(p.pos.y, 1.0, 0.05);
}

test "player jump rises and falls back" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.on_ground = true;
    p.tick(&testSolid, 0, 0, true, 1.0 / 60.0);
    try std.testing.expect(p.vel_y > 0);
    var i: usize = 0;
    while (i < 300) : (i += 1) p.tick(&testSolid, 0, 0, false, 1.0 / 60.0);
    try std.testing.expect(p.on_ground);
    try std.testing.expectApproxEqAbs(p.pos.y, 1.0, 0.05);
}

fn wallSolid(x: i32, y: i32, z: i32) bool {
    _ = z;
    if (y <= 0) return true;
    return x >= 2 and y <= 3; // wall at x>=2 (any z)
}

test "player blocked by wall" {
    var p = Player.init(0.5, 1.0, 0.5);
    var i: usize = 0;
    while (i < 120) : (i += 1) p.tick(&wallSolid, 10.0 * 1.0 / 60.0, 0, false, 1.0 / 60.0);
    try std.testing.expect(p.pos.x < 2.0 - p.radius);
}

test "player walking updates distance_walked" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.on_ground = true;
    p.tick(&testSolid, 1.0, 0, false, 0.016);
    try std.testing.expect(p.distance_walked > 0.0);
}

test "player eat restores hunger" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.hunger = 10.0;
    p.saturation = 0.0;
    p.eat(true);
    try std.testing.expectApproxEqAbs(p.hunger, 16.0, 0.001);
    try std.testing.expectApproxEqAbs(p.saturation, 8.0, 0.001);
    p.eat(false);
    try std.testing.expectApproxEqAbs(p.hunger, 18.0, 0.001);
}

test "player vitals drain and regen" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.health = 10.0;
    p.hunger = 20.0;
    p.tickVitals(1.0);
    try std.testing.expect(p.health > 10.0);
    p.hunger = 0.0;
    const h = p.health;
    p.tickVitals(1.0);
    try std.testing.expect(p.health < h);
}

test "player death and respawn" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.health = 0.4;
    p.hunger = 0.0;
    p.tickVitals(1.0);
    try std.testing.expect(p.isDead());
    p.respawn(24.0, 20.0, 24.0);
    try std.testing.expect(!p.isDead());
    try std.testing.expectApproxEqAbs(p.hunger, 20.0, 0.001);
}

test "golden apple heals and regens" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.health = 10.0;
    p.eatGolden();
    try std.testing.expectApproxEqAbs(p.health, 16.0, 0.001);
    try std.testing.expect(p.regen_timer > 0.0);
    p.tickVitals(1.0);
    try std.testing.expect(p.health > 16.0);
}

fn isInsideLadder(pos: math.Vec3, radius: f32, height: f32, ladder: *const fn (x: i32, y: i32, z: i32) bool) bool {
    const min_y: i32 = @intFromFloat(@floor(pos.y));
    const max_y: i32 = @intFromFloat(@floor(pos.y + height));
    var yb = min_y;
    while (yb <= max_y) : (yb += 1) {
        for ([2]f32{ pos.x - radius, pos.x + radius }) |sx| {
            for ([2]f32{ pos.z - radius, pos.z + radius }) |sz| {
                const xb: i32 = @intFromFloat(@floor(sx));
                const zb: i32 = @intFromFloat(@floor(sz));
                if (ladder(xb, yb, zb)) return true;
            }
        }
    }
    return false;
}

fn dummySolid(x: i32, y: i32, z: i32) bool {
    _ = x; _ = z;
    return y <= 0;
}
fn testLadder(x: i32, y: i32, z: i32) bool {
    _ = x; _ = z;
    return y >= 1 and y <= 3;
}
test "player climbs ladder when jumping" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.tickLadder(&dummySolid, &testLadder, 0, 0, true, 0.05);
    try std.testing.expect(p.vel_y > 0.0);
}
