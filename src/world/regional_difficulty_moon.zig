const std = @import("std");

/// Game difficulty setting.
pub const Difficulty = enum(u8) {
    peaceful = 0,
    easy = 1,
    normal = 2,
    hard = 3,

    pub fn name(self: Difficulty) []const u8 {
        return switch (self) {
            .peaceful => "Peaceful",
            .easy => "Easy",
            .normal => "Normal",
            .hard => "Hard",
        };
    }
};

/// 8-day lunar phase cycle.
/// Each Minecraft day lasts 24,000 ticks.
/// A full lunar cycle spans 8 game days (192,000 ticks).
pub const MoonPhase = enum(u3) {
    full_moon = 0,
    waning_gibbous = 1,
    third_quarter = 2,
    waning_crescent = 3,
    new_moon = 4,
    waxing_crescent = 5,
    first_quarter = 6,
    waxing_gibbous = 7,

    /// Moon brightness factor (0.0 .. 1.0).
    /// Full moon = 1.0, New moon = 0.0, Gibbous = 0.75, Quarter = 0.50, Crescent = 0.25.
    pub fn brightness(self: MoonPhase) f32 {
        return switch (self) {
            .full_moon => 1.0,
            .waning_gibbous, .waxing_gibbous => 0.75,
            .third_quarter, .first_quarter => 0.50,
            .waning_crescent, .waxing_crescent => 0.25,
            .new_moon => 0.0,
        };
    }

    /// Zero-based phase index (0..7).
    pub fn phaseIndex(self: MoonPhase) u3 {
        return @intFromEnum(self);
    }

    /// Construct MoonPhase from 0..7 index.
    pub fn fromIndex(idx: u3) MoonPhase {
        return @enumFromInt(idx);
    }

    /// Next moon phase in the 8-day lunar cycle.
    pub fn next(self: MoonPhase) MoonPhase {
        const next_idx: u3 = @intCast((@as(u4, @intFromEnum(self)) + 1) % 8);
        return @enumFromInt(next_idx);
    }

    /// Previous moon phase in the 8-day lunar cycle.
    pub fn prev(self: MoonPhase) MoonPhase {
        const prev_idx: u3 = @intCast((@as(u4, @intFromEnum(self)) + 7) % 8);
        return @enumFromInt(prev_idx);
    }

    /// Whether this phase is a full moon.
    pub fn isFull(self: MoonPhase) bool {
        return self == .full_moon;
    }

    /// Whether this phase is a new moon.
    pub fn isNew(self: MoonPhase) bool {
        return self == .new_moon;
    }

    /// Human-readable name for the moon phase.
    pub fn name(self: MoonPhase) []const u8 {
        return switch (self) {
            .full_moon => "Full Moon",
            .waning_gibbous => "Waning Gibbous",
            .third_quarter => "Third Quarter",
            .waning_crescent => "Waning Crescent",
            .new_moon => "New Moon",
            .waxing_crescent => "Waxing Crescent",
            .first_quarter => "First Quarter",
            .waxing_gibbous => "Waxing Gibbous",
        };
    }
};

/// Time constants for tick and difficulty calculations.
pub const TICKS_PER_DAY: u64 = 24_000;
pub const DAYS_PER_MOON_CYCLE: u64 = 8;
pub const TICKS_PER_MOON_CYCLE: u64 = DAYS_PER_MOON_CYCLE * TICKS_PER_DAY; // 192,000 ticks

pub const WORLD_TIME_START_TICKS: u64 = 72_000; // 3 in-game days (1 hour real time)
pub const WORLD_TIME_PEAK_TICKS: u64 = 1_512_000; // 63 in-game days (21 hours real time)
pub const WORLD_TIME_DIVISOR: f32 = 5_760_000.0;

pub const CHUNK_INHABITED_PEAK_TICKS: u64 = 3_600_000; // 150 in-game days (50 hours real time)
pub const CHUNK_INHABITED_DIVISOR: f32 = 3_600_000.0;

/// Determine current moon phase given the total world age in ticks.
/// Each day is 24,000 ticks; 8 phases cycle every 192,000 ticks.
pub fn moonPhaseForWorldTime(total_ticks: u64) MoonPhase {
    const day = total_ticks / TICKS_PER_DAY;
    const phase_idx: u3 = @intCast(day % DAYS_PER_MOON_CYCLE);
    return @enumFromInt(phase_idx);
}

/// Moon phase effects on mob spawning and world generation.
pub const MoonPhaseEffects = struct {
    /// Swamp Slime spawning peaks during .full_moon (100% chance)
    /// and is completely disabled during .new_moon (0% chance).
    pub fn swampSlimeSpawnChance(phase: MoonPhase) f32 {
        return phase.brightness();
    }

    /// Black Cat generation in villages:
    /// During .full_moon, village cats have a 50% chance of spawning as black cats.
    /// On all other moon phases, this special bonus is 0%.
    pub fn villageBlackCatChance(phase: MoonPhase) f32 {
        return if (phase == .full_moon) 0.50 else 0.0;
    }

    /// Swamp slime spawning with environmental condition checks:
    /// Valid only between Y = 51..69 and light level <= 7.
    pub fn swampSlimeSpawnChanceWithEnv(phase: MoonPhase, light_level: u4, y_coord: i32) f32 {
        if (y_coord < 51 or y_coord > 69 or light_level > 7) {
            return 0.0;
        }
        return MoonPhaseEffects.swampSlimeSpawnChance(phase);
    }
};

pub const swampSlimeSpawnChance = MoonPhaseEffects.swampSlimeSpawnChance;
pub const villageBlackCatChance = MoonPhaseEffects.villageBlackCatChance;
pub const swampSlimeSpawnChanceWithEnv = MoonPhaseEffects.swampSlimeSpawnChanceWithEnv;

/// Regional difficulty calculation formula.
/// Base difficulty values:
///   Peaceful: always 0.0
///   Easy:     0.75 .. 1.50
///   Normal:   1.50 .. 4.00
///   Hard:     2.25 .. 6.75
///
/// Scales upward with:
///   1. total_world_time_ticks (starts at 72,000 ticks, peaks at 1,512,000 ticks = 21 hours)
///   2. chunk_inhabited_time_ticks (peaks at 3,600,000 ticks = 50 hours)
///   3. moon_brightness (0.0 .. 1.0)
pub const RegionalDifficultyFormula = struct {
    pub fn compute(
        difficulty: Difficulty,
        world_ticks: u64,
        chunk_ticks: u64,
        moon_brightness: f32,
    ) f32 {
        if (difficulty == .peaceful) return 0.0;

        // 1. Total world time factor (0.0 .. 0.25)
        var total_time_factor: f32 = 0.0;
        if (world_ticks > WORLD_TIME_PEAK_TICKS) {
            total_time_factor = 0.25;
        } else if (world_ticks < WORLD_TIME_START_TICKS) {
            total_time_factor = 0.0;
        } else {
            total_time_factor = @as(f32, @floatFromInt(world_ticks - WORLD_TIME_START_TICKS)) / WORLD_TIME_DIVISOR;
        }

        // 2. Chunk inhabited time factor (0.0 .. 1.0)
        var chunk_factor: f32 = if (chunk_ticks > CHUNK_INHABITED_PEAK_TICKS)
            1.0
        else
            @as(f32, @floatFromInt(chunk_ticks)) / CHUNK_INHABITED_DIVISOR;

        // In Easy and Normal difficulties, chunk factor is scaled by 0.75
        if (difficulty != .hard) {
            chunk_factor *= 0.75;
        }

        // 3. Moon phase brightness factor (scaled by 0.25, capped by total_time_factor)
        const clamped_moon = std.math.clamp(moon_brightness, 0.0, 1.0);
        const moon_factor = clamped_moon * 0.25;
        if (moon_factor > total_time_factor) {
            chunk_factor += total_time_factor;
        } else {
            chunk_factor += moon_factor;
        }

        // Easy difficulty halves the chunk factor
        if (difficulty == .easy) {
            chunk_factor /= 2.0;
        }

        // 4. Base sum and difficulty multiplier
        var regional_diff: f32 = 0.75 + total_time_factor + chunk_factor;
        if (difficulty == .normal) {
            regional_diff *= 2.0;
        } else if (difficulty == .hard) {
            regional_diff *= 3.0;
        }

        return regional_diff;
    }
};

pub const computeRegionalDifficulty = RegionalDifficultyFormula.compute;

/// Helper to compute regional difficulty directly from world ticks and chunk inhabited ticks.
pub fn computeRegionalDifficultyFromTime(
    difficulty: Difficulty,
    world_ticks: u64,
    chunk_ticks: u64,
) f32 {
    const phase = moonPhaseForWorldTime(world_ticks);
    return computeRegionalDifficulty(difficulty, world_ticks, chunk_ticks, phase.brightness());
}

/// Clamped special multiplier (0.0 .. 1.0) derived from regional difficulty:
///   - clamped = 0.0 when regional_difficulty < 2.0
///   - clamped = (regional_difficulty - 2.0) / 2.0 when 2.0 <= regional_difficulty <= 4.0
///   - clamped = 1.0 when regional_difficulty > 4.0
///
/// Controls:
///   - Mob armor spawn probability (up to 15% * clamped)
///   - Weapon enchantment probability (up to 25% * clamped)
///   - Armor enchantment probability (up to 50% * clamped)
///   - Zombie leader spawn probability (up to 5% * clamped) and reinforcement bonus (+50%..75%)
///   - Spider status effects on Hard difficulty (up to 10% * clamped)
pub const ClampedSpecialMultiplier = struct {
    pub fn compute(regional_diff: f32) f32 {
        if (regional_diff < 2.0) {
            return 0.0;
        } else if (regional_diff > 4.0) {
            return 1.0;
        } else {
            return (regional_diff - 2.0) / 2.0;
        }
    }

    /// Mob armor spawn probability (up to 15% * clamped).
    pub fn mobArmorSpawnChance(clamped: f32) f32 {
        const c = std.math.clamp(clamped, 0.0, 1.0);
        return 0.15 * c;
    }

    /// Weapon enchantment probability (up to 25% * clamped).
    pub fn weaponEnchantmentChance(clamped: f32) f32 {
        const c = std.math.clamp(clamped, 0.0, 1.0);
        return 0.25 * c;
    }

    /// Armor enchantment probability (up to 50% * clamped).
    pub fn armorEnchantmentChance(clamped: f32) f32 {
        const c = std.math.clamp(clamped, 0.0, 1.0);
        return 0.50 * c;
    }

    /// Zombie leader spawn probability (up to 5% * clamped).
    pub fn zombieLeaderSpawnChance(clamped: f32) f32 {
        const c = std.math.clamp(clamped, 0.0, 1.0);
        return 0.05 * c;
    }

    /// Zombie leader reinforcement call bonus:
    /// Leader zombies receive +50%..75% reinforcement call bonus (+0.50 to +0.75).
    pub fn zombieLeaderReinforcementBonus(is_leader: bool, clamped: f32) f32 {
        if (!is_leader) return 0.0;
        const c = std.math.clamp(clamped, 0.0, 1.0);
        return 0.50 + 0.25 * c;
    }

    /// Total zombie reinforcement call probability:
    /// Normal zombies have up to 10% * clamped chance;
    /// Leader zombies add +50%..75% bonus on top.
    pub fn zombieTotalReinforcementChance(is_leader: bool, clamped: f32) f32 {
        const c = std.math.clamp(clamped, 0.0, 1.0);
        const base_chance = 0.10 * c;
        if (is_leader) {
            return base_chance + ClampedSpecialMultiplier.zombieLeaderReinforcementBonus(true, c);
        }
        return base_chance;
    }

    /// Spider status effect spawn chance on Hard difficulty:
    /// In Hard difficulty, (10 * clamped)% chance for spiders to spawn with Speed, Strength,
    /// Regeneration, or Invisibility.
    pub fn spiderStatusEffectChance(difficulty: Difficulty, clamped: f32) f32 {
        if (difficulty != .hard) return 0.0;
        const c = std.math.clamp(clamped, 0.0, 1.0);
        return 0.10 * c;
    }
};

pub const computeClampedRegionalMultiplier = ClampedSpecialMultiplier.compute;
pub const mobArmorSpawnChance = ClampedSpecialMultiplier.mobArmorSpawnChance;
pub const weaponEnchantmentChance = ClampedSpecialMultiplier.weaponEnchantmentChance;
pub const armorEnchantmentChance = ClampedSpecialMultiplier.armorEnchantmentChance;
pub const zombieLeaderSpawnChance = ClampedSpecialMultiplier.zombieLeaderSpawnChance;
pub const zombieLeaderReinforcementBonus = ClampedSpecialMultiplier.zombieLeaderReinforcementBonus;
pub const zombieTotalReinforcementChance = ClampedSpecialMultiplier.zombieTotalReinforcementChance;
pub const spiderStatusEffectChance = ClampedSpecialMultiplier.spiderStatusEffectChance;

/// Armor tier materials for mobs spawned with equipment.
pub const ArmorTier = enum(u8) {
    leather = 0,
    gold = 1,
    chainmail = 2,
    iron = 3,
    diamond = 4,

    pub fn name(self: ArmorTier) []const u8 {
        return switch (self) {
            .leather => "Leather",
            .gold => "Gold",
            .chainmail => "Chainmail",
            .iron => "Iron",
            .diamond => "Diamond",
        };
    }

    /// Map a normalized uniform random roll (0.0 .. 1.0) to an armor tier.
    /// Vanilla distribution:
    ///   Leather:   37.06%
    ///   Gold:      48.73%
    ///   Chainmail: 12.90%
    ///   Iron:       1.27%
    ///   Diamond:    0.04%
    pub fn fromRandomRoll(roll: f32) ArmorTier {
        const r = std.math.clamp(roll, 0.0, 1.0);
        if (r < 0.3706) {
            return .leather;
        } else if (r < 0.3706 + 0.4873) {
            return .gold;
        } else if (r < 0.3706 + 0.4873 + 0.1290) {
            return .chainmail;
        } else if (r < 0.3706 + 0.4873 + 0.1290 + 0.0127) {
            return .iron;
        } else {
            return .diamond;
        }
    }
};

/// Chance of an armored mob spawning with multiple armor pieces.
/// In Easy & Normal: 75% for 2 pieces, 56.25% for 3 pieces, 42.19% for 4 pieces (full set).
/// In Hard:          90% for 2 pieces, 81.00% for 3 pieces, 72.90% for 4 pieces (full set).
pub fn armorPieceCountChance(difficulty: Difficulty, piece_count: u3) f32 {
    if (piece_count <= 1) return 1.0;
    const base_ratio: f32 = if (difficulty == .hard) 0.90 else 0.75;
    return switch (piece_count) {
        2 => base_ratio,
        3 => base_ratio * base_ratio,
        4 => base_ratio * base_ratio * base_ratio,
        else => 0.0,
    };
}

/// Comprehensive regional difficulty state snapshot.
pub const RegionalDifficulty = struct {
    difficulty: Difficulty,
    raw_value: f32,
    clamped_multiplier: f32,

    pub fn init(
        difficulty: Difficulty,
        world_ticks: u64,
        chunk_ticks: u64,
        moon_brightness: f32,
    ) RegionalDifficulty {
        const raw = computeRegionalDifficulty(difficulty, world_ticks, chunk_ticks, moon_brightness);
        return .{
            .difficulty = difficulty,
            .raw_value = raw,
            .clamped_multiplier = computeClampedRegionalMultiplier(raw),
        };
    }

    pub fn initFromWorldTime(
        difficulty: Difficulty,
        world_ticks: u64,
        chunk_ticks: u64,
    ) RegionalDifficulty {
        const phase = moonPhaseForWorldTime(world_ticks);
        return init(difficulty, world_ticks, chunk_ticks, phase.brightness());
    }

    pub fn armorChance(self: RegionalDifficulty) f32 {
        return mobArmorSpawnChance(self.clamped_multiplier);
    }

    pub fn weaponEnchantChance(self: RegionalDifficulty) f32 {
        return weaponEnchantmentChance(self.clamped_multiplier);
    }

    pub fn armorEnchantChance(self: RegionalDifficulty) f32 {
        return armorEnchantmentChance(self.clamped_multiplier);
    }

    pub fn leaderChance(self: RegionalDifficulty) f32 {
        return zombieLeaderSpawnChance(self.clamped_multiplier);
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "8-day moon phase cycle from world time ticks" {
    // Day 0: 0 .. 23,999 ticks -> full_moon
    try std.testing.expectEqual(MoonPhase.full_moon, moonPhaseForWorldTime(0));
    try std.testing.expectEqual(MoonPhase.full_moon, moonPhaseForWorldTime(12_000));
    try std.testing.expectEqual(MoonPhase.full_moon, moonPhaseForWorldTime(23_999));

    // Day 1: 24,000 .. 47,999 ticks -> waning_gibbous
    try std.testing.expectEqual(MoonPhase.waning_gibbous, moonPhaseForWorldTime(24_000));
    try std.testing.expectEqual(MoonPhase.waning_gibbous, moonPhaseForWorldTime(36_000));

    // Day 2: third_quarter
    try std.testing.expectEqual(MoonPhase.third_quarter, moonPhaseForWorldTime(48_000));

    // Day 3: waning_crescent
    try std.testing.expectEqual(MoonPhase.waning_crescent, moonPhaseForWorldTime(72_000));

    // Day 4: new_moon
    try std.testing.expectEqual(MoonPhase.new_moon, moonPhaseForWorldTime(96_000));

    // Day 5: waxing_crescent
    try std.testing.expectEqual(MoonPhase.waxing_crescent, moonPhaseForWorldTime(120_000));

    // Day 6: first_quarter
    try std.testing.expectEqual(MoonPhase.first_quarter, moonPhaseForWorldTime(144_000));

    // Day 7: waxing_gibbous
    try std.testing.expectEqual(MoonPhase.waxing_gibbous, moonPhaseForWorldTime(168_000));

    // Day 8: wraps back to full_moon (192,000 ticks)
    try std.testing.expectEqual(MoonPhase.full_moon, moonPhaseForWorldTime(192_000));
    try std.testing.expectEqual(MoonPhase.new_moon, moonPhaseForWorldTime(192_000 + 96_000));
}

test "moon phase brightness and properties" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), MoonPhase.full_moon.brightness(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), MoonPhase.waning_gibbous.brightness(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), MoonPhase.third_quarter.brightness(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), MoonPhase.waning_crescent.brightness(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), MoonPhase.new_moon.brightness(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), MoonPhase.waxing_crescent.brightness(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), MoonPhase.first_quarter.brightness(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), MoonPhase.waxing_gibbous.brightness(), 1e-5);

    try std.testing.expect(MoonPhase.full_moon.isFull());
    try std.testing.expect(!MoonPhase.new_moon.isFull());
    try std.testing.expect(MoonPhase.new_moon.isNew());
    try std.testing.expect(!MoonPhase.full_moon.isNew());
}

test "moon phase sequence navigation next and prev" {
    var p = MoonPhase.full_moon;
    p = p.next();
    try std.testing.expectEqual(MoonPhase.waning_gibbous, p);
    p = p.next();
    try std.testing.expectEqual(MoonPhase.third_quarter, p);
    p = p.next();
    try std.testing.expectEqual(MoonPhase.waning_crescent, p);
    p = p.next();
    try std.testing.expectEqual(MoonPhase.new_moon, p);
    p = p.next();
    try std.testing.expectEqual(MoonPhase.waxing_crescent, p);
    p = p.next();
    try std.testing.expectEqual(MoonPhase.first_quarter, p);
    p = p.next();
    try std.testing.expectEqual(MoonPhase.waxing_gibbous, p);
    p = p.next();
    try std.testing.expectEqual(MoonPhase.full_moon, p);

    // Prev navigation
    try std.testing.expectEqual(MoonPhase.waxing_gibbous, MoonPhase.full_moon.prev());
    try std.testing.expectEqual(MoonPhase.full_moon, MoonPhase.waning_gibbous.prev());
    try std.testing.expectEqual(MoonPhase.waning_crescent, MoonPhase.new_moon.prev());
}

test "swamp slime spawn chance by moon phase" {
    // Peaks at 100% on full moon
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), swampSlimeSpawnChance(.full_moon), 1e-5);
    // Completely disabled at 0% on new moon
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), swampSlimeSpawnChance(.new_moon), 1e-5);
    // Intermediate chances
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), swampSlimeSpawnChance(.waning_gibbous), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), swampSlimeSpawnChance(.waxing_gibbous), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), swampSlimeSpawnChance(.third_quarter), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), swampSlimeSpawnChance(.first_quarter), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), swampSlimeSpawnChance(.waning_crescent), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), swampSlimeSpawnChance(.waxing_crescent), 1e-5);
}

test "swamp slime spawn chance environmental checks" {
    // Valid conditions (Y 51..69, light <= 7)
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), swampSlimeSpawnChanceWithEnv(.full_moon, 5, 60), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), swampSlimeSpawnChanceWithEnv(.full_moon, 7, 51), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), swampSlimeSpawnChanceWithEnv(.full_moon, 0, 69), 1e-5);

    // Invalid conditions
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), swampSlimeSpawnChanceWithEnv(.full_moon, 8, 60), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), swampSlimeSpawnChanceWithEnv(.full_moon, 7, 50), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), swampSlimeSpawnChanceWithEnv(.full_moon, 7, 70), 1e-5);
}

test "village black cat generation chance by moon phase" {
    // 50% chance on full moon
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), villageBlackCatChance(.full_moon), 1e-5);

    // 0% on all other 7 phases
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), villageBlackCatChance(.waning_gibbous), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), villageBlackCatChance(.third_quarter), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), villageBlackCatChance(.waning_crescent), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), villageBlackCatChance(.new_moon), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), villageBlackCatChance(.waxing_crescent), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), villageBlackCatChance(.first_quarter), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), villageBlackCatChance(.waxing_gibbous), 1e-5);
}

test "peaceful difficulty always yields 0.0 regional difficulty" {
    try std.testing.expectEqual(@as(f32, 0.0), computeRegionalDifficulty(.peaceful, 0, 0, 0.0));
    try std.testing.expectEqual(@as(f32, 0.0), computeRegionalDifficulty(.peaceful, 1_512_000, 3_600_000, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), computeRegionalDifficulty(.peaceful, 10_000_000, 10_000_000, 1.0));
}

test "easy difficulty range bounds 0.75 to 1.50" {
    // Minimum bound: Day 0, Chunk 0, New Moon
    const min_rd = computeRegionalDifficulty(.easy, 0, 0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), min_rd, 1e-5);

    // Maximum bound: Max world ticks (>= 1,512,000), Max chunk ticks (>= 3,600,000), Full Moon (1.0)
    const max_rd = computeRegionalDifficulty(.easy, WORLD_TIME_PEAK_TICKS, CHUNK_INHABITED_PEAK_TICKS, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.50), max_rd, 1e-5);

    // Clamped multiplier on Easy is always 0.0 because 1.50 < 2.0
    try std.testing.expectEqual(@as(f32, 0.0), computeClampedRegionalMultiplier(min_rd));
    try std.testing.expectEqual(@as(f32, 0.0), computeClampedRegionalMultiplier(max_rd));
}

test "normal difficulty range bounds 1.50 to 4.00" {
    // Minimum bound: Day 0, Chunk 0, New Moon
    const min_rd = computeRegionalDifficulty(.normal, 0, 0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.50), min_rd, 1e-5);

    // Maximum bound: Max world ticks, Max chunk ticks, Full Moon
    const max_rd = computeRegionalDifficulty(.normal, WORLD_TIME_PEAK_TICKS, CHUNK_INHABITED_PEAK_TICKS, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 4.00), max_rd, 1e-5);

    // Clamped multiplier on Normal spans 0.0 to 1.0
    try std.testing.expectEqual(@as(f32, 0.0), computeClampedRegionalMultiplier(min_rd));
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), computeClampedRegionalMultiplier(max_rd), 1e-5);
}

test "hard difficulty range bounds 2.25 to 6.75" {
    // Minimum bound: Day 0, Chunk 0, New Moon
    const min_rd = computeRegionalDifficulty(.hard, 0, 0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.25), min_rd, 1e-5);

    // Maximum bound: Max world ticks, Max chunk ticks, Full Moon
    const max_rd = computeRegionalDifficulty(.hard, WORLD_TIME_PEAK_TICKS, CHUNK_INHABITED_PEAK_TICKS, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 6.75), max_rd, 1e-5);

    // Clamped multiplier on Hard starts at (2.25 - 2.0)/2.0 = 0.125 and reaches 1.0
    try std.testing.expectApproxEqAbs(@as(f32, 0.125), computeClampedRegionalMultiplier(min_rd), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), computeClampedRegionalMultiplier(max_rd), 1e-5);
}

test "world time ticks scaling threshold and saturation" {
    // Below 72,000 ticks: 0.0 contribution
    const rd_0 = computeRegionalDifficulty(.hard, 0, 0, 0.0);
    const rd_71k = computeRegionalDifficulty(.hard, 71_999, 0, 0.0);
    try std.testing.expectEqual(rd_0, rd_71k);

    // Exactly 72,000 ticks: still minimum
    const rd_72k = computeRegionalDifficulty(.hard, 72_000, 0, 0.0);
    try std.testing.expectEqual(rd_0, rd_72k);

    // Midpoint: 792,000 ticks (720,000 / 5,760,000 = 0.125 factor)
    // base 0.75 + 0.125 = 0.875 * 3 = 2.625
    const rd_mid = computeRegionalDifficulty(.hard, 792_000, 0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.625), rd_mid, 1e-5);

    // Saturation at 1,512,000 ticks
    const rd_peak = computeRegionalDifficulty(.hard, 1_512_000, 0, 0.0);
    const rd_beyond = computeRegionalDifficulty(.hard, 5_000_000, 0, 0.0);
    try std.testing.expectEqual(rd_peak, rd_beyond);
}

test "chunk inhabited time scaling and saturation" {
    // 0 chunk ticks
    const rd_c0 = computeRegionalDifficulty(.hard, 0, 0, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 2.25), rd_c0, 1e-5);

    // Half chunk ticks: 1,800,000 / 3,600,000 = 0.5 factor
    // Hard chunk_factor = 0.5, moon_factor = 0 (since total_time_factor = 0, moon contributes min(moon, 0) = 0)
    // rd = (0.75 + 0.0 + 0.5) * 3 = 3.75
    const rd_half = computeRegionalDifficulty(.hard, 0, 1_800_000, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 3.75), rd_half, 1e-5);

    // Saturated chunk ticks (>= 3,600,000)
    const rd_peak = computeRegionalDifficulty(.hard, 0, 3_600_000, 0.0);
    const rd_over = computeRegionalDifficulty(.hard, 0, 10_000_000, 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 5.25), rd_peak, 1e-5);
    try std.testing.expectEqual(rd_peak, rd_over);
}

test "clamped regional multiplier piecewise formula and boundaries" {
    // Below 2.0 -> 0.0
    try std.testing.expectEqual(@as(f32, 0.0), computeClampedRegionalMultiplier(0.0));
    try std.testing.expectEqual(@as(f32, 0.0), computeClampedRegionalMultiplier(1.5));
    try std.testing.expectEqual(@as(f32, 0.0), computeClampedRegionalMultiplier(1.999));

    // At 2.0 -> 0.0
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), computeClampedRegionalMultiplier(2.0), 1e-5);

    // Linear ramp between 2.0 and 4.0: (diff - 2.0) / 2.0
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), computeClampedRegionalMultiplier(2.5), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), computeClampedRegionalMultiplier(3.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), computeClampedRegionalMultiplier(3.5), 1e-5);

    // At 4.0 -> 1.0
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), computeClampedRegionalMultiplier(4.0), 1e-5);

    // Above 4.0 -> 1.0
    try std.testing.expectEqual(@as(f32, 1.0), computeClampedRegionalMultiplier(4.001));
    try std.testing.expectEqual(@as(f32, 1.0), computeClampedRegionalMultiplier(6.75));
    try std.testing.expectEqual(@as(f32, 1.0), computeClampedRegionalMultiplier(10.0));
}

test "mob armor spawn probability scaled by clamped multiplier" {
    // Clamped = 0.0 -> 0.0%
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), mobArmorSpawnChance(0.0), 1e-5);

    // Clamped = 0.5 -> 7.5%
    try std.testing.expectApproxEqAbs(@as(f32, 0.075), mobArmorSpawnChance(0.5), 1e-5);

    // Clamped = 1.0 -> 15.0%
    try std.testing.expectApproxEqAbs(@as(f32, 0.15), mobArmorSpawnChance(1.0), 1e-5);
}

test "weapon and armor enchantment probability scaling" {
    // Weapon enchantment: up to 25% * clamped
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), weaponEnchantmentChance(0.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.125), weaponEnchantmentChance(0.5), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), weaponEnchantmentChance(1.0), 1e-5);

    // Armor enchantment: up to 50% * clamped
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), armorEnchantmentChance(0.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), armorEnchantmentChance(0.5), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), armorEnchantmentChance(1.0), 1e-5);
}

test "zombie leader spawn probability and reinforcement bonus" {
    // Leader spawn chance: up to 5% * clamped
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), zombieLeaderSpawnChance(0.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.025), zombieLeaderSpawnChance(0.5), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), zombieLeaderSpawnChance(1.0), 1e-5);

    // Leader reinforcement bonus: 50%..75% (+0.50 to +0.75)
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), zombieLeaderReinforcementBonus(true, 0.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.625), zombieLeaderReinforcementBonus(true, 0.5), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), zombieLeaderReinforcementBonus(true, 1.0), 1e-5);
    try std.testing.expectEqual(@as(f32, 0.0), zombieLeaderReinforcementBonus(false, 1.0));

    // Total reinforcement call probability
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), zombieTotalReinforcementChance(false, 0.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), zombieTotalReinforcementChance(false, 1.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), zombieTotalReinforcementChance(true, 1.0), 1e-5);
}

test "spider status effect chance on hard difficulty" {
    // Non-hard difficulties never spawn spiders with effects
    try std.testing.expectEqual(@as(f32, 0.0), spiderStatusEffectChance(.easy, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), spiderStatusEffectChance(.normal, 1.0));
    try std.testing.expectEqual(@as(f32, 0.0), spiderStatusEffectChance(.peaceful, 1.0));

    // Hard difficulty: up to 10% * clamped
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), spiderStatusEffectChance(.hard, 0.0), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), spiderStatusEffectChance(.hard, 0.5), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.10), spiderStatusEffectChance(.hard, 1.0), 1e-5);
}

test "armor tier distribution from random roll" {
    try std.testing.expectEqual(ArmorTier.leather, ArmorTier.fromRandomRoll(0.10));
    try std.testing.expectEqual(ArmorTier.gold, ArmorTier.fromRandomRoll(0.50));
    try std.testing.expectEqual(ArmorTier.chainmail, ArmorTier.fromRandomRoll(0.90));
    try std.testing.expectEqual(ArmorTier.iron, ArmorTier.fromRandomRoll(0.99));
    try std.testing.expectEqual(ArmorTier.diamond, ArmorTier.fromRandomRoll(0.9999));
}

test "armor piece count probability scaling by difficulty" {
    // Single piece is always 100%
    try std.testing.expectEqual(@as(f32, 1.0), armorPieceCountChance(.normal, 1));
    try std.testing.expectEqual(@as(f32, 1.0), armorPieceCountChance(.hard, 1));

    // Easy & Normal: 75% for 2, 56.25% for 3, 42.1875% for 4
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), armorPieceCountChance(.normal, 2), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5625), armorPieceCountChance(.normal, 3), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.421875), armorPieceCountChance(.normal, 4), 1e-5);

    // Hard: 90% for 2, 81.00% for 3, 72.90% for 4
    try std.testing.expectApproxEqAbs(@as(f32, 0.90), armorPieceCountChance(.hard, 2), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.81), armorPieceCountChance(.hard, 3), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.729), armorPieceCountChance(.hard, 4), 1e-5);
}

test "RegionalDifficulty struct snapshot and helpers" {
    const snap = RegionalDifficulty.init(.hard, WORLD_TIME_PEAK_TICKS, CHUNK_INHABITED_PEAK_TICKS, 1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 6.75), snap.raw_value, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), snap.clamped_multiplier, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.15), snap.armorChance(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), snap.weaponEnchantChance(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), snap.armorEnchantChance(), 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.05), snap.leaderChance(), 1e-5);

    const time_snap = RegionalDifficulty.initFromWorldTime(.hard, WORLD_TIME_PEAK_TICKS, CHUNK_INHABITED_PEAK_TICKS);
    try std.testing.expect(time_snap.raw_value >= 2.25 and time_snap.raw_value <= 6.75);
}
