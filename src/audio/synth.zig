fn hash2(x: usize, y: usize, seed: u32) u32 {
    var h: u32 = seed +% @as(u32, @intCast(x)) *% 374761393 +% @as(u32, @intCast(y)) *% 668265263;
    h ^= h >> 13;
    h *%= 1274126177;
    h ^= h >> 16;
    return h;
}

const std = @import("std");

pub const SoundType = enum {
    step_grass,
    step_stone,
    step_wood,
    step_dirt,
    step_snow,
    step_wool,
    step_sand,
    break_block,
    place_block,
    mob_baa,
    mob_oink,
    craft_item,
    eat,
    hurt,
    mob_growl,
    mob_roar,
    click_on,
    click_off,
    splash,
    underwater_submerge,
    lava_pop,
    lava_bubble,
    portal_hum,
    portal_warp,
    burn_sizzle,
    nether_wind,
    glowstone_chime,
    bow_shoot,
    shield_block,
    crossbow_shoot,
    crossbow_load,
    firework_blast,
    note_harp,
    note_bass,
    note_snare,
    note_chime,
    record_13,
    record_cat,
    anvil_clang,
    grindstone_scrape,
    smithing_strike,
    map_rustle,
    fletching_snap,
    composter_fill,
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
            .step_grass, .step_dirt, .step_sand => SAMPLE_RATE / 10, // ~100ms
            .step_snow => SAMPLE_RATE / 8, // ~125ms
            .step_wool => SAMPLE_RATE / 12, // ~83ms
            .step_stone => SAMPLE_RATE / 12, // ~83ms
            .step_wood => SAMPLE_RATE / 9, // ~110ms
            .break_block => SAMPLE_RATE / 6, // ~166ms
            .place_block => SAMPLE_RATE / 10, // ~100ms
            .mob_baa => SAMPLE_RATE / 3, // ~333ms
            .mob_oink => SAMPLE_RATE / 4, // ~250ms
            .eat => SAMPLE_RATE / 5, // ~200ms
            .hurt => SAMPLE_RATE / 3, // ~330ms
            .mob_growl => SAMPLE_RATE / 2, // ~500ms
            .mob_roar => SAMPLE_RATE * 2 / 3, // ~660ms
            .craft_item => SAMPLE_RATE / 6, // ~166ms
            .click_on, .click_off => SAMPLE_RATE / 20, // ~50ms mechanical click
            .splash => SAMPLE_RATE / 4, // ~250ms bubbly splash burst
            .underwater_submerge => SAMPLE_RATE / 3, // ~330ms deep water plunge
            .lava_pop => SAMPLE_RATE / 10, // ~100ms quick fiery pop/snap
            .lava_bubble => SAMPLE_RATE / 4, // ~250ms low simmering bubbling hiss
            .portal_hum => SAMPLE_RATE / 2, // ~500ms mystical otherworldly choir drone
            .portal_warp => SAMPLE_RATE * 3 / 4, // ~750ms sweeping dimension portal vortex whoosh
            .burn_sizzle => SAMPLE_RATE / 3, // ~330ms fiery contact hiss & burning crackle
            .nether_wind => SAMPLE_RATE * 3 / 2, // ~1500ms ominous hollow gust & subterranean rumble
            .glowstone_chime => SAMPLE_RATE * 2 / 5, // ~400ms crystalline harmonic chime bell
            .bow_shoot => SAMPLE_RATE / 5, // ~200ms bow string snap & twang
            .shield_block => SAMPLE_RATE / 6, // ~166ms heavy wooden-iron clang
            .crossbow_shoot => SAMPLE_RATE / 6, // ~166ms powerful latch release snap & whip
            .crossbow_load => SAMPLE_RATE / 5, // ~200ms ratchet latch click & tension creak
            .firework_blast => SAMPLE_RATE * 2 / 5, // ~400ms explosive thud & cascading crackle
            .note_harp, .note_bass, .note_chime => SAMPLE_RATE * 3 / 10, // ~300ms resonant melodic decay
            .note_snare => SAMPLE_RATE / 8, // ~125ms sharp percussion snare snap
            .record_13, .record_cat => SAMPLE_RATE * 3, // ~3000ms vinyl record melody phrase
            .anvil_clang => SAMPLE_RATE / 3, // ~333ms resonant metallic iron anvil strike & overtone ringing
            .grindstone_scrape => SAMPLE_RATE / 4, // ~250ms abrasive stone-on-metal sharpening friction hiss & friction rumble
            .smithing_strike => SAMPLE_RATE / 4, // ~250ms solid heavy wooden-iron bench hammer thud & anvil clack
            .map_rustle => SAMPLE_RATE / 5, // ~200ms crisp paper parchment flutter & drafting slide
            .fletching_snap => SAMPLE_RATE / 6, // ~166ms precision arrow nock snap & wood dowel click
            .composter_fill => SAMPLE_RATE / 5, // ~200ms leafy organic mulch deposit & crunch rustle
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
            .step_sand => {
                // Gritty granular slide/crunch: high-frequency noise + low thud
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.8;
                const freq: f32 = 80.0 * (1.0 - progress * 0.5);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.25;
                return (noise * 0.75 + tone) * envelope * 0.5;
            },
            .step_snow => {
                // Powdery crunch: bright noise with slow decay
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.65;
                const freq: f32 = 900.0 * (1.0 - progress * 0.3);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.15;
                return (noise + tone) * envelope * 0.55;
            },
            .step_wool => {
                // Soft thud: low sine, fast decay
                const freq: f32 = 120.0 * (1.0 - progress * 0.3);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.7;
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.1;
                return (tone + noise) * envelope * 0.5;
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
            .mob_oink => {
                // Pig grunt / oink: low pitch formant grunt (~130-160Hz) with rapid pitch rise & fall + snort noise
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const pitch_bend = 1.0 + 0.3 * @sin(progress * std.math.pi);
                const freq: f32 = 135.0 * pitch_bend;
                const phase = t * freq * 2.0 * std.math.pi;
                const tone = @sin(phase) + 0.4 * @sin(phase * 2.0) + 0.2 * @sin(phase * 3.0);
                const snort = (rng.random().float(f32) * 2.0 - 1.0) * 0.25;
                const env = @sin(progress * std.math.pi) * (1.0 - progress * 0.4);
                return (tone * 0.75 + snort) * env * 0.5;
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
            .eat => {
                // Munch: 3 short noise chomps decaying
                const chomp = @sin(progress * std.math.pi * 3.0);
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.5;
                const freq: f32 = 300.0 * (1.0 - progress * 0.5);
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.4;
                return (noise * @max(0.0, chomp) + tone * 0.5) * envelope * 0.6;
            },
            .mob_roar => {
                // Emberbeast roar: deep 55Hz bellow with fiery 220Hz overtone and crackle
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const wobble = 0.6 + 0.4 * @sin(t * 40.0);
                const phase = t * 55.0 * 2.0 * std.math.pi;
                const tone = @sin(phase) + 0.6 * @sin(phase * 4.0) + 0.3 * @sin(phase * 8.03);
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.2;
                return (tone * wobble + noise) * envelope * 0.65;
            },
            .mob_growl => {
                // Wolf growl: low rumbling 70Hz with amplitude wobble
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const wobble = 0.6 + 0.4 * @sin(t * 55.0);
                const freq: f32 = 70.0;
                const phase = t * freq * 2.0 * std.math.pi;
                const tone = @sin(phase) + 0.5 * @sin(phase * 1.5) + 0.25 * @sin(phase * 2.02);
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.15;
                return (tone * wobble + noise) * envelope * 0.6;
            },
            .hurt => {
                // Pained yelp: falling pitch 400->150Hz
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const freq: f32 = 400.0 - 250.0 * progress;
                const phase = t * freq * 2.0 * std.math.pi;
                const tone = @sin(phase) + 0.3 * @sin(phase * 2.0);
                return tone * envelope * 0.55;
            },
            .click_on => {
                // Sharp mechanical snap down (high pitch click: 1600Hz transient)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.6;
                const freq: f32 = 1400.0 * (1.0 - progress * 0.8);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.5;
                return (noise + tone) * envelope * 0.7;
            },
            .click_off => {
                // Slightly softer mechanical release click (1000Hz transient)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.4;
                const freq: f32 = 900.0 * (1.0 - progress * 0.7);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.4;
                return (noise + tone) * envelope * 0.55;
            },
            .splash => {
                // Water splash: bubbly pitch-drop sine wave modulated by churning white noise
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const bubble_freq: f32 = 360.0 * (1.0 - progress * 0.6) + 40.0 * @sin(t * 80.0);
                const tone = @sin(t * bubble_freq * 2.0 * std.math.pi) * 0.6;
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.5;
                const foam = @sin(progress * std.math.pi);
                return (tone + noise * foam) * envelope * 0.7;
            },
            .underwater_submerge => {
                // Submerge thud: low frequency resonant swell (80Hz down to 40Hz)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const freq: f32 = 90.0 * (1.0 - progress * 0.5);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.8;
                const sub = @sin(t * (freq * 0.5) * 2.0 * std.math.pi) * 0.4;
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.15 * (1.0 - progress);
                return (tone + sub + noise) * envelope * 0.75;
            },
            .lava_pop => {
                // Lava burst pop: short high-energy chirp dropping pitch (650Hz -> 180Hz) + fiery sizzle noise
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const freq: f32 = 650.0 * (1.0 - progress * 0.75);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.65;
                const sizzle = (rng.random().float(f32) * 2.0 - 1.0) * 0.35 * (1.0 - progress * 0.5);
                return (tone + sizzle) * envelope * 0.7;
            },
            .lava_bubble => {
                // Simmering lava bubble: low viscous rumble (90-120Hz modulated) + subtle escaping steam hiss
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const wobble = @sin(t * 45.0);
                const freq: f32 = (110.0 + 30.0 * wobble) * (1.0 - progress * 0.4);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.75;
                const hiss = (rng.random().float(f32) * 2.0 - 1.0) * 0.25 * @sin(progress * std.math.pi);
                return (tone + hiss) * envelope * 0.65;
            },
            .portal_hum => {
                // Nether portal hum: resonant dual-frequency choir drone (~146Hz / 220Hz) with eerie tremolo
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const tremolo = 0.7 + 0.3 * @sin(t * 18.0);
                const p1 = t * 146.83 * 2.0 * std.math.pi; // D3 fundamental
                const p2 = t * 220.00 * 2.0 * std.math.pi; // A3 harmonic fifth
                const p3 = t * 293.66 * 2.0 * std.math.pi; // D4 octave
                const tone = (@sin(p1) * 0.6 + @sin(p2) * 0.3 + @sin(p3) * 0.15) * tremolo;
                const ether_whisper = (rng.random().float(f32) * 2.0 - 1.0) * 0.1 * @sin(progress * std.math.pi);
                return (tone + ether_whisper) * @sin(progress * std.math.pi) * 0.6;
            },
            .portal_warp => {
                // Nether teleport warp: rising & falling frequency vortex sweep with resonant white-noise rush
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const freq = 120.0 + 380.0 * @sin(progress * std.math.pi * 0.8);
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.7;
                const whoosh = (rng.random().float(f32) * 2.0 - 1.0) * 0.3 * @sin(progress * std.math.pi);
                const env = @sin(progress * std.math.pi);
                return (tone + whoosh) * env * 0.8;
            },
            .burn_sizzle => {
                // Burning contact hiss: searing high-frequency white noise + steam sizzle flutter (800-2400Hz)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const hiss = (rng.random().float(f32) * 2.0 - 1.0) * 0.65;
                const flutter = 0.7 + 0.3 * @sin(t * 120.0);
                const crackle = if (rng.random().float(f32) < 0.15) (rng.random().float(f32) * 2.0 - 1.0) * 0.4 else 0.0;
                return (hiss * flutter + crackle) * envelope * 0.75;
            },
            .nether_wind => {
                // Ominous Nether subterranean wind: low 55Hz rumble modulated with hollow whistling breath
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const sub_bass = @sin(t * 55.0 * 2.0 * std.math.pi) * 0.5;
                const drone = @sin(t * 110.0 * 2.0 * std.math.pi + 0.4 * @sin(t * 3.5)) * 0.25;
                const breath = (rng.random().float(f32) * 2.0 - 1.0) * 0.3 * (0.6 + 0.4 * @sin(t * 5.0));
                const env = @sin(progress * std.math.pi);
                return (sub_bass + drone + breath) * env * 0.55;
            },
            .glowstone_chime => {
                // Radiant crystalline bell chime: pristine pure harmonics (880Hz root, 1760Hz octave, 2640Hz 5th) with sparkling shimmer decay
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const h1 = @sin(t * 880.0 * 2.0 * std.math.pi) * 0.55;
                const h2 = @sin(t * 1760.0 * 2.0 * std.math.pi) * 0.30;
                const h3 = @sin(t * 2640.0 * 2.0 * std.math.pi) * 0.15;
                const sparkle = (rng.random().float(f32) * 2.0 - 1.0) * 0.05 * (1.0 - progress);
                const chime_env = @exp(-progress * 4.5);
                return (h1 + h2 + h3 + sparkle) * chime_env * 0.65;
            },
            .bow_shoot => {
                // Bow string release snap & twang: sharp initial snap click + vibrating tension sine (280Hz -> 140Hz)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const click = (rng.random().float(f32) * 2.0 - 1.0) * 0.5 * (1.0 - @min(1.0, progress * 8.0));
                const freq: f32 = 280.0 * (1.0 - progress * 0.5);
                const twang = @sin(t * freq * 2.0 * std.math.pi) * 0.7 + 0.3 * @sin(t * freq * 4.0 * std.math.pi);
                return (twang + click) * envelope * 0.7;
            },
            .shield_block => {
                // Shield block thud: heavy wooden-iron clang (180Hz fundamental + 540Hz iron harmonic + transient thud)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const click = (rng.random().float(f32) * 2.0 - 1.0) * 0.6 * (1.0 - @min(1.0, progress * 10.0));
                const wood = @sin(t * 180.0 * 2.0 * std.math.pi) * 0.6;
                const iron = @sin(t * 540.0 * 2.0 * std.math.pi) * 0.35 * @exp(-progress * 6.0);
                return (wood + iron + click) * envelope * 0.75;
            },
            .crossbow_shoot => {
                // Crossbow trigger latch release: powerful sharp mechanical snap & whip (420Hz -> 210Hz)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const snap = (rng.random().float(f32) * 2.0 - 1.0) * 0.75 * (1.0 - @min(1.0, progress * 12.0));
                const freq: f32 = 420.0 * (1.0 - progress * 0.5);
                const whip = @sin(t * freq * 2.0 * std.math.pi) * 0.75;
                return (whip + snap) * envelope * 0.85;
            },
            .crossbow_load => {
                // Crossbow wind ratchet: tension creak (130Hz) + metal latch clicks
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const ratchet = if (@sin(progress * 30.0) > 0.7) (rng.random().float(f32) * 0.6) else 0.0;
                const creak = @sin(t * 130.0 * 2.0 * std.math.pi) * 0.45;
                return (creak + ratchet) * envelope * 0.65;
            },
            .firework_blast => {
                // Firework explosion: initial low blast concussive punch (90Hz) + glittering crackle hiss
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const punch = @sin(t * 90.0 * 2.0 * std.math.pi) * 0.75 * @exp(-progress * 8.0);
                const crackle_gate: f32 = if (progress > 0.15 and @sin(progress * 45.0) > 0.3) 1.0 else 0.2;
                const crackle = (rng.random().float(f32) * 2.0 - 1.0) * 0.5 * crackle_gate * (1.0 - progress);
                return (punch + crackle) * envelope * 0.85;
            },
            .note_harp => {
                // Plucked wooden acoustic harp/piano tone: rich warm harmonics (261.6Hz Middle C base)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const fund: f32 = 261.63; // C4
                const h1 = @sin(t * fund * 2.0 * std.math.pi) * 0.65;
                const h2 = @sin(t * fund * 4.0 * std.math.pi) * 0.25;
                const h3 = @sin(t * fund * 6.0 * std.math.pi) * 0.10;
                const harp_env = @exp(-progress * 5.0);
                return (h1 + h2 + h3) * harp_env * 0.85;
            },
            .note_bass => {
                // Deep acoustic double bass / wood floor thud: punchy low-end sine + warm sub (130.8Hz C3 base)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const fund: f32 = 130.81; // C3
                const sub = @sin(t * fund * 2.0 * std.math.pi) * 0.75;
                const punch = @sin(t * fund * 4.0 * std.math.pi) * 0.25 * @exp(-progress * 8.0);
                const bass_env = @exp(-progress * 4.0);
                return (sub + punch) * bass_env * 0.90;
            },
            .note_snare => {
                // Sand/gravel crisp acoustic percussion snare: high-passed noise burst + crisp skin snap
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.65;
                const snap = @sin(t * 330.0 * 2.0 * std.math.pi) * 0.35 * @exp(-progress * 12.0);
                const snare_env = @exp(-progress * 8.0);
                return (noise + snap) * snare_env * 0.80;
            },
            .note_chime => {
                // Glass / glowstone bell chime: pure crystalline high-frequency bell (523.25Hz C5 base)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const fund: f32 = 523.25; // C5
                const b1 = @sin(t * fund * 2.0 * std.math.pi) * 0.60;
                const b2 = @sin(t * fund * 6.0 * std.math.pi) * 0.30;
                const b3 = @sin(t * fund * 10.0 * std.math.pi) * 0.10;
                const chime_env = @exp(-progress * 4.5);
                return (b1 + b2 + b3) * chime_env * 0.75;
            },
            .record_13 => {
                // Record 13: mysterious ambient vinyl crackle + eerie minor harmonic motif (A minor chord progression)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const crackle = (rng.random().float(f32) * 2.0 - 1.0) * (if (hash2(sample_idx / 250, 0, 99) % 35 == 0) @as(f32, 0.4) else 0.03);
                // Step sequence: 0..0.75s A3 (220Hz), 0.75..1.5s C4 (261.6Hz), 1.5..2.25s E4 (329.6Hz), 2.25..3.0s G#3 (207.65Hz)
                const note_idx: usize = @min(3, @as(usize, @intFromFloat(t / 0.75)));
                const notes = [_]f32{ 220.0, 261.63, 329.63, 207.65 };
                const freq = notes[note_idx];
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.55 + @sin(t * freq * 4.0 * std.math.pi) * 0.15;
                const v_env = (1.0 - progress * 0.2);
                return (tone + crackle) * v_env * 0.70;
            },
            .composter_fill => {
                // Organic mulch compost crunch: low vegetation thump (90Hz) + fibrous foliage crackle
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const thump = @sin(t * 90.0 * 2.0 * std.math.pi) * 0.50 * @exp(-progress * 10.0);
                const crunch = if (@sin(t * 1200.0) > 0.6) (rng.random().float(f32) * 2.0 - 1.0) * 0.55 else 0.0;
                return (thump + crunch) * (1.0 - progress) * 0.75;
            },
            .fletching_snap => {
                // Precision wood nock snap: sharp transient click (1800Hz) + light arrow shaft twang (520Hz)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const click = if (progress < 0.06) (rng.random().float(f32) * 2.0 - 1.0) * 0.75 else 0.0;
                const twang = @sin(t * 520.0 * 2.0 * std.math.pi) * 0.45 * @exp(-progress * 12.0);
                const snap = @sin(t * 1800.0 * 2.0 * std.math.pi) * 0.35 * @exp(-progress * 25.0);
                return (click + twang + snap) * (1.0 - progress) * 0.80;
            },
            .map_rustle => {
                // Crisp dry parchment paper rustle: filtered noise flutter + soft page crinkle
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.55;
                const flutter = 0.5 + 0.5 * @sin(progress * 50.0);
                const crinkle = if (@sin(t * 700.0) > 0.8) (rng.random().float(f32) * 0.4) else 0.0;
                return (noise * flutter + crinkle) * (1.0 - progress) * 0.70;
            },
            .smithing_strike => {
                // Smithing table strike: low wood bench thud (120Hz) + sharp steel hammer clack (1200Hz)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const wood_thud = @sin(t * 120.0 * 2.0 * std.math.pi) * 0.60 * @exp(-progress * 8.0);
                const steel_clack = @sin(t * 1200.0 * 2.0 * std.math.pi) * 0.40 * @exp(-progress * 15.0);
                const transient_click = if (progress < 0.05) (rng.random().float(f32) * 2.0 - 1.0) * 0.50 else 0.0;
                return (wood_thud + steel_clack + transient_click) * (1.0 - progress) * 0.85;
            },
            .grindstone_scrape => {
                // Abrasive stone grinding friction: textured friction noise + dual harmonic buzz (440Hz / 660Hz)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const noise = (rng.random().float(f32) * 2.0 - 1.0) * 0.65;
                const buzz1 = @sin(t * 440.0 * 2.0 * std.math.pi) * 0.25;
                const buzz2 = @sin(t * 660.0 * 2.0 * std.math.pi) * 0.15;
                const flutter = 0.85 + 0.15 * @sin(progress * 40.0);
                const scrape_env = (1.0 - progress * 0.8) * flutter;
                return (noise + buzz1 + buzz2) * scrape_env * 0.75;
            },
            .anvil_clang => {
                // High resonant metallic overtone clang with fast initial transient hammer strike
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const impact_noise = if (progress < 0.08) (rng.random().float(f32) * 2.0 - 1.0) * 0.7 else 0.0;
                // Metallic bell-like inharmonic partials: ~880Hz, 1760Hz, 2340Hz, 3520Hz
                const p1 = @sin(t * 880.0 * 2.0 * std.math.pi) * 0.50;
                const p2 = @sin(t * 1760.0 * 2.0 * std.math.pi) * 0.35;
                const p3 = @sin(t * 2340.0 * 2.0 * std.math.pi) * 0.20;
                const p4 = @sin(t * 3520.0 * 2.0 * std.math.pi) * 0.15;
                const ring_decay = @exp(-progress * 6.0);
                return (impact_noise + p1 + p2 + p3 + p4) * ring_decay * 0.85;
            },
            .record_cat => {
                // Record cat: warm cheerful synth melody with gentle vinyl surface noise (C major bouncing arpeggio)
                const t = @as(f32, @floatFromInt(sample_idx)) / @as(f32, SAMPLE_RATE);
                const crackle = (rng.random().float(f32) * 2.0 - 1.0) * (if (hash2(sample_idx / 300, 0, 77) % 40 == 0) @as(f32, 0.25) else 0.02);
                // Step sequence: 0..0.5s C4 (261.6Hz), 0.5..1.0s E4 (329.6Hz), 1.0..1.5s G4 (392Hz), 1.5..2.0s C5 (523Hz), 2.0..2.5s A4 (440Hz), 2.5..3.0s G4 (392Hz)
                const step_idx: usize = @min(5, @as(usize, @intFromFloat(t / 0.5)));
                const notes = [_]f32{ 261.63, 329.63, 392.00, 523.25, 440.00, 392.00 };
                const freq = notes[step_idx];
                const tone = @sin(t * freq * 2.0 * std.math.pi) * 0.60 + 0.20 * @sin(t * freq * 3.0 * std.math.pi);
                const v_env = (1.0 - progress * 0.15);
                return (tone + crackle) * v_env * 0.75;
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
    const sounds = [_]SoundType{ .step_grass, .step_stone, .step_wood, .step_dirt, .step_snow, .step_wool, .step_sand, .break_block, .place_block, .mob_baa, .mob_oink, .eat, .hurt, .mob_growl, .mob_roar, .click_on, .click_off, .splash, .underwater_submerge, .lava_pop, .lava_bubble, .portal_hum, .portal_warp, .burn_sizzle, .nether_wind, .glowstone_chime, .bow_shoot, .shield_block, .crossbow_shoot, .crossbow_load, .firework_blast, .note_harp, .note_bass, .note_snare, .note_chime, .record_13, .record_cat, .anvil_clang, .grindstone_scrape, .smithing_strike, .map_rustle, .fletching_snap, .composter_fill };
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

test "AudioMixer burn_sizzle sound synthesizes properly" {
    var mixer = AudioMixer.init();
    mixer.play(.burn_sizzle, 0.7);
    var buf: [512]i16 = undefined;
    mixer.render(&buf);
    var has_audio = false;
    for (buf) |s| {
        if (s != 0) {
            has_audio = true;
            break;
        }
    }
    try std.testing.expect(has_audio);
}

test "nether_wind sound synthesis non-zero output" {
    var mixer = AudioMixer.init();
    mixer.play(.nether_wind, 0.8);
    var buf: [512]i16 = undefined;
    mixer.render(&buf);
    var non_zero = false;
    for (buf) |s| {
        if (s != 0) {
            non_zero = true;
            break;
        }
    }
    try std.testing.expect(non_zero);
}

test "glowstone_chime sound synthesis non-zero harmonic output" {
    var mixer = AudioMixer.init();
    mixer.play(.glowstone_chime, 0.75);
    var buf: [512]i16 = undefined;
    mixer.render(&buf);
    var non_zero = false;
    for (buf) |s| {
        if (s != 0) {
            non_zero = true;
            break;
        }
    }
    try std.testing.expect(non_zero);
}

test "bow_shoot sound synthesis non-zero output" {
    var mixer = AudioMixer.init();
    mixer.play(.bow_shoot, 0.8);
    var buf: [512]i16 = undefined;
    mixer.render(&buf);
    var non_zero = false;
    for (buf) |s| {
        if (s != 0) {
            non_zero = true;
            break;
        }
    }
    try std.testing.expect(non_zero);
}

test "shield_block sound synthesis non-zero output" {
    var mixer = AudioMixer.init();
    mixer.play(.shield_block, 0.85);
    var buf: [512]i16 = undefined;
    mixer.render(&buf);
    var non_zero = false;
    for (buf) |s| {
        if (s != 0) {
            non_zero = true;
            break;
        }
    }
    try std.testing.expect(non_zero);
}

test "crossbow sound synthesis non-zero output" {
    var mixer = AudioMixer.init();
    mixer.play(.crossbow_shoot, 0.8);
    mixer.play(.crossbow_load, 0.7);
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

test "firework_blast sound synthesis non-zero output" {
    var mixer = AudioMixer.init();
    mixer.play(.firework_blast, 0.9);
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

test "note block instrumental audio synthesis voices" {
    var mixer = AudioMixer.init();
    var buf: [256]i16 = undefined;

    const note_types = [_]SoundType{ .note_harp, .note_bass, .note_snare, .note_chime };
    for (note_types) |nt| {
        mixer.play(nt, 0.8);
        mixer.render(&buf);
        var non_zero = false;
        for (buf) |s| {
            if (s != 0) {
                non_zero = true;
                break;
            }
        }
        try std.testing.expect(non_zero);
    }
}

test "music disc vinyl audio synthesis voices" {
    var mixer = AudioMixer.init();
    var buf: [256]i16 = undefined;

    const disc_types = [_]SoundType{ .record_13, .record_cat, .anvil_clang, .grindstone_scrape, .smithing_strike, .map_rustle, .fletching_snap, .composter_fill };
    for (disc_types) |dt| {
        mixer.play(dt, 0.8);
        mixer.render(&buf);
        var non_zero = false;
        for (buf) |s| {
            if (s != 0) {
                non_zero = true;
                break;
            }
        }
        try std.testing.expect(non_zero);
    }
}
