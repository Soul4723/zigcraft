---
name: implement
description: Use when writing or changing Zigcraft code.
---

1. Search for existing code for the mechanic first and extend it
   (CONTRIBUTING step 3). Read its decision records in `docs/decisions/`.
2. Make the change in the module that owns the mechanic, not in `main()`.
3. For gameplay work, wire the result into play: input or the frame loop
   must reach it, and its result or side effects must change the game.
4. Test changed rules and register new test files in `build.zig`. For
   build or tooling changes, run the affected command and its failure cases.
5. Run `bash scripts/check.sh`. For a visible change, run `zig build run`.
6. When a Zig error is unclear, read the Zig 0.16 standard library source and
   [CONTRIBUTING.md](../../../CONTRIBUTING.md#zig-016-gotchas) before
   guessing.

Done when the applicable items of CONTRIBUTING step 3 hold and
`scripts/check.sh` passes.
