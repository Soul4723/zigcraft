const std = @import("std");
const block_mod = @import("block.zig");
pub const BlockId = block_mod.BlockId;

pub const HORIZONTAL_SCALE: i64 = 8;
pub const PORTAL_SEARCH_RADIUS: i64 = 128;
pub const PORTAL_TRIGGER_TICKS: u16 = 80;
pub const PORTAL_POST_TRANSIT_COOLDOWN_TICKS: u16 = 300;
pub const MIN_WORLD_Y: i64 = 0;
pub const MAX_WORLD_Y: i64 = 255;
pub const FRAME_WIDTH: usize = 4;
pub const FRAME_HEIGHT: usize = 5;
pub const PORTAL_BLOCK_COUNT: usize = 6;
pub const FRAME_OBSIDIAN_COUNT: usize = 10;
pub const FRAME_GENERATION_RADIUS: i64 = 16;
pub const FRAME_MAX_BASE_Y: i64 = MAX_WORLD_Y - @as(i64, FRAME_HEIGHT - 1);

pub const Dimension = enum { overworld, nether };

pub const Position = struct { x: i64, y: i64, z: i64 };

pub fn clampWorldY(y: i64) i64 {
    return @max(MIN_WORLD_Y, @min(MAX_WORLD_Y, y));
}

fn clampFrameBaseY(y: i64) i64 {
    return @max(MIN_WORLD_Y, @min(FRAME_MAX_BASE_Y, y));
}

pub fn overworldToNether(position: Position) Position {
    return .{
        .x = @divFloor(position.x, HORIZONTAL_SCALE),
        .y = clampWorldY(position.y),
        .z = @divFloor(position.z, HORIZONTAL_SCALE),
    };
}

pub fn netherToOverworld(position: Position) Position {
    return .{
        .x = position.x * HORIZONTAL_SCALE,
        .y = clampWorldY(position.y),
        .z = position.z * HORIZONTAL_SCALE,
    };
}

pub fn convertPosition(from: Dimension, position: Position) Position {
    return if (from == .overworld) overworldToNether(position) else netherToOverworld(position);
}

pub const Portal = struct {
    position: Position,
    dimension: Dimension,
    active: bool = true,
};

/// Searches the horizontal 128-block circle and picks its closest active portal
/// using full 3D distance. The input is the entity position in the source dimension.
pub fn findDestinationPortal(portals: []const Portal, from: Dimension, source: Position) ?Portal {
    const ideal = convertPosition(from, source);
    const target_dimension: Dimension = if (from == .overworld) .nether else .overworld;
    const radius_sq: i64 = PORTAL_SEARCH_RADIUS * PORTAL_SEARCH_RADIUS;
    var closest: ?Portal = null;
    var closest_distance_sq: f64 = std.math.inf(f64);

    for (portals) |portal| {
        if (!portal.active or portal.dimension != target_dimension) continue;
        const dx = portal.position.x - ideal.x;
        const dz = portal.position.z - ideal.z;
        const horizontal_distance_sq = dx * dx + dz * dz;
        if (horizontal_distance_sq > radius_sq) continue;

        const dy = portal.position.y - ideal.y;
        const distance_sq = @as(f64, @floatFromInt(dx)) * @as(f64, @floatFromInt(dx)) +
            @as(f64, @floatFromInt(dy)) * @as(f64, @floatFromInt(dy)) +
            @as(f64, @floatFromInt(dz)) * @as(f64, @floatFromInt(dz));
        if (distance_sq < closest_distance_sq) {
            closest = portal;
            closest_distance_sq = distance_sq;
        }
    }
    return closest;
}

pub const PortalFrameSite = struct {
    /// Minimum X/Y/Z coordinate of the 4x5 frame plane (including its edges).
    min: Position,
    /// The four-wide side runs along X when true, or along Z when false.
    along_x: bool,
};

pub const FrameBlock = struct { position: Position, block: BlockId };

/// A score of zero means the candidate is unsafe or unavailable. Larger scores
/// represent safer sites; ties are resolved by distance, then scan order.
pub const SiteSafetyFn = *const fn (context: *const anyopaque, site: PortalFrameSite) u8;

pub const FramePlan = struct {
    site: PortalFrameSite,
    safety_score: u8,
};

pub const Destination = union(enum) {
    linked: Portal,
    generated: [FRAME_OBSIDIAN_COUNT + PORTAL_BLOCK_COUNT]FrameBlock,
};

/// Scan candidate sites within 16 horizontal blocks of the converted point.
/// The safety callback owns world-specific checks such as solid footing, clearance,
/// nearby lava, and dimension build limits.
pub fn findSafestFrameSite(
    ideal: Position,
    context: *const anyopaque,
    is_safe: SiteSafetyFn,
) ?FramePlan {
    var best: ?FramePlan = null;
    var best_distance_sq: i64 = std.math.maxInt(i64);

    var dz: i64 = -FRAME_GENERATION_RADIUS;
    while (dz <= FRAME_GENERATION_RADIUS) : (dz += 4) {
        var dx: i64 = -FRAME_GENERATION_RADIUS;
        while (dx <= FRAME_GENERATION_RADIUS) : (dx += 4) {
            const distance_sq = dx * dx + dz * dz;
            if (distance_sq > FRAME_GENERATION_RADIUS * FRAME_GENERATION_RADIUS) continue;
            const site = PortalFrameSite{
                .min = .{ .x = ideal.x + dx, .y = clampFrameBaseY(ideal.y), .z = ideal.z + dz },
                .along_x = true,
            };
            const score = is_safe(context, site);
            if (score == 0) continue;
            if (best == null or score > best.?.safety_score or
                (score == best.?.safety_score and distance_sq < best_distance_sq))
            {
                best = .{ .site = site, .safety_score = score };
                best_distance_sq = distance_sq;
            }
        }
    }
    return best;
}

/// Link to an in-range active portal, otherwise return a generated frame for the
/// highest-scoring safe site near the ideal converted position. Null means no
/// safe site was offered by the world-specific safety callback.
pub fn resolveDestination(
    portals: []const Portal,
    from: Dimension,
    source: Position,
    context: *const anyopaque,
    is_safe: SiteSafetyFn,
) ?Destination {
    if (findDestinationPortal(portals, from, source)) |portal| return .{ .linked = portal };
    const site = findSafestFrameSite(convertPosition(from, source), context, is_safe) orelse return null;
    return .{ .generated = generateFrame(site.site) };
}

/// Produce the ten required obsidian edge blocks and six portal interior blocks.
/// Frame corners are omitted, as in the standard minimum-obsidian portal frame.
pub fn generateFrame(site: PortalFrameSite) [FRAME_OBSIDIAN_COUNT + PORTAL_BLOCK_COUNT]FrameBlock {
    var result: [FRAME_OBSIDIAN_COUNT + PORTAL_BLOCK_COUNT]FrameBlock = undefined;
    var index: usize = 0;
    var x: usize = 1;
    while (x < FRAME_WIDTH - 1) : (x += 1) {
        result[index] = .{ .position = framePosition(site, x, 0), .block = .obsidian };
        index += 1;
        result[index] = .{ .position = framePosition(site, x, FRAME_HEIGHT - 1), .block = .obsidian };
        index += 1;
    }
    var y: usize = 1;
    while (y < FRAME_HEIGHT - 1) : (y += 1) {
        result[index] = .{ .position = framePosition(site, 0, y), .block = .obsidian };
        index += 1;
        result[index] = .{ .position = framePosition(site, FRAME_WIDTH - 1, y), .block = .obsidian };
        index += 1;
    }
    y = 1;
    while (y < FRAME_HEIGHT - 1) : (y += 1) {
        var inner: usize = 1;
        while (inner < FRAME_WIDTH - 1) : (inner += 1) {
            result[index] = .{ .position = framePosition(site, inner, y), .block = .nether_portal };
            index += 1;
        }
    }
    return result;
}

fn framePosition(site: PortalFrameSite, across: usize, up: usize) Position {
    const horizontal = @as(i64, @intCast(across));
    return .{
        .x = site.min.x + (if (site.along_x) horizontal else 0),
        .y = site.min.y + @as(i64, @intCast(up)),
        .z = site.min.z + (if (site.along_x) 0 else horizontal),
    };
}

pub const EntityKind = enum { survival_player, adventure_player, creative_player, mob_or_entity };

pub const TransitState = struct {
    portal_ticks: u16 = 0,
    cooldown_ticks: u16 = 0,

    /// Returns true once when transit should occur. The caller performs the actual
    /// dimension change and then keeps ticking this state during cooldown.
    pub fn tick(self: *TransitState, in_portal: bool, kind: EntityKind) bool {
        if (self.cooldown_ticks > 0) {
            self.cooldown_ticks -= 1;
            self.portal_ticks = 0;
            return false;
        }
        if (!in_portal) {
            self.portal_ticks = 0;
            return false;
        }
        if (kind == .creative_player or kind == .mob_or_entity) {
            self.portal_ticks = 0;
            self.cooldown_ticks = PORTAL_POST_TRANSIT_COOLDOWN_TICKS;
            return true;
        }
        self.portal_ticks += 1;
        if (self.portal_ticks < PORTAL_TRIGGER_TICKS) return false;
        self.portal_ticks = 0;
        self.cooldown_ticks = PORTAL_POST_TRANSIT_COOLDOWN_TICKS;
        return true;
    }
};

pub fn validatePortalFrame(lookup: *const fn (context: *const anyopaque, position: Position) BlockId, context: *const anyopaque, site: PortalFrameSite) bool {
    const blocks = generateFrame(site);
    var obsidian_count: usize = 0;
    for (blocks) |entry| {
        if (entry.block != .obsidian) continue;
        const actual = lookup(context, entry.position);
        if (actual == .obsidian) obsidian_count += 1;
    }
    if (obsidian_count < FRAME_OBSIDIAN_COUNT) return false;
    var up: usize = 1;
    while (up < FRAME_HEIGHT - 1) : (up += 1) {
        var across: usize = 1;
        while (across < FRAME_WIDTH - 1) : (across += 1) {
            const interior = lookup(context, framePosition(site, across, up));
            if (interior != .air and interior != .nether_portal) return false;
        }
    }
    return true;
}

test "coordinate scaling uses floor division for negative overworld positions" {
    try std.testing.expectEqual(Position{ .x = -2, .y = 64, .z = -1 }, overworldToNether(.{ .x = -9, .y = 64, .z = -1 }));
    try std.testing.expectEqual(Position{ .x = 2, .y = 64, .z = -2 }, overworldToNether(.{ .x = 23, .y = 64, .z = -16 }));
}

test "coordinate scaling maps positive coordinates to one eighth" {
    try std.testing.expectEqual(Position{ .x = 20, .y = 70, .z = 30 }, overworldToNether(.{ .x = 160, .y = 70, .z = 240 }));
}

test "nether coordinates map to eight times overworld coordinates" {
    try std.testing.expectEqual(Position{ .x = 160, .y = 70, .z = -240 }, netherToOverworld(.{ .x = 20, .y = 70, .z = -30 }));
}

test "Y coordinate clamps at both world bounds during conversion" {
    try std.testing.expectEqual(@as(i64, 0), overworldToNether(.{ .x = 0, .y = -40, .z = 0 }).y);
    try std.testing.expectEqual(@as(i64, 255), netherToOverworld(.{ .x = 0, .y = 900, .z = 0 }).y);
}

test "conversion selects the source dimension mapping" {
    try std.testing.expectEqual(Position{ .x = 2, .y = 5, .z = 3 }, convertPosition(.overworld, .{ .x = 16, .y = 5, .z = 24 }));
    try std.testing.expectEqual(Position{ .x = 16, .y = 5, .z = 24 }, convertPosition(.nether, .{ .x = 2, .y = 5, .z = 3 }));
}

test "search links to nearest active destination portal" {
    const portals = [_]Portal{
        .{ .position = .{ .x = 6, .y = 80, .z = 5 }, .dimension = .nether },
        .{ .position = .{ .x = 1, .y = 64, .z = 0 }, .dimension = .nether },
    };
    const found = findDestinationPortal(&portals, .overworld, .{ .x = 8, .y = 64, .z = 0 }).?;
    try std.testing.expectEqual(@as(i64, 1), found.position.x);
}

test "search includes portal exactly 128 blocks horizontally away" {
    const portals = [_]Portal{.{ .position = .{ .x = 128, .y = 64, .z = 0 }, .dimension = .nether }};
    try std.testing.expect(findDestinationPortal(&portals, .overworld, .{ .x = 0, .y = 64, .z = 0 }) != null);
}

test "search excludes portal beyond horizontal 128 block radius" {
    const portals = [_]Portal{.{ .position = .{ .x = 129, .y = 64, .z = 0 }, .dimension = .nether }};
    try std.testing.expect(findDestinationPortal(&portals, .overworld, .{ .x = 0, .y = 64, .z = 0 }) == null);
}

test "search radius uses horizontal circle rather than per-axis bounds" {
    const portals = [_]Portal{.{ .position = .{ .x = 100, .y = 64, .z = 100 }, .dimension = .nether }};
    try std.testing.expect(findDestinationPortal(&portals, .overworld, .{ .x = 0, .y = 64, .z = 0 }) == null);
}

test "search ignores inactive portals" {
    const portals = [_]Portal{.{ .position = .{ .x = 0, .y = 64, .z = 0 }, .dimension = .nether, .active = false }};
    try std.testing.expect(findDestinationPortal(&portals, .overworld, .{ .x = 0, .y = 64, .z = 0 }) == null);
}

test "search ignores source dimension portals" {
    const portals = [_]Portal{.{ .position = .{ .x = 0, .y = 64, .z = 0 }, .dimension = .overworld }};
    try std.testing.expect(findDestinationPortal(&portals, .overworld, .{ .x = 0, .y = 64, .z = 0 }) == null);
}

test "search ranks candidates by full three dimensional distance" {
    const portals = [_]Portal{
        .{ .position = .{ .x = 0, .y = 100, .z = 0 }, .dimension = .nether },
        .{ .position = .{ .x = 10, .y = 64, .z = 0 }, .dimension = .nether },
    };
    const found = findDestinationPortal(&portals, .overworld, .{ .x = 0, .y = 64, .z = 0 }).?;
    try std.testing.expectEqual(@as(i64, 10), found.position.x);
}

test "search returns null when no destination portal is in range" {
    const portals = [_]Portal{};
    try std.testing.expect(findDestinationPortal(&portals, .nether, .{ .x = 5, .y = 70, .z = 9 }) == null);
}

test "safest generation site prefers the highest safety score" {
    const Safety = struct {
        fn score(_: *const anyopaque, site: PortalFrameSite) u8 {
            return if (site.min.x == 0 and site.min.z == 0) 1 else if (site.min.x == 4 and site.min.z == 0) 9 else 0;
        }
    };
    const context: u8 = 0;
    const best = findSafestFrameSite(.{ .x = 0, .y = 64, .z = 0 }, &context, Safety.score).?;
    try std.testing.expectEqual(@as(i64, 4), best.site.min.x);
    try std.testing.expectEqual(@as(u8, 9), best.safety_score);
}

test "generated frame base height stays within world bounds" {
    const Safety = struct {
        fn score(_: *const anyopaque, _: PortalFrameSite) u8 {
            return 1;
        }
    };
    const context: u8 = 0;
    const site = findSafestFrameSite(.{ .x = 0, .y = 255, .z = 0 }, &context, Safety.score).?.site;
    try std.testing.expectEqual(FRAME_MAX_BASE_Y, site.min.y);
    for (generateFrame(site)) |entry| try std.testing.expect(entry.position.y <= MAX_WORLD_Y);
}

test "safest generation site uses distance to break equal scores" {
    const Safety = struct {
        fn score(_: *const anyopaque, site: PortalFrameSite) u8 {
            return if (site.min.x == 0 and site.min.z == 0) 3 else if (site.min.x == 4 and site.min.z == 0) 3 else 0;
        }
    };
    const context: u8 = 0;
    const best = findSafestFrameSite(.{ .x = 0, .y = 64, .z = 0 }, &context, Safety.score).?;
    try std.testing.expectEqual(@as(i64, 0), best.site.min.x);
}

test "destination resolution generates a frame when no portal is in range" {
    const Safety = struct {
        fn score(_: *const anyopaque, site: PortalFrameSite) u8 {
            return if (site.min.x == 0 and site.min.z == 0) 1 else 0;
        }
    };
    const portals = [_]Portal{};
    const context: u8 = 0;
    const destination = resolveDestination(&portals, .overworld, .{ .x = 0, .y = 64, .z = 0 }, &context, Safety.score).?;
    switch (destination) {
        .linked => return error.ExpectedGeneratedFrame,
        .generated => |frame| {
            try std.testing.expectEqual(@as(usize, 10), countBlocks(&frame, .obsidian));
            try std.testing.expectEqual(@as(usize, 6), countBlocks(&frame, .nether_portal));
        },
    }
}

fn countBlocks(blocks: []const FrameBlock, block: BlockId) usize {
    var count: usize = 0;
    for (blocks) |entry| if (entry.block == block) { count += 1; };
    return count;
}

test "frame generation emits ten obsidian and six portal blocks" {
    const blocks = generateFrame(.{ .min = .{ .x = 10, .y = 20, .z = 30 }, .along_x = true });
    var obsidian: usize = 0;
    var portal: usize = 0;
    for (blocks) |entry| {
        if (entry.block == .obsidian) obsidian += 1;
        if (entry.block == .nether_portal) portal += 1;
    }
    try std.testing.expectEqual(@as(usize, 10), obsidian);
    try std.testing.expectEqual(@as(usize, 6), portal);
}

test "frame generation keeps a two by three interior" {
    const blocks = generateFrame(.{ .min = .{ .x = 0, .y = 10, .z = 0 }, .along_x = true });
    for (blocks[FRAME_OBSIDIAN_COUNT..]) |entry| try std.testing.expectEqual(BlockId.nether_portal, entry.block);
    try std.testing.expectEqual(Position{ .x = 1, .y = 11, .z = 0 }, blocks[FRAME_OBSIDIAN_COUNT].position);
}

test "frame generation supports vertical plane along Z" {
    const blocks = generateFrame(.{ .min = .{ .x = 5, .y = 7, .z = 9 }, .along_x = false });
    try std.testing.expectEqual(Position{ .x = 5, .y = 7, .z = 10 }, blocks[0].position);
    try std.testing.expectEqual(Position{ .x = 5, .y = 11, .z = 10 }, blocks[1].position);
}

test "frame validation accepts minimum complete portal" {
    const Mock = struct {
        fn get(_: *const anyopaque, position: Position) BlockId {
            const frame = generateFrame(.{ .min = .{ .x = 10, .y = 20, .z = 30 }, .along_x = true });
            for (frame) |entry| if (std.meta.eql(entry.position, position)) return entry.block;
            return .air;
        }
    };
    const context: u8 = 0;
    try std.testing.expect(validatePortalFrame(Mock.get, &context, .{ .min = .{ .x = 10, .y = 20, .z = 30 }, .along_x = true }));
}

test "frame validation rejects missing obsidian" {
    const Mock = struct {
        fn get(_: *const anyopaque, position: Position) BlockId {
            const frame = generateFrame(.{ .min = .{ .x = 0, .y = 0, .z = 0 }, .along_x = true });
            for (frame, 0..) |entry, i| if (std.meta.eql(entry.position, position)) return if (i == 0) .air else entry.block;
            return .air;
        }
    };
    const context: u8 = 0;
    try std.testing.expect(!validatePortalFrame(Mock.get, &context, .{ .min = .{ .x = 0, .y = 0, .z = 0 }, .along_x = true }));
}

test "frame validation accepts an air filled two by three interior" {
    const Mock = struct {
        fn get(_: *const anyopaque, position: Position) BlockId {
            const frame = generateFrame(.{ .min = .{ .x = 0, .y = 0, .z = 0 }, .along_x = true });
            for (frame) |entry| if (entry.block == .obsidian and std.meta.eql(entry.position, position)) return .obsidian;
            return .air;
        }
    };
    const context: u8 = 0;
    try std.testing.expect(validatePortalFrame(Mock.get, &context, .{ .min = .{ .x = 0, .y = 0, .z = 0 }, .along_x = true }));
}

test "survival player transit begins after exactly 80 ticks" {
    var state = TransitState{};
    for (0..79) |_| try std.testing.expect(!state.tick(true, .survival_player));
    try std.testing.expect(state.tick(true, .survival_player));
}

test "adventure player transit begins after exactly 80 ticks" {
    var state = TransitState{};
    for (0..79) |_| try std.testing.expect(!state.tick(true, .adventure_player));
    try std.testing.expect(state.tick(true, .adventure_player));
}

test "leaving the portal resets player transit countdown" {
    var state = TransitState{};
    for (0..40) |_| _ = state.tick(true, .survival_player);
    try std.testing.expect(!state.tick(false, .survival_player));
    try std.testing.expectEqual(@as(u16, 0), state.portal_ticks);
}

test "creative player transits instantly" {
    var state = TransitState{};
    try std.testing.expect(state.tick(true, .creative_player));
}

test "mobs and other entities transit instantly" {
    var state = TransitState{};
    try std.testing.expect(state.tick(true, .mob_or_entity));
}

test "transit sets a 300 tick anti-loop cooldown" {
    var state = TransitState{};
    try std.testing.expect(state.tick(true, .creative_player));
    try std.testing.expectEqual(PORTAL_POST_TRANSIT_COOLDOWN_TICKS, state.cooldown_ticks);
}

test "cooldown prevents transit for all 300 ticks" {
    var state = TransitState{ .cooldown_ticks = PORTAL_POST_TRANSIT_COOLDOWN_TICKS };
    for (0..300) |_| try std.testing.expect(!state.tick(true, .creative_player));
    try std.testing.expectEqual(@as(u16, 0), state.cooldown_ticks);
    try std.testing.expect(state.tick(true, .creative_player));
}

test "entity outside a portal does not transit" {
    var state = TransitState{};
    try std.testing.expect(!state.tick(false, .mob_or_entity));
}
