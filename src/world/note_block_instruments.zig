const std = @import("std");

/// Broad material categories used to select a Note Block's instrument.
pub const UnderBlockMaterial = enum {
    wood,
    sand_gravel,
    glass,
    stone,
    gold_block,
    clay,
    packed_ice,
    wool,
    bone_block,
    iron_block,
    soul_sand,
    pumpkin,
    emerald_block,
    hay_bale,
    glowstone,
    other,
};

/// Mob heads which can be mounted directly above a Note Block.
pub const MobHeadKind = enum {
    zombie,
    skeleton,
    creeper,
    wither_skeleton,
    piglin,
    ender_dragon,
};

/// Instrument sounds available to Note Blocks, including mob-head overrides.
pub const NoteBlockInstrument = enum {
    harp,
    bass,
    snare_drum,
    clicks_and_sticks,
    bass_drum,
    bell,
    flute,
    chime,
    guitar,
    xylophone,
    iron_xylophone,
    cow_bell,
    didgeridoo,
    bit_synth,
    banjo,
    pling,
    mob_zombie,
    mob_skeleton,
    mob_creeper,
    mob_wither_skeleton,
    mob_piglin,
    mob_ender_dragon,
};

/// A mounted mob head takes precedence over the material beneath the block.
pub fn resolveNoteBlockInstrument(under_block_category: UnderBlockMaterial, mob_head_on_top: ?MobHeadKind) NoteBlockInstrument {
    if (mob_head_on_top) |head| {
        return switch (head) {
            .zombie => .mob_zombie,
            .skeleton => .mob_skeleton,
            .creeper => .mob_creeper,
            .wither_skeleton => .mob_wither_skeleton,
            .piglin => .mob_piglin,
            .ender_dragon => .mob_ender_dragon,
        };
    }

    return switch (under_block_category) {
        .wood => .bass,
        .sand_gravel => .snare_drum,
        .glass => .clicks_and_sticks,
        .stone => .bass_drum,
        .gold_block => .bell,
        .clay => .flute,
        .packed_ice => .chime,
        .wool => .guitar,
        .bone_block => .xylophone,
        .iron_block => .iron_xylophone,
        .soul_sand => .cow_bell,
        .pumpkin => .didgeridoo,
        .emerald_block => .bit_synth,
        .hay_bale => .banjo,
        .glowstone => .pling,
        .other => .harp,
    };
}

/// Advances one semitone through the 25 playable pitches, wrapping at 24.
pub fn cycleNoteBlockPitch(current_pitch_0_to_24: u5) u5 {
    return if (current_pitch_0_to_24 >= 24) 0 else current_pitch_0_to_24 + 1;
}

/// Frequency multiplier for a pitch relative to pitch 12.
pub fn computeNotePitchMultiplier(pitch_0_to_24: u5) f32 {
    const semitones: f32 = @as(f32, @floatFromInt(pitch_0_to_24)) - 12.0;
    return @exp2(semitones / 12.0);
}

/// A solid block above the Note Block muffles it; air and mob heads do not.
pub fn canNoteBlockSound(block_directly_above_is_air_or_mob_head: bool) bool {
    return block_directly_above_is_air_or_mob_head;
}

test "wood maps to bass" {
    try std.testing.expectEqual(NoteBlockInstrument.bass, resolveNoteBlockInstrument(.wood, null));
}

test "sand and gravel map to snare drum" {
    try std.testing.expectEqual(NoteBlockInstrument.snare_drum, resolveNoteBlockInstrument(.sand_gravel, null));
}

test "glass maps to clicks and sticks" {
    try std.testing.expectEqual(NoteBlockInstrument.clicks_and_sticks, resolveNoteBlockInstrument(.glass, null));
}

test "stone maps to bass drum" {
    try std.testing.expectEqual(NoteBlockInstrument.bass_drum, resolveNoteBlockInstrument(.stone, null));
}

test "gold block maps to bell" {
    try std.testing.expectEqual(NoteBlockInstrument.bell, resolveNoteBlockInstrument(.gold_block, null));
}

test "clay maps to flute" {
    try std.testing.expectEqual(NoteBlockInstrument.flute, resolveNoteBlockInstrument(.clay, null));
}

test "packed ice maps to chime" {
    try std.testing.expectEqual(NoteBlockInstrument.chime, resolveNoteBlockInstrument(.packed_ice, null));
}

test "wool maps to guitar" {
    try std.testing.expectEqual(NoteBlockInstrument.guitar, resolveNoteBlockInstrument(.wool, null));
}

test "bone block maps to xylophone" {
    try std.testing.expectEqual(NoteBlockInstrument.xylophone, resolveNoteBlockInstrument(.bone_block, null));
}

test "iron block maps to iron xylophone" {
    try std.testing.expectEqual(NoteBlockInstrument.iron_xylophone, resolveNoteBlockInstrument(.iron_block, null));
}

test "soul sand maps to cow bell" {
    try std.testing.expectEqual(NoteBlockInstrument.cow_bell, resolveNoteBlockInstrument(.soul_sand, null));
}

test "pumpkin maps to didgeridoo" {
    try std.testing.expectEqual(NoteBlockInstrument.didgeridoo, resolveNoteBlockInstrument(.pumpkin, null));
}

test "emerald block maps to bit synth" {
    try std.testing.expectEqual(NoteBlockInstrument.bit_synth, resolveNoteBlockInstrument(.emerald_block, null));
}

test "hay bale maps to banjo" {
    try std.testing.expectEqual(NoteBlockInstrument.banjo, resolveNoteBlockInstrument(.hay_bale, null));
}

test "glowstone maps to pling" {
    try std.testing.expectEqual(NoteBlockInstrument.pling, resolveNoteBlockInstrument(.glowstone, null));
}

test "other material maps to harp" {
    try std.testing.expectEqual(NoteBlockInstrument.harp, resolveNoteBlockInstrument(.other, null));
}

test "mob head overrides under-block instrument with its vocalization" {
    const cases = [_]struct { head: MobHeadKind, instrument: NoteBlockInstrument }{
        .{ .head = .zombie, .instrument = .mob_zombie },
        .{ .head = .skeleton, .instrument = .mob_skeleton },
        .{ .head = .creeper, .instrument = .mob_creeper },
        .{ .head = .wither_skeleton, .instrument = .mob_wither_skeleton },
        .{ .head = .piglin, .instrument = .mob_piglin },
        .{ .head = .ender_dragon, .instrument = .mob_ender_dragon },
    };
    for (cases) |case| {
        try std.testing.expectEqual(case.instrument, resolveNoteBlockInstrument(.wood, case.head));
    }
}

test "pitch cycles through 0 to 24 and wraps to zero" {
    var pitch: u5 = 0;
    var expected: u5 = 1;
    while (expected <= 24) : (expected += 1) {
        pitch = cycleNoteBlockPitch(pitch);
        try std.testing.expectEqual(expected, pitch);
    }
    try std.testing.expectEqual(@as(u5, 0), cycleNoteBlockPitch(pitch));
}

test "pitch multiplier is half, unity, and double at octaves" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), computeNotePitchMultiplier(0), 0.00001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), computeNotePitchMultiplier(12), 0.00001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), computeNotePitchMultiplier(24), 0.00001);
}

test "solid block above muffles while air or mob head permits sound" {
    try std.testing.expect(canNoteBlockSound(true));
    try std.testing.expect(!canNoteBlockSound(false));
}
