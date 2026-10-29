const std = @import("std");

/// Local coordinate-space layout for a compact, multi-level Trial Chamber.
pub const FOOTPRINT_X: i32 = 64;
pub const FOOTPRINT_Y: i32 = 32;
pub const FOOTPRINT_Z: i32 = 64;
pub const MIN_SPAWNER_CLEARANCE: i32 = 6;
pub const SPAWNER_HEADROOM: i32 = 3;

pub const RoomType = enum { entrance_corridor, combat_chamber, intersection_junction, vault_alcove };
pub const Theme = enum { standard, swamp_bogged, ominous };
pub const VaultType = enum { standard, ominous };

pub const Block = enum {
    air,
    tuff_bricks,
    polished_tuff,
    chiseled_tuff,
    tuff_stairs,
    tuff_slab,
    copper_block,
    exposed_copper_block,
    weathered_copper_block,
    cut_copper,
    exposed_cut_copper,
    weathered_cut_copper,
    copper_grate,
    exposed_copper_grate,
    weathered_copper_grate,
    copper_bulb,
    exposed_copper_bulb,
    weathered_copper_bulb,
    waxed_oxidized_copper,
    waxed_oxidized_cut_copper,
    waxed_oxidized_copper_grate,
    waxed_oxidized_copper_bulb,
    trial_spawner,
    vault,
    ominous_vault,
    dispenser,
    tripwire_hook,
    tripwire,
    scaffolding,
    water,
};

pub const Vec3i = struct { x: i32, y: i32, z: i32 };
pub const Aabb = struct {
    min: Vec3i,
    max: Vec3i, // exclusive

    pub fn valid(self: Aabb) bool {
        return self.min.x < self.max.x and self.min.y < self.max.y and self.min.z < self.max.z;
    }

    pub fn contains(self: Aabb, p: Vec3i) bool {
        return p.x >= self.min.x and p.x < self.max.x and p.y >= self.min.y and p.y < self.max.y and p.z >= self.min.z and p.z < self.max.z;
    }

    pub fn intersects(self: Aabb, other: Aabb) bool {
        return self.min.x < other.max.x and other.min.x < self.max.x and
            self.min.y < other.max.y and other.min.y < self.max.y and
            self.min.z < other.max.z and other.min.z < self.max.z;
    }

    pub fn width(self: Aabb) i32 {
        return self.max.x - self.min.x;
    }
    pub fn height(self: Aabb) i32 {
        return self.max.y - self.min.y;
    }
    pub fn depth(self: Aabb) i32 {
        return self.max.z - self.min.z;
    }
};

pub const Doorway = struct { from_room: u8, to_room: u8, center: Vec3i, axis: Axis, width: u8 = 3, height: u8 = 4 };
pub const Axis = enum { x, z };
pub const Room = struct { kind: RoomType, bounds: Aabb, level: u8 = 0 };
pub const Site = struct {
    bedrock_y: i32 = 0,
    solid_foundation_y: i32,
    ceiling_y: i32 = 64,
    open_void: bool = false,
};

pub const Palette = struct {
    masonry: Block = .tuff_bricks,
    trim: Block = .polished_tuff,
    carved: Block = .chiseled_tuff,
    stairs: Block = .tuff_stairs,
    slab: Block = .tuff_slab,
    copper: Block = .copper_block,
    cut_copper: Block = .cut_copper,
    grate: Block = .copper_grate,
    bulb: Block = .copper_bulb,
    oxidation_stage: u2 = 0,
};

pub const TrapPayload = enum { poison_tipped_arrows, slowness_tipped_arrows, lingering_potion_vent, water_bucket_current };
pub const Trap = struct {
    dispenser: Vec3i,
    hook_a: Vec3i,
    hook_b: Vec3i,
    payload: TrapPayload,
    ejection_vector: [3]f32,
    has_tripwire: bool = true,
    above_scaffolding: bool = false,
};

pub const SpawnerSocket = struct { position: Vec3i, foundation: bool = true, clear_air_above: u8 = SPAWNER_HEADROOM };
pub const VaultPlacement = struct { position: Vec3i, kind: VaultType, alcove_room: u8, line_of_sight_to_entrance: bool = true };

pub const Layout = struct {
    origin: Vec3i,
    footprint: Aabb,
    theme: Theme,
    rooms: [7]Room,
    doorways: [7]Doorway,
    palette: Palette,
    traps: [4]Trap,
    trap_count: u8 = 0,
    spawners: [4]SpawnerSocket,
    spawner_count: u8 = 0,
    vaults: [2]VaultPlacement,
    vault_count: u8 = 0,
};

pub fn defaultSite(floor_y: i32) Site {
    return .{ .solid_foundation_y = floor_y };
}

pub fn validateSite(footprint: Aabb, site: Site) bool {
    return footprint.valid() and !site.open_void and
        footprint.min.y > site.bedrock_y and
        footprint.min.y == site.solid_foundation_y + 1 and
        footprint.max.y <= site.ceiling_y;
}

pub fn roomsOverlap(rooms: []const Room) bool {
    for (rooms, 0..) |room, i| {
        if (!room.bounds.valid()) return true;
        for (rooms[i + 1 ..]) |other| if (room.bounds.intersects(other.bounds)) return true;
    }
    return false;
}

pub fn copperPalette(seed: u64) Palette {
    var state = seed;
    const stage: u2 = @truncate(nextRandom(&state) % 4);
    var result = Palette{ .oxidation_stage = stage };
    if (stage == 3) {
        result.copper = .waxed_oxidized_copper;
        result.cut_copper = .waxed_oxidized_cut_copper;
        result.grate = .waxed_oxidized_copper_grate;
        result.bulb = .waxed_oxidized_copper_bulb;
    } else if (stage == 2) {
        result.copper = .weathered_copper_block;
        result.cut_copper = .weathered_cut_copper;
        result.grate = .weathered_copper_grate;
        result.bulb = .weathered_copper_bulb;
    } else if (stage == 1) {
        result.copper = .exposed_copper_block;
        result.cut_copper = .exposed_cut_copper;
        result.grate = .exposed_copper_grate;
        result.bulb = .exposed_copper_bulb;
    }
    return result;
}

fn nextRandom(state: *u64) u64 {
    state.* = state.* *% 6364136223846793005 +% 1442695040888963407;
    return state.* ^ (state.* >> 29);
}

/// Generates a 64×32×64 room graph and feature sockets in local structure coordinates.
pub fn generate(seed: u64, origin: Vec3i, theme: Theme, site: Site) ?Layout {
    const footprint = Aabb{ .min = origin, .max = .{ .x = origin.x + FOOTPRINT_X, .y = origin.y + FOOTPRINT_Y, .z = origin.z + FOOTPRINT_Z } };
    if (!validateSite(footprint, site)) return null;
    const y = origin.y;
    const rooms = [7]Room{
        .{ .kind = .entrance_corridor, .bounds = box(origin, 2, y, 26, 14, y + 8, 38) },
        .{ .kind = .intersection_junction, .bounds = box(origin, 14, y, 22, 22, y + 8, 42) },
        .{ .kind = .combat_chamber, .bounds = box(origin, 22, y, 14, 44, y + 12, 34) },
        .{ .kind = .vault_alcove, .bounds = box(origin, 44, y + 2, 20, 50, y + 9, 28) },
        .{ .kind = .combat_chamber, .bounds = box(origin, 22, y, 42, 44, y + 12, 58), .level = 1 },
        .{ .kind = .vault_alcove, .bounds = box(origin, 44, y + 2, 46, 50, y + 9, 54) },
        .{ .kind = .entrance_corridor, .bounds = box(origin, 6, y + 14, 30, 18, y + 21, 34), .level = 1 },
    };
    if (roomsOverlap(&rooms)) return null;

    const doorways = [7]Doorway{
        .{ .from_room = 0, .to_room = 1, .center = .{ .x = origin.x + 14, .y = y + 3, .z = origin.z + 32 }, .axis = .x },
        .{ .from_room = 1, .to_room = 2, .center = .{ .x = origin.x + 22, .y = y + 3, .z = origin.z + 24 }, .axis = .x },
        .{ .from_room = 2, .to_room = 3, .center = .{ .x = origin.x + 44, .y = y + 4, .z = origin.z + 24 }, .axis = .x },
        .{ .from_room = 1, .to_room = 4, .center = .{ .x = origin.x + 22, .y = y + 3, .z = origin.z + 38 }, .axis = .x },
        .{ .from_room = 4, .to_room = 5, .center = .{ .x = origin.x + 44, .y = y + 4, .z = origin.z + 50 }, .axis = .x },
        .{ .from_room = 1, .to_room = 6, .center = .{ .x = origin.x + 12, .y = y + 4, .z = origin.z + 32 }, .axis = .x },
        .{ .from_room = 6, .to_room = 2, .center = .{ .x = origin.x + 22, .y = y + 4, .z = origin.z + 32 }, .axis = .x },
    };

    var layout = Layout{
        .origin = origin,
        .footprint = footprint,
        .theme = theme,
        .rooms = rooms,
        .doorways = doorways,
        .palette = copperPalette(seed),
        .traps = undefined,
        .spawners = undefined,
        .vaults = undefined,
    };
    layout.traps[0] = makeTrap(origin, theme, 17, 2, 32);
    layout.traps[1] = makeTrap(origin, theme, 25, 2, 24);
    layout.traps[2] = makeTrap(origin, theme, 25, 2, 50);
    layout.traps[3] = makeWaterCurrentTrap(origin, .{ .x = 32, .y = 6, .z = 34 });
    layout.trap_count = 4;
    layout.spawners = .{
        .{ .position = .{ .x = origin.x + 28, .y = y + 1, .z = origin.z + 20 } },
        .{ .position = .{ .x = origin.x + 38, .y = y + 1, .z = origin.z + 28 } },
        .{ .position = .{ .x = origin.x + 28, .y = y + 1, .z = origin.z + 48 } },
        .{ .position = .{ .x = origin.x + 38, .y = y + 1, .z = origin.z + 54 } },
    };
    layout.spawner_count = placeTrialSpawners(&layout.spawners, 4, footprint);
    layout.vaults = .{
        .{ .position = .{ .x = origin.x + 47, .y = y + 4, .z = origin.z + 24 }, .kind = if (theme == .ominous) .ominous else .standard, .alcove_room = 3 },
        .{ .position = .{ .x = origin.x + 47, .y = y + 4, .z = origin.z + 50 }, .kind = if (theme == .ominous) .ominous else .standard, .alcove_room = 5 },
    };
    layout.vault_count = placeVaults(&layout.vaults, 2, &layout.rooms, &layout.doorways);
    return layout;
}

fn box(origin: Vec3i, x0: i32, y0: i32, z0: i32, x1: i32, y1: i32, z1: i32) Aabb {
    return .{ .min = .{ .x = origin.x + x0, .y = y0, .z = origin.z + z0 }, .max = .{ .x = origin.x + x1, .y = y1, .z = origin.z + z1 } };
}

pub fn placeTrialSpawners(sockets: []SpawnerSocket, requested: usize, footprint: Aabb) u8 {
    var placed: u8 = 0;
    const limit = @min(@min(requested, sockets.len), 4);
    for (sockets[0..limit]) |socket| {
        if (!socket.foundation or socket.clear_air_above < SPAWNER_HEADROOM or !footprint.contains(socket.position)) continue;
        var clear = true;
        for (sockets[0..placed]) |prior| {
            if (manhattan(socket.position, prior.position) < MIN_SPAWNER_CLEARANCE) {
                clear = false;
                break;
            }
        }
        if (clear) {
            sockets[placed] = socket;
            placed += 1;
        }
    }
    return placed;
}

pub fn placeVaults(vaults: []VaultPlacement, requested: usize, rooms: []const Room, doorways: []const Doorway) u8 {
    var placed: u8 = 0;
    for (vaults[0..@min(@min(requested, vaults.len), 2)]) |vault| {
        if (vault.alcove_room >= rooms.len or rooms[vault.alcove_room].kind != .vault_alcove) continue;
        if (!rooms[vault.alcove_room].bounds.contains(vault.position) or !vault.line_of_sight_to_entrance) continue;
        var has_entrance_route = false;
        for (doorways) |door| {
            if (door.to_room != vault.alcove_room and door.from_room != vault.alcove_room) continue;
            if (door.center.y == vault.position.y and ((door.axis == .x and door.center.z == vault.position.z) or (door.axis == .z and door.center.x == vault.position.x))) has_entrance_route = true;
        }
        if (!has_entrance_route) continue;
        vaults[placed] = vault;
        placed += 1;
    }
    return placed;
}

pub fn connectedRoomCount(room_count: usize, doorways: []const Doorway) usize {
    if (room_count == 0) return 0;
    var seen = [_]bool{false} ** 16;
    const count = @min(room_count, seen.len);
    seen[0] = true;
    var changed = true;
    while (changed) {
        changed = false;
        for (doorways) |door| {
            if (door.from_room >= count or door.to_room >= count) continue;
            const a = seen[door.from_room];
            const b = seen[door.to_room];
            if (a and !b) {
                seen[door.to_room] = true;
                changed = true;
            }
            if (b and !a) {
                seen[door.from_room] = true;
                changed = true;
            }
        }
    }
    var total: usize = 0;
    for (seen[0..count]) |value| if (value) {
        total += 1;
    };
    return total;
}

pub fn makeTrap(origin: Vec3i, theme: Theme, x: i32, y: i32, z: i32) Trap {
    const payload: TrapPayload = switch (theme) {
        .swamp_bogged => .poison_tipped_arrows,
        .ominous => .lingering_potion_vent,
        .standard => .slowness_tipped_arrows,
    };
    return .{
        .dispenser = .{ .x = origin.x + x, .y = origin.y + y, .z = origin.z + z },
        .hook_a = .{ .x = origin.x + x - 2, .y = origin.y + y, .z = origin.z + z },
        .hook_b = .{ .x = origin.x + x + 2, .y = origin.y + y, .z = origin.z + z },
        .payload = payload,
        .ejection_vector = .{ 1.0, 0.0, 0.0 },
    };
}

pub fn makeWaterCurrentTrap(origin: Vec3i, dispenser: Vec3i) Trap {
    return .{ .dispenser = .{ .x = origin.x + dispenser.x, .y = origin.y + dispenser.y, .z = origin.z + dispenser.z }, .hook_a = .{ .x = origin.x + dispenser.x - 2, .y = origin.y + dispenser.y, .z = origin.z + dispenser.z }, .hook_b = .{ .x = origin.x + dispenser.x + 2, .y = origin.y + dispenser.y, .z = origin.z + dispenser.z }, .payload = .water_bucket_current, .ejection_vector = .{ 0.0, -1.0, 0.0 }, .above_scaffolding = true };
}

pub fn manhattan(a: Vec3i, b: Vec3i) u32 {
    return @abs(a.x - b.x) + @abs(a.y - b.y) + @abs(a.z - b.z);
}

pub fn blockAt(layout: Layout, position: Vec3i) Block {
    for (layout.traps[0..layout.trap_count]) |trap| {
        if (samePosition(position, trap.dispenser)) return .dispenser;
        if (trap.above_scaffolding and position.x == trap.dispenser.x and position.z == trap.dispenser.z and position.y == trap.dispenser.y - 1) return .scaffolding;
        if (samePosition(position, trap.hook_a) or samePosition(position, trap.hook_b)) return .tripwire_hook;
        if (position.y == trap.hook_a.y and position.z == trap.hook_a.z and position.x > trap.hook_a.x and position.x < trap.hook_b.x) return .tripwire;
    }
    for (layout.vaults[0..layout.vault_count]) |vault| if (samePosition(position, vault.position)) return if (vault.kind == .ominous) .ominous_vault else .vault;
    for (layout.spawners[0..layout.spawner_count]) |socket| if (samePosition(position, socket.position)) return .trial_spawner;

    for (layout.rooms, 0..) |room, index| {
        if (!room.bounds.contains(position)) continue;
        const x = position.x;
        const y = position.y;
        const z = position.z;
        if (y == room.bounds.min.y) {
            if (room.kind == .combat_chamber and @mod(x + z, 4) == 0) return layout.palette.grate;
            return layout.palette.masonry;
        }
        if (x == room.bounds.min.x or x == room.bounds.max.x - 1 or z == room.bounds.min.z or z == room.bounds.max.z - 1) {
            if (room.kind == .vault_alcove and y > room.bounds.min.y + 1 and y < room.bounds.max.y - 1 and (x == room.bounds.min.x or x == room.bounds.max.x - 1)) return layout.palette.carved;
            return layout.palette.trim;
        }
        if (y == room.bounds.max.y - 1) return if (room.kind == .entrance_corridor) .tuff_slab else layout.palette.masonry;
        if (room.kind == .entrance_corridor and (x == room.bounds.min.x + 1 or x == room.bounds.max.x - 2) and y == room.bounds.min.y + 5) return layout.palette.bulb;
        if (room.kind == .combat_chamber and y == room.bounds.max.y - 2 and x == @divTrunc(room.bounds.min.x + room.bounds.max.x, 2) and z == @divTrunc(room.bounds.min.z + room.bounds.max.z, 2)) return layout.palette.bulb;
        if (room.kind == .combat_chamber and y == room.bounds.min.y + 7 and (x == room.bounds.min.x + 1 or x == room.bounds.max.x - 2)) return .tuff_slab;
        if (room.kind == .intersection_junction and y == room.bounds.min.y + 1 and (x == room.bounds.min.x + 1 or x == room.bounds.max.x - 2 or z == room.bounds.min.z + 1 or z == room.bounds.max.z - 2)) return .tuff_stairs;
        if (room.kind == .combat_chamber and y == room.bounds.min.y + 1 and @mod(x + z, 4) == 0) return layout.palette.grate;
        _ = index;
        return .air;
    }
    return .air;
}

fn samePosition(a: Vec3i, b: Vec3i) bool {
    return a.x == b.x and a.y == b.y and a.z == b.z;
}

fn fixtureAt(layout: Layout, room_index: usize, x: i32, y: i32, z: i32) Block {
    const room = layout.rooms[room_index];
    if (y == room.bounds.min.y) return layout.palette.masonry;
    if (room.kind == .entrance_corridor and (x == room.bounds.min.x + 1 or x == room.bounds.max.x - 2) and y == room.bounds.min.y + 5) return layout.palette.bulb;
    if (room.kind == .combat_chamber and y == room.bounds.min.y + 1 and @mod(x + z, 4) == 0) return layout.palette.grate;
    if (room.kind == .combat_chamber and y == room.bounds.min.y + 1 and x == @divTrunc(room.bounds.min.x + room.bounds.max.x, 2) and z == @divTrunc(room.bounds.min.z + room.bounds.max.z, 2)) return .trial_spawner;
    if (room.kind == .vault_alcove and (x == room.bounds.min.x or x == room.bounds.max.x - 1)) return layout.palette.carved;
    return .air;
}

// Tests cover bounds, connectivity, palette, traps, sockets, vaults, and site rejection.
test "layout uses the requested 64 by 32 by 64 footprint" {
    const layout = generate(3, .{ .x = 0, .y = 5, .z = 0 }, .standard, defaultSite(4)).?;
    try std.testing.expectEqual(@as(i32, FOOTPRINT_X), layout.footprint.width());
    try std.testing.expectEqual(@as(i32, FOOTPRINT_Y), layout.footprint.height());
    try std.testing.expectEqual(@as(i32, FOOTPRINT_Z), layout.footprint.depth());
}

test "room boxes have positive dimensions" {
    const l = generate(1, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    for (l.rooms) |r| try std.testing.expect(r.bounds.valid());
}
test "generated rooms do not overlap" {
    const l = generate(7, .{ .x = 10, .y = 2, .z = 20 }, .standard, defaultSite(1)).?;
    try std.testing.expect(!roomsOverlap(&l.rooms));
}
test "intersecting rooms are detected" {
    const r = [_]Room{ .{ .kind = .combat_chamber, .bounds = .{ .min = .{ .x = 0, .y = 0, .z = 0 }, .max = .{ .x = 4, .y = 4, .z = 4 } } }, .{ .kind = .entrance_corridor, .bounds = .{ .min = .{ .x = 3, .y = 0, .z = 0 }, .max = .{ .x = 8, .y = 4, .z = 4 } } } };
    try std.testing.expect(roomsOverlap(&r));
}
test "touching room faces do not count as overlap" {
    const a = Aabb{ .min = .{ .x = 0, .y = 0, .z = 0 }, .max = .{ .x = 2, .y = 2, .z = 2 } };
    const b = Aabb{ .min = .{ .x = 2, .y = 0, .z = 0 }, .max = .{ .x = 4, .y = 2, .z = 2 } };
    try std.testing.expect(!a.intersects(b));
}
test "all room types are represented" {
    const l = generate(1, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    var types = [_]bool{false} ** 4;
    for (l.rooms) |r| types[@intFromEnum(r.kind)] = true;
    for (types) |v| try std.testing.expect(v);
}
test "room graph connects every room through doorway portals" {
    const l = generate(1, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    try std.testing.expectEqual(@as(usize, 7), connectedRoomCount(l.rooms.len, &l.doorways));
}
test "disconnected portal graph reports only reachable rooms" {
    const d = [_]Doorway{.{ .from_room = 0, .to_room = 1, .center = .{ .x = 0, .y = 0, .z = 0 }, .axis = .x }};
    try std.testing.expectEqual(@as(usize, 2), connectedRoomCount(3, &d));
}
test "doorways provide walkable clear portals" {
    const l = generate(1, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    for (l.doorways) |d| {
        try std.testing.expect(d.width >= 2);
        try std.testing.expect(d.height >= 3);
        try std.testing.expect(d.from_room != d.to_room);
    }
}
test "entrance hallway has arched corridor dimensions" {
    const l = generate(1, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    try std.testing.expectEqual(RoomType.entrance_corridor, l.rooms[0].kind);
    try std.testing.expect(l.rooms[0].bounds.height() >= 7);
}
test "combat chambers are two-level halls with balcony height" {
    const l = generate(1, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    try std.testing.expectEqual(@as(u8, 0), l.rooms[2].level);
    try std.testing.expectEqual(@as(u8, 1), l.rooms[4].level);
    try std.testing.expect(l.rooms[2].bounds.height() >= 10);
}
test "palette contains tuff masonry set" {
    const p = copperPalette(0);
    try std.testing.expectEqual(Block.tuff_bricks, p.masonry);
    try std.testing.expectEqual(Block.polished_tuff, p.trim);
    try std.testing.expectEqual(Block.chiseled_tuff, p.carved);
    try std.testing.expectEqual(Block.tuff_stairs, p.stairs);
    try std.testing.expectEqual(Block.tuff_slab, p.slab);
}
test "weathered palette is reproducible for equal seeds" {
    try std.testing.expectEqual(copperPalette(142).oxidation_stage, copperPalette(142).oxidation_stage);
}
test "weathering selects multiple oxidation stages" {
    var found = [_]bool{false} ** 4;
    for (0..128) |seed| found[copperPalette(seed).oxidation_stage] = true;
    for (found) |stage| try std.testing.expect(stage);
}
test "fully oxidized copper fixtures are waxed variants" {
    var palette: ?Palette = null;
    for (0..128) |seed| {
        const p = copperPalette(seed);
        if (p.oxidation_stage == 3) {
            palette = p;
            break;
        }
    }
    const p = palette.?;
    try std.testing.expectEqual(Block.waxed_oxidized_copper, p.copper);
    try std.testing.expectEqual(Block.waxed_oxidized_cut_copper, p.cut_copper);
    try std.testing.expectEqual(Block.waxed_oxidized_copper_grate, p.grate);
    try std.testing.expectEqual(Block.waxed_oxidized_copper_bulb, p.bulb);
}
test "combat floor vents use copper grate palette" {
    const l = generate(2, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    const p = Vec3i{ .x = l.rooms[2].bounds.min.x + 2, .y = l.rooms[2].bounds.min.y + 1, .z = l.rooms[2].bounds.min.z + 2 };
    try std.testing.expectEqual(l.palette.grate, blockAt(l, p));
}
test "bogged theme arms poison tipped arrows" {
    try std.testing.expectEqual(TrapPayload.poison_tipped_arrows, makeTrap(.{ .x = 0, .y = 0, .z = 0 }, .swamp_bogged, 5, 1, 5).payload);
}
test "standard theme arms slowness tipped arrows" {
    try std.testing.expectEqual(TrapPayload.slowness_tipped_arrows, makeTrap(.{ .x = 0, .y = 0, .z = 0 }, .standard, 5, 1, 5).payload);
}
test "ominous theme arms lingering potion vents" {
    try std.testing.expectEqual(TrapPayload.lingering_potion_vent, makeTrap(.{ .x = 0, .y = 0, .z = 0 }, .ominous, 5, 1, 5).payload);
}
test "tripwire spans between paired hooks through threshold" {
    const t = makeTrap(.{ .x = 10, .y = 3, .z = 10 }, .standard, 5, 2, 7);
    try std.testing.expect(t.has_tripwire);
    try std.testing.expectEqual(@as(i32, 4), t.hook_b.x - t.hook_a.x);
    try std.testing.expectEqual(t.dispenser.y, t.hook_a.y);
}
test "arrow trap ejects horizontally through the corridor" {
    const t = makeTrap(.{ .x = 0, .y = 0, .z = 0 }, .standard, 0, 0, 0);
    try std.testing.expectEqual([3]f32{ 1, 0, 0 }, t.ejection_vector);
}
test "water bucket vent sits above scaffolding and points downward" {
    const t = makeWaterCurrentTrap(.{ .x = 2, .y = 1, .z = 2 }, .{ .x = 4, .y = 8, .z = 6 });
    try std.testing.expect(t.above_scaffolding);
    try std.testing.expectEqual(TrapPayload.water_bucket_current, t.payload);
    try std.testing.expectEqual([3]f32{ 0, -1, 0 }, t.ejection_vector);
}
test "generated trap list includes a water current scaffold vent" {
    const l = generate(2, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    try std.testing.expectEqual(@as(u8, 4), l.trap_count);
    try std.testing.expectEqual(TrapPayload.water_bucket_current, l.traps[3].payload);
    try std.testing.expectEqual(Block.scaffolding, blockAt(l, .{ .x = 32, .y = 6, .z = 34 }));
}
test "spawners require foundation and three air blocks" {
    var s = [_]SpawnerSocket{ .{ .position = .{ .x = 3, .y = 2, .z = 3 }, .foundation = true, .clear_air_above = 3 }, .{ .position = .{ .x = 12, .y = 2, .z = 3 }, .foundation = false }, .{ .position = .{ .x = 21, .y = 2, .z = 3 }, .clear_air_above = 2 } };
    const n = placeTrialSpawners(&s, 3, .{ .min = .{ .x = 0, .y = 0, .z = 0 }, .max = .{ .x = 30, .y = 10, .z = 10 } });
    try std.testing.expectEqual(@as(u8, 1), n);
}
test "spawner placement enforces six block minimum clearance" {
    var s = [_]SpawnerSocket{ .{ .position = .{ .x = 3, .y = 2, .z = 3 } }, .{ .position = .{ .x = 8, .y = 2, .z = 3 } } };
    const n = placeTrialSpawners(&s, 2, .{ .min = .{ .x = 0, .y = 0, .z = 0 }, .max = .{ .x = 20, .y = 10, .z = 10 } });
    try std.testing.expectEqual(@as(u8, 1), n);
}
test "generated layout places two to four trial spawners" {
    const l = generate(1, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    try std.testing.expect(l.spawner_count >= 2 and l.spawner_count <= 4);
}
test "vaults must occupy alcoves and see chamber entrance" {
    const l = generate(1, .{ .x = 0, .y = 1, .z = 0 }, .ominous, defaultSite(0)).?;
    try std.testing.expectEqual(@as(u8, 2), l.vault_count);
    for (l.vaults[0..l.vault_count]) |v| {
        try std.testing.expect(v.line_of_sight_to_entrance);
        try std.testing.expectEqual(VaultType.ominous, v.kind);
    }
}
test "vault selector rejects inaccessible or non-alcove locations" {
    var v = [_]VaultPlacement{ .{ .position = .{ .x = 28, .y = 5, .z = 20 }, .kind = .standard, .alcove_room = 2 }, .{ .position = .{ .x = 47, .y = 5, .z = 24 }, .kind = .standard, .alcove_room = 3, .line_of_sight_to_entrance = false } };
    const l = generate(1, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    try std.testing.expectEqual(@as(u8, 0), placeVaults(&v, 2, &l.rooms, &l.doorways));
}
test "bedrock collision rejects site at or below bedrock" {
    try std.testing.expect(!validateSite(.{ .min = .{ .x = 0, .y = 0, .z = 0 }, .max = .{ .x = 64, .y = 32, .z = 64 } }, .{ .bedrock_y = 0, .solid_foundation_y = -1 }));
}
test "open void sites are rejected" {
    try std.testing.expect(generate(1, .{ .x = 0, .y = 1, .z = 0 }, .standard, .{ .solid_foundation_y = 0, .open_void = true }) == null);
}
test "site without solid foundation is rejected" {
    try std.testing.expect(generate(1, .{ .x = 0, .y = 4, .z = 0 }, .standard, defaultSite(1)) == null);
}
test "structure exceeding ceiling is rejected" {
    try std.testing.expect(generate(1, .{ .x = 0, .y = 40, .z = 0 }, .standard, .{ .solid_foundation_y = 39, .ceiling_y = 60 }) == null);
}
test "room fixture sampling exposes bulb and grate accents" {
    const l = generate(19, .{ .x = 0, .y = 1, .z = 0 }, .standard, defaultSite(0)).?;
    try std.testing.expectEqual(l.palette.bulb, fixtureAt(l, 0, l.rooms[0].bounds.min.x + 1, l.rooms[0].bounds.min.y + 5, l.rooms[0].bounds.min.z));
    try std.testing.expectEqual(l.palette.grate, fixtureAt(l, 2, l.rooms[2].bounds.min.x, l.rooms[2].bounds.min.y + 1, l.rooms[2].bounds.min.z));
}
test "block query emits vault and spawner placements" {
    const l = generate(19, .{ .x = 0, .y = 1, .z = 0 }, .ominous, defaultSite(0)).?;
    try std.testing.expectEqual(Block.ominous_vault, blockAt(l, l.vaults[0].position));
    try std.testing.expectEqual(Block.trial_spawner, blockAt(l, l.spawners[0].position));
}
