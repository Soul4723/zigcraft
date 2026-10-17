const std = @import("std");
const block_mod = @import("world/block.zig");
pub const BlockId = block_mod.BlockId;

pub const ItemType = enum(u16) {
    none = 0,
    stone = 1,
    dirt = 2,
    grass = 3,
    water = 4,
    wood = 5,
    leaves = 6,
    wood_planks = 7,
    stick = 8,
    wooden_pickaxe = 9,
    crafting_bench = 10,
    cobblestone = 11,
    coal = 12,
    iron_ore = 13,
    sand = 14,
    glass = 15,
    sandstone = 16,
    brick = 17,
    raw_pork = 18,
    raw_mutton = 19,
    cooked_pork = 20,
    cooked_mutton = 21,
    wool = 22,
    apple = 23,
    sapling = 24,
    furnace = 25,
    iron_ingot = 26,
    iron_pickaxe = 27,
    snowball = 28,
    snow_block = 29,
    golden_apple = 30,
    iron_sword = 31,
    ladder = 32,
    tnt = 33,
    torch = 34,
    chest = 35,
    wooden_door = 36,
    pressure_plate = 37,
    redstone_dust = 38,
    lever = 39,
    redstone_repeater = 40,
    redstone_lamp = 41,
    iron_door = 42,
    redstone_torch = 43,
    campfire = 44,
    cactus = 45,
    boat = 46,
    lava_bucket = 47,
    obsidian = 48,
    netherrack = 49,
    soul_sand = 50,
    magma = 51,
    fire_resistance_potion = 52,
    glowstone = 53,
    nether_quartz_ore = 54,
    nether_quartz = 55,
    quartz_block = 56,
    quartz_pillar = 57,
    chiseled_quartz_block = 58,
    nether_brick = 59,
    nether_brick_fence = 60,
    nether_wart = 61,
    magma_cream = 62,
    fire_charge = 63,
    soul_torch = 64,
    soul_campfire = 65,
    spawner_cage = 66,
    wither_skull = 67,
    nether_star = 68,
    beacon = 69,
    ancient_debris = 70,
    netherite_scrap = 71,
    netherite_ingot = 72,
    netherite_pickaxe = 73,
    netherite_sword = 74,
    respawn_anchor = 75,
    crying_obsidian = 76,
    lodestone = 77,
    basalt = 78,
    blackstone = 79,
    gilded_blackstone = 80,
    gold_nugget = 81,
    weeping_vines = 82,
    twisting_vines = 83,
    target_block = 84,
    hay_bale = 85,
    crimson_fungus = 86,
    warped_fungus = 87,
    shroomlight = 88,
    warped_fungus_on_a_stick = 89,
    netherite_chestplate = 90,
    soul_speed_boots = 91,
    netherite_helmet = 92,
    netherite_leggings = 93,
    chiseled_nether_brick = 94,
    netherite_boots = 95,
    spectral_arrow = 96,
    arrow = 97,
    bow = 98,
    shield = 99,
    compass = 100,
    lodestone_compass = 101,
    crossbow = 102,
    fireworks_rocket = 103,
    dispenser = 104,
    dropper = 105,
    hopper = 106,
    blaze_rod = 107,
    blaze_powder = 108,
    brewing_stand = 109,
    cauldron = 110,
    water_bucket = 111,
    daylight_detector = 112,
    note_block = 113,
    jukebox = 114,
    music_disc_13 = 115,
    music_disc_cat = 116,
    oak_fence = 117,
    lead = 118,
    armor_stand = 119,
    target_dummy = 120,
    enchantment_table = 121,
    anvil = 122,
    grindstone = 123,
    smithing_table = 124,
    cartography_table = 125,
    fletching_table = 126,
    composter = 127,
    bone_meal = 128,
    loom = 129,
    smoker = 130,
    blast_furnace = 131,
    stonecutter = 132,
    lantern = 133,
    soul_lantern = 134,
    chain = 135,
    iron_bars = 136,
    tripwire_hook = 137,
    string = 138,
    cobweb = 139,
    spider_eye = 140,
    poison_potion = 141,
    fermented_spider_eye = 142,
    weakness_potion = 143,
    bone = 144,
    rotten_flesh = 145,
    gunpowder = 146,
    ender_pearl = 147,
    eye_of_ender = 148,
    end_stone = 149,
    end_portal_frame = 150,
    end_crystal = 151,
    dragon_egg = 152,
    purpur_block = 153,
    purpur_pillar = 154,
    end_rod = 155,
    chorus_fruit = 156,
    popped_chorus_fruit = 157,
    chorus_flower = 158,
    chorus_plant = 159,
    shulker_shell = 160,
    shulker_box = 161,
    elytra = 162,
    dragon_head = 163,
    end_gateway = 164,
    dragons_breath = 165,
    lingering_poison_potion = 166,
    lingering_weakness_potion = 167,
    scute = 168,
    turtle_helmet = 169,
    water_breathing_potion = 170,
    trident = 171,
    phantom_membrane = 172,
    slow_falling_potion = 173,
    prismarine_shard = 174,
    prismarine_crystals = 175,
    prismarine = 177,
    prismarine_bricks = 178,
    dark_prismarine = 179,
    sea_lantern = 180,
    conduit = 181,
    sponge = 182,
    wet_sponge = 183,
    raw_cod = 184,
    cooked_cod = 185,
    fishing_rod = 186,
    kelp = 187,
    dried_kelp = 188,
    dried_kelp_block = 189,
    sea_pickle = 190,
    raw_salmon = 191,
    cooked_salmon = 192,
    pufferfish = 193,
    tropical_fish = 194,
    nautilus_shell = 195,
    rail = 196,
    powered_rail = 197,
    minecart = 198,
    detector_rail = 199,
    activator_rail = 200,
    chest_minecart = 201,
    furnace_minecart = 202,
    tnt_minecart = 203,
    hopper_minecart = 204,
    redstone_comparator = 205,
    slimeball = 206,
    slime_block = 207,
    piston = 208,
    sticky_piston = 209,
    observer = 210,
    wooden_trapdoor = 211,
    iron_trapdoor = 212,
    redstone_block = 213,
    redstone_ore = 214,
    gold_ore = 215,
    gold_block = 216,
    diamond = 217,
    diamond_ore = 218,
    diamond_block = 219,
    diamond_sword = 220,
    diamond_pickaxe = 221,
    diamond_helmet = 222,
    diamond_chestplate = 223,
    diamond_leggings = 224,
    diamond_boots = 225,
    flint = 226,
    flint_and_steel = 227,
    wooden_axe = 228,
    iron_axe = 229,
    diamond_axe = 230,
    netherite_axe = 231,
    wooden_shovel = 232,
    iron_shovel = 233,
    diamond_shovel = 234,
    netherite_shovel = 235,
    wooden_hoe = 236,
    iron_hoe = 237,
    diamond_hoe = 238,
    netherite_hoe = 239,
    shears = 240,
    iron_helmet = 241,
    iron_chestplate = 242,
    iron_leggings = 243,
    iron_boots = 244,
    golden_helmet = 245,
    golden_chestplate = 246,
    golden_leggings = 247,
    golden_boots = 248,
    stone_sword = 249,
    stone_pickaxe = 250,
    stone_axe = 251,
    stone_shovel = 252,
    stone_hoe = 253,
    golden_sword = 254,
    golden_pickaxe = 255,
    golden_axe = 256,
    golden_shovel = 257,
    golden_hoe = 258,
    wooden_sword = 259,
    leather = 260,
    leather_helmet = 261,
    leather_chestplate = 262,
    leather_leggings = 263,
    leather_boots = 264,
    farmland = 265,
    wheat_seeds = 266,
    wheat = 267,
    bread = 268,
    paper = 269,
    book = 270,
    bookshelf = 271,
    lectern = 272,
    emerald = 273,
    emerald_ore = 274,
    emerald_block = 275,
    lapis_lazuli = 276,
    lapis_ore = 277,
    lapis_block = 278,
    honeycomb = 279,
    honey_bottle = 280,
    beehive = 281,
    honey_block = 282,
    raw_copper = 283,
    copper_ingot = 284,
    copper_ore = 285,
    copper_block = 286,
    exposed_copper = 287,
    weathered_copper = 288,
    oxidized_copper = 289,
    waxed_copper_block = 290,
    lightning_rod = 291,
    spyglass = 292,
    amethyst_shard = 293,
    amethyst_block = 294,
    budding_amethyst = 295,
    amethyst_cluster = 296,
    tinted_glass = 297,
    bell = 298,
    sugar_cane = 299,
    sugar = 300,
    pumpkin = 301,
    carved_pumpkin = 302,
    jack_o_lantern = 303,
    pumpkin_pie = 304,
    sculk = 305,
    sculk_sensor = 306,
    echo_shard = 307,
    recovery_compass = 308,
    deepslate = 309,
    cobbled_deepslate = 310,
    polished_deepslate = 311,
    deepslate_bricks = 312,
    iron_block = 313,
    cake = 314,
    melon = 315,
    melon_slice = 316,
    glistering_melon = 317,
    healing_potion = 318,
    barrel = 319,
    dripstone_block = 320,
    pointed_dripstone = 321,
    moss_block = 322,
    moss_carpet = 323,
    glow_berries = 324,
    clay_ball = 325,
    clay = 326,
    terracotta = 327,
    brick_item = 328,
    flower_pot = 329,
    totem_of_undying = 330,
    carrot = 331,
    golden_carrot = 332,
    night_vision_potion = 333,
    ghast_tear = 334,
    regeneration_potion = 335,
    ice = 336,
    packed_ice = 337,
    blue_ice = 338,
    powder_snow_bucket = 339,
    bamboo = 340,
    scaffolding = 341,
    potato = 342,
    baked_potato = 343,
    poisonous_potato = 344,
    beetroot = 345,
    bowl = 346,
    beetroot_soup = 347,
    mushroom_stew = 348,
    rabbit_foot = 349,
    swiftness_potion = 350,
    strength_potion = 351,
    leaping_potion = 352,
    cocoa_beans = 353,
    cookie = 354,
    sweet_berries = 355,
    ender_chest = 356,
    chainmail_helmet = 357,
    chainmail_chestplate = 358,
    chainmail_leggings = 359,
    chainmail_boots = 360,
    mud = 361,
    packed_mud = 362,
    mud_bricks = 363,
    copper_bulb = 364,
    chiseled_copper = 365,
    copper_grate = 366,
    brush = 367,
    suspicious_sand = 368,
    pottery_sherd = 369,
    decorated_pot = 370,
    breeze_rod = 371,
    wind_charge = 372,
    heavy_core = 373,
    mace = 374,
    crafter = 375,
    trial_key = 376,
    trial_spawner = 377,
    vault = 378,
    enchanted_golden_apple = 379,
    suspicious_stew = 380,
    tuff = 381,
    polished_tuff = 382,
    tuff_bricks = 383,
    chiseled_tuff = 384,
    calibrated_sculk_sensor = 385,
    ochre_froglight = 386,
    verdant_froglight = 387,
    pearlescent_froglight = 388,
    mangrove_roots = 389,
    muddy_mangrove_roots = 390,
    mangrove_propagule = 391,
    mangrove_log = 392,
    mangrove_planks = 393,
    goat_horn = 394,
    armor_trim_template = 395,
    torchflower_seeds = 396,
    torchflower = 397,
    pitcher_pod = 398,
    pitcher_plant = 399,
    cherry_log = 400,
    cherry_leaves = 401,
    cherry_planks = 402,
    pink_petals = 403,
    chiseled_bookshelf = 404,
    hanging_sign = 405,
    bamboo_mosaic = 406,
    creaking_heart = 407,
    pale_oak_log = 408,
    open_eyeblossom = 409,
    resin_bricks = 410,
    resin_clump = 411,
    resin_brick = 412,
    armadillo_scute = 413,
    wolf_armor = 414,
    ominous_bottle = 415,
    ominous_trial_key = 416,
    ominous_vault = 417,
    potion_of_infested = 418,
    potion_of_oozing = 419,
    potion_of_weaving = 420,
    potion_of_wind_charged = 421,
    bundle = 422,
    copper_door = 423,
    copper_trapdoor = 424,
    disc_fragment_5 = 425,
    music_disc_5 = 426,
    music_disc_relic = 427,
    music_disc_precipice = 428,
    music_disc_creator = 429,
    dried_ghast = 430,
    ghast_harness = 431,
    sculk_catalyst = 432,
    sculk_shrieker = 433,
    bucket_of_axolotl = 434,
    banner = 435,
    banner_pattern_stencil = 436,
    copper_golem_statue = 437,
    firefly_bush = 438,
    leaf_litter = 439,
    enchanted_book = 440,
    mending_book = 441,
    raid_omen_banner = 442,
    evoker_fang_totem = 443,
    turtle_egg = 444,
    seagrass = 445,
    potion_of_turtle_master = 446,
    sweet_berry_fox_treat = 447,
    zombie_head = 448,
    skeleton_skull = 449,
    creeper_head = 450,
    piglin_head = 451,
    splash_water_bottle = 452,
    splash_harming_potion = 453,
    water_bottle = 454,
    harming_potion = 455,
    wither_rose = 456,
    glazed_terracotta = 457,
    name_tag = 458,
    saddle = 459,
    light_weighted_pressure_plate = 460,
    heavy_weighted_pressure_plate = 461,
    empty_locator_map = 462,
    filled_explorer_map = 463,
    glass_pane = 464,
    leather_horse_armor = 465,
    iron_horse_armor = 466,
    golden_horse_armor = 467,
    diamond_horse_armor = 468,
    frost_walker_boots = 469,
    swift_sneak_book = 470,
    reinforced_deepslate = 471,
    milk_bucket = 472,
    bottle_o_enchanting = 473,
    sweeping_edge_book = 474,
    arrow_of_slowness = 475,
    item_frame = 476,
    glow_item_frame = 477,
    painting = 478,
    feather_falling_book = 479,
    stained_glass = 480,
    potion_of_slowness = 481,
    red_sandstone = 482,
    concrete_powder = 483,
    concrete_block = 484,
    buried_treasure_map = 485,
    heart_of_the_sea = 486,
    firework_star = 487,
    acacia_planks = 488,
    dark_oak_planks = 489,
    music_disc_pigstep = 490,
    netherite_upgrade_template = 491,
    sniffer_egg = 492,
    suspicious_gravel = 493,
    coral_block = 494,
    dead_coral_block = 495,
    lily_pad = 496,
    frogspawn = 497,
    bucket_of_tadpole = 498,
    book_and_quill = 499,
    written_book = 500,
    bone_block = 501,
    calcite = 502,
    smooth_basalt = 503,
    rooted_dirt = 504,
    hanging_roots = 505,
    big_dripleaf = 506,
    spore_blossom = 507,
    awkward_potion = 508,
    invisibility_potion = 509,
    sunflower = 511,
    lilac = 512,
    rose_bush = 513,
    peony = 514,
    podzol = 515,
    mossy_cobblestone = 516,
    birch_planks = 517,
    spruce_planks = 518,
    chest_boat = 519,
    bamboo_raft = 520,
    bed = 521,
    clock = 510,

    pub fn toBlockId(self: ItemType) ?BlockId {
        return switch (self) {
            .stone => .stone,
            .dirt => .dirt,
            .grass => .grass,
            .water => .water,
            .wood => .wood,
            .leaves => .leaves,
            .wood_planks => .wood_planks,
            .crafting_bench => .crafting_table,
            .cobblestone => .cobblestone,
            .coal => .coal_ore,
            .iron_ore => .iron_ore,
            .sand => .sand,
            .glass => .glass,
            .sandstone => .sandstone,
            .brick => .brick,
            .snow_block => .snow,
            .ladder => .ladder,
            .tnt => .tnt,
            .torch => .torch,
            .chest => .chest,
            .wooden_door => .wooden_door_closed,
            .pressure_plate => .pressure_plate_up,
            .redstone_dust => .redstone_wire_off,
            .lever => .lever_off,
            .redstone_repeater => .repeater_off,
            .redstone_lamp => .redstone_lamp_off,
            .iron_door => .iron_door_closed,
            .redstone_torch => .redstone_torch_on,
            .campfire => .campfire,
            .cactus => .cactus,
            .lava_bucket => .lava,
            .obsidian => .obsidian,
            .netherrack => .netherrack,
            .soul_sand => .soul_sand,
            .magma => .magma,
            .glowstone => .glowstone,
            .nether_quartz_ore => .nether_quartz_ore,
            .quartz_block => .quartz_block,
            .quartz_pillar => .quartz_pillar,
            .chiseled_quartz_block => .chiseled_quartz_block,
            .nether_brick => .nether_brick,
            .nether_brick_fence => .nether_brick_fence,
            .nether_wart => .nether_wart,
            .soul_torch => .soul_torch,
            .soul_campfire => .soul_campfire,
            .spawner_cage => .spawner_cage,
            .wither_skull => .wither_skull_block,
            .beacon => .beacon,
            .ancient_debris => .ancient_debris,
            .respawn_anchor => .respawn_anchor,
            .crying_obsidian => .crying_obsidian,
            .lodestone => .lodestone,
            .basalt => .basalt,
            .blackstone => .blackstone,
            .gilded_blackstone => .gilded_blackstone,
            .weeping_vines => .weeping_vines,
            .twisting_vines => .twisting_vines,
            .target_block => .target_block,
            .hay_bale => .hay_bale,
            .crimson_fungus => .crimson_fungus,
            .warped_fungus => .warped_fungus,
            .shroomlight => .shroomlight,
            .chiseled_nether_brick => .chiseled_nether_brick,
            .dispenser => .dispenser,
            .dropper => .dropper,
            .hopper => .hopper,
            .brewing_stand => .brewing_stand,
            .cauldron => .cauldron,
            .water_bucket => .water,
            .daylight_detector => .daylight_detector,
            .note_block => .note_block,
            .jukebox => .jukebox,
            .oak_fence => .oak_fence,
            .armor_stand => .armor_stand,
            .enchantment_table => .enchantment_table,
            .anvil => .anvil,
            .grindstone => .grindstone,
            .smithing_table => .smithing_table,
            .cartography_table => .cartography_table,
            .fletching_table => .fletching_table,
            .composter => .composter,
            .loom => .loom,
            .smoker => .smoker,
            .blast_furnace => .blast_furnace,
            .stonecutter => .stonecutter,
            .lantern => .lantern,
            .soul_lantern => .soul_lantern,
            .chain => .chain,
            .iron_bars => .iron_bars,
            .tripwire_hook => .tripwire_hook_off,
            .string => .tripwire,
            .cobweb => .cobweb,
            .end_stone => .end_stone,
            .end_portal_frame => .end_portal_frame,
            .end_crystal => .end_crystal,
            .dragon_egg => .dragon_egg,
            .purpur_block => .purpur_block,
            .purpur_pillar => .purpur_pillar,
            .end_rod => .end_rod,
            .chorus_plant => .chorus_plant,
            .chorus_flower => .chorus_flower,
            .shulker_box => .shulker_box,
            .dragon_head => .dragon_head,
            .end_gateway => .end_gateway,
            .prismarine => .prismarine,
            .prismarine_bricks => .prismarine_bricks,
            .dark_prismarine => .dark_prismarine,
            .sea_lantern => .sea_lantern,
            .conduit => .conduit,
            .sponge => .sponge,
            .wet_sponge => .wet_sponge,
            .kelp => .kelp,
            .dried_kelp_block => .dried_kelp_block,
            .sea_pickle => .sea_pickle,
            .rail => .rail,
            .powered_rail => .powered_rail,
            .detector_rail => .detector_rail,
            .activator_rail => .activator_rail,
            .redstone_comparator => .redstone_comparator_off,
            .slime_block => .slime_block,
            .piston => .piston,
            .sticky_piston => .sticky_piston,
            .observer => .observer_off,
            .wooden_trapdoor => .wooden_trapdoor_closed,
            .iron_trapdoor => .iron_trapdoor_closed,
            .redstone_block => .redstone_block,
            .redstone_ore => .redstone_ore,
            .gold_ore => .gold_ore,
            .gold_block => .gold_block,
            .diamond_ore => .diamond_ore,
            .diamond_block => .diamond_block,
            .farmland => .farmland,
            .wheat_seeds => .wheat_crop,
            .bookshelf => .bookshelf,
            .lectern => .lectern,
            .emerald_ore => .emerald_ore,
            .emerald_block => .emerald_block,
            .lapis_ore => .lapis_ore,
            .lapis_block => .lapis_block,
            .beehive => .beehive,
            .honey_block => .honey_block,
            .copper_ore => .copper_ore,
            .copper_block => .copper_block,
            .exposed_copper => .exposed_copper,
            .weathered_copper => .weathered_copper,
            .oxidized_copper => .oxidized_copper,
            .waxed_copper_block => .waxed_copper_block,
            .lightning_rod => .lightning_rod,
            .amethyst_block => .amethyst_block,
            .budding_amethyst => .budding_amethyst,
            .amethyst_cluster => .amethyst_cluster,
            .tinted_glass => .tinted_glass,
            .bell => .bell,
            .sugar_cane => .sugar_cane,
            .pumpkin => .pumpkin,
            .carved_pumpkin => .carved_pumpkin,
            .jack_o_lantern => .jack_o_lantern,
            .sculk => .sculk,
            .sculk_sensor => .sculk_sensor_off,
            .deepslate => .deepslate,
            .cobbled_deepslate => .cobbled_deepslate,
            .polished_deepslate => .polished_deepslate,
            .deepslate_bricks => .deepslate_bricks,
            .iron_block => .iron_block,
            .cake => .cake,
            .melon => .melon,
            .barrel => .barrel,
            .dripstone_block => .dripstone_block,
            .pointed_dripstone => .pointed_dripstone,
            .moss_block => .moss_block,
            .moss_carpet => .moss_carpet,
            .glow_berries => .cave_vines,
            .clay => .clay,
            .terracotta => .terracotta,
            .flower_pot => .flower_pot,
            .ice => .ice,
            .packed_ice => .packed_ice,
            .blue_ice => .blue_ice,
            .powder_snow_bucket => .powder_snow,
            .bamboo => .bamboo,
            .scaffolding => .scaffolding,
            .sweet_berries => .sweet_berry_bush,
            .ender_chest => .ender_chest,
            .mud => .mud,
            .packed_mud => .packed_mud,
            .mud_bricks => .mud_bricks,
            .copper_bulb => .copper_bulb_off,
            .chiseled_copper => .chiseled_copper,
            .copper_grate => .copper_grate,
            .suspicious_sand => .suspicious_sand,
            .decorated_pot => .decorated_pot,
            .heavy_core => .heavy_core,
            .crafter => .crafter,
            .trial_spawner => .trial_spawner,
            .vault => .vault,
            .tuff => .tuff,
            .polished_tuff => .polished_tuff,
            .tuff_bricks => .tuff_bricks,
            .chiseled_tuff => .chiseled_tuff,
            .calibrated_sculk_sensor => .calibrated_sculk_sensor,
            .ochre_froglight => .ochre_froglight,
            .verdant_froglight => .verdant_froglight,
            .pearlescent_froglight => .pearlescent_froglight,
            .mangrove_roots => .mangrove_roots,
            .muddy_mangrove_roots => .muddy_mangrove_roots,
            .mangrove_propagule => .mangrove_propagule,
            .mangrove_log => .mangrove_log,
            .mangrove_planks => .mangrove_planks,
            .torchflower_seeds => .torchflower_crop,
            .torchflower => .torchflower,
            .pitcher_pod => .pitcher_plant,
            .pitcher_plant => .pitcher_plant,
            .cherry_log => .cherry_log,
            .cherry_leaves => .cherry_leaves,
            .cherry_planks => .cherry_planks,
            .pink_petals => .pink_petals,
            .chiseled_bookshelf => .chiseled_bookshelf,
            .hanging_sign => .hanging_sign,
            .bamboo_mosaic => .bamboo_mosaic,
            .creaking_heart => .creaking_heart,
            .pale_oak_log => .pale_oak_log,
            .open_eyeblossom => .open_eyeblossom,
            .resin_bricks => .resin_bricks,
            .copper_door => .copper_door_closed,
            .copper_trapdoor => .copper_trapdoor_closed,
            .ominous_vault => .ominous_vault,
            .dried_ghast => .dried_ghast,
            .sculk_catalyst => .sculk_catalyst,
            .sculk_shrieker => .sculk_shrieker,
            .firefly_bush => .firefly_bush,
            .leaf_litter => .leaf_litter,
            else => null,
        };
    }

    pub fn fromBlockId(b: BlockId) ItemType {
        return switch (b) {
            .air => .none,
            .stone => .stone,
            .dirt => .dirt,
            .grass => .grass,
            .water => .water,
            .wood => .wood,
            .leaves => .leaves,
            .wood_planks => .wood_planks,
            .crafting_table => .crafting_bench,
            .cobblestone => .cobblestone,
            .coal_ore => .coal,
            .iron_ore => .iron_ore,
            .sand => .sand,
            .glass => .glass,
            .sandstone => .sandstone,
            .brick => .brick,
            .wool => .wool,
            .furnace => .furnace,
            .snow => .snow_block,
            .ladder => .ladder,
            .tnt => .tnt,
            .torch => .torch,
            .chest => .chest,
            .wooden_door_closed, .wooden_door_open => .wooden_door,
            .pressure_plate_up, .pressure_plate_down => .pressure_plate,
            .redstone_wire_off, .redstone_wire_on => .redstone_dust,
            .lever_off, .lever_on => .lever,
            .repeater_off, .repeater_on => .redstone_repeater,
            .redstone_lamp_off, .redstone_lamp_on => .redstone_lamp,
            .iron_door_closed, .iron_door_open => .iron_door,
            .redstone_torch_off, .redstone_torch_on => .redstone_torch,
            .campfire => .campfire,
            .cactus => .cactus,
            .lava => .lava_bucket,
            .obsidian => .obsidian,
            .nether_portal => .none,
            .netherrack => .netherrack,
            .soul_sand => .soul_sand,
            .magma => .magma,
            .glowstone => .glowstone,
            .nether_quartz_ore => .nether_quartz,
            .quartz_block => .quartz_block,
            .quartz_pillar => .quartz_pillar,
            .chiseled_quartz_block => .chiseled_quartz_block,
            .nether_brick => .nether_brick,
            .nether_brick_fence => .nether_brick_fence,
            .nether_wart => .nether_wart,
            .soul_torch => .soul_torch,
            .soul_campfire => .soul_campfire,
            .spawner_cage => .spawner_cage,
            .wither_skull_block => .wither_skull,
            .beacon => .beacon,
            .ancient_debris => .ancient_debris,
            .respawn_anchor => .respawn_anchor,
            .crying_obsidian => .crying_obsidian,
            .lodestone => .lodestone,
            .basalt => .basalt,
            .blackstone => .blackstone,
            .gilded_blackstone => .gilded_blackstone,
            .weeping_vines => .weeping_vines,
            .twisting_vines => .twisting_vines,
            .target_block => .target_block,
            .hay_bale => .hay_bale,
            .crimson_fungus => .crimson_fungus,
            .warped_fungus => .warped_fungus,
            .shroomlight => .shroomlight,
            .chiseled_nether_brick => .chiseled_nether_brick,
            .dispenser => .dispenser,
            .dropper => .dropper,
            .hopper => .hopper,
            .brewing_stand => .brewing_stand,
            .cauldron => .cauldron,
            .daylight_detector, .daylight_detector_inverted => .daylight_detector,
            .note_block => .note_block,
            .jukebox => .jukebox,
            .oak_fence => .oak_fence,
            .armor_stand => .armor_stand,
            .enchantment_table => .enchantment_table,
            .anvil => .anvil,
            .grindstone => .grindstone,
            .smithing_table => .smithing_table,
            .cartography_table => .cartography_table,
            .fletching_table => .fletching_table,
            .composter => .composter,
            .loom => .loom,
            .smoker => .smoker,
            .blast_furnace => .blast_furnace,
            .stonecutter => .stonecutter,
            .lantern => .lantern,
            .soul_lantern => .soul_lantern,
            .chain => .chain,
            .iron_bars => .iron_bars,
            .tripwire_hook_off, .tripwire_hook_on => .tripwire_hook,
            .tripwire => .string,
            .cobweb => .cobweb,
            .end_stone => .end_stone,
            .end_portal_frame, .end_portal_frame_filled => .end_portal_frame,
            .end_portal => .none,
            .end_crystal => .end_crystal,
            .dragon_egg => .dragon_egg,
            .purpur_block => .purpur_block,
            .purpur_pillar => .purpur_pillar,
            .end_rod => .end_rod,
            .chorus_plant => .chorus_plant,
            .chorus_flower => .chorus_flower,
            .shulker_box => .shulker_box,
            .dragon_head => .dragon_head,
            .end_gateway => .end_gateway,
            .prismarine => .prismarine,
            .prismarine_bricks => .prismarine_bricks,
            .dark_prismarine => .dark_prismarine,
            .sea_lantern => .sea_lantern,
            .conduit => .conduit,
            .sponge => .sponge,
            .wet_sponge => .wet_sponge,
            .kelp => .kelp,
            .dried_kelp_block => .dried_kelp_block,
            .sea_pickle => .sea_pickle,
            .rail => .rail,
            .powered_rail => .powered_rail,
            .detector_rail => .detector_rail,
            .activator_rail => .activator_rail,
            .redstone_comparator_off, .redstone_comparator_on => .redstone_comparator,
            .slime_block => .slime_block,
            .piston => .piston,
            .sticky_piston => .sticky_piston,
            .observer_off, .observer_on => .observer,
            .wooden_trapdoor_closed, .wooden_trapdoor_open => .wooden_trapdoor,
            .iron_trapdoor_closed, .iron_trapdoor_open => .iron_trapdoor,
            .redstone_block => .redstone_block,
            .redstone_ore, .lit_redstone_ore => .redstone_ore,
            .gold_ore => .gold_ore,
            .gold_block => .gold_block,
            .diamond_ore => .diamond_ore,
            .diamond_block => .diamond_block,
            .farmland => .dirt,
            .wheat_crop => .wheat_seeds,
            .bookshelf => .bookshelf,
            .lectern => .lectern,
            .emerald_ore => .emerald_ore,
            .emerald_block => .emerald_block,
            .lapis_ore => .lapis_ore,
            .lapis_block => .lapis_block,
            .beehive => .beehive,
            .honey_block => .honey_block,
            .copper_ore => .copper_ore,
            .copper_block => .copper_block,
            .exposed_copper => .exposed_copper,
            .weathered_copper => .weathered_copper,
            .oxidized_copper => .oxidized_copper,
            .waxed_copper_block => .waxed_copper_block,
            .lightning_rod => .lightning_rod,
            .amethyst_block => .amethyst_block,
            .budding_amethyst => .budding_amethyst,
            .amethyst_cluster => .amethyst_cluster,
            .tinted_glass => .tinted_glass,
            .bell => .bell,
            .sugar_cane => .sugar_cane,
            .pumpkin => .pumpkin,
            .carved_pumpkin => .carved_pumpkin,
            .jack_o_lantern => .jack_o_lantern,
            .sculk => .sculk,
            .sculk_sensor_off, .sculk_sensor_on => .sculk_sensor,
            .deepslate => .cobbled_deepslate,
            .cobbled_deepslate => .cobbled_deepslate,
            .polished_deepslate => .polished_deepslate,
            .deepslate_bricks => .deepslate_bricks,
            .iron_block => .iron_block,
            .cake => .none,
            .melon => .melon_slice,
            .barrel => .barrel,
            .dripstone_block => .dripstone_block,
            .pointed_dripstone => .pointed_dripstone,
            .moss_block => .moss_block,
            .moss_carpet => .moss_carpet,
            .cave_vines => .glow_berries,
            .cave_vines_lit => .glow_berries,
            .clay => .clay_ball,
            .terracotta => .terracotta,
            .flower_pot => .flower_pot,
            .ice => .ice,
            .packed_ice => .packed_ice,
            .blue_ice => .blue_ice,
            .powder_snow => .powder_snow_bucket,
            .bamboo => .bamboo,
            .scaffolding => .scaffolding,
            .sweet_berry_bush => .sweet_berries,
            .ender_chest => .ender_chest,
            .mud => .mud,
            .packed_mud => .packed_mud,
            .mud_bricks => .mud_bricks,
            .copper_bulb_off, .copper_bulb_on => .copper_bulb,
            .chiseled_copper => .chiseled_copper,
            .copper_grate => .copper_grate,
            .suspicious_sand => .sand,
            .decorated_pot => .decorated_pot,
            .heavy_core => .heavy_core,
            .crafter => .crafter,
            .trial_spawner => .trial_spawner,
            .vault => .vault,
            .tuff => .tuff,
            .polished_tuff => .polished_tuff,
            .tuff_bricks => .tuff_bricks,
            .chiseled_tuff => .chiseled_tuff,
            .calibrated_sculk_sensor => .calibrated_sculk_sensor,
            .ochre_froglight => .ochre_froglight,
            .verdant_froglight => .verdant_froglight,
            .pearlescent_froglight => .pearlescent_froglight,
            .mangrove_roots => .mangrove_roots,
            .muddy_mangrove_roots => .muddy_mangrove_roots,
            .mangrove_propagule => .mangrove_propagule,
            .mangrove_log => .mangrove_log,
            .mangrove_planks => .mangrove_planks,
            .torchflower_crop => .torchflower_seeds,
            .torchflower => .torchflower,
            .pitcher_plant => .pitcher_plant,
            .cherry_log => .cherry_log,
            .cherry_leaves => .cherry_leaves,
            .cherry_planks => .cherry_planks,
            .pink_petals => .pink_petals,
            .chiseled_bookshelf => .chiseled_bookshelf,
            .hanging_sign => .hanging_sign,
            .bamboo_mosaic => .bamboo_mosaic,
            .creaking_heart => .creaking_heart,
            .pale_oak_log => .pale_oak_log,
            .open_eyeblossom => .open_eyeblossom,
            .resin_bricks => .resin_bricks,
            .copper_door_closed, .copper_door_open => .copper_door,
            .copper_trapdoor_closed, .copper_trapdoor_open => .copper_trapdoor,
            .ominous_vault => .ominous_vault,
            .piston_head => .piston,
            .dried_ghast => .dried_ghast,
            .sculk_catalyst => .sculk_catalyst,
            .sculk_shrieker => .sculk_shrieker,
            .firefly_bush => .firefly_bush,
            .leaf_litter => .leaf_litter,
        };
    }


    pub fn isArmor(self: ItemType) bool {
        return switch (self) {
            .netherite_helmet, .turtle_helmet, .netherite_chestplate, .elytra, .netherite_leggings, .netherite_boots, .soul_speed_boots, .frost_walker_boots, .dragon_head, .diamond_helmet, .diamond_chestplate, .diamond_leggings, .diamond_boots, .iron_helmet, .iron_chestplate, .iron_leggings, .iron_boots, .golden_helmet, .golden_chestplate, .golden_leggings, .golden_boots, .leather_helmet, .leather_chestplate, .leather_leggings, .leather_boots, .carved_pumpkin, .chainmail_helmet, .chainmail_chestplate, .chainmail_leggings, .chainmail_boots => true,
            else => false,
        };
    }

    pub fn maxDurability(self: ItemType) u16 {
        return switch (self) {
            .wooden_pickaxe => 25,
            .iron_pickaxe => 120,
            .iron_sword => 100,
            .diamond_pickaxe => 250,
            .diamond_sword => 250,
            .diamond_helmet => 360,
            .diamond_chestplate => 420,
            .diamond_leggings => 390,
            .diamond_boots => 340,
            .iron_helmet => 165,
            .iron_chestplate => 240,
            .iron_leggings => 225,
            .iron_boots => 195,
            .frost_walker_boots => 195,
            .golden_helmet => 77,
            .golden_chestplate => 112,
            .golden_leggings => 105,
            .golden_boots => 91,
            .stone_sword => 131,
            .stone_pickaxe => 131,
            .stone_axe => 131,
            .stone_shovel => 131,
            .stone_hoe => 131,
            .golden_sword => 32,
            .golden_pickaxe => 32,
            .golden_axe => 32,
            .golden_shovel => 32,
            .golden_hoe => 32,
            .wooden_sword => 59,
            .leather_helmet => 55,
            .leather_chestplate => 80,
            .leather_leggings => 75,
            .leather_boots => 65,
            .chainmail_helmet => 165,
            .chainmail_chestplate => 240,
            .chainmail_leggings => 225,
            .chainmail_boots => 195,
            .brush => 64,
            .mace => 500,
            .flint_and_steel => 64,
            .wooden_axe => 25,
            .iron_axe => 120,
            .diamond_axe => 250,
            .netherite_axe => 350,
            .wooden_shovel => 25,
            .iron_shovel => 120,
            .diamond_shovel => 250,
            .netherite_shovel => 350,
            .wooden_hoe => 25,
            .iron_hoe => 120,
            .diamond_hoe => 250,
            .netherite_hoe => 350,
            .shears => 238,
            .netherite_pickaxe => 350,
            .netherite_sword => 400,
            .warped_fungus_on_a_stick => 100,
            .netherite_chestplate => 500,
            .soul_speed_boots => 300,
            .netherite_helmet => 450,
            .netherite_leggings => 475,
            .netherite_boots => 425,
            .elytra => 432,
            .turtle_helmet => 275,
            .trident => 250,
            .bow => 384,
            .shield => 336,
            .crossbow => 465,
            .fishing_rod => 64,
            .wolf_armor => 64,
            else => 0,
        };
    }


    pub fn isCompostable(self: ItemType) bool {
        return switch (self) {
            .leaves, .hay_bale, .wheat_seeds, .wheat, .bread, .paper, .sugar_cane, .pumpkin, .carved_pumpkin, .pumpkin_pie, .cake, .melon, .melon_slice, .moss_block, .moss_carpet, .glow_berries, .carrot, .bamboo, .potato, .baked_potato, .beetroot, .cocoa_beans, .cookie, .sweet_berries, .crimson_fungus, .warped_fungus, .weeping_vines, .twisting_vines, .nether_wart, .cactus, .raw_pork, .raw_mutton, .rotten_flesh, .raw_cod, .cooked_cod, .kelp, .dried_kelp, .sea_pickle, .seagrass, .raw_salmon, .cooked_salmon, .pufferfish, .tropical_fish, .cherry_leaves, .pink_petals, .open_eyeblossom => true,
            else => false,
        };
    }

    
    pub fn isHoe(self: ItemType) bool {
        return self == .wooden_hoe or self == .stone_hoe or self == .golden_hoe or self == .iron_hoe or self == .diamond_hoe or self == .netherite_hoe;
    }

    pub fn isShears(self: ItemType) bool {
        return self == .shears;
    }

    pub fn isTool(self: ItemType) bool {
        return self.maxDurability() > 0;
    }

    pub fn maxStackSize(self: ItemType) u8 {
        return switch (self) {
            .none => 0,
            .armor_stand, .target_dummy, .ender_pearl, .dragon_head, .lingering_poison_potion, .lingering_weakness_potion, .water_breathing_potion, .slow_falling_potion, .conduit, .honey_bottle, .healing_potion, .night_vision_potion, .regeneration_potion, .swiftness_potion, .strength_potion, .leaping_potion, .ominous_bottle, .potion_of_infested, .potion_of_oozing, .potion_of_weaving, .potion_of_wind_charged, .potion_of_slowness, .splash_water_bottle, .splash_harming_potion, .water_bottle, .harming_potion, .written_book, .awkward_potion, .invisibility_potion => 16,
            .wooden_pickaxe, .iron_pickaxe, .diamond_pickaxe, .netherite_pickaxe, .iron_sword, .diamond_sword, .netherite_sword, .diamond_helmet, .diamond_chestplate, .diamond_leggings, .diamond_boots, .flint_and_steel, .wooden_axe, .iron_axe, .diamond_axe, .netherite_axe, .wooden_shovel, .iron_shovel, .diamond_shovel, .netherite_shovel, .wooden_hoe, .stone_hoe, .golden_hoe, .iron_hoe, .diamond_hoe, .netherite_hoe, .wooden_sword, .stone_sword, .golden_sword, .stone_pickaxe, .golden_pickaxe, .leather_helmet, .leather_chestplate, .leather_leggings, .leather_boots, .stone_axe, .golden_axe, .stone_shovel, .golden_shovel, .shears, .iron_helmet, .iron_chestplate, .iron_leggings, .iron_boots, .golden_helmet, .golden_chestplate, .golden_leggings, .golden_boots, .warped_fungus_on_a_stick, .netherite_chestplate, .elytra, .soul_speed_boots, .frost_walker_boots, .netherite_helmet, .turtle_helmet, .trident, .netherite_leggings, .netherite_boots, .bow, .shield, .lodestone_compass, .crossbow, .music_disc_13, .music_disc_cat, .fishing_rod, .minecart, .chest_minecart, .furnace_minecart, .tnt_minecart, .hopper_minecart, .spyglass, .recovery_compass, .cake, .totem_of_undying, .powder_snow_bucket, .beetroot_soup, .mushroom_stew, .chainmail_helmet, .chainmail_chestplate, .chainmail_leggings, .chainmail_boots, .brush, .mace, .suspicious_stew, .goat_horn, .wolf_armor, .bundle, .ghast_harness, .bucket_of_axolotl, .banner, .banner_pattern_stencil, .copper_golem_statue, .music_disc_5, .music_disc_relic, .music_disc_precipice, .music_disc_creator, .enchanted_book, .mending_book, .swift_sneak_book, .sweeping_edge_book, .feather_falling_book, .milk_bucket, .raid_omen_banner, .evoker_fang_totem, .saddle, .empty_locator_map, .filled_explorer_map, .leather_horse_armor, .iron_horse_armor, .golden_horse_armor, .diamond_horse_armor, .item_frame, .glow_item_frame, .painting, .buried_treasure_map, .music_disc_pigstep, .bucket_of_tadpole, .book_and_quill, .chest_boat, .bamboo_raft, .bed => 1,
            .wither_rose, .glazed_terracotta, .light_weighted_pressure_plate, .heavy_weighted_pressure_plate, .glass_pane, .stained_glass, .arrow_of_slowness => 64,
            .potion_of_turtle_master => 16,
            else => 64,
        };
    }

    pub fn name(self: ItemType) []const u8 {
        return switch (self) {
            .none => "Empty",
            .stone => "Stone",
            .dirt => "Dirt",
            .grass => "Grass",
            .water => "Water",
            .wood => "Wood Log",
            .leaves => "Leaves",
            .wood_planks => "Wood Planks",
            .stick => "Stick",
            .wooden_pickaxe => "Wooden Pickaxe",
            .crafting_bench => "Crafting Table",
            .cobblestone => "Cobblestone",
            .coal => "Coal",
            .iron_ore => "Iron Ore",
            .sand => "Sand",
            .glass => "Glass",
            .sandstone => "Sandstone",
            .brick => "Bricks",
            .wool => "Wool",
            .apple => "Apple",
            .sapling => "Sapling",
            .furnace => "Furnace",
            .iron_ingot => "Iron Ingot",
            .iron_pickaxe => "Iron Pickaxe",
            .snowball => "Snowball",
            .snow_block => "Snow Block",
            .golden_apple => "Golden Apple",
            .iron_sword => "Iron Sword",
            .ladder => "Ladder",
            .tnt => "TNT",
            .torch => "Torch",
            .chest => "Chest",
            .wooden_door => "Wooden Door",
            .pressure_plate => "Pressure Plate",
            .redstone_dust => "Redstone Dust",
            .lever => "Lever",
            .redstone_repeater => "Redstone Repeater",
            .redstone_lamp => "Redstone Lamp",
            .iron_door => "Iron Door",
            .redstone_torch => "Redstone Torch",
            .campfire => "Campfire",
            .cactus => "Cactus",
            .boat => "Wooden Boat",
            .lava_bucket => "Lava Bucket",
            .obsidian => "Obsidian",
            .netherrack => "Netherrack",
            .soul_sand => "Soul Sand",
            .magma => "Magma Block",
            .fire_resistance_potion => "Fire Resistance Potion",
            .glowstone => "Glowstone",
            .nether_quartz_ore => "Nether Quartz Ore",
            .nether_quartz => "Nether Quartz",
            .quartz_block => "Block of Quartz",
            .quartz_pillar => "Quartz Pillar",
            .chiseled_quartz_block => "Chiseled Quartz Block",
            .nether_brick => "Nether Bricks",
            .nether_brick_fence => "Nether Brick Fence",
            .nether_wart => "Nether Wart",
            .magma_cream => "Magma Cream",
            .fire_charge => "Fire Charge",
            .soul_torch => "Soul Torch",
            .soul_campfire => "Soul Campfire",
            .spawner_cage => "Monster Spawner",
            .wither_skull => "Wither Skeleton Skull",
            .nether_star => "Nether Star",
            .beacon => "Beacon",
            .ancient_debris => "Ancient Debris",
            .netherite_scrap => "Netherite Scrap",
            .netherite_ingot => "Netherite Ingot",
            .netherite_pickaxe => "Netherite Pickaxe",
            .netherite_sword => "Netherite Sword",
            .respawn_anchor => "Respawn Anchor",
            .crying_obsidian => "Crying Obsidian",
            .lodestone => "Lodestone",
            .basalt => "Basalt",
            .blackstone => "Blackstone",
            .gilded_blackstone => "Gilded Blackstone",
            .gold_nugget => "Gold Nugget",
            .weeping_vines => "Weeping Vines",
            .twisting_vines => "Twisting Vines",
            .target_block => "Target Block",
            .hay_bale => "Hay Bale",
            .crimson_fungus => "Crimson Fungus",
            .warped_fungus => "Warped Fungus",
            .shroomlight => "Shroomlight",
            .warped_fungus_on_a_stick => "Warped Fungus on a Stick",
            .netherite_chestplate => "Netherite Chestplate",
            .soul_speed_boots => "Soul Speed Boots",
            .netherite_helmet => "Netherite Helmet",
            .netherite_leggings => "Netherite Leggings",
            .chiseled_nether_brick => "Chiseled Nether Brick",
            .netherite_boots => "Netherite Boots",
            .spectral_arrow => "Spectral Arrow",
            .arrow => "Arrow",
            .bow => "Bow",
            .shield => "Shield",
            .compass => "Compass",
            .lodestone_compass => "Lodestone Compass",
            .crossbow => "Crossbow",
            .fireworks_rocket => "Fireworks Rocket",
            .dispenser => "Dispenser",
            .dropper => "Dropper",
            .hopper => "Hopper",
            .blaze_rod => "Blaze Rod",
            .blaze_powder => "Blaze Powder",
            .brewing_stand => "Brewing Stand",
            .cauldron => "Cauldron",
            .water_bucket => "Water Bucket",
            .daylight_detector => "Daylight Detector",
            .note_block => "Note Block",
            .jukebox => "Jukebox",
            .music_disc_13 => "Music Disc (13)",
            .music_disc_cat => "Music Disc (cat)",
            .oak_fence => "Oak Fence",
            .lead => "Lead",
            .armor_stand => "Armor Stand",
            .target_dummy => "Target Dummy",
            .enchantment_table => "Enchantment Table",
            .anvil => "Anvil",
            .grindstone => "Grindstone",
            .smithing_table => "Smithing Table",
            .cartography_table => "Cartography Table",
            .fletching_table => "Fletching Table",
            .composter => "Composter",
            .bone_meal => "Bone Meal",
            .loom => "Loom",
            .smoker => "Smoker",
            .blast_furnace => "Blast Furnace",
            .stonecutter => "Stonecutter",
            .lantern => "Lantern",
            .soul_lantern => "Soul Lantern",
            .chain => "Chain",
            .iron_bars => "Iron Bars",
            .tripwire_hook => "Tripwire Hook",
            .string => "String",
            .cobweb => "Cobweb",
            .spider_eye => "Spider Eye",
            .poison_potion => "Potion of Poison",
            .fermented_spider_eye => "Fermented Spider Eye",
            .weakness_potion => "Potion of Weakness",
            .bone => "Bone",
            .rotten_flesh => "Rotten Flesh",
            .gunpowder => "Gunpowder",
            .ender_pearl => "Ender Pearl",
            .eye_of_ender => "Eye of Ender",
            .end_stone => "End Stone",
            .end_portal_frame => "End Portal Frame",
            .end_crystal => "End Crystal",
            .dragon_egg => "Dragon Egg",
            .purpur_block => "Purpur Block",
            .purpur_pillar => "Purpur Pillar",
            .end_rod => "End Rod",
            .chorus_fruit => "Chorus Fruit",
            .popped_chorus_fruit => "Popped Chorus Fruit",
            .chorus_flower => "Chorus Flower",
            .chorus_plant => "Chorus Plant",
            .shulker_shell => "Shulker Shell",
            .shulker_box => "Shulker Box",
            .elytra => "Elytra",
            .dragon_head => "Dragon Head",
            .end_gateway => "End Gateway",
            .dragons_breath => "Dragon's Breath",
            .lingering_poison_potion => "Lingering Potion of Poison",
            .lingering_weakness_potion => "Lingering Potion of Weakness",
            .scute => "Scute",
            .turtle_helmet => "Turtle Shell Helmet",
            .water_breathing_potion => "Potion of Water Breathing",
            .trident => "Trident",
            .phantom_membrane => "Phantom Membrane",
            .slow_falling_potion => "Potion of Slow Falling",
            .prismarine_shard => "Prismarine Shard",
            .prismarine_crystals => "Prismarine Crystals",
            .heart_of_the_sea => "Heart of the Sea",
            .prismarine => "Prismarine",
            .prismarine_bricks => "Prismarine Bricks",
            .dark_prismarine => "Dark Prismarine",
            .sea_lantern => "Sea Lantern",
            .conduit => "Conduit",
            .sponge => "Sponge",
            .wet_sponge => "Wet Sponge",
            .raw_cod => "Raw Cod",
            .cooked_cod => "Cooked Cod",
            .fishing_rod => "Fishing Rod",
            .kelp => "Kelp",
            .dried_kelp => "Dried Kelp",
            .dried_kelp_block => "Dried Kelp Block",
            .sea_pickle => "Sea Pickle",
            .raw_salmon => "Raw Salmon",
            .cooked_salmon => "Cooked Salmon",
            .pufferfish => "Pufferfish",
            .tropical_fish => "Tropical Fish",
            .nautilus_shell => "Nautilus Shell",
            .rail => "Rail",
            .powered_rail => "Powered Rail",
            .minecart => "Minecart",
            .detector_rail => "Detector Rail",
            .activator_rail => "Activator Rail",
            .chest_minecart => "Minecart with Chest",
            .furnace_minecart => "Minecart with Furnace",
            .tnt_minecart => "Minecart with TNT",
            .hopper_minecart => "Minecart with Hopper",
            .redstone_comparator => "Redstone Comparator",
            .slimeball => "Slimeball",
            .slime_block => "Slime Block",
            .piston => "Piston",
            .sticky_piston => "Sticky Piston",
            .observer => "Observer",
            .wooden_trapdoor => "Wooden Trapdoor",
            .iron_trapdoor => "Iron Trapdoor",
            .redstone_block => "Block of Redstone",
            .redstone_ore => "Redstone Ore",
            .gold_ore => "Gold Ore",
            .gold_block => "Block of Gold",
            .diamond => "Diamond",
            .diamond_ore => "Diamond Ore",
            .diamond_block => "Block of Diamond",
            .diamond_sword => "Diamond Sword",
            .diamond_pickaxe => "Diamond Pickaxe",
            .diamond_helmet => "Diamond Helmet",
            .diamond_chestplate => "Diamond Chestplate",
            .diamond_leggings => "Diamond Leggings",
            .diamond_boots => "Diamond Boots",
            .flint => "Flint",
            .flint_and_steel => "Flint and Steel",
            .wooden_axe => "Wooden Axe",
            .iron_axe => "Iron Axe",
            .diamond_axe => "Diamond Axe",
            .netherite_axe => "Netherite Axe",
            .wooden_shovel => "Wooden Shovel",
            .iron_shovel => "Iron Shovel",
            .diamond_shovel => "Diamond Shovel",
            .netherite_shovel => "Netherite Shovel",
            .wooden_hoe => "Wooden Hoe",
            .iron_hoe => "Iron Hoe",
            .diamond_hoe => "Diamond Hoe",
            .netherite_hoe => "Netherite Hoe",
            .shears => "Shears",
            .iron_helmet => "Iron Helmet",
            .iron_chestplate => "Iron Chestplate",
            .iron_leggings => "Iron Leggings",
            .iron_boots => "Iron Boots",
            .golden_helmet => "Golden Helmet",
            .golden_chestplate => "Golden Chestplate",
            .golden_leggings => "Golden Leggings",
            .golden_boots => "Golden Boots",
            .stone_sword => "Stone Sword",
            .stone_pickaxe => "Stone Pickaxe",
            .stone_axe => "Stone Axe",
            .stone_shovel => "Stone Shovel",
            .stone_hoe => "Stone Hoe",
            .golden_sword => "Golden Sword",
            .golden_pickaxe => "Golden Pickaxe",
            .golden_axe => "Golden Axe",
            .golden_shovel => "Golden Shovel",
            .golden_hoe => "Golden Hoe",
            .wooden_sword => "Wooden Sword",
            .leather => "Leather",
            .leather_helmet => "Leather Cap",
            .leather_chestplate => "Leather Tunic",
            .leather_leggings => "Leather Pants",
            .leather_boots => "Leather Boots",
            .farmland => "Farmland",
            .wheat_seeds => "Wheat Seeds",
            .wheat => "Wheat",
            .bread => "Bread",
            .paper => "Paper",
            .book => "Book",
            .bookshelf => "Bookshelf",
            .lectern => "Lectern",
            .emerald => "Emerald",
            .emerald_ore => "Emerald Ore",
            .emerald_block => "Block of Emerald",
            .lapis_lazuli => "Lapis Lazuli",
            .lapis_ore => "Lapis Lazuli Ore",
            .lapis_block => "Block of Lapis Lazuli",
            .honeycomb => "Honeycomb",
            .honey_bottle => "Honey Bottle",
            .beehive => "Beehive",
            .honey_block => "Honey Block",
            .raw_copper => "Raw Copper",
            .copper_ingot => "Copper Ingot",
            .copper_ore => "Copper Ore",
            .copper_block => "Block of Copper",
            .exposed_copper => "Exposed Copper",
            .weathered_copper => "Weathered Copper",
            .oxidized_copper => "Oxidized Copper",
            .waxed_copper_block => "Waxed Block of Copper",
            .lightning_rod => "Lightning Rod",
            .spyglass => "Spyglass",
            .amethyst_shard => "Amethyst Shard",
            .amethyst_block => "Block of Amethyst",
            .budding_amethyst => "Budding Amethyst",
            .amethyst_cluster => "Amethyst Cluster",
            .tinted_glass => "Tinted Glass",
            .bell => "Bell",
            .sugar_cane => "Sugar Cane",
            .sugar => "Sugar",
            .pumpkin => "Pumpkin",
            .carved_pumpkin => "Carved Pumpkin",
            .jack_o_lantern => "Jack o'Lantern",
            .pumpkin_pie => "Pumpkin Pie",
            .sculk => "Sculk",
            .sculk_sensor => "Sculk Sensor",
            .echo_shard => "Echo Shard",
            .recovery_compass => "Recovery Compass",
            .deepslate => "Deepslate",
            .cobbled_deepslate => "Cobbled Deepslate",
            .polished_deepslate => "Polished Deepslate",
            .deepslate_bricks => "Deepslate Bricks",
            .iron_block => "Block of Iron",
            .cake => "Cake",
            .melon => "Melon",
            .melon_slice => "Melon Slice",
            .glistering_melon => "Glistering Melon Slice",
            .healing_potion => "Potion of Healing",
            .barrel => "Barrel",
            .dripstone_block => "Dripstone Block",
            .pointed_dripstone => "Pointed Dripstone",
            .moss_block => "Moss Block",
            .moss_carpet => "Moss Carpet",
            .glow_berries => "Glow Berries",
            .clay_ball => "Clay Ball",
            .clay => "Clay",
            .terracotta => "Terracotta",
            .brick_item => "Brick",
            .flower_pot => "Flower Pot",
            .totem_of_undying => "Totem of Undying",
            .carrot => "Carrot",
            .golden_carrot => "Golden Carrot",
            .night_vision_potion => "Potion of Night Vision",
            .ghast_tear => "Ghast Tear",
            .regeneration_potion => "Potion of Regeneration",
            .ice => "Ice",
            .packed_ice => "Packed Ice",
            .blue_ice => "Blue Ice",
            .powder_snow_bucket => "Powder Snow Bucket",
            .bamboo => "Bamboo",
            .scaffolding => "Scaffolding",
            .potato => "Potato",
            .baked_potato => "Baked Potato",
            .poisonous_potato => "Poisonous Potato",
            .beetroot => "Beetroot",
            .bowl => "Bowl",
            .beetroot_soup => "Beetroot Soup",
            .mushroom_stew => "Mushroom Stew",
            .rabbit_foot => "Rabbit's Foot",
            .swiftness_potion => "Potion of Swiftness",
            .strength_potion => "Potion of Strength",
            .leaping_potion => "Potion of Leaping",
            .cocoa_beans => "Cocoa Beans",
            .cookie => "Cookie",
            .sweet_berries => "Sweet Berries",
            .ender_chest => "Ender Chest",
            .chainmail_helmet => "Chainmail Helmet",
            .chainmail_chestplate => "Chainmail Chestplate",
            .chainmail_leggings => "Chainmail Leggings",
            .chainmail_boots => "Chainmail Boots",
            .mud => "Mud",
            .packed_mud => "Packed Mud",
            .mud_bricks => "Mud Bricks",
            .copper_bulb => "Copper Bulb",
            .chiseled_copper => "Chiseled Copper",
            .copper_grate => "Copper Grate",
            .brush => "Brush",
            .suspicious_sand => "Suspicious Sand",
            .pottery_sherd => "Pottery Sherd",
            .decorated_pot => "Decorated Pot",
            .breeze_rod => "Breeze Rod",
            .wind_charge => "Wind Charge",
            .heavy_core => "Heavy Core",
            .mace => "Mace",
            .crafter => "Crafter",
            .trial_key => "Trial Key",
            .trial_spawner => "Trial Spawner",
            .vault => "Vault",
            .enchanted_golden_apple => "Enchanted Golden Apple",
            .suspicious_stew => "Suspicious Stew",
            .tuff => "Tuff",
            .polished_tuff => "Polished Tuff",
            .tuff_bricks => "Tuff Bricks",
            .chiseled_tuff => "Chiseled Tuff",
            .calibrated_sculk_sensor => "Calibrated Sculk Sensor",
            .ochre_froglight => "Ochre Froglight",
            .verdant_froglight => "Verdant Froglight",
            .pearlescent_froglight => "Pearlescent Froglight",
            .mangrove_roots => "Mangrove Roots",
            .muddy_mangrove_roots => "Muddy Mangrove Roots",
            .mangrove_propagule => "Mangrove Propagule",
            .mangrove_log => "Mangrove Log",
            .mangrove_planks => "Mangrove Planks",
            .goat_horn => "Goat Horn",
            .armor_trim_template => "Armor Trim Smithing Template",
            .torchflower_seeds => "Torchflower Seeds",
            .torchflower => "Torchflower",
            .pitcher_pod => "Pitcher Pod",
            .pitcher_plant => "Pitcher Plant",
            .cherry_log => "Cherry Log",
            .cherry_leaves => "Cherry Leaves",
            .cherry_planks => "Cherry Planks",
            .pink_petals => "Pink Petals",
            .chiseled_bookshelf => "Chiseled Bookshelf",
            .hanging_sign => "Hanging Sign",
            .bamboo_mosaic => "Bamboo Mosaic",
            .creaking_heart => "Creaking Heart",
            .pale_oak_log => "Pale Oak Log",
            .open_eyeblossom => "Open Eyeblossom",
            .resin_bricks => "Resin Bricks",
            .resin_clump => "Resin Clump",
            .resin_brick => "Resin Brick",
            .armadillo_scute => "Armadillo Scute",
            .wolf_armor => "Wolf Armor",
            .ominous_bottle => "Ominous Bottle",
            .ominous_trial_key => "Ominous Trial Key",
            .ominous_vault => "Ominous Vault",
            .potion_of_infested => "Potion of Infested",
            .potion_of_oozing => "Potion of Oozing",
            .potion_of_weaving => "Potion of Weaving",
            .potion_of_wind_charged => "Potion of Wind Charged",
            .bundle => "Bundle",
            .copper_door => "Copper Door",
            .copper_trapdoor => "Copper Trapdoor",
            .disc_fragment_5 => "Disc Fragment (5)",
            .music_disc_5 => "Music Disc (5)",
            .music_disc_relic => "Music Disc (Relic)",
            .music_disc_precipice => "Music Disc (Precipice)",
            .music_disc_creator => "Music Disc (Creator)",
            .dried_ghast => "Dried Ghast",
            .ghast_harness => "Ghast Harness",
            .sculk_catalyst => "Sculk Catalyst",
            .sculk_shrieker => "Sculk Shrieker",
            .bucket_of_axolotl => "Bucket of Axolotl",
            .banner => "Banner",
            .banner_pattern_stencil => "Banner Pattern Stencil",
            .copper_golem_statue => "Copper Golem Statue",
            .firefly_bush => "Firefly Bush",
            .leaf_litter => "Leaf Litter",
            .enchanted_book => "Enchanted Book",
            .mending_book => "Mending Book",
            .raid_omen_banner => "Raid Omen Banner",
            .evoker_fang_totem => "Evoker Fang Totem",
            .turtle_egg => "Turtle Egg",
            .seagrass => "Seagrass",
            .potion_of_turtle_master => "Potion of the Turtle Master",
            .sweet_berry_fox_treat => "Sweet Berry Fox Treat",
            .zombie_head => "Zombie Head",
            .skeleton_skull => "Skeleton Skull",
            .creeper_head => "Creeper Head",
            .piglin_head => "Piglin Head",
            .splash_water_bottle => "Splash Water Bottle",
            .splash_harming_potion => "Splash Potion of Harming",
            .water_bottle => "Water Bottle",
            .harming_potion => "Potion of Harming",
            .wither_rose => "Wither Rose",
            .glazed_terracotta => "Glazed Terracotta",
            .name_tag => "Name Tag",
            .saddle => "Saddle",
            .light_weighted_pressure_plate => "Light Weighted Pressure Plate",
            .heavy_weighted_pressure_plate => "Heavy Weighted Pressure Plate",
            .empty_locator_map => "Empty Locator Map",
            .filled_explorer_map => "Explorer Map",
            .glass_pane => "Glass Pane",
            .leather_horse_armor => "Leather Horse Armor",
            .iron_horse_armor => "Iron Horse Armor",
            .golden_horse_armor => "Golden Horse Armor",
            .diamond_horse_armor => "Diamond Horse Armor",
            .frost_walker_boots => "Frost Walker Boots",
            .swift_sneak_book => "Swift Sneak Book",
            .reinforced_deepslate => "Reinforced Deepslate",
            .milk_bucket => "Milk Bucket",
            .bottle_o_enchanting => "Bottle o' Enchanting",
            .sweeping_edge_book => "Sweeping Edge Book",
            .arrow_of_slowness => "Arrow of Slowness",
            .item_frame => "Item Frame",
            .glow_item_frame => "Glow Item Frame",
            .painting => "Painting",
            .feather_falling_book => "Feather Falling Book",
            .stained_glass => "Stained Glass",
            .potion_of_slowness => "Potion of Slowness",
            .red_sandstone => "Red Sandstone",
            .concrete_powder => "Concrete Powder",
            .concrete_block => "Concrete",
            .buried_treasure_map => "Buried Treasure Map",
            .firework_star => "Firework Star",
            .acacia_planks => "Acacia Planks",
            .dark_oak_planks => "Dark Oak Planks",
            .music_disc_pigstep => "Music Disc Pigstep",
            .netherite_upgrade_template => "Netherite Upgrade Template",
            .sniffer_egg => "Sniffer Egg",
            .suspicious_gravel => "Suspicious Gravel",
            .coral_block => "Coral Block",
            .dead_coral_block => "Dead Coral Block",
            .lily_pad => "Lily Pad",
            .frogspawn => "Frogspawn",
            .bucket_of_tadpole => "Bucket of Tadpole",
            .book_and_quill => "Book and Quill",
            .written_book => "Written Book",
            .bone_block => "Bone Block",
            .calcite => "Calcite",
            .smooth_basalt => "Smooth Basalt",
            .rooted_dirt => "Rooted Dirt",
            .hanging_roots => "Hanging Roots",
            .big_dripleaf => "Big Dripleaf",
            .spore_blossom => "Spore Blossom",
            .awkward_potion => "Awkward Potion",
            .invisibility_potion => "Potion of Invisibility",
            .clock => "Clock",
            .sunflower => "Sunflower",
            .lilac => "Lilac",
            .rose_bush => "Rose Bush",
            .peony => "Peony",
            .podzol => "Podzol",
            .mossy_cobblestone => "Mossy Cobblestone",
            .birch_planks => "Birch Planks",
            .spruce_planks => "Spruce Planks",
            .chest_boat => "Chest Boat",
            .bamboo_raft => "Bamboo Raft",
            .bed => "Bed",
            .raw_pork => "Raw Pork",
            .raw_mutton => "Raw Mutton",
            .cooked_pork => "Cooked Pork",
            .cooked_mutton => "Cooked Mutton",
        };
    }

    pub fn getColor(self: ItemType) [4]f32 {
        return switch (self) {
            .none => .{ 0.0, 0.0, 0.0, 0.0 },
            .stone => .{ 0.6, 0.6, 0.62, 0.95 },
            .dirt => .{ 0.55, 0.35, 0.2, 0.95 },
            .grass => .{ 0.25, 0.75, 0.25, 0.95 },
            .water => .{ 0.2, 0.45, 0.85, 0.95 },
            .wood => .{ 0.45, 0.28, 0.12, 0.95 },
            .leaves => .{ 0.15, 0.55, 0.15, 0.95 },
            .wood_planks => .{ 0.80, 0.62, 0.35, 0.95 },
            .stick => .{ 0.60, 0.45, 0.22, 0.95 },
            .wooden_pickaxe => .{ 0.85, 0.70, 0.40, 0.95 },
            .crafting_bench => .{ 0.75, 0.50, 0.25, 0.95 },
            .cobblestone => .{ 0.5, 0.5, 0.53, 0.95 },
            .coal => .{ 0.12, 0.12, 0.14, 0.95 },
            .iron_ore => .{ 0.72, 0.55, 0.42, 0.95 },
            .weeping_vines => .{ 0.75, 0.15, 0.22, 0.95 },
            .twisting_vines => .{ 0.15, 0.65, 0.60, 0.95 },
            .target_block => .{ 0.88, 0.22, 0.22, 0.95 },
            .hay_bale => .{ 0.85, 0.75, 0.25, 0.95 },
            .crimson_fungus => .{ 0.85, 0.15, 0.20, 0.95 },
            .warped_fungus => .{ 0.12, 0.70, 0.65, 0.95 },
            .shroomlight => .{ 0.98, 0.78, 0.45, 0.95 },
            .warped_fungus_on_a_stick => .{ 0.15, 0.75, 0.70, 0.95 },
            .netherite_chestplate => .{ 0.25, 0.22, 0.26, 0.95 },
            .soul_speed_boots => .{ 0.20, 0.85, 0.90, 0.95 },
            .netherite_helmet => .{ 0.26, 0.23, 0.28, 0.95 },
            .netherite_leggings => .{ 0.24, 0.21, 0.25, 0.95 },
            .chiseled_nether_brick => .{ 0.35, 0.15, 0.18, 0.95 },
            .netherite_boots => .{ 0.22, 0.20, 0.24, 0.95 },
            .spectral_arrow => .{ 1.0, 0.90, 0.25, 0.95 },
            .arrow => .{ 0.75, 0.75, 0.78, 0.95 },
            .bow => .{ 0.55, 0.38, 0.20, 0.95 },
            .shield => .{ 0.65, 0.62, 0.60, 0.95 },
            .compass => .{ 0.78, 0.75, 0.72, 0.95 },
            .lodestone_compass => .{ 0.35, 0.85, 0.95, 0.95 },
            .crossbow => .{ 0.48, 0.35, 0.22, 0.95 },
            .fireworks_rocket => .{ 0.92, 0.25, 0.30, 0.95 },
            .dispenser => .{ 0.55, 0.55, 0.58, 0.95 },
            .dropper => .{ 0.62, 0.62, 0.64, 0.95 },
            .hopper => .{ 0.38, 0.38, 0.40, 0.95 },
            .blaze_rod => .{ 1.0, 0.72, 0.15, 0.95 },
            .blaze_powder => .{ 0.95, 0.55, 0.10, 0.95 },
            .brewing_stand => .{ 0.88, 0.65, 0.22, 0.95 },
            .cauldron => .{ 0.32, 0.32, 0.35, 0.95 },
            .water_bucket => .{ 0.25, 0.50, 0.90, 0.95 },
            .daylight_detector => .{ 0.85, 0.75, 0.45, 0.95 },
            .note_block => .{ 0.70, 0.45, 0.25, 0.95 },
            .jukebox => .{ 0.55, 0.32, 0.18, 0.95 },
            .music_disc_13 => .{ 0.95, 0.82, 0.20, 0.95 },
            .music_disc_cat => .{ 0.20, 0.75, 0.40, 0.95 },
            .oak_fence => .{ 0.65, 0.48, 0.28, 0.95 },
            .lead => .{ 0.85, 0.75, 0.55, 0.95 },
            .armor_stand => .{ 0.75, 0.60, 0.42, 0.95 },
            .target_dummy => .{ 0.90, 0.80, 0.35, 0.95 },
            .enchantment_table => .{ 0.60, 0.20, 0.70, 0.95 },
            .anvil => .{ 0.35, 0.35, 0.38, 0.95 },
            .grindstone => .{ 0.65, 0.60, 0.55, 0.95 },
            .smithing_table => .{ 0.30, 0.35, 0.42, 0.95 },
            .cartography_table => .{ 0.85, 0.78, 0.58, 0.95 },
            .fletching_table => .{ 0.78, 0.68, 0.50, 0.95 },
            .composter => .{ 0.58, 0.42, 0.28, 0.95 },
            .bone_meal => .{ 0.92, 0.92, 0.88, 0.95 },
            .loom => .{ 0.65, 0.52, 0.38, 0.95 },
            .smoker => .{ 0.40, 0.38, 0.36, 0.95 },
            .blast_furnace => .{ 0.30, 0.32, 0.34, 0.95 },
            .stonecutter => .{ 0.50, 0.50, 0.52, 0.95 },
            .lantern => .{ 0.95, 0.75, 0.35, 0.95 },
            .soul_lantern => .{ 0.35, 0.75, 0.85, 0.95 },
            .chain => .{ 0.45, 0.45, 0.48, 0.95 },
            .iron_bars => .{ 0.70, 0.70, 0.72, 0.95 },
            .tripwire_hook => .{ 0.65, 0.50, 0.30, 0.95 },
            .string => .{ 0.90, 0.90, 0.92, 0.95 },
            .cobweb => .{ 0.85, 0.85, 0.88, 0.95 },
            .spider_eye => .{ 0.65, 0.12, 0.18, 0.95 },
            .poison_potion => .{ 0.35, 0.68, 0.22, 0.90 },
            .fermented_spider_eye => .{ 0.45, 0.12, 0.22, 0.95 },
            .weakness_potion => .{ 0.42, 0.40, 0.48, 0.90 },
            .bone => .{ 0.88, 0.86, 0.80, 0.95 },
            .rotten_flesh => .{ 0.60, 0.38, 0.22, 0.95 },
            .gunpowder => .{ 0.38, 0.40, 0.42, 0.95 },
            .ender_pearl => .{ 0.12, 0.45, 0.42, 0.95 },
            .eye_of_ender => .{ 0.18, 0.65, 0.48, 0.95 },
            .end_stone => .{ 0.92, 0.90, 0.65, 0.95 },
            .end_portal_frame => .{ 0.18, 0.42, 0.35, 0.95 },
            .end_crystal => .{ 0.85, 0.30, 0.90, 0.95 },
            .dragon_egg => .{ 0.22, 0.10, 0.28, 0.98 },
            .purpur_block => .{ 0.68, 0.44, 0.68, 0.95 },
            .purpur_pillar => .{ 0.72, 0.48, 0.72, 0.95 },
            .end_rod => .{ 0.95, 0.95, 0.98, 0.95 },
            .chorus_fruit => .{ 0.78, 0.52, 0.78, 0.95 },
            .popped_chorus_fruit => .{ 0.85, 0.60, 0.70, 0.95 },
            .chorus_flower => .{ 0.90, 0.80, 0.92, 0.95 },
            .chorus_plant => .{ 0.60, 0.38, 0.60, 0.95 },
            .shulker_shell => .{ 0.68, 0.44, 0.68, 0.95 },
            .shulker_box => .{ 0.72, 0.48, 0.72, 0.98 },
            .elytra => .{ 0.42, 0.46, 0.54, 0.95 },
            .dragon_head => .{ 0.18, 0.16, 0.20, 0.98 },
            .end_gateway => .{ 0.65, 0.20, 0.95, 0.98 },
            .dragons_breath => .{ 0.85, 0.35, 0.88, 0.95 },
            .lingering_poison_potion => .{ 0.40, 0.85, 0.25, 0.92 },
            .lingering_weakness_potion => .{ 0.50, 0.45, 0.60, 0.92 },
            .scute => .{ 0.22, 0.58, 0.35, 0.95 },
            .turtle_helmet => .{ 0.18, 0.62, 0.32, 0.98 },
            .water_breathing_potion => .{ 0.15, 0.65, 0.85, 0.90 },
            .trident => .{ 0.12, 0.65, 0.60, 0.98 },
            .phantom_membrane => .{ 0.70, 0.75, 0.65, 0.85 },
            .slow_falling_potion => .{ 0.88, 0.82, 0.75, 0.90 },
            .prismarine_shard => .{ 0.40, 0.75, 0.70, 0.95 },
            .prismarine_crystals => .{ 0.75, 0.95, 0.90, 0.95 },
            .heart_of_the_sea => .{ 0.15, 0.45, 0.90, 0.98 },
            .prismarine => .{ 0.38, 0.65, 0.62, 0.98 },
            .prismarine_bricks => .{ 0.35, 0.68, 0.65, 0.98 },
            .dark_prismarine => .{ 0.20, 0.38, 0.36, 0.98 },
            .sea_lantern => .{ 0.82, 0.95, 0.92, 0.98 },
            .conduit => .{ 0.90, 0.60, 0.45, 0.98 },
            .sponge => .{ 0.85, 0.80, 0.30, 0.98 },
            .wet_sponge => .{ 0.65, 0.68, 0.28, 0.98 },
            .raw_cod => .{ 0.72, 0.60, 0.50, 0.95 },
            .cooked_cod => .{ 0.85, 0.68, 0.42, 0.95 },
            .fishing_rod => .{ 0.55, 0.40, 0.22, 0.95 },
            .kelp => .{ 0.22, 0.55, 0.20, 0.95 },
            .dried_kelp => .{ 0.18, 0.35, 0.16, 0.95 },
            .dried_kelp_block => .{ 0.15, 0.32, 0.14, 0.98 },
            .sea_pickle => .{ 0.40, 0.65, 0.25, 0.95 },
            .raw_salmon => .{ 0.85, 0.42, 0.38, 0.95 },
            .cooked_salmon => .{ 0.90, 0.55, 0.45, 0.95 },
            .pufferfish => .{ 0.88, 0.78, 0.25, 0.95 },
            .tropical_fish => .{ 0.95, 0.50, 0.15, 0.95 },
            .nautilus_shell => .{ 0.88, 0.82, 0.72, 0.95 },
            .rail => .{ 0.75, 0.75, 0.75, 0.95 },
            .powered_rail => .{ 0.95, 0.75, 0.20, 0.95 },
            .minecart => .{ 0.60, 0.60, 0.65, 0.95 },
            .detector_rail => .{ 0.85, 0.35, 0.30, 0.95 },
            .activator_rail => .{ 0.70, 0.55, 0.35, 0.95 },
            .chest_minecart => .{ 0.65, 0.55, 0.35, 0.95 },
            .furnace_minecart => .{ 0.45, 0.45, 0.48, 0.95 },
            .tnt_minecart => .{ 0.85, 0.25, 0.20, 0.95 },
            .hopper_minecart => .{ 0.40, 0.40, 0.45, 0.95 },
            .redstone_comparator => .{ 0.90, 0.88, 0.85, 0.95 },
            .slimeball => .{ 0.45, 0.82, 0.35, 0.95 },
            .slime_block => .{ 0.40, 0.85, 0.30, 0.80 },
            .piston => .{ 0.65, 0.55, 0.40, 0.95 },
            .sticky_piston => .{ 0.55, 0.70, 0.40, 0.95 },
            .observer => .{ 0.45, 0.45, 0.48, 0.95 },
            .wooden_trapdoor => .{ 0.65, 0.45, 0.22, 0.95 },
            .iron_trapdoor => .{ 0.85, 0.85, 0.88, 0.95 },
            .redstone_block => .{ 0.88, 0.12, 0.08, 0.95 },
            .redstone_ore => .{ 0.65, 0.25, 0.25, 0.95 },
            .gold_ore => .{ 0.75, 0.70, 0.35, 0.95 },
            .gold_block => .{ 0.95, 0.85, 0.20, 0.95 },
            .diamond => .{ 0.35, 0.85, 0.95, 0.95 },
            .diamond_ore => .{ 0.45, 0.70, 0.80, 0.95 },
            .diamond_block => .{ 0.40, 0.90, 0.95, 0.95 },
            .diamond_sword => .{ 0.35, 0.88, 0.95, 0.95 },
            .diamond_pickaxe => .{ 0.35, 0.88, 0.95, 0.95 },
            .diamond_helmet => .{ 0.38, 0.86, 0.96, 0.95 },
            .diamond_chestplate => .{ 0.35, 0.88, 0.98, 0.95 },
            .diamond_leggings => .{ 0.32, 0.84, 0.94, 0.95 },
            .diamond_boots => .{ 0.30, 0.82, 0.92, 0.95 },
            .flint => .{ 0.28, 0.26, 0.30, 0.95 },
            .flint_and_steel => .{ 0.82, 0.78, 0.72, 0.95 },
            .wooden_axe => .{ 0.82, 0.68, 0.38, 0.95 },
            .iron_axe => .{ 0.88, 0.85, 0.82, 0.95 },
            .diamond_axe => .{ 0.35, 0.88, 0.95, 0.95 },
            .netherite_axe => .{ 0.30, 0.26, 0.32, 0.95 },
            .wooden_shovel => .{ 0.78, 0.64, 0.40, 0.95 },
            .iron_shovel => .{ 0.85, 0.85, 0.88, 0.95 },
            .diamond_shovel => .{ 0.35, 0.88, 0.95, 0.95 },
            .netherite_shovel => .{ 0.28, 0.24, 0.30, 0.95 },
            .wooden_hoe => .{ 0.75, 0.60, 0.35, 0.95 },
            .iron_hoe => .{ 0.86, 0.84, 0.82, 0.95 },
            .diamond_hoe => .{ 0.35, 0.88, 0.95, 0.95 },
            .netherite_hoe => .{ 0.26, 0.22, 0.28, 0.95 },
            .shears => .{ 0.82, 0.82, 0.84, 0.95 },
            .iron_helmet => .{ 0.85, 0.85, 0.88, 0.95 },
            .iron_chestplate => .{ 0.88, 0.88, 0.90, 0.95 },
            .iron_leggings => .{ 0.82, 0.82, 0.85, 0.95 },
            .iron_boots => .{ 0.80, 0.80, 0.82, 0.95 },
            .golden_helmet => .{ 0.95, 0.82, 0.18, 0.95 },
            .golden_chestplate => .{ 0.98, 0.85, 0.22, 0.95 },
            .golden_leggings => .{ 0.92, 0.80, 0.15, 0.95 },
            .golden_boots => .{ 0.90, 0.78, 0.12, 0.95 },
            .stone_sword => .{ 0.65, 0.65, 0.65, 0.95 },
            .stone_pickaxe => .{ 0.62, 0.62, 0.64, 0.95 },
            .stone_axe => .{ 0.60, 0.60, 0.62, 0.95 },
            .stone_shovel => .{ 0.63, 0.63, 0.65, 0.95 },
            .stone_hoe => .{ 0.58, 0.58, 0.60, 0.95 },
            .golden_sword => .{ 0.96, 0.82, 0.18, 0.95 },
            .golden_pickaxe => .{ 0.94, 0.80, 0.16, 0.95 },
            .golden_axe => .{ 0.92, 0.78, 0.15, 0.95 },
            .golden_shovel => .{ 0.95, 0.81, 0.17, 0.95 },
            .golden_hoe => .{ 0.90, 0.76, 0.14, 0.95 },
            .wooden_sword => .{ 0.76, 0.58, 0.34, 0.95 },
            .leather => .{ 0.62, 0.36, 0.20, 0.95 },
            .leather_helmet => .{ 0.65, 0.38, 0.22, 0.95 },
            .leather_chestplate => .{ 0.60, 0.35, 0.19, 0.95 },
            .leather_leggings => .{ 0.58, 0.33, 0.18, 0.95 },
            .leather_boots => .{ 0.55, 0.31, 0.16, 0.95 },
            .farmland => .{ 0.45, 0.30, 0.16, 0.95 },
            .wheat_seeds => .{ 0.48, 0.68, 0.24, 0.95 },
            .wheat => .{ 0.88, 0.76, 0.28, 0.95 },
            .bread => .{ 0.82, 0.58, 0.24, 0.95 },
            .paper => .{ 0.94, 0.93, 0.88, 0.95 },
            .book => .{ 0.65, 0.38, 0.22, 0.95 },
            .bookshelf => .{ 0.68, 0.48, 0.26, 0.95 },
            .lectern => .{ 0.72, 0.54, 0.30, 0.95 },
            .emerald => .{ 0.15, 0.85, 0.38, 0.95 },
            .emerald_ore => .{ 0.35, 0.68, 0.42, 0.95 },
            .emerald_block => .{ 0.18, 0.90, 0.42, 0.95 },
            .lapis_lazuli => .{ 0.16, 0.32, 0.85, 0.95 },
            .lapis_ore => .{ 0.28, 0.42, 0.78, 0.95 },
            .lapis_block => .{ 0.14, 0.28, 0.88, 0.95 },
            .honeycomb => .{ 0.96, 0.72, 0.18, 0.95 },
            .honey_bottle => .{ 0.98, 0.76, 0.20, 0.95 },
            .beehive => .{ 0.78, 0.62, 0.34, 0.95 },
            .honey_block => .{ 0.98, 0.74, 0.16, 0.85 },
            .raw_copper => .{ 0.84, 0.48, 0.32, 0.95 },
            .copper_ingot => .{ 0.88, 0.50, 0.30, 0.95 },
            .copper_ore => .{ 0.65, 0.48, 0.40, 0.95 },
            .copper_block => .{ 0.86, 0.48, 0.28, 0.95 },
            .exposed_copper => .{ 0.68, 0.52, 0.44, 0.95 },
            .weathered_copper => .{ 0.42, 0.66, 0.54, 0.95 },
            .oxidized_copper => .{ 0.32, 0.76, 0.64, 0.95 },
            .waxed_copper_block => .{ 0.90, 0.54, 0.30, 0.95 },
            .lightning_rod => .{ 0.88, 0.52, 0.32, 0.95 },
            .spyglass => .{ 0.78, 0.56, 0.28, 0.95 },
            .amethyst_shard => .{ 0.68, 0.38, 0.88, 0.95 },
            .amethyst_block => .{ 0.58, 0.30, 0.82, 0.95 },
            .budding_amethyst => .{ 0.64, 0.34, 0.86, 0.95 },
            .amethyst_cluster => .{ 0.76, 0.46, 0.95, 0.95 },
            .tinted_glass => .{ 0.28, 0.20, 0.34, 0.75 },
            .bell => .{ 0.94, 0.80, 0.22, 0.95 },
            .sugar_cane => .{ 0.52, 0.82, 0.36, 0.95 },
            .sugar => .{ 0.96, 0.96, 0.98, 0.95 },
            .pumpkin => .{ 0.90, 0.52, 0.14, 0.95 },
            .carved_pumpkin => .{ 0.86, 0.48, 0.12, 0.95 },
            .jack_o_lantern => .{ 0.98, 0.68, 0.18, 0.95 },
            .pumpkin_pie => .{ 0.88, 0.56, 0.24, 0.95 },
            .sculk => .{ 0.06, 0.18, 0.24, 0.95 },
            .sculk_sensor => .{ 0.08, 0.48, 0.58, 0.95 },
            .echo_shard => .{ 0.12, 0.68, 0.78, 0.95 },
            .recovery_compass => .{ 0.10, 0.58, 0.68, 0.95 },
            .deepslate => .{ 0.28, 0.28, 0.32, 0.95 },
            .cobbled_deepslate => .{ 0.32, 0.32, 0.36, 0.95 },
            .polished_deepslate => .{ 0.36, 0.36, 0.40, 0.95 },
            .deepslate_bricks => .{ 0.30, 0.30, 0.34, 0.95 },
            .iron_block => .{ 0.88, 0.88, 0.90, 0.95 },
            .cake => .{ 0.96, 0.88, 0.84, 0.95 },
            .melon => .{ 0.46, 0.74, 0.22, 0.95 },
            .melon_slice => .{ 0.90, 0.28, 0.26, 0.95 },
            .glistering_melon => .{ 0.96, 0.68, 0.22, 0.95 },
            .healing_potion => .{ 0.96, 0.22, 0.36, 0.95 },
            .barrel => .{ 0.58, 0.42, 0.24, 0.95 },
            .dripstone_block => .{ 0.56, 0.44, 0.38, 0.95 },
            .pointed_dripstone => .{ 0.62, 0.48, 0.42, 0.95 },
            .moss_block => .{ 0.32, 0.64, 0.24, 0.95 },
            .moss_carpet => .{ 0.36, 0.68, 0.28, 0.95 },
            .glow_berries => .{ 0.98, 0.78, 0.24, 0.95 },
            .clay_ball => .{ 0.66, 0.70, 0.76, 0.95 },
            .clay => .{ 0.62, 0.66, 0.72, 0.95 },
            .terracotta => .{ 0.68, 0.42, 0.32, 0.95 },
            .brick_item => .{ 0.76, 0.36, 0.28, 0.95 },
            .flower_pot => .{ 0.64, 0.36, 0.28, 0.95 },
            .totem_of_undying => .{ 0.96, 0.84, 0.22, 0.95 },
            .carrot => .{ 0.96, 0.54, 0.14, 0.95 },
            .golden_carrot => .{ 0.98, 0.82, 0.20, 0.95 },
            .night_vision_potion => .{ 0.18, 0.28, 0.88, 0.95 },
            .ghast_tear => .{ 0.90, 0.96, 0.98, 0.95 },
            .regeneration_potion => .{ 0.94, 0.38, 0.72, 0.95 },
            .ice => .{ 0.60, 0.82, 0.98, 0.75 },
            .packed_ice => .{ 0.56, 0.78, 0.96, 0.95 },
            .blue_ice => .{ 0.36, 0.64, 0.98, 0.95 },
            .powder_snow_bucket => .{ 0.92, 0.96, 0.98, 0.95 },
            .bamboo => .{ 0.44, 0.76, 0.24, 0.95 },
            .scaffolding => .{ 0.82, 0.68, 0.38, 0.95 },
            .potato => .{ 0.84, 0.68, 0.38, 0.95 },
            .baked_potato => .{ 0.78, 0.56, 0.26, 0.95 },
            .poisonous_potato => .{ 0.58, 0.76, 0.32, 0.95 },
            .beetroot => .{ 0.68, 0.16, 0.24, 0.95 },
            .bowl => .{ 0.58, 0.42, 0.24, 0.95 },
            .beetroot_soup => .{ 0.74, 0.18, 0.26, 0.95 },
            .mushroom_stew => .{ 0.76, 0.52, 0.38, 0.95 },
            .rabbit_foot => .{ 0.82, 0.68, 0.52, 0.95 },
            .swiftness_potion => .{ 0.48, 0.82, 0.96, 0.95 },
            .strength_potion => .{ 0.68, 0.16, 0.18, 0.95 },
            .leaping_potion => .{ 0.28, 0.92, 0.42, 0.95 },
            .cocoa_beans => .{ 0.46, 0.26, 0.14, 0.95 },
            .cookie => .{ 0.82, 0.58, 0.28, 0.95 },
            .sweet_berries => .{ 0.86, 0.14, 0.22, 0.95 },
            .ender_chest => .{ 0.16, 0.34, 0.32, 0.95 },
            .chainmail_helmet => .{ 0.68, 0.70, 0.74, 0.95 },
            .chainmail_chestplate => .{ 0.66, 0.68, 0.72, 0.95 },
            .chainmail_leggings => .{ 0.64, 0.66, 0.70, 0.95 },
            .chainmail_boots => .{ 0.62, 0.64, 0.68, 0.95 },
            .mud => .{ 0.28, 0.24, 0.22, 0.95 },
            .packed_mud => .{ 0.56, 0.44, 0.34, 0.95 },
            .mud_bricks => .{ 0.52, 0.40, 0.30, 0.95 },
            .copper_bulb => .{ 0.88, 0.58, 0.28, 0.95 },
            .chiseled_copper => .{ 0.84, 0.46, 0.26, 0.95 },
            .copper_grate => .{ 0.80, 0.44, 0.24, 0.85 },
            .brush => .{ 0.78, 0.52, 0.28, 0.95 },
            .suspicious_sand => .{ 0.88, 0.80, 0.58, 0.95 },
            .pottery_sherd => .{ 0.66, 0.38, 0.28, 0.95 },
            .decorated_pot => .{ 0.64, 0.36, 0.26, 0.95 },
            .breeze_rod => .{ 0.62, 0.88, 0.96, 0.95 },
            .wind_charge => .{ 0.78, 0.94, 0.98, 0.95 },
            .heavy_core => .{ 0.42, 0.44, 0.48, 0.95 },
            .mace => .{ 0.52, 0.56, 0.64, 0.95 },
            .crafter => .{ 0.62, 0.52, 0.40, 0.95 },
            .trial_key => .{ 0.88, 0.56, 0.30, 0.95 },
            .trial_spawner => .{ 0.34, 0.52, 0.56, 0.95 },
            .vault => .{ 0.38, 0.56, 0.52, 0.95 },
            .enchanted_golden_apple => .{ 0.96, 0.72, 0.92, 0.95 },
            .suspicious_stew => .{ 0.68, 0.78, 0.36, 0.95 },
            .tuff => .{ 0.44, 0.46, 0.42, 0.95 },
            .polished_tuff => .{ 0.48, 0.50, 0.46, 0.95 },
            .tuff_bricks => .{ 0.46, 0.48, 0.44, 0.95 },
            .chiseled_tuff => .{ 0.50, 0.52, 0.48, 0.95 },
            .calibrated_sculk_sensor => .{ 0.56, 0.28, 0.88, 0.95 },
            .ochre_froglight => .{ 0.96, 0.82, 0.44, 0.95 },
            .verdant_froglight => .{ 0.48, 0.88, 0.56, 0.95 },
            .pearlescent_froglight => .{ 0.88, 0.62, 0.96, 0.95 },
            .mangrove_roots => .{ 0.46, 0.32, 0.22, 0.95 },
            .muddy_mangrove_roots => .{ 0.36, 0.26, 0.18, 0.95 },
            .mangrove_propagule => .{ 0.42, 0.72, 0.28, 0.95 },
            .mangrove_log => .{ 0.52, 0.30, 0.24, 0.95 },
            .mangrove_planks => .{ 0.64, 0.32, 0.26, 0.95 },
            .goat_horn => .{ 0.88, 0.86, 0.80, 0.95 },
            .armor_trim_template => .{ 0.34, 0.68, 0.82, 0.95 },
            .torchflower_seeds => .{ 0.78, 0.54, 0.22, 0.95 },
            .torchflower => .{ 0.98, 0.62, 0.14, 0.95 },
            .pitcher_pod => .{ 0.36, 0.52, 0.74, 0.95 },
            .pitcher_plant => .{ 0.38, 0.46, 0.84, 0.95 },
            .cherry_log => .{ 0.44, 0.28, 0.32, 0.95 },
            .cherry_leaves => .{ 0.96, 0.68, 0.82, 0.95 },
            .cherry_planks => .{ 0.92, 0.70, 0.74, 0.95 },
            .pink_petals => .{ 0.98, 0.65, 0.80, 0.95 },
            .chiseled_bookshelf => .{ 0.72, 0.54, 0.36, 0.95 },
            .hanging_sign => .{ 0.78, 0.60, 0.42, 0.95 },
            .bamboo_mosaic => .{ 0.82, 0.76, 0.38, 0.95 },
            .creaking_heart => .{ 0.88, 0.46, 0.22, 0.95 },
            .pale_oak_log => .{ 0.86, 0.86, 0.84, 0.95 },
            .open_eyeblossom => .{ 0.94, 0.50, 0.18, 0.95 },
            .resin_bricks => .{ 0.86, 0.42, 0.20, 0.95 },
            .resin_clump => .{ 0.92, 0.48, 0.16, 0.95 },
            .resin_brick => .{ 0.82, 0.38, 0.18, 0.95 },
            .armadillo_scute => .{ 0.72, 0.50, 0.40, 0.95 },
            .wolf_armor => .{ 0.68, 0.46, 0.36, 0.95 },
            .ominous_bottle => .{ 0.20, 0.70, 0.85, 0.95 },
            .ominous_trial_key => .{ 0.25, 0.80, 0.90, 0.95 },
            .ominous_vault => .{ 0.30, 0.75, 0.85, 0.95 },
            .potion_of_infested => .{ 0.55, 0.60, 0.55, 0.90 },
            .potion_of_oozing => .{ 0.40, 0.80, 0.30, 0.90 },
            .potion_of_weaving => .{ 0.80, 0.80, 0.75, 0.90 },
            .potion_of_wind_charged => .{ 0.75, 0.90, 0.95, 0.90 },
            .bundle => .{ 0.65, 0.42, 0.28, 0.95 },
            .copper_door => .{ 0.85, 0.52, 0.32, 0.95 },
            .copper_trapdoor => .{ 0.85, 0.52, 0.32, 0.95 },
            .disc_fragment_5 => .{ 0.25, 0.60, 0.65, 0.95 },
            .music_disc_5 => .{ 0.20, 0.55, 0.60, 0.95 },
            .music_disc_relic => .{ 0.35, 0.55, 0.70, 0.95 },
            .music_disc_precipice => .{ 0.20, 0.75, 0.80, 0.95 },
            .music_disc_creator => .{ 0.85, 0.60, 0.25, 0.95 },
            .dried_ghast => .{ 0.76, 0.72, 0.68, 0.95 },
            .ghast_harness => .{ 0.92, 0.86, 0.72, 0.95 },
            .sculk_catalyst => .{ 0.12, 0.28, 0.34, 0.95 },
            .sculk_shrieker => .{ 0.08, 0.20, 0.25, 0.95 },
            .bucket_of_axolotl => .{ 0.95, 0.48, 0.62, 0.95 },
            .banner => .{ 0.88, 0.82, 0.70, 0.95 },
            .banner_pattern_stencil => .{ 0.82, 0.78, 0.68, 0.95 },
            .copper_golem_statue => .{ 0.78, 0.48, 0.30, 0.95 },
            .firefly_bush => .{ 0.35, 0.72, 0.35, 0.95 },
            .leaf_litter => .{ 0.72, 0.42, 0.20, 0.95 },
            .enchanted_book => .{ 0.65, 0.25, 0.78, 0.95 },
            .mending_book => .{ 0.25, 0.78, 0.55, 0.95 },
            .raid_omen_banner => .{ 0.52, 0.18, 0.18, 0.95 },
            .evoker_fang_totem => .{ 0.82, 0.76, 0.46, 0.95 },
            .turtle_egg => .{ 0.58, 0.64, 0.34, 0.95 },
            .seagrass => .{ 0.18, 0.58, 0.38, 0.95 },
            .potion_of_turtle_master => .{ 0.25, 0.62, 0.48, 0.95 },
            .sweet_berry_fox_treat => .{ 0.82, 0.22, 0.28, 0.95 },
            .zombie_head => .{ 0.28, 0.48, 0.24, 0.95 },
            .skeleton_skull => .{ 0.82, 0.78, 0.67, 0.95 },
            .creeper_head => .{ 0.20, 0.54, 0.25, 0.95 },
            .piglin_head => .{ 0.65, 0.38, 0.28, 0.95 },
            .splash_water_bottle => .{ 0.28, 0.62, 0.94, 0.85 },
            .splash_harming_potion => .{ 0.58, 0.16, 0.30, 0.85 },
            .water_bottle => .{ 0.28, 0.62, 0.94, 0.85 },
            .harming_potion => .{ 0.58, 0.16, 0.30, 0.85 },
            .wither_rose => .{ 0.16, 0.08, 0.18, 0.95 },
            .glazed_terracotta => .{ 0.73, 0.37, 0.28, 0.95 },
            .name_tag => .{ 0.79, 0.66, 0.38, 0.95 },
            .saddle => .{ 0.53, 0.25, 0.12, 0.95 },
            .light_weighted_pressure_plate => .{ 0.92, 0.75, 0.24, 0.95 },
            .heavy_weighted_pressure_plate => .{ 0.72, 0.72, 0.74, 0.95 },
            .empty_locator_map => .{ 0.78, 0.70, 0.48, 0.95 },
            .filled_explorer_map => .{ 0.28, 0.62, 0.35, 0.95 },
            .glass_pane => .{ 0.82, 0.94, 0.98, 0.65 },
            .leather_horse_armor => .{ 0.48, 0.27, 0.16, 0.95 },
            .iron_horse_armor => .{ 0.72, 0.74, 0.76, 0.95 },
            .golden_horse_armor => .{ 0.96, 0.78, 0.20, 0.95 },
            .diamond_horse_armor => .{ 0.18, 0.78, 0.82, 0.95 },
            .frost_walker_boots => .{ 0.35, 0.78, 0.92, 0.95 },
            .swift_sneak_book => .{ 0.32, 0.58, 0.78, 0.95 },
            .reinforced_deepslate => .{ 0.25, 0.29, 0.32, 0.95 },
            .milk_bucket => .{ 0.90, 0.92, 0.95, 0.95 },
            .bottle_o_enchanting => .{ 0.25, 0.72, 0.92, 0.85 },
            .sweeping_edge_book => .{ 0.68, 0.34, 0.76, 0.95 },
            .arrow_of_slowness => .{ 0.48, 0.66, 0.40, 0.95 },
            .item_frame => .{ 0.74, 0.56, 0.32, 0.95 },
            .glow_item_frame => .{ 0.94, 0.78, 0.38, 0.95 },
            .painting => .{ 0.60, 0.34, 0.28, 0.95 },
            .feather_falling_book => .{ 0.74, 0.46, 0.88, 0.95 },
            .stained_glass => .{ 0.42, 0.62, 0.78, 0.65 },
            .potion_of_slowness => .{ 0.48, 0.60, 0.38, 0.90 },
            .red_sandstone => .{ 0.78, 0.40, 0.22, 1.0 },
            .concrete_powder => .{ 0.65, 0.65, 0.65, 1.0 },
            .concrete_block => .{ 0.50, 0.50, 0.52, 1.0 },
            .buried_treasure_map => .{ 0.85, 0.75, 0.50, 1.0 },
            .firework_star => .{ 0.95, 0.35, 0.15, 1.0 },
            .acacia_planks => .{ 0.75, 0.38, 0.20, 1.0 },
            .dark_oak_planks => .{ 0.26, 0.18, 0.10, 1.0 },
            .music_disc_pigstep => .{ 0.60, 0.20, 0.25, 1.0 },
            .netherite_upgrade_template => .{ 0.25, 0.22, 0.28, 1.0 },
            .sniffer_egg => .{ 0.68, 0.28, 0.22, 1.0 },
            .suspicious_gravel => .{ 0.55, 0.53, 0.52, 1.0 },
            .coral_block => .{ 0.90, 0.40, 0.50, 1.0 },
            .dead_coral_block => .{ 0.50, 0.48, 0.46, 1.0 },
            .lily_pad => .{ 0.15, 0.45, 0.18, 1.0 },
            .frogspawn => .{ 0.50, 0.65, 0.45, 0.90 },
            .bucket_of_tadpole => .{ 0.35, 0.55, 0.65, 1.0 },
            .book_and_quill => .{ 0.45, 0.30, 0.20, 1.0 },
            .written_book => .{ 0.35, 0.18, 0.45, 1.0 },
            .bone_block => .{ 0.82, 0.78, 0.68, 1.0 },
            .calcite => .{ 0.88, 0.86, 0.82, 1.0 },
            .smooth_basalt => .{ 0.25, 0.25, 0.28, 1.0 },
            .rooted_dirt => .{ 0.42, 0.27, 0.16, 1.0 },
            .hanging_roots => .{ 0.38, 0.24, 0.12, 1.0 },
            .big_dripleaf => .{ 0.22, 0.62, 0.28, 1.0 },
            .spore_blossom => .{ 0.78, 0.38, 0.62, 1.0 },
            .awkward_potion => .{ 0.68, 0.28, 0.82, 0.9 },
            .invisibility_potion => .{ 0.42, 0.52, 0.78, 0.9 },
            .clock => .{ 0.92, 0.72, 0.18, 1.0 },
            .sand => .{ 0.91, 0.84, 0.63, 0.95 },
            .glass => .{ 0.85, 0.95, 1.0, 0.65 },
            .sandstone => .{ 0.89, 0.82, 0.61, 0.95 },
            .brick => .{ 0.72, 0.32, 0.25, 0.95 },
            .wool => .{ 0.92, 0.90, 0.85, 0.95 },
            .apple => .{ 0.85, 0.15, 0.12, 0.95 },
            .sapling => .{ 0.35, 0.65, 0.25, 0.95 },
            .furnace => .{ 0.35, 0.35, 0.38, 0.95 },
            .iron_ingot => .{ 0.85, 0.82, 0.78, 0.95 },
            .iron_pickaxe => .{ 0.90, 0.85, 0.80, 0.95 },
            .snowball => .{ 0.93, 0.95, 1.0, 0.95 },
            .snow_block => .{ 0.90, 0.93, 0.98, 0.95 },
            .golden_apple => .{ 1.0, 0.80, 0.20, 0.95 },
            .iron_sword => .{ 0.88, 0.86, 0.92, 0.95 },
            .ladder => .{ 0.65, 0.45, 0.22, 0.95 },
            .tnt => .{ 0.85, 0.18, 0.15, 0.95 },
            .torch => .{ 1.0, 0.70, 0.20, 0.95 },
            .chest => .{ 0.70, 0.45, 0.20, 0.95 },
            .wooden_door => .{ 0.65, 0.40, 0.18, 0.95 },
            .pressure_plate => .{ 0.70, 0.48, 0.22, 0.95 },
            .redstone_dust => .{ 0.85, 0.15, 0.12, 0.95 },
            .lever => .{ 0.65, 0.62, 0.58, 0.95 },
            .redstone_repeater => .{ 0.72, 0.72, 0.75, 0.95 },
            .redstone_lamp => .{ 0.95, 0.75, 0.35, 0.95 },
            .iron_door => .{ 0.85, 0.85, 0.88, 0.95 },
            .redstone_torch => .{ 0.95, 0.22, 0.18, 0.95 },
            .campfire => .{ 0.95, 0.45, 0.10, 0.95 },
            .cactus => .{ 0.15, 0.60, 0.15, 0.95 },
            .boat => .{ 0.70, 0.48, 0.25, 0.95 },
            .lava_bucket => .{ 0.98, 0.35, 0.05, 0.95 },
            .obsidian => .{ 0.15, 0.10, 0.22, 0.95 },
            .netherrack => .{ 0.65, 0.18, 0.18, 0.95 },
            .soul_sand => .{ 0.45, 0.32, 0.25, 0.95 },
            .magma => .{ 0.92, 0.42, 0.12, 0.95 },
            .fire_resistance_potion => .{ 0.95, 0.50, 0.10, 0.90 },
            .glowstone => .{ 0.98, 0.85, 0.35, 0.95 },
            .nether_quartz_ore => .{ 0.75, 0.28, 0.28, 0.95 },
            .nether_quartz => .{ 0.95, 0.95, 0.98, 0.95 },
            .quartz_block => .{ 0.94, 0.92, 0.90, 0.95 },
            .quartz_pillar => .{ 0.93, 0.91, 0.89, 0.95 },
            .chiseled_quartz_block => .{ 0.92, 0.90, 0.88, 0.95 },
            .nether_brick => .{ 0.35, 0.12, 0.15, 0.95 },
            .nether_brick_fence => .{ 0.38, 0.14, 0.16, 0.95 },
            .nether_wart => .{ 0.75, 0.16, 0.22, 0.95 },
            .magma_cream => .{ 0.88, 0.52, 0.15, 0.95 },
            .fire_charge => .{ 0.98, 0.35, 0.10, 0.95 },
            .soul_torch => .{ 0.25, 0.85, 0.95, 0.95 },
            .soul_campfire => .{ 0.20, 0.80, 0.90, 0.95 },
            .spawner_cage => .{ 0.35, 0.33, 0.38, 0.95 },
            .wither_skull => .{ 0.85, 0.83, 0.80, 0.95 },
            .nether_star => .{ 0.55, 0.95, 1.0, 1.0 },
            .beacon => .{ 0.50, 0.90, 0.95, 0.95 },
            .ancient_debris => .{ 0.38, 0.32, 0.28, 0.95 },
            .netherite_scrap => .{ 0.28, 0.22, 0.20, 0.95 },
            .netherite_ingot => .{ 0.22, 0.20, 0.22, 0.95 },
            .netherite_pickaxe => .{ 0.32, 0.28, 0.34, 0.95 },
            .netherite_sword => .{ 0.28, 0.24, 0.30, 0.95 },
            .respawn_anchor => .{ 0.35, 0.15, 0.45, 0.95 },
            .crying_obsidian => .{ 0.45, 0.15, 0.65, 0.95 },
            .lodestone => .{ 0.60, 0.60, 0.65, 0.95 },
            .basalt => .{ 0.28, 0.28, 0.32, 0.95 },
            .blackstone => .{ 0.18, 0.18, 0.20, 0.95 },
            .gilded_blackstone => .{ 0.85, 0.65, 0.15, 0.95 },
            .gold_nugget => .{ 1.0, 0.85, 0.10, 0.95 },
            .sunflower => .{ 0.95, 0.80, 0.12, 0.98 },
            .lilac => .{ 0.72, 0.42, 0.78, 0.98 },
            .rose_bush => .{ 0.85, 0.16, 0.20, 0.98 },
            .peony => .{ 0.95, 0.48, 0.60, 0.98 },
            .podzol => .{ 0.38, 0.24, 0.14, 0.98 },
            .mossy_cobblestone => .{ 0.32, 0.42, 0.30, 0.98 },
            .birch_planks => .{ 0.82, 0.74, 0.52, 0.98 },
            .spruce_planks => .{ 0.42, 0.28, 0.16, 0.98 },
            .chest_boat => .{ 0.48, 0.30, 0.16, 0.98 },
            .bamboo_raft => .{ 0.68, 0.78, 0.28, 0.98 },
            .bed => .{ 0.82, 0.20, 0.22, 0.98 },
            .raw_pork => .{ 0.95, 0.55, 0.55, 0.95 },
            .raw_mutton => .{ 0.80, 0.45, 0.40, 0.95 },
            .cooked_pork => .{ 0.72, 0.38, 0.22, 0.95 },
            .cooked_mutton => .{ 0.55, 0.28, 0.20, 0.95 },
        };
    }
};

pub const ItemStack = struct {
    item: ItemType = .none,
    count: u8 = 0,

    pub fn isEmpty(self: ItemStack) bool {
        return self.item == .none or self.count == 0;
    }

    pub fn clear(self: *ItemStack) void {
        self.item = .none;
        self.count = 0;
    }

    pub fn canStackWith(self: ItemStack, other: ItemStack) bool {
        if (self.isEmpty()) return true;
        if (other.isEmpty()) return true;
        return self.item == other.item and (self.count + other.count <= self.item.maxStackSize());
    }

    pub fn add(self: *ItemStack, count: u8) u8 {
        if (self.item == .none) return count;
        const max = self.item.maxStackSize();
        const available = max - self.count;
        const to_add = @min(available, count);
        self.count += to_add;
        return count - to_add;
    }

    pub fn decrement(self: *ItemStack, amount: u8) void {
        if (amount >= self.count) {
            self.clear();
        } else {
            self.count -= amount;
        }
    }
};

fn wave9CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var has_arrow = false;
    var has_slowness = false;
    var has_leather = false;
    var has_stick = false;
    var has_paper = false;
    var has_glowstone = false;
    var has_frame = false;
    var has_wool = false;
    var has_book = false;
    var has_slow_falling = false;
    var has_glass = false;
    var has_lapis = false;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        has_arrow = has_arrow or slot.item == .arrow;
        has_slowness = has_slowness or slot.item == .potion_of_slowness;
        has_leather = has_leather or slot.item == .leather;
        has_stick = has_stick or slot.item == .stick;
        has_paper = has_paper or slot.item == .paper;
        has_glowstone = has_glowstone or slot.item == .glowstone;
        has_frame = has_frame or slot.item == .item_frame;
        has_wool = has_wool or slot.item == .wool;
        has_book = has_book or slot.item == .book;
        has_slow_falling = has_slow_falling or slot.item == .slow_falling_potion;
        has_glass = has_glass or slot.item == .glass;
        has_lapis = has_lapis or slot.item == .lapis_lazuli;
    }
    if (non_empty != 2) return null;
    if (has_arrow and has_slowness) return .{ .item = .arrow_of_slowness, .count = 1 };
    if (has_leather and has_stick) return .{ .item = .item_frame, .count = 1 };
    if (has_frame and has_glowstone) return .{ .item = .glow_item_frame, .count = 1 };
    if (has_wool and has_paper) return .{ .item = .painting, .count = 1 };
    if (has_book and has_slow_falling) return .{ .item = .feather_falling_book, .count = 1 };
    if (has_glass and has_lapis) return .{ .item = .stained_glass, .count = 1 };
    return null;
}

fn wave10CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var has_sandstone = false;
    var has_brick = false;
    var has_sand = false;
    var has_clay = false;
    var has_clay_ball = false;
    var has_flint = false;
    var has_concrete_powder = false;
    var has_water_bucket = false;
    var has_water_bottle = false;
    var has_empty_map = false;
    var has_heart_of_sea = false;
    var has_gunpowder = false;
    var has_glowstone = false;
    var has_wood_planks = false;
    var has_torch = false;
    var has_coal = false;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        has_sandstone = has_sandstone or slot.item == .sandstone;
        has_brick = has_brick or slot.item == .brick;
        has_sand = has_sand or slot.item == .sand;
        has_clay = has_clay or slot.item == .clay;
        has_clay_ball = has_clay_ball or slot.item == .clay_ball;
        has_flint = has_flint or slot.item == .flint;
        has_concrete_powder = has_concrete_powder or slot.item == .concrete_powder;
        has_water_bucket = has_water_bucket or slot.item == .water_bucket;
        has_water_bottle = has_water_bottle or slot.item == .water_bottle;
        has_empty_map = has_empty_map or slot.item == .empty_locator_map;
        has_heart_of_sea = has_heart_of_sea or slot.item == .heart_of_the_sea;
        has_gunpowder = has_gunpowder or slot.item == .gunpowder;
        has_glowstone = has_glowstone or slot.item == .glowstone;
        has_wood_planks = has_wood_planks or slot.item == .wood_planks;
        has_torch = has_torch or slot.item == .torch;
        has_coal = has_coal or slot.item == .coal;
    }
    if (non_empty != 2) return null;
    if (has_sandstone and has_brick) return .{ .item = .red_sandstone, .count = 1 };
    if (has_sand and (has_clay or has_clay_ball or has_flint)) return .{ .item = .concrete_powder, .count = 1 };
    if (has_concrete_powder and (has_water_bucket or has_water_bottle)) return .{ .item = .concrete_block, .count = 1 };
    if (has_empty_map and has_heart_of_sea) return .{ .item = .buried_treasure_map, .count = 1 };
    if (has_gunpowder and has_glowstone) return .{ .item = .firework_star, .count = 1 };
    if (has_wood_planks and has_torch) return .{ .item = .acacia_planks, .count = 1 };
    if (has_wood_planks and has_coal) return .{ .item = .dark_oak_planks, .count = 1 };
    return null;
}

fn wave11CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var has_diamond = false;
    var has_netherrack = false;
    var has_book = false;
    var has_coal = false;
    var has_book_and_quill = false;
    var has_paper = false;
    var has_leaves = false;
    var has_seagrass = false;
    var has_sea_pickle = false;
    var has_kelp = false;
    var has_water_bucket = false;
    var has_slimeball = false;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        has_diamond = has_diamond or slot.item == .diamond;
        has_netherrack = has_netherrack or slot.item == .netherrack;
        has_book = has_book or slot.item == .book;
        has_coal = has_coal or slot.item == .coal;
        has_book_and_quill = has_book_and_quill or slot.item == .book_and_quill;
        has_paper = has_paper or slot.item == .paper;
        has_leaves = has_leaves or slot.item == .leaves;
        has_seagrass = has_seagrass or slot.item == .seagrass;
        has_sea_pickle = has_sea_pickle or slot.item == .sea_pickle;
        has_kelp = has_kelp or slot.item == .kelp;
        has_water_bucket = has_water_bucket or slot.item == .water_bucket;
        has_slimeball = has_slimeball or slot.item == .slimeball;
    }
    if (non_empty != 2) return null;
    if (has_diamond and has_netherrack) return .{ .item = .netherite_upgrade_template, .count = 2 };
    if (has_book and has_coal) return .{ .item = .book_and_quill, .count = 1 };
    if (has_book_and_quill and has_paper) return .{ .item = .written_book, .count = 1 };
    if (has_leaves and has_seagrass) return .{ .item = .lily_pad, .count = 1 };
    if (has_sea_pickle and has_kelp) return .{ .item = .coral_block, .count = 1 };
    if (has_water_bucket and has_slimeball) return .{ .item = .bucket_of_tadpole, .count = 1 };
    return null;
}


fn wave12CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var has_bone_meal = false;
    var has_bone = false;
    var has_dirt = false;
    var has_hanging_roots = false;
    var has_water_bottle = false;
    var has_nether_wart = false;
    var has_night_vision = false;
    var has_fermented_eye = false;
    var has_gold_block = false;
    var has_redstone = false;
    var has_moss = false;
    var has_lily_pad = false;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        has_bone_meal = has_bone_meal or slot.item == .bone_meal;
        has_bone = has_bone or slot.item == .bone;
        has_dirt = has_dirt or slot.item == .dirt;
        has_hanging_roots = has_hanging_roots or slot.item == .hanging_roots;
        has_water_bottle = has_water_bottle or slot.item == .water_bottle;
        has_nether_wart = has_nether_wart or slot.item == .nether_wart;
        has_night_vision = has_night_vision or slot.item == .night_vision_potion;
        has_fermented_eye = has_fermented_eye or slot.item == .fermented_spider_eye;
        has_gold_block = has_gold_block or slot.item == .gold_block;
        has_redstone = has_redstone or slot.item == .redstone_dust;
        has_moss = has_moss or slot.item == .moss_block;
        has_lily_pad = has_lily_pad or slot.item == .lily_pad;
    }
    if (non_empty != 2) return null;
    if (has_bone_meal and has_bone) return .{ .item = .bone_block, .count = 1 };
    if (has_dirt and has_hanging_roots) return .{ .item = .rooted_dirt, .count = 1 };
    if (has_water_bottle and has_nether_wart) return .{ .item = .awkward_potion, .count = 1 };
    if (has_night_vision and has_fermented_eye) return .{ .item = .invisibility_potion, .count = 1 };
    if (has_gold_block and has_redstone) return .{ .item = .clock, .count = 1 };
    if (has_moss and has_lily_pad) return .{ .item = .big_dripleaf, .count = 2 };
    return null;
}

fn wave13CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0; var flags = [_]bool{false} ** 12;
    for (grid) |slot| { if (slot.isEmpty()) continue; non_empty += 1;
        flags[0] = flags[0] or slot.item == .cobblestone; flags[1] = flags[1] or slot.item == .moss_block;
        flags[2] = flags[2] or slot.item == .boat; flags[3] = flags[3] or slot.item == .chest;
        flags[4] = flags[4] or slot.item == .bamboo_mosaic; flags[5] = flags[5] or slot.item == .bamboo;
        flags[6] = flags[6] or slot.item == .wool; flags[7] = flags[7] or slot.item == .wood_planks;
        flags[8] = flags[8] or slot.item == .sunflower; flags[9] = flags[9] or slot.item == .bone_meal;
        flags[10] = flags[10] or slot.item == .dirt; flags[11] = flags[11] or slot.item == .leaf_litter; }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .mossy_cobblestone, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .chest_boat, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .bamboo_raft, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .bed, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .sunflower, .count = 2 };
    if (flags[10] and flags[11]) return .{ .item = .podzol, .count = 1 };
    return null;
}

pub const Inventory = struct {
    pub const HOTBAR_SIZE = 6;
    pub const MAIN_SIZE = 18;
    pub const TOTAL_SIZE = HOTBAR_SIZE + MAIN_SIZE; // 24 slots total

    slots: [TOTAL_SIZE]ItemStack,
    craft_grid: [4]ItemStack, // 2x2 player crafting grid: [0, 1; 2, 3]
    craft_output: ItemStack,

    pub fn init() Inventory {
        var inv = Inventory{
            .slots = [_]ItemStack{.{}} ** TOTAL_SIZE,
            .craft_grid = [_]ItemStack{.{}} ** 4,
            .craft_output = .{},
        };

        // Give starter items in hotbar
        inv.slots[0] = .{ .item = .stone, .count = 64 };
        inv.slots[1] = .{ .item = .dirt, .count = 64 };
        inv.slots[2] = .{ .item = .grass, .count = 64 };
        inv.slots[3] = .{ .item = .wooden_pickaxe, .count = 1 };
        inv.slots[4] = .{ .item = .wood, .count = 32 };
        inv.slots[5] = .{ .item = .leaves, .count = 32 };

        inv.updateCrafting();
        return inv;
    }

    pub fn getHotbar(self: *Inventory, index: usize) ?*ItemStack {
        if (index >= HOTBAR_SIZE) return null;
        return &self.slots[index];
    }

    pub fn hasFullChainmailSet(self: *const Inventory) bool {
        return self.hasItem(.chainmail_helmet) and
               self.hasItem(.chainmail_chestplate) and
               self.hasItem(.chainmail_leggings) and
               self.hasItem(.chainmail_boots);
    }

    pub fn hasFullLeatherSet(self: *const Inventory) bool {
        return self.hasItem(.leather_helmet) and
               self.hasItem(.leather_chestplate) and
               self.hasItem(.leather_leggings) and
               self.hasItem(.leather_boots);
    }

    pub fn hasFullGoldenSet(self: *const Inventory) bool {
        return self.hasItem(.golden_helmet) and
               self.hasItem(.golden_chestplate) and
               self.hasItem(.golden_leggings) and
               self.hasItem(.golden_boots);
    }

    pub fn hasAnyGoldenArmor(self: *const Inventory) bool {
        return self.hasItem(.golden_helmet) or
               self.hasItem(.golden_chestplate) or
               self.hasItem(.golden_leggings) or
               self.hasItem(.golden_boots);
    }

    pub fn hasAnyGoldenItem(self: *const Inventory) bool {
        return self.hasAnyGoldenArmor() or
               self.hasItem(.gold_nugget) or
               self.hasItem(.golden_apple) or
               self.hasItem(.gold_block) or
               self.hasItem(.golden_sword) or
               self.hasItem(.golden_pickaxe) or
               self.hasItem(.golden_axe) or
               self.hasItem(.golden_shovel) or
               self.hasItem(.golden_hoe) or self.hasItem(.golden_carrot) or self.hasItem(.enchanted_golden_apple);
    }

    pub fn hasFullIronSet(self: *const Inventory) bool {
        return self.hasItem(.iron_helmet) and
               self.hasItem(.iron_chestplate) and
               self.hasItem(.iron_leggings) and
               self.hasItem(.iron_boots);
    }

    pub fn hasFullDiamondSet(self: *const Inventory) bool {
        return self.hasItem(.diamond_helmet) and
               self.hasItem(.diamond_chestplate) and
               self.hasItem(.diamond_leggings) and
               self.hasItem(.diamond_boots);
    }

    pub fn hasFullNetheriteSet(self: *const Inventory) bool {
        return self.hasItem(.netherite_helmet) and
               self.hasItem(.netherite_chestplate) and
               self.hasItem(.netherite_leggings) and
               (self.hasItem(.netherite_boots) or self.hasItem(.soul_speed_boots));
    }

    pub fn hasItem(self: *const Inventory, item: ItemType) bool {
        for (self.slots) |slot| {
            if (slot.item == item and slot.count > 0) return true;
        }
        return false;
    }

    pub fn consumeItem(self: *Inventory, item: ItemType) bool {
        for (&self.slots) |*slot| {
            if (slot.item == item and slot.count > 0) {
                slot.decrement(1);
                return true;
            }
        }
        return false;
    }

    pub fn consumeCrossbowAmmo(self: *Inventory) ?ItemType {
        if (self.consumeItem(.fireworks_rocket)) return .fireworks_rocket;
        if (self.consumeItem(.spectral_arrow)) return .spectral_arrow;
        if (self.consumeItem(.arrow)) return .arrow;
        return null;
    }

    pub fn consumeArrow(self: *Inventory) ?ItemType {
        if (self.consumeItem(.spectral_arrow)) return .spectral_arrow;
        if (self.consumeItem(.arrow)) return .arrow;
        return null;
    }

    pub fn addItem(self: *Inventory, item: ItemType, count: u8) u8 {
        if (item == .none or count == 0) return 0;
        var remaining = count;

        // Try existing stacks
        for (&self.slots) |*slot| {
            if (slot.item == item and slot.count < item.maxStackSize()) {
                remaining = slot.add(remaining);
                if (remaining == 0) return 0;
            }
        }

        // Place into first empty slot
        for (&self.slots) |*slot| {
            if (slot.isEmpty()) {
                const max = item.maxStackSize();
                const to_place = @min(max, remaining);
                slot.* = .{ .item = item, .count = to_place };
                remaining -= to_place;
                if (remaining == 0) return 0;
            }
        }

        return remaining;
    }

    /// Evaluates current 2x2 crafting grid and sets output preview.
    pub fn updateCrafting(self: *Inventory) void {
        const g0 = self.craft_grid[0].item;
        const g1 = self.craft_grid[1].item;
        const g2 = self.craft_grid[2].item;
        const g3 = self.craft_grid[3].item;

        // Count non-empty items
        var non_empty: usize = 0;
        for (self.craft_grid) |s| {
            if (!s.isEmpty()) non_empty += 1;
        }

        // Wave 6 weighted plates must precede the existing generic weapon recipes.
        if (non_empty == 2) {
            var gold_nugget_count: usize = 0;
            var iron_ingot_count: usize = 0;
            for (self.craft_grid) |slot| {
                if (slot.item == .gold_nugget) gold_nugget_count += 1;
                if (slot.item == .iron_ingot) iron_ingot_count += 1;
            }
            const horizontal_pair = (g0 == .gold_nugget and g1 == .gold_nugget and g2 == .none and g3 == .none) or
                (g2 == .gold_nugget and g3 == .gold_nugget and g0 == .none and g1 == .none);
            const iron_horizontal_pair = (g0 == .iron_ingot and g1 == .iron_ingot and g2 == .none and g3 == .none) or
                (g2 == .iron_ingot and g3 == .iron_ingot and g0 == .none and g1 == .none);
            if (gold_nugget_count == 2 and horizontal_pair) {
                self.craft_output = .{ .item = .light_weighted_pressure_plate, .count = 1 };
                return;
            }
            if (iron_ingot_count == 2 and iron_horizontal_pair) {
                self.craft_output = .{ .item = .heavy_weighted_pressure_plate, .count = 1 };
                return;
            }
            var has_paper = false;
            var has_compass = false;
            var has_empty_map = false;
            var has_explorer_map = false;
            for (self.craft_grid) |slot| {
                has_paper = has_paper or slot.item == .paper;
                has_compass = has_compass or slot.item == .compass;
                has_empty_map = has_empty_map or slot.item == .empty_locator_map;
                has_explorer_map = has_explorer_map or slot.item == .filled_explorer_map;
            }
            if (has_paper and has_compass) {
                self.craft_output = .{ .item = .empty_locator_map, .count = 1 };
                return;
            }
            if (has_empty_map and has_explorer_map) {
                self.craft_output = .{ .item = .filled_explorer_map, .count = 2 };
                return;
            }
            const has_book = g0 == .book or g1 == .book or g2 == .book or g3 == .book;
            const has_enchanted_book = g0 == .enchanted_book or g1 == .enchanted_book or g2 == .enchanted_book or g3 == .enchanted_book;
            const has_echo_shard = g0 == .echo_shard or g1 == .echo_shard or g2 == .echo_shard or g3 == .echo_shard;
            const has_diamond = g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond;
            if (has_book and has_echo_shard) {
                self.craft_output = .{ .item = .swift_sneak_book, .count = 1 };
                return;
            }
            if (has_enchanted_book and has_diamond) {
                self.craft_output = .{ .item = .sweeping_edge_book, .count = 1 };
                return;
            }
        }

        // Recipe: four glass blocks in a 2x2 square -> four glass panes.
        if (non_empty == 4 and g0 == .glass and g1 == .glass and g2 == .glass and g3 == .glass) {
            self.craft_output = .{ .item = .glass_pane, .count = 4 };
            return;
        }

        // Recipe 1: 1 Wood Log -> 4 Wood Planks (any single slot)
        if (non_empty == 1) {
            for (self.craft_grid) |s| {
                if (!s.isEmpty() and s.item == .wood) {
                    self.craft_output = .{ .item = .wood_planks, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 2: 2 Planks vertically -> 4 Sticks
        // Slot 0 & 2 or Slot 1 & 3
        if (non_empty == 2) {
            if ((g0 == .wood_planks and g2 == .wood_planks and g1 == .none and g3 == .none) or
                (g1 == .wood_planks and g3 == .wood_planks and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .stick, .count = 4 };
                return;
            }
        }

        // Recipe 3: 4 Wood Planks (2x2 filled) -> 1 Crafting Table
        if (non_empty == 4) {
            if (g0 == .wood_planks and g1 == .wood_planks and g2 == .wood_planks and g3 == .wood_planks) {
                self.craft_output = .{ .item = .crafting_bench, .count = 1 };
                return;
            }
        }

        
        // Recipe 31: 3 Wood Planks in U-shape (top-left, bottom-left, bottom-right OR top-right, bottom-left, bottom-right) -> 1 Boat
        if (non_empty == 3) {
            if ((g0 == .wood_planks and g2 == .wood_planks and g3 == .wood_planks and g1 == .none) or
                (g1 == .wood_planks and g2 == .wood_planks and g3 == .wood_planks and g0 == .none))
            {
                self.craft_output = .{ .item = .boat, .count = 1 };
                return;
            }
        }

        // Recipe 18: 3 Wood Planks (hollow corner 2x2) -> 1 Chest
        if (non_empty == 3) {
            const is_plank = (g0 == .wood_planks or g0 == .none) and
                (g1 == .wood_planks or g1 == .none) and
                (g2 == .wood_planks or g2 == .none) and
                (g3 == .wood_planks or g3 == .none);
            const count_planks = @as(u8, if (g0 == .wood_planks) 1 else 0) +
                @as(u8, if (g1 == .wood_planks) 1 else 0) +
                @as(u8, if (g2 == .wood_planks) 1 else 0) +
                @as(u8, if (g3 == .wood_planks) 1 else 0);
            if (is_plank and count_planks == 3) {
                self.craft_output = .{ .item = .chest, .count = 1 };
                return;
            }
        }

        // Recipe 19: 2 Planks horizontal (g0+g1 or g2+g3) + 1 Stick -> 1 Wooden Door
        if (non_empty == 3) {
            if ((g0 == .wood_planks and g1 == .wood_planks and (g2 == .stick or g3 == .stick)) or
                (g2 == .wood_planks and g3 == .wood_planks and (g0 == .stick or g1 == .stick)))
            {
                // Note: top row 2 planks + bottom stick is wooden pickaxe recipe!
                // To avoid conflict: bottom row 2 planks + top stick -> Wooden Door!
                if (g2 == .wood_planks and g3 == .wood_planks and (g0 == .stick or g1 == .stick)) {
                    self.craft_output = .{ .item = .wooden_door, .count = 1 };
                    return;
                }
            }
        }

        // Recipe 26: 1 Redstone Dust over 1 Stick (vertical) -> 1 Redstone Torch
        if (non_empty == 2) {
            if ((g0 == .redstone_dust and g2 == .stick and g1 == .none and g3 == .none) or
                (g1 == .redstone_dust and g3 == .stick and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .redstone_torch, .count = 1 };
                return;
            }
        }

        // Recipe 25: 4 Iron Ingots (2x2 filled) -> 1 Iron Door (or 1 Block of Iron when total >= 8)
        if (non_empty == 4) {
            if (g0 == .iron_ingot and g1 == .iron_ingot and g2 == .iron_ingot and g3 == .iron_ingot) {
                const total_iron = @as(u16, self.craft_grid[0].count) + self.craft_grid[1].count + self.craft_grid[2].count + self.craft_grid[3].count;
                if (total_iron >= 8) {
                    self.craft_output = .{ .item = .iron_block, .count = 1 };
                } else {
                    self.craft_output = .{ .item = .iron_door, .count = 1 };
                }
                return;
            }
        }

        // Recipe 24: Redstone Lamp (1 Torch + 1 Glass + 2 Redstone Dust in 2x2)
        if (non_empty == 4) {
            var torch_cnt: u8 = 0;
            var glass_cnt: u8 = 0;
            var red_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .torch) torch_cnt += 1 else if (sl.item == .glass) glass_cnt += 1 else if (sl.item == .redstone_dust) red_cnt += 1;
            }
            if (torch_cnt == 1 and glass_cnt == 1 and red_cnt == 2) {
                self.craft_output = .{ .item = .redstone_lamp, .count = 1 };
                return;
            }
        }

        // Recipe 23: Redstone Repeater (2 torches + 1 redstone dust + 1 stone in 2x2)
        if (non_empty == 4) {
            var torches_cnt: u8 = 0;
            var red_cnt: u8 = 0;
            var stone_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .torch) torches_cnt += 1 else if (sl.item == .redstone_dust) red_cnt += 1 else if (sl.item == .stone) stone_cnt += 1;
            }
            if (torches_cnt == 2 and red_cnt == 1 and stone_cnt == 1) {
                self.craft_output = .{ .item = .redstone_repeater, .count = 1 };
                return;
            }
        }

        // Recipe 22: 1 Stick above 1 Cobblestone (vertical) -> 1 Lever
        if (non_empty == 2) {
            if ((g0 == .stick and g2 == .cobblestone and g1 == .none and g3 == .none) or
                (g1 == .stick and g3 == .cobblestone and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .lever, .count = 1 };
                return;
            }
        }

        // Recipe 21: 1 Coal + 1 Iron Ingot (vertical or horizontal) -> 4 Redstone Dust
        if (non_empty == 2) {
            const has_c = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal);
            const has_i = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            if (has_c and has_i) {
                // Ensure not torches (coal + stick) or smelting
                self.craft_output = .{ .item = .redstone_dust, .count = 4 };
                return;
            }
        }

        // Recipe 20: 2 Wood Planks horizontally (g0+g1 or g2+g3) -> 1 Pressure Plate
        if (non_empty == 2) {
            if ((g0 == .wood_planks and g1 == .wood_planks and g2 == .none and g3 == .none) or
                (g2 == .wood_planks and g3 == .wood_planks and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .pressure_plate, .count = 1 };
                return;
            }
        }

        // Recipe 4: Wooden Pickaxe recipe in 2x2:
        // Top row: 2 wood planks (g0, g1), bottom: 1 stick (g2 or g3)
        if (non_empty == 3) {
            if (g0 == .wood_planks and g1 == .wood_planks and (g2 == .stick or g3 == .stick)) {
                self.craft_output = .{ .item = .wooden_pickaxe, .count = 1 };
                return;
            }
        }

        // Recipe: 2 Nether Bricks stacked vertically -> 2 Nether Brick Fences
        if (non_empty == 2) {
            if ((g0 == .nether_brick and g2 == .nether_brick and g1 == .none and g3 == .none) or
                (g1 == .nether_brick and g3 == .nether_brick and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .nether_brick_fence, .count = 2 };
                return;
            }
        }

        // Recipe: 2 Quartz Blocks stacked vertically -> 2 Quartz Pillars
        if (non_empty == 2) {
            if ((g0 == .quartz_block and g2 == .quartz_block and g1 == .none and g3 == .none) or
                (g1 == .quartz_block and g3 == .quartz_block and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .quartz_pillar, .count = 2 };
                return;
            }
        }

        // Recipe: 2 Quartz Pillars stacked vertically -> 2 Chiseled Quartz Blocks
        if (non_empty == 2) {
            if ((g0 == .quartz_pillar and g2 == .quartz_pillar and g1 == .none and g3 == .none) or
                (g1 == .quartz_pillar and g3 == .quartz_pillar and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .chiseled_quartz_block, .count = 2 };
                return;
            }
        }

        // Recipe: 4 Nether Quartz in 2x2 grid -> 1 Block of Quartz
        if (non_empty == 4) {
            var quartz_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .nether_quartz) quartz_cnt += 1;
            }
            if (quartz_cnt == 4) {
                self.craft_output = .{ .item = .quartz_block, .count = 1 };
                return;
            }
        }

        // Recipe: 4 Netherrack (2x2 filled) -> 4 Nether Bricks
        if (non_empty == 4) {
            if (g0 == .netherrack and g1 == .netherrack and g2 == .netherrack and g3 == .netherrack) {
                self.craft_output = .{ .item = .nether_brick, .count = 4 };
                return;
            }
        }

        // Recipe 5: 4 Sand (2x2 filled) -> 1 Sandstone
        if (non_empty == 4) {
            if (g0 == .sand and g1 == .sand and g2 == .sand and g3 == .sand) {
                self.craft_output = .{ .item = .sandstone, .count = 1 };
                return;
            }
        }

        // Recipe 6: 4 Cobblestone (2x2 filled) -> 4 Bricks
        if (non_empty == 4) {
            if (g0 == .cobblestone and g1 == .cobblestone and g2 == .cobblestone and g3 == .cobblestone) {
                self.craft_output = .{ .item = .brick, .count = 4 };
                return;
            }
        }

        // Recipe 17: 1 Coal above 1 Stick (vertical) -> 4 Torches
        if (non_empty == 2) {
            if ((g0 == .coal and g2 == .stick and g1 == .none and g3 == .none) or
                (g1 == .coal and g3 == .stick and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .torch, .count = 4 };
                return;
            }
        }

        // Recipe 16: 2 Sand + 2 Coal (diagonal checkerboard) -> 1 TNT
        if (non_empty == 4) {
            if ((g0 == .sand and g3 == .sand and g1 == .coal and g2 == .coal) or
                (g1 == .sand and g2 == .sand and g0 == .coal and g3 == .coal))
            {
                self.craft_output = .{ .item = .tnt, .count = 1 };
                return;
            }
        }

        // Recipe 15: 3 Sticks (any 3 slots in 2x2) -> 3 Ladders
        if (non_empty == 3) {
            var sticks: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .stick) sticks += 1;
            }
            if (sticks == 3) {
                self.craft_output = .{ .item = .ladder, .count = 3 };
                return;
            }
        }

        // Recipe 14: Iron Sword: 2 ingots vertically
        if (non_empty == 2) {
            if ((g0 == .iron_ingot and g2 == .iron_ingot and g1 == .none and g3 == .none) or
                (g1 == .iron_ingot and g3 == .iron_ingot and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .iron_sword, .count = 1 };
                return;
            }
        }

        // Recipe 11: Iron Pickaxe: top row 2 ingots + stick below (either slot)
        if (non_empty == 3) {
            if (g0 == .iron_ingot and g1 == .iron_ingot and (g2 == .stick or g3 == .stick)) {
                self.craft_output = .{ .item = .iron_pickaxe, .count = 1 };
                return;
            }
        }

        // Recipe 36: Soul Campfire: 1 Soul Sand + 1 Campfire -> 1 Soul Campfire (non_empty == 2)
        if (non_empty == 2) {
            const has_soul = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand);
            const has_fire = (g0 == .campfire or g1 == .campfire or g2 == .campfire or g3 == .campfire);
            if (has_soul and has_fire) {
                self.craft_output = .{ .item = .soul_campfire, .count = 1 };
                return;
            }
        }

        // Recipe 35: Soul Torch: 1 Soul Sand + 1 Torch -> 2 Soul Torches (non_empty == 2)
        if (non_empty == 2) {
            const has_soul = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand);
            const has_torch = (g0 == .torch or g1 == .torch or g2 == .torch or g3 == .torch);
            if (has_soul and has_torch) {
                self.craft_output = .{ .item = .soul_torch, .count = 2 };
                return;
            }
        }

        // Recipe 34: Fire Charge: 1 Magma Cream + 1 Coal -> 3 Fire Charges (non_empty == 2)
        if (non_empty == 2) {
            const has_cream = (g0 == .magma_cream or g1 == .magma_cream or g2 == .magma_cream or g3 == .magma_cream);
            const has_coal = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal);
            if (has_cream and has_coal) {
                self.craft_output = .{ .item = .fire_charge, .count = 3 };
                return;
            }
        }

        // Recipe 33: Magma Cream: 1 Coal + 1 Nether Wart (non_empty == 2)
        if (non_empty == 2) {
            const has_coal = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal);
            const has_wart = (g0 == .nether_wart or g1 == .nether_wart or g2 == .nether_wart or g3 == .nether_wart);
            if (has_coal and has_wart) {
                self.craft_output = .{ .item = .magma_cream, .count = 1 };
                return;
            }
        }

        // Recipe 32: Fire Resistance Potion: 1 Magma/Magma Cream + 1 Glass vial (or 1 Nether Wart + 1 Glass vial, or legacy apple).
        // Wart brewing requires a glass vial as the potion vessel; apple no longer substitutes for wart.
        if (non_empty == 2) {
            const has_magma = (g0 == .magma or g1 == .magma or g2 == .magma or g3 == .magma or
                g0 == .magma_cream or g1 == .magma_cream or g2 == .magma_cream or g3 == .magma_cream);
            const has_apple = (g0 == .apple or g1 == .apple or g2 == .apple or g3 == .apple);
            const has_glass = (g0 == .glass or g1 == .glass or g2 == .glass or g3 == .glass);
            const has_wart = (g0 == .nether_wart or g1 == .nether_wart or g2 == .nether_wart or g3 == .nether_wart);
            if ((has_magma and (has_apple or has_glass)) or (has_wart and has_glass)) {
                self.craft_output = .{ .item = .fire_resistance_potion, .count = 1 };
                return;
            }
        }






        // Recipe 130: Prismarine Block: 4 Prismarine Shards (2x2) -> 1 Prismarine Block
        if (non_empty == 4) {
            var shard_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .prismarine_shard) shard_c += 1;
            }
            if (shard_c == 4) {
                self.craft_output = .{ .item = .prismarine, .count = 1 };
                return;
            }
        }

        // Recipe 131: Prismarine Bricks: 2 Prismarine + 2 Cobblestone / Stone -> 2 Prismarine Bricks
        if (non_empty == 4) {
            var pris_c: usize = 0;
            var stone_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .prismarine) pris_c += 1;
                if (sl.item == .cobblestone or sl.item == .stone) stone_c += 1;
            }
            if (pris_c == 2 and stone_c == 2) {
                self.craft_output = .{ .item = .prismarine_bricks, .count = 2 };
                return;
            }
        }

        // Recipe 132: Dark Prismarine: 2 Prismarine + 2 Coal -> 2 Dark Prismarine
        if (non_empty == 4) {
            var pris_c: usize = 0;
            var coal_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .prismarine) pris_c += 1;
                if (sl.item == .coal or sl.item == .obsidian) coal_c += 1;
            }
            if (pris_c == 2 and coal_c == 2) {
                self.craft_output = .{ .item = .dark_prismarine, .count = 2 };
                return;
            }
        }

        // Recipe 133: Sea Lantern: 2 Prismarine Shards + 2 Prismarine Crystals (or Glowstone) -> 1 Sea Lantern
        if (non_empty == 4) {
            var shard_cnt: usize = 0;
            var crystal_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .prismarine_shard) shard_cnt += 1;
                if (sl.item == .prismarine_crystals or sl.item == .glowstone) crystal_cnt += 1;
            }
            if (shard_cnt == 2 and crystal_cnt == 2) {
                self.craft_output = .{ .item = .sea_lantern, .count = 1 };
                return;
            }
        }

        // Recipe 137: Dried Kelp Unpacking: 1 Dried Kelp Block -> 4 Dried Kelp
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .dried_kelp_block) {
                    self.craft_output = .{ .item = .dried_kelp, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 136: Dried Kelp Block: 4 Dried Kelp (in 2x2 grid) -> 1 Dried Kelp Block
        if (non_empty == 4) {
            var dk_count: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .dried_kelp) dk_count += 1;
            }
            if (dk_count == 4) {
                self.craft_output = .{ .item = .dried_kelp_block, .count = 1 };
                return;
            }
        }

        // Recipe 135: Fishing Rod: 2 Sticks + 2 Strings (or 1 String + 1 Scute/Membrane) -> 1 Fishing Rod
        if (non_empty >= 2 and non_empty <= 4) {
            var stick_c: usize = 0;
            var line_c: usize = 0;
            var other_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .stick) stick_c += sl.count
                else if (sl.item == .string or sl.item == .scute or sl.item == .phantom_membrane) line_c += sl.count
                else if (sl.item != .none) other_c += 1;
            }
            if (stick_c >= 2 and line_c >= 2 and other_c == 0) {
                self.craft_output = .{ .item = .fishing_rod, .count = 1 };
                return;
            }
        }

        // Recipe 134: Conduit: 1 Heart of the Sea + 1 Prismarine Shard / Crystal / Scute -> 1 Conduit
        if (non_empty == 2) {
            var heart_cnt: usize = 0;
            var shell_catalyst: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .heart_of_the_sea) heart_cnt += 1;
                if (sl.item == .nautilus_shell or sl.item == .prismarine_shard or sl.item == .prismarine_crystals or sl.item == .scute or sl.item == .trident) shell_catalyst += 1;
            }
            if (heart_cnt == 1 and shell_catalyst == 1) {
                self.craft_output = .{ .item = .conduit, .count = 1 };
                return;
            }
        }

        // Recipe 128: Slow Falling Potion: 1 Phantom Membrane + 1 Glass vial (or nether wart) -> 1 Slow Falling Potion
        if (non_empty == 2) {
            var memb_c: usize = 0;
            var liquid_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .phantom_membrane) memb_c += 1;
                if (sl.item == .glass or sl.item == .nether_wart or sl.item == .water) liquid_c += 1;
            }
            if (memb_c == 1 and liquid_c == 1) {
                self.craft_output = .{ .item = .slow_falling_potion, .count = 1 };
                return;
            }
        }

        // Recipe 129: Elytra Membrane Repair / Craft: 2 Phantom Membranes + 2 Feathers/String/Purpur -> 1 Elytra
        if (non_empty == 4) {
            var memb_cnt: usize = 0;
            var supp_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .phantom_membrane) memb_cnt += 1;
                if (sl.item == .string or sl.item == .purpur_block or sl.item == .wool) supp_cnt += 1;
            }
            if (memb_cnt == 2 and supp_cnt == 2) {
                self.craft_output = .{ .item = .elytra, .count = 1 };
                return;
            }
        }

        // Recipe 127: Trident: 2 Iron Ingots + 1 Scute + 1 Stick -> 1 Trident
        if (non_empty == 4) {
            var iron_c: usize = 0;
            var scute_c: usize = 0;
            var stick_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) iron_c += 1;
                if (sl.item == .scute) scute_c += 1;
                if (sl.item == .stick) stick_c += 1;
            }
            if (iron_c == 2 and scute_c == 1 and stick_c == 1) {
                self.craft_output = .{ .item = .trident, .count = 1 };
                return;
            }
        }

        // Recipe 125: Turtle Shell Helmet: 4 Scutes (filling 2x2 grid) -> 1 Turtle Shell Helmet
        if (non_empty == 4) {
            var scute_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .scute) scute_cnt += 1;
            }
            if (scute_cnt == 4) {
                self.craft_output = .{ .item = .turtle_helmet, .count = 1 };
                return;
            }
        }

        // Recipe 139: Rail: 2 Iron Ingots in vertical column + 1 Stick -> 4 Rails
        if (non_empty == 3) {
            if ((g0 == .iron_ingot and g2 == .iron_ingot and (g1 == .stick or g3 == .stick)) or
                (g1 == .iron_ingot and g3 == .iron_ingot and (g0 == .stick or g2 == .stick)))
            {
                self.craft_output = .{ .item = .rail, .count = 4 };
                return;
            }
        }

        // Recipe 140: Powered Rail: 2 Gold Nuggets + 1 Redstone Dust + 1 Stick -> 4 Powered Rails
        if (non_empty == 4) {
            var gold_c: usize = 0;
            var red_c: usize = 0;
            var stick_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .gold_nugget) gold_c += sl.count;
                if (sl.item == .redstone_dust) red_c += sl.count;
                if (sl.item == .stick) stick_c += sl.count;
            }
            if (gold_c >= 2 and red_c >= 1 and stick_c >= 1) {
                self.craft_output = .{ .item = .powered_rail, .count = 4 };
                return;
            }
        }

        // Recipe 141: Minecart: 3 Iron Ingots (U-shape in 2x2 grid) -> 1 Minecart
        if (non_empty == 3) {
            if ((g0 == .iron_ingot and g2 == .iron_ingot and g3 == .iron_ingot and g1 == .none) or
                (g1 == .iron_ingot and g2 == .iron_ingot and g3 == .iron_ingot and g0 == .none))
            {
                self.craft_output = .{ .item = .minecart, .count = 1 };
                return;
            }
        }

        // Recipe 142: Detector Rail: 2 Iron Ingots + 1 Stone/Pressure Plate + 1 Redstone Dust -> 6 Detector Rails
        if (non_empty == 3 or non_empty == 4) {
            var iron_c: usize = 0;
            var red_c: usize = 0;
            var plate_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) iron_c += sl.count;
                if (sl.item == .redstone_dust) red_c += sl.count;
                if (sl.item == .pressure_plate or sl.item == .stone or sl.item == .cobblestone) plate_c += sl.count;
            }
            if (iron_c >= 2 and red_c >= 1 and plate_c >= 1) {
                self.craft_output = .{ .item = .detector_rail, .count = 6 };
                return;
            }
        }

        // Recipe 143: Activator Rail: 2 Iron Ingots + 1 Redstone Torch + 1 Stick -> 6 Activator Rails
        if (non_empty == 3 or non_empty == 4) {
            var iron_c: usize = 0;
            var torch_c: usize = 0;
            var stick_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) iron_c += sl.count;
                if (sl.item == .redstone_torch or sl.item == .torch) torch_c += sl.count;
                if (sl.item == .stick) stick_c += sl.count;
            }
            if (iron_c >= 2 and torch_c >= 1 and stick_c >= 1) {
                self.craft_output = .{ .item = .activator_rail, .count = 6 };
                return;
            }
        }

        // Recipe 144: Minecart with Chest: 1 Minecart + 1 Chest -> 1 Minecart with Chest
        if (non_empty == 2) {
            var cart_c: usize = 0;
            var chest_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .minecart) cart_c += 1;
                if (sl.item == .chest) chest_c += 1;
            }
            if (cart_c == 1 and chest_c == 1) {
                self.craft_output = .{ .item = .chest_minecart, .count = 1 };
                return;
            }
        }

        // Recipe 145: Minecart with Furnace: 1 Minecart + 1 Furnace -> 1 Minecart with Furnace
        if (non_empty == 2) {
            var cart_c: usize = 0;
            var furn_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .minecart) cart_c += 1;
                if (sl.item == .furnace or sl.item == .blast_furnace or sl.item == .smoker) furn_c += 1;
            }
            if (cart_c == 1 and furn_c == 1) {
                self.craft_output = .{ .item = .furnace_minecart, .count = 1 };
                return;
            }
        }

        // Recipe 146: Minecart with TNT: 1 Minecart + 1 TNT -> 1 Minecart with TNT
        if (non_empty == 2) {
            var cart_c: usize = 0;
            var tnt_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .minecart) cart_c += 1;
                if (sl.item == .tnt) tnt_c += 1;
            }
            if (cart_c == 1 and tnt_c == 1) {
                self.craft_output = .{ .item = .tnt_minecart, .count = 1 };
                return;
            }
        }

        // Recipe 147: Minecart with Hopper: 1 Minecart + 1 Hopper -> 1 Minecart with Hopper
        if (non_empty == 2) {
            var cart_c: usize = 0;
            var hop_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .minecart) cart_c += 1;
                if (sl.item == .hopper) hop_c += 1;
            }
            if (cart_c == 1 and hop_c == 1) {
                self.craft_output = .{ .item = .hopper_minecart, .count = 1 };
                return;
            }
        }

        // Recipe 287: Calibrated Sculk Sensor: 1 Sculk Sensor + 1..3 Amethyst Shards -> 1 Calibrated Sculk Sensor
        if (non_empty >= 2 and non_empty <= 4) {
            var ssn_cnt: u8 = 0;
            var ame_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .sculk_sensor) ssn_cnt += 1;
                if (sl.item == .amethyst_shard) ame_cnt += 1;
            }
            if (ssn_cnt == 1 and ame_cnt >= 1 and (ssn_cnt + ame_cnt == non_empty)) {
                self.craft_output = .{ .item = .calibrated_sculk_sensor, .count = 1 };
                return;
            }
        }

        // Recipes 288-290: Mangrove Planks (1 Mangrove Log -> 4 Planks), Muddy Mangrove Roots (Mangrove Roots + Mud), Armor Trim (Template + Mineral)
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .mangrove_log) {
                    self.craft_output = .{ .item = .mangrove_planks, .count = 4 };
                    return;
                }
                if (sl.item == .cherry_log) {
                    self.craft_output = .{ .item = .cherry_planks, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 292: Chiseled Bookshelf: 2 Planks + 1 Book -> 1 Chiseled Bookshelf
        if (non_empty == 3) {
            var plk_c: u8 = 0;
            var bk_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wood_planks or sl.item == .mangrove_planks or sl.item == .cherry_planks) plk_c += 1;
                if (sl.item == .book) bk_c += 1;
            }
            if (plk_c == 2 and bk_c == 1) {
                self.craft_output = .{ .item = .chiseled_bookshelf, .count = 1 };
                return;
            }
        }

        // Recipe 293: Hanging Sign: 2 Chains + 1 Planks/Log -> 2 Hanging Signs
        if (non_empty == 3) {
            var chn_c: u8 = 0;
            var wd_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .chain) chn_c += 1;
                if (sl.item == .wood_planks or sl.item == .cherry_planks or sl.item == .mangrove_planks or sl.item == .wood or sl.item == .cherry_log or sl.item == .mangrove_log or sl.item == .pale_oak_log) wd_c += 1;
            }
            if (chn_c == 2 and wd_c == 1) {
                self.craft_output = .{ .item = .hanging_sign, .count = 2 };
                return;
            }
        }

        // Recipe 294: Bamboo Mosaic: 4 Bamboo (or 2 horizontal Bamboo) -> 1 Bamboo Mosaic
        if (non_empty == 4) {
            var bmb_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .bamboo) bmb_c += 1;
            }
            if (bmb_c == 4) {
                self.craft_output = .{ .item = .bamboo_mosaic, .count = 1 };
                return;
            }
        }
        if (non_empty == 2) {
            if ((g0 == .bamboo and g1 == .bamboo and g2 == .none and g3 == .none) or
                (g2 == .bamboo and g3 == .bamboo and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .bamboo_mosaic, .count = 1 };
                return;
            }
        }

        // Recipe 295: Resin Bricks: 4 Resin Brick items -> 1 Resin Bricks block
        if (non_empty == 4) {
            var rsb_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .resin_brick or sl.item == .resin_clump) rsb_c += 1;
            }
            if (rsb_c == 4) {
                self.craft_output = .{ .item = .resin_bricks, .count = 1 };
                return;
            }
        }

        // Recipe 296: Creaking Heart: 2 Pale Oak Logs + 1 Resin Bricks -> 1 Creaking Heart
        if (non_empty == 3) {
            var pol_c: u8 = 0;
            var rsbk_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .pale_oak_log) pol_c += 1;
                if (sl.item == .resin_bricks) rsbk_c += 1;
            }
            if (pol_c == 2 and rsbk_c == 1) {
                self.craft_output = .{ .item = .creaking_heart, .count = 1 };
                return;
            }
        }

        // Recipe 297: Wolf Armor: 4 (or 2) Armadillo Scutes -> 1 Wolf Armor
        if (non_empty == 4) {
            var sct_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .armadillo_scute) sct_c += 1;
            }
            if (sct_c == 4) {
                self.craft_output = .{ .item = .wolf_armor, .count = 1 };
                return;
            }
        }
        if (non_empty == 2) {
            var sct_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .armadillo_scute) sct_c += 1;
            }
            if (sct_c == 2) {
                self.craft_output = .{ .item = .wolf_armor, .count = 1 };
                return;
            }
        }

        // Recipe 298: Ominous Trial Key: 1 Trial Key + 1 Ominous Bottle -> 1 Ominous Trial Key
        if (non_empty == 2) {
            var tk_c: u8 = 0;
            var ob_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .trial_key) tk_c += 1;
                if (sl.item == .ominous_bottle) ob_c += 1;
            }
            if (tk_c == 1 and ob_c == 1) {
                self.craft_output = .{ .item = .ominous_trial_key, .count = 1 };
                return;
            }
        }

        // Recipe 299: Ominous Vault: 1 Vault + 1 Ominous Bottle -> 1 Ominous Vault
        if (non_empty == 2) {
            var vt_c: u8 = 0;
            var ob_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .vault) vt_c += 1;
                if (sl.item == .ominous_bottle) ob_c += 1;
            }
            if (vt_c == 1 and ob_c == 1) {
                self.craft_output = .{ .item = .ominous_vault, .count = 1 };
                return;
            }
        }

        // Recipe 300: Trial Alchemy: Reagent + Glass/Nether Wart -> Potion
        if (non_empty == 2) {
            var vsl_c: u8 = 0;
            var reagent: ?ItemType = null;
            for (self.craft_grid) |sl| {
                if (sl.item == .glass or sl.item == .nether_wart) vsl_c += 1
                else if (reagent == null) reagent = sl.item;
            }
            if (vsl_c == 1 and reagent != null) {
                switch (reagent.?) {
                    .wind_charge, .breeze_rod => {
                        self.craft_output = .{ .item = .potion_of_wind_charged, .count = 1 };
                        return;
                    },
                    .slimeball, .slime_block => {
                        self.craft_output = .{ .item = .potion_of_oozing, .count = 1 };
                        return;
                    },
                    .cobweb, .string => {
                        self.craft_output = .{ .item = .potion_of_weaving, .count = 1 };
                        return;
                    },
                    .stone, .cobblestone, .iron_ingot => {
                        self.craft_output = .{ .item = .potion_of_infested, .count = 1 };
                        return;
                    },
                    else => {},
                }
            }
        }

        // Recipe 301: Bundle: 1 String + 1 Leather -> 1 Bundle
        if (non_empty == 2) {
            var str_c: u8 = 0;
            var lth_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .string) str_c += 1;
                if (sl.item == .leather) lth_c += 1;
            }
            if (str_c == 1 and lth_c == 1) {
                self.craft_output = .{ .item = .bundle, .count = 1 };
                return;
            }
        }

        // Recipe 302: Copper Door: 3 Copper Ingots -> 1 Copper Door
        if (non_empty == 3) {
            var cpi_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .copper_ingot) cpi_c += 1;
            }
            if (cpi_c == 3) {
                self.craft_output = .{ .item = .copper_door, .count = 1 };
                return;
            }
        }

        // Recipe 303: Copper Trapdoor: 1 Copper Door -> 2 Copper Trapdoors or 2 Copper Ingots horizontally
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .copper_door and sl.count >= 1) {
                    self.craft_output = .{ .item = .copper_trapdoor, .count = 2 };
                    return;
                }
            }
        }
        if (non_empty == 2) {
            if ((g0 == .copper_ingot and g1 == .copper_ingot and g2 == .none and g3 == .none) or
                (g2 == .copper_ingot and g3 == .copper_ingot and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .copper_trapdoor, .count = 2 };
                return;
            }
        }

        // Wave 3 utility recipes: dried ghast, ghast harness, copper golem statue, and banner.
        if (non_empty == 2 and ((g0 == .bone and g1 == .bone) or (g2 == .bone and g3 == .bone))) {
            self.craft_output = .{ .item = .dried_ghast, .count = 1 };
            return;
        }
        if (non_empty == 4) {
            var leather_count: u8 = 0;
            var glass_count: u8 = 0;
            var wool_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .leather) leather_count += 1;
                if (sl.item == .glass) glass_count += 1;
                if (sl.item == .wool) wool_count += 1;
            }
            if (leather_count == 2 and glass_count == 1 and wool_count == 1) {
                self.craft_output = .{ .item = .ghast_harness, .count = 1 };
                return;
            }
        }
        if (non_empty == 2) {
            var copper_count: u8 = 0;
            var pumpkin_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .copper_ingot) copper_count += 1;
                if (sl.item == .carved_pumpkin) pumpkin_count += 1;
            }
            if (copper_count == 1 and pumpkin_count == 1) {
                self.craft_output = .{ .item = .copper_golem_statue, .count = 1 };
                return;
            }
        }
        if (non_empty == 4) {
            var wool_count: u8 = 0;
            var stick_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wool) wool_count += 1;
                if (sl.item == .stick) stick_count += 1;
            }
            if (wool_count == 3 and stick_count == 1) {
                self.craft_output = .{ .item = .banner, .count = 1 };
                return;
            }
        }
        if (non_empty == 1) {
            for (self.craft_grid) |sl| if (sl.item == .sculk and sl.count >= 1) {
                self.craft_output = .{ .item = .sculk_catalyst, .count = 1 };
                return;
            };
        }

        // Recipe 304: Music Disc 5: 4 (or 2) Disc Fragments (5) -> 1 Music Disc 5
        if (non_empty == 4) {
            var df_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .disc_fragment_5) df_c += 1;
            }
            if (df_c == 4) {
                self.craft_output = .{ .item = .music_disc_5, .count = 1 };
                return;
            }
        }
        if (non_empty == 2) {
            var df_c: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .disc_fragment_5) df_c += 1;
            }
            if (df_c == 2) {
                self.craft_output = .{ .item = .music_disc_5, .count = 1 };
                return;
            }
        }
        if (non_empty == 2) {
            var rts_cnt: u8 = 0;
            var mud_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .mangrove_roots) rts_cnt += 1;
                if (sl.item == .mud) mud_cnt += 1;
            }
            if (rts_cnt == 1 and mud_cnt == 1) {
                self.craft_output = .{ .item = .muddy_mangrove_roots, .count = 1 };
                return;
            }
        }

        // Recipe 279 & 280: Wind Charge (1 Breeze Rod -> 4 Wind Charges) & Mace (1 Heavy Core + 1 Breeze Rod -> 1 Mace)
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .breeze_rod) {
                    self.craft_output = .{ .item = .wind_charge, .count = 4 };
                    return;
                }
            }
        }
        if (non_empty == 2) {
            var hvc_cnt: u8 = 0;
            var brz_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .heavy_core) hvc_cnt += 1;
                if (sl.item == .breeze_rod) brz_cnt += 1;
            }
            if (hvc_cnt == 1 and brz_cnt == 1) {
                self.craft_output = .{ .item = .mace, .count = 1 };
                return;
            }
        }

        // Recipe 281: Crafter: 1 Crafting Bench + 1 Dropper + 1..2 Redstone Dust/Iron Ingots -> 1 Crafter
        if (non_empty >= 3 and non_empty <= 4) {
            var cft_cnt: u8 = 0;
            var drp_cnt: u8 = 0;
            var rds_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .crafting_bench) cft_cnt += 1;
                if (sl.item == .dropper) drp_cnt += 1;
                if (sl.item == .redstone_dust or sl.item == .iron_ingot) rds_cnt += 1;
            }
            if (cft_cnt == 1 and drp_cnt == 1 and rds_cnt >= 1 and (cft_cnt + drp_cnt + rds_cnt == non_empty)) {
                self.craft_output = .{ .item = .crafter, .count = 1 };
                return;
            }
        }

        // Recipe 282 & 283: Enchanted Golden Apple (1 Golden Apple + 2..3 Gold Blocks) & Suspicious Stew (1 Mushroom Stew + 1 Glow Berries/Sweet Berries)
        if (non_empty >= 3 and non_empty <= 4) {
            var gap_cnt: u8 = 0;
            var gbk_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .golden_apple) gap_cnt += 1;
                if (sl.item == .gold_block) gbk_cnt += 1;
            }
            if (gap_cnt == 1 and gbk_cnt >= 2 and (gap_cnt + gbk_cnt == non_empty)) {
                self.craft_output = .{ .item = .enchanted_golden_apple, .count = 1 };
                return;
            }
        }
        if (non_empty == 2) {
            var stw_cnt: u8 = 0;
            var flw_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .mushroom_stew) stw_cnt += 1;
                if (sl.item == .glow_berries or sl.item == .sweet_berries or sl.item == .golden_carrot) flw_cnt += 1;
            }
            if (stw_cnt == 1 and flw_cnt == 1) {
                self.craft_output = .{ .item = .suspicious_stew, .count = 1 };
                return;
            }
        }

        // Recipes 284-286: Tuff -> Polished Tuff (4x), Polished Tuff -> Tuff Bricks (4x), Tuff Bricks vertically -> Chiseled Tuff (2x)
        if (non_empty == 4) {
            if (g0 == .tuff and g1 == .tuff and g2 == .tuff and g3 == .tuff) {
                self.craft_output = .{ .item = .polished_tuff, .count = 4 };
                return;
            }
            if (g0 == .polished_tuff and g1 == .polished_tuff and g2 == .polished_tuff and g3 == .polished_tuff) {
                self.craft_output = .{ .item = .tuff_bricks, .count = 4 };
                return;
            }
        }
        if (non_empty == 2) {
            if ((g0 == .tuff_bricks and g2 == .tuff_bricks and g1 == .none and g3 == .none) or
                (g1 == .tuff_bricks and g3 == .tuff_bricks and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .chiseled_tuff, .count = 2 };
                return;
            }
        }

        // Recipe 266: Ender Chest: 2..3 Obsidian + 1 Eye of Ender -> 1 Ender Chest
        if (non_empty >= 3 and non_empty <= 4) {
            var obs_cnt: u8 = 0;
            var eye_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .obsidian) obs_cnt += 1;
                if (sl.item == .eye_of_ender) eye_cnt += 1;
            }
            if (obs_cnt >= 2 and eye_cnt == 1 and (obs_cnt + eye_cnt == non_empty)) {
                self.craft_output = .{ .item = .ender_chest, .count = 1 };
                return;
            }
        }

        // Recipes 267-270: Chainmail Armor Suit (2 Chains horizontally -> Helmet, 4 Chains -> Chestplate, 3 Chains -> Leggings, 2 Chains vertically -> Boots)
        if (non_empty == 2) {
            if ((g0 == .chain and g1 == .chain and g2 == .none and g3 == .none) or
                (g2 == .chain and g3 == .chain and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .chainmail_helmet, .count = 1 };
                return;
            }
            if ((g0 == .chain and g2 == .chain and g1 == .none and g3 == .none) or
                (g1 == .chain and g3 == .chain and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .chainmail_boots, .count = 1 };
                return;
            }
        }
        if (non_empty == 4 and g0 == .chain and g1 == .chain and g2 == .chain and g3 == .chain) {
            self.craft_output = .{ .item = .chainmail_chestplate, .count = 1 };
            return;
        }
        if (non_empty == 3) {
            var chn_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .chain) chn_cnt += 1;
            }
            if (chn_cnt == 3) {
                self.craft_output = .{ .item = .chainmail_leggings, .count = 1 };
                return;
            }
        }

        // Recipes 271-273: Mud (Dirt + Water Bucket), Packed Mud (Mud + Wheat), Mud Bricks (4 Packed Mud -> 4 Mud Bricks)
        if (non_empty == 2) {
            var drt_cnt: u8 = 0;
            var wtr_cnt: u8 = 0;
            var mud_cnt: u8 = 0;
            var wht_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .dirt) drt_cnt += 1;
                if (sl.item == .water_bucket) wtr_cnt += 1;
                if (sl.item == .mud) mud_cnt += 1;
                if (sl.item == .wheat) wht_cnt += 1;
            }
            if (drt_cnt == 1 and wtr_cnt == 1) {
                self.craft_output = .{ .item = .mud, .count = 1 };
                return;
            }
            if (mud_cnt == 1 and wht_cnt == 1) {
                self.craft_output = .{ .item = .packed_mud, .count = 1 };
                return;
            }
        }
        if (non_empty == 4 and g0 == .packed_mud and g1 == .packed_mud and g2 == .packed_mud and g3 == .packed_mud) {
            self.craft_output = .{ .item = .mud_bricks, .count = 4 };
            return;
        }

        // Recipes 274-276: Copper Bulb (1..2 Copper Block + 1 Blaze Rod + 1 Redstone Dust -> 4 Copper Bulbs), Chiseled Copper (2 Copper Blocks vertically -> 2 Chiseled Copper), Copper Grate (4 Copper Blocks -> 4 Copper Grates)
        if (non_empty >= 3 and non_empty <= 4) {
            var cpb_cnt: u8 = 0;
            var blz_cnt: u8 = 0;
            var red_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .copper_block) cpb_cnt += 1;
                if (sl.item == .blaze_rod) blz_cnt += 1;
                if (sl.item == .redstone_dust) red_cnt += 1;
            }
            if (cpb_cnt >= 1 and blz_cnt == 1 and red_cnt == 1 and (cpb_cnt + blz_cnt + red_cnt == non_empty)) {
                self.craft_output = .{ .item = .copper_bulb, .count = 4 };
                return;
            }
        }
        if (non_empty == 2) {
            if ((g0 == .copper_block and g2 == .copper_block and g1 == .none and g3 == .none) or
                (g1 == .copper_block and g3 == .copper_block and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .chiseled_copper, .count = 2 };
                return;
            }
        }
        if (non_empty == 4 and g0 == .copper_block and g1 == .copper_block and g2 == .copper_block and g3 == .copper_block) {
            self.craft_output = .{ .item = .copper_grate, .count = 4 };
            return;
        }

        // Recipes 277 & 278: Brush (1 Copper Ingot + 1 Stick + 1 String -> 1 Brush) & Decorated Pot (4 Pottery Sherds -> 1 Decorated Pot)
        if (non_empty == 3) {
            var cpi_cnt: u8 = 0;
            var stk_cnt: u8 = 0;
            var str_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .copper_ingot) cpi_cnt += 1;
                if (sl.item == .stick) stk_cnt += 1;
                if (sl.item == .string) str_cnt += 1;
            }
            if (cpi_cnt == 1 and stk_cnt == 1 and str_cnt == 1) {
                self.craft_output = .{ .item = .brush, .count = 1 };
                return;
            }
        }
        if (non_empty == 4 and g0 == .pottery_sherd and g1 == .pottery_sherd and g2 == .pottery_sherd and g3 == .pottery_sherd) {
            self.craft_output = .{ .item = .decorated_pot, .count = 1 };
            return;
        }

        // Recipe 254 & 255: Packed Ice (4 Ice -> 1 Packed Ice) & Blue Ice (4 Packed Ice -> 1 Blue Ice)
        if (non_empty == 4) {
            if (g0 == .ice and g1 == .ice and g2 == .ice and g3 == .ice) {
                self.craft_output = .{ .item = .packed_ice, .count = 1 };
                return;
            }
            if (g0 == .packed_ice and g1 == .packed_ice and g2 == .packed_ice and g3 == .packed_ice) {
                self.craft_output = .{ .item = .blue_ice, .count = 1 };
                return;
            }
        }

        // Recipe 256: Powder Snow Bucket: 1 Snow Block + 1 Water Bucket -> 1 Powder Snow Bucket
        if (non_empty == 2) {
            var snw_cnt: u8 = 0;
            var wtr_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .snow_block) snw_cnt += 1;
                if (sl.item == .water_bucket) wtr_cnt += 1;
            }
            if (snw_cnt == 1 and wtr_cnt == 1) {
                self.craft_output = .{ .item = .powder_snow_bucket, .count = 1 };
                return;
            }
        }

        // Recipe 257 & 258: Bamboo -> Stick (2 Bamboo vertically -> 1 Stick) & Scaffolding (2..3 Bamboo + 1 String -> 6 Scaffolding)
        if (non_empty == 2) {
            if ((g0 == .bamboo and g2 == .bamboo and g1 == .none and g3 == .none) or
                (g1 == .bamboo and g3 == .bamboo and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .stick, .count = 1 };
                return;
            }
        }
        if (non_empty >= 3 and non_empty <= 4) {
            var bmb_cnt: u8 = 0;
            var str_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .bamboo) bmb_cnt += 1;
                if (sl.item == .string) str_cnt += 1;
            }
            if (bmb_cnt >= 2 and str_cnt == 1 and (bmb_cnt + str_cnt == non_empty)) {
                self.craft_output = .{ .item = .scaffolding, .count = 6 };
                return;
            }
        }

        // Recipe 259, 260 & 261: Bowl (2 diagonal Wood Planks -> 4 Bowls), Beetroot Soup (2..3 Beetroot + 1 Bowl), Mushroom Stew (2 Fungus + 1 Bowl)
        if (non_empty == 2) {
            if ((g0 == .wood_planks and g3 == .wood_planks and g1 == .none and g2 == .none) or
                (g1 == .wood_planks and g2 == .wood_planks and g0 == .none and g3 == .none))
            {
                self.craft_output = .{ .item = .bowl, .count = 4 };
                return;
            }
        }
        if (non_empty >= 3 and non_empty <= 4) {
            var btr_cnt: u8 = 0;
            var fng_cnt: u8 = 0;
            var bwl_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .beetroot) btr_cnt += 1;
                if (sl.item == .crimson_fungus or sl.item == .warped_fungus) fng_cnt += 1;
                if (sl.item == .bowl) bwl_cnt += 1;
            }
            if (btr_cnt >= 2 and bwl_cnt == 1 and (btr_cnt + bwl_cnt == non_empty)) {
                self.craft_output = .{ .item = .beetroot_soup, .count = 1 };
                return;
            }
            if (fng_cnt >= 2 and bwl_cnt == 1 and (fng_cnt + bwl_cnt == non_empty)) {
                self.craft_output = .{ .item = .mushroom_stew, .count = 1 };
                return;
            }
        }

        // Recipe 262, 263 & 264: Swiftness Potion (Sugar + Glass/Wart), Strength Potion (Blaze Powder + Glass/Wart), Leaping Potion (Rabbit Foot + Glass/Wart)
        if (non_empty == 2) {
            var sgr_cnt: u8 = 0;
            var blz_cnt: u8 = 0;
            var rbt_cnt: u8 = 0;
            var vsl_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .sugar) sgr_cnt += 1;
                if (sl.item == .blaze_powder) blz_cnt += 1;
                if (sl.item == .rabbit_foot) rbt_cnt += 1;
                if (sl.item == .glass or sl.item == .nether_wart) vsl_cnt += 1;
            }
            if (sgr_cnt == 1 and vsl_cnt == 1) {
                self.craft_output = .{ .item = .swiftness_potion, .count = 1 };
                return;
            }
            if (blz_cnt == 1 and vsl_cnt == 1) {
                self.craft_output = .{ .item = .strength_potion, .count = 1 };
                return;
            }
            if (rbt_cnt == 1 and vsl_cnt == 1) {
                self.craft_output = .{ .item = .leaping_potion, .count = 1 };
                return;
            }
        }

        // Recipe 265: Cookie: 2 Wheat + 1 Cocoa Beans -> 8 Cookies
        if (non_empty == 3) {
            var wht_cnt: u8 = 0;
            var coc_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wheat) wht_cnt += 1;
                if (sl.item == .cocoa_beans) coc_cnt += 1;
            }
            if (wht_cnt == 2 and coc_cnt == 1) {
                self.craft_output = .{ .item = .cookie, .count = 8 };
                return;
            }
        }

        // Recipe 244 & 245: Dripstone Block (4 Pointed Dripstone <-> 1 Dripstone Block)
        if (non_empty == 4) {
            if (g0 == .pointed_dripstone and g1 == .pointed_dripstone and g2 == .pointed_dripstone and g3 == .pointed_dripstone) {
                self.craft_output = .{ .item = .dripstone_block, .count = 1 };
                return;
            }
        }
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .dripstone_block) {
                    self.craft_output = .{ .item = .pointed_dripstone, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 246: Moss Carpet: 2 Moss Blocks horizontally -> 3 Moss Carpets
        if (non_empty == 2) {
            if ((g0 == .moss_block and g1 == .moss_block and g2 == .none and g3 == .none) or
                (g2 == .moss_block and g3 == .moss_block and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .moss_carpet, .count = 3 };
                return;
            }
        }

        // Recipe 247, 248 & 249: Clay (4 Clay Balls -> 1 Clay), Bricks (4 Brick items -> 1 Brick block), Flower Pot (3 Brick items -> 1 Flower Pot)
        if (non_empty == 4) {
            if (g0 == .clay_ball and g1 == .clay_ball and g2 == .clay_ball and g3 == .clay_ball) {
                self.craft_output = .{ .item = .clay, .count = 1 };
                return;
            }
            if (g0 == .brick_item and g1 == .brick_item and g2 == .brick_item and g3 == .brick_item) {
                self.craft_output = .{ .item = .brick, .count = 1 };
                return;
            }
        }
        if (non_empty == 3) {
            var brk_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .brick_item) brk_cnt += 1;
            }
            if (brk_cnt == 3) {
                self.craft_output = .{ .item = .flower_pot, .count = 1 };
                return;
            }
        }

        // Recipe 250: Totem of Undying: 2 Gold Blocks + 1..2 Emeralds -> 1 Totem of Undying
        if (non_empty >= 3 and non_empty <= 4) {
            var gb_cnt: u8 = 0;
            var em_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .gold_block) gb_cnt += 1;
                if (sl.item == .emerald) em_cnt += 1;
            }
            if (gb_cnt == 2 and em_cnt >= 1 and (gb_cnt + em_cnt == non_empty)) {
                self.craft_output = .{ .item = .totem_of_undying, .count = 1 };
                return;
            }
        }

        // Recipe 251 & 252: Golden Carrot (1 Carrot + 1..3 Gold Nuggets) & Potion of Night Vision (1 Golden Carrot + 1 Glass/Wart)
        if (non_empty >= 2 and non_empty <= 4) {
            var crt_cnt: u8 = 0;
            var gld_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .carrot) crt_cnt += 1;
                if (sl.item == .gold_nugget) gld_cnt += 1;
            }
            if (crt_cnt == 1 and gld_cnt >= 1 and (crt_cnt + gld_cnt == non_empty)) {
                self.craft_output = .{ .item = .golden_carrot, .count = 1 };
                return;
            }
        }
        if (non_empty == 2) {
            var gc_cnt: u8 = 0;
            var vsl_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .golden_carrot) gc_cnt += 1;
                if (sl.item == .glass or sl.item == .nether_wart) vsl_cnt += 1;
            }
            if (gc_cnt == 1 and vsl_cnt == 1) {
                self.craft_output = .{ .item = .night_vision_potion, .count = 1 };
                return;
            }
        }

        // Recipe 253: Potion of Regeneration: 1 Ghast Tear + 1 Glass/Nether Wart -> 1 Potion of Regeneration
        if (non_empty == 2) {
            var gt_cnt: u8 = 0;
            var vsl_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .ghast_tear) gt_cnt += 1;
                if (sl.item == .glass or sl.item == .nether_wart) vsl_cnt += 1;
            }
            if (gt_cnt == 1 and vsl_cnt == 1) {
                self.craft_output = .{ .item = .regeneration_potion, .count = 1 };
                return;
            }
        }

        // Recipe 233: Sculk Sensor: 1 Sculk + 1 Redstone Dust/Observer -> 1 Sculk Sensor
        if (non_empty == 2) {
            var sck_cnt: u8 = 0;
            var red_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .sculk) sck_cnt += 1;
                if (sl.item == .redstone_dust or sl.item == .observer) red_cnt += 1;
            }
            if (sck_cnt == 1 and red_cnt == 1) {
                self.craft_output = .{ .item = .sculk_sensor, .count = 1 };
                return;
            }
        }

        // Recipe 234: Recovery Compass: 1 Compass + 1..3 Echo Shards -> 1 Recovery Compass
        if (non_empty >= 2 and non_empty <= 4) {
            var cmp_cnt: u8 = 0;
            var ech_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .compass) cmp_cnt += 1;
                if (sl.item == .echo_shard) ech_cnt += 1;
            }
            if (cmp_cnt == 1 and ech_cnt >= 1 and (cmp_cnt + ech_cnt == non_empty)) {
                self.craft_output = .{ .item = .recovery_compass, .count = 1 };
                return;
            }
        }

        // Recipe 235 & 236: Polished Deepslate (4 Cobbled Deepslate) & Deepslate Bricks (4 Polished Deepslate)
        if (non_empty == 4) {
            if (g0 == .cobbled_deepslate and g1 == .cobbled_deepslate and g2 == .cobbled_deepslate and g3 == .cobbled_deepslate) {
                self.craft_output = .{ .item = .polished_deepslate, .count = 4 };
                return;
            }
            if (g0 == .polished_deepslate and g1 == .polished_deepslate and g2 == .polished_deepslate and g3 == .polished_deepslate) {
                self.craft_output = .{ .item = .deepslate_bricks, .count = 4 };
                return;
            }
        }

        // Recipe 237 & 238: Block of Iron (4 slots of Iron Ingots with total >= 8, or 3 Iron Ingots + 1 Iron Bars -> 1 Block of Iron) & Unpack (1 Block of Iron -> 4 Iron Ingots)
        if (non_empty == 4) {
            var iron_slots: u8 = 0;
            var bars_slots: u8 = 0;
            var total_iron: u16 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) {
                    iron_slots += 1;
                    total_iron += sl.count;
                } else if (sl.item == .iron_bars) {
                    bars_slots += 1;
                }
            }
            if ((iron_slots == 4 and total_iron >= 8) or (iron_slots == 3 and bars_slots == 1)) {
                self.craft_output = .{ .item = .iron_block, .count = 1 };
                return;
            }
        }
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_block) {
                    self.craft_output = .{ .item = .iron_ingot, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 239: Cake: 1..2 Wheat + 1 Sugar + 1 Apple/Honey Bottle -> 1 Cake
        if (non_empty >= 3 and non_empty <= 4) {
            var wht_cnt: u8 = 0;
            var sgr_cnt: u8 = 0;
            var swt_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wheat) wht_cnt += 1;
                if (sl.item == .sugar) sgr_cnt += 1;
                if (sl.item == .apple or sl.item == .honey_bottle) swt_cnt += 1;
            }
            if (wht_cnt >= 1 and sgr_cnt == 1 and swt_cnt == 1 and (wht_cnt + sgr_cnt + swt_cnt == non_empty)) {
                self.craft_output = .{ .item = .cake, .count = 1 };
                return;
            }
        }

        // Recipe 240: Melon (4 Melon Slices -> 1 Melon Block)
        if (non_empty == 4) {
            if (g0 == .melon_slice and g1 == .melon_slice and g2 == .melon_slice and g3 == .melon_slice) {
                self.craft_output = .{ .item = .melon, .count = 1 };
                return;
            }
        }

        // Recipe 241: Glistering Melon Slice: 1 Melon Slice + 1 Gold Nugget -> 1 Glistering Melon Slice
        if (non_empty == 2) {
            var mln_cnt: u8 = 0;
            var gld_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .melon_slice) mln_cnt += 1;
                if (sl.item == .gold_nugget) gld_cnt += 1;
            }
            if (mln_cnt == 1 and gld_cnt == 1) {
                self.craft_output = .{ .item = .glistering_melon, .count = 1 };
                return;
            }
        }

        // Recipe 242: Potion of Healing: 1 Glistering Melon Slice + 1 Glass/Nether Wart -> 1 Potion of Healing
        if (non_empty == 2) {
            var glm_cnt: u8 = 0;
            var vsl_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .glistering_melon) glm_cnt += 1;
                if (sl.item == .glass or sl.item == .nether_wart) vsl_cnt += 1;
            }
            if (glm_cnt == 1 and vsl_cnt == 1) {
                self.craft_output = .{ .item = .healing_potion, .count = 1 };
                return;
            }
        }

        // Recipe 243: Barrel: 3 Wood Planks + 1 Stick -> 1 Barrel (Wait: 3 Wood Planks + 1 Stick is Composter Recipe 91! Let us make Barrel: 2 Wood Planks + 1 Wooden Trapdoor -> 1 Barrel)
        if (non_empty >= 2 and non_empty <= 3) {
            var plk_cnt: u8 = 0;
            var trp_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wood_planks) plk_cnt += 1;
                if (sl.item == .wooden_trapdoor) trp_cnt += 1;
            }
            if (plk_cnt >= 1 and trp_cnt >= 1 and (plk_cnt + trp_cnt == non_empty)) {
                self.craft_output = .{ .item = .barrel, .count = 1 };
                return;
            }
        }

        // Recipe 221 & 222: Block of Copper (4 Copper Ingots -> 1 Block) & Unpack (1 Block -> 4 Copper Ingots)
        if (non_empty == 4) {
            if (g0 == .copper_ingot and g1 == .copper_ingot and g2 == .copper_ingot and g3 == .copper_ingot) {
                self.craft_output = .{ .item = .copper_block, .count = 1 };
                return;
            }
        }
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .copper_block or sl.item == .waxed_copper_block) {
                    self.craft_output = .{ .item = .copper_ingot, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 223: Waxed Block of Copper: 1 Block of Copper + 1 Honeycomb -> 1 Waxed Block of Copper
        if (non_empty == 2) {
            var cop_cnt: u8 = 0;
            var comb_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .copper_block) cop_cnt += 1;
                if (sl.item == .honeycomb) comb_cnt += 1;
            }
            if (cop_cnt == 1 and comb_cnt == 1) {
                self.craft_output = .{ .item = .waxed_copper_block, .count = 1 };
                return;
            }
        }

        // Recipe 224: Lightning Rod: 2 Copper Ingots vertically -> 1 Lightning Rod
        if (non_empty == 2) {
            if ((g0 == .copper_ingot and g2 == .copper_ingot and g1 == .none and g3 == .none) or
                (g1 == .copper_ingot and g3 == .copper_ingot and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .lightning_rod, .count = 1 };
                return;
            }
        }

        // Recipe 225: Spyglass: 1..2 Copper Ingots + 1 Amethyst Shard -> 1 Spyglass
        if (non_empty >= 2 and non_empty <= 3) {
            var cop_cnt: u8 = 0;
            var ame_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .copper_ingot) cop_cnt += 1;
                if (sl.item == .amethyst_shard) ame_cnt += 1;
            }
            if (cop_cnt >= 1 and ame_cnt == 1 and (cop_cnt + ame_cnt == non_empty)) {
                self.craft_output = .{ .item = .spyglass, .count = 1 };
                return;
            }
        }

        // Recipe 226: Block of Amethyst: 4 Amethyst Shards -> 1 Block of Amethyst
        if (non_empty == 4) {
            if (g0 == .amethyst_shard and g1 == .amethyst_shard and g2 == .amethyst_shard and g3 == .amethyst_shard) {
                self.craft_output = .{ .item = .amethyst_block, .count = 1 };
                return;
            }
        }

        // Recipe 227: Tinted Glass: 2 Amethyst Shards + 1 Glass -> 2 Tinted Glass
        if (non_empty == 3) {
            var ame_cnt: u8 = 0;
            var gls_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .amethyst_shard) ame_cnt += 1;
                if (sl.item == .glass) gls_cnt += 1;
            }
            if (ame_cnt == 2 and gls_cnt == 1) {
                self.craft_output = .{ .item = .tinted_glass, .count = 2 };
                return;
            }
        }

        // Recipe 228: Bell: 1 Gold Nugget/Block + 1..2 Wood Planks + 1 Stone -> 1 Bell
        if (non_empty >= 3 and non_empty <= 4) {
            var gld_cnt: u8 = 0;
            var plk_cnt: u8 = 0;
            var stn_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .gold_nugget or sl.item == .gold_block) gld_cnt += 1;
                if (sl.item == .wood_planks) plk_cnt += 1;
                if (sl.item == .stone or sl.item == .cobblestone) stn_cnt += 1;
            }
            if (gld_cnt == 1 and plk_cnt >= 1 and stn_cnt == 1 and (gld_cnt + plk_cnt + stn_cnt == non_empty)) {
                self.craft_output = .{ .item = .bell, .count = 1 };
                return;
            }
        }

        // Recipe 229 & 230: Sugar Cane -> 1 Sugar (1 item) or 2 Sugar Cane horizontally -> 3 Paper
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .sugar_cane) {
                    self.craft_output = .{ .item = .sugar, .count = 1 };
                    return;
                }
            }
        }
        if (non_empty == 2) {
            if ((g0 == .sugar_cane and g1 == .sugar_cane and g2 == .none and g3 == .none) or
                (g2 == .sugar_cane and g3 == .sugar_cane and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .paper, .count = 3 };
                return;
            }
        }

        // Recipe 231: Jack o'Lantern: 1 Carved Pumpkin/Pumpkin + 1 Torch -> 1 Jack o'Lantern
        if (non_empty == 2) {
            var pmp_cnt: u8 = 0;
            var trc_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .carved_pumpkin or sl.item == .pumpkin) pmp_cnt += 1;
                if (sl.item == .torch) trc_cnt += 1;
            }
            if (pmp_cnt == 1 and trc_cnt == 1) {
                self.craft_output = .{ .item = .jack_o_lantern, .count = 1 };
                return;
            }
        }

        // Recipe 232: Pumpkin Pie: 1 Pumpkin + 1 Sugar + 1 Wheat/Bread -> 1 Pumpkin Pie
        if (non_empty == 3) {
            var pmp_cnt: u8 = 0;
            var sgr_cnt: u8 = 0;
            var wht_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .pumpkin or sl.item == .carved_pumpkin) pmp_cnt += 1;
                if (sl.item == .sugar) sgr_cnt += 1;
                if (sl.item == .wheat or sl.item == .bread) wht_cnt += 1;
            }
            if (pmp_cnt == 1 and sgr_cnt == 1 and wht_cnt == 1) {
                self.craft_output = .{ .item = .pumpkin_pie, .count = 1 };
                return;
            }
        }

        // Recipe 216 & 217: Block of Lapis Lazuli (4 Lapis -> 1 Block) & Unpack (1 Block -> 4 Lapis)
        if (non_empty == 4) {
            if (g0 == .lapis_lazuli and g1 == .lapis_lazuli and g2 == .lapis_lazuli and g3 == .lapis_lazuli) {
                self.craft_output = .{ .item = .lapis_block, .count = 1 };
                return;
            }
        }
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .lapis_block) {
                    self.craft_output = .{ .item = .lapis_lazuli, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 218: Beehive: 2 Honeycomb + 2 Wood Planks (4 items) -> 1 Beehive
        if (non_empty == 4) {
            var comb_cnt: u8 = 0;
            var plank_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .honeycomb) comb_cnt += 1;
                if (sl.item == .wood_planks) plank_cnt += 1;
            }
            if (comb_cnt == 2 and plank_cnt == 2) {
                self.craft_output = .{ .item = .beehive, .count = 1 };
                return;
            }
        }

        // Recipe 219 & 220: Honey Block (4 Honey Bottles -> 1 Honey Block) & Unpack (1 Honey Block + 1..3 Glass -> 4 Honey Bottles)
        if (non_empty == 4) {
            if (g0 == .honey_bottle and g1 == .honey_bottle and g2 == .honey_bottle and g3 == .honey_bottle) {
                self.craft_output = .{ .item = .honey_block, .count = 1 };
                return;
            }
        }
        if (non_empty >= 2 and non_empty <= 4) {
            var hb_cnt: u8 = 0;
            var glass_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .honey_block) hb_cnt += 1;
                if (sl.item == .glass) glass_cnt += 1;
            }
            if (hb_cnt == 1 and glass_cnt >= 1 and (hb_cnt + glass_cnt == non_empty)) {
                self.craft_output = .{ .item = .honey_bottle, .count = 4 };
                return;
            }
        }

        // Recipe 210: Paper: 2 Wheat or 2 Kelp horizontally -> 3 Paper
        if (non_empty == 2) {
            if (((g0 == .wheat and g1 == .wheat) or (g0 == .kelp and g1 == .kelp)) and g2 == .none and g3 == .none) {
                self.craft_output = .{ .item = .paper, .count = 3 };
                return;
            }
            if (((g2 == .wheat and g3 == .wheat) or (g2 == .kelp and g3 == .kelp)) and g0 == .none and g1 == .none) {
                self.craft_output = .{ .item = .paper, .count = 3 };
                return;
            }
        }

        // Recipe 211: Book: 2..3 Paper + 1 Leather -> 1 Book
        if (non_empty >= 3 and non_empty <= 4) {
            var paper_cnt: u8 = 0;
            var leather_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .paper) paper_cnt += 1;
                if (sl.item == .leather) leather_cnt += 1;
            }
            if (paper_cnt >= 2 and leather_cnt == 1 and (paper_cnt + leather_cnt == non_empty)) {
                self.craft_output = .{ .item = .book, .count = 1 };
                return;
            }
        }

        // Recipe 212: Bookshelf: 2 Books + 2 Wood Planks (4 items) -> 1 Bookshelf
        if (non_empty == 4) {
            var book_cnt: u8 = 0;
            var plank_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .book) book_cnt += 1;
                if (sl.item == .wood_planks) plank_cnt += 1;
            }
            if (book_cnt == 2 and plank_cnt == 2) {
                self.craft_output = .{ .item = .bookshelf, .count = 1 };
                return;
            }
        }

        // Recipe 213: Lectern: 1 Bookshelf + 1..3 Wood Planks -> 1 Lectern
        if (non_empty >= 2 and non_empty <= 4) {
            var shelf_cnt: u8 = 0;
            var plank_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .bookshelf) shelf_cnt += 1;
                if (sl.item == .wood_planks) plank_cnt += 1;
            }
            if (shelf_cnt == 1 and plank_cnt >= 1 and (shelf_cnt + plank_cnt == non_empty)) {
                self.craft_output = .{ .item = .lectern, .count = 1 };
                return;
            }
        }

        // Recipe 214 & 215: Block of Emerald (4 Emeralds -> 1 Block of Emerald) & Unpack (1 Block of Emerald -> 4 Emeralds)
        if (non_empty == 4) {
            if (g0 == .emerald and g1 == .emerald and g2 == .emerald and g3 == .emerald) {
                self.craft_output = .{ .item = .emerald_block, .count = 1 };
                return;
            }
        }
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .emerald_block) {
                    self.craft_output = .{ .item = .emerald, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 207: Wheat Seeds: 1 Wheat or 1 Grass -> 2 Wheat Seeds
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .wheat or sl.item == .grass) {
                    self.craft_output = .{ .item = .wheat_seeds, .count = 2 };
                    return;
                }
            }
        }

        // Recipe 208: Bread: 3 Wheat in 2x2 grid -> 1 Bread
        if (non_empty == 3) {
            var wheat_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wheat) wheat_cnt += 1;
            }
            if (wheat_cnt == 3) {
                self.craft_output = .{ .item = .bread, .count = 1 };
                return;
            }
        }

        // Recipe 209: Hay Bale from 4 Wheat (2x2 filled), and 1 Hay Bale -> 4 Wheat
        if (non_empty == 4) {
            if (g0 == .wheat and g1 == .wheat and g2 == .wheat and g3 == .wheat) {
                self.craft_output = .{ .item = .hay_bale, .count = 1 };
                return;
            }
        }
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .hay_bale) {
                    self.craft_output = .{ .item = .wheat, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 201: Wooden Sword: 1 Wood Planks + 1 Stick (diagonal) or 2 bottom Wood Planks + 1 top Stick -> 1 Wooden Sword
        if (non_empty == 2) {
            if ((g0 == .wood_planks and g3 == .stick and g1 == .none and g2 == .none) or
                (g1 == .wood_planks and g2 == .stick and g0 == .none and g3 == .none))
            {
                self.craft_output = .{ .item = .wooden_sword, .count = 1 };
                return;
            }
        }
        if (non_empty == 3) {
            if (g2 == .wood_planks and g3 == .wood_planks and (g0 == .stick or g1 == .stick)) {
                self.craft_output = .{ .item = .wooden_sword, .count = 1 };
                return;
            }
        }

        // Recipe 202: Leather tanning: 4 Rotten Flesh (2x2 filled) -> 1 Leather
        if (non_empty == 4) {
            if (g0 == .rotten_flesh and g1 == .rotten_flesh and g2 == .rotten_flesh and g3 == .rotten_flesh) {
                self.craft_output = .{ .item = .leather, .count = 1 };
                return;
            }
        }

        // Recipe 203: Leather Cap: 2 Leather horizontally -> 1 Leather Cap
        if (non_empty == 2) {
            if ((g0 == .leather and g1 == .leather and g2 == .none and g3 == .none) or
                (g2 == .leather and g3 == .leather and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .leather_helmet, .count = 1 };
                return;
            }
        }

        // Recipe 204: Leather Tunic: 4 Leather (2x2 filled) -> 1 Leather Tunic
        if (non_empty == 4) {
            if (g0 == .leather and g1 == .leather and g2 == .leather and g3 == .leather) {
                self.craft_output = .{ .item = .leather_chestplate, .count = 1 };
                return;
            }
        }

        // Recipe 205: Leather Pants: 3 Leather in 2x2 grid -> 1 Leather Pants
        if (non_empty == 3) {
            var leather_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .leather) leather_cnt += 1;
            }
            if (leather_cnt == 3) {
                self.craft_output = .{ .item = .leather_leggings, .count = 1 };
                return;
            }
        }

        // Recipe 206: Leather Boots: 2 Leather vertically -> 1 Leather Boots
        if (non_empty == 2) {
            if ((g0 == .leather and g2 == .leather and g1 == .none and g3 == .none) or
                (g1 == .leather and g3 == .leather and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .leather_boots, .count = 1 };
                return;
            }
        }

        // Recipe 196: Golden Sword: 1 Gold Nugget + 1 Stick (vertical) -> 1 Golden Sword
        if (non_empty == 2) {
            if ((g0 == .gold_nugget and g2 == .stick and g1 == .none and g3 == .none) or
                (g1 == .gold_nugget and g3 == .stick and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .golden_sword, .count = 1 };
                return;
            }
        }

        // Recipe 197: Golden Pickaxe: top row 2 Gold Nuggets + stick below -> 1 Golden Pickaxe
        if (non_empty == 3) {
            if (g0 == .gold_nugget and g1 == .gold_nugget and (g2 == .stick or g3 == .stick)) {
                self.craft_output = .{ .item = .golden_pickaxe, .count = 1 };
                return;
            }
        }

        // Recipe 198: Golden Axe: 1 Gold Nugget + 1 Wood Log -> 1 Golden Axe
        if (non_empty == 2) {
            if ((g0 == .gold_nugget and g1 == .wood and g2 == .none and g3 == .none) or
                (g2 == .gold_nugget and g3 == .wood and g0 == .none and g1 == .none) or
                (g0 == .wood and g1 == .gold_nugget and g2 == .none and g3 == .none) or
                (g2 == .wood and g3 == .gold_nugget and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .golden_axe, .count = 1 };
                return;
            }
        }

        // Recipe 199: Golden Shovel: 1 Gold Nugget + 1 Wood Planks -> 1 Golden Shovel
        if (non_empty == 2) {
            if ((g0 == .gold_nugget and g2 == .wood_planks and g1 == .none and g3 == .none) or
                (g1 == .gold_nugget and g3 == .wood_planks and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .golden_shovel, .count = 1 };
                return;
            }
        }

        // Recipe 200: Golden Hoe: 1 Gold Nugget + 1 Stick (horizontal) -> 1 Golden Hoe
        if (non_empty == 2) {
            if ((g0 == .gold_nugget and g1 == .stick and g2 == .none and g3 == .none) or
                (g2 == .gold_nugget and g3 == .stick and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .golden_hoe, .count = 1 };
                return;
            }
        }

        // Recipe 191: Stone Sword: 1 Cobblestone + 1 Stick (vertical) or 2 Cobblestone -> 1 Stone Sword
        if (non_empty == 2) {
            if ((g0 == .cobblestone and g2 == .stick and g1 == .none and g3 == .none) or
                (g1 == .cobblestone and g3 == .stick and g0 == .none and g2 == .none) or
                (g0 == .cobblestone and g2 == .cobblestone and g1 == .none and g3 == .none) or
                (g1 == .cobblestone and g3 == .cobblestone and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .stone_sword, .count = 1 };
                return;
            }
        }

        // Recipe 192: Stone Pickaxe: top row 2 Cobblestone + stick below -> 1 Stone Pickaxe
        if (non_empty == 3) {
            if (g0 == .cobblestone and g1 == .cobblestone and (g2 == .stick or g3 == .stick)) {
                self.craft_output = .{ .item = .stone_pickaxe, .count = 1 };
                return;
            }
        }

        // Recipe 193: Stone Axe: 1 Cobblestone + 1 Stick horizontally or 1 Cobblestone + 1 Wood Log -> 1 Stone Axe
        if (non_empty == 2) {
            if ((g0 == .cobblestone and g1 == .wood and g2 == .none and g3 == .none) or
                (g2 == .cobblestone and g3 == .wood and g0 == .none and g1 == .none) or
                (g0 == .wood and g1 == .cobblestone and g2 == .none and g3 == .none) or
                (g2 == .wood and g3 == .cobblestone and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .stone_axe, .count = 1 };
                return;
            }
        }

        // Recipe 194: Stone Shovel: 1 Cobblestone + 1 Stick vertically -> 1 Stone Shovel
        if (non_empty == 2) {
            if ((g0 == .cobblestone and g2 == .wood_planks and g1 == .none and g3 == .none) or
                (g1 == .cobblestone and g3 == .wood_planks and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .stone_shovel, .count = 1 };
                return;
            }
        }

        // Recipe 195: Stone Hoe: 1 Cobblestone + 1 Stick horizontally -> 1 Stone Hoe
        if (non_empty == 2) {
            if ((g0 == .cobblestone and g1 == .stick and g2 == .none and g3 == .none) or
                (g2 == .cobblestone and g3 == .stick and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .stone_hoe, .count = 1 };
                return;
            }
        }

        // Recipe 187: Golden Helmet: 1 Gold Nugget + 1 Sand (or 1 Gold Nugget + 1 Glass) -> 1 Golden Helmet
        if (non_empty == 2) {
            const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget);
            const has_cap = (g0 == .sand or g1 == .sand or g2 == .sand or g3 == .sand or
                             g0 == .glass or g1 == .glass or g2 == .glass or g3 == .glass);
            if (has_gold and has_cap) {
                self.craft_output = .{ .item = .golden_helmet, .count = 1 };
                return;
            }
        }

        // Recipe 188: Golden Chestplate: 1 Block of Gold + 1 Gold Nugget (or 1 Block of Gold + 1 Leather / Wool) -> 1 Golden Chestplate
        if (non_empty == 2) {
            const has_gb = (g0 == .gold_block or g1 == .gold_block or g2 == .gold_block or g3 == .gold_block);
            const has_mat = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget or
                             g0 == .wool or g1 == .wool or g2 == .wool or g3 == .wool);
            if (has_gb and has_mat) {
                self.craft_output = .{ .item = .golden_chestplate, .count = 1 };
                return;
            }
        }

        // Recipe 189: Golden Leggings: 1 Gold Nugget + 1 Chain -> 1 Golden Leggings
        if (non_empty == 2) {
            const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget);
            const has_chain = (g0 == .chain or g1 == .chain or g2 == .chain or g3 == .chain);
            if (has_gold and has_chain) {
                self.craft_output = .{ .item = .golden_leggings, .count = 1 };
                return;
            }
        }

        // Recipe 190: Golden Boots: 1 Gold Nugget + 1 Wool (or 1 Gold Nugget + 1 String) -> 1 Golden Boots
        if (non_empty == 2) {
            const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget);
            const has_soft = (g0 == .wool or g1 == .wool or g2 == .wool or g3 == .wool or
                              g0 == .string or g1 == .string or g2 == .string or g3 == .string);
            if (has_gold and has_soft) {
                self.craft_output = .{ .item = .golden_boots, .count = 1 };
                return;
            }
        }

        // Recipe 183: Iron Helmet: 1 Iron Ingot + 1 Sand (or 1 Iron Ingot + 1 Dirt) -> 1 Iron Helmet
        if (non_empty == 2) {
            const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            const has_cap = (g0 == .sand or g1 == .sand or g2 == .sand or g3 == .sand or
                             g0 == .dirt or g1 == .dirt or g2 == .dirt or g3 == .dirt);
            if (has_iron and has_cap) {
                self.craft_output = .{ .item = .iron_helmet, .count = 1 };
                return;
            }
        }

        // Recipe 184: Iron Chestplate: 1 Iron Ingot + 1 Iron Bars (or 1 Iron Ingot + 1 Brick) -> 1 Iron Chestplate
        if (non_empty == 2) {
            const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            const has_plate = (g0 == .iron_bars or g1 == .iron_bars or g2 == .iron_bars or g3 == .iron_bars or
                               g0 == .brick or g1 == .brick or g2 == .brick or g3 == .brick);
            if (has_iron and has_plate) {
                self.craft_output = .{ .item = .iron_chestplate, .count = 1 };
                return;
            }
        }

        // Recipe 185: Iron Leggings: 1 Iron Ingot + 1 Chain -> 1 Iron Leggings
        if (non_empty == 2) {
            const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            const has_chain = (g0 == .chain or g1 == .chain or g2 == .chain or g3 == .chain);
            if (has_iron and has_chain) {
                self.craft_output = .{ .item = .iron_leggings, .count = 1 };
                return;
            }
        }

        // Recipe 186: Iron Boots: 1 Iron Ingot + 1 Wool (or 1 Iron Ingot + 1 String) -> 1 Iron Boots
        if (non_empty == 2) {
            const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            const has_soft = (g0 == .wool or g1 == .wool or g2 == .wool or g3 == .wool or
                              g0 == .string or g1 == .string or g2 == .string or g3 == .string);
            if (has_iron and has_soft) {
                self.craft_output = .{ .item = .iron_boots, .count = 1 };
                return;
            }
        }

        // Recipe 182: Shears: 2 Iron Ingots -> 1 Shears
        if (non_empty == 2) {
            if ((g0 == .iron_ingot and g3 == .iron_ingot and g1 == .none and g2 == .none) or
                (g1 == .iron_ingot and g2 == .iron_ingot and g0 == .none and g3 == .none) or
                (g0 == .iron_ingot and g1 == .iron_ingot and g2 == .none and g3 == .none) or
                (g2 == .iron_ingot and g3 == .iron_ingot and g0 == .none and g1 == .none) or
                (g0 == .iron_ingot and g2 == .iron_ingot and g1 == .none and g3 == .none) or
                (g1 == .iron_ingot and g3 == .iron_ingot and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .shears, .count = 1 };
                return;
            }
        }

        // Recipe 178: Wooden Hoe: 1 Wood Planks + 1 Stick horizontally -> 1 Wooden Hoe
        if (non_empty == 2) {
            if ((g0 == .wood_planks and g1 == .stick and g2 == .none and g3 == .none) or
                (g2 == .wood_planks and g3 == .stick and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .wooden_hoe, .count = 1 };
                return;
            }
        }

        // Recipe 179: Iron Hoe: 1 Iron Ingot + 1 Stick horizontally -> 1 Iron Hoe
        if (non_empty == 2) {
            if ((g0 == .iron_ingot and g1 == .stick and g2 == .none and g3 == .none) or
                (g2 == .iron_ingot and g3 == .stick and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .iron_hoe, .count = 1 };
                return;
            }
        }

        // Recipe 180: Diamond Hoe: 1 Diamond + 1 Stick horizontally or 1 Iron Hoe + 1 Diamond -> 1 Diamond Hoe
        if (non_empty == 2) {
            if ((g0 == .diamond and g1 == .stick and g2 == .none and g3 == .none) or
                (g2 == .diamond and g3 == .stick and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .diamond_hoe, .count = 1 };
                return;
            }
            const has_iron_hoe = (g0 == .iron_hoe or g1 == .iron_hoe or g2 == .iron_hoe or g3 == .iron_hoe);
            const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
            if (has_iron_hoe and has_dia) {
                self.craft_output = .{ .item = .diamond_hoe, .count = 1 };
                return;
            }
        }

        // Recipe 181: Netherite Hoe: 1 Netherite Ingot + 1 Diamond Hoe / Iron Hoe -> 1 Netherite Hoe
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_base_hoe = (g0 == .diamond_hoe or g1 == .diamond_hoe or g2 == .diamond_hoe or g3 == .diamond_hoe or
                                  g0 == .iron_hoe or g1 == .iron_hoe or g2 == .iron_hoe or g3 == .iron_hoe);
            if (has_ni and has_base_hoe) {
                self.craft_output = .{ .item = .netherite_hoe, .count = 1 };
                return;
            }
        }

        // Recipe 174: Wooden Shovel: 1 Wood Planks + 1 Stick (vertical) -> 1 Wooden Shovel
        if (non_empty == 2) {
            if ((g0 == .wood_planks and g2 == .stick and g1 == .none and g3 == .none) or
                (g1 == .wood_planks and g3 == .stick and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .wooden_shovel, .count = 1 };
                return;
            }
        }

        // Recipe 175: Iron Shovel: 1 Iron Ingot + 1 Stick (vertical) -> 1 Iron Shovel
        if (non_empty == 2) {
            if ((g0 == .iron_ingot and g2 == .stick and g1 == .none and g3 == .none) or
                (g1 == .iron_ingot and g3 == .stick and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .iron_shovel, .count = 1 };
                return;
            }
        }

        // Recipe 176: Diamond Shovel: 1 Diamond + 1 Stick (vertical) or 1 Iron Shovel + 1 Diamond -> 1 Diamond Shovel
        if (non_empty == 2) {
            if ((g0 == .diamond and g2 == .stick and g1 == .none and g3 == .none) or
                (g1 == .diamond and g3 == .stick and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .diamond_shovel, .count = 1 };
                return;
            }
            const has_iron_shov = (g0 == .iron_shovel or g1 == .iron_shovel or g2 == .iron_shovel or g3 == .iron_shovel);
            const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
            if (has_iron_shov and has_dia) {
                self.craft_output = .{ .item = .diamond_shovel, .count = 1 };
                return;
            }
        }

        // Recipe 177: Netherite Shovel: 1 Netherite Ingot + 1 Diamond Shovel / Iron Shovel -> 1 Netherite Shovel
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_base_shov = (g0 == .diamond_shovel or g1 == .diamond_shovel or g2 == .diamond_shovel or g3 == .diamond_shovel or
                                   g0 == .iron_shovel or g1 == .iron_shovel or g2 == .iron_shovel or g3 == .iron_shovel);
            if (has_ni and has_base_shov) {
                self.craft_output = .{ .item = .netherite_shovel, .count = 1 };
                return;
            }
        }

        // Recipe 170: Wooden Axe: 1 Wood Log + 1 Stick -> 1 Wooden Axe
        if (non_empty == 2) {
            const has_log = (g0 == .wood or g1 == .wood or g2 == .wood or g3 == .wood);
            const has_stk = (g0 == .stick or g1 == .stick or g2 == .stick or g3 == .stick);
            if (has_log and has_stk) {
                self.craft_output = .{ .item = .wooden_axe, .count = 1 };
                return;
            }
        }

        // Recipe 171: Iron Axe: 1 Iron Ingot + 1 Wood Log/Plank -> 1 Iron Axe
        if (non_empty == 2) {
            const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            const has_wood_mat = (g0 == .wood or g1 == .wood or g2 == .wood or g3 == .wood or
                                  g0 == .wood_planks or g1 == .wood_planks or g2 == .wood_planks or g3 == .wood_planks);
            if (has_iron and has_wood_mat) {
                self.craft_output = .{ .item = .iron_axe, .count = 1 };
                return;
            }
        }

        // Recipe 172: Diamond Axe: 1 Diamond + 1 Wood Log/Plank (or 1 Iron Axe + 1 Diamond) -> 1 Diamond Axe
        if (non_empty == 2) {
            const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
            const has_wood_mat = (g0 == .wood or g1 == .wood or g2 == .wood or g3 == .wood or
                                  g0 == .wood_planks or g1 == .wood_planks or g2 == .wood_planks or g3 == .wood_planks);
            const has_iron_axe = (g0 == .iron_axe or g1 == .iron_axe or g2 == .iron_axe or g3 == .iron_axe);
            if (has_dia and (has_wood_mat or has_iron_axe)) {
                self.craft_output = .{ .item = .diamond_axe, .count = 1 };
                return;
            }
        }

        // Recipe 173: Netherite Axe: 1 Netherite Ingot + 1 Diamond Axe / Iron Axe -> 1 Netherite Axe
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_base_axe = (g0 == .diamond_axe or g1 == .diamond_axe or g2 == .diamond_axe or g3 == .diamond_axe or
                                  g0 == .iron_axe or g1 == .iron_axe or g2 == .iron_axe or g3 == .iron_axe);
            if (has_ni and has_base_axe) {
                self.craft_output = .{ .item = .netherite_axe, .count = 1 };
                return;
            }
        }

        // Recipe 168: Flint: 2 Gravel/Sand -> 1 Flint
        if (non_empty == 2) {
            
            var sand_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .sand) sand_c += 1;
            }
            if (sand_c == 2) {
                self.craft_output = .{ .item = .flint, .count = 1 };
                return;
            }
        }

        // Recipe 169: Flint and Steel: 1 Iron Ingot + 1 Flint (non_empty == 2) -> 1 Flint and Steel
        if (non_empty == 2) {
            const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            const has_flint = (g0 == .flint or g1 == .flint or g2 == .flint or g3 == .flint);
            if (has_iron and has_flint) {
                self.craft_output = .{ .item = .flint_and_steel, .count = 1 };
                return;
            }
        }

        // Recipe 164: Diamond Helmet: 1 Diamond + 1 Glass (or 1 Diamond + 1 Coal) -> 1 Diamond Helmet
        if (non_empty == 2) {
            const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
            const has_gem = (g0 == .glass or g1 == .glass or g2 == .glass or g3 == .glass or
                             g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal or
                             g0 == .iron_helmet or g1 == .iron_helmet or g2 == .iron_helmet or g3 == .iron_helmet);
            if (has_dia and has_gem) {
                self.craft_output = .{ .item = .diamond_helmet, .count = 1 };
                return;
            }
        }

        // Recipe 165: Diamond Chestplate: 1 Diamond Block + 1 Diamond/Iron Ingot or 1 Iron Chestplate + 1 Diamond -> 1 Diamond Chestplate
        if (non_empty == 2) {
            const has_db = (g0 == .diamond_block or g1 == .diamond_block or g2 == .diamond_block or g3 == .diamond_block);
            const has_mat = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond or
                             g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            if (has_db and has_mat) {
                self.craft_output = .{ .item = .diamond_chestplate, .count = 1 };
                return;
            }
            const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
            const has_ic = (g0 == .iron_chestplate or g1 == .iron_chestplate or g2 == .iron_chestplate or g3 == .iron_chestplate);
            if (has_dia and has_ic) {
                self.craft_output = .{ .item = .diamond_chestplate, .count = 1 };
                return;
            }
        }

        // Recipe 166: Diamond Leggings: 1 Diamond + 1 Obsidian (or 1 Diamond + 1 Chain) -> 1 Diamond Leggings
        if (non_empty == 2) {
            const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
            const has_tough = (g0 == .obsidian or g1 == .obsidian or g2 == .obsidian or g3 == .obsidian or
                               g0 == .chain or g1 == .chain or g2 == .chain or g3 == .chain or
                               g0 == .iron_leggings or g1 == .iron_leggings or g2 == .iron_leggings or g3 == .iron_leggings);
            if (has_dia and has_tough) {
                self.craft_output = .{ .item = .diamond_leggings, .count = 1 };
                return;
            }
        }

        // Recipe 167: Diamond Boots: 2 Diamonds horizontally or 1 Iron Boots + 1 Diamond -> 1 Diamond Boots
        if (non_empty == 2) {
            if ((g0 == .diamond and g1 == .diamond and g2 == .none and g3 == .none) or
                (g2 == .diamond and g3 == .diamond and g0 == .none and g1 == .none))
            {
                self.craft_output = .{ .item = .diamond_boots, .count = 1 };
                return;
            }
            const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
            const has_ib = (g0 == .iron_boots or g1 == .iron_boots or g2 == .iron_boots or g3 == .iron_boots);
            if (has_dia and has_ib) {
                self.craft_output = .{ .item = .diamond_boots, .count = 1 };
                return;
            }
        }

        // Recipe 162: Diamond Sword: 2 Diamonds vertically or 1 Iron Sword + 1 Diamond -> 1 Diamond Sword
        if (non_empty == 2) {
            if ((g0 == .diamond and g2 == .diamond and g1 == .none and g3 == .none) or
                (g1 == .diamond and g3 == .diamond and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .diamond_sword, .count = 1 };
                return;
            }
            const has_iron_sword = (g0 == .iron_sword or g1 == .iron_sword or g2 == .iron_sword or g3 == .iron_sword);
            const has_diamond = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
            if (has_iron_sword and has_diamond) {
                self.craft_output = .{ .item = .diamond_sword, .count = 1 };
                return;
            }
        }

        // Recipe 163: Diamond Pickaxe: 2 Diamonds top row + 1 Stick below, or 1 Iron Pickaxe + 1 Diamond -> 1 Diamond Pickaxe
        if (non_empty == 3) {
            if (g0 == .diamond and g1 == .diamond and (g2 == .stick or g3 == .stick)) {
                self.craft_output = .{ .item = .diamond_pickaxe, .count = 1 };
                return;
            }
        }
        if (non_empty == 2) {
            const has_iron_pick = (g0 == .iron_pickaxe or g1 == .iron_pickaxe or g2 == .iron_pickaxe or g3 == .iron_pickaxe);
            const has_diamond = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
            if (has_iron_pick and has_diamond) {
                self.craft_output = .{ .item = .diamond_pickaxe, .count = 1 };
                return;
            }
        }

        // Recipe 160: Block of Diamond: 4 Diamonds (2x2 filled) -> 1 Block of Diamond
        if (non_empty == 4) {
            var dia_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .diamond) dia_c += 1;
            }
            if (dia_c == 4) {
                self.craft_output = .{ .item = .diamond_block, .count = 1 };
                return;
            }
        }

        // Recipe 161: Diamond Unpacking: 1 Block of Diamond -> 4 Diamonds
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .diamond_block and sl.count >= 1) {
                    self.craft_output = .{ .item = .diamond, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 158: Block of Gold: 4 Gold Nuggets (2x2 filled) -> 1 Block of Gold
        if (non_empty == 4) {
            var gold_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .gold_nugget) gold_c += 1;
            }
            if (gold_c == 4) {
                self.craft_output = .{ .item = .gold_block, .count = 1 };
                return;
            }
        }

        // Recipe 159: Gold Nugget Unpacking: 1 Block of Gold -> 4 Gold Nuggets
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .gold_block and sl.count >= 1) {
                    self.craft_output = .{ .item = .gold_nugget, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 156: Block of Redstone: 4 Redstone Dust (2x2 filled) -> 1 Block of Redstone
        if (non_empty == 4) {
            var red_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .redstone_dust) red_c += 1;
            }
            if (red_c == 4) {
                self.craft_output = .{ .item = .redstone_block, .count = 1 };
                return;
            }
        }

        // Recipe 157: Redstone Dust Unpacking: 1 Block of Redstone -> 4 Redstone Dust
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .redstone_block and sl.count >= 1) {
                    self.craft_output = .{ .item = .redstone_dust, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 154: Wooden Trapdoor: 1 Wooden Door -> 2 Wooden Trapdoors
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .wooden_door and sl.count >= 1) {
                    self.craft_output = .{ .item = .wooden_trapdoor, .count = 2 };
                    return;
                }
            }
        }

        // Recipe 155: Iron Trapdoor: 1 Iron Door -> 2 Iron Trapdoors
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_door and sl.count >= 1) {
                    self.craft_output = .{ .item = .iron_trapdoor, .count = 2 };
                    return;
                }
            }
        }

        // Recipe 153: Observer: 2 Cobblestone + 1 Redstone Dust + 1 Nether Quartz -> 1 Observer
        if (non_empty >= 3) {
            var cobble_c: usize = 0;
            var red_c: usize = 0;
            var quartz_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .cobblestone or sl.item == .stone) cobble_c += sl.count;
                if (sl.item == .redstone_dust) red_c += sl.count;
                if (sl.item == .nether_quartz) quartz_c += sl.count;
            }
            if (cobble_c >= 2 and red_c >= 1 and quartz_c >= 1) {
                self.craft_output = .{ .item = .observer, .count = 1 };
                return;
            }
        }

        // Recipe 151: Piston: 1 Wood Planks + 1 Cobblestone + 1 Iron Ingot + 1 Redstone Dust -> 1 Piston
        if (non_empty == 4) {
            var plank_c: usize = 0;
            var cobble_c: usize = 0;
            var iron_c: usize = 0;
            var red_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wood_planks) plank_c += sl.count;
                if (sl.item == .cobblestone or sl.item == .stone) cobble_c += sl.count;
                if (sl.item == .iron_ingot) iron_c += sl.count;
                if (sl.item == .redstone_dust) red_c += sl.count;
            }
            if (plank_c >= 1 and cobble_c >= 1 and iron_c >= 1 and red_c >= 1) {
                self.craft_output = .{ .item = .piston, .count = 1 };
                return;
            }
        }

        // Recipe 152: Sticky Piston: 1 Piston + 1 Slimeball -> 1 Sticky Piston
        if (non_empty == 2) {
            var pist_c: usize = 0;
            var slime_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .piston) pist_c += sl.count;
                if (sl.item == .slimeball) slime_c += sl.count;
            }
            if (pist_c == 1 and slime_c == 1) {
                self.craft_output = .{ .item = .sticky_piston, .count = 1 };
                return;
            }
        }

        // Recipe 149: Slime Block: 4 Slimeballs -> 1 Slime Block
        if (non_empty == 4) {
            var slime_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .slimeball) slime_c += sl.count;
            }
            if (slime_c == 4) {
                self.craft_output = .{ .item = .slime_block, .count = 1 };
                return;
            }
        }

        // Recipe 150: Slimeballs: 1 Slime Block -> 4 Slimeballs
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .slime_block) {
                    self.craft_output = .{ .item = .slimeball, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 148: Redstone Comparator: 1 Nether Quartz + 1 Redstone Torch (or 2) + 1 Stone (2x2 grid) -> 1 Redstone Comparator
        if (non_empty >= 3) {
            var quartz_c: usize = 0;
            var torch_c: usize = 0;
            var stone_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .nether_quartz) quartz_c += sl.count;
                if (sl.item == .redstone_torch or sl.item == .torch) torch_c += sl.count;
                if (sl.item == .stone or sl.item == .cobblestone) stone_c += sl.count;
            }
            if (quartz_c >= 1 and torch_c >= 1 and stone_c >= 1) {
                self.craft_output = .{ .item = .redstone_comparator, .count = 1 };
                return;
            }
        }

        // Recipe 138: Water Breathing Potion (Pufferfish Brewing): 1 Pufferfish + 1 Glass vial (or nether wart / water) -> 1 Water Breathing Potion
        if (non_empty == 2) {
            var puff_c: usize = 0;
            var liquid_c: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .pufferfish) puff_c += 1;
                if (sl.item == .glass or sl.item == .water or sl.item == .nether_wart) liquid_c += 1;
            }
            if (puff_c == 1 and liquid_c == 1) {
                self.craft_output = .{ .item = .water_breathing_potion, .count = 1 };
                return;
            }
        }

        // Recipe 126: Water Breathing Potion: 1 Scute + 1 Glass vial (or water bucket / nether wart) -> 1 Water Breathing Potion
        if (non_empty == 2) {
            var scute_c: usize = 0;
            var liquid_catalyst: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .scute) scute_c += 1;
                if (sl.item == .glass or sl.item == .water or sl.item == .nether_wart) liquid_catalyst += 1;
            }
            if (scute_c == 1 and liquid_catalyst == 1) {
                self.craft_output = .{ .item = .water_breathing_potion, .count = 1 };
                return;
            }
        }

        // Recipe 122: Dragon's Breath Alchemy: 1 Glass (vial) + 1 Dragon Head / Chorus Fruit -> 1 Dragon's Breath
        if (non_empty == 2) {
            var glass_cnt: usize = 0;
            var dragon_catalyst: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .glass) glass_cnt += 1;
                if (sl.item == .dragon_head or sl.item == .dragon_egg or sl.item == .chorus_fruit) dragon_catalyst += 1;
            }
            if (glass_cnt == 1 and dragon_catalyst == 1) {
                self.craft_output = .{ .item = .dragons_breath, .count = 1 };
                return;
            }
        }

        // Recipe 123: Lingering Poison Potion: 1 Dragon's Breath + 1 Poison Potion -> 1 Lingering Poison Potion
        if (non_empty == 2) {
            var breath_cnt: usize = 0;
            var poison_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .dragons_breath) breath_cnt += 1;
                if (sl.item == .poison_potion) poison_cnt += 1;
            }
            if (breath_cnt == 1 and poison_cnt == 1) {
                self.craft_output = .{ .item = .lingering_poison_potion, .count = 1 };
                return;
            }
        }

        // Recipe 124: Lingering Weakness Potion: 1 Dragon's Breath + 1 Weakness Potion -> 1 Lingering Weakness Potion
        if (non_empty == 2) {
            var breath_cnt: usize = 0;
            var weak_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .dragons_breath) breath_cnt += 1;
                if (sl.item == .weakness_potion) weak_cnt += 1;
            }
            if (breath_cnt == 1 and weak_cnt == 1) {
                self.craft_output = .{ .item = .lingering_weakness_potion, .count = 1 };
                return;
            }
        }

        // Recipe 121: End Gateway: 1 Dragon Head + 1 End Crystal -> 1 End Gateway
        if (non_empty == 2) {
            var head_cnt: usize = 0;
            var crys_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .dragon_head) head_cnt += 1;
                if (sl.item == .end_crystal) crys_cnt += 1;
            }
            if (head_cnt == 1 and crys_cnt == 1) {
                self.craft_output = .{ .item = .end_gateway, .count = 1 };
                return;
            }
        }

        // Recipe 120: Dragon Head: 1 Dragon Egg + 1 Wither Skull -> 1 Dragon Head
        if (non_empty == 2) {
            var egg_cnt: usize = 0;
            var skull_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .dragon_egg) egg_cnt += 1;
                if (sl.item == .wither_skull) skull_cnt += 1;
            }
            if (egg_cnt == 1 and skull_cnt == 1) {
                self.craft_output = .{ .item = .dragon_head, .count = 1 };
                return;
            }
        }

        // Recipe 119: Elytra: 2 Shulker Shells + 2 Purpur Blocks -> 1 Elytra
        if (non_empty == 4) {
            var shell_cnt: usize = 0;
            var purp_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .shulker_shell) shell_cnt += 1;
                if (sl.item == .purpur_block) purp_cnt += 1;
            }
            if (shell_cnt == 2 and purp_cnt == 2) {
                self.craft_output = .{ .item = .elytra, .count = 1 };
                return;
            }
        }

        // Recipe 118: Shulker Box: 1 Chest + 2 Shulker Shells -> 1 Shulker Box
        if (non_empty == 3) {
            var chest_cnt: usize = 0;
            var shell_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .chest) chest_cnt += 1;
                if (sl.item == .shulker_shell) shell_cnt += 1;
            }
            if (chest_cnt == 1 and shell_cnt == 2) {
                self.craft_output = .{ .item = .shulker_box, .count = 1 };
                return;
            }
        }

        // Recipe 115: Purpur Block from Popped Chorus Fruit: 4 Popped Chorus Fruit -> 4 Purpur Blocks
        if (non_empty == 4) {
            var pop_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .popped_chorus_fruit) pop_cnt += 1;
            }
            if (pop_cnt == 4) {
                self.craft_output = .{ .item = .purpur_block, .count = 4 };
                return;
            }
        }

        // Recipe 116: End Rod with Chorus Fruit: 1 Blaze Rod + 1 Popped Chorus Fruit / Chorus Fruit -> 4 End Rods
        if (non_empty == 2) {
            const has_rod = (g0 == .blaze_rod or g1 == .blaze_rod or g2 == .blaze_rod or g3 == .blaze_rod);
            const has_fruit = (g0 == .chorus_fruit or g1 == .chorus_fruit or g2 == .chorus_fruit or g3 == .chorus_fruit or
                g0 == .popped_chorus_fruit or g1 == .popped_chorus_fruit or g2 == .popped_chorus_fruit or g3 == .popped_chorus_fruit);
            if (has_rod and has_fruit) {
                self.craft_output = .{ .item = .end_rod, .count = 4 };
                return;
            }
        }

        // Recipe 117: 1 Chorus Fruit + 1 Coal -> 1 Popped Chorus Fruit (quick field roast)
        if (non_empty == 2) {
            const has_cf = (g0 == .chorus_fruit or g1 == .chorus_fruit or g2 == .chorus_fruit or g3 == .chorus_fruit);
            const has_fuel = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal);
            if (has_cf and has_fuel) {
                self.craft_output = .{ .item = .popped_chorus_fruit, .count = 1 };
                return;
            }
        }

        // Recipe 112: Purpur Block: 4 End Stone -> 4 Purpur Blocks
        if (non_empty == 4) {
            var es_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .end_stone) es_cnt += 1;
            }
            if (es_cnt == 4) {
                self.craft_output = .{ .item = .purpur_block, .count = 4 };
                return;
            }
        }

        // Recipe 113: Purpur Pillar: 2 Purpur Blocks -> 2 Purpur Pillars
        if (non_empty == 2) {
            const has_two_pb = ((g0 == .purpur_block and g2 == .purpur_block) or
                (g1 == .purpur_block and g3 == .purpur_block) or
                (g0 == .purpur_block and g1 == .purpur_block) or
                (g2 == .purpur_block and g3 == .purpur_block));
            if (has_two_pb) {
                self.craft_output = .{ .item = .purpur_pillar, .count = 2 };
                return;
            }
        }

        // Recipe 114: End Rod: 1 Blaze Rod + 1 Ender Pearl/Eye of Ender -> 4 End Rods
        if (non_empty == 2) {
            const has_rod = (g0 == .blaze_rod or g1 == .blaze_rod or g2 == .blaze_rod or g3 == .blaze_rod);
            const has_pearl = (g0 == .ender_pearl or g1 == .ender_pearl or g2 == .ender_pearl or g3 == .ender_pearl or
                g0 == .eye_of_ender or g1 == .eye_of_ender or g2 == .eye_of_ender or g3 == .eye_of_ender);
            if (has_rod and has_pearl) {
                self.craft_output = .{ .item = .end_rod, .count = 4 };
                return;
            }
        }

        // Recipe 111: End Crystal: 2 Glass + 1 Eye of Ender + 1 Blaze Powder/Nether Star/Ghast Tear -> 1 End Crystal
        if (non_empty == 4) {
            var glass_cnt: usize = 0;
            var eye_cnt: usize = 0;
            var catalyst_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .glass) glass_cnt += 1;
                if (sl.item == .eye_of_ender) eye_cnt += 1;
                if (sl.item == .blaze_powder or sl.item == .nether_star or sl.item == .magma_cream) catalyst_cnt += 1;
            }
            if (glass_cnt == 2 and eye_cnt == 1 and catalyst_cnt == 1) {
                self.craft_output = .{ .item = .end_crystal, .count = 1 };
                return;
            }
        }

        // Recipe 109: End Stone: 1 Cobblestone + 1 Sandstone -> 2 End Stone
        if (non_empty == 2) {
            const has_cobb = (g0 == .cobblestone or g1 == .cobblestone or g2 == .cobblestone or g3 == .cobblestone);
            const has_sandstone = (g0 == .sandstone or g1 == .sandstone or g2 == .sandstone or g3 == .sandstone);
            if (has_cobb and has_sandstone) {
                self.craft_output = .{ .item = .end_stone, .count = 2 };
                return;
            }
        }

        // Recipe 110: End Portal Frame: 3 End Stone + 1 Ender Pearl/Eye of Ender -> 1 End Portal Frame
        if (non_empty == 4) {
            var es_cnt: usize = 0;
            var relic_cnt: usize = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .end_stone) es_cnt += 1;
                if (sl.item == .ender_pearl or sl.item == .eye_of_ender) relic_cnt += 1;
            }
            if (es_cnt == 3 and relic_cnt == 1) {
                self.craft_output = .{ .item = .end_portal_frame, .count = 1 };
                return;
            }
        }

        // Recipe 108: Eye of Ender: 1 Ender Pearl + 1 Blaze Powder -> 1 Eye of Ender
        if (non_empty == 2) {
            const has_pearl = (g0 == .ender_pearl or g1 == .ender_pearl or g2 == .ender_pearl or g3 == .ender_pearl);
            const has_powder = (g0 == .blaze_powder or g1 == .blaze_powder or g2 == .blaze_powder or g3 == .blaze_powder);
            if (has_pearl and has_powder) {
                self.craft_output = .{ .item = .eye_of_ender, .count = 1 };
                return;
            }
        }

        // Recipe 107: TNT: 2 Sand + 2 Gunpowder (checkerboard) or 1 Sand + 1 Gunpowder -> 1 TNT
        if (non_empty == 4) {
            if ((g0 == .sand and g3 == .sand and g1 == .gunpowder and g2 == .gunpowder) or
                (g1 == .sand and g2 == .sand and g0 == .gunpowder and g3 == .gunpowder))
            {
                self.craft_output = .{ .item = .tnt, .count = 1 };
                return;
            }
        }
        if (non_empty == 2) {
            const has_sand = (g0 == .sand or g1 == .sand or g2 == .sand or g3 == .sand);
            const has_gunpowder = (g0 == .gunpowder or g1 == .gunpowder or g2 == .gunpowder or g3 == .gunpowder);
            if (has_sand and has_gunpowder) {
                self.craft_output = .{ .item = .tnt, .count = 1 };
                return;
            }
        }

        // Recipe 106: Bone Meal: 1 Bone -> 3 Bone Meal
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .bone) {
                    self.craft_output = .{ .item = .bone_meal, .count = 3 };
                    return;
                }
            }
        }

        // Recipe 104: Fermented Spider Eye: 1 Spider Eye + 1 Fungus (Crimson/Warped/Nether Wart/Apple) -> 1 Fermented Spider Eye
        if (non_empty == 2) {
            const has_eye = (g0 == .spider_eye or g1 == .spider_eye or g2 == .spider_eye or g3 == .spider_eye);
            const has_sugar_catalyst = (g0 == .crimson_fungus or g1 == .crimson_fungus or g2 == .crimson_fungus or g3 == .crimson_fungus or
                g0 == .warped_fungus or g1 == .warped_fungus or g2 == .warped_fungus or g3 == .warped_fungus or
                g0 == .apple or g1 == .apple or g2 == .apple or g3 == .apple);
            if (has_eye and has_sugar_catalyst) {
                self.craft_output = .{ .item = .fermented_spider_eye, .count = 1 };
                return;
            }
        }

        // Recipe 105: Potion of Weakness: 1 Fermented Spider Eye + 1 Glass vial (or 1 Fermented Spider Eye + 1 Nether Wart) -> 1 Weakness Potion
        if (non_empty == 2) {
            const has_ferm = (g0 == .fermented_spider_eye or g1 == .fermented_spider_eye or g2 == .fermented_spider_eye or g3 == .fermented_spider_eye);
            const has_glass = (g0 == .glass or g1 == .glass or g2 == .glass or g3 == .glass);
            const has_wart = (g0 == .nether_wart or g1 == .nether_wart or g2 == .nether_wart or g3 == .nether_wart);
            if (has_ferm and (has_glass or has_wart)) {
                self.craft_output = .{ .item = .weakness_potion, .count = 1 };
                return;
            }
        }

        // Recipe 103: Potion of Poison: 1 Spider Eye + 1 Glass vial (or 1 Spider Eye + 1 Nether Wart) -> 1 Poison Potion
        if (non_empty == 2) {
            const has_eye = (g0 == .spider_eye or g1 == .spider_eye or g2 == .spider_eye or g3 == .spider_eye);
            const has_glass = (g0 == .glass or g1 == .glass or g2 == .glass or g3 == .glass);
            const has_wart = (g0 == .nether_wart or g1 == .nether_wart or g2 == .nether_wart or g3 == .nether_wart);
            if (has_eye and (has_glass or has_wart)) {
                self.craft_output = .{ .item = .poison_potion, .count = 1 };
                return;
            }
        }

        // Recipe 102: Cobweb: 4 Strings -> 1 Cobweb
        if (non_empty == 4) {
            var string_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .string) string_count += 1;
            }
            if (string_count == 4) {
                self.craft_output = .{ .item = .cobweb, .count = 1 };
                return;
            }
        }

        // Recipe 101: String: 1 Wool (or 1 Weeping Vines or 1 Twisting Vines) -> 4 Strings
        if (non_empty == 1) {
            for (self.craft_grid) |sl| {
                if (sl.item == .wool or sl.item == .weeping_vines or sl.item == .twisting_vines) {
                    self.craft_output = .{ .item = .string, .count = 4 };
                    return;
                }
            }
        }

        // Recipe 100: Tripwire Hook: 1 Iron Ingot + 1 Stick + 1 Wood Planks -> 2 Tripwire Hooks
        if (non_empty == 3) {
            var iron_count: u8 = 0;
            var stick_count: u8 = 0;
            var plank_count: u8 = 0;
            var other_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) iron_count += 1
                else if (sl.item == .stick) stick_count += 1
                else if (sl.item == .wood_planks) plank_count += 1
                else if (!sl.isEmpty()) other_count += 1;
            }
            if (iron_count == 1 and stick_count == 1 and plank_count == 1 and other_count == 0) {
                self.craft_output = .{ .item = .tripwire_hook, .count = 2 };
                return;
            }
        }

        // Recipe 99: Iron Bars: 2 Iron Ingots + 1 Cobblestone (or 2 Iron Ingots + 1 Sandstone) -> 4 Iron Bars
        if (non_empty == 3) {
            var iron_count: u8 = 0;
            var stone_count: u8 = 0;
            var other_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) iron_count += 1
                else if (sl.item == .cobblestone or sl.item == .sandstone) stone_count += 1
                else if (!sl.isEmpty()) other_count += 1;
            }
            if (iron_count == 2 and stone_count == 1 and other_count == 0) {
                self.craft_output = .{ .item = .iron_bars, .count = 4 };
                return;
            }
        }

        // Recipe 98: Chain: 1 Iron Ingot + 1..2 Iron Ore (or 1 Iron Ingot + 1 Iron/Chain link) -> 2 Chains
        if (non_empty >= 2 and non_empty <= 3) {
            var ingot_count: u8 = 0;
            var ore_count: u8 = 0;
            var other_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) ingot_count += 1
                else if (sl.item == .iron_ore) ore_count += 1
                else if (!sl.isEmpty()) other_count += 1;
            }
            if (ingot_count >= 1 and ore_count >= 1 and other_count == 0) {
                self.craft_output = .{ .item = .chain, .count = 2 };
                return;
            }
        }

        // Recipe 97: Soul Lantern: 1 Soul Torch + 1..3 Iron Ingots (or Iron Ore) -> 1 Soul Lantern
        if (non_empty >= 2 and non_empty <= 4) {
            var soul_torch_count: u8 = 0;
            var iron_count: u8 = 0;
            var other_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .soul_torch) soul_torch_count += 1
                else if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1
                else if (!sl.isEmpty()) other_count += 1;
            }
            if (soul_torch_count == 1 and iron_count >= 1 and other_count == 0) {
                self.craft_output = .{ .item = .soul_lantern, .count = 1 };
                return;
            }
        }

        // Recipe 96: Lantern: 1 Torch + 1..3 Iron Ingots (or Iron Ore) -> 1 Lantern
        if (non_empty >= 2 and non_empty <= 4) {
            var torch_count: u8 = 0;
            var iron_count: u8 = 0;
            var other_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .torch) torch_count += 1
                else if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1
                else if (!sl.isEmpty()) other_count += 1;
            }
            if (torch_count == 1 and iron_count >= 1 and other_count == 0) {
                self.craft_output = .{ .item = .lantern, .count = 1 };
                return;
            }
        }

        // Recipe 95: Stonecutter: 1 Iron Ingot + 1..3 Stone (or Cobblestone/Sandstone) -> 1 Stonecutter
        if (non_empty >= 2 and non_empty <= 4) {
            var iron_count: u8 = 0;
            var stone_count: u8 = 0;
            var other_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) iron_count += 1
                else if (sl.item == .stone or sl.item == .cobblestone or sl.item == .sandstone) stone_count += 1
                else if (!sl.isEmpty()) other_count += 1;
            }
            if (iron_count == 1 and stone_count >= 1 and other_count == 0) {
                self.craft_output = .{ .item = .stonecutter, .count = 1 };
                return;
            }
        }

        // Recipe 94: Blast Furnace: 1 Furnace + 1 Iron Ingot (or Iron Ore) + 1 Stone (or Cobblestone/Sandstone) -> 1 Blast Furnace
        if (non_empty >= 3 and non_empty <= 5) {
            var furnace_count: u8 = 0;
            var iron_count: u8 = 0;
            var stone_count: u8 = 0;
            var other_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .furnace) furnace_count += 1
                else if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1
                else if (sl.item == .stone or sl.item == .cobblestone or sl.item == .sandstone) stone_count += 1
                else if (!sl.isEmpty()) other_count += 1;
            }
            if (furnace_count == 1 and iron_count >= 1 and stone_count >= 1 and other_count == 0) {
                self.craft_output = .{ .item = .blast_furnace, .count = 1 };
                return;
            }
        }

        // Recipe 93: Smoker: 1 Furnace + 1 Wood Planks (or Wood Log) -> 1 Smoker
        if (non_empty >= 2 and non_empty <= 4) {
            var furnace_count: u8 = 0;
            var wood_count: u8 = 0;
            var other_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .furnace) furnace_count += 1
                else if (sl.item == .wood or sl.item == .wood_planks) wood_count += 1
                else if (!sl.isEmpty()) other_count += 1;
            }
            if (furnace_count == 1 and wood_count >= 1 and other_count == 0) {
                self.craft_output = .{ .item = .smoker, .count = 1 };
                return;
            }
        }

        // Recipe 92: Loom: 2 Wool (or Vines) + 2 Wood Planks -> 1 Loom
        if (non_empty == 4) {
            var thread_count: u8 = 0;
            var plank_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wool or sl.item == .weeping_vines or sl.item == .twisting_vines) thread_count += 1;
                if (sl.item == .wood_planks) plank_count += 1;
            }
            if (thread_count == 2 and plank_count == 2) {
                self.craft_output = .{ .item = .loom, .count = 1 };
                return;
            }
        }

        // Recipe 91: Composter: 3 Wood Planks + 1 Stick -> 1 Composter
        if (non_empty == 4) {
            var plank_count: u8 = 0;
            var stick_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wood_planks) plank_count += 1;
                if (sl.item == .stick) stick_count += 1;
            }
            if (plank_count == 3 and stick_count == 1) {
                self.craft_output = .{ .item = .composter, .count = 1 };
                return;
            }
        }

        // Recipe 90: Fletching Table: 2 Sticks (or Coal / Arrows) + 2 Wood Planks -> 1 Fletching Table
        if (non_empty == 4) {
            var fletch_mat_count: u8 = 0;
            var plank_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .stick or sl.item == .coal or sl.item == .arrow) fletch_mat_count += 1;
                if (sl.item == .wood_planks) plank_count += 1;
            }
            if (fletch_mat_count == 2 and plank_count == 2) {
                self.craft_output = .{ .item = .fletching_table, .count = 1 };
                return;
            }
        }

        // Recipe 89: Cartography Table: 1 Compass (or Lodestone Compass / Redstone Dust) + 1 Wood Planks + 1..2 Sticks -> 1 Cartography Table
        if (non_empty >= 3 and non_empty <= 4) {
            var nav_count: u8 = 0;
            var plank_count: u8 = 0;
            var stick_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .compass or sl.item == .lodestone_compass or sl.item == .redstone_dust) nav_count += 1;
                if (sl.item == .wood_planks) plank_count += 1;
                if (sl.item == .stick) stick_count += 1;
            }
            if (nav_count == 1 and plank_count == 1 and (stick_count == 1 or stick_count == 2)) {
                self.craft_output = .{ .item = .cartography_table, .count = 1 };
                return;
            }
        }

        // Recipe 88: Smithing Table: 2 Iron Ingots (or Iron Ore) + 2 Wood Planks -> 1 Smithing Table
        if (non_empty == 4) {
            var iron_count: u8 = 0;
            var plank_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1;
                if (sl.item == .wood_planks) plank_count += 1;
            }
            if (iron_count == 2 and plank_count == 2) {
                self.craft_output = .{ .item = .smithing_table, .count = 1 };
                return;
            }
        }

        // Recipe 87: Grindstone: 1 Stone (or Cobblestone/Sandstone) + 2 Sticks + 1 Wood Planks -> 1 Grindstone
        if (non_empty == 4) {
            var stone_count: u8 = 0;
            var stick_count: u8 = 0;
            var plank_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .stone or sl.item == .cobblestone or sl.item == .sandstone) stone_count += 1;
                if (sl.item == .stick) stick_count += 1;
                if (sl.item == .wood_planks) plank_count += 1;
            }
            if (stone_count == 1 and stick_count == 2 and plank_count == 1) {
                self.craft_output = .{ .item = .grindstone, .count = 1 };
                return;
            }
        }

        // Recipe 86: Anvil: 3 Iron Ingots (or Iron Ore) + 1 Cobblestone (or Stone) -> 1 Anvil
        if (non_empty == 4) {
            var iron_count: u8 = 0;
            var base_stone_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1;
                if (sl.item == .cobblestone or sl.item == .stone) base_stone_count += 1;
            }
            if (iron_count == 3 and base_stone_count == 1) {
                self.craft_output = .{ .item = .anvil, .count = 1 };
                return;
            }
        }

        // Recipe 85: Enchantment Table: 2 Obsidian + 1 Nether Quartz (or Nether Star / Gold Nugget) + 1 Wood Planks (or Wool) -> 1 Enchantment Table
        if (non_empty == 4) {
            var obs_count: u8 = 0;
            var gem_count: u8 = 0;
            var book_cloth_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .obsidian or sl.item == .crying_obsidian) obs_count += 1;
                if (sl.item == .nether_quartz or sl.item == .nether_star or sl.item == .gold_nugget) gem_count += 1;
                if (sl.item == .wood_planks or sl.item == .wool) book_cloth_count += 1;
            }
            if (obs_count == 2 and gem_count == 1 and book_cloth_count == 1) {
                self.craft_output = .{ .item = .enchantment_table, .count = 1 };
                return;
            }
        }

        // Recipe 84: Target Dummy: 1 Hay Bale + 1..2 Sticks + 1 Wood Planks (or Wool) -> 1 Target Dummy
        if (non_empty >= 3 and non_empty <= 4) {
            var hay_count: u8 = 0;
            var stick_count: u8 = 0;
            var wood_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .hay_bale) hay_count += 1;
                if (sl.item == .stick) stick_count += 1;
                if (sl.item == .wood_planks or sl.item == .wool) wood_count += 1;
            }
            if (hay_count == 1 and stick_count >= 1 and wood_count >= 1 and (hay_count + stick_count + wood_count == non_empty)) {
                self.craft_output = .{ .item = .target_dummy, .count = 1 };
                return;
            }
        }

        // Recipe 83: Armor Stand: 1 Stone (smooth stone base) + 2..3 Sticks -> 1 Armor Stand
        if (non_empty >= 3 and non_empty <= 4) {
            var stone_count: u8 = 0;
            var stick_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .stone or sl.item == .cobblestone) stone_count += 1;
                if (sl.item == .stick) stick_count += 1;
            }
            if (stone_count == 1 and stick_count >= 2 and (stone_count + stick_count == non_empty)) {
                self.craft_output = .{ .item = .armor_stand, .count = 1 };
                return;
            }
        }

        // Recipe 81: Oak Fence: 2 Wood Planks + 2 Sticks (4 items) or 2 Wood Planks vertically + 1 Stick (vertical column g0+g2 + g1 stick) -> 2 Oak Fences
        if (non_empty == 3) {
            // Vertical 2 planks (g0, g2) + stick (g1 or g3) or (g1, g3 planks + g0 or g2 stick)
            if ((g0 == .wood_planks and g2 == .wood_planks and (g1 == .stick or g3 == .stick)) or
                (g1 == .wood_planks and g3 == .wood_planks and (g0 == .stick or g2 == .stick)))
            {
                self.craft_output = .{ .item = .oak_fence, .count = 2 };
                return;
            }
        }
        if (non_empty == 4) {
            var plank_count: u8 = 0;
            var stick_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wood_planks) plank_count += 1;
                if (sl.item == .stick) stick_count += 1;
            }
            if (plank_count == 2 and stick_count == 2) {
                self.craft_output = .{ .item = .oak_fence, .count = 2 };
                return;
            }
        }

        // Recipe 82: Lead: 1 Wool/Vines + 1 Stick (non_empty == 2) OR 1 Wool/Vines + 3 Sticks (non_empty == 4)
        if (non_empty == 2) {
            var string_fiber_count: u8 = 0;
            var stick_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .wool or sl.item == .weeping_vines or sl.item == .twisting_vines) string_fiber_count += 1;
                if (sl.item == .stick) stick_count += 1;
            }
            if (string_fiber_count == 1 and stick_count == 1) {
                self.craft_output = .{ .item = .lead, .count = 1 };
                return;
            }
        }

        // Recipe 78: Jukebox: 1 Gold Nugget / Nether Star / Nether Quartz + 2..3 Wood Planks -> 1 Jukebox
        if (non_empty >= 3 and non_empty <= 4) {
            var core_count: u8 = 0;
            var plank_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .gold_nugget or sl.item == .nether_star or sl.item == .nether_quartz) core_count += 1;
                if (sl.item == .wood_planks) plank_count += 1;
            }
            if (core_count == 1 and plank_count >= 2 and (core_count + plank_count == non_empty)) {
                self.craft_output = .{ .item = .jukebox, .count = 1 };
                return;
            }
        }

        // Recipe 79: Music Disc (13): 1 Gold Nugget + 1 Coal -> 1 Music Disc (13)
        if (non_empty == 2) {
            var gold_count: u8 = 0;
            var coal_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .gold_nugget) gold_count += 1;
                if (sl.item == .coal) coal_count += 1;
            }
            if (gold_count == 1 and coal_count == 1) {
                self.craft_output = .{ .item = .music_disc_13, .count = 1 };
                return;
            }
        }

        // Recipe 80: Music Disc (cat): 1 Warped Fungus + 1 Coal -> 1 Music Disc (cat)
        if (non_empty == 2) {
            var fungus_count: u8 = 0;
            var coal_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .warped_fungus) fungus_count += 1;
                if (sl.item == .coal) coal_count += 1;
            }
            if (fungus_count == 1 and coal_count == 1) {
                self.craft_output = .{ .item = .music_disc_cat, .count = 1 };
                return;
            }
        }

        // Recipe 77: Note Block: 1 Redstone Dust + 2..3 Wood Planks -> 1 Note Block
        if (non_empty >= 3 and non_empty <= 4) {
            var red_count: u8 = 0;
            var plank_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .redstone_dust) red_count += 1;
                if (sl.item == .wood_planks) plank_count += 1;
            }
            if (red_count == 1 and plank_count >= 2 and (red_count + plank_count == non_empty)) {
                self.craft_output = .{ .item = .note_block, .count = 1 };
                return;
            }
        }

        // Recipe 76: Daylight Detector: 1 Nether Quartz + 1 Glass + 1 Wood Planks -> 1 Daylight Detector
        if (non_empty == 3) {
            var quartz_count: u8 = 0;
            var glass_count: u8 = 0;
            var plank_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .nether_quartz) quartz_count += 1;
                if (sl.item == .glass) glass_count += 1;
                if (sl.item == .wood_planks) plank_count += 1;
            }
            if (quartz_count == 1 and glass_count == 1 and plank_count == 1) {
                self.craft_output = .{ .item = .daylight_detector, .count = 1 };
                return;
            }
        }

        // Recipe 75: Cauldron: 2..4 Iron Ingots -> 1 Cauldron
        if (non_empty >= 2 and non_empty <= 4) {
            var iron_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) iron_count += 1;
            }
            if (iron_count == non_empty and iron_count >= 2) {
                self.craft_output = .{ .item = .cauldron, .count = 1 };
                return;
            }
        }

        // Recipe 74: Brewing Stand: 1 Blaze Rod + 1..3 Cobblestone -> 1 Brewing Stand
        if (non_empty >= 2 and non_empty <= 4) {
            var rod_count: u8 = 0;
            var cobble_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .blaze_rod) rod_count += 1;
                if (sl.item == .cobblestone) cobble_count += 1;
            }
            if (rod_count == 1 and cobble_count >= 1 and (rod_count + cobble_count == non_empty)) {
                self.craft_output = .{ .item = .brewing_stand, .count = 1 };
                return;
            }
        }

        // Recipe 72: Blaze Powder: 1 Blaze Rod -> 2 Blaze Powder
        if (non_empty == 1) {
            if (g0 == .blaze_rod or g1 == .blaze_rod or g2 == .blaze_rod or g3 == .blaze_rod) {
                self.craft_output = .{ .item = .blaze_powder, .count = 2 };
                return;
            }
        }

        // Recipe 73: Fire Charge: 1 Blaze Powder + 1 Coal -> 3 Fire Charges
        if (non_empty == 2) {
            var powder_count: u8 = 0;
            var coal_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .blaze_powder) powder_count += 1;
                if (sl.item == .coal) coal_count += 1;
            }
            if (powder_count == 1 and coal_count == 1) {
                self.craft_output = .{ .item = .fire_charge, .count = 3 };
                return;
            }
        }

        // Recipe 71: Hopper: 1 Chest + 1..2 Iron Ingots -> 1 Hopper
        if (non_empty >= 2 and non_empty <= 3) {
            var has_chest = false;
            var iron_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .chest) has_chest = true;
                if (sl.item == .iron_ingot) iron_count += 1;
            }
            if (has_chest and iron_count >= 1 and ((if (has_chest) @as(u8, 1) else 0) + iron_count == non_empty)) {
                self.craft_output = .{ .item = .hopper, .count = 1 };
                return;
            }
        }

        // Recipe 70: Dropper: 1 Redstone Dust + 2..3 Cobblestone -> 1 Dropper
        if (non_empty >= 3) {
            var has_red = false;
            var cobble_count: u8 = 0;
            var other_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .redstone_dust) {
                    has_red = true;
                } else if (sl.item == .cobblestone) {
                    cobble_count += 1;
                } else if (sl.item != .none and sl.item != .bow and sl.item != .crossbow) {
                    other_count += 1;
                }
            }
            if (has_red and cobble_count >= 2 and (cobble_count + other_count + 1 == non_empty)) {
                self.craft_output = .{ .item = .dropper, .count = 1 };
                return;
            }
        }

        // Recipe 69: Dispenser: 1 Bow/Crossbow + 1 Redstone Dust + 1..2 Cobblestone -> 1 Dispenser
        if (non_empty >= 3) {
            var has_launcher = false;
            var has_red = false;
            var cobble_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .bow or sl.item == .crossbow) has_launcher = true;
                if (sl.item == .redstone_dust) has_red = true;
                if (sl.item == .cobblestone) cobble_count += 1;
            }
            if (has_launcher and has_red and cobble_count >= 1 and ((if (has_launcher) @as(u8, 1) else 0) + (if (has_red) @as(u8, 1) else 0) + cobble_count == non_empty)) {
                self.craft_output = .{ .item = .dispenser, .count = 1 };
                return;
            }
        }

        // Recipe 68: Fireworks Rocket: 1 Fire Charge + 1 Wool (or 1 Fire Charge + 1 Wood Planks) -> 3 Fireworks Rockets
        if (non_empty == 2) {
            const has_fire = (g0 == .fire_charge or g1 == .fire_charge or g2 == .fire_charge or g3 == .fire_charge);
            const has_casing = (g0 == .wool or g1 == .wool or g2 == .wool or g3 == .wool or
                                g0 == .wood_planks or g1 == .wood_planks or g2 == .wood_planks or g3 == .wood_planks);
            if (has_fire and has_casing) {
                self.craft_output = .{ .item = .fireworks_rocket, .count = 3 };
                return;
            }
        }

        // Recipe 67: Crossbow: 1 Iron Ingot + 1 Stick + 1 Wool/Vines (or 1 Iron + 2 Sticks + 1 Wool/Vines) -> 1 Crossbow
        if (non_empty >= 3) {
            var iron_count: u8 = 0;
            var stick_count: u8 = 0;
            var fiber_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) iron_count += 1;
                if (sl.item == .stick) stick_count += 1;
                if (sl.item == .wool or sl.item == .twisting_vines or sl.item == .weeping_vines) fiber_count += 1;
            }
            if (iron_count >= 1 and stick_count >= 1 and fiber_count >= 1 and (iron_count + stick_count + fiber_count == non_empty)) {
                self.craft_output = .{ .item = .crossbow, .count = 1 };
                return;
            }
        }

        // Recipe 66: Compass: 1 Iron Ingot + 1 Redstone Dust -> 1 Compass
        if (non_empty == 2) {
            const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            const has_red = (g0 == .redstone_dust or g1 == .redstone_dust or g2 == .redstone_dust or g3 == .redstone_dust);
            if (has_iron and has_red) {
                self.craft_output = .{ .item = .compass, .count = 1 };
                return;
            }
        }

        // Recipe 65: Shield: 1 Iron Ingot + 2 Wood Planks (or 1 Iron Ingot + 3 Wood Planks) -> 1 Shield
        if (non_empty == 3 or non_empty == 4) {
            var iron_count: u8 = 0;
            var plank_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .iron_ingot) iron_count += 1;
                if (sl.item == .wood_planks) plank_count += 1;
            }
            if (iron_count == 1 and (plank_count == 2 or plank_count == 3) and (iron_count + plank_count == non_empty)) {
                self.craft_output = .{ .item = .shield, .count = 1 };
                return;
            }
        }

        // Recipe 64: Bow: 2 Sticks + 1 Wool (or 2 Sticks + 1 Twisting Vines/Weeping Vines) -> 1 Bow
        if (non_empty == 3) {
            var stick_count: u8 = 0;
            var fiber_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .stick) stick_count += 1;
                if (sl.item == .wool or sl.item == .twisting_vines or sl.item == .weeping_vines) fiber_count += 1;
            }
            if (stick_count == 2 and fiber_count == 1) {
                self.craft_output = .{ .item = .bow, .count = 1 };
                return;
            }
        }

        // Recipe 63: Arrow: 1 Stick + 1 Iron Ingot (or 1 Stick + 1 Nether Quartz) -> 4 Arrows
        if (non_empty == 2) {
            const has_stick = (g0 == .stick or g1 == .stick or g2 == .stick or g3 == .stick);
            const has_point = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot or
                               g0 == .nether_quartz or g1 == .nether_quartz or g2 == .nether_quartz or g3 == .nether_quartz);
            if (has_stick and has_point) {
                self.craft_output = .{ .item = .arrow, .count = 4 };
                return;
            }
        }

        // Recipe 62: Spectral Arrow: 1 Glowstone + 1 Stick (or 1 Glowstone + 1 Iron Ingot) -> 2 Spectral Arrows
        if (non_empty == 2) {
            const has_glow = (g0 == .glowstone or g1 == .glowstone or g2 == .glowstone or g3 == .glowstone);
            const has_shaft = (g0 == .stick or g1 == .stick or g2 == .stick or g3 == .stick or
                               g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            if (has_glow and has_shaft) {
                self.craft_output = .{ .item = .spectral_arrow, .count = 2 };
                return;
            }
        }

        // Recipe 61: Netherite Boots: 1 Netherite Ingot + 1 Gold Nugget / Diamond Boots -> 1 Netherite Boots
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot or
                            g0 == .netherite_scrap or g1 == .netherite_scrap or g2 == .netherite_scrap or g3 == .netherite_scrap);
            const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget or
                              g0 == .diamond_boots or g1 == .diamond_boots or g2 == .diamond_boots or g3 == .diamond_boots);
            if (has_ni and has_gold) {
                self.craft_output = .{ .item = .netherite_boots, .count = 1 };
                return;
            }
        }

        // Recipe 60: Chiseled Nether Brick: 2 Nether Bricks -> 1 Chiseled Nether Brick
        if (non_empty == 2) {
            var nb_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .nether_brick) nb_count += 1;
            }
            if (nb_count == 2) {
                self.craft_output = .{ .item = .chiseled_nether_brick, .count = 1 };
                return;
            }
        }

        // Recipe 59: Netherite Leggings: 1 Netherite Ingot + 1 Obsidian / Diamond Leggings (or 2 Netherite Scrap) -> 1 Netherite Leggings
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_obs = (g0 == .obsidian or g1 == .obsidian or g2 == .obsidian or g3 == .obsidian or
                             g0 == .diamond_leggings or g1 == .diamond_leggings or g2 == .diamond_leggings or g3 == .diamond_leggings);
            var scraps: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .netherite_scrap) scraps += 1;
            }
            if ((has_ni and has_obs) or scraps == 2) {
                self.craft_output = .{ .item = .netherite_leggings, .count = 1 };
                return;
            }
        }

        // Recipe 58: Netherite Helmet: 1 Netherite Ingot + 1 Coal / Diamond Helmet (or 1 Iron Ingot + 1 Netherite Scrap) -> 1 Netherite Helmet
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_coal = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal or
                              g0 == .diamond_helmet or g1 == .diamond_helmet or g2 == .diamond_helmet or g3 == .diamond_helmet);
            const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            const has_scrap = (g0 == .netherite_scrap or g1 == .netherite_scrap or g2 == .netherite_scrap or g3 == .netherite_scrap);
            if ((has_ni and has_coal) or (has_iron and has_scrap)) {
                self.craft_output = .{ .item = .netherite_helmet, .count = 1 };
                return;
            }
        }

        // Recipe 57: Soul Speed Boots: 1 Iron Ingot + 1 Soul Sand (or 1 Netherite Ingot + 1 Soul Sand) -> 1 Soul Speed Boots
        if (non_empty == 2) {
            const has_metal = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot or
                               g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_soul = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand);
            if (has_metal and has_soul) {
                self.craft_output = .{ .item = .soul_speed_boots, .count = 1 };
                return;
            }
        }

        // Recipe 56: Netherite Chestplate: 1 Netherite Ingot + 1 Iron Ingot / Diamond Chestplate -> 1 Netherite Chestplate
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_base = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot or
                              g0 == .diamond_chestplate or g1 == .diamond_chestplate or g2 == .diamond_chestplate or g3 == .diamond_chestplate);
            if (has_ni and has_base) {
                self.craft_output = .{ .item = .netherite_chestplate, .count = 1 };
                return;
            }
        }

        // Recipe 55: Warped Fungus on a Stick: 1 Stick + 1 Warped Fungus -> 1 Warped Fungus on a Stick
        if (non_empty == 2) {
            const has_stick = (g0 == .stick or g1 == .stick or g2 == .stick or g3 == .stick);
            const has_wf = (g0 == .warped_fungus or g1 == .warped_fungus or g2 == .warped_fungus or g3 == .warped_fungus);
            if (has_stick and has_wf) {
                self.craft_output = .{ .item = .warped_fungus_on_a_stick, .count = 1 };
                return;
            }
        }

        // Recipe 54: Shroomlight: 1 Glowstone + 1 Fungus (Crimson or Warped) -> 1 Shroomlight
        if (non_empty == 2) {
            const has_glow = (g0 == .glowstone or g1 == .glowstone or g2 == .glowstone or g3 == .glowstone);
            const has_fungus = (g0 == .crimson_fungus or g1 == .crimson_fungus or g2 == .crimson_fungus or g3 == .crimson_fungus or
                                g0 == .warped_fungus or g1 == .warped_fungus or g2 == .warped_fungus or g3 == .warped_fungus);
            if (has_glow and has_fungus) {
                self.craft_output = .{ .item = .shroomlight, .count = 1 };
                return;
            }
        }

        // Recipe 53: Warped Fungus: 1 Twisting Vines + 1 Sapling (or 1 Crimson Fungus + 1 Soul Sand) -> 2 Warped Fungus
        if (non_empty == 2) {
            const has_twist = (g0 == .twisting_vines or g1 == .twisting_vines or g2 == .twisting_vines or g3 == .twisting_vines);
            const has_sap = (g0 == .sapling or g1 == .sapling or g2 == .sapling or g3 == .sapling);
            const has_crim = (g0 == .crimson_fungus or g1 == .crimson_fungus or g2 == .crimson_fungus or g3 == .crimson_fungus);
            const has_soul = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand);
            if ((has_twist and has_sap) or (has_crim and has_soul)) {
                self.craft_output = .{ .item = .warped_fungus, .count = 2 };
                return;
            }
        }

        // Recipe 52: Crimson Fungus: 1 Nether Wart + 1 Sapling -> 2 Crimson Fungus
        if (non_empty == 2) {
            const has_wart = (g0 == .nether_wart or g1 == .nether_wart or g2 == .nether_wart or g3 == .nether_wart);
            const has_sap = (g0 == .sapling or g1 == .sapling or g2 == .sapling or g3 == .sapling);
            if (has_wart and has_sap) {
                self.craft_output = .{ .item = .crimson_fungus, .count = 2 };
                return;
            }
        }

        // Recipe 51: Hay Bale: 2 Wood Planks + 2 Saplings/Leaves (or 4 Saplings) -> 1 Hay Bale
        if (non_empty == 4) {
            var bio_count: u8 = 0;
            var wood_count: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.isEmpty()) continue;
                if (sl.item == .sapling or sl.item == .leaves) bio_count += 1
                else if (sl.item == .wood_planks) wood_count += 1;
            }
            if ((bio_count == 2 and wood_count == 2) or bio_count == 4) {
                self.craft_output = .{ .item = .hay_bale, .count = 1 };
                return;
            }
        }

        // Recipe 50: Target Block: 1 Redstone Dust + 1 Wood Planks (or 1 Hay/Wheat) -> 1 Target Block
        if (non_empty == 2) {
            const has_red = (g0 == .redstone_dust or g1 == .redstone_dust or g2 == .redstone_dust or g3 == .redstone_dust);
            const has_wood = (g0 == .wood_planks or g1 == .wood_planks or g2 == .wood_planks or g3 == .wood_planks or g0 == .hay_bale or g1 == .hay_bale or g2 == .hay_bale or g3 == .hay_bale);
            if (has_red and has_wood) {
                self.craft_output = .{ .item = .target_block, .count = 1 };
                return;
            }
        }

        // Recipe 49: Twisting Vines: 1 Weeping Vines + 1 Soul Sand (or Soul Torch) -> 2 Twisting Vines
        if (non_empty == 2) {
            const has_weep = (g0 == .weeping_vines or g1 == .weeping_vines or g2 == .weeping_vines or g3 == .weeping_vines);
            const has_warp = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand or
                              g0 == .soul_torch or g1 == .soul_torch or g2 == .soul_torch or g3 == .soul_torch);
            if (has_weep and has_warp) {
                self.craft_output = .{ .item = .twisting_vines, .count = 2 };
                return;
            }
        }

        // Recipe 48: Weeping Vines: 2 Nether Wart stacked vertically -> 2 Weeping Vines
        if (non_empty == 2) {
            if ((g0 == .nether_wart and g2 == .nether_wart and g1 == .none and g3 == .none) or
                (g1 == .nether_wart and g3 == .nether_wart and g0 == .none and g2 == .none))
            {
                self.craft_output = .{ .item = .weeping_vines, .count = 2 };
                return;
            }
        }

        // Recipe 47: Golden Apple via Nuggets: 2 Apples + 2 Gold Nuggets -> 1 Golden Apple
        if (non_empty == 4) {
            var apple_cnt: u8 = 0;
            var nugget_cnt: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.isEmpty()) continue;
                if (sl.item == .apple) apple_cnt += 1 else if (sl.item == .gold_nugget) nugget_cnt += 1;
            }
            if (apple_cnt == 2 and nugget_cnt == 2) {
                self.craft_output = .{ .item = .golden_apple, .count = 1 };
                return;
            }
        }

        // Recipe 46: Gilded Blackstone: 1 Blackstone + 1 Gold Nugget -> 1 Gilded Blackstone
        if (non_empty == 2) {
            const has_blackstone = (g0 == .blackstone or g1 == .blackstone or g2 == .blackstone or g3 == .blackstone);
            const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget);
            if (has_blackstone and has_gold) {
                self.craft_output = .{ .item = .gilded_blackstone, .count = 1 };
                return;
            }
        }

        // Recipe 45: Blackstone: 1 Basalt + 1 Coal (or 2 Basalt) -> 2 Blackstone
        if (non_empty == 2) {
            const has_basalt = (g0 == .basalt or g1 == .basalt or g2 == .basalt or g3 == .basalt);
            const has_darkener = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal or
                                  (g0 == .basalt and g1 == .basalt) or (g0 == .basalt and g2 == .basalt) or
                                  (g0 == .basalt and g3 == .basalt) or (g1 == .basalt and g2 == .basalt) or
                                  (g1 == .basalt and g3 == .basalt) or (g2 == .basalt and g3 == .basalt));
            if (has_basalt and has_darkener) {
                self.craft_output = .{ .item = .blackstone, .count = 2 };
                return;
            }
        }

        // Recipe 44: Basalt: 1 Cobblestone + 1 Soul Sand (or Magma) -> 2 Basalt
        if (non_empty == 2) {
            const has_cobble = (g0 == .cobblestone or g1 == .cobblestone or g2 == .cobblestone or g3 == .cobblestone);
            const has_volcanic = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand or
                                  g0 == .magma or g1 == .magma or g2 == .magma or g3 == .magma);
            if (has_cobble and has_volcanic) {
                self.craft_output = .{ .item = .basalt, .count = 2 };
                return;
            }
        }

        // Recipe 43: Lodestone: 1 Netherite Ingot + 1 Chiseled Quartz (or Quartz Block) -> 1 Lodestone
        if (non_empty == 2) {
            const has_netherite = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_carved_stone = (g0 == .chiseled_quartz_block or g1 == .chiseled_quartz_block or g2 == .chiseled_quartz_block or g3 == .chiseled_quartz_block or
                                      g0 == .quartz_block or g1 == .quartz_block or g2 == .quartz_block or g3 == .quartz_block or
                                      g0 == .stone or g1 == .stone or g2 == .stone or g3 == .stone);
            if (has_netherite and has_carved_stone) {
                self.craft_output = .{ .item = .lodestone, .count = 1 };
                return;
            }
        }

        // Recipe 42: Crying Obsidian: 1 Obsidian + 1 Magma Cream -> 1 Crying Obsidian
        if (non_empty == 2) {
            const has_obs = (g0 == .obsidian or g1 == .obsidian or g2 == .obsidian or g3 == .obsidian);
            const has_magma_cream = (g0 == .magma_cream or g1 == .magma_cream or g2 == .magma_cream or g3 == .magma_cream);
            if (has_obs and has_magma_cream) {
                self.craft_output = .{ .item = .crying_obsidian, .count = 1 };
                return;
            }
        }

        // Recipe 41: Respawn Anchor: 2 Obsidian (or Crying Obsidian) + 2 Glowstone (full 2x2, any layout) -> 1 Respawn Anchor
        {
            var obs: u8 = 0;
            var glow: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.isEmpty()) continue;
                if (sl.item == .obsidian or sl.item == .crying_obsidian) obs += 1 else if (sl.item == .glowstone) glow += 1 else {
                    obs = 99;
                    break;
                }
            }
            if (obs == 2 and glow == 2) {
                self.craft_output = .{ .item = .respawn_anchor, .count = 1 };
                return;
            }
        }

        // Recipe 40: Netherite Sword: 1 Iron/Diamond Sword + 1 Netherite Ingot (non_empty == 2) -> 1 Netherite Sword
        if (non_empty == 2) {
            const has_sword = (g0 == .iron_sword or g1 == .iron_sword or g2 == .iron_sword or g3 == .iron_sword or
                g0 == .diamond_sword or g1 == .diamond_sword or g2 == .diamond_sword or g3 == .diamond_sword);
            const has_ingot = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            if (has_sword and has_ingot) {
                self.craft_output = .{ .item = .netherite_sword, .count = 1 };
                return;
            }
        }

        // Recipe 39: Netherite Pickaxe: 1 Iron/Diamond Pickaxe + 1 Netherite Ingot (non_empty == 2) -> 1 Netherite Pickaxe
        if (non_empty == 2) {
            const has_pick = (g0 == .iron_pickaxe or g1 == .iron_pickaxe or g2 == .iron_pickaxe or g3 == .iron_pickaxe or
                g0 == .diamond_pickaxe or g1 == .diamond_pickaxe or g2 == .diamond_pickaxe or g3 == .diamond_pickaxe);
            const has_ingot = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            if (has_pick and has_ingot) {
                self.craft_output = .{ .item = .netherite_pickaxe, .count = 1 };
                return;
            }
        }

        // Recipe 38: Netherite Ingot: 2 Netherite Scrap + 2 Iron Ingot (full 2x2, any layout) -> 1 Netherite Ingot
        {
            var scraps: u8 = 0;
            var iron_ingots: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.isEmpty()) continue;
                if (sl.item == .netherite_scrap) scraps += 1 else if (sl.item == .iron_ingot) iron_ingots += 1 else {
                    scraps = 99;
                    break;
                }
            }
            if (scraps == 2 and iron_ingots == 2) {
                self.craft_output = .{ .item = .netherite_ingot, .count = 1 };
                return;
            }
        }

        // Recipe 37: Beacon: 1 Nether Star + 1 Obsidian + 2 Glass (full 2x2, any layout) -> 1 Beacon
        {
            var stars: u8 = 0;
            var obs: u8 = 0;
            var glasses: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.isEmpty()) continue;
                if (sl.item == .nether_star) stars += 1 else if (sl.item == .obsidian) obs += 1 else if (sl.item == .glass) glasses += 1 else {
                    stars = 99;
                    break;
                }
            }
            if (stars == 1 and obs == 1 and glasses == 2) {
                self.craft_output = .{ .item = .beacon, .count = 1 };
                return;
            }
        }

        // Recipe 13: Golden Apple: 2 apples + 1 iron ingot + 1 coal (full 2x2, any layout)
        {
            var apples: u8 = 0;
            var ingots: u8 = 0;
            var coals: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.isEmpty()) continue;
                if (sl.item == .apple) apples += 1 else if (sl.item == .iron_ingot) ingots += 1 else if (sl.item == .coal) coals += 1 else {
                    apples = 99;
                    break;
                }
            }
            if (apples == 2 and ingots == 1 and coals == 1 and non_empty == 4) {
                self.craft_output = .{ .item = .golden_apple, .count = 1 };
                return;
            }
        }

        // Recipe 12: 4 Snowballs (2x2) -> 1 Snow Block
        if (non_empty == 4) {
            if (g0 == .snowball and g1 == .snowball and g2 == .snowball and g3 == .snowball) {
                self.craft_output = .{ .item = .snow_block, .count = 1 };
                return;
            }
        }

        // Recipe 10: 4 Stone (2x2) -> 1 Furnace (bricks own 4-cobble)
        if (non_empty == 4) {
            if (g0 == .stone and g1 == .stone and g2 == .stone and g3 == .stone) {
                self.craft_output = .{ .item = .furnace, .count = 1 };
                return;
            }
        }

        // Recipe 8: Cooking in 2x2: 1 Raw Meat + 1 Coal (fuel below) -> 1 Cooked Meat
        if (non_empty == 2) {
            const cook = [_]ItemType{ .raw_pork, .raw_mutton };
            for (cook) |raw| {
                const done: ItemType = if (raw == .raw_pork) .cooked_pork else .cooked_mutton;
                if (((g0 == raw and g2 == .coal) or (g1 == raw and g3 == .coal) or
                    (g0 == .coal and g2 == raw) or (g1 == .coal and g3 == raw)))
                {
                    self.craft_output = .{ .item = done, .count = 1 };
                    return;
                }
            }
        }

        // Recipe 7: Smelting simulation in 2x2: 1 Sand + 1 Coal -> 2 Glass
        if (non_empty == 2) {
            if ((g0 == .sand and g2 == .coal) or (g1 == .sand and g3 == .coal) or
                (g0 == .coal and g2 == .sand) or (g1 == .coal and g3 == .sand))
            {
                self.craft_output = .{ .item = .glass, .count = 2 };
                return;
            }
        }

        // Wave 4 recipe 305: Book + Lapis Lazuli -> Enchanted Book.
        if (non_empty == 2) {
            var has_book = false;
            var has_lapis = false;
            for (self.craft_grid) |slot| {
                has_book = has_book or slot.item == .book;
                has_lapis = has_lapis or slot.item == .lapis_lazuli;
            }
            if (has_book and has_lapis) {
                self.craft_output = .{ .item = .enchanted_book, .count = 1 };
                return;
            }
        }

        // Wave 4 recipe 306: Enchanted Book + Emerald -> Mending Book.
        if (non_empty == 2) {
            var has_enchanted = false;
            var has_emerald = false;
            for (self.craft_grid) |slot| {
                has_enchanted = has_enchanted or slot.item == .enchanted_book;
                has_emerald = has_emerald or slot.item == .emerald;
            }
            if (has_enchanted and has_emerald) {
                self.craft_output = .{ .item = .mending_book, .count = 1 };
                return;
            }
        }

        // Wave 4 recipe 307: Turtle Egg + Seagrass + Potion + Turtle Helmet -> Fox Treat.
        if (non_empty == 4) {
            var eggs: u8 = 0;
            var grass: u8 = 0;
            var potions: u8 = 0;
            var helmets: u8 = 0;
            for (self.craft_grid) |slot| {
                switch (slot.item) {
                    .turtle_egg => eggs += 1,
                    .seagrass => grass += 1,
                    .potion_of_turtle_master => potions += 1,
                    .turtle_helmet => helmets += 1,
                    else => {},
                }
            }
            if (eggs == 1 and grass == 1 and potions == 1 and helmets == 1) {
                self.craft_output = .{ .item = .sweet_berry_fox_treat, .count = 2 };
                return;
            }
        }

        // Wave 5: gunpowder turns a water bottle or harming potion into its splash form.
        if (non_empty == 2) {
            var has_gunpowder = false;
            var has_water_bottle = false;
            var has_harming = false;
            for (self.craft_grid) |slot| {
                has_gunpowder = has_gunpowder or slot.item == .gunpowder;
                has_water_bottle = has_water_bottle or slot.item == .water_bottle;
                has_harming = has_harming or slot.item == .harming_potion;
            }
            if (has_gunpowder and has_water_bottle) {
                self.craft_output = .{ .item = .splash_water_bottle, .count = 1 };
                return;
            }
            if (has_gunpowder and has_harming) {
                self.craft_output = .{ .item = .splash_harming_potion, .count = 1 };
                return;
            }
        }

        // Wave 6 recipes: four Terracotta make Glazed Terracotta; two matching
        // metal ingredients make their weighted plate variant.
        if (non_empty == 4 and g0 == .terracotta and g1 == .terracotta and g2 == .terracotta and g3 == .terracotta) {
            self.craft_output = .{ .item = .glazed_terracotta, .count = 1 };
            return;
        }
        if (wave9CraftingRecipe(self.craft_grid)) |output| {
            self.craft_output = output;
            return;
        }
        if (wave10CraftingRecipe(self.craft_grid)) |output| {
            self.craft_output = output;
            return;
        }
        if (wave11CraftingRecipe(self.craft_grid)) |output| {
            self.craft_output = output;
            return;
        }
        if (wave12CraftingRecipe(self.craft_grid)) |output| {
            self.craft_output = output;
            return;
        }
        if (wave13CraftingRecipe(self.craft_grid)) |output| {
            self.craft_output = output;
            return;
        }
        self.craft_output.clear();
    }

    /// Craft output clicked: decrements 1 item from each ingredient slot, outputs to cursor stack.
    pub fn takeCraftResult(self: *Inventory, cursor: *ItemStack) bool {
        if (self.craft_output.isEmpty()) return false;

        const out = self.craft_output;
        if (!cursor.isEmpty()) {
            if (cursor.item != out.item or cursor.count + out.count > out.item.maxStackSize()) {
                return false;
            }
            cursor.count += out.count;
        } else {
            cursor.* = out;
        }

        // Decrement inputs
        for (&self.craft_grid) |*slot| {
            if (!slot.isEmpty()) {
                slot.decrement(1);
            }
        }

        self.updateCrafting();
        return true;
    }
};

test "inventory init and hotbar defaults" {
    const inv = Inventory.init();
    try std.testing.expectEqual(inv.slots[0].item, .stone);
    try std.testing.expectEqual(inv.slots[0].count, 64);
    try std.testing.expectEqual(inv.slots[3].item, .wooden_pickaxe);
    try std.testing.expectEqual(inv.slots[4].item, .wood);
    try std.testing.expectEqual(inv.slots[5].item, .leaves);
}

test "inventory addItem stacking" {
    var inv = Inventory.init();
    inv.slots[0].clear();
    _ = inv.addItem(.stone, 30);
    try std.testing.expectEqual(inv.slots[0].item, .stone);
    try std.testing.expectEqual(inv.slots[0].count, 30);

    _ = inv.addItem(.stone, 40);
    try std.testing.expectEqual(inv.slots[0].count, 64);
    try std.testing.expectEqual(inv.slots[6].item, .stone);
    try std.testing.expectEqual(inv.slots[6].count, 6);
}

test "crafting recipes: wood to planks, planks to sticks, 2x2 to table and pickaxe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .wood, .count = 2 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wood_planks);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    var cursor = ItemStack{};
    try std.testing.expect(inv.takeCraftResult(&cursor));
    try std.testing.expectEqual(cursor.item, .wood_planks);
    try std.testing.expectEqual(cursor.count, 4);
    try std.testing.expectEqual(inv.craft_grid[0].count, 1);

    // Now test sticks (vertical planks)
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 2 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 2 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stick);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Test 4 planks -> crafting table
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .crafting_bench);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "inventory full test: transfer between slots, boundary checks" {
    var inv = Inventory.init();
    // Test slot out of bounds
    try std.testing.expect(inv.getHotbar(6) == null);
    try std.testing.expect(inv.getHotbar(0) != null);

    // Test stack decrement to empty
    var stack = ItemStack{ .item = .dirt, .count = 2 };
    stack.decrement(1);
    try std.testing.expectEqual(stack.count, 1);
    stack.decrement(1);
    try std.testing.expect(stack.isEmpty());

    // Test item max stack
    const pick = ItemType.wooden_pickaxe;
    try std.testing.expectEqual(pick.maxStackSize(), 1);
    try std.testing.expectEqual(pick.maxDurability(), 25);
    try std.testing.expect(pick.isTool());
    try std.testing.expect(!ItemType.stone.isTool());
    const planks = ItemType.wood_planks;
    try std.testing.expectEqual(planks.maxStackSize(), 64);
}

test "crafting recipes: sandstone, bricks, glass" {
    var inv = Inventory.init();
    // 4 Sand -> 1 Sandstone
    inv.craft_grid[0] = .{ .item = .sand, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sand, .count = 1 };
    inv.craft_grid[2] = .{ .item = .sand, .count = 1 };
    inv.craft_grid[3] = .{ .item = .sand, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .sandstone);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // 4 Cobblestone -> 4 Bricks
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[3] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .brick);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Sand + Coal -> 2 Glass
    inv.craft_grid[0] = .{ .item = .sand, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .glass);
    try std.testing.expectEqual(inv.craft_output.count, 2);
}

test "cooking recipes: raw meat + coal -> cooked meat" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .raw_pork, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .cooked_pork);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    inv.craft_grid[0] = .{ .item = .raw_mutton, .count = 1 };
    inv.craft_grid[2] = .{ .item = .coal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .cooked_mutton);
}

test "furnace recipe: 4 stone -> furnace" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .stone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stone, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .furnace);
}

test "quartz pillar and chiseled quartz architectural crafting recipes" {
    var inv = Inventory.init();
    // 2 stacked quartz blocks -> 2 quartz pillars
    inv.craft_grid[0] = .{ .item = .quartz_block, .count = 1 };
    inv.craft_grid[2] = .{ .item = .quartz_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .quartz_pillar);
    try std.testing.expectEqual(inv.craft_output.count, 2);
    try std.testing.expectEqual(inv.craft_output.item.toBlockId(), .quartz_pillar);

    // 2 stacked quartz pillars -> 2 chiseled quartz blocks
    inv.craft_grid[0] = .{ .item = .quartz_pillar, .count = 1 };
    inv.craft_grid[2] = .{ .item = .quartz_pillar, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chiseled_quartz_block);
    try std.testing.expectEqual(inv.craft_output.count, 2);
    try std.testing.expectEqual(inv.craft_output.item.toBlockId(), .chiseled_quartz_block);
}

test "block of quartz crafting recipe from 4 nether quartz crystals" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .nether_quartz, .count = 1 };
    inv.craft_grid[1] = .{ .item = .nether_quartz, .count = 1 };
    inv.craft_grid[2] = .{ .item = .nether_quartz, .count = 1 };
    inv.craft_grid[3] = .{ .item = .nether_quartz, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .quartz_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);
    try std.testing.expectEqual(inv.craft_output.item.toBlockId(), .quartz_block);
}

test "nether quartz ore drops and item conversion" {
    const ore = ItemType.nether_quartz_ore;
    try std.testing.expectEqual(ore.toBlockId(), .nether_quartz_ore);
    try std.testing.expectEqual(ore.name(), "Nether Quartz Ore");
    // Mining nether quartz ore yields raw nether quartz crystal
    try std.testing.expectEqual(ItemType.fromBlockId(.nether_quartz_ore), .nether_quartz);
    const quartz = ItemType.nether_quartz;
    try std.testing.expectEqual(quartz.name(), "Nether Quartz");
    try std.testing.expectEqual(quartz.toBlockId(), null);
}

test "glowstone block item properties and drop" {
    const item = ItemType.glowstone;
    try std.testing.expectEqual(item.toBlockId(), .glowstone);
    try std.testing.expectEqual(item.name(), "Glowstone");
    try std.testing.expectEqual(ItemType.fromBlockId(.glowstone), .glowstone);
}

test "fire resistance potion recipe: magma + apple or glass" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .magma, .count = 1 };
    inv.craft_grid[1] = .{ .item = .apple, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fire_resistance_potion);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fire_resistance_potion);

    // Wart brewing: nether wart + glass vial -> potion (apple alone with wart does not brew)
    inv.craft_grid[0] = .{ .item = .nether_wart, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fire_resistance_potion);

    inv.craft_grid[1] = .{ .item = .apple, .count = 1 };
    inv.updateCrafting();
    try std.testing.expect(inv.craft_output.item != .fire_resistance_potion);
}

test "golden apple recipe: 2 apples + ingot + coal" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .apple, .count = 1 };
    inv.craft_grid[1] = .{ .item = .apple, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[3] = .{ .item = .coal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_apple);
}

test "tnt recipe: 2 sand + 2 coal checkerboard" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .sand, .count = 1 };
    inv.craft_grid[1] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[2] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[3] = .{ .item = .sand, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .tnt);
}

test "torch recipe: coal over stick -> 4 torches" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .torch);
    try std.testing.expectEqual(inv.craft_output.count, 4);
}

test "chest recipe: 3 wood planks -> 1 chest" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chest);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "door recipe: 1 stick over 2 wood planks -> 1 wooden door" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wooden_door);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "redstone torch recipe: redstone dust over stick -> 1 redstone torch" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .redstone_torch);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "iron door recipe: 4 iron ingots -> 1 iron door" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[3] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_door);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "lamp recipe: torch + glass + 2 redstone dust -> 1 lamp" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .torch, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[3] = .{ .item = .redstone_dust, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .redstone_lamp);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "repeater recipe: 2 torches + redstone dust + stone -> 1 repeater" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .torch, .count = 1 };
    inv.craft_grid[1] = .{ .item = .torch, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .redstone_repeater);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "lever recipe: stick over cobblestone -> 1 lever" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lever);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "redstone dust recipe: coal + iron ingot -> 4 redstone dust" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .redstone_dust);
    try std.testing.expectEqual(inv.craft_output.count, 4);
}

test "pressure plate recipe: 2 wood planks horizontal -> 1 pressure plate" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .pressure_plate);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also test bottom row
    inv.craft_grid[0].clear();
    inv.craft_grid[1].clear();
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .pressure_plate);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "cactus item mapping and conversion" {
    const item = ItemType.fromBlockId(.cactus);
    try std.testing.expectEqual(item, ItemType.cactus);
    try std.testing.expectEqual(item.toBlockId(), .cactus);
    try std.testing.expectEqualStrings(item.name(), "Cactus");
}

pub fn canHarvestBlock(held: ItemType, block: BlockId) bool {
    if (block == .cobweb and (held == .wooden_sword or held == .stone_sword or held == .golden_sword or held == .iron_sword or held == .diamond_sword or held == .netherite_sword or held == .shears)) return true;
    const need = block_mod.requiredTier(block);
    if (need == .hand) return true;
    return held == .wooden_pickaxe or held == .stone_pickaxe or held == .golden_pickaxe or held == .iron_pickaxe or held == .diamond_pickaxe or held == .netherite_pickaxe or
           held == .wooden_axe or held == .stone_axe or held == .golden_axe or held == .iron_axe or held == .diamond_axe or held == .netherite_axe or
           held == .wooden_shovel or held == .stone_shovel or held == .golden_shovel or held == .iron_shovel or held == .diamond_shovel or held == .netherite_shovel or
           held == .wooden_hoe or held == .stone_hoe or held == .golden_hoe or held == .iron_hoe or held == .diamond_hoe or held == .netherite_hoe or held == .shears;
}

pub const MobType = enum { sheep, pig, wolf, emberbeast, wither_skeleton, piglin, piglin_brute, blaze, target_dummy, spider, cave_spider, skeleton, zombie, creeper, enderman, ender_dragon, shulker, endermite, turtle, drowned, phantom, guardian, elder_guardian, dolphin, slime };

pub fn getMobMeatDrop(mob_type: MobType) ItemType {
    return switch (mob_type) {
        .guardian => .prismarine_shard,
        .elder_guardian => .sponge,
        .dolphin => .raw_cod,
        .phantom => .phantom_membrane,
        .drowned => .rotten_flesh,
        .turtle => .scute,
        .shulker => .shulker_shell,
        .endermite => .ender_pearl,
        .pig => .raw_pork,
        .sheep => .raw_mutton,
        .wolf => .none,
        .emberbeast => .coal,
        .wither_skeleton => .coal,
        .piglin, .piglin_brute => .gold_nugget,
        .blaze => .blaze_rod,
        .target_dummy => .hay_bale,
        .spider, .cave_spider => .string,
        .slime => .slimeball,
        .skeleton => .bone,
        .zombie => .rotten_flesh,
        .creeper => .gunpowder,
        .enderman => .ender_pearl,
        .ender_dragon => .end_crystal,
    };
}

pub const BarterReward = struct {
    item: ItemType,
    count: u8,
};

// ponytail: 8-entry Nether bartering table; upgrade with enchanted books/soul speed when enchanting lands.
pub fn getPiglinBarter(seed: u32) BarterReward {
    const roll = seed % 8;
    return switch (roll) {
        0 => .{ .item = .crying_obsidian, .count = 1 },
        1 => .{ .item = .obsidian, .count = 1 },
        2 => .{ .item = .fire_charge, .count = 2 },
        3 => .{ .item = .nether_quartz, .count = 3 },
        4 => .{ .item = .soul_sand, .count = 2 },
        5 => .{ .item = .blackstone, .count = 4 },
        6 => .{ .item = .magma_cream, .count = 1 },
        7 => .{ .item = .nether_brick, .count = 4 },
        else => .{ .item = .blackstone, .count = 2 },
    };
}

/// Bonus ember drops: emberbeasts shed 0-2 nether wart plus coal.
pub fn getEmberBonus(wx: i32, wz: i32) u8 {
    const h: u32 = @as(u32, @bitCast(wx *% 7 +% wz *% 19)) % 3;
    return @as(u8, @intCast(h));
}

/// Rare trophy: wither skeletons drop a skull on ~1-in-8 deterministic kills.
pub fn dropsWitherSkull(wx: i32, wy: i32, wz: i32) bool {
    const h: u32 = @as(u32, @bitCast(wx *% 13 +% wy *% 29 +% wz *% 7)) % 8;
    return h == 0;
}

pub fn dropsSpiderEye(wx: i32, wy: i32, wz: i32) bool {
    // 33% deterministic chance for spider mobs to yield an intact spider eye
    const h: u32 = @as(u32, @bitCast(wx *% 17 +% wy *% 31 +% wz *% 11)) % 3;
    return h == 0;
}

pub fn dropsSkeletonArrow(wx: i32, wy: i32, wz: i32) bool {
    // 50% deterministic chance for skeleton archers to drop reserve arrows
    const h: u32 = @as(u32, @bitCast(wx *% 19 +% wy *% 37 +% wz *% 5)) % 2;
    return h == 0;
}

pub fn dropsDrownedNautilus(wx: i32, wy: i32, wz: i32) bool {
    // 1-in-4 deterministic chance for drowned mob to drop a Nautilus Shell
    const h: u32 = @as(u32, @bitCast(wx *% 43 +% wy *% 29 +% wz *% 53)) % 4;
    return h == 0;
}

pub fn dropsDrownedTrident(wx: i32, wy: i32, wz: i32) bool {
    // Rare trophy: drowned mobs drop a trident on ~1-in-6 deterministic kills
    const h: u32 = @as(u32, @bitCast(wx *% 31 +% wy *% 47 +% wz *% 19)) % 6;
    return h == 0;
}

pub fn dropsEyeShatter(seed: u32) bool {
    // 20% deterministic chance for Eye of Ender to shatter upon flight completion
    return (seed % 5) == 0;
}

pub fn dropsZombieIron(wx: i32, wy: i32, wz: i32) bool {
    // Rare trophy: zombies drop an iron ingot on ~1-in-8 deterministic kills
    const h: u32 = @as(u32, @bitCast(wx *% 23 +% wy *% 41 +% wz *% 13)) % 8;
    return h == 0;
}


test "piglin drops gold nugget and barters nether wares" {
    try std.testing.expectEqual(getMobMeatDrop(.piglin), .gold_nugget);
    var i: u32 = 0;
    while (i < 8) : (i += 1) {
        const reward = getPiglinBarter(i);
        try std.testing.expect(reward.count > 0);
        try std.testing.expect(reward.item != .none);
    }
    try std.testing.expectEqual(getPiglinBarter(0).item, .crying_obsidian);
    try std.testing.expectEqual(getPiglinBarter(1).item, .obsidian);
    try std.testing.expectEqual(getPiglinBarter(2).item, .fire_charge);
}

test "wither skeleton drops skull rarely" {
    var skulls: u32 = 0;
    var x: i32 = 0;
    while (x < 16) : (x += 1) {
        var z: i32 = 0;
        while (z < 16) : (z += 1) {
            if (dropsWitherSkull(x, 7, z)) skulls += 1;
        }
    }
    try std.testing.expect(skulls > 0 and skulls < 128);
    try std.testing.expectEqual(dropsWitherSkull(3, 7, 5), dropsWitherSkull(3, 7, 5));
}

test "emberbeast drops coal plus wart bonus" {
    try std.testing.expectEqual(getMobMeatDrop(.emberbeast), .coal);
    try std.testing.expect(getEmberBonus(0, 0) <= 2);
    // Deterministic per position.
    try std.testing.expectEqual(getEmberBonus(5, 9), getEmberBonus(5, 9));
}

pub const BlockDrop = struct {
    item: ItemType,
    count: u8,
};

pub fn getBlockDrops(block: BlockId, out: []BlockDrop) usize {
    if (block == .gilded_blackstone) {
        out[0] = .{ .item = .blackstone, .count = 1 };
        out[1] = .{ .item = .gold_nugget, .count = 2 };
        return 2;
    } else if (block == .bookshelf) {
        out[0] = .{ .item = .book, .count = 3 };
        return 1;
    } else if (block == .trial_spawner) {
        out[0] = .{ .item = .trial_key, .count = 1 };
        out[1] = .{ .item = .breeze_rod, .count = 2 };
        return 2;
    } else if (block == .ender_chest) {
        out[0] = .{ .item = .obsidian, .count = 8 };
        return 1;
    } else if (block == .sweet_berry_bush) {
        out[0] = .{ .item = .sweet_berries, .count = 2 };
        return 1;
    } else if (block == .clay) {
        out[0] = .{ .item = .clay_ball, .count = 4 };
        return 1;
    } else if (block == .cave_vines_lit) {
        out[0] = .{ .item = .glow_berries, .count = 2 };
        return 1;
    } else if (block == .deepslate) {
        out[0] = .{ .item = .cobbled_deepslate, .count = 1 };
        return 1;
    } else if (block == .cake) {
        return 0;
    } else if (block == .melon) {
        out[0] = .{ .item = .melon_slice, .count = 4 };
        return 1;
    } else if (block == .sculk) {
        out[0] = .{ .item = .sculk, .count = 1 };
        out[1] = .{ .item = .echo_shard, .count = 1 };
        return 2;
    } else if (block == .copper_ore) {
        out[0] = .{ .item = .raw_copper, .count = 2 };
        return 1;
    } else if (block == .amethyst_cluster) {
        out[0] = .{ .item = .amethyst_shard, .count = 4 };
        return 1;
    } else if (block == .tinted_glass) {
        out[0] = .{ .item = .tinted_glass, .count = 1 };
        return 1;
    } else if (block == .lapis_ore) {
        out[0] = .{ .item = .lapis_lazuli, .count = 4 };
        return 1;
    } else if (block == .emerald_ore) {
        out[0] = .{ .item = .emerald, .count = 1 };
        return 1;
    } else if (block == .diamond_ore) {
        out[0] = .{ .item = .diamond, .count = 1 };
        return 1;
    } else if (block == .gold_ore) {
        out[0] = .{ .item = .gold_nugget, .count = 2 };
        return 1;
    } else if (block == .redstone_ore or block == .lit_redstone_ore) {
        out[0] = .{ .item = .redstone_dust, .count = 4 };
        return 1;
    } else if (block == .coal_ore) {
        out[0] = .{ .item = .coal, .count = 1 };
        out[1] = .{ .item = .cobblestone, .count = 1 };
        return 2;
    } else if (block == .snow) {
        out[0] = .{ .item = .snowball, .count = 2 };
        return 1;
    } else if (block == .nether_wart) {
        out[0] = .{ .item = .nether_wart, .count = 2 };
        return 1;
    } else if (block == .cobweb or block == .tripwire) {
        out[0] = .{ .item = .string, .count = 1 };
        return 1;
    } else if (block == .chorus_plant) {
        out[0] = .{ .item = .chorus_fruit, .count = 1 };
        return 1;
    } else if (block == .sea_lantern) {
        out[0] = .{ .item = .prismarine_crystals, .count = 2 };
        out[1] = .{ .item = .prismarine_shard, .count = 1 };
        return 2;
    } else {
        const item = ItemType.fromBlockId(block);
        if (item != .none) {
            out[0] = .{ .item = item, .count = 1 };
            return 1;
        }
        return 0;
    }
}

test "crimson and warped fungi item roundtrip, drops, and crafting recipes" {
    var inv = Inventory.init();
    // Recipe 52: Nether wart + sapling -> 2 crimson fungus
    inv.craft_grid[0] = .{ .item = .nether_wart, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sapling, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .crimson_fungus);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 53: Twisting vines + sapling -> 2 warped fungus
    inv.craft_grid[0] = .{ .item = .twisting_vines, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sapling, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .warped_fungus);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    try std.testing.expectEqual(ItemType.crimson_fungus.toBlockId().?, .crimson_fungus);
    try std.testing.expectEqual(ItemType.fromBlockId(.crimson_fungus), .crimson_fungus);
    try std.testing.expectEqualStrings(ItemType.crimson_fungus.name(), "Crimson Fungus");

    try std.testing.expectEqual(ItemType.warped_fungus.toBlockId().?, .warped_fungus);
    try std.testing.expectEqual(ItemType.fromBlockId(.warped_fungus), .warped_fungus);
    try std.testing.expectEqualStrings(ItemType.warped_fungus.name(), "Warped Fungus");

    var drops: [2]BlockDrop = undefined;
    const n_cr = getBlockDrops(.crimson_fungus, &drops);
    try std.testing.expectEqual(n_cr, 1);
    try std.testing.expectEqual(drops[0].item, .crimson_fungus);
    try std.testing.expectEqual(drops[0].count, 1);

    const n_wa = getBlockDrops(.warped_fungus, &drops);
    try std.testing.expectEqual(n_wa, 1);
    try std.testing.expectEqual(drops[0].item, .warped_fungus);
    try std.testing.expectEqual(drops[0].count, 1);
}

test "hay bale item roundtrip, drops, and crafting recipe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .sapling, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sapling, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .hay_bale);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.hay_bale.toBlockId().?, .hay_bale);
    try std.testing.expectEqual(ItemType.fromBlockId(.hay_bale), .hay_bale);
    try std.testing.expectEqualStrings(ItemType.hay_bale.name(), "Hay Bale");

    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.hay_bale, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .hay_bale);
    try std.testing.expectEqual(drops[0].count, 1);
}

test "target block item roundtrip, drops, and crafting recipe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .target_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.target_block.toBlockId().?, .target_block);
    try std.testing.expectEqual(ItemType.fromBlockId(.target_block), .target_block);
    try std.testing.expectEqualStrings(ItemType.target_block.name(), "Target Block");

    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.target_block, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .target_block);
    try std.testing.expectEqual(drops[0].count, 1);
}

test "twisting vines item roundtrip, drops, and crafting recipe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .weeping_vines, .count = 1 };
    inv.craft_grid[1] = .{ .item = .soul_sand, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .twisting_vines);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    try std.testing.expectEqual(ItemType.twisting_vines.toBlockId().?, .twisting_vines);
    try std.testing.expectEqual(ItemType.fromBlockId(.twisting_vines), .twisting_vines);
    try std.testing.expectEqualStrings(ItemType.twisting_vines.name(), "Twisting Vines");

    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.twisting_vines, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .twisting_vines);
    try std.testing.expectEqual(drops[0].count, 1);
}

test "weeping vines item roundtrip, drops, and crafting recipe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .nether_wart, .count = 1 };
    inv.craft_grid[2] = .{ .item = .nether_wart, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .weeping_vines);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    try std.testing.expectEqual(ItemType.weeping_vines.toBlockId().?, .weeping_vines);
    try std.testing.expectEqual(ItemType.fromBlockId(.weeping_vines), .weeping_vines);
    try std.testing.expectEqualStrings(ItemType.weeping_vines.name(), "Weeping Vines");

    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.weeping_vines, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .weeping_vines);
    try std.testing.expectEqual(drops[0].count, 1);
}

test "gilded blackstone item roundtrip, drops, and gold recipes" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .blackstone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_nugget, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .gilded_blackstone);
    try std.testing.expectEqual(inv.craft_output.count, 1);
    try std.testing.expectEqual(ItemType.gilded_blackstone.toBlockId().?, .gilded_blackstone);
    try std.testing.expectEqual(ItemType.fromBlockId(.gilded_blackstone), .gilded_blackstone);
    try std.testing.expectEqualStrings(ItemType.gilded_blackstone.name(), "Gilded Blackstone");
    try std.testing.expectEqualStrings(ItemType.gold_nugget.name(), "Gold Nugget");

    // Mining drops check: drops blackstone + 2 gold nuggets
    var drops: [4]BlockDrop = undefined;
    const n = getBlockDrops(.gilded_blackstone, &drops);
    try std.testing.expectEqual(n, 2);
    try std.testing.expectEqual(drops[0].item, .blackstone);
    try std.testing.expectEqual(drops[0].count, 1);
    try std.testing.expectEqual(drops[1].item, .gold_nugget);
    try std.testing.expectEqual(drops[1].count, 2);

    // Recipe 47: 2 apples + 2 gold nuggets -> golden apple
    inv.craft_grid[0] = .{ .item = .apple, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[2] = .{ .item = .apple, .count = 1 };
    inv.craft_grid[3] = .{ .item = .gold_nugget, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_apple);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "blackstone item roundtrip and crafting recipe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .basalt, .count = 1 };
    inv.craft_grid[1] = .{ .item = .coal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .blackstone);
    try std.testing.expectEqual(inv.craft_output.count, 2);
    try std.testing.expectEqual(ItemType.blackstone.toBlockId().?, .blackstone);
    try std.testing.expectEqual(ItemType.fromBlockId(.blackstone), .blackstone);
    try std.testing.expectEqualStrings(ItemType.blackstone.name(), "Blackstone");

    // Also craftable with 2 basalt
    inv.craft_grid[1] = .{ .item = .basalt, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .blackstone);
    try std.testing.expectEqual(inv.craft_output.count, 2);
}

test "basalt item roundtrip and crafting recipe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .soul_sand, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .basalt);
    try std.testing.expectEqual(inv.craft_output.count, 2);
    try std.testing.expectEqual(ItemType.basalt.toBlockId().?, .basalt);
    try std.testing.expectEqual(ItemType.fromBlockId(.basalt), .basalt);
    try std.testing.expectEqualStrings(ItemType.basalt.name(), "Basalt");

    // Also craftable with magma
    inv.craft_grid[1] = .{ .item = .magma, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .basalt);
    try std.testing.expectEqual(inv.craft_output.count, 2);
}

test "lodestone item roundtrip and crafting recipe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .netherite_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .chiseled_quartz_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lodestone);
    try std.testing.expectEqual(inv.craft_output.count, 1);
    try std.testing.expectEqual(ItemType.lodestone.toBlockId().?, .lodestone);
    try std.testing.expectEqual(ItemType.fromBlockId(.lodestone), .lodestone);
    try std.testing.expectEqualStrings(ItemType.lodestone.name(), "Lodestone");

    // Also craftable with regular stone
    inv.craft_grid[1] = .{ .item = .stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lodestone);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "crying obsidian item roundtrip and crafting recipe" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .obsidian, .count = 1 };
    inv.craft_grid[1] = .{ .item = .magma_cream, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .crying_obsidian);
    try std.testing.expectEqual(inv.craft_output.count, 1);
    try std.testing.expectEqual(ItemType.crying_obsidian.toBlockId().?, .crying_obsidian);
    try std.testing.expectEqual(ItemType.fromBlockId(.crying_obsidian), .crying_obsidian);
    try std.testing.expectEqualStrings(ItemType.crying_obsidian.name(), "Crying Obsidian");

    // Respawn anchor can also be crafted with crying obsidian
    inv.craft_grid[0] = .{ .item = .crying_obsidian, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glowstone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .glowstone, .count = 1 };
    inv.craft_grid[3] = .{ .item = .crying_obsidian, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .respawn_anchor);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "crafting recipe: respawn anchor from obsidian and glowstone" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .obsidian, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glowstone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .glowstone, .count = 1 };
    inv.craft_grid[3] = .{ .item = .obsidian, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .respawn_anchor);
    try std.testing.expectEqual(inv.craft_output.count, 1);
    try std.testing.expectEqual(ItemType.respawn_anchor.toBlockId().?, .respawn_anchor);
    try std.testing.expectEqual(ItemType.fromBlockId(.respawn_anchor), .respawn_anchor);
    try std.testing.expectEqualStrings(ItemType.respawn_anchor.name(), "Respawn Anchor");
}

test "crafting recipe: netherite sword weapon upgrade" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .iron_sword, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_sword);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    const ns = ItemType.netherite_sword;
    try std.testing.expect(ns.isTool());
    try std.testing.expectEqual(ns.maxDurability(), 400);
    try std.testing.expectEqual(ns.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ns.name(), "Netherite Sword");
}

test "crafting recipes: netherite ingot and netherite pickaxe" {
    var inv = Inventory.init();
    // 2 scraps + 2 iron ingots -> 1 netherite ingot
    inv.craft_grid[0] = .{ .item = .netherite_scrap, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_scrap, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[3] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_ingot);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // 1 iron pickaxe + 1 netherite ingot -> 1 netherite pickaxe
    inv.craft_grid = [_]ItemStack{.{}} ** 4;
    inv.craft_grid[0] = .{ .item = .iron_pickaxe, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_pickaxe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Tool properties
    const np = ItemType.netherite_pickaxe;
    try std.testing.expect(np.isTool());
    try std.testing.expectEqual(np.maxDurability(), 350);
    try std.testing.expectEqual(np.maxStackSize(), 1);
    try std.testing.expect(canHarvestBlock(.netherite_pickaxe, .ancient_debris));
    try std.testing.expect(canHarvestBlock(.netherite_pickaxe, .obsidian));
}

test "ancient debris block and item roundtrip" {
    try std.testing.expectEqual(ItemType.ancient_debris.toBlockId().?, .ancient_debris);
    try std.testing.expectEqual(ItemType.fromBlockId(.ancient_debris), .ancient_debris);
    try std.testing.expectEqual(ItemType.netherite_scrap.toBlockId(), null);
    try std.testing.expectEqualStrings(ItemType.ancient_debris.name(), "Ancient Debris");
    try std.testing.expectEqualStrings(ItemType.netherite_scrap.name(), "Netherite Scrap");
}

test "crafting recipe: beacon from nether star, obsidian, glass" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{ .item = .nether_star, .count = 1 };
    inv.craft_grid[3] = .{ .item = .obsidian, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .beacon);
    try std.testing.expectEqual(inv.craft_output.count, 1);
    try std.testing.expectEqual(ItemType.beacon.toBlockId().?, .beacon);
    try std.testing.expectEqual(ItemType.fromBlockId(.beacon), .beacon);
}

test "getBlockDrops mapping" {
    var drops: [2]BlockDrop = undefined;
    const coal_cnt = getBlockDrops(.coal_ore, &drops);
    try std.testing.expectEqual(@as(usize, 2), coal_cnt);
    try std.testing.expectEqual(ItemType.coal, drops[0].item);
    try std.testing.expectEqual(ItemType.cobblestone, drops[1].item);

    const snow_cnt = getBlockDrops(.snow, &drops);
    try std.testing.expectEqual(@as(usize, 1), snow_cnt);
    try std.testing.expectEqual(ItemType.snowball, drops[0].item);
    try std.testing.expectEqual(@as(u8, 2), drops[0].count);

    const dirt_cnt = getBlockDrops(.dirt, &drops);
    try std.testing.expectEqual(@as(usize, 1), dirt_cnt);
    try std.testing.expectEqual(ItemType.dirt, drops[0].item);

    const air_cnt = getBlockDrops(.air, &drops);
    try std.testing.expectEqual(@as(usize, 0), air_cnt);
}



test "canHarvestBlock tier check" {
    // Hand blocks allow anything
    try std.testing.expect(canHarvestBlock(.dirt, .dirt));
    try std.testing.expect(canHarvestBlock(.none, .wood));

    // Pickaxe tier blocks
    try std.testing.expect(canHarvestBlock(.wooden_pickaxe, .stone));
    try std.testing.expect(canHarvestBlock(.iron_pickaxe, .stone));
    try std.testing.expect(!canHarvestBlock(.dirt, .stone));
    try std.testing.expect(!canHarvestBlock(.none, .iron_ore));
}

test "crafting wooden boat recipe" {
    var inv = Inventory.init();
    // g0=wood_planks, g2=wood_planks, g3=wood_planks, g1=none
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .none, .count = 0 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.boat, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);

    var cursor = ItemStack{};
    _ = inv.takeCraftResult(&cursor);
    try std.testing.expectEqual(ItemType.boat, cursor.item);
    try std.testing.expectEqual(@as(u8, 1), cursor.count);
}

test "nether bricks crafting recipe and item conversion" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .netherrack, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherrack, .count = 1 };
    inv.craft_grid[2] = .{ .item = .netherrack, .count = 1 };
    inv.craft_grid[3] = .{ .item = .netherrack, .count = 1 };
    inv.updateCrafting();

    try std.testing.expectEqual(inv.craft_output.item, .nether_brick);
    try std.testing.expectEqual(inv.craft_output.count, 4);
    try std.testing.expectEqual(inv.craft_output.item.toBlockId(), .nether_brick);

    const b = ItemType.fromBlockId(.nether_brick);
    try std.testing.expectEqual(b, .nether_brick);
    try std.testing.expectEqual(b.name(), "Nether Bricks");
}

test "nether brick fence crafting recipe and item conversion" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .nether_brick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .nether_brick, .count = 1 };
    inv.updateCrafting();

    try std.testing.expectEqual(inv.craft_output.item, .nether_brick_fence);
    try std.testing.expectEqual(inv.craft_output.count, 2);
    try std.testing.expectEqual(inv.craft_output.item.toBlockId(), .nether_brick_fence);

    const f = ItemType.fromBlockId(.nether_brick_fence);
    try std.testing.expectEqual(f, .nether_brick_fence);
    try std.testing.expectEqual(f.name(), "Nether Brick Fence");
}

test "nether wart item conversion and drops" {
    try std.testing.expectEqual(ItemType.fromBlockId(.nether_wart), .nether_wart);
    try std.testing.expectEqual(ItemType.nether_wart.toBlockId(), .nether_wart);
    try std.testing.expectEqualStrings(ItemType.nether_wart.name(), "Nether Wart");

    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.nether_wart, &drops);
    try std.testing.expectEqual(@as(usize, 1), n);
    try std.testing.expectEqual(drops[0].item, .nether_wart);
    try std.testing.expectEqual(drops[0].count, 2);
}

/// Deterministic fortress junction loot roll for world (wx, wz).
pub fn fortressLoot(wx: i32, wz: i32, out: *[4]ItemStack) void {
    const h1: u32 = @as(u32, @bitCast(wx *% 17 +% wz *% 41)) % 3;
    const h2: u32 = @as(u32, @bitCast(wx *% 29 +% wz *% 53)) % 2;
    out[0] = .{ .item = .nether_wart, .count = @as(u8, @intCast(h1 + 2)) };
    out[1] = .{ .item = .nether_quartz, .count = @as(u8, @intCast(h2 + 1)) };
    const h3: u32 = @as(u32, @bitCast(wx *% 11 +% wz *% 67)) % 4;
    if (h3 == 0) {
        out[2] = .{ .item = .iron_ingot, .count = 2 };
    } else {
        out[2] = .{};
    }
        const h4: u32 = @as(u32, @bitCast(wx *% 19 +% wz *% 73)) % 4;
    if (h4 == 0) {
        out[3] = .{ .item = .music_disc_13, .count = 1 };
    } else if (h4 == 1) {
        out[3] = .{ .item = .music_disc_cat, .count = 1 };
    } else {
        out[3] = .{};
    }
}

test "fortress loot is deterministic and wart-weighted" {
    var loot: [4]ItemStack = undefined;
    fortressLoot(23, 24, &loot);
    try std.testing.expectEqual(loot[0].item, .nether_wart);
    try std.testing.expect(loot[0].count >= 2 and loot[0].count <= 4);
    try std.testing.expectEqual(loot[1].item, .nether_quartz);
    var loot2: [4]ItemStack = undefined;
    fortressLoot(23, 24, &loot2);
    try std.testing.expectEqual(loot[0].count, loot2[0].count);
}

test "magma cream recipe and potion brewing" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[1] = .{ .item = .nether_wart, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .magma_cream);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Brew fire resistance from magma cream + glass vial
    inv.craft_grid[0] = .{ .item = .magma_cream, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fire_resistance_potion);
}

test "fire charge recipe from cream and coal" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .magma_cream, .count = 1 };
    inv.craft_grid[0] = .{ .item = .blaze_powder, .count = 1 };
    inv.craft_grid[1] = .{ .item = .coal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fire_charge);
    try std.testing.expectEqual(inv.craft_output.count, 3);
}

test "soul torch crafting recipe and item conversion" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .soul_sand, .count = 1 };
    inv.craft_grid[1] = .{ .item = .torch, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .soul_torch);
    try std.testing.expectEqual(inv.craft_output.count, 2);
    try std.testing.expectEqual(inv.craft_output.item.toBlockId(), .soul_torch);

    const st = ItemType.fromBlockId(.soul_torch);
    try std.testing.expectEqual(st, .soul_torch);
    try std.testing.expectEqualStrings(st.name(), "Soul Torch");
}

test "monster spawner item conversion and name" {
    const it = ItemType.fromBlockId(.spawner_cage);
    try std.testing.expectEqual(it, .spawner_cage);
    try std.testing.expectEqual(ItemType.wither_skull.toBlockId().?, .wither_skull_block);
    try std.testing.expectEqual(ItemType.fromBlockId(.wither_skull_block), .wither_skull);
    try std.testing.expectEqual(it.toBlockId(), .spawner_cage);
    try std.testing.expectEqualStrings(it.name(), "Monster Spawner");
}

test "soul campfire crafting recipe and item conversion" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .soul_sand, .count = 1 };
    inv.craft_grid[1] = .{ .item = .campfire, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .soul_campfire);
    try std.testing.expectEqual(inv.craft_output.count, 1);
    try std.testing.expectEqual(inv.craft_output.item.toBlockId(), .soul_campfire);

    const sc = ItemType.fromBlockId(.soul_campfire);
    try std.testing.expectEqual(sc, .soul_campfire);
    try std.testing.expectEqualStrings(sc.name(), "Soul Campfire");
}

test "shroomlight item roundtrip, drops, and Recipe 54" {
    var inv = Inventory.init();

    // Recipe 54: 1 Glowstone + 1 Crimson Fungus -> 1 Shroomlight
    inv.craft_grid[0] = .{ .item = .glowstone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .crimson_fungus, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .shroomlight);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Warped Fungus
    inv.craft_grid[1] = .{ .item = .warped_fungus, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .shroomlight);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.shroomlight.toBlockId().?, .shroomlight);
    try std.testing.expectEqual(ItemType.fromBlockId(.shroomlight), .shroomlight);
    try std.testing.expectEqualStrings(ItemType.shroomlight.name(), "Shroomlight");

    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.shroomlight, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .shroomlight);
    try std.testing.expectEqual(drops[0].count, 1);
}

test "warped fungus on a stick item properties, durability, and Recipe 55" {
    var inv = Inventory.init();

    // Recipe 55: 1 Stick + 1 Warped Fungus -> 1 Warped Fungus on a Stick
    inv.craft_grid[0] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[1] = .{ .item = .warped_fungus, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .warped_fungus_on_a_stick);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.warped_fungus_on_a_stick.maxDurability(), 100);
    try std.testing.expect(ItemType.warped_fungus_on_a_stick.isTool());
    try std.testing.expectEqual(ItemType.warped_fungus_on_a_stick.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.warped_fungus_on_a_stick.name(), "Warped Fungus on a Stick");
}

test "netherite chestplate item properties, recipe 56, and hasItem" {
    var inv = Inventory.init();

    // Recipe 56: 1 Netherite Ingot + 1 Iron Ingot -> 1 Netherite Chestplate
    inv.craft_grid[0] = .{ .item = .netherite_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_chestplate);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.netherite_chestplate.maxDurability(), 500);
    try std.testing.expect(ItemType.netherite_chestplate.isTool());
    try std.testing.expectEqual(ItemType.netherite_chestplate.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.netherite_chestplate.name(), "Netherite Chestplate");

    // hasItem check
    try std.testing.expect(!inv.hasItem(.netherite_chestplate));
    inv.slots[10] = .{ .item = .netherite_chestplate, .count = 1 };
    try std.testing.expect(inv.hasItem(.netherite_chestplate));
}

test "soul speed boots item properties, durability, and Recipe 57" {
    var inv = Inventory.init();

    // Recipe 57: 1 Iron Ingot + 1 Soul Sand -> 1 Soul Speed Boots
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .soul_sand, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .soul_speed_boots);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Netherite Ingot
    inv.craft_grid[0] = .{ .item = .netherite_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .soul_speed_boots);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.soul_speed_boots.maxDurability(), 300);
    try std.testing.expect(ItemType.soul_speed_boots.isTool());
    try std.testing.expectEqual(ItemType.soul_speed_boots.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.soul_speed_boots.name(), "Soul Speed Boots");
}

test "netherite helmet item properties, durability, and Recipe 58" {
    var inv = Inventory.init();

    // Recipe 58: 1 Netherite Ingot + 1 Coal -> 1 Netherite Helmet
    inv.craft_grid[0] = .{ .item = .netherite_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .coal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_helmet);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Iron Ingot + Netherite Scrap
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_scrap, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_helmet);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.netherite_helmet.maxDurability(), 450);
    try std.testing.expect(ItemType.netherite_helmet.isTool());
    try std.testing.expectEqual(ItemType.netherite_helmet.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.netherite_helmet.name(), "Netherite Helmet");
}

test "netherite leggings item properties, durability, and Recipe 59" {
    var inv = Inventory.init();

    // Recipe 59: 1 Netherite Ingot + 1 Obsidian -> 1 Netherite Leggings
    inv.craft_grid[0] = .{ .item = .netherite_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .obsidian, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_leggings);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with 2 Netherite Scraps
    inv.craft_grid[0] = .{ .item = .netherite_scrap, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_scrap, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_leggings);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.netherite_leggings.maxDurability(), 475);
    try std.testing.expect(ItemType.netherite_leggings.isTool());
    try std.testing.expectEqual(ItemType.netherite_leggings.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.netherite_leggings.name(), "Netherite Leggings");
}

test "chiseled nether brick item roundtrip, drops, and Recipe 60" {
    var inv = Inventory.init();

    // Recipe 60: 2 Nether Bricks -> 1 Chiseled Nether Brick
    inv.craft_grid[0] = .{ .item = .nether_brick, .count = 1 };
    inv.craft_grid[1] = .{ .item = .nether_brick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chiseled_nether_brick);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.chiseled_nether_brick.toBlockId().?, .chiseled_nether_brick);
    try std.testing.expectEqual(ItemType.fromBlockId(.chiseled_nether_brick), .chiseled_nether_brick);
    try std.testing.expectEqualStrings(ItemType.chiseled_nether_brick.name(), "Chiseled Nether Brick");

    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.chiseled_nether_brick, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .chiseled_nether_brick);
    try std.testing.expectEqual(drops[0].count, 1);
}

test "netherite boots item properties, durability, recipe 61, and full set check" {
    var inv = Inventory.init();

    // Recipe 61: 1 Netherite Ingot + 1 Gold Nugget -> 1 Netherite Boots
    inv.craft_grid[0] = .{ .item = .netherite_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_nugget, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_boots);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.netherite_boots.maxDurability(), 425);
    try std.testing.expect(ItemType.netherite_boots.isTool());
    try std.testing.expectEqual(ItemType.netherite_boots.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.netherite_boots.name(), "Netherite Boots");

    // Full set check: helmet + chestplate + leggings + boots
    try std.testing.expect(!inv.hasFullNetheriteSet());
    inv.slots[10] = .{ .item = .netherite_helmet, .count = 1 };
    inv.slots[11] = .{ .item = .netherite_chestplate, .count = 1 };
    inv.slots[12] = .{ .item = .netherite_leggings, .count = 1 };
    try std.testing.expect(!inv.hasFullNetheriteSet());
    inv.slots[13] = .{ .item = .netherite_boots, .count = 1 };
    try std.testing.expect(inv.hasFullNetheriteSet());
}

test "spectral arrow item properties, stack, and Recipe 62" {
    var inv = Inventory.init();

    // Recipe 62: 1 Glowstone + 1 Stick -> 2 Spectral Arrows
    inv.craft_grid[0] = .{ .item = .glowstone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .spectral_arrow);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Alternate: 1 Glowstone + 1 Iron Ingot -> 2 Spectral Arrows
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .spectral_arrow);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    try std.testing.expectEqual(ItemType.spectral_arrow.maxDurability(), 0);
    try std.testing.expect(!ItemType.spectral_arrow.isTool());
    try std.testing.expectEqual(ItemType.spectral_arrow.maxStackSize(), 64);
    try std.testing.expectEqualStrings(ItemType.spectral_arrow.name(), "Spectral Arrow");
    try std.testing.expect(ItemType.spectral_arrow.toBlockId() == null);
}

test "arrow and bow item properties, recipes 63 and 64, and consumeArrow" {
    var inv = Inventory.init();

    // Recipe 63: 1 Stick + 1 Iron Ingot -> 4 Arrows
    inv.craft_grid[0] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .arrow);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Alternate: 1 Stick + 1 Nether Quartz -> 4 Arrows
    inv.craft_grid[1] = .{ .item = .nether_quartz, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .arrow);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 64: 2 Sticks + 1 Wool -> 1 Bow
    inv.craft_grid[0] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wool, .count = 1 };
    inv.craft_grid[3] = .{ .item = .none, .count = 0 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .bow);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Alternate: 2 Sticks + 1 Twisting Vines -> 1 Bow
    inv.craft_grid[2] = .{ .item = .twisting_vines, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .bow);

    // Properties
    try std.testing.expectEqual(ItemType.arrow.maxDurability(), 0);
    try std.testing.expect(!ItemType.arrow.isTool());
    try std.testing.expectEqual(ItemType.arrow.maxStackSize(), 64);
    try std.testing.expectEqualStrings(ItemType.arrow.name(), "Arrow");

    try std.testing.expectEqual(ItemType.bow.maxDurability(), 384);
    try std.testing.expect(ItemType.bow.isTool());
    try std.testing.expectEqual(ItemType.bow.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.bow.name(), "Bow");

    // consumeArrow
    try std.testing.expect(inv.consumeArrow() == null);
    inv.slots[5] = .{ .item = .arrow, .count = 2 };
    try std.testing.expectEqual(inv.consumeArrow(), .arrow);
    try std.testing.expectEqual(inv.slots[5].count, 1);
    inv.slots[4] = .{ .item = .spectral_arrow, .count = 1 };
    try std.testing.expectEqual(inv.consumeArrow(), .spectral_arrow);
    try std.testing.expectEqual(inv.slots[4].count, 0);
}

test "shield item properties, durability, tool check, and Recipe 65" {
    var inv = Inventory.init();

    // Recipe 65 (3-item): 1 Iron Ingot + 2 Wood Planks -> 1 Shield
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .none, .count = 0 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .shield);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 65 (4-item): 1 Iron Ingot + 3 Wood Planks -> 1 Shield
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .shield);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Properties
    try std.testing.expectEqual(ItemType.shield.maxDurability(), 336);
    try std.testing.expect(ItemType.shield.isTool());
    try std.testing.expectEqual(ItemType.shield.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.shield.name(), "Shield");
    try std.testing.expect(ItemType.shield.toBlockId() == null);
}

test "compass and lodestone compass item properties, stack, and Recipe 66" {
    var inv = Inventory.init();

    // Recipe 66: 1 Iron Ingot + 1 Redstone Dust -> 1 Compass
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .redstone_dust, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .compass);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Properties
    try std.testing.expectEqual(ItemType.compass.maxDurability(), 0);
    try std.testing.expect(!ItemType.compass.isTool());
    try std.testing.expectEqual(ItemType.compass.maxStackSize(), 64);
    try std.testing.expectEqualStrings(ItemType.compass.name(), "Compass");
    try std.testing.expect(ItemType.compass.toBlockId() == null);

    try std.testing.expectEqual(ItemType.lodestone_compass.maxDurability(), 0);
    try std.testing.expect(!ItemType.lodestone_compass.isTool());
    try std.testing.expectEqual(ItemType.lodestone_compass.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.lodestone_compass.name(), "Lodestone Compass");
    try std.testing.expect(ItemType.lodestone_compass.toBlockId() == null);
}

test "crossbow item properties, durability, tool check, and Recipe 67" {
    var inv = Inventory.init();

    // Recipe 67: 1 Iron Ingot + 1 Stick + 1 Wool -> 1 Crossbow
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wool, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .crossbow);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 67 with twisting vines
    inv.craft_grid[2] = .{ .item = .twisting_vines, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .crossbow);

    // Properties
    try std.testing.expectEqual(ItemType.crossbow.maxDurability(), 465);
    try std.testing.expect(ItemType.crossbow.isTool());
    try std.testing.expectEqual(ItemType.crossbow.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.crossbow.name(), "Crossbow");
    try std.testing.expect(ItemType.crossbow.toBlockId() == null);
}

test "fireworks_rocket item properties and Recipe 68" {
    var inv = Inventory.init();

    // Recipe 68: 1 Fire Charge + 1 Wool -> 3 Fireworks Rockets
    inv.craft_grid[0] = .{ .item = .fire_charge, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wool, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fireworks_rocket);
    try std.testing.expectEqual(inv.craft_output.count, 3);

    // Recipe 68 with wood planks
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fireworks_rocket);
    try std.testing.expectEqual(inv.craft_output.count, 3);

    // Properties
    try std.testing.expectEqual(ItemType.fireworks_rocket.maxDurability(), 0);
    try std.testing.expect(!ItemType.fireworks_rocket.isTool());
    try std.testing.expectEqual(ItemType.fireworks_rocket.maxStackSize(), 64);
    try std.testing.expectEqualStrings(ItemType.fireworks_rocket.name(), "Fireworks Rocket");
    try std.testing.expect(ItemType.fireworks_rocket.toBlockId() == null);
}

test "consumeCrossbowAmmo priority: rocket > spectral > arrow" {
    var inv = Inventory.init();
    try std.testing.expect(inv.consumeCrossbowAmmo() == null);

    inv.slots[0] = .{ .item = .arrow, .count = 2 };
    inv.slots[1] = .{ .item = .spectral_arrow, .count = 1 };
    inv.slots[2] = .{ .item = .fireworks_rocket, .count = 1 };

    // 1st consumed: fireworks_rocket
    try std.testing.expectEqual(inv.consumeCrossbowAmmo(), .fireworks_rocket);
    // 2nd consumed: spectral_arrow
    try std.testing.expectEqual(inv.consumeCrossbowAmmo(), .spectral_arrow);
    // 3rd consumed: arrow
    try std.testing.expectEqual(inv.consumeCrossbowAmmo(), .arrow);
    try std.testing.expectEqual(inv.consumeCrossbowAmmo(), .arrow);
    try std.testing.expect(inv.consumeCrossbowAmmo() == null);
}

test "dispenser item roundtrip, properties, and Recipe 69" {
    var inv = Inventory.init();

    // Recipe 69: 1 Bow + 1 Redstone Dust + 1 Cobblestone -> 1 Dispenser
    inv.craft_grid[0] = .{ .item = .bow, .count = 1 };
    inv.craft_grid[1] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dispenser);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 69 with crossbow
    inv.craft_grid[0] = .{ .item = .crossbow, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dispenser);

    // Properties
    try std.testing.expectEqual(ItemType.dispenser.toBlockId().?, .dispenser);
    try std.testing.expectEqual(ItemType.fromBlockId(.dispenser), .dispenser);
    try std.testing.expectEqualStrings(ItemType.dispenser.name(), "Dispenser");
    try std.testing.expectEqual(ItemType.dispenser.maxDurability(), 0);
    try std.testing.expect(!ItemType.dispenser.isTool());
    try std.testing.expectEqual(ItemType.dispenser.maxStackSize(), 64);
}

test "dropper item roundtrip, properties, and Recipe 70" {
    var inv = Inventory.init();

    // Recipe 70: 1 Redstone Dust + 2 Cobblestone -> 1 Dropper
    inv.craft_grid[0] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[1] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dropper);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Properties
    try std.testing.expectEqual(ItemType.dropper.toBlockId().?, .dropper);
    try std.testing.expectEqual(ItemType.fromBlockId(.dropper), .dropper);
    try std.testing.expectEqualStrings(ItemType.dropper.name(), "Dropper");
    try std.testing.expectEqual(ItemType.dropper.maxDurability(), 0);
    try std.testing.expect(!ItemType.dropper.isTool());
    try std.testing.expectEqual(ItemType.dropper.maxStackSize(), 64);
}

test "hopper item roundtrip, properties, and Recipe 71" {
    var inv = Inventory.init();

    // Recipe 71: 1 Chest + 1 Iron Ingot -> 1 Hopper
    inv.craft_grid[0] = .{ .item = .chest, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .hopper);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 71 with 2 iron ingots
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .hopper);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Properties
    try std.testing.expectEqual(ItemType.hopper.toBlockId().?, .hopper);
    try std.testing.expectEqual(ItemType.fromBlockId(.hopper), .hopper);
    try std.testing.expectEqualStrings(ItemType.hopper.name(), "Hopper");
    try std.testing.expectEqual(ItemType.hopper.maxDurability(), 0);
    try std.testing.expect(!ItemType.hopper.isTool());
    try std.testing.expectEqual(ItemType.hopper.maxStackSize(), 64);
}

test "blaze mob drops and recipes 72 and 73" {
    try std.testing.expectEqual(ItemType.blaze_rod, getMobMeatDrop(.blaze));
    try std.testing.expectEqualStrings(ItemType.blaze_rod.name(), "Blaze Rod");
    try std.testing.expectEqualStrings(ItemType.blaze_powder.name(), "Blaze Powder");
    try std.testing.expectEqual(ItemType.blaze_rod.maxDurability(), 0);
    try std.testing.expect(!ItemType.blaze_rod.isTool());
    try std.testing.expectEqual(ItemType.blaze_rod.maxStackSize(), 64);

    var inv = Inventory.init();
    // Recipe 72: 1 Blaze Rod -> 2 Blaze Powder
    inv.craft_grid[0] = .{ .item = .blaze_rod, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .blaze_powder);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 73: 1 Blaze Powder + 1 Coal -> 3 Fire Charges
    inv.craft_grid[0] = .{ .item = .blaze_powder, .count = 1 };
    inv.craft_grid[1] = .{ .item = .coal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fire_charge);
    try std.testing.expectEqual(inv.craft_output.count, 3);
}

test "brewing stand item roundtrip, properties, and Recipe 74" {
    var inv = Inventory.init();
    // Recipe 74: 1 Blaze Rod + 1 Cobblestone -> 1 Brewing Stand
    inv.craft_grid[0] = .{ .item = .blaze_rod, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .brewing_stand);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also with 2 cobblestone
    inv.craft_grid[3] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .brewing_stand);

    try std.testing.expectEqual(ItemType.brewing_stand.toBlockId().?, .brewing_stand);
    try std.testing.expectEqual(ItemType.fromBlockId(.brewing_stand), .brewing_stand);
    try std.testing.expectEqualStrings(ItemType.brewing_stand.name(), "Brewing Stand");
    try std.testing.expectEqual(ItemType.brewing_stand.maxDurability(), 0);
    try std.testing.expect(!ItemType.brewing_stand.isTool());
    try std.testing.expectEqual(ItemType.brewing_stand.maxStackSize(), 64);
}

test "cauldron and water bucket item roundtrip, properties, and Recipe 75" {
    var inv = Inventory.init();
    // Recipe 75: 3 Iron Ingots -> 1 Cauldron
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .cauldron);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.cauldron.toBlockId().?, .cauldron);
    try std.testing.expectEqual(ItemType.fromBlockId(.cauldron), .cauldron);
    try std.testing.expectEqualStrings(ItemType.cauldron.name(), "Cauldron");
    try std.testing.expectEqual(ItemType.cauldron.maxDurability(), 0);
    try std.testing.expect(!ItemType.cauldron.isTool());
    try std.testing.expectEqual(ItemType.cauldron.maxStackSize(), 64);

    try std.testing.expectEqual(ItemType.water_bucket.toBlockId().?, .water);
    try std.testing.expectEqualStrings(ItemType.water_bucket.name(), "Water Bucket");
    try std.testing.expectEqual(ItemType.water_bucket.maxStackSize(), 64);
}

test "daylight detector item roundtrip, properties, and Recipe 76" {
    var inv = Inventory.init();
    // Recipe 76: 1 Nether Quartz + 1 Glass + 1 Wood Planks -> 1 Daylight Detector
    inv.craft_grid[0] = .{ .item = .nether_quartz, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .daylight_detector);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.daylight_detector.toBlockId().?, .daylight_detector);
    try std.testing.expectEqual(ItemType.fromBlockId(.daylight_detector), .daylight_detector);
    try std.testing.expectEqual(ItemType.fromBlockId(.daylight_detector_inverted), .daylight_detector);
    try std.testing.expectEqualStrings(ItemType.daylight_detector.name(), "Daylight Detector");
    try std.testing.expectEqual(ItemType.daylight_detector.maxDurability(), 0);
    try std.testing.expect(!ItemType.daylight_detector.isTool());
    try std.testing.expectEqual(ItemType.daylight_detector.maxStackSize(), 64);
}

test "note block item roundtrip, properties, and Recipe 77" {
    var inv = Inventory.init();
    // Recipe 77: 1 Redstone Dust + 2 Wood Planks -> 1 Note Block
    inv.craft_grid[0] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .note_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.note_block.toBlockId().?, .note_block);
    try std.testing.expectEqual(ItemType.fromBlockId(.note_block), .note_block);
    try std.testing.expectEqualStrings(ItemType.note_block.name(), "Note Block");
    try std.testing.expectEqual(ItemType.note_block.maxDurability(), 0);
    try std.testing.expect(!ItemType.note_block.isTool());
    try std.testing.expectEqual(ItemType.note_block.maxStackSize(), 64);
}

test "jukebox and music discs item roundtrip, properties, and Recipes 78, 79, 80" {
    var inv = Inventory.init();
    // Recipe 78: 1 Gold Nugget + 2 Wood Planks -> 1 Jukebox
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .jukebox);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 79: 1 Gold Nugget + 1 Coal -> 1 Music Disc (13)
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[2].clear();
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .music_disc_13);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 80: 1 Warped Fungus + 1 Coal -> 1 Music Disc (cat)
    inv.craft_grid[0] = .{ .item = .warped_fungus, .count = 1 };
    inv.craft_grid[1] = .{ .item = .coal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .music_disc_cat);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.jukebox.toBlockId().?, .jukebox);
    try std.testing.expectEqual(ItemType.fromBlockId(.jukebox), .jukebox);
    try std.testing.expectEqualStrings(ItemType.jukebox.name(), "Jukebox");
    try std.testing.expectEqual(ItemType.jukebox.maxDurability(), 0);
    try std.testing.expect(!ItemType.jukebox.isTool());
    try std.testing.expectEqual(ItemType.jukebox.maxStackSize(), 64);

    try std.testing.expectEqual(ItemType.music_disc_13.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.music_disc_cat.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.music_disc_13.name(), "Music Disc (13)");
    try std.testing.expectEqualStrings(ItemType.music_disc_cat.name(), "Music Disc (cat)");
}

test "oak fence and lead item roundtrip, properties, and Recipes 81 and 82" {
    var inv = Inventory.init();
    // Recipe 81: 2 Wood Planks vertically + 1 Stick -> 2 Oak Fences
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .none, .count = 0 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .oak_fence);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 82: 1 Wool + 1 Stick -> 1 Lead
    inv.craft_grid[0] = .{ .item = .wool, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2].clear();
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lead);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also craftable with weeping vines
    inv.craft_grid[0] = .{ .item = .weeping_vines, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lead);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.oak_fence.toBlockId().?, .oak_fence);
    try std.testing.expectEqual(ItemType.fromBlockId(.oak_fence), .oak_fence);
    try std.testing.expectEqualStrings(ItemType.oak_fence.name(), "Oak Fence");
    try std.testing.expectEqual(ItemType.oak_fence.maxDurability(), 0);
    try std.testing.expect(!ItemType.oak_fence.isTool());
    try std.testing.expectEqual(ItemType.oak_fence.maxStackSize(), 64);

    try std.testing.expectEqual(ItemType.lead.toBlockId(), null);
    try std.testing.expectEqualStrings(ItemType.lead.name(), "Lead");
    try std.testing.expectEqual(ItemType.lead.maxDurability(), 0);
    try std.testing.expect(!ItemType.lead.isTool());
    try std.testing.expectEqual(ItemType.lead.maxStackSize(), 64);
}

test "armor stand item roundtrip, properties, isArmor check, and Recipe 83" {
    var inv = Inventory.init();
    // Recipe 83: 1 Stone + 2 Sticks -> 1 Armor Stand
    inv.craft_grid[0] = .{ .item = .stone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[3].clear();
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .armor_stand);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also craftable with cobblestone
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .armor_stand);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.armor_stand.toBlockId().?, .armor_stand);
    try std.testing.expectEqual(ItemType.fromBlockId(.armor_stand), .armor_stand);
    try std.testing.expectEqualStrings(ItemType.armor_stand.name(), "Armor Stand");
    try std.testing.expectEqual(ItemType.armor_stand.maxDurability(), 0);
    try std.testing.expect(!ItemType.armor_stand.isTool());
    try std.testing.expectEqual(ItemType.armor_stand.maxStackSize(), 16);

    try std.testing.expect(ItemType.netherite_helmet.isArmor());
    try std.testing.expect(ItemType.netherite_chestplate.isArmor());
    try std.testing.expect(ItemType.netherite_leggings.isArmor());
    try std.testing.expect(ItemType.netherite_boots.isArmor());
    try std.testing.expect(ItemType.soul_speed_boots.isArmor());
    try std.testing.expect(!ItemType.iron_sword.isArmor());
    try std.testing.expect(!ItemType.armor_stand.isArmor());
}

test "target dummy item properties, mob drop, and Recipe 84" {
    var inv = Inventory.init();
    // Recipe 84: 1 Hay Bale + 1 Stick + 1 Wood Planks -> 1 Target Dummy
    inv.craft_grid[0] = .{ .item = .hay_bale, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3].clear();
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .target_dummy);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also craftable with wool
    inv.craft_grid[2] = .{ .item = .wool, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .target_dummy);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.target_dummy.toBlockId(), null);
    try std.testing.expectEqualStrings(ItemType.target_dummy.name(), "Target Dummy");
    try std.testing.expectEqual(ItemType.target_dummy.maxDurability(), 0);
    try std.testing.expect(!ItemType.target_dummy.isTool());
    try std.testing.expectEqual(ItemType.target_dummy.maxStackSize(), 16);

    try std.testing.expectEqual(ItemType.hay_bale, getMobMeatDrop(.target_dummy));
}

test "enchantment table item roundtrip, properties, and Recipe 85" {
    var inv = Inventory.init();
    // Recipe 85: 2 Obsidian + 1 Nether Quartz + 1 Wood Planks -> 1 Enchantment Table
    inv.craft_grid[0] = .{ .item = .obsidian, .count = 1 };
    inv.craft_grid[1] = .{ .item = .obsidian, .count = 1 };
    inv.craft_grid[2] = .{ .item = .nether_quartz, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .enchantment_table);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Nether Star & Wool
    inv.craft_grid[2] = .{ .item = .nether_star, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wool, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .enchantment_table);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.enchantment_table.toBlockId().?, .enchantment_table);
    try std.testing.expectEqual(ItemType.fromBlockId(.enchantment_table), .enchantment_table);
    try std.testing.expectEqualStrings(ItemType.enchantment_table.name(), "Enchantment Table");
    try std.testing.expectEqual(ItemType.enchantment_table.maxDurability(), 0);
    try std.testing.expect(!ItemType.enchantment_table.isTool());
    try std.testing.expectEqual(ItemType.enchantment_table.maxStackSize(), 64);
}

test "anvil item roundtrip, properties, and Recipe 86" {
    var inv = Inventory.init();
    // Recipe 86: 3 Iron Ingots + 1 Cobblestone -> 1 Anvil
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[3] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .anvil);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Iron Ore & Stone
    inv.craft_grid[0] = .{ .item = .iron_ore, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .anvil);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.anvil.toBlockId().?, .anvil);
    try std.testing.expectEqual(ItemType.fromBlockId(.anvil), .anvil);
    try std.testing.expectEqualStrings(ItemType.anvil.name(), "Anvil");
    try std.testing.expectEqual(ItemType.anvil.maxDurability(), 0);
    try std.testing.expect(!ItemType.anvil.isTool());
    try std.testing.expectEqual(ItemType.anvil.maxStackSize(), 64);
}

test "grindstone item roundtrip, properties, and Recipe 87" {
    var inv = Inventory.init();
    // Recipe 87: 1 Stone + 2 Sticks + 1 Wood Planks -> 1 Grindstone
    inv.craft_grid[0] = .{ .item = .stone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .grindstone);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Cobblestone or Sandstone
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .grindstone);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.grindstone.toBlockId().?, .grindstone);
    try std.testing.expectEqual(ItemType.fromBlockId(.grindstone), .grindstone);
    try std.testing.expectEqualStrings(ItemType.grindstone.name(), "Grindstone");
    try std.testing.expectEqual(ItemType.grindstone.maxDurability(), 0);
    try std.testing.expect(!ItemType.grindstone.isTool());
    try std.testing.expectEqual(ItemType.grindstone.maxStackSize(), 64);
}

test "smithing table item roundtrip, properties, and Recipe 88" {
    var inv = Inventory.init();
    // Recipe 88: 2 Iron Ingots + 2 Wood Planks -> 1 Smithing Table
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .smithing_table);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Iron Ore
    inv.craft_grid[0] = .{ .item = .iron_ore, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .smithing_table);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.smithing_table.toBlockId().?, .smithing_table);
    try std.testing.expectEqual(ItemType.fromBlockId(.smithing_table), .smithing_table);
    try std.testing.expectEqualStrings(ItemType.smithing_table.name(), "Smithing Table");
    try std.testing.expectEqual(ItemType.smithing_table.maxDurability(), 0);
    try std.testing.expect(!ItemType.smithing_table.isTool());
    try std.testing.expectEqual(ItemType.smithing_table.maxStackSize(), 64);
}

test "cartography table item roundtrip, properties, and Recipe 89" {
    var inv = Inventory.init();
    // Recipe 89: 1 Compass + 1 Wood Planks + 2 Sticks -> 1 Cartography Table
    inv.craft_grid[0] = .{ .item = .compass, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .cartography_table);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Redstone Dust & 1 Stick
    inv.craft_grid = [_]ItemStack{.{}} ** 4;
    inv.craft_grid[0] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .cartography_table);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.cartography_table.toBlockId().?, .cartography_table);
    try std.testing.expectEqual(ItemType.fromBlockId(.cartography_table), .cartography_table);
    try std.testing.expectEqualStrings(ItemType.cartography_table.name(), "Cartography Table");
    try std.testing.expectEqual(ItemType.cartography_table.maxDurability(), 0);
    try std.testing.expect(!ItemType.cartography_table.isTool());
    try std.testing.expectEqual(ItemType.cartography_table.maxStackSize(), 64);
}

test "fletching table item roundtrip, properties, and Recipe 90" {
    var inv = Inventory.init();
    // Recipe 90: 2 Sticks + 2 Wood Planks -> 1 Fletching Table
    inv.craft_grid[0] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fletching_table);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Coal
    inv.craft_grid[0] = .{ .item = .coal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fletching_table);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.fletching_table.toBlockId().?, .fletching_table);
    try std.testing.expectEqual(ItemType.fromBlockId(.fletching_table), .fletching_table);
    try std.testing.expectEqualStrings(ItemType.fletching_table.name(), "Fletching Table");
    try std.testing.expectEqual(ItemType.fletching_table.maxDurability(), 0);
    try std.testing.expect(!ItemType.fletching_table.isTool());
    try std.testing.expectEqual(ItemType.fletching_table.maxStackSize(), 64);
}

test "composter and bone meal item roundtrip, compostable check, and Recipe 91" {
    var inv = Inventory.init();
    // Recipe 91: 3 Wood Planks + 1 Stick -> 1 Composter
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .composter);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.composter.toBlockId().?, .composter);
    try std.testing.expectEqual(ItemType.fromBlockId(.composter), .composter);
    try std.testing.expectEqual(ItemType.bone_meal.toBlockId(), null);
    try std.testing.expectEqualStrings(ItemType.composter.name(), "Composter");
    try std.testing.expectEqualStrings(ItemType.bone_meal.name(), "Bone Meal");
    try std.testing.expect(ItemType.leaves.isCompostable());
    try std.testing.expect(ItemType.nether_wart.isCompostable());
    try std.testing.expect(!ItemType.stone.isCompostable());
    try std.testing.expectEqual(ItemType.bone_meal.maxStackSize(), 64);
}

test "loom item roundtrip, properties, and Recipe 92" {
    var inv = Inventory.init();
    // Recipe 92: 2 Wool + 2 Wood Planks -> 1 Loom
    inv.craft_grid[0] = .{ .item = .wool, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wool, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .loom);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Weeping Vines
    inv.craft_grid[0] = .{ .item = .weeping_vines, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .loom);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.loom.toBlockId().?, .loom);
    try std.testing.expectEqual(ItemType.fromBlockId(.loom), .loom);
    try std.testing.expectEqualStrings(ItemType.loom.name(), "Loom");
    try std.testing.expectEqual(ItemType.loom.maxDurability(), 0);
    try std.testing.expect(!ItemType.loom.isTool());
    try std.testing.expectEqual(ItemType.loom.maxStackSize(), 64);
}

test "cobweb item roundtrip, drops, and Recipe 102" {
    var inv = Inventory.init();
    // Recipe 102: 4 Strings -> 1 Cobweb
    inv.craft_grid[0] = .{ .item = .string, .count = 1 };
    inv.craft_grid[1] = .{ .item = .string, .count = 1 };
    inv.craft_grid[2] = .{ .item = .string, .count = 1 };
    inv.craft_grid[3] = .{ .item = .string, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .cobweb);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.cobweb.toBlockId().?, .cobweb);
    try std.testing.expectEqual(ItemType.fromBlockId(.cobweb), .cobweb);
    try std.testing.expectEqualStrings(ItemType.cobweb.name(), "Cobweb");
    try std.testing.expectEqual(ItemType.cobweb.maxDurability(), 0);
    try std.testing.expect(!ItemType.cobweb.isTool());
    try std.testing.expectEqual(ItemType.cobweb.maxStackSize(), 64);

    var drops: [4]BlockDrop = undefined;
    const n = getBlockDrops(.cobweb, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .string);
    try std.testing.expectEqual(drops[0].count, 1);
}

test "string item roundtrip, properties, and Recipe 101" {
    var inv = Inventory.init();
    // Recipe 101: 1 Wool -> 4 Strings
    inv.craft_grid[0] = .{ .item = .wool, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .string);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Alternative: 1 Weeping Vines -> 4 Strings
    inv.craft_grid[0] = .{ .item = .weeping_vines, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .string);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    try std.testing.expectEqual(ItemType.string.toBlockId().?, .tripwire);
    try std.testing.expectEqual(ItemType.fromBlockId(.tripwire), .string);
    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(@as(usize, 1), getBlockDrops(.tripwire, &drops));
    try std.testing.expectEqual(drops[0].item, .string);
    try std.testing.expectEqualStrings(ItemType.string.name(), "String");
    try std.testing.expectEqual(ItemType.string.maxDurability(), 0);
    try std.testing.expect(!ItemType.string.isTool());
    try std.testing.expectEqual(ItemType.string.maxStackSize(), 64);
}

test "tripwire hook item roundtrip, properties, and Recipe 100" {
    var inv = Inventory.init();
    // Recipe 100: 1 Iron Ingot + 1 Stick + 1 Wood Planks -> 2 Tripwire Hooks
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .tripwire_hook);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    try std.testing.expectEqual(ItemType.tripwire_hook.toBlockId().?, .tripwire_hook_off);
    try std.testing.expectEqual(ItemType.fromBlockId(.tripwire_hook_off), .tripwire_hook);
    try std.testing.expectEqual(ItemType.fromBlockId(.tripwire_hook_on), .tripwire_hook);
    try std.testing.expectEqualStrings(ItemType.tripwire_hook.name(), "Tripwire Hook");
    try std.testing.expectEqual(ItemType.tripwire_hook.maxDurability(), 0);
    try std.testing.expect(!ItemType.tripwire_hook.isTool());
    try std.testing.expectEqual(ItemType.tripwire_hook.maxStackSize(), 64);
}

test "iron_bars item roundtrip, properties, and Recipe 99" {
    var inv = Inventory.init();
    // Recipe 99: 2 Iron Ingots + 1 Cobblestone -> 4 Iron Bars
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_bars);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Alternative: 2 Iron Ingots + 1 Sandstone -> 4 Iron Bars
    inv.craft_grid[2] = .{ .item = .sandstone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_bars);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    try std.testing.expectEqual(ItemType.iron_bars.toBlockId().?, .iron_bars);
    try std.testing.expectEqual(ItemType.fromBlockId(.iron_bars), .iron_bars);
    try std.testing.expectEqualStrings(ItemType.iron_bars.name(), "Iron Bars");
    try std.testing.expectEqual(ItemType.iron_bars.maxDurability(), 0);
    try std.testing.expect(!ItemType.iron_bars.isTool());
    try std.testing.expectEqual(ItemType.iron_bars.maxStackSize(), 64);
}

test "chain item roundtrip, properties, and Recipe 98" {
    var inv = Inventory.init();
    // Recipe 98: 1 Iron Ingot + 1 Iron Ore -> 2 Chains
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ore, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chain);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Alternative: 1 Iron Ingot + 2 Iron Ore -> 2 Chains
    inv.craft_grid[2] = .{ .item = .iron_ore, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chain);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    try std.testing.expectEqual(ItemType.chain.toBlockId().?, .chain);
    try std.testing.expectEqual(ItemType.fromBlockId(.chain), .chain);
    try std.testing.expectEqualStrings(ItemType.chain.name(), "Chain");
    try std.testing.expectEqual(ItemType.chain.maxDurability(), 0);
    try std.testing.expect(!ItemType.chain.isTool());
    try std.testing.expectEqual(ItemType.chain.maxStackSize(), 64);
}

test "soul_lantern item roundtrip, properties, and Recipe 97" {
    var inv = Inventory.init();
    // Recipe 97: 1 Soul Torch + 1 Iron Ingot -> 1 Soul Lantern
    inv.craft_grid[0] = .{ .item = .soul_torch, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .soul_lantern);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Alternative: 1 Soul Torch + 2 Iron Ore
    inv.craft_grid[1] = .{ .item = .iron_ore, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ore, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .soul_lantern);

    try std.testing.expectEqual(ItemType.soul_lantern.toBlockId().?, .soul_lantern);
    try std.testing.expectEqual(ItemType.fromBlockId(.soul_lantern), .soul_lantern);
    try std.testing.expectEqualStrings(ItemType.soul_lantern.name(), "Soul Lantern");
    try std.testing.expectEqual(ItemType.soul_lantern.maxDurability(), 0);
    try std.testing.expect(!ItemType.soul_lantern.isTool());
    try std.testing.expectEqual(ItemType.soul_lantern.maxStackSize(), 64);
}

test "lantern item roundtrip, properties, and Recipe 96" {
    var inv = Inventory.init();
    // Recipe 96: 1 Torch + 1 Iron Ingot -> 1 Lantern
    inv.craft_grid[0] = .{ .item = .torch, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lantern);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Alternative: 1 Torch + 2 Iron Ore
    inv.craft_grid[1] = .{ .item = .iron_ore, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ore, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lantern);

    try std.testing.expectEqual(ItemType.lantern.toBlockId().?, .lantern);
    try std.testing.expectEqual(ItemType.fromBlockId(.lantern), .lantern);
    try std.testing.expectEqualStrings(ItemType.lantern.name(), "Lantern");
    try std.testing.expectEqual(ItemType.lantern.maxDurability(), 0);
    try std.testing.expect(!ItemType.lantern.isTool());
    try std.testing.expectEqual(ItemType.lantern.maxStackSize(), 64);
}

test "stonecutter item roundtrip, properties, and Recipe 95" {
    var inv = Inventory.init();
    // Recipe 95: 1 Iron Ingot + 1 Stone -> 1 Stonecutter
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stonecutter);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Alternative: 1 Iron Ingot + 2 Cobblestone
    inv.craft_grid[1] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stonecutter);

    try std.testing.expectEqual(ItemType.stonecutter.toBlockId().?, .stonecutter);
    try std.testing.expectEqual(ItemType.fromBlockId(.stonecutter), .stonecutter);
    try std.testing.expectEqualStrings(ItemType.stonecutter.name(), "Stonecutter");
    try std.testing.expectEqual(ItemType.stonecutter.maxDurability(), 0);
    try std.testing.expect(!ItemType.stonecutter.isTool());
    try std.testing.expectEqual(ItemType.stonecutter.maxStackSize(), 64);
}

test "blast_furnace item roundtrip, properties, and Recipe 94" {
    var inv = Inventory.init();
    // Recipe 94: 1 Furnace + 1 Iron Ingot + 1 Stone -> 1 Blast Furnace
    inv.craft_grid[0] = .{ .item = .furnace, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .blast_furnace);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Alternative: 1 Furnace + 1 Iron Ore + 1 Cobblestone
    inv.craft_grid[1] = .{ .item = .iron_ore, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cobblestone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .blast_furnace);

    try std.testing.expectEqual(ItemType.blast_furnace.toBlockId().?, .blast_furnace);
    try std.testing.expectEqual(ItemType.fromBlockId(.blast_furnace), .blast_furnace);
    try std.testing.expectEqualStrings(ItemType.blast_furnace.name(), "Blast Furnace");
    try std.testing.expectEqual(ItemType.blast_furnace.maxDurability(), 0);
    try std.testing.expect(!ItemType.blast_furnace.isTool());
    try std.testing.expectEqual(ItemType.blast_furnace.maxStackSize(), 64);
}

test "smoker item roundtrip, properties, and Recipe 93" {
    var inv = Inventory.init();
    // Recipe 93: 1 Furnace + 1 Wood Planks -> 1 Smoker
    inv.craft_grid[0] = .{ .item = .furnace, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .smoker);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with Wood Log
    inv.craft_grid[1] = .{ .item = .wood, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .smoker);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.smoker.toBlockId().?, .smoker);
    try std.testing.expectEqual(ItemType.fromBlockId(.smoker), .smoker);
    try std.testing.expectEqualStrings(ItemType.smoker.name(), "Smoker");
    try std.testing.expectEqual(ItemType.smoker.maxDurability(), 0);
    try std.testing.expect(!ItemType.smoker.isTool());
    try std.testing.expectEqual(ItemType.smoker.maxStackSize(), 64);
}

test "spider eye item properties and drop probability" {
    try std.testing.expectEqualStrings(ItemType.spider_eye.name(), "Spider Eye");
    try std.testing.expectEqual(ItemType.spider_eye.maxDurability(), 0);
    try std.testing.expect(!ItemType.spider_eye.isTool());
    try std.testing.expectEqual(ItemType.spider_eye.maxStackSize(), 64);
    try std.testing.expect(ItemType.spider_eye.toBlockId() == null);

    var eyes: usize = 0;
    var x: i32 = 0;
    while (x < 30) : (x += 1) {
        if (dropsSpiderEye(x, 1, 0)) eyes += 1;
    }
    try std.testing.expect(eyes > 0 and eyes < 30);
    try std.testing.expectEqual(dropsSpiderEye(5, 2, 7), dropsSpiderEye(5, 2, 7));
}

test "poison potion recipe and item properties" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .spider_eye, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .poison_potion);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    inv.craft_grid[1] = .{ .item = .nether_wart, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .poison_potion);

    try std.testing.expectEqualStrings(ItemType.poison_potion.name(), "Potion of Poison");
    try std.testing.expect(!ItemType.poison_potion.isTool());
    try std.testing.expect(ItemType.poison_potion.toBlockId() == null);
}

test "fermented spider eye and weakness potion recipes and properties" {
    var inv = Inventory.init();
    // Recipe 104: Spider eye + crimson fungus -> fermented spider eye
    inv.craft_grid[0] = .{ .item = .spider_eye, .count = 1 };
    inv.craft_grid[1] = .{ .item = .crimson_fungus, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fermented_spider_eye);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Also works with apple
    inv.craft_grid[1] = .{ .item = .apple, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .fermented_spider_eye);

    // Recipe 105: Fermented spider eye + glass vial -> weakness potion
    inv.craft_grid[0] = .{ .item = .fermented_spider_eye, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .weakness_potion);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqualStrings(ItemType.fermented_spider_eye.name(), "Fermented Spider Eye");
    try std.testing.expect(!ItemType.fermented_spider_eye.isTool());
    try std.testing.expect(ItemType.fermented_spider_eye.toBlockId() == null);

    try std.testing.expectEqualStrings(ItemType.weakness_potion.name(), "Potion of Weakness");
    try std.testing.expect(!ItemType.weakness_potion.isTool());
    try std.testing.expect(ItemType.weakness_potion.toBlockId() == null);
}

test "skeleton mob drop, bone item, and Recipe 106 bone meal" {
    try std.testing.expectEqual(getMobMeatDrop(.skeleton), .bone);
    try std.testing.expectEqualStrings(ItemType.bone.name(), "Bone");
    try std.testing.expect(!ItemType.bone.isTool());
    try std.testing.expect(ItemType.bone.toBlockId() == null);
    try std.testing.expectEqual(ItemType.bone.maxStackSize(), 64);

    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .bone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .bone_meal);
    try std.testing.expectEqual(inv.craft_output.count, 3);

    var arrow_drops: usize = 0;
    var x: i32 = 0;
    while (x < 20) : (x += 1) {
        if (dropsSkeletonArrow(x, 2, 5)) arrow_drops += 1;
    }
    try std.testing.expect(arrow_drops > 0 and arrow_drops < 20);
    try std.testing.expectEqual(dropsSkeletonArrow(3, 4, 5), dropsSkeletonArrow(3, 4, 5));
}

test "zombie mob drop, rotten flesh item, and rare iron ingot drop" {
    try std.testing.expectEqual(getMobMeatDrop(.zombie), .rotten_flesh);
    try std.testing.expectEqualStrings(ItemType.rotten_flesh.name(), "Rotten Flesh");
    try std.testing.expect(!ItemType.rotten_flesh.isTool());
    try std.testing.expect(ItemType.rotten_flesh.toBlockId() == null);
    try std.testing.expectEqual(ItemType.rotten_flesh.maxStackSize(), 64);
    try std.testing.expect(ItemType.rotten_flesh.isCompostable());

    var iron_drops: usize = 0;
    var x: i32 = 0;
    while (x < 64) : (x += 1) {
        if (dropsZombieIron(x, 2, 5)) iron_drops += 1;
    }
    try std.testing.expect(iron_drops > 0 and iron_drops < 64);
    try std.testing.expectEqual(dropsZombieIron(7, 3, 11), dropsZombieIron(7, 3, 11));
}

test "creeper mob drop, gunpowder item, and Recipe 107 TNT crafting" {
    try std.testing.expectEqual(getMobMeatDrop(.creeper), .gunpowder);
    try std.testing.expectEqualStrings(ItemType.gunpowder.name(), "Gunpowder");
    try std.testing.expect(!ItemType.gunpowder.isTool());
    try std.testing.expect(ItemType.gunpowder.toBlockId() == null);
    try std.testing.expectEqual(ItemType.gunpowder.maxStackSize(), 64);

    var inv = Inventory.init();
    // 2-ingredient TNT recipe: 1 Sand + 1 Gunpowder -> 1 TNT
    inv.craft_grid[0] = .{ .item = .sand, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gunpowder, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .tnt);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // 4-ingredient checkerboard TNT recipe: 2 Sand + 2 Gunpowder -> 1 TNT
    inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .sand, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gunpowder, .count = 1 };
    inv.craft_grid[2] = .{ .item = .gunpowder, .count = 1 };
    inv.craft_grid[3] = .{ .item = .sand, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .tnt);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "enderman mob drop, ender pearl item properties, and stack cap" {
    try std.testing.expectEqual(getMobMeatDrop(.enderman), .ender_pearl);
    try std.testing.expectEqualStrings(ItemType.ender_pearl.name(), "Ender Pearl");
    try std.testing.expect(!ItemType.ender_pearl.isTool());
    try std.testing.expect(ItemType.ender_pearl.toBlockId() == null);
    try std.testing.expectEqual(ItemType.ender_pearl.maxStackSize(), 16);
}

test "eye of ender item properties, Recipe 108 crafting, and shatter probability" {
    try std.testing.expectEqualStrings(ItemType.eye_of_ender.name(), "Eye of Ender");
    try std.testing.expect(!ItemType.eye_of_ender.isTool());
    try std.testing.expect(ItemType.eye_of_ender.toBlockId() == null);
    try std.testing.expectEqual(ItemType.eye_of_ender.maxStackSize(), 64);

    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .ender_pearl, .count = 1 };
    inv.craft_grid[1] = .{ .item = .blaze_powder, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .eye_of_ender);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    var shatters: usize = 0;
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        if (dropsEyeShatter(i)) shatters += 1;
    }
    try std.testing.expectEqual(@as(usize, 20), shatters);
}

test "end stone and end portal frame item roundtrip, properties, and Recipes 109 and 110" {
    try std.testing.expectEqual(ItemType.fromBlockId(.end_stone), .end_stone);
    try std.testing.expectEqual(ItemType.fromBlockId(.end_portal_frame), .end_portal_frame);
    try std.testing.expectEqual(ItemType.fromBlockId(.end_portal_frame_filled), .end_portal_frame);
    try std.testing.expectEqual(ItemType.end_stone.toBlockId(), .end_stone);
    try std.testing.expectEqual(ItemType.end_portal_frame.toBlockId(), .end_portal_frame);
    try std.testing.expectEqualStrings(ItemType.end_stone.name(), "End Stone");
    try std.testing.expectEqualStrings(ItemType.end_portal_frame.name(), "End Portal Frame");

    var inv = Inventory.init();
    // Recipe 109: 1 Cobblestone + 1 Sandstone -> 2 End Stone
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sandstone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .end_stone);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 110: 3 End Stone + 1 Ender Pearl -> 1 End Portal Frame
    inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .end_stone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .end_stone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .end_stone, .count = 1 };
    inv.craft_grid[3] = .{ .item = .ender_pearl, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .end_portal_frame);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "end crystal item roundtrip and Recipe 111" {
    try std.testing.expectEqual(ItemType.fromBlockId(.end_crystal), .end_crystal);
    try std.testing.expectEqual(ItemType.end_crystal.toBlockId(), .end_crystal);
    try std.testing.expectEqualStrings(ItemType.end_crystal.name(), "End Crystal");

    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{ .item = .eye_of_ender, .count = 1 };
    inv.craft_grid[3] = .{ .item = .blaze_powder, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .end_crystal);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "dragon egg item roundtrip, drops, and properties" {
    try std.testing.expectEqual(ItemType.fromBlockId(.dragon_egg), .dragon_egg);
    try std.testing.expectEqual(ItemType.dragon_egg.toBlockId(), .dragon_egg);
    try std.testing.expectEqualStrings(ItemType.dragon_egg.name(), "Dragon Egg");

    var drops_buf: [2]BlockDrop = undefined;
    const n = getBlockDrops(.dragon_egg, &drops_buf);
    try std.testing.expectEqual(@as(usize, 1), n);
    try std.testing.expectEqual(drops_buf[0].item, .dragon_egg);
    try std.testing.expectEqual(drops_buf[0].count, 1);
}

test "purpur and end rod item roundtrip, drops, and recipes 112-114" {
    var inv = Inventory.init();

    // Recipe 112: 4 End Stone -> 4 Purpur Blocks
    inv.craft_grid[0] = .{ .item = .end_stone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .end_stone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .end_stone, .count = 1 };
    inv.craft_grid[3] = .{ .item = .end_stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .purpur_block);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 113: 2 Purpur Blocks -> 2 Purpur Pillars
    inv.craft_grid[1] = .{ .item = .none, .count = 0 };
    inv.craft_grid[3] = .{ .item = .none, .count = 0 };
    inv.craft_grid[0] = .{ .item = .purpur_block, .count = 1 };
    inv.craft_grid[2] = .{ .item = .purpur_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .purpur_pillar);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 114: 1 Blaze Rod + 1 Ender Pearl -> 4 End Rods
    inv.craft_grid[0] = .{ .item = .blaze_rod, .count = 1 };
    inv.craft_grid[2] = .{ .item = .ender_pearl, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .end_rod);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Roundtrips & names
    try std.testing.expectEqual(ItemType.fromBlockId(.purpur_block), .purpur_block);
    try std.testing.expectEqual(ItemType.purpur_block.toBlockId().?, .purpur_block);
    try std.testing.expectEqualStrings(ItemType.purpur_block.name(), "Purpur Block");

    try std.testing.expectEqual(ItemType.fromBlockId(.purpur_pillar), .purpur_pillar);
    try std.testing.expectEqual(ItemType.purpur_pillar.toBlockId().?, .purpur_pillar);
    try std.testing.expectEqualStrings(ItemType.purpur_pillar.name(), "Purpur Pillar");

    try std.testing.expectEqual(ItemType.fromBlockId(.end_rod), .end_rod);
    try std.testing.expectEqual(ItemType.end_rod.toBlockId().?, .end_rod);
    try std.testing.expectEqualStrings(ItemType.end_rod.name(), "End Rod");

    // Drops
    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(@as(usize, 1), getBlockDrops(.purpur_block, &drops));
    try std.testing.expectEqual(drops[0].item, .purpur_block);

    try std.testing.expectEqual(@as(usize, 1), getBlockDrops(.purpur_pillar, &drops));
    try std.testing.expectEqual(drops[0].item, .purpur_pillar);

    try std.testing.expectEqual(@as(usize, 1), getBlockDrops(.end_rod, &drops));
    try std.testing.expectEqual(drops[0].item, .end_rod);
}

test "chorus fruit item roundtrip, drops, and recipes 115-117" {
    var inv = Inventory.init();

    // Recipe 117: Chorus fruit + coal -> popped chorus fruit
    inv.craft_grid[0] = .{ .item = .chorus_fruit, .count = 1 };
    inv.craft_grid[1] = .{ .item = .coal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .popped_chorus_fruit);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 115: 4 popped chorus fruit -> 4 purpur blocks
    inv.craft_grid[0] = .{ .item = .popped_chorus_fruit, .count = 1 };
    inv.craft_grid[1] = .{ .item = .popped_chorus_fruit, .count = 1 };
    inv.craft_grid[2] = .{ .item = .popped_chorus_fruit, .count = 1 };
    inv.craft_grid[3] = .{ .item = .popped_chorus_fruit, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .purpur_block);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 116: Blaze rod + popped chorus fruit -> 4 end rods
    inv.craft_grid[1] = .{ .item = .none, .count = 0 };
    inv.craft_grid[2] = .{ .item = .none, .count = 0 };
    inv.craft_grid[3] = .{ .item = .none, .count = 0 };
    inv.craft_grid[0] = .{ .item = .blaze_rod, .count = 1 };
    inv.craft_grid[1] = .{ .item = .popped_chorus_fruit, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .end_rod);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Roundtrips & names
    try std.testing.expectEqual(ItemType.fromBlockId(.chorus_plant), .chorus_plant);
    try std.testing.expectEqual(ItemType.chorus_plant.toBlockId().?, .chorus_plant);
    try std.testing.expectEqualStrings(ItemType.chorus_plant.name(), "Chorus Plant");

    try std.testing.expectEqual(ItemType.fromBlockId(.chorus_flower), .chorus_flower);
    try std.testing.expectEqual(ItemType.chorus_flower.toBlockId().?, .chorus_flower);
    try std.testing.expectEqualStrings(ItemType.chorus_flower.name(), "Chorus Flower");

    try std.testing.expectEqualStrings(ItemType.chorus_fruit.name(), "Chorus Fruit");
    try std.testing.expectEqualStrings(ItemType.popped_chorus_fruit.name(), "Popped Chorus Fruit");

    // Drops: chorus_plant drops chorus_fruit; chorus_flower drops chorus_flower
    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(@as(usize, 1), getBlockDrops(.chorus_plant, &drops));
    try std.testing.expectEqual(drops[0].item, .chorus_fruit);

    try std.testing.expectEqual(@as(usize, 1), getBlockDrops(.chorus_flower, &drops));
    try std.testing.expectEqual(drops[0].item, .chorus_flower);
}

test "shulker shell and shulker box item roundtrip, mob drop, and Recipe 118" {
    var inv = Inventory.init();

    // Recipe 118: 1 Chest + 2 Shulker Shells -> 1 Shulker Box
    inv.craft_grid[0] = .{ .item = .shulker_shell, .count = 1 };
    inv.craft_grid[1] = .{ .item = .chest, .count = 1 };
    inv.craft_grid[2] = .{ .item = .shulker_shell, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .shulker_box);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Roundtrip and names
    try std.testing.expectEqual(ItemType.fromBlockId(.shulker_box), .shulker_box);
    try std.testing.expectEqual(ItemType.shulker_box.toBlockId().?, .shulker_box);
    try std.testing.expectEqualStrings(ItemType.shulker_box.name(), "Shulker Box");
    try std.testing.expectEqualStrings(ItemType.shulker_shell.name(), "Shulker Shell");

    // Mob drop
    try std.testing.expectEqual(getMobMeatDrop(.shulker), .shulker_shell);

    // Block drops
    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(@as(usize, 1), getBlockDrops(.shulker_box, &drops));
    try std.testing.expectEqual(drops[0].item, .shulker_box);
}

test "elytra item properties, wearable armor check, and Recipe 119" {
    var inv = Inventory.init();

    // Recipe 119: 2 Shulker Shells + 2 Purpur Blocks -> 1 Elytra
    inv.craft_grid[0] = .{ .item = .shulker_shell, .count = 1 };
    inv.craft_grid[1] = .{ .item = .purpur_block, .count = 1 };
    inv.craft_grid[2] = .{ .item = .purpur_block, .count = 1 };
    inv.craft_grid[3] = .{ .item = .shulker_shell, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .elytra);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expect(ItemType.elytra.isArmor());
    try std.testing.expect(ItemType.elytra.isTool());
    try std.testing.expectEqual(ItemType.elytra.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.elytra.maxDurability(), 432);
    try std.testing.expectEqualStrings(ItemType.elytra.name(), "Elytra");
    try std.testing.expect(ItemType.elytra.toBlockId() == null);
}

test "dragon head item roundtrip, properties, wearable armor check, and Recipe 120" {
    var inv = Inventory.init();

    // Recipe 120: 1 Dragon Egg + 1 Wither Skull -> 1 Dragon Head
    inv.craft_grid[0] = .{ .item = .dragon_egg, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wither_skull, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dragon_head);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expect(ItemType.dragon_head.isArmor());
    try std.testing.expect(!ItemType.dragon_head.isTool());
    try std.testing.expectEqual(ItemType.dragon_head.maxStackSize(), 16);
    try std.testing.expectEqualStrings(ItemType.dragon_head.name(), "Dragon Head");
    try std.testing.expectEqual(ItemType.dragon_head.toBlockId().?, .dragon_head);
    try std.testing.expectEqual(ItemType.fromBlockId(.dragon_head), .dragon_head);
}

test "end gateway item roundtrip, properties, and Recipe 121" {
    var inv = Inventory.init();

    // Recipe 121: 1 Dragon Head + 1 End Crystal -> 1 End Gateway
    inv.craft_grid[0] = .{ .item = .dragon_head, .count = 1 };
    inv.craft_grid[1] = .{ .item = .end_crystal, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .end_gateway);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqualStrings(ItemType.end_gateway.name(), "End Gateway");
    try std.testing.expectEqual(ItemType.end_gateway.toBlockId().?, .end_gateway);
    try std.testing.expectEqual(ItemType.fromBlockId(.end_gateway), .end_gateway);
}

test "dragon's breath and lingering potion crafting recipes 122-124 and properties" {
    var inv = Inventory.init();

    // Recipe 122: 1 Glass + 1 Dragon Head -> 1 Dragon's Breath
    inv.craft_grid[0] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[1] = .{ .item = .dragon_head, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dragons_breath);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 123: 1 Dragon's Breath + 1 Poison Potion -> 1 Lingering Poison Potion
    inv.craft_grid[0] = .{ .item = .dragons_breath, .count = 1 };
    inv.craft_grid[1] = .{ .item = .poison_potion, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lingering_poison_potion);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 124: 1 Dragon's Breath + 1 Weakness Potion -> 1 Lingering Weakness Potion
    inv.craft_grid[0] = .{ .item = .dragons_breath, .count = 1 };
    inv.craft_grid[1] = .{ .item = .weakness_potion, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lingering_weakness_potion);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqualStrings(ItemType.dragons_breath.name(), "Dragon's Breath");
    try std.testing.expectEqualStrings(ItemType.lingering_poison_potion.name(), "Lingering Potion of Poison");
    try std.testing.expectEqualStrings(ItemType.lingering_weakness_potion.name(), "Lingering Potion of Weakness");
    try std.testing.expectEqual(ItemType.dragons_breath.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.lingering_poison_potion.maxStackSize(), 16);
}

test "turtle scute, turtle shell helmet, and water breathing potion recipes 125-126 and properties" {
    var inv = Inventory.init();

    // Recipe 125: 4 Scutes -> 1 Turtle Shell Helmet
    inv.craft_grid[0] = .{ .item = .scute, .count = 1 };
    inv.craft_grid[1] = .{ .item = .scute, .count = 1 };
    inv.craft_grid[2] = .{ .item = .scute, .count = 1 };
    inv.craft_grid[3] = .{ .item = .scute, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .turtle_helmet);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 126: 1 Scute + 1 Glass -> 1 Water Breathing Potion
    inv.craft_grid[0] = .{ .item = .scute, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .water_breathing_potion);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expect(ItemType.turtle_helmet.isArmor());
    try std.testing.expect(ItemType.turtle_helmet.isTool());
    try std.testing.expectEqual(ItemType.turtle_helmet.maxDurability(), 275);
    try std.testing.expectEqual(ItemType.turtle_helmet.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.turtle_helmet.name(), "Turtle Shell Helmet");

    try std.testing.expectEqualStrings(ItemType.scute.name(), "Scute");
    try std.testing.expectEqual(ItemType.scute.maxStackSize(), 64);

    try std.testing.expectEqualStrings(ItemType.water_breathing_potion.name(), "Potion of Water Breathing");
    try std.testing.expectEqual(ItemType.water_breathing_potion.maxStackSize(), 16);
    try std.testing.expectEqual(getMobMeatDrop(.turtle), .scute);
}

test "trident item properties, tool status, Recipe 127, and drowned mob drops" {
    var inv = Inventory.init();

    // Recipe 127: 2 Iron Ingots + 1 Scute + 1 Stick -> 1 Trident
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .scute, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .trident);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expect(ItemType.trident.isTool());
    try std.testing.expectEqual(ItemType.trident.maxDurability(), 250);
    try std.testing.expectEqual(ItemType.trident.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.trident.name(), "Trident");
    try std.testing.expect(ItemType.trident.toBlockId() == null);

    try std.testing.expectEqual(getMobMeatDrop(.drowned), .rotten_flesh);

    // Verify deterministic trident drop frequency
    var trident_drops: usize = 0;
    var x: i32 = 0;
    while (x < 60) : (x += 1) {
        if (dropsDrownedTrident(x, 4, 10)) trident_drops += 1;
    }
    try std.testing.expect(trident_drops > 0 and trident_drops < 30);
    try std.testing.expectEqual(dropsDrownedTrident(12, 4, 10), dropsDrownedTrident(12, 4, 10));
}

test "phantom membrane, slow falling potion, and elytra repair recipes 128-129" {
    var inv = Inventory.init();

    // Recipe 128: 1 Phantom Membrane + 1 Glass -> 1 Slow Falling Potion
    inv.craft_grid[0] = .{ .item = .phantom_membrane, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .slow_falling_potion);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 129: 2 Phantom Membranes + 2 Strings -> 1 Elytra
    inv.craft_grid[0] = .{ .item = .phantom_membrane, .count = 1 };
    inv.craft_grid[1] = .{ .item = .string, .count = 1 };
    inv.craft_grid[2] = .{ .item = .phantom_membrane, .count = 1 };
    inv.craft_grid[3] = .{ .item = .string, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .elytra);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.phantom_membrane.maxStackSize(), 64);
    try std.testing.expectEqualStrings(ItemType.phantom_membrane.name(), "Phantom Membrane");
    try std.testing.expectEqual(ItemType.slow_falling_potion.maxStackSize(), 16);
    try std.testing.expectEqualStrings(ItemType.slow_falling_potion.name(), "Potion of Slow Falling");
    try std.testing.expectEqual(getMobMeatDrop(.phantom), .phantom_membrane);
}

test "ocean monument prismarine, sea lantern, and conduit recipes 130-134 and roundtrip" {
    var inv = Inventory.init();

    // Recipe 130: 4 Prismarine Shards -> 1 Prismarine Block
    inv.craft_grid[0] = .{ .item = .prismarine_shard, .count = 1 };
    inv.craft_grid[1] = .{ .item = .prismarine_shard, .count = 1 };
    inv.craft_grid[2] = .{ .item = .prismarine_shard, .count = 1 };
    inv.craft_grid[3] = .{ .item = .prismarine_shard, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .prismarine);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 131: 2 Prismarine + 2 Cobblestone -> 2 Prismarine Bricks
    inv.craft_grid[0] = .{ .item = .prismarine, .count = 1 };
    inv.craft_grid[1] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[3] = .{ .item = .prismarine, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .prismarine_bricks);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 132: 2 Prismarine + 2 Coal -> 2 Dark Prismarine
    inv.craft_grid[0] = .{ .item = .prismarine, .count = 1 };
    inv.craft_grid[1] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[2] = .{ .item = .coal, .count = 1 };
    inv.craft_grid[3] = .{ .item = .prismarine, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dark_prismarine);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 133: 2 Shards + 2 Crystals -> 1 Sea Lantern
    inv.craft_grid[0] = .{ .item = .prismarine_shard, .count = 1 };
    inv.craft_grid[1] = .{ .item = .prismarine_crystals, .count = 1 };
    inv.craft_grid[2] = .{ .item = .prismarine_shard, .count = 1 };
    inv.craft_grid[3] = .{ .item = .prismarine_crystals, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .sea_lantern);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 134: 1 Heart of the Sea + 1 Shard -> 1 Conduit
    inv.craft_grid[0] = .{ .item = .heart_of_the_sea, .count = 1 };
    inv.craft_grid[1] = .{ .item = .prismarine_shard, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .conduit);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expectEqual(ItemType.prismarine.toBlockId().?, .prismarine);
    try std.testing.expectEqual(ItemType.prismarine_bricks.toBlockId().?, .prismarine_bricks);
    try std.testing.expectEqual(ItemType.dark_prismarine.toBlockId().?, .dark_prismarine);
    try std.testing.expectEqual(ItemType.sea_lantern.toBlockId().?, .sea_lantern);
    try std.testing.expectEqual(ItemType.conduit.toBlockId().?, .conduit);

    try std.testing.expectEqual(ItemType.fromBlockId(.conduit), .conduit);
    try std.testing.expectEqual(ItemType.fromBlockId(.sea_lantern), .sea_lantern);
}

test "guardian mob drop" {
    try std.testing.expectEqual(getMobMeatDrop(.guardian), .prismarine_shard);
}

test "sponge and wet sponge item roundtrip, properties, and elder guardian drops" {
    try std.testing.expectEqual(ItemType.sponge.toBlockId().?, .sponge);
    try std.testing.expectEqual(ItemType.wet_sponge.toBlockId().?, .wet_sponge);
    try std.testing.expectEqual(ItemType.fromBlockId(.sponge), .sponge);
    try std.testing.expectEqual(ItemType.fromBlockId(.wet_sponge), .wet_sponge);

    try std.testing.expectEqualStrings(ItemType.sponge.name(), "Sponge");
    try std.testing.expectEqualStrings(ItemType.wet_sponge.name(), "Wet Sponge");

    try std.testing.expectEqual(ItemType.sponge.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.wet_sponge.maxStackSize(), 64);

    try std.testing.expect(!ItemType.sponge.isTool());
    try std.testing.expect(!ItemType.wet_sponge.isTool());

    try std.testing.expectEqual(getMobMeatDrop(.elder_guardian), .sponge);
}

test "fishing rod recipe 135, cod properties, and dolphin drops" {
    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .string, .count = 1 };
    inv.craft_grid[3] = .{ .item = .string, .count = 1 };
    inv.updateCrafting();

    try std.testing.expectEqual(inv.craft_output.item, .fishing_rod);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expect(ItemType.fishing_rod.isTool());
    try std.testing.expectEqual(ItemType.fishing_rod.maxDurability(), 64);
    try std.testing.expectEqual(ItemType.fishing_rod.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.fishing_rod.name(), "Fishing Rod");

    try std.testing.expect(!ItemType.raw_cod.isTool());
    try std.testing.expect(!ItemType.cooked_cod.isTool());
    try std.testing.expectEqual(ItemType.raw_cod.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.cooked_cod.maxStackSize(), 64);
    try std.testing.expect(ItemType.raw_cod.isCompostable());
    try std.testing.expect(ItemType.cooked_cod.isCompostable());

    try std.testing.expectEqual(getMobMeatDrop(.dolphin), .raw_cod);
}

test "kelp, dried kelp, dried kelp block items and recipes 136-137" {
    var inv = Inventory.init();

    // Recipe 136: 4 Dried Kelp -> 1 Dried Kelp Block
    inv.craft_grid[0] = .{ .item = .dried_kelp, .count = 1 };
    inv.craft_grid[1] = .{ .item = .dried_kelp, .count = 1 };
    inv.craft_grid[2] = .{ .item = .dried_kelp, .count = 1 };
    inv.craft_grid[3] = .{ .item = .dried_kelp, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dried_kelp_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 137: 1 Dried Kelp Block -> 4 Dried Kelp
    inv.craft_grid[0] = .{ .item = .dried_kelp_block, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dried_kelp);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    try std.testing.expectEqual(ItemType.kelp.toBlockId().?, .kelp);
    try std.testing.expectEqual(ItemType.dried_kelp_block.toBlockId().?, .dried_kelp_block);
    try std.testing.expect(ItemType.dried_kelp.toBlockId() == null);

    try std.testing.expectEqual(ItemType.fromBlockId(.kelp), .kelp);
    try std.testing.expectEqual(ItemType.fromBlockId(.dried_kelp_block), .dried_kelp_block);

    try std.testing.expect(ItemType.kelp.isCompostable());
    try std.testing.expect(ItemType.dried_kelp.isCompostable());
    try std.testing.expect(!ItemType.dried_kelp_block.isCompostable());
}

test "sea pickle item roundtrip, compostable check, and properties" {
    try std.testing.expectEqual(ItemType.sea_pickle.toBlockId().?, .sea_pickle);
    try std.testing.expectEqual(ItemType.fromBlockId(.sea_pickle), .sea_pickle);
    try std.testing.expect(ItemType.sea_pickle.isCompostable());
    try std.testing.expectEqual(ItemType.sea_pickle.maxStackSize(), 64);
    try std.testing.expectEqualStrings(ItemType.sea_pickle.name(), "Sea Pickle");
}

test "marine fish species items, properties, and Recipe 138 pufferfish brewing" {
    var inv = Inventory.init();

    // Recipe 138: 1 Pufferfish + 1 Glass -> 1 Water Breathing Potion
    inv.craft_grid[0] = .{ .item = .pufferfish, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .water_breathing_potion);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expect(ItemType.raw_salmon.isCompostable());
    try std.testing.expect(ItemType.cooked_salmon.isCompostable());
    try std.testing.expect(ItemType.pufferfish.isCompostable());
    try std.testing.expect(ItemType.tropical_fish.isCompostable());

    try std.testing.expectEqual(ItemType.raw_salmon.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.cooked_salmon.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.pufferfish.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.tropical_fish.maxStackSize(), 64);

    try std.testing.expect(!ItemType.raw_salmon.isTool());
    try std.testing.expect(!ItemType.cooked_salmon.isTool());
    try std.testing.expect(!ItemType.pufferfish.isTool());
    try std.testing.expect(!ItemType.tropical_fish.isTool());

    try std.testing.expect(ItemType.raw_salmon.toBlockId() == null);
    try std.testing.expect(ItemType.cooked_salmon.toBlockId() == null);
    try std.testing.expect(ItemType.pufferfish.toBlockId() == null);
    try std.testing.expect(ItemType.tropical_fish.toBlockId() == null);
}

test "nautilus shell item properties, Recipe 134 conduit synergy, and drowned drops" {
    var inv = Inventory.init();

    // Recipe 134: 1 Heart of the Sea + 1 Nautilus Shell -> 1 Conduit
    inv.craft_grid[0] = .{ .item = .heart_of_the_sea, .count = 1 };
    inv.craft_grid[1] = .{ .item = .nautilus_shell, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .conduit);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    try std.testing.expect(!ItemType.nautilus_shell.isTool());
    try std.testing.expect(!ItemType.nautilus_shell.isCompostable());
    try std.testing.expectEqual(ItemType.nautilus_shell.maxStackSize(), 64);
    try std.testing.expectEqualStrings(ItemType.nautilus_shell.name(), "Nautilus Shell");
    try std.testing.expect(ItemType.nautilus_shell.toBlockId() == null);

    // Verify drowned nautilus shell drops deterministically
    var nautilus_count: usize = 0;
    var x: i32 = 0;
    while (x < 40) : (x += 1) {
        if (dropsDrownedNautilus(x, 4, 10)) nautilus_count += 1;
    }
    try std.testing.expect(nautilus_count >= 5);
}

test "rail, powered rail, and minecart items, recipes, and stack limits" {
    var inv = Inventory.init();

    // Recipe 139: 2 Iron Ingots + 1 Stick -> 4 Rails
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .rail);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 140: 2 Gold Nuggets + 1 Redstone Dust + 1 Stick -> 4 Powered Rails
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .powered_rail);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 141: 3 Iron Ingots U-shape -> 1 Minecart
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[3] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .minecart);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Stacks and names
    try std.testing.expectEqual(ItemType.rail.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.powered_rail.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.minecart.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.rail.name(), "Rail");
    try std.testing.expectEqualStrings(ItemType.powered_rail.name(), "Powered Rail");
    try std.testing.expectEqualStrings(ItemType.minecart.name(), "Minecart");

    // Block ID roundtrips
    try std.testing.expectEqual(ItemType.rail.toBlockId().?, .rail);
    try std.testing.expectEqual(ItemType.powered_rail.toBlockId().?, .powered_rail);
    try std.testing.expect(ItemType.minecart.toBlockId() == null);
}

test "detector rail and activator rail crafting recipes and properties" {
    var inv = Inventory.init();

    // Recipe 142: 2 Iron + 1 Redstone + 1 Stone -> 6 Detector Rails
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .detector_rail);
    try std.testing.expectEqual(inv.craft_output.count, 6);

    // Recipe 143: 2 Iron + 1 Redstone Torch + 1 Stick -> 6 Activator Rails
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_torch, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .activator_rail);
    try std.testing.expectEqual(inv.craft_output.count, 6);

    // Stacks and names
    try std.testing.expectEqual(ItemType.detector_rail.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.activator_rail.maxStackSize(), 64);
    try std.testing.expectEqualStrings(ItemType.detector_rail.name(), "Detector Rail");
    try std.testing.expectEqualStrings(ItemType.activator_rail.name(), "Activator Rail");

    // Roundtrips
    try std.testing.expectEqual(ItemType.detector_rail.toBlockId().?, .detector_rail);
    try std.testing.expectEqual(ItemType.activator_rail.toBlockId().?, .activator_rail);
    try std.testing.expectEqual(ItemType.fromBlockId(.detector_rail), .detector_rail);
    try std.testing.expectEqual(ItemType.fromBlockId(.activator_rail), .activator_rail);
}

test "minecart functional variants recipes 144-147 and properties" {
    var inv = Inventory.init();

    // Recipe 144: Minecart + Chest -> Chest Minecart
    inv.craft_grid[0] = .{ .item = .minecart, .count = 1 };
    inv.craft_grid[1] = .{ .item = .chest, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chest_minecart);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 145: Minecart + Furnace -> Furnace Minecart
    inv.craft_grid[1] = .{ .item = .furnace, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .furnace_minecart);

    // Recipe 146: Minecart + TNT -> TNT Minecart
    inv.craft_grid[1] = .{ .item = .tnt, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .tnt_minecart);

    // Recipe 147: Minecart + Hopper -> Hopper Minecart
    inv.craft_grid[1] = .{ .item = .hopper, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .hopper_minecart);

    // Stack sizes (all vehicles stack 1)
    try std.testing.expectEqual(ItemType.chest_minecart.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.furnace_minecart.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.tnt_minecart.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.hopper_minecart.maxStackSize(), 1);

    // Names
    try std.testing.expectEqualStrings(ItemType.chest_minecart.name(), "Minecart with Chest");
    try std.testing.expectEqualStrings(ItemType.furnace_minecart.name(), "Minecart with Furnace");
    try std.testing.expectEqualStrings(ItemType.tnt_minecart.name(), "Minecart with TNT");
    try std.testing.expectEqualStrings(ItemType.hopper_minecart.name(), "Minecart with Hopper");
}

test "redstone comparator item, roundtrip, and Recipe 148 crafting" {
    var inv = Inventory.init();

    // Recipe 148: 1 Nether Quartz + 2 Redstone Torches + 1 Stone -> 1 Comparator
    inv.craft_grid[0] = .{ .item = .nether_quartz, .count = 1 };
    inv.craft_grid[1] = .{ .item = .redstone_torch, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_torch, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .redstone_comparator);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Stacks and names
    try std.testing.expectEqual(ItemType.redstone_comparator.maxStackSize(), 64);
    try std.testing.expectEqualStrings(ItemType.redstone_comparator.name(), "Redstone Comparator");

    // Roundtrips
    try std.testing.expectEqual(ItemType.redstone_comparator.toBlockId().?, .redstone_comparator_off);
    try std.testing.expectEqual(ItemType.fromBlockId(.redstone_comparator_off), .redstone_comparator);
    try std.testing.expectEqual(ItemType.fromBlockId(.redstone_comparator_on), .redstone_comparator);
}

test "slime mob drop, slimeball item, slime block recipes 149 and 150" {
    var inv = Inventory.init();

    // Recipe 149: 4 Slimeballs -> 1 Slime Block
    inv.craft_grid[0] = .{ .item = .slimeball, .count = 1 };
    inv.craft_grid[1] = .{ .item = .slimeball, .count = 1 };
    inv.craft_grid[2] = .{ .item = .slimeball, .count = 1 };
    inv.craft_grid[3] = .{ .item = .slimeball, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .slime_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 150: 1 Slime Block -> 4 Slimeballs
    inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .slime_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .slimeball);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Drops & roundtrips
    try std.testing.expectEqual(getMobMeatDrop(.slime), .slimeball);
    try std.testing.expectEqual(ItemType.slime_block.toBlockId().?, .slime_block);
    try std.testing.expectEqual(ItemType.fromBlockId(.slime_block), .slime_block);
    try std.testing.expectEqual(ItemType.slimeball.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.slime_block.maxStackSize(), 64);
}

test "piston and sticky piston items and recipes 151 and 152" {
    var inv = Inventory.init();

    // Recipe 151: 1 Wood Planks + 1 Cobblestone + 1 Iron Ingot + 1 Redstone Dust -> 1 Piston
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[3] = .{ .item = .redstone_dust, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .piston);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 152: 1 Piston + 1 Slimeball -> 1 Sticky Piston
    inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .piston, .count = 1 };
    inv.craft_grid[1] = .{ .item = .slimeball, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .sticky_piston);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Stacks and roundtrips
    try std.testing.expectEqual(ItemType.piston.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.sticky_piston.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.piston.toBlockId().?, .piston);
    try std.testing.expectEqual(ItemType.sticky_piston.toBlockId().?, .sticky_piston);
    try std.testing.expectEqual(ItemType.fromBlockId(.piston), .piston);
    try std.testing.expectEqual(ItemType.fromBlockId(.sticky_piston), .sticky_piston);
    try std.testing.expectEqual(ItemType.fromBlockId(.piston_head), .piston);
}

test "observer item and Recipe 153 crafting" {
    var inv = Inventory.init();

    // Recipe 153: 2 Cobblestone + 1 Redstone Dust + 1 Nether Quartz -> 1 Observer
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[3] = .{ .item = .nether_quartz, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .observer);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Stacks and roundtrips
    try std.testing.expectEqual(ItemType.observer.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.observer.toBlockId().?, .observer_off);
    try std.testing.expectEqual(ItemType.fromBlockId(.observer_off), .observer);
    try std.testing.expectEqual(ItemType.fromBlockId(.observer_on), .observer);
    try std.testing.expectEqualStrings(ItemType.observer.name(), "Observer");
}

test "redstone ore item and drops" {
    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.redstone_ore, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .redstone_dust);
    try std.testing.expectEqual(drops[0].count, 4);

    const n_lit = getBlockDrops(.lit_redstone_ore, &drops);
    try std.testing.expectEqual(n_lit, 1);
    try std.testing.expectEqual(drops[0].item, .redstone_dust);
    try std.testing.expectEqual(drops[0].count, 4);

    try std.testing.expectEqual(ItemType.redstone_ore.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.redstone_ore.toBlockId().?, .redstone_ore);
    try std.testing.expectEqual(ItemType.fromBlockId(.redstone_ore), .redstone_ore);
    try std.testing.expectEqual(ItemType.fromBlockId(.lit_redstone_ore), .redstone_ore);
    try std.testing.expectEqualStrings(ItemType.redstone_ore.name(), "Redstone Ore");
}

test "diamond, diamond ore, and diamond block items, drops, and recipes 160 and 161" {
    var inv = Inventory.init();

    // Recipe 160: 4 Diamonds -> 1 Diamond Block
    inv.craft_grid[0] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[2] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[3] = .{ .item = .diamond, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 161: 1 Diamond Block -> 4 Diamonds
    inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .diamond_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Drops: diamond_ore -> 1 diamond
    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.diamond_ore, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .diamond);
    try std.testing.expectEqual(drops[0].count, 1);

    const n_db = getBlockDrops(.diamond_block, &drops);
    try std.testing.expectEqual(n_db, 1);
    try std.testing.expectEqual(drops[0].item, .diamond_block);
    try std.testing.expectEqual(drops[0].count, 1);

    // Item roundtrips and properties
    try std.testing.expectEqual(ItemType.diamond.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.diamond_ore.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.diamond_block.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.diamond.toBlockId(), null);
    try std.testing.expectEqual(ItemType.diamond_ore.toBlockId().?, .diamond_ore);
    try std.testing.expectEqual(ItemType.diamond_block.toBlockId().?, .diamond_block);
    try std.testing.expectEqual(ItemType.fromBlockId(.diamond_ore), .diamond_ore);
    try std.testing.expectEqual(ItemType.fromBlockId(.diamond_block), .diamond_block);
    try std.testing.expectEqualStrings(ItemType.diamond.name(), "Diamond");
    try std.testing.expectEqualStrings(ItemType.diamond_ore.name(), "Diamond Ore");
    try std.testing.expectEqualStrings(ItemType.diamond_block.name(), "Block of Diamond");
}

test "gold ore and gold block items, drops, and recipes 158 and 159" {
    var inv = Inventory.init();

    // Recipe 158: 4 Gold Nuggets -> 1 Gold Block
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[2] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[3] = .{ .item = .gold_nugget, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .gold_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 159: 1 Gold Block -> 4 Gold Nuggets
    inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .gold_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .gold_nugget);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Drops: gold_ore -> 2 gold nuggets
    var drops: [2]BlockDrop = undefined;
    const n = getBlockDrops(.gold_ore, &drops);
    try std.testing.expectEqual(n, 1);
    try std.testing.expectEqual(drops[0].item, .gold_nugget);
    try std.testing.expectEqual(drops[0].count, 2);

    const n_gb = getBlockDrops(.gold_block, &drops);
    try std.testing.expectEqual(n_gb, 1);
    try std.testing.expectEqual(drops[0].item, .gold_block);
    try std.testing.expectEqual(drops[0].count, 1);

    // Item roundtrips and properties
    try std.testing.expectEqual(ItemType.gold_ore.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.gold_block.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.gold_ore.toBlockId().?, .gold_ore);
    try std.testing.expectEqual(ItemType.gold_block.toBlockId().?, .gold_block);
    try std.testing.expectEqual(ItemType.fromBlockId(.gold_ore), .gold_ore);
    try std.testing.expectEqual(ItemType.fromBlockId(.gold_block), .gold_block);
    try std.testing.expectEqualStrings(ItemType.gold_ore.name(), "Gold Ore");
    try std.testing.expectEqualStrings(ItemType.gold_block.name(), "Block of Gold");
}

test "redstone block item and recipes 156 and 157" {
    var inv = Inventory.init();

    // Recipe 156: 4 Redstone Dust -> 1 Redstone Block
    inv.craft_grid[0] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[1] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[3] = .{ .item = .redstone_dust, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .redstone_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 157: 1 Redstone Block -> 4 Redstone Dust
    inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .redstone_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .redstone_dust);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Stack and roundtrips
    try std.testing.expectEqual(ItemType.redstone_block.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.redstone_block.toBlockId().?, .redstone_block);
    try std.testing.expectEqual(ItemType.fromBlockId(.redstone_block), .redstone_block);
    try std.testing.expectEqualStrings(ItemType.redstone_block.name(), "Block of Redstone");
}

test "wooden and iron trapdoor items and recipes 154 and 155" {
    var inv = Inventory.init();

    // Recipe 154: 1 Wooden Door -> 2 Wooden Trapdoors
    inv.craft_grid[0] = .{ .item = .wooden_door, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wooden_trapdoor);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 155: 1 Iron Door -> 2 Iron Trapdoors
    inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .iron_door, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_trapdoor);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Stacks and roundtrips
    try std.testing.expectEqual(ItemType.wooden_trapdoor.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.iron_trapdoor.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.wooden_trapdoor.toBlockId().?, .wooden_trapdoor_closed);
    try std.testing.expectEqual(ItemType.iron_trapdoor.toBlockId().?, .iron_trapdoor_closed);
    try std.testing.expectEqual(ItemType.fromBlockId(.wooden_trapdoor_closed), .wooden_trapdoor);
    try std.testing.expectEqual(ItemType.fromBlockId(.wooden_trapdoor_open), .wooden_trapdoor);
    try std.testing.expectEqual(ItemType.fromBlockId(.iron_trapdoor_closed), .iron_trapdoor);
    try std.testing.expectEqual(ItemType.fromBlockId(.iron_trapdoor_open), .iron_trapdoor);
}

test "diamond sword and diamond pickaxe items, durability, harvest tier, and recipes 162 and 163" {
    var inv = Inventory.init();

    // Recipe 162: 2 Diamonds vertically -> 1 Diamond Sword
    inv.craft_grid[0] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[2] = .{ .item = .diamond, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_sword);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 162 alternative: 1 Iron Sword + 1 Diamond -> 1 Diamond Sword
    inv.craft_grid[0] = .{ .item = .iron_sword, .count = 1 };
    inv.craft_grid[2] = .{ .item = .diamond, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_sword);

    // Recipe 163: 2 Diamonds top row + 1 Stick below -> 1 Diamond Pickaxe
    inv.craft_grid[0] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_pickaxe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 163 alternative: 1 Iron Pickaxe + 1 Diamond -> 1 Diamond Pickaxe
    inv.craft_grid[0] = .{ .item = .iron_pickaxe, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_pickaxe);

    // Netherite tool upgrading with Diamond tier:
    // Recipe 40: 1 Diamond Sword + 1 Netherite Ingot -> 1 Netherite Sword
    inv.craft_grid[0] = .{ .item = .diamond_sword, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_ingot, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_sword);

    // Recipe 39: 1 Diamond Pickaxe + 1 Netherite Ingot -> 1 Netherite Pickaxe
    inv.craft_grid[0] = .{ .item = .diamond_pickaxe, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_pickaxe);

    // Tool properties
    try std.testing.expect(ItemType.diamond_sword.isTool());
    try std.testing.expect(ItemType.diamond_pickaxe.isTool());
    try std.testing.expectEqual(ItemType.diamond_sword.maxDurability(), 250);
    try std.testing.expectEqual(ItemType.diamond_pickaxe.maxDurability(), 250);
    try std.testing.expectEqual(ItemType.diamond_sword.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.diamond_pickaxe.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.diamond_sword.name(), "Diamond Sword");
    try std.testing.expectEqualStrings(ItemType.diamond_pickaxe.name(), "Diamond Pickaxe");

    // Block harvesting permissions
    try std.testing.expect(canHarvestBlock(.diamond_pickaxe, .stone));
    try std.testing.expect(canHarvestBlock(.diamond_pickaxe, .iron_ore));
    try std.testing.expect(canHarvestBlock(.diamond_pickaxe, .diamond_ore));
    try std.testing.expect(canHarvestBlock(.diamond_pickaxe, .obsidian));
    try std.testing.expect(canHarvestBlock(.diamond_pickaxe, .ancient_debris));
}

test "diamond armor items, durability, set checks, and recipes 164-167" {
    var inv = Inventory.init();

    // Recipe 164: 1 Diamond + 1 Glass -> 1 Diamond Helmet
    inv.craft_grid[0] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_helmet);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 165: 1 Diamond Block + 1 Diamond -> 1 Diamond Chestplate
    inv.craft_grid[0] = .{ .item = .diamond_block, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_chestplate);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 166: 1 Diamond + 1 Obsidian -> 1 Diamond Leggings
    inv.craft_grid[0] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[1] = .{ .item = .obsidian, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_leggings);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 167: 2 Diamonds horizontally -> 1 Diamond Boots
    inv.craft_grid[0] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_boots);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Netherite armor upgrade recipes with diamond tier
    // Recipe 56: Diamond Chestplate + Netherite Ingot -> Netherite Chestplate
    inv.craft_grid[0] = .{ .item = .diamond_chestplate, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_chestplate);

    // Recipe 58: Diamond Helmet + Netherite Ingot -> Netherite Helmet
    inv.craft_grid[0] = .{ .item = .diamond_helmet, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_helmet);

    // Recipe 59: Diamond Leggings + Netherite Ingot -> Netherite Leggings
    inv.craft_grid[0] = .{ .item = .diamond_leggings, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_leggings);

    // Recipe 61: Diamond Boots + Netherite Ingot -> Netherite Boots
    inv.craft_grid[0] = .{ .item = .diamond_boots, .count = 1 };
    inv.craft_grid[1] = .{ .item = .netherite_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_boots);

    // Durabilities & tools
    try std.testing.expect(ItemType.diamond_helmet.isArmor());
    try std.testing.expect(ItemType.diamond_chestplate.isArmor());
    try std.testing.expect(ItemType.diamond_leggings.isArmor());
    try std.testing.expect(ItemType.diamond_boots.isArmor());

    try std.testing.expectEqual(ItemType.diamond_helmet.maxDurability(), 360);
    try std.testing.expectEqual(ItemType.diamond_chestplate.maxDurability(), 420);
    try std.testing.expectEqual(ItemType.diamond_leggings.maxDurability(), 390);
    try std.testing.expectEqual(ItemType.diamond_boots.maxDurability(), 340);

    try std.testing.expectEqual(ItemType.diamond_helmet.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.diamond_chestplate.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.diamond_leggings.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.diamond_boots.maxStackSize(), 1);

    // Set check
    var player_inv = Inventory.init();
    try std.testing.expect(!player_inv.hasFullDiamondSet());
    player_inv.slots[0] = .{ .item = .diamond_helmet, .count = 1 };
    player_inv.slots[1] = .{ .item = .diamond_chestplate, .count = 1 };
    player_inv.slots[2] = .{ .item = .diamond_leggings, .count = 1 };
    try std.testing.expect(!player_inv.hasFullDiamondSet());
    player_inv.slots[3] = .{ .item = .diamond_boots, .count = 1 };
    try std.testing.expect(player_inv.hasFullDiamondSet());
}

test "flint and flint and steel items, recipes 168-169, durability and stack" {
    var inv = Inventory.init();

    // Recipe 168: 2 Sand -> 1 Flint
    inv.craft_grid[0] = .{ .item = .sand, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sand, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .flint);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 169: 1 Iron Ingot + 1 Flint -> 1 Flint and Steel
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .flint, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .flint_and_steel);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Item properties
    try std.testing.expect(!ItemType.flint.isTool());
    try std.testing.expect(ItemType.flint_and_steel.isTool());
    try std.testing.expectEqual(ItemType.flint.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.flint_and_steel.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.flint_and_steel.maxDurability(), 64);
    try std.testing.expectEqualStrings(ItemType.flint.name(), "Flint");
    try std.testing.expectEqualStrings(ItemType.flint_and_steel.name(), "Flint and Steel");
}

test "axe items, durability, harvesting, and recipes 170-173" {
    var inv = Inventory.init();

    // Recipe 170: 1 Wood + 1 Stick -> 1 Wooden Axe
    inv.craft_grid[0] = .{ .item = .wood, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wooden_axe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 171: 1 Iron Ingot + 1 Wood Planks -> 1 Iron Axe
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_axe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 172: 1 Diamond + 1 Wood -> 1 Diamond Axe
    inv.craft_grid[0] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_axe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 173: 1 Netherite Ingot + 1 Diamond Axe -> 1 Netherite Axe
    inv.craft_grid[0] = .{ .item = .netherite_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond_axe, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_axe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Durabilities & tools
    try std.testing.expect(ItemType.wooden_axe.isTool());
    try std.testing.expect(ItemType.iron_axe.isTool());
    try std.testing.expect(ItemType.diamond_axe.isTool());
    try std.testing.expect(ItemType.netherite_axe.isTool());

    try std.testing.expectEqual(ItemType.wooden_axe.maxDurability(), 25);
    try std.testing.expectEqual(ItemType.iron_axe.maxDurability(), 120);
    try std.testing.expectEqual(ItemType.diamond_axe.maxDurability(), 250);
    try std.testing.expectEqual(ItemType.netherite_axe.maxDurability(), 350);

    try std.testing.expectEqual(ItemType.wooden_axe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.iron_axe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.diamond_axe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.netherite_axe.maxStackSize(), 1);

    // Harvesting permissions
    try std.testing.expect(canHarvestBlock(.wooden_axe, .wood));
    try std.testing.expect(canHarvestBlock(.iron_axe, .wood_planks));
    try std.testing.expect(canHarvestBlock(.diamond_axe, .chest));
    try std.testing.expect(canHarvestBlock(.netherite_axe, .crafting_table));
}

test "shovel items, durability, harvesting, and recipes 174-177" {
    var inv = Inventory.init();

    // Recipe 174: 1 Wood Planks + 1 Stick -> 1 Wooden Shovel
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wooden_shovel);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 175: 1 Iron Ingot + 1 Stick -> 1 Iron Shovel
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_shovel);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 176: 1 Diamond + 1 Stick -> 1 Diamond Shovel
    inv.craft_grid[0] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_shovel);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 177: 1 Netherite Ingot + 1 Diamond Shovel -> 1 Netherite Shovel
    inv.craft_grid[0] = .{ .item = .netherite_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond_shovel, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_shovel);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Durabilities & tools
    try std.testing.expect(ItemType.wooden_shovel.isTool());
    try std.testing.expect(ItemType.iron_shovel.isTool());
    try std.testing.expect(ItemType.diamond_shovel.isTool());
    try std.testing.expect(ItemType.netherite_shovel.isTool());

    try std.testing.expectEqual(ItemType.wooden_shovel.maxDurability(), 25);
    try std.testing.expectEqual(ItemType.iron_shovel.maxDurability(), 120);
    try std.testing.expectEqual(ItemType.diamond_shovel.maxDurability(), 250);
    try std.testing.expectEqual(ItemType.netherite_shovel.maxDurability(), 350);

    try std.testing.expectEqual(ItemType.wooden_shovel.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.iron_shovel.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.diamond_shovel.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.netherite_shovel.maxStackSize(), 1);

    // Harvesting permissions
    try std.testing.expect(canHarvestBlock(.wooden_shovel, .dirt));
    try std.testing.expect(canHarvestBlock(.iron_shovel, .grass));
    try std.testing.expect(canHarvestBlock(.diamond_shovel, .sand));
    try std.testing.expect(canHarvestBlock(.netherite_shovel, .soul_sand));
}

test "hoe items, durability, harvesting, and recipes 178-181" {
    var inv = Inventory.init();

    // Recipe 178: 1 Wood Planks + 1 Stick horizontally -> 1 Wooden Hoe
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wooden_hoe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 179: 1 Iron Ingot + 1 Stick horizontally -> 1 Iron Hoe
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_hoe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 180: 1 Diamond + 1 Stick horizontally -> 1 Diamond Hoe
    inv.craft_grid[0] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_hoe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 181: 1 Netherite Ingot + 1 Diamond Hoe -> 1 Netherite Hoe
    inv.craft_grid[0] = .{ .item = .netherite_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond_hoe, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .netherite_hoe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Durabilities & tools
    try std.testing.expect(ItemType.wooden_hoe.isTool());
    try std.testing.expect(ItemType.iron_hoe.isTool());
    try std.testing.expect(ItemType.diamond_hoe.isTool());
    try std.testing.expect(ItemType.netherite_hoe.isTool());

    try std.testing.expect(ItemType.wooden_hoe.isHoe());
    try std.testing.expect(ItemType.iron_hoe.isHoe());
    try std.testing.expect(ItemType.diamond_hoe.isHoe());
    try std.testing.expect(ItemType.netherite_hoe.isHoe());
    try std.testing.expect(!ItemType.wooden_shovel.isHoe());

    try std.testing.expectEqual(ItemType.wooden_hoe.maxDurability(), 25);
    try std.testing.expectEqual(ItemType.iron_hoe.maxDurability(), 120);
    try std.testing.expectEqual(ItemType.diamond_hoe.maxDurability(), 250);
    try std.testing.expectEqual(ItemType.netherite_hoe.maxDurability(), 350);

    try std.testing.expectEqual(ItemType.wooden_hoe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.iron_hoe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.diamond_hoe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.netherite_hoe.maxStackSize(), 1);

    // Harvesting permissions
    try std.testing.expect(canHarvestBlock(.wooden_hoe, .leaves));
    try std.testing.expect(canHarvestBlock(.iron_hoe, .hay_bale));
    try std.testing.expect(canHarvestBlock(.diamond_hoe, .shroomlight));
    try std.testing.expect(canHarvestBlock(.netherite_hoe, .sponge));
}

test "shears item, durability, tool classification, and Recipe 182" {
    var inv = Inventory.init();

    // Recipe 182: 2 Iron Ingots -> 1 Shears
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[3] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .shears);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Diagonal inverted
    inv.craft_grid[0] = .{};
    inv.craft_grid[3] = .{};
    inv.craft_grid[1] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .iron_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .shears);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Durability & tool properties
    try std.testing.expect(ItemType.shears.isTool());
    try std.testing.expect(ItemType.shears.isShears());
    try std.testing.expect(!ItemType.shears.isHoe());
    try std.testing.expectEqual(ItemType.shears.maxDurability(), 238);
    try std.testing.expectEqual(ItemType.shears.maxStackSize(), 1);
    try std.testing.expectEqualStrings(ItemType.shears.name(), "Shears");

    // Harvesting permissions
    try std.testing.expect(canHarvestBlock(.shears, .leaves));
    try std.testing.expect(canHarvestBlock(.shears, .cobweb));
    try std.testing.expect(canHarvestBlock(.shears, .wool));
}

test "iron armor suit item properties, recipes 183-186, and full set detection" {
    var inv = Inventory.init();

    // Recipe 183: 1 Iron Ingot + 1 Sand -> 1 Iron Helmet
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sand, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_helmet);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 184: 1 Iron Ingot + 1 Iron Bars -> 1 Iron Chestplate
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .iron_bars, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_chestplate);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 185: 1 Iron Ingot + 1 Chain -> 1 Iron Leggings
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .chain, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_leggings);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 186: 1 Iron Ingot + 1 Wool -> 1 Iron Boots
    inv.craft_grid[0] = .{ .item = .iron_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wool, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_boots);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Upgrades: Iron Armor + Diamond -> Diamond Armor
    inv.craft_grid[0] = .{ .item = .iron_helmet, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_helmet);

    inv.craft_grid[0] = .{ .item = .iron_chestplate, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_chestplate);

    inv.craft_grid[0] = .{ .item = .iron_leggings, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_leggings);

    inv.craft_grid[0] = .{ .item = .iron_boots, .count = 1 };
    inv.craft_grid[1] = .{ .item = .diamond, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .diamond_boots);

    // Durabilities & Armor classifications
    try std.testing.expect(ItemType.iron_helmet.isArmor());
    try std.testing.expect(ItemType.iron_chestplate.isArmor());
    try std.testing.expect(ItemType.iron_leggings.isArmor());
    try std.testing.expect(ItemType.iron_boots.isArmor());

    try std.testing.expectEqual(ItemType.iron_helmet.maxDurability(), 165);
    try std.testing.expectEqual(ItemType.iron_chestplate.maxDurability(), 240);
    try std.testing.expectEqual(ItemType.iron_leggings.maxDurability(), 225);
    try std.testing.expectEqual(ItemType.iron_boots.maxDurability(), 195);

    try std.testing.expectEqual(ItemType.iron_helmet.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.iron_chestplate.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.iron_leggings.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.iron_boots.maxStackSize(), 1);

    // Full set detection
    var player_inv = Inventory.init();
    try std.testing.expect(!player_inv.hasFullIronSet());
    player_inv.slots[0] = .{ .item = .iron_helmet, .count = 1 };
    player_inv.slots[1] = .{ .item = .iron_chestplate, .count = 1 };
    player_inv.slots[2] = .{ .item = .iron_leggings, .count = 1 };
    try std.testing.expect(!player_inv.hasFullIronSet());
    player_inv.slots[3] = .{ .item = .iron_boots, .count = 1 };
    try std.testing.expect(player_inv.hasFullIronSet());
}

test "golden armor suit item properties, recipes 187-190, full set and any piece checks" {
    var inv = Inventory.init();

    // Recipe 187: 1 Gold Nugget + 1 Sand -> 1 Golden Helmet
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sand, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_helmet);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 188: 1 Block of Gold + 1 Gold Nugget -> 1 Golden Chestplate
    inv.craft_grid[0] = .{ .item = .gold_block, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_nugget, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_chestplate);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 189: 1 Gold Nugget + 1 Chain -> 1 Golden Leggings
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .chain, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_leggings);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 190: 1 Gold Nugget + 1 Wool -> 1 Golden Boots
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wool, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_boots);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Durabilities & Armor classifications
    try std.testing.expect(ItemType.golden_helmet.isArmor());
    try std.testing.expect(ItemType.golden_chestplate.isArmor());
    try std.testing.expect(ItemType.golden_leggings.isArmor());
    try std.testing.expect(ItemType.golden_boots.isArmor());

    try std.testing.expectEqual(ItemType.golden_helmet.maxDurability(), 77);
    try std.testing.expectEqual(ItemType.golden_chestplate.maxDurability(), 112);
    try std.testing.expectEqual(ItemType.golden_leggings.maxDurability(), 105);
    try std.testing.expectEqual(ItemType.golden_boots.maxDurability(), 91);

    try std.testing.expectEqual(ItemType.golden_helmet.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.golden_chestplate.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.golden_leggings.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.golden_boots.maxStackSize(), 1);

    // Full set detection and any piece pacification check
    var player_inv = Inventory.init();
    try std.testing.expect(!player_inv.hasFullGoldenSet());
    try std.testing.expect(!player_inv.hasAnyGoldenArmor());

    player_inv.slots[0] = .{ .item = .golden_helmet, .count = 1 };
    try std.testing.expect(!player_inv.hasFullGoldenSet());
    try std.testing.expect(player_inv.hasAnyGoldenArmor());

    player_inv.slots[1] = .{ .item = .golden_chestplate, .count = 1 };
    player_inv.slots[2] = .{ .item = .golden_leggings, .count = 1 };
    try std.testing.expect(!player_inv.hasFullGoldenSet());
    player_inv.slots[3] = .{ .item = .golden_boots, .count = 1 };
    try std.testing.expect(player_inv.hasFullGoldenSet());
}

test "stone tool items, durabilities, tool classification, and recipes 191-195" {
    var inv = Inventory.init();

    // Recipe 191: 1 Cobblestone + 1 Stick (vertical) -> 1 Stone Sword
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stone_sword);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 192: 2 Cobblestone + 1 Stick -> 1 Stone Pickaxe
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stone_pickaxe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 193: 1 Cobblestone + 1 Wood Log -> 1 Stone Axe
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stone_axe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 194: 1 Cobblestone + 1 Wood Planks -> 1 Stone Shovel
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stone_shovel);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 195: 1 Cobblestone + 1 Stick (horizontal) -> 1 Stone Hoe
    inv.craft_grid[0] = .{ .item = .cobblestone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stone_hoe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Tool classification and durabilities
    try std.testing.expect(ItemType.stone_sword.isTool());
    try std.testing.expect(ItemType.stone_pickaxe.isTool());
    try std.testing.expect(ItemType.stone_axe.isTool());
    try std.testing.expect(ItemType.stone_shovel.isTool());
    try std.testing.expect(ItemType.stone_hoe.isTool());
    try std.testing.expect(ItemType.stone_hoe.isHoe());

    try std.testing.expectEqual(ItemType.stone_sword.maxDurability(), 131);
    try std.testing.expectEqual(ItemType.stone_pickaxe.maxDurability(), 131);
    try std.testing.expectEqual(ItemType.stone_axe.maxDurability(), 131);
    try std.testing.expectEqual(ItemType.stone_shovel.maxDurability(), 131);
    try std.testing.expectEqual(ItemType.stone_hoe.maxDurability(), 131);

    try std.testing.expectEqual(ItemType.stone_sword.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.stone_pickaxe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.stone_axe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.stone_shovel.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.stone_hoe.maxStackSize(), 1);

    // Harvesting permissions
    try std.testing.expect(canHarvestBlock(.stone_pickaxe, .stone));
    try std.testing.expect(canHarvestBlock(.stone_pickaxe, .iron_ore));
    try std.testing.expect(canHarvestBlock(.stone_axe, .wood));
    try std.testing.expect(canHarvestBlock(.stone_shovel, .dirt));
    try std.testing.expect(canHarvestBlock(.stone_hoe, .leaves));
}

test "golden tool items, durabilities, tool classification, recipes 196-200, and hasAnyGoldenItem" {
    var inv = Inventory.init();

    // Recipe 196: 1 Gold Nugget + 1 Stick (vertical) -> 1 Golden Sword
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_sword);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 197: 2 Gold Nuggets + 1 Stick -> 1 Golden Pickaxe
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_pickaxe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 198: 1 Gold Nugget + 1 Wood Log -> 1 Golden Axe
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_axe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 199: 1 Gold Nugget + 1 Wood Planks -> 1 Golden Shovel
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_shovel);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 200: 1 Gold Nugget + 1 Stick (horizontal) -> 1 Golden Hoe
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_hoe);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Tool classification and durabilities
    try std.testing.expect(ItemType.golden_sword.isTool());
    try std.testing.expect(ItemType.golden_pickaxe.isTool());
    try std.testing.expect(ItemType.golden_axe.isTool());
    try std.testing.expect(ItemType.golden_shovel.isTool());
    try std.testing.expect(ItemType.golden_hoe.isTool());
    try std.testing.expect(ItemType.golden_hoe.isHoe());

    try std.testing.expectEqual(ItemType.golden_sword.maxDurability(), 32);
    try std.testing.expectEqual(ItemType.golden_pickaxe.maxDurability(), 32);
    try std.testing.expectEqual(ItemType.golden_axe.maxDurability(), 32);
    try std.testing.expectEqual(ItemType.golden_shovel.maxDurability(), 32);
    try std.testing.expectEqual(ItemType.golden_hoe.maxDurability(), 32);

    try std.testing.expectEqual(ItemType.golden_sword.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.golden_pickaxe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.golden_axe.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.golden_shovel.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.golden_hoe.maxStackSize(), 1);

    // Harvesting permissions
    try std.testing.expect(canHarvestBlock(.golden_pickaxe, .stone));
    try std.testing.expect(canHarvestBlock(.golden_axe, .wood));
    try std.testing.expect(canHarvestBlock(.golden_shovel, .dirt));
    try std.testing.expect(canHarvestBlock(.golden_hoe, .leaves));

    // hasAnyGoldenItem checks
    var player_inv = Inventory.init();
    try std.testing.expect(!player_inv.hasAnyGoldenItem());
    player_inv.slots[0] = .{ .item = .golden_sword, .count = 1 };
    try std.testing.expect(player_inv.hasAnyGoldenItem());
}

test "wooden sword, leather, and leather armor suit recipes 201-206" {
    var inv = Inventory.init();

    // Recipe 201: 1 Wood Planks + 1 Stick (diagonal) -> 1 Wooden Sword
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .stick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wooden_sword);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 202: 4 Rotten Flesh -> 1 Leather
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .rotten_flesh, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .leather);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 203: 2 Leather horizontally -> 1 Leather Cap
    inv.craft_grid[0] = .{ .item = .leather, .count = 1 };
    inv.craft_grid[1] = .{ .item = .leather, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .leather_helmet);

    // Recipe 204: 4 Leather -> 1 Leather Tunic
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .leather, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .leather_chestplate);

    // Recipe 205: 3 Leather -> 1 Leather Pants
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .leather_leggings);

    // Recipe 206: 2 Leather vertically -> 1 Leather Boots
    inv.craft_grid[0] = .{ .item = .leather, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .leather, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .leather_boots);

    try std.testing.expect(ItemType.wooden_sword.isTool());
    try std.testing.expectEqual(ItemType.wooden_sword.maxDurability(), 59);
    try std.testing.expect(ItemType.leather_helmet.isArmor());
    try std.testing.expect(ItemType.leather_chestplate.isArmor());
    try std.testing.expect(ItemType.leather_leggings.isArmor());
    try std.testing.expect(ItemType.leather_boots.isArmor());
    try std.testing.expectEqual(ItemType.leather_helmet.maxDurability(), 55);
    try std.testing.expectEqual(ItemType.leather_chestplate.maxDurability(), 80);
    try std.testing.expectEqual(ItemType.leather_leggings.maxDurability(), 75);
    try std.testing.expectEqual(ItemType.leather_boots.maxDurability(), 65);
    try std.testing.expect(canHarvestBlock(.wooden_sword, .cobweb));

    var p_inv = Inventory.init();
    try std.testing.expect(!p_inv.hasFullLeatherSet());
    p_inv.slots[0] = .{ .item = .leather_helmet, .count = 1 };
    p_inv.slots[1] = .{ .item = .leather_chestplate, .count = 1 };
    p_inv.slots[2] = .{ .item = .leather_leggings, .count = 1 };
    p_inv.slots[3] = .{ .item = .leather_boots, .count = 1 };
    try std.testing.expect(p_inv.hasFullLeatherSet());
}

test "farmland, wheat_seeds, wheat, and bread items and recipes 207-209" {
    var inv = Inventory.init();

    // Recipe 207: 1 Wheat -> 2 Wheat Seeds
    inv.craft_grid[0] = .{ .item = .wheat, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wheat_seeds);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 208: 3 Wheat -> 1 Bread
    inv.craft_grid[0] = .{ .item = .wheat, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wheat, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wheat, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .bread);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 209: 4 Wheat -> 1 Hay Bale, 1 Hay Bale -> 4 Wheat
    inv.craft_grid[3] = .{ .item = .wheat, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .hay_bale);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    inv.craft_grid[0] = .{ .item = .hay_bale, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wheat);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    try std.testing.expect(ItemType.wheat_seeds.isCompostable());
    try std.testing.expect(ItemType.wheat.isCompostable());
    try std.testing.expect(ItemType.bread.isCompostable());
    try std.testing.expectEqual(ItemType.wheat_seeds.toBlockId().?, .wheat_crop);
    try std.testing.expectEqual(ItemType.fromBlockId(.farmland), .dirt);
    try std.testing.expectEqual(ItemType.fromBlockId(.wheat_crop), .wheat_seeds);
}

test "paper, book, bookshelf, lectern, and emerald items, drops, and recipes 210-215" {
    var inv = Inventory.init();

    // Recipe 210: 2 Wheat horizontally -> 3 Paper
    inv.craft_grid[0] = .{ .item = .wheat, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wheat, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .paper);
    try std.testing.expectEqual(inv.craft_output.count, 3);

    // Recipe 211: 2 Paper + 1 Leather -> 1 Book
    inv.craft_grid[0] = .{ .item = .paper, .count = 1 };
    inv.craft_grid[1] = .{ .item = .paper, .count = 1 };
    inv.craft_grid[2] = .{ .item = .leather, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .book);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 212: 2 Books + 2 Wood Planks -> 1 Bookshelf
    inv.craft_grid[0] = .{ .item = .book, .count = 1 };
    inv.craft_grid[1] = .{ .item = .book, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .bookshelf);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 213: 1 Bookshelf + 1 Wood Planks -> 1 Lectern
    inv.craft_grid[0] = .{ .item = .bookshelf, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lectern);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 214 & 215: 4 Emeralds <-> 1 Block of Emerald
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .emerald, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .emerald_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    inv.craft_grid[0] = .{ .item = .emerald_block, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .emerald);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(getBlockDrops(.bookshelf, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .book);
    try std.testing.expectEqual(drops[0].count, 3);
    try std.testing.expectEqual(getBlockDrops(.emerald_ore, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .emerald);
    try std.testing.expectEqual(drops[0].count, 1);
}

test "lapis lazuli, beehive, honeycomb, honey bottle, and honey block recipes 216-220" {
    var inv = Inventory.init();

    // Recipe 216 & 217: 4 Lapis <-> 1 Block of Lapis
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .lapis_lazuli, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lapis_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    inv.craft_grid[0] = .{ .item = .lapis_block, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lapis_lazuli);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 218: 2 Honeycomb + 2 Wood Planks -> 1 Beehive
    inv.craft_grid[0] = .{ .item = .honeycomb, .count = 1 };
    inv.craft_grid[1] = .{ .item = .honeycomb, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .beehive);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 219 & 220: 4 Honey Bottles <-> 1 Honey Block
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .honey_bottle, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .honey_block);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    inv.craft_grid[0] = .{ .item = .honey_block, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .honey_bottle);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(getBlockDrops(.lapis_ore, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .lapis_lazuli);
    try std.testing.expectEqual(drops[0].count, 4);
}

test "copper, lightning rod, spyglass, amethyst, tinted glass, bell, sugar cane, and pumpkin recipes 221-232" {
    var inv = Inventory.init();

    // Recipe 221: 4 Copper Ingots -> 1 Block of Copper
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .copper_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .copper_block);

    // Recipe 223: 1 Block of Copper + 1 Honeycomb -> 1 Waxed Block of Copper
    inv.craft_grid[0] = .{ .item = .copper_block, .count = 1 };
    inv.craft_grid[1] = .{ .item = .honeycomb, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .waxed_copper_block);

    // Recipe 224: 2 Copper Ingots vertically -> 1 Lightning Rod
    inv.craft_grid[0] = .{ .item = .copper_ingot, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .copper_ingot, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lightning_rod);

    // Recipe 225: 2 Copper Ingots + 1 Amethyst Shard -> 1 Spyglass
    inv.craft_grid[1] = .{ .item = .amethyst_shard, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .spyglass);
    try std.testing.expectEqual(ItemType.spyglass.maxStackSize(), 1);

    // Recipe 227: 2 Amethyst Shards + 1 Glass -> 2 Tinted Glass
    inv.craft_grid[0] = .{ .item = .amethyst_shard, .count = 1 };
    inv.craft_grid[1] = .{ .item = .amethyst_shard, .count = 1 };
    inv.craft_grid[2] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .tinted_glass);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 228: Bell
    inv.craft_grid[0] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .stone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .bell);

    // Recipe 229: 1 Sugar Cane -> 1 Sugar
    inv.craft_grid[0] = .{ .item = .sugar_cane, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .sugar);

    // Recipe 231: 1 Carved Pumpkin + 1 Torch -> 1 Jack o'Lantern
    inv.craft_grid[0] = .{ .item = .carved_pumpkin, .count = 1 };
    inv.craft_grid[1] = .{ .item = .torch, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .jack_o_lantern);

    // Recipe 232: 1 Pumpkin + 1 Sugar + 1 Wheat -> 1 Pumpkin Pie
    inv.craft_grid[0] = .{ .item = .pumpkin, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sugar, .count = 1 };
    inv.craft_grid[2] = .{ .item = .wheat, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .pumpkin_pie);

    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(getBlockDrops(.copper_ore, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .raw_copper);
    try std.testing.expectEqual(drops[0].count, 2);
    try std.testing.expectEqual(getBlockDrops(.amethyst_cluster, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .amethyst_shard);
    try std.testing.expectEqual(drops[0].count, 4);
    try std.testing.expectEqual(getBlockDrops(.tinted_glass, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .tinted_glass);
}

test "sculk, deepslate, iron block, cake, melon, glistering melon, healing potion, and barrel recipes 233-243" {
    var inv = Inventory.init();

    // Recipe 233: Sculk Sensor
    inv.craft_grid[0] = .{ .item = .sculk, .count = 1 };
    inv.craft_grid[1] = .{ .item = .redstone_dust, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .sculk_sensor);

    // Recipe 234: Recovery Compass
    inv.craft_grid[0] = .{ .item = .compass, .count = 1 };
    inv.craft_grid[1] = .{ .item = .echo_shard, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .recovery_compass);

    // Recipe 235 & 236: Polished Deepslate & Deepslate Bricks
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .cobbled_deepslate, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .polished_deepslate);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .polished_deepslate, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .deepslate_bricks);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 237 & 238: 4x2 Iron Ingots <-> 1 Block of Iron
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .iron_ingot, .count = 2 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_block);

    inv.craft_grid[0] = .{ .item = .iron_block, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .iron_ingot);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 239: Cake
    inv.craft_grid[0] = .{ .item = .wheat, .count = 1 };
    inv.craft_grid[1] = .{ .item = .sugar, .count = 1 };
    inv.craft_grid[2] = .{ .item = .apple, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .cake);

    // Recipe 240: 4 Melon Slices -> 1 Melon
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .melon_slice, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .melon);

    // Recipe 241 & 242: Glistering Melon & Healing Potion
    inv.craft_grid[0] = .{ .item = .melon_slice, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .glistering_melon);

    inv.craft_grid[0] = .{ .item = .glistering_melon, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .healing_potion);

    // Recipe 243: Barrel
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wooden_trapdoor, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .barrel);

    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(getBlockDrops(.deepslate, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .cobbled_deepslate);
    try std.testing.expectEqual(getBlockDrops(.cake, &drops), 0);
    try std.testing.expectEqual(getBlockDrops(.melon, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .melon_slice);
    try std.testing.expectEqual(drops[0].count, 4);
}

test "dripstone, moss, clay, terracotta, brick_item, flower_pot, totem, golden_carrot, night_vision, and regeneration recipes 244-253" {
    var inv = Inventory.init();

    // Recipe 244 & 245: 4 Pointed Dripstone <-> 1 Dripstone Block
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .pointed_dripstone, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dripstone_block);

    inv.craft_grid[0] = .{ .item = .dripstone_block, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .pointed_dripstone);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 246: 2 Moss Blocks -> 3 Moss Carpets
    inv.craft_grid[0] = .{ .item = .moss_block, .count = 1 };
    inv.craft_grid[1] = .{ .item = .moss_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .moss_carpet);
    try std.testing.expectEqual(inv.craft_output.count, 3);

    // Recipe 247, 248, 249: Clay, Brick, Flower Pot
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .clay_ball, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .clay);

    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .brick_item, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .brick);

    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .flower_pot);

    // Recipe 250: Totem of Undying
    inv.craft_grid[0] = .{ .item = .gold_block, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_block, .count = 1 };
    inv.craft_grid[2] = .{ .item = .emerald, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .totem_of_undying);

    // Recipe 251 & 252: Golden Carrot & Night Vision Potion
    inv.craft_grid[0] = .{ .item = .carrot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_nugget, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .golden_carrot);

    inv.craft_grid[0] = .{ .item = .golden_carrot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .night_vision_potion);

    // Recipe 253: Regeneration Potion
    inv.craft_grid[0] = .{ .item = .ghast_tear, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .regeneration_potion);

    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(getBlockDrops(.clay, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .clay_ball);
    try std.testing.expectEqual(drops[0].count, 4);
}

test "ice, powder snow, bamboo, scaffolding, soups, buff potions, cookies, and sweet berries recipes 254-265" {
    var inv = Inventory.init();

    // Recipe 254 & 255: Packed Ice & Blue Ice
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .ice, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .packed_ice);

    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .packed_ice, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .blue_ice);

    // Recipe 256: Powder Snow Bucket
    inv.craft_grid[0] = .{ .item = .snow_block, .count = 1 };
    inv.craft_grid[1] = .{ .item = .water_bucket, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .powder_snow_bucket);

    // Recipe 257 & 258: Bamboo -> Stick & Scaffolding
    inv.craft_grid[0] = .{ .item = .bamboo, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .bamboo, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .stick);

    inv.craft_grid[1] = .{ .item = .string, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .scaffolding);
    try std.testing.expectEqual(inv.craft_output.count, 6);

    // Recipe 259, 260, 261: Bowl, Beetroot Soup, Mushroom Stew
    inv.craft_grid[0] = .{ .item = .wood_planks, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{ .item = .wood_planks, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .bowl);
    try std.testing.expectEqual(inv.craft_output.count, 4);
    inv.craft_grid[3] = .{};

    inv.craft_grid[0] = .{ .item = .beetroot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .beetroot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .bowl, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .beetroot_soup);

    inv.craft_grid[0] = .{ .item = .crimson_fungus, .count = 1 };
    inv.craft_grid[1] = .{ .item = .warped_fungus, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .mushroom_stew);

    // Recipe 262, 263, 264: Swiftness, Strength, Leaping Potions
    inv.craft_grid[0] = .{ .item = .sugar, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .swiftness_potion);

    inv.craft_grid[0] = .{ .item = .blaze_powder, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .strength_potion);

    inv.craft_grid[0] = .{ .item = .rabbit_foot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .leaping_potion);

    // Recipe 265: Cookie
    inv.craft_grid[0] = .{ .item = .wheat, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wheat, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cocoa_beans, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .cookie);
    try std.testing.expectEqual(inv.craft_output.count, 8);
}

test "ender chest, chainmail armor, mud bricks, copper bulb/grate/chiseled, brush, and decorated pot recipes 266-278" {
    var inv = Inventory.init();

    // Recipe 266: Ender Chest
    inv.craft_grid[0] = .{ .item = .obsidian, .count = 1 };
    inv.craft_grid[1] = .{ .item = .obsidian, .count = 1 };
    inv.craft_grid[2] = .{ .item = .eye_of_ender, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .ender_chest);

    // Recipes 267-270: Chainmail Armor
    inv.craft_grid[0] = .{ .item = .chain, .count = 1 };
    inv.craft_grid[1] = .{ .item = .chain, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chainmail_helmet);

    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .chain, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chainmail_chestplate);

    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chainmail_leggings);

    inv.craft_grid[1] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chainmail_boots);

    // Recipes 271-273: Mud, Packed Mud, Mud Bricks
    inv.craft_grid[0] = .{ .item = .dirt, .count = 1 };
    inv.craft_grid[1] = .{ .item = .water_bucket, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .mud);

    inv.craft_grid[0] = .{ .item = .mud, .count = 1 };
    inv.craft_grid[1] = .{ .item = .wheat, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .packed_mud);

    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .packed_mud, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .mud_bricks);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipes 274-276: Copper Bulb, Chiseled Copper, Copper Grate
    inv.craft_grid[0] = .{ .item = .copper_block, .count = 1 };
    inv.craft_grid[1] = .{ .item = .blaze_rod, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_dust, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .copper_bulb);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    inv.craft_grid[0] = .{ .item = .copper_block, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .copper_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chiseled_copper);

    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .copper_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .copper_grate);

    // Recipes 277 & 278: Brush & Decorated Pot
    inv.craft_grid[0] = .{ .item = .copper_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .stick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .string, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .brush);

    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .pottery_sherd, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .decorated_pot);

    var drops: [2]BlockDrop = undefined;
    try std.testing.expectEqual(getBlockDrops(.ender_chest, &drops), 1);
    try std.testing.expectEqual(drops[0].item, .obsidian);
    try std.testing.expectEqual(drops[0].count, 8);
}

test "breeze rod, wind charge, heavy core, mace, crafter, trial vault, enchanted golden apple, suspicious stew, and tuff recipes 279-286" {
    var inv = Inventory.init();

    // Recipe 279 & 280: Wind Charge & Mace
    inv.craft_grid[0] = .{ .item = .breeze_rod, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wind_charge);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    inv.craft_grid[1] = .{ .item = .heavy_core, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .mace);
    try std.testing.expect(ItemType.mace.isTool());
    try std.testing.expectEqual(ItemType.mace.maxDurability(), 500);

    // Recipe 281: Crafter
    inv.craft_grid[0] = .{ .item = .crafting_bench, .count = 1 };
    inv.craft_grid[1] = .{ .item = .dropper, .count = 1 };
    inv.craft_grid[2] = .{ .item = .redstone_dust, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .crafter);

    // Recipe 282 & 283: Enchanted Golden Apple & Suspicious Stew
    inv.craft_grid[0] = .{ .item = .golden_apple, .count = 1 };
    inv.craft_grid[1] = .{ .item = .gold_block, .count = 1 };
    inv.craft_grid[2] = .{ .item = .gold_block, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .enchanted_golden_apple);

    inv.craft_grid[0] = .{ .item = .mushroom_stew, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glow_berries, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .suspicious_stew);

    // Recipes 284-286: Tuff masonry
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .tuff, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .polished_tuff);

    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .polished_tuff, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .tuff_bricks);

    inv.craft_grid[0] = .{ .item = .tuff_bricks, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{ .item = .tuff_bricks, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chiseled_tuff);
}

test "calibrated sculk sensor, mangrove, and goat horn recipes 287-290" {
    var inv = Inventory.init();

    // Recipe 287: Calibrated Sculk Sensor
    inv.craft_grid[0] = .{ .item = .sculk_sensor, .count = 1 };
    inv.craft_grid[1] = .{ .item = .amethyst_shard, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .calibrated_sculk_sensor);

    // Recipe 288: Mangrove Planks
    inv.craft_grid[0] = .{ .item = .mangrove_log, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .mangrove_planks);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 289: Muddy Mangrove Roots
    inv.craft_grid[0] = .{ .item = .mangrove_roots, .count = 1 };
    inv.craft_grid[1] = .{ .item = .mud, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .muddy_mangrove_roots);
}

test "milestones 293-298 item roundtrips, properties, and recipes" {
    var inv = Inventory.init();

    // Roundtrips
    try std.testing.expectEqual(ItemType.cherry_log.toBlockId().?, .cherry_log);
    try std.testing.expectEqual(ItemType.fromBlockId(.cherry_log), .cherry_log);
    try std.testing.expectEqual(ItemType.chiseled_bookshelf.toBlockId().?, .chiseled_bookshelf);
    try std.testing.expectEqual(ItemType.fromBlockId(.chiseled_bookshelf), .chiseled_bookshelf);
    try std.testing.expectEqual(ItemType.hanging_sign.toBlockId().?, .hanging_sign);
    try std.testing.expectEqual(ItemType.fromBlockId(.hanging_sign), .hanging_sign);
    try std.testing.expectEqual(ItemType.bamboo_mosaic.toBlockId().?, .bamboo_mosaic);
    try std.testing.expectEqual(ItemType.fromBlockId(.bamboo_mosaic), .bamboo_mosaic);
    try std.testing.expectEqual(ItemType.creaking_heart.toBlockId().?, .creaking_heart);
    try std.testing.expectEqual(ItemType.fromBlockId(.creaking_heart), .creaking_heart);
    try std.testing.expectEqual(ItemType.pale_oak_log.toBlockId().?, .pale_oak_log);
    try std.testing.expectEqual(ItemType.fromBlockId(.pale_oak_log), .pale_oak_log);
    try std.testing.expectEqual(ItemType.resin_bricks.toBlockId().?, .resin_bricks);
    try std.testing.expectEqual(ItemType.fromBlockId(.resin_bricks), .resin_bricks);

    // Compostable checks
    try std.testing.expect(ItemType.cherry_leaves.isCompostable());
    try std.testing.expect(ItemType.pink_petals.isCompostable());
    try std.testing.expect(ItemType.open_eyeblossom.isCompostable());

    // Recipe 291: Cherry Planks
    inv.craft_grid[0] = .{ .item = .cherry_log, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .cherry_planks);
    try std.testing.expectEqual(inv.craft_output.count, 4);

    // Recipe 292: Chiseled Bookshelf
    inv.craft_grid[0] = .{ .item = .cherry_planks, .count = 1 };
    inv.craft_grid[1] = .{ .item = .book, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cherry_planks, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .chiseled_bookshelf);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 293: Hanging Sign
    inv.craft_grid[0] = .{ .item = .chain, .count = 1 };
    inv.craft_grid[1] = .{ .item = .chain, .count = 1 };
    inv.craft_grid[2] = .{ .item = .cherry_planks, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .hanging_sign);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 294: Bamboo Mosaic
    inv.craft_grid[0] = .{ .item = .bamboo, .count = 1 };
    inv.craft_grid[1] = .{ .item = .bamboo, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .bamboo_mosaic);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 295: Resin Bricks
    inv.craft_grid[0] = .{ .item = .resin_brick, .count = 1 };
    inv.craft_grid[1] = .{ .item = .resin_brick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .resin_brick, .count = 1 };
    inv.craft_grid[3] = .{ .item = .resin_brick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .resin_bricks);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 296: Creaking Heart
    inv.craft_grid[0] = .{ .item = .pale_oak_log, .count = 1 };
    inv.craft_grid[1] = .{ .item = .resin_bricks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .pale_oak_log, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .creaking_heart);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "Milestones 299-304 items, block roundtrips, and recipes 297-304" {
    // 1. Block to item roundtrips
    try std.testing.expectEqual(ItemType.copper_door.toBlockId().?, .copper_door_closed);
    try std.testing.expectEqual(ItemType.fromBlockId(.copper_door_closed), .copper_door);
    try std.testing.expectEqual(ItemType.fromBlockId(.copper_door_open), .copper_door);

    try std.testing.expectEqual(ItemType.copper_trapdoor.toBlockId().?, .copper_trapdoor_closed);
    try std.testing.expectEqual(ItemType.fromBlockId(.copper_trapdoor_closed), .copper_trapdoor);
    try std.testing.expectEqual(ItemType.fromBlockId(.copper_trapdoor_open), .copper_trapdoor);

    try std.testing.expectEqual(ItemType.ominous_vault.toBlockId().?, .ominous_vault);
    try std.testing.expectEqual(ItemType.fromBlockId(.ominous_vault), .ominous_vault);

    // 2. Durabilities, stack sizes, and tool classification
    try std.testing.expectEqual(ItemType.wolf_armor.maxDurability(), 64);
    try std.testing.expect(ItemType.wolf_armor.isTool());
    try std.testing.expectEqual(ItemType.wolf_armor.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.bundle.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.music_disc_5.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.music_disc_relic.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.music_disc_precipice.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.music_disc_creator.maxStackSize(), 1);
    try std.testing.expectEqual(ItemType.ominous_bottle.maxStackSize(), 16);
    try std.testing.expectEqual(ItemType.potion_of_wind_charged.maxStackSize(), 16);
    try std.testing.expectEqual(ItemType.armadillo_scute.maxStackSize(), 64);
    try std.testing.expectEqual(ItemType.disc_fragment_5.maxStackSize(), 64);

    // 3. Names
    try std.testing.expectEqualStrings(ItemType.armadillo_scute.name(), "Armadillo Scute");
    try std.testing.expectEqualStrings(ItemType.wolf_armor.name(), "Wolf Armor");
    try std.testing.expectEqualStrings(ItemType.ominous_bottle.name(), "Ominous Bottle");
    try std.testing.expectEqualStrings(ItemType.ominous_trial_key.name(), "Ominous Trial Key");
    try std.testing.expectEqualStrings(ItemType.ominous_vault.name(), "Ominous Vault");
    try std.testing.expectEqualStrings(ItemType.potion_of_infested.name(), "Potion of Infested");
    try std.testing.expectEqualStrings(ItemType.potion_of_oozing.name(), "Potion of Oozing");
    try std.testing.expectEqualStrings(ItemType.potion_of_weaving.name(), "Potion of Weaving");
    try std.testing.expectEqualStrings(ItemType.potion_of_wind_charged.name(), "Potion of Wind Charged");
    try std.testing.expectEqualStrings(ItemType.bundle.name(), "Bundle");
    try std.testing.expectEqualStrings(ItemType.copper_door.name(), "Copper Door");
    try std.testing.expectEqualStrings(ItemType.copper_trapdoor.name(), "Copper Trapdoor");
    try std.testing.expectEqualStrings(ItemType.disc_fragment_5.name(), "Disc Fragment (5)");
    try std.testing.expectEqualStrings(ItemType.music_disc_5.name(), "Music Disc (5)");

    var inv = Inventory.init();

    // Recipe 297: Wolf Armor (4 Armadillo Scutes)
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .armadillo_scute, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .wolf_armor);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 298: Ominous Trial Key (1 Trial Key + 1 Ominous Bottle)
    inv.craft_grid[0] = .{ .item = .trial_key, .count = 1 };
    inv.craft_grid[1] = .{ .item = .ominous_bottle, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .ominous_trial_key);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 299: Ominous Vault (1 Vault + 1 Ominous Bottle)
    inv.craft_grid[0] = .{ .item = .vault, .count = 1 };
    inv.craft_grid[1] = .{ .item = .ominous_bottle, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .ominous_vault);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 300: Trial Alchemy (Wind Charge + Glass -> Potion of Wind Charged)
    inv.craft_grid[0] = .{ .item = .wind_charge, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .potion_of_wind_charged);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 300: Trial Alchemy (Slimeball + Glass -> Potion of Oozing)
    inv.craft_grid[0] = .{ .item = .slimeball, .count = 1 };
    inv.craft_grid[1] = .{ .item = .glass, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .potion_of_oozing);

    // Recipe 301: Bundle (1 String + 1 Leather)
    inv.craft_grid[0] = .{ .item = .string, .count = 1 };
    inv.craft_grid[1] = .{ .item = .leather, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .bundle);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 302: Copper Door (3 Copper Ingots)
    inv.craft_grid[0] = .{ .item = .copper_ingot, .count = 1 };
    inv.craft_grid[1] = .{ .item = .copper_ingot, .count = 1 };
    inv.craft_grid[2] = .{ .item = .copper_ingot, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .copper_door);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    // Recipe 303: Copper Trapdoor (1 Copper Door)
    inv.craft_grid[0] = .{ .item = .copper_door, .count = 1 };
    inv.craft_grid[1] = .{};
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .copper_trapdoor);
    try std.testing.expectEqual(inv.craft_output.count, 2);

    // Recipe 304: Music Disc 5 (4 Disc Fragments)
    for (&inv.craft_grid) |*sl| sl.* = .{ .item = .disc_fragment_5, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .music_disc_5);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}


test "Wave 3 representative items roundtrip, properties and recipes" {
    try std.testing.expectEqual(ItemType.fromBlockId(.dried_ghast), .dried_ghast);
    try std.testing.expectEqual(ItemType.dried_ghast.toBlockId().?, .dried_ghast);
    try std.testing.expectEqual(ItemType.fromBlockId(.sculk_catalyst), .sculk_catalyst);
    try std.testing.expectEqual(ItemType.fromBlockId(.sculk_shrieker), .sculk_shrieker);
    try std.testing.expectEqual(ItemType.fromBlockId(.firefly_bush), .firefly_bush);
    try std.testing.expectEqual(ItemType.fromBlockId(.leaf_litter), .leaf_litter);
    try std.testing.expectEqualStrings(ItemType.ghast_harness.name(), "Ghast Harness");
    try std.testing.expectEqualStrings(ItemType.bucket_of_axolotl.name(), "Bucket of Axolotl");
    try std.testing.expectEqualStrings(ItemType.banner_pattern_stencil.name(), "Banner Pattern Stencil");
    try std.testing.expectEqualStrings(ItemType.copper_golem_statue.name(), "Copper Golem Statue");
    try std.testing.expectEqual(ItemType.banner.maxStackSize(), 1);
    try std.testing.expect(ItemType.firefly_bush.getColor()[1] > ItemType.firefly_bush.getColor()[0]);

    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .bone, .count = 1 };
    inv.craft_grid[1] = .{ .item = .bone, .count = 1 };
    inv.craft_grid[2] = .{};
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .dried_ghast);
    try std.testing.expectEqual(inv.craft_output.count, 1);

    inv.craft_grid = .{ .{ .item = .wool, .count = 1 }, .{ .item = .wool, .count = 1 }, .{ .item = .wool, .count = 1 }, .{ .item = .stick, .count = 1 } };
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .banner);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "Wave 4 representative item metadata and 2x2 recipes" {
    try std.testing.expectEqual(@as(u16, 447), @intFromEnum(ItemType.sweet_berry_fox_treat));
    try std.testing.expectEqualStrings("Mending Book", ItemType.mending_book.name());
    try std.testing.expectEqualStrings("Turtle Egg", ItemType.turtle_egg.name());
    try std.testing.expectEqual(@as(u8, 1), ItemType.enchanted_book.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.potion_of_turtle_master.maxStackSize());
    try std.testing.expect(ItemType.seagrass.isCompostable());
    try std.testing.expect(ItemType.sweet_berry_fox_treat.getColor()[0] > ItemType.sweet_berry_fox_treat.getColor()[1]);

    var inv = Inventory.init();
    inv.craft_grid = .{ .{ .item = .book, .count = 1 }, .{ .item = .lapis_lazuli, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.enchanted_book, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .enchanted_book, .count = 1 }, .{ .item = .emerald, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.mending_book, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .turtle_egg, .count = 1 }, .{ .item = .seagrass, .count = 1 }, .{ .item = .potion_of_turtle_master, .count = 1 }, .{ .item = .turtle_helmet, .count = 1 } };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.sweet_berry_fox_treat, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 2), inv.craft_output.count);
}

test "Wave 5 trophy and splash potion item metadata and recipes" {
    try std.testing.expectEqual(@as(u16, 448), @intFromEnum(ItemType.zombie_head));
    try std.testing.expectEqual(@as(u16, 453), @intFromEnum(ItemType.splash_harming_potion));
    try std.testing.expectEqualStrings("Skeleton Skull", ItemType.skeleton_skull.name());
    try std.testing.expectEqual(@as(u8, 64), ItemType.creeper_head.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.splash_water_bottle.maxStackSize());
    try std.testing.expect(ItemType.piglin_head.getColor()[0] > ItemType.piglin_head.getColor()[1]);

    var inv = Inventory.init();
    inv.craft_grid = .{ .{ .item = .water_bottle, .count = 1 }, .{ .item = .gunpowder, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.splash_water_bottle, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .harming_potion, .count = 1 }, .{ .item = .gunpowder, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.splash_harming_potion, inv.craft_output.item);
}

test "Wave 6 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 456), @intFromEnum(ItemType.wither_rose));
    try std.testing.expectEqual(@as(u16, 461), @intFromEnum(ItemType.heavy_weighted_pressure_plate));
    try std.testing.expectEqual(@as(u8, 64), ItemType.wither_rose.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.name_tag.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.saddle.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.glazed_terracotta.maxStackSize());
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    try std.testing.expectEqualStrings("Wither Rose", ItemType.wither_rose.name());
    try std.testing.expectEqualStrings("Name Tag", ItemType.name_tag.name());
    try std.testing.expect(ItemType.wither_rose.getColor()[0] < 0.2);

    var inv = Inventory.init();
    inv.craft_grid = .{ .{ .item = .terracotta, .count = 1 }, .{ .item = .terracotta, .count = 1 }, .{ .item = .terracotta, .count = 1 }, .{ .item = .terracotta, .count = 1 } };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.glazed_terracotta, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .gold_nugget, .count = 1 }, .{ .item = .gold_nugget, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.light_weighted_pressure_plate, inv.craft_output.item);

    inv.craft_grid = .{ .{}, .{}, .{ .item = .iron_ingot, .count = 1 }, .{ .item = .iron_ingot, .count = 1 } };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.heavy_weighted_pressure_plate, inv.craft_output.item);
}

test "Wave 7 item metadata and map and glass pane recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 462), @intFromEnum(ItemType.empty_locator_map));
    try std.testing.expectEqual(@as(u16, 469), @intFromEnum(ItemType.frost_walker_boots));
    try std.testing.expectEqual(@as(u8, 1), ItemType.empty_locator_map.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.diamond_horse_armor.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.glass_pane.maxStackSize());
    try std.testing.expect(ItemType.frost_walker_boots.isArmor());
    try std.testing.expectEqual(@as(u16, 195), ItemType.frost_walker_boots.maxDurability());
    try std.testing.expectEqualStrings("Explorer Map", ItemType.filled_explorer_map.name());
    try std.testing.expect(ItemType.glass_pane.getColor()[3] < 1.0);
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));

    var inv = Inventory.init();
    inv.craft_grid = .{ .{ .item = .paper, .count = 1 }, .{ .item = .compass, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.empty_locator_map, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .empty_locator_map, .count = 1 }, .{ .item = .filled_explorer_map, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.filled_explorer_map, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 2), inv.craft_output.count);

    inv.craft_grid = .{ .{ .item = .glass, .count = 1 }, .{ .item = .glass, .count = 1 }, .{ .item = .glass, .count = 1 }, .{ .item = .glass, .count = 1 } };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.glass_pane, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 4), inv.craft_output.count);
}

test "Wave 8 item metadata and enchanted book recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 470), @intFromEnum(ItemType.swift_sneak_book));
    try std.testing.expectEqual(@as(u16, 474), @intFromEnum(ItemType.sweeping_edge_book));
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    try std.testing.expectEqual(@as(u8, 1), ItemType.swift_sneak_book.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.sweeping_edge_book.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.milk_bucket.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.reinforced_deepslate.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.bottle_o_enchanting.maxStackSize());
    try std.testing.expectEqualStrings("Reinforced Deepslate", ItemType.reinforced_deepslate.name());
    try std.testing.expectEqualStrings("Milk Bucket", ItemType.milk_bucket.name());
    try std.testing.expectEqualStrings("Bottle o' Enchanting", ItemType.bottle_o_enchanting.name());
    try std.testing.expect(ItemType.reinforced_deepslate.getColor()[0] < ItemType.reinforced_deepslate.getColor()[1]);

    var inv = Inventory.init();
    inv.craft_grid = .{ .{ .item = .book, .count = 1 }, .{ .item = .echo_shard, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.swift_sneak_book, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .enchanted_book, .count = 1 }, .{ .item = .diamond, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.sweeping_edge_book, inv.craft_output.item);
}

test "Wave 9 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 475), @intFromEnum(ItemType.arrow_of_slowness));
    try std.testing.expectEqual(@as(u16, 480), @intFromEnum(ItemType.stained_glass));
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    try std.testing.expectEqual(@as(u8, 64), ItemType.arrow_of_slowness.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.item_frame.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.glow_item_frame.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.painting.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.feather_falling_book.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.stained_glass.maxStackSize());
    try std.testing.expectEqualStrings("Arrow of Slowness", ItemType.arrow_of_slowness.name());
    try std.testing.expectEqualStrings("Glow Item Frame", ItemType.glow_item_frame.name());
    try std.testing.expect(ItemType.stained_glass.getColor()[3] < 1.0);

    var inv = Inventory.init();
    inv.craft_grid = .{ .{ .item = .arrow, .count = 1 }, .{ .item = .potion_of_slowness, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.arrow_of_slowness, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .leather, .count = 1 }, .{ .item = .stick, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.item_frame, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .item_frame, .count = 1 }, .{ .item = .glowstone, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.glow_item_frame, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .wool, .count = 1 }, .{ .item = .paper, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.painting, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .book, .count = 1 }, .{ .item = .slow_falling_potion, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.feather_falling_book, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .glass, .count = 1 }, .{ .item = .lapis_lazuli, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.stained_glass, inv.craft_output.item);
}


test "Wave 10 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 482), @intFromEnum(ItemType.red_sandstone));
    try std.testing.expectEqual(@as(u16, 483), @intFromEnum(ItemType.concrete_powder));
    try std.testing.expectEqual(@as(u16, 484), @intFromEnum(ItemType.concrete_block));
    try std.testing.expectEqual(@as(u16, 485), @intFromEnum(ItemType.buried_treasure_map));
    try std.testing.expectEqual(@as(u16, 486), @intFromEnum(ItemType.heart_of_the_sea));
    try std.testing.expectEqual(@as(u16, 487), @intFromEnum(ItemType.firework_star));
    try std.testing.expectEqual(@as(u16, 488), @intFromEnum(ItemType.acacia_planks));
    try std.testing.expectEqual(@as(u16, 489), @intFromEnum(ItemType.dark_oak_planks));
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));

    try std.testing.expectEqual(@as(u8, 64), ItemType.red_sandstone.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.concrete_powder.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.concrete_block.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.buried_treasure_map.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.heart_of_the_sea.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.firework_star.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.acacia_planks.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.dark_oak_planks.maxStackSize());

    try std.testing.expectEqualStrings("Red Sandstone", ItemType.red_sandstone.name());
    try std.testing.expectEqualStrings("Concrete Powder", ItemType.concrete_powder.name());
    try std.testing.expectEqualStrings("Concrete", ItemType.concrete_block.name());
    try std.testing.expectEqualStrings("Buried Treasure Map", ItemType.buried_treasure_map.name());
    try std.testing.expectEqualStrings("Heart of the Sea", ItemType.heart_of_the_sea.name());
    try std.testing.expectEqualStrings("Firework Star", ItemType.firework_star.name());
    try std.testing.expectEqualStrings("Acacia Planks", ItemType.acacia_planks.name());
    try std.testing.expectEqualStrings("Dark Oak Planks", ItemType.dark_oak_planks.name());

    var inv = Inventory.init();
    inv.craft_grid = .{ .{ .item = .sandstone, .count = 1 }, .{ .item = .brick, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.red_sandstone, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .sand, .count = 1 }, .{ .item = .clay_ball, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.concrete_powder, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .concrete_powder, .count = 1 }, .{ .item = .water_bucket, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.concrete_block, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .empty_locator_map, .count = 1 }, .{ .item = .heart_of_the_sea, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.buried_treasure_map, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .gunpowder, .count = 1 }, .{ .item = .glowstone, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.firework_star, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .wood_planks, .count = 1 }, .{ .item = .torch, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.acacia_planks, inv.craft_output.item);

    inv.craft_grid = .{ .{ .item = .wood_planks, .count = 1 }, .{ .item = .coal, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.dark_oak_planks, inv.craft_output.item);
}


test "Wave 11 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 490), @intFromEnum(ItemType.music_disc_pigstep));
    try std.testing.expectEqual(@as(u16, 491), @intFromEnum(ItemType.netherite_upgrade_template));
    try std.testing.expectEqual(@as(u16, 492), @intFromEnum(ItemType.sniffer_egg));
    try std.testing.expectEqual(@as(u16, 493), @intFromEnum(ItemType.suspicious_gravel));
    try std.testing.expectEqual(@as(u16, 494), @intFromEnum(ItemType.coral_block));
    try std.testing.expectEqual(@as(u16, 495), @intFromEnum(ItemType.dead_coral_block));
    try std.testing.expectEqual(@as(u16, 496), @intFromEnum(ItemType.lily_pad));
    try std.testing.expectEqual(@as(u16, 497), @intFromEnum(ItemType.frogspawn));
    try std.testing.expectEqual(@as(u16, 498), @intFromEnum(ItemType.bucket_of_tadpole));
    try std.testing.expectEqual(@as(u16, 499), @intFromEnum(ItemType.book_and_quill));
    try std.testing.expectEqual(@as(u16, 500), @intFromEnum(ItemType.written_book));
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));

    try std.testing.expectEqual(@as(u8, 1), ItemType.music_disc_pigstep.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.netherite_upgrade_template.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.sniffer_egg.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.suspicious_gravel.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.coral_block.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.dead_coral_block.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.lily_pad.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.frogspawn.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.bucket_of_tadpole.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.book_and_quill.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.written_book.maxStackSize());

    try std.testing.expectEqualStrings("Music Disc Pigstep", ItemType.music_disc_pigstep.name());
    try std.testing.expectEqualStrings("Netherite Upgrade Template", ItemType.netherite_upgrade_template.name());
    try std.testing.expectEqualStrings("Sniffer Egg", ItemType.sniffer_egg.name());
    try std.testing.expectEqualStrings("Suspicious Gravel", ItemType.suspicious_gravel.name());
    try std.testing.expectEqualStrings("Coral Block", ItemType.coral_block.name());
    try std.testing.expectEqualStrings("Dead Coral Block", ItemType.dead_coral_block.name());
    try std.testing.expectEqualStrings("Lily Pad", ItemType.lily_pad.name());
    try std.testing.expectEqualStrings("Frogspawn", ItemType.frogspawn.name());
    try std.testing.expectEqualStrings("Bucket of Tadpole", ItemType.bucket_of_tadpole.name());
    try std.testing.expectEqualStrings("Book and Quill", ItemType.book_and_quill.name());
    try std.testing.expectEqualStrings("Written Book", ItemType.written_book.name());

    var inv = Inventory.init();
    inv.craft_grid = .{ .{ .item = .diamond, .count = 1 }, .{ .item = .netherrack, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.netherite_upgrade_template, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 2), inv.craft_output.count);

    inv.craft_grid = .{ .{ .item = .book, .count = 1 }, .{ .item = .coal, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.book_and_quill, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);

    inv.craft_grid = .{ .{ .item = .book_and_quill, .count = 1 }, .{ .item = .paper, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.written_book, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);

    inv.craft_grid = .{ .{ .item = .leaves, .count = 1 }, .{ .item = .seagrass, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.lily_pad, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);

    inv.craft_grid = .{ .{ .item = .sea_pickle, .count = 1 }, .{ .item = .kelp, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.coral_block, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);

    inv.craft_grid = .{ .{ .item = .water_bucket, .count = 1 }, .{ .item = .slimeball, .count = 1 }, .{}, .{} };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.bucket_of_tadpole, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);
}


test "Wave 12 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 501), @intFromEnum(ItemType.bone_block));
    try std.testing.expectEqual(@as(u16, 510), @intFromEnum(ItemType.clock));
    try std.testing.expectEqual(@as(u8, 16), ItemType.awkward_potion.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.invisibility_potion.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.bone_block.maxStackSize());
    try std.testing.expectEqualStrings("Potion of Invisibility", ItemType.invisibility_potion.name());
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType, count: u8 }{
        .{ .a = .bone_meal, .b = .bone, .out = .bone_block, .count = 1 },
        .{ .a = .dirt, .b = .hanging_roots, .out = .rooted_dirt, .count = 1 },
        .{ .a = .water_bottle, .b = .nether_wart, .out = .awkward_potion, .count = 1 },
        .{ .a = .night_vision_potion, .b = .fermented_spider_eye, .out = .invisibility_potion, .count = 1 },
        .{ .a = .gold_block, .b = .redstone_dust, .out = .clock, .count = 1 },
        .{ .a = .moss_block, .b = .lily_pad, .out = .big_dripleaf, .count = 2 },
    };
    for (recipes) |recipe| {
        inv.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe.out, inv.craft_output.item);
        try std.testing.expectEqual(recipe.count, inv.craft_output.count);
    }
}


test "Wave 13 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 511), @intFromEnum(ItemType.sunflower));
    try std.testing.expectEqual(@as(u16, 521), @intFromEnum(ItemType.bed));
    try std.testing.expectEqual(@as(u8, 1), ItemType.chest_boat.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.bamboo_raft.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.bed.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.sunflower.maxStackSize());
    try std.testing.expectEqualStrings("Sunflower", ItemType.sunflower.name());
    try std.testing.expectEqualStrings("Bed", ItemType.bed.name());
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType, count: u8 }{ .{ .a = .cobblestone, .b = .moss_block, .out = .mossy_cobblestone, .count = 1 }, .{ .a = .boat, .b = .chest, .out = .chest_boat, .count = 1 }, .{ .a = .bamboo_mosaic, .b = .bamboo, .out = .bamboo_raft, .count = 1 }, .{ .a = .wool, .b = .wood_planks, .out = .bed, .count = 1 }, .{ .a = .sunflower, .b = .bone_meal, .out = .sunflower, .count = 2 }, .{ .a = .dirt, .b = .leaf_litter, .out = .podzol, .count = 1 } };
    for (recipes) |recipe_item| { inv.craft_grid = .{ .{ .item = recipe_item.a, .count = 1 }, .{ .item = recipe_item.b, .count = 1 }, .{}, .{} }; inv.updateCrafting(); try std.testing.expectEqual(recipe_item.out, inv.craft_output.item); try std.testing.expectEqual(recipe_item.count, inv.craft_output.count); }
}
