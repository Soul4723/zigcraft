const std = @import("std");
const smelting = @import("world/smelting.zig");
const inv_mod = @import("inventory.zig");

const Inventory = inv_mod.Inventory;
const ItemStack = inv_mod.ItemStack;
const ItemType = inv_mod.ItemType;
const BlockId = inv_mod.BlockId;
const canHarvestBlock = inv_mod.canHarvestBlock;
const MobType = inv_mod.MobType;
const getMobMeatDrop = inv_mod.getMobMeatDrop;
const BarterReward = inv_mod.BarterReward;
const getPiglinBarter = inv_mod.getPiglinBarter;
const getEmberBonus = inv_mod.getEmberBonus;
const dropsWitherSkull = inv_mod.dropsWitherSkull;
const dropsSpiderEye = inv_mod.dropsSpiderEye;
const dropsSkeletonArrow = inv_mod.dropsSkeletonArrow;
const dropsDrownedNautilus = inv_mod.dropsDrownedNautilus;
const dropsDrownedTrident = inv_mod.dropsDrownedTrident;
const dropsEyeShatter = inv_mod.dropsEyeShatter;
const dropsZombieIron = inv_mod.dropsZombieIron;
const BlockDrop = inv_mod.BlockDrop;
const getBlockDrops = inv_mod.getBlockDrops;
const fortressLoot = inv_mod.fortressLoot;

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

    // Recipe 82: 4 String + 1 Slimeball -> 2 Leads
    inv.craft_grid[0] = .{ .item = .string, .count = 4 };
    inv.craft_grid[1] = .{ .item = .slimeball, .count = 1 };
    inv.craft_grid[2].clear();
    inv.craft_grid[3].clear();
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .lead);
    try std.testing.expectEqual(inv.craft_output.count, 2);
    var cursor = ItemStack{};
    try std.testing.expect(inv.takeCraftResult(&cursor));
    try std.testing.expectEqual(@as(u8, 2), cursor.count);
    try std.testing.expect(inv.craft_grid[0].isEmpty());
    try std.testing.expect(inv.craft_grid[1].isEmpty());

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
    inv.craft_grid[1] = .{ .item = .echo_shard, .count = 2 };
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
    inv.craft_grid[1] = .{ .item = .amethyst_shard, .count = 2 };
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

    inv.craft_grid[0] = .{ .item = .resin_clump, .count = 1 };
    inv.craft_grid[1] = .{ .item = .resin_clump, .count = 1 };
    inv.craft_grid[2] = .{ .item = .resin_clump, .count = 1 };
    inv.craft_grid[3] = .{ .item = .resin_clump, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.none, inv.craft_output.item);

    // Recipe 296: Creaking Heart
    inv.craft_grid[0] = .{ .item = .pale_oak_log, .count = 1 };
    inv.craft_grid[1] = .{ .item = .resin_bricks, .count = 1 };
    inv.craft_grid[2] = .{ .item = .pale_oak_log, .count = 1 };
    inv.craft_grid[3] = .{};
    inv.updateCrafting();
    try std.testing.expectEqual(inv.craft_output.item, .creaking_heart);
    try std.testing.expectEqual(inv.craft_output.count, 1);
}

test "resin furnace item IDs match inventory items and recipe 295 crafting" {
    try std.testing.expectEqual(@as(u16, @intFromEnum(ItemType.resin_clump)), smelting.ResinClump);
    try std.testing.expectEqual(@as(u16, @intFromEnum(ItemType.resin_brick)), smelting.ResinBrick);
    try std.testing.expectEqual(@as(u16, 411), smelting.ResinClump);
    try std.testing.expectEqual(@as(u16, 412), smelting.ResinBrick);

    var inv = Inventory.init();
    inv.craft_grid[0] = .{ .item = .resin_brick, .count = 1 };
    inv.craft_grid[1] = .{ .item = .resin_brick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .resin_brick, .count = 1 };
    inv.craft_grid[3] = .{ .item = .resin_brick, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.resin_bricks, inv.craft_output.item);
    try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);

    inv.craft_grid[0] = .{ .item = .resin_clump, .count = 1 };
    inv.craft_grid[1] = .{ .item = .resin_clump, .count = 1 };
    inv.craft_grid[2] = .{ .item = .resin_clump, .count = 1 };
    inv.craft_grid[3] = .{ .item = .resin_clump, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.none, inv.craft_output.item);

    inv.craft_grid[0] = .{ .item = .resin_brick, .count = 1 };
    inv.craft_grid[1] = .{ .item = .resin_brick, .count = 1 };
    inv.craft_grid[2] = .{ .item = .resin_clump, .count = 1 };
    inv.craft_grid[3] = .{ .item = .resin_clump, .count = 1 };
    inv.updateCrafting();
    try std.testing.expectEqual(ItemType.none, inv.craft_output.item);
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

    // Recipe 301: Bundle (1 String + 2 Leather)
    inv.craft_grid[0] = .{ .item = .string, .count = 1 };
    inv.craft_grid[1] = .{ .item = .leather, .count = 2 };
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
    for (recipes) |recipe_item| {
        inv.craft_grid = .{ .{ .item = recipe_item.a, .count = 1 }, .{ .item = recipe_item.b, .count = 1 }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe_item.out, inv.craft_output.item);
        try std.testing.expectEqual(recipe_item.count, inv.craft_output.count);
    }
}

test "Wave 14 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 522), @intFromEnum(ItemType.granite));
    try std.testing.expectEqual(@as(u16, 532), @intFromEnum(ItemType.sculk_vein));
    try std.testing.expectEqual(@as(u8, 16), ItemType.wooden_sign.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.granite.maxStackSize());
    try std.testing.expectEqualStrings("Granite", ItemType.granite.name());
    try std.testing.expectEqualStrings("Wooden Sign", ItemType.wooden_sign.name());
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType, count: u8 }{
        .{ .a = .cobblestone, .b = .nether_quartz, .out = .diorite, .count = 2 },
        .{ .a = .diorite, .b = .nether_quartz, .out = .granite, .count = 1 },
        .{ .a = .diorite, .b = .cobblestone, .out = .andesite, .count = 2 },
        .{ .a = .granite, .b = .stonecutter, .out = .polished_granite, .count = 1 },
        .{ .a = .oak_fence, .b = .stick, .out = .fence_gate, .count = 1 },
        .{ .a = .sculk, .b = .echo_shard, .out = .sculk_vein, .count = 4 },
    };
    for (recipes) |recipe| {
        inv.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe.out, inv.craft_output.item);
        try std.testing.expectEqual(recipe.count, inv.craft_output.count);
    }
}

test "Wave 15 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 533), @intFromEnum(ItemType.chunk_loader_token));
    try std.testing.expectEqual(@as(u16, 542), @intFromEnum(ItemType.cramming_disperser));
    try std.testing.expectEqual(@as(u8, 16), ItemType.chunk_loader_token.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.redstone_inverter_core.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.moon_phase_talisman.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.repeater_latch_lock.maxStackSize());
    try std.testing.expectEqualStrings("Chunk Loader Token", ItemType.chunk_loader_token.name());
    try std.testing.expectEqualStrings("Cramming Disperser", ItemType.cramming_disperser.name());
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType, count: u8 }{
        .{ .a = .ender_pearl, .b = .obsidian, .out = .chunk_loader_token, .count = 1 },
        .{ .a = .redstone_torch, .b = .iron_ingot, .out = .redstone_inverter_core, .count = 1 },
        .{ .a = .clock, .b = .lapis_lazuli, .out = .moon_phase_talisman, .count = 1 },
        .{ .a = .redstone_repeater, .b = .lever, .out = .repeater_latch_lock, .count = 1 },
        .{ .a = .observer, .b = .slime_block, .out = .flying_machine_core, .count = 1 },
        .{ .a = .banner, .b = .rotten_flesh, .out = .zombie_siege_banner, .count = 1 },
    };
    for (recipes) |recipe| {
        inv.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe.out, inv.craft_output.item);
        try std.testing.expectEqual(recipe.count, inv.craft_output.count);
    }
}

test "Wave 16 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 543), @intFromEnum(ItemType.target_block_core));
    try std.testing.expectEqual(@as(u16, 552), @intFromEnum(ItemType.tripwire_tension_gauge));
    try std.testing.expectEqual(@as(u8, 64), ItemType.target_block_core.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.lightning_deflector.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.frosted_ice_shard.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.soul_speed_talisman.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.swift_sneak_boots_trim.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.respawn_anchor_shard.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.lodestone_tracker.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.composter_catalyst.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.pyrometallurgy_nozzle.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.tripwire_tension_gauge.maxStackSize());
    try std.testing.expectEqualStrings("Target Block Core", ItemType.target_block_core.name());
    try std.testing.expectEqualStrings("Tripwire Tension Gauge", ItemType.tripwire_tension_gauge.name());
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType, count: u8 }{
        .{ .a = .target_block, .b = .redstone_block, .out = .target_block_core, .count = 1 },
        .{ .a = .lightning_rod, .b = .copper_ingot, .out = .lightning_deflector, .count = 1 },
        .{ .a = .packed_ice, .b = .snowball, .out = .frosted_ice_shard, .count = 1 },
        .{ .a = .soul_sand, .b = .gold_nugget, .out = .soul_speed_talisman, .count = 1 },
        .{ .a = .composter, .b = .bone_meal, .out = .composter_catalyst, .count = 1 },
        .{ .a = .tripwire_hook, .b = .string, .out = .tripwire_tension_gauge, .count = 1 },
    };
    for (recipes) |recipe| {
        inv.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe.out, inv.craft_output.item);
        try std.testing.expectEqual(recipe.count, inv.craft_output.count);
    }
}

test "Wave 17 item metadata and 2x2 recipes preserve BlockId capacity" {
    try std.testing.expectEqual(@as(u16, 553), @intFromEnum(ItemType.sculk_bloom_catalyst));
    try std.testing.expectEqual(@as(u16, 554), @intFromEnum(ItemType.shrieker_alarm_core));
    try std.testing.expectEqual(@as(u16, 555), @intFromEnum(ItemType.calibrated_sensor_tuner));
    try std.testing.expectEqual(@as(u16, 556), @intFromEnum(ItemType.chiseled_bookshelf_slot));
    try std.testing.expectEqual(@as(u16, 557), @intFromEnum(ItemType.hanging_chain_mount));
    try std.testing.expectEqual(@as(u16, 558), @intFromEnum(ItemType.camel_bridle_saddle));
    try std.testing.expectEqual(@as(u16, 559), @intFromEnum(ItemType.decorated_pot_motif));
    try std.testing.expectEqual(@as(u16, 560), @intFromEnum(ItemType.creaking_heart_core));
    try std.testing.expectEqual(@as(u16, 561), @intFromEnum(ItemType.eyeblossom_resin_bloom));
    try std.testing.expectEqual(@as(u16, 562), @intFromEnum(ItemType.resin_brick_masonry));
    try std.testing.expectEqual(@as(u8, 64), ItemType.sculk_bloom_catalyst.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.shrieker_alarm_core.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.calibrated_sensor_tuner.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.chiseled_bookshelf_slot.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.hanging_chain_mount.maxStackSize());
    try std.testing.expectEqual(@as(u8, 1), ItemType.camel_bridle_saddle.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.decorated_pot_motif.maxStackSize());
    try std.testing.expectEqual(@as(u8, 16), ItemType.creaking_heart_core.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.eyeblossom_resin_bloom.maxStackSize());
    try std.testing.expectEqual(@as(u8, 64), ItemType.resin_brick_masonry.maxStackSize());
    try std.testing.expectEqualStrings("Sculk Bloom Catalyst", ItemType.sculk_bloom_catalyst.name());
    try std.testing.expectEqualStrings("Shrieker Alarm Core", ItemType.shrieker_alarm_core.name());
    try std.testing.expectEqualStrings("Calibrated Sensor Tuner", ItemType.calibrated_sensor_tuner.name());
    try std.testing.expectEqualStrings("Chiseled Bookshelf Slot", ItemType.chiseled_bookshelf_slot.name());
    try std.testing.expectEqualStrings("Hanging Chain Mount", ItemType.hanging_chain_mount.name());
    try std.testing.expectEqualStrings("Camel Bridle Saddle", ItemType.camel_bridle_saddle.name());
    try std.testing.expectEqualStrings("Decorated Pot Motif", ItemType.decorated_pot_motif.name());
    try std.testing.expectEqualStrings("Creaking Heart Core", ItemType.creaking_heart_core.name());
    try std.testing.expectEqualStrings("Eyeblossom Resin Bloom", ItemType.eyeblossom_resin_bloom.name());
    try std.testing.expectEqualStrings("Resin Brick Masonry", ItemType.resin_brick_masonry.name());
    for ([_]ItemType{ .sculk_bloom_catalyst, .shrieker_alarm_core, .calibrated_sensor_tuner, .chiseled_bookshelf_slot, .hanging_chain_mount, .camel_bridle_saddle, .decorated_pot_motif, .creaking_heart_core, .eyeblossom_resin_bloom, .resin_brick_masonry }) |item| {
        const color = item.getColor();
        try std.testing.expect(color[0] >= 0.0 and color[0] <= 1.0);
        try std.testing.expect(color[1] >= 0.0 and color[1] <= 1.0);
        try std.testing.expect(color[2] >= 0.0 and color[2] <= 1.0);
        try std.testing.expect(color[3] > 0.0 and color[3] <= 1.0);
    }
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    try std.testing.expect(@intFromEnum(BlockId.leaf_litter) <= 255);

    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, ingredient_count: u8 = 1, out: ItemType, count: u8 }{
        .{ .a = .sculk, .b = .bone_meal, .out = .sculk_bloom_catalyst, .count = 1 },
        .{ .a = .sculk_sensor, .b = .amethyst_shard, .out = .calibrated_sensor_tuner, .count = 1 },
        .{ .a = .chain, .b = .wooden_slab, .out = .hanging_chain_mount, .count = 2 },
        .{ .a = .saddle, .b = .cactus, .out = .camel_bridle_saddle, .count = 1 },
        .{ .a = .clay, .b = .brick, .out = .decorated_pot_motif, .count = 1 },
        .{ .a = .resin_brick, .b = .stone_bricks, .out = .resin_brick_masonry, .count = 1 },
    };
    for (recipes) |recipe| {
        inv.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = recipe.ingredient_count }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe.out, inv.craft_output.item);
        try std.testing.expectEqual(recipe.count, inv.craft_output.count);
    }
}

test "Wave 18 item metadata and 2x2 recipes preserve BlockId capacity" {
    const metadata = [_]struct { item: ItemType, id: u16, stack: u8, display: []const u8 }{
        .{ .item = .sniffer_egg_ancient, .id = 565, .stack = 16, .display = "Ancient Sniffer Egg" },
        .{ .item = .trial_key_master, .id = 566, .stack = 16, .display = "Master Trial Key" },
        .{ .item = .ominous_trial_key_master, .id = 567, .stack = 16, .display = "Ominous Master Trial Key" },
        .{ .item = .breeze_wind_charge_core, .id = 568, .stack = 64, .display = "Breeze Wind Charge Core" },
        .{ .item = .mace_density_core, .id = 569, .stack = 1, .display = "Mace Density Core" },
        .{ .item = .crafter_pulse_core, .id = 570, .stack = 64, .display = "Crafter Pulse Core" },
        .{ .item = .copper_bulb_core, .id = 571, .stack = 64, .display = "Copper Bulb Core" },
        .{ .item = .trial_chamber_map, .id = 572, .stack = 1, .display = "Trial Chamber Map" },
        .{ .item = .ominous_bottle_catalyst, .id = 573, .stack = 16, .display = "Ominous Bottle Catalyst" },
        .{ .item = .bogged_poison_quiver, .id = 574, .stack = 16, .display = "Bogged Poison Quiver" },
    };
    for (metadata) |entry| {
        try std.testing.expectEqual(entry.id, @intFromEnum(entry.item));
        try std.testing.expectEqual(entry.stack, entry.item.maxStackSize());
        try std.testing.expectEqualStrings(entry.display, entry.item.name());
        const rgba = entry.item.getColor();
        for (rgba) |channel| try std.testing.expect(channel >= 0.0 and channel <= 1.0);
        try std.testing.expect(rgba[3] > 0.0);
    }
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    try std.testing.expect(@intFromEnum(BlockId.leaf_litter) <= 255);

    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType }{
        .{ .a = .torchflower_seeds, .b = .pitcher_pod, .out = .sniffer_egg_ancient },
        .{ .a = .trial_key, .b = .copper_ingot, .out = .trial_key_master },
        .{ .a = .breeze_rod, .b = .wind_charge, .out = .breeze_wind_charge_core },
        .{ .a = .heavy_core, .b = .mace, .out = .mace_density_core },
        .{ .a = .crafter, .b = .redstone_block, .out = .crafter_pulse_core },
        .{ .a = .copper_bulb, .b = .redstone_torch, .out = .copper_bulb_core },
    };
    for (recipes) |recipe| {
        inv.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe.out, inv.craft_output.item);
        try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);
    }
}

test "Wave 19 item metadata and 2x2 recipes preserve BlockId capacity" {
    const metadata = [_]struct { item: ItemType, id: u16, stack: u8, display: []const u8 }{
        .{ .item = .armadillo_scute_core, .id = 575, .stack = 64, .display = "Armadillo Scute Core" },
        .{ .item = .allay_amethyst_resonator, .id = 576, .stack = 16, .display = "Allay Amethyst Resonator" },
        .{ .item = .froglight_catalyst, .id = 577, .stack = 64, .display = "Froglight Catalyst" },
        .{ .item = .screamer_goat_horn, .id = 578, .stack = 1, .display = "Screamer Goat Horn" },
        .{ .item = .sculk_multiplexer_node, .id = 579, .stack = 64, .display = "Sculk Multiplexer Node" },
        .{ .item = .reinforced_deepslate_core, .id = 580, .stack = 64, .display = "Reinforced Deepslate Core" },
        .{ .item = .mud_brick_masonry, .id = 581, .stack = 64, .display = "Mud Brick Masonry" },
        .{ .item = .warden_sonic_core, .id = 582, .stack = 16, .display = "Warden Sonic Core" },
        .{ .item = .recovery_compass_talisman, .id = 583, .stack = 1, .display = "Recovery Compass Talisman" },
        .{ .item = .archaeology_brush_relic, .id = 584, .stack = 1, .display = "Archaeology Brush Relic" },
    };
    for (metadata) |entry| {
        try std.testing.expectEqual(entry.id, @intFromEnum(entry.item));
        try std.testing.expectEqual(entry.stack, entry.item.maxStackSize());
        try std.testing.expectEqualStrings(entry.display, entry.item.name());
        const rgba = entry.item.getColor();
        for (rgba) |channel| try std.testing.expect(channel >= 0.0 and channel <= 1.0);
        try std.testing.expect(rgba[3] > 0.0);
    }
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    try std.testing.expect(@intFromEnum(BlockId.leaf_litter) <= 255);

    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType }{
        .{ .a = .armadillo_scute, .b = .leather, .out = .armadillo_scute_core },
        .{ .a = .amethyst_shard, .b = .note_block, .out = .allay_amethyst_resonator },
        .{ .a = .ochre_froglight, .b = .glowstone_dust, .out = .froglight_catalyst },
        .{ .a = .goat_horn, .b = .echo_shard, .out = .screamer_goat_horn },
        .{ .a = .mud_bricks, .b = .packed_mud, .out = .mud_brick_masonry },
        .{ .a = .echo_shard, .b = .compass, .out = .recovery_compass_talisman },
    };
    for (recipes) |recipe| {
        inv.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe.out, inv.craft_output.item);
        try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);
    }
}

test "Wave 20 item metadata and 2x2 recipes preserve BlockId capacity" {
    const metadata = [_]struct { item: ItemType, id: u16, stack: u8, display: []const u8 }{
        .{ .item = .ominous_trap_core, .id = 586, .stack = 64, .display = "Ominous Trap Core" },
        .{ .item = .dyed_bundle_package, .id = 587, .stack = 1, .display = "Dyed Bundle Package" },
        .{ .item = .netherite_smithing_core, .id = 588, .stack = 16, .display = "Netherite Smithing Core" },
        .{ .item = .shulker_levitation_orb, .id = 589, .stack = 16, .display = "Shulker Levitation Orb" },
        .{ .item = .elytra_propulsion_core, .id = 590, .stack = 1, .display = "Elytra Propulsion Core" },
        .{ .item = .riptide_vortex_shard, .id = 591, .stack = 16, .display = "Riptide Vortex Shard" },
        .{ .item = .four_horsemen_crest, .id = 592, .stack = 1, .display = "Four Horsemen Crest" },
        .{ .item = .witch_brewing_cauldron, .id = 593, .stack = 1, .display = "Witch Brewing Cauldron" },
        .{ .item = .evoker_fangs_talisman, .id = 594, .stack = 16, .display = "Evoker Fangs Talisman" },
        .{ .item = .totem_resurrection_effigy, .id = 595, .stack = 1, .display = "Totem Resurrection Effigy" },
    };
    for (metadata) |entry| {
        try std.testing.expectEqual(entry.id, @intFromEnum(entry.item));
        try std.testing.expectEqual(entry.stack, entry.item.maxStackSize());
        try std.testing.expectEqualStrings(entry.display, entry.item.name());
        const rgba = entry.item.getColor();
        for (rgba) |channel| try std.testing.expect(channel >= 0.0 and channel <= 1.0);
        try std.testing.expect(rgba[3] > 0.0);
    }
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    try std.testing.expect(@intFromEnum(BlockId.leaf_litter) <= 255);

    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType }{
        .{ .a = .trial_chamber_map, .b = .wind_charge, .out = .ominous_trap_core },
        .{ .a = .string, .b = .leather, .out = .dyed_bundle_package },
        .{ .a = .netherite_upgrade_template, .b = .diamond, .out = .netherite_smithing_core },
        .{ .a = .end_rod, .b = .shulker_shell, .out = .shulker_levitation_orb },
        .{ .a = .firework_star, .b = .phantom_membrane, .out = .elytra_propulsion_core },
        .{ .a = .totem_of_undying, .b = .emerald, .out = .totem_resurrection_effigy },
    };
    for (recipes) |recipe| {
        inv.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe.out, inv.craft_output.item);
        try std.testing.expectEqual(@as(u8, 1), inv.craft_output.count);
    }
}

test "Copper Horn item metadata and exact 2x2 crafting recipe" {
    try std.testing.expectEqual(@as(u16, 607), @intFromEnum(ItemType.copper_horn));
    try std.testing.expectEqual(@as(u8, 1), ItemType.copper_horn.maxStackSize());
    try std.testing.expectEqualStrings("Copper Horn", ItemType.copper_horn.name());

    var inventory = Inventory.init();
    inventory.craft_grid = .{
        .{ .item = .goat_horn, .count = 1 },
        .{ .item = .copper_ingot, .count = 1 },
        .{ .item = .copper_ingot, .count = 1 },
        .{ .item = .copper_ingot, .count = 1 },
    };
    inventory.updateCrafting();
    try std.testing.expectEqual(ItemType.copper_horn, inventory.craft_output.item);
    try std.testing.expectEqual(@as(u8, 1), inventory.craft_output.count);

    var cursor = ItemStack{};
    try std.testing.expect(inventory.takeCraftResult(&cursor));
    try std.testing.expectEqual(ItemType.copper_horn, cursor.item);
    for (inventory.craft_grid) |slot| try std.testing.expect(slot.isEmpty());
}

test "Wave 21 item metadata and 2x2 recipes preserve BlockId capacity" {
    const metadata = [_]struct { item: ItemType, id: u16, stack: u8, display: []const u8 }{
        .{ .item = .piglin_barter_token, .id = 596, .stack = 64, .display = "Piglin Barter Token" },
        .{ .item = .piglin_brute_armband, .id = 597, .stack = 1, .display = "Piglin Brute Armband" },
        .{ .item = .zombified_swarm_beacon, .id = 598, .stack = 16, .display = "Zombified Swarm Beacon" },
        .{ .item = .strider_lava_harness, .id = 599, .stack = 1, .display = "Strider Lava Harness" },
        .{ .item = .nether_fungus_spores, .id = 600, .stack = 64, .display = "Nether Fungus Spores" },
        .{ .item = .hoglin_tusk_trophy, .id = 601, .stack = 16, .display = "Hoglin Tusk Trophy" },
        .{ .item = .reinforced_elastic_lead, .id = 602, .stack = 16, .display = "Reinforced Elastic Lead" },
        .{ .item = .sweet_berry_basket, .id = 603, .stack = 16, .display = "Sweet Berry Basket" },
        .{ .item = .turtle_scute_core, .id = 604, .stack = 64, .display = "Turtle Scute Core" },
        .{ .item = .panda_gene_scroll, .id = 605, .stack = 1, .display = "Panda Gene Scroll" },
    };
    for (metadata) |entry| {
        try std.testing.expectEqual(entry.id, @intFromEnum(entry.item));
        try std.testing.expectEqual(entry.stack, entry.item.maxStackSize());
        try std.testing.expectEqualStrings(entry.display, entry.item.name());
        const rgba = entry.item.getColor();
        for (rgba) |channel| try std.testing.expect(channel >= 0.0 and channel <= 1.0);
        try std.testing.expect(rgba[3] > 0.0);
    }
    try std.testing.expect(@intFromEnum(BlockId.leaf_litter) <= 255);

    var inv = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType, count: u8 }{
        .{ .a = .gold_ingot, .b = .leather, .out = .piglin_barter_token, .count = 1 },
        .{ .a = .gold_ingot, .b = .gold_block, .out = .piglin_brute_armband, .count = 1 },
        .{ .a = .warped_fungus, .b = .string, .out = .strider_lava_harness, .count = 1 },
        .{ .a = .crimson_fungus, .b = .warped_fungus, .out = .nether_fungus_spores, .count = 2 },
        .{ .a = .lead, .b = .slimeball, .out = .reinforced_elastic_lead, .count = 1 },
        .{ .a = .sweet_berries, .b = .wheat, .out = .sweet_berry_basket, .count = 1 },
    };
    for (recipes) |recipe| {
        inv.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inv.updateCrafting();
        try std.testing.expectEqual(recipe.out, inv.craft_output.item);
        try std.testing.expectEqual(recipe.count, inv.craft_output.count);
    }
}

test "vault reset token has stack metadata and display color" {
    try std.testing.expectEqual(@as(u16, 613), @intFromEnum(ItemType.vault_reset_token));
    try std.testing.expectEqual(@as(u8, 16), ItemType.vault_reset_token.maxStackSize());
    try std.testing.expectEqualStrings("Vault Reset Token", ItemType.vault_reset_token.name());
    const rgba = ItemType.vault_reset_token.getColor();
    for (rgba) |channel| try std.testing.expect(channel >= 0.0 and channel <= 1.0);
    try std.testing.expect(rgba[3] > 0.0);
}

test "Wave 22 item metadata and 2x2 recipes preserve BlockId capacity" {
    const metadata = [_]struct { item: ItemType, id: u16, stack: u8, display: []const u8 }{
        .{ .item = .copper_horn_instrument, .id = 608, .stack = 1, .display = "Copper Horn Instrument" },
        .{ .item = .sculk_bloom_core, .id = 609, .stack = 64, .display = "Sculk Bloom Core" },
        .{ .item = .camel_dash_saddle, .id = 610, .stack = 1, .display = "Camel Dash Saddle" },
        .{ .item = .secret_bookshelf_mechanism, .id = 611, .stack = 16, .display = "Secret Bookshelf Mechanism" },
        .{ .item = .brush_plume_fiber, .id = 612, .stack = 64, .display = "Brush Plume Fiber" },
        .{ .item = .vault_reset_token, .id = 613, .stack = 16, .display = "Vault Reset Token" },
        .{ .item = .mace_combo_catalyst, .id = 614, .stack = 1, .display = "Mace Combo Catalyst" },
        .{ .item = .factory_clock_regulator, .id = 615, .stack = 16, .display = "Factory Clock Regulator" },
        .{ .item = .copper_bulb_display_module, .id = 616, .stack = 16, .display = "Copper Bulb Display Module" },
        .{ .item = .dragon_fountain_essence, .id = 617, .stack = 1, .display = "Dragon Fountain Essence" },
    };
    for (metadata) |entry| {
        try std.testing.expectEqual(entry.id, @intFromEnum(entry.item));
        try std.testing.expectEqual(entry.stack, entry.item.maxStackSize());
        try std.testing.expectEqualStrings(entry.display, entry.item.name());
        const rgba = entry.item.getColor();
        for (rgba) |channel| try std.testing.expect(channel >= 0.0 and channel <= 1.0);
        try std.testing.expect(rgba[3] > 0.0);
    }
    try std.testing.expect(@intFromEnum(BlockId.leaf_litter) <= 255);

    var inventory = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType }{
        .{ .a = .copper_horn, .b = .copper_ingot, .out = .copper_horn_instrument },
        .{ .a = .sculk, .b = .sculk_sensor, .out = .sculk_bloom_core },
        .{ .a = .saddle, .b = .lead, .out = .camel_dash_saddle },
        .{ .a = .mace, .b = .wind_charge, .out = .mace_combo_catalyst },
        .{ .a = .copper_bulb, .b = .redstone_dust, .out = .copper_bulb_display_module },
        .{ .a = .dragon_egg, .b = .end_crystal, .out = .dragon_fountain_essence },
    };
    for (recipes) |recipe| {
        inventory.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inventory.updateCrafting();
        try std.testing.expectEqual(recipe.out, inventory.craft_output.item);
        try std.testing.expectEqual(@as(u8, 1), inventory.craft_output.count);
    }
}

test "Wave 23 item metadata and 2x2 recipes preserve BlockId capacity" {
    const metadata = [_]struct { item: ItemType, id: u16, stack: u8, display: []const u8 }{
        .{ .item = .blaze_artillery_core, .id = 618, .stack = 64, .display = "Blaze Artillery Core" },
        .{ .item = .magma_cream_catalyst, .id = 619, .stack = 64, .display = "Magma Cream Catalyst" },
        .{ .item = .ghast_tear_essence, .id = 620, .stack = 16, .display = "Ghast Tear Essence" },
        .{ .item = .wither_skull_relic, .id = 621, .stack = 16, .display = "Wither Skull Relic" },
        .{ .item = .nether_star_core, .id = 622, .stack = 1, .display = "Nether Star Core" },
        .{ .item = .beacon_pyramid_talisman, .id = 623, .stack = 1, .display = "Beacon Pyramid Talisman" },
        .{ .item = .conduit_power_orb, .id = 624, .stack = 16, .display = "Conduit Power Orb" },
        .{ .item = .guardian_laser_emitter, .id = 625, .stack = 16, .display = "Guardian Laser Emitter" },
        .{ .item = .elder_curse_sponge, .id = 626, .stack = 1, .display = "Elder Curse Sponge" },
        .{ .item = .nether_portal_compass, .id = 627, .stack = 1, .display = "Nether Portal Compass" },
    };
    for (metadata) |entry| {
        try std.testing.expectEqual(entry.id, @intFromEnum(entry.item));
        try std.testing.expectEqual(entry.stack, entry.item.maxStackSize());
        try std.testing.expectEqualStrings(entry.display, entry.item.name());
        const rgba = entry.item.getColor();
        for (rgba) |channel| try std.testing.expect(channel >= 0.0 and channel <= 1.0);
        try std.testing.expect(rgba[3] > 0.0);
    }
    try std.testing.expect(@intFromEnum(BlockId.leaf_litter) <= 255);

    var inventory = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType }{
        .{ .a = .blaze_rod, .b = .fire_charge, .out = .blaze_artillery_core },
        .{ .a = .magma_cream, .b = .slimeball, .out = .magma_cream_catalyst },
        .{ .a = .ghast_tear, .b = .nether_wart, .out = .ghast_tear_essence },
        .{ .a = .wither_skull, .b = .coal, .out = .wither_skull_relic },
        .{ .a = .nether_star, .b = .obsidian, .out = .nether_star_core },
        .{ .a = .prismarine_shard, .b = .prismarine_crystals, .out = .conduit_power_orb },
    };
    for (recipes) |recipe| {
        inventory.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inventory.updateCrafting();
        try std.testing.expectEqual(recipe.out, inventory.craft_output.item);
        try std.testing.expectEqual(@as(u8, 1), inventory.craft_output.count);
    }
}

test "Wave 24 item metadata and 2x2 recipes preserve BlockId capacity" {
    const metadata = [_]struct { item: ItemType, id: u16, stack: u8, display: []const u8 }{
        .{ .item = .chorus_teleport_matrix, .id = 628, .stack = 64, .display = "Chorus Teleport Matrix" },
        .{ .item = .end_gateway_shard, .id = 629, .stack = 16, .display = "End Gateway Shard" },
        .{ .item = .shulker_shell_armor_plate, .id = 630, .stack = 64, .display = "Shulker Shell Armor Plate" },
        .{ .item = .quantum_shulker_core, .id = 631, .stack = 1, .display = "Quantum Shulker Core" },
        .{ .item = .elytra_mending_wing, .id = 632, .stack = 1, .display = "Elytra Mending Wing" },
        .{ .item = .dragon_skull_horn, .id = 633, .stack = 1, .display = "Dragon Skull Horn" },
        .{ .item = .dragons_breath_vial, .id = 634, .stack = 16, .display = "Dragon's Breath Vial" },
        .{ .item = .end_city_vault_key, .id = 635, .stack = 16, .display = "End City Vault Key" },
        .{ .item = .end_ship_figurehead, .id = 636, .stack = 1, .display = "End Ship Figurehead" },
        .{ .item = .dragon_respawn_crystal, .id = 637, .stack = 1, .display = "Dragon Respawn Crystal" },
    };
    for (metadata) |entry| {
        try std.testing.expectEqual(entry.id, @intFromEnum(entry.item));
        try std.testing.expectEqual(entry.stack, entry.item.maxStackSize());
        try std.testing.expectEqualStrings(entry.display, entry.item.name());
        const rgba = entry.item.getColor();
        for (rgba) |channel| try std.testing.expect(channel >= 0.0 and channel <= 1.0);
        try std.testing.expect(rgba[3] > 0.0);
    }
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    try std.testing.expect(@intFromEnum(BlockId.leaf_litter) <= 255);

    var inventory = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType }{
        .{ .a = .chorus_fruit, .b = .ender_pearl, .out = .chorus_teleport_matrix },
        .{ .a = .shulker_shell, .b = .iron_ingot, .out = .shulker_shell_armor_plate },
        .{ .a = .shulker_box, .b = .diamond, .out = .quantum_shulker_core },
        .{ .a = .elytra, .b = .phantom_membrane, .out = .elytra_mending_wing },
        .{ .a = .dragon_head, .b = .copper_horn, .out = .dragon_skull_horn },
        .{ .a = .dragons_breath, .b = .glass_bottle, .out = .dragons_breath_vial },
    };
    for (recipes) |recipe| {
        inventory.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inventory.updateCrafting();
        try std.testing.expectEqual(recipe.out, inventory.craft_output.item);
        try std.testing.expectEqual(@as(u8, 1), inventory.craft_output.count);
    }
}

test "Wave 25 item metadata and 2x2 recipes preserve BlockId capacity" {
    const metadata = [_]struct { item: ItemType, id: u16, stack: u8, display: []const u8 }{
        .{ .item = .warden_sonic_pulse_matrix, .id = 639, .stack = 1, .display = "Warden Sonic Pulse Matrix" },
        .{ .item = .shrieker_darkness_fog_relic, .id = 640, .stack = 16, .display = "Shrieker Darkness Fog Relic" },
        .{ .item = .calibrated_resonance_matrix, .id = 641, .stack = 16, .display = "Calibrated Resonance Matrix" },
        .{ .item = .wind_charge_rocket_booster, .id = 642, .stack = 16, .display = "Wind Charge Rocket Booster" },
        .{ .item = .ominous_wave_hazard_core, .id = 643, .stack = 16, .display = "Ominous Wave Hazard Core" },
        .{ .item = .mace_velocity_impact_relic, .id = 644, .stack = 1, .display = "Mace Velocity Impact Relic" },
        .{ .item = .vault_reset_token_matrix, .id = 645, .stack = 16, .display = "Vault Reset Token Matrix" },
        .{ .item = .crafter_pulsed_grid_controller, .id = 646, .stack = 64, .display = "Crafter Pulsed Grid Controller" },
        .{ .item = .bogged_poison_harvest_quiver, .id = 647, .stack = 16, .display = "Bogged Poison Harvest Quiver" },
        .{ .item = .ominous_omen_transmutation_matrix, .id = 648, .stack = 16, .display = "Ominous Omen Transmutation Matrix" },
    };
    for (metadata) |entry| {
        try std.testing.expectEqual(entry.id, @intFromEnum(entry.item));
        try std.testing.expectEqual(entry.stack, entry.item.maxStackSize());
        try std.testing.expectEqualStrings(entry.display, entry.item.name());
        const rgba = entry.item.getColor();
        for (rgba) |channel| try std.testing.expect(channel >= 0.0 and channel <= 1.0);
        try std.testing.expect(rgba[3] > 0.0);
    }
    try std.testing.expectEqual(@as(u8, 255), @intFromEnum(BlockId.leaf_litter));
    try std.testing.expect(@intFromEnum(BlockId.leaf_litter) <= 255);

    var inventory = Inventory.init();
    const recipes = [_]struct { a: ItemType, b: ItemType, out: ItemType }{
        .{ .a = .echo_shard, .b = .sculk_catalyst, .out = .warden_sonic_pulse_matrix },
        .{ .a = .sculk, .b = .bone, .out = .shrieker_darkness_fog_relic },
        .{ .a = .amethyst_shard, .b = .copper_ingot, .out = .calibrated_resonance_matrix },
        .{ .a = .wind_charge, .b = .gunpowder, .out = .wind_charge_rocket_booster },
        .{ .a = .mace, .b = .breeze_rod, .out = .mace_velocity_impact_relic },
        .{ .a = .crafter, .b = .iron_ingot, .out = .crafter_pulsed_grid_controller },
    };
    for (recipes) |recipe| {
        inventory.craft_grid = .{ .{ .item = recipe.a, .count = 1 }, .{ .item = recipe.b, .count = 1 }, .{}, .{} };
        inventory.updateCrafting();
        try std.testing.expectEqual(recipe.out, inventory.craft_output.item);
        try std.testing.expectEqual(@as(u8, 1), inventory.craft_output.count);
    }
}
