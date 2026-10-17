const std = @import("std");

/// Maximum number of chiseled bookshelves tracked in a single spatial collection.
pub const max_chiseled_bookshelves: usize = 32;

/// Total number of book slots in a chiseled bookshelf (3 columns x 2 rows).
pub const total_slots: usize = 6;

// Tag constants for book items
pub const EmptySlot: u16 = 0;
pub const BookTag: u16 = 270; // Matches inventory.zig .book
pub const EnchantedBookTag: u16 = 400;
pub const BookAndQuillTag: u16 = 401;
pub const WrittenBookTag: u16 = 402;
pub const KnowledgeTomeTag: u16 = 403;

/// Returns true if the item tag represents an acceptable book item.
pub fn isBookItem(item_id: u16) bool {
    return switch (item_id) {
        BookTag, EnchantedBookTag, BookAndQuillTag, WrittenBookTag, KnowledgeTomeTag => true,
        else => false,
    };
}

/// Horizontal and vertical cardinal facings for directional blocks.
pub const Facing = enum(u3) {
    north = 0,
    south = 1,
    west = 2,
    east = 3,
    up = 4,
    down = 5,

    pub fn toNormal(self: Facing) [3]i32 {
        return switch (self) {
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .west => .{ -1, 0, 0 },
            .east => .{ 1, 0, 0 },
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
        };
    }

    pub fn isHorizontal(self: Facing) bool {
        return switch (self) {
            .north, .south, .west, .east => true,
            .up, .down => false,
        };
    }
};

/// Result of interacting with a slot on the chiseled bookshelf.
pub const InteractAction = enum {
    none,
    inserted,
    retrieved,
};

pub const InteractResult = struct {
    action: InteractAction = .none,
    item_id: u16 = EmptySlot,
    slot: u3 = 0,

    pub fn success(self: InteractResult) bool {
        return self.action != .none;
    }
};

/// Maps 3D block face UV coordinates (0.0..1.0 horizontal u across 3 columns, vertical v across 2 rows)
/// onto slot index 0..5 (top row 0..2, bottom row 3..5).
/// Clamps u and v to [0.0, 1.0].
pub fn hitCoordsToSlot(facing: Facing, hit_u: f32, hit_v: f32) u3 {
    _ = facing;
    const u = std.math.clamp(hit_u, 0.0, 1.0);
    const v = std.math.clamp(hit_v, 0.0, 1.0);

    const col: u3 = if (u < 1.0 / 3.0)
        0
    else if (u < 2.0 / 3.0)
        1
    else
        2;

    const row: u3 = if (v < 0.5) 0 else 1;

    return row * 3 + col;
}

/// Helper mapping 2D face UV (0.0..1.0) directly to slot index 0..5.
pub fn uvToSlot(hit_u: f32, hit_v: f32) u3 {
    return hitCoordsToSlot(.north, hit_u, hit_v);
}

/// Converts world ray hit coordinates on a block face to normalized face UV (u, v in 0.0..1.0).
/// Top edge is v = 0.0, bottom edge is v = 1.0.
/// Returns null if hit is on top/bottom or invalid face.
pub fn worldHitToFaceUV(facing: Facing, hit_x: f32, hit_y: f32, hit_z: f32, block_x: i32, block_y: i32, block_z: i32) ?struct { u: f32, v: f32 } {
    const fx = hit_x - @as(f32, @floatFromInt(block_x));
    const fy = hit_y - @as(f32, @floatFromInt(block_y));
    const fz = hit_z - @as(f32, @floatFromInt(block_z));

    const v = std.math.clamp(1.0 - fy, 0.0, 1.0);

    const u = switch (facing) {
        .north => std.math.clamp(fx, 0.0, 1.0),
        .south => std.math.clamp(1.0 - fx, 0.0, 1.0),
        .west => std.math.clamp(1.0 - fz, 0.0, 1.0),
        .east => std.math.clamp(fz, 0.0, 1.0),
        .up, .down => return null,
    };

    return .{ .u = u, .v = v };
}

/// ChiseledBookshelf represents a 6-slot directional book storage container (slots 0..5).
/// Top row: slots 0, 1, 2. Bottom row: slots 3, 4, 5.
pub const ChiseledBookshelf = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    facing: Facing = .north,
    slots: [total_slots]u16 = [_]u16{EmptySlot} ** total_slots,
    last_interacted_slot: ?u3 = null,

    pub fn init(x: i32, y: i32, z: i32, facing: Facing) ChiseledBookshelf {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .facing = facing,
            .slots = [_]u16{EmptySlot} ** total_slots,
            .last_interacted_slot = null,
        };
    }

    /// Number of books currently stored in the shelf (0..6).
    pub fn bookCount(self: ChiseledBookshelf) u3 {
        var count: u3 = 0;
        for (self.slots) |s| {
            if (s != EmptySlot) count += 1;
        }
        return count;
    }

    /// True if no books are stored.
    pub fn isEmpty(self: ChiseledBookshelf) bool {
        return self.bookCount() == 0;
    }

    /// True if all 6 slots are occupied.
    pub fn isFull(self: ChiseledBookshelf) bool {
        return self.bookCount() == total_slots;
    }

    /// Returns the item ID at the given slot, or null if slot is out of bounds or empty.
    pub fn getSlot(self: ChiseledBookshelf, slot: u3) ?u16 {
        if (slot >= total_slots) return null;
        const item = self.slots[slot];
        return if (item != EmptySlot) item else null;
    }

    /// Manually sets a slot's item ID. Returns false if slot index is invalid.
    pub fn setSlot(self: *ChiseledBookshelf, slot: u3, item_id: u16) bool {
        if (slot >= total_slots) return false;
        self.slots[slot] = item_id;
        return true;
    }

    /// Returns true if the targeted slot contains a book.
    pub fn isSlotOccupied(self: ChiseledBookshelf, slot: u3) bool {
        if (slot >= total_slots) return false;
        return self.slots[slot] != EmptySlot;
    }

    /// Bitmask for visual rendering of the 6 book spines (bit i corresponds to slot i).
    /// Value is between 0b000000 (0, all empty) and 0b111111 (63, all full).
    pub fn occupiedMask(self: ChiseledBookshelf) u6 {
        var mask: u6 = 0;
        for (self.slots, 0..) |s, i| {
            if (s != EmptySlot) {
                mask |= @as(u6, 1) << @as(u3, @intCast(i));
            }
        }
        return mask;
    }

    /// Returns the redstone comparator signal (1..6) corresponding to last_interacted_slot + 1,
    /// or 0 if empty / never interacted with.
    /// Matches Minecraft 1.20 Chiseled Bookshelf redstone semantics.
    pub fn comparatorSignal(self: ChiseledBookshelf) u4 {
        if (self.last_interacted_slot) |slot| {
            return @as(u4, slot) + 1;
        }
        return 0;
    }

    /// Interacts with a specific slot on the bookshelf.
    /// If the slot is empty: inserts book if player is holding a book (held_is_book or valid book_item_id).
    /// If the slot is occupied: retrieves the book from the slot.
    /// Updates last_interacted_slot on successful insertion or retrieval.
    pub fn interactSlot(self: *ChiseledBookshelf, slot: u3, held_is_book: bool, book_item_id: u16) InteractResult {
        if (slot >= total_slots) {
            return .{ .action = .none, .item_id = EmptySlot, .slot = slot };
        }

        const current_item = self.slots[slot];
        if (current_item != EmptySlot) {
            // Retrieve book from occupied slot
            self.slots[slot] = EmptySlot;
            self.last_interacted_slot = slot;
            return .{
                .action = .retrieved,
                .item_id = current_item,
                .slot = slot,
            };
        } else {
            // Attempt to insert book into empty slot
            const can_insert = held_is_book or isBookItem(book_item_id);
            if (!can_insert) {
                return .{ .action = .none, .item_id = EmptySlot, .slot = slot };
            }

            const item_to_insert = if (book_item_id != EmptySlot) book_item_id else BookTag;
            self.slots[slot] = item_to_insert;
            self.last_interacted_slot = slot;
            return .{
                .action = .inserted,
                .item_id = item_to_insert,
                .slot = slot,
            };
        }
    }

    /// Clears all slots and resets last_interacted_slot.
    pub fn clear(self: *ChiseledBookshelf) void {
        self.slots = [_]u16{EmptySlot} ** total_slots;
        self.last_interacted_slot = null;
    }
};

/// Free function wrapper for interacting with a bookshelf slot.
pub fn interactSlot(shelf: *ChiseledBookshelf, slot: u3, held_is_book: bool, book_item_id: u16) InteractResult {
    return shelf.interactSlot(slot, held_is_book, book_item_id);
}

/// Free function wrapper for computing comparator signal.
pub fn comparatorSignal(shelf: ChiseledBookshelf) u4 {
    return shelf.comparatorSignal();
}

/// Free function wrapper for computing occupied spine bitmask.
pub fn occupiedMask(shelf: ChiseledBookshelf) u6 {
    return shelf.occupiedMask();
}

/// Find a chiseled bookshelf at coordinates (x, y, z) in an array.
pub fn findBookshelf(bookshelves: []const ChiseledBookshelf, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, bookshelves.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const shelf = bookshelves[i];
        if (shelf.x == x and shelf.y == y and shelf.z == z) return i;
    }
    return null;
}

// ---------------------------------------------------------------------------
// Unit Tests (Comprehensive 15-test suite)
// ---------------------------------------------------------------------------

test "constants and book item identification" {
    try std.testing.expectEqual(@as(usize, 32), max_chiseled_bookshelves);
    try std.testing.expectEqual(@as(usize, 6), total_slots);
    try std.testing.expectEqual(@as(u16, 0), EmptySlot);
    try std.testing.expectEqual(@as(u16, 270), BookTag);
    try std.testing.expectEqual(@as(u16, 400), EnchantedBookTag);
    try std.testing.expectEqual(@as(u16, 401), BookAndQuillTag);
    try std.testing.expectEqual(@as(u16, 402), WrittenBookTag);
    try std.testing.expectEqual(@as(u16, 403), KnowledgeTomeTag);

    // Valid books
    try std.testing.expect(isBookItem(BookTag));
    try std.testing.expect(isBookItem(EnchantedBookTag));
    try std.testing.expect(isBookItem(BookAndQuillTag));
    try std.testing.expect(isBookItem(WrittenBookTag));
    try std.testing.expect(isBookItem(KnowledgeTomeTag));

    // Invalid non-book items
    try std.testing.expect(!isBookItem(EmptySlot));
    try std.testing.expect(!isBookItem(1)); // stone
    try std.testing.expect(!isBookItem(7)); // wood planks
    try std.testing.expect(!isBookItem(999));
}

test "hitCoordsToSlot top row UV targeting (slots 0, 1, 2)" {
    // Top-left column -> Slot 0
    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.north, 0.1, 0.2));
    try std.testing.expectEqual(@as(u3, 0), uvToSlot(0.2, 0.1));

    // Top-middle column -> Slot 1
    try std.testing.expectEqual(@as(u3, 1), hitCoordsToSlot(.north, 0.5, 0.2));
    try std.testing.expectEqual(@as(u3, 1), uvToSlot(0.4, 0.3));

    // Top-right column -> Slot 2
    try std.testing.expectEqual(@as(u3, 2), hitCoordsToSlot(.north, 0.9, 0.2));
    try std.testing.expectEqual(@as(u3, 2), uvToSlot(0.8, 0.4));
}

test "hitCoordsToSlot bottom row UV targeting (slots 3, 4, 5)" {
    // Bottom-left column -> Slot 3
    try std.testing.expectEqual(@as(u3, 3), hitCoordsToSlot(.north, 0.1, 0.8));
    try std.testing.expectEqual(@as(u3, 3), uvToSlot(0.2, 0.6));

    // Bottom-middle column -> Slot 4
    try std.testing.expectEqual(@as(u3, 4), hitCoordsToSlot(.north, 0.5, 0.8));
    try std.testing.expectEqual(@as(u3, 4), uvToSlot(0.5, 0.7));

    // Bottom-right column -> Slot 5
    try std.testing.expectEqual(@as(u3, 5), hitCoordsToSlot(.north, 0.9, 0.8));
    try std.testing.expectEqual(@as(u3, 5), uvToSlot(0.85, 0.9));
}

test "hitCoordsToSlot boundary conditions and clamping" {
    // Exact corners
    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.north, 0.0, 0.0));
    try std.testing.expectEqual(@as(u3, 2), hitCoordsToSlot(.north, 1.0, 0.0));
    try std.testing.expectEqual(@as(u3, 3), hitCoordsToSlot(.north, 0.0, 1.0));
    try std.testing.expectEqual(@as(u3, 5), hitCoordsToSlot(.north, 1.0, 1.0));

    // Clamping out-of-range UV coordinates
    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.north, -0.5, -0.2));
    try std.testing.expectEqual(@as(u3, 5), hitCoordsToSlot(.north, 1.5, 1.8));

    // Precise column dividing thresholds (1/3 and 2/3)
    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.south, (1.0 / 3.0) - 0.001, 0.1));
    try std.testing.expectEqual(@as(u3, 1), hitCoordsToSlot(.south, (1.0 / 3.0) + 0.001, 0.1));
    try std.testing.expectEqual(@as(u3, 1), hitCoordsToSlot(.south, (2.0 / 3.0) - 0.001, 0.1));
    try std.testing.expectEqual(@as(u3, 2), hitCoordsToSlot(.south, (2.0 / 3.0) + 0.001, 0.1));

    // Precise row dividing threshold (0.5)
    try std.testing.expectEqual(@as(u3, 1), hitCoordsToSlot(.east, 0.5, 0.499));
    try std.testing.expectEqual(@as(u3, 4), hitCoordsToSlot(.east, 0.5, 0.501));
}

test "worldHitToFaceUV 3D coordinate mapping for all cardinal facings" {
    // North facing (front is at -Z): looking South, fx -> u, 1 - fy -> v
    const north_uv = worldHitToFaceUV(.north, 10.2, 5.8, 20.0, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), north_uv.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), north_uv.v, 0.001);
    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.north, north_uv.u, north_uv.v));

    // South facing (front is at +Z): looking North, 1 - fx -> u, 1 - fy -> v
    const south_uv = worldHitToFaceUV(.south, 10.2, 5.8, 21.0, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), south_uv.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), south_uv.v, 0.001);
    try std.testing.expectEqual(@as(u3, 2), hitCoordsToSlot(.south, south_uv.u, south_uv.v));

    // West facing (front is at -X): looking East, 1 - fz -> u, 1 - fy -> v
    const west_uv = worldHitToFaceUV(.west, 10.0, 5.2, 20.8, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), west_uv.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), west_uv.v, 0.001);
    try std.testing.expectEqual(@as(u3, 3), hitCoordsToSlot(.west, west_uv.u, west_uv.v));

    // East facing (front is at +X): looking West, fz -> u, 1 - fy -> v
    const east_uv = worldHitToFaceUV(.east, 11.0, 5.2, 20.8, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), east_uv.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), east_uv.v, 0.001);
    try std.testing.expectEqual(@as(u3, 5), hitCoordsToSlot(.east, east_uv.u, east_uv.v));

    // Up and Down are not accessible front faces
    try std.testing.expect(worldHitToFaceUV(.up, 10.5, 6.0, 20.5, 10, 5, 20) == null);
    try std.testing.expect(worldHitToFaceUV(.down, 10.5, 5.0, 20.5, 10, 5, 20) == null);
}

test "ChiseledBookshelf initialization and initial state" {
    const shelf = ChiseledBookshelf.init(5, 64, -12, .west);
    try std.testing.expectEqual(@as(i32, 5), shelf.x);
    try std.testing.expectEqual(@as(i32, 64), shelf.y);
    try std.testing.expectEqual(@as(i32, -12), shelf.z);
    try std.testing.expectEqual(Facing.west, shelf.facing);

    try std.testing.expectEqual(@as(u3, 0), shelf.bookCount());
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expect(!shelf.isFull());
    try std.testing.expect(shelf.last_interacted_slot == null);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0), shelf.occupiedMask());

    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        try std.testing.expect(!shelf.isSlotOccupied(s));
        try std.testing.expect(shelf.getSlot(s) == null);
    }
}

test "book insertion into empty slots updates slot, count, and last_interacted_slot" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);

    // Insert standard book into slot 0
    const res0 = shelf.interactSlot(0, true, BookTag);
    try std.testing.expectEqual(InteractAction.inserted, res0.action);
    try std.testing.expectEqual(BookTag, res0.item_id);
    try std.testing.expectEqual(@as(u3, 0), res0.slot);
    try std.testing.expect(res0.success());

    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());
    try std.testing.expectEqual(BookTag, shelf.getSlot(0).?);
    try std.testing.expectEqual(@as(?u3, 0), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(u4, 1), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0b000001), shelf.occupiedMask());

    // Insert enchanted book into slot 4
    const res4 = shelf.interactSlot(4, false, EnchantedBookTag);
    try std.testing.expectEqual(InteractAction.inserted, res4.action);
    try std.testing.expectEqual(EnchantedBookTag, res4.item_id);
    try std.testing.expectEqual(@as(u3, 4), res4.slot);

    try std.testing.expectEqual(@as(u3, 2), shelf.bookCount());
    try std.testing.expectEqual(EnchantedBookTag, shelf.getSlot(4).?);
    try std.testing.expectEqual(@as(?u3, 4), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(u4, 5), shelf.comparatorSignal()); // 4 + 1 = 5
    try std.testing.expectEqual(@as(u6, 0b010001), shelf.occupiedMask());
}

test "non-book items cannot be inserted into empty slots" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);

    // Stone item (tag 1) held, held_is_book = false
    const res = shelf.interactSlot(2, false, 1);
    try std.testing.expectEqual(InteractAction.none, res.action);
    try std.testing.expectEqual(EmptySlot, res.item_id);
    try std.testing.expect(!res.success());

    try std.testing.expect(shelf.isEmpty());
    try std.testing.expect(!shelf.isSlotOccupied(2));
    try std.testing.expect(shelf.last_interacted_slot == null);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0), shelf.occupiedMask());
}

test "book retrieval from occupied slot clears slot and returns item" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);
    _ = shelf.interactSlot(3, false, KnowledgeTomeTag);
    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());

    // Retrieve from slot 3 with empty hand (held_is_book = false, item_id = 0)
    const ret = shelf.interactSlot(3, false, EmptySlot);
    try std.testing.expectEqual(InteractAction.retrieved, ret.action);
    try std.testing.expectEqual(KnowledgeTomeTag, ret.item_id);
    try std.testing.expectEqual(@as(u3, 3), ret.slot);
    try std.testing.expect(ret.success());

    try std.testing.expect(shelf.isEmpty());
    try std.testing.expect(!shelf.isSlotOccupied(3));
    try std.testing.expect(shelf.getSlot(3) == null);
    try std.testing.expectEqual(@as(?u3, 3), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(u4, 4), shelf.comparatorSignal()); // 3 + 1 = 4
}

test "last-interacted comparator signal retention after removal" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());

    // Insert books into slot 1 and slot 5
    _ = shelf.interactSlot(1, false, BookTag);
    try std.testing.expectEqual(@as(u4, 2), shelf.comparatorSignal()); // 1 + 1 = 2

    _ = shelf.interactSlot(5, false, BookAndQuillTag);
    try std.testing.expectEqual(@as(u4, 6), shelf.comparatorSignal()); // 5 + 1 = 6

    // Remove book from slot 1 -> signal updates to slot 1 + 1 = 2
    const ret1 = shelf.interactSlot(1, false, EmptySlot);
    try std.testing.expectEqual(InteractAction.retrieved, ret1.action);
    try std.testing.expectEqual(@as(u4, 2), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(?u3, 1), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());

    // Remove book from slot 5 -> signal updates to slot 5 + 1 = 6
    // Even though shelf is now completely empty, comparator signal retains 6!
    const ret5 = shelf.interactSlot(5, false, EmptySlot);
    try std.testing.expectEqual(InteractAction.retrieved, ret5.action);
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expectEqual(@as(?u3, 5), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(u4, 6), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0), shelf.occupiedMask());
}

test "full shelf transition and bookCount tracking" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);

    const book_types = [_]u16{
        BookTag,
        EnchantedBookTag,
        BookAndQuillTag,
        WrittenBookTag,
        KnowledgeTomeTag,
        BookTag,
    };

    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        _ = shelf.interactSlot(s, false, book_types[s]);
        try std.testing.expectEqual(s + 1, shelf.bookCount());
    }

    try std.testing.expect(shelf.isFull());
    try std.testing.expect(!shelf.isEmpty());
    try std.testing.expectEqual(@as(u6, 0b111111), shelf.occupiedMask());

    // Interacting with full slot retrieves the book rather than inserting
    const ret_full = shelf.interactSlot(2, true, BookTag);
    try std.testing.expectEqual(InteractAction.retrieved, ret_full.action);
    try std.testing.expectEqual(BookAndQuillTag, ret_full.item_id);
    try std.testing.expectEqual(@as(u3, 5), shelf.bookCount());
    try std.testing.expect(!shelf.isFull());

    // Clear shelf resets all slots and comparator state
    shelf.clear();
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expectEqual(@as(u3, 0), shelf.bookCount());
    try std.testing.expect(shelf.last_interacted_slot == null);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0), shelf.occupiedMask());
}

test "occupiedMask bitmask states for visual spine rendering" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);

    // Test individual slot bitmask positions
    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        _ = shelf.setSlot(s, BookTag);
        const expected_bit = @as(u6, 1) << s;
        try std.testing.expectEqual(expected_bit, shelf.occupiedMask());
        _ = shelf.setSlot(s, EmptySlot);
    }

    // Combined multi-slot patterns:
    // Alternating slots: 0, 2, 4 -> bits 1, 4, 16 = 21 (0b010101)
    _ = shelf.setSlot(0, BookTag);
    _ = shelf.setSlot(2, EnchantedBookTag);
    _ = shelf.setSlot(4, WrittenBookTag);
    try std.testing.expectEqual(@as(u6, 0b010101), shelf.occupiedMask());
    try std.testing.expectEqual(@as(u6, 21), shelf.occupiedMask());

    // Add slot 5 -> bit 32 = 53 (0b110101)
    _ = shelf.setSlot(5, BookTag);
    try std.testing.expectEqual(@as(u6, 0b110101), shelf.occupiedMask());
    try std.testing.expectEqual(@as(u6, 53), shelf.occupiedMask());
}

test "comparatorSignal 1..6 coverage for all six slots" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);

    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        _ = shelf.interactSlot(s, false, BookTag);
        const expected_signal: u4 = @as(u4, s) + 1;
        try std.testing.expectEqual(expected_signal, shelf.comparatorSignal());
        try std.testing.expectEqual(expected_signal, comparatorSignal(shelf));

        // Free wrapper function interactSlot
        const ret = interactSlot(&shelf, s, false, EmptySlot);
        try std.testing.expectEqual(InteractAction.retrieved, ret.action);
        try std.testing.expectEqual(expected_signal, shelf.comparatorSignal());

        // Clear shelf back to 0
        shelf.clear();
        try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    }
}

test "invalid slot index safety (slot >= 6)" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);

    // Out of bounds interaction (slots 6 and 7)
    const res6 = shelf.interactSlot(6, true, BookTag);
    try std.testing.expectEqual(InteractAction.none, res6.action);
    try std.testing.expect(!res6.success());

    const res7 = interactSlot(&shelf, 7, false, EmptySlot);
    try std.testing.expectEqual(InteractAction.none, res7.action);

    try std.testing.expect(shelf.getSlot(6) == null);
    try std.testing.expect(!shelf.isSlotOccupied(6));
    try std.testing.expect(!shelf.setSlot(6, BookTag));
}

test "findBookshelf spatial lookup in array" {
    var shelves = [_]ChiseledBookshelf{
        ChiseledBookshelf.init(10, 64, 20, .north),
        ChiseledBookshelf.init(15, 65, -30, .east),
        ChiseledBookshelf.init(-5, 70, 42, .south),
    };

    try std.testing.expectEqual(@as(?usize, 0), findBookshelf(&shelves, shelves.len, 10, 64, 20));
    try std.testing.expectEqual(@as(?usize, 1), findBookshelf(&shelves, shelves.len, 15, 65, -30));
    try std.testing.expectEqual(@as(?usize, 2), findBookshelf(&shelves, shelves.len, -5, 70, 42));

    // Non-existent positions
    try std.testing.expect(findBookshelf(&shelves, shelves.len, 99, 99, 99) == null);
    try std.testing.expect(findBookshelf(&shelves, shelves.len, 10, 64, 21) == null);

    // Count bound limit
    try std.testing.expect(findBookshelf(&shelves, 1, 15, 65, -30) == null);
}
