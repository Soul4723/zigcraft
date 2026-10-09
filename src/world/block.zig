const std = @import("std");

/// Block type identifier. Packed into chunk storage.
pub const BlockId = enum(u8) {
    air = 0,
    stone = 1,
    dirt = 2,
    grass = 3,
    water = 4,
    wood = 5,
    leaves = 6,
    wood_planks = 7,
    crafting_table = 8,
    cobblestone = 9,
    coal_ore = 10,
    iron_ore = 11,
    sand = 12,
    glass = 13,
    sandstone = 14,
    brick = 15,
    wool = 16,
    furnace = 17,
    snow = 18,
    ladder = 19,
    tnt = 20,
    torch = 21,
    chest = 22,
    wooden_door_closed = 23,
    wooden_door_open = 24,
    pressure_plate_up = 25,
    pressure_plate_down = 26,
    redstone_wire_off = 27,
    redstone_wire_on = 28,
    lever_off = 29,
    lever_on = 30,
    repeater_off = 31,
    repeater_on = 32,
    redstone_lamp_off = 33,
    redstone_lamp_on = 34,
    iron_door_closed = 35,
    iron_door_open = 36,
    redstone_torch_off = 37,
    redstone_torch_on = 38,
    cactus = 39,
    campfire = 40,
    lava = 41,
    obsidian = 42,
    nether_portal = 43,
    netherrack = 44,
    soul_sand = 45,
    magma = 46,
    glowstone = 47,
    nether_quartz_ore = 48,
    quartz_block = 49,
    quartz_pillar = 50,
    chiseled_quartz_block = 51,
    // ponytail: Nether masonry ceiling; upgrade when adding red nether bricks and cracked nether bricks.
    nether_brick = 52,
    nether_brick_fence = 53,
    // ponytail: single-stage wart crop; upgrade to multi-stage growth blocks when crop stages land.
    nether_wart = 54,
    soul_torch = 55,
    soul_campfire = 56,
    spawner_cage = 57,

    pub fn is_solid(self: BlockId) bool {
        return self != .air and self != .water and self != .lava and self != .ladder and self != .torch and self != .wooden_door_open and self != .iron_door_open and self != .pressure_plate_up and self != .pressure_plate_down and self != .redstone_wire_off and self != .redstone_wire_on and self != .lever_off and self != .lever_on and self != .repeater_off and self != .repeater_on and self != .redstone_torch_off and self != .redstone_torch_on and self != .campfire and self != .nether_portal and self != .nether_wart and self != .soul_torch and self != .soul_campfire;
    }

    pub fn is_campfire(self: BlockId) bool {
        return self == .campfire or self == .soul_campfire;
    }

    pub fn is_spawner(self: BlockId) bool {
        return self == .spawner_cage;
    }

    pub fn is_cactus(self: BlockId) bool {
        return self == .cactus;
    }

    pub fn is_ladder(self: BlockId) bool {
        return self == .ladder;
    }

    pub fn is_fluid(self: BlockId) bool {
        return self == .water or self == .lava;
    }

    pub fn is_transparent(self: BlockId) bool {
        return self == .air or self == .water or self == .lava or self == .glass or self == .ladder or self == .torch or self == .wooden_door_closed or self == .wooden_door_open or self == .iron_door_closed or self == .iron_door_open or self == .pressure_plate_up or self == .pressure_plate_down or self == .redstone_wire_off or self == .redstone_wire_on or self == .lever_off or self == .lever_on or self == .repeater_off or self == .repeater_on or self == .redstone_torch_off or self == .redstone_torch_on or self == .nether_portal or self == .nether_brick_fence or self == .nether_wart or self == .soul_torch or self == .soul_campfire or self == .spawner_cage;
    }

    /// 0.0 = lit by sun only. 1.0 = full glow even at midnight.
    /// Covers flame torches, lit redstone lamps, lit redstone torches,
    /// powered wire, and powered repeaters.
    pub fn emissive(self: BlockId) f32 {
        return switch (self) {
            .torch => 0.9,
            .soul_torch => 0.7,
            .soul_campfire => 0.8,
            .spawner_cage => 0.6,
            .redstone_lamp_on => 1.0,
            .redstone_torch_on => 0.85,
            .redstone_wire_on => 0.7,
            .repeater_on => 0.6,
            .lava => 1.0,
            .nether_portal => 0.85,
            .magma => 0.7,
            .glowstone => 1.0,
            else => 0.0,
        };
    }

    pub fn isFlammable(self: BlockId) bool {
        return switch (self) {
            .wood, .leaves, .wood_planks, .crafting_table, .wool, .chest, .wooden_door_closed, .wooden_door_open, .pressure_plate_up, .pressure_plate_down => true,
            else => false,
        };
    }

    /// Return tile coordinates (tile_x, tile_y) on the 4x4 atlas for given face.
    /// Face index matches chunk_mesh order:
    /// 0: Up (+Y)
    /// 1: Down (-Y)
    /// 2: North (-Z)
    /// 3: South (+Z)
    /// 4: East (+X)
    /// 5: West (-X)
    pub fn getFaceTexture(self: BlockId, face_idx: usize) struct { x: u32, y: u32 } {
        return switch (self) {
            .grass => switch (face_idx) {
                0 => .{ .x = 0, .y = 0 }, // Grass Top
                1 => .{ .x = 2, .y = 0 }, // Dirt bottom
                else => .{ .x = 1, .y = 0 }, // Grass Side
            },
            .dirt => .{ .x = 2, .y = 0 },
            .stone => .{ .x = 3, .y = 0 },
            .water => .{ .x = 0, .y = 1 },
            .wood => switch (face_idx) {
                0, 1 => .{ .x = 2, .y = 1 }, // Wood ring top/bottom
                else => .{ .x = 1, .y = 1 }, // Wood bark sides
            },
            .leaves => .{ .x = 3, .y = 1 },
            .wood_planks => .{ .x = 2, .y = 2 },
            .cobblestone => .{ .x = 0, .y = 3 },
            .coal_ore => .{ .x = 1, .y = 3 },
            .iron_ore => .{ .x = 2, .y = 3 },
            .sand => .{ .x = 3, .y = 3 },
            .glass => .{ .x = 0, .y = 4 },
            .sandstone => switch (face_idx) {
                0 => .{ .x = 1, .y = 4 }, // Sandstone Top
                1 => .{ .x = 3, .y = 4 }, // Sandstone Bottom
                else => .{ .x = 2, .y = 4 }, // Sandstone Side
            },
            .brick => .{ .x = 4, .y = 4 },
            .wool => .{ .x = 7, .y = 4 },
            .furnace => .{ .x = 0, .y = 5 },
            .snow => .{ .x = 1, .y = 5 },
            .ladder => .{ .x = 4, .y = 5 },
            .tnt => .{ .x = 5, .y = 5 },
            .torch => .{ .x = 6, .y = 5 },
            .chest => .{ .x = 7, .y = 5 },
            .wooden_door_closed => .{ .x = 0, .y = 6 },
            .wooden_door_open => .{ .x = 1, .y = 6 },
            .pressure_plate_up => .{ .x = 2, .y = 6 },
            .pressure_plate_down => .{ .x = 3, .y = 6 },
            .redstone_wire_off => .{ .x = 4, .y = 6 },
            .redstone_wire_on => .{ .x = 5, .y = 6 },
            .lever_off => .{ .x = 6, .y = 6 },
            .lever_on => .{ .x = 7, .y = 6 },
            .repeater_off => .{ .x = 0, .y = 7 },
            .repeater_on => .{ .x = 1, .y = 7 },
            .redstone_lamp_off => .{ .x = 2, .y = 7 },
            .redstone_lamp_on => .{ .x = 3, .y = 7 },
            .iron_door_closed => .{ .x = 4, .y = 7 },
            .iron_door_open => .{ .x = 5, .y = 7 },
            .redstone_torch_off => .{ .x = 6, .y = 7 },
            .redstone_torch_on => .{ .x = 7, .y = 7 },
            .cactus => .{ .x = 3, .y = 1 },
            .campfire => .{ .x = 4, .y = 3 },
            .lava => .{ .x = 5, .y = 3 },
            .obsidian => .{ .x = 1, .y = 2 },
            .nether_portal => .{ .x = 2, .y = 6 }, // Ethereal purple portal vortex tile
            .netherrack => .{ .x = 3, .y = 3 }, // Craggy crimson nether stone
            .soul_sand => .{ .x = 2, .y = 1 }, // Dark gritty soul sediment
            .magma => .{ .x = 4, .y = 2 }, // Scorched glowing obsidian fissures
            .glowstone => .{ .x = 5, .y = 2 }, // Radiant crystalline golden glowstone
            .nether_quartz_ore => .{ .x = 6, .y = 2 }, // Crimson netherrack with white crystalline quartz veins
            .quartz_block => .{ .x = 7, .y = 2 }, // Polished architectural white quartz block
            .quartz_pillar => switch (face_idx) {
                0, 1 => .{ .x = 7, .y = 2 }, // Top/bottom smooth quartz cap
                else => .{ .x = 6, .y = 3 }, // Fluted column vertical sides
            },
            .chiseled_quartz_block => .{ .x = 7, .y = 3 }, // Carved glyph medallion relief
            .nether_brick => .{ .x = 4, .y = 1 }, // Dark fiery running-bond nether masonry
            .nether_brick_fence => .{ .x = 5, .y = 1 }, // Nether brick post and crossbar rail texture
            .nether_wart => .{ .x = 6, .y = 1 }, // Crimson wart cluster nodules on soul soil
            .soul_torch => .{ .x = 7, .y = 1 }, // Cyan soul flame torch
            .soul_campfire => .{ .x = 4, .y = 0 }, // Soul campfire with cyan embers
            .spawner_cage => .{ .x = 5, .y = 0 }, // Iron mesh spawner cage with burning core
            .crafting_table => switch (face_idx) {
                0 => .{ .x = 3, .y = 2 }, // Table top with tools
                1 => .{ .x = 2, .y = 2 }, // Planks bottom
                else => .{ .x = 3, .y = 2 }, // Table sides
            },
            .air => .{ .x = 0, .y = 0 },
        };
    }
};

/// Static properties for each block type.
pub const BlockDef = struct {
    name: []const u8,
    solid: bool,
    transparent: bool,
    fluid: bool,
};

/// Mining hardness: seconds to break with bare hand. Higher = tougher.
/// Tool tiers gate drops and speed up matching blocks.
///
/// Tool ids mirror `ItemType` discriminants without importing inventory
/// (cross-directory import breaks standalone test targets): 9 = wooden_pickaxe, 27 = iron_pickaxe.
pub const TOOL_WOODEN_PICKAXE: u8 = 9;
pub const TOOL_IRON_PICKAXE: u8 = 27;

pub fn hardness(block: BlockId) f32 {
    return switch (block) {
        .air, .water => 0.0,
        .dirt, .grass => 0.45,
        .sand => 0.5,
        .glass => 0.3,
        .sandstone => 1.8,
        .wool => 0.4,
        .furnace => 2.5,
        .snow => 0.3,
        .ladder => 0.4,
        .tnt => 0.0,
        .torch => 0.1,
        .soul_torch => 0.1,
        .redstone_torch_off, .redstone_torch_on => 0.0,
        .redstone_wire_off, .redstone_wire_on => 0.0,
        .chest => 1.0,
        .wooden_door_closed, .wooden_door_open, .pressure_plate_up, .pressure_plate_down, .lever_off, .lever_on => 0.5,
        .repeater_off, .repeater_on => 0.2,
        .redstone_lamp_off, .redstone_lamp_on => 0.4,
        .brick => 2.0,
        .wood => 0.9,
        .leaves => 0.25,
        .wood_planks => 0.9,
        .crafting_table => 0.9,
        .cobblestone => 2.2,
        .stone => 2.5,
        .coal_ore => 3.0,
        .iron_ore => 3.5,
        .iron_door_closed, .iron_door_open => 3.0,
        .cactus => 0.4,
        .campfire => 1.0,
        .soul_campfire => 1.0,
        .spawner_cage => 5.0,
        .lava => 0.0,
        .obsidian => 15.0,
        .nether_portal => 0.0,
        .netherrack => 0.4,
        .soul_sand => 0.5,
        .magma => 0.5,
        .glowstone => 0.3,
        .nether_quartz_ore => 0.8,
        .quartz_block => 1.2,
        .quartz_pillar => 1.2,
        .chiseled_quartz_block => 1.2,
        .nether_brick => 2.0,
        .nether_brick_fence => 2.0,
        .nether_wart => 0.3,
    };
}

/// Tool class needed to harvest a block's drop at all.
pub const ToolTier = enum(u8) {
    hand = 0,
    wooden = 1,
};

pub fn requiredTier(block: BlockId) ToolTier {
    return switch (block) {
        .stone, .obsidian, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .iron_door_closed, .iron_door_open, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence => .wooden,
        else => .hand,
    };
}

/// Mining speed multiplier for held item vs target block.
/// Wooden pickaxe is 3x on stone-class blocks, 1.5x elsewhere.
pub fn toolMultiplier(held_tool_id: u8, block: BlockId) f32 {
    if (held_tool_id == TOOL_IRON_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence => 4.0,
            else => 2.0,
        };
    }
    if (held_tool_id == TOOL_WOODEN_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence => 3.0,
            else => 1.5,
        };
    }
    return 1.0;
}

/// Seconds to mine `block` while holding tool with discriminant `held_tool_id`.
pub fn mineTime(block: BlockId, held_tool_id: u8) f32 {
    if (block == .air or block == .water) return 0.0;
    return hardness(block) / toolMultiplier(held_tool_id, block);
}

pub const block_defs = std.EnumArray(BlockId, BlockDef).init(.{
    .air = .{ .name = "air", .solid = false, .transparent = true, .fluid = false },
    .stone = .{ .name = "stone", .solid = true, .transparent = false, .fluid = false },
    .dirt = .{ .name = "dirt", .solid = true, .transparent = false, .fluid = false },
    .grass = .{ .name = "grass", .solid = true, .transparent = false, .fluid = false },
    .water = .{ .name = "water", .solid = false, .transparent = true, .fluid = true },
    .wood = .{ .name = "wood", .solid = true, .transparent = false, .fluid = false },
    .leaves = .{ .name = "leaves", .solid = true, .transparent = false, .fluid = false },
    .wood_planks = .{ .name = "wood_planks", .solid = true, .transparent = false, .fluid = false },
    .crafting_table = .{ .name = "crafting_table", .solid = true, .transparent = false, .fluid = false },
    .cobblestone = .{ .name = "cobblestone", .solid = true, .transparent = false, .fluid = false },
    .coal_ore = .{ .name = "coal_ore", .solid = true, .transparent = false, .fluid = false },
    .iron_ore = .{ .name = "iron_ore", .solid = true, .transparent = false, .fluid = false },
    .sand = .{ .name = "sand", .solid = true, .transparent = false, .fluid = false },
    .glass = .{ .name = "glass", .solid = true, .transparent = true, .fluid = false },
    .sandstone = .{ .name = "sandstone", .solid = true, .transparent = false, .fluid = false },
    .wool = .{ .name = "wool", .solid = true, .transparent = false, .fluid = false },
    .furnace = .{ .name = "furnace", .solid = true, .transparent = false, .fluid = false },
    .snow = .{ .name = "snow", .solid = true, .transparent = false, .fluid = false },
    .ladder = .{ .name = "ladder", .solid = false, .transparent = true, .fluid = false },
    .tnt = .{ .name = "tnt", .solid = true, .transparent = false, .fluid = false },
    .torch = .{ .name = "torch", .solid = false, .transparent = true, .fluid = false },
    .chest = .{ .name = "chest", .solid = true, .transparent = false, .fluid = false },
    .wooden_door_closed = .{ .name = "wooden_door_closed", .solid = true, .transparent = true, .fluid = false },
    .wooden_door_open = .{ .name = "wooden_door_open", .solid = false, .transparent = true, .fluid = false },
    .pressure_plate_up = .{ .name = "pressure_plate_up", .solid = false, .transparent = true, .fluid = false },
    .pressure_plate_down = .{ .name = "pressure_plate_down", .solid = false, .transparent = true, .fluid = false },
    .redstone_wire_off = .{ .name = "redstone_wire_off", .solid = false, .transparent = true, .fluid = false },
    .redstone_wire_on = .{ .name = "redstone_wire_on", .solid = false, .transparent = true, .fluid = false },
    .lever_off = .{ .name = "lever_off", .solid = false, .transparent = true, .fluid = false },
    .lever_on = .{ .name = "lever_on", .solid = false, .transparent = true, .fluid = false },
    .repeater_off = .{ .name = "repeater_off", .solid = false, .transparent = true, .fluid = false },
    .repeater_on = .{ .name = "repeater_on", .solid = false, .transparent = true, .fluid = false },
    .redstone_lamp_off = .{ .name = "redstone_lamp_off", .solid = true, .transparent = false, .fluid = false },
    .redstone_lamp_on = .{ .name = "redstone_lamp_on", .solid = true, .transparent = false, .fluid = false },
    .iron_door_closed = .{ .name = "iron_door_closed", .solid = true, .transparent = true, .fluid = false },
    .iron_door_open = .{ .name = "iron_door_open", .solid = false, .transparent = true, .fluid = false },
    .redstone_torch_off = .{ .name = "redstone_torch_off", .solid = false, .transparent = true, .fluid = false },
    .redstone_torch_on = .{ .name = "redstone_torch_on", .solid = false, .transparent = true, .fluid = false },
    .cactus = .{ .name = "cactus", .solid = true, .transparent = false, .fluid = false },
    .campfire = .{ .name = "campfire", .solid = false, .transparent = true, .fluid = false },
    .brick = .{ .name = "brick", .solid = true, .transparent = false, .fluid = false },
    .lava = .{ .name = "lava", .solid = false, .transparent = true, .fluid = true },
    .obsidian = .{ .name = "obsidian", .solid = true, .transparent = false, .fluid = false },
    .nether_portal = .{ .name = "nether_portal", .solid = false, .transparent = true, .fluid = false },
    .netherrack = .{ .name = "netherrack", .solid = true, .transparent = false, .fluid = false },
    .soul_sand = .{ .name = "soul_sand", .solid = true, .transparent = false, .fluid = false },
    .magma = .{ .name = "magma", .solid = true, .transparent = false, .fluid = false },
    .glowstone = .{ .name = "glowstone", .solid = true, .transparent = false, .fluid = false },
    .nether_quartz_ore = .{ .name = "nether_quartz_ore", .solid = true, .transparent = false, .fluid = false },
    .quartz_block = .{ .name = "quartz_block", .solid = true, .transparent = false, .fluid = false },
    .quartz_pillar = .{ .name = "quartz_pillar", .solid = true, .transparent = false, .fluid = false },
    .chiseled_quartz_block = .{ .name = "chiseled_quartz_block", .solid = true, .transparent = false, .fluid = false },
    .nether_brick = .{ .name = "nether_brick", .solid = true, .transparent = false, .fluid = false },
    .nether_brick_fence = .{ .name = "nether_brick_fence", .solid = true, .transparent = true, .fluid = false },
    .nether_wart = .{ .name = "nether_wart", .solid = false, .transparent = true, .fluid = false },
    .soul_torch = .{ .name = "soul_torch", .solid = false, .transparent = true, .fluid = false },
    .soul_campfire = .{ .name = "soul_campfire", .solid = false, .transparent = true, .fluid = false },
    .spawner_cage = .{ .name = "spawner_cage", .solid = true, .transparent = true, .fluid = false },
});

test "block is_solid" {
    try std.testing.expect(!BlockId.air.is_solid());
    try std.testing.expect(BlockId.stone.is_solid());
    try std.testing.expect(BlockId.dirt.is_solid());
    try std.testing.expect(BlockId.grass.is_solid());
    try std.testing.expect(!BlockId.water.is_solid());
    try std.testing.expect(BlockId.wood.is_solid());
    try std.testing.expect(BlockId.leaves.is_solid());
    try std.testing.expect(BlockId.cobblestone.is_solid());
    try std.testing.expect(BlockId.coal_ore.is_solid());
    try std.testing.expect(BlockId.iron_ore.is_solid());
    try std.testing.expect(BlockId.sand.is_solid());
    try std.testing.expect(BlockId.glass.is_solid());
    try std.testing.expect(BlockId.sandstone.is_solid());
    try std.testing.expect(BlockId.brick.is_solid());
}

test "new block face texture mapping" {
    const cob = BlockId.cobblestone.getFaceTexture(2);
    try std.testing.expectEqual(cob.x, 0);
    try std.testing.expectEqual(cob.y, 3);
    const ore = BlockId.coal_ore.getFaceTexture(0);
    try std.testing.expectEqual(ore.x, 1);
    try std.testing.expectEqual(ore.y, 3);
    const iron = BlockId.iron_ore.getFaceTexture(0);
    try std.testing.expectEqual(iron.x, 2);
    try std.testing.expectEqual(iron.y, 3);
    const sand = BlockId.sand.getFaceTexture(0);
    try std.testing.expectEqual(sand.x, 3);
    try std.testing.expectEqual(sand.y, 3);
    const gl = BlockId.glass.getFaceTexture(0);
    try std.testing.expectEqual(gl.x, 0);
    try std.testing.expectEqual(gl.y, 4);
    const ss_top = BlockId.sandstone.getFaceTexture(0);
    try std.testing.expectEqual(ss_top.x, 1);
    try std.testing.expectEqual(ss_top.y, 4);
    const ss_side = BlockId.sandstone.getFaceTexture(2);
    try std.testing.expectEqual(ss_side.x, 2);
    try std.testing.expectEqual(ss_side.y, 4);
    const ss_bot = BlockId.sandstone.getFaceTexture(1);
    try std.testing.expectEqual(ss_bot.x, 3);
    try std.testing.expectEqual(ss_bot.y, 4);
    const br = BlockId.brick.getFaceTexture(0);
    try std.testing.expectEqual(br.x, 4);
    try std.testing.expectEqual(br.y, 4);
}

test "block is_transparent" {
    try std.testing.expect(BlockId.air.is_transparent());
    try std.testing.expect(!BlockId.stone.is_transparent());
    try std.testing.expect(!BlockId.dirt.is_transparent());
    try std.testing.expect(!BlockId.grass.is_transparent());
    try std.testing.expect(BlockId.water.is_transparent());
    try std.testing.expect(BlockId.glass.is_transparent());
    try std.testing.expect(!BlockId.sandstone.is_transparent());
    try std.testing.expect(!BlockId.brick.is_transparent());
    try std.testing.expect(!BlockId.wood.is_transparent());
    try std.testing.expect(!BlockId.leaves.is_transparent());
}

test "block properties" {
    const wood = block_defs.get(.wood);
    try std.testing.expectEqualStrings(wood.name, "wood");
    try std.testing.expect(wood.solid);

    const leaves = block_defs.get(.leaves);
    try std.testing.expectEqualStrings(leaves.name, "leaves");
    try std.testing.expect(leaves.solid);
}

test "hardness tiers and tool multipliers" {
    try std.testing.expect(hardness(.dirt) < hardness(.stone));
    try std.testing.expect(hardness(.coal_ore) > hardness(.cobblestone));
    try std.testing.expectEqual(requiredTier(.stone), .wooden);
    try std.testing.expectEqual(requiredTier(.coal_ore), .wooden);
    try std.testing.expectEqual(requiredTier(.dirt), .hand);
    try std.testing.expect(toolMultiplier(TOOL_WOODEN_PICKAXE, .stone) > toolMultiplier(TOOL_WOODEN_PICKAXE, .dirt));
    try std.testing.expectEqual(toolMultiplier(0, .stone), 1.0);
    try std.testing.expect(mineTime(.stone, TOOL_WOODEN_PICKAXE) < mineTime(.stone, 0));
    try std.testing.expect(mineTime(.dirt, 0) < mineTime(.stone, 0));
}

test "block count is reasonable" {
    try std.testing.expect(@typeInfo(BlockId).@"enum".fields.len <= 256);
}

test "block face texture mapping" {
    const wood_top = BlockId.wood.getFaceTexture(0);
    try std.testing.expectEqual(wood_top.x, 2);
    try std.testing.expectEqual(wood_top.y, 1);

    const wood_side = BlockId.wood.getFaceTexture(2);
    try std.testing.expectEqual(wood_side.x, 1);
    try std.testing.expectEqual(wood_side.y, 1);

    const leaves = BlockId.leaves.getFaceTexture(0);
    try std.testing.expectEqual(leaves.x, 3);
    try std.testing.expectEqual(leaves.y, 1);
}

test "wool block props" {
    try std.testing.expect(BlockId.wool.is_solid());
    try std.testing.expect(!BlockId.wool.is_transparent());
    const t = BlockId.wool.getFaceTexture(2);
    try std.testing.expectEqual(t.x, 7);
    try std.testing.expectEqual(t.y, 4);
    try std.testing.expectApproxEqAbs(hardness(.wool), 0.4, 0.001);
}

test "flammable blocks" {
    try std.testing.expect(BlockId.wood.isFlammable());
    try std.testing.expect(BlockId.leaves.isFlammable());
    try std.testing.expect(BlockId.wool.isFlammable());
    try std.testing.expect(!BlockId.stone.isFlammable());
    try std.testing.expect(!BlockId.coal_ore.isFlammable());
}

test "furnace block props" {
    try std.testing.expect(BlockId.furnace.is_solid());
    const t = BlockId.furnace.getFaceTexture(2);
    try std.testing.expectEqual(t.x, 0);
    try std.testing.expectEqual(t.y, 5);
    try std.testing.expectEqual(requiredTier(.furnace), .wooden);
}

test "tnt block props" {
    try std.testing.expect(BlockId.tnt.is_solid());
    const t = BlockId.tnt.getFaceTexture(0);
    try std.testing.expectEqual(t.x, 5);
    try std.testing.expectEqual(t.y, 5);
    try std.testing.expectEqual(hardness(.tnt), 0.0);
}

test "torch block props" {
    try std.testing.expect(!BlockId.torch.is_solid());
    try std.testing.expect(BlockId.torch.is_transparent());
    const t = BlockId.torch.getFaceTexture(0);
    try std.testing.expectEqual(t.x, 6);
    try std.testing.expectEqual(t.y, 5);
}

test "chest block props" {
    try std.testing.expect(BlockId.chest.is_solid());
    try std.testing.expect(!BlockId.chest.is_transparent());
    try std.testing.expect(BlockId.chest.isFlammable());
    const t = BlockId.chest.getFaceTexture(0);
    try std.testing.expectEqual(t.x, 7);
    try std.testing.expectEqual(t.y, 5);
    try std.testing.expectEqual(hardness(.chest), 1.0);
}

test "emissive blocks glow, stone and dirt do not" {
    try std.testing.expectApproxEqAbs(BlockId.torch.emissive(), 0.9, 0.001);
    try std.testing.expectApproxEqAbs(BlockId.redstone_lamp_on.emissive(), 1.0, 0.001);
    try std.testing.expectApproxEqAbs(BlockId.redstone_wire_on.emissive(), 0.7, 0.001);
    try std.testing.expectEqual(BlockId.stone.emissive(), 0.0);
    try std.testing.expectEqual(BlockId.redstone_lamp_off.emissive(), 0.0);
    try std.testing.expectEqual(BlockId.redstone_wire_off.emissive(), 0.0);
}

test "redstone torch block properties" {
    try std.testing.expect(!BlockId.redstone_torch_off.is_solid());
    try std.testing.expect(!BlockId.redstone_torch_on.is_solid());
    try std.testing.expect(BlockId.redstone_torch_off.is_transparent());
    try std.testing.expect(BlockId.redstone_torch_on.is_transparent());
    const rto = BlockId.redstone_torch_off.getFaceTexture(0);
    try std.testing.expectEqual(rto.x, 6);
    try std.testing.expectEqual(rto.y, 7);
    const rtn = BlockId.redstone_torch_on.getFaceTexture(0);
    try std.testing.expectEqual(rtn.x, 7);
    try std.testing.expectEqual(rtn.y, 7);
}

test "iron door block properties" {
    try std.testing.expect(BlockId.iron_door_closed.is_solid());
    try std.testing.expect(!BlockId.iron_door_open.is_solid());
    try std.testing.expect(BlockId.iron_door_closed.is_transparent());
    try std.testing.expect(BlockId.iron_door_open.is_transparent());
    try std.testing.expectEqual(requiredTier(.iron_door_closed), .wooden);
    const idc = BlockId.iron_door_closed.getFaceTexture(0);
    try std.testing.expectEqual(idc.x, 4);
    try std.testing.expectEqual(idc.y, 7);
    const ido = BlockId.iron_door_open.getFaceTexture(0);
    try std.testing.expectEqual(ido.x, 5);
    try std.testing.expectEqual(ido.y, 7);
}

test "redstone lamp block properties" {
    try std.testing.expect(BlockId.redstone_lamp_off.is_solid());
    try std.testing.expect(BlockId.redstone_lamp_on.is_solid());
    try std.testing.expect(!BlockId.redstone_lamp_off.is_transparent());
    try std.testing.expect(!BlockId.redstone_lamp_on.is_transparent());
    const lo = BlockId.redstone_lamp_off.getFaceTexture(0);
    try std.testing.expectEqual(lo.x, 2);
    try std.testing.expectEqual(lo.y, 7);
    const ln = BlockId.redstone_lamp_on.getFaceTexture(0);
    try std.testing.expectEqual(ln.x, 3);
    try std.testing.expectEqual(ln.y, 7);
}

test "repeater block properties" {
    try std.testing.expect(!BlockId.repeater_off.is_solid());
    try std.testing.expect(!BlockId.repeater_on.is_solid());
    try std.testing.expect(BlockId.repeater_off.is_transparent());
    try std.testing.expect(BlockId.repeater_on.is_transparent());
    const ro = BlockId.repeater_off.getFaceTexture(0);
    try std.testing.expectEqual(ro.x, 0);
    try std.testing.expectEqual(ro.y, 7);
    const rn = BlockId.repeater_on.getFaceTexture(0);
    try std.testing.expectEqual(rn.x, 1);
    try std.testing.expectEqual(rn.y, 7);
}

test "lever block properties" {
    try std.testing.expect(!BlockId.lever_off.is_solid());
    try std.testing.expect(!BlockId.lever_on.is_solid());
    try std.testing.expect(BlockId.lever_off.is_transparent());
    try std.testing.expect(BlockId.lever_on.is_transparent());
    const lo = BlockId.lever_off.getFaceTexture(0);
    try std.testing.expectEqual(lo.x, 6);
    try std.testing.expectEqual(lo.y, 6);
    const ln = BlockId.lever_on.getFaceTexture(0);
    try std.testing.expectEqual(ln.x, 7);
    try std.testing.expectEqual(ln.y, 6);
}

test "redstone wire block properties" {
    try std.testing.expect(!BlockId.redstone_wire_off.is_solid());
    try std.testing.expect(!BlockId.redstone_wire_on.is_solid());
    try std.testing.expect(BlockId.redstone_wire_off.is_transparent());
    try std.testing.expect(BlockId.redstone_wire_on.is_transparent());
    try std.testing.expectEqual(hardness(.redstone_wire_off), 0.0);
    const two = BlockId.redstone_wire_off.getFaceTexture(0);
    try std.testing.expectEqual(two.x, 4);
    try std.testing.expectEqual(two.y, 6);
    const twn = BlockId.redstone_wire_on.getFaceTexture(0);
    try std.testing.expectEqual(twn.x, 5);
    try std.testing.expectEqual(twn.y, 6);
}

test "door block properties" {
    try std.testing.expect(BlockId.wooden_door_closed.is_solid());
    try std.testing.expect(!BlockId.wooden_door_open.is_solid());
    try std.testing.expect(BlockId.wooden_door_closed.is_transparent());
    try std.testing.expect(BlockId.wooden_door_open.is_transparent());
    try std.testing.expect(BlockId.wooden_door_closed.isFlammable());
    try std.testing.expect(!BlockId.pressure_plate_up.is_solid());
    try std.testing.expect(!BlockId.pressure_plate_down.is_solid());
    try std.testing.expect(BlockId.pressure_plate_up.is_transparent());
    try std.testing.expect(BlockId.pressure_plate_down.is_transparent());
    try std.testing.expect(BlockId.pressure_plate_up.isFlammable());
    const tpu = BlockId.pressure_plate_up.getFaceTexture(0);
    try std.testing.expectEqual(tpu.x, 2);
    try std.testing.expectEqual(tpu.y, 6);
    const tpd = BlockId.pressure_plate_down.getFaceTexture(0);
    try std.testing.expectEqual(tpd.x, 3);
    try std.testing.expectEqual(tpd.y, 6);
    const tc = BlockId.wooden_door_closed.getFaceTexture(0);
    try std.testing.expectEqual(tc.x, 0);
    try std.testing.expectEqual(tc.y, 6);
    const to = BlockId.wooden_door_open.getFaceTexture(0);
    try std.testing.expectEqual(to.x, 1);
    try std.testing.expectEqual(to.y, 6);
}

test "campfire block definition" {
    try std.testing.expect(BlockId.campfire.is_campfire());
    try std.testing.expect(!BlockId.campfire.is_solid());
    try std.testing.expectEqual(hardness(BlockId.campfire), 1.0);
}

test "cactus properties and block definition" {
    try std.testing.expect(BlockId.cactus.is_solid());
    try std.testing.expect(BlockId.cactus.is_cactus());
    try std.testing.expectEqual(hardness(BlockId.cactus), 0.4);
    const tex = BlockId.cactus.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 3);
    try std.testing.expectEqual(tex.y, 1);
}

pub const FootstepType = enum {
    grass,
    stone,
    wood,
    dirt,
    sand,
    snow,
    wool,
};

pub fn footstepType(block: BlockId) FootstepType {
    return switch (block) {
        .grass => .grass,
        .stone, .obsidian, .cobblestone, .coal_ore, .iron_ore, .glass, .sandstone, .brick, .nether_brick, .nether_brick_fence => .stone,
        .wood => .wood,
        .dirt => .dirt,
        .sand => .sand,
        .snow => .snow,
        .wool => .wool,
        else => .grass,
    };
}

test "footstepType block classification" {
    try std.testing.expectEqual(FootstepType.grass, footstepType(.grass));
    try std.testing.expectEqual(FootstepType.stone, footstepType(.stone));
    try std.testing.expectEqual(FootstepType.stone, footstepType(.cobblestone));
    try std.testing.expectEqual(FootstepType.stone, footstepType(.brick));
    try std.testing.expectEqual(FootstepType.wood, footstepType(.wood));
    try std.testing.expectEqual(FootstepType.dirt, footstepType(.dirt));
    try std.testing.expectEqual(FootstepType.sand, footstepType(.sand));
    try std.testing.expectEqual(FootstepType.snow, footstepType(.snow));
    try std.testing.expectEqual(FootstepType.wool, footstepType(.wool));
    try std.testing.expectEqual(FootstepType.grass, footstepType(.air));
}

test "lava fluid and obsidian hardness properties" {
    try std.testing.expect(BlockId.lava.is_fluid());
    try std.testing.expect(!BlockId.lava.is_solid());
    try std.testing.expectEqual(@as(f32, 1.0), BlockId.lava.emissive());
    try std.testing.expect(BlockId.obsidian.is_solid());
    try std.testing.expect(!BlockId.obsidian.is_fluid());
    try std.testing.expectEqual(@as(f32, 15.0), hardness(.obsidian));
    try std.testing.expectEqual(ToolTier.wooden, requiredTier(.obsidian));
}

test "nether brick block properties and textures" {
    try std.testing.expect(BlockId.nether_brick.is_solid());
    try std.testing.expect(!BlockId.nether_brick.is_transparent());
    try std.testing.expect(!BlockId.nether_brick.is_fluid());
    try std.testing.expectEqual(hardness(.nether_brick), 2.0);
    try std.testing.expectEqual(requiredTier(.nether_brick), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .nether_brick), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .nether_brick), 4.0);
    try std.testing.expectEqual(footstepType(.nether_brick), .stone);

    const tex = BlockId.nether_brick.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 4);
    try std.testing.expectEqual(tex.y, 1);
}

test "nether brick fence block properties and textures" {
    try std.testing.expect(BlockId.nether_brick_fence.is_solid());
    try std.testing.expect(BlockId.nether_brick_fence.is_transparent());
    try std.testing.expect(!BlockId.nether_brick_fence.is_fluid());
    try std.testing.expectEqual(hardness(.nether_brick_fence), 2.0);
    try std.testing.expectEqual(requiredTier(.nether_brick_fence), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .nether_brick_fence), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .nether_brick_fence), 4.0);
    try std.testing.expectEqual(footstepType(.nether_brick_fence), .stone);

    const tex = BlockId.nether_brick_fence.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 5);
    try std.testing.expectEqual(tex.y, 1);
}

test "nether wart block properties and textures" {
    try std.testing.expect(!BlockId.nether_wart.is_solid());
    try std.testing.expect(BlockId.nether_wart.is_transparent());
    try std.testing.expect(!BlockId.nether_wart.is_fluid());
    try std.testing.expectEqual(hardness(.nether_wart), 0.3);
    try std.testing.expectEqual(requiredTier(.nether_wart), .hand);

    const tex = BlockId.nether_wart.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 6);
    try std.testing.expectEqual(tex.y, 1);
}

test "soul torch properties and cyan emissive" {
    try std.testing.expect(!BlockId.soul_torch.is_solid());
    try std.testing.expect(BlockId.soul_torch.is_transparent());
    try std.testing.expectApproxEqAbs(BlockId.soul_torch.emissive(), 0.7, 0.001);
    const tex = BlockId.soul_torch.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 7);
    try std.testing.expectEqual(tex.y, 1);
}

test "soul campfire properties and cyan emissive" {
    try std.testing.expect(BlockId.soul_campfire.is_campfire());
    try std.testing.expect(!BlockId.soul_campfire.is_solid());
    try std.testing.expect(BlockId.soul_campfire.is_transparent());
    try std.testing.expectApproxEqAbs(BlockId.soul_campfire.emissive(), 0.8, 0.001);
    const tex = BlockId.soul_campfire.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 4);
    try std.testing.expectEqual(tex.y, 0);
}

test "spawner cage properties and texture" {
    try std.testing.expect(BlockId.spawner_cage.is_solid());
    try std.testing.expect(BlockId.spawner_cage.is_transparent());
    try std.testing.expectApproxEqAbs(BlockId.spawner_cage.emissive(), 0.6, 0.001);
    try std.testing.expectEqual(hardness(BlockId.spawner_cage), 5.0);
    const tex = BlockId.spawner_cage.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 5);
    try std.testing.expectEqual(tex.y, 0);
}
