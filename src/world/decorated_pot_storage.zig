const std = @import("std");

// ============================================================================
// Constants & Item Tags
// ============================================================================

/// Standard item tags used in Decorated Pot assembly and drops.
pub const BrickTag: u16 = 328;
pub const PotterySherdTag: u16 = 369;
pub const DecoratedPotTag: u16 = 370;

/// The maximum duration of pot wobble animation in game ticks (10 ticks = 0.5s).
pub const max_wobble_ticks: u8 = 10;
/// Wobble animation duration in seconds.
pub const wobble_duration_seconds: f32 = 0.5;

/// Maximum number of drops from harvesting a decorated pot:
/// 4 constituent sherds/bricks + 1 stored item stack (shatter) or intact pot + content (bare hand).
pub const max_harvest_drops: usize = 6;

// ============================================================================
// Facet Motifs (Brick + 23 Archaeological Sherds)
// ============================================================================

/// The 24 decorative facet motifs for a Decorated Pot:
/// 1 plain brick + 23 archaeological pottery sherd designs (Minecraft 1.20 + 1.21).
pub const PotFacetMotif = enum(u8) {
    brick = 0,
    angler = 1,
    archer = 2,
    arms_up = 3,
    blade = 4,
    brewer = 5,
    burn = 6,
    danger = 7,
    explorer = 8,
    flow = 9,
    friend = 10,
    guster = 11,
    heart = 12,
    heartbreak = 13,
    howl = 14,
    miner = 15,
    mourner = 16,
    plenty = 17,
    prize = 18,
    scrape = 19,
    sheaf = 20,
    shelter = 21,
    skull = 22,
    snort = 23,

    pub const brick_blank = PotFacetMotif.brick;

    pub fn isSherd(self: PotFacetMotif) bool {
        return self != .brick;
    }

    pub fn isBrick(self: PotFacetMotif) bool {
        return self == .brick;
    }

    pub fn name(self: PotFacetMotif) []const u8 {
        return switch (self) {
            .brick => "Brick",
            .angler => "Angler Pottery Sherd",
            .archer => "Archer Pottery Sherd",
            .arms_up => "Arms Up Pottery Sherd",
            .blade => "Blade Pottery Sherd",
            .brewer => "Brewer Pottery Sherd",
            .burn => "Burn Pottery Sherd",
            .danger => "Danger Pottery Sherd",
            .explorer => "Explorer Pottery Sherd",
            .flow => "Flow Pottery Sherd",
            .friend => "Friend Pottery Sherd",
            .guster => "Guster Pottery Sherd",
            .heart => "Heart Pottery Sherd",
            .heartbreak => "Heartbreak Pottery Sherd",
            .howl => "Howl Pottery Sherd",
            .miner => "Miner Pottery Sherd",
            .mourner => "Mourner Pottery Sherd",
            .plenty => "Plenty Pottery Sherd",
            .prize => "Prize Pottery Sherd",
            .scrape => "Scrape Pottery Sherd",
            .sheaf => "Sheaf Pottery Sherd",
            .shelter => "Shelter Pottery Sherd",
            .skull => "Skull Pottery Sherd",
            .snort => "Snort Pottery Sherd",
        };
    }

    pub fn dropItemTag(self: PotFacetMotif) u16 {
        return if (self == .brick) BrickTag else PotterySherdTag;
    }
};

/// Backward-compatible alias for PotFacetMotif.
pub const PotFaceMotif = PotFacetMotif;

// ============================================================================
// Cardinal Directions & Facets
// ============================================================================

/// The 4 cardinal facets of a decorated pot block.
pub const CardinalFacet = enum(u2) {
    north = 0,
    east = 1,
    south = 2,
    west = 3,

    pub fn opposite(self: CardinalFacet) CardinalFacet {
        return switch (self) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }
};

/// Backward-compatible alias for CardinalFacet.
pub const CardinalFace = CardinalFacet;

// ============================================================================
// Diamond Crafting Pattern
// ============================================================================

/// 4-slot diamond crafting pattern representation.
/// In standard crafting tables:
/// - top (back)    -> North facet
/// - left (left)   -> West facet
/// - right (right) -> East facet
/// - bottom (front)-> South facet
pub const DiamondCraftingPattern = struct {
    top: PotFacetMotif = .brick,
    left: PotFacetMotif = .brick,
    right: PotFacetMotif = .brick,
    bottom: PotFacetMotif = .brick,
};

// ============================================================================
// Wobble Animation State
// ============================================================================

/// Visual wobble animation state when interacting with a decorated pot.
pub const WobbleState = enum(u8) {
    none = 0,
    positive_wobble = 1,
    negative_wobble = 2,
};

// ============================================================================
// Tools, Projectiles, & Drops
// ============================================================================

/// Tool classifications for breaking decorated pots.
pub const ToolKind = enum {
    pickaxe,
    axe,
    shovel,
    hoe,
    sword,
    bare_hand,
    fist,

    pub fn isTool(self: ToolKind) bool {
        return switch (self) {
            .pickaxe, .axe, .shovel, .hoe, .sword => true,
            .bare_hand, .fist => false,
        };
    }

    pub fn shattersPot(self: ToolKind) bool {
        return self.isTool();
    }
};

/// Projectile classifications for hitting decorated pots.
pub const ProjectileKind = enum {
    arrow,
    wind_charge,
    trident,
    snowball,
    egg,
    fireball,
    firework_rocket,

    pub fn shattersPot(self: ProjectileKind) bool {
        _ = self;
        return true;
    }
};

pub fn isShatterTool(tool: ToolKind) bool {
    return tool.shattersPot();
}

pub fn isShatterProjectile(proj: ProjectileKind) bool {
    return proj.shattersPot();
}

/// Item dropped upon shattering or breaking a decorated pot.
pub const PotDrop = struct {
    item_id: u16,
    count: u8,
    motif: PotFacetMotif = .brick,
};

/// Representing items withdrawn or extracted from the single-stack storage.
pub const WithdrawnItem = struct {
    item_id: u16,
    count: u8,
};

/// Complete outcome of harvesting/breaking a decorated pot.
pub const HarvestOutcome = struct {
    shattered: bool,
    drops: [max_harvest_drops]PotDrop = [_]PotDrop{.{ .item_id = 0, .count = 0 }} ** max_harvest_drops,
    drop_count: usize = 0,
    intact_pot: ?DecoratedPot = null,

    pub fn getDrops(self: *const HarvestOutcome) []const PotDrop {
        return self.drops[0..self.drop_count];
    }
};

// ============================================================================
// Decorated Pot Container Implementation
// ============================================================================

pub const DecoratedPot = struct {
    /// 4 cardinal facet motifs [north, east, south, west].
    faces: [4]PotFacetMotif = [_]PotFacetMotif{.brick} ** 4,

    /// Single-stack internal inventory storage.
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

    pub fn initFacets(north_motif: PotFacetMotif, east_motif: PotFacetMotif, south_motif: PotFacetMotif, west_motif: PotFacetMotif) DecoratedPot {
        var pot = DecoratedPot{};
        pot.setFacet(.north, north_motif);
        pot.setFacet(.east, east_motif);
        pot.setFacet(.south, south_motif);
        pot.setFacet(.west, west_motif);
        return pot;
    }

    pub fn initFaces(north_motif: PotFacetMotif, east_motif: PotFacetMotif, south_motif: PotFacetMotif, west_motif: PotFacetMotif) DecoratedPot {
        return initFacets(north_motif, east_motif, south_motif, west_motif);
    }

    pub fn initDiamond(top: PotFacetMotif, left: PotFacetMotif, right: PotFacetMotif, bottom: PotFacetMotif) DecoratedPot {
        return assembleDiamond(top, left, right, bottom);
    }

    // --- Facet Getters & Setters ---

    pub fn getFacet(self: DecoratedPot, facet: CardinalFacet) PotFacetMotif {
        return self.faces[@intFromEnum(facet)];
    }

    pub fn setFacet(self: *DecoratedPot, facet: CardinalFacet, motif: PotFacetMotif) void {
        self.faces[@intFromEnum(facet)] = motif;
    }

    pub fn getFace(self: DecoratedPot, face: CardinalFace) PotFacetMotif {
        return self.getFacet(face);
    }

    pub fn setFace(self: *DecoratedPot, face: CardinalFace, motif: PotFacetMotif) void {
        self.setFacet(face, motif);
    }

    pub fn north(self: DecoratedPot) PotFacetMotif {
        return self.getFacet(.north);
    }

    pub fn east(self: DecoratedPot) PotFacetMotif {
        return self.getFacet(.east);
    }

    pub fn south(self: DecoratedPot) PotFacetMotif {
        return self.getFacet(.south);
    }

    pub fn west(self: DecoratedPot) PotFacetMotif {
        return self.getFacet(.west);
    }

    pub fn countSherds(self: DecoratedPot) u8 {
        var cnt: u8 = 0;
        for (self.faces) |f| {
            if (f.isSherd()) cnt += 1;
        }
        return cnt;
    }

    pub fn countBricks(self: DecoratedPot) u8 {
        var cnt: u8 = 0;
        for (self.faces) |f| {
            if (f.isBrick()) cnt += 1;
        }
        return cnt;
    }

    pub fn isAllBricks(self: DecoratedPot) bool {
        for (self.faces) |f| {
            if (!f.isBrick()) return false;
        }
        return true;
    }

    // --- Single-Stack Storage Mechanics ---

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

    /// Attempts to insert items into this decorated pot's single-stack storage.
    /// Right-clicking with an item inserts into the pot up to stack capacity.
    /// Rejects different item types when already holding an item.
    /// Returns the number of items successfully accepted.
    /// Triggers positive_wobble on success (>0 accepted), or negative_wobble on failure.
    pub fn insertItem(self: *DecoratedPot, new_item_id: u16, new_count: u8, item_max_stack: u8) u8 {
        if (new_item_id == 0 or new_count == 0 or item_max_stack == 0) {
            self.triggerWobble(.negative_wobble);
            return 0;
        }

        const effective_max = @min(item_max_stack, 64);
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
            // Pot already holds an item: reject different item type or if full
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

    /// Punching / hitting the pot with an empty hand or tool extracts and drops the stored items.
    /// Triggers visual wobble animation.
    /// Returns the extracted item stack if items were present, or null if empty.
    pub fn punch(self: *DecoratedPot) ?WithdrawnItem {
        self.triggerWobble(.positive_wobble);
        if (self.count > 0) {
            const extracted = self.takeAll();
            return extracted;
        }
        return null;
    }

    /// Alias for punch extraction.
    pub fn punchExtract(self: *DecoratedPot) ?WithdrawnItem {
        return self.punch();
    }

    // --- Wobble Animation ---

    /// Triggers a wobble animation state, resetting duration timers and ticks.
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

    /// Ticks the wobble animation (called each game tick, 20 ticks/sec).
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

    /// Calculates a visual rotational oscillation angle (in degrees) for rendering.
    /// Produces a decaying sinusoidal oscillation based on remaining wobble duration or ticks.
    pub fn getWobbleAngle(self: DecoratedPot) f32 {
        if (self.wobble_state == .none) {
            return 0.0;
        }
        if (self.wobble_ticks == 0 and self.wobble_timer <= 0.0) {
            return 0.0;
        }

        const progress: f32 = if (self.wobble_timer > 0.0)
            1.0 - (self.wobble_timer / wobble_duration_seconds)
        else
            1.0 - (@as(f32, @floatFromInt(self.wobble_ticks)) / @as(f32, @floatFromInt(max_wobble_ticks)));

        const clamped_progress = std.math.clamp(progress, 0.0, 1.0);
        const decay = 1.0 - clamped_progress;
        const amplitude: f32 = if (self.wobble_state == .positive_wobble) 6.0 else 3.0;
        const freq: f32 = if (self.wobble_state == .positive_wobble) 4.0 else 8.0;
        return amplitude * decay * @sin(clamped_progress * freq * std.math.pi);
    }

    // --- Redstone Comparator Signal ---

    /// Comparator reads fullness ratio:
    /// signal = @as(u4, @intFromFloat(@ceil(@as(f32, @floatFromInt(count)) / @as(f32, @floatFromInt(max_stack)) * 15.0)))
    /// Returns 1..15 when holding items, 0 when empty.
    pub fn comparatorSignal(self: DecoratedPot) u4 {
        if (self.count == 0 or self.max_stack == 0) return 0;
        const count_f: f32 = @floatFromInt(self.count);
        const max_f: f32 = @floatFromInt(self.max_stack);
        const signal = @as(u4, @intFromFloat(@ceil(count_f / max_f * 15.0)));
        return @min(15, signal);
    }

    // --- Harvesting & Shattering Mechanics ---

    /// Resolves block harvest drops:
    /// - Breaking with any tool shatters the pot, dropping the 4 constituent sherds/bricks and any stored items.
    /// - Breaking with bare hands / fists drops the intact Decorated Pot preserving its 4 facet patterns, plus stored items.
    pub fn resolveHarvestOutcome(self: DecoratedPot, broken_with_tool: bool) HarvestOutcome {
        var outcome = HarvestOutcome{
            .shattered = broken_with_tool,
        };

        if (broken_with_tool) {
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
                    .motif = .brick,
                };
                outcome.drop_count = 5;
            }
        } else {
            // Bare hands drop intact pot item preserving its 4 facet patterns
            outcome.intact_pot = self;
            outcome.drops[0] = .{
                .item_id = DecoratedPotTag,
                .count = 1,
                .motif = .brick,
            };
            outcome.drop_count = 1;

            // Plus stored items drop
            if (self.count > 0 and self.item_id != 0) {
                outcome.drops[1] = .{
                    .item_id = self.item_id,
                    .count = self.count,
                    .motif = .brick,
                };
                outcome.drop_count = 2;
            }
        }

        return outcome;
    }

    /// Resolves harvest outcome when hit with a specific tool and silk touch flag.
    pub fn resolveToolBreak(self: DecoratedPot, tool: ToolKind, silk_touch: bool) HarvestOutcome {
        if (silk_touch) {
            return self.resolveHarvestOutcome(false);
        }
        return self.resolveHarvestOutcome(tool.shattersPot());
    }

    /// Resolves harvest outcome when hit by a projectile.
    pub fn resolveProjectileHit(self: DecoratedPot, proj: ProjectileKind) HarvestOutcome {
        return self.resolveHarvestOutcome(proj.shattersPot());
    }
};

// ============================================================================
// Assembly & Crafting Helpers
// ============================================================================

/// Assembles a DecoratedPot from a 4-slot diamond crafting pattern.
/// - top (back)    -> North facet
/// - left (left)   -> West facet
/// - right (right) -> East facet
/// - bottom (front)-> South facet
pub fn assembleFromDiamondPattern(pattern: DiamondCraftingPattern) DecoratedPot {
    var pot = DecoratedPot{};
    pot.setFacet(.north, pattern.top);
    pot.setFacet(.west, pattern.left);
    pot.setFacet(.east, pattern.right);
    pot.setFacet(.south, pattern.bottom);
    return pot;
}

pub fn assembleDiamond(top: PotFacetMotif, left: PotFacetMotif, right: PotFacetMotif, bottom: PotFacetMotif) DecoratedPot {
    return assembleFromDiamondPattern(.{
        .top = top,
        .left = left,
        .right = right,
        .bottom = bottom,
    });
}

pub fn assembleFacets(north_motif: PotFacetMotif, east_motif: PotFacetMotif, south_motif: PotFacetMotif, west_motif: PotFacetMotif) DecoratedPot {
    return DecoratedPot.initFacets(north_motif, east_motif, south_motif, west_motif);
}

pub fn assembleFaces(north_motif: PotFacetMotif, east_motif: PotFacetMotif, south_motif: PotFacetMotif, west_motif: PotFacetMotif) DecoratedPot {
    return assembleFacets(north_motif, east_motif, south_motif, west_motif);
}

pub fn assembleAllBricks() DecoratedPot {
    return assembleFacets(.brick, .brick, .brick, .brick);
}

/// Parses a 3x3 crafting grid containing a diamond pattern into a DecoratedPot.
/// In a 3x3 grid (indices 0..8):
/// [0] [1: top]    [2]
/// [3: left] [4]   [5: right]
/// [6] [7: bottom] [8]
pub fn craftFrom3x3Grid(grid: [9]?PotFacetMotif) ?DecoratedPot {
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
pub fn resolveHarvestOutcome(pot: DecoratedPot, broken_with_tool: bool) HarvestOutcome {
    return pot.resolveHarvestOutcome(broken_with_tool);
}

// ============================================================================
// Unit Tests (28 Comprehensive Tests)
// ============================================================================

test "1: PotFacetMotif all 24 variants, names, isSherd, isBrick, and drop tags" {
    const motifs = [_]PotFacetMotif{
        .brick,
        .angler,
        .archer,
        .arms_up,
        .blade,
        .brewer,
        .burn,
        .danger,
        .explorer,
        .flow,
        .friend,
        .guster,
        .heart,
        .heartbreak,
        .howl,
        .miner,
        .mourner,
        .plenty,
        .prize,
        .scrape,
        .sheaf,
        .shelter,
        .skull,
        .snort,
    };
    try std.testing.expectEqual(@as(usize, 24), motifs.len);

    // Brick verification
    try std.testing.expect(!PotFacetMotif.brick.isSherd());
    try std.testing.expect(PotFacetMotif.brick.isBrick());
    try std.testing.expectEqual(BrickTag, PotFacetMotif.brick.dropItemTag());
    try std.testing.expectEqualStrings("Brick", PotFacetMotif.brick.name());

    // All 23 archaeological pottery sherds verification
    for (motifs[1..]) |m| {
        try std.testing.expect(m.isSherd());
        try std.testing.expect(!m.isBrick());
        try std.testing.expectEqual(PotterySherdTag, m.dropItemTag());
        try std.testing.expect(m.name().len > 0);
    }
}

test "2: DecoratedPot 4-facet cardinal direction assembly and getters/setters" {
    var pot = DecoratedPot.initFacets(.angler, .archer, .mourner, .snort);
    try std.testing.expectEqual(PotFacetMotif.angler, pot.north());
    try std.testing.expectEqual(PotFacetMotif.archer, pot.east());
    try std.testing.expectEqual(PotFacetMotif.mourner, pot.south());
    try std.testing.expectEqual(PotFacetMotif.snort, pot.west());

    pot.setFacet(.north, .skull);
    pot.setFacet(.east, .prize);
    pot.setFacet(.south, .heartbreak);
    pot.setFacet(.west, .flow);
    try std.testing.expectEqual(PotFacetMotif.skull, pot.getFacet(.north));
    try std.testing.expectEqual(PotFacetMotif.prize, pot.getFacet(.east));
    try std.testing.expectEqual(PotFacetMotif.heartbreak, pot.getFacet(.south));
    try std.testing.expectEqual(PotFacetMotif.flow, pot.getFacet(.west));
    try std.testing.expectEqual(@as(u8, 4), pot.countSherds());
    try std.testing.expectEqual(@as(u8, 0), pot.countBricks());
    try std.testing.expect(!pot.isAllBricks());
}

test "3: Diamond crafting pattern maps top/left/right/bottom to cardinal facets" {
    // Diamond crafting layout:
    // top -> north (back)
    // left -> west (left)
    // right -> east (right)
    // bottom -> south (front)
    const pot = assembleDiamond(.howl, .blade, .heart, .friend);
    try std.testing.expectEqual(PotFacetMotif.howl, pot.north());
    try std.testing.expectEqual(PotFacetMotif.heart, pot.east());
    try std.testing.expectEqual(PotFacetMotif.friend, pot.south());
    try std.testing.expectEqual(PotFacetMotif.blade, pot.west());
}

test "4: Diamond assembly with mixed sherds and plain bricks" {
    const pot = assembleDiamond(.brick, .archer, .brick, .miner);
    try std.testing.expectEqual(PotFacetMotif.brick, pot.north());
    try std.testing.expectEqual(PotFacetMotif.brick, pot.east());
    try std.testing.expectEqual(PotFacetMotif.miner, pot.south());
    try std.testing.expectEqual(PotFacetMotif.archer, pot.west());

    try std.testing.expectEqual(@as(u8, 2), pot.countSherds());
    try std.testing.expectEqual(@as(u8, 2), pot.countBricks());
    try std.testing.expect(!pot.isAllBricks());

    const all_brick = assembleAllBricks();
    try std.testing.expectEqual(@as(u8, 0), all_brick.countSherds());
    try std.testing.expectEqual(@as(u8, 4), all_brick.countBricks());
    try std.testing.expect(all_brick.isAllBricks());
}

test "5: 3x3 crafting grid diamond pattern assembly and rejection of non-diamond slots" {
    var grid: [9]?PotFacetMotif = [_]?PotFacetMotif{null} ** 9;
    grid[1] = .danger;
    grid[3] = .explorer;
    grid[5] = .plenty;
    grid[7] = .brewer;

    const pot = craftFrom3x3Grid(grid).?;
    try std.testing.expectEqual(PotFacetMotif.danger, pot.north());
    try std.testing.expectEqual(PotFacetMotif.explorer, pot.west());
    try std.testing.expectEqual(PotFacetMotif.plenty, pot.east());
    try std.testing.expectEqual(PotFacetMotif.brewer, pot.south());

    // Corner slot filled should reject
    grid[0] = .brick;
    try std.testing.expect(craftFrom3x3Grid(grid) == null);

    // Center slot filled should reject
    grid[0] = null;
    grid[4] = .burn;
    try std.testing.expect(craftFrom3x3Grid(grid) == null);

    // Missing top slot should reject
    grid[4] = null;
    grid[1] = null;
    try std.testing.expect(craftFrom3x3Grid(grid) == null);
}

test "6: Single-stack storage insertion into empty pot triggers positive wobble" {
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

test "7: Single-stack storage accumulates same item up to max_stack" {
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

    // Insert emerald into diamond-holding pot
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

test "11: Single-stack storage with non-standard stack limits (16 and 1)" {
    var pot16 = DecoratedPot.init();
    const pearl_tag: u16 = 368;
    const accepted16 = pot16.insertItem(pearl_tag, 20, 16);
    try std.testing.expectEqual(@as(u8, 16), accepted16);
    try std.testing.expectEqual(@as(u8, 16), pot16.count);
    try std.testing.expectEqual(@as(u8, 16), pot16.max_stack);
    try std.testing.expect(pot16.isFull());

    var pot1 = DecoratedPot.init();
    const sword_tag: u16 = 276;
    const accepted1 = pot1.insertItem(sword_tag, 5, 1);
    try std.testing.expectEqual(@as(u8, 1), accepted1);
    try std.testing.expectEqual(@as(u8, 1), pot1.count);
    try std.testing.expectEqual(@as(u8, 1), pot1.max_stack);
    try std.testing.expect(pot1.isFull());
}

test "12: Punch extraction drops stored items and triggers wobble" {
    var pot = DecoratedPot.init();
    const diamond_tag: u16 = 217;
    _ = pot.insertItem(diamond_tag, 15, 64);
    try std.testing.expectEqual(@as(u8, 15), pot.count);

    // Punching the pot extracts and drops stored items
    const extracted = pot.punch();
    try std.testing.expect(extracted != null);
    try std.testing.expectEqual(diamond_tag, extracted.?.item_id);
    try std.testing.expectEqual(@as(u8, 15), extracted.?.count);

    // Pot is now empty and storage reset
    try std.testing.expect(pot.isEmpty());
    try std.testing.expectEqual(@as(u16, 0), pot.item_id);
    try std.testing.expectEqual(@as(u8, 0), pot.count);

    // Wobble animation triggered
    try std.testing.expectEqual(WobbleState.positive_wobble, pot.wobble_state);
    try std.testing.expectEqual(max_wobble_ticks, pot.wobble_ticks);
}

test "13: Punch on empty pot returns null and triggers wobble" {
    var pot = DecoratedPot.init();
    try std.testing.expect(pot.isEmpty());

    const res = pot.punch();
    try std.testing.expect(res == null);
    try std.testing.expectEqual(WobbleState.positive_wobble, pot.wobble_state);
    try std.testing.expectEqual(max_wobble_ticks, pot.wobble_ticks);
}

test "14: Wobble animation tick countdown and transition to idle state" {
    var pot = DecoratedPot.init();
    pot.triggerWobble(.positive_wobble);
    try std.testing.expectEqual(WobbleState.positive_wobble, pot.wobble_state);
    try std.testing.expectEqual(max_wobble_ticks, pot.wobble_ticks);

    // Tick down 5 game ticks
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

test "15: Wobble animation delta-time update and duration decay" {
    var pot = DecoratedPot.init();
    pot.triggerWobble(.negative_wobble);
    try std.testing.expectEqual(WobbleState.negative_wobble, pot.wobble_state);
    try std.testing.expect(pot.wobble_timer > 0.49);

    pot.updateAnimation(0.2);
    try std.testing.expect(pot.wobble_timer < 0.31);
    try std.testing.expect(pot.wobble_ticks > 0);

    // Advance past end of animation
    pot.updateAnimation(0.4);
    try std.testing.expectEqual(WobbleState.none, pot.wobble_state);
    try std.testing.expectEqual(@as(f32, 0.0), pot.wobble_timer);
    try std.testing.expectEqual(@as(u8, 0), pot.wobble_ticks);
    try std.testing.expectEqual(@as(f32, 0.0), pot.getWobbleAngle());
}

test "16: Rotational oscillation angle calculation with decaying sinusoidal motion" {
    var pot = DecoratedPot.init();
    pot.triggerWobble(.positive_wobble);

    // Mid-wobble has non-zero oscillation angle
    pot.updateAnimation(0.1);
    const angle = pot.getWobbleAngle();
    try std.testing.expect(angle != 0.0);

    // Stationary pot has 0 wobble angle
    pot.triggerWobble(.none);
    try std.testing.expectEqual(@as(f32, 0.0), pot.getWobbleAngle());
}

test "17: Tool shattering with pickaxe drops 4 constituent sherds/bricks plus stored items" {
    var pot = assembleFacets(.angler, .brick, .mourner, .archer);
    const diamond_tag: u16 = 217;
    _ = pot.insertItem(diamond_tag, 16, 64);

    const outcome = pot.resolveToolBreak(.pickaxe, false);
    try std.testing.expect(outcome.shattered);
    try std.testing.expect(outcome.intact_pot == null);
    try std.testing.expectEqual(@as(usize, 5), outcome.drop_count);

    const drops = outcome.getDrops();
    // 4 constituent facet items
    try std.testing.expectEqual(PotterySherdTag, drops[0].item_id);
    try std.testing.expectEqual(PotFacetMotif.angler, drops[0].motif);

    try std.testing.expectEqual(BrickTag, drops[1].item_id);
    try std.testing.expectEqual(PotFacetMotif.brick, drops[1].motif);

    try std.testing.expectEqual(PotterySherdTag, drops[2].item_id);
    try std.testing.expectEqual(PotFacetMotif.mourner, drops[2].motif);

    try std.testing.expectEqual(PotterySherdTag, drops[3].item_id);
    try std.testing.expectEqual(PotFacetMotif.archer, drops[3].motif);

    // 5th drop is the stored items
    try std.testing.expectEqual(diamond_tag, drops[4].item_id);
    try std.testing.expectEqual(@as(u8, 16), drops[4].count);
}

test "18: Tool shattering with axe, shovel, and hoe all shatter pot into constituent sherds" {
    var pot = assembleFacets(.burn, .danger, .friend, .heart);
    _ = pot.insertItem(100, 5, 64);

    const tools = [_]ToolKind{ .axe, .shovel, .hoe, .sword };
    for (tools) |tool| {
        const out = pot.resolveToolBreak(tool, false);
        try std.testing.expect(out.shattered);
        try std.testing.expect(out.intact_pot == null);
        try std.testing.expectEqual(@as(usize, 5), out.drop_count);
    }
}

test "19: Shattering an empty decorated pot drops exactly 4 constituent sherds/bricks" {
    const pot = assembleFacets(.guster, .scrape, .flow, .sheaf);
    const outcome = pot.resolveHarvestOutcome(true);
    try std.testing.expect(outcome.shattered);
    try std.testing.expect(outcome.intact_pot == null);
    try std.testing.expectEqual(@as(usize, 4), outcome.drop_count);

    const drops = outcome.getDrops();
    try std.testing.expectEqual(PotFacetMotif.guster, drops[0].motif);
    try std.testing.expectEqual(PotFacetMotif.scrape, drops[1].motif);
    try std.testing.expectEqual(PotFacetMotif.flow, drops[2].motif);
    try std.testing.expectEqual(PotFacetMotif.sheaf, drops[3].motif);
}

test "20: Projectile shattering (arrow, wind charge, trident) breaks pot into 4 sherds plus content" {
    var pot = assembleFacets(.arms_up, .blade, .brewer, .explorer);
    _ = pot.insertItem(81, 7, 64);

    const projectiles = [_]ProjectileKind{ .arrow, .wind_charge, .trident, .snowball };
    for (projectiles) |proj| {
        const out = pot.resolveProjectileHit(proj);
        try std.testing.expect(out.shattered);
        try std.testing.expectEqual(@as(usize, 5), out.drop_count);
    }
}

test "21: Bare-hand / fist break drops intact DecoratedPot preserving 4 facet motifs PLUS stored content" {
    var pot = assembleFacets(.snort, .prize, .skull, .plenty);
    _ = pot.insertItem(12, 5, 64); // Coal

    const outcome = pot.resolveToolBreak(.bare_hand, false);
    try std.testing.expect(!outcome.shattered);
    try std.testing.expect(outcome.intact_pot != null);
    try std.testing.expectEqual(@as(usize, 2), outcome.drop_count);

    // First drop is the intact decorated pot item
    try std.testing.expectEqual(DecoratedPotTag, outcome.drops[0].item_id);
    try std.testing.expectEqual(@as(u8, 1), outcome.drops[0].count);

    // Second drop is the stored items
    try std.testing.expectEqual(@as(u16, 12), outcome.drops[1].item_id);
    try std.testing.expectEqual(@as(u8, 5), outcome.drops[1].count);

    // Preserved intact pot facets
    const intact = outcome.intact_pot.?;
    try std.testing.expectEqual(PotFacetMotif.snort, intact.north());
    try std.testing.expectEqual(PotFacetMotif.prize, intact.east());
    try std.testing.expectEqual(PotFacetMotif.skull, intact.south());
    try std.testing.expectEqual(PotFacetMotif.plenty, intact.west());
}

test "22: Bare-hand break on empty pot drops intact DecoratedPot with preserved motifs" {
    const pot = assembleFacets(.shelter, .heartbreak, .howl, .miner);
    const outcome = pot.resolveHarvestOutcome(false);
    try std.testing.expect(!outcome.shattered);
    try std.testing.expect(outcome.intact_pot != null);
    try std.testing.expectEqual(@as(usize, 1), outcome.drop_count);
    try std.testing.expectEqual(DecoratedPotTag, outcome.drops[0].item_id);
}

test "23: Silk touch tool break preserves intact pot and drops stored items" {
    var pot = assembleDiamond(.howl, .miner, .burn, .danger);
    _ = pot.insertItem(55, 3, 64);

    const outcome = pot.resolveToolBreak(.pickaxe, true); // Pickaxe with silk touch
    try std.testing.expect(!outcome.shattered);
    try std.testing.expect(outcome.intact_pot != null);
    try std.testing.expectEqual(PotFacetMotif.howl, outcome.intact_pot.?.north());
    try std.testing.expectEqual(PotFacetMotif.burn, outcome.intact_pot.?.east());
    try std.testing.expectEqual(PotFacetMotif.danger, outcome.intact_pot.?.south());
    try std.testing.expectEqual(PotFacetMotif.miner, outcome.intact_pot.?.west());
    try std.testing.expectEqual(@as(usize, 2), outcome.drop_count);
}

test "24: Comparator signal: empty pot outputs 0" {
    var pot = DecoratedPot.init();
    try std.testing.expectEqual(@as(u4, 0), pot.comparatorSignal());
}

test "25: Comparator signal: full pot outputs 15 across any stack size" {
    var pot64 = DecoratedPot.init();
    _ = pot64.insertItem(100, 64, 64);
    try std.testing.expectEqual(@as(u4, 15), pot64.comparatorSignal());

    var pot16 = DecoratedPot.init();
    _ = pot16.insertItem(200, 16, 16);
    try std.testing.expectEqual(@as(u4, 15), pot16.comparatorSignal());

    var pot1 = DecoratedPot.init();
    _ = pot1.insertItem(300, 1, 1);
    try std.testing.expectEqual(@as(u4, 15), pot1.comparatorSignal());
}

test "26: Comparator signal: graduated fullness ratios matching ceil(count / max * 15.0)" {
    var pot = DecoratedPot.init();
    _ = pot.insertItem(100, 1, 64);

    // 1 item (1/64 = 0.015625 * 15 = 0.234375 -> ceil -> 1)
    try std.testing.expectEqual(@as(u4, 1), pot.comparatorSignal());

    // 4 items (4/64 * 15 = 0.9375 -> ceil -> 1)
    pot.count = 4;
    try std.testing.expectEqual(@as(u4, 1), pot.comparatorSignal());

    // 5 items (5/64 * 15 = 1.171875 -> ceil -> 2)
    pot.count = 5;
    try std.testing.expectEqual(@as(u4, 2), pot.comparatorSignal());

    // 32 items (32/64 * 15 = 7.5 -> ceil -> 8)
    pot.count = 32;
    try std.testing.expectEqual(@as(u4, 8), pot.comparatorSignal());

    // 48 items (48/64 * 15 = 11.25 -> ceil -> 12)
    pot.count = 48;
    try std.testing.expectEqual(@as(u4, 12), pot.comparatorSignal());

    // 63 items (63/64 * 15 = 14.765625 -> ceil -> 15)
    pot.count = 63;
    try std.testing.expectEqual(@as(u4, 15), pot.comparatorSignal());

    // 64 items (64/64 * 15 = 15.0 -> ceil -> 15)
    pot.count = 64;
    try std.testing.expectEqual(@as(u4, 15), pot.comparatorSignal());
}

test "27: Partial item withdrawal and clearInventory" {
    var pot = DecoratedPot.init();
    _ = pot.insertItem(50, 30, 64);
    try std.testing.expectEqual(@as(u8, 30), pot.count);

    const w1 = pot.withdraw(10);
    try std.testing.expectEqual(@as(u16, 50), w1.item_id);
    try std.testing.expectEqual(@as(u8, 10), w1.count);
    try std.testing.expectEqual(@as(u8, 20), pot.count);

    pot.clearInventory();
    try std.testing.expect(pot.isEmpty());
    try std.testing.expectEqual(@as(u16, 0), pot.item_id);
    try std.testing.expectEqual(@as(u8, 0), pot.count);
}

test "28: Free function resolveHarvestOutcome compatibility" {
    const pot = assembleAllBricks();
    const out_shattered = resolveHarvestOutcome(pot, true);
    try std.testing.expect(out_shattered.shattered);

    const out_intact = resolveHarvestOutcome(pot, false);
    try std.testing.expect(!out_intact.shattered);
}
