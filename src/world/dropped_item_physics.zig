//! Milestone 429: Dropped Item Entity 5-Minute Despawn Timer, Stack Merge Radius
//! & Age Inheritance, Ice Water-Stream Sliding & Nether Star Blast Immunity.
//!
//! Provides clean, deterministic mechanics for:
//! 1. ItemDespawnLifecycle:
//!    - Initial pickup delays: 10 ticks (0.5s) for block break drops and mob loot;
//!      40 ticks (2.0s) for player Q throws.
//!    - 6000-tick (5.0 minutes / 300 seconds) despawn timer.
//!    - Chunk loading simulation rule: age_ticks only increments while the chunk is loaded.
//!      Unloaded chunk items never tick or despawn.
//! 2. ItemStackClumping:
//!    - Nearby dropped ItemEntity stacks of the same ItemType within 0.5-block horizontal
//!      and vertical merge radius merge into a single stack if total_count <= max_stack_size.
//!    - Merged stack adopts the younger (min(age_a, age_b)) age, refreshing the despawn timer.
//! 3. WaterIceStreamTransport:
//!    - Flowing water pushes items at ~1.8 m/s on normal blocks.
//!    - ~8.0 m/s over packed ice.
//!    - ~12.0+ m/s (12.5 m/s) when sliding across blue ice gaps between aligned ender_chest /
//!      honey_block / top_slab water streams.
//! 4. NetherStarExplosionImmunity:
//!    - Nether Star is completely immune to all explosions (isNetherStarImmuneToExplosions() == true).
//!    - Netherite items survive explosions, fire, and lava.
//!    - Regular non-Netherite items are destroyed by fire, lava, and explosions.
//!    - ALL dropped items (including Netherite and Nether Star) are destroyed by cactus
//!      (destroyedByCactus() == true).

const std = @import("std");
const block_mod = @import("block.zig");
pub const BlockId = block_mod.BlockId;

// ============================================================================
// Item Types & Classification
// ============================================================================

pub const ItemType = enum(u16) {
    none = 0,
    stone = 1,
    dirt = 2,
    grass = 3,
    water = 4,
    wood = 5,
    leaves = 6,
    wood_planks = 7,
    stick = 8,
    wooden_pickaxe = 9,
    cobblestone = 11,
    sand = 14,
    cactus = 39,
    netherrack = 49,
    nether_star = 68,
    netherite_scrap = 71,
    netherite_ingot = 72,
    netherite_pickaxe = 73,
    netherite_sword = 74,
    netherite_chestplate = 90,
    netherite_helmet = 92,
    netherite_leggings = 93,
    netherite_boots = 95,
    honey_block = 161,
    ice = 198,
    packed_ice = 199,
    blue_ice = 200,
    ender_chest = 205,
    netherite_axe = 231,
    netherite_shovel = 235,
    netherite_hoe = 239,
    netherite_block = 240,
    ancient_debris = 241,
    diamond = 264,
    iron_ingot = 265,
    gold_ingot = 266,
    diamond_sword = 267,
    diamond_pickaxe = 278,
    _,

    pub fn maxStackSize(self: ItemType) u8 {
        return switch (self) {
            .netherite_sword,
            .netherite_pickaxe,
            .netherite_axe,
            .netherite_shovel,
            .netherite_hoe,
            .netherite_helmet,
            .netherite_chestplate,
            .netherite_leggings,
            .netherite_boots,
            .diamond_sword,
            .diamond_pickaxe,
            .wooden_pickaxe,
            => 1,
            else => 64,
        };
    }

    pub fn name(self: ItemType) []const u8 {
        return switch (self) {
            .none => "Air",
            .stone => "Stone",
            .dirt => "Dirt",
            .cobblestone => "Cobblestone",
            .nether_star => "Nether Star",
            .netherite_scrap => "Netherite Scrap",
            .netherite_ingot => "Netherite Ingot",
            .netherite_sword => "Netherite Sword",
            .netherite_pickaxe => "Netherite Pickaxe",
            .netherite_axe => "Netherite Axe",
            .netherite_shovel => "Netherite Shovel",
            .netherite_hoe => "Netherite Hoe",
            .netherite_helmet => "Netherite Helmet",
            .netherite_chestplate => "Netherite Chestplate",
            .netherite_leggings => "Netherite Leggings",
            .netherite_boots => "Netherite Boots",
            .netherite_block => "Netherite Block",
            .ancient_debris => "Ancient Debris",
            .diamond => "Diamond",
            .iron_ingot => "Iron Ingot",
            .gold_ingot => "Gold Ingot",
            .cactus => "Cactus",
            else => "Item",
        };
    }
};

pub const DropSource = enum {
    block_drop,
    mob_loot,
    player_throw,
    death_drop,
    dispenser,
    hopper,
    container_break,
};

pub fn initialPickupDelay(source: DropSource) u8 {
    return switch (source) {
        .player_throw => 40,
        .block_drop, .mob_loot, .dispenser, .death_drop, .hopper, .container_break => 10,
    };
}

// ============================================================================
// 1. ItemDespawnLifecycle
// ============================================================================

pub const ItemDespawnLifecycle = struct {
    const Self = @This();

    pub const max_item_age_ticks: u16 = 6000;
    pub const nether_star_max_age_ticks: u16 = 12000; // 10.0 minutes
    pub const pickup_delay_block_drop: u8 = 10;
    pub const pickup_delay_mob_drop: u8 = 10;
    pub const pickup_delay_player_throw: u8 = 40;
    pub const ticks_per_second: f32 = 20.0;
    pub const despawn_time_seconds: f32 = 300.0; // 5.0 minutes (6000 / 20)

    /// Standard despawn rule: 6000 game ticks (5 minutes).
    pub fn shouldItemDespawn(age_ticks: u16) bool {
        return age_ticks >= Self.max_item_age_ticks;
    }

    /// Despawn check supporting custom item lifetimes (e.g. 10m for Nether Star).
    pub fn shouldItemDespawnFor(item: anytype, age_ticks: u16) bool {
        return age_ticks >= Self.maxAgeTicksFor(item);
    }

    /// Returns the maximum lifespan in game ticks for an item before despawning.
    pub fn maxAgeTicksFor(item: anytype) u16 {
        if (NetherStarExplosionImmunity.isNetherStar(item)) return Self.nether_star_max_age_ticks;
        return Self.max_item_age_ticks;
    }

    /// Dropped item entity age_ticks ONLY increments when the chunk is loaded.
    /// Returns false: items in unloaded chunks never advance age or despawn.
    pub fn ticksWhenChunkUnloaded() bool {
        return false;
    }

    /// Advances the item's age and decrements its pickup delay if the chunk is loaded.
    /// Returns true if the item has reached its despawn threshold.
    pub fn tickItem(item: *ItemEntity, chunk_loaded: bool) bool {
        if (!chunk_loaded) {
            return false;
        }
        if (item.pickup_delay_ticks > 0) {
            item.pickup_delay_ticks -= 1;
        }
        item.age_ticks = item.age_ticks +| 1;
        return Self.shouldItemDespawnFor(item.item, item.age_ticks);
    }
};

pub const max_item_age_ticks: u16 = ItemDespawnLifecycle.max_item_age_ticks;
pub const MAX_ITEM_AGE_TICKS: u16 = ItemDespawnLifecycle.max_item_age_ticks;
pub const nether_star_max_age_ticks: u16 = ItemDespawnLifecycle.nether_star_max_age_ticks;
pub const NETHER_STAR_MAX_AGE_TICKS: u16 = ItemDespawnLifecycle.nether_star_max_age_ticks;
pub const pickup_delay_block_drop: u8 = ItemDespawnLifecycle.pickup_delay_block_drop;
pub const pickup_delay_mob_drop: u8 = ItemDespawnLifecycle.pickup_delay_mob_drop;
pub const pickup_delay_player_throw: u8 = ItemDespawnLifecycle.pickup_delay_player_throw;
pub const shouldItemDespawn = ItemDespawnLifecycle.shouldItemDespawn;
pub const shouldItemDespawnFor = ItemDespawnLifecycle.shouldItemDespawnFor;
pub const maxAgeTicksFor = ItemDespawnLifecycle.maxAgeTicksFor;
pub const ticksWhenChunkUnloaded = ItemDespawnLifecycle.ticksWhenChunkUnloaded;

// ============================================================================
// 2. ItemStackClumping
// ============================================================================

pub const ItemStackClumping = struct {
    const Self = @This();

    pub const merge_radius: f32 = 0.5;
    pub const merge_radius_horizontal: f32 = 0.5;
    pub const merge_radius_vertical: f32 = 0.5;

    /// Checks if two position vectors are within the 0.5-block horizontal and vertical merge radius.
    pub fn isWithinMergeRadius(pos_a: [3]f32, pos_b: [3]f32) bool {
        const dx = @abs(pos_a[0] - pos_b[0]);
        const dy = @abs(pos_a[1] - pos_b[1]);
        const dz = @abs(pos_a[2] - pos_b[2]);
        return dx <= (Self.merge_radius_horizontal + 0.0001) and
               dy <= (Self.merge_radius_vertical + 0.0001) and
               dz <= (Self.merge_radius_horizontal + 0.0001);
    }

    /// Merged stack adopts the younger (smaller age_ticks) of the two stacks,
    /// refreshing its despawn timer.
    pub fn mergedAgeTicks(age_a: u16, age_b: u16) u16 {
        return @min(age_a, age_b);
    }

    /// Combines two nearby dropped ItemEntity stacks into target if:
    /// 1. Both stacks have the same ItemType.
    /// 2. total_count <= max_stack_size.
    /// 3. Positions are within the 0.5-block merge radius.
    ///
    /// On success:
    /// - target.count += source.count.
    /// - target.age_ticks = min(target.age_ticks, source.age_ticks).
    /// - target.pickup_delay_ticks = min(target.pickup_delay_ticks, source.pickup_delay_ticks).
    /// - source.count = 0 (consumed).
    pub fn tryMergeItemStacks(target: *ItemEntity, source: *ItemEntity) bool {
        if (target == source) return false;
        if (target.count == 0 or source.count == 0) return false;
        if (target.item != source.item) return false;

        const total: u16 = @as(u16, target.count) + @as(u16, source.count);
        if (total > target.max_stack_size) return false;

        if (!Self.isWithinMergeRadius(target.pos, source.pos)) return false;

        target.count = @intCast(total);
        target.age_ticks = Self.mergedAgeTicks(target.age_ticks, source.age_ticks);
        target.pickup_delay_ticks = @min(target.pickup_delay_ticks, source.pickup_delay_ticks);
        source.count = 0;
        return true;
    }
};

pub const merge_radius: f32 = ItemStackClumping.merge_radius;
pub const MERGE_RADIUS: f32 = ItemStackClumping.merge_radius;
pub const MERGE_RADIUS_HORIZONTAL: f32 = ItemStackClumping.merge_radius_horizontal;
pub const MERGE_RADIUS_VERTICAL: f32 = ItemStackClumping.merge_radius_vertical;
pub const isWithinMergeRadius = ItemStackClumping.isWithinMergeRadius;
pub const mergedAgeTicks = ItemStackClumping.mergedAgeTicks;
pub const tryMergeItemStacks = ItemStackClumping.tryMergeItemStacks;

// ============================================================================
// 3. WaterIceStreamTransport
// ============================================================================

pub const StreamSurface = enum {
    normal,
    ice,
    packed_ice,
    blue_ice,
};

pub const StreamAlignment = enum {
    none,
    ender_chest,
    honey_block,
    top_slab,

    pub fn isAligned(self: StreamAlignment) bool {
        return self != .none;
    }
};

pub const StreamMedium = enum {
    water_stream,
    dry_gap,
    air_gap,

    pub fn isWater(self: StreamMedium) bool {
        return self == .water_stream;
    }
};

pub const WaterIceStreamTransport = struct {
    const Self = @This();

    /// Terminal horizontal push speed in flowing water over normal blocks (~1.8 m/s).
    pub const NORMAL_BLOCK_STREAM_SPEED: f32 = 1.8;
    /// Terminal horizontal push speed in flowing water over standard ice (~4.5 m/s).
    pub const ICE_STREAM_SPEED: f32 = 4.5;
    /// Terminal horizontal push speed in flowing water over packed ice (~8.0 m/s).
    pub const PACKED_ICE_STREAM_SPEED: f32 = 8.0;
    /// Unaligned flowing water push speed over blue ice (~12.0 m/s).
    pub const BLUE_ICE_STREAM_SPEED: f32 = 12.0;
    /// Sliding speed across blue ice gaps between aligned ender_chest / honey_block / top_slab water streams (~12.0+ m/s).
    pub const BLUE_ICE_ALIGNED_GAP_SPEED: f32 = 12.5;

    pub const SLIPPERINESS_NORMAL: f32 = 0.6;
    pub const SLIPPERINESS_ICE: f32 = 0.98;
    pub const SLIPPERINESS_PACKED_ICE: f32 = 0.98;
    pub const SLIPPERINESS_BLUE_ICE: f32 = 0.989;

    pub fn parseSurface(surface: anytype) StreamSurface {
        const T = @TypeOf(surface);
        if (T == StreamSurface) return surface;
        if (T == BlockId) {
            return switch (surface) {
                .packed_ice => .packed_ice,
                .blue_ice => .blue_ice,
                .ice => .ice,
                else => .normal,
            };
        }
        if (@typeInfo(T) == .@"enum" or @typeInfo(T) == .enum_literal) {
            const tag = @tagName(surface);
            if (std.mem.eql(u8, tag, "packed_ice")) return .packed_ice;
            if (std.mem.eql(u8, tag, "blue_ice")) return .blue_ice;
            if (std.mem.eql(u8, tag, "ice")) return .ice;
            return .normal;
        }
        return .normal;
    }

    pub fn isAlignmentActive(alignment: anytype) bool {
        const T = @TypeOf(alignment);
        if (T == bool) return alignment;
        if (T == StreamAlignment) return alignment != .none;
        if (T == BlockId) {
            return alignment == .ender_chest or alignment == .honey_block;
        }
        if (@typeInfo(T) == .@"enum" or @typeInfo(T) == .enum_literal) {
            const tag = @tagName(alignment);
            return std.mem.eql(u8, tag, "ender_chest") or
                   std.mem.eql(u8, tag, "honey_block") or
                   std.mem.eql(u8, tag, "top_slab") or
                   std.mem.eql(u8, tag, "aligned");
        }
        return false;
    }

    pub fn isWaterMedium(medium: anytype) bool {
        const T = @TypeOf(medium);
        if (T == bool) return medium;
        if (T == StreamMedium) return medium == .water_stream;
        if (@typeInfo(T) == .@"enum" or @typeInfo(T) == .enum_literal) {
            const tag = @tagName(medium);
            return std.mem.eql(u8, tag, "water") or
                   std.mem.eql(u8, tag, "water_stream") or
                   std.mem.eql(u8, tag, "flowing_water");
        }
        return false;
    }

    /// Computes the horizontal stream velocity in m/s for a dropped item entity.
    /// - Normal blocks in flowing water: ~1.8 m/s
    /// - Packed ice in flowing water: ~8.0 m/s
    /// - Blue ice sliding across gaps between aligned ender_chest / honey_block / top_slab water streams: ~12.0+ m/s (12.5 m/s)
    pub fn computeItemStreamVelocity(surface_in: anytype, alignment_in: anytype, medium_in: anytype) f32 {
        const surface = Self.parseSurface(surface_in);
        const aligned = Self.isAlignmentActive(alignment_in);
        const in_water = Self.isWaterMedium(medium_in);

        return switch (surface) {
            .blue_ice => if (aligned)
                Self.BLUE_ICE_ALIGNED_GAP_SPEED // 12.5 m/s (sliding across gap between aligned streams)
            else if (in_water)
                Self.BLUE_ICE_STREAM_SPEED // 12.0 m/s
            else
                4.0, // dry unaligned blue ice
            .packed_ice => if (in_water)
                (if (aligned) 8.5 else Self.PACKED_ICE_STREAM_SPEED) // 8.0 m/s
            else if (aligned)
                6.0
            else
                2.0,
            .ice => if (in_water)
                (if (aligned) 5.0 else Self.ICE_STREAM_SPEED) // 4.5 m/s
            else
                1.0,
            .normal => if (in_water)
                Self.NORMAL_BLOCK_STREAM_SPEED // 1.8 m/s
            else
                0.0,
        };
    }

    pub fn computeStreamVelocity(surface_in: anytype) f32 {
        return Self.computeItemStreamVelocity(surface_in, StreamAlignment.none, true);
    }
};

pub const computeItemStreamVelocity = WaterIceStreamTransport.computeItemStreamVelocity;
pub const computeStreamVelocity = WaterIceStreamTransport.computeStreamVelocity;

// ============================================================================
// 4. NetherStarExplosionImmunity & Hazard Destruction
// ============================================================================

pub const DamageSource = enum {
    cactus,
    explosion,
    fire,
    lava,
    void,
    lightning,
};

pub const NetherStarExplosionImmunity = struct {
    const Self = @This();

    /// Nether Star is completely immune to all explosions (including Wither death skulls).
    pub fn isNetherStarImmuneToExplosions() bool {
        return true;
    }

    /// ALL dropped items, including Netherite and Nether Stars, are destroyed by cactus!
    pub fn destroyedByCactus() bool {
        return true;
    }

    pub fn isDestroyedByCactus(item: anytype) bool {
        _ = item;
        return true;
    }

    pub fn isNetherite(item: anytype) bool {
        const T = @TypeOf(item);
        if (T == ItemType) {
            return switch (item) {
                .netherite_ingot,
                .netherite_scrap,
                .netherite_block,
                .netherite_sword,
                .netherite_pickaxe,
                .netherite_axe,
                .netherite_shovel,
                .netherite_hoe,
                .netherite_helmet,
                .netherite_chestplate,
                .netherite_leggings,
                .netherite_boots,
                .ancient_debris,
                => true,
                else => false,
            };
        }
        if (@typeInfo(T) == .@"enum" or @typeInfo(T) == .enum_literal) {
            const tag = @tagName(item);
            return std.mem.indexOf(u8, tag, "netherite") != null or
                   std.mem.eql(u8, tag, "ancient_debris");
        }
        return false;
    }

    pub fn isNetherStar(item: anytype) bool {
        const T = @TypeOf(item);
        if (T == ItemType) return item == .nether_star;
        if (@typeInfo(T) == .@"enum" or @typeInfo(T) == .enum_literal) {
            const tag = @tagName(item);
            return std.mem.eql(u8, tag, "nether_star");
        }
        return false;
    }

    pub fn isImmuneToExplosions(item: anytype) bool {
        return Self.isNetherStar(item) or Self.isNetherite(item);
    }

    pub fn isImmuneToFireAndLava(item: anytype) bool {
        return Self.isNetherite(item);
    }

    pub fn isDestroyedByFireOrLava(item: anytype) bool {
        return !Self.isImmuneToFireAndLava(item);
    }

    pub fn survivesExplosion(item: anytype) bool {
        return Self.isImmuneToExplosions(item);
    }

    pub fn survivesDamage(item: anytype, source: DamageSource) bool {
        return switch (source) {
            .cactus => false, // All items destroyed by cactus!
            .void => false,   // All items destroyed by void!
            .explosion => Self.isImmuneToExplosions(item),
            .fire, .lava => Self.isImmuneToFireAndLava(item),
            .lightning => Self.isImmuneToExplosions(item),
        };
    }

    pub fn isDestroyedBy(item: anytype, source: DamageSource) bool {
        return !Self.survivesDamage(item, source);
    }
};

pub const isNetherStarImmuneToExplosions = NetherStarExplosionImmunity.isNetherStarImmuneToExplosions;
pub const destroyedByCactus = NetherStarExplosionImmunity.destroyedByCactus;
pub const isDestroyedByCactus = NetherStarExplosionImmunity.isDestroyedByCactus;
pub const isNetherite = NetherStarExplosionImmunity.isNetherite;
pub const isNetherStar = NetherStarExplosionImmunity.isNetherStar;
pub const isImmuneToExplosions = NetherStarExplosionImmunity.isImmuneToExplosions;
pub const isImmuneToFireAndLava = NetherStarExplosionImmunity.isImmuneToFireAndLava;
pub const isDestroyedByFireOrLava = NetherStarExplosionImmunity.isDestroyedByFireOrLava;
pub const survivesExplosion = NetherStarExplosionImmunity.survivesExplosion;
pub const survivesDamage = NetherStarExplosionImmunity.survivesDamage;
pub const isDestroyedBy = NetherStarExplosionImmunity.isDestroyedBy;

// ============================================================================
// Dropped Item Entity
// ============================================================================

pub const ItemEntity = struct {
    id: u32 = 0,
    item: ItemType,
    count: u8,
    max_stack_size: u8 = 64,
    pos: [3]f32,
    vel: [3]f32 = .{ 0.0, 0.0, 0.0 },
    age_ticks: u16 = 0,
    pickup_delay_ticks: u8 = 10,
    health: u8 = 5,

    pub fn init(item: ItemType, count: u8, pos: [3]f32, source: DropSource) ItemEntity {
        return .{
            .item = item,
            .count = count,
            .max_stack_size = item.maxStackSize(),
            .pos = pos,
            .vel = .{ 0.0, 0.0, 0.0 },
            .age_ticks = 0,
            .pickup_delay_ticks = initialPickupDelay(source),
            .health = 5,
        };
    }

    pub fn initSimple(item: ItemType, count: u8, pos: [3]f32) ItemEntity {
        return init(item, count, pos, .block_drop);
    }

    pub fn canPickup(self: ItemEntity) bool {
        return self.pickup_delay_ticks == 0 and self.count > 0;
    }

    pub fn isDespawned(self: ItemEntity) bool {
        return shouldItemDespawnFor(self.item, self.age_ticks);
    }

    pub fn tick(self: *ItemEntity, chunk_loaded: bool) bool {
        return ItemDespawnLifecycle.tickItem(self, chunk_loaded);
    }

    pub fn tryMergeWith(self: *ItemEntity, other: *ItemEntity) bool {
        return tryMergeItemStacks(self, other);
    }

    pub fn applyDamage(self: *ItemEntity, source: DamageSource) bool {
        if (isDestroyedBy(self.item, source)) {
            self.count = 0;
            self.health = 0;
            return true; // Destroyed
        }
        return false; // Survived
    }

    pub fn destroyedByCactus(self: ItemEntity) bool {
        _ = self;
        return true;
    }

    pub fn distanceTo(self: ItemEntity, other: ItemEntity) f32 {
        const dx = self.pos[0] - other.pos[0];
        const dy = self.pos[1] - other.pos[1];
        const dz = self.pos[2] - other.pos[2];
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    pub fn horizontalDistanceTo(self: ItemEntity, other: ItemEntity) f32 {
        const dx = self.pos[0] - other.pos[0];
        const dz = self.pos[2] - other.pos[2];
        return @sqrt(dx * dx + dz * dz);
    }
};

// Simulation distance & chunk spatial helpers
pub fn chunkCoordinate(world_coord: f32) i32 {
    return @as(i32, @intFromFloat(@floor(world_coord / 16.0)));
}

pub fn isChunkLoaded(chunk_x: i32, chunk_z: i32, player_chunk_x: i32, player_chunk_z: i32, sim_distance_chunks: i32) bool {
    const dx = @abs(chunk_x - player_chunk_x);
    const dz = @abs(chunk_z - player_chunk_z);
    return dx <= sim_distance_chunks and dz <= sim_distance_chunks;
}

// ============================================================================
// Comprehensive Test Suite (16 Tests)
// ============================================================================

test "item despawn lifecycle - spawn pickup delays for block drops, mob loot, and player Q throw" {
    const block_drop = ItemEntity.init(.cobblestone, 1, .{ 0, 64, 0 }, .block_drop);
    const mob_drop = ItemEntity.init(.gold_ingot, 2, .{ 0, 64, 0 }, .mob_loot);
    const player_throw = ItemEntity.init(.diamond, 1, .{ 0, 64, 0 }, .player_throw);

    try std.testing.expectEqual(@as(u8, 10), block_drop.pickup_delay_ticks);
    try std.testing.expectEqual(@as(u8, 10), mob_drop.pickup_delay_ticks);
    try std.testing.expectEqual(@as(u8, 40), player_throw.pickup_delay_ticks);

    // Cannot pick up immediately
    try std.testing.expect(!block_drop.canPickup());
    try std.testing.expect(!mob_drop.canPickup());
    try std.testing.expect(!player_throw.canPickup());

    // Advance 10 loaded ticks
    var b = block_drop;
    var p = player_throw;
    for (0..10) |_| {
        _ = b.tick(true);
        _ = p.tick(true);
    }

    try std.testing.expectEqual(@as(u8, 0), b.pickup_delay_ticks);
    try std.testing.expect(b.canPickup());

    try std.testing.expectEqual(@as(u8, 30), p.pickup_delay_ticks);
    try std.testing.expect(!p.canPickup());

    // Advance remaining 30 loaded ticks for player throw
    for (0..30) |_| {
        _ = p.tick(true);
    }
    try std.testing.expectEqual(@as(u8, 0), p.pickup_delay_ticks);
    try std.testing.expect(p.canPickup());
}

test "item despawn lifecycle - 6000 tick / 5 minute threshold and shouldItemDespawn" {
    try std.testing.expectEqual(@as(u16, 6000), max_item_age_ticks);
    try std.testing.expectEqual(@as(f32, 20.0), ItemDespawnLifecycle.ticks_per_second);
    try std.testing.expectEqual(@as(f32, 300.0), ItemDespawnLifecycle.despawn_time_seconds);

    try std.testing.expect(!shouldItemDespawn(0));
    try std.testing.expect(!shouldItemDespawn(1000));
    try std.testing.expect(!shouldItemDespawn(5999));
    try std.testing.expect(shouldItemDespawn(6000));
    try std.testing.expect(shouldItemDespawn(6001));
    try std.testing.expect(shouldItemDespawn(10000));
}

test "item despawn lifecycle - chunk loading rule prevents aging when chunk is unloaded" {
    try std.testing.expect(!ticksWhenChunkUnloaded());

    var item = ItemEntity.initSimple(.diamond, 3, .{ 100, 64, 100 });
    try std.testing.expectEqual(@as(u16, 0), item.age_ticks);
    try std.testing.expectEqual(@as(u8, 10), item.pickup_delay_ticks);

    // Advance 5000 ticks while chunk is unloaded
    for (0..5000) |_| {
        const despawned = item.tick(false);
        try std.testing.expect(!despawned);
    }

    // Nothing aged, pickup delay was frozen
    try std.testing.expectEqual(@as(u16, 0), item.age_ticks);
    try std.testing.expectEqual(@as(u8, 10), item.pickup_delay_ticks);
    try std.testing.expect(!item.canPickup());

    // Chunk becomes loaded for 10 ticks
    for (0..10) |_| {
        _ = item.tick(true);
    }
    try std.testing.expectEqual(@as(u16, 10), item.age_ticks);
    try std.testing.expectEqual(@as(u8, 0), item.pickup_delay_ticks);
    try std.testing.expect(item.canPickup());
}

test "item despawn lifecycle - death drop 2000 blocks away never despawns while unloaded" {
    const death_x: f32 = 2000.0;
    const death_z: f32 = 2000.0;
    const spawn_x: f32 = 0.0;
    const spawn_z: f32 = 0.0;
    const sim_distance_chunks: i32 = 10; // 160 blocks simulation distance

    const death_chunk_x = chunkCoordinate(death_x);
    const death_chunk_z = chunkCoordinate(death_z);
    const spawn_chunk_x = chunkCoordinate(spawn_x);
    const spawn_chunk_z = chunkCoordinate(spawn_z);

    // Death chunk is far outside simulation distance of spawn
    try std.testing.expect(!isChunkLoaded(death_chunk_x, death_chunk_z, spawn_chunk_x, spawn_chunk_z, sim_distance_chunks));

    var dropped_gear = ItemEntity.init(.netherite_sword, 1, .{ death_x, 64.0, death_z }, .death_drop);
    var dropped_ore = ItemEntity.init(.diamond, 32, .{ death_x, 64.0, death_z }, .death_drop);

    // Player spends 100,000 game ticks (~83 minutes) building at spawn
    for (0..100_000) |_| {
        const loaded = isChunkLoaded(death_chunk_x, death_chunk_z, spawn_chunk_x, spawn_chunk_z, sim_distance_chunks);
        _ = dropped_gear.tick(loaded);
        _ = dropped_ore.tick(loaded);
    }

    // Items 2000 blocks away never aged a single tick!
    try std.testing.expectEqual(@as(u16, 0), dropped_gear.age_ticks);
    try std.testing.expectEqual(@as(u16, 0), dropped_ore.age_ticks);
    try std.testing.expect(!dropped_gear.isDespawned());
    try std.testing.expect(!dropped_ore.isDespawned());

    // Player travels back to (1950, 64, 1950) -> chunk is now within simulation distance!
    const nearby_chunk_x = chunkCoordinate(1950.0);
    const nearby_chunk_z = chunkCoordinate(1950.0);
    try std.testing.expect(isChunkLoaded(death_chunk_x, death_chunk_z, nearby_chunk_x, nearby_chunk_z, sim_distance_chunks));

    // Now the death chunk simulates and items begin aging
    for (0..6000) |_| {
        _ = dropped_ore.tick(true);
    }
    try std.testing.expect(dropped_ore.isDespawned());
}

test "item stack clumping - merge radius 0.5 horizontal and vertical boundary tests" {
    const center = [3]f32{ 10.0, 64.0, 10.0 };

    // Exactly at 0.5 boundary
    try std.testing.expect(isWithinMergeRadius(center, .{ 10.5, 64.0, 10.0 }));
    try std.testing.expect(isWithinMergeRadius(center, .{ 9.5, 64.0, 10.0 }));
    try std.testing.expect(isWithinMergeRadius(center, .{ 10.0, 64.5, 10.0 }));
    try std.testing.expect(isWithinMergeRadius(center, .{ 10.0, 63.5, 10.0 }));
    try std.testing.expect(isWithinMergeRadius(center, .{ 10.0, 64.0, 10.5 }));
    try std.testing.expect(isWithinMergeRadius(center, .{ 10.0, 64.0, 9.5 }));

    // Just beyond 0.5 boundary
    try std.testing.expect(!isWithinMergeRadius(center, .{ 10.52, 64.0, 10.0 }));
    try std.testing.expect(!isWithinMergeRadius(center, .{ 9.48, 64.0, 10.0 }));
    try std.testing.expect(!isWithinMergeRadius(center, .{ 10.0, 64.52, 10.0 }));
    try std.testing.expect(!isWithinMergeRadius(center, .{ 10.0, 63.48, 10.0 }));
    try std.testing.expect(!isWithinMergeRadius(center, .{ 10.0, 64.0, 10.52 }));
}

test "item stack clumping - successful merge of identical item types within max_stack_size" {
    var target = ItemEntity.initSimple(.cobblestone, 16, .{ 5.0, 64.0, 5.0 });
    var source = ItemEntity.initSimple(.cobblestone, 24, .{ 5.2, 64.1, 5.1 });
    target.age_ticks = 4000;
    source.age_ticks = 800;

    try std.testing.expect(tryMergeItemStacks(&target, &source));
    try std.testing.expectEqual(@as(u8, 40), target.count);
    try std.testing.expectEqual(@as(u8, 0), source.count);
    // Inherits younger age (800 < 4000)
    try std.testing.expectEqual(@as(u16, 800), target.age_ticks);
}

test "item stack clumping - rejects merge when total_count exceeds max_stack_size or different item type" {
    // 1. Exceeds max stack size (45 + 30 = 75 > 64)
    var stack_a = ItemEntity.initSimple(.sand, 45, .{ 0, 64, 0 });
    var stack_b = ItemEntity.initSimple(.sand, 30, .{ 0.2, 64.0, 0 });
    try std.testing.expect(!tryMergeItemStacks(&stack_a, &stack_b));
    try std.testing.expectEqual(@as(u8, 45), stack_a.count);
    try std.testing.expectEqual(@as(u8, 30), stack_b.count);

    // 2. Different item types (dirt vs stone)
    var stack_dirt = ItemEntity.initSimple(.dirt, 10, .{ 0, 64, 0 });
    var stack_stone = ItemEntity.initSimple(.stone, 10, .{ 0.2, 64.0, 0 });
    try std.testing.expect(!tryMergeItemStacks(&stack_dirt, &stack_stone));
    try std.testing.expectEqual(@as(u8, 10), stack_dirt.count);
    try std.testing.expectEqual(@as(u8, 10), stack_stone.count);

    // 3. Unstackable items (swords have max_stack_size = 1)
    var sword_a = ItemEntity.initSimple(.diamond_sword, 1, .{ 0, 64, 0 });
    var sword_b = ItemEntity.initSimple(.diamond_sword, 1, .{ 0.2, 64.0, 0 });
    try std.testing.expect(!tryMergeItemStacks(&sword_a, &sword_b));
}

test "item stack clumping - merged stack inherits younger age resetting despawn timer" {
    try std.testing.expectEqual(@as(u16, 120), mergedAgeTicks(5800, 120));
    try std.testing.expectEqual(@as(u16, 300), mergedAgeTicks(300, 4900));
    try std.testing.expectEqual(@as(u16, 500), mergedAgeTicks(500, 500));

    // Old stack about to despawn (age 5950, 2.5 seconds left)
    var dying_stack = ItemEntity.initSimple(.iron_ingot, 5, .{ 12.0, 64.0, 12.0 });
    dying_stack.age_ticks = 5950;

    // Fresh stack dropped (age 50)
    var fresh_stack = ItemEntity.initSimple(.iron_ingot, 10, .{ 12.2, 64.0, 12.1 });
    fresh_stack.age_ticks = 50;

    try std.testing.expect(dying_stack.tryMergeWith(&fresh_stack));
    try std.testing.expectEqual(@as(u8, 15), dying_stack.count);
    try std.testing.expectEqual(@as(u16, 50), dying_stack.age_ticks);

    // The entire stack now has 5950 more ticks (almost 5 full minutes) to live!
    try std.testing.expect(!dying_stack.isDespawned());
}

test "water ice stream transport - normal blocks reach ~1.8 m/s in flowing water" {
    const v_normal = computeItemStreamVelocity(StreamSurface.normal, StreamAlignment.none, true);
    try std.testing.expectApproxEqAbs(@as(f32, 1.8), v_normal, 0.01);

    // With BlockId
    const v_block = computeItemStreamVelocity(BlockId.stone, StreamAlignment.none, true);
    try std.testing.expectApproxEqAbs(@as(f32, 1.8), v_block, 0.01);

    // Dry normal block (no water) has 0 push
    const v_dry = computeItemStreamVelocity(StreamSurface.normal, StreamAlignment.none, false);
    try std.testing.expectEqual(@as(f32, 0.0), v_dry);
}

test "water ice stream transport - packed ice reaches ~8.0 m/s in flowing water" {
    const v_packed = computeItemStreamVelocity(StreamSurface.packed_ice, StreamAlignment.none, true);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), v_packed, 0.01);

    // With BlockId
    const v_block = computeItemStreamVelocity(BlockId.packed_ice, false, true);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), v_block, 0.01);

    // Aligned packed ice stream
    const v_aligned = computeItemStreamVelocity(StreamSurface.packed_ice, true, true);
    try std.testing.expect(v_aligned >= 8.0);
}

test "water ice stream transport - blue ice sliding across gap between aligned ender chest / honey block / top slab streams reaches ~12.0+ m/s" {
    // Aligned with ender chest sliding across dry gap between streams
    const v_ender = computeItemStreamVelocity(StreamSurface.blue_ice, StreamAlignment.ender_chest, false);
    try std.testing.expect(v_ender >= 12.0);
    try std.testing.expectApproxEqAbs(@as(f32, 12.5), v_ender, 0.01);

    // Aligned with honey block sliding across dry gap
    const v_honey = computeItemStreamVelocity(StreamSurface.blue_ice, StreamAlignment.honey_block, false);
    try std.testing.expect(v_honey >= 12.0);
    try std.testing.expectApproxEqAbs(@as(f32, 12.5), v_honey, 0.01);

    // Aligned with top slab sliding across dry gap
    const v_slab = computeItemStreamVelocity(StreamSurface.blue_ice, StreamAlignment.top_slab, false);
    try std.testing.expect(v_slab >= 12.0);
    try std.testing.expectApproxEqAbs(@as(f32, 12.5), v_slab, 0.01);

    // Unaligned blue ice water stream
    const v_blue_stream = computeItemStreamVelocity(StreamSurface.blue_ice, StreamAlignment.none, true);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), v_blue_stream, 0.01);
}

test "nether star blast immunity - immune to all explosions and withstands wither skull blasts" {
    try std.testing.expect(isNetherStarImmuneToExplosions());
    try std.testing.expect(survivesExplosion(ItemType.nether_star));
    try std.testing.expect(survivesDamage(ItemType.nether_star, .explosion));

    var star_entity = ItemEntity.initSimple(.nether_star, 1, .{ 0, 64, 0 });
    const damaged = star_entity.applyDamage(.explosion);
    try std.testing.expect(!damaged); // Survived
    try std.testing.expectEqual(@as(u8, 1), star_entity.count);

    // Nether star takes 10.0 minutes (12000 ticks) to despawn
    try std.testing.expectEqual(@as(u16, 12000), maxAgeTicksFor(ItemType.nether_star));
    try std.testing.expect(!shouldItemDespawnFor(ItemType.nether_star, 6000));
    try std.testing.expect(!shouldItemDespawnFor(ItemType.nether_star, 11999));
    try std.testing.expect(shouldItemDespawnFor(ItemType.nether_star, 12000));
}

test "netherite gear hazard resistance - immune to fire, lava, and explosions" {
    const netherite_items = [_]ItemType{
        .netherite_ingot,
        .netherite_scrap,
        .netherite_sword,
        .netherite_pickaxe,
        .netherite_axe,
        .netherite_shovel,
        .netherite_hoe,
        .netherite_helmet,
        .netherite_chestplate,
        .netherite_leggings,
        .netherite_boots,
        .ancient_debris,
    };

    for (netherite_items) |item| {
        try std.testing.expect(isNetherite(item));
        try std.testing.expect(isImmuneToFireAndLava(item));
        try std.testing.expect(isImmuneToExplosions(item));
        try std.testing.expect(survivesDamage(item, .fire));
        try std.testing.expect(survivesDamage(item, .lava));
        try std.testing.expect(survivesDamage(item, .explosion));
    }
}

test "cactus destruction - destroys all dropped items unconditionally including netherite and nether stars" {
    try std.testing.expect(destroyedByCactus());
    try std.testing.expect(isDestroyedByCactus(ItemType.stone));
    try std.testing.expect(isDestroyedByCactus(ItemType.netherite_ingot));
    try std.testing.expect(isDestroyedByCactus(ItemType.netherite_sword));
    try std.testing.expect(isDestroyedByCactus(ItemType.nether_star));

    // Cactus damages and destroys Netherite
    try std.testing.expect(!survivesDamage(ItemType.netherite_ingot, .cactus));
    try std.testing.expect(isDestroyedBy(ItemType.netherite_ingot, .cactus));

    // Cactus damages and destroys Nether Star
    try std.testing.expect(!survivesDamage(ItemType.nether_star, .cactus));
    try std.testing.expect(isDestroyedBy(ItemType.nether_star, .cactus));

    var star = ItemEntity.initSimple(.nether_star, 1, .{ 0, 64, 0 });
    try std.testing.expect(star.destroyedByCactus());
    const destroyed = star.applyDamage(.cactus);
    try std.testing.expect(destroyed);
    try std.testing.expectEqual(@as(u8, 0), star.count);
}

test "hazard destruction rules - non-netherite items destroyed by fire, lava, and explosions" {
    const vulnerable_items = [_]ItemType{
        .diamond,
        .iron_ingot,
        .gold_ingot,
        .cobblestone,
        .wood,
    };

    for (vulnerable_items) |item| {
        try std.testing.expect(!isNetherite(item));
        try std.testing.expect(isDestroyedByFireOrLava(item));
        try std.testing.expect(!survivesDamage(item, .fire));
        try std.testing.expect(!survivesDamage(item, .lava));
        try std.testing.expect(!survivesDamage(item, .explosion));
        try std.testing.expect(!survivesDamage(item, .cactus));
        try std.testing.expect(!survivesDamage(item, .void));
    }

    // Nether Star survives explosions, but is vulnerable to fire, lava, cactus, and void
    try std.testing.expect(survivesDamage(ItemType.nether_star, .explosion));
    try std.testing.expect(!survivesDamage(ItemType.nether_star, .fire));
    try std.testing.expect(!survivesDamage(ItemType.nether_star, .lava));
    try std.testing.expect(!survivesDamage(ItemType.nether_star, .cactus));
    try std.testing.expect(!survivesDamage(ItemType.nether_star, .void));
}

test "full dropped item simulation - water stream transport, stack clumping age reset, and despawn cycle" {
    // 1. Water stream transport across blue ice aligned with ender chest
    const speed = computeItemStreamVelocity(StreamSurface.blue_ice, StreamAlignment.ender_chest, false);
    try std.testing.expect(speed >= 12.0);

    // 2. Item A travels along stream, accumulating 3000 ticks of age
    var item_a = ItemEntity.init(.diamond, 5, .{ 0.0, 64.0, 0.0 }, .player_throw);
    item_a.age_ticks = 3000;
    item_a.pickup_delay_ticks = 0;

    // 3. Item B dropped recently at end of stream (age 200, count 10)
    var item_b = ItemEntity.initSimple(.diamond, 10, .{ 0.3, 64.0, 0.2 });
    item_b.age_ticks = 200;

    // 4. They clump together
    try std.testing.expect(item_a.tryMergeWith(&item_b));
    try std.testing.expectEqual(@as(u8, 15), item_a.count);
    try std.testing.expectEqual(@as(u8, 0), item_b.count);
    try std.testing.expectEqual(@as(u16, 200), item_a.age_ticks); // Younger age inherited!

    // 5. Simulate aging until despawn
    for (0..5799) |_| {
        _ = item_a.tick(true);
    }
    try std.testing.expectEqual(@as(u16, 5999), item_a.age_ticks);
    try std.testing.expect(!item_a.isDespawned());

    // 6. Final tick hits 6000 and despawns
    const despawned = item_a.tick(true);
    try std.testing.expect(despawned);
    try std.testing.expectEqual(@as(u16, 6000), item_a.age_ticks);
    try std.testing.expect(item_a.isDespawned());
}
