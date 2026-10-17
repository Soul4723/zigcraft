//! TNT Demolition Physics & Mechanics (Milestone 420)
//!
//! Covers:
//! 1. TNT Crafting Recipe (5 gunpowder + 4 sand/red_sand in alternating X pattern -> 1 TNT).
//! 2. Primed TNT Fuse & Dynamics (80-tick default fuse, 0.2 initial vy hop, 10..30-tick chain reaction,
//!    safe hand-breaking, and unstable TNT silk-touch harvesting rules).
//! 3. Underwater Explosion Dampening (0 block damage in fluid unless displaced/covered by gravity blocks
//!    such as falling sand/anvil, full entity damage and knockback maintained).
//! 4. Blast Ray Attenuation & Demolition Yields (ray attenuation formula `(blast_res + 0.3) * 0.3`,
//!    100% block drop rate for TNT vs 30% for Creepers).

const std = @import("std");

// ============================================================================
// 1. TNT Crafting Recipe
// ============================================================================

pub const TntCraftingRecipe = struct {
    pub const gunpowder_per_tnt: u8 = 5;
    pub const sand_per_tnt: u8 = 4;

    pub const Ingredient = enum {
        empty,
        gunpowder,
        sand,
        red_sand,
    };

    pub const CraftingResult = struct {
        tnt_produced: u8,
        remaining_gunpowder: u8,
        remaining_sand: u8,
        remaining_red_sand: u8,
    };

    /// Calculates how many TNT blocks can be crafted from available gunpowder, sand, and red_sand.
    /// Mixed regular sand and red sand is fully supported in any combination!
    pub fn craftTnt(gunpowder: u8, sand: u8, red_sand: u8) u8 {
        const total_sand: u16 = @as(u16, sand) + @as(u16, red_sand);
        const tnt_from_gunpowder = gunpowder / gunpowder_per_tnt;
        const tnt_from_sand = @as(u8, @intCast(@min(255, total_sand / sand_per_tnt)));
        return @min(tnt_from_gunpowder, tnt_from_sand);
    }

    /// Crafts maximum possible TNT and calculates the exact remaining ingredients,
    /// prioritizing consuming regular sand before red sand.
    pub fn craftWithRemainder(gunpowder: u8, sand: u8, red_sand: u8) CraftingResult {
        const produced = TntCraftingRecipe.craftTnt(gunpowder, sand, red_sand);
        const used_gunpowder = produced * gunpowder_per_tnt;
        const remaining_gunpowder = gunpowder - used_gunpowder;

        var needed_sand: u16 = @as(u16, produced) * sand_per_tnt;
        var rem_sand = sand;
        var rem_red_sand = red_sand;

        if (needed_sand <= rem_sand) {
            rem_sand -= @intCast(needed_sand);
        } else {
            needed_sand -= rem_sand;
            rem_sand = 0;
            rem_red_sand -= @intCast(needed_sand);
        }

        return .{
            .tnt_produced = produced,
            .remaining_gunpowder = remaining_gunpowder,
            .remaining_sand = rem_sand,
            .remaining_red_sand = rem_red_sand,
        };
    }

    /// Verifies if a 3x3 grid (flat 9-element array, row-major) matches the alternating 'X' pattern:
    /// Indices 0, 2, 4, 6, 8 = gunpowder (X shape: 4 corners + center)
    /// Indices 1, 3, 5, 7 = sand or red_sand (cross shape: top, left, right, bottom)
    pub fn matchesGrid(grid: [9]Ingredient) bool {
        const gp_indices = [_]usize{ 0, 2, 4, 6, 8 };
        for (gp_indices) |idx| {
            if (grid[idx] != .gunpowder) return false;
        }
        const sand_indices = [_]usize{ 1, 3, 5, 7 };
        for (sand_indices) |idx| {
            if (grid[idx] != .sand and grid[idx] != .red_sand) return false;
        }
        return true;
    }

    /// Verifies if a 3x3 2D array matches the alternating 'X' pattern.
    pub fn matchesGrid2D(grid: [3][3]Ingredient) bool {
        var flat: [9]Ingredient = undefined;
        var r: usize = 0;
        while (r < 3) : (r += 1) {
            var c: usize = 0;
            while (c < 3) : (c += 1) {
                flat[r * 3 + c] = grid[r][c];
            }
        }
        return matchesGrid(flat);
    }
};

// ============================================================================
// 2. Primed TNT Fuse & Dynamics
// ============================================================================

pub const PrimedTntFuse = struct {
    /// Default fuse duration when primed by redstone, flint & steel, fire, etc. (80 ticks = 4.0 seconds).
    pub const default_fuse_ticks: u8 = 80;
    pub const default_fuse_seconds: f32 = 4.0;

    /// Small upward vertical impulse given to TNT upon ignition (0.2 blocks/tick).
    pub const initial_vy: f32 = 0.2;

    /// Shortened fuse duration bounds for TNT primed by another explosion (chain reaction).
    pub const min_chain_fuse_ticks: u8 = 10;
    pub const max_chain_fuse_ticks: u8 = 30;

    /// Downward gravitational acceleration applied to primed TNT entities per tick.
    pub const tnt_gravity: f32 = 0.04;

    /// Air resistance drag multiplier applied per tick.
    pub const tnt_drag: f32 = 0.98;

    /// Water/fluid resistance drag multiplier applied per tick.
    pub const tnt_fluid_drag: f32 = 0.80;

    pub const IgnitionSource = enum {
        redstone,
        flint_and_steel,
        fire_charge,
        flame_arrow,
        lava_or_fire,
        dispenser,
        chain_reaction,
        unstable_punch,
    };

    pub const HarvestResult = enum {
        drop_item,
        ignite_and_prime,
    };

    /// Deterministically computes the shortened fuse for TNT primed by an explosion (chain reaction).
    /// Maps roll_0_to_20 into [10..30] game ticks (0.5..1.5 seconds).
    pub fn chainReactionFuseTicks(roll_0_to_20: u8) u8 {
        return 10 + (roll_0_to_20 % 21);
    }

    /// Breaking placed TNT by hand or tool drops the TNT block item safely without priming.
    pub fn breaksSafelyByHand() bool {
        return true;
    }

    /// Determines harvest outcome when breaking placed TNT:
    /// - Normal TNT: Always drops safely as an item, regardless of tool or silk touch.
    /// - Unstable TNT (historical / custom flag):
    ///   - Mined with Silk Touch: safely harvested as an item.
    ///   - Hit/broken without Silk Touch: immediately ignites and primes!
    pub fn harvestPlacedTnt(unstable: bool, has_silk_touch: bool) HarvestResult {
        if (!unstable) return .drop_item;
        if (has_silk_touch) return .drop_item;
        return .ignite_and_prime;
    }

    /// Helper returning true if harvesting succeeds safely without priming.
    pub fn canHarvestSafely(unstable: bool, has_silk_touch: bool) bool {
        return harvestPlacedTnt(unstable, has_silk_touch) == .drop_item;
    }

    /// Computes the chain reaction launch velocity vector imparted onto primed TNT by an explosion.
    /// Forms the core physics foundation for TNT cannons.
    pub fn computeChainBlastVector(
        tnt_pos: [3]f32,
        blast_origin: [3]f32,
        blast_power: f32,
    ) [3]f32 {
        const dx = tnt_pos[0] - blast_origin[0];
        const dy = tnt_pos[1] - blast_origin[1];
        const dz = tnt_pos[2] - blast_origin[2];
        const dist_sq = dx * dx + dy * dy + dz * dz;
        const dist = @sqrt(dist_sq);

        const blast_radius: f32 = blast_power * 2.0;
        if (dist >= blast_radius or dist <= 0.0001) {
            return .{ 0.0, 0.0, 0.0 };
        }

        const exposure = (blast_radius - dist) / blast_radius;
        const norm_x = dx / dist;
        const norm_y = dy / dist;
        const norm_z = dz / dist;

        // Blast impulse: directional force along blast vector
        const force = exposure * blast_power * 0.5;
        return .{
            norm_x * force,
            norm_y * force + 0.1 * exposure, // slight upward component for realistic cannon arcs
            norm_z * force,
        };
    }
};

/// Represents an active Primed TNT entity ticking in the world.
pub const PrimedTntEntity = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32 = 0.0,
    vy: f32 = 0.0,
    vz: f32 = 0.0,
    fuse_ticks: u8,
    source: PrimedTntFuse.IgnitionSource,
    in_fluid: bool = false,
    covered_by_gravity_block: bool = false,

    /// Creates a standard primed TNT entity (80 ticks, 0.2 upward hop).
    pub fn initStandard(x: f32, y: f32, z: f32, source: PrimedTntFuse.IgnitionSource) PrimedTntEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .vx = 0.0,
            .vy = PrimedTntFuse.initial_vy,
            .vz = 0.0,
            .fuse_ticks = PrimedTntFuse.default_fuse_ticks,
            .source = source,
        };
    }

    /// Creates a chain-reaction primed TNT entity with shortened fuse and launch velocity.
    pub fn initChainReaction(
        x: f32,
        y: f32,
        z: f32,
        roll_0_to_20: u8,
        launch_velocity: [3]f32,
    ) PrimedTntEntity {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .vx = launch_velocity[0],
            .vy = launch_velocity[1],
            .vz = launch_velocity[2],
            .fuse_ticks = PrimedTntFuse.chainReactionFuseTicks(roll_0_to_20),
            .source = .chain_reaction,
        };
    }

    /// Advances simulation by 1 game tick (0.05 seconds):
    /// - Updates position from velocity.
    /// - Applies drag and gravity.
    /// - Decrements fuse timer.
    /// Returns true when detonation occurs (fuse_ticks reached 0).
    pub fn tick(self: *PrimedTntEntity) bool {
        self.x += self.vx;
        self.y += self.vy;
        self.z += self.vz;

        const drag: f32 = if (self.in_fluid) PrimedTntFuse.tnt_fluid_drag else PrimedTntFuse.tnt_drag;
        self.vx *= drag;
        self.vz *= drag;
        self.vy = (self.vy - PrimedTntFuse.tnt_gravity) * drag;

        if (self.fuse_ticks > 0) {
            self.fuse_ticks -= 1;
        }

        return self.fuse_ticks == 0;
    }
};

// ============================================================================
// 3. Underwater Explosion Dampening
// ============================================================================

pub const UnderwaterExplosionDampening = struct {
    /// In water, lava, or waterlogged blocks, TNT detonation deals full entity damage and knockback.
    pub fn dealsEntityDamageInWater() bool {
        return true;
    }

    /// Determines whether the explosion can destroy surrounding blocks.
    /// - If not in fluid, blocks are destroyed normally (returns true).
    /// - If in fluid (water, lava, waterlogged block): destroys 0 surrounding blocks (returns false),
    ///   UNLESS a falling gravity block (sand, gravel, or anvil) entered the same block space
    ///   as the primed TNT just before detonation, which displaces/shields the fluid check
    ///   and enables underwater block breaching (returns true).
    pub fn canDestroyBlocksWhenSubmerged(in_fluid: bool, covered_by_sand_or_anvil: bool) bool {
        if (!in_fluid) return true;
        return covered_by_sand_or_anvil;
    }

    /// Computes the number of blocks destroyed: returns 0 if submerged without gravity block shielding.
    pub fn computeDestroyedBlockCount(
        potential_blocks_in_blast: usize,
        in_fluid: bool,
        covered_by_sand_or_anvil: bool,
    ) usize {
        if (!UnderwaterExplosionDampening.canDestroyBlocksWhenSubmerged(in_fluid, covered_by_sand_or_anvil)) {
            return 0;
        }
        return potential_blocks_in_blast;
    }

    /// Computes entity damage at a given distance: water does NOT reduce entity damage in Minecraft!
    pub fn computeEntityDamage(base_damage: f32, distance: f32, max_radius: f32, in_fluid: bool) f32 {
        _ = in_fluid; // Fluids do not dampen entity damage
        if (distance >= max_radius or distance <= 0.0) return 0.0;
        const falloff = (max_radius - distance) / max_radius;
        return base_damage * falloff;
    }
};

// ============================================================================
// 4. Blast Ray Attenuation & Demolition Yields
// ============================================================================

pub const BlastRayAttenuation = struct {
    /// Standard TNT explosion power (4.0).
    pub const tnt_explosion_power: f32 = 4.0;

    /// Standard Creeper explosion power (3.0).
    pub const creeper_explosion_power: f32 = 3.0;

    /// Charged Creeper explosion power (6.0).
    pub const charged_creeper_explosion_power: f32 = 6.0;

    /// Minecraft standard ray step increment in meters (0.3).
    pub const ray_step_size: f32 = 0.3;

    /// Air resistance decay per 0.3m step (0.3 * 0.75 = 0.225).
    pub const air_decay_per_step: f32 = 0.225;

    /// Standard Minecraft ray attenuation per step through a block with given blast resistance:
    /// `(blast_resistance + 0.3) * 0.3`
    pub fn computeStepAttenuation(blast_resistance: f32) f32 {
        return (blast_resistance + 0.3) * 0.3;
    }

    /// Block drop probability for blocks destroyed by TNT in modern Minecraft (100% / 1.0).
    pub fn tntBlockDropProbability() f32 {
        return 1.0;
    }

    /// Block drop probability for blocks destroyed by Creepers (~30% / 0.3).
    pub fn creeperBlockDropProbability() f32 {
        return 0.3;
    }

    /// Decrements blast ray power through a block with given blast resistance.
    pub fn stepRayPower(current_power: f32, blast_resistance: f32) f32 {
        const att = BlastRayAttenuation.computeStepAttenuation(blast_resistance);
        const rem = current_power - att;
        if (rem <= 0.0) return 0.0;
        return rem;
    }

    /// Decrements blast ray power including distance-based air decay.
    pub fn stepRayPowerWithDecay(current_power: f32, blast_resistance: f32, step_size: f32) f32 {
        const att = BlastRayAttenuation.computeStepAttenuation(blast_resistance);
        const decay = step_size * 0.75;
        const rem = current_power - att - decay;
        if (rem <= 0.0) return 0.0;
        return rem;
    }

    /// Reference blast resistance values from standard Minecraft blocks.
    pub const Resistance = struct {
        pub const air: f32 = 0.0;
        pub const leaves: f32 = 0.2;
        pub const dirt: f32 = 0.5;
        pub const sand: f32 = 0.5;
        pub const gravel: f32 = 0.6;
        pub const wood_planks: f32 = 2.0;
        pub const cobblestone: f32 = 6.0;
        pub const stone: f32 = 6.0;
        pub const iron_block: f32 = 6.0;
        pub const water: f32 = 100.0;
        pub const lava: f32 = 100.0;
        pub const obsidian: f32 = 1200.0;
        pub const anvil: f32 = 1200.0;
        pub const bedrock: f32 = 3600000.0;
    };

    /// Simulates a ray through sequential blocks, counting how many blocks it breaches
    /// before its blast power is exhausted (<= 0.0).
    pub fn countBreachedBlocks(initial_power: f32, resistances: []const f32) usize {
        var power = initial_power;
        var breached: usize = 0;
        for (resistances) |res| {
            if (power <= 0.0) break;
            const next = stepRayPower(power, res);
            breached += 1;
            power = next;
        }
        return breached;
    }
};

// ============================================================================
// Root-Level Module Aliases & Exports
// ============================================================================

pub const craftTnt = TntCraftingRecipe.craftTnt;
pub const default_fuse_ticks = PrimedTntFuse.default_fuse_ticks;
pub const initial_vy = PrimedTntFuse.initial_vy;
pub const chainReactionFuseTicks = PrimedTntFuse.chainReactionFuseTicks;
pub const breaksSafelyByHand = PrimedTntFuse.breaksSafelyByHand;
pub const dealsEntityDamageInWater = UnderwaterExplosionDampening.dealsEntityDamageInWater;
pub const canDestroyBlocksWhenSubmerged = UnderwaterExplosionDampening.canDestroyBlocksWhenSubmerged;
pub const computeStepAttenuation = BlastRayAttenuation.computeStepAttenuation;
pub const tntBlockDropProbability = BlastRayAttenuation.tntBlockDropProbability;

// ============================================================================
// Unit Tests (Comprehensive Test Suite: 16 Tests)
// ============================================================================

test "TntCraftingRecipe: exact 5 gunpowder and 4 sand yields 1 tnt" {
    // Exactly 5 gunpowder and 4 sand -> 1 TNT
    try std.testing.expectEqual(@as(u8, 1), craftTnt(5, 4, 0));
    // Exactly 5 gunpowder and 4 red_sand -> 1 TNT
    try std.testing.expectEqual(@as(u8, 1), craftTnt(5, 0, 4));
    // Exactly 5 gunpowder and 2 sand + 2 red_sand -> 1 TNT
    try std.testing.expectEqual(@as(u8, 1), craftTnt(5, 2, 2));
}

test "TntCraftingRecipe: mixed regular sand and red sand allows crafting multiple tnt" {
    // 10 gunpowder, 3 regular sand + 5 red sand = 8 total sand -> 2 TNT
    try std.testing.expectEqual(@as(u8, 2), craftTnt(10, 3, 5));
    // 15 gunpowder, 1 regular sand + 11 red sand = 12 total sand -> 3 TNT
    try std.testing.expectEqual(@as(u8, 3), craftTnt(15, 1, 11));
    // 20 gunpowder, 16 sand -> 4 TNT
    try std.testing.expectEqual(@as(u8, 4), craftTnt(20, 16, 0));
}

test "TntCraftingRecipe: insufficient ingredients yields 0 tnt" {
    // Only 4 gunpowder (need 5)
    try std.testing.expectEqual(@as(u8, 0), craftTnt(4, 4, 0));
    // Only 3 sand (need 4)
    try std.testing.expectEqual(@as(u8, 0), craftTnt(5, 2, 1));
    // 0 gunpowder
    try std.testing.expectEqual(@as(u8, 0), craftTnt(0, 10, 10));
    // 0 sand
    try std.testing.expectEqual(@as(u8, 0), craftTnt(100, 0, 0));
}

test "TntCraftingRecipe: craftWithRemainder preserves unused materials" {
    // 13 gunpowder, 6 sand, 5 red sand (total sand = 11)
    // 13 / 5 = 2 TNT; 11 / 4 = 2 TNT.
    // 2 TNT uses 10 gunpowder (3 remaining), and 8 sand (6 regular used, 2 red sand used -> 0 reg sand, 3 red sand remaining).
    const res = TntCraftingRecipe.craftWithRemainder(13, 6, 5);
    try std.testing.expectEqual(@as(u8, 2), res.tnt_produced);
    try std.testing.expectEqual(@as(u8, 3), res.remaining_gunpowder);
    try std.testing.expectEqual(@as(u8, 0), res.remaining_sand);
    try std.testing.expectEqual(@as(u8, 3), res.remaining_red_sand);
}

test "TntCraftingRecipe: 3x3 alternating X grid pattern validation" {
    // Standard sand alternating X pattern:
    // G S G
    // S G S
    // G S G
    const valid_grid = [9]TntCraftingRecipe.Ingredient{
        .gunpowder, .sand,      .gunpowder,
        .sand,      .gunpowder, .sand,
        .gunpowder, .sand,      .gunpowder,
    };
    try std.testing.expect(TntCraftingRecipe.matchesGrid(valid_grid));

    // Valid with red_sand and mixed sand:
    const valid_mixed = [9]TntCraftingRecipe.Ingredient{
        .gunpowder, .red_sand,  .gunpowder,
        .sand,      .gunpowder, .red_sand,
        .gunpowder, .sand,      .gunpowder,
    };
    try std.testing.expect(TntCraftingRecipe.matchesGrid(valid_mixed));

    // Invalid: center is sand instead of gunpowder
    const invalid_center = [9]TntCraftingRecipe.Ingredient{
        .gunpowder, .sand, .gunpowder,
        .sand,      .sand, .sand,
        .gunpowder, .sand, .gunpowder,
    };
    try std.testing.expect(!TntCraftingRecipe.matchesGrid(invalid_center));

    // 2D grid helper test
    const grid_2d = [3][3]TntCraftingRecipe.Ingredient{
        .{ .gunpowder, .sand, .gunpowder },
        .{ .sand, .gunpowder, .sand },
        .{ .gunpowder, .sand, .gunpowder },
    };
    try std.testing.expect(TntCraftingRecipe.matchesGrid2D(grid_2d));
}

test "PrimedTntFuse: default fuse ticks is 80 and initial vy hop is 0.2" {
    try std.testing.expectEqual(@as(u8, 80), default_fuse_ticks);
    try std.testing.expectEqual(@as(f32, 0.2), initial_vy);
    try std.testing.expectEqual(@as(f32, 4.0), PrimedTntFuse.default_fuse_seconds);

    const entity = PrimedTntEntity.initStandard(10.0, 64.0, 10.0, .redstone);
    try std.testing.expectEqual(@as(u8, 80), entity.fuse_ticks);
    try std.testing.expectEqual(@as(f32, 0.2), entity.vy);
    try std.testing.expectEqual(@as(f32, 0.0), entity.vx);
    try std.testing.expectEqual(@as(f32, 0.0), entity.vz);
    try std.testing.expectEqual(PrimedTntFuse.IgnitionSource.redstone, entity.source);
}

test "PrimedTntFuse: chain reaction fuse rolls strictly within 10 to 30 ticks" {
    // Test the full roll space 0..20
    var roll: u8 = 0;
    while (roll <= 20) : (roll += 1) {
        const ticks = chainReactionFuseTicks(roll);
        try std.testing.expect(ticks >= 10);
        try std.testing.expect(ticks <= 30);
        try std.testing.expectEqual(@as(u8, 10 + roll), ticks);
    }

    // Roll 0 -> 10 ticks (0.5s)
    try std.testing.expectEqual(@as(u8, 10), chainReactionFuseTicks(0));
    // Roll 20 -> 30 ticks (1.5s)
    try std.testing.expectEqual(@as(u8, 30), chainReactionFuseTicks(20));
    // Roll 21 (wraps) -> 10 ticks
    try std.testing.expectEqual(@as(u8, 10), chainReactionFuseTicks(21));
}

test "PrimedTntFuse: placed TNT breaks safely by hand without priming" {
    try std.testing.expect(breaksSafelyByHand());
    try std.testing.expect(PrimedTntFuse.breaksSafelyByHand());
    try std.testing.expect(PrimedTntFuse.canHarvestSafely(false, false));
    try std.testing.expectEqual(PrimedTntFuse.HarvestResult.drop_item, PrimedTntFuse.harvestPlacedTnt(false, false));
}

test "PrimedTntFuse: unstable TNT silk-touch harvesting vs bare hand ignition" {
    // Normal TNT: drops safely regardless of silk touch
    try std.testing.expectEqual(PrimedTntFuse.HarvestResult.drop_item, PrimedTntFuse.harvestPlacedTnt(false, false));
    try std.testing.expectEqual(PrimedTntFuse.HarvestResult.drop_item, PrimedTntFuse.harvestPlacedTnt(false, true));

    // Unstable TNT mined without silk touch: ignites and primes!
    try std.testing.expectEqual(PrimedTntFuse.HarvestResult.ignite_and_prime, PrimedTntFuse.harvestPlacedTnt(true, false));
    try std.testing.expect(!PrimedTntFuse.canHarvestSafely(true, false));

    // Unstable TNT mined WITH Silk Touch: drops safely as an item!
    try std.testing.expectEqual(PrimedTntFuse.HarvestResult.drop_item, PrimedTntFuse.harvestPlacedTnt(true, true));
    try std.testing.expect(PrimedTntFuse.canHarvestSafely(true, true));
}

test "PrimedTntFuse: entity physics simulation with gravity and drag over ticks" {
    var entity = PrimedTntEntity.initStandard(0.0, 10.0, 0.0, .flint_and_steel);

    // Initial tick
    const detonated_tick1 = entity.tick();
    try std.testing.expect(!detonated_tick1);
    try std.testing.expectEqual(@as(u8, 79), entity.fuse_ticks);
    // Position y moved by initial vy (0.2)
    try std.testing.expect(entity.y > 10.0);
    // vy is updated by gravity (-0.04) and drag (0.98): (0.2 - 0.04) * 0.98 = 0.1568
    try std.testing.expect(std.math.approxEqAbs(f32, entity.vy, 0.1568, 0.001));

    // Tick the remaining 78 ticks until fuse reaches 0
    var i: usize = 0;
    while (i < 78) : (i += 1) {
        try std.testing.expect(!entity.tick());
    }
    // Final tick at tick 80
    const detonated_final = entity.tick();
    try std.testing.expect(detonated_final);
    try std.testing.expectEqual(@as(u8, 0), entity.fuse_ticks);
}

test "PrimedTntFuse: chain reaction blast vector calculation for cannon propulsion" {
    const blast_origin = [3]f32{ 0.0, 0.0, 0.0 };
    const tnt_pos = [3]f32{ 2.0, 0.0, 0.0 };
    const blast_power: f32 = 4.0;

    const vec = PrimedTntFuse.computeChainBlastVector(tnt_pos, blast_origin, blast_power);
    // Should propel strongly along +X
    try std.testing.expect(vec[0] > 0.0);
    // Should have small upward bias for trajectory arc
    try std.testing.expect(vec[1] > 0.0);
    // Z component should be zero since blast is aligned with X
    try std.testing.expectEqual(@as(f32, 0.0), vec[2]);

    // Beyond blast radius (blast_radius = 4.0 * 2.0 = 8.0 blocks)
    const far_pos = [3]f32{ 10.0, 0.0, 0.0 };
    const far_vec = PrimedTntFuse.computeChainBlastVector(far_pos, blast_origin, blast_power);
    try std.testing.expectEqual(@as(f32, 0.0), far_vec[0]);
    try std.testing.expectEqual(@as(f32, 0.0), far_vec[1]);
    try std.testing.expectEqual(@as(f32, 0.0), far_vec[2]);
}

test "UnderwaterExplosionDampening: full entity damage and knockback deals in water" {
    try std.testing.expect(dealsEntityDamageInWater());
    try std.testing.expect(UnderwaterExplosionDampening.dealsEntityDamageInWater());

    // Entity damage at 2.0 blocks from 4.0 radius explosion
    const damage_in_air = UnderwaterExplosionDampening.computeEntityDamage(20.0, 2.0, 4.0, false);
    const damage_in_water = UnderwaterExplosionDampening.computeEntityDamage(20.0, 2.0, 4.0, true);
    try std.testing.expectEqual(damage_in_air, damage_in_water);
    try std.testing.expect(std.math.approxEqAbs(f32, damage_in_water, 10.0, 0.001));

    // Outside blast radius
    try std.testing.expectEqual(@as(f32, 0.0), UnderwaterExplosionDampening.computeEntityDamage(20.0, 5.0, 4.0, true));
}

test "UnderwaterExplosionDampening: submerged TNT destroys 0 blocks unless covered by sand/anvil" {
    // Air explosion: can destroy blocks
    try std.testing.expect(canDestroyBlocksWhenSubmerged(false, false));
    try std.testing.expectEqual(@as(usize, 32), UnderwaterExplosionDampening.computeDestroyedBlockCount(32, false, false));

    // Submerged in water/lava without sand/anvil: destroys 0 blocks!
    try std.testing.expect(!canDestroyBlocksWhenSubmerged(true, false));
    try std.testing.expectEqual(@as(usize, 0), UnderwaterExplosionDampening.computeDestroyedBlockCount(32, true, false));

    // Submerged in water/lava WITH sand/anvil covering: destroys blocks (cannon breach trick)!
    try std.testing.expect(canDestroyBlocksWhenSubmerged(true, true));
    try std.testing.expectEqual(@as(usize, 32), UnderwaterExplosionDampening.computeDestroyedBlockCount(32, true, true));
}

test "BlastRayAttenuation: step attenuation formula for various block blast resistances" {
    // Air: (0.0 + 0.3) * 0.3 = 0.09
    const att_air = computeStepAttenuation(BlastRayAttenuation.Resistance.air);
    try std.testing.expect(std.math.approxEqAbs(f32, att_air, 0.09, 0.0001));

    // Dirt/Sand: (0.5 + 0.3) * 0.3 = 0.24
    const att_dirt = computeStepAttenuation(BlastRayAttenuation.Resistance.dirt);
    try std.testing.expect(std.math.approxEqAbs(f32, att_dirt, 0.24, 0.0001));

    // Cobblestone/Stone: (6.0 + 0.3) * 0.3 = 1.89
    const att_stone = computeStepAttenuation(BlastRayAttenuation.Resistance.stone);
    try std.testing.expect(std.math.approxEqAbs(f32, att_stone, 1.89, 0.0001));

    // Obsidian: (1200.0 + 0.3) * 0.3 = 360.09
    const att_obsidian = computeStepAttenuation(BlastRayAttenuation.Resistance.obsidian);
    try std.testing.expect(std.math.approxEqAbs(f32, att_obsidian, 360.09, 0.0001));
}

test "BlastRayAttenuation: 100% block drop probability for TNT vs creeper explosions" {
    try std.testing.expectEqual(@as(f32, 1.0), tntBlockDropProbability());
    try std.testing.expectEqual(@as(f32, 1.0), BlastRayAttenuation.tntBlockDropProbability());

    // Creeper drop rate is ~0.3
    try std.testing.expectEqual(@as(f32, 0.3), BlastRayAttenuation.creeperBlockDropProbability());
}

test "BlastRayAttenuation: ray penetration simulation through dirt, stone, and obsidian" {
    // Power 4.0 through multiple dirt blocks (att = 0.24 per block)
    // 4.0 / 0.24 ~ 16.6 blocks
    const dirt_layers = [_]f32{BlastRayAttenuation.Resistance.dirt} ** 20;
    const breached_dirt = BlastRayAttenuation.countBreachedBlocks(4.0, &dirt_layers);
    try std.testing.expect(breached_dirt >= 16 and breached_dirt <= 17);

    // Power 4.0 through stone (att = 1.89 per block)
    // 4.0 - 1.89 = 2.11 (breaches 1st) -> 2.11 - 1.89 = 0.22 (breaches 2nd) -> 0.22 - 1.89 <= 0 (breaches 3rd and stops)
    const stone_layers = [_]f32{BlastRayAttenuation.Resistance.stone} ** 5;
    const breached_stone = BlastRayAttenuation.countBreachedBlocks(4.0, &stone_layers);
    try std.testing.expectEqual(@as(usize, 3), breached_stone);

    // Power 4.0 against Obsidian (att = 360.09)
    // 4.0 - 360.09 <= 0 immediately, stops on 1st block
    const obsidian_layers = [_]f32{BlastRayAttenuation.Resistance.obsidian} ** 3;
    const breached_obsidian = BlastRayAttenuation.countBreachedBlocks(4.0, &obsidian_layers);
    try std.testing.expectEqual(@as(usize, 1), breached_obsidian);
}
