const std = @import("std");

/// Physical orientation of a generated shipwreck in the ocean or on the shore.
pub const ShipwreckOrientation = enum {
    upright,
    tilted_side,
    upside_down,
    beached,

    pub const intact_three_chests = ShipwreckHullIntegrity.intact_three_chests;
    pub const missing_bow = ShipwreckHullIntegrity.missing_bow;
    pub const missing_stern = ShipwreckHullIntegrity.missing_stern;
    pub const HullIntegrity = ShipwreckHullIntegrity;

    pub fn isSubmerged(self: ShipwreckOrientation) bool {
        return self != .beached;
    }

    pub fn isBeached(self: ShipwreckOrientation) bool {
        return self == .beached;
    }
};

/// Hull integrity state determining how many and which loot chests generate:
/// - intact_three_chests: bow, stern, and hold intact -> 3 chests (supply, map, treasure)
/// - missing_bow: bow is broken -> missing supply chest -> 2 chests (map, treasure)
/// - missing_stern: stern and hold broken -> missing map & treasure chests -> 1 chest (supply)
pub const ShipwreckHullIntegrity = enum {
    intact_three_chests,
    missing_bow,
    missing_stern,

    pub fn chestCount(self: ShipwreckHullIntegrity) u3 {
        return switch (self) {
            .intact_three_chests => 3,
            .missing_bow => 2,
            .missing_stern => 1,
        };
    }

    pub fn hasSupplyChest(self: ShipwreckHullIntegrity) bool {
        return switch (self) {
            .intact_three_chests, .missing_stern => true,
            .missing_bow => false,
        };
    }

    pub fn hasMapChest(self: ShipwreckHullIntegrity) bool {
        return switch (self) {
            .intact_three_chests, .missing_bow => true,
            .missing_stern => false,
        };
    }

    pub fn hasTreasureChest(self: ShipwreckHullIntegrity) bool {
        return switch (self) {
            .intact_three_chests, .missing_bow => true,
            .missing_stern => false,
        };
    }

    pub fn hasChestKind(self: ShipwreckHullIntegrity, kind: ShipwreckChestKind) bool {
        return switch (kind) {
            .supply_chest => self.hasSupplyChest(),
            .map_chest => self.hasMapChest(),
            .treasure_chest => self.hasTreasureChest(),
        };
    }
};

pub const HullIntegrity = ShipwreckHullIntegrity;

/// Wood types for shipwreck structure generation.
pub const ShipwreckWoodType = enum {
    oak,
    spruce,
    birch,
    jungle,
    acacia,
    dark_oak,
    mangrove,
    cherry,
    bamboo,
    crimson,
    warped,
};

/// Complete structure specification for a generated shipwreck.
pub const ShipwreckStructure = struct {
    orientation: ShipwreckOrientation = .upright,
    hull_integrity: ShipwreckHullIntegrity = .intact_three_chests,
    wood_type: ShipwreckWoodType = .oak,

    pub fn chestCount(self: ShipwreckStructure) u3 {
        return self.hull_integrity.chestCount();
    }

    pub fn hasChest(self: ShipwreckStructure, kind: ShipwreckChestKind) bool {
        return self.hull_integrity.hasChestKind(kind);
    }
};

pub const Shipwreck = ShipwreckStructure;

/// Three distinct loot chest tiers found in shipwrecks.
pub const ShipwreckChestKind = enum {
    supply_chest,
    map_chest,
    treasure_chest,

    pub fn displayName(self: ShipwreckChestKind) []const u8 {
        return switch (self) {
            .supply_chest => "Supply Chest",
            .map_chest => "Map Chest",
            .treasure_chest => "Treasure Chest",
        };
    }
};

/// Supply chest loot tier (located in shipwreck bow).
/// Contains foodstuffs, plants, and basic survival items:
/// suspicious stew, paper, potatoes, leather, bamboo, etc.
pub const SupplyChestLoot = struct {
    suspicious_stew: u8 = 0,
    paper: u8 = 0,
    potatoes: u8 = 0,
    leather: u8 = 0,
    bamboo: u8 = 0,
    wheat: u8 = 0,
    carrots: u8 = 0,
    poisonous_potatoes: u8 = 0,
    coal: u8 = 0,
    rotten_flesh: u8 = 0,

    pub fn potato(self: SupplyChestLoot) u8 {
        return self.potatoes;
    }

    pub fn totalItems(self: SupplyChestLoot) usize {
        return @as(usize, self.suspicious_stew) + self.paper + self.potatoes +
            self.leather + self.bamboo + self.wheat + self.carrots +
            self.poisonous_potatoes + self.coal + self.rotten_flesh;
    }
};

/// Map chest loot tier (located in shipwreck stern / captain's cabin).
/// Guaranteed to contain 1 Buried Treasure Map, plus navigational gear:
/// compass, clock, coast armor trim smithing template, paper, feathers, books.
pub const MapChestLoot = struct {
    buried_treasure_map: u8 = 1, // Guaranteed 1 Buried Treasure Map!
    compass: u8 = 0,
    clock: u8 = 0,
    coast_armor_trim: u8 = 0,
    paper: u8 = 0,
    feathers: u8 = 0,
    books: u8 = 0,

    pub fn hasBuriedTreasureMap(self: MapChestLoot) bool {
        return self.buried_treasure_map >= 1;
    }

    pub fn hasCompass(self: MapChestLoot) bool {
        return self.compass >= 1;
    }

    pub fn hasClock(self: MapChestLoot) bool {
        return self.clock >= 1;
    }

    pub fn hasCoastArmorTrim(self: MapChestLoot) bool {
        return self.coast_armor_trim >= 1;
    }

    pub fn totalItems(self: MapChestLoot) usize {
        return @as(usize, self.buried_treasure_map) + self.compass + self.clock +
            self.coast_armor_trim + self.paper + self.feathers + self.books;
    }
};

/// Treasure chest loot tier (located in shipwreck hold / lower deck).
/// Contains valuable currency and precious minerals:
/// iron ingots/nuggets, gold ingots/nuggets, emerald, diamond, lapis lazuli.
pub const TreasureChestLoot = struct {
    iron_ingots: u8 = 0,
    iron_nuggets: u8 = 0,
    gold_ingots: u8 = 0,
    gold_nuggets: u8 = 0,
    emerald: u8 = 0,
    diamond: u8 = 0,
    lapis: u8 = 0,

    pub fn iron(self: TreasureChestLoot) u8 {
        return self.iron_ingots;
    }

    pub fn gold(self: TreasureChestLoot) u8 {
        return self.gold_ingots;
    }

    pub fn emeralds(self: TreasureChestLoot) u8 {
        return self.emerald;
    }

    pub fn diamonds(self: TreasureChestLoot) u8 {
        return self.diamond;
    }

    pub fn lapisLazuli(self: TreasureChestLoot) u8 {
        return self.lapis;
    }

    pub fn totalItems(self: TreasureChestLoot) usize {
        return @as(usize, self.iron_ingots) + self.iron_nuggets +
            self.gold_ingots + self.gold_nuggets + self.emerald +
            self.diamond + self.lapis;
    }
};

/// Covering material concealing buried treasure chests.
pub const BuriedCoverMaterial = enum {
    sand,
    gravel,

    pub fn isDiggableWithShovel(self: BuriedCoverMaterial) bool {
        return switch (self) {
            .sand, .gravel => true,
        };
    }
};

/// Environment where buried treasure is located.
pub const BuriedTreasureEnvironment = enum {
    beach,
    ocean_floor,
};

pub const min_buried_depth: u8 = 1;
pub const max_buried_depth: u8 = 3;

/// Deterministic chunk-local coordinates for buried treasure chests.
/// In Minecraft, buried treasure chests always generate strictly at local X=9, Z=9,
/// buried under 1..3 blocks of sand or gravel.
pub const BuriedTreasureCoord = struct {
    local_x: u4 = 9,
    local_z: u4 = 9,
    depth: u8 = 1,
    cover_material: BuriedCoverMaterial = .sand,
    environment: BuriedTreasureEnvironment = .beach,

    pub const default_local_x: u4 = 9;
    pub const default_local_z: u4 = 9;

    pub fn init(depth: u8, cover_material: BuriedCoverMaterial) BuriedTreasureCoord {
        return .{
            .local_x = 9,
            .local_z = 9,
            .depth = std.math.clamp(depth, min_buried_depth, max_buried_depth),
            .cover_material = cover_material,
            .environment = if (cover_material == .sand) .beach else .ocean_floor,
        };
    }

    pub fn isValidDepth(self: BuriedTreasureCoord) bool {
        return self.depth >= min_buried_depth and self.depth <= max_buried_depth;
    }

    pub fn worldX(self: BuriedTreasureCoord, chunk_x: i32) i32 {
        return chunk_x * 16 + @as(i32, self.local_x);
    }

    pub fn worldZ(self: BuriedTreasureCoord, chunk_z: i32) i32 {
        return chunk_z * 16 + @as(i32, self.local_z);
    }

    pub fn chestY(self: BuriedTreasureCoord, surface_y: i32) i32 {
        return surface_y - @as(i32, self.depth);
    }
};

/// Buried treasure chest loot contents.
/// Guaranteed 1 Heart of the Sea, plus valuable oceanic/pirate loot:
/// iron ingots, gold ingots, prismarine crystals, cooked cod/salmon, TNT,
/// potion of water breathing, diamonds, and emeralds.
pub const BuriedTreasureLoot = struct {
    heart_of_the_sea: u8 = 1, // Guaranteed 1 Heart of the Sea!
    iron_ingots: u8 = 0,
    gold_ingots: u8 = 0,
    prismarine_crystals: u8 = 0,
    cooked_cod: u8 = 0,
    cooked_salmon: u8 = 0,
    tnt: u8 = 0,
    potion_of_water_breathing: u8 = 0,
    diamonds: u8 = 0,
    emeralds: u8 = 0,

    pub fn hasHeartOfTheSea(self: BuriedTreasureLoot) bool {
        return self.heart_of_the_sea >= 1;
    }

    pub fn cookedFishCount(self: BuriedTreasureLoot) u8 {
        return self.cooked_cod + self.cooked_salmon;
    }

    pub fn totalItems(self: BuriedTreasureLoot) usize {
        return @as(usize, self.heart_of_the_sea) + self.iron_ingots +
            self.gold_ingots + self.prismarine_crystals + self.cooked_cod +
            self.cooked_salmon + self.tnt + self.potion_of_water_breathing +
            self.diamonds + self.emeralds;
    }
};

/// Checks whether a player's chunk coordinates match the target chunk AND
/// their chunk-local coordinates align with the deterministic (9, 9) buried treasure chest.
pub fn isPlayerAtBuriedTreasureSpot(
    player_chunk_x: i32,
    player_chunk_z: i32,
    player_local_x: u4,
    player_local_z: u4,
    target_chunk_x: i32,
    target_chunk_z: i32,
) bool {
    return player_chunk_x == target_chunk_x and
        player_chunk_z == target_chunk_z and
        player_local_x == 9 and
        player_local_z == 9;
}

/// Converts a world coordinate into a chunk coordinate.
pub fn worldToChunk(coord: i32) i32 {
    return @divFloor(coord, 16);
}

/// Converts a world coordinate into a chunk-local coordinate (0..15).
pub fn worldToLocal(coord: i32) u4 {
    return @as(u4, @intCast(@mod(coord, 16)));
}

/// Converts a chunk and local coordinate into an absolute world coordinate.
pub fn chunkLocalToWorld(chunk: i32, local: u4) i32 {
    return chunk * 16 + @as(i32, local);
}

/// Checks whether a player at absolute world coordinates is standing on the buried treasure spot (local 9, 9).
pub fn isPlayerWorldAtBuriedTreasureSpot(
    player_world_x: i32,
    player_world_z: i32,
    target_chunk_x: i32,
    target_chunk_z: i32,
) bool {
    const chunk_x = worldToChunk(player_world_x);
    const chunk_z = worldToChunk(player_world_z);
    const local_x = worldToLocal(player_world_x);
    const local_z = worldToLocal(player_world_z);
    return isPlayerAtBuriedTreasureSpot(chunk_x, chunk_z, local_x, local_z, target_chunk_x, target_chunk_z);
}

/// Buried Treasure Map representing the explorer map item found in shipwreck map chests.
pub const BuriedTreasureMap = struct {
    target_chunk_x: i32,
    target_chunk_z: i32,
    target_local_x: u4 = 9,
    target_local_z: u4 = 9,

    pub fn targetWorldX(self: BuriedTreasureMap) i32 {
        return self.target_chunk_x * 16 + @as(i32, self.target_local_x);
    }

    pub fn targetWorldZ(self: BuriedTreasureMap) i32 {
        return self.target_chunk_z * 16 + @as(i32, self.target_local_z);
    }

    pub fn isPlayerOverRedX(
        self: BuriedTreasureMap,
        player_chunk_x: i32,
        player_chunk_z: i32,
        player_local_x: u4,
        player_local_z: u4,
    ) bool {
        return isPlayerAtBuriedTreasureSpot(
            player_chunk_x,
            player_chunk_z,
            player_local_x,
            player_local_z,
            self.target_chunk_x,
            self.target_chunk_z,
        );
    }
};

/// Deterministic generator for supply chest loot.
pub fn generateSupplyChestLoot(roll: u32) SupplyChestLoot {
    return .{
        .suspicious_stew = if (roll % 3 == 0) 1 else 0,
        .paper = @intCast(1 + (roll % 10)),
        .potatoes = @intCast(2 + ((roll / 3) % 6)),
        .leather = @intCast(1 + ((roll / 5) % 5)),
        .bamboo = @intCast(1 + ((roll / 7) % 6)),
        .wheat = @intCast((roll / 11) % 8),
        .carrots = @intCast((roll / 13) % 5),
        .poisonous_potatoes = if (roll % 17 == 0) 1 else 0,
        .coal = @intCast(1 + (roll % 8)),
        .rotten_flesh = @intCast((roll / 23) % 6),
    };
}

/// Deterministic generator for map chest loot (guaranteed 1 Buried Treasure Map).
pub fn generateMapChestLoot(roll: u32) MapChestLoot {
    return .{
        .buried_treasure_map = 1, // Guaranteed 1 Buried Treasure Map!
        .compass = if (roll % 2 == 0) 1 else 0,
        .clock = if (roll % 3 == 0) 1 else 0,
        .coast_armor_trim = if (roll % 6 == 0) 1 else 0,
        .paper = @intCast(2 + (roll % 8)),
        .feathers = @intCast(1 + ((roll / 4) % 6)),
        .books = @intCast((roll / 8) % 4),
    };
}

/// Deterministic generator for treasure chest loot.
pub fn generateTreasureChestLoot(roll: u32) TreasureChestLoot {
    return .{
        .iron_ingots = @intCast(1 + (roll % 8)),
        .iron_nuggets = @intCast((roll / 3) % 10),
        .gold_ingots = @intCast(1 + ((roll / 5) % 6)),
        .gold_nuggets = @intCast((roll / 7) % 10),
        .emerald = @intCast((roll / 11) % 5),
        .diamond = if (roll % 7 == 0) 1 else 0,
        .lapis = @intCast(1 + ((roll / 13) % 10)),
    };
}

/// Deterministic generator for buried treasure loot (guaranteed 1 Heart of the Sea).
pub fn generateBuriedTreasureLoot(roll: u32) BuriedTreasureLoot {
    return .{
        .heart_of_the_sea = 1, // Guaranteed 1 Heart of the Sea!
        .iron_ingots = @intCast(1 + (roll % 8)),
        .gold_ingots = @intCast(1 + ((roll / 3) % 8)),
        .prismarine_crystals = @intCast(1 + ((roll / 5) % 5)),
        .cooked_cod = @intCast((roll / 7) % 4),
        .cooked_salmon = @intCast((roll / 11) % 4),
        .tnt = if (roll % 4 == 0) 1 else 0,
        .potion_of_water_breathing = if (roll % 3 == 0) 1 else 0,
        .diamonds = if (roll % 5 == 0) 1 else 0,
        .emeralds = @intCast((roll / 13) % 4),
    };
}

/// Deterministic generator for shipwreck structure metadata.
pub fn generateShipwreckStructure(orientation_roll: u8, integrity_roll: u8, wood_roll: u8) ShipwreckStructure {
    const orientation: ShipwreckOrientation = switch (orientation_roll % 4) {
        0 => .upright,
        1 => .tilted_side,
        2 => .upside_down,
        else => .beached,
    };
    const integrity: ShipwreckHullIntegrity = switch (integrity_roll % 3) {
        0 => .intact_three_chests,
        1 => .missing_bow,
        else => .missing_stern,
    };
    const wood: ShipwreckWoodType = @enumFromInt(wood_roll % 11);
    return .{
        .orientation = orientation,
        .hull_integrity = integrity,
        .wood_type = wood,
    };
}

/// Conduit crafting recipe helper: 1 Heart of the Sea + 8 Nautilus Shells -> Conduit.
pub fn canCraftConduit(heart_of_the_sea: u8, nautilus_shells: u8) bool {
    return heart_of_the_sea >= 1 and nautilus_shells >= 8;
}

/// Consumes 1 Heart of the Sea and 8 Nautilus Shells to craft a conduit block.
pub fn craftConduit(heart_of_the_sea: *u8, nautilus_shells: *u8) bool {
    if (!canCraftConduit(heart_of_the_sea.*, nautilus_shells.*)) return false;
    heart_of_the_sea.* -= 1;
    nautilus_shells.* -= 8;
    return true;
}

// ============================================================================
// Unit Tests (At least 12 comprehensive test blocks)
// ============================================================================

test "1. ShipwreckOrientation variants and submerged or beached state" {
    const upright = ShipwreckOrientation.upright;
    const tilted = ShipwreckOrientation.tilted_side;
    const upside_down = ShipwreckOrientation.upside_down;
    const beached = ShipwreckOrientation.beached;

    try std.testing.expect(upright.isSubmerged());
    try std.testing.expect(!upright.isBeached());
    try std.testing.expect(tilted.isSubmerged());
    try std.testing.expect(!tilted.isBeached());
    try std.testing.expect(upside_down.isSubmerged());
    try std.testing.expect(!upside_down.isBeached());
    try std.testing.expect(!beached.isSubmerged());
    try std.testing.expect(beached.isBeached());
}

test "2. ShipwreckHullIntegrity chest counts reflect structural integrity" {
    try std.testing.expectEqual(@as(u3, 3), ShipwreckHullIntegrity.intact_three_chests.chestCount());
    try std.testing.expectEqual(@as(u3, 2), ShipwreckHullIntegrity.missing_bow.chestCount());
    try std.testing.expectEqual(@as(u3, 1), ShipwreckHullIntegrity.missing_stern.chestCount());

    // Aliases through ShipwreckOrientation and HullIntegrity
    try std.testing.expectEqual(@as(u3, 3), ShipwreckOrientation.intact_three_chests.chestCount());
    try std.testing.expectEqual(@as(u3, 2), HullIntegrity.missing_bow.chestCount());
    try std.testing.expectEqual(@as(u3, 1), HullIntegrity.missing_stern.chestCount());
}

test "3. Shipwreck chest presence: intact has all three, missing bow loses supply, missing stern has only supply" {
    const intact = ShipwreckHullIntegrity.intact_three_chests;
    try std.testing.expect(intact.hasSupplyChest());
    try std.testing.expect(intact.hasMapChest());
    try std.testing.expect(intact.hasTreasureChest());
    try std.testing.expect(intact.hasChestKind(.supply_chest));
    try std.testing.expect(intact.hasChestKind(.map_chest));
    try std.testing.expect(intact.hasChestKind(.treasure_chest));

    const no_bow = ShipwreckHullIntegrity.missing_bow;
    try std.testing.expect(!no_bow.hasSupplyChest());
    try std.testing.expect(no_bow.hasMapChest());
    try std.testing.expect(no_bow.hasTreasureChest());
    try std.testing.expect(!no_bow.hasChestKind(.supply_chest));

    const no_stern = ShipwreckHullIntegrity.missing_stern;
    try std.testing.expect(no_stern.hasSupplyChest());
    try std.testing.expect(!no_stern.hasMapChest());
    try std.testing.expect(!no_stern.hasTreasureChest());
    try std.testing.expect(no_stern.hasChestKind(.supply_chest));
    try std.testing.expect(!no_stern.hasChestKind(.map_chest));
    try std.testing.expect(!no_stern.hasChestKind(.treasure_chest));
}

test "4. ShipwreckChestKind enum variants and descriptive display names" {
    try std.testing.expectEqualStrings("Supply Chest", ShipwreckChestKind.supply_chest.displayName());
    try std.testing.expectEqualStrings("Map Chest", ShipwreckChestKind.map_chest.displayName());
    try std.testing.expectEqualStrings("Treasure Chest", ShipwreckChestKind.treasure_chest.displayName());
}

test "5. SupplyChestLoot contains suspicious stew, paper, potatoes, leather, and bamboo" {
    const loot = SupplyChestLoot{
        .suspicious_stew = 1,
        .paper = 5,
        .potatoes = 6,
        .leather = 3,
        .bamboo = 4,
    };
    try std.testing.expectEqual(@as(u8, 1), loot.suspicious_stew);
    try std.testing.expectEqual(@as(u8, 5), loot.paper);
    try std.testing.expectEqual(@as(u8, 6), loot.potatoes);
    try std.testing.expectEqual(@as(u8, 6), loot.potato());
    try std.testing.expectEqual(@as(u8, 3), loot.leather);
    try std.testing.expectEqual(@as(u8, 4), loot.bamboo);
    try std.testing.expectEqual(@as(usize, 19), loot.totalItems());

    // Deterministic generated supply loot verification
    const generated = generateSupplyChestLoot(15);
    try std.testing.expect(generated.paper >= 1);
    try std.testing.expect(generated.potatoes >= 2);
    try std.testing.expect(generated.leather >= 1);
    try std.testing.expect(generated.bamboo >= 1);
}

test "6. MapChestLoot contains guaranteed 1 Buried Treasure Map, compass, clock, coast armor trim" {
    const default_map_loot = MapChestLoot{};
    try std.testing.expectEqual(@as(u8, 1), default_map_loot.buried_treasure_map);
    try std.testing.expect(default_map_loot.hasBuriedTreasureMap());

    const equipped_map_loot = MapChestLoot{
        .buried_treasure_map = 1,
        .compass = 1,
        .clock = 1,
        .coast_armor_trim = 1,
        .paper = 3,
    };
    try std.testing.expect(equipped_map_loot.hasCompass());
    try std.testing.expect(equipped_map_loot.hasClock());
    try std.testing.expect(equipped_map_loot.hasCoastArmorTrim());
    try std.testing.expectEqual(@as(u8, 1), equipped_map_loot.coast_armor_trim);
    try std.testing.expectEqual(@as(usize, 7), equipped_map_loot.totalItems());

    // Generator must guarantee Buried Treasure Map across various rolls
    var roll: u32 = 0;
    while (roll < 10) : (roll += 1) {
        const generated = generateMapChestLoot(roll);
        try std.testing.expectEqual(@as(u8, 1), generated.buried_treasure_map);
        try std.testing.expect(generated.hasBuriedTreasureMap());
    }
}

test "7. TreasureChestLoot contains iron, gold, emerald, diamond, and lapis" {
    const loot = TreasureChestLoot{
        .iron_ingots = 4,
        .iron_nuggets = 8,
        .gold_ingots = 2,
        .gold_nuggets = 5,
        .emerald = 3,
        .diamond = 1,
        .lapis = 10,
    };
    try std.testing.expectEqual(@as(u8, 4), loot.iron());
    try std.testing.expectEqual(@as(u8, 2), loot.gold());
    try std.testing.expectEqual(@as(u8, 3), loot.emeralds());
    try std.testing.expectEqual(@as(u8, 1), loot.diamonds());
    try std.testing.expectEqual(@as(u8, 10), loot.lapisLazuli());
    try std.testing.expectEqual(@as(usize, 33), loot.totalItems());

    const generated = generateTreasureChestLoot(42);
    try std.testing.expect(generated.iron_ingots >= 1);
    try std.testing.expect(generated.gold_ingots >= 1);
    try std.testing.expect(generated.lapis >= 1);
}

test "8. BuriedTreasureCoord default local coordinates are strictly 9, 9" {
    const coord = BuriedTreasureCoord{};
    try std.testing.expectEqual(@as(u4, 9), coord.local_x);
    try std.testing.expectEqual(@as(u4, 9), coord.local_z);
    try std.testing.expectEqual(@as(u4, 9), BuriedTreasureCoord.default_local_x);
    try std.testing.expectEqual(@as(u4, 9), BuriedTreasureCoord.default_local_z);
}

test "9. BuriedTreasureCoord burial depth is within 1..3 blocks under sand or gravel" {
    const sand_treasure = BuriedTreasureCoord.init(2, .sand);
    try std.testing.expectEqual(@as(u8, 2), sand_treasure.depth);
    try std.testing.expect(sand_treasure.isValidDepth());
    try std.testing.expectEqual(BuriedCoverMaterial.sand, sand_treasure.cover_material);
    try std.testing.expect(sand_treasure.cover_material.isDiggableWithShovel());
    try std.testing.expectEqual(BuriedTreasureEnvironment.beach, sand_treasure.environment);

    const gravel_treasure = BuriedTreasureCoord.init(3, .gravel);
    try std.testing.expectEqual(@as(u8, 3), gravel_treasure.depth);
    try std.testing.expect(gravel_treasure.isValidDepth());
    try std.testing.expectEqual(BuriedCoverMaterial.gravel, gravel_treasure.cover_material);
    try std.testing.expect(gravel_treasure.cover_material.isDiggableWithShovel());
    try std.testing.expectEqual(BuriedTreasureEnvironment.ocean_floor, gravel_treasure.environment);

    // Clamping to 1..3 bounds
    const underflow = BuriedTreasureCoord.init(0, .sand);
    try std.testing.expectEqual(@as(u8, 1), underflow.depth);
    const overflow = BuriedTreasureCoord.init(10, .sand);
    try std.testing.expectEqual(@as(u8, 3), overflow.depth);
}

test "10. BuriedTreasureCoord world coordinate and chest Y depth calculation" {
    const coord = BuriedTreasureCoord.init(2, .sand);

    // Chunk (3, 5): world x = 3*16 + 9 = 57, world z = 5*16 + 9 = 89
    try std.testing.expectEqual(@as(i32, 57), coord.worldX(3));
    try std.testing.expectEqual(@as(i32, 89), coord.worldZ(5));

    // Negative chunk coordinates: chunk (-2, -1):
    // world x = -2*16 + 9 = -23, world z = -1*16 + 9 = -7
    try std.testing.expectEqual(@as(i32, -23), coord.worldX(-2));
    try std.testing.expectEqual(@as(i32, -7), coord.worldZ(-1));

    // Buried 2 blocks below surface y = 63 (sea level beach)
    try std.testing.expectEqual(@as(i32, 61), coord.chestY(63));
}

test "11. BuriedTreasureLoot guaranteed heart_of_the_sea is always 1" {
    const default_loot = BuriedTreasureLoot{};
    try std.testing.expectEqual(@as(u8, 1), default_loot.heart_of_the_sea);
    try std.testing.expect(default_loot.hasHeartOfTheSea());

    // Generator across multiple rolls always yields 1 Heart of the Sea
    var roll: u32 = 0;
    while (roll < 20) : (roll += 1) {
        const loot = generateBuriedTreasureLoot(roll);
        try std.testing.expectEqual(@as(u8, 1), loot.heart_of_the_sea);
        try std.testing.expect(loot.hasHeartOfTheSea());
    }
}

test "12. BuriedTreasureLoot contains iron ingots, gold ingots, prismarine crystals, cooked cod/salmon, TNT, or potion of water breathing" {
    const custom_loot = BuriedTreasureLoot{
        .heart_of_the_sea = 1,
        .iron_ingots = 8,
        .gold_ingots = 4,
        .prismarine_crystals = 5,
        .cooked_cod = 2,
        .cooked_salmon = 3,
        .tnt = 1,
        .potion_of_water_breathing = 1,
    };

    try std.testing.expectEqual(@as(u8, 1), custom_loot.heart_of_the_sea);
    try std.testing.expectEqual(@as(u8, 8), custom_loot.iron_ingots);
    try std.testing.expectEqual(@as(u8, 4), custom_loot.gold_ingots);
    try std.testing.expectEqual(@as(u8, 5), custom_loot.prismarine_crystals);
    try std.testing.expectEqual(@as(u8, 2), custom_loot.cooked_cod);
    try std.testing.expectEqual(@as(u8, 3), custom_loot.cooked_salmon);
    try std.testing.expectEqual(@as(u8, 5), custom_loot.cookedFishCount());
    try std.testing.expectEqual(@as(u8, 1), custom_loot.tnt);
    try std.testing.expectEqual(@as(u8, 1), custom_loot.potion_of_water_breathing);
    try std.testing.expectEqual(@as(usize, 25), custom_loot.totalItems());
}

test "13. isPlayerAtBuriedTreasureSpot matches correct chunk and local 9, 9" {
    // Player at chunk (10, -5) and local (9, 9) searching for target (10, -5)
    try std.testing.expect(isPlayerAtBuriedTreasureSpot(10, -5, 9, 9, 10, -5));
    // Chunk origin (0, 0)
    try std.testing.expect(isPlayerAtBuriedTreasureSpot(0, 0, 9, 9, 0, 0));
}

test "14. isPlayerAtBuriedTreasureSpot rejects player when local coordinates are not 9, 9" {
    // Correct chunk (4, 4), but off by one in local X or Z
    try std.testing.expect(!isPlayerAtBuriedTreasureSpot(4, 4, 8, 9, 4, 4));
    try std.testing.expect(!isPlayerAtBuriedTreasureSpot(4, 4, 10, 9, 4, 4));
    try std.testing.expect(!isPlayerAtBuriedTreasureSpot(4, 4, 9, 8, 4, 4));
    try std.testing.expect(!isPlayerAtBuriedTreasureSpot(4, 4, 9, 10, 4, 4));
    try std.testing.expect(!isPlayerAtBuriedTreasureSpot(4, 4, 0, 0, 4, 4));
    try std.testing.expect(!isPlayerAtBuriedTreasureSpot(4, 4, 15, 15, 4, 4));
}

test "15. isPlayerAtBuriedTreasureSpot rejects player when chunk does not match target chunk" {
    // Player at local (9, 9) but in adjacent chunk
    try std.testing.expect(!isPlayerAtBuriedTreasureSpot(11, -5, 9, 9, 10, -5));
    try std.testing.expect(!isPlayerAtBuriedTreasureSpot(10, -4, 9, 9, 10, -5));
    try std.testing.expect(!isPlayerAtBuriedTreasureSpot(-10, 5, 9, 9, 10, -5));
}

test "16. isPlayerWorldAtBuriedTreasureSpot handles positive and negative world coordinates" {
    // Target chunk is (2, -3) -> chest is at world X = 2*16 + 9 = 41, Z = -3*16 + 9 = -39
    const target_chunk_x: i32 = 2;
    const target_chunk_z: i32 = -3;

    try std.testing.expect(isPlayerWorldAtBuriedTreasureSpot(41, -39, target_chunk_x, target_chunk_z));

    // 1 block away in world coordinates
    try std.testing.expect(!isPlayerWorldAtBuriedTreasureSpot(40, -39, target_chunk_x, target_chunk_z));
    try std.testing.expect(!isPlayerWorldAtBuriedTreasureSpot(42, -39, target_chunk_x, target_chunk_z));
    try std.testing.expect(!isPlayerWorldAtBuriedTreasureSpot(41, -40, target_chunk_x, target_chunk_z));
    try std.testing.expect(!isPlayerWorldAtBuriedTreasureSpot(41, -38, target_chunk_x, target_chunk_z));

    // Coordinate conversion utilities
    try std.testing.expectEqual(@as(i32, 2), worldToChunk(41));
    try std.testing.expectEqual(@as(i32, -3), worldToChunk(-39));
    try std.testing.expectEqual(@as(u4, 9), worldToLocal(41));
    try std.testing.expectEqual(@as(u4, 9), worldToLocal(-39));
    try std.testing.expectEqual(@as(i32, 41), chunkLocalToWorld(2, 9));
    try std.testing.expectEqual(@as(i32, -39), chunkLocalToWorld(-3, 9));
}

test "17. BuriedTreasureMap links red X target coordinates to player spot detection" {
    const map = BuriedTreasureMap{
        .target_chunk_x = 7,
        .target_chunk_z = 12,
    };

    try std.testing.expectEqual(@as(i32, 7 * 16 + 9), map.targetWorldX());
    try std.testing.expectEqual(@as(i32, 12 * 16 + 9), map.targetWorldZ());

    try std.testing.expect(map.isPlayerOverRedX(7, 12, 9, 9));
    try std.testing.expect(!map.isPlayerOverRedX(7, 12, 8, 9));
    try std.testing.expect(!map.isPlayerOverRedX(6, 12, 9, 9));
}

test "18. Conduit crafting recipe requires 1 Heart of the Sea and 8 Nautilus Shells" {
    try std.testing.expect(!canCraftConduit(0, 8));
    try std.testing.expect(!canCraftConduit(1, 7));
    try std.testing.expect(canCraftConduit(1, 8));
    try std.testing.expect(canCraftConduit(2, 16));

    var hearts: u8 = 1;
    var shells: u8 = 8;
    try std.testing.expect(craftConduit(&hearts, &shells));
    try std.testing.expectEqual(@as(u8, 0), hearts);
    try std.testing.expectEqual(@as(u8, 0), shells);
    try std.testing.expect(!craftConduit(&hearts, &shells));
}

test "19. ShipwreckStructure deterministic generation with orientation, integrity, and wood type" {
    const ship = generateShipwreckStructure(3, 0, 5);
    try std.testing.expectEqual(ShipwreckOrientation.beached, ship.orientation);
    try std.testing.expect(ship.orientation.isBeached());
    try std.testing.expectEqual(ShipwreckHullIntegrity.intact_three_chests, ship.hull_integrity);
    try std.testing.expectEqual(@as(u3, 3), ship.chestCount());
    try std.testing.expectEqual(ShipwreckWoodType.dark_oak, ship.wood_type);

    try std.testing.expect(ship.hasChest(.supply_chest));
    try std.testing.expect(ship.hasChest(.map_chest));
    try std.testing.expect(ship.hasChest(.treasure_chest));
}
