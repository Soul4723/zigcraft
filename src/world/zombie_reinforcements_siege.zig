const std = @import("std");

pub const base_spawn_reinforcements_chance: f32 = 0.05;
pub const leader_spawn_chance_cap: f32 = 0.05;
pub const leader_bonus_min: f32 = 0.50;
pub const leader_bonus_max: f32 = 0.75;
pub const leader_max_health_multiplier: f32 = 1.50;

pub const ZombieKind = enum {
    zombie,
    husk,
    drowned,
    zombified_piglin,
};

pub const ZombieReinforcementAttribute = struct {
    kind: ZombieKind,
    spawn_reinforcements_chance: f32,
    is_leader: bool,
    max_health_multiplier: f32,

    pub fn init(kind: ZombieKind) ZombieReinforcementAttribute {
        return .{
            .kind = kind,
            .spawn_reinforcements_chance = base_spawn_reinforcements_chance,
            .is_leader = false,
            .max_health_multiplier = 1.0,
        };
    }

    /// Regional difficulty is clamped to [0, 1]. A zombie can become a leader
    /// on at most five percent of spawns, with the leader bonus sampled from
    /// the inclusive 50..75 percentage-point range.
    pub fn spawn(kind: ZombieKind, regional_difficulty: f32, leader_roll: f32, bonus_roll: f32) ZombieReinforcementAttribute {
        var result = init(kind);
        const difficulty = clamp01(regional_difficulty);
        if (kind == .zombie and leader_roll >= 0.0 and leader_roll < leaderSpawnChance(difficulty)) {
            result.is_leader = true;
            result.spawn_reinforcements_chance += leaderReinforcementBonus(bonus_roll);
            result.max_health_multiplier = leader_max_health_multiplier;
        }
        return result;
    }
};

pub fn clamp01(value: f32) f32 {
    if (value < 0.0) return 0.0;
    if (value > 1.0) return 1.0;
    return value;
}

pub fn leaderSpawnChance(regional_difficulty: f32) f32 {
    return leader_spawn_chance_cap * clamp01(regional_difficulty);
}

pub fn leaderReinforcementBonus(roll: f32) f32 {
    const t = clamp01(roll);
    return leader_bonus_min + (leader_bonus_max - leader_bonus_min) * t;
}

/// A successful summon permanently removes five percentage points from both
/// the summoner and the newly spawned reinforcement.
pub fn degradeReinforcementChance(current_chance: f32) f32 {
    const non_negative = if (current_chance < 0.0) 0.0 else current_chance;
    if (non_negative <= 0.05) return 0.0;
    return non_negative - 0.05;
}

/// Applies the post-summon degradation to both sides of a successful summon.
pub fn applyReinforcementDamageDegradation(summoner: *ZombieReinforcementAttribute, reinforcement: *ZombieReinforcementAttribute) void {
    summoner.spawn_reinforcements_chance = degradeReinforcementChance(summoner.spawn_reinforcements_chance);
    reinforcement.spawn_reinforcements_chance = degradeReinforcementChance(reinforcement.spawn_reinforcements_chance);
}

pub const ReinforcementPlacementRule = struct {
    pub const min_dist: u8 = 7;
    pub const max_dist: u8 = 40;
    pub const max_attempts: u8 = 50;
    pub const max_light_level: u8 = 9;
    pub const no_player_radius: f32 = 7.0;

    /// A probe is supplied by the world query layer. Keeping the rule in
    /// value form makes it deterministic and independent of block storage.
    pub const Spot = struct {
        distance: f32,
        light_level: u8,
        has_solid_top_surface: bool,
        nearest_player_distance: ?f32,
    };

    pub fn isValidReinforcementSpot(spot: Spot) bool {
        if (!spot.has_solid_top_surface) return false;
        if (spot.light_level > max_light_level) return false;
        if (spot.distance < @as(f32, min_dist) or spot.distance > @as(f32, max_dist)) return false;
        if (spot.nearest_player_distance) |distance| {
            if (distance < no_player_radius) return false;
        }
        return true;
    }

    /// Evaluates at most fifty already-randomized candidates in order.
    pub fn selectValid(candidates: []const Spot) ?usize {
        const count = @min(candidates.len, @as(usize, max_attempts));
        var i: usize = 0;
        while (i < count) : (i += 1) {
            if (ReinforcementPlacementRule.isValidReinforcementSpot(candidates[i])) return i;
        }
        return null;
    }
};

/// Convenience form for callers that do not need to name the rule type.
pub fn isValidReinforcementSpot(spot: ReinforcementPlacementRule.Spot) bool {
    return ReinforcementPlacementRule.isValidReinforcementSpot(spot);
}

pub const MidnightVillageSiege = struct {
    pub const midnight_ticks: u32 = 18_000;
    pub const min_beds: u8 = 10;
    pub const min_villagers: u8 = 20;
    pub const trigger_chance: f32 = 0.10;
    pub const max_zombies: u8 = 20;

    pub fn isMidnight(time_of_day_ticks: u32) bool {
        return time_of_day_ticks % 24_000 == midnight_ticks;
    }

    pub fn qualifies(beds: u8, villagers: u8) bool {
        return beds >= min_beds and villagers >= min_villagers;
    }

    pub fn shouldTrigger(time_of_day_ticks: u32, beds: u8, villagers: u8, roll: f32) bool {
        return isMidnight(time_of_day_ticks) and qualifies(beds, villagers) and roll >= 0.0 and roll < trigger_chance;
    }

    pub fn spawnCount(requested: u8) u8 {
        return @min(requested, max_zombies);
    }

    pub fn ignoresTorchLightDuringSiege() bool {
        return true;
    }

    /// Torch light is ignored, but physical obstructions still prevent a spot.
    pub fn isValidSiegeSpot(has_solid_top_surface: bool, blocked_by_slab_carpet_or_glass: bool) bool {
        return has_solid_top_surface and !blocked_by_slab_carpet_or_glass;
    }
};

test "all supported zombie kinds receive a base chance" {
    const kinds = [_]ZombieKind{ .zombie, .husk, .drowned, .zombified_piglin };
    for (kinds) |kind| {
        const attribute = ZombieReinforcementAttribute.init(kind);
        try std.testing.expectEqual(base_spawn_reinforcements_chance, attribute.spawn_reinforcements_chance);
        try std.testing.expect(!attribute.is_leader);
    }
}

test "regional difficulty clamps leader chance" {
    try std.testing.expectEqual(@as(f32, 0.0), leaderSpawnChance(-2.0));
    try std.testing.expectEqual(@as(f32, 0.025), leaderSpawnChance(0.5));
    try std.testing.expectEqual(@as(f32, 0.05), leaderSpawnChance(2.0));
}

test "leader roll creates a health-boosted leader" {
    const leader = ZombieReinforcementAttribute.spawn(.zombie, 1.0, 0.01, 0.0);
    try std.testing.expect(leader.is_leader);
    try std.testing.expectEqual(@as(f32, 0.55), leader.spawn_reinforcements_chance);
    try std.testing.expectEqual(leader_max_health_multiplier, leader.max_health_multiplier);
}

test "leader bonus reaches the seventy-five percent endpoint" {
    const leader = ZombieReinforcementAttribute.spawn(.zombie, 1.0, 0.0, 1.0);
    try std.testing.expectEqual(@as(f32, 0.80), leader.spawn_reinforcements_chance);
}

test "only zombies can become leaders" {
    const husk = ZombieReinforcementAttribute.spawn(.husk, 1.0, 0.0, 1.0);
    try std.testing.expect(!husk.is_leader);
    try std.testing.expectEqual(@as(f32, 1.0), husk.max_health_multiplier);
}

test "leader boundary roll is excluded" {
    const not_leader = ZombieReinforcementAttribute.spawn(.zombie, 1.0, 0.05, 0.0);
    try std.testing.expect(!not_leader.is_leader);
}

test "damage degradation subtracts five percentage points" {
    try std.testing.expectEqual(@as(f32, 0.15), degradeReinforcementChance(0.20));
    try std.testing.expectEqual(@as(f32, 0.0), degradeReinforcementChance(0.05));
    try std.testing.expectEqual(@as(f32, 0.0), degradeReinforcementChance(-0.5));
}

test "degradation cannot go below zero after repeated summons" {
    var chance: f32 = 0.16;
    chance = degradeReinforcementChance(chance);
    chance = degradeReinforcementChance(chance);
    chance = degradeReinforcementChance(chance);
    chance = degradeReinforcementChance(chance);
    try std.testing.expectEqual(@as(f32, 0.0), chance);
}

test "successful summon degrades summoner and reinforcement independently" {
    var summoner = ZombieReinforcementAttribute.init(.zombie);
    var reinforcement = ZombieReinforcementAttribute.init(.drowned);
    summoner.spawn_reinforcements_chance = 0.20;
    reinforcement.spawn_reinforcements_chance = 0.06;
    applyReinforcementDamageDegradation(&summoner, &reinforcement);
    try std.testing.expectEqual(@as(f32, 0.15), summoner.spawn_reinforcements_chance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.01), reinforcement.spawn_reinforcements_chance, 0.000001);
}

test "reinforcement spot accepts the complete valid boundary" {
    const spot = ReinforcementPlacementRule.Spot{
        .distance = 7.0,
        .light_level = 9,
        .has_solid_top_surface = true,
        .nearest_player_distance = 7.0,
    };
    try std.testing.expect(ReinforcementPlacementRule.isValidReinforcementSpot(spot));
}

test "reinforcement spot rejects light, ground, and player violations" {
    try std.testing.expect(!isValidReinforcementSpot(.{ .distance = 10.0, .light_level = 9, .has_solid_top_surface = true, .nearest_player_distance = 6.99 }));
    try std.testing.expect(!ReinforcementPlacementRule.isValidReinforcementSpot(.{ .distance = 10.0, .light_level = 10, .has_solid_top_surface = true, .nearest_player_distance = null }));
    try std.testing.expect(!ReinforcementPlacementRule.isValidReinforcementSpot(.{ .distance = 10.0, .light_level = 9, .has_solid_top_surface = false, .nearest_player_distance = null }));
    try std.testing.expect(!ReinforcementPlacementRule.isValidReinforcementSpot(.{ .distance = 10.0, .light_level = 9, .has_solid_top_surface = true, .nearest_player_distance = 6.99 }));
}

test "reinforcement distance range is inclusive" {
    try std.testing.expect(ReinforcementPlacementRule.isValidReinforcementSpot(.{ .distance = 40.0, .light_level = 7, .has_solid_top_surface = true, .nearest_player_distance = null }));
    try std.testing.expect(!ReinforcementPlacementRule.isValidReinforcementSpot(.{ .distance = 6.99, .light_level = 7, .has_solid_top_surface = true, .nearest_player_distance = null }));
    try std.testing.expect(!ReinforcementPlacementRule.isValidReinforcementSpot(.{ .distance = 40.01, .light_level = 7, .has_solid_top_surface = true, .nearest_player_distance = null }));
}

test "placement selection stops after fifty attempts" {
    var candidates: [51]ReinforcementPlacementRule.Spot = undefined;
    for (&candidates) |*candidate| candidate.* = .{ .distance = 10.0, .light_level = 10, .has_solid_top_surface = true, .nearest_player_distance = null };
    candidates[50].light_level = 0;
    try std.testing.expectEqual(@as(?usize, null), ReinforcementPlacementRule.selectValid(&candidates));
    candidates[49].light_level = 0;
    try std.testing.expectEqual(@as(?usize, 49), ReinforcementPlacementRule.selectValid(&candidates));
}

test "midnight village siege thresholds and chance" {
    try std.testing.expect(MidnightVillageSiege.isMidnight(18_000));
    try std.testing.expect(!MidnightVillageSiege.isMidnight(17_999));
    try std.testing.expect(MidnightVillageSiege.qualifies(10, 20));
    try std.testing.expect(!MidnightVillageSiege.qualifies(9, 20));
    try std.testing.expect(MidnightVillageSiege.shouldTrigger(18_000, 10, 20, 0.099));
    try std.testing.expect(!MidnightVillageSiege.shouldTrigger(18_000, 10, 20, 0.10));
}

test "siege caps the wave and ignores torch light but respects blockers" {
    try std.testing.expectEqual(@as(u8, 20), MidnightVillageSiege.spawnCount(200));
    try std.testing.expect(MidnightVillageSiege.ignoresTorchLightDuringSiege());
    try std.testing.expect(MidnightVillageSiege.isValidSiegeSpot(true, false));
    try std.testing.expect(!MidnightVillageSiege.isValidSiegeSpot(true, true));
    try std.testing.expect(!MidnightVillageSiege.isValidSiegeSpot(false, false));
}
