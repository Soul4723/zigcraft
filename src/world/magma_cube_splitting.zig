const std = @import("std");

pub const TICKS_PER_SECOND: f32 = 20.0;
pub const JUMP_COMPRESS_TICKS: u8 = 8;
pub const GRAVITY_PER_TICK: f32 = 0.08;
pub const CHILD_RADIAL_SPEED: f32 = 1.5;
pub const CHILD_UPWARD_POP: f32 = 0.2;
pub const LAND_MOVEMENT_SPEED: f32 = 0.8;
pub const LAVA_SWIM_SPEED: f32 = 1.5;
pub const MAGMA_CREAM_ITEM_TAG: u16 = 62;

pub const ItemType = enum(u16) { magma_cream = MAGMA_CREAM_ITEM_TAG };

/// Canonical magma cube size values also encode the entity's size attribute.
pub const MagmaCubeSize = enum(u8) {
    small = 1,
    medium = 2,
    big = 4,

    pub fn maxHealth(self: MagmaCubeSize) f32 {
        const size: f32 = @floatFromInt(@intFromEnum(self));
        return size * size;
    }

    pub fn meleeDamage(self: MagmaCubeSize) f32 {
        return switch (self) {
            .small => 3.0,
            .medium => 4.0,
            .big => 6.0,
        };
    }

    pub fn dimensions(self: MagmaCubeSize) Dimensions {
        const scale: f32 = @floatFromInt(@intFromEnum(self));
        return .{ .width = 0.52 * scale, .height = 0.52 * scale };
    }

    /// Minecraft's per-tick jump impulse; gravity is likewise integrated per tick.
    pub fn jumpVelocity(self: MagmaCubeSize) f32 {
        return 0.42 + 0.1 * @as(f32, @floatFromInt(@intFromEnum(self)));
    }
};

pub const Dimensions = struct { width: f32, height: f32 };
pub const Vec3 = struct { x: f32, y: f32, z: f32 };

pub const ChildCube = struct {
    size: MagmaCubeSize,
    velocity: Vec3,
};

pub const DeathResult = struct {
    defeated: bool = false,
    children: [4]ChildCube = undefined,
    child_count: u8 = 0,
    dropped_item: ?ItemType = null,
    dropped_item_count: u8 = 0,
    experience: u8 = 0,
};

/// Resolves a lethal hit exactly once. Rolls are explicit so callers can plug in
/// their world RNG while this domain module stays deterministic and testable.
pub const MagmaCube = struct {
    size: MagmaCubeSize,
    health: f32,
    defeated: bool = false,

    pub fn init(size: MagmaCubeSize) MagmaCube {
        return .{ .size = size, .health = size.maxHealth() };
    }

    pub fn applyDamage(self: *MagmaCube, amount: f32, split_roll_2_to_4: u8, cream_roll_0_to_1: bool, angle_offset_radians: f32) DeathResult {
        if (self.defeated or amount <= 0.0) return .{};
        self.health = @max(0.0, self.health - amount);
        if (self.health > 0.0) return .{};
        self.defeated = true;
        return resolveDefeat(self.size, split_roll_2_to_4, cream_roll_0_to_1, angle_offset_radians);
    }
};

pub fn resolveDefeat(size: MagmaCubeSize, split_roll_2_to_4: u8, cream_roll_0_to_1: bool, angle_offset_radians: f32) DeathResult {
    return switch (size) {
        .big, .medium => makeSplitResult(size, split_roll_2_to_4, angle_offset_radians),
        .small => .{
            .defeated = true,
            .dropped_item = if (cream_roll_0_to_1) .magma_cream else null,
            .dropped_item_count = @intFromBool(cream_roll_0_to_1),
            .experience = 1,
        },
    };
}

fn makeSplitResult(size: MagmaCubeSize, roll: u8, angle_offset_radians: f32) DeathResult {
    const count: u8 = @max(2, @min(4, roll));
    const child_size: MagmaCubeSize = if (size == .big) .medium else .small;
    var result = DeathResult{ .defeated = true, .child_count = count };
    for (0..count) |i| {
        const fraction = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(count));
        const angle = angle_offset_radians + fraction * 2.0 * std.math.pi;
        result.children[i] = .{
            .size = child_size,
            .velocity = .{
                .x = @cos(angle) * CHILD_RADIAL_SPEED,
                .y = CHILD_UPWARD_POP,
                .z = @sin(angle) * CHILD_RADIAL_SPEED,
            },
        };
    }
    return result;
}

pub fn takesFallDamage() bool {
    return false;
}

pub fn movementSpeed(in_lava: bool) f32 {
    return if (in_lava) LAVA_SWIM_SPEED else LAND_MOVEMENT_SPEED;
}

pub const LeapState = struct {
    size: MagmaCubeSize,
    compression_ticks: u8 = 0,
    velocity_y: f32 = 0.0,
    grounded: bool = true,
    body_height_scale: f32 = 1.0,

    pub fn init(size: MagmaCubeSize) LeapState {
        return .{ .size = size };
    }

    /// Advances one game tick. The first eight grounded ticks compress the
    /// spring body; the following tick launches it, then gravity is integrated.
    pub fn tick(self: *LeapState) void {
        if (self.grounded) {
            if (self.compression_ticks < JUMP_COMPRESS_TICKS) {
                self.compression_ticks += 1;
                const progress = @as(f32, @floatFromInt(self.compression_ticks)) / @as(f32, JUMP_COMPRESS_TICKS);
                self.body_height_scale = 1.0 - 0.4 * progress;
                return;
            }
            self.velocity_y = self.size.jumpVelocity();
            self.grounded = false;
            self.compression_ticks = 0;
            self.body_height_scale = 1.0;
            return;
        }
        self.velocity_y -= GRAVITY_PER_TICK;
    }

    pub fn land(self: *LeapState) void {
        self.grounded = true;
        self.velocity_y = 0.0;
        self.compression_ticks = 0;
        self.body_height_scale = 1.0;
    }
};

test "size enum discriminants are canonical" {
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(MagmaCubeSize.big));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(MagmaCubeSize.medium));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(MagmaCubeSize.small));
}

test "big cube has sixteen health" { try std.testing.expectEqual(@as(f32, 16), MagmaCubeSize.big.maxHealth()); }
test "medium cube has four health" { try std.testing.expectEqual(@as(f32, 4), MagmaCubeSize.medium.maxHealth()); }
test "small cube has one health" { try std.testing.expectEqual(@as(f32, 1), MagmaCubeSize.small.maxHealth()); }
test "big cube deals six melee damage" { try std.testing.expectEqual(@as(f32, 6), MagmaCubeSize.big.meleeDamage()); }
test "medium cube deals four melee damage" { try std.testing.expectEqual(@as(f32, 4), MagmaCubeSize.medium.meleeDamage()); }
test "small magma cube still deals three melee damage" { try std.testing.expectEqual(@as(f32, 3), MagmaCubeSize.small.meleeDamage()); }
test "big cube dimensions are 2.08 meters" { const d = MagmaCubeSize.big.dimensions(); try std.testing.expectApproxEqAbs(@as(f32, 2.08), d.width, 0.0001); try std.testing.expectApproxEqAbs(@as(f32, 2.08), d.height, 0.0001); }
test "medium cube dimensions are 1.04 meters" { const d = MagmaCubeSize.medium.dimensions(); try std.testing.expectApproxEqAbs(@as(f32, 1.04), d.width, 0.0001); try std.testing.expectApproxEqAbs(@as(f32, 1.04), d.height, 0.0001); }
test "small cube dimensions are 0.52 meters" { const d = MagmaCubeSize.small.dimensions(); try std.testing.expectApproxEqAbs(@as(f32, 0.52), d.width, 0.0001); try std.testing.expectApproxEqAbs(@as(f32, 0.52), d.height, 0.0001); }
test "big jump impulse follows size formula" { try std.testing.expectApproxEqAbs(@as(f32, 0.82), MagmaCubeSize.big.jumpVelocity(), 0.0001); }
test "medium jump impulse follows size formula" { try std.testing.expectApproxEqAbs(@as(f32, 0.62), MagmaCubeSize.medium.jumpVelocity(), 0.0001); }
test "small jump impulse follows size formula" { try std.testing.expectApproxEqAbs(@as(f32, 0.52), MagmaCubeSize.small.jumpVelocity(), 0.0001); }
test "big cube lethal hit splits" { var cube = MagmaCube.init(.big); const r = cube.applyDamage(16, 3, false, 0); try std.testing.expect(r.defeated); }
test "big cube splits into medium cubes" { const r = resolveDefeat(.big, 3, false, 0); try std.testing.expectEqual(MagmaCubeSize.medium, r.children[0].size); }
test "big cube supports minimum of two children" { try std.testing.expectEqual(@as(u8, 2), resolveDefeat(.big, 2, false, 0).child_count); }
test "big cube supports three children" { try std.testing.expectEqual(@as(u8, 3), resolveDefeat(.big, 3, false, 0).child_count); }
test "big cube supports maximum of four children" { try std.testing.expectEqual(@as(u8, 4), resolveDefeat(.big, 4, false, 0).child_count); }
test "medium cube splits into small cubes" { const r = resolveDefeat(.medium, 3, false, 0); try std.testing.expectEqual(MagmaCubeSize.small, r.children[0].size); }
test "medium cube supports two children" { try std.testing.expectEqual(@as(u8, 2), resolveDefeat(.medium, 2, false, 0).child_count); }
test "medium cube supports four children" { try std.testing.expectEqual(@as(u8, 4), resolveDefeat(.medium, 4, false, 0).child_count); }
test "split count clamps low roll to two" { try std.testing.expectEqual(@as(u8, 2), resolveDefeat(.big, 0, false, 0).child_count); }
test "split count clamps high roll to four" { try std.testing.expectEqual(@as(u8, 4), resolveDefeat(.medium, 9, false, 0).child_count); }
test "small cube does not split and awards one experience" { const r = resolveDefeat(.small, 4, false, 0); try std.testing.expectEqual(@as(u8, 0), r.child_count); try std.testing.expectEqual(@as(u8, 1), r.experience); }
test "small cube can drop one magma cream" { const r = resolveDefeat(.small, 3, true, 0); try std.testing.expectEqual(ItemType.magma_cream, r.dropped_item.?); try std.testing.expectEqual(@as(u8, 1), r.dropped_item_count); }
test "small cube can drop zero magma cream" { const r = resolveDefeat(.small, 3, false, 0); try std.testing.expectEqual(@as(?ItemType, null), r.dropped_item); try std.testing.expectEqual(@as(u8, 0), r.dropped_item_count); }
test "magma cream tag matches inventory" { try std.testing.expectEqual(@as(u16, 62), @intFromEnum(ItemType.magma_cream)); }
test "child launches have 1.5 meter per second radial velocity" { const r = resolveDefeat(.big, 2, false, 0); try std.testing.expectApproxEqAbs(CHILD_RADIAL_SPEED, @sqrt(r.children[0].velocity.x * r.children[0].velocity.x + r.children[0].velocity.z * r.children[0].velocity.z), 0.0001); }
test "child launch includes slight upward pop" { const r = resolveDefeat(.big, 2, false, 0); try std.testing.expectEqual(CHILD_UPWARD_POP, r.children[0].velocity.y); }
test "child launch directions disperse radially" { const r = resolveDefeat(.big, 4, false, 0); try std.testing.expect(r.children[0].velocity.x > 0); try std.testing.expect(@abs(r.children[1].velocity.z) > 1.4); }
test "cube takes no fall damage" { try std.testing.expect(!takesFallDamage()); }
test "lava swimming is faster than land movement" { try std.testing.expect(movementSpeed(true) > movementSpeed(false)); }
test "lava movement speed is 1.5 meters per second" { try std.testing.expectEqual(@as(f32, 1.5), movementSpeed(true)); }
test "land movement speed is 0.8 meters per second" { try std.testing.expectEqual(@as(f32, 0.8), movementSpeed(false)); }
test "leap compresses for eight ticks before launch" { var leap = LeapState.init(.big); for (0..8) |_| leap.tick(); try std.testing.expectEqual(@as(u8, 8), leap.compression_ticks); try std.testing.expect(leap.grounded); try std.testing.expect(leap.body_height_scale < 1.0); leap.tick(); try std.testing.expect(!leap.grounded); try std.testing.expectEqual(@as(f32, 0.82), leap.velocity_y); }
test "compression is visibly progressive" { var leap = LeapState.init(.small); leap.tick(); try std.testing.expectApproxEqAbs(@as(f32, 0.95), leap.body_height_scale, 0.0001); }
test "leap gravity reduces upward velocity" { var leap = LeapState.init(.big); for (0..9) |_| leap.tick(); leap.tick(); try std.testing.expectApproxEqAbs(@as(f32, 0.74), leap.velocity_y, 0.0001); }
test "big leap can rise about four blocks" { var leap = LeapState.init(.big); for (0..9) |_| leap.tick(); var height: f32 = 0; var peak: f32 = 0; while (leap.velocity_y > 0) { height += leap.velocity_y; peak = @max(peak, height); leap.tick(); } try std.testing.expect(peak >= 4.0); }
test "landing resets leap compression and velocity" { var leap = LeapState.init(.medium); for (0..9) |_| leap.tick(); leap.land(); try std.testing.expect(leap.grounded); try std.testing.expectEqual(@as(f32, 0), leap.velocity_y); try std.testing.expectEqual(@as(f32, 1), leap.body_height_scale); }
test "nonlethal damage does not emit defeat events" { var cube = MagmaCube.init(.small); const r = cube.applyDamage(0.5, 3, true, 0); try std.testing.expect(!r.defeated); try std.testing.expectEqual(@as(f32, 0.5), cube.health); }
test "lethal damage emits split once" { var cube = MagmaCube.init(.big); _ = cube.applyDamage(16, 2, false, 0); const repeated = cube.applyDamage(1, 2, false, 0); try std.testing.expect(!repeated.defeated); try std.testing.expectEqual(@as(u8, 0), repeated.child_count); }
