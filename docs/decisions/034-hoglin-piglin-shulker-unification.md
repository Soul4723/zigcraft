# Decision 034: Hoglin/Zoglin, Piglin/Bastion, and Shulker/End City unification

Accepted: 2026-11-14.

## Context
Three Nether and End mob/container mechanics were still split across ten overlapping modules in `src/world/`:
1. **Hoglin / Zoglin**: `src/world/hoglin_zoglin.zig` (16 tests) and `src/world/hoglin_warped_repellent.zig` (42 tests).
2. **Piglin / Bastion / Zombified Piglin**: `src/world/piglin_bastion.zig` (16 tests), `src/world/piglin_bartering_economy.zig` (45 tests), `src/world/piglin_brute_bastion.zig` (37 tests), and `src/world/zombified_piglin_swarm.zig` (44 tests).
3. **Shulker / End City**: `src/world/shulker_end_city.zig` (21 tests), `src/world/shulker_box_storage.zig` (31 tests), `src/world/shulker_bullet_levitation.zig` (42 tests), and `src/world/shulker_shell_defense.zig` (39 tests).

In `src/main.zig`, all seven duplicate modules were imported alongside the three canonical modules solely for dummy state initialization and discarded `_ = ...` calls, while live gameplay lacked Hoglin 7-block repulsion and Crimson Fungus breeding, 6-second Gold Ingot bartering inspection, Piglin Brute alarm coordination, Zombified Piglin swarm alerts, Shulker closed-shell projectile deflection and melee armor reduction, cardinal-axis homing Shulker bullets, Shulker Box anti-nesting, and cauldron washing of dyed Shulker Boxes.

## Decision
1. **Unify Hoglin/Zoglin rules in `src/world/hoglin_zoglin.zig`**:
   - Merged all public declarations and all 42 unit tests from `hoglin_warped_repellent.zig` into `hoglin_zoglin.zig` (58 tests total) and removed `src/world/hoglin_warped_repellent.zig`.
2. **Unify Piglin, Piglin Brute, and Zombified Piglin rules in `src/world/piglin_bastion.zig`**:
   - Merged all declarations and unit tests from `piglin_bartering_economy.zig`, `piglin_brute_bastion.zig`, and `zombified_piglin_swarm.zig` into `piglin_bastion.zig` (142 tests total), unifying `Vec3`, `ItemType`, and `SoundEffect` while disambiguating `BruteZombifiedPiglin`, `BRUTE_EXPERIENCE_POINTS_DROP`, and `calculateBruteDefeatDrops`, and removed the three duplicate files.
3. **Unify Shulker and End City rules in `src/world/shulker_end_city.zig`**:
   - Merged all declarations and unit tests from `shulker_box_storage.zig`, `shulker_bullet_levitation.zig`, and `shulker_shell_defense.zig` into `shulker_end_city.zig` (133 tests total), disambiguating `PortableShulkerBoxItem`, `GuidedShulkerBullet`, and `ShulkerShell`, and removed the three duplicate files.
4. **Connect all three unified mechanics to live gameplay in `src/items.zig`, `src/player.zig`, `src/entity/`, and `src/main.zig`**:
   - Added `.hoglin`, `.zoglin`, and `.zombified_piglin` to `MobType`, `Mob`, `MobRenderer`, and `MobManager`, plus `shulker_peek_state` on `.shulker` driving both shell rendering and combat vulnerability.
   - Connected Hoglin 7-block repulsion (`.warped_fungus`, `.nether_portal`, `.respawn_anchor`), Overworld/End 15s zombification, Crimson Fungus breeding/pacification, and adult tusk upward launch.
   - Connected Piglin 6-second Gold Ingot bartering inspection and loot dispensing, golden armor pacification vs Piglin Brute immunity and 16m Bastion alarm broadcast, guarded chest/shulker-box/gold-block provocation, and Zombified Piglin 40m swarm alert propagation.
   - Connected Shulker closed/peeking 20-armor projectile deflection and 80% melee reduction vs open-shell vulnerability, 25% damage teleportation, melee bullet swatting, cardinal-axis homing Shulker bullets inflicting Levitation I (10s at `0.9 m/s` cured by Milk Bucket), Shulker Box anti-nesting, and dyed Shulker Box water cauldron washing.
   - Removed the 7 duplicate imports, 7 `build.zig` test entries, and all discarded `_ = ...` calls for these modules in `src/main.zig`.
