/// Allay item collection, note-block tethering, delivery, survivability,
/// jukebox dancing, and amethyst shard duplication rules.

const std = @import("std");
const jukebox_discs = @import("jukebox_discs.zig");

pub const allay_collection_radius: f32 = 32.0;
pub const note_block_hearing_radius: f32 = 16.0;
pub const note_block_tether_duration: f32 = 30.0;
pub const allay_throw_cooldown_duration: f32 = 3.0;
pub const allay_max_health: f32 = 20.0;
pub const allay_regeneration_per_second: f32 = 2.0;

pub const JUKEBOX_RANGE_SQ: f32 = 256.0;
pub const DUPLICATION_COOLDOWN_TICKS: u32 = 6_000;
pub const ALLAY_MAX_HEALTH: f32 = 20.0;
pub const ALLAY_REGEN_HP_PER_SECOND: f32 = 2.0;
pub const ALLAY_REGEN_HP_PER_TICK: f32 = 0.1;
pub const ITEM_DELIVERY_RANGE: f32 = 32.0;
pub const NOTE_BLOCK_RANGE: f32 = 16.0;

pub const AllayCollectorState = struct {
    /// Item ID held in the Allay's main hand as its collection filter.
    filter_item_id: ?u16 = null,
    carried_stack_count: u8 = 0,
    carried_max_stack: u8 = 64,
    tethered_note_block_pos: ?[3]i32 = null,
    note_block_tether_timer: f32 = 0.0,
    throw_cooldown: f32 = 0.0,
    health: f32 = allay_max_health,

    pub fn init() AllayCollectorState {
        return .{};
    }

    /// The held item becomes the filter; removing the held item clears it.
    pub fn assignFilterItem(self: *AllayCollectorState, held_item_id: ?u16) void {
        self.filter_item_id = held_item_id;
    }

    /// Adds one matching dropped item when the state has room in its stack.
    pub fn collectDroppedItem(self: *AllayCollectorState, dropped_item_id: u16, dist_to_allay: f32) bool {
        if (!canAllayCollectDroppedItem(
            self.filter_item_id,
            dropped_item_id,
            self.carried_stack_count,
            self.carried_max_stack,
            dist_to_allay,
        )) return false;
        self.carried_stack_count += 1;
        return true;
    }

    /// A nearby note-block sound sets/refreshes the acoustic delivery tether.
    /// `wool_occluded` represents wool anywhere along the sound path.
    pub fn onNoteBlockPlayed(self: *AllayCollectorState, note_block_pos: [3]i32, dist_to_allay: f32, wool_occluded: bool) bool {
        if (wool_occluded or dist_to_allay < 0.0 or dist_to_allay > note_block_hearing_radius) return false;
        self.tethered_note_block_pos = note_block_pos;
        self.note_block_tether_timer = note_block_tether_duration;
        return true;
    }

    /// Advances transient timers and expires the note-block destination at zero.
    pub fn tick(self: *AllayCollectorState, delta_seconds: f32) void {
        if (delta_seconds <= 0.0) return;
        self.note_block_tether_timer = @max(0.0, self.note_block_tether_timer - delta_seconds);
        self.throw_cooldown = @max(0.0, self.throw_cooldown - delta_seconds);
        if (self.note_block_tether_timer == 0.0) self.tethered_note_block_pos = null;
    }
};

/// The Allay seeks only the matching item identity (durability/enchantments are
/// intentionally outside this ID-level rule), within 32 blocks and stack room.
pub fn canAllayCollectDroppedItem(
    allay_filter_id: ?u16,
    dropped_item_id: u16,
    current_carried_count: u8,
    max_stack: u8,
    dist_to_allay: f32,
) bool {
    const filter_id = allay_filter_id orelse return false;
    return filter_id == dropped_item_id and
        dist_to_allay >= 0.0 and dist_to_allay <= allay_collection_radius and
        max_stack > 0 and current_carried_count < max_stack;
}

/// Resolves the active delivery destination, preferring a live note-block tether.
pub fn resolveAllayDeliveryDestination(allay: AllayCollectorState, owner_pos: [3]f32) [3]f32 {
    if (allay.note_block_tether_timer > 0.0) {
        if (allay.tethered_note_block_pos) |pos| {
            return .{ @floatFromInt(pos[0]), @floatFromInt(pos[1]), @floatFromInt(pos[2]) };
        }
    }
    return owner_pos;
}

/// The trusted owner who supplied the filter item cannot damage this Allay.
pub fn resolveDamageOnAllay(attacker_id: u32, trusted_owner_id: ?u32, incoming_damage: f32) f32 {
    if (trusted_owner_id != null and attacker_id == trusted_owner_id.?) return 0.0;
    return @max(0.0, incoming_damage);
}

/// Regenerates 2 HP/s, never healing beyond the Allay's 20 HP maximum.
pub fn tickAllayRegeneration(allay: *AllayCollectorState, delta_seconds: f32) void {
    if (delta_seconds <= 0.0) return;
    allay.health = @min(allay_max_health, allay.health + allay_regeneration_per_second * delta_seconds);
}

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

    /// Decrements the duplication cooldown by one tick and refreshes idle state.
    pub fn tickCooldown(self: *Allay) void {
        if (self.duplication_cooldown_ticks > 0) self.duplication_cooldown_ticks -= 1;
        if (!self.is_dancing) self.refreshIdleState();
    }

    /// Restores natural Allay health for one 20 Hz tick.
    pub fn regenerateOneTick(self: *Allay) void {
        self.health = @min(ALLAY_MAX_HEALTH, self.health + ALLAY_REGEN_HP_PER_TICK);
    }

    /// Restores natural Allay health over `seconds`.
    pub fn regenerateSeconds(self: *Allay, seconds: f32) void {
        if (seconds <= 0.0) return;
        self.health = @min(ALLAY_MAX_HEALTH, self.health + ALLAY_REGEN_HP_PER_SECOND * seconds);
    }

    /// Binds a non-empty stack to this Allay and transitions to holding state when idle.
    pub fn bindItem(self: *Allay, stack: ItemStack) bool {
        if (stack.count == 0) return false;
        self.bound_item_type = stack.item;
        self.bound_item_count = stack.count;
        self.refreshIdleState();
        return true;
    }

    /// Clears the bound item stack from this Allay.
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

/// Computes squared Euclidean distance between two 3D points.
pub fn distanceSq(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

/// Returns true when `allay_pos` is within the 16-block jukebox dancing radius.
pub fn isJukeboxInDanceRange(allay_pos: [3]f32, jukebox_pos: [3]f32) bool {
    return distanceSq(allay_pos, jukebox_pos) <= JUKEBOX_RANGE_SQ;
}

test "state defaults and filter assignment and clearing" {
    var allay = AllayCollectorState.init();
    try std.testing.expectEqual(@as(?u16, null), allay.filter_item_id);
    try std.testing.expectEqual(@as(u8, 0), allay.carried_stack_count);
    try std.testing.expectEqual(@as(u8, 64), allay.carried_max_stack);
    try std.testing.expectEqual(allay_max_health, allay.health);
    allay.assignFilterItem(42);
    try std.testing.expectEqual(@as(?u16, 42), allay.filter_item_id);
    allay.assignFilterItem(null);
    try std.testing.expectEqual(@as(?u16, null), allay.filter_item_id);
}

test "matching item is collected at 32 blocks including the boundary" {
    try std.testing.expect(canAllayCollectDroppedItem(42, 42, 0, 64, 0.0));
    try std.testing.expect(canAllayCollectDroppedItem(42, 42, 10, 64, 32.0));
}

test "matching item beyond 32 blocks is ignored" {
    try std.testing.expect(!canAllayCollectDroppedItem(42, 42, 0, 64, 32.01));
    try std.testing.expect(!canAllayCollectDroppedItem(42, 42, 0, 64, 100.0));
}

test "nonmatching and unfiltered items are ignored" {
    try std.testing.expect(!canAllayCollectDroppedItem(42, 43, 0, 64, 1.0));
    try std.testing.expect(!canAllayCollectDroppedItem(null, 42, 0, 64, 1.0));
}

test "full stacks and invalid stack sizes reject pickup" {
    try std.testing.expect(!canAllayCollectDroppedItem(42, 42, 64, 64, 1.0));
    try std.testing.expect(!canAllayCollectDroppedItem(42, 42, 16, 16, 1.0));
    try std.testing.expect(!canAllayCollectDroppedItem(42, 42, 1, 1, 1.0));
    try std.testing.expect(!canAllayCollectDroppedItem(42, 42, 0, 0, 1.0));
}

test "single-item and sixteen-item stack capacities accept only available room" {
    try std.testing.expect(canAllayCollectDroppedItem(42, 42, 0, 1, 1.0));
    try std.testing.expect(canAllayCollectDroppedItem(42, 42, 15, 16, 1.0));
    try std.testing.expect(!canAllayCollectDroppedItem(42, 42, 16, 16, 1.0));
}

test "negative distance is rejected" {
    try std.testing.expect(!canAllayCollectDroppedItem(42, 42, 0, 64, -0.1));
}

test "collection updates carried count only for valid matching drops" {
    var allay = AllayCollectorState.init();
    allay.assignFilterItem(9);
    try std.testing.expect(!allay.collectDroppedItem(10, 2.0));
    try std.testing.expectEqual(@as(u8, 0), allay.carried_stack_count);
    try std.testing.expect(allay.collectDroppedItem(9, 2.0));
    try std.testing.expectEqual(@as(u8, 1), allay.carried_stack_count);
}

test "item IDs match regardless of damage or enchantment metadata" {
    // The API compares only item identity; stack metadata is deliberately absent.
    try std.testing.expect(canAllayCollectDroppedItem(500, 500, 0, 1, 4.0));
}

test "note block tether starts at 16 blocks for 30 seconds" {
    var allay = AllayCollectorState.init();
    try std.testing.expect(allay.onNoteBlockPlayed(.{ 10, 64, -3 }, 16.0, false));
    try std.testing.expectEqual(@as(?[3]i32, .{ 10, 64, -3 }), allay.tethered_note_block_pos);
    try std.testing.expectEqual(note_block_tether_duration, allay.note_block_tether_timer);
    allay.tick(30.0);
    try std.testing.expectEqual(@as(f32, 0.0), allay.note_block_tether_timer);
    try std.testing.expectEqual(@as(?[3]i32, null), allay.tethered_note_block_pos);
}

test "note block beyond 16 blocks does not establish tether" {
    var allay = AllayCollectorState.init();
    try std.testing.expect(!allay.onNoteBlockPlayed(.{ 0, 0, 0 }, 16.01, false));
    try std.testing.expectEqual(@as(?[3]i32, null), allay.tethered_note_block_pos);
}

test "wool occlusion blocks note block tether" {
    var allay = AllayCollectorState.init();
    try std.testing.expect(!allay.onNoteBlockPlayed(.{ 0, 0, 0 }, 2.0, true));
    try std.testing.expectEqual(@as(f32, 0.0), allay.note_block_tether_timer);
}

test "expired or absent note tether routes delivery to owner" {
    var allay = AllayCollectorState.init();
    const owner = [3]f32{ 1.5, 70.0, -2.0 };
    try std.testing.expectEqual(owner, resolveAllayDeliveryDestination(allay, owner));
    allay.tethered_note_block_pos = .{ 4, 5, 6 };
    allay.note_block_tether_timer = 0.0;
    try std.testing.expectEqual(owner, resolveAllayDeliveryDestination(allay, owner));
}

test "live note tether routes delivery to note block instead of owner" {
    var allay = AllayCollectorState.init();
    allay.tethered_note_block_pos = .{ 4, 65, -6 };
    allay.note_block_tether_timer = 0.01;
    try std.testing.expectEqual([3]f32{ 4.0, 65.0, -6.0 }, resolveAllayDeliveryDestination(allay, .{ 1, 2, 3 }));
}

test "owner is completely immune to Allay friendly fire" {
    try std.testing.expectEqual(@as(f32, 0.0), resolveDamageOnAllay(7, 7, 1000.0));
    try std.testing.expectEqual(@as(f32, 0.0), resolveDamageOnAllay(7, 7, 1.0));
}

test "other attackers damage the Allay and damage is nonnegative" {
    try std.testing.expectEqual(@as(f32, 4.5), resolveDamageOnAllay(8, 7, 4.5));
    try std.testing.expectEqual(@as(f32, 4.5), resolveDamageOnAllay(8, null, 4.5));
    try std.testing.expectEqual(@as(f32, 0.0), resolveDamageOnAllay(8, null, -1.0));
}

test "Allay passively regenerates 2 HP per second" {
    var allay = AllayCollectorState.init();
    allay.health = 10.0;
    tickAllayRegeneration(&allay, 1.0);
    try std.testing.expectEqual(@as(f32, 12.0), allay.health);
    tickAllayRegeneration(&allay, 0.5);
    try std.testing.expectEqual(@as(f32, 13.0), allay.health);
}

test "regeneration clamps at 20 HP and ignores nonpositive elapsed time" {
    var allay = AllayCollectorState.init();
    allay.health = 19.5;
    tickAllayRegeneration(&allay, 1.0);
    try std.testing.expectEqual(allay_max_health, allay.health);
    tickAllayRegeneration(&allay, -1.0);
    try std.testing.expectEqual(allay_max_health, allay.health);
}

test "throw cooldown counts down to zero without going negative" {
    var allay = AllayCollectorState.init();
    allay.throw_cooldown = allay_throw_cooldown_duration;
    allay.tick(1.0);
    try std.testing.expectEqual(@as(f32, 2.0), allay.throw_cooldown);
    allay.tick(5.0);
    try std.testing.expectEqual(@as(f32, 0.0), allay.throw_cooldown);
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
