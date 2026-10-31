const std = @import("std");
const items_mod = @import("items.zig");

pub const ItemType = items_mod.ItemType;
pub const ItemStack = items_mod.ItemStack;

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
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .cobblestone;
        flags[1] = flags[1] or slot.item == .moss_block;
        flags[2] = flags[2] or slot.item == .boat;
        flags[3] = flags[3] or slot.item == .chest;
        flags[4] = flags[4] or slot.item == .bamboo_mosaic;
        flags[5] = flags[5] or slot.item == .bamboo;
        flags[6] = flags[6] or slot.item == .wool;
        flags[7] = flags[7] or slot.item == .wood_planks;
        flags[8] = flags[8] or slot.item == .sunflower;
        flags[9] = flags[9] or slot.item == .bone_meal;
        flags[10] = flags[10] or slot.item == .dirt;
        flags[11] = flags[11] or slot.item == .leaf_litter;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .mossy_cobblestone, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .chest_boat, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .bamboo_raft, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .bed, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .sunflower, .count = 2 };
    if (flags[10] and flags[11]) return .{ .item = .podzol, .count = 1 };
    return null;
}

fn wave14CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .cobblestone;
        flags[1] = flags[1] or slot.item == .nether_quartz;
        flags[2] = flags[2] or slot.item == .diorite;
        flags[3] = flags[3] or slot.item == .cobblestone;
        flags[4] = flags[4] or slot.item == .granite;
        flags[5] = flags[5] or slot.item == .stonecutter;
        flags[6] = flags[6] or slot.item == .oak_fence;
        flags[7] = flags[7] or slot.item == .stick;
        flags[8] = flags[8] or slot.item == .sculk;
        flags[9] = flags[9] or slot.item == .echo_shard;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .diorite, .count = 2 };
    if (flags[2] and flags[1]) return .{ .item = .granite, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .andesite, .count = 2 };
    if (flags[4] and flags[5]) return .{ .item = .polished_granite, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .fence_gate, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .sculk_vein, .count = 4 };
    return null;
}

fn wave15CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .ender_pearl;
        flags[1] = flags[1] or slot.item == .obsidian;
        flags[2] = flags[2] or slot.item == .redstone_torch;
        flags[3] = flags[3] or slot.item == .iron_ingot;
        flags[4] = flags[4] or slot.item == .clock;
        flags[5] = flags[5] or slot.item == .lapis_lazuli;
        flags[6] = flags[6] or slot.item == .redstone_repeater;
        flags[7] = flags[7] or slot.item == .lever;
        flags[8] = flags[8] or slot.item == .observer;
        flags[9] = flags[9] or slot.item == .slime_block;
        flags[10] = flags[10] or slot.item == .banner;
        flags[11] = flags[11] or slot.item == .rotten_flesh;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .chunk_loader_token, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .redstone_inverter_core, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .moon_phase_talisman, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .repeater_latch_lock, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .flying_machine_core, .count = 1 };
    if (flags[10] and flags[11]) return .{ .item = .zombie_siege_banner, .count = 1 };
    return null;
}

fn wave16CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .target_block;
        flags[1] = flags[1] or slot.item == .redstone_block;
        flags[2] = flags[2] or slot.item == .lightning_rod;
        flags[3] = flags[3] or slot.item == .copper_ingot;
        flags[4] = flags[4] or slot.item == .packed_ice;
        flags[5] = flags[5] or slot.item == .snowball;
        flags[6] = flags[6] or slot.item == .soul_sand;
        flags[7] = flags[7] or slot.item == .gold_nugget;
        flags[8] = flags[8] or slot.item == .composter;
        flags[9] = flags[9] or slot.item == .bone_meal;
        flags[10] = flags[10] or slot.item == .tripwire_hook;
        flags[11] = flags[11] or slot.item == .string;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .target_block_core, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .lightning_deflector, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .frosted_ice_shard, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .soul_speed_talisman, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .composter_catalyst, .count = 1 };
    if (flags[10] and flags[11]) return .{ .item = .tripwire_tension_gauge, .count = 1 };
    return null;
}

fn wave17CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    var amethyst_shards: u16 = 0;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .sculk;
        flags[1] = flags[1] or slot.item == .bone_meal;
        flags[2] = flags[2] or slot.item == .sculk_sensor;
        flags[3] = flags[3] or slot.item == .amethyst_shard;
        if (slot.item == .amethyst_shard) amethyst_shards += slot.count;
        flags[4] = flags[4] or slot.item == .chain;
        flags[5] = flags[5] or slot.item == .wooden_slab;
        flags[6] = flags[6] or slot.item == .saddle;
        flags[7] = flags[7] or slot.item == .cactus;
        flags[8] = flags[8] or slot.item == .clay;
        flags[9] = flags[9] or slot.item == .brick;
        flags[10] = flags[10] or slot.item == .resin_brick;
        flags[11] = flags[11] or slot.item == .stone_bricks;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .sculk_bloom_catalyst, .count = 1 };
    // The exact one-shard recipe makes the tuner; the legacy calibrated sensor
    // recipe remains available with two or three shards.
    if (flags[2] and flags[3] and amethyst_shards == 1) return .{ .item = .calibrated_sensor_tuner, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .hanging_chain_mount, .count = 2 };
    if (flags[6] and flags[7]) return .{ .item = .camel_bridle_saddle, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .decorated_pot_motif, .count = 1 };
    if (flags[10] and flags[11]) return .{ .item = .resin_brick_masonry, .count = 1 };
    return null;
}

fn wave18CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .torchflower_seeds;
        flags[1] = flags[1] or slot.item == .pitcher_pod;
        flags[2] = flags[2] or slot.item == .trial_key;
        flags[3] = flags[3] or slot.item == .copper_ingot;
        flags[4] = flags[4] or slot.item == .breeze_rod;
        flags[5] = flags[5] or slot.item == .wind_charge;
        flags[6] = flags[6] or slot.item == .heavy_core;
        flags[7] = flags[7] or slot.item == .mace;
        flags[8] = flags[8] or slot.item == .crafter;
        flags[9] = flags[9] or slot.item == .redstone_block;
        flags[10] = flags[10] or slot.item == .copper_bulb;
        flags[11] = flags[11] or slot.item == .redstone_torch;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .sniffer_egg_ancient, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .trial_key_master, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .breeze_wind_charge_core, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .mace_density_core, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .crafter_pulse_core, .count = 1 };
    if (flags[10] and flags[11]) return .{ .item = .copper_bulb_core, .count = 1 };
    return null;
}

fn wave21CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .gold_ingot;
        flags[1] = flags[1] or slot.item == .leather;
        flags[2] = flags[2] or slot.item == .gold_block;
        flags[3] = flags[3] or slot.item == .warped_fungus;
        flags[4] = flags[4] or slot.item == .string;
        flags[5] = flags[5] or slot.item == .crimson_fungus;
        flags[6] = flags[6] or slot.item == .lead;
        flags[7] = flags[7] or slot.item == .slimeball;
        flags[8] = flags[8] or slot.item == .sweet_berries;
        flags[9] = flags[9] or slot.item == .wheat;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .piglin_barter_token, .count = 1 };
    if (flags[0] and flags[2]) return .{ .item = .piglin_brute_armband, .count = 1 };
    if (flags[3] and flags[4]) return .{ .item = .strider_lava_harness, .count = 1 };
    if (flags[5] and flags[3]) return .{ .item = .nether_fungus_spores, .count = 2 };
    if (flags[6] and flags[7]) return .{ .item = .reinforced_elastic_lead, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .sweet_berry_basket, .count = 1 };
    return null;
}

fn wave22CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .copper_horn;
        flags[1] = flags[1] or slot.item == .copper_ingot;
        flags[2] = flags[2] or slot.item == .sculk;
        flags[3] = flags[3] or slot.item == .sculk_sensor;
        flags[4] = flags[4] or slot.item == .saddle;
        flags[5] = flags[5] or slot.item == .lead;
        flags[6] = flags[6] or slot.item == .mace;
        flags[7] = flags[7] or slot.item == .wind_charge;
        flags[8] = flags[8] or slot.item == .copper_bulb;
        flags[9] = flags[9] or slot.item == .redstone_dust;
        flags[10] = flags[10] or slot.item == .dragon_egg;
        flags[11] = flags[11] or slot.item == .end_crystal;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .copper_horn_instrument, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .sculk_bloom_core, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .camel_dash_saddle, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .mace_combo_catalyst, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .copper_bulb_display_module, .count = 1 };
    if (flags[10] and flags[11]) return .{ .item = .dragon_fountain_essence, .count = 1 };
    return null;
}

fn wave23CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .blaze_rod;
        flags[1] = flags[1] or slot.item == .fire_charge;
        flags[2] = flags[2] or slot.item == .magma_cream;
        flags[3] = flags[3] or slot.item == .slimeball;
        flags[4] = flags[4] or slot.item == .ghast_tear;
        flags[5] = flags[5] or slot.item == .nether_wart;
        flags[6] = flags[6] or slot.item == .wither_skull;
        flags[7] = flags[7] or slot.item == .coal;
        flags[8] = flags[8] or slot.item == .nether_star;
        flags[9] = flags[9] or slot.item == .obsidian;
        flags[10] = flags[10] or slot.item == .prismarine_shard;
        flags[11] = flags[11] or slot.item == .prismarine_crystals;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .blaze_artillery_core, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .magma_cream_catalyst, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .ghast_tear_essence, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .wither_skull_relic, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .nether_star_core, .count = 1 };
    if (flags[10] and flags[11]) return .{ .item = .conduit_power_orb, .count = 1 };
    return null;
}

fn wave25CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .echo_shard;
        flags[1] = flags[1] or slot.item == .sculk_catalyst;
        flags[2] = flags[2] or slot.item == .sculk;
        flags[3] = flags[3] or slot.item == .bone;
        flags[4] = flags[4] or slot.item == .amethyst_shard;
        flags[5] = flags[5] or slot.item == .copper_ingot;
        flags[6] = flags[6] or slot.item == .wind_charge;
        flags[7] = flags[7] or slot.item == .gunpowder;
        flags[8] = flags[8] or slot.item == .mace;
        flags[9] = flags[9] or slot.item == .breeze_rod;
        flags[10] = flags[10] or slot.item == .crafter;
        flags[11] = flags[11] or slot.item == .iron_ingot;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .warden_sonic_pulse_matrix, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .shrieker_darkness_fog_relic, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .calibrated_resonance_matrix, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .wind_charge_rocket_booster, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .mace_velocity_impact_relic, .count = 1 };
    if (flags[10] and flags[11]) return .{ .item = .crafter_pulsed_grid_controller, .count = 1 };
    return null;
}

fn wave24CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .chorus_fruit;
        flags[1] = flags[1] or slot.item == .ender_pearl;
        flags[2] = flags[2] or slot.item == .shulker_shell;
        flags[3] = flags[3] or slot.item == .iron_ingot;
        flags[4] = flags[4] or slot.item == .shulker_box;
        flags[5] = flags[5] or slot.item == .diamond;
        flags[6] = flags[6] or slot.item == .elytra;
        flags[7] = flags[7] or slot.item == .phantom_membrane;
        flags[8] = flags[8] or slot.item == .dragon_head;
        flags[9] = flags[9] or slot.item == .copper_horn;
        flags[10] = flags[10] or slot.item == .dragons_breath;
        flags[11] = flags[11] or slot.item == .glass_bottle;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .chorus_teleport_matrix, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .shulker_shell_armor_plate, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .quantum_shulker_core, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .elytra_mending_wing, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .dragon_skull_horn, .count = 1 };
    if (flags[10] and flags[11]) return .{ .item = .dragons_breath_vial, .count = 1 };
    return null;
}

fn wave20CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 12;
    var string_count: u16 = 0;
    var leather_count: u16 = 0;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .trial_chamber_map;
        flags[1] = flags[1] or slot.item == .wind_charge;
        flags[2] = flags[2] or slot.item == .string;
        if (slot.item == .string) string_count += slot.count;
        flags[3] = flags[3] or slot.item == .leather;
        if (slot.item == .leather) leather_count += slot.count;
        flags[4] = flags[4] or slot.item == .netherite_upgrade_template;
        flags[5] = flags[5] or slot.item == .diamond;
        flags[6] = flags[6] or slot.item == .end_rod;
        flags[7] = flags[7] or slot.item == .shulker_shell;
        flags[8] = flags[8] or slot.item == .firework_star;
        flags[9] = flags[9] or slot.item == .phantom_membrane;
        flags[10] = flags[10] or slot.item == .totem_of_undying;
        flags[11] = flags[11] or slot.item == .emerald;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .ominous_trap_core, .count = 1 };
    // The exact 1-string, 1-leather recipe yields dyed_bundle_package; multiple
    // leather or string preserves legacy Recipe 301 bundle.
    if (flags[2] and flags[3] and string_count == 1 and leather_count == 1) return .{ .item = .dyed_bundle_package, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .netherite_smithing_core, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .shulker_levitation_orb, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .elytra_propulsion_core, .count = 1 };
    if (flags[10] and flags[11]) return .{ .item = .totem_resurrection_effigy, .count = 1 };
    return null;
}

fn wave19CraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var non_empty: usize = 0;
    var flags = [_]bool{false} ** 11;
    var echo_shard_count: u16 = 0;
    for (grid) |slot| {
        if (slot.isEmpty()) continue;
        non_empty += 1;
        flags[0] = flags[0] or slot.item == .armadillo_scute;
        flags[1] = flags[1] or slot.item == .leather;
        flags[2] = flags[2] or slot.item == .amethyst_shard;
        flags[3] = flags[3] or slot.item == .note_block;
        flags[4] = flags[4] or slot.item == .ochre_froglight;
        flags[5] = flags[5] or slot.item == .glowstone_dust;
        flags[6] = flags[6] or slot.item == .goat_horn;
        flags[7] = flags[7] or slot.item == .echo_shard;
        if (slot.item == .echo_shard) echo_shard_count += slot.count;
        flags[8] = flags[8] or slot.item == .mud_bricks;
        flags[9] = flags[9] or slot.item == .packed_mud;
        flags[10] = flags[10] or slot.item == .compass;
    }
    if (non_empty != 2) return null;
    if (flags[0] and flags[1]) return .{ .item = .armadillo_scute_core, .count = 1 };
    if (flags[2] and flags[3]) return .{ .item = .allay_amethyst_resonator, .count = 1 };
    if (flags[4] and flags[5]) return .{ .item = .froglight_catalyst, .count = 1 };
    if (flags[6] and flags[7]) return .{ .item = .screamer_goat_horn, .count = 1 };
    if (flags[8] and flags[9]) return .{ .item = .mud_brick_masonry, .count = 1 };
    // The exact one-shard recipe makes the talisman; the legacy recovery compass
    // recipe remains available with multiple shards.
    if (flags[7] and flags[10] and echo_shard_count == 1) return .{ .item = .recovery_compass_talisman, .count = 1 };
    return null;
}

fn copperHornCraftingRecipe(grid: [4]ItemStack) ?ItemStack {
    var horn_count: u8 = 0;
    var ingot_count: u8 = 0;
    for (grid) |slot| {
        if (slot.isEmpty() or slot.count != 1) return null;
        switch (slot.item) {
            .goat_horn => horn_count += 1,
            .copper_ingot => ingot_count += 1,
            else => return null,
        }
    }
    if (horn_count != 1 or ingot_count != 3) return null;
    return .{ .item = .copper_horn, .count = 1 };
}

/// Evaluates current 2x2 crafting grid and returns the output ItemStack preview, or an empty ItemStack if no recipe matches.
pub fn resolveCraftOutput(craft_grid: [4]ItemStack) ItemStack {
    var craft_output = ItemStack{};

    const g0 = craft_grid[0].item;
    const g1 = craft_grid[1].item;
    const g2 = craft_grid[2].item;
    const g3 = craft_grid[3].item;

    // Count non-empty items
    var non_empty: usize = 0;
    for (craft_grid) |s| {
        if (!s.isEmpty()) non_empty += 1;
    }

    if (copperHornCraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    // Lead: four String + one Slimeball -> two Leads. Stacks allow the
    // five ingredients to fit in the player's 2x2 crafting grid.
    var lead_string_total: u16 = 0;
    var lead_slimeball_total: u16 = 0;
    var lead_ingredients_only = true;
    for (craft_grid) |slot| {
        if (slot.isEmpty()) continue;
        switch (slot.item) {
            .string => lead_string_total += slot.count,
            .slimeball => lead_slimeball_total += slot.count,
            else => lead_ingredients_only = false,
        }
    }
    const has_lead_batch = @min(lead_string_total / 4, lead_slimeball_total) > 0;
    if (lead_ingredients_only and has_lead_batch) {
        craft_output = .{ .item = .lead, .count = 2 };
        return craft_output;
    }

    if (wave23CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    if (wave25CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    if (wave24CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    if (wave22CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    if (wave21CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    if (wave20CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    if (wave19CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    if (wave18CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    // Wave 17's calibrated sensor tuner shares the legacy sensor ingredients.
    if (wave17CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }

    // Wave 6 weighted plates must precede the existing generic weapon recipes.
    if (non_empty == 2) {
        var gold_nugget_count: usize = 0;
        var iron_ingot_count: usize = 0;
        for (craft_grid) |slot| {
            if (slot.item == .gold_nugget) gold_nugget_count += 1;
            if (slot.item == .iron_ingot) iron_ingot_count += 1;
        }
        const horizontal_pair = (g0 == .gold_nugget and g1 == .gold_nugget and g2 == .none and g3 == .none) or
            (g2 == .gold_nugget and g3 == .gold_nugget and g0 == .none and g1 == .none);
        const iron_horizontal_pair = (g0 == .iron_ingot and g1 == .iron_ingot and g2 == .none and g3 == .none) or
            (g2 == .iron_ingot and g3 == .iron_ingot and g0 == .none and g1 == .none);
        if (gold_nugget_count == 2 and horizontal_pair) {
            craft_output = .{ .item = .light_weighted_pressure_plate, .count = 1 };
            return craft_output;
        }
        if (iron_ingot_count == 2 and iron_horizontal_pair) {
            craft_output = .{ .item = .heavy_weighted_pressure_plate, .count = 1 };
            return craft_output;
        }
        var has_paper = false;
        var has_compass = false;
        var has_empty_map = false;
        var has_explorer_map = false;
        for (craft_grid) |slot| {
            has_paper = has_paper or slot.item == .paper;
            has_compass = has_compass or slot.item == .compass;
            has_empty_map = has_empty_map or slot.item == .empty_locator_map;
            has_explorer_map = has_explorer_map or slot.item == .filled_explorer_map;
        }
        if (has_paper and has_compass) {
            craft_output = .{ .item = .empty_locator_map, .count = 1 };
            return craft_output;
        }
        if (has_empty_map and has_explorer_map) {
            craft_output = .{ .item = .filled_explorer_map, .count = 2 };
            return craft_output;
        }
        const has_book = g0 == .book or g1 == .book or g2 == .book or g3 == .book;
        const has_enchanted_book = g0 == .enchanted_book or g1 == .enchanted_book or g2 == .enchanted_book or g3 == .enchanted_book;
        const has_echo_shard = g0 == .echo_shard or g1 == .echo_shard or g2 == .echo_shard or g3 == .echo_shard;
        const has_diamond = g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond;
        if (has_book and has_echo_shard) {
            craft_output = .{ .item = .swift_sneak_book, .count = 1 };
            return craft_output;
        }
        if (has_enchanted_book and has_diamond) {
            craft_output = .{ .item = .sweeping_edge_book, .count = 1 };
            return craft_output;
        }
    }

    // Recipe: four glass blocks in a 2x2 square -> four glass panes.
    if (non_empty == 4 and g0 == .glass and g1 == .glass and g2 == .glass and g3 == .glass) {
        craft_output = .{ .item = .glass_pane, .count = 4 };
        return craft_output;
    }

    // Recipe 1: 1 Wood Log -> 4 Wood Planks (any single slot)
    if (non_empty == 1) {
        for (craft_grid) |s| {
            if (!s.isEmpty() and s.item == .wood) {
                craft_output = .{ .item = .wood_planks, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 2: 2 Planks vertically -> 4 Sticks
    // Slot 0 & 2 or Slot 1 & 3
    if (non_empty == 2) {
        if ((g0 == .wood_planks and g2 == .wood_planks and g1 == .none and g3 == .none) or
            (g1 == .wood_planks and g3 == .wood_planks and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .stick, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 3: 4 Wood Planks (2x2 filled) -> 1 Crafting Table
    if (non_empty == 4) {
        if (g0 == .wood_planks and g1 == .wood_planks and g2 == .wood_planks and g3 == .wood_planks) {
            craft_output = .{ .item = .crafting_bench, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 31: 3 Wood Planks in U-shape (top-left, bottom-left, bottom-right OR top-right, bottom-left, bottom-right) -> 1 Boat
    if (non_empty == 3) {
        if ((g0 == .wood_planks and g2 == .wood_planks and g3 == .wood_planks and g1 == .none) or
            (g1 == .wood_planks and g2 == .wood_planks and g3 == .wood_planks and g0 == .none))
        {
            craft_output = .{ .item = .boat, .count = 1 };
            return craft_output;
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
            craft_output = .{ .item = .chest, .count = 1 };
            return craft_output;
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
                craft_output = .{ .item = .wooden_door, .count = 1 };
                return craft_output;
            }
        }
    }

    // Recipe 26: 1 Redstone Dust over 1 Stick (vertical) -> 1 Redstone Torch
    if (non_empty == 2) {
        if ((g0 == .redstone_dust and g2 == .stick and g1 == .none and g3 == .none) or
            (g1 == .redstone_dust and g3 == .stick and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .redstone_torch, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 25: 4 Iron Ingots (2x2 filled) -> 1 Iron Door (or 1 Block of Iron when total >= 8)
    if (non_empty == 4) {
        if (g0 == .iron_ingot and g1 == .iron_ingot and g2 == .iron_ingot and g3 == .iron_ingot) {
            const total_iron = @as(u16, craft_grid[0].count) + craft_grid[1].count + craft_grid[2].count + craft_grid[3].count;
            if (total_iron >= 8) {
                craft_output = .{ .item = .iron_block, .count = 1 };
            } else {
                craft_output = .{ .item = .iron_door, .count = 1 };
            }
            return craft_output;
        }
    }

    // Recipe 24: Redstone Lamp (1 Torch + 1 Glass + 2 Redstone Dust in 2x2)
    if (non_empty == 4) {
        var torch_cnt: u8 = 0;
        var glass_cnt: u8 = 0;
        var red_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .torch) torch_cnt += 1 else if (sl.item == .glass) glass_cnt += 1 else if (sl.item == .redstone_dust) red_cnt += 1;
        }
        if (torch_cnt == 1 and glass_cnt == 1 and red_cnt == 2) {
            craft_output = .{ .item = .redstone_lamp, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 23: Redstone Repeater (2 torches + 1 redstone dust + 1 stone in 2x2)
    if (non_empty == 4) {
        var torches_cnt: u8 = 0;
        var red_cnt: u8 = 0;
        var stone_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .torch) torches_cnt += 1 else if (sl.item == .redstone_dust) red_cnt += 1 else if (sl.item == .stone) stone_cnt += 1;
        }
        if (torches_cnt == 2 and red_cnt == 1 and stone_cnt == 1) {
            craft_output = .{ .item = .redstone_repeater, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 22: 1 Stick above 1 Cobblestone (vertical) -> 1 Lever
    if (non_empty == 2) {
        if ((g0 == .stick and g2 == .cobblestone and g1 == .none and g3 == .none) or
            (g1 == .stick and g3 == .cobblestone and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .lever, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 21: 1 Coal + 1 Iron Ingot (vertical or horizontal) -> 4 Redstone Dust
    if (non_empty == 2) {
        const has_c = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal);
        const has_i = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        if (has_c and has_i) {
            // Ensure not torches (coal + stick) or smelting
            craft_output = .{ .item = .redstone_dust, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 20: 2 Wood Planks horizontally (g0+g1 or g2+g3) -> 1 Pressure Plate
    if (non_empty == 2) {
        if ((g0 == .wood_planks and g1 == .wood_planks and g2 == .none and g3 == .none) or
            (g2 == .wood_planks and g3 == .wood_planks and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .pressure_plate, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 4: Wooden Pickaxe recipe in 2x2:
    // Top row: 2 wood planks (g0, g1), bottom: 1 stick (g2 or g3)
    if (non_empty == 3) {
        if (g0 == .wood_planks and g1 == .wood_planks and (g2 == .stick or g3 == .stick)) {
            craft_output = .{ .item = .wooden_pickaxe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe: 2 Nether Bricks stacked vertically -> 2 Nether Brick Fences
    if (non_empty == 2) {
        if ((g0 == .nether_brick and g2 == .nether_brick and g1 == .none and g3 == .none) or
            (g1 == .nether_brick and g3 == .nether_brick and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .nether_brick_fence, .count = 2 };
            return craft_output;
        }
    }

    // Recipe: 2 Quartz Blocks stacked vertically -> 2 Quartz Pillars
    if (non_empty == 2) {
        if ((g0 == .quartz_block and g2 == .quartz_block and g1 == .none and g3 == .none) or
            (g1 == .quartz_block and g3 == .quartz_block and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .quartz_pillar, .count = 2 };
            return craft_output;
        }
    }

    // Recipe: 2 Quartz Pillars stacked vertically -> 2 Chiseled Quartz Blocks
    if (non_empty == 2) {
        if ((g0 == .quartz_pillar and g2 == .quartz_pillar and g1 == .none and g3 == .none) or
            (g1 == .quartz_pillar and g3 == .quartz_pillar and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .chiseled_quartz_block, .count = 2 };
            return craft_output;
        }
    }

    // Recipe: 4 Nether Quartz in 2x2 grid -> 1 Block of Quartz
    if (non_empty == 4) {
        var quartz_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .nether_quartz) quartz_cnt += 1;
        }
        if (quartz_cnt == 4) {
            craft_output = .{ .item = .quartz_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe: 4 Netherrack (2x2 filled) -> 4 Nether Bricks
    if (non_empty == 4) {
        if (g0 == .netherrack and g1 == .netherrack and g2 == .netherrack and g3 == .netherrack) {
            craft_output = .{ .item = .nether_brick, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 5: 4 Sand (2x2 filled) -> 1 Sandstone
    if (non_empty == 4) {
        if (g0 == .sand and g1 == .sand and g2 == .sand and g3 == .sand) {
            craft_output = .{ .item = .sandstone, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 6: 4 Cobblestone (2x2 filled) -> 4 Bricks
    if (non_empty == 4) {
        if (g0 == .cobblestone and g1 == .cobblestone and g2 == .cobblestone and g3 == .cobblestone) {
            craft_output = .{ .item = .brick, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 17: 1 Coal above 1 Stick (vertical) -> 4 Torches
    if (non_empty == 2) {
        if ((g0 == .coal and g2 == .stick and g1 == .none and g3 == .none) or
            (g1 == .coal and g3 == .stick and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .torch, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 16: 2 Sand + 2 Coal (diagonal checkerboard) -> 1 TNT
    if (non_empty == 4) {
        if ((g0 == .sand and g3 == .sand and g1 == .coal and g2 == .coal) or
            (g1 == .sand and g2 == .sand and g0 == .coal and g3 == .coal))
        {
            craft_output = .{ .item = .tnt, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 15: 3 Sticks (any 3 slots in 2x2) -> 3 Ladders
    if (non_empty == 3) {
        var sticks: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .stick) sticks += 1;
        }
        if (sticks == 3) {
            craft_output = .{ .item = .ladder, .count = 3 };
            return craft_output;
        }
    }

    // Recipe 14: Iron Sword: 2 ingots vertically
    if (non_empty == 2) {
        if ((g0 == .iron_ingot and g2 == .iron_ingot and g1 == .none and g3 == .none) or
            (g1 == .iron_ingot and g3 == .iron_ingot and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .iron_sword, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 11: Iron Pickaxe: top row 2 ingots + stick below (either slot)
    if (non_empty == 3) {
        if (g0 == .iron_ingot and g1 == .iron_ingot and (g2 == .stick or g3 == .stick)) {
            craft_output = .{ .item = .iron_pickaxe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 36: Soul Campfire: 1 Soul Sand + 1 Campfire -> 1 Soul Campfire (non_empty == 2)
    if (non_empty == 2) {
        const has_soul = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand);
        const has_fire = (g0 == .campfire or g1 == .campfire or g2 == .campfire or g3 == .campfire);
        if (has_soul and has_fire) {
            craft_output = .{ .item = .soul_campfire, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 35: Soul Torch: 1 Soul Sand + 1 Torch -> 2 Soul Torches (non_empty == 2)
    if (non_empty == 2) {
        const has_soul = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand);
        const has_torch = (g0 == .torch or g1 == .torch or g2 == .torch or g3 == .torch);
        if (has_soul and has_torch) {
            craft_output = .{ .item = .soul_torch, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 34: Fire Charge: 1 Magma Cream + 1 Coal -> 3 Fire Charges (non_empty == 2)
    if (non_empty == 2) {
        const has_cream = (g0 == .magma_cream or g1 == .magma_cream or g2 == .magma_cream or g3 == .magma_cream);
        const has_coal = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal);
        if (has_cream and has_coal) {
            craft_output = .{ .item = .fire_charge, .count = 3 };
            return craft_output;
        }
    }

    // Recipe 33: Magma Cream: 1 Coal + 1 Nether Wart (non_empty == 2)
    if (non_empty == 2) {
        const has_coal = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal);
        const has_wart = (g0 == .nether_wart or g1 == .nether_wart or g2 == .nether_wart or g3 == .nether_wart);
        if (has_coal and has_wart) {
            craft_output = .{ .item = .magma_cream, .count = 1 };
            return craft_output;
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
            craft_output = .{ .item = .fire_resistance_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 130: Prismarine Block: 4 Prismarine Shards (2x2) -> 1 Prismarine Block
    if (non_empty == 4) {
        var shard_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .prismarine_shard) shard_c += 1;
        }
        if (shard_c == 4) {
            craft_output = .{ .item = .prismarine, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 131: Prismarine Bricks: 2 Prismarine + 2 Cobblestone / Stone -> 2 Prismarine Bricks
    if (non_empty == 4) {
        var pris_c: usize = 0;
        var stone_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .prismarine) pris_c += 1;
            if (sl.item == .cobblestone or sl.item == .stone) stone_c += 1;
        }
        if (pris_c == 2 and stone_c == 2) {
            craft_output = .{ .item = .prismarine_bricks, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 132: Dark Prismarine: 2 Prismarine + 2 Coal -> 2 Dark Prismarine
    if (non_empty == 4) {
        var pris_c: usize = 0;
        var coal_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .prismarine) pris_c += 1;
            if (sl.item == .coal or sl.item == .obsidian) coal_c += 1;
        }
        if (pris_c == 2 and coal_c == 2) {
            craft_output = .{ .item = .dark_prismarine, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 133: Sea Lantern: 2 Prismarine Shards + 2 Prismarine Crystals (or Glowstone) -> 1 Sea Lantern
    if (non_empty == 4) {
        var shard_cnt: usize = 0;
        var crystal_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .prismarine_shard) shard_cnt += 1;
            if (sl.item == .prismarine_crystals or sl.item == .glowstone) crystal_cnt += 1;
        }
        if (shard_cnt == 2 and crystal_cnt == 2) {
            craft_output = .{ .item = .sea_lantern, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 137: Dried Kelp Unpacking: 1 Dried Kelp Block -> 4 Dried Kelp
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .dried_kelp_block) {
                craft_output = .{ .item = .dried_kelp, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 136: Dried Kelp Block: 4 Dried Kelp (in 2x2 grid) -> 1 Dried Kelp Block
    if (non_empty == 4) {
        var dk_count: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .dried_kelp) dk_count += 1;
        }
        if (dk_count == 4) {
            craft_output = .{ .item = .dried_kelp_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 135: Fishing Rod: 2 Sticks + 2 Strings (or 1 String + 1 Scute/Membrane) -> 1 Fishing Rod
    if (non_empty >= 2 and non_empty <= 4) {
        var stick_c: usize = 0;
        var line_c: usize = 0;
        var other_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .stick) stick_c += sl.count else if (sl.item == .string or sl.item == .scute or sl.item == .phantom_membrane) line_c += sl.count else if (sl.item != .none) other_c += 1;
        }
        if (stick_c >= 2 and line_c >= 2 and other_c == 0) {
            craft_output = .{ .item = .fishing_rod, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 134: Conduit: 1 Heart of the Sea + 1 Prismarine Shard / Crystal / Scute -> 1 Conduit
    if (non_empty == 2) {
        var heart_cnt: usize = 0;
        var shell_catalyst: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .heart_of_the_sea) heart_cnt += 1;
            if (sl.item == .nautilus_shell or sl.item == .prismarine_shard or sl.item == .prismarine_crystals or sl.item == .scute or sl.item == .trident) shell_catalyst += 1;
        }
        if (heart_cnt == 1 and shell_catalyst == 1) {
            craft_output = .{ .item = .conduit, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 128: Slow Falling Potion: 1 Phantom Membrane + 1 Glass vial (or nether wart) -> 1 Slow Falling Potion
    if (non_empty == 2) {
        var memb_c: usize = 0;
        var liquid_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .phantom_membrane) memb_c += 1;
            if (sl.item == .glass or sl.item == .nether_wart or sl.item == .water) liquid_c += 1;
        }
        if (memb_c == 1 and liquid_c == 1) {
            craft_output = .{ .item = .slow_falling_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 129: Elytra Membrane Repair / Craft: 2 Phantom Membranes + 2 Feathers/String/Purpur -> 1 Elytra
    if (non_empty == 4) {
        var memb_cnt: usize = 0;
        var supp_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .phantom_membrane) memb_cnt += 1;
            if (sl.item == .string or sl.item == .purpur_block or sl.item == .wool) supp_cnt += 1;
        }
        if (memb_cnt == 2 and supp_cnt == 2) {
            craft_output = .{ .item = .elytra, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 127: Trident: 2 Iron Ingots + 1 Scute + 1 Stick -> 1 Trident
    if (non_empty == 4) {
        var iron_c: usize = 0;
        var scute_c: usize = 0;
        var stick_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) iron_c += 1;
            if (sl.item == .scute) scute_c += 1;
            if (sl.item == .stick) stick_c += 1;
        }
        if (iron_c == 2 and scute_c == 1 and stick_c == 1) {
            craft_output = .{ .item = .trident, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 125: Turtle Shell Helmet: 4 Scutes (filling 2x2 grid) -> 1 Turtle Shell Helmet
    if (non_empty == 4) {
        var scute_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .scute) scute_cnt += 1;
        }
        if (scute_cnt == 4) {
            craft_output = .{ .item = .turtle_helmet, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 139: Rail: 2 Iron Ingots in vertical column + 1 Stick -> 4 Rails
    if (non_empty == 3) {
        if ((g0 == .iron_ingot and g2 == .iron_ingot and (g1 == .stick or g3 == .stick)) or
            (g1 == .iron_ingot and g3 == .iron_ingot and (g0 == .stick or g2 == .stick)))
        {
            craft_output = .{ .item = .rail, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 140: Powered Rail: 2 Gold Nuggets + 1 Redstone Dust + 1 Stick -> 4 Powered Rails
    if (non_empty == 4) {
        var gold_c: usize = 0;
        var red_c: usize = 0;
        var stick_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .gold_nugget) gold_c += sl.count;
            if (sl.item == .redstone_dust) red_c += sl.count;
            if (sl.item == .stick) stick_c += sl.count;
        }
        if (gold_c >= 2 and red_c >= 1 and stick_c >= 1) {
            craft_output = .{ .item = .powered_rail, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 141: Minecart: 3 Iron Ingots (U-shape in 2x2 grid) -> 1 Minecart
    if (non_empty == 3) {
        if ((g0 == .iron_ingot and g2 == .iron_ingot and g3 == .iron_ingot and g1 == .none) or
            (g1 == .iron_ingot and g2 == .iron_ingot and g3 == .iron_ingot and g0 == .none))
        {
            craft_output = .{ .item = .minecart, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 142: Detector Rail: 2 Iron Ingots + 1 Stone/Pressure Plate + 1 Redstone Dust -> 6 Detector Rails
    if (non_empty == 3 or non_empty == 4) {
        var iron_c: usize = 0;
        var red_c: usize = 0;
        var plate_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) iron_c += sl.count;
            if (sl.item == .redstone_dust) red_c += sl.count;
            if (sl.item == .pressure_plate or sl.item == .stone or sl.item == .cobblestone) plate_c += sl.count;
        }
        if (iron_c >= 2 and red_c >= 1 and plate_c >= 1) {
            craft_output = .{ .item = .detector_rail, .count = 6 };
            return craft_output;
        }
    }

    // Recipe 143: Activator Rail: 2 Iron Ingots + 1 Redstone Torch + 1 Stick -> 6 Activator Rails
    if (non_empty == 3 or non_empty == 4) {
        var iron_c: usize = 0;
        var torch_c: usize = 0;
        var stick_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) iron_c += sl.count;
            if (sl.item == .redstone_torch or sl.item == .torch) torch_c += sl.count;
            if (sl.item == .stick) stick_c += sl.count;
        }
        if (iron_c >= 2 and torch_c >= 1 and stick_c >= 1) {
            craft_output = .{ .item = .activator_rail, .count = 6 };
            return craft_output;
        }
    }

    // Recipe 144: Minecart with Chest: 1 Minecart + 1 Chest -> 1 Minecart with Chest
    if (non_empty == 2) {
        var cart_c: usize = 0;
        var chest_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .minecart) cart_c += 1;
            if (sl.item == .chest) chest_c += 1;
        }
        if (cart_c == 1 and chest_c == 1) {
            craft_output = .{ .item = .chest_minecart, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 145: Minecart with Furnace: 1 Minecart + 1 Furnace -> 1 Minecart with Furnace
    if (non_empty == 2) {
        var cart_c: usize = 0;
        var furn_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .minecart) cart_c += 1;
            if (sl.item == .furnace or sl.item == .blast_furnace or sl.item == .smoker) furn_c += 1;
        }
        if (cart_c == 1 and furn_c == 1) {
            craft_output = .{ .item = .furnace_minecart, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 146: Minecart with TNT: 1 Minecart + 1 TNT -> 1 Minecart with TNT
    if (non_empty == 2) {
        var cart_c: usize = 0;
        var tnt_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .minecart) cart_c += 1;
            if (sl.item == .tnt) tnt_c += 1;
        }
        if (cart_c == 1 and tnt_c == 1) {
            craft_output = .{ .item = .tnt_minecart, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 147: Minecart with Hopper: 1 Minecart + 1 Hopper -> 1 Minecart with Hopper
    if (non_empty == 2) {
        var cart_c: usize = 0;
        var hop_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .minecart) cart_c += 1;
            if (sl.item == .hopper) hop_c += 1;
        }
        if (cart_c == 1 and hop_c == 1) {
            craft_output = .{ .item = .hopper_minecart, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 287: Calibrated Sculk Sensor: 1 Sculk Sensor + 1..3 Amethyst Shards -> 1 Calibrated Sculk Sensor
    if (non_empty >= 2 and non_empty <= 4) {
        var ssn_cnt: u8 = 0;
        var ame_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .sculk_sensor) ssn_cnt += 1;
            if (sl.item == .amethyst_shard) ame_cnt += 1;
        }
        if (ssn_cnt == 1 and ame_cnt >= 1 and (ssn_cnt + ame_cnt == non_empty)) {
            craft_output = .{ .item = .calibrated_sculk_sensor, .count = 1 };
            return craft_output;
        }
    }

    // Recipes 288-290: Mangrove Planks (1 Mangrove Log -> 4 Planks), Muddy Mangrove Roots (Mangrove Roots + Mud), Armor Trim (Template + Mineral)
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .mangrove_log) {
                craft_output = .{ .item = .mangrove_planks, .count = 4 };
                return craft_output;
            }
            if (sl.item == .cherry_log) {
                craft_output = .{ .item = .cherry_planks, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 292: Chiseled Bookshelf: 2 Planks + 1 Book -> 1 Chiseled Bookshelf
    if (non_empty == 3) {
        var plk_c: u8 = 0;
        var bk_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wood_planks or sl.item == .mangrove_planks or sl.item == .cherry_planks) plk_c += 1;
            if (sl.item == .book) bk_c += 1;
        }
        if (plk_c == 2 and bk_c == 1) {
            craft_output = .{ .item = .chiseled_bookshelf, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 293: Hanging Sign: 2 Chains + 1 Planks/Log -> 2 Hanging Signs
    if (non_empty == 3) {
        var chn_c: u8 = 0;
        var wd_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .chain) chn_c += 1;
            if (sl.item == .wood_planks or sl.item == .cherry_planks or sl.item == .mangrove_planks or sl.item == .wood or sl.item == .cherry_log or sl.item == .mangrove_log or sl.item == .pale_oak_log) wd_c += 1;
        }
        if (chn_c == 2 and wd_c == 1) {
            craft_output = .{ .item = .hanging_sign, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 294: Bamboo Mosaic: 4 Bamboo (or 2 horizontal Bamboo) -> 1 Bamboo Mosaic
    if (non_empty == 4) {
        var bmb_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .bamboo) bmb_c += 1;
        }
        if (bmb_c == 4) {
            craft_output = .{ .item = .bamboo_mosaic, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        if ((g0 == .bamboo and g1 == .bamboo and g2 == .none and g3 == .none) or
            (g2 == .bamboo and g3 == .bamboo and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .bamboo_mosaic, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 295: Resin Bricks: 4 Resin Brick items -> 1 Resin Bricks block
    if (non_empty == 4) {
        var rsb_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .resin_brick) rsb_c += 1;
        }
        if (rsb_c == 4) {
            craft_output = .{ .item = .resin_bricks, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 296: Creaking Heart: 2 Pale Oak Logs + 1 Resin Bricks -> 1 Creaking Heart
    if (non_empty == 3) {
        var pol_c: u8 = 0;
        var rsbk_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .pale_oak_log) pol_c += 1;
            if (sl.item == .resin_bricks) rsbk_c += 1;
        }
        if (pol_c == 2 and rsbk_c == 1) {
            craft_output = .{ .item = .creaking_heart, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 297: Wolf Armor: 4 (or 2) Armadillo Scutes -> 1 Wolf Armor
    if (non_empty == 4) {
        var sct_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .armadillo_scute) sct_c += 1;
        }
        if (sct_c == 4) {
            craft_output = .{ .item = .wolf_armor, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        var sct_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .armadillo_scute) sct_c += 1;
        }
        if (sct_c == 2) {
            craft_output = .{ .item = .wolf_armor, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 298: Ominous Trial Key: 1 Trial Key + 1 Ominous Bottle -> 1 Ominous Trial Key
    if (non_empty == 2) {
        var tk_c: u8 = 0;
        var ob_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .trial_key) tk_c += 1;
            if (sl.item == .ominous_bottle) ob_c += 1;
        }
        if (tk_c == 1 and ob_c == 1) {
            craft_output = .{ .item = .ominous_trial_key, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 299: Ominous Vault: 1 Vault + 1 Ominous Bottle -> 1 Ominous Vault
    if (non_empty == 2) {
        var vt_c: u8 = 0;
        var ob_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .vault) vt_c += 1;
            if (sl.item == .ominous_bottle) ob_c += 1;
        }
        if (vt_c == 1 and ob_c == 1) {
            craft_output = .{ .item = .ominous_vault, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 300: Trial Alchemy: Reagent + Glass/Nether Wart -> Potion
    if (non_empty == 2) {
        var vsl_c: u8 = 0;
        var reagent: ?ItemType = null;
        for (craft_grid) |sl| {
            if (sl.item == .glass or sl.item == .nether_wart) vsl_c += 1 else if (reagent == null) reagent = sl.item;
        }
        if (vsl_c == 1 and reagent != null) {
            switch (reagent.?) {
                .wind_charge, .breeze_rod => {
                    craft_output = .{ .item = .potion_of_wind_charged, .count = 1 };
                    return craft_output;
                },
                .slimeball, .slime_block => {
                    craft_output = .{ .item = .potion_of_oozing, .count = 1 };
                    return craft_output;
                },
                .cobweb, .string => {
                    craft_output = .{ .item = .potion_of_weaving, .count = 1 };
                    return craft_output;
                },
                .stone, .cobblestone, .iron_ingot => {
                    craft_output = .{ .item = .potion_of_infested, .count = 1 };
                    return craft_output;
                },
                else => {},
            }
        }
    }

    // Recipe 301: Bundle: 1 String + 1 Leather -> 1 Bundle
    if (non_empty == 2) {
        var str_c: u8 = 0;
        var lth_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .string) str_c += 1;
            if (sl.item == .leather) lth_c += 1;
        }
        if (str_c == 1 and lth_c == 1) {
            craft_output = .{ .item = .bundle, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 302: Copper Door: 3 Copper Ingots -> 1 Copper Door
    if (non_empty == 3) {
        var cpi_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .copper_ingot) cpi_c += 1;
        }
        if (cpi_c == 3) {
            craft_output = .{ .item = .copper_door, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 303: Copper Trapdoor: 1 Copper Door -> 2 Copper Trapdoors or 2 Copper Ingots horizontally
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .copper_door and sl.count >= 1) {
                craft_output = .{ .item = .copper_trapdoor, .count = 2 };
                return craft_output;
            }
        }
    }
    if (non_empty == 2) {
        if ((g0 == .copper_ingot and g1 == .copper_ingot and g2 == .none and g3 == .none) or
            (g2 == .copper_ingot and g3 == .copper_ingot and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .copper_trapdoor, .count = 2 };
            return craft_output;
        }
    }

    // Wave 3 utility recipes: dried ghast, ghast harness, copper golem statue, and banner.
    if (non_empty == 2 and ((g0 == .bone and g1 == .bone) or (g2 == .bone and g3 == .bone))) {
        craft_output = .{ .item = .dried_ghast, .count = 1 };
        return craft_output;
    }
    if (non_empty == 4) {
        var leather_count: u8 = 0;
        var glass_count: u8 = 0;
        var wool_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .leather) leather_count += 1;
            if (sl.item == .glass) glass_count += 1;
            if (sl.item == .wool) wool_count += 1;
        }
        if (leather_count == 2 and glass_count == 1 and wool_count == 1) {
            craft_output = .{ .item = .ghast_harness, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        var copper_count: u8 = 0;
        var pumpkin_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .copper_ingot) copper_count += 1;
            if (sl.item == .carved_pumpkin) pumpkin_count += 1;
        }
        if (copper_count == 1 and pumpkin_count == 1) {
            craft_output = .{ .item = .copper_golem_statue, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 4) {
        var wool_count: u8 = 0;
        var stick_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wool) wool_count += 1;
            if (sl.item == .stick) stick_count += 1;
        }
        if (wool_count == 3 and stick_count == 1) {
            craft_output = .{ .item = .banner, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 1) {
        for (craft_grid) |sl| if (sl.item == .sculk and sl.count >= 1) {
            craft_output = .{ .item = .sculk_catalyst, .count = 1 };
            return craft_output;
        };
    }

    // Recipe 304: Music Disc 5: 4 (or 2) Disc Fragments (5) -> 1 Music Disc 5
    if (non_empty == 4) {
        var df_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .disc_fragment_5) df_c += 1;
        }
        if (df_c == 4) {
            craft_output = .{ .item = .music_disc_5, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        var df_c: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .disc_fragment_5) df_c += 1;
        }
        if (df_c == 2) {
            craft_output = .{ .item = .music_disc_5, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        var rts_cnt: u8 = 0;
        var mud_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .mangrove_roots) rts_cnt += 1;
            if (sl.item == .mud) mud_cnt += 1;
        }
        if (rts_cnt == 1 and mud_cnt == 1) {
            craft_output = .{ .item = .muddy_mangrove_roots, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 279 & 280: Wind Charge (1 Breeze Rod -> 4 Wind Charges) & Mace (1 Heavy Core + 1 Breeze Rod -> 1 Mace)
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .breeze_rod) {
                craft_output = .{ .item = .wind_charge, .count = 4 };
                return craft_output;
            }
        }
    }
    if (non_empty == 2) {
        var hvc_cnt: u8 = 0;
        var brz_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .heavy_core) hvc_cnt += 1;
            if (sl.item == .breeze_rod) brz_cnt += 1;
        }
        if (hvc_cnt == 1 and brz_cnt == 1) {
            craft_output = .{ .item = .mace, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 281: Crafter: 1 Crafting Bench + 1 Dropper + 1..2 Redstone Dust/Iron Ingots -> 1 Crafter
    if (non_empty >= 3 and non_empty <= 4) {
        var cft_cnt: u8 = 0;
        var drp_cnt: u8 = 0;
        var rds_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .crafting_bench) cft_cnt += 1;
            if (sl.item == .dropper) drp_cnt += 1;
            if (sl.item == .redstone_dust or sl.item == .iron_ingot) rds_cnt += 1;
        }
        if (cft_cnt == 1 and drp_cnt == 1 and rds_cnt >= 1 and (cft_cnt + drp_cnt + rds_cnt == non_empty)) {
            craft_output = .{ .item = .crafter, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 282 & 283: Enchanted Golden Apple (1 Golden Apple + 2..3 Gold Blocks) & Suspicious Stew (1 Mushroom Stew + 1 Glow Berries/Sweet Berries)
    if (non_empty >= 3 and non_empty <= 4) {
        var gap_cnt: u8 = 0;
        var gbk_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .golden_apple) gap_cnt += 1;
            if (sl.item == .gold_block) gbk_cnt += 1;
        }
        if (gap_cnt == 1 and gbk_cnt >= 2 and (gap_cnt + gbk_cnt == non_empty)) {
            craft_output = .{ .item = .enchanted_golden_apple, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        var stw_cnt: u8 = 0;
        var flw_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .mushroom_stew) stw_cnt += 1;
            if (sl.item == .glow_berries or sl.item == .sweet_berries or sl.item == .golden_carrot) flw_cnt += 1;
        }
        if (stw_cnt == 1 and flw_cnt == 1) {
            craft_output = .{ .item = .suspicious_stew, .count = 1 };
            return craft_output;
        }
    }

    // Recipes 284-286: Tuff -> Polished Tuff (4x), Polished Tuff -> Tuff Bricks (4x), Tuff Bricks vertically -> Chiseled Tuff (2x)
    if (non_empty == 4) {
        if (g0 == .tuff and g1 == .tuff and g2 == .tuff and g3 == .tuff) {
            craft_output = .{ .item = .polished_tuff, .count = 4 };
            return craft_output;
        }
        if (g0 == .polished_tuff and g1 == .polished_tuff and g2 == .polished_tuff and g3 == .polished_tuff) {
            craft_output = .{ .item = .tuff_bricks, .count = 4 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        if ((g0 == .tuff_bricks and g2 == .tuff_bricks and g1 == .none and g3 == .none) or
            (g1 == .tuff_bricks and g3 == .tuff_bricks and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .chiseled_tuff, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 266: Ender Chest: 2..3 Obsidian + 1 Eye of Ender -> 1 Ender Chest
    if (non_empty >= 3 and non_empty <= 4) {
        var obs_cnt: u8 = 0;
        var eye_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .obsidian) obs_cnt += 1;
            if (sl.item == .eye_of_ender) eye_cnt += 1;
        }
        if (obs_cnt >= 2 and eye_cnt == 1 and (obs_cnt + eye_cnt == non_empty)) {
            craft_output = .{ .item = .ender_chest, .count = 1 };
            return craft_output;
        }
    }

    // Recipes 267-270: Chainmail Armor Suit (2 Chains horizontally -> Helmet, 4 Chains -> Chestplate, 3 Chains -> Leggings, 2 Chains vertically -> Boots)
    if (non_empty == 2) {
        if ((g0 == .chain and g1 == .chain and g2 == .none and g3 == .none) or
            (g2 == .chain and g3 == .chain and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .chainmail_helmet, .count = 1 };
            return craft_output;
        }
        if ((g0 == .chain and g2 == .chain and g1 == .none and g3 == .none) or
            (g1 == .chain and g3 == .chain and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .chainmail_boots, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 4 and g0 == .chain and g1 == .chain and g2 == .chain and g3 == .chain) {
        craft_output = .{ .item = .chainmail_chestplate, .count = 1 };
        return craft_output;
    }
    if (non_empty == 3) {
        var chn_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .chain) chn_cnt += 1;
        }
        if (chn_cnt == 3) {
            craft_output = .{ .item = .chainmail_leggings, .count = 1 };
            return craft_output;
        }
    }

    // Recipes 271-273: Mud (Dirt + Water Bucket), Packed Mud (Mud + Wheat), Mud Bricks (4 Packed Mud -> 4 Mud Bricks)
    if (non_empty == 2) {
        var drt_cnt: u8 = 0;
        var wtr_cnt: u8 = 0;
        var mud_cnt: u8 = 0;
        var wht_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .dirt) drt_cnt += 1;
            if (sl.item == .water_bucket) wtr_cnt += 1;
            if (sl.item == .mud) mud_cnt += 1;
            if (sl.item == .wheat) wht_cnt += 1;
        }
        if (drt_cnt == 1 and wtr_cnt == 1) {
            craft_output = .{ .item = .mud, .count = 1 };
            return craft_output;
        }
        if (mud_cnt == 1 and wht_cnt == 1) {
            craft_output = .{ .item = .packed_mud, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 4 and g0 == .packed_mud and g1 == .packed_mud and g2 == .packed_mud and g3 == .packed_mud) {
        craft_output = .{ .item = .mud_bricks, .count = 4 };
        return craft_output;
    }

    // Recipes 274-276: Copper Bulb (1..2 Copper Block + 1 Blaze Rod + 1 Redstone Dust -> 4 Copper Bulbs), Chiseled Copper (2 Copper Blocks vertically -> 2 Chiseled Copper), Copper Grate (4 Copper Blocks -> 4 Copper Grates)
    if (non_empty >= 3 and non_empty <= 4) {
        var cpb_cnt: u8 = 0;
        var blz_cnt: u8 = 0;
        var red_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .copper_block) cpb_cnt += 1;
            if (sl.item == .blaze_rod) blz_cnt += 1;
            if (sl.item == .redstone_dust) red_cnt += 1;
        }
        if (cpb_cnt >= 1 and blz_cnt == 1 and red_cnt == 1 and (cpb_cnt + blz_cnt + red_cnt == non_empty)) {
            craft_output = .{ .item = .copper_bulb, .count = 4 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        if ((g0 == .copper_block and g2 == .copper_block and g1 == .none and g3 == .none) or
            (g1 == .copper_block and g3 == .copper_block and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .chiseled_copper, .count = 2 };
            return craft_output;
        }
    }
    if (non_empty == 4 and g0 == .copper_block and g1 == .copper_block and g2 == .copper_block and g3 == .copper_block) {
        craft_output = .{ .item = .copper_grate, .count = 4 };
        return craft_output;
    }

    // Recipes 277 & 278: Brush (1 Copper Ingot + 1 Stick + 1 String -> 1 Brush) & Decorated Pot (4 Pottery Sherds -> 1 Decorated Pot)
    if (non_empty == 3) {
        var cpi_cnt: u8 = 0;
        var stk_cnt: u8 = 0;
        var str_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .copper_ingot) cpi_cnt += 1;
            if (sl.item == .stick) stk_cnt += 1;
            if (sl.item == .string) str_cnt += 1;
        }
        if (cpi_cnt == 1 and stk_cnt == 1 and str_cnt == 1) {
            craft_output = .{ .item = .brush, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 4 and g0 == .pottery_sherd and g1 == .pottery_sherd and g2 == .pottery_sherd and g3 == .pottery_sherd) {
        craft_output = .{ .item = .decorated_pot, .count = 1 };
        return craft_output;
    }

    // Recipe 254 & 255: Packed Ice (4 Ice -> 1 Packed Ice) & Blue Ice (4 Packed Ice -> 1 Blue Ice)
    if (non_empty == 4) {
        if (g0 == .ice and g1 == .ice and g2 == .ice and g3 == .ice) {
            craft_output = .{ .item = .packed_ice, .count = 1 };
            return craft_output;
        }
        if (g0 == .packed_ice and g1 == .packed_ice and g2 == .packed_ice and g3 == .packed_ice) {
            craft_output = .{ .item = .blue_ice, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 256: Powder Snow Bucket: 1 Snow Block + 1 Water Bucket -> 1 Powder Snow Bucket
    if (non_empty == 2) {
        var snw_cnt: u8 = 0;
        var wtr_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .snow_block) snw_cnt += 1;
            if (sl.item == .water_bucket) wtr_cnt += 1;
        }
        if (snw_cnt == 1 and wtr_cnt == 1) {
            craft_output = .{ .item = .powder_snow_bucket, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 257 & 258: Bamboo -> Stick (2 Bamboo vertically -> 1 Stick) & Scaffolding (2..3 Bamboo + 1 String -> 6 Scaffolding)
    if (non_empty == 2) {
        if ((g0 == .bamboo and g2 == .bamboo and g1 == .none and g3 == .none) or
            (g1 == .bamboo and g3 == .bamboo and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .stick, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty >= 3 and non_empty <= 4) {
        var bmb_cnt: u8 = 0;
        var str_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .bamboo) bmb_cnt += 1;
            if (sl.item == .string) str_cnt += 1;
        }
        if (bmb_cnt >= 2 and str_cnt == 1 and (bmb_cnt + str_cnt == non_empty)) {
            craft_output = .{ .item = .scaffolding, .count = 6 };
            return craft_output;
        }
    }

    // Recipe 259, 260 & 261: Bowl (2 diagonal Wood Planks -> 4 Bowls), Beetroot Soup (2..3 Beetroot + 1 Bowl), Mushroom Stew (2 Fungus + 1 Bowl)
    if (non_empty == 2) {
        if ((g0 == .wood_planks and g3 == .wood_planks and g1 == .none and g2 == .none) or
            (g1 == .wood_planks and g2 == .wood_planks and g0 == .none and g3 == .none))
        {
            craft_output = .{ .item = .bowl, .count = 4 };
            return craft_output;
        }
    }
    if (non_empty >= 3 and non_empty <= 4) {
        var btr_cnt: u8 = 0;
        var fng_cnt: u8 = 0;
        var bwl_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .beetroot) btr_cnt += 1;
            if (sl.item == .crimson_fungus or sl.item == .warped_fungus) fng_cnt += 1;
            if (sl.item == .bowl) bwl_cnt += 1;
        }
        if (btr_cnt >= 2 and bwl_cnt == 1 and (btr_cnt + bwl_cnt == non_empty)) {
            craft_output = .{ .item = .beetroot_soup, .count = 1 };
            return craft_output;
        }
        if (fng_cnt >= 2 and bwl_cnt == 1 and (fng_cnt + bwl_cnt == non_empty)) {
            craft_output = .{ .item = .mushroom_stew, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 262, 263 & 264: Swiftness Potion (Sugar + Glass/Wart), Strength Potion (Blaze Powder + Glass/Wart), Leaping Potion (Rabbit Foot + Glass/Wart)
    if (non_empty == 2) {
        var sgr_cnt: u8 = 0;
        var blz_cnt: u8 = 0;
        var rbt_cnt: u8 = 0;
        var vsl_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .sugar) sgr_cnt += 1;
            if (sl.item == .blaze_powder) blz_cnt += 1;
            if (sl.item == .rabbit_foot) rbt_cnt += 1;
            if (sl.item == .glass or sl.item == .nether_wart) vsl_cnt += 1;
        }
        if (sgr_cnt == 1 and vsl_cnt == 1) {
            craft_output = .{ .item = .swiftness_potion, .count = 1 };
            return craft_output;
        }
        if (blz_cnt == 1 and vsl_cnt == 1) {
            craft_output = .{ .item = .strength_potion, .count = 1 };
            return craft_output;
        }
        if (rbt_cnt == 1 and vsl_cnt == 1) {
            craft_output = .{ .item = .leaping_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 265: Cookie: 2 Wheat + 1 Cocoa Beans -> 8 Cookies
    if (non_empty == 3) {
        var wht_cnt: u8 = 0;
        var coc_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wheat) wht_cnt += 1;
            if (sl.item == .cocoa_beans) coc_cnt += 1;
        }
        if (wht_cnt == 2 and coc_cnt == 1) {
            craft_output = .{ .item = .cookie, .count = 8 };
            return craft_output;
        }
    }

    // Recipe 244 & 245: Dripstone Block (4 Pointed Dripstone <-> 1 Dripstone Block)
    if (non_empty == 4) {
        if (g0 == .pointed_dripstone and g1 == .pointed_dripstone and g2 == .pointed_dripstone and g3 == .pointed_dripstone) {
            craft_output = .{ .item = .dripstone_block, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .dripstone_block) {
                craft_output = .{ .item = .pointed_dripstone, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 246: Moss Carpet: 2 Moss Blocks horizontally -> 3 Moss Carpets
    if (non_empty == 2) {
        if ((g0 == .moss_block and g1 == .moss_block and g2 == .none and g3 == .none) or
            (g2 == .moss_block and g3 == .moss_block and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .moss_carpet, .count = 3 };
            return craft_output;
        }
    }

    // Recipe 247, 248 & 249: Clay (4 Clay Balls -> 1 Clay), Bricks (4 Brick items -> 1 Brick block), Flower Pot (3 Brick items -> 1 Flower Pot)
    if (non_empty == 4) {
        if (g0 == .clay_ball and g1 == .clay_ball and g2 == .clay_ball and g3 == .clay_ball) {
            craft_output = .{ .item = .clay, .count = 1 };
            return craft_output;
        }
        if (g0 == .brick_item and g1 == .brick_item and g2 == .brick_item and g3 == .brick_item) {
            craft_output = .{ .item = .brick, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 3) {
        var brk_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .brick_item) brk_cnt += 1;
        }
        if (brk_cnt == 3) {
            craft_output = .{ .item = .flower_pot, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 250: Totem of Undying: 2 Gold Blocks + 1..2 Emeralds -> 1 Totem of Undying
    if (non_empty >= 3 and non_empty <= 4) {
        var gb_cnt: u8 = 0;
        var em_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .gold_block) gb_cnt += 1;
            if (sl.item == .emerald) em_cnt += 1;
        }
        if (gb_cnt == 2 and em_cnt >= 1 and (gb_cnt + em_cnt == non_empty)) {
            craft_output = .{ .item = .totem_of_undying, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 251 & 252: Golden Carrot (1 Carrot + 1..3 Gold Nuggets) & Potion of Night Vision (1 Golden Carrot + 1 Glass/Wart)
    if (non_empty >= 2 and non_empty <= 4) {
        var crt_cnt: u8 = 0;
        var gld_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .carrot) crt_cnt += 1;
            if (sl.item == .gold_nugget) gld_cnt += 1;
        }
        if (crt_cnt == 1 and gld_cnt >= 1 and (crt_cnt + gld_cnt == non_empty)) {
            craft_output = .{ .item = .golden_carrot, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        var gc_cnt: u8 = 0;
        var vsl_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .golden_carrot) gc_cnt += 1;
            if (sl.item == .glass or sl.item == .nether_wart) vsl_cnt += 1;
        }
        if (gc_cnt == 1 and vsl_cnt == 1) {
            craft_output = .{ .item = .night_vision_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 253: Potion of Regeneration: 1 Ghast Tear + 1 Glass/Nether Wart -> 1 Potion of Regeneration
    if (non_empty == 2) {
        var gt_cnt: u8 = 0;
        var vsl_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .ghast_tear) gt_cnt += 1;
            if (sl.item == .glass or sl.item == .nether_wart) vsl_cnt += 1;
        }
        if (gt_cnt == 1 and vsl_cnt == 1) {
            craft_output = .{ .item = .regeneration_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 233: Sculk Sensor: 1 Sculk + 1 Redstone Dust/Observer -> 1 Sculk Sensor
    if (non_empty == 2) {
        var sck_cnt: u8 = 0;
        var red_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .sculk) sck_cnt += 1;
            if (sl.item == .redstone_dust or sl.item == .observer) red_cnt += 1;
        }
        if (sck_cnt == 1 and red_cnt == 1) {
            craft_output = .{ .item = .sculk_sensor, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 234: Recovery Compass: 1 Compass + 1..3 Echo Shards -> 1 Recovery Compass
    if (non_empty >= 2 and non_empty <= 4) {
        var cmp_cnt: u8 = 0;
        var ech_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .compass) cmp_cnt += 1;
            if (sl.item == .echo_shard) ech_cnt += 1;
        }
        if (cmp_cnt == 1 and ech_cnt >= 1 and (cmp_cnt + ech_cnt == non_empty)) {
            craft_output = .{ .item = .recovery_compass, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 235 & 236: Polished Deepslate (4 Cobbled Deepslate) & Deepslate Bricks (4 Polished Deepslate)
    if (non_empty == 4) {
        if (g0 == .cobbled_deepslate and g1 == .cobbled_deepslate and g2 == .cobbled_deepslate and g3 == .cobbled_deepslate) {
            craft_output = .{ .item = .polished_deepslate, .count = 4 };
            return craft_output;
        }
        if (g0 == .polished_deepslate and g1 == .polished_deepslate and g2 == .polished_deepslate and g3 == .polished_deepslate) {
            craft_output = .{ .item = .deepslate_bricks, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 237 & 238: Block of Iron (4 slots of Iron Ingots with total >= 8, or 3 Iron Ingots + 1 Iron Bars -> 1 Block of Iron) & Unpack (1 Block of Iron -> 4 Iron Ingots)
    if (non_empty == 4) {
        var iron_slots: u8 = 0;
        var bars_slots: u8 = 0;
        var total_iron: u16 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) {
                iron_slots += 1;
                total_iron += sl.count;
            } else if (sl.item == .iron_bars) {
                bars_slots += 1;
            }
        }
        if ((iron_slots == 4 and total_iron >= 8) or (iron_slots == 3 and bars_slots == 1)) {
            craft_output = .{ .item = .iron_block, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .iron_block) {
                craft_output = .{ .item = .iron_ingot, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 239: Cake: 1..2 Wheat + 1 Sugar + 1 Apple/Honey Bottle -> 1 Cake
    if (non_empty >= 3 and non_empty <= 4) {
        var wht_cnt: u8 = 0;
        var sgr_cnt: u8 = 0;
        var swt_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wheat) wht_cnt += 1;
            if (sl.item == .sugar) sgr_cnt += 1;
            if (sl.item == .apple or sl.item == .honey_bottle) swt_cnt += 1;
        }
        if (wht_cnt >= 1 and sgr_cnt == 1 and swt_cnt == 1 and (wht_cnt + sgr_cnt + swt_cnt == non_empty)) {
            craft_output = .{ .item = .cake, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 240: Melon (4 Melon Slices -> 1 Melon Block)
    if (non_empty == 4) {
        if (g0 == .melon_slice and g1 == .melon_slice and g2 == .melon_slice and g3 == .melon_slice) {
            craft_output = .{ .item = .melon, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 241: Glistering Melon Slice: 1 Melon Slice + 1 Gold Nugget -> 1 Glistering Melon Slice
    if (non_empty == 2) {
        var mln_cnt: u8 = 0;
        var gld_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .melon_slice) mln_cnt += 1;
            if (sl.item == .gold_nugget) gld_cnt += 1;
        }
        if (mln_cnt == 1 and gld_cnt == 1) {
            craft_output = .{ .item = .glistering_melon, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 242: Potion of Healing: 1 Glistering Melon Slice + 1 Glass/Nether Wart -> 1 Potion of Healing
    if (non_empty == 2) {
        var glm_cnt: u8 = 0;
        var vsl_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .glistering_melon) glm_cnt += 1;
            if (sl.item == .glass or sl.item == .nether_wart) vsl_cnt += 1;
        }
        if (glm_cnt == 1 and vsl_cnt == 1) {
            craft_output = .{ .item = .healing_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 243: Barrel: 3 Wood Planks + 1 Stick -> 1 Barrel (Wait: 3 Wood Planks + 1 Stick is Composter Recipe 91! Let us make Barrel: 2 Wood Planks + 1 Wooden Trapdoor -> 1 Barrel)
    if (non_empty >= 2 and non_empty <= 3) {
        var plk_cnt: u8 = 0;
        var trp_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wood_planks) plk_cnt += 1;
            if (sl.item == .wooden_trapdoor) trp_cnt += 1;
        }
        if (plk_cnt >= 1 and trp_cnt >= 1 and (plk_cnt + trp_cnt == non_empty)) {
            craft_output = .{ .item = .barrel, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 221 & 222: Block of Copper (4 Copper Ingots -> 1 Block) & Unpack (1 Block -> 4 Copper Ingots)
    if (non_empty == 4) {
        if (g0 == .copper_ingot and g1 == .copper_ingot and g2 == .copper_ingot and g3 == .copper_ingot) {
            craft_output = .{ .item = .copper_block, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .copper_block or sl.item == .waxed_copper_block) {
                craft_output = .{ .item = .copper_ingot, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 223: Waxed Block of Copper: 1 Block of Copper + 1 Honeycomb -> 1 Waxed Block of Copper
    if (non_empty == 2) {
        var cop_cnt: u8 = 0;
        var comb_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .copper_block) cop_cnt += 1;
            if (sl.item == .honeycomb) comb_cnt += 1;
        }
        if (cop_cnt == 1 and comb_cnt == 1) {
            craft_output = .{ .item = .waxed_copper_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 224: Lightning Rod: 2 Copper Ingots vertically -> 1 Lightning Rod
    if (non_empty == 2) {
        if ((g0 == .copper_ingot and g2 == .copper_ingot and g1 == .none and g3 == .none) or
            (g1 == .copper_ingot and g3 == .copper_ingot and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .lightning_rod, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 225: Spyglass: 1..2 Copper Ingots + 1 Amethyst Shard -> 1 Spyglass
    if (non_empty >= 2 and non_empty <= 3) {
        var cop_cnt: u8 = 0;
        var ame_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .copper_ingot) cop_cnt += 1;
            if (sl.item == .amethyst_shard) ame_cnt += 1;
        }
        if (cop_cnt >= 1 and ame_cnt == 1 and (cop_cnt + ame_cnt == non_empty)) {
            craft_output = .{ .item = .spyglass, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 226: Block of Amethyst: 4 Amethyst Shards -> 1 Block of Amethyst
    if (non_empty == 4) {
        if (g0 == .amethyst_shard and g1 == .amethyst_shard and g2 == .amethyst_shard and g3 == .amethyst_shard) {
            craft_output = .{ .item = .amethyst_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 227: Tinted Glass: 2 Amethyst Shards + 1 Glass -> 2 Tinted Glass
    if (non_empty == 3) {
        var ame_cnt: u8 = 0;
        var gls_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .amethyst_shard) ame_cnt += 1;
            if (sl.item == .glass) gls_cnt += 1;
        }
        if (ame_cnt == 2 and gls_cnt == 1) {
            craft_output = .{ .item = .tinted_glass, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 228: Bell: 1 Gold Nugget/Block + 1..2 Wood Planks + 1 Stone -> 1 Bell
    if (non_empty >= 3 and non_empty <= 4) {
        var gld_cnt: u8 = 0;
        var plk_cnt: u8 = 0;
        var stn_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .gold_nugget or sl.item == .gold_block) gld_cnt += 1;
            if (sl.item == .wood_planks) plk_cnt += 1;
            if (sl.item == .stone or sl.item == .cobblestone) stn_cnt += 1;
        }
        if (gld_cnt == 1 and plk_cnt >= 1 and stn_cnt == 1 and (gld_cnt + plk_cnt + stn_cnt == non_empty)) {
            craft_output = .{ .item = .bell, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 229 & 230: Sugar Cane -> 1 Sugar (1 item) or 2 Sugar Cane horizontally -> 3 Paper
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .sugar_cane) {
                craft_output = .{ .item = .sugar, .count = 1 };
                return craft_output;
            }
        }
    }
    if (non_empty == 2) {
        if ((g0 == .sugar_cane and g1 == .sugar_cane and g2 == .none and g3 == .none) or
            (g2 == .sugar_cane and g3 == .sugar_cane and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .paper, .count = 3 };
            return craft_output;
        }
    }

    // Recipe 231: Jack o'Lantern: 1 Carved Pumpkin/Pumpkin + 1 Torch -> 1 Jack o'Lantern
    if (non_empty == 2) {
        var pmp_cnt: u8 = 0;
        var trc_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .carved_pumpkin or sl.item == .pumpkin) pmp_cnt += 1;
            if (sl.item == .torch) trc_cnt += 1;
        }
        if (pmp_cnt == 1 and trc_cnt == 1) {
            craft_output = .{ .item = .jack_o_lantern, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 232: Pumpkin Pie: 1 Pumpkin + 1 Sugar + 1 Wheat/Bread -> 1 Pumpkin Pie
    if (non_empty == 3) {
        var pmp_cnt: u8 = 0;
        var sgr_cnt: u8 = 0;
        var wht_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .pumpkin or sl.item == .carved_pumpkin) pmp_cnt += 1;
            if (sl.item == .sugar) sgr_cnt += 1;
            if (sl.item == .wheat or sl.item == .bread) wht_cnt += 1;
        }
        if (pmp_cnt == 1 and sgr_cnt == 1 and wht_cnt == 1) {
            craft_output = .{ .item = .pumpkin_pie, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 216 & 217: Block of Lapis Lazuli (4 Lapis -> 1 Block) & Unpack (1 Block -> 4 Lapis)
    if (non_empty == 4) {
        if (g0 == .lapis_lazuli and g1 == .lapis_lazuli and g2 == .lapis_lazuli and g3 == .lapis_lazuli) {
            craft_output = .{ .item = .lapis_block, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .lapis_block) {
                craft_output = .{ .item = .lapis_lazuli, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 218: Beehive: 2 Honeycomb + 2 Wood Planks (4 items) -> 1 Beehive
    if (non_empty == 4) {
        var comb_cnt: u8 = 0;
        var plank_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .honeycomb) comb_cnt += 1;
            if (sl.item == .wood_planks) plank_cnt += 1;
        }
        if (comb_cnt == 2 and plank_cnt == 2) {
            craft_output = .{ .item = .beehive, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 219 & 220: Honey Block (4 Honey Bottles -> 1 Honey Block) & Unpack (1 Honey Block + 1..3 Glass -> 4 Honey Bottles)
    if (non_empty == 4) {
        if (g0 == .honey_bottle and g1 == .honey_bottle and g2 == .honey_bottle and g3 == .honey_bottle) {
            craft_output = .{ .item = .honey_block, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty >= 2 and non_empty <= 4) {
        var hb_cnt: u8 = 0;
        var glass_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .honey_block) hb_cnt += 1;
            if (sl.item == .glass) glass_cnt += 1;
        }
        if (hb_cnt == 1 and glass_cnt >= 1 and (hb_cnt + glass_cnt == non_empty)) {
            craft_output = .{ .item = .honey_bottle, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 210: Paper: 2 Wheat or 2 Kelp horizontally -> 3 Paper
    if (non_empty == 2) {
        if (((g0 == .wheat and g1 == .wheat) or (g0 == .kelp and g1 == .kelp)) and g2 == .none and g3 == .none) {
            craft_output = .{ .item = .paper, .count = 3 };
            return craft_output;
        }
        if (((g2 == .wheat and g3 == .wheat) or (g2 == .kelp and g3 == .kelp)) and g0 == .none and g1 == .none) {
            craft_output = .{ .item = .paper, .count = 3 };
            return craft_output;
        }
    }

    // Recipe 211: Book: 2..3 Paper + 1 Leather -> 1 Book
    if (non_empty >= 3 and non_empty <= 4) {
        var paper_cnt: u8 = 0;
        var leather_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .paper) paper_cnt += 1;
            if (sl.item == .leather) leather_cnt += 1;
        }
        if (paper_cnt >= 2 and leather_cnt == 1 and (paper_cnt + leather_cnt == non_empty)) {
            craft_output = .{ .item = .book, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 212: Bookshelf: 2 Books + 2 Wood Planks (4 items) -> 1 Bookshelf
    if (non_empty == 4) {
        var book_cnt: u8 = 0;
        var plank_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .book) book_cnt += 1;
            if (sl.item == .wood_planks) plank_cnt += 1;
        }
        if (book_cnt == 2 and plank_cnt == 2) {
            craft_output = .{ .item = .bookshelf, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 213: Lectern: 1 Bookshelf + 1..3 Wood Planks -> 1 Lectern
    if (non_empty >= 2 and non_empty <= 4) {
        var shelf_cnt: u8 = 0;
        var plank_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .bookshelf) shelf_cnt += 1;
            if (sl.item == .wood_planks) plank_cnt += 1;
        }
        if (shelf_cnt == 1 and plank_cnt >= 1 and (shelf_cnt + plank_cnt == non_empty)) {
            craft_output = .{ .item = .lectern, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 214 & 215: Block of Emerald (4 Emeralds -> 1 Block of Emerald) & Unpack (1 Block of Emerald -> 4 Emeralds)
    if (non_empty == 4) {
        if (g0 == .emerald and g1 == .emerald and g2 == .emerald and g3 == .emerald) {
            craft_output = .{ .item = .emerald_block, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .emerald_block) {
                craft_output = .{ .item = .emerald, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 207: Wheat Seeds: 1 Wheat or 1 Grass -> 2 Wheat Seeds
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .wheat or sl.item == .grass) {
                craft_output = .{ .item = .wheat_seeds, .count = 2 };
                return craft_output;
            }
        }
    }

    // Recipe 208: Bread: 3 Wheat in 2x2 grid -> 1 Bread
    if (non_empty == 3) {
        var wheat_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wheat) wheat_cnt += 1;
        }
        if (wheat_cnt == 3) {
            craft_output = .{ .item = .bread, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 209: Hay Bale from 4 Wheat (2x2 filled), and 1 Hay Bale -> 4 Wheat
    if (non_empty == 4) {
        if (g0 == .wheat and g1 == .wheat and g2 == .wheat and g3 == .wheat) {
            craft_output = .{ .item = .hay_bale, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .hay_bale) {
                craft_output = .{ .item = .wheat, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 201: Wooden Sword: 1 Wood Planks + 1 Stick (diagonal) or 2 bottom Wood Planks + 1 top Stick -> 1 Wooden Sword
    if (non_empty == 2) {
        if ((g0 == .wood_planks and g3 == .stick and g1 == .none and g2 == .none) or
            (g1 == .wood_planks and g2 == .stick and g0 == .none and g3 == .none))
        {
            craft_output = .{ .item = .wooden_sword, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 3) {
        if (g2 == .wood_planks and g3 == .wood_planks and (g0 == .stick or g1 == .stick)) {
            craft_output = .{ .item = .wooden_sword, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 202: Leather tanning: 4 Rotten Flesh (2x2 filled) -> 1 Leather
    if (non_empty == 4) {
        if (g0 == .rotten_flesh and g1 == .rotten_flesh and g2 == .rotten_flesh and g3 == .rotten_flesh) {
            craft_output = .{ .item = .leather, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 203: Leather Cap: 2 Leather horizontally -> 1 Leather Cap
    if (non_empty == 2) {
        if ((g0 == .leather and g1 == .leather and g2 == .none and g3 == .none) or
            (g2 == .leather and g3 == .leather and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .leather_helmet, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 204: Leather Tunic: 4 Leather (2x2 filled) -> 1 Leather Tunic
    if (non_empty == 4) {
        if (g0 == .leather and g1 == .leather and g2 == .leather and g3 == .leather) {
            craft_output = .{ .item = .leather_chestplate, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 205: Leather Pants: 3 Leather in 2x2 grid -> 1 Leather Pants
    if (non_empty == 3) {
        var leather_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .leather) leather_cnt += 1;
        }
        if (leather_cnt == 3) {
            craft_output = .{ .item = .leather_leggings, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 206: Leather Boots: 2 Leather vertically -> 1 Leather Boots
    if (non_empty == 2) {
        if ((g0 == .leather and g2 == .leather and g1 == .none and g3 == .none) or
            (g1 == .leather and g3 == .leather and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .leather_boots, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 196: Golden Sword: 1 Gold Nugget + 1 Stick (vertical) -> 1 Golden Sword
    if (non_empty == 2) {
        if ((g0 == .gold_nugget and g2 == .stick and g1 == .none and g3 == .none) or
            (g1 == .gold_nugget and g3 == .stick and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .golden_sword, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 197: Golden Pickaxe: top row 2 Gold Nuggets + stick below -> 1 Golden Pickaxe
    if (non_empty == 3) {
        if (g0 == .gold_nugget and g1 == .gold_nugget and (g2 == .stick or g3 == .stick)) {
            craft_output = .{ .item = .golden_pickaxe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 198: Golden Axe: 1 Gold Nugget + 1 Wood Log -> 1 Golden Axe
    if (non_empty == 2) {
        if ((g0 == .gold_nugget and g1 == .wood and g2 == .none and g3 == .none) or
            (g2 == .gold_nugget and g3 == .wood and g0 == .none and g1 == .none) or
            (g0 == .wood and g1 == .gold_nugget and g2 == .none and g3 == .none) or
            (g2 == .wood and g3 == .gold_nugget and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .golden_axe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 199: Golden Shovel: 1 Gold Nugget + 1 Wood Planks -> 1 Golden Shovel
    if (non_empty == 2) {
        if ((g0 == .gold_nugget and g2 == .wood_planks and g1 == .none and g3 == .none) or
            (g1 == .gold_nugget and g3 == .wood_planks and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .golden_shovel, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 200: Golden Hoe: 1 Gold Nugget + 1 Stick (horizontal) -> 1 Golden Hoe
    if (non_empty == 2) {
        if ((g0 == .gold_nugget and g1 == .stick and g2 == .none and g3 == .none) or
            (g2 == .gold_nugget and g3 == .stick and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .golden_hoe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 191: Stone Sword: 1 Cobblestone + 1 Stick (vertical) or 2 Cobblestone -> 1 Stone Sword
    if (non_empty == 2) {
        if ((g0 == .cobblestone and g2 == .stick and g1 == .none and g3 == .none) or
            (g1 == .cobblestone and g3 == .stick and g0 == .none and g2 == .none) or
            (g0 == .cobblestone and g2 == .cobblestone and g1 == .none and g3 == .none) or
            (g1 == .cobblestone and g3 == .cobblestone and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .stone_sword, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 192: Stone Pickaxe: top row 2 Cobblestone + stick below -> 1 Stone Pickaxe
    if (non_empty == 3) {
        if (g0 == .cobblestone and g1 == .cobblestone and (g2 == .stick or g3 == .stick)) {
            craft_output = .{ .item = .stone_pickaxe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 193: Stone Axe: 1 Cobblestone + 1 Stick horizontally or 1 Cobblestone + 1 Wood Log -> 1 Stone Axe
    if (non_empty == 2) {
        if ((g0 == .cobblestone and g1 == .wood and g2 == .none and g3 == .none) or
            (g2 == .cobblestone and g3 == .wood and g0 == .none and g1 == .none) or
            (g0 == .wood and g1 == .cobblestone and g2 == .none and g3 == .none) or
            (g2 == .wood and g3 == .cobblestone and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .stone_axe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 194: Stone Shovel: 1 Cobblestone + 1 Stick vertically -> 1 Stone Shovel
    if (non_empty == 2) {
        if ((g0 == .cobblestone and g2 == .wood_planks and g1 == .none and g3 == .none) or
            (g1 == .cobblestone and g3 == .wood_planks and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .stone_shovel, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 195: Stone Hoe: 1 Cobblestone + 1 Stick horizontally -> 1 Stone Hoe
    if (non_empty == 2) {
        if ((g0 == .cobblestone and g1 == .stick and g2 == .none and g3 == .none) or
            (g2 == .cobblestone and g3 == .stick and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .stone_hoe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 187: Golden Helmet: 1 Gold Nugget + 1 Sand (or 1 Gold Nugget + 1 Glass) -> 1 Golden Helmet
    if (non_empty == 2) {
        const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget);
        const has_cap = (g0 == .sand or g1 == .sand or g2 == .sand or g3 == .sand or
            g0 == .glass or g1 == .glass or g2 == .glass or g3 == .glass);
        if (has_gold and has_cap) {
            craft_output = .{ .item = .golden_helmet, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 188: Golden Chestplate: 1 Block of Gold + 1 Gold Nugget (or 1 Block of Gold + 1 Leather / Wool) -> 1 Golden Chestplate
    if (non_empty == 2) {
        const has_gb = (g0 == .gold_block or g1 == .gold_block or g2 == .gold_block or g3 == .gold_block);
        const has_mat = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget or
            g0 == .wool or g1 == .wool or g2 == .wool or g3 == .wool);
        if (has_gb and has_mat) {
            craft_output = .{ .item = .golden_chestplate, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 189: Golden Leggings: 1 Gold Nugget + 1 Chain -> 1 Golden Leggings
    if (non_empty == 2) {
        const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget);
        const has_chain = (g0 == .chain or g1 == .chain or g2 == .chain or g3 == .chain);
        if (has_gold and has_chain) {
            craft_output = .{ .item = .golden_leggings, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 190: Golden Boots: 1 Gold Nugget + 1 Wool (or 1 Gold Nugget + 1 String) -> 1 Golden Boots
    if (non_empty == 2) {
        const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget);
        const has_soft = (g0 == .wool or g1 == .wool or g2 == .wool or g3 == .wool or
            g0 == .string or g1 == .string or g2 == .string or g3 == .string);
        if (has_gold and has_soft) {
            craft_output = .{ .item = .golden_boots, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 183: Iron Helmet: 1 Iron Ingot + 1 Sand (or 1 Iron Ingot + 1 Dirt) -> 1 Iron Helmet
    if (non_empty == 2) {
        const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        const has_cap = (g0 == .sand or g1 == .sand or g2 == .sand or g3 == .sand or
            g0 == .dirt or g1 == .dirt or g2 == .dirt or g3 == .dirt);
        if (has_iron and has_cap) {
            craft_output = .{ .item = .iron_helmet, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 184: Iron Chestplate: 1 Iron Ingot + 1 Iron Bars (or 1 Iron Ingot + 1 Brick) -> 1 Iron Chestplate
    if (non_empty == 2) {
        const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        const has_plate = (g0 == .iron_bars or g1 == .iron_bars or g2 == .iron_bars or g3 == .iron_bars or
            g0 == .brick or g1 == .brick or g2 == .brick or g3 == .brick);
        if (has_iron and has_plate) {
            craft_output = .{ .item = .iron_chestplate, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 185: Iron Leggings: 1 Iron Ingot + 1 Chain -> 1 Iron Leggings
    if (non_empty == 2) {
        const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        const has_chain = (g0 == .chain or g1 == .chain or g2 == .chain or g3 == .chain);
        if (has_iron and has_chain) {
            craft_output = .{ .item = .iron_leggings, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 186: Iron Boots: 1 Iron Ingot + 1 Wool (or 1 Iron Ingot + 1 String) -> 1 Iron Boots
    if (non_empty == 2) {
        const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        const has_soft = (g0 == .wool or g1 == .wool or g2 == .wool or g3 == .wool or
            g0 == .string or g1 == .string or g2 == .string or g3 == .string);
        if (has_iron and has_soft) {
            craft_output = .{ .item = .iron_boots, .count = 1 };
            return craft_output;
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
            craft_output = .{ .item = .shears, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 178: Wooden Hoe: 1 Wood Planks + 1 Stick horizontally -> 1 Wooden Hoe
    if (non_empty == 2) {
        if ((g0 == .wood_planks and g1 == .stick and g2 == .none and g3 == .none) or
            (g2 == .wood_planks and g3 == .stick and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .wooden_hoe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 179: Iron Hoe: 1 Iron Ingot + 1 Stick horizontally -> 1 Iron Hoe
    if (non_empty == 2) {
        if ((g0 == .iron_ingot and g1 == .stick and g2 == .none and g3 == .none) or
            (g2 == .iron_ingot and g3 == .stick and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .iron_hoe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 180: Diamond Hoe: 1 Diamond + 1 Stick horizontally or 1 Iron Hoe + 1 Diamond -> 1 Diamond Hoe
    if (non_empty == 2) {
        if ((g0 == .diamond and g1 == .stick and g2 == .none and g3 == .none) or
            (g2 == .diamond and g3 == .stick and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .diamond_hoe, .count = 1 };
            return craft_output;
        }
        const has_iron_hoe = (g0 == .iron_hoe or g1 == .iron_hoe or g2 == .iron_hoe or g3 == .iron_hoe);
        const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
        if (has_iron_hoe and has_dia) {
            craft_output = .{ .item = .diamond_hoe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 181: Netherite Hoe: 1 Netherite Ingot + 1 Diamond Hoe / Iron Hoe -> 1 Netherite Hoe
    if (non_empty == 2) {
        const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
        const has_base_hoe = (g0 == .diamond_hoe or g1 == .diamond_hoe or g2 == .diamond_hoe or g3 == .diamond_hoe or
            g0 == .iron_hoe or g1 == .iron_hoe or g2 == .iron_hoe or g3 == .iron_hoe);
        if (has_ni and has_base_hoe) {
            craft_output = .{ .item = .netherite_hoe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 174: Wooden Shovel: 1 Wood Planks + 1 Stick (vertical) -> 1 Wooden Shovel
    if (non_empty == 2) {
        if ((g0 == .wood_planks and g2 == .stick and g1 == .none and g3 == .none) or
            (g1 == .wood_planks and g3 == .stick and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .wooden_shovel, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 175: Iron Shovel: 1 Iron Ingot + 1 Stick (vertical) -> 1 Iron Shovel
    if (non_empty == 2) {
        if ((g0 == .iron_ingot and g2 == .stick and g1 == .none and g3 == .none) or
            (g1 == .iron_ingot and g3 == .stick and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .iron_shovel, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 176: Diamond Shovel: 1 Diamond + 1 Stick (vertical) or 1 Iron Shovel + 1 Diamond -> 1 Diamond Shovel
    if (non_empty == 2) {
        if ((g0 == .diamond and g2 == .stick and g1 == .none and g3 == .none) or
            (g1 == .diamond and g3 == .stick and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .diamond_shovel, .count = 1 };
            return craft_output;
        }
        const has_iron_shov = (g0 == .iron_shovel or g1 == .iron_shovel or g2 == .iron_shovel or g3 == .iron_shovel);
        const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
        if (has_iron_shov and has_dia) {
            craft_output = .{ .item = .diamond_shovel, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 177: Netherite Shovel: 1 Netherite Ingot + 1 Diamond Shovel / Iron Shovel -> 1 Netherite Shovel
    if (non_empty == 2) {
        const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
        const has_base_shov = (g0 == .diamond_shovel or g1 == .diamond_shovel or g2 == .diamond_shovel or g3 == .diamond_shovel or
            g0 == .iron_shovel or g1 == .iron_shovel or g2 == .iron_shovel or g3 == .iron_shovel);
        if (has_ni and has_base_shov) {
            craft_output = .{ .item = .netherite_shovel, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 170: Wooden Axe: 1 Wood Log + 1 Stick -> 1 Wooden Axe
    if (non_empty == 2) {
        const has_log = (g0 == .wood or g1 == .wood or g2 == .wood or g3 == .wood);
        const has_stk = (g0 == .stick or g1 == .stick or g2 == .stick or g3 == .stick);
        if (has_log and has_stk) {
            craft_output = .{ .item = .wooden_axe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 171: Iron Axe: 1 Iron Ingot + 1 Wood Log/Plank -> 1 Iron Axe
    if (non_empty == 2) {
        const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        const has_wood_mat = (g0 == .wood or g1 == .wood or g2 == .wood or g3 == .wood or
            g0 == .wood_planks or g1 == .wood_planks or g2 == .wood_planks or g3 == .wood_planks);
        if (has_iron and has_wood_mat) {
            craft_output = .{ .item = .iron_axe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 172: Diamond Axe: 1 Diamond + 1 Wood Log/Plank (or 1 Iron Axe + 1 Diamond) -> 1 Diamond Axe
    if (non_empty == 2) {
        const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
        const has_wood_mat = (g0 == .wood or g1 == .wood or g2 == .wood or g3 == .wood or
            g0 == .wood_planks or g1 == .wood_planks or g2 == .wood_planks or g3 == .wood_planks);
        const has_iron_axe = (g0 == .iron_axe or g1 == .iron_axe or g2 == .iron_axe or g3 == .iron_axe);
        if (has_dia and (has_wood_mat or has_iron_axe)) {
            craft_output = .{ .item = .diamond_axe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 173: Netherite Axe: 1 Netherite Ingot + 1 Diamond Axe / Iron Axe -> 1 Netherite Axe
    if (non_empty == 2) {
        const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
        const has_base_axe = (g0 == .diamond_axe or g1 == .diamond_axe or g2 == .diamond_axe or g3 == .diamond_axe or
            g0 == .iron_axe or g1 == .iron_axe or g2 == .iron_axe or g3 == .iron_axe);
        if (has_ni and has_base_axe) {
            craft_output = .{ .item = .netherite_axe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 168: Flint: 2 Gravel/Sand -> 1 Flint
    if (non_empty == 2) {
        var sand_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .sand) sand_c += 1;
        }
        if (sand_c == 2) {
            craft_output = .{ .item = .flint, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 169: Flint and Steel: 1 Iron Ingot + 1 Flint (non_empty == 2) -> 1 Flint and Steel
    if (non_empty == 2) {
        const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        const has_flint = (g0 == .flint or g1 == .flint or g2 == .flint or g3 == .flint);
        if (has_iron and has_flint) {
            craft_output = .{ .item = .flint_and_steel, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 164: Diamond Helmet: 1 Diamond + 1 Glass (or 1 Diamond + 1 Coal) -> 1 Diamond Helmet
    if (non_empty == 2) {
        const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
        const has_gem = (g0 == .glass or g1 == .glass or g2 == .glass or g3 == .glass or
            g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal or
            g0 == .iron_helmet or g1 == .iron_helmet or g2 == .iron_helmet or g3 == .iron_helmet);
        if (has_dia and has_gem) {
            craft_output = .{ .item = .diamond_helmet, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 165: Diamond Chestplate: 1 Diamond Block + 1 Diamond/Iron Ingot or 1 Iron Chestplate + 1 Diamond -> 1 Diamond Chestplate
    if (non_empty == 2) {
        const has_db = (g0 == .diamond_block or g1 == .diamond_block or g2 == .diamond_block or g3 == .diamond_block);
        const has_mat = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond or
            g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        if (has_db and has_mat) {
            craft_output = .{ .item = .diamond_chestplate, .count = 1 };
            return craft_output;
        }
        const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
        const has_ic = (g0 == .iron_chestplate or g1 == .iron_chestplate or g2 == .iron_chestplate or g3 == .iron_chestplate);
        if (has_dia and has_ic) {
            craft_output = .{ .item = .diamond_chestplate, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 166: Diamond Leggings: 1 Diamond + 1 Obsidian (or 1 Diamond + 1 Chain) -> 1 Diamond Leggings
    if (non_empty == 2) {
        const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
        const has_tough = (g0 == .obsidian or g1 == .obsidian or g2 == .obsidian or g3 == .obsidian or
            g0 == .chain or g1 == .chain or g2 == .chain or g3 == .chain or
            g0 == .iron_leggings or g1 == .iron_leggings or g2 == .iron_leggings or g3 == .iron_leggings);
        if (has_dia and has_tough) {
            craft_output = .{ .item = .diamond_leggings, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 167: Diamond Boots: 2 Diamonds horizontally or 1 Iron Boots + 1 Diamond -> 1 Diamond Boots
    if (non_empty == 2) {
        if ((g0 == .diamond and g1 == .diamond and g2 == .none and g3 == .none) or
            (g2 == .diamond and g3 == .diamond and g0 == .none and g1 == .none))
        {
            craft_output = .{ .item = .diamond_boots, .count = 1 };
            return craft_output;
        }
        const has_dia = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
        const has_ib = (g0 == .iron_boots or g1 == .iron_boots or g2 == .iron_boots or g3 == .iron_boots);
        if (has_dia and has_ib) {
            craft_output = .{ .item = .diamond_boots, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 162: Diamond Sword: 2 Diamonds vertically or 1 Iron Sword + 1 Diamond -> 1 Diamond Sword
    if (non_empty == 2) {
        if ((g0 == .diamond and g2 == .diamond and g1 == .none and g3 == .none) or
            (g1 == .diamond and g3 == .diamond and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .diamond_sword, .count = 1 };
            return craft_output;
        }
        const has_iron_sword = (g0 == .iron_sword or g1 == .iron_sword or g2 == .iron_sword or g3 == .iron_sword);
        const has_diamond = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
        if (has_iron_sword and has_diamond) {
            craft_output = .{ .item = .diamond_sword, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 163: Diamond Pickaxe: 2 Diamonds top row + 1 Stick below, or 1 Iron Pickaxe + 1 Diamond -> 1 Diamond Pickaxe
    if (non_empty == 3) {
        if (g0 == .diamond and g1 == .diamond and (g2 == .stick or g3 == .stick)) {
            craft_output = .{ .item = .diamond_pickaxe, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        const has_iron_pick = (g0 == .iron_pickaxe or g1 == .iron_pickaxe or g2 == .iron_pickaxe or g3 == .iron_pickaxe);
        const has_diamond = (g0 == .diamond or g1 == .diamond or g2 == .diamond or g3 == .diamond);
        if (has_iron_pick and has_diamond) {
            craft_output = .{ .item = .diamond_pickaxe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 160: Block of Diamond: 4 Diamonds (2x2 filled) -> 1 Block of Diamond
    if (non_empty == 4) {
        var dia_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .diamond) dia_c += 1;
        }
        if (dia_c == 4) {
            craft_output = .{ .item = .diamond_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 161: Diamond Unpacking: 1 Block of Diamond -> 4 Diamonds
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .diamond_block and sl.count >= 1) {
                craft_output = .{ .item = .diamond, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 158: Block of Gold: 4 Gold Nuggets (2x2 filled) -> 1 Block of Gold
    if (non_empty == 4) {
        var gold_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .gold_nugget) gold_c += 1;
        }
        if (gold_c == 4) {
            craft_output = .{ .item = .gold_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 159: Gold Nugget Unpacking: 1 Block of Gold -> 4 Gold Nuggets
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .gold_block and sl.count >= 1) {
                craft_output = .{ .item = .gold_nugget, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 156: Block of Redstone: 4 Redstone Dust (2x2 filled) -> 1 Block of Redstone
    if (non_empty == 4) {
        var red_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .redstone_dust) red_c += 1;
        }
        if (red_c == 4) {
            craft_output = .{ .item = .redstone_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 157: Redstone Dust Unpacking: 1 Block of Redstone -> 4 Redstone Dust
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .redstone_block and sl.count >= 1) {
                craft_output = .{ .item = .redstone_dust, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 154: Wooden Trapdoor: 1 Wooden Door -> 2 Wooden Trapdoors
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .wooden_door and sl.count >= 1) {
                craft_output = .{ .item = .wooden_trapdoor, .count = 2 };
                return craft_output;
            }
        }
    }

    // Recipe 155: Iron Trapdoor: 1 Iron Door -> 2 Iron Trapdoors
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .iron_door and sl.count >= 1) {
                craft_output = .{ .item = .iron_trapdoor, .count = 2 };
                return craft_output;
            }
        }
    }

    // Recipe 153: Observer: 2 Cobblestone + 1 Redstone Dust + 1 Nether Quartz -> 1 Observer
    if (non_empty >= 3) {
        var cobble_c: usize = 0;
        var red_c: usize = 0;
        var quartz_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .cobblestone or sl.item == .stone) cobble_c += sl.count;
            if (sl.item == .redstone_dust) red_c += sl.count;
            if (sl.item == .nether_quartz) quartz_c += sl.count;
        }
        if (cobble_c >= 2 and red_c >= 1 and quartz_c >= 1) {
            craft_output = .{ .item = .observer, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 151: Piston: 1 Wood Planks + 1 Cobblestone + 1 Iron Ingot + 1 Redstone Dust -> 1 Piston
    if (non_empty == 4) {
        var plank_c: usize = 0;
        var cobble_c: usize = 0;
        var iron_c: usize = 0;
        var red_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wood_planks) plank_c += sl.count;
            if (sl.item == .cobblestone or sl.item == .stone) cobble_c += sl.count;
            if (sl.item == .iron_ingot) iron_c += sl.count;
            if (sl.item == .redstone_dust) red_c += sl.count;
        }
        if (plank_c >= 1 and cobble_c >= 1 and iron_c >= 1 and red_c >= 1) {
            craft_output = .{ .item = .piston, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 152: Sticky Piston: 1 Piston + 1 Slimeball -> 1 Sticky Piston
    if (non_empty == 2) {
        var pist_c: usize = 0;
        var slime_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .piston) pist_c += sl.count;
            if (sl.item == .slimeball) slime_c += sl.count;
        }
        if (pist_c == 1 and slime_c == 1) {
            craft_output = .{ .item = .sticky_piston, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 149: Slime Block: 4 Slimeballs -> 1 Slime Block
    if (non_empty == 4) {
        var slime_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .slimeball) slime_c += sl.count;
        }
        if (slime_c == 4) {
            craft_output = .{ .item = .slime_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 150: Slimeballs: 1 Slime Block -> 4 Slimeballs
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .slime_block) {
                craft_output = .{ .item = .slimeball, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 148: Redstone Comparator: 1 Nether Quartz + 1 Redstone Torch (or 2) + 1 Stone (2x2 grid) -> 1 Redstone Comparator
    if (non_empty >= 3) {
        var quartz_c: usize = 0;
        var torch_c: usize = 0;
        var stone_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .nether_quartz) quartz_c += sl.count;
            if (sl.item == .redstone_torch or sl.item == .torch) torch_c += sl.count;
            if (sl.item == .stone or sl.item == .cobblestone) stone_c += sl.count;
        }
        if (quartz_c >= 1 and torch_c >= 1 and stone_c >= 1) {
            craft_output = .{ .item = .redstone_comparator, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 138: Water Breathing Potion (Pufferfish Brewing): 1 Pufferfish + 1 Glass vial (or nether wart / water) -> 1 Water Breathing Potion
    if (non_empty == 2) {
        var puff_c: usize = 0;
        var liquid_c: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .pufferfish) puff_c += 1;
            if (sl.item == .glass or sl.item == .water or sl.item == .nether_wart) liquid_c += 1;
        }
        if (puff_c == 1 and liquid_c == 1) {
            craft_output = .{ .item = .water_breathing_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 126: Water Breathing Potion: 1 Scute + 1 Glass vial (or water bucket / nether wart) -> 1 Water Breathing Potion
    if (non_empty == 2) {
        var scute_c: usize = 0;
        var liquid_catalyst: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .scute) scute_c += 1;
            if (sl.item == .glass or sl.item == .water or sl.item == .nether_wart) liquid_catalyst += 1;
        }
        if (scute_c == 1 and liquid_catalyst == 1) {
            craft_output = .{ .item = .water_breathing_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 122: Dragon's Breath Alchemy: 1 Glass (vial) + 1 Dragon Head / Chorus Fruit -> 1 Dragon's Breath
    if (non_empty == 2) {
        var glass_cnt: usize = 0;
        var dragon_catalyst: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .glass) glass_cnt += 1;
            if (sl.item == .dragon_head or sl.item == .dragon_egg or sl.item == .chorus_fruit) dragon_catalyst += 1;
        }
        if (glass_cnt == 1 and dragon_catalyst == 1) {
            craft_output = .{ .item = .dragons_breath, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 123: Lingering Poison Potion: 1 Dragon's Breath + 1 Poison Potion -> 1 Lingering Poison Potion
    if (non_empty == 2) {
        var breath_cnt: usize = 0;
        var poison_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .dragons_breath) breath_cnt += 1;
            if (sl.item == .poison_potion) poison_cnt += 1;
        }
        if (breath_cnt == 1 and poison_cnt == 1) {
            craft_output = .{ .item = .lingering_poison_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 124: Lingering Weakness Potion: 1 Dragon's Breath + 1 Weakness Potion -> 1 Lingering Weakness Potion
    if (non_empty == 2) {
        var breath_cnt: usize = 0;
        var weak_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .dragons_breath) breath_cnt += 1;
            if (sl.item == .weakness_potion) weak_cnt += 1;
        }
        if (breath_cnt == 1 and weak_cnt == 1) {
            craft_output = .{ .item = .lingering_weakness_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 121: End Gateway: 1 Dragon Head + 1 End Crystal -> 1 End Gateway
    if (non_empty == 2) {
        var head_cnt: usize = 0;
        var crys_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .dragon_head) head_cnt += 1;
            if (sl.item == .end_crystal) crys_cnt += 1;
        }
        if (head_cnt == 1 and crys_cnt == 1) {
            craft_output = .{ .item = .end_gateway, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 120: Dragon Head: 1 Dragon Egg + 1 Wither Skull -> 1 Dragon Head
    if (non_empty == 2) {
        var egg_cnt: usize = 0;
        var skull_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .dragon_egg) egg_cnt += 1;
            if (sl.item == .wither_skull) skull_cnt += 1;
        }
        if (egg_cnt == 1 and skull_cnt == 1) {
            craft_output = .{ .item = .dragon_head, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 119: Elytra: 2 Shulker Shells + 2 Purpur Blocks -> 1 Elytra
    if (non_empty == 4) {
        var shell_cnt: usize = 0;
        var purp_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .shulker_shell) shell_cnt += 1;
            if (sl.item == .purpur_block) purp_cnt += 1;
        }
        if (shell_cnt == 2 and purp_cnt == 2) {
            craft_output = .{ .item = .elytra, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 118: Shulker Box: 1 Chest + 2 Shulker Shells -> 1 Shulker Box
    if (non_empty == 3) {
        var chest_cnt: usize = 0;
        var shell_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .chest) chest_cnt += 1;
            if (sl.item == .shulker_shell) shell_cnt += 1;
        }
        if (chest_cnt == 1 and shell_cnt == 2) {
            craft_output = .{ .item = .shulker_box, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 115: Purpur Block from Popped Chorus Fruit: 4 Popped Chorus Fruit -> 4 Purpur Blocks
    if (non_empty == 4) {
        var pop_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .popped_chorus_fruit) pop_cnt += 1;
        }
        if (pop_cnt == 4) {
            craft_output = .{ .item = .purpur_block, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 116: End Rod with Chorus Fruit: 1 Blaze Rod + 1 Popped Chorus Fruit / Chorus Fruit -> 4 End Rods
    if (non_empty == 2) {
        const has_rod = (g0 == .blaze_rod or g1 == .blaze_rod or g2 == .blaze_rod or g3 == .blaze_rod);
        const has_fruit = (g0 == .chorus_fruit or g1 == .chorus_fruit or g2 == .chorus_fruit or g3 == .chorus_fruit or
            g0 == .popped_chorus_fruit or g1 == .popped_chorus_fruit or g2 == .popped_chorus_fruit or g3 == .popped_chorus_fruit);
        if (has_rod and has_fruit) {
            craft_output = .{ .item = .end_rod, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 117: 1 Chorus Fruit + 1 Coal -> 1 Popped Chorus Fruit (quick field roast)
    if (non_empty == 2) {
        const has_cf = (g0 == .chorus_fruit or g1 == .chorus_fruit or g2 == .chorus_fruit or g3 == .chorus_fruit);
        const has_fuel = (g0 == .coal or g1 == .coal or g2 == .coal or g3 == .coal);
        if (has_cf and has_fuel) {
            craft_output = .{ .item = .popped_chorus_fruit, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 112: Purpur Block: 4 End Stone -> 4 Purpur Blocks
    if (non_empty == 4) {
        var es_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .end_stone) es_cnt += 1;
        }
        if (es_cnt == 4) {
            craft_output = .{ .item = .purpur_block, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 113: Purpur Pillar: 2 Purpur Blocks -> 2 Purpur Pillars
    if (non_empty == 2) {
        const has_two_pb = ((g0 == .purpur_block and g2 == .purpur_block) or
            (g1 == .purpur_block and g3 == .purpur_block) or
            (g0 == .purpur_block and g1 == .purpur_block) or
            (g2 == .purpur_block and g3 == .purpur_block));
        if (has_two_pb) {
            craft_output = .{ .item = .purpur_pillar, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 114: End Rod: 1 Blaze Rod + 1 Ender Pearl/Eye of Ender -> 4 End Rods
    if (non_empty == 2) {
        const has_rod = (g0 == .blaze_rod or g1 == .blaze_rod or g2 == .blaze_rod or g3 == .blaze_rod);
        const has_pearl = (g0 == .ender_pearl or g1 == .ender_pearl or g2 == .ender_pearl or g3 == .ender_pearl or
            g0 == .eye_of_ender or g1 == .eye_of_ender or g2 == .eye_of_ender or g3 == .eye_of_ender);
        if (has_rod and has_pearl) {
            craft_output = .{ .item = .end_rod, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 111: End Crystal: 2 Glass + 1 Eye of Ender + 1 Blaze Powder/Nether Star/Ghast Tear -> 1 End Crystal
    if (non_empty == 4) {
        var glass_cnt: usize = 0;
        var eye_cnt: usize = 0;
        var catalyst_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .glass) glass_cnt += 1;
            if (sl.item == .eye_of_ender) eye_cnt += 1;
            if (sl.item == .blaze_powder or sl.item == .nether_star or sl.item == .magma_cream) catalyst_cnt += 1;
        }
        if (glass_cnt == 2 and eye_cnt == 1 and catalyst_cnt == 1) {
            craft_output = .{ .item = .end_crystal, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 109: End Stone: 1 Cobblestone + 1 Sandstone -> 2 End Stone
    if (non_empty == 2) {
        const has_cobb = (g0 == .cobblestone or g1 == .cobblestone or g2 == .cobblestone or g3 == .cobblestone);
        const has_sandstone = (g0 == .sandstone or g1 == .sandstone or g2 == .sandstone or g3 == .sandstone);
        if (has_cobb and has_sandstone) {
            craft_output = .{ .item = .end_stone, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 110: End Portal Frame: 3 End Stone + 1 Ender Pearl/Eye of Ender -> 1 End Portal Frame
    if (non_empty == 4) {
        var es_cnt: usize = 0;
        var relic_cnt: usize = 0;
        for (craft_grid) |sl| {
            if (sl.item == .end_stone) es_cnt += 1;
            if (sl.item == .ender_pearl or sl.item == .eye_of_ender) relic_cnt += 1;
        }
        if (es_cnt == 3 and relic_cnt == 1) {
            craft_output = .{ .item = .end_portal_frame, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 108: Eye of Ender: 1 Ender Pearl + 1 Blaze Powder -> 1 Eye of Ender
    if (non_empty == 2) {
        const has_pearl = (g0 == .ender_pearl or g1 == .ender_pearl or g2 == .ender_pearl or g3 == .ender_pearl);
        const has_powder = (g0 == .blaze_powder or g1 == .blaze_powder or g2 == .blaze_powder or g3 == .blaze_powder);
        if (has_pearl and has_powder) {
            craft_output = .{ .item = .eye_of_ender, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 107: TNT: 2 Sand + 2 Gunpowder (checkerboard) or 1 Sand + 1 Gunpowder -> 1 TNT
    if (non_empty == 4) {
        if ((g0 == .sand and g3 == .sand and g1 == .gunpowder and g2 == .gunpowder) or
            (g1 == .sand and g2 == .sand and g0 == .gunpowder and g3 == .gunpowder))
        {
            craft_output = .{ .item = .tnt, .count = 1 };
            return craft_output;
        }
    }
    if (non_empty == 2) {
        const has_sand = (g0 == .sand or g1 == .sand or g2 == .sand or g3 == .sand);
        const has_gunpowder = (g0 == .gunpowder or g1 == .gunpowder or g2 == .gunpowder or g3 == .gunpowder);
        if (has_sand and has_gunpowder) {
            craft_output = .{ .item = .tnt, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 106: Bone Meal: 1 Bone -> 3 Bone Meal
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .bone) {
                craft_output = .{ .item = .bone_meal, .count = 3 };
                return craft_output;
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
            craft_output = .{ .item = .fermented_spider_eye, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 105: Potion of Weakness: 1 Fermented Spider Eye + 1 Glass vial (or 1 Fermented Spider Eye + 1 Nether Wart) -> 1 Weakness Potion
    if (non_empty == 2) {
        const has_ferm = (g0 == .fermented_spider_eye or g1 == .fermented_spider_eye or g2 == .fermented_spider_eye or g3 == .fermented_spider_eye);
        const has_glass = (g0 == .glass or g1 == .glass or g2 == .glass or g3 == .glass);
        const has_wart = (g0 == .nether_wart or g1 == .nether_wart or g2 == .nether_wart or g3 == .nether_wart);
        if (has_ferm and (has_glass or has_wart)) {
            craft_output = .{ .item = .weakness_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 103: Potion of Poison: 1 Spider Eye + 1 Glass vial (or 1 Spider Eye + 1 Nether Wart) -> 1 Poison Potion
    if (non_empty == 2) {
        const has_eye = (g0 == .spider_eye or g1 == .spider_eye or g2 == .spider_eye or g3 == .spider_eye);
        const has_glass = (g0 == .glass or g1 == .glass or g2 == .glass or g3 == .glass);
        const has_wart = (g0 == .nether_wart or g1 == .nether_wart or g2 == .nether_wart or g3 == .nether_wart);
        if (has_eye and (has_glass or has_wart)) {
            craft_output = .{ .item = .poison_potion, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 102: Cobweb: 4 Strings -> 1 Cobweb
    if (non_empty == 4) {
        var string_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .string) string_count += 1;
        }
        if (string_count == 4) {
            craft_output = .{ .item = .cobweb, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 101: String: 1 Wool (or 1 Weeping Vines or 1 Twisting Vines) -> 4 Strings
    if (non_empty == 1) {
        for (craft_grid) |sl| {
            if (sl.item == .wool or sl.item == .weeping_vines or sl.item == .twisting_vines) {
                craft_output = .{ .item = .string, .count = 4 };
                return craft_output;
            }
        }
    }

    // Recipe 100: Tripwire Hook: 1 Iron Ingot + 1 Stick + 1 Wood Planks -> 2 Tripwire Hooks
    if (non_empty == 3) {
        var iron_count: u8 = 0;
        var stick_count: u8 = 0;
        var plank_count: u8 = 0;
        var other_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) iron_count += 1 else if (sl.item == .stick) stick_count += 1 else if (sl.item == .wood_planks) plank_count += 1 else if (!sl.isEmpty()) other_count += 1;
        }
        if (iron_count == 1 and stick_count == 1 and plank_count == 1 and other_count == 0) {
            craft_output = .{ .item = .tripwire_hook, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 99: Iron Bars: 2 Iron Ingots + 1 Cobblestone (or 2 Iron Ingots + 1 Sandstone) -> 4 Iron Bars
    if (non_empty == 3) {
        var iron_count: u8 = 0;
        var stone_count: u8 = 0;
        var other_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) iron_count += 1 else if (sl.item == .cobblestone or sl.item == .sandstone) stone_count += 1 else if (!sl.isEmpty()) other_count += 1;
        }
        if (iron_count == 2 and stone_count == 1 and other_count == 0) {
            craft_output = .{ .item = .iron_bars, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 98: Chain: 1 Iron Ingot + 1..2 Iron Ore (or 1 Iron Ingot + 1 Iron/Chain link) -> 2 Chains
    if (non_empty >= 2 and non_empty <= 3) {
        var ingot_count: u8 = 0;
        var ore_count: u8 = 0;
        var other_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) ingot_count += 1 else if (sl.item == .iron_ore) ore_count += 1 else if (!sl.isEmpty()) other_count += 1;
        }
        if (ingot_count >= 1 and ore_count >= 1 and other_count == 0) {
            craft_output = .{ .item = .chain, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 97: Soul Lantern: 1 Soul Torch + 1..3 Iron Ingots (or Iron Ore) -> 1 Soul Lantern
    if (non_empty >= 2 and non_empty <= 4) {
        var soul_torch_count: u8 = 0;
        var iron_count: u8 = 0;
        var other_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .soul_torch) soul_torch_count += 1 else if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1 else if (!sl.isEmpty()) other_count += 1;
        }
        if (soul_torch_count == 1 and iron_count >= 1 and other_count == 0) {
            craft_output = .{ .item = .soul_lantern, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 96: Lantern: 1 Torch + 1..3 Iron Ingots (or Iron Ore) -> 1 Lantern
    if (non_empty >= 2 and non_empty <= 4) {
        var torch_count: u8 = 0;
        var iron_count: u8 = 0;
        var other_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .torch) torch_count += 1 else if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1 else if (!sl.isEmpty()) other_count += 1;
        }
        if (torch_count == 1 and iron_count >= 1 and other_count == 0) {
            craft_output = .{ .item = .lantern, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 95: Stonecutter: 1 Iron Ingot + 1..3 Stone (or Cobblestone/Sandstone) -> 1 Stonecutter
    if (non_empty >= 2 and non_empty <= 4) {
        var iron_count: u8 = 0;
        var stone_count: u8 = 0;
        var other_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) iron_count += 1 else if (sl.item == .stone or sl.item == .cobblestone or sl.item == .sandstone) stone_count += 1 else if (!sl.isEmpty()) other_count += 1;
        }
        if (iron_count == 1 and stone_count >= 1 and other_count == 0) {
            craft_output = .{ .item = .stonecutter, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 94: Blast Furnace: 1 Furnace + 1 Iron Ingot (or Iron Ore) + 1 Stone (or Cobblestone/Sandstone) -> 1 Blast Furnace
    if (non_empty >= 3 and non_empty <= 5) {
        var furnace_count: u8 = 0;
        var iron_count: u8 = 0;
        var stone_count: u8 = 0;
        var other_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .furnace) furnace_count += 1 else if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1 else if (sl.item == .stone or sl.item == .cobblestone or sl.item == .sandstone) stone_count += 1 else if (!sl.isEmpty()) other_count += 1;
        }
        if (furnace_count == 1 and iron_count >= 1 and stone_count >= 1 and other_count == 0) {
            craft_output = .{ .item = .blast_furnace, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 93: Smoker: 1 Furnace + 1 Wood Planks (or Wood Log) -> 1 Smoker
    if (non_empty >= 2 and non_empty <= 4) {
        var furnace_count: u8 = 0;
        var wood_count: u8 = 0;
        var other_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .furnace) furnace_count += 1 else if (sl.item == .wood or sl.item == .wood_planks) wood_count += 1 else if (!sl.isEmpty()) other_count += 1;
        }
        if (furnace_count == 1 and wood_count >= 1 and other_count == 0) {
            craft_output = .{ .item = .smoker, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 92: Loom: 2 Wool (or Vines) + 2 Wood Planks -> 1 Loom
    if (non_empty == 4) {
        var thread_count: u8 = 0;
        var plank_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wool or sl.item == .weeping_vines or sl.item == .twisting_vines) thread_count += 1;
            if (sl.item == .wood_planks) plank_count += 1;
        }
        if (thread_count == 2 and plank_count == 2) {
            craft_output = .{ .item = .loom, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 91: Composter: 3 Wood Planks + 1 Stick -> 1 Composter
    if (non_empty == 4) {
        var plank_count: u8 = 0;
        var stick_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wood_planks) plank_count += 1;
            if (sl.item == .stick) stick_count += 1;
        }
        if (plank_count == 3 and stick_count == 1) {
            craft_output = .{ .item = .composter, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 90: Fletching Table: 2 Sticks (or Coal / Arrows) + 2 Wood Planks -> 1 Fletching Table
    if (non_empty == 4) {
        var fletch_mat_count: u8 = 0;
        var plank_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .stick or sl.item == .coal or sl.item == .arrow) fletch_mat_count += 1;
            if (sl.item == .wood_planks) plank_count += 1;
        }
        if (fletch_mat_count == 2 and plank_count == 2) {
            craft_output = .{ .item = .fletching_table, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 89: Cartography Table: 1 Compass (or Lodestone Compass / Redstone Dust) + 1 Wood Planks + 1..2 Sticks -> 1 Cartography Table
    if (non_empty >= 3 and non_empty <= 4) {
        var nav_count: u8 = 0;
        var plank_count: u8 = 0;
        var stick_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .compass or sl.item == .lodestone_compass or sl.item == .redstone_dust) nav_count += 1;
            if (sl.item == .wood_planks) plank_count += 1;
            if (sl.item == .stick) stick_count += 1;
        }
        if (nav_count == 1 and plank_count == 1 and (stick_count == 1 or stick_count == 2)) {
            craft_output = .{ .item = .cartography_table, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 88: Smithing Table: 2 Iron Ingots (or Iron Ore) + 2 Wood Planks -> 1 Smithing Table
    if (non_empty == 4) {
        var iron_count: u8 = 0;
        var plank_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1;
            if (sl.item == .wood_planks) plank_count += 1;
        }
        if (iron_count == 2 and plank_count == 2) {
            craft_output = .{ .item = .smithing_table, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 87: Grindstone: 1 Stone (or Cobblestone/Sandstone) + 2 Sticks + 1 Wood Planks -> 1 Grindstone
    if (non_empty == 4) {
        var stone_count: u8 = 0;
        var stick_count: u8 = 0;
        var plank_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .stone or sl.item == .cobblestone or sl.item == .sandstone) stone_count += 1;
            if (sl.item == .stick) stick_count += 1;
            if (sl.item == .wood_planks) plank_count += 1;
        }
        if (stone_count == 1 and stick_count == 2 and plank_count == 1) {
            craft_output = .{ .item = .grindstone, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 86: Anvil: 3 Iron Ingots (or Iron Ore) + 1 Cobblestone (or Stone) -> 1 Anvil
    if (non_empty == 4) {
        var iron_count: u8 = 0;
        var base_stone_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot or sl.item == .iron_ore) iron_count += 1;
            if (sl.item == .cobblestone or sl.item == .stone) base_stone_count += 1;
        }
        if (iron_count == 3 and base_stone_count == 1) {
            craft_output = .{ .item = .anvil, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 85: Enchantment Table: 2 Obsidian + 1 Nether Quartz (or Nether Star / Gold Nugget) + 1 Wood Planks (or Wool) -> 1 Enchantment Table
    if (non_empty == 4) {
        var obs_count: u8 = 0;
        var gem_count: u8 = 0;
        var book_cloth_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .obsidian or sl.item == .crying_obsidian) obs_count += 1;
            if (sl.item == .nether_quartz or sl.item == .nether_star or sl.item == .gold_nugget) gem_count += 1;
            if (sl.item == .wood_planks or sl.item == .wool) book_cloth_count += 1;
        }
        if (obs_count == 2 and gem_count == 1 and book_cloth_count == 1) {
            craft_output = .{ .item = .enchantment_table, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 84: Target Dummy: 1 Hay Bale + 1..2 Sticks + 1 Wood Planks (or Wool) -> 1 Target Dummy
    if (non_empty >= 3 and non_empty <= 4) {
        var hay_count: u8 = 0;
        var stick_count: u8 = 0;
        var wood_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .hay_bale) hay_count += 1;
            if (sl.item == .stick) stick_count += 1;
            if (sl.item == .wood_planks or sl.item == .wool) wood_count += 1;
        }
        if (hay_count == 1 and stick_count >= 1 and wood_count >= 1 and (hay_count + stick_count + wood_count == non_empty)) {
            craft_output = .{ .item = .target_dummy, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 83: Armor Stand: 1 Stone (smooth stone base) + 2..3 Sticks -> 1 Armor Stand
    if (non_empty >= 3 and non_empty <= 4) {
        var stone_count: u8 = 0;
        var stick_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .stone or sl.item == .cobblestone) stone_count += 1;
            if (sl.item == .stick) stick_count += 1;
        }
        if (stone_count == 1 and stick_count >= 2 and (stone_count + stick_count == non_empty)) {
            craft_output = .{ .item = .armor_stand, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 81: Oak Fence: 2 Wood Planks + 2 Sticks (4 items) or 2 Wood Planks vertically + 1 Stick (vertical column g0+g2 + g1 stick) -> 2 Oak Fences
    if (non_empty == 3) {
        // Vertical 2 planks (g0, g2) + stick (g1 or g3) or (g1, g3 planks + g0 or g2 stick)
        if ((g0 == .wood_planks and g2 == .wood_planks and (g1 == .stick or g3 == .stick)) or
            (g1 == .wood_planks and g3 == .wood_planks and (g0 == .stick or g2 == .stick)))
        {
            craft_output = .{ .item = .oak_fence, .count = 2 };
            return craft_output;
        }
    }
    if (non_empty == 4) {
        var plank_count: u8 = 0;
        var stick_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .wood_planks) plank_count += 1;
            if (sl.item == .stick) stick_count += 1;
        }
        if (plank_count == 2 and stick_count == 2) {
            craft_output = .{ .item = .oak_fence, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 78: Jukebox: 1 Gold Nugget / Nether Star / Nether Quartz + 2..3 Wood Planks -> 1 Jukebox
    if (non_empty >= 3 and non_empty <= 4) {
        var core_count: u8 = 0;
        var plank_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .gold_nugget or sl.item == .nether_star or sl.item == .nether_quartz) core_count += 1;
            if (sl.item == .wood_planks) plank_count += 1;
        }
        if (core_count == 1 and plank_count >= 2 and (core_count + plank_count == non_empty)) {
            craft_output = .{ .item = .jukebox, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 79: Music Disc (13): 1 Gold Nugget + 1 Coal -> 1 Music Disc (13)
    if (non_empty == 2) {
        var gold_count: u8 = 0;
        var coal_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .gold_nugget) gold_count += 1;
            if (sl.item == .coal) coal_count += 1;
        }
        if (gold_count == 1 and coal_count == 1) {
            craft_output = .{ .item = .music_disc_13, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 80: Music Disc (cat): 1 Warped Fungus + 1 Coal -> 1 Music Disc (cat)
    if (non_empty == 2) {
        var fungus_count: u8 = 0;
        var coal_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .warped_fungus) fungus_count += 1;
            if (sl.item == .coal) coal_count += 1;
        }
        if (fungus_count == 1 and coal_count == 1) {
            craft_output = .{ .item = .music_disc_cat, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 77: Note Block: 1 Redstone Dust + 2..3 Wood Planks -> 1 Note Block
    if (non_empty >= 3 and non_empty <= 4) {
        var red_count: u8 = 0;
        var plank_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .redstone_dust) red_count += 1;
            if (sl.item == .wood_planks) plank_count += 1;
        }
        if (red_count == 1 and plank_count >= 2 and (red_count + plank_count == non_empty)) {
            craft_output = .{ .item = .note_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 76: Daylight Detector: 1 Nether Quartz + 1 Glass + 1 Wood Planks -> 1 Daylight Detector
    if (non_empty == 3) {
        var quartz_count: u8 = 0;
        var glass_count: u8 = 0;
        var plank_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .nether_quartz) quartz_count += 1;
            if (sl.item == .glass) glass_count += 1;
            if (sl.item == .wood_planks) plank_count += 1;
        }
        if (quartz_count == 1 and glass_count == 1 and plank_count == 1) {
            craft_output = .{ .item = .daylight_detector, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 75: Cauldron: 2..4 Iron Ingots -> 1 Cauldron
    if (non_empty >= 2 and non_empty <= 4) {
        var iron_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) iron_count += 1;
        }
        if (iron_count == non_empty and iron_count >= 2) {
            craft_output = .{ .item = .cauldron, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 74: Brewing Stand: 1 Blaze Rod + 1..3 Cobblestone -> 1 Brewing Stand
    if (non_empty >= 2 and non_empty <= 4) {
        var rod_count: u8 = 0;
        var cobble_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .blaze_rod) rod_count += 1;
            if (sl.item == .cobblestone) cobble_count += 1;
        }
        if (rod_count == 1 and cobble_count >= 1 and (rod_count + cobble_count == non_empty)) {
            craft_output = .{ .item = .brewing_stand, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 72: Blaze Powder: 1 Blaze Rod -> 2 Blaze Powder
    if (non_empty == 1) {
        if (g0 == .blaze_rod or g1 == .blaze_rod or g2 == .blaze_rod or g3 == .blaze_rod) {
            craft_output = .{ .item = .blaze_powder, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 73: Fire Charge: 1 Blaze Powder + 1 Coal -> 3 Fire Charges
    if (non_empty == 2) {
        var powder_count: u8 = 0;
        var coal_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .blaze_powder) powder_count += 1;
            if (sl.item == .coal) coal_count += 1;
        }
        if (powder_count == 1 and coal_count == 1) {
            craft_output = .{ .item = .fire_charge, .count = 3 };
            return craft_output;
        }
    }

    // Recipe 71: Hopper: 1 Chest + 1..2 Iron Ingots -> 1 Hopper
    if (non_empty >= 2 and non_empty <= 3) {
        var has_chest = false;
        var iron_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .chest) has_chest = true;
            if (sl.item == .iron_ingot) iron_count += 1;
        }
        if (has_chest and iron_count >= 1 and ((if (has_chest) @as(u8, 1) else 0) + iron_count == non_empty)) {
            craft_output = .{ .item = .hopper, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 70: Dropper: 1 Redstone Dust + 2..3 Cobblestone -> 1 Dropper
    if (non_empty >= 3) {
        var has_red = false;
        var cobble_count: u8 = 0;
        var other_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .redstone_dust) {
                has_red = true;
            } else if (sl.item == .cobblestone) {
                cobble_count += 1;
            } else if (sl.item != .none and sl.item != .bow and sl.item != .crossbow) {
                other_count += 1;
            }
        }
        if (has_red and cobble_count >= 2 and (cobble_count + other_count + 1 == non_empty)) {
            craft_output = .{ .item = .dropper, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 69: Dispenser: 1 Bow/Crossbow + 1 Redstone Dust + 1..2 Cobblestone -> 1 Dispenser
    if (non_empty >= 3) {
        var has_launcher = false;
        var has_red = false;
        var cobble_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .bow or sl.item == .crossbow) has_launcher = true;
            if (sl.item == .redstone_dust) has_red = true;
            if (sl.item == .cobblestone) cobble_count += 1;
        }
        if (has_launcher and has_red and cobble_count >= 1 and ((if (has_launcher) @as(u8, 1) else 0) + (if (has_red) @as(u8, 1) else 0) + cobble_count == non_empty)) {
            craft_output = .{ .item = .dispenser, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 68: Fireworks Rocket: 1 Fire Charge + 1 Wool (or 1 Fire Charge + 1 Wood Planks) -> 3 Fireworks Rockets
    if (non_empty == 2) {
        const has_fire = (g0 == .fire_charge or g1 == .fire_charge or g2 == .fire_charge or g3 == .fire_charge);
        const has_casing = (g0 == .wool or g1 == .wool or g2 == .wool or g3 == .wool or
            g0 == .wood_planks or g1 == .wood_planks or g2 == .wood_planks or g3 == .wood_planks);
        if (has_fire and has_casing) {
            craft_output = .{ .item = .fireworks_rocket, .count = 3 };
            return craft_output;
        }
    }

    // Recipe 67: Crossbow: 1 Iron Ingot + 1 Stick + 1 Wool/Vines (or 1 Iron + 2 Sticks + 1 Wool/Vines) -> 1 Crossbow
    if (non_empty >= 3) {
        var iron_count: u8 = 0;
        var stick_count: u8 = 0;
        var fiber_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) iron_count += 1;
            if (sl.item == .stick) stick_count += 1;
            if (sl.item == .wool or sl.item == .twisting_vines or sl.item == .weeping_vines) fiber_count += 1;
        }
        if (iron_count >= 1 and stick_count >= 1 and fiber_count >= 1 and (iron_count + stick_count + fiber_count == non_empty)) {
            craft_output = .{ .item = .crossbow, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 66: Compass: 1 Iron Ingot + 1 Redstone Dust -> 1 Compass
    if (non_empty == 2) {
        const has_iron = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        const has_red = (g0 == .redstone_dust or g1 == .redstone_dust or g2 == .redstone_dust or g3 == .redstone_dust);
        if (has_iron and has_red) {
            craft_output = .{ .item = .compass, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 65: Shield: 1 Iron Ingot + 2 Wood Planks (or 1 Iron Ingot + 3 Wood Planks) -> 1 Shield
    if (non_empty == 3 or non_empty == 4) {
        var iron_count: u8 = 0;
        var plank_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .iron_ingot) iron_count += 1;
            if (sl.item == .wood_planks) plank_count += 1;
        }
        if (iron_count == 1 and (plank_count == 2 or plank_count == 3) and (iron_count + plank_count == non_empty)) {
            craft_output = .{ .item = .shield, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 64: Bow: 2 Sticks + 1 Wool (or 2 Sticks + 1 Twisting Vines/Weeping Vines) -> 1 Bow
    if (non_empty == 3) {
        var stick_count: u8 = 0;
        var fiber_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .stick) stick_count += 1;
            if (sl.item == .wool or sl.item == .twisting_vines or sl.item == .weeping_vines) fiber_count += 1;
        }
        if (stick_count == 2 and fiber_count == 1) {
            craft_output = .{ .item = .bow, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 63: Arrow: 1 Stick + 1 Iron Ingot (or 1 Stick + 1 Nether Quartz) -> 4 Arrows
    if (non_empty == 2) {
        const has_stick = (g0 == .stick or g1 == .stick or g2 == .stick or g3 == .stick);
        const has_point = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot or
            g0 == .nether_quartz or g1 == .nether_quartz or g2 == .nether_quartz or g3 == .nether_quartz);
        if (has_stick and has_point) {
            craft_output = .{ .item = .arrow, .count = 4 };
            return craft_output;
        }
    }

    // Recipe 62: Spectral Arrow: 1 Glowstone + 1 Stick (or 1 Glowstone + 1 Iron Ingot) -> 2 Spectral Arrows
    if (non_empty == 2) {
        const has_glow = (g0 == .glowstone or g1 == .glowstone or g2 == .glowstone or g3 == .glowstone);
        const has_shaft = (g0 == .stick or g1 == .stick or g2 == .stick or g3 == .stick or
            g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot);
        if (has_glow and has_shaft) {
            craft_output = .{ .item = .spectral_arrow, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 61: Netherite Boots: 1 Netherite Ingot + 1 Gold Nugget / Diamond Boots -> 1 Netherite Boots
    if (non_empty == 2) {
        const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot or
            g0 == .netherite_scrap or g1 == .netherite_scrap or g2 == .netherite_scrap or g3 == .netherite_scrap);
        const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget or
            g0 == .diamond_boots or g1 == .diamond_boots or g2 == .diamond_boots or g3 == .diamond_boots);
        if (has_ni and has_gold) {
            craft_output = .{ .item = .netherite_boots, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 60: Chiseled Nether Brick: 2 Nether Bricks -> 1 Chiseled Nether Brick
    if (non_empty == 2) {
        var nb_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .nether_brick) nb_count += 1;
        }
        if (nb_count == 2) {
            craft_output = .{ .item = .chiseled_nether_brick, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 59: Netherite Leggings: 1 Netherite Ingot + 1 Obsidian / Diamond Leggings (or 2 Netherite Scrap) -> 1 Netherite Leggings
    if (non_empty == 2) {
        const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
        const has_obs = (g0 == .obsidian or g1 == .obsidian or g2 == .obsidian or g3 == .obsidian or
            g0 == .diamond_leggings or g1 == .diamond_leggings or g2 == .diamond_leggings or g3 == .diamond_leggings);
        var scraps: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.item == .netherite_scrap) scraps += 1;
        }
        if ((has_ni and has_obs) or scraps == 2) {
            craft_output = .{ .item = .netherite_leggings, .count = 1 };
            return craft_output;
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
            craft_output = .{ .item = .netherite_helmet, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 57: Soul Speed Boots: 1 Iron Ingot + 1 Soul Sand (or 1 Netherite Ingot + 1 Soul Sand) -> 1 Soul Speed Boots
    if (non_empty == 2) {
        const has_metal = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot or
            g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
        const has_soul = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand);
        if (has_metal and has_soul) {
            craft_output = .{ .item = .soul_speed_boots, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 56: Netherite Chestplate: 1 Netherite Ingot + 1 Iron Ingot / Diamond Chestplate -> 1 Netherite Chestplate
    if (non_empty == 2) {
        const has_ni = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
        const has_base = (g0 == .iron_ingot or g1 == .iron_ingot or g2 == .iron_ingot or g3 == .iron_ingot or
            g0 == .diamond_chestplate or g1 == .diamond_chestplate or g2 == .diamond_chestplate or g3 == .diamond_chestplate);
        if (has_ni and has_base) {
            craft_output = .{ .item = .netherite_chestplate, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 55: Warped Fungus on a Stick: 1 Stick + 1 Warped Fungus -> 1 Warped Fungus on a Stick
    if (non_empty == 2) {
        const has_stick = (g0 == .stick or g1 == .stick or g2 == .stick or g3 == .stick);
        const has_wf = (g0 == .warped_fungus or g1 == .warped_fungus or g2 == .warped_fungus or g3 == .warped_fungus);
        if (has_stick and has_wf) {
            craft_output = .{ .item = .warped_fungus_on_a_stick, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 54: Shroomlight: 1 Glowstone + 1 Fungus (Crimson or Warped) -> 1 Shroomlight
    if (non_empty == 2) {
        const has_glow = (g0 == .glowstone or g1 == .glowstone or g2 == .glowstone or g3 == .glowstone);
        const has_fungus = (g0 == .crimson_fungus or g1 == .crimson_fungus or g2 == .crimson_fungus or g3 == .crimson_fungus or
            g0 == .warped_fungus or g1 == .warped_fungus or g2 == .warped_fungus or g3 == .warped_fungus);
        if (has_glow and has_fungus) {
            craft_output = .{ .item = .shroomlight, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 53: Warped Fungus: 1 Twisting Vines + 1 Sapling (or 1 Crimson Fungus + 1 Soul Sand) -> 2 Warped Fungus
    if (non_empty == 2) {
        const has_twist = (g0 == .twisting_vines or g1 == .twisting_vines or g2 == .twisting_vines or g3 == .twisting_vines);
        const has_sap = (g0 == .sapling or g1 == .sapling or g2 == .sapling or g3 == .sapling);
        const has_crim = (g0 == .crimson_fungus or g1 == .crimson_fungus or g2 == .crimson_fungus or g3 == .crimson_fungus);
        const has_soul = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand);
        if ((has_twist and has_sap) or (has_crim and has_soul)) {
            craft_output = .{ .item = .warped_fungus, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 52: Crimson Fungus: 1 Nether Wart + 1 Sapling -> 2 Crimson Fungus
    if (non_empty == 2) {
        const has_wart = (g0 == .nether_wart or g1 == .nether_wart or g2 == .nether_wart or g3 == .nether_wart);
        const has_sap = (g0 == .sapling or g1 == .sapling or g2 == .sapling or g3 == .sapling);
        if (has_wart and has_sap) {
            craft_output = .{ .item = .crimson_fungus, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 51: Hay Bale: 2 Wood Planks + 2 Saplings/Leaves (or 4 Saplings) -> 1 Hay Bale
    if (non_empty == 4) {
        var bio_count: u8 = 0;
        var wood_count: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.isEmpty()) continue;
            if (sl.item == .sapling or sl.item == .leaves) bio_count += 1 else if (sl.item == .wood_planks) wood_count += 1;
        }
        if ((bio_count == 2 and wood_count == 2) or bio_count == 4) {
            craft_output = .{ .item = .hay_bale, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 50: Target Block: 1 Redstone Dust + 1 Wood Planks (or 1 Hay/Wheat) -> 1 Target Block
    if (non_empty == 2) {
        const has_red = (g0 == .redstone_dust or g1 == .redstone_dust or g2 == .redstone_dust or g3 == .redstone_dust);
        const has_wood = (g0 == .wood_planks or g1 == .wood_planks or g2 == .wood_planks or g3 == .wood_planks or g0 == .hay_bale or g1 == .hay_bale or g2 == .hay_bale or g3 == .hay_bale);
        if (has_red and has_wood) {
            craft_output = .{ .item = .target_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 49: Twisting Vines: 1 Weeping Vines + 1 Soul Sand (or Soul Torch) -> 2 Twisting Vines
    if (non_empty == 2) {
        const has_weep = (g0 == .weeping_vines or g1 == .weeping_vines or g2 == .weeping_vines or g3 == .weeping_vines);
        const has_warp = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand or
            g0 == .soul_torch or g1 == .soul_torch or g2 == .soul_torch or g3 == .soul_torch);
        if (has_weep and has_warp) {
            craft_output = .{ .item = .twisting_vines, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 48: Weeping Vines: 2 Nether Wart stacked vertically -> 2 Weeping Vines
    if (non_empty == 2) {
        if ((g0 == .nether_wart and g2 == .nether_wart and g1 == .none and g3 == .none) or
            (g1 == .nether_wart and g3 == .nether_wart and g0 == .none and g2 == .none))
        {
            craft_output = .{ .item = .weeping_vines, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 47: Golden Apple via Nuggets: 2 Apples + 2 Gold Nuggets -> 1 Golden Apple
    if (non_empty == 4) {
        var apple_cnt: u8 = 0;
        var nugget_cnt: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.isEmpty()) continue;
            if (sl.item == .apple) apple_cnt += 1 else if (sl.item == .gold_nugget) nugget_cnt += 1;
        }
        if (apple_cnt == 2 and nugget_cnt == 2) {
            craft_output = .{ .item = .golden_apple, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 46: Gilded Blackstone: 1 Blackstone + 1 Gold Nugget -> 1 Gilded Blackstone
    if (non_empty == 2) {
        const has_blackstone = (g0 == .blackstone or g1 == .blackstone or g2 == .blackstone or g3 == .blackstone);
        const has_gold = (g0 == .gold_nugget or g1 == .gold_nugget or g2 == .gold_nugget or g3 == .gold_nugget);
        if (has_blackstone and has_gold) {
            craft_output = .{ .item = .gilded_blackstone, .count = 1 };
            return craft_output;
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
            craft_output = .{ .item = .blackstone, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 44: Basalt: 1 Cobblestone + 1 Soul Sand (or Magma) -> 2 Basalt
    if (non_empty == 2) {
        const has_cobble = (g0 == .cobblestone or g1 == .cobblestone or g2 == .cobblestone or g3 == .cobblestone);
        const has_volcanic = (g0 == .soul_sand or g1 == .soul_sand or g2 == .soul_sand or g3 == .soul_sand or
            g0 == .magma or g1 == .magma or g2 == .magma or g3 == .magma);
        if (has_cobble and has_volcanic) {
            craft_output = .{ .item = .basalt, .count = 2 };
            return craft_output;
        }
    }

    // Recipe 43: Lodestone: 1 Netherite Ingot + 1 Chiseled Quartz (or Quartz Block) -> 1 Lodestone
    if (non_empty == 2) {
        const has_netherite = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
        const has_carved_stone = (g0 == .chiseled_quartz_block or g1 == .chiseled_quartz_block or g2 == .chiseled_quartz_block or g3 == .chiseled_quartz_block or
            g0 == .quartz_block or g1 == .quartz_block or g2 == .quartz_block or g3 == .quartz_block or
            g0 == .stone or g1 == .stone or g2 == .stone or g3 == .stone);
        if (has_netherite and has_carved_stone) {
            craft_output = .{ .item = .lodestone, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 42: Crying Obsidian: 1 Obsidian + 1 Magma Cream -> 1 Crying Obsidian
    if (non_empty == 2) {
        const has_obs = (g0 == .obsidian or g1 == .obsidian or g2 == .obsidian or g3 == .obsidian);
        const has_magma_cream = (g0 == .magma_cream or g1 == .magma_cream or g2 == .magma_cream or g3 == .magma_cream);
        if (has_obs and has_magma_cream) {
            craft_output = .{ .item = .crying_obsidian, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 41: Respawn Anchor: 2 Obsidian (or Crying Obsidian) + 2 Glowstone (full 2x2, any layout) -> 1 Respawn Anchor
    {
        var obs: u8 = 0;
        var glow: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.isEmpty()) continue;
            if (sl.item == .obsidian or sl.item == .crying_obsidian) obs += 1 else if (sl.item == .glowstone) glow += 1 else {
                obs = 99;
                break;
            }
        }
        if (obs == 2 and glow == 2) {
            craft_output = .{ .item = .respawn_anchor, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 40: Netherite Sword: 1 Iron/Diamond Sword + 1 Netherite Ingot (non_empty == 2) -> 1 Netherite Sword
    if (non_empty == 2) {
        const has_sword = (g0 == .iron_sword or g1 == .iron_sword or g2 == .iron_sword or g3 == .iron_sword or
            g0 == .diamond_sword or g1 == .diamond_sword or g2 == .diamond_sword or g3 == .diamond_sword);
        const has_ingot = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
        if (has_sword and has_ingot) {
            craft_output = .{ .item = .netherite_sword, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 39: Netherite Pickaxe: 1 Iron/Diamond Pickaxe + 1 Netherite Ingot (non_empty == 2) -> 1 Netherite Pickaxe
    if (non_empty == 2) {
        const has_pick = (g0 == .iron_pickaxe or g1 == .iron_pickaxe or g2 == .iron_pickaxe or g3 == .iron_pickaxe or
            g0 == .diamond_pickaxe or g1 == .diamond_pickaxe or g2 == .diamond_pickaxe or g3 == .diamond_pickaxe);
        const has_ingot = (g0 == .netherite_ingot or g1 == .netherite_ingot or g2 == .netherite_ingot or g3 == .netherite_ingot);
        if (has_pick and has_ingot) {
            craft_output = .{ .item = .netherite_pickaxe, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 38: Netherite Ingot: 2 Netherite Scrap + 2 Iron Ingot (full 2x2, any layout) -> 1 Netherite Ingot
    {
        var scraps: u8 = 0;
        var iron_ingots: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.isEmpty()) continue;
            if (sl.item == .netherite_scrap) scraps += 1 else if (sl.item == .iron_ingot) iron_ingots += 1 else {
                scraps = 99;
                break;
            }
        }
        if (scraps == 2 and iron_ingots == 2) {
            craft_output = .{ .item = .netherite_ingot, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 37: Beacon: 1 Nether Star + 1 Obsidian + 2 Glass (full 2x2, any layout) -> 1 Beacon
    {
        var stars: u8 = 0;
        var obs: u8 = 0;
        var glasses: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.isEmpty()) continue;
            if (sl.item == .nether_star) stars += 1 else if (sl.item == .obsidian) obs += 1 else if (sl.item == .glass) glasses += 1 else {
                stars = 99;
                break;
            }
        }
        if (stars == 1 and obs == 1 and glasses == 2) {
            craft_output = .{ .item = .beacon, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 13: Golden Apple: 2 apples + 1 iron ingot + 1 coal (full 2x2, any layout)
    {
        var apples: u8 = 0;
        var ingots: u8 = 0;
        var coals: u8 = 0;
        for (craft_grid) |sl| {
            if (sl.isEmpty()) continue;
            if (sl.item == .apple) apples += 1 else if (sl.item == .iron_ingot) ingots += 1 else if (sl.item == .coal) coals += 1 else {
                apples = 99;
                break;
            }
        }
        if (apples == 2 and ingots == 1 and coals == 1 and non_empty == 4) {
            craft_output = .{ .item = .golden_apple, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 12: 4 Snowballs (2x2) -> 1 Snow Block
    if (non_empty == 4) {
        if (g0 == .snowball and g1 == .snowball and g2 == .snowball and g3 == .snowball) {
            craft_output = .{ .item = .snow_block, .count = 1 };
            return craft_output;
        }
    }

    // Recipe 10: 4 Stone (2x2) -> 1 Furnace (bricks own 4-cobble)
    if (non_empty == 4) {
        if (g0 == .stone and g1 == .stone and g2 == .stone and g3 == .stone) {
            craft_output = .{ .item = .furnace, .count = 1 };
            return craft_output;
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
                craft_output = .{ .item = done, .count = 1 };
                return craft_output;
            }
        }
    }

    // Recipe 7: Smelting simulation in 2x2: 1 Sand + 1 Coal -> 2 Glass
    if (non_empty == 2) {
        if ((g0 == .sand and g2 == .coal) or (g1 == .sand and g3 == .coal) or
            (g0 == .coal and g2 == .sand) or (g1 == .coal and g3 == .sand))
        {
            craft_output = .{ .item = .glass, .count = 2 };
            return craft_output;
        }
    }

    // Wave 4 recipe 305: Book + Lapis Lazuli -> Enchanted Book.
    if (non_empty == 2) {
        var has_book = false;
        var has_lapis = false;
        for (craft_grid) |slot| {
            has_book = has_book or slot.item == .book;
            has_lapis = has_lapis or slot.item == .lapis_lazuli;
        }
        if (has_book and has_lapis) {
            craft_output = .{ .item = .enchanted_book, .count = 1 };
            return craft_output;
        }
    }

    // Wave 4 recipe 306: Enchanted Book + Emerald -> Mending Book.
    if (non_empty == 2) {
        var has_enchanted = false;
        var has_emerald = false;
        for (craft_grid) |slot| {
            has_enchanted = has_enchanted or slot.item == .enchanted_book;
            has_emerald = has_emerald or slot.item == .emerald;
        }
        if (has_enchanted and has_emerald) {
            craft_output = .{ .item = .mending_book, .count = 1 };
            return craft_output;
        }
    }

    // Wave 4 recipe 307: Turtle Egg + Seagrass + Potion + Turtle Helmet -> Fox Treat.
    if (non_empty == 4) {
        var eggs: u8 = 0;
        var grass: u8 = 0;
        var potions: u8 = 0;
        var helmets: u8 = 0;
        for (craft_grid) |slot| {
            switch (slot.item) {
                .turtle_egg => eggs += 1,
                .seagrass => grass += 1,
                .potion_of_turtle_master => potions += 1,
                .turtle_helmet => helmets += 1,
                else => {},
            }
        }
        if (eggs == 1 and grass == 1 and potions == 1 and helmets == 1) {
            craft_output = .{ .item = .sweet_berry_fox_treat, .count = 2 };
            return craft_output;
        }
    }

    // Wave 5: gunpowder turns a water bottle or harming potion into its splash form.
    if (non_empty == 2) {
        var has_gunpowder = false;
        var has_water_bottle = false;
        var has_harming = false;
        for (craft_grid) |slot| {
            has_gunpowder = has_gunpowder or slot.item == .gunpowder;
            has_water_bottle = has_water_bottle or slot.item == .water_bottle;
            has_harming = has_harming or slot.item == .harming_potion;
        }
        if (has_gunpowder and has_water_bottle) {
            craft_output = .{ .item = .splash_water_bottle, .count = 1 };
            return craft_output;
        }
        if (has_gunpowder and has_harming) {
            craft_output = .{ .item = .splash_harming_potion, .count = 1 };
            return craft_output;
        }
    }

    // Wave 6 recipes: four Terracotta make Glazed Terracotta; two matching
    // metal ingredients make their weighted plate variant.
    if (non_empty == 4 and g0 == .terracotta and g1 == .terracotta and g2 == .terracotta and g3 == .terracotta) {
        craft_output = .{ .item = .glazed_terracotta, .count = 1 };
        return craft_output;
    }
    if (wave9CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }
    if (wave10CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }
    if (wave11CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }
    if (wave12CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }
    if (wave13CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }
    if (wave14CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }
    if (wave15CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }
    if (wave16CraftingRecipe(craft_grid)) |output| {
        craft_output = output;
        return craft_output;
    }
    craft_output.clear();

    return craft_output;
}

test "resolveCraftOutput: basic 2x2 recipes, resin brick recipe, and empty grid" {
    // Empty grid -> .none
    const empty_out = resolveCraftOutput([_]ItemStack{.{}} ** 4);
    try std.testing.expectEqual(ItemType.none, empty_out.item);
    try std.testing.expectEqual(@as(u8, 0), empty_out.count);

    // Basic 2x2: wood to wood_planks
    const wood_grid = [4]ItemStack{
        .{ .item = .wood, .count = 1 },
        .{},
        .{},
        .{},
    };
    const planks_out = resolveCraftOutput(wood_grid);
    try std.testing.expectEqual(ItemType.wood_planks, planks_out.item);
    try std.testing.expectEqual(@as(u8, 4), planks_out.count);

    // 4 resin_brick -> resin_bricks
    const resin_brick_grid = [4]ItemStack{
        .{ .item = .resin_brick, .count = 1 },
        .{ .item = .resin_brick, .count = 1 },
        .{ .item = .resin_brick, .count = 1 },
        .{ .item = .resin_brick, .count = 1 },
    };
    const resin_bricks_out = resolveCraftOutput(resin_brick_grid);
    try std.testing.expectEqual(ItemType.resin_bricks, resin_bricks_out.item);
    try std.testing.expectEqual(@as(u8, 1), resin_bricks_out.count);

    // Rejecting resin_clump (4 resin_clump -> .none)
    const resin_clump_grid = [4]ItemStack{
        .{ .item = .resin_clump, .count = 1 },
        .{ .item = .resin_clump, .count = 1 },
        .{ .item = .resin_clump, .count = 1 },
        .{ .item = .resin_clump, .count = 1 },
    };
    const clump_out = resolveCraftOutput(resin_clump_grid);
    try std.testing.expectEqual(ItemType.none, clump_out.item);
    try std.testing.expectEqual(@as(u8, 0), clump_out.count);
}
