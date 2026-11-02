# Decision 010: Per-dimension automation persistence

Accepted: 2026-11-02.

Hopper and dropper inventories previously lived only in coordinate-keyed arrays,
which lost items at restart and could expose source-dimension items after travel.

Keep the existing four-slot runtime model and store both caches in one versioned
`automation.bin` per dimension. The format uses explicit little-endian encoding,
a dimension tag, bounded counts and coordinates, validated stack sizes, finite
hopper cooldowns and a Boolean dropper power state. Decode into temporary arrays
and replace live caches only after validation and successful dimension switching.
Missing files mean empty caches; corrupt or unreadable files block startup or travel.

This extends the paused inactive-dimension/unloaded-chunk model in decision 008.
Atomic replacement reuses the existing persistence writer. A combined file keeps
hopper/dropper state together without changing existing container or job formats.
Extending those existing files would couple unrelated format migrations; a general
block-entity database is unnecessary for these bounded caches. Separate chunk,
player, container, job and automation files are not one atomic transaction.

Failed destination insertion leaves the source item in place. Without an item-entity
system, dispensing into air succeeds only when the nearby player can receive the
item. Container-break overflow remains separate work.
