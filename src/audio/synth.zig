const std = @import("std");

pub const SoundType = enum {
    step_grass,
    step_stone,
    step_wood,
    step_dirt,
    break_block,
    place_block,
    mob_baa,
    craft_item,
};

pub const SAMPLE_RATE: u32 = 44100;
pub const MAX_CHANNELS: usize = 8;

pub const ActiveVoice = struct {
    sound_type: SoundType,
    cursor: usize,
    total_samples: usize,
    volume: f32,
    active: bool,
};

pub const AudioMixer = struct {
    voices: [MAX_CHANNELS]ActiveVoice,
    rng: std.Random.DefaultPrng,

    pub fn init() AudioMixer {
        var mixer = AudioMixer{
            .voices = undefined,
            .rng = std.Random.DefaultPrng.init(0x1337BEEF),
        };
        for (&mixer.voices) |*v| {
            v.active = false;
            v.cursor = 0;
            v.total_samples = 0;
            v.volume = 1.0;
            v.sound_type = .step_grass;
        }
        return mixer;
    }

    pub fn play(self: *AudioMixer, sound: SoundType, volume: f32) void {
        var slot: ?*ActiveVoice = null;
        for (&self.voices) |*v| {
            if (!v.active) {
                slot = v;
                break;
            }
        }
        if (slot == null) {
            slot = &self.voices[0];
        }

        const duration_samples: usize = switch (sound) {
            .step_grass, .step_dirt => SAMPLE_RATE / 10, // ~100ms
            .step_stone => SAMPLE_RATE / 12, // ~83ms
            .step_wood => SAMPLE_RATE / 9, // ~110ms
            .break_block => SAMPLE_RATE / 6, // ~166ms
            .place_block => SAMPLE_RATE / 10, // ~100ms
            .mob_baa => SAMPLE_RATE / 3, // ~333ms
            .craft_item => SAMPLE_RATE / 6, // ~166ms
        };

        slot.?.* = .{
            .sound_type = sound,
            .cursor = 0,
            .total_samples = duration_samples,
            .volume = volume,
            .active = true,
        };
    }

    pub fn render(self: *AudioMixer, buffer: []i16) void {
        @memset(buffer, 0);

        for (buffer) |*out_sample| {
            var mixed_sample: f32 = 0.0;

            for (&self.voices) |*v| {
                if (!v.active) continue;

                const progress = @as(f32, @floatFromInt(v.cursor)) / @as(f32, @floatFromInt(v.total_samples));
                const sample_val = sampleVoice(v.sound_type, progress, v.cursor, &self.rng);

                mixed_sample += sample_val * v.volume;

                v.cursor += 1;
                if (v.cursor >= v.total_samples) {
                    v.active = false;
                }
            }

            // Soft-clip / clamp to i16 range
            const clamped = std.math.clamp(mixed_sample, -1.0, 1.0);
            out_sample.* = @intFromFloat(clamped * 32767.0);
        }
    }

    fn sampleVoice(sound: SoundType, progress: f32, sample_idx: usize, rng: *std.Random.DefaultPrng) f32 {
        const decay = 1.0 - progress;
        const envelope = decay * decay; // Quadratic decay

        switch (sound) {
            .step_grass => {
                // Low-pass filtered noise + soft thump
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.4;
                const freq: f32 = 80.0 * (1.0 - progress * 0.5);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.6;
                return (noise + tone) * envelope * 0.5;
            },
            .step_stone => {
                // Higher pitched crisp click / transient
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.7;
                const freq: f32 = 240.0 * (1.0 - progress * 0.7);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.4;
                return (noise + tone) * (envelope * decay) * 0.6;
            },
            .step_wood => {
                // Hollow thud
                const freq: f32 = 140.0 * (1.0 - progress * 0.4);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.8;
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.2;
                return (tone + noise) * envelope * 0.6;
            },
            .step_dirt => {
                // Muffled crunch
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.6;
                const freq: f32 = 100.0 * (1.0 - progress * 0.6);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.4;
                return (noise + tone) * envelope * 0.5;
            },
            .break_block => {
                // Crunchy burst with pitch drop
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.75;
                const freq: f32 = 180.0 * (1.0 - progress * 0.8);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.3;
                return (noise + tone) * envelope * 0.7;
            },
            .place_block => {
                // Crisp pop / snap
                const freq: f32 = 320.0 * (1.0 - progress * 0.6);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.7;
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.3;
                return (tone + noise) * envelope * 0.6;
            },
            .mob_baa => {
                // Sheep bleat: warm harmonic vocalization (~180-220Hz) with gentle vibrato and formant envelope
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const vibrato = 1.0 + 0.04 * @sin(t * 35.0);
                const freq: f32 = (200.0 + 20.0 * (1.0 - progress)) * vibrato;
                const phase = t * freq * 2.0 * std.math.pi;
                const h1 = @sin(phase);
                const h2 = 0.5 * @sin(phase * 2.0);
                const h3 = 0.25 * @sin(phase * 3.0);
                const breath = (rng.random().float(f32) * 2.0 - 1.0) * 0.12;
                const env = @sin(progress * std.math.pi);
                return (h1 + h2 + h3 + breath) * env * 0.45;
            },
            .craft_item => {
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const freq: f32 = if (progress < 0.5) 880.0 else 1320.0;
                const phase = t * freq * 2.0 * std.math.pi;
                const wave = @sin(phase) + 0.3 * @sin(phase * 2.0);
                const sub_progress = if (progress < 0.5) progress * 2.0 else (progress - 0.5) * 2.0;
                const amp = (1.0 - sub_progress) * (1.0 - @exp(-t * 80.0));
                return wave * amp * 0.5;
            },
        }
    }
};

test "AudioMixer initialization and render silence" {
    var mixer = AudioMixer.init();
    var buf: [128]i16 = undefined;
    mixer.render(&buf);
    for (buf) |s| {
        try std.testing.expectEqual(@as(i16, 0), s);
    }
}

test "AudioMixer play voice produces non-zero samples" {
    var mixer = AudioMixer.init();
    mixer.play(.step_stone, 1.0);
    var buf: [256]i16 = undefined;
    mixer.render(&buf);

    var has_nonzero = false;
    for (buf) |s| {
        if (s != 0) {
            has_nonzero = true;
            break;
        }
    }
    try std.testing.expect(has_nonzero);
}

test "AudioMixer all sound types render without overflow or crash" {
    var mixer = AudioMixer.init();
    const sounds = [_]SoundType{ .step_grass, .step_stone, .step_wood, .step_dirt, .break_block, .place_block, .mob_baa };
    for (sounds) |snd| {
        mixer.play(snd, 1.0);
    }

    var buf: [512]i16 = undefined;
    mixer.render(&buf);
    var max_val: i16 = 0;
    for (buf) |s| {
        if (s > max_val) max_val = s;
    }
    try std.testing.expect(max_val > 0);
}
