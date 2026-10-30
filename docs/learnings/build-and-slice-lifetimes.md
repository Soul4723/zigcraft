# Compiler setup and slice lifetimes

Use `bash scripts/setup.sh` to install checksum-pinned Zig 0.16.0 in the
ignored `.local/` directory. `bash scripts/check.sh` prefers that compiler;
for interactive commands, prepend `.local/bin` to `PATH` as CONTRIBUTING
shows. A newer system Zig is not a reason to migrate the source.

The build selects both LLVM code generation and LLD linking. The native
linker rejected `.sframe` relocations in recent Linux C runtime objects.
Selecting LLD without LLVM crashed this compiler; selecting both built
successfully without copying or changing system runtime files.

LLVM also exposed a dangling slice in `HarvestOutcome.getDrops` in
`src/world/decorated_pot.zig`: a by-value `self` returned a slice of its copied
array. The slice outlived that copy, corrupting item IDs and enum values.
Changing the receiver to `*const HarvestOutcome` borrows the caller's live
array. Existing shatter tests failed before the fix and all 22 module tests
passed afterward. The owner must still outlive the borrowed slice.

The same correction applies to `decorated_pot_storage.zig` and
`EquipmentItem.getName` in `netherite_smithing_pipeline.zig`: a returned slice
must borrow the caller's array, including an array inside an optional value.
