const std = @import("std");

// ============================================================================
// Section 1: Constants, Spatial Enums & Coordinates
// ============================================================================

/// Number of game ticks per second (20 ticks/sec).
pub const TICKS_PER_SECOND: u32 = 20;

/// Resin extrusion cooldown after a Creaking puppet is struck (100 ticks = 5.0 seconds).
pub const RESIN_EXTRUSION_COOLDOWN_TICKS: u32 = 100;
pub const RESIN_EXTRUSION_COOLDOWN_SECONDS: f32 = 5.0;

/// Minimum and maximum resin clumps extruded per valid strike.
pub const MIN_CLUMPS_PER_EXTRUSION: u8 = 1;
pub const MAX_CLUMPS_PER_EXTRUSION: u8 = 3;

/// Maximum number of resin layers accumulated on a single block face (5 layers).
pub const MAX_RESIN_LAYERS: u8 = 5;

/// Number of resin clumps required to form or consolidate into 1 solid Block of Resin (9 clumps).
pub const RESIN_CLUMPS_PER_BLOCK: u8 = 9;

/// Number of resin bricks required to craft 1 Block of Resin Bricks (4 bricks in 2x2).
pub const BRICKS_PER_RESIN_BRICK_BLOCK: u8 = 4;

/// Masonry crafting yield constants.
pub const SLABS_PER_CRAFT: u8 = 6;
pub const SLAB_CRAFT_INPUT_BLOCKS: u8 = 3;
pub const STAIRS_PER_CRAFT: u8 = 4;
pub const STAIR_CRAFT_INPUT_BLOCKS: u8 = 6;
pub const WALLS_PER_CRAFT: u8 = 6;
pub const WALL_CRAFT_INPUT_BLOCKS: u8 = 6;
pub const CHISELED_SLABS_REQUIRED: u8 = 2;

/// Smelting constants.
pub const SMELT_EXPERIENCE_YIELD: f32 = 0.1;
pub const STANDARD_FURNACE_SMELT_TICKS: u32 = 200; // 10.0 seconds
pub const BLAST_FURNACE_SMELT_TICKS: u32 = 100;    // 5.0 seconds (2x speed)

/// Creaking mob tether reach and particle trail bounds.
pub const MAX_TETHER_RADIUS: f32 = 32.0;
pub const MAX_TETHER_RADIUS_SQ: f32 = MAX_TETHER_RADIUS * MAX_TETHER_RADIUS; // 1024.0
pub const MIN_BEAM_PARTICLES: u32 = 8;
pub const MAX_BEAM_PARTICLES: u32 = 32;

/// Resin visual palette constants.
pub const RESIN_ORANGE_HEX: u24 = 0xe05e26;
pub const RESIN_DARK_CONTRAST_HEX: u24 = 0xb33e0f;
pub const RESIN_ORANGE_RGB: [3]f32 = .{ 0.8784, 0.3686, 0.1490 };

/// 3D cardinal and vertical directions.
pub const Direction = enum(u3) {
    up = 0,
    down = 1,
    north = 2,
    south = 3,
    east = 4,
    west = 5,

    pub const all: [6]Direction = .{ .up, .down, .north, .south, .east, .west };
    pub const horizontal: [4]Direction = .{ .north, .south, .east, .west };
    pub const vertical: [2]Direction = .{ .up, .down };

    pub fn getOffset(self: Direction) [3]i32 {
        return switch (self) {
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
        };
    }

    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .up => .down,
            .down => .up,
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }

    pub fn name(self: Direction) []const u8 {
        return switch (self) {
            .up => "Up",
            .down => "Down",
            .north => "North",
            .south => "South",
            .east => "East",
            .west => "West",
        };
    }

    pub fn isVertical(self: Direction) bool {
        return self == .up or self == .down;
    }

    pub fn isHorizontal(self: Direction) bool {
        return !self.isVertical();
    }
};

/// 3D discrete block coordinate position.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) BlockPos {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn toArray(self: BlockPos) [3]i32 {
        return .{ self.x, self.y, self.z };
    }

    pub fn fromArray(arr: [3]i32) BlockPos {
        return .{ .x = arr[0], .y = arr[1], .z = arr[2] };
    }

    pub fn offset(self: BlockPos, dir: Direction) BlockPos {
        const off = dir.getOffset();
        return .{ .x = self.x + off[0], .y = self.y + off[1], .z = self.z + off[2] };
    }

    pub fn offsetBy(self: BlockPos, dx: i32, dy: i32, dz: i32) BlockPos {
        return .{ .x = self.x + dx, .y = self.y + dy, .z = self.z + dz };
    }

    pub fn equals(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub fn distSq(self: BlockPos, other: BlockPos) f32 {
        const dx = @as(f32, @floatFromInt(self.x - other.x));
        const dy = @as(f32, @floatFromInt(self.y - other.y));
        const dz = @as(f32, @floatFromInt(self.z - other.z));
        return dx * dx + dy * dy + dz * dz;
    }

    pub fn dist(self: BlockPos, other: BlockPos) f32 {
        return @sqrt(self.distSq(other));
    }
};

// ============================================================================
// Section 2: Block & Item Taxonomy for Resin & Masonry
// ============================================================================

/// Block identifiers specific to the Pale Garden biome and Resin masonry architecture.
pub const ResinBlockKind = enum(u16) {
    air = 0,
    pale_oak_log = 420,
    creaking_heart = 421,
    pale_oak_wood = 423,
    pale_oak_planks = 424,
    resin_clump = 431,
    resin_block = 432,           // Solid consolidated Block of Resin (9 clumps)
    resin_bricks = 433,          // Block of Resin Bricks (4 bricks)
    resin_brick_slab = 434,      // Half-slab architectural variant
    resin_brick_stairs = 435,    // Stairway architectural variant
    resin_brick_wall = 436,      // Protective stone wall variant
    chiseled_resin_bricks = 437, // Decorative chiseled Creaking motif block

    pub fn name(self: ResinBlockKind) []const u8 {
        return switch (self) {
            .air => "Air",
            .pale_oak_log => "Pale Oak Log",
            .creaking_heart => "Creaking Heart",
            .pale_oak_wood => "Pale Oak Wood",
            .pale_oak_planks => "Pale Oak Planks",
            .resin_clump => "Resin Clump",
            .resin_block => "Block of Resin",
            .resin_bricks => "Resin Bricks",
            .resin_brick_slab => "Resin Brick Slab",
            .resin_brick_stairs => "Resin Brick Stairs",
            .resin_brick_wall => "Resin Brick Wall",
            .chiseled_resin_bricks => "Chiseled Resin Bricks",
        };
    }

    pub fn isSolid(self: ResinBlockKind) bool {
        return switch (self) {
            .air => false,
            .resin_clump => false, // Non-full block surface attachment
            else => true,
        };
    }

    pub fn isPaleOakWood(self: ResinBlockKind) bool {
        return self == .pale_oak_log or self == .pale_oak_wood;
    }

    pub fn hardness(self: ResinBlockKind) f32 {
        return switch (self) {
            .air => 0.0,
            .pale_oak_log, .pale_oak_wood, .pale_oak_planks => 2.0,
            .creaking_heart => 5.0,
            .resin_clump => 1.0,
            .resin_block => 1.5,
            .resin_bricks, .resin_brick_slab, .resin_brick_stairs, .resin_brick_wall, .chiseled_resin_bricks => 1.5,
        };
    }

    pub fn blastResistance(self: ResinBlockKind) f32 {
        return switch (self) {
            .air => 0.0,
            .pale_oak_log, .pale_oak_wood, .pale_oak_planks => 2.0,
            .creaking_heart => 5.0,
            .resin_clump => 3.0,
            .resin_block => 5.0,
            .resin_bricks, .resin_brick_slab, .resin_brick_stairs, .resin_brick_wall, .chiseled_resin_bricks => 6.0,
        };
    }

    pub fn isFlammable(self: ResinBlockKind) bool {
        return switch (self) {
            .pale_oak_log, .pale_oak_wood, .pale_oak_planks => true,
            else => false, // Resin masonry blocks are fired/vitrified and non-flammable
        };
    }
};

/// Item identifiers for inventory, crafting, and furnace pyrometallurgy.
pub const ResinItemKind = enum(u16) {
    none = 0,
    pale_oak_log = 420,
    creaking_heart = 421,
    resin_clump = 431,
    resin_brick = 412,           // Fired kiln brick item
    resin_block = 432,           // Item form of Block of Resin
    resin_bricks = 433,          // Item form of Resin Bricks
    resin_brick_slab = 434,
    resin_brick_stairs = 435,
    resin_brick_wall = 436,
    chiseled_resin_bricks = 437,
    armor_trim_template = 395,

    pub fn name(self: ResinItemKind) []const u8 {
        return switch (self) {
            .none => "None",
            .pale_oak_log => "Pale Oak Log",
            .creaking_heart => "Creaking Heart",
            .resin_clump => "Resin Clump",
            .resin_brick => "Resin Brick",
            .resin_block => "Block of Resin",
            .resin_bricks => "Resin Bricks",
            .resin_brick_slab => "Resin Brick Slab",
            .resin_brick_stairs => "Resin Brick Stairs",
            .resin_brick_wall => "Resin Brick Wall",
            .chiseled_resin_bricks => "Chiseled Resin Bricks",
            .armor_trim_template => "Armor Trim Smithing Template",
        };
    }

    pub fn maxStackSize(self: ResinItemKind) u8 {
        return switch (self) {
            .none => 0,
            .armor_trim_template => 16,
            else => 64,
        };
    }
};

// ============================================================================
// Section 3: Creaking Puppet & Creaking Heart Spawning Engine
// ============================================================================

/// Represents the physical Creaking puppet entity tethered to a Creaking Heart.
pub const CreakingPuppetEntity = struct {
    id: u32,
    pos: [3]f32,
    heart_pos: BlockPos,
    is_alive: bool = true,
    is_frozen: bool = false,

    pub fn init(id: u32, pos: [3]f32, heart_pos: BlockPos) CreakingPuppetEntity {
        return .{
            .id = id,
            .pos = pos,
            .heart_pos = heart_pos,
            .is_alive = true,
            .is_frozen = false,
        };
    }

    /// Evaluates whether the puppet is within its 32-block tether radius.
    pub fn isWithinTether(self: *const CreakingPuppetEntity) bool {
        const dx = self.pos[0] - @as(f32, @floatFromInt(self.heart_pos.x));
        const dy = self.pos[1] - @as(f32, @floatFromInt(self.heart_pos.y));
        const dz = self.pos[2] - @as(f32, @floatFromInt(self.heart_pos.z));
        return (dx * dx + dy * dy + dz * dz) <= MAX_TETHER_RADIUS_SQ;
    }
};

/// Represents the active Creaking Heart block in the world.
pub const CreakingHeartBlock = struct {
    pos: BlockPos,
    is_active: bool = true,
    is_natural: bool = false,
    resin_cooldown_ticks: u32 = 0,
    linked_puppet_id: ?u32 = null,
    total_strikes_absorbed: u32 = 0,
    total_clumps_extruded: u32 = 0,

    pub fn init(pos: BlockPos, is_natural: bool) CreakingHeartBlock {
        return .{
            .pos = pos,
            .is_active = true,
            .is_natural = is_natural,
            .resin_cooldown_ticks = 0,
            .linked_puppet_id = null,
            .total_strikes_absorbed = 0,
            .total_clumps_extruded = 0,
        };
    }

    /// Heart can extrude resin only if active and off cooldown.
    pub fn canExtrudeResin(self: *const CreakingHeartBlock) bool {
        return self.is_active and (self.resin_cooldown_ticks == 0);
    }

    /// Ticks cooldown timer.
    pub fn tick(self: *CreakingHeartBlock, dt_ticks: u32) void {
        if (self.resin_cooldown_ticks > dt_ticks) {
            self.resin_cooldown_ticks -= dt_ticks;
        } else {
            self.resin_cooldown_ticks = 0;
        }
    }

    /// Triggers extrusion cooldown.
    pub fn triggerCooldown(self: *CreakingHeartBlock) void {
        self.resin_cooldown_ticks = RESIN_EXTRUSION_COOLDOWN_TICKS;
    }
};

/// Result of striking a Creaking puppet entity.
pub const StrikeOutcome = struct {
    damage_dealt_to_puppet: f32 = 0.0, // Puppet takes 0 direct damage
    particles_in_trail: u32,           // Particle count along redirection beam (8..32)
    clumps_spawned: u8,                // 1..3 resin clumps extruded if off cooldown
    cooldown_triggered: bool,
    heart_pos: BlockPos,
    spawn_positions: [MAX_CLUMPS_PER_EXTRUSION]BlockPos,
    spawn_faces: [MAX_CLUMPS_PER_EXTRUSION]Direction,
};

/// Calculates particle count along redirection beam based on distance to heart.
pub fn calculateRedirectionParticles(puppet_pos: [3]f32, heart_pos: BlockPos) u32 {
    const dx = puppet_pos[0] - (@as(f32, @floatFromInt(heart_pos.x)) + 0.5);
    const dy = puppet_pos[1] - (@as(f32, @floatFromInt(heart_pos.y)) + 0.5);
    const dz = puppet_pos[2] - (@as(f32, @floatFromInt(heart_pos.z)) + 0.5);
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);
    const count = @as(u32, @intFromFloat(@round(dist * 0.75))) + MIN_BEAM_PARTICLES;
    return @min(MAX_BEAM_PARTICLES, @max(MIN_BEAM_PARTICLES, count));
}

// ============================================================================
// Section 4: Resin Clump Surface Attachment & Layer Accumulation
// ============================================================================

/// Represents a single Resin Clump surface attachment on an outer face of a Pale Oak Log.
pub const ResinClumpAttachment = struct {
    pos: BlockPos,              // Position in world where clump geometry sits
    host_log_pos: BlockPos,     // Position of the supporting Pale Oak Log
    attached_face: Direction,   // Face of the supporting log that the clump is affixed to
    layers: u8 = 1,             // 1 to 5 accumulated resin layers
    is_consolidated: bool = false, // Consolidated into a solid Block of Resin (9 clumps)

    pub fn init(pos: BlockPos, host_log_pos: BlockPos, face: Direction, initial_layers: u8) ResinClumpAttachment {
        return .{
            .pos = pos,
            .host_log_pos = host_log_pos,
            .attached_face = face,
            .layers = @min(MAX_RESIN_LAYERS, @max(1, initial_layers)),
            .is_consolidated = false,
        };
    }

    /// Surface attachment validation: clump must be directly adjacent to its host log along attached_face.
    pub fn isValidAttachment(self: *const ResinClumpAttachment) bool {
        const expected_pos = self.host_log_pos.offset(self.attached_face);
        return self.pos.equals(expected_pos);
    }

    /// Accumulates additional resin layer onto this surface attachment (caps at 5 layers).
    pub fn accumulateLayers(self: *ResinClumpAttachment, count: u8) struct { added: u8, total_layers: u8, reached_max: bool } {
        if (self.is_consolidated) {
            return .{ .added = 0, .total_layers = MAX_RESIN_LAYERS, .reached_max = true };
        }
        const prev = self.layers;
        const new_total = @min(MAX_RESIN_LAYERS, prev + count);
        const added = new_total - prev;
        self.layers = new_total;
        return .{
            .added = added,
            .total_layers = self.layers,
            .reached_max = self.layers == MAX_RESIN_LAYERS,
        };
    }

    /// Consolidates 9 accumulated clumps into 1 solid Block of Resin.
    pub fn consolidateIntoBlock(self: *ResinClumpAttachment, total_clumps: u8) bool {
        if (total_clumps >= RESIN_CLUMPS_PER_BLOCK) {
            self.is_consolidated = true;
            self.layers = MAX_RESIN_LAYERS;
            return true;
        }
        return false;
    }
};

/// Candidate surface location for resin extrusion.
pub const ClumpSurfaceCandidate = struct {
    clump_pos: BlockPos,
    host_log_pos: BlockPos,
    face: Direction,
};

/// Scans neighboring Pale Oak Logs around a Creaking Heart to locate exposed outer faces.
/// A face is exposed if the adjacent space is Air or an existing non-full Resin Clump.
pub fn findExposedLogSurfaces(
    heart_pos: BlockPos,
    is_log_fn: *const fn (BlockPos) bool,
    is_air_or_clump_fn: *const fn (BlockPos) bool,
    out_candidates: []ClumpSurfaceCandidate,
) usize {
    var count: usize = 0;

    // Search immediate 3x3x3 neighborhood around Creaking Heart
    var dy: i32 = -1;
    while (dy <= 1) : (dy += 1) {
        var dz: i32 = -1;
        while (dz <= 1) : (dz += 1) {
            var dx: i32 = -1;
            while (dx <= 1) : (dx += 1) {
                const log_pos = heart_pos.offsetBy(dx, dy, dz);
                if (log_pos.equals(heart_pos)) continue; // Creaking Heart itself is not a log

                if (is_log_fn(log_pos)) {
                    // Check all 6 faces of this log
                    for (Direction.all) |dir| {
                        const outer_pos = log_pos.offset(dir);
                        if (is_air_or_clump_fn(outer_pos)) {
                            if (count < out_candidates.len) {
                                out_candidates[count] = .{
                                    .clump_pos = outer_pos,
                                    .host_log_pos = log_pos,
                                    .face = dir,
                                };
                                count += 1;
                            }
                        }
                    }
                }
            }
        }
    }

    return count;
}

/// Executes a Creaking puppet strike:
/// 1. Puppet absorbs strike taking 0 direct damage.
/// 2. Emits particle beam trail to Creaking Heart.
/// 3. If heart is off cooldown, extrudes 1..3 Resin Clumps on neighboring outer log faces.
pub fn strikeCreakingPuppet(
    puppet: *CreakingPuppetEntity,
    heart: *CreakingHeartBlock,
    available_candidates: []const ClumpSurfaceCandidate,
    requested_clump_count: u8,
) StrikeOutcome {
    const particles = calculateRedirectionParticles(puppet.pos, heart.pos);
    heart.total_strikes_absorbed += 1;

    var outcome = StrikeOutcome{
        .damage_dealt_to_puppet = 0.0,
        .particles_in_trail = particles,
        .clumps_spawned = 0,
        .cooldown_triggered = false,
        .heart_pos = heart.pos,
        .spawn_positions = undefined,
        .spawn_faces = undefined,
    };

    if (!heart.canExtrudeResin()) {
        return outcome;
    }

    // Extrude 1..3 clumps
    const to_spawn = @min(MAX_CLUMPS_PER_EXTRUSION, @max(MIN_CLUMPS_PER_EXTRUSION, requested_clump_count));
    const actual_count = @min(@as(usize, to_spawn), available_candidates.len);

    var i: usize = 0;
    while (i < actual_count) : (i += 1) {
        outcome.spawn_positions[i] = available_candidates[i].clump_pos;
        outcome.spawn_faces[i] = available_candidates[i].face;
    }

    outcome.clumps_spawned = @intCast(actual_count);
    outcome.cooldown_triggered = true;
    heart.triggerCooldown();
    heart.total_clumps_extruded += outcome.clumps_spawned;

    return outcome;
}

// ============================================================================
// Section 5: Resin Clump Hardening Lifecycle & State Machine
// ============================================================================

/// Progressive hardening stages of extruded resin.
pub const ResinHardeningStage = enum(u8) {
    fresh_viscous = 0, // Freshly extruded: soft, warm, glowing amber, malleable
    settling = 1,      // Cooling and polymerization: semi-rigid, curing
    hardened = 2,      // Fully cured solid resin clump: firm, standard hardness
    vitrified = 3,     // Vitrified / crystalline: dense, highly resistant masonry state

    pub fn name(self: ResinHardeningStage) []const u8 {
        return switch (self) {
            .fresh_viscous => "Fresh Viscous",
            .settling => "Settling",
            .hardened => "Hardened",
            .vitrified => "Vitrified",
        };
    }
};

/// Full state machine tracking the lifecycle and hardening of a Resin Clump.
pub const ResinHardeningLifecycle = struct {
    stage: ResinHardeningStage = .fresh_viscous,
    progress_ticks: u32 = 0,
    ticks_per_stage: u32 = 400, // 20 seconds per hardening stage

    pub fn init(ticks_per_stage: u32) ResinHardeningLifecycle {
        return .{
            .stage = .fresh_viscous,
            .progress_ticks = 0,
            .ticks_per_stage = ticks_per_stage,
        };
    }

    /// Advances the hardening timer and transitions between stages.
    pub fn tick(self: *ResinHardeningLifecycle, dt_ticks: u32) bool {
        if (self.stage == .vitrified) return false;

        self.progress_ticks += dt_ticks;
        if (self.progress_ticks >= self.ticks_per_stage) {
            self.progress_ticks -= self.ticks_per_stage;
            self.stage = switch (self.stage) {
                .fresh_viscous => .settling,
                .settling => .hardened,
                .hardened => .vitrified,
                .vitrified => .vitrified,
            };
            return true;
        }
        return false;
    }

    /// Hardness rating scaling from malleable fresh clump to hardened masonry.
    pub fn getHardness(self: *const ResinHardeningLifecycle) f32 {
        return switch (self.stage) {
            .fresh_viscous => 0.2,
            .settling => 0.5,
            .hardened => 1.0,
            .vitrified => 1.5,
        };
    }

    /// Blast resistance scaling with hardening stage.
    pub fn getBlastResistance(self: *const ResinHardeningLifecycle) f32 {
        return switch (self.stage) {
            .fresh_viscous => 0.5,
            .settling => 1.5,
            .hardened => 3.0,
            .vitrified => 4.5,
        };
    }

    /// Whether the clump has reached a fully cured or vitrified state.
    pub fn isHardened(self: *const ResinHardeningLifecycle) bool {
        return self.stage == .hardened or self.stage == .vitrified;
    }
};

/// Tool type used for breaking/harvesting resin clumps.
pub const HarvestTool = enum {
    hand,
    pickaxe,
    axe,
    shovel,
};

/// Evaluates drops when a Resin Clump block or layers are mined.
pub fn evaluateResinClumpDrops(
    layers: u8,
    is_consolidated: bool,
    tool: HarvestTool,
    has_silk_touch: bool,
) struct { item: ResinItemKind, count: u8, preserves_layers: bool } {
    _ = tool;
    if (is_consolidated) {
        if (has_silk_touch) {
            return .{ .item = .resin_block, .count = 1, .preserves_layers = false };
        } else {
            return .{ .item = .resin_clump, .count = RESIN_CLUMPS_PER_BLOCK, .preserves_layers = false };
        }
    }

    if (has_silk_touch) {
        return .{ .item = .resin_clump, .count = layers, .preserves_layers = true };
    } else {
        return .{ .item = .resin_clump, .count = layers, .preserves_layers = false };
    }
}

// ============================================================================
// Section 6: Smelting Engine & Workstation Pyrometallurgy
// ============================================================================

/// Furnace workstation types.
pub const FurnaceWorkstation = enum(u8) {
    standard_furnace,
    blast_furnace,
    smoker,

    pub fn name(self: FurnaceWorkstation) []const u8 {
        return switch (self) {
            .standard_furnace => "Standard Furnace",
            .blast_furnace => "Blast Furnace",
            .smoker => "Smoker",
        };
    }
};

/// Result of smelting operation.
pub const SmeltOutcome = struct {
    output_item: ResinItemKind,
    output_count: u32,
    experience_yield: f32,
    cook_ticks_per_item: u32,
    total_cook_ticks: u32,
    furnace_type: FurnaceWorkstation,
};

/// Evaluates if an item can be smelted in the specified workstation.
/// Resin Clump smelts in standard furnace and blast furnace, but NEVER in a smoker!
pub fn canSmeltInWorkstation(item: ResinItemKind, workstation: FurnaceWorkstation) bool {
    if (item != .resin_clump) return false;
    return switch (workstation) {
        .standard_furnace, .blast_furnace => true,
        .smoker => false,
    };
}

/// Smelts Resin Clumps into Resin Bricks with 0.1 XP yield per item.
pub fn smeltResinClump(
    item: ResinItemKind,
    count: u32,
    workstation: FurnaceWorkstation,
) ?SmeltOutcome {
    if (count == 0 or !canSmeltInWorkstation(item, workstation)) return null;

    const ticks_per_item: u32 = switch (workstation) {
        .standard_furnace => STANDARD_FURNACE_SMELT_TICKS, // 200 ticks = 10s
        .blast_furnace => BLAST_FURNACE_SMELT_TICKS,       // 100 ticks = 5s (2x speed)
        .smoker => return null,
    };

    return SmeltOutcome{
        .output_item = .resin_brick,
        .output_count = count,
        .experience_yield = @as(f32, @floatFromInt(count)) * SMELT_EXPERIENCE_YIELD,
        .cook_ticks_per_item = ticks_per_item,
        .total_cook_ticks = count * ticks_per_item,
        .furnace_type = workstation,
    };
}

/// Simulates progressive fuel burn and batch smelting over time.
pub const SmeltingSimulation = struct {
    input_item: ResinItemKind,
    input_count: u32,
    workstation: FurnaceWorkstation,
    cook_progress_ticks: u32 = 0,
    completed_items: u32 = 0,
    accumulated_xp: f32 = 0.0,

    pub fn init(item: ResinItemKind, count: u32, workstation: FurnaceWorkstation) ?SmeltingSimulation {
        if (!canSmeltInWorkstation(item, workstation)) return null;
        return .{
            .input_item = item,
            .input_count = count,
            .workstation = workstation,
            .cook_progress_ticks = 0,
            .completed_items = 0,
            .accumulated_xp = 0.0,
        };
    }

    pub fn tick(self: *SmeltingSimulation, dt_ticks: u32) u32 {
        if (self.input_count == 0) return 0;

        const ticks_per_item: u32 = switch (self.workstation) {
            .standard_furnace => STANDARD_FURNACE_SMELT_TICKS,
            .blast_furnace => BLAST_FURNACE_SMELT_TICKS,
            .smoker => return 0,
        };

        self.cook_progress_ticks += dt_ticks;
        var items_finished: u32 = 0;

        while (self.cook_progress_ticks >= ticks_per_item and self.input_count > 0) {
            self.cook_progress_ticks -= ticks_per_item;
            self.input_count -= 1;
            self.completed_items += 1;
            self.accumulated_xp += SMELT_EXPERIENCE_YIELD;
            items_finished += 1;
        }

        return items_finished;
    }
};

// ============================================================================
// Section 7: Masonry Architecture, Crafting & Stonecutting
// ============================================================================

/// Outcome of a crafting or stonecutting operation.
pub const CraftResult = struct {
    output_item: ResinItemKind,
    output_count: u32,
    consumed_count: u32,
    remainder_count: u32,
};

/// 2x2 Crafting: 4 Resin Bricks -> 1 Block of Resin Bricks.
pub fn craftResinBricks(resin_brick_count: u32) ?CraftResult {
    if (resin_brick_count < BRICKS_PER_RESIN_BRICK_BLOCK) return null;
    const crafted = resin_brick_count / BRICKS_PER_RESIN_BRICK_BLOCK;
    return .{
        .output_item = .resin_bricks,
        .output_count = crafted,
        .consumed_count = crafted * BRICKS_PER_RESIN_BRICK_BLOCK,
        .remainder_count = resin_brick_count % BRICKS_PER_RESIN_BRICK_BLOCK,
    };
}

/// 3x3 Crafting: 9 Resin Clumps -> 1 Block of Resin.
pub fn craftBlockOfResin(resin_clump_count: u32) ?CraftResult {
    if (resin_clump_count < RESIN_CLUMPS_PER_BLOCK) return null;
    const crafted = resin_clump_count / RESIN_CLUMPS_PER_BLOCK;
    return .{
        .output_item = .resin_block,
        .output_count = crafted,
        .consumed_count = crafted * RESIN_CLUMPS_PER_BLOCK,
        .remainder_count = resin_clump_count % RESIN_CLUMPS_PER_BLOCK,
    };
}

/// Deconstruction: 1 Block of Resin -> 9 Resin Clump items.
pub fn deconstructBlockOfResin(resin_block_count: u32) ?CraftResult {
    if (resin_block_count == 0) return null;
    return .{
        .output_item = .resin_clump,
        .output_count = resin_block_count * RESIN_CLUMPS_PER_BLOCK,
        .consumed_count = resin_block_count,
        .remainder_count = 0,
    };
}

/// Architectural Crafting: 3 Resin Bricks blocks -> 6 Resin Brick Slabs.
pub fn craftResinBrickSlabs(resin_bricks_count: u32) ?CraftResult {
    if (resin_bricks_count < SLAB_CRAFT_INPUT_BLOCKS) return null;
    const sets = resin_bricks_count / SLAB_CRAFT_INPUT_BLOCKS;
    return .{
        .output_item = .resin_brick_slab,
        .output_count = sets * SLABS_PER_CRAFT,
        .consumed_count = sets * SLAB_CRAFT_INPUT_BLOCKS,
        .remainder_count = resin_bricks_count % SLAB_CRAFT_INPUT_BLOCKS,
    };
}

/// Architectural Crafting: 6 Resin Bricks blocks -> 4 Resin Brick Stairs.
pub fn craftResinBrickStairs(resin_bricks_count: u32) ?CraftResult {
    if (resin_bricks_count < STAIR_CRAFT_INPUT_BLOCKS) return null;
    const sets = resin_bricks_count / STAIR_CRAFT_INPUT_BLOCKS;
    return .{
        .output_item = .resin_brick_stairs,
        .output_count = sets * STAIRS_PER_CRAFT,
        .consumed_count = sets * STAIR_CRAFT_INPUT_BLOCKS,
        .remainder_count = resin_bricks_count % STAIR_CRAFT_INPUT_BLOCKS,
    };
}

/// Architectural Crafting: 6 Resin Bricks blocks -> 6 Resin Brick Walls.
pub fn craftResinBrickWalls(resin_bricks_count: u32) ?CraftResult {
    if (resin_bricks_count < WALL_CRAFT_INPUT_BLOCKS) return null;
    const sets = resin_bricks_count / WALL_CRAFT_INPUT_BLOCKS;
    return .{
        .output_item = .resin_brick_wall,
        .output_count = sets * WALLS_PER_CRAFT,
        .consumed_count = sets * WALL_CRAFT_INPUT_BLOCKS,
        .remainder_count = resin_bricks_count % WALL_CRAFT_INPUT_BLOCKS,
    };
}

/// Architectural Crafting: 2 Resin Brick Slabs stacked vertically -> 1 Chiseled Resin Bricks block.
pub fn craftChiseledResinBricks(slab_count: u32) ?CraftResult {
    if (slab_count < CHISELED_SLABS_REQUIRED) return null;
    const crafted = slab_count / CHISELED_SLABS_REQUIRED;
    return .{
        .output_item = .chiseled_resin_bricks,
        .output_count = crafted,
        .consumed_count = crafted * CHISELED_SLABS_REQUIRED,
        .remainder_count = slab_count % CHISELED_SLABS_REQUIRED,
    };
}

/// Stonecutting: converts 1 Block of Resin Bricks directly into architectural variants.
pub fn stonecutResinBricks(target: ResinItemKind, input_count: u32) ?CraftResult {
    if (input_count == 0) return null;
    const yield_ratio: u32 = switch (target) {
        .resin_brick_slab => 2,      // 1 Block -> 2 Slabs
        .resin_brick_stairs => 1,    // 1 Block -> 1 Stair
        .resin_brick_wall => 1,      // 1 Block -> 1 Wall
        .chiseled_resin_bricks => 1, // 1 Block -> 1 Chiseled block
        else => return null,
    };

    return .{
        .output_item = target,
        .output_count = input_count * yield_ratio,
        .consumed_count = input_count,
        .remainder_count = 0,
    };
}

/// Double slab placement state: 2 slabs occupying the same block form a full double slab.
pub const SlabType = enum(u2) {
    bottom = 0,
    top = 1,
    double = 2,
};

/// Resin Wall post & collision state.
pub const WallState = struct {
    up: bool = true, // Center pillar post raised
    north: bool = false,
    south: bool = false,
    east: bool = false,
    west: bool = false,

    /// Wall collision height is 1.5 blocks (preventing regular jumps).
    pub fn getCollisionHeight(self: *const WallState) f32 {
        _ = self;
        return 1.5;
    }
};

// ============================================================================
// Section 8: Armor Trim Integration in Smithing Table
// ============================================================================

/// The 18 standard Armor Trim Smithing Templates in Minecraft.
pub const SmithingTrimPattern = enum(u8) {
    silence,
    ward,
    spire,
    vex,
    rib,
    snout,
    eye,
    tide,
    flow,
    bolt,
    wayfinder,
    raiser,
    shaper,
    host,
    coast,
    sentry,
    dune,
    wild,

    pub const all: [18]SmithingTrimPattern = .{
        .silence, .ward, .spire, .vex, .rib, .snout,
        .eye, .tide, .flow, .bolt, .wayfinder, .raiser,
        .shaper, .host, .coast, .sentry, .dune, .wild,
    };

    pub fn name(self: SmithingTrimPattern) []const u8 {
        return switch (self) {
            .silence => "Silence",
            .ward => "Ward",
            .spire => "Spire",
            .vex => "Vex",
            .rib => "Rib",
            .snout => "Snout",
            .eye => "Eye",
            .tide => "Tide",
            .flow => "Flow",
            .bolt => "Bolt",
            .wayfinder => "Wayfinder",
            .raiser => "Raiser",
            .shaper => "Shaper",
            .host => "Host",
            .coast => "Coast",
            .sentry => "Sentry",
            .dune => "Dune",
            .wild => "Wild",
        };
    }
};

/// Armor slot types.
pub const ArmorSlot = enum(u8) {
    helmet,
    chestplate,
    leggings,
    boots,

    pub const all: [4]ArmorSlot = .{ .helmet, .chestplate, .leggings, .boots };

    pub fn name(self: ArmorSlot) []const u8 {
        return switch (self) {
            .helmet => "Helmet",
            .chestplate => "Chestplate",
            .leggings => "Leggings",
            .boots => "Boots",
        };
    }
};

/// Base armor material types.
pub const ArmorBaseMaterial = enum(u8) {
    leather,
    chainmail,
    iron,
    golden,
    diamond,
    netherite,
    turtle,

    pub const all: [7]ArmorBaseMaterial = .{
        .leather, .chainmail, .iron, .golden, .diamond, .netherite, .turtle,
    };

    pub fn name(self: ArmorBaseMaterial) []const u8 {
        return switch (self) {
            .leather => "Leather",
            .chainmail => "Chainmail",
            .iron => "Iron",
            .golden => "Golden",
            .diamond => "Diamond",
            .netherite => "Netherite",
            .turtle => "Turtle",
        };
    }

    pub fn durability(self: ArmorBaseMaterial, slot: ArmorSlot) u32 {
        const base_multiplier: u32 = switch (self) {
            .leather => 5,
            .chainmail => 15,
            .iron => 14,
            .golden => 7,
            .diamond => 33,
            .netherite => 37,
            .turtle => 25,
        };
        const slot_factor: u32 = switch (slot) {
            .helmet => 11,
            .chestplate => 16,
            .leggings => 15,
            .boots => 13,
        };
        return base_multiplier * slot_factor;
    }
};

/// An armor item specification ready for smithing table trimming.
pub const ArmorItem = struct {
    slot: ArmorSlot,
    material: ArmorBaseMaterial,

    pub fn init(slot: ArmorSlot, material: ArmorBaseMaterial) ArmorItem {
        return .{ .slot = slot, .material = material };
    }
};

/// Result of applying a resin trim to an armor piece.
pub const TrimmedArmorSpec = struct {
    armor: ArmorItem,
    pattern: SmithingTrimPattern,
    trim_material_name: []const u8 = "Resin",
    color_hex: u24 = RESIN_ORANGE_HEX,
    color_rgb: [3]f32 = RESIN_ORANGE_RGB,

    /// Contrast shade applied when trimming golden armor to avoid blending with base armor.
    pub fn getActiveTrimHex(self: *const TrimmedArmorSpec) u24 {
        if (self.armor.material == .golden) {
            return RESIN_DARK_CONTRAST_HEX;
        }
        return self.color_hex;
    }
};

/// Evaluates if an item qualifies as a valid Resin trim addition material.
pub fn isValidResinTrimMaterial(item: ResinItemKind) bool {
    return item == .resin_brick or item == .resin_clump;
}

/// Applies an orange Resin trim in the Smithing Table using an Armor Trim Smithing Template.
pub fn applyResinArmorTrim(
    has_template: bool,
    pattern: SmithingTrimPattern,
    armor_opt: ?ArmorItem,
    addition_item: ResinItemKind,
) ?TrimmedArmorSpec {
    if (!has_template) return null;
    const armor = armor_opt orelse return null;
    if (!isValidResinTrimMaterial(addition_item)) return null;

    return TrimmedArmorSpec{
        .armor = armor,
        .pattern = pattern,
        .trim_material_name = "Resin",
        .color_hex = RESIN_ORANGE_HEX,
        .color_rgb = RESIN_ORANGE_RGB,
    };
}

// ============================================================================
// Section 9: Comprehensive Unit Test Suite (30 Tests)
// ============================================================================

test "1. Creaking puppet strike redirects 0 direct damage and emits particle beam trail" {
    const heart_pos = BlockPos.init(10, 64, 10);
    var puppet = CreakingPuppetEntity.init(1, .{ 10.0, 64.0, 20.0 }, heart_pos); // 10 blocks away
    var heart = CreakingHeartBlock.init(heart_pos, true);

    try std.testing.expect(puppet.isWithinTether());

    const particles = calculateRedirectionParticles(puppet.pos, heart_pos);
    try std.testing.expect(particles >= MIN_BEAM_PARTICLES);
    try std.testing.expect(particles <= MAX_BEAM_PARTICLES);

    const candidates = [_]ClumpSurfaceCandidate{
        .{ .clump_pos = heart_pos.offset(.north), .host_log_pos = heart_pos.offsetBy(0, 1, 0), .face = .north },
    };

    const outcome = strikeCreakingPuppet(&puppet, &heart, &candidates, 1);
    try std.testing.expectEqual(@as(f32, 0.0), outcome.damage_dealt_to_puppet);
    try std.testing.expectEqual(particles, outcome.particles_in_trail);
    try std.testing.expectEqual(@as(u8, 1), outcome.clumps_spawned);
    try std.testing.expect(outcome.cooldown_triggered);
}

test "2. Creaking Heart extrusion cooldown enforces 100-tick delay between strikes" {
    const heart_pos = BlockPos.init(0, 64, 0);
    var puppet = CreakingPuppetEntity.init(1, .{ 0.0, 64.0, 4.0 }, heart_pos);
    var heart = CreakingHeartBlock.init(heart_pos, true);

    const candidates = [_]ClumpSurfaceCandidate{
        .{ .clump_pos = heart_pos.offset(.east), .host_log_pos = heart_pos.offsetBy(0, 1, 0), .face = .east },
    };

    // Strike 1: Heart ready -> spawns clump, starts 100-tick cooldown
    try std.testing.expect(heart.canExtrudeResin());
    const hit1 = strikeCreakingPuppet(&puppet, &heart, &candidates, 1);
    try std.testing.expectEqual(@as(u8, 1), hit1.clumps_spawned);
    try std.testing.expectEqual(RESIN_EXTRUSION_COOLDOWN_TICKS, heart.resin_cooldown_ticks);
    try std.testing.expect(!heart.canExtrudeResin());

    // Immediate Strike 2: On cooldown -> 0 clumps spawned
    const hit2 = strikeCreakingPuppet(&puppet, &heart, &candidates, 1);
    try std.testing.expectEqual(@as(u8, 0), hit2.clumps_spawned);
    try std.testing.expect(!hit2.cooldown_triggered);

    // Advance 50 ticks (halfway): still on cooldown
    heart.tick(50);
    try std.testing.expectEqual(@as(u32, 50), heart.resin_cooldown_ticks);
    try std.testing.expect(!heart.canExtrudeResin());

    // Advance remaining 50 ticks: cooldown expires
    heart.tick(50);
    try std.testing.expectEqual(@as(u32, 0), heart.resin_cooldown_ticks);
    try std.testing.expect(heart.canExtrudeResin());

    // Strike 3: Off cooldown -> spawns clump again!
    const hit3 = strikeCreakingPuppet(&puppet, &heart, &candidates, 1);
    try std.testing.expectEqual(@as(u8, 1), hit3.clumps_spawned);
    try std.testing.expectEqual(RESIN_EXTRUSION_COOLDOWN_TICKS, heart.resin_cooldown_ticks);
}

test "3. Striking Creaking Heart spawns 1..3 Resin Clumps on neighboring pale oak log surfaces" {
    const heart_pos = BlockPos.init(20, 65, 30);
    var puppet = CreakingPuppetEntity.init(2, .{ 20.0, 65.0, 25.0 }, heart_pos);
    var heart = CreakingHeartBlock.init(heart_pos, true);

    const candidates = [_]ClumpSurfaceCandidate{
        .{ .clump_pos = BlockPos.init(21, 66, 30), .host_log_pos = BlockPos.init(20, 66, 30), .face = .east },
        .{ .clump_pos = BlockPos.init(19, 66, 30), .host_log_pos = BlockPos.init(20, 66, 30), .face = .west },
        .{ .clump_pos = BlockPos.init(20, 66, 31), .host_log_pos = BlockPos.init(20, 66, 30), .face = .south },
    };

    // Request 3 clumps
    const hit = strikeCreakingPuppet(&puppet, &heart, &candidates, 3);
    try std.testing.expectEqual(@as(u8, 3), hit.clumps_spawned);
    try std.testing.expect(hit.spawn_positions[0].equals(candidates[0].clump_pos));
    try std.testing.expect(hit.spawn_positions[1].equals(candidates[1].clump_pos));
    try std.testing.expect(hit.spawn_positions[2].equals(candidates[2].clump_pos));
    try std.testing.expectEqual(Direction.east, hit.spawn_faces[0]);
    try std.testing.expectEqual(Direction.west, hit.spawn_faces[1]);
    try std.testing.expectEqual(Direction.south, hit.spawn_faces[2]);
}

test "4. Resin Clump surface attachment validates face orientation and host alignment" {
    const log_pos = BlockPos.init(50, 70, 50);

    // Attach to North face
    const north_pos = log_pos.offset(.north);
    const clump_north = ResinClumpAttachment.init(north_pos, log_pos, .north, 1);
    try std.testing.expect(clump_north.isValidAttachment());
    try std.testing.expectEqual(Direction.north, clump_north.attached_face);

    // Attach to Up face
    const up_pos = log_pos.offset(.up);
    const clump_up = ResinClumpAttachment.init(up_pos, log_pos, .up, 1);
    try std.testing.expect(clump_up.isValidAttachment());
    try std.testing.expectEqual(Direction.up, clump_up.attached_face);

    // Misaligned position fails validation
    const wrong_pos = BlockPos.init(99, 99, 99);
    const invalid_clump = ResinClumpAttachment.init(wrong_pos, log_pos, .north, 1);
    try std.testing.expect(!invalid_clump.isValidAttachment());
}

test "5. Clump accumulation accumulates layers up to maximum of 5 layers" {
    const log_pos = BlockPos.init(10, 64, 10);
    var clump = ResinClumpAttachment.init(log_pos.offset(.east), log_pos, .east, 1);
    try std.testing.expectEqual(@as(u8, 1), clump.layers);

    // Add 2 layers -> 3 total
    const acc1 = clump.accumulateLayers(2);
    try std.testing.expectEqual(@as(u8, 2), acc1.added);
    try std.testing.expectEqual(@as(u8, 3), acc1.total_layers);
    try std.testing.expect(!acc1.reached_max);

    // Add 2 more layers -> 5 total (reached maximum!)
    const acc2 = clump.accumulateLayers(2);
    try std.testing.expectEqual(@as(u8, 2), acc2.added);
    try std.testing.expectEqual(@as(u8, 5), acc2.total_layers);
    try std.testing.expect(acc2.reached_max);

    // Further addition caps at 5 layers
    const acc3 = clump.accumulateLayers(3);
    try std.testing.expectEqual(@as(u8, 0), acc3.added);
    try std.testing.expectEqual(@as(u8, 5), acc3.total_layers);
    try std.testing.expect(acc3.reached_max);
}

test "6. Consolidation of 9 resin clumps into a solid Block of Resin" {
    const log_pos = BlockPos.init(0, 64, 0);
    var clump = ResinClumpAttachment.init(log_pos.offset(.south), log_pos, .south, 1);

    // Less than 9 clumps: consolidation fails
    try std.testing.expect(!clump.consolidateIntoBlock(8));
    try std.testing.expect(!clump.is_consolidated);

    // Exactly 9 clumps: consolidates into solid Block of Resin
    try std.testing.expect(clump.consolidateIntoBlock(9));
    try std.testing.expect(clump.is_consolidated);
    try std.testing.expectEqual(MAX_RESIN_LAYERS, clump.layers);
}

test "7. Resin Clump hardening lifecycle transitions through four distinct stages" {
    var lifecycle = ResinHardeningLifecycle.init(100); // 100 ticks per stage

    // Stage 0: Fresh Viscous
    try std.testing.expectEqual(ResinHardeningStage.fresh_viscous, lifecycle.stage);
    try std.testing.expect(!lifecycle.isHardened());
    try std.testing.expectEqual(@as(f32, 0.2), lifecycle.getHardness());
    try std.testing.expectEqual(@as(f32, 0.5), lifecycle.getBlastResistance());

    // Advance 100 ticks -> Stage 1: Settling
    try std.testing.expect(lifecycle.tick(100));
    try std.testing.expectEqual(ResinHardeningStage.settling, lifecycle.stage);
    try std.testing.expect(!lifecycle.isHardened());
    try std.testing.expectEqual(@as(f32, 0.5), lifecycle.getHardness());
    try std.testing.expectEqual(@as(f32, 1.5), lifecycle.getBlastResistance());

    // Advance 100 ticks -> Stage 2: Hardened
    try std.testing.expect(lifecycle.tick(100));
    try std.testing.expectEqual(ResinHardeningStage.hardened, lifecycle.stage);
    try std.testing.expect(lifecycle.isHardened());
    try std.testing.expectEqual(@as(f32, 1.0), lifecycle.getHardness());
    try std.testing.expectEqual(@as(f32, 3.0), lifecycle.getBlastResistance());

    // Advance 100 ticks -> Stage 3: Vitrified
    try std.testing.expect(lifecycle.tick(100));
    try std.testing.expectEqual(ResinHardeningStage.vitrified, lifecycle.stage);
    try std.testing.expect(lifecycle.isHardened());
    try std.testing.expectEqual(@as(f32, 1.5), lifecycle.getHardness());
    try std.testing.expectEqual(@as(f32, 4.5), lifecycle.getBlastResistance());

    // Further ticks do not advance past vitrified
    try std.testing.expect(!lifecycle.tick(100));
    try std.testing.expectEqual(ResinHardeningStage.vitrified, lifecycle.stage);
}

test "8. Harvesting resin clump drops items matching layer count and preserves layers on silk touch" {
    // Normal harvest of 4-layer clump yields 4 resin clumps
    const normal_drops = evaluateResinClumpDrops(4, false, .pickaxe, false);
    try std.testing.expectEqual(ResinItemKind.resin_clump, normal_drops.item);
    try std.testing.expectEqual(@as(u8, 4), normal_drops.count);
    try std.testing.expect(!normal_drops.preserves_layers);

    // Silk touch harvest of 3-layer clump preserves layers
    const silk_drops = evaluateResinClumpDrops(3, false, .pickaxe, true);
    try std.testing.expectEqual(ResinItemKind.resin_clump, silk_drops.item);
    try std.testing.expectEqual(@as(u8, 3), silk_drops.count);
    try std.testing.expect(silk_drops.preserves_layers);

    // Normal harvest of consolidated block drops 9 clumps
    const block_normal = evaluateResinClumpDrops(5, true, .pickaxe, false);
    try std.testing.expectEqual(ResinItemKind.resin_clump, block_normal.item);
    try std.testing.expectEqual(@as(u8, 9), block_normal.count);

    // Silk touch harvest of consolidated block drops 1 Block of Resin item
    const block_silk = evaluateResinClumpDrops(5, true, .pickaxe, true);
    try std.testing.expectEqual(ResinItemKind.resin_block, block_silk.item);
    try std.testing.expectEqual(@as(u8, 1), block_silk.count);
}

test "9. Smelting: Resin Clump smelts in standard furnace yielding Resin Brick and 0.1 XP (200 ticks)" {
    const outcome_opt = smeltResinClump(.resin_clump, 1, .standard_furnace);
    try std.testing.expect(outcome_opt != null);
    const outcome = outcome_opt.?;

    try std.testing.expectEqual(ResinItemKind.resin_brick, outcome.output_item);
    try std.testing.expectEqual(@as(u32, 1), outcome.output_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), outcome.experience_yield, 0.0001);
    try std.testing.expectEqual(STANDARD_FURNACE_SMELT_TICKS, outcome.cook_ticks_per_item);
    try std.testing.expectEqual(@as(u32, 200), outcome.total_cook_ticks);
}

test "10. Smelting: Resin Clump smelts in blast furnace at 2x speed (100 ticks) and yields 0.1 XP" {
    const outcome_opt = smeltResinClump(.resin_clump, 4, .blast_furnace);
    try std.testing.expect(outcome_opt != null);
    const outcome = outcome_opt.?;

    try std.testing.expectEqual(ResinItemKind.resin_brick, outcome.output_item);
    try std.testing.expectEqual(@as(u32, 4), outcome.output_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), outcome.experience_yield, 0.0001);
    try std.testing.expectEqual(BLAST_FURNACE_SMELT_TICKS, outcome.cook_ticks_per_item);
    try std.testing.expectEqual(@as(u32, 400), outcome.total_cook_ticks); // 4 * 100 ticks
}

test "11. Smelting: Food smoker rejects Resin Clump" {
    try std.testing.expect(!canSmeltInWorkstation(.resin_clump, .smoker));
    const outcome = smeltResinClump(.resin_clump, 1, .smoker);
    try std.testing.expect(outcome == null);
}

test "12. Smelting: Progressive simulation yields completed bricks and banks experience" {
    var sim = SmeltingSimulation.init(.resin_clump, 5, .blast_furnace).?;

    // Tick 99 ticks: not yet finished first item
    const f0 = sim.tick(99);
    try std.testing.expectEqual(@as(u32, 0), f0);
    try std.testing.expectEqual(@as(u32, 0), sim.completed_items);

    // 1 more tick (100th tick): finishes first brick!
    const f1 = sim.tick(1);
    try std.testing.expectEqual(@as(u32, 1), f1);
    try std.testing.expectEqual(@as(u32, 1), sim.completed_items);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), sim.accumulated_xp, 0.0001);

    // Advance 400 more ticks: finishes remaining 4 bricks
    const f4 = sim.tick(400);
    try std.testing.expectEqual(@as(u32, 4), f4);
    try std.testing.expectEqual(@as(u32, 5), sim.completed_items);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), sim.accumulated_xp, 0.0001);
}

test "13. Masonry 2x2 Crafting: 4 Resin Bricks yield 1 Block of Resin Bricks" {
    // Less than 4 bricks cannot craft
    try std.testing.expect(craftResinBricks(3) == null);

    // 4 bricks -> 1 block, 0 remainder
    const c1 = craftResinBricks(4).?;
    try std.testing.expectEqual(ResinItemKind.resin_bricks, c1.output_item);
    try std.testing.expectEqual(@as(u32, 1), c1.output_count);
    try std.testing.expectEqual(@as(u32, 4), c1.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), c1.remainder_count);

    // 14 bricks -> 3 blocks, 2 remainder
    const c2 = craftResinBricks(14).?;
    try std.testing.expectEqual(@as(u32, 3), c2.output_count);
    try std.testing.expectEqual(@as(u32, 12), c2.consumed_count);
    try std.testing.expectEqual(@as(u32, 2), c2.remainder_count);
}

test "14. Masonry 3x3 Crafting: 9 Resin Clumps yield 1 Block of Resin and reverse deconstructs" {
    // 9 clumps -> 1 Block of Resin
    const c9 = craftBlockOfResin(9).?;
    try std.testing.expectEqual(ResinItemKind.resin_block, c9.output_item);
    try std.testing.expectEqual(@as(u32, 1), c9.output_count);
    try std.testing.expectEqual(@as(u32, 9), c9.consumed_count);

    // Deconstruct 1 Block of Resin -> 9 Resin Clumps
    const dec = deconstructBlockOfResin(1).?;
    try std.testing.expectEqual(ResinItemKind.resin_clump, dec.output_item);
    try std.testing.expectEqual(@as(u32, 9), dec.output_count);
    try std.testing.expectEqual(@as(u32, 1), dec.consumed_count);
}

test "15. Architectural Crafting: 3 Resin Bricks blocks yield 6 Resin Brick Slabs" {
    try std.testing.expect(craftResinBrickSlabs(2) == null);

    const slabs = craftResinBrickSlabs(3).?;
    try std.testing.expectEqual(ResinItemKind.resin_brick_slab, slabs.output_item);
    try std.testing.expectEqual(@as(u32, 6), slabs.output_count);
    try std.testing.expectEqual(@as(u32, 3), slabs.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), slabs.remainder_count);
}

test "16. Architectural Crafting: 6 Resin Bricks blocks yield 4 Resin Brick Stairs" {
    try std.testing.expect(craftResinBrickStairs(5) == null);

    const stairs = craftResinBrickStairs(6).?;
    try std.testing.expectEqual(ResinItemKind.resin_brick_stairs, stairs.output_item);
    try std.testing.expectEqual(@as(u32, 4), stairs.output_count);
    try std.testing.expectEqual(@as(u32, 6), stairs.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), stairs.remainder_count);
}

test "17. Architectural Crafting: 6 Resin Bricks blocks yield 6 Resin Brick Walls" {
    try std.testing.expect(craftResinBrickWalls(5) == null);

    const walls = craftResinBrickWalls(6).?;
    try std.testing.expectEqual(ResinItemKind.resin_brick_wall, walls.output_item);
    try std.testing.expectEqual(@as(u32, 6), walls.output_count);
    try std.testing.expectEqual(@as(u32, 6), walls.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), walls.remainder_count);
}

test "18. Architectural Crafting: 2 Resin Brick Slabs yield 1 Chiseled Resin Bricks block" {
    try std.testing.expect(craftChiseledResinBricks(1) == null);

    const chiseled = craftChiseledResinBricks(2).?;
    try std.testing.expectEqual(ResinItemKind.chiseled_resin_bricks, chiseled.output_item);
    try std.testing.expectEqual(@as(u32, 1), chiseled.output_count);
    try std.testing.expectEqual(@as(u32, 2), chiseled.consumed_count);
    try std.testing.expectEqual(@as(u32, 0), chiseled.remainder_count);
}

test "19. Stonecutter converts 1 Block of Resin Bricks directly into architectural variants" {
    // 1 block -> 2 slabs
    const sc_slabs = stonecutResinBricks(.resin_brick_slab, 1).?;
    try std.testing.expectEqual(@as(u32, 2), sc_slabs.output_count);

    // 1 block -> 1 stairs
    const sc_stairs = stonecutResinBricks(.resin_brick_stairs, 1).?;
    try std.testing.expectEqual(@as(u32, 1), sc_stairs.output_count);

    // 1 block -> 1 wall
    const sc_wall = stonecutResinBricks(.resin_brick_wall, 1).?;
    try std.testing.expectEqual(@as(u32, 1), sc_wall.output_count);

    // 1 block -> 1 chiseled block
    const sc_chiseled = stonecutResinBricks(.chiseled_resin_bricks, 1).?;
    try std.testing.expectEqual(@as(u32, 1), sc_chiseled.output_count);

    // Invalid stonecutting target returns null
    try std.testing.expect(stonecutResinBricks(.pale_oak_log, 1) == null);
}

test "20. Armor Trim: Smithing table accepts Resin Brick as orange trim material" {
    const armor = ArmorItem.init(.chestplate, .netherite);
    const trim_opt = applyResinArmorTrim(true, .silence, armor, .resin_brick);

    try std.testing.expect(trim_opt != null);
    const trim = trim_opt.?;
    try std.testing.expectEqual(ArmorSlot.chestplate, trim.armor.slot);
    try std.testing.expectEqual(ArmorBaseMaterial.netherite, trim.armor.material);
    try std.testing.expectEqual(SmithingTrimPattern.silence, trim.pattern);
    try std.testing.expectEqual(@as(u24, RESIN_ORANGE_HEX), trim.color_hex);
    try std.testing.expectEqualStrings("Resin", trim.trim_material_name);
}

test "21. Armor Trim: Resin Clump also qualifies as valid resin trim material" {
    const armor = ArmorItem.init(.helmet, .diamond);
    const trim_opt = applyResinArmorTrim(true, .ward, armor, .resin_clump);

    try std.testing.expect(trim_opt != null);
    const trim = trim_opt.?;
    try std.testing.expectEqual(ArmorSlot.helmet, trim.armor.slot);
    try std.testing.expectEqual(SmithingTrimPattern.ward, trim.pattern);
    try std.testing.expectEqual(@as(u24, RESIN_ORANGE_HEX), trim.color_hex);
}

test "22. Armor Trim: All 18 SmithingTrimPattern templates are compatible with Resin trim" {
    const armor = ArmorItem.init(.chestplate, .iron);

    for (SmithingTrimPattern.all) |pat| {
        const trim = applyResinArmorTrim(true, pat, armor, .resin_brick);
        try std.testing.expect(trim != null);
        try std.testing.expectEqual(pat, trim.?.pattern);
        try std.testing.expect(pat.name().len > 0);
    }
}

test "23. Armor Trim: All 4 armor slots accept Resin trim" {
    for (ArmorSlot.all) |slot| {
        const armor = ArmorItem.init(slot, .diamond);
        const trim = applyResinArmorTrim(true, .spire, armor, .resin_brick);
        try std.testing.expect(trim != null);
        try std.testing.expectEqual(slot, trim.?.armor.slot);
        try std.testing.expect(slot.name().len > 0);
    }
}

test "24. Armor Trim: All 7 base armor materials accept Resin trim" {
    for (ArmorBaseMaterial.all) |mat| {
        const armor = ArmorItem.init(.boots, mat);
        const trim = applyResinArmorTrim(true, .coast, armor, .resin_brick);
        try std.testing.expect(trim != null);
        try std.testing.expectEqual(mat, trim.?.armor.material);
        try std.testing.expect(armor.material.durability(armor.slot) > 0);
    }
}

test "25. Armor Trim: Golden armor applies darker contrast shade for optimal visibility" {
    const gold_armor = ArmorItem.init(.chestplate, .golden);
    const gold_trim = applyResinArmorTrim(true, .rib, gold_armor, .resin_brick).?;
    try std.testing.expectEqual(@as(u24, RESIN_DARK_CONTRAST_HEX), gold_trim.getActiveTrimHex());

    const diamond_armor = ArmorItem.init(.chestplate, .diamond);
    const diamond_trim = applyResinArmorTrim(true, .rib, diamond_armor, .resin_brick).?;
    try std.testing.expectEqual(@as(u24, RESIN_ORANGE_HEX), diamond_trim.getActiveTrimHex());
}

test "26. Armor Trim: Invalid inputs (missing template, missing armor, invalid addition) rejected" {
    const armor = ArmorItem.init(.leggings, .netherite);

    // Missing template -> null
    try std.testing.expect(applyResinArmorTrim(false, .vex, armor, .resin_brick) == null);

    // Missing armor -> null
    try std.testing.expect(applyResinArmorTrim(true, .vex, null, .resin_brick) == null);

    // Invalid trim material (e.g. pale oak log or air) -> null
    try std.testing.expect(applyResinArmorTrim(true, .vex, armor, .pale_oak_log) == null);
    try std.testing.expect(applyResinArmorTrim(true, .vex, armor, .none) == null);
}

test "27. Resin masonry blocks physical properties and blast resistance" {
    // Resin Bricks: hardness 1.5, blast resistance 6.0, non-flammable
    try std.testing.expectEqual(@as(f32, 1.5), ResinBlockKind.resin_bricks.hardness());
    try std.testing.expectEqual(@as(f32, 6.0), ResinBlockKind.resin_bricks.blastResistance());
    try std.testing.expect(!ResinBlockKind.resin_bricks.isFlammable());
    try std.testing.expect(ResinBlockKind.resin_bricks.isSolid());

    // Block of Resin: hardness 1.5, blast resistance 5.0
    try std.testing.expectEqual(@as(f32, 1.5), ResinBlockKind.resin_block.hardness());
    try std.testing.expectEqual(@as(f32, 5.0), ResinBlockKind.resin_block.blastResistance());

    // Architectural variants have matching hardness and blast resistance
    try std.testing.expectEqual(@as(f32, 1.5), ResinBlockKind.chiseled_resin_bricks.hardness());
    try std.testing.expectEqual(@as(f32, 6.0), ResinBlockKind.chiseled_resin_bricks.blastResistance());
    try std.testing.expectEqual(@as(f32, 1.5), ResinBlockKind.resin_brick_slab.hardness());
    try std.testing.expectEqual(@as(f32, 1.5), ResinBlockKind.resin_brick_stairs.hardness());
    try std.testing.expectEqual(@as(f32, 1.5), ResinBlockKind.resin_brick_wall.hardness());
}

test "28. Resin Brick Wall collision height and slab type classification" {
    const wall = WallState{};
    try std.testing.expectEqual(@as(f32, 1.5), wall.getCollisionHeight());

    const bottom_slab = SlabType.bottom;
    const top_slab = SlabType.top;
    const double_slab = SlabType.double;

    try std.testing.expect(bottom_slab != top_slab);
    try std.testing.expect(double_slab == .double);
}

test "29. Spatial neighborhood scanner locates exposed outer log surfaces" {
    const heart_pos = BlockPos.init(10, 64, 10);

    // Mock logs function: vertical logs at y=63 and y=65 (sandwiched heart)
    const is_log = struct {
        fn check(pos: BlockPos) bool {
            return (pos.x == 10 and pos.z == 10 and (pos.y == 63 or pos.y == 65));
        }
    }.check;

    // Mock air function: everything else is air
    const is_air = struct {
        fn check(pos: BlockPos) bool {
            return !(pos.x == 10 and pos.z == 10 and (pos.y == 63 or pos.y == 65 or pos.y == 64));
        }
    }.check;

    var candidates: [24]ClumpSurfaceCandidate = undefined;
    const count = findExposedLogSurfaces(heart_pos, is_log, is_air, &candidates);

    // Log at y=63 has 5 exposed faces (down, north, south, east, west; up is heart)
    // Log at y=65 has 5 exposed faces (up, north, south, east, west; down is heart)
    // Total 10 exposed log surfaces!
    try std.testing.expectEqual(@as(usize, 10), count);
}

test "30. Full end-to-end resin lifecycle: extrusion, accumulation, smelting, and masonry crafting" {
    // Step 1: Creaking struck -> extrudes 3 clumps
    const heart_pos = BlockPos.init(0, 64, 0);
    var puppet = CreakingPuppetEntity.init(1, .{ 0.0, 64.0, 10.0 }, heart_pos);
    var heart = CreakingHeartBlock.init(heart_pos, true);

    const candidates = [_]ClumpSurfaceCandidate{
        .{ .clump_pos = BlockPos.init(1, 65, 0), .host_log_pos = BlockPos.init(0, 65, 0), .face = .east },
        .{ .clump_pos = BlockPos.init(-1, 65, 0), .host_log_pos = BlockPos.init(0, 65, 0), .face = .west },
        .{ .clump_pos = BlockPos.init(0, 65, 1), .host_log_pos = BlockPos.init(0, 65, 0), .face = .south },
    };

    const strike = strikeCreakingPuppet(&puppet, &heart, &candidates, 3);
    try std.testing.expectEqual(@as(u8, 3), strike.clumps_spawned);

    // Step 2: Surface clump accumulates to 5 layers
    var attachment = ResinClumpAttachment.init(strike.spawn_positions[0], candidates[0].host_log_pos, strike.spawn_faces[0], 3);
    _ = attachment.accumulateLayers(2);
    try std.testing.expectEqual(@as(u8, 5), attachment.layers);

    // Step 3: Harvest yields 5 clump items
    const drops = evaluateResinClumpDrops(attachment.layers, false, .pickaxe, false);
    try std.testing.expectEqual(@as(u8, 5), drops.count);

    // Step 4: Smelt 4 clumps into 4 Resin Bricks
    const smelt = smeltResinClump(drops.item, 4, .blast_furnace).?;
    try std.testing.expectEqual(ResinItemKind.resin_brick, smelt.output_item);
    try std.testing.expectEqual(@as(u32, 4), smelt.output_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), smelt.experience_yield, 0.0001);

    // Step 5: Craft 4 Resin Bricks into 1 Resin Bricks block
    const craft = craftResinBricks(smelt.output_count).?;
    try std.testing.expectEqual(ResinItemKind.resin_bricks, craft.output_item);
    try std.testing.expectEqual(@as(u32, 1), craft.output_count);

    // Step 6: Stonecut 1 Resin Bricks block into 2 Resin Brick Slabs
    const slabs = stonecutResinBricks(.resin_brick_slab, craft.output_count).?;
    try std.testing.expectEqual(ResinItemKind.resin_brick_slab, slabs.output_item);
    try std.testing.expectEqual(@as(u32, 2), slabs.output_count);

    // Step 7: Craft 2 Slabs into 1 Chiseled Resin Bricks block
    const chiseled = craftChiseledResinBricks(slabs.output_count).?;
    try std.testing.expectEqual(ResinItemKind.chiseled_resin_bricks, chiseled.output_item);
    try std.testing.expectEqual(@as(u32, 1), chiseled.output_count);
}
