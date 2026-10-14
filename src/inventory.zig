const std = @import("std");
const block_mod = @import("world/block.zig");
pub const BlockId = block_mod.BlockId;

pub const ItemType = enum(u8) {
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
            .cobweb => .cobweb,
            .end_stone => .end_stone,
            .end_portal_frame => .end_portal_frame,
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
            .cobweb => .cobweb,
            .end_stone => .end_stone,
            .end_portal_frame, .end_portal_frame_filled => .end_portal_frame,
        };
    }


    pub fn isArmor(self: ItemType) bool {
        return switch (self) {
            .netherite_helmet, .netherite_chestplate, .netherite_leggings, .netherite_boots, .soul_speed_boots => true,
            else => false,
        };
    }

    pub fn maxDurability(self: ItemType) u16 {
        return switch (self) {
            .wooden_pickaxe => 25,
            .iron_pickaxe => 120,
            .iron_sword => 100,
            .netherite_pickaxe => 350,
            .netherite_sword => 400,
            .warped_fungus_on_a_stick => 100,
            .netherite_chestplate => 500,
            .soul_speed_boots => 300,
            .netherite_helmet => 450,
            .netherite_leggings => 475,
            .netherite_boots => 425,
            .bow => 384,
            .shield => 336,
            .crossbow => 465,
            else => 0,
        };
    }


    pub fn isCompostable(self: ItemType) bool {
        return switch (self) {
            .leaves, .hay_bale, .crimson_fungus, .warped_fungus, .weeping_vines, .twisting_vines, .nether_wart, .cactus, .raw_pork, .raw_mutton, .rotten_flesh => true,
            else => false,
        };
    }

    pub fn isTool(self: ItemType) bool {
        return self.maxDurability() > 0;
    }

    pub fn maxStackSize(self: ItemType) u8 {
        return switch (self) {
            .none => 0,
            .armor_stand, .target_dummy, .ender_pearl => 16,
            .wooden_pickaxe, .iron_pickaxe, .netherite_pickaxe, .iron_sword, .netherite_sword, .warped_fungus_on_a_stick, .netherite_chestplate, .soul_speed_boots, .netherite_helmet, .netherite_leggings, .netherite_boots, .bow, .shield, .lodestone_compass, .crossbow, .music_disc_13, .music_disc_cat => 1,
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

        // Recipe 25: 4 Iron Ingots (2x2 filled) -> 1 Iron Door
        if (non_empty == 4) {
            if (g0 == .iron_ingot and g1 == .iron_ingot and g2 == .iron_ingot and g3 == .iron_ingot) {
                self.craft_output = .{ .item = .iron_door, .count = 1 };
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

        // Recipe 61: Netherite Boots: 1 Netherite Ingot + 1 Gold Nugget (or 1 Netherite Scrap + 1 Gold Nugget) -> 1 Netherite Boots
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot or
                            g0 == .netherite_scrap or g1 == .netherite_scrap or g2 == .netherite_scrap or g3 == .netherite_scrap);
            const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget);
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

        // Recipe 59: Netherite Leggings: 1 Netherite Ingot + 1 Obsidian (or 2 Netherite Scrap) -> 1 Netherite Leggings
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_obs = (g0 == .obsidian or g1 == .obsidian or g2 == .obsidian or g3 == .obsidian);
            var scraps: u8 = 0;
            for (self.craft_grid) |sl| {
                if (sl.item == .netherite_scrap) scraps += 1;
            }
            if ((has_ni and has_obs) or scraps == 2) {
                self.craft_output = .{ .item = .netherite_leggings, .count = 1 };
                return;
            }
        }

        // Recipe 58: Netherite Helmet: 1 Netherite Ingot + 1 Coal (or 1 Iron Ingot + 1 Netherite Scrap) -> 1 Netherite Helmet
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_coal = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal);
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

        // Recipe 56: Netherite Chestplate: 1 Netherite Ingot + 1 Iron Ingot (or 3 Netherite Ingot) -> 1 Netherite Chestplate
        if (non_empty == 2) {
            const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
            if (has_ni and has_iron) {
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

        // Recipe 40: Netherite Sword: 1 Iron Sword + 1 Netherite Ingot (non_empty == 2) -> 1 Netherite Sword
        if (non_empty == 2) {
            const has_sword = (g0 == .iron_sword or g1 == .iron_sword or g2 == .iron_sword or g3 == .iron_sword);
            const has_ingot = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
            if (has_sword and has_ingot) {
                self.craft_output = .{ .item = .netherite_sword, .count = 1 };
                return;
            }
        }

        // Recipe 39: Netherite Pickaxe: 1 Iron Pickaxe + 1 Netherite Ingot (non_empty == 2) -> 1 Netherite Pickaxe
        if (non_empty == 2) {
            const has_pick = (g0 == .iron_pickaxe or g1 == .iron_pickaxe or g2 == .iron_pickaxe or g3 == .iron_pickaxe);
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
    const need = block_mod.requiredTier(block);
    if (need == .hand) return true;
    return held == .wooden_pickaxe or held == .iron_pickaxe or held == .netherite_pickaxe;
}

pub const MobType = enum { sheep, pig, wolf, emberbeast, wither_skeleton, piglin, piglin_brute, blaze, target_dummy, spider, skeleton, zombie, creeper, enderman };

pub fn getMobMeatDrop(mob_type: MobType) ItemType {
    return switch (mob_type) {
        .pig => .raw_pork,
        .sheep => .raw_mutton,
        .wolf => .none,
        .emberbeast => .coal,
        .wither_skeleton => .coal,
        .piglin, .piglin_brute => .gold_nugget,
        .blaze => .blaze_rod,
        .target_dummy => .hay_bale,
        .spider => .string,
        .skeleton => .bone,
        .zombie => .rotten_flesh,
        .creeper => .gunpowder,
        .enderman => .ender_pearl,
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
    } else if (block == .cobweb) {
        out[0] = .{ .item = .string, .count = 1 };
        return 1;
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

    try std.testing.expectEqual(ItemType.string.toBlockId(), null);
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
