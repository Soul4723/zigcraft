# Zigcraft

Zigcraft is a Minecraft-style voxel sandbox written in Zig, using GLFW,
OpenGL 3.3 and ALSA on Linux.

It is also an experiment in autonomous development: AI coding agents write
the code, tests and docs, review their own changes and merge checked work.
No person reviews routine changes. [AGENTS.md](AGENTS.md) and
[CONTRIBUTING.md](CONTRIBUTING.md) are the instructions the agents follow.

## What to expect

You can walk around a generated world, mine and place blocks, craft in a
2×2 grid, store items in chests, meet mobs, wire basic redstone, and travel
to a Nether and an End through portals.

It is rough in several ways:

- The world is one chunk layer tall: 16 blocks.
- Much gameplay feedback goes to the terminal, not the screen. Run the game
  from a terminal to see it.
- Most of the roughly 290 files in `src/world/` are rule modules with their
  own unit tests. Many are not yet connected to what you can do in the game.
  [docs/STATUS.md](docs/STATUS.md) lists what is connected and what is not.

## Build and run

You need Zig 0.16.0 exactly, the version CI uses. Zig 0.17 fails to compile
`build.zig`. The build targets Linux. Running the game needs a graphical
session with an OpenGL 3.3 driver.

Install the system libraries:

```bash
# Debian / Ubuntu
sudo apt-get install libglfw3-dev libgl-dev libasound2-dev pkg-config

# Arch Linux
sudo pacman -S glfw mesa alsa-lib pkgconf
```

Install [Zig 0.16.0](https://ziglang.org/download/), check `zig version`,
then from the repository root:

```bash
zig build                    # build
zig build run                # build and run
zig build test --summary all # run the unit tests
```

The tests check modules on their own. A passing test run does not show that
a mechanic is reachable in the game.

## Controls

| Input | Action |
|-------|--------|
| W, A, S, D | Move |
| Mouse | Look around |
| Space | Jump, or swim upward |
| Left mouse button | Mine a block, or attack |
| Right mouse button | Place a block, or use the held item |
| F | Interact with the aimed block (doors, repeaters, chests, TNT and others) |
| G | Throw the held item, if it can be thrown |
| B | Sleep, while aiming at wool at night |
| C | Print a compass reading, while holding a compass |
| 1–6 | Select a hotbar slot |
| E | Open or close the inventory and 2×2 crafting grid |
| Left Shift | Leave a boat or minecart |
| Escape | Quit |

The mouse is captured while the inventory is closed. You start with stone,
dirt, grass, wood, leaves and a wooden pickaxe.

## Saved worlds

Changed chunks are written to `saves/` in the working directory when they
unload and when the game exits normally, and are loaded again on start.
Blocks, water levels, repeater delays and burned-out redstone torches are
saved. The player, inventory and other machine state are not. The Overworld,
Nether and End share one set of chunk files, so a changed chunk in one
dimension replaces the terrain at the same coordinates in the others. Copy
`saves/` before trying a new version; save compatibility is not guaranteed.

## Documentation

- [docs/STATUS.md](docs/STATUS.md): what works, what is only tested, known problems
- [docs/ROADMAP.md](docs/ROADMAP.md): what comes next
- [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md): how the code is organized
- [docs/decisions/](docs/decisions/): architecture decision records
- [docs/learnings/](docs/learnings/) and [docs/research/](docs/research/): Zig 0.16 notes and background research

## License

Zigcraft is released under the [MIT License](LICENSE).
