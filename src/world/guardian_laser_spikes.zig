const std = @import("std");

pub const MAX_HEALTH: f32 = 30.0;
pub const SWIM_SPEED: f32 = 2.4;
pub const LAND_SPEED: f32 = 0.6;
pub const LASER_ACQUIRE_RANGE: f32 = 15.0;
pub const LASER_MAX_TRACK_RANGE: f32 = 16.0;
pub const LASER_CHARGE_TICKS: u8 = 60;
pub const SPIKE_COUNT: u8 = 12;
pub const THORNS_DAMAGE: f32 = 2.0;
pub const SUFFOCATION_INTERVAL_TICKS: u8 = 10;
pub const SUFFOCATION_DAMAGE: f32 = 1.0;
pub const TICKS_PER_SECOND: f32 = 20.0;
pub const SPIKE_COLOR: [4]f32 = .{ 1.0, 0.28, 0.06, 1.0 };

pub const Vec3 = [3]f32;
pub const Difficulty = enum { easy, normal, hard };
pub const BeamColor = enum { purple_red, bright_yellow };
pub const Drop = enum { prismarine_shard, prismarine_crystal, raw_cod };

pub const BeamEvent = struct {
    fired: bool = false,
    target_id: ?u32 = null,
    damage: f32 = 0.0,
    unmitigated_magic: bool = false,
    color: BeamColor = .purple_red,
};

pub const DamageEvent = struct {
    guardian_damage: f32,
    thorns_damage: f32,
};

pub const MovementEvent = struct {
    suffocation_damage: f32 = 0.0,
    hopped: bool = false,
};

pub const Guardian = struct {
    position: Vec3 = .{ 0.0, 0.0, 0.0 },
    velocity: Vec3 = .{ 0.0, 0.0, 0.0 },
    health: f32 = MAX_HEALTH,
    laser_target_id: ?u32 = null,
    laser_charge_ticks: u8 = 0,
    spikes_extended: bool = true,
    out_of_water_ticks: u8 = 0,

    pub fn beamColor(self: Guardian) BeamColor {
        return if (self.laser_charge_ticks >= LASER_CHARGE_TICKS) .bright_yellow else .purple_red;
    }

    /// Acquires a visible target at up to 15m, then keeps tracking it to 16m.
    /// One call advances exactly one game tick.
    pub fn tickLaser(
        self: *Guardian,
        candidate_target_id: ?u32,
        distance: f32,
        has_line_of_sight: bool,
        difficulty: Difficulty,
    ) BeamEvent {
        if (self.health <= 0.0) return .{};

        if (self.laser_target_id) |target_id| {
            if (candidate_target_id != target_id or !has_line_of_sight or distance < 0.0 or distance > LASER_MAX_TRACK_RANGE) {
                self.cancelLaser();
                return .{};
            }
        } else {
            const target_id = candidate_target_id orelse return .{};
            if (!has_line_of_sight or distance < 0.0 or distance > LASER_ACQUIRE_RANGE) return .{};
            self.laser_target_id = target_id;
        }

        self.laser_charge_ticks += 1;
        if (self.laser_charge_ticks < LASER_CHARGE_TICKS) return .{ .target_id = self.laser_target_id };

        const target_id = self.laser_target_id;
        self.cancelLaser();
        return .{
            .fired = true,
            .target_id = target_id,
            .damage = beamDamage(difficulty),
            .unmitigated_magic = true,
            .color = .bright_yellow,
        };
    }

    pub fn cancelLaser(self: *Guardian) void {
        self.laser_target_id = null;
        self.laser_charge_ticks = 0;
    }

    /// Spikes stay out while stationary or attacking and retract during movement.
    pub fn updateSpikes(self: *Guardian, is_moving: bool, is_attacking: bool) void {
        self.spikes_extended = !is_moving or is_attacking;
    }

    /// Applies normal incoming damage and reports two HP retaliation when the
    /// orange spikes are extended. Damage application stays with the caller.
    pub fn receiveAttack(self: *Guardian, incoming_damage: f32, attacker_present: bool) DamageEvent {
        const damage = @max(incoming_damage, 0.0);
        const applied = @min(self.health, damage);
        self.health -= applied;
        return .{
            .guardian_damage = applied,
            .thorns_damage = if (attacker_present and self.spikes_extended) THORNS_DAMAGE else 0.0,
        };
    }

    /// Desired movement is normalized and smoothly approached. Land movement
    /// includes an awkward hop and one suffocation damage pulse every 10 ticks.
    pub fn tickMovement(self: *Guardian, desired_direction: Vec3, in_water: bool) MovementEvent {
        const max_speed = if (in_water) SWIM_SPEED else LAND_SPEED;
        const desired = scale(normalize(desired_direction), max_speed);
        const response: f32 = 0.2;
        for (0..3) |axis| {
            self.velocity[axis] += (desired[axis] - self.velocity[axis]) * response;
            self.position[axis] += self.velocity[axis] / TICKS_PER_SECOND;
        }

        if (in_water) {
            self.out_of_water_ticks = 0;
            return .{};
        }
        self.out_of_water_ticks +|= 1;
        if (self.out_of_water_ticks < SUFFOCATION_INTERVAL_TICKS) return .{};
        self.out_of_water_ticks = 0;
        self.velocity[1] = 0.35;
        self.health = @max(self.health - SUFFOCATION_DAMAGE, 0.0);
        return .{ .suffocation_damage = SUFFOCATION_DAMAGE, .hopped = true };
    }
};

pub fn beamDamage(difficulty: Difficulty) f32 {
    return switch (difficulty) {
        .easy => 6.0,
        .normal => 9.0,
        .hard => 12.0,
    };
}

pub fn drops() [3]Drop {
    return .{ .prismarine_shard, .prismarine_crystal, .raw_cod };
}

fn normalize(direction: Vec3) Vec3 {
    const length_squared = direction[0] * direction[0] + direction[1] * direction[1] + direction[2] * direction[2];
    if (length_squared <= 0.000001) return .{ 0.0, 0.0, 0.0 };
    const inverse_length = 1.0 / @sqrt(length_squared);
    return scale(direction, inverse_length);
}

fn scale(vector: Vec3, amount: f32) Vec3 {
    return .{ vector[0] * amount, vector[1] * amount, vector[2] * amount };
}

test "Guardian has a 30 HP health pool and starts with extended spikes" {
    const guardian = Guardian{};
    try std.testing.expectEqual(@as(f32, 30.0), guardian.health);
    try std.testing.expect(guardian.spikes_extended);
}

test "Guardian uses the requested swim and land speeds" {
    try std.testing.expectEqual(@as(f32, 2.4), SWIM_SPEED);
    try std.testing.expectEqual(@as(f32, 0.6), LAND_SPEED);
}

test "water movement accelerates smoothly instead of jumping to top speed" {
    var guardian = Guardian{};
    _ = guardian.tickMovement(.{ 1.0, 0.0, 0.0 }, true);
    try std.testing.expect(guardian.velocity[0] > 0.0);
    try std.testing.expect(guardian.velocity[0] < SWIM_SPEED);
}

test "water movement approaches the 2.4 meters per second swim speed" {
    var guardian = Guardian{};
    for (0..30) |_| _ = guardian.tickMovement(.{ 1.0, 0.0, 0.0 }, true);
    try std.testing.expectApproxEqAbs(SWIM_SPEED, guardian.velocity[0], 0.01);
}

test "water movement normalizes diagonal input to swim speed" {
    var guardian = Guardian{};
    for (0..30) |_| _ = guardian.tickMovement(.{ 1.0, 0.0, 1.0 }, true);
    const speed = @sqrt(guardian.velocity[0] * guardian.velocity[0] + guardian.velocity[2] * guardian.velocity[2]);
    try std.testing.expectApproxEqAbs(SWIM_SPEED, speed, 0.01);
}

test "water movement resets the land suffocation timer" {
    var guardian = Guardian{ .out_of_water_ticks = 9 };
    _ = guardian.tickMovement(.{ 0.0, 0.0, 0.0 }, true);
    try std.testing.expectEqual(@as(u8, 0), guardian.out_of_water_ticks);
}

test "land movement is slower than water movement" {
    var guardian = Guardian{};
    for (0..30) |_| _ = guardian.tickMovement(.{ 1.0, 0.0, 0.0 }, false);
    try std.testing.expectApproxEqAbs(LAND_SPEED, guardian.velocity[0], 0.01);
}

test "Guardian receives a land suffocation pulse every half second" {
    var guardian = Guardian{};
    for (0..9) |_| try std.testing.expectEqual(@as(f32, 0.0), guardian.tickMovement(.{ 0.0, 0.0, 0.0 }, false).suffocation_damage);
    const event = guardian.tickMovement(.{ 0.0, 0.0, 0.0 }, false);
    try std.testing.expectEqual(SUFFOCATION_DAMAGE, event.suffocation_damage);
    try std.testing.expect(event.hopped);
    try std.testing.expectEqual(@as(f32, 29.0), guardian.health);
}

test "land suffocation timer restarts after its pulse" {
    var guardian = Guardian{ .out_of_water_ticks = 9 };
    _ = guardian.tickMovement(.{ 0.0, 0.0, 0.0 }, false);
    try std.testing.expectEqual(@as(u8, 0), guardian.out_of_water_ticks);
}

test "land hopping adds an upward kick" {
    var guardian = Guardian{ .out_of_water_ticks = 9 };
    const event = guardian.tickMovement(.{ 0.0, 0.0, 0.0 }, false);
    try std.testing.expect(event.hopped);
    try std.testing.expectEqual(@as(f32, 0.35), guardian.velocity[1]);
}

test "laser acquires a visible target at exactly fifteen meters" {
    var guardian = Guardian{};
    _ = guardian.tickLaser(7, 15.0, true, .normal);
    try std.testing.expectEqual(@as(?u32, 7), guardian.laser_target_id);
}

test "laser rejects targets beyond fifteen meters at acquisition" {
    var guardian = Guardian{};
    _ = guardian.tickLaser(7, 15.01, true, .normal);
    try std.testing.expectEqual(@as(?u32, null), guardian.laser_target_id);
}

test "laser rejects targets hidden at acquisition" {
    var guardian = Guardian{};
    _ = guardian.tickLaser(7, 5.0, false, .normal);
    try std.testing.expectEqual(@as(?u32, null), guardian.laser_target_id);
}

test "laser rejects negative target distances" {
    var guardian = Guardian{};
    _ = guardian.tickLaser(7, -1.0, true, .normal);
    try std.testing.expectEqual(@as(?u32, null), guardian.laser_target_id);
}

test "laser starts purple red while charging" {
    var guardian = Guardian{};
    _ = guardian.tickLaser(7, 10.0, true, .normal);
    try std.testing.expectEqual(BeamColor.purple_red, guardian.beamColor());
}

test "laser fires on tick sixty" {
    var guardian = Guardian{};
    for (0..59) |_| try std.testing.expect(!guardian.tickLaser(7, 10.0, true, .normal).fired);
    try std.testing.expect(guardian.tickLaser(7, 10.0, true, .normal).fired);
}

test "laser firing targets the entity acquired at charge start" {
    var guardian = Guardian{};
    for (0..LASER_CHARGE_TICKS - 1) |_| _ = guardian.tickLaser(42, 10.0, true, .normal);
    const event = guardian.tickLaser(42, 10.0, true, .normal);
    try std.testing.expectEqual(@as(?u32, 42), event.target_id);
}

test "laser charge cancels immediately when line of sight breaks" {
    var guardian = Guardian{};
    for (0..30) |_| _ = guardian.tickLaser(7, 10.0, true, .normal);
    _ = guardian.tickLaser(7, 10.0, false, .normal);
    try std.testing.expectEqual(@as(u8, 0), guardian.laser_charge_ticks);
    try std.testing.expectEqual(@as(?u32, null), guardian.laser_target_id);
}

test "laser charge cancels beyond sixteen meters" {
    var guardian = Guardian{};
    _ = guardian.tickLaser(7, 10.0, true, .normal);
    _ = guardian.tickLaser(7, 16.01, true, .normal);
    try std.testing.expectEqual(@as(u8, 0), guardian.laser_charge_ticks);
}

test "laser remains tracked at exactly sixteen meters" {
    var guardian = Guardian{};
    _ = guardian.tickLaser(7, 15.0, true, .normal);
    _ = guardian.tickLaser(7, 16.0, true, .normal);
    try std.testing.expectEqual(@as(u8, 2), guardian.laser_charge_ticks);
}

test "laser charge cancels when its target identity changes" {
    var guardian = Guardian{};
    _ = guardian.tickLaser(7, 10.0, true, .normal);
    _ = guardian.tickLaser(8, 10.0, true, .normal);
    try std.testing.expectEqual(@as(u8, 0), guardian.laser_charge_ticks);
}

test "completed laser deals nine unmitigated magic damage on normal" {
    var guardian = Guardian{};
    for (0..59) |_| _ = guardian.tickLaser(7, 10.0, true, .normal);
    const event = guardian.tickLaser(7, 10.0, true, .normal);
    try std.testing.expectEqual(@as(f32, 9.0), event.damage);
    try std.testing.expect(event.unmitigated_magic);
}

test "completed laser deals six HP on easy" {
    try std.testing.expectEqual(@as(f32, 6.0), beamDamage(.easy));
}

test "completed laser deals twelve HP on hard" {
    try std.testing.expectEqual(@as(f32, 12.0), beamDamage(.hard));
}

test "laser completion emits a bright yellow beam" {
    var guardian = Guardian{};
    for (0..59) |_| _ = guardian.tickLaser(7, 10.0, true, .normal);
    try std.testing.expectEqual(BeamColor.bright_yellow, guardian.tickLaser(7, 10.0, true, .normal).color);
}

test "laser charge resets after firing" {
    var guardian = Guardian{};
    for (0..LASER_CHARGE_TICKS) |_| _ = guardian.tickLaser(7, 10.0, true, .normal);
    try std.testing.expectEqual(@as(u8, 0), guardian.laser_charge_ticks);
    try std.testing.expectEqual(@as(?u32, null), guardian.laser_target_id);
}

test "defeated Guardian cannot charge or fire" {
    var guardian = Guardian{ .health = 0.0 };
    for (0..LASER_CHARGE_TICKS) |_| try std.testing.expect(!guardian.tickLaser(7, 10.0, true, .normal).fired);
    try std.testing.expectEqual(@as(u8, 0), guardian.laser_charge_ticks);
}

test "spikes extend while stationary" {
    var guardian = Guardian{ .spikes_extended = false };
    guardian.updateSpikes(false, false);
    try std.testing.expect(guardian.spikes_extended);
}

test "spikes extend while Guardian attacks even when moving" {
    var guardian = Guardian{ .spikes_extended = false };
    guardian.updateSpikes(true, true);
    try std.testing.expect(guardian.spikes_extended);
}

test "spikes retract during fast swimming" {
    var guardian = Guardian{};
    guardian.updateSpikes(true, false);
    try std.testing.expect(!guardian.spikes_extended);
}

test "attacking Guardian presents twelve orange defense spikes" {
    try std.testing.expectEqual(@as(u8, 12), SPIKE_COUNT);
    try std.testing.expect(SPIKE_COLOR[0] > SPIKE_COLOR[2]);
    try std.testing.expect(SPIKE_COLOR[1] > 0.0);
}

test "extended spikes retaliate for two HP against an attacker" {
    var guardian = Guardian{};
    const event = guardian.receiveAttack(3.0, true);
    try std.testing.expectEqual(@as(f32, 3.0), event.guardian_damage);
    try std.testing.expectEqual(@as(f32, 2.0), event.thorns_damage);
}

test "retracted spikes take normal melee damage without thorns" {
    var guardian = Guardian{ .spikes_extended = false };
    const event = guardian.receiveAttack(4.0, true);
    try std.testing.expectEqual(@as(f32, 4.0), event.guardian_damage);
    try std.testing.expectEqual(@as(f32, 0.0), event.thorns_damage);
}

test "attacks without an attacker do not generate thorns damage" {
    var guardian = Guardian{};
    const event = guardian.receiveAttack(2.0, false);
    try std.testing.expectEqual(@as(f32, 0.0), event.thorns_damage);
}

test "Guardian health damage is clamped at remaining health" {
    var guardian = Guardian{ .health = 1.0 };
    const event = guardian.receiveAttack(5.0, true);
    try std.testing.expectEqual(@as(f32, 1.0), event.guardian_damage);
    try std.testing.expectEqual(@as(f32, 0.0), guardian.health);
}

test "negative incoming damage is ignored" {
    var guardian = Guardian{};
    const event = guardian.receiveAttack(-5.0, true);
    try std.testing.expectEqual(@as(f32, 0.0), event.guardian_damage);
    try std.testing.expectEqual(MAX_HEALTH, guardian.health);
}

test "Guardian drop candidates include prismarine shards" {
    try std.testing.expectEqual(Drop.prismarine_shard, drops()[0]);
}

test "Guardian drop candidates include prismarine crystals" {
    try std.testing.expectEqual(Drop.prismarine_crystal, drops()[1]);
}

test "Guardian drop candidates include raw cod" {
    try std.testing.expectEqual(Drop.raw_cod, drops()[2]);
}
