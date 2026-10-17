const std = @import("std");

/// Standard item ID for an undyed Bundle pouch.
pub const BUNDLE_ITEM_ID: u16 = 371;
pub const BUNDLE_ITEM_TAG: u16 = BUNDLE_ITEM_ID;

/// Maximum weight capacity of a Bundle pouch (64 weight units).
pub const MAX_BUNDLE_WEIGHT: u8 = 64;

/// Maximum number of distinct item entries inside a bundle pouch (16 slots).
pub const MAX_BUNDLE_ENTRIES: usize = 16;

/// Weight unit calculation rules for Bundle items.
pub const BundleWeight = struct {
    pub const max_capacity: u8 = MAX_BUNDLE_WEIGHT;
    pub const empty_bundle_weight: u8 = 4;

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

/// Undyed default sentinel constant (null).
pub const undyed_default: ?u4 = null;
pub const UNDYED: ?u4 = null;

/// A single distinct item entry inside a bundle pouch.
pub const BundleEntry = struct {
    item_id: u16 = 0,
    count: u8 = 0,
    max_stack: u8 = 64,

    /// Weight unit occupied by this entry.
    pub fn weight(self: BundleEntry) u8 {
        if (self.item_id == 0 or self.count == 0) return 0;
        const unit = BundleWeight.perItemForId(self.item_id, self.max_stack);
        const w = @as(u16, unit) * @as(u16, self.count);
        return @intCast(@min(64, w));
    }

    pub fn isEmpty(self: BundleEntry) bool {
        return self.item_id == 0 or self.count == 0;
    }
};

/// Result of extracting an item stack from a bundle.
pub const ExtractedItem = struct {
    item_id: u16,
    count: u8,
};

/// A bundle pouch container tracking mixed item entries, weight, scroll selection, and dye color.
pub const BundlePouch = struct {
    entries: [MAX_BUNDLE_ENTRIES]BundleEntry = [_]BundleEntry{.{}} ** MAX_BUNDLE_ENTRIES,
    entry_count: u5 = 0,
    total_weight: u8 = 0,
    selected_index: ?u4 = null,
    dye_color: ?u4 = null,

    pub const max_entries: usize = MAX_BUNDLE_ENTRIES;
    pub const max_capacity: u8 = MAX_BUNDLE_WEIGHT;

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

    pub fn getDye(self: BundlePouch) ?u4 {
        return self.dye_color;
    }

    pub fn displayName(self: BundlePouch) []const u8 {
        return bundleDisplayName(self);
    }

    pub fn recalculateWeight(self: *BundlePouch) void {
        recomputeWeight(self);
    }
};

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

/// Redstone comparator signal (0 when empty, 1..15 based on ceil(fullness * 15)).
pub fn comparatorSignal(bundle: BundlePouch) u4 {
    if (bundle.total_weight == 0) return 0;
    const numerator = @as(u16, bundle.total_weight) * 15 + 63;
    const sig = numerator / 64;
    return @intCast(@min(15, sig));
}

// ============================================================================
// UNIT TESTS
// ============================================================================

test "1. BundleWeight calculations for standard stack sizes" {
    try std.testing.expectEqual(@as(u8, 1), BundleWeight.perItem(64));
    try std.testing.expectEqual(@as(u8, 4), BundleWeight.perItem(16));
    try std.testing.expectEqual(@as(u8, 64), BundleWeight.perItem(1));
    try std.testing.expectEqual(@as(u8, 4), BundleWeight.emptyBundle());
    try std.testing.expectEqual(@as(u8, 4), BundleWeight.perItemForId(BUNDLE_ITEM_ID, 1));

    try std.testing.expectEqual(@as(u16, 64), BundleWeight.total(64, 64));
    try std.testing.expectEqual(@as(u16, 64), BundleWeight.total(16, 16));
    try std.testing.expectEqual(@as(u16, 64), BundleWeight.total(1, 1));
}

test "2. BundleWeight edge cases and arbitrary stack sizes" {
    try std.testing.expectEqual(@as(u8, 0), BundleWeight.perItem(0));
    try std.testing.expectEqual(@as(u8, 2), BundleWeight.perItem(32));
    try std.testing.expectEqual(@as(u8, 8), BundleWeight.perItem(8));
    try std.testing.expectEqual(@as(u8, 16), BundleWeight.perItem(4));
    try std.testing.expectEqual(@as(u8, 32), BundleWeight.perItem(2));
}

test "3. BundlePouch default initialization" {
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

test "4. Insert 64-stack item increments weight by 1 per item" {
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

test "5. Insert 16-stack item increments weight by 4 per item" {
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

test "6. Unstackable 1-stack item fills entire 64/64 weight" {
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

test "7. Nested empty bundle occupies 4 weight units" {
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

test "8. Mixed 64-stack + 16-stack weight math" {
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

test "9. Partial insertion when nearly full (64-stack item)" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 1, 60, 64);
    try std.testing.expectEqual(@as(u8, 60), pouch.total_weight);

    // 4 units remaining. Inserting 10 cobblestone should accept only 4.
    const inserted = insertIntoBundle(&pouch, 2, 10, 64);
    try std.testing.expectEqual(@as(u8, 4), inserted);
    try std.testing.expectEqual(@as(u8, 64), pouch.total_weight);
    try std.testing.expect(pouch.isFull());
}

test "10. Partial insertion when nearly full (16-stack item)" {
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

test "11. Merging into existing matching stack" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 5, 10, 64);
    _ = insertIntoBundle(&pouch, 5, 20, 64);

    try std.testing.expectEqual(@as(u5, 1), pouch.entry_count);
    try std.testing.expectEqual(@as(u16, 5), pouch.entries[0].item_id);
    try std.testing.expectEqual(@as(u8, 30), pouch.entries[0].count);
    try std.testing.expectEqual(@as(u8, 30), pouch.total_weight);
}

test "12. Up to 16 distinct item entries capacity limit" {
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

test "13. Extract without selection extracts top / most recently added stack (LIFO)" {
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

test "14. Extract with scroll selection removes specific selected item" {
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

test "15. Mouse-wheel scroll selection cycling and wrapping" {
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

test "16. Selection index clamping when out of bounds" {
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

test "17. Sequential extraction until bundle is empty" {
    var pouch = BundlePouch{};
    _ = insertIntoBundle(&pouch, 1, 2, 64);
    _ = insertIntoBundle(&pouch, 2, 3, 64);

    try std.testing.expect(extractSelectedOrTop(&pouch) != null);
    try std.testing.expect(extractSelectedOrTop(&pouch) != null);
    try std.testing.expectEqual(@as(?ExtractedItem, null), extractSelectedOrTop(&pouch));
}

test "18. emptyAll dumps all contents into buffer and resets pouch" {
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

test "19. emptyAll with smaller buffer performs partial dump" {
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

test "20. fullnessBarRatio and isFull" {
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

test "21. Dyeing bundle with 16 colors and undyed default" {
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

test "22. All 16 DyeColor enum values, rgbHex, and names" {
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

test "23. Comparator signal based on fullness" {
    var pouch = BundlePouch{};
    try std.testing.expectEqual(@as(u4, 0), comparatorSignal(pouch));

    _ = insertIntoBundle(&pouch, 1, 1, 64); // 1 / 64
    try std.testing.expectEqual(@as(u4, 1), comparatorSignal(pouch));

    _ = insertIntoBundle(&pouch, 1, 31, 64); // 32 / 64
    try std.testing.expectEqual(@as(u4, 8), comparatorSignal(pouch));

    _ = insertIntoBundle(&pouch, 1, 32, 64); // 64 / 64
    try std.testing.expectEqual(@as(u4, 15), comparatorSignal(pouch));
}

test "24. Rejection of zero tag, count, or max_stack" {
    var pouch = BundlePouch{};
    try std.testing.expectEqual(@as(u8, 0), insertIntoBundle(&pouch, 0, 10, 64));
    try std.testing.expectEqual(@as(u8, 0), insertIntoBundle(&pouch, 1, 0, 64));
    try std.testing.expectEqual(@as(u8, 0), insertIntoBundle(&pouch, 1, 10, 0));
    try std.testing.expect(pouch.isEmpty());
}

test "25. BundleEntry weight calculation helper" {
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

test "26. recomputeWeight restores weight from entries" {
    var pouch = BundlePouch{};
    pouch.entries[0] = .{ .item_id = 1, .count = 10, .max_stack = 64 };
    pouch.entries[1] = .{ .item_id = 2, .count = 2, .max_stack = 16 };
    pouch.entry_count = 2;
    pouch.total_weight = 0; // Simulated desync

    recomputeWeight(&pouch);
    try std.testing.expectEqual(@as(u8, 18), pouch.total_weight);
}

test "27. emptyAll on empty bundle returns 0" {
    var pouch = BundlePouch{};
    var buf: [4]BundleEntry = undefined;
    try std.testing.expectEqual(@as(usize, 0), emptyAll(&pouch, &buf));
    try std.testing.expectEqual(@as(usize, 0), emptyAll(&pouch, &[_]BundleEntry{}));
}
