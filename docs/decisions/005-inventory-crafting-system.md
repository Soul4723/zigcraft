# Decision 005: Slot-Based Grid Inventory and Procedural Crafting Resolution

## Status
Accepted (2026-10-02, Session 022)

## Context
Milestone 31 calls for an inventory and crafting system. The engine needs a unified way to handle player items (both placable blocks and tools/craftables), an interactive UI overlay screen toggled with standard Minecraft controls ('E'), and recipe synthesis.

## Options Considered

1. **Text-based / console-only inventory**
   - Simpler to implement without 2D UI drawing.
   - Poor user experience; fails Minecraft gameplay expectations.

2. **Unified Slot-Based Grid Inventory with Immediate-Mode 2D Quad GUI**
   - `Inventory` struct with 6 hotbar slots, 18 main inventory storage slots, 2x2 crafting grid, and 1 output slot.
   - Cursor item stack for mouse dragging / swapping.
   - Immediate 2D UI quads batched into dynamic vertex buffers with alpha blending.
   - Item consumption on placement and item drop addition on block mining.

## Decision
Implement Option 2:
- Items cleanly map to `BlockId` where applicable, or stand as craftable tools (Sticks, Wooden Pickaxe).
- Immediate recipe verification updates the output slot reactively upon grid changes.
- Pressing 'E' unlocks the cursor and opens the full inventory window, freezing player look movement while active.
