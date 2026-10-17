const std = @import("std");

/// The 12 wood and hyphae families that provide standing and wall signs.
pub const SignWoodSpecies = enum {
    oak,
    spruce,
    birch,
    jungle,
    acacia,
    dark_oak,
    mangrove,
    cherry,
    pale_oak,
    bamboo,
    crimson,
    warped,
};

/// Crimson and warped hyphae do not burn, including when used for signs.
pub fn isSignFireproof(species: SignWoodSpecies) bool {
    return switch (species) {
        .crimson, .warped => true,
        else => false,
    };
}

/// The crafting recipe shared by every wooden sign variant.
pub const SignRecipe = struct {
    pub const planks_required: u8 = 6;
    pub const sticks_required: u8 = 1;
    pub const signs_produced: u8 = 3;
    pub const max_stack_size: u8 = 16;

    pub fn craftSigns(planks: u8, sticks: u8) u8 {
        return if (planks >= planks_required and sticks >= sticks_required) signs_produced else 0;
    }
};

/// Convenience form of the sign recipe for callers that do not need the namespace.
pub fn craftSigns(planks: u8, sticks: u8) u8 {
    return SignRecipe.craftSigns(planks, sticks);
}

pub const WallFacing = enum {
    north,
    east,
    south,
    west,
};

/// Placement orientation for a sign. Standing signs have 16 (22.5 degree) angles.
pub const SignPlacementMode = union(enum) {
    standing_post_16_rotations: struct { rotation_0_to_15: u4 },
    wall_mounted_4_facings: WallFacing,

    pub fn standing(rotation_0_to_15: u4) SignPlacementMode {
        return .{ .standing_post_16_rotations = .{ .rotation_0_to_15 = rotation_0_to_15 } };
    }

    pub fn wall(facing: WallFacing) SignPlacementMode {
        return .{ .wall_mounted_4_facings = facing };
    }

    pub fn rotationDegrees(self: SignPlacementMode) ?f32 {
        return switch (self) {
            .standing_post_16_rotations => |standing_mode| @as(f32, standing_mode.rotation_0_to_15) * 22.5,
            .wall_mounted_4_facings => null,
        };
    }
};

/// Signs can occupy waterlogged blocks and their full block shape stops lava flow.
pub fn canWaterlogSign() bool {
    return true;
}

pub fn blocksLavaFlow() bool {
    return true;
}

/// The 16 Minecraft dye choices available for each sign face.
pub const DyeColor = enum(u4) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,

    pub const count: u8 = 16;
};

pub const SignSide = enum { front, back };
pub const max_lines: usize = 4;
pub const max_line_length: usize = 32;

/// A bounded, allocation-free line of sign text.
pub const SignLine = struct {
    bytes: [max_line_length]u8 = [_]u8{0} ** max_line_length,
    len: u8 = 0,

    pub fn set(self: *SignLine, text: []const u8) void {
        const count = @min(text.len, max_line_length);
        @memcpy(self.bytes[0..count], text[0..count]);
        self.len = @intCast(count);
    }

    pub fn get(self: *const SignLine) []const u8 {
        return self.bytes[0..self.len];
    }
};

/// One editable side of a sign: four lines, one dye color, and glow state.
pub const SignFace = struct {
    lines: [max_lines]SignLine = [_]SignLine{.{}} ** max_lines,
    dye_color: DyeColor = .black,
    is_glowing: bool = false,

    pub fn setLine(self: *SignFace, line: usize, text: []const u8) bool {
        if (line >= max_lines) return false;
        self.lines[line].set(text);
        return true;
    }

    pub fn getLine(self: *const SignFace, line: usize) []const u8 {
        if (line >= max_lines) return "";
        return self.lines[line].get();
    }
};

/// Dual-sided sign state. Waxing permanently prevents all face edits.
pub const DualSidedSignState = struct {
    front: SignFace = .{},
    back: SignFace = .{},
    is_waxed: bool = false,

    pub fn init() DualSidedSignState {
        return .{};
    }

    pub fn face(self: *DualSidedSignState, side: SignSide) *SignFace {
        return switch (side) {
            .front => &self.front,
            .back => &self.back,
        };
    }

    pub fn faceConst(self: *const DualSidedSignState, side: SignSide) *const SignFace {
        return switch (side) {
            .front => &self.front,
            .back => &self.back,
        };
    }

    pub fn setLine(self: *DualSidedSignState, side: SignSide, line: usize, text: []const u8) bool {
        if (!canEditSignFace(self.is_waxed)) return false;
        return self.face(side).setLine(line, text);
    }

    pub fn setDyeColor(self: *DualSidedSignState, side: SignSide, color: DyeColor) bool {
        if (!canEditSignFace(self.is_waxed)) return false;
        self.face(side).dye_color = color;
        return true;
    }

    pub fn applyGlowInkSac(self: *DualSidedSignState, side: SignSide) bool {
        if (!canEditSignFace(self.is_waxed)) return false;
        self.face(side).is_glowing = true;
        return true;
    }

    pub fn applyInkSac(self: *DualSidedSignState, side: SignSide) bool {
        if (!canEditSignFace(self.is_waxed)) return false;
        self.face(side).is_glowing = false;
        return true;
    }

    pub fn applyHoneycomb(self: *DualSidedSignState) bool {
        if (self.is_waxed) return false;
        self.is_waxed = true;
        return true;
    }

    pub fn isNightLegible(self: *const DualSidedSignState, side: SignSide) bool {
        return self.faceConst(side).is_glowing;
    }
};

pub fn canEditSignFace(is_waxed: bool) bool {
    return !is_waxed;
}

test "all twelve wood species are represented" {
    const species = [_]SignWoodSpecies{ .oak, .spruce, .birch, .jungle, .acacia, .dark_oak, .mangrove, .cherry, .pale_oak, .bamboo, .crimson, .warped };
    try std.testing.expectEqual(@as(usize, 12), species.len);
}

test "only crimson and warped signs are fireproof" {
    try std.testing.expect(isSignFireproof(.crimson));
    try std.testing.expect(isSignFireproof(.warped));
    try std.testing.expect(!isSignFireproof(.oak));
    try std.testing.expect(!isSignFireproof(.bamboo));
}

test "sign recipe requires six planks and one stick" {
    try std.testing.expectEqual(@as(u8, 3), craftSigns(6, 1));
    try std.testing.expectEqual(@as(u8, 3), craftSigns(64, 2));
    try std.testing.expectEqual(@as(u8, 0), craftSigns(5, 1));
    try std.testing.expectEqual(@as(u8, 0), craftSigns(6, 0));
}

test "sign recipe constants describe stack size" {
    try std.testing.expectEqual(@as(u8, 16), SignRecipe.max_stack_size);
    try std.testing.expectEqual(@as(u8, 6), SignRecipe.planks_required);
    try std.testing.expectEqual(@as(u8, 1), SignRecipe.sticks_required);
}

test "standing signs support all sixteen rotations" {
    const placement = SignPlacementMode.standing(15);
    try std.testing.expectEqual(@as(u4, 15), placement.standing_post_16_rotations.rotation_0_to_15);
    try std.testing.expectApproxEqAbs(@as(f32, 337.5), placement.rotationDegrees().?, 0.001);
}

test "wall signs support four facings" {
    const placement = SignPlacementMode.wall(.west);
    try std.testing.expectEqual(WallFacing.west, placement.wall_mounted_4_facings);
    try std.testing.expectEqual(@as(?f32, null), placement.rotationDegrees());
}

test "signs are waterloggable and stop lava flow" {
    try std.testing.expect(canWaterlogSign());
    try std.testing.expect(blocksLavaFlow());
}

test "new sign faces have four blank black lines" {
    const face = SignFace{};
    try std.testing.expectEqual(@as(usize, 4), face.lines.len);
    try std.testing.expectEqual(DyeColor.black, face.dye_color);
    try std.testing.expect(!face.is_glowing);
    try std.testing.expectEqualStrings("", face.getLine(0));
}

test "each face stores four lines independently" {
    var state = DualSidedSignState.init();
    try std.testing.expect(state.setLine(.front, 0, "front"));
    try std.testing.expect(state.setLine(.back, 0, "back"));
    try std.testing.expectEqualStrings("front", state.front.getLine(0));
    try std.testing.expectEqualStrings("back", state.back.getLine(0));
}

test "sign text is bounded and invalid lines are rejected" {
    var face = SignFace{};
    var long_text: [40]u8 = [_]u8{'x'} ** 40;
    try std.testing.expect(face.setLine(3, &long_text));
    try std.testing.expectEqual(max_line_length, face.getLine(3).len);
    try std.testing.expect(!face.setLine(4, "invalid"));
}

test "dye colors are independent per face" {
    var state = DualSidedSignState.init();
    try std.testing.expect(state.setDyeColor(.front, .red));
    try std.testing.expect(state.setDyeColor(.back, .blue));
    try std.testing.expectEqual(DyeColor.red, state.front.dye_color);
    try std.testing.expectEqual(DyeColor.blue, state.back.dye_color);
}

test "glow ink sac makes only selected face night legible" {
    var state = DualSidedSignState.init();
    try std.testing.expect(state.applyGlowInkSac(.front));
    try std.testing.expect(state.isNightLegible(.front));
    try std.testing.expect(!state.isNightLegible(.back));
    try std.testing.expect(state.applyInkSac(.front));
    try std.testing.expect(!state.isNightLegible(.front));
}

test "honeycomb wax permanently locks both faces" {
    var state = DualSidedSignState.init();
    try std.testing.expect(state.setLine(.front, 0, "locked soon"));
    try std.testing.expect(state.applyHoneycomb());
    try std.testing.expect(state.is_waxed);
    try std.testing.expect(!canEditSignFace(state.is_waxed));
    try std.testing.expect(!state.setLine(.front, 0, "changed"));
    try std.testing.expect(!state.setDyeColor(.back, .green));
    try std.testing.expect(!state.applyGlowInkSac(.back));
    try std.testing.expect(!state.applyInkSac(.front));
    try std.testing.expect(!state.applyHoneycomb());
}

test "canEditSignFace mirrors wax lock" {
    try std.testing.expect(canEditSignFace(false));
    try std.testing.expect(!canEditSignFace(true));
}
