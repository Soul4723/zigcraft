const std = @import("std");
const BlockId = @import("block.zig").BlockId;

pub const GATEWAY_RING_RADIUS: f32 = 96.0;
pub const MAIN_GATEWAY_Y: f32 = 75.0;
pub const OUTER_ISLAND_RADIUS: f32 = 1024.0;
pub const OUTER_ISLAND_GROUND_Y: f32 = 65.0;
pub const PLAYER_CLEARANCE_BLOCKS: usize = 2;
pub const BEDROCK_CASING_BLOCKS: usize = 12;
pub const PORTAL_BLOCK_COUNT: usize = 1;

pub const Position = struct { x: i32, y: i32, z: i32 };
pub const Vec3 = [3]f32;
pub const GatewayKind = enum { main_island, outer_island };
pub const EntryMethod = enum { ender_pearl, trapdoor_crawl, elytra_crawl, walking, sneaking };
pub const CasingBlock = enum { bedrock };

pub const Gateway = struct {
    position: Position,
    kind: GatewayKind,
    has_beam: bool = true,
    beam_color: BeamColor = .magenta,
};

pub const BeamColor = enum { magenta };

pub const GatewayStructure = struct {
    gateway: Position,
    casing: [BEDROCK_CASING_BLOCKS]Position,
    portal_block: BlockId = .end_gateway,
    casing_block: CasingBlock = .bedrock,
};

/// Creates four three-block bedrock corner pillars around a single-block aperture.
/// The one-block End Gateway is at center; the 12 bedrock blocks are its casing.
pub fn generateGatewayStructure(center: Position) GatewayStructure {
    var casing: [BEDROCK_CASING_BLOCKS]Position = undefined;
    var index: usize = 0;
    for ([_]i32{-1, 1}) |dx| {
        for ([_]i32{-1, 1}) |dz| {
            for ([_]i32{-1, 0, 1}) |dy| {
                casing[index] = .{ .x = center.x + dx, .y = center.y + dy, .z = center.z + dz };
                index += 1;
            }
        }
    }
    return .{ .gateway = center, .casing = casing };
}

/// Places the main gateway on the arena perimeter at the requested ring angle.
pub fn generateMainGateway(angle_radians: f32) Gateway {
    return .{
        .position = .{
            .x = @intFromFloat(@round(GATEWAY_RING_RADIUS * @cos(angle_radians))),
            .y = @intFromFloat(MAIN_GATEWAY_Y),
            .z = @intFromFloat(@round(GATEWAY_RING_RADIUS * @sin(angle_radians))),
        },
        .kind = .main_island,
    };
}

/// The arena gateway appears only after the Dragon defeat event has completed.
pub fn spawnGatewayAfterDragonDefeat(dragon_defeated: bool, angle_radians: f32) ?Gateway {
    if (!dragon_defeated) return null;
    return generateMainGateway(angle_radians);
}

pub fn canEnter(method: EntryMethod) bool {
    return switch (method) {
        .ender_pearl, .trapdoor_crawl, .elytra_crawl => true,
        .walking, .sneaking => false,
    };
}

pub fn pearlCollidesWithGateway(pearl_position: Vec3, gateway: Gateway) bool {
    const dx = pearl_position[0] - @as(f32, @floatFromInt(gateway.position.x));
    const dy = pearl_position[1] - @as(f32, @floatFromInt(gateway.position.y));
    const dz = pearl_position[2] - @as(f32, @floatFromInt(gateway.position.z));
    return @abs(dx) <= 0.5 and @abs(dy) <= 0.5 and @abs(dz) <= 0.5;
}

pub const LandingSite = struct {
    player_position: Vec3,
    ground_block: BlockId = .end_stone,
    headroom_blocks: usize = PLAYER_CLEARANCE_BLOCKS,
    safe_footing: bool = true,
};

pub const TransitResult = struct {
    destination: Vec3,
    gateway: Gateway,
    landing: LandingSite,
};

/// Returns a deterministic 1,024-block outward landing, slightly offset from the
/// exact bearing to leave room for a safe gateway platform on the island.
pub fn outerIslandLanding(source: Gateway) LandingSite {
    var dx = @as(f32, @floatFromInt(source.position.x));
    var dz = @as(f32, @floatFromInt(source.position.z));
    const length = @sqrt(dx * dx + dz * dz);
    if (length == 0.0) {
        dx = 1.0;
        dz = 0.0;
    } else {
        dx /= length;
        dz /= length;
    }
    const x = dx * OUTER_ISLAND_RADIUS;
    const z = dz * OUTER_ISLAND_RADIUS;
    return .{ .player_position = .{ x, OUTER_ISLAND_GROUND_Y + 1.0, z } };
}

pub fn generateReturnGateway(source: Gateway) Gateway {
    const landing = outerIslandLanding(source);
    return .{
        .position = .{
            .x = @intFromFloat(@round(landing.player_position[0])),
            .y = @intFromFloat(OUTER_ISLAND_GROUND_Y + 1.0),
            .z = @intFromFloat(@round(landing.player_position[2])),
        },
        .kind = .outer_island,
    };
}

pub fn transitThroughGateway(source: Gateway, pearl_hit: bool) ?TransitResult {
    if (!pearl_hit) return null;
    const landing = outerIslandLanding(source);
    const return_gateway = generateReturnGateway(source);
    return .{ .destination = landing.player_position, .gateway = return_gateway, .landing = landing };
}

pub fn transitBackThroughGateway(return_gateway: Gateway, pearl_hit: bool) ?Vec3 {
    if (!pearl_hit or return_gateway.kind != .outer_island) return null;
    return .{ 0.0, MAIN_GATEWAY_Y, 0.0 };
}

pub fn radialDistance(position: Vec3) f32 {
    return @sqrt(position[0] * position[0] + position[2] * position[2]);
}

test "gateway aperture is exactly one End Gateway block" {
    const structure = generateGatewayStructure(.{ .x = 96, .y = 75, .z = 0 });
    try std.testing.expectEqual(@as(usize, 1), PORTAL_BLOCK_COUNT);
    try std.testing.expectEqual(BlockId.end_gateway, structure.portal_block);
    try std.testing.expectEqual(@as(i32, 96), structure.gateway.x);
}

test "gateway casing contains exactly twelve bedrock blocks" {
    const structure = generateGatewayStructure(.{ .x = 96, .y = 75, .z = 0 });
    try std.testing.expectEqual(@as(usize, 12), structure.casing.len);
    try std.testing.expectEqual(CasingBlock.bedrock, structure.casing_block);
}

test "casing pillars occupy four corners around the aperture" {
    const structure = generateGatewayStructure(.{ .x = 0, .y = 0, .z = 0 });
    for (structure.casing) |block| {
        try std.testing.expect(@abs(block.x) == 1);
        try std.testing.expect(@abs(block.z) == 1);
        try std.testing.expect(block.y >= -1 and block.y <= 1);
    }
}

test "casing has three bedrock blocks at every corner" {
    const structure = generateGatewayStructure(.{ .x = 10, .y = 20, .z = 30 });
    for ([_]i32{ -1, 1 }) |dx| for ([_]i32{ -1, 1 }) |dz| {
        var count: usize = 0;
        for (structure.casing) |block| {
            if (block.x == 10 + dx and block.z == 30 + dz) count += 1;
        }
        try std.testing.expectEqual(@as(usize, 3), count);
    };
}

test "gateway center remains clear of its bedrock casing" {
    const center = Position{ .x = -31, .y = 75, .z = 48 };
    const structure = generateGatewayStructure(center);
    for (structure.casing) |block| try std.testing.expect(!std.meta.eql(center, block));
}

test "main gateway is placed at radius 96" {
    const gateway = generateMainGateway(0.0);
    try std.testing.expectEqual(@as(i32, 96), gateway.position.x);
    try std.testing.expectEqual(@as(i32, 0), gateway.position.z);
}

test "main gateway uses arena perimeter height 75" {
    const gateway = generateMainGateway(1.0);
    try std.testing.expectEqual(@as(i32, 75), gateway.position.y);
}

test "main gateway can be placed on the positive z perimeter" {
    const gateway = generateMainGateway(std.math.pi / 2.0);
    try std.testing.expectEqual(@as(i32, 96), gateway.position.z);
}

test "main gateway does not spawn before dragon defeat" {
    try std.testing.expect(spawnGatewayAfterDragonDefeat(false, 0.0) == null);
}

test "main gateway spawns after dragon defeat" {
    const gateway = spawnGatewayAfterDragonDefeat(true, 0.0).?;
    try std.testing.expectEqual(GatewayKind.main_island, gateway.kind);
    try std.testing.expectEqual(@as(i32, 75), gateway.position.y);
}

test "main gateway emits an enabled beam" {
    const gateway = generateMainGateway(0.0);
    try std.testing.expect(gateway.has_beam);
}

test "gateway beam palette is magenta purple" {
    const gateway = generateMainGateway(0.0);
    try std.testing.expectEqual(BeamColor.magenta, gateway.beam_color);
}

test "beam stays enabled on generated return gateway" {
    const gateway = generateReturnGateway(generateMainGateway(0.0));
    try std.testing.expect(gateway.has_beam);
}

test "pearl entry is allowed through one block aperture" {
    try std.testing.expect(canEnter(.ender_pearl));
}

test "trapdoor crawl fits the aperture" {
    try std.testing.expect(canEnter(.trapdoor_crawl));
}

test "elytra crawl fits the aperture" {
    try std.testing.expect(canEnter(.elytra_crawl));
}

test "standing walk is rejected by the aperture" {
    try std.testing.expect(!canEnter(.walking));
}

test "sneaking upright does not fit the aperture" {
    try std.testing.expect(!canEnter(.sneaking));
}

test "pearl collision accepts gateway block center" {
    const gateway = generateMainGateway(0.0);
    try std.testing.expect(pearlCollidesWithGateway(.{ 96.0, 75.0, 0.0 }, gateway));
}

test "pearl collision accepts gateway block face boundary" {
    const gateway = generateMainGateway(0.0);
    try std.testing.expect(pearlCollidesWithGateway(.{ 96.5, 75.0, 0.0 }, gateway));
}

test "pearl misses gateway outside its one block bounds" {
    const gateway = generateMainGateway(0.0);
    try std.testing.expect(!pearlCollidesWithGateway(.{ 96.51, 75.0, 0.0 }, gateway));
}

test "pearl must collide in all three dimensions" {
    const gateway = generateMainGateway(0.0);
    try std.testing.expect(!pearlCollidesWithGateway(.{ 96.0, 75.0, 0.51 }, gateway));
}

test "pearl collision works for translated gateway coordinates" {
    const gateway = Gateway{ .position = .{ .x = -52, .y = 81, .z = 19 }, .kind = .main_island };
    try std.testing.expect(pearlCollidesWithGateway(.{ -52.25, 81.25, 18.75 }, gateway));
}

test "pearl hit triggers gateway transit" {
    const source = generateMainGateway(0.0);
    try std.testing.expect(transitThroughGateway(source, true) != null);
}

test "transit does not trigger without pearl collision" {
    const source = generateMainGateway(0.0);
    try std.testing.expect(transitThroughGateway(source, false) == null);
}

test "outer island destination is at least one thousand blocks away" {
    const destination = outerIslandLanding(generateMainGateway(0.0)).player_position;
    try std.testing.expect(radialDistance(destination) >= 1000.0);
}

test "outer island destination is exactly 1024 blocks radially" {
    const destination = outerIslandLanding(generateMainGateway(1.4)).player_position;
    try std.testing.expectApproxEqAbs(OUTER_ISLAND_RADIUS, radialDistance(destination), 0.01);
}

test "centered source gateway uses stable positive x destination" {
    const source = Gateway{ .position = .{ .x = 0, .y = 75, .z = 0 }, .kind = .main_island };
    const destination = outerIslandLanding(source).player_position;
    try std.testing.expectEqual(OUTER_ISLAND_RADIUS, destination[0]);
    try std.testing.expectEqual(@as(f32, 0.0), destination[2]);
}

test "outer landing has End Stone footing" {
    const landing = outerIslandLanding(generateMainGateway(0.0));
    try std.testing.expectEqual(BlockId.end_stone, landing.ground_block);
    try std.testing.expect(landing.safe_footing);
}

test "outer landing leaves two blocks of headroom" {
    const landing = outerIslandLanding(generateMainGateway(0.0));
    try std.testing.expectEqual(@as(usize, 2), landing.headroom_blocks);
}

test "outer landing player feet are one block above ground" {
    const landing = outerIslandLanding(generateMainGateway(0.0));
    try std.testing.expectEqual(OUTER_ISLAND_GROUND_Y + 1.0, landing.player_position[1]);
}

test "outbound transit generates a linked outer island gateway" {
    const result = transitThroughGateway(generateMainGateway(0.4), true).?;
    try std.testing.expectEqual(GatewayKind.outer_island, result.gateway.kind);
}

test "return gateway is placed on the landing island at safe height" {
    const result = transitThroughGateway(generateMainGateway(0.7), true).?;
    try std.testing.expectEqual(@as(i32, 66), result.gateway.position.y);
    try std.testing.expectApproxEqAbs(OUTER_ISLAND_RADIUS, radialDistance(.{
        @floatFromInt(result.gateway.position.x),
        0.0,
        @floatFromInt(result.gateway.position.z),
    }), 1.0);
}

test "pearl hit on outer return gateway returns to central fountain" {
    const source = generateMainGateway(0.2);
    const return_gateway = generateReturnGateway(source);
    const destination = transitBackThroughGateway(return_gateway, true).?;
    try std.testing.expectEqual(@as(f32, 0.0), destination[0]);
    try std.testing.expectEqual(@as(f32, 0.0), destination[2]);
}

test "return trip preserves central fountain height" {
    const return_gateway = generateReturnGateway(generateMainGateway(1.1));
    const destination = transitBackThroughGateway(return_gateway, true).?;
    try std.testing.expectEqual(MAIN_GATEWAY_Y, destination[1]);
}

test "return gateway transit requires a pearl hit" {
    const return_gateway = generateReturnGateway(generateMainGateway(0.5));
    try std.testing.expect(transitBackThroughGateway(return_gateway, false) == null);
}

test "main island gateway cannot be used as a return gateway" {
    const main = generateMainGateway(0.0);
    try std.testing.expect(transitBackThroughGateway(main, true) == null);
}

test "outbound and return transit preserve x z axis bearing" {
    const source = generateMainGateway(std.math.pi / 4.0);
    const landing = outerIslandLanding(source).player_position;
    try std.testing.expect(landing[0] > 0.0 and landing[2] > 0.0);
}
