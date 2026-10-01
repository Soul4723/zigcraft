# Chunk Meshing Strategies

Date: 2026-10-01
Question: How should we generate renderable meshes from voxel chunk data?

## Problem

A chunk is a 16×16×16 grid of block IDs. We need to generate a triangle mesh
from this data that only includes visible faces — faces between a solid block
and air (or transparent block).

## Approach 1: Naive Per-Face (Start Here)

For each solid block, check its 6 neighbors. If a neighbor is air or
transparent, emit a quad (2 triangles) for that face.

```
for each block in chunk:
    if block is air: skip
    for each of 6 directions:
        neighbor = block at (pos + direction)
        if neighbor is air or transparent:
            emit 4 vertices for this face
            emit 2 triangles (6 indices)
```

**Vertex format** for this approach:
```zig
const Vertex = struct {
    position: [3]f32,    // world position
    normal: [3]f32,      // face normal (for lighting later)
    tex_coord: [2]f32,   // texture coordinates
};
```

**Performance**: A worst-case chunk (checkerboard) generates ~24K quads
(~144K vertices). Acceptable for a small world but wasteful.

**This is the right first implementation.** It's simple, correct, and
easy to debug. Optimize later.

## Approach 2: Greedy Meshing (Later Optimization)

Merge adjacent coplanar faces of the same block type into larger quads.
Reduces vertex count by 80-95% in typical terrain.

Algorithm:
1. For each slice along an axis (e.g., all blocks at y=5):
2. Create a 2D mask of visible faces
3. Sweep the mask: find the largest rectangle of same-type faces
4. Emit one quad for that rectangle
5. Clear those faces from the mask
6. Repeat until mask is empty

Much more complex to implement. Do this only after naive meshing works
and you've profiled to confirm it's needed.

## Approach 3: Binary Greedy Meshing (Much Later)

Uses bitwise operations on the face mask for the sweep step. Fastest
known approach. Very complex. Don't even think about this until greedy
meshing is proven insufficient.

## Chunk Border Handling

A chunk needs to know about its neighbors to generate correct meshes at
chunk boundaries. Options:

1. **Pass neighbor data**: When meshing chunk (x,y,z), also pass the
   border slices of chunks (x±1, y±1, z±1). Simple, explicit.
2. **World lookup**: The mesh function queries the world for any block
   position. Cleaner API but tighter coupling.

Recommendation: option 1. Keep meshing a pure function of data.

## Mesh Update Strategy

When a block changes, only the containing chunk needs remeshing (and
possibly the adjacent chunk if the block is on a border). Don't remesh
the entire world.

## Data Layout

```zig
const Chunk = struct {
    blocks: [16][16][16]BlockId,  // y, z, x ordering for cache-friendly vertical access

    pub fn getBlock(self: *const Chunk, x: u4, y: u4, z: u4) BlockId {
        return self.blocks[y][z][x];
    }

    pub fn setBlock(self: *Chunk, x: u4, y: u4, z: u4, block: BlockId) void {
        self.blocks[y][z][x] = block;
    }
};
```

Use `u4` for coordinates (0-15 fits in 4 bits). `BlockId` is a `u8` or `u16`
depending on how many block types we need. Start with `u8` (256 types).

## Vertex Packing (Later Optimization)

Instead of 32 bytes per vertex (3×f32 + 3×f32 + 2×f32), pack into 8 bytes:
- Position: 5+5+5 bits (chunk-local coords, 0-15 with sub-block precision)
- Normal: 3 bits (6 possible directions)
- Texture ID: 10 bits
- UV: 2 bits (corner index)

This is a big optimization but makes the code much harder to debug.
Do it only after naive meshing works and vertex count is a proven bottleneck.

## Open Questions

- What's the right vertex format for the texture atlas? Depends on how
  we structure block textures. Decide when implementing textures.
- Should chunks store their mesh GPU-side (VBO per chunk) or use a
  single large VBO? Per-chunk VBO is simpler. Single VBO is faster but
  more complex to manage. Start with per-chunk.
