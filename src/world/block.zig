const std = @import("std");

/// Block type identifier. Packed into chunk storage.
pub const BlockId = enum(u8) {
    air = 0,
    stone = 1,
    dirt = 2,
    grass = 3,
    water = 4,

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
            .water => .{ .x = 0, .y = 1 }, // Water tile on row 1
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
});

test "block is_solid" {
    try std.testing.expect(!BlockId.air.is_solid());
    try std.testing.expect(BlockId.stone.is_solid());
    try std.testing.expect(BlockId.dirt.is_solid());
    try std.testing.expect(BlockId.grass.is_solid());
    try std.testing.expect(!BlockId.water.is_solid());
}

test "block is_transparent" {
    try std.testing.expect(BlockId.air.is_transparent());
    try std.testing.expect(!BlockId.stone.is_transparent());
    try std.testing.expect(!BlockId.dirt.is_transparent());
    try std.testing.expect(!BlockId.grass.is_transparent());
    try std.testing.expect(BlockId.water.is_transparent());
}

test "block properties" {
    const grass = block_defs.get(.grass);
    try std.testing.expectEqualStrings(grass.name, "grass");
    try std.testing.expect(grass.solid);
    try std.testing.expect(!grass.transparent);

    const water = block_defs.get(.water);
    try std.testing.expectEqualStrings(water.name, "water");
    try std.testing.expect(!water.solid);
    try std.testing.expect(water.fluid);
}

test "block count is reasonable" {
    try std.testing.expect(@typeInfo(BlockId).@"enum".fields.len <= 256);
}

test "block face texture mapping" {
    const grass_top = BlockId.grass.getFaceTexture(0);
    try std.testing.expectEqual(grass_top.x, 0);

    const grass_bottom = BlockId.grass.getFaceTexture(1);
    try std.testing.expectEqual(grass_bottom.x, 2);

    const grass_side = BlockId.grass.getFaceTexture(2);
    try std.testing.expectEqual(grass_side.x, 1);

    const stone = BlockId.stone.getFaceTexture(0);
    try std.testing.expectEqual(stone.x, 3);

    const water = BlockId.water.getFaceTexture(0);
    try std.testing.expectEqual(water.x, 0);
    try std.testing.expectEqual(water.y, 1);
}
