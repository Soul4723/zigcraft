const std = @import("std");

/// Allay duplication cooldown in seconds (5 minutes / 300.0s in Minecraft).
pub const allay_duplication_cooldown_duration: f32 = 300.0;

/// Radius in blocks within which an Allay dances to a playing Jukebox (10.0 blocks).
pub const allay_dance_radius: f32 = 10.0;

/// Squared distance radius in blocks for cheap distance checks (10.0^2 = 100.0).
pub const allay_dance_radius_sq: f32 = 100.0;

/// Number of Disc Fragment 5 items needed to assemble one Music Disc 5.
pub const fragments_per_disc_5: u8 = 9;

/// Synth melody tempo and root-note acoustic parameters for audio rendering.
pub const SynthParameters = struct {
    tempo_bpm: f32,
    root_note_hz: f32,
    root_note_name: []const u8,
    beat_step_seconds: f32,
};

/// The 15 canonical Music Discs (1..15) plus modern Trial Chamber & Archaeology discs.
pub const MusicDisc = enum(u8) {
    disc_13 = 1,
    cat = 2,
    blocks = 3,
    chirp = 4,
    far = 5,
    mall = 6,
    mellohi = 7,
    stal = 8,
    strad = 9,
    ward = 10,
    disc_11 = 11,
    wait = 12,
    pigstep = 13,
    otherside = 14,
    disc_5 = 15,
    // Modern Trial Chambers & Archaeology Discs
    relic = 16,
    precipice = 17,
    creator = 18,
    creator_music_box = 19,

    /// Human-readable title of the music disc.
    pub fn title(self: MusicDisc) []const u8 {
        return switch (self) {
            .disc_13 => "13",
            .cat => "cat",
            .blocks => "blocks",
            .chirp => "chirp",
            .far => "far",
            .mall => "mall",
            .mellohi => "mellohi",
            .stal => "stal",
            .strad => "strad",
            .ward => "ward",
            .disc_11 => "11",
            .wait => "wait",
            .pigstep => "Pigstep",
            .otherside => "otherside",
            .disc_5 => "5",
            .relic => "Relic",
            .precipice => "Precipice",
            .creator => "Creator",
            .creator_music_box => "Creator (Music Box)",
        };
    }

    /// Primary composer or artist for this track.
    pub fn author(self: MusicDisc) []const u8 {
        return switch (self) {
            .disc_13, .cat, .blocks, .chirp, .far, .mall, .mellohi, .stal, .strad, .ward, .disc_11, .wait => "C418",
            .pigstep, .otherside, .creator, .creator_music_box => "Lena Raine",
            .disc_5 => "Samuel Åberg",
            .relic, .precipice => "Aaron Cherof",
        };
    }

    /// Official track duration in seconds.
    pub fn durationSeconds(self: MusicDisc) f32 {
        return switch (self) {
            .disc_13 => 178.0,
            .cat => 185.0,
            .blocks => 345.0,
            .chirp => 185.0,
            .far => 174.0,
            .mall => 197.0,
            .mellohi => 96.0,
            .stal => 150.0,
            .strad => 188.0,
            .ward => 251.0,
            .disc_11 => 71.0,
            .wait => 238.0,
            .pigstep => 149.0,
            .otherside => 195.0,
            .disc_5 => 178.0,
            .relic => 218.0,
            .precipice => 299.0,
            .creator => 176.0,
            .creator_music_box => 73.0,
        };
    }

    /// Redstone comparator output strength (1..15).
    /// The 15 canonical discs output 1..15 corresponding directly to their index.
    /// Modern discs map to their canonical comparator equivalents:
    /// - Relic: 14 (same as otherside)
    /// - Precipice: 13 (same as Pigstep)
    /// - Creator: 12 (same as wait)
    /// - Creator (Music Box): 11 (same as 11)
    pub fn comparatorOutput(self: MusicDisc) u4 {
        return switch (self) {
            .disc_13 => 1,
            .cat => 2,
            .blocks => 3,
            .chirp => 4,
            .far => 5,
            .mall => 6,
            .mellohi => 7,
            .stal => 8,
            .strad => 9,
            .ward => 10,
            .disc_11 => 11,
            .wait => 12,
            .pigstep => 13,
            .otherside => 14,
            .disc_5 => 15,
            .relic => 14,
            .precipice => 13,
            .creator => 12,
            .creator_music_box => 11,
        };
    }

    /// Alias for comparatorOutput.
    pub fn comparatorSignal(self: MusicDisc) u4 {
        return self.comparatorOutput();
    }

    /// Synth melody tempo and root-note acoustic parameters.
    pub fn synthParameters(self: MusicDisc) SynthParameters {
        return switch (self) {
            .disc_13 => .{ .tempo_bpm = 80.0, .root_note_hz = 220.00, .root_note_name = "A3", .beat_step_seconds = 0.75 },
            .cat => .{ .tempo_bpm = 120.0, .root_note_hz = 261.63, .root_note_name = "C4", .beat_step_seconds = 0.50 },
            .blocks => .{ .tempo_bpm = 140.0, .root_note_hz = 293.66, .root_note_name = "D4", .beat_step_seconds = 60.0 / 140.0 },
            .chirp => .{ .tempo_bpm = 105.0, .root_note_hz = 329.63, .root_note_name = "E4", .beat_step_seconds = 60.0 / 105.0 },
            .far => .{ .tempo_bpm = 72.0, .root_note_hz = 196.00, .root_note_name = "G3", .beat_step_seconds = 60.0 / 72.0 },
            .mall => .{ .tempo_bpm = 90.0, .root_note_hz = 261.63, .root_note_name = "C4", .beat_step_seconds = 60.0 / 90.0 },
            .mellohi => .{ .tempo_bpm = 85.0, .root_note_hz = 246.94, .root_note_name = "B3", .beat_step_seconds = 60.0 / 85.0 },
            .stal => .{ .tempo_bpm = 112.0, .root_note_hz = 349.23, .root_note_name = "F4", .beat_step_seconds = 60.0 / 112.0 },
            .strad => .{ .tempo_bpm = 110.0, .root_note_hz = 293.66, .root_note_name = "D4", .beat_step_seconds = 60.0 / 110.0 },
            .ward => .{ .tempo_bpm = 95.0, .root_note_hz = 174.61, .root_note_name = "F3", .beat_step_seconds = 60.0 / 95.0 },
            .disc_11 => .{ .tempo_bpm = 60.0, .root_note_hz = 130.81, .root_note_name = "C3", .beat_step_seconds = 1.00 },
            .wait => .{ .tempo_bpm = 125.0, .root_note_hz = 392.00, .root_note_name = "G4", .beat_step_seconds = 60.0 / 125.0 },
            .pigstep => .{ .tempo_bpm = 110.0, .root_note_hz = 146.83, .root_note_name = "D3", .beat_step_seconds = 60.0 / 110.0 },
            .otherside => .{ .tempo_bpm = 128.0, .root_note_hz = 261.63, .root_note_name = "C4", .beat_step_seconds = 60.0 / 128.0 },
            .disc_5 => .{ .tempo_bpm = 65.0, .root_note_hz = 110.00, .root_note_name = "A2", .beat_step_seconds = 60.0 / 65.0 },
            .relic => .{ .tempo_bpm = 100.0, .root_note_hz = 220.00, .root_note_name = "A3", .beat_step_seconds = 0.60 },
            .precipice => .{ .tempo_bpm = 135.0, .root_note_hz = 329.63, .root_note_name = "E4", .beat_step_seconds = 60.0 / 135.0 },
            .creator => .{ .tempo_bpm = 118.0, .root_note_hz = 293.66, .root_note_name = "D4", .beat_step_seconds = 60.0 / 118.0 },
            .creator_music_box => .{ .tempo_bpm = 92.0, .root_note_hz = 523.25, .root_note_name = "C5", .beat_step_seconds = 60.0 / 92.0 },
        };
    }

    /// Tempo in beats per minute.
    pub fn tempoBpm(self: MusicDisc) f32 {
        return self.synthParameters().tempo_bpm;
    }

    /// Root frequency in Hertz.
    pub fn rootNoteHz(self: MusicDisc) f32 {
        return self.synthParameters().root_note_hz;
    }

    /// True if this disc belongs to the 15 original canonical records.
    pub fn isCanonical(self: MusicDisc) bool {
        return @intFromEnum(self) <= 15;
    }

    /// True if this disc is a modern Trial Chamber or Archaeology excavation track.
    pub fn isTrialOrArchaeology(self: MusicDisc) bool {
        return @intFromEnum(self) >= 16;
    }

    /// Attempts to parse a disc from its integer tag value.
    pub fn fromId(id: u8) ?MusicDisc {
        return switch (id) {
            1...19 => @enumFromInt(id),
            else => null,
        };
    }
};

/// Complete list of all 19 supported music discs.
pub const all_discs = [_]MusicDisc{
    .disc_13, .cat,     .blocks,            .chirp,     .far,
    .mall,    .mellohi, .stal,              .strad,     .ward,
    .disc_11, .wait,    .pigstep,           .otherside, .disc_5,
    .relic,   .precipice, .creator,         .creator_music_box,
};

/// List of the 15 canonical discs mapping 1:1 to comparator signals 1..15.
pub const canonical_discs = [_]MusicDisc{
    .disc_13, .cat,     .blocks,    .chirp,     .far,
    .mall,    .mellohi, .stal,      .strad,     .ward,
    .disc_11, .wait,    .pigstep,   .otherside, .disc_5,
};

/// Result of crafting Music Disc 5 from Disc Fragment 5 pieces.
pub const CraftDisc5Result = struct {
    discs_crafted: u8,
    remaining_fragments: u8,
};

/// Assembles Music Disc 5 from Disc Fragment 5 pieces.
/// Exactly 9 fragments yield 1 complete Music Disc 5.
pub fn craftDisc5FromFragments(fragment_count: u8) struct { discs_crafted: u8, remaining_fragments: u8 } {
    return .{
        .discs_crafted = fragment_count / fragments_per_disc_5,
        .remaining_fragments = fragment_count % fragments_per_disc_5,
    };
}

/// Evaluates whether an Allay duplicates when interacting with a player holding an Amethyst Shard.
/// Requirements:
/// 1. A Jukebox within 10 blocks (distance_sq <= 100.0) is actively playing music (`jukebox_playing = true`).
/// 2. Player is offering / holding an Amethyst Shard (`holding_amethyst_shard = true`).
/// 3. Allay duplication cooldown has fully elapsed (`duplication_cooldown <= 0.0`).
pub fn canDuplicateDancingAllay(
    jukebox_playing: bool,
    distance_sq: f32,
    holding_amethyst_shard: bool,
    duplication_cooldown: f32,
) bool {
    if (!jukebox_playing) return false;
    if (distance_sq < 0.0 or distance_sq > allay_dance_radius_sq) return false;
    if (!holding_amethyst_shard) return false;
    if (duplication_cooldown > 0.0) return false;
    return true;
}

/// Advances Allay duplication cooldown timer by `dt` seconds, clamped at 0.0.
pub fn tickAllayDuplicationCooldown(cooldown: f32, dt: f32) f32 {
    if (dt <= 0.0) return cooldown;
    return @max(0.0, cooldown - dt);
}

/// Squared Euclidean distance between a Jukebox and an Allay in 3D space.
pub fn allayDistanceSq(jx: f32, jy: f32, jz: f32, ax: f32, ay: f32, az: f32) f32 {
    const dx = ax - jx;
    const dy = ay - jy;
    const dz = az - jz;
    return dx * dx + dy * dy + dz * dz;
}

/// Returns true if an Allay at (ax, ay, az) is within dancing range (10 blocks) of a Jukebox at (jx, jy, jz).
pub fn isWithinAllayDanceRange(jx: f32, jy: f32, jz: f32, ax: f32, ay: f32, az: f32) bool {
    return allayDistanceSq(jx, jy, jz, ax, ay, az) <= allay_dance_radius_sq;
}

/// Jukebox block state tracking inserted vinyl records, playback duration, and comparator signal output.
pub const JukeboxState = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    inserted_disc: ?MusicDisc = null,
    playback_elapsed: f32 = 0.0,
    is_playing: bool = false,

    pub fn init() JukeboxState {
        return .{};
    }

    pub fn initAt(x: i32, y: i32, z: i32) JukeboxState {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .inserted_disc = null,
            .playback_elapsed = 0.0,
            .is_playing = false,
        };
    }

    /// Inserts a music disc into the jukebox.
    /// Resets playback timer to 0.0 and starts playback.
    /// Returns true if successfully inserted, or false if already occupied.
    pub fn insertDisc(self: *JukeboxState, disc: MusicDisc) bool {
        if (self.inserted_disc != null) return false;
        self.inserted_disc = disc;
        self.playback_elapsed = 0.0;
        self.is_playing = true;
        return true;
    }

    /// Ejects the currently inserted disc, halting playback and clearing state.
    /// Returns the ejected disc, or null if the jukebox was empty.
    pub fn ejectDisc(self: *JukeboxState) ?MusicDisc {
        const disc = self.inserted_disc orelse return null;
        self.inserted_disc = null;
        self.playback_elapsed = 0.0;
        self.is_playing = false;
        return disc;
    }

    /// Advances record playback by `dt` seconds.
    /// When `playback_elapsed >= disc.durationSeconds()`, automatically stops playback
    /// (`is_playing = false`), while keeping the disc safely inside until ejected or
    /// extracted by a hopper!
    pub fn tickPlayback(self: *JukeboxState, dt: f32) void {
        if (!self.is_playing or dt <= 0.0) return;
        const disc = self.inserted_disc orelse {
            self.is_playing = false;
            return;
        };

        self.playback_elapsed += dt;
        if (self.playback_elapsed >= disc.durationSeconds()) {
            self.is_playing = false;
        }
    }

    /// Evaluates the redstone comparator signal emitted by this jukebox.
    /// Empty jukebox = 0.
    /// Jukebox with inserted disc = disc.comparatorOutput() (1..15).
    /// Note: Comparator signal persists even after playback completes,
    /// as long as the disc remains inside!
    pub fn comparatorSignal(self: JukeboxState) u4 {
        if (self.inserted_disc) |disc| {
            return disc.comparatorOutput();
        }
        return 0;
    }

    /// Hopper extraction support (Minecraft 1.20+):
    /// Extracts the disc currently held inside the jukebox into an adjacent hopper.
    pub fn hopperExtract(self: *JukeboxState) ?MusicDisc {
        return self.ejectDisc();
    }

    /// True if a disc is inserted in the jukebox.
    pub fn hasDisc(self: JukeboxState) bool {
        return self.inserted_disc != null;
    }

    /// True if the inserted disc has completed its playback duration.
    pub fn isFinished(self: JukeboxState) bool {
        if (self.inserted_disc) |disc| {
            return self.playback_elapsed >= disc.durationSeconds();
        }
        return false;
    }

    /// Returns remaining playback time in seconds (0.0 if not playing or empty).
    pub fn remainingPlaybackSeconds(self: JukeboxState) f32 {
        if (!self.is_playing) return 0.0;
        if (self.inserted_disc) |disc| {
            const duration = disc.durationSeconds();
            if (self.playback_elapsed >= duration) return 0.0;
            return duration - self.playback_elapsed;
        }
        return 0.0;
    }

    /// Normalized playback progress [0.0..1.0].
    pub fn playbackProgress(self: JukeboxState) f32 {
        const disc = self.inserted_disc orelse return 0.0;
        const duration = disc.durationSeconds();
        if (duration <= 0.0) return 1.0;
        return @min(1.0, @max(0.0, self.playback_elapsed / duration));
    }
};

/// Free function wrapper for JukeboxState comparator signal evaluation.
pub fn comparatorSignal(state: JukeboxState) u4 {
    return state.comparatorSignal();
}

// ============================================================================
// Unit Tests (At least 14 comprehensive tests)
// ============================================================================

test "1: MusicDisc enum 15 canonical discs have explicit integer values 1..15" {
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(MusicDisc.disc_13));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(MusicDisc.cat));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(MusicDisc.blocks));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(MusicDisc.chirp));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(MusicDisc.far));
    try std.testing.expectEqual(@as(u8, 6), @intFromEnum(MusicDisc.mall));
    try std.testing.expectEqual(@as(u8, 7), @intFromEnum(MusicDisc.mellohi));
    try std.testing.expectEqual(@as(u8, 8), @intFromEnum(MusicDisc.stal));
    try std.testing.expectEqual(@as(u8, 9), @intFromEnum(MusicDisc.strad));
    try std.testing.expectEqual(@as(u8, 10), @intFromEnum(MusicDisc.ward));
    try std.testing.expectEqual(@as(u8, 11), @intFromEnum(MusicDisc.disc_11));
    try std.testing.expectEqual(@as(u8, 12), @intFromEnum(MusicDisc.wait));
    try std.testing.expectEqual(@as(u8, 13), @intFromEnum(MusicDisc.pigstep));
    try std.testing.expectEqual(@as(u8, 14), @intFromEnum(MusicDisc.otherside));
    try std.testing.expectEqual(@as(u8, 15), @intFromEnum(MusicDisc.disc_5));
}

test "2: Trial and Archaeology discs have distinct IDs > 15" {
    try std.testing.expectEqual(@as(u8, 16), @intFromEnum(MusicDisc.relic));
    try std.testing.expectEqual(@as(u8, 17), @intFromEnum(MusicDisc.precipice));
    try std.testing.expectEqual(@as(u8, 18), @intFromEnum(MusicDisc.creator));
    try std.testing.expectEqual(@as(u8, 19), @intFromEnum(MusicDisc.creator_music_box));

    try std.testing.expect(MusicDisc.relic.isTrialOrArchaeology());
    try std.testing.expect(MusicDisc.precipice.isTrialOrArchaeology());
    try std.testing.expect(MusicDisc.creator.isTrialOrArchaeology());
    try std.testing.expect(MusicDisc.creator_music_box.isTrialOrArchaeology());

    try std.testing.expect(!MusicDisc.cat.isTrialOrArchaeology());
    try std.testing.expect(MusicDisc.cat.isCanonical());
}

test "3: Comparator output for all 15 canonical discs matches 1..15 exactly" {
    var expected_signal: u8 = 1;
    for (canonical_discs) |disc| {
        try std.testing.expectEqual(@as(u4, @intCast(expected_signal)), disc.comparatorOutput());
        try std.testing.expectEqual(@as(u4, @intCast(expected_signal)), disc.comparatorSignal());
        expected_signal += 1;
    }
}

test "4: Comparator output for Trial and Archaeology discs match Minecraft specifications" {
    // Relic = 14 (same as otherside)
    try std.testing.expectEqual(@as(u4, 14), MusicDisc.relic.comparatorOutput());
    // Precipice = 13 (same as Pigstep)
    try std.testing.expectEqual(@as(u4, 13), MusicDisc.precipice.comparatorOutput());
    // Creator = 12 (same as wait)
    try std.testing.expectEqual(@as(u4, 12), MusicDisc.creator.comparatorOutput());
    // Creator (Music Box) = 11 (same as 11)
    try std.testing.expectEqual(@as(u4, 11), MusicDisc.creator_music_box.comparatorOutput());
}

test "5: Track durations in seconds for canonical and modern discs" {
    // 11 is the shortest canonical disc (71 seconds)
    try std.testing.expectApproxEqAbs(@as(f32, 71.0), MusicDisc.disc_11.durationSeconds(), 0.001);
    // blocks is the longest canonical disc (345 seconds / 5:45)
    try std.testing.expectApproxEqAbs(@as(f32, 345.0), MusicDisc.blocks.durationSeconds(), 0.001);

    // Other specific disc durations
    try std.testing.expectApproxEqAbs(@as(f32, 178.0), MusicDisc.disc_13.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 185.0), MusicDisc.cat.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 149.0), MusicDisc.pigstep.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 195.0), MusicDisc.otherside.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 178.0), MusicDisc.disc_5.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 218.0), MusicDisc.relic.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 299.0), MusicDisc.precipice.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 176.0), MusicDisc.creator.durationSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 73.0), MusicDisc.creator_music_box.durationSeconds(), 0.001);
}

test "6: Synth melody tempo and root-note parameters for audio synthesis" {
    const cat_params = MusicDisc.cat.synthParameters();
    try std.testing.expectApproxEqAbs(@as(f32, 120.0), cat_params.tempo_bpm, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 261.63), cat_params.root_note_hz, 0.01);
    try std.testing.expectEqualStrings("C4", cat_params.root_note_name);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), cat_params.beat_step_seconds, 0.01);

    const disc_13_params = MusicDisc.disc_13.synthParameters();
    try std.testing.expectApproxEqAbs(@as(f32, 80.0), disc_13_params.tempo_bpm, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 220.00), disc_13_params.root_note_hz, 0.01);
    try std.testing.expectEqualStrings("A3", disc_13_params.root_note_name);

    const pigstep_params = MusicDisc.pigstep.synthParameters();
    try std.testing.expectApproxEqAbs(@as(f32, 110.0), pigstep_params.tempo_bpm, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 146.83), pigstep_params.root_note_hz, 0.01);
    try std.testing.expectEqualStrings("D3", pigstep_params.root_note_name);

    const relic_params = MusicDisc.relic.synthParameters();
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), relic_params.tempo_bpm, 0.01);
    try std.testing.expectEqualStrings("A3", relic_params.root_note_name);
}

test "7: JukeboxState default initialization and empty comparator signal is 0" {
    const jb = JukeboxState.init();
    try std.testing.expectEqual(@as(?MusicDisc, null), jb.inserted_disc);
    try std.testing.expectEqual(@as(f32, 0.0), jb.playback_elapsed);
    try std.testing.expect(!jb.is_playing);
    try std.testing.expect(!jb.hasDisc());
    try std.testing.expectEqual(@as(u4, 0), jb.comparatorSignal());
    try std.testing.expectEqual(@as(u4, 0), comparatorSignal(jb));
}

test "8: JukeboxState insertDisc starts playback and outputs disc comparator signal" {
    var jb = JukeboxState.initAt(10, 64, -20);
    try std.testing.expect(jb.insertDisc(.cat));
    try std.testing.expect(jb.hasDisc());
    try std.testing.expect(jb.is_playing);
    try std.testing.expectEqual(@as(?MusicDisc, .cat), jb.inserted_disc);
    try std.testing.expectEqual(@as(f32, 0.0), jb.playback_elapsed);
    // cat comparator output is 2
    try std.testing.expectEqual(@as(u4, 2), jb.comparatorSignal());
    try std.testing.expectEqual(@as(u4, 2), comparatorSignal(jb));

    // Cannot insert another disc while occupied
    try std.testing.expect(!jb.insertDisc(.pigstep));
    try std.testing.expectEqual(@as(?MusicDisc, .cat), jb.inserted_disc);
}

test "9: JukeboxState tickPlayback advances time and stops playing on completion" {
    var jb = JukeboxState.init();
    _ = jb.insertDisc(.disc_11); // 71 seconds duration
    try std.testing.expect(jb.is_playing);

    // Tick 30 seconds
    jb.tickPlayback(30.0);
    try std.testing.expect(jb.is_playing);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), jb.playback_elapsed, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 41.0), jb.remainingPlaybackSeconds(), 0.001);
    try std.testing.expect(!jb.isFinished());

    // Tick 41 seconds (total 71 seconds: exact track duration)
    jb.tickPlayback(41.0);
    try std.testing.expect(!jb.is_playing); // Automatically stopped playing!
    try std.testing.expect(jb.isFinished());
    try std.testing.expectApproxEqAbs(@as(f32, 71.0), jb.playback_elapsed, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), jb.remainingPlaybackSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), jb.playbackProgress(), 0.001);
}

test "10: JukeboxState retains disc and comparator signal after playback completion" {
    var jb = JukeboxState.init();
    _ = jb.insertDisc(.disc_5); // comparator signal 15, duration 178.0s
    try std.testing.expectEqual(@as(u4, 15), jb.comparatorSignal());

    // Advance way past the end of track
    jb.tickPlayback(250.0);
    try std.testing.expect(!jb.is_playing); // playback stopped
    try std.testing.expect(jb.hasDisc()); // disc remains inside!
    try std.testing.expectEqual(@as(?MusicDisc, .disc_5), jb.inserted_disc);
    // Comparator signal MUST remain 15 while disc is inside
    try std.testing.expectEqual(@as(u4, 15), jb.comparatorSignal());
}

test "11: JukeboxState ejectDisc resets playback and zeroes comparator signal" {
    var jb = JukeboxState.init();
    _ = jb.insertDisc(.pigstep);
    jb.tickPlayback(50.0);
    try std.testing.expectEqual(@as(u4, 13), jb.comparatorSignal());

    const ejected = jb.ejectDisc();
    try std.testing.expectEqual(@as(?MusicDisc, .pigstep), ejected);
    try std.testing.expectEqual(@as(?MusicDisc, null), jb.inserted_disc);
    try std.testing.expect(!jb.is_playing);
    try std.testing.expectEqual(@as(f32, 0.0), jb.playback_elapsed);
    try std.testing.expectEqual(@as(u4, 0), jb.comparatorSignal());

    // Ejecting from empty jukebox returns null
    try std.testing.expectEqual(@as(?MusicDisc, null), jb.ejectDisc());
}

test "12: JukeboxState hopper extraction support" {
    var jb = JukeboxState.init();
    _ = jb.insertDisc(.relic);
    try std.testing.expectEqual(@as(u4, 14), jb.comparatorSignal());

    // Hopper pulls record out
    const hopper_item = jb.hopperExtract();
    try std.testing.expectEqual(@as(?MusicDisc, .relic), hopper_item);
    try std.testing.expect(!jb.hasDisc());
    try std.testing.expectEqual(@as(u4, 0), jb.comparatorSignal());
}

test "13: Disc 5 fragment crafting: 0 to 8 fragments yields 0 discs" {
    var f: u8 = 0;
    while (f < 9) : (f += 1) {
        const res = craftDisc5FromFragments(f);
        try std.testing.expectEqual(@as(u8, 0), res.discs_crafted);
        try std.testing.expectEqual(f, res.remaining_fragments);
    }
}

test "14: Disc 5 fragment crafting: exact multiples and remainders" {
    // Exact 9 -> 1 disc, 0 remaining
    const res9 = craftDisc5FromFragments(9);
    try std.testing.expectEqual(@as(u8, 1), res9.discs_crafted);
    try std.testing.expectEqual(@as(u8, 0), res9.remaining_fragments);

    // Exact 18 -> 2 discs, 0 remaining
    const res18 = craftDisc5FromFragments(18);
    try std.testing.expectEqual(@as(u8, 2), res18.discs_crafted);
    try std.testing.expectEqual(@as(u8, 0), res18.remaining_fragments);

    // 25 fragments -> 2 discs, 7 remaining
    const res25 = craftDisc5FromFragments(25);
    try std.testing.expectEqual(@as(u8, 2), res25.discs_crafted);
    try std.testing.expectEqual(@as(u8, 7), res25.remaining_fragments);

    // Full stack of 64 fragments -> 7 discs, 1 remaining
    const res64 = craftDisc5FromFragments(64);
    try std.testing.expectEqual(@as(u8, 7), res64.discs_crafted);
    try std.testing.expectEqual(@as(u8, 1), res64.remaining_fragments);
}

test "15: Allay duplication dance: valid conditions within 10 blocks succeeds" {
    // Exactly at jukebox (distance_sq = 0.0)
    try std.testing.expect(canDuplicateDancingAllay(true, 0.0, true, 0.0));
    // Mid-range (5 blocks away, distance_sq = 25.0)
    try std.testing.expect(canDuplicateDancingAllay(true, 25.0, true, 0.0));
    // Exact boundary (10 blocks away, distance_sq = 100.0)
    try std.testing.expect(canDuplicateDancingAllay(true, 100.0, true, 0.0));
    // With negative/zero cooldown (ready)
    try std.testing.expect(canDuplicateDancingAllay(true, 40.0, true, -1.0));
}

test "16: Allay duplication dance fails if jukebox is not playing" {
    // Jukebox has disc but stopped or empty
    try std.testing.expect(!canDuplicateDancingAllay(false, 0.0, true, 0.0));
    try std.testing.expect(!canDuplicateDancingAllay(false, 25.0, true, 0.0));
}

test "17: Allay duplication dance fails if distance exceeds 10 blocks (> 100 distance_sq)" {
    // Slightly beyond boundary (10.01 blocks, distance_sq = 100.2)
    try std.testing.expect(!canDuplicateDancingAllay(true, 100.2, true, 0.0));
    // Far away
    try std.testing.expect(!canDuplicateDancingAllay(true, 400.0, true, 0.0));
    // Negative distance sanity check
    try std.testing.expect(!canDuplicateDancingAllay(true, -1.0, true, 0.0));
}

test "18: Allay duplication dance fails without amethyst shard" {
    try std.testing.expect(!canDuplicateDancingAllay(true, 25.0, false, 0.0));
}

test "19: Allay duplication dance fails on cooldown and recovers with tick" {
    var cooldown: f32 = allay_duplication_cooldown_duration; // 300.0s (5 minutes)
    try std.testing.expect(!canDuplicateDancingAllay(true, 25.0, true, cooldown));

    // Tick 150 seconds (halfway)
    cooldown = tickAllayDuplicationCooldown(cooldown, 150.0);
    try std.testing.expectApproxEqAbs(@as(f32, 150.0), cooldown, 0.001);
    try std.testing.expect(!canDuplicateDancingAllay(true, 25.0, true, cooldown));

    // Tick remaining 150 seconds
    cooldown = tickAllayDuplicationCooldown(cooldown, 150.0);
    try std.testing.expectEqual(@as(f32, 0.0), cooldown);
    try std.testing.expect(canDuplicateDancingAllay(true, 25.0, true, cooldown));

    // Cooldown never ticks below zero
    cooldown = tickAllayDuplicationCooldown(cooldown, 10.0);
    try std.testing.expectEqual(@as(f32, 0.0), cooldown);
}

test "20: 3D distance and range helper functions for Allay and Jukebox" {
    // Jukebox at (10, 64, 10), Allay at (13, 64, 14) -> dx = 3, dz = 4, dy = 0 -> distance_sq = 25
    const dsq = allayDistanceSq(10.0, 64.0, 10.0, 13.0, 64.0, 14.0);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), dsq, 0.001);
    try std.testing.expect(isWithinAllayDanceRange(10.0, 64.0, 10.0, 13.0, 64.0, 14.0));

    // Far allay: dx = 8, dz = 8 -> distance_sq = 128 > 100
    try std.testing.expect(!isWithinAllayDanceRange(0.0, 0.0, 0.0, 8.0, 0.0, 8.0));
}

test "21: fromId disc roundtrip and title/author metadata" {
    var id: u8 = 1;
    while (id <= 19) : (id += 1) {
        const disc = MusicDisc.fromId(id).?;
        try std.testing.expectEqual(id, @intFromEnum(disc));
        try std.testing.expect(disc.title().len > 0);
        try std.testing.expect(disc.author().len > 0);
    }
    try std.testing.expectEqual(@as(?MusicDisc, null), MusicDisc.fromId(0));
    try std.testing.expectEqual(@as(?MusicDisc, null), MusicDisc.fromId(20));
}
