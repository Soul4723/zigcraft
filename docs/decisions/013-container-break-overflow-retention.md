# Decision 013: Container break overflow retention

Accepted: 2026-11-04.

Breaking or exploding chests, shulker boxes, hoppers, or droppers previously transferred
items into player inventory using `inventory.addItem`, silently discarding any overflow items
when the 24-slot inventory had insufficient space. Additionally, hoppers and droppers were not
drained at all when mined or blasted, losing their stored items when their coordinates were remeshed to air.

Without a floating item entity drop system, containers cannot spill items as loose pickup entities.
Instead, container breaks perform an atomic drain check via `drainContainerBreak`:
1. All fitting items are transferred into the player inventory using `addItem` and removed from container slots.
2. If all container slots become empty (`drained == true`), the container cache entry is removed, the block is remeshed to air, and the container block item drop is awarded.
3. If overflow remains (`drained == false`), the break or explosion is aborted: the container block survives in the world, its remaining items remain preserved in the cache, and no block drop is awarded. In mining, user feedback is printed to the console (`inventory full; container retained overflow items`).

This ensures total item conservation across mining, creeper blasts, TNT explosions, end crystal detonations, and respawn anchor overcharges without requiring an item-entity simulation layer.
