const std = @import("std");
const block = @import("block.zig");

pub const BlockId = block.BlockId;
/// Item ids mirror the canonical inventory ids. This module is tested as a
/// standalone Zig root, which cannot import files above src/world/.
pub const ItemType = enum(u16) {
    none = 0,
    slimeball = 206,
    ochre_froglight = 386,
    verdant_froglight = 387,
    pearlescent_froglight = 388,
};

pub const acquisition_range: f32 = 8.0;
pub const tongue_reach: f32 = 2.5;
pub const predation_damage: f32 = 1.0;

pub const FrogVariant = enum {
    temperate,
    warm,
    cold,

    pub fn froglightBlock(self: FrogVariant) BlockId {
        return switch (self) {
            .temperate => .ochre_froglight,
            .warm => .pearlescent_froglight,
            .cold => .verdant_froglight,
        };
    }

    pub fn froglightItem(self: FrogVariant) ItemType {
        return switch (self) {
            .temperate => .ochre_froglight,
            .warm => .pearlescent_froglight,
            .cold => .verdant_froglight,
        };
    }

    pub fn coloration(self: FrogVariant) [3]u8 {
        return switch (self) {
            .temperate => .{ 145, 91, 55 }, // warm brown
            .warm => .{ 210, 210, 215 }, // white-gray
            .cold => .{ 76, 145, 89 }, // green
        };
    }
};

pub const Habitat = enum {
    swamp,
    mangrove_swamp,
    desert,
    jungle,
    snowy_biome,
    frozen_peaks,
    taiga,
    other,
};

pub fn nativeVariant(habitat: Habitat) ?FrogVariant {
    return switch (habitat) {
        .swamp => .temperate,
        .mangrove_swamp, .desert, .jungle => .warm,
        .snowy_biome, .frozen_peaks, .taiga => .cold,
        .other => null,
    };
}

pub const PreyKind = enum { magma_cube, slime };
pub const PreySize = enum(u8) { small = 1, medium = 2, large = 4 };

pub const Prey = struct {
    kind: PreyKind,
    size: PreySize,
    distance: f32,
};

pub fn canAcquireTarget(prey: Prey) bool {
    return prey.size == .small and std.math.isFinite(prey.distance) and
        prey.distance >= 0 and prey.distance <= acquisition_range;
}

pub const TongueStrike = struct {
    mouth_open: bool,
    tongue_extended: bool,
    tongue_length: f32,
    snapped_to_mouth: bool,
    lethal_damage: f32,
    killed: bool,
    drop_block: ?BlockId,
    drop_item: ItemType,
    drop_count: u8,
};

/// Resolves a strike at the current target distance. Acquisition can happen at
/// eight blocks, while a successful tongue snap requires the target to be within
/// the physical 2.5 block tongue reach.
pub fn tongueStrike(variant: FrogVariant, prey: Prey) TongueStrike {
    const acquired = canAcquireTarget(prey);
    const strike_succeeds = acquired and prey.distance <= tongue_reach;
    const tongue_length = if (acquired) @min(prey.distance, tongue_reach) else 0;
    if (!strike_succeeds) return .{
        .mouth_open = false,
        .tongue_extended = false,
        .tongue_length = tongue_length,
        .snapped_to_mouth = false,
        .lethal_damage = 0,
        .killed = false,
        .drop_block = null,
        .drop_item = .none,
        .drop_count = 0,
    };

    return switch (prey.kind) {
        .magma_cube => .{
            .mouth_open = true,
            .tongue_extended = true,
            .tongue_length = tongue_length,
            .snapped_to_mouth = true,
            .lethal_damage = predation_damage,
            .killed = true,
            .drop_block = variant.froglightBlock(),
            .drop_item = variant.froglightItem(),
            .drop_count = 1,
        },
        .slime => .{
            .mouth_open = true,
            .tongue_extended = true,
            .tongue_length = tongue_length,
            .snapped_to_mouth = true,
            .lethal_damage = predation_damage,
            .killed = true,
            .drop_block = null,
            .drop_item = .slimeball,
            .drop_count = 1,
        },
    };
}

pub const FroglightProperties = struct {
    light_level: u4 = 15,
    emissive_intensity: f32 = 1.0,
    hardness: f32 = 0.3,
    blast_resistance: f32 = 0.3,
};

pub fn froglightProperties(id: BlockId) ?FroglightProperties {
    return switch (id) {
        .ochre_froglight, .verdant_froglight, .pearlescent_froglight => .{},
        else => null,
    };
}

test "temperate frog has brown coloration and produces ochre froglight" {
    try std.testing.expectEqual(BlockId.ochre_froglight, FrogVariant.temperate.froglightBlock());
    try std.testing.expectEqual(ItemType.ochre_froglight, FrogVariant.temperate.froglightItem());
    try std.testing.expectEqual([3]u8{ 145, 91, 55 }, FrogVariant.temperate.coloration());
}

test "warm frog has white gray coloration and produces pearlescent froglight" {
    try std.testing.expectEqual(BlockId.pearlescent_froglight, FrogVariant.warm.froglightBlock());
    try std.testing.expectEqual(ItemType.pearlescent_froglight, FrogVariant.warm.froglightItem());
    try std.testing.expectEqual([3]u8{ 210, 210, 215 }, FrogVariant.warm.coloration());
}

test "cold frog has green coloration and produces verdant froglight" {
    try std.testing.expectEqual(BlockId.verdant_froglight, FrogVariant.cold.froglightBlock());
    try std.testing.expectEqual(ItemType.verdant_froglight, FrogVariant.cold.froglightItem());
    try std.testing.expectEqual([3]u8{ 76, 145, 89 }, FrogVariant.cold.coloration());
}

test "swamp is temperate frog habitat" {
    try std.testing.expectEqual(FrogVariant.temperate, nativeVariant(.swamp).?);
}
test "mangrove swamp is warm frog habitat" {
    try std.testing.expectEqual(FrogVariant.warm, nativeVariant(.mangrove_swamp).?);
}
test "desert is warm frog habitat" {
    try std.testing.expectEqual(FrogVariant.warm, nativeVariant(.desert).?);
}
test "jungle is warm frog habitat" {
    try std.testing.expectEqual(FrogVariant.warm, nativeVariant(.jungle).?);
}
test "snowy biome is cold frog habitat" {
    try std.testing.expectEqual(FrogVariant.cold, nativeVariant(.snowy_biome).?);
}
test "frozen peaks are cold frog habitat" {
    try std.testing.expectEqual(FrogVariant.cold, nativeVariant(.frozen_peaks).?);
}
test "taiga is cold frog habitat" {
    try std.testing.expectEqual(FrogVariant.cold, nativeVariant(.taiga).?);
}
test "other habitat has no native frog variant" {
    try std.testing.expect(nativeVariant(.other) == null);
}

test "small magma cube is targetable" {
    try std.testing.expect(canAcquireTarget(.{ .kind = .magma_cube, .size = .small, .distance = 1 }));
}
test "medium magma cube is ignored" {
    try std.testing.expect(!canAcquireTarget(.{ .kind = .magma_cube, .size = .medium, .distance = 1 }));
}
test "large magma cube is ignored" {
    try std.testing.expect(!canAcquireTarget(.{ .kind = .magma_cube, .size = .large, .distance = 1 }));
}
test "small slime is targetable" {
    try std.testing.expect(canAcquireTarget(.{ .kind = .slime, .size = .small, .distance = 1 }));
}
test "medium slime is ignored" {
    try std.testing.expect(!canAcquireTarget(.{ .kind = .slime, .size = .medium, .distance = 1 }));
}
test "large slime is ignored" {
    try std.testing.expect(!canAcquireTarget(.{ .kind = .slime, .size = .large, .distance = 1 }));
}
test "target acquisition includes exactly eight blocks" {
    try std.testing.expect(canAcquireTarget(.{ .kind = .magma_cube, .size = .small, .distance = 8 }));
}
test "target acquisition rejects beyond eight blocks" {
    try std.testing.expect(!canAcquireTarget(.{ .kind = .magma_cube, .size = .small, .distance = 8.01 }));
}
test "target acquisition rejects negative distance" {
    try std.testing.expect(!canAcquireTarget(.{ .kind = .slime, .size = .small, .distance = -0.1 }));
}
test "target acquisition rejects infinite distance" {
    try std.testing.expect(!canAcquireTarget(.{ .kind = .slime, .size = .small, .distance = std.math.inf(f32) }));
}

test "magma cube tongue strike opens mouth and snaps prey into mouth" {
    const strike = tongueStrike(.temperate, .{ .kind = .magma_cube, .size = .small, .distance = 2 });
    try std.testing.expect(strike.mouth_open and strike.tongue_extended and strike.snapped_to_mouth);
}
test "tongue reaches full two point five blocks" {
    const strike = tongueStrike(.warm, .{ .kind = .magma_cube, .size = .small, .distance = 2.5 });
    try std.testing.expectEqual(@as(f32, 2.5), strike.tongue_length);
    try std.testing.expect(strike.killed);
}
test "tongue strike kills small cube with lethal one damage" {
    const strike = tongueStrike(.cold, .{ .kind = .magma_cube, .size = .small, .distance = 1 });
    try std.testing.expectEqual(@as(f32, 1), strike.lethal_damage);
    try std.testing.expect(strike.killed);
}
test "small cube at acquisition range is not yet within tongue reach" {
    const strike = tongueStrike(.temperate, .{ .kind = .magma_cube, .size = .small, .distance = 8 });
    try std.testing.expect(!strike.killed and !strike.mouth_open);
}
test "medium cube cannot be struck" {
    const strike = tongueStrike(.warm, .{ .kind = .magma_cube, .size = .medium, .distance = 1 });
    try std.testing.expect(!strike.killed and strike.drop_count == 0);
}
test "large cube cannot be struck" {
    const strike = tongueStrike(.cold, .{ .kind = .magma_cube, .size = .large, .distance = 1 });
    try std.testing.expect(!strike.killed and strike.drop_count == 0);
}
test "temperate frog drops exactly one ochre block and item" {
    const strike = tongueStrike(.temperate, .{ .kind = .magma_cube, .size = .small, .distance = 1 });
    try std.testing.expectEqual(BlockId.ochre_froglight, strike.drop_block.?);
    try std.testing.expectEqual(ItemType.ochre_froglight, strike.drop_item);
    try std.testing.expectEqual(@as(u8, 1), strike.drop_count);
}
test "warm frog drops exactly one pearlescent block and item" {
    const strike = tongueStrike(.warm, .{ .kind = .magma_cube, .size = .small, .distance = 1 });
    try std.testing.expectEqual(BlockId.pearlescent_froglight, strike.drop_block.?);
    try std.testing.expectEqual(ItemType.pearlescent_froglight, strike.drop_item);
    try std.testing.expectEqual(@as(u8, 1), strike.drop_count);
}
test "cold frog drops exactly one verdant block and item" {
    const strike = tongueStrike(.cold, .{ .kind = .magma_cube, .size = .small, .distance = 1 });
    try std.testing.expectEqual(BlockId.verdant_froglight, strike.drop_block.?);
    try std.testing.expectEqual(ItemType.verdant_froglight, strike.drop_item);
    try std.testing.expectEqual(@as(u8, 1), strike.drop_count);
}
test "small slime is eaten for one slimeball" {
    const strike = tongueStrike(.cold, .{ .kind = .slime, .size = .small, .distance = 1 });
    try std.testing.expect(strike.killed and strike.snapped_to_mouth);
    try std.testing.expectEqual(ItemType.slimeball, strike.drop_item);
    try std.testing.expectEqual(@as(u8, 1), strike.drop_count);
    try std.testing.expect(strike.drop_block == null);
}

test "all froglights emit full light and emissive intensity" {
    const ids = [_]BlockId{ .ochre_froglight, .pearlescent_froglight, .verdant_froglight };
    for (ids) |id| {
        const props = froglightProperties(id).?;
        try std.testing.expectEqual(@as(u4, 15), props.light_level);
        try std.testing.expectEqual(@as(f32, 1), props.emissive_intensity);
    }
}
test "all froglights have hardness zero point three" {
    const ids = [_]BlockId{ .ochre_froglight, .pearlescent_froglight, .verdant_froglight };
    for (ids) |id| try std.testing.expectEqual(@as(f32, 0.3), froglightProperties(id).?.hardness);
}
test "all froglights have blast resistance zero point three" {
    const ids = [_]BlockId{ .ochre_froglight, .pearlescent_froglight, .verdant_froglight };
    for (ids) |id| try std.testing.expectEqual(@as(f32, 0.3), froglightProperties(id).?.blast_resistance);
}
test "non froglight blocks have no froglight properties" {
    try std.testing.expect(froglightProperties(.stone) == null);
}
