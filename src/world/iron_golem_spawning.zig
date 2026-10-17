//! Village iron golem spawning rules (Milestone 426).
//!
//! This module deliberately contains only deterministic predicates and count
//! helpers. World/entity systems can provide the nearby-villager and block
//! observations without coupling this mechanic to a particular world store.

const std = @import("std");

pub const villager_detection_radius_m: f32 = 10.0;
pub const panic_quorum_villagers: u8 = 3;
pub const gossip_quorum_villagers: u8 = 5;
pub const sleep_requirement_ticks: u32 = 24000;
pub const golem_detection_cooldown_ticks: u16 = 600;
pub const golem_detection_radius_m: f32 = 16.0;

/// Hostile mobs that make nearby villagers panic and use the smaller quorum.
pub const PanicMob = enum {
    zombie,
    husk,
    drowned,
    pillager,
    vindicator,
    evoker,
    vex,
    zoglin,
    skeleton,
    creeper,
};

pub const VillagerGolemQuorum = struct {
    const Self = @This();
    pub const panic_quorum_villagers: u8 = 3;
    pub const gossip_quorum_villagers: u8 = 5;
    pub const detection_radius_m: f32 = villager_detection_radius_m;

    pub fn requiredVillagers(panic_mode: bool) u8 {
        return if (panic_mode) Self.panic_quorum_villagers else Self.gossip_quorum_villagers;
    }

    /// A threat is panic-triggering only when it is one of the eight specified
    /// mob types and lies within the 10-block detection radius.
    pub fn isPanicThreat(mob: PanicMob, distance_m: f32) bool {
        if (!std.math.isFinite(distance_m) or distance_m < 0.0 or distance_m > detection_radius_m) return false;
        return switch (mob) {
            .zombie, .husk, .drowned, .pillager, .vindicator, .evoker, .vex, .zoglin => true,
            .skeleton, .creeper => false,
        };
    }

    /// Counts eligible villagers, rather than merely nearby villagers, because
    /// every villager participating in the quorum must pass its own conditions.
    pub fn hasQuorum(eligible_villagers: u8, panic_mode: bool) bool {
        return eligible_villagers >= requiredVillagers(panic_mode);
    }

    pub fn canSummon(eligible_villagers: u8, panic_mode: bool) bool {
        return hasQuorum(eligible_villagers, panic_mode);
    }
};

pub const VillagerEligibilityConditions = struct {
    const Self = @This();
    ticks_since_last_sleep: u32,
    ticks_since_golem_detection: ?u32 = null,

    pub const max_sleep_age_ticks: u32 = sleep_requirement_ticks;
    pub const golem_detection_cooldown_ticks: u16 = 600;
    pub const golem_detection_radius_m: f32 = 16.0;

    pub fn hasSleptWithinLast24000Ticks(ticks_since_last_sleep: u32) bool {
        return ticks_since_last_sleep <= max_sleep_age_ticks;
    }

    pub fn hasRecentGolemDetection(ticks_since_detection: ?u32) bool {
        return if (ticks_since_detection) |ticks| ticks <= @as(u32, Self.golem_detection_cooldown_ticks) else false;
    }

    pub fn isEligible(self: VillagerEligibilityConditions) bool {
        return hasSleptWithinLast24000Ticks(self.ticks_since_last_sleep) and
            !hasRecentGolemDetection(self.ticks_since_golem_detection);
    }
};

/// The summoning villager is at the center of a 17x13x17 search volume:
/// offsets -8..8 on X/Z and -6..6 on Y. A candidate location needs a solid
/// top surface and a 2x3x2 unobstructed space above it.
pub const GolemSpawnVolume = struct {
    pub const width: u8 = 17;
    pub const height: u8 = 13;
    pub const depth: u8 = 17;
    pub const horizontal_radius: i8 = 8;
    pub const vertical_radius: i8 = 6;
    pub const clearance_width: u8 = 2;
    pub const clearance_height: u8 = 3;
    pub const clearance_depth: u8 = 2;

    pub fn containsOffset(offset: [3]i32) bool {
        return offset[0] >= -8 and offset[0] <= 8 and
            offset[1] >= -6 and offset[1] <= 6 and
            offset[2] >= -8 and offset[2] <= 8;
    }

    /// Flowing water above a valid solid floor is allowed for the golem's
    /// spawn check; the water is not itself a solid obstruction.
    pub fn canGolemSpawnInShallowWater() bool {
        return true;
    }

    /// `is_carpet_or_glass_or_bottom_slab` also represents buttons and other
    /// non-full blocks that do not make a candidate space solid-proof.
    pub fn isBlockGolemSpawnProof(is_carpet_or_glass_or_bottom_slab: bool) bool {
        return is_carpet_or_glass_or_bottom_slab;
    }

    pub fn canSpawnAt(
        offset: [3]i32,
        top_surface_is_solid: bool,
        under_flowing_water: bool,
        clearance_free_of_solid_obstructions: bool,
    ) bool {
        return containsOffset(offset) and top_surface_is_solid and
            (under_flowing_water == false or GolemSpawnVolume.canGolemSpawnInShallowWater()) and
            clearance_free_of_solid_obstructions;
    }
};

pub const PlayerBuiltGolemRule = struct {
    pub const iron_blocks_required: u8 = 4;
    pub const carved_pumpkins_required: u8 = 1;
    pub const hostile_popularity_threshold: i16 = -15;

    pub fn canPlayerBuiltGolemAttackPlayer() bool {
        return false;
    }

    /// A player-built golem is permanently passive. A village-spawned golem
    /// attacks after being hit, or when village popularity is below -15.
    pub fn canGolemAttackPlayer(
        player_built: bool,
        player_hit_golem: bool,
        village_popularity: i16,
    ) bool {
        if (player_built) return PlayerBuiltGolemRule.canPlayerBuiltGolemAttackPlayer();
        return player_hit_golem or village_popularity < hostile_popularity_threshold;
    }
};

pub fn canGolemSpawnInShallowWater() bool {
    return GolemSpawnVolume.canGolemSpawnInShallowWater();
}

pub fn isBlockGolemSpawnProof(is_carpet_or_glass_or_bottom_slab: bool) bool {
    return GolemSpawnVolume.isBlockGolemSpawnProof(is_carpet_or_glass_or_bottom_slab);
}

pub fn canPlayerBuiltGolemAttackPlayer() bool {
    return PlayerBuiltGolemRule.canPlayerBuiltGolemAttackPlayer();
}

test "panic and gossip quorum constants" {
    try std.testing.expectEqual(@as(u8, 3), panic_quorum_villagers);
    try std.testing.expectEqual(@as(u8, 5), gossip_quorum_villagers);
    try std.testing.expectEqual(@as(u8, 3), VillagerGolemQuorum.requiredVillagers(true));
    try std.testing.expectEqual(@as(u8, 5), VillagerGolemQuorum.requiredVillagers(false));
}

test "panic quorum accepts exactly three eligible villagers" {
    try std.testing.expect(VillagerGolemQuorum.hasQuorum(3, true));
    try std.testing.expect(!VillagerGolemQuorum.hasQuorum(2, true));
}

test "peaceful gossip quorum requires five villagers" {
    try std.testing.expect(VillagerGolemQuorum.hasQuorum(5, false));
    try std.testing.expect(!VillagerGolemQuorum.hasQuorum(4, false));
}

test "all eight specified mobs trigger panic in range" {
    const mobs = [_]PanicMob{ .zombie, .husk, .drowned, .pillager, .vindicator, .evoker, .vex, .zoglin };
    for (mobs) |mob| try std.testing.expect(VillagerGolemQuorum.isPanicThreat(mob, 10.0));
}

test "panic threat excludes unrelated mobs and out of range threats" {
    try std.testing.expect(!VillagerGolemQuorum.isPanicThreat(.skeleton, 1.0));
    try std.testing.expect(!VillagerGolemQuorum.isPanicThreat(.zombie, 10.01));
    try std.testing.expect(VillagerGolemQuorum.isPanicThreat(.zombie, 0.0));
}

test "sleep eligibility includes exactly 24000 ticks" {
    try std.testing.expect(VillagerEligibilityConditions.hasSleptWithinLast24000Ticks(0));
    try std.testing.expect(VillagerEligibilityConditions.hasSleptWithinLast24000Ticks(24000));
    try std.testing.expect(!VillagerEligibilityConditions.hasSleptWithinLast24000Ticks(24001));
}

test "recent golem detection blocks through 600 ticks" {
    try std.testing.expect(VillagerEligibilityConditions.hasRecentGolemDetection(0));
    try std.testing.expect(VillagerEligibilityConditions.hasRecentGolemDetection(600));
    try std.testing.expect(!VillagerEligibilityConditions.hasRecentGolemDetection(601));
    try std.testing.expect(!VillagerEligibilityConditions.hasRecentGolemDetection(null));
}

test "villager eligibility combines sleep and detection conditions" {
    try std.testing.expect((VillagerEligibilityConditions{ .ticks_since_last_sleep = 24000 }).isEligible());
    try std.testing.expect(!(VillagerEligibilityConditions{ .ticks_since_last_sleep = 24000, .ticks_since_golem_detection = 600 }).isEligible());
    try std.testing.expect(!(VillagerEligibilityConditions{ .ticks_since_last_sleep = 24001 }).isEligible());
}

test "spawn volume has 17 by 13 by 17 inclusive offsets" {
    try std.testing.expect(GolemSpawnVolume.containsOffset(.{ -8, -6, -8 }));
    try std.testing.expect(GolemSpawnVolume.containsOffset(.{ 8, 6, 8 }));
    try std.testing.expect(!GolemSpawnVolume.containsOffset(.{ 9, 0, 0 }));
    try std.testing.expect(!GolemSpawnVolume.containsOffset(.{ 0, 7, 0 }));
}

test "shallow flowing water is spawnable" {
    try std.testing.expect(canGolemSpawnInShallowWater());
    try std.testing.expect(GolemSpawnVolume.canSpawnAt(.{ 0, 0, 0 }, true, true, true));
}

test "spawn requires solid top surface and clear two by three by two space" {
    try std.testing.expect(!GolemSpawnVolume.canSpawnAt(.{ 0, 0, 0 }, false, false, true));
    try std.testing.expect(!GolemSpawnVolume.canSpawnAt(.{ 0, 0, 0 }, true, false, false));
    try std.testing.expect(GolemSpawnVolume.canSpawnAt(.{ 8, 6, -8 }, true, false, true));
}

test "carpets glass bottom slabs and buttons are spawn proof" {
    try std.testing.expect(isBlockGolemSpawnProof(true));
    try std.testing.expect(!isBlockGolemSpawnProof(false));
}

test "player-built golems never attack players" {
    try std.testing.expect(!canPlayerBuiltGolemAttackPlayer());
    try std.testing.expect(!PlayerBuiltGolemRule.canGolemAttackPlayer(true, true, -100));
}

test "village golem attacks on hit or popularity below minus fifteen" {
    try std.testing.expect(PlayerBuiltGolemRule.canGolemAttackPlayer(false, true, 0));
    try std.testing.expect(PlayerBuiltGolemRule.canGolemAttackPlayer(false, false, -16));
    try std.testing.expect(!PlayerBuiltGolemRule.canGolemAttackPlayer(false, false, -15));
}

test "player-built recipe shape uses four iron blocks and one pumpkin" {
    try std.testing.expectEqual(@as(u8, 4), PlayerBuiltGolemRule.iron_blocks_required);
    try std.testing.expectEqual(@as(u8, 1), PlayerBuiltGolemRule.carved_pumpkins_required);
}
