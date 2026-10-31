# Decision 008: Paused Inactive Dimension Time and Per-Dimension Block Job Persistence

## Status
Accepted (2026-10-31)

## Context
Furnaces, smokers, blast furnaces, and growing saplings lacked persistence across game restart and portal dimension switches. When a chunk unloaded around the player, `getBlockWorld` returned air, which caused active jobs to be incorrectly treated as destroyed and erased from live arrays. In addition, cross-dimension portal travel previously transferred active jobs without isolation, causing Overworld furnace jobs to run in Nether or The End. A defined time and persistence model was required for inactive dimensions and unloaded chunks.

## Decision
1. **Inactive Dimension and Unloaded Chunk Time is Paused:**
   - Unloaded chunks and inactive dimensions do not advance simulation timers, consume fuel, or grow structures into unloaded chunks.
   - When a player leaves a dimension via Nether or End portals or quits the game, active jobs (furnaces, smokers, blast furnaces, saplings) are durably persisted with their exact inputs, remaining fuel, elapsed timers, and coordinates.
   - On return to the dimension or game restart, jobs resume from their exact saved elapsed progress without lost items or duplicated outputs.

2. **Per-Dimension Save Namespaces:**
   - Block jobs persist in separate namespace files matching chunk storage conventions:
     - Overworld: `saves/block_jobs.bin`
     - Nether: `saves/nether/block_jobs.bin`
     - The End: `saves/the_end/block_jobs.bin`
   - Files encode binary header magic `ZJOB`, version `1`, expected dimension tag, bounded counts (<= 16 each), vertical coordinate bounds (0..15 for furnace jobs, 0..13 for sapling sprouts; full i32 range for x and z), finite non-negative timers, supported recipe inputs, and exact file length verification.

3. **Atomic Replacement and Transit Rollback:**
   - Saves use POSIX `writeAtomic` (`mkstemp`, `fsync`, atomic `rename`) so write failures preserve prior durable state.
   - In portal transit, source dimension jobs are persisted before chunk switching; if source saving fails, transit is paused and source jobs remain live.
   - Target dimension loading distinguishes absent files (fresh empty state) from corrupt files. An existing corrupt or unreadable file aborts startup or portal transit immediately before committing any interactive state, dimension, position, or cache changes, preserving the original corrupt file bytes on disk without automatic reset or overwrite.

4. **Unloaded Chunk Protection:**
   - Simulation loops check `manager.isBlockLoaded(x, y, z)` before comparing block IDs. Unloaded chunks skip ticking and retain job state.
   - Saplings check `isCanopyLoaded` across the full tree footprint so trees never grow into absent chunks.
