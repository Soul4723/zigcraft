//! ============================================================================
//! Unified Bundle Storage, Nesting & Color Dyeing (16 Dye Variants)
//! ============================================================================

const std = @import("std");
const cauldron_fluids = @import("cauldron_fluids.zig");

// ============================================================================
// Constants & Weight Rules
// ============================================================================

/// Standard item ID for an undyed Bundle pouch.
pub const BUNDLE_ITEM_ID: u16 = 371;
pub const BUNDLE_ITEM_TAG: u16 = BUNDLE_ITEM_ID;

/// Total weight capacity of a bundle pouch (64 weight units).
pub const TOTAL_BUNDLE_CAPACITY: u8 = 64;
pub const MAX_BUNDLE_WEIGHT: u8 = TOTAL_BUNDLE_CAPACITY;

/// Baseline weight occupied by an empty bundle when nested inside another bundle.
pub const EMPTY_BUNDLE_BASE_WEIGHT: u8 = 4;

/// Maximum number of distinct item entries inside a standard bundle pouch (16 slots).
pub const MAX_BUNDLE_ENTRIES: usize = 16;

/// Maximum distinct item/bundle entries inside a single nested bundle (64 slots).
pub const MAX_NESTED_BUNDLE_ENTRIES: usize = 64;

/// Maximum nesting depth allowed to protect against deep recursion.
pub const MAX_NESTING_DEPTH: usize = 16;

/// Weight unit calculation rules for Bundle items.
pub const BundleWeight = struct {
    pub const max_capacity: u8 = TOTAL_BUNDLE_CAPACITY;
    pub const empty_bundle_weight: u8 = EMPTY_BUNDLE_BASE_WEIGHT;

    /// Calculate the weight unit per item based on max_stack size:
    /// - 64-stack item = 1 weight unit
    /// - 16-stack item = 4 weight units (e.g. ender pearls, eggs, snowballs)
    /// - 1-stack item  = 64 weight units (unstackable tool/armor)
    /// - other stack sizes = 64 / max_stack (or 0 if max_stack == 0)
    pub fn perItem(max_stack: u8) u8 {
        if (max_stack == 0) return 0;
        return switch (max_stack) {
            1 => 64,
            16 => 4,
            64 => 1,
            else => @divTrunc(@as(u8, 64), max_stack),
        };
    }

    /// Weight unit of an item given its ID and max_stack.
    /// Special case: nested empty bundle item occupies 4 weight units.
    pub fn perItemForId(item_id: u16, max_stack: u8) u8 {
        if (item_id == BUNDLE_ITEM_ID) {
            return empty_bundle_weight;
        }
        return perItem(max_stack);
    }

    /// Weight unit alias matching perItem.
    pub fn itemWeight(max_stack: u8) u8 {
        return perItem(max_stack);
    }

    /// Weight of an empty bundle (4 weight units).
    pub fn emptyBundle() u8 {
        return empty_bundle_weight;
    }

    /// Total weight for `count` items with max_stack.
    pub fn total(max_stack: u8, count: u8) u16 {
        return @as(u16, perItem(max_stack)) * @as(u16, count);
    }

    /// Total weight for `count` items with item_id and max_stack.
    pub fn totalForId(item_id: u16, max_stack: u8, count: u8) u16 {
        return @as(u16, perItemForId(item_id, max_stack)) * @as(u16, count);
    }
};

/// Calculates the weight unit per item based on max_stack size:
/// - 64-stack item = 1 weight unit (e.g. 64 dirt = 64 units)
/// - 16-stack item = 4 weight units (e.g. 1 ender pearl = 4 units, max 16 = 64 units)
/// - 1-stack item  = 64 weight units (e.g. 1 sword = 64 units)
/// - other stack sizes = @divTrunc(64, max_stack) (or 0 if max_stack == 0)
pub fn itemWeight(max_stack: u8) u8 {
    return BundleWeight.perItem(max_stack);
}

/// Total weight for `count` items with `max_stack`.
pub fn stackWeight(max_stack: u8, count: u8) u16 {
    return BundleWeight.total(max_stack, count);
}

/// Computes the redstone comparator output signal for a given current weight:
/// signal = @as(u4, @intFromFloat(@ceil((current_weight / 64.0) * 15.0)))
/// Outputs 0 when empty, 1..15 when holding items.
pub fn comparatorSignalForWeight(current_weight: u8) u4 {
    if (current_weight == 0) return 0;
    const numerator = @as(u16, current_weight) * 15 + 63;
    const sig = numerator / 64;
    return @intCast(@min(15, sig));
}

/// Computes comparator signal for a BundlePouch, Bundle, or direct weight integer.
pub fn comparatorSignal(arg: anytype) u4 {
    const T = @TypeOf(arg);
    if (T == BundlePouch) {
        return comparatorSignalForWeight(arg.total_weight);
    } else if (T == Bundle or T == *const Bundle or T == *Bundle) {
        return comparatorSignalForWeight(arg.totalWeight());
    } else {
        return comparatorSignalForWeight(@intCast(arg));
    }
}

/// Public alias for bundle comparator signal calculation.
pub const bundleComparatorSignal = comparatorSignal;

// ============================================================================
// Dye Color & Bundle Color Definitions
// ============================================================================

/// 16 Minecraft dye colors.
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

/// Undyed default sentinel constant (null).
pub const undyed_default: ?u4 = null;
pub const UNDYED: ?u4 = null;

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

/// A single distinct item entry inside a standard bundle pouch.
pub const BundleEntry = struct {
    item_id: u16 = 0,
    count: u8 = 0,
    max_stack: u8 = 64,

    /// Weight unit occupied by this entry.
    pub fn weight(self: BundleEntry) u8 {
        if (self.item_id == 0 or self.count == 0) return 0;
        const unit = BundleWeight.perItemForId(self.item_id, self.max_stack);
        const w = @as(u16, unit) * @as(u16, self.count);
        return @intCast(@min(TOTAL_BUNDLE_CAPACITY, w));
    }

    pub fn isEmpty(self: BundleEntry) bool {
        return self.item_id == 0 or self.count == 0;
    }
};

/// Result of extracting an item stack from a bundle pouch.
pub const ExtractedItem = struct {
    item_id: u16,
    count: u8,
};

/// Represents a regular item stack stored in a nested bundle.
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

/// A single entry in a nested bundle, either an item stack or a nested bundle reference.
pub const NestedBundleEntry = struct {
    kind: EntryKind = .empty,
    item: StoredItem = .{},
    nested_bundle: ?*Bundle = null,

    /// Weight unit occupied by this entry.
    /// For nested bundles: 4 baseline units + nested bundle contents weight.
    pub fn weight(self: NestedBundleEntry) u8 {
        return switch (self.kind) {
            .empty => 0,
            .item => self.item.weight(),
            .bundle => if (self.nested_bundle) |b| EMPTY_BUNDLE_BASE_WEIGHT + b.totalWeight() else 0,
        };
    }

    pub fn isEmpty(self: NestedBundleEntry) bool {
        return self.kind == .empty;
    }
};

/// Item or Bundle returned from LIFO extraction or full dumping in a nested bundle.
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
// BundlePouch Structure (Flat Mixed Inventory Container)
// ============================================================================

/// A bundle pouch container tracking mixed item entries, weight, scroll selection, and dye color.
pub const BundlePouch = struct {
    entries: [MAX_BUNDLE_ENTRIES]BundleEntry = [_]BundleEntry{.{}} ** MAX_BUNDLE_ENTRIES,
    entry_count: u5 = 0,
    total_weight: u8 = 0,
    selected_index: ?u4 = null,
    dye_color: ?u4 = null,

    pub const max_entries: usize = MAX_BUNDLE_ENTRIES;
    pub const max_capacity: u8 = TOTAL_BUNDLE_CAPACITY;

    pub fn isFull(self: BundlePouch) bool {
        return self.total_weight >= max_capacity;
    }

    pub fn isEmpty(self: BundlePouch) bool {
        return self.total_weight == 0 or self.entry_count == 0;
    }

    pub fn fullnessBarRatio(self: BundlePouch) f32 {
        return @as(f32, @floatFromInt(self.total_weight)) / @as(f32, @floatFromInt(max_capacity));
    }

    pub fn remainingCapacity(self: BundlePouch) u8 {
        if (self.total_weight >= max_capacity) return 0;
        return max_capacity - self.total_weight;
    }

    pub fn insert(self: *BundlePouch, item_id: u16, count: u8, max_stack: u8) u8 {
        return insertIntoBundle(self, item_id, count, max_stack);
    }

    pub fn extract(self: *BundlePouch) ?ExtractedItem {
        return extractSelectedOrTop(self);
    }

    pub fn dumpAll(self: *BundlePouch, out_buf: []BundleEntry) usize {
        return emptyAll(self, out_buf);
    }

    pub fn setSelection(self: *BundlePouch, index: ?u4) void {
        selectIndex(self, index);
    }

    pub fn scroll(self: *BundlePouch, delta: i8) void {
        scrollSelection(self, delta);
    }

    pub fn setDye(self: *BundlePouch, color: ?u4) void {
        self.dye_color = color;
    }

    pub fn isDyed(self: BundlePouch) bool {
        return self.dye_color != null;
    }

    pub fn undye(self: *BundlePouch) bool {
        if (self.dye_color == null) return false;
        self.dye_color = null;
        return true;
    }

    pub fn getDye(self: BundlePouch) ?u4 {
        return self.dye_color;
    }

    pub fn getColor(self: BundlePouch) BundleColor {
        if (self.dye_color) |col| {
            return BundleColor.fromDyeColor(@enumFromInt(col));
        }
        return .undyed;
    }

    pub fn setColor(self: *BundlePouch, color: BundleColor) void {
        if (color.toDyeColor()) |d| {
            self.dye_color = @intFromEnum(d);
        } else {
            self.dye_color = null;
        }
    }

    pub fn displayName(self: BundlePouch) []const u8 {
        return bundleDisplayName(self);
    }

    pub fn recalculateWeight(self: *BundlePouch) void {
        recomputeWeight(self);
    }

    pub fn comparatorSignal(self: BundlePouch) u4 {
        return comparatorSignalForWeight(self.total_weight);
    }

    pub fn wash(self: *BundlePouch, cauldron_target: anytype) bool {
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
// Bundle Structure (Recursive Multi-Bundle Nesting Container)
// ============================================================================

pub const Bundle = struct {
    id: u32 = 0,
    color: BundleColor = .undyed,
    entries: [MAX_NESTED_BUNDLE_ENTRIES]NestedBundleEntry = [_]NestedBundleEntry{.{}} ** MAX_NESTED_BUNDLE_ENTRIES,
    entry_count: u8 = 0,
    parent: ?*Bundle = null,
    selected_index: ?u8 = null,

    pub const max_capacity: u8 = TOTAL_BUNDLE_CAPACITY;
    pub const base_nested_weight: u8 = EMPTY_BUNDLE_BASE_WEIGHT;
    pub const max_entries: usize = MAX_NESTED_BUNDLE_ENTRIES;
    pub const Entry = NestedBundleEntry;

    pub fn init(id: u32, color: BundleColor) Bundle {
        return .{
            .id = id,
            .color = color,
            .entries = [_]NestedBundleEntry{.{}} ** MAX_NESTED_BUNDLE_ENTRIES,
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
        while (to_insert > 0 and self.entry_count < MAX_NESTED_BUNDLE_ENTRIES) {
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
        if (self.entry_count >= MAX_NESTED_BUNDLE_ENTRIES) return false;

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
        if (self.entry_count >= MAX_NESTED_BUNDLE_ENTRIES) {
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

    pub fn applyDye(self: *Bundle, dye: DyeColor) void {
        self.color = BundleColor.fromDyeColor(dye);
    }

    pub fn undye(self: *Bundle) bool {
        if (self.color == .undyed) return false;
        self.color = .undyed;
        return true;
    }

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
pub const craftBundleDye = craftDyeBundle;

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

    pub fn washBundle(self: *Cauldron, bundle: anytype) bool {
        if (!self.is_water or self.water_level == 0) return false;
        const PtrType = @TypeOf(bundle);
        if (PtrType == *Bundle) {
            if (!bundle.color.isDyed()) return false;
            bundle.color = .undyed;
            self.water_level -= 1;
            return true;
        } else if (PtrType == *BundlePouch) {
            if (!bundle.isDyed()) return false;
            _ = bundle.undye();
            self.water_level -= 1;
            return true;
        } else {
            @compileError("Unsupported bundle type for Cauldron.washBundle");
        }
    }
};

/// Washes a dyed bundle in a water cauldron represented by a `*u2` water level.
/// If dyed and water_level > 0: reverts to undyed and decrements water level by 1.
/// Returns true on success, false if empty or already undyed.
pub fn washBundleInCauldron(bundle: anytype, water_level: *u2) bool {
    if (water_level.* == 0) return false;
    const PtrType = @TypeOf(bundle);
    if (PtrType == *Bundle) {
        if (!bundle.color.isDyed()) return false;
        bundle.color = .undyed;
        water_level.* -= 1;
        return true;
    } else if (PtrType == *BundlePouch) {
        if (!bundle.isDyed()) return false;
        _ = bundle.undye();
        water_level.* -= 1;
        return true;
    } else {
        @compileError("Unsupported bundle type for washBundleInCauldron");
    }
}

/// Washes a dyed bundle in a `CauldronState` from `cauldron_fluids.zig`.
pub fn washBundleInCauldronState(bundle: anytype, state: *cauldron_fluids.CauldronState) bool {
    if (!state.isWater() or state.level == 0) return false;
    const PtrType = @TypeOf(bundle);
    if (PtrType == *Bundle) {
        if (!bundle.color.isDyed()) return false;
        bundle.color = .undyed;
        state.level -= 1;
        if (state.level == 0) {
            state.content = .empty;
        }
        return true;
    } else if (PtrType == *BundlePouch) {
        if (!bundle.isDyed()) return false;
        _ = bundle.undye();
        state.level -= 1;
        if (state.level == 0) {
            state.content = .empty;
        }
        return true;
    } else {
        @compileError("Unsupported bundle type for washBundleInCauldronState");
    }
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
// Standalone Functions for BundlePouch
// ============================================================================

/// Inserts as many items as fit within remaining `64 - current_weight` capacity,
/// merging with existing matching stack or creating a new entry, returning number of items accepted.
pub fn insertIntoBundle(bundle: *BundlePouch, item_id: u16, count: u8, max_stack: u8) u8 {
    if (item_id == 0 or count == 0 or max_stack == 0) return 0;
    if (bundle.total_weight >= MAX_BUNDLE_WEIGHT) return 0;

    const unit_weight = BundleWeight.perItemForId(item_id, max_stack);
    if (unit_weight == 0) return 0;

    const remaining_weight: u8 = MAX_BUNDLE_WEIGHT - bundle.total_weight;
    const max_items_by_weight: u8 = remaining_weight / unit_weight;
    if (max_items_by_weight == 0) return 0;

    var to_insert: u8 = @min(count, max_items_by_weight);
    var accepted: u8 = 0;

    // 1. Try to merge into existing matching entries
    var i: usize = 0;
    while (i < bundle.entry_count and to_insert > 0) : (i += 1) {
        const entry = &bundle.entries[i];
        if (entry.item_id == item_id and entry.max_stack == max_stack and entry.count < entry.max_stack) {
            const space: u8 = entry.max_stack - entry.count;
            const added: u8 = @min(to_insert, space);
            entry.count += added;
            to_insert -= added;
            accepted += added;
        }
    }

    // 2. Add into new entry slots if space remains
    while (to_insert > 0 and bundle.entry_count < MAX_BUNDLE_ENTRIES) {
        const added: u8 = @min(to_insert, max_stack);
        bundle.entries[bundle.entry_count] = .{
            .item_id = item_id,
            .count = added,
            .max_stack = max_stack,
        };
        bundle.entry_count += 1;
        to_insert -= added;
        accepted += added;
    }

    bundle.total_weight += @intCast(@as(u16, accepted) * @as(u16, unit_weight));
    return accepted;
}

/// Removes the scrolled-to item stack (or last-inserted top stack when `selected_index == null`).
pub fn extractSelectedOrTop(bundle: *BundlePouch) ?ExtractedItem {
    if (bundle.entry_count == 0) return null;

    const target_idx: usize = if (bundle.selected_index) |idx|
        if (idx < bundle.entry_count) idx else bundle.entry_count - 1
    else
        bundle.entry_count - 1;

    const entry = bundle.entries[target_idx];
    if (entry.item_id == 0 or entry.count == 0) return null;

    const unit_weight = BundleWeight.perItemForId(entry.item_id, entry.max_stack);
    const weight_freed: u16 = @as(u16, unit_weight) * @as(u16, entry.count);
    if (bundle.total_weight >= weight_freed) {
        bundle.total_weight -= @intCast(weight_freed);
    } else {
        bundle.total_weight = 0;
    }

    // Compact remaining entries to maintain contiguous array
    var j: usize = target_idx;
    while (j + 1 < bundle.entry_count) : (j += 1) {
        bundle.entries[j] = bundle.entries[j + 1];
    }
    bundle.entries[bundle.entry_count - 1] = .{};
    bundle.entry_count -= 1;

    // Adjust selected_index
    if (bundle.entry_count == 0) {
        bundle.selected_index = null;
    } else if (bundle.selected_index) |sel| {
        if (sel >= bundle.entry_count) {
            bundle.selected_index = @intCast(bundle.entry_count - 1);
        }
    }

    return .{
        .item_id = entry.item_id,
        .count = entry.count,
    };
}

/// Dumps all contents into out_buf (world/inventory). Returns number of entries dumped.
pub fn emptyAll(bundle: *BundlePouch, out_buf: []BundleEntry) usize {
    if (bundle.entry_count == 0 or out_buf.len == 0) return 0;

    const to_dump: usize = @min(@as(usize, bundle.entry_count), out_buf.len);
    var i: usize = 0;
    while (i < to_dump) : (i += 1) {
        out_buf[i] = bundle.entries[i];
    }

    if (to_dump == bundle.entry_count) {
        // Complete dump
        bundle.entries = [_]BundleEntry{.{}} ** MAX_BUNDLE_ENTRIES;
        bundle.entry_count = 0;
        bundle.total_weight = 0;
        bundle.selected_index = null;
    } else {
        // Partial dump into smaller buffer
        var freed_weight: u16 = 0;
        var d: usize = 0;
        while (d < to_dump) : (d += 1) {
            const e = out_buf[d];
            const u = BundleWeight.perItemForId(e.item_id, e.max_stack);
            freed_weight += @as(u16, u) * @as(u16, e.count);
        }
        if (bundle.total_weight >= freed_weight) {
            bundle.total_weight -= @intCast(freed_weight);
        } else {
            bundle.total_weight = 0;
        }

        var rem: usize = 0;
        while (rem < bundle.entry_count - to_dump) : (rem += 1) {
            bundle.entries[rem] = bundle.entries[rem + to_dump];
        }
        var cl: usize = bundle.entry_count - to_dump;
        while (cl < MAX_BUNDLE_ENTRIES) : (cl += 1) {
            bundle.entries[cl] = .{};
        }
        bundle.entry_count -= @intCast(to_dump);
        if (bundle.selected_index) |sel| {
            if (bundle.entry_count == 0) {
                bundle.selected_index = null;
            } else if (sel >= to_dump) {
                bundle.selected_index = @intCast(sel - to_dump);
            } else {
                bundle.selected_index = @intCast(@min(bundle.entry_count - 1, sel));
            }
        }
    }

    return to_dump;
}

/// Ratio of bundle weight fullness (0.0 when empty, 1.0 when full at 64 weight).
pub fn fullnessBarRatio(bundle: BundlePouch) f32 {
    return @as(f32, @floatFromInt(bundle.total_weight)) / @as(f32, @floatFromInt(MAX_BUNDLE_WEIGHT));
}

/// Returns true when the bundle reaches or exceeds its max weight capacity of 64.
pub fn isFull(bundle: BundlePouch) bool {
    return bundle.total_weight >= MAX_BUNDLE_WEIGHT;
}

/// Returns true when the bundle contains no items.
pub fn isEmpty(bundle: BundlePouch) bool {
    return bundle.total_weight == 0 or bundle.entry_count == 0;
}

/// Sets or clears the active scroll selection index in the bundle tooltip.
pub fn selectIndex(bundle: *BundlePouch, index: ?u4) void {
    if (index) |idx| {
        if (idx < bundle.entry_count) {
            bundle.selected_index = idx;
        } else if (bundle.entry_count > 0) {
            bundle.selected_index = @intCast(bundle.entry_count - 1);
        } else {
            bundle.selected_index = null;
        }
    } else {
        bundle.selected_index = null;
    }
}

/// Handles mouse wheel scrolling across bundle items (+1 or -1).
/// Wraps cyclically through the active entries [0 .. entry_count - 1].
pub fn scrollSelection(bundle: *BundlePouch, delta: i8) void {
    if (bundle.entry_count == 0) {
        bundle.selected_index = null;
        return;
    }
    const count: i16 = @intCast(bundle.entry_count);
    const current: i16 = if (bundle.selected_index) |idx| @intCast(idx) else count - 1;
    var next = @mod(current + delta, count);
    if (next < 0) next += count;
    bundle.selected_index = @intCast(next);
}

/// Applies one of the 16 dye colors to a bundle pouch.
pub fn dyeBundle(bundle: *BundlePouch, color: u4) void {
    bundle.dye_color = color;
}

/// Reverts a bundle pouch to its undyed default state.
pub fn undyeBundle(bundle: *BundlePouch) void {
    bundle.dye_color = null;
}

/// Computes human-readable display name for the bundle ("Bundle" or "<Color> Bundle").
pub fn bundleDisplayName(bundle: BundlePouch) []const u8 {
    if (bundle.dye_color) |col| {
        const dye_enum: DyeColor = @enumFromInt(col);
        return switch (dye_enum) {
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
    return "Bundle";
}

/// Recomputes the exact total weight by summing all active entries.
pub fn recomputeWeight(bundle: *BundlePouch) void {
    var sum: u16 = 0;
    var i: usize = 0;
    while (i < bundle.entry_count) : (i += 1) {
        sum += bundle.entries[i].weight();
    }
    bundle.total_weight = @intCast(@min(MAX_BUNDLE_WEIGHT, sum));
}

// ============================================================================
// UNIT TESTS (BundlePouch - 27 Tests)
// ============================================================================

test "bundle_pouch: 1. BundleWeight calculations for standard stack sizes" {
    try std.testing.expectEqual(@as(u8, 1), BundleWeight.perItem(64));
    try std.testing.expectEqual(@as(u8, 4), BundleWeight.perItem(16));
    try std.testing.expectEqual(@as(u8, 64), BundleWeight.perItem(1));
    try std.testing.expectEqual(@as(u8, 4), BundleWeight.emptyBundle());
    try std.testing.expectEqual(@as(u8, 4), BundleWeight.perItemForId(BUNDLE_ITEM_ID, 1));

    try std.testing.expectEqual(@as(u16, 64), BundleWeight.total(64, 64));
    try std.testing.expectEqual(@as(u16, 64), BundleWeight.total(16, 16));
    try std.testing.expectEqual(@as(u16, 64), BundleWeight.total(1, 1));
}

test "bundle_pouch: 2. BundleWeight edge cases and arbitrary stack sizes" {
    try std.testing.expectEqual(@as(u8, 0), BundleWeight.perItem(0));
    try std.testing.expectEqual(@as(u8, 2), BundleWeight.perItem(32));
    try std.testing.expectEqual(@as(u8, 8), BundleWeight.perItem(8));
    try std.testing.expectEqual(@as(u8, 16), BundleWeight.perItem(4));
    try std.testing.expectEqual(@as(u8, 32), BundleWeight.perItem(2));
}

test "bundle_pouch: 3. BundlePouch default initialization" {
    const pouch = BundlePouch{};
    try std.testing.expectEqual(@as(u5, 0), pouch.entry_count);
    try std.testing.expectEqual(@as(u8, 0), pouch.total_weight);
    try std.testing.expectEqual(@as(?u4, null), pouch.selected_index);
    try std.testing.expectEqual(@as(?u4, null), pouch.dye_color);
    try std.testing.expect(pouch.isEmpty());
    try std.testing.expect(!pouch.isFull());
    try std.testing.expectEqual(@as(f32, 0.0), pouch.fullnessBarRatio());
    try std.testing.expectEqual(@as(u8, 64), pouch.remainingCapacity());
    try std.testing.expectEqualStrings("Bundle", pouch.displayName());
}

test "bundle_pouch: 4. Insert 64-stack item increments weight by 1 per item" {
    var pouch = BundlePouch{};
    const inserted1 = insertIntoBundle(&pouch, 10, 15, 64);
    try std.testing.expectEqual(@as(u8, 15), inserted1);
    try std.testing.expectEqual(@as(u8, 15), pouch.total_weight);
    try std.testing.expectEqual(@as(u5, 1), pouch.entry_count);
    try std.testing.expectEqual(@as(u8, 15), pouch.entries[0].count);

    const inserted2 = insertIntoBundle(&pouch, 10, 20, 64);
    try std.testing.expectEqual(@as(u8, 20), inserted2);
    try std.testing.expectEqual(@as(u8, 35), pouch.total_weight);
    try std.testing.expectEqual(@as(u5, 1), pouch.entry_count);
    try std.testing.expectEqual(@as(u8, 35), pouch.entries[0].count);
}

test "bundle_pouch: 5. Insert 16-stack item increments weight by 4 per item" {
    var pouch = BundlePouch{};
    // Ender pearls (max_stack = 16): 5 items * 4 = 20 weight
    const inserted = insertIntoBundle(&pouch, 20, 5, 16);
    try std.testing.expectEqual(@as(u8, 5), inserted);
    try std.testing.expectEqual(@as(u8, 20), pouch.total_weight);
    try std.testing.expectEqual(@as(u5, 1), pouch.entry_count);

    // Insert 5 more: 10 items * 4 = 40 weight
    const inserted2 = insertIntoBundle(&pouch, 20, 5, 16);
    try std.testing.expectEqual(@as(u8, 5), inserted2);
    try std.testing.expectEqual(@as(u8, 40), pouch.total_weight);
    try std.testing.expectEqual(@as(u8, 10), pouch.entries[0].count);
}

test "bundle_pouch: 6. Unstackable 1-stack item fills entire 64/64 weight" {
    var pouch = BundlePouch{};
    // Diamond sword (max_stack = 1): 1 item * 64 = 64 weight
    const inserted = insertIntoBundle(&pouch, 100, 1, 1);
    try std.testing.expectEqual(@as(u8, 1), inserted);
    try std.testing.expectEqual(@as(u8, 64), pouch.total_weight);
    try std.testing.expect(pouch.isFull());
    try std.testing.expectEqual(@as(f32, 1.0), pouch.fullnessBarRatio());
    try std.testing.expectEqual(@as(u8, 0), pouch.remainingCapacity());

    // Subsequent insertions are rejected
    try std.testing.expectEqual(@as(u8, 0), insertIntoBundle(&pouch, 10, 1, 64));
    try std.testing.expectEqual(@as(u8, 0), insertIntoBundle(&pouch, 20, 1, 16));
    try std.testing.expectEqual(@as(u8, 0), insertIntoBundle(&pouch, 101, 1, 1));
}

test "bundle_pouch: 7. Nested empty bundle occupies 4 weight units" {
    var pouch = BundlePouch{};
    const inserted = insertIntoBundle(&pouch, BUNDLE_ITEM_ID, 1, 1);
    try std.testing.expectEqual(@as(u8, 1), inserted);
    try std.testing.expectEqual(@as(u8, 4), pouch.total_weight);

    // Can fit up to 16 empty bundles total (16 * 4 = 64)
    const inserted_more = insertIntoBundle(&pouch, BUNDLE_ITEM_ID, 15, 1);
    try std.testing.expectEqual(@as(u8, 15), inserted_more);
    try std.testing.expectEqual(@as(u8, 64), pouch.total_weight);
    try std.testing.expect(pouch.isFull());
}

test "bundle_pouch: 8. Mixed 64-stack + 16-stack weight math" {
    var pouch = BundlePouch{};
    // 32 dirt (max_stack 64) = 32 weight units
    const d = insertIntoBundle(&pouch, 1, 32, 64);
    try std.testing.expectEqual(@as(u8, 32), d);
    try std.testing.expectEqual(@as(u8, 32), pouch.total_weight);

    // 8 ender pearls (max_stack 16) = 8 * 4 = 32 weight units
    const p = insertIntoBundle(&pouch, 2, 8, 16);
    try std.testing.expectEqual(@as(u8, 8), p);
    try std.testing.expectEqual(@as(u8, 64), pouch.total_weight);
    try std.testing.expect(pouch.isFull());
    try std.testing.expectEqual(@as(u5, 2), pouch.entry_count);
}

test "bundle_pouch: 9. Partial insertion when nearly full (64-stack item)" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 1, 60, 64);
    try std.testing.expectEqual(@as(u8, 60), pouch.total_weight);

    // 4 units remaining. Inserting 10 cobblestone should accept only 4.
    const inserted = insertIntoBundle(&pouch, 2, 10, 64);
    try std.testing.expectEqual(@as(u8, 4), inserted);
    try std.testing.expectEqual(@as(u8, 64), pouch.total_weight);
    try std.testing.expect(pouch.isFull());
}

test "bundle_pouch: 10. Partial insertion when nearly full (16-stack item)" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 1, 62, 64);
    try std.testing.expectEqual(@as(u8, 62), pouch.total_weight);

    // 2 units remaining. An ender pearl requires 4 units, so 0 can fit.
    const inserted = insertIntoBundle(&pouch, 2, 1, 16);
    try std.testing.expectEqual(@as(u8, 0), inserted);
    try std.testing.expectEqual(@as(u8, 62), pouch.total_weight);

    // But 2 items of 64-stack will fit!
    const inserted_dirt = insertIntoBundle(&pouch, 3, 5, 64);
    try std.testing.expectEqual(@as(u8, 2), inserted_dirt);
    try std.testing.expectEqual(@as(u8, 64), pouch.total_weight);
}

test "bundle_pouch: 11. Merging into existing matching stack" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 5, 10, 64);
    _ = insertIntoBundle(&pouch, 5, 20, 64);

    try std.testing.expectEqual(@as(u5, 1), pouch.entry_count);
    try std.testing.expectEqual(@as(u16, 5), pouch.entries[0].item_id);
    try std.testing.expectEqual(@as(u8, 30), pouch.entries[0].count);
    try std.testing.expectEqual(@as(u8, 30), pouch.total_weight);
}

test "bundle_pouch: 12. Up to 16 distinct item entries capacity limit" {
    var pouch = BundlePouch{};
    // Insert 1 item each of 16 distinct IDs
    var id: u16 = 1;
    while (id <= 16) : (id += 1) {
        const ins = insertIntoBundle(&pouch, id, 1, 64);
        try std.testing.expectEqual(@as(u8, 1), ins);
    }
    try std.testing.expectEqual(@as(u5, 16), pouch.entry_count);
    try std.testing.expectEqual(@as(u8, 16), pouch.total_weight);

    // 17th distinct item cannot be added because all 16 slots are occupied
    const ins17 = insertIntoBundle(&pouch, 999, 1, 64);
    try std.testing.expectEqual(@as(u8, 0), ins17);
    try std.testing.expectEqual(@as(u5, 16), pouch.entry_count);

    // But adding to an existing item ID (e.g. id=1) succeeds by merging!
    const merge_ins = insertIntoBundle(&pouch, 1, 5, 64);
    try std.testing.expectEqual(@as(u8, 5), merge_ins);
    try std.testing.expectEqual(@as(u8, 6), pouch.entries[0].count);
    try std.testing.expectEqual(@as(u8, 21), pouch.total_weight);
}

test "bundle_pouch: 13. Extract without selection extracts top / most recently added stack (LIFO)" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 1, 10, 64); // Dirt (index 0)
    _ = insertIntoBundle(&pouch, 2, 5, 64);  // Stone (index 1)

    try std.testing.expectEqual(@as(?u4, null), pouch.selected_index);
    const top = extractSelectedOrTop(&pouch);
    try std.testing.expect(top != null);
    try std.testing.expectEqual(@as(u16, 2), top.?.item_id);
    try std.testing.expectEqual(@as(u8, 5), top.?.count);
    try std.testing.expectEqual(@as(u5, 1), pouch.entry_count);
    try std.testing.expectEqual(@as(u8, 10), pouch.total_weight);

    // Next extraction extracts Dirt
    const next = extractSelectedOrTop(&pouch);
    try std.testing.expect(next != null);
    try std.testing.expectEqual(@as(u16, 1), next.?.item_id);
    try std.testing.expectEqual(@as(u8, 10), next.?.count);
    try std.testing.expect(pouch.isEmpty());
}

test "bundle_pouch: 14. Extract with scroll selection removes specific selected item" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 10, 5, 64); // Slot 0
    _ = insertIntoBundle(&pouch, 20, 8, 64); // Slot 1
    _ = insertIntoBundle(&pouch, 30, 2, 64); // Slot 2
    try std.testing.expectEqual(@as(u8, 15), pouch.total_weight);

    // Select slot 1 (item 20)
    selectIndex(&pouch, 1);
    try std.testing.expectEqual(@as(?u4, 1), pouch.selected_index);

    const extracted = extractSelectedOrTop(&pouch);
    try std.testing.expect(extracted != null);
    try std.testing.expectEqual(@as(u16, 20), extracted.?.item_id);
    try std.testing.expectEqual(@as(u8, 8), extracted.?.count);

    // Remaining items should be slot 0: item 10, slot 1: item 30 (compacted)
    try std.testing.expectEqual(@as(u5, 2), pouch.entry_count);
    try std.testing.expectEqual(@as(u16, 10), pouch.entries[0].item_id);
    try std.testing.expectEqual(@as(u16, 30), pouch.entries[1].item_id);
    try std.testing.expectEqual(@as(u8, 7), pouch.total_weight);
}

test "bundle_pouch: 15. Mouse-wheel scroll selection cycling and wrapping" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 1, 1, 64);
    _ = insertIntoBundle(&pouch, 2, 1, 64);
    _ = insertIntoBundle(&pouch, 3, 1, 64);
    // entry_count = 3 (indices 0, 1, 2)

    try std.testing.expectEqual(@as(?u4, null), pouch.selected_index);

    // Scrolling starts from top (2): +1 wraps to 0
    scrollSelection(&pouch, 1);
    try std.testing.expectEqual(@as(?u4, 0), pouch.selected_index);

    scrollSelection(&pouch, 1);
    try std.testing.expectEqual(@as(?u4, 1), pouch.selected_index);

    scrollSelection(&pouch, 1);
    try std.testing.expectEqual(@as(?u4, 2), pouch.selected_index);

    scrollSelection(&pouch, 1);
    try std.testing.expectEqual(@as(?u4, 0), pouch.selected_index);

    // Scroll backward (-1) wraps to 2
    scrollSelection(&pouch, -1);
    try std.testing.expectEqual(@as(?u4, 2), pouch.selected_index);
}

test "bundle_pouch: 16. Selection index clamping when out of bounds" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 1, 1, 64);
    _ = insertIntoBundle(&pouch, 2, 1, 64);

    selectIndex(&pouch, 10); // Beyond entry_count (2), clamps to 1
    try std.testing.expectEqual(@as(?u4, 1), pouch.selected_index);

    _ = extractSelectedOrTop(&pouch); // Removes index 1
    try std.testing.expectEqual(@as(u5, 1), pouch.entry_count);
    try std.testing.expectEqual(@as(?u4, 0), pouch.selected_index); // Clamped to 0

    _ = extractSelectedOrTop(&pouch); // Removes index 0
    try std.testing.expect(pouch.isEmpty());
    try std.testing.expectEqual(@as(?u4, null), pouch.selected_index);
}

test "bundle_pouch: 17. Sequential extraction until bundle is empty" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 1, 2, 64);
    _ = insertIntoBundle(&pouch, 2, 3, 64);

    try std.testing.expect(extractSelectedOrTop(&pouch) != null);
    try std.testing.expect(extractSelectedOrTop(&pouch) != null);
    try std.testing.expectEqual(@as(?ExtractedItem, null), extractSelectedOrTop(&pouch));
}

test "bundle_pouch: 18. emptyAll dumps all contents into buffer and resets pouch" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 10, 5, 64);
    _ = insertIntoBundle(&pouch, 20, 2, 16);
    _ = insertIntoBundle(&pouch, 30, 10, 64);

    var out_buf: [16]BundleEntry = [_]BundleEntry{.{}} ** 16;
    const dumped = emptyAll(&pouch, &out_buf);

    try std.testing.expectEqual(@as(usize, 3), dumped);
    try std.testing.expectEqual(@as(u16, 10), out_buf[0].item_id);
    try std.testing.expectEqual(@as(u8, 5), out_buf[0].count);
    try std.testing.expectEqual(@as(u16, 20), out_buf[1].item_id);
    try std.testing.expectEqual(@as(u8, 2), out_buf[1].count);
    try std.testing.expectEqual(@as(u16, 30), out_buf[2].item_id);
    try std.testing.expectEqual(@as(u8, 10), out_buf[2].count);

    try std.testing.expect(pouch.isEmpty());
    try std.testing.expectEqual(@as(u8, 0), pouch.total_weight);
    try std.testing.expectEqual(@as(u5, 0), pouch.entry_count);
    try std.testing.expectEqual(@as(?u4, null), pouch.selected_index);
}

test "bundle_pouch: 19. emptyAll with smaller buffer performs partial dump" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 10, 5, 64);
    _ = insertIntoBundle(&pouch, 20, 10, 64);

    var small_buf: [1]BundleEntry = undefined;
    const dumped = emptyAll(&pouch, &small_buf);

    try std.testing.expectEqual(@as(usize, 1), dumped);
    try std.testing.expectEqual(@as(u16, 10), small_buf[0].item_id);
    try std.testing.expectEqual(@as(u8, 5), small_buf[0].count);

    // Remaining in pouch is item 20 with count 10
    try std.testing.expectEqual(@as(u5, 1), pouch.entry_count);
    try std.testing.expectEqual(@as(u16, 20), pouch.entries[0].item_id);
    try std.testing.expectEqual(@as(u8, 10), pouch.entries[0].count);
    try std.testing.expectEqual(@as(u8, 10), pouch.total_weight);
}

test "bundle_pouch: 20. fullnessBarRatio and isFull" {
    var pouch = BundlePouch{};
    try std.testing.expectEqual(@as(f32, 0.0), fullnessBarRatio(pouch));
    try std.testing.expect(!isFull(pouch));

    _ = insertIntoBundle(&pouch, 1, 32, 64);
    try std.testing.expectEqual(@as(f32, 0.5), fullnessBarRatio(pouch));
    try std.testing.expect(!isFull(pouch));

    _ = insertIntoBundle(&pouch, 1, 32, 64);
    try std.testing.expectEqual(@as(f32, 1.0), fullnessBarRatio(pouch));
    try std.testing.expect(isFull(pouch));
}

test "bundle_pouch: 21. Dyeing bundle with 16 colors and undyed default" {
    var pouch = BundlePouch{};
    try std.testing.expectEqual(@as(?u4, null), pouch.dye_color);
    try std.testing.expect(!pouch.isDyed());
    try std.testing.expectEqualStrings("Bundle", pouch.displayName());

    dyeBundle(&pouch, 0); // White
    try std.testing.expectEqual(@as(?u4, 0), pouch.dye_color);
    try std.testing.expect(pouch.isDyed());
    try std.testing.expectEqualStrings("White Bundle", pouch.displayName());

    dyeBundle(&pouch, 14); // Red
    try std.testing.expectEqual(@as(?u4, 14), pouch.dye_color);
    try std.testing.expectEqualStrings("Red Bundle", pouch.displayName());

    dyeBundle(&pouch, 9); // Cyan
    try std.testing.expectEqual(@as(?u4, 9), pouch.dye_color);
    try std.testing.expectEqualStrings("Cyan Bundle", pouch.displayName());

    // Revert to undyed
    undyeBundle(&pouch);
    try std.testing.expectEqual(@as(?u4, null), pouch.dye_color);
    try std.testing.expect(!pouch.isDyed());
    try std.testing.expectEqualStrings("Bundle", pouch.displayName());
}

test "bundle_pouch: 22. All 16 DyeColor enum values, rgbHex, and names" {
    try std.testing.expectEqual(@as(usize, 16), DyeColor.count);
    var i: u4 = 0;
    while (true) {
        const col: DyeColor = @enumFromInt(i);
        try std.testing.expect(col.name().len > 0);
        try std.testing.expect(col.rgbHex() > 0);

        var pouch = BundlePouch{};
        pouch.setDye(i);
        try std.testing.expect(pouch.isDyed());
        try std.testing.expect(pouch.displayName().len > "Bundle".len);

        if (i == 15) break;
        i += 1;
    }
}

test "bundle_pouch: 23. Comparator signal based on fullness" {
    var pouch = BundlePouch{};
    try std.testing.expectEqual(@as(u4, 0), comparatorSignal(pouch));

    _ = insertIntoBundle(&pouch, 1, 1, 64); // 1 / 64
    try std.testing.expectEqual(@as(u4, 1), comparatorSignal(pouch));

    _ = insertIntoBundle(&pouch, 1, 31, 64); // 32 / 64
    try std.testing.expectEqual(@as(u4, 8), comparatorSignal(pouch));

    _ = insertIntoBundle(&pouch, 1, 32, 64); // 64 / 64
    try std.testing.expectEqual(@as(u4, 15), comparatorSignal(pouch));
}

test "bundle_pouch: 24. Rejection of zero tag, count, or max_stack" {
    var pouch = BundlePouch{};
    try std.testing.expectEqual(@as(u8, 0), insertIntoBundle(&pouch, 0, 10, 64));
    try std.testing.expectEqual(@as(u8, 0), insertIntoBundle(&pouch, 1, 0, 64));
    try std.testing.expectEqual(@as(u8, 0), insertIntoBundle(&pouch, 1, 10, 0));
    try std.testing.expect(pouch.isEmpty());
}

test "bundle_pouch: 25. BundleEntry weight calculation helper" {
    const empty_e = BundleEntry{};
    try std.testing.expectEqual(@as(u8, 0), empty_e.weight());
    try std.testing.expect(empty_e.isEmpty());

    const e64 = BundleEntry{ .item_id = 1, .count = 10, .max_stack = 64 };
    try std.testing.expectEqual(@as(u8, 10), e64.weight());

    const e16 = BundleEntry{ .item_id = 2, .count = 3, .max_stack = 16 };
    try std.testing.expectEqual(@as(u8, 12), e16.weight());

    const e1 = BundleEntry{ .item_id = 3, .count = 1, .max_stack = 1 };
    try std.testing.expectEqual(@as(u8, 64), e1.weight());

    const eb = BundleEntry{ .item_id = BUNDLE_ITEM_ID, .count = 2, .max_stack = 1 };
    try std.testing.expectEqual(@as(u8, 8), eb.weight());
}

test "bundle_pouch: 26. recomputeWeight restores weight from entries" {
    var pouch = BundlePouch{};
    pouch.entries[0] = .{ .item_id = 1, .count = 10, .max_stack = 64 };
    pouch.entries[1] = .{ .item_id = 2, .count = 2, .max_stack = 16 };
    pouch.entry_count = 2;
    pouch.total_weight = 0; // Simulated desync

    recomputeWeight(&pouch);
    try std.testing.expectEqual(@as(u8, 18), pouch.total_weight);
}

test "bundle_pouch: 27. emptyAll on empty bundle returns 0" {
    var pouch = BundlePouch{};
    var buf: [4]BundleEntry = undefined;
    try std.testing.expectEqual(@as(usize, 0), emptyAll(&pouch, &buf));
    try std.testing.expectEqual(@as(usize, 0), emptyAll(&pouch, &[_]BundleEntry{}));
}


// ============================================================================
// UNIT TESTS (Bundle Nesting & Color Dyeing - 38 Tests)
// ============================================================================

test "bundle_dyeing_nesting: 1. Capacity weight math: 64-stack item contributes 1 unit per item" {
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

test "bundle_dyeing_nesting: 2. Capacity weight math: 16-stack item contributes 4 units per item" {
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

test "bundle_dyeing_nesting: 3. Capacity weight math: 1-stack item contributes 64 units per item" {
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

test "bundle_dyeing_nesting: 4. Capacity weight math: arbitrary stack sizes and stackWeight helper" {
    try std.testing.expectEqual(@as(u8, 0), itemWeight(0));
    try std.testing.expectEqual(@as(u8, 2), itemWeight(32)); // 64 / 32 = 2
    try std.testing.expectEqual(@as(u8, 8), itemWeight(8));  // 64 / 8 = 8
    try std.testing.expectEqual(@as(u8, 16), itemWeight(4)); // 64 / 4 = 16
    try std.testing.expectEqual(@as(u8, 32), itemWeight(2)); // 64 / 2 = 32

    try std.testing.expectEqual(@as(u16, 20), stackWeight(32, 10)); // 10 * 2 = 20
    try std.testing.expectEqual(@as(u16, 40), stackWeight(8, 5));   // 5 * 8 = 40
}

test "bundle_dyeing_nesting: 5. Empty bundle baseline weight: 4 units when nested" {
    var outer = Bundle.init(1, .undyed);
    var inner = Bundle.init(2, .white);

    try std.testing.expectEqual(@as(u8, 0), inner.totalWeight());
    try std.testing.expectEqual(@as(u8, 4), inner.nestedBundleWeight());

    try outer.insertBundle(&inner);
    try std.testing.expectEqual(@as(u8, 4), outer.totalWeight());
    try std.testing.expectEqual(@as(u8, 60), outer.remainingCapacity());
}

test "bundle_dyeing_nesting: 6. Nested bundle weight calculation: 4 base + contents weight" {
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

test "bundle_dyeing_nesting: 7. Multi-level nested bundles: 3-level nesting weight propagation" {
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

test "bundle_dyeing_nesting: 8. Multiple nested bundles in parallel inside a single bundle" {
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

test "bundle_dyeing_nesting: 9. Capacity limit: exactly 16 empty bundles fill a bundle to 64/64" {
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

test "bundle_dyeing_nesting: 10. Capacity overflow: 17th empty bundle is rejected" {
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

test "bundle_dyeing_nesting: 11. Capacity overflow: bundle with 61 contents cannot be nested in any bundle" {
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

test "bundle_dyeing_nesting: 12. Capacity overflow: partial item insertion when nearly full" {
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

test "bundle_dyeing_nesting: 13. Self-containment rejection: bundle cannot be inserted into itself" {
    var bundle = Bundle.init(1, .undyed);
    try std.testing.expectError(BundleError.SelfContainment, bundle.insertBundle(&bundle));
    try std.testing.expect(!bundle.canInsertBundle(&bundle));
    try std.testing.expectEqual(@as(u8, 0), bundle.entry_count);
}

test "bundle_dyeing_nesting: 14. Recursive loop rejection: 2-node cycle (A -> B -> A)" {
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

test "bundle_dyeing_nesting: 15. Recursive loop rejection: 3-node cycle (A -> B -> C -> A)" {
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

test "bundle_dyeing_nesting: 16. Already-nested bundle cannot be inserted into another bundle without prior extraction" {
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

test "bundle_dyeing_nesting: 17. BundleColor enum: 17 variants (undyed + 16 colors) and names" {
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

test "bundle_dyeing_nesting: 18. BundleColor rgbHex and toDyeColor/fromDyeColor conversion" {
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

test "bundle_dyeing_nesting: 19. Crafting grid dyeing: 1 Bundle + 1 Dye preserves all items inside" {
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

test "bundle_dyeing_nesting: 20. Crafting grid dyeing: all 16 dye colors individually preserve contents" {
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

test "bundle_dyeing_nesting: 21. Crafting grid dyeing: re-dyeing already-dyed bundle" {
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

test "bundle_dyeing_nesting: 22. Crafting grid dyeing: invalid recipes rejected (multiple bundles, missing dye, extra items)" {
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

test "bundle_dyeing_nesting: 23. Cauldron washing: dyed bundle in water cauldron reverts to undyed and decrements water level" {
    var bundle = Bundle.init(1, .cyan);
    var cauldron = Cauldron.init(3);

    try std.testing.expect(cauldron.washBundle(&bundle));
    try std.testing.expectEqual(BundleColor.undyed, bundle.color);
    try std.testing.expectEqualStrings("Bundle", bundle.displayName());
    try std.testing.expectEqual(@as(u2, 2), cauldron.water_level);
}

test "bundle_dyeing_nesting: 24. Cauldron washing: sequential washing until cauldron reaches 0 water" {
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

test "bundle_dyeing_nesting: 25. Cauldron washing: fails when cauldron water level is 0" {
    var bundle = Bundle.init(1, .magenta);
    var water_level: u2 = 0;

    try std.testing.expect(!washBundleInCauldron(&bundle, &water_level));
    try std.testing.expectEqual(BundleColor.magenta, bundle.color);
    try std.testing.expectEqual(@as(u2, 0), water_level);
}

test "bundle_dyeing_nesting: 26. Cauldron washing: fails when bundle is already undyed (no water consumed)" {
    var bundle = Bundle.init(1, .undyed);
    var water_level: u2 = 3;

    try std.testing.expect(!washBundleInCauldron(&bundle, &water_level));
    try std.testing.expectEqual(BundleColor.undyed, bundle.color);
    try std.testing.expectEqual(@as(u2, 3), water_level); // No water wasted!
}

test "bundle_dyeing_nesting: 27. Cauldron washing: preserves all contents and nested bundles inside" {
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

test "bundle_dyeing_nesting: 28. Cauldron washing: integration with cauldron_fluids.CauldronState and rejection of lava/snow" {
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

test "bundle_dyeing_nesting: 29. Extraction & insertion: LIFO order extraction of items" {
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

test "bundle_dyeing_nesting: 30. Extraction & insertion: LIFO order extraction of nested bundles and regular items mixed" {
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

test "bundle_dyeing_nesting: 31. Extraction & insertion: extraction clears parent reference on extracted bundle" {
    var outer = Bundle.init(1, .undyed);
    var inner = Bundle.init(2, .white);

    try outer.insertBundle(&inner);
    try std.testing.expectEqual(inner.parent, &outer);

    const ext = outer.extract().?;
    const child = ext.asBundle().?;
    try std.testing.expectEqual(child.parent, null);
    try std.testing.expectEqual(inner.parent, null);
}

test "bundle_dyeing_nesting: 32. Extraction & insertion: extract with scroll selection" {
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

test "bundle_dyeing_nesting: 33. Scroll selection cycling and wrapping" {
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

test "bundle_dyeing_nesting: 34. Full bundle dumping: dumpAll empties bundle and resets parent references" {
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

test "bundle_dyeing_nesting: 35. Full bundle dumping: dumpAll on empty bundle returns 0" {
    var bundle = Bundle.init(1, .undyed);
    var out_buf: [4]ExtractedEntry = undefined;
    try std.testing.expectEqual(@as(usize, 0), bundle.dumpAll(&out_buf));
}

test "bundle_dyeing_nesting: 36. Redstone comparator signal: empty bundle outputs 0, full outputs 15" {
    var bundle = Bundle.init(1, .undyed);
    try std.testing.expectEqual(@as(u4, 0), bundle.comparatorSignal());

    _ = bundle.insertItem(1, 64, 64); // Full 64 weight
    try std.testing.expectEqual(@as(u4, 15), bundle.comparatorSignal());
}

test "bundle_dyeing_nesting: 37. Redstone comparator signal: exact formula curve verification across various weights" {
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

test "bundle_dyeing_nesting: 38. BundlePool: creation, nesting, and release without memory leaks" {
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
