---
name: implement
description: >-
  Implement a feature or fix. Follow this procedure exactly.
---

## Before coding

1. Read `CONTRIBUTING.md` for code patterns and rules
2. Read `docs/architecture/OVERVIEW.md` to understand where your code fits
3. Check `docs/decisions/` for relevant ADRs
4. Check `docs/research/` for relevant research notes
5. Check `docs/learnings/zig-0.16-changes.md` for API gotchas

## While coding

### Build after every meaningful change

```bash
zig build
```

Not "when you're done". After every function, every struct, every file.
Zig's compiler errors are precise — catching them early saves time.

### Follow existing patterns

Look at existing code first. Match the style. If `main.zig` uses
`const c = @cImport(...)`, your new file does too. If errors are returned
with `return error.SomethingFailed`, do that, don't use `@panic`.

### Keep files focused

One module per file. If a file is getting past 200 lines, consider
splitting. But don't split preemptively — split when there's a clear
seam.

### Test what you can

```bash
zig build test          # unit tests
zig build run           # manual verification for visual features
```

For visual/runtime features that can't be unit tested, describe what
you verified in the commit message.

## Commit pattern

```bash
git add -A
zig build               # must pass
git commit -m "<type>: <description>"
```

Small commits. One logical change each. Don't batch an entire feature
into one commit if it has separable parts.

## If something doesn't compile

1. Read the error message carefully — Zig errors are usually precise
2. Search the actual standard library: `rg <symbol> /usr/lib/zig/std/`
3. Check `docs/learnings/zig-0.16-changes.md`
4. If you can't fix it in 10 minutes, write down what you tried in the
   session log and move on to something else
