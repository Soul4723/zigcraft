# Decision 030: Chiseled Bookshelf storage, UV face targeting, and Secret Latch unification

Accepted: 2026-11-14.

## Context
Chiseled Bookshelf mechanics, UV face slot targeting, comparator signal rules, and secret combination piston-door locks were previously fragmented across three overlapping modules in `src/world/`:
- `src/world/chiseled_bookshelf.zig`: Contained `ChiseledBookshelf` (6 slots, `occupiedMask`, `comparatorSignal` retaining `last_interacted_slot + 1` after removal, `findBookshelf`) and basic `hitCoordsToSlot`/`worldHitToFaceUV`, using legacy item tags `400..403` (which actually collide with `cherry_log`..`pink_petals` in `src/items.zig`).
- `src/world/chiseled_bookshelf_storage.zig`: Contained `ChiseledBookshelfStorage`, `BookItem`, `SlotRow`, `SlotCol`, `SlotId`, `SlotCoords`, `UVHit`, `uvToCol`/`uvToRow`/`uvToSlotCoords`/`worldHitToSlot`/`interactUV`, and expanded book validation (`Book` `270`, `Enchanted Book` `440`, `Mending` `441`, `Swift Sneak` `470`, `Sweeping Edge` `474`, `Feather Falling` `479`, `Book and Quill` `499`, `Written Book` `500`).
- `src/world/bookshelf_secret_latch.zig`: Contained `BookshelfState`, `SecretLatch` (multi-shelf password matching outputting `15` when unlocked or `0` when locked), and `PistonDoor` (6-tick retraction/extension actuator).

In `src/main.zig`, `chiseled_bookshelf_storage_mod` and `bookshelf_secret_latch_mod` were only imported to run discarded dummy reads (`_ = chiseled_bookshelf_storage_mod.total_slots;`, `_ = bookshelf_secret_latch_mod.door_transition_ticks;`), while `.chiseled_bookshelf` F-key interaction computed slot index from a block-coordinate hash instead of face UV raycasting, rejected real enchanted book IDs (`440, 441, 470, 474, 479, 499, 500`), and never evaluated `SecretLatch` or `PistonDoor`.

## Decision
1. **Module ownership**: `src/world/chiseled_bookshelf.zig` is the single authoritative module for Chiseled Bookshelf storage, UV face targeting, comparator signal calculation, `BookshelfState`, `SecretLatch`, and `PistonDoor`.
   - Standardized book item IDs on `src/items.zig` (`270, 440, 441, 470, 474, 479, 499, 500`) and removed `400..403` from `isAcceptedBook`/`isBookItem` so `cherry_log`, `cherry_leaves`, `cherry_planks`, and `pink_petals` cannot be shelved as books in live play.
   - Standardized Cartesian face UV orientation (`v = clamp(fy, 0.0, 1.0)` with `v >= 0.50` selecting the top row `0..2` and `v < 0.50` selecting the bottom row `3..5`; horizontal `u` mapped across `.north`, `.south`, `.west`, `.east`) and added `raycastBlockFaceSlot` for 3D ray-plane slot selection.
   - Retained `ChiseledBookshelf.comparatorSignal()` (1..6 for `last_interacted_slot + 1`, retained across removals until `clear()`, matching Minecraft 1.20), exposed `occupiedComparatorSignal()` for occupancy-gated queries, and added `toBookshelfState()` and `evaluateBookshelfLatch()` to bridge `ChiseledBookshelf` storage with `SecretLatch` and `PistonDoor`.
   - Consolidated all 75 unit tests into `src/world/chiseled_bookshelf.zig`, removed `src/world/chiseled_bookshelf_storage.zig` and `src/world/bookshelf_secret_latch.zig` via `git rm`, and removed their entries from `test_files` in `build.zig`.
2. **Gameplay integration in `src/main.zig`**:
   - Removed the unused `chiseled_bookshelf_storage_mod` and `bookshelf_secret_latch_mod` imports and both discarded `_ = ...` calls.
   - Tracked interacted Chiseled Bookshelves spatially (`max_chiseled_bookshelves = 32`), wired `raycastBlockFaceSlot` for 6-slot UV targeting, enabled all `isAcceptedBook` book variants (including Mending, Swift Sneak, Sweeping Edge, Feather Falling, Book and Quill, Written Book), evaluated `SecretLatch` (`default_latch_password = .{ 0, 5 }`) and `PistonDoor` (ticked at 0.05s per tick in the frame loop), triggered `.glowstone_chime` audio and `particles.spawnGlowstoneShimmer` on latch unlock, and logged slot (`1..6`), comparator signal, occupied mask, and latch/door status.
