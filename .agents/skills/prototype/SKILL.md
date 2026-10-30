---
name: prototype
description: Use when a risky technical choice should be tried in throwaway code before it goes into the game.
---

1. Write the question the prototype answers.
2. Branch `prototype/<question>` from `origin/main`. Quick code is fine.
3. Record the answer and the chosen approach in `docs/research/<topic>.md`
   or a decision record, merged through a normal `docs/` pull request.
4. Delete the prototype branch. Never merge it; rewrite the good parts on a
   normal branch.

Done when the answer is merged in the docs and the prototype branch is gone.
