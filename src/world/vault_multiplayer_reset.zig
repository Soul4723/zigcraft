const std = @import("std");

/// Item IDs mirrored from canonical inventory definitions so this world module is an isolated test target.
pub const ItemType = enum(u16) {
    iron_ingot = 26,
    golden_apple = 30,
    bread = 34,
    cooked_beef = 36,
    diamond = 217,
    emerald = 273,
    baked_potato = 343,
    breeze_rod = 371,
    heavy_core = 373,
    trial_key = 376,
    enchanted_golden_apple = 379,
    flow_armor_trim_template = 402,
    bolt_armor_trim_template = 403,
    wind_burst_enchanted_book = 405,
    flow_banner_pattern = 406,
    ominous_trial_key = 416,
    vault_reset_token = 613,

    pub fn name(self: ItemType) []const u8 {
        return switch (self) {
            .iron_ingot => "Iron Ingot",
            .golden_apple => "Golden Apple",
            .bread => "Bread",
            .cooked_beef => "Cooked Beef",
            .diamond => "Diamond",
            .emerald => "Emerald",
            .baked_potato => "Baked Potato",
            .breeze_rod => "Breeze Rod",
            .heavy_core => "Heavy Core",
            .trial_key => "Trial Key",
            .enchanted_golden_apple => "Enchanted Golden Apple",
            .flow_armor_trim_template => "Flow Armor Trim Smithing Template",
            .bolt_armor_trim_template => "Bolt Armor Trim Smithing Template",
            .wind_burst_enchanted_book => "Wind Burst Enchanted Book",
            .flow_banner_pattern => "Flow Banner Pattern",
            .ominous_trial_key => "Ominous Trial Key",
            .vault_reset_token => "Vault Reset Token",
        };
    }

    pub fn isOminousExclusive(self: ItemType) bool {
        return switch (self) {
            .heavy_core,
            .flow_armor_trim_template,
            .bolt_armor_trim_template,
            .wind_burst_enchanted_book,
            .flow_banner_pattern,
            => true,
            else => false,
        };
    }

    pub fn isStandardReward(self: ItemType) bool {
        return !self.isOminousExclusive() and self != .trial_key and self != .ominous_trial_key and self != .vault_reset_token;
    }
};

pub const VaultType = enum { standard, ominous };
pub const VaultState = enum { idle, ejecting, unlocked };
pub const State = VaultState;

pub const InteractionResult = enum {
    started_ejection,
    reset,
    already_unlocked,
    wrong_item,
    busy,
    player_limit,
};

pub const EJECTION_TICKS: u8 = 40;
pub const RESET_TOKEN_DROP_PERCENT: u8 = 5;
pub const MIN_LOOT_ITEMS: usize = 3;
pub const MAX_LOOT_ITEMS: usize = 6;
pub const MAX_EJECTED_STACKS: usize = MAX_LOOT_ITEMS;
pub const MIN_UPWARD_VELOCITY: f32 = 0.35;
pub const MAX_UPWARD_VELOCITY: f32 = 0.55;
pub const MIN_HORIZONTAL_SPEED: f32 = 0.15;
pub const MAX_HORIZONTAL_SPEED: f32 = 0.35;
pub const MAX_UNLOCKED_PLAYERS: usize = 64;
pub const HEAVY_CORE_CHANCE_PER_MILLE: u32 = 22; // 2.2% chance
pub const COMPARATOR_DETECTION_RADIUS: f32 = 4.5;
pub const COMPARATOR_RADIUS_SQ: f32 = COMPARATOR_DETECTION_RADIUS * COMPARATOR_DETECTION_RADIUS;
pub const COMPARATOR_MAX_SIGNAL: u4 = 15;
pub const COMPARATOR_MIN_SIGNAL: u4 = 0;

const TAU: f32 = 2.0 * std.math.pi;

pub const ItemStack = struct {
    item: ItemType,
    count: u8 = 1,
};
pub const Stack = ItemStack;

pub const Inventory = struct {
    slots: [36]?ItemStack = [_]?ItemStack{null} ** 36,

    pub fn count(self: Inventory, item: ItemType) u32 {
        var total: u32 = 0;
        for (self.slots) |slot| if (slot) |s| {
            if (s.item == item) total += s.count;
        };
        return total;
    }

    pub fn consumeOne(self: *Inventory, item: ItemType) bool {
        for (&self.slots) |*slot| {
            if (slot.*) |*s| {
                if (s.item != item or s.count == 0) continue;
                s.count -= 1;
                if (s.count == 0) slot.* = null;
                return true;
            }
        }
        return false;
    }
};

pub const EjectedItem = struct {
    item: ItemType,
    count: u8 = 1,
    stack: ItemStack,
    position: [3]f32,
    velocity: [3]f32,
    dispersion_angle: f32 = 0.0,
};
pub const EjectedStack = EjectedItem;

pub const DisplayPreview = struct {
    item: ItemType,
    position: [3]f32,
    spin_radians: f32,
};
pub const DisplayItem = DisplayPreview;

pub const Loot = struct {
    items: [MAX_LOOT_ITEMS]?EjectedItem = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS,
    count: u8 = 0,

    pub fn stacks(self: Loot) [MAX_LOOT_ITEMS]?EjectedItem {
        return self.items;
    }
};
pub const LootGeneration = Loot;

pub const UnlockResult = struct {
    interaction: InteractionResult,
    ejected: [MAX_LOOT_ITEMS]?EjectedItem = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS,
    ejected_count: u8 = 0,
};

pub const PlayerPosition = struct {
    player_id: u32,
    position: [3]f32,
};
pub const NearbyPlayer = struct {
    id: u32,
    position: [3]f32,

    pub fn toPlayerPosition(self: NearbyPlayer) PlayerPosition {
        return .{ .player_id = self.id, .position = self.position };
    }
};

pub const Vault = struct {
    position: [3]f32,
    vault_type: VaultType = .standard,
    state: VaultState = .idle,
    unlocked_players: [MAX_UNLOCKED_PLAYERS]u32 = [_]u32{0} ** MAX_UNLOCKED_PLAYERS,
    unlocked_player_count: u8 = 0,
    eject_ticks_remaining: u8 = 0,
    display_ticks: u32 = 0,
    spin_radians: f32 = 0.0,
    active_ejector: ?u32 = null,
    last_ejected_items: [MAX_LOOT_ITEMS]?EjectedItem = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS,
    last_ejected_count: u8 = 0,

    pub fn init(vault_type: VaultType, position: [3]f32) Vault {
        return .{
            .position = position,
            .vault_type = vault_type,
        };
    }

    pub fn hasPlayerUnlocked(self: Vault, player_id: u32) bool {
        for (self.unlocked_players[0..self.unlocked_player_count]) |id| {
            if (id == player_id) return true;
        }
        return false;
    }

    pub fn acceptsInteraction(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id) and self.unlocked_player_count < MAX_UNLOCKED_PLAYERS;
    }

    pub fn canInsertKey(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id) and self.state != .ejecting and self.unlocked_player_count < MAX_UNLOCKED_PLAYERS;
    }

    pub fn keyholeIsDark(self: Vault, player_id: u32) bool {
        return self.hasPlayerUnlocked(player_id);
    }

    pub fn displayItemVisible(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id);
    }

    pub fn emitsAmbientParticles(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id);
    }
    pub const emitsAmbientSparks = emitsAmbientParticles;

    pub fn currentShowcaseItem(self: Vault) ItemType {
        if (self.vault_type == .ominous) {
            const pool = [_]ItemType{
                .heavy_core,
                .flow_armor_trim_template,
                .bolt_armor_trim_template,
                .wind_burst_enchanted_book,
                .diamond,
                .enchanted_golden_apple,
            };
            const index = (self.display_ticks / 40) % pool.len;
            return pool[index];
        } else {
            const pool = [_]ItemType{
                .diamond,
                .emerald,
                .golden_apple,
                .iron_ingot,
                .breeze_rod,
            };
            const index = (self.display_ticks / 40) % pool.len;
            return pool[index];
        }
    }

    pub fn displayPreview(self: Vault, player_id: u32) ?DisplayPreview {
        if (!self.displayItemVisible(player_id)) return null;
        const angle = if (self.state == .ejecting)
            self.spin_radians
        else
            @as(f32, @floatFromInt(self.display_ticks % 628)) * 0.01;
        return .{
            .item = self.currentShowcaseItem(),
            .position = .{ self.position[0] + 0.5, self.position[1] + 0.65, self.position[2] + 0.5 },
            .spin_radians = angle,
        };
    }

    pub fn displayForPlayer(self: Vault, player_id: u32) ?DisplayPreview {
        return self.displayPreview(player_id);
    }

    pub fn resetPlayerLock(self: *Vault, player_id: u32) bool {
        for (self.unlocked_players[0..self.unlocked_player_count], 0..) |id, index| {
            if (id != player_id) continue;
            var i = index;
            while (i + 1 < self.unlocked_player_count) : (i += 1) {
                self.unlocked_players[i] = self.unlocked_players[i + 1];
            }
            self.unlocked_player_count -= 1;
            self.unlocked_players[self.unlocked_player_count] = 0;
            return true;
        }
        return false;
    }

    pub fn interact(self: *Vault, player_id: u32, inventory: *Inventory, seed: u32) UnlockResult {
        // 1. If player has already unlocked this vault:
        if (self.hasPlayerUnlocked(player_id)) {
            if (self.state == .ejecting) return .{ .interaction = .busy };
            if (inventory.consumeOne(.vault_reset_token)) {
                _ = self.resetPlayerLock(player_id);
                return .{ .interaction = .reset };
            }
            return .{ .interaction = .already_unlocked };
        }

        // 2. Vault currently busy ejecting for another player
        if (self.state == .ejecting) return .{ .interaction = .busy };

        // 3. Vault player capacity reached
        if (self.unlocked_player_count >= MAX_UNLOCKED_PLAYERS) {
            return .{ .interaction = .player_limit };
        }

        // 4. Key validation
        const needed_key = requiredKey(self.vault_type);
        if (!inventory.consumeOne(needed_key)) {
            return .{ .interaction = .wrong_item };
        }

        // 5. Successful unlock
        self.unlocked_players[self.unlocked_player_count] = player_id;
        self.unlocked_player_count += 1;
        self.state = .ejecting;
        self.eject_ticks_remaining = EJECTION_TICKS;
        self.spin_radians = 0.0;
        self.active_ejector = player_id;

        const generated = generateLoot(self.vault_type, seed, self.position);
        self.last_ejected_items = generated.items;
        self.last_ejected_count = generated.count;

        return .{
            .interaction = .started_ejection,
            .ejected = generated.items,
            .ejected_count = generated.count,
        };
    }

    pub fn tick(self: *Vault) bool {
        self.display_ticks +%= 1;
        if (self.state != .ejecting) return false;

        const progress = @as(f32, @floatFromInt(EJECTION_TICKS - self.eject_ticks_remaining)) / @as(f32, EJECTION_TICKS);
        const angular_speed = 0.8 - 0.6 * progress;
        self.spin_radians += angular_speed;

        if (self.eject_ticks_remaining > 0) self.eject_ticks_remaining -= 1;
        if (self.eject_ticks_remaining == 0) {
            self.state = .unlocked;
            self.active_ejector = null;
            return true;
        }
        return false;
    }

    pub fn comparatorOutput(self: Vault, players: []const PlayerPosition) u4 {
        var nearest_distance_sq = std.math.inf(f32);
        var nearest_id: ?u32 = null;
        for (players) |player| {
            const d2 = distanceSquared(self.position, player.position);
            if (d2 < nearest_distance_sq or (d2 == nearest_distance_sq and player.player_id < (nearest_id orelse std.math.maxInt(u32)))) {
                nearest_distance_sq = d2;
                nearest_id = player.player_id;
            }
        }
        const id = nearest_id orelse return COMPARATOR_MIN_SIGNAL;
        return if (self.hasPlayerUnlocked(id)) COMPARATOR_MIN_SIGNAL else COMPARATOR_MAX_SIGNAL;
    }

    pub fn comparatorSignal(self: Vault, players: []const PlayerPosition) u4 {
        return self.comparatorOutput(players);
    }

    pub fn comparatorOutputWithRadius(self: Vault, players: []const PlayerPosition, max_radius: f32) u4 {
        const max_radius_sq = max_radius * max_radius;
        var nearest_distance_sq = max_radius_sq;
        var nearest_id: ?u32 = null;
        for (players) |player| {
            const d2 = distanceSquared(self.position, player.position);
            if (d2 <= nearest_distance_sq) {
                if (nearest_id == null or d2 < nearest_distance_sq or player.player_id < nearest_id.?) {
                    nearest_distance_sq = d2;
                    nearest_id = player.player_id;
                }
            }
        }
        const id = nearest_id orelse return COMPARATOR_MIN_SIGNAL;
        return if (self.hasPlayerUnlocked(id)) COMPARATOR_MIN_SIGNAL else COMPARATOR_MAX_SIGNAL;
    }
};
pub const VaultBlock = Vault;

pub fn requiredKey(vault_type: VaultType) ItemType {
    return if (vault_type == .standard) .trial_key else .ominous_trial_key;
}

pub fn dropsVaultResetToken(ominous: bool, roll_percent: u8) bool {
    return ominous and roll_percent < RESET_TOKEN_DROP_PERCENT;
}

pub fn rollHeavyCore(rng_state: *u32) bool {
    return (nextRandom(rng_state) % 1000) < HEAVY_CORE_CHANCE_PER_MILLE;
}

pub fn rollHeavyCoreDirect(roll_1000: u32) bool {
    return roll_1000 < HEAVY_CORE_CHANCE_PER_MILLE;
}

pub fn isOminousExclusive(item: ItemType) bool {
    return item.isOminousExclusive();
}

pub fn isStandardReward(item: ItemType) bool {
    return item.isStandardReward();
}

fn distanceSquared(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

pub fn nextRandom(state: *u32) u32 {
    state.* = state.* *% 1664525 +% 1013904223;
    return state.*;
}

pub fn unitRandom(state: *u32) f32 {
    return @as(f32, @floatFromInt(nextRandom(state) >> 8)) / 16_777_216.0;
}

pub fn generateLoot(vault_type: VaultType, seed: u32, position: [3]f32) Loot {
    var result = Loot{};
    var rng = seed;
    const item_count: usize = MIN_LOOT_ITEMS + @as(usize, @intCast(nextRandom(&rng) % 4));

    if (vault_type == .ominous) {
        // Exclusive ominous rewards: Heavy Core (2.2%), Flow/Bolt armor trims, Wind Burst books, Flow banner pattern
        const heavy_core_awarded = (nextRandom(&rng) % 1000) < HEAVY_CORE_CHANCE_PER_MILLE;
        var heavy_core_added = false;

        while (result.count < item_count) {
            var item: ItemType = undefined;
            var count: u8 = 1;

            if (heavy_core_awarded and !heavy_core_added) {
                item = .heavy_core;
                count = 1;
                heavy_core_added = true;
            } else {
                const pool = [_]ItemType{
                    .flow_armor_trim_template,
                    .bolt_armor_trim_template,
                    .wind_burst_enchanted_book,
                    .flow_banner_pattern,
                    .diamond,
                    .emerald,
                    .enchanted_golden_apple,
                    .golden_apple,
                    .breeze_rod,
                    .iron_ingot,
                };
                item = pool[nextRandom(&rng) % pool.len];
                count = switch (item) {
                    .flow_armor_trim_template, .bolt_armor_trim_template, .wind_burst_enchanted_book, .flow_banner_pattern, .enchanted_golden_apple => 1,
                    .diamond => 1 + @as(u8, @intCast(nextRandom(&rng) % 3)),
                    .emerald => 2 + @as(u8, @intCast(nextRandom(&rng) % 5)),
                    .golden_apple => 1 + @as(u8, @intCast(nextRandom(&rng) % 2)),
                    .breeze_rod => 1 + @as(u8, @intCast(nextRandom(&rng) % 3)),
                    .iron_ingot => 2 + @as(u8, @intCast(nextRandom(&rng) % 4)),
                    else => 1,
                };
            }

            const theta = unitRandom(&rng) * TAU;
            const horizontal_speed = MIN_HORIZONTAL_SPEED + unitRandom(&rng) * (MAX_HORIZONTAL_SPEED - MIN_HORIZONTAL_SPEED);
            const vy = MIN_UPWARD_VELOCITY + unitRandom(&rng) * (MAX_UPWARD_VELOCITY - MIN_UPWARD_VELOCITY);
            const vx = @cos(theta) * horizontal_speed;
            const vz = @sin(theta) * horizontal_speed;

            result.items[result.count] = .{
                .item = item,
                .count = count,
                .stack = .{ .item = item, .count = count },
                .position = .{ position[0] + 0.5, position[1] + 1.0, position[2] + 0.5 },
                .velocity = .{ vx, vy, vz },
                .dispersion_angle = theta,
            };
            result.count += 1;
        }
    } else {
        // Standard Vault: dispenses standard rewards only (never ominous exclusives)
        const pool = [_]ItemType{
            .iron_ingot,
            .diamond,
            .emerald,
            .golden_apple,
            .enchanted_golden_apple,
            .breeze_rod,
            .bread,
            .cooked_beef,
            .baked_potato,
        };

        while (result.count < item_count) {
            const item = pool[nextRandom(&rng) % pool.len];
            const count: u8 = switch (item) {
                .enchanted_golden_apple => 1,
                .diamond => 1 + @as(u8, @intCast(nextRandom(&rng) % 2)),
                .golden_apple => 1 + @as(u8, @intCast(nextRandom(&rng) % 2)),
                .emerald, .iron_ingot => 2 + @as(u8, @intCast(nextRandom(&rng) % 4)),
                .breeze_rod => 1 + @as(u8, @intCast(nextRandom(&rng) % 2)),
                .bread, .cooked_beef, .baked_potato => 2 + @as(u8, @intCast(nextRandom(&rng) % 4)),
                else => 1,
            };

            const theta = unitRandom(&rng) * TAU;
            const horizontal_speed = MIN_HORIZONTAL_SPEED + unitRandom(&rng) * (MAX_HORIZONTAL_SPEED - MIN_HORIZONTAL_SPEED);
            const vy = MIN_UPWARD_VELOCITY + unitRandom(&rng) * (MAX_UPWARD_VELOCITY - MIN_UPWARD_VELOCITY);
            const vx = @cos(theta) * horizontal_speed;
            const vz = @sin(theta) * horizontal_speed;

            result.items[result.count] = .{
                .item = item,
                .count = count,
                .stack = .{ .item = item, .count = count },
                .position = .{ position[0] + 0.5, position[1] + 1.0, position[2] + 0.5 },
                .velocity = .{ vx, vy, vz },
                .dispersion_angle = theta,
            };
            result.count += 1;
        }
    }

    return result;
}

// ============================================================================
// UNIT TESTS (37 Tests)
// ============================================================================

test "1. Standard and ominous vaults require matching trial key variants" {
    try std.testing.expectEqual(ItemType.trial_key, requiredKey(.standard));
    try std.testing.expectEqual(ItemType.ominous_trial_key, requiredKey(.ominous));
    try std.testing.expectEqual(@as(u16, 376), @intFromEnum(ItemType.trial_key));
    try std.testing.expectEqual(@as(u16, 416), @intFromEnum(ItemType.ominous_trial_key));
}

test "2. Standard vault accepts standard key and consumes exactly one" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 2 };
    const res = vault.interact(1, &inv, 42);
    try std.testing.expectEqual(InteractionResult.started_ejection, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.trial_key));
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expectEqual(VaultState.ejecting, vault.state);
}

test "3. Standard vault rejects ominous trial key without consuming it" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .ominous_trial_key, .count = 1 };
    const res = vault.interact(1, &inv, 42);
    try std.testing.expectEqual(InteractionResult.wrong_item, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.ominous_trial_key));
    try std.testing.expect(!vault.hasPlayerUnlocked(1));
}

test "4. Ominous vault accepts ominous trial key and consumes exactly one" {
    var vault = Vault.init(.ominous, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .ominous_trial_key, .count = 3 };
    const res = vault.interact(10, &inv, 99);
    try std.testing.expectEqual(InteractionResult.started_ejection, res.interaction);
    try std.testing.expectEqual(@as(u32, 2), inv.count(.ominous_trial_key));
    try std.testing.expect(vault.hasPlayerUnlocked(10));
    try std.testing.expectEqual(VaultState.ejecting, vault.state);
}

test "5. Ominous vault rejects standard trial key without consuming it" {
    var vault = Vault.init(.ominous, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    const res = vault.interact(1, &inv, 42);
    try std.testing.expectEqual(InteractionResult.wrong_item, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.trial_key));
    try std.testing.expect(!vault.hasPlayerUnlocked(1));
}

test "6. Standard vault loot pool dispenses standard rewards only" {
    var seed: u32 = 1;
    while (seed <= 50) : (seed += 1) {
        const loot = generateLoot(.standard, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?.item;
            try std.testing.expect(item.isStandardReward());
            try std.testing.expect(!item.isOminousExclusive());
            try std.testing.expect(item != .heavy_core);
            try std.testing.expect(item != .flow_armor_trim_template);
            try std.testing.expect(item != .bolt_armor_trim_template);
            try std.testing.expect(item != .wind_burst_enchanted_book);
            try std.testing.expect(item != .flow_banner_pattern);
        }
    }
}

test "7. Ominous vault loot pool dispenses exclusive ominous rewards" {
    var found_flow_trim = false;
    var found_bolt_trim = false;
    var found_wind_burst = false;
    var found_heavy_core = false;

    var seed: u32 = 1;
    while (seed <= 500) : (seed += 1) {
        const loot = generateLoot(.ominous, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?.item;
            if (item == .flow_armor_trim_template) found_flow_trim = true;
            if (item == .bolt_armor_trim_template) found_bolt_trim = true;
            if (item == .wind_burst_enchanted_book) found_wind_burst = true;
            if (item == .heavy_core) found_heavy_core = true;
        }
    }

    try std.testing.expect(found_flow_trim);
    try std.testing.expect(found_bolt_trim);
    try std.testing.expect(found_wind_burst);
    try std.testing.expect(found_heavy_core);
}

test "8. Heavy core 2.2 percent roll threshold boundaries are exact" {
    try std.testing.expect(rollHeavyCoreDirect(0));
    try std.testing.expect(rollHeavyCoreDirect(21));
    try std.testing.expect(!rollHeavyCoreDirect(22));
    try std.testing.expect(!rollHeavyCoreDirect(23));
    try std.testing.expect(!rollHeavyCoreDirect(999));
    try std.testing.expectEqual(@as(u32, 22), HEAVY_CORE_CHANCE_PER_MILLE);
}

test "9. Heavy core rolls at approximately 2.2 percent over large sample" {
    var rng_state: u32 = 12345;
    var heavy_core_count: u32 = 0;
    const trials: u32 = 10_000;
    var i: u32 = 0;
    while (i < trials) : (i += 1) {
        if (rollHeavyCore(&rng_state)) heavy_core_count += 1;
    }
    // 2.2% of 10,000 is 220; expect within reasonable sampling bounds [160, 280]
    try std.testing.expect(heavy_core_count >= 160 and heavy_core_count <= 280);
}

test "10. Multi-player party members independently unlock the same vault" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var p1_inv = Inventory{};
    p1_inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    var p2_inv = Inventory{};
    p2_inv.slots[0] = .{ .item = .trial_key, .count = 1 };

    // P1 unlocks
    const res1 = vault.interact(1, &p1_inv, 100);
    try std.testing.expectEqual(InteractionResult.started_ejection, res1.interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(!vault.hasPlayerUnlocked(2));

    // P2 cannot unlock while vault is ejecting for P1
    const res2_busy = vault.interact(2, &p2_inv, 200);
    try std.testing.expectEqual(InteractionResult.busy, res2_busy.interaction);
    try std.testing.expectEqual(@as(u32, 1), p2_inv.count(.trial_key));

    // Finish 40-tick ejection
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();
    try std.testing.expectEqual(VaultState.unlocked, vault.state);

    // Now P2 can independently unlock
    const res2 = vault.interact(2, &p2_inv, 200);
    try std.testing.expectEqual(InteractionResult.started_ejection, res2.interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(vault.hasPlayerUnlocked(2));
    try std.testing.expectEqual(@as(u32, 0), p2_inv.count(.trial_key));
}

test "11. Per-player tracking maintains multiple player IDs accurately" {
    var vault = Vault.init(.ominous, .{ 10, 20, 30 });
    const player_ids = [_]u32{ 7, 42, 101, 256, 512 };

    for (player_ids, 0..) |pid, idx| {
        try std.testing.expect(!vault.hasPlayerUnlocked(pid));
        try std.testing.expect(vault.acceptsInteraction(pid));

        var inv = Inventory{};
        inv.slots[0] = .{ .item = .ominous_trial_key, .count = 1 };
        _ = vault.interact(pid, &inv, @as(u32, @intCast(pid)));

        // Advance ejection ticks
        var t: u8 = 0;
        while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();

        try std.testing.expect(vault.hasPlayerUnlocked(pid));
        try std.testing.expectEqual(@as(u8, @intCast(idx + 1)), vault.unlocked_player_count);
    }

    // Verify all players remain recorded
    for (player_ids) |pid| {
        try std.testing.expect(vault.hasPlayerUnlocked(pid));
    }
}

test "12. Already unlocked player is rejected when attempting to unlock again" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 2 };

    _ = vault.interact(1, &inv, 10);
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();

    // Second unlock attempt with trial key
    const res2 = vault.interact(1, &inv, 20);
    try std.testing.expectEqual(InteractionResult.already_unlocked, res2.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.trial_key)); // Key preserved!
}

test "13. Consuming 1 Vault Reset Token clears only that player lock" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    inv.slots[1] = .{ .item = .vault_reset_token, .count = 2 };

    _ = vault.interact(1, &inv, 1);
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();
    try std.testing.expect(vault.hasPlayerUnlocked(1));

    // Reset lock
    const res = vault.interact(1, &inv, 2);
    try std.testing.expectEqual(InteractionResult.reset, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.vault_reset_token)); // 1 consumed
    try std.testing.expect(!vault.hasPlayerUnlocked(1)); // Lock cleared!
    try std.testing.expectEqual(@as(u8, 0), vault.unlocked_player_count);
}

test "14. Reset token cannot reset an unlocked player who lacks a token" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };

    _ = vault.interact(1, &inv, 1);
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();

    var empty_inv = Inventory{};
    const res = vault.interact(1, &empty_inv, 2);
    try std.testing.expectEqual(InteractionResult.already_unlocked, res.interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
}

test "15. Reset token is not consumed if player has not yet unlocked the vault" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .vault_reset_token, .count = 1 };

    const res = vault.interact(1, &inv, 10);
    try std.testing.expectEqual(InteractionResult.wrong_item, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.vault_reset_token));
    try std.testing.expect(!vault.hasPlayerUnlocked(1));
}

test "16. Reset token is not consumed while vault is busy ejecting" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv1 = Inventory{};
    inv1.slots[0] = .{ .item = .trial_key, .count = 1 };
    inv1.slots[1] = .{ .item = .vault_reset_token, .count = 1 };

    _ = vault.interact(1, &inv1, 1);
    // Vault is in ejecting state!
    try std.testing.expectEqual(VaultState.ejecting, vault.state);

    const res = vault.interact(1, &inv1, 2);
    try std.testing.expectEqual(InteractionResult.busy, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv1.count(.vault_reset_token));
}

test "17. Resetting player lock allows unlocking the vault again" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 2 };
    inv.slots[1] = .{ .item = .vault_reset_token, .count = 1 };

    // First unlock
    const res1 = vault.interact(1, &inv, 1);
    try std.testing.expectEqual(InteractionResult.started_ejection, res1.interaction);
    var t: u8 = 0;
    while (t < EJECTION_TICKS) : (t += 1) _ = vault.tick();

    // Reset lock
    const res_reset = vault.interact(1, &inv, 2);
    try std.testing.expectEqual(InteractionResult.reset, res_reset.interaction);
    try std.testing.expect(!vault.hasPlayerUnlocked(1));

    // Second unlock succeeds!
    const res2 = vault.interact(1, &inv, 3);
    try std.testing.expectEqual(InteractionResult.started_ejection, res2.interaction);
    try std.testing.expectEqual(@as(u32, 0), inv.count(.trial_key));
    try std.testing.expect(vault.hasPlayerUnlocked(1));
}

test "18. resetPlayerLock preserves other players locks and order" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 10;
    vault.unlocked_players[1] = 20;
    vault.unlocked_players[2] = 30;
    vault.unlocked_player_count = 3;

    try std.testing.expect(vault.resetPlayerLock(20));
    try std.testing.expectEqual(@as(u8, 2), vault.unlocked_player_count);
    try std.testing.expect(vault.hasPlayerUnlocked(10));
    try std.testing.expect(!vault.hasPlayerUnlocked(20));
    try std.testing.expect(vault.hasPlayerUnlocked(30));
    try std.testing.expectEqual(@as(u32, 10), vault.unlocked_players[0]);
    try std.testing.expectEqual(@as(u32, 30), vault.unlocked_players[1]);
}

test "19. resetPlayerLock returns false for non-locked player IDs" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(!vault.resetPlayerLock(999));
    try std.testing.expect(!vault.resetPlayerLock(0));
}

test "20. Vault rejects player when capacity is reached without consuming key" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var i: u32 = 0;
    while (i < MAX_UNLOCKED_PLAYERS) : (i += 1) {
        vault.unlocked_players[i] = i + 1;
    }
    vault.unlocked_player_count = MAX_UNLOCKED_PLAYERS;

    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    const res = vault.interact(100, &inv, 5);
    try std.testing.expectEqual(InteractionResult.player_limit, res.interaction);
    try std.testing.expectEqual(@as(u32, 1), inv.count(.trial_key));
}

test "21. Resetting a player at capacity frees one slot" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var i: u32 = 0;
    while (i < MAX_UNLOCKED_PLAYERS) : (i += 1) {
        vault.unlocked_players[i] = i + 1;
    }
    vault.unlocked_player_count = MAX_UNLOCKED_PLAYERS;
    vault.state = .unlocked;

    var inv = Inventory{};
    inv.slots[0] = .{ .item = .vault_reset_token, .count = 1 };
    const res_reset = vault.interact(5, &inv, 1);
    try std.testing.expectEqual(InteractionResult.reset, res_reset.interaction);
    try std.testing.expectEqual(@as(u8, MAX_UNLOCKED_PLAYERS - 1), vault.unlocked_player_count);

    var new_player_inv = Inventory{};
    new_player_inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    const res_unlock = vault.interact(100, &new_player_inv, 2);
    try std.testing.expectEqual(InteractionResult.started_ejection, res_unlock.interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(100));
}

test "22. Ejection item count is strictly between three and six items" {
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const std_loot = generateLoot(.standard, seed, .{ 0, 0, 0 });
        try std.testing.expect(std_loot.count >= MIN_LOOT_ITEMS and std_loot.count <= MAX_LOOT_ITEMS);

        const omn_loot = generateLoot(.ominous, seed, .{ 0, 0, 0 });
        try std.testing.expect(omn_loot.count >= MIN_LOOT_ITEMS and omn_loot.count <= MAX_LOOT_ITEMS);
    }
}

test "23. All ejected upward velocities stay within specified bounds [0.35, 0.55]" {
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const loot = generateLoot(.standard, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const vy = maybe_item.?.velocity[1];
            try std.testing.expect(vy >= MIN_UPWARD_VELOCITY);
            try std.testing.expect(vy <= MAX_UPWARD_VELOCITY);
        }
    }
}

test "24. Horizontal velocity is radial and matches dispersion angle" {
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const loot = generateLoot(.ominous, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?;
            const vx = item.velocity[0];
            const vz = item.velocity[2];
            const h_speed = std.math.sqrt(vx * vx + vz * vz);

            try std.testing.expect(h_speed >= MIN_HORIZONTAL_SPEED - 0.001);
            try std.testing.expect(h_speed <= MAX_HORIZONTAL_SPEED + 0.001);

            const expected_vx = @cos(item.dispersion_angle) * h_speed;
            const expected_vz = @sin(item.dispersion_angle) * h_speed;
            try std.testing.expectApproxEqAbs(expected_vx, vx, 0.001);
            try std.testing.expectApproxEqAbs(expected_vz, vz, 0.001);
        }
    }
}

test "25. Radial angles cover full circular range [0, 2*pi]" {
    var quadrant_covered = [_]bool{ false, false, false, false };
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const loot = generateLoot(.standard, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const angle = maybe_item.?.dispersion_angle;
            if (angle >= 0.0 and angle < 0.5 * std.math.pi) quadrant_covered[0] = true;
            if (angle >= 0.5 * std.math.pi and angle < std.math.pi) quadrant_covered[1] = true;
            if (angle >= std.math.pi and angle < 1.5 * std.math.pi) quadrant_covered[2] = true;
            if (angle >= 1.5 * std.math.pi and angle < TAU) quadrant_covered[3] = true;
        }
    }
    for (quadrant_covered) |covered| {
        try std.testing.expect(covered);
    }
}

test "26. Ejection positions spawn at vault center plus one meter launch height" {
    const vault_pos = [3]f32{ 15.0, 60.0, -25.0 };
    const loot = generateLoot(.standard, 888, vault_pos);
    const expected_pos = [3]f32{ 15.5, 61.0, -24.5 };
    for (loot.items[0..loot.count]) |maybe_item| {
        try std.testing.expectEqual(expected_pos, maybe_item.?.position);
    }
}

test "27. Loot generation is strictly deterministic for identical seeds" {
    const l1 = generateLoot(.ominous, 7777, .{ 1, 2, 3 });
    const l2 = generateLoot(.ominous, 7777, .{ 1, 2, 3 });
    try std.testing.expectEqual(l1.count, l2.count);
    var i: usize = 0;
    while (i < l1.count) : (i += 1) {
        try std.testing.expectEqual(l1.items[i].?.item, l2.items[i].?.item);
        try std.testing.expectEqual(l1.items[i].?.count, l2.items[i].?.count);
        try std.testing.expectEqual(l1.items[i].?.velocity, l2.items[i].?.velocity);
        try std.testing.expectEqual(l1.items[i].?.dispersion_angle, l2.items[i].?.dispersion_angle);
    }
}

test "28. Animated spinning loot showcase is visible only to eligible players" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(vault.displayItemVisible(1));
    try std.testing.expect(vault.displayPreview(1) != null);
    try std.testing.expect(vault.emitsAmbientParticles(1));

    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inv, 10);

    // After unlocking, showcase is hidden for player 1 but visible for player 2
    try std.testing.expect(!vault.displayItemVisible(1));
    try std.testing.expect(vault.displayPreview(1) == null);
    try std.testing.expect(!vault.emitsAmbientParticles(1));

    try std.testing.expect(vault.displayItemVisible(2));
    try std.testing.expect(vault.displayPreview(2) != null);
    try std.testing.expect(vault.emitsAmbientParticles(2));
}

test "29. Keyhole is dark for already unlocked players and illuminated for eligible players" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(!vault.keyholeIsDark(1));

    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;

    try std.testing.expect(vault.keyholeIsDark(1));
    try std.testing.expect(!vault.keyholeIsDark(2));
}

test "30. canInsertKey returns true only for eligible players when not ejecting" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(vault.canInsertKey(1));

    vault.state = .ejecting;
    try std.testing.expect(!vault.canInsertKey(1));

    vault.state = .idle;
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    try std.testing.expect(!vault.canInsertKey(1));
    try std.testing.expect(vault.canInsertKey(2));
}

test "31. Comparator outputs fifteen for nearest eligible player and zero after unlock" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    const nearby = [_]PlayerPosition{.{ .player_id = 5, .position = .{ 1, 0, 0 } }};
    try std.testing.expectEqual(COMPARATOR_MAX_SIGNAL, vault.comparatorOutput(&nearby));

    vault.unlocked_players[0] = 5;
    vault.unlocked_player_count = 1;
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutput(&nearby));
}

test "32. Comparator selects nearest player when party members differ in eligibility" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;

    // Player 1 (unlocked) is at distance 1.0, Player 2 (eligible) is at distance 2.0 -> output 0
    const p1_closer = [_]PlayerPosition{
        .{ .player_id = 1, .position = .{ 1, 0, 0 } },
        .{ .player_id = 2, .position = .{ 2, 0, 0 } },
    };
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutput(&p1_closer));

    // Player 2 (eligible) is at distance 1.0, Player 1 (unlocked) is at distance 3.0 -> output 15
    const p2_closer = [_]PlayerPosition{
        .{ .player_id = 1, .position = .{ 3, 0, 0 } },
        .{ .player_id = 2, .position = .{ 1, 0, 0 } },
    };
    try std.testing.expectEqual(COMPARATOR_MAX_SIGNAL, vault.comparatorOutput(&p2_closer));
}

test "33. Comparator outputs zero with no players and handles distance ties deterministically" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutput(&.{}));

    vault.unlocked_players[0] = 3;
    vault.unlocked_player_count = 1;

    const tied = [_]PlayerPosition{
        .{ .player_id = 8, .position = .{ 1, 0, 0 } },
        .{ .player_id = 3, .position = .{ -1, 0, 0 } },
    };
    // Tie at distance 1; lower ID is 3 (unlocked) -> output 0
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutput(&tied));
}

test "34. Comparator bounded radius returns zero when nearest player is outside radius" {
    const vault = Vault.init(.standard, .{ 0, 0, 0 });
    const outside_players = [_]PlayerPosition{.{ .player_id = 1, .position = .{ 5.0, 0, 0 } }};
    try std.testing.expectEqual(COMPARATOR_MIN_SIGNAL, vault.comparatorOutputWithRadius(&outside_players, COMPARATOR_DETECTION_RADIUS));

    const inside_players = [_]PlayerPosition{.{ .player_id = 1, .position = .{ 4.0, 0, 0 } }};
    try std.testing.expectEqual(COMPARATOR_MAX_SIGNAL, vault.comparatorOutputWithRadius(&inside_players, COMPARATOR_DETECTION_RADIUS));
}

test "35. Vault tick advances display ticks and completes ejection in forty ticks" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inv = Inventory{};
    inv.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inv, 12);
    try std.testing.expectEqual(VaultState.ejecting, vault.state);

    var i: u8 = 0;
    while (i < EJECTION_TICKS - 1) : (i += 1) {
        try std.testing.expect(!vault.tick());
    }
    // 40th tick completes ejection
    try std.testing.expect(vault.tick());
    try std.testing.expectEqual(VaultState.unlocked, vault.state);
}

test "36. dropsVaultResetToken awards tokens only for ominous spawners at five percent" {
    try std.testing.expect(dropsVaultResetToken(true, 0));
    try std.testing.expect(dropsVaultResetToken(true, 4));
    try std.testing.expect(!dropsVaultResetToken(true, 5));
    try std.testing.expect(!dropsVaultResetToken(true, 99));

    // Standard spawners never drop reset tokens
    try std.testing.expect(!dropsVaultResetToken(false, 0));
    try std.testing.expect(!dropsVaultResetToken(false, 4));
}

test "37. Item stack counts match rarity rules" {
    var seed: u32 = 1;
    while (seed <= 100) : (seed += 1) {
        const loot = generateLoot(.ominous, seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?;
            if (item.item == .heavy_core) try std.testing.expectEqual(@as(u8, 1), item.count);
            if (item.item == .flow_armor_trim_template) try std.testing.expectEqual(@as(u8, 1), item.count);
            if (item.item == .bolt_armor_trim_template) try std.testing.expectEqual(@as(u8, 1), item.count);
            if (item.item == .wind_burst_enchanted_book) try std.testing.expectEqual(@as(u8, 1), item.count);
        }
    }
}
