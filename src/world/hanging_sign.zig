const std = @import("std");

/// Mounting mode of a hanging sign in the world.
pub const HangingSignMountMode = enum {
    /// Hanging beneath a full, solid block with parallel chains.
    ceiling_parallel,
    /// Hanging beneath a narrow support (chain, fence, wall, sign) or full block while sneaking (V-shaped chains).
    ceiling_v_chain,
    /// Mounted to a wall block via a horizontal wooden support bracket / arm.
    wall_bracket,
};

/// Type of support provided by an adjacent block.
pub const SupportType = enum {
    full_block,
    narrow_support,
    chain,
    fence,
    narrow_post,
    hanging_sign,
    none,

    pub fn isNarrow(self: SupportType) bool {
        return switch (self) {
            .narrow_support, .chain, .fence, .narrow_post, .hanging_sign => true,
            else => false,
        };
    }

    pub fn isSolidCeiling(self: SupportType) bool {
        return self == .full_block;
    }

    pub fn isValidCeilingSupport(self: SupportType) bool {
        return self != .none;
    }
};

/// Placement context for determining mount mode.
pub const PlacementContext = struct {
    upper_solid: bool = false,
    support_type: SupportType = .none,
    is_wall: bool = false,
    is_sneaking: bool = false,
    wall_solid: bool = true,
};

/// The 16 canonical dye colors for sign text tinting.
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

    pub const count: usize = 16;

    /// 24-bit sRGB color (0xRRGGBB).
    pub fn rgbHex(self: DyeColor) u32 {
        return switch (self) {
            .white => 0xF9FFFE,
            .orange => 0xF9801D,
            .magenta => 0xC74EBD,
            .light_blue => 0x3AB3DA,
            .yellow => 0xFED83D,
            .lime => 0x80C71F,
            .pink => 0xF38BAA,
            .gray => 0x474F52,
            .light_gray => 0x9D9D97,
            .cyan => 0x169C9C,
            .purple => 0x8932B8,
            .blue => 0x3C44AA,
            .brown => 0x835432,
            .green => 0x5E7C16,
            .red => 0xB02E26,
            .black => 0x1D1D21,
        };
    }

    pub fn name(self: DyeColor) []const u8 {
        return switch (self) {
            .white => "White",
            .orange => "Orange",
            .magenta => "Magenta",
            .light_blue => "Light Blue",
            .yellow => "Yellow",
            .lime => "Lime",
            .pink => "Pink",
            .gray => "Gray",
            .light_gray => "Light Gray",
            .cyan => "Cyan",
            .purple => "Purple",
            .blue => "Blue",
            .brown => "Brown",
            .green => "Green",
            .red => "Red",
            .black => "Black",
        };
    }
};

/// Sign side selector (front or back face).
pub const SignSide = enum {
    front,
    back,
};

pub const max_lines: usize = 4;
pub const max_line_len: usize = 32;

/// A single line of text on a sign face.
pub const SignLine = struct {
    bytes: [max_line_len]u8 = [_]u8{0} ** max_line_len,
    len: u8 = 0,

    pub fn slice(self: *const SignLine) []const u8 {
        return self.bytes[0..self.len];
    }

    pub fn get(self: *const SignLine) []const u8 {
        return self.bytes[0..self.len];
    }

    pub fn set(self: *SignLine, text: []const u8) void {
        const copy_len = @min(text.len, max_line_len);
        @memcpy(self.bytes[0..copy_len], text[0..copy_len]);
        self.len = @intCast(copy_len);
    }

    pub fn clear(self: *SignLine) void {
        self.len = 0;
        @memset(&self.bytes, 0);
    }
};

pub const SignError = error{
    SignWaxed,
    InvalidLineIndex,
};

/// Dual-sided 4-line text buffer, dye color tinting, glowing ink sac toggle, and honeycomb waxing lock.
pub const HangingSignText = struct {
    front_lines: [max_lines]SignLine = [_]SignLine{.{}} ** max_lines,
    back_lines: [max_lines]SignLine = [_]SignLine{.{}} ** max_lines,
    front_color: DyeColor = .black,
    back_color: DyeColor = .black,
    is_glowing_front: bool = false,
    is_glowing_back: bool = false,
    is_waxed: bool = false,

    pub fn init() HangingSignText {
        return .{};
    }

    pub fn getLine(self: *const HangingSignText, side: SignSide, line_idx: usize) []const u8 {
        if (line_idx >= max_lines) return "";
        return switch (side) {
            .front => self.front_lines[line_idx].slice(),
            .back => self.back_lines[line_idx].slice(),
        };
    }

    pub fn setLine(self: *HangingSignText, side: SignSide, line_idx: usize, text: []const u8) bool {
        if (self.is_waxed or line_idx >= max_lines) return false;
        switch (side) {
            .front => self.front_lines[line_idx].set(text),
            .back => self.back_lines[line_idx].set(text),
        }
        return true;
    }

    pub fn trySetLine(self: *HangingSignText, side: SignSide, line_idx: usize, text: []const u8) SignError!void {
        if (self.is_waxed) return error.SignWaxed;
        if (line_idx >= max_lines) return error.InvalidLineIndex;
        switch (side) {
            .front => self.front_lines[line_idx].set(text),
            .back => self.back_lines[line_idx].set(text),
        }
    }

    pub fn getColor(self: *const HangingSignText, side: SignSide) DyeColor {
        return switch (side) {
            .front => self.front_color,
            .back => self.back_color,
        };
    }

    pub fn applyDye(self: *HangingSignText, side: SignSide, color: DyeColor) bool {
        if (self.is_waxed) return false;
        switch (side) {
            .front => self.front_color = color,
            .back => self.back_color = color,
        }
        return true;
    }

    pub fn tryApplyDye(self: *HangingSignText, side: SignSide, color: DyeColor) SignError!void {
        if (self.is_waxed) return error.SignWaxed;
        switch (side) {
            .front => self.front_color = color,
            .back => self.back_color = color,
        }
    }

    pub fn isGlowing(self: *const HangingSignText, side: SignSide) bool {
        return switch (side) {
            .front => self.is_glowing_front,
            .back => self.is_glowing_back,
        };
    }

    pub fn applyGlowInkSac(self: *HangingSignText, side: SignSide) bool {
        if (self.is_waxed) return false;
        switch (side) {
            .front => self.is_glowing_front = true,
            .back => self.is_glowing_back = true,
        }
        return true;
    }

    pub fn applyInkSac(self: *HangingSignText, side: SignSide) bool {
        if (self.is_waxed) return false;
        switch (side) {
            .front => self.is_glowing_front = false,
            .back => self.is_glowing_back = false,
        }
        return true;
    }

    pub fn applyHoneycomb(self: *HangingSignText) bool {
        if (self.is_waxed) return false;
        self.is_waxed = true;
        return true;
    }

    pub fn applyWax(self: *HangingSignText) bool {
        return self.applyHoneycomb();
    }
};

/// Standalone helper to set sign line.
pub fn setSignLine(sign: *HangingSignText, side: SignSide, line_idx: usize, text: []const u8) bool {
    return sign.setLine(side, line_idx, text);
}

/// Standalone helper to apply dye tint.
pub fn applyDyeToSign(sign: *HangingSignText, side: SignSide, color: DyeColor) bool {
    return sign.applyDye(side, color);
}

/// Standalone helper to apply glowing ink sac.
pub fn applyGlowToSign(sign: *HangingSignText, side: SignSide) bool {
    return sign.applyGlowInkSac(side);
}

/// Standalone helper to wax sign with honeycomb.
pub fn waxSign(sign: *HangingSignText) bool {
    return sign.applyHoneycomb();
}

/// Resolves mount mode based on upper neighbor solidity, support type, wall orientation, and sneak state.
pub fn resolveMountMode(upper_solid: bool, support: SupportType, is_wall: bool, is_sneaking: bool) ?HangingSignMountMode {
    if (is_wall) {
        return .wall_bracket;
    }
    if (support.isNarrow()) {
        return .ceiling_v_chain;
    }
    if (upper_solid or support == .full_block) {
        if (is_sneaking) {
            return .ceiling_v_chain;
        } else {
            return .ceiling_parallel;
        }
    }
    return null;
}

/// Resolves ceiling-specific mount mode.
pub fn resolveCeilingMountMode(support: SupportType, is_sneaking: bool) ?HangingSignMountMode {
    return resolveMountMode(support == .full_block, support, false, is_sneaking);
}

/// Determines mount mode from placement context.
pub fn determineMountMode(ctx: PlacementContext) ?HangingSignMountMode {
    if (ctx.is_wall) {
        if (!ctx.wall_solid) return null;
        return .wall_bracket;
    }
    return resolveMountMode(ctx.upper_solid, ctx.support_type, false, ctx.is_sneaking);
}

/// Checks whether a hanging sign can stay attached given its mount mode and neighbor supports.
/// For ceiling modes, ceiling support is strictly required.
/// For wall_bracket, the sign stays anchored to the horizontal wall arm regardless of ceiling status.
pub fn canStayAttached(mode: HangingSignMountMode, ceiling_support: SupportType, wall_solid: bool) bool {
    return switch (mode) {
        .ceiling_parallel => ceiling_support == .full_block,
        .ceiling_v_chain => ceiling_support == .full_block or ceiling_support.isNarrow(),
        .wall_bracket => wall_solid,
    };
}

/// Boolean overload for canStayAttached where ceiling is full block or none.
pub fn canStayAttachedSimple(mode: HangingSignMountMode, ceiling_solid: bool, wall_solid: bool) bool {
    const ceil_supp: SupportType = if (ceiling_solid) .full_block else .none;
    return canStayAttached(mode, ceil_supp, wall_solid);
}

/// A placed hanging sign instance for cascade drop evaluation.
pub const HangingSignInstance = struct {
    mode: HangingSignMountMode,
    wall_intact: bool = true,
};

/// Simulates a vertical column of hanging signs hanging one beneath the other.
/// Returns the number of signs that drop due to loss of attachment.
pub fn simulateColumnCascade(ceiling_intact: bool, signs: []const HangingSignInstance) usize {
    var dropped_count: usize = 0;
    var upper_present = ceiling_intact;
    var upper_supp: SupportType = if (ceiling_intact) .full_block else .none;

    for (signs) |sign| {
        const can_stay = canStayAttached(
            sign.mode,
            if (upper_present) upper_supp else .none,
            sign.wall_intact,
        );
        if (!can_stay) {
            dropped_count += 1;
            upper_present = false;
            upper_supp = .none;
        } else {
            upper_present = true;
            upper_supp = .hanging_sign;
        }
    }
    return dropped_count;
}

// ============================================================================
// Bamboo Crafting & Woodworking Calculations
// ============================================================================

pub const bamboo_per_bamboo_block: u32 = 9;
pub const planks_per_bamboo_block: u32 = 2;
pub const planks_per_slab_craft: u32 = 3;
pub const slabs_per_plank_craft: u32 = 6;
pub const slabs_per_bamboo_mosaic: u32 = 2;
pub const mosaic_per_stairs_craft: u32 = 6;
pub const stairs_per_mosaic_craft: u32 = 4;
pub const mosaic_per_slab_craft: u32 = 3;
pub const slabs_per_mosaic_craft: u32 = 6;
pub const planks_per_stairs_craft: u32 = 6;
pub const stairs_per_plank_craft: u32 = 4;

pub const hanging_sign_chains_required: u32 = 2;
pub const hanging_sign_wood_required: u32 = 6;
pub const hanging_signs_per_craft: u32 = 6;

pub const RemainderResult = struct {
    count: u32,
    remainder: u32,
};

/// 9 Bamboo -> 1 Block of Bamboo.
pub fn bambooToBlockOfBamboo(bamboo_count: u32) RemainderResult {
    return .{
        .count = bamboo_count / bamboo_per_bamboo_block,
        .remainder = bamboo_count % bamboo_per_bamboo_block,
    };
}

/// Stripping a Block of Bamboo using an axe (1:1 conversion).
pub fn stripBambooBlock(block_count: u32) u32 {
    return block_count;
}

/// 1 Block of Bamboo (or Stripped Block of Bamboo) -> 2 Bamboo Planks.
pub fn bambooBlockToPlanks(block_count: u32) u32 {
    return block_count * planks_per_bamboo_block;
}

/// 3 Bamboo Planks -> 6 Bamboo Slabs (crafting table recipe).
pub fn planksToBambooSlabs(planks: u32) RemainderResult {
    const batches = planks / planks_per_slab_craft;
    return .{
        .count = batches * slabs_per_plank_craft,
        .remainder = planks % planks_per_slab_craft,
    };
}

/// 2 Bamboo Slabs -> 1 Bamboo Mosaic (crafting table vertical 1x2 recipe).
pub fn slabsToBambooMosaic(slabs: u32) RemainderResult {
    return .{
        .count = slabs / slabs_per_bamboo_mosaic,
        .remainder = slabs % slabs_per_bamboo_mosaic,
    };
}

/// 1 Bamboo Plank -> 1 Bamboo Mosaic (stonecutter recipe).
pub fn stonecutterPlankToMosaic(planks: u32) u32 {
    return planks;
}

/// 6 Bamboo Mosaic -> 4 Bamboo Mosaic Stairs (crafting table recipe).
pub fn mosaicToMosaicStairs(mosaics: u32) RemainderResult {
    const batches = mosaics / mosaic_per_stairs_craft;
    return .{
        .count = batches * stairs_per_mosaic_craft,
        .remainder = mosaics % mosaic_per_stairs_craft,
    };
}

/// 1 Bamboo Mosaic -> 1 Bamboo Mosaic Stairs (stonecutter recipe).
pub fn stonecutterMosaicToStairs(mosaics: u32) u32 {
    return mosaics;
}

/// 3 Bamboo Mosaic -> 6 Bamboo Mosaic Slabs (crafting table recipe).
pub fn mosaicToMosaicSlabs(mosaics: u32) RemainderResult {
    const batches = mosaics / mosaic_per_slab_craft;
    return .{
        .count = batches * slabs_per_mosaic_craft,
        .remainder = mosaics % mosaic_per_slab_craft,
    };
}

/// 1 Bamboo Mosaic -> 2 Bamboo Mosaic Slabs (stonecutter recipe).
pub fn stonecutterMosaicToSlabs(mosaics: u32) u32 {
    return mosaics * 2;
}

/// 6 Bamboo Planks -> 4 Bamboo Stairs (crafting table recipe).
pub fn planksToBambooStairs(planks: u32) RemainderResult {
    const batches = planks / planks_per_stairs_craft;
    return .{
        .count = batches * stairs_per_plank_craft,
        .remainder = planks % planks_per_stairs_craft,
    };
}

/// 1 Bamboo Plank -> 1 Bamboo Stairs (stonecutter recipe).
pub fn stonecutterPlankToStairs(planks: u32) u32 {
    return planks;
}

/// Hanging signs recipe: 2 Chains + 6 Stripped Logs / Stripped Bamboo Blocks -> 6 Hanging Signs.
pub fn craftHangingSigns(chains: u32, stripped_wood: u32) struct {
    signs: u32,
    remaining_chains: u32,
    remaining_wood: u32,
} {
    const batches = @min(chains / hanging_sign_chains_required, stripped_wood / hanging_sign_wood_required);
    return .{
        .signs = batches * hanging_signs_per_craft,
        .remaining_chains = chains - (batches * hanging_sign_chains_required),
        .remaining_wood = stripped_wood - (batches * hanging_sign_wood_required),
    };
}

/// Comprehensive yield breakdown from raw bamboo down the entire woodworking chain.
pub const BambooPipelineYield = struct {
    raw_bamboo_used: u32,
    raw_bamboo_remainder: u32,
    bamboo_blocks: u32,
    stripped_blocks: u32,
    planks: u32,
    mosaic_blocks_stonecutter: u32,
    mosaic_blocks_crafting: u32,
    crafting_slab_remainder: u32,
    crafting_plank_remainder: u32,
};

pub fn calculateBambooPipeline(raw_bamboo: u32) BambooPipelineYield {
    const block_res = bambooToBlockOfBamboo(raw_bamboo);
    const blocks = block_res.count;
    const stripped = stripBambooBlock(blocks);
    const planks = bambooBlockToPlanks(stripped);

    // Stonecutter: 1 plank -> 1 mosaic
    const sc_mosaics = stonecutterPlankToMosaic(planks);

    // Crafting table: planks -> slabs (batches of 3 -> 6) -> mosaics (pairs of slabs -> 1)
    const slab_res = planksToBambooSlabs(planks);
    const mosaic_res = slabsToBambooMosaic(slab_res.count);

    return .{
        .raw_bamboo_used = raw_bamboo - block_res.remainder,
        .raw_bamboo_remainder = block_res.remainder,
        .bamboo_blocks = blocks,
        .stripped_blocks = stripped,
        .planks = planks,
        .mosaic_blocks_stonecutter = sc_mosaics,
        .mosaic_blocks_crafting = mosaic_res.count,
        .crafting_slab_remainder = mosaic_res.remainder,
        .crafting_plank_remainder = slab_res.remainder,
    };
}

// ============================================================================
// Unit Tests (24 comprehensive tests)
// ============================================================================

test "1. HangingSignMountMode: ceiling full block without sneaking resolves to ceiling_parallel" {
    const mode = resolveMountMode(true, .full_block, false, false);
    try std.testing.expectEqual(HangingSignMountMode.ceiling_parallel, mode.?);

    const mode2 = resolveCeilingMountMode(.full_block, false);
    try std.testing.expectEqual(HangingSignMountMode.ceiling_parallel, mode2.?);
}

test "2. HangingSignMountMode: ceiling full block with sneaking resolves to ceiling_v_chain" {
    const mode = resolveMountMode(true, .full_block, false, true);
    try std.testing.expectEqual(HangingSignMountMode.ceiling_v_chain, mode.?);

    const mode2 = resolveCeilingMountMode(.full_block, true);
    try std.testing.expectEqual(HangingSignMountMode.ceiling_v_chain, mode2.?);
}

test "3. HangingSignMountMode: narrow supports resolve to ceiling_v_chain regardless of sneak" {
    const narrow_types = [_]SupportType{ .narrow_support, .chain, .fence, .narrow_post, .hanging_sign };
    for (narrow_types) |st| {
        try std.testing.expect(st.isNarrow());
        const mode_nosneak = resolveMountMode(false, st, false, false);
        try std.testing.expectEqual(HangingSignMountMode.ceiling_v_chain, mode_nosneak.?);

        const mode_sneak = resolveMountMode(false, st, false, true);
        try std.testing.expectEqual(HangingSignMountMode.ceiling_v_chain, mode_sneak.?);
    }
}

test "4. HangingSignMountMode: side wall attachment resolves to wall_bracket" {
    const mode = resolveMountMode(false, .none, true, false);
    try std.testing.expectEqual(HangingSignMountMode.wall_bracket, mode.?);

    const mode_sneak = resolveMountMode(true, .full_block, true, true);
    try std.testing.expectEqual(HangingSignMountMode.wall_bracket, mode_sneak.?);

    const ctx = PlacementContext{ .is_wall = true, .wall_solid = true };
    try std.testing.expectEqual(HangingSignMountMode.wall_bracket, determineMountMode(ctx).?);
}

test "5. HangingSignMountMode: unsupported ceiling returns null" {
    const mode = resolveMountMode(false, .none, false, false);
    try std.testing.expectEqual(@as(?HangingSignMountMode, null), mode);

    const ctx = PlacementContext{ .upper_solid = false, .support_type = .none, .is_wall = false };
    try std.testing.expectEqual(@as(?HangingSignMountMode, null), determineMountMode(ctx));
}

test "6. HangingSignText: initial default state" {
    const text = HangingSignText.init();
    try std.testing.expect(!text.is_waxed);
    try std.testing.expect(!text.is_glowing_front);
    try std.testing.expect(!text.is_glowing_back);
    try std.testing.expectEqual(DyeColor.black, text.front_color);
    try std.testing.expectEqual(DyeColor.black, text.back_color);

    var i: usize = 0;
    while (i < max_lines) : (i += 1) {
        try std.testing.expectEqualStrings("", text.getLine(.front, i));
        try std.testing.expectEqualStrings("", text.getLine(.back, i));
    }
}

test "7. HangingSignText: dual-sided independent 4-line editing" {
    var text = HangingSignText.init();

    try std.testing.expect(text.setLine(.front, 0, "Welcome to"));
    try std.testing.expect(text.setLine(.front, 1, "Zigcraft"));
    try std.testing.expect(text.setLine(.front, 2, "1.20 Update"));
    try std.testing.expect(text.setLine(.front, 3, "Hanging Signs!"));

    try std.testing.expect(text.setLine(.back, 0, "Caution:"));
    try std.testing.expect(text.setLine(.back, 1, "Creepers Ahead"));
    try std.testing.expect(text.setLine(.back, 2, "Turn Back"));
    try std.testing.expect(text.setLine(.back, 3, "Now!"));

    try std.testing.expectEqualStrings("Welcome to", text.getLine(.front, 0));
    try std.testing.expectEqualStrings("Zigcraft", text.getLine(.front, 1));
    try std.testing.expectEqualStrings("1.20 Update", text.getLine(.front, 2));
    try std.testing.expectEqualStrings("Hanging Signs!", text.getLine(.front, 3));

    try std.testing.expectEqualStrings("Caution:", text.getLine(.back, 0));
    try std.testing.expectEqualStrings("Creepers Ahead", text.getLine(.back, 1));
    try std.testing.expectEqualStrings("Turn Back", text.getLine(.back, 2));
    try std.testing.expectEqualStrings("Now!", text.getLine(.back, 3));

    // Out of bounds check
    try std.testing.expect(!text.setLine(.front, 4, "Too Far"));
    try std.testing.expectEqualStrings("", text.getLine(.front, 4));
}

test "8. HangingSignText: 16 dye colors tinting front and back independently" {
    var text = HangingSignText.init();

    try std.testing.expectEqual(@as(usize, 16), DyeColor.count);

    // Front: cyan, Back: orange
    try std.testing.expect(text.applyDye(.front, .cyan));
    try std.testing.expect(text.applyDye(.back, .orange));

    try std.testing.expectEqual(DyeColor.cyan, text.getColor(.front));
    try std.testing.expectEqual(DyeColor.orange, text.getColor(.back));
    try std.testing.expectEqual(@as(u32, 0x169C9C), DyeColor.cyan.rgbHex());
    try std.testing.expectEqual(@as(u32, 0xF9801D), DyeColor.orange.rgbHex());
    try std.testing.expectEqualStrings("Cyan", DyeColor.cyan.name());
    try std.testing.expectEqualStrings("Orange", DyeColor.orange.name());

    // Cycle all 16 colors
    const all_colors = [_]DyeColor{
        .white,      .orange, .magenta, .light_blue,
        .yellow,     .lime,   .pink,    .gray,
        .light_gray, .cyan,   .purple,  .blue,
        .brown,      .green,  .red,     .black,
    };
    for (all_colors, 0..) |col, idx| {
        try std.testing.expectEqual(@as(u4, @intCast(idx)), @intFromEnum(col));
        try std.testing.expect(text.applyDye(.front, col));
        try std.testing.expectEqual(col, text.getColor(.front));
    }
}

test "9. HangingSignText: glowing ink sac toggle and revert" {
    var text = HangingSignText.init();

    try std.testing.expect(!text.isGlowing(.front));
    try std.testing.expect(!text.isGlowing(.back));

    try std.testing.expect(text.applyGlowInkSac(.front));
    try std.testing.expect(text.isGlowing(.front));
    try std.testing.expect(!text.isGlowing(.back));

    try std.testing.expect(text.applyGlowInkSac(.back));
    try std.testing.expect(text.isGlowing(.front));
    try std.testing.expect(text.isGlowing(.back));

    // Revert front using regular ink sac
    try std.testing.expect(text.applyInkSac(.front));
    try std.testing.expect(!text.isGlowing(.front));
    try std.testing.expect(text.isGlowing(.back));
}

test "10. HangingSignText: honeycomb waxing locks text editing" {
    var text = HangingSignText.init();
    try std.testing.expect(text.setLine(.front, 0, "Original"));

    // Apply honeycomb
    try std.testing.expect(text.applyHoneycomb());
    try std.testing.expect(text.is_waxed);

    // Subsequent wax attempts return false (already waxed)
    try std.testing.expect(!text.applyHoneycomb());
    try std.testing.expect(!text.applyWax());

    // Editing lines is rejected
    try std.testing.expect(!text.setLine(.front, 0, "Modified"));
    try std.testing.expect(!text.setLine(.back, 0, "Modified"));
    try std.testing.expectError(error.SignWaxed, text.trySetLine(.front, 0, "Modified"));

    // Original text remains intact
    try std.testing.expectEqualStrings("Original", text.getLine(.front, 0));
}

test "11. HangingSignText: waxing immutability prevents dye and glow modification" {
    var text = HangingSignText.init();
    try std.testing.expect(text.applyDye(.front, .blue));
    try std.testing.expect(text.applyHoneycomb());

    // Changing dye fails
    try std.testing.expect(!text.applyDye(.front, .red));
    try std.testing.expect(!text.applyDye(.back, .yellow));
    try std.testing.expectError(error.SignWaxed, text.tryApplyDye(.front, .red));
    try std.testing.expectEqual(DyeColor.blue, text.getColor(.front));

    // Changing glow fails
    try std.testing.expect(!text.applyGlowInkSac(.front));
    try std.testing.expect(!text.applyInkSac(.front));
    try std.testing.expect(!text.isGlowing(.front));
}

test "12. Structural support: canStayAttached for ceiling_parallel" {
    // Requires full block ceiling
    try std.testing.expect(canStayAttached(.ceiling_parallel, .full_block, false));
    try std.testing.expect(canStayAttachedSimple(.ceiling_parallel, true, false));

    // Fails with narrow support
    try std.testing.expect(!canStayAttached(.ceiling_parallel, .chain, false));
    try std.testing.expect(!canStayAttached(.ceiling_parallel, .fence, false));

    // Fails with none/air
    try std.testing.expect(!canStayAttached(.ceiling_parallel, .none, false));
    try std.testing.expect(!canStayAttachedSimple(.ceiling_parallel, false, false));
}

test "13. Structural support: canStayAttached for ceiling_v_chain" {
    // Accepts full block
    try std.testing.expect(canStayAttached(.ceiling_v_chain, .full_block, false));

    // Accepts narrow supports (chain, fence, post, hanging sign)
    try std.testing.expect(canStayAttached(.ceiling_v_chain, .chain, false));
    try std.testing.expect(canStayAttached(.ceiling_v_chain, .fence, false));
    try std.testing.expect(canStayAttached(.ceiling_v_chain, .narrow_post, false));
    try std.testing.expect(canStayAttached(.ceiling_v_chain, .hanging_sign, false));

    // Fails with none/air
    try std.testing.expect(!canStayAttached(.ceiling_v_chain, .none, false));
    try std.testing.expect(!canStayAttachedSimple(.ceiling_v_chain, false, false));
}

test "14. Structural support: wall_bracket stays anchored to wall regardless of ceiling" {
    // Wall bracket with ceiling air but solid wall -> stays attached
    try std.testing.expect(canStayAttached(.wall_bracket, .none, true));
    try std.testing.expect(canStayAttachedSimple(.wall_bracket, false, true));

    // Wall bracket with full ceiling but solid wall -> stays attached
    try std.testing.expect(canStayAttached(.wall_bracket, .full_block, true));
}

test "15. Structural support: wall_bracket drops when wall is broken" {
    // Wall bracket with broken wall -> drops even if ceiling has blocks
    try std.testing.expect(!canStayAttached(.wall_bracket, .none, false));
    try std.testing.expect(!canStayAttached(.wall_bracket, .full_block, false));
    try std.testing.expect(!canStayAttachedSimple(.wall_bracket, true, false));
}

test "16. Structural cascade drop: breaking ceiling drops entire vertical chain of ceiling signs" {
    const signs = [_]HangingSignInstance{
        .{ .mode = .ceiling_parallel },
        .{ .mode = .ceiling_v_chain },
        .{ .mode = .ceiling_v_chain },
        .{ .mode = .ceiling_v_chain },
    };

    // When ceiling is intact, 0 signs drop
    try std.testing.expectEqual(@as(usize, 0), simulateColumnCascade(true, &signs));

    // When ceiling is broken, all 4 signs drop in cascade
    try std.testing.expectEqual(@as(usize, 4), simulateColumnCascade(false, &signs));
}

test "17. Structural cascade drop: wall_bracket in column stops cascade drop" {
    const signs = [_]HangingSignInstance{
        .{ .mode = .ceiling_parallel }, // attached to ceiling block -> drops
        .{ .mode = .wall_bracket, .wall_intact = true }, // anchored to wall -> stays!
        .{ .mode = .ceiling_v_chain }, // hanging from wall bracket sign -> stays!
        .{ .mode = .ceiling_v_chain }, // hanging from sign above -> stays!
    };

    // When ceiling breaks: sign 0 drops, but sign 1 stays on wall, so signs 2 & 3 stay too!
    try std.testing.expectEqual(@as(usize, 1), simulateColumnCascade(false, &signs));
}

test "18. Bamboo crafting: 9 Bamboo -> 1 Block of Bamboo" {
    try std.testing.expectEqual(@as(u32, 9), bamboo_per_bamboo_block);

    const r0 = bambooToBlockOfBamboo(0);
    try std.testing.expectEqual(@as(u32, 0), r0.count);
    try std.testing.expectEqual(@as(u32, 0), r0.remainder);

    const r8 = bambooToBlockOfBamboo(8);
    try std.testing.expectEqual(@as(u32, 0), r8.count);
    try std.testing.expectEqual(@as(u32, 8), r8.remainder);

    const r9 = bambooToBlockOfBamboo(9);
    try std.testing.expectEqual(@as(u32, 1), r9.count);
    try std.testing.expectEqual(@as(u32, 0), r9.remainder);

    const r64 = bambooToBlockOfBamboo(64);
    try std.testing.expectEqual(@as(u32, 7), r64.count);
    try std.testing.expectEqual(@as(u32, 1), r64.remainder);
}

test "19. Bamboo woodworking: stripping Block of Bamboo is 1:1" {
    try std.testing.expectEqual(@as(u32, 0), stripBambooBlock(0));
    try std.testing.expectEqual(@as(u32, 1), stripBambooBlock(1));
    try std.testing.expectEqual(@as(u32, 64), stripBambooBlock(64));
}

test "20. Bamboo crafting: Block of Bamboo -> 2 Bamboo Planks" {
    try std.testing.expectEqual(@as(u32, 2), planks_per_bamboo_block);
    try std.testing.expectEqual(@as(u32, 0), bambooBlockToPlanks(0));
    try std.testing.expectEqual(@as(u32, 2), bambooBlockToPlanks(1));
    try std.testing.expectEqual(@as(u32, 8), bambooBlockToPlanks(4));
    try std.testing.expectEqual(@as(u32, 128), bambooBlockToPlanks(64));
}

test "21. Bamboo Mosaic crafting: planks -> slabs -> mosaic in crafting table" {
    // 3 Bamboo Planks -> 6 Bamboo Slabs
    const slabs_res = planksToBambooSlabs(6);
    try std.testing.expectEqual(@as(u32, 12), slabs_res.count);
    try std.testing.expectEqual(@as(u32, 0), slabs_res.remainder);

    // 2 Bamboo Slabs -> 1 Bamboo Mosaic
    const mosaic_res = slabsToBambooMosaic(slabs_res.count);
    try std.testing.expectEqual(@as(u32, 6), mosaic_res.count);
    try std.testing.expectEqual(@as(u32, 0), mosaic_res.remainder);

    // Remainder handling: 5 planks -> 1 batch of 6 slabs + 2 remainder planks
    const odd_slabs = planksToBambooSlabs(5);
    try std.testing.expectEqual(@as(u32, 6), odd_slabs.count);
    try std.testing.expectEqual(@as(u32, 2), odd_slabs.remainder);

    // 7 slabs -> 3 mosaics + 1 remainder slab
    const odd_mosaic = slabsToBambooMosaic(7);
    try std.testing.expectEqual(@as(u32, 3), odd_mosaic.count);
    try std.testing.expectEqual(@as(u32, 1), odd_mosaic.remainder);
}

test "22. Bamboo Mosaic woodworking: Stonecutter & Stairs/Slabs conversions" {
    // Stonecutter: 1 plank -> 1 mosaic
    try std.testing.expectEqual(@as(u32, 10), stonecutterPlankToMosaic(10));

    // Crafting table: 6 mosaics -> 4 stairs
    const stairs_craft = mosaicToMosaicStairs(14);
    try std.testing.expectEqual(@as(u32, 8), stairs_craft.count); // 2 batches of 6 -> 8
    try std.testing.expectEqual(@as(u32, 2), stairs_craft.remainder);

    // Stonecutter: 1 mosaic -> 1 stairs
    try std.testing.expectEqual(@as(u32, 14), stonecutterMosaicToStairs(14));

    // Crafting table: 3 mosaics -> 6 slabs
    const slab_craft = mosaicToMosaicSlabs(7);
    try std.testing.expectEqual(@as(u32, 12), slab_craft.count); // 2 batches of 3 -> 12
    try std.testing.expectEqual(@as(u32, 1), slab_craft.remainder);

    // Stonecutter: 1 mosaic -> 2 slabs
    try std.testing.expectEqual(@as(u32, 14), stonecutterMosaicToSlabs(7));

    // Planks to Bamboo Stairs
    const plank_stairs = planksToBambooStairs(12);
    try std.testing.expectEqual(@as(u32, 8), plank_stairs.count);
    try std.testing.expectEqual(@as(u32, 0), plank_stairs.remainder);
    try std.testing.expectEqual(@as(u32, 12), stonecutterPlankToStairs(12));
}

test "23. Hanging Signs crafting: 2 Chains + 6 Stripped Wood -> 6 Signs" {
    try std.testing.expectEqual(@as(u32, 2), hanging_sign_chains_required);
    try std.testing.expectEqual(@as(u32, 6), hanging_sign_wood_required);
    try std.testing.expectEqual(@as(u32, 6), hanging_signs_per_craft);

    // Exact craft
    const res1 = craftHangingSigns(2, 6);
    try std.testing.expectEqual(@as(u32, 6), res1.signs);
    try std.testing.expectEqual(@as(u32, 0), res1.remaining_chains);
    try std.testing.expectEqual(@as(u32, 0), res1.remaining_wood);

    // Multiple crafts with leftovers
    const res2 = craftHangingSigns(5, 14);
    try std.testing.expectEqual(@as(u32, 12), res2.signs); // 2 batches
    try std.testing.expectEqual(@as(u32, 1), res2.remaining_chains); // 5 - 4 = 1
    try std.testing.expectEqual(@as(u32, 2), res2.remaining_wood); // 14 - 12 = 2

    // Insufficient chains
    const res3 = craftHangingSigns(1, 10);
    try std.testing.expectEqual(@as(u32, 0), res3.signs);
    try std.testing.expectEqual(@as(u32, 1), res3.remaining_chains);
    try std.testing.expectEqual(@as(u32, 10), res3.remaining_wood);
}

test "24. End-to-end Bamboo woodworking pipeline" {
    // 36 raw bamboo:
    // 36 / 9 = 4 blocks of bamboo (0 remainder)
    // 4 stripped blocks
    // 4 * 2 = 8 planks
    // Stonecutter: 8 mosaics
    // Crafting table: 8 planks -> 2 batches of 3 = 6 planks -> 12 slabs (2 remainder planks)
    // 12 slabs -> 6 mosaics (0 remainder slabs)
    const yield = calculateBambooPipeline(36);
    try std.testing.expectEqual(@as(u32, 36), yield.raw_bamboo_used);
    try std.testing.expectEqual(@as(u32, 0), yield.raw_bamboo_remainder);
    try std.testing.expectEqual(@as(u32, 4), yield.bamboo_blocks);
    try std.testing.expectEqual(@as(u32, 4), yield.stripped_blocks);
    try std.testing.expectEqual(@as(u32, 8), yield.planks);
    try std.testing.expectEqual(@as(u32, 8), yield.mosaic_blocks_stonecutter);
    try std.testing.expectEqual(@as(u32, 6), yield.mosaic_blocks_crafting);
    try std.testing.expectEqual(@as(u32, 0), yield.crafting_slab_remainder);
    try std.testing.expectEqual(@as(u32, 2), yield.crafting_plank_remainder);
}
