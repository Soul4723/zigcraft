const std = @import("std");

pub const Position = struct { x: i32, y: i32, z: i32 };
pub const Bounds = struct { min: Position, max: Position };
pub const Block = enum { air, purpur_block, purpur_slab, purpur_pillar, end_rod, dragon_head, brewing_stand, chest, item_frame, shulker };
pub const ItemType = enum { dragon_head, elytra, diamond_chestplate, diamond_sword, diamond_pickaxe, iron_ingot, gold_ingot, emerald, potion_of_healing_ii };
pub const PotionEffect = enum { instant_health_ii };
pub const Direction = enum { north, south, east, west };
pub const AttachmentFace = enum { wall, ceiling };

pub const SHIP_X_MIN: i32 = 80;
pub const SHIP_X_MAX: i32 = 88;
pub const SHIP_Y_MIN: i32 = 80;
pub const SHIP_Y_MAX: i32 = 95;
pub const SHIP_Z_MIN: i32 = -2;
pub const SHIP_Z_MAX: i32 = 2;
pub const DRAGON_HEAD_EYE_EMISSIVE: f32 = 0.25;
pub const LOOT_CHEST_COUNT = 2;
pub const HEALTH_POTION_COUNT = 2;

pub const LootKind = enum { diamond_chestplate, diamond_sword, diamond_pickaxe, iron_ingot, gold_ingot, emerald };
pub const LootEntry = struct { item: LootKind, count: u8, enchantment: ?Enchantment = null };
pub const Enchantment = enum { protection_iv, unbreaking_iii, sharpness_v, efficiency_v };
pub const LootChest = struct { position: Position, entries: [3]LootEntry };
pub const BrewingStand = struct {
    position: Position,
    bottles: [HEALTH_POTION_COUNT]PotionEffect,
};
pub const ItemFrame = struct { position: Position, facing: Direction, item: ItemType };
pub const DragonHead = struct { position: Position, facing: Direction, item: ItemType, eye_emissive: f32 };
pub const ShulkerGuard = struct { position: Position, attached_to: Position, attached_face: AttachmentFace };

/// Deterministic End Ship placement relative to the End City origin. The hull
/// floats at Y=80..95 and the stern mooring remains within the city airspace.
pub fn generateEndShip(city_origin: Position) EndShip {
    const bounds = Bounds{
        .min = .{ .x = city_origin.x + SHIP_X_MIN, .y = city_origin.y + 16, .z = city_origin.z + SHIP_Z_MIN },
        .max = .{ .x = city_origin.x + SHIP_X_MAX, .y = city_origin.y + 31, .z = city_origin.z + SHIP_Z_MAX },
    };
    return .{
        .bounds = bounds,
        .dragon_head = .{ .position = add(city_origin, .{ .x = 88, .y = 24, .z = 0 }), .facing = .east, .item = .dragon_head, .eye_emissive = DRAGON_HEAD_EYE_EMISSIVE },
        .brewing_stand = .{ .position = add(city_origin, .{ .x = 82, .y = 21, .z = 0 }), .bottles = .{ .instant_health_ii, .instant_health_ii } },
        .chests = .{
            .{ .position = add(city_origin, .{ .x = 86, .y = 21, .z = -1 }), .entries = .{
                .{ .item = .diamond_chestplate, .count = 1, .enchantment = .protection_iv },
                .{ .item = .iron_ingot, .count = 8 },
                .{ .item = .emerald, .count = 5 },
            } },
            .{ .position = add(city_origin, .{ .x = 86, .y = 21, .z = 1 }), .entries = .{
                .{ .item = .diamond_sword, .count = 1, .enchantment = .sharpness_v },
                .{ .item = .diamond_pickaxe, .count = 1, .enchantment = .efficiency_v },
                .{ .item = .gold_ingot, .count = 6 },
            } },
        },
        .elytra_frame = .{ .position = add(city_origin, .{ .x = 84, .y = 23, .z = -2 }), .facing = .north, .item = .elytra },
        .shulker_guard = .{ .position = add(city_origin, .{ .x = 84, .y = 23, .z = 0 }), .attached_to = add(city_origin, .{ .x = 84, .y = 24, .z = 0 }), .attached_face = .ceiling },
    };
}

pub const EndShip = struct {
    bounds: Bounds,
    dragon_head: DragonHead,
    brewing_stand: BrewingStand,
    chests: [LOOT_CHEST_COUNT]LootChest,
    elytra_frame: ItemFrame,
    shulker_guard: ShulkerGuard,

    pub fn blockAt(self: EndShip, p: Position) Block {
        if (samePosition(p, self.dragon_head.position)) return .dragon_head;
        if (samePosition(p, self.brewing_stand.position)) return .brewing_stand;
        for (self.chests) |chest| if (samePosition(p, chest.position)) return .chest;
        if (samePosition(p, self.elytra_frame.position)) return .item_frame;
        if (samePosition(p, self.shulker_guard.position)) return .shulker;

        const b = self.bounds;
        if (p.x < b.min.x or p.x > b.max.x or p.y < b.min.y or p.y > b.max.y or p.z < b.min.z or p.z > b.max.z) return .air;

        // Shallow curved keel: the center hangs lowest, tapering at the bow and stern.
        if (p.y == b.min.y + 1 and p.z == 0 and p.x >= b.min.x + 1 and p.x <= b.max.x - 1) return .purpur_block;
        if (p.y == b.min.y + 2 and @abs(p.z) <= 1 and p.x >= b.min.x + 1 and p.x <= b.max.x - 1) return .purpur_block;
        if (p.y == b.min.y + 3 and @abs(p.z) <= 1 and p.x >= b.min.x + 1 and p.x <= b.max.x - 1) return .purpur_slab;
        // Lower cargo deck and upper deck.
        if (p.y == b.min.y + 4 and @abs(p.z) <= 1) return .purpur_slab;
        if (p.y == b.min.y + 8 and @abs(p.z) <= 1) return .purpur_slab;
        if (p.y == b.min.y + 8 and @abs(p.z) == 2) return .purpur_block;
        // Railings ring the exposed deck; the bow remains clear for the figurehead.
        if (p.y == b.min.y + 9 and (p.z == b.min.z or p.z == b.max.z or p.x == b.min.x) and p.x < b.max.x) return .purpur_slab;
        // Central pillar mast and End Rod yardarms/rigging.
        if (p.x == b.min.x + 4 and p.z == 0 and p.y >= b.min.y + 10) return .purpur_pillar;
        if (p.y == b.min.y + 13 and p.x == b.min.x + 4 and @abs(p.z) == 2) return .end_rod;
        if (p.y == b.min.y + 13 and p.z == 0 and (p.x == b.min.x + 2 or p.x == b.min.x + 6)) return .end_rod;
        if ((p.x == b.min.x + 2 or p.x == b.min.x + 6) and p.y >= b.min.y + 11 and p.y <= b.min.y + 13 and p.z == 0) return .end_rod;
        return .air;
    }
};

fn add(a: Position, b: Position) Position {
    return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
}

fn samePosition(a: Position, b: Position) bool {
    return a.x == b.x and a.y == b.y and a.z == b.z;
}

fn cityShip() EndShip {
    return generateEndShip(.{ .x = 0, .y = 64, .z = 0 });
}

test "ship hull bounds cover expected floating void coordinates" {
    const b = cityShip().bounds;
    try std.testing.expectEqual(@as(i32, 80), b.min.x);
    try std.testing.expectEqual(@as(i32, 88), b.max.x);
    try std.testing.expectEqual(@as(i32, 80), b.min.y);
    try std.testing.expectEqual(@as(i32, 95), b.max.y);
    try std.testing.expectEqual(@as(i32, -2), b.min.z);
    try std.testing.expectEqual(@as(i32, 2), b.max.z);
}
test "ship generation translates with the End City origin" {
    const s = generateEndShip(.{ .x = -20, .y = 70, .z = 40 });
    try std.testing.expectEqual(@as(i32, 60), s.bounds.min.x);
    try std.testing.expectEqual(@as(i32, 86), s.bounds.min.y);
    try std.testing.expectEqual(@as(i32, 38), s.bounds.min.z);
}
test "ship is positioned above the End City origin" {
    const s = cityShip();
    try std.testing.expect(s.bounds.min.y > 64);
    try std.testing.expectEqual(@as(i32, 16), s.bounds.min.y - 64);
}
test "ship coordinate bounds are ordered" {
    const b = cityShip().bounds;
    try std.testing.expect(b.min.x < b.max.x and b.min.y < b.max.y and b.min.z < b.max.z);
}
test "space below and around ship remains void air" {
    const s = cityShip();
    try std.testing.expectEqual(Block.air, s.blockAt(.{ .x = 84, .y = 70, .z = 0 }));
    try std.testing.expectEqual(Block.air, s.blockAt(.{ .x = 79, .y = 90, .z = 0 }));
}
test "curved keel has a low center and tapered ends" {
    const s = cityShip();
    try std.testing.expectEqual(Block.purpur_block, s.blockAt(.{ .x = 84, .y = 81, .z = 0 }));
    try std.testing.expectEqual(Block.purpur_block, s.blockAt(.{ .x = 83, .y = 82, .z = 1 }));
    try std.testing.expectEqual(Block.air, s.blockAt(.{ .x = 80, .y = 81, .z = 0 }));
}
test "purpur slab deck spans the hull" {
    const s = cityShip();
    try std.testing.expectEqual(Block.purpur_slab, s.blockAt(.{ .x = 84, .y = 88, .z = 0 }));
}
test "purpur bulwarks protect both deck sides" {
    const s = cityShip();
    try std.testing.expectEqual(Block.purpur_block, s.blockAt(.{ .x = 84, .y = 88, .z = -2 }));
    try std.testing.expectEqual(Block.purpur_block, s.blockAt(.{ .x = 84, .y = 88, .z = 2 }));
}
test "purpur slab railings border the deck" {
    const s = cityShip();
    try std.testing.expectEqual(Block.purpur_slab, s.blockAt(.{ .x = 83, .y = 89, .z = -2 }));
    try std.testing.expectEqual(Block.purpur_slab, s.blockAt(.{ .x = 83, .y = 89, .z = 2 }));
}
test "prow opening leaves a clear figurehead mount" {
    const s = cityShip();
    try std.testing.expectEqual(Block.dragon_head, s.blockAt(s.dragon_head.position));
}
test "prow trophy is dragon head item type" {
    try std.testing.expectEqual(ItemType.dragon_head, cityShip().dragon_head.item);
}
test "prow dragon head faces forward from the bow" {
    const h = cityShip().dragon_head;
    try std.testing.expectEqual(Direction.east, h.facing);
    try std.testing.expectEqual(@as(i32, 88), h.position.x);
}
test "dragon head eyes use quarter emissive intensity" {
    try std.testing.expectEqual(@as(f32, 0.25), cityShip().dragon_head.eye_emissive);
}
test "mast is a central purpur pillar" {
    const s = cityShip();
    try std.testing.expectEqual(Block.purpur_pillar, s.blockAt(.{ .x = 84, .y = 90, .z = 0 }));
    try std.testing.expectEqual(Block.purpur_pillar, s.blockAt(.{ .x = 84, .y = 95, .z = 0 }));
}
test "yardarms use End Rod lighting" {
    const s = cityShip();
    try std.testing.expectEqual(Block.end_rod, s.blockAt(.{ .x = 84, .y = 93, .z = -2 }));
    try std.testing.expectEqual(Block.end_rod, s.blockAt(.{ .x = 84, .y = 93, .z = 2 }));
}
test "rigging uses End Rods along the mast supports" {
    const s = cityShip();
    try std.testing.expectEqual(Block.end_rod, s.blockAt(.{ .x = 82, .y = 92, .z = 0 }));
    try std.testing.expectEqual(Block.end_rod, s.blockAt(.{ .x = 86, .y = 92, .z = 0 }));
}
test "lower cargo deck has an installed brewing stand" {
    const s = cityShip();
    try std.testing.expectEqual(Block.brewing_stand, s.blockAt(s.brewing_stand.position));
}
test "brewing stand contains exactly two potion bottles" {
    try std.testing.expectEqual(@as(usize, 2), cityShip().brewing_stand.bottles.len);
}
test "both cargo potions are Instant Health II" {
    const b = cityShip().brewing_stand.bottles;
    try std.testing.expectEqual(PotionEffect.instant_health_ii, b[0]);
    try std.testing.expectEqual(PotionEffect.instant_health_ii, b[1]);
}
test "cargo hold contains two End City loot chests" {
    try std.testing.expectEqual(@as(usize, 2), cityShip().chests.len);
}
test "both loot chests are generated as chest blocks" {
    const s = cityShip();
    for (s.chests) |chest| try std.testing.expectEqual(Block.chest, s.blockAt(chest.position));
}
test "first chest includes enchanted diamond gear iron and emeralds" {
    const c = cityShip().chests[0];
    try std.testing.expectEqual(LootKind.diamond_chestplate, c.entries[0].item);
    try std.testing.expectEqual(Enchantment.protection_iv, c.entries[0].enchantment.?);
    try std.testing.expectEqual(LootKind.iron_ingot, c.entries[1].item);
    try std.testing.expectEqual(LootKind.emerald, c.entries[2].item);
}
test "second chest includes enchanted diamond gear and gold" {
    const c = cityShip().chests[1];
    try std.testing.expectEqual(LootKind.diamond_sword, c.entries[0].item);
    try std.testing.expectEqual(Enchantment.sharpness_v, c.entries[0].enchantment.?);
    try std.testing.expectEqual(LootKind.diamond_pickaxe, c.entries[1].item);
    try std.testing.expectEqual(LootKind.gold_ingot, c.entries[2].item);
}
test "vault bulkhead item frame displays Elytra" {
    const f = cityShip().elytra_frame;
    try std.testing.expectEqual(Block.item_frame, cityShip().blockAt(f.position));
    try std.testing.expectEqual(ItemType.elytra, f.item);
}
test "Elytra frame is attached to the cargo hold bulkhead" {
    const f = cityShip().elytra_frame;
    try std.testing.expectEqual(@as(i32, -2), f.position.z);
    try std.testing.expectEqual(Direction.north, f.facing);
}
test "one ceiling Shulker guards the Elytra vault" {
    const s = cityShip();
    try std.testing.expectEqual(Block.shulker, s.blockAt(s.shulker_guard.position));
    try std.testing.expectEqual(AttachmentFace.ceiling, s.shulker_guard.attached_face);
    try std.testing.expectEqual(@as(i32, 88), s.shulker_guard.attached_to.y);
}
test "Shulker sentry is attached to the vault ceiling over its interior" {
    const s = cityShip();
    try std.testing.expectEqual(s.elytra_frame.position.y, s.shulker_guard.position.y);
    try std.testing.expectEqual(@as(i32, 1), s.shulker_guard.attached_to.y - s.shulker_guard.position.y);
    try std.testing.expectEqual(@as(i32, 84), s.shulker_guard.position.x);
}
