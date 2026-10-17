/// A hopper's output direction. Hoppers cannot face upward.
pub const HopperDirection = enum { down, north, south, west, east };

pub const ItemStack = struct {
    item_id: u16 = 0,
    count: u8 = 0,
    max_stack: u8 = 64,

    pub fn isEmpty(self: ItemStack) bool {
        return self.count == 0;
    }
};

pub const HopperContainerState = struct {
    slots: [5]ItemStack = [_]ItemStack{.{}} ** 5,
    transfer_cooldown_ticks: u4 = 0,
    is_powered_locked: bool = false,
    facing: HopperDirection = .down,
};

pub const HopperTransferResult = struct { pushed_item: bool, pulled_item: bool };

fn moveOne(source: *ItemStack, destination: *?ItemStack) bool {
    if (source.count == 0) return false;
    if (destination.*) |*dest| {
        if (dest.item_id != source.item_id or dest.count >= dest.max_stack) return false;
        dest.count += 1;
    } else {
        destination.* = .{ .item_id = source.item_id, .count = 1, .max_stack = source.max_stack };
    }
    source.count -= 1;
    return true;
}

fn moveOneIntoHopper(source: *?ItemStack, destination: *ItemStack) bool {
    const src = &(source.* orelse return false);
    if (src.count == 0) return false;
    if (destination.count != 0) {
        if (destination.item_id != src.item_id or destination.count >= destination.max_stack) return false;
        destination.count += 1;
    } else {
        destination.* = .{ .item_id = src.item_id, .count = 1, .max_stack = src.max_stack };
    }
    src.count -= 1;
    if (src.count == 0) source.* = null;
    return true;
}

/// Runs one hopper transfer opportunity: push first, then pull, in the same game tick.
/// Each successful leg moves one item. A ready hopper receives the standard eight-tick cooldown.
pub fn tickHopperPushAndPull(
    state: *HopperContainerState,
    source_above_first_slot: *?ItemStack,
    target_facing_slot: *?ItemStack,
) HopperTransferResult {
    if (state.is_powered_locked) return .{ .pushed_item = false, .pulled_item = false };
    if (state.transfer_cooldown_ticks != 0) {
        state.transfer_cooldown_ticks -= 1;
        return .{ .pushed_item = false, .pulled_item = false };
    }

    var result = HopperTransferResult{ .pushed_item = false, .pulled_item = false };
    for (&state.slots) |*slot| {
        if (slot.count == 0) continue;
        result.pushed_item = moveOne(slot, target_facing_slot);
        break;
    }
    if (source_above_first_slot.* != null) {
        for (&state.slots) |*slot| {
            if (slot.count != 0 and slot.item_id != source_above_first_slot.*.?.item_id) continue;
            if (slot.count >= slot.max_stack) continue;
            result.pulled_item = moveOneIntoHopper(source_above_first_slot, slot);
            if (result.pulled_item) break;
        }
    }
    state.transfer_cooldown_ticks = 8;
    return result;
}

pub const ItemSorterResult = struct { comparator_signal: u4, unlocks_lower_hopper_torch: bool };

/// Comparator strength for the five-slot ImpulseSV filter inventory.
/// Four renamed blocker items occupy slots 1–4; valid filter math uses 64-stack items.
pub fn evaluateImpulseSvItemSorter(
    slot0_target_item_count: u8,
    blocker_slots_1_to_4_each_have_1_filler: bool,
    max_stack_64: bool,
) ItemSorterResult {
    const stack_limit: u32 = if (max_stack_64) 64 else 16;
    const total_slots: u32 = 5;
    const total: u32 = @as(u32, slot0_target_item_count) + if (blocker_slots_1_to_4_each_have_1_filler) @as(u32, 4) else 0;
    const denominator = total_slots * stack_limit;
    const signal: u32 = if (total == 0) 0 else 1 + @divTrunc(total * 14, denominator);
    const bounded: u4 = @intCast(@min(signal, 15));
    return .{ .comparator_signal = bounded, .unlocks_lower_hopper_torch = bounded >= 3 };
}

pub const DropperDispenserOutcome = enum {
    injected_into_container_slot,
    dropped_as_gentle_item_entity,
    fired_active_projectile_or_placed_block,
};

/// Resolves the distinct activation behavior of a dropper and a dispenser.
pub fn resolveDropperVsDispenserActivation(
    is_dropper: bool,
    facing_into_container: bool,
    item_is_arrow_or_tnt_or_bucket: bool,
) DropperDispenserOutcome {
    if (is_dropper and facing_into_container) return .injected_into_container_slot;
    if (!is_dropper and item_is_arrow_or_tnt_or_bucket) return .fired_active_projectile_or_placed_block;
    return .dropped_as_gentle_item_entity;
}

test "hopper direction has exactly five legal values and never points up" {
    const directions = [_]HopperDirection{ .down, .north, .south, .west, .east };
    try @import("std").testing.expectEqual(@as(usize, 5), directions.len);
    try @import("std").testing.expectEqual(HopperDirection.down, (HopperContainerState{}).facing);
}

test "hopper defaults to five empty slots and no cooldown" {
    const hopper = HopperContainerState{};
    try @import("std").testing.expectEqual(@as(usize, 5), hopper.slots.len);
    try @import("std").testing.expectEqual(@as(u4, 0), hopper.transfer_cooldown_ticks);
    try @import("std").testing.expect(!hopper.is_powered_locked);
}

test "one transfer opportunity arms an eight game tick cooldown" {
    var hopper = HopperContainerState{};
    hopper.slots[0] = .{ .item_id = 1, .count = 2 };
    var source: ?ItemStack = null;
    var target: ?ItemStack = null;
    const result = tickHopperPushAndPull(&hopper, &source, &target);
    try @import("std").testing.expect(result.pushed_item);
    try @import("std").testing.expectEqual(@as(u4, 8), hopper.transfer_cooldown_ticks);
    try @import("std").testing.expectApproxEqAbs(@as(f32, 2.5), 20.0 / 8.0, 0.001);
}

test "cooldown decrements without transferring until ready" {
    var hopper = HopperContainerState{ .transfer_cooldown_ticks = 2 };
    hopper.slots[0] = .{ .item_id = 2, .count = 1 };
    var source: ?ItemStack = null;
    var target: ?ItemStack = null;
    const a = tickHopperPushAndPull(&hopper, &source, &target);
    try @import("std").testing.expect(!a.pushed_item and !a.pulled_item);
    try @import("std").testing.expectEqual(@as(u4, 1), hopper.transfer_cooldown_ticks);
    const b = tickHopperPushAndPull(&hopper, &source, &target);
    try @import("std").testing.expect(!b.pushed_item);
    try @import("std").testing.expectEqual(@as(u4, 0), hopper.transfer_cooldown_ticks);
}

test "powered hopper is completely frozen including cooldown" {
    var hopper = HopperContainerState{ .is_powered_locked = true, .transfer_cooldown_ticks = 0 };
    hopper.slots[0] = .{ .item_id = 1, .count = 1 };
    var source: ?ItemStack = .{ .item_id = 2, .count = 1 };
    var target: ?ItemStack = null;
    const result = tickHopperPushAndPull(&hopper, &source, &target);
    try @import("std").testing.expect(!result.pushed_item and !result.pulled_item);
    try @import("std").testing.expectEqual(@as(u8, 1), hopper.slots[0].count);
    try @import("std").testing.expectEqual(@as(u8, 1), source.?.count);
    try @import("std").testing.expect(target == null);
}

test "push then pull both happen during one ready tick" {
    var hopper = HopperContainerState{};
    hopper.slots[0] = .{ .item_id = 10, .count = 1 };
    var source: ?ItemStack = .{ .item_id = 20, .count = 3 };
    var target: ?ItemStack = null;
    const result = tickHopperPushAndPull(&hopper, &source, &target);
    try @import("std").testing.expect(result.pushed_item and result.pulled_item);
    try @import("std").testing.expectEqual(@as(u16, 10), target.?.item_id);
    try @import("std").testing.expectEqual(@as(u16, 20), hopper.slots[0].item_id);
    try @import("std").testing.expectEqual(@as(u8, 1), hopper.slots[0].count);
    try @import("std").testing.expectEqual(@as(u8, 2), source.?.count);
}

test "push selects first nonempty hopper slot" {
    var hopper = HopperContainerState{};
    hopper.slots[2] = .{ .item_id = 9, .count = 2 };
    var source: ?ItemStack = null;
    var target: ?ItemStack = null;
    const result = tickHopperPushAndPull(&hopper, &source, &target);
    try @import("std").testing.expect(result.pushed_item);
    try @import("std").testing.expectEqual(@as(u16, 9), target.?.item_id);
    try @import("std").testing.expectEqual(@as(u8, 1), hopper.slots[2].count);
}

test "full or mismatched output blocks push but still allows pull" {
    var hopper = HopperContainerState{};
    hopper.slots[0] = .{ .item_id = 1, .count = 2 };
    var source: ?ItemStack = .{ .item_id = 2, .count = 1 };
    var target: ?ItemStack = .{ .item_id = 3, .count = 64 };
    const result = tickHopperPushAndPull(&hopper, &source, &target);
    try @import("std").testing.expect(!result.pushed_item and result.pulled_item);
    try @import("std").testing.expectEqual(@as(u16, 2), hopper.slots[1].item_id);
}

test "pull fills matching stack before an empty slot" {
    var hopper = HopperContainerState{};
    hopper.slots[0] = .{ .item_id = 5, .count = 4 };
    var source: ?ItemStack = .{ .item_id = 5, .count = 2 };
    var target: ?ItemStack = null;
    const result = tickHopperPushAndPull(&hopper, &source, &target);
    try @import("std").testing.expect(result.pulled_item);
    // Push ran first and returned one matching item before the pull restored it.
    try @import("std").testing.expectEqual(@as(u8, 4), hopper.slots[0].count);
    try @import("std").testing.expectEqual(@as(u8, 1), source.?.count);
}

test "failed transfer opportunity still starts cooldown" {
    var hopper = HopperContainerState{};
    var source: ?ItemStack = null;
    var target: ?ItemStack = null;
    const result = tickHopperPushAndPull(&hopper, &source, &target);
    try @import("std").testing.expect(!result.pushed_item and !result.pulled_item);
    try @import("std").testing.expectEqual(@as(u4, 8), hopper.transfer_cooldown_ticks);
}

test "ImpulseSV 41 targets with four fillers signal two" {
    const result = evaluateImpulseSvItemSorter(41, true, true);
    try @import("std").testing.expectEqual(@as(u4, 2), result.comparator_signal);
    try @import("std").testing.expect(!result.unlocks_lower_hopper_torch);
}

test "ImpulseSV threshold jumps from 41 to 42 targets" {
    const at_41 = evaluateImpulseSvItemSorter(41, true, true);
    const at_42 = evaluateImpulseSvItemSorter(42, true, true);
    try @import("std").testing.expectEqual(@as(u4, 2), at_41.comparator_signal);
    try @import("std").testing.expectEqual(@as(u4, 3), at_42.comparator_signal);
    try @import("std").testing.expect(at_42.unlocks_lower_hopper_torch);
}

test "sorter signal without blockers follows occupied inventory fraction" {
    const empty = evaluateImpulseSvItemSorter(0, false, true);
    const occupied = evaluateImpulseSvItemSorter(46, false, true);
    try @import("std").testing.expectEqual(@as(u4, 0), empty.comparator_signal);
    try @import("std").testing.expectEqual(@as(u4, 3), occupied.comparator_signal);
}

test "sorter supports non-64-stack denominator" {
    const result = evaluateImpulseSvItemSorter(12, true, false);
    try @import("std").testing.expectEqual(@as(u4, 3), result.comparator_signal);
    try @import("std").testing.expect(result.unlocks_lower_hopper_torch);
}

test "dropper inserts directly into a facing container" {
    try @import("std").testing.expectEqual(DropperDispenserOutcome.injected_into_container_slot, resolveDropperVsDispenserActivation(true, true, true));
}

test "dropper drops arrows and tnt gently when not inserting" {
    try @import("std").testing.expectEqual(DropperDispenserOutcome.dropped_as_gentle_item_entity, resolveDropperVsDispenserActivation(true, false, true));
}

test "dispenser activates arrow tnt or bucket behavior" {
    try @import("std").testing.expectEqual(DropperDispenserOutcome.fired_active_projectile_or_placed_block, resolveDropperVsDispenserActivation(false, false, true));
}

test "dispenser drops ordinary items gently" {
    try @import("std").testing.expectEqual(DropperDispenserOutcome.dropped_as_gentle_item_entity, resolveDropperVsDispenserActivation(false, true, false));
}
