const std = @import("std");

// ============================================================================
// Unified Archaeology, Brush Excavation, and Brushing Visual Particles
// ============================================================================

pub const brushes_to_excavate: u8 = 3;

pub const PotterySherdTag: u16 = 369;
pub const EmeraldTag: u16 = 273;
pub const GoldNuggetTag: u16 = 81;
pub const DiamondTag: u16 = 217;
pub const CoalTag: u16 = 12;

/// Game ticks and timing constants for archaeological excavation.
pub const TICKS_PER_SECOND: u32 = 20;
pub const TOTAL_EXCAVATION_TICKS: u16 = 96; // 4.8 seconds * 20 ticks/sec
pub const BRUSHING_CYCLE_TICKS: u16 = 4; // Each brushing cycle is 4 game ticks
pub const TOTAL_BRUSHING_CYCLES: u16 = 24; // 96 / 4 = 24 brushing cycles
pub const TICKS_PER_STAGE: u16 = 24; // 4 dust stages, 24 ticks each
pub const EXCAVATION_TICKS_PER_STAGE: u16 = 24;
pub const EXCAVATION_DURATION_SECONDS: f32 = 4.8;
pub const DECAY_TICKS_PER_STAGE: u16 = 40; // 2.0 seconds * 20 ticks/sec
pub const DECAY_INTERVAL_SECONDS: f32 = 2.0;
pub const MAX_INTERACTION_DISTANCE: f32 = 4.5; // Max block reach for brushing
pub const SNIFFER_EGG_PROBABILITY: f32 = 0.067; // 6.7% in warm ocean ruins

pub const MAX_PARTICLES: usize = 32;
pub const INTERRUPTION_DECAY_PER_TICK: f32 = 0.25;
pub const PARTICLE_FADE_PER_TICK: f32 = 0.12;

pub fn relicForRoll(roll: u8) u16 {
    return switch (roll % 5) {
        0, 1 => PotterySherdTag,
        2 => EmeraldTag,
        3 => GoldNuggetTag,
        else => DiamondTag,
    };
}

pub fn toggleCopperBulb(is_lit: bool) bool {
    return !is_lit;
}

pub fn copperBulbComparatorSignal(is_lit: bool) u8 {
    if (is_lit) return 15;
    return 0;
}

/// Item identifiers mirroring the local archaeology vocabulary.
/// For mapping loot directly to `src/items.zig` ItemType values, use `lootInventoryTag`.
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

/// Maps an ArchaeologyLoot result to the global `src/items.zig` ItemType integer ID.
pub fn lootInventoryTag(loot: ArchaeologyLoot) u16 {
    return switch (loot) {
        .pottery_sherd => 369, // .pottery_sherd
        .sniffer_egg => 492, // .sniffer_egg
        .armor_trim => 395, // .armor_trim_template
        .emerald => 273, // .emerald
        .wheat => 267, // .wheat
        .coal => 12, // .coal
        .diamond => 217, // .diamond
        .gold_nugget => 81, // .gold_nugget
        .iron_axe => 229, // .iron_axe
        .wooden_hoe => 236, // .wooden_hoe
        .music_disc_relic => 427, // .music_disc_relic
    };
}

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
            .velocity = .{ 0.0, 0.2, 0.0 },
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
// Visual Brushing Stages & Deterministic Particle Bursts
// ============================================================================

pub const ExcavationStage = enum(u8) {
    idle = 0,
    stage_1 = 1,
    stage_2 = 2,
    stage_3 = 3,
    stage_4 = 4,

    pub fn progressPercent(self: ExcavationStage) u8 {
        return @as(u8, @intFromEnum(self)) * 25;
    }

    pub fn pitch(self: ExcavationStage) f32 {
        return switch (self) {
            .idle => 0.0,
            .stage_1 => 0.8,
            .stage_2 => 1.0,
            .stage_3 => 1.2,
            .stage_4 => 1.4,
        };
    }

    pub fn particleCountRange(self: ExcavationStage) [2]u8 {
        return switch (self) {
            .idle => .{ 0, 0 },
            .stage_1 => .{ 4, 6 },
            .stage_2 => .{ 8, 12 },
            .stage_3 => .{ 16, 24 },
            .stage_4 => .{ 32, 32 },
        };
    }
};

pub fn stageFromProgress(progress_ticks: f32) ExcavationStage {
    if (progress_ticks >= @as(f32, TOTAL_EXCAVATION_TICKS)) return .stage_4;
    if (progress_ticks >= 72.0) return .stage_3;
    if (progress_ticks >= 48.0) return .stage_2;
    if (progress_ticks >= 24.0) return .stage_1;
    return .idle;
}

pub const ParticleType = enum(u8) {
    dust_plume,
    medium_dust_cloud,
    heavy_particulate,
    relic_sparkle,
};

pub const Particle = struct {
    particle_type: ParticleType,
    position: [3]f32,
    velocity: [3]f32,
    lifetime_ticks: u8,
    age_ticks: u8 = 0,
    alpha: f32 = 1.0,
    scale: f32,
    shows_item_edge: bool = false,
    golden: bool = false,

    pub fn isAlive(self: Particle) bool {
        return self.age_ticks < self.lifetime_ticks and self.alpha > 0.0;
    }
};

pub const ParticleBurst = struct {
    particles: [MAX_PARTICLES]Particle = undefined,
    count: u8 = 0,

    pub fn slice(self: *const ParticleBurst) []const Particle {
        return self.particles[0..self.count];
    }
};

fn mixSeed(seed: u32) u32 {
    var value = seed;
    value ^= value >> 16;
    value *%= 0x7feb352d;
    value ^= value >> 15;
    value *%= 0x846ca68b;
    value ^= value >> 16;
    return value;
}

fn randomUnit(seed: u32) f32 {
    return @as(f32, @floatFromInt(mixSeed(seed) & 0x00ffffff)) / 16777215.0;
}

/// Builds a deterministic burst so the simulation and tests do not need a global RNG.
pub fn makeBurst(stage: ExcavationStage, origin: [3]f32, seed: u32) ParticleBurst {
    var result = ParticleBurst{};
    if (stage == .idle) return result;

    const range = stage.particleCountRange();
    const count: usize = @as(usize, range[0]) + @as(usize, mixSeed(seed) % (@as(u32, range[1] - range[0]) + 1));
    result.count = @intCast(count);
    for (0..count) |index| {
        const i: u32 = @intCast(index);
        const theta = randomUnit(seed +% i *% 3) * 6.2831855;
        const outward = 0.025 + randomUnit(seed +% i *% 3 +% 1) * 0.09;
        const upward_scale: f32 = switch (stage) {
            .idle => 0.0,
            .stage_1 => 0.055,
            .stage_2 => 0.09,
            .stage_3 => 0.13,
            .stage_4 => 0.17,
        };
        const upward = 0.025 + randomUnit(seed +% i *% 3 +% 2) * upward_scale;
        const golden = stage == .stage_4 and index % 4 == 0;
        result.particles[index] = .{
            .particle_type = if (golden) .relic_sparkle else switch (stage) {
                .idle => unreachable,
                .stage_1 => .dust_plume,
                .stage_2 => .medium_dust_cloud,
                .stage_3, .stage_4 => .heavy_particulate,
            },
            .position = origin,
            .velocity = .{ @cos(theta) * outward, upward, @sin(theta) * outward },
            .lifetime_ticks = switch (stage) {
                .idle => 1,
                .stage_1 => 18,
                .stage_2 => 28,
                .stage_3 => 36,
                .stage_4 => 44,
            },
            .scale = switch (stage) {
                .idle => 0.0,
                .stage_1 => 0.35 + randomUnit(seed +% i +% 11) * 0.25,
                .stage_2 => 0.65 + randomUnit(seed +% i +% 11) * 0.45,
                .stage_3 => 0.8 + randomUnit(seed +% i +% 11) * 0.7,
                .stage_4 => if (golden) 0.3 else 1.0 + randomUnit(seed +% i +% 11) * 0.9,
            },
            .shows_item_edge = stage == .stage_3 or stage == .stage_4,
            .golden = golden,
        };
    }
    return result;
}

pub const Hand = enum(u1) { main, off };
pub const HeldItem = enum { empty, brush, other };

pub const Hands = struct {
    main: HeldItem = .empty,
    off: HeldItem = .empty,

    pub fn brushHand(self: Hands) ?Hand {
        if (self.main == .brush) return .main;
        if (self.off == .brush) return .off;
        return null;
    }

    pub fn isSynchronized(self: Hands) bool {
        return self.main == .brush and self.off == .brush;
    }
};

pub const AudioEvent = struct {
    brushing_pitch: f32 = 0.0,
    play_brush_loop: bool = false,
    play_completion_chime: bool = false,
};

pub const TickResult = struct {
    stage: ExcavationStage,
    brush_hand: ?Hand,
    synchronized: bool,
    audio: AudioEvent,
    emitted_burst: ?ParticleBurst = null,
};

/// Progress and interruption state for one suspicious block's visual presentation.
pub const BrushingVisualState = struct {
    progress_ticks: f32 = 0.0,
    previous_stage: ExcavationStage = .idle,
    plume_alpha: f32 = 0.0,
    completion_chime_played: bool = false,
    burst_serial: u32 = 0,

    pub fn stage(self: BrushingVisualState) ExcavationStage {
        return stageFromProgress(self.progress_ticks);
    }

    pub fn tick(self: *BrushingVisualState, hands: Hands, origin: [3]f32) TickResult {
        const hand = hands.brushHand();
        const old_stage = self.stage();
        if (hand != null) {
            self.progress_ticks = @min(self.progress_ticks + 1.0, @as(f32, TOTAL_EXCAVATION_TICKS));
            self.plume_alpha = @min(self.plume_alpha + 0.25, 1.0);
        } else {
            self.progress_ticks = @max(self.progress_ticks - INTERRUPTION_DECAY_PER_TICK, 0.0);
            self.plume_alpha = @max(self.plume_alpha - PARTICLE_FADE_PER_TICK, 0.0);
        }

        const current_stage = self.stage();
        const completed_now = old_stage != .stage_4 and current_stage == .stage_4;
        const stage_changed = current_stage != self.previous_stage;
        var result = TickResult{
            .stage = current_stage,
            .brush_hand = hand,
            .synchronized = hands.isSynchronized(),
            .audio = .{
                .brushing_pitch = current_stage.pitch(),
                .play_brush_loop = hand != null and current_stage != .idle and current_stage != .stage_4,
                .play_completion_chime = completed_now and !self.completion_chime_played,
            },
        };
        if (stage_changed and current_stage != .idle) {
            self.burst_serial +%= 1;
            result.emitted_burst = makeBurst(current_stage, origin, self.burst_serial);
        }
        if (completed_now) self.completion_chime_played = true;
        if (current_stage != .stage_4) self.completion_chime_played = false;
        self.previous_stage = current_stage;
        return result;
    }

    pub fn particleAlpha(self: BrushingVisualState, particle: Particle) f32 {
        return @max(particle.alpha * self.plume_alpha, 0.0);
    }
};

// ============================================================================
// Live Gameplay Excavation Session Bridge
// ============================================================================

/// Selects a structure pool deterministically from world coordinates / seed.
pub fn structureForSeed(seed: u32) StructureType {
    return switch (seed % 5) {
        0 => .warm_ocean_ruins,
        1 => .desert_pyramid,
        2 => .desert_well,
        3 => .trail_ruins,
        else => .cold_ocean_ruins,
    };
}

/// Manages active suspicious block excavation across frames in live gameplay.
pub const ActiveExcavation = struct {
    active: bool = false,
    target_pos: [3]i32 = .{ 0, 0, 0 },
    block: SuspiciousBlock = SuspiciousBlock.init(.{ 0, 0, 0 }, .suspicious_sand, .warm_ocean_ruins, .{ .emerald = {} }),
    visual: BrushingVisualState = .{},
    tick_accum: f32 = 0.0,
    last_cycle: u8 = 0,

    pub const StepResult = struct {
        stage: ExcavationStage = .idle,
        stage_changed: bool = false,
        emitted_burst: ?ParticleBurst = null,
        play_brush_cycle_sound: bool = false,
        brush_pitch: f32 = 0.8,
        durability_consumed: u16 = 0,
        completed: bool = false,
        completed_pos: [3]i32 = .{ 0, 0, 0 },
        loot: ?ArchaeologyLoot = null,
        extracted_item_tag: u16 = 0,
        play_completion_chime: bool = false,
    };

    /// Resets the active excavation session back to idle.
    pub fn reset(self: *ActiveExcavation) void {
        self.active = false;
        self.visual = .{};
        self.tick_accum = 0.0;
        self.last_cycle = 0;
    }

    fn beginAt(self: *ActiveExcavation, pos: [3]i32, seed: u32) void {
        const structure = structureForSeed(seed);
        const roll = randomUnit(seed ^ 0x9e3779b9);
        const loot = lootForStructure(structure, roll);
        self.active = true;
        self.target_pos = pos;
        self.block = SuspiciousBlock.init(pos, .suspicious_sand, structure, loot);
        self.visual = .{};
        self.tick_accum = 0.0;
        self.last_cycle = 0;
    }

    fn applySingleTick(self: *ActiveExcavation, brushing_now: bool, player_pos: [3]f32, brush: *Brush, out: *StepResult) void {
        const center = [3]f32{
            @as(f32, @floatFromInt(self.target_pos[0])) + 0.5,
            @as(f32, @floatFromInt(self.target_pos[1])) + 0.5,
            @as(f32, @floatFromInt(self.target_pos[2])) + 0.5,
        };
        const before_dur = brush.durability;
        const prev_stage = self.visual.stage();

        if (brushing_now) {
            const outcome_opt = self.block.brushWithReach(brush, player_pos, MAX_INTERACTION_DISTANCE);
            if (outcome_opt) |outcome| {
                const vis_res = self.visual.tick(.{ .main = .brush }, center);
                out.stage = vis_res.stage;
                if (vis_res.stage != prev_stage) out.stage_changed = true;
                if (vis_res.emitted_burst) |burst| out.emitted_burst = burst;
                if (outcome.brushing_cycle != self.last_cycle) {
                    self.last_cycle = outcome.brushing_cycle;
                    out.play_brush_cycle_sound = true;
                    out.brush_pitch = @max(vis_res.audio.brushing_pitch, 0.8);
                }
                if (vis_res.audio.play_completion_chime) out.play_completion_chime = true;
                if (outcome.completed) {
                    out.completed = true;
                    out.completed_pos = self.target_pos;
                    out.loot = self.block.buried_loot;
                    out.extracted_item_tag = lootInventoryTag(self.block.buried_loot);
                    out.play_completion_chime = true;
                    if (out.emitted_burst == null) {
                        out.emitted_burst = makeBurst(.stage_4, center, self.visual.burst_serial +% 1);
                    }
                    self.reset();
                }
            } else {
                const vis_res = self.visual.tick(.{}, center);
                out.stage = vis_res.stage;
                _ = self.block.tickDecay();
            }
        } else {
            if (self.block.is_brushing) {
                self.block.interruptBrushing(brush);
            }
            const vis_res = self.visual.tick(.{}, center);
            out.stage = vis_res.stage;
            if (vis_res.stage != prev_stage) out.stage_changed = true;
            _ = self.block.tickDecay();
            if (self.block.brush_ticks == 0 and vis_res.stage == .idle) {
                self.reset();
            }
        }

        if (before_dur > brush.durability) {
            out.durability_consumed += (before_dur - brush.durability);
        }
    }

    /// Advances excavation at 20 Hz while holding right-click with a brush, or decays when released.
    pub fn stepFrame(
        self: *ActiveExcavation,
        dt: f32,
        holding_brush: bool,
        aiming_suspicious: bool,
        hit_pos: [3]i32,
        player_pos: [3]f32,
        remaining_durability: u16,
        seed: u32,
    ) StepResult {
        var out = StepResult{};
        const same_target = self.active and self.target_pos[0] == hit_pos[0] and self.target_pos[1] == hit_pos[1] and self.target_pos[2] == hit_pos[2];
        const brushing_now = holding_brush and aiming_suspicious and remaining_durability > 0;

        if (brushing_now and !same_target) {
            if (self.active and self.block.is_brushing) {
                var prev_brush = Brush.initWithDurability(remaining_durability);
                self.block.interruptBrushing(&prev_brush);
                if (remaining_durability > prev_brush.durability) {
                    out.durability_consumed += (remaining_durability - prev_brush.durability);
                }
            }
            self.beginAt(hit_pos, seed);
        }

        if (!self.active) return out;

        const tick_interval: f32 = 1.0 / @as(f32, @floatFromInt(TICKS_PER_SECOND));
        self.tick_accum += @min(dt, 0.25);
        var brush = Brush.initWithDurability(if (remaining_durability > out.durability_consumed) remaining_durability - out.durability_consumed else 0);

        while (self.active and self.tick_accum >= tick_interval) {
            self.tick_accum -= tick_interval;
            self.applySingleTick(brushing_now, player_pos, &brush, &out);
            if (out.completed) break;
        }
        return out;
    }

    /// Advances excavation by one full dust stage (24 ticks) for discrete interaction (e.g. F key).
    pub fn advanceStageStep(
        self: *ActiveExcavation,
        pos: [3]i32,
        player_pos: [3]f32,
        remaining_durability: u16,
        seed: u32,
    ) StepResult {
        var out = StepResult{};
        if (remaining_durability == 0) return out;

        const same_target = self.active and self.target_pos[0] == pos[0] and self.target_pos[1] == pos[1] and self.target_pos[2] == pos[2];
        if (!same_target) {
            self.beginAt(pos, seed);
        }

        var brush = Brush.initWithDurability(remaining_durability);
        var i: u16 = 0;
        while (self.active and i < EXCAVATION_TICKS_PER_STAGE) : (i += 1) {
            self.applySingleTick(true, player_pos, &brush, &out);
            if (out.completed) break;
        }
        return out;
    }
};

// ============================================================================
// Unit Tests (Original + Excavation + Visual Particles + Session Bridge)
// ============================================================================

test "constants" {
    try std.testing.expectEqual(@as(u8, 3), brushes_to_excavate);
    try std.testing.expectEqual(@as(u16, 369), PotterySherdTag);
    try std.testing.expectEqual(@as(u16, 273), EmeraldTag);
    try std.testing.expectEqual(@as(u16, 81), GoldNuggetTag);
    try std.testing.expectEqual(@as(u16, 217), DiamondTag);
    try std.testing.expectEqual(@as(u16, 12), CoalTag);
}

test "relicForRoll maps each residue class" {
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(0));
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(1));
    try std.testing.expectEqual(EmeraldTag, relicForRoll(2));
    try std.testing.expectEqual(GoldNuggetTag, relicForRoll(3));
    try std.testing.expectEqual(DiamondTag, relicForRoll(4));
}

test "relicForRoll wraps with modulo five" {
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(5));
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(6));
    try std.testing.expectEqual(EmeraldTag, relicForRoll(7));
    try std.testing.expectEqual(GoldNuggetTag, relicForRoll(8));
    try std.testing.expectEqual(DiamondTag, relicForRoll(9));
    try std.testing.expectEqual(PotterySherdTag, relicForRoll(255));
}

test "toggleCopperBulb" {
    try std.testing.expect(toggleCopperBulb(false));
    try std.testing.expect(!toggleCopperBulb(true));
}

test "copperBulbComparatorSignal" {
    try std.testing.expectEqual(@as(u8, 15), copperBulbComparatorSignal(true));
    try std.testing.expectEqual(@as(u8, 0), copperBulbComparatorSignal(false));
}

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
    var grid0 = [_]?ItemType{null} ** 9;
    grid0[0] = .feather;
    grid0[3] = .copper_ingot;
    grid0[6] = .stick;
    const res0 = craftBrush3x3(grid0);
    try std.testing.expect(res0 != null);
    try std.testing.expectEqual(ItemType.brush, res0.?.item);

    var grid1 = [_]?ItemType{null} ** 9;
    grid1[1] = .feather;
    grid1[4] = .copper_ingot;
    grid1[7] = .stick;
    const res1 = craftBrush3x3(grid1);
    try std.testing.expect(res1 != null);
    try std.testing.expectEqual(ItemType.brush, res1.?.item);

    var grid2 = [_]?ItemType{null} ** 9;
    grid2[2] = .feather;
    grid2[5] = .copper_ingot;
    grid2[8] = .stick;
    const res2 = craftBrush3x3(grid2);
    try std.testing.expect(res2 != null);
    try std.testing.expectEqual(ItemType.brush, res2.?.item);
}

test "4. Brush crafting rejects invalid recipes, wrong ingredients, or horizontal alignment" {
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrushVertical(.stick, .copper_ingot, .feather));
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrushVertical(.copper_ingot, .feather, .stick));
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrushVertical(.wheat, .copper_ingot, .stick));
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrushVertical(.feather, .diamond, .stick));

    var horiz_grid = [_]?ItemType{null} ** 9;
    horiz_grid[0] = .feather;
    horiz_grid[1] = .copper_ingot;
    horiz_grid[2] = .stick;
    try std.testing.expectEqual(@as(?ItemStack, null), craftBrush3x3(horiz_grid));

    var polluted_grid = [_]?ItemType{null} ** 9;
    polluted_grid[0] = .feather;
    polluted_grid[3] = .copper_ingot;
    polluted_grid[6] = .stick;
    polluted_grid[1] = .sand;
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
    const mining = block.mine(null);
    try std.testing.expectEqual(ItemType.sand, mining.dropped_item);
    try std.testing.expectEqual(@as(u8, 1), mining.count);
    try std.testing.expect(mining.artifact_destroyed);
    try std.testing.expect(mining.block_destroyed);
    try std.testing.expect(block.is_destroyed);
}

test "11. Direct mining suspicious gravel drops regular gravel and destroys artifact" {
    var block = SuspiciousBlock.init(.{ -12, 45, 100 }, .suspicious_gravel, .cold_ocean_ruins, .{ .pottery_sherd = .blade });
    const mining = block.mine(.iron_axe);
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

    _ = block.brushTicks(4, &brush);
    try std.testing.expectEqual(@as(u8, 1), block.brushingCycle());

    _ = block.brushTicks(44, &brush);
    try std.testing.expectEqual(@as(u8, 12), block.brushingCycle());

    _ = block.brushTicks(48, &brush);
    try std.testing.expectEqual(@as(u8, 24), block.brushingCycle());
    try std.testing.expectEqual(@as(u16, 24), TOTAL_BRUSHING_CYCLES);
}

test "18. Durability consumption: completed excavation consumes exactly 1 durability point" {
    var block = SuspiciousBlock.init(.{ 0, 64, 0 }, .suspicious_sand, .warm_ocean_ruins, .{ .sniffer_egg = {} });
    var brush = Brush.init();
    try std.testing.expectEqual(@as(u16, 64), brush.durability);

    const outcome = block.brushTicks(96, &brush);
    try std.testing.expect(outcome != null);
    try std.testing.expect(outcome.?.completed);
    try std.testing.expectEqual(@as(u16, 1), outcome.?.durability_consumed);
    try std.testing.expectEqual(@as(u16, 63), brush.durability);
}

test "19. Durability consumption: interrupted brushing consumes exactly 1 durability point" {
    var block = SuspiciousBlock.init(.{ 0, 64, 0 }, .suspicious_sand, .desert_well, .{ .pottery_sherd = .arms_up });
    var brush = Brush.init();

    _ = block.brushTicks(30, &brush);
    try std.testing.expect(block.is_brushing);
    try std.testing.expectEqual(@as(u16, 64), brush.durability);

    block.interruptBrushing(&brush);
    try std.testing.expect(!block.is_brushing);
    try std.testing.expectEqual(@as(u16, 63), brush.durability);

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

    _ = block.brushTicks(30, &brush);
    try std.testing.expectEqual(DustStage.stage_1, block.currentStage());

    block.interruptBrushing(&brush);

    _ = block.decayByTicks(39);
    try std.testing.expectEqual(DustStage.stage_1, block.currentStage());

    const decayed = block.decayByTicks(1);
    try std.testing.expectEqual(@as(u8, 1), decayed);
    try std.testing.expectEqual(DustStage.stage_0, block.currentStage());
    try std.testing.expectEqual(@as(u16, 0), block.brush_ticks);
}

test "22. Incomplete brushing decay: multi-stage decay from stage 3 to stage 0 across 120 ticks" {
    var block = SuspiciousBlock.init(.{ 0, 60, 0 }, .suspicious_gravel, .trail_ruins, .{ .armor_trim = .shaper });
    var brush = Brush.init();

    _ = block.brushTicks(75, &brush);
    try std.testing.expectEqual(DustStage.stage_3, block.currentStage());

    block.interruptBrushing(&brush);

    try std.testing.expectEqual(@as(u8, 1), block.decayByTicks(40));
    try std.testing.expectEqual(DustStage.stage_2, block.currentStage());
    try std.testing.expectEqual(@as(u16, 48), block.brush_ticks);

    try std.testing.expectEqual(@as(u8, 1), block.decayByTicks(40));
    try std.testing.expectEqual(DustStage.stage_1, block.currentStage());
    try std.testing.expectEqual(@as(u16, 24), block.brush_ticks);

    try std.testing.expectEqual(@as(u8, 1), block.decayByTicks(40));
    try std.testing.expectEqual(DustStage.stage_0, block.currentStage());
    try std.testing.expectEqual(@as(u16, 0), block.brush_ticks);
}

test "23. Resuming brushing before decay completes retains remaining progress" {
    var block = SuspiciousBlock.init(.{ 0, 60, 0 }, .suspicious_sand, .desert_pyramid, .{ .pottery_sherd = .prize });
    var brush = Brush.init();

    _ = block.brushTicks(72, &brush);
    block.interruptBrushing(&brush);

    _ = block.decayByTicks(40);
    try std.testing.expectEqual(DustStage.stage_2, block.currentStage());
    try std.testing.expectEqual(@as(u16, 48), block.brush_ticks);

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
    try std.testing.expect(artifact.velocity[1] > 0.0);
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
    const egg_loot = lootForWarmOceanRuins(0.05);
    try std.testing.expectEqual(ArchaeologyLoot.sniffer_egg, egg_loot);
    try std.testing.expectEqual(ItemType.sniffer_egg, egg_loot.toItemType());
    try std.testing.expect(egg_loot.isRare());

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
    const warm_sherd = lootForWarmOceanRuins(0.10);
    try std.testing.expect(warm_sherd.isSherd());

    const archer_loot = lootForDesertPyramid(0.05);
    try std.testing.expect(archer_loot.isSherd());
    try std.testing.expectEqual(PotterySherd.archer, archer_loot.pottery_sherd);

    const arms_up_loot = lootForDesertWell(0.1);
    try std.testing.expect(arms_up_loot.isSherd());
    try std.testing.expectEqual(PotterySherd.arms_up, arms_up_loot.pottery_sherd);

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

    const outcome_near = block.brushWithReach(&brush, .{ 0.5, 60.5, 2.0 }, MAX_INTERACTION_DISTANCE);
    try std.testing.expect(outcome_near != null);
    try std.testing.expectEqual(@as(u16, 1), block.brush_ticks);

    const outcome_far = block.brushWithReach(&brush, .{ 0.5, 60.5, 10.0 }, MAX_INTERACTION_DISTANCE);
    try std.testing.expectEqual(@as(?ExcavationOutcome, null), outcome_far);
    try std.testing.expect(!block.is_brushing);
    try std.testing.expectEqual(@as(u16, 63), brush.durability);
}

test "32. Full simulated archaeology excavation workflow end-to-end" {
    const brush_craft = craftBrushVertical(.feather, .copper_ingot, .stick);
    try std.testing.expect(brush_craft != null);
    var brush = Brush.initWithDurability(brush_craft.?.durability);

    var block = SuspiciousBlock.init(.{ 100, 48, -50 }, .suspicious_gravel, .trail_ruins, .{ .armor_trim = .wayfinder });
    try std.testing.expectEqual(DustStage.stage_0, block.currentStage());

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

    try std.testing.expect(block.is_excavated);
    try std.testing.expectEqual(ItemType.gravel, block.resultingBlock());
    try std.testing.expectEqual(@as(u16, 63), brush.durability);
}

test "stage 1 emits 4 to 6 light dust puffs" {
    const burst = makeBurst(.stage_1, .{ 0, 0, 0 }, 12);
    try std.testing.expect(burst.count >= 4 and burst.count <= 6);
    for (burst.slice()) |particle| try std.testing.expectEqual(ParticleType.dust_plume, particle.particle_type);
}

test "stage 2 emits 8 to 12 medium clouds" {
    const burst = makeBurst(.stage_2, .{ 0, 0, 0 }, 4);
    try std.testing.expect(burst.count >= 8 and burst.count <= 12);
    for (burst.slice()) |particle| try std.testing.expectEqual(ParticleType.medium_dust_cloud, particle.particle_type);
}

test "stage 3 emits 16 to 24 heavy particles" {
    const burst = makeBurst(.stage_3, .{ 0, 0, 0 }, 9);
    try std.testing.expect(burst.count >= 16 and burst.count <= 24);
    for (burst.slice()) |particle| try std.testing.expectEqual(ParticleType.heavy_particulate, particle.particle_type);
}

test "stage 4 emits a dense 32 particle burst" {
    try std.testing.expectEqual(@as(u8, 32), makeBurst(.stage_4, .{ 0, 0, 0 }, 2).count);
}

test "stage 1 particles are dust plumes" {
    try std.testing.expectEqual(ParticleType.dust_plume, makeBurst(.stage_1, .{ 0, 0, 0 }, 1).particles[0].particle_type);
}

test "stage 2 particles are medium dust clouds" {
    try std.testing.expectEqual(ParticleType.medium_dust_cloud, makeBurst(.stage_2, .{ 0, 0, 0 }, 1).particles[0].particle_type);
}

test "stage 3 particles expose item edges" {
    for (makeBurst(.stage_3, .{ 0, 0, 0 }, 1).slice()) |particle| try std.testing.expect(particle.shows_item_edge);
}

test "stage 4 particles expose item edges" {
    for (makeBurst(.stage_4, .{ 0, 0, 0 }, 1).slice()) |particle| try std.testing.expect(particle.shows_item_edge);
}

test "stage 4 includes golden relic sparkles" {
    var golden_count: usize = 0;
    for (makeBurst(.stage_4, .{ 0, 0, 0 }, 1).slice()) |particle| {
        if (particle.golden) {
            golden_count += 1;
            try std.testing.expectEqual(ParticleType.relic_sparkle, particle.particle_type);
        }
    }
    try std.testing.expect(golden_count >= 8);
}

test "stage 4 sparkles use golden particle color flag" {
    const burst = makeBurst(.stage_4, .{ 0, 0, 0 }, 5);
    try std.testing.expect(burst.particles[0].golden);
}

test "idle stage emits no particles" {
    try std.testing.expectEqual(@as(u8, 0), makeBurst(.idle, .{ 0, 0, 0 }, 0).count);
}

test "progress maps to idle before first quarter" {
    try std.testing.expectEqual(ExcavationStage.idle, stageFromProgress(23.99));
}

test "progress maps to stage 1 at quarter" {
    try std.testing.expectEqual(ExcavationStage.stage_1, stageFromProgress(24));
}

test "progress maps to stage 2 at half" {
    try std.testing.expectEqual(ExcavationStage.stage_2, stageFromProgress(48));
}

test "progress maps to stage 3 at three quarters" {
    try std.testing.expectEqual(ExcavationStage.stage_3, stageFromProgress(72));
}

test "progress maps to stage 4 at completion" {
    try std.testing.expectEqual(ExcavationStage.stage_4, stageFromProgress(96));
}

test "stage 1 brushing pitch is 0.8" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), ExcavationStage.stage_1.pitch(), 0.001);
}

test "stage 2 brushing pitch is 1.0" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), ExcavationStage.stage_2.pitch(), 0.001);
}

test "stage 3 brushing pitch is 1.2" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), ExcavationStage.stage_3.pitch(), 0.001);
}

test "stage 4 brushing pitch is 1.4" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.4), ExcavationStage.stage_4.pitch(), 0.001);
}

test "main hand brush is accepted" {
    try std.testing.expectEqual(Hand.main, (Hands{ .main = .brush }).brushHand().?);
}

test "off hand brush is accepted" {
    try std.testing.expectEqual(Hand.off, (Hands{ .off = .brush }).brushHand().?);
}

test "non-brush hands do not activate brushing" {
    try std.testing.expectEqual(@as(?Hand, null), (Hands{ .main = .other, .off = .empty }).brushHand());
}

test "main hand is selected when both hands hold brushes" {
    try std.testing.expectEqual(Hand.main, (Hands{ .main = .brush, .off = .brush }).brushHand().?);
}

test "dual brush use reports synchronized brushing" {
    var state = BrushingVisualState{};
    const result = state.tick(.{ .main = .brush, .off = .brush }, .{ 0, 0, 0 });
    try std.testing.expect(result.synchronized);
}

test "release regresses excavation progress smoothly" {
    var state = BrushingVisualState{ .progress_ticks = 48.0 };
    _ = state.tick(.{}, .{ 0, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 47.75), state.progress_ticks, 0.001);
}

test "interruption takes four ticks to regress one excavation tick" {
    var state = BrushingVisualState{ .progress_ticks = 60.0 };
    for (0..4) |_| _ = state.tick(.{}, .{ 0, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 59.0), state.progress_ticks, 0.001);
}

test "interruption decays plume alpha" {
    var state = BrushingVisualState{ .plume_alpha = 1.0 };
    _ = state.tick(.{}, .{ 0, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 0.88), state.plume_alpha, 0.001);
}

test "plume alpha reaches zero after sufficient release ticks" {
    var state = BrushingVisualState{ .plume_alpha = 1.0 };
    for (0..9) |_| _ = state.tick(.{}, .{ 0, 0, 0 });
    try std.testing.expectEqual(@as(f32, 0.0), state.plume_alpha);
}

test "particle fade is scaled by plume alpha" {
    const state = BrushingVisualState{ .plume_alpha = 0.5 };
    const particle = Particle{ .particle_type = .dust_plume, .position = .{ 0, 0, 0 }, .velocity = .{ 0, 0, 0 }, .lifetime_ticks = 10, .scale = 1.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), state.particleAlpha(particle), 0.001);
}

test "tick emits stage burst on crossing stage 1" {
    var state = BrushingVisualState{ .progress_ticks = 23.0 };
    const result = state.tick(.{ .main = .brush }, .{ 1, 2, 3 });
    try std.testing.expect(result.emitted_burst != null);
    try std.testing.expectEqual(ExcavationStage.stage_1, result.stage);
}

test "tick does not emit repeated burst while stage remains unchanged" {
    var state = BrushingVisualState{ .progress_ticks = 30.0, .previous_stage = .stage_1 };
    const result = state.tick(.{ .main = .brush }, .{ 0, 0, 0 });
    try std.testing.expect(result.emitted_burst == null);
}

test "brushing tick reports the active hand" {
    var state = BrushingVisualState{};
    const result = state.tick(.{ .off = .brush }, .{ 0, 0, 0 });
    try std.testing.expectEqual(Hand.off, result.brush_hand.?);
}

test "completion tick plays the relic chime once" {
    var state = BrushingVisualState{ .progress_ticks = 95.0 };
    const result = state.tick(.{ .main = .brush }, .{ 0, 0, 0 });
    try std.testing.expect(result.audio.play_completion_chime);
}

test "completion chime does not repeat while holding at completion" {
    var state = BrushingVisualState{ .progress_ticks = 95.0 };
    _ = state.tick(.{ .main = .brush }, .{ 0, 0, 0 });
    const result = state.tick(.{ .main = .brush }, .{ 0, 0, 0 });
    try std.testing.expect(!result.audio.play_completion_chime);
}

test "brushing loop is active during incomplete excavation" {
    var state = BrushingVisualState{ .progress_ticks = 40.0 };
    try std.testing.expect(state.tick(.{ .main = .brush }, .{ 0, 0, 0 }).audio.play_brush_loop);
}

test "released brush disables brushing loop" {
    var state = BrushingVisualState{ .progress_ticks = 40.0 };
    try std.testing.expect(!state.tick(.{}, .{ 0, 0, 0 }).audio.play_brush_loop);
}

test "particle burst generation is deterministic" {
    const first = makeBurst(.stage_3, .{ 2, 3, 4 }, 1234);
    const second = makeBurst(.stage_3, .{ 2, 3, 4 }, 1234);
    try std.testing.expectEqual(first.count, second.count);
    try std.testing.expectEqual(first.particles[0].velocity, second.particles[0].velocity);
}

test "lootInventoryTag maps all archaeology loot variants to global item IDs" {
    try std.testing.expectEqual(@as(u16, 369), lootInventoryTag(.{ .pottery_sherd = .angler }));
    try std.testing.expectEqual(@as(u16, 492), lootInventoryTag(.{ .sniffer_egg = {} }));
    try std.testing.expectEqual(@as(u16, 395), lootInventoryTag(.{ .armor_trim = .wayfinder }));
    try std.testing.expectEqual(@as(u16, 229), lootInventoryTag(.{ .iron_axe = {} }));
    try std.testing.expectEqual(@as(u16, 236), lootInventoryTag(.{ .wooden_hoe = {} }));
    try std.testing.expectEqual(@as(u16, 427), lootInventoryTag(.{ .music_disc_relic = {} }));
}

test "ActiveExcavation progresses through 4 stages to completion and consumes 1 durability" {
    var session = ActiveExcavation{};
    const pos = [3]i32{ 4, 64, 8 };
    const player_pos = [3]f32{ 4.5, 64.5, 10.0 };

    const s1 = session.advanceStageStep(pos, player_pos, 64, 42);
    try std.testing.expectEqual(ExcavationStage.stage_1, s1.stage);
    try std.testing.expect(s1.emitted_burst != null);
    try std.testing.expect(!s1.completed);

    const s2 = session.advanceStageStep(pos, player_pos, 64, 42);
    try std.testing.expectEqual(ExcavationStage.stage_2, s2.stage);
    try std.testing.expect(!s2.completed);

    const s3 = session.advanceStageStep(pos, player_pos, 64, 42);
    try std.testing.expectEqual(ExcavationStage.stage_3, s3.stage);
    try std.testing.expect(!s3.completed);

    const s4 = session.advanceStageStep(pos, player_pos, 64, 42);
    try std.testing.expect(s4.completed);
    try std.testing.expect(s4.play_completion_chime);
    try std.testing.expect(s4.extracted_item_tag > 0);
    try std.testing.expectEqual(@as(u16, 1), s4.durability_consumed);
    try std.testing.expect(!session.active);
}

test "ActiveExcavation stepFrame interrupts durability and decays when released" {
    var session = ActiveExcavation{};
    const pos = [3]i32{ 0, 64, 0 };
    const player_pos = [3]f32{ 0.5, 64.5, 2.0 };

    var step_i: usize = 0;
    while (step_i < 25) : (step_i += 1) {
        const res = session.stepFrame(0.05, true, true, pos, player_pos, 64, 17);
        if (step_i == 23) {
            try std.testing.expectEqual(ExcavationStage.stage_1, res.stage);
            try std.testing.expect(res.emitted_burst != null);
        }
    }
    try std.testing.expect(session.active);

    const rel = session.stepFrame(0.05, false, false, pos, player_pos, 64, 17);
    try std.testing.expectEqual(@as(u16, 1), rel.durability_consumed);
}
