const std = @import("std");

pub const MIN_BUILD_HEIGHT: i32 = -64;
pub const MAX_BUILD_HEIGHT: i32 = 319;
pub const WRONG_DIMENSION_BLAST_RADIUS: f32 = 5.0;

/// Validates the non-corner pieces of a rectangular obsidian frame and its interior.
/// Width/height refer to the opening, not the outer frame; corner blocks are optional.
pub fn validateVariableNetherPortalFrame(
    interior_width: u8,
    interior_height: u8,
    frame_obsidian_complete: bool,
    interior_all_air_or_fire: bool,
) bool {
    return interior_width >= 2 and interior_width <= 21 and
        interior_height >= 3 and interior_height <= 21 and
        frame_obsidian_complete and interior_all_air_or_fire;
}

pub const DimensionalLinkCoords = struct {
    target_x: i32,
    target_y: i32,
    target_z: i32,
    search_radius: i32,
};

/// Computes the ideal 8:1 destination coordinate and destination portal search radius.
pub fn computeDimensionalLinkCoords(
    source_x: i32,
    source_y: i32,
    source_z: i32,
    from_overworld_to_nether: bool,
) DimensionalLinkCoords {
    if (from_overworld_to_nether) {
        return .{
            .target_x = @divFloor(source_x, 8),
            .target_y = std.math.clamp(source_y, MIN_BUILD_HEIGHT, MAX_BUILD_HEIGHT),
            .target_z = @divFloor(source_z, 8),
            .search_radius = 16,
        };
    }
    return .{
        .target_x = source_x *| 8,
        .target_y = std.math.clamp(source_y, MIN_BUILD_HEIGHT, MAX_BUILD_HEIGHT),
        .target_z = source_z *| 8,
        .search_radius = 128,
    };
}

pub const RespawnAnchorState = struct {
    charges: u3 = 0,
    set_as_spawn: bool = false,

    pub fn lightLevel(self: RespawnAnchorState) u8 {
        return chargeLevel(self.charges);
    }

    pub fn comparatorSignal(self: RespawnAnchorState) u8 {
        return chargeLevel(self.charges);
    }
};

fn chargeLevel(charges: u3) u8 {
    return switch (charges) {
        0 => 0,
        1 => 3,
        2 => 7,
        3 => 11,
        4 => 15,
        else => 0,
    };
}

pub const RespawnAnchorInteraction = struct {
    added_charge: bool = false,
    consumed_respawn_charge: bool = false,
    exploded_wrong_dimension: bool = false,
    blast_radius: f32 = 0.0,
};

/// Loads Glowstone, sets a Nether spawn, or detonates a charged anchor elsewhere.
pub fn interactRespawnAnchor(
    state: *RespawnAnchorState,
    held_is_glowstone: bool,
    in_nether_dimension: bool,
) RespawnAnchorInteraction {
    if (held_is_glowstone) {
        if (state.charges < 4) {
            state.charges += 1;
            return .{ .added_charge = true };
        }
        return .{};
    }

    if (in_nether_dimension) {
        if (state.charges == 0) return .{};
        state.set_as_spawn = true;
        return .{};
    }

    if (state.charges == 0) return .{};
    state.set_as_spawn = false;
    state.charges = 0;
    return .{
        .exploded_wrong_dimension = true,
        .blast_radius = WRONG_DIMENSION_BLAST_RADIUS,
    };
}

/// Consumes exactly one charge when a player respawns at this anchor.
pub fn consumeRespawnAnchorCharge(state: *RespawnAnchorState) bool {
    if (!state.set_as_spawn or state.charges == 0) return false;
    state.charges -= 1;
    return true;
}

pub const Dimension = enum { overworld, nether, the_end };

pub fn doesBedExplodeInDimension(dimension: Dimension) bool {
    return dimension != .overworld;
}

pub fn bedExplosionRadius(dimension: Dimension) f32 {
    return if (doesBedExplodeInDimension(dimension)) WRONG_DIMENSION_BLAST_RADIUS else 0.0;
}

test "variable portal frame accepts minimum 4x5 opening frame with optional corners" {
    try std.testing.expect(validateVariableNetherPortalFrame(2, 3, true, true));
}

test "variable portal frame accepts maximum 23x23 outer dimensions" {
    try std.testing.expect(validateVariableNetherPortalFrame(21, 21, true, true));
}

test "variable portal frame accepts intermediate rectangular openings" {
    try std.testing.expect(validateVariableNetherPortalFrame(7, 13, true, true));
    try std.testing.expect(validateVariableNetherPortalFrame(21, 3, true, true));
}

test "variable portal frame rejects widths below and above bounds" {
    try std.testing.expect(!validateVariableNetherPortalFrame(1, 3, true, true));
    try std.testing.expect(!validateVariableNetherPortalFrame(22, 3, true, true));
}

test "variable portal frame rejects heights below and above bounds" {
    try std.testing.expect(!validateVariableNetherPortalFrame(2, 2, true, true));
    try std.testing.expect(!validateVariableNetherPortalFrame(2, 22, true, true));
}

test "variable portal frame requires complete obsidian edges but corners may be absent" {
    try std.testing.expect(!validateVariableNetherPortalFrame(2, 3, false, true));
    // The frame-completeness input concerns required edges; optional corners are excluded.
    try std.testing.expect(validateVariableNetherPortalFrame(2, 3, true, true));
}

test "variable portal frame interior must be air or fire" {
    try std.testing.expect(!validateVariableNetherPortalFrame(2, 3, true, false));
}

test "Overworld link floors negative coordinates and searches sixteen blocks" {
    const result = computeDimensionalLinkCoords(-9, 70, 17, true);
    try std.testing.expectEqual(@as(i32, -2), result.target_x);
    try std.testing.expectEqual(@as(i32, 70), result.target_y);
    try std.testing.expectEqual(@as(i32, 2), result.target_z);
    try std.testing.expectEqual(@as(i32, 16), result.search_radius);
}

test "Nether link multiplies coordinates by eight and searches 128 blocks" {
    const result = computeDimensionalLinkCoords(-9, 70, 17, false);
    try std.testing.expectEqual(@as(i32, -72), result.target_x);
    try std.testing.expectEqual(@as(i32, 70), result.target_y);
    try std.testing.expectEqual(@as(i32, 136), result.target_z);
    try std.testing.expectEqual(@as(i32, 128), result.search_radius);
}

test "dimensional links clamp Y to valid build height" {
    try std.testing.expectEqual(MIN_BUILD_HEIGHT, computeDimensionalLinkCoords(0, -100, 0, true).target_y);
    try std.testing.expectEqual(MAX_BUILD_HEIGHT, computeDimensionalLinkCoords(0, 500, 0, false).target_y);
}

test "Respawn Anchor charges produce matching light and comparator levels" {
    const expected = [_]u8{ 0, 3, 7, 11, 15 };
    for (expected, 0..) |level, charge| {
        const state = RespawnAnchorState{ .charges = @intCast(charge) };
        try std.testing.expectEqual(level, state.lightLevel());
        try std.testing.expectEqual(level, state.comparatorSignal());
    }
}

test "Glowstone loads at most four Respawn Anchor charges" {
    var state = RespawnAnchorState{};
    for (0..4) |_| try std.testing.expect(interactRespawnAnchor(&state, true, true).added_charge);
    try std.testing.expectEqual(@as(u3, 4), state.charges);
    try std.testing.expect(!interactRespawnAnchor(&state, true, true).added_charge);
    try std.testing.expectEqual(@as(u3, 4), state.charges);
}

test "Nether anchor sets spawn and consumes one charge on respawn" {
    var state = RespawnAnchorState{ .charges = 2 };
    _ = interactRespawnAnchor(&state, false, true);
    try std.testing.expect(state.set_as_spawn);
    try std.testing.expect(consumeRespawnAnchorCharge(&state));
    try std.testing.expectEqual(@as(u3, 1), state.charges);
}

test "unavailable anchor charge cannot be consumed for respawn" {
    var state = RespawnAnchorState{};
    try std.testing.expect(!consumeRespawnAnchorCharge(&state));
    state.charges = 1;
    try std.testing.expect(!consumeRespawnAnchorCharge(&state));
    try std.testing.expectEqual(@as(u3, 1), state.charges);
}

test "charged Overworld Respawn Anchor detonates with five radius" {
    var state = RespawnAnchorState{ .charges = 1, .set_as_spawn = true };
    const result = interactRespawnAnchor(&state, false, false);
    try std.testing.expect(result.exploded_wrong_dimension);
    try std.testing.expectEqual(WRONG_DIMENSION_BLAST_RADIUS, result.blast_radius);
    try std.testing.expectEqual(@as(u3, 0), state.charges);
    try std.testing.expect(!state.set_as_spawn);
}

test "beds explode with five radius in Nether and End only" {
    try std.testing.expect(!doesBedExplodeInDimension(.overworld));
    try std.testing.expect(doesBedExplodeInDimension(.nether));
    try std.testing.expect(doesBedExplodeInDimension(.the_end));
    try std.testing.expectEqual(@as(f32, 0.0), bedExplosionRadius(.overworld));
    try std.testing.expectEqual(WRONG_DIMENSION_BLAST_RADIUS, bedExplosionRadius(.nether));
    try std.testing.expectEqual(WRONG_DIMENSION_BLAST_RADIUS, bedExplosionRadius(.the_end));
}
