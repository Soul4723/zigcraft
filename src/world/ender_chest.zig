const std = @import("std");

pub const vault_slots: usize = 4;
pub const obsidian_salvage_count: u8 = 8;

pub const VaultSlot = struct {
    item_tag: u16 = 0,
    count: u8 = 0,
};

pub const EnderVault = struct {
    slots: [vault_slots]VaultSlot = [_]VaultSlot{.{}} ** vault_slots,
};

pub fn depositItem(vault: *EnderVault, item_tag: u16, count: u8, max_stack: u8) u8 {
    if (item_tag == 0 or count == 0 or max_stack == 0) return 0;
    var remaining: u8 = count;
    for (&vault.slots) |*slot| {
        if (remaining == 0) break;
        if (slot.item_tag == item_tag and slot.count < max_stack) {
            const space = max_stack - slot.count;
            const moved = @min(space, remaining);
            slot.count += moved;
            remaining -= moved;
        }
    }
    for (&vault.slots) |*slot| {
        if (remaining == 0) break;
        if (slot.item_tag == 0) {
            const moved = @min(max_stack, remaining);
            slot.item_tag = item_tag;
            slot.count = moved;
            remaining -= moved;
        }
    }
    return count - remaining;
}

pub fn withdrawLast(vault: *EnderVault) ?VaultSlot {
    var i: usize = vault_slots;
    while (i > 0) {
        i -= 1;
        const slot = vault.slots[i];
        if (slot.item_tag != 0 and slot.count > 0) {
            vault.slots[i] = .{};
            return slot;
        }
    }
    return null;
}

pub fn occupiedSlotCount(vault: EnderVault) u8 {
    var n: u8 = 0;
    for (vault.slots) |slot| {
        if (slot.item_tag != 0 and slot.count > 0) n += 1;
    }
    return n;
}

test "constants" {
    try std.testing.expectEqual(@as(usize, 4), vault_slots);
    try std.testing.expectEqual(@as(u8, 8), obsidian_salvage_count);
}

test "VaultSlot defaults" {
    const slot = VaultSlot{};
    try std.testing.expectEqual(@as(u16, 0), slot.item_tag);
    try std.testing.expectEqual(@as(u8, 0), slot.count);
}

test "EnderVault defaults to empty slots" {
    const vault = EnderVault{};
    for (vault.slots) |slot| {
        try std.testing.expectEqual(@as(u16, 0), slot.item_tag);
        try std.testing.expectEqual(@as(u8, 0), slot.count);
    }
    try std.testing.expectEqual(@as(u8, 0), occupiedSlotCount(vault));
}

test "depositItem rejects zero tag and zero count" {
    var vault = EnderVault{};
    try std.testing.expectEqual(@as(u8, 0), depositItem(&vault, 0, 5, 64));
    try std.testing.expectEqual(@as(u8, 0), depositItem(&vault, 7, 0, 64));
    try std.testing.expectEqual(@as(u8, 0), occupiedSlotCount(vault));
}

test "depositItem into empty slot" {
    var vault = EnderVault{};
    const deposited = depositItem(&vault, 7, 10, 64);
    try std.testing.expectEqual(@as(u8, 10), deposited);
    try std.testing.expectEqual(@as(u16, 7), vault.slots[0].item_tag);
    try std.testing.expectEqual(@as(u8, 10), vault.slots[0].count);
    try std.testing.expectEqual(@as(u8, 1), occupiedSlotCount(vault));
}

test "depositItem stacks into existing matching slot" {
    var vault = EnderVault{};
    _ = depositItem(&vault, 7, 10, 64);
    const deposited = depositItem(&vault, 7, 5, 64);
    try std.testing.expectEqual(@as(u8, 5), deposited);
    try std.testing.expectEqual(@as(u8, 15), vault.slots[0].count);
    try std.testing.expectEqual(@as(u8, 1), occupiedSlotCount(vault));
}

test "depositItem respects max_stack and spills to next slot" {
    var vault = EnderVault{};
    _ = depositItem(&vault, 7, 60, 64);
    const deposited = depositItem(&vault, 7, 10, 64);
    try std.testing.expectEqual(@as(u8, 10), deposited);
    try std.testing.expectEqual(@as(u8, 64), vault.slots[0].count);
    try std.testing.expectEqual(@as(u16, 7), vault.slots[1].item_tag);
    try std.testing.expectEqual(@as(u8, 6), vault.slots[1].count);
    try std.testing.expectEqual(@as(u8, 2), occupiedSlotCount(vault));
}

test "depositItem reports partial when vault is full" {
    var vault = EnderVault{};
    var i: usize = 0;
    while (i < vault_slots) : (i += 1) {
        const deposited = depositItem(&vault, 7, 64, 64);
        try std.testing.expectEqual(@as(u8, 64), deposited);
    }
    try std.testing.expectEqual(@as(u8, 4), occupiedSlotCount(vault));
    const deposited = depositItem(&vault, 9, 10, 64);
    try std.testing.expectEqual(@as(u8, 0), deposited);
    try std.testing.expectEqual(@as(u8, 4), occupiedSlotCount(vault));
}

test "depositItem into a full matching stack does not merge" {
    var vault = EnderVault{};
    vault.slots[0] = .{ .item_tag = 7, .count = 64 };
    const deposited = depositItem(&vault, 7, 5, 64);
    try std.testing.expectEqual(@as(u8, 5), deposited);
    try std.testing.expectEqual(@as(u8, 64), vault.slots[0].count);
    try std.testing.expectEqual(@as(u16, 7), vault.slots[1].item_tag);
    try std.testing.expectEqual(@as(u8, 5), vault.slots[1].count);
}

test "depositItem splits across existing stack and new slot" {
    var vault = EnderVault{};
    vault.slots[0] = .{ .item_tag = 7, .count = 60 };
    const deposited = depositItem(&vault, 7, 10, 64);
    try std.testing.expectEqual(@as(u8, 10), deposited);
    try std.testing.expectEqual(@as(u8, 64), vault.slots[0].count);
    try std.testing.expectEqual(@as(u8, 6), vault.slots[1].count);
}

test "depositItem with max_stack of one" {
    var vault = EnderVault{};
    const deposited = depositItem(&vault, 7, 3, 1);
    try std.testing.expectEqual(@as(u8, 3), deposited);
    try std.testing.expectEqual(@as(u8, 1), vault.slots[0].count);
    try std.testing.expectEqual(@as(u8, 1), vault.slots[1].count);
    try std.testing.expectEqual(@as(u8, 1), vault.slots[2].count);
    try std.testing.expectEqual(@as(u8, 3), occupiedSlotCount(vault));
}

test "depositItem refuses when max_stack is zero" {
    var vault = EnderVault{};
    try std.testing.expectEqual(@as(u8, 0), depositItem(&vault, 7, 5, 0));
    try std.testing.expectEqual(@as(u8, 0), occupiedSlotCount(vault));
}

test "withdrawLast on empty vault returns null" {
    var vault = EnderVault{};
    try std.testing.expectEqual(@as(?VaultSlot, null), withdrawLast(&vault));
}

test "withdrawLast returns and clears the last occupied slot" {
    var vault = EnderVault{};
    vault.slots[0] = .{ .item_tag = 1, .count = 2 };
    vault.slots[2] = .{ .item_tag = 3, .count = 4 };
    const got = withdrawLast(&vault);
    try std.testing.expect(got != null);
    try std.testing.expectEqual(@as(u16, 3), got.?.item_tag);
    try std.testing.expectEqual(@as(u8, 4), got.?.count);
    try std.testing.expectEqual(@as(u16, 0), vault.slots[2].item_tag);
    try std.testing.expectEqual(@as(u8, 0), vault.slots[2].count);
    try std.testing.expectEqual(@as(u8, 1), occupiedSlotCount(vault));
}

test "withdrawLast scans downward and ignores empty slots" {
    var vault = EnderVault{};
    vault.slots[3] = .{ .item_tag = 5, .count = 1 };
    _ = withdrawLast(&vault);
    try std.testing.expectEqual(@as(?VaultSlot, null), withdrawLast(&vault));
}

test "withdrawLast ignores slots with zero count" {
    var vault = EnderVault{};
    vault.slots[2] = .{ .item_tag = 3, .count = 0 };
    vault.slots[0] = .{ .item_tag = 1, .count = 9 };
    const got = withdrawLast(&vault);
    try std.testing.expect(got != null);
    try std.testing.expectEqual(@as(u16, 1), got.?.item_tag);
    try std.testing.expectEqual(@as(u8, 9), got.?.count);
    try std.testing.expectEqual(@as(u16, 3), vault.slots[2].item_tag);
    try std.testing.expectEqual(@as(u8, 0), vault.slots[2].count);
}

test "occupiedSlotCount counts only non-empty slots" {
    var vault = EnderVault{};
    try std.testing.expectEqual(@as(u8, 0), occupiedSlotCount(vault));
    vault.slots[0] = .{ .item_tag = 1, .count = 1 };
    try std.testing.expectEqual(@as(u8, 1), occupiedSlotCount(vault));
    vault.slots[1] = .{ .item_tag = 0, .count = 5 };
    try std.testing.expectEqual(@as(u8, 1), occupiedSlotCount(vault));
    vault.slots[3] = .{ .item_tag = 2, .count = 3 };
    try std.testing.expectEqual(@as(u8, 2), occupiedSlotCount(vault));
}

test "deposit then withdraw round trip" {
    var vault = EnderVault{};
    _ = depositItem(&vault, 42, 12, 64);
    const got = withdrawLast(&vault);
    try std.testing.expect(got != null);
    try std.testing.expectEqual(@as(u16, 42), got.?.item_tag);
    try std.testing.expectEqual(@as(u8, 12), got.?.count);
    try std.testing.expectEqual(@as(u8, 0), occupiedSlotCount(vault));
}
