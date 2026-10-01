const std = @import("std");

/// A unique identifier for a block type.
/// 0 = air (treated as implicit — not stored in chunk arrays)
pub const BlockId = enum(u8) {
    air = 0,
    stone = 1,
    dirt = 2,
    grass = 3,

    pub fn is_solid(self: BlockId) bool {
        return self != .air;
    }

    pub fn is_transparent(self: BlockId) bool {
        return self == .air;
    }
};

/// Properties for a block type. Used during meshing and rendering.
pub const BlockProperties = struct {
    solid: bool,
    transparent: bool,
};

/// Lookup table for block properties.
pub fn getProperties(block: BlockId) BlockProperties {
    return switch (block) {
        .air => .{
            .solid = false,
            .transparent = true,
        },
        .stone => .{
            .solid = true,
            .transparent = false,
        },
        .dirt => .{
            .solid = true,
            .transparent = false,
        },
        .grass => .{
            .solid = true,
            .transparent = false,
        },
    };
}

test "block is_solid" {
    try std.testing.expect(!BlockId.air.is_solid());
    try std.testing.expect(BlockId.stone.is_solid());
    try std.testing.expect(BlockId.dirt.is_solid());
    try std.testing.expect(BlockId.grass.is_solid());
}

test "block is_transparent" {
    try std.testing.expect(BlockId.air.is_transparent());
    try std.testing.expect(!BlockId.stone.is_transparent());
    try std.testing.expect(!BlockId.dirt.is_transparent());
    try std.testing.expect(!BlockId.grass.is_transparent());
}

test "block properties" {
    const stone_props = getProperties(.stone);
    try std.testing.expect(stone_props.solid);
    try std.testing.expect(!stone_props.transparent);

    const air_props = getProperties(.air);
    try std.testing.expect(!air_props.solid);
    try std.testing.expect(air_props.transparent);
}

test "block count is reasonable" {
    const count = @typeInfo(BlockId).@"enum".fields.len;
    try std.testing.expect(count >= 4);
}
