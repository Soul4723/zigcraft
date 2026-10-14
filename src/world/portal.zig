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

pub const PortalTarget = struct {
    x: i32,
    y: i32,
    z: i32,
    dim: Dimension,
};

pub const PORTAL_LINK_SEARCH_RADIUS: f32 = 128.0;

/// Find closest active portal in the target destination dimension within search radius.
pub fn findLinkedPortal(portals: []const PortalTarget, from_dim: Dimension, ox: f32, oy: f32, oz: f32, search_radius: f32) ?PortalTarget {
    const target_dim: Dimension = if (from_dim == .overworld) .nether else .overworld;
    const ideal = PortalTransitState.calculateWarpPosition(from_dim, ox, oy, oz);
    var closest: ?PortalTarget = null;
    var min_dist_sq: f32 = search_radius * search_radius;

    for (portals) |pt| {
        if (pt.dim != target_dim) continue;
        const ptx = @as(f32, @floatFromInt(pt.x)) + 0.5;
        const pty = @as(f32, @floatFromInt(pt.y));
        const ptz = @as(f32, @floatFromInt(pt.z)) + 0.5;
        const dx = ptx - ideal[0];
        const dy = (pty - ideal[1]) * 0.5; // Bias towards horizontal alignment
        const dz = ptz - ideal[2];
        const dist_sq = dx * dx + dy * dy + dz * dz;
        if (dist_sq <= min_dist_sq) {
            min_dist_sq = dist_sq;
            closest = pt;
        }
    }
    return closest;
}

test "findLinkedPortal matches closest portal in target dimension within search radius" {
    const portals = [_]PortalTarget{
        .{ .x = 10, .y = 60, .z = 10, .dim = .nether }, // Nether portal near (10, 60, 10)
        .{ .x = 80, .y = 60, .z = 80, .dim = .overworld }, // Overworld portal
    };

    // Warp from Overworld (80, 60, 80) -> ideal Nether coord is (10, 60, 10). Should match first portal!
    const match = findLinkedPortal(&portals, .overworld, 80.0, 60.0, 80.0, 128.0);
    try std.testing.expect(match != null);
    try std.testing.expectEqual(@as(i32, 10), match.?.x);
    try std.testing.expectEqual(Dimension.nether, match.?.dim);

    // Warp from Nether (10, 60, 10) -> ideal Overworld coord is (80, 60, 80). Should match second portal!
    const return_match = findLinkedPortal(&portals, .nether, 10.0, 60.0, 10.0, 128.0);
    try std.testing.expect(return_match != null);
    try std.testing.expectEqual(@as(i32, 80), return_match.?.x);
    try std.testing.expectEqual(Dimension.overworld, return_match.?.dim);

    // Far portal outside search radius returns null
    const far_match = findLinkedPortal(&portals, .overworld, 2000.0, 60.0, 2000.0, 64.0);
    try std.testing.expect(far_match == null);
}

/// Check if a given portal cell still resides within a fully intact obsidian frame.
pub fn isPortalCellValid(lookup: BlockLookupFn, x: i32, y: i32, z: i32) bool {
    return detectPortalFrame(lookup, x, y, z) != null;
}

/// Extinguish connected portal cells when frame is broken or breached by water.
pub fn collectPortalCellsToExtinguish(lookup: BlockLookupFn, x: i32, y: i32, z: i32, out: *[6][3]i32) usize {
    var count: usize = 0;
    // Scan local 3x4x3 volume around the broken/quenched point for connected nether_portal blocks
    var dx: i32 = -2;
    while (dx <= 2) : (dx += 1) {
        var dy: i32 = -3;
        while (dy <= 3) : (dy += 1) {
            var dz: i32 = -2;
            while (dz <= 2) : (dz += 1) {
                const cx = x + dx;
                const cy = y + dy;
                const cz = z + dz;
                if (lookup(cx, cy, cz) == .nether_portal) {
                    if (count < 6) {
                        out[count] = .{ cx, cy, cz };
                        count += 1;
                    }
                }
            }
        }
    }
    return count;
}

test "isPortalCellValid detects broken frame and collectPortalCellsToExtinguish finds cells" {
    // Intact frame:
    const MockIntact = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (z != 5) return .air;
            if (x < 10 or x > 13 or y < 20 or y > 24) return .air;
            if ((x == 11 or x == 12) and (y >= 21 and y <= 23)) return .nether_portal;
            return .obsidian;
        }
    };
    try std.testing.expect(isPortalCellValid(MockIntact.get, 11, 21, 5));

    // Broken frame (missing jamb at x=10):
    const MockBroken = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (z != 5) return .air;
            if (x == 10 and y == 21) return .air; // broken!
            if (x < 10 or x > 13 or y < 20 or y > 24) return .air;
            if ((x == 11 or x == 12) and (y >= 21 and y <= 23)) return .nether_portal;
            return .obsidian;
        }
    };
    try std.testing.expect(!isPortalCellValid(MockBroken.get, 11, 21, 5));

    var cells: [6][3]i32 = undefined;
    const n = collectPortalCellsToExtinguish(MockBroken.get, 11, 21, 5, &cells);
    try std.testing.expectEqual(@as(usize, 6), n);
}

pub const EndPortalAltar = struct {
    center_x: i32,
    center_y: i32,
    center_z: i32,
};

/// Check if (cx, cy, cz) is center of a 3x3 horizontal End Portal inside a 5x5 altar of 12 filled frames.
/// The 12 frame positions are:
/// x in [cx-1, cx+1], z = cz - 2 (North 3 frames)
/// x in [cx-1, cx+1], z = cz + 2 (South 3 frames)
/// z in [cz-1, cz+1], x = cx - 2 (West 3 frames)
/// z in [cz-1, cz+1], x = cx + 2 (East 3 frames)
/// The 4 corners (cx+-2, cz+-2) are open/ignored.
/// The 3x3 interior (x in cx-1..cx+1, z in cz-1..cz+1) at cy must be air or end_portal.
pub fn checkEndAltarCenter(lookup: BlockLookupFn, cx: i32, cy: i32, cz: i32) bool {
    // 1. Verify 3x3 interior is air or end_portal
    var ix: i32 = -1;
    while (ix <= 1) : (ix += 1) {
        var iz: i32 = -1;
        while (iz <= 1) : (iz += 1) {
            const b = lookup(cx + ix, cy, cz + iz);
            if (b != .air and b != .end_portal) return false;
        }
    }

    // 2. Verify North rim (z = cz - 2, x in cx-1..cx+1)
    var rx: i32 = -1;
    while (rx <= 1) : (rx += 1) {
        if (lookup(cx + rx, cy, cz - 2) != .end_portal_frame_filled) return false;
        if (lookup(cx + rx, cy, cz + 2) != .end_portal_frame_filled) return false;
    }

    // 3. Verify West/East rim (x = cx +- 2, z in cz-1..cz+1)
    var rz: i32 = -1;
    while (rz <= 1) : (rz += 1) {
        if (lookup(cx - 2, cy, cz + rz) != .end_portal_frame_filled) return false;
        if (lookup(cx + 2, cy, cz + rz) != .end_portal_frame_filled) return false;
    }

    return true;
}

/// Detect if eye insertion at (fx, fy, fz) completes a 12-frame altar around any adjacent 3x3 center.
/// Returns the altar center (cx, cy, cz) if found.
pub fn detectEndPortalAltar(lookup: BlockLookupFn, fx: i32, fy: i32, fz: i32) ?EndPortalAltar {
    // fx, fz is one of the 12 frame positions.
    // The center (cx, cz) must be at distance:
    // Either (fx +- 2, fz) if fx was West/East rim
    // Or (fx, fz +- 2) if fz was North/South rim
    // Or (fx +- 1, fz +- 2) etc.
    // Scan candidate centers cx in [fx-2 .. fx+2], cz in [fz-2 .. fz+2]
    var dcx: i32 = -2;
    while (dcx <= 2) : (dcx += 1) {
        var dcz: i32 = -2;
        while (dcz <= 2) : (dcz += 1) {
            // Centers are 2 blocks away along one axis and at most 1 away along the other
            const ax = if (dcx < 0) -dcx else dcx;
            const az = if (dcz < 0) -dcz else dcz;
            if ((ax == 2 and az <= 1) or (az == 2 and ax <= 1)) {
                const cx = fx + dcx;
                const cz = fz + dcz;
                if (checkEndAltarCenter(lookup, cx, fy, cz)) {
                    return EndPortalAltar{ .center_x = cx, .center_y = fy, .center_z = cz };
                }
            }
        }
    }
    return null;
}

/// Given an EndPortalAltar center, fills the 3x3 interior (9 cells) with end_portal blocks.
pub fn activateEndPortalAltar(
    altar: EndPortalAltar,
    context: anytype,
    editBlock: *const fn (@TypeOf(context), x: i32, y: i32, z: i32, block: BlockId) bool,
) usize {
    var count: usize = 0;
    var dx: i32 = -1;
    while (dx <= 1) : (dx += 1) {
        var dz: i32 = -1;
        while (dz <= 1) : (dz += 1) {
            if (editBlock(context, altar.center_x + dx, altar.center_y, altar.center_z + dz, .end_portal)) {
                count += 1;
            }
        }
    }
    return count;
}

test "End Portal Altar detection and 3x3 activation" {
    const MockWorld = struct {
        filled: [12][3]i32,
        interior: [9]BlockId = [_]BlockId{.air} ** 9,

        fn get(self: *@This(), x: i32, y: i32, z: i32) BlockId {
            if (y != 10) return .air;
            for (self.filled) |f| {
                if (f[0] == x and f[1] == y and f[2] == z) return .end_portal_frame_filled;
            }
            if (x >= 9 and x <= 11 and z >= 19 and z <= 21) {
                const idx = @as(usize, @intCast((x - 9) + (z - 19) * 3));
                return self.interior[idx];
            }
            return .air;
        }

        fn set(self: *@This(), x: i32, y: i32, z: i32, b: BlockId) bool {
            if (y == 10 and x >= 9 and x <= 11 and z >= 19 and z <= 21) {
                const idx = @as(usize, @intCast((x - 9) + (z - 19) * 3));
                self.interior[idx] = b;
                return true;
            }
            return false;
        }
    };

    // Center at (10, 10, 20)
    // 12 filled frames:
    // North: (9, 10, 18), (10, 10, 18), (11, 10, 18)
    // South: (9, 10, 22), (10, 10, 22), (11, 10, 22)
    // West:  (8, 10, 19), (8, 10, 20), (8, 10, 21)
    // East:  (12, 10, 19), (12, 10, 20), (12, 10, 21)
    var world = MockWorld{
        .filled = [_][3]i32{
            .{ 9, 10, 18 }, .{ 10, 10, 18 }, .{ 11, 10, 18 },
            .{ 9, 10, 22 }, .{ 10, 10, 22 }, .{ 11, 10, 22 },
            .{ 8, 10, 19 }, .{ 8, 10, 20 }, .{ 8, 10, 21 },
            .{ 12, 10, 19 }, .{ 12, 10, 20 }, .{ 12, 10, 21 },
        },
    };

    const GlobalMock = struct {
        var current: *MockWorld = undefined;
        fn lookup(x: i32, y: i32, z: i32) BlockId {
            return current.get(x, y, z);
        }
    };
    GlobalMock.current = &world;

    // Detect from one of the frames (e.g. 10, 10, 18)
    const altar = detectEndPortalAltar(GlobalMock.lookup, 10, 10, 18);
    try std.testing.expect(altar != null);
    try std.testing.expectEqual(@as(i32, 10), altar.?.center_x);
    try std.testing.expectEqual(@as(i32, 10), altar.?.center_y);
    try std.testing.expectEqual(@as(i32, 20), altar.?.center_z);

    // Activate: should fill all 9 cells with .end_portal
    const n = activateEndPortalAltar(altar.?, &world, MockWorld.set);
    try std.testing.expectEqual(@as(usize, 9), n);
    for (world.interior) |b| {
        try std.testing.expectEqual(BlockId.end_portal, b);
    }
}
