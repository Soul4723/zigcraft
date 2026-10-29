const std = @import("std");

/// Item IDs are mirrored here so this module stays an isolated test target.
pub const ItemType = enum(u16) {
    trial_key = 376,
    ominous_trial_key = 416,
    vault_reset_token = 608,
    heavy_core = 373,
    emerald = 273,
    diamond = 217,
    golden_apple = 30,
};

pub const VaultType = enum { standard, ominous };
pub const VaultState = enum { idle, ejecting, unlocked };
pub const InteractionResult = enum { started_ejection, reset, already_unlocked, wrong_item, busy, player_limit };
pub const EJECTION_TICKS: u8 = 40;
pub const RESET_TOKEN_DROP_PERCENT: u8 = 5;
pub const MIN_LOOT_ITEMS: usize = 3;
pub const MAX_LOOT_ITEMS: usize = 6;
pub const MIN_UPWARD_VELOCITY: f32 = 0.35;
pub const MAX_UPWARD_VELOCITY: f32 = 0.55;
pub const MAX_UNLOCKED_PLAYERS: usize = 64;
const TAU: f32 = 2.0 * std.math.pi;

pub const Stack = struct { item: ItemType, count: u8 = 1 };
pub const Inventory = struct {
    slots: [36]?Stack = [_]?Stack{null} ** 36,

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

pub const EjectedItem = struct {
    item: ItemType,
    position: [3]f32,
    velocity: [3]f32,
    dispersion_angle: f32,
};

pub const DisplayPreview = struct { item: ItemType, spin_radians: f32 };

pub const UnlockResult = struct {
    interaction: InteractionResult,
    ejected: [MAX_LOOT_ITEMS]?EjectedItem = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS,
    ejected_count: u8 = 0,
};

pub const PlayerPosition = struct { player_id: u32, position: [3]f32 };

pub const Vault = struct {
    position: [3]f32,
    vault_type: VaultType = .standard,
    state: VaultState = .idle,
    unlocked_players: [MAX_UNLOCKED_PLAYERS]u32 = [_]u32{0} ** MAX_UNLOCKED_PLAYERS,
    unlocked_player_count: u8 = 0,
    eject_ticks_remaining: u8 = 0,
    display_ticks: u32 = 0,

    pub fn init(vault_type: VaultType, position: [3]f32) Vault {
        return .{ .position = position, .vault_type = vault_type };
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

    pub fn resetPlayerLock(self: *Vault, player_id: u32) bool {
        for (self.unlocked_players[0..self.unlocked_player_count], 0..) |id, index| {
            if (id != player_id) continue;
            var i = index;
            while (i + 1 < self.unlocked_player_count) : (i += 1) {
                self.unlocked_players[i] = self.unlocked_players[i + 1];
            }
            self.unlocked_player_count -= 1;
            return true;
        }
        return false;
    }

    pub fn displayItemVisible(self: Vault, player_id: u32) bool {
        return !self.hasPlayerUnlocked(player_id);
    }

    pub fn displayPreview(self: Vault, player_id: u32) ?DisplayPreview {
        if (!self.displayItemVisible(player_id)) return null;
        return .{ .item = .heavy_core, .spin_radians = @as(f32, @floatFromInt(self.display_ticks % 628)) * 0.01 };
    }

    pub fn interact(self: *Vault, player_id: u32, inventory: *Inventory, seed: u32) UnlockResult {
        if (self.hasPlayerUnlocked(player_id)) {
            if (self.state != .unlocked) return .{ .interaction = .busy };
            if (!inventory.consumeOne(.vault_reset_token)) return .{ .interaction = .already_unlocked };
            _ = self.resetPlayerLock(player_id);
            return .{ .interaction = .reset };
        }
        if (self.unlocked_player_count >= MAX_UNLOCKED_PLAYERS) return .{ .interaction = .player_limit };
        if (self.state == .ejecting) return .{ .interaction = .busy };

        if (!inventory.consumeOne(requiredKey(self.vault_type))) return .{ .interaction = .wrong_item };
        self.unlocked_players[self.unlocked_player_count] = player_id;
        self.unlocked_player_count += 1;
        self.state = .ejecting;
        self.eject_ticks_remaining = EJECTION_TICKS;
        const generated = generateLoot(seed, self.position);
        return .{ .interaction = .started_ejection, .ejected = generated.items, .ejected_count = generated.count };
    }

    pub fn tick(self: *Vault) bool {
        self.display_ticks +%= 1;
        if (self.state != .ejecting) return false;
        if (self.eject_ticks_remaining > 0) self.eject_ticks_remaining -= 1;
        if (self.eject_ticks_remaining != 0) return false;
        self.state = .unlocked;
        return true;
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
        const id = nearest_id orelse return 0;
        return if (self.hasPlayerUnlocked(id)) 0 else 15;
    }
};

pub fn requiredKey(vault_type: VaultType) ItemType {
    return if (vault_type == .standard) .trial_key else .ominous_trial_key;
}

/// `roll_percent` is an integer in [0, 99]; only ominous spawners can drop the token.
pub fn dropsVaultResetToken(ominous: bool, roll_percent: u8) bool {
    return ominous and roll_percent < RESET_TOKEN_DROP_PERCENT;
}

const Loot = struct { items: [MAX_LOOT_ITEMS]?EjectedItem, count: u8 };

fn nextRandom(state: *u32) u32 {
    state.* = state.* *% 1664525 +% 1013904223;
    return state.*;
}

fn unitRandom(state: *u32) f32 {
    return @as(f32, @floatFromInt(nextRandom(state) >> 8)) / 16_777_216.0;
}

fn generateLoot(seed: u32, position: [3]f32) Loot {
    var result = Loot{ .items = [_]?EjectedItem{null} ** MAX_LOOT_ITEMS, .count = 0 };
    var random_state = seed;
    const item_count: usize = MIN_LOOT_ITEMS + @as(usize, @intCast(nextRandom(&random_state) % 4));
    const pool = [_]ItemType{ .emerald, .diamond, .golden_apple, .heavy_core };
    while (result.count < item_count) {
        const item = pool[nextRandom(&random_state) % pool.len];
        const theta = unitRandom(&random_state) * TAU;
        const horizontal_speed = 0.15 + unitRandom(&random_state) * 0.20;
        const vy = MIN_UPWARD_VELOCITY + unitRandom(&random_state) * (MAX_UPWARD_VELOCITY - MIN_UPWARD_VELOCITY);
        result.items[result.count] = .{
            .item = item,
            .position = .{ position[0] + 0.5, position[1] + 1.0, position[2] + 0.5 },
            .velocity = .{ @cos(theta) * horizontal_speed, vy, @sin(theta) * horizontal_speed },
            .dispersion_angle = theta,
        };
        result.count += 1;
    }
    return result;
}

fn distanceSquared(a: [3]f32, b: [3]f32) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return dx * dx + dy * dy + dz * dz;
}

test "standard and ominous vaults require their matching trial key variants" {
    try std.testing.expectEqual(ItemType.trial_key, requiredKey(.standard));
    try std.testing.expectEqual(ItemType.ominous_trial_key, requiredKey(.ominous));
    var standard = Vault.init(.standard, .{ 0, 0, 0 });
    var wrong = Inventory{};
    wrong.slots[0] = .{ .item = .ominous_trial_key };
    try std.testing.expectEqual(InteractionResult.wrong_item, standard.interact(1, &wrong, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), wrong.count(.ominous_trial_key));
    var ominous = Vault.init(.ominous, .{ 0, 0, 0 });
    var right = Inventory{};
    right.slots[0] = .{ .item = .ominous_trial_key };
    try std.testing.expectEqual(InteractionResult.started_ejection, ominous.interact(1, &right, 0).interaction);
}

test "each party member can independently unlock the same vault" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var first = Inventory{};
    first.slots[0] = .{ .item = .trial_key };
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(1, &first, 1).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
    try std.testing.expect(!vault.hasPlayerUnlocked(2));
    var second = Inventory{};
    second.slots[0] = .{ .item = .trial_key };
    try std.testing.expectEqual(InteractionResult.busy, vault.interact(2, &second, 2).interaction);
    var i: u8 = 0;
    while (i < EJECTION_TICKS) : (i += 1) _ = vault.tick();
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(2, &second, 2).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(1) and vault.hasPlayerUnlocked(2));
}

test "reset token consumes exactly one and clears only that player's lock" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 11;
    vault.unlocked_players[1] = 22;
    vault.unlocked_player_count = 2;
    vault.state = .unlocked;
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .vault_reset_token, .count = 2 };
    try std.testing.expectEqual(InteractionResult.reset, vault.interact(11, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.vault_reset_token));
    try std.testing.expect(!vault.hasPlayerUnlocked(11));
    try std.testing.expect(vault.hasPlayerUnlocked(22));
    try std.testing.expect(vault.displayItemVisible(11));
    try std.testing.expect(!vault.displayItemVisible(22));
}

test "reset token cannot reset an unlocked player without token" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 7;
    vault.unlocked_player_count = 1;
    vault.state = .unlocked;
    var inventory = Inventory{};
    try std.testing.expectEqual(InteractionResult.already_unlocked, vault.interact(7, &inventory, 0).interaction);
    try std.testing.expect(vault.hasPlayerUnlocked(7));
}

test "reset token is not consumed before the vault ejection cycle completes" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 7;
    vault.unlocked_player_count = 1;
    vault.state = .ejecting;
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .vault_reset_token };
    try std.testing.expectEqual(InteractionResult.busy, vault.interact(7, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.vault_reset_token));
    try std.testing.expect(vault.hasPlayerUnlocked(7));
}

test "reset player lock is safe for missing and zero-valued IDs" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 0;
    vault.unlocked_players[1] = 1;
    vault.unlocked_player_count = 2;
    try std.testing.expect(!vault.resetPlayerLock(9));
    try std.testing.expect(vault.resetPlayerLock(0));
    try std.testing.expectEqual(@as(u8, 1), vault.unlocked_player_count);
    try std.testing.expect(vault.hasPlayerUnlocked(1));
}

test "only ominous spawners have a five percent reset token drop" {
    try std.testing.expect(dropsVaultResetToken(true, 0));
    try std.testing.expect(dropsVaultResetToken(true, 4));
    try std.testing.expect(!dropsVaultResetToken(true, 5));
    try std.testing.expect(!dropsVaultResetToken(false, 0));
}

test "ejection loot count is three to six for a broad deterministic seed range" {
    var seed: u32 = 0;
    while (seed < 500) : (seed += 1) {
        const loot = generateLoot(seed, .{ 5, 70, -2 });
        try std.testing.expect(loot.count >= MIN_LOOT_ITEMS and loot.count <= MAX_LOOT_ITEMS);
    }
}

test "all ejected upward velocities stay within specified bounds" {
    var seed: u32 = 0;
    while (seed < 256) : (seed += 1) {
        const loot = generateLoot(seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const item = maybe_item.?;
            try std.testing.expect(item.velocity[1] >= MIN_UPWARD_VELOCITY);
            try std.testing.expect(item.velocity[1] <= MAX_UPWARD_VELOCITY);
        }
    }
}

test "horizontal velocity is radial and matches randomized theta" {
    const loot = generateLoot(12345, .{ 0, 0, 0 });
    for (loot.items[0..loot.count]) |maybe_item| {
        const item = maybe_item.?;
        const speed = @sqrt(item.velocity[0] * item.velocity[0] + item.velocity[2] * item.velocity[2]);
        try std.testing.expect(item.dispersion_angle >= 0.0 and item.dispersion_angle < TAU);
        try std.testing.expect(speed >= 0.15 and speed <= 0.35);
        try std.testing.expectApproxEqAbs(@cos(item.dispersion_angle) * speed, item.velocity[0], 0.00001);
        try std.testing.expectApproxEqAbs(@sin(item.dispersion_angle) * speed, item.velocity[2], 0.00001);
    }
}

test "ejection positions use the vault center and one meter launch height" {
    const loot = generateLoot(7, .{ 5, 70, -2 });
    for (loot.items[0..loot.count]) |maybe_item| try std.testing.expectEqual([3]f32{ 5.5, 71.0, -1.5 }, maybe_item.?.position);
}

test "loot dispersion is deterministic for the same seed" {
    const first = generateLoot(912, .{ 0, 0, 0 });
    const second = generateLoot(912, .{ 0, 0, 0 });
    try std.testing.expectEqual(first.count, second.count);
    for (first.items[0..first.count], second.items[0..second.count]) |a, b| try std.testing.expectEqual(a.?.velocity, b.?.velocity);
}

test "comparator outputs fifteen for nearest eligible player and zero after unlock" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    const nearby = [_]PlayerPosition{.{ .player_id = 2, .position = .{ 1, 0, 0 } }};
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorOutput(&nearby));
    vault.unlocked_players[0] = 2;
    vault.unlocked_player_count = 1;
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorOutput(&nearby));
}

test "comparator follows the nearest player when party members differ in eligibility" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    const players = [_]PlayerPosition{
        .{ .player_id = 1, .position = .{ 1, 0, 0 } },
        .{ .player_id = 2, .position = .{ 2, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorOutput(&players));
}

test "comparator outputs zero with no players and is deterministic on distance ties" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorOutput(&.{}));
    vault.unlocked_players[0] = 3;
    vault.unlocked_player_count = 1;
    const tied = [_]PlayerPosition{
        .{ .player_id = 8, .position = .{ 1, 0, 0 } },
        .{ .player_id = 3, .position = .{ -1, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 0), vault.comparatorOutput(&tied));
}

test "ejection cooldown completes after forty ticks before next party member unlocks" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 1 };
    _ = vault.interact(1, &inventory, 17);
    var i: u8 = 0;
    while (i < EJECTION_TICKS - 1) : (i += 1) try std.testing.expect(!vault.tick());
    try std.testing.expect(vault.tick());
    try std.testing.expectEqual(VaultState.unlocked, vault.state);
}

test "vault rejects a sixty-fifth distinct player without consuming key" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_player_count = @intCast(MAX_UNLOCKED_PLAYERS);
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key };
    try std.testing.expectEqual(InteractionResult.player_limit, vault.interact(999, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.trial_key));
}

test "wrong ominous key does not open a standard vault" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .ominous_trial_key, .count = 2 };
    try std.testing.expectEqual(InteractionResult.wrong_item, vault.interact(3, &inventory, 4).interaction);
    try std.testing.expectEqual(@as(u32, 2), inventory.count(.ominous_trial_key));
    try std.testing.expectEqual(VaultState.idle, vault.state);
}

test "successful standard key interaction consumes one and starts ejection" {
    var vault = Vault.init(.standard, .{ 1, 2, 3 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .trial_key, .count = 3 };
    const result = vault.interact(4, &inventory, 77);
    try std.testing.expectEqual(InteractionResult.started_ejection, result.interaction);
    try std.testing.expectEqual(@as(u32, 2), inventory.count(.trial_key));
    try std.testing.expectEqual(VaultState.ejecting, vault.state);
}

test "an eligible player sees the preview while another player's preview is hidden" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 15;
    vault.unlocked_player_count = 1;
    try std.testing.expect(!vault.displayItemVisible(15));
    try std.testing.expect(vault.displayItemVisible(16));
    try std.testing.expect(vault.displayPreview(16) != null);
    try std.testing.expect(vault.displayPreview(15) == null);
}

test "reset token on a player without a lock is not consumed" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var inventory = Inventory{};
    inventory.slots[0] = .{ .item = .vault_reset_token };
    try std.testing.expectEqual(InteractionResult.wrong_item, vault.interact(1, &inventory, 0).interaction);
    try std.testing.expectEqual(@as(u32, 1), inventory.count(.vault_reset_token));
}

test "resetting a player permits another key unlock after current ejection finishes" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    var first = Inventory{};
    first.slots[0] = .{ .item = .trial_key };
    _ = vault.interact(7, &first, 1);
    var i: u8 = 0;
    while (i < EJECTION_TICKS) : (i += 1) _ = vault.tick();
    var reset = Inventory{};
    reset.slots[0] = .{ .item = .vault_reset_token };
    try std.testing.expectEqual(InteractionResult.reset, vault.interact(7, &reset, 2).interaction);
    var second_key = Inventory{};
    second_key.slots[0] = .{ .item = .trial_key };
    try std.testing.expectEqual(InteractionResult.started_ejection, vault.interact(7, &second_key, 3).interaction);
}

test "removing a lock at capacity frees one player slot" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_player_count = @intCast(MAX_UNLOCKED_PLAYERS);
    vault.unlocked_players[0] = 9;
    vault.state = .unlocked;
    var reset = Inventory{};
    reset.slots[0] = .{ .item = .vault_reset_token };
    try std.testing.expectEqual(InteractionResult.reset, vault.interact(9, &reset, 0).interaction);
    try std.testing.expect(vault.acceptsInteraction(999));
}

test "reset token drop boundary is inclusive at four percent and exclusive at five" {
    try std.testing.expect(dropsVaultResetToken(true, RESET_TOKEN_DROP_PERCENT - 1));
    try std.testing.expect(!dropsVaultResetToken(true, RESET_TOKEN_DROP_PERCENT));
    try std.testing.expect(!dropsVaultResetToken(false, RESET_TOKEN_DROP_PERCENT - 1));
}

test "ejected loot count is not coupled to party size" {
    const one = generateLoot(89, .{ 0, 0, 0 });
    const another_seed = generateLoot(90, .{ 0, 0, 0 });
    try std.testing.expect(one.count >= 3 and one.count <= 6);
    try std.testing.expect(another_seed.count >= 3 and another_seed.count <= 6);
}

test "randomized ejection angles cover the full circle" {
    var quadrants = [_]bool{false} ** 4;
    var seed: u32 = 0;
    while (seed < 64) : (seed += 1) {
        const loot = generateLoot(seed, .{ 0, 0, 0 });
        for (loot.items[0..loot.count]) |maybe_item| {
            const theta = maybe_item.?.dispersion_angle;
            const quadrant: usize = @intFromFloat(theta / (TAU / 4.0));
            quadrants[@min(quadrant, 3)] = true;
        }
    }
    for (quadrants) |seen| try std.testing.expect(seen);
}

test "ejected items have nonzero horizontal radial speed" {
    const loot = generateLoot(0xfeedbeef, .{ 0, 0, 0 });
    for (loot.items[0..loot.count]) |maybe_item| {
        const item = maybe_item.?;
        try std.testing.expect(item.velocity[0] != 0.0 or item.velocity[2] != 0.0);
    }
}

test "ejecting state rejects other players without consuming their key" {
    var vault = Vault.init(.ominous, .{ 0, 0, 0 });
    var first = Inventory{};
    first.slots[0] = .{ .item = .ominous_trial_key };
    _ = vault.interact(1, &first, 2);
    var second = Inventory{};
    second.slots[0] = .{ .item = .ominous_trial_key };
    try std.testing.expectEqual(InteractionResult.busy, vault.interact(2, &second, 3).interaction);
    try std.testing.expectEqual(@as(u32, 1), second.count(.ominous_trial_key));
}

test "comparator chooses closest eligible player over farther unlocked player" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    vault.unlocked_players[0] = 1;
    vault.unlocked_player_count = 1;
    const players = [_]PlayerPosition{
        .{ .player_id = 1, .position = .{ 3, 0, 0 } },
        .{ .player_id = 2, .position = .{ 1, 0, 0 } },
    };
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorOutput(&players));
}

test "comparator handles players at the vault position" {
    const vault = Vault.init(.standard, .{ 4, 5, 6 });
    const players = [_]PlayerPosition{.{ .player_id = 1, .position = .{ 4, 5, 6 } }};
    try std.testing.expectEqual(@as(u4, 15), vault.comparatorOutput(&players));
}

test "idle tick advances preview time without changing state" {
    var vault = Vault.init(.standard, .{ 0, 0, 0 });
    try std.testing.expect(!vault.tick());
    try std.testing.expectEqual(@as(u32, 1), vault.display_ticks);
    try std.testing.expectEqual(VaultState.idle, vault.state);
}
