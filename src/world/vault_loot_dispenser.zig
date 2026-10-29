const std = @import("std");

/// Item IDs are mirrored here so this world module remains a standalone test target.
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
    ominous_trial_key = 404,
    wind_burst_enchanted_book = 405,
    flow_banner_pattern = 406,
};

pub const VaultType = enum { standard, ominous };
pub const State = enum { idle, ejecting, unlocked };
pub const InteractionResult = enum { started_ejection, already_unlocked, wrong_key, busy };
pub const EJECTION_TICKS: u8 = 40;
pub const COMPARATOR_RADIUS: f32 = 4.5;
pub const COMPARATOR_RADIUS_SQ: f32 = COMPARATOR_RADIUS * COMPARATOR_RADIUS;
pub const MAX_UNLOCKED_PLAYERS: usize = 64;
pub const MAX_EJECTED_STACKS: usize = 6;

pub const ItemStack = struct {
    item: ItemType,
    count: u8 = 1,
};

pub const Inventory = struct {
    slots: [36]?ItemStack = [_]?ItemStack{null} ** 36,

    pub fn count(self: Inventory, item: ItemType) u32 {
        var total: u32 = 0;
        for (self.slots) |slot| if (slot) |stack| {
            if (stack.item == item) total += stack.count;
        };
        return total;
    }

    fn consumeOne(self: *Inventory, item: ItemType) bool {
        for (&self.slots) |*slot| {
            if (slot.*) |*stack| {
                if (stack.item != item or stack.count == 0) continue;
                stack.count -= 1;
                if (stack.count == 0) slot.* = null;
                return true;
            }
        }
        return false;
    }
};

pub const DisplayItem = struct {
    item: ItemType,
    position: [3]f32,
    spin_radians: f32,
};

pub const EjectedStack = struct {
    stack: ItemStack,
    position: [3]f32,
    velocity: [3]f32,
};

pub const UnlockResult = struct {
    interaction: InteractionResult,
    ejected: [MAX_EJECTED_STACKS]?EjectedStack = [_]?EjectedStack{null} ** MAX_EJECTED_STACKS,
    ejected_count: u8 = 0,
};

pub const NearbyPlayer = struct { id: u32, position: [3]f32 };

pub const VaultBlock = struct {
    position: [3]f32,
    vault_type: VaultType = .standard,
    state: State = .idle,
    eject_ticks_remaining: u8 = 0,
    display_ticks: u32 = 0,
    spin_radians: f32 = 0.0,
    display_item: ItemType = .heavy_core,
    unlocked_players: [MAX_UNLOCKED_PLAYERS]u32 = [_]u32{0} ** MAX_UNLOCKED_PLAYERS,
    unlocked_player_count: u8 = 0,
    active_ejector: ?u32 = null,
    last_eject_stacks: [MAX_EJECTED_STACKS]?EjectedStack = [_]?EjectedStack{null} ** MAX_EJECTED_STACKS,
    last_eject_count: u8 = 0,

    pub fn init(vault_type: VaultType, position: [3]f32) VaultBlock {
        return .{ .position = position, .vault_type = vault_type };
    }

    pub fn hasPlayerUnlocked(self: VaultBlock, player_id: u32) bool {
        for (self.unlocked_players[0..self.unlocked_player_count]) |id| {
            if (id == player_id) return true;
        }
        return false;
    }

    pub fn acceptsInteraction(self: VaultBlock, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id) and self.unlocked_player_count < MAX_UNLOCKED_PLAYERS;
    }

    /// A keyhole goes dark only for the player who has already claimed this vault.
    pub fn keyholeIsDark(self: VaultBlock, player_id: u32) bool {
        return self.hasPlayerUnlocked(player_id);
    }

    /// The caged item and ambient sparks are viewer-specific, not global vault state.
    pub fn displayForPlayer(self: VaultBlock, player_id: u32) ?DisplayItem {
        if (self.hasPlayerUnlocked(player_id)) return null;
        const angle = if (self.state == .ejecting) self.spin_radians else @as(f32, @floatFromInt(self.display_ticks % 628)) * 0.01;
        return .{
            .item = self.display_item,
            .position = .{ self.position[0] + 0.5, self.position[1] + 0.65, self.position[2] + 0.5 },
            .spin_radians = angle,
        };
    }

    pub fn emitsAmbientSparks(self: VaultBlock, player_id: u32) bool {
        return self.displayForPlayer(player_id) != null;
    }

    pub fn interact(self: *VaultBlock, player_id: u32, inventory: *Inventory, random_seed: u32) UnlockResult {
        if (self.hasPlayerUnlocked(player_id)) return .{ .interaction = .already_unlocked };
        if (self.unlocked_player_count >= MAX_UNLOCKED_PLAYERS) return .{ .interaction = .already_unlocked };
        if (self.state == .ejecting) return .{ .interaction = .busy };
        const key = requiredKey(self.vault_type);
        if (!inventory.consumeOne(key)) return .{ .interaction = .wrong_key };

        self.unlocked_players[self.unlocked_player_count] = player_id;
        self.unlocked_player_count += 1;
        self.state = .ejecting;
        self.eject_ticks_remaining = EJECTION_TICKS;
        self.spin_radians = 0.0;
        self.active_ejector = player_id;
        const generated = generateLoot(self.vault_type, random_seed, self.position);
        self.last_eject_stacks = generated.stacks;
        self.last_eject_count = generated.count;
        return .{
            .interaction = .started_ejection,
            .ejected = generated.stacks,
            .ejected_count = generated.count,
        };
    }

    /// Advances the 40 tick display spin-down; returns true on the completion tick.
    pub fn tick(self: *VaultBlock) bool {
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

    /// Signal is based on the nearest player in range, including already-unlocked players.
    pub fn comparatorSignal(self: VaultBlock, players: []const NearbyPlayer) u4 {
        var nearest_distance_sq = COMPARATOR_RADIUS_SQ;
        var nearest_id: ?u32 = null;
        for (players) |player| {
            const distance_sq = distanceSquared(self.position, player.position);
            if (distance_sq <= nearest_distance_sq) {
                if (nearest_id == null or distance_sq < nearest_distance_sq or player.id < nearest_id.?) {
                    nearest_distance_sq = distance_sq;
                    nearest_id = player.id;
                }
            }
        }
        const id = nearest_id orelse return 0;
        return if (self.hasPlayerUnlocked(id)) 0 else 15;
    }
};

pub fn requiredKey(vault_type: VaultType) ItemType {
    return if (vault_type == .standard) .trial_key else .ominous_trial_key;
}

fn distanceSquared(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

fn lootPool(vault_type: VaultType) []const ItemType {
    const standard = [_]ItemType{ .heavy_core, .breeze_rod, .diamond, .emerald, .enchanted_golden_apple, .iron_ingot, .bread, .cooked_beef, .baked_potato };
    const ominous = [_]ItemType{ .heavy_core, .flow_armor_trim_template, .bolt_armor_trim_template, .wind_burst_enchanted_book, .flow_banner_pattern, .golden_apple };
    return if (vault_type == .standard) standard[0..] else ominous[0..];
}

const LootGeneration = struct {
    stacks: [MAX_EJECTED_STACKS]?EjectedStack,
    count: u8,
};

fn nextRandom(state: *u32) u32 {
    state.* = state.* *% 1664525 +% 1013904223;
    return state.*;
}

fn generateLoot(vault_type: VaultType, seed: u32, position: [3]f32) LootGeneration {
    var result = LootGeneration{ .stacks = [_]?EjectedStack{null} ** MAX_EJECTED_STACKS, .count = 0 };
    var rng = seed;
    const pool = lootPool(vault_type);
    const standard_pool = pool[1..]; // Heavy Core is selected by its independent 2.2% roll.
    const choices = if (vault_type == .standard) standard_pool else pool;
    const requested: usize = 3 + @as(usize, @intCast(nextRandom(&rng) % 4));
    var item_used: [9]bool = [_]bool{false} ** 9;
    while (result.count < requested) {
        const rare_heavy_core = vault_type == .standard and nextRandom(&rng) % 1000 < 22 and !item_used[0];
        var item_index: usize = if (rare_heavy_core)
            0
        else if (vault_type == .standard)
            1 + @as(usize, @intCast(nextRandom(&rng) % @as(u32, @intCast(choices.len))))
        else
            @intCast(nextRandom(&rng) % @as(u32, @intCast(choices.len)));
        var attempts: usize = 0;
        while (item_used[item_index] and attempts < choices.len) : (attempts += 1) {
            item_index = if (vault_type == .standard and item_index + 1 >= pool.len)
                1
            else
                (item_index + 1) % pool.len;
        }
        if (item_used[item_index]) item_index = if (item_used[0]) 1 else 0;
        item_used[item_index] = true;
        const item = pool[item_index];
        const horizontal_x = @as(f32, @floatFromInt(@as(i32, @intCast(nextRandom(&rng) % 101)) - 50)) / 200.0;
        const horizontal_z = @as(f32, @floatFromInt(@as(i32, @intCast(nextRandom(&rng) % 101)) - 50)) / 200.0;
        const amount: u8 = switch (item) {
            .breeze_rod => 2 + @as(u8, @intCast(nextRandom(&rng) % 3)),
            .diamond, .emerald, .iron_ingot => 2 + @as(u8, @intCast(nextRandom(&rng) % 5)),
            .bread, .cooked_beef, .baked_potato, .golden_apple => 2 + @as(u8, @intCast(nextRandom(&rng) % 4)),
            else => 1,
        };
        result.stacks[result.count] = .{
            .stack = .{ .item = item, .count = amount },
            .position = .{ position[0] + 0.5, position[1] + 1.0, position[2] + 0.5 },
            .velocity = .{ horizontal_x, 0.45, horizontal_z },
        };
        result.count += 1;
    }
    return result;
}

test "vault type selects its required key and pool" {
    try std.testing.expectEqual(ItemType.trial_key, requiredKey(.standard));
    try std.testing.expectEqual(ItemType.ominous_trial_key, requiredKey(.ominous));
    try std.testing.expectEqual(@as(u16, 404), @intFromEnum(ItemType.ominous_trial_key));
    try std.testing.expectEqual(@as(usize, 9), lootPool(.standard).len);
    try std.testing.expectEqual(@as(usize, 6), lootPool(.ominous).len);
}

test "standard vault accepts standard key and consumes exactly one" {
    var vault = VaultBlock.init(.standard, .{ 0, 64, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 2 };
    const result = vault.interact(1, &inventory, 1);
    try std.testing.expectEqual(InteractionResult.started_ejection, result.interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.trial_key));
    try std.testing.expect(vault.hasPlayerUnlocked(1));
}

test "ominous vault accepts ominous key and consumes it" {
    var vault = VaultBlock.init(.ominous, .{ 0, 64, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .ominous_trial_key, .count = 1 };
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(7, &inventory, 3).interaction);
    try std.testing.expectEqual(@as(u32, 0), inventory.count(.ominous_trial_key));
}

test "wrong key variants do not consume inventory" {
    var standard = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var ominous = VaultBlock.init(.ominous, .{ 0, 0, 0 });
    var ominous_key_inventory = Inventory{};
    ominous_key_inventory.slots[0] = .{ .item = .ominous_trial_key, .count = 1 };
    try std.testing.expectEqual(InteractionResult.wrong_key, standard.interact(1, &ominous_key_inventory, 4).interaction);
    var standard_key_inventory = Inventory{};
    standard_key_inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    try std.testing.expectEqual(InteractionResult.wrong_key, ominous.interact(1, &standard_key_inventory, 5).interaction);
    try std.testing.expectEqual(@as(u32, 1), ominous_key_inventory.count(.ominous_trial_key));
    try std.testing.expectEqual(@as(u32, 1), standard_key_inventory.count(.trial_key));
}

test "player unlock tracking is isolated by player ID" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(1, &inventory, 1).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(!vault.hasPlayerUnlocked(2));
    try std.testing.expect(vault.keyholeIsDark(1));
    try std.testing.expect(!vault.keyholeIsDark(2));
    try std.testing.expect(vault.displayForPlayer(1) == null);
    try std.testing.expect(vault.displayForPlayer(2) != null);
}

test "unlocked player is rejected on second interaction" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 2 };
    _ = vault.interact(1, &inventory, 1);
    try std.testing.expectEqual(InteractionResult.already_unlocked, vault.interact(1, &inventory, 2).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.trial_key));
}

test "ambient sparks and floating item show only to eligible player" {
    var vault = VaultBlock.init(.standard, .{ 2, 10, -3 });
    try std.testing.expect(vault.emitsAmbientSparks(2));
    const display = vault.displayForPlayer(2).?;
    try std.testing.expectEqual(ItemType.heavy_core, display.item);
    try std.testing.expectEqual([3]f32{ 2.5, 10.65, -2.5 }, display.position);
    vault.unlocked_players[0] = 2;
    vault.unlocked_player_count = 1;
    try std.testing.expect(!vault.emitsAmbientSparks(2));
    try std.testing.expect(vault.displayForPlayer(2) == null);
    try std.testing.expect(vault.emitsAmbientSparks(3));
}

test "ejection returns three to six distinct stacks with upward velocity" {
    var seed: u32 = 0;
    while (seed < 20) : (seed += 1) {
        const generated = generateLoot(.standard, seed, .{ 4, 8, -2 });
        try std.testing.expect(generated.count >= 3 and generated.count <= 6);
        var i: usize = 0;
        while (i < generated.count) : (i += 1) {
            const stack = generated.stacks[i].?;
            try std.testing.expectEqual(@as(f32, 0.45), stack.velocity[1]);
            try std.testing.expectEqual([3]f32{ 4.5, 9.0, -1.5 }, stack.position);
            var j = i + 1;
            while (j < generated.count) : (j += 1) try std.testing.expect(stack.stack.item != generated.stacks[j].?.stack.item);
        }
    }
}

test "ejection has deterministic horizontal dispersion" {
    const a = generateLoot(.standard, 1, .{ 0, 0, 0 });
    const b = generateLoot(.standard, 2, .{ 0, 0, 0 });
    try std.testing.expect(a.stacks[0].?.velocity[0] != b.stacks[0].?.velocity[0] or a.stacks[0].?.velocity[2] != b.stacks[0].?.velocity[2]);
    for (a.stacks[0..a.count]) |maybe_stack| {
        const velocity = maybe_stack.?.velocity;
        try std.testing.expect(velocity[0] >= -0.25 and velocity[0] <= 0.25);
        try std.testing.expect(velocity[2] >= -0.25 and velocity[2] <= 0.25);
    }
}

test "standard loot includes heavy core with requested rare weight" {
    var heavy_count: usize = 0;
    var stack_count: usize = 0;
    const trials = 20_000;
    var seed: u32 = 0;
    while (seed < trials) : (seed += 1) {
        const generated = generateLoot(.standard, seed, .{ 0, 0, 0 });
        for (generated.stacks[0..generated.count]) |stack| {
            stack_count += 1;
            if (stack.?.stack.item == .heavy_core) heavy_count += 1;
        }
    }
    const observed_rate = @as(f64, @floatFromInt(heavy_count)) / @as(f64, @floatFromInt(stack_count));
    try std.testing.expect(observed_rate > 0.018 and observed_rate < 0.026);
}

test "standard loot items stay within standard pool" {
    const generated = generateLoot(.standard, 123, .{ 0, 0, 0 });
    for (generated.stacks[0..generated.count]) |stack| try std.testing.expect(std.mem.indexOfScalar(ItemType, lootPool(.standard), stack.?.stack.item) != null);
}

test "ominous loot items stay within ominous pool" {
    const generated = generateLoot(.ominous, 456, .{ 0, 0, 0 });
    for (generated.stacks[0..generated.count]) |stack| try std.testing.expect(std.mem.indexOfScalar(ItemType, lootPool(.ominous), stack.?.stack.item) != null);
}

test "comparator gives full signal for nearby eligible player" {
    const vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    const players = [_]NearbyPlayer{.{ .id = 1, .position = .{ 4, 0, 0 } }};
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorSignal(&players));
}

test "comparator gives zero for nearby unlocked player" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 5;
    vault.unlocked_player_count = 1;
    const players = [_]NearbyPlayer{.{ .id = 5, .position = .{ 1, 0, 0 } }};
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorSignal(&players));
}

test "comparator ignores players beyond 4.5 meters" {
    const vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    const players = [_]NearbyPlayer{.{ .id = 1, .position = .{ 4.6, 0, 0 } }};
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorSignal(&players));
}

test "comparator uses nearest player's eligibility" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    const players = [_]NearbyPlayer{
        .{ .id = 1, .position = .{ 1, 0, 0 } },
        .{ .id = 2, .position = .{ 2, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorSignal(&players));
}

test "comparator follows newly nearest eligible player" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    const players = [_]NearbyPlayer{
        .{ .id = 1, .position = .{ 2, 0, 0 } },
        .{ .id = 2, .position = .{ 1, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorSignal(&players));
}

test "state machine advances idle to ejecting to unlocked after forty ticks" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    try std.testing.expectEqual(State.idle, vault.state);
    _ = vault.interact(1, &inventory, 4);
    try std.testing.expectEqual(State.ejecting, vault.state);
    var tick_number: u8 = 0;
    while (tick_number < EJECTION_TICKS - 1) : (tick_number += 1) try std.testing.expect(!vault.tick());
    try std.testing.expectEqual(State.ejecting, vault.state);
    try std.testing.expect(vault.tick());
    try std.testing.expectEqual(State.unlocked, vault.state);
}

test "ejecting vault is busy to other players and does not consume their key" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inv1 = Inventory{};
    var inv2 = Inventory{};
    inv1.slots[0] = .{ .item = .trial_key, .count = 1 };
    inv2.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inv1, 9);
    try std.testing.expectEqual(InteractionResult.busy, vault.interact(2, &inv2, 10).interaction);
    try std.testing.expectEqual(@as(u32, 1), inv2.count(.trial_key));
    try std.testing.expect(!vault.hasPlayerUnlocked(2));
}

test "second player can unlock after current ejection finishes" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var first = Inventory{};
    var second = Inventory{};
    first.slots[0] = .{ .item = .trial_key, .count = 1 };
    second.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &first, 7);
    var i: usize = 0;
    while (i < EJECTION_TICKS) : (i += 1) _ = vault.tick();
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(2, &second, 8).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(vault.hasPlayerUnlocked(2));
}

test "item spin advances and slows through the ejection cycle" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inventory, 11);
    var i: usize = 0;
    while (i < 20) : (i += 1) _ = vault.tick();
    const middle_spin = vault.displayForPlayer(2).?.spin_radians;
    const middle_increment = vault.spin_radians;
    _ = vault.tick();
    const next_increment = vault.spin_radians - middle_increment;
    try std.testing.expect(middle_spin > 0.0);
    try std.testing.expect(next_increment < 0.8);
    try std.testing.expectEqual(@as(u8, 19), vault.eject_ticks_remaining);
}

test "empty inventory rejects interaction" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    try std.testing.expectEqual(InteractionResult.wrong_key, vault.interact(1, &inventory, 0).interaction);
    try std.testing.expectEqual(State.idle, vault.state);
}

test "unlocked tracking supports zero-valued player IDs" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(0, &inventory, 4);
    try std.testing.expect(vault.hasPlayerUnlocked(0));
}

test "display item remains visible to other players during ejection" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inventory, 0);
    try std.testing.expect(vault.displayForPlayer(1) == null);
    try std.testing.expect(vault.displayForPlayer(2) != null);
    try std.testing.expect(vault.emitsAmbientSparks(2));
}

test "completed ejection clears active player and tick is stable" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(9, &inventory, 13);
    var i: usize = 0;
    while (i < EJECTION_TICKS) : (i += 1) _ = vault.tick();
    try std.testing.expect(vault.active_ejector == null);
    try std.testing.expect(!vault.tick());
    try std.testing.expectEqual(State.unlocked, vault.state);
}

test "player at comparator radius boundary is considered nearby" {
    const vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    const players = [_]NearbyPlayer{.{ .id = 42, .position = .{ 0, 0, 4.5 } }};
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorSignal(&players));
}

test "unlocked player list capacity rejects additional keys safely" {
    var vault = VaultBlock.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_player_count = MAX_UNLOCKED_PLAYERS;
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    try std.testing.expect(!vault.acceptsInteraction(999));
    try std.testing.expectEqual(InteractionResult.already_unlocked, vault.interact(999, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.trial_key));
}
