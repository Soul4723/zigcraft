//! Unified Chiseled Bookshelf storage, 6-slot UV face targeting, comparator
//! redstone signal (1..6), secret combination latch, and piston door actuator.

const std = @import("std");

// ============================================================================
// Constants
// ============================================================================

/// Maximum number of chiseled bookshelves tracked in a single spatial collection.
pub const max_chiseled_bookshelves: usize = 32;

/// Total number of book slots in a chiseled bookshelf (3 columns x 2 rows).
pub const total_slots: usize = 6;

/// Alias for total_slots used by secret latch rules.
pub const bookshelf_slots: usize = total_slots;

/// Number of columns on the front face (3 columns: left, center, right).
pub const num_columns: usize = 3;

/// Number of rows on the front face (2 rows: top, bottom).
pub const num_rows: usize = 2;

/// Front face UV column and row boundary thresholds.
pub const col_left_threshold: f32 = 0.333;
pub const col_center_threshold: f32 = 0.666;
pub const row_vertical_threshold: f32 = 0.50;

/// Redstone comparator signal bounds.
pub const min_comparator_signal: u4 = 0;
pub const max_comparator_signal: u4 = 6;

/// Secret latch & piston door constants.
pub const minimum_bookshelves: usize = 2;
pub const door_transition_ticks: u8 = 6;
pub const locked_signal: u8 = 0;
pub const unlocked_signal: u8 = 15;
pub const default_latch_password = [_]u3{ 0, 5 };

/// Empty slot marker.
pub const EmptySlot: u16 = 0;

/// Primary and specialized book item tags (matching src/items.zig ItemType).
pub const BookTag: u16 = 270;
pub const EnchantedBookTag: u16 = 440;
pub const MendingBookTag: u16 = 441;
pub const SwiftSneakBookTag: u16 = 470;
pub const SweepingEdgeBookTag: u16 = 474;
pub const FeatherFallingBookTag: u16 = 479;
pub const BookAndQuillTag: u16 = 499;
pub const WrittenBookTag: u16 = 500;

// ============================================================================
// Enums & Types
// ============================================================================

/// Accepted standard book categories matching src/items.zig item IDs.
pub const BookItem = enum(u16) {
    book = BookTag,
    enchanted_book = EnchantedBookTag,
    book_and_quill = BookAndQuillTag,
    written_book = WrittenBookTag,

    /// Returns the numeric item ID matching src/items.zig.
    pub fn toId(self: BookItem) u16 {
        return @intFromEnum(self);
    }

    /// Returns the human-readable display name of the book item.
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

    /// Returns the 0-based row index (0 = top, 1 = bottom).
    pub fn toIndex(self: SlotRow) u1 {
        return @intFromEnum(self);
    }
};

/// 3-column horizontal matrix partition for front face UV targeting.
pub const SlotCol = enum(u2) {
    left = 0,
    center = 1,
    right = 2,

    /// Returns the 0-based column index (0 = left, 1 = center, 2 = right).
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

    /// Returns the 0-based slot index (0..5).
    pub fn toIndex(self: SlotId) u3 {
        return @intFromEnum(self);
    }

    /// Converts row and column coordinates into a SlotId.
    pub fn fromRowCol(r: SlotRow, c: SlotCol) SlotId {
        const idx: u3 = @as(u3, r.toIndex()) * 3 + @as(u3, c.toIndex());
        return @enumFromInt(idx);
    }

    /// Returns the vertical row of this slot.
    pub fn row(self: SlotId) SlotRow {
        return if (@intFromEnum(self) < 3) .top else .bottom;
    }

    /// Returns the horizontal column of this slot.
    pub fn col(self: SlotId) SlotCol {
        return @enumFromInt(@intFromEnum(self) % 3);
    }

    /// Returns the 1-based comparator signal (1..6) for this slot.
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

    /// Returns the unit integer normal vector for this facing.
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

    /// Maps a raycast entry face normal (nx, ny, nz) to a Facing, if valid.
    pub fn fromHitNormal(nx: i32, ny: i32, nz: i32) ?Facing {
        if (nz < 0) return .north;
        if (nz > 0) return .south;
        if (nx < 0) return .west;
        if (nx > 0) return .east;
        if (ny > 0) return .up;
        if (ny < 0) return .down;
        return null;
    }

    /// Returns true if this facing is one of the 4 horizontal cardinal directions.
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

/// Outcome kind for a slot interaction.
pub const InteractAction = enum {
    none,
    inserted,
    retrieved,
};

/// Result of interacting with a slot on the chiseled bookshelf.
pub const InteractResult = struct {
    action: InteractAction = .none,
    item_id: u16 = EmptySlot,
    slot: u3 = 0,

    /// Returns true if a book was inserted or retrieved.
    pub fn success(self: InteractResult) bool {
        return self.action != .none;
    }
};

// ============================================================================
// Book Item Validation
// ============================================================================

/// Returns true if the item tag represents an acceptable book item in src/items.zig:
/// Book (270), Enchanted Book (440), Mending Book (441), Swift Sneak Book (470),
/// Sweeping Edge Book (474), Feather Falling Book (479), Book and Quill (499),
/// or Written Book (500).
pub fn isAcceptedBook(item_id: u16) bool {
    return switch (item_id) {
        BookTag,
        EnchantedBookTag,
        MendingBookTag,
        SwiftSneakBookTag,
        SweepingEdgeBookTag,
        FeatherFallingBookTag,
        BookAndQuillTag,
        WrittenBookTag,
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

/// Maps facing + normalized UV hit coordinates (u in 0..1, v in 0..1 with v >= 0.50 top row)
/// onto slot index 0..5.
pub fn hitCoordsToSlot(facing: Facing, hit_u: f32, hit_v: f32) u3 {
    _ = facing;
    return uvToSlot(hit_u, hit_v);
}

/// Converts world ray hit coordinates on a block face to normalized face UV (u, v in 0.0..1.0).
/// Bottom edge is v = 0.0, top edge is v = 1.0 (v >= 0.50 selects top row).
/// Returns null for non-horizontal faces (up, down).
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

/// Computes the exact ray-plane intersection on the entered block face from camera
/// origin and direction, returning the targeted slot index 0..5.
/// Falls back to a deterministic slot from block coords when aimed at top/bottom faces.
pub fn raycastBlockFaceSlot(
    origin: [3]f32,
    dir: [3]f32,
    block_x: i32,
    block_y: i32,
    block_z: i32,
    nx: i32,
    ny: i32,
    nz: i32,
) u3 {
    const facing = Facing.fromHitNormal(nx, ny, nz) orelse
        return @intCast(@as(usize, @intCast(@abs(block_x +% block_y +% block_z))) % total_slots);

    if (nx != 0 and @abs(dir[0]) > 1e-6) {
        const plane_x: f32 = @floatFromInt(if (nx > 0) block_x + 1 else block_x);
        const t = (plane_x - origin[0]) / dir[0];
        if (t >= 0.0) {
            const hy = origin[1] + dir[1] * t;
            const hz = origin[2] + dir[2] * t;
            if (worldHitToSlot(facing, plane_x, hy, hz, block_x, block_y, block_z)) |slot| {
                return slot;
            }
        }
    } else if (nz != 0 and @abs(dir[2]) > 1e-6) {
        const plane_z: f32 = @floatFromInt(if (nz > 0) block_z + 1 else block_z);
        const t = (plane_z - origin[2]) / dir[2];
        if (t >= 0.0) {
            const hx = origin[0] + dir[0] * t;
            const hy = origin[1] + dir[1] * t;
            if (worldHitToSlot(facing, hx, hy, plane_z, block_x, block_y, block_z)) |slot| {
                return slot;
            }
        }
    }

    return @intCast(@as(usize, @intCast(@abs(block_x +% block_y +% block_z))) % total_slots);
}

// ============================================================================
// ChiseledBookshelf Storage Struct
// ============================================================================

/// ChiseledBookshelf represents a 6-slot directional book storage container (slots 0..5).
/// Top row: slots 0, 1, 2. Bottom row: slots 3, 4, 5.
/// Emits comparator signal 1..6 for last_interacted_slot + 1 (retained across removals
/// until cleared, matching Minecraft 1.20 redstone semantics).
pub const ChiseledBookshelf = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
    facing: Facing = .north,
    slots: [total_slots]u16 = [_]u16{EmptySlot} ** total_slots,
    last_interacted_slot: ?u3 = null,

    /// Initializes an empty ChiseledBookshelf at the given world position and facing.
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

    /// True if no books are stored in any of the 6 slots.
    pub fn isEmpty(self: ChiseledBookshelf) bool {
        return self.bookCount() == 0;
    }

    /// True if all 6 slots are occupied with books.
    pub fn isFull(self: ChiseledBookshelf) bool {
        return self.bookCount() == total_slots;
    }

    /// Returns the item ID at the given slot (0..5), or null if slot is out of bounds or empty.
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

    /// Returns true if the targeted slot contains a stored book.
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

    /// Returns the 0-indexed last interacted slot (0..5), or null if un-interacted.
    pub fn getLastInteractedSlotIndex(self: ChiseledBookshelf) ?u3 {
        return self.last_interacted_slot;
    }

    /// Returns the 1-based last interacted slot number (1..6), or null if un-interacted.
    pub fn getLastInteractedSlotNumber(self: ChiseledBookshelf) ?u4 {
        if (self.last_interacted_slot) |slot| {
            return @as(u4, slot) + 1;
        }
        return null;
    }

    /// Returns the redstone comparator signal (1..6) corresponding to last_interacted_slot + 1,
    /// or 0 if never interacted with or cleared.
    pub fn comparatorSignal(self: ChiseledBookshelf) u4 {
        if (self.last_interacted_slot) |slot| {
            return @as(u4, slot) + 1;
        }
        return 0;
    }

    /// Returns the occupancy-gated comparator signal (1..6), returning 0 when the shelf is empty.
    pub fn occupiedComparatorSignal(self: ChiseledBookshelf) u4 {
        if (self.isEmpty()) return 0;
        return self.comparatorSignal();
    }

    /// Projects this bookshelf into a BookshelfState for SecretLatch evaluation.
    /// Keeps interacted_slot only if that slot currently holds a book.
    pub fn toBookshelfState(self: ChiseledBookshelf) BookshelfState {
        const mask = self.occupiedMask();
        var interacted: ?u3 = null;
        if (self.last_interacted_slot) |slot| {
            if (slot < total_slots and (mask & (@as(u6, 1) << slot)) != 0) {
                interacted = slot;
            }
        }
        return .{
            .occupied_slots = mask,
            .interacted_slot = interacted,
        };
    }

    /// Interacts with a specific slot on the bookshelf:
    /// - If the slot is empty: inserts book if player is holding a valid book.
    /// - If the slot is occupied: extracts stored book and clears the slot.
    /// - Updates last_interacted_slot on successful insertion or retrieval.
    pub fn interactSlot(
        self: *ChiseledBookshelf,
        slot: u3,
        held_is_book: bool,
        book_item_id: u16,
    ) InteractResult {
        if (slot >= total_slots) {
            return .{ .action = .none, .item_id = EmptySlot, .slot = slot };
        }

        const current_item = self.slots[slot];
        if (current_item != EmptySlot) {
            self.slots[slot] = EmptySlot;
            self.last_interacted_slot = slot;
            return .{
                .action = .retrieved,
                .item_id = current_item,
                .slot = slot,
            };
        } else {
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
    pub fn interactWithItem(self: *ChiseledBookshelf, slot: u3, item_id: u16) InteractResult {
        return self.interactSlot(slot, isBookItem(item_id), item_id);
    }

    /// High-level interaction taking face UV hit coordinates directly.
    pub fn interactUV(
        self: *ChiseledBookshelf,
        u: f32,
        v: f32,
        held_is_book: bool,
        book_item_id: u16,
    ) InteractResult {
        const slot = uvToSlot(u, v);
        return self.interactSlot(slot, held_is_book, book_item_id);
    }

    /// Clears all slots and resets last_interacted_slot.
    pub fn clear(self: *ChiseledBookshelf) void {
        self.slots = [_]u16{EmptySlot} ** total_slots;
        self.last_interacted_slot = null;
    }
};

/// Type alias preserving ChiseledBookshelfStorage naming.
pub const ChiseledBookshelfStorage = ChiseledBookshelf;

// ============================================================================
// Secret Combination Latch & Piston Door Actuator
// ============================================================================

/// A bookshelf's occupied slots and most recent valid slot interaction.
/// Any slot content change clears the interaction, requiring a fresh selection.
pub const BookshelfState = struct {
    occupied_slots: u6 = 0,
    interacted_slot: ?u3 = null,

    /// Marks a slot as occupied or empty; changing occupancy clears interacted_slot.
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

    /// Emits comparator signal 1..6 when the interacted slot holds a book, else 0.
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

    /// Initializes a SecretLatch with the target slot combination slice.
    pub fn init(password: []const u3) SecretLatch {
        return .{ .password = password };
    }

    /// Returns true if every shelf matches its expected occupied password slot.
    pub fn isUnlocked(self: SecretLatch, bookshelves: []const BookshelfState) bool {
        if (self.password.len < minimum_bookshelves or bookshelves.len != self.password.len) return false;
        for (self.password, bookshelves) |expected, shelf| {
            if (shelf.interacted_slot == null or shelf.interacted_slot.? != expected) return false;
            if (shelf.comparatorSignal() == 0) return false;
        }
        return true;
    }

    /// Returns 15 when unlocked, or 0 when locked.
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

    /// Advances the piston door transition by one tick; returns true when state flips.
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

    /// Returns true when the secret passage is open (pistons retracted).
    pub fn isPassageOpen(self: PistonDoor) bool {
        return self.is_retracted;
    }
};

/// Result of evaluating a SecretLatch and advancing its PistonDoor from live shelves.
pub const LatchEvalResult = struct {
    signal: u8 = locked_signal,
    unlocked: bool = false,
    just_unlocked: bool = false,
    door_changed: bool = false,
    door_open: bool = false,
};

/// Evaluates a SecretLatch over tracked ChiseledBookshelf instances and ticks the
/// associated PistonDoor. Supports both multi-shelf combinations and single-shelf
/// target pair activation when only one bookshelf has been placed.
pub fn evaluateBookshelfLatch(
    shelves: []const ChiseledBookshelf,
    latch: SecretLatch,
    door: *PistonDoor,
) LatchEvalResult {
    const was_active = door.isPassageOpen() or (door.pending_target orelse false);
    var signal: u8 = locked_signal;

    if (latch.password.len >= minimum_bookshelves and latch.password.len <= max_chiseled_bookshelves) {
        if (shelves.len >= latch.password.len) {
            var states: [max_chiseled_bookshelves]BookshelfState = undefined;
            for (0..latch.password.len) |i| {
                states[i] = shelves[i].toBookshelfState();
            }
            signal = latch.outputSignal(states[0..latch.password.len]);
        } else if (shelves.len == 1 and latch.password.len == 2) {
            const s = shelves[0];
            var pair = [2]BookshelfState{
                .{
                    .occupied_slots = s.occupiedMask(),
                    .interacted_slot = if (s.isSlotOccupied(latch.password[0])) latch.password[0] else null,
                },
                s.toBookshelfState(),
            };
            signal = latch.outputSignal(&pair);
        }
    }

    const door_changed = door.tick(signal);
    const unlocked = (signal == unlocked_signal);
    return .{
        .signal = signal,
        .unlocked = unlocked,
        .just_unlocked = unlocked and !was_active,
        .door_changed = door_changed,
        .door_open = door.isPassageOpen(),
    };
}

// ============================================================================
// Free Functions
// ============================================================================

/// Free function wrapper for interacting with a bookshelf slot.
pub fn interactSlot(
    shelf: *ChiseledBookshelf,
    slot: u3,
    held_is_book: bool,
    book_item_id: u16,
) InteractResult {
    return shelf.interactSlot(slot, held_is_book, book_item_id);
}

/// Free function wrapper for computing redstone comparator signal.
pub fn comparatorSignal(shelf: ChiseledBookshelf) u4 {
    return shelf.comparatorSignal();
}

/// Free function wrapper for computing occupied spine bitmask.
pub fn occupiedMask(shelf: ChiseledBookshelf) u6 {
    return shelf.occupiedMask();
}

/// Find a chiseled bookshelf at coordinates (x, y, z) in an array.
pub fn findBookshelf(
    bookshelves: []const ChiseledBookshelf,
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
// Unit Tests (Unified Suite: Chiseled Bookshelf + Storage UV + Secret Latch)
// ============================================================================

test "constants and book item identification" {
    try std.testing.expectEqual(@as(usize, 32), max_chiseled_bookshelves);
    try std.testing.expectEqual(@as(usize, 6), total_slots);
    try std.testing.expectEqual(@as(u16, 0), EmptySlot);
    try std.testing.expectEqual(@as(u16, 270), BookTag);
    try std.testing.expectEqual(@as(u16, 440), EnchantedBookTag);
    try std.testing.expectEqual(@as(u16, 441), MendingBookTag);
    try std.testing.expectEqual(@as(u16, 470), SwiftSneakBookTag);
    try std.testing.expectEqual(@as(u16, 474), SweepingEdgeBookTag);
    try std.testing.expectEqual(@as(u16, 479), FeatherFallingBookTag);
    try std.testing.expectEqual(@as(u16, 499), BookAndQuillTag);
    try std.testing.expectEqual(@as(u16, 500), WrittenBookTag);

    // Valid books
    try std.testing.expect(isBookItem(BookTag));
    try std.testing.expect(isBookItem(EnchantedBookTag));
    try std.testing.expect(isBookItem(MendingBookTag));
    try std.testing.expect(isBookItem(SwiftSneakBookTag));
    try std.testing.expect(isBookItem(SweepingEdgeBookTag));
    try std.testing.expect(isBookItem(FeatherFallingBookTag));
    try std.testing.expect(isBookItem(BookAndQuillTag));
    try std.testing.expect(isBookItem(WrittenBookTag));

    // Invalid non-book items (including cherry_log..pink_petals 400..403)
    try std.testing.expect(!isBookItem(EmptySlot));
    try std.testing.expect(!isBookItem(1)); // stone
    try std.testing.expect(!isBookItem(7)); // wood planks
    try std.testing.expect(!isBookItem(400)); // cherry_log
    try std.testing.expect(!isBookItem(403)); // pink_petals
    try std.testing.expect(!isBookItem(999));
}

test "hitCoordsToSlot top row UV targeting (slots 0, 1, 2)" {
    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.north, 0.1, 0.8));
    try std.testing.expectEqual(@as(u3, 0), uvToSlot(0.2, 0.9));

    try std.testing.expectEqual(@as(u3, 1), hitCoordsToSlot(.north, 0.5, 0.8));
    try std.testing.expectEqual(@as(u3, 1), uvToSlot(0.4, 0.7));

    try std.testing.expectEqual(@as(u3, 2), hitCoordsToSlot(.north, 0.9, 0.8));
    try std.testing.expectEqual(@as(u3, 2), uvToSlot(0.8, 0.6));
}

test "hitCoordsToSlot bottom row UV targeting (slots 3, 4, 5)" {
    try std.testing.expectEqual(@as(u3, 3), hitCoordsToSlot(.north, 0.1, 0.2));
    try std.testing.expectEqual(@as(u3, 3), uvToSlot(0.2, 0.4));

    try std.testing.expectEqual(@as(u3, 4), hitCoordsToSlot(.north, 0.5, 0.2));
    try std.testing.expectEqual(@as(u3, 4), uvToSlot(0.5, 0.3));

    try std.testing.expectEqual(@as(u3, 5), hitCoordsToSlot(.north, 0.9, 0.2));
    try std.testing.expectEqual(@as(u3, 5), uvToSlot(0.85, 0.1));
}

test "hitCoordsToSlot boundary conditions and clamping" {
    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.north, 0.0, 1.0));
    try std.testing.expectEqual(@as(u3, 2), hitCoordsToSlot(.north, 1.0, 1.0));
    try std.testing.expectEqual(@as(u3, 3), hitCoordsToSlot(.north, 0.0, 0.0));
    try std.testing.expectEqual(@as(u3, 5), hitCoordsToSlot(.north, 1.0, 0.0));

    try std.testing.expectEqual(@as(u3, 3), hitCoordsToSlot(.north, -0.5, -0.2));
    try std.testing.expectEqual(@as(u3, 2), hitCoordsToSlot(.north, 1.5, 1.8));

    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.south, 0.332, 0.9));
    try std.testing.expectEqual(@as(u3, 1), hitCoordsToSlot(.south, 0.334, 0.9));
    try std.testing.expectEqual(@as(u3, 1), hitCoordsToSlot(.south, 0.665, 0.9));
    try std.testing.expectEqual(@as(u3, 2), hitCoordsToSlot(.south, 0.667, 0.9));

    try std.testing.expectEqual(@as(u3, 1), hitCoordsToSlot(.east, 0.5, 0.501));
    try std.testing.expectEqual(@as(u3, 4), hitCoordsToSlot(.east, 0.5, 0.499));
}

test "worldHitToFaceUV 3D coordinate mapping for all cardinal facings" {
    const north_uv = worldHitToFaceUV(.north, 10.2, 5.8, 20.0, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), north_uv.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), north_uv.v, 0.001);
    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.north, north_uv.u, north_uv.v));

    const south_uv = worldHitToFaceUV(.south, 10.2, 5.8, 21.0, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), south_uv.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), south_uv.v, 0.001);
    try std.testing.expectEqual(@as(u3, 2), hitCoordsToSlot(.south, south_uv.u, south_uv.v));

    const west_uv = worldHitToFaceUV(.west, 10.0, 5.2, 20.2, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), west_uv.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), west_uv.v, 0.001);
    try std.testing.expectEqual(@as(u3, 3), hitCoordsToSlot(.west, west_uv.u, west_uv.v));

    const east_uv = worldHitToFaceUV(.east, 11.0, 5.2, 20.2, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), east_uv.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), east_uv.v, 0.001);
    try std.testing.expectEqual(@as(u3, 5), hitCoordsToSlot(.east, east_uv.u, east_uv.v));

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

    const res4 = shelf.interactSlot(4, false, EnchantedBookTag);
    try std.testing.expectEqual(InteractAction.inserted, res4.action);
    try std.testing.expectEqual(EnchantedBookTag, res4.item_id);
    try std.testing.expectEqual(@as(u3, 4), res4.slot);

    try std.testing.expectEqual(@as(u3, 2), shelf.bookCount());
    try std.testing.expectEqual(EnchantedBookTag, shelf.getSlot(4).?);
    try std.testing.expectEqual(@as(?u3, 4), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(u4, 5), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0b010001), shelf.occupiedMask());
}

test "non-book items cannot be inserted into empty slots" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);

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
    _ = shelf.interactSlot(3, false, MendingBookTag);
    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());

    const ret = shelf.interactSlot(3, false, EmptySlot);
    try std.testing.expectEqual(InteractAction.retrieved, ret.action);
    try std.testing.expectEqual(MendingBookTag, ret.item_id);
    try std.testing.expectEqual(@as(u3, 3), ret.slot);
    try std.testing.expect(ret.success());

    try std.testing.expect(shelf.isEmpty());
    try std.testing.expect(!shelf.isSlotOccupied(3));
    try std.testing.expect(shelf.getSlot(3) == null);
    try std.testing.expectEqual(@as(?u3, 3), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(u4, 4), shelf.comparatorSignal());
}

test "last-interacted comparator signal retention after removal" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());

    _ = shelf.interactSlot(1, false, BookTag);
    try std.testing.expectEqual(@as(u4, 2), shelf.comparatorSignal());

    _ = shelf.interactSlot(5, false, BookAndQuillTag);
    try std.testing.expectEqual(@as(u4, 6), shelf.comparatorSignal());

    const ret1 = shelf.interactSlot(1, false, EmptySlot);
    try std.testing.expectEqual(InteractAction.retrieved, ret1.action);
    try std.testing.expectEqual(@as(u4, 2), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(?u3, 1), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());

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
        MendingBookTag,
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

    const ret_full = shelf.interactSlot(2, true, BookTag);
    try std.testing.expectEqual(InteractAction.retrieved, ret_full.action);
    try std.testing.expectEqual(BookAndQuillTag, ret_full.item_id);
    try std.testing.expectEqual(@as(u3, 5), shelf.bookCount());
    try std.testing.expect(!shelf.isFull());

    shelf.clear();
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expectEqual(@as(u3, 0), shelf.bookCount());
    try std.testing.expect(shelf.last_interacted_slot == null);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0), shelf.occupiedMask());
}

test "occupiedMask bitmask states for visual spine rendering" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);

    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        _ = shelf.setSlot(s, BookTag);
        const expected_bit = @as(u6, 1) << s;
        try std.testing.expectEqual(expected_bit, shelf.occupiedMask());
        _ = shelf.setSlot(s, EmptySlot);
    }

    _ = shelf.setSlot(0, BookTag);
    _ = shelf.setSlot(2, EnchantedBookTag);
    _ = shelf.setSlot(4, WrittenBookTag);
    try std.testing.expectEqual(@as(u6, 0b010101), shelf.occupiedMask());
    try std.testing.expectEqual(@as(u6, 21), shelf.occupiedMask());

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

        const ret = interactSlot(&shelf, s, false, EmptySlot);
        try std.testing.expectEqual(InteractAction.retrieved, ret.action);
        try std.testing.expectEqual(expected_signal, shelf.comparatorSignal());

        shelf.clear();
        try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    }
}

test "invalid slot index safety (slot >= 6)" {
    var shelf = ChiseledBookshelf.init(0, 0, 0, .north);

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

    try std.testing.expect(findBookshelf(&shelves, shelves.len, 99, 99, 99) == null);
    try std.testing.expect(findBookshelf(&shelves, shelves.len, 10, 64, 21) == null);
    try std.testing.expect(findBookshelf(&shelves, 1, 15, 65, -30) == null);
}

// --- Consolidated ChiseledBookshelfStorage UV & Slot tests (25 tests) ---

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
    try std.testing.expect(isAcceptedBook(BookTag));
    try std.testing.expect(isAcceptedBook(WrittenBookTag));
    try std.testing.expect(isAcceptedBook(BookAndQuillTag));
    try std.testing.expect(isAcceptedBook(EnchantedBookTag));

    try std.testing.expectEqualStrings("Book", BookItem.book.name());
    try std.testing.expectEqualStrings("Enchanted Book", BookItem.enchanted_book.name());
    try std.testing.expectEqualStrings("Book and Quill", BookItem.book_and_quill.name());
    try std.testing.expectEqualStrings("Written Book", BookItem.written_book.name());

    try std.testing.expect(isAcceptedBook(MendingBookTag));
    try std.testing.expect(isAcceptedBook(SwiftSneakBookTag));
    try std.testing.expect(isAcceptedBook(SweepingEdgeBookTag));
    try std.testing.expect(isAcceptedBook(FeatherFallingBookTag));

    try std.testing.expect(isBookItem(BookTag));
    try std.testing.expect(isBookItem(WrittenBookTag));
    try std.testing.expect(isBookItem(BookAndQuillTag));
    try std.testing.expect(isBookItem(EnchantedBookTag));
}

test "3. Non-book item rejection in isAcceptedBook and isBookItem" {
    try std.testing.expect(!isAcceptedBook(EmptySlot));
    try std.testing.expect(!isAcceptedBook(1));
    try std.testing.expect(!isAcceptedBook(2));
    try std.testing.expect(!isAcceptedBook(3));
    try std.testing.expect(!isAcceptedBook(5));
    try std.testing.expect(!isAcceptedBook(264));
    try std.testing.expect(!isAcceptedBook(400));
    try std.testing.expect(!isAcceptedBook(999));

    try std.testing.expect(!isBookItem(EmptySlot));
    try std.testing.expect(!isBookItem(1));
    try std.testing.expect(!isBookItem(264));
}

test "4. UV coordinate targeting: top row slots 0, 1, 2 (v >= 0.50)" {
    try std.testing.expectEqual(@as(u3, 0), uvToSlot(0.15, 0.75));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.75));
    try std.testing.expectEqual(@as(u2, 0), uvToCol(0.15));

    try std.testing.expectEqual(@as(u3, 1), uvToSlot(0.50, 0.75));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.75));
    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.50));

    try std.testing.expectEqual(@as(u3, 2), uvToSlot(0.85, 0.75));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.75));
    try std.testing.expectEqual(@as(u2, 2), uvToCol(0.85));
}

test "5. UV coordinate targeting: bottom row slots 3, 4, 5 (v < 0.50)" {
    try std.testing.expectEqual(@as(u3, 3), uvToSlot(0.15, 0.25));
    try std.testing.expectEqual(@as(u1, 1), uvToRow(0.25));
    try std.testing.expectEqual(@as(u2, 0), uvToCol(0.15));

    try std.testing.expectEqual(@as(u3, 4), uvToSlot(0.50, 0.25));
    try std.testing.expectEqual(@as(u1, 1), uvToRow(0.25));
    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.50));

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
    try std.testing.expectEqual(@as(u2, 0), uvToCol(0.0));
    try std.testing.expectEqual(@as(u2, 0), uvToCol(0.332));

    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.333));
    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.50));
    try std.testing.expectEqual(@as(u2, 1), uvToCol(0.665));

    try std.testing.expectEqual(@as(u2, 2), uvToCol(0.666));
    try std.testing.expectEqual(@as(u2, 2), uvToCol(0.999));
    try std.testing.expectEqual(@as(u2, 2), uvToCol(1.0));
}

test "8. UV boundary testing: vertical threshold (0.0, 0.50, 1.0)" {
    try std.testing.expectEqual(@as(u1, 1), uvToRow(0.0));
    try std.testing.expectEqual(@as(u1, 1), uvToRow(0.499));

    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.50));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(0.501));
    try std.testing.expectEqual(@as(u1, 0), uvToRow(1.0));
}

test "9. UV boundary testing: four face corners and intersection points" {
    try std.testing.expectEqual(@as(u3, 0), uvToSlot(0.0, 1.0));
    try std.testing.expectEqual(@as(u3, 2), uvToSlot(1.0, 1.0));
    try std.testing.expectEqual(@as(u3, 3), uvToSlot(0.0, 0.0));
    try std.testing.expectEqual(@as(u3, 5), uvToSlot(1.0, 0.0));

    try std.testing.expectEqual(@as(u3, 1), uvToSlot(0.333, 0.50));
    try std.testing.expectEqual(@as(u3, 2), uvToSlot(0.666, 0.50));
    try std.testing.expectEqual(@as(u3, 4), uvToSlot(0.333, 0.499));
    try std.testing.expectEqual(@as(u3, 5), uvToSlot(0.666, 0.499));
}

test "10. UV out-of-range clamping: negative and exceeding 1.0 coordinates" {
    try std.testing.expectEqual(@as(u3, 3), uvToSlot(-0.5, -0.2));
    try std.testing.expectEqual(@as(u3, 2), uvToSlot(1.5, 1.8));
    try std.testing.expectEqual(@as(u3, 0), uvToSlot(-10.0, 5.0));
    try std.testing.expectEqual(@as(u3, 5), uvToSlot(10.0, -5.0));

    try std.testing.expectEqual(@as(u3, 0), hitCoordsToSlot(.north, 0.1, 0.9));
    try std.testing.expectEqual(@as(u3, 4), hitCoordsToSlot(.south, 0.5, 0.2));
}

test "11. 3D world raycast hit conversion to face UV across all cardinal facings" {
    const north_hit = worldHitToFaceUV(.north, 10.2, 5.8, 20.0, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), north_hit.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), north_hit.v, 0.001);
    try std.testing.expectEqual(@as(u3, 0), worldHitToSlot(.north, 10.2, 5.8, 20.0, 10, 5, 20).?);

    const south_hit = worldHitToFaceUV(.south, 10.2, 5.8, 21.0, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), south_hit.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), south_hit.v, 0.001);
    try std.testing.expectEqual(@as(u3, 2), worldHitToSlot(.south, 10.2, 5.8, 21.0, 10, 5, 20).?);

    const west_hit = worldHitToFaceUV(.west, 10.0, 5.2, 20.2, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), west_hit.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), west_hit.v, 0.001);
    try std.testing.expectEqual(@as(u3, 3), worldHitToSlot(.west, 10.0, 5.2, 20.2, 10, 5, 20).?);

    const east_hit = worldHitToFaceUV(.east, 11.0, 5.2, 20.2, 10, 5, 20).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), east_hit.u, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), east_hit.v, 0.001);
    try std.testing.expectEqual(@as(u3, 5), worldHitToSlot(.east, 11.0, 5.2, 20.2, 10, 5, 20).?);

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

    const res2 = shelf.interactSlot(2, false, EnchantedBookTag);
    try std.testing.expect(res2.success());
    try std.testing.expectEqual(InteractAction.inserted, res2.action);
    try std.testing.expectEqual(EnchantedBookTag, res2.item_id);

    try std.testing.expectEqual(@as(u3, 2), shelf.bookCount());
    try std.testing.expect(shelf.isSlotOccupied(2));
    try std.testing.expectEqual(EnchantedBookTag, shelf.getSlot(2).?);
    try std.testing.expectEqual(@as(?u3, 2), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(?u4, 3), shelf.getLastInteractedSlotNumber());
    try std.testing.expectEqual(@as(u4, 3), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u6, 0b000101), shelf.occupiedMask());
}

test "14. Slot interaction: book extraction from occupied slot clears slot and returns item" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    _ = shelf.interactSlot(3, false, BookAndQuillTag);
    try std.testing.expect(shelf.isSlotOccupied(3));
    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());

    const ret3 = shelf.interactSlot(3, false, EmptySlot);
    try std.testing.expect(ret3.success());
    try std.testing.expectEqual(InteractAction.retrieved, ret3.action);
    try std.testing.expectEqual(BookAndQuillTag, ret3.item_id);
    try std.testing.expectEqual(@as(u3, 3), ret3.slot);

    try std.testing.expect(!shelf.isSlotOccupied(3));
    try std.testing.expect(shelf.getSlot(3) == null);
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expectEqual(@as(u3, 0), shelf.bookCount());
    try std.testing.expectEqual(@as(?u3, 3), shelf.last_interacted_slot);
    try std.testing.expectEqual(@as(?u4, 4), shelf.getLastInteractedSlotNumber());
}

test "15. Slot interaction: non-book item insertion rejection leaves slot empty" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    const rej1 = shelf.interactSlot(1, false, 4);
    try std.testing.expect(!rej1.success());
    try std.testing.expectEqual(InteractAction.none, rej1.action);
    try std.testing.expectEqual(EmptySlot, rej1.item_id);
    try std.testing.expect(!shelf.isSlotOccupied(1));
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expect(shelf.last_interacted_slot == null);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());

    const rej2 = shelf.interactWithItem(4, 264);
    try std.testing.expect(!rej2.success());
    try std.testing.expectEqual(InteractAction.none, rej2.action);
    try std.testing.expect(!shelf.isSlotOccupied(4));
    try std.testing.expect(shelf.isEmpty());
}

test "16. Extracting from occupied slot with non-book in hand succeeds" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    _ = shelf.interactSlot(5, false, WrittenBookTag);
    try std.testing.expect(shelf.isSlotOccupied(5));

    const ret = shelf.interactSlot(5, false, 278);
    try std.testing.expect(ret.success());
    try std.testing.expectEqual(InteractAction.retrieved, ret.action);
    try std.testing.expectEqual(WrittenBookTag, ret.item_id);
    try std.testing.expect(!shelf.isSlotOccupied(5));
}

test "17. Comparator signal: 0 in un-interacted state" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    try std.testing.expectEqual(@as(u4, 0), comparatorSignal(shelf));

    _ = shelf.setSlot(0, BookTag);
    _ = shelf.setSlot(1, EnchantedBookTag);
    try std.testing.expectEqual(@as(u3, 2), shelf.bookCount());
    try std.testing.expect(shelf.last_interacted_slot == null);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());

    shelf.clear();
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
}

test "18. Comparator signal: 1..6 output across slots 0..5" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    const expected_signals = [_]u4{ 1, 2, 3, 4, 5, 6 };
    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        const ins = shelf.interactSlot(s, false, BookTag);
        try std.testing.expect(ins.success());
        try std.testing.expectEqual(@as(?u3, s), shelf.last_interacted_slot);
        try std.testing.expectEqual(expected_signals[s], shelf.comparatorSignal());
        try std.testing.expectEqual(expected_signals[s], comparatorSignal(shelf));
        try std.testing.expectEqual(@as(?u4, expected_signals[s]), shelf.getLastInteractedSlotNumber());

        shelf.clear();
        try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
    }
}

test "19. Occupancy-gated comparator signal drops to 0 when bookshelf becomes empty" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    _ = shelf.interactSlot(1, false, BookTag);
    try std.testing.expectEqual(@as(u4, 2), shelf.occupiedComparatorSignal());

    _ = shelf.interactSlot(5, false, WrittenBookTag);
    try std.testing.expectEqual(@as(u4, 6), shelf.occupiedComparatorSignal());

    const ret1 = shelf.interactSlot(1, false, EmptySlot);
    try std.testing.expect(ret1.success());
    try std.testing.expect(!shelf.isEmpty());
    try std.testing.expectEqual(@as(u3, 1), shelf.bookCount());
    try std.testing.expectEqual(@as(u4, 2), shelf.occupiedComparatorSignal());

    const ret5 = shelf.interactSlot(5, false, EmptySlot);
    try std.testing.expect(ret5.success());
    try std.testing.expect(shelf.isEmpty());
    try std.testing.expectEqual(@as(u3, 0), shelf.bookCount());
    try std.testing.expectEqual(@as(u4, 0), shelf.occupiedComparatorSignal());
    try std.testing.expectEqual(@as(u4, 6), shelf.comparatorSignal());

    _ = shelf.interactSlot(4, false, EnchantedBookTag);
    try std.testing.expect(!shelf.isEmpty());
    try std.testing.expectEqual(@as(u4, 5), shelf.occupiedComparatorSignal());
}

test "20. OccupiedMask: bitmask tracking for all 6 slots and combinations" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    var s: u3 = 0;
    while (s < total_slots) : (s += 1) {
        _ = shelf.setSlot(s, BookTag);
        const expected_bit = @as(u6, 1) << s;
        try std.testing.expectEqual(expected_bit, shelf.occupiedMask());
        try std.testing.expectEqual(expected_bit, occupiedMask(shelf));
        _ = shelf.setSlot(s, EmptySlot);
    }

    _ = shelf.setSlot(0, BookTag);
    _ = shelf.setSlot(1, BookTag);
    _ = shelf.setSlot(2, BookTag);
    try std.testing.expectEqual(@as(u6, 0b000111), shelf.occupiedMask());

    shelf.clear();
    _ = shelf.setSlot(3, BookTag);
    _ = shelf.setSlot(4, BookTag);
    _ = shelf.setSlot(5, BookTag);
    try std.testing.expectEqual(@as(u6, 0b111000), shelf.occupiedMask());

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

    const ret1 = shelf.interactSlot(1, true, BookTag);
    try std.testing.expect(ret1.success());
    try std.testing.expectEqual(InteractAction.retrieved, ret1.action);
    try std.testing.expectEqual(EnchantedBookTag, ret1.item_id);
    try std.testing.expectEqual(@as(u3, 5), shelf.bookCount());
    try std.testing.expect(!shelf.isFull());
    try std.testing.expectEqual(@as(u4, 2), shelf.comparatorSignal());
}

test "22. Direct UV interaction via interactUV" {
    var shelf = ChiseledBookshelfStorage.init(0, 0, 0, .north);

    const res2 = shelf.interactUV(0.85, 0.80, true, BookTag);
    try std.testing.expect(res2.success());
    try std.testing.expectEqual(@as(u3, 2), res2.slot);
    try std.testing.expectEqual(BookTag, shelf.getSlot(2).?);
    try std.testing.expectEqual(@as(u4, 3), shelf.comparatorSignal());

    const res4 = shelf.interactUV(0.50, 0.20, false, BookAndQuillTag);
    try std.testing.expect(res4.success());
    try std.testing.expectEqual(@as(u3, 4), res4.slot);
    try std.testing.expectEqual(BookAndQuillTag, shelf.getSlot(4).?);
    try std.testing.expectEqual(@as(u4, 5), shelf.comparatorSignal());

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

// --- Consolidated SecretLatch & PistonDoor tests (33 tests) ---

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
    try std.testing.expect(SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "three bookshelf password matches" {
    const pass = [_]u3{ 2, 5, 0 };
    const shelves = makeShelves(&pass);
    try std.testing.expect(SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "four bookshelf password matches" {
    const pass = [_]u3{ 2, 5, 0, 4 };
    const shelves = makeShelves(&pass);
    try std.testing.expect(SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "two shelf combination outputs full power" {
    const pass = [_]u3{ 1, 3 };
    const shelves = makeShelves(&pass);
    try std.testing.expectEqual(unlocked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "three shelf combination outputs full power" {
    const pass = [_]u3{ 1, 3, 5 };
    const shelves = makeShelves(&pass);
    try std.testing.expectEqual(unlocked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "four shelf combination outputs full power" {
    const pass = [_]u3{ 1, 3, 5, 0 };
    const shelves = makeShelves(&pass);
    try std.testing.expectEqual(unlocked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "first shelf mismatch keeps signal at zero" {
    const pass = [_]u3{ 1, 2, 3 };
    const shelves = makeShelves(&[_]u3{ 0, 2, 3 });
    try std.testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "middle shelf mismatch keeps signal at zero" {
    const pass = [_]u3{ 1, 2, 3 };
    const shelves = makeShelves(&[_]u3{ 1, 0, 3 });
    try std.testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "last shelf mismatch keeps signal at zero" {
    const pass = [_]u3{ 1, 2, 3 };
    const shelves = makeShelves(&[_]u3{ 1, 2, 0 });
    try std.testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "a two shelf password rejects one wrong selection" {
    const pass = [_]u3{ 2, 5 };
    const shelves = makeShelves(&[_]u3{ 2, 4 });
    try std.testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "a four shelf password rejects one wrong selection" {
    const pass = [_]u3{ 2, 5, 0, 4 };
    const shelves = makeShelves(&[_]u3{ 2, 5, 1, 4 });
    try std.testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "missing bookshelf prevents a match" {
    const pass = [_]u3{ 2, 5, 0 };
    const shelves = makeShelves(&[_]u3{ 2, 5 });
    try std.testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "extra bookshelf prevents a match" {
    const pass = [_]u3{ 2, 5 };
    const shelves = makeShelves(&[_]u3{ 2, 5, 0 });
    try std.testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "password with fewer than two shelves is invalid" {
    const pass = [_]u3{2};
    const shelves = makeShelves(&pass);
    try std.testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "empty password is invalid" {
    const pass = [_]u3{};
    const shelves = [_]BookshelfState{};
    try std.testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "uninteracted occupied shelf does not match" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    shelves[1].interacted_slot = null;
    try std.testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "removed password book resets its interaction and lock" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    shelves[0].setSlotOccupied(2, false);
    try std.testing.expectEqual(@as(u4, 0), shelves[0].comparatorSignal());
    try std.testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "adding a book resets interaction until the slot is selected" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    shelves[0].setSlotOccupied(4, true);
    try std.testing.expectEqual(locked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
    _ = shelves[0].interact(2);
    try std.testing.expectEqual(unlocked_signal, SecretLatch.init(&pass).outputSignal(&shelves));
}

test "changing selected shelf slot resets combination" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    shelves[1].setSlotOccupied(1, true);
    try std.testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "reselecting password slot restores combination" {
    const pass = [_]u3{ 2, 5 };
    var shelves = makeShelves(&pass);
    _ = shelves[1].interact(1);
    try std.testing.expect(!SecretLatch.init(&pass).isUnlocked(&shelves));
    _ = shelves[1].interact(5);
    try std.testing.expect(SecretLatch.init(&pass).isUnlocked(&shelves));
}

test "unchanged slot contents preserve selected interaction" {
    var shelf = makeShelves(&[_]u3{3})[0];
    shelf.setSlotOccupied(3, true);
    try std.testing.expectEqual(@as(?u3, 3), shelf.interacted_slot);
}

test "empty slot interaction clears the previous selection" {
    var shelf = makeShelves(&[_]u3{3})[0];
    try std.testing.expect(!shelf.interact(4));
    try std.testing.expectEqual(@as(?u3, null), shelf.interacted_slot);
}

test "bookshelf comparator signal follows selected slot" {
    var shelf = makeShelves(&[_]u3{4})[0];
    try std.testing.expectEqual(@as(u4, 5), shelf.comparatorSignal());
}

test "bookshelf comparator returns zero with no interaction" {
    var shelf = BookshelfState{};
    shelf.setSlotOccupied(0, true);
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
}

test "bookshelf comparator returns zero when selected book disappears" {
    var shelf = makeShelves(&[_]u3{0})[0];
    shelf.occupied_slots = 0;
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
}

test "out of range slot updates are ignored" {
    var shelf = makeShelves(&[_]u3{2})[0];
    shelf.setSlotOccupied(7, false);
    try std.testing.expectEqual(@as(u6, 1 << 2), shelf.occupied_slots);
    try std.testing.expectEqual(@as(?u3, 2), shelf.interacted_slot);
}

test "invalid last interacted slot emits no comparator signal" {
    const shelf = BookshelfState{ .interacted_slot = 7 };
    try std.testing.expectEqual(@as(u4, 0), shelf.comparatorSignal());
}

test "piston door begins sealed" {
    const door = PistonDoor{};
    try std.testing.expect(!door.isPassageOpen());
}

test "unlocked input retracts pistons after six ticks" {
    var door = PistonDoor{};
    for (0..5) |_| try std.testing.expect(!door.tick(unlocked_signal));
    try std.testing.expect(!door.isPassageOpen());
    try std.testing.expect(door.tick(unlocked_signal));
    try std.testing.expect(door.isPassageOpen());
}

test "locked input extends pistons after six ticks" {
    var door = PistonDoor{ .is_retracted = true };
    for (0..5) |_| try std.testing.expect(!door.tick(locked_signal));
    try std.testing.expect(door.isPassageOpen());
    try std.testing.expect(door.tick(locked_signal));
    try std.testing.expect(!door.isPassageOpen());
}

test "pending door transition can be canceled by relocking" {
    var door = PistonDoor{};
    for (0..3) |_| _ = door.tick(unlocked_signal);
    for (0..8) |_| _ = door.tick(locked_signal);
    try std.testing.expect(!door.isPassageOpen());
    try std.testing.expectEqual(@as(u8, 0), door.ticks_remaining);
}

test "door opens after six ticks of a steady unlock input" {
    var door = PistonDoor{};
    for (0..5) |_| _ = door.tick(unlocked_signal);
    try std.testing.expect(door.tick(unlocked_signal));
    try std.testing.expect(door.isPassageOpen());
}

test "intermediate signal levels keep the door locked" {
    var door = PistonDoor{};
    for (0..8) |_| _ = door.tick(6);
    try std.testing.expect(!door.isPassageOpen());
}

// --- Gameplay integration helper tests ---

test "raycastBlockFaceSlot computes exact slot across north face" {
    // Block at (10, 5, 20), hitting north face (nz = -1 -> z = 20.0)
    // Ray from (10.15, 5.80, 18.0) toward +Z hits (10.15, 5.80, 20.0) -> top-left slot 0
    try std.testing.expectEqual(@as(u3, 0), raycastBlockFaceSlot(.{ 10.15, 5.80, 18.0 }, .{ 0.0, 0.0, 1.0 }, 10, 5, 20, 0, 0, -1));
    // Ray hitting center top (10.50, 5.80, 20.0) -> slot 1
    try std.testing.expectEqual(@as(u3, 1), raycastBlockFaceSlot(.{ 10.50, 5.80, 18.0 }, .{ 0.0, 0.0, 1.0 }, 10, 5, 20, 0, 0, -1));
    // Ray hitting bottom-right (10.85, 5.20, 20.0) -> slot 5
    try std.testing.expectEqual(@as(u3, 5), raycastBlockFaceSlot(.{ 10.85, 5.20, 18.0 }, .{ 0.0, 0.0, 1.0 }, 10, 5, 20, 0, 0, -1));
}

test "evaluateBookshelfLatch unlocks single and multi-shelf combinations and ticks door" {
    const latch = SecretLatch.init(&default_latch_password);
    var door = PistonDoor{};

    // Single bookshelf: slot 0 then slot 5 unlocks the latch
    var single = [_]ChiseledBookshelf{ChiseledBookshelf.init(0, 64, 0, .north)};
    _ = single[0].interactSlot(0, false, MendingBookTag);
    const ev1 = evaluateBookshelfLatch(&single, latch, &door);
    try std.testing.expect(!ev1.unlocked);
    try std.testing.expectEqual(locked_signal, ev1.signal);

    _ = single[0].interactSlot(5, false, SwiftSneakBookTag);
    const ev2 = evaluateBookshelfLatch(&single, latch, &door);
    try std.testing.expect(ev2.unlocked);
    try std.testing.expect(ev2.just_unlocked);
    try std.testing.expectEqual(unlocked_signal, ev2.signal);
    try std.testing.expect(!ev2.door_open);

    // Remaining 5 ticks complete the 6-tick piston retraction
    var tick_i: usize = 0;
    while (tick_i < 5) : (tick_i += 1) {
        _ = door.tick(ev2.signal);
    }
    try std.testing.expect(door.isPassageOpen());

    // Multi-shelf combination: two shelves matching [0, 5]
    var pair = [_]ChiseledBookshelf{
        ChiseledBookshelf.init(1, 64, 0, .north),
        ChiseledBookshelf.init(2, 64, 0, .north),
    };
    var pair_door = PistonDoor{};
    _ = pair[0].interactSlot(0, false, SweepingEdgeBookTag);
    _ = pair[1].interactSlot(5, false, FeatherFallingBookTag);
    const ev_pair = evaluateBookshelfLatch(&pair, latch, &pair_door);
    try std.testing.expect(ev_pair.unlocked);
    try std.testing.expect(ev_pair.just_unlocked);
    try std.testing.expectEqual(unlocked_signal, ev_pair.signal);
}
