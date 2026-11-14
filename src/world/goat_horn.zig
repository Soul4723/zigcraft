const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Seconds the goat horn is on cooldown after being blown.
pub const horn_cooldown_duration: f32 = 7.0;
/// Radius in blocks within which the horn can be heard (legacy local radius).
pub const horn_audible_radius: f32 = 64.0;
/// Squared audible radius, for cheap distance comparisons.
pub const horn_audible_radius_sq: f32 = 4096.0;
/// Damage dealt to a target hit by a goat ram.
pub const ram_impact_damage: u8 = 8;
/// Upward knockback velocity applied by a goat ram.
pub const ram_knockback_vy: f32 = 7.0;

/// Full acoustic propagation radius of Goat and Copper horns in blocks (256m).
pub const ACOUSTIC_RADIUS: f32 = 256.0;
pub const ACOUSTIC_RADIUS_SQUARED: f32 = ACOUSTIC_RADIUS * ACOUSTIC_RADIUS;
/// Horn cooldown in 20 Hz game ticks (140 ticks = 7.0 seconds).
pub const HORN_COOLDOWN_TICKS: u16 = 140;
pub const TICKS_PER_SECOND: f32 = 20.0;
pub const HORN_COOLDOWN_SECONDS: f32 = @as(f32, @floatFromInt(HORN_COOLDOWN_TICKS)) / TICKS_PER_SECOND;
/// Goat ram windup, charge speed, and ram cooldown durations.
pub const RAM_WINDUP_SECONDS: f32 = 2.0;
pub const RAM_CHARGE_SPEED: f32 = 9.0;
pub const STANDARD_RAM_COOLDOWN_SECONDS: f32 = 30.0;
pub const SCREAMER_RAM_COOLDOWN_SECONDS: f32 = 10.0;
pub const SCREAMER_SPAWN_PERCENT: u8 = 2;
/// Sculk sensor vibration frequency emitted when blowing a Goat or Copper Horn.
pub const SCULK_VIBRATION_FREQUENCY: u4 = 10;
pub const SCULK_SENSOR_FREQUENCY: u4 = SCULK_VIBRATION_FREQUENCY;

/// Camera pitch thresholds (in Minecraft pitch degrees: negative = looking up, positive = looking down).
pub const HIGH_REGISTER_MAX_PITCH_DEGREES: f32 = -30.0;
pub const LOW_REGISTER_MIN_PITCH_DEGREES: f32 = 30.0;

// ============================================================================
// Horn Variants, Registers & Core Types
// ============================================================================

/// The 8 canonical Goat Horn / Copper Horn variants (4 standard + 4 screamer-exclusive).
pub const GoatHornVariant = enum {
    ponder,
    sing,
    seek,
    feel,
    admire,
    call,
    yearn,
    dream,

    pub fn isScreamerExclusive(self: GoatHornVariant) bool {
        return switch (self) {
            .admire, .call, .yearn, .dream => true,
            .ponder, .sing, .seek, .feel => false,
        };
    }

    /// Semitone offset from the base pitch. Every canonical call is distinct.
    pub fn pitchIntervalSemitones(self: GoatHornVariant) i8 {
        return switch (self) {
            .ponder => 0,
            .sing => 2,
            .seek => 4,
            .feel => 5,
            .admire => 7,
            .call => 9,
            .yearn => 11,
            .dream => 12,
        };
    }

    /// Resource identifiers are stable and correspond to the canonical horn call.
    pub fn audioCallId(self: GoatHornVariant) []const u8 {
        return switch (self) {
            .ponder => "minecraft:item.goat_horn.sound.0",
            .sing => "minecraft:item.goat_horn.sound.1",
            .seek => "minecraft:item.goat_horn.sound.2",
            .feel => "minecraft:item.goat_horn.sound.3",
            .admire => "minecraft:item.goat_horn.sound.4",
            .call => "minecraft:item.goat_horn.sound.5",
            .yearn => "minecraft:item.goat_horn.sound.6",
            .dream => "minecraft:item.goat_horn.sound.7",
        };
    }
};

/// Theme alias shared by Copper Horns crafted from Goat Horns.
pub const GoatHornTheme = GoatHornVariant;

pub const standard_variants = [_]GoatHornVariant{ .ponder, .sing, .seek, .feel };
pub const screamer_variants = [_]GoatHornVariant{ .admire, .call, .yearn, .dream };

/// Acoustic register selected by camera pitch:
/// - high (melody): pitch <= -30° (looking up), 1.33x multiplier
/// - mid (harmony): -30° < pitch < +30°, 1.0x multiplier
/// - low (bass): pitch >= +30° (looking down), 0.75x multiplier
pub const PitchRegister = enum {
    high,
    mid,
    low,

    pub fn multiplier(self: PitchRegister) f32 {
        return switch (self) {
            .high => 1.33,
            .mid => 1.0,
            .low => 0.75,
        };
    }

    /// Musical part name corresponding to the acoustic register.
    pub fn musicalRole(self: PitchRegister) []const u8 {
        return switch (self) {
            .high => "melody",
            .mid => "harmony",
            .low => "bass",
        };
    }
};

/// Maps camera pitch angle in degrees (negative = looking up, positive = looking down)
/// to Copper/Goat Horn acoustic register.
pub fn registerForCameraPitch(theta_degrees: f32) PitchRegister {
    if (theta_degrees <= HIGH_REGISTER_MAX_PITCH_DEGREES) return .high;
    if (theta_degrees >= LOW_REGISTER_MIN_PITCH_DEGREES) return .low;
    return .mid;
}

/// Sneaking while blowing a Copper Horn engages vibrato modulation.
pub const VibratoMode = enum { steady, sneaking_vibrato };

pub const Vec3 = struct { x: f32, y: f32, z: f32 };

// ============================================================================
// Cooldown, Range & Goat Ram Kinematics
// ============================================================================

/// Whether the horn may be blown yet. It is ready once the cooldown reaches
/// zero (or below).
pub fn canBlowHorn(cooldown_timer: f32) bool {
    return cooldown_timer <= 0.0;
}

/// Advances the horn cooldown by `dt` seconds, never returning below zero.
pub fn tickHornCooldown(timer: f32, dt: f32) f32 {
    return @max(0.0, timer - dt);
}

/// Whether a point at `(px, pz)` lies within the horn's 64m local audible radius of the
/// horn at `(hx, hz)`, using squared horizontal distance.
pub fn isWithinHornAudibleRange(hx: f32, hz: f32, px: f32, pz: f32) bool {
    const dx = px - hx;
    const dz = pz - hz;
    return dx * dx + dz * dz <= horn_audible_radius_sq;
}

/// Computes the horizontal and vertical impulse applied to a target at
/// horizontal offset `(dx, dz)` from a ramming goat. The horizontal direction
/// is normalized (with a minimum length of 0.2) and scaled by 9.0.
pub fn calculateRamImpulse(dx: f32, dz: f32) struct { vx: f32, vy: f32, vz: f32 } {
    const len = @max(0.2, @sqrt(dx * dx + dz * dz));
    return .{ .vx = (dx / len) * 9.0, .vy = ram_knockback_vy, .vz = (dz / len) * 9.0 };
}

// ============================================================================
// Goat Horn Acoustic Playback & Sonic Cone Particles
// ============================================================================

pub const HornPlaybackState = struct {
    cooldown_ticks: u16 = 0,

    pub fn tick(self: *HornPlaybackState, ticks: u16) void {
        self.cooldown_ticks -|= ticks;
    }

    pub fn play(self: *HornPlaybackState, variant: GoatHornVariant, origin: Vec3, look_direction: Vec3) ?HornSoundWave {
        if (self.cooldown_ticks != 0) return null;
        self.cooldown_ticks = HORN_COOLDOWN_TICKS;
        return .{
            .variant = variant,
            .origin = origin,
            .look_direction = normalize(look_direction),
            .pitch_interval_semitones = variant.pitchIntervalSemitones(),
            .audio_call_id = variant.audioCallId(),
            .radius = ACOUSTIC_RADIUS,
            .sculk_frequency = SCULK_VIBRATION_FREQUENCY,
            .emits_sonic_cone_particles = true,
        };
    }
};

pub const HornSoundWave = struct {
    variant: GoatHornVariant,
    origin: Vec3,
    look_direction: Vec3,
    pitch_interval_semitones: i8,
    audio_call_id: []const u8,
    radius: f32,
    sculk_frequency: u4,
    emits_sonic_cone_particles: bool,

    pub fn distanceToListener(self: HornSoundWave, listener: Vec3) f32 {
        const dx = listener.x - self.origin.x;
        const dy = listener.y - self.origin.y;
        const dz = listener.z - self.origin.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    pub fn isAudibleAt(self: HornSoundWave, listener: Vec3) bool {
        return self.distanceToListener(listener) <= self.radius;
    }

    /// Linear distance rolloff: full strength at the source and silent at 256m.
    pub fn attenuationAt(self: HornSoundWave, listener: Vec3) f32 {
        return @max(0.0, 1.0 - self.distanceToListener(listener) / self.radius);
    }

    /// Returns an expanding particle shell at progress 0..1 along the look cone.
    pub fn sonicConeAt(self: HornSoundWave, progress: f32, particle_count: u16) SonicConeParticles {
        const expansion = @max(0.0, @min(1.0, progress));
        return .{
            .origin = self.origin,
            .direction = self.look_direction,
            .radius = self.radius * expansion,
            .half_angle_radians = 0.35,
            .particle_count = particle_count,
        };
    }
};

pub const SonicConeParticles = struct {
    origin: Vec3,
    direction: Vec3,
    radius: f32,
    half_angle_radians: f32,
    particle_count: u16,
};

fn normalize(direction: Vec3) Vec3 {
    const magnitude = @sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z);
    if (magnitude <= 0.00001) return .{ .x = 0, .y = 0, .z = -1 };
    return .{ .x = direction.x / magnitude, .y = direction.y / magnitude, .z = direction.z / magnitude };
}

fn playGoatHornOnce(variant: GoatHornVariant, origin: Vec3, look_direction: Vec3) HornSoundWave {
    var state = HornPlaybackState{};
    return state.play(variant, origin, look_direction).?;
}

// ============================================================================
// Goat Entity Ramming & Horn Shedding
// ============================================================================

pub const GoatHornSide = enum { left_horn, right_horn };
pub const HornDrop = struct { item: ItemType = .goat_horn, side: GoatHornSide };
pub const ItemType = enum { goat_horn };

pub const RamObstacle = enum {
    stone,
    coal_ore,
    iron_ore,
    copper_ore,
    emerald_ore,
    log,
    dirt,
    planks,
    other,

    pub fn shedsHorn(self: RamObstacle) bool {
        return switch (self) {
            .stone, .coal_ore, .iron_ore, .copper_ore, .emerald_ore, .log => true,
            .dirt, .planks, .other => false,
        };
    }
};

pub const Goat = struct {
    is_screaming: bool = false,
    horns_remaining: u2 = 2,
    ramming: bool = false,
    windup_remaining_seconds: f32 = 0,
    ram_cooldown_seconds: f32 = 0,

    pub fn beginRam(self: *Goat) bool {
        if (self.horns_remaining == 0 or self.ramming or self.ram_cooldown_seconds > 0) return false;
        self.ramming = true;
        self.windup_remaining_seconds = RAM_WINDUP_SECONDS;
        return true;
    }

    pub fn tickRam(self: *Goat, delta_seconds: f32) RamMotion {
        if (self.ram_cooldown_seconds > 0) self.ram_cooldown_seconds = @max(0, self.ram_cooldown_seconds - delta_seconds);
        if (!self.ramming) return .{ .charging = false, .speed = 0 };
        self.windup_remaining_seconds = @max(0, self.windup_remaining_seconds - delta_seconds);
        if (self.windup_remaining_seconds > 0) return .{ .charging = false, .speed = 0 };
        self.ramming = false;
        self.ram_cooldown_seconds = if (self.is_screaming) SCREAMER_RAM_COOLDOWN_SECONDS else STANDARD_RAM_COOLDOWN_SECONDS;
        return .{ .charging = true, .speed = RAM_CHARGE_SPEED };
    }

    pub fn collide(self: *Goat, obstacle: RamObstacle) ?HornDrop {
        if (!obstacle.shedsHorn() or self.horns_remaining == 0) return null;
        const side: GoatHornSide = if (self.horns_remaining == 2) .left_horn else .right_horn;
        self.horns_remaining -= 1;
        return .{ .side = side };
    }

    pub fn scream(self: Goat, origin: Vec3) ?ScreamerCall {
        if (!self.is_screaming) return null;
        return .{ .origin = origin, .radius = ACOUSTIC_RADIUS, .audio_call_id = "minecraft:entity.goat.screaming" };
    }
};

pub const RamMotion = struct { charging: bool, speed: f32 };
pub const ScreamerCall = struct { origin: Vec3, radius: f32, audio_call_id: []const u8 };

/// `roll_0_to_99` is a uniform integer in the inclusive range 0..99.
pub fn spawnsAsScreamingGoat(roll_0_to_99: u7) bool {
    return roll_0_to_99 < SCREAMER_SPAWN_PERCENT;
}

// ============================================================================
// Copper Horn Crafting & Camera-Pitch Register Playback
// ============================================================================

pub const CraftingIngredient = union(enum) {
    empty,
    goat_horn: GoatHornTheme,
    copper_ingot,
};

pub const CraftingRecipe = struct {
    theme: GoatHornTheme,

    /// A 2x2 recipe: one horn of any call and one ingot in each remaining slot.
    pub fn match(grid: [4]CraftingIngredient) ?CraftingRecipe {
        var horn: ?GoatHornTheme = null;
        var ingots: u8 = 0;
        for (grid) |ingredient| switch (ingredient) {
            .empty => return null,
            .goat_horn => |theme| {
                if (horn != null) return null;
                horn = theme;
            },
            .copper_ingot => ingots += 1,
        };
        if (ingots != 3) return null;
        return .{ .theme = horn orelse return null };
    }
};

pub const CopperHorn = struct {
    theme: GoatHornTheme,

    pub fn craft(theme: GoatHornTheme) CopperHorn {
        return .{ .theme = theme };
    }
};

pub const HornWave = struct {
    theme: GoatHornTheme,
    origin: Vec3,
    radius: f32 = ACOUSTIC_RADIUS,
    pitch_register: PitchRegister,
    pitch_multiplier: f32,
    vibrato_mode: VibratoMode,
    sculk_frequency: u4 = SCULK_SENSOR_FREQUENCY,

    pub fn distanceTo(self: HornWave, listener: Vec3) f32 {
        const dx = listener.x - self.origin.x;
        const dy = listener.y - self.origin.y;
        const dz = listener.z - self.origin.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    pub fn reaches(self: HornWave, listener: Vec3) bool {
        return self.distanceTo(listener) <= self.radius;
    }
};

pub const PlaybackState = struct {
    cooldown_ticks: u16 = 0,

    pub fn tick(self: *PlaybackState, ticks: u16) void {
        self.cooldown_ticks -|= ticks;
    }

    pub fn play(self: *PlaybackState, horn: CopperHorn, origin: Vec3, camera_pitch_degrees: f32, sneaking: bool) ?HornWave {
        if (self.cooldown_ticks > 0) return null;
        const register = registerForCameraPitch(camera_pitch_degrees);
        self.cooldown_ticks = HORN_COOLDOWN_TICKS;
        return .{
            .theme = horn.theme,
            .origin = origin,
            .pitch_register = register,
            .pitch_multiplier = register.multiplier(),
            .vibrato_mode = if (sneaking) .sneaking_vibrato else .steady,
        };
    }
};

fn playCopperHornOnce(theme: GoatHornTheme, pitch: f32, sneaking: bool) HornWave {
    var state = PlaybackState{};
    return state.play(CopperHorn.craft(theme), .{ .x = 0, .y = 0, .z = 0 }, pitch, sneaking).?;
}

// ============================================================================
// Unit Tests (goat_horn + goat_horn_acoustics + copper_horn_acoustics)
// ============================================================================

test "constants have expected values" {
    try std.testing.expectApproxEqAbs(horn_cooldown_duration, 7.0, 0.0001);
    try std.testing.expectApproxEqAbs(horn_audible_radius, 64.0, 0.0001);
    try std.testing.expectApproxEqAbs(horn_audible_radius_sq, 4096.0, 0.0001);
    try std.testing.expectEqual(@as(u8, 8), ram_impact_damage);
    try std.testing.expectApproxEqAbs(ram_knockback_vy, 7.0, 0.0001);
}

test "audible radius squared matches radius" {
    try std.testing.expectApproxEqAbs(horn_audible_radius * horn_audible_radius, horn_audible_radius_sq, 0.01);
}

test "canBlowHorn ready at or below zero cooldown" {
    try std.testing.expect(canBlowHorn(0.0));
    try std.testing.expect(canBlowHorn(-1.0));
}

test "canBlowHorn blocked while cooling down" {
    try std.testing.expect(!canBlowHorn(horn_cooldown_duration));
    try std.testing.expect(!canBlowHorn(0.01));
}

test "tickHornCooldown decays the timer" {
    try std.testing.expectApproxEqAbs(tickHornCooldown(horn_cooldown_duration, 1.0), 6.0, 0.0001);
    try std.testing.expectApproxEqAbs(tickHornCooldown(2.0, 0.5), 1.5, 0.0001);
}

test "tickHornCooldown never goes negative" {
    try std.testing.expectEqual(@as(f32, 0.0), tickHornCooldown(0.0, 5.0));
    try std.testing.expectEqual(@as(f32, 0.0), tickHornCooldown(1.0, 10.0));
}

test "tickHornCooldown completes a full cooldown" {
    var timer: f32 = horn_cooldown_duration;
    timer = tickHornCooldown(timer, horn_cooldown_duration);
    try std.testing.expectEqual(@as(f32, 0.0), timer);
    try std.testing.expect(canBlowHorn(timer));
}

test "isWithinHornAudibleRange inside and on boundary" {
    try std.testing.expect(isWithinHornAudibleRange(0.0, 0.0, 0.0, 0.0));
    try std.testing.expect(isWithinHornAudibleRange(0.0, 0.0, 64.0, 0.0));
    try std.testing.expect(isWithinHornAudibleRange(0.0, 0.0, 0.0, -64.0));
    try std.testing.expect(isWithinHornAudibleRange(10.0, 10.0, 13.0, 14.0));
}

test "isWithinHornAudibleRange outside" {
    try std.testing.expect(!isWithinHornAudibleRange(0.0, 0.0, 64.01, 0.0));
    try std.testing.expect(!isWithinHornAudibleRange(0.0, 0.0, 100.0, 100.0));
    try std.testing.expect(!isWithinHornAudibleRange(0.0, 0.0, 45.0, 46.0));
}

test "calculateRamImpulse pushes along delta" {
    const k = calculateRamImpulse(3.0, 4.0);
    try std.testing.expectApproxEqAbs(k.vx, 5.4, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, 7.2, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, ram_knockback_vy, 0.001);
}

test "calculateRamImpulse negative direction" {
    const k = calculateRamImpulse(-3.0, -4.0);
    try std.testing.expectApproxEqAbs(k.vx, -5.4, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, -7.2, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, ram_knockback_vy, 0.001);
}

test "calculateRamImpulse clamps tiny offset to minimum length" {
    const k = calculateRamImpulse(0.1, 0.0);
    try std.testing.expectApproxEqAbs(k.vx, 4.5, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, ram_knockback_vy, 0.001);
}

test "calculateRamImpulse handles zero offset without panic" {
    const k = calculateRamImpulse(0.0, 0.0);
    try std.testing.expectApproxEqAbs(k.vx, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(k.vz, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(k.vy, ram_knockback_vy, 0.001);
}

// --- Goat Horn Acoustics tests ---

test "all eight variants have unique pitch and call identifiers" {
    var pitches: [13]bool = .{false} ** 13;
    var ids: [8][]const u8 = undefined;
    for (standard_variants ++ screamer_variants, 0..) |variant, i| {
        const pitch_index: usize = @intCast(variant.pitchIntervalSemitones());
        try std.testing.expect(!pitches[pitch_index]);
        pitches[pitch_index] = true;
        ids[i] = variant.audioCallId();
    }
    for (ids, 0..) |id, i| for (ids[0..i]) |prior| try std.testing.expect(!std.mem.eql(u8, id, prior));
}

test "four standard calls are regular goat exclusive variants" {
    try std.testing.expectEqual(GoatHornVariant.ponder, standard_variants[0]);
    try std.testing.expectEqual(GoatHornVariant.sing, standard_variants[1]);
    try std.testing.expectEqual(GoatHornVariant.seek, standard_variants[2]);
    try std.testing.expectEqual(GoatHornVariant.feel, standard_variants[3]);
    for (standard_variants) |variant| try std.testing.expect(!variant.isScreamerExclusive());
}

test "four screamer calls are exclusive variants" {
    try std.testing.expectEqual(GoatHornVariant.admire, screamer_variants[0]);
    try std.testing.expectEqual(GoatHornVariant.call, screamer_variants[1]);
    try std.testing.expectEqual(GoatHornVariant.yearn, screamer_variants[2]);
    try std.testing.expectEqual(GoatHornVariant.dream, screamer_variants[3]);
    for (screamer_variants) |variant| try std.testing.expect(variant.isScreamerExclusive());
}

test "each standard call has its canonical sound resource" {
    try std.testing.expectEqualStrings("minecraft:item.goat_horn.sound.0", GoatHornVariant.ponder.audioCallId());
    try std.testing.expectEqualStrings("minecraft:item.goat_horn.sound.1", GoatHornVariant.sing.audioCallId());
    try std.testing.expectEqualStrings("minecraft:item.goat_horn.sound.2", GoatHornVariant.seek.audioCallId());
    try std.testing.expectEqualStrings("minecraft:item.goat_horn.sound.3", GoatHornVariant.feel.audioCallId());
}

test "each screamer call has its canonical sound resource" {
    try std.testing.expectEqualStrings("minecraft:item.goat_horn.sound.4", GoatHornVariant.admire.audioCallId());
    try std.testing.expectEqualStrings("minecraft:item.goat_horn.sound.5", GoatHornVariant.call.audioCallId());
    try std.testing.expectEqualStrings("minecraft:item.goat_horn.sound.6", GoatHornVariant.yearn.audioCallId());
    try std.testing.expectEqualStrings("minecraft:item.goat_horn.sound.7", GoatHornVariant.dream.audioCallId());
}

test "variant pitch intervals are unique and ascending" {
    try std.testing.expectEqual(@as(i8, 0), GoatHornVariant.ponder.pitchIntervalSemitones());
    try std.testing.expectEqual(@as(i8, 2), GoatHornVariant.sing.pitchIntervalSemitones());
    try std.testing.expectEqual(@as(i8, 4), GoatHornVariant.seek.pitchIntervalSemitones());
    try std.testing.expectEqual(@as(i8, 5), GoatHornVariant.feel.pitchIntervalSemitones());
    try std.testing.expectEqual(@as(i8, 7), GoatHornVariant.admire.pitchIntervalSemitones());
    try std.testing.expectEqual(@as(i8, 9), GoatHornVariant.call.pitchIntervalSemitones());
    try std.testing.expectEqual(@as(i8, 11), GoatHornVariant.yearn.pitchIntervalSemitones());
    try std.testing.expectEqual(@as(i8, 12), GoatHornVariant.dream.pitchIntervalSemitones());
}

test "acoustic radius is 256 blocks" {
    try std.testing.expectEqual(@as(f32, 256), ACOUSTIC_RADIUS);
}
test "acoustic radius squared is consistent" {
    try std.testing.expectEqual(@as(f32, 65536), ACOUSTIC_RADIUS_SQUARED);
}
test "listener at horn origin hears at full volume" {
    const wave = playGoatHornOnce(.ponder, .{ .x = 4, .y = 8, .z = 2 }, .{ .x = 0, .y = 0, .z = -1 });
    try std.testing.expect(wave.isAudibleAt(wave.origin));
    try std.testing.expectEqual(@as(f32, 1), wave.attenuationAt(wave.origin));
}
test "listener within radius hears horn" {
    const wave = playGoatHornOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    try std.testing.expect(wave.isAudibleAt(.{ .x = 128, .y = 0, .z = 0 }));
}
test "listener on 256 meter boundary hears horn" {
    const wave = playGoatHornOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    try std.testing.expect(wave.isAudibleAt(.{ .x = 256, .y = 0, .z = 0 }));
    try std.testing.expectEqual(@as(f32, 0), wave.attenuationAt(.{ .x = 256, .y = 0, .z = 0 }));
}
test "listener beyond radius cannot hear horn" {
    const wave = playGoatHornOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    try std.testing.expect(!wave.isAudibleAt(.{ .x = 256.01, .y = 0, .z = 0 }));
}
test "distance check includes vertical separation" {
    const wave = playGoatHornOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    try std.testing.expect(!wave.isAudibleAt(.{ .x = 0, .y = 257, .z = 0 }));
}
test "attenuation decreases linearly with distance" {
    const wave = playGoatHornOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 1 });
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), wave.attenuationAt(.{ .x = 128, .y = 0, .z = 0 }), 0.0001);
}
test "playback sets a 140 tick cooldown" {
    var state = HornPlaybackState{};
    try std.testing.expect(state.play(.sing, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 1 }) != null);
    try std.testing.expectEqual(@as(u16, 140), state.cooldown_ticks);
}
test "cooldown blocks repeated horn sound" {
    var state = HornPlaybackState{};
    _ = state.play(.sing, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    try std.testing.expect(state.play(.seek, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 }) == null);
}
test "cooldown unlocks exactly after 140 ticks" {
    var state = HornPlaybackState{};
    _ = state.play(.sing, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    state.tick(139);
    try std.testing.expect(state.play(.seek, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 }) == null);
    state.tick(1);
    try std.testing.expect(state.play(.seek, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 }) != null);
}
test "cooldown tick saturates at zero" {
    var state = HornPlaybackState{ .cooldown_ticks = 5 };
    state.tick(20);
    try std.testing.expectEqual(@as(u16, 0), state.cooldown_ticks);
}
test "playback emits frequency ten sensor event" {
    const wave = playGoatHornOnce(.call, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = -1 });
    try std.testing.expectEqual(@as(u4, 10), wave.sculk_frequency);
}
test "playback marks directional sonic cone particle emission" {
    const wave = playGoatHornOnce(.dream, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 3, .y = 0, .z = 4 });
    try std.testing.expect(wave.emits_sonic_cone_particles);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), wave.look_direction.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), wave.look_direction.z, 0.0001);
}
test "sonic cone expands in look direction" {
    const wave = playGoatHornOnce(.dream, .{ .x = 1, .y = 2, .z = 3 }, .{ .x = 0, .y = 0, .z = 2 });
    const particles = wave.sonicConeAt(0.5, 20);
    try std.testing.expectEqual(@as(f32, 128), particles.radius);
    try std.testing.expectEqual(@as(u16, 20), particles.particle_count);
    try std.testing.expectEqual(@as(f32, 1), particles.direction.z);
}
test "sonic cone expansion is clamped to maximum reach" {
    const wave = playGoatHornOnce(.dream, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 1 });
    try std.testing.expectEqual(@as(f32, 0), wave.sonicConeAt(-1, 8).radius);
    try std.testing.expectEqual(ACOUSTIC_RADIUS, wave.sonicConeAt(2, 8).radius);
}
test "zero look direction falls back to forward" {
    const wave = playGoatHornOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 0 });
    try std.testing.expectEqual(@as(f32, -1), wave.look_direction.z);
}
test "standard goat has two horns" {
    try std.testing.expectEqual(@as(u2, 2), (Goat{}).horns_remaining);
}
test "first hard ram collision drops left horn item" {
    var goat = Goat{};
    const drop = goat.collide(.stone).?;
    try std.testing.expectEqual(ItemType.goat_horn, drop.item);
    try std.testing.expectEqual(GoatHornSide.left_horn, drop.side);
    try std.testing.expectEqual(@as(u2, 1), goat.horns_remaining);
}
test "second hard ram collision drops right horn item" {
    var goat = Goat{};
    _ = goat.collide(.stone);
    const drop = goat.collide(.coal_ore).?;
    try std.testing.expectEqual(GoatHornSide.right_horn, drop.side);
    try std.testing.expectEqual(@as(u2, 0), goat.horns_remaining);
}
test "hornless goat cannot shed another item" {
    var goat = Goat{ .horns_remaining = 0 };
    try std.testing.expect(goat.collide(.stone) == null);
    try std.testing.expectEqual(@as(u2, 0), goat.horns_remaining);
}
test "soft obstacle does not shed a horn" {
    var goat = Goat{};
    try std.testing.expect(goat.collide(.dirt) == null);
    try std.testing.expectEqual(@as(u2, 2), goat.horns_remaining);
}
test "all specified solid obstacles shed horns" {
    for ([_]RamObstacle{ .stone, .coal_ore, .iron_ore, .copper_ore, .emerald_ore, .log }) |obstacle| {
        try std.testing.expect(obstacle.shedsHorn());
    }
}
test "unspecified obstacles do not shed horns" {
    for ([_]RamObstacle{ .dirt, .planks, .other }) |obstacle| try std.testing.expect(!obstacle.shedsHorn());
}
test "screaming goat spawn chance is two percent" {
    try std.testing.expect(spawnsAsScreamingGoat(0));
    try std.testing.expect(spawnsAsScreamingGoat(1));
    try std.testing.expect(!spawnsAsScreamingGoat(2));
    try std.testing.expect(!spawnsAsScreamingGoat(99));
}
test "goat begins two second ram windup" {
    var goat = Goat{};
    try std.testing.expect(goat.beginRam());
    try std.testing.expectEqual(RAM_WINDUP_SECONDS, goat.windup_remaining_seconds);
}
test "ram windup delays charge until two seconds" {
    var goat = Goat{};
    _ = goat.beginRam();
    try std.testing.expect(!goat.tickRam(1.99).charging);
    const motion = goat.tickRam(0.01);
    try std.testing.expect(motion.charging);
    try std.testing.expectEqual(RAM_CHARGE_SPEED, motion.speed);
}
test "ram is unavailable during windup" {
    var goat = Goat{};
    try std.testing.expect(goat.beginRam());
    try std.testing.expect(!goat.beginRam());
}
test "standard goat ram cadence uses thirty second cooldown" {
    var goat = Goat{};
    _ = goat.beginRam();
    _ = goat.tickRam(2);
    try std.testing.expectEqual(STANDARD_RAM_COOLDOWN_SECONDS, goat.ram_cooldown_seconds);
    try std.testing.expect(!goat.beginRam());
}
test "screamer ram cadence uses ten second cooldown" {
    var goat = Goat{ .is_screaming = true };
    _ = goat.beginRam();
    _ = goat.tickRam(2);
    try std.testing.expectEqual(SCREAMER_RAM_COOLDOWN_SECONDS, goat.ram_cooldown_seconds);
    try std.testing.expect(!goat.beginRam());
}
test "screaming goat emits an audible scream call" {
    const call = (Goat{ .is_screaming = true }).scream(.{ .x = 1, .y = 2, .z = 3 }).?;
    try std.testing.expectEqual(ACOUSTIC_RADIUS, call.radius);
    try std.testing.expectEqualStrings("minecraft:entity.goat.screaming", call.audio_call_id);
}
test "regular goat does not emit screamer call" {
    try std.testing.expect((Goat{}).scream(.{ .x = 0, .y = 0, .z = 0 }) == null);
}
test "ram cooldown expires and goat can wind up again" {
    var goat = Goat{ .is_screaming = true };
    _ = goat.beginRam();
    _ = goat.tickRam(2);
    _ = goat.tickRam(10);
    try std.testing.expect(goat.beginRam());
}
test "hornless goat cannot begin a ram" {
    var goat = Goat{ .horns_remaining = 0 };
    try std.testing.expect(!goat.beginRam());
}

// --- Copper Horn Acoustics tests ---

test "copper horn crafting accepts one Ponder horn and three ingots" {
    const recipe = CraftingRecipe.match(.{ .{ .goat_horn = .ponder }, .copper_ingot, .copper_ingot, .copper_ingot }).?;
    try std.testing.expectEqual(GoatHornTheme.ponder, recipe.theme);
}
test "crafting retains Sing theme" {
    try std.testing.expectEqual(GoatHornTheme.sing, CraftingRecipe.match(.{ .copper_ingot, .{ .goat_horn = .sing }, .copper_ingot, .copper_ingot }).?.theme);
}
test "crafting retains Seek theme" {
    try std.testing.expectEqual(GoatHornTheme.seek, CraftingRecipe.match(.{ .copper_ingot, .copper_ingot, .{ .goat_horn = .seek }, .copper_ingot }).?.theme);
}
test "crafting retains Feel theme" {
    try std.testing.expectEqual(GoatHornTheme.feel, CraftingRecipe.match(.{ .copper_ingot, .copper_ingot, .copper_ingot, .{ .goat_horn = .feel } }).?.theme);
}
test "crafting retains Admire theme" {
    try std.testing.expectEqual(GoatHornTheme.admire, CraftingRecipe.match(.{ .{ .goat_horn = .admire }, .copper_ingot, .copper_ingot, .copper_ingot }).?.theme);
}
test "crafting retains Call theme" {
    try std.testing.expectEqual(GoatHornTheme.call, CraftingRecipe.match(.{ .{ .goat_horn = .call }, .copper_ingot, .copper_ingot, .copper_ingot }).?.theme);
}
test "crafting retains Yearn theme" {
    try std.testing.expectEqual(GoatHornTheme.yearn, CraftingRecipe.match(.{ .{ .goat_horn = .yearn }, .copper_ingot, .copper_ingot, .copper_ingot }).?.theme);
}
test "crafting retains Dream theme" {
    try std.testing.expectEqual(GoatHornTheme.dream, CraftingRecipe.match(.{ .{ .goat_horn = .dream }, .copper_ingot, .copper_ingot, .copper_ingot }).?.theme);
}
test "crafting rejects two goat horns" {
    try std.testing.expect(CraftingRecipe.match(.{ .{ .goat_horn = .ponder }, .{ .goat_horn = .sing }, .copper_ingot, .copper_ingot }) == null);
}
test "crafting rejects two copper ingots" {
    try std.testing.expect(CraftingRecipe.match(.{ .{ .goat_horn = .ponder }, .copper_ingot, .copper_ingot, .empty }) == null);
}
test "crafting rejects four copper ingots" {
    try std.testing.expect(CraftingRecipe.match(.{ .copper_ingot, .copper_ingot, .copper_ingot, .copper_ingot }) == null);
}
test "crafting rejects an empty grid" {
    try std.testing.expect(CraftingRecipe.match(.{ .empty, .empty, .empty, .empty }) == null);
}
test "crafting rejects a horn with an empty slot" {
    try std.testing.expect(CraftingRecipe.match(.{ .{ .goat_horn = .dream }, .copper_ingot, .empty, .copper_ingot }) == null);
}
test "crafted horn stores the source theme" {
    try std.testing.expectEqual(GoatHornTheme.yearn, CopperHorn.craft(.yearn).theme);
}
test "camera pitch at minus 30 degrees selects high register" {
    try std.testing.expectEqual(PitchRegister.high, registerForCameraPitch(-30));
}
test "camera pitch above minus 30 selects mid register" {
    try std.testing.expectEqual(PitchRegister.mid, registerForCameraPitch(-29.99));
}
test "camera pitch at zero selects mid register" {
    try std.testing.expectEqual(PitchRegister.mid, registerForCameraPitch(0));
}
test "camera pitch below plus 30 selects mid register" {
    try std.testing.expectEqual(PitchRegister.mid, registerForCameraPitch(29.99));
}
test "camera pitch at plus 30 degrees selects low register" {
    try std.testing.expectEqual(PitchRegister.low, registerForCameraPitch(30));
}
test "camera pitch looking far up selects high register" {
    try std.testing.expectEqual(PitchRegister.high, registerForCameraPitch(-90));
}
test "camera pitch looking far down selects low register" {
    try std.testing.expectEqual(PitchRegister.low, registerForCameraPitch(90));
}
test "high register pitch multiplier is soprano 1.33" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.33), PitchRegister.high.multiplier(), 0.0001);
}
test "mid register pitch multiplier is standard 1.0" {
    try std.testing.expectEqual(@as(f32, 1.0), PitchRegister.mid.multiplier());
}
test "low register pitch multiplier is bass 0.75" {
    try std.testing.expectEqual(@as(f32, 0.75), PitchRegister.low.multiplier());
}
test "sneaking enables alternate vibrato mode" {
    try std.testing.expectEqual(VibratoMode.sneaking_vibrato, playCopperHornOnce(.ponder, 0, true).vibrato_mode);
}
test "standing keeps steady timbre" {
    try std.testing.expectEqual(VibratoMode.steady, playCopperHornOnce(.ponder, 0, false).vibrato_mode);
}
test "sneaking does not change pitch register" {
    try std.testing.expectEqual(PitchRegister.high, playCopperHornOnce(.ponder, -45, true).pitch_register);
}
test "sound reaches listener at the 256 meter boundary" {
    try std.testing.expect(playCopperHornOnce(.call, 0, false).reaches(.{ .x = 256, .y = 0, .z = 0 }));
}
test "sound does not reach listener beyond 256 meters" {
    try std.testing.expect(!playCopperHornOnce(.call, 0, false).reaches(.{ .x = 256.01, .y = 0, .z = 0 }));
}
test "sound radius is exactly 256 meters" {
    try std.testing.expectEqual(@as(f32, 256), ACOUSTIC_RADIUS);
}
test "sound propagation includes vertical distance" {
    try std.testing.expect(!playCopperHornOnce(.call, 0, false).reaches(.{ .x = 0, .y = 257, .z = 0 }));
}
test "playback applies 140 tick cooldown" {
    var state = PlaybackState{};
    _ = state.play(CopperHorn.craft(.feel), .{ .x = 0, .y = 0, .z = 0 }, 0, false);
    try std.testing.expectEqual(@as(u16, 140), state.cooldown_ticks);
}
test "cooldown blocks immediate retrigger" {
    var state = PlaybackState{};
    _ = state.play(CopperHorn.craft(.feel), .{ .x = 0, .y = 0, .z = 0 }, 0, false);
    try std.testing.expect(state.play(CopperHorn.craft(.feel), .{ .x = 0, .y = 0, .z = 0 }, 0, false) == null);
}
test "cooldown remains after 139 ticks" {
    var state = PlaybackState{ .cooldown_ticks = 140 };
    state.tick(139);
    try std.testing.expectEqual(@as(u16, 1), state.cooldown_ticks);
}
test "cooldown expires after 140 ticks" {
    var state = PlaybackState{ .cooldown_ticks = 140 };
    state.tick(140);
    try std.testing.expectEqual(@as(u16, 0), state.cooldown_ticks);
}
test "copper horn cooldown tick saturates at zero" {
    var state = PlaybackState{ .cooldown_ticks = 10 };
    state.tick(20);
    try std.testing.expectEqual(@as(u16, 0), state.cooldown_ticks);
}
test "playback emits frequency ten for sculk sensor activation" {
    try std.testing.expectEqual(@as(u4, 10), playCopperHornOnce(.admire, 0, false).sculk_frequency);
}
test "playback carries original melodic theme into wave" {
    try std.testing.expectEqual(GoatHornTheme.dream, playCopperHornOnce(.dream, 0, false).theme);
}
