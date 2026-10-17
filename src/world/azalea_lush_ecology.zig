const std = @import("std");

// ============================================================================
// Block and Item Type Definitions
// ============================================================================

/// Identifiers for blocks relevant to Azalea trees, Lush Caves, and moss ecology.
pub const BlockType = enum(u16) {
    air = 0,
    oak_log = 1,
    azalea_leaves = 2,
    flowering_azalea_leaves = 3,
    rooted_dirt = 4,
    hanging_roots = 5,
    dirt = 6,
    moss_block = 7,
    moss_carpet = 8,
    azalea = 9,
    flowering_azalea = 10,
    grass = 11,
    stone = 12,
    deepslate = 13,
    tuff = 14,
    granite = 15,
    diorite = 16,
    andesite = 17,
    coarse_dirt = 18,
    mycelium = 19,
    podzol = 20,
    big_dripleaf = 21,
    spore_blossom = 22,
    bedrock = 23,
    clay = 24,
    cave_vines = 25,
    sand = 26,
    gravel = 27,
    obsidian = 28,
    water = 29,
    lava = 30,

    /// Whether this block represents a solid structural barrier for attachment or walking.
    pub fn isSolid(self: BlockType) bool {
        return switch (self) {
            .air,
            .moss_carpet,
            .hanging_roots,
            .azalea,
            .flowering_azalea,
            .grass,
            .spore_blossom,
            .cave_vines,
            .water,
            .lava,
            => false,
            // Big Dripleaf has dynamic collision based on tilt state; as a block type it is non-full-solid.
            .big_dripleaf => false,
            else => true,
        };
    }
};

/// Items yielded by interaction or farming in lush cave ecology.
pub const ItemType = enum(u16) {
    hanging_roots = 1,
    dirt = 2,
    rooted_dirt = 3,
    azalea = 4,
    flowering_azalea = 5,
    moss_block = 6,
    moss_carpet = 7,
    spore_blossom = 8,
    big_dripleaf = 9,
    bone_meal = 10,
    hoe = 11,
};

/// World space placement record.
pub const PlacedBlock = struct {
    x: i32,
    y: i32,
    z: i32,
    block: BlockType,
};

// ============================================================================
// 1. AzaleaTreeIndicator
// ============================================================================

/// Represents a surface Azalea Tree that serves as a direct vertical indicator
/// of an underground Lush Cave biome.
///
/// Features:
/// - Surface tree composed of `oak_log` trunk, `azalea_leaves`, and `flowering_azalea_leaves`.
/// - Vertical indicator column of `rooted_dirt` descending through stone/dirt down to the lush cave.
/// - When penetrating the lush cave ceiling, generates `hanging_roots` dangling into the open cave air.
/// - `indicatesLushCaveBelow()` returns true, confirming lush cave presence.
pub const AzaleaTreeIndicator = struct {
    surface_x: i32 = 0,
    surface_y: i32 = 64,
    surface_z: i32 = 0,
    cave_ceiling_y: i32 = 20,
    trunk_height: u8 = 4,
    has_lush_cave_below: bool = true,

    pub fn init(surface_x: i32, surface_y: i32, surface_z: i32, cave_ceiling_y: i32) AzaleaTreeIndicator {
        return .{
            .surface_x = surface_x,
            .surface_y = surface_y,
            .surface_z = surface_z,
            .cave_ceiling_y = cave_ceiling_y,
            .trunk_height = 4,
            .has_lush_cave_below = true,
        };
    }

    /// Confirms that an Azalea Tree on the surface indicates a Lush Cave underground.
    pub fn indicatesLushCaveBelow(self: AzaleaTreeIndicator) bool {
        return self.has_lush_cave_below;
    }

    /// Depth in blocks from the surface root base down to the lush cave ceiling.
    pub fn rootColumnDepth(self: AzaleaTreeIndicator) u32 {
        if (self.surface_y <= self.cave_ceiling_y) return 0;
        return @intCast(self.surface_y - self.cave_ceiling_y);
    }

    /// Generates the above-ground tree structure: oak_log trunk with azalea_leaves
    /// and flowering_azalea_leaves canopy.
    /// Returns the number of blocks written to buffer.
    pub fn generateTree(self: AzaleaTreeIndicator, buffer: []PlacedBlock) usize {
        var count: usize = 0;

        // 1. Oak log trunk (from surface_y up for trunk_height)
        var y: i32 = self.surface_y;
        while (y < self.surface_y + @as(i32, self.trunk_height)) : (y += 1) {
            if (count < buffer.len) {
                buffer[count] = .{
                    .x = self.surface_x,
                    .y = y,
                    .z = self.surface_z,
                    .block = .oak_log,
                };
                count += 1;
            }
        }

        // 2. Canopy leaves around and atop the trunk
        const top_trunk_y = self.surface_y + @as(i32, self.trunk_height) - 1;
        var dy: i32 = -1;
        while (dy <= 2) : (dy += 1) {
            const layer_y = top_trunk_y + dy;
            const radius: i32 = if (dy == 2) 1 else if (dy == -1) 2 else 3;

            var dx: i32 = -radius;
            while (dx <= radius) : (dx += 1) {
                var dz: i32 = -radius;
                while (dz <= radius) : (dz += 1) {
                    // Skip center if trunk already occupies it
                    if (dx == 0 and dz == 0 and dy <= 0) continue;

                    // Approximate rounded dome shape
                    if (dx * dx + dz * dz <= radius * radius + 1) {
                        if (count < buffer.len) {
                            // ~25% flowering azalea leaves, ~75% regular azalea leaves
                            const is_flowering = @mod(dx * 3 + dz * 5 + dy * 7 + 100, 4) == 0;
                            buffer[count] = .{
                                .x = self.surface_x + dx,
                                .y = layer_y,
                                .z = self.surface_z + dz,
                                .block = if (is_flowering) .flowering_azalea_leaves else .azalea_leaves,
                            };
                            count += 1;
                        }
                    }
                }
            }
        }

        return count;
    }

    /// Generates the vertical root column descending from surface_y - 1 down to the cave.
    /// Fills the column with `rooted_dirt`.
    /// When it reaches the open cave below `cave_ceiling_y`, places `hanging_roots` at `cave_ceiling_y - 1`.
    /// Returns the number of blocks written to buffer.
    pub fn generateRootColumn(self: AzaleaTreeIndicator, buffer: []PlacedBlock) usize {
        var count: usize = 0;
        if (self.surface_y <= self.cave_ceiling_y) return 0;

        // Column of rooted dirt replacing underground blocks
        var y: i32 = self.surface_y - 1;
        while (y >= self.cave_ceiling_y) : (y -= 1) {
            if (count < buffer.len) {
                buffer[count] = .{
                    .x = self.surface_x,
                    .y = y,
                    .z = self.surface_z,
                    .block = .rooted_dirt,
                };
                count += 1;
            }
        }

        // Hanging roots dangling down from the cave ceiling into the cave air
        if (count < buffer.len) {
            buffer[count] = .{
                .x = self.surface_x,
                .y = self.cave_ceiling_y - 1,
                .z = self.surface_z,
                .block = .hanging_roots,
            };
            count += 1;
        }

        return count;
    }
};

/// Global free-function indicator check.
pub fn indicatesLushCaveBelow() bool {
    return true;
}

// ============================================================================
// 2. RootedDirtMechanics
// ============================================================================

/// Mechanics for interaction with Rooted Dirt:
/// - Tilling rooted dirt with a Hoe converts it to regular `dirt` and drops `1` `hanging_roots` item.
/// - Applying Bone Meal to rooted dirt when the block below is `air` grows `hanging_roots` underneath.
pub const RootedDirtMechanics = struct {
    pub const TillResult = struct {
        success: bool,
        converted_block: BlockType,
        dropped_item: ?ItemType,
        dropped_count: u8,
    };

    /// Using a Hoe on rooted_dirt converts it to regular dirt and pops out 1 hanging_roots item.
    pub fn tillRootedDirtWithHoe() TillResult {
        return .{
            .success = true,
            .converted_block = .dirt,
            .dropped_item = .hanging_roots,
            .dropped_count = 1,
        };
    }

    /// Tills any given block. If it is rooted_dirt, converts to dirt and drops 1 hanging_roots.
    pub fn tillBlockWithHoe(block: BlockType) TillResult {
        if (block == .rooted_dirt) {
            return RootedDirtMechanics.tillRootedDirtWithHoe();
        }
        return .{
            .success = false,
            .converted_block = block,
            .dropped_item = null,
            .dropped_count = 0,
        };
    }

    /// Applying Bone Meal to rooted_dirt when the block below is air grows hanging_roots underneath.
    pub fn applyBoneMealToRootedDirt(below_is_air: bool) bool {
        return below_is_air;
    }

    /// Returns the block to place underneath rooted_dirt when bone meal succeeds.
    pub fn getUnderneathGrownBlock(below_is_air: bool) ?BlockType {
        if (below_is_air) return .hanging_roots;
        return null;
    }
};

/// Free-function wrapper for tilling rooted dirt with a hoe.
pub fn tillRootedDirtWithHoe() RootedDirtMechanics.TillResult {
    return RootedDirtMechanics.tillRootedDirtWithHoe();
}

/// Free-function wrapper for bone meal application to rooted dirt.
pub fn applyBoneMealToRootedDirt(below_is_air: bool) bool {
    return RootedDirtMechanics.applyBoneMealToRootedDirt(below_is_air);
}

// ============================================================================
// 3. MossBoneMealSpread
// ============================================================================

/// Checks whether a block name matches one of the replaceable natural stone/dirt types:
/// `stone`, `deepslate`, `tuff`, `granite`, `diorite`, `andesite`, `dirt`, `coarse_dirt`, `mycelium`, `podzol`.
pub fn isReplaceableBlockName(name: []const u8) bool {
    const replaceable_names = [_][]const u8{
        "stone",
        "deepslate",
        "tuff",
        "granite",
        "diorite",
        "andesite",
        "dirt",
        "coarse_dirt",
        "mycelium",
        "podzol",
    };
    for (replaceable_names) |target| {
        if (std.mem.eql(u8, name, target)) return true;
    }
    return false;
}

/// Checks whether a block can be replaced by moss spread when bone meal is applied.
/// Supports `BlockType`, any enum type (like `BlockId`), enum literals (e.g. `.stone`), and string slices/literals.
pub fn canMossReplaceBlock(block_kind: anytype) bool {
    const T = @TypeOf(block_kind);
    if (@typeInfo(T) == .@"enum" or @typeInfo(T) == .enum_literal) {
        const name = @tagName(block_kind);
        return isReplaceableBlockName(name);
    }
    if (@typeInfo(T) == .pointer) {
        const ptr_info = @typeInfo(T).pointer;
        if (ptr_info.size == .slice and ptr_info.child == u8) {
            return isReplaceableBlockName(block_kind);
        }
        if (ptr_info.size == .one and @typeInfo(ptr_info.child) == .array and @typeInfo(ptr_info.child).array.child == u8) {
            const slice: []const u8 = block_kind;
            return isReplaceableBlockName(slice);
        }
    }
    return false;
}

/// Mechanics for applying Bone Meal to a Moss Block:
/// - Target must be `moss_block` with `air` above it.
/// - Converts replaceable natural stone/dirt blocks in up to a `7x11x7` neighborhood into `moss_block`.
/// - Spawns vegetation (`moss_carpet`, `azalea`, `flowering_azalea`, `grass`) on top of converted or existing moss.
pub const MossBoneMealSpread = struct {
    pub const spread_width: i32 = 7;
    pub const spread_height: i32 = 11;
    pub const spread_depth: i32 = 7;
    pub const radius_x: i32 = 3;
    pub const radius_z: i32 = 3;
    pub const radius_y: i32 = 5;

    pub const VegetationType = enum(u8) {
        none = 0,
        moss_carpet = 1,
        azalea = 2,
        flowering_azalea = 3,
        grass = 4,

        pub fn toBlockType(self: VegetationType) ?BlockType {
            return switch (self) {
                .none => null,
                .moss_carpet => .moss_carpet,
                .azalea => .azalea,
                .flowering_azalea => .flowering_azalea,
                .grass => .grass,
            };
        }
    };

    /// Checks if a block is replaceable by moss terraforming.
    pub fn canMossReplaceBlock(block_kind: anytype) bool {
        return @import("azalea_lush_ecology.zig").canMossReplaceBlock(block_kind);
    }

    /// Bone meal can only be applied to a moss block if the space directly above is air.
    pub fn canApplyBoneMeal(target_block: BlockType, above_is_air: bool) bool {
        return (target_block == .moss_block) and above_is_air;
    }

    /// Checks whether an offset (dx, dy, dz) lies within the 7x11x7 spread neighborhood.
    pub fn isInSpreadNeighborhood(dx: i32, dy: i32, dz: i32) bool {
        return (@abs(dx) <= radius_x) and (@abs(dy) <= radius_y) and (@abs(dz) <= radius_z);
    }

    /// Deterministic vegetation selection atop moss blocks based on a roll (0..99).
    pub fn pickVegetation(roll: u8) VegetationType {
        const val = roll % 100;
        if (val < 40) {
            return .grass;
        } else if (val < 65) {
            return .moss_carpet;
        } else if (val < 80) {
            return .azalea;
        } else if (val < 90) {
            return .flowering_azalea;
        } else {
            return .none;
        }
    }
};

// ============================================================================
// 4. DripleafTiltState
// ============================================================================

/// Tilt stages for Big Dripleaf.
pub const TiltStage = enum(u8) {
    un_tilted = 0,
    unstable = 1,
    partial_tilt = 2,
    full_tilt_pass_through = 3,
};

/// State machine for Big Dripleaf tilt mechanics:
/// - When stood upon: `un_tilted` -> `unstable` (0.5s / 10 ticks) -> `partial_tilt` (0.5s / 10 ticks) -> `full_tilt_pass_through` (5.0s / 100 ticks).
/// - When in `full_tilt_pass_through`, entities fall through it (pass-through / non-solid).
/// - Powered by Redstone locks it horizontally stable (`isLockedByRedstone: bool`), preventing tilt!
/// - Hitting with a projectile immediately collapses it to `full_tilt_pass_through`.
pub const DripleafTiltState = struct {
    pub const unstable_ticks: u32 = 10; // 0.5s at 20 tps
    pub const partial_tilt_ticks: u32 = 10; // 0.5s at 20 tps
    pub const full_tilt_ticks: u32 = 100; // 5.0s at 20 tps

    pub const unstable_duration_seconds: f32 = 0.5;
    pub const partial_tilt_duration_seconds: f32 = 0.5;
    pub const full_tilt_duration_seconds: f32 = 5.0;

    stage: TiltStage = .un_tilted,
    ticks_in_stage: u32 = 0,
    isLockedByRedstone: bool = false,

    pub fn init() DripleafTiltState {
        return .{
            .stage = .un_tilted,
            .ticks_in_stage = 0,
            .isLockedByRedstone = false,
        };
    }

    pub fn initWithRedstone(locked: bool) DripleafTiltState {
        return .{
            .stage = .un_tilted,
            .ticks_in_stage = 0,
            .isLockedByRedstone = locked,
        };
    }

    /// Whether entities can pass through this dripleaf.
    /// True only in `full_tilt_pass_through`.
    pub fn canPassThrough(self: DripleafTiltState) bool {
        return self.stage == .full_tilt_pass_through;
    }

    /// Whether the dripleaf has solid top collision.
    pub fn isSolid(self: DripleafTiltState) bool {
        return self.stage != .full_tilt_pass_through;
    }

    /// Hitting a Big Dripleaf with a projectile immediately collapses it to full_tilt_pass_through,
    /// unless locked stable by redstone power.
    pub fn hitWithProjectile(self: *DripleafTiltState) void {
        if (self.isLockedByRedstone) return;
        self.stage = .full_tilt_pass_through;
        self.ticks_in_stage = 0;
    }

    pub fn hitByProjectile(self: *DripleafTiltState) void {
        self.hitWithProjectile();
    }

    /// Updates the tilt state by one game tick (1/20 sec).
    /// - has_entity: true if a player or mob is standing on the leaf.
    /// - redstone_powered: true if powered by redstone signal.
    pub fn tick(self: *DripleafTiltState, has_entity: bool, redstone_powered: bool) void {
        self.isLockedByRedstone = redstone_powered;

        // Redstone power locks it horizontally stable and resets any ongoing tilt
        if (self.isLockedByRedstone) {
            self.stage = .un_tilted;
            self.ticks_in_stage = 0;
            return;
        }

        switch (self.stage) {
            .un_tilted => {
                if (has_entity) {
                    self.stage = .unstable;
                    self.ticks_in_stage = 1;
                }
            },
            .unstable => {
                if (!has_entity) {
                    // Stepping off before collapsing restores stability
                    self.stage = .un_tilted;
                    self.ticks_in_stage = 0;
                } else {
                    self.ticks_in_stage += 1;
                    if (self.ticks_in_stage >= unstable_ticks) {
                        self.stage = .partial_tilt;
                        self.ticks_in_stage = 0;
                    }
                }
            },
            .partial_tilt => {
                if (!has_entity) {
                    // Stepping off restores stability
                    self.stage = .un_tilted;
                    self.ticks_in_stage = 0;
                } else {
                    self.ticks_in_stage += 1;
                    if (self.ticks_in_stage >= partial_tilt_ticks) {
                        self.stage = .full_tilt_pass_through;
                        self.ticks_in_stage = 0;
                    }
                }
            },
            .full_tilt_pass_through => {
                // In full tilt, entities fall through. It recovers after 100 ticks (5.0s).
                self.ticks_in_stage += 1;
                if (self.ticks_in_stage >= full_tilt_ticks) {
                    self.stage = .un_tilted;
                    self.ticks_in_stage = 0;
                }
            },
        }
    }
};

// ============================================================================
// 5. SporeBlossom
// ============================================================================

/// Particle emitted by Spore Blossom raining down into ambient air volume.
pub const SporeParticle = struct {
    x: f32,
    y: f32,
    z: f32,
    vel_y: f32 = -0.05,
    lifetime_ticks: u32 = 60,
    r: f32 = 0.25,
    g: f32 = 0.70,
    b: f32 = 0.25,

    pub fn isGreen(self: SporeParticle) bool {
        return self.g > self.r and self.g > self.b;
    }

    pub fn tick(self: *SporeParticle) bool {
        self.y += self.vel_y;
        if (self.lifetime_ticks == 0) return false;
        self.lifetime_ticks -= 1;
        return self.lifetime_ticks > 0;
    }
};

/// Spore Blossom ceiling flora mechanics:
/// - Attaches exclusively to the underside of solid blocks into air.
/// - Rains green spore particles downward.
/// - Fills a 32x32x32 ambient air volume with floating particles.
pub const SporeBlossom = struct {
    pub const ambient_volume_width: i32 = 32;
    pub const ambient_volume_height: i32 = 32;
    pub const ambient_volume_depth: i32 = 32;
    pub const ambient_volume_radius: i32 = 16;

    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,

    pub fn init(x: i32, y: i32, z: i32) SporeBlossom {
        return .{ .x = x, .y = y, .z = z };
    }

    /// Attaches exclusively to the underside of solid blocks when the target position is air.
    pub fn canAttachSporeBlossom(block_above_is_solid: bool, target_is_air: bool) bool {
        return block_above_is_solid and target_is_air;
    }

    /// Checks if a position is within the 32x32x32 ambient particle air volume centered on this blossom.
    pub fn isInAmbientVolume(self: SporeBlossom, px: i32, py: i32, pz: i32) bool {
        const dx = @abs(px - self.x);
        const dy = @abs(py - self.y);
        const dz = @abs(pz - self.z);
        return (dx <= ambient_volume_radius) and (dy <= ambient_volume_radius) and (dz <= ambient_volume_radius);
    }

    /// Spawns a green spore particle drifting downward beneath the blossom.
    pub fn spawnRainingParticle(self: SporeBlossom, offset_x: f32, offset_z: f32) SporeParticle {
        return .{
            .x = @as(f32, @floatFromInt(self.x)) + 0.5 + offset_x,
            .y = @as(f32, @floatFromInt(self.y)) + 0.1,
            .z = @as(f32, @floatFromInt(self.z)) + 0.5 + offset_z,
            .vel_y = -0.04, // Gentle downward drift
            .lifetime_ticks = 80,
            .r = 0.22,
            .g = 0.72,
            .b = 0.24,
        };
    }
};

/// Free-function wrapper for Spore Blossom placement validity.
pub fn canAttachSporeBlossom(block_above_is_solid: bool, target_is_air: bool) bool {
    return SporeBlossom.canAttachSporeBlossom(block_above_is_solid, target_is_air);
}

// ============================================================================
// Comprehensive Test Suite (18 tests)
// ============================================================================

test "AzaleaTreeIndicator: indicatesLushCaveBelow returns true" {
    const indicator = AzaleaTreeIndicator.init(100, 70, -200, 15);
    try std.testing.expect(indicator.indicatesLushCaveBelow());
    try std.testing.expect(indicatesLushCaveBelow());
}

test "AzaleaTreeIndicator: tree generation places oak log trunk and azalea foliage" {
    const indicator = AzaleaTreeIndicator.init(0, 64, 0, 20);
    var buffer: [200]PlacedBlock = undefined;
    const count = indicator.generateTree(&buffer);

    try std.testing.expect(count > 0);

    var has_oak_log = false;
    var has_azalea_leaves = false;
    var has_flowering_azalea_leaves = false;

    for (buffer[0..count]) |pb| {
        if (pb.block == .oak_log) has_oak_log = true;
        if (pb.block == .azalea_leaves) has_azalea_leaves = true;
        if (pb.block == .flowering_azalea_leaves) has_flowering_azalea_leaves = true;
    }

    try std.testing.expect(has_oak_log);
    try std.testing.expect(has_azalea_leaves);
    try std.testing.expect(has_flowering_azalea_leaves);
}

test "AzaleaTreeIndicator: root column generates rooted dirt down to cave ceiling with hanging roots" {
    const indicator = AzaleaTreeIndicator.init(10, 64, 10, 50);
    var buffer: [100]PlacedBlock = undefined;
    const count = indicator.generateRootColumn(&buffer);

    // From y = 63 down to 50 is 14 rooted_dirt blocks, plus 1 hanging_roots at y = 49
    try std.testing.expectEqual(@as(usize, 15), count);

    var rooted_dirt_count: usize = 0;
    var hanging_roots_count: usize = 0;

    for (buffer[0..count]) |pb| {
        if (pb.block == .rooted_dirt) rooted_dirt_count += 1;
        if (pb.block == .hanging_roots) {
            hanging_roots_count += 1;
            try std.testing.expectEqual(@as(i32, 49), pb.y);
        }
    }

    try std.testing.expectEqual(@as(usize, 14), rooted_dirt_count);
    try std.testing.expectEqual(@as(usize, 1), hanging_roots_count);
}

test "AzaleaTreeIndicator: root column depth calculation" {
    const indicator1 = AzaleaTreeIndicator.init(0, 80, 0, 30);
    try std.testing.expectEqual(@as(u32, 50), indicator1.rootColumnDepth());

    const indicator2 = AzaleaTreeIndicator.init(0, 30, 0, 30);
    try std.testing.expectEqual(@as(u32, 0), indicator2.rootColumnDepth());
}

test "RootedDirtMechanics: tillRootedDirtWithHoe converts to dirt and drops 1 hanging_roots" {
    const result = tillRootedDirtWithHoe();
    try std.testing.expect(result.success);
    try std.testing.expectEqual(BlockType.dirt, result.converted_block);
    try std.testing.expectEqual(@as(?ItemType, .hanging_roots), result.dropped_item);
    try std.testing.expectEqual(@as(u8, 1), result.dropped_count);
}

test "RootedDirtMechanics: tillBlockWithHoe only affects rooted_dirt" {
    const res_rooted = RootedDirtMechanics.tillBlockWithHoe(.rooted_dirt);
    try std.testing.expect(res_rooted.success);
    try std.testing.expectEqual(BlockType.dirt, res_rooted.converted_block);
    try std.testing.expectEqual(@as(?ItemType, .hanging_roots), res_rooted.dropped_item);

    const res_stone = RootedDirtMechanics.tillBlockWithHoe(.stone);
    try std.testing.expect(!res_stone.success);
    try std.testing.expectEqual(BlockType.stone, res_stone.converted_block);
    try std.testing.expectEqual(@as(?ItemType, null), res_stone.dropped_item);
}

test "RootedDirtMechanics: applyBoneMealToRootedDirt grows hanging roots only if below is air" {
    try std.testing.expect(applyBoneMealToRootedDirt(true));
    try std.testing.expect(!applyBoneMealToRootedDirt(false));

    try std.testing.expectEqual(@as(?BlockType, .hanging_roots), RootedDirtMechanics.getUnderneathGrownBlock(true));
    try std.testing.expectEqual(@as(?BlockType, null), RootedDirtMechanics.getUnderneathGrownBlock(false));
}

test "MossBoneMealSpread: canMossReplaceBlock converts natural stone and dirt types" {
    // 10 required replaceable block kinds
    try std.testing.expect(canMossReplaceBlock(BlockType.stone));
    try std.testing.expect(canMossReplaceBlock(BlockType.deepslate));
    try std.testing.expect(canMossReplaceBlock(BlockType.tuff));
    try std.testing.expect(canMossReplaceBlock(BlockType.granite));
    try std.testing.expect(canMossReplaceBlock(BlockType.diorite));
    try std.testing.expect(canMossReplaceBlock(BlockType.andesite));
    try std.testing.expect(canMossReplaceBlock(BlockType.dirt));
    try std.testing.expect(canMossReplaceBlock(BlockType.coarse_dirt));
    try std.testing.expect(canMossReplaceBlock(BlockType.mycelium));
    try std.testing.expect(canMossReplaceBlock(BlockType.podzol));

    // Also works with enum literals
    try std.testing.expect(canMossReplaceBlock(.stone));
    try std.testing.expect(canMossReplaceBlock(.deepslate));
    try std.testing.expect(canMossReplaceBlock(.tuff));
    try std.testing.expect(canMossReplaceBlock(.granite));
    try std.testing.expect(canMossReplaceBlock(.diorite));
    try std.testing.expect(canMossReplaceBlock(.andesite));
    try std.testing.expect(canMossReplaceBlock(.dirt));
    try std.testing.expect(canMossReplaceBlock(.coarse_dirt));
    try std.testing.expect(canMossReplaceBlock(.mycelium));
    try std.testing.expect(canMossReplaceBlock(.podzol));

    // Also works with strings
    try std.testing.expect(canMossReplaceBlock("stone"));
    try std.testing.expect(canMossReplaceBlock("deepslate"));
}

test "MossBoneMealSpread: canMossReplaceBlock rejects non-replaceable blocks" {
    try std.testing.expect(!canMossReplaceBlock(BlockType.air));
    try std.testing.expect(!canMossReplaceBlock(BlockType.bedrock));
    try std.testing.expect(!canMossReplaceBlock(BlockType.oak_log));
    try std.testing.expect(!canMossReplaceBlock(BlockType.moss_block));
    try std.testing.expect(!canMossReplaceBlock(BlockType.sand));
    try std.testing.expect(!canMossReplaceBlock(BlockType.gravel));
    try std.testing.expect(!canMossReplaceBlock(BlockType.obsidian));
    try std.testing.expect(!canMossReplaceBlock(BlockType.water));
    try std.testing.expect(!canMossReplaceBlock(BlockType.lava));

    try std.testing.expect(!canMossReplaceBlock(.bedrock));
    try std.testing.expect(!canMossReplaceBlock("glass"));
}

test "MossBoneMealSpread: canApplyBoneMeal requires moss_block with air above" {
    try std.testing.expect(MossBoneMealSpread.canApplyBoneMeal(.moss_block, true));
    try std.testing.expect(!MossBoneMealSpread.canApplyBoneMeal(.moss_block, false));
    try std.testing.expect(!MossBoneMealSpread.canApplyBoneMeal(.stone, true));
    try std.testing.expect(!MossBoneMealSpread.canApplyBoneMeal(.dirt, true));
}

test "MossBoneMealSpread: 7x11x7 neighborhood bounds check" {
    try std.testing.expectEqual(@as(i32, 7), MossBoneMealSpread.spread_width);
    try std.testing.expectEqual(@as(i32, 11), MossBoneMealSpread.spread_height);
    try std.testing.expectEqual(@as(i32, 7), MossBoneMealSpread.spread_depth);

    try std.testing.expect(MossBoneMealSpread.isInSpreadNeighborhood(0, 0, 0));
    try std.testing.expect(MossBoneMealSpread.isInSpreadNeighborhood(3, 5, 3));
    try std.testing.expect(MossBoneMealSpread.isInSpreadNeighborhood(-3, -5, -3));
    try std.testing.expect(!MossBoneMealSpread.isInSpreadNeighborhood(4, 0, 0));
    try std.testing.expect(!MossBoneMealSpread.isInSpreadNeighborhood(0, 6, 0));
    try std.testing.expect(!MossBoneMealSpread.isInSpreadNeighborhood(0, 0, 4));
}

test "MossBoneMealSpread: vegetation selection generates moss_carpet, azalea, flowering_azalea, and grass" {
    var has_grass = false;
    var has_carpet = false;
    var has_azalea = false;
    var has_flowering = false;

    var roll: u8 = 0;
    while (roll < 100) : (roll += 1) {
        const veg = MossBoneMealSpread.pickVegetation(roll);
        switch (veg) {
            .grass => has_grass = true,
            .moss_carpet => has_carpet = true,
            .azalea => has_azalea = true,
            .flowering_azalea => has_flowering = true,
            .none => {},
        }
    }

    try std.testing.expect(has_grass);
    try std.testing.expect(has_carpet);
    try std.testing.expect(has_azalea);
    try std.testing.expect(has_flowering);
}

test "DripleafTiltState: tilts through unstable, partial_tilt, and full_tilt_pass_through stages" {
    var dripleaf = DripleafTiltState.init();
    try std.testing.expectEqual(TiltStage.un_tilted, dripleaf.stage);
    try std.testing.expect(dripleaf.isSolid());
    try std.testing.expect(!dripleaf.canPassThrough());

    // Step on dripleaf: 10 ticks in unstable (0.5s at 20 tps)
    for (0..10) |_| {
        dripleaf.tick(true, false);
    }
    // After 10 ticks, transitions to partial_tilt
    try std.testing.expectEqual(TiltStage.partial_tilt, dripleaf.stage);
    try std.testing.expect(dripleaf.isSolid());

    // 10 ticks in partial_tilt (0.5s at 20 tps)
    for (0..10) |_| {
        dripleaf.tick(true, false);
    }
    // Transitions to full_tilt_pass_through!
    try std.testing.expectEqual(TiltStage.full_tilt_pass_through, dripleaf.stage);
    try std.testing.expect(!dripleaf.isSolid());
    try std.testing.expect(dripleaf.canPassThrough());

    // 100 ticks in full_tilt_pass_through (5.0s at 20 tps)
    for (0..100) |_| {
        dripleaf.tick(false, false);
    }
    // Resets back to un_tilted
    try std.testing.expectEqual(TiltStage.un_tilted, dripleaf.stage);
    try std.testing.expect(dripleaf.isSolid());
}

test "DripleafTiltState: step off before full tilt restores un_tilted state" {
    var dripleaf = DripleafTiltState.init();
    dripleaf.tick(true, false); // unstable
    try std.testing.expectEqual(TiltStage.unstable, dripleaf.stage);

    // Entity steps off
    dripleaf.tick(false, false);
    try std.testing.expectEqual(TiltStage.un_tilted, dripleaf.stage);
}

test "DripleafTiltState: pass-through collision only active during full_tilt_pass_through" {
    var dl = DripleafTiltState.init();
    dl.stage = .un_tilted;
    try std.testing.expect(!dl.canPassThrough());
    try std.testing.expect(dl.isSolid());

    dl.stage = .unstable;
    try std.testing.expect(!dl.canPassThrough());
    try std.testing.expect(dl.isSolid());

    dl.stage = .partial_tilt;
    try std.testing.expect(!dl.canPassThrough());
    try std.testing.expect(dl.isSolid());

    dl.stage = .full_tilt_pass_through;
    try std.testing.expect(dl.canPassThrough());
    try std.testing.expect(!dl.isSolid());
}

test "DripleafTiltState: redstone power locks dripleaf horizontally stable" {
    var dripleaf = DripleafTiltState.init();
    dripleaf.tick(true, false); // unstable
    try std.testing.expectEqual(TiltStage.unstable, dripleaf.stage);

    // Turn on redstone power: locks it to un_tilted and horizontally stable
    dripleaf.tick(true, true);
    try std.testing.expect(dripleaf.isLockedByRedstone);
    try std.testing.expectEqual(TiltStage.un_tilted, dripleaf.stage);

    // Ticking with entity standing on it while redstone powered never tilts
    var i: usize = 0;
    while (i < 50) : (i += 1) {
        dripleaf.tick(true, true);
        try std.testing.expectEqual(TiltStage.un_tilted, dripleaf.stage);
    }
}

test "DripleafTiltState: projectile impact immediately collapses dripleaf to full_tilt_pass_through" {
    var dripleaf = DripleafTiltState.init();
    try std.testing.expectEqual(TiltStage.un_tilted, dripleaf.stage);

    // Arrow or projectile hits the big dripleaf
    dripleaf.hitWithProjectile();
    try std.testing.expectEqual(TiltStage.full_tilt_pass_through, dripleaf.stage);
    try std.testing.expect(dripleaf.canPassThrough());
}

test "DripleafTiltState: projectile impact has no effect when locked by redstone" {
    var dripleaf = DripleafTiltState.initWithRedstone(true);
    dripleaf.hitWithProjectile();
    try std.testing.expectEqual(TiltStage.un_tilted, dripleaf.stage);
    try std.testing.expect(!dripleaf.canPassThrough());
}

test "SporeBlossom: canAttachSporeBlossom attaches exclusively to underside of solid blocks into air" {
    // Solid block above and target is air: Valid!
    try std.testing.expect(canAttachSporeBlossom(true, true));
    try std.testing.expect(SporeBlossom.canAttachSporeBlossom(true, true));

    // Solid block above but target is occupied: Invalid!
    try std.testing.expect(!canAttachSporeBlossom(true, false));

    // Non-solid block above: Invalid!
    try std.testing.expect(!canAttachSporeBlossom(false, true));
    try std.testing.expect(!canAttachSporeBlossom(false, false));
}

test "SporeBlossom: 32x32x32 ambient volume bounds check" {
    const blossom = SporeBlossom.init(0, 50, 0);

    try std.testing.expectEqual(@as(i32, 32), SporeBlossom.ambient_volume_width);
    try std.testing.expectEqual(@as(i32, 32), SporeBlossom.ambient_volume_height);
    try std.testing.expectEqual(@as(i32, 32), SporeBlossom.ambient_volume_depth);

    // Inside volume
    try std.testing.expect(blossom.isInAmbientVolume(0, 50, 0));
    try std.testing.expect(blossom.isInAmbientVolume(16, 50, 0));
    try std.testing.expect(blossom.isInAmbientVolume(0, 66, 0));
    try std.testing.expect(blossom.isInAmbientVolume(0, 34, 0));
    try std.testing.expect(blossom.isInAmbientVolume(0, 50, -16));

    // Outside volume
    try std.testing.expect(!blossom.isInAmbientVolume(17, 50, 0));
    try std.testing.expect(!blossom.isInAmbientVolume(0, 67, 0));
    try std.testing.expect(!blossom.isInAmbientVolume(0, 50, 17));
}

test "SporeBlossom: green spore particles rain downward" {
    const blossom = SporeBlossom.init(10, 40, 10);
    var particle = blossom.spawnRainingParticle(0.0, 0.0);

    try std.testing.expect(particle.isGreen());
    try std.testing.expect(particle.vel_y < 0.0); // downward drift

    const initial_y = particle.y;
    const alive = particle.tick();

    try std.testing.expect(alive);
    try std.testing.expect(particle.y < initial_y); // drifted down
}
