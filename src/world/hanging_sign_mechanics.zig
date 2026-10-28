const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

// ============================================================================
// Constants
// ============================================================================

/// Number of editable text lines per sign face (4 lines).
pub const max_lines: usize = 4;

/// Maximum number of characters allowed per text line (16 characters).
pub const max_chars_per_line: usize = 16;

/// Alias for max characters per line.
pub const max_line_len: usize = max_chars_per_line;

/// Number of chains required in crafting recipe.
pub const crafting_chains_required: u32 = 2;

/// Number of stripped wood logs/blocks required in crafting recipe.
pub const crafting_wood_required: u32 = 6;

/// Number of hanging signs produced per craft batch.
pub const crafting_yield: u32 = 6;

// ============================================================================
// Enums & Types
// ============================================================================

/// Three canonical hanging sign attachment mount configurations.
pub const HangingSignMount = enum {
    /// Hanging suspended beneath a solid ceiling block or iron bars/chains with V-chains.
    ceiling_chains,
    /// Attached to the side face of a solid wall block with a horizontal wooden support beam.
    wall_bracket,
    /// Hanging directly beneath another hanging sign with straight vertical chains.
    hanging_stack,

    pub fn isCeiling(self: HangingSignMount) bool {
        return self == .ceiling_chains;
    }

    pub fn isWall(self: HangingSignMount) bool {
        return self == .wall_bracket;
    }

    pub fn isStacked(self: HangingSignMount) bool {
        return self == .hanging_stack;
    }

    pub fn description(self: HangingSignMount) []const u8 {
        return switch (self) {
            .ceiling_chains => "Ceiling Chains",
            .wall_bracket => "Wall Bracket",
            .hanging_stack => "Hanging Stack",
        };
    }
};

/// Type aliases for mount configuration.
pub const MountType = HangingSignMount;
pub const AttachmentType = HangingSignMount;

/// Chain visual link style based on mount configuration and support geometry.
pub const ChainStyle = enum {
    /// Parallel vertical chains suspended from the underside of a full solid block.
    parallel_chains,
    /// V-shaped converging chains suspended from narrow supports or full block while sneaking.
    v_chains,
    /// Straight vertical chains linking directly to the hanging sign above.
    vertical_chains,
    /// Horizontal wooden support beam with vertical chains anchored to a wall.
    wall_beam,

    pub fn isParallel(self: ChainStyle) bool {
        return self == .parallel_chains;
    }

    pub fn isVChains(self: ChainStyle) bool {
        return self == .v_chains;
    }

    pub fn isVertical(self: ChainStyle) bool {
        return self == .vertical_chains;
    }

    pub fn isWallBeam(self: ChainStyle) bool {
        return self == .wall_beam;
    }
};

/// Cardinal direction facing for wall bracket attachments.
pub const WallFacing = enum {
    north,
    south,
    east,
    west,

    pub fn opposite(self: WallFacing) WallFacing {
        return switch (self) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }

    pub fn offset(self: WallFacing) [3]i32 {
        return switch (self) {
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
        };
    }

    pub fn name(self: WallFacing) []const u8 {
        return switch (self) {
            .north => "North",
            .south => "South",
            .east => "East",
            .west => "West",
        };
    }
};

/// Support block classification for attachment validity.
pub const SupportBlockKind = enum {
    solid_block,
    iron_bars,
    chain,
    fence,
    wall,
    hanging_sign,
    air,
    non_solid,

    pub fn isSolid(self: SupportBlockKind) bool {
        return self == .solid_block;
    }

    pub fn isNarrow(self: SupportBlockKind) bool {
        return switch (self) {
            .iron_bars, .chain, .fence, .wall => true,
            else => false,
        };
    }

    pub fn isValidCeilingSupport(self: SupportBlockKind) bool {
        return self == .solid_block or self.isNarrow();
    }

    pub fn isValidWallSupport(self: SupportBlockKind) bool {
        return self == .solid_block;
    }

    pub fn isValidStackSupport(self: SupportBlockKind) bool {
        return self == .hanging_sign;
    }
};

/// Classifies a world BlockId into a SupportBlockKind.
pub fn classifyBlock(id: BlockId) SupportBlockKind {
    if (id == .hanging_sign) return .hanging_sign;
    if (id == .iron_bars) return .iron_bars;
    if (id == .chain) return .chain;
    if (id == .oak_fence or id == .nether_brick_fence) return .fence;
    if (id.is_solid()) return .solid_block;
    if (id == .air) return .air;
    return .non_solid;
}

/// The 16 canonical dye colors for sign text coloring.
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

/// Target face of sign (dual-sided).
pub const SignSide = enum {
    front,
    back,

    pub fn opposite(self: SignSide) SignSide {
        return switch (self) {
            .front => .back,
            .back => .front,
        };
    }

    pub fn name(self: SignSide) []const u8 {
        return switch (self) {
            .front => "Front",
            .back => "Back",
        };
    }
};

/// Wood species available for hanging sign crafting.
pub const WoodSpecies = enum {
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

    pub const count: usize = 12;

    pub fn isFireproof(self: WoodSpecies) bool {
        return self == .crimson or self == .warped;
    }
};

/// Errors that can occur during sign operations.
pub const SignError = error{
    SignWaxed,
    InvalidLineIndex,
    InvalidSupport,
};

// ============================================================================
// Text Line and Sign Face Structs
// ============================================================================

/// Single bounded line of text (max 16 characters).
pub const SignLine = struct {
    bytes: [max_chars_per_line]u8 = [_]u8{0} ** max_chars_per_line,
    len: u8 = 0,

    pub fn get(self: *const SignLine) []const u8 {
        return self.bytes[0..self.len];
    }

    pub fn slice(self: *const SignLine) []const u8 {
        return self.bytes[0..self.len];
    }

    /// Sets text content, clamping to max_chars_per_line (16 chars).
    pub fn set(self: *SignLine, text: []const u8) void {
        const copy_len = @min(text.len, max_chars_per_line);
        @memcpy(self.bytes[0..copy_len], text[0..copy_len]);
        self.len = @intCast(copy_len);
    }

    pub fn clear(self: *SignLine) void {
        self.len = 0;
        @memset(&self.bytes, 0);
    }
};

/// One editable face of a sign (4 lines, dye color, glowing status).
pub const SignFace = struct {
    lines: [max_lines]SignLine = [_]SignLine{.{}} ** max_lines,
    color: DyeColor = .black,
    is_glowing: bool = false,

    pub fn getLine(self: *const SignFace, line_idx: usize) []const u8 {
        if (line_idx >= max_lines) return "";
        return self.lines[line_idx].get();
    }

    pub fn setLine(self: *SignFace, line_idx: usize, text: []const u8) bool {
        if (line_idx >= max_lines) return false;
        self.lines[line_idx].set(text);
        return true;
    }

    pub fn clearLine(self: *SignFace, line_idx: usize) bool {
        if (line_idx >= max_lines) return false;
        self.lines[line_idx].clear();
        return true;
    }

    pub fn clear(self: *SignFace) void {
        for (&self.lines) |*line| {
            line.clear();
        }
    }
};

// ============================================================================
// Placement & Attachment Resolution
// ============================================================================

/// Placement context parameters for resolving mount type.
pub const PlacementContext = struct {
    /// Support block above the target hanging sign position (y + 1).
    support_above: SupportBlockKind = .air,
    /// Support block behind the wall bracket (if placing on a wall).
    wall_support: SupportBlockKind = .air,
    /// Attached wall facing (if clicking a side face of a block).
    attached_face: ?WallFacing = null,
    /// Player sneaking status (forces V-chains on solid ceiling blocks).
    is_sneaking: bool = false,
    /// Discrete rotation index (0..15) for 22.5 degree increments when ceiling-mounted.
    rotation: u4 = 0,
};

/// Resolves the HangingSignMount configuration given placement context.
pub fn resolveMountType(ctx: PlacementContext) ?HangingSignMount {
    // Wall bracket mounting takes precedence if placed against a wall face
    if (ctx.attached_face != null) {
        if (ctx.wall_support.isValidWallSupport()) {
            return .wall_bracket;
        }
        return null;
    }

    // Stacked hanging sign beneath another hanging sign
    if (ctx.support_above == .hanging_sign) {
        return .hanging_stack;
    }

    // Ceiling chains beneath solid block, iron bars, chain, or fence
    if (ctx.support_above.isValidCeilingSupport()) {
        return .ceiling_chains;
    }

    return null;
}

/// Checks if an existing hanging sign can stay attached in the world.
pub fn canStayAttached(
    mount: HangingSignMount,
    support_above: SupportBlockKind,
    wall_support: SupportBlockKind,
) bool {
    return switch (mount) {
        .ceiling_chains => support_above.isValidCeilingSupport(),
        .wall_bracket => wall_support.isValidWallSupport(),
        .hanging_stack => support_above.isValidStackSupport(),
    };
}

/// Resolves the chain rendering style based on mount type and ceiling support.
pub fn resolveChainStyle(
    mount: HangingSignMount,
    support_above: SupportBlockKind,
    is_sneaking: bool,
) ChainStyle {
    return switch (mount) {
        .ceiling_chains => {
            if (is_sneaking or support_above.isNarrow()) {
                return .v_chains;
            } else {
                return .parallel_chains;
            }
        },
        .wall_bracket => .wall_beam,
        .hanging_stack => .vertical_chains,
    };
}

/// Converts a 0..15 rotation index to degrees (0.0 to 337.5).
pub fn rotationIndexToDegrees(rotation: u4) f32 {
    return @as(f32, @floatFromInt(rotation)) * 22.5;
}

// ============================================================================
// Hanging Sign State & Mechanics
// ============================================================================

/// Dual-sided editable hanging sign state with honeycomb waxing lock and customization.
pub const HangingSign = struct {
    mount_type: HangingSignMount = .ceiling_chains,
    wall_facing: ?WallFacing = null,
    rotation: u4 = 0,
    species: WoodSpecies = .oak,
    front: SignFace = .{},
    back: SignFace = .{},
    is_waxed: bool = false,

    pub fn init(mount: HangingSignMount) HangingSign {
        return .{
            .mount_type = mount,
        };
    }

    pub fn initWithFacing(mount: HangingSignMount, facing: ?WallFacing, rotation: u4) HangingSign {
        return .{
            .mount_type = mount,
            .wall_facing = facing,
            .rotation = rotation,
        };
    }

    pub fn face(self: *HangingSign, side: SignSide) *SignFace {
        return switch (side) {
            .front => &self.front,
            .back => &self.back,
        };
    }

    pub fn faceConst(self: *const HangingSign, side: SignSide) *const SignFace {
        return switch (side) {
            .front => &self.front,
            .back => &self.back,
        };
    }

    // --- Dual-Sided Text Editing ---

    pub fn getLine(self: *const HangingSign, side: SignSide, line_idx: usize) []const u8 {
        return self.faceConst(side).getLine(line_idx);
    }

    pub fn setLine(self: *HangingSign, side: SignSide, line_idx: usize, text: []const u8) bool {
        if (self.is_waxed or line_idx >= max_lines) return false;
        return self.face(side).setLine(line_idx, text);
    }

    pub fn trySetLine(self: *HangingSign, side: SignSide, line_idx: usize, text: []const u8) SignError!void {
        if (self.is_waxed) return error.SignWaxed;
        if (line_idx >= max_lines) return error.InvalidLineIndex;
        _ = self.face(side).setLine(line_idx, text);
    }

    pub fn clearLine(self: *HangingSign, side: SignSide, line_idx: usize) bool {
        if (self.is_waxed or line_idx >= max_lines) return false;
        return self.face(side).clearLine(line_idx);
    }

    pub fn clearSide(self: *HangingSign, side: SignSide) bool {
        if (self.is_waxed) return false;
        self.face(side).clear();
        return true;
    }

    // --- Color & Dye Customization ---

    pub fn getColor(self: *const HangingSign, side: SignSide) DyeColor {
        return self.faceConst(side).color;
    }

    pub fn applyDye(self: *HangingSign, side: SignSide, dye: DyeColor) bool {
        if (self.is_waxed) return false;
        self.face(side).color = dye;
        return true;
    }

    // --- Glow Ink & Luminescence ---

    pub fn isGlowing(self: *const HangingSign, side: SignSide) bool {
        return self.faceConst(side).is_glowing;
    }

    pub fn applyGlowInkSac(self: *HangingSign, side: SignSide) bool {
        if (self.is_waxed) return false;
        self.face(side).is_glowing = true;
        return true;
    }

    pub fn applyInkSac(self: *HangingSign, side: SignSide) bool {
        if (self.is_waxed) return false;
        self.face(side).is_glowing = false;
        return true;
    }

    pub fn isFullBright(self: *const HangingSign, side: SignSide) bool {
        return self.faceConst(side).is_glowing;
    }

    // --- Honeycomb Waxing Lock ---

    pub fn applyHoneycomb(self: *HangingSign) bool {
        if (self.is_waxed) return false;
        self.is_waxed = true;
        return true;
    }

    pub fn canEdit(self: *const HangingSign) bool {
        return !self.is_waxed;
    }
};

/// Type aliases for compatibility.
pub const HangingSignState = HangingSign;
pub const DualSidedHangingSign = HangingSign;

// ============================================================================
// Crafting & Pipeline Helpers
// ============================================================================

/// Crafting result representing produced signs and remaining materials.
pub const CraftResult = struct {
    signs: u32,
    remaining_chains: u32,
    remaining_wood: u32,
};

/// Crafts hanging signs: 2 Chains + 6 Stripped Wood = 6 Hanging Signs.
pub fn craftHangingSigns(chains: u32, stripped_wood: u32) CraftResult {
    const batches = @min(chains / crafting_chains_required, stripped_wood / crafting_wood_required);
    return .{
        .signs = batches * crafting_yield,
        .remaining_chains = chains - (batches * crafting_chains_required),
        .remaining_wood = stripped_wood - (batches * crafting_wood_required),
    };
}

/// Simulates structural cascade drop down a vertical column of hanging signs.
/// Returns the number of signs that dropped when the support block breaks.
pub fn simulateCascadeDrop(
    signs: []const HangingSignMount,
    ceiling_support: SupportBlockKind,
    wall_support: SupportBlockKind,
) usize {
    var dropped_count: usize = 0;
    var upper_block = ceiling_support;

    for (signs) |mount| {
        const attached = canStayAttached(mount, upper_block, wall_support);
        if (!attached) {
            dropped_count += 1;
            upper_block = .air; // Broken sign becomes air for signs beneath it
        } else {
            upper_block = .hanging_sign; // Surviving sign continues to support stack
        }
    }

    return dropped_count;
}

// ============================================================================
// Unit Tests (Milestone 445)
// ============================================================================

test "1. Mount Type: ceiling_chains attaches beneath solid block" {
    const ctx = PlacementContext{
        .support_above = .solid_block,
        .attached_face = null,
        .wall_support = .air,
    };
    const mount = resolveMountType(ctx);
    try std.testing.expect(mount != null);
    try std.testing.expectEqual(HangingSignMount.ceiling_chains, mount.?);
    try std.testing.expect(canStayAttached(.ceiling_chains, .solid_block, .air));
}

test "2. Mount Type: ceiling_chains attaches beneath iron bars and chain" {
    const ctx_bars = PlacementContext{
        .support_above = .iron_bars,
        .attached_face = null,
    };
    try std.testing.expectEqual(HangingSignMount.ceiling_chains, resolveMountType(ctx_bars).?);
    try std.testing.expect(canStayAttached(.ceiling_chains, .iron_bars, .air));

    const ctx_chain = PlacementContext{
        .support_above = .chain,
        .attached_face = null,
    };
    try std.testing.expectEqual(HangingSignMount.ceiling_chains, resolveMountType(ctx_chain).?);
    try std.testing.expect(canStayAttached(.ceiling_chains, .chain, .air));
}

test "3. Mount Type: ceiling_chains attaches beneath fence and wall" {
    const ctx_fence = PlacementContext{
        .support_above = .fence,
        .attached_face = null,
    };
    try std.testing.expectEqual(HangingSignMount.ceiling_chains, resolveMountType(ctx_fence).?);
    try std.testing.expect(canStayAttached(.ceiling_chains, .fence, .air));

    const ctx_wall = PlacementContext{
        .support_above = .wall,
        .attached_face = null,
    };
    try std.testing.expectEqual(HangingSignMount.ceiling_chains, resolveMountType(ctx_wall).?);
    try std.testing.expect(canStayAttached(.ceiling_chains, .wall, .air));
}

test "4. Mount Type: ceiling_chains rejects air, non-solid, and hanging sign ceiling" {
    // Air above
    try std.testing.expect(!canStayAttached(.ceiling_chains, .air, .solid_block));

    // Non-solid block above
    try std.testing.expect(!canStayAttached(.ceiling_chains, .non_solid, .solid_block));

    // Hanging sign above is for hanging_stack, not ceiling_chains
    try std.testing.expect(!SupportBlockKind.hanging_sign.isValidCeilingSupport());
}

test "5. Mount Type: ceiling_chains chain style resolves to parallel without sneak, v_chains with sneak or narrow support" {
    // Solid block without sneaking -> parallel chains
    const style_parallel = resolveChainStyle(.ceiling_chains, .solid_block, false);
    try std.testing.expectEqual(ChainStyle.parallel_chains, style_parallel);
    try std.testing.expect(style_parallel.isParallel());

    // Solid block WITH sneaking -> V-chains
    const style_v_sneak = resolveChainStyle(.ceiling_chains, .solid_block, true);
    try std.testing.expectEqual(ChainStyle.v_chains, style_v_sneak);
    try std.testing.expect(style_v_sneak.isVChains());

    // Iron bars -> V-chains regardless of sneaking
    try std.testing.expectEqual(ChainStyle.v_chains, resolveChainStyle(.ceiling_chains, .iron_bars, false));
    try std.testing.expectEqual(ChainStyle.v_chains, resolveChainStyle(.ceiling_chains, .iron_bars, true));

    // Chain -> V-chains
    try std.testing.expectEqual(ChainStyle.v_chains, resolveChainStyle(.ceiling_chains, .chain, false));
}

test "6. Mount Type: wall_bracket attaches to solid wall face" {
    const ctx = PlacementContext{
        .attached_face = .north,
        .wall_support = .solid_block,
        .support_above = .air,
    };
    const mount = resolveMountType(ctx);
    try std.testing.expect(mount != null);
    try std.testing.expectEqual(HangingSignMount.wall_bracket, mount.?);
    try std.testing.expect(mount.?.isWall());
    try std.testing.expect(canStayAttached(.wall_bracket, .air, .solid_block));

    const style = resolveChainStyle(.wall_bracket, .air, false);
    try std.testing.expectEqual(ChainStyle.wall_beam, style);
    try std.testing.expect(style.isWallBeam());
}

test "7. Mount Type: wall_bracket rejects non-solid block or air wall" {
    const ctx_air = PlacementContext{
        .attached_face = .east,
        .wall_support = .air,
        .support_above = .air,
    };
    try std.testing.expect(resolveMountType(ctx_air) == null);
    try std.testing.expect(!canStayAttached(.wall_bracket, .solid_block, .air));

    const ctx_nonsolid = PlacementContext{
        .attached_face = .west,
        .wall_support = .non_solid,
        .support_above = .air,
    };
    try std.testing.expect(resolveMountType(ctx_nonsolid) == null);
    try std.testing.expect(!canStayAttached(.wall_bracket, .solid_block, .non_solid));
}

test "8. Mount Type: wall_bracket supports all 4 cardinal facings" {
    const facings = [_]WallFacing{ .north, .south, .east, .west };
    for (facings) |f| {
        const sign = HangingSign.initWithFacing(.wall_bracket, f, 0);
        try std.testing.expectEqual(HangingSignMount.wall_bracket, sign.mount_type);
        try std.testing.expectEqual(f, sign.wall_facing.?);
        try std.testing.expectEqual(f.opposite().opposite(), f);
        const off = f.offset();
        try std.testing.expect(off[0] != 0 or off[2] != 0);
    }
}

test "9. Mount Type: hanging_stack attaches directly beneath another hanging sign" {
    const ctx = PlacementContext{
        .support_above = .hanging_sign,
        .attached_face = null,
        .wall_support = .air,
    };
    const mount = resolveMountType(ctx);
    try std.testing.expect(mount != null);
    try std.testing.expectEqual(HangingSignMount.hanging_stack, mount.?);
    try std.testing.expect(mount.?.isStacked());
    try std.testing.expect(canStayAttached(.hanging_stack, .hanging_sign, .air));

    const style = resolveChainStyle(.hanging_stack, .hanging_sign, false);
    try std.testing.expectEqual(ChainStyle.vertical_chains, style);
    try std.testing.expect(style.isVertical());
}

test "10. Mount Type: hanging_stack rejects solid block, iron bars, chain, air above" {
    try std.testing.expect(!canStayAttached(.hanging_stack, .solid_block, .air));
    try std.testing.expect(!canStayAttached(.hanging_stack, .iron_bars, .air));
    try std.testing.expect(!canStayAttached(.hanging_stack, .chain, .air));
    try std.testing.expect(!canStayAttached(.hanging_stack, .air, .air));
}

test "11. Placement resolver: picks ceiling_chains, wall_bracket, or hanging_stack by context" {
    // 1. Ceiling with solid block
    const c1 = resolveMountType(.{ .support_above = .solid_block });
    try std.testing.expectEqual(HangingSignMount.ceiling_chains, c1.?);

    // 2. Wall with solid block
    const c2 = resolveMountType(.{ .attached_face = .south, .wall_support = .solid_block });
    try std.testing.expectEqual(HangingSignMount.wall_bracket, c2.?);

    // 3. Hanging underneath existing hanging sign
    const c3 = resolveMountType(.{ .support_above = .hanging_sign });
    try std.testing.expectEqual(HangingSignMount.hanging_stack, c3.?);
}

test "12. Placement resolver: returns null when neither ceiling nor wall provides valid support" {
    const c_invalid1 = resolveMountType(.{ .support_above = .air, .wall_support = .air });
    try std.testing.expect(c_invalid1 == null);

    const c_invalid2 = resolveMountType(.{ .attached_face = .north, .wall_support = .air });
    try std.testing.expect(c_invalid2 == null);
}

test "13. Structural integrity: canStayAttached checks per mount type" {
    // ceiling_chains needs valid ceiling support
    try std.testing.expect(canStayAttached(.ceiling_chains, .solid_block, .air));
    try std.testing.expect(canStayAttached(.ceiling_chains, .chain, .air));
    try std.testing.expect(!canStayAttached(.ceiling_chains, .air, .solid_block));

    // wall_bracket needs solid wall support
    try std.testing.expect(canStayAttached(.wall_bracket, .air, .solid_block));
    try std.testing.expect(!canStayAttached(.wall_bracket, .solid_block, .air));

    // hanging_stack needs hanging_sign directly above
    try std.testing.expect(canStayAttached(.hanging_stack, .hanging_sign, .air));
    try std.testing.expect(!canStayAttached(.hanging_stack, .solid_block, .solid_block));
}

test "14. Cascade drop: breaking ceiling drops ceiling sign and stacked sign underneath" {
    const column = [_]HangingSignMount{
        .ceiling_chains,
        .hanging_stack,
        .hanging_stack,
    };

    // Solid ceiling intact -> 0 drops
    const intact_drops = simulateCascadeDrop(&column, .solid_block, .air);
    try std.testing.expectEqual(@as(usize, 0), intact_drops);

    // Ceiling broken (becomes air) -> all 3 signs cascade drop
    const broken_drops = simulateCascadeDrop(&column, .air, .air);
    try std.testing.expectEqual(@as(usize, 3), broken_drops);
}

test "15. Cascade drop: wall bracket in column resists ceiling destruction and maintains support below" {
    const column = [_]HangingSignMount{
        .ceiling_chains, // Drops when ceiling broken
        .wall_bracket,   // Stays because wall support is solid!
        .hanging_stack,  // Stays because sign above (wall_bracket) survived!
    };

    // Ceiling is broken, but wall is solid
    const drops = simulateCascadeDrop(&column, .air, .solid_block);
    try std.testing.expectEqual(@as(usize, 1), drops); // Only the top ceiling_chains sign dropped
}

test "16. Text buffering: dual-sided independent 4-line editing on front and back" {
    var sign = HangingSign.init(.ceiling_chains);

    // Verify initial state is empty
    for (0..max_lines) |i| {
        try std.testing.expectEqualStrings("", sign.getLine(.front, i));
        try std.testing.expectEqualStrings("", sign.getLine(.back, i));
    }

    // Set lines on front
    try std.testing.expect(sign.setLine(.front, 0, "Welcome"));
    try std.testing.expect(sign.setLine(.front, 1, "To"));
    try std.testing.expect(sign.setLine(.front, 2, "Zigcraft"));
    try std.testing.expect(sign.setLine(.front, 3, "Outpost"));

    // Set lines on back with completely different text
    try std.testing.expect(sign.setLine(.back, 0, "Danger Ahead"));
    try std.testing.expect(sign.setLine(.back, 1, "Beware Creepers"));
    try std.testing.expect(sign.setLine(.back, 2, "Turn Around"));
    try std.testing.expect(sign.setLine(.back, 3, "No Entry"));

    // Verify front has not been overwritten by back
    try std.testing.expectEqualStrings("Welcome", sign.getLine(.front, 0));
    try std.testing.expectEqualStrings("To", sign.getLine(.front, 1));
    try std.testing.expectEqualStrings("Zigcraft", sign.getLine(.front, 2));
    try std.testing.expectEqualStrings("Outpost", sign.getLine(.front, 3));

    // Verify back
    try std.testing.expectEqualStrings("Danger Ahead", sign.getLine(.back, 0));
    try std.testing.expectEqualStrings("Beware Creepers", sign.getLine(.back, 1));
    try std.testing.expectEqualStrings("Turn Around", sign.getLine(.back, 2));
    try std.testing.expectEqualStrings("No Entry", sign.getLine(.back, 3));
}

test "17. Text buffering: line length bounds clamping to 16 characters max" {
    var sign = HangingSign.init(.wall_bracket);

    // 16 characters exactly fits
    try std.testing.expect(sign.setLine(.front, 0, "1234567890123456"));
    try std.testing.expectEqualStrings("1234567890123456", sign.getLine(.front, 0));
    try std.testing.expectEqual(@as(usize, 16), sign.getLine(.front, 0).len);

    // 25 characters gets clamped to 16 characters
    try std.testing.expect(sign.setLine(.front, 1, "abcdefghijklmnopqrstuvwxy"));
    try std.testing.expectEqualStrings("abcdefghijklmnop", sign.getLine(.front, 1));
    try std.testing.expectEqual(@as(usize, 16), sign.getLine(.front, 1).len);

    // Short text keeps exact length
    try std.testing.expect(sign.setLine(.back, 0, "Hello"));
    try std.testing.expectEqualStrings("Hello", sign.getLine(.back, 0));
    try std.testing.expectEqual(@as(usize, 5), sign.getLine(.back, 0).len);
}

test "18. Text buffering: line index bounds checking (lines 0..3 valid, line 4 invalid)" {
    var sign = HangingSign.init(.ceiling_chains);

    try std.testing.expect(sign.setLine(.front, 0, "Line 0"));
    try std.testing.expect(sign.setLine(.front, 3, "Line 3"));

    // Line 4 is out of bounds
    try std.testing.expect(!sign.setLine(.front, 4, "Line 4"));
    try std.testing.expectEqualStrings("", sign.getLine(.front, 4));

    // trySetLine error return
    try sign.trySetLine(.front, 2, "Line 2");
    try std.testing.expectError(error.InvalidLineIndex, sign.trySetLine(.front, 4, "Invalid"));
}

test "19. Text buffering: clearLine and clearSide operations" {
    var sign = HangingSign.init(.hanging_stack);
    _ = sign.setLine(.front, 0, "Alpha");
    _ = sign.setLine(.front, 1, "Beta");
    _ = sign.setLine(.back, 0, "Gamma");

    // Clear single line
    try std.testing.expect(sign.clearLine(.front, 0));
    try std.testing.expectEqualStrings("", sign.getLine(.front, 0));
    try std.testing.expectEqualStrings("Beta", sign.getLine(.front, 1));

    // Clear entire side
    try std.testing.expect(sign.clearSide(.front));
    try std.testing.expectEqualStrings("", sign.getLine(.front, 1));
    // Back remains intact
    try std.testing.expectEqualStrings("Gamma", sign.getLine(.back, 0));
}

test "20. Dye customization: standard 16 dye colors apply independently to front and back faces" {
    var sign = HangingSign.init(.ceiling_chains);

    // Initial default text color is black
    try std.testing.expectEqual(DyeColor.black, sign.getColor(.front));
    try std.testing.expectEqual(DyeColor.black, sign.getColor(.back));

    // Dye front side cyan
    try std.testing.expect(sign.applyDye(.front, .cyan));
    try std.testing.expectEqual(DyeColor.cyan, sign.getColor(.front));
    try std.testing.expectEqual(DyeColor.black, sign.getColor(.back)); // Back unchanged

    // Dye back side yellow
    try std.testing.expect(sign.applyDye(.back, .yellow));
    try std.testing.expectEqual(DyeColor.cyan, sign.getColor(.front));
    try std.testing.expectEqual(DyeColor.yellow, sign.getColor(.back));

    // Verify all 16 dye colors can be set
    const all_dyes = [_]DyeColor{
        .white, .orange, .magenta, .light_blue,
        .yellow, .lime, .pink, .gray,
        .light_gray, .cyan, .purple, .blue,
        .brown, .green, .red, .black,
    };
    try std.testing.expectEqual(@as(usize, 16), DyeColor.count);

    for (all_dyes) |dye| {
        try std.testing.expect(sign.applyDye(.front, dye));
        try std.testing.expectEqual(dye, sign.getColor(.front));
        try std.testing.expect(dye.rgbHex() > 0);
        try std.testing.expect(dye.name().len > 0);
    }
}

test "21. Glow ink sac: applies glowing full-bright status to targeted side independently" {
    var sign = HangingSign.init(.wall_bracket);

    // Initial state is not glowing
    try std.testing.expect(!sign.isGlowing(.front));
    try std.testing.expect(!sign.isGlowing(.back));
    try std.testing.expect(!sign.isFullBright(.front));

    // Apply glow ink sac to front side
    try std.testing.expect(sign.applyGlowInkSac(.front));
    try std.testing.expect(sign.isGlowing(.front));
    try std.testing.expect(sign.isFullBright(.front));
    try std.testing.expect(!sign.isGlowing(.back)); // Back remains un-glowed

    // Apply glow ink sac to back side
    try std.testing.expect(sign.applyGlowInkSac(.back));
    try std.testing.expect(sign.isGlowing(.back));
}

test "22. Ink sac: clears glowing status back to normal when not waxed" {
    var sign = HangingSign.init(.ceiling_chains);

    _ = sign.applyGlowInkSac(.front);
    try std.testing.expect(sign.isGlowing(.front));

    // Clear glow using regular ink sac
    try std.testing.expect(sign.applyInkSac(.front));
    try std.testing.expect(!sign.isGlowing(.front));
    try std.testing.expect(!sign.isFullBright(.front));
}

test "23. Honeycomb waxing: permanently locks sign and sets is_waxed = true" {
    var sign = HangingSign.init(.ceiling_chains);

    try std.testing.expect(!sign.is_waxed);
    try std.testing.expect(sign.canEdit());

    // Apply honeycomb
    try std.testing.expect(sign.applyHoneycomb());
    try std.testing.expect(sign.is_waxed);
    try std.testing.expect(!sign.canEdit());
}

test "24. Honeycomb waxing: immutability rejects subsequent front and back text edits" {
    var sign = HangingSign.init(.wall_bracket);

    _ = sign.setLine(.front, 0, "Immutable Text");
    _ = sign.setLine(.back, 0, "Locked Forever");

    // Wax the sign
    try std.testing.expect(sign.applyHoneycomb());

    // Attempts to modify text must fail
    try std.testing.expect(!sign.setLine(.front, 0, "New Front"));
    try std.testing.expect(!sign.setLine(.back, 0, "New Back"));
    try std.testing.expect(!sign.setLine(.front, 1, "Line 1"));
    try std.testing.expect(!sign.clearLine(.front, 0));
    try std.testing.expect(!sign.clearSide(.front));

    // trySetLine returns error.SignWaxed
    try std.testing.expectError(error.SignWaxed, sign.trySetLine(.front, 0, "Try Edit"));

    // Verify text is strictly preserved
    try std.testing.expectEqualStrings("Immutable Text", sign.getLine(.front, 0));
    try std.testing.expectEqualStrings("Locked Forever", sign.getLine(.back, 0));
}

test "25. Honeycomb waxing: immutability rejects subsequent dye color modification" {
    var sign = HangingSign.init(.ceiling_chains);
    _ = sign.applyDye(.front, .purple);
    _ = sign.applyDye(.back, .lime);

    // Wax the sign
    _ = sign.applyHoneycomb();

    // Attempts to dye waxed sign must fail
    try std.testing.expect(!sign.applyDye(.front, .red));
    try std.testing.expect(!sign.applyDye(.back, .blue));

    // Colors remain unchanged
    try std.testing.expectEqual(DyeColor.purple, sign.getColor(.front));
    try std.testing.expectEqual(DyeColor.lime, sign.getColor(.back));
}

test "26. Honeycomb waxing: immutability rejects subsequent glow ink sac and ink sac modification" {
    var sign = HangingSign.init(.hanging_stack);
    _ = sign.applyGlowInkSac(.front);

    // Wax the sign
    _ = sign.applyHoneycomb();

    // Cannot remove glow with ink sac
    try std.testing.expect(!sign.applyInkSac(.front));
    try std.testing.expect(sign.isGlowing(.front));

    // Cannot add glow to back
    try std.testing.expect(!sign.applyGlowInkSac(.back));
    try std.testing.expect(!sign.isGlowing(.back));
}

test "27. Honeycomb waxing: repeated honeycomb application returns false once already locked" {
    var sign = HangingSign.init(.ceiling_chains);

    try std.testing.expect(sign.applyHoneycomb());
    // Second waxing attempt returns false (already waxed)
    try std.testing.expect(!sign.applyHoneycomb());
    try std.testing.expect(!sign.applyHoneycomb());
}

test "28. Crafting recipe: 2 chains + 6 stripped wood yields 6 hanging signs with remainder tracking" {
    try std.testing.expectEqual(@as(u32, 2), crafting_chains_required);
    try std.testing.expectEqual(@as(u32, 6), crafting_wood_required);
    try std.testing.expectEqual(@as(u32, 6), crafting_yield);

    // Exact single batch
    const r1 = craftHangingSigns(2, 6);
    try std.testing.expectEqual(@as(u32, 6), r1.signs);
    try std.testing.expectEqual(@as(u32, 0), r1.remaining_chains);
    try std.testing.expectEqual(@as(u32, 0), r1.remaining_wood);

    // Multiple batches with remainder
    const r2 = craftHangingSigns(7, 20); // min(7/2=3, 20/6=3) -> 3 batches = 18 signs
    try std.testing.expectEqual(@as(u32, 18), r2.signs);
    try std.testing.expectEqual(@as(u32, 1), r2.remaining_chains); // 7 - 6 = 1
    try std.testing.expectEqual(@as(u32, 2), r2.remaining_wood);   // 20 - 18 = 2

    // Insufficient materials
    const r3 = craftHangingSigns(1, 12);
    try std.testing.expectEqual(@as(u32, 0), r3.signs);
    try std.testing.expectEqual(@as(u32, 1), r3.remaining_chains);
    try std.testing.expectEqual(@as(u32, 12), r3.remaining_wood);
}

test "29. Wood species: 12 wood species available with Nether species fireproof" {
    try std.testing.expectEqual(@as(usize, 12), WoodSpecies.count);
    try std.testing.expect(WoodSpecies.crimson.isFireproof());
    try std.testing.expect(WoodSpecies.warped.isFireproof());
    try std.testing.expect(!WoodSpecies.oak.isFireproof());
    try std.testing.expect(!WoodSpecies.cherry.isFireproof());
}

test "30. Rotation: 16 discrete angles (0..15) resolve to 22.5 degree intervals" {
    try std.testing.expectEqual(@as(f32, 0.0), rotationIndexToDegrees(0));
    try std.testing.expectEqual(@as(f32, 45.0), rotationIndexToDegrees(2));
    try std.testing.expectEqual(@as(f32, 90.0), rotationIndexToDegrees(4));
    try std.testing.expectEqual(@as(f32, 180.0), rotationIndexToDegrees(8));
    try std.testing.expectEqual(@as(f32, 270.0), rotationIndexToDegrees(12));
    try std.testing.expectEqual(@as(f32, 337.5), rotationIndexToDegrees(15));
}

test "31. BlockId integration: classifyBlock correctly maps BlockId variants to SupportBlockKind" {
    try std.testing.expectEqual(SupportBlockKind.solid_block, classifyBlock(.stone));
    try std.testing.expectEqual(SupportBlockKind.solid_block, classifyBlock(.wood));
    try std.testing.expectEqual(SupportBlockKind.iron_bars, classifyBlock(.iron_bars));
    try std.testing.expectEqual(SupportBlockKind.chain, classifyBlock(.chain));
    try std.testing.expectEqual(SupportBlockKind.fence, classifyBlock(.oak_fence));
    try std.testing.expectEqual(SupportBlockKind.hanging_sign, classifyBlock(.hanging_sign));
    try std.testing.expectEqual(SupportBlockKind.air, classifyBlock(.air));
}
