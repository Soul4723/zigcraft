const std = @import("std");
const jukebox_discs = @import("jukebox_discs.zig");

pub const JUKEBOX_RANGE_SQ: f32 = 256.0;
pub const DUPLICATION_COOLDOWN_TICKS: u32 = 6_000;
pub const ALLAY_MAX_HEALTH: f32 = 20.0;
pub const ALLAY_REGEN_HP_PER_SECOND: f32 = 2.0;
pub const ALLAY_REGEN_HP_PER_TICK: f32 = 0.1;
pub const ITEM_DELIVERY_RANGE: f32 = 32.0;
pub const NOTE_BLOCK_RANGE: f32 = 16.0;

pub const AllayState = enum { idle_floating, holding_item, dancing_to_music, duplicating, cooldown };
pub const DuplicateResult = enum { success, not_dancing, on_cooldown, no_amethyst_shard };
pub const ItemType = enum { amethyst_shard, other };
pub const MusicDisc = jukebox_discs.MusicDisc;

pub const ItemStack = struct {
    item: ItemType = .other,
    count: u16 = 0,
};

pub const JukeboxSignal = struct {
    pos: [3]f32,
    active: bool = true,
    playing_disc: ?MusicDisc = null,
};

pub const NoteParticle = struct {
    pos: [3]f32,
    disc: MusicDisc,
    pitch_hz: f32,
};

pub const DanceTick = struct {
    dancing: bool = false,
    entered_dancing: bool = false,
    left_dancing: bool = false,
    note_particle: ?NoteParticle = null,
    spin_radians: f32 = 0.0,
    sway_radians: f32 = 0.0,
};

pub const Allay = struct {
    pos: [3]f32 = .{ 0.0, 0.0, 0.0 },
    state: AllayState = .idle_floating,
    health: f32 = ALLAY_MAX_HEALTH,
    duplication_cooldown_ticks: u32 = 0,
    bound_item_type: ?ItemType = null,
    bound_item_count: u16 = 0,
    tamed_player_id: ?u64 = null,
    spin_radians: f32 = 0.0,
    sway_phase: f32 = 0.0,
    is_dancing: bool = false,

    pub fn init(pos: [3]f32) Allay {
        return .{ .pos = pos };
    }

    /// Advances one game tick, updating dance state, cooldown, and natural healing.
    pub fn tick(self: *Allay, jukebox: ?JukeboxSignal) DanceTick {
        self.tickCooldown();
        self.regenerateOneTick();
        const was_dancing = self.is_dancing;
        const signal = jukebox orelse {
            self.is_dancing = false;
            self.refreshIdleState();
            return .{ .left_dancing = was_dancing };
        };
        const disc = signal.playing_disc orelse {
            self.is_dancing = false;
            self.refreshIdleState();
            return .{ .left_dancing = was_dancing };
        };
        if (!signal.active or distanceSq(self.pos, signal.pos) > JUKEBOX_RANGE_SQ) {
            self.is_dancing = false;
            self.refreshIdleState();
            return .{ .left_dancing = was_dancing };
        }

        self.is_dancing = true;
        self.state = .dancing_to_music;
        self.spin_radians = @mod(self.spin_radians + 0.35, 2.0 * std.math.pi);
        self.sway_phase = @mod(self.sway_phase + 0.22, 2.0 * std.math.pi);
        return .{
            .dancing = true,
            .entered_dancing = !was_dancing,
            .note_particle = .{ .pos = self.pos, .disc = disc, .pitch_hz = disc.rootNoteHz() },
            .spin_radians = self.spin_radians,
            .sway_radians = @sin(self.sway_phase) * 0.25,
        };
    }

    pub fn tickCooldown(self: *Allay) void {
        if (self.duplication_cooldown_ticks > 0) self.duplication_cooldown_ticks -= 1;
        if (!self.is_dancing) self.refreshIdleState();
    }

    pub fn regenerateOneTick(self: *Allay) void {
        self.health = @min(ALLAY_MAX_HEALTH, self.health + ALLAY_REGEN_HP_PER_TICK);
    }

    pub fn regenerateSeconds(self: *Allay, seconds: f32) void {
        if (seconds <= 0.0) return;
        self.health = @min(ALLAY_MAX_HEALTH, self.health + ALLAY_REGEN_HP_PER_SECOND * seconds);
    }

    pub fn bindItem(self: *Allay, stack: ItemStack) bool {
        if (stack.count == 0) return false;
        self.bound_item_type = stack.item;
        self.bound_item_count = stack.count;
        self.refreshIdleState();
        return true;
    }

    pub fn clearBoundItem(self: *Allay) void {
        self.bound_item_type = null;
        self.bound_item_count = 0;
        self.refreshIdleState();
    }

    /// Checks item-delivery reach toward the favorite player, within 32 blocks.
    pub fn canSearchForDelivery(self: Allay, player_id: u64, player_pos: [3]f32) bool {
        if (self.tamed_player_id == null or self.tamed_player_id.? != player_id) return false;
        return distanceSq(self.pos, player_pos) <= ITEM_DELIVERY_RANGE * ITEM_DELIVERY_RANGE;
    }

    /// Finds an active Note Block near the Allay and within delivery reach of its favorite player.
    pub fn findNoteBlockDelivery(self: Allay, player_id: u64, player_pos: [3]f32, blocks: []const NoteBlockTarget) ?usize {
        if (!self.canSearchForDelivery(player_id, player_pos)) return null;
        for (blocks, 0..) |block, i| {
            if (!block.active) continue;
            if (distanceSq(self.pos, block.pos) > NOTE_BLOCK_RANGE * NOTE_BLOCK_RANGE) continue;
            if (distanceSq(player_pos, block.pos) > ITEM_DELIVERY_RANGE * ITEM_DELIVERY_RANGE) continue;
            return i;
        }
        return null;
    }

    fn refreshIdleState(self: *Allay) void {
        if (self.is_dancing) return;
        if (self.duplication_cooldown_ticks > 0) {
            self.state = .cooldown;
        } else if (self.bound_item_type != null and self.bound_item_count > 0) {
            self.state = .holding_item;
        } else {
            self.state = .idle_floating;
        }
    }
};

pub const NoteBlockTarget = struct { pos: [3]f32, active: bool = true };

pub const DuplicateOutcome = struct {
    result: DuplicateResult,
    shard_consumed: bool = false,
    amethyst_chime: bool = false,
    heart_particles: bool = false,
    child: ?Allay = null,
};

/// Feeds one shard to a dancing Allay. On success, both parent and child receive the full cooldown.
pub fn feedAmethystShard(parent: *Allay, offered: *ItemStack) DuplicateOutcome {
    if (parent.duplication_cooldown_ticks > 0) return .{ .result = .on_cooldown };
    if (offered.item != .amethyst_shard or offered.count == 0) return .{ .result = .no_amethyst_shard };
    if (!parent.is_dancing or parent.state != .dancing_to_music) return .{ .result = .not_dancing };

    offered.count -= 1;
    parent.duplication_cooldown_ticks = DUPLICATION_COOLDOWN_TICKS;
    parent.state = .duplicating;
    var child = Allay.init(parent.pos);
    child.duplication_cooldown_ticks = DUPLICATION_COOLDOWN_TICKS;
    child.state = .cooldown;
    return .{
        .result = .success,
        .shard_consumed = true,
        .amethyst_chime = true,
        .heart_particles = true,
        .child = child,
    };
}

pub fn distanceSq(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

pub fn isJukeboxInDanceRange(allay_pos: [3]f32, jukebox_pos: [3]f32) bool {
    return distanceSq(allay_pos, jukebox_pos) <= JUKEBOX_RANGE_SQ;
}

test "jukebox within sixteen meters triggers dancing and note particle" {
    var allay = Allay.init(.{ 0.0, 0.0, 0.0 });
    const event = allay.tick(.{ .pos = .{ 16.0, 0.0, 0.0 }, .playing_disc = .cat });
    try std.testing.expect(event.dancing and event.entered_dancing);
    try std.testing.expectEqual(AllayState.dancing_to_music, allay.state);
    try std.testing.expectEqual(MusicDisc.cat, event.note_particle.?.disc);
    try std.testing.expectEqual(MusicDisc.cat.rootNoteHz(), event.note_particle.?.pitch_hz);
}

test ">16 meter jukebox is ignored" {
    var allay = Allay.init(.{ 0.0, 0.0, 0.0 });
    const event = allay.tick(.{ .pos = .{ 16.01, 0.0, 0.0 }, .playing_disc = .cat });
    try std.testing.expect(!event.dancing);
    try std.testing.expectEqual(AllayState.idle_floating, allay.state);
}

test "diagonal jukebox range uses Euclidean distance" {
    try std.testing.expect(isJukeboxInDanceRange(.{ 0, 0, 0 }, .{ 8, 8, 8 }));
    try std.testing.expect(!isJukeboxInDanceRange(.{ 0, 0, 0 }, .{ 10, 10, 10 }));
}

test "stopped jukebox makes dancing Allay leave dance" {
    var allay = Allay.init(.{ 0, 0, 0 });
    _ = allay.tick(.{ .pos = .{ 1, 0, 0 }, .playing_disc = .pigstep });
    const event = allay.tick(.{ .pos = .{ 1, 0, 0 } });
    try std.testing.expect(event.left_dancing);
    try std.testing.expectEqual(AllayState.idle_floating, allay.state);
}

test "inactive jukebox ends dance" {
    var allay = Allay.init(.{ 0, 0, 0 });
    _ = allay.tick(.{ .pos = .{ 1, 0, 0 }, .playing_disc = .cat });
    const event = allay.tick(.{ .pos = .{ 1, 0, 0 }, .active = false, .playing_disc = .cat });
    try std.testing.expect(event.left_dancing);
}

test "moving out of jukebox range ends dance" {
    var allay = Allay.init(.{ 0, 0, 0 });
    _ = allay.tick(.{ .pos = .{ 1, 0, 0 }, .playing_disc = .cat });
    try std.testing.expect(allay.tick(.{ .pos = .{ 17, 0, 0 }, .playing_disc = .cat }).left_dancing);
}

test "disc pitch is carried by note particle" {
    var allay = Allay.init(.{ 0, 0, 0 });
    const event = allay.tick(.{ .pos = .{ 0, 1, 0 }, .playing_disc = .creator_music_box });
    try std.testing.expectEqual(@as(f32, 523.25), event.note_particle.?.pitch_hz);
}

test "dance advances spin and sway animation" {
    var allay = Allay.init(.{ 0, 0, 0 });
    const event = allay.tick(.{ .pos = .{ 0, 0, 0 }, .playing_disc = .blocks });
    try std.testing.expect(event.spin_radians > 0.0);
    try std.testing.expect(event.sway_radians > 0.0);
}

test "dancing Allay with shard duplicates and consumes one shard" {
    var parent = Allay.init(.{ 2, 3, 4 });
    _ = parent.tick(.{ .pos = .{ 2, 3, 4 }, .playing_disc = .cat });
    var shard = ItemStack{ .item = .amethyst_shard, .count = 2 };
    const outcome = feedAmethystShard(&parent, &shard);
    try std.testing.expectEqual(DuplicateResult.success, outcome.result);
    try std.testing.expectEqual(@as(u16, 1), shard.count);
    try std.testing.expect(outcome.shard_consumed and outcome.amethyst_chime and outcome.heart_particles);
    try std.testing.expect(outcome.child != null);
}

test "parent and child receive six thousand tick cooldown" {
    var parent = Allay.init(.{ 0, 0, 0 });
    _ = parent.tick(.{ .pos = .{ 0, 0, 0 }, .playing_disc = .cat });
    var shard = ItemStack{ .item = .amethyst_shard, .count = 1 };
    const result = feedAmethystShard(&parent, &shard);
    try std.testing.expectEqual(@as(u32, 6000), parent.duplication_cooldown_ticks);
    try std.testing.expectEqual(@as(u32, 6000), result.child.?.duplication_cooldown_ticks);
}

test "duplicate child begins in cooldown state" {
    var parent = Allay.init(.{ 0, 0, 0 });
    _ = parent.tick(.{ .pos = .{ 0, 0, 0 }, .playing_disc = .cat });
    var shard = ItemStack{ .item = .amethyst_shard, .count = 1 };
    try std.testing.expectEqual(AllayState.cooldown, feedAmethystShard(&parent, &shard).child.?.state);
}

test "parent duplication animation resolves on following tick" {
    var parent = Allay.init(.{ 0, 0, 0 });
    _ = parent.tick(.{ .pos = .{ 0, 0, 0 }, .playing_disc = .cat });
    var shard = ItemStack{ .item = .amethyst_shard, .count = 1 };
    _ = feedAmethystShard(&parent, &shard);
    try std.testing.expectEqual(AllayState.duplicating, parent.state);
    _ = parent.tick(null);
    try std.testing.expectEqual(AllayState.cooldown, parent.state);
}

test "shard offered when not dancing is retained" {
    var allay = Allay.init(.{ 0, 0, 0 });
    var shard = ItemStack{ .item = .amethyst_shard, .count = 3 };
    const result = feedAmethystShard(&allay, &shard);
    try std.testing.expectEqual(DuplicateResult.not_dancing, result.result);
    try std.testing.expectEqual(@as(u16, 3), shard.count);
}

test "cooldown rejection takes precedence while dancing" {
    var allay = Allay.init(.{ 0, 0, 0 });
    _ = allay.tick(.{ .pos = .{ 0, 0, 0 }, .playing_disc = .cat });
    allay.duplication_cooldown_ticks = 1;
    var shard = ItemStack{ .item = .amethyst_shard, .count = 1 };
    try std.testing.expectEqual(DuplicateResult.on_cooldown, feedAmethystShard(&allay, &shard).result);
    try std.testing.expectEqual(@as(u16, 1), shard.count);
}

test "empty shard stack cannot duplicate" {
    var allay = Allay.init(.{ 0, 0, 0 });
    _ = allay.tick(.{ .pos = .{ 0, 0, 0 }, .playing_disc = .cat });
    var shard = ItemStack{ .item = .amethyst_shard, .count = 0 };
    try std.testing.expectEqual(DuplicateResult.no_amethyst_shard, feedAmethystShard(&allay, &shard).result);
}

test "other item cannot duplicate" {
    var allay = Allay.init(.{ 0, 0, 0 });
    _ = allay.tick(.{ .pos = .{ 0, 0, 0 }, .playing_disc = .cat });
    var item = ItemStack{ .item = .other, .count = 1 };
    try std.testing.expectEqual(DuplicateResult.no_amethyst_shard, feedAmethystShard(&allay, &item).result);
}

test "cooldown counts down one tick at a time" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.duplication_cooldown_ticks = 6000;
    allay.tickCooldown();
    try std.testing.expectEqual(@as(u32, 5999), allay.duplication_cooldown_ticks);
}

test "cooldown expires at zero and restores idle state" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.duplication_cooldown_ticks = 1;
    allay.tickCooldown();
    try std.testing.expectEqual(@as(u32, 0), allay.duplication_cooldown_ticks);
    try std.testing.expectEqual(AllayState.idle_floating, allay.state);
}

test "cooldown expiry restores duplication eligibility" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.duplication_cooldown_ticks = 1;
    _ = allay.tick(.{ .pos = .{ 0, 0, 0 }, .playing_disc = .cat });
    var shard = ItemStack{ .item = .amethyst_shard, .count = 1 };
    try std.testing.expectEqual(DuplicateResult.success, feedAmethystShard(&allay, &shard).result);
}

test "Allay can keep dancing during duplication cooldown" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.duplication_cooldown_ticks = 100;
    const event = allay.tick(.{ .pos = .{ 0, 0, 0 }, .playing_disc = .cat });
    try std.testing.expect(event.dancing);
    try std.testing.expectEqual(AllayState.dancing_to_music, allay.state);
}

test "max health is twenty HP" {
    try std.testing.expectEqual(@as(f32, 20.0), ALLAY_MAX_HEALTH);
}

test "natural regeneration restores 0.1 HP per tick" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.health = 10.0;
    allay.regenerateOneTick();
    try std.testing.expectApproxEqAbs(@as(f32, 10.1), allay.health, 0.0001);
}

test "natural regeneration restores two HP per second" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.health = 10.0;
    allay.regenerateSeconds(1.0);
    try std.testing.expectEqual(@as(f32, 12.0), allay.health);
}

test "natural regeneration clamps at max health" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.health = 19.95;
    allay.regenerateOneTick();
    try std.testing.expectEqual(ALLAY_MAX_HEALTH, allay.health);
}

test "negative regeneration duration does not damage" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.health = 10.0;
    allay.regenerateSeconds(-5.0);
    try std.testing.expectEqual(@as(f32, 10.0), allay.health);
}

test "binding item stack changes Allay to holding state" {
    var allay = Allay.init(.{ 0, 0, 0 });
    try std.testing.expect(allay.bindItem(.{ .item = .other, .count = 12 }));
    try std.testing.expectEqual(AllayState.holding_item, allay.state);
    try std.testing.expectEqual(@as(u16, 12), allay.bound_item_count);
}

test "zero stack cannot bind" {
    var allay = Allay.init(.{ 0, 0, 0 });
    try std.testing.expect(!allay.bindItem(.{ .item = .other, .count = 0 }));
    try std.testing.expectEqual(AllayState.idle_floating, allay.state);
}

test "clearing bound item returns idle Allay to floating" {
    var allay = Allay.init(.{ 0, 0, 0 });
    _ = allay.bindItem(.{ .item = .other, .count = 1 });
    allay.clearBoundItem();
    try std.testing.expectEqual(AllayState.idle_floating, allay.state);
}

test "favorite player delivery search includes thirty two block boundary" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.tamed_player_id = 7;
    try std.testing.expect(allay.canSearchForDelivery(7, .{ 32, 0, 0 }));
    try std.testing.expect(!allay.canSearchForDelivery(7, .{ 32.01, 0, 0 }));
}

test "delivery search only follows favorite player" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.tamed_player_id = 7;
    try std.testing.expect(!allay.canSearchForDelivery(8, .{ 1, 0, 0 }));
}

test "nearby active note block receives collected item delivery" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.tamed_player_id = 7;
    const blocks = [_]NoteBlockTarget{ .{ .pos = .{ 12, 0, 0 } } };
    try std.testing.expectEqual(@as(?usize, 0), allay.findNoteBlockDelivery(7, .{ 16, 0, 0 }, &blocks));
}

test "inactive note block is skipped for delivery" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.tamed_player_id = 7;
    const blocks = [_]NoteBlockTarget{.{ .pos = .{ 1, 0, 0 }, .active = false }};
    try std.testing.expect(allay.findNoteBlockDelivery(7, .{ 1, 0, 0 }, &blocks) == null);
}

test "note block beyond sixteen blocks is not a delivery target" {
    var allay = Allay.init(.{ 0, 0, 0 });
    allay.tamed_player_id = 7;
    const blocks = [_]NoteBlockTarget{.{ .pos = .{ 16.01, 0, 0 } }};
    try std.testing.expect(allay.findNoteBlockDelivery(7, .{ 16, 0, 0 }, &blocks) == null);
}
