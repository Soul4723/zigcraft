---
name: research
description: >-
  Investigate a technical question using primary sources. Write findings
  to docs/research/. Use before implementing anything you're uncertain about.
---

## When to use this

- Before implementing a feature that involves unfamiliar APIs
- When the Zig 0.16 API doesn't match what you expect
- When choosing between algorithms or approaches
- When you need to understand how a C library works with Zig

## Process

### 1. Define the question

Write it down explicitly. "How does X work?" or "Which approach is better
for Y?" Not "research rendering".

### 2. Search primary sources

In this order:
1. **Zig standard library source**: `rg <term> /usr/lib/zig/std/ -l`
2. **System headers**: `rg <term> /usr/include/ -l`
3. **Existing project code**: `rg <term> src/`
4. **docs/learnings/**: check if someone already figured this out
5. **Web search**: last resort, and verify against source code

**Critical**: Your training data for Zig is almost certainly outdated.
Zig 0.16.0 has breaking changes from every prior version. Always verify
against `/usr/lib/zig/std/`.

### 3. Write findings

Create `docs/research/<topic>.md` with:

```markdown
# <Topic>

Date: YYYY-MM-DD
Question: <the specific question>

## Findings

<what you found, with source citations>

## Code Examples

<working examples tested against Zig 0.16.0>

## Decision / Recommendation

<what to do based on findings>

## Open Questions

<anything still uncertain>
```

### 4. Test code examples

If the research includes code, compile it. Don't write untested examples.

```bash
# Quick test: add a test block to an existing file or create a scratch file
zig build test
```
