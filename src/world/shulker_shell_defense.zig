const std = @import("std");

/// Numeric identifier matches the project's existing inventory enum.
pub const ItemType = enum(u16) { shulker_shell = 160 };

pub const TELEPORT_RANGE: f32 = 8.0;
pub const TELEPORT_RANGE_SQ: f32 = TELEPORT_RANGE * TELEPORT_RANGE;
pub const TELEPORT_CHANCE: f32 = 0.25;
pub const CLOSED_ARMOR_POINTS: f32 = 20.0;
pub const CLOSED_DAMAGE_REDUCTION: f32 = 0.8;
pub const SHULKER_SHELL_BASE_DROP_CHANCE: f32 = 0.5;
pub const SHULKER_SHELL_LOOTING_BONUS: f32 = 1.0 / 6.0;
pub const SHULKER_EXPERIENCE: u8 = 5;

pub const Direction = enum {
    up,
    down,
    north,
    south,
    east,
    west,

    pub fn offset(self: Direction) [3]i32 {
        return switch (self) {
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
        };
    }
};

pub const BlockPos = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn distanceSquared(self: BlockPos, other: BlockPos) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return dx * dx + dy * dy + dz * dz;
    }
};

pub const DamageKind = enum { melee, arrow, projectile, fire, lava, other };

pub const Shulker = struct {
    attachment: Direction = .down,
    peek_height: f32 = 0.0,

    pub const isImmuneToFire = true;
    pub const isImmuneToLava = true;

    pub fn init(attachment: Direction) Shulker {
        return .{ .attachment = attachment };
    }

    pub fn setPeekHeight(self: *Shulker, height: f32) void {
        self.peek_height = std.math.clamp(height, 0.0, 1.0);
    }

    pub fn isClosed(self: Shulker) bool {
        return self.peek_height == 0.0;
    }

    pub fn armorPoints(self: Shulker) f32 {
        return if (self.isClosed()) CLOSED_ARMOR_POINTS else 0.0;
    }

    pub fn damageReduction(self: Shulker) f32 {
        return if (self.isClosed()) CLOSED_DAMAGE_REDUCTION else 0.0;
    }

    pub fn damageAfterArmor(self: Shulker, damage: f32) f32 {
        return @max(0.0, damage) * (1.0 - self.damageReduction());
    }

    pub fn applyDamage(self: Shulker, kind: DamageKind, damage: f32) DamageResult {
        if (self.isClosed() and (kind == .arrow or kind == .projectile)) {
            return .{ .damage_taken = 0.0, .is_deflected = true };
        }
        if ((kind == .fire and isImmuneToFire) or (kind == .lava and isImmuneToLava)) {
            return .{ .damage_taken = 0.0, .is_deflected = false };
        }
        return .{ .damage_taken = self.damageAfterArmor(damage), .is_deflected = false };
    }
};

pub const DamageResult = struct {
    damage_taken: f32,
    is_deflected: bool,
};

pub const BlockFace = struct {
    position: BlockPos,
    face: Direction,
    is_solid: bool = true,
};

/// Returns true for a roll in [0, 1) that succeeds at the 25% damage teleport chance.
pub fn shouldTeleportAfterDamage(roll: f32) bool {
    return roll >= 0.0 and roll < TELEPORT_CHANCE;
}

/// Selects uniformly from eligible solid faces within 8 blocks, using `selection_roll` in [0, 1).
pub fn chooseTeleportFace(origin: BlockPos, candidates: []const BlockFace, selection_roll: f32) ?BlockFace {
    if (!(selection_roll >= 0.0 and selection_roll < 1.0)) return null;
    var eligible_count: usize = 0;
    for (candidates) |candidate| {
        if (candidate.is_solid and origin.distanceSquared(candidate.position) <= TELEPORT_RANGE_SQ) {
            eligible_count += 1;
        }
    }
    if (eligible_count == 0) return null;

    const selected_index = @min(@as(usize, @intFromFloat(selection_roll * @as(f32, @floatFromInt(eligible_count)))), eligible_count - 1);
    var eligible_index: usize = 0;
    for (candidates) |candidate| {
        if (!candidate.is_solid or origin.distanceSquared(candidate.position) > TELEPORT_RANGE_SQ) continue;
        if (eligible_index == selected_index) return candidate;
        eligible_index += 1;
    }
    return null;
}

pub const TeleportResult = struct {
    teleported: bool = false,
    destination: ?BlockFace = null,
};

/// Applies the damage-triggered chance, then picks an eligible face if one exists.
pub fn teleportReaction(roll: f32, selection_roll: f32, origin: BlockPos, candidates: []const BlockFace) TeleportResult {
    if (!shouldTeleportAfterDamage(roll)) return .{};
    const destination = chooseTeleportFace(origin, candidates, selection_roll) orelse return .{};
    return .{ .teleported = true, .destination = destination };
}

pub fn shulkerShellDropChance(looting_level: u8) f32 {
    return @min(1.0, SHULKER_SHELL_BASE_DROP_CHANCE + SHULKER_SHELL_LOOTING_BONUS * @as(f32, @floatFromInt(looting_level)));
}

pub const DefeatDrops = struct {
    item: ItemType = .shulker_shell,
    shell_count: u8 = 0,
    experience: u8 = SHULKER_EXPERIENCE,
};

/// The shell roll is in [0, 1); Looting levels above III use the capped 100% chance.
pub fn rollDefeatDrops(shell_roll: f32, looting_level: u8) DefeatDrops {
    const chance = shulkerShellDropChance(looting_level);
    return .{
        .shell_count = if (shell_roll >= 0.0 and shell_roll < chance) 1 else 0,
    };
}

test "all six cardinal faces can be attachment orientations" {
    const faces = [_]Direction{ .up, .down, .north, .south, .east, .west };
    for (faces) |face| try std.testing.expectEqual(face, Shulker.init(face).attachment);
}

test "each face has a distinct cardinal support offset" {
    try std.testing.expectEqual([3]i32{ 0, 1, 0 }, Direction.up.offset());
    try std.testing.expectEqual([3]i32{ 0, -1, 0 }, Direction.down.offset());
    try std.testing.expectEqual([3]i32{ 0, 0, -1 }, Direction.north.offset());
    try std.testing.expectEqual([3]i32{ 0, 0, 1 }, Direction.south.offset());
    try std.testing.expectEqual([3]i32{ 1, 0, 0 }, Direction.east.offset());
    try std.testing.expectEqual([3]i32{ -1, 0, 0 }, Direction.west.offset());
}

test "default peek height is closed" {
    const shulker = Shulker{};
    try std.testing.expectEqual(@as(f32, 0.0), shulker.peek_height);
    try std.testing.expect(shulker.isClosed());
}

test "peek height zero remains closed" {
    var shulker = Shulker{};
    shulker.setPeekHeight(0.0);
    try std.testing.expect(shulker.isClosed());
}

test "any positive peek height opens the shell" {
    var shulker = Shulker{};
    shulker.setPeekHeight(0.001);
    try std.testing.expect(!shulker.isClosed());
}

test "peek height can be fully open" {
    var shulker = Shulker{};
    shulker.setPeekHeight(1.0);
    try std.testing.expectEqual(@as(f32, 1.0), shulker.peek_height);
}

test "peek height clamps below zero" {
    var shulker = Shulker{};
    shulker.setPeekHeight(-1.0);
    try std.testing.expectEqual(@as(f32, 0.0), shulker.peek_height);
}

test "peek height clamps above one" {
    var shulker = Shulker{};
    shulker.setPeekHeight(2.0);
    try std.testing.expectEqual(@as(f32, 1.0), shulker.peek_height);
}

test "closed shell has twenty armor points" {
    try std.testing.expectEqual(CLOSED_ARMOR_POINTS, (Shulker{}).armorPoints());
}

test "closed shell reduces damage by eighty percent" {
    try std.testing.expectEqual(@as(f32, 0.8), (Shulker{}).damageReduction());
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), (Shulker{}).damageAfterArmor(10.0), 0.0001);
}

test "closed shell damage cannot become negative" {
    try std.testing.expectEqual(@as(f32, 0.0), (Shulker{}).damageAfterArmor(-5.0));
}

test "peeking shell has zero armor" {
    var shulker = Shulker{};
    shulker.setPeekHeight(0.5);
    try std.testing.expectEqual(@as(f32, 0.0), shulker.armorPoints());
}

test "peeking shell takes full melee damage" {
    var shulker = Shulker{};
    shulker.setPeekHeight(0.25);
    const result = shulker.applyDamage(.melee, 7.0);
    try std.testing.expectEqual(@as(f32, 7.0), result.damage_taken);
    try std.testing.expect(!result.is_deflected);
}

test "fully open shell takes full melee damage" {
    var shulker = Shulker{};
    shulker.setPeekHeight(1.0);
    try std.testing.expectEqual(@as(f32, 4.0), shulker.applyDamage(.melee, 4.0).damage_taken);
}

test "closed shell deflects arrows with zero damage" {
    const result = (Shulker{}).applyDamage(.arrow, 20.0);
    try std.testing.expect(result.is_deflected);
    try std.testing.expectEqual(@as(f32, 0.0), result.damage_taken);
}

test "closed shell deflects other projectiles with zero damage" {
    const result = (Shulker{}).applyDamage(.projectile, 9.0);
    try std.testing.expect(result.is_deflected);
    try std.testing.expectEqual(@as(f32, 0.0), result.damage_taken);
}

test "peeking shell receives arrow damage normally" {
    var shulker = Shulker{};
    shulker.setPeekHeight(0.1);
    const result = shulker.applyDamage(.arrow, 6.0);
    try std.testing.expect(!result.is_deflected);
    try std.testing.expectEqual(@as(f32, 6.0), result.damage_taken);
}

test "open shell receives projectile damage normally" {
    var shulker = Shulker{};
    shulker.setPeekHeight(1.0);
    const result = shulker.applyDamage(.projectile, 8.0);
    try std.testing.expect(!result.is_deflected);
    try std.testing.expectEqual(@as(f32, 8.0), result.damage_taken);
}

test "shulker is fire immune" {
    try std.testing.expect(Shulker.isImmuneToFire);
    try std.testing.expectEqual(@as(f32, 0.0), (Shulker{}).applyDamage(.fire, 12.0).damage_taken);
}

test "shulker is lava immune" {
    try std.testing.expect(Shulker.isImmuneToLava);
    try std.testing.expectEqual(@as(f32, 0.0), (Shulker{}).applyDamage(.lava, 20.0).damage_taken);
}

test "teleport chance is exactly one quarter of unit interval" {
    try std.testing.expect(shouldTeleportAfterDamage(0.0));
    try std.testing.expect(shouldTeleportAfterDamage(0.2499));
    try std.testing.expect(!shouldTeleportAfterDamage(0.25));
    try std.testing.expect(!shouldTeleportAfterDamage(0.9999));
}

test "teleport rejects rolls outside the unit interval" {
    try std.testing.expect(!shouldTeleportAfterDamage(-0.01));
    try std.testing.expect(!shouldTeleportAfterDamage(1.0));
}

test "eligible teleport face can be selected at origin" {
    const candidates = [_]BlockFace{.{ .position = .{}, .face = .north }};
    try std.testing.expectEqual(Direction.north, chooseTeleportFace(.{}, &candidates, 0.0).?.face);
}

test "teleport face exactly eight blocks away is eligible" {
    const candidates = [_]BlockFace{.{ .position = .{ .x = 8.0 }, .face = .east }};
    try std.testing.expect(chooseTeleportFace(.{}, &candidates, 0.0) != null);
}

test "teleport face beyond eight blocks is rejected" {
    const candidates = [_]BlockFace{.{ .position = .{ .x = 8.01 }, .face = .east }};
    try std.testing.expect(chooseTeleportFace(.{}, &candidates, 0.0) == null);
}

test "teleport range uses three dimensional distance" {
    const candidates = [_]BlockFace{.{ .position = .{ .x = 6.0, .y = 6.0 }, .face = .up }};
    try std.testing.expect(chooseTeleportFace(.{}, &candidates, 0.0) == null);
}

test "teleport ignores non-solid faces" {
    const candidates = [_]BlockFace{.{ .position = .{ .x = 1.0 }, .face = .west, .is_solid = false }};
    try std.testing.expect(chooseTeleportFace(.{}, &candidates, 0.0) == null);
}

test "teleport selects uniformly indexed eligible faces" {
    const candidates = [_]BlockFace{
        .{ .position = .{ .x = 1.0 }, .face = .north },
        .{ .position = .{ .x = 2.0 }, .face = .south },
        .{ .position = .{ .x = 9.0 }, .face = .up },
    };
    try std.testing.expectEqual(Direction.north, chooseTeleportFace(.{}, &candidates, 0.0).?.face);
    try std.testing.expectEqual(Direction.south, chooseTeleportFace(.{}, &candidates, 0.75).?.face);
}

test "damage teleport reaction requires chance and valid destination" {
    const candidates = [_]BlockFace{.{ .position = .{ .z = 3.0 }, .face = .south }};
    try std.testing.expect(teleportReaction(0.1, 0.5, .{}, &candidates).teleported);
    try std.testing.expect(!teleportReaction(0.3, 0.5, .{}, &candidates).teleported);
}

test "damage teleport reaction stays put if no solid face is nearby" {
    const candidates = [_]BlockFace{.{ .position = .{ .z = 9.0 }, .face = .south }};
    try std.testing.expect(!teleportReaction(0.1, 0.5, .{}, &candidates).teleported);
}

test "one thousand teleport trials demonstrate the 25 percent threshold" {
    var successful: usize = 0;
    for (0..1000) |i| {
        const roll = @as(f32, @floatFromInt(i)) / 1000.0;
        if (shouldTeleportAfterDamage(roll)) successful += 1;
    }
    try std.testing.expectEqual(@as(usize, 250), successful);
}

test "base shulker shell drop chance is fifty percent" {
    try std.testing.expectEqual(@as(f32, 0.5), shulkerShellDropChance(0));
}

test "Looting increases shell chance by one sixth per level" {
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 3.0), shulkerShellDropChance(1), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0 / 6.0), shulkerShellDropChance(2), 0.0001);
}

test "Looting three guarantees a shell drop" {
    try std.testing.expectEqual(@as(f32, 1.0), shulkerShellDropChance(3));
    try std.testing.expectEqual(@as(u8, 1), rollDefeatDrops(0.9999, 3).shell_count);
}

test "shell drop chance stays capped at one above Looting three" {
    try std.testing.expectEqual(@as(f32, 1.0), shulkerShellDropChance(10));
}

test "shell drop roll produces zero or one shulker shell" {
    const missed = rollDefeatDrops(0.5, 0);
    const dropped = rollDefeatDrops(0.499, 0);
    try std.testing.expectEqual(@as(u8, 0), missed.shell_count);
    try std.testing.expectEqual(@as(u8, 1), dropped.shell_count);
    try std.testing.expectEqual(ItemType.shulker_shell, dropped.item);
}

test "defeat grants five experience regardless of shell roll" {
    try std.testing.expectEqual(@as(u8, 5), rollDefeatDrops(0.99, 0).experience);
}

test "shell drop frequency matches the base half chance" {
    var dropped: usize = 0;
    for (0..1000) |i| {
        const roll = @as(f32, @floatFromInt(i)) / 1000.0;
        if (rollDefeatDrops(roll, 0).shell_count == 1) dropped += 1;
    }
    try std.testing.expectEqual(@as(usize, 500), dropped);
}

test "shell drop frequency reaches certainty at Looting three" {
    var dropped: usize = 0;
    for (0..1000) |i| {
        const roll = @as(f32, @floatFromInt(i)) / 1000.0;
        if (rollDefeatDrops(roll, 3).shell_count == 1) dropped += 1;
    }
    try std.testing.expectEqual(@as(usize, 1000), dropped);
}
