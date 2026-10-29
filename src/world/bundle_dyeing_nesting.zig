//! ============================================================================
//! Milestone 472: Bundle Storage Nesting & Color Dyeing (16 Dye Variants)
//! ============================================================================
//!
//! Overview:
//!   Implements comprehensive Minecraft 1.21+ compliant Bundle storage mechanics:
//!   1. 64-Weight Fraction System:
//!      - Total capacity: 64 weight units (equivalent to 1 full 64-stack).
//!      - Item contributions:
//!        * 64-stack items: 1 weight unit per item.
//!        * 16-stack items: 4 weight units per item.
//!        * 1-stack items:  64 weight units per item (fills bundle completely).
//!        * Other stack sizes: @divTrunc(64, max_stack).
//!   2. Nested Bundles (Bundles inside Bundles):
//!      - Bundles can be placed inside other bundles.
//!      - Each nested bundle contributes: 4 units (empty baseline) + contents_weight.
//!      - Strict capacity enforcement: adding a bundle whose total weight exceeds
//!        remaining capacity is rejected.
//!      - Prevents recursive loops and self-containment via parent tracking and
//!        ancestor cycle detection.
//!   3. 16 Color Dyeing Pipeline:
//!      - BundleColor: undyed + 16 Minecraft dye variants.
//!      - Crafting Grid Dyeing: 1 Bundle + 1 Dye -> 1 Dyed Bundle matching color,
//!        preserving all stored contents and nested bundles.
//!      - Cauldron Washing: Right-clicking a water cauldron with a dyed bundle
//!        removes the dye, reverting to undyed and consuming 1 cauldron water level.
//!   4. Extraction & Insertion Mechanics:
//!      - Insert item: Adds items or bundles up to remaining capacity.
//!      - Extract item (LIFO): Returns the top item stack or nested bundle.
//!      - Dump all: Unloads all contained items and bundles.
//!   5. Redstone Comparator Signal:
//!      - signal = @as(u4, @intFromFloat(@ceil((current_weight / 64.0) * 15.0)))
//!      - Outputs 0 when empty, 1..15 when holding items.

const std = @import("std");
const cauldron_fluids = @import("cauldron_fluids.zig");

// ============================================================================
// Constants & Weight Rules
// ============================================================================

/// Total weight capacity of a bundle pouch (64 weight units).
pub const TOTAL_BUNDLE_CAPACITY: u8 = 64;
pub const MAX_BUNDLE_WEIGHT: u8 = TOTAL_BUNDLE_CAPACITY;

/// Baseline weight occupied by an empty bundle when nested inside another bundle.
pub const EMPTY_BUNDLE_BASE_WEIGHT: u8 = 4;

/// Maximum distinct item/bundle entries inside a single bundle.
pub const MAX_BUNDLE_ENTRIES: usize = 64;

/// Maximum nesting depth allowed to protect against deep recursion.
pub const MAX_NESTING_DEPTH: usize = 16;

/// Default standard item ID for a Bundle pouch.
pub const BUNDLE_ITEM_ID: u16 = 371;

/// Calculates the weight unit per item based on max_stack size:
/// - 64-stack item = 1 weight unit (e.g. 64 dirt = 64 units)
/// - 16-stack item = 4 weight units (e.g. 1 ender pearl = 4 units, max 16 = 64 units)
/// - 1-stack item  = 64 weight units (e.g. 1 sword = 64 units)
/// - other stack sizes = @divTrunc(64, max_stack) (or 0 if max_stack == 0)
pub fn itemWeight(max_stack: u8) u8 {
    if (max_stack == 0) return 0;
    return switch (max_stack) {
        1 => 64,
        16 => 4,
        64 => 1,
        else => @divTrunc(@as(u8, 64), max_stack),
    };
}

/// Total weight for `count` items with `max_stack`.
pub fn stackWeight(max_stack: u8, count: u8) u16 {
    return @as(u16, itemWeight(max_stack)) * @as(u16, count);
}

/// Computes the redstone comparator output signal for a given current weight:
/// signal = @as(u4, @intFromFloat(@ceil((current_weight / 64.0) * 15.0)))
/// Outputs 0 when empty, 1..15 when holding items.
pub fn comparatorSignalForWeight(current_weight: u8) u4 {
    if (current_weight == 0) return 0;
    const fullness: f32 = @as(f32, @floatFromInt(current_weight)) / 64.0;
    const signal: u4 = @as(u4, @intFromFloat(@ceil(fullness * 15.0)));
    return @min(15, signal);
}

pub const comparatorSignal = comparatorSignalForWeight;

// ============================================================================
// Dye Color & Bundle Color Definitions
// ============================================================================

/// Canonical 16 Minecraft dye colors.
pub const DyeColor = enum(u4) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,

    pub const count: usize = 16;

    /// 24-bit sRGB color (0xRRGGBB).
    pub fn rgbHex(self: DyeColor) u32 {
        return switch (self) {
            .white => 0xF9FFFE,
            .orange => 0xF9801D,
            .magenta => 0xC74EBD,
            .light_blue => 0x3AB3DA,
            .yellow => 0xFED83D,
            .lime => 0x80C71F,
            .pink => 0xF38BAA,
            .gray => 0x474F52,
            .light_gray => 0x9D9D97,
            .cyan => 0x169C9C,
            .purple => 0x8932B8,
            .blue => 0x3C44AA,
            .brown => 0x835432,
            .green => 0x5E7C16,
            .red => 0xB02E26,
            .black => 0x1D1D21,
        };
    }

    pub fn name(self: DyeColor) []const u8 {
        return switch (self) {
            .white => "White",
            .orange => "Orange",
            .magenta => "Magenta",
            .light_blue => "Light Blue",
            .yellow => "Yellow",
            .lime => "Lime",
            .pink => "Pink",
            .gray => "Gray",
            .light_gray => "Light Gray",
            .cyan => "Cyan",
            .purple => "Purple",
            .blue => "Blue",
            .brown => "Brown",
            .green => "Green",
            .red => "Red",
            .black => "Black",
        };
    }
};

/// Bundle color: undyed natural leather plus the 16 dyed color variants.
pub const BundleColor = enum(u8) {
    undyed = 0,
    white = 1,
    orange = 2,
    magenta = 3,
    light_blue = 4,
    yellow = 5,
    lime = 6,
    pink = 7,
    gray = 8,
    light_gray = 9,
    cyan = 10,
    purple = 11,
    blue = 12,
    brown = 13,
    green = 14,
    red = 15,
    black = 16,

    pub const count: usize = 17;

    pub fn isDyed(self: BundleColor) bool {
        return self != .undyed;
    }

    pub fn fromDyeColor(dye: DyeColor) BundleColor {
        return switch (dye) {
            .white => .white,
            .orange => .orange,
            .magenta => .magenta,
            .light_blue => .light_blue,
            .yellow => .yellow,
            .lime => .lime,
            .pink => .pink,
            .gray => .gray,
            .light_gray => .light_gray,
            .cyan => .cyan,
            .purple => .purple,
            .blue => .blue,
            .brown => .brown,
            .green => .green,
            .red => .red,
            .black => .black,
        };
    }

    pub fn toDyeColor(self: BundleColor) ?DyeColor {
        return switch (self) {
            .undyed => null,
            .white => .white,
            .orange => .orange,
            .magenta => .magenta,
            .light_blue => .light_blue,
            .yellow => .yellow,
            .lime => .lime,
            .pink => .pink,
            .gray => .gray,
            .light_gray => .light_gray,
            .cyan => .cyan,
            .purple => .purple,
            .blue => .blue,
            .brown => .brown,
            .green => .green,
            .red => .red,
            .black => .black,
        };
    }

    pub fn rgbHex(self: BundleColor) u32 {
        if (self.toDyeColor()) |d| {
            return d.rgbHex();
        }
        // Default undyed bundle natural leather tone
        return 0xC7935E;
    }

    pub fn name(self: BundleColor) []const u8 {
        return switch (self) {
            .undyed => "Undyed",
            .white => "White",
            .orange => "Orange",
            .magenta => "Magenta",
            .light_blue => "Light Blue",
            .yellow => "Yellow",
            .lime => "Lime",
            .pink => "Pink",
            .gray => "Gray",
            .light_gray => "Light Gray",
            .cyan => "Cyan",
            .purple => "Purple",
            .blue => "Blue",
            .brown => "Brown",
            .green => "Green",
            .red => "Red",
            .black => "Black",
        };
    }

    pub fn displayName(self: BundleColor) []const u8 {
        return switch (self) {
            .undyed => "Bundle",
            .white => "White Bundle",
            .orange => "Orange Bundle",
            .magenta => "Magenta Bundle",
            .light_blue => "Light Blue Bundle",
            .yellow => "Yellow Bundle",
            .lime => "Lime Bundle",
            .pink => "Pink Bundle",
            .gray => "Gray Bundle",
            .light_gray => "Light Gray Bundle",
            .cyan => "Cyan Bundle",
            .purple => "Purple Bundle",
            .blue => "Blue Bundle",
            .brown => "Brown Bundle",
            .green => "Green Bundle",
            .red => "Red Bundle",
            .black => "Black Bundle",
        };
    }
};

// ============================================================================
// Errors
// ============================================================================

pub const BundleError = error{
    BundleFull,
    CapacityExceeded,
    SelfContainment,
    RecursiveLoopDetected,
    AlreadyNested,
    MaxEntriesReached,
    InvalidItem,
    InvalidCount,
    CauldronEmpty,
    CauldronNotWater,
    BundleNotDyed,
    InvalidDyeRecipe,
};

// ============================================================================
// Storage Data Types
// ============================================================================

/// Represents a regular item stack stored in a bundle.
pub const StoredItem = struct {
    item_id: u16 = 0,
    count: u8 = 0,
    max_stack: u8 = 64,

    pub fn weight(self: StoredItem) u8 {
        if (self.item_id == 0 or self.count == 0) return 0;
        const unit = itemWeight(self.max_stack);
        const w = @as(u16, unit) * @as(u16, self.count);
        return @intCast(@min(TOTAL_BUNDLE_CAPACITY, w));
    }

    pub fn isEmpty(self: StoredItem) bool {
        return self.item_id == 0 or self.count == 0;
    }
};

pub const EntryKind = enum {
    empty,
    item,
    bundle,
};

/// A single entry in the bundle, either an item stack or a nested bundle reference.
pub const BundleEntry = struct {
    kind: EntryKind = .empty,
    item: StoredItem = .{},
    nested_bundle: ?*Bundle = null,

    /// Weight unit occupied by this entry.
    /// For nested bundles: 4 baseline units + nested bundle contents weight.
    pub fn weight(self: BundleEntry) u8 {
        return switch (self.kind) {
            .empty => 0,
            .item => self.item.weight(),
            .bundle => if (self.nested_bundle) |b| EMPTY_BUNDLE_BASE_WEIGHT + b.totalWeight() else 0,
        };
    }

    pub fn isEmpty(self: BundleEntry) bool {
        return self.kind == .empty;
    }
};

/// Item or Bundle returned from LIFO extraction or full dumping.
pub const ExtractedEntry = union(enum) {
    item: StoredItem,
    bundle: *Bundle,

    pub fn isItem(self: ExtractedEntry) bool {
        return self == .item;
    }

    pub fn isBundle(self: ExtractedEntry) bool {
        return self == .bundle;
    }

    pub fn asItem(self: ExtractedEntry) ?StoredItem {
        return switch (self) {
            .item => |i| i,
            .bundle => null,
        };
    }

    pub fn asBundle(self: ExtractedEntry) ?*Bundle {
        return switch (self) {
            .item => null,
            .bundle => |b| b,
        };
    }
};

// ============================================================================
// Bundle Structure & Core Implementation
// ============================================================================

pub const Bundle = struct {
    id: u32 = 0,
    color: BundleColor = .undyed,
    entries: [MAX_BUNDLE_ENTRIES]BundleEntry = [_]BundleEntry{.{}} ** MAX_BUNDLE_ENTRIES,
    entry_count: u8 = 0,
    parent: ?*Bundle = null,
    selected_index: ?u8 = null,

    pub const max_capacity: u8 = TOTAL_BUNDLE_CAPACITY;
    pub const base_nested_weight: u8 = EMPTY_BUNDLE_BASE_WEIGHT;
    pub const max_entries: usize = MAX_BUNDLE_ENTRIES;

    pub fn init(id: u32, color: BundleColor) Bundle {
        return .{
            .id = id,
            .color = color,
            .entries = [_]BundleEntry{.{}} ** MAX_BUNDLE_ENTRIES,
            .entry_count = 0,
            .parent = null,
            .selected_index = null,
        };
    }

    /// Computes the exact weight of all stored entries (0..64).
    pub fn totalWeight(self: *const Bundle) u8 {
        var sum: u16 = 0;
        var i: usize = 0;
        while (i < self.entry_count) : (i += 1) {
            sum += self.entries[i].weight();
        }
        return @intCast(@min(TOTAL_BUNDLE_CAPACITY, sum));
    }

    /// Weight contributed by this bundle when stored inside another bundle:
    /// 4 units baseline + contents weight.
    pub fn nestedBundleWeight(self: *const Bundle) u8 {
        const w = @as(u16, EMPTY_BUNDLE_BASE_WEIGHT) + @as(u16, self.totalWeight());
        return @intCast(@min(TOTAL_BUNDLE_CAPACITY, w));
    }

    /// Free weight remaining before reaching 64.
    pub fn remainingCapacity(self: *const Bundle) u8 {
        const current = self.totalWeight();
        if (current >= TOTAL_BUNDLE_CAPACITY) return 0;
        return TOTAL_BUNDLE_CAPACITY - current;
    }

    pub fn isFull(self: *const Bundle) bool {
        return self.totalWeight() >= TOTAL_BUNDLE_CAPACITY;
    }

    pub fn isEmpty(self: *const Bundle) bool {
        return self.entry_count == 0;
    }

    pub fn fullnessRatio(self: *const Bundle) f32 {
        return @as(f32, @floatFromInt(self.totalWeight())) / @as(f32, @floatFromInt(TOTAL_BUNDLE_CAPACITY));
    }

    pub fn comparatorSignal(self: *const Bundle) u4 {
        return comparatorSignalForWeight(self.totalWeight());
    }

    pub fn displayName(self: *const Bundle) []const u8 {
        return self.color.displayName();
    }

    // ------------------------------------------------------------------------
    // Ancestry and Loop Prevention
    // ------------------------------------------------------------------------

    /// Returns true if this bundle is a descendant of the given potential ancestor.
    pub fn isDescendantOf(self: *const Bundle, potential_ancestor: *const Bundle) bool {
        var curr = self.parent;
        while (curr) |p| {
            if (p == potential_ancestor) return true;
            curr = p.parent;
        }
        return false;
    }

    /// Recursively checks if this bundle directly or indirectly contains `target`.
    pub fn containsBundle(self: *const Bundle, target: *const Bundle) bool {
        if (self == target) return true;
        var i: usize = 0;
        while (i < self.entry_count) : (i += 1) {
            const entry = self.entries[i];
            if (entry.kind == .bundle) {
                if (entry.nested_bundle) |child| {
                    if (child == target or child.containsBundle(target)) return true;
                }
            }
        }
        return false;
    }

    /// Checks if this bundle and all its parent ancestors can accommodate `added_weight`.
    pub fn canAcceptWeight(self: *const Bundle, added_weight: u8) bool {
        if (@as(u16, self.totalWeight()) + @as(u16, added_weight) > TOTAL_BUNDLE_CAPACITY) {
            return false;
        }
        if (self.parent) |p| {
            return p.canAcceptWeight(added_weight);
        }
        return true;
    }

    // ------------------------------------------------------------------------
    // Insertion
    // ------------------------------------------------------------------------

    /// Inserts up to `count` items into the bundle.
    /// Returns the number of items actually accepted.
    pub fn insertItem(self: *Bundle, item_id: u16, count: u8, max_stack: u8) u8 {
        if (item_id == 0 or count == 0 or max_stack == 0) return 0;
        const unit = itemWeight(max_stack);
        if (unit == 0) return 0;

        // Determine available weight across this bundle and any parent chain
        var available_weight = self.remainingCapacity();
        var ancestor = self.parent;
        while (ancestor) |anc| {
            available_weight = @min(available_weight, anc.remainingCapacity());
            ancestor = anc.parent;
        }

        const max_by_weight = available_weight / unit;
        if (max_by_weight == 0) return 0;

        var to_insert = @min(count, max_by_weight);
        var accepted: u8 = 0;

        // 1. Try to merge into the top item if it matches
        if (self.entry_count > 0) {
            const top = &self.entries[self.entry_count - 1];
            if (top.kind == .item and top.item.item_id == item_id and top.item.max_stack == max_stack and top.item.count < max_stack) {
                const space = max_stack - top.item.count;
                const add = @min(to_insert, space);
                top.item.count += add;
                to_insert -= add;
                accepted += add;
            }
        }

        // 2. Try to merge into other existing matching item entries
        var i: usize = 0;
        while (i < self.entry_count and to_insert > 0) : (i += 1) {
            const entry = &self.entries[i];
            if (entry.kind == .item and entry.item.item_id == item_id and entry.item.max_stack == max_stack and entry.item.count < max_stack) {
                const space = max_stack - entry.item.count;
                const add = @min(to_insert, space);
                entry.item.count += add;
                to_insert -= add;
                accepted += add;
            }
        }

        // 3. Push new entries if space and entry capacity remain
        while (to_insert > 0 and self.entry_count < MAX_BUNDLE_ENTRIES) {
            const add = @min(to_insert, max_stack);
            self.entries[self.entry_count] = .{
                .kind = .item,
                .item = .{
                    .item_id = item_id,
                    .count = add,
                    .max_stack = max_stack,
                },
                .nested_bundle = null,
            };
            self.entry_count += 1;
            to_insert -= add;
            accepted += add;
        }

        return accepted;
    }

    /// Validates whether `child` bundle can be inserted into `self`.
    pub fn canInsertBundle(self: *const Bundle, child: *const Bundle) bool {
        if (child == self) return false;
        if (child.parent != null) return false;
        if (self.isDescendantOf(child)) return false;
        if (child.containsBundle(self)) return false;
        if (self.entry_count >= MAX_BUNDLE_ENTRIES) return false;

        const child_weight = @as(u16, EMPTY_BUNDLE_BASE_WEIGHT) + @as(u16, child.totalWeight());
        if (child_weight > TOTAL_BUNDLE_CAPACITY) return false;

        return self.canAcceptWeight(@intCast(child_weight));
    }

    /// Inserts a nested bundle into this bundle.
    /// Strictly rejects capacity overflow, self-containment, and recursive cycles.
    pub fn insertBundle(self: *Bundle, child: *Bundle) BundleError!void {
        if (child == self) {
            return BundleError.SelfContainment;
        }
        if (child.parent != null) {
            return BundleError.AlreadyNested;
        }
        if (self.isDescendantOf(child) or child.containsBundle(self)) {
            return BundleError.RecursiveLoopDetected;
        }
        if (self.entry_count >= MAX_BUNDLE_ENTRIES) {
            return BundleError.MaxEntriesReached;
        }

        const child_weight = @as(u16, EMPTY_BUNDLE_BASE_WEIGHT) + @as(u16, child.totalWeight());
        if (child_weight > TOTAL_BUNDLE_CAPACITY or !self.canAcceptWeight(@intCast(child_weight))) {
            return BundleError.CapacityExceeded;
        }

        self.entries[self.entry_count] = .{
            .kind = .bundle,
            .item = .{},
            .nested_bundle = child,
        };
        self.entry_count += 1;
        child.parent = self;
    }

    /// Non-error variant: returns true if child bundle was successfully inserted.
    pub fn tryInsertBundle(self: *Bundle, child: *Bundle) bool {
        self.insertBundle(child) catch return false;
        return true;
    }

    // ------------------------------------------------------------------------
    // Extraction (LIFO) & Dumping
    // ------------------------------------------------------------------------

    /// Extracts the top item stack or nested bundle in LIFO order.
    pub fn extract(self: *Bundle) ?ExtractedEntry {
        if (self.entry_count == 0) return null;

        const target_idx: usize = if (self.selected_index) |idx|
            if (idx < self.entry_count) idx else self.entry_count - 1
        else
            self.entry_count - 1;

        const entry = self.entries[target_idx];

        // Shift remaining entries to maintain contiguous array
        var j: usize = target_idx;
        while (j + 1 < self.entry_count) : (j += 1) {
            self.entries[j] = self.entries[j + 1];
        }
        self.entries[self.entry_count - 1] = .{};
        self.entry_count -= 1;

        // Adjust scroll selection
        if (self.entry_count == 0) {
            self.selected_index = null;
        } else if (self.selected_index) |sel| {
            if (sel >= self.entry_count) {
                self.selected_index = @intCast(self.entry_count - 1);
            }
        }

        return switch (entry.kind) {
            .empty => null,
            .item => ExtractedEntry{ .item = entry.item },
            .bundle => if (entry.nested_bundle) |b| blk: {
                b.parent = null;
                break :blk ExtractedEntry{ .bundle = b };
            } else null,
        };
    }

    /// Extracts the top entry specifically as an item, or null if top is a bundle or empty.
    pub fn extractItem(self: *Bundle) ?StoredItem {
        if (self.entry_count == 0) return null;
        if (self.entries[self.entry_count - 1].kind != .item) return null;
        const ext = self.extract() orelse return null;
        return ext.asItem();
    }

    /// Extracts the top entry specifically as a nested bundle, or null if top is an item.
    pub fn extractBundle(self: *Bundle) ?*Bundle {
        if (self.entry_count == 0) return null;
        if (self.entries[self.entry_count - 1].kind != .bundle) return null;
        const ext = self.extract() orelse return null;
        return ext.asBundle();
    }

    /// Dumps all contained entries in LIFO order into `out_buf`.
    /// Returns the number of entries dumped.
    pub fn dumpAll(self: *Bundle, out_buf: []ExtractedEntry) usize {
        if (self.entry_count == 0 or out_buf.len == 0) return 0;
        const to_dump: usize = @min(@as(usize, self.entry_count), out_buf.len);

        var i: usize = 0;
        while (i < to_dump) : (i += 1) {
            const idx = self.entry_count - 1 - i;
            const entry = self.entries[idx];
            switch (entry.kind) {
                .empty => {},
                .item => {
                    out_buf[i] = .{ .item = entry.item };
                },
                .bundle => {
                    if (entry.nested_bundle) |b| {
                        b.parent = null;
                        out_buf[i] = .{ .bundle = b };
                    }
                },
            }
        }

        if (to_dump == self.entry_count) {
            self.entry_count = 0;
            self.selected_index = null;
            for (&self.entries) |*e| {
                e.* = .{};
            }
        } else {
            self.entry_count -= @intCast(to_dump);
            if (self.selected_index) |sel| {
                if (self.entry_count == 0) {
                    self.selected_index = null;
                } else if (sel >= self.entry_count) {
                    self.selected_index = @intCast(self.entry_count - 1);
                }
            }
            for (self.entries[self.entry_count..]) |*e| {
                e.* = .{};
            }
        }

        return to_dump;
    }

    /// Dumps only regular stored items into `out_buf` (does not unpack nested bundles).
    pub fn dumpAllItems(self: *Bundle, out_buf: []StoredItem) usize {
        var count: usize = 0;
        var i: usize = 0;
        while (i < self.entry_count and count < out_buf.len) : (i += 1) {
            if (self.entries[i].kind == .item) {
                out_buf[count] = self.entries[i].item;
                count += 1;
            }
        }
        return count;
    }

    // ------------------------------------------------------------------------
    // Scroll & Tooltip Selection
    // ------------------------------------------------------------------------

    pub fn setSelection(self: *Bundle, index: ?u8) void {
        if (index) |idx| {
            if (idx < self.entry_count) {
                self.selected_index = idx;
            } else if (self.entry_count > 0) {
                self.selected_index = @intCast(self.entry_count - 1);
            } else {
                self.selected_index = null;
            }
        } else {
            self.selected_index = null;
        }
    }

    pub fn scroll(self: *Bundle, delta: i8) void {
        if (self.entry_count == 0) {
            self.selected_index = null;
            return;
        }
        const count: i16 = @intCast(self.entry_count);
        const current: i16 = if (self.selected_index) |idx| @intCast(idx) else count - 1;
        var next = @mod(current + delta, count);
        if (next < 0) next += count;
        self.selected_index = @intCast(next);
    }

    // ------------------------------------------------------------------------
    // Dyeing & Cauldron Washing
    // ------------------------------------------------------------------------

    /// Applies a dye color in-place to this bundle.
    pub fn applyDye(self: *Bundle, dye: DyeColor) void {
        self.color = BundleColor.fromDyeColor(dye);
    }

    /// Reverts bundle to undyed default. Returns true if dye was cleared.
    pub fn undye(self: *Bundle) bool {
        if (self.color == .undyed) return false;
        self.color = .undyed;
        return true;
    }

    /// Interacts with a water cauldron: if bundle is dyed, reverts to undyed
    /// and lowers cauldron water level by 1 level.
    pub fn wash(self: *Bundle, cauldron_target: anytype) bool {
        const T = @TypeOf(cauldron_target);
        if (T == *u2) {
            return washBundleInCauldron(self, cauldron_target);
        } else if (T == *Cauldron) {
            return cauldron_target.washBundle(self);
        } else if (T == *cauldron_fluids.CauldronState) {
            return washBundleInCauldronState(self, cauldron_target);
        } else {
            @compileError("Unsupported cauldron type for bundle washing");
        }
    }
};

// ============================================================================
// Crafting Grid Dyeing
// ============================================================================

/// Represents one ingredient slot in a crafting grid.
pub const CraftingGridSlot = union(enum) {
    empty,
    bundle: Bundle,
    bundle_ref: *const Bundle,
    dye: DyeColor,
    other: u16,
};

/// Crafts a dyed bundle from 1 Bundle + 1 Dye.
/// Preserves all stored contents and nested bundles inside the bundle!
pub fn craftDyeBundle(bundle: *const Bundle, dye: DyeColor) Bundle {
    var dyed = bundle.*;
    dyed.color = BundleColor.fromDyeColor(dye);
    return dyed;
}

/// Alias for craftDyeBundle matching specification naming.
pub fn craftBundleDye(bundle: *const Bundle, dye: DyeColor) Bundle {
    return craftDyeBundle(bundle, dye);
}

/// Evaluates a crafting grid (e.g. 2x2 or 3x3 slots):
/// Exactly 1 Bundle + 1 Dye (and empty remaining slots) yields 1 Dyed Bundle.
/// Returns null if the recipe does not match.
pub fn craftDyeGrid(grid: []const CraftingGridSlot) ?Bundle {
    var found_bundle: ?Bundle = null;
    var found_dye: ?DyeColor = null;

    for (grid) |slot| {
        switch (slot) {
            .empty => {},
            .bundle => |b| {
                if (found_bundle != null) return null; // Only 1 bundle allowed
                found_bundle = b;
            },
            .bundle_ref => |b| {
                if (found_bundle != null) return null;
                found_bundle = b.*;
            },
            .dye => |d| {
                if (found_dye != null) return null; // Only 1 dye allowed
                found_dye = d;
            },
            .other => return null, // Extraneous items invalidate recipe
        }
    }

    if (found_bundle) |b| {
        if (found_dye) |d| {
            return craftDyeBundle(&b, d);
        }
    }
    return null;
}

// ============================================================================
// Cauldron Washing Mechanics
// ============================================================================

/// Standalone Water Cauldron container for washing dyed items.
pub const Cauldron = struct {
    water_level: u2 = 3,
    is_water: bool = true,

    pub fn init(water_level: u2) Cauldron {
        return .{
            .water_level = water_level,
            .is_water = true,
        };
    }

    pub fn washBundle(self: *Cauldron, bundle: *Bundle) bool {
        if (!self.is_water or self.water_level == 0) return false;
        if (!bundle.color.isDyed()) return false;

        bundle.color = .undyed;
        self.water_level -= 1;
        return true;
    }
};

/// Washes a dyed bundle in a water cauldron represented by a `*u2` water level.
/// If dyed and water_level > 0: reverts to undyed and decrements water level by 1.
/// Returns true on success, false if empty or already undyed.
pub fn washBundleInCauldron(bundle: *Bundle, water_level: *u2) bool {
    if (water_level.* == 0) return false;
    if (!bundle.color.isDyed()) return false;

    bundle.color = .undyed;
    water_level.* -= 1;
    return true;
}

/// Washes a dyed bundle in a `CauldronState` from `cauldron_fluids.zig`.
pub fn washBundleInCauldronState(bundle: *Bundle, state: *cauldron_fluids.CauldronState) bool {
    if (!state.isWater() or state.level == 0) return false;
    if (!bundle.color.isDyed()) return false;

    bundle.color = .undyed;
    state.level -= 1;
    if (state.level == 0) {
        state.content = .empty;
    }
    return true;
}

// ============================================================================
// Fixed-buffer Bundle Pool for Memory-Safe Multi-Bundle Nesting
// ============================================================================

pub fn BundlePool(comptime capacity: usize) type {
    return struct {
        const Self = @This();
        storage: [capacity]Bundle = undefined,
        used: [capacity]bool = [_]bool{false} ** capacity,
        active_count: usize = 0,

        pub fn init() Self {
            var pool = Self{
                .storage = undefined,
                .used = [_]bool{false} ** capacity,
                .active_count = 0,
            };
            for (&pool.storage, 0..) |*b, i| {
                b.* = Bundle.init(@intCast(i + 1), .undyed);
            }
            return pool;
        }

        pub fn create(self: *Self, id: u32, color: BundleColor) ?*Bundle {
            for (&self.storage, 0..) |*b, i| {
                if (!self.used[i]) {
                    self.used[i] = true;
                    self.active_count += 1;
                    b.* = Bundle.init(id, color);
                    return b;
                }
            }
            return null;
        }

        pub fn release(self: *Self, bundle_ptr: *Bundle) void {
            for (&self.storage, 0..) |*b, i| {
                if (b == bundle_ptr) {
                    if (self.used[i]) {
                        self.used[i] = false;
                        self.active_count -= 1;
                        bundle_ptr.* = Bundle.init(@intCast(i + 1), .undyed);
                    }
                    return;
                }
            }
        }
    };
}


// ============================================================================
// UNIT TESTS (Milestone 472 Specification Verification)
// ============================================================================

test "1. Capacity weight math: 64-stack item contributes 1 unit per item" {
    try std.testing.expectEqual(@as(u8, 1), itemWeight(64));
    try std.testing.expectEqual(@as(u16, 1), stackWeight(64, 1));
    try std.testing.expectEqual(@as(u16, 32), stackWeight(64, 32));
    try std.testing.expectEqual(@as(u16, 64), stackWeight(64, 64));

    var bundle = Bundle.init(1, .undyed);
    const accepted = bundle.insertItem(10, 64, 64);
    try std.testing.expectEqual(@as(u8, 64), accepted);
    try std.testing.expectEqual(@as(u8, 64), bundle.totalWeight());
    try std.testing.expect(bundle.isFull());
}

test "2. Capacity weight math: 16-stack item contributes 4 units per item" {
    try std.testing.expectEqual(@as(u8, 4), itemWeight(16));
    try std.testing.expectEqual(@as(u16, 4), stackWeight(16, 1));
    try std.testing.expectEqual(@as(u16, 32), stackWeight(16, 8));
    try std.testing.expectEqual(@as(u16, 64), stackWeight(16, 16));

    var bundle = Bundle.init(1, .undyed);
    // 1 ender pearl = 4 weight units
    const accepted1 = bundle.insertItem(20, 1, 16);
    try std.testing.expectEqual(@as(u8, 1), accepted1);
    try std.testing.expectEqual(@as(u8, 4), bundle.totalWeight());

    // 15 more pearls fill remaining 60 units (15 * 4 = 60)
    const accepted2 = bundle.insertItem(20, 15, 16);
    try std.testing.expectEqual(@as(u8, 15), accepted2);
    try std.testing.expectEqual(@as(u8, 64), bundle.totalWeight());
    try std.testing.expect(bundle.isFull());
}

test "3. Capacity weight math: 1-stack item contributes 64 units per item" {
    try std.testing.expectEqual(@as(u8, 64), itemWeight(1));
    try std.testing.expectEqual(@as(u16, 64), stackWeight(1, 1));

    var bundle = Bundle.init(1, .undyed);
    // 1 sword fills the bundle completely
    const accepted = bundle.insertItem(100, 1, 1);
    try std.testing.expectEqual(@as(u8, 1), accepted);
    try std.testing.expectEqual(@as(u8, 64), bundle.totalWeight());
    try std.testing.expect(bundle.isFull());
    try std.testing.expectEqual(@as(u8, 0), bundle.remainingCapacity());

    // Trying to insert another item fails completely
    try std.testing.expectEqual(@as(u8, 0), bundle.insertItem(10, 1, 64));
}

test "4. Capacity weight math: arbitrary stack sizes and stackWeight helper" {
    try std.testing.expectEqual(@as(u8, 0), itemWeight(0));
    try std.testing.expectEqual(@as(u8, 2), itemWeight(32)); // 64 / 32 = 2
    try std.testing.expectEqual(@as(u8, 8), itemWeight(8));  // 64 / 8 = 8
    try std.testing.expectEqual(@as(u8, 16), itemWeight(4)); // 64 / 4 = 16
    try std.testing.expectEqual(@as(u8, 32), itemWeight(2)); // 64 / 2 = 32

    try std.testing.expectEqual(@as(u16, 20), stackWeight(32, 10)); // 10 * 2 = 20
    try std.testing.expectEqual(@as(u16, 40), stackWeight(8, 5));   // 5 * 8 = 40
}

test "5. Empty bundle baseline weight: 4 units when nested" {
    var outer = Bundle.init(1, .undyed);
    var inner = Bundle.init(2, .white);

    try std.testing.expectEqual(@as(u8, 0), inner.totalWeight());
    try std.testing.expectEqual(@as(u8, 4), inner.nestedBundleWeight());

    try outer.insertBundle(&inner);
    try std.testing.expectEqual(@as(u8, 4), outer.totalWeight());
    try std.testing.expectEqual(@as(u8, 60), outer.remainingCapacity());
}

test "6. Nested bundle weight calculation: 4 base + contents weight" {
    var outer = Bundle.init(1, .undyed);
    var inner = Bundle.init(2, .cyan);

    // Add 10 dirt (weight 10) into inner bundle
    _ = inner.insertItem(1, 10, 64);
    try std.testing.expectEqual(@as(u8, 10), inner.totalWeight());

    // Nested weight must be 4 base + 10 contents = 14
    try std.testing.expectEqual(@as(u8, 14), inner.nestedBundleWeight());

    try outer.insertBundle(&inner);
    try std.testing.expectEqual(@as(u8, 14), outer.totalWeight());
    try std.testing.expectEqual(@as(u8, 50), outer.remainingCapacity());

    // Also add 1 pearl (weight 4) into inner bundle while nested:
    // inner contents weight becomes 14, nested weight becomes 4 + 14 = 18
    _ = inner.insertItem(2, 1, 16);
    try std.testing.expectEqual(@as(u8, 14), inner.totalWeight());
    try std.testing.expectEqual(@as(u8, 18), inner.nestedBundleWeight());
    try std.testing.expectEqual(@as(u8, 18), outer.totalWeight());
}

test "7. Multi-level nested bundles: 3-level nesting weight propagation" {
    var level1 = Bundle.init(1, .undyed);
    var level2 = Bundle.init(2, .blue);
    var level3 = Bundle.init(3, .red);

    // level3 contains 8 dirt (weight 8)
    _ = level3.insertItem(10, 8, 64);
    try std.testing.expectEqual(@as(u8, 8), level3.totalWeight());

    // level2 nests level3 -> weight: 4 + 8 = 12
    try level2.insertBundle(&level3);
    try std.testing.expectEqual(@as(u8, 12), level2.totalWeight());
    try std.testing.expectEqual(@as(u8, 16), level2.nestedBundleWeight()); // 4 base + 12

    // level1 nests level2 -> weight: 4 + 12 = 16
    try level1.insertBundle(&level2);
    try std.testing.expectEqual(@as(u8, 16), level1.totalWeight());
    try std.testing.expectEqual(@as(u8, 48), level1.remainingCapacity());
}

test "8. Multiple nested bundles in parallel inside a single bundle" {
    var outer = Bundle.init(1, .undyed);
    var b1 = Bundle.init(2, .white); // empty: 4 units
    var b2 = Bundle.init(3, .orange); // 6 dirt: 4 + 6 = 10 units
    var b3 = Bundle.init(4, .purple); // 2 pearls: 4 + 8 = 12 units

    _ = b2.insertItem(1, 6, 64);
    _ = b3.insertItem(2, 2, 16);

    try outer.insertBundle(&b1);
    try outer.insertBundle(&b2);
    try outer.insertBundle(&b3);

    // 4 + 10 + 12 = 26 units
    try std.testing.expectEqual(@as(u8, 26), outer.totalWeight());
    try std.testing.expectEqual(@as(u8, 38), outer.remainingCapacity());
    try std.testing.expectEqual(@as(u8, 3), outer.entry_count);
}

test "9. Capacity limit: exactly 16 empty bundles fill a bundle to 64/64" {
    var outer = Bundle.init(1, .undyed);
    var pool = BundlePool(20).init();

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        const child = pool.create(@intCast(i + 10), .lime) orelse unreachable;
        try outer.insertBundle(child);
    }

    try std.testing.expectEqual(@as(u8, 16), outer.entry_count);
    try std.testing.expectEqual(@as(u8, 64), outer.totalWeight());
    try std.testing.expect(outer.isFull());
    try std.testing.expectEqual(@as(u8, 0), outer.remainingCapacity());
}

test "10. Capacity overflow: 17th empty bundle is rejected" {
    var outer = Bundle.init(1, .undyed);
    var pool = BundlePool(20).init();

    var i: usize = 0;
    while (i < 16) : (i += 1) {
        const child = pool.create(@intCast(i + 10), .pink) orelse unreachable;
        try outer.insertBundle(child);
    }

    // 17th empty bundle requires 4 units but remaining capacity is 0
    const extra = pool.create(99, .pink) orelse unreachable;
    try std.testing.expectError(BundleError.CapacityExceeded, outer.insertBundle(extra));
    try std.testing.expect(!outer.tryInsertBundle(extra));
    try std.testing.expectEqual(@as(u8, 16), outer.entry_count);
    try std.testing.expectEqual(@as(u8, 64), outer.totalWeight());
}

test "11. Capacity overflow: bundle with 61 contents cannot be nested in any bundle" {
    var outer = Bundle.init(1, .undyed);
    var heavy = Bundle.init(2, .black);

    // Fill heavy bundle with 61 dirt (weight 61)
    _ = heavy.insertItem(1, 61, 64);
    try std.testing.expectEqual(@as(u8, 61), heavy.totalWeight());

    // 4 baseline + 61 contents = 65 units > 64 MAX_BUNDLE_WEIGHT
    try std.testing.expect(heavy.nestedBundleWeight() >= 64);
    try std.testing.expect(!outer.canInsertBundle(&heavy));
    try std.testing.expectError(BundleError.CapacityExceeded, outer.insertBundle(&heavy));
}

test "12. Capacity overflow: partial item insertion when nearly full" {
    var bundle = Bundle.init(1, .undyed);
    _ = bundle.insertItem(1, 60, 64); // 60 weight
    try std.testing.expectEqual(@as(u8, 60), bundle.totalWeight());
    try std.testing.expectEqual(@as(u8, 4), bundle.remainingCapacity());

    // Attempting to insert 10 dirt accepts only 4
    const accepted_dirt = bundle.insertItem(2, 10, 64);
    try std.testing.expectEqual(@as(u8, 4), accepted_dirt);
    try std.testing.expectEqual(@as(u8, 64), bundle.totalWeight());
    try std.testing.expect(bundle.isFull());

    // Further insertions rejected
    try std.testing.expectEqual(@as(u8, 0), bundle.insertItem(3, 1, 64));
}

test "13. Self-containment rejection: bundle cannot be inserted into itself" {
    var bundle = Bundle.init(1, .undyed);
    try std.testing.expectError(BundleError.SelfContainment, bundle.insertBundle(&bundle));
    try std.testing.expect(!bundle.canInsertBundle(&bundle));
    try std.testing.expectEqual(@as(u8, 0), bundle.entry_count);
}

test "14. Recursive loop rejection: 2-node cycle (A -> B -> A)" {
    var a = Bundle.init(1, .undyed);
    var b = Bundle.init(2, .red);

    // a contains b
    try a.insertBundle(&b);
    try std.testing.expectEqual(b.parent, &a);

    // b attempting to insert a would form a cycle
    try std.testing.expectError(BundleError.RecursiveLoopDetected, b.insertBundle(&a));
    try std.testing.expect(!b.canInsertBundle(&a));
    try std.testing.expectEqual(@as(u8, 0), b.entry_count);
}

test "15. Recursive loop rejection: 3-node cycle (A -> B -> C -> A)" {
    var a = Bundle.init(1, .undyed);
    var b = Bundle.init(2, .blue);
    var c = Bundle.init(3, .green);

    try a.insertBundle(&b);
    try b.insertBundle(&c);

    // c attempting to insert a would form a 3-node cycle
    try std.testing.expectError(BundleError.RecursiveLoopDetected, c.insertBundle(&a));
    try std.testing.expect(!c.canInsertBundle(&a));
    try std.testing.expectEqual(@as(u8, 0), c.entry_count);
}

test "16. Already-nested bundle cannot be inserted into another bundle without prior extraction" {
    var parent1 = Bundle.init(1, .undyed);
    var parent2 = Bundle.init(2, .undyed);
    var child = Bundle.init(3, .yellow);

    try parent1.insertBundle(&child);
    try std.testing.expectEqual(child.parent, &parent1);

    // Attempting to insert child into parent2 while still inside parent1 fails
    try std.testing.expectError(BundleError.AlreadyNested, parent2.insertBundle(&child));
    try std.testing.expect(!parent2.canInsertBundle(&child));

    // Extract child from parent1: now parent is null and insertion into parent2 succeeds!
    const ext = parent1.extract().?;
    try std.testing.expect(ext.isBundle());
    try std.testing.expectEqual(child.parent, null);

    try parent2.insertBundle(&child);
    try std.testing.expectEqual(child.parent, &parent2);
}

test "17. BundleColor enum: 17 variants (undyed + 16 colors) and names" {
    try std.testing.expectEqual(@as(usize, 17), BundleColor.count);

    try std.testing.expectEqualStrings("Bundle", BundleColor.undyed.displayName());
    try std.testing.expectEqualStrings("White Bundle", BundleColor.white.displayName());
    try std.testing.expectEqualStrings("Orange Bundle", BundleColor.orange.displayName());
    try std.testing.expectEqualStrings("Magenta Bundle", BundleColor.magenta.displayName());
    try std.testing.expectEqualStrings("Light Blue Bundle", BundleColor.light_blue.displayName());
    try std.testing.expectEqualStrings("Yellow Bundle", BundleColor.yellow.displayName());
    try std.testing.expectEqualStrings("Lime Bundle", BundleColor.lime.displayName());
    try std.testing.expectEqualStrings("Pink Bundle", BundleColor.pink.displayName());
    try std.testing.expectEqualStrings("Gray Bundle", BundleColor.gray.displayName());
    try std.testing.expectEqualStrings("Light Gray Bundle", BundleColor.light_gray.displayName());
    try std.testing.expectEqualStrings("Cyan Bundle", BundleColor.cyan.displayName());
    try std.testing.expectEqualStrings("Purple Bundle", BundleColor.purple.displayName());
    try std.testing.expectEqualStrings("Blue Bundle", BundleColor.blue.displayName());
    try std.testing.expectEqualStrings("Brown Bundle", BundleColor.brown.displayName());
    try std.testing.expectEqualStrings("Green Bundle", BundleColor.green.displayName());
    try std.testing.expectEqualStrings("Red Bundle", BundleColor.red.displayName());
    try std.testing.expectEqualStrings("Black Bundle", BundleColor.black.displayName());
}

test "18. BundleColor rgbHex and toDyeColor/fromDyeColor conversion" {
    try std.testing.expect(!BundleColor.undyed.isDyed());
    try std.testing.expectEqual(@as(?DyeColor, null), BundleColor.undyed.toDyeColor());
    try std.testing.expectEqual(@as(u32, 0xC7935E), BundleColor.undyed.rgbHex());

    inline for (std.meta.tags(DyeColor)) |dye| {
        const bc = BundleColor.fromDyeColor(dye);
        try std.testing.expect(bc.isDyed());
        try std.testing.expectEqual(dye, bc.toDyeColor().?);
        try std.testing.expectEqual(dye.rgbHex(), bc.rgbHex());
    }
}

test "19. Crafting grid dyeing: 1 Bundle + 1 Dye preserves all items inside" {
    var bundle = Bundle.init(1, .undyed);
    _ = bundle.insertItem(10, 20, 64);
    _ = bundle.insertItem(20, 4, 16);

    const dyed = craftDyeBundle(&bundle, .red);
    try std.testing.expectEqual(BundleColor.red, dyed.color);
    try std.testing.expectEqualStrings("Red Bundle", dyed.displayName());
    try std.testing.expectEqual(@as(u8, 2), dyed.entry_count);
    try std.testing.expectEqual(@as(u8, 36), dyed.totalWeight()); // 20 + 16 = 36
    try std.testing.expectEqual(@as(u16, 10), dyed.entries[0].item.item_id);
    try std.testing.expectEqual(@as(u8, 20), dyed.entries[0].item.count);
    try std.testing.expectEqual(@as(u16, 20), dyed.entries[1].item.item_id);
    try std.testing.expectEqual(@as(u8, 4), dyed.entries[1].item.count);
}

test "20. Crafting grid dyeing: all 16 dye colors individually preserve contents" {
    var bundle = Bundle.init(1, .undyed);
    _ = bundle.insertItem(5, 12, 64);

    inline for (std.meta.tags(DyeColor)) |dye| {
        const dyed = craftBundleDye(&bundle, dye);
        try std.testing.expectEqual(BundleColor.fromDyeColor(dye), dyed.color);
        try std.testing.expectEqual(@as(u8, 12), dyed.totalWeight());
        try std.testing.expectEqual(@as(u8, 1), dyed.entry_count);
        try std.testing.expectEqual(@as(u16, 5), dyed.entries[0].item.item_id);
    }
}

test "21. Crafting grid dyeing: re-dyeing already-dyed bundle" {
    var bundle = Bundle.init(1, .white);
    _ = bundle.insertItem(1, 10, 64);

    // White Bundle + Blue Dye -> Blue Bundle
    const blue_bundle = craftDyeBundle(&bundle, .blue);
    try std.testing.expectEqual(BundleColor.blue, blue_bundle.color);
    try std.testing.expectEqualStrings("Blue Bundle", blue_bundle.displayName());
    try std.testing.expectEqual(@as(u8, 10), blue_bundle.totalWeight());

    // Blue Bundle + Yellow Dye -> Yellow Bundle
    const yellow_bundle = craftDyeBundle(&blue_bundle, .yellow);
    try std.testing.expectEqual(BundleColor.yellow, yellow_bundle.color);
    try std.testing.expectEqualStrings("Yellow Bundle", yellow_bundle.displayName());
    try std.testing.expectEqual(@as(u8, 10), yellow_bundle.totalWeight());
}

test "22. Crafting grid dyeing: invalid recipes rejected (multiple bundles, missing dye, extra items)" {
    const b1 = Bundle.init(1, .undyed);
    const b2 = Bundle.init(2, .undyed);

    // Valid: 1 Bundle + 1 Dye in a 2x2 grid
    const grid_valid = [_]CraftingGridSlot{
        .{ .bundle = b1 },
        .{ .dye = .purple },
        .empty,
        .empty,
    };
    const res_valid = craftDyeGrid(&grid_valid);
    try std.testing.expect(res_valid != null);
    try std.testing.expectEqual(BundleColor.purple, res_valid.?.color);

    // Invalid: 2 Bundles
    const grid_two_bundles = [_]CraftingGridSlot{
        .{ .bundle = b1 },
        .{ .bundle = b2 },
        .{ .dye = .purple },
        .empty,
    };
    try std.testing.expect(craftDyeGrid(&grid_two_bundles) == null);

    // Invalid: Missing Dye
    const grid_no_dye = [_]CraftingGridSlot{
        .{ .bundle = b1 },
        .empty,
        .empty,
        .empty,
    };
    try std.testing.expect(craftDyeGrid(&grid_no_dye) == null);

    // Invalid: Extra extraneous item (e.g. stick)
    const grid_extra_item = [_]CraftingGridSlot{
        .{ .bundle = b1 },
        .{ .dye = .purple },
        .{ .other = 999 },
        .empty,
    };
    try std.testing.expect(craftDyeGrid(&grid_extra_item) == null);
}

test "23. Cauldron washing: dyed bundle in water cauldron reverts to undyed and decrements water level" {
    var bundle = Bundle.init(1, .cyan);
    var cauldron = Cauldron.init(3);

    try std.testing.expect(cauldron.washBundle(&bundle));
    try std.testing.expectEqual(BundleColor.undyed, bundle.color);
    try std.testing.expectEqualStrings("Bundle", bundle.displayName());
    try std.testing.expectEqual(@as(u2, 2), cauldron.water_level);
}

test "24. Cauldron washing: sequential washing until cauldron reaches 0 water" {
    var b1 = Bundle.init(1, .red);
    var b2 = Bundle.init(2, .green);
    var b3 = Bundle.init(3, .blue);
    var b4 = Bundle.init(4, .yellow);
    var cauldron = Cauldron.init(3);

    // Wash 1: level 3 -> 2
    try std.testing.expect(cauldron.washBundle(&b1));
    try std.testing.expectEqual(BundleColor.undyed, b1.color);
    try std.testing.expectEqual(@as(u2, 2), cauldron.water_level);

    // Wash 2: level 2 -> 1
    try std.testing.expect(cauldron.washBundle(&b2));
    try std.testing.expectEqual(BundleColor.undyed, b2.color);
    try std.testing.expectEqual(@as(u2, 1), cauldron.water_level);

    // Wash 3: level 1 -> 0
    try std.testing.expect(cauldron.washBundle(&b3));
    try std.testing.expectEqual(BundleColor.undyed, b3.color);
    try std.testing.expectEqual(@as(u2, 0), cauldron.water_level);

    // Wash 4: fails because cauldron is empty (level 0)
    try std.testing.expect(!cauldron.washBundle(&b4));
    try std.testing.expectEqual(BundleColor.yellow, b4.color);
    try std.testing.expectEqual(@as(u2, 0), cauldron.water_level);
}

test "25. Cauldron washing: fails when cauldron water level is 0" {
    var bundle = Bundle.init(1, .magenta);
    var water_level: u2 = 0;

    try std.testing.expect(!washBundleInCauldron(&bundle, &water_level));
    try std.testing.expectEqual(BundleColor.magenta, bundle.color);
    try std.testing.expectEqual(@as(u2, 0), water_level);
}

test "26. Cauldron washing: fails when bundle is already undyed (no water consumed)" {
    var bundle = Bundle.init(1, .undyed);
    var water_level: u2 = 3;

    try std.testing.expect(!washBundleInCauldron(&bundle, &water_level));
    try std.testing.expectEqual(BundleColor.undyed, bundle.color);
    try std.testing.expectEqual(@as(u2, 3), water_level); // No water wasted!
}

test "27. Cauldron washing: preserves all contents and nested bundles inside" {
    var outer = Bundle.init(1, .orange);
    var inner = Bundle.init(2, .lime);
    _ = inner.insertItem(1, 10, 64);
    try outer.insertBundle(&inner);
    _ = outer.insertItem(2, 5, 16);

    var water_level: u2 = 3;
    try std.testing.expect(washBundleInCauldron(&outer, &water_level));

    // Outer is now undyed
    try std.testing.expectEqual(BundleColor.undyed, outer.color);
    try std.testing.expectEqual(@as(u2, 2), water_level);

    // Contents and inner bundle's lime color are completely preserved!
    try std.testing.expectEqual(@as(u8, 2), outer.entry_count);
    try std.testing.expectEqual(BundleColor.lime, inner.color);
    try std.testing.expectEqual(@as(u8, 10), inner.totalWeight());
    try std.testing.expectEqual(@as(u8, 34), outer.totalWeight()); // (4+10) + (5*4=20) = 34
}

test "28. Cauldron washing: integration with cauldron_fluids.CauldronState and rejection of lava/snow" {
    var bundle = Bundle.init(1, .purple);

    // 1. Water cauldron: succeeds and drains 1 level
    var water_state = cauldron_fluids.CauldronState.initWater(2);
    try std.testing.expect(bundle.wash(&water_state));
    try std.testing.expectEqual(BundleColor.undyed, bundle.color);
    try std.testing.expectEqual(@as(u2, 1), water_state.level);

    // 2. Lava cauldron: fails and preserves color
    var lava_bundle = Bundle.init(2, .red);
    var lava_state = cauldron_fluids.CauldronState.initLava();
    try std.testing.expect(!lava_bundle.wash(&lava_state));
    try std.testing.expectEqual(BundleColor.red, lava_bundle.color);
    try std.testing.expect(lava_state.isLava());

    // 3. Powder snow cauldron: fails and preserves color
    var snow_bundle = Bundle.init(3, .blue);
    var snow_state = cauldron_fluids.CauldronState.initPowderSnow(3);
    try std.testing.expect(!snow_bundle.wash(&snow_state));
    try std.testing.expectEqual(BundleColor.blue, snow_bundle.color);
    try std.testing.expect(snow_state.isPowderSnow());
}

test "29. Extraction & insertion: LIFO order extraction of items" {
    var bundle = Bundle.init(1, .undyed);
    _ = bundle.insertItem(10, 5, 64); // First inserted (bottom)
    _ = bundle.insertItem(20, 8, 64); // Second inserted
    _ = bundle.insertItem(30, 2, 64); // Third inserted (top)

    // LIFO pop 1: top item (id 30)
    const ext1 = bundle.extract().?;
    try std.testing.expect(ext1.isItem());
    try std.testing.expectEqual(@as(u16, 30), ext1.asItem().?.item_id);
    try std.testing.expectEqual(@as(u8, 2), ext1.asItem().?.count);

    // LIFO pop 2: middle item (id 20)
    const ext2 = bundle.extract().?;
    try std.testing.expectEqual(@as(u16, 20), ext2.asItem().?.item_id);
    try std.testing.expectEqual(@as(u8, 8), ext2.asItem().?.count);

    // LIFO pop 3: bottom item (id 10)
    const ext3 = bundle.extract().?;
    try std.testing.expectEqual(@as(u16, 10), ext3.asItem().?.item_id);
    try std.testing.expectEqual(@as(u8, 5), ext3.asItem().?.count);

    // Bundle now empty
    try std.testing.expect(bundle.extract() == null);
    try std.testing.expect(bundle.isEmpty());
}

test "30. Extraction & insertion: LIFO order extraction of nested bundles and regular items mixed" {
    var outer = Bundle.init(1, .undyed);
    var inner = Bundle.init(2, .red);
    _ = inner.insertItem(100, 1, 16);

    _ = outer.insertItem(1, 15, 64);   // Slot 0
    try outer.insertBundle(&inner);     // Slot 1
    _ = outer.insertItem(2, 5, 64);    // Slot 2 (top)

    // Pop 1: id 2
    const p1 = outer.extract().?;
    try std.testing.expect(p1.isItem());
    try std.testing.expectEqual(@as(u16, 2), p1.asItem().?.item_id);

    // Pop 2: inner bundle
    const p2 = outer.extract().?;
    try std.testing.expect(p2.isBundle());
    try std.testing.expectEqual(&inner, p2.asBundle().?);
    try std.testing.expectEqual(BundleColor.red, p2.asBundle().?.color);

    // Pop 3: id 1
    const p3 = outer.extract().?;
    try std.testing.expect(p3.isItem());
    try std.testing.expectEqual(@as(u16, 1), p3.asItem().?.item_id);

    try std.testing.expect(outer.isEmpty());
}

test "31. Extraction & insertion: extraction clears parent reference on extracted bundle" {
    var outer = Bundle.init(1, .undyed);
    var inner = Bundle.init(2, .white);

    try outer.insertBundle(&inner);
    try std.testing.expectEqual(inner.parent, &outer);

    const ext = outer.extract().?;
    const child = ext.asBundle().?;
    try std.testing.expectEqual(child.parent, null);
    try std.testing.expectEqual(inner.parent, null);
}

test "32. Extraction & insertion: extract with scroll selection" {
    var bundle = Bundle.init(1, .undyed);
    _ = bundle.insertItem(10, 5, 64); // idx 0
    _ = bundle.insertItem(20, 8, 64); // idx 1
    _ = bundle.insertItem(30, 2, 64); // idx 2

    // Select idx 1 (item 20)
    bundle.setSelection(1);
    try std.testing.expectEqual(@as(?u8, 1), bundle.selected_index);

    const ext = bundle.extract().?;
    try std.testing.expectEqual(@as(u16, 20), ext.asItem().?.item_id);
    try std.testing.expectEqual(@as(u8, 2), bundle.entry_count);
}

test "33. Scroll selection cycling and wrapping" {
    var bundle = Bundle.init(1, .undyed);
    _ = bundle.insertItem(10, 1, 64);
    _ = bundle.insertItem(20, 1, 64);
    _ = bundle.insertItem(30, 1, 64);

    // Initially null
    try std.testing.expectEqual(@as(?u8, null), bundle.selected_index);

    // Scroll +1 from unselected starts at end (2) + 1 = 0 (wrap)
    bundle.scroll(1);
    try std.testing.expectEqual(@as(?u8, 0), bundle.selected_index);

    bundle.scroll(1);
    try std.testing.expectEqual(@as(?u8, 1), bundle.selected_index);

    bundle.scroll(1);
    try std.testing.expectEqual(@as(?u8, 2), bundle.selected_index);

    bundle.scroll(1); // wrap around to 0
    try std.testing.expectEqual(@as(?u8, 0), bundle.selected_index);

    bundle.scroll(-1); // wrap backwards to 2
    try std.testing.expectEqual(@as(?u8, 2), bundle.selected_index);
}

test "34. Full bundle dumping: dumpAll empties bundle and resets parent references" {
    var outer = Bundle.init(1, .undyed);
    var inner = Bundle.init(2, .green);
    _ = outer.insertItem(1, 10, 64);
    try outer.insertBundle(&inner);
    _ = outer.insertItem(2, 5, 64);

    var out_buf: [4]ExtractedEntry = undefined;
    const dumped = outer.dumpAll(&out_buf);

    try std.testing.expectEqual(@as(usize, 3), dumped);
    try std.testing.expect(outer.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), outer.totalWeight());

    // Verified LIFO order in dumped output:
    // Slot 0 of dump: id 2
    try std.testing.expect(out_buf[0].isItem());
    try std.testing.expectEqual(@as(u16, 2), out_buf[0].asItem().?.item_id);

    // Slot 1 of dump: inner bundle, with parent reset to null
    try std.testing.expect(out_buf[1].isBundle());
    try std.testing.expectEqual(&inner, out_buf[1].asBundle().?);
    try std.testing.expectEqual(inner.parent, null);

    // Slot 2 of dump: id 1
    try std.testing.expect(out_buf[2].isItem());
    try std.testing.expectEqual(@as(u16, 1), out_buf[2].asItem().?.item_id);
}

test "35. Full bundle dumping: dumpAll on empty bundle returns 0" {
    var bundle = Bundle.init(1, .undyed);
    var out_buf: [4]ExtractedEntry = undefined;
    try std.testing.expectEqual(@as(usize, 0), bundle.dumpAll(&out_buf));
}

test "36. Redstone comparator signal: empty bundle outputs 0, full outputs 15" {
    var bundle = Bundle.init(1, .undyed);
    try std.testing.expectEqual(@as(u4, 0), bundle.comparatorSignal());

    _ = bundle.insertItem(1, 64, 64); // Full 64 weight
    try std.testing.expectEqual(@as(u4, 15), bundle.comparatorSignal());
}

test "37. Redstone comparator signal: exact formula curve verification across various weights" {
    // signal = ceil((weight / 64.0) * 15.0)
    try std.testing.expectEqual(@as(u4, 0), comparatorSignal(0));
    try std.testing.expectEqual(@as(u4, 1), comparatorSignal(1));   // ceil(0.234) = 1
    try std.testing.expectEqual(@as(u4, 1), comparatorSignal(4));   // ceil(0.9375) = 1
    try std.testing.expectEqual(@as(u4, 2), comparatorSignal(5));   // ceil(1.171875) = 2
    try std.testing.expectEqual(@as(u4, 2), comparatorSignal(8));   // ceil(1.875) = 2
    try std.testing.expectEqual(@as(u4, 3), comparatorSignal(9));   // ceil(2.109375) = 3
    try std.testing.expectEqual(@as(u4, 8), comparatorSignal(32));  // ceil(7.5) = 8
    try std.testing.expectEqual(@as(u4, 15), comparatorSignal(60)); // ceil(14.0625) = 15
    try std.testing.expectEqual(@as(u4, 15), comparatorSignal(64)); // ceil(15.0) = 15
}

test "38. BundlePool: creation, nesting, and release without memory leaks" {
    var pool = BundlePool(8).init();
    try std.testing.expectEqual(@as(usize, 0), pool.active_count);

    const b1 = pool.create(1, .blue) orelse unreachable;
    const b2 = pool.create(2, .yellow) orelse unreachable;
    try std.testing.expectEqual(@as(usize, 2), pool.active_count);

    _ = b2.insertItem(1, 10, 64);
    try b1.insertBundle(b2);

    try std.testing.expectEqual(@as(u8, 14), b1.totalWeight()); // 4 base + 10 contents

    // Extraction and release
    const ext = b1.extract().?;
    const popped = ext.asBundle().?;
    pool.release(popped);
    try std.testing.expectEqual(@as(usize, 1), pool.active_count);

    pool.release(b1);
    try std.testing.expectEqual(@as(usize, 0), pool.active_count);
}
