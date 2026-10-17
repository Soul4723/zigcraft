const std = @import("std");

/// Piglins evaluate nearby guarded blocks across this radius.
pub const guarded_block_anger_radius: f32 = 16.0;
pub const guarded_block_anger_duration: f32 = 30.0;
pub const guarded_block_anger_ticks: u32 = 600;

/// Gold-ingot admiration lasts six seconds at the standard 20 TPS tick rate.
pub const barter_admiration_duration: f32 = 6.0;
pub const barter_admiration_ticks: u32 = 120;

/// Piglins and brutes shiver for fifteen seconds before zombifying in the
/// Overworld or End. Nether piglins do not use this timer.
pub const overworld_zombification_duration: f32 = 15.0;
pub const overworld_zombification_ticks: u32 = 300;

pub const soul_fire_repulsion_radius: f32 = 8.0;
pub const piglin_brute_max_health: f32 = 50.0;
pub const piglin_brute_axe_damage: f32 = 13.0;

/// Standard piglins accept any one piece of golden armor, unless the player
/// has provoked the bastion by opening/mining a guarded block. Brutes ignore
/// armor and are consequently never pacified by this rule.
pub fn isPiglinPacifiedByPlayer(
    wearing_any_gold_armor: bool,
    opened_or_mined_guarded_block: bool,
    is_piglin_brute: bool,
) bool {
    return !is_piglin_brute and wearing_any_gold_armor and !opened_or_mined_guarded_block;
}

/// Returns whether a guarded block interaction at `distance` provokes nearby
/// piglins. The caller can use the result to apply the 30-second anger timer.
pub fn guardedBlockProvokesPiglins(distance: f32) bool {
    return distance >= 0.0 and distance <= guarded_block_anger_radius;
}

pub const PiglinBarterState = struct {
    ticks_remaining: u16 = 0,
    is_baby: bool = false,
    holding_gold: bool = false,
    distracted: bool = false,

    pub fn init(is_baby: bool) PiglinBarterState {
        return .{ .is_baby = is_baby };
    }

    /// Starts (or restarts) the six-second admiration animation.
    pub fn startAdmiring(self: *PiglinBarterState) void {
        self.ticks_remaining = barter_admiration_ticks;
        self.holding_gold = true;
        self.distracted = false;
    }

    /// Advances admiration by game ticks. Returns true on the completion tick.
    pub fn tick(self: *PiglinBarterState, ticks: u32) bool {
        if (!self.holding_gold or self.ticks_remaining == 0) return false;
        const amount: u16 = @intCast(@min(ticks, @as(u32, self.ticks_remaining)));
        self.ticks_remaining -= amount;
        return self.ticks_remaining == 0;
    }

    pub fn isAdmiring(self: PiglinBarterState) bool {
        return self.holding_gold and self.ticks_remaining > 0;
    }

    /// Adult piglins return loot after admiration. Babies keep the ingot; a
    /// distracted baby also keeps it, matching the confiscation behavior.
    pub fn returnsLoot(self: PiglinBarterState) bool {
        return !self.is_baby and self.holding_gold and !self.distracted;
    }

    pub fn babyKeepsGold(self: PiglinBarterState) bool {
        return self.is_baby and self.holding_gold and !self.returnsLoot();
    }
};

pub const BarterLoot = struct {
    item_name: []const u8,
    min_count: u8,
    max_count: u8,
};

// Weighted 8-bit table. The final entry owns the remainder, so every u8 roll
// deterministically yields one of the documented barter rewards.
const barter_loot_table = [_]struct { weight: u16, loot: BarterLoot }{
    .{ .weight = 6, .loot = .{ .item_name = "Ender Pearls", .min_count = 2, .max_count = 4 } },
    .{ .weight = 22, .loot = .{ .item_name = "Crying Obsidian", .min_count = 1, .max_count = 3 } },
    .{ .weight = 22, .loot = .{ .item_name = "Obsidian", .min_count = 1, .max_count = 1 } },
    .{ .weight = 22, .loot = .{ .item_name = "Fire Resistance Potion", .min_count = 1, .max_count = 1 } },
    .{ .weight = 4, .loot = .{ .item_name = "Soul Speed Book", .min_count = 1, .max_count = 1 } },
    .{ .weight = 4, .loot = .{ .item_name = "Soul Speed Boots", .min_count = 1, .max_count = 1 } },
    .{ .weight = 22, .loot = .{ .item_name = "Spectral Arrows", .min_count = 6, .max_count = 12 } },
    .{ .weight = 22, .loot = .{ .item_name = "Nether Quartz", .min_count = 5, .max_count = 12 } },
    .{ .weight = 22, .loot = .{ .item_name = "String", .min_count = 3, .max_count = 9 } },
    .{ .weight = 22, .loot = .{ .item_name = "Gravel", .min_count = 8, .max_count = 16 } },
    .{ .weight = 88, .loot = .{ .item_name = "Iron Nuggets", .min_count = 9, .max_count = 36 } },
};

pub fn rollPiglinBarterLoot(roll: u8) BarterLoot {
    var cursor: u16 = @as(u16, roll);
    for (barter_loot_table) |entry| {
        if (cursor < entry.weight) return entry.loot;
        cursor -= entry.weight;
    }
    return barter_loot_table[barter_loot_table.len - 1].loot;
}

/// `is_overworld_or_end` excludes the Nether, where piglins remain native.
pub fn shouldTransformToZombifiedPiglin(ticks_elapsed: u32, is_overworld_or_end: bool) bool {
    return is_overworld_or_end and ticks_elapsed >= overworld_zombification_ticks;
}

pub fn fleeFromSoulFire(is_brute: bool, dist_to_soul_fire: f32) bool {
    return !is_brute and dist_to_soul_fire >= 0.0 and dist_to_soul_fire <= soul_fire_repulsion_radius;
}

test "gold armor pacifies standard piglins" {
    try std.testing.expect(isPiglinPacifiedByPlayer(true, false, false));
    try std.testing.expect(!isPiglinPacifiedByPlayer(false, false, false));
}

test "all golden armor pieces are represented by one boolean" {
    try std.testing.expect(isPiglinPacifiedByPlayer(true, false, false));
}

test "guarded chest or gold mining provocation overrides armor" {
    try std.testing.expect(!isPiglinPacifiedByPlayer(true, true, false));
    try std.testing.expect(guardedBlockProvokesPiglins(16.0));
    try std.testing.expect(!guardedBlockProvokesPiglins(16.01));
}

test "piglin brute always attacks despite armor" {
    try std.testing.expect(!isPiglinPacifiedByPlayer(true, false, true));
    try std.testing.expectEqual(@as(f32, 50.0), piglin_brute_max_health);
    try std.testing.expectEqual(@as(f32, 13.0), piglin_brute_axe_damage);
}

test "barter admiration lasts exactly 120 ticks" {
    var state = PiglinBarterState.init(false);
    state.startAdmiring();
    try std.testing.expectEqual(@as(u32, 120), barter_admiration_ticks);
    try std.testing.expect(state.isAdmiring());
    try std.testing.expect(!state.tick(119));
    try std.testing.expect(state.tick(1));
    try std.testing.expect(!state.isAdmiring());
}

test "barter tick clamps large advances" {
    var state = PiglinBarterState.init(false);
    state.startAdmiring();
    try std.testing.expect(state.tick(1000));
    try std.testing.expectEqual(@as(u16, 0), state.ticks_remaining);
}

test "adult piglin returns loot after admiration" {
    var state = PiglinBarterState.init(false);
    state.startAdmiring();
    _ = state.tick(barter_admiration_ticks);
    try std.testing.expect(state.returnsLoot());
    try std.testing.expect(!state.babyKeepsGold());
}

test "baby piglin keeps gold without returning loot" {
    var state = PiglinBarterState.init(true);
    state.startAdmiring();
    _ = state.tick(barter_admiration_ticks);
    try std.testing.expect(!state.returnsLoot());
    try std.testing.expect(state.babyKeepsGold());
}

test "distracted adult does not return loot" {
    var state = PiglinBarterState.init(false);
    state.startAdmiring();
    state.distracted = true;
    try std.testing.expect(!state.returnsLoot());
}

test "barter table includes pearls and crying obsidian" {
    try std.testing.expectEqualStrings("Ender Pearls", rollPiglinBarterLoot(0).item_name);
    try std.testing.expectEqualStrings("Crying Obsidian", rollPiglinBarterLoot(6).item_name);
}

test "barter table covers every reward category" {
    const expected = [_][]const u8{ "Ender Pearls", "Crying Obsidian", "Obsidian", "Fire Resistance Potion", "Soul Speed Book", "Soul Speed Boots", "Spectral Arrows", "Nether Quartz", "String", "Gravel", "Iron Nuggets" };
    for (expected) |name| {
        var found = false;
        var roll: u16 = 0;
        while (roll <= 255) : (roll += 1) {
            if (std.mem.eql(u8, rollPiglinBarterLoot(@intCast(roll)).item_name, name)) found = true;
        }
        try std.testing.expect(found);
    }
}

test "loot counts are ordered" {
    var roll: u16 = 0;
    while (roll <= 255) : (roll += 1) {
        const loot = rollPiglinBarterLoot(@intCast(roll));
        try std.testing.expect(loot.min_count <= loot.max_count);
    }
}

test "overworld zombification begins after 300 ticks" {
    try std.testing.expect(!shouldTransformToZombifiedPiglin(299, true));
    try std.testing.expect(shouldTransformToZombifiedPiglin(300, true));
    try std.testing.expect(!shouldTransformToZombifiedPiglin(300, false));
}

test "zombification timer is fifteen seconds" {
    try std.testing.expectEqual(@as(f32, 15.0), overworld_zombification_duration);
    try std.testing.expectEqual(@as(u32, 300), overworld_zombification_ticks);
}

test "normal piglins flee soul fire within eight blocks" {
    try std.testing.expect(fleeFromSoulFire(false, 0.0));
    try std.testing.expect(fleeFromSoulFire(false, 8.0));
    try std.testing.expect(!fleeFromSoulFire(false, 8.01));
}

test "piglin brutes do not flee soul fire" {
    try std.testing.expect(!fleeFromSoulFire(true, 1.0));
    try std.testing.expect(!fleeFromSoulFire(true, 8.0));
}
