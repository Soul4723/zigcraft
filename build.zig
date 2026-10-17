const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe_mod.linkSystemLibrary("glfw3", .{});
    exe_mod.linkSystemLibrary("gl", .{});
    exe_mod.linkSystemLibrary("asound", .{});

    const exe = b.addExecutable(.{
        .name = "zigcraft",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run zigcraft");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run all tests");

    const exe_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    test_step.dependOn(&run_exe_tests.step);

    // Modules that can be tested in isolation (root at src/ or self-contained)
    const test_files = [_][]const u8{
        "src/world/block.zig",
        "src/world/portal.zig",
        "src/world/summon.zig",
        "src/world/hazard.zig",
        "src/world/falling_blocks.zig",
        "src/world/fluid_wash.zig",
        "src/world/component_cache.zig",
        "src/world/spawn_rules.zig",
        "src/world/compass.zig",
        "src/world/sapling.zig",
        "src/world/explosives.zig",
        "src/world/smelting.zig",
        "src/world/projectile.zig",
        "src/world/combat.zig",
        "src/world/farming.zig",
        "src/world/trading.zig",
        "src/world/apiary.zig",
        "src/world/copper.zig",
        "src/world/amethyst.zig",
        "src/world/campfire_cook.zig",
        "src/world/sculk.zig",
        "src/world/golem.zig",
        "src/world/cake.zig",
        "src/world/dripstone.zig",
        "src/world/lush_caves.zig",
        "src/world/totem.zig",
        "src/world/ice_physics.zig",
        "src/world/scaffolding.zig",
        "src/world/alchemy_buffs.zig",
        "src/world/ender_chest.zig",
        "src/world/beacon_aura.zig",
        "src/world/archaeology.zig",
        "src/world/wind_charge.zig",
        "src/world/mace_combat.zig",
        "src/world/autocrafter.zig",
        "src/world/calibrated_sculk.zig",
        "src/world/frog.zig",
        "src/world/goat_horn.zig",
        "src/world/cherry_grove.zig",
        "src/world/chiseled_bookshelf.zig",
        "src/world/hanging_sign.zig",
        "src/world/camel.zig",
        "src/world/decorated_pot.zig",
        "src/world/pale_garden.zig",
        "src/world/armadillo_wolf_armor.zig",
        "src/world/ominous_trial.zig",
        "src/world/trial_alchemy.zig",
        "src/world/bundle_pouch.zig",
        "src/world/copper_fixtures.zig",
        "src/world/jukebox_discs.zig",
        "src/world/happy_ghast.zig",
        "src/world/warden_deep_dark.zig",
        "src/world/strider_mount.zig",
        "src/world/axolotl.zig",
        "src/world/banner_heraldry.zig",
        "src/world/anvil_smithing.zig",
        "src/world/copper_golem.zig",
        "src/world/ambient_foliage.zig",
        "src/world/ender_stasis.zig",
        "src/world/minecart_logistics.zig",
        "src/world/enchanting_grindstone.zig",
        "src/world/village_raid.zig",
        "src/world/redstone_workstations.zig",
        "src/world/shulker_end_city.zig",
        "src/world/elytra_aerodynamics.zig",
        "src/world/sea_turtle.zig",
        "src/world/taiga_fox.zig",
        "src/world/conduit_frame.zig",
        "src/world/enderman_ai.zig",
        "src/world/piglin_bastion.zig",
        "src/world/charged_creeper.zig",
        "src/world/swamp_witch.zig",
        "src/world/blaze_fortress.zig",
        "src/world/ghast_deflection.zig",
        "src/world/slime_mitosis.zig",
        "src/world/phantom_insomnia.zig",
        "src/world/wither_boss.zig",
        "src/world/ender_dragon_fight.zig",
        "src/world/villager_curing.zig",
        "src/world/piston_adhesion.zig",
        "src/world/fishing_treasure.zig",
        "src/world/shield_thorns_combat.zig",
        "src/world/trident_enchantments.zig",
        "src/world/dimensional_anchors.zig",
        "src/world/precision_redstone_sensors.zig",
        "src/world/snow_golem_ai.zig",
        "src/world/allay_collector.zig",
        "src/world/note_block_instruments.zig",
        "src/world/equine_genetics.zig",
        "src/world/companion_pets.zig",
        "src/world/panda_genetics.zig",
        "src/world/dolphin_navigation.zig",
        "src/world/bee_pollination.zig",
        "src/world/cartography_maps.zig",
        "src/world/processing_workstations.zig",
        "src/world/boots_and_armor_stands.zig",
        "src/world/woodland_mansion.zig",
        "src/world/ocean_monument.zig",
        "src/world/ancient_city.zig",
        "src/world/temple_traps.zig",
        "src/world/stronghold_triangulation.zig",
        "src/world/mushroom_island.zig",
        "src/world/weather_lightning.zig",
        "src/world/hunger_metabolism.zig",
        "src/world/experience_orbs.zig",
        "src/world/melee_sweep_crit.zig",
        "src/world/skeleton_variants.zig",
        "src/world/zombie_conversions.zig",
        "src/world/spider_arachnids.zig",
        "src/world/mountain_goat.zig",
        "src/world/hoglin_zoglin.zig",
        "src/world/ranged_enchantments.zig",
        "src/world/item_frames_paintings.zig",
        "src/world/armor_toughness_epf.zig",
        "src/world/hopper_item_sorter.zig",
        "src/world/beacon_pyramid.zig",
        "src/world/badlands_mesa.zig",
        "src/world/concrete_masonry.zig",
        "src/world/igloo_snowy_plains.zig",
        "src/world/jungle_canopy.zig",
        "src/world/savanna_acacia.zig",
        "src/world/dark_forest_canopy.zig",
        "src/world/shipwreck_treasure.zig",
        "src/world/nether_biomes.zig",
        "src/world/firework_pyrotechnics.zig",
        "src/world/cauldron_fluids.zig",
        "src/world/interact.zig",
        "src/world/hotbar.zig",
        "src/world/mining.zig",
        "src/world/tool_wear.zig",
        "src/world/redstone.zig",
        "src/world/chunk.zig",
        "src/world/chunk_mesh.zig",
        "src/world/terrain.zig",
        "src/world/persistence_test.zig",
        "src/chunk_manager.zig",
        "src/frustum.zig",
        "src/pick.zig",
        "src/renderer/shader.zig",
        "src/renderer/texture.zig",
        "src/renderer/ui.zig",
        "src/renderer/highlight.zig",
        "src/renderer/toast.zig",
        "src/renderer/particles.zig",
        "src/renderer/mesh.zig",
        "src/camera.zig",
        "src/player.zig",
        "src/sky.zig",
        "src/math.zig",
        "src/audio/synth.zig",
        "src/audio/audio.zig",
        "src/entity/pathfind.zig",
        "src/entity.zig",
        "src/inventory.zig",
    };

    for (test_files) |test_file| {
        const test_mod = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .link_libc = true,
        });
        test_mod.linkSystemLibrary("gl", .{});
        test_mod.linkSystemLibrary("glfw3", .{});
        test_mod.linkSystemLibrary("asound", .{});
        const test_exe = b.addTest(.{
            .root_module = test_mod,
        });
        const run_test = b.addRunArtifact(test_exe);
        test_step.dependOn(&run_test.step);
    }
}
