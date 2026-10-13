const std = @import("std");

/// Block type identifier. Packed into chunk storage.
pub const BlockId = enum(u8) {
    air = 0,
    stone = 1,
    dirt = 2,
    grass = 3,
    water = 4,
    wood = 5,
    leaves = 6,
    wood_planks = 7,
    crafting_table = 8,
    cobblestone = 9,
    coal_ore = 10,
    iron_ore = 11,
    sand = 12,
    glass = 13,
    sandstone = 14,
    brick = 15,
    wool = 16,
    furnace = 17,
    snow = 18,
    ladder = 19,
    tnt = 20,
    torch = 21,
    chest = 22,
    wooden_door_closed = 23,
    wooden_door_open = 24,
    pressure_plate_up = 25,
    pressure_plate_down = 26,
    redstone_wire_off = 27,
    redstone_wire_on = 28,
    lever_off = 29,
    lever_on = 30,
    repeater_off = 31,
    repeater_on = 32,
    redstone_lamp_off = 33,
    redstone_lamp_on = 34,
    iron_door_closed = 35,
    iron_door_open = 36,
    redstone_torch_off = 37,
    redstone_torch_on = 38,
    cactus = 39,
    campfire = 40,
    lava = 41,
    obsidian = 42,
    nether_portal = 43,
    netherrack = 44,
    soul_sand = 45,
    magma = 46,
    glowstone = 47,
    nether_quartz_ore = 48,
    quartz_block = 49,
    quartz_pillar = 50,
    chiseled_quartz_block = 51,
    // ponytail: Nether masonry ceiling; upgrade when adding red nether bricks and cracked nether bricks.
    nether_brick = 52,
    nether_brick_fence = 53,
    // ponytail: single-stage wart crop; upgrade to multi-stage growth blocks when crop stages land.
    nether_wart = 54,
    soul_torch = 55,
    soul_campfire = 56,
    spawner_cage = 57,
    wither_skull_block = 58,
    beacon = 59,
    ancient_debris = 60,
    respawn_anchor = 61,
    crying_obsidian = 62,
    lodestone = 63,
    basalt = 64,
    blackstone = 65,
    gilded_blackstone = 66,
    // ponytail: single weeping vine block with hanging attachments; upgrade with separate vine tip block when age/flowering lands.
    weeping_vines = 67,
    // ponytail: single twisting vine block; upgrade with age growth stages when vine tick loop lands.
    twisting_vines = 68,
    // ponytail: single target block; upgrade with multi-ring hit precision strength when raycast uv hits land.
    target_block = 69,
    // ponytail: single hay bale orientation; upgrade with directional 3-axis rotation when axis metadata lands.
    hay_bale = 70,
    crimson_fungus = 71,
    warped_fungus = 72,
    shroomlight = 73,
    chiseled_nether_brick = 74,
    dispenser = 75,
    dropper = 76,
    hopper = 77,
    brewing_stand = 78,
    cauldron = 79,
    daylight_detector = 80,
    daylight_detector_inverted = 81,
    note_block = 82,
    jukebox = 83,
    oak_fence = 84,
    armor_stand = 85,
    enchantment_table = 86,
    anvil = 87,
    grindstone = 88,
    smithing_table = 89,
    cartography_table = 90,
    fletching_table = 91,
    composter = 92,
    loom = 93,
    smoker = 94,
    blast_furnace = 95,
    stonecutter = 96,
    lantern = 97,
    soul_lantern = 98,
    chain = 99,

    pub fn is_solid(self: BlockId) bool {
        return self != .air and self != .water and self != .lava and self != .ladder and self != .torch and self != .wooden_door_open and self != .iron_door_open and self != .pressure_plate_up and self != .pressure_plate_down and self != .redstone_wire_off and self != .redstone_wire_on and self != .lever_off and self != .lever_on and self != .repeater_off and self != .repeater_on and self != .redstone_torch_off and self != .redstone_torch_on and self != .campfire and self != .nether_portal and self != .nether_wart and self != .soul_torch and self != .soul_campfire and self != .wither_skull_block and self != .weeping_vines and self != .twisting_vines and self != .crimson_fungus and self != .warped_fungus and self != .brewing_stand and self != .lantern and self != .soul_lantern and self != .chain;
    }

    pub fn is_campfire(self: BlockId) bool {
        return self == .campfire or self == .soul_campfire;
    }

    pub fn is_spawner(self: BlockId) bool {
        return self == .spawner_cage;
    }

    pub fn is_falling(self: BlockId) bool {
        return self == .sand or self == .anvil;
    }

    pub fn is_cactus(self: BlockId) bool {
        return self == .cactus;
    }

    pub fn is_ladder(self: BlockId) bool {
        return self == .ladder or self == .weeping_vines or self == .twisting_vines;
    }

    pub fn is_weeping_vines(self: BlockId) bool {
        return self == .weeping_vines;
    }

    pub fn is_twisting_vines(self: BlockId) bool {
        return self == .twisting_vines;
    }

    pub fn is_target_block(self: BlockId) bool {
        return self == .target_block;
    }

    pub fn is_fence(self: BlockId) bool {
        return self == .nether_brick_fence or self == .oak_fence;
    }

    pub fn is_hay_bale(self: BlockId) bool {
        return self == .hay_bale;
    }

    pub fn is_fungus(self: BlockId) bool {
        return self == .crimson_fungus or self == .warped_fungus;
    }

    pub fn is_fluid(self: BlockId) bool {
        return self == .water or self == .lava;
    }

    pub fn is_transparent(self: BlockId) bool {
        return self == .air or self == .water or self == .lava or self == .glass or self == .ladder or self == .torch or self == .wooden_door_closed or self == .wooden_door_open or self == .iron_door_closed or self == .iron_door_open or self == .pressure_plate_up or self == .pressure_plate_down or self == .redstone_wire_off or self == .redstone_wire_on or self == .lever_off or self == .lever_on or self == .repeater_off or self == .repeater_on or self == .redstone_torch_off or self == .redstone_torch_on or self == .nether_portal or self == .nether_brick_fence or self == .oak_fence or self == .armor_stand or self == .enchantment_table or self == .anvil or self == .grindstone or self == .composter or self == .nether_wart or self == .soul_torch or self == .soul_campfire or self == .spawner_cage or self == .wither_skull_block or self == .beacon or self == .weeping_vines or self == .twisting_vines or self == .crimson_fungus or self == .warped_fungus or self == .brewing_stand or self == .stonecutter or self == .lantern or self == .soul_lantern or self == .chain;
    }

    /// 0.0 = lit by sun only. 1.0 = full glow even at midnight.
    /// Covers flame torches, lit redstone lamps, lit redstone torches,
    /// powered wire, and powered repeaters.
    pub fn emissive(self: BlockId) f32 {
        return switch (self) {
            .enchantment_table => 0.5,
            .lantern => 0.95,
            .soul_lantern => 0.75,
            .torch => 0.9,
            .soul_torch => 0.7,
            .soul_campfire => 0.8,
            .spawner_cage => 0.6,
            .redstone_lamp_on => 1.0,
            .redstone_torch_on => 0.85,
            .redstone_wire_on => 0.7,
            .repeater_on => 0.6,
            .lava => 1.0,
            .nether_portal => 0.85,
            .magma => 0.7,
            .glowstone => 1.0,
            .beacon => 1.0,
            .respawn_anchor => 0.85,
            .crying_obsidian => 0.7,
            .weeping_vines => 0.35,
            .twisting_vines => 0.4,
            .warped_fungus => 0.35,
            .shroomlight => 1.0,
            .brewing_stand => 0.4,
            else => 0.0,
        };
    }

    pub fn isFlammable(self: BlockId) bool {
        return switch (self) {
            .wood, .leaves, .wood_planks, .crafting_table, .wool, .chest, .note_block, .jukebox, .oak_fence, .armor_stand, .smithing_table, .cartography_table, .fletching_table, .composter, .loom, .wooden_door_closed, .wooden_door_open, .pressure_plate_up, .pressure_plate_down, .weeping_vines, .twisting_vines, .target_block, .hay_bale, .crimson_fungus, .warped_fungus, .shroomlight => true,
            else => false,
        };
    }

    /// Return tile coordinates (tile_x, tile_y) on the 4x4 atlas for given face.
    /// Face index matches chunk_mesh order:
    /// 0: Up (+Y)
    /// 1: Down (-Y)
    /// 2: North (-Z)
    /// 3: South (+Z)
    /// 4: East (+X)
    /// 5: West (-X)
    pub fn getFaceTexture(self: BlockId, face_idx: usize) struct { x: u32, y: u32 } {
        return switch (self) {
            .grass => switch (face_idx) {
                0 => .{ .x = 0, .y = 0 }, // Grass Top
                1 => .{ .x = 2, .y = 0 }, // Dirt bottom
                else => .{ .x = 1, .y = 0 }, // Grass Side
            },
            .dirt => .{ .x = 2, .y = 0 },
            .stone => .{ .x = 3, .y = 0 },
            .water => .{ .x = 0, .y = 1 },
            .wood => switch (face_idx) {
                0, 1 => .{ .x = 2, .y = 1 }, // Wood ring top/bottom
                else => .{ .x = 1, .y = 1 }, // Wood bark sides
            },
            .leaves => .{ .x = 3, .y = 1 },
            .wood_planks => .{ .x = 2, .y = 2 },
            .cobblestone => .{ .x = 0, .y = 3 },
            .coal_ore => .{ .x = 1, .y = 3 },
            .iron_ore => .{ .x = 2, .y = 3 },
            .sand => .{ .x = 3, .y = 3 },
            .glass => .{ .x = 0, .y = 4 },
            .sandstone => switch (face_idx) {
                0 => .{ .x = 1, .y = 4 }, // Sandstone Top
                1 => .{ .x = 3, .y = 4 }, // Sandstone Bottom
                else => .{ .x = 2, .y = 4 }, // Sandstone Side
            },
            .brick => .{ .x = 4, .y = 4 },
            .wool => .{ .x = 7, .y = 4 },
            .furnace => .{ .x = 0, .y = 5 },
            .snow => .{ .x = 1, .y = 5 },
            .ladder => .{ .x = 4, .y = 5 },
            .tnt => .{ .x = 5, .y = 5 },
            .torch => .{ .x = 6, .y = 5 },
            .chest => .{ .x = 7, .y = 5 },
            .wooden_door_closed => .{ .x = 0, .y = 6 },
            .wooden_door_open => .{ .x = 1, .y = 6 },
            .pressure_plate_up => .{ .x = 2, .y = 6 },
            .pressure_plate_down => .{ .x = 3, .y = 6 },
            .redstone_wire_off => .{ .x = 4, .y = 6 },
            .redstone_wire_on => .{ .x = 5, .y = 6 },
            .lever_off => .{ .x = 6, .y = 6 },
            .lever_on => .{ .x = 7, .y = 6 },
            .repeater_off => .{ .x = 0, .y = 7 },
            .repeater_on => .{ .x = 1, .y = 7 },
            .redstone_lamp_off => .{ .x = 2, .y = 7 },
            .redstone_lamp_on => .{ .x = 3, .y = 7 },
            .iron_door_closed => .{ .x = 4, .y = 7 },
            .iron_door_open => .{ .x = 5, .y = 7 },
            .redstone_torch_off => .{ .x = 6, .y = 7 },
            .redstone_torch_on => .{ .x = 7, .y = 7 },
            .cactus => .{ .x = 3, .y = 1 },
            .campfire => .{ .x = 4, .y = 3 },
            .lava => .{ .x = 5, .y = 3 },
            .obsidian => .{ .x = 1, .y = 2 },
            .nether_portal => .{ .x = 2, .y = 6 }, // Ethereal purple portal vortex tile
            .netherrack => .{ .x = 3, .y = 3 }, // Craggy crimson nether stone
            .soul_sand => .{ .x = 2, .y = 1 }, // Dark gritty soul sediment
            .magma => .{ .x = 4, .y = 2 }, // Scorched glowing obsidian fissures
            .glowstone => .{ .x = 5, .y = 2 }, // Radiant crystalline golden glowstone
            .nether_quartz_ore => .{ .x = 6, .y = 2 }, // Crimson netherrack with white crystalline quartz veins
            .quartz_block => .{ .x = 7, .y = 2 }, // Polished architectural white quartz block
            .quartz_pillar => switch (face_idx) {
                0, 1 => .{ .x = 7, .y = 2 }, // Top/bottom smooth quartz cap
                else => .{ .x = 6, .y = 3 }, // Fluted column vertical sides
            },
            .chiseled_quartz_block => .{ .x = 7, .y = 3 }, // Carved glyph medallion relief
            .nether_brick => .{ .x = 4, .y = 1 }, // Dark fiery running-bond nether masonry
            .nether_brick_fence => .{ .x = 5, .y = 1 }, // Nether brick post and crossbar rail texture
            .nether_wart => .{ .x = 6, .y = 1 }, // Crimson wart cluster nodules on soul soil
            .soul_torch => .{ .x = 7, .y = 1 }, // Cyan soul flame torch
            .soul_campfire => .{ .x = 4, .y = 0 }, // Soul campfire with cyan embers
            .spawner_cage => .{ .x = 5, .y = 0 }, // Iron mesh spawner cage with burning core
            .wither_skull_block => .{ .x = 6, .y = 0 }, // Bleached wither skull trophy
            .beacon => .{ .x = 7, .y = 0 }, // Crystalline glass beacon enclosing radiant star core
            .ancient_debris => .{ .x = 0, .y = 2 }, // Fossilized metallic ancient debris ore bands
            .crying_obsidian => .{ .x = 6, .y = 4 }, // Obsidian with weeping luminous purple veins
            .lodestone => switch (face_idx) {
                0, 1 => .{ .x = 7, .y = 3 }, // Concentric magnetic rune medallion top/bottom
                else => .{ .x = 6, .y = 3 }, // Fluted magnetic stone column sides
            },
            .basalt => switch (face_idx) {
                0, 1 => .{ .x = 5, .y = 4 }, // Dark polygonal basalt column cap
                else => .{ .x = 4, .y = 4 }, // Columnar dark volcanic basalt shaft
            },
            .blackstone => .{ .x = 2, .y = 5 }, // Dark charcoal volcanic bastion masonry
            .gilded_blackstone => .{ .x = 3, .y = 5 }, // Charcoal masonry studded with glittering gold seams
            .weeping_vines => .{ .x = 6, .y = 1 }, // Crimson hanging tendrils and wart bulbs
            .twisting_vines => .{ .x = 7, .y = 1 }, // Cyan glowing warped tendril spiral
            .target_block => .{ .x = 3, .y = 3 }, // Concentric bullseye target and redstone hay band
            .hay_bale => switch (face_idx) {
                0, 1 => .{ .x = 1, .y = 4 }, // Bound straw end cross-section
                else => .{ .x = 0, .y = 3 }, // Golden dried wheat stalks and twine bands
            },
            .crimson_fungus => .{ .x = 6, .y = 1 }, // Crimson spore cap and yellow speckles
            .warped_fungus => .{ .x = 7, .y = 1 }, // Azure bioluminescent spore cap
            .shroomlight => .{ .x = 5, .y = 3 }, // Luminescent organic shroomlight vesicle
            .chiseled_nether_brick => .{ .x = 5, .y = 1 }, // Chiseled nether brick skull relief medallion
            .smoker => switch (face_idx) {
                0 => .{ .x = 1, .y = 5 }, // Smoker top smoke vent and iron exhaust chimney
                1 => .{ .x = 0, .y = 0 }, // Stone hearth foundation bottom
                else => .{ .x = 0, .y = 5 }, // Cobblestone smoker chamber with oak wood reinforcement
            },
            .blast_furnace => switch (face_idx) {
                0 => .{ .x = 0, .y = 0 }, // Smooth stone blast furnace chimney top
                1 => .{ .x = 0, .y = 0 }, // Smooth stone base bottom
                else => .{ .x = 0, .y = 5 }, // Iron reinforced blast smelting chamber sides
            },
            .stonecutter => switch (face_idx) {
                0 => .{ .x = 1, .y = 1 }, // Circular iron rotary saw blade top
                1 => .{ .x = 0, .y = 0 }, // Smooth stone base bottom
                else => .{ .x = 1, .y = 3 }, // Chiselled stone mason frame sides
            },
            .lantern => switch (face_idx) {
                0 => .{ .x = 0, .y = 2 }, // Wrought iron suspension loop top
                1 => .{ .x = 0, .y = 2 }, // Wrought iron base bottom
                else => .{ .x = 6, .y = 6 }, // Glass casing with glowing fire core flanks
            },
            .soul_lantern => switch (face_idx) {
                0 => .{ .x = 0, .y = 2 }, // Wrought iron suspension loop top
                1 => .{ .x = 0, .y = 2 }, // Wrought iron base bottom
                else => .{ .x = 7, .y = 6 }, // Glass casing with cyan soul flame core flanks
            },
            .chain => switch (face_idx) {
                0 => .{ .x = 1, .y = 2 }, // Interlocking metallic chain link end
                1 => .{ .x = 1, .y = 2 }, // Interlocking metallic chain link end
                else => .{ .x = 2, .y = 2 }, // Vertical iron chain link segment flanks
            },
            .loom => switch (face_idx) {
                0 => .{ .x = 7, .y = 4 }, // Weaving warp thread array and wooden heddle harness top
                1 => .{ .x = 2, .y = 2 }, // Oak wood planks bottom
                else => .{ .x = 4, .y = 3 }, // Timber loom frame and tensioning spindle sides
            },
            .composter => switch (face_idx) {
                0 => .{ .x = 1, .y = 4 }, // Open composting chamber aperture and rich humus layer top
                1 => .{ .x = 2, .y = 2 }, // Oak wood planks bottom
                else => .{ .x = 0, .y = 3 }, // Slatted wooden palisade crate sides
            },
            .fletching_table => switch (face_idx) {
                0 => .{ .x = 3, .y = 3 }, // Inset tool vice and arrow feather vane alignment groove top
                1 => .{ .x = 2, .y = 2 }, // Oak wood planks bottom
                else => .{ .x = 4, .y = 3 }, // Birch timber casing with arrow bundle and carved bowstring sides
            },
            .cartography_table => switch (face_idx) {
                0 => .{ .x = 3, .y = 7 }, // Parchment map spread with brass navigation compass rose top
                1 => .{ .x = 2, .y = 2 }, // Oak wood planks bottom
                else => .{ .x = 4, .y = 3 }, // Polished wood casing with map scroll holders
            },
            .smithing_table => switch (face_idx) {
                0 => .{ .x = 2, .y = 4 }, // Reinforced steel work plate top with schematic etchings
                1 => .{ .x = 2, .y = 2 }, // Oak wood timber foundation bottom
                else => .{ .x = 3, .y = 4 }, // Dark oak casing sides with smithing tool rack & clamp
            },
            .grindstone => switch (face_idx) {
                0 => .{ .x = 1, .y = 1 }, // Polished stone grinding wheel pivot top
                1 => .{ .x = 2, .y = 2 }, // Oak wood leg framing base bottom
                else => .{ .x = 0, .y = 0 }, // Smooth stone grinding wheel rim flanked by oak braces
            },
            .anvil => switch (face_idx) {
                0 => .{ .x = 1, .y = 1 }, // Flat forged iron striking face
                1 => .{ .x = 0, .y = 2 }, // Heavy dark iron foundation pedestal
                else => .{ .x = 2, .y = 3 }, // Cast iron waisted horn & body flank
            },
            .enchantment_table => switch (face_idx) {
                0 => .{ .x = 6, .y = 2 }, // Open celestial grimoire on crimson cloth
                1 => .{ .x = 5, .y = 2 }, // Obsidian base foundation
                else => .{ .x = 6, .y = 0 }, // Carved runic obsidian pedestal sides
            },
            .armor_stand => switch (face_idx) {
                1 => .{ .x = 0, .y = 0 }, // Smooth stone base plate
                else => .{ .x = 2, .y = 2 }, // Polished oak dowel framing
            },
            .oak_fence => .{ .x = 2, .y = 2 }, // Oak wood texture
            .jukebox => switch (face_idx) {
                0 => .{ .x = 6, .y = 3 }, // Brass phonograph spindle aperture top
                1 => .{ .x = 2, .y = 2 }, // Oak wood base bottom
                else => .{ .x = 4, .y = 3 }, // Carved wood sound chest casing sides
            },
            .note_block => switch (face_idx) {
                0, 1 => .{ .x = 2, .y = 2 }, // Wooden soundboard top & bottom
                else => .{ .x = 4, .y = 3 }, // Carved acoustic wooden sound hole sides
            },
            .daylight_detector => switch (face_idx) {
                0 => .{ .x = 3, .y = 7 }, // Radiant solar quartz photovoltaic cell top (day)
                1 => .{ .x = 2, .y = 2 }, // Oak wood base bottom
                else => .{ .x = 2, .y = 2 }, // Oak wood panel sides
            },
            .daylight_detector_inverted => switch (face_idx) {
                0 => .{ .x = 7, .y = 1 }, // Moonlight cyan photovoltaic cell top (night)
                1 => .{ .x = 2, .y = 2 }, // Oak wood base bottom
                else => .{ .x = 2, .y = 2 }, // Oak wood panel sides
            },
            .cauldron => switch (face_idx) {
                0 => .{ .x = 7, .y = 3 }, // Basin rim opening / hopper aperture
                else => .{ .x = 0, .y = 2 }, // Dark forged iron cauldron basin walls & legs
            },
            .brewing_stand => switch (face_idx) {
                0 => .{ .x = 5, .y = 2 }, // Golden apparatus / blaze core top
                else => .{ .x = 1, .y = 3 }, // Cobblestone tripod base casing
            },
            .hopper => switch (face_idx) {
                0 => .{ .x = 7, .y = 3 }, // Top funnel throat aperture
                else => .{ .x = 0, .y = 2 }, // Dark iron funnel casing sides and spout bottom
            },
            .dropper => switch (face_idx) {
                2 => .{ .x = 1, .y = 5 }, // Stone face with horizontal dropper slot mouth
                else => .{ .x = 1, .y = 3 }, // Cobblestone casing
            },
            .dispenser => switch (face_idx) {
                2 => .{ .x = 0, .y = 5 }, // Stone face with nozzle aperture
                else => .{ .x = 1, .y = 3 }, // Cobblestone casing
            },
            .respawn_anchor => switch (face_idx) {
                0 => .{ .x = 5, .y = 2 }, // Radiant crystalline glowstone top portal core
                else => .{ .x = 1, .y = 2 }, // Dense obsidian casing sides and bottom
            },
            .crafting_table => switch (face_idx) {
                0 => .{ .x = 3, .y = 2 }, // Table top with tools
                1 => .{ .x = 2, .y = 2 }, // Planks bottom
                else => .{ .x = 3, .y = 2 }, // Table sides
            },
            .air => .{ .x = 0, .y = 0 },
        };
    }
};

/// Static properties for each block type.
pub const BlockDef = struct {
    name: []const u8,
    solid: bool,
    transparent: bool,
    fluid: bool,
};

/// Mining hardness: seconds to break with bare hand. Higher = tougher.
/// Tool tiers gate drops and speed up matching blocks.
///
/// Tool ids mirror `ItemType` discriminants without importing inventory
/// (cross-directory import breaks standalone test targets): 9 = wooden_pickaxe, 27 = iron_pickaxe.
pub const TOOL_WOODEN_PICKAXE: u8 = 9;
pub const TOOL_IRON_PICKAXE: u8 = 27;
pub const TOOL_NETHERITE_PICKAXE: u8 = 73;

pub fn hardness(block: BlockId) f32 {
    return switch (block) {
        .air, .water => 0.0,
        .dirt, .grass => 0.45,
        .sand => 0.5,
        .glass => 0.3,
        .sandstone => 1.8,
        .wool => 0.4,
        .target_block => 0.6,
        .shroomlight => 1.0,
        .hay_bale => 0.5,
        .crimson_fungus, .warped_fungus => 0.0,
        .furnace => 2.5,
        .snow => 0.3,
        .ladder => 0.4,
        .tnt => 0.0,
        .weeping_vines, .twisting_vines => 0.2,
        .torch => 0.1,
        .soul_torch => 0.1,
        .redstone_torch_off, .redstone_torch_on => 0.0,
        .redstone_wire_off, .redstone_wire_on => 0.0,
        .chest => 1.0,
        .wooden_door_closed, .wooden_door_open, .pressure_plate_up, .pressure_plate_down, .lever_off, .lever_on => 0.5,
        .repeater_off, .repeater_on => 0.2,
        .redstone_lamp_off, .redstone_lamp_on => 0.4,
        .brick => 2.0,
        .wood => 0.9,
        .leaves => 0.25,
        .wood_planks => 0.9,
        .crafting_table => 0.9,
        .cobblestone => 2.2,
        .stone => 2.5,
        .coal_ore => 3.0,
        .iron_ore => 3.5,
        .iron_door_closed, .iron_door_open => 3.0,
        .cactus => 0.4,
        .campfire => 1.0,
        .soul_campfire => 1.0,
        .spawner_cage => 5.0,
        .wither_skull_block => 0.5,
        .beacon => 3.0,
        .ancient_debris => 12.0,
        .respawn_anchor => 15.0,
        .crying_obsidian => 15.0,
        .lodestone => 5.0,
        .basalt => 2.5,
        .blackstone => 3.0,
        .gilded_blackstone => 3.0,
        .lava => 0.0,
        .obsidian => 15.0,
        .nether_portal => 0.0,
        .netherrack => 0.4,
        .soul_sand => 0.5,
        .magma => 0.5,
        .glowstone => 0.3,
        .nether_quartz_ore => 0.8,
        .quartz_block => 1.2,
        .quartz_pillar => 1.2,
        .chiseled_quartz_block => 1.2,
        .nether_brick => 2.0,
        .nether_brick_fence => 2.0,
        .chiseled_nether_brick => 2.0,
        .dispenser => 3.5,
        .dropper => 3.5,
        .hopper => 3.0,
        .brewing_stand => 2.0,
        .cauldron => 2.0,
        .daylight_detector, .daylight_detector_inverted => 0.2,
        .note_block => 0.8,
        .armor_stand => 1.0,
        .enchantment_table => 5.0,
        .anvil => 5.0,
        .grindstone => 2.0,
        .smithing_table, .cartography_table, .fletching_table => 2.5,
        .composter => 0.6,
        .loom => 2.5,
        .smoker, .blast_furnace, .stonecutter => 3.5,
        .jukebox, .oak_fence => 2.0,
        .lantern, .soul_lantern => 3.5,
        .chain => 5.0,
        .nether_wart => 0.3,
    };
}

/// Tool class needed to harvest a block's drop at all.
pub const ToolTier = enum(u8) {
    hand = 0,
    wooden = 1,
};

pub fn requiredTier(block: BlockId) ToolTier {
    return switch (block) {
        .stone, .obsidian, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .iron_door_closed, .iron_door_open, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .ancient_debris, .respawn_anchor, .crying_obsidian, .lodestone, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain => .wooden,
        else => .hand,
    };
}

/// Mining speed multiplier for held item vs target block.
/// Wooden pickaxe is 3x on stone-class blocks, 1.5x elsewhere.
pub fn toolMultiplier(held_tool_id: u8, block: BlockId) f32 {
    if (held_tool_id == TOOL_NETHERITE_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .ancient_debris, .respawn_anchor, .crying_obsidian, .lodestone, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain => 6.0,
            else => 3.0,
        };
    }
    if (held_tool_id == TOOL_IRON_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .ancient_debris, .respawn_anchor, .crying_obsidian, .lodestone, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain => 4.0,
            else => 2.0,
        };
    }
    if (held_tool_id == TOOL_WOODEN_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain => 3.0,
            else => 1.5,
        };
    }
    return 1.0;
}

/// Seconds to mine `block` while holding tool with discriminant `held_tool_id`.
pub fn mineTime(block: BlockId, held_tool_id: u8) f32 {
    if (block == .air or block == .water) return 0.0;
    return hardness(block) / toolMultiplier(held_tool_id, block);
}

pub const block_defs = std.EnumArray(BlockId, BlockDef).init(.{
    .air = .{ .name = "air", .solid = false, .transparent = true, .fluid = false },
    .stone = .{ .name = "stone", .solid = true, .transparent = false, .fluid = false },
    .dirt = .{ .name = "dirt", .solid = true, .transparent = false, .fluid = false },
    .grass = .{ .name = "grass", .solid = true, .transparent = false, .fluid = false },
    .water = .{ .name = "water", .solid = false, .transparent = true, .fluid = true },
    .wood = .{ .name = "wood", .solid = true, .transparent = false, .fluid = false },
    .leaves = .{ .name = "leaves", .solid = true, .transparent = false, .fluid = false },
    .wood_planks = .{ .name = "wood_planks", .solid = true, .transparent = false, .fluid = false },
    .crafting_table = .{ .name = "crafting_table", .solid = true, .transparent = false, .fluid = false },
    .cobblestone = .{ .name = "cobblestone", .solid = true, .transparent = false, .fluid = false },
    .coal_ore = .{ .name = "coal_ore", .solid = true, .transparent = false, .fluid = false },
    .iron_ore = .{ .name = "iron_ore", .solid = true, .transparent = false, .fluid = false },
    .sand = .{ .name = "sand", .solid = true, .transparent = false, .fluid = false },
    .glass = .{ .name = "glass", .solid = true, .transparent = true, .fluid = false },
    .sandstone = .{ .name = "sandstone", .solid = true, .transparent = false, .fluid = false },
    .wool = .{ .name = "wool", .solid = true, .transparent = false, .fluid = false },
    .furnace = .{ .name = "furnace", .solid = true, .transparent = false, .fluid = false },
    .snow = .{ .name = "snow", .solid = true, .transparent = false, .fluid = false },
    .ladder = .{ .name = "ladder", .solid = false, .transparent = true, .fluid = false },
    .tnt = .{ .name = "tnt", .solid = true, .transparent = false, .fluid = false },
    .torch = .{ .name = "torch", .solid = false, .transparent = true, .fluid = false },
    .chest = .{ .name = "chest", .solid = true, .transparent = false, .fluid = false },
    .wooden_door_closed = .{ .name = "wooden_door_closed", .solid = true, .transparent = true, .fluid = false },
    .wooden_door_open = .{ .name = "wooden_door_open", .solid = false, .transparent = true, .fluid = false },
    .pressure_plate_up = .{ .name = "pressure_plate_up", .solid = false, .transparent = true, .fluid = false },
    .pressure_plate_down = .{ .name = "pressure_plate_down", .solid = false, .transparent = true, .fluid = false },
    .redstone_wire_off = .{ .name = "redstone_wire_off", .solid = false, .transparent = true, .fluid = false },
    .redstone_wire_on = .{ .name = "redstone_wire_on", .solid = false, .transparent = true, .fluid = false },
    .lever_off = .{ .name = "lever_off", .solid = false, .transparent = true, .fluid = false },
    .lever_on = .{ .name = "lever_on", .solid = false, .transparent = true, .fluid = false },
    .repeater_off = .{ .name = "repeater_off", .solid = false, .transparent = true, .fluid = false },
    .repeater_on = .{ .name = "repeater_on", .solid = false, .transparent = true, .fluid = false },
    .redstone_lamp_off = .{ .name = "redstone_lamp_off", .solid = true, .transparent = false, .fluid = false },
    .redstone_lamp_on = .{ .name = "redstone_lamp_on", .solid = true, .transparent = false, .fluid = false },
    .iron_door_closed = .{ .name = "iron_door_closed", .solid = true, .transparent = true, .fluid = false },
    .iron_door_open = .{ .name = "iron_door_open", .solid = false, .transparent = true, .fluid = false },
    .redstone_torch_off = .{ .name = "redstone_torch_off", .solid = false, .transparent = true, .fluid = false },
    .redstone_torch_on = .{ .name = "redstone_torch_on", .solid = false, .transparent = true, .fluid = false },
    .cactus = .{ .name = "cactus", .solid = true, .transparent = false, .fluid = false },
    .campfire = .{ .name = "campfire", .solid = false, .transparent = true, .fluid = false },
    .brick = .{ .name = "brick", .solid = true, .transparent = false, .fluid = false },
    .lava = .{ .name = "lava", .solid = false, .transparent = true, .fluid = true },
    .obsidian = .{ .name = "obsidian", .solid = true, .transparent = false, .fluid = false },
    .nether_portal = .{ .name = "nether_portal", .solid = false, .transparent = true, .fluid = false },
    .netherrack = .{ .name = "netherrack", .solid = true, .transparent = false, .fluid = false },
    .soul_sand = .{ .name = "soul_sand", .solid = true, .transparent = false, .fluid = false },
    .magma = .{ .name = "magma", .solid = true, .transparent = false, .fluid = false },
    .glowstone = .{ .name = "glowstone", .solid = true, .transparent = false, .fluid = false },
    .nether_quartz_ore = .{ .name = "nether_quartz_ore", .solid = true, .transparent = false, .fluid = false },
    .quartz_block = .{ .name = "quartz_block", .solid = true, .transparent = false, .fluid = false },
    .quartz_pillar = .{ .name = "quartz_pillar", .solid = true, .transparent = false, .fluid = false },
    .chiseled_quartz_block = .{ .name = "chiseled_quartz_block", .solid = true, .transparent = false, .fluid = false },
    .nether_brick = .{ .name = "nether_brick", .solid = true, .transparent = false, .fluid = false },
    .nether_brick_fence = .{ .name = "nether_brick_fence", .solid = true, .transparent = true, .fluid = false },
    .nether_wart = .{ .name = "nether_wart", .solid = false, .transparent = true, .fluid = false },
    .soul_torch = .{ .name = "soul_torch", .solid = false, .transparent = true, .fluid = false },
    .soul_campfire = .{ .name = "soul_campfire", .solid = false, .transparent = true, .fluid = false },
    .spawner_cage = .{ .name = "spawner_cage", .solid = true, .transparent = true, .fluid = false },
    .wither_skull_block = .{ .name = "wither_skull_block", .solid = false, .transparent = true, .fluid = false },
    .beacon = .{ .name = "beacon", .solid = true, .transparent = true, .fluid = false },
    .ancient_debris = .{ .name = "ancient_debris", .solid = true, .transparent = false, .fluid = false },
    .respawn_anchor = .{ .name = "respawn_anchor", .solid = true, .transparent = false, .fluid = false },
    .crying_obsidian = .{ .name = "crying_obsidian", .solid = true, .transparent = false, .fluid = false },
    .lodestone = .{ .name = "lodestone", .solid = true, .transparent = false, .fluid = false },
    .basalt = .{ .name = "basalt", .solid = true, .transparent = false, .fluid = false },
    .blackstone = .{ .name = "blackstone", .solid = true, .transparent = false, .fluid = false },
    .gilded_blackstone = .{ .name = "gilded_blackstone", .solid = true, .transparent = false, .fluid = false },
    .weeping_vines = .{ .name = "weeping_vines", .solid = false, .transparent = true, .fluid = false },
    .twisting_vines = .{ .name = "twisting_vines", .solid = false, .transparent = true, .fluid = false },
    .target_block = .{ .name = "target_block", .solid = true, .transparent = false, .fluid = false },
    .hay_bale = .{ .name = "hay_bale", .solid = true, .transparent = false, .fluid = false },
    .crimson_fungus = .{ .name = "crimson_fungus", .solid = false, .transparent = true, .fluid = false },
    .warped_fungus = .{ .name = "warped_fungus", .solid = false, .transparent = true, .fluid = false },
    .shroomlight = .{ .name = "shroomlight", .solid = true, .transparent = false, .fluid = false },
    .chiseled_nether_brick = .{ .name = "chiseled_nether_brick", .solid = true, .transparent = false, .fluid = false },
    .dispenser = .{ .name = "dispenser", .solid = true, .transparent = false, .fluid = false },
    .dropper = .{ .name = "dropper", .solid = true, .transparent = false, .fluid = false },
    .hopper = .{ .name = "hopper", .solid = true, .transparent = false, .fluid = false },
    .brewing_stand = .{ .name = "brewing_stand", .solid = false, .transparent = true, .fluid = false },
    .cauldron = .{ .name = "cauldron", .solid = true, .transparent = false, .fluid = false },
    .daylight_detector = .{ .name = "daylight_detector", .solid = true, .transparent = false, .fluid = false },
    .daylight_detector_inverted = .{ .name = "daylight_detector_inverted", .solid = true, .transparent = false, .fluid = false },
    .note_block = .{ .name = "note_block", .solid = true, .transparent = false, .fluid = false },
    .jukebox = .{ .name = "jukebox", .solid = true, .transparent = false, .fluid = false },
    .oak_fence = .{ .name = "oak_fence", .solid = true, .transparent = true, .fluid = false },
    .armor_stand = .{ .name = "armor_stand", .solid = true, .transparent = true, .fluid = false },
    .enchantment_table = .{ .name = "enchantment_table", .solid = true, .transparent = true, .fluid = false },
    .anvil = .{ .name = "anvil", .solid = true, .transparent = true, .fluid = false },
    .grindstone = .{ .name = "grindstone", .solid = true, .transparent = true, .fluid = false },
    .smithing_table = .{ .name = "smithing_table", .solid = true, .transparent = false, .fluid = false },
    .cartography_table = .{ .name = "cartography_table", .solid = true, .transparent = false, .fluid = false },
    .fletching_table = .{ .name = "fletching_table", .solid = true, .transparent = false, .fluid = false },
    .composter = .{ .name = "composter", .solid = true, .transparent = true, .fluid = false },
    .loom = .{ .name = "loom", .solid = true, .transparent = false, .fluid = false },
    .smoker = .{ .name = "smoker", .solid = true, .transparent = false, .fluid = false },
    .blast_furnace = .{ .name = "blast_furnace", .solid = true, .transparent = false, .fluid = false },
    .stonecutter = .{ .name = "stonecutter", .solid = true, .transparent = true, .fluid = false },
    .lantern = .{ .name = "lantern", .solid = false, .transparent = true, .fluid = false },
    .soul_lantern = .{ .name = "soul_lantern", .solid = false, .transparent = true, .fluid = false },
    .chain = .{ .name = "chain", .solid = false, .transparent = true, .fluid = false },
});

/// A beacon activates when the column directly above it up to world ceiling (y=15)
/// contains only transparent blocks (air, glass, etc).
pub fn isBeaconSkyClear(lookup: *const fn (x: i32, y: i32, z: i32) BlockId, bx: i32, by: i32, bz: i32) bool {
    var y = by + 1;
    while (y <= 15) : (y += 1) {
        const b = lookup(bx, y, bz);
        if (!b.is_transparent()) return false;
    }
    return true;
}

test "isBeaconSkyClear checks column above beacon" {
    const Mock = struct {
        fn openSky(x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = z;
            return if (y >= 10) .air else .glass;
        }
        fn blockedSky(x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = z;
            return if (y == 12) .stone else .air;
        }
    };
    try std.testing.expect(isBeaconSkyClear(Mock.openSky, 0, 5, 0));
    try std.testing.expect(!isBeaconSkyClear(Mock.blockedSky, 0, 5, 0));
}

test "gilded blackstone block properties and textures" {
    try std.testing.expect(BlockId.gilded_blackstone.is_solid());
    try std.testing.expect(!BlockId.gilded_blackstone.is_transparent());
    try std.testing.expectEqual(hardness(.gilded_blackstone), 3.0);
    try std.testing.expectEqual(requiredTier(.gilded_blackstone), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .gilded_blackstone), 6.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .gilded_blackstone), 4.0);
    try std.testing.expectEqual(footstepType(.gilded_blackstone), .stone);

    const tex = BlockId.gilded_blackstone.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 3);
    try std.testing.expectEqual(tex.y, 5);
}

test "blackstone block properties and bastion textures" {
    try std.testing.expect(BlockId.blackstone.is_solid());
    try std.testing.expect(!BlockId.blackstone.is_transparent());
    try std.testing.expectEqual(hardness(.blackstone), 3.0);
    try std.testing.expectEqual(requiredTier(.blackstone), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .blackstone), 6.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .blackstone), 4.0);
    try std.testing.expectEqual(footstepType(.blackstone), .stone);

    const tex = BlockId.blackstone.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 2);
    try std.testing.expectEqual(tex.y, 5);
}

test "basalt block properties and column textures" {
    try std.testing.expect(BlockId.basalt.is_solid());
    try std.testing.expect(!BlockId.basalt.is_transparent());
    try std.testing.expectEqual(hardness(.basalt), 2.5);
    try std.testing.expectEqual(requiredTier(.basalt), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .basalt), 6.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .basalt), 4.0);
    try std.testing.expectEqual(footstepType(.basalt), .stone);

    const top_tex = BlockId.basalt.getFaceTexture(0);
    try std.testing.expectEqual(top_tex.x, 5);
    try std.testing.expectEqual(top_tex.y, 4);
    const side_tex = BlockId.basalt.getFaceTexture(2);
    try std.testing.expectEqual(side_tex.x, 4);
    try std.testing.expectEqual(side_tex.y, 4);
}

test "lodestone block properties and textures" {
    try std.testing.expect(BlockId.lodestone.is_solid());
    try std.testing.expect(!BlockId.lodestone.is_transparent());
    try std.testing.expectEqual(hardness(.lodestone), 5.0);
    try std.testing.expectEqual(requiredTier(.lodestone), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .lodestone), 6.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .lodestone), 4.0);
    try std.testing.expectEqual(footstepType(.lodestone), .stone);

    const top_tex = BlockId.lodestone.getFaceTexture(0);
    try std.testing.expectEqual(top_tex.x, 7);
    try std.testing.expectEqual(top_tex.y, 3);
    const side_tex = BlockId.lodestone.getFaceTexture(2);
    try std.testing.expectEqual(side_tex.x, 6);
    try std.testing.expectEqual(side_tex.y, 3);
}

test "crying obsidian properties, textures, and emissive glow" {
    try std.testing.expect(BlockId.crying_obsidian.is_solid());
    try std.testing.expect(!BlockId.crying_obsidian.is_transparent());
    try std.testing.expectApproxEqAbs(BlockId.crying_obsidian.emissive(), 0.7, 0.001);
    try std.testing.expectEqual(hardness(.crying_obsidian), 15.0);
    try std.testing.expectEqual(requiredTier(.crying_obsidian), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .crying_obsidian), 6.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .crying_obsidian), 4.0);
    try std.testing.expectEqual(footstepType(.crying_obsidian), .stone);

    const tex = BlockId.crying_obsidian.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 6);
    try std.testing.expectEqual(tex.y, 4);
}

test "respawn anchor properties, textures, and emissive glow" {
    try std.testing.expect(BlockId.respawn_anchor.is_solid());
    try std.testing.expect(!BlockId.respawn_anchor.is_transparent());
    try std.testing.expectApproxEqAbs(BlockId.respawn_anchor.emissive(), 0.85, 0.001);
    try std.testing.expectEqual(hardness(.respawn_anchor), 15.0);
    try std.testing.expectEqual(requiredTier(.respawn_anchor), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .respawn_anchor), 6.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .respawn_anchor), 4.0);
    try std.testing.expectEqual(footstepType(.respawn_anchor), .stone);

    const top_tex = BlockId.respawn_anchor.getFaceTexture(0);
    try std.testing.expectEqual(top_tex.x, 5);
    try std.testing.expectEqual(top_tex.y, 2);

    const side_tex = BlockId.respawn_anchor.getFaceTexture(2);
    try std.testing.expectEqual(side_tex.x, 1);
    try std.testing.expectEqual(side_tex.y, 2);
}

test "netherite pickaxe tool speed exceeds iron tier" {
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .ancient_debris), 6.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .stone), 6.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .dirt), 3.0);
    try std.testing.expect(mineTime(.ancient_debris, TOOL_NETHERITE_PICKAXE) < mineTime(.ancient_debris, TOOL_IRON_PICKAXE));
    try std.testing.expect(mineTime(.stone, TOOL_NETHERITE_PICKAXE) < mineTime(.stone, TOOL_IRON_PICKAXE));
}

test "ancient debris block properties and textures" {
    try std.testing.expect(BlockId.ancient_debris.is_solid());
    try std.testing.expect(!BlockId.ancient_debris.is_transparent());
    try std.testing.expect(!BlockId.ancient_debris.is_fluid());
    try std.testing.expectEqual(hardness(.ancient_debris), 12.0);
    try std.testing.expectEqual(requiredTier(.ancient_debris), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .ancient_debris), 4.0);
    try std.testing.expectEqual(footstepType(.ancient_debris), .stone);
    const tex = BlockId.ancient_debris.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 0);
    try std.testing.expectEqual(tex.y, 2);
}

test "block is_solid" {
    try std.testing.expect(!BlockId.air.is_solid());
    try std.testing.expect(BlockId.stone.is_solid());
    try std.testing.expect(BlockId.dirt.is_solid());
    try std.testing.expect(BlockId.grass.is_solid());
    try std.testing.expect(!BlockId.water.is_solid());
    try std.testing.expect(BlockId.wood.is_solid());
    try std.testing.expect(BlockId.leaves.is_solid());
    try std.testing.expect(BlockId.cobblestone.is_solid());
    try std.testing.expect(BlockId.coal_ore.is_solid());
    try std.testing.expect(BlockId.iron_ore.is_solid());
    try std.testing.expect(BlockId.sand.is_solid());
    try std.testing.expect(BlockId.glass.is_solid());
    try std.testing.expect(BlockId.sandstone.is_solid());
    try std.testing.expect(BlockId.brick.is_solid());
}

test "new block face texture mapping" {
    const cob = BlockId.cobblestone.getFaceTexture(2);
    try std.testing.expectEqual(cob.x, 0);
    try std.testing.expectEqual(cob.y, 3);
    const ore = BlockId.coal_ore.getFaceTexture(0);
    try std.testing.expectEqual(ore.x, 1);
    try std.testing.expectEqual(ore.y, 3);
    const iron = BlockId.iron_ore.getFaceTexture(0);
    try std.testing.expectEqual(iron.x, 2);
    try std.testing.expectEqual(iron.y, 3);
    const sand = BlockId.sand.getFaceTexture(0);
    try std.testing.expectEqual(sand.x, 3);
    try std.testing.expectEqual(sand.y, 3);
    const gl = BlockId.glass.getFaceTexture(0);
    try std.testing.expectEqual(gl.x, 0);
    try std.testing.expectEqual(gl.y, 4);
    const ss_top = BlockId.sandstone.getFaceTexture(0);
    try std.testing.expectEqual(ss_top.x, 1);
    try std.testing.expectEqual(ss_top.y, 4);
    const ss_side = BlockId.sandstone.getFaceTexture(2);
    try std.testing.expectEqual(ss_side.x, 2);
    try std.testing.expectEqual(ss_side.y, 4);
    const ss_bot = BlockId.sandstone.getFaceTexture(1);
    try std.testing.expectEqual(ss_bot.x, 3);
    try std.testing.expectEqual(ss_bot.y, 4);
    const br = BlockId.brick.getFaceTexture(0);
    try std.testing.expectEqual(br.x, 4);
    try std.testing.expectEqual(br.y, 4);
}

test "block is_transparent" {
    try std.testing.expect(BlockId.air.is_transparent());
    try std.testing.expect(!BlockId.stone.is_transparent());
    try std.testing.expect(!BlockId.dirt.is_transparent());
    try std.testing.expect(!BlockId.grass.is_transparent());
    try std.testing.expect(BlockId.water.is_transparent());
    try std.testing.expect(BlockId.glass.is_transparent());
    try std.testing.expect(!BlockId.sandstone.is_transparent());
    try std.testing.expect(!BlockId.brick.is_transparent());
    try std.testing.expect(!BlockId.wood.is_transparent());
    try std.testing.expect(!BlockId.leaves.is_transparent());
}

test "block properties" {
    const wood = block_defs.get(.wood);
    try std.testing.expectEqualStrings(wood.name, "wood");
    try std.testing.expect(wood.solid);

    const leaves = block_defs.get(.leaves);
    try std.testing.expectEqualStrings(leaves.name, "leaves");
    try std.testing.expect(leaves.solid);
}

test "hardness tiers and tool multipliers" {
    try std.testing.expect(hardness(.dirt) < hardness(.stone));
    try std.testing.expect(hardness(.coal_ore) > hardness(.cobblestone));
    try std.testing.expectEqual(requiredTier(.stone), .wooden);
    try std.testing.expectEqual(requiredTier(.coal_ore), .wooden);
    try std.testing.expectEqual(requiredTier(.dirt), .hand);
    try std.testing.expect(toolMultiplier(TOOL_WOODEN_PICKAXE, .stone) > toolMultiplier(TOOL_WOODEN_PICKAXE, .dirt));
    try std.testing.expectEqual(toolMultiplier(0, .stone), 1.0);
    try std.testing.expect(mineTime(.stone, TOOL_WOODEN_PICKAXE) < mineTime(.stone, 0));
    try std.testing.expect(mineTime(.dirt, 0) < mineTime(.stone, 0));
}

test "block count is reasonable" {
    try std.testing.expect(@typeInfo(BlockId).@"enum".fields.len <= 256);
}

test "block face texture mapping" {
    const wood_top = BlockId.wood.getFaceTexture(0);
    try std.testing.expectEqual(wood_top.x, 2);
    try std.testing.expectEqual(wood_top.y, 1);

    const wood_side = BlockId.wood.getFaceTexture(2);
    try std.testing.expectEqual(wood_side.x, 1);
    try std.testing.expectEqual(wood_side.y, 1);

    const leaves = BlockId.leaves.getFaceTexture(0);
    try std.testing.expectEqual(leaves.x, 3);
    try std.testing.expectEqual(leaves.y, 1);
}

test "wool block props" {
    try std.testing.expect(BlockId.wool.is_solid());
    try std.testing.expect(!BlockId.wool.is_transparent());
    const t = BlockId.wool.getFaceTexture(2);
    try std.testing.expectEqual(t.x, 7);
    try std.testing.expectEqual(t.y, 4);
    try std.testing.expectApproxEqAbs(hardness(.wool), 0.4, 0.001);
}

test "flammable blocks" {
    try std.testing.expect(BlockId.wood.isFlammable());
    try std.testing.expect(BlockId.leaves.isFlammable());
    try std.testing.expect(BlockId.wool.isFlammable());
    try std.testing.expect(!BlockId.stone.isFlammable());
    try std.testing.expect(!BlockId.coal_ore.isFlammable());
}

test "furnace block props" {
    try std.testing.expect(BlockId.furnace.is_solid());
    const t = BlockId.furnace.getFaceTexture(2);
    try std.testing.expectEqual(t.x, 0);
    try std.testing.expectEqual(t.y, 5);
    try std.testing.expectEqual(requiredTier(.furnace), .wooden);
}

test "tnt block props" {
    try std.testing.expect(BlockId.tnt.is_solid());
    const t = BlockId.tnt.getFaceTexture(0);
    try std.testing.expectEqual(t.x, 5);
    try std.testing.expectEqual(t.y, 5);
    try std.testing.expectEqual(hardness(.tnt), 0.0);
}

test "torch block props" {
    try std.testing.expect(!BlockId.torch.is_solid());
    try std.testing.expect(BlockId.torch.is_transparent());
    const t = BlockId.torch.getFaceTexture(0);
    try std.testing.expectEqual(t.x, 6);
    try std.testing.expectEqual(t.y, 5);
}

test "chest block props" {
    try std.testing.expect(BlockId.chest.is_solid());
    try std.testing.expect(!BlockId.chest.is_transparent());
    try std.testing.expect(BlockId.chest.isFlammable());
    const t = BlockId.chest.getFaceTexture(0);
    try std.testing.expectEqual(t.x, 7);
    try std.testing.expectEqual(t.y, 5);
    try std.testing.expectEqual(hardness(.chest), 1.0);
}

test "emissive blocks glow, stone and dirt do not" {
    try std.testing.expectApproxEqAbs(BlockId.torch.emissive(), 0.9, 0.001);
    try std.testing.expectApproxEqAbs(BlockId.redstone_lamp_on.emissive(), 1.0, 0.001);
    try std.testing.expectApproxEqAbs(BlockId.redstone_wire_on.emissive(), 0.7, 0.001);
    try std.testing.expectEqual(BlockId.stone.emissive(), 0.0);
    try std.testing.expectEqual(BlockId.redstone_lamp_off.emissive(), 0.0);
    try std.testing.expectEqual(BlockId.redstone_wire_off.emissive(), 0.0);
}

test "redstone torch block properties" {
    try std.testing.expect(!BlockId.redstone_torch_off.is_solid());
    try std.testing.expect(!BlockId.redstone_torch_on.is_solid());
    try std.testing.expect(BlockId.redstone_torch_off.is_transparent());
    try std.testing.expect(BlockId.redstone_torch_on.is_transparent());
    const rto = BlockId.redstone_torch_off.getFaceTexture(0);
    try std.testing.expectEqual(rto.x, 6);
    try std.testing.expectEqual(rto.y, 7);
    const rtn = BlockId.redstone_torch_on.getFaceTexture(0);
    try std.testing.expectEqual(rtn.x, 7);
    try std.testing.expectEqual(rtn.y, 7);
}

test "iron door block properties" {
    try std.testing.expect(BlockId.iron_door_closed.is_solid());
    try std.testing.expect(!BlockId.iron_door_open.is_solid());
    try std.testing.expect(BlockId.iron_door_closed.is_transparent());
    try std.testing.expect(BlockId.iron_door_open.is_transparent());
    try std.testing.expectEqual(requiredTier(.iron_door_closed), .wooden);
    const idc = BlockId.iron_door_closed.getFaceTexture(0);
    try std.testing.expectEqual(idc.x, 4);
    try std.testing.expectEqual(idc.y, 7);
    const ido = BlockId.iron_door_open.getFaceTexture(0);
    try std.testing.expectEqual(ido.x, 5);
    try std.testing.expectEqual(ido.y, 7);
}

test "redstone lamp block properties" {
    try std.testing.expect(BlockId.redstone_lamp_off.is_solid());
    try std.testing.expect(BlockId.redstone_lamp_on.is_solid());
    try std.testing.expect(!BlockId.redstone_lamp_off.is_transparent());
    try std.testing.expect(!BlockId.redstone_lamp_on.is_transparent());
    const lo = BlockId.redstone_lamp_off.getFaceTexture(0);
    try std.testing.expectEqual(lo.x, 2);
    try std.testing.expectEqual(lo.y, 7);
    const ln = BlockId.redstone_lamp_on.getFaceTexture(0);
    try std.testing.expectEqual(ln.x, 3);
    try std.testing.expectEqual(ln.y, 7);
}

test "repeater block properties" {
    try std.testing.expect(!BlockId.repeater_off.is_solid());
    try std.testing.expect(!BlockId.repeater_on.is_solid());
    try std.testing.expect(BlockId.repeater_off.is_transparent());
    try std.testing.expect(BlockId.repeater_on.is_transparent());
    const ro = BlockId.repeater_off.getFaceTexture(0);
    try std.testing.expectEqual(ro.x, 0);
    try std.testing.expectEqual(ro.y, 7);
    const rn = BlockId.repeater_on.getFaceTexture(0);
    try std.testing.expectEqual(rn.x, 1);
    try std.testing.expectEqual(rn.y, 7);
}

test "lever block properties" {
    try std.testing.expect(!BlockId.lever_off.is_solid());
    try std.testing.expect(!BlockId.lever_on.is_solid());
    try std.testing.expect(BlockId.lever_off.is_transparent());
    try std.testing.expect(BlockId.lever_on.is_transparent());
    const lo = BlockId.lever_off.getFaceTexture(0);
    try std.testing.expectEqual(lo.x, 6);
    try std.testing.expectEqual(lo.y, 6);
    const ln = BlockId.lever_on.getFaceTexture(0);
    try std.testing.expectEqual(ln.x, 7);
    try std.testing.expectEqual(ln.y, 6);
}

test "redstone wire block properties" {
    try std.testing.expect(!BlockId.redstone_wire_off.is_solid());
    try std.testing.expect(!BlockId.redstone_wire_on.is_solid());
    try std.testing.expect(BlockId.redstone_wire_off.is_transparent());
    try std.testing.expect(BlockId.redstone_wire_on.is_transparent());
    try std.testing.expectEqual(hardness(.redstone_wire_off), 0.0);
    const two = BlockId.redstone_wire_off.getFaceTexture(0);
    try std.testing.expectEqual(two.x, 4);
    try std.testing.expectEqual(two.y, 6);
    const twn = BlockId.redstone_wire_on.getFaceTexture(0);
    try std.testing.expectEqual(twn.x, 5);
    try std.testing.expectEqual(twn.y, 6);
}

test "door block properties" {
    try std.testing.expect(BlockId.wooden_door_closed.is_solid());
    try std.testing.expect(!BlockId.wooden_door_open.is_solid());
    try std.testing.expect(BlockId.wooden_door_closed.is_transparent());
    try std.testing.expect(BlockId.wooden_door_open.is_transparent());
    try std.testing.expect(BlockId.wooden_door_closed.isFlammable());
    try std.testing.expect(!BlockId.pressure_plate_up.is_solid());
    try std.testing.expect(!BlockId.pressure_plate_down.is_solid());
    try std.testing.expect(BlockId.pressure_plate_up.is_transparent());
    try std.testing.expect(BlockId.pressure_plate_down.is_transparent());
    try std.testing.expect(BlockId.pressure_plate_up.isFlammable());
    const tpu = BlockId.pressure_plate_up.getFaceTexture(0);
    try std.testing.expectEqual(tpu.x, 2);
    try std.testing.expectEqual(tpu.y, 6);
    const tpd = BlockId.pressure_plate_down.getFaceTexture(0);
    try std.testing.expectEqual(tpd.x, 3);
    try std.testing.expectEqual(tpd.y, 6);
    const tc = BlockId.wooden_door_closed.getFaceTexture(0);
    try std.testing.expectEqual(tc.x, 0);
    try std.testing.expectEqual(tc.y, 6);
    const to = BlockId.wooden_door_open.getFaceTexture(0);
    try std.testing.expectEqual(to.x, 1);
    try std.testing.expectEqual(to.y, 6);
}

test "campfire block definition" {
    try std.testing.expect(BlockId.campfire.is_campfire());
    try std.testing.expect(!BlockId.campfire.is_solid());
    try std.testing.expectEqual(hardness(BlockId.campfire), 1.0);
}

test "cactus properties and block definition" {
    try std.testing.expect(BlockId.cactus.is_solid());
    try std.testing.expect(BlockId.cactus.is_cactus());
    try std.testing.expectEqual(hardness(BlockId.cactus), 0.4);
    const tex = BlockId.cactus.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 3);
    try std.testing.expectEqual(tex.y, 1);
}

pub const FootstepType = enum {
    grass,
    stone,
    wood,
    dirt,
    sand,
    snow,
    wool,
};

pub fn footstepType(block: BlockId) FootstepType {
    return switch (block) {
        .grass, .weeping_vines, .twisting_vines, .hay_bale, .crimson_fungus, .warped_fungus, .shroomlight => .grass,
        .stone, .obsidian, .cobblestone, .coal_ore, .iron_ore, .glass, .sandstone, .brick, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .ancient_debris, .respawn_anchor, .crying_obsidian, .lodestone, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain => .stone,
        .wood, .target_block, .daylight_detector, .daylight_detector_inverted, .note_block, .jukebox, .oak_fence, .armor_stand, .smithing_table, .cartography_table, .fletching_table, .composter, .loom => .wood,
        .dirt => .dirt,
        .sand => .sand,
        .snow => .snow,
        .wool => .wool,
        else => .grass,
    };
}

test "footstepType block classification" {
    try std.testing.expectEqual(FootstepType.grass, footstepType(.grass));
    try std.testing.expectEqual(FootstepType.stone, footstepType(.stone));
    try std.testing.expectEqual(FootstepType.stone, footstepType(.cobblestone));
    try std.testing.expectEqual(FootstepType.stone, footstepType(.brick));
    try std.testing.expectEqual(FootstepType.wood, footstepType(.wood));
    try std.testing.expectEqual(FootstepType.dirt, footstepType(.dirt));
    try std.testing.expectEqual(FootstepType.sand, footstepType(.sand));
    try std.testing.expectEqual(FootstepType.snow, footstepType(.snow));
    try std.testing.expectEqual(FootstepType.wool, footstepType(.wool));
    try std.testing.expectEqual(FootstepType.grass, footstepType(.air));
}

test "lava fluid and obsidian hardness properties" {
    try std.testing.expect(BlockId.lava.is_fluid());
    try std.testing.expect(!BlockId.lava.is_solid());
    try std.testing.expectEqual(@as(f32, 1.0), BlockId.lava.emissive());
    try std.testing.expect(BlockId.obsidian.is_solid());
    try std.testing.expect(!BlockId.obsidian.is_fluid());
    try std.testing.expectEqual(@as(f32, 15.0), hardness(.obsidian));
    try std.testing.expectEqual(ToolTier.wooden, requiredTier(.obsidian));
}

test "nether brick block properties and textures" {
    try std.testing.expect(BlockId.nether_brick.is_solid());
    try std.testing.expect(!BlockId.nether_brick.is_transparent());
    try std.testing.expect(!BlockId.nether_brick.is_fluid());
    try std.testing.expectEqual(hardness(.nether_brick), 2.0);
    try std.testing.expectEqual(requiredTier(.nether_brick), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .nether_brick), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .nether_brick), 4.0);
    try std.testing.expectEqual(footstepType(.nether_brick), .stone);

    const tex = BlockId.nether_brick.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 4);
    try std.testing.expectEqual(tex.y, 1);
}

test "nether brick fence block properties and textures" {
    try std.testing.expect(BlockId.nether_brick_fence.is_solid());
    try std.testing.expect(BlockId.nether_brick_fence.is_transparent());
    try std.testing.expect(!BlockId.nether_brick_fence.is_fluid());
    try std.testing.expectEqual(hardness(.nether_brick_fence), 2.0);
    try std.testing.expectEqual(requiredTier(.nether_brick_fence), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .nether_brick_fence), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .nether_brick_fence), 4.0);
    try std.testing.expectEqual(footstepType(.nether_brick_fence), .stone);

    const tex = BlockId.nether_brick_fence.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 5);
    try std.testing.expectEqual(tex.y, 1);
}

test "crimson and warped fungi properties and textures" {
    try std.testing.expect(!BlockId.crimson_fungus.is_solid());
    try std.testing.expect(BlockId.crimson_fungus.is_transparent());
    try std.testing.expect(BlockId.crimson_fungus.is_fungus());
    try std.testing.expect(BlockId.crimson_fungus.isFlammable());
    try std.testing.expectEqual(hardness(.crimson_fungus), 0.0);
    try std.testing.expectEqual(requiredTier(.crimson_fungus), .hand);
    try std.testing.expectEqual(footstepType(.crimson_fungus), .grass);

    try std.testing.expect(!BlockId.warped_fungus.is_solid());
    try std.testing.expect(BlockId.warped_fungus.is_transparent());
    try std.testing.expect(BlockId.warped_fungus.is_fungus());
    try std.testing.expect(BlockId.warped_fungus.isFlammable());
    try std.testing.expectApproxEqAbs(BlockId.warped_fungus.emissive(), 0.35, 0.001);

    const cr_tex = BlockId.crimson_fungus.getFaceTexture(0);
    try std.testing.expectEqual(cr_tex.x, 6);
    try std.testing.expectEqual(cr_tex.y, 1);
    const wa_tex = BlockId.warped_fungus.getFaceTexture(0);
    try std.testing.expectEqual(wa_tex.x, 7);
    try std.testing.expectEqual(wa_tex.y, 1);
}

test "hay bale properties, cushioning, and textures" {
    try std.testing.expect(BlockId.hay_bale.is_solid());
    try std.testing.expect(!BlockId.hay_bale.is_transparent());
    try std.testing.expect(BlockId.hay_bale.is_hay_bale());
    try std.testing.expect(BlockId.hay_bale.isFlammable());
    try std.testing.expectEqual(hardness(.hay_bale), 0.5);
    try std.testing.expectEqual(requiredTier(.hay_bale), .hand);
    try std.testing.expectEqual(footstepType(.hay_bale), .grass);

    const top_tex = BlockId.hay_bale.getFaceTexture(0);
    try std.testing.expectEqual(top_tex.x, 1);
    try std.testing.expectEqual(top_tex.y, 4);
    const side_tex = BlockId.hay_bale.getFaceTexture(2);
    try std.testing.expectEqual(side_tex.x, 0);
    try std.testing.expectEqual(side_tex.y, 3);
}

test "target block properties and textures" {
    try std.testing.expect(BlockId.target_block.is_solid());
    try std.testing.expect(!BlockId.target_block.is_transparent());
    try std.testing.expect(BlockId.target_block.is_target_block());
    try std.testing.expect(BlockId.target_block.isFlammable());
    try std.testing.expectEqual(hardness(.target_block), 0.6);
    try std.testing.expectEqual(requiredTier(.target_block), .hand);
    try std.testing.expectEqual(footstepType(.target_block), .wood);

    const tex = BlockId.target_block.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 3);
    try std.testing.expectEqual(tex.y, 3);
}

test "twisting vines block properties, climbing, and cyan glow" {
    try std.testing.expect(!BlockId.twisting_vines.is_solid());
    try std.testing.expect(BlockId.twisting_vines.is_transparent());
    try std.testing.expect(BlockId.twisting_vines.is_ladder());
    try std.testing.expect(BlockId.twisting_vines.is_twisting_vines());
    try std.testing.expectApproxEqAbs(BlockId.twisting_vines.emissive(), 0.4, 0.001);
    try std.testing.expectEqual(hardness(.twisting_vines), 0.2);
    try std.testing.expectEqual(requiredTier(.twisting_vines), .hand);
    try std.testing.expectEqual(footstepType(.twisting_vines), .grass);

    const tex = BlockId.twisting_vines.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 7);
    try std.testing.expectEqual(tex.y, 1);
}

test "weeping vines block properties, climbing, and emissive glow" {
    try std.testing.expect(!BlockId.weeping_vines.is_solid());
    try std.testing.expect(BlockId.weeping_vines.is_transparent());
    try std.testing.expect(BlockId.weeping_vines.is_ladder());
    try std.testing.expect(BlockId.weeping_vines.is_weeping_vines());
    try std.testing.expectApproxEqAbs(BlockId.weeping_vines.emissive(), 0.35, 0.001);
    try std.testing.expectEqual(hardness(.weeping_vines), 0.2);
    try std.testing.expectEqual(requiredTier(.weeping_vines), .hand);
    try std.testing.expectEqual(footstepType(.weeping_vines), .grass);

    const tex = BlockId.weeping_vines.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 6);
    try std.testing.expectEqual(tex.y, 1);
}

test "nether wart block properties and textures" {
    try std.testing.expect(!BlockId.nether_wart.is_solid());
    try std.testing.expect(BlockId.nether_wart.is_transparent());
    try std.testing.expect(!BlockId.nether_wart.is_fluid());
    try std.testing.expectEqual(hardness(.nether_wart), 0.3);
    try std.testing.expectEqual(requiredTier(.nether_wart), .hand);

    const tex = BlockId.nether_wart.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 6);
    try std.testing.expectEqual(tex.y, 1);
}

test "soul torch properties and cyan emissive" {
    try std.testing.expect(!BlockId.soul_torch.is_solid());
    try std.testing.expect(BlockId.soul_torch.is_transparent());
    try std.testing.expectApproxEqAbs(BlockId.soul_torch.emissive(), 0.7, 0.001);
    const tex = BlockId.soul_torch.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 7);
    try std.testing.expectEqual(tex.y, 1);
}

test "soul campfire properties and cyan emissive" {
    try std.testing.expect(BlockId.soul_campfire.is_campfire());
    try std.testing.expect(!BlockId.soul_campfire.is_solid());
    try std.testing.expect(BlockId.soul_campfire.is_transparent());
    try std.testing.expectApproxEqAbs(BlockId.soul_campfire.emissive(), 0.8, 0.001);
    const tex = BlockId.soul_campfire.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 4);
    try std.testing.expectEqual(tex.y, 0);
}

test "spawner cage properties and texture" {
    try std.testing.expect(BlockId.spawner_cage.is_solid());
    try std.testing.expect(BlockId.spawner_cage.is_transparent());
    try std.testing.expectApproxEqAbs(BlockId.spawner_cage.emissive(), 0.6, 0.001);
    try std.testing.expectEqual(hardness(BlockId.spawner_cage), 5.0);
    const tex = BlockId.spawner_cage.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 5);
    try std.testing.expectEqual(tex.y, 0);
}

test "shroomlight block definition, properties, and emissive" {
    try std.testing.expect(BlockId.shroomlight.is_solid());
    try std.testing.expect(!BlockId.shroomlight.is_transparent());
    try std.testing.expect(BlockId.shroomlight.isFlammable());
    try std.testing.expectApproxEqAbs(BlockId.shroomlight.emissive(), 1.0, 0.001);
    try std.testing.expectEqual(hardness(.shroomlight), 1.0);
    try std.testing.expectEqual(requiredTier(.shroomlight), .hand);
    try std.testing.expectEqual(footstepType(.shroomlight), .grass);

    const tex = BlockId.shroomlight.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 5);
    try std.testing.expectEqual(tex.y, 3);
}


test "chiseled nether brick properties and textures" {
    try std.testing.expect(BlockId.chiseled_nether_brick.is_solid());
    try std.testing.expect(!BlockId.chiseled_nether_brick.is_transparent());
    try std.testing.expect(!BlockId.chiseled_nether_brick.is_fluid());
    try std.testing.expectEqual(hardness(.chiseled_nether_brick), 2.0);
    try std.testing.expectEqual(requiredTier(.chiseled_nether_brick), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .chiseled_nether_brick), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .chiseled_nether_brick), 4.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .chiseled_nether_brick), 6.0);
    try std.testing.expectEqual(footstepType(.chiseled_nether_brick), .stone);

    const tex = BlockId.chiseled_nether_brick.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 5);
    try std.testing.expectEqual(tex.y, 1);
}

test "dispenser block properties and textures" {
    try std.testing.expect(BlockId.dispenser.is_solid());
    try std.testing.expect(!BlockId.dispenser.is_transparent());
    try std.testing.expect(!BlockId.dispenser.is_fluid());
    try std.testing.expectEqual(hardness(.dispenser), 3.5);
    try std.testing.expectEqual(requiredTier(.dispenser), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .dispenser), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .dispenser), 4.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .dispenser), 6.0);
    try std.testing.expectEqual(footstepType(.dispenser), .stone);

    const front_tex = BlockId.dispenser.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 0), front_tex.x);
    try std.testing.expectEqual(@as(u32, 5), front_tex.y);
    const side_tex = BlockId.dispenser.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 1), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "dropper block properties and textures" {
    try std.testing.expect(BlockId.dropper.is_solid());
    try std.testing.expect(!BlockId.dropper.is_transparent());
    try std.testing.expect(!BlockId.dropper.is_fluid());
    try std.testing.expectEqual(hardness(.dropper), 3.5);
    try std.testing.expectEqual(requiredTier(.dropper), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .dropper), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .dropper), 4.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .dropper), 6.0);
    try std.testing.expectEqual(footstepType(.dropper), .stone);

    const front_tex = BlockId.dropper.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 1), front_tex.x);
    try std.testing.expectEqual(@as(u32, 5), front_tex.y);
    const side_tex = BlockId.dropper.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 1), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "hopper block properties and textures" {
    try std.testing.expect(BlockId.hopper.is_solid());
    try std.testing.expect(!BlockId.hopper.is_transparent());
    try std.testing.expect(!BlockId.hopper.is_fluid());
    try std.testing.expectEqual(hardness(.hopper), 3.0);
    try std.testing.expectEqual(requiredTier(.hopper), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .hopper), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .hopper), 4.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .hopper), 6.0);
    try std.testing.expectEqual(footstepType(.hopper), .stone);

    const top_tex = BlockId.hopper.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), top_tex.x);
    try std.testing.expectEqual(@as(u32, 3), top_tex.y);
    const side_tex = BlockId.hopper.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 0), side_tex.x);
    try std.testing.expectEqual(@as(u32, 2), side_tex.y);
}

test "brewing stand block properties and textures" {
    try std.testing.expect(!BlockId.brewing_stand.is_solid());
    try std.testing.expect(BlockId.brewing_stand.is_transparent());
    try std.testing.expect(!BlockId.brewing_stand.is_fluid());
    try std.testing.expectEqual(hardness(.brewing_stand), 2.0);
    try std.testing.expectEqual(requiredTier(.brewing_stand), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .brewing_stand), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .brewing_stand), 4.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .brewing_stand), 6.0);
    try std.testing.expectEqual(footstepType(.brewing_stand), .stone);
    try std.testing.expectApproxEqAbs(BlockId.brewing_stand.emissive(), 0.4, 0.001);

    const top_tex = BlockId.brewing_stand.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 5), top_tex.x);
    try std.testing.expectEqual(@as(u32, 2), top_tex.y);
    const side_tex = BlockId.brewing_stand.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 1), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "cauldron block properties and textures" {
    try std.testing.expect(BlockId.cauldron.is_solid());
    try std.testing.expect(!BlockId.cauldron.is_transparent());
    try std.testing.expect(!BlockId.cauldron.is_fluid());
    try std.testing.expectEqual(hardness(.cauldron), 2.0);
    try std.testing.expectEqual(requiredTier(.cauldron), .wooden);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_PICKAXE, .cauldron), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_PICKAXE, .cauldron), 4.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_PICKAXE, .cauldron), 6.0);
    try std.testing.expectEqual(footstepType(.cauldron), .stone);

    const top_tex = BlockId.cauldron.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), top_tex.x);
    try std.testing.expectEqual(@as(u32, 3), top_tex.y);
    const side_tex = BlockId.cauldron.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 0), side_tex.x);
    try std.testing.expectEqual(@as(u32, 2), side_tex.y);
}

test "daylight detector block properties and textures" {
    try std.testing.expect(BlockId.daylight_detector.is_solid());
    try std.testing.expect(!BlockId.daylight_detector.is_transparent());
    try std.testing.expect(!BlockId.daylight_detector.is_fluid());
    try std.testing.expectEqual(hardness(.daylight_detector), 0.2);
    try std.testing.expectEqual(footstepType(.daylight_detector), .wood);

    const day_top = BlockId.daylight_detector.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 3), day_top.x);
    try std.testing.expectEqual(@as(u32, 7), day_top.y);

    const night_top = BlockId.daylight_detector_inverted.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), night_top.x);
    try std.testing.expectEqual(@as(u32, 1), night_top.y);
}

test "note block block properties and textures" {
    try std.testing.expect(BlockId.note_block.is_solid());
    try std.testing.expect(!BlockId.note_block.is_transparent());
    try std.testing.expect(!BlockId.note_block.is_fluid());
    try std.testing.expectEqual(hardness(.note_block), 0.8);
    try std.testing.expectEqual(footstepType(.note_block), .wood);
    try std.testing.expect(BlockId.note_block.isFlammable());

    const top_tex = BlockId.note_block.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 2), top_tex.x);
    try std.testing.expectEqual(@as(u32, 2), top_tex.y);

    const side_tex = BlockId.note_block.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 4), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "jukebox block properties and textures" {
    try std.testing.expect(BlockId.jukebox.is_solid());
    try std.testing.expect(!BlockId.jukebox.is_transparent());
    try std.testing.expect(!BlockId.jukebox.is_fluid());
    try std.testing.expectEqual(hardness(.jukebox), 2.0);
    try std.testing.expectEqual(footstepType(.jukebox), .wood);
    try std.testing.expect(BlockId.jukebox.isFlammable());

    const top_tex = BlockId.jukebox.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 6), top_tex.x);
    try std.testing.expectEqual(@as(u32, 3), top_tex.y);

    const side_tex = BlockId.jukebox.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 4), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "oak fence block properties and textures" {
    try std.testing.expect(BlockId.oak_fence.is_solid());
    try std.testing.expect(BlockId.oak_fence.is_transparent());
    try std.testing.expect(!BlockId.oak_fence.is_fluid());
    try std.testing.expect(BlockId.oak_fence.is_fence());
    try std.testing.expect(BlockId.nether_brick_fence.is_fence());
    try std.testing.expectEqual(hardness(.oak_fence), 2.0);
    try std.testing.expectEqual(footstepType(.oak_fence), .wood);
    try std.testing.expect(BlockId.oak_fence.isFlammable());

    const tex = BlockId.oak_fence.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 2), tex.x);
    try std.testing.expectEqual(@as(u32, 2), tex.y);
}

test "armor stand block properties and textures" {
    try std.testing.expect(BlockId.armor_stand.is_solid());
    try std.testing.expect(BlockId.armor_stand.is_transparent());
    try std.testing.expect(!BlockId.armor_stand.is_fluid());
    try std.testing.expectEqual(hardness(.armor_stand), 1.0);
    try std.testing.expectEqual(footstepType(.armor_stand), .wood);
    try std.testing.expect(BlockId.armor_stand.isFlammable());

    const bot_tex = BlockId.armor_stand.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 0), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 0), bot_tex.y);

    const side_tex = BlockId.armor_stand.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 2), side_tex.x);
    try std.testing.expectEqual(@as(u32, 2), side_tex.y);
}

test "enchantment table block properties and textures" {
    try std.testing.expect(BlockId.enchantment_table.is_solid());
    try std.testing.expect(BlockId.enchantment_table.is_transparent());
    try std.testing.expect(!BlockId.enchantment_table.is_fluid());
    try std.testing.expectEqual(hardness(.enchantment_table), 5.0);
    try std.testing.expectEqual(requiredTier(.enchantment_table), .wooden);
    try std.testing.expectEqual(footstepType(.enchantment_table), .stone);
    try std.testing.expectApproxEqAbs(BlockId.enchantment_table.emissive(), 0.5, 0.001);

    const top_tex = BlockId.enchantment_table.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 6), top_tex.x);
    try std.testing.expectEqual(@as(u32, 2), top_tex.y);

    const bot_tex = BlockId.enchantment_table.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 5), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.y);

    const side_tex = BlockId.enchantment_table.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 6), side_tex.x);
    try std.testing.expectEqual(@as(u32, 0), side_tex.y);
}

test "anvil block properties, falling classification, and forged textures" {
    try std.testing.expect(BlockId.anvil.is_solid());
    try std.testing.expect(BlockId.anvil.is_transparent());
    try std.testing.expect(!BlockId.anvil.is_fluid());
    try std.testing.expect(BlockId.anvil.is_falling());
    try std.testing.expect(BlockId.sand.is_falling());
    try std.testing.expect(!BlockId.stone.is_falling());
    try std.testing.expectEqual(hardness(.anvil), 5.0);
    try std.testing.expectEqual(requiredTier(.anvil), .wooden);
    try std.testing.expectEqual(footstepType(.anvil), .stone);

    const top_tex = BlockId.anvil.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 1), top_tex.x);
    try std.testing.expectEqual(@as(u32, 1), top_tex.y);

    const bot_tex = BlockId.anvil.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 0), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.y);

    const side_tex = BlockId.anvil.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 2), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "grindstone block properties and textures" {
    try std.testing.expect(BlockId.grindstone.is_solid());
    try std.testing.expect(BlockId.grindstone.is_transparent());
    try std.testing.expect(!BlockId.grindstone.is_fluid());
    try std.testing.expect(!BlockId.grindstone.is_falling());
    try std.testing.expectEqual(hardness(.grindstone), 2.0);
    try std.testing.expectEqual(requiredTier(.grindstone), .wooden);
    try std.testing.expectEqual(footstepType(.grindstone), .stone);

    const top_tex = BlockId.grindstone.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 1), top_tex.x);
    try std.testing.expectEqual(@as(u32, 1), top_tex.y);

    const bot_tex = BlockId.grindstone.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.y);

    const side_tex = BlockId.grindstone.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 0), side_tex.x);
    try std.testing.expectEqual(@as(u32, 0), side_tex.y);
}

test "smithing table block properties and textures" {
    try std.testing.expect(BlockId.smithing_table.is_solid());
    try std.testing.expect(!BlockId.smithing_table.is_transparent());
    try std.testing.expect(!BlockId.smithing_table.is_fluid());
    try std.testing.expect(BlockId.smithing_table.isFlammable());
    try std.testing.expectEqual(hardness(.smithing_table), 2.5);
    try std.testing.expectEqual(requiredTier(.smithing_table), .hand);
    try std.testing.expectEqual(footstepType(.smithing_table), .wood);

    const top_tex = BlockId.smithing_table.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 2), top_tex.x);
    try std.testing.expectEqual(@as(u32, 4), top_tex.y);

    const bot_tex = BlockId.smithing_table.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.y);

    const side_tex = BlockId.smithing_table.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 3), side_tex.x);
    try std.testing.expectEqual(@as(u32, 4), side_tex.y);
}

test "cartography table block properties and textures" {
    try std.testing.expect(BlockId.cartography_table.is_solid());
    try std.testing.expect(!BlockId.cartography_table.is_transparent());
    try std.testing.expect(!BlockId.cartography_table.is_fluid());
    try std.testing.expect(BlockId.cartography_table.isFlammable());
    try std.testing.expectEqual(hardness(.cartography_table), 2.5);
    try std.testing.expectEqual(requiredTier(.cartography_table), .hand);
    try std.testing.expectEqual(footstepType(.cartography_table), .wood);

    const top_tex = BlockId.cartography_table.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 3), top_tex.x);
    try std.testing.expectEqual(@as(u32, 7), top_tex.y);

    const bot_tex = BlockId.cartography_table.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.y);

    const side_tex = BlockId.cartography_table.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 4), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "fletching table block properties and textures" {
    try std.testing.expect(BlockId.fletching_table.is_solid());
    try std.testing.expect(!BlockId.fletching_table.is_transparent());
    try std.testing.expect(!BlockId.fletching_table.is_fluid());
    try std.testing.expect(BlockId.fletching_table.isFlammable());
    try std.testing.expectEqual(hardness(.fletching_table), 2.5);
    try std.testing.expectEqual(requiredTier(.fletching_table), .hand);
    try std.testing.expectEqual(footstepType(.fletching_table), .wood);

    const top_tex = BlockId.fletching_table.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 3), top_tex.x);
    try std.testing.expectEqual(@as(u32, 3), top_tex.y);

    const bot_tex = BlockId.fletching_table.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.y);

    const side_tex = BlockId.fletching_table.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 4), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "composter block properties and textures" {
    try std.testing.expect(BlockId.composter.is_solid());
    try std.testing.expect(BlockId.composter.is_transparent());
    try std.testing.expect(!BlockId.composter.is_fluid());
    try std.testing.expect(BlockId.composter.isFlammable());
    try std.testing.expectEqual(hardness(.composter), 0.6);
    try std.testing.expectEqual(requiredTier(.composter), .hand);
    try std.testing.expectEqual(footstepType(.composter), .wood);

    const top_tex = BlockId.composter.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 1), top_tex.x);
    try std.testing.expectEqual(@as(u32, 4), top_tex.y);

    const bot_tex = BlockId.composter.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.y);

    const side_tex = BlockId.composter.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 0), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "loom block properties and textures" {
    try std.testing.expect(BlockId.loom.is_solid());
    try std.testing.expect(!BlockId.loom.is_transparent());
    try std.testing.expect(!BlockId.loom.is_fluid());
    try std.testing.expect(BlockId.loom.isFlammable());
    try std.testing.expectEqual(hardness(.loom), 2.5);
    try std.testing.expectEqual(requiredTier(.loom), .hand);
    try std.testing.expectEqual(footstepType(.loom), .wood);

    const top_tex = BlockId.loom.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), top_tex.x);
    try std.testing.expectEqual(@as(u32, 4), top_tex.y);

    const bot_tex = BlockId.loom.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 2), bot_tex.y);

    const side_tex = BlockId.loom.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 4), side_tex.x);
    try std.testing.expectEqual(@as(u32, 3), side_tex.y);
}

test "chain block properties and textures" {
    try std.testing.expect(!BlockId.chain.is_solid());
    try std.testing.expect(BlockId.chain.is_transparent());
    try std.testing.expect(!BlockId.chain.is_fluid());
    try std.testing.expectEqual(hardness(.chain), 5.0);
    try std.testing.expectEqual(requiredTier(.chain), .wooden);
    try std.testing.expectEqual(footstepType(.chain), .stone);
    const top_tex = BlockId.chain.getFaceTexture(0);
    try std.testing.expectEqual(@as(u8, 1), top_tex.x);
    try std.testing.expectEqual(@as(u8, 2), top_tex.y);
    const bot_tex = BlockId.chain.getFaceTexture(1);
    try std.testing.expectEqual(@as(u8, 1), bot_tex.x);
    try std.testing.expectEqual(@as(u8, 2), bot_tex.y);
    const side_tex = BlockId.chain.getFaceTexture(2);
    try std.testing.expectEqual(@as(u8, 2), side_tex.x);
    try std.testing.expectEqual(@as(u8, 2), side_tex.y);
}

test "soul_lantern block properties, emissive, and textures" {
    try std.testing.expect(!BlockId.soul_lantern.is_solid());
    try std.testing.expect(BlockId.soul_lantern.is_transparent());
    try std.testing.expect(!BlockId.soul_lantern.is_fluid());
    try std.testing.expectEqual(BlockId.soul_lantern.emissive(), 0.75);
    try std.testing.expectEqual(hardness(.soul_lantern), 3.5);
    try std.testing.expectEqual(requiredTier(.soul_lantern), .wooden);
    try std.testing.expectEqual(footstepType(.soul_lantern), .stone);
    const top_tex = BlockId.soul_lantern.getFaceTexture(0);
    try std.testing.expectEqual(@as(u8, 0), top_tex.x);
    try std.testing.expectEqual(@as(u8, 2), top_tex.y);
    const bot_tex = BlockId.soul_lantern.getFaceTexture(1);
    try std.testing.expectEqual(@as(u8, 0), bot_tex.x);
    try std.testing.expectEqual(@as(u8, 2), bot_tex.y);
    const side_tex = BlockId.soul_lantern.getFaceTexture(2);
    try std.testing.expectEqual(@as(u8, 7), side_tex.x);
    try std.testing.expectEqual(@as(u8, 6), side_tex.y);
}

test "lantern block properties, emissive, and textures" {
    try std.testing.expect(!BlockId.lantern.is_solid());
    try std.testing.expect(BlockId.lantern.is_transparent());
    try std.testing.expect(!BlockId.lantern.is_fluid());
    try std.testing.expectEqual(BlockId.lantern.emissive(), 0.95);
    try std.testing.expectEqual(hardness(.lantern), 3.5);
    try std.testing.expectEqual(requiredTier(.lantern), .wooden);
    try std.testing.expectEqual(footstepType(.lantern), .stone);
    const top_tex = BlockId.lantern.getFaceTexture(0);
    try std.testing.expectEqual(@as(u8, 0), top_tex.x);
    try std.testing.expectEqual(@as(u8, 2), top_tex.y);
    const bot_tex = BlockId.lantern.getFaceTexture(1);
    try std.testing.expectEqual(@as(u8, 0), bot_tex.x);
    try std.testing.expectEqual(@as(u8, 2), bot_tex.y);
    const side_tex = BlockId.lantern.getFaceTexture(2);
    try std.testing.expectEqual(@as(u8, 6), side_tex.x);
    try std.testing.expectEqual(@as(u8, 6), side_tex.y);
}

test "stonecutter block properties and textures" {
    try std.testing.expect(BlockId.stonecutter.is_solid());
    try std.testing.expect(BlockId.stonecutter.is_transparent());
    try std.testing.expect(!BlockId.stonecutter.is_fluid());
    try std.testing.expectEqual(hardness(.stonecutter), 3.5);
    try std.testing.expectEqual(requiredTier(.stonecutter), .wooden);
    try std.testing.expectEqual(footstepType(.stonecutter), .stone);
    const top_tex = BlockId.stonecutter.getFaceTexture(0);
    try std.testing.expectEqual(@as(u8, 1), top_tex.x);
    try std.testing.expectEqual(@as(u8, 1), top_tex.y);
    const bot_tex = BlockId.stonecutter.getFaceTexture(1);
    try std.testing.expectEqual(@as(u8, 0), bot_tex.x);
    try std.testing.expectEqual(@as(u8, 0), bot_tex.y);
    const side_tex = BlockId.stonecutter.getFaceTexture(2);
    try std.testing.expectEqual(@as(u8, 1), side_tex.x);
    try std.testing.expectEqual(@as(u8, 3), side_tex.y);
}

test "blast_furnace block properties and textures" {
    try std.testing.expect(BlockId.blast_furnace.is_solid());
    try std.testing.expect(!BlockId.blast_furnace.is_transparent());
    try std.testing.expect(!BlockId.blast_furnace.is_fluid());
    try std.testing.expectEqual(hardness(.blast_furnace), 3.5);
    try std.testing.expectEqual(requiredTier(.blast_furnace), .wooden);
    try std.testing.expectEqual(footstepType(.blast_furnace), .stone);
    const top_tex = BlockId.blast_furnace.getFaceTexture(0);
    try std.testing.expectEqual(@as(u8, 0), top_tex.x);
    try std.testing.expectEqual(@as(u8, 0), top_tex.y);
    const bot_tex = BlockId.blast_furnace.getFaceTexture(1);
    try std.testing.expectEqual(@as(u8, 0), bot_tex.x);
    try std.testing.expectEqual(@as(u8, 0), bot_tex.y);
    const side_tex = BlockId.blast_furnace.getFaceTexture(2);
    try std.testing.expectEqual(@as(u8, 0), side_tex.x);
    try std.testing.expectEqual(@as(u8, 5), side_tex.y);
}

test "smoker block properties and textures" {
    try std.testing.expect(BlockId.smoker.is_solid());
    try std.testing.expect(!BlockId.smoker.is_transparent());
    try std.testing.expect(!BlockId.smoker.is_fluid());
    try std.testing.expectEqual(hardness(.smoker), 3.5);
    try std.testing.expectEqual(requiredTier(.smoker), .wooden);
    try std.testing.expectEqual(footstepType(.smoker), .stone);

    const top_tex = BlockId.smoker.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 1), top_tex.x);
    try std.testing.expectEqual(@as(u32, 5), top_tex.y);

    const bot_tex = BlockId.smoker.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 0), bot_tex.x);
    try std.testing.expectEqual(@as(u32, 0), bot_tex.y);

    const side_tex = BlockId.smoker.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 0), side_tex.x);
    try std.testing.expectEqual(@as(u32, 5), side_tex.y);
}

/// A lantern can be placed either resting on top of a solid block (floor support, y-1 solid)
/// or hanging suspended from a solid block above (ceiling support, y+1 solid).
pub fn canSupportLantern(lookup: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, y: i32, z: i32) bool {
    const below = lookup(x, y - 1, z);
    if (below.is_solid()) return true;
    const above = lookup(x, y + 1, z);
    if (above.is_solid() or above == .chain) return true;
    return false;
}

test "canSupportLantern standing and hanging physics" {
    const mock = struct {
        fn getFloor(x: i32, y: i32, z: i32) BlockId {
            _ = x;
            _ = z;
            if (y == 4) return .stone;
            return .air;
        }
        fn getCeil(x: i32, y: i32, z: i32) BlockId {
            _ = x;
            _ = z;
            if (y == 6) return .stone;
            return .air;
        }
        fn getVoid(x: i32, y: i32, z: i32) BlockId {
            _ = x;
            _ = y;
            _ = z;
            return .air;
        }
    };
    // Standing on floor (y=5, y-1=4 stone) -> supported
    try std.testing.expect(canSupportLantern(&mock.getFloor, 0, 5, 0));
    // Hanging from ceiling (y=5, y+1=6 stone) -> supported
    try std.testing.expect(canSupportLantern(&mock.getCeil, 0, 5, 0));
    // Free floating in air -> unsupported
    try std.testing.expect(!canSupportLantern(&mock.getVoid, 0, 5, 0));
}
