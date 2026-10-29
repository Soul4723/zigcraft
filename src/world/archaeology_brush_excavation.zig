const std = @import("std");

// ============================================================================
// Milestone 470: Archaeology Brush Excavation & Suspicious Substrate Extraction
// ============================================================================

/// Game ticks and timing constants for archaeological excavation.
pub const TICKS_PER_SECOND: u32 = 20;
pub const TOTAL_EXCAVATION_TICKS: u16 = 96; // 4.8 seconds * 20 ticks/sec
pub const BRUSHING_CYCLE_TICKS: u16 = 4; // Each brushing cycle is 4 game ticks
pub const TOTAL_BRUSHING_CYCLES: u16 = 24; // 96 / 4 = 24 brushing cycles
pub const TICKS_PER_STAGE: u16 = 24; // 4 dust stages, 24 ticks each
pub const EXCAVATION_DURATION_SECONDS: f32 = 4.8;
pub const DECAY_TICKS_PER_STAGE: u16 = 40; // 2.0 seconds * 20 ticks/sec
pub const DECAY_INTERVAL_SECONDS: f32 = 2.0;
pub const MAX_INTERACTION_DISTANCE: f32 = 4.5; // Max block reach for brushing
pub const SNIFFER_EGG_PROBABILITY: f32 = 0.067; // 6.7% in warm ocean ruins

/// Item identifiers mirroring the global inventory vocabulary.
pub const ItemType = enum(u16) {
    none = 0,
    stick = 8,
    coal = 12,
    sand = 14,
    wooden_hoe = 24,
    gold_nugget = 81,
    iron_axe = 100,
    gravel = 127,
    diamond = 217,
    wheat = 267,
    emerald = 273,
    copper_ingot = 284,
    feather = 288,
    brush = 367,
    suspicious_sand = 368,
    pottery_sherd = 369,
    music_disc_relic = 473,
    wayfinder_armor_trim = 485,
    raiser_armor_trim = 486,
    shaper_armor_trim = 487,
    host_armor_trim = 488,
    sniffer_egg = 492,
    suspicious_gravel = 493,

    pub fn maxDurability(self: ItemType) u16 {
        return switch (self) {
            .brush => 64,
            else => 0,
        };
    }

    pub fn isTool(self: ItemType) bool {
        return self == .brush;
    }

    pub fn name(self: ItemType) []const u8 {
        return switch (self) {
            .none => "Air",
            .stick => "Stick",
            .coal => "Coal",
            .sand => "Sand",
            .wooden_hoe => "Wooden Hoe",
            .gold_nugget => "Gold Nugget",
            .iron_axe => "Iron Axe",
            .gravel => "Gravel",
            .diamond => "Diamond",
            .wheat => "Wheat",
            .emerald => "Emerald",
            .copper_ingot => "Copper Ingot",
            .feather => "Feather",
            .brush => "Brush",
            .suspicious_sand => "Suspicious Sand",
            .pottery_sherd => "Pottery Sherd",
            .music_disc_relic => "Music Disc (Relic)",
            .wayfinder_armor_trim => "Wayfinder Armor Trim",
            .raiser_armor_trim => "Raiser Armor Trim",
            .shaper_armor_trim => "Shaper Armor Trim",
            .host_armor_trim => "Host Armor Trim",
            .sniffer_egg => "Sniffer Egg",
            .suspicious_gravel => "Suspicious Gravel",
        };
    }
};

/// Item stack representation for crafting and inventories.
pub const ItemStack = struct {
    item: ItemType,
    count: u8 = 1,
    durability: u16 = 64,
};

/// Brush tool with 64 max durability.
pub const Brush = struct {
    pub const MAX_DURABILITY: u16 = 64;
    durability: u16 = MAX_DURABILITY,

    pub fn init() Brush {
        return .{ .durability = MAX_DURABILITY };
    }

    pub fn initWithDurability(durability: u16) Brush {
        return .{ .durability = @min(durability, MAX_DURABILITY) };
    }

    pub fn isBroken(self: Brush) bool {
        return self.durability == 0;
    }

    pub fn canBrush(self: Brush) bool {
        return self.durability > 0;
    }

    /// Consumes durability. Returns true if the brush is still usable, false if broken.
    pub fn consumeDurability(self: *Brush, amount: u16) bool {
        if (self.durability <= amount) {
            self.durability = 0;
            return false;
        }
        self.durability -= amount;
        return true;
    }
};

/// Crafting recipes for Brush: 1 Feather + 1 Copper Ingot + 1 Stick in a vertical column.
pub fn craftBrushVertical(top: ItemType, middle: ItemType, bottom: ItemType) ?ItemStack {
    if (top == .feather and middle == .copper_ingot and bottom == .stick) {
        return ItemStack{
            .item = .brush,
            .count = 1,
            .durability = Brush.MAX_DURABILITY,
        };
    }
    return null;
}

pub fn canCraftBrush(top: ItemType, middle: ItemType, bottom: ItemType) bool {
    return craftBrushVertical(top, middle, bottom) != null;
}

/// 3x3 crafting grid checker for the vertical brush recipe in any of the 3 columns:
/// Col 0: (0, 3, 6)
/// Col 1: (1, 4, 7)
/// Col 2: (2, 5, 8)
pub fn craftBrush3x3(grid: [9]?ItemType) ?ItemStack {
    const col_indices = [3][3]usize{
        .{ 0, 3, 6 },
        .{ 1, 4, 7 },
        .{ 2, 5, 8 },
    };

    for (col_indices) |col| {
        const top = grid[col[0]];
        const mid = grid[col[1]];
        const bot = grid[col[2]];

        if (top != null and top.? == .feather and
            mid != null and mid.? == .copper_ingot and
            bot != null and bot.? == .stick)
        {
            // Verify all other 6 slots are empty
            var others_empty = true;
            for (grid, 0..) |slot, idx| {
                if (idx != col[0] and idx != col[1] and idx != col[2]) {
                    if (slot != null and slot.? != .none) {
                        others_empty = false;
                        break;
                    }
                }
            }
            if (others_empty) {
                return ItemStack{
                    .item = .brush,
                    .count = 1,
                    .durability = Brush.MAX_DURABILITY,
                };
            }
        }
    }
    return null;
}

/// Suspicious substrate block types: suspicious sand and suspicious gravel.
pub const SuspiciousBlockType = enum(u8) {
    suspicious_sand,
    suspicious_gravel,

    pub fn toItemType(self: SuspiciousBlockType) ItemType {
        return switch (self) {
            .suspicious_sand => .suspicious_sand,
            .suspicious_gravel => .suspicious_gravel,
        };
    }

    pub fn regularSubstrate(self: SuspiciousBlockType) ItemType {
        return switch (self) {
            .suspicious_sand => .sand,
            .suspicious_gravel => .gravel,
        };
    }

    pub fn regularSubstrateName(self: SuspiciousBlockType) []const u8 {
        return switch (self) {
            .suspicious_sand => "Sand",
            .suspicious_gravel => "Gravel",
        };
    }

    pub fn name(self: SuspiciousBlockType) []const u8 {
        return switch (self) {
            .suspicious_sand => "Suspicious Sand",
            .suspicious_gravel => "Suspicious Gravel",
        };
    }

    pub fn isSuspicious(item: ItemType) bool {
        return item == .suspicious_sand or item == .suspicious_gravel;
    }

    pub fn fromItemType(item: ItemType) ?SuspiciousBlockType {
        return switch (item) {
            .suspicious_sand => .suspicious_sand,
            .suspicious_gravel => .suspicious_gravel,
            else => null,
        };
    }

    pub fn naturalStructures(self: SuspiciousBlockType) []const StructureType {
        return switch (self) {
            .suspicious_sand => &.{ .desert_pyramid, .desert_well, .warm_ocean_ruins },
            .suspicious_gravel => &.{ .cold_ocean_ruins, .trail_ruins },
        };
    }

    pub fn isValidInStructure(self: SuspiciousBlockType, structure: StructureType) bool {
        return switch (self) {
            .suspicious_sand => structure == .desert_pyramid or structure == .desert_well or structure == .warm_ocean_ruins,
            .suspicious_gravel => structure == .cold_ocean_ruins or structure == .trail_ruins,
        };
    }
};

/// Archaeological structure locations where suspicious blocks naturally occur.
pub const StructureType = enum {
    desert_pyramid,
    desert_well,
    warm_ocean_ruins,
    cold_ocean_ruins,
    trail_ruins,

    pub fn expectedSubstrate(self: StructureType) SuspiciousBlockType {
        return switch (self) {
            .desert_pyramid, .desert_well, .warm_ocean_ruins => .suspicious_sand,
            .cold_ocean_ruins, .trail_ruins => .suspicious_gravel,
        };
    }

    pub fn name(self: StructureType) []const u8 {
        return switch (self) {
            .desert_pyramid => "Desert Pyramid",
            .desert_well => "Desert Well",
            .warm_ocean_ruins => "Warm Ocean Ruins",
            .cold_ocean_ruins => "Cold Ocean Ruins",
            .trail_ruins => "Trail Ruins",
        };
    }
};

/// The 20 pottery sherds in Minecraft 1.20+.
pub const PotterySherd = enum(u8) {
    angler,
    archer,
    arms_up,
    blade,
    brewer,
    burn,
    danger,
    explorer,
    friend,
    heart,
    howl,
    miner,
    mourner,
    plenty,
    prize,
    scrape,
    sheaf,
    shelter,
    skull,
    snort,

    pub fn name(self: PotterySherd) []const u8 {
        return switch (self) {
            .angler => "Angler Pottery Sherd",
            .archer => "Archer Pottery Sherd",
            .arms_up => "Arms Up Pottery Sherd",
            .blade => "Blade Pottery Sherd",
            .brewer => "Brewer Pottery Sherd",
            .burn => "Burn Pottery Sherd",
            .danger => "Danger Pottery Sherd",
            .explorer => "Explorer Pottery Sherd",
            .friend => "Friend Pottery Sherd",
            .heart => "Heart Pottery Sherd",
            .howl => "Howl Pottery Sherd",
            .miner => "Miner Pottery Sherd",
            .mourner => "Mourner Pottery Sherd",
            .plenty => "Plenty Pottery Sherd",
            .prize => "Prize Pottery Sherd",
            .scrape => "Scrape Pottery Sherd",
            .sheaf => "Sheaf Pottery Sherd",
            .shelter => "Shelter Pottery Sherd",
            .skull => "Skull Pottery Sherd",
            .snort => "Snort Pottery Sherd",
        };
    }
};

/// Exclusive armor trims discovered in archaeological substrates (Trail Ruins).
pub const ArmorTrim = enum(u8) {
    wayfinder,
    raiser,
    shaper,
    host,

    pub fn name(self: ArmorTrim) []const u8 {
        return switch (self) {
            .wayfinder => "Wayfinder Armor Trim Smithing Template",
            .raiser => "Raiser Armor Trim Smithing Template",
            .shaper => "Shaper Armor Trim Smithing Template",
            .host => "Host Armor Trim Smithing Template",
        };
    }

    pub fn toItemType(self: ArmorTrim) ItemType {
        return switch (self) {
            .wayfinder => .wayfinder_armor_trim,
            .raiser => .raiser_armor_trim,
            .shaper => .shaper_armor_trim,
            .host => .host_armor_trim,
        };
    }
};

/// Tagged union representing archaeological loot items found in suspicious blocks.
pub const ArchaeologyLoot = union(enum) {
    pottery_sherd: PotterySherd,
    sniffer_egg: void,
    armor_trim: ArmorTrim,
    emerald: void,
    wheat: void,
    coal: void,
    diamond: void,
    gold_nugget: void,
    iron_axe: void,
    wooden_hoe: void,
    music_disc_relic: void,

    pub fn toItemType(self: ArchaeologyLoot) ItemType {
        return switch (self) {
            .pottery_sherd => .pottery_sherd,
            .sniffer_egg => .sniffer_egg,
            .armor_trim => |t| t.toItemType(),
            .emerald => .emerald,
            .wheat => .wheat,
            .coal => .coal,
            .diamond => .diamond,
            .gold_nugget => .gold_nugget,
            .iron_axe => .iron_axe,
            .wooden_hoe => .wooden_hoe,
            .music_disc_relic => .music_disc_relic,
        };
    }

    pub fn name(self: ArchaeologyLoot) []const u8 {
        return switch (self) {
            .pottery_sherd => |s| s.name(),
            .sniffer_egg => "Sniffer Egg",
            .armor_trim => |t| t.name(),
            .emerald => "Emerald",
            .wheat => "Wheat",
            .coal => "Coal",
            .diamond => "Diamond",
            .gold_nugget => "Gold Nugget",
            .iron_axe => "Iron Axe",
            .wooden_hoe => "Wooden Hoe",
            .music_disc_relic => "Music Disc (Relic)",
        };
    }

    pub fn isRare(self: ArchaeologyLoot) bool {
        return switch (self) {
            .sniffer_egg, .armor_trim, .pottery_sherd, .diamond, .music_disc_relic => true,
            else => false,
        };
    }

    pub fn isSherd(self: ArchaeologyLoot) bool {
        return self == .pottery_sherd;
    }

    pub fn isTrim(self: ArchaeologyLoot) bool {
        return self == .armor_trim;
    }
};

/// Particle emissions associated with brushing progression.
pub const DustParticleType = enum {
    none,
    initial_puff,
    heavy_puff,
    continuous_plume,
    completion_burst,
};

/// 4 progressive dusting stages plus stage 4 complete.
pub const DustStage = enum(u3) {
    stage_0 = 0, // 0% uncovered
    stage_1 = 1, // 25% uncovered (initial dust puff, top tip of artifact visible)
    stage_2 = 2, // 50% uncovered (heavy dust puff, half of artifact visible)
    stage_3 = 3, // 75% uncovered (artifact almost completely exposed)
    stage_4_complete = 4, // 100% uncovered (artifact fully extruded, block converts)

    pub fn percentUncovered(self: DustStage) u8 {
        return switch (self) {
            .stage_0 => 0,
            .stage_1 => 25,
            .stage_2 => 50,
            .stage_3 => 75,
            .stage_4_complete => 100,
        };
    }

    pub fn exposureFraction(self: DustStage) f32 {
        return switch (self) {
            .stage_0 => 0.0,
            .stage_1 => 0.25,
            .stage_2 => 0.50,
            .stage_3 => 0.75,
            .stage_4_complete => 1.0,
        };
    }

    pub fn particleEffect(self: DustStage) DustParticleType {
        return switch (self) {
            .stage_0 => .none,
            .stage_1 => .initial_puff,
            .stage_2 => .heavy_puff,
            .stage_3 => .continuous_plume,
            .stage_4_complete => .completion_burst,
        };
    }

    pub fn description(self: DustStage) []const u8 {
        return switch (self) {
            .stage_0 => "0% uncovered",
            .stage_1 => "25% uncovered (initial dust puff, top tip of artifact visible)",
            .stage_2 => "50% uncovered (heavy dust puff, half of artifact visible)",
            .stage_3 => "75% uncovered (artifact almost completely exposed)",
            .stage_4_complete => "100% uncovered (artifact fully extruded, block converts to regular Sand or Gravel)",
        };
    }
};

/// Maps game ticks (0..96) to dust stages.
pub fn stageFromTicks(ticks: u16) DustStage {
    if (ticks >= TOTAL_EXCAVATION_TICKS) return .stage_4_complete;
    if (ticks >= 72) return .stage_3;
    if (ticks >= 48) return .stage_2;
    if (ticks >= 24) return .stage_1;
    return .stage_0;
}

/// Result of direct mining of a suspicious block with any tool or hand.
pub const MiningResult = struct {
    dropped_item: ItemType,
    count: u8 = 1,
    artifact_destroyed: bool = true,
    block_destroyed: bool = true,
};

/// Result of fragile physics fall impact: instant shattering with zero drops.
pub const FallImpactResult = struct {
    shattered: bool = true,
    items_dropped: usize = 0,
    artifact_destroyed: bool = true,
};

/// Spawned artifact entity extruded from completed excavation.
pub const ArtifactEntity = struct {
    loot: ArchaeologyLoot,
    position: [3]f32,
    velocity: [3]f32,
    pickup_delay_ticks: u8 = 10,

    pub fn init(block_pos: [3]i32, loot: ArchaeologyLoot) ArtifactEntity {
        return .{
            .loot = loot,
            .position = .{
                @as(f32, @floatFromInt(block_pos[0])) + 0.5,
                @as(f32, @floatFromInt(block_pos[1])) + 0.5,
                @as(f32, @floatFromInt(block_pos[2])) + 0.5,
            },
            .velocity = .{ 0.0, 0.2, 0.0 }, // Small upward pop velocity
            .pickup_delay_ticks = 10,
        };
    }
};

/// Interaction outcome per tick.
pub const ExcavationOutcome = struct {
    completed: bool,
    current_stage: DustStage,
    brush_ticks: u16,
    brushing_cycle: u8,
    durability_consumed: u16,
    artifact: ?ArtifactEntity = null,
    converted_substrate: ?ItemType = null,
    particle_effect: DustParticleType,
};

/// State of an in-world suspicious block undergoing brush excavation.
pub const SuspiciousBlock = struct {
    position: [3]i32,
    substrate_type: SuspiciousBlockType,
    structure: StructureType,
    buried_loot: ArchaeologyLoot,
    brush_ticks: u16 = 0,
    is_brushing: bool = false,
    decay_timer: u16 = 0,
    is_excavated: bool = false,
    is_destroyed: bool = false,

    pub fn init(pos: [3]i32, substrate: SuspiciousBlockType, structure: StructureType, loot: ArchaeologyLoot) SuspiciousBlock {
        return .{
            .position = pos,
            .substrate_type = substrate,
            .structure = structure,
            .buried_loot = loot,
            .brush_ticks = 0,
            .is_brushing = false,
            .decay_timer = 0,
            .is_excavated = false,
            .is_destroyed = false,
        };
    }

    pub fn currentStage(self: SuspiciousBlock) DustStage {
        if (self.is_excavated) return .stage_4_complete;
        return stageFromTicks(self.brush_ticks);
    }

    pub fn brushingCycle(self: SuspiciousBlock) u8 {
        return @intCast(@min(self.brush_ticks / BRUSHING_CYCLE_TICKS, TOTAL_BRUSHING_CYCLES));
    }

    pub fn progressSeconds(self: SuspiciousBlock) f32 {
        return @as(f32, @floatFromInt(self.brush_ticks)) / @as(f32, @floatFromInt(TICKS_PER_SECOND));
    }

    pub fn progressFraction(self: SuspiciousBlock) f32 {
        if (self.is_excavated) return 1.0;
        return @min(@as(f32, @floatFromInt(self.brush_ticks)) / @as(f32, @floatFromInt(TOTAL_EXCAVATION_TICKS)), 1.0);
    }

    pub fn isAffectedByGravity(self: SuspiciousBlock) bool {
        _ = self;
        return true;
    }

    pub fn shattersOnFall(self: SuspiciousBlock) bool {
        _ = self;
        return true;
    }

    /// Fragile physics: if suspicious block falls, it shatters and drops NOTHING.
    pub fn onFallImpact(self: *SuspiciousBlock) FallImpactResult {
        self.is_destroyed = true;
        return .{
            .shattered = true,
            .items_dropped = 0,
            .artifact_destroyed = true,
        };
    }

    /// Piston push instantly shatters suspicious blocks without dropping anything.
    pub fn onPistonPush(self: *SuspiciousBlock) FallImpactResult {
        self.is_destroyed = true;
        return .{
            .shattered = true,
            .items_dropped = 0,
            .artifact_destroyed = true,
        };
    }

    /// Direct mining: breaking with any tool drops regular sand or gravel; artifact is destroyed.
    pub fn mine(self: *SuspiciousBlock, _: ?ItemType) MiningResult {
        self.is_destroyed = true;
        return .{
            .dropped_item = self.substrate_type.regularSubstrate(),
            .count = 1,
            .artifact_destroyed = true,
            .block_destroyed = true,
        };
    }

    /// Starts brushing action.
    pub fn startBrushing(self: *SuspiciousBlock) void {
        if (self.is_excavated or self.is_destroyed) return;
        self.is_brushing = true;
        self.decay_timer = 0;
    }

    /// Interrupted brushing (e.g. player releases right click before completion).
    /// Consumes 1 durability point upon interrupted brushing.
    pub fn interruptBrushing(self: *SuspiciousBlock, brush: ?*Brush) void {
        if (!self.is_brushing) return;
        self.is_brushing = false;
        if (!self.is_excavated and self.brush_ticks > 0) {
            if (brush) |b| {
                _ = b.consumeDurability(1);
            }
        }
    }

    /// Advances brushing by 1 tick while player is right-clicking with an intact brush.
    pub fn brushTick(self: *SuspiciousBlock, brush: *Brush) ?ExcavationOutcome {
        if (self.is_excavated or self.is_destroyed) return null;
        if (!brush.canBrush()) return null;

        self.is_brushing = true;
        self.decay_timer = 0;
        self.brush_ticks += 1;

        const cycle = self.brushingCycle();
        const stage = self.currentStage();

        if (self.brush_ticks >= TOTAL_EXCAVATION_TICKS) {
            self.is_excavated = true;
            self.is_brushing = false;
            _ = brush.consumeDurability(1);

            const entity = ArtifactEntity.init(self.position, self.buried_loot);
            return ExcavationOutcome{
                .completed = true,
                .current_stage = .stage_4_complete,
                .brush_ticks = self.brush_ticks,
                .brushing_cycle = TOTAL_BRUSHING_CYCLES,
                .durability_consumed = 1,
                .artifact = entity,
                .converted_substrate = self.substrate_type.regularSubstrate(),
                .particle_effect = .completion_burst,
            };
        }

        return ExcavationOutcome{
            .completed = false,
            .current_stage = stage,
            .brush_ticks = self.brush_ticks,
            .brushing_cycle = cycle,
            .durability_consumed = 0,
            .artifact = null,
            .converted_substrate = null,
            .particle_effect = stage.particleEffect(),
        };
    }

    /// Advances multiple ticks at once while continuously brushing.
    pub fn brushTicks(self: *SuspiciousBlock, ticks: u16, brush: *Brush) ?ExcavationOutcome {
        var last_outcome: ?ExcavationOutcome = null;
        var i: u16 = 0;
        while (i < ticks) : (i += 1) {
            last_outcome = self.brushTick(brush);
            if (self.is_excavated) break;
        }
        return last_outcome;
    }

    /// Brushing with distance/reach validation (Minecraft max reach is 4.5 blocks).
    pub fn brushWithReach(
        self: *SuspiciousBlock,
        brush: *Brush,
        player_pos: [3]f32,
        max_reach: f32,
    ) ?ExcavationOutcome {
        const center_x = @as(f32, @floatFromInt(self.position[0])) + 0.5;
        const center_y = @as(f32, @floatFromInt(self.position[1])) + 0.5;
        const center_z = @as(f32, @floatFromInt(self.position[2])) + 0.5;
        const dx = player_pos[0] - center_x;
        const dy = player_pos[1] - center_y;
        const dz = player_pos[2] - center_z;
        const dist_sq = dx * dx + dy * dy + dz * dz;

        if (dist_sq > max_reach * max_reach) {
            self.interruptBrushing(brush);
            return null;
        }

        return self.brushTick(brush);
    }

    /// Decays progress when not brushing: 1 dust stage every 40 ticks (2.0s) until stage 0.
    pub fn tickDecay(self: *SuspiciousBlock) bool {
        if (self.is_excavated or self.is_destroyed or self.is_brushing or self.brush_ticks == 0) {
            self.decay_timer = 0;
            return false;
        }

        self.decay_timer += 1;
        if (self.decay_timer >= DECAY_TICKS_PER_STAGE) {
            self.decay_timer = 0;
            const current_stage = self.currentStage();
            switch (current_stage) {
                .stage_4_complete => {},
                .stage_3 => {
                    self.brush_ticks = 48; // Decay to stage 2
                    return true;
                },
                .stage_2 => {
                    self.brush_ticks = 24; // Decay to stage 1
                    return true;
                },
                .stage_1 => {
                    self.brush_ticks = 0; // Decay to stage 0
                    return true;
                },
                .stage_0 => {
                    self.brush_ticks = 0;
                },
            }
        }
        return false;
    }

    /// Advances decay by multiple ticks. Returns number of stages decayed.
    pub fn decayByTicks(self: *SuspiciousBlock, elapsed_ticks: u16) u8 {
        var decayed: u8 = 0;
        var i: u16 = 0;
        while (i < elapsed_ticks) : (i += 1) {
            if (self.tickDecay()) {
                decayed += 1;
            }
        }
        return decayed;
    }

    /// Comprehensive game loop update tick.
    pub fn update(self: *SuspiciousBlock, holding_right_click: bool, brush: *Brush) ?ExcavationOutcome {
        if (self.is_excavated or self.is_destroyed) return null;

        if (holding_right_click) {
            if (!brush.canBrush()) return null;
            return self.brushTick(brush);
        } else {
            if (self.is_brushing) {
                self.interruptBrushing(brush);
            }
            _ = self.tickDecay();
            return null;
        }
    }

    /// Resulting block after excavation (regular sand/gravel) or current block.
    pub fn resultingBlock(self: SuspiciousBlock) ItemType {
        if (self.is_excavated) {
            return self.substrate_type.regularSubstrate();
        }
        return self.substrate_type.toItemType();
    }
};

/// Loot table sampling for archaeological structures.
pub fn lootForWarmOceanRuins(roll: f32) ArchaeologyLoot {
    if (roll < SNIFFER_EGG_PROBABILITY) {
        return .{ .sniffer_egg = {} };
    }
    const rem = (roll - SNIFFER_EGG_PROBABILITY) / (1.0 - SNIFFER_EGG_PROBABILITY);
    const index = @as(usize, @intFromFloat(@min(@max(rem, 0.0), 0.9999) * 9.0));
    return switch (index) {
        0 => .{ .pottery_sherd = .angler },
        1 => .{ .pottery_sherd = .shelter },
        2 => .{ .pottery_sherd = .snort },
        3 => .{ .emerald = {} },
        4 => .{ .wheat = {} },
        5 => .{ .coal = {} },
        6 => .{ .iron_axe = {} },
        7 => .{ .wooden_hoe = {} },
        else => .{ .gold_nugget = {} },
    };
}

pub fn lootForColdOceanRuins(roll: f32) ArchaeologyLoot {
    const clamped = @min(@max(roll, 0.0), 0.9999);
    const index = @as(usize, @intFromFloat(clamped * 10.0));
    return switch (index) {
        0 => .{ .pottery_sherd = .blade },
        1 => .{ .pottery_sherd = .explorer },
        2 => .{ .pottery_sherd = .mourner },
        3 => .{ .pottery_sherd = .plenty },
        4 => .{ .emerald = {} },
        5 => .{ .wheat = {} },
        6 => .{ .coal = {} },
        7 => .{ .iron_axe = {} },
        8 => .{ .wooden_hoe = {} },
        else => .{ .gold_nugget = {} },
    };
}

pub fn lootForTrailRuins(roll: f32) ArchaeologyLoot {
    const clamped = @min(@max(roll, 0.0), 0.9999);
    // 4 armor trims (Wayfinder, Raiser, Shaper, Host) + 10 pottery sherds + common loot
    const index = @as(usize, @intFromFloat(clamped * 18.0));
    return switch (index) {
        0 => .{ .armor_trim = .wayfinder },
        1 => .{ .armor_trim = .raiser },
        2 => .{ .armor_trim = .shaper },
        3 => .{ .armor_trim = .host },
        4 => .{ .pottery_sherd = .burn },
        5 => .{ .pottery_sherd = .danger },
        6 => .{ .pottery_sherd = .friend },
        7 => .{ .pottery_sherd = .heart },
        8 => .{ .pottery_sherd = .howl },
        9 => .{ .pottery_sherd = .mourner },
        10 => .{ .pottery_sherd = .plenty },
        11 => .{ .pottery_sherd = .sheaf },
        12 => .{ .pottery_sherd = .shelter },
        13 => .{ .pottery_sherd = .snort },
        14 => .{ .emerald = {} },
        15 => .{ .wheat = {} },
        16 => .{ .coal = {} },
        else => .{ .music_disc_relic = {} },
    };
}

pub fn lootForDesertPyramid(roll: f32) ArchaeologyLoot {
    const clamped = @min(@max(roll, 0.0), 0.9999);
    const index = @as(usize, @intFromFloat(clamped * 7.0));
    return switch (index) {
        0 => .{ .pottery_sherd = .archer },
        1 => .{ .pottery_sherd = .miner },
        2 => .{ .pottery_sherd = .prize },
        3 => .{ .pottery_sherd = .skull },
        4 => .{ .diamond = {} },
        5 => .{ .emerald = {} },
        else => .{ .coal = {} },
    };
}

pub fn lootForDesertWell(roll: f32) ArchaeologyLoot {
    const clamped = @min(@max(roll, 0.0), 0.9999);
    const index = @as(usize, @intFromFloat(clamped * 4.0));
    return switch (index) {
        0 => .{ .pottery_sherd = .arms_up },
        1 => .{ .pottery_sherd = .brewer },
        2 => .{ .emerald = {} },
        else => .{ .wheat = {} },
    };
}

pub fn lootForStructure(structure: StructureType, roll: f32) ArchaeologyLoot {
    return switch (structure) {
        .warm_ocean_ruins => lootForWarmOceanRuins(roll),
        .cold_ocean_ruins => lootForColdOceanRuins(roll),
        .trail_ruins => lootForTrailRuins(roll),
        .desert_pyramid => lootForDesertPyramid(roll),
        .desert_well => lootForDesertWell(roll),
    };
}

// ============================================================================
// Unit Tests (30+ comprehensive tests)
// ============================================================================

test "1. Brush initial durability is 64 and tool classification" {
    const brush = Brush.init();
    try std.testing.expectEqual(@as(u16, 64), brush.durability);
    try std.testing.expect(!brush.isBroken());
    try std.testing.expect(brush.canBrush());
    try std.testing.expectEqual(@as(u16, 64), ItemType.brush.maxDurability());
    try std.testing.expect(ItemType.brush.isTool());
    try std.testing.expect(!ItemType.sand.isTool());
}

test "2. Brush crafting vertical column: feather + copper ingot + stick -> brush (durability 64)" {
    const result = craftBrushVertical(.feather, .copper_ingot, .stick);
    try std.testing.expect(result != null);
    const stack = result.?;
    try std.testing.expectEqual(ItemType.brush, stack.item);
    try std.testing.expectEqual(@as(u8, 1), stack.count);
    try std.testing.expectEqual(@as(u16, 64), stack.durability);
    try std.testing.expect(canCraftBrush(.feather, .copper_ingot, .stick));
}

test "3. Brush crafting in 3x3 grid across all 3 columns (left, center, right)" {
    // Column 0 (left: indices 0, 3, 6)
    var grid0 = [_]?ItemType{null} ** 9;
    grid0[0] = .feather;
    grid0[3] = .copper_ingot;
    grid0[6] = .stick;
    const res0 = craftBrush3x3(grid0);
    try std.testing.expect(res0 != null);
    try std.testing.expectEqual(ItemType.brush, res0.?.item);

    // Column 1 (center: indices 1, 4, 7)
    var grid1 = [_]?ItemType{null} ** 9;
    grid1[1] = .feather;
    grid1[4] = .copper_ingot;
    grid1[7] = .stick;
    const res1 = craftBrush3x3(grid1);
    try std.testing.expect(res1 != null);
    try std.testing.expectEqual(ItemType.brush, res1.?.item);

    // Column 2 (right: indices 2, 5, 8)
    var grid2 = [_]?ItemType{null} ** 9;
    grid2[2] = .feather;
    grid2[5] = .copper_ingot;
    grid2[8] = .stick;
    const res2 = craftBrush3x3(grid2);
    try std.testing.expect(res2 != null);
    try std.testing.expectEqual(ItemType.brush, res2.?.item);
}

test "4. Brush crafting rejects invalid recipes, wrong ingredients, or horizontal alignment" {
    // Inverted vertical order
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrushVertical(.stick, .copper_ingot, .feather));
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrushVertical(.copper_ingot, .feather, .stick));
    // Wrong ingredients
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrushVertical(.wheat, .copper_ingot, .stick));
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrushVertical(.feather, .diamond, .stick));

    // Horizontal arrangement in 3x3 grid (indices 0, 1, 2)
    var horiz_grid = [_]?ItemType{null} ** 9;
    horiz_grid[0] = .feather;
    horiz_grid[1] = .copper_ingot;
    horiz_grid[2] = .stick;
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrush3x3(horiz_grid));

    // Valid column but with extra clutter in grid
    var polluted_grid = [_]?ItemType{null} ** 9;
    polluted_grid[0] = .feather;
    polluted_grid[3] = .copper_ingot;
    polluted_grid[6] = .stick;
    polluted_grid[1] = .sand; // Extra clutter
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrush3x3(polluted_grid));
}

test "5. SuspiciousBlockType detection: suspicious sand and gravel mapping" {
    try std.testing.expect(SuspiciousBlockType.isSuspicious(.suspicious_sand));
    try std.testing.expect(SuspiciousBlockType.isSuspicious(.suspicious_gravel));
    try std.testing.expect(!SuspiciousBlockType.isSuspicious(.sand));
    try std.testing.expect(!SuspiciousBlockType.isSuspicious(.gravel));

    try std.testing.expectEqual(SuspiciousBlockType.suspicious_sand, SuspiciousBlockType.fromItemType(.suspicious_sand).?);
    try std.testing.expectEqual(SuspiciousBlockType.suspicious_gravel, SuspiciousBlockType.fromItemType(.suspicious_gravel).?);
    try std.testing.expectEqual(@as(?SuspiciousBlockType, null), SuspiciousBlockType.fromItemType(.sand));

    try std.testing.expectEqual(ItemType.sand, SuspiciousBlockType.suspicious_sand.regularSubstrate());
    try std.testing.expectEqual(ItemType.gravel, SuspiciousBlockType.suspicious_gravel.regularSubstrate());
}

test "6. SuspiciousBlockType natural structure association (Desert, Ocean Ruins, Trail Ruins)" {
    const sand_structures = SuspiciousBlockType.suspicious_sand.naturalStructures();
    try std.testing.expectEqual(@as(usize, 3), sand_structures.len);
    try std.testing.expect(SuspiciousBlockType.suspicious_sand.isValidInStructure(.desert_pyramid));
    try std.testing.expect(SuspiciousBlockType.suspicious_sand.isValidInStructure(.desert_well));
    try std.testing.expect(SuspiciousBlockType.suspicious_sand.isValidInStructure(.warm_ocean_ruins));
    try std.testing.expect(!SuspiciousBlockType.suspicious_sand.isValidInStructure(.trail_ruins));

    const gravel_structures = SuspiciousBlockType.suspicious_gravel.naturalStructures();
    try std.testing.expectEqual(@as(usize, 2), gravel_structures.len);
    try std.testing.expect(SuspiciousBlockType.suspicious_gravel.isValidInStructure(.cold_ocean_ruins));
    try std.testing.expect(SuspiciousBlockType.suspicious_gravel.isValidInStructure(.trail_ruins));
    try std.testing.expect(!SuspiciousBlockType.suspicious_gravel.isValidInStructure(.desert_pyramid));

    try std.testing.expectEqual(SuspiciousBlockType.suspicious_sand, StructureType.desert_pyramid.expectedSubstrate());
    try std.testing.expectEqual(SuspiciousBlockType.suspicious_sand, StructureType.desert_well.expectedSubstrate());
    try std.testing.expectEqual(SuspiciousBlockType.suspicious_sand, StructureType.warm_ocean_ruins.expectedSubstrate());
    try std.testing.expectEqual(SuspiciousBlockType.suspicious_gravel, StructureType.cold_ocean_ruins.expectedSubstrate());
    try std.testing.expectEqual(SuspiciousBlockType.suspicious_gravel, StructureType.trail_ruins.expectedSubstrate());
}

test "7. Falling physics: suspicious sand shatters on fall impact and drops 0 items" {
    var block = SuspiciousBlock.init(.{ 10, 64, 10 }, .suspicious_sand, .desert_pyramid, .{ .diamond = {} });
    try std.testing.expect(block.isAffectedByGravity());
    try std.testing.expect(block.shattersOnFall());

    const result = block.onFallImpact();
    try std.testing.expect(result.shattered);
    try std.testing.expectEqual(@as(usize, 0), result.items_dropped);
    try std.testing.expect(result.artifact_destroyed);
    try std.testing.expect(block.is_destroyed);
}

test "8. Falling physics: suspicious gravel shatters on fall impact and drops 0 items" {
    var block = SuspiciousBlock.init(.{ 20, 50, 20 }, .suspicious_gravel, .trail_ruins, .{ .armor_trim = .wayfinder });
    try std.testing.expect(block.isAffectedByGravity());
    try std.testing.expect(block.shattersOnFall());

    const result = block.onFallImpact();
    try std.testing.expect(result.shattered);
    try std.testing.expectEqual(@as(usize, 0), result.items_dropped);
    try std.testing.expect(result.artifact_destroyed);
    try std.testing.expect(block.is_destroyed);
}

test "9. Piston push fragile physics shatters suspicious block with zero drops" {
    var block = SuspiciousBlock.init(.{ 5, 60, 5 }, .suspicious_sand, .desert_well, .{ .pottery_sherd = .arms_up });
    const result = block.onPistonPush();
    try std.testing.expect(result.shattered);
    try std.testing.expectEqual(@as(usize, 0), result.items_dropped);
    try std.testing.expect(result.artifact_destroyed);
    try std.testing.expect(block.is_destroyed);
}

test "10. Direct mining suspicious sand drops regular sand and destroys artifact" {
    var block = SuspiciousBlock.init(.{ 10, 30, -5 }, .suspicious_sand, .desert_pyramid, .{ .pottery_sherd = .archer });
    const mining = block.mine(null); // Mined with bare hand or any tool
    try std.testing.expectEqual(ItemType.sand, mining.dropped_item);
    try std.testing.expectEqual(@as(u8, 1), mining.count);
    try std.testing.expect(mining.artifact_destroyed);
    try std.testing.expect(mining.block_destroyed);
    try std.testing.expect(block.is_destroyed);
}

test "11. Direct mining suspicious gravel drops regular gravel and destroys artifact" {
    var block = SuspiciousBlock.init(.{ -12, 45, 100 }, .suspicious_gravel, .cold_ocean_ruins, .{ .pottery_sherd = .blade });
    const mining = block.mine(.iron_axe); // Mined with axe or shovel
    try std.testing.expectEqual(ItemType.gravel, mining.dropped_item);
    try std.testing.expectEqual(@as(u8, 1), mining.count);
    try std.testing.expect(mining.artifact_destroyed);
    try std.testing.expect(mining.block_destroyed);
    try std.testing.expect(block.is_destroyed);
}

test "12. 4-stage dust progression: Stage 0 (0% uncovered, 0-23 ticks)" {
    try std.testing.expectEqual(DustStage.stage_0, stageFromTicks(0));
    try std.testing.expectEqual(DustStage.stage_0, stageFromTicks(10));
    try std.testing.expectEqual(DustStage.stage_0, stageFromTicks(23));
    try std.testing.expectEqual(@as(u8, 0), DustStage.stage_0.percentUncovered());
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), DustStage.stage_0.exposureFraction(), 0.001);
    try std.testing.expectEqual(DustParticleType.none, DustStage.stage_0.particleEffect());
}

test "13. 4-stage dust progression: Stage 1 (25% uncovered, 24-47 ticks, initial dust puff)" {
    try std.testing.expectEqual(DustStage.stage_1, stageFromTicks(24));
    try std.testing.expectEqual(DustStage.stage_1, stageFromTicks(35));
    try std.testing.expectEqual(DustStage.stage_1, stageFromTicks(47));
    try std.testing.expectEqual(@as(u8, 25), DustStage.stage_1.percentUncovered());
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), DustStage.stage_1.exposureFraction(), 0.001);
    try std.testing.expectEqual(DustParticleType.initial_puff, DustStage.stage_1.particleEffect());
}

test "14. 4-stage dust progression: Stage 2 (50% uncovered, 48-71 ticks, heavy dust puff)" {
    try std.testing.expectEqual(DustStage.stage_2, stageFromTicks(48));
    try std.testing.expectEqual(DustStage.stage_2, stageFromTicks(60));
    try std.testing.expectEqual(DustStage.stage_2, stageFromTicks(71));
    try std.testing.expectEqual(@as(u8, 50), DustStage.stage_2.percentUncovered());
    try std.testing.expectApproxEqAbs(@as(f32, 0.50), DustStage.stage_2.exposureFraction(), 0.001);
    try std.testing.expectEqual(DustParticleType.heavy_puff, DustStage.stage_2.particleEffect());
}

test "15. 4-stage dust progression: Stage 3 (75% uncovered, 72-95 ticks, almost completely exposed)" {
    try std.testing.expectEqual(DustStage.stage_3, stageFromTicks(72));
    try std.testing.expectEqual(DustStage.stage_3, stageFromTicks(85));
    try std.testing.expectEqual(DustStage.stage_3, stageFromTicks(95));
    try std.testing.expectEqual(@as(u8, 75), DustStage.stage_3.percentUncovered());
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), DustStage.stage_3.exposureFraction(), 0.001);
    try std.testing.expectEqual(DustParticleType.continuous_plume, DustStage.stage_3.particleEffect());
}

test "16. 4-stage dust progression: Stage 4 / Complete (100% uncovered at 96 ticks / 4.8s)" {
    try std.testing.expectEqual(DustStage.stage_4_complete, stageFromTicks(96));
    try std.testing.expectEqual(DustStage.stage_4_complete, stageFromTicks(120));
    try std.testing.expectEqual(@as(u8, 100), DustStage.stage_4_complete.percentUncovered());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), DustStage.stage_4_complete.exposureFraction(), 0.001);
    try std.testing.expectEqual(DustParticleType.completion_burst, DustStage.stage_4_complete.particleEffect());
    try std.testing.expectApproxEqAbs(@as(f32, 4.8), EXCAVATION_DURATION_SECONDS, 0.001);
}

test "17. Brushing cycles: 24 cycles of 4 ticks each across 96 ticks" {
    var block = SuspiciousBlock.init(.{ 0, 60, 0 }, .suspicious_sand, .desert_pyramid, .{ .emerald = {} });
    var brush = Brush.init();

    _ = block.brushTicks(4, &brush); // 1 cycle
    try std.testing.expectEqual(@as(u8, 1), block.brushingCycle());

    _ = block.brushTicks(44, &brush); // 48 ticks total -> 12 cycles
    try std.testing.expectEqual(@as(u8, 12), block.brushingCycle());

    _ = block.brushTicks(48, &brush); // 96 ticks total -> 24 cycles
    try std.testing.expectEqual(@as(u8, 24), block.brushingCycle());
    try std.testing.expectEqual(@as(u16, 24), TOTAL_BRUSHING_CYCLES);
}

test "18. Durability consumption: completed excavation consumes exactly 1 durability point" {
    var block = SuspiciousBlock.init(.{ 0, 64, 0 }, .suspicious_sand, .warm_ocean_ruins, .{ .sniffer_egg = {} });
    var brush = Brush.init();
    try std.testing.expectEqual(@as(u16, 64), brush.durability);

    // Brush continuously for 96 ticks to completion
    const outcome = block.brushTicks(96, &brush);
    try std.testing.expect(outcome != null);
    try std.testing.expect(outcome.?.completed);
    try std.testing.expectEqual(@as(u16, 1), outcome.?.durability_consumed);
    try std.testing.expectEqual(@as(u16, 63), brush.durability);
}

test "19. Durability consumption: interrupted brushing consumes exactly 1 durability point" {
    var block = SuspiciousBlock.init(.{ 0, 64, 0 }, .suspicious_sand, .desert_well, .{ .pottery_sherd = .arms_up });
    var brush = Brush.init();

    // Brush for 30 ticks (reaching stage 1)
    _ = block.brushTicks(30, &brush);
    try std.testing.expect(block.is_brushing);
    try std.testing.expectEqual(@as(u16, 64), brush.durability);

    // Player interrupts / releases right-click
    block.interruptBrushing(&brush);
    try std.testing.expect(!block.is_brushing);
    try std.testing.expectEqual(@as(u16, 63), brush.durability);

    // Repeated interrupt calls while already not brushing do not consume further durability
    block.interruptBrushing(&brush);
    try std.testing.expectEqual(@as(u16, 63), brush.durability);
}

test "20. Broken brush (0 durability) cannot initiate or advance excavation" {
    var block = SuspiciousBlock.init(.{ 0, 60, 0 }, .suspicious_gravel, .trail_ruins, .{ .coal = {} });
    var broken_brush = Brush.initWithDurability(0);
    try std.testing.expect(broken_brush.isBroken());
    try std.testing.expect(!broken_brush.canBrush());

    const outcome = block.brushTick(&broken_brush);
    try std.testing.expectEqual(@as(?ExcavationOutcome, null), outcome);
    try std.testing.expectEqual(@as(u16, 0), block.brush_ticks);
    try std.testing.expect(!block.is_brushing);
}

test "21. Incomplete brushing decay: 1 stage decay every 40 ticks (2.0s) until stage 0" {
    var block = SuspiciousBlock.init(.{ 0, 60, 0 }, .suspicious_sand, .desert_pyramid, .{ .pottery_sherd = .miner });
    var brush = Brush.init();

    // Brush to Stage 1 (30 ticks)
    _ = block.brushTicks(30, &brush);
    try std.testing.expectEqual(DustStage.stage_1, block.currentStage());

    // Release brushing
    block.interruptBrushing(&brush);

    // Tick decay for 39 ticks (decay threshold not yet reached)
    _ = block.decayByTicks(39);
    try std.testing.expectEqual(DustStage.stage_1, block.currentStage());

    // 40th tick -> decay occurs! Stage 1 drops to Stage 0
    const decayed = block.decayByTicks(1);
    try std.testing.expectEqual(@as(u8, 1), decayed);
    try std.testing.expectEqual(DustStage.stage_0, block.currentStage());
    try std.testing.expectEqual(@as(u16, 0), block.brush_ticks);
}

test "22. Incomplete brushing decay: multi-stage decay from stage 3 to stage 0 across 120 ticks" {
    var block = SuspiciousBlock.init(.{ 0, 60, 0 }, .suspicious_gravel, .trail_ruins, .{ .armor_trim = .shaper });
    var brush = Brush.init();

    // Brush to Stage 3 (75 ticks)
    _ = block.brushTicks(75, &brush);
    try std.testing.expectEqual(DustStage.stage_3, block.currentStage());

    block.interruptBrushing(&brush);

    // 40 ticks: decays Stage 3 -> Stage 2 (48 ticks)
    try std.testing.expectEqual(@as(u8, 1), block.decayByTicks(40));
    try std.testing.expectEqual(DustStage.stage_2, block.currentStage());
    try std.testing.expectEqual(@as(u16, 48), block.brush_ticks);

    // 40 ticks: decays Stage 2 -> Stage 1 (24 ticks)
    try std.testing.expectEqual(@as(u8, 1), block.decayByTicks(40));
    try std.testing.expectEqual(DustStage.stage_1, block.currentStage());
    try std.testing.expectEqual(@as(u16, 24), block.brush_ticks);

    // 40 ticks: decays Stage 1 -> Stage 0 (0 ticks)
    try std.testing.expectEqual(@as(u8, 1), block.decayByTicks(40));
    try std.testing.expectEqual(DustStage.stage_0, block.currentStage());
    try std.testing.expectEqual(@as(u16, 0), block.brush_ticks);
}

test "23. Resuming brushing before decay completes retains remaining progress" {
    var block = SuspiciousBlock.init(.{ 0, 60, 0 }, .suspicious_sand, .desert_pyramid, .{ .pottery_sherd = .prize });
    var brush = Brush.init();

    // Brush to 72 ticks (Stage 3)
    _ = block.brushTicks(72, &brush);
    block.interruptBrushing(&brush);

    // Wait 40 ticks -> decays to Stage 2 (48 ticks)
    _ = block.decayByTicks(40);
    try std.testing.expectEqual(DustStage.stage_2, block.currentStage());
    try std.testing.expectEqual(@as(u16, 48), block.brush_ticks);

    // Player resumes brushing! Needs 48 more ticks to complete 96
    const outcome = block.brushTicks(48, &brush);
    try std.testing.expect(outcome != null);
    try std.testing.expect(outcome.?.completed);
    try std.testing.expectEqual(DustStage.stage_4_complete, block.currentStage());
    try std.testing.expectEqual(ItemType.sand, block.resultingBlock());
}

test "24. Completed excavation spawns artifact entity at block center (x+0.5, y+0.5, z+0.5) with upward pop velocity" {
    const block_pos = [3]i32{ 15, 64, -20 };
    var block = SuspiciousBlock.init(block_pos, .suspicious_sand, .warm_ocean_ruins, .{ .sniffer_egg = {} });
    var brush = Brush.init();

    const outcome = block.brushTicks(96, &brush);
    try std.testing.expect(outcome != null);
    try std.testing.expect(outcome.?.completed);
    try std.testing.expect(outcome.?.artifact != null);

    const artifact = outcome.?.artifact.?;
    try std.testing.expectEqual(ArchaeologyLoot.sniffer_egg, artifact.loot);
    try std.testing.expectApproxEqAbs(@as(f32, 15.5), artifact.position[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 64.5), artifact.position[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -19.5), artifact.position[2], 0.001);
    try std.testing.expect(artifact.velocity[1] > 0.0); // Small upward pop velocity
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), artifact.velocity[1], 0.001);
}

test "25. Completed excavation converts suspicious sand to regular sand" {
    var block = SuspiciousBlock.init(.{ 0, 30, 0 }, .suspicious_sand, .desert_pyramid, .{ .diamond = {} });
    var brush = Brush.init();

    try std.testing.expectEqual(ItemType.suspicious_sand, block.resultingBlock());
    _ = block.brushTicks(96, &brush);
    try std.testing.expect(block.is_excavated);
    try std.testing.expectEqual(ItemType.sand, block.resultingBlock());
}

test "26. Completed excavation converts suspicious gravel to regular gravel" {
    var block = SuspiciousBlock.init(.{ 10, 50, 10 }, .suspicious_gravel, .trail_ruins, .{ .armor_trim = .host });
    var brush = Brush.init();

    try std.testing.expectEqual(ItemType.suspicious_gravel, block.resultingBlock());
    _ = block.brushTicks(96, &brush);
    try std.testing.expect(block.is_excavated);
    try std.testing.expectEqual(ItemType.gravel, block.resultingBlock());
}

test "27. Archaeological loot pool: Sniffer Egg 6.7% chance in Warm Ocean Ruins" {
    // Exactly below 0.067 -> yields sniffer egg
    const egg_loot = lootForWarmOceanRuins(0.05);
    try std.testing.expectEqual(ArchaeologyLoot.sniffer_egg, egg_loot);
    try std.testing.expectEqual(ItemType.sniffer_egg, egg_loot.toItemType());
    try std.testing.expect(egg_loot.isRare());

    // At or above 0.067 -> yields other warm ocean ruins items
    const other_loot = lootForWarmOceanRuins(0.10);
    try std.testing.expect(other_loot != .sniffer_egg);
}

test "28. Archaeological loot pool: Trail Ruins armor trim smithing templates (Wayfinder, Raiser, Shaper, Host)" {
    const wayfinder = lootForTrailRuins(0.02);
    try std.testing.expect(wayfinder == .armor_trim);
    try std.testing.expectEqual(ArmorTrim.wayfinder, wayfinder.armor_trim);
    try std.testing.expectEqual(ItemType.wayfinder_armor_trim, wayfinder.toItemType());
    try std.testing.expect(wayfinder.isRare());

    const raiser = lootForTrailRuins(0.07);
    try std.testing.expect(raiser == .armor_trim);
    try std.testing.expectEqual(ArmorTrim.raiser, raiser.armor_trim);

    const shaper = lootForTrailRuins(0.13);
    try std.testing.expect(shaper == .armor_trim);
    try std.testing.expectEqual(ArmorTrim.shaper, shaper.armor_trim);

    const host = lootForTrailRuins(0.18);
    try std.testing.expect(host == .armor_trim);
    try std.testing.expectEqual(ArmorTrim.host, host.armor_trim);
}

test "29. Archaeological loot pool: Pottery Sherds across structures (Angler, Archer, Arms Up, Blade, etc.)" {
    // Warm ocean ruins sherd
    const warm_sherd = lootForWarmOceanRuins(0.10);
    try std.testing.expect(warm_sherd.isSherd());

    // Desert pyramid sherd
    const archer_loot = lootForDesertPyramid(0.05);
    try std.testing.expect(archer_loot.isSherd());
    try std.testing.expectEqual(PotterySherd.archer, archer_loot.pottery_sherd);

    // Desert well sherd
    const arms_up_loot = lootForDesertWell(0.1);
    try std.testing.expect(arms_up_loot.isSherd());
    try std.testing.expectEqual(PotterySherd.arms_up, arms_up_loot.pottery_sherd);

    // Cold ocean ruins sherd
    const blade_loot = lootForColdOceanRuins(0.05);
    try std.testing.expect(blade_loot.isSherd());
    try std.testing.expectEqual(PotterySherd.blade, blade_loot.pottery_sherd);
}

test "30. Archaeological loot pool: common finds (Emerald, Wheat, Coal)" {
    const emerald_loot = ArchaeologyLoot{ .emerald = {} };
    try std.testing.expectEqual(ItemType.emerald, emerald_loot.toItemType());
    try std.testing.expectEqualStrings("Emerald", emerald_loot.name());
    try std.testing.expect(!emerald_loot.isRare());

    const wheat_loot = ArchaeologyLoot{ .wheat = {} };
    try std.testing.expectEqual(ItemType.wheat, wheat_loot.toItemType());
    try std.testing.expectEqualStrings("Wheat", wheat_loot.name());

    const coal_loot = ArchaeologyLoot{ .coal = {} };
    try std.testing.expectEqual(ItemType.coal, coal_loot.toItemType());
    try std.testing.expectEqualStrings("Coal", coal_loot.name());
}

test "31. Player reach constraint: brushing beyond 4.5 blocks fails or pauses" {
    var block = SuspiciousBlock.init(.{ 0, 60, 0 }, .suspicious_sand, .desert_pyramid, .{ .coal = {} });
    var brush = Brush.init();

    // Player nearby: distance 2.0 blocks (within reach 4.5)
    const outcome_near = block.brushWithReach(&brush, .{ 0.5, 60.5, 2.0 }, MAX_INTERACTION_DISTANCE);
    try std.testing.expect(outcome_near != null);
    try std.testing.expectEqual(@as(u16, 1), block.brush_ticks);

    // Player far away: distance 10.0 blocks (out of reach)
    const outcome_far = block.brushWithReach(&brush, .{ 0.5, 60.5, 10.0 }, MAX_INTERACTION_DISTANCE);
    try std.testing.expectEqual(@as(?ExcavationOutcome, null), outcome_far);
    try std.testing.expect(!block.is_brushing);
    try std.testing.expectEqual(@as(u16, 63), brush.durability); // Interrupted consumed 1 durability
}

test "32. Full simulated archaeology excavation workflow end-to-end" {
    // 1. Craft Brush
    const brush_craft = craftBrushVertical(.feather, .copper_ingot, .stick);
    try std.testing.expect(brush_craft != null);
    var brush = Brush.initWithDurability(brush_craft.?.durability);

    // 2. Discover suspicious block in Trail Ruins
    var block = SuspiciousBlock.init(.{ 100, 48, -50 }, .suspicious_gravel, .trail_ruins, .{ .armor_trim = .wayfinder });
    try std.testing.expectEqual(DustStage.stage_0, block.currentStage());

    // 3. Right click & hold brush for 96 ticks through update loop
    var t: u16 = 0;
    while (t < 96) : (t += 1) {
        const out = block.update(true, &brush);
        if (t == 95) {
            try std.testing.expect(out != null);
            try std.testing.expect(out.?.completed);
            try std.testing.expect(out.?.artifact != null);
            try std.testing.expectEqual(ItemType.wayfinder_armor_trim, out.?.artifact.?.loot.toItemType());
        }
    }

    // 4. Verify post-excavation state
    try std.testing.expect(block.is_excavated);
    try std.testing.expectEqual(ItemType.gravel, block.resultingBlock());
    try std.testing.expectEqual(@as(u16, 63), brush.durability);
}
