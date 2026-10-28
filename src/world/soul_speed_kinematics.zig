const std = @import("std");
const block_mod = @import("block.zig");
const nether_biomes = @import("nether_biomes.zig");

// ============================================================================
// Constants
// ============================================================================

/// Base speed multiplier when Soul Speed is active (1.30x normal speed).
pub const base_speed_multiplier: f32 = 1.30;

/// Speed multiplier increment per enchantment level (+0.105x per level).
pub const level_speed_step: f32 = 0.105;

/// Normal ground movement speed multiplier (1.0x).
pub const normal_speed: f32 = 1.0;

/// Soul sand movement drag reduction (-60% speed without Soul Speed).
pub const soul_sand_drag_reduction: f32 = 0.60;

/// Effective movement speed multiplier on soul sand without Soul Speed (0.40x).
pub const soul_sand_drag_multiplier: f32 = normal_speed - soul_sand_drag_reduction; // 0.40

/// Normal movement speed on soul soil without Soul Speed (1.0x, no drag).
pub const soul_soil_normal_multiplier: f32 = 1.0;

/// Base chance of damaging boots per soul block step (4% = 0.04).
pub const base_durability_wear_probability: f32 = 0.04;

/// Particles emitted per footstep per Soul Speed level (2 * level).
pub const particles_per_level: u32 = 2;

/// Maximum standard enchantment level for Soul Speed.
pub const max_soul_speed_level: u3 = 3;

/// Maximum standard enchantment level for Unbreaking.
pub const max_unbreaking_level: u3 = 3;

// ============================================================================
// Soul Block Recognition
// ============================================================================

/// Categorization of terrain blocks relevant to Soul Speed kinematics.
pub const SoulBlockKind = enum(u8) {
    none = 0,
    soul_sand = 1,
    soul_soil = 2,

    /// Whether this block kind qualifies as a soul block (Soul Sand or Soul Soil).
    pub fn isSoulBlock(self: SoulBlockKind) bool {
        return self == .soul_sand or self == .soul_soil;
    }

    /// Whether this block naturally applies soul sand drag (-60% speed).
    pub fn hasSoulSandDrag(self: SoulBlockKind) bool {
        return self == .soul_sand;
    }

    /// User-friendly name identifier.
    pub fn name(self: SoulBlockKind) []const u8 {
        return switch (self) {
            .none => "none",
            .soul_sand => "soul_sand",
            .soul_soil => "soul_soil",
        };
    }
};

/// Recognizes whether a SoulBlockKind is a soul block.
pub fn isSoulBlockKind(kind: SoulBlockKind) bool {
    return kind.isSoulBlock();
}

/// Identifies soul block kind from world BlockId.
pub fn identifyBlockId(id: block_mod.BlockId) SoulBlockKind {
    return switch (id) {
        .soul_sand => .soul_sand,
        else => .none,
    };
}

/// Returns true if the BlockId is any soul block.
pub fn isSoulBlockId(id: block_mod.BlockId) bool {
    return identifyBlockId(id).isSoulBlock();
}

/// Identifies soul block kind from NetherBlock identifier.
pub fn identifyNetherBlock(nb: nether_biomes.NetherBlock) SoulBlockKind {
    return switch (nb) {
        .soul_sand => .soul_sand,
        .soul_soil => .soul_soil,
        else => .none,
    };
}

/// Returns true if the NetherBlock is any soul block.
pub fn isSoulNetherBlock(nb: nether_biomes.NetherBlock) bool {
    return identifyNetherBlock(nb).isSoulBlock();
}

/// Identifies soul block kind from block name string.
pub fn identifyBlockByName(block_name: []const u8) SoulBlockKind {
    if (std.mem.eql(u8, block_name, "soul_sand") or
        std.mem.eql(u8, block_name, "minecraft:soul_sand"))
    {
        return .soul_sand;
    }
    if (std.mem.eql(u8, block_name, "soul_soil") or
        std.mem.eql(u8, block_name, "minecraft:soul_soil"))
    {
        return .soul_soil;
    }
    return .none;
}

/// Returns true if the block name represents a soul block.
pub fn isSoulBlockByName(block_name: []const u8) bool {
    return identifyBlockByName(block_name).isSoulBlock();
}

// ============================================================================
// Kinematics & Speed Boost Calculation
// ============================================================================

/// Computes the active Soul Speed speed boost multiplier:
/// `speed_multiplier = 1.30 + 0.105 * @as(f32, @floatFromInt(level))`
/// Level 1 = 1.405x, Level 2 = 1.510x, Level 3 = 1.615x normal speed.
pub fn calculateSoulSpeedMultiplier(level: u3) f32 {
    return base_speed_multiplier + level_speed_step * @as(f32, @floatFromInt(level));
}

/// Computes the effective movement speed multiplier given the player's Soul Speed level
/// and the block traversed.
/// - On Soul Sand or Soul Soil with Soul Speed (level >= 1):
///   `speed_multiplier = 1.30 + 0.105 * level`
///   Normal soul sand drag (-60% speed) is negated.
/// - On Soul Sand with level == 0:
///   Normal soul sand drag applies (0.40x multiplier).
/// - On Soul Soil with level == 0:
///   Normal ground speed applies (1.0x multiplier).
/// - On non-soul blocks (any level):
///   Normal ground speed applies (1.0x multiplier).
pub fn calculateEffectiveSpeed(level: u3, block: SoulBlockKind) f32 {
    if (block.isSoulBlock()) {
        if (level > 0) {
            return calculateSoulSpeedMultiplier(level);
        } else {
            return if (block == .soul_sand) soul_sand_drag_multiplier else soul_soil_normal_multiplier;
        }
    }
    return normal_speed;
}

/// Checks whether normal soul sand drag is negated.
/// Negated whenever Soul Speed level is >= 1 on any soul block.
pub fn isSoulSandDragNegated(level: u3, block: SoulBlockKind) bool {
    return level > 0 and block.isSoulBlock();
}

// ============================================================================
// Cyan Soul Particle Trails
// ============================================================================

/// RGBA color definition for cyan soul fire particles.
pub const ParticleColor = struct {
    r: f32 = 0.20,
    g: f32 = 0.85,
    b: f32 = 0.90,
    a: f32 = 1.0,
};

/// Default cyan color matching soul fire / soul sand valley ambiance.
pub const cyan_soul_particle_color = ParticleColor{
    .r = 0.20,
    .g = 0.85,
    .b = 0.90,
    .a = 1.0,
};

/// Representation of an emitted cyan soul particle.
pub const SoulParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    color: ParticleColor = cyan_soul_particle_color,
    lifetime_ticks: u16 = 20,
};

/// Returns the number of cyan soul particles emitted per footstep.
/// Footsteps on soul blocks emit `2 * level` cyan particles.
/// Zero particles are emitted if not on a soul block or if level == 0.
pub fn getParticleCountPerStep(level: u3, block: SoulBlockKind) u32 {
    if (!block.isSoulBlock() or level == 0) return 0;
    return particles_per_level * @as(u32, level);
}

/// Emits cyan soul particles at the footstep position into `out_buffer`.
/// Returns the actual number of particles written.
pub fn emitSoulParticles(
    level: u3,
    block: SoulBlockKind,
    foot_pos: [3]f32,
    out_buffer: []SoulParticle,
    rng: ?*std.Random,
) usize {
    const count = getParticleCountPerStep(level, block);
    const to_emit = @min(count, out_buffer.len);
    for (0..to_emit) |i| {
        const fi: f32 = @floatFromInt(i);
        const spread_x: f32 = if (rng) |r| (r.float(f32) - 0.5) * 0.4 else (fi * 0.08 - 0.12);
        const spread_z: f32 = if (rng) |r| (r.float(f32) - 0.5) * 0.4 else (@as(f32, @floatFromInt(i % 2)) * 0.16 - 0.08);
        const vy: f32 = if (rng) |r| 0.04 + r.float(f32) * 0.04 else 0.06;
        const vx: f32 = if (rng) |r| (r.float(f32) - 0.5) * 0.02 else 0.0;
        const vz: f32 = if (rng) |r| (r.float(f32) - 0.5) * 0.02 else 0.0;

        out_buffer[i] = SoulParticle{
            .x = foot_pos[0] + spread_x,
            .y = foot_pos[1] + 0.05,
            .z = foot_pos[2] + spread_z,
            .vx = vx,
            .vy = vy,
            .vz = vz,
            .color = cyan_soul_particle_color,
            .lifetime_ticks = 20,
        };
    }
    return to_emit;
}

// ============================================================================
// Boot Durability Wear & Unbreaking Scaling
// ============================================================================

/// Calculates boot durability wear probability with Unbreaking scaling:
/// `wear_probability = 0.04 / @as(f32, @floatFromInt(unbreaking_level + 1))`
/// Unbreaking 0: 0.04 (4.0%)
/// Unbreaking 1: 0.02 (2.0%)
/// Unbreaking 2: 0.013333333 (~1.33%)
/// Unbreaking 3: 0.01 (1.0%)
pub fn calculateDurabilityWearProbability(unbreaking_level: u3) f32 {
    return base_durability_wear_probability / @as(f32, @floatFromInt(unbreaking_level + 1));
}

/// Evaluates wear probability for a single step in context.
/// Returns 0.0 if not on a soul block or if Soul Speed is not active.
pub fn getWearProbabilityForStep(
    soul_speed_level: u3,
    unbreaking_level: u3,
    block: SoulBlockKind,
) f32 {
    if (!block.isSoulBlock() or soul_speed_level == 0) return 0.0;
    return calculateDurabilityWearProbability(unbreaking_level);
}

/// Determines whether a durability damage point should be applied to boots
/// based on a random roll in [0.0, 1.0).
pub fn shouldWearBootDurability(
    random_roll_0_to_1: f32,
    soul_speed_level: u3,
    unbreaking_level: u3,
    block: SoulBlockKind,
) bool {
    const prob = getWearProbabilityForStep(soul_speed_level, unbreaking_level, block);
    return prob > 0.0 and random_roll_0_to_1 < prob;
}

/// Result of evaluating and applying durability wear on boots.
pub const DurabilityDamageOutcome = struct {
    damaged: bool,
    durability_deducted: u16,
    remaining_durability: u16,
    broken: bool,
};

/// Applies durability wear to boots from a soul block step.
/// If roll < wear_probability, reduces durability by 1 point.
/// If durability reaches 0, the boots break.
pub fn applyBootDurabilityWear(
    current_durability: u16,
    random_roll_0_to_1: f32,
    soul_speed_level: u3,
    unbreaking_level: u3,
    block: SoulBlockKind,
) DurabilityDamageOutcome {
    if (!shouldWearBootDurability(random_roll_0_to_1, soul_speed_level, unbreaking_level, block)) {
        return .{
            .damaged = false,
            .durability_deducted = 0,
            .remaining_durability = current_durability,
            .broken = current_durability == 0,
        };
    }
    if (current_durability <= 1) {
        return .{
            .damaged = true,
            .durability_deducted = current_durability,
            .remaining_durability = 0,
            .broken = true,
        };
    }
    return .{
        .damaged = true,
        .durability_deducted = 1,
        .remaining_durability = current_durability - 1,
        .broken = false,
    };
}

// ============================================================================
// Kinematics Controller & State Tracker
// ============================================================================

/// Outcome of a single footstep event.
pub const StepEvent = struct {
    step_number: u64,
    speed_multiplier: f32,
    drag_negated: bool,
    particles_emitted: u32,
    boot_damaged: bool,
    remaining_durability: u16,
    boots_broken: bool,
};

/// Tracks player soul speed state, accumulated step distance, boot wear, and particles.
pub const SoulSpeedKinematics = struct {
    soul_speed_level: u3 = 0,
    unbreaking_level: u3 = 0,
    boot_durability: u16 = 429, // Default diamond boots durability
    max_boot_durability: u16 = 429,
    is_boots_broken: bool = false,
    distance_accumulated: f32 = 0.0,
    step_distance_threshold: f32 = 1.0, // 1 block per step event
    total_steps: u64 = 0,
    total_wear_damage: u64 = 0,
    total_particles_emitted: u64 = 0,

    pub fn init(soul_speed_level: u3, unbreaking_level: u3, boot_durability: u16) SoulSpeedKinematics {
        return .{
            .soul_speed_level = soul_speed_level,
            .unbreaking_level = unbreaking_level,
            .boot_durability = boot_durability,
            .max_boot_durability = boot_durability,
            .is_boots_broken = (boot_durability == 0),
        };
    }

    /// Whether Soul Speed is currently active and functional on boots.
    pub fn hasActiveSoulSpeed(self: SoulSpeedKinematics) bool {
        return self.soul_speed_level > 0 and !self.is_boots_broken and self.boot_durability > 0;
    }

    /// Effective level taking boot brokenness into account.
    pub fn getActiveLevel(self: SoulSpeedKinematics) u3 {
        return if (self.hasActiveSoulSpeed()) self.soul_speed_level else 0;
    }

    /// Current speed multiplier for a block given the active state.
    pub fn getCurrentSpeedMultiplier(self: SoulSpeedKinematics, block: SoulBlockKind) f32 {
        return calculateEffectiveSpeed(self.getActiveLevel(), block);
    }

    /// Triggers a footstep on the specified block with a given random roll.
    pub fn onStep(self: *SoulSpeedKinematics, block: SoulBlockKind, random_roll: f32) StepEvent {
        self.total_steps += 1;
        const active_level = self.getActiveLevel();
        const speed = calculateEffectiveSpeed(active_level, block);
        const drag_negated = isSoulSandDragNegated(active_level, block);
        const p_count = getParticleCountPerStep(active_level, block);
        self.total_particles_emitted += p_count;

        var damaged = false;
        if (self.hasActiveSoulSpeed()) {
            const wear_outcome = applyBootDurabilityWear(
                self.boot_durability,
                random_roll,
                self.soul_speed_level,
                self.unbreaking_level,
                block,
            );
            if (wear_outcome.damaged) {
                damaged = true;
                self.boot_durability = wear_outcome.remaining_durability;
                self.total_wear_damage += wear_outcome.durability_deducted;
                if (wear_outcome.broken) {
                    self.is_boots_broken = true;
                }
            }
        }

        return .{
            .step_number = self.total_steps,
            .speed_multiplier = speed,
            .drag_negated = drag_negated,
            .particles_emitted = p_count,
            .boot_damaged = damaged,
            .remaining_durability = self.boot_durability,
            .boots_broken = self.is_boots_broken,
        };
    }

    /// Accumulates horizontal movement (dx, dz) and fires a step event whenever
    /// accumulated distance reaches or exceeds `step_distance_threshold`.
    pub fn updateMovement(
        self: *SoulSpeedKinematics,
        dx: f32,
        dz: f32,
        block: SoulBlockKind,
        random_roll: f32,
    ) ?StepEvent {
        const horizontal_dist = @sqrt(dx * dx + dz * dz);
        self.distance_accumulated += horizontal_dist;
        if (self.distance_accumulated >= self.step_distance_threshold) {
            self.distance_accumulated -= self.step_distance_threshold;
            return self.onStep(block, random_roll);
        }
        return null;
    }
};

// ============================================================================
// Comprehensive Unit Test Suite (15+ Tests)
// ============================================================================

test "speed multiplier: Level 1 on soul sand is exactly 1.405x" {
    const mult = calculateEffectiveSpeed(1, .soul_sand);
    try std.testing.expectApproxEqAbs(@as(f32, 1.405), mult, 0.0001);
}

test "speed multiplier: Level 2 on soul sand is exactly 1.510x" {
    const mult = calculateEffectiveSpeed(2, .soul_sand);
    try std.testing.expectApproxEqAbs(@as(f32, 1.510), mult, 0.0001);
}

test "speed multiplier: Level 3 on soul sand is exactly 1.615x" {
    const mult = calculateEffectiveSpeed(3, .soul_sand);
    try std.testing.expectApproxEqAbs(@as(f32, 1.615), mult, 0.0001);
}

test "speed multiplier: Levels 1, 2, 3 on soul soil match soul sand boost" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.405), calculateEffectiveSpeed(1, .soul_soil), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.510), calculateEffectiveSpeed(2, .soul_soil), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.615), calculateEffectiveSpeed(3, .soul_soil), 0.0001);
}

test "speed multiplier: Level 0 on soul sand applies -60% drag (0.40x)" {
    const mult = calculateEffectiveSpeed(0, .soul_sand);
    try std.testing.expectApproxEqAbs(@as(f32, 0.40), mult, 0.0001);
}

test "speed multiplier: Level 0 on soul soil maintains 1.0x normal speed" {
    const mult = calculateEffectiveSpeed(0, .soul_soil);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mult, 0.0001);
}

test "speed multiplier: Level 0 on non-soul block maintains 1.0x normal speed" {
    const mult = calculateEffectiveSpeed(0, .none);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), mult, 0.0001);
}

test "speed multiplier: active Soul Speed on non-soul block grants no boost (1.0x)" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), calculateEffectiveSpeed(1, .none), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), calculateEffectiveSpeed(2, .none), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), calculateEffectiveSpeed(3, .none), 0.0001);
}

test "soul sand drag negation: active Soul Speed negates drag on soul sand" {
    try std.testing.expect(isSoulSandDragNegated(1, .soul_sand));
    try std.testing.expect(isSoulSandDragNegated(2, .soul_sand));
    try std.testing.expect(isSoulSandDragNegated(3, .soul_sand));
    try std.testing.expect(isSoulSandDragNegated(1, .soul_soil));
}

test "soul sand drag negation: Level 0 does not negate drag on soul sand" {
    try std.testing.expect(!isSoulSandDragNegated(0, .soul_sand));
    try std.testing.expect(!isSoulSandDragNegated(0, .soul_soil));
    try std.testing.expect(!isSoulSandDragNegated(0, .none));
}

test "block recognition: SoulBlockKind enum predicates" {
    try std.testing.expect(SoulBlockKind.soul_sand.isSoulBlock());
    try std.testing.expect(SoulBlockKind.soul_soil.isSoulBlock());
    try std.testing.expect(!SoulBlockKind.none.isSoulBlock());

    try std.testing.expect(SoulBlockKind.soul_sand.hasSoulSandDrag());
    try std.testing.expect(!SoulBlockKind.soul_soil.hasSoulSandDrag());
    try std.testing.expect(!SoulBlockKind.none.hasSoulSandDrag());
}

test "block recognition: BlockId soul_sand mapped correctly, others are none" {
    try std.testing.expectEqual(SoulBlockKind.soul_sand, identifyBlockId(.soul_sand));
    try std.testing.expectEqual(SoulBlockKind.none, identifyBlockId(.stone));
    try std.testing.expectEqual(SoulBlockKind.none, identifyBlockId(.dirt));
    try std.testing.expectEqual(SoulBlockKind.none, identifyBlockId(.air));

    try std.testing.expect(isSoulBlockId(.soul_sand));
    try std.testing.expect(!isSoulBlockId(.stone));
}

test "block recognition: NetherBlock soul_sand and soul_soil mapped correctly" {
    try std.testing.expectEqual(SoulBlockKind.soul_sand, identifyNetherBlock(.soul_sand));
    try std.testing.expectEqual(SoulBlockKind.soul_soil, identifyNetherBlock(.soul_soil));
    try std.testing.expectEqual(SoulBlockKind.none, identifyNetherBlock(.netherrack));
    try std.testing.expectEqual(SoulBlockKind.none, identifyNetherBlock(.basalt));

    try std.testing.expect(isSoulNetherBlock(.soul_sand));
    try std.testing.expect(isSoulNetherBlock(.soul_soil));
    try std.testing.expect(!isSoulNetherBlock(.netherrack));
}

test "block recognition: string block names matched correctly" {
    try std.testing.expectEqual(SoulBlockKind.soul_sand, identifyBlockByName("soul_sand"));
    try std.testing.expectEqual(SoulBlockKind.soul_sand, identifyBlockByName("minecraft:soul_sand"));
    try std.testing.expectEqual(SoulBlockKind.soul_soil, identifyBlockByName("soul_soil"));
    try std.testing.expectEqual(SoulBlockKind.soul_soil, identifyBlockByName("minecraft:soul_soil"));
    try std.testing.expectEqual(SoulBlockKind.none, identifyBlockByName("dirt"));
    try std.testing.expectEqual(SoulBlockKind.none, identifyBlockByName("minecraft:air"));

    try std.testing.expect(isSoulBlockByName("soul_sand"));
    try std.testing.expect(isSoulBlockByName("soul_soil"));
    try std.testing.expect(!isSoulBlockByName("stone"));
}

test "particle count: Level 0 emits zero particles" {
    try std.testing.expectEqual(@as(u32, 0), getParticleCountPerStep(0, .soul_sand));
    try std.testing.expectEqual(@as(u32, 0), getParticleCountPerStep(0, .soul_soil));
    try std.testing.expectEqual(@as(u32, 0), getParticleCountPerStep(0, .none));
}

test "particle count: Level 1 emits 2 particles per step" {
    try std.testing.expectEqual(@as(u32, 2), getParticleCountPerStep(1, .soul_sand));
    try std.testing.expectEqual(@as(u32, 2), getParticleCountPerStep(1, .soul_soil));
}

test "particle count: Level 2 emits 4 particles per step" {
    try std.testing.expectEqual(@as(u32, 4), getParticleCountPerStep(2, .soul_sand));
    try std.testing.expectEqual(@as(u32, 4), getParticleCountPerStep(2, .soul_soil));
}

test "particle count: Level 3 emits 6 particles per step" {
    try std.testing.expectEqual(@as(u32, 6), getParticleCountPerStep(3, .soul_sand));
    try std.testing.expectEqual(@as(u32, 6), getParticleCountPerStep(3, .soul_soil));
}

test "particle count: non-soul block emits zero particles regardless of level" {
    try std.testing.expectEqual(@as(u32, 0), getParticleCountPerStep(1, .none));
    try std.testing.expectEqual(@as(u32, 0), getParticleCountPerStep(2, .none));
    try std.testing.expectEqual(@as(u32, 0), getParticleCountPerStep(3, .none));
}

test "particle emission: generates cyan particles with valid velocity and lifetime" {
    var buffer: [8]SoulParticle = undefined;
    const foot_pos = [3]f32{ 10.0, 64.0, -15.0 };
    const emitted = emitSoulParticles(3, .soul_sand, foot_pos, &buffer, null);
    try std.testing.expectEqual(@as(usize, 6), emitted);

    for (0..emitted) |i| {
        const p = buffer[i];
        try std.testing.expectApproxEqAbs(@as(f32, 0.20), p.color.r, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.85), p.color.g, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 0.90), p.color.b, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), p.color.a, 0.001);
        try std.testing.expect(p.vy > 0.0); // Rises upwards
        try std.testing.expectEqual(@as(u16, 20), p.lifetime_ticks);
    }
}

test "durability wear probability: Level 0 Soul Speed has 0% wear probability" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getWearProbabilityForStep(0, 0, .soul_sand), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getWearProbabilityForStep(0, 3, .soul_soil), 0.0001);
}

test "durability wear probability: base wear is 4% (0.04) without Unbreaking" {
    const prob = calculateDurabilityWearProbability(0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.04), prob, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.04), getWearProbabilityForStep(1, 0, .soul_sand), 0.0001);
}

test "durability wear probability: Unbreaking I reduces wear to 2% (0.02)" {
    const prob = calculateDurabilityWearProbability(1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.02), prob, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.02), getWearProbabilityForStep(1, 1, .soul_soil), 0.0001);
}

test "durability wear probability: Unbreaking II reduces wear to ~1.333% (0.04 / 3)" {
    const prob = calculateDurabilityWearProbability(2);
    try std.testing.expectApproxEqAbs(@as(f32, 0.04 / 3.0), prob, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.04 / 3.0), getWearProbabilityForStep(2, 2, .soul_sand), 0.0001);
}

test "durability wear probability: Unbreaking III reduces wear to 1% (0.01)" {
    const prob = calculateDurabilityWearProbability(3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.01), prob, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.01), getWearProbabilityForStep(3, 3, .soul_sand), 0.0001);
}

test "durability wear roll evaluation: roll below threshold causes wear, above does not" {
    // With Unbreaking 0, wear prob = 0.04
    try std.testing.expect(shouldWearBootDurability(0.02, 1, 0, .soul_sand));
    try std.testing.expect(shouldWearBootDurability(0.0399, 1, 0, .soul_sand));
    try std.testing.expect(!shouldWearBootDurability(0.0401, 1, 0, .soul_sand));
    try std.testing.expect(!shouldWearBootDurability(0.50, 1, 0, .soul_sand));
}

test "durability wear: stepping on non-soul block never causes wear" {
    try std.testing.expect(!shouldWearBootDurability(0.001, 3, 0, .none));
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), getWearProbabilityForStep(3, 0, .none), 0.0001);
}

test "durability wear: application deducts 1 point and marks boots broken at zero" {
    // Normal damage tick (roll 0.01 < 0.04)
    const outcome1 = applyBootDurabilityWear(100, 0.01, 1, 0, .soul_sand);
    try std.testing.expect(outcome1.damaged);
    try std.testing.expectEqual(@as(u16, 1), outcome1.durability_deducted);
    try std.testing.expectEqual(@as(u16, 99), outcome1.remaining_durability);
    try std.testing.expect(!outcome1.broken);

    // No damage tick (roll 0.10 >= 0.04)
    const outcome2 = applyBootDurabilityWear(99, 0.10, 1, 0, .soul_sand);
    try std.testing.expect(!outcome2.damaged);
    try std.testing.expectEqual(@as(u16, 0), outcome2.durability_deducted);
    try std.testing.expectEqual(@as(u16, 99), outcome2.remaining_durability);
    try std.testing.expect(!outcome2.broken);

    // Boot break tick when durability is 1
    const outcome3 = applyBootDurabilityWear(1, 0.01, 1, 0, .soul_sand);
    try std.testing.expect(outcome3.damaged);
    try std.testing.expectEqual(@as(u16, 1), outcome3.durability_deducted);
    try std.testing.expectEqual(@as(u16, 0), outcome3.remaining_durability);
    try std.testing.expect(outcome3.broken);
}

test "kinematics controller: step tracking and particle accumulation on soul blocks" {
    var controller = SoulSpeedKinematics.init(2, 0, 429);
    try std.testing.expect(controller.hasActiveSoulSpeed());
    try std.testing.expectEqual(@as(u3, 2), controller.getActiveLevel());

    // Step with roll that doesn't damage boots (0.50 >= 0.04)
    const step1 = controller.onStep(.soul_sand, 0.50);
    try std.testing.expectEqual(@as(u64, 1), step1.step_number);
    try std.testing.expectApproxEqAbs(@as(f32, 1.510), step1.speed_multiplier, 0.0001);
    try std.testing.expect(step1.drag_negated);
    try std.testing.expectEqual(@as(u32, 4), step1.particles_emitted);
    try std.testing.expect(!step1.boot_damaged);
    try std.testing.expectEqual(@as(u16, 429), step1.remaining_durability);

    // Step with roll that damages boots (0.01 < 0.04)
    const step2 = controller.onStep(.soul_sand, 0.01);
    try std.testing.expectEqual(@as(u64, 2), step2.step_number);
    try std.testing.expect(step2.boot_damaged);
    try std.testing.expectEqual(@as(u16, 428), step2.remaining_durability);
    try std.testing.expectEqual(@as(u64, 8), controller.total_particles_emitted);
    try std.testing.expectEqual(@as(u64, 1), controller.total_wear_damage);
}

test "kinematics controller: breaking boots deactivates soul speed boost and particles" {
    var controller = SoulSpeedKinematics.init(3, 0, 1);
    try std.testing.expect(controller.hasActiveSoulSpeed());

    // Taking damage breaks boots
    const step1 = controller.onStep(.soul_sand, 0.01);
    try std.testing.expect(step1.boot_damaged);
    try std.testing.expect(step1.boots_broken);
    try std.testing.expectEqual(@as(u16, 0), controller.boot_durability);
    try std.testing.expect(!controller.hasActiveSoulSpeed());

    // Subsequent steps on soul sand suffer drag (-60% speed = 0.40x) and emit 0 particles
    const step2 = controller.onStep(.soul_sand, 0.50);
    try std.testing.expectApproxEqAbs(@as(f32, 0.40), step2.speed_multiplier, 0.0001);
    try std.testing.expect(!step2.drag_negated);
    try std.testing.expectEqual(@as(u32, 0), step2.particles_emitted);
}

test "kinematics controller: movement distance accumulation triggers step events" {
    var controller = SoulSpeedKinematics.init(1, 0, 100);
    controller.step_distance_threshold = 1.0;

    // Move 0.6 blocks - no step yet
    const event1 = controller.updateMovement(0.6, 0.0, .soul_sand, 0.50);
    try std.testing.expect(event1 == null);

    // Move another 0.6 blocks - accumulated = 1.2 >= 1.0, triggers step
    const event2 = controller.updateMovement(0.6, 0.0, .soul_sand, 0.50);
    try std.testing.expect(event2 != null);
    try std.testing.expectEqual(@as(u64, 1), event2.?.step_number);
    try std.testing.expectApproxEqAbs(@as(f32, 1.405), event2.?.speed_multiplier, 0.0001);
    try std.testing.expectEqual(@as(u32, 2), event2.?.particles_emitted);
}

test "kinematics controller: Unbreaking III wear probability over multiple steps" {
    // Test that wear probability calculation scales correctly with unbreaking
    const unbreaking_3_prob = calculateDurabilityWearProbability(3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.01), unbreaking_3_prob, 0.00001);

    var controller = SoulSpeedKinematics.init(3, 3, 100);
    // Roll of 0.015 is above 0.01, so no damage
    const s1 = controller.onStep(.soul_sand, 0.015);
    try std.testing.expect(!s1.boot_damaged);
    try std.testing.expectEqual(@as(u16, 100), controller.boot_durability);

    // Roll of 0.005 is below 0.01, so damage is taken
    const s2 = controller.onStep(.soul_sand, 0.005);
    try std.testing.expect(s2.boot_damaged);
    try std.testing.expectEqual(@as(u16, 99), controller.boot_durability);
}
