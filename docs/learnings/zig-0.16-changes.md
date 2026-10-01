# Zig 0.16.0 API Changes

Date: 2026-10-01

These are things discovered by actually compiling against the installed
Zig 0.16.0 standard library at `/usr/lib/zig/std/`.

## I/O

- `std.io` no longer exists as a public namespace. The module is `std.Io`
  (capital I) and it's a completely different async I/O interface.
- **For console output, use `std.debug.print`.** This writes to stderr
  and is the simplest way to print in 0.16.0.
- The old `std.io.getStdOut().writer()` pattern does not work.

## Build API

- `build.zig` executable creation uses `b.createModule()` instead of
  directly passing `.root_source_file` to `b.addExecutable()`.
- The executable's `.root_module` field takes a module created by
  `b.createModule()`.
- Package manifest (`build.zig.zon`) uses `.name = .identifier` (dot-prefixed
  identifier, not a string).
- The `fingerprint` field is required and validated by the compiler. On
  first build, the compiler tells you what value to use.

## Standard Library Layout

The standard library at `/usr/lib/zig/std/std.zig` exports:
- `std.debug` — debug printing, stack traces
- `std.mem` — memory utilities, Allocator
- `std.posix` — POSIX system calls
- `std.Io` — new async I/O system
- `std.Build` — build system
- `std.ArrayList`, `std.HashMap`, etc. — data structures

## Testing

- `zig build test` works as expected
- Test blocks: `test "name" { ... }` in any source file
- The build.zig template uses `b.addTest(.{ .root_module = ... })`
