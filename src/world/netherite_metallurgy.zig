//! Milestone 386: Ancient Debris Subterranean Distribution, Bed/TNT Blast Mining,
//! Netherite Ingot Refining & Lava-Buoyant Items.
//!
//! Provides mechanics for:
//! 1. Ancient Debris subterranean generation with peak triangular distribution
//!    at Y=15 (Y=8..22, 1..3 blocks) and secondary uniform vein (Y=8..119, 1..2 blocks),
//!    strictly enforcing never_exposed_to_air.
//! 2. Blast resistance (1200.0) and immunity to TNT and Nether Bed explosions,
//!    enabling bed/TNT blast mining, hardness (30.0), and diamond/netherite pickaxe harvesting.
//! 3. Smelting 1 Ancient Debris into 1 Netherite Scrap (2.0 XP) and shapeless crafting of
//!    4 Netherite Scraps + 4 Gold Ingots into 1 Netherite Ingot.
//! 4. Fire and lava immunity for all Netherite gear/items, plus vertical buoyancy
//!    lifting dropped items upward to float at the lava surface.
//! 5. Armor knockback resistance granting +10% (0.10) per equipped piece up to 0.40
//!    for a full 4-piece suit.

const std = @import("std");

// ============================================================================
// 1. Ancient Debris Distribution
// ============================================================================

pub const AncientDebrisDistribution = struct {
    /// In Minecraft, Ancient Debris NEVER generates naturally exposed to air.
    pub const never_exposed_to_air: bool = true;

    /// Primary vein height limits (triangular distribution centered at Y=15).
    pub const PRIMARY_MIN_Y: i32 = 8;
    pub const PRIMARY_MAX_Y: i32 = 22;
    pub const PRIMARY_PEAK_Y: i32 = 15;
    pub const PRIMARY_MIN_VEIN_SIZE: u8 = 1;
    pub const PRIMARY_MAX_VEIN_SIZE: u8 = 3;

    /// Secondary scattered vein height limits (uniform distribution across Nether).
    pub const SECONDARY_MIN_Y: i32 = 8;
    pub const SECONDARY_MAX_Y: i32 = 119;
    pub const SECONDARY_MIN_VEIN_SIZE: u8 = 1;
    pub const SECONDARY_MAX_VEIN_SIZE: u8 = 2;

    pub const VeinType = enum {
        primary_triangular,
        secondary_uniform,
    };

    /// Checks whether Ancient Debris can spawn at the specified Y level and air contact.
    /// Returns false if adjacent to air, or if Y is outside the valid Nether generation range [8..119].
    pub fn canSpawnAncientDebrisAt(y: i32, adjacent_to_air: bool) bool {
        if (AncientDebrisDistribution.never_exposed_to_air and adjacent_to_air) return false;
        return y >= SECONDARY_MIN_Y and y <= SECONDARY_MAX_Y;
    }

    /// Checks if a coordinate is valid for the primary triangular vein (Y = 8..22, unexposed).
    pub fn canSpawnPrimaryVein(y: i32, adjacent_to_air: bool) bool {
        if (AncientDebrisDistribution.never_exposed_to_air and adjacent_to_air) return false;
        return y >= PRIMARY_MIN_Y and y <= PRIMARY_MAX_Y;
    }

    /// Checks if a coordinate is valid for the secondary uniform vein (Y = 8..119, unexposed).
    pub fn canSpawnSecondaryVein(y: i32, adjacent_to_air: bool) bool {
        if (AncientDebrisDistribution.never_exposed_to_air and adjacent_to_air) return false;
        return y >= SECONDARY_MIN_Y and y <= SECONDARY_MAX_Y;
    }

    /// Calculates the triangular distribution weight for the primary vein centered at Y=15.
    /// Peak at Y=15 gives 1.0; falls linearly to 0.0 at Y=8 and Y=22.
    /// Values outside [8..22] yield 0.0.
    pub fn primaryTriangularWeight(y: i32) f32 {
        if (y < PRIMARY_MIN_Y or y > PRIMARY_MAX_Y) return 0.0;
        const dist = @abs(y - PRIMARY_PEAK_Y);
        const half_span: f32 = @floatFromInt(PRIMARY_MAX_Y - PRIMARY_PEAK_Y); // 7.0
        const normalized_dist: f32 = @as(f32, @floatFromInt(dist)) / half_span;
        return 1.0 - normalized_dist;
    }

    /// Returns the vein block count given a normalized random roll (0.0 to 1.0).
    pub fn sampleVeinSize(vein_type: VeinType, roll: f32) u8 {
        const clamped = std.math.clamp(roll, 0.0, 1.0);
        return switch (vein_type) {
            .primary_triangular => blk: {
                // 1..3 blocks
                if (clamped < 0.333) break :blk 1;
                if (clamped < 0.667) break :blk 2;
                break :blk 3;
            },
            .secondary_uniform => blk: {
                // 1..2 blocks
                if (clamped < 0.5) break :blk 1;
                break :blk 2;
            },
        };
    }
};

pub const canSpawnAncientDebrisAt = AncientDebrisDistribution.canSpawnAncientDebrisAt;
pub const never_exposed_to_air: bool = AncientDebrisDistribution.never_exposed_to_air;

// ============================================================================
// 2. Ancient Debris Mining & Blast Resistance
// ============================================================================

pub const ToolTier = enum(u8) {
    hand = 0,
    wooden = 1,
    stone = 2,
    iron = 3,
    golden = 4,
    diamond = 5,
    netherite = 6,

    pub fn miningSpeedMultiplier(self: ToolTier) f32 {
        return switch (self) {
            .hand => 1.0,
            .wooden => 2.0,
            .stone => 4.0,
            .iron => 6.0,
            .golden => 12.0,
            .diamond => 8.0,
            .netherite => 9.0,
        };
    }
};

pub const AncientDebrisMining = struct {
    /// Blast resistance in Minecraft: 1200.0 (identical to Obsidian/Respawn Anchor/Crying Obsidian).
    pub const blast_resistance: f32 = 1200.0;

    /// Hardness in Minecraft: 30.0.
    pub const hardness: f32 = 30.0;

    /// Blast resistance of Netherrack: 0.4 (extremely brittle, easily cleared by explosions).
    pub const netherrack_blast_resistance: f32 = 0.4;

    /// Explosion power of primed TNT in Minecraft.
    pub const tnt_explosion_power: f32 = 4.0;

    /// Explosion power of a Bed detonated in the Nether.
    pub const bed_explosion_power: f32 = 5.0;

    /// Threshold blast resistance above which standard explosive blasts cannot break the block.
    pub const BLAST_IMMUNITY_RESISTANCE: f32 = 1200.0;

    /// Returns true because blast_resistance (1200.0) is immune to TNT and Bed explosions.
    pub fn immuneToTntAndBedExplosions() bool {
        return AncientDebrisMining.blast_resistance >= BLAST_IMMUNITY_RESISTANCE;
    }

    /// Evaluates if a block with a given blast resistance survives an explosion of power `blast_power`.
    /// In Minecraft, an explosion ray loses power based on (blast_resistance / 5.0 + 0.3) * 0.3 per step.
    /// A resistance of 1200.0 absorbs over 72 blast units per block step, stopping TNT (power 4.0)
    /// and Beds (power 5.0) dead in their tracks.
    pub fn survivesExplosion(block_resistance: f32, blast_power: f32) bool {
        const required_power_to_destroy = (block_resistance / 5.0 + 0.3) * 0.3;
        return blast_power < required_power_to_destroy;
    }

    /// Checks if a tool tier can harvest Ancient Debris.
    /// Only Diamond or Netherite pickaxes can harvest Ancient Debris.
    pub fn canHarvestAncientDebris(tool_tier: anytype) bool {
        const T = @TypeOf(tool_tier);
        if (T == ToolTier) {
            return tool_tier == .diamond or tool_tier == .netherite;
        }
        if (@typeInfo(T) == .@"enum" or @typeInfo(T) == .enum_literal) {
            const name = @tagName(tool_tier);
            return std.mem.eql(u8, name, "diamond") or
                   std.mem.eql(u8, name, "netherite") or
                   std.mem.eql(u8, name, "diamond_pickaxe") or
                   std.mem.eql(u8, name, "netherite_pickaxe");
        }
        if (@typeInfo(T) == .int or @typeInfo(T) == .comptime_int) {
            return tool_tier == @intFromEnum(ToolTier.diamond) or
                   tool_tier == @intFromEnum(ToolTier.netherite) or
                   tool_tier == 73; // Netherite pickaxe item ID in game
        }
        return false;
    }

    /// Computes the time in seconds to break an Ancient Debris block given a tool tier.
    /// When using an effective tool that can harvest:
    ///   time = (hardness * 1.5) / speed_multiplier.
    /// When using an ineffective tool:
    ///   time = hardness * 5.0 (and no drop is yielded).
    pub fn calculateBreakTime(tier: ToolTier) f32 {
        if (AncientDebrisMining.canHarvestAncientDebris(tier)) {
            return (AncientDebrisMining.hardness * 1.5) / tier.miningSpeedMultiplier();
        } else {
            return AncientDebrisMining.hardness * 5.0;
        }
    }
};

pub const blast_resistance: f32 = AncientDebrisMining.blast_resistance;
pub const hardness: f32 = AncientDebrisMining.hardness;
pub const immuneToTntAndBedExplosions = AncientDebrisMining.immuneToTntAndBedExplosions;
pub const canHarvestAncientDebris = AncientDebrisMining.canHarvestAncientDebris;

// ============================================================================
// 3. Netherite Ingot Refining (Smelting & Crafting)
// ============================================================================

pub const NetheriteIngotRefining = struct {
    /// 1 Ancient Debris produces exactly 1 Netherite Scrap when smelted.
    pub const SCRAP_PER_DEBRIS: u8 = 1;

    /// Smelting Ancient Debris awards 2.0 experience points per block (highest ore XP).
    pub const SMELT_XP_PER_DEBRIS: f32 = 2.0;

    /// 4 Netherite Scraps required per Netherite Ingot.
    pub const SCRAPS_PER_INGOT: u8 = 4;

    /// 4 Gold Ingots required per Netherite Ingot.
    pub const GOLD_INGOTS_PER_INGOT: u8 = 4;

    pub const SmeltResult = struct {
        scraps: u32,
        xp: f32,
    };

    pub const CraftingResult = struct {
        ingots: u8,
        remaining_scraps: u8,
        remaining_gold: u8,
    };

    /// Smelts Ancient Debris blocks in a furnace or blast furnace.
    /// Yields 1 Netherite Scrap and 2.0 XP per debris.
    pub fn smeltAncientDebris(debris_count: u32) SmeltResult {
        return .{
            .scraps = debris_count * SCRAP_PER_DEBRIS,
            .xp = @as(f32, @floatFromInt(debris_count)) * SMELT_XP_PER_DEBRIS,
        };
    }

    /// Shapeless crafting: 4 Netherite Scraps + 4 Gold Ingots -> 1 Netherite Ingot.
    /// Returns the number of Netherite Ingots crafted.
    pub fn craftNetheriteIngot(scraps: u8, gold_ingots: u8) u8 {
        const from_scraps = scraps / SCRAPS_PER_INGOT;
        const from_gold = gold_ingots / GOLD_INGOTS_PER_INGOT;
        return @min(from_scraps, from_gold);
    }

    /// Detailed crafting recipe calculating output ingots and remaining ingredients.
    pub fn craftNetheriteIngotDetailed(scraps: u8, gold_ingots: u8) CraftingResult {
        const ingots = NetheriteIngotRefining.craftNetheriteIngot(scraps, gold_ingots);
        return .{
            .ingots = ingots,
            .remaining_scraps = scraps - (ingots * SCRAPS_PER_INGOT),
            .remaining_gold = gold_ingots - (ingots * GOLD_INGOTS_PER_INGOT),
        };
    }

    /// Checks if sufficient ingredients exist to craft at least 1 Netherite Ingot.
    pub fn canCraftNetheriteIngot(scraps: u8, gold_ingots: u8) bool {
        return scraps >= SCRAPS_PER_INGOT and gold_ingots >= GOLD_INGOTS_PER_INGOT;
    }
};

pub const craftNetheriteIngot = NetheriteIngotRefining.craftNetheriteIngot;
pub const smeltAncientDebris = NetheriteIngotRefining.smeltAncientDebris;

// ============================================================================
// 4. Lava-Buoyant Items (Fire/Lava Immunity & Buoyancy Physics)
// ============================================================================

pub const NetheriteItemType = enum {
    ancient_debris,
    netherite_scrap,
    netherite_ingot,
    netherite_block,
    netherite_helmet,
    netherite_chestplate,
    netherite_leggings,
    netherite_boots,
    netherite_sword,
    netherite_pickaxe,
    netherite_axe,
    netherite_shovel,
    netherite_hoe,
    // Representative non-netherite items for comparison
    diamond,
    diamond_pickaxe,
    gold_ingot,
    iron_ingot,
    netherrack,
    cobblestone,

    pub fn isImmuneToLavaAndFire(self: NetheriteItemType) bool {
        return switch (self) {
            .ancient_debris,
            .netherite_scrap,
            .netherite_ingot,
            .netherite_block,
            .netherite_helmet,
            .netherite_chestplate,
            .netherite_leggings,
            .netherite_boots,
            .netherite_sword,
            .netherite_pickaxe,
            .netherite_axe,
            .netherite_shovel,
            .netherite_hoe => true,
            else => false,
        };
    }
};

pub const LavaBuoyantItem = struct {
    item_type: NetheriteItemType = .ancient_debris,
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,
    vy: f32 = 0.0,
    in_lava: bool = false,
    in_fire: bool = false,

    /// Constant upward buoyancy acceleration in lava.
    pub const LAVA_BUOYANCY_ACCEL: f32 = 0.05;
    /// Drag factor in lava.
    pub const LAVA_DRAG: f32 = 0.90;
    /// Maximum upward floating speed at the lava surface.
    pub const LAVA_TERMINAL_FLOAT_VY: f32 = 0.10;

    /// Checks if this item instance is immune to fire and lava destruction.
    pub fn isImmuneToLavaAndFire(self: LavaBuoyantItem) bool {
        return self.item_type.isImmuneToLavaAndFire();
    }

    /// Computes the upward buoyant vertical velocity in lava.
    /// When submerged in lava, a buoyant item reverses downward velocity,
    /// accelerates upward, and settles at a positive terminal upward float velocity.
    pub fn computeLavaBuoyancyVy(current_vy: f32) f32 {
        if (current_vy < 0.0) {
            // Rapidly damp downward sinking momentum and apply upward lift
            const damped = current_vy * 0.5 + LAVA_BUOYANCY_ACCEL;
            return if (damped > 0.0) @min(damped, LAVA_TERMINAL_FLOAT_VY) else damped;
        }
        // Accelerate or maintain upward float speed up to terminal float velocity
        return @min(current_vy * LAVA_DRAG + LAVA_BUOYANCY_ACCEL, LAVA_TERMINAL_FLOAT_VY);
    }

    pub fn init(item_type: NetheriteItemType) LavaBuoyantItem {
        return .{
            .item_type = item_type,
        };
    }

    /// Updates item physics when dropped into lava.
    /// Returns true if item survives and floats, false if incinerated.
    pub fn tickInLava(self: *LavaBuoyantItem) bool {
        if (!self.isImmuneToLavaAndFire()) {
            return false; // Non-netherite item burns up
        }
        self.in_lava = true;
        self.vy = LavaBuoyantItem.computeLavaBuoyancyVy(self.vy);
        self.y += self.vy;
        return true;
    }
};

pub const computeLavaBuoyancyVy = LavaBuoyantItem.computeLavaBuoyancyVy;

/// Universal immunity check supporting NetheriteItemType, LavaBuoyantItem, or generic enum.
pub fn isImmuneToLavaAndFire(target: anytype) bool {
    const T = @TypeOf(target);
    if (T == LavaBuoyantItem or T == *const LavaBuoyantItem or T == *LavaBuoyantItem) {
        return target.isImmuneToLavaAndFire();
    }
    if (T == NetheriteItemType) {
        return target.isImmuneToLavaAndFire();
    }
    if (@typeInfo(T) == .@"enum" or @typeInfo(T) == .enum_literal) {
        const name = @tagName(target);
        if (std.mem.startsWith(u8, name, "netherite_") or
            std.mem.eql(u8, name, "ancient_debris") or
            std.mem.eql(u8, name, "netherite_block"))
        {
            return true;
        }
        return false;
    }
    return false;
}

// ============================================================================
// 5. Netherite Knockback Resistance
// ============================================================================

pub const NetheriteKnockbackResistance = struct {
    /// Each Netherite armor piece provides +10% (0.10) knockback resistance.
    pub const RESISTANCE_PER_PIECE: f32 = 0.10;

    /// Standard armor consists of 4 pieces (helmet, chestplate, leggings, boots).
    pub const MAX_ARMOR_PIECES: u3 = 4;

    /// Full 4-piece Netherite suit grants 40% (0.40) total knockback resistance.
    pub const FULL_SUIT_RESISTANCE: f32 = 0.40;

    /// Calculates total knockback resistance granted by 0 to 4 equipped Netherite pieces.
    /// 0 pieces -> 0.00 (0%)
    /// 1 piece  -> 0.10 (10%)
    /// 2 pieces -> 0.20 (20%)
    /// 3 pieces -> 0.30 (30%)
    /// 4 pieces -> 0.40 (40%)
    pub fn totalKnockbackResistance(pieces_0_to_4: u3) f32 {
        const count = @min(pieces_0_to_4, MAX_ARMOR_PIECES);
        return @as(f32, @floatFromInt(count)) * RESISTANCE_PER_PIECE;
    }

    /// Counts how many Netherite armor pieces are equipped given slot booleans.
    pub fn countPieces(helmet: bool, chestplate: bool, leggings: bool, boots: bool) u3 {
        var count: u3 = 0;
        if (helmet) count += 1;
        if (chestplate) count += 1;
        if (leggings) count += 1;
        if (boots) count += 1;
        return count;
    }

    /// Applies Netherite knockback reduction to an incoming knockback impulse.
    pub fn applyKnockbackReduction(raw_knockback: f32, pieces_0_to_4: u3) f32 {
        const resistance = NetheriteKnockbackResistance.totalKnockbackResistance(pieces_0_to_4);
        return raw_knockback * (1.0 - resistance);
    }
};

pub const totalKnockbackResistance = NetheriteKnockbackResistance.totalKnockbackResistance;

// ============================================================================
// Unit Tests
// ============================================================================

test "1. ancient debris never spawns adjacent to air" {
    // Air adjacency must always prevent ancient debris from generating
    try std.testing.expect(!canSpawnAncientDebrisAt(15, true));
    try std.testing.expect(!canSpawnAncientDebrisAt(10, true));
    try std.testing.expect(!canSpawnAncientDebrisAt(8, true));
    try std.testing.expect(!canSpawnAncientDebrisAt(22, true));
    try std.testing.expect(!canSpawnAncientDebrisAt(64, true));
    try std.testing.expect(!canSpawnAncientDebrisAt(100, true));

    // When not exposed to air, valid Nether coordinates return true
    try std.testing.expect(canSpawnAncientDebrisAt(15, false));
    try std.testing.expect(canSpawnAncientDebrisAt(10, false));
    try std.testing.expect(canSpawnAncientDebrisAt(64, false));
}

test "2. ancient debris vertical distribution bounds check" {
    // Valid Nether subterranean range: Y = 8..119
    try std.testing.expect(canSpawnAncientDebrisAt(8, false));
    try std.testing.expect(canSpawnAncientDebrisAt(15, false));
    try std.testing.expect(canSpawnAncientDebrisAt(119, false));

    // Below bedrock floor or above ceiling: invalid
    try std.testing.expect(!canSpawnAncientDebrisAt(7, false));
    try std.testing.expect(!canSpawnAncientDebrisAt(0, false));
    try std.testing.expect(!canSpawnAncientDebrisAt(-5, false));
    try std.testing.expect(!canSpawnAncientDebrisAt(120, false));
    try std.testing.expect(!canSpawnAncientDebrisAt(128, false));
    try std.testing.expect(!canSpawnAncientDebrisAt(256, false));
}

test "3. primary vein triangular distribution peaks at y=15" {
    // Primary vein range: 8..22 with peak at 15
    const peak_weight = AncientDebrisDistribution.primaryTriangularWeight(15);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), peak_weight, 0.001);

    // Symmetric falloff around Y=15
    const w14 = AncientDebrisDistribution.primaryTriangularWeight(14);
    const w16 = AncientDebrisDistribution.primaryTriangularWeight(16);
    try std.testing.expectApproxEqAbs(w14, w16, 0.001);
    try std.testing.expect(w14 < peak_weight);

    const w10 = AncientDebrisDistribution.primaryTriangularWeight(10);
    const w20 = AncientDebrisDistribution.primaryTriangularWeight(20);
    try std.testing.expectApproxEqAbs(w10, w20, 0.001);
    try std.testing.expect(w10 < w14);

    // Range boundaries Y=8 and Y=22 fall to 0.0
    const w8 = AncientDebrisDistribution.primaryTriangularWeight(8);
    const w22 = AncientDebrisDistribution.primaryTriangularWeight(22);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), w8, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), w22, 0.001);

    // Outside primary range yields 0.0
    try std.testing.expectEqual(@as(f32, 0.0), AncientDebrisDistribution.primaryTriangularWeight(7));
    try std.testing.expectEqual(@as(f32, 0.0), AncientDebrisDistribution.primaryTriangularWeight(23));
}

test "4. primary and secondary vein size generation ranges" {
    // Primary vein: 1..3 blocks
    try std.testing.expectEqual(@as(u8, 1), AncientDebrisDistribution.sampleVeinSize(.primary_triangular, 0.0));
    try std.testing.expectEqual(@as(u8, 1), AncientDebrisDistribution.sampleVeinSize(.primary_triangular, 0.2));
    try std.testing.expectEqual(@as(u8, 2), AncientDebrisDistribution.sampleVeinSize(.primary_triangular, 0.5));
    try std.testing.expectEqual(@as(u8, 3), AncientDebrisDistribution.sampleVeinSize(.primary_triangular, 0.8));
    try std.testing.expectEqual(@as(u8, 3), AncientDebrisDistribution.sampleVeinSize(.primary_triangular, 1.0));

    // Secondary vein: 1..2 blocks
    try std.testing.expectEqual(@as(u8, 1), AncientDebrisDistribution.sampleVeinSize(.secondary_uniform, 0.0));
    try std.testing.expectEqual(@as(u8, 1), AncientDebrisDistribution.sampleVeinSize(.secondary_uniform, 0.4));
    try std.testing.expectEqual(@as(u8, 2), AncientDebrisDistribution.sampleVeinSize(.secondary_uniform, 0.6));
    try std.testing.expectEqual(@as(u8, 2), AncientDebrisDistribution.sampleVeinSize(.secondary_uniform, 1.0));
}

test "5. ancient debris blast resistance 1200 is immune to TNT and Bed explosions" {
    try std.testing.expectEqual(@as(f32, 1200.0), blast_resistance);
    try std.testing.expect(immuneToTntAndBedExplosions());

    // Survives TNT explosion (power 4.0)
    try std.testing.expect(AncientDebrisMining.survivesExplosion(blast_resistance, AncientDebrisMining.tnt_explosion_power));

    // Survives Bed explosion in Nether (power 5.0)
    try std.testing.expect(AncientDebrisMining.survivesExplosion(blast_resistance, AncientDebrisMining.bed_explosion_power));

    // Even extreme explosions (End Crystal 6.0, Wither birth 7.0) cannot break resistance 1200.0
    try std.testing.expect(AncientDebrisMining.survivesExplosion(blast_resistance, 6.0));
    try std.testing.expect(AncientDebrisMining.survivesExplosion(blast_resistance, 7.0));
}

test "6. bed blast mining destroys surrounding netherrack while ancient debris survives" {
    const netherrack_res = AncientDebrisMining.netherrack_blast_resistance; // 0.4
    const debris_res = AncientDebrisMining.blast_resistance; // 1200.0
    const bed_power = AncientDebrisMining.bed_explosion_power; // 5.0

    // Netherrack is destroyed by bed explosion
    try std.testing.expect(!AncientDebrisMining.survivesExplosion(netherrack_res, bed_power));

    // Ancient Debris survives unharmed
    try std.testing.expect(AncientDebrisMining.survivesExplosion(debris_res, bed_power));

    // Netherrack is destroyed by TNT explosion (power 4.0)
    try std.testing.expect(!AncientDebrisMining.survivesExplosion(netherrack_res, AncientDebrisMining.tnt_explosion_power));
}

test "7. ancient debris hardness 30.0 and harvest requires diamond or netherite pickaxe" {
    try std.testing.expectEqual(@as(f32, 30.0), hardness);

    // Diamond and Netherite can harvest
    try std.testing.expect(canHarvestAncientDebris(ToolTier.diamond));
    try std.testing.expect(canHarvestAncientDebris(ToolTier.netherite));

    // Inferior tiers cannot harvest Ancient Debris
    try std.testing.expect(!canHarvestAncientDebris(ToolTier.hand));
    try std.testing.expect(!canHarvestAncientDebris(ToolTier.wooden));
    try std.testing.expect(!canHarvestAncientDebris(ToolTier.stone));
    try std.testing.expect(!canHarvestAncientDebris(ToolTier.iron));
    try std.testing.expect(!canHarvestAncientDebris(ToolTier.golden));

    // Generic enum / literal checks
    try std.testing.expect(canHarvestAncientDebris(.diamond));
    try std.testing.expect(canHarvestAncientDebris(.netherite));
}

test "8. tool mining break times for ancient debris" {
    // Diamond pickaxe (speed multiplier 8.0): (30 * 1.5) / 8.0 = 5.625 seconds
    const diamond_time = AncientDebrisMining.calculateBreakTime(.diamond);
    try std.testing.expectApproxEqAbs(@as(f32, 5.625), diamond_time, 0.001);

    // Netherite pickaxe (speed multiplier 9.0): (30 * 1.5) / 9.0 = 5.0 seconds
    const netherite_time = AncientDebrisMining.calculateBreakTime(.netherite);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), netherite_time, 0.001);
    try std.testing.expect(netherite_time < diamond_time);

    // Ineffective tools take hardness * 5.0 = 150.0 seconds
    const iron_time = AncientDebrisMining.calculateBreakTime(.iron);
    const hand_time = AncientDebrisMining.calculateBreakTime(.hand);
    try std.testing.expectEqual(@as(f32, 150.0), iron_time);
    try std.testing.expectEqual(@as(f32, 150.0), hand_time);
}

test "9. smelting 1 ancient debris yields 1 netherite scrap and 2.0 XP" {
    // Single debris
    const single_smelt = smeltAncientDebris(1);
    try std.testing.expectEqual(@as(u32, 1), single_smelt.scraps);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), single_smelt.xp, 0.001);

    // Batch smelting: 4 debris -> 4 scraps, 8.0 XP
    const batch_smelt = smeltAncientDebris(4);
    try std.testing.expectEqual(@as(u32, 4), batch_smelt.scraps);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), batch_smelt.xp, 0.001);

    // 10 debris -> 10 scraps, 20.0 XP
    const ten_smelt = smeltAncientDebris(10);
    try std.testing.expectEqual(@as(u32, 10), ten_smelt.scraps);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), ten_smelt.xp, 0.001);
}

test "10. crafting netherite ingot requires 4 scraps + 4 gold ingots" {
    // Exact 1 ingot recipe: 4 scraps + 4 gold
    try std.testing.expectEqual(@as(u8, 1), craftNetheriteIngot(4, 4));

    // Multiples: 8 scraps + 8 gold -> 2 ingots
    try std.testing.expectEqual(@as(u8, 2), craftNetheriteIngot(8, 8));

    // 16 scraps + 16 gold -> 4 ingots
    try std.testing.expectEqual(@as(u8, 4), craftNetheriteIngot(16, 16));

    // Insufficient scraps -> 0 ingots
    try std.testing.expectEqual(@as(u8, 0), craftNetheriteIngot(3, 4));
    try std.testing.expectEqual(@as(u8, 0), craftNetheriteIngot(0, 10));

    // Insufficient gold ingots -> 0 ingots
    try std.testing.expectEqual(@as(u8, 0), craftNetheriteIngot(4, 3));
    try std.testing.expectEqual(@as(u8, 0), craftNetheriteIngot(12, 0));
}

test "11. crafting netherite ingot detailed leftovers calculation" {
    // 7 scraps and 9 gold -> 1 ingot, 3 scraps leftover, 5 gold leftover
    const res = NetheriteIngotRefining.craftNetheriteIngotDetailed(7, 9);
    try std.testing.expectEqual(@as(u8, 1), res.ingots);
    try std.testing.expectEqual(@as(u8, 3), res.remaining_scraps);
    try std.testing.expectEqual(@as(u8, 5), res.remaining_gold);

    // Zero leftover with exact 8 scraps and 8 gold
    const exact = NetheriteIngotRefining.craftNetheriteIngotDetailed(8, 8);
    try std.testing.expectEqual(@as(u8, 2), exact.ingots);
    try std.testing.expectEqual(@as(u8, 0), exact.remaining_scraps);
    try std.testing.expectEqual(@as(u8, 0), exact.remaining_gold);
}

test "12. netherite items are immune to fire and lava destruction" {
    // Raw materials and blocks
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.ancient_debris));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_scrap));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_ingot));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_block));

    // Armor pieces
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_helmet));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_chestplate));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_leggings));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_boots));

    // Tools and weapons
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_sword));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_pickaxe));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_axe));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_shovel));
    try std.testing.expect(isImmuneToLavaAndFire(NetheriteItemType.netherite_hoe));

    // LavaBuoyantItem struct instances
    const dropped_ingot = LavaBuoyantItem.init(.netherite_ingot);
    try std.testing.expect(dropped_ingot.isImmuneToLavaAndFire());
    const dropped_chest = LavaBuoyantItem.init(.netherite_chestplate);
    try std.testing.expect(dropped_chest.isImmuneToLavaAndFire());
}

test "13. non-netherite items burn and are destroyed in fire or lava" {
    try std.testing.expect(!isImmuneToLavaAndFire(NetheriteItemType.diamond));
    try std.testing.expect(!isImmuneToLavaAndFire(NetheriteItemType.diamond_pickaxe));
    try std.testing.expect(!isImmuneToLavaAndFire(NetheriteItemType.gold_ingot));
    try std.testing.expect(!isImmuneToLavaAndFire(NetheriteItemType.iron_ingot));
    try std.testing.expect(!isImmuneToLavaAndFire(NetheriteItemType.cobblestone));
    try std.testing.expect(!isImmuneToLavaAndFire(NetheriteItemType.netherrack));

    var dropped_diamond = LavaBuoyantItem.init(.diamond);
    try std.testing.expect(!dropped_diamond.tickInLava()); // Burned up!
}

test "14. lava buoyancy physics lifts submerged items upward to surface" {
    // Sinking item (negative vy) decelerates and turns upward
    var vy: f32 = -0.40;
    vy = computeLavaBuoyancyVy(vy);
    try std.testing.expect(vy > -0.40); // Sinking slowed

    // After repeated ticks, velocity reverses into positive upward motion
    var ticks: usize = 0;
    while (ticks < 10) : (ticks += 1) {
        vy = computeLavaBuoyancyVy(vy);
    }
    try std.testing.expect(vy > 0.0); // Now floating upward!

    // Upward float is capped at terminal float velocity (0.10)
    var fast_vy: f32 = 0.50;
    fast_vy = computeLavaBuoyancyVy(fast_vy);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), fast_vy, 0.001);

    // Dropped item in lava floats upward in Y position
    var dropped_pick = LavaBuoyantItem.init(.netherite_pickaxe);
    dropped_pick.y = 10.0;
    dropped_pick.vy = 0.0;
    try std.testing.expect(dropped_pick.tickInLava());
    try std.testing.expect(dropped_pick.y > 10.0); // Moved up towards lava surface
}

test "15. netherite armor knockback resistance scales 10% per piece up to 40%" {
    // 0 pieces: 0% resistance
    try std.testing.expectApproxEqAbs(@as(f32, 0.00), totalKnockbackResistance(0), 0.001);

    // 1 piece: 10% resistance
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), totalKnockbackResistance(1), 0.001);

    // 2 pieces: 20% resistance
    try std.testing.expectApproxEqAbs(@as(f32, 0.20), totalKnockbackResistance(2), 0.001);

    // 3 pieces: 30% resistance
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), totalKnockbackResistance(3), 0.001);

    // 4 pieces (full suit): 40% resistance
    try std.testing.expectApproxEqAbs(@as(f32, 0.40), totalKnockbackResistance(4), 0.001);

    // Input greater than 4 is clamped to max 40%
    try std.testing.expectApproxEqAbs(@as(f32, 0.40), totalKnockbackResistance(5), 0.001);
}

test "16. knockback impulse reduction calculation with equipped pieces" {
    const raw_knockback: f32 = 2.0;

    // No netherite: full knockback
    const kb0 = NetheriteKnockbackResistance.applyKnockbackReduction(raw_knockback, 0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), kb0, 0.001);

    // 2 pieces (20% resistance): 2.0 * 0.8 = 1.6
    const kb2 = NetheriteKnockbackResistance.applyKnockbackReduction(raw_knockback, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 1.6), kb2, 0.001);

    // 4 pieces (full suit, 40% resistance): 2.0 * 0.6 = 1.2
    const kb4 = NetheriteKnockbackResistance.applyKnockbackReduction(raw_knockback, 4);
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), kb4, 0.001);

    // Count pieces helper
    const count = NetheriteKnockbackResistance.countPieces(true, true, false, true); // 3 pieces
    try std.testing.expectEqual(@as(u3, 3), count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.30), totalKnockbackResistance(count), 0.001);
}

test "17. full lifecycle: bed mining to ingot refining to lava buoyancy recovery" {
    // 1. Bed blast mining clears netherrack, unearths ancient debris intact at Y=15
    try std.testing.expect(canSpawnAncientDebrisAt(15, false));
    try std.testing.expect(immuneToTntAndBedExplosions());

    // 2. Diamond pickaxe mines 4 Ancient Debris
    try std.testing.expect(canHarvestAncientDebris(.diamond));
    const debris_count: u32 = 4;

    // 3. Smelt 4 Ancient Debris -> 4 Netherite Scraps + 8.0 XP
    const smelt_out = smeltAncientDebris(debris_count);
    try std.testing.expectEqual(@as(u32, 4), smelt_out.scraps);
    try std.testing.expectEqual(@as(f32, 8.0), smelt_out.xp);

    // 4. Combine 4 Netherite Scraps + 4 Gold Ingots -> 1 Netherite Ingot
    const gold_count: u8 = 4;
    const ingots = craftNetheriteIngot(@intCast(smelt_out.scraps), gold_count);
    try std.testing.expectEqual(@as(u8, 1), ingots);

    // 5. Ingot accidentally drops into Nether lava lake: survives and floats to surface!
    var dropped_ingot = LavaBuoyantItem.init(.netherite_ingot);
    dropped_ingot.y = 31.0; // Submerged below lava lake surface (Y=32)
    dropped_ingot.vy = -0.2;
    try std.testing.expect(dropped_ingot.isImmuneToLavaAndFire());

    // Tick buoyancy in lava
    for (0..20) |_| {
        _ = dropped_ingot.tickInLava();
    }
    // Ingot has floated upward safely
    try std.testing.expect(dropped_ingot.y > 31.0);
    try std.testing.expect(dropped_ingot.vy > 0.0);
}
