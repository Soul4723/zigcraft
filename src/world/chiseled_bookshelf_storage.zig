//! Milestone 444: Chiseled Bookshelf UV Face Targeting & Comparator Signal
//!
//! Implements the complete Minecraft 1.20+ compliant Chiseled Bookshelf storage mechanics:
//! 1. Chiseled Bookshelf Storage (6 slots):
//!    - 6 discrete book storage slots organized in a 3x2 matrix on the front face:
//!      - Top row: slot 0 (top-left), slot 1 (top-center), slot 2 (top-right).
//!      - Bottom row: slot 3 (bottom-left), slot 4 (bottom-center), slot 5 (bottom-right).
//!    - Accepted book items: Book, Written Book, Book and Quill, Enchanted Book.
//! 2. Front Face UV Targeting:
//!    - Evaluates face UV hit coordinates (u in 0.0..1.0, v in 0.0..1.0) on the front face.
//!    - Horizontal column: u < 0.333 -> left (col 0), u < 0.666 -> center (col 1), else right (col 2).
//!    - Vertical row: v >= 0.50 -> top row (row 0), v < 0.50 -> bottom row (row 1).
//!    - Slot index = row * 3 + col (0..5).
//! 3. Slot Interaction Mechanics:
//!    - Right-clicking empty slot with a valid book item inserts the book and marks slot occupied.
//!    - Right-clicking an occupied slot extracts the stored book item and clears the slot.
//!    - Tracks last_interacted_slot (1..6).
//! 4. Redstone Comparator Signal Output:
//!    - Emits signal strength equal to the index of the last interacted slot plus one (values 1..6).
//!    - Signal is 0 if no slot has been interacted with yet or if bookshelf is empty.

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Maximum number of chiseled bookshelves tracked in a single spatial collection.
pub const max_chiseled_bookshelves: usize = 32;

/// Total number of book slots in a chiseled bookshelf (3 columns x 2 rows).
pub const total_slots: usize = 6;

/// Number of columns on the front face (3 columns: left, center, right).
pub const num_columns: usize = 3;

/// Number of rows on the front face (2 rows: top, bottom).
pub const num_rows: usize = 2;

// Front face UV column and row boundary thresholds
pub const col_left_threshold: f32 = 0.333;
pub const col_center_threshold: f32 = 0.666;
pub const row_vertical_threshold: f32 = 0.50;

// Redstone signal bounds
pub const min_comparator_signal: u4 = 0;
pub const max_comparator_signal: u4 = 6;

// Empty slot marker
pub const EmptySlot: u16 = 0;

// Primary standard item tags (mirrors inventory.zig ItemType)
pub const BookTag: u16 = 270;
pub const EnchantedBookTag: u16 = 440;
pub const BookAndQuillTag: u16 = 499;
pub const WrittenBookTag: u16 = 500;

// Legacy and specialized book item tags
pub const LegacyEnchantedBookTag: u16 = 400;
pub const LegacyBookAndQuillTag: u16 = 401;
pub const LegacyWrittenBookTag: u16 = 402;
pub const KnowledgeTomeTag: u16 = 403;
pub const MendingBookTag: u16 = 441;
pub const SwiftSneakBookTag: u16 = 470;
pub const SweepingEdgeBookTag: u16 = 474;
pub const FeatherFallingBookTag: u16 = 479;

// ============================================================================
// Enums & Types
// ============================================================================

/// Accepted book items according to Milestone 444 specification:
/// Book, Written Book, Book and Quill, Enchanted Book (and their enchanted variants).
pub const BookItem = enum(u16) {
    book = BookTag,
    enchanted_book = EnchantedBookTag,
    book_and_quill = BookAndQuillTag,
    written_book = WrittenBookTag,

    pub fn toId(self: BookItem) u16 {
        return @intFromEnum(self);
    }

    pub fn name(self: BookItem) []const u8 {
        return switch (self) {
            .book => "Book",
            .enchanted_book => "Enchanted Book",
            .book_and_quill => "Book and Quill",
            .written_book => "Written Book",
        };
    }
};

/// 2-row vertical matrix partition for front face UV targeting.
pub const SlotRow = enum(u1) {
    top = 0,
    bottom = 1,

    pub fn toIndex(self: SlotRow) u1 {
        return @intFromEnum(self);
    }
};

/// 3-column horizontal matrix partition for front face UV targeting.
pub const SlotCol = enum(u2) {
    left = 0,
    center = 1,
    right = 2,

    pub fn toIndex(self: SlotCol) u2 {
        return @intFromEnum(self);
    }
};

/// 6 discrete slot identifiers on the front face (3x2 matrix).
pub const SlotId = enum(u3) {
    top_left = 0,
    top_center = 1,
    top_right = 2,
    bottom_left = 3,
    bottom_center = 4,
    bottom_right = 5,

    pub fn toIndex(self: SlotId) u3 {
        return @intFromEnum(self);
    }

    pub fn fromRowCol(r: SlotRow, c: SlotCol) SlotId {
        const idx: u3 = @as(u3, r.toIndex()) * 3 + @as(u3, c.toIndex());
        return @enumFromInt(idx);
    }

    pub fn row(self: SlotId) SlotRow {
        return if (@intFromEnum(self) < 3) .top else .bottom;
    }

    pub fn col(self: SlotId) SlotCol {
        return @enumFromInt(@intFromEnum(self) % 3);
    }

    pub fn comparatorSignal(self: SlotId) u4 {
        return @as(u4, @intFromEnum(self)) + 1;
    }
};

/// Discrete UV slot coordinates.
pub const SlotCoords = struct {
    row: u1,
    col: u2,
    slot: u3,
};

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

/// Normalized 2D UV hit coordinates on a block face.
pub const UVHit = struct {
    u: f32,
    v: f32,
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

// ============================================================================
// Book Item Validation
// ============================================================================

/// Returns true if the item tag represents an acceptable book item:
/// - Book (Tag 270)
/// - Written Book (Tag 500, legacy 402)
/// - Book and Quill (Tag 499, legacy 401)
/// - Enchanted Book (Tag 440, legacy 400, variants 441, 470, 474, 479)
/// - Knowledge Tome (Tag 403)
pub fn isAcceptedBook(item_id: u16) bool {
    return switch (item_id) {
        BookTag,
        EnchantedBookTag,
        BookAndQuillTag,
        WrittenBookTag,
        LegacyEnchantedBookTag,
        LegacyBookAndQuillTag,
        LegacyWrittenBookTag,
        KnowledgeTomeTag,
        MendingBookTag,
        SwiftSneakBookTag,
        SweepingEdgeBookTag,
        FeatherFallingBookTag,
        => true,
        else => false,
    };
}

/// Convenience alias for book item validation.
pub fn isBookItem(item_id: u16) bool {
    return isAcceptedBook(item_id);
}

// ============================================================================
// UV Face Targeting Functions
// ============================================================================

/// Evaluates horizontal UV coordinate u (clamped to 0.0..1.0):
/// - u < 0.333 -> left (col 0)
/// - u < 0.666 -> center (col 1)
/// - else -> right (col 2)
pub fn uvToCol(u: f32) u2 {
    const clamped_u = std.math.clamp(u, 0.0, 1.0);
    if (clamped_u < col_left_threshold) {
        return 0;
    } else if (clamped_u < col_center_threshold) {
        return 1;
    } else {
        return 2;
    }
}

/// Evaluates vertical UV coordinate v (clamped to 0.0..1.0):
/// - v >= 0.50 -> top row (row 0)
/// - v < 0.50 -> bottom row (row 1)
pub fn uvToRow(v: f32) u1 {
    const clamped_v = std.math.clamp(v, 0.0, 1.0);
    return if (clamped_v >= row_vertical_threshold) 0 else 1;
}

/// Evaluates face UV hit coordinates (u in 0.0..1.0, v in 0.0..1.0) on the front face:
/// - Horizontal column: u < 0.333 -> left (col 0), u < 0.666 -> center (col 1), else right (col 2).
/// - Vertical row: v >= 0.50 -> top row (row 0), v < 0.50 -> bottom row (row 1).
/// - Slot index = `row * 3 + col` (0..5).
pub fn uvToSlot(u: f32, v: f32) u3 {
    const row: u3 = uvToRow(v);
    const col: u3 = uvToCol(u);
    return row * 3 + col;
}

/// Returns full row, column, and slot indices from face UV coordinates.
pub fn uvToSlotCoords(u: f32, v: f32) SlotCoords {
    const row = uvToRow(v);
    const col = uvToCol(u);
    const slot: u3 = @as(u3, row) * 3 + @as(u3, col);
    return .{
        .row = row,
        .col = col,
        .slot = slot,
    };
}

/// Helper mapping facing + UV hit coordinates onto slot index 0..5.
pub fn hitCoordsToSlot(facing: Facing, hit_u: f32, hit_v: f32) u3 {
    _ = facing;
    return uvToSlot(hit_u, hit_v);
}

/// Converts world ray hit coordinates on a block face to normalized face UV (u, v in 0.0..1.0).
/// Front face mapping:
/// - Vertical coordinate v: fy in 0.0..1.0 (bottom = 0.0, top = 1.0; v >= 0.50 is top row).
/// - Horizontal coordinate u:
///   - North facing (normal -Z): looking South (+Z), West (-X) is left -> u = fx.
///   - South facing (normal +Z): looking North (-Z), East (+X) is left -> u = 1.0 - fx.
///   - West facing (normal -X): looking East (+X), North (-Z) is left -> u = fz.
///   - East facing (normal +X): looking West (-X), South (+Z) is left -> u = 1.0 - fz.
/// Returns null for non-front faces (up, down).
pub fn worldHitToFaceUV(
    facing: Facing,
    hit_x: f32,
    hit_y: f32,
    hit_z: f32,
    block_x: i32,
    block_y: i32,
    block_z: i32,
) ?UVHit {
    const fx = hit_x - @as(f32, @floatFromInt(block_x));
    const fy = hit_y - @as(f32, @floatFromInt(block_y));
    const fz = hit_z - @as(f32, @floatFromInt(block_z));

    const v = std.math.clamp(fy, 0.0, 1.0);

    const u = switch (facing) {
        .north => std.math.clamp(fx, 0.0, 1.0),
        .south => std.math.clamp(1.0 - fx, 0.0, 1.0),
        .west => std.math.clamp(fz, 0.0, 1.0),
        .east => std.math.clamp(1.0 - fz, 0.0, 1.0),
        .up, .down => return null,
    };

    return .{ .u = u, .v = v };
}

/// Converts world ray hit coordinates on a block face directly to slot index 0..5.
pub fn worldHitToSlot(
    facing: Facing,
    hit_x: f32,
    hit_y: f32,
    hit_z: f32,
    block_x: i32,
    block_y: i32,
    block_z: i32,
) ?u3 {
    if (worldHitToFaceUV(facing, hit_x, hit_y, hit_z, block_x, block_y, block_z)) |uv| {
        return uvToSlot(uv.u, uv.v);
    }
    return null;
}

// ============================================================================
// ChiseledBookshelfStorage Struct
// ============================================================================

/// Represents a 6-slot directional Chiseled Bookshelf storage container.
///
/// Front face slot layout (3x2 matrix):
/// - Top row (v >= 0.50):
///   - Slot 0: Top-Left    (u < 0.333, v >= 0.50)
///   - Slot 1: Top-Center  (0.333 <= u < 0.666, v >= 0.50)
///   - Slot 2: Top-Right   (u >= 0.666, v >= 0.50)
/// - Bottom row (v < 0.50):
///   - Slot 3: Bottom-Left   (u < 0.333, v < 0.50)
///   - Slot 4: Bottom-Center (0.333 <= u < 0.666, v < 0.50)
///   - Slot 5: Bottom-Right  (u >= 0.666, v < 0.50)
///
/// Redstone comparator output:
/// - Emits signal strength equal to (last_interacted_slot + 1), which is 1..6.
/// - Emits 0 if no slot has been interacted with yet or if bookshelf is empty.
pub const ChiseledBookshelfStorage = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    facing: Facing = .north,
    slots: [total_slots]u16 = [_]u16{EmptySlot} ** total_slots,
    last_interacted_slot: ?u3 = null,

    pub fn init(x: i32, y: i32, z: i32, facing: Facing) ChiseledBookshelfStorage {
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
    pub fn bookCount(self: ChiseledBookshelfStorage) u3 {
        var count: u3 = 0;
        for (self.slots) |s| {
            if (s != EmptySlot) count += 1;
        }
        return count;
    }

    /// True if no books are stored in any of the 6 slots.
    pub fn isEmpty(self: ChiseledBookshelfStorage) bool {
        return self.bookCount() == 0;
    }

    /// True if all 6 slots are occupied with books.
    pub fn isFull(self: ChiseledBookshelfStorage) bool {
        return self.bookCount() == total_slots;
    }

    /// Returns the item ID at the given slot (0..5), or null if slot is out of bounds or empty.
    pub fn getSlot(self: ChiseledBookshelfStorage, slot: u3) ?u16 {
        if (slot >= total_slots) return null;
        const item = self.slots[slot];
        return if (item != EmptySlot) item else null;
    }

    /// Manually sets a slot's item ID. Returns false if slot index is invalid.
    pub fn setSlot(self: *ChiseledBookshelfStorage, slot: u3, item_id: u16) bool {
        if (slot >= total_slots) return false;
        self.slots[slot] = item_id;
        return true;
    }

    /// Returns true if the targeted slot contains a stored book.
    pub fn isSlotOccupied(self: ChiseledBookshelfStorage, slot: u3) bool {
        if (slot >= total_slots) return false;
        return self.slots[slot] != EmptySlot;
    }

    /// Bitmask for visual rendering of the 6 book spines (bit i corresponds to slot i).
    /// Value is between 0b000000 (0, all empty) and 0b111111 (63, all full).
    pub fn occupiedMask(self: ChiseledBookshelfStorage) u6 {
        var mask: u6 = 0;
        for (self.slots, 0..) |s, i| {
            if (s != EmptySlot) {
                mask |= @as(u6, 1) << @as(u3, @intCast(i));
            }
        }
        return mask;
    }

    /// Returns the 0-indexed last interacted slot (0..5), or null if un-interacted.
    pub fn getLastInteractedSlotIndex(self: ChiseledBookshelfStorage) ?u3 {
        return self.last_interacted_slot;
    }

    /// Returns the 1-based last interacted slot number (1..6), or null if un-interacted.
    pub fn getLastInteractedSlotNumber(self: ChiseledBookshelfStorage) ?u4 {
        if (self.last_interacted_slot) |slot| {
            return @as(u4, slot) + 1;
        }
        return null;
    }

    /// Returns the redstone comparator signal output:
    /// - Emits signal strength equal to the index of the last interacted slot plus one (values 1..6).
    /// - Signal is 0 if no slot has been interacted with yet or if bookshelf is empty.
    pub fn comparatorSignal(self: ChiseledBookshelfStorage) u4 {
        if (self.isEmpty()) return 0;
        if (self.last_interacted_slot) |slot| {
            return @as(u4, slot) + 1;
        }
        return 0;
    }

    /// Interacts with a specific slot on the bookshelf:
    /// - If the slot is empty: inserts book if player is holding a valid book (Book, Written Book, Book and Quill, Enchanted Book).
    /// - If the slot is occupied: extracts stored book and clears the slot.
    /// - Tracks last_interacted_slot (1..6 via index 0..5).
    pub fn interactSlot(
        self: *ChiseledBookshelfStorage,
        slot: u3,
        held_is_book: bool,
        book_item_id: u16,
    ) InteractResult {
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

    /// High-level interaction taking an item ID directly.
    pub fn interactWithItem(self: *ChiseledBookshelfStorage, slot: u3, item_id: u16) InteractResult {
        return self.interactSlot(slot, isBookItem(item_id), item_id);
    }

    /// High-level interaction taking face UV hit coordinates directly.
    pub fn interactUV(
        self: *ChiseledBookshelfStorage,
        u: f32,
        v: f32,
        held_is_book: bool,
        book_item_id: u16,
    ) InteractResult {
        const slot = uvToSlot(u, v);
        return self.interactSlot(slot, held_is_book, book_item_id);
    }

    /// Clears all slots and resets last_interacted_slot.
    pub fn clear(self: *ChiseledBookshelfStorage) void {
        self.slots = [_]u16{EmptySlot} ** total_slots;
        self.last_interacted_slot = null;
    }
};

/// Type alias for compatibility.
pub const ChiseledBookshelf = ChiseledBookshelfStorage;

// ============================================================================
// Free Functions
// ============================================================================

/// Free function wrapper for interacting with a bookshelf slot.
pub fn interactSlot(
    shelf: *ChiseledBookshelfStorage,
    slot: u3,
    held_is_book: bool,
    book_item_id: u16,
) InteractResult {
    return shelf.interactSlot(slot, held_is_book, book_item_id);
}

/// Free function wrapper for computing redstone comparator signal.
pub fn comparatorSignal(shelf: ChiseledBookshelfStorage) u4 {
    return shelf.comparatorSignal();
}

/// Free function wrapper for computing occupied spine bitmask.
pub fn occupiedMask(shelf: ChiseledBookshelfStorage) u6 {
    return shelf.occupiedMask();
}

/// Find a chiseled bookshelf at coordinates (x, y, z) in an array.
pub fn findBookshelf(
    bookshelves: []const ChiseledBookshelfStorage,
    count: usize,
    x: i32,
    y: i32,
    z: i32,
) ?usize {
    const n = @min(count, bookshelves.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const shelf = bookshelves[i];
        if (shelf.x == x and shelf.y == y and shelf.z == z) return i;
    }
    return null;
}

// ============================================================================
// Unit Tests (Comprehensive 20+ Test Suite)
// ============================================================================

test "1. Constants: slot counts, matrix dimensions, and thresholds" {
    try std.testing.expectEqual(@as(usize, 6), total_slots);
    try std.testing.expectEqual(@as(usize, 32), max_chiseled_bookshelves);
    try std.testing.expectEqual(@as(usize, 3), num_columns);
    try std.testing.expectEqual(@as(usize, 2), num_rows);

    try std.testing.expectApproxEqAbs(@as(f32, 0.333), col_left_threshold, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.666), col_center_threshold, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), row_vertical_threshold, 0.0001);

    try std.testing.expectEqual(@as(u4, 0), min_comparator_signal);
    try std.testing.expectEqual(@as(u4, 6), max_comparator_signal);
    try std.testing.expectEqual(@as(u16, 0), EmptySlot);
}

test "2. Accepted book items: Book, Written Book, Book and Quill, Enchanted Book" {
    // Standard Minecraft items specified in Milestone 444
    try std.testing.expect(isAcceptedBook(BookTag));
    try std.testing.expect(isAcceptedBook(WrittenBookTag));
    try std.testing.expect(isAcceptedBook(BookAndQuillTag));
    try std.testing.expect(isAcceptedBook(EnchantedBookTag));

    // BookItem enum methods
    try std.testing.expectEqualStrings("Book", BookItem.book.name());
    try std.testing.expectEqualStrings("Enchanted Book", BookItem.enchanted_book.name());
    try std.testing.expectEqualStrings("Book and Quill", BookItem.book_and_quill.name());
    try std.testing.expectEqualStrings("Written Book", BookItem.written_book.name());

    // Legacy and specialized variants
    try std.testing.expect(isAcceptedBook(LegacyEnchantedBookTag));
    try std.testing.expect(isAcceptedBook(LegacyBookAndQuillTag));
    try std.testing.expect(isAcceptedBook(LegacyWrittenBookTag));
    try std.testing.expect(isAcceptedBook(KnowledgeTomeTag));
    try std.testing.expect(isAcceptedBook(MendingBookTag));
    try std.testing.expect(isAcceptedBook(SwiftSneakBookTag));
    try std.testing.expect(isAcceptedBook(SweepingEdgeBookTag));
    try std.testing.expect(isAcceptedBook(FeatherFallingBookTag));

    // Convenience alias isBookItem
    try std.testing.expect(isBookItem(BookTag));
    try std.testing.expect(isBookItem(WrittenBookTag));
    try std.testing.expect(isBookItem(BookAndQuillTag));
    try std.testing.expect(isBookItem(EnchantedBookTag));
}

test "3. Non-book item rejection in isAcceptedBook and isBookItem" {
    try std.testing.expect(!isAcceptedBook(EmptySlot));
    try std.testing.expect(!isAcceptedBook(1)); // Stone
    try std.testing.expect(!isAcceptedBook(2)); // Grass block
    try std.testing.expect(!isAcceptedBook(3)); // Dirt
    try std.testing.expect(!isAcceptedBook(5)); // Wood planks
    try std.testing.expect(!isAcceptedBook(264)); // Diamond
    try std.testing.expect(!isAcceptedBook(999));

    try std.testing.expect(!isBookItem(EmptySlot));
    try std.testing.expect(!isBookItem(1));
    try std.testing.expect(!isBookItem(264));
}

test "4. UV coordinate targeting: top row slots 0, 1, 2 (v >= 0.50)" {
    // Slot 0: Top-Left (u < 0.333, v >= 0.50)
    try std.testing.expectEqual(@as(u3, 0), uvToSlot(0.15, 0.75));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.75));
    try std.testing.expectEqual(@as(u2, 0), uvToCol(0.15));

    // Slot 1: Top-Center (0.333 <= u < 0.666, v >= 0.50)
    try std.testing.expectEqual(@as(u3, 1), uvToSlot(0.50, 0.75));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.75));
    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.50));

    // Slot 2: Top-Right (u >= 0.666, v >= 0.50)
    try std.testing.expectEqual(@as(u3, 2), uvToSlot(0.85, 0.75));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.75));
    try std.testing.expectEqual(@as(u2, 2), uvToCol(0.85));
}

test "5. UV coordinate targeting: bottom row slots 3, 4, 5 (v < 0.50)" {
    // Slot 3: Bottom-Left (u < 0.333, v < 0.50)
    try std.testing.expectEqual(@as(u3, 3), uvToSlot(0.15, 0.25));
    try std.testing.expectEqual(@as(u1, 1), uvToRow(0.25));
    try std.testing.expectEqual(@as(u2, 0), uvToCol(0.15));

    // Slot 4: Bottom-Center (0.333 <= u < 0.666, v < 0.50)
    try std.testing.expectEqual(@as(u3, 4), uvToSlot(0.50, 0.25));
    try std.testing.expectEqual(@as(u1, 1), uvToRow(0.25));
    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.50));

    // Slot 5: Bottom-Right (u >= 0.666, v < 0.50)
    try std.testing.expectEqual(@as(u3, 5), uvToSlot(0.85, 0.25));
    try std.testing.expectEqual(@as(u1, 1), uvToRow(0.25));
    try std.testing.expectEqual(@as(u2, 2), uvToCol(0.85));
}

test "6. UV coordinate mapping: all 6 discrete slot regions (slots 0..5)" {
    const test_points = [_]struct { u: f32, v: f32, expected_slot: u3, expected_row: u1, expected_col: u2 }{
        .{ .u = 0.10, .v = 0.90, .expected_slot = 0, .expected_row = 0, .expected_col = 0 },
        .{ .u = 0.50, .v = 0.90, .expected_slot = 1, .expected_row = 0, .expected_col = 1 },
        .{ .u = 0.90, .v = 0.90, .expected_slot = 2, .expected_row = 0, .expected_col = 2 },
        .{ .u = 0.10, .v = 0.10, .expected_slot = 3, .expected_row = 1, .expected_col = 0 },
        .{ .u = 0.50, .v = 0.10, .expected_slot = 4, .expected_row = 1, .expected_col = 1 },
        .{ .u = 0.90, .v = 0.10, .expected_slot = 5, .expected_row = 1, .expected_col = 2 },
    };

    for (test_points) |pt| {
        try std.testing.expectEqual(pt.expected_slot, uvToSlot(pt.u, pt.v));
        const coords = uvToSlotCoords(pt.u, pt.v);
        try std.testing.expectEqual(pt.expected_row, coords.row);
        try std.testing.expectEqual(pt.expected_col, coords.col);
        try std.testing.expectEqual(pt.expected_slot, coords.slot);
    }
}

test "7. UV boundary testing: horizontal thresholds (0.0, 0.333, 0.666, 1.0)" {
    // 0.0 -> left (col 0)
    try std.testing.expectEqual(@as(u2, 0), uvToCol(0.0));
    try std.testing.expectEqual(@as(u2, 0), uvToCol(0.332));

    // 0.333 -> not < 0.333, but < 0.666 -> center (col 1)
    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.333));
    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.50));
    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.665));

    // 0.666 -> not < 0.666 -> right (col 2)
    try std.testing.expectEqual(@as(u2, 2), uvToCol(0.666));
    try std.testing.expectEqual(@as(u2, 2), uvToCol(0.999));
    try std.testing.expectEqual(@as(u2, 2), uvToCol(1.0));
}

test "8. UV boundary testing: vertical threshold (0.0, 0.50, 1.0)" {
    // 0.0 -> bottom row (row 1)
    try std.testing.expectEqual(@as(u1, 1), uvToRow(0.0));
    try std.testing.expectEqual(@as(u1, 1), uvToRow(0.499));

    // 0.50 -> top row (row 0)
    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.50));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.501));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(1.0));
}

test "9. UV boundary testing: four face corners and intersection points" {
    // Exact corners
    try std.testing.expectEqual(@as(u3, 0), uvToSlot(0.0, 1.0)); // Top-Left
    try std.testing.expectEqual(@as(u3, 2), uvToSlot(1.0, 1.0)); // Top-Right
    try std.testing.expectEqual(@as(u3, 3), uvToSlot(0.0, 0.0)); // Bottom-Left
    try std.testing.expectEqual(@as(u3, 5), uvToSlot(1.0, 0.0)); // Bottom-Right

    // Threshold junction intersections
    try std.testing.expectEqual(@as(u3, 1), uvToSlot(0.333, 0.50)); // Top-Center boundary
    try std.testing.expectEqual(@as(u3, 2), uvToSlot(0.666, 0.50)); // Top-Right boundary
    try std.testing.expectEqual(@as(u3, 4), uvToSlot(0.333, 0.499)); // Bottom-Center boundary
    try std.testing.expectEqual(@as(u3, 5), uvToSlot(0.666, 0.499)); // Bottom-Right boundary
}

test "10. UV out-of-range clamping: negative and exceeding 1.0 coordinates" {
    // Clamping coordinates < 0.0 or > 1.0
    try std.testing.expectEqual(@as(u3, 3), uvToSlot(-0.5, -0.2)); // Clamped to (0.0, 0.0) -> slot 3
    try std.testing.expectEqual(@as(u3, 2), uvToSlot(1.5, 1.8)); // Clamped to (1.0, 1.0) -> slot 2
    try std.testing.expectEqual(@as(u3, 0), uvToSlot(-10.0, 5.0)); // Clamped to (0.0, 1.0) -> slot 0
    try std.testing.expectEqual(@as(u3, 5), uvToSlot(10.0, -5.0)); // Clamped to (1.0, 0.0) -> slot 5

    // hitCoordsToSlot wrapper
    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.north, 0.1, 0.9));
    try std.testing.expectEqual(@as(u3, 4), hitCoordsToSlot(.south, 0.5, 0.2));
}

test "11. 3D world raycast hit conversion to face UV across all cardinal facings" {
    // North facing (front at -Z): fx -> u, fy -> v
    const north_hit = worldHitToFaceUV(.north, 10.2, 5.8, 20.0, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), north_hit.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), north_hit.v, 0.001);
    try std.testing.expectEqual(@as(u3, 0), worldHitToSlot(.north, 10.2, 5.8, 20.0, 10, 5, 20).?);

    // South facing (front at +Z): 1.0 - fx -> u, fy -> v
    const south_hit = worldHitToFaceUV(.south, 10.2, 5.8, 21.0, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), south_hit.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), south_hit.v, 0.001);
    try std.testing.expectEqual(@as(u3, 2), worldHitToSlot(.south, 10.2, 5.8, 21.0, 10, 5, 20).?);

    // West facing (front at -X): fz -> u, fy -> v
    const west_hit = worldHitToFaceUV(.west, 10.0, 5.2, 20.2, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), west_hit.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), west_hit.v, 0.001);
    try std.testing.expectEqual(@as(u3, 3), worldHitToSlot(.west, 10.0, 5.2, 20.2, 10, 5, 20).?);

    // East facing (front at +X): 1.0 - fz -> u, fy -> v
    const east_hit = worldHitToFaceUV(.east, 11.0, 5.2, 20.2, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), east_hit.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), east_hit.v, 0.001);
    try std.testing.expectEqual(@as(u3, 5), worldHitToSlot(.east, 11.0, 5.2, 20.2, 10, 5, 20).?);

    // Up and Down faces cannot be targeted
    try std.testing.expect(worldHitToFaceUV(.up, 10.5, 6.0, 20.5, 10, 5, 20) == null);
    try std.testing.expect(worldHitToFaceUV(.down, 10.5, 5.0, 20.5, 10, 5, 20) == null);
    try std.testing.expect(worldHitToSlot(.up, 10.5, 6.0, 20.5, 10, 5, 20) == null);
}

test "12. ChiseledBookshelfStorage initialization and empty state" {
    const shelf = ChiseledBookshelfStorage.init(100, 64, -200, .south);
    try std.testing.expectEqual(@as(i32, 100), shelf.x);
    try std.testing.expectEqual(@as(i32, 64), shelf.y);
    try std.testing.expectEqual(@as(i32, -200), shelf.z);
    try std.testing.expectEqual(Facing.south, shelf.facing);

    try std.testing.expectEqual(@as(u3, 0), shelf.bookCount());
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expect(!shelf.isFull());
    try std.testing.expect(shelf.last_interacted_slot == null);
    try std.testing.expect(shelf.getLastInteractedSlotIndex() == null);
    try std.testing.expect(shelf.getLastInteractedSlotNumber() == null);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0), shelf.occupiedMask());

    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        try std.testing.expect(!shelf.isSlotOccupied(s));
        try std.testing.expect(shelf.getSlot(s) == null);
    }
}

test "13. Slot interaction: book insertion into empty slot marks occupied and stores item" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    // Insert Book into slot 0
    const res0 = shelf.interactSlot(0, true, BookTag);
    try std.testing.expect(res0.success());
    try std.testing.expectEqual(InteractAction.inserted, res0.action);
    try std.testing.expectEqual(BookTag, res0.item_id);
    try std.testing.expectEqual(@as(u3, 0), res0.slot);

    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());
    try std.testing.expect(shelf.isSlotOccupied(0));
    try std.testing.expectEqual(BookTag, shelf.getSlot(0).?);
    try std.testing.expectEqual(@as(?u3, 0), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(?u4, 1), shelf.getLastInteractedSlotNumber());
    try std.testing.expectEqual(@as(u4, 1), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0b000001), shelf.occupiedMask());

    // Insert Enchanted Book into slot 2
    const res2 = shelf.interactSlot(2, false, EnchantedBookTag);
    try std.testing.expect(res2.success());
    try std.testing.expectEqual(InteractAction.inserted, res2.action);
    try std.testing.expectEqual(EnchantedBookTag, res2.item_id);

    try std.testing.expectEqual(@as(u3, 2), shelf.bookCount());
    try std.testing.expect(shelf.isSlotOccupied(2));
    try std.testing.expectEqual(EnchantedBookTag, shelf.getSlot(2).?);
    try std.testing.expectEqual(@as(?u3, 2), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(?u4, 3), shelf.getLastInteractedSlotNumber());
    try std.testing.expectEqual(@as(u4, 3), shelf.comparatorSignal()); // 2 + 1 = 3
    try std.testing.expectEqual(@as(u6, 0b000101), shelf.occupiedMask());
}

test "14. Slot interaction: book extraction from occupied slot clears slot and returns item" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    // Insert Book and Quill into slot 3
    _ = shelf.interactSlot(3, false, BookAndQuillTag);
    try std.testing.expect(shelf.isSlotOccupied(3));
    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());

    // Extract with empty hand (held_is_book = false, item_id = 0)
    const ret3 = shelf.interactSlot(3, false, EmptySlot);
    try std.testing.expect(ret3.success());
    try std.testing.expectEqual(InteractAction.retrieved, ret3.action);
    try std.testing.expectEqual(BookAndQuillTag, ret3.item_id);
    try std.testing.expectEqual(@as(u3, 3), ret3.slot);

    // Slot 3 should now be cleared
    try std.testing.expect(!shelf.isSlotOccupied(3));
    try std.testing.expect(shelf.getSlot(3) == null);
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expectEqual(@as(u3, 0), shelf.bookCount());
    try std.testing.expectEqual(@as(?u3, 3), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(?u4, 4), shelf.getLastInteractedSlotNumber());
}

test "15. Slot interaction: non-book item insertion rejection leaves slot empty" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    // Attempt to insert cobblestone (id 4)
    const rej1 = shelf.interactSlot(1, false, 4);
    try std.testing.expect(!rej1.success());
    try std.testing.expectEqual(InteractAction.none, rej1.action);
    try std.testing.expectEqual(EmptySlot, rej1.item_id);
    try std.testing.expect(!shelf.isSlotOccupied(1));
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expect(shelf.last_interacted_slot == null);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());

    // Attempt to insert diamond (id 264) via interactWithItem
    const rej2 = shelf.interactWithItem(4, 264);
    try std.testing.expect(!rej2.success());
    try std.testing.expectEqual(InteractAction.none, rej2.action);
    try std.testing.expect(!shelf.isSlotOccupied(4));
    try std.testing.expect(shelf.isEmpty());
}

test "16. Extracting from occupied slot with non-book in hand succeeds" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    // Insert Written Book into slot 5
    _ = shelf.interactSlot(5, false, WrittenBookTag);
    try std.testing.expect(shelf.isSlotOccupied(5));

    // Player clicks slot 5 while holding a diamond pickaxe (id 278)
    const ret = shelf.interactSlot(5, false, 278);
    try std.testing.expect(ret.success());
    try std.testing.expectEqual(InteractAction.retrieved, ret.action);
    try std.testing.expectEqual(WrittenBookTag, ret.item_id);
    try std.testing.expect(!shelf.isSlotOccupied(5));
}

test "17. Comparator signal: 0 in un-interacted state" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    // Never interacted shelf
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u4, 0), comparatorSignal(shelf));

    // Shelf populated via setSlot without interaction
    _ = shelf.setSlot(0, BookTag);
    _ = shelf.setSlot(1, EnchantedBookTag);
    try std.testing.expectEqual(@as(u3, 2), shelf.bookCount());
    try std.testing.expect(shelf.last_interacted_slot == null);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());

    // Clear resets to 0
    shelf.clear();
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
}

test "18. Comparator signal: 1..6 output across slots 0..5" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    // Test each slot 0..5 generating signals 1..6
    const expected_signals = [_]u4{ 1, 2, 3, 4, 5, 6 };
    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        // Insert into slot s
        const ins = shelf.interactSlot(s, false, BookTag);
        try std.testing.expect(ins.success());
        try std.testing.expectEqual(@as(?u3, s), shelf.last_interacted_slot);
        try std.testing.expectEqual(expected_signals[s], shelf.comparatorSignal());
        try std.testing.expectEqual(expected_signals[s], comparatorSignal(shelf));
        try std.testing.expectEqual(@as(?u4, expected_signals[s]), shelf.getLastInteractedSlotNumber());

        // Extract and reset
        shelf.clear();
        try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    }
}

test "19. Comparator signal: drops to 0 when bookshelf becomes empty" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    // Insert books into slot 1 and slot 5
    _ = shelf.interactSlot(1, false, BookTag);
    try std.testing.expectEqual(@as(u4, 2), shelf.comparatorSignal()); // 1 + 1 = 2

    _ = shelf.interactSlot(5, false, WrittenBookTag);
    try std.testing.expectEqual(@as(u4, 6), shelf.comparatorSignal()); // 5 + 1 = 6

    // Extract book from slot 1: shelf still has book in slot 5 -> signal updates to 1 + 1 = 2
    const ret1 = shelf.interactSlot(1, false, EmptySlot);
    try std.testing.expect(ret1.success());
    try std.testing.expect(!shelf.isEmpty());
    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());
    try std.testing.expectEqual(@as(u4, 2), shelf.comparatorSignal());

    // Extract book from slot 5: shelf is now completely empty -> signal drops to 0!
    const ret5 = shelf.interactSlot(5, false, EmptySlot);
    try std.testing.expect(ret5.success());
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expectEqual(@as(u3, 0), shelf.bookCount());
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());

    // Insert back into slot 4: signal becomes 4 + 1 = 5
    _ = shelf.interactSlot(4, false, EnchantedBookTag);
    try std.testing.expect(!shelf.isEmpty());
    try std.testing.expectEqual(@as(u4, 5), shelf.comparatorSignal());
}

test "20. OccupiedMask: bitmask tracking for all 6 slots and combinations" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    // Each individual slot sets exactly 1 bit
    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        _ = shelf.setSlot(s, BookTag);
        const expected_bit = @as(u6, 1) << s;
        try std.testing.expectEqual(expected_bit, shelf.occupiedMask());
        try std.testing.expectEqual(expected_bit, occupiedMask(shelf));
        _ = shelf.setSlot(s, EmptySlot);
    }

    // Top row full (slots 0, 1, 2) -> bits 0, 1, 2 = 0b000111 = 7
    _ = shelf.setSlot(0, BookTag);
    _ = shelf.setSlot(1, BookTag);
    _ = shelf.setSlot(2, BookTag);
    try std.testing.expectEqual(@as(u6, 0b000111), shelf.occupiedMask());

    // Bottom row full (slots 3, 4, 5) -> bits 3, 4, 5 = 0b111000 = 56
    shelf.clear();
    _ = shelf.setSlot(3, BookTag);
    _ = shelf.setSlot(4, BookTag);
    _ = shelf.setSlot(5, BookTag);
    try std.testing.expectEqual(@as(u6, 0b111000), shelf.occupiedMask());

    // Diagonal slots (0, 4) -> bits 0, 4 = 1 | 16 = 17 (0b010001)
    shelf.clear();
    _ = shelf.setSlot(0, BookTag);
    _ = shelf.setSlot(4, BookTag);
    try std.testing.expectEqual(@as(u6, 0b010001), shelf.occupiedMask());
}

test "21. Full storage capacity (6 books) and full shelf extraction" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    const book_types = [_]u16{
        BookTag,
        EnchantedBookTag,
        BookAndQuillTag,
        WrittenBookTag,
        MendingBookTag,
        SwiftSneakBookTag,
    };

    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        _ = shelf.interactSlot(s, false, book_types[s]);
        try std.testing.expectEqual(s + 1, shelf.bookCount());
    }

    try std.testing.expect(shelf.isFull());
    try std.testing.expect(!shelf.isEmpty());
    try std.testing.expectEqual(@as(u6, 0b111111), shelf.occupiedMask());
    try std.testing.expectEqual(@as(u4, 6), shelf.comparatorSignal());

    // Right clicking occupied slot 1 extracts the book
    const ret1 = shelf.interactSlot(1, true, BookTag);
    try std.testing.expect(ret1.success());
    try std.testing.expectEqual(InteractAction.retrieved, ret1.action);
    try std.testing.expectEqual(EnchantedBookTag, ret1.item_id);
    try std.testing.expectEqual(@as(u3, 5), shelf.bookCount());
    try std.testing.expect(!shelf.isFull());
    try std.testing.expectEqual(@as(u4, 2), shelf.comparatorSignal()); // 1 + 1 = 2
}

test "22. Direct UV interaction via interactUV" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    // Target top-right (slot 2): u = 0.85, v = 0.80
    const res2 = shelf.interactUV(0.85, 0.80, true, BookTag);
    try std.testing.expect(res2.success());
    try std.testing.expectEqual(@as(u3, 2), res2.slot);
    try std.testing.expectEqual(BookTag, shelf.getSlot(2).?);
    try std.testing.expectEqual(@as(u4, 3), shelf.comparatorSignal());

    // Target bottom-center (slot 4): u = 0.50, v = 0.20
    const res4 = shelf.interactUV(0.50, 0.20, false, BookAndQuillTag);
    try std.testing.expect(res4.success());
    try std.testing.expectEqual(@as(u3, 4), res4.slot);
    try std.testing.expectEqual(BookAndQuillTag, shelf.getSlot(4).?);
    try std.testing.expectEqual(@as(u4, 5), shelf.comparatorSignal());

    // Retrieve from slot 2 via UV
    const ret2 = shelf.interactUV(0.90, 0.95, false, EmptySlot);
    try std.testing.expect(ret2.success());
    try std.testing.expectEqual(InteractAction.retrieved, ret2.action);
    try std.testing.expectEqual(BookTag, ret2.item_id);
    try std.testing.expectEqual(@as(u3, 2), ret2.slot);
    try std.testing.expectEqual(@as(u4, 3), shelf.comparatorSignal());
}

test "23. Out of bounds slot index safety (slot >= 6)" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    const res6 = shelf.interactSlot(6, true, BookTag);
    try std.testing.expect(!res6.success());
    try std.testing.expectEqual(InteractAction.none, res6.action);

    const res7 = interactSlot(&shelf, 7, false, EmptySlot);
    try std.testing.expect(!res7.success());

    try std.testing.expect(shelf.getSlot(6) == null);
    try std.testing.expect(!shelf.isSlotOccupied(6));
    try std.testing.expect(!shelf.setSlot(6, BookTag));
}

test "24. Spatial lookup findBookshelf in collection" {
    var shelves = [_]ChiseledBookshelfStorage{
        ChiseledBookshelfStorage.init(10, 64, 20, .north),
        ChiseledBookshelfStorage.init(15, 65, -30, .east),
        ChiseledBookshelfStorage.init(-5, 70, 42, .south),
    };

    try std.testing.expectEqual(@as(?usize, 0), findBookshelf(&shelves, shelves.len, 10, 64, 20));
    try std.testing.expectEqual(@as(?usize, 1), findBookshelf(&shelves, shelves.len, 15, 65, -30));
    try std.testing.expectEqual(@as(?usize, 2), findBookshelf(&shelves, shelves.len, -5, 70, 42));

    try std.testing.expect(findBookshelf(&shelves, shelves.len, 0, 0, 0) == null);
    try std.testing.expect(findBookshelf(&shelves, 1, 15, 65, -30) == null);
}

test "25. SlotId enum metadata and conversion" {
    try std.testing.expectEqual(SlotId.top_left, SlotId.fromRowCol(.top, .left));
    try std.testing.expectEqual(SlotId.top_center, SlotId.fromRowCol(.top, .center));
    try std.testing.expectEqual(SlotId.top_right, SlotId.fromRowCol(.top, .right));
    try std.testing.expectEqual(SlotId.bottom_left, SlotId.fromRowCol(.bottom, .left));
    try std.testing.expectEqual(SlotId.bottom_center, SlotId.fromRowCol(.bottom, .center));
    try std.testing.expectEqual(SlotId.bottom_right, SlotId.fromRowCol(.bottom, .right));

    try std.testing.expectEqual(SlotRow.top, SlotId.top_left.row());
    try std.testing.expectEqual(SlotCol.left, SlotId.top_left.col());
    try std.testing.expectEqual(@as(u4, 1), SlotId.top_left.comparatorSignal());

    try std.testing.expectEqual(SlotRow.bottom, SlotId.bottom_right.row());
    try std.testing.expectEqual(SlotCol.right, SlotId.bottom_right.col());
    try std.testing.expectEqual(@as(u4, 6), SlotId.bottom_right.comparatorSignal());
}
