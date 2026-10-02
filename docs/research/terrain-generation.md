# Terrain Generation

Date: 2026-10-01
Question: How should we generate terrain for the voxel world?

## Overview

Terrain generation uses noise functions to create a heightmap, then fills
blocks below the surface with appropriate types (grass on top, dirt below,
stone deeper).

## Noise Function

Use Simplex noise (or OpenSimplex). It's better than Perlin noise for
this purpose — less grid-aligned artifacts.

The algorithm is simple enough to implement directly in Zig (~100 lines).
No need for an external library.

**Key parameters:**
- **Octaves**: Number of noise layers to combine. More octaves = more detail.
  Start with 4-6.
- **Frequency**: How "zoomed in" the noise is. Lower = smoother terrain.
  Start with 0.01.
- **Amplitude**: Height variation. Start with 32 blocks.
- **Lacunarity**: Frequency multiplier per octave. Standard value: 2.0.
- **Persistence**: Amplitude multiplier per octave. Standard value: 0.5.

## Height Calculation

```
for each (x, z) column:
    height = base_height
    for each octave:
        height += amplitude * simplex_noise(x * frequency, z * frequency)
        frequency *= lacunarity
        amplitude *= persistence

    for y from 0 to chunk_height:
        if y == 0: bedrock
        else if y < height - 4: stone
        else if y < height: dirt
        else if y == height: grass
        else: air
```

## Seed

Use a u64 seed to initialize the noise permutation table. Same seed =
same world. The seed should be configurable (passed to the world generator).

## Chunk-Based Generation

Generate terrain per-chunk, not per-world. When a chunk is loaded for
the first time, generate its terrain from the noise function. The noise
function is deterministic — same (x, z) always produces the same height,
regardless of which chunk requests it.

## Biomes (Later)

Not for the initial implementation. When added:
- Use a second noise function at lower frequency for biome selection
- Biome determines block types, tree placement, height variation
- Blend between biomes at borders

## Implementation Plan

1. Implement 2D simplex noise
2. Generate flat terrain (y < 64 = stone, y == 64 = grass)
3. Add noise-based heightmap
4. Add multi-octave fractal noise
5. Add block type variation (grass/dirt/stone layers)

Steps 1-3 are one session's work. Steps 4-5 are a second session.

## Reference

OpenSimplex2 algorithm: https://github.com/KdotJPG/OpenSimplex2
The "fast" variant is sufficient and simpler to port.
