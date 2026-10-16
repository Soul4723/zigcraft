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
    iron_bars = 100,
    tripwire_hook_off = 101,
    tripwire_hook_on = 102,
    cobweb = 103,
    end_stone = 104,
    end_portal_frame = 105,
    end_portal_frame_filled = 106,
    end_portal = 107,
    end_crystal = 108,
    dragon_egg = 109,
    purpur_block = 110,
    purpur_pillar = 111,
    end_rod = 112,
    chorus_plant = 113,
    chorus_flower = 114,
    shulker_box = 115,
    dragon_head = 116,
    end_gateway = 117,
    prismarine = 118,
    prismarine_bricks = 119,
    dark_prismarine = 120,
    sea_lantern = 121,
    conduit = 122,
    sponge = 123,
    wet_sponge = 124,
    kelp = 125,
    dried_kelp_block = 126,
    sea_pickle = 127,
    rail = 128,
    powered_rail = 129,
    detector_rail = 130,
    activator_rail = 131,
    redstone_comparator_off = 132,
    redstone_comparator_on = 133,
    slime_block = 134,
    piston = 135,
    sticky_piston = 136,
    piston_head = 137,
    observer_off = 138,
    observer_on = 139,
    wooden_trapdoor_closed = 140,
    wooden_trapdoor_open = 141,
    iron_trapdoor_closed = 142,
    iron_trapdoor_open = 143,
    redstone_block = 144,
    redstone_ore = 145,
    lit_redstone_ore = 146,
    tripwire = 147,
    gold_ore = 148,
    gold_block = 149,
    diamond_ore = 150,
    diamond_block = 151,
    farmland = 152,
    wheat_crop = 153,
    bookshelf = 154,
    lectern = 155,
    emerald_ore = 156,
    emerald_block = 157,
    lapis_ore = 158,
    lapis_block = 159,
    beehive = 160,
    honey_block = 161,
    copper_ore = 162,
    copper_block = 163,
    exposed_copper = 164,
    weathered_copper = 165,
    oxidized_copper = 166,
    waxed_copper_block = 167,
    lightning_rod = 168,
    amethyst_block = 169,
    budding_amethyst = 170,
    amethyst_cluster = 171,
    tinted_glass = 172,
    bell = 173,
    sugar_cane = 174,
    pumpkin = 175,
    carved_pumpkin = 176,
    jack_o_lantern = 177,
    sculk = 178,
    sculk_sensor_off = 179,
    sculk_sensor_on = 180,
    deepslate = 181,
    cobbled_deepslate = 182,
    polished_deepslate = 183,
    deepslate_bricks = 184,
    iron_block = 185,
    cake = 186,
    melon = 187,
    barrel = 188,
    dripstone_block = 189,
    pointed_dripstone = 190,
    moss_block = 191,
    moss_carpet = 192,
    cave_vines = 193,
    cave_vines_lit = 194,
    clay = 195,
    terracotta = 196,
    flower_pot = 197,
    ice = 198,
    packed_ice = 199,
    blue_ice = 200,
    powder_snow = 201,
    bamboo = 202,
    scaffolding = 203,
    sweet_berry_bush = 204,
    ender_chest = 205,
    mud = 206,
    packed_mud = 207,
    mud_bricks = 208,
    copper_bulb_off = 209,
    copper_bulb_on = 210,
    chiseled_copper = 211,
    copper_grate = 212,
    suspicious_sand = 213,
    decorated_pot = 214,
    heavy_core = 215,
    crafter = 216,
    trial_spawner = 217,
    vault = 218,
    tuff = 219,
    polished_tuff = 220,
    tuff_bricks = 221,
    chiseled_tuff = 222,

    pub fn is_solid(self: BlockId) bool {
        return self != .air and self != .water and self != .lava and self != .ladder and self != .torch and self != .wooden_door_open and self != .iron_door_open and self != .wooden_trapdoor_open and self != .iron_trapdoor_open and self != .pressure_plate_up and self != .pressure_plate_down and self != .redstone_wire_off and self != .redstone_wire_on and self != .lever_off and self != .lever_on and self != .repeater_off and self != .repeater_on and self != .redstone_torch_off and self != .redstone_torch_on and self != .campfire and self != .nether_portal and self != .end_portal and self != .nether_wart and self != .soul_torch and self != .soul_campfire and self != .wither_skull_block and self != .weeping_vines and self != .twisting_vines and self != .crimson_fungus and self != .warped_fungus and self != .brewing_stand and self != .lantern and self != .soul_lantern and self != .chain and self != .iron_bars and self != .tripwire_hook_off and self != .tripwire_hook_on and self != .cobweb and self != .end_crystal and self != .end_rod and self != .chorus_plant and self != .chorus_flower and self != .dragon_head and self != .end_gateway and self != .conduit and self != .kelp and self != .sea_pickle and self != .rail and self != .powered_rail and self != .detector_rail and self != .activator_rail and self != .redstone_comparator_off and self != .redstone_comparator_on and self != .tripwire and self != .wheat_crop and self != .lightning_rod and self != .amethyst_cluster and self != .sugar_cane and self != .moss_carpet and self != .cave_vines and self != .cave_vines_lit and self != .flower_pot and self != .powder_snow and self != .bamboo and self != .scaffolding and self != .sweet_berry_bush;
    }

    pub fn is_sponge(self: BlockId) bool {
        return self == .sponge or self == .wet_sponge;
    }

    pub fn is_campfire(self: BlockId) bool {
        return self == .campfire or self == .soul_campfire;
    }

    pub fn is_spawner(self: BlockId) bool {
        return self == .spawner_cage;
    }

    pub fn is_falling(self: BlockId) bool {
        return self == .sand or self == .anvil or self == .dragon_egg or self == .pointed_dripstone or self == .suspicious_sand;
    }

    pub fn is_cactus(self: BlockId) bool {
        return self == .cactus;
    }

    pub fn is_ladder(self: BlockId) bool {
        return self == .ladder or self == .weeping_vines or self == .twisting_vines or self == .kelp or self == .cave_vines or self == .cave_vines_lit or self == .scaffolding;
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

    pub fn is_slime_block(self: BlockId) bool {
        return self == .slime_block;
    }

    pub fn is_honey_block(self: BlockId) bool {
        return self == .honey_block;
    }

    pub fn is_fungus(self: BlockId) bool {
        return self == .crimson_fungus or self == .warped_fungus;
    }

    pub fn is_fluid(self: BlockId) bool {
        return self == .water or self == .lava;
    }

    pub fn is_rail(self: BlockId) bool {
        return self == .rail or self == .powered_rail or self == .detector_rail or self == .activator_rail;
    }

    pub fn is_transparent(self: BlockId) bool {
        return self == .air or self == .water or self == .lava or self == .glass or self == .ladder or self == .torch or self == .wooden_door_closed or self == .wooden_door_open or self == .iron_door_closed or self == .iron_door_open or self == .pressure_plate_up or self == .pressure_plate_down or self == .redstone_wire_off or self == .redstone_wire_on or self == .lever_off or self == .lever_on or self == .repeater_off or self == .repeater_on or self == .redstone_torch_off or self == .redstone_torch_on or self == .nether_portal or self == .end_portal or self == .nether_brick_fence or self == .oak_fence or self == .armor_stand or self == .enchantment_table or self == .anvil or self == .grindstone or self == .composter or self == .nether_wart or self == .soul_torch or self == .soul_campfire or self == .spawner_cage or self == .wither_skull_block or self == .beacon or self == .weeping_vines or self == .twisting_vines or self == .crimson_fungus or self == .warped_fungus or self == .brewing_stand or self == .stonecutter or self == .lantern or self == .soul_lantern or self == .chain or self == .iron_bars or self == .tripwire_hook_off or self == .tripwire_hook_on or self == .cobweb or self == .end_portal_frame or self == .end_portal_frame_filled or self == .end_crystal or self == .dragon_egg or self == .end_rod or self == .chorus_plant or self == .chorus_flower or self == .shulker_box or self == .dragon_head or self == .end_gateway or self == .conduit or self == .kelp or self == .sea_pickle or self == .rail or self == .powered_rail or self == .detector_rail or self == .activator_rail or self == .redstone_comparator_off or self == .redstone_comparator_on or self == .slime_block or self == .piston_head or self == .wooden_trapdoor_closed or self == .wooden_trapdoor_open or self == .iron_trapdoor_closed or self == .iron_trapdoor_open or self == .tripwire or self == .wheat_crop or self == .lectern or self == .honey_block or self == .lightning_rod or self == .amethyst_cluster or self == .tinted_glass or self == .bell or self == .sugar_cane or self == .sculk_sensor_off or self == .sculk_sensor_on or self == .cake or self == .pointed_dripstone or self == .moss_carpet or self == .cave_vines or self == .cave_vines_lit or self == .flower_pot or self == .ice or self == .powder_snow or self == .bamboo or self == .scaffolding or self == .sweet_berry_bush or self == .ender_chest or self == .copper_grate or self == .decorated_pot or self == .heavy_core or self == .trial_spawner or self == .vault;
    }

    /// 0.0 = lit by sun only. 1.0 = full glow even at midnight.
    /// Covers flame torches, lit redstone lamps, lit redstone torches,
    /// powered wire, and powered repeaters.
    pub fn emissive(self: BlockId) f32 {
        return switch (self) {
            .enchantment_table => 0.5,
            .lantern => 0.95,
            .soul_lantern => 0.75,
            .tripwire_hook_on => 0.4,
            .torch => 0.9,
            .soul_torch => 0.7,
            .soul_campfire => 0.8,
            .spawner_cage => 0.6,
            .redstone_lamp_on => 1.0,
            .redstone_block => 0.65,
            .lit_redstone_ore => 0.55,
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
            .end_portal_frame_filled => 0.8,
            .end_portal => 0.90,
            .end_crystal => 0.85,
            .dragon_egg => 0.35,
            .dragon_head => 0.25,
            .end_gateway => 1.0,
            .sea_lantern => 1.0,
            .conduit => 1.0,
            .end_rod => 0.95,
            .chorus_flower => 0.4,
            .weeping_vines => 0.35,
            .twisting_vines => 0.4,
            .warped_fungus => 0.35,
            .shroomlight => 1.0,
            .brewing_stand => 0.4,
            .sea_pickle => 0.75,
            .powered_rail => 0.6,
            .redstone_comparator_on => 0.65,
            .observer_on => 0.70,
            .lightning_rod => 0.45,
            .amethyst_block => 0.35,
            .budding_amethyst => 0.45,
            .amethyst_cluster => 0.65,
            .bell => 0.30,
            .jack_o_lantern => 0.95,
            .sculk => 0.25,
            .sculk_sensor_off => 0.35,
            .sculk_sensor_on => 0.85,
            .cave_vines_lit => 0.90,
            .blue_ice => 0.15,
            .ender_chest => 0.55,
            .copper_bulb_on => 1.0,
            .trial_spawner => 0.70,
            .vault => 0.65,
            .detector_rail => 0.5,
            .activator_rail => 0.55,
            else => 0.0,
        };
    }

    pub fn isFlammable(self: BlockId) bool {
        return switch (self) {
            .wood, .leaves, .wood_planks, .crafting_table, .wool, .chest, .note_block, .jukebox, .oak_fence, .armor_stand, .smithing_table, .cartography_table, .fletching_table, .composter, .loom, .wooden_door_closed, .wooden_door_open, .wooden_trapdoor_closed, .wooden_trapdoor_open, .pressure_plate_up, .pressure_plate_down, .weeping_vines, .twisting_vines, .target_block, .hay_bale, .crimson_fungus, .warped_fungus, .shroomlight, .dried_kelp_block, .wheat_crop, .bookshelf, .lectern, .beehive, .sugar_cane, .barrel, .moss_block, .moss_carpet, .cave_vines, .cave_vines_lit, .bamboo, .scaffolding, .sweet_berry_bush => true,
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
            .iron_bars => switch (face_idx) {
                0 => .{ .x = 1, .y = 2 }, // Wrought iron bar top post rim
                1 => .{ .x = 1, .y = 2 }, // Wrought iron bar bottom post rim
                else => .{ .x = 5, .y = 0 }, // Vertical iron lattice grating flanks
            },
            .tripwire_hook_off => .{ .x = 3, .y = 6 }, // Slanted brass catch pin & timber bracket
            .tripwire_hook_on => .{ .x = 4, .y = 6 }, // Depressed trip lever & tensioned wire catch
            .tripwire => .{ .x = 5, .y = 6 }, // Thin suspended tripwire strand
            .cobweb => .{ .x = 0, .y = 1 }, // Fine woven silken spider web matrix
            .end_stone => .{ .x = 1, .y = 4 }, // Pale yellowish-ivory cratered stone
            .end_portal_frame => switch (face_idx) {
                0 => .{ .x = 7, .y = 3 }, // Empty decorative brass eye socket basin
                1 => .{ .x = 1, .y = 4 }, // End stone base
                else => .{ .x = 6, .y = 0 }, // Green runic gilded masonry flank
            },
            .end_portal, .end_gateway => .{ .x = 7, .y = 6 }, // Obsidian celestial void starfield vortex
            .prismarine => .{ .x = 7, .y = 1 }, // Aquamarine sea-green rough tile
            .prismarine_bricks => .{ .x = 6, .y = 4 }, // Cyan-teal dressed stone brick tile
            .dark_prismarine => .{ .x = 5, .y = 4 }, // Dark slate-teal carved prismarine
            .sea_lantern => .{ .x = 7, .y = 6 }, // Radiant pearl-white / cyan luminescent sea lantern
            .conduit => .{ .x = 7, .y = 6 }, // Mystic oceanic heart of the sea conduit sphere
            .sponge => .{ .x = 0, .y = 3 }, // Porous golden-yellow cellular sponge
            .wet_sponge => .{ .x = 7, .y = 1 }, // Dark saturated waterlogged sponge
            .kelp => .{ .x = 7, .y = 0 }, // Deep forest-green marine kelp fronds
            .dried_kelp_block => switch (face_idx) {
                0, 1 => .{ .x = 6, .y = 0 }, // Dried bound kelp end grain
                else => .{ .x = 7, .y = 0 }, // Compressed dark olive dried kelp wraps
            },
            .sea_pickle => switch (face_idx) {
                0 => .{ .x = 7, .y = 6 }, // Bioluminescent yellow-green aperture tip
                else => .{ .x = 7, .y = 0 }, // Mottled olive-green colonial tunic flanks
            },
            .rail => switch (face_idx) {
                0, 1 => .{ .x = 1, .y = 2 }, // Metallic track ties and steel running rails
                else => .{ .x = 1, .y = 2 },
            },
            .powered_rail => switch (face_idx) {
                0, 1 => .{ .x = 7, .y = 7 }, // Redstone-infused gold energized rail guide
                else => .{ .x = 7, .y = 7 },
            },
            .detector_rail => switch (face_idx) {
                0, 1 => .{ .x = 4, .y = 6 }, // Steel running rails with redstone pressure contact plate
                else => .{ .x = 4, .y = 6 },
            },
            .activator_rail => switch (face_idx) {
                0, 1 => .{ .x = 6, .y = 7 }, // Redstone torch activated vibrational crossties
                else => .{ .x = 6, .y = 7 },
            },
            .redstone_comparator_off => switch (face_idx) {
                0 => .{ .x = 0, .y = 7 }, // Quartz slab with 3 redstone torches (unlit front)
                else => .{ .x = 0, .y = 7 },
            },
            .redstone_comparator_on => switch (face_idx) {
                0 => .{ .x = 1, .y = 7 }, // Quartz slab with energized redstone torches
                else => .{ .x = 1, .y = 7 },
            },
            .slime_block => .{ .x = 2, .y = 7 }, // Translucent green gelatinous cube
            .piston => switch (face_idx) {
                0 => .{ .x = 3, .y = 7 }, // Wood face piston head
                1 => .{ .x = 0, .y = 1 }, // Cobblestone bottom
                else => .{ .x = 4, .y = 7 }, // Stone mechanical casing
            },
            .sticky_piston => switch (face_idx) {
                0 => .{ .x = 5, .y = 7 }, // Slime coated wood face
                1 => .{ .x = 0, .y = 1 }, // Cobblestone bottom
                else => .{ .x = 4, .y = 7 }, // Stone mechanical casing
            },
            .piston_head => .{ .x = 3, .y = 7 },
            .observer_off => switch (face_idx) {
                2 => .{ .x = 6, .y = 7 }, // Observer front face with optical sensor lens
                3 => .{ .x = 7, .y = 7 }, // Observer back output redstone contact (unlit)
                else => .{ .x = 4, .y = 7 }, // Cobblestone casing
            },
            .observer_on => switch (face_idx) {
                2 => .{ .x = 6, .y = 7 }, // Observer front face with optical sensor lens
                3 => .{ .x = 7, .y = 6 }, // Observer back output redstone contact (lit red pulse)
                else => .{ .x = 4, .y = 7 }, // Cobblestone casing
            },
            .diamond_ore => .{ .x = 4, .y = 2 }, // Stone matrix with radiant cyan-blue diamond crystals
            .diamond_block => .{ .x = 5, .y = 7 }, // Polished crystalline cyan diamond gemstone block
            .farmland => switch (face_idx) {
                0 => .{ .x = 1, .y = 4 }, // Tilled furrow rows top
                else => .{ .x = 2, .y = 0 }, // Rich soil dirt sides and bottom
            },
            .wheat_crop => .{ .x = 0, .y = 3 }, // Golden ripening wheat stalks
            .bookshelf => switch (face_idx) {
                0, 1 => .{ .x = 2, .y = 2 }, // Oak wood planks top and bottom
                else => .{ .x = 4, .y = 3 }, // Bound library books in oak shelving
            },
            .lectern => switch (face_idx) {
                0 => .{ .x = 3, .y = 7 }, // Slanted oak reading desk with open tome
                1 => .{ .x = 2, .y = 2 }, // Oak pedestal base
                else => .{ .x = 4, .y = 3 }, // Carved lectern stand sides
            },
            .emerald_ore => .{ .x = 6, .y = 0 }, // Stone matrix with vibrant green emerald crystals
            .emerald_block => .{ .x = 7, .y = 4 }, // Polished radiant green emerald block
            .lapis_ore => .{ .x = 7, .y = 1 }, // Stone matrix with deep ultramarine lapis veins
            .lapis_block => .{ .x = 0, .y = 1 }, // Polished royal blue lapis lazuli block
            .beehive => switch (face_idx) {
                0, 1 => .{ .x = 2, .y = 2 }, // Oak planks top and bottom
                else => .{ .x = 4, .y = 3 }, // Slatted wooden apiary box sides
            },
            .honey_block => .{ .x = 5, .y = 2 }, // Translucent golden amber honey cube
            .copper_ore => .{ .x = 1, .y = 3 }, // Stone matrix with warm copper & verdigris ore veins
            .copper_block, .waxed_copper_block, .lightning_rod => .{ .x = 4, .y = 4 }, // Burnished copper block & lightning rod
            .exposed_copper => .{ .x = 2, .y = 4 }, // Tarnished rose-brown exposed copper
            .weathered_copper => .{ .x = 6, .y = 4 }, // Green-patinated weathered copper
            .oxidized_copper => .{ .x = 7, .y = 1 }, // Bright turquoise oxidized verdigris copper
            .amethyst_block => .{ .x = 6, .y = 5 }, // Crystalline royal violet amethyst block
            .budding_amethyst => .{ .x = 6, .y = 2 }, // Fractured budding amethyst geode core
            .amethyst_cluster => .{ .x = 7, .y = 6 }, // Radiant violet crystal cluster spires
            .tinted_glass => .{ .x = 0, .y = 4 }, // Amethyst-tinted light-blocking glass
            .bell => switch (face_idx) {
                0 => .{ .x = 2, .y = 2 }, // Oak timber bell yoke top
                else => .{ .x = 4, .y = 7 }, // Cast golden village bell body
            },
            .sugar_cane => .{ .x = 3, .y = 1 }, // Emerald reed stalks
            .pumpkin => switch (face_idx) {
                0, 1 => .{ .x = 1, .y = 4 }, // Ribbed pumpkin stem top/bottom
                else => .{ .x = 5, .y = 3 }, // Orange gourd ribs
            },
            .carved_pumpkin => switch (face_idx) {
                0, 1 => .{ .x = 1, .y = 4 },
                2 => .{ .x = 4, .y = 3 }, // Carved pumpkin face
                else => .{ .x = 5, .y = 3 },
            },
            .jack_o_lantern => switch (face_idx) {
                0, 1 => .{ .x = 1, .y = 4 },
                2 => .{ .x = 5, .y = 2 }, // Glowing carved lantern face
                else => .{ .x = 5, .y = 3 },
            },
            .sculk => .{ .x = 7, .y = 6 }, // Dark abyssal sculk with cyan bioluminescent stars
            .sculk_sensor_off => switch (face_idx) {
                0 => .{ .x = 7, .y = 1 }, // Dormant cyan acoustic tendrils top
                else => .{ .x = 7, .y = 6 }, // Sculk sensor base
            },
            .sculk_sensor_on => switch (face_idx) {
                0 => .{ .x = 7, .y = 6 }, // Energized glowing acoustic tendrils top
                else => .{ .x = 7, .y = 1 }, // Active sculk sensor base
            },
            .deepslate => .{ .x = 5, .y = 4 }, // Stratified dark abyssal deepslate
            .cobbled_deepslate => .{ .x = 2, .y = 5 }, // Fractured dark cobbled deepslate
            .polished_deepslate => .{ .x = 0, .y = 2 }, // Smooth dressed dark deepslate
            .deepslate_bricks => .{ .x = 4, .y = 1 }, // Running-bond dark deepslate bricks
            .iron_block => .{ .x = 1, .y = 1 }, // Gleaming forged block of iron
            .cake => switch (face_idx) {
                0 => .{ .x = 1, .y = 5 }, // White icing with red berry toppings
                1 => .{ .x = 1, .y = 4 }, // Baked sponge base
                else => .{ .x = 3, .y = 3 }, // Layered icing and golden sponge sides
            },
            .melon => switch (face_idx) {
                0, 1 => .{ .x = 6, .y = 0 }, // Melon stem ring top/bottom
                else => .{ .x = 7, .y = 0 }, // Striped green melon rind sides
            },
            .barrel => switch (face_idx) {
                0 => .{ .x = 3, .y = 4 }, // Coopered barrel lid with bung-hole
                1 => .{ .x = 2, .y = 2 }, // Oak barrel base
                else => .{ .x = 4, .y = 3 }, // Iron-hooped oak stave sides
            },
            .dripstone_block => .{ .x = 2, .y = 4 }, // Travertine brown dripstone block
            .pointed_dripstone => .{ .x = 1, .y = 4 }, // Tapered pointed stalactite/stalagmite
            .moss_block, .moss_carpet => .{ .x = 0, .y = 0 }, // Lush emerald cave moss
            .cave_vines => .{ .x = 3, .y = 1 }, // Hanging lush cave vines
            .cave_vines_lit => .{ .x = 5, .y = 2 }, // Bioluminescent glow-berry cave vines
            .clay => .{ .x = 1, .y = 5 }, // Smooth river clay deposit
            .terracotta, .flower_pot => .{ .x = 4, .y = 4 }, // Baked earthen terracotta & clay pot
            .ice => .{ .x = 0, .y = 4 }, // Translucent glacial ice
            .packed_ice, .powder_snow => .{ .x = 1, .y = 5 }, // Dense packed ice & fluffy powder snow
            .blue_ice => .{ .x = 7, .y = 1 }, // Radiant sapphire blue ice
            .bamboo => .{ .x = 3, .y = 1 }, // Segmented green bamboo culm
            .scaffolding => switch (face_idx) {
                0, 1 => .{ .x = 2, .y = 2 }, // Woven bamboo scaffolding deck
                else => .{ .x = 4, .y = 5 }, // Cross-braced bamboo rigging frame
            },
            .sweet_berry_bush => .{ .x = 6, .y = 1 }, // Thorny crimson berry bush
            .ender_chest => switch (face_idx) {
                0, 1 => .{ .x = 1, .y = 2 }, // Obsidian lid & base
                else => .{ .x = 7, .y = 5 }, // Obsidian vault with Eye of Ender clasp
            },
            .mud => .{ .x = 2, .y = 1 }, // Dark saturated mangrove mud
            .packed_mud => .{ .x = 1, .y = 4 }, // Straw-bound packed mud
            .mud_bricks, .decorated_pot => .{ .x = 4, .y = 4 }, // Sun-dried mud bricks & decorated amphora pot
            .copper_bulb_off => .{ .x = 2, .y = 7 }, // Unlit copper bulb lattice
            .copper_bulb_on => .{ .x = 3, .y = 7 }, // Radiant lit copper bulb
            .chiseled_copper => .{ .x = 7, .y = 3 }, // Carved geometric chiseled copper
            .copper_grate => .{ .x = 5, .y = 0 }, // Open-mesh copper ventilation grate
            .suspicious_sand => .{ .x = 3, .y = 3 }, // Coarse artifact-bearing suspicious sand
            .heavy_core => .{ .x = 1, .y = 1 }, // Dense forged metallic Heavy Core
            .crafter => switch (face_idx) {
                0 => .{ .x = 3, .y = 2 }, // Mechanical autocrafting grid top
                1 => .{ .x = 0, .y = 3 }, // Cobblestone base
                else => .{ .x = 1, .y = 5 }, // Redstone-geared crafter casing sides
            },
            .trial_spawner => .{ .x = 5, .y = 0 }, // Copper-bound trial spawner cage
            .vault => .{ .x = 7, .y = 5 }, // Keyhole trial treasure vault
            .tuff => .{ .x = 5, .y = 4 }, // Volcanic ash tuff stone
            .polished_tuff => .{ .x = 0, .y = 2 }, // Smooth polished tuff
            .tuff_bricks => .{ .x = 1, .y = 3 }, // Dressed tuff bricks
            .chiseled_tuff => .{ .x = 7, .y = 3 }, // Carved spiral chiseled tuff
            .gold_ore => .{ .x = 3, .y = 2 }, // Stone matrix with rich golden ore nuggets
            .gold_block => .{ .x = 4, .y = 7 }, // Polished gilded auric gold ingot block
            .redstone_block => .{ .x = 3, .y = 7 }, // Radiant crystalline ruby-red block
            .redstone_ore => .{ .x = 1, .y = 7 }, // Stone matrix with dark ruby redstone ore specks
            .lit_redstone_ore => .{ .x = 2, .y = 7 }, // Stone matrix with glowing scarlet redstone ore specks
            .wooden_trapdoor_closed => .{ .x = 0, .y = 6 },
            .wooden_trapdoor_open => .{ .x = 1, .y = 6 },
            .iron_trapdoor_closed => .{ .x = 2, .y = 6 },
            .iron_trapdoor_open => .{ .x = 3, .y = 6 },
            .dragon_egg => .{ .x = 5, .y = 2 }, // Deep obsidian crystalline egg shell with purple specks
            .dragon_head => switch (face_idx) {
                2 => .{ .x = 7, .y = 3 }, // Draconic horned snout with glowing purple eye
                else => .{ .x = 5, .y = 2 }, // Deep obsidian dragon scale armor
            },
            .chorus_plant => .{ .x = 6, .y = 5 }, // Woody purple segmented tubular plant stem
            .chorus_flower => switch (face_idx) {
                0 => .{ .x = 7, .y = 6 }, // Creamy white-lavender blossom petal crown
                else => .{ .x = 6, .y = 5 }, // Purpur calyx cup sides
            },
            .shulker_box => switch (face_idx) {
                0 => .{ .x = 6, .y = 5 }, // Purpur dome shell top
                1 => .{ .x = 6, .y = 5 }, // Purpur shell bottom
                else => .{ .x = 1, .y = 3 }, // Fluted purpur shell lip & rim
            },
            .purpur_block => .{ .x = 6, .y = 5 }, // Rich royal purple masonry bricks
            .purpur_pillar => switch (face_idx) {
                0, 1 => .{ .x = 6, .y = 5 }, // Purpur pillar cap
                else => .{ .x = 1, .y = 3 }, // Vertical fluted column sides
            },
            .end_rod => switch (face_idx) {
                1 => .{ .x = 6, .y = 5 }, // Purpur footing base
                else => .{ .x = 7, .y = 6 }, // Radiant white glowing crystalline rod core
            },
            .end_crystal => switch (face_idx) {
                0 => .{ .x = 7, .y = 6 }, // Radiant eye crystal core
                1 => .{ .x = 5, .y = 2 }, // Obsidian pedestal base
                else => .{ .x = 6, .y = 6 }, // Glass containment facets
            },
            .end_portal_frame_filled => switch (face_idx) {
                0 => .{ .x = 7, .y = 6 }, // Inserted glowing Eye of Ender socket
                1 => .{ .x = 1, .y = 4 }, // End stone base
                else => .{ .x = 6, .y = 0 }, // Green runic gilded masonry flank
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
pub const TOOL_WOODEN_PICKAXE: u16 = 9;
pub const TOOL_IRON_PICKAXE: u16 = 27;
pub const TOOL_NETHERITE_PICKAXE: u16 = 73;
pub const TOOL_DIAMOND_PICKAXE: u16 = 221;
pub const TOOL_WOODEN_AXE: u16 = 228;
pub const TOOL_IRON_AXE: u16 = 229;
pub const TOOL_DIAMOND_AXE: u16 = 230;
pub const TOOL_NETHERITE_AXE: u16 = 231;
pub const TOOL_WOODEN_SHOVEL: u16 = 232;
pub const TOOL_IRON_SHOVEL: u16 = 233;
pub const TOOL_DIAMOND_SHOVEL: u16 = 234;
pub const TOOL_NETHERITE_SHOVEL: u16 = 235;
pub const TOOL_WOODEN_HOE: u16 = 236;
pub const TOOL_IRON_HOE: u16 = 237;
pub const TOOL_DIAMOND_HOE: u16 = 238;
pub const TOOL_NETHERITE_HOE: u16 = 239;
pub const TOOL_SHEARS: u16 = 240;
pub const TOOL_STONE_SWORD: u16 = 249;
pub const TOOL_STONE_PICKAXE: u16 = 250;
pub const TOOL_STONE_AXE: u16 = 251;
pub const TOOL_STONE_SHOVEL: u16 = 252;
pub const TOOL_STONE_HOE: u16 = 253;
pub const TOOL_GOLDEN_SWORD: u16 = 254;
pub const TOOL_GOLDEN_PICKAXE: u16 = 255;
pub const TOOL_GOLDEN_AXE: u16 = 256;
pub const TOOL_GOLDEN_SHOVEL: u16 = 257;
pub const TOOL_GOLDEN_HOE: u16 = 258;
pub const TOOL_WOODEN_SWORD: u16 = 259;
pub const TOOL_IRON_SWORD: u16 = 31;
pub const TOOL_NETHERITE_SWORD: u16 = 74;
pub const TOOL_DIAMOND_SWORD: u16 = 220;

pub fn hardness(block: BlockId) f32 {
    return switch (block) {
        .air, .water => 0.0,
        .dirt, .grass => 0.45,
        .farmland => 0.6,
        .wheat_crop => 0.0,
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
        .tripwire => 0.0,
        .tnt => 0.0,
        .weeping_vines, .twisting_vines => 0.2,
        .torch => 0.1,
        .soul_torch => 0.1,
        .redstone_torch_off, .redstone_torch_on => 0.0,
        .redstone_wire_off, .redstone_wire_on => 0.0,
        .chest => 1.0,
        .wooden_door_closed, .wooden_door_open, .wooden_trapdoor_closed, .wooden_trapdoor_open, .pressure_plate_up, .pressure_plate_down, .lever_off, .lever_on, .tripwire_hook_off, .tripwire_hook_on => 0.5,
        .repeater_off, .repeater_on, .redstone_comparator_off, .redstone_comparator_on => 0.2,
        .slime_block => 0.0,
        .piston, .sticky_piston, .piston_head => 0.5,
        .observer_off, .observer_on => 3.0,
        .redstone_lamp_off, .redstone_lamp_on => 0.4,
        .redstone_block => 5.0,
        .brick => 2.0,
        .wood => 0.9,
        .leaves => 0.25,
        .wood_planks => 0.9,
        .crafting_table => 0.9,
        .cobblestone => 2.2,
        .stone => 2.5,
        .coal_ore => 3.0,
        .iron_ore => 3.5,
        .diamond_block => 5.0,
        .diamond_ore => 3.0,
        .emerald_ore => 3.0,
        .emerald_block => 5.0,
        .lapis_ore, .lapis_block => 3.0,
        .beehive => 0.6,
        .honey_block => 0.0,
        .copper_ore, .copper_block, .exposed_copper, .weathered_copper, .oxidized_copper, .waxed_copper_block, .lightning_rod => 3.0,
        .amethyst_block, .budding_amethyst, .amethyst_cluster => 1.5,
        .tinted_glass => 0.3,
        .bell => 5.0,
        .sugar_cane => 0.0,
        .pumpkin, .carved_pumpkin, .jack_o_lantern, .melon => 1.0,
        .sculk => 0.2,
        .sculk_sensor_off, .sculk_sensor_on => 1.5,
        .deepslate => 3.0,
        .cobbled_deepslate, .polished_deepslate, .deepslate_bricks => 3.5,
        .iron_block => 5.0,
        .cake => 0.5,
        .barrel => 2.5,
        .dripstone_block, .pointed_dripstone => 1.5,
        .moss_block, .moss_carpet => 0.1,
        .cave_vines, .cave_vines_lit, .flower_pot => 0.0,
        .clay => 0.6,
        .terracotta => 1.25,
        .ice, .packed_ice => 0.5,
        .blue_ice => 2.8,
        .powder_snow => 0.25,
        .bamboo, .packed_mud => 1.0,
        .scaffolding, .sweet_berry_bush, .decorated_pot => 0.0,
        .ender_chest => 22.5,
        .mud => 0.5,
        .mud_bricks => 1.5,
        .copper_bulb_off, .copper_bulb_on, .chiseled_copper, .copper_grate => 3.0,
        .suspicious_sand => 0.25,
        .heavy_core => 10.0,
        .crafter, .tuff, .polished_tuff, .tuff_bricks, .chiseled_tuff => 1.5,
        .trial_spawner, .vault => 5.0,
        .bookshelf => 1.5,
        .lectern => 2.5,
        .gold_ore, .gold_block => 3.0,
        .redstone_ore, .lit_redstone_ore => 3.0,
        .iron_door_closed, .iron_door_open, .iron_trapdoor_closed, .iron_trapdoor_open => 3.0,
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
        .end_portal => 0.0,
        .end_crystal => 0.0,
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
        .chain, .iron_bars => 5.0,
        .cobweb => 4.0,
        .end_stone => 3.0,
        .dragon_egg => 3.0,
        .dragon_head => 1.5,
        .end_gateway => 50.0,
        .prismarine, .prismarine_bricks, .dark_prismarine => 1.5,
        .sea_lantern => 0.3,
        .conduit => 3.0,
        .sponge, .wet_sponge => 0.6,
        .kelp => 0.0,
        .dried_kelp_block => 0.5,
        .sea_pickle => 0.0,
        .rail, .powered_rail, .detector_rail, .activator_rail => 0.7,
        .purpur_block, .purpur_pillar => 1.5,
        .shulker_box => 2.0,
        .end_rod => 0.0,
        .chorus_plant, .chorus_flower => 0.4,
        .end_portal_frame, .end_portal_frame_filled => 20.0,
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
        .stone, .obsidian, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .iron_door_closed, .iron_door_open, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .ancient_debris, .respawn_anchor, .crying_obsidian, .lodestone, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain, .iron_bars, .purpur_block, .purpur_pillar, .shulker_box, .redstone_block, .redstone_ore, .lit_redstone_ore, .gold_ore, .gold_block, .diamond_ore, .diamond_block, .emerald_ore, .emerald_block, .lapis_ore, .lapis_block, .copper_ore, .copper_block, .exposed_copper, .weathered_copper, .oxidized_copper, .waxed_copper_block, .lightning_rod, .amethyst_block, .budding_amethyst, .amethyst_cluster, .bell, .deepslate, .cobbled_deepslate, .polished_deepslate, .deepslate_bricks, .iron_block, .dripstone_block, .pointed_dripstone, .terracotta, .blue_ice, .ender_chest, .mud_bricks, .copper_bulb_off, .copper_bulb_on, .chiseled_copper, .copper_grate, .heavy_core, .crafter, .trial_spawner, .vault, .tuff, .polished_tuff, .tuff_bricks, .chiseled_tuff => .wooden,
        else => .hand,
    };
}

/// Mining speed multiplier for held item vs target block.
/// Wooden pickaxe is 3x on stone-class blocks, 1.5x elsewhere.
pub fn isWoodClass(block: BlockId) bool {
    return switch (block) {
        .wood, .wood_planks, .crafting_table, .chest, .wooden_door_closed, .wooden_door_open,
        .wooden_trapdoor_closed, .wooden_trapdoor_open, .oak_fence, .note_block, .jukebox,
        .smithing_table, .cartography_table, .fletching_table, .loom, .composter, .daylight_detector,
        .daylight_detector_inverted, .bookshelf, .lectern, .beehive, .barrel, .bamboo, .scaffolding => true,
        else => false,
    };
}

pub fn isSoilClass(block: BlockId) bool {
    return switch (block) {
        .dirt, .grass, .farmland, .sand, .snow, .soul_sand, .clay, .mud, .suspicious_sand => true,
        else => false,
    };
}

pub fn isShearableBlock(block: BlockId) bool {
    return switch (block) {
        .leaves, .cobweb, .weeping_vines, .twisting_vines, .wool => true,
        else => false,
    };
}

pub fn isFoliageClass(block: BlockId) bool {
    return switch (block) {
        .leaves, .hay_bale, .nether_wart, .wheat_crop, .sugar_cane, .pumpkin, .carved_pumpkin, .jack_o_lantern, .melon, .sculk, .sculk_sensor_off, .sculk_sensor_on, .moss_block, .moss_carpet, .cave_vines, .cave_vines_lit, .chorus_plant, .chorus_flower, .shroomlight, .sponge, .wet_sponge => true,
        else => false,
    };
}

pub fn isSwordTool(held_tool_id: u16) bool {
    return held_tool_id == TOOL_WOODEN_SWORD or held_tool_id == TOOL_STONE_SWORD or held_tool_id == TOOL_GOLDEN_SWORD or held_tool_id == TOOL_IRON_SWORD or held_tool_id == TOOL_DIAMOND_SWORD or held_tool_id == TOOL_NETHERITE_SWORD;
}

pub fn toolMultiplier(held_tool_id: u16, block: BlockId) f32 {
    if (isSwordTool(held_tool_id)) {
        if (block == .cobweb) return 10.0;
        if (isFoliageClass(block)) return 1.5;
        return 1.0;
    }
    if (held_tool_id == TOOL_SHEARS) {
        if (block == .cobweb) return 15.0;
        if (block == .leaves) return 10.0;
        if (block == .wool) return 5.0;
        if (isShearableBlock(block)) return 5.0;
        return 1.0;
    }

    if (held_tool_id == TOOL_GOLDEN_HOE) {
        if (isFoliageClass(block)) return 7.0;
        return 1.6;
    }
    if (held_tool_id == TOOL_NETHERITE_HOE) {
        if (isFoliageClass(block)) return 6.0;
        return 1.5;
    }
    if (held_tool_id == TOOL_DIAMOND_HOE) {
        if (isFoliageClass(block)) return 5.0;
        return 1.4;
    }
    if (held_tool_id == TOOL_IRON_HOE) {
        if (isFoliageClass(block)) return 4.0;
        return 1.2;
    }
    if (held_tool_id == TOOL_WOODEN_HOE) {
        if (isFoliageClass(block)) return 3.0;
        return 1.0;
    }
    if (held_tool_id == TOOL_STONE_HOE) {
        if (isFoliageClass(block)) return 3.5;
        return 1.1;
    }
    if (held_tool_id == TOOL_GOLDEN_SHOVEL) {
        if (isSoilClass(block)) return 7.0;
        return 1.6;
    }
    if (held_tool_id == TOOL_NETHERITE_SHOVEL) {
        if (isSoilClass(block)) return 6.0;
        return 1.5;
    }
    if (held_tool_id == TOOL_DIAMOND_SHOVEL) {
        if (isSoilClass(block)) return 5.0;
        return 1.4;
    }
    if (held_tool_id == TOOL_IRON_SHOVEL) {
        if (isSoilClass(block)) return 4.0;
        return 1.2;
    }
    if (held_tool_id == TOOL_WOODEN_SHOVEL) {
        if (isSoilClass(block)) return 3.0;
        return 1.0;
    }
    if (held_tool_id == TOOL_STONE_SHOVEL) {
        if (isSoilClass(block)) return 3.5;
        return 1.1;
    }
    if (held_tool_id == TOOL_GOLDEN_AXE) {
        if (isWoodClass(block)) return 7.0;
        return 2.2;
    }
    if (held_tool_id == TOOL_NETHERITE_AXE) {
        if (isWoodClass(block)) return 6.0;
        return 2.0;
    }
    if (held_tool_id == TOOL_DIAMOND_AXE) {
        if (isWoodClass(block)) return 5.0;
        return 1.8;
    }
    if (held_tool_id == TOOL_IRON_AXE) {
        if (isWoodClass(block)) return 4.0;
        return 1.5;
    }
    if (held_tool_id == TOOL_WOODEN_AXE) {
        if (isWoodClass(block)) return 3.0;
        return 1.2;
    }
    if (held_tool_id == TOOL_STONE_AXE) {
        if (isWoodClass(block)) return 3.5;
        return 1.3;
    }
    if (held_tool_id == TOOL_GOLDEN_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .redstone_block => 7.0,
            else => 2.0,
        };
    }
    if (held_tool_id == TOOL_NETHERITE_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .ancient_debris, .respawn_anchor, .obsidian, .crying_obsidian, .lodestone, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain, .iron_bars, .purpur_block, .purpur_pillar, .shulker_box, .redstone_block, .redstone_ore, .lit_redstone_ore, .gold_ore, .gold_block, .diamond_ore, .diamond_block, .emerald_ore, .emerald_block, .lapis_ore, .lapis_block, .copper_ore, .copper_block, .exposed_copper, .weathered_copper, .oxidized_copper, .waxed_copper_block, .lightning_rod, .amethyst_block, .budding_amethyst, .amethyst_cluster, .bell, .deepslate, .cobbled_deepslate, .polished_deepslate, .deepslate_bricks, .iron_block, .dripstone_block, .pointed_dripstone, .terracotta, .blue_ice, .ender_chest, .mud_bricks, .copper_bulb_off, .copper_bulb_on, .chiseled_copper, .copper_grate, .heavy_core, .crafter, .trial_spawner, .vault, .tuff, .polished_tuff, .tuff_bricks, .chiseled_tuff => 6.0,
            else => 3.0,
        };
    }
    if (held_tool_id == TOOL_DIAMOND_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .ancient_debris, .respawn_anchor, .obsidian, .crying_obsidian, .lodestone, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain, .iron_bars, .purpur_block, .purpur_pillar, .shulker_box, .redstone_block, .redstone_ore, .lit_redstone_ore, .gold_ore, .gold_block, .diamond_ore, .diamond_block, .emerald_ore, .emerald_block, .lapis_ore, .lapis_block, .copper_ore, .copper_block, .exposed_copper, .weathered_copper, .oxidized_copper, .waxed_copper_block, .lightning_rod, .amethyst_block, .budding_amethyst, .amethyst_cluster, .bell, .deepslate, .cobbled_deepslate, .polished_deepslate, .deepslate_bricks, .iron_block, .dripstone_block, .pointed_dripstone, .terracotta, .blue_ice, .ender_chest, .mud_bricks, .copper_bulb_off, .copper_bulb_on, .chiseled_copper, .copper_grate, .heavy_core, .crafter, .trial_spawner, .vault, .tuff, .polished_tuff, .tuff_bricks, .chiseled_tuff => 5.0,
            else => 2.5,
        };
    }
    if (held_tool_id == TOOL_IRON_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .ancient_debris, .respawn_anchor, .obsidian, .crying_obsidian, .lodestone, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain, .iron_bars, .purpur_block, .purpur_pillar, .shulker_box, .redstone_block, .redstone_ore, .lit_redstone_ore, .gold_ore, .gold_block, .diamond_ore, .diamond_block, .emerald_ore, .emerald_block, .lapis_ore, .lapis_block, .copper_ore, .copper_block, .exposed_copper, .weathered_copper, .oxidized_copper, .waxed_copper_block, .lightning_rod, .amethyst_block, .budding_amethyst, .amethyst_cluster, .bell, .deepslate, .cobbled_deepslate, .polished_deepslate, .deepslate_bricks, .iron_block, .dripstone_block, .pointed_dripstone, .terracotta, .blue_ice, .ender_chest, .mud_bricks, .copper_bulb_off, .copper_bulb_on, .chiseled_copper, .copper_grate, .heavy_core, .crafter, .trial_spawner, .vault, .tuff, .polished_tuff, .tuff_bricks, .chiseled_tuff => 4.0,
            else => 2.0,
        };
    }
    if (held_tool_id == TOOL_STONE_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .dispenser, .dropper, .brewing_stand, .cauldron, .redstone_block, .redstone_ore, .lit_redstone_ore => 3.5,
            else => 1.8,
        };
    }
    if (held_tool_id == TOOL_WOODEN_PICKAXE) {
        return switch (block) {
            .stone, .cobblestone, .coal_ore, .iron_ore, .sandstone, .brick, .furnace, .nether_quartz_ore, .quartz_block, .quartz_pillar, .chiseled_quartz_block, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain, .iron_bars, .purpur_block, .purpur_pillar, .shulker_box, .redstone_block, .redstone_ore, .lit_redstone_ore, .gold_ore, .gold_block, .diamond_ore, .diamond_block, .emerald_ore, .emerald_block, .lapis_ore, .lapis_block, .copper_ore, .copper_block, .exposed_copper, .weathered_copper, .oxidized_copper, .waxed_copper_block, .lightning_rod, .amethyst_block, .budding_amethyst, .amethyst_cluster, .bell, .deepslate, .cobbled_deepslate, .polished_deepslate, .deepslate_bricks, .iron_block, .dripstone_block, .pointed_dripstone, .terracotta, .blue_ice, .ender_chest, .mud_bricks, .copper_bulb_off, .copper_bulb_on, .chiseled_copper, .copper_grate, .heavy_core, .crafter, .trial_spawner, .vault, .tuff, .polished_tuff, .tuff_bricks, .chiseled_tuff => 3.0,
            else => 1.5,
        };
    }
    return 1.0;
}

/// Seconds to mine `block` while holding tool with discriminant `held_tool_id`.
pub fn mineTime(block: BlockId, held_tool_id: u16) f32 {
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
    .iron_bars = .{ .name = "iron_bars", .solid = false, .transparent = true, .fluid = false },
    .tripwire_hook_off = .{ .name = "tripwire_hook_off", .solid = false, .transparent = true, .fluid = false },
    .tripwire_hook_on = .{ .name = "tripwire_hook_on", .solid = false, .transparent = true, .fluid = false },
    .tripwire = .{ .name = "tripwire", .solid = false, .transparent = true, .fluid = false },
    .cobweb = .{ .name = "cobweb", .solid = false, .transparent = true, .fluid = false },
    .end_stone = .{ .name = "end_stone", .solid = true, .transparent = false, .fluid = false },
    .end_portal_frame = .{ .name = "end_portal_frame", .solid = true, .transparent = true, .fluid = false },
    .end_portal_frame_filled = .{ .name = "end_portal_frame_filled", .solid = true, .transparent = true, .fluid = false },
    .end_portal = .{ .name = "end_portal", .solid = false, .transparent = true, .fluid = false },
    .end_crystal = .{ .name = "end_crystal", .solid = false, .transparent = true, .fluid = false },
    .dragon_egg = .{ .name = "dragon_egg", .solid = true, .transparent = true, .fluid = false },
    .dragon_head = .{ .name = "dragon_head", .solid = false, .transparent = true, .fluid = false },
    .end_gateway = .{ .name = "end_gateway", .solid = false, .transparent = true, .fluid = false },
    .prismarine = .{ .name = "prismarine", .solid = true, .transparent = false, .fluid = false },
    .prismarine_bricks = .{ .name = "prismarine_bricks", .solid = true, .transparent = false, .fluid = false },
    .dark_prismarine = .{ .name = "dark_prismarine", .solid = true, .transparent = false, .fluid = false },
    .sea_lantern = .{ .name = "sea_lantern", .solid = true, .transparent = false, .fluid = false },
    .conduit = .{ .name = "conduit", .solid = false, .transparent = true, .fluid = false },
    .sponge = .{ .name = "sponge", .solid = true, .transparent = false, .fluid = false },
    .wet_sponge = .{ .name = "wet_sponge", .solid = true, .transparent = false, .fluid = false },
    .kelp = .{ .name = "kelp", .solid = false, .transparent = true, .fluid = false },
    .dried_kelp_block = .{ .name = "dried_kelp_block", .solid = true, .transparent = false, .fluid = false },
    .sea_pickle = .{ .name = "sea_pickle", .solid = false, .transparent = true, .fluid = false },
    .rail = .{ .name = "rail", .solid = false, .transparent = true, .fluid = false },
    .powered_rail = .{ .name = "powered_rail", .solid = false, .transparent = true, .fluid = false },
    .detector_rail = .{ .name = "detector_rail", .solid = false, .transparent = true, .fluid = false },
    .activator_rail = .{ .name = "activator_rail", .solid = false, .transparent = true, .fluid = false },
    .redstone_comparator_off = .{ .name = "redstone_comparator_off", .solid = false, .transparent = true, .fluid = false },
    .redstone_comparator_on = .{ .name = "redstone_comparator_on", .solid = false, .transparent = true, .fluid = false },
    .slime_block = .{ .name = "slime_block", .solid = true, .transparent = true, .fluid = false },
    .piston = .{ .name = "piston", .solid = true, .transparent = false, .fluid = false },
    .sticky_piston = .{ .name = "sticky_piston", .solid = true, .transparent = false, .fluid = false },
    .piston_head = .{ .name = "piston_head", .solid = true, .transparent = true, .fluid = false },
    .observer_off = .{ .name = "observer_off", .solid = true, .transparent = false, .fluid = false },
    .observer_on = .{ .name = "observer_on", .solid = true, .transparent = false, .fluid = false },
    .wooden_trapdoor_closed = .{ .name = "wooden_trapdoor_closed", .solid = true, .transparent = true, .fluid = false },
    .wooden_trapdoor_open = .{ .name = "wooden_trapdoor_open", .solid = false, .transparent = true, .fluid = false },
    .iron_trapdoor_closed = .{ .name = "iron_trapdoor_closed", .solid = true, .transparent = true, .fluid = false },
    .iron_trapdoor_open = .{ .name = "iron_trapdoor_open", .solid = false, .transparent = true, .fluid = false },
    .diamond_ore = .{ .name = "diamond_ore", .solid = true, .transparent = false, .fluid = false },
    .diamond_block = .{ .name = "diamond_block", .solid = true, .transparent = false, .fluid = false },
    .farmland = .{ .name = "farmland", .solid = true, .transparent = false, .fluid = false },
    .wheat_crop = .{ .name = "wheat_crop", .solid = false, .transparent = true, .fluid = false },
    .bookshelf = .{ .name = "bookshelf", .solid = true, .transparent = false, .fluid = false },
    .lectern = .{ .name = "lectern", .solid = true, .transparent = true, .fluid = false },
    .emerald_ore = .{ .name = "emerald_ore", .solid = true, .transparent = false, .fluid = false },
    .emerald_block = .{ .name = "emerald_block", .solid = true, .transparent = false, .fluid = false },
    .lapis_ore = .{ .name = "lapis_ore", .solid = true, .transparent = false, .fluid = false },
    .lapis_block = .{ .name = "lapis_block", .solid = true, .transparent = false, .fluid = false },
    .beehive = .{ .name = "beehive", .solid = true, .transparent = false, .fluid = false },
    .honey_block = .{ .name = "honey_block", .solid = true, .transparent = true, .fluid = false },
    .copper_ore = .{ .name = "copper_ore", .solid = true, .transparent = false, .fluid = false },
    .copper_block = .{ .name = "copper_block", .solid = true, .transparent = false, .fluid = false },
    .exposed_copper = .{ .name = "exposed_copper", .solid = true, .transparent = false, .fluid = false },
    .weathered_copper = .{ .name = "weathered_copper", .solid = true, .transparent = false, .fluid = false },
    .oxidized_copper = .{ .name = "oxidized_copper", .solid = true, .transparent = false, .fluid = false },
    .waxed_copper_block = .{ .name = "waxed_copper_block", .solid = true, .transparent = false, .fluid = false },
    .lightning_rod = .{ .name = "lightning_rod", .solid = false, .transparent = true, .fluid = false },
    .amethyst_block = .{ .name = "amethyst_block", .solid = true, .transparent = false, .fluid = false },
    .budding_amethyst = .{ .name = "budding_amethyst", .solid = true, .transparent = false, .fluid = false },
    .amethyst_cluster = .{ .name = "amethyst_cluster", .solid = false, .transparent = true, .fluid = false },
    .tinted_glass = .{ .name = "tinted_glass", .solid = true, .transparent = true, .fluid = false },
    .bell = .{ .name = "bell", .solid = true, .transparent = true, .fluid = false },
    .sugar_cane = .{ .name = "sugar_cane", .solid = false, .transparent = true, .fluid = false },
    .pumpkin = .{ .name = "pumpkin", .solid = true, .transparent = false, .fluid = false },
    .carved_pumpkin = .{ .name = "carved_pumpkin", .solid = true, .transparent = false, .fluid = false },
    .jack_o_lantern = .{ .name = "jack_o_lantern", .solid = true, .transparent = false, .fluid = false },
    .sculk = .{ .name = "sculk", .solid = true, .transparent = false, .fluid = false },
    .sculk_sensor_off = .{ .name = "sculk_sensor_off", .solid = true, .transparent = true, .fluid = false },
    .sculk_sensor_on = .{ .name = "sculk_sensor_on", .solid = true, .transparent = true, .fluid = false },
    .deepslate = .{ .name = "deepslate", .solid = true, .transparent = false, .fluid = false },
    .cobbled_deepslate = .{ .name = "cobbled_deepslate", .solid = true, .transparent = false, .fluid = false },
    .polished_deepslate = .{ .name = "polished_deepslate", .solid = true, .transparent = false, .fluid = false },
    .deepslate_bricks = .{ .name = "deepslate_bricks", .solid = true, .transparent = false, .fluid = false },
    .iron_block = .{ .name = "iron_block", .solid = true, .transparent = false, .fluid = false },
    .cake = .{ .name = "cake", .solid = true, .transparent = true, .fluid = false },
    .melon = .{ .name = "melon", .solid = true, .transparent = false, .fluid = false },
    .barrel = .{ .name = "barrel", .solid = true, .transparent = false, .fluid = false },
    .dripstone_block = .{ .name = "dripstone_block", .solid = true, .transparent = false, .fluid = false },
    .pointed_dripstone = .{ .name = "pointed_dripstone", .solid = true, .transparent = true, .fluid = false },
    .moss_block = .{ .name = "moss_block", .solid = true, .transparent = false, .fluid = false },
    .moss_carpet = .{ .name = "moss_carpet", .solid = false, .transparent = true, .fluid = false },
    .cave_vines = .{ .name = "cave_vines", .solid = false, .transparent = true, .fluid = false },
    .cave_vines_lit = .{ .name = "cave_vines_lit", .solid = false, .transparent = true, .fluid = false },
    .clay = .{ .name = "clay", .solid = true, .transparent = false, .fluid = false },
    .terracotta = .{ .name = "terracotta", .solid = true, .transparent = false, .fluid = false },
    .flower_pot = .{ .name = "flower_pot", .solid = false, .transparent = true, .fluid = false },
    .ice = .{ .name = "ice", .solid = true, .transparent = true, .fluid = false },
    .packed_ice = .{ .name = "packed_ice", .solid = true, .transparent = false, .fluid = false },
    .blue_ice = .{ .name = "blue_ice", .solid = true, .transparent = false, .fluid = false },
    .powder_snow = .{ .name = "powder_snow", .solid = false, .transparent = true, .fluid = false },
    .bamboo = .{ .name = "bamboo", .solid = false, .transparent = true, .fluid = false },
    .scaffolding = .{ .name = "scaffolding", .solid = false, .transparent = true, .fluid = false },
    .sweet_berry_bush = .{ .name = "sweet_berry_bush", .solid = false, .transparent = true, .fluid = false },
    .ender_chest = .{ .name = "ender_chest", .solid = true, .transparent = true, .fluid = false },
    .mud = .{ .name = "mud", .solid = true, .transparent = false, .fluid = false },
    .packed_mud = .{ .name = "packed_mud", .solid = true, .transparent = false, .fluid = false },
    .mud_bricks = .{ .name = "mud_bricks", .solid = true, .transparent = false, .fluid = false },
    .copper_bulb_off = .{ .name = "copper_bulb_off", .solid = true, .transparent = false, .fluid = false },
    .copper_bulb_on = .{ .name = "copper_bulb_on", .solid = true, .transparent = false, .fluid = false },
    .chiseled_copper = .{ .name = "chiseled_copper", .solid = true, .transparent = false, .fluid = false },
    .copper_grate = .{ .name = "copper_grate", .solid = true, .transparent = true, .fluid = false },
    .suspicious_sand = .{ .name = "suspicious_sand", .solid = true, .transparent = false, .fluid = false },
    .decorated_pot = .{ .name = "decorated_pot", .solid = true, .transparent = true, .fluid = false },
    .heavy_core = .{ .name = "heavy_core", .solid = true, .transparent = true, .fluid = false },
    .crafter = .{ .name = "crafter", .solid = true, .transparent = false, .fluid = false },
    .trial_spawner = .{ .name = "trial_spawner", .solid = true, .transparent = true, .fluid = false },
    .vault = .{ .name = "vault", .solid = true, .transparent = true, .fluid = false },
    .tuff = .{ .name = "tuff", .solid = true, .transparent = false, .fluid = false },
    .polished_tuff = .{ .name = "polished_tuff", .solid = true, .transparent = false, .fluid = false },
    .tuff_bricks = .{ .name = "tuff_bricks", .solid = true, .transparent = false, .fluid = false },
    .chiseled_tuff = .{ .name = "chiseled_tuff", .solid = true, .transparent = false, .fluid = false },
    .gold_ore = .{ .name = "gold_ore", .solid = true, .transparent = false, .fluid = false },
    .gold_block = .{ .name = "gold_block", .solid = true, .transparent = false, .fluid = false },
    .redstone_block = .{ .name = "redstone_block", .solid = true, .transparent = false, .fluid = false },
    .redstone_ore = .{ .name = "redstone_ore", .solid = true, .transparent = false, .fluid = false },
    .lit_redstone_ore = .{ .name = "lit_redstone_ore", .solid = true, .transparent = false, .fluid = false },
    .shulker_box = .{ .name = "shulker_box", .solid = true, .transparent = true, .fluid = false },
    .purpur_block = .{ .name = "purpur_block", .solid = true, .transparent = false, .fluid = false },
    .purpur_pillar = .{ .name = "purpur_pillar", .solid = true, .transparent = false, .fluid = false },
    .end_rod = .{ .name = "end_rod", .solid = false, .transparent = true, .fluid = false },
    .chorus_plant = .{ .name = "chorus_plant", .solid = false, .transparent = true, .fluid = false },
    .chorus_flower = .{ .name = "chorus_flower", .solid = false, .transparent = true, .fluid = false },
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
        .stone, .obsidian, .cobblestone, .coal_ore, .iron_ore, .glass, .sandstone, .brick, .nether_brick, .nether_brick_fence, .chiseled_nether_brick, .ancient_debris, .respawn_anchor, .crying_obsidian, .lodestone, .basalt, .blackstone, .gilded_blackstone, .dispenser, .dropper, .hopper, .brewing_stand, .cauldron, .enchantment_table, .anvil, .grindstone, .smoker, .blast_furnace, .stonecutter, .lantern, .soul_lantern, .chain, .iron_bars, .end_stone, .end_portal_frame, .end_portal_frame_filled, .dragon_egg, .dragon_head, .end_gateway, .purpur_block, .purpur_pillar, .shulker_box, .prismarine, .prismarine_bricks, .dark_prismarine, .sea_lantern, .conduit => .stone,
        .sponge, .wet_sponge, .slime_block => .grass,
        .piston, .sticky_piston, .piston_head, .observer_off, .observer_on, .iron_trapdoor_closed, .iron_trapdoor_open, .redstone_block, .redstone_ore, .lit_redstone_ore, .gold_ore, .gold_block, .diamond_ore, .diamond_block, .emerald_ore, .emerald_block, .lapis_ore, .lapis_block, .copper_ore, .copper_block, .exposed_copper, .weathered_copper, .oxidized_copper, .waxed_copper_block, .lightning_rod, .amethyst_block, .budding_amethyst, .amethyst_cluster, .tinted_glass, .bell, .deepslate, .cobbled_deepslate, .polished_deepslate, .deepslate_bricks, .iron_block, .dripstone_block, .pointed_dripstone, .terracotta, .flower_pot, .ice, .packed_ice, .blue_ice, .ender_chest, .mud_bricks, .copper_bulb_off, .copper_bulb_on, .chiseled_copper, .copper_grate, .decorated_pot, .heavy_core, .crafter, .trial_spawner, .vault, .tuff, .polished_tuff, .tuff_bricks, .chiseled_tuff => .stone,
        .kelp, .dried_kelp_block, .sea_pickle => .grass,
        .rail, .powered_rail, .detector_rail, .activator_rail, .redstone_comparator_off, .redstone_comparator_on => .stone,
        .end_rod, .chorus_plant, .chorus_flower => .wood,
        .wood, .target_block, .wooden_trapdoor_closed, .wooden_trapdoor_open, .tripwire, .daylight_detector, .daylight_detector_inverted, .note_block, .jukebox, .oak_fence, .armor_stand, .smithing_table, .cartography_table, .fletching_table, .composter, .loom, .tripwire_hook_off, .tripwire_hook_on => .wood,
        .dirt => .dirt,
        .sand, .suspicious_sand => .sand,
        .snow, .powder_snow => .snow,
        .wool, .cobweb => .wool,
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

test "cobweb block properties and textures" {
    try std.testing.expect(!BlockId.cobweb.is_solid());
    try std.testing.expect(BlockId.cobweb.is_transparent());
    try std.testing.expect(!BlockId.cobweb.is_fluid());
    try std.testing.expectEqual(hardness(.cobweb), 4.0);
    try std.testing.expectEqual(footstepType(.cobweb), .wool);
    const tex = BlockId.cobweb.getFaceTexture(0);
    try std.testing.expectEqual(@as(u8, 0), tex.x);
    try std.testing.expectEqual(@as(u8, 1), tex.y);
}

test "tripwire string line block properties and textures" {
    try std.testing.expect(!BlockId.tripwire.is_solid());
    try std.testing.expect(BlockId.tripwire.is_transparent());
    try std.testing.expect(!BlockId.tripwire.isFlammable());
    try std.testing.expectEqual(hardness(.tripwire), 0.0);
    try std.testing.expectEqual(BlockId.tripwire.emissive(), 0.0);
    try std.testing.expectEqual(footstepType(.tripwire), .wood);
    const tw_tex = BlockId.tripwire.getFaceTexture(0);
    try std.testing.expectEqual(tw_tex.x, 5);
    try std.testing.expectEqual(tw_tex.y, 6);
}

test "tripwire hook block properties and textures" {
    try std.testing.expect(!BlockId.tripwire_hook_off.is_solid());
    try std.testing.expect(!BlockId.tripwire_hook_on.is_solid());
    try std.testing.expect(BlockId.tripwire_hook_off.is_transparent());
    try std.testing.expect(BlockId.tripwire_hook_on.is_transparent());
    try std.testing.expectEqual(hardness(.tripwire_hook_off), 0.5);
    try std.testing.expectEqual(hardness(.tripwire_hook_on), 0.5);
    try std.testing.expectEqual(BlockId.tripwire_hook_off.emissive(), 0.0);
    try std.testing.expectEqual(BlockId.tripwire_hook_on.emissive(), 0.4);
    try std.testing.expectEqual(footstepType(.tripwire_hook_off), .wood);
    try std.testing.expectEqual(footstepType(.tripwire_hook_on), .wood);
    const toff = BlockId.tripwire_hook_off.getFaceTexture(0);
    try std.testing.expectEqual(@as(u8, 3), toff.x);
    try std.testing.expectEqual(@as(u8, 6), toff.y);
    const ton = BlockId.tripwire_hook_on.getFaceTexture(0);
    try std.testing.expectEqual(@as(u8, 4), ton.x);
    try std.testing.expectEqual(@as(u8, 6), ton.y);
}

test "iron_bars block properties and textures" {
    try std.testing.expect(!BlockId.iron_bars.is_solid());
    try std.testing.expect(BlockId.iron_bars.is_transparent());
    try std.testing.expect(!BlockId.iron_bars.is_fluid());
    try std.testing.expectEqual(hardness(.iron_bars), 5.0);
    try std.testing.expectEqual(requiredTier(.iron_bars), .wooden);
    try std.testing.expectEqual(footstepType(.iron_bars), .stone);
    const top_tex = BlockId.iron_bars.getFaceTexture(0);
    try std.testing.expectEqual(@as(u8, 1), top_tex.x);
    try std.testing.expectEqual(@as(u8, 2), top_tex.y);
    const bot_tex = BlockId.iron_bars.getFaceTexture(1);
    try std.testing.expectEqual(@as(u8, 1), bot_tex.x);
    try std.testing.expectEqual(@as(u8, 2), bot_tex.y);
    const side_tex = BlockId.iron_bars.getFaceTexture(2);
    try std.testing.expectEqual(@as(u8, 5), side_tex.x);
    try std.testing.expectEqual(@as(u8, 0), side_tex.y);
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


/// An end rod requires solid support on at least one adjacent face (floor, ceiling, or horizontal side)
/// or an adjacent end rod / chain.

/// Chorus plant and flower require solid support on floor (y-1) or another connected chorus plant.
pub fn canSupportChorusPlant(lookup: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, y: i32, z: i32) bool {
    const below = lookup(x, y - 1, z);
    if (below.is_solid() or below == .chorus_plant or below == .end_stone) return true;
    const adj = [_][3]i32{
        .{ -1, 0, 0 },
        .{ 1, 0, 0 },
        .{ 0, 0, -1 },
        .{ 0, 0, 1 },
    };
    for (adj) |off| {
        if (lookup(x + off[0], y + off[1], z + off[2]) == .chorus_plant) return true;
    }
    return false;
}

pub fn canSupportEndRod(lookup: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, y: i32, z: i32) bool {
    const offsets = [_][3]i32{
        .{ 0, -1, 0 },
        .{ 0, 1, 0 },
        .{ -1, 0, 0 },
        .{ 1, 0, 0 },
        .{ 0, 0, -1 },
        .{ 0, 0, 1 },
    };
    for (offsets) |off| {
        const adj = lookup(x + off[0], y + off[1], z + off[2]);
        if (adj.is_solid() or adj == .end_rod or adj == .chain or adj == .iron_bars) return true;
    }
    return false;
}

/// A lantern can be placed either resting on top of a solid block (floor support, y-1 solid)
/// or hanging suspended from a solid block above (ceiling support, y+1 solid).
pub fn canSupportLantern(lookup: *const fn (x: i32, y: i32, z: i32) BlockId, x: i32, y: i32, z: i32) bool {
    const below = lookup(x, y - 1, z);
    if (below.is_solid()) return true;
    const above = lookup(x, y + 1, z);
    if (above.is_solid() or above == .chain or above == .iron_bars) return true;
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

test "end stone and end portal frame properties and textures" {
    try std.testing.expect(BlockId.end_stone.is_solid());
    try std.testing.expect(!BlockId.end_stone.is_transparent());
    try std.testing.expectEqual(hardness(.end_stone), 3.0);
    try std.testing.expectEqual(footstepType(.end_stone), .stone);

    try std.testing.expect(BlockId.end_portal_frame.is_solid());
    try std.testing.expect(BlockId.end_portal_frame.is_transparent());
    try std.testing.expectEqual(hardness(.end_portal_frame), 20.0);
    try std.testing.expectEqual(BlockId.end_portal_frame.emissive(), 0.0);

    try std.testing.expect(BlockId.end_portal_frame_filled.is_solid());
    try std.testing.expect(BlockId.end_portal_frame_filled.is_transparent());
    try std.testing.expectEqual(hardness(.end_portal_frame_filled), 20.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.80), BlockId.end_portal_frame_filled.emissive(), 0.001);

    const f_top = BlockId.end_portal_frame.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), f_top.x);
    try std.testing.expectEqual(@as(u32, 3), f_top.y);

    const ff_top = BlockId.end_portal_frame_filled.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), ff_top.x);
    try std.testing.expectEqual(@as(u32, 6), ff_top.y);
}

test "end portal block properties and textures" {
    try std.testing.expect(!BlockId.end_portal.is_solid());
    try std.testing.expect(BlockId.end_portal.is_transparent());
    try std.testing.expectEqual(hardness(.end_portal), 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.90), BlockId.end_portal.emissive(), 0.001);

    const f_top = BlockId.end_portal.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), f_top.x);
    try std.testing.expectEqual(@as(u32, 6), f_top.y);
}

test "end crystal block properties and textures" {
    try std.testing.expect(!BlockId.end_crystal.is_solid());
    try std.testing.expect(BlockId.end_crystal.is_transparent());
    try std.testing.expectEqual(hardness(.end_crystal), 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.85), BlockId.end_crystal.emissive(), 0.001);

    const f_top = BlockId.end_crystal.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), f_top.x);
    try std.testing.expectEqual(@as(u32, 6), f_top.y);
}

test "dragon egg block properties, gravity, and textures" {
    try std.testing.expect(BlockId.dragon_egg.is_solid());
    try std.testing.expect(BlockId.dragon_egg.is_transparent());
    try std.testing.expect(BlockId.dragon_egg.is_falling());
    try std.testing.expectEqual(hardness(.dragon_egg), 3.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.35), BlockId.dragon_egg.emissive(), 0.001);
    try std.testing.expectEqual(footstepType(.dragon_egg), .stone);

    const f_top = BlockId.dragon_egg.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 5), f_top.x);
    try std.testing.expectEqual(@as(u32, 2), f_top.y);
}

test "purpur and end rod block properties and textures" {
    try std.testing.expect(BlockId.purpur_block.is_solid());
    try std.testing.expect(!BlockId.purpur_block.is_transparent());
    try std.testing.expectEqual(hardness(.purpur_block), 1.5);
    try std.testing.expectEqual(footstepType(.purpur_block), .stone);

    try std.testing.expect(BlockId.purpur_pillar.is_solid());
    try std.testing.expect(!BlockId.purpur_pillar.is_transparent());
    try std.testing.expectEqual(hardness(.purpur_pillar), 1.5);
    try std.testing.expectEqual(footstepType(.purpur_pillar), .stone);

    try std.testing.expect(!BlockId.end_rod.is_solid());
    try std.testing.expect(BlockId.end_rod.is_transparent());
    try std.testing.expectEqual(hardness(.end_rod), 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.95), BlockId.end_rod.emissive(), 0.001);
    try std.testing.expectEqual(footstepType(.end_rod), .wood);

    const pb_tex = BlockId.purpur_block.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 6), pb_tex.x);
    try std.testing.expectEqual(@as(u32, 5), pb_tex.y);

    const pp_top = BlockId.purpur_pillar.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 6), pp_top.x);
    try std.testing.expectEqual(@as(u32, 5), pp_top.y);
    const pp_side = BlockId.purpur_pillar.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 1), pp_side.x);
    try std.testing.expectEqual(@as(u32, 3), pp_side.y);

    const er_bot = BlockId.end_rod.getFaceTexture(1);
    try std.testing.expectEqual(@as(u32, 6), er_bot.x);
    try std.testing.expectEqual(@as(u32, 5), er_bot.y);
    const er_side = BlockId.end_rod.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 7), er_side.x);
    try std.testing.expectEqual(@as(u32, 6), er_side.y);
}

test "canSupportEndRod physical support check" {
    const mock = struct {
        fn getFloor(x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = z;
            if (y == 4) return .purpur_block;
            return .air;
        }
        fn getSide(x: i32, y: i32, z: i32) BlockId {
            _ = y; _ = z;
            if (x == 1) return .stone;
            return .air;
        }
        fn getVoid(x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = y; _ = z;
            return .air;
        }
    };
    try std.testing.expect(canSupportEndRod(&mock.getFloor, 0, 5, 0));
    try std.testing.expect(canSupportEndRod(&mock.getSide, 0, 5, 0));
    try std.testing.expect(!canSupportEndRod(&mock.getVoid, 0, 5, 0));
}

test "chorus plant and chorus flower block properties, textures, and support" {
    try std.testing.expect(!BlockId.chorus_plant.is_solid());
    try std.testing.expect(BlockId.chorus_plant.is_transparent());
    try std.testing.expectEqual(hardness(.chorus_plant), 0.4);
    try std.testing.expectEqual(footstepType(.chorus_plant), .wood);

    try std.testing.expect(!BlockId.chorus_flower.is_solid());
    try std.testing.expect(BlockId.chorus_flower.is_transparent());
    try std.testing.expectEqual(hardness(.chorus_flower), 0.4);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), BlockId.chorus_flower.emissive(), 0.001);
    try std.testing.expectEqual(footstepType(.chorus_flower), .wood);

    const cp_tex = BlockId.chorus_plant.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 6), cp_tex.x);
    try std.testing.expectEqual(@as(u32, 5), cp_tex.y);

    const cf_top = BlockId.chorus_flower.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), cf_top.x);
    try std.testing.expectEqual(@as(u32, 6), cf_top.y);

    const mock = struct {
        fn getFloor(x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = z;
            if (y == 4) return .end_stone;
            return .air;
        }
        fn getStem(x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = z;
            if (y == 4) return .chorus_plant;
            return .air;
        }
        fn getBranch(x: i32, y: i32, z: i32) BlockId {
            _ = y; _ = z;
            if (x == 1) return .chorus_plant;
            return .air;
        }
        fn getVoid(x: i32, y: i32, z: i32) BlockId {
            _ = x; _ = y; _ = z;
            return .air;
        }
    };
    try std.testing.expect(canSupportChorusPlant(&mock.getFloor, 0, 5, 0));
    try std.testing.expect(canSupportChorusPlant(&mock.getStem, 0, 5, 0));
    try std.testing.expect(canSupportChorusPlant(&mock.getBranch, 0, 5, 0));
    try std.testing.expect(!canSupportChorusPlant(&mock.getVoid, 0, 5, 0));
}

test "shulker box block properties and textures" {
    try std.testing.expect(BlockId.shulker_box.is_solid());
    try std.testing.expect(BlockId.shulker_box.is_transparent());
    try std.testing.expectEqual(hardness(.shulker_box), 2.0);
    try std.testing.expectEqual(footstepType(.shulker_box), .stone);

    const sb_top = BlockId.shulker_box.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 6), sb_top.x);
    try std.testing.expectEqual(@as(u32, 5), sb_top.y);
    const sb_side = BlockId.shulker_box.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 1), sb_side.x);
    try std.testing.expectEqual(@as(u32, 3), sb_side.y);
}

test "dragon head block properties, transparency, emissive, and textures" {
    try std.testing.expect(!BlockId.dragon_head.is_solid());
    try std.testing.expect(BlockId.dragon_head.is_transparent());
    try std.testing.expectEqual(hardness(.dragon_head), 1.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), BlockId.dragon_head.emissive(), 0.001);
    try std.testing.expectEqual(footstepType(.dragon_head), .stone);

    // Front face has snout/eye tile, other faces have dragon scales
    const f_front = BlockId.dragon_head.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 7), f_front.x);
    try std.testing.expectEqual(@as(u32, 3), f_front.y);

    const f_top = BlockId.dragon_head.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 5), f_top.x);
    try std.testing.expectEqual(@as(u32, 2), f_top.y);
}

test "end gateway block properties, transparency, emissive, and textures" {
    try std.testing.expect(!BlockId.end_gateway.is_solid());
    try std.testing.expect(BlockId.end_gateway.is_transparent());
    try std.testing.expectEqual(hardness(.end_gateway), 50.0);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), BlockId.end_gateway.emissive(), 0.001);
    try std.testing.expectEqual(footstepType(.end_gateway), .stone);

    const f = BlockId.end_gateway.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), f.x);
    try std.testing.expectEqual(@as(u32, 6), f.y);
}

test "prismarine, sea lantern, and conduit block properties and textures" {
    try std.testing.expect(BlockId.prismarine.is_solid());
    try std.testing.expect(!BlockId.prismarine.is_transparent());
    try std.testing.expectEqual(hardness(.prismarine), 1.5);
    try std.testing.expectEqual(footstepType(.prismarine), .stone);

    try std.testing.expect(BlockId.sea_lantern.is_solid());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), BlockId.sea_lantern.emissive(), 0.001);

    try std.testing.expect(!BlockId.conduit.is_solid());
    try std.testing.expect(BlockId.conduit.is_transparent());
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), BlockId.conduit.emissive(), 0.001);
}

test "sponge and wet sponge block properties, textures, and absorption checks" {
    try std.testing.expect(BlockId.sponge.is_solid());
    try std.testing.expect(!BlockId.sponge.is_transparent());
    try std.testing.expect(BlockId.sponge.is_sponge());
    try std.testing.expectEqual(hardness(.sponge), 0.6);
    try std.testing.expectEqual(footstepType(.sponge), .grass);

    try std.testing.expect(BlockId.wet_sponge.is_solid());
    try std.testing.expect(!BlockId.wet_sponge.is_transparent());
    try std.testing.expect(BlockId.wet_sponge.is_sponge());
    try std.testing.expectEqual(hardness(.wet_sponge), 0.6);
    try std.testing.expectEqual(footstepType(.wet_sponge), .grass);

    const s_tex = BlockId.sponge.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 0), s_tex.x);
    try std.testing.expectEqual(@as(u32, 3), s_tex.y);

    const ws_tex = BlockId.wet_sponge.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), ws_tex.x);
    try std.testing.expectEqual(@as(u32, 1), ws_tex.y);
}

test "kelp and dried kelp block properties, transparency, and textures" {
    try std.testing.expect(!BlockId.kelp.is_solid());
    try std.testing.expect(BlockId.kelp.is_transparent());
    try std.testing.expect(BlockId.kelp.is_ladder());
    try std.testing.expectEqual(hardness(.kelp), 0.0);
    try std.testing.expectEqual(footstepType(.kelp), .grass);

    try std.testing.expect(BlockId.dried_kelp_block.is_solid());
    try std.testing.expect(!BlockId.dried_kelp_block.is_transparent());
    try std.testing.expect(BlockId.dried_kelp_block.isFlammable());
    try std.testing.expectEqual(hardness(.dried_kelp_block), 0.5);
    try std.testing.expectEqual(footstepType(.dried_kelp_block), .grass);

    const k_tex = BlockId.kelp.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), k_tex.x);
    try std.testing.expectEqual(@as(u32, 0), k_tex.y);
}

test "sea pickle block properties, transparency, emissive glow, and textures" {
    try std.testing.expect(!BlockId.sea_pickle.is_solid());
    try std.testing.expect(BlockId.sea_pickle.is_transparent());
    try std.testing.expectEqual(hardness(.sea_pickle), 0.0);
    try std.testing.expectEqual(footstepType(.sea_pickle), .grass);
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), BlockId.sea_pickle.emissive(), 0.001);

    const sp_top = BlockId.sea_pickle.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), sp_top.x);
    try std.testing.expectEqual(@as(u32, 6), sp_top.y);

    const sp_side = BlockId.sea_pickle.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 7), sp_side.x);
    try std.testing.expectEqual(@as(u32, 0), sp_side.y);
}

test "rail and powered rail block properties, transparency, emissive, and textures" {
    try std.testing.expect(!BlockId.rail.is_solid());
    try std.testing.expect(BlockId.rail.is_transparent());
    try std.testing.expect(BlockId.rail.is_rail());
    try std.testing.expectEqual(hardness(.rail), 0.7);
    try std.testing.expectEqual(footstepType(.rail), .stone);
    try std.testing.expectEqual(BlockId.rail.emissive(), 0.0);

    try std.testing.expect(!BlockId.powered_rail.is_solid());
    try std.testing.expect(BlockId.powered_rail.is_transparent());
    try std.testing.expect(BlockId.powered_rail.is_rail());
    try std.testing.expectEqual(hardness(.powered_rail), 0.7);
    try std.testing.expectEqual(footstepType(.powered_rail), .stone);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), BlockId.powered_rail.emissive(), 0.001);

    const r_tex = BlockId.rail.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 1), r_tex.x);
    try std.testing.expectEqual(@as(u32, 2), r_tex.y);

    const pr_tex = BlockId.powered_rail.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 7), pr_tex.x);
    try std.testing.expectEqual(@as(u32, 7), pr_tex.y);
}

test "detector rail and activator rail properties, transparency, emissive, and textures" {
    try std.testing.expect(!BlockId.detector_rail.is_solid());
    try std.testing.expect(BlockId.detector_rail.is_transparent());
    try std.testing.expect(BlockId.detector_rail.is_rail());
    try std.testing.expectEqual(hardness(.detector_rail), 0.7);
    try std.testing.expectEqual(footstepType(.detector_rail), .stone);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), BlockId.detector_rail.emissive(), 0.001);

    try std.testing.expect(!BlockId.activator_rail.is_solid());
    try std.testing.expect(BlockId.activator_rail.is_transparent());
    try std.testing.expect(BlockId.activator_rail.is_rail());
    try std.testing.expectEqual(hardness(.activator_rail), 0.7);
    try std.testing.expectEqual(footstepType(.activator_rail), .stone);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), BlockId.activator_rail.emissive(), 0.001);

    const dr_tex = BlockId.detector_rail.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 4), dr_tex.x);
    try std.testing.expectEqual(@as(u32, 6), dr_tex.y);

    const ar_tex = BlockId.activator_rail.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 6), ar_tex.x);
    try std.testing.expectEqual(@as(u32, 7), ar_tex.y);
}

test "redstone comparator block properties, transparency, emissive, and textures" {
    try std.testing.expect(!BlockId.redstone_comparator_off.is_solid());
    try std.testing.expect(!BlockId.redstone_comparator_on.is_solid());
    try std.testing.expect(BlockId.redstone_comparator_off.is_transparent());
    try std.testing.expect(BlockId.redstone_comparator_on.is_transparent());
    try std.testing.expectEqual(hardness(.redstone_comparator_off), 0.2);
    try std.testing.expectEqual(hardness(.redstone_comparator_on), 0.2);
    try std.testing.expectEqual(footstepType(.redstone_comparator_off), .stone);
    try std.testing.expectEqual(BlockId.redstone_comparator_off.emissive(), 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.65), BlockId.redstone_comparator_on.emissive(), 0.001);

    const rco_tex = BlockId.redstone_comparator_off.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 0), rco_tex.x);
    try std.testing.expectEqual(@as(u32, 7), rco_tex.y);

    const rcn_tex = BlockId.redstone_comparator_on.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 1), rcn_tex.x);
    try std.testing.expectEqual(@as(u32, 7), rcn_tex.y);
}

test "slime block properties, transparency, and bounce support" {
    try std.testing.expect(BlockId.slime_block.is_solid());
    try std.testing.expect(BlockId.slime_block.is_transparent());
    try std.testing.expect(BlockId.slime_block.is_slime_block());
    try std.testing.expectEqual(hardness(.slime_block), 0.0);
    try std.testing.expectEqual(footstepType(.slime_block), .grass);

    const tex = BlockId.slime_block.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 2), tex.x);
    try std.testing.expectEqual(@as(u32, 7), tex.y);
}

test "piston and sticky piston block properties, textures, and hardness" {
    try std.testing.expect(BlockId.piston.is_solid());
    try std.testing.expect(BlockId.sticky_piston.is_solid());
    try std.testing.expect(BlockId.piston_head.is_solid());
    try std.testing.expect(!BlockId.piston.is_transparent());
    try std.testing.expect(!BlockId.sticky_piston.is_transparent());
    try std.testing.expect(BlockId.piston_head.is_transparent());
    try std.testing.expectEqual(hardness(.piston), 0.5);
    try std.testing.expectEqual(hardness(.sticky_piston), 0.5);
    try std.testing.expectEqual(footstepType(.piston), .stone);

    const p_top = BlockId.piston.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 3), p_top.x);
    try std.testing.expectEqual(@as(u32, 7), p_top.y);

    const sp_top = BlockId.sticky_piston.getFaceTexture(0);
    try std.testing.expectEqual(@as(u32, 5), sp_top.x);
    try std.testing.expectEqual(@as(u32, 7), sp_top.y);
}

test "observer block properties, textures, emissive, and hardness" {
    try std.testing.expect(BlockId.observer_off.is_solid());
    try std.testing.expect(BlockId.observer_on.is_solid());
    try std.testing.expect(!BlockId.observer_off.is_transparent());
    try std.testing.expect(!BlockId.observer_on.is_transparent());
    try std.testing.expectEqual(hardness(.observer_off), 3.0);
    try std.testing.expectEqual(footstepType(.observer_off), .stone);
    try std.testing.expectEqual(BlockId.observer_off.emissive(), 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.70), BlockId.observer_on.emissive(), 0.001);

    const obs_front = BlockId.observer_off.getFaceTexture(2);
    try std.testing.expectEqual(@as(u32, 6), obs_front.x);
    try std.testing.expectEqual(@as(u32, 7), obs_front.y);

    const obs_back_on = BlockId.observer_on.getFaceTexture(3);
    try std.testing.expectEqual(@as(u32, 7), obs_back_on.x);
    try std.testing.expectEqual(@as(u32, 6), obs_back_on.y);
}

test "redstone ore and lit redstone ore properties, textures, emissive, and hardness" {
    try std.testing.expect(BlockId.redstone_ore.is_solid());
    try std.testing.expect(BlockId.lit_redstone_ore.is_solid());
    try std.testing.expect(!BlockId.redstone_ore.is_transparent());
    try std.testing.expect(!BlockId.lit_redstone_ore.is_transparent());
    try std.testing.expect(!BlockId.redstone_ore.isFlammable());
    try std.testing.expectEqual(BlockId.redstone_ore.emissive(), 0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.55), BlockId.lit_redstone_ore.emissive(), 0.001);
    try std.testing.expectEqual(hardness(.redstone_ore), 3.0);
    try std.testing.expectEqual(hardness(.lit_redstone_ore), 3.0);
    try std.testing.expectEqual(requiredTier(.redstone_ore), .wooden);
    try std.testing.expectEqual(requiredTier(.lit_redstone_ore), .wooden);
    try std.testing.expectEqual(footstepType(.redstone_ore), .stone);
    try std.testing.expectEqual(footstepType(.lit_redstone_ore), .stone);
    const ore_tex = BlockId.redstone_ore.getFaceTexture(0);
    try std.testing.expectEqual(ore_tex.x, 1);
    try std.testing.expectEqual(ore_tex.y, 7);
    const lit_tex = BlockId.lit_redstone_ore.getFaceTexture(0);
    try std.testing.expectEqual(lit_tex.x, 2);
    try std.testing.expectEqual(lit_tex.y, 7);
}

test "diamond ore and diamond block properties, textures, and hardness" {
    try std.testing.expect(BlockId.diamond_ore.is_solid());
    try std.testing.expect(BlockId.diamond_block.is_solid());
    try std.testing.expect(!BlockId.diamond_ore.is_transparent());
    try std.testing.expect(!BlockId.diamond_block.is_transparent());
    try std.testing.expect(!BlockId.diamond_ore.isFlammable());
    try std.testing.expect(!BlockId.diamond_block.isFlammable());
    try std.testing.expectEqual(hardness(.diamond_ore), 3.0);
    try std.testing.expectEqual(hardness(.diamond_block), 5.0);
    try std.testing.expectEqual(requiredTier(.diamond_ore), .wooden);
    try std.testing.expectEqual(requiredTier(.diamond_block), .wooden);
    try std.testing.expectEqual(footstepType(.diamond_ore), .stone);
    try std.testing.expectEqual(footstepType(.diamond_block), .stone);
    const ore_tex = BlockId.diamond_ore.getFaceTexture(0);
    try std.testing.expectEqual(ore_tex.x, 4);
    try std.testing.expectEqual(ore_tex.y, 2);
    const block_tex = BlockId.diamond_block.getFaceTexture(0);
    try std.testing.expectEqual(block_tex.x, 5);
    try std.testing.expectEqual(block_tex.y, 7);
}

test "gold ore and gold block properties, textures, and hardness" {
    try std.testing.expect(BlockId.gold_ore.is_solid());
    try std.testing.expect(BlockId.gold_block.is_solid());
    try std.testing.expect(!BlockId.gold_ore.is_transparent());
    try std.testing.expect(!BlockId.gold_block.is_transparent());
    try std.testing.expect(!BlockId.gold_ore.isFlammable());
    try std.testing.expect(!BlockId.gold_block.isFlammable());
    try std.testing.expectEqual(hardness(.gold_ore), 3.0);
    try std.testing.expectEqual(hardness(.gold_block), 3.0);
    try std.testing.expectEqual(requiredTier(.gold_ore), .wooden);
    try std.testing.expectEqual(requiredTier(.gold_block), .wooden);
    try std.testing.expectEqual(footstepType(.gold_ore), .stone);
    try std.testing.expectEqual(footstepType(.gold_block), .stone);
    const ore_tex = BlockId.gold_ore.getFaceTexture(0);
    try std.testing.expectEqual(ore_tex.x, 3);
    try std.testing.expectEqual(ore_tex.y, 2);
    const block_tex = BlockId.gold_block.getFaceTexture(0);
    try std.testing.expectEqual(block_tex.x, 4);
    try std.testing.expectEqual(block_tex.y, 7);
}

test "redstone block properties, textures, emissive, and hardness" {
    try std.testing.expect(BlockId.redstone_block.is_solid());
    try std.testing.expect(!BlockId.redstone_block.is_transparent());
    try std.testing.expect(!BlockId.redstone_block.isFlammable());
    try std.testing.expectApproxEqAbs(@as(f32, 0.65), BlockId.redstone_block.emissive(), 0.001);
    try std.testing.expectEqual(hardness(.redstone_block), 5.0);
    try std.testing.expectEqual(footstepType(.redstone_block), .stone);
    const tex = BlockId.redstone_block.getFaceTexture(0);
    try std.testing.expectEqual(tex.x, 3);
    try std.testing.expectEqual(tex.y, 7);
}

test "wooden and iron trapdoor block properties, transparency, and hardness" {
    try std.testing.expect(BlockId.wooden_trapdoor_closed.is_solid());
    try std.testing.expect(!BlockId.wooden_trapdoor_open.is_solid());
    try std.testing.expect(BlockId.iron_trapdoor_closed.is_solid());
    try std.testing.expect(!BlockId.iron_trapdoor_open.is_solid());

    try std.testing.expect(BlockId.wooden_trapdoor_closed.is_transparent());
    try std.testing.expect(BlockId.wooden_trapdoor_open.is_transparent());
    try std.testing.expect(BlockId.iron_trapdoor_closed.is_transparent());
    try std.testing.expect(BlockId.iron_trapdoor_open.is_transparent());

    try std.testing.expect(BlockId.wooden_trapdoor_closed.isFlammable());
    try std.testing.expect(!BlockId.iron_trapdoor_closed.isFlammable());

    try std.testing.expectEqual(hardness(.wooden_trapdoor_closed), 0.5);
    try std.testing.expectEqual(hardness(.iron_trapdoor_closed), 3.0);
    try std.testing.expectEqual(footstepType(.wooden_trapdoor_closed), .wood);
    try std.testing.expectEqual(footstepType(.iron_trapdoor_closed), .stone);
}

test "diamond pickaxe tool multiplier speed and tool id" {
    try std.testing.expectEqual(TOOL_DIAMOND_PICKAXE, 221);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_PICKAXE, .stone), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_PICKAXE, .diamond_ore), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_PICKAXE, .obsidian), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_PICKAXE, .ancient_debris), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_PICKAXE, .dirt), 2.5);

    // Speed tier hierarchy: Netherite (6.0) > Diamond (5.0) > Iron (4.0) > Wooden (3.0)
    try std.testing.expect(toolMultiplier(TOOL_NETHERITE_PICKAXE, .stone) > toolMultiplier(TOOL_DIAMOND_PICKAXE, .stone));
    try std.testing.expect(toolMultiplier(TOOL_DIAMOND_PICKAXE, .stone) > toolMultiplier(TOOL_IRON_PICKAXE, .stone));
    try std.testing.expect(mineTime(.stone, TOOL_DIAMOND_PICKAXE) < mineTime(.stone, TOOL_IRON_PICKAXE));
    try std.testing.expect(mineTime(.stone, TOOL_NETHERITE_PICKAXE) < mineTime(.stone, TOOL_DIAMOND_PICKAXE));
}

test "axe tool multiplier speed and wood cutting efficiency" {
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_AXE, .wood), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_AXE, .wood), 4.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_AXE, .wood), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_AXE, .wood), 6.0);

    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_AXE, .wood_planks), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_AXE, .crafting_table), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_AXE, .chest), 5.0);

    // Axe cuts wood faster than bare hand or pickaxe
    try std.testing.expect(mineTime(.wood, TOOL_DIAMOND_AXE) < mineTime(.wood, 0));
    try std.testing.expect(mineTime(.wood, TOOL_NETHERITE_AXE) < mineTime(.wood, TOOL_DIAMOND_AXE));
    try std.testing.expect(mineTime(.wood, TOOL_DIAMOND_AXE) < mineTime(.wood, TOOL_IRON_AXE));
    try std.testing.expect(mineTime(.wood, TOOL_IRON_AXE) < mineTime(.wood, TOOL_WOODEN_AXE));
}

test "shovel tool multiplier speed and excavation efficiency" {
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_SHOVEL, .dirt), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_SHOVEL, .dirt), 4.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_SHOVEL, .dirt), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_SHOVEL, .dirt), 6.0);

    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_SHOVEL, .grass), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_SHOVEL, .sand), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_SHOVEL, .soul_sand), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_SHOVEL, .snow), 5.0);

    // Shovel digs soil faster than bare hand or pickaxe
    try std.testing.expect(mineTime(.dirt, TOOL_DIAMOND_SHOVEL) < mineTime(.dirt, 0));
    try std.testing.expect(mineTime(.dirt, TOOL_NETHERITE_SHOVEL) < mineTime(.dirt, TOOL_DIAMOND_SHOVEL));
    try std.testing.expect(mineTime(.dirt, TOOL_DIAMOND_SHOVEL) < mineTime(.dirt, TOOL_IRON_SHOVEL));
    try std.testing.expect(mineTime(.dirt, TOOL_IRON_SHOVEL) < mineTime(.dirt, TOOL_WOODEN_SHOVEL));
}

test "hoe tool multiplier speed and foliage efficiency" {
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_HOE, .leaves), 3.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_IRON_HOE, .leaves), 4.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_HOE, .leaves), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_NETHERITE_HOE, .leaves), 6.0);

    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_HOE, .hay_bale), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_HOE, .nether_wart), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_HOE, .chorus_plant), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_HOE, .shroomlight), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_HOE, .sponge), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_DIAMOND_HOE, .wet_sponge), 5.0);

    // Hoe harvests foliage faster than bare hand
    try std.testing.expect(mineTime(.leaves, TOOL_DIAMOND_HOE) < mineTime(.leaves, 0));
    try std.testing.expect(mineTime(.leaves, TOOL_NETHERITE_HOE) < mineTime(.leaves, TOOL_DIAMOND_HOE));
    try std.testing.expect(mineTime(.leaves, TOOL_DIAMOND_HOE) < mineTime(.leaves, TOOL_IRON_HOE));
    try std.testing.expect(mineTime(.leaves, TOOL_IRON_HOE) < mineTime(.leaves, TOOL_WOODEN_HOE));
}

test "shears tool multiplier and shearable block efficiency" {
    try std.testing.expectEqual(toolMultiplier(TOOL_SHEARS, .cobweb), 15.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_SHEARS, .leaves), 10.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_SHEARS, .wool), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_SHEARS, .weeping_vines), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_SHEARS, .twisting_vines), 5.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_SHEARS, .stone), 1.0);

    try std.testing.expect(isShearableBlock(.cobweb));
    try std.testing.expect(isShearableBlock(.leaves));
    try std.testing.expect(isShearableBlock(.wool));
    try std.testing.expect(!isShearableBlock(.dirt));

    // Shears cut cobwebs and leaves much faster than bare hand
    try std.testing.expect(mineTime(.cobweb, TOOL_SHEARS) < mineTime(.cobweb, 0));
    try std.testing.expect(mineTime(.leaves, TOOL_SHEARS) < mineTime(.leaves, 0));
}

test "stone tool multiplier speeds and stone mining efficiency" {
    try std.testing.expectEqual(toolMultiplier(TOOL_STONE_PICKAXE, .stone), 3.5);
    try std.testing.expectEqual(toolMultiplier(TOOL_STONE_PICKAXE, .coal_ore), 3.5);
    try std.testing.expectEqual(toolMultiplier(TOOL_STONE_PICKAXE, .iron_ore), 3.5);
    try std.testing.expectEqual(toolMultiplier(TOOL_STONE_PICKAXE, .dirt), 1.8);

    try std.testing.expectEqual(toolMultiplier(TOOL_STONE_AXE, .wood), 3.5);
    try std.testing.expectEqual(toolMultiplier(TOOL_STONE_SHOVEL, .dirt), 3.5);
    try std.testing.expectEqual(toolMultiplier(TOOL_STONE_HOE, .leaves), 3.5);

    // Stone pickaxe mines stone faster than wooden pickaxe
    try std.testing.expect(toolMultiplier(TOOL_STONE_PICKAXE, .stone) > toolMultiplier(TOOL_WOODEN_PICKAXE, .stone));
    try std.testing.expect(mineTime(.stone, TOOL_STONE_PICKAXE) < mineTime(.stone, TOOL_WOODEN_PICKAXE));
}

test "golden tool multiplier speeds and ultra-speed harvesting" {
    try std.testing.expectEqual(toolMultiplier(TOOL_GOLDEN_PICKAXE, .stone), 7.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_GOLDEN_PICKAXE, .coal_ore), 7.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_GOLDEN_PICKAXE, .dirt), 2.0);

    try std.testing.expectEqual(toolMultiplier(TOOL_GOLDEN_AXE, .wood), 7.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_GOLDEN_SHOVEL, .dirt), 7.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_GOLDEN_HOE, .leaves), 7.0);

    // Golden pickaxe mines stone faster than netherite pickaxe (7.0x vs 6.0x)
    try std.testing.expect(toolMultiplier(TOOL_GOLDEN_PICKAXE, .stone) > toolMultiplier(TOOL_NETHERITE_PICKAXE, .stone));
    try std.testing.expect(mineTime(.stone, TOOL_GOLDEN_PICKAXE) < mineTime(.stone, TOOL_NETHERITE_PICKAXE));
}

test "sword tool cobweb and foliage cutting multipliers" {
    try std.testing.expect(isSwordTool(TOOL_WOODEN_SWORD));
    try std.testing.expect(isSwordTool(TOOL_STONE_SWORD));
    try std.testing.expect(isSwordTool(TOOL_GOLDEN_SWORD));
    try std.testing.expect(isSwordTool(TOOL_IRON_SWORD));
    try std.testing.expect(isSwordTool(TOOL_DIAMOND_SWORD));
    try std.testing.expect(isSwordTool(TOOL_NETHERITE_SWORD));
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_SWORD, .cobweb), 10.0);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_SWORD, .leaves), 1.5);
    try std.testing.expectEqual(toolMultiplier(TOOL_WOODEN_SWORD, .stone), 1.0);
}

test "farmland and wheat_crop block properties" {
    try std.testing.expect(BlockId.farmland.is_solid());
    try std.testing.expect(!BlockId.farmland.is_transparent());
    try std.testing.expect(isSoilClass(.farmland));
    try std.testing.expect(!BlockId.wheat_crop.is_solid());
    try std.testing.expect(BlockId.wheat_crop.is_transparent());
    try std.testing.expect(BlockId.wheat_crop.isFlammable());
    try std.testing.expect(isFoliageClass(.wheat_crop));
}

test "bookshelf, lectern, emerald_ore, and emerald_block properties" {
    try std.testing.expect(BlockId.bookshelf.is_solid());
    try std.testing.expect(BlockId.bookshelf.isFlammable());
    try std.testing.expect(isWoodClass(.bookshelf));
    try std.testing.expect(BlockId.lectern.is_solid());
    try std.testing.expect(BlockId.lectern.is_transparent());
    try std.testing.expect(isWoodClass(.lectern));
    try std.testing.expect(BlockId.emerald_ore.is_solid());
    try std.testing.expectEqual(requiredTier(.emerald_ore), .wooden);
    try std.testing.expect(BlockId.emerald_block.is_solid());
    try std.testing.expectEqual(hardness(.emerald_block), 5.0);
}

test "lapis_ore, lapis_block, beehive, and honey_block properties" {
    try std.testing.expect(BlockId.lapis_ore.is_solid());
    try std.testing.expectEqual(requiredTier(.lapis_ore), .wooden);
    try std.testing.expect(BlockId.lapis_block.is_solid());
    try std.testing.expect(BlockId.beehive.is_solid());
    try std.testing.expect(BlockId.beehive.isFlammable());
    try std.testing.expect(BlockId.honey_block.is_solid());
    try std.testing.expect(BlockId.honey_block.is_transparent());
    try std.testing.expect(BlockId.honey_block.is_honey_block());
}

test "copper, lightning rod, amethyst, tinted glass, bell, sugar cane, and pumpkin block properties" {
    try std.testing.expect(BlockId.copper_ore.is_solid());
    try std.testing.expect(BlockId.copper_block.is_solid());
    try std.testing.expect(BlockId.oxidized_copper.is_solid());
    try std.testing.expect(!BlockId.lightning_rod.is_solid());
    try std.testing.expectEqual(BlockId.lightning_rod.emissive(), 0.45);
    try std.testing.expect(BlockId.amethyst_block.is_solid());
    try std.testing.expect(!BlockId.amethyst_cluster.is_solid());
    try std.testing.expectEqual(BlockId.amethyst_cluster.emissive(), 0.65);
    try std.testing.expect(BlockId.tinted_glass.is_solid());
    try std.testing.expect(BlockId.tinted_glass.is_transparent());
    try std.testing.expect(BlockId.bell.is_solid());
    try std.testing.expect(!BlockId.sugar_cane.is_solid());
    try std.testing.expect(BlockId.pumpkin.is_solid());
    try std.testing.expectEqual(BlockId.jack_o_lantern.emissive(), 0.95);
}

test "sculk, deepslate, iron_block, cake, melon, and barrel block properties" {
    try std.testing.expect(BlockId.sculk.is_solid());
    try std.testing.expectEqual(BlockId.sculk_sensor_on.emissive(), 0.85);
    try std.testing.expect(BlockId.deepslate.is_solid());
    try std.testing.expectEqual(requiredTier(.deepslate), .wooden);
    try std.testing.expect(BlockId.iron_block.is_solid());
    try std.testing.expect(BlockId.cake.is_solid());
    try std.testing.expect(BlockId.cake.is_transparent());
    try std.testing.expect(BlockId.melon.is_solid());
    try std.testing.expect(BlockId.barrel.is_solid());
    try std.testing.expect(BlockId.barrel.isFlammable());
}

test "dripstone, moss, cave_vines, clay, terracotta, and flower_pot block properties" {
    try std.testing.expect(BlockId.dripstone_block.is_solid());
    try std.testing.expect(BlockId.pointed_dripstone.is_falling());
    try std.testing.expect(BlockId.moss_block.is_solid());
    try std.testing.expect(!BlockId.moss_carpet.is_solid());
    try std.testing.expect(BlockId.cave_vines.is_ladder());
    try std.testing.expect(BlockId.cave_vines_lit.is_ladder());
    try std.testing.expectEqual(BlockId.cave_vines_lit.emissive(), 0.90);
    try std.testing.expect(isSoilClass(.clay));
    try std.testing.expect(BlockId.terracotta.is_solid());
    try std.testing.expect(!BlockId.flower_pot.is_solid());
}

test "ice, packed_ice, blue_ice, powder_snow, bamboo, scaffolding, and sweet_berry_bush block properties" {
    try std.testing.expect(BlockId.ice.is_solid());
    try std.testing.expect(BlockId.ice.is_transparent());
    try std.testing.expect(BlockId.packed_ice.is_solid());
    try std.testing.expect(BlockId.blue_ice.is_solid());
    try std.testing.expect(!BlockId.powder_snow.is_solid());
    try std.testing.expect(!BlockId.bamboo.is_solid());
    try std.testing.expect(BlockId.scaffolding.is_ladder());
    try std.testing.expect(!BlockId.sweet_berry_bush.is_solid());
}

test "ender_chest, mud, copper_bulb, chiseled_copper, copper_grate, suspicious_sand, and decorated_pot block properties" {
    try std.testing.expect(BlockId.ender_chest.is_solid());
    try std.testing.expectEqual(BlockId.ender_chest.emissive(), 0.55);
    try std.testing.expect(isSoilClass(.mud));
    try std.testing.expectEqual(BlockId.copper_bulb_on.emissive(), 1.0);
    try std.testing.expect(BlockId.copper_grate.is_transparent());
    try std.testing.expect(BlockId.suspicious_sand.is_falling());
    try std.testing.expect(BlockId.decorated_pot.is_transparent());
}

test "heavy_core, crafter, trial_spawner, vault, and tuff masonry block properties" {
    try std.testing.expect(BlockId.heavy_core.is_solid());
    try std.testing.expect(BlockId.heavy_core.is_transparent());
    try std.testing.expect(BlockId.crafter.is_solid());
    try std.testing.expectEqual(BlockId.trial_spawner.emissive(), 0.70);
    try std.testing.expectEqual(BlockId.vault.emissive(), 0.65);
    try std.testing.expect(BlockId.tuff.is_solid());
    try std.testing.expect(BlockId.tuff_bricks.is_solid());
}
