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
    in_water: bool,
    in_boat: bool,
    water_entry_speed: f32,
    oxygen: f32,
    on_soulsand: bool = false,
    in_cobweb: bool = false,
    has_soul_speed: bool = false,
    in_bubble_column: bool = false,
    in_whirlpool: bool = false,
    fire_resistance_timer: f32 = 0.0,
    wither_timer: f32 = 0.0,
    poison_timer: f32 = 0.0,
    weakness_timer: f32 = 0.0,
    lodestone_target: ?math.Vec3 = null,

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
            .in_water = false,
            .in_boat = false,
            .water_entry_speed = 0.0,
            .oxygen = 15.0,
        };
    }

    /// Fire Resistance Potion: grants 3 minutes (180s) of complete immunity to fire, lava, and magma heat.
    pub fn drinkFireResistance(self: *Player) void {
        self.fire_resistance_timer = 180.0;
    }

    pub fn isFireImmune(self: Player) bool {
        return self.fire_resistance_timer > 0.0;
    }

    /// Golden apple: instant heal + regen timer. Cleanses wither.
    /// ponytail: dedicated milk bucket + cow milking cures instead when passive mobs expand.
    pub fn eatGolden(self: *Player) void {
        self.health = @min(20.0, self.health + 6.0);
        self.hunger = @min(20.0, self.hunger + 4.0);
        self.saturation = @min(20.0, self.saturation + 6.0);
        self.regen_timer = 30.0;
        self.wither_timer = 0.0;
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
        self.wither_timer = 0.0;
        self.in_water = false;
        self.in_boat = false;
        self.oxygen = 15.0;
        self.spawn_point = self.pos;
    }

    pub const hunger_drain: f32 = 0.05;
    pub const regen_rate: f32 = 0.8;
    pub const passive_heal_rate: f32 = 0.4;
    pub const starve_rate: f32 = 0.5;
    pub const heal_hunger_threshold: f32 = 14.0;

    /// Passive drain: hunger falls over time, health regen/suffer follows.
    pub const wither_duration: f32 = 8.0;
    pub const wither_rate: f32 = 1.0;
    pub const poison_duration: f32 = 10.0;
    pub const poison_rate: f32 = 1.0;

    pub fn applyPoison(self: *Player) void {
        self.poison_timer = poison_duration;
    }

    pub fn isPoisoned(self: Player) bool {
        return self.poison_timer > 0.0;
    }

    pub const weakness_duration: f32 = 15.0;

    pub fn applyWeakness(self: *Player) void {
        self.weakness_timer = weakness_duration;
    }

    pub fn isWeakened(self: Player) bool {
        return self.weakness_timer > 0.0;
    }

    pub fn applyWither(self: *Player) void {
        self.wither_timer = wither_duration;
    }

    pub fn isWithered(self: Player) bool {
        return self.wither_timer > 0.0;
    }

    pub fn tickVitals(self: *Player, dt: f32) void {
        self.fire_resistance_timer = @max(0.0, self.fire_resistance_timer - dt);
        self.regen_timer = @max(0.0, self.regen_timer - dt);
        self.wither_timer = @max(0.0, self.wither_timer - dt);
        self.poison_timer = @max(0.0, self.poison_timer - dt);
        self.weakness_timer = @max(0.0, self.weakness_timer - dt);
        if (self.wither_timer > 0.0 and self.health > 0.0) {
            self.health = @max(0.0, self.health - dt * wither_rate);
        }
        // Poison damage cannot reduce player health below 1.0 HP (unlike Wither which kills)
        if (self.poison_timer > 0.0 and self.health > 1.0) {
            self.health = @max(1.0, self.health - dt * poison_rate);
        }
        // Wither and Poison suppress all healing while active.
        const debuffed = self.wither_timer > 0.0 or self.poison_timer > 0.0;
        if (!debuffed and self.regen_timer > 0.0 and self.health < 20.0) {
            self.health = @min(20.0, self.health + dt * regen_rate);
        }
        self.hunger = @max(0.0, self.hunger - dt * hunger_drain);
        if (!debuffed and self.hunger > heal_hunger_threshold and self.health < 20.0) {
            self.health = @min(20.0, self.health + dt * passive_heal_rate);
        } else if (self.hunger <= 0.0 and self.health > 0.0) {
            self.health = @max(0.0, self.health - dt * starve_rate);
        }
    }

    pub fn eyePos(self: Player) math.Vec3 {
        return math.Vec3.init(self.pos.x, self.pos.y + 1.62, self.pos.z);
    }

        pub const boat_horizontal_speed_scale: f32 = 2.2;
    pub const water_horizontal_speed_scale: f32 = 0.65;
    pub const soulsand_horizontal_speed_scale: f32 = 0.40; // Soul sand slow drag
    pub const cobweb_horizontal_speed_scale: f32 = 0.15; // Cobweb heavy drag
    pub const soulsand_speed_boost_scale: f32 = 1.40; // Soul speed boots acceleration
    pub const bubble_column_lift_speed: f32 = 6.5; // Upward bubble elevator surge
    pub const whirlpool_pull_speed: f32 = -7.0; // Downward magma whirlpool pull
    pub const water_sink_speed: f32 = -2.5;
    pub const water_current_push_speed: f32 = 1.4;
    pub const water_swim_speed: f32 = 3.5;
    pub const water_drag_rate: f32 = 8.0;

    /// Advance physics by dt. Optional `ladder` detects climbing; `fluid` detects water buoyancy/swimming.
    pub fn tickPhysicsFull(self: *Player, solid: *const fn (x: i32, y: i32, z: i32) bool, ladder: ?*const fn (x: i32, y: i32, z: i32) bool, fluid: ?*const fn (x: i32, y: i32, z: i32) bool, hay: ?*const fn (x: i32, y: i32, z: i32) bool, move_x: f32, move_z: f32, jump: bool, dt: f32) void {
        const clamped_dt = @min(dt, 0.05);
        const on_ladder = if (ladder) |l| isInsideLadder(self.pos, self.radius, self.height, l) else false;
        const now_in_water = if (fluid) |f| isInsideWater(self.pos, self.radius, self.height, f) else false;
        if (now_in_water and !self.in_water) {
            self.water_entry_speed = -self.vel_y;
        } else if (!now_in_water) {
            self.water_entry_speed = 0.0;
        }
        self.in_water = now_in_water;
        const old_x = self.pos.x;
        const old_z = self.pos.z;

        // Check floor block under player for soul sand drag

        const speed_scale = if (self.in_boat and self.in_water)
            boat_horizontal_speed_scale
        else if (self.in_water)
            water_horizontal_speed_scale
        else if (self.in_cobweb)
            cobweb_horizontal_speed_scale
        else if (self.on_soulsand and self.has_soul_speed)
            soulsand_speed_boost_scale
        else if (self.on_soulsand)
            soulsand_horizontal_speed_scale
        else
            1.0;
        var effective_move_x = move_x * speed_scale;
        var effective_move_z = move_z * speed_scale;

        // Water current push: if inside water, compute lateral flow gradient and push player
        if (self.in_water and fluid != null) {
            const f = fluid.?;
            const px_i: i32 = @intFromFloat(@floor(self.pos.x));
            const py_i: i32 = @intFromFloat(@floor(self.pos.y + 0.2));
            const pz_i: i32 = @intFromFloat(@floor(self.pos.z));
            const cur = computeWaterFlowVector(px_i, py_i, pz_i, f);
            effective_move_x += cur[0] * water_current_push_speed * clamped_dt;
            effective_move_z += cur[1] * water_current_push_speed * clamped_dt;
        }

        self.pos.x = moveAxis(self.pos, self.radius, self.height, solid, effective_move_x, .x);
        self.pos.z = moveAxis(self.pos, self.radius, self.height, solid, effective_move_z, .z);

        if (self.on_ground) {
            const dx = self.pos.x - old_x;
            const dz = self.pos.z - old_z;
            self.distance_walked += @sqrt(dx * dx + dz * dz);
        }

        if (on_ladder) {
            // Ladders: gravity halted; jump climbs up, quiet slide down
            self.vel_y = if (jump) 4.5 else 0.0;
            self.on_ground = false;
        } else if (self.in_boat and self.in_water) {
            // Boat cruising: floats on surface, buoyant upward force counters sink
            self.vel_y = @min(1.0, self.vel_y + 12.0 * clamped_dt);
            self.on_ground = false;
        } else if (self.in_water) {
            // Water: vertical drag dampens falls; holding jump swims up; otherwise sinks slowly
            self.vel_y *= @max(0.0, 1.0 - water_drag_rate * clamped_dt);
            if (self.in_whirlpool) {
                // Downward magma whirlpool drags player down to seafloor
                self.vel_y = @min(self.vel_y, whirlpool_pull_speed);
            } else if (self.in_bubble_column) {
                // Upward bubble column surge pushes player rapidly to surface
                self.vel_y = @max(self.vel_y, bubble_column_lift_speed);
                self.on_ground = false;
            } else if (jump) {
                self.vel_y = water_swim_speed;
                self.on_ground = false;
            } else {
                self.vel_y -= 6.0 * clamped_dt;
                if (self.vel_y < water_sink_speed) self.vel_y = water_sink_speed;
            }
        } else {
            if (jump and self.on_ground) {
                self.vel_y = 8.0;
                self.on_ground = false;
            }
            self.vel_y -= 25.0 * clamped_dt;
            if (self.vel_y < -30.0) self.vel_y = -30.0;
        }
        const was_airborne = !self.on_ground;
        const fall_speed = if (self.in_water) 0.0 else self.vel_y;
        self.pos.y = collideAxis(self.pos, self.radius, self.height, solid, self.vel_y * clamped_dt, Axis.y, &self.vel_y, &self.on_ground);
        if (was_airborne and self.on_ground) {
            const floor_y = @as(i32, @intFromFloat(@floor(self.pos.y - 0.1)));
            const floor_x = @as(i32, @intFromFloat(@floor(self.pos.x)));
            const floor_z = @as(i32, @intFromFloat(@floor(self.pos.z)));
            const is_hay = if (hay) |h| h(floor_x, floor_y, floor_z) else false;
            const dmg = fallDamageOnSurface(fall_speed, is_hay);
            if (dmg > 0.0) self.health = @max(0.0, self.health - dmg);
        }
    }

    pub fn tickPhysics(self: *Player, solid: *const fn (x: i32, y: i32, z: i32) bool, ladder: ?*const fn (x: i32, y: i32, z: i32) bool, fluid: ?*const fn (x: i32, y: i32, z: i32) bool, move_x: f32, move_z: f32, jump: bool, dt: f32) void {
        self.tickPhysicsFull(solid, ladder, fluid, null, move_x, move_z, jump, dt);
    }

    pub fn tickLadder(self: *Player, solid: *const fn (x: i32, y: i32, z: i32) bool, ladder: ?*const fn (x: i32, y: i32, z: i32) bool, move_x: f32, move_z: f32, jump: bool, dt: f32) void {
        self.tickPhysics(solid, ladder, null, move_x, move_z, jump, dt);
    }

    pub const safe_fall_speed: f32 = 12.0;
    pub const fall_damage_scale: f32 = 1.5;
    pub const hay_cushion_multiplier: f32 = 0.20; // 80% fall damage reduction when landing on hay bale

    pub fn fallDamage(impact_vy: f32) f32 {
        return fallDamageOnSurface(impact_vy, false);
    }

    pub fn fallDamageOnSurface(impact_vy: f32, is_hay: bool) f32 {
        const excess = -impact_vy - safe_fall_speed;
        if (excess <= 0.0) return 0.0;
        const raw = excess * fall_damage_scale;
        return if (is_hay) raw * hay_cushion_multiplier else raw;
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

test "wither effect drains health over 8s" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.health = 10.0;
    p.hunger = 10.0;
    p.applyWither();
    try std.testing.expect(p.isWithered());
    p.tickVitals(3.0);
    try std.testing.expectApproxEqAbs(p.health, 7.0, 0.001);
    try std.testing.expect(p.isWithered());
    p.tickVitals(5.0);
    try std.testing.expectApproxEqAbs(p.health, 7.0, 0.001);
    try std.testing.expect(!p.isWithered());
    p.applyWither();
    p.tickVitals(7.0);
    try std.testing.expectApproxEqAbs(p.health, 0.0, 0.001);
    p.respawn(0, 1, 0);
    try std.testing.expect(!p.isWithered());

    // Wither suppresses golden-apple regen and passive healing.
    var q = Player.init(0.5, 1.0, 0.5);
    q.health = 10.0;
    q.hunger = 20.0;
    q.regen_timer = 30.0;
    q.applyWither();
    q.tickVitals(2.0);
    try std.testing.expectApproxEqAbs(q.health, 8.0, 0.001);
    q.eatGolden();
    try std.testing.expect(!q.isWithered());
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

fn isInsideBlock(pos: math.Vec3, radius: f32, height: f32, check_fn: *const fn (x: i32, y: i32, z: i32) bool) bool {
    const min_y: i32 = @intFromFloat(@floor(pos.y));
    const max_y: i32 = @intFromFloat(@floor(pos.y + height));
    var yb = min_y;
    while (yb <= max_y) : (yb += 1) {
        for ([2]f32{ pos.x - radius, pos.x + radius }) |sx| {
            for ([2]f32{ pos.z - radius, pos.z + radius }) |sz| {
                const xb: i32 = @intFromFloat(@floor(sx));
                const zb: i32 = @intFromFloat(@floor(sz));
                if (check_fn(xb, yb, zb)) return true;
            }
        }
    }
    return false;
}

pub fn isInsideLadder(pos: math.Vec3, radius: f32, height: f32, ladder: *const fn (x: i32, y: i32, z: i32) bool) bool {
    return isInsideBlock(pos, radius, height, ladder);
}

pub fn isInsideWater(pos: math.Vec3, radius: f32, height: f32, fluid: *const fn (x: i32, y: i32, z: i32) bool) bool {
    return isInsideBlock(pos, radius, height, fluid);
}

fn dummySolid(x: i32, y: i32, z: i32) bool {
    _ = x; _ = z;
    return y <= 0;
}
fn testLadder(x: i32, y: i32, z: i32) bool {
    _ = x; _ = z;
    return y >= 1 and y <= 3;
}
fn testWater(x: i32, y: i32, z: i32) bool {
    _ = x; _ = z;
    return y >= 1 and y <= 6;
}

test "player swimming buoyancy sinks slowly and swims up on jump" {
    var p = Player.init(0.5, 3.0, 0.5);
    // Sink slowly without jump
    p.tickPhysics(&dummySolid, null, &testWater, 0, 0, false, 0.05);
    try std.testing.expect(p.in_water);
    try std.testing.expect(p.vel_y >= Player.water_sink_speed);
    try std.testing.expect(p.vel_y < 0.0);

    // Swim upward on jump
    p.tickPhysics(&dummySolid, null, &testWater, 0, 0, true, 0.05);
    try std.testing.expectEqual(p.vel_y, Player.water_swim_speed);
}

test "water absorbs fall impact damage" {
    var p = Player.init(0.5, 2.0, 0.5);
    p.vel_y = -25.0; // High lethal falling speed
    p.tickPhysics(&dummySolid, null, &testWater, 0, 0, false, 0.05);
    try std.testing.expect(p.in_water);
    // Health is not damaged by hard landing in water
    try std.testing.expectEqual(p.health, 20.0);
}

test "player climbs ladder when jumping" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.tickLadder(&dummySolid, &testLadder, 0, 0, true, 0.05);
    try std.testing.expect(p.vel_y > 0.0);
}

test "fall damage thresholds" {
    try std.testing.expectEqual(Player.fallDamage(0.0), 0.0);
    try std.testing.expectEqual(Player.fallDamage(-12.0), 0.0);
    try std.testing.expect(Player.fallDamage(-20.0) > 0.0);
    try std.testing.expect(Player.fallDamage(-30.0) > Player.fallDamage(-20.0));
    try std.testing.expectApproxEqAbs(Player.fallDamageOnSurface(-22.0, true), Player.fallDamage(-22.0) * 0.20, 0.001);
}

test "player landing on hay bale reduces fall damage by 80 percent" {
    var player = Player.init(0.5, 1.5, 0.5);
    player.vel_y = -20.0;
    const FakeWorld = struct {
        fn solid(_: i32, y: i32, _: i32) bool {
            return y <= 0;
        }
        fn hay(_: i32, y: i32, _: i32) bool {
            return y == 0;
        }
    };
    player.tickPhysicsFull(FakeWorld.solid, null, null, FakeWorld.hay, 0.0, 0.0, false, 0.05);
    // Standard damage for -20.0: (-(-20) - 12) * 1.5 = 12.0 dmg -> 8.0 hp left
    // With 80% reduction: 12.0 * 0.20 = 2.4 dmg -> 17.6 hp left
    try std.testing.expectApproxEqAbs(@as(f32, 17.225), player.health, 0.05);
}

pub const WalkVectors = struct {
    fwd: math.Vec3,
    right: math.Vec3,
};

pub fn computeWalkVectors(cam_fwd: math.Vec3) WalkVectors {
    const flat_f = math.Vec3.init(cam_fwd.x, 0, cam_fwd.z);
    const flat_len = math.Vec3.len(flat_f);
    const walk_f = if (flat_len > 0.001) flat_f.scale(1.0 / flat_len) else math.Vec3.init(0, 0, -1);
    const walk_r = math.Vec3.normalize(math.Vec3.cross(walk_f, math.Vec3.init(0, 1, 0)));
    return .{ .fwd = walk_f, .right = walk_r };
}

pub fn computeWishDirection(vectors: WalkVectors, w: bool, s: bool, d: bool, a: bool, blocked: bool) math.Vec3 {
    if (blocked) return math.Vec3.init(0, 0, 0);
    var wish = math.Vec3.init(0, 0, 0);
    if (w) wish = math.Vec3.add(wish, vectors.fwd);
    if (s) wish = math.Vec3.sub(wish, vectors.fwd);
    if (d) wish = math.Vec3.add(wish, vectors.right);
    if (a) wish = math.Vec3.sub(wish, vectors.right);
    const len = math.Vec3.len(wish);
    if (len > 0.001) {
        return wish.scale(1.0 / len);
    }
    return math.Vec3.init(0, 0, 0);
}

test "compute walk vectors and normalized wish" {
    const fwd = math.Vec3.init(0, -0.5, 1.0);
    const wv = computeWalkVectors(fwd);
    try std.testing.expectApproxEqAbs(wv.fwd.y, 0.0, 0.0001);
    try std.testing.expect(math.Vec3.len(wv.fwd) > 0.999);
    try std.testing.expect(math.Vec3.len(wv.right) > 0.999);

    const wish_fwd = computeWishDirection(wv, true, false, false, false, false);
    try std.testing.expectApproxEqAbs(wish_fwd.x, wv.fwd.x, 0.0001);
    try std.testing.expectApproxEqAbs(wish_fwd.z, wv.fwd.z, 0.0001);

    const wish_blocked = computeWishDirection(wv, true, false, false, false, true);
    try std.testing.expectEqual(math.Vec3.len(wish_blocked), 0.0);
}

/// Compute lateral water flow vector based on open boundaries.
pub fn computeWaterFlowVector(x: i32, y: i32, z: i32, is_fluid: *const fn (x: i32, y: i32, z: i32) bool) [2]f32 {
    if (!is_fluid(x, y, z)) return .{ 0.0, 0.0 };
    var px: f32 = 0.0;
    var pz: f32 = 0.0;
    const dirs = [_][2]i32{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };
    for (dirs) |d| {
        if (!is_fluid(x + d[0], y, z + d[1])) {
            px += @floatFromInt(d[0]);
            pz += @floatFromInt(d[1]);
        }
    }
    const len_sq = px * px + pz * pz;
    if (len_sq > 0.0001) {
        const len = @sqrt(len_sq);
        return .{ px / len, pz / len };
    }
    return .{ 0.0, 0.0 };
}

test "player water current lateral push" {
    var p = Player.init(0.5, 5.0, 0.5);
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn water(x: i32, y: i32, z: i32) bool {
            // Water at x <= 0 and current cell (0, 5, 0), open to east (+x > 0)
            return x <= 0 and y == 5 and z == 0;
        }
    };

    // Before tick in water: pos.x is 0.5
    try std.testing.expectEqual(@as(f32, 0.5), p.pos.x);
    // Tick with zero player movement input (move_x=0, move_z=0)
    p.tickPhysics(Mock.solid, null, Mock.water, 0.0, 0.0, false, 0.05);
    // Water current should push player towards east (+X)
    try std.testing.expect(p.pos.x > 0.5);
}

test "player water entry landing impact speed recorded" {
    var p = Player.init(0.5, 6.0, 0.5);
    p.vel_y = -10.0;
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn water(_: i32, y: i32, _: i32) bool { return y <= 4; }
    };
    try std.testing.expectEqual(@as(f32, 0.0), p.water_entry_speed);
    // Step 1: falls from 6.0 towards water
    p.tickPhysics(Mock.solid, null, Mock.water, 0.0, 0.0, false, 0.05);
    // Continue falling until inside water
    while (!p.in_water) {
        p.tickPhysics(Mock.solid, null, Mock.water, 0.0, 0.0, false, 0.05);
    }
    try std.testing.expect(p.in_water);
    try std.testing.expect(p.water_entry_speed > 9.0);
}

test "player boat water cruising and floatation speed" {
    var p = Player.init(0.5, 2.0, 0.5);
    p.in_boat = true;
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn water(_: i32, _: i32, _: i32) bool { return true; }
    };
    // Tick with forward movement 1.0
    p.tickPhysics(Mock.solid, null, Mock.water, 1.0, 0.0, false, 0.05);
    try std.testing.expect(p.in_water);
    try std.testing.expect(p.in_boat);
    // Boat movement scale (2.2) is higher than normal water scale (0.65)
    try std.testing.expect(p.pos.x > 0.5 + 1.0 * Player.water_horizontal_speed_scale * 0.9);
    // Boat lifts player upward in water
    try std.testing.expect(p.vel_y > 0.0);
}

test "player soul sand speed drag deceleration" {
    var p = Player.init(0.5, 2.0, 0.5);
    p.on_ground = true;
    p.on_soulsand = true;
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
    };
    p.tickPhysics(Mock.solid, null, null, 1.0, 0.0, false, 0.05);
    // Player speed reduced to 40% (0.40) on soul sand
    try std.testing.expectApproxEqAbs(@as(f32, 0.5 + 1.0 * Player.soulsand_horizontal_speed_scale), p.pos.x, 0.001);
}

test "player soul sand bubble column upward surge" {
    var p = Player.init(0.5, 2.0, 0.5);
    p.in_bubble_column = true;
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn water(_: i32, _: i32, _: i32) bool { return true; }
    };
    p.tickPhysics(Mock.solid, null, Mock.water, 0.0, 0.0, false, 0.05);
    try std.testing.expect(p.in_water);
    // Bubble column propels player upwards >= 6.5 m/s
    try std.testing.expect(p.vel_y >= 6.0);
}

test "player magma whirlpool downward drag" {
    var p = Player.init(0.5, 5.0, 0.5);
    p.in_whirlpool = true;
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
        fn water(_: i32, _: i32, _: i32) bool { return true; }
    };
    p.tickPhysics(Mock.solid, null, Mock.water, 0.0, 0.0, false, 0.05);
    try std.testing.expect(p.in_water);
    // Whirlpool pulls player downwards <= -7.0 m/s
    try std.testing.expect(p.vel_y <= -6.5);
}

test "player fire resistance duration and immunity" {
    var p = Player.init(0, 0, 0);
    try std.testing.expect(!p.isFireImmune());
    p.drinkFireResistance();
    try std.testing.expect(p.isFireImmune());
    try std.testing.expectEqual(@as(f32, 180.0), p.fire_resistance_timer);

    p.tickVitals(60.0);
    try std.testing.expect(p.isFireImmune());
    try std.testing.expectEqual(@as(f32, 120.0), p.fire_resistance_timer);

    p.tickVitals(120.0);
    try std.testing.expect(!p.isFireImmune());
    try std.testing.expectEqual(@as(f32, 0.0), p.fire_resistance_timer);
}
test "player lodestone tracking target" {
    var p = Player.init(0.0, 10.0, 0.0);
    try std.testing.expectEqual(p.lodestone_target, null);
    p.lodestone_target = math.Vec3.init(100.0, 64.0, -50.0);
    try std.testing.expect(p.lodestone_target != null);
    try std.testing.expectEqual(p.lodestone_target.?.x, 100.0);
}


test "player soul speed boots acceleration on soul sand" {
    var p = Player.init(0.5, 1.0, 0.5);
    p.on_soulsand = true;
    p.has_soul_speed = true;

    const MockWorld = struct {
        fn solid(_: i32, _: i32, _: i32) bool {
            return false;
        }
    };

    p.tickPhysicsFull(MockWorld.solid, null, null, null, 1.0, 0.0, false, 0.05);

    // Boosted movement: 1.0 * soulsand_speed_boost_scale (1.40)
    try std.testing.expectApproxEqAbs(@as(f32, 0.5 + 1.0 * Player.soulsand_speed_boost_scale), p.pos.x, 0.001);
}

test "cobweb entity movement retardation drag" {
    var p = Player.init(0.5, 2.0, 0.5);
    p.on_ground = true;
    p.in_cobweb = true;
    const Mock = struct {
        fn solid(_: i32, _: i32, _: i32) bool { return false; }
    };
    p.tickPhysics(Mock.solid, null, null, 1.0, 0.0, false, 0.05);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5 + 1.0 * Player.cobweb_horizontal_speed_scale), p.pos.x, 0.001);
}

test "player poison effect drains health down to 1 HP floor" {
    var p = Player.init(0, 0, 0);
    p.health = 5.0;
    p.applyPoison();
    try std.testing.expect(p.isPoisoned());
    try std.testing.expectEqual(@as(f32, 10.0), p.poison_timer);

    p.tickVitals(2.0);
    try std.testing.expectEqual(@as(f32, 3.0), p.health);

    p.tickVitals(5.0);
    // Should clamp at 1.0 HP floor
    try std.testing.expectEqual(@as(f32, 1.0), p.health);
}

test "player weakness effect timer decay and status" {
    var p = Player.init(0, 0, 0);
    try std.testing.expect(!p.isWeakened());
    p.applyWeakness();
    try std.testing.expect(p.isWeakened());
    try std.testing.expectEqual(@as(f32, 15.0), p.weakness_timer);

    p.tickVitals(5.0);
    try std.testing.expectEqual(@as(f32, 10.0), p.weakness_timer);
    try std.testing.expect(p.isWeakened());

    p.tickVitals(11.0);
    try std.testing.expectEqual(@as(f32, 0.0), p.weakness_timer);
    try std.testing.expect(!p.isWeakened());
}
