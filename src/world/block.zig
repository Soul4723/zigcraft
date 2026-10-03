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

    pub fn is_solid(self: BlockId) bool {
        return self != .air and self != .water;
    }

    pub fn is_fluid(self: BlockId) bool {
        return self == .water;
    }

    pub fn is_transparent(self: BlockId) bool {
        return self == .air or self == .water;
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
}

test "new block face texture mapping" {
    const cob = BlockId.cobblestone.getFaceTexture(2);
    try std.testing.expectEqual(cob.x, 0);
    try std.testing.expectEqual(cob.y, 3);
    const ore = BlockId.coal_ore.getFaceTexture(0);
    try std.testing.expectEqual(ore.x, 1);
    try std.testing.expectEqual(ore.y, 3);
}

test "block is_transparent" {
    try std.testing.expect(BlockId.air.is_transparent());
    try std.testing.expect(!BlockId.stone.is_transparent());
    try std.testing.expect(!BlockId.dirt.is_transparent());
    try std.testing.expect(!BlockId.grass.is_transparent());
    try std.testing.expect(BlockId.water.is_transparent());
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
