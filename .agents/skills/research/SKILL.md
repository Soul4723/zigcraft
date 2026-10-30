---
name: research
description: Use before implementing something that depends on an unfamiliar Zig, OpenGL, GLFW or ALSA API, or when choosing between algorithms.
---

1. Write the question as one sentence.
2. Check, in order: existing code in `src/`, `docs/learnings/`,
   `docs/research/`, the Zig 0.16 standard library source, system headers,
   then the web. Trust source code over memory or web pages.
3. Compile any code example you keep, on Zig 0.16.0.
4. Write `docs/research/<topic>.md` with the question, date, findings with
   sources, tested examples, the recommendation and open questions.

Done when the research file answers the question and its examples compile.
