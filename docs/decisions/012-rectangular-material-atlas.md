# Decision 012: Extend the material atlas vertically

Accepted: 2026-11-02.

Obsidian reused the sheep-face tile and Nether portal cells reused the wooden
pressure-plate tile. Live frames therefore showed faces and wooden pads instead
of recognizable portal materials. Repainting those shared tiles would change
sheep and pressure plates too.

Extend the atlas from eight by eight to eight by sixteen tiles, retaining all
existing tile coordinates. Add dedicated obsidian and purple portal tiles on
row eight. Texture creation and both renderer and chunk-mesh UV paths use the
rectangular dimensions. Pixels stay 16 by 16; no world or save IDs change.

A larger square atlas would also work but would change both UV axes and allocate
more unused pixels. Remapping the existing materials would require broader
coordination. Vertical extension changes only the V scale and doubles the RGBA
atlas allocation from 64 KiB to 128 KiB. Future materials may use the added rows;
this change does not attempt to repair every existing shared material mapping.
