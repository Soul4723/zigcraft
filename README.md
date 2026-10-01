# Zigcraft

A Minecraft clone written in Zig. Built entirely by AI — no human developer writes code.

## Building

Requires Zig 0.16.0+ and system libraries:

```bash
# CachyOS / Arch Linux
sudo pacman -S zig glfw vulkan-devel vulkan-headers cmake

# Build
zig build

# Run
zig build run

# Test
zig build test
```

## Project Structure

```
src/          Source code
docs/         Project documentation
.agents/      AI workflow definitions (skills)
```

See [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md) for details.

## Status

See [docs/STATUS.md](docs/STATUS.md) for current state and
[docs/ROADMAP.md](docs/ROADMAP.md) for what's planned.
