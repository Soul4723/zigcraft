# Decision 011: Naturally reachable dormant portal frames

Accepted: 2026-11-02.

Overworld terrain generated neither obsidian nor lava, and no obsidian recipe
provided the ten edges needed by the existing Nether portal detector. A fixture
portal could be activated, but baseline exploration could not obtain a frame.

Generate sparse deterministic dormant frames on suitable Overworld land, using
the existing ruined-portal owner for geometry. Each 64-block region searches a
bounded sequence of candidate sites. Flat dry ground, height/headroom and nearby
structures/trees constrain placement. World-coordinate sampling keeps separate
chunk generation independent of order. Existing saved chunks remain unchanged.

All ten essential edges use ordinary obsidian and the six interior cells stay
clear, so the existing F ignition path works without unavailable repair materials.
The default seed provides a site near spawn. This is a progression choice for the
current game, not a claim of exact Minecraft ruined-portal generation rules.

Incomplete frames plus repair loot would require new acquisition/loot integration;
natural lava and bucket casting require a broader fluid/progression increment.
Complete inactive frames reuse working travel now while leaving those alternatives
available. The change adds no block IDs, starting items or ignition-rule changes.
