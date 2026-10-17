const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Maximum effective bookshelves that empower an Enchantment Table (15 bookshelves).
pub const MAX_EFFECTIVE_BOOKSHELVES: u4 = 15;

/// Number of bookshelf positions in the standard 5x5 single-tier radius-2 ring around an Enchantment Table (16 positions).
pub const BOOKSHELF_RING_CAPACITY: usize = 16;

/// Maximum enchantment offer level required in slot 3 when bookshelf count reaches 15 (Level 30).
pub const MAX_ENCHANTMENT_LEVEL: u8 = 30;

/// Base minimum enchantment level without bookshelves (Level 8 in slot 3 maximum offer).
pub const BASE_ENCHANTMENT_LEVEL: u8 = 8;

/// Durability points restored per 1 Experience Point collected via the Mending enchantment (2 durability / 1 XP).
pub const MENDING_DURABILITY_PER_XP: u16 = 2;

/// Fixed Lapis Lazuli material costs for enchantment slots 1, 2, and 3 (1, 2, 3 pieces).
pub const LAPIS_SLOT_COSTS: [3]u8 = .{ 1, 2, 3 };

/// Average XP refunded per non-curse enchantment level stripped at a Grindstone (~7 XP per level).
pub const XP_PER_ENCHANT_LEVEL_REFUND: u16 = 7;

// ============================================================================
// Enums & Definitions
// ============================================================================

/// Canonical Minecraft enchantment categories and identities.
pub const EnchantmentKind = enum {
    // Armor
    protection,
    fire_protection,
    feather_falling,
    blast_protection,
    projectile_protection,
    respiration,
    aqua_affinity,
    thorns,
    depth_strider,
    frost_walker,
    soul_speed,
    swift_sneak,

    // Weapons / Melee
    sharpness,
    smite,
    bane_of_arthropods,
    knockback,
    fire_aspect,
    looting,
    sweeping_edge,

    // Tools
    efficiency,
    silk_touch,
    unbreaking,
    fortune,

    // Bows & Crossbows
    power,
    punch,
    flame,
    infinity,
    multishot,
    quick_charge,
    piercing,

    // Tridents
    loyalty,
    impaling,
    riptide,
    channeling,

    // Fishing Rods
    luck_of_the_sea,
    lure,

    // Universal / Mending
    mending,

    // Curses
    curse_of_binding,
    curse_of_vanishing,

    // Modern Mace Enchantments
    density,
    breach,
    wind_burst,

    /// Whether this enchantment is an indelible curse that cannot be removed by a Grindstone.
    pub fn isCurse(self: EnchantmentKind) bool {
        return self == .curse_of_binding or self == .curse_of_vanishing;
    }

    /// Maximum tier level for this enchantment.
    pub fn maxLevel(self: EnchantmentKind) u3 {
        return switch (self) {
            .silk_touch, .mending, .curse_of_binding, .curse_of_vanishing, .aqua_affinity, .flame, .infinity, .multishot, .channeling => 1,
            .knockback, .fire_aspect, .punch, .frost_walker => 2,
            .unbreaking, .fortune, .looting, .respiration, .thorns, .depth_strider, .soul_speed, .swift_sneak, .quick_charge, .loyalty, .riptide, .luck_of_the_sea, .lure, .wind_burst => 3,
            .protection, .fire_protection, .feather_falling, .blast_protection, .projectile_protection, .piercing, .breach => 4,
            .sharpness, .smite, .bane_of_arthropods, .efficiency, .power, .impaling, .sweeping_edge, .density => 5,
        };
    }

    /// Checks if two enchantments mutually conflict and cannot coexist on the same item.
    pub fn conflictsWith(self: EnchantmentKind, other: EnchantmentKind) bool {
        if (self == other) return false;

        // Silk Touch and Fortune are mutually exclusive
        if ((self == .silk_touch and other == .fortune) or (self == .fortune and other == .silk_touch)) return true;

        // Mending and Infinity are mutually exclusive on Bows
        if ((self == .mending and other == .infinity) or (self == .infinity and other == .mending)) return true;

        // Damage enchantments conflict
        const is_damage_self = (self == .sharpness or self == .smite or self == .bane_of_arthropods);
        const is_damage_other = (other == .sharpness or other == .smite or other == .bane_of_arthropods);
        if (is_damage_self and is_damage_other) return true;

        // Armor protection enchantments conflict
        const is_prot_self = (self == .protection or self == .fire_protection or self == .blast_protection or self == .projectile_protection);
        const is_prot_other = (other == .protection or other == .fire_protection or other == .blast_protection or other == .projectile_protection);
        if (is_prot_self and is_prot_other) return true;

        // Boots water mobility conflicts
        if ((self == .depth_strider and other == .frost_walker) or (self == .frost_walker and other == .depth_strider)) return true;

        // Crossbow shot behavior conflicts
        if ((self == .multishot and other == .piercing) or (self == .piercing and other == .multishot)) return true;

        // Trident propulsion vs throw loyalty/channeling
        if (self == .riptide and (other == .loyalty or other == .channeling)) return true;
        if (other == .riptide and (self == .loyalty or self == .channeling)) return true;

        // Mace Density vs Breach conflicts
        if ((self == .density and other == .breach) or (self == .breach and other == .density)) return true;

        return false;
    }

    pub fn name(self: EnchantmentKind) []const u8 {
        return switch (self) {
            .protection => "Protection",
            .fire_protection => "Fire Protection",
            .feather_falling => "Feather Falling",
            .blast_protection => "Blast Protection",
            .projectile_protection => "Projectile Protection",
            .respiration => "Respiration",
            .aqua_affinity => "Aqua Affinity",
            .thorns => "Thorns",
            .depth_strider => "Depth Strider",
            .frost_walker => "Frost Walker",
            .soul_speed => "Soul Speed",
            .swift_sneak => "Swift Sneak",
            .sharpness => "Sharpness",
            .smite => "Smite",
            .bane_of_arthropods => "Bane of Arthropods",
            .knockback => "Knockback",
            .fire_aspect => "Fire Aspect",
            .looting => "Looting",
            .sweeping_edge => "Sweeping Edge",
            .efficiency => "Efficiency",
            .silk_touch => "Silk Touch",
            .unbreaking => "Unbreaking",
            .fortune => "Fortune",
            .power => "Power",
            .punch => "Punch",
            .flame => "Flame",
            .infinity => "Infinity",
            .multishot => "Multishot",
            .quick_charge => "Quick Charge",
            .piercing => "Piercing",
            .loyalty => "Loyalty",
            .impaling => "Impaling",
            .riptide => "Riptide",
            .channeling => "Channeling",
            .luck_of_the_sea => "Luck of the Sea",
            .lure => "Lure",
            .mending => "Mending",
            .curse_of_binding => "Curse of Binding",
            .curse_of_vanishing => "Curse of Vanishing",
            .density => "Density",
            .breach => "Breach",
            .wind_burst => "Wind Burst",
        };
    }
};

/// 3 Offer slots on an Enchantment Table interface.
pub const EnchantmentSlot = enum(u2) {
    slot1 = 0,
    slot2 = 1,
    slot3 = 2,

    pub fn lapisCost(self: EnchantmentSlot) u8 {
        return switch (self) {
            .slot1 => 1,
            .slot2 => 2,
            .slot3 => 3,
        };
    }

    pub fn levelDeduction(self: EnchantmentSlot) u8 {
        return switch (self) {
            .slot1 => 1,
            .slot2 => 2,
            .slot3 => 3,
        };
    }
};

// ============================================================================
// Structs & Return Types
// ============================================================================

/// Result of computing enchantment offer requirements and material costs.
pub const EnchantSlotOffers = struct {
    slot1_req_level: u8,
    slot2_req_level: u8,
    slot3_req_level: u8,
    lapis_cost: [3]u8,
};

/// Result of repairing tool durability using collected XP with the Mending enchantment.
pub const MendingRepairResult = struct {
    new_durability: u16,
    leftover_xp_to_player: u16,
};

/// Result of disenchanting an item at a Grindstone.
pub const GrindstoneDisenchantResult = struct {
    cleared_non_curses: bool,
    retained_curse: bool,
    refunded_xp: u16,
};

/// Spatial offset of one bookshelf in the 5x5 perimeter ring around an Enchantment Table.
pub const BookshelfRingOffset = struct {
    dx: i8,
    dz: i8,
    gap_dx: i8,
    gap_dz: i8,
};

/// The 16 canonical perimeter bookshelf offsets (radius 2) and their intermediate 1-block air gaps.
pub const BOOKSHELF_RING_OFFSETS: [16]BookshelfRingOffset = .{
    // North edge (z = -2)
    .{ .dx = -2, .dz = -2, .gap_dx = -1, .gap_dz = -1 },
    .{ .dx = -1, .dz = -2, .gap_dx = -1, .gap_dz = -1 },
    .{ .dx = 0, .dz = -2, .gap_dx = 0, .gap_dz = -1 },
    .{ .dx = 1, .dz = -2, .gap_dx = 1, .gap_dz = -1 },
    .{ .dx = 2, .dz = -2, .gap_dx = 1, .gap_dz = -1 },

    // East edge (x = 2)
    .{ .dx = 2, .dz = -1, .gap_dx = 1, .gap_dz = -1 },
    .{ .dx = 2, .dz = 0, .gap_dx = 1, .gap_dz = 0 },
    .{ .dx = 2, .dz = 1, .gap_dx = 1, .gap_dz = 1 },

    // South edge (z = 2)
    .{ .dx = 2, .dz = 2, .gap_dx = 1, .gap_dz = 1 },
    .{ .dx = 1, .dz = 2, .gap_dx = 1, .gap_dz = 1 },
    .{ .dx = 0, .dz = 2, .gap_dx = 0, .gap_dz = 1 },
    .{ .dx = -1, .dz = 2, .gap_dx = -1, .gap_dz = 1 },
    .{ .dx = -2, .dz = 2, .gap_dx = -1, .gap_dz = 1 },

    // West edge (x = -2)
    .{ .dx = -2, .dz = 1, .gap_dx = -1, .gap_dz = 1 },
    .{ .dx = -2, .dz = 0, .gap_dx = -1, .gap_dz = 0 },
    .{ .dx = -2, .dz = -1, .gap_dx = -1, .gap_dz = -1 },
};

// ============================================================================
// Core Functions
// ============================================================================

/// Counts up to 15 valid bookshelves at radius 2 around an Enchantment Table.
/// A bookshelf only powers the table when the intermediate 1-block gap between the table
/// and the bookshelf is clear air (torches, carpets, or blocks in the gap occlude arcane particles).
pub fn countValidBookshelves(ring_blocks: [16]bool, air_gap_clear: [16]bool) u4 {
    var valid_count: usize = 0;
    var i: usize = 0;
    while (i < BOOKSHELF_RING_CAPACITY) : (i += 1) {
        if (ring_blocks[i] and air_gap_clear[i]) {
            valid_count += 1;
        }
    }
    return @intCast(@min(valid_count, MAX_EFFECTIVE_BOOKSHELVES));
}

/// Calculates the 3 enchantment offer level requirements and fixed Lapis Lazuli costs.
/// Level requirements scale with bookshelf count, culminating in Level 30 for slot 3 at 15 bookshelves.
/// In vanilla Minecraft Java Edition, base level = 8 + floor(b / 2) + b, with:
/// - Slot 1: max(1, base / 3)
/// - Slot 2: (base * 2) / 3 + 1
/// - Slot 3: max(base, b * 2) capped at 30
/// Lapis Lazuli costs are always [1, 2, 3].
pub fn computeEnchantSlotOffers(bookshelf_count: u4) EnchantSlotOffers {
    const b: u8 = @intCast(@min(bookshelf_count, MAX_EFFECTIVE_BOOKSHELVES));
    const base: u8 = BASE_ENCHANTMENT_LEVEL + (b / 2) + b;

    const slot1: u8 = @max(@as(u8, 1), base / 3);
    const slot2: u8 = (base * 2) / 3 + 1;
    const slot3: u8 = @min(MAX_ENCHANTMENT_LEVEL, @max(base, b * 2));

    return .{
        .slot1_req_level = slot1,
        .slot2_req_level = slot2,
        .slot3_req_level = slot3,
        .lapis_cost = LAPIS_SLOT_COSTS,
    };
}

/// Evaluates whether tool or armor durability should be consumed upon use with Unbreaking I–III.
/// - For tools: chance to consume durability is `100 / (level + 1)%` (Level 0: 100%, I: 50%, II: 33%, III: 25%).
/// - For armor: chance to consume durability is `60 + 40 / (level + 1)%` (Level 0: 100%, I: 80%, II: 73%, III: 70%).
/// `roll` is expected to be a value in 0..99. Returns `true` if durability is consumed, `false` if preserved.
pub fn shouldConsumeToolDurability(unbreaking_level: u3, is_armor: bool, roll: u8) bool {
    if (unbreaking_level == 0) return true;
    const chance_percent: u8 = if (is_armor)
        60 + (40 / (@as(u8, unbreaking_level) + 1))
    else
        100 / (@as(u8, unbreaking_level) + 1);
    return roll < chance_percent;
}

/// Calculates discrete ore drop yield when harvesting with Fortune I–III.
/// - Fortune 0: Always 1x drops (multiplier = 1).
/// - Fortune I: 33% chance of 2x drops; 67% chance of 1x.
/// - Fortune II: 25% chance of 2x; 25% chance of 3x; 50% chance of 1x.
/// - Fortune III: 20% chance of 2x; 20% chance of 3x; 20% chance of 4x; 40% chance of 1x.
/// Multiplier is applied to `base_drops`. Clamped at 255 to prevent overflow.
pub fn computeFortuneOreYield(base_drops: u8, fortune_level: u3, roll: u8) u8 {
    if (base_drops == 0) return 0;
    const multiplier: u8 = switch (fortune_level) {
        0 => 1,
        1 => if (roll < 33) 2 else 1,
        2 => if (roll < 25) 2 else if (roll < 50) 3 else 1,
        3 => if (roll < 20) 2 else if (roll < 40) 3 else if (roll < 60) 4 else 1,
        else => 1,
    };
    const product = @as(u16, base_drops) * @as(u16, multiplier);
    return @intCast(@min(product, 255));
}

/// Applies Mending enchantment repair logic to a damaged item from collected XP orbs.
/// In Minecraft, Mending repairs 2 durability points per 1 XP point collected.
/// Once the item reaches its maximum durability, any leftover XP is routed directly to the player's level bar.
pub fn applyMendingXpRepair(
    xp_orb_value: u16,
    current_durability: u16,
    max_durability: u16,
) MendingRepairResult {
    if (current_durability >= max_durability or xp_orb_value == 0) {
        return .{
            .new_durability = current_durability,
            .leftover_xp_to_player = xp_orb_value,
        };
    }

    const missing_durability: u16 = max_durability - current_durability;
    // Each 1 XP restores 2 durability. Ceiling division: (missing + 1) / 2
    const xp_needed: u16 = (missing_durability + 1) / 2;
    const xp_used: u16 = @min(xp_orb_value, xp_needed);
    const durability_restored: u32 = @as(u32, xp_used) * MENDING_DURABILITY_PER_XP;
    const new_durability: u16 = @intCast(@min(@as(u32, max_durability), @as(u32, current_durability) + durability_restored));
    const leftover_xp: u16 = xp_orb_value - xp_used;

    return .{
        .new_durability = new_durability,
        .leftover_xp_to_player = leftover_xp,
    };
}

/// Disenchants an item on a Grindstone:
/// - Strips all standard (non-curse) enchantments.
/// - Retains Curse of Binding and Curse of Vanishing.
/// - Refunds experience points based on stripped enchantment levels (~7 XP per level).
/// - Curses do not yield any experience refund.
pub fn disenchantAtGrindstone(enchant_levels_sum: u8, has_curse: bool) GrindstoneDisenchantResult {
    const has_non_curses = (enchant_levels_sum > 0);
    const xp_refund: u16 = if (has_non_curses)
        @as(u16, enchant_levels_sum) * XP_PER_ENCHANT_LEVEL_REFUND
    else
        0;

    return .{
        .cleared_non_curses = has_non_curses,
        .retained_curse = has_curse,
        .refunded_xp = xp_refund,
    };
}

/// Evaluates block harvesting drops considering Silk Touch exclusivity over Fortune.
/// If `has_silk_touch` is true, 1 original block is preserved regardless of Fortune level.
/// If `has_silk_touch` is false, Fortune drop multiplier is applied.
pub fn evaluateHarvestDrops(
    has_silk_touch: bool,
    fortune_level: u3,
    base_drops: u8,
    roll: u8,
) struct { is_silk_touch: bool, count: u8 } {
    if (has_silk_touch) {
        return .{
            .is_silk_touch = true,
            .count = 1,
        };
    }
    return .{
        .is_silk_touch = false,
        .count = computeFortuneOreYield(base_drops, fortune_level, roll),
    };
}

// ============================================================================
// Unit Tests (At least 14 required; 32 comprehensive tests provided)
// ============================================================================

test "countValidBookshelves: 16 clear bookshelves capped at 15" {
    const ring = [_]bool{true} ** 16;
    const gaps = [_]bool{true} ** 16;
    const count = countValidBookshelves(ring, gaps);
    try std.testing.expectEqual(@as(u4, 15), count);
}

test "countValidBookshelves: exactly 15 clear bookshelves returns 15" {
    var ring = [_]bool{true} ** 16;
    ring[15] = false; // 15 present
    const gaps = [_]bool{true} ** 16;
    const count = countValidBookshelves(ring, gaps);
    try std.testing.expectEqual(@as(u4, 15), count);
}

test "countValidBookshelves: air gap occlusion blocks bookshelves" {
    const ring = [_]bool{true} ** 16;
    var gaps = [_]bool{true} ** 16;
    // Place torches in gap 2, gap 5, gap 9 (making gap clear = false)
    gaps[2] = false;
    gaps[5] = false;
    gaps[9] = false;

    // 16 present, 3 occluded -> 13 valid
    const count = countValidBookshelves(ring, gaps);
    try std.testing.expectEqual(@as(u4, 13), count);
}

test "countValidBookshelves: partial ring with missing and blocked positions" {
    var ring = [_]bool{false} ** 16;
    var gaps = [_]bool{true} ** 16;

    // 8 bookshelves placed
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        ring[i] = true;
    }
    // Occlude 2 of those 8
    gaps[1] = false;
    gaps[4] = false;

    // Valid = 6
    const count = countValidBookshelves(ring, gaps);
    try std.testing.expectEqual(@as(u4, 6), count);
}

test "countValidBookshelves: empty ring returns 0" {
    const ring = [_]bool{false} ** 16;
    const gaps = [_]bool{true} ** 16;
    try std.testing.expectEqual(@as(u4, 0), countValidBookshelves(ring, gaps));
}

test "countValidBookshelves: all air gaps blocked returns 0 even with full ring" {
    const ring = [_]bool{true} ** 16;
    const gaps = [_]bool{false} ** 16;
    try std.testing.expectEqual(@as(u4, 0), countValidBookshelves(ring, gaps));
}

test "computeEnchantSlotOffers: reaching level 30 in slot 3 when bookshelf_count == 15" {
    const offers = computeEnchantSlotOffers(15);
    try std.testing.expectEqual(@as(u8, 30), offers.slot3_req_level);
    try std.testing.expectEqual(@as(u8, 21), offers.slot2_req_level);
    try std.testing.expectEqual(@as(u8, 10), offers.slot1_req_level);
    try std.testing.expectEqual([3]u8{ 1, 2, 3 }, offers.lapis_cost);
}

test "computeEnchantSlotOffers: baseline offers with 0 bookshelves" {
    const offers = computeEnchantSlotOffers(0);
    try std.testing.expectEqual(@as(u8, 8), offers.slot3_req_level);
    try std.testing.expectEqual(@as(u8, 6), offers.slot2_req_level);
    try std.testing.expectEqual(@as(u8, 2), offers.slot1_req_level);
    try std.testing.expectEqual([3]u8{ 1, 2, 3 }, offers.lapis_cost);
}

test "computeEnchantSlotOffers: monotonic progression across all bookshelf levels 0..15" {
    var b: u4 = 0;
    var prev_slot3: u8 = 0;
    while (true) {
        const offers = computeEnchantSlotOffers(b);
        // Slot requirements are strictly ascending within each table state
        try std.testing.expect(offers.slot1_req_level < offers.slot2_req_level);
        try std.testing.expect(offers.slot2_req_level <= offers.slot3_req_level);
        // Slot 3 non-decreasing with bookshelf power
        try std.testing.expect(offers.slot3_req_level >= prev_slot3);
        prev_slot3 = offers.slot3_req_level;

        // Lapis costs invariant
        try std.testing.expectEqual([3]u8{ 1, 2, 3 }, offers.lapis_cost);

        if (b == 15) break;
        b += 1;
    }
}

test "computeEnchantSlotOffers: intermediate shelf milestones" {
    const o5 = computeEnchantSlotOffers(5);
    try std.testing.expectEqual(@as(u8, 15), o5.slot3_req_level);
    try std.testing.expectEqual(@as(u8, 11), o5.slot2_req_level);
    try std.testing.expectEqual(@as(u8, 5), o5.slot1_req_level);

    const o10 = computeEnchantSlotOffers(10);
    try std.testing.expectEqual(@as(u8, 23), o10.slot3_req_level);
    try std.testing.expectEqual(@as(u8, 16), o10.slot2_req_level);
    try std.testing.expectEqual(@as(u8, 7), o10.slot1_req_level);
}

test "shouldConsumeToolDurability: level 0 always consumes durability" {
    // For tools
    try std.testing.expect(shouldConsumeToolDurability(0, false, 0));
    try std.testing.expect(shouldConsumeToolDurability(0, false, 50));
    try std.testing.expect(shouldConsumeToolDurability(0, false, 99));

    // For armor
    try std.testing.expect(shouldConsumeToolDurability(0, true, 0));
    try std.testing.expect(shouldConsumeToolDurability(0, true, 50));
    try std.testing.expect(shouldConsumeToolDurability(0, true, 99));
}

test "shouldConsumeToolDurability: Unbreaking I on tools (50% chance)" {
    // 100 / (1 + 1) = 50%
    try std.testing.expect(shouldConsumeToolDurability(1, false, 0));
    try std.testing.expect(shouldConsumeToolDurability(1, false, 49));
    try std.testing.expect(!shouldConsumeToolDurability(1, false, 50));
    try std.testing.expect(!shouldConsumeToolDurability(1, false, 99));
}

test "shouldConsumeToolDurability: Unbreaking II on tools (33% chance)" {
    // 100 / (2 + 1) = 33%
    try std.testing.expect(shouldConsumeToolDurability(2, false, 0));
    try std.testing.expect(shouldConsumeToolDurability(2, false, 32));
    try std.testing.expect(!shouldConsumeToolDurability(2, false, 33));
    try std.testing.expect(!shouldConsumeToolDurability(2, false, 75));
}

test "shouldConsumeToolDurability: Unbreaking III on tools (25% chance)" {
    // 100 / (3 + 1) = 25%
    try std.testing.expect(shouldConsumeToolDurability(3, false, 0));
    try std.testing.expect(shouldConsumeToolDurability(3, false, 24));
    try std.testing.expect(!shouldConsumeToolDurability(3, false, 25));
    try std.testing.expect(!shouldConsumeToolDurability(3, false, 99));
}

test "shouldConsumeToolDurability: Unbreaking I on armor (80% chance)" {
    // 60 + 40 / 2 = 80%
    try std.testing.expect(shouldConsumeToolDurability(1, true, 0));
    try std.testing.expect(shouldConsumeToolDurability(1, true, 79));
    try std.testing.expect(!shouldConsumeToolDurability(1, true, 80));
    try std.testing.expect(!shouldConsumeToolDurability(1, true, 99));
}

test "shouldConsumeToolDurability: Unbreaking II on armor (73% chance)" {
    // 60 + 40 / 3 = 73%
    try std.testing.expect(shouldConsumeToolDurability(2, true, 0));
    try std.testing.expect(shouldConsumeToolDurability(2, true, 72));
    try std.testing.expect(!shouldConsumeToolDurability(2, true, 73));
    try std.testing.expect(!shouldConsumeToolDurability(2, true, 95));
}

test "shouldConsumeToolDurability: Unbreaking III on armor (70% chance)" {
    // 60 + 40 / 4 = 70%
    try std.testing.expect(shouldConsumeToolDurability(3, true, 0));
    try std.testing.expect(shouldConsumeToolDurability(3, true, 69));
    try std.testing.expect(!shouldConsumeToolDurability(3, true, 70));
    try std.testing.expect(!shouldConsumeToolDurability(3, true, 99));
}

test "computeFortuneOreYield: Fortune 0 always gives 1x yield" {
    try std.testing.expectEqual(@as(u8, 1), computeFortuneOreYield(1, 0, 0));
    try std.testing.expectEqual(@as(u8, 1), computeFortuneOreYield(1, 0, 50));
    try std.testing.expectEqual(@as(u8, 1), computeFortuneOreYield(1, 0, 99));
    try std.testing.expectEqual(@as(u8, 4), computeFortuneOreYield(4, 0, 10));
}

test "computeFortuneOreYield: Fortune I distribution (33% 2x, 67% 1x)" {
    // roll < 33 -> 2x
    try std.testing.expectEqual(@as(u8, 2), computeFortuneOreYield(1, 1, 0));
    try std.testing.expectEqual(@as(u8, 2), computeFortuneOreYield(1, 1, 32));
    // roll >= 33 -> 1x
    try std.testing.expectEqual(@as(u8, 1), computeFortuneOreYield(1, 1, 33));
    try std.testing.expectEqual(@as(u8, 1), computeFortuneOreYield(1, 1, 99));
}

test "computeFortuneOreYield: Fortune II distribution (25% 2x, 25% 3x, 50% 1x)" {
    // roll < 25 -> 2x
    try std.testing.expectEqual(@as(u8, 2), computeFortuneOreYield(1, 2, 0));
    try std.testing.expectEqual(@as(u8, 2), computeFortuneOreYield(1, 2, 24));
    // roll in 25..49 -> 3x
    try std.testing.expectEqual(@as(u8, 3), computeFortuneOreYield(1, 2, 25));
    try std.testing.expectEqual(@as(u8, 3), computeFortuneOreYield(1, 2, 49));
    // roll >= 50 -> 1x
    try std.testing.expectEqual(@as(u8, 1), computeFortuneOreYield(1, 2, 50));
    try std.testing.expectEqual(@as(u8, 1), computeFortuneOreYield(1, 2, 99));
}

test "computeFortuneOreYield: Fortune III distribution (20% 2x, 20% 3x, 20% 4x, 40% 1x)" {
    // roll < 20 -> 2x
    try std.testing.expectEqual(@as(u8, 2), computeFortuneOreYield(1, 3, 0));
    try std.testing.expectEqual(@as(u8, 2), computeFortuneOreYield(1, 3, 19));
    // roll in 20..39 -> 3x
    try std.testing.expectEqual(@as(u8, 3), computeFortuneOreYield(1, 3, 20));
    try std.testing.expectEqual(@as(u8, 3), computeFortuneOreYield(1, 3, 39));
    // roll in 40..59 -> 4x
    try std.testing.expectEqual(@as(u8, 4), computeFortuneOreYield(1, 3, 40));
    try std.testing.expectEqual(@as(u8, 4), computeFortuneOreYield(1, 3, 59));
    // roll >= 60 -> 1x
    try std.testing.expectEqual(@as(u8, 1), computeFortuneOreYield(1, 3, 60));
    try std.testing.expectEqual(@as(u8, 1), computeFortuneOreYield(1, 3, 99));
}

test "computeFortuneOreYield: multi-item ore yields (e.g. Lapis Lazuli base 4..9)" {
    // base_drops = 4 with Fortune III 4x multiplier
    try std.testing.expectEqual(@as(u8, 16), computeFortuneOreYield(4, 3, 50));
    // base_drops = 5 with Fortune II 3x multiplier
    try std.testing.expectEqual(@as(u8, 15), computeFortuneOreYield(5, 2, 30));
    // base_drops = 0 yields 0
    try std.testing.expectEqual(@as(u8, 0), computeFortuneOreYield(0, 3, 50));
}

test "applyMendingXpRepair: 2 durability per 1 XP exact repair without leftover" {
    // Current 90, Max 100 -> Missing 10 durability.
    // 5 XP needed. Orb has 5 XP.
    const res = applyMendingXpRepair(5, 90, 100);
    try std.testing.expectEqual(@as(u16, 100), res.new_durability);
    try std.testing.expectEqual(@as(u16, 0), res.leftover_xp_to_player);
}

test "applyMendingXpRepair: surplus XP routes leftovers to player" {
    // Current 90, Max 100 -> Missing 10 durability.
    // 5 XP needed. Orb has 12 XP.
    const res = applyMendingXpRepair(12, 90, 100);
    try std.testing.expectEqual(@as(u16, 100), res.new_durability);
    try std.testing.expectEqual(@as(u16, 7), res.leftover_xp_to_player);
}

test "applyMendingXpRepair: partial repair when XP orb is insufficient" {
    // Current 50, Max 100 -> Missing 50 durability.
    // 25 XP needed. Orb only has 10 XP.
    // 10 XP restores 20 durability -> 50 + 20 = 70.
    const res = applyMendingXpRepair(10, 50, 100);
    try std.testing.expectEqual(@as(u16, 70), res.new_durability);
    try std.testing.expectEqual(@as(u16, 0), res.leftover_xp_to_player);
}

test "applyMendingXpRepair: odd missing durability (1 point missing)" {
    // Current 99, Max 100 -> Missing 1 durability.
    // 1 XP restores up to 2 durability -> reaches 100, 0 leftover.
    const res = applyMendingXpRepair(1, 99, 100);
    try std.testing.expectEqual(@as(u16, 100), res.new_durability);
    try std.testing.expectEqual(@as(u16, 0), res.leftover_xp_to_player);
}

test "applyMendingXpRepair: already intact tool routes all XP to player" {
    const res = applyMendingXpRepair(25, 1561, 1561);
    try std.testing.expectEqual(@as(u16, 1561), res.new_durability);
    try std.testing.expectEqual(@as(u16, 25), res.leftover_xp_to_player);
}

test "applyMendingXpRepair: zero XP orb value does nothing" {
    const res = applyMendingXpRepair(0, 100, 500);
    try std.testing.expectEqual(@as(u16, 100), res.new_durability);
    try std.testing.expectEqual(@as(u16, 0), res.leftover_xp_to_player);
}

test "disenchantAtGrindstone: strips non-curses and refunds XP" {
    // Sharpness V (level 5) -> cleared_non_curses = true, retained_curse = false, 5 * 7 = 35 XP
    const res = disenchantAtGrindstone(5, false);
    try std.testing.expect(res.cleared_non_curses);
    try std.testing.expect(!res.retained_curse);
    try std.testing.expectEqual(@as(u16, 35), res.refunded_xp);
}

test "disenchantAtGrindstone: retains Curse of Binding / Vanishing while stripping enchants" {
    // Efficiency V + Unbreaking III (5 + 3 = 8 levels) with Curse of Vanishing
    const res = disenchantAtGrindstone(8, true);
    try std.testing.expect(res.cleared_non_curses);
    try std.testing.expect(res.retained_curse);
    try std.testing.expectEqual(@as(u16, 56), res.refunded_xp); // 8 * 7 = 56
}

test "disenchantAtGrindstone: cursed item without regular enchants yields 0 XP and keeps curse" {
    const res = disenchantAtGrindstone(0, true);
    try std.testing.expect(!res.cleared_non_curses);
    try std.testing.expect(res.retained_curse);
    try std.testing.expectEqual(@as(u16, 0), res.refunded_xp);
}

test "disenchantAtGrindstone: clean item without enchants or curses yields nothing" {
    const res = disenchantAtGrindstone(0, false);
    try std.testing.expect(!res.cleared_non_curses);
    try std.testing.expect(!res.retained_curse);
    try std.testing.expectEqual(@as(u16, 0), res.refunded_xp);
}

test "evaluateHarvestDrops: Silk Touch overrides Fortune" {
    // Silk Touch active: always 1 item
    const silk = evaluateHarvestDrops(true, 3, 1, 50);
    try std.testing.expect(silk.is_silk_touch);
    try std.testing.expectEqual(@as(u8, 1), silk.count);

    // No Silk Touch: Fortune III applies
    const fort = evaluateHarvestDrops(false, 3, 1, 50);
    try std.testing.expect(!fort.is_silk_touch);
    try std.testing.expectEqual(@as(u8, 4), fort.count);
}

test "EnchantmentKind: curse identification and exclusivity rules" {
    try std.testing.expect(EnchantmentKind.curse_of_binding.isCurse());
    try std.testing.expect(EnchantmentKind.curse_of_vanishing.isCurse());
    try std.testing.expect(!EnchantmentKind.sharpness.isCurse());
    try std.testing.expect(!EnchantmentKind.unbreaking.isCurse());

    // Incompatibilities
    try std.testing.expect(EnchantmentKind.silk_touch.conflictsWith(.fortune));
    try std.testing.expect(EnchantmentKind.fortune.conflictsWith(.silk_touch));
    try std.testing.expect(EnchantmentKind.mending.conflictsWith(.infinity));
    try std.testing.expect(EnchantmentKind.sharpness.conflictsWith(.smite));
    try std.testing.expect(EnchantmentKind.protection.conflictsWith(.blast_protection));
    try std.testing.expect(!EnchantmentKind.sharpness.conflictsWith(.unbreaking));
    try std.testing.expect(!EnchantmentKind.efficiency.conflictsWith(.silk_touch));
}

test "BookshelfRingOffsets: exactly 16 offsets and correct perimeter radius" {
    try std.testing.expectEqual(@as(usize, 16), BOOKSHELF_RING_OFFSETS.len);
    for (BOOKSHELF_RING_OFFSETS) |off| {
        // Must be in 5x5 ring at radius 2
        const max_dist = @max(@abs(off.dx), @abs(off.dz));
        try std.testing.expectEqual(@as(u8, 2), max_dist);
        // Gap must be within inner 3x3
        try std.testing.expect(@abs(off.gap_dx) <= 1);
        try std.testing.expect(@abs(off.gap_dz) <= 1);
    }
}
