/// Allay item collection, note-block tethering, delivery, and survivability rules.

pub const allay_collection_radius: f32 = 32.0;
pub const note_block_hearing_radius: f32 = 16.0;
pub const note_block_tether_duration: f32 = 30.0;
pub const allay_throw_cooldown_duration: f32 = 3.0;
pub const allay_max_health: f32 = 20.0;
pub const allay_regeneration_per_second: f32 = 2.0;

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

const std = @import("std");

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
