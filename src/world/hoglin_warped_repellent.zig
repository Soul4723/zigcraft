const std = @import("std");

pub const MAX_HEALTH: f32 = 40.0;
pub const BABY_MAX_HEALTH: f32 = 20.0;
pub const REPELLENT_RADIUS: f32 = 7.0;
pub const FLEE_SPEED: f32 = 4.5;
pub const VERTICAL_TOSS_VELOCITY: f32 = 7.0;
pub const BABY_MATURATION_TICKS: u32 = 24_000;
pub const ZOMBIFICATION_TICKS: u32 = 300;
pub const ZOMBIFICATION_SECONDS: f32 = 15.0;

pub const Difficulty = enum { easy, normal, hard };

pub fn attackDamage(difficulty: Difficulty) f32 {
    return switch (difficulty) {
        .easy => 3.0,
        .normal => 6.0,
        .hard => 9.0,
    };
}

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn distance(self: Vec3, other: Vec3) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

pub const Repellent = enum {
    warped_fungus,
    potted_warped_fungus,
    warped_roots,
    active_nether_portal,
    active_respawn_anchor,
    other,

    pub fn repels(self: Repellent) bool {
        return self != .other;
    }
};

pub const RepellentResult = struct {
    detected: bool = false,
    is_fleeing: bool = false,
    direction: Vec3 = .{},
    velocity: Vec3 = .{},
};

pub fn detectRepellent(position: Vec3, source_position: Vec3, source: Repellent) RepellentResult {
    const delta = Vec3{
        .x = position.x - source_position.x,
        .y = position.y - source_position.y,
        .z = position.z - source_position.z,
    };
    const distance = position.distance(source_position);
    if (!source.repels() or distance > REPELLENT_RADIUS) return .{};
    if (distance == 0.0) return .{ .detected = true, .is_fleeing = true };
    const direction = Vec3{ .x = delta.x / distance, .y = delta.y / distance, .z = delta.z / distance };
    return .{
        .detected = true,
        .is_fleeing = true,
        .direction = direction,
        .velocity = .{ .x = direction.x * FLEE_SPEED, .y = direction.y * FLEE_SPEED, .z = direction.z * FLEE_SPEED },
    };
}

pub const Knockback = struct { vx: f32, vy: f32, vz: f32 };

/// `horizontal_away` is normalized by the caller and points from the attacker to its target.
pub fn computeAttackKnockback(horizontal_away: [2]f32, horizontal_speed: f32) Knockback {
    return .{
        .vx = horizontal_away[0] * horizontal_speed,
        .vy = VERTICAL_TOSS_VELOCITY,
        .vz = horizontal_away[1] * horizontal_speed,
    };
}

pub const Drops = struct {
    raw_porkchops: u8,
    leather: u8,
};

pub fn drops(pork_roll: u8, leather_roll: u8) Drops {
    return .{ .raw_porkchops = @as(u8, 2) + @min(pork_roll, @as(u8, 2)), .leather = @min(leather_roll, @as(u8, 1)) };
}

pub const Dimension = enum { nether, overworld, the_end };

pub const Hoglin = struct {
    health: f32 = MAX_HEALTH,
    is_baby: bool = false,
    scale: f32 = 1.0,
    is_love_mode: bool = false,
    is_fleeing: bool = false,
    flee_velocity: Vec3 = .{},
    is_shivering: bool = false,
    zombification_ticks: u32 = 0,
    is_zoglin: bool = false,
    is_undead: bool = false,
    immune_to_fire: bool = false,
    immune_to_lava: bool = false,
    maturation_ticks_remaining: u32 = 0,

    pub fn init() Hoglin {
        return .{};
    }

    pub fn baby() Hoglin {
        return .{ .health = BABY_MAX_HEALTH, .is_baby = true, .scale = 0.5, .maturation_ticks_remaining = BABY_MATURATION_TICKS };
    }

    pub fn updateRepellent(self: *Hoglin, position: Vec3, source_position: Vec3, source: Repellent) RepellentResult {
        if (self.is_zoglin) {
            self.is_fleeing = false;
            self.flee_velocity = .{};
            return .{};
        }
        const result = detectRepellent(position, source_position, source);
        self.is_fleeing = result.is_fleeing;
        self.flee_velocity = result.velocity;
        return result;
    }

    pub fn feedCrimsonFungus(self: *Hoglin) void {
        if (self.is_baby) {
            self.maturation_ticks_remaining -|= BABY_MATURATION_TICKS / 10;
        } else if (!self.is_zoglin) {
            self.is_love_mode = true;
        }
    }

    pub fn mature(self: *Hoglin, ticks: u32) bool {
        if (!self.is_baby) return false;
        self.maturation_ticks_remaining -|= ticks;
        if (self.maturation_ticks_remaining == 0) {
            self.is_baby = false;
            self.scale = 1.0;
            self.health = MAX_HEALTH;
            return true;
        }
        return false;
    }

    pub fn tickDimension(self: *Hoglin, dimension: Dimension, ticks: u32) bool {
        if (self.is_zoglin or dimension == .nether or ticks == 0) return false;
        self.is_shivering = true;
        const previous = self.zombification_ticks;
        self.zombification_ticks = @min(ZOMBIFICATION_TICKS, self.zombification_ticks +| ticks);
        if (self.zombification_ticks < ZOMBIFICATION_TICKS) return false;
        self.is_zoglin = true;
        self.is_undead = true;
        self.immune_to_fire = true;
        self.immune_to_lava = true;
        self.is_shivering = false;
        return previous < ZOMBIFICATION_TICKS;
    }

    pub fn attacks(self: Hoglin, target_is_zoglin: bool, target_is_creeper: bool) bool {
        _ = target_is_zoglin;
        _ = target_is_creeper;
        return self.is_zoglin;
    }
};

pub const BreedingResult = struct { first_love_mode: bool, second_love_mode: bool, baby: ?Hoglin };

/// Both adults must be fed Crimson Fungus before breeding can create a baby.
pub fn feedBreedingPair(first: *Hoglin, second: *Hoglin) BreedingResult {
    first.feedCrimsonFungus();
    second.feedCrimsonFungus();
    const can_pair = !first.is_baby and !second.is_baby and !first.is_zoglin and !second.is_zoglin and first.is_love_mode and second.is_love_mode;
    const first_entered_love = first.is_love_mode;
    const second_entered_love = second.is_love_mode;
    if (can_pair) {
        first.is_love_mode = false;
        second.is_love_mode = false;
    }
    return .{
        .first_love_mode = first_entered_love,
        .second_love_mode = second_entered_love,
        .baby = if (can_pair) Hoglin.baby() else null,
    };
}

test "adult hoglin starts with forty HP" {
    try std.testing.expectEqual(@as(f32, 40), Hoglin.init().health);
}
test "baby starts with twenty HP and half scale" {
    const h = Hoglin.baby();
    try std.testing.expectEqual(@as(f32, 20), h.health);
    try std.testing.expectEqual(@as(f32, 0.5), h.scale);
    try std.testing.expect(h.is_baby);
}
test "easy attack damage is three HP" {
    try std.testing.expectEqual(@as(f32, 3), attackDamage(.easy));
}
test "normal attack damage is six HP" {
    try std.testing.expectEqual(@as(f32, 6), attackDamage(.normal));
}
test "hard attack damage is nine HP" {
    try std.testing.expectEqual(@as(f32, 9), attackDamage(.hard));
}
test "adult attack has seven meters per second vertical toss" {
    const k = computeAttackKnockback(.{ 1, 0 }, 2);
    try std.testing.expectEqual(@as(f32, 7), k.vy);
    try std.testing.expectEqual(@as(f32, 2), k.vx);
}
test "horizontal toss follows target-away direction" {
    const k = computeAttackKnockback(.{ 0, -1 }, 3.5);
    try std.testing.expectEqual(@as(f32, 0), k.vx);
    try std.testing.expectEqual(@as(f32, -3.5), k.vz);
}
test "zero horizontal impulse retains vertical toss" {
    const k = computeAttackKnockback(.{ 0, 0 }, 0);
    try std.testing.expectEqual(@as(f32, 7), k.vy);
    try std.testing.expectEqual(@as(f32, 0), k.vx);
}
test "warped fungus repels at seven meter boundary" {
    try std.testing.expect(detectRepellent(.{ .x = 7 }, .{}, .warped_fungus).detected);
}
test "warped fungus outside seven meters does not repel" {
    try std.testing.expect(!detectRepellent(.{ .x = 7.01 }, .{}, .warped_fungus).detected);
}
test "potted warped fungus repels hoglin" {
    try std.testing.expect(detectRepellent(.{ .z = 1 }, .{}, .potted_warped_fungus).detected);
}
test "warped roots repel hoglin" {
    try std.testing.expect(detectRepellent(.{ .z = 2 }, .{}, .warped_roots).detected);
}
test "active portal repels hoglin" {
    try std.testing.expect(detectRepellent(.{ .z = 3 }, .{}, .active_nether_portal).detected);
}
test "active respawn anchor repels hoglin" {
    try std.testing.expect(detectRepellent(.{ .z = 4 }, .{}, .active_respawn_anchor).detected);
}
test "inactive or unrelated blocks do not repel" {
    try std.testing.expect(!detectRepellent(.{ .x = 1 }, .{}, .other).detected);
}
test "repellent distance is three dimensional Euclidean distance" {
    try std.testing.expect(!detectRepellent(.{ .x = 5, .y = 5 }, .{}, .warped_fungus).detected);
}
test "flee vector points away from source" {
    const r = detectRepellent(.{ .x = 2 }, .{}, .warped_fungus);
    try std.testing.expectEqual(@as(f32, 1), r.direction.x);
}
test "flee velocity uses sprint speed four point five" {
    const r = detectRepellent(.{ .x = -1 }, .{}, .warped_roots);
    try std.testing.expectEqual(@as(f32, -4.5), r.velocity.x);
}
test "flee vector normalizes diagonal displacement" {
    const r = detectRepellent(.{ .x = 3, .z = 4 }, .{}, .active_nether_portal);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), r.direction.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), r.direction.z, 0.0001);
}
test "hoglin records immediate fleeing state" {
    var h = Hoglin.init();
    _ = h.updateRepellent(.{ .x = 1 }, .{}, .warped_fungus);
    try std.testing.expect(h.is_fleeing);
}
test "hoglin stops fleeing when repellent leaves range" {
    var h = Hoglin.init();
    _ = h.updateRepellent(.{ .x = 1 }, .{}, .warped_fungus);
    _ = h.updateRepellent(.{ .x = 9 }, .{}, .warped_fungus);
    try std.testing.expect(!h.is_fleeing);
}
test "both fed adults enter love mode and spawn baby" {
    var a = Hoglin.init();
    var b = Hoglin.init();
    const result = feedBreedingPair(&a, &b);
    try std.testing.expect(result.first_love_mode and result.second_love_mode);
    try std.testing.expect(result.baby.?.is_baby);
}
test "successful breeding consumes adult love mode" {
    var a = Hoglin.init();
    var b = Hoglin.init();
    _ = feedBreedingPair(&a, &b);
    try std.testing.expect(!a.is_love_mode and !b.is_love_mode);
}
test "baby breeding result has half scale and twenty HP" {
    var a = Hoglin.init();
    var b = Hoglin.init();
    const child = feedBreedingPair(&a, &b).baby.?;
    try std.testing.expectEqual(@as(f32, 0.5), child.scale);
    try std.testing.expectEqual(@as(f32, 20), child.health);
}
test "baby has twenty four thousand maturation ticks" {
    try std.testing.expectEqual(@as(u32, 24_000), Hoglin.baby().maturation_ticks_remaining);
}
test "each baby fungus feed accelerates maturation by ten percent" {
    var h = Hoglin.baby();
    h.feedCrimsonFungus();
    try std.testing.expectEqual(@as(u32, 21_600), h.maturation_ticks_remaining);
}
test "baby matures after full timer and becomes adult" {
    var h = Hoglin.baby();
    try std.testing.expect(h.mature(24_000));
    try std.testing.expect(!h.is_baby);
    try std.testing.expectEqual(@as(f32, 1), h.scale);
    try std.testing.expectEqual(@as(f32, 40), h.health);
}
test "maturation partial tick countdown remains baby" {
    var h = Hoglin.baby();
    try std.testing.expect(!h.mature(23_999));
    try std.testing.expect(h.is_baby);
}
test "adult Crimson Fungus feeding enters love mode" {
    var h = Hoglin.init();
    h.feedCrimsonFungus();
    try std.testing.expect(h.is_love_mode);
}
test "Hoglin entering Overworld begins shivering" {
    var h = Hoglin.init();
    try std.testing.expect(!h.tickDimension(.overworld, 1));
    try std.testing.expect(h.is_shivering);
}
test "Hoglin entering End begins shivering" {
    var h = Hoglin.init();
    try std.testing.expect(!h.tickDimension(.the_end, 1));
    try std.testing.expect(h.is_shivering);
}
test "Nether ticks do not advance zombification" {
    var h = Hoglin.init();
    try std.testing.expect(!h.tickDimension(.nether, 300));
    try std.testing.expectEqual(@as(u32, 0), h.zombification_ticks);
}
test "Overworld conversion occurs at exactly three hundred ticks" {
    var h = Hoglin.init();
    try std.testing.expect(!h.tickDimension(.overworld, 299));
    try std.testing.expect(h.tickDimension(.overworld, 1));
    try std.testing.expect(h.is_zoglin);
}
test "End conversion occurs at three hundred ticks" {
    var h = Hoglin.init();
    try std.testing.expect(h.tickDimension(.the_end, 300));
    try std.testing.expect(h.is_zoglin);
}
test "conversion marks zoglin undead and fire immune" {
    var h = Hoglin.init();
    _ = h.tickDimension(.overworld, 300);
    try std.testing.expect(h.is_undead and h.immune_to_fire and h.immune_to_lava);
}
test "conversion transformation event fires once" {
    var h = Hoglin.init();
    try std.testing.expect(h.tickDimension(.overworld, 300));
    try std.testing.expect(!h.tickDimension(.overworld, 1));
}
test "zoglin attacks players and ordinary mobs indiscriminately" {
    var h = Hoglin.init();
    _ = h.tickDimension(.overworld, 300);
    try std.testing.expect(h.attacks(false, false));
}
test "zoglin attacks other zoglins indiscriminately" {
    var h = Hoglin.init();
    _ = h.tickDimension(.overworld, 300);
    try std.testing.expect(h.attacks(true, false));
}
test "zoglin attacks creepers indiscriminately" {
    var h = Hoglin.init();
    _ = h.tickDimension(.overworld, 300);
    try std.testing.expect(h.attacks(false, true));
}
test "hoglin drops raw porkchops in range" {
    const d = drops(0, 0);
    try std.testing.expectEqual(@as(u8, 2), d.raw_porkchops);
}
test "porkchop drops cap at four" {
    try std.testing.expectEqual(@as(u8, 4), drops(255, 0).raw_porkchops);
}
test "leather drops range from zero to one" {
    try std.testing.expectEqual(@as(u8, 0), drops(0, 0).leather);
    try std.testing.expectEqual(@as(u8, 1), drops(0, 1).leather);
}
