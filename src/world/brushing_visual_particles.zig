const std = @import("std");

pub const EXCAVATION_TICKS_PER_STAGE: u16 = 24;
pub const TOTAL_EXCAVATION_TICKS: u16 = 96;
pub const MAX_PARTICLES: usize = 32;
pub const INTERRUPTION_DECAY_PER_TICK: f32 = 0.25;
pub const PARTICLE_FADE_PER_TICK: f32 = 0.12;

pub const ExcavationStage = enum(u8) {
    idle = 0,
    stage_1 = 1,
    stage_2 = 2,
    stage_3 = 3,
    stage_4 = 4,

    pub fn progressPercent(self: ExcavationStage) u8 {
        return @as(u8, @intFromEnum(self)) * 25;
    }

    pub fn pitch(self: ExcavationStage) f32 {
        return switch (self) {
            .idle => 0.0,
            .stage_1 => 0.8,
            .stage_2 => 1.0,
            .stage_3 => 1.2,
            .stage_4 => 1.4,
        };
    }

    pub fn particleCountRange(self: ExcavationStage) [2]u8 {
        return switch (self) {
            .idle => .{ 0, 0 },
            .stage_1 => .{ 4, 6 },
            .stage_2 => .{ 8, 12 },
            .stage_3 => .{ 16, 24 },
            .stage_4 => .{ 32, 32 },
        };
    }
};

pub fn stageFromProgress(progress_ticks: f32) ExcavationStage {
    if (progress_ticks >= @as(f32, TOTAL_EXCAVATION_TICKS)) return .stage_4;
    if (progress_ticks >= 72.0) return .stage_3;
    if (progress_ticks >= 48.0) return .stage_2;
    if (progress_ticks >= 24.0) return .stage_1;
    return .idle;
}

pub const ParticleType = enum(u8) {
    dust_plume,
    medium_dust_cloud,
    heavy_particulate,
    relic_sparkle,
};

pub const Particle = struct {
    particle_type: ParticleType,
    position: [3]f32,
    velocity: [3]f32,
    lifetime_ticks: u8,
    age_ticks: u8 = 0,
    alpha: f32 = 1.0,
    scale: f32,
    shows_item_edge: bool = false,
    golden: bool = false,

    pub fn isAlive(self: Particle) bool {
        return self.age_ticks < self.lifetime_ticks and self.alpha > 0.0;
    }
};

pub const ParticleBurst = struct {
    particles: [MAX_PARTICLES]Particle = undefined,
    count: u8 = 0,

    pub fn slice(self: *const ParticleBurst) []const Particle {
        return self.particles[0..self.count];
    }
};

fn mixSeed(seed: u32) u32 {
    var value = seed;
    value ^= value >> 16;
    value *%= 0x7feb352d;
    value ^= value >> 15;
    value *%= 0x846ca68b;
    value ^= value >> 16;
    return value;
}

fn randomUnit(seed: u32) f32 {
    return @as(f32, @floatFromInt(mixSeed(seed) & 0x00ffffff)) / 16777215.0;
}

/// Builds a deterministic burst so the simulation and tests do not need a global RNG.
pub fn makeBurst(stage: ExcavationStage, origin: [3]f32, seed: u32) ParticleBurst {
    var result = ParticleBurst{};
    if (stage == .idle) return result;

    const range = stage.particleCountRange();
    const count: usize = @as(usize, range[0]) + @as(usize, mixSeed(seed) % (@as(u32, range[1] - range[0]) + 1));
    result.count = @intCast(count);
    for (0..count) |index| {
        const i: u32 = @intCast(index);
        const theta = randomUnit(seed +% i *% 3) * 6.2831855;
        const outward = 0.025 + randomUnit(seed +% i *% 3 +% 1) * 0.09;
        const upward_scale: f32 = switch (stage) {
            .idle => 0.0,
            .stage_1 => 0.055,
            .stage_2 => 0.09,
            .stage_3 => 0.13,
            .stage_4 => 0.17,
        };
        const upward = 0.025 + randomUnit(seed +% i *% 3 +% 2) * upward_scale;
        const golden = stage == .stage_4 and index % 4 == 0;
        result.particles[index] = .{
            .particle_type = if (golden) .relic_sparkle else switch (stage) {
                .idle => unreachable,
                .stage_1 => .dust_plume,
                .stage_2 => .medium_dust_cloud,
                .stage_3, .stage_4 => .heavy_particulate,
            },
            .position = origin,
            .velocity = .{ @cos(theta) * outward, upward, @sin(theta) * outward },
            .lifetime_ticks = switch (stage) {
                .idle => 1,
                .stage_1 => 18,
                .stage_2 => 28,
                .stage_3 => 36,
                .stage_4 => 44,
            },
            .scale = switch (stage) {
                .idle => 0.0,
                .stage_1 => 0.35 + randomUnit(seed +% i +% 11) * 0.25,
                .stage_2 => 0.65 + randomUnit(seed +% i +% 11) * 0.45,
                .stage_3 => 0.8 + randomUnit(seed +% i +% 11) * 0.7,
                .stage_4 => if (golden) 0.3 else 1.0 + randomUnit(seed +% i +% 11) * 0.9,
            },
            .shows_item_edge = stage == .stage_3 or stage == .stage_4,
            .golden = golden,
        };
    }
    return result;
}

pub const Hand = enum(u1) { main, off };
pub const HeldItem = enum { empty, brush, other };

pub const Hands = struct {
    main: HeldItem = .empty,
    off: HeldItem = .empty,

    pub fn brushHand(self: Hands) ?Hand {
        if (self.main == .brush) return .main;
        if (self.off == .brush) return .off;
        return null;
    }

    pub fn isSynchronized(self: Hands) bool {
        return self.main == .brush and self.off == .brush;
    }
};

pub const AudioEvent = struct {
    brushing_pitch: f32 = 0.0,
    play_brush_loop: bool = false,
    play_completion_chime: bool = false,
};

pub const TickResult = struct {
    stage: ExcavationStage,
    brush_hand: ?Hand,
    synchronized: bool,
    audio: AudioEvent,
    emitted_burst: ?ParticleBurst = null,
};

/// Progress and interruption state for one suspicious block's visual presentation.
pub const BrushingVisualState = struct {
    progress_ticks: f32 = 0.0,
    previous_stage: ExcavationStage = .idle,
    plume_alpha: f32 = 0.0,
    completion_chime_played: bool = false,
    burst_serial: u32 = 0,

    pub fn stage(self: BrushingVisualState) ExcavationStage {
        return stageFromProgress(self.progress_ticks);
    }

    pub fn tick(self: *BrushingVisualState, hands: Hands, origin: [3]f32) TickResult {
        const hand = hands.brushHand();
        const old_stage = self.stage();
        if (hand != null) {
            self.progress_ticks = @min(self.progress_ticks + 1.0, @as(f32, TOTAL_EXCAVATION_TICKS));
            self.plume_alpha = @min(self.plume_alpha + 0.25, 1.0);
        } else {
            self.progress_ticks = @max(self.progress_ticks - INTERRUPTION_DECAY_PER_TICK, 0.0);
            self.plume_alpha = @max(self.plume_alpha - PARTICLE_FADE_PER_TICK, 0.0);
        }

        const current_stage = self.stage();
        const completed_now = old_stage != .stage_4 and current_stage == .stage_4;
        const stage_changed = current_stage != self.previous_stage;
        var result = TickResult{
            .stage = current_stage,
            .brush_hand = hand,
            .synchronized = hands.isSynchronized(),
            .audio = .{
                .brushing_pitch = current_stage.pitch(),
                .play_brush_loop = hand != null and current_stage != .idle and current_stage != .stage_4,
                .play_completion_chime = completed_now and !self.completion_chime_played,
            },
        };
        if (stage_changed and current_stage != .idle) {
            self.burst_serial +%= 1;
            result.emitted_burst = makeBurst(current_stage, origin, self.burst_serial);
        }
        if (completed_now) self.completion_chime_played = true;
        if (current_stage != .stage_4) self.completion_chime_played = false;
        self.previous_stage = current_stage;
        return result;
    }

    pub fn particleAlpha(self: BrushingVisualState, particle: Particle) f32 {
        return @max(particle.alpha * self.plume_alpha, 0.0);
    }
};

// Focused behavior tests: individual assertions keep stage boundaries and transitions explicit.
test "stage 1 emits 4 to 6 light dust puffs" {
    const burst = makeBurst(.stage_1, .{ 0, 0, 0 }, 12);
    try std.testing.expect(burst.count >= 4 and burst.count <= 6);
    for (burst.slice()) |particle| try std.testing.expectEqual(ParticleType.dust_plume, particle.particle_type);
}

test "stage 2 emits 8 to 12 medium clouds" {
    const burst = makeBurst(.stage_2, .{ 0, 0, 0 }, 4);
    try std.testing.expect(burst.count >= 8 and burst.count <= 12);
    for (burst.slice()) |particle| try std.testing.expectEqual(ParticleType.medium_dust_cloud, particle.particle_type);
}

test "stage 3 emits 16 to 24 heavy particles" {
    const burst = makeBurst(.stage_3, .{ 0, 0, 0 }, 9);
    try std.testing.expect(burst.count >= 16 and burst.count <= 24);
    for (burst.slice()) |particle| try std.testing.expectEqual(ParticleType.heavy_particulate, particle.particle_type);
}

test "stage 4 emits a dense 32 particle burst" {
    try std.testing.expectEqual(@as(u8, 32), makeBurst(.stage_4, .{ 0, 0, 0 }, 2).count);
}

test "stage 1 particles are dust plumes" {
    try std.testing.expectEqual(ParticleType.dust_plume, makeBurst(.stage_1, .{ 0, 0, 0 }, 1).particles[0].particle_type);
}

test "stage 2 particles are medium dust clouds" {
    try std.testing.expectEqual(ParticleType.medium_dust_cloud, makeBurst(.stage_2, .{ 0, 0, 0 }, 1).particles[0].particle_type);
}

test "stage 3 particles expose item edges" {
    for (makeBurst(.stage_3, .{ 0, 0, 0 }, 1).slice()) |particle| try std.testing.expect(particle.shows_item_edge);
}

test "stage 4 particles expose item edges" {
    for (makeBurst(.stage_4, .{ 0, 0, 0 }, 1).slice()) |particle| try std.testing.expect(particle.shows_item_edge);
}

test "stage 4 includes golden relic sparkles" {
    var golden_count: usize = 0;
    for (makeBurst(.stage_4, .{ 0, 0, 0 }, 1).slice()) |particle| {
        if (particle.golden) {
            golden_count += 1;
            try std.testing.expectEqual(ParticleType.relic_sparkle, particle.particle_type);
        }
    }
    try std.testing.expect(golden_count >= 8);
}

test "stage 4 sparkles use golden particle color flag" {
    const burst = makeBurst(.stage_4, .{ 0, 0, 0 }, 5);
    try std.testing.expect(burst.particles[0].golden);
}

test "idle stage emits no particles" {
    try std.testing.expectEqual(@as(u8, 0), makeBurst(.idle, .{ 0, 0, 0 }, 0).count);
}

test "progress maps to idle before first quarter" {
    try std.testing.expectEqual(ExcavationStage.idle, stageFromProgress(23.99));
}

test "progress maps to stage 1 at quarter" {
    try std.testing.expectEqual(ExcavationStage.stage_1, stageFromProgress(24));
}

test "progress maps to stage 2 at half" {
    try std.testing.expectEqual(ExcavationStage.stage_2, stageFromProgress(48));
}

test "progress maps to stage 3 at three quarters" {
    try std.testing.expectEqual(ExcavationStage.stage_3, stageFromProgress(72));
}

test "progress maps to stage 4 at completion" {
    try std.testing.expectEqual(ExcavationStage.stage_4, stageFromProgress(96));
}

test "stage 1 brushing pitch is 0.8" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), ExcavationStage.stage_1.pitch(), 0.001);
}

test "stage 2 brushing pitch is 1.0" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ExcavationStage.stage_2.pitch(), 0.001);
}

test "stage 3 brushing pitch is 1.2" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), ExcavationStage.stage_3.pitch(), 0.001);
}

test "stage 4 brushing pitch is 1.4" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.4), ExcavationStage.stage_4.pitch(), 0.001);
}

test "main hand brush is accepted" {
    try std.testing.expectEqual(Hand.main, (Hands{ .main = .brush }).brushHand().?);
}

test "off hand brush is accepted" {
    try std.testing.expectEqual(Hand.off, (Hands{ .off = .brush }).brushHand().?);
}

test "non-brush hands do not activate brushing" {
    try std.testing.expectEqual(@as(?Hand, null), (Hands{ .main = .other, .off = .empty }).brushHand());
}

test "main hand is selected when both hands hold brushes" {
    try std.testing.expectEqual(Hand.main, (Hands{ .main = .brush, .off = .brush }).brushHand().?);
}

test "dual brush use reports synchronized brushing" {
    var state = BrushingVisualState{};
    const result = state.tick(.{ .main = .brush, .off = .brush }, .{ 0, 0, 0 });
    try std.testing.expect(result.synchronized);
}

test "release regresses excavation progress smoothly" {
    var state = BrushingVisualState{ .progress_ticks = 48.0 };
    _ = state.tick(.{}, .{ 0, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 47.75), state.progress_ticks, 0.001);
}

test "interruption takes four ticks to regress one excavation tick" {
    var state = BrushingVisualState{ .progress_ticks = 60.0 };
    for (0..4) |_| _ = state.tick(.{}, .{ 0, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 59.0), state.progress_ticks, 0.001);
}

test "interruption decays plume alpha" {
    var state = BrushingVisualState{ .plume_alpha = 1.0 };
    _ = state.tick(.{}, .{ 0, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 0.88), state.plume_alpha, 0.001);
}

test "plume alpha reaches zero after sufficient release ticks" {
    var state = BrushingVisualState{ .plume_alpha = 1.0 };
    for (0..9) |_| _ = state.tick(.{}, .{ 0, 0, 0 });
    try std.testing.expectEqual(@as(f32, 0.0), state.plume_alpha);
}

test "particle fade is scaled by plume alpha" {
    const state = BrushingVisualState{ .plume_alpha = 0.5 };
    const particle = Particle{ .particle_type = .dust_plume, .position = .{ 0, 0, 0 }, .velocity = .{ 0, 0, 0 }, .lifetime_ticks = 10, .scale = 1.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), state.particleAlpha(particle), 0.001);
}

test "tick emits stage burst on crossing stage 1" {
    var state = BrushingVisualState{ .progress_ticks = 23.0 };
    const result = state.tick(.{ .main = .brush }, .{ 1, 2, 3 });
    try std.testing.expect(result.emitted_burst != null);
    try std.testing.expectEqual(ExcavationStage.stage_1, result.stage);
}

test "tick does not emit repeated burst while stage remains unchanged" {
    var state = BrushingVisualState{ .progress_ticks = 30.0, .previous_stage = .stage_1 };
    const result = state.tick(.{ .main = .brush }, .{ 0, 0, 0 });
    try std.testing.expect(result.emitted_burst == null);
}

test "brushing tick reports the active hand" {
    var state = BrushingVisualState{};
    const result = state.tick(.{ .off = .brush }, .{ 0, 0, 0 });
    try std.testing.expectEqual(Hand.off, result.brush_hand.?);
}

test "completion tick plays the relic chime once" {
    var state = BrushingVisualState{ .progress_ticks = 95.0 };
    const result = state.tick(.{ .main = .brush }, .{ 0, 0, 0 });
    try std.testing.expect(result.audio.play_completion_chime);
}

test "completion chime does not repeat while holding at completion" {
    var state = BrushingVisualState{ .progress_ticks = 95.0 };
    _ = state.tick(.{ .main = .brush }, .{ 0, 0, 0 });
    const result = state.tick(.{ .main = .brush }, .{ 0, 0, 0 });
    try std.testing.expect(!result.audio.play_completion_chime);
}

test "brushing loop is active during incomplete excavation" {
    var state = BrushingVisualState{ .progress_ticks = 40.0 };
    try std.testing.expect(state.tick(.{ .main = .brush }, .{ 0, 0, 0 }).audio.play_brush_loop);
}

test "released brush disables brushing loop" {
    var state = BrushingVisualState{ .progress_ticks = 40.0 };
    try std.testing.expect(!state.tick(.{}, .{ 0, 0, 0 }).audio.play_brush_loop);
}

test "particle burst generation is deterministic" {
    const first = makeBurst(.stage_3, .{ 2, 3, 4 }, 1234);
    const second = makeBurst(.stage_3, .{ 2, 3, 4 }, 1234);
    try std.testing.expectEqual(first.count, second.count);
    try std.testing.expectEqual(first.particles[0].velocity, second.particles[0].velocity);
}
