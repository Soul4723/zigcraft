const std = @import("std");

/// Block identifiers specific to the Pale Garden biome and Resin masonry.
pub const PaleGardenBlock = enum(u16) {
    air = 0,
    pale_oak_log = 420,
    creaking_heart = 421,
    creaking_heart_active = 422,
    pale_oak_wood = 423,
    pale_oak_planks = 424,
    pale_oak_leaves = 425,
    pale_moss_block = 426,
    pale_moss_carpet = 427,
    pale_hanging_moss = 428,
    closed_eyeblossom = 429,
    open_eyeblossom = 430,
    resin_clump = 431,
    resin_block = 432,
    resin_bricks = 433,
    resin_brick_slab = 434,
    resin_brick_stairs = 435,
    resin_brick_wall = 436,
    chiseled_resin_bricks = 437,
};

/// Item tags for inventory and crafting integration.
pub const PaleOakLogTag: u16 = 420;
pub const CreakingHeartTag: u16 = 421;
pub const ClosedEyeblossomTag: u16 = 429;
pub const OpenEyeblossomTag: u16 = 430;
pub const ResinClumpTag: u16 = 431;
pub const ResinBrickTag: u16 = 438;
pub const BlockOfResinBricksTag: u16 = 433;
pub const ResinBrickSlabTag: u16 = 434;
pub const ResinBrickStairsTag: u16 = 435;
pub const ResinBrickWallTag: u16 = 436;
pub const ChiseledResinBricksTag: u16 = 437;

/// Creaking mob and Creaking Heart physical constants.
pub const creaking_max_tether_radius: f32 = 32.0;
pub const creaking_max_tether_radius_sq: f32 = creaking_max_tether_radius * creaking_max_tether_radius; // 1024.0
pub const resin_extrusion_cooldown_ticks: u32 = 100; // 5 seconds at 20 ticks/sec
pub const resin_extrusion_cooldown_seconds: f32 = 5.0;

/// Eyeblossom constants.
pub const open_eyeblossom_light_level: u8 = 3;
pub const closed_eyeblossom_light_level: u8 = 0;
pub const eyeblossom_poison_duration_ticks: u32 = 200; // 10 seconds
pub const eyeblossom_acoustic_range: f32 = 16.0;

/// Axis alignment for tree logs.
pub const LogAxis = enum(u8) {
    y = 0,
    x = 1,
    z = 2,
};

/// Represents the Creaking puppet mob tethered to a Creaking Heart.
pub const Creaking = struct {
    id: u32 = 1,
    pos: [3]f32,
    heart_pos: [3]i32,
    is_frozen: bool = false,
    is_alive: bool = true,
    is_vaporized: bool = false,
    health: f32 = 1.0, // Virtual HP; puppet takes 0 direct damage from hits
};

/// State of a Creaking Heart block in the world.
pub const CreakingHeartState = struct {
    pos: [3]i32,
    is_active: bool = false,
    is_natural: bool = false,
    resin_cooldown_ticks: u32 = 0,
    linked_creaking_id: ?u32 = null,
    spawned_creaking: ?Creaking = null,

    pub fn init(pos: [3]i32, is_natural: bool) CreakingHeartState {
        return .{
            .pos = pos,
            .is_active = false,
            .is_natural = is_natural,
            .resin_cooldown_ticks = 0,
            .linked_creaking_id = null,
            .spawned_creaking = null,
        };
    }

    /// Evaluates whether the Creaking Heart can activate.
    /// Active only at night or during a thunderstorm, and only when sandwiched
    /// vertically between two Pale Oak Logs (`above == pale_oak_log and below == pale_oak_log`).
    pub fn canActivate(above: PaleGardenBlock, below: PaleGardenBlock, is_night: bool, is_thunder: bool) bool {
        const is_sandwiched = (above == .pale_oak_log and below == .pale_oak_log);
        const time_ok = is_night or is_thunder;
        return is_sandwiched and time_ok;
    }

    /// Evaluates activation with log axis alignment (vertical Y-axis alignment).
    pub fn canActivateWithAxis(
        above: PaleGardenBlock,
        above_axis: LogAxis,
        below: PaleGardenBlock,
        below_axis: LogAxis,
        is_night: bool,
        is_thunder: bool,
    ) bool {
        const axis_ok = (above_axis == .y and below_axis == .y);
        return axis_ok and canActivate(above, below, is_night, is_thunder);
    }

    /// Updates active status and spawns/tethers or despawns the Creaking puppet.
    pub fn update(
        self: *CreakingHeartState,
        above: PaleGardenBlock,
        below: PaleGardenBlock,
        is_night: bool,
        is_thunder: bool,
        spawn_offset: ?[3]f32,
    ) void {
        const should_be_active = canActivate(above, below, is_night, is_thunder);
        if (should_be_active) {
            self.is_active = true;
            if (self.spawned_creaking == null or (self.spawned_creaking != null and !self.spawned_creaking.?.is_alive)) {
                const offset = spawn_offset orelse [3]f32{ 0.0, 0.0, 4.0 };
                const sx = @as(f32, @floatFromInt(self.pos[0])) + offset[0];
                const sy = @as(f32, @floatFromInt(self.pos[1])) + offset[1];
                const sz = @as(f32, @floatFromInt(self.pos[2])) + offset[2];
                const new_id = (self.linked_creaking_id orelse 100) + 1;
                self.linked_creaking_id = new_id;
                self.spawned_creaking = Creaking{
                    .id = new_id,
                    .pos = .{ sx, sy, sz },
                    .heart_pos = self.pos,
                    .is_frozen = false,
                    .is_alive = true,
                    .is_vaporized = false,
                };
            }
        } else {
            self.is_active = false;
            if (self.spawned_creaking) |*creaking| {
                creaking.is_alive = false;
                creaking.is_vaporized = true;
            }
            self.spawned_creaking = null;
            self.linked_creaking_id = null;
        }
    }

    /// Ticks the resin extrusion cooldown.
    pub fn tick(self: *CreakingHeartState, dt_ticks: u32) void {
        if (self.resin_cooldown_ticks > dt_ticks) {
            self.resin_cooldown_ticks -= dt_ticks;
        } else {
            self.resin_cooldown_ticks = 0;
        }
    }

    /// Breaking the Creaking Heart immediately vaporizes the linked Creaking puppet.
    pub fn onBroken(self: *CreakingHeartState) void {
        self.is_active = false;
        if (self.spawned_creaking) |*creaking| {
            creaking.is_alive = false;
            creaking.is_vaporized = true;
            creaking.health = 0.0;
        }
        self.spawned_creaking = null;
        self.linked_creaking_id = null;
    }

    pub fn canExtrudeResin(self: *const CreakingHeartState) bool {
        return self.resin_cooldown_ticks == 0;
    }
};

/// Checks if a position is within the Creaking's 32-block tether radius from its heart.
pub fn isWithinTetherRadius(creaking_pos: [3]f32, heart_pos: [3]i32) bool {
    const dx = creaking_pos[0] - @as(f32, @floatFromInt(heart_pos[0]));
    const dy = creaking_pos[1] - @as(f32, @floatFromInt(heart_pos[1]));
    const dz = creaking_pos[2] - @as(f32, @floatFromInt(heart_pos[2]));
    return (dx * dx + dy * dy + dz * dz) <= creaking_max_tether_radius_sq;
}

/// Freezes the Creaking completely when a player looks at it within the FOV cone
/// (unless wearing a Carved Pumpkin, which bypasses gaze freeze!).
pub fn isCreakingFrozenByGaze(
    creaking_pos: [3]f32,
    player_eye_pos: [3]f32,
    player_look_dir: [3]f32,
    cos_fov_threshold: f32,
    wearing_carved_pumpkin: bool,
) bool {
    // Carved pumpkin bypasses gaze freeze completely
    if (wearing_carved_pumpkin) {
        return false;
    }

    const dx = creaking_pos[0] - player_eye_pos[0];
    const dy = creaking_pos[1] - player_eye_pos[1];
    const dz = creaking_pos[2] - player_eye_pos[2];
    const dist_sq = dx * dx + dy * dy + dz * dz;

    // Inside or extremely close to the player
    if (dist_sq < 0.0001) {
        return true;
    }

    const inv_dist = 1.0 / @sqrt(dist_sq);
    const to_c_x = dx * inv_dist;
    const to_c_y = dy * inv_dist;
    const to_c_z = dz * inv_dist;

    const look_sq = player_look_dir[0] * player_look_dir[0] +
        player_look_dir[1] * player_look_dir[1] +
        player_look_dir[2] * player_look_dir[2];

    if (look_sq < 0.0001) {
        return false;
    }

    const inv_look = 1.0 / @sqrt(look_sq);
    const look_x = player_look_dir[0] * inv_look;
    const look_y = player_look_dir[1] * inv_look;
    const look_z = player_look_dir[2] * inv_look;

    const dot = to_c_x * look_x + to_c_y * look_y + to_c_z * look_z;

    return dot >= cos_fov_threshold;
}

/// Result of hitting a Creaking puppet.
pub const CreakingHitResult = struct {
    particle_trail_count: u8,
    resin_clump_positions: [3][3]i32,
    damage_dealt: f32 = 0.0,
    clumps_count: u8 = 3,
};

/// Hitting the Creaking deals 0 direct HP damage to the puppet, emits an orange-to-grey spore
/// particle trail toward the tethered CreakingHeart, and extrudes 2–3 Resin Clumps onto adjacent
/// Pale Oak Logs.
pub fn onCreakingHit(heart_pos: [3]i32, creaking_pos: anytype) CreakingHitResult {
    const cx: f32 = if (@typeInfo(@TypeOf(creaking_pos[0])) == .int) @floatFromInt(creaking_pos[0]) else creaking_pos[0];
    const cy: f32 = if (@typeInfo(@TypeOf(creaking_pos[1])) == .int) @floatFromInt(creaking_pos[1]) else creaking_pos[1];
    const cz: f32 = if (@typeInfo(@TypeOf(creaking_pos[2])) == .int) @floatFromInt(creaking_pos[2]) else creaking_pos[2];

    const hx: f32 = @floatFromInt(heart_pos[0]);
    const hy: f32 = @floatFromInt(heart_pos[1]);
    const hz: f32 = @floatFromInt(heart_pos[2]);

    const dx = hx - cx;
    const dy = hy - cy;
    const dz = hz - cz;
    const dist = @sqrt(dx * dx + dy * dy + dz * dz);

    // Particle count: 8..32 particles flying from Creaking to Heart
    const base_count = @as(u32, @intFromFloat(@round(dist * 0.75))) + 8;
    const particle_count: u8 = @intCast(@min(32, @max(8, base_count)));

    // 3 adjacent positions onto adjacent logs around the heart
    const clump_positions = [3][3]i32{
        .{ heart_pos[0] + 1, heart_pos[1], heart_pos[2] },
        .{ heart_pos[0] - 1, heart_pos[1], heart_pos[2] },
        .{ heart_pos[0], heart_pos[1] + 1, heart_pos[2] },
    };

    return .{
        .particle_trail_count = particle_count,
        .resin_clump_positions = clump_positions,
        .damage_dealt = 0.0, // Deals 0 direct HP damage to the puppet
        .clumps_count = 3,
    };
}

/// Hitting the Creaking with heart state and cooldown enforcement.
pub fn onCreakingHitWithState(
    heart: *CreakingHeartState,
    creaking: *Creaking,
) CreakingHitResult {
    var result = onCreakingHit(heart.pos, creaking.pos);
    if (heart.canExtrudeResin()) {
        heart.resin_cooldown_ticks = resin_extrusion_cooldown_ticks;
        result.clumps_count = 3;
    } else {
        result.clumps_count = 0;
    }
    // Puppet takes 0 damage
    creaking.health = 1.0;
    return result;
}

/// Breaking the Creaking Heart immediately vaporizes the linked Creaking puppet.
pub fn breakCreakingHeart(heart: *CreakingHeartState, creaking: ?*Creaking) void {
    heart.onBroken();
    if (creaking) |c| {
        c.is_alive = false;
        c.is_vaporized = true;
        c.health = 0.0;
    }
}

/// Variant of Eyeblossom flower.
pub const EyeblossomVariant = enum(u8) {
    closed = 0,
    open = 1,
};

/// State of an Eyeblossom flower block.
pub const EyeblossomState = struct {
    pos: [3]i32 = .{ 0, 0, 0 },
    variant: EyeblossomVariant = .closed,
    light_level: u8 = 0,
    wave_delay_ticks: u32 = 0,

    pub fn init(pos: [3]i32, is_night: bool) EyeblossomState {
        const v: EyeblossomVariant = if (is_night) .open else .closed;
        return .{
            .pos = pos,
            .variant = v,
            .light_level = if (v == .open) open_eyeblossom_light_level else closed_eyeblossom_light_level,
            .wave_delay_ticks = 0,
        };
    }

    /// Evaluates target variant for current time/weather conditions.
    pub fn targetVariant(is_night: bool, is_thunderstorm: bool) EyeblossomVariant {
        if (is_night or is_thunderstorm) return .open;
        return .closed;
    }

    /// Updates variant and light level automatically based on day/night or weather.
    pub fn update(self: *EyeblossomState, is_night: bool, is_thunderstorm: bool) bool {
        const target = targetVariant(is_night, is_thunderstorm);
        const changed = (self.variant != target);
        self.variant = target;
        self.light_level = if (target == .open) open_eyeblossom_light_level else closed_eyeblossom_light_level;
        return changed;
    }

    /// Ticks delayed wave transition for sequential acoustic communication opening/closing.
    pub fn tick(self: *EyeblossomState) bool {
        if (self.wave_delay_ticks > 0) {
            self.wave_delay_ticks -= 1;
            if (self.wave_delay_ticks == 0) {
                self.variant = if (self.variant == .closed) .open else .closed;
                self.light_level = if (self.variant == .open) open_eyeblossom_light_level else closed_eyeblossom_light_level;
                return true;
            }
        }
        return false;
    }

    /// Schedules an acoustic wave transition delay relative to the origin blossom.
    pub fn scheduleWaveTransition(self: *EyeblossomState, origin_pos: [3]i32, ticks_per_block: u32) void {
        const dx = self.pos[0] - origin_pos[0];
        const dy = self.pos[1] - origin_pos[1];
        const dz = self.pos[2] - origin_pos[2];
        const dist = @sqrt(@as(f32, @floatFromInt(dx * dx + dy * dy + dz * dz)));
        const delay = @as(u32, @intFromFloat(@round(dist))) * ticks_per_block;
        self.wave_delay_ticks = @max(1, delay);
    }
};

/// Triggers an acoustic communication wave cascade to neighboring eyeblossoms within range.
pub fn triggerEyeblossomCascade(
    origin: *const EyeblossomState,
    neighbors: []EyeblossomState,
    ticks_per_block: u32,
) usize {
    var count: usize = 0;
    for (neighbors) |*nb| {
        const dx = @as(f32, @floatFromInt(nb.pos[0] - origin.pos[0]));
        const dy = @as(f32, @floatFromInt(nb.pos[1] - origin.pos[1]));
        const dz = @as(f32, @floatFromInt(nb.pos[2] - origin.pos[2]));
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);
        if (dist > 0.0 and dist <= eyeblossom_acoustic_range) {
            nb.scheduleWaveTransition(origin.pos, ticks_per_block);
            count += 1;
        }
    }
    return count;
}

/// Poison effect evaluation when a bee touches an Eyeblossom.
pub fn checkBeeInteraction(variant: EyeblossomVariant) struct { poisons_bee: bool, effect_duration_ticks: u32 } {
    if (variant == .open) {
        return .{
            .poisons_bee = true,
            .effect_duration_ticks = eyeblossom_poison_duration_ticks,
        };
    }
    return .{
        .poisons_bee = false,
        .effect_duration_ticks = 0,
    };
}

/// Helper function to check if an Eyeblossom poisons bees.
pub fn doesEyeblossomPoisonBee(variant: EyeblossomVariant) bool {
    return variant == .open;
}

// ============================================================================
// Resin Masonry Conversion Helpers
// ============================================================================

/// Smelting helper: Resin Clump -> Resin Brick.
pub fn smeltResinClump(input_tag: u16) ?u16 {
    if (input_tag == ResinClumpTag) {
        return ResinBrickTag;
    }
    return null;
}

/// Crafting helper: 4 Resin Bricks -> 1 Block of Resin Bricks.
pub fn craftBlockOfResinBricks(resin_brick_count: u32) ?struct { blocks: u32, remaining_bricks: u32 } {
    if (resin_brick_count < 4) return null;
    return .{
        .blocks = resin_brick_count / 4,
        .remaining_bricks = resin_brick_count % 4,
    };
}

/// Crafting helper: 3 Blocks of Resin Bricks -> 6 Resin Brick Slabs.
pub fn craftResinBrickSlabs(block_count: u32) ?struct { slabs: u32, remaining_blocks: u32 } {
    if (block_count < 3) return null;
    return .{
        .slabs = (block_count / 3) * 6,
        .remaining_blocks = block_count % 3,
    };
}

/// Crafting helper: 6 Blocks of Resin Bricks -> 4 Resin Brick Stairs.
pub fn craftResinBrickStairs(block_count: u32) ?struct { stairs: u32, remaining_blocks: u32 } {
    if (block_count < 6) return null;
    return .{
        .stairs = (block_count / 6) * 4,
        .remaining_blocks = block_count % 6,
    };
}

/// Crafting helper: 6 Blocks of Resin Bricks -> 6 Resin Brick Walls.
pub fn craftResinBrickWalls(block_count: u32) ?struct { walls: u32, remaining_blocks: u32 } {
    if (block_count < 6) return null;
    return .{
        .walls = (block_count / 6) * 6,
        .remaining_blocks = block_count % 6,
    };
}

/// Crafting helper: 2 Resin Brick Slabs -> 1 Chiseled Resin Bricks block.
pub fn craftChiseledResinBricks(slab_count: u32) ?struct { chiseled: u32, remaining_slabs: u32 } {
    if (slab_count < 2) return null;
    return .{
        .chiseled = slab_count / 2,
        .remaining_slabs = slab_count % 2,
    };
}

/// Stonecutting conversion: 1 Block of Resin Bricks -> 1/2 of specified masonry product.
pub fn stonecutResinBlock(input_tag: u16, target_tag: u16) ?u32 {
    if (input_tag != BlockOfResinBricksTag) return null;
    return switch (target_tag) {
        ResinBrickSlabTag => 2,
        ResinBrickStairsTag => 1,
        ResinBrickWallTag => 1,
        ChiseledResinBricksTag => 1,
        else => null,
    };
}

// ============================================================================
// Comprehensive Unit Tests
// ============================================================================

test "CreakingHeartState log sandwich activation requires pale oak log above and below" {
    // Valid sandwich: pale oak log above and below at night
    try std.testing.expect(CreakingHeartState.canActivate(.pale_oak_log, .pale_oak_log, true, false));

    // Missing log above (e.g. air or leaves)
    try std.testing.expect(!CreakingHeartState.canActivate(.air, .pale_oak_log, true, false));
    try std.testing.expect(!CreakingHeartState.canActivate(.pale_oak_leaves, .pale_oak_log, true, false));

    // Missing log below (e.g. pale oak planks or moss)
    try std.testing.expect(!CreakingHeartState.canActivate(.pale_oak_log, .pale_oak_planks, true, false));
    try std.testing.expect(!CreakingHeartState.canActivate(.pale_oak_log, .pale_moss_block, true, false));

    // Neither is log
    try std.testing.expect(!CreakingHeartState.canActivate(.air, .air, true, false));
}

test "CreakingHeartState log sandwich with vertical Y axis alignment" {
    // Both logs aligned vertically along Y axis
    try std.testing.expect(CreakingHeartState.canActivateWithAxis(
        .pale_oak_log,
        .y,
        .pale_oak_log,
        .y,
        true,
        false,
    ));

    // Misaligned logs (e.g. horizontal X or Z axis)
    try std.testing.expect(!CreakingHeartState.canActivateWithAxis(
        .pale_oak_log,
        .x,
        .pale_oak_log,
        .y,
        true,
        false,
    ));
    try std.testing.expect(!CreakingHeartState.canActivateWithAxis(
        .pale_oak_log,
        .y,
        .pale_oak_log,
        .z,
        true,
        false,
    ));
}

test "CreakingHeartState requires night or thunderstorm to activate" {
    // Clear daytime: inactive even with logs
    try std.testing.expect(!CreakingHeartState.canActivate(.pale_oak_log, .pale_oak_log, false, false));

    // Nighttime: active
    try std.testing.expect(CreakingHeartState.canActivate(.pale_oak_log, .pale_oak_log, true, false));

    // Thunderstorm during day: active
    try std.testing.expect(CreakingHeartState.canActivate(.pale_oak_log, .pale_oak_log, false, true));

    // Thunderstorm at night: active
    try std.testing.expect(CreakingHeartState.canActivate(.pale_oak_log, .pale_oak_log, true, true));
}

test "CreakingHeartState spawns puppet within 32 block tether radius" {
    var heart = CreakingHeartState.init(.{ 100, 64, 200 }, true);
    heart.update(.pale_oak_log, .pale_oak_log, true, false, .{ 5.0, 0.0, 5.0 });

    try std.testing.expect(heart.is_active);
    try std.testing.expect(heart.spawned_creaking != null);

    const puppet = heart.spawned_creaking.?;
    try std.testing.expect(puppet.is_alive);
    try std.testing.expectEqual(@as(f32, 105.0), puppet.pos[0]);
    try std.testing.expectEqual(@as(f32, 64.0), puppet.pos[1]);
    try std.testing.expectEqual(@as(f32, 205.0), puppet.pos[2]);

    // Check tether distance
    try std.testing.expect(isWithinTetherRadius(puppet.pos, heart.pos));

    // Position beyond 32 blocks is outside tether radius
    const far_pos = [3]f32{ 140.0, 64.0, 200.0 }; // 40 blocks away
    try std.testing.expect(!isWithinTetherRadius(far_pos, heart.pos));
}

test "CreakingHeartState break immediately vaporizes linked Creaking puppet" {
    var heart = CreakingHeartState.init(.{ 0, 70, 0 }, true);
    heart.update(.pale_oak_log, .pale_oak_log, true, false, null);
    try std.testing.expect(heart.spawned_creaking != null);

    var puppet = heart.spawned_creaking.?;
    try std.testing.expect(puppet.is_alive);
    try std.testing.expect(!puppet.is_vaporized);

    // Break the heart
    breakCreakingHeart(&heart, &puppet);

    try std.testing.expect(!heart.is_active);
    try std.testing.expect(!puppet.is_alive);
    try std.testing.expect(puppet.is_vaporized);
    try std.testing.expectEqual(@as(f32, 0.0), puppet.health);
    try std.testing.expect(heart.spawned_creaking == null);
}

test "isCreakingFrozenByGaze freezes when player looks directly at Creaking" {
    const creaking_pos = [3]f32{ 0.0, 1.6, 10.0 };
    const player_eye_pos = [3]f32{ 0.0, 1.6, 0.0 };
    const player_look_dir = [3]f32{ 0.0, 0.0, 1.0 }; // Looking directly at creaking
    const cos_fov = 0.7071; // ~45 deg half-angle (90 deg FOV)

    const frozen = isCreakingFrozenByGaze(creaking_pos, player_eye_pos, player_look_dir, cos_fov, false);
    try std.testing.expect(frozen);
}

test "isCreakingFrozenByGaze does not freeze when player looks away" {
    const creaking_pos = [3]f32{ 0.0, 1.6, 10.0 };
    const player_eye_pos = [3]f32{ 0.0, 1.6, 0.0 };
    const player_look_dir = [3]f32{ 0.0, 0.0, -1.0 }; // Looking opposite direction
    const cos_fov = 0.7071;

    const frozen = isCreakingFrozenByGaze(creaking_pos, player_eye_pos, player_look_dir, cos_fov, false);
    try std.testing.expect(!frozen);
}

test "isCreakingFrozenByGaze carved pumpkin bypasses gaze freeze" {
    const creaking_pos = [3]f32{ 0.0, 1.6, 10.0 };
    const player_eye_pos = [3]f32{ 0.0, 1.6, 0.0 };
    const player_look_dir = [3]f32{ 0.0, 0.0, 1.0 }; // Direct look
    const cos_fov = 0.5;

    // Wearing carved pumpkin bypasses freeze!
    const frozen = isCreakingFrozenByGaze(creaking_pos, player_eye_pos, player_look_dir, cos_fov, true);
    try std.testing.expect(!frozen);
}

test "isCreakingFrozenByGaze dot product FOV cone angle boundary" {
    const player_eye = [3]f32{ 0.0, 0.0, 0.0 };
    // Creaking placed along X axis
    const creaking_pos = [3]f32{ 10.0, 0.0, 0.0 };

    // Player looks at 45 degrees: (cos(45°), sin(45°), 0) = (0.7071, 0.7071, 0)
    const player_look = [3]f32{ 0.7071, 0.7071, 0.0 };

    // Dot product between (1,0,0) and (0.7071, 0.7071, 0) is ~0.7071
    // If threshold is 0.8 (narrower than 45°), it should NOT freeze
    try std.testing.expect(!isCreakingFrozenByGaze(creaking_pos, player_eye, player_look, 0.8, false));

    // If threshold is 0.5 (wider than 45°, 60° half-angle), it SHOULD freeze
    try std.testing.expect(isCreakingFrozenByGaze(creaking_pos, player_eye, player_look, 0.5, false));
}

test "onCreakingHit deals 0 direct damage, emits particle trail and extrudes resin clumps" {
    const heart_pos = [3]i32{ 20, 65, 30 };
    const creaking_pos = [3]f32{ 20.0, 65.0, 42.0 }; // 12 blocks away

    const hit = onCreakingHit(heart_pos, creaking_pos);

    // Puppet takes 0 direct damage
    try std.testing.expectEqual(@as(f32, 0.0), hit.damage_dealt);

    // Particle trail emitted towards heart: 12 * 0.75 + 8 = 17 particles
    try std.testing.expect(hit.particle_trail_count >= 8);
    try std.testing.expect(hit.particle_trail_count <= 32);

    // Extrudes 3 resin clumps onto adjacent logs
    try std.testing.expectEqual(@as(u8, 3), hit.clumps_count);
    try std.testing.expectEqual([3]i32{ 21, 65, 30 }, hit.resin_clump_positions[0]);
    try std.testing.expectEqual([3]i32{ 19, 65, 30 }, hit.resin_clump_positions[1]);
    try std.testing.expectEqual([3]i32{ 20, 66, 30 }, hit.resin_clump_positions[2]);
}

test "onCreakingHit resin extrusion respects 5-second 100-tick cooldown" {
    var heart = CreakingHeartState.init(.{ 10, 64, 10 }, true);
    var puppet = Creaking{
        .pos = .{ 10.0, 64.0, 14.0 },
        .heart_pos = heart.pos,
    };

    // First hit: cooldown is 0 -> extrudes resin clumps
    try std.testing.expect(heart.canExtrudeResin());
    const hit1 = onCreakingHitWithState(&heart, &puppet);
    try std.testing.expectEqual(@as(u8, 3), hit1.clumps_count);
    try std.testing.expectEqual(resin_extrusion_cooldown_ticks, heart.resin_cooldown_ticks);
    try std.testing.expect(!heart.canExtrudeResin());

    // Immediate second hit: on cooldown -> 0 clumps extruded
    const hit2 = onCreakingHitWithState(&heart, &puppet);
    try std.testing.expectEqual(@as(u8, 0), hit2.clumps_count);

    // Advance 50 ticks (halfway): still on cooldown
    heart.tick(50);
    try std.testing.expectEqual(@as(u32, 50), heart.resin_cooldown_ticks);
    try std.testing.expect(!heart.canExtrudeResin());

    // Advance remaining 50 ticks: cooldown expires
    heart.tick(50);
    try std.testing.expectEqual(@as(u32, 0), heart.resin_cooldown_ticks);
    try std.testing.expect(heart.canExtrudeResin());

    // Third hit: can extrude again!
    const hit3 = onCreakingHitWithState(&heart, &puppet);
    try std.testing.expectEqual(@as(u8, 3), hit3.clumps_count);
}

test "EyeblossomState day/night transitions between closed and open states with light levels" {
    var blossom = EyeblossomState.init(.{ 5, 60, 5 }, false);

    // Initial daytime state: closed, 0 light
    try std.testing.expectEqual(EyeblossomVariant.closed, blossom.variant);
    try std.testing.expectEqual(@as(u8, 0), blossom.light_level);

    // Transition to nighttime: open, 3 light
    const changed_to_night = blossom.update(true, false);
    try std.testing.expect(changed_to_night);
    try std.testing.expectEqual(EyeblossomVariant.open, blossom.variant);
    try std.testing.expectEqual(@as(u8, 3), blossom.light_level);

    // Thunderstorm during day also keeps it open
    _ = blossom.update(false, true);
    try std.testing.expectEqual(EyeblossomVariant.open, blossom.variant);
    try std.testing.expectEqual(@as(u8, 3), blossom.light_level);

    // Back to sunny daytime: closed, 0 light
    const changed_to_day = blossom.update(false, false);
    try std.testing.expect(changed_to_day);
    try std.testing.expectEqual(EyeblossomVariant.closed, blossom.variant);
    try std.testing.expectEqual(@as(u8, 0), blossom.light_level);
}

test "EyeblossomState sequential acoustic communication wave delay" {
    const origin = EyeblossomState.init(.{ 0, 64, 0 }, true);

    var neighbors = [_]EyeblossomState{
        EyeblossomState.init(.{ 3, 64, 0 }, false), // 3 blocks away
        EyeblossomState.init(.{ 8, 64, 0 }, false), // 8 blocks away
        EyeblossomState.init(.{ 25, 64, 0 }, false), // 25 blocks away (out of 16-block range)
    };

    const affected = triggerEyeblossomCascade(&origin, &neighbors, 2);
    try std.testing.expectEqual(@as(usize, 2), affected);

    // Neighbor 0: 3 blocks * 2 ticks = 6 ticks delay
    try std.testing.expectEqual(@as(u32, 6), neighbors[0].wave_delay_ticks);
    // Neighbor 1: 8 blocks * 2 ticks = 16 ticks delay
    try std.testing.expectEqual(@as(u32, 16), neighbors[1].wave_delay_ticks);
    // Neighbor 2: out of range -> 0 delay
    try std.testing.expectEqual(@as(u32, 0), neighbors[2].wave_delay_ticks);

    // Tick neighbor 0 for 5 ticks: not yet transitioned
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        try std.testing.expect(!neighbors[0].tick());
    }
    try std.testing.expectEqual(EyeblossomVariant.closed, neighbors[0].variant);

    // 6th tick: transitions from closed to open!
    try std.testing.expect(neighbors[0].tick());
    try std.testing.expectEqual(EyeblossomVariant.open, neighbors[0].variant);
    try std.testing.expectEqual(@as(u8, 3), neighbors[0].light_level);
}

test "Eyeblossom open state applies poison effect to bees while closed does not" {
    // Open Eyeblossom poisons bees with 10s (200 ticks) duration
    const open_res = checkBeeInteraction(.open);
    try std.testing.expect(open_res.poisons_bee);
    try std.testing.expectEqual(@as(u32, 200), open_res.effect_duration_ticks);
    try std.testing.expect(doesEyeblossomPoisonBee(.open));

    // Closed Eyeblossom does not poison bees
    const closed_res = checkBeeInteraction(.closed);
    try std.testing.expect(!closed_res.poisons_bee);
    try std.testing.expectEqual(@as(u32, 0), closed_res.effect_duration_ticks);
    try std.testing.expect(!doesEyeblossomPoisonBee(.closed));
}

test "Resin Masonry smelting resin clump yields resin brick" {
    // Smelting Resin Clump yields Resin Brick
    const smelt_result = smeltResinClump(ResinClumpTag);
    try std.testing.expectEqual(@as(?u16, ResinBrickTag), smelt_result);

    // Non-resin clump items return null
    try std.testing.expectEqual(@as(?u16, null), smeltResinClump(PaleOakLogTag));
}

test "Resin Masonry crafting 4 resin bricks yields block of resin bricks" {
    // Less than 4 bricks: cannot craft
    try std.testing.expectEqual(@as(?@TypeOf(craftBlockOfResinBricks(3).?), null), craftBlockOfResinBricks(3));

    // Exactly 4 bricks -> 1 block, 0 remainder
    const craft1 = craftBlockOfResinBricks(4).?;
    try std.testing.expectEqual(@as(u32, 1), craft1.blocks);
    try std.testing.expectEqual(@as(u32, 0), craft1.remaining_bricks);

    // 10 bricks -> 2 blocks, 2 remainder
    const craft2 = craftBlockOfResinBricks(10).?;
    try std.testing.expectEqual(@as(u32, 2), craft2.blocks);
    try std.testing.expectEqual(@as(u32, 2), craft2.remaining_bricks);
}

test "Resin Masonry crafting slabs, stairs, walls, and chiseled resin bricks" {
    // Slabs: 3 blocks -> 6 slabs
    const slabs = craftResinBrickSlabs(3).?;
    try std.testing.expectEqual(@as(u32, 6), slabs.slabs);
    try std.testing.expectEqual(@as(u32, 0), slabs.remaining_blocks);

    // Stairs: 6 blocks -> 4 stairs
    const stairs = craftResinBrickStairs(7).?;
    try std.testing.expectEqual(@as(u32, 4), stairs.stairs);
    try std.testing.expectEqual(@as(u32, 1), stairs.remaining_blocks);

    // Walls: 6 blocks -> 6 walls
    const walls = craftResinBrickWalls(6).?;
    try std.testing.expectEqual(@as(u32, 6), walls.walls);
    try std.testing.expectEqual(@as(u32, 0), walls.remaining_blocks);

    // Chiseled: 2 slabs -> 1 chiseled block
    const chiseled = craftChiseledResinBricks(5).?;
    try std.testing.expectEqual(@as(u32, 2), chiseled.chiseled);
    try std.testing.expectEqual(@as(u32, 1), chiseled.remaining_slabs);

    // Stonecutter: 1 block -> 2 slabs, 1 stair, 1 wall, 1 chiseled
    try std.testing.expectEqual(@as(?u32, 2), stonecutResinBlock(BlockOfResinBricksTag, ResinBrickSlabTag));
    try std.testing.expectEqual(@as(?u32, 1), stonecutResinBlock(BlockOfResinBricksTag, ResinBrickStairsTag));
    try std.testing.expectEqual(@as(?u32, 1), stonecutResinBlock(BlockOfResinBricksTag, ResinBrickWallTag));
    try std.testing.expectEqual(@as(?u32, 1), stonecutResinBlock(BlockOfResinBricksTag, ChiseledResinBricksTag));
}
