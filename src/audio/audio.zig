const std = @import("std");
pub const synth = @import("synth.zig");

const c = @cImport({
    @cInclude("alsa/asoundlib.h");
});

pub const AudioSystem = struct {
    pcm_handle: ?*c.snd_pcm_t,
    mixer: synth.AudioMixer,
    enabled: bool,
    buffer: [1024]i16,

    pub fn init() AudioSystem {
        var sys = AudioSystem{
            .pcm_handle = null,
            .mixer = synth.AudioMixer.init(),
            .enabled = false,
            .buffer = undefined,
        };

        var handle: ?*c.snd_pcm_t = null;
        // Try opening default ALSA playback device in non-blocking mode
        const err = c.snd_pcm_open(&handle, "default", c.SND_PCM_STREAM_PLAYBACK, c.SND_PCM_NONBLOCK);
        if (err < 0) {
            std.debug.print("Audio: ALSA open failed ({s}), sound disabled\n", .{c.snd_strerror(err)});
            return sys;
        }

        // Configure simple hardware parameters: 44100 Hz, 1 channel (mono), 16-bit signed little-endian, low latency
        const set_params = c.snd_pcm_set_params(
            handle,
            c.SND_PCM_FORMAT_S16_LE,
            c.SND_PCM_ACCESS_RW_INTERLEAVED,
            1, // mono
            synth.SAMPLE_RATE,
            1, // soft resample allow
            50000, // 50ms latency
        );

        if (set_params < 0) {
            std.debug.print("Audio: ALSA set_params failed ({s}), sound disabled\n", .{c.snd_strerror(set_params)});
            _ = c.snd_pcm_close(handle);
            return sys;
        }

        sys.pcm_handle = handle;
        sys.enabled = true;
        std.debug.print("Audio: ALSA backend initialized (44100Hz mono)\n", .{});
        return sys;
    }

    pub fn deinit(self: *AudioSystem) void {
        if (self.pcm_handle) |handle| {
            _ = c.snd_pcm_drain(handle);
            _ = c.snd_pcm_close(handle);
            self.pcm_handle = null;
        }
        self.enabled = false;
    }

    pub fn play(self: *AudioSystem, sound: synth.SoundType, volume: f32) void {
        self.mixer.play(sound, volume);
    }

    pub fn update(self: *AudioSystem) void {
        if (!self.enabled or self.pcm_handle == null) return;

        // Check how many frames can be written without blocking
        const avail = c.snd_pcm_avail_update(self.pcm_handle);
        if (avail < 0) {
            // Buffer underrun / overrun or suspend recovery
            _ = c.snd_pcm_recover(self.pcm_handle, @intCast(avail), 1);
            return;
        }

        if (avail > 0) {
            const frames_to_write = @min(@as(usize, @intCast(avail)), self.buffer.len);
            if (frames_to_write > 0) {
                self.mixer.render(self.buffer[0..frames_to_write]);
                const written = c.snd_pcm_writei(self.pcm_handle, self.buffer[0..frames_to_write].ptr, @intCast(frames_to_write));
                if (written < 0) {
                    _ = c.snd_pcm_recover(self.pcm_handle, @intCast(written), 1);
                }
            }
        }
    }
};

test "AudioSystem struct can be instantiated safely with mock or real device" {
    var sys = AudioSystem{
        .pcm_handle = null,
        .mixer = synth.AudioMixer.init(),
        .enabled = false,
        .buffer = undefined,
    };
    defer sys.deinit();

    sys.play(.step_grass, 0.5);
    sys.update();
    try std.testing.expect(!sys.enabled);
}
