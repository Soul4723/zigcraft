//! Milestone 494: chiseled bookshelf combination lock and piston door.
//!
//! A lock borrows a configured slot combination. Each shelf reports its last
//! interacted occupied slot; every shelf must match for the lock to emit 15.
//! The door actuator turns that signal into a six-tick piston state transition.

pub const bookshelf_slots: usize = 6;
pub const minimum_bookshelves: usize = 2;
pub const door_transition_ticks: u8 = 6;
pub const locked_signal: u8 = 0;
pub const unlocked_signal: u8 = 15;

/// A bookshelf's occupied slots and most recent valid slot interaction.
/// Any slot content change clears the interaction, requiring a fresh selection.
pub const BookshelfState = struct {
    occupied_slots: u6 = 0,
    interacted_slot: ?u3 = null,

    pub fn setSlotOccupied(self: *BookshelfState, slot: u3, occupied: bool) void {
        if (slot >= bookshelf_slots) return;
        const mask: u6 = @as(u6, 1) << slot;
        const was_occupied = (self.occupied_slots & mask) != 0;
        if (was_occupied == occupied) return;
        if (occupied) {
            self.occupied_slots |= mask;
        } else {
            self.occupied_slots &= ~mask;
        }
        self.interacted_slot = null;
    }

    /// Marks the slot as the latest selection only if it currently holds a book.
    pub fn interact(self: *BookshelfState, slot: u3) bool {
        if (slot >= bookshelf_slots) return false;
        const mask: u6 = @as(u6, 1) << slot;
        if ((self.occupied_slots & mask) == 0) {
            self.interacted_slot = null;
            return false;
        }
        self.interacted_slot = slot;
        return true;
    }

    pub fn comparatorSignal(self: BookshelfState) u4 {
        const slot = self.interacted_slot orelse return 0;
        if (slot >= bookshelf_slots) return 0;
        const mask: u6 = @as(u6, 1) << slot;
        if ((self.occupied_slots & mask) == 0) return 0;
        return @as(u4, slot) + 1;
    }
};

/// Secret combination. The password and bookshelf slices are borrowed and
/// must remain alive for the duration of each evaluation.
pub const SecretLatch = struct {
    password: []const u3,

    pub fn init(password: []const u3) SecretLatch {
        return .{ .password = password };
    }

    pub fn isUnlocked(self: SecretLatch, bookshelves: []const BookshelfState) bool {
        if (self.password.len < minimum_bookshelves or bookshelves.len != self.password.len) return false;
        for (self.password, bookshelves) |expected, shelf| {
            if (shelf.interacted_slot == null or shelf.interacted_slot.? != expected) return false;
            if (shelf.comparatorSignal() == 0) return false;
        }
        return true;
    }

    pub fn outputSignal(self: SecretLatch, bookshelves: []const BookshelfState) u8 {
        return if (self.isUnlocked(bookshelves)) unlocked_signal else locked_signal;
    }
};

/// Tracks the hidden piston array. A changed lock signal starts a six-tick
/// transition; a new target during the delay replaces the pending target.
pub const PistonDoor = struct {
    is_retracted: bool = false,
    pending_target: ?bool = null,
    ticks_remaining: u8 = 0,

    pub fn tick(self: *PistonDoor, signal_strength: u8) bool {
        const wants_open = signal_strength == unlocked_signal;
        if (wants_open == self.is_retracted) {
            self.pending_target = null;
            self.ticks_remaining = 0;
            return false;
        }

        if (self.pending_target == null or self.pending_target.? != wants_open) {
            self.pending_target = wants_open;
            self.ticks_remaining = door_transition_ticks;
        }
        self.ticks_remaining -= 1;
        if (self.ticks_remaining != 0) return false;

        self.is_retracted = self.pending_target.?;
        self.pending_target = null;
        return true;
    }

    pub fn isPassageOpen(self: PistonDoor) bool {
        return self.is_retracted;
    }
};

fn makeShelves(comptime slots: []const u3) [slots.len]BookshelfState {
    var shelves: [slots.len]BookshelfState = undefined;
    for (slots, 0..) |slot, i| {
        shelves[i] = .{};
        shelves[i].setSlotOccupied(slot, true);
        _ = shelves[i].interact(slot);
    }
    return shelves;
}

test "two bookshelf password matches" {
    const pass = [_]u3{ 2, 5 };
    const shelves = makeShelves(&pass);
    try @import("std").testing.expect(SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "three bookshelf password matches" {
    const pass = [_]u3{ 2, 5, 0 };
    const shelves = makeShelves(&pass);
    try @import("std").testing.expect(SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "four bookshelf password matches" {
    const pass = [_]u3{ 2, 5, 0, 4 };
    const shelves = makeShelves(&pass);
    try @import("std").testing.expect(SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "two shelf combination outputs full power" {
    const pass = [_]u3{ 1, 3 };
    const shelves = makeShelves(&pass);
    try @import("std").testing.expectEqual(unlocked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "three shelf combination outputs full power" {
    const pass = [_]u3{ 1, 3, 5 };
    const shelves = makeShelves(&pass);
    try @import("std").testing.expectEqual(unlocked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "four shelf combination outputs full power" {
    const pass = [_]u3{ 1, 3, 5, 0 };
    const shelves = makeShelves(&pass);
    try @import("std").testing.expectEqual(unlocked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "first shelf mismatch keeps signal at zero" {
    const pass = [_]u3{ 1, 2, 3 };
    const shelves = makeShelves(&[_]u3{ 0, 2, 3 });
    try @import("std").testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "middle shelf mismatch keeps signal at zero" {
    const pass = [_]u3{ 1, 2, 3 };
    const shelves = makeShelves(&[_]u3{ 1, 0, 3 });
    try @import("std").testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "last shelf mismatch keeps signal at zero" {
    const pass = [_]u3{ 1, 2, 3 };
    const shelves = makeShelves(&[_]u3{ 1, 2, 0 });
    try @import("std").testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "a two shelf password rejects one wrong selection" {
    const pass = [_]u3{ 2, 5 };
    const shelves = makeShelves(&[_]u3{ 2, 4 });
    try @import("std").testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "a four shelf password rejects one wrong selection" {
    const pass = [_]u3{ 2, 5, 0, 4 };
    const shelves = makeShelves(&[_]u3{ 2, 5, 1, 4 });
    try @import("std").testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "missing bookshelf prevents a match" {
    const pass = [_]u3{ 2, 5, 0 };
    const shelves = makeShelves(&[_]u3{ 2, 5 });
    try @import("std").testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "extra bookshelf prevents a match" {
    const pass = [_]u3{ 2, 5 };
    const shelves = makeShelves(&[_]u3{ 2, 5, 0 });
    try @import("std").testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "password with fewer than two shelves is invalid" {
    const pass = [_]u3{2};
    const shelves = makeShelves(&pass);
    try @import("std").testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "empty password is invalid" {
    const pass = [_]u3{};
    const shelves = [_]BookshelfState{};
    try @import("std").testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "uninteracted occupied shelf does not match" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    shelves[1].interacted_slot = null;
    try @import("std").testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "removed password book resets its interaction and lock" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    shelves[0].setSlotOccupied(2, false);
    try @import("std").testing.expectEqual(@as(u4, 0), shelves[0].comparatorSignal());
    try @import("std").testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "adding a book resets interaction until the slot is selected" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    shelves[0].setSlotOccupied(4, true);
    try @import("std").testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
    _ = shelves[0].interact(2);
    try @import("std").testing.expectEqual(unlocked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "changing selected shelf slot resets combination" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    shelves[1].setSlotOccupied(1, true);
    try @import("std").testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "reselecting password slot restores combination" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    _ = shelves[1].interact(1);
    try @import("std").testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
    _ = shelves[1].interact(5);
    try @import("std").testing.expect(SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "unchanged slot contents preserve selected interaction" {
    var shelf = makeShelves(&[_]u3{3})[0];
    shelf.setSlotOccupied(3, true);
    try @import("std").testing.expectEqual(@as(?u3, 3), shelf.interacted_slot);
}

test "empty slot interaction clears the previous selection" {
    var shelf = makeShelves(&[_]u3{3})[0];
    try @import("std").testing.expect(!shelf.interact(4));
    try @import("std").testing.expectEqual(@as(?u3, null), shelf.interacted_slot);
}

test "bookshelf comparator signal follows selected slot" {
    var shelf = makeShelves(&[_]u3{4})[0];
    try @import("std").testing.expectEqual(@as(u4, 5), shelf.comparatorSignal());
}

test "bookshelf comparator returns zero with no interaction" {
    var shelf = BookshelfState{};
    shelf.setSlotOccupied(0, true);
    try @import("std").testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
}

test "bookshelf comparator returns zero when selected book disappears" {
    var shelf = makeShelves(&[_]u3{0})[0];
    shelf.occupied_slots = 0;
    try @import("std").testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
}

test "out of range slot updates are ignored" {
    var shelf = makeShelves(&[_]u3{2})[0];
    shelf.setSlotOccupied(7, false);
    try @import("std").testing.expectEqual(@as(u6, 1 << 2), shelf.occupied_slots);
    try @import("std").testing.expectEqual(@as(?u3, 2), shelf.interacted_slot);
}

test "invalid last interacted slot emits no comparator signal" {
    const shelf = BookshelfState{ .interacted_slot = 7 };
    try @import("std").testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
}

test "piston door begins sealed" {
    const door = PistonDoor{};
    try @import("std").testing.expect(!door.isPassageOpen());
}

test "unlocked input retracts pistons after six ticks" {
    var door = PistonDoor{};
    for (0..5) |_| try @import("std").testing.expect(!door.tick(unlocked_signal));
    try @import("std").testing.expect(!door.isPassageOpen());
    try @import("std").testing.expect(door.tick(unlocked_signal));
    try @import("std").testing.expect(door.isPassageOpen());
}

test "locked input extends pistons after six ticks" {
    var door = PistonDoor{ .is_retracted = true };
    for (0..5) |_| try @import("std").testing.expect(!door.tick(locked_signal));
    try @import("std").testing.expect(door.isPassageOpen());
    try @import("std").testing.expect(door.tick(locked_signal));
    try @import("std").testing.expect(!door.isPassageOpen());
}

test "pending door transition can be canceled by relocking" {
    var door = PistonDoor{};
    for (0..3) |_| _ = door.tick(unlocked_signal);
    for (0..8) |_| _ = door.tick(locked_signal);
    try @import("std").testing.expect(!door.isPassageOpen());
    try @import("std").testing.expectEqual(@as(u8, 0), door.ticks_remaining);
}

test "door opens after six ticks of a steady unlock input" {
    var door = PistonDoor{};
    for (0..5) |_| _ = door.tick(unlocked_signal);
    try @import("std").testing.expect(door.tick(unlocked_signal));
    try @import("std").testing.expect(door.isPassageOpen());
}

test "intermediate signal levels keep the door locked" {
    var door = PistonDoor{};
    for (0..8) |_| _ = door.tick(6);
    try @import("std").testing.expect(!door.isPassageOpen());
}
