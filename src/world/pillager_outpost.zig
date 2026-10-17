const std = @import("std");

/// ============================================================================
/// Milestone 383: Pillager Outpost Watchtower, Captain Ominous Bottle Drops,
/// Caged Allies & Goat Horn Chest Loot
/// ============================================================================

// ============================================================================
// 1. Outpost Spawn Volume & Natural Spawning Rules
// ============================================================================

/// Ground block types recognized by pillager outpost surface spawning logic.
pub const GroundBlockType = enum {
    grass,
    sand,
    stone,
    cobblestone,
    dark_oak_planks,
    dark_oak_log,
    dirt,
    gravel,
    air,
    water,
    lava,

    pub fn isGrassOrSand(self: GroundBlockType) bool {
        return self == .grass or self == .sand;
    }

    pub fn isSolid(self: GroundBlockType) bool {
        return switch (self) {
            .air, .water, .lava => false,
            else => true,
        };
    }
};

/// Pillager Outpost continuous bounding box centered on the watchtower:
/// Dimensions: 72 blocks (X) x 54 blocks (Y) x 72 blocks (Z).
pub const OutpostSpawnVolume = struct {
    pub const size_x: i32 = 72;
    pub const size_y: i32 = 54;
    pub const size_z: i32 = 72;

    pub const half_x: i32 = 36;
    pub const half_y: i32 = 27;
    pub const half_z: i32 = 36;

    /// Relative coordinate ranges centered at (0, 0, 0):
    /// Total discrete blocks: 35 - (-36) + 1 = 72.
    pub const min_dx: i32 = -36;
    pub const max_dx: i32 = 35;
    pub const min_dy: i32 = -27;
    pub const max_dy: i32 = 26;
    pub const min_dz: i32 = -36;
    pub const max_dz: i32 = 35;

    pub const total_volume_blocks: usize = @as(usize, @intCast(size_x)) *
        @as(usize, @intCast(size_y)) *
        @as(usize, @intCast(size_z));

    pub fn isWithin(dx: i32, dy: i32, dz: i32) bool {
        return isWithinOutpostSpawnBox(dx, dy, dz);
    }

    pub fn isWithinContinuous(x: f32, y: f32, z: f32) bool {
        return @abs(x) <= @as(f32, @floatFromInt(half_x)) and
            @abs(y) <= @as(f32, @floatFromInt(half_y)) and
            @abs(z) <= @as(f32, @floatFromInt(half_z));
    }
};

/// Continuous Pillager bounding box centered on the watchtower:
/// Returns true if (dx, dy, dz) lies within the 72x54x72 bounding box.
pub fn isWithinOutpostSpawnBox(dx: i32, dy: i32, dz: i32) bool {
    return (dx >= OutpostSpawnVolume.min_dx and dx <= OutpostSpawnVolume.max_dx) and
        (dy >= OutpostSpawnVolume.min_dy and dy <= OutpostSpawnVolume.max_dy) and
        (dz >= OutpostSpawnVolume.min_dz and dz <= OutpostSpawnVolume.max_dz);
}

/// Standard hostile mob maximum light level threshold.
pub const max_monster_spawn_light: u8 = 7;

/// Evaluates if a Pillager can spawn on a block surface based on light and block type:
/// - On grass or sand: irrespective of block light level if sky light allows (e.g. daytime or open sky).
/// - On any solid block: if block light level <= 7.
pub fn canPillagerSpawn(
    ground: GroundBlockType,
    block_light: u8,
    sky_light_allows: bool,
) bool {
    if (!ground.isSolid()) return false;
    if (ground.isGrassOrSand() and sky_light_allows) {
        return true;
    }
    return block_light <= max_monster_spawn_light;
}

/// Evaluates if a Pillager can spawn at relative offset (dx, dy, dz) from the watchtower center.
/// Must be within the 72x54x72 spawn volume AND satisfy the surface/lighting rules.
pub fn canPillagerSpawnAt(
    dx: i32,
    dy: i32,
    dz: i32,
    ground: GroundBlockType,
    block_light: u8,
    sky_light_allows: bool,
) bool {
    if (!isWithinOutpostSpawnBox(dx, dy, dz)) return false;
    return canPillagerSpawn(ground, block_light, sky_light_allows);
}

/// Evaluates raw boolean conditions for pillager spawn.
pub fn canPillagerSpawnRaw(
    is_grass_or_sand: bool,
    is_solid: bool,
    block_light: u8,
    sky_light_allows: bool,
) bool {
    if (!is_solid) return false;
    if (is_grass_or_sand and sky_light_allows) return true;
    return block_light <= max_monster_spawn_light;
}

// ============================================================================
// 2. Outpost Captain & Ominous Bottle Drops
// ============================================================================

pub const pillager_max_health: f32 = 24.0;
pub const min_bad_omen_amplifier: u8 = 1;
pub const max_bad_omen_amplifier: u8 = 5;
pub const bad_omen_duration_seconds: f32 = 6000.0; // 100 minutes

/// Ominous Bottle item giving Bad Omen I..V upon consumption.
pub const OminousBottle = struct {
    amplifier: u8 = 1, // 1..5

    pub fn init(tier: u8) OminousBottle {
        return .{
            .amplifier = std.math.clamp(tier, min_bad_omen_amplifier, max_bad_omen_amplifier),
        };
    }

    pub fn badOmenLevel(self: OminousBottle) u8 {
        return self.amplifier;
    }

    pub fn durationSeconds(self: OminousBottle) f32 {
        _ = self;
        return bad_omen_duration_seconds;
    }
};

/// Canonical Ominous Banner worn by raid / outpost captains.
pub const OminousBanner = struct {
    name: []const u8 = "Ominous Banner",
    base_color: []const u8 = "white",
    pattern_count: u8 = 6,
    is_ominous: bool = true,
};

/// Items dropped when an Outpost Captain is defeated.
pub const CaptainDrops = struct {
    has_ominous_banner: bool,
    ominous_banner_count: u8,
    ominous_bottle: ?OminousBottle,
    ominous_bottle_count: u8,
};

/// Outpost Captain mob wearing an Ominous Banner on their head.
pub const OutpostCaptain = struct {
    has_ominous_banner: bool = true,
    health: f32 = pillager_max_health,
    is_alive: bool = true,
    bottle_tier: u8 = 1,

    pub fn init(bottle_tier: u8) OutpostCaptain {
        return .{
            .has_ominous_banner = true,
            .health = pillager_max_health,
            .is_alive = true,
            .bottle_tier = std.math.clamp(bottle_tier, min_bad_omen_amplifier, max_bad_omen_amplifier),
        };
    }

    /// Drops 1 Ominous Bottle (Bad Omen I..V) and 1 Ominous Banner upon death.
    pub fn onDeath(self: *OutpostCaptain) CaptainDrops {
        self.is_alive = false;
        if (self.has_ominous_banner) {
            self.has_ominous_banner = false;
            return .{
                .has_ominous_banner = true,
                .ominous_banner_count = 1,
                .ominous_bottle = OminousBottle.init(self.bottle_tier),
                .ominous_bottle_count = 1,
            };
        } else {
            return .{
                .has_ominous_banner = false,
                .ominous_banner_count = 0,
                .ominous_bottle = null,
                .ominous_bottle_count = 0,
            };
        }
    }

    pub fn takeDamage(self: *OutpostCaptain, damage: f32) ?CaptainDrops {
        if (!self.is_alive) return null;
        if (damage >= self.health) {
            self.health = 0.0;
            return self.onDeath();
        } else {
            self.health -= damage;
            return null;
        }
    }
};

// ============================================================================
// 3. Outpost Substructures & Target Scarecrow Dummy
// ============================================================================

/// Substructures generated surrounding the central watchtower.
pub const OutpostSubstructure = enum {
    target_scarecrow,
    wooden_tent,
    log_pile,
    prison_cage,

    pub fn name(self: OutpostSubstructure) []const u8 {
        return switch (self) {
            .target_scarecrow => "Target Scarecrow",
            .wooden_tent => "Wooden Tent",
            .log_pile => "Log Pile",
            .prison_cage => "Prison Cage",
        };
    }

    pub fn description(self: OutpostSubstructure) []const u8 {
        return switch (self) {
            .target_scarecrow => "Carved pumpkin head + hay bale dummy for crossbow practice",
            .wooden_tent => "White wool and dark oak planks outpost tent",
            .log_pile => "Dark oak logs stacked horizontally with birch fences",
            .prison_cage => "Dark oak fence prison cage holding captive allies",
        };
    }
};

/// Target practice dummy substructure.
pub const TargetScarecrow = struct {
    head_block: []const u8 = "carved_pumpkin",
    body_block: []const u8 = "hay_bale",
    support_block: []const u8 = "dark_oak_fence",
    is_dummy: bool = true,

    pub fn isValidDummy(head: []const u8, body: []const u8) bool {
        return std.mem.eql(u8, head, "carved_pumpkin") and
            std.mem.eql(u8, body, "hay_bale");
    }
};

// ============================================================================
// 4. Outpost Prison Cage & Caged Allies
// ============================================================================

pub const CagedAllyType = enum {
    iron_golem,
    allay,
};

pub const iron_golem_hp: f32 = 100.0;
pub const min_allay_cage_count: u8 = 1;
pub const max_allay_cage_count: u8 = 3;

/// Result when a cage is breached or opened.
pub const CageReleaseResult = struct {
    ally_type: CagedAllyType,
    iron_golem_hp: f32 = 0.0,
    attacks_pillagers_immediately: bool = false,
    rescued_allays_count: u8 = 0,
    is_rescued: bool = true,
};

/// Dark oak fence cage holding either an Iron Golem (100 HP) or 1..3 Allays.
pub const OutpostPrisonCage = struct {
    wall_material: []const u8 = "dark_oak_fence",
    gate_material: []const u8 = "dark_oak_fence_gate",
    ally_type: CagedAllyType,
    golem_health: f32 = iron_golem_hp,
    allay_count: u8 = 1,
    is_broken: bool = false,
    is_open: bool = false,

    pub fn initIronGolem() OutpostPrisonCage {
        return .{
            .ally_type = .iron_golem,
            .golem_health = iron_golem_hp,
            .allay_count = 0,
            .is_broken = false,
            .is_open = false,
        };
    }

    pub fn initAllays(count: u8) OutpostPrisonCage {
        return .{
            .ally_type = .allay,
            .golem_health = 0.0,
            .allay_count = std.math.clamp(count, min_allay_cage_count, max_allay_cage_count),
            .is_broken = false,
            .is_open = false,
        };
    }

    /// Breaking the fence cage releases the captive(s).
    /// If an Iron Golem, attacks Pillagers immediately.
    pub fn breakCage(self: *OutpostPrisonCage) ?CageReleaseResult {
        if (self.is_broken or self.is_open) return null;
        self.is_broken = true;
        return self.release();
    }

    /// Opening the fence gate or bars releases the captive(s).
    pub fn openGateOrBars(self: *OutpostPrisonCage) ?CageReleaseResult {
        if (self.is_open or self.is_broken) return null;
        self.is_open = true;
        return self.release();
    }

    fn release(self: *OutpostPrisonCage) CageReleaseResult {
        switch (self.ally_type) {
            .iron_golem => return .{
                .ally_type = .iron_golem,
                .iron_golem_hp = self.golem_health,
                .attacks_pillagers_immediately = true,
                .rescued_allays_count = 0,
                .is_rescued = true,
            },
            .allay => return .{
                .ally_type = .allay,
                .iron_golem_hp = 0.0,
                .attacks_pillagers_immediately = false,
                .rescued_allays_count = self.allay_count,
                .is_rescued = true,
            },
        }
    }
};

// ============================================================================
// 5. Watchtower Chest Loot & Regular Goat Horns
// ============================================================================

/// Canonical Regular Goat Horn variants found in pillager outpost watchtower chests.
/// (Screaming goat horn variants Admire, Call, Yearn, Dream are NOT in outpost chests).
pub const RegularGoatHorn = enum(u2) {
    ponder = 0,
    sing = 1,
    seek = 2,
    feel = 3,

    pub fn name(self: RegularGoatHorn) []const u8 {
        return switch (self) {
            .ponder => "Ponder",
            .sing => "Sing",
            .seek => "Seek",
            .feel => "Feel",
        };
    }

    pub fn soundId(self: RegularGoatHorn) []const u8 {
        return switch (self) {
            .ponder => "minecraft:item.goat_horn.sound.0",
            .sing => "minecraft:item.goat_horn.sound.1",
            .seek => "minecraft:item.goat_horn.sound.2",
            .feel => "minecraft:item.goat_horn.sound.3",
        };
    }
};

pub const regular_goat_horns = [_]RegularGoatHorn{
    .ponder,
    .sing,
    .seek,
    .feel,
};

/// Items present in the Watchtower chest loot table.
pub const OutpostLootItem = enum {
    crossbow,
    dark_oak_logs,
    bottle_o_enchanting,
    sentry_armor_trim_smithing_template,
    goat_horn,

    pub fn name(self: OutpostLootItem) []const u8 {
        return switch (self) {
            .crossbow => "Crossbow",
            .dark_oak_logs => "Dark Oak Log",
            .bottle_o_enchanting => "Bottle o' Enchanting",
            .sentry_armor_trim_smithing_template => "Sentry Armor Trim Smithing Template",
            .goat_horn => "Goat Horn",
        };
    }
};

pub const LootStack = struct {
    item: OutpostLootItem,
    count: u8,
    horn_variant: ?RegularGoatHorn = null,
};

/// Watchtower top-floor chest loot table generator and verification.
pub const OutpostWatchtowerChestLoot = struct {
    pub const available_items = [_]OutpostLootItem{
        .crossbow,
        .dark_oak_logs,
        .bottle_o_enchanting,
        .sentry_armor_trim_smithing_template,
        .goat_horn,
    };

    pub fn rollGoatHorn(roll: u2) RegularGoatHorn {
        return regular_goat_horns[roll];
    }

    pub fn getLootItem(index: usize) OutpostLootItem {
        return available_items[index % available_items.len];
    }

    pub fn createLootStack(item: OutpostLootItem, count_roll: u8, horn_roll: u2) LootStack {
        return switch (item) {
            .crossbow => .{
                .item = .crossbow,
                .count = 1,
            },
            .dark_oak_logs => .{
                .item = .dark_oak_logs,
                .count = 2 + (count_roll % 4), // 2..5 logs
            },
            .bottle_o_enchanting => .{
                .item = .bottle_o_enchanting,
                .count = 1 + (count_roll % 2), // 1..2 bottles
            },
            .sentry_armor_trim_smithing_template => .{
                .item = .sentry_armor_trim_smithing_template,
                .count = 1 + (count_roll % 2), // 1..2 templates
            },
            .goat_horn => .{
                .item = .goat_horn,
                .count = 1,
                .horn_variant = rollGoatHorn(horn_roll),
            },
        };
    }

    pub fn isValidLootItem(item: OutpostLootItem) bool {
        for (available_items) |valid_item| {
            if (item == valid_item) return true;
        }
        return false;
    }
};

// ============================================================================
// Comprehensive Test Suite (16 Test Blocks)
// ============================================================================

test "1. OutpostSpawnVolume 72x54x72 dimensions and volume calculation" {
    try std.testing.expectEqual(@as(i32, 72), OutpostSpawnVolume.size_x);
    try std.testing.expectEqual(@as(i32, 54), OutpostSpawnVolume.size_y);
    try std.testing.expectEqual(@as(i32, 72), OutpostSpawnVolume.size_z);

    try std.testing.expectEqual(@as(i32, 36), OutpostSpawnVolume.half_x);
    try std.testing.expectEqual(@as(i32, 27), OutpostSpawnVolume.half_y);
    try std.testing.expectEqual(@as(i32, 36), OutpostSpawnVolume.half_z);

    try std.testing.expectEqual(@as(usize, 279936), OutpostSpawnVolume.total_volume_blocks);
}

test "2. isWithinOutpostSpawnBox boundary checks for 72x54x72 box centered on watchtower" {
    // Watchtower center
    try std.testing.expect(isWithinOutpostSpawnBox(0, 0, 0));

    // Minimum boundary corner (-36, -27, -36)
    try std.testing.expect(isWithinOutpostSpawnBox(-36, -27, -36));

    // Maximum boundary corner (35, 26, 35)
    try std.testing.expect(isWithinOutpostSpawnBox(35, 26, 35));

    // Continuous float boundary check
    try std.testing.expect(OutpostSpawnVolume.isWithinContinuous(36.0, 27.0, 36.0));
    try std.testing.expect(OutpostSpawnVolume.isWithinContinuous(-36.0, -27.0, -36.0));
}

test "3. isWithinOutpostSpawnBox rejects coordinates outside bounds" {
    // Just outside along X
    try std.testing.expect(!isWithinOutpostSpawnBox(-37, 0, 0));
    try std.testing.expect(!isWithinOutpostSpawnBox(36, 0, 0));

    // Just outside along Y
    try std.testing.expect(!isWithinOutpostSpawnBox(0, -28, 0));
    try std.testing.expect(!isWithinOutpostSpawnBox(0, 27, 0));

    // Just outside along Z
    try std.testing.expect(!isWithinOutpostSpawnBox(0, 0, -37));
    try std.testing.expect(!isWithinOutpostSpawnBox(0, 0, 36));

    // Far away
    try std.testing.expect(!isWithinOutpostSpawnBox(100, 100, 100));
}

test "4. Pillager spawning on grass and sand succeeds regardless of block light when sky light allows" {
    // Grass with max block light 15 during daytime (sky light allows)
    try std.testing.expect(canPillagerSpawn(.grass, 15, true));
    try std.testing.expect(canPillagerSpawn(.grass, 10, true));
    try std.testing.expect(canPillagerSpawn(.grass, 0, true));

    // Sand with max block light 15 during daytime
    try std.testing.expect(canPillagerSpawn(.sand, 15, true));
    try std.testing.expect(canPillagerSpawn(.sand, 8, true));
    try std.testing.expect(canPillagerSpawn(.sand, 0, true));

    // Inside outpost spawn box
    try std.testing.expect(canPillagerSpawnAt(10, 5, -10, .grass, 14, true));
    try std.testing.expect(canPillagerSpawnAt(-20, 0, 20, .sand, 15, true));
}

test "5. Pillager spawning on solid blocks requires block light <= 7" {
    // Cobblestone, stone, planks at light <= 7 succeed even without sky light
    try std.testing.expect(canPillagerSpawn(.cobblestone, 7, false));
    try std.testing.expect(canPillagerSpawn(.cobblestone, 0, false));
    try std.testing.expect(canPillagerSpawn(.stone, 5, false));
    try std.testing.expect(canPillagerSpawn(.dark_oak_planks, 6, false));

    // Grass at night (no sky light) still spawns if block light <= 7
    try std.testing.expect(canPillagerSpawn(.grass, 7, false));
    try std.testing.expect(canPillagerSpawn(.grass, 4, false));
}

test "6. Pillager spawning rejects non-solid blocks and high light without sky light" {
    // Air, water, lava can never spawn pillagers
    try std.testing.expect(!canPillagerSpawn(.air, 0, true));
    try std.testing.expect(!canPillagerSpawn(.water, 0, true));
    try std.testing.expect(!canPillagerSpawn(.lava, 0, true));

    // Solid stone/cobblestone at light 8 fails
    try std.testing.expect(!canPillagerSpawn(.stone, 8, false));
    try std.testing.expect(!canPillagerSpawn(.cobblestone, 12, true));

    // Grass at night with torch light 8 fails
    try std.testing.expect(!canPillagerSpawn(.grass, 8, false));

    // Outside bounding box fails
    try std.testing.expect(!canPillagerSpawnAt(40, 0, 0, .grass, 0, true));
}

test "7. OutpostCaptain defaults to wearing Ominous Banner on head" {
    const captain = OutpostCaptain.init(1);
    try std.testing.expect(captain.has_ominous_banner);
    try std.testing.expect(captain.is_alive);
    try std.testing.expectEqual(pillager_max_health, captain.health);
    try std.testing.expectEqual(@as(u8, 1), captain.bottle_tier);
}

test "8. OutpostCaptain death drops 1 Ominous Banner and 1 Ominous Bottle" {
    var captain = OutpostCaptain.init(3);
    const drops = captain.onDeath();

    try std.testing.expect(!captain.is_alive);
    try std.testing.expect(!captain.has_ominous_banner);

    try std.testing.expect(drops.has_ominous_banner);
    try std.testing.expectEqual(@as(u8, 1), drops.ominous_banner_count);

    try std.testing.expect(drops.ominous_bottle != null);
    try std.testing.expectEqual(@as(u8, 1), drops.ominous_bottle_count);
    try std.testing.expectEqual(@as(u8, 3), drops.ominous_bottle.?.amplifier);
    try std.testing.expectEqual(bad_omen_duration_seconds, drops.ominous_bottle.?.durationSeconds());

    // Subsequent death calls produce no drops
    const drops2 = captain.onDeath();
    try std.testing.expect(!drops2.has_ominous_banner);
    try std.testing.expectEqual(@as(u8, 0), drops2.ominous_banner_count);
    try std.testing.expect(drops2.ominous_bottle == null);
}

test "9. Ominous Bottle Bad Omen amplifier clamps to tiers I through V" {
    const b0 = OminousBottle.init(0);
    try std.testing.expectEqual(@as(u8, 1), b0.amplifier);

    const b1 = OminousBottle.init(1);
    try std.testing.expectEqual(@as(u8, 1), b1.amplifier);

    const b5 = OminousBottle.init(5);
    try std.testing.expectEqual(@as(u8, 5), b5.amplifier);

    const b99 = OminousBottle.init(99);
    try std.testing.expectEqual(@as(u8, 5), b99.amplifier);
}

test "10. OutpostSubstructure variants and descriptions" {
    const subs = [_]OutpostSubstructure{
        .target_scarecrow,
        .wooden_tent,
        .log_pile,
        .prison_cage,
    };
    try std.testing.expectEqual(@as(usize, 4), subs.len);

    try std.testing.expectEqualStrings("Target Scarecrow", OutpostSubstructure.target_scarecrow.name());
    try std.testing.expectEqualStrings("Wooden Tent", OutpostSubstructure.wooden_tent.name());
    try std.testing.expectEqualStrings("Log Pile", OutpostSubstructure.log_pile.name());
    try std.testing.expectEqualStrings("Prison Cage", OutpostSubstructure.prison_cage.name());
}

test "11. Target scarecrow dummy structure is made of carved pumpkin and hay bale" {
    const scarecrow = TargetScarecrow{};
    try std.testing.expectEqualStrings("carved_pumpkin", scarecrow.head_block);
    try std.testing.expectEqualStrings("hay_bale", scarecrow.body_block);
    try std.testing.expect(scarecrow.is_dummy);

    try std.testing.expect(TargetScarecrow.isValidDummy("carved_pumpkin", "hay_bale"));
    try std.testing.expect(!TargetScarecrow.isValidDummy("jack_o_lantern", "hay_bale"));
    try std.testing.expect(!TargetScarecrow.isValidDummy("carved_pumpkin", "dirt"));
}

test "12. OutpostPrisonCage with Iron Golem: 100 HP, attacks Pillagers immediately on break" {
    var cage = OutpostPrisonCage.initIronGolem();
    try std.testing.expectEqualStrings("dark_oak_fence", cage.wall_material);
    try std.testing.expectEqual(CagedAllyType.iron_golem, cage.ally_type);
    try std.testing.expectEqual(iron_golem_hp, cage.golem_health);
    try std.testing.expect(!cage.is_broken);
    try std.testing.expect(!cage.is_open);

    const release_result = cage.breakCage();
    try std.testing.expect(release_result != null);
    const result = release_result.?;

    try std.testing.expectEqual(CagedAllyType.iron_golem, result.ally_type);
    try std.testing.expectEqual(100.0, result.iron_golem_hp);
    try std.testing.expect(result.attacks_pillagers_immediately);
    try std.testing.expectEqual(@as(u8, 0), result.rescued_allays_count);
    try std.testing.expect(result.is_rescued);

    // Second break attempt returns null (already broken)
    try std.testing.expect(cage.breakCage() == null);
}

test "13. OutpostPrisonCage with Allays: holding 1..3 allays, rescued when gate opened" {
    var cage = OutpostPrisonCage.initAllays(2);
    try std.testing.expectEqual(CagedAllyType.allay, cage.ally_type);
    try std.testing.expectEqual(@as(u8, 2), cage.allay_count);

    const release_result = cage.openGateOrBars();
    try std.testing.expect(release_result != null);
    const result = release_result.?;

    try std.testing.expectEqual(CagedAllyType.allay, result.ally_type);
    try std.testing.expectEqual(@as(u8, 2), result.rescued_allays_count);
    try std.testing.expect(!result.attacks_pillagers_immediately);
    try std.testing.expect(result.is_rescued);

    // Opening again returns null
    try std.testing.expect(cage.openGateOrBars() == null);
}

test "14. OutpostPrisonCage clamps allay count between 1 and 3" {
    const cage_zero = OutpostPrisonCage.initAllays(0);
    try std.testing.expectEqual(@as(u8, 1), cage_zero.allay_count);

    const cage_three = OutpostPrisonCage.initAllays(3);
    try std.testing.expectEqual(@as(u8, 3), cage_three.allay_count);

    const cage_many = OutpostPrisonCage.initAllays(10);
    try std.testing.expectEqual(@as(u8, 3), cage_many.allay_count);
}

test "15. OutpostWatchtowerChestLoot items list and validation" {
    try std.testing.expect(OutpostWatchtowerChestLoot.isValidLootItem(.crossbow));
    try std.testing.expect(OutpostWatchtowerChestLoot.isValidLootItem(.dark_oak_logs));
    try std.testing.expect(OutpostWatchtowerChestLoot.isValidLootItem(.bottle_o_enchanting));
    try std.testing.expect(OutpostWatchtowerChestLoot.isValidLootItem(.sentry_armor_trim_smithing_template));
    try std.testing.expect(OutpostWatchtowerChestLoot.isValidLootItem(.goat_horn));

    try std.testing.expectEqualStrings("Crossbow", OutpostLootItem.crossbow.name());
    try std.testing.expectEqualStrings("Dark Oak Log", OutpostLootItem.dark_oak_logs.name());
    try std.testing.expectEqualStrings("Bottle o' Enchanting", OutpostLootItem.bottle_o_enchanting.name());
    try std.testing.expectEqualStrings("Sentry Armor Trim Smithing Template", OutpostLootItem.sentry_armor_trim_smithing_template.name());
    try std.testing.expectEqualStrings("Goat Horn", OutpostLootItem.goat_horn.name());
}

test "16. Regular Goat Horn chest loot only produces Ponder, Sing, Seek, Feel" {
    try std.testing.expectEqual(RegularGoatHorn.ponder, OutpostWatchtowerChestLoot.rollGoatHorn(0));
    try std.testing.expectEqual(RegularGoatHorn.sing, OutpostWatchtowerChestLoot.rollGoatHorn(1));
    try std.testing.expectEqual(RegularGoatHorn.seek, OutpostWatchtowerChestLoot.rollGoatHorn(2));
    try std.testing.expectEqual(RegularGoatHorn.feel, OutpostWatchtowerChestLoot.rollGoatHorn(3));

    try std.testing.expectEqualStrings("Ponder", RegularGoatHorn.ponder.name());
    try std.testing.expectEqualStrings("Sing", RegularGoatHorn.sing.name());
    try std.testing.expectEqualStrings("Seek", RegularGoatHorn.seek.name());
    try std.testing.expectEqualStrings("Feel", RegularGoatHorn.feel.name());

    // Chest loot stack for goat horn creates valid regular horn stack
    const horn_stack = OutpostWatchtowerChestLoot.createLootStack(.goat_horn, 0, 1);
    try std.testing.expectEqual(OutpostLootItem.goat_horn, horn_stack.item);
    try std.testing.expectEqual(@as(u8, 1), horn_stack.count);
    try std.testing.expectEqual(RegularGoatHorn.sing, horn_stack.horn_variant.?);
}
