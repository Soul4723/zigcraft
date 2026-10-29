const std = @import("std");

pub const Position = struct { x: i32, y: i32, z: i32 };
pub const Bounds = struct {
    min: Position,
    max: Position,

    pub fn contains(self: Bounds, p: Position) bool {
        return p.x >= self.min.x and p.x <= self.max.x and
            p.y >= self.min.y and p.y <= self.max.y and
            p.z >= self.min.z and p.z <= self.max.z;
    }

    pub fn overlaps(self: Bounds, other: Bounds) bool {
        return self.min.x <= other.max.x and self.max.x >= other.min.x and
            self.min.y <= other.max.y and self.max.y >= other.min.y and
            self.min.z <= other.max.z and self.max.z >= other.min.z;
    }
};

pub const Block = enum { air, purpur_block, purpur_pillar, purpur_slab, end_stone_bricks, iron_bars, end_rod, chest };
pub const PieceKind = enum { base_tower, bridge_corridor, branching_tower, upper_connector, upper_tower, loot_bridge, loot_chamber };
pub const PIECE_COUNT = 7;
pub const MIN_SENTRIES = 4;
pub const MAX_SENTRIES = 8;
pub const VAULT_CHEST_COUNT = 2;

pub const Piece = struct { kind: PieceKind, bounds: Bounds };
pub const Chest = struct { position: Position };

pub const EndCityLayout = struct {
    pieces: [PIECE_COUNT]Piece,
    chests: [VAULT_CHEST_COUNT]Chest,

    pub fn boundsFor(self: EndCityLayout, kind: PieceKind) Bounds {
        for (self.pieces) |piece| if (piece.kind == kind) return piece.bounds;
        unreachable;
    }

    /// Returns the generated architectural block at a world position. Empty
    /// interior space and positions outside the city return `.air`.
    pub fn blockAt(self: EndCityLayout, p: Position) Block {
        for (self.pieces) |piece| {
            if (!piece.bounds.contains(p)) continue;
            const b = piece.bounds;
            const on_x_edge = p.x == b.min.x or p.x == b.max.x;
            const on_y_edge = p.y == b.min.y or p.y == b.max.y;
            const on_z_edge = p.z == b.min.z or p.z == b.max.z;
            switch (piece.kind) {
                .base_tower, .branching_tower, .upper_tower => {
                    if (on_y_edge) return .end_stone_bricks;
                    if (piece.kind == .base_tower and p.x == b.min.x and p.z == b.min.z + 3 and p.y >= b.min.y + 1 and p.y <= b.min.y + 3) return .air;
                    if (piece.kind == .base_tower and p.x == b.min.x and (p.z == b.min.z + 2 or p.z == b.min.z + 4) and p.y >= b.min.y + 1 and p.y <= b.min.y + 3) return .purpur_pillar;
                    if ((on_x_edge and on_z_edge) or (piece.kind == .base_tower and p.y == b.min.y + 1)) return .purpur_pillar;
                    if (on_x_edge or on_z_edge) return .purpur_block;
                },
                .bridge_corridor, .upper_connector, .loot_bridge => {
                    if (p.y == b.min.y) return .purpur_slab;
                    if (p.y == b.max.y or on_x_edge or on_z_edge) return .purpur_pillar;
                },
                .loot_chamber => {
                    if (isChestPosition(self, p)) return .chest;
                    if (p.y == b.min.y or p.y == b.max.y) return .purpur_slab;
                    if (on_x_edge and (p.z == b.min.z + 3 or p.z == b.max.z - 3)) return .purpur_pillar;
                    if (p.x == b.min.x and p.z == b.min.z + 4 and p.y >= b.min.y + 2 and p.y <= b.min.y + 3) return .air;
                    if (on_x_edge or on_z_edge) return .iron_bars;
                },
            }
            return .air;
        }
        // End Rod corner spires crown each tower and the vault.
        for (self.pieces) |piece| {
            if (piece.kind != .base_tower and piece.kind != .branching_tower and piece.kind != .upper_tower and piece.kind != .loot_chamber) continue;
            const b = piece.bounds;
            if (p.y == b.max.y + 1 and (p.x == b.min.x or p.x == b.max.x) and (p.z == b.min.z or p.z == b.max.z)) return .end_rod;
        }
        return .air;
    }
};

fn isChestPosition(layout: EndCityLayout, p: Position) bool {
    for (layout.chests) |chest| if (samePosition(chest.position, p)) return true;
    return false;
}

pub fn generateEndCity(origin: Position) EndCityLayout {
    const base = box(origin, 0, 0, 0, 6, 14, 6);
    const bridge = box(origin, 7, 12, 2, 11, 14, 4);
    const lower_tower = box(origin, 12, 15, 0, 18, 34, 6);
    const connector = box(origin, 14, 35, 7, 16, 37, 11);
    const upper_tower = box(origin, 12, 38, 12, 18, 55, 18);
    const vault_bridge = box(origin, 19, 42, 14, 23, 44, 16);
    const vault = box(origin, 24, 41, 11, 32, 51, 19);
    return .{
        .pieces = .{
            .{ .kind = .base_tower, .bounds = base },
            .{ .kind = .bridge_corridor, .bounds = bridge },
            .{ .kind = .branching_tower, .bounds = lower_tower },
            .{ .kind = .upper_connector, .bounds = connector },
            .{ .kind = .upper_tower, .bounds = upper_tower },
            .{ .kind = .loot_bridge, .bounds = vault_bridge },
            .{ .kind = .loot_chamber, .bounds = vault },
        },
        .chests = .{
            .{ .position = add(origin, .{ .x = 27, .y = 42, .z = 14 }) },
            .{ .position = add(origin, .{ .x = 29, .y = 42, .z = 16 }) },
        },
    };
}

fn box(origin: Position, min_x: i32, min_y: i32, min_z: i32, max_x: i32, max_y: i32, max_z: i32) Bounds {
    return .{
        .min = add(origin, .{ .x = min_x, .y = min_y, .z = min_z }),
        .max = add(origin, .{ .x = max_x, .y = max_y, .z = max_z }),
    };
}

fn add(a: Position, b: Position) Position {
    return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
}

fn samePosition(a: Position, b: Position) bool {
    return a.x == b.x and a.y == b.y and a.z == b.z;
}

pub const Face = enum { north, south, east, west, ceiling, floor };
pub const SentryPurpose = enum { entrance, exterior_wall, bridge_ceiling, vault_threshold };
pub const Sentry = struct { support: Position, face: Face, purpose: SentryPurpose };
pub const SentryLayout = struct { sentries: [MAX_SENTRIES]Sentry, count: usize };
pub const SentryError = error{ InvalidSentryCount, InvalidLayout };

/// Chooses 4..8 sentries from validated wall and ceiling anchors. Two anchors
/// always cover opposite sides of the loot-chamber threshold.
pub fn placeShulkerSentries(layout: EndCityLayout, count: usize) SentryError!SentryLayout {
    if (count < MIN_SENTRIES or count > MAX_SENTRIES) return error.InvalidSentryCount;
    const vault = layout.boundsFor(.loot_chamber);
    const candidates = [_]Sentry{
        .{ .support = .{ .x = layout.boundsFor(.base_tower).min.x, .y = layout.boundsFor(.base_tower).min.y + 2, .z = layout.boundsFor(.base_tower).min.z + 2 }, .face = .west, .purpose = .entrance },
        .{ .support = .{ .x = vault.min.x, .y = vault.min.y + 2, .z = vault.min.z + 3 }, .face = .west, .purpose = .vault_threshold },
        .{ .support = .{ .x = vault.min.x, .y = vault.min.y + 2, .z = vault.max.z - 3 }, .face = .west, .purpose = .vault_threshold },
        .{ .support = .{ .x = layout.boundsFor(.bridge_corridor).min.x + 2, .y = layout.boundsFor(.bridge_corridor).max.y, .z = layout.boundsFor(.bridge_corridor).min.z + 1 }, .face = .ceiling, .purpose = .bridge_ceiling },
        .{ .support = .{ .x = layout.boundsFor(.base_tower).max.x, .y = layout.boundsFor(.base_tower).min.y + 5, .z = layout.boundsFor(.base_tower).min.z + 2 }, .face = .east, .purpose = .exterior_wall },
        .{ .support = .{ .x = layout.boundsFor(.branching_tower).min.x, .y = layout.boundsFor(.branching_tower).min.y + 5, .z = layout.boundsFor(.branching_tower).min.z + 2 }, .face = .west, .purpose = .exterior_wall },
        .{ .support = .{ .x = vault.min.x + 3, .y = vault.max.y, .z = vault.min.z + 2 }, .face = .ceiling, .purpose = .exterior_wall },
        .{ .support = .{ .x = vault.max.x - 3, .y = vault.max.y, .z = vault.max.z - 2 }, .face = .ceiling, .purpose = .exterior_wall },
    };
    var result = SentryLayout{ .sentries = undefined, .count = count };
    for (candidates[0..count], 0..) |candidate, i| {
        const support_block = layout.blockAt(candidate.support);
        if (support_block != .purpur_block and support_block != .purpur_pillar and support_block != .purpur_slab and support_block != .end_stone_bricks) return error.InvalidLayout;
        result.sentries[i] = candidate;
    }
    return result;
}

pub const LootItem = enum { diamond_helmet, diamond_chestplate, diamond_leggings, diamond_boots, diamond_sword, diamond_pickaxe, iron_ingot, gold_ingot, emerald, saddle, iron_horse_armor, golden_horse_armor, diamond_horse_armor };
pub const Enchantment = enum { protection, unbreaking, sharpness, efficiency };
pub const EnchantmentRoll = struct { kind: Enchantment, level: u8 };
pub const LootEntry = struct { item: LootItem, count: u8, enchantment: ?EnchantmentRoll = null };
pub const CHEST_SLOT_COUNT = 8;
pub const CHEST_MIN_ITEMS = 3;
pub const CHEST_MAX_ITEMS = CHEST_SLOT_COUNT;
pub const LootChest = struct { entries: [CHEST_SLOT_COUNT]LootEntry, count: usize };
pub const VaultLoot = struct { chests: [VAULT_CHEST_COUNT]LootChest };

/// Deterministic chest loot: each vault chest gets 3..8 entries, equipment
/// enchantments stay within vanilla maxima, and stack counts remain bounded.
pub fn generateVaultLoot(seed: u64) VaultLoot {
    var rng = Generator{ .state = if (seed == 0) 0x9e3779b97f4a7c15 else seed };
    var result: VaultLoot = undefined;
    for (&result.chests) |*chest| {
        chest.count = CHEST_MIN_ITEMS + rng.bounded(CHEST_MAX_ITEMS - CHEST_MIN_ITEMS + 1);
        for (chest.entries[0..chest.count]) |*entry| entry.* = rollEntry(&rng);
    }
    return result;
}

fn rollEntry(rng: *Generator) LootEntry {
    const roll = rng.bounded(13);
    const item: LootItem = switch (roll) {
        0 => .diamond_helmet, 1 => .diamond_chestplate, 2 => .diamond_leggings, 3 => .diamond_boots,
        4 => .diamond_sword, 5 => .diamond_pickaxe, 6 => .iron_ingot, 7 => .gold_ingot,
        8 => .emerald, 9 => .saddle, 10 => .iron_horse_armor, 11 => .golden_horse_armor, else => .diamond_horse_armor,
    };
    const enchantment = switch (item) {
        .diamond_helmet, .diamond_chestplate, .diamond_leggings, .diamond_boots => blk: {
            if (rng.bounded(2) == 0) break :blk EnchantmentRoll{ .kind = .protection, .level = 4 };
            break :blk EnchantmentRoll{ .kind = .unbreaking, .level = 3 };
        },
        .diamond_sword => EnchantmentRoll{ .kind = .sharpness, .level = 5 },
        .diamond_pickaxe => EnchantmentRoll{ .kind = .efficiency, .level = 5 },
        else => null,
    };
    return .{ .item = item, .count = if (item == .iron_ingot or item == .gold_ingot or item == .emerald) @as(u8, @intCast(2 + rng.bounded(9))) else 1, .enchantment = enchantment };
}

const Generator = struct {
    state: u64,
    fn next(self: *Generator) u64 {
        self.state ^= self.state << 13;
        self.state ^= self.state >> 7;
        self.state ^= self.state << 17;
        return self.state;
    }
    fn bounded(self: *Generator, limit: usize) usize {
        return @intCast(self.next() % limit);
    }
};

test "city contains seven bounded architectural regions" {
    const city = generateEndCity(.{ .x = 0, .y = 64, .z = 0 });
    try std.testing.expectEqual(@as(usize, 7), city.pieces.len);
    for (city.pieces) |piece| try std.testing.expect(piece.bounds.min.x <= piece.bounds.max.x and piece.bounds.min.y <= piece.bounds.max.y and piece.bounds.min.z <= piece.bounds.max.z);
}
test "base tower is seven by seven at the entrance" { const b = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }).boundsFor(.base_tower); try std.testing.expectEqual(@as(i32, 7), b.max.x - b.min.x + 1); try std.testing.expectEqual(@as(i32, 7), b.max.z - b.min.z + 1); }
test "all structure bounds are non-overlapping" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); for (c.pieces, 0..) |a, i| for (c.pieces[i + 1 ..]) |b| try std.testing.expect(!a.bounds.overlaps(b.bounds)); }
test "lower branching tower rises above the entrance tower" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expect(c.boundsFor(.branching_tower).min.y > c.boundsFor(.base_tower).max.y); }
test "upper branching tower reaches the monumental skyline" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expect(c.boundsFor(.upper_tower).max.y >= 100); try std.testing.expect(c.boundsFor(.upper_tower).max.y <= 120); }
test "origin translates every piece" { const c = generateEndCity(.{ .x = -50, .y = 64, .z = 30 }); try std.testing.expectEqual(@as(i32, -50), c.boundsFor(.base_tower).min.x); try std.testing.expectEqual(@as(i32, 119), c.boundsFor(.upper_tower).max.y); }
test "base tower corners use purpur pillars" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(Block.purpur_pillar, c.blockAt(.{ .x = 0, .y = 66, .z = 0 })); }
test "base tower uses purpur wall blocks" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(Block.purpur_block, c.blockAt(.{ .x = 0, .y = 70, .z = 3 })); }
test "entrance doorway is open with purpur pillar frame" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(Block.air, c.blockAt(.{ .x = 0, .y = 66, .z = 3 })); try std.testing.expectEqual(Block.purpur_pillar, c.blockAt(.{ .x = 0, .y = 66, .z = 2 })); }
test "tower floors use end stone bricks" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(Block.end_stone_bricks, c.blockAt(.{ .x = 3, .y = 64, .z = 3 })); }
test "tower crown has end rod light spires" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(Block.end_rod, c.blockAt(.{ .x = 0, .y = 79, .z = 0 })); }
test "bridges have purpur slab skyway floors" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(Block.purpur_slab, c.blockAt(.{ .x = 9, .y = 76, .z = 3 })); }
test "bridge ends connect tower bounds" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(c.boundsFor(.base_tower).max.x + 1, c.boundsFor(.bridge_corridor).min.x); try std.testing.expectEqual(c.boundsFor(.bridge_corridor).max.x + 1, c.boundsFor(.branching_tower).min.x); }
test "upper connector joins ascending tower tiers" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expect(c.boundsFor(.upper_connector).min.y > c.boundsFor(.branching_tower).max.y); try std.testing.expect(c.boundsFor(.upper_connector).max.y < c.boundsFor(.upper_tower).min.y); }
test "loot bridge connects vault chamber" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(c.boundsFor(.loot_bridge).max.x + 1, c.boundsFor(.loot_chamber).min.x); }
test "vault chamber is high above the base" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expect(c.boundsFor(.loot_chamber).min.y > c.boundsFor(.base_tower).max.y); }
test "vault walls are enclosed by iron bars" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(Block.iron_bars, c.blockAt(.{ .x = 24, .y = 111, .z = 12 })); }
test "vault threshold has a clear doorway with purpur pillar posts" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(Block.air, c.blockAt(.{ .x = 24, .y = 108, .z = 15 })); try std.testing.expectEqual(Block.purpur_pillar, c.blockAt(.{ .x = 24, .y = 108, .z = 14 })); }
test "vault floor and roof use purpur slabs" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(Block.purpur_slab, c.blockAt(.{ .x = 25, .y = 105, .z = 12 })); try std.testing.expectEqual(Block.purpur_slab, c.blockAt(.{ .x = 25, .y = 115, .z = 12 })); }
test "vault has exactly two positioned chests" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expectEqual(@as(usize, 2), c.chests.len); for (c.chests) |chest| try std.testing.expectEqual(Block.chest, c.blockAt(chest.position)); }
test "vault chest positions are distinct" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); try std.testing.expect(!samePosition(c.chests[0].position, c.chests[1].position)); }
test "vault chests are inside the vault bounds" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); const b = c.boundsFor(.loot_chamber); for (c.chests) |chest| try std.testing.expect(b.contains(chest.position)); }
test "four sentries are accepted" { const s = try placeShulkerSentries(generateEndCity(.{ .x = 0, .y = 64, .z = 0 }), 4); try std.testing.expectEqual(@as(usize, 4), s.count); }
test "eight sentries are accepted" { const s = try placeShulkerSentries(generateEndCity(.{ .x = 0, .y = 64, .z = 0 }), 8); try std.testing.expectEqual(@as(usize, 8), s.count); }
test "fewer than four sentries are rejected" { try std.testing.expectError(error.InvalidSentryCount, placeShulkerSentries(generateEndCity(.{ .x = 0, .y = 64, .z = 0 }), 3)); }
test "more than eight sentries are rejected" { try std.testing.expectError(error.InvalidSentryCount, placeShulkerSentries(generateEndCity(.{ .x = 0, .y = 64, .z = 0 }), 9)); }
test "sentries attach only to solid purpur or end stone blocks" { const c = generateEndCity(.{ .x = 0, .y = 64, .z = 0 }); const s = try placeShulkerSentries(c, 8); for (s.sentries[0..s.count]) |entry| { const b = c.blockAt(entry.support); try std.testing.expect(b == .purpur_block or b == .purpur_pillar or b == .purpur_slab or b == .end_stone_bricks); } }
test "sentry layout covers bridge ceiling" { const s = try placeShulkerSentries(generateEndCity(.{ .x = 0, .y = 64, .z = 0 }), 8); var found = false; for (s.sentries[0..s.count]) |entry| if (entry.purpose == .bridge_ceiling and entry.face == .ceiling) { found = true; }; try std.testing.expect(found); }
test "sentry layout guarantees both vault thresholds" { const s = try placeShulkerSentries(generateEndCity(.{ .x = 0, .y = 64, .z = 0 }), 4); var found: usize = 0; for (s.sentries[0..s.count]) |entry| if (entry.purpose == .vault_threshold) { found += 1; }; try std.testing.expectEqual(@as(usize, 2), found); }
test "loot rolls are repeatable for a seed" { try std.testing.expectEqualDeep(generateVaultLoot(1234), generateVaultLoot(1234)); }
test "each vault chest receives between three and eight items" { const loot = generateVaultLoot(33); for (loot.chests) |chest| try std.testing.expect(chest.count >= CHEST_MIN_ITEMS and chest.count <= CHEST_MAX_ITEMS); }
test "loot stack counts stay positive and bounded" { const loot = generateVaultLoot(777); for (loot.chests) |chest| for (chest.entries[0..chest.count]) |entry| try std.testing.expect(entry.count >= 1 and entry.count <= 10); }
test "diamond armor uses protection four or unbreaking three" { var found = false; for (0..64) |seed| for (generateVaultLoot(seed).chests) |chest| for (chest.entries[0..chest.count]) |entry| if (entry.item == .diamond_helmet or entry.item == .diamond_chestplate or entry.item == .diamond_leggings or entry.item == .diamond_boots) { found = true; try std.testing.expect(entry.enchantment != null); const e = entry.enchantment.?; try std.testing.expect((e.kind == .protection and e.level == 4) or (e.kind == .unbreaking and e.level == 3)); }; try std.testing.expect(found); }
test "diamond sword gets sharpness five" { var found = false; for (0..64) |seed| for (generateVaultLoot(seed).chests) |chest| for (chest.entries[0..chest.count]) |entry| if (entry.item == .diamond_sword) { found = true; try std.testing.expectEqual(Enchantment.sharpness, entry.enchantment.?.kind); try std.testing.expectEqual(@as(u8, 5), entry.enchantment.?.level); }; try std.testing.expect(found); }
test "diamond pickaxe gets efficiency five" { var found = false; for (0..64) |seed| for (generateVaultLoot(seed).chests) |chest| for (chest.entries[0..chest.count]) |entry| if (entry.item == .diamond_pickaxe) { found = true; try std.testing.expectEqual(Enchantment.efficiency, entry.enchantment.?.kind); try std.testing.expectEqual(@as(u8, 5), entry.enchantment.?.level); }; try std.testing.expect(found); }
test "vault pool includes metals gems saddles and horse armor" { const pool = [_]LootItem{ .iron_ingot, .gold_ingot, .emerald, .saddle, .iron_horse_armor, .golden_horse_armor, .diamond_horse_armor }; for (pool) |item| { var found = false; for (0..13) |seed| for (generateVaultLoot(seed).chests) |chest| for (chest.entries[0..chest.count]) |entry| if (entry.item == item) { found = true; }; try std.testing.expect(found); } }
