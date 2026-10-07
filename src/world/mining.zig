const std = @import("std");

pub const MineState = struct {
    valid: bool = false,
    key: i64 = 0,
    progress: f32 = 0.0,
    need: f32 = 1.0,

    pub fn retarget(self: *MineState, key: i64, need: f32) void {
        self.valid = true;
        self.key = key;
        self.progress = 0.0;
        self.need = @max(need, 0.001);
    }

    pub fn advance(self: *MineState, dt: f32) void {
        self.progress += dt;
    }

    pub fn done(self: *const MineState, need: f32) bool {
        return need > 0.0 and self.progress + 0.0001 >= need;
    }

    pub fn fraction(self: *const MineState) f32 {
        if (!self.valid or self.need <= 0.0) return -1.0;
        return self.progress / self.need;
    }

    pub fn reset(self: *MineState) void {
        self.valid = false;
        self.progress = 0.0;
        self.need = 1.0;
    }
};

pub fn targetKey(x: i32, y: i32, z: i32) i64 {
    return (@as(i64, x) << 42) ^ (@as(i64, y) << 21) ^ @as(i64, z);
}

pub fn leafAppleDrop(x: i32, y: i32, z: i32) bool {
    const h: u32 = @as(u32, @bitCast(x *% 31 +% y *% 17 +% z)) % 7;
    return h == 0;
}

pub fn leafSaplingDrop(x: i32, y: i32, z: i32) bool {
    const sh: u32 = @as(u32, @bitCast(x *% 13 +% y *% 29 +% z *% 7)) % 12;
    return sh == 0;
}

test "mine state lifecycle" {
    var m = MineState{};
    try std.testing.expectEqual(m.fraction(), -1.0);
    m.retarget(42, 1.0);
    try std.testing.expect(m.valid);
    try std.testing.expectEqual(m.fraction(), 0.0);
    m.advance(0.5);
    try std.testing.expect(!m.done(1.0));
    m.advance(0.6);
    try std.testing.expect(m.done(1.0));
    m.reset();
    try std.testing.expect(!m.valid);
}

test "target keys differ per cell" {
    try std.testing.expect(targetKey(1, 2, 3) != targetKey(1, 2, 4));
    try std.testing.expectEqual(targetKey(5, 5, 5), targetKey(5, 5, 5));
}

pub const LeafBonus = struct {
    apple: bool,
    sapling: bool,
};

pub fn checkLeafBonuses(x: i32, y: i32, z: i32) LeafBonus {
    return .{
        .apple = leafAppleDrop(x, y, z),
        .sapling = leafSaplingDrop(x, y, z),
    };
}

test "checkLeafBonuses check" {
    const b = checkLeafBonuses(0, 0, 0);
    try std.testing.expectEqual(leafAppleDrop(0, 0, 0), b.apple);
    try std.testing.expectEqual(leafSaplingDrop(0, 0, 0), b.sapling);
}
