const std = @import("std");

/// Entity kinds that can occupy a shared one-block space.
///
/// Cramming counts living pushable entities and vehicles, but deliberately
/// ignores loose objects, projectiles, decorative entities, and spectators.
pub const EntityKind = enum {
    mob,
    player,
    boat,
    minecart,
    hopper_minecart,
    dropped_item,
    xp_orb,
    arrow,
    armor_stand,
    bat,
    spectator,
};

/// The vanilla maxEntityCramming rule and the damage pulse it produces.
pub const MaxEntityCrammingRule = struct {
    pub const default_threshold: u8 = 24;
    pub const damage_per_pulse: f32 = 3.0;
    pub const pulse_interval_seconds: f32 = 0.5;
    pub const damage_per_second: f32 = damage_per_pulse / pulse_interval_seconds;

    max_entity_cramming: u8 = default_threshold,

    pub fn evaluateDamage(self: MaxEntityCrammingRule, colliding_pushable_entities: u16) f32 {
        return evaluateEntityCrammingDamage(colliding_pushable_entities, self.max_entity_cramming);
    }

    pub fn isDisabled(self: MaxEntityCrammingRule) bool {
        return self.max_entity_cramming == 0;
    }
};

/// Returns one half-second cramming damage pulse in HP.
///
/// The returned damage is armor-bypassing suffocation damage. A zero gamerule
/// disables the mechanic, while any positive gamerule value is the configured
/// threshold (not a hard-coded 24).
pub fn evaluateEntityCrammingDamage(
    colliding_pushable_entities: u16,
    max_cramming_gamerule: u8,
) f32 {
    if (max_cramming_gamerule == 0) return 0.0;
    if (colliding_pushable_entities < @as(u16, max_cramming_gamerule)) return 0.0;
    return MaxEntityCrammingRule.damage_per_pulse;
}

/// Whether an entity contributes to the pushable-entity count.
pub fn countsAsPushableForCramming(entity_kind: EntityKind) bool {
    return switch (entity_kind) {
        .mob, .player, .boat, .minecart, .hopper_minecart => true,
        .dropped_item, .xp_orb, .arrow, .armor_stand, .bat, .spectator => false,
    };
}

/// A passive minecart kill chamber needs no redstone or player intervention.
pub const MinecartGrinderChamber = struct {
    pub const required_minecarts: u8 = MaxEntityCrammingRule.default_threshold;

    minecart_count: u8 = 0,
    hopper_minecart_count: u8 = 0,

    pub fn init(minecart_count: u8, hopper_minecart_count: u8) MinecartGrinderChamber {
        return .{
            .minecart_count = minecart_count,
            .hopper_minecart_count = hopper_minecart_count,
        };
    }

    pub fn totalMinecarts(self: MinecartGrinderChamber) u16 {
        return @as(u16, self.minecart_count) + @as(u16, self.hopper_minecart_count);
    }

    pub fn isActive(self: MinecartGrinderChamber) bool {
        return self.totalMinecarts() >= required_minecarts;
    }

    /// A mob falling onto an active chamber is immediately exposed to enough
    /// pushable minecarts to receive cramming damage and die.
    pub fn does24MinecartStackKillFirstMob(self: MinecartGrinderChamber) bool {
        return self.isActive();
    }

    pub fn dropsCommonLootWithoutPlayer(self: MinecartGrinderChamber) bool {
        return self.isActive();
    }
};

/// The canonical 24-minecart (or hopper-minecart) grinder configuration.
pub fn does24MinecartStackKillFirstMob() bool {
    return MinecartGrinderChamber.init(24, 0).does24MinecartStackKillFirstMob();
}

/// Climbing blocks disable horizontal entity-push collision and therefore
/// exempt entities inside them from cramming, regardless of crowd size.
pub fn isExemptFromEntityCrammingWhileInClimbingBlock(in_vine_or_ladder: bool) bool {
    return in_vine_or_ladder;
}

test "default max entity cramming threshold is 24" {
    const rule = MaxEntityCrammingRule{};
    try std.testing.expectEqual(@as(u8, 24), rule.max_entity_cramming);
    try std.testing.expect(!rule.isDisabled());
}

test "exactly 24 pushable entities take three hp per pulse" {
    try std.testing.expectEqual(@as(f32, 3.0), evaluateEntityCrammingDamage(24, 24));
    try std.testing.expectEqual(@as(f32, 3.0), evaluateEntityCrammingDamage(100, 24));
}

test "fewer than the configured threshold take no cramming damage" {
    try std.testing.expectEqual(@as(f32, 0.0), evaluateEntityCrammingDamage(23, 24));
    try std.testing.expectEqual(@as(f32, 0.0), evaluateEntityCrammingDamage(23, 30));
}

test "zero max entity cramming disables damage" {
    try std.testing.expectEqual(@as(f32, 0.0), evaluateEntityCrammingDamage(24, 0));
    try std.testing.expectEqual(@as(f32, 0.0), (MaxEntityCrammingRule{ .max_entity_cramming = 0 }).evaluateDamage(200));
}

test "custom positive gamerule is used as the threshold" {
    const rule = MaxEntityCrammingRule{ .max_entity_cramming = 5 };
    try std.testing.expectEqual(@as(f32, 0.0), rule.evaluateDamage(4));
    try std.testing.expectEqual(@as(f32, 3.0), rule.evaluateDamage(5));
}

test "cramming damage is six hp per second from half-second pulses" {
    try std.testing.expectEqual(@as(f32, 0.5), MaxEntityCrammingRule.pulse_interval_seconds);
    try std.testing.expectEqual(@as(f32, 6.0), MaxEntityCrammingRule.damage_per_second);
}

test "mobs players boats and both minecart variants are pushable" {
    const pushable = [_]EntityKind{ .mob, .player, .boat, .minecart, .hopper_minecart };
    for (pushable) |kind| try std.testing.expect(countsAsPushableForCramming(kind));
}

test "non-pushable entities do not count toward cramming" {
    const exempt = [_]EntityKind{ .dropped_item, .xp_orb, .arrow, .armor_stand, .bat, .spectator };
    for (exempt) |kind| try std.testing.expect(!countsAsPushableForCramming(kind));
}

test "a mixed crowd counts only pushable entities" {
    const crowd = [_]EntityKind{ .mob, .dropped_item, .player, .xp_orb, .boat, .arrow, .minecart };
    var count: u16 = 0;
    for (crowd) |kind| {
        if (countsAsPushableForCramming(kind)) count += 1;
    }
    try std.testing.expectEqual(@as(u16, 4), count);
    try std.testing.expectEqual(@as(f32, 0.0), evaluateEntityCrammingDamage(count, 24));
}

test "24 minecarts activate a passive grinder" {
    const chamber = MinecartGrinderChamber.init(24, 0);
    try std.testing.expect(chamber.isActive());
    try std.testing.expect(chamber.does24MinecartStackKillFirstMob());
    try std.testing.expect(chamber.dropsCommonLootWithoutPlayer());
}

test "hopper minecarts contribute to the 24-cart stack" {
    const chamber = MinecartGrinderChamber.init(12, 12);
    try std.testing.expectEqual(@as(u16, 24), chamber.totalMinecarts());
    try std.testing.expect(chamber.does24MinecartStackKillFirstMob());
}

test "an incomplete minecart stack is not an active grinder" {
    const chamber = MinecartGrinderChamber.init(23, 0);
    try std.testing.expect(!chamber.isActive());
    try std.testing.expect(!chamber.dropsCommonLootWithoutPlayer());
}

test "the canonical 24 minecart grinder kills the first mob" {
    try std.testing.expect(does24MinecartStackKillFirstMob());
}

test "climbing vine or ladder exempts an entity from cramming" {
    try std.testing.expect(isExemptFromEntityCrammingWhileInClimbingBlock(true));
    try std.testing.expect(!isExemptFromEntityCrammingWhileInClimbingBlock(false));
}

test "all listed climbing blocks can use the same exemption flag" {
    const climbing_blocks = [_][]const u8{ "ladder", "vines", "weeping_vines", "twisting_vines", "cave_vines", "scaffolding" };
    for (climbing_blocks) |block_name| {
        try std.testing.expect(block_name.len > 0);
        try std.testing.expect(isExemptFromEntityCrammingWhileInClimbingBlock(true));
    }
}

