const std = @import("std");

/// Game difficulty settings affecting mob behaviors and mechanics.
pub const Difficulty = enum(u8) {
    peaceful = 0,
    easy = 1,
    normal = 2,
    hard = 3,
};

/// 12 distinct wood species in modern Minecraft.
pub const WoodSpecies = enum(u8) {
    oak = 0,
    spruce = 1,
    birch = 2,
    jungle = 3,
    acacia = 4,
    dark_oak = 5,
    mangrove = 6,
    cherry = 7,
    bamboo = 8,
    crimson = 9,
    warped = 10,
    pale_oak = 11,

    pub fn name(self: WoodSpecies) []const u8 {
        return switch (self) {
            .oak => "Oak",
            .spruce => "Spruce",
            .birch => "Birch",
            .jungle => "Jungle",
            .acacia => "Acacia",
            .dark_oak => "Dark Oak",
            .mangrove => "Mangrove",
            .cherry => "Cherry",
            .bamboo => "Bamboo",
            .crimson => "Crimson",
            .warped => "Warped",
            .pale_oak => "Pale Oak",
        };
    }

    /// Crimson and Warped fungi from the Nether are immune to fire.
    pub fn isNetherFungi(self: WoodSpecies) bool {
        return self == .crimson or self == .warped;
    }

    pub fn isFlammable(self: WoodSpecies) bool {
        return !self.isNetherFungi();
    }
};

/// 4 copper oxidation stages: unaffected -> exposed -> weathered -> oxidized.
pub const CopperOxidation = enum(u8) {
    unaffected = 0,
    exposed = 1,
    weathered = 2,
    oxidized = 3,

    pub fn name(self: CopperOxidation) []const u8 {
        return switch (self) {
            .unaffected => "Unaffected Copper",
            .exposed => "Exposed Copper",
            .weathered => "Weathered Copper",
            .oxidized => "Oxidized Copper",
        };
    }

    pub fn nextStage(self: CopperOxidation) ?CopperOxidation {
        return switch (self) {
            .unaffected => .exposed,
            .exposed => .weathered,
            .weathered => .oxidized,
            .oxidized => null,
        };
    }

    pub fn prevStage(self: CopperOxidation) ?CopperOxidation {
        return switch (self) {
            .unaffected => null,
            .exposed => .unaffected,
            .weathered => .exposed,
            .oxidized => .weathered,
        };
    }
};

/// Primary material categories for doors and trapdoors.
pub const DoorMaterial = enum(u8) {
    wood = 0,
    copper = 1,
    iron = 2,
};

/// Door and trapdoor species across 12 wood species, 4 copper oxidation stages, and 1 iron variant.
/// Total = 17 variants.
pub const DoorAndTrapdoorKind = enum(u8) {
    // 12 Wooden variants
    oak = 0,
    spruce = 1,
    birch = 2,
    jungle = 3,
    acacia = 4,
    dark_oak = 5,
    mangrove = 6,
    cherry = 7,
    bamboo = 8,
    crimson = 9,
    warped = 10,
    pale_oak = 11,

    // 4 Copper oxidation variants
    copper = 12,
    exposed_copper = 13,
    weathered_copper = 14,
    oxidized_copper = 15,

    // 1 Iron variant
    iron = 16,

    pub fn material(self: DoorAndTrapdoorKind) DoorMaterial {
        return switch (self) {
            .oak, .spruce, .birch, .jungle, .acacia, .dark_oak,
            .mangrove, .cherry, .bamboo, .crimson, .warped, .pale_oak => .wood,
            .copper, .exposed_copper, .weathered_copper, .oxidized_copper => .copper,
            .iron => .iron,
        };
    }

    pub fn isWooden(self: DoorAndTrapdoorKind) bool {
        return self.material() == .wood;
    }

    pub fn isCopper(self: DoorAndTrapdoorKind) bool {
        return self.material() == .copper;
    }

    pub fn isIron(self: DoorAndTrapdoorKind) bool {
        return self == .iron;
    }

    pub fn isCopperOrIron(self: DoorAndTrapdoorKind) bool {
        return self.isCopper() or self.isIron();
    }

    /// Wooden doors/trapdoors (12) and Copper doors/trapdoors (4) can be opened and closed by hand.
    /// Iron doors and trapdoors CANNOT be opened by hand and require a Redstone signal.
    pub fn canToggleByHand(self: DoorAndTrapdoorKind) bool {
        return self != .iron;
    }

    /// All doors and trapdoors (wood, copper, and iron) can be toggled by Redstone signals.
    pub fn canToggleByRedstone(self: DoorAndTrapdoorKind) bool {
        _ = self;
        return true;
    }

    /// Only iron variants strictly require redstone power to toggle because player interaction by hand is disabled.
    pub fn requiresRedstone(self: DoorAndTrapdoorKind) bool {
        return self == .iron;
    }

    pub fn isFlammable(self: DoorAndTrapdoorKind) bool {
        return switch (self) {
            .oak, .spruce, .birch, .jungle, .acacia, .dark_oak,
            .mangrove, .cherry, .bamboo, .pale_oak => true,
            .crimson, .warped, .copper, .exposed_copper, .weathered_copper, .oxidized_copper, .iron => false,
        };
    }

    pub fn hardness(self: DoorAndTrapdoorKind) f32 {
        return switch (self) {
            .iron => 5.0,
            .copper, .exposed_copper, .weathered_copper, .oxidized_copper => 3.0,
            else => 3.0,
        };
    }

    pub fn blastResistance(self: DoorAndTrapdoorKind) f32 {
        return switch (self) {
            .iron => 5.0,
            .copper, .exposed_copper, .weathered_copper, .oxidized_copper => 6.0,
            else => 3.0,
        };
    }

    pub fn woodSpecies(self: DoorAndTrapdoorKind) ?WoodSpecies {
        return switch (self) {
            .oak => .oak,
            .spruce => .spruce,
            .birch => .birch,
            .jungle => .jungle,
            .acacia => .acacia,
            .dark_oak => .dark_oak,
            .mangrove => .mangrove,
            .cherry => .cherry,
            .bamboo => .bamboo,
            .crimson => .crimson,
            .warped => .warped,
            .pale_oak => .pale_oak,
            else => null,
        };
    }

    pub fn copperOxidation(self: DoorAndTrapdoorKind) ?CopperOxidation {
        return switch (self) {
            .copper => .unaffected,
            .exposed_copper => .exposed,
            .weathered_copper => .weathered,
            .oxidized_copper => .oxidized,
            else => null,
        };
    }

    pub fn fromWoodSpecies(species: WoodSpecies) DoorAndTrapdoorKind {
        return switch (species) {
            .oak => .oak,
            .spruce => .spruce,
            .birch => .birch,
            .jungle => .jungle,
            .acacia => .acacia,
            .dark_oak => .dark_oak,
            .mangrove => .mangrove,
            .cherry => .cherry,
            .bamboo => .bamboo,
            .crimson => .crimson,
            .warped => .warped,
            .pale_oak => .pale_oak,
        };
    }

    pub fn fromCopperOxidation(ox: CopperOxidation) DoorAndTrapdoorKind {
        return switch (ox) {
            .unaffected => .copper,
            .exposed => .exposed_copper,
            .weathered => .weathered_copper,
            .oxidized => .oxidized_copper,
        };
    }
};

/// Half positioning for two-block-tall doors or trapdoors.
pub const BlockHalf = enum(u8) {
    bottom = 0,
    top = 1,
};

/// Half attachment for trapdoors within a single 1x1x1 block space.
pub const TrapdoorHalf = enum(u8) {
    bottom = 0,
    top = 1,
};

/// Hinge attachment side for doors.
pub const DoorHinge = enum(u8) {
    left = 0,
    right = 1,
};

/// Cardinal direction facing.
pub const Direction = enum(u8) {
    north = 0,
    south = 1,
    west = 2,
    east = 3,
    up = 4,
    down = 5,

    pub fn isHorizontal(self: Direction) bool {
        return self == .north or self == .south or self == .west or self == .east;
    }

    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .north => .south,
            .south => .north,
            .west => .east,
            .east => .west,
            .up => .down,
            .down => .up,
        };
    }
};

/// State of a door block.
pub const DoorState = struct {
    kind: DoorAndTrapdoorKind,
    facing: Direction = .north,
    open: bool = false,
    hinge: DoorHinge = .left,
    powered: bool = false,
    half: BlockHalf = .bottom,

    pub fn toggleByHand(self: *DoorState) bool {
        if (!self.kind.canToggleByHand()) return false;
        self.open = !self.open;
        return true;
    }

    pub fn applyRedstone(self: *DoorState, is_powered: bool) void {
        if (self.powered != is_powered) {
            self.powered = is_powered;
            self.open = is_powered;
        }
    }
};

/// State of a trapdoor block.
pub const TrapdoorState = struct {
    kind: DoorAndTrapdoorKind,
    facing: Direction = .north,
    half: TrapdoorHalf = .bottom,
    open: bool = false,
    powered: bool = false,
    waterlogged: bool = false,

    pub fn toggleByHand(self: *TrapdoorState) bool {
        if (!self.kind.canToggleByHand()) return false;
        self.open = !self.open;
        return true;
    }

    pub fn applyRedstone(self: *TrapdoorState, is_powered: bool) void {
        if (self.powered != is_powered) {
            self.powered = is_powered;
            self.open = is_powered;
        }
    }

    /// Vertical clearance within the block space when closed or open.
    pub fn effectiveClearance(self: TrapdoorState) f32 {
        if (self.open) return 1.0;
        return switch (self.half) {
            .top => TrapdoorCrawlTrigger.head_space_height, // 0.8125
            .bottom => 1.0 - TrapdoorCrawlTrigger.trapdoor_thickness, // 0.8125 standing on floor
        };
    }
};

/// Player posture and hitbox states.
pub const PlayerPosture = enum(u8) {
    standing = 0,
    sneaking = 1,
    crawling = 2,
    swimming = 3,
    gliding = 4,

    pub fn height(self: PlayerPosture) f32 {
        return switch (self) {
            .standing => 1.8,
            .sneaking => 1.5,
            .crawling, .swimming => 0.6,
            .gliding => 0.6,
        };
    }

    pub fn eyeHeight(self: PlayerPosture) f32 {
        return switch (self) {
            .standing => 1.62,
            .sneaking => 1.27,
            .crawling, .swimming => 0.4,
            .gliding => 0.4,
        };
    }

    pub fn speedMps(self: PlayerPosture) f32 {
        return switch (self) {
            .standing => 4.317,
            .sneaking => 1.295,
            .crawling => 1.295,
            .swimming => 1.97,
            .gliding => 30.0,
        };
    }

    pub fn isCrawlingOrSwimming(self: PlayerPosture) bool {
        return self == .crawling or self == .swimming;
    }
};

/// Trapdoor crawl mechanics:
/// Closing a top-half trapdoor down onto a standing player's head leaves:
/// head_space_height: 1.0 - 0.1875 = 0.8125 blocks clearance.
/// Because 0.8125 < 1.8 (standing) and 0.8125 < 1.5 (sneaking),
/// the player is forced into the 0.6-block-tall crawling/swimming posture,
/// enabling 1x1 strip-mining tunnel navigation at 1.295 m/s.
pub const TrapdoorCrawlTrigger = struct {
    pub const block_height: f32 = 1.0;
    pub const trapdoor_thickness: f32 = 0.1875; // 3/16 block thickness
    pub const head_space_height: f32 = 1.0 - 0.1875; // 0.8125 block clearance
    pub const standing_player_height: f32 = 1.8;
    pub const sneak_player_height: f32 = 1.5;
    pub const crawl_player_height: f32 = 0.6;
    pub const crawling_swimming_posture: PlayerPosture = .crawling;
    pub const crawl_speed_mps: f32 = 1.295;

    pub fn crawlSpeedMps() f32 {
        return TrapdoorCrawlTrigger.crawl_speed_mps;
    }

    pub fn triggersCrawlPosture(trapdoor_is_top_half: bool, closed_onto_player: bool) bool {
        return trapdoor_is_top_half and closed_onto_player;
    }

    pub fn canStandUp(clearance_height: f32) bool {
        return clearance_height >= standing_player_height;
    }

    pub fn canSneak(clearance_height: f32) bool {
        return clearance_height >= sneak_player_height;
    }

    pub fn canCrawl(clearance_height: f32) bool {
        return clearance_height >= crawl_player_height;
    }

    pub fn evaluatePosture(
        current: PlayerPosture,
        trapdoor_is_top_half: bool,
        closed_onto_player: bool,
        tunnel_height: f32,
    ) PlayerPosture {
        if (TrapdoorCrawlTrigger.triggersCrawlPosture(trapdoor_is_top_half, closed_onto_player)) {
            return .crawling;
        }
        if (tunnel_height < sneak_player_height and current.isCrawlingOrSwimming()) {
            return .crawling;
        }
        if (tunnel_height >= standing_player_height and current == .crawling) {
            return .standing;
        }
        return current;
    }
};

/// Trapdoor ladder climb bridging mechanics:
/// An open trapdoor attached to the same wall face directly above a ladder
/// functions as a climbable extension of the ladder, allowing seamless vertical exit.
pub const TrapdoorLadderBridge = struct {
    pub const ladder_climb_speed_up_mps: f32 = 2.35;
    pub const ladder_climb_speed_down_mps: f32 = 3.0;
    pub const ladder_thickness: f32 = 0.125; // 2/16 block

    pub fn canClimbOpenTrapdoorAboveLadder(trapdoor_is_open: bool, below_is_ladder: bool, same_facing: bool) bool {
        return trapdoor_is_open and below_is_ladder and same_facing;
    }

    pub fn canClimb(ladder_facing: Direction, trapdoor_facing: Direction, trapdoor_is_open: bool, below_is_ladder: bool) bool {
        const same_facing = (ladder_facing == trapdoor_facing);
        return TrapdoorLadderBridge.canClimbOpenTrapdoorAboveLadder(trapdoor_is_open, below_is_ladder, same_facing);
    }

    pub fn getClimbVelocityY(moving_up: bool, sneaking: bool) f32 {
        if (sneaking) return 0.0; // Sneaking holds the player stationary on ladders and open trapdoors
        if (moving_up) return 0.1175; // Positive vertical velocity in blocks/tick (~2.35 m/s)
        return -0.15; // Downward slide in blocks/tick (~3.0 m/s)
    }
};

/// AI pathfinding node classification for trapdoors and pits.
pub const PathNodeType = enum(u8) {
    blocked = 0,
    walkable_solid = 1,
    open_trapdoor = 2,
    closed_trapdoor = 3,
    water = 4,
    lava = 5,
    pit_drop = 6,
};

/// Mob pathfinding trapdoor trick:
/// AI pathfinding treats open trapdoors over a pit as solid walkable ground.
/// Because open trapdoors have no horizontal floor collision, mobs walk over the edge
/// and fall into mob-grinder drop shafts.
pub const MobPathfindingTrapdoorTrick = struct {
    pub fn mobTreatsOpenTrapdoorAsWalkable() bool {
        return true;
    }

    pub fn getPathNodeType(is_trapdoor: bool, is_open: bool, has_solid_support_below: bool) PathNodeType {
        if (!is_trapdoor) {
            return if (has_solid_support_below) .walkable_solid else .pit_drop;
        }
        if (is_open) {
            return .open_trapdoor;
        } else {
            return .closed_trapdoor;
        }
    }

    pub fn isTraversableByMobAi(node_type: PathNodeType) bool {
        return switch (node_type) {
            .walkable_solid, .closed_trapdoor, .open_trapdoor => true,
            .blocked, .lava, .pit_drop => false,
            .water => true,
        };
    }

    pub fn hasPhysicalCollision(is_trapdoor: bool, is_open: bool, has_solid_support_below: bool) bool {
        if (!is_trapdoor) return has_solid_support_below;
        if (is_open) return false; // Open trapdoor leaves the hole physically empty
        return true;
    }

    pub fn mobStepsAndFallsIntoPit(trapdoor_is_open: bool, is_over_pit: bool) bool {
        return MobPathfindingTrapdoorTrick.mobTreatsOpenTrapdoorAsWalkable() and trapdoor_is_open and is_over_pit;
    }

    /// In Minecraft, fall damage = max(0, fall_distance - 3.0).
    pub fn calculateFallDamage(fall_distance: f32) f32 {
        return @max(0.0, fall_distance - 3.0);
    }

    /// Zombies have 20 HP. A 23-block fall deals 20 damage (killing them outright).
    /// A 22-block fall deals 19 damage, leaving them at 1 HP for 1-hit kill xp grinding.
    pub fn isLethalToZombie(fall_distance: f32, zombie_health: f32) bool {
        return calculateFallDamage(fall_distance) >= zombie_health;
    }
};

/// Mob kinds with door interaction capabilities.
pub const MobKind = enum(u8) {
    zombie = 0,
    zombie_villager = 1,
    husk = 2,
    drowned = 3,
    zombified_piglin = 4,
    vindicator = 5,
    skeleton = 6,
    creeper = 7,
    spider = 8,
    iron_golem = 9,
    villager = 10,
    player = 11,

    pub fn canAttemptDoorBreak(self: MobKind) bool {
        return switch (self) {
            .zombie, .zombie_villager, .husk, .drowned, .vindicator => true,
            else => false,
        };
    }
};

/// Zombie and Vindicator door-breaking rules:
/// - Wooden doors can be broken ONLY on .hard difficulty.
/// - Iron and copper doors cannot be broken.
/// - Sideways door placement (default 'open' blockstate that visually blocks doorway) prevents breaking.
/// - Raising the door 1 block off the ground prevents breaking.
pub const ZombieHardDoorBreak = struct {
    pub const break_time_seconds: f32 = 12.0; // 240 ticks = 12 seconds
    pub const max_break_stages: u8 = 10;

    pub fn canZombieBreakDoor(difficulty: Difficulty, is_wooden_door: bool, is_copper_or_iron: bool) bool {
        if (difficulty != .hard) return false;
        if (!is_wooden_door) return false;
        if (is_copper_or_iron) return false;
        return true;
    }

    pub fn isPreventedBySidewaysPlacement(is_door_open_state: bool) bool {
        return is_door_open_state;
    }

    pub fn isPreventedByRaisedDoor(zombie_feet_y: i32, door_base_y: i32) bool {
        return door_base_y > zombie_feet_y;
    }

    pub fn isPreventedByMetalMaterial(kind: DoorAndTrapdoorKind) bool {
        return kind.isCopperOrIron();
    }

    pub fn canZombieBreakPlacedDoor(
        difficulty: Difficulty,
        kind: DoorAndTrapdoorKind,
        is_door_open_state: bool,
        zombie_feet_y: i32,
        door_base_y: i32,
        mob: MobKind,
    ) bool {
        if (!mob.canAttemptDoorBreak()) return false;
        if (!ZombieHardDoorBreak.canZombieBreakDoor(difficulty, kind.isWooden(), kind.isCopperOrIron())) return false;
        if (ZombieHardDoorBreak.isPreventedBySidewaysPlacement(is_door_open_state)) return false;
        if (ZombieHardDoorBreak.isPreventedByRaisedDoor(zombie_feet_y, door_base_y)) return false;
        return true;
    }
};

/// Tracks the progress of a zombie banging on a wooden door.
pub const DoorBreakTracker = struct {
    progress_seconds: f32 = 0.0,
    is_broken: bool = false,

    pub fn tick(self: *DoorBreakTracker, dt: f32, can_break: bool) bool {
        if (!can_break) {
            self.progress_seconds = 0.0;
            return false;
        }
        self.progress_seconds += dt;
        if (self.progress_seconds >= ZombieHardDoorBreak.break_time_seconds) {
            self.is_broken = true;
            return true;
        }
        return false;
    }

    pub fn crackStage(self: DoorBreakTracker) u4 {
        const ratio = @min(1.0, self.progress_seconds / ZombieHardDoorBreak.break_time_seconds);
        return @intFromFloat(ratio * 9.0);
    }

    pub fn reset(self: *DoorBreakTracker) void {
        self.progress_seconds = 0.0;
        self.is_broken = false;
    }
};

// ============================================================================
// Top-Level Convenience Aliases and Functions
// ============================================================================

pub const head_space_height: f32 = TrapdoorCrawlTrigger.head_space_height;
pub const crawl_speed_mps: f32 = TrapdoorCrawlTrigger.crawl_speed_mps;
pub const crawling_swimming_posture: PlayerPosture = TrapdoorCrawlTrigger.crawling_swimming_posture;

pub fn crawlSpeedMps() f32 {
    return TrapdoorCrawlTrigger.crawlSpeedMps();
}

pub fn triggersCrawlPosture(trapdoor_is_top_half: bool, closed_onto_player: bool) bool {
    return TrapdoorCrawlTrigger.triggersCrawlPosture(trapdoor_is_top_half, closed_onto_player);
}

pub fn canClimbOpenTrapdoorAboveLadder(trapdoor_is_open: bool, below_is_ladder: bool, same_facing: bool) bool {
    return TrapdoorLadderBridge.canClimbOpenTrapdoorAboveLadder(trapdoor_is_open, below_is_ladder, same_facing);
}

pub fn mobTreatsOpenTrapdoorAsWalkable() bool {
    return MobPathfindingTrapdoorTrick.mobTreatsOpenTrapdoorAsWalkable();
}

pub fn canZombieBreakDoor(difficulty: Difficulty, is_wooden_door: bool, is_copper_or_iron: bool) bool {
    return ZombieHardDoorBreak.canZombieBreakDoor(difficulty, is_wooden_door, is_copper_or_iron);
}

// ============================================================================
// Comprehensive Test Suite (17 Tests)
// ============================================================================

test "1. DoorAndTrapdoorKind has 12 wood, 4 copper, and 1 iron variant (17 total)" {
    var wood_count: usize = 0;
    var copper_count: usize = 0;
    var iron_count: usize = 0;

    const all_kinds = [_]DoorAndTrapdoorKind{
        .oak,            .spruce,           .birch,             .jungle,
        .acacia,         .dark_oak,         .mangrove,          .cherry,
        .bamboo,         .crimson,          .warped,            .pale_oak,
        .copper,         .exposed_copper,   .weathered_copper,  .oxidized_copper,
        .iron,
    };

    try std.testing.expectEqual(@as(usize, 17), all_kinds.len);

    for (all_kinds) |k| {
        switch (k.material()) {
            .wood => {
                wood_count += 1;
                try std.testing.expect(k.isWooden());
                try std.testing.expect(!k.isCopper());
                try std.testing.expect(!k.isIron());
                try std.testing.expect(!k.isCopperOrIron());
            },
            .copper => {
                copper_count += 1;
                try std.testing.expect(!k.isWooden());
                try std.testing.expect(k.isCopper());
                try std.testing.expect(!k.isIron());
                try std.testing.expect(k.isCopperOrIron());
            },
            .iron => {
                iron_count += 1;
                try std.testing.expect(!k.isWooden());
                try std.testing.expect(!k.isCopper());
                try std.testing.expect(k.isIron());
                try std.testing.expect(k.isCopperOrIron());
            },
        }
    }

    try std.testing.expectEqual(@as(usize, 12), wood_count);
    try std.testing.expectEqual(@as(usize, 4), copper_count);
    try std.testing.expectEqual(@as(usize, 1), iron_count);
}

test "2. canToggleByHand rules: 12 wood = true, 4 copper = true, 1 iron = false" {
    // 12 Wooden species can be opened by hand
    try std.testing.expect(DoorAndTrapdoorKind.oak.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.spruce.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.birch.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.jungle.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.acacia.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.dark_oak.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.mangrove.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.cherry.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.bamboo.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.crimson.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.warped.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.pale_oak.canToggleByHand());

    // 4 Copper oxidation stages can also be opened by hand
    try std.testing.expect(DoorAndTrapdoorKind.copper.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.exposed_copper.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.weathered_copper.canToggleByHand());
    try std.testing.expect(DoorAndTrapdoorKind.oxidized_copper.canToggleByHand());

    // 1 Iron variant CANNOT be opened by hand
    try std.testing.expect(!DoorAndTrapdoorKind.iron.canToggleByHand());
}

test "3. Redstone power rules: iron requires redstone, all 17 toggle with redstone" {
    const all_kinds = [_]DoorAndTrapdoorKind{
        .oak,            .spruce,           .birch,             .jungle,
        .acacia,         .dark_oak,         .mangrove,          .cherry,
        .bamboo,         .crimson,          .warped,            .pale_oak,
        .copper,         .exposed_copper,   .weathered_copper,  .oxidized_copper,
        .iron,
    };

    for (all_kinds) |k| {
        // Every door/trapdoor species responds to redstone signals
        try std.testing.expect(k.canToggleByRedstone());

        // Only iron requires redstone
        if (k == .iron) {
            try std.testing.expect(k.requiresRedstone());
        } else {
            try std.testing.expect(!k.requiresRedstone());
        }
    }
}

test "4. DoorState interaction: hand toggling and redstone actuation" {
    var oak_door = DoorState{ .kind = .oak };
    try std.testing.expect(!oak_door.open);
    try std.testing.expect(oak_door.toggleByHand());
    try std.testing.expect(oak_door.open);
    try std.testing.expect(oak_door.toggleByHand());
    try std.testing.expect(!oak_door.open);

    var iron_door = DoorState{ .kind = .iron };
    try std.testing.expect(!iron_door.open);
    // Hand toggle must fail on iron door
    try std.testing.expect(!iron_door.toggleByHand());
    try std.testing.expect(!iron_door.open);

    // Redstone pulse opens and closes iron door
    iron_door.applyRedstone(true);
    try std.testing.expect(iron_door.open);
    try std.testing.expect(iron_door.powered);

    iron_door.applyRedstone(false);
    try std.testing.expect(!iron_door.open);
    try std.testing.expect(!iron_door.powered);
}

test "5. TrapdoorState interaction: top and bottom half, hand and redstone" {
    var copper_trapdoor = TrapdoorState{
        .kind = .weathered_copper,
        .half = .top,
        .open = false,
    };
    try std.testing.expect(copper_trapdoor.toggleByHand());
    try std.testing.expect(copper_trapdoor.open);

    var iron_trapdoor = TrapdoorState{
        .kind = .iron,
        .half = .bottom,
        .open = false,
    };
    try std.testing.expect(!iron_trapdoor.toggleByHand());
    try std.testing.expect(!iron_trapdoor.open);

    iron_trapdoor.applyRedstone(true);
    try std.testing.expect(iron_trapdoor.open);
}

test "6. TrapdoorCrawlTrigger clearance math: 0.8125 head space compresses standing and sneaking" {
    const clearance = TrapdoorCrawlTrigger.head_space_height;
    try std.testing.expectEqual(@as(f32, 0.8125), clearance);
    try std.testing.expectEqual(@as(f32, 1.0 - 0.1875), clearance);

    // Standing player (1.8 blocks) does not fit
    try std.testing.expect(!TrapdoorCrawlTrigger.canStandUp(clearance));
    try std.testing.expect(clearance < TrapdoorCrawlTrigger.standing_player_height);

    // Sneaking player (1.5 blocks) does not fit
    try std.testing.expect(!TrapdoorCrawlTrigger.canSneak(clearance));
    try std.testing.expect(clearance < TrapdoorCrawlTrigger.sneak_player_height);

    // Crawling player (0.6 blocks) fits comfortably
    try std.testing.expect(TrapdoorCrawlTrigger.canCrawl(clearance));
    try std.testing.expect(clearance >= TrapdoorCrawlTrigger.crawl_player_height);
}

test "7. triggersCrawlPosture: only top-half trapdoor closed onto player triggers crawl" {
    // Top-half trapdoor closed onto standing player triggers crawl
    try std.testing.expect(triggersCrawlPosture(true, true));
    try std.testing.expect(TrapdoorCrawlTrigger.triggersCrawlPosture(true, true));

    // Bottom-half trapdoor closed does NOT trigger crawl (player stands on top of it)
    try std.testing.expect(!triggersCrawlPosture(false, true));

    // Top-half open trapdoor does NOT trigger crawl (full vertical space available)
    try std.testing.expect(!triggersCrawlPosture(true, false));

    // Bottom-half open does not trigger crawl
    try std.testing.expect(!triggersCrawlPosture(false, false));
}

test "8. crawlSpeedMps and 1x1 strip-mining tunnel navigation" {
    try std.testing.expectEqual(@as(f32, 1.295), crawlSpeedMps());
    try std.testing.expectEqual(@as(f32, 1.295), TrapdoorCrawlTrigger.crawlSpeedMps());
    try std.testing.expectEqual(@as(f32, 1.295), PlayerPosture.crawling.speedMps());

    // In a 1x1 strip-mining tunnel (clearance 1.0 block):
    const tunnel_height: f32 = 1.0;
    var posture: PlayerPosture = .standing;

    // Trapdoor closes onto player -> switches to crawling
    posture = TrapdoorCrawlTrigger.evaluatePosture(posture, true, true, tunnel_height);
    try std.testing.expectEqual(PlayerPosture.crawling, posture);

    // Inside the 1x1 tunnel with no trapdoor, player cannot stand up and stays crawling
    posture = TrapdoorCrawlTrigger.evaluatePosture(posture, false, false, tunnel_height);
    try std.testing.expectEqual(PlayerPosture.crawling, posture);

    // Exiting 1x1 tunnel into a 2-block-tall cavern (clearance 2.0 blocks) -> stands up
    const cavern_height: f32 = 2.0;
    posture = TrapdoorCrawlTrigger.evaluatePosture(posture, false, false, cavern_height);
    try std.testing.expectEqual(PlayerPosture.standing, posture);
}

test "9. TrapdoorLadderBridge: open trapdoor above ladder on same wall face allows climb" {
    // Open trapdoor directly above ladder with identical wall facing
    try std.testing.expect(canClimbOpenTrapdoorAboveLadder(true, true, true));
    try std.testing.expect(TrapdoorLadderBridge.canClimbOpenTrapdoorAboveLadder(true, true, true));

    // With explicit directions
    try std.testing.expect(TrapdoorLadderBridge.canClimb(.north, .north, true, true));
    try std.testing.expect(TrapdoorLadderBridge.canClimb(.south, .south, true, true));
    try std.testing.expect(TrapdoorLadderBridge.canClimb(.east, .east, true, true));
    try std.testing.expect(TrapdoorLadderBridge.canClimb(.west, .west, true, true));
}

test "10. TrapdoorLadderBridge: closed trapdoors, opposite facing, or missing ladder block climbing" {
    // Closed trapdoor above ladder blocks exit
    try std.testing.expect(!canClimbOpenTrapdoorAboveLadder(false, true, true));

    // Open trapdoor but different facing (e.g., ladder on north wall, trapdoor on south wall)
    try std.testing.expect(!canClimbOpenTrapdoorAboveLadder(true, true, false));
    try std.testing.expect(!TrapdoorLadderBridge.canClimb(.north, .south, true, true));

    // Open trapdoor on same wall, but block below is NOT a ladder
    try std.testing.expect(!canClimbOpenTrapdoorAboveLadder(true, false, true));

    // All conditions false
    try std.testing.expect(!canClimbOpenTrapdoorAboveLadder(false, false, false));
}

test "11. TrapdoorLadderBridge velocities and sneaking ladder suspension" {
    // Moving up ladder / open trapdoor
    const v_up = TrapdoorLadderBridge.getClimbVelocityY(true, false);
    try std.testing.expect(v_up > 0.0);

    // Sliding down ladder
    const v_down = TrapdoorLadderBridge.getClimbVelocityY(false, false);
    try std.testing.expect(v_down < 0.0);

    // Sneaking freezes vertical velocity to 0.0
    const v_sneak_up = TrapdoorLadderBridge.getClimbVelocityY(true, true);
    try std.testing.expectEqual(@as(f32, 0.0), v_sneak_up);

    const v_sneak_down = TrapdoorLadderBridge.getClimbVelocityY(false, true);
    try std.testing.expectEqual(@as(f32, 0.0), v_sneak_down);
}

test "12. MobPathfindingTrapdoorTrick: AI treats open trapdoors as solid walkable ground" {
    try std.testing.expect(mobTreatsOpenTrapdoorAsWalkable());
    try std.testing.expect(MobPathfindingTrapdoorTrick.mobTreatsOpenTrapdoorAsWalkable());

    // PathNodeType for open trapdoor is traversable by mob AI
    const node = MobPathfindingTrapdoorTrick.getPathNodeType(true, true, false);
    try std.testing.expectEqual(PathNodeType.open_trapdoor, node);
    try std.testing.expect(MobPathfindingTrapdoorTrick.isTraversableByMobAi(node));

    // Physical collision is absent for open trapdoors
    const has_col = MobPathfindingTrapdoorTrick.hasPhysicalCollision(true, true, false);
    try std.testing.expect(!has_col);

    // Mob steps on open trapdoor over pit and falls
    try std.testing.expect(MobPathfindingTrapdoorTrick.mobStepsAndFallsIntoPit(true, true));

    // If trapdoor is closed, mob does NOT fall into pit
    try std.testing.expect(!MobPathfindingTrapdoorTrick.mobStepsAndFallsIntoPit(false, true));
}

test "13. Mob grinder drop shaft fall damage and lethal heights" {
    // Fall distance <= 3.0 deals 0 damage
    try std.testing.expectEqual(@as(f32, 0.0), MobPathfindingTrapdoorTrick.calculateFallDamage(3.0));
    try std.testing.expectEqual(@as(f32, 0.0), MobPathfindingTrapdoorTrick.calculateFallDamage(2.5));

    // Fall distance 22.0 deals 19 damage -> zombie left at 1 HP (non-lethal)
    const dmg_22 = MobPathfindingTrapdoorTrick.calculateFallDamage(22.0);
    try std.testing.expectEqual(@as(f32, 19.0), dmg_22);
    try std.testing.expect(!MobPathfindingTrapdoorTrick.isLethalToZombie(22.0, 20.0));

    // Fall distance 23.0 deals 20 damage -> lethal to standard 20 HP zombie
    const dmg_23 = MobPathfindingTrapdoorTrick.calculateFallDamage(23.0);
    try std.testing.expectEqual(@as(f32, 20.0), dmg_23);
    try std.testing.expect(MobPathfindingTrapdoorTrick.isLethalToZombie(23.0, 20.0));

    // Fall distance 24.0 deals 21 damage -> lethal
    try std.testing.expect(MobPathfindingTrapdoorTrick.isLethalToZombie(24.0, 20.0));
}

test "14. ZombieHardDoorBreak difficulty restriction: ONLY hard difficulty allows breaking" {
    // Hard difficulty allows breaking wooden doors
    try std.testing.expect(canZombieBreakDoor(.hard, true, false));
    try std.testing.expect(ZombieHardDoorBreak.canZombieBreakDoor(.hard, true, false));

    // Normal, Easy, and Peaceful difficulties prevent breaking
    try std.testing.expect(!canZombieBreakDoor(.normal, true, false));
    try std.testing.expect(!canZombieBreakDoor(.easy, true, false));
    try std.testing.expect(!canZombieBreakDoor(.peaceful, true, false));
}

test "15. ZombieHardDoorBreak material restriction: wood breaks, copper and iron never break" {
    // 12 Wooden species break on hard difficulty
    const wood_species = [_]DoorAndTrapdoorKind{
        .oak,     .spruce,  .birch,   .jungle,
        .acacia,  .dark_oak, .mangrove, .cherry,
        .bamboo,  .crimson,  .warped,  .pale_oak,
    };
    for (wood_species) |w| {
        try std.testing.expect(canZombieBreakDoor(.hard, w.isWooden(), w.isCopperOrIron()));
    }

    // 4 Copper variants cannot be broken, even on hard
    const copper_species = [_]DoorAndTrapdoorKind{
        .copper, .exposed_copper, .weathered_copper, .oxidized_copper,
    };
    for (copper_species) |c| {
        try std.testing.expect(!canZombieBreakDoor(.hard, c.isWooden(), c.isCopperOrIron()));
    }

    // Iron cannot be broken, even on hard
    try std.testing.expect(!canZombieBreakDoor(.hard, DoorAndTrapdoorKind.iron.isWooden(), DoorAndTrapdoorKind.iron.isCopperOrIron()));
}

test "16. Zombie door bypass tricks: sideways placement and raised door prevent breaks" {
    // Standard setup: closed wooden door at ground level on hard -> breakable
    try std.testing.expect(ZombieHardDoorBreak.canZombieBreakPlacedDoor(
        .hard,
        .oak,
        false, // open state is false (closed)
        64,    // zombie feet Y
        64,    // door base Y
        .zombie,
    ));

    // Sideways door trick: door placed so open blockstate visually blocks doorway
    // Zombie AI ignores doors with open == true!
    try std.testing.expect(!ZombieHardDoorBreak.canZombieBreakPlacedDoor(
        .hard,
        .oak,
        true, // open state is true (sideways trick)
        64,
        64,
        .zombie,
    ));

    // Raised door trick: door base is 1 block above zombie feet (Y=65 vs Y=64)
    try std.testing.expect(!ZombieHardDoorBreak.canZombieBreakPlacedDoor(
        .hard,
        .oak,
        false,
        64, // zombie feet
        65, // door raised 1 block
        .zombie,
    ));

    // Non-breaking mobs (e.g., Skeleton, Creeper) cannot break doors
    try std.testing.expect(!ZombieHardDoorBreak.canZombieBreakPlacedDoor(
        .hard,
        .oak,
        false,
        64,
        64,
        .skeleton,
    ));

    // Vindicator CAN break doors on hard
    try std.testing.expect(ZombieHardDoorBreak.canZombieBreakPlacedDoor(
        .hard,
        .dark_oak,
        false,
        64,
        64,
        .vindicator,
    ));
}

test "17. DoorBreakTracker: 12-second break duration and crack stage progression" {
    var tracker = DoorBreakTracker{};
    try std.testing.expect(!tracker.is_broken);
    try std.testing.expectEqual(@as(u4, 0), tracker.crackStage());

    // Advance 6 seconds (halfway through break progress)
    const broken_mid = tracker.tick(6.0, true);
    try std.testing.expect(!broken_mid);
    try std.testing.expect(!tracker.is_broken);
    try std.testing.expect(tracker.crackStage() >= 4);

    // If can_break becomes false (e.g. day arrives or zombie pushed away), progress resets
    _ = tracker.tick(1.0, false);
    try std.testing.expectEqual(@as(f32, 0.0), tracker.progress_seconds);
    try std.testing.expectEqual(@as(u4, 0), tracker.crackStage());

    // Advance 12 full seconds
    _ = tracker.tick(11.9, true);
    try std.testing.expect(!tracker.is_broken);
    const broken_final = tracker.tick(0.2, true);
    try std.testing.expect(broken_final);
    try std.testing.expect(tracker.is_broken);
    try std.testing.expectEqual(@as(u4, 9), tracker.crackStage());
}
