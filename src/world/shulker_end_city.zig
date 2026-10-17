const std = @import("std");

pub const shulker_closed_armor_points: f32 = 20.0;
pub const shulker_open_armor_points: f32 = 0.0;
pub const shulker_bullet_damage: f32 = 4.0;
pub const levitation_duration_seconds: f32 = 10.0;
pub const levitation_upward_velocity: f32 = 0.9;
pub const shulker_box_slot_count: usize = 27;
pub const shulker_duplication_nearby_limit: u8 = 5;

pub const ShulkerPeekState = enum {
    closed_shell,
    peeking,
    open_firing,
};

/// Closed and transitional shells retain full armor; the firing opening exposes
/// the Shulker with no armor.
pub fn armorPoints(state: ShulkerPeekState) f32 {
    return if (state == .open_firing) shulker_open_armor_points else shulker_closed_armor_points;
}

/// The simplified armor model used here applies the requested 80% reduction
/// while the shell is closed or peeking.
pub fn meleeDamageReduction(state: ShulkerPeekState) f32 {
    return if (armorPoints(state) == shulker_closed_armor_points) 0.8 else 0.0;
}

pub fn applyMeleeDamage(state: ShulkerPeekState, damage: f32) f32 {
    return @max(0.0, damage) * (1.0 - meleeDamageReduction(state));
}

/// Closed-shell Shulkers deflect all projectile hits, including arrows.
pub fn deflectsProjectile(state: ShulkerPeekState) bool {
    return state != .open_firing;
}

pub const Axis = enum(u2) { x, y, z };

/// Selects the axis with the greatest remaining distance (ties prefer X, then
/// Y, then Z) and returns a one-block step toward the target on only that axis.
/// A target less than one block away is reached exactly on the selected axis.
pub fn chooseNextAxisStep(position: [3]f32, target: [3]f32) [3]f32 {
    var axis: usize = 0;
    var greatest_distance = @abs(target[0] - position[0]);
    for (1..3) |candidate| {
        const distance = @abs(target[candidate] - position[candidate]);
        if (distance > greatest_distance) {
            greatest_distance = distance;
            axis = candidate;
        }
    }

    var next = position;
    if (greatest_distance == 0.0) return next;
    const delta = target[axis] - position[axis];
    next[axis] += if (delta > 0.0) @min(1.0, delta) else @max(-1.0, delta);
    return next;
}

pub const Levitation = struct {
    duration: f32 = levitation_duration_seconds,
    upward_velocity: f32 = levitation_upward_velocity,
    active: bool = true,

    pub fn tick(self: *Levitation, dt: f32) void {
        if (!self.active) return;
        if (dt <= 0.0) return;
        if (self.duration > dt) {
            self.duration -= dt;
        } else {
            self.duration = 0.0;
            self.active = false;
        }
    }
};

pub const ShulkerBullet = struct {
    position: [3]f32,
    target: [3]f32,
    alive: bool = true,

    pub fn init(position: [3]f32, target: [3]f32) ShulkerBullet {
        return .{ .position = position, .target = target };
    }

    /// Advance by one orthogonal grid step toward the current target.
    pub fn homeOneStep(self: *ShulkerBullet) [3]f32 {
        if (!self.alive) return self.position;
        self.position = chooseNextAxisStep(self.position, self.target);
        return self.position;
    }

    pub fn hasReachedTarget(self: ShulkerBullet) bool {
        return self.position[0] == self.target[0] and
            self.position[1] == self.target[1] and
            self.position[2] == self.target[2];
    }

    /// A successful hit consumes the bullet and applies fixed damage plus
    /// 10 seconds of upward Levitation. Subsequent hits do nothing.
    pub fn hitTarget(self: *ShulkerBullet) ?BulletHit {
        if (!self.alive) return null;
        self.alive = false;
        return .{ .damage = shulker_bullet_damage, .levitation = .{} };
    }

    /// A melee swat destroys the projectile before it can hit a target.
    pub fn swatWithMelee(self: *ShulkerBullet) bool {
        if (!self.alive) return false;
        self.alive = false;
        return true;
    }
};

pub const BulletHit = struct {
    damage: f32,
    levitation: Levitation,
};

pub const ShulkerBoxSlot = struct {
    item_id: u16 = 0,
    count: u8 = 0,
};

pub const ShulkerBoxContainer = struct {
    slots: [27]ShulkerBoxSlot = [_]ShulkerBoxSlot{.{}} ** shulker_box_slot_count,
    color: ?u4 = null,

    pub fn setSlot(self: *ShulkerBoxContainer, index: usize, item_id: u16, count: u8) bool {
        if (index >= shulker_box_slot_count) return false;
        self.slots[index] = .{ .item_id = item_id, .count = count };
        return true;
    }

    pub fn getSlot(self: ShulkerBoxContainer, index: usize) ?ShulkerBoxSlot {
        if (index >= shulker_box_slot_count) return null;
        const slot = self.slots[index];
        return .{ .item_id = slot.item_id, .count = slot.count };
    }

    /// Mining/picking up preserves every slot and the optional dye color in
    /// the returned item payload; no inventory serialization is discarded.
    pub fn mineAndPickUp(self: ShulkerBoxContainer) ShulkerBoxItem {
        return .{ .slots = self.slots, .color = self.color };
    }

    pub fn canInsertIntoShulkerBox(is_shulker_box_item: bool) bool {
        return !is_shulker_box_item;
    }
};

pub const ShulkerBoxItem = struct {
    slots: [27]ShulkerBoxSlot,
    color: ?u4,

    pub fn place(self: ShulkerBoxItem) ShulkerBoxContainer {
        return .{ .slots = self.slots, .color = self.color };
    }
};

pub const Shulker = struct {
    position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    alive: bool = true,
};

pub const ShulkerDuplicationResult = struct {
    triggered: bool = false,
    teleported: bool = false,
    spawned_shulker: bool = false,
    spawned_position: ?[3]f32 = null,
};

/// Models the mutual-hit duplication event. When a Shulker bullet hits another
/// Shulker and fewer than five Shulkers are nearby, the victim teleports to the
/// supplied destination and a new Shulker appears at its old position.
pub fn tryShulkerHitDuplication(
    victim: *Shulker,
    hit_by_shulker_bullet: bool,
    nearby_shulker_count: u8,
    teleport_destination: [3]f32,
) ShulkerDuplicationResult {
    if (!victim.alive or !hit_by_shulker_bullet or nearby_shulker_count >= shulker_duplication_nearby_limit) {
        return .{};
    }
    const spawn_position = victim.position;
    victim.position = teleport_destination;
    return .{
        .triggered = true,
        .teleported = true,
        .spawned_shulker = true,
        .spawned_position = spawn_position,
    };
}

test "closed shell has 20 armor points and reduces melee damage by 80 percent" {
    try std.testing.expectEqual(@as(f32, 20.0), armorPoints(.closed_shell));
    try std.testing.expectEqual(@as(f32, 0.8), meleeDamageReduction(.closed_shell));
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), applyMeleeDamage(.closed_shell, 10.0), 0.0001);
}

test "closed shell completely deflects arrows and projectiles" {
    try std.testing.expect(deflectsProjectile(.closed_shell));
}

test "peeking shell keeps its armor and projectile deflection" {
    try std.testing.expectEqual(@as(f32, 20.0), armorPoints(.peeking));
    try std.testing.expect(deflectsProjectile(.peeking));
}

test "open firing shell has no armor or melee reduction" {
    try std.testing.expectEqual(@as(f32, 0.0), armorPoints(.open_firing));
    try std.testing.expectEqual(@as(f32, 0.0), meleeDamageReduction(.open_firing));
    try std.testing.expectEqual(@as(f32, 10.0), applyMeleeDamage(.open_firing, 10.0));
}

test "open firing shell is vulnerable to projectiles" {
    try std.testing.expect(!deflectsProjectile(.open_firing));
}

test "axis homing chooses largest remaining delta and changes only X" {
    const next = chooseNextAxisStep(.{ 0.0, 0.0, 0.0 }, .{ 3.0, 2.0, 1.0 });
    try std.testing.expectEqual([3]f32{ 1.0, 0.0, 0.0 }, next);
}

test "axis homing steps toward negative Y only" {
    const next = chooseNextAxisStep(.{ 2.0, 5.0, -1.0 }, .{ 2.0, 1.0, -1.0 });
    try std.testing.expectEqual([3]f32{ 2.0, 4.0, -1.0 }, next);
}

test "axis homing handles fractional final step" {
    const next = chooseNextAxisStep(.{ 0.0, 0.0, 0.0 }, .{ 0.25, 0.1, 0.0 });
    try std.testing.expectEqual([3]f32{ 0.25, 0.0, 0.0 }, next);
}

test "axis homing does not move when already at target" {
    const next = chooseNextAxisStep(.{ 1.0, 2.0, 3.0 }, .{ 1.0, 2.0, 3.0 });
    try std.testing.expectEqual([3]f32{ 1.0, 2.0, 3.0 }, next);
}

test "ShulkerBullet homes one axis per step until reaching target" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 1.0, 1.0 });
    _ = bullet.homeOneStep();
    try std.testing.expectEqual([3]f32{ 1.0, 0.0, 0.0 }, bullet.position);
    _ = bullet.homeOneStep();
    try std.testing.expectEqual([3]f32{ 1.0, 1.0, 0.0 }, bullet.position);
    _ = bullet.homeOneStep();
    try std.testing.expect(bullet.hasReachedTarget());
}

test "Shulker Bullet hit deals four damage and applies ten-second Levitation" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    const hit = bullet.hitTarget().?;
    try std.testing.expectEqual(@as(f32, 4.0), hit.damage);
    try std.testing.expectEqual(@as(f32, 10.0), hit.levitation.duration);
    try std.testing.expect(hit.levitation.active);
}

test "Levitation applies plus 0.9 meters per second upward float velocity" {
    const effect = Levitation{};
    try std.testing.expectEqual(@as(f32, 0.9), effect.upward_velocity);
}

test "Levitation expires after ten seconds" {
    var effect = Levitation{};
    effect.tick(9.5);
    try std.testing.expect(effect.active);
    try std.testing.expectEqual(@as(f32, 0.5), effect.duration);
    effect.tick(0.5);
    try std.testing.expect(!effect.active);
    try std.testing.expectEqual(@as(f32, 0.0), effect.duration);
}

test "Shulker Bullet can be swatted out of the air with melee" {
    var bullet = ShulkerBullet.init(.{ 0.0, 0.0, 0.0 }, .{ 4.0, 2.0, 1.0 });
    try std.testing.expect(bullet.swatWithMelee());
    try std.testing.expect(!bullet.alive);
    try std.testing.expect(!bullet.swatWithMelee());
    try std.testing.expectEqual(@as(?BulletHit, null), bullet.hitTarget());
}

test "Shulker Box has 27 empty slots and optional color" {
    const box = ShulkerBoxContainer{};
    try std.testing.expectEqual(@as(usize, 27), box.slots.len);
    try std.testing.expectEqual(@as(?u4, null), box.color);
    for (box.slots) |slot| {
        try std.testing.expectEqual(@as(u16, 0), slot.item_id);
        try std.testing.expectEqual(@as(u8, 0), slot.count);
    }
}

test "Shulker Box retains all 27 stacks and color through mining and placement" {
    var box = ShulkerBoxContainer{ .color = 13 };
    for (0..shulker_box_slot_count) |i| {
        try std.testing.expect(box.setSlot(i, @intCast(i + 1), @intCast(i + 2)));
    }
    const item = box.mineAndPickUp();
    const placed = item.place();
    try std.testing.expectEqual(@as(?u4, 13), placed.color);
    for (0..shulker_box_slot_count) |i| {
        const slot = placed.getSlot(i).?;
        try std.testing.expectEqual(@as(u16, @intCast(i + 1)), slot.item_id);
        try std.testing.expectEqual(@as(u8, @intCast(i + 2)), slot.count);
    }
}

test "Shulker Box rejects nesting Shulker Box items" {
    try std.testing.expect(!ShulkerBoxContainer.canInsertIntoShulkerBox(true));
    try std.testing.expect(ShulkerBoxContainer.canInsertIntoShulkerBox(false));
}

test "Shulker Box slot access rejects indices outside 27 slots" {
    var box = ShulkerBoxContainer{};
    try std.testing.expect(!box.setSlot(27, 12, 1));
    try std.testing.expectEqual(@as(?ShulkerBoxSlot, null), box.getSlot(27));
}

test "Shulker bullet mutual hit teleports and duplicates below five nearby" {
    var victim = Shulker{ .position = .{ 1.0, 2.0, 3.0 } };
    const result = tryShulkerHitDuplication(&victim, true, 4, .{ 9.0, 8.0, 7.0 });
    try std.testing.expect(result.triggered and result.teleported and result.spawned_shulker);
    try std.testing.expectEqual([3]f32{ 9.0, 8.0, 7.0 }, victim.position);
    try std.testing.expectEqual([3]f32{ 1.0, 2.0, 3.0 }, result.spawned_position.?);
}

test "Shulker duplication is blocked at five nearby Shulkers" {
    var victim = Shulker{ .position = .{ 1.0, 2.0, 3.0 } };
    const result = tryShulkerHitDuplication(&victim, true, 5, .{ 9.0, 8.0, 7.0 });
    try std.testing.expect(!result.triggered);
    try std.testing.expectEqual([3]f32{ 1.0, 2.0, 3.0 }, victim.position);
}

test "Shulker duplication requires a Shulker bullet hit and living victim" {
    var victim = Shulker{ .position = .{ 1.0, 2.0, 3.0 } };
    try std.testing.expect(!tryShulkerHitDuplication(&victim, false, 1, .{ 9.0, 8.0, 7.0 }).triggered);
    victim.alive = false;
    try std.testing.expect(!tryShulkerHitDuplication(&victim, true, 1, .{ 9.0, 8.0, 7.0 }).triggered);
    try std.testing.expectEqual([3]f32{ 1.0, 2.0, 3.0 }, victim.position);
}
