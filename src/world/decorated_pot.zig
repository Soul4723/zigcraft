const std = @import("std");

/// Standard item tags used in Decorated Pot assembly and drops.
pub const BrickTag: u16 = 328;
pub const PotterySherdTag: u16 = 369;
pub const DecoratedPotTag: u16 = 370;

/// The 18 decorative face motifs for a Decorated Pot:
/// 1 blank brick face + 17 archaeological pottery sherd designs.
pub const PotFaceMotif = enum(u8) {
    brick_blank = 0,
    angler = 1,
    archer = 2,
    arms_up = 3,
    blade = 4,
    brewer = 5,
    burn = 6,
    danger = 7,
    explorer = 8,
    friend = 9,
    heart = 10,
    howl = 11,
    miner = 12,
    mourner = 13,
    plenty = 14,
    prize = 15,
    skull = 16,
    snort = 17,

    pub fn isSherd(self: PotFaceMotif) bool {
        return self != .brick_blank;
    }

    pub fn name(self: PotFaceMotif) []const u8 {
        return switch (self) {
            .brick_blank => "Brick",
            .angler => "Angler Pottery Sherd",
            .archer => "Archer Pottery Sherd",
            .arms_up => "Arms Up Pottery Sherd",
            .blade => "Blade Pottery Sherd",
            .brewer => "Brewer Pottery Sherd",
            .burn => "Burn Pottery Sherd",
            .danger => "Danger Pottery Sherd",
            .explorer => "Explorer Pottery Sherd",
            .friend => "Friend Pottery Sherd",
            .heart => "Heart Pottery Sherd",
            .howl => "Howl Pottery Sherd",
            .miner => "Miner Pottery Sherd",
            .mourner => "Mourner Pottery Sherd",
            .plenty => "Plenty Pottery Sherd",
            .prize => "Prize Pottery Sherd",
            .skull => "Skull Pottery Sherd",
            .snort => "Snort Pottery Sherd",
        };
    }

    pub fn dropItemTag(self: PotFaceMotif) u16 {
        return if (self == .brick_blank) BrickTag else PotterySherdTag;
    }
};

/// The 4 cardinal faces of a decorated pot block.
pub const CardinalFace = enum(u2) {
    north = 0,
    east = 1,
    south = 2,
    west = 3,
};

/// 4-slot diamond crafting pattern representation.
/// In standard crafting tables:
/// - top (back) -> North face
/// - left -> West face
/// - right -> East face
/// - bottom (front) -> South face
pub const DiamondCraftingPattern = struct {
    top: PotFaceMotif = .brick_blank,
    left: PotFaceMotif = .brick_blank,
    right: PotFaceMotif = .brick_blank,
    bottom: PotFaceMotif = .brick_blank,
};

/// Wobble animation state when interacting with a decorated pot.
pub const WobbleState = enum(u8) {
    none = 0,
    positive_wobble = 1,
    negative_wobble = 2,
};

pub const max_wobble_ticks: u8 = 10;
pub const wobble_duration_seconds: f32 = 0.5;

/// Drop item representation for shattered or broken pots.
pub const PotDrop = struct {
    item_id: u16,
    count: u8,
    motif: PotFaceMotif = .brick_blank,
};

pub const max_harvest_drops: usize = 5;

pub const WithdrawnItem = struct {
    item_id: u16,
    count: u8,
};


pub const HarvestOutcome = struct {
    shattered: bool,
    drops: [max_harvest_drops]PotDrop = [_]PotDrop{.{ .item_id = 0, .count = 0 }} ** max_harvest_drops,
    drop_count: usize = 0,
    intact_pot: ?DecoratedPot = null,

    pub fn getDrops(self: *const HarvestOutcome) []const PotDrop {
        return self.drops[0..self.drop_count];
    }
};

pub const ToolKind = enum {
    pickaxe,
    sword,
    axe,
    shovel,
    hoe,
    bare_hand,
};

pub const ProjectileKind = enum {
    arrow,
    wind_charge,
    trident,
    snowball,
    egg,
    fireball,
    firework_rocket,
};

pub fn isShatterTool(tool: ToolKind) bool {
    return switch (tool) {
        .pickaxe, .sword, .axe => true,
        .shovel, .hoe, .bare_hand => false,
    };
}

pub fn isShatterProjectile(proj: ProjectileKind) bool {
    return switch (proj) {
        .arrow, .wind_charge, .trident, .snowball, .egg, .fireball, .firework_rocket => true,
    };
}

pub const DecoratedPot = struct {
    /// 4 cardinal face motifs [north, east, south, west].
    faces: [4]PotFaceMotif = [_]PotFaceMotif{.brick_blank} ** 4,

    /// Single-stack internal inventory.
    item_id: u16 = 0,
    count: u8 = 0,
    max_stack: u8 = 64,

    /// Wobble animation state and timers.
    wobble_state: WobbleState = .none,
    wobble_ticks: u8 = 0,
    wobble_timer: f32 = 0.0,

    pub fn init() DecoratedPot {
        return .{};
    }

    pub fn initFaces(north_motif: PotFaceMotif, east_motif: PotFaceMotif, south_motif: PotFaceMotif, west_motif: PotFaceMotif) DecoratedPot {
        var pot = DecoratedPot{};
        pot.setFace(.north, north_motif);
        pot.setFace(.east, east_motif);
        pot.setFace(.south, south_motif);
        pot.setFace(.west, west_motif);
        return pot;
    }

    pub fn initDiamond(top: PotFaceMotif, left: PotFaceMotif, right: PotFaceMotif, bottom: PotFaceMotif) DecoratedPot {
        return assembleDiamond(top, left, right, bottom);
    }

    pub fn getFace(self: DecoratedPot, face: CardinalFace) PotFaceMotif {
        return self.faces[@intFromEnum(face)];
    }

    pub fn setFace(self: *DecoratedPot, face: CardinalFace, motif: PotFaceMotif) void {
        self.faces[@intFromEnum(face)] = motif;
    }

    pub fn north(self: DecoratedPot) PotFaceMotif {
        return self.getFace(.north);
    }

    pub fn east(self: DecoratedPot) PotFaceMotif {
        return self.getFace(.east);
    }

    pub fn south(self: DecoratedPot) PotFaceMotif {
        return self.getFace(.south);
    }

    pub fn west(self: DecoratedPot) PotFaceMotif {
        return self.getFace(.west);
    }

    pub fn countSherds(self: DecoratedPot) u8 {
        var cnt: u8 = 0;
        for (self.faces) |f| {
            if (f != .brick_blank) cnt += 1;
        }
        return cnt;
    }

    pub fn countBricks(self: DecoratedPot) u8 {
        var cnt: u8 = 0;
        for (self.faces) |f| {
            if (f == .brick_blank) cnt += 1;
        }
        return cnt;
    }

    pub fn isAllBricks(self: DecoratedPot) bool {
        for (self.faces) |f| {
            if (f != .brick_blank) return false;
        }
        return true;
    }

    pub fn isEmpty(self: DecoratedPot) bool {
        return self.count == 0;
    }

    pub fn isFull(self: DecoratedPot) bool {
        return self.count >= self.max_stack and self.max_stack > 0;
    }

    pub fn clearInventory(self: *DecoratedPot) void {
        self.item_id = 0;
        self.count = 0;
        self.max_stack = 64;
    }

    /// Triggers a wobble animation state, resetting the duration timers.
    pub fn triggerWobble(self: *DecoratedPot, state: WobbleState) void {
        self.wobble_state = state;
        if (state == .none) {
            self.wobble_ticks = 0;
            self.wobble_timer = 0.0;
        } else {
            self.wobble_ticks = max_wobble_ticks;
            self.wobble_timer = wobble_duration_seconds;
        }
    }

    /// Ticks the wobble animation (called each game tick).
    pub fn tick(self: *DecoratedPot) void {
        if (self.wobble_ticks > 0) {
            self.wobble_ticks -= 1;
            if (self.wobble_ticks == 0) {
                self.wobble_state = .none;
                self.wobble_timer = 0.0;
            }
        }
    }

    /// Updates the wobble animation by delta-time in seconds.
    pub fn updateAnimation(self: *DecoratedPot, dt: f32) void {
        if (self.wobble_timer > 0.0) {
            self.wobble_timer -= dt;
            if (self.wobble_timer <= 0.0) {
                self.wobble_timer = 0.0;
                self.wobble_ticks = 0;
                self.wobble_state = .none;
            } else {
                const fraction = self.wobble_timer / wobble_duration_seconds;
                const remaining: u8 = @intFromFloat(@ceil(fraction * @as(f32, @floatFromInt(max_wobble_ticks))));
                self.wobble_ticks = @min(max_wobble_ticks, remaining);
            }
        }
    }

    /// Calculates a visual wobble angle (in degrees) for rendering.
    pub fn getWobbleAngle(self: DecoratedPot) f32 {
        if (self.wobble_state == .none or self.wobble_timer <= 0.0) {
            return 0.0;
        }
        const progress = 1.0 - (self.wobble_timer / wobble_duration_seconds);
        const decay = 1.0 - progress;
        const amplitude: f32 = if (self.wobble_state == .positive_wobble) 6.0 else 3.0;
        const freq: f32 = if (self.wobble_state == .positive_wobble) 4.0 else 8.0;
        return amplitude * decay * @sin(progress * freq * std.math.pi);
    }

    /// Attempts to insert items into this decorated pot's single-stack storage.
    /// Returns the number of items successfully accepted.
    /// Triggers positive_wobble on success (>0 accepted), or negative_wobble on failure.
    pub fn insertItem(self: *DecoratedPot, new_item_id: u16, new_count: u8, item_max_stack: u8) u8 {
        if (new_item_id == 0 or new_count == 0 or item_max_stack == 0) {
            self.triggerWobble(.negative_wobble);
            return 0;
        }

        const effective_max = @min(@min(item_max_stack, 64), 64);
        if (effective_max == 0) {
            self.triggerWobble(.negative_wobble);
            return 0;
        }

        if (self.count == 0) {
            // Pot is empty: accept new item up to effective_max
            const accepted = @min(effective_max, new_count);
            if (accepted > 0) {
                self.item_id = new_item_id;
                self.count = accepted;
                self.max_stack = effective_max;
                self.triggerWobble(.positive_wobble);
                return accepted;
            } else {
                self.triggerWobble(.negative_wobble);
                return 0;
            }
        } else {
            // Pot already has an item: only accept if same item_id and space remains
            if (self.item_id != new_item_id or self.count >= self.max_stack) {
                self.triggerWobble(.negative_wobble);
                return 0;
            }

            const space = self.max_stack - self.count;
            const accepted = @min(space, new_count);
            if (accepted > 0) {
                self.count += accepted;
                self.triggerWobble(.positive_wobble);
                return accepted;
            } else {
                self.triggerWobble(.negative_wobble);
                return 0;
            }
        }
    }

    /// Convenience helper to insert 1 item with default max stack 64.
    pub fn insertSingle(self: *DecoratedPot, new_item_id: u16) bool {
        return self.insertItem(new_item_id, 1, 64) == 1;
    }

    /// Withdraws up to `amount` items from the single-stack storage.
    pub fn withdraw(self: *DecoratedPot, amount: u8) WithdrawnItem {
        if (self.count == 0 or amount == 0) {
            return .{ .item_id = 0, .count = 0 };
        }
        const taken = @min(self.count, amount);
        const id = self.item_id;
        self.count -= taken;
        if (self.count == 0) {
            self.item_id = 0;
            self.max_stack = 64;
        }
        return .{ .item_id = id, .count = taken };
    }

    /// Takes all items from the pot, emptying it.
    pub fn takeAll(self: *DecoratedPot) WithdrawnItem {
        return self.withdraw(self.count);
    }

    /// Evaluates container fullness to comparator signal strength (0..15).
    /// Empty = 0, full = 15, non-empty partial = 1 + floor(14 * fullness).
    pub fn comparatorSignal(self: DecoratedPot) u8 {
        if (self.count == 0 or self.max_stack == 0) return 0;
        if (self.count >= self.max_stack) return 15;
        const fraction = @as(f32, @floatFromInt(self.count)) / @as(f32, @floatFromInt(self.max_stack));
        const signal: u8 = @intFromFloat(@floor(1.0 + fraction * 14.0));
        return @min(15, signal);
    }

    /// Resolves block harvest drops:
    /// - When shattered by a tool/projectile (`broken_by_projectile_or_tool == true`):
    ///   shatters into its 4 constituent bricks/sherds + drops stored items.
    /// - When broken with bare hand or silk touch (`broken_by_projectile_or_tool == false`):
    ///   drops the intact DecoratedPot item preserving its 4 face motifs.
    pub fn resolveHarvestOutcome(self: DecoratedPot, broken_by_projectile_or_tool: bool) HarvestOutcome {
        var outcome = HarvestOutcome{
            .shattered = broken_by_projectile_or_tool,
        };

        if (broken_by_projectile_or_tool) {
            outcome.intact_pot = null;
            // 4 constituent bricks / sherds
            for (self.faces, 0..) |motif, i| {
                outcome.drops[i] = .{
                    .item_id = motif.dropItemTag(),
                    .count = 1,
                    .motif = motif,
                };
            }
            outcome.drop_count = 4;

            // Plus stored item stack if non-empty
            if (self.count > 0 and self.item_id != 0) {
                outcome.drops[4] = .{
                    .item_id = self.item_id,
                    .count = self.count,
                    .motif = .brick_blank,
                };
                outcome.drop_count = 5;
            }
        } else {
            // Bare hand or silk touch drops intact pot item preserving its 4 face motifs
            outcome.intact_pot = self;
            outcome.drops[0] = .{
                .item_id = DecoratedPotTag,
                .count = 1,
                .motif = .brick_blank,
            };
            outcome.drop_count = 1;
        }

        return outcome;
    }

    /// Resolves harvest outcome when hit with a specific tool and silk touch flag.
    pub fn resolveToolBreak(self: DecoratedPot, tool: ToolKind, silk_touch: bool) HarvestOutcome {
        if (silk_touch) {
            return self.resolveHarvestOutcome(false);
        }
        return self.resolveHarvestOutcome(isShatterTool(tool));
    }

    /// Resolves harvest outcome when hit by a projectile.
    pub fn resolveProjectileHit(self: DecoratedPot, proj: ProjectileKind) HarvestOutcome {
        return self.resolveHarvestOutcome(isShatterProjectile(proj));
    }
};

/// Assembles a DecoratedPot from a 4-slot diamond crafting pattern.
/// - top (back) -> North face
/// - left -> West face
/// - right -> East face
/// - bottom (front) -> South face
pub fn assembleFromDiamondPattern(pattern: DiamondCraftingPattern) DecoratedPot {
    var pot = DecoratedPot{};
    pot.setFace(.north, pattern.top);
    pot.setFace(.west, pattern.left);
    pot.setFace(.east, pattern.right);
    pot.setFace(.south, pattern.bottom);
    return pot;
}

pub fn assembleDiamond(top: PotFaceMotif, left: PotFaceMotif, right: PotFaceMotif, bottom: PotFaceMotif) DecoratedPot {
    return assembleFromDiamondPattern(.{
        .top = top,
        .left = left,
        .right = right,
        .bottom = bottom,
    });
}

pub fn assembleFaces(north_motif: PotFaceMotif, east_motif: PotFaceMotif, south_motif: PotFaceMotif, west_motif: PotFaceMotif) DecoratedPot {
    return DecoratedPot.initFaces(north_motif, east_motif, south_motif, west_motif);
}

pub fn assembleAllBricks() DecoratedPot {
    return assembleFaces(.brick_blank, .brick_blank, .brick_blank, .brick_blank);
}

/// Parses a 3x3 crafting grid containing a diamond pattern into a DecoratedPot.
/// In a 3x3 grid (indices 0..8):
/// [0] [1: top]    [2]
/// [3: left] [4]   [5: right]
/// [6] [7: bottom] [8]
pub fn craftFrom3x3Grid(grid: [9]?PotFaceMotif) ?DecoratedPot {
    if (grid[0] != null or grid[2] != null or grid[4] != null or grid[6] != null or grid[8] != null) {
        return null;
    }
    const top = grid[1] orelse return null;
    const left = grid[3] orelse return null;
    const right = grid[5] orelse return null;
    const bottom = grid[7] orelse return null;
    return assembleDiamond(top, left, right, bottom);
}

/// Free-function wrapper for resolving harvest outcome.
pub fn resolveHarvestOutcome(pot: DecoratedPot, broken_by_projectile_or_tool: bool) HarvestOutcome {
    return pot.resolveHarvestOutcome(broken_by_projectile_or_tool);
}

// ============================================================================
// UNIT TESTS
// ============================================================================

test "1: PotFaceMotif all 18 variants, names, isSherd, and drop tags" {
    const motifs = [_]PotFaceMotif{
        .brick_blank,
        .angler,
        .archer,
        .arms_up,
        .blade,
        .brewer,
        .burn,
        .danger,
        .explorer,
        .friend,
        .heart,
        .howl,
        .miner,
        .mourner,
        .plenty,
        .prize,
        .skull,
        .snort,
    };
    try std.testing.expectEqual(@as(usize, 18), motifs.len);

    try std.testing.expect(!PotFaceMotif.brick_blank.isSherd());
    try std.testing.expectEqual(BrickTag, PotFaceMotif.brick_blank.dropItemTag());
    try std.testing.expectEqualStrings("Brick", PotFaceMotif.brick_blank.name());

    for (motifs[1..]) |m| {
        try std.testing.expect(m.isSherd());
        try std.testing.expectEqual(PotterySherdTag, m.dropItemTag());
        try std.testing.expect(m.name().len > 0);
    }
}

test "2: DecoratedPot 4-face cardinal direction assembly and getters/setters" {
    var pot = DecoratedPot.initFaces(.angler, .archer, .mourner, .snort);
    try std.testing.expectEqual(PotFaceMotif.angler, pot.north());
    try std.testing.expectEqual(PotFaceMotif.archer, pot.east());
    try std.testing.expectEqual(PotFaceMotif.mourner, pot.south());
    try std.testing.expectEqual(PotFaceMotif.snort, pot.west());

    pot.setFace(.north, .skull);
    pot.setFace(.east, .prize);
    try std.testing.expectEqual(PotFaceMotif.skull, pot.getFace(.north));
    try std.testing.expectEqual(PotFaceMotif.prize, pot.getFace(.east));
    try std.testing.expectEqual(@as(u8, 4), pot.countSherds());
    try std.testing.expectEqual(@as(u8, 0), pot.countBricks());
    try std.testing.expect(!pot.isAllBricks());
}

test "3: Diamond crafting pattern maps top/left/right/bottom to cardinal faces" {
    // In diamond crafting:
    // top -> north (back)
    // left -> west (left)
    // right -> east (right)
    // bottom -> south (front)
    const pot = assembleDiamond(.howl, .blade, .heart, .friend);
    try std.testing.expectEqual(PotFaceMotif.howl, pot.north());
    try std.testing.expectEqual(PotFaceMotif.heart, pot.east());
    try std.testing.expectEqual(PotFaceMotif.friend, pot.south());
    try std.testing.expectEqual(PotFaceMotif.blade, pot.west());
}

test "4: Diamond assembly with mixed sherds and bricks" {
    const pot = assembleDiamond(.brick_blank, .archer, .brick_blank, .miner);
    try std.testing.expectEqual(PotFaceMotif.brick_blank, pot.north());
    try std.testing.expectEqual(PotFaceMotif.brick_blank, pot.east());
    try std.testing.expectEqual(PotFaceMotif.miner, pot.south());
    try std.testing.expectEqual(PotFaceMotif.archer, pot.west());

    try std.testing.expectEqual(@as(u8, 2), pot.countSherds());
    try std.testing.expectEqual(@as(u8, 2), pot.countBricks());
    try std.testing.expect(!pot.isAllBricks());

    const all_brick = assembleAllBricks();
    try std.testing.expectEqual(@as(u8, 0), all_brick.countSherds());
    try std.testing.expectEqual(@as(u8, 4), all_brick.countBricks());
    try std.testing.expect(all_brick.isAllBricks());
}

test "5: 3x3 crafting grid diamond pattern assembly and rejection of invalid slots" {
    // Valid diamond in 3x3 grid
    var grid: [9]?PotFaceMotif = [_]?PotFaceMotif{null} ** 9;
    grid[1] = .danger;
    grid[3] = .explorer;
    grid[5] = .plenty;
    grid[7] = .brewer;

    const pot = craftFrom3x3Grid(grid).?;
    try std.testing.expectEqual(PotFaceMotif.danger, pot.north());
    try std.testing.expectEqual(PotFaceMotif.explorer, pot.west());
    try std.testing.expectEqual(PotFaceMotif.plenty, pot.east());
    try std.testing.expectEqual(PotFaceMotif.brewer, pot.south());

    // Corner filled should reject
    grid[0] = .brick_blank;
    try std.testing.expect(craftFrom3x3Grid(grid) == null);

    // Center filled should reject
    grid[0] = null;
    grid[4] = .burn;
    try std.testing.expect(craftFrom3x3Grid(grid) == null);
}

test "6: Single-stack insertion into empty pot triggers positive wobble" {
    var pot = DecoratedPot.init();
    try std.testing.expect(pot.isEmpty());
    try std.testing.expectEqual(@as(u16, 0), pot.item_id);
    try std.testing.expectEqual(@as(u8, 0), pot.count);
    try std.testing.expectEqual(WobbleState.none, pot.wobble_state);

    const diamond_tag: u16 = 217;
    const accepted = pot.insertItem(diamond_tag, 10, 64);
    try std.testing.expectEqual(@as(u8, 10), accepted);
    try std.testing.expectEqual(diamond_tag, pot.item_id);
    try std.testing.expectEqual(@as(u8, 10), pot.count);
    try std.testing.expectEqual(@as(u8, 64), pot.max_stack);
    try std.testing.expectEqual(WobbleState.positive_wobble, pot.wobble_state);
    try std.testing.expectEqual(max_wobble_ticks, pot.wobble_ticks);
}

test "7: Single-stack insertion accumulates same item up to max_stack" {
    var pot = DecoratedPot.init();
    const iron_tag: u16 = 265;
    _ = pot.insertItem(iron_tag, 40, 64);
    try std.testing.expectEqual(@as(u8, 40), pot.count);

    // Add 20 more of the same item
    const added1 = pot.insertItem(iron_tag, 20, 64);
    try std.testing.expectEqual(@as(u8, 20), added1);
    try std.testing.expectEqual(@as(u8, 60), pot.count);
    try std.testing.expectEqual(WobbleState.positive_wobble, pot.wobble_state);

    // Add 10 more, but only 4 space remaining
    const added2 = pot.insertItem(iron_tag, 10, 64);
    try std.testing.expectEqual(@as(u8, 4), added2);
    try std.testing.expectEqual(@as(u8, 64), pot.count);
    try std.testing.expect(pot.isFull());
    try std.testing.expectEqual(WobbleState.positive_wobble, pot.wobble_state);
}

test "8: Single-stack insertion rejection when full triggers negative wobble" {
    var pot = DecoratedPot.init();
    const gold_tag: u16 = 266;
    _ = pot.insertItem(gold_tag, 64, 64);
    try std.testing.expect(pot.isFull());

    // Clear wobble to test subsequent failure
    pot.wobble_state = .none;

    const accepted = pot.insertItem(gold_tag, 5, 64);
    try std.testing.expectEqual(@as(u8, 0), accepted);
    try std.testing.expectEqual(@as(u8, 64), pot.count);
    try std.testing.expectEqual(WobbleState.negative_wobble, pot.wobble_state);
}

test "9: Single-stack insertion rejection for mismatched item type triggers negative wobble" {
    var pot = DecoratedPot.init();
    const diamond_tag: u16 = 217;
    const emerald_tag: u16 = 273;

    _ = pot.insertItem(diamond_tag, 5, 64);
    try std.testing.expectEqual(@as(u8, 5), pot.count);

    // Try inserting emerald into pot containing diamond
    const accepted = pot.insertItem(emerald_tag, 1, 64);
    try std.testing.expectEqual(@as(u8, 0), accepted);
    try std.testing.expectEqual(diamond_tag, pot.item_id);
    try std.testing.expectEqual(@as(u8, 5), pot.count);
    try std.testing.expectEqual(WobbleState.negative_wobble, pot.wobble_state);
}

test "10: Single-stack insertion boundary conditions (zero count, zero item_id, zero max_stack)" {
    var pot = DecoratedPot.init();

    // Zero count
    try std.testing.expectEqual(@as(u8, 0), pot.insertItem(10, 0, 64));
    try std.testing.expectEqual(WobbleState.negative_wobble, pot.wobble_state);

    // Zero item_id
    try std.testing.expectEqual(@as(u8, 0), pot.insertItem(0, 5, 64));
    try std.testing.expectEqual(WobbleState.negative_wobble, pot.wobble_state);

    // Zero max_stack
    try std.testing.expectEqual(@as(u8, 0), pot.insertItem(10, 5, 0));
    try std.testing.expectEqual(WobbleState.negative_wobble, pot.wobble_state);
}

test "11: Wobble animation tick countdown and transition to none" {
    var pot = DecoratedPot.init();
    pot.triggerWobble(.positive_wobble);
    try std.testing.expectEqual(WobbleState.positive_wobble, pot.wobble_state);
    try std.testing.expectEqual(max_wobble_ticks, pot.wobble_ticks);

    // Tick down 5 ticks
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        pot.tick();
    }
    try std.testing.expectEqual(@as(u8, 5), pot.wobble_ticks);
    try std.testing.expectEqual(WobbleState.positive_wobble, pot.wobble_state);

    // Tick down remaining 5 ticks
    i = 0;
    while (i < 5) : (i += 1) {
        pot.tick();
    }
    try std.testing.expectEqual(@as(u8, 0), pot.wobble_ticks);
    try std.testing.expectEqual(WobbleState.none, pot.wobble_state);
}

test "12: Wobble animation delta-time update and angle progress" {
    var pot = DecoratedPot.init();
    pot.triggerWobble(.negative_wobble);
    try std.testing.expectEqual(WobbleState.negative_wobble, pot.wobble_state);
    try std.testing.expect(pot.wobble_timer > 0.49);

    // Angle should be non-zero while wobbling
    pot.updateAnimation(0.1);
    const angle = pot.getWobbleAngle();
    try std.testing.expect(angle != 0.0);

    // Advance past end of animation (0.5s total)
    pot.updateAnimation(0.5);
    try std.testing.expectEqual(WobbleState.none, pot.wobble_state);
    try std.testing.expectEqual(@as(f32, 0.0), pot.wobble_timer);
    try std.testing.expectEqual(@as(u8, 0), pot.wobble_ticks);
    try std.testing.expectEqual(@as(f32, 0.0), pot.getWobbleAngle());
}

test "13: Comparator fullness signal for empty and full pot" {
    var pot = DecoratedPot.init();
    // Empty pot outputs signal 0
    try std.testing.expectEqual(@as(u8, 0), pot.comparatorSignal());

    // Full pot (64/64) outputs signal 15
    _ = pot.insertItem(100, 64, 64);
    try std.testing.expectEqual(@as(u8, 15), pot.comparatorSignal());
}

test "14: Comparator fullness signal proportional graduation (0..15)" {
    var pot = DecoratedPot.init();
    // Non-empty item (1/64) produces signal 1
    _ = pot.insertItem(100, 1, 64);
    try std.testing.expectEqual(@as(u8, 1), pot.comparatorSignal());

    // Half full (32/64) produces signal 8
    pot.count = 32;
    try std.testing.expectEqual(@as(u8, 8), pot.comparatorSignal());

    // Three quarters full (48/64) produces signal 11
    pot.count = 48;
    try std.testing.expectEqual(@as(u8, 11), pot.comparatorSignal());

    // 63/64 produces signal 14
    pot.count = 63;
    try std.testing.expectEqual(@as(u8, 14), pot.comparatorSignal());

    // 64/64 produces signal 15
    pot.count = 64;
    try std.testing.expectEqual(@as(u8, 15), pot.comparatorSignal());
}

test "15: Comparator fullness signal with non-standard stack sizes (16 and 1)" {
    var pot16 = DecoratedPot.init();
    _ = pot16.insertItem(200, 1, 16);
    try std.testing.expectEqual(@as(u8, 1), pot16.comparatorSignal());
    pot16.count = 8;
    try std.testing.expectEqual(@as(u8, 8), pot16.comparatorSignal());
    pot16.count = 16;
    try std.testing.expectEqual(@as(u8, 15), pot16.comparatorSignal());

    var pot1 = DecoratedPot.init();
    _ = pot1.insertItem(300, 1, 1);
    try std.testing.expectEqual(@as(u8, 15), pot1.comparatorSignal());
}

test "16: Tool shatter drops 4 constituent bricks/sherds plus stored items" {
    var pot = assembleFaces(.angler, .brick_blank, .mourner, .archer);
    const diamond_tag: u16 = 217;
    _ = pot.insertItem(diamond_tag, 16, 64);

    // Shattered with pickaxe (broken_by_projectile_or_tool = true)
    const outcome = pot.resolveHarvestOutcome(true);
    try std.testing.expect(outcome.shattered);
    try std.testing.expect(outcome.intact_pot == null);
    try std.testing.expectEqual(@as(usize, 5), outcome.drop_count);

    // 4 constituent faces
    const drops = outcome.getDrops();
    try std.testing.expectEqual(PotterySherdTag, drops[0].item_id);
    try std.testing.expectEqual(PotFaceMotif.angler, drops[0].motif);

    try std.testing.expectEqual(BrickTag, drops[1].item_id);
    try std.testing.expectEqual(PotFaceMotif.brick_blank, drops[1].motif);

    try std.testing.expectEqual(PotterySherdTag, drops[2].item_id);
    try std.testing.expectEqual(PotFaceMotif.mourner, drops[2].motif);

    try std.testing.expectEqual(PotterySherdTag, drops[3].item_id);
    try std.testing.expectEqual(PotFaceMotif.archer, drops[3].motif);

    // 5th drop is the stored diamonds
    try std.testing.expectEqual(diamond_tag, drops[4].item_id);
    try std.testing.expectEqual(@as(u8, 16), drops[4].count);
}

test "17: Empty pot tool shatter drops exactly 4 constituent facets" {
    const pot = assembleFaces(.burn, .danger, .friend, .heart);
    const outcome = pot.resolveHarvestOutcome(true);
    try std.testing.expect(outcome.shattered);
    try std.testing.expect(outcome.intact_pot == null);
    try std.testing.expectEqual(@as(usize, 4), outcome.drop_count);

    const drops = outcome.getDrops();
    try std.testing.expectEqual(PotFaceMotif.burn, drops[0].motif);
    try std.testing.expectEqual(PotFaceMotif.danger, drops[1].motif);
    try std.testing.expectEqual(PotFaceMotif.friend, drops[2].motif);
    try std.testing.expectEqual(PotFaceMotif.heart, drops[3].motif);
}

test "18: Projectile shattering (arrow, wind charge, trident, snowball)" {
    var pot = assembleFaces(.arms_up, .blade, .brewer, .explorer);
    _ = pot.insertItem(81, 7, 64); // Gold nuggets

    const tools = [_]ToolKind{ .pickaxe, .sword, .axe };
    for (tools) |t| {
        const out = pot.resolveToolBreak(t, false);
        try std.testing.expect(out.shattered);
        try std.testing.expectEqual(@as(usize, 5), out.drop_count);
    }

    const projectiles = [_]ProjectileKind{ .arrow, .wind_charge, .trident, .snowball };
    for (projectiles) |proj| {
        const out = pot.resolveProjectileHit(proj);
        try std.testing.expect(out.shattered);
        try std.testing.expectEqual(@as(usize, 5), out.drop_count);
    }
}

test "19: Bare-hand break drops intact DecoratedPot preserving 4 face motifs" {
    var pot = assembleFaces(.snort, .prize, .skull, .plenty);
    _ = pot.insertItem(12, 5, 64); // Coal

    const outcome = pot.resolveHarvestOutcome(false);
    try std.testing.expect(!outcome.shattered);
    try std.testing.expectEqual(@as(usize, 1), outcome.drop_count);
    try std.testing.expectEqual(DecoratedPotTag, outcome.drops[0].item_id);
    try std.testing.expectEqual(@as(u8, 1), outcome.drops[0].count);

    // Preserved intact pot
    const intact = outcome.intact_pot.?;
    try std.testing.expectEqual(PotFaceMotif.snort, intact.north());
    try std.testing.expectEqual(PotFaceMotif.prize, intact.east());
    try std.testing.expectEqual(PotFaceMotif.skull, intact.south());
    try std.testing.expectEqual(PotFaceMotif.plenty, intact.west());
    try std.testing.expectEqual(@as(u16, 12), intact.item_id);
    try std.testing.expectEqual(@as(u8, 5), intact.count);
}

test "20: Silk touch tool break drops intact pot with preserved motifs" {
    const pot = assembleDiamond(.howl, .miner, .burn, .danger);
    const outcome = pot.resolveToolBreak(.pickaxe, true); // pickaxe with silk touch
    try std.testing.expect(!outcome.shattered);
    try std.testing.expect(outcome.intact_pot != null);
    try std.testing.expectEqual(PotFaceMotif.howl, outcome.intact_pot.?.north());
    try std.testing.expectEqual(PotFaceMotif.burn, outcome.intact_pot.?.east());
    try std.testing.expectEqual(PotFaceMotif.danger, outcome.intact_pot.?.south());
    try std.testing.expectEqual(PotFaceMotif.miner, outcome.intact_pot.?.west());
}

test "21: Inventory withdrawal and clearing" {
    var pot = DecoratedPot.init();
    _ = pot.insertItem(50, 30, 64);
    try std.testing.expectEqual(@as(u8, 30), pot.count);

    const w1 = pot.withdraw(10);
    try std.testing.expectEqual(@as(u16, 50), w1.item_id);
    try std.testing.expectEqual(@as(u8, 10), w1.count);
    try std.testing.expectEqual(@as(u8, 20), pot.count);

    const w2 = pot.takeAll();
    try std.testing.expectEqual(@as(u16, 50), w2.item_id);
    try std.testing.expectEqual(@as(u8, 20), w2.count);
    try std.testing.expect(pot.isEmpty());
    try std.testing.expectEqual(@as(u16, 0), pot.item_id);

    // Empty withdraw returns 0
    const w3 = pot.withdraw(5);
    try std.testing.expectEqual(@as(u8, 0), w3.count);
}

test "22: Free function resolveHarvestOutcome compatibility" {
    const pot = assembleAllBricks();
    const out_shattered = resolveHarvestOutcome(pot, true);
    try std.testing.expect(out_shattered.shattered);

    const out_intact = resolveHarvestOutcome(pot, false);
    try std.testing.expect(!out_intact.shattered);
}
