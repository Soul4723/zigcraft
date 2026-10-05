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

    pub fn is_solid(self: BlockId) bool {
        return self != .air and self != .water;
    }

    pub fn is_fluid(self: BlockId) bool {
        return self == .water;
    }

    pub fn is_transparent(self: BlockId) bool {
        return self == .air or self == .water or self == .glass;
    }

    pub fn isFlammable(self: BlockId) bool {
        return switch (self) {
            .wood, .leaves, .wood_planks, .crafting_table, .wool => true,
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
        .brick => 2.0,
        .wood => 0.9,
        .leaves => 0.25,
        .wood_planks => 0.9,
        .crafting_table => 0.9,
        .cobblestone => 2.2,
        .stone => 2.5,
        .coal_ore => 3.0,
        .iron_ore => 3.5,
    };
}

/// Tool class needed to harvest a block's drop at all.
pub const ToolTier = enum(u8) {
    hand = 0,
    wooden = 1,
};

pub fn requiredTier(block: BlockId) ToolTier {
    return switch (block) {
        .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace => .wooden,
        else => .hand,
    };
}

/// Mining speed multiplier for held item vs target block.
/// Wooden pickaxe is 3x on stone-class blocks, 1.5x elsewhere.
pub fn toolMultiplier(held_tool_id: u8, block: BlockId) f32 {
    if (held_tool_id == TOOL_IRON_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace => 4.0,
            else => 2.0,
        };
    }
    if (held_tool_id == TOOL_WOODEN_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace => 3.0,
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
    .brick = .{ .name = "brick", .solid = true, .transparent = false, .fluid = false },
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
