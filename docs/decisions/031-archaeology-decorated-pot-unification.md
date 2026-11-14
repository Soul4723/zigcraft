# Decision 031: Archaeology brush excavation and Decorated Pot unification

Accepted: 2026-11-14.

## Context
Archaeology excavation and Decorated Pot rules were each split across overlapping modules in `src/world/`:
- `src/world/archaeology.zig`: Contained `relicForRoll`, `brushes_to_excavate`, item tag constants, and legacy Copper Bulb helpers.
- `src/world/archaeology_brush_excavation.zig`: Contained `Brush` (64 durability, vertical and 3×3 crafting), `SuspiciousBlockType`, `StructureType`, 20 `PotterySherd` designs, 4 `ArmorTrim` templates, `ArchaeologyLoot`, `DustStage` (0..96 ticks), `SuspiciousBlock` (reach validation, decay on interruption, gravity/piston shattering with zero drops, direct mining to sand/gravel), and structure loot tables (`lootForWarmOceanRuins`, `lootForColdOceanRuins`, `lootForTrailRuins`, `lootForDesertPyramid`, `lootForDesertWell`). It had only a discarded dummy call `_ = archaeology_brush_excavation_mod.TOTAL_EXCAVATION_TICKS;` in `src/main.zig`.
- `src/world/brushing_visual_particles.zig`: Contained `ExcavationStage`, deterministic `ParticleBurst` / `makeBurst`, `Hands`, `AudioEvent`, and `BrushingVisualState` (interruption regression and plume alpha fade). It had only a discarded dummy call `_ = brushing_visual_particles_mod.TOTAL_EXCAVATION_TICKS;` in `src/main.zig`.
- `src/world/decorated_pot.zig`: Contained `PotFaceMotif` (18 variants), `CardinalFace`, `DiamondCraftingPattern`, `WobbleState`, `ToolKind`, `ProjectileKind`, and `DecoratedPot` (single-stack storage, wobble timers/angles, comparator signal, and harvest shattering).
- `src/world/decorated_pot_storage.zig`: Contained expanded `PotFacetMotif` (24 variants including `.flow`, `.guster`, `.heartbreak`, `.scrape`, `.sheaf`, `.shelter`), `CardinalFacet.opposite`, `ToolKind.fist` (with all tools shattering the pot), `DecoratedPot.punch` / `punchExtract`, and `ceil`-based comparator signal calculation. It had only a discarded dummy call `_ = decorated_pot_storage_mod.wobble_duration_seconds;` in `src/main.zig`.

In live gameplay in `src/main.zig`, `.suspicious_sand` completed immediately on a single F-key press without stage progression, particle bursts, decay, or falling fragility, and `.decorated_pot` lacked punch extraction, sherd facet decoration, tool vs bare-hand shatter drops, and projectile shattering.

## Decision
1. **Archaeology unification in `src/world/archaeology.zig`**:
   - Consolidated all constants, types, loot tables, `SuspiciousBlock`, `BrushingVisualState`, `makeBurst`, and all 75 existing unit tests into `src/world/archaeology.zig`.
   - Kept `toggleCopperBulb` / `copperBulbComparatorSignal` in place so existing callers in `src/main.zig` continue to work without interfering with separate Copper Bulb work.
   - Added `lootInventoryTag` to map `ArchaeologyLoot` to global `src/items.zig` item IDs and `ActiveExcavation` to drive 20 Hz continuous right-hold brushing, discrete F-key stage advancement, reach checks, interruption wear/decay, and deterministic particle bursts (78 unit tests total).
   - Deleted `src/world/archaeology_brush_excavation.zig` and `src/world/brushing_visual_particles.zig` and removed their `test_files` entries from `build.zig`.

2. **Decorated Pot unification in `src/world/decorated_pot.zig`**:
   - Consolidated all 24 `PotFacetMotif` variants (aliasing `PotFaceMotif` and `brick_blank`), `CardinalFacet` (aliasing `CardinalFace`), `ToolKind` (where all 5 tool categories shatter the pot while `.bare_hand` / `.fist` preserve it), `punch` / `punchExtract`, `applyNextSherdFacet`, `sherdMotifForSeed`, `comparatorSignal` (`1 + floor(14 * fullness)`), `comparatorSignalCeil` (`ceil(count / max * 15)`), `resolveHarvestOutcome`, and `resolveStorageHarvestOutcome` / `resolveToolBreak` into `src/world/decorated_pot.zig` (51 unit tests total).
   - Deleted `src/world/decorated_pot_storage.zig` and removed its `test_files` entry from `build.zig`.

3. **Gameplay integration in `src/main.zig`**:
   - Removed the 3 duplicate imports and 3 discarded `_ = ...` calls.
   - Connected continuous right-hold brushing and discrete F-key stage brushing on `.suspicious_sand` via `active_excavation`, emitting stage dust bursts and golden relic sparkles, playing pitched `.step_sand` and `.glowstone_chime`, wearing brush durability, converting excavated blocks to `.sand`, and shattering falling `.suspicious_sand` on impact with zero drops.
   - Connected `.decorated_pot` tool vs bare-hand harvest drops (`resolveToolBreak`), projectile shattering (`resolveProjectileHit`), empty-hand right-click and Shift+F `punch()` extraction with wobble feedback, and Shift+F sherd facet decoration (`applyNextSherdFacet`), while removing the redundant per-frame `active_decorated_pot.tick()` so `updateAnimation(dt)` drives smooth 0.5s wobble decay.
