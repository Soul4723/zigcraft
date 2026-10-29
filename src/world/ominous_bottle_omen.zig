const std = @import("std");

pub const TICKS_PER_SECOND: u32 = 20;
pub const BOTTLE_DRINK_TICKS: u32 = 32;
pub const BAD_OMEN_DURATION_TICKS: u32 = 120_000;
pub const RAID_OMEN_DURATION_TICKS: u32 = 600;
pub const VILLAGE_RADIUS: f32 = 32.0;
pub const TRIAL_OMEN_RADIUS: f32 = 14.0;

pub const OminousBottleTier = enum(u8) { tier_1 = 1, tier_2 = 2, tier_3 = 3, tier_4 = 4, tier_5 = 5 };
pub const OmenKind = enum { idle, bad_omen, raid_omen, trial_omen };
pub const SoundCue = enum { none, raid_horn, ominous_chime };

pub fn amplifierForTier(tier: OminousBottleTier) u8 {
    return @intFromEnum(tier) - 1;
}

pub const DrinkEvent = struct {
    bottle_consumed: bool = false,
    glass_break_particles: bool = false,
    bad_omen_applied: bool = false,
};

pub const OminousBottleDrink = struct {
    tier: OminousBottleTier,
    ticks_remaining: u32 = BOTTLE_DRINK_TICKS,
    completed: bool = false,

    pub fn tick(self: *OminousBottleDrink, omen: *PlayerOmen) DrinkEvent {
        if (self.completed) return .{};
        if (self.ticks_remaining > 0) self.ticks_remaining -= 1;
        if (self.ticks_remaining != 0) return .{};
        self.completed = true;
        omen.applyBadOmen(amplifierForTier(self.tier), BAD_OMEN_DURATION_TICKS);
        return .{ .bottle_consumed = true, .glass_break_particles = true, .bad_omen_applied = true };
    }
};

pub const Proximity = struct {
    village_distance: ?f32 = null,
    trial_distance: ?f32 = null,
};

pub const TickEvent = struct {
    kind: OmenKind = .idle,
    red_black_head_particles: bool = false,
    ominous_flame_burst: bool = false,
    sound: SoundCue = .none,
    raid_started: bool = false,
    raid_waves_started: bool = false,
    raid_cancelled: bool = false,
};

/// Per-player status state. Call tick once per game tick and pass distances to
/// the nearest village marker and trial chamber/spawner when available.
pub const PlayerOmen = struct {
    kind: OmenKind = .idle,
    amplifier: u8 = 0,
    ticks_remaining: u32 = 0,
    is_transmuted: bool = false,

    pub fn applyBadOmen(self: *PlayerOmen, amplifier: u8, duration: u32) void {
        self.kind = .bad_omen;
        self.amplifier = @min(amplifier, 4);
        self.ticks_remaining = duration;
        self.is_transmuted = false;
    }

    pub fn cleanseWithMilk(self: *PlayerOmen) void {
        self.* = .{};
    }

    pub fn tick(self: *PlayerOmen, proximity: Proximity) TickEvent {
        var event = TickEvent{};
        switch (self.kind) {
            .idle => {},
            .bad_omen => {
                if (proximity.trial_distance) |distance| {
                    if (distance <= TRIAL_OMEN_RADIUS) {
                        self.kind = .trial_omen;
                        self.is_transmuted = true;
                        event.ominous_flame_burst = true;
                        event.sound = .ominous_chime;
                    }
                }
                if (self.kind == .bad_omen) {
                    if (proximity.village_distance) |distance| {
                        if (distance <= VILLAGE_RADIUS) {
                            self.kind = .raid_omen;
                            self.ticks_remaining = RAID_OMEN_DURATION_TICKS;
                            event.raid_started = true;
                            event.sound = .raid_horn;
                        }
                    }
                }
                if (self.kind == .bad_omen) {
                    event.red_black_head_particles = true;
                    decrement(self);
                } else if (self.kind == .trial_omen) {
                    // Trial Omen inherits Bad Omen's remaining duration exactly.
                }
            },
            .raid_omen => {
                if (self.ticks_remaining == 1) event.raid_waves_started = true;
                decrement(self);
            },
            .trial_omen => {
                event.red_black_head_particles = true;
                decrement(self);
            },
        }
        if (self.kind == .idle) self.is_transmuted = false;
        event.kind = self.kind;
        return event;
    }

    /// Milk is checked before ordinary tick processing, so it cancels even a
    /// final-tick Raid Omen countdown.
    pub fn tickWithMilk(self: *PlayerOmen, proximity: Proximity, drank_milk: bool) TickEvent {
        if (!drank_milk) return self.tick(proximity);
        const cancelled = self.kind == .raid_omen;
        self.cleanseWithMilk();
        return .{ .kind = .idle, .raid_cancelled = cancelled };
    }

    pub fn shouldOminousTrialSpawner(self: PlayerOmen, player_distance: f32) bool {
        return self.kind == .trial_omen and self.is_transmuted and player_distance <= TRIAL_OMEN_RADIUS;
    }
};

fn decrement(self: *PlayerOmen) void {
    if (self.ticks_remaining > 0) self.ticks_remaining -= 1;
    if (self.ticks_remaining == 0) self.cleanseWithMilk();
}

// Distance helper for world integrations that have positions rather than ranges.
pub fn distance3(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

// Keep this helper public for integrations that enumerate a neighborhood of spawners.
pub fn spawnerReceivesOminousTrial(omen: PlayerOmen, player: [3]f32, spawner: [3]f32) bool {
    return omen.shouldOminousTrialSpawner(distance3(player, spawner));
}

test "bottle tiers map to amplifiers zero through four" {
    try std.testing.expectEqual(@as(u8, 0), amplifierForTier(.tier_1));
    try std.testing.expectEqual(@as(u8, 1), amplifierForTier(.tier_2));
    try std.testing.expectEqual(@as(u8, 2), amplifierForTier(.tier_3));
    try std.testing.expectEqual(@as(u8, 3), amplifierForTier(.tier_4));
    try std.testing.expectEqual(@as(u8, 4), amplifierForTier(.tier_5));
}

test "bottle takes exactly 32 ticks to drink" {
    var drink = OminousBottleDrink{ .tier = .tier_1 };
    var omen = PlayerOmen{};
    for (0..31) |_| try std.testing.expect(!drink.tick(&omen).bottle_consumed);
    try std.testing.expectEqual(@as(u32, 1), drink.ticks_remaining);
    try std.testing.expect(drink.tick(&omen).bottle_consumed);
}

test "bottle completion consumes glass and applies tier amplifier" {
    var drink = OminousBottleDrink{ .tier = .tier_5 };
    var omen = PlayerOmen{};
    for (0..32) |_| _ = drink.tick(&omen);
    try std.testing.expectEqual(OmenKind.bad_omen, omen.kind);
    try std.testing.expectEqual(@as(u8, 4), omen.amplifier);
    try std.testing.expectEqual(BAD_OMEN_DURATION_TICKS, omen.ticks_remaining);
}

test "completed bottle cannot be consumed twice" {
    var drink = OminousBottleDrink{ .tier = .tier_1 };
    var omen = PlayerOmen{};
    for (0..32) |_| _ = drink.tick(&omen);
    try std.testing.expect(!drink.tick(&omen).bottle_consumed);
}

test "bad omen begins with 100 minute duration" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, BAD_OMEN_DURATION_TICKS);
    try std.testing.expectEqual(@as(u32, 120_000), omen.ticks_remaining);
}

test "bad omen duration decays one game tick at a time" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(2, BAD_OMEN_DURATION_TICKS);
    _ = omen.tick(.{});
    try std.testing.expectEqual(@as(u32, 119_999), omen.ticks_remaining);
}

test "bad omen expires to idle at zero" {
    var omen = PlayerOmen{ .kind = .bad_omen, .ticks_remaining = 1, .amplifier = 3 };
    const event = omen.tick(.{});
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
    try std.testing.expect(event.red_black_head_particles);
}

test "bad omen emits red black head particles" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, 10);
    try std.testing.expect(omen.tick(.{}).red_black_head_particles);
}

test "bad omen does not trigger raid outside 32 meters" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, 10);
    _ = omen.tick(.{ .village_distance = 32.01 });
    try std.testing.expectEqual(OmenKind.bad_omen, omen.kind);
}

test "village boundary triggers raid omen at 32 meters" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(1, 1000);
    const event = omen.tick(.{ .village_distance = 32.0 });
    try std.testing.expect(event.raid_started);
    try std.testing.expectEqual(SoundCue.raid_horn, event.sound);
    try std.testing.expectEqual(OmenKind.raid_omen, omen.kind);
    try std.testing.expectEqual(@as(u32, 600), omen.ticks_remaining);
}

test "raid countdown decays for 30 seconds" {
    var omen = PlayerOmen{ .kind = .raid_omen, .ticks_remaining = RAID_OMEN_DURATION_TICKS };
    for (0..599) |_| _ = omen.tick(.{});
    try std.testing.expectEqual(@as(u32, 1), omen.ticks_remaining);
    const event = omen.tick(.{});
    try std.testing.expect(event.raid_waves_started);
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
}

test "milk cancels raid countdown" {
    var omen = PlayerOmen{ .kind = .raid_omen, .ticks_remaining = 1 };
    const event = omen.tickWithMilk(.{}, true);
    try std.testing.expect(event.raid_cancelled);
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
}

test "milk does not report raid cancellation when no raid is pending" {
    var omen = PlayerOmen{};
    try std.testing.expect(!omen.tickWithMilk(.{}, true).raid_cancelled);
}

test "trial proximity transmutates at 14 meters" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(3, 9000);
    const event = omen.tick(.{ .trial_distance = 14.0 });
    try std.testing.expectEqual(OmenKind.trial_omen, omen.kind);
    try std.testing.expect(omen.is_transmuted);
    try std.testing.expect(event.ominous_flame_burst);
    try std.testing.expectEqual(SoundCue.ominous_chime, event.sound);
}

test "trial transmutation inherits remaining duration and amplifier" {
    var omen = PlayerOmen{ .kind = .bad_omen, .amplifier = 4, .ticks_remaining = 4321 };
    _ = omen.tick(.{ .trial_distance = 13.9 });
    try std.testing.expectEqual(@as(u32, 4321), omen.ticks_remaining);
    try std.testing.expectEqual(@as(u8, 4), omen.amplifier);
}

test "trial transmutation does not occur outside 14 meters" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, 10);
    _ = omen.tick(.{ .trial_distance = 14.01 });
    try std.testing.expectEqual(OmenKind.bad_omen, omen.kind);
}

test "trial omen keeps inherited duration ticking" {
    var omen = PlayerOmen{ .kind = .trial_omen, .amplifier = 2, .ticks_remaining = 8, .is_transmuted = true };
    _ = omen.tick(.{});
    try std.testing.expectEqual(@as(u32, 7), omen.ticks_remaining);
}

test "trial aura triggers nearby spawner transformation" {
    const omen = PlayerOmen{ .kind = .trial_omen, .amplifier = 1, .ticks_remaining = 50, .is_transmuted = true };
    try std.testing.expect(spawnerReceivesOminousTrial(omen, .{ 0, 0, 0 }, .{ 14, 0, 0 }));
    try std.testing.expect(!spawnerReceivesOminousTrial(omen, .{ 0, 0, 0 }, .{ 14.1, 0, 0 }));
}

test "bad omen does not make spawners ominous before transmutation" {
    const omen = PlayerOmen{ .kind = .bad_omen, .ticks_remaining = 50 };
    try std.testing.expect(!spawnerReceivesOminousTrial(omen, .{ 0, 0, 0 }, .{ 1, 0, 0 }));
}

test "milk clears bad omen, raid omen, and trial omen" {
    const kinds = [_]OmenKind{ .bad_omen, .raid_omen, .trial_omen };
    for (kinds) |kind| {
        var omen = PlayerOmen{ .kind = kind, .amplifier = 4, .ticks_remaining = 50, .is_transmuted = kind == .trial_omen };
        omen.cleanseWithMilk();
        try std.testing.expectEqual(OmenKind.idle, omen.kind);
        try std.testing.expectEqual(@as(u32, 0), omen.ticks_remaining);
        try std.testing.expectEqual(@as(u8, 0), omen.amplifier);
        try std.testing.expect(!omen.is_transmuted);
    }
}

test "milk tick prevents proximity triggers" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(0, 10);
    const event = omen.tickWithMilk(.{ .village_distance = 1, .trial_distance = 1 }, true);
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
    try std.testing.expect(!event.raid_started);
    try std.testing.expect(!event.ominous_flame_burst);
}

test "trial chamber takes precedence over nearby village" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(2, 500);
    const event = omen.tick(.{ .village_distance = 1, .trial_distance = 1 });
    try std.testing.expectEqual(OmenKind.trial_omen, omen.kind);
    try std.testing.expect(!event.raid_started);
}

test "bad omen amplifier is clamped to bottle maximum" {
    var omen = PlayerOmen{};
    omen.applyBadOmen(99, 10);
    try std.testing.expectEqual(@as(u8, 4), omen.amplifier);
}

test "distance helper measures three dimensional range" {
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), distance3(.{ 0, 0, 0 }, .{ 3, 4, 0 }), 0.0001);
}

test "raid omen preserves amplifier while counting down" {
    var omen = PlayerOmen{ .kind = .raid_omen, .amplifier = 3, .ticks_remaining = 20 };
    _ = omen.tick(.{});
    try std.testing.expectEqual(@as(u8, 3), omen.amplifier);
}

test "cleansed player remains idle without effects" {
    var omen = PlayerOmen{ .kind = .trial_omen, .ticks_remaining = 3, .is_transmuted = true };
    _ = omen.tickWithMilk(.{}, true);
    _ = omen.tick(.{});
    try std.testing.expectEqual(OmenKind.idle, omen.kind);
}
