const std = @import("std");

pub const ACOUSTIC_RADIUS: f32 = 256.0;
pub const ACOUSTIC_RADIUS_SQUARED: f32 = ACOUSTIC_RADIUS * ACOUSTIC_RADIUS;
pub const HORN_COOLDOWN_TICKS: u16 = 140;
pub const TICKS_PER_SECOND: f32 = 20.0;
pub const HORN_COOLDOWN_SECONDS: f32 = @as(f32, @floatFromInt(HORN_COOLDOWN_TICKS)) / TICKS_PER_SECOND;
pub const RAM_WINDUP_SECONDS: f32 = 2.0;
pub const RAM_CHARGE_SPEED: f32 = 9.0;
pub const STANDARD_RAM_COOLDOWN_SECONDS: f32 = 30.0;
pub const SCREAMER_RAM_COOLDOWN_SECONDS: f32 = 10.0;
pub const SCREAMER_SPAWN_PERCENT: u8 = 2;
pub const SCULK_VIBRATION_FREQUENCY: u4 = 10;

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

pub const standard_variants = [_]GoatHornVariant{ .ponder, .sing, .seek, .feel };
pub const screamer_variants = [_]GoatHornVariant{ .admire, .call, .yearn, .dream };

pub const Vec3 = struct { x: f32, y: f32, z: f32 };

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

fn playOnce(variant: GoatHornVariant, origin: Vec3, look_direction: Vec3) HornSoundWave {
    var state = HornPlaybackState{};
    return state.play(variant, origin, look_direction).?;
}

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

test "acoustic radius is 256 blocks" { try std.testing.expectEqual(@as(f32, 256), ACOUSTIC_RADIUS); }
test "acoustic radius squared is consistent" { try std.testing.expectEqual(@as(f32, 65536), ACOUSTIC_RADIUS_SQUARED); }
test "listener at horn origin hears at full volume" {
    const wave = playOnce(.ponder, .{ .x = 4, .y = 8, .z = 2 }, .{ .x = 0, .y = 0, .z = -1 });
    try std.testing.expect(wave.isAudibleAt(wave.origin));
    try std.testing.expectEqual(@as(f32, 1), wave.attenuationAt(wave.origin));
}
test "listener within radius hears horn" {
    const wave = playOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    try std.testing.expect(wave.isAudibleAt(.{ .x = 128, .y = 0, .z = 0 }));
}
test "listener on 256 meter boundary hears horn" {
    const wave = playOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    try std.testing.expect(wave.isAudibleAt(.{ .x = 256, .y = 0, .z = 0 }));
    try std.testing.expectEqual(@as(f32, 0), wave.attenuationAt(.{ .x = 256, .y = 0, .z = 0 }));
}
test "listener beyond radius cannot hear horn" {
    const wave = playOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    try std.testing.expect(!wave.isAudibleAt(.{ .x = 256.01, .y = 0, .z = 0 }));
}
test "distance check includes vertical separation" {
    const wave = playOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 1, .y = 0, .z = 0 });
    try std.testing.expect(!wave.isAudibleAt(.{ .x = 0, .y = 257, .z = 0 }));
}
test "attenuation decreases linearly with distance" {
    const wave = playOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 1 });
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
    const wave = playOnce(.call, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = -1 });
    try std.testing.expectEqual(@as(u4, 10), wave.sculk_frequency);
}
test "playback marks directional sonic cone particle emission" {
    const wave = playOnce(.dream, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 3, .y = 0, .z = 4 });
    try std.testing.expect(wave.emits_sonic_cone_particles);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), wave.look_direction.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), wave.look_direction.z, 0.0001);
}
test "sonic cone expands in look direction" {
    const wave = playOnce(.dream, .{ .x = 1, .y = 2, .z = 3 }, .{ .x = 0, .y = 0, .z = 2 });
    const particles = wave.sonicConeAt(0.5, 20);
    try std.testing.expectEqual(@as(f32, 128), particles.radius);
    try std.testing.expectEqual(@as(u16, 20), particles.particle_count);
    try std.testing.expectEqual(@as(f32, 1), particles.direction.z);
}
test "sonic cone expansion is clamped to maximum reach" {
    const wave = playOnce(.dream, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 1 });
    try std.testing.expectEqual(@as(f32, 0), wave.sonicConeAt(-1, 8).radius);
    try std.testing.expectEqual(ACOUSTIC_RADIUS, wave.sonicConeAt(2, 8).radius);
}
test "zero look direction falls back to forward" {
    const wave = playOnce(.ponder, .{ .x = 0, .y = 0, .z = 0 }, .{ .x = 0, .y = 0, .z = 0 });
    try std.testing.expectEqual(@as(f32, -1), wave.look_direction.z);
}
test "standard goat has two horns" { try std.testing.expectEqual(@as(u2, 2), (Goat{}).horns_remaining); }
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
