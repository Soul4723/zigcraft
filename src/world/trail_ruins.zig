const std = @import("std");

// ============================================================================
// Milestone 385: Trail Ruins Buried Terracotta Settlements, Four Armor Trims,
// Music Disc Relic & Workstations
// ============================================================================

/// Biomes where Trail Ruins generate in Minecraft (Taiga, Jungle, and Birch Forest families).
pub const TrailRuinBiome = enum {
    taiga,
    snowy_taiga,
    old_growth_pine_taiga,
    old_growth_spruce_taiga,
    jungle,
    sparse_jungle,
    bamboo_jungle,
    birch_forest,
    old_growth_birch_forest,
    // Non-trail biomes for rejection testing:
    plains,
    desert,
    savanna,
    badlands,
    swamp,
    dark_forest,
    ocean,
    nether_wastes,
    the_end,

    /// Returns true if this biome is an authentic habitat for Trail Ruins generation.
    pub fn isValidTrailRuinBiome(self: TrailRuinBiome) bool {
        return switch (self) {
            .taiga,
            .snowy_taiga,
            .old_growth_pine_taiga,
            .old_growth_spruce_taiga,
            .jungle,
            .sparse_jungle,
            .bamboo_jungle,
            .birch_forest,
            .old_growth_birch_forest,
            => true,
            else => false,
        };
    }
};

/// The six craft and artisan workstations found inside Trail Ruin guild rooms.
pub const TrailRuinWorkstation = enum(u8) {
    loom = 0,
    cartography_table = 1,
    smithing_table = 2,
    grindstone = 3,
    stonecutter = 4,
    kiln_furnace = 5,

    pub const count: usize = 6;

    pub const all = [_]TrailRuinWorkstation{
        .loom,
        .cartography_table,
        .smithing_table,
        .grindstone,
        .stonecutter,
        .kiln_furnace,
    };

    pub fn name(self: TrailRuinWorkstation) []const u8 {
        return switch (self) {
            .loom => "Loom",
            .cartography_table => "Cartography Table",
            .smithing_table => "Smithing Table",
            .grindstone => "Grindstone",
            .stonecutter => "Stonecutter",
            .kiln_furnace => "Kiln Furnace",
        };
    }

    pub fn guildName(self: TrailRuinWorkstation) []const u8 {
        return switch (self) {
            .loom => "Weavers Guild",
            .cartography_table => "Cartographers Guild",
            .smithing_table => "Blacksmiths Guild",
            .grindstone => "Armory Guild",
            .stonecutter => "Masons Guild",
            .kiln_furnace => "Potters Guild",
        };
    }
};

/// Blocks present in Trail Ruins structures and archaeological digs.
pub const TrailRuinBlock = enum(u8) {
    air = 0,
    cobblestone = 1,
    mud_bricks = 2,
    packed_mud = 3,
    terracotta = 4,
    orange_terracotta = 5,
    yellow_terracotta = 6,
    red_terracotta = 7,
    light_gray_terracotta = 8,
    blue_terracotta = 9,
    cyan_terracotta = 10,
    white_terracotta = 11,
    gravel = 12,
    suspicious_gravel = 13,
    coarse_dirt = 14,
    stone_bricks = 15,
    oak_planks = 16,
    // Workstations
    loom = 20,
    cartography_table = 21,
    smithing_table = 22,
    grindstone = 23,
    stonecutter = 24,
    kiln_furnace = 25,

    pub fn isWorkstation(self: TrailRuinBlock) bool {
        return switch (self) {
            .loom, .cartography_table, .smithing_table, .grindstone, .stonecutter, .kiln_furnace => true,
            else => false,
        };
    }

    pub fn isRoadMaterial(self: TrailRuinBlock) bool {
        return self == .cobblestone or self == .mud_bricks;
    }
};

/// 3D Axis-Aligned Bounding Box.
pub const BoundingBox3D = struct {
    min_x: i32,
    min_y: i32,
    min_z: i32,
    max_x: i32,
    max_y: i32,
    max_z: i32,

    pub fn contains(self: BoundingBox3D, x: i32, y: i32, z: i32) bool {
        return x >= self.min_x and x <= self.max_x and
            y >= self.min_y and y <= self.max_y and
            z >= self.min_z and z <= self.max_z;
    }

    pub fn height(self: BoundingBox3D) i32 {
        return self.max_y - self.min_y + 1;
    }

    pub fn volume(self: BoundingBox3D) i32 {
        return (self.max_x - self.min_x + 1) *
            (self.max_y - self.min_y + 1) *
            (self.max_z - self.min_z + 1);
    }
};

/// A side guild room branching off the main underground road.
pub const GuildRoom = struct {
    name: []const u8,
    workstation: TrailRuinWorkstation,
    workstation_pos: [3]i32,
    bounds: BoundingBox3D,
    suspicious_gravel_pos: [3]i32,
};

/// Layout generator and structural model for a Trail Ruin.
pub const TrailRuinLayout = struct {
    origin_x: i32,
    ground_y: i32,
    origin_z: i32,
    biome: TrailRuinBiome,
    /// Height of the surface tower crown protruding above the ground (strictly 1..3 blocks).
    crown_protrusion_height: u8,
    /// Absolute Y coordinate of the topmost block of the protruding crown.
    tower_top_y: i32,
    /// Absolute Y coordinate of the tower base where it joins the underground road.
    tower_base_y: i32,
    /// Absolute Y coordinate of the underground main road.
    road_y: i32,
    /// Length of the cobblestone / mud-brick road.
    road_length: u16,
    /// Width of the road corridor.
    road_width: u8,
    /// Side guild rooms attached along the main road.
    guild_rooms: [6]GuildRoom,

    /// Deterministically generates a TrailRuinLayout. Returns null if the biome is invalid.
    pub fn generate(seed: u64, origin_x: i32, ground_y: i32, origin_z: i32, biome: TrailRuinBiome) ?TrailRuinLayout {
        if (!biome.isValidTrailRuinBiome()) return null;

        // Deterministic pseudo-random derivation for protrusion: strictly 1..3 blocks
        const hash = seed ^ (@as(u64, @bitCast(@as(i64, origin_x))) *% 73856093) ^ (@as(u64, @bitCast(@as(i64, origin_z))) *% 19349663);
        const protrusion: u8 = @as(u8, @intCast(1 + (hash % 3))); // 1, 2, or 3

        return initWithProtrusion(origin_x, ground_y, origin_z, biome, protrusion);
    }

    /// Explicitly initializes a TrailRuinLayout with a given crown protrusion clamped to 1..3.
    pub fn initWithProtrusion(origin_x: i32, ground_y: i32, origin_z: i32, biome: TrailRuinBiome, protrusion: u8) ?TrailRuinLayout {
        if (!biome.isValidTrailRuinBiome()) return null;

        const clamped_protrusion = std.math.clamp(protrusion, @as(u8, 1), @as(u8, 3));
        const tower_top = ground_y + @as(i32, clamped_protrusion);
        const depth: i32 = 14;
        const road_level = ground_y - depth;
        const tower_base = road_level;
        const r_length: u16 = 36;
        const r_width: u8 = 3;

        // Build 6 side guild rooms positioned along both sides of the main road.
        var rooms: [6]GuildRoom = undefined;
        const ws_list = TrailRuinWorkstation.all;
        var i: usize = 0;
        while (i < 6) : (i += 1) {
            const ws = ws_list[i];
            const is_left = (i % 2 == 0);
            const z_offset: i32 = 4 + @as(i32, @intCast(i)) * 5;
            const x_offset: i32 = if (is_left) -6 else 4;

            const room_min_x = origin_x + x_offset;
            const room_max_x = room_min_x + 4;
            const room_min_y = road_level;
            const room_max_y = road_level + 4;
            const room_min_z = origin_z + z_offset;
            const room_max_z = room_min_z + 4;

            const ws_x = room_min_x + 2;
            const ws_y = road_level + 1;
            const ws_z = room_min_z + 2;

            const sg_x = room_min_x + 1;
            const sg_y = road_level + 1;
            const sg_z = room_min_z + 1;

            rooms[i] = GuildRoom{
                .name = ws.guildName(),
                .workstation = ws,
                .workstation_pos = .{ ws_x, ws_y, ws_z },
                .bounds = .{
                    .min_x = room_min_x,
                    .min_y = room_min_y,
                    .min_z = room_min_z,
                    .max_x = room_max_x,
                    .max_y = room_max_y,
                    .max_z = room_max_z,
                },
                .suspicious_gravel_pos = .{ sg_x, sg_y, sg_z },
            };
        }

        return TrailRuinLayout{
            .origin_x = origin_x,
            .ground_y = ground_y,
            .origin_z = origin_z,
            .biome = biome,
            .crown_protrusion_height = clamped_protrusion,
            .tower_top_y = tower_top,
            .tower_base_y = tower_base,
            .road_y = road_level,
            .road_length = r_length,
            .road_width = r_width,
            .guild_rooms = rooms,
        };
    }

    /// Returns true if the block at Y is part of the surface tower crown protruding above ground.
    pub fn isCrownProtrusionY(self: TrailRuinLayout, y: i32) bool {
        return y > self.ground_y and y <= self.tower_top_y;
    }

    /// Returns true if the position lies within the underground structure.
    pub fn isUndergroundY(self: TrailRuinLayout, y: i32) bool {
        return y <= self.ground_y and y >= self.road_y;
    }

    /// Finds a guild room by its workstation kind.
    pub fn findGuildRoom(self: TrailRuinLayout, ws: TrailRuinWorkstation) ?GuildRoom {
        for (self.guild_rooms) |room| {
            if (room.workstation == ws) return room;
        }
        return null;
    }

    /// Checks if all 6 canonical workstations exist in the layout.
    pub fn hasAllWorkstations(self: TrailRuinLayout) bool {
        for (TrailRuinWorkstation.all) |ws| {
            if (self.findGuildRoom(ws) == null) return false;
        }
        return true;
    }

    /// Returns the block at a specific world coordinate within this layout.
    pub fn getBlockAt(self: TrailRuinLayout, x: i32, y: i32, z: i32) TrailRuinBlock {
        // 1. Check guild room workstations & suspicious gravel
        for (self.guild_rooms) |room| {
            if (x == room.workstation_pos[0] and y == room.workstation_pos[1] and z == room.workstation_pos[2]) {
                return switch (room.workstation) {
                    .loom => .loom,
                    .cartography_table => .cartography_table,
                    .smithing_table => .smithing_table,
                    .grindstone => .grindstone,
                    .stonecutter => .stonecutter,
                    .kiln_furnace => .kiln_furnace,
                };
            }
            if (x == room.suspicious_gravel_pos[0] and y == room.suspicious_gravel_pos[1] and z == room.suspicious_gravel_pos[2]) {
                return .suspicious_gravel;
            }
            if (room.bounds.contains(x, y, z)) {
                if (y == room.bounds.min_y) {
                    return if (@mod(x + z, 2) == 0) .mud_bricks else .cobblestone;
                }
                if (x == room.bounds.min_x or x == room.bounds.max_x or z == room.bounds.min_z or z == room.bounds.max_z) {
                    return .terracotta;
                }
                return .air;
            }
        }

        // 2. Check main road corridor along Z: width = 3, length = road_length
        const half_w = @as(i32, @intCast(self.road_width / 2));
        const in_road_x = (x >= self.origin_x - half_w and x <= self.origin_x + half_w);
        const in_road_z = (z >= self.origin_z and z <= self.origin_z + @as(i32, @intCast(self.road_length)));

        if (in_road_x and in_road_z) {
            if (y == self.road_y) {
                // Cobblestone and mud bricks road floor
                return if (@mod(x + z, 2) == 0) .cobblestone else .mud_bricks;
            }
            if (y > self.road_y and y <= self.road_y + 3) {
                return .air; // Walkway clearance
            }
        }

        // 3. Tower footprint: 5x5 centered around origin_x, origin_z
        const in_tower_x = (x >= self.origin_x - 2 and x <= self.origin_x + 2);
        const in_tower_z = (z >= self.origin_z - 2 and z <= self.origin_z + 2);

        if (in_tower_x and in_tower_z) {
            if (self.isCrownProtrusionY(y)) {
                // Surface tower crown
                return if (@mod(y, 2) == 0) .terracotta else .orange_terracotta;
            }
            if (y <= self.ground_y and y >= self.tower_base_y) {
                // Tower walls vs interior
                const is_wall = (x == self.origin_x - 2 or x == self.origin_x + 2 or z == self.origin_z - 2 or z == self.origin_z + 2);
                if (is_wall) {
                    const layer = @as(u32, @bitCast(@mod(y, 4)));
                    return switch (layer) {
                        0 => .mud_bricks,
                        1 => .yellow_terracotta,
                        2 => .red_terracotta,
                        else => .cobblestone,
                    };
                }
                // Tower interior has gravel / suspicious gravel deposits
                if (y == self.tower_base_y + 1) {
                    return if (x == self.origin_x and z == self.origin_z) .suspicious_gravel else .gravel;
                }
                return .air;
            }
        }

        return .air;
    }
};

// ============================================================================
// Armor Trim Templates & Duplication
// ============================================================================

/// The 4 armor trim templates found exclusively in Trail Ruins suspicious gravel.
pub const TrailRuinTrimTemplate = enum(u8) {
    wayfinder = 0,
    raiser = 1,
    shaper = 2,
    host = 3,

    pub const count: usize = 4;

    pub const all = [_]TrailRuinTrimTemplate{
        .wayfinder,
        .raiser,
        .shaper,
        .host,
    };

    pub fn isTrailRuinExclusiveTrim(self: TrailRuinTrimTemplate) bool {
        _ = self;
        return true;
    }

    pub fn name(self: TrailRuinTrimTemplate) []const u8 {
        return switch (self) {
            .wayfinder => "Wayfinder Armor Trim",
            .raiser => "Raiser Armor Trim",
            .shaper => "Shaper Armor Trim",
            .host => "Host Armor Trim",
        };
    }

    pub fn requiredDuplicationMaterial(self: TrailRuinTrimTemplate) []const u8 {
        _ = self;
        return "terracotta";
    }
};

/// Returns true if a given trim template is one of the four Trail Ruins exclusive trims.
pub fn isTrailRuinExclusiveTrim(trim: anytype) bool {
    const T = @TypeOf(trim);
    if (T == TrailRuinTrimTemplate) return true;
    switch (@typeInfo(T)) {
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice or (ptr_info.size == .one and @typeInfo(ptr_info.child) == .array)) {
                const s: []const u8 = trim;
                return std.mem.eql(u8, s, "wayfinder") or
                    std.mem.eql(u8, s, "raiser") or
                    std.mem.eql(u8, s, "shaper") or
                    std.mem.eql(u8, s, "host");
            }
        },
        .enum_literal, .@"enum" => {
            const tag_name = @tagName(trim);
            return std.mem.eql(u8, tag_name, "wayfinder") or
                std.mem.eql(u8, tag_name, "raiser") or
                std.mem.eql(u8, tag_name, "shaper") or
                std.mem.eql(u8, tag_name, "host");
        },
        else => {},
    }
    return false;
}

/// Result of duplicating a Trail Ruin trim template.
pub const TrimDuplicationResult = struct {
    success: bool,
    templates_out: u8,
    diamonds_used: u8,
    terracotta_used: u8,
    templates_consumed: u8,
    diamonds_remaining: u8,
    terracotta_remaining: u8,
    templates_total: u8,
};

/// Duplicates Trail Ruin armor trim templates.
/// Recipe: 7 diamonds + 1 terracotta + 1 template -> 2 templates.
pub fn duplicateTrailRuinTrim(diamonds: u8, terracotta: u8, templates: u8) TrimDuplicationResult {
    const DIAMONDS_PER_CRAFT: u8 = 7;
    const TERRACOTTA_PER_CRAFT: u8 = 1;
    const TEMPLATES_PER_CRAFT: u8 = 1;
    const TEMPLATES_PRODUCED_PER_CRAFT: u8 = 2;

    if (diamonds < DIAMONDS_PER_CRAFT or terracotta < TERRACOTTA_PER_CRAFT or templates < TEMPLATES_PER_CRAFT) {
        return .{
            .success = false,
            .templates_out = 0,
            .diamonds_used = 0,
            .terracotta_used = 0,
            .templates_consumed = 0,
            .diamonds_remaining = diamonds,
            .terracotta_remaining = terracotta,
            .templates_total = templates,
        };
    }

    const crafts_from_diamonds = diamonds / DIAMONDS_PER_CRAFT;
    const crafts = @min(templates, @min(crafts_from_diamonds, terracotta));

    const dia_used = crafts * DIAMONDS_PER_CRAFT;
    const terra_used = crafts * TERRACOTTA_PER_CRAFT;
    const tpl_consumed = crafts * TEMPLATES_PER_CRAFT;
    const tpl_out = crafts * TEMPLATES_PRODUCED_PER_CRAFT;

    return .{
        .success = (crafts > 0),
        .templates_out = tpl_out,
        .diamonds_used = dia_used,
        .terracotta_used = terra_used,
        .templates_consumed = tpl_consumed,
        .diamonds_remaining = diamonds - dia_used,
        .terracotta_remaining = terracotta - terra_used,
        .templates_total = (templates - tpl_consumed) + tpl_out,
    };
}

// ============================================================================
// Pottery Sherds
// ============================================================================

/// The 7 archaeological pottery sherds exclusive to Trail Ruins.
pub const TrailRuinPotterySherd = enum(u8) {
    burn = 0,
    danger = 1,
    friend = 2,
    heart = 3,
    heartbreak = 4,
    howl = 5,
    sheaf = 6,

    pub const count: usize = 7;

    pub const all = [_]TrailRuinPotterySherd{
        .burn,
        .danger,
        .friend,
        .heart,
        .heartbreak,
        .howl,
        .sheaf,
    };

    pub fn isTrailRuinExclusive(self: TrailRuinPotterySherd) bool {
        _ = self;
        return true;
    }

    pub fn name(self: TrailRuinPotterySherd) []const u8 {
        return switch (self) {
            .burn => "Burn Pottery Sherd",
            .danger => "Danger Pottery Sherd",
            .friend => "Friend Pottery Sherd",
            .heart => "Heart Pottery Sherd",
            .heartbreak => "Heartbreak Pottery Sherd",
            .howl => "Howl Pottery Sherd",
            .sheaf => "Sheaf Pottery Sherd",
        };
    }
};

/// Returns true if a given sherd is one of the 7 Trail Ruins exclusive pottery sherds.
pub fn isTrailRuinPotterySherd(sherd: anytype) bool {
    const T = @TypeOf(sherd);
    if (T == TrailRuinPotterySherd) return true;
    switch (@typeInfo(T)) {
        .pointer => |ptr_info| {
            if (ptr_info.size == .slice or (ptr_info.size == .one and @typeInfo(ptr_info.child) == .array)) {
                const s: []const u8 = sherd;
                for (TrailRuinPotterySherd.all) |cand| {
                    if (std.mem.eql(u8, s, @tagName(cand))) return true;
                }
                return false;
            }
        },
        .enum_literal, .@"enum" => {
            const tag_name = @tagName(sherd);
            for (TrailRuinPotterySherd.all) |cand| {
                if (std.mem.eql(u8, tag_name, @tagName(cand))) return true;
            }
            return false;
        },
        else => {},
    }
    return false;
}

// ============================================================================
// Archaeological Loot & Relic Discovery
// ============================================================================

/// Rare archaeological items found by excavating Trail Ruins suspicious gravel.
pub const RareArchaeologicalItem = union(enum) {
    trim: TrailRuinTrimTemplate,
    sherd: TrailRuinPotterySherd,
    music_disc_relic: void,

    pub fn name(self: RareArchaeologicalItem) []const u8 {
        return switch (self) {
            .trim => |t| t.name(),
            .sherd => |s| s.name(),
            .music_disc_relic => "Music Disc (Aaron Cherof - Relic)",
        };
    }
};

/// The rare archaeological pool contains 12 items: 4 trims + 7 sherds + 1 music disc relic.
pub const RARE_ARCHAEOLOGICAL_POOL_SIZE: usize = 12;

/// Deterministically resolves an item from the 12-item rare archaeological pool.
pub fn getRareArchaeologicalItem(index: usize) RareArchaeologicalItem {
    return switch (index % RARE_ARCHAEOLOGICAL_POOL_SIZE) {
        0 => .{ .trim = .wayfinder },
        1 => .{ .trim = .raiser },
        2 => .{ .trim = .shaper },
        3 => .{ .trim = .host },
        4 => .{ .sherd = .burn },
        5 => .{ .sherd = .danger },
        6 => .{ .sherd = .friend },
        7 => .{ .sherd = .heart },
        8 => .{ .sherd = .heartbreak },
        9 => .{ .sherd = .howl },
        10 => .{ .sherd = .sheaf },
        11 => .{ .music_disc_relic = {} },
        else => unreachable,
    };
}

/// Music Disc Relic discovery metadata and redstone comparator physics.
pub const RelicDiscDiscovery = struct {
    pub const disc_identifier: []const u8 = "music_disc_relic";
    pub const track_title: []const u8 = "Relic";
    pub const author: []const u8 = "Aaron Cherof";
    pub const track_duration_seconds: f32 = 218.0;
    /// The redstone comparator output emitted when played in a Jukebox (14 out of 15).
    pub const comparator_signal: u4 = 14;
    pub const max_comparator_signal: u4 = 15;

    pub fn comparatorSignal() u4 {
        return comparator_signal;
    }

    pub fn comparatorRatio() f32 {
        return @as(f32, @floatFromInt(comparator_signal)) / @as(f32, @floatFromInt(max_comparator_signal));
    }

    pub fn isMusicDiscRelic(identifier: []const u8) bool {
        return std.mem.eql(u8, identifier, disc_identifier) or std.mem.eql(u8, identifier, "relic");
    }
};

// ============================================================================
// Suspicious Gravel Physics
// ============================================================================

/// Physics rules and constants governing suspicious gravel blocks.
pub const SuspiciousGravelPhysics = struct {
    /// Safe brushing duration in seconds (4.8s).
    pub const BRUSH_DURATION_SECONDS: f32 = 4.8;
    /// Safe brushing duration in game ticks (4.8 * 20 = 96 ticks).
    pub const BRUSH_DURATION_TICKS: u16 = 96;
    /// Number of progressive dusting texture stages.
    pub const DUSTING_STAGES: u8 = 4;
    /// Ticks required to advance each dusting stage (96 / 4 = 24 ticks).
    pub const TICKS_PER_STAGE: u16 = BRUSH_DURATION_TICKS / DUSTING_STAGES;

    /// Suspicious gravel falls with gravity, but shatters and destroys its item on fall.
    pub fn shattersOnFall() bool {
        return true;
    }

    /// Suspicious gravel shatters and destroys its item when moved by a piston.
    pub fn shattersOnPistonPush() bool {
        return true;
    }
};

/// Global function for fall shattering physics check.
pub fn shattersOnFall() bool {
    return SuspiciousGravelPhysics.shattersOnFall();
}

/// Global function for piston push shattering physics check.
pub fn shattersOnPistonPush() bool {
    return SuspiciousGravelPhysics.shattersOnPistonPush();
}

/// In-world state tracking for an individual suspicious gravel block.
pub const SuspiciousGravelBlock = struct {
    x: i32,
    y: i32,
    z: i32,
    buried_item: ?RareArchaeologicalItem = null,
    brush_ticks: u16 = 0,
    is_brushing: bool = false,
    is_shattered: bool = false,
    is_converted_to_gravel: bool = false,

    pub fn init(x: i32, y: i32, z: i32, buried_item: ?RareArchaeologicalItem) SuspiciousGravelBlock {
        return .{
            .x = x,
            .y = y,
            .z = z,
            .buried_item = buried_item,
        };
    }

    /// Dusting stage: 0 (0..23), 1 (24..47), 2 (48..71), 3 (72..95).
    pub fn dustingStage(self: SuspiciousGravelBlock) u2 {
        if (self.brush_ticks >= 72) return 3;
        if (self.brush_ticks >= 48) return 2;
        if (self.brush_ticks >= 24) return 1;
        return 0;
    }

    /// Current brushing progress in seconds.
    pub fn progressSeconds(self: SuspiciousGravelBlock) f32 {
        return @as(f32, @floatFromInt(self.brush_ticks)) / 20.0;
    }

    /// Advances brushing in-place. If player is within reach (<= 4.5 blocks), ticks accumulate.
    /// Reaching 96 ticks (4.8s) safely extracts the relic and converts block to regular gravel.
    pub fn brush(self: *SuspiciousGravelBlock, ticks: u16, player_x: f32, player_y: f32, player_z: f32) ?RareArchaeologicalItem {
        if (self.is_shattered or self.is_converted_to_gravel) return null;

        const bx = @as(f32, @floatFromInt(self.x)) + 0.5;
        const by = @as(f32, @floatFromInt(self.y)) + 0.5;
        const bz = @as(f32, @floatFromInt(self.z)) + 0.5;
        const dx = player_x - bx;
        const dy = player_y - by;
        const dz = player_z - bz;
        const dist_sq = dx * dx + dy * dy + dz * dz;

        // Player must remain in-place within reach (<= 4.5m, dist_sq <= 20.25).
        // If player moves away, brushing stalls/resets.
        if (dist_sq > 20.25) {
            self.brush_ticks = 0;
            self.is_brushing = false;
            return null;
        }

        self.is_brushing = true;
        self.brush_ticks += ticks;

        if (self.brush_ticks >= SuspiciousGravelPhysics.BRUSH_DURATION_TICKS) {
            self.is_converted_to_gravel = true;
            self.is_brushing = false;
            const item = self.buried_item;
            self.buried_item = null;
            return item;
        }

        return null;
    }

    /// Suspicious gravel falls due to gravity: shatters block and permanently destroys buried item.
    pub fn triggerFall(self: *SuspiciousGravelBlock) void {
        self.is_shattered = true;
        self.buried_item = null; // Item destroyed!
        self.brush_ticks = 0;
        self.is_brushing = false;
    }

    /// Piston moves or pushes suspicious gravel: shatters block and permanently destroys buried item.
    pub fn triggerPistonPush(self: *SuspiciousGravelBlock) void {
        self.is_shattered = true;
        self.buried_item = null; // Item destroyed!
        self.brush_ticks = 0;
        self.is_brushing = false;
    }
};

// ============================================================================
// Unit Tests (16 comprehensive tests)
// ============================================================================

test "1: TrailRuinBiome validation - only taiga, jungle, and birch forest variants are valid" {
    // Valid biomes
    try std.testing.expect(TrailRuinBiome.taiga.isValidTrailRuinBiome());
    try std.testing.expect(TrailRuinBiome.snowy_taiga.isValidTrailRuinBiome());
    try std.testing.expect(TrailRuinBiome.old_growth_pine_taiga.isValidTrailRuinBiome());
    try std.testing.expect(TrailRuinBiome.old_growth_spruce_taiga.isValidTrailRuinBiome());
    try std.testing.expect(TrailRuinBiome.jungle.isValidTrailRuinBiome());
    try std.testing.expect(TrailRuinBiome.sparse_jungle.isValidTrailRuinBiome());
    try std.testing.expect(TrailRuinBiome.bamboo_jungle.isValidTrailRuinBiome());
    try std.testing.expect(TrailRuinBiome.birch_forest.isValidTrailRuinBiome());
    try std.testing.expect(TrailRuinBiome.old_growth_birch_forest.isValidTrailRuinBiome());

    // Invalid biomes
    try std.testing.expect(!TrailRuinBiome.plains.isValidTrailRuinBiome());
    try std.testing.expect(!TrailRuinBiome.desert.isValidTrailRuinBiome());
    try std.testing.expect(!TrailRuinBiome.savanna.isValidTrailRuinBiome());
    try std.testing.expect(!TrailRuinBiome.badlands.isValidTrailRuinBiome());
    try std.testing.expect(!TrailRuinBiome.ocean.isValidTrailRuinBiome());
    try std.testing.expect(!TrailRuinBiome.nether_wastes.isValidTrailRuinBiome());
    try std.testing.expect(!TrailRuinBiome.the_end.isValidTrailRuinBiome());

    // Layout generation returns null for invalid biome
    try std.testing.expectEqual(@as(?TrailRuinLayout, null), TrailRuinLayout.generate(12345, 100, 64, -200, .plains));
}

test "2: TrailRuinLayout surface tower crown protrusion is strictly between 1 and 3 blocks above ground" {
    // Test generated protrusion heights across multiple seeds
    var seed: u64 = 1000;
    while (seed < 1030) : (seed += 1) {
        const layout_opt = TrailRuinLayout.generate(seed, 0, 64, 0, .taiga);
        try std.testing.expect(layout_opt != null);
        const layout = layout_opt.?;

        try std.testing.expect(layout.crown_protrusion_height >= 1);
        try std.testing.expect(layout.crown_protrusion_height <= 3);
        try std.testing.expectEqual(layout.ground_y + @as(i32, layout.crown_protrusion_height), layout.tower_top_y);

        // Verification of protrusion check method
        try std.testing.expect(!layout.isCrownProtrusionY(layout.ground_y));
        try std.testing.expect(layout.isCrownProtrusionY(layout.ground_y + 1));
        try std.testing.expect(layout.isCrownProtrusionY(layout.tower_top_y));
        try std.testing.expect(!layout.isCrownProtrusionY(layout.tower_top_y + 1));
    }

    // Explicit clamping tests
    const l1 = TrailRuinLayout.initWithProtrusion(0, 64, 0, .birch_forest, 0).?;
    try std.testing.expectEqual(@as(u8, 1), l1.crown_protrusion_height);

    const l2 = TrailRuinLayout.initWithProtrusion(0, 64, 0, .jungle, 2).?;
    try std.testing.expectEqual(@as(u8, 2), l2.crown_protrusion_height);

    const l3 = TrailRuinLayout.initWithProtrusion(0, 64, 0, .old_growth_pine_taiga, 5).?;
    try std.testing.expectEqual(@as(u8, 3), l3.crown_protrusion_height);
}

test "3: TrailRuinLayout underground road uses cobblestone and mud-brick materials" {
    const layout = TrailRuinLayout.initWithProtrusion(0, 64, 0, .taiga, 2).?;

    // Road is situated deep underground
    try std.testing.expect(layout.road_y < layout.ground_y);
    try std.testing.expect(layout.isUndergroundY(layout.road_y));

    // Road flooring alternates cobblestone and mud bricks
    var z: i32 = 0;
    while (z < 10) : (z += 1) {
        const block = layout.getBlockAt(layout.origin_x, layout.road_y, layout.origin_z + z);
        try std.testing.expect(block.isRoadMaterial());
        try std.testing.expect(block == .cobblestone or block == .mud_bricks);
    }
}

test "4: TrailRuinLayout contains all 6 guild room workstations" {
    const layout = TrailRuinLayout.initWithProtrusion(10, 68, -50, .bamboo_jungle, 2).?;

    // Must have all 6 workstations
    try std.testing.expect(layout.hasAllWorkstations());

    const expected_ws = [_]TrailRuinWorkstation{
        .loom,
        .cartography_table,
        .smithing_table,
        .grindstone,
        .stonecutter,
        .kiln_furnace,
    };

    for (expected_ws) |ws| {
        const room = layout.findGuildRoom(ws);
        try std.testing.expect(room != null);
        const r = room.?;
        try std.testing.expectEqual(ws, r.workstation);

        // Verify the workstation block is located at its designated position
        const block = layout.getBlockAt(r.workstation_pos[0], r.workstation_pos[1], r.workstation_pos[2]);
        try std.testing.expect(block.isWorkstation());
    }
}

test "5: TrailRuinLayout 3D voxel inspection differentiates crown protrusion, underground tower, and guild rooms" {
    const layout = TrailRuinLayout.initWithProtrusion(0, 64, 0, .taiga, 2).?;

    // Crown protrusion block above ground level is terracotta
    const crown_block = layout.getBlockAt(0, 65, 0);
    try std.testing.expect(crown_block == .terracotta or crown_block == .orange_terracotta);

    // Well above crown is air
    try std.testing.expectEqual(TrailRuinBlock.air, layout.getBlockAt(0, 75, 0));

    // Outside structure is air
    try std.testing.expectEqual(TrailRuinBlock.air, layout.getBlockAt(50, 64, 50));

    // Underground road block is cobblestone or mud bricks
    const road_block = layout.getBlockAt(0, layout.road_y, 10);
    try std.testing.expect(road_block == .cobblestone or road_block == .mud_bricks);
}

test "6: TrailRuinTrimTemplate four exclusive armor trims and isTrailRuinExclusiveTrim check" {
    // Exactly 4 templates
    try std.testing.expectEqual(@as(usize, 4), TrailRuinTrimTemplate.count);

    const trims = TrailRuinTrimTemplate.all;
    for (trims) |trim| {
        try std.testing.expect(trim.isTrailRuinExclusiveTrim());
        try std.testing.expect(isTrailRuinExclusiveTrim(trim));
        try std.testing.expectEqualStrings("terracotta", trim.requiredDuplicationMaterial());
    }

    // Name strings
    try std.testing.expectEqualStrings("Wayfinder Armor Trim", TrailRuinTrimTemplate.wayfinder.name());
    try std.testing.expectEqualStrings("Raiser Armor Trim", TrailRuinTrimTemplate.raiser.name());
    try std.testing.expectEqualStrings("Shaper Armor Trim", TrailRuinTrimTemplate.shaper.name());
    try std.testing.expectEqualStrings("Host Armor Trim", TrailRuinTrimTemplate.host.name());

    // isTrailRuinExclusiveTrim supports string and enum checks
    try std.testing.expect(isTrailRuinExclusiveTrim("wayfinder"));
    try std.testing.expect(isTrailRuinExclusiveTrim("raiser"));
    try std.testing.expect(isTrailRuinExclusiveTrim("shaper"));
    try std.testing.expect(isTrailRuinExclusiveTrim("host"));

    // Non-exclusive trims return false
    try std.testing.expect(!isTrailRuinExclusiveTrim("silence"));
    try std.testing.expect(!isTrailRuinExclusiveTrim("ward"));
    try std.testing.expect(!isTrailRuinExclusiveTrim("coast"));
}

test "7: duplicateTrailRuinTrim valid single craft (7 diamonds + 1 terracotta + 1 template -> 2 templates)" {
    const res = duplicateTrailRuinTrim(7, 1, 1);
    try std.testing.expect(res.success);
    try std.testing.expectEqual(@as(u8, 2), res.templates_out);
    try std.testing.expectEqual(@as(u8, 7), res.diamonds_used);
    try std.testing.expectEqual(@as(u8, 1), res.terracotta_used);
    try std.testing.expectEqual(@as(u8, 1), res.templates_consumed);
    try std.testing.expectEqual(@as(u8, 0), res.diamonds_remaining);
    try std.testing.expectEqual(@as(u8, 0), res.terracotta_remaining);
    try std.testing.expectEqual(@as(u8, 2), res.templates_total);

    // Excess ingredients preserved
    const res_excess = duplicateTrailRuinTrim(10, 5, 1);
    try std.testing.expect(res_excess.success);
    try std.testing.expectEqual(@as(u8, 2), res_excess.templates_out);
    try std.testing.expectEqual(@as(u8, 7), res_excess.diamonds_used);
    try std.testing.expectEqual(@as(u8, 1), res_excess.terracotta_used);
    try std.testing.expectEqual(@as(u8, 3), res_excess.diamonds_remaining);
    try std.testing.expectEqual(@as(u8, 4), res_excess.terracotta_remaining);
    try std.testing.expectEqual(@as(u8, 2), res_excess.templates_total);
}

test "8: duplicateTrailRuinTrim batch crafting and insufficient ingredient rejection" {
    // 2 crafts: 14 diamonds + 2 terracotta + 2 templates -> 4 templates
    const res_batch2 = duplicateTrailRuinTrim(14, 2, 2);
    try std.testing.expect(res_batch2.success);
    try std.testing.expectEqual(@as(u8, 4), res_batch2.templates_out);
    try std.testing.expectEqual(@as(u8, 14), res_batch2.diamonds_used);
    try std.testing.expectEqual(@as(u8, 2), res_batch2.terracotta_used);
    try std.testing.expectEqual(@as(u8, 4), res_batch2.templates_total);

    // Insufficient diamonds (< 7)
    const fail_dia = duplicateTrailRuinTrim(6, 1, 1);
    try std.testing.expect(!fail_dia.success);
    try std.testing.expectEqual(@as(u8, 0), fail_dia.templates_out);

    // Insufficient terracotta (< 1)
    const fail_terra = duplicateTrailRuinTrim(7, 0, 1);
    try std.testing.expect(!fail_terra.success);
    try std.testing.expectEqual(@as(u8, 0), fail_terra.templates_out);

    // Insufficient templates (< 1)
    const fail_tpl = duplicateTrailRuinTrim(7, 1, 0);
    try std.testing.expect(!fail_tpl.success);
    try std.testing.expectEqual(@as(u8, 0), fail_tpl.templates_out);
}

test "9: TrailRuinPotterySherd all 7 exclusive sherds and identification" {
    try std.testing.expectEqual(@as(usize, 7), TrailRuinPotterySherd.count);

    const sherds = TrailRuinPotterySherd.all;
    for (sherds) |sherd| {
        try std.testing.expect(sherd.isTrailRuinExclusive());
        try std.testing.expect(isTrailRuinPotterySherd(sherd));
    }

    try std.testing.expectEqualStrings("Burn Pottery Sherd", TrailRuinPotterySherd.burn.name());
    try std.testing.expectEqualStrings("Danger Pottery Sherd", TrailRuinPotterySherd.danger.name());
    try std.testing.expectEqualStrings("Friend Pottery Sherd", TrailRuinPotterySherd.friend.name());
    try std.testing.expectEqualStrings("Heart Pottery Sherd", TrailRuinPotterySherd.heart.name());
    try std.testing.expectEqualStrings("Heartbreak Pottery Sherd", TrailRuinPotterySherd.heartbreak.name());
    try std.testing.expectEqualStrings("Howl Pottery Sherd", TrailRuinPotterySherd.howl.name());
    try std.testing.expectEqualStrings("Sheaf Pottery Sherd", TrailRuinPotterySherd.sheaf.name());

    // Non-trail sherds
    try std.testing.expect(!isTrailRuinPotterySherd("angler"));
    try std.testing.expect(!isTrailRuinPotterySherd("archer"));
    try std.testing.expect(!isTrailRuinPotterySherd("miner"));
}

test "10: SuspiciousGravelPhysics gravity fall shatters block and destroys buried archaeological item" {
    try std.testing.expect(SuspiciousGravelPhysics.shattersOnFall());
    try std.testing.expect(shattersOnFall());

    var block = SuspiciousGravelBlock.init(10, 60, 20, .{ .trim = .wayfinder });
    try std.testing.expect(block.buried_item != null);
    try std.testing.expect(!block.is_shattered);

    // Block falls due to lack of support below
    block.triggerFall();

    try std.testing.expect(block.is_shattered);
    // Relic was permanently destroyed upon shattering!
    try std.testing.expectEqual(@as(?RareArchaeologicalItem, null), block.buried_item);
    try std.testing.expect(!block.is_converted_to_gravel);
}

test "11: SuspiciousGravelPhysics piston push shatters block and destroys buried archaeological item" {
    try std.testing.expect(SuspiciousGravelPhysics.shattersOnPistonPush());
    try std.testing.expect(shattersOnPistonPush());

    var block = SuspiciousGravelBlock.init(5, 55, 15, .{ .sherd = .burn });
    try std.testing.expect(block.buried_item != null);

    // Piston attempts to push block
    block.triggerPistonPush();

    try std.testing.expect(block.is_shattered);
    // Relic was permanently destroyed!
    try std.testing.expectEqual(@as(?RareArchaeologicalItem, null), block.buried_item);
}

test "12: SuspiciousGravelPhysics safe in-place brushing for 4.8 seconds (96 ticks) extracts relic and converts to regular gravel" {
    try std.testing.expectApproxEqAbs(@as(f32, 4.8), SuspiciousGravelPhysics.BRUSH_DURATION_SECONDS, 0.001);
    try std.testing.expectEqual(@as(u16, 96), SuspiciousGravelPhysics.BRUSH_DURATION_TICKS);

    var block = SuspiciousGravelBlock.init(0, 50, 0, .{ .trim = .shaper });
    const player_x: f32 = 0.5;
    const player_y: f32 = 50.5;
    const player_z: f32 = 1.5; // Within 1.5 blocks reach

    // Brush for 48 ticks (2.4s) - halfway
    const mid = block.brush(48, player_x, player_y, player_z);
    try std.testing.expectEqual(@as(?RareArchaeologicalItem, null), mid);
    try std.testing.expectApproxEqAbs(@as(f32, 2.4), block.progressSeconds(), 0.001);
    try std.testing.expect(!block.is_converted_to_gravel);

    // Finish remaining 48 ticks (total 96 ticks = 4.8s)
    const result = block.brush(48, player_x, player_y, player_z);
    try std.testing.expect(result != null);
    try std.testing.expectEqual(TrailRuinTrimTemplate.shaper, result.?.trim);

    // Block converted to regular gravel and no longer holds an item
    try std.testing.expect(block.is_converted_to_gravel);
    try std.testing.expectEqual(@as(?RareArchaeologicalItem, null), block.buried_item);
}

test "13: SuspiciousGravelPhysics brushing progress stages and out-of-range interruption reset" {
    var block = SuspiciousGravelBlock.init(0, 50, 0, .{ .sherd = .howl });
    const px: f32 = 0.5;
    const py: f32 = 50.5;
    const pz: f32 = 1.0;

    // Stage 0: 0..23 ticks
    _ = block.brush(10, px, py, pz);
    try std.testing.expectEqual(@as(u2, 0), block.dustingStage());

    // Stage 1: 24..47 ticks
    _ = block.brush(20, px, py, pz); // total 30 ticks
    try std.testing.expectEqual(@as(u2, 1), block.dustingStage());

    // Stage 2: 48..71 ticks
    _ = block.brush(20, px, py, pz); // total 50 ticks
    try std.testing.expectEqual(@as(u2, 2), block.dustingStage());

    // Stage 3: 72..95 ticks
    _ = block.brush(25, px, py, pz); // total 75 ticks
    try std.testing.expectEqual(@as(u2, 3), block.dustingStage());

    // Player walks away (> 4.5m distance) -> progress resets!
    const far_x: f32 = 100.0;
    _ = block.brush(1, far_x, py, pz);
    try std.testing.expectEqual(@as(u16, 0), block.brush_ticks);
    try std.testing.expectEqual(@as(u2, 0), block.dustingStage());
    try std.testing.expect(!block.is_brushing);
}

test "14: RelicDiscDiscovery yields music_disc_relic with comparator signal 14 out of 15" {
    try std.testing.expectEqual(@as(u4, 14), RelicDiscDiscovery.comparatorSignal());
    try std.testing.expectEqual(@as(u4, 15), RelicDiscDiscovery.max_comparator_signal);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0 / 15.0), RelicDiscDiscovery.comparatorRatio(), 0.0001);

    try std.testing.expectEqualStrings("music_disc_relic", RelicDiscDiscovery.disc_identifier);
    try std.testing.expectEqualStrings("Relic", RelicDiscDiscovery.track_title);
    try std.testing.expectEqualStrings("Aaron Cherof", RelicDiscDiscovery.author);
    try std.testing.expectApproxEqAbs(@as(f32, 218.0), RelicDiscDiscovery.track_duration_seconds, 0.01);

    try std.testing.expect(RelicDiscDiscovery.isMusicDiscRelic("music_disc_relic"));
    try std.testing.expect(RelicDiscDiscovery.isMusicDiscRelic("relic"));
    try std.testing.expect(!RelicDiscDiscovery.isMusicDiscRelic("cat"));
}

test "15: Archaeology loot pool distribution across 12 rare relics (4 trims, 7 sherds, 1 disc)" {
    try std.testing.expectEqual(@as(usize, 12), RARE_ARCHAEOLOGICAL_POOL_SIZE);

    var trims_found: usize = 0;
    var sherds_found: usize = 0;
    var disc_found: usize = 0;

    var i: usize = 0;
    while (i < 12) : (i += 1) {
        const item = getRareArchaeologicalItem(i);
        switch (item) {
            .trim => trims_found += 1,
            .sherd => sherds_found += 1,
            .music_disc_relic => disc_found += 1,
        }
    }

    try std.testing.expectEqual(@as(usize, 4), trims_found);
    try std.testing.expectEqual(@as(usize, 7), sherds_found);
    try std.testing.expectEqual(@as(usize, 1), disc_found);
}

test "16: Full archaeological excavation and craft workflow integration" {
    // Setup buried suspicious gravel with rare Wayfinder trim
    var block = SuspiciousGravelBlock.init(10, 48, -25, .{ .trim = .wayfinder });

    // Brush safely for 96 ticks
    const loot = block.brush(96, 10.5, 48.5, -24.5);
    try std.testing.expect(loot != null);
    try std.testing.expectEqual(TrailRuinTrimTemplate.wayfinder, loot.?.trim);
    try std.testing.expect(block.is_converted_to_gravel);

    // Duplicate the extracted Wayfinder trim with 7 diamonds and 1 terracotta
    const dup = duplicateTrailRuinTrim(7, 1, 1);
    try std.testing.expect(dup.success);
    try std.testing.expectEqual(@as(u8, 2), dup.templates_out);
    try std.testing.expectEqual(@as(u8, 7), dup.diamonds_used);
    try std.testing.expectEqual(@as(u8, 1), dup.terracotta_used);

    // Next block contains Music Disc Relic
    var disc_block = SuspiciousGravelBlock.init(11, 48, -25, .{ .music_disc_relic = {} });
    const disc_loot = disc_block.brush(96, 10.5, 48.5, -24.5);
    try std.testing.expect(disc_loot != null);
    try std.testing.expect(disc_loot.? == .music_disc_relic);
    try std.testing.expectEqual(@as(u4, 14), RelicDiscDiscovery.comparatorSignal());
}
