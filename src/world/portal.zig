const std = @import("std");
const block_mod = @import("block.zig");
pub const BlockId = block_mod.BlockId;

pub const PortalAxis = enum {
    x_axis, // Frame runs along X axis (normal along Z)
    z_axis, // Frame runs along Z axis (normal along X)
};

pub const PortalFrame = struct {
    axis: PortalAxis,
    interior_min_x: i32,
    interior_min_y: i32,
    interior_min_z: i32,
    width: i32, // standard: 2
    height: i32, // standard: 3
};

/// Type definition for world block lookup function.
pub const BlockLookupFn = *const fn (x: i32, y: i32, z: i32) BlockId;

/// Check if a 2x3 frame surrounded by obsidian exists with (x, y, z) inside the 2x3 interior.
/// Standard frame: 4 blocks wide, 5 blocks high total.
/// Interior: 2 blocks wide, 3 blocks high of air/portal.
/// Bottom sill: 2 obsidian blocks under interior.
/// Top lintel: 2 obsidian blocks over interior.
/// Left/Right jambs: 3 obsidian blocks on each vertical side.
/// Corners are optional (standard Minecraft allows air or any block in corners).
pub fn detectPortalFrame(lookup: BlockLookupFn, x: i32, y: i32, z: i32) ?PortalFrame {
    // Try both X-axis and Z-axis orientations
    if (detectFrameOnAxis(lookup, x, y, z, .x_axis)) |f| return f;
    if (detectFrameOnAxis(lookup, x, y, z, .z_axis)) |f| return f;
    return null;
}

fn detectFrameOnAxis(lookup: BlockLookupFn, x: i32, y: i32, z: i32, axis: PortalAxis) ?PortalFrame {
    // A 2x3 interior has width=2 along primary axis, height=3 along Y.
    // The candidate interior point (x, y, z) could be at horizontal offset dx in [0, 1]
    // and vertical offset dy in [0, 1, 2].
    const width: i32 = 2;
    const height: i32 = 3;

    var dy: i32 = 0;
    while (dy < height) : (dy += 1) {
        const min_y = y - dy;
        var dw: i32 = 0;
        while (dw < width) : (dw += 1) {
            const min_x = if (axis == .x_axis) x - dw else x;
            const min_z = if (axis == .z_axis) z - dw else z;

            if (validateFrame(lookup, min_x, min_y, min_z, axis, width, height)) {
                return PortalFrame{
                    .axis = axis,
                    .interior_min_x = min_x,
                    .interior_min_y = min_y,
                    .interior_min_z = min_z,
                    .width = width,
                    .height = height,
                };
            }
        }
    }
    return null;
}

fn validateFrame(lookup: BlockLookupFn, min_x: i32, min_y: i32, min_z: i32, axis: PortalAxis, width: i32, height: i32) bool {
    // 1. Verify interior cells are air or already nether_portal
    var h: i32 = 0;
    while (h < height) : (h += 1) {
        var w: i32 = 0;
        while (w < width) : (w += 1) {
            const cx = if (axis == .x_axis) min_x + w else min_x;
            const cy = min_y + h;
            const cz = if (axis == .z_axis) min_z + w else min_z;
            const b = lookup(cx, cy, cz);
            if (b != .air and b != .nether_portal) return false;
        }
    }

    // 2. Verify bottom sill: width blocks of obsidian directly under interior
    var w: i32 = 0;
    while (w < width) : (w += 1) {
        const bx = if (axis == .x_axis) min_x + w else min_x;
        const by = min_y - 1;
        const bz = if (axis == .z_axis) min_z + w else min_z;
        if (lookup(bx, by, bz) != .obsidian) return false;
    }

    // 3. Verify top lintel: width blocks of obsidian directly above interior
    w = 0;
    while (w < width) : (w += 1) {
        const tx = if (axis == .x_axis) min_x + w else min_x;
        const ty = min_y + height;
        const tz = if (axis == .z_axis) min_z + w else min_z;
        if (lookup(tx, ty, tz) != .obsidian) return false;
    }

    // 4. Verify left and right jambs (sides): height blocks of obsidian on each side
    h = 0;
    while (h < height) : (h += 1) {
        const ly = min_y + h;
        // Left jamb (-1 on axis)
        const lx = if (axis == .x_axis) min_x - 1 else min_x;
        const lz = if (axis == .z_axis) min_z - 1 else min_z;
        if (lookup(lx, ly, lz) != .obsidian) return false;

        // Right jamb (+width on axis)
        const rx = if (axis == .x_axis) min_x + width else min_x;
        const rz = if (axis == .z_axis) min_z + width else min_z;
        if (lookup(rx, ly, rz) != .obsidian) return false;
    }

    return true;
}

test "detectPortalFrame identifies valid X-axis frame" {
    // Frame: 4x5 along X:
    // X from 10 to 13, Y from 20 to 24, Z = 5
    // Interior: X=11..12, Y=21..23, Z=5
    const Mock = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (z != 5) return .air;
            if (x < 10 or x > 13 or y < 20 or y > 24) return .air;
            // Interior:
            if ((x == 11 or x == 12) and (y >= 21 and y <= 23)) return .air;
            // Frame:
            return .obsidian;
        }
    };

    // Test any interior block finds the frame
    const frame = detectPortalFrame(Mock.get, 11, 21, 5);
    try std.testing.expect(frame != null);
    try std.testing.expectEqual(PortalAxis.x_axis, frame.?.axis);
    try std.testing.expectEqual(@as(i32, 11), frame.?.interior_min_x);
    try std.testing.expectEqual(@as(i32, 21), frame.?.interior_min_y);
    try std.testing.expectEqual(@as(i32, 5), frame.?.interior_min_z);

    // Test non-interior or broken frame fails
    try std.testing.expect(detectPortalFrame(Mock.get, 10, 20, 5) == null);
}

test "detectPortalFrame identifies valid Z-axis frame" {
    // Frame: 4x5 along Z:
    // X = 8, Y from 30 to 34, Z from 40 to 43
    // Interior: X=8, Y=31..33, Z=41..42
    const Mock = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (x != 8) return .air;
            if (z < 40 or z > 43 or y < 30 or y > 34) return .air;
            // Interior:
            if ((z == 41 or z == 42) and (y >= 31 and y <= 33)) return .air;
            // Frame:
            return .obsidian;
        }
    };

    const frame = detectPortalFrame(Mock.get, 8, 32, 42);
    try std.testing.expect(frame != null);
    try std.testing.expectEqual(PortalAxis.z_axis, frame.?.axis);
    try std.testing.expectEqual(@as(i32, 8), frame.?.interior_min_x);
    try std.testing.expectEqual(@as(i32, 31), frame.?.interior_min_y);
    try std.testing.expectEqual(@as(i32, 41), frame.?.interior_min_z);
}

test "detectPortalFrame rejects broken or incomplete frame" {
    // Missing top lintel
    const Mock = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (z != 0) return .air;
            if (y == 4) return .air; // missing top lintel
            if (x < 0 or x > 3 or y < 0 or y > 4) return .air;
            if ((x == 1 or x == 2) and (y >= 1 and y <= 3)) return .air;
            return .obsidian;
        }
    };

    try std.testing.expect(detectPortalFrame(Mock.get, 1, 1, 0) == null);
}

/// Activate portal: given a detected PortalFrame, fill its interior cells with nether_portal.
/// editBlock must be a callback that sets block at (x, y, z) to nether_portal.
pub fn activatePortalFrame(
    frame: PortalFrame,
    context: anytype,
    editBlock: *const fn (@TypeOf(context), x: i32, y: i32, z: i32, block: BlockId) bool,
) usize {
    var filled: usize = 0;
    var h: i32 = 0;
    while (h < frame.height) : (h += 1) {
        var w: i32 = 0;
        while (w < frame.width) : (w += 1) {
            const cx = if (frame.axis == .x_axis) frame.interior_min_x + w else frame.interior_min_x;
            const cy = frame.interior_min_y + h;
            const cz = if (frame.axis == .z_axis) frame.interior_min_z + w else frame.interior_min_z;
            if (editBlock(context, cx, cy, cz, .nether_portal)) {
                filled += 1;
            }
        }
    }
    return filled;
}

test "activatePortalFrame fills 2x3 interior cells" {
    const TestWorld = struct {
        blocks: [6]BlockId = [_]BlockId{.air} ** 6,

        fn set(self: *@This(), x: i32, y: i32, z: i32, b: BlockId) bool {
            _ = z;
            const idx = @as(usize, @intCast((x - 10) + (y - 5) * 2));
            self.blocks[idx] = b;
            return true;
        }
    };

    var world = TestWorld{};
    const frame = PortalFrame{
        .axis = .x_axis,
        .interior_min_x = 10,
        .interior_min_y = 5,
        .interior_min_z = 20,
        .width = 2,
        .height = 3,
    };

    const count = activatePortalFrame(frame, &world, TestWorld.set);
    try std.testing.expectEqual(@as(usize, 6), count);
    for (world.blocks) |b| {
        try std.testing.expectEqual(BlockId.nether_portal, b);
    }
}

pub const Dimension = enum(u8) {
    overworld = 0,
    nether = 1,
};

pub const PORTAL_TRIGGER_TIME: f32 = 3.0; // 3 seconds standing inside portal to warp
pub const PORTAL_COOLDOWN_TIME: f32 = 4.0; // 4 seconds post-warp immunity

pub const PortalTransitState = struct {
    inside_timer: f32 = 0.0,
    cooldown_timer: f32 = 0.0,
    current_dim: Dimension = .overworld,

    /// Update standing inside portal. Returns true if dimension shift triggers!
    pub fn tick(self: *PortalTransitState, in_portal: bool, dt: f32) bool {
        self.cooldown_timer = @max(0.0, self.cooldown_timer - dt);

        if (!in_portal) {
            // Decaying transit charge when player leaves portal frame
            self.inside_timer = @max(0.0, self.inside_timer - dt * 2.0);
            return false;
        }

        if (self.cooldown_timer > 0.0) {
            return false; // Still on cooldown after previous teleport
        }

        self.inside_timer += dt;
        if (self.inside_timer >= PORTAL_TRIGGER_TIME) {
            // Trigger teleportation and toggle dimension!
            self.inside_timer = 0.0;
            self.cooldown_timer = PORTAL_COOLDOWN_TIME;
            self.current_dim = if (self.current_dim == .overworld) .nether else .overworld;
            return true;
        }

        return false;
    }

    /// Calculate coordinate warp between Overworld and Nether (8:1 spatial ratio)
    pub fn calculateWarpPosition(from_dim: Dimension, px: f32, py: f32, pz: f32) [3]f32 {
        if (from_dim == .overworld) {
            // Overworld to Nether: scale coordinates down by 8x (keep Y level)
            return .{ px / 8.0, py, pz / 8.0 };
        } else {
            // Nether to Overworld: scale coordinates up by 8x
            return .{ px * 8.0, py, pz * 8.0 };
        }
    }
};

test "PortalTransitState requires sustained contact and triggers dimension warp" {
    var state = PortalTransitState{};
    try std.testing.expectEqual(Dimension.overworld, state.current_dim);

    // 1 second inside portal: not triggered yet
    try std.testing.expect(!state.tick(true, 1.0));
    try std.testing.expectEqual(Dimension.overworld, state.current_dim);
    try std.testing.expect(state.inside_timer >= 1.0);

    // Step out of portal: inside_timer decays
    _ = state.tick(false, 0.5);
    try std.testing.expect(state.inside_timer < 1.0);

    // Re-enter and sustain 3.0 seconds: triggers dimension warp!
    _ = state.tick(true, 1.5);
    _ = state.tick(true, 1.0);
    const triggered = state.tick(true, 0.6); // Total >= 3.0s
    try std.testing.expect(triggered);
    try std.testing.expectEqual(Dimension.nether, state.current_dim);
    try std.testing.expect(state.cooldown_timer > 0.0);

    // While on cooldown, sustained standing does not re-trigger immediately
    try std.testing.expect(!state.tick(true, 1.0));
    try std.testing.expectEqual(Dimension.nether, state.current_dim);
}

test "PortalTransitState coordinate scaling 8:1 ratio" {
    const nether_pos = PortalTransitState.calculateWarpPosition(.overworld, 160.0, 64.0, -80.0);
    try std.testing.expectEqual(@as(f32, 20.0), nether_pos[0]);
    try std.testing.expectEqual(@as(f32, 64.0), nether_pos[1]);
    try std.testing.expectEqual(@as(f32, -10.0), nether_pos[2]);

    const overworld_pos = PortalTransitState.calculateWarpPosition(.nether, 20.0, 64.0, -10.0);
    try std.testing.expectEqual(@as(f32, 160.0), overworld_pos[0]);
    try std.testing.expectEqual(@as(f32, 64.0), overworld_pos[1]);
    try std.testing.expectEqual(@as(f32, -80.0), overworld_pos[2]);
}
