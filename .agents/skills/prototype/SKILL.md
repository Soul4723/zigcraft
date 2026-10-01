---
name: prototype
description: >-
  Build a throwaway prototype to test an approach before committing
  to it in the main codebase. Use for risky technical decisions.
---

A prototype answers a question. It lives on a throwaway branch and
gets deleted or archived after the question is answered.

## When to Prototype

- Unsure if a Zig C interop approach works
- Testing a rendering technique before building the full pipeline
- Comparing two algorithms (meshing, noise, culling)
- Anything where the cost of guessing wrong is high

## Process

1. **State the question.** Write it down before coding.

2. **Branch.** `prototype/<topic>` branch from main.

3. **Build fast and ugly.** No tests, no style, no abstraction.
   The point is to learn, not to ship.

4. **Record the answer.** Write a short note in `docs/research/<topic>.md`
   with what you learned and which approach to use.

5. **Clean up.** Either:
   - Delete the branch if the knowledge is captured in docs
   - Leave it as a reference and note its existence in the research doc

6. **Never merge a prototype branch into main.** Rewrite the good
   parts cleanly on a proper feature branch.
