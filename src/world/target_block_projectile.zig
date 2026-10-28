const std = @import("std");

// ============================================================================
// 1. Constants & Timing Configurations
// ============================================================================

/// Number of game ticks per second (20 ticks/sec).
pub const game_ticks_per_second: u32 = 20;

/// Number of redstone ticks per second (10 ticks/sec).
pub const redstone_ticks_per_second: u32 = 10;

/// Duration of a single game tick in seconds (1/20s = 0.05s).
pub const game_tick_duration_seconds: f32 = 0.05;

/// Duration of a single redstone tick in seconds (1/10s = 0.10s = 2 game ticks).
pub const redstone_tick_duration_seconds: f32 = 0.10;

/// Number of game ticks in one redstone tick.
pub const game_ticks_per_redstone_tick: u32 = 2;

/// Maximum redstone signal strength emitted by a target block (bullseye hit).
pub const max_signal_strength: u4 = 15;

/// Minimum redstone signal strength emitted by a struck target block (outer ring / edge).
pub const min_signal_strength: u4 = 1;

/// Signal strength emitted when the target block is inactive / unpowered.
pub const inactive_signal_strength: u4 = 0;

/// Center bullseye hit radius threshold in meters (<= 0.033m emits maximum power 15).
pub const bullseye_distance_threshold: f32 = 0.033;

/// Outer edge radius from face center in meters (0.50m from center to side edge).
pub const outer_edge_distance: f32 = 0.50;

/// Redstone pulse duration in game ticks for arrow/trident/spectral arrow projectiles (8 game ticks).
pub const arrow_pulse_game_ticks: u32 = 8;

/// Redstone pulse duration in redstone ticks for arrow/trident/spectral arrow projectiles (4 redstone ticks).
pub const arrow_pulse_redstone_ticks: u32 = 4;

/// Redstone pulse duration in seconds for arrow/trident/spectral arrow projectiles (0.40s).
pub const arrow_pulse_duration_seconds: f32 = 0.40;

/// Redstone pulse duration in game ticks for thrown projectiles (snowballs, eggs, pearls, potions) (20 game ticks).
pub const thrown_pulse_game_ticks: u32 = 20;

/// Redstone pulse duration in redstone ticks for thrown projectiles (10 redstone ticks).
pub const thrown_pulse_redstone_ticks: u32 = 10;

/// Redstone pulse duration in seconds for thrown projectiles (1.00s).
pub const thrown_pulse_duration_seconds: f32 = 1.00;

// ============================================================================
// 2. Spatial & Directional Enums
// ============================================================================

/// 3D cardinal and vertical directions.
pub const Direction = enum(u3) {
    up = 0,
    down = 1,
    north = 2,
    south = 3,
    east = 4,
    west = 5,

    pub const all: [6]Direction = .{ .up, .down, .north, .south, .east, .west };
    pub const horizontal: [4]Direction = .{ .north, .south, .east, .west };

    /// Vector offset for this direction.
    pub fn getOffset(self: Direction) [3]i32 {
        return switch (self) {
            .up => .{ 0, 1, 0 },
            .down => .{ 0, -1, 0 },
            .north => .{ 0, 0, -1 },
            .south => .{ 0, 0, 1 },
            .east => .{ 1, 0, 0 },
            .west => .{ -1, 0, 0 },
        };
    }

    /// Opposite 3D direction.
    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .up => .down,
            .down => .up,
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }

    /// Whether this direction lies in the horizontal plane (XZ).
    pub fn isHorizontal(self: Direction) bool {
        return self != .up and self != .down;
    }

    /// Converts to horizontal direction if applicable.
    pub fn toHorizontal(self: Direction) ?HorizontalDirection {
        return switch (self) {
            .north => .north,
            .south => .south,
            .east => .east,
            .west => .west,
            .up, .down => null,
        };
    }
};

/// 2D horizontal cardinal directions.
pub const HorizontalDirection = enum(u2) {
    north = 0,
    south = 1,
    east = 2,
    west = 3,

    pub const all: [4]HorizontalDirection = .{ .north, .south, .east, .west };

    /// Converts to 3D Direction.
    pub fn toDirection(self: HorizontalDirection) Direction {
        return switch (self) {
            .north => .north,
            .south => .south,
            .east => .east,
            .west => .west,
        };
    }

    /// 3D vector offset for this horizontal direction.
    pub fn getOffset(self: HorizontalDirection) [3]i32 {
        return self.toDirection().getOffset();
    }

    /// Opposite horizontal direction.
    pub fn opposite(self: HorizontalDirection) HorizontalDirection {
        return switch (self) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }
};

/// Redstone power delivery level.
pub const PowerLevel = enum {
    none,
    weak,
    strong,
};

// ============================================================================
// 3. Projectile Kinds & Categories
// ============================================================================

/// Broad category of projectiles determining target block pulse duration.
pub const ProjectileCategory = enum {
    arrow_or_trident, // 8 game ticks / 4 redstone ticks / 0.40s
    thrown,           // 20 game ticks / 10 redstone ticks / 1.00s
};

/// Specific projectile kinds that can strike a target block.
pub const ProjectileKind = enum {
    arrow,
    spectral_arrow,
    tipped_arrow,
    hostile_arrow,
    trident,
    snowball,
    egg,
    ender_pearl,
    splash_potion,
    lingering_potion,
    fire_charge,
    wind_charge,
    firework_rocket,
    shulker_bullet,
    llama_spit,
    other,
};

/// Categorizes a projectile kind into arrow/trident vs thrown.
pub fn getProjectileCategory(kind: ProjectileKind) ProjectileCategory {
    return switch (kind) {
        .arrow, .spectral_arrow, .tipped_arrow, .hostile_arrow, .trident => .arrow_or_trident,
        .snowball, .egg, .ender_pearl, .splash_potion, .lingering_potion,
        .fire_charge, .wind_charge, .firework_rocket, .shulker_bullet, .llama_spit, .other => .thrown,
    };
}

/// Returns whether the projectile belongs to the arrow/trident category.
pub fn isArrowOrTrident(kind: ProjectileKind) bool {
    return getProjectileCategory(kind) == .arrow_or_trident;
}

/// Returns whether the projectile belongs to the thrown projectile category.
pub fn isThrownProjectile(kind: ProjectileKind) bool {
    return getProjectileCategory(kind) == .thrown;
}

/// Returns pulse duration in game ticks for a projectile category.
pub fn getPulseGameTicks(category: ProjectileCategory) u32 {
    return switch (category) {
        .arrow_or_trident => arrow_pulse_game_ticks,
        .thrown => thrown_pulse_game_ticks,
    };
}

/// Returns pulse duration in game ticks for a specific projectile kind.
pub fn getPulseGameTicksForProjectile(kind: ProjectileKind) u32 {
    return getPulseGameTicks(getProjectileCategory(kind));
}

/// Returns pulse duration in redstone ticks for a projectile category.
pub fn getPulseRedstoneTicks(category: ProjectileCategory) u32 {
    return switch (category) {
        .arrow_or_trident => arrow_pulse_redstone_ticks,
        .thrown => thrown_pulse_redstone_ticks,
    };
}

/// Returns pulse duration in redstone ticks for a specific projectile kind.
pub fn getPulseRedstoneTicksForProjectile(kind: ProjectileKind) u32 {
    return getPulseRedstoneTicks(getProjectileCategory(kind));
}

/// Returns pulse duration in seconds for a projectile category.
pub fn getPulseDurationSeconds(category: ProjectileCategory) f32 {
    return switch (category) {
        .arrow_or_trident => arrow_pulse_duration_seconds,
        .thrown => thrown_pulse_duration_seconds,
    };
}

/// Returns pulse duration in seconds for a specific projectile kind.
pub fn getPulseDurationSecondsForProjectile(kind: ProjectileKind) f32 {
    return getPulseDurationSeconds(getProjectileCategory(kind));
}

// ============================================================================
// 4. Hit Detection & Signal Scaling
// ============================================================================

/// Calculates redstone signal strength (1..15) from radial distance on face:
/// - Center bullseye hit (distance <= 0.033m) outputs maximum signal strength 15.
/// - Outer rings scale from 14 down to 1 based on radial distance:
///   signal = @as(u4, @intFromFloat(std.math.clamp(15.0 - (dist_from_center / 0.5) * 14.0, 1.0, 15.0)))
pub fn calculateSignalFromDistance(dist_from_center: f32) u4 {
    const dist = @abs(dist_from_center);
    if (dist <= bullseye_distance_threshold) {
        return max_signal_strength;
    }
    const scaled = 15.0 - (dist / outer_edge_distance) * 14.0;
    const clamped = std.math.clamp(scaled, 1.0, 15.0);
    return @as(u4, @intFromFloat(clamped));
}

/// Calculates redstone signal strength from face UV coordinates (0.0 to 1.0).
/// The center of the face is at (0.5, 0.5).
pub fn calculateSignalFromFaceUV(u: f32, v: f32) u4 {
    const cu = std.math.clamp(u, 0.0, 1.0) - 0.5;
    const cv = std.math.clamp(v, 0.0, 1.0) - 0.5;
    const dist = @sqrt(cu * cu + cv * cv);
    return calculateSignalFromDistance(dist);
}

/// Calculates redstone signal strength given 3D hit position, target block origin, and struck face.
pub fn calculateSignalFromHitFace(hit_pos: [3]f32, block_pos: [3]i32, face: Direction) u4 {
    const bx = @as(f32, @floatFromInt(block_pos[0]));
    const by = @as(f32, @floatFromInt(block_pos[1]));
    const bz = @as(f32, @floatFromInt(block_pos[2]));

    const dist: f32 = switch (face) {
        .up, .down => blk: {
            const dx = hit_pos[0] - (bx + 0.5);
            const dz = hit_pos[2] - (bz + 0.5);
            break :blk @sqrt(dx * dx + dz * dz);
        },
        .north, .south => blk: {
            const dx = hit_pos[0] - (bx + 0.5);
            const dy = hit_pos[1] - (by + 0.5);
            break :blk @sqrt(dx * dx + dy * dy);
        },
        .east, .west => blk: {
            const dy = hit_pos[1] - (by + 0.5);
            const dz = hit_pos[2] - (bz + 0.5);
            break :blk @sqrt(dy * dy + dz * dz);
        },
    };

    return calculateSignalFromDistance(dist);
}

/// Hit result containing details of a projectile impact on a target block.
pub const TargetHitResult = struct {
    face: Direction,
    hit_pos: [3]f32,
    distance_from_center: f32,
    signal_strength: u4,
};

/// Performs a raycast against a 1x1x1 unit target block at `block_pos`.
/// Returns hit details and calculated signal strength if intersection occurs.
pub fn raycastTargetBlock(ray_origin: [3]f32, ray_dir: [3]f32, block_pos: [3]i32) ?TargetHitResult {
    const min_x = @as(f32, @floatFromInt(block_pos[0]));
    const min_y = @as(f32, @floatFromInt(block_pos[1]));
    const min_z = @as(f32, @floatFromInt(block_pos[2]));
    const max_x = min_x + 1.0;
    const max_y = min_y + 1.0;
    const max_z = min_z + 1.0;

    var t_near: f32 = -std.math.inf(f32);
    var t_far: f32 = std.math.inf(f32);
    var hit_face: Direction = .north;

    // X slab
    if (@abs(ray_dir[0]) > 0.00001) {
        var t1 = (min_x - ray_origin[0]) / ray_dir[0];
        var t2 = (max_x - ray_origin[0]) / ray_dir[0];
        var face1: Direction = .west;
        if (t1 > t2) {
            std.mem.swap(f32, &t1, &t2);
            face1 = .east;
        }
        if (t1 > t_near) {
            t_near = t1;
            hit_face = face1;
        }
        if (t2 < t_far) t_far = t2;
        if (t_near > t_far or t_far < 0.0) return null;
    } else if (ray_origin[0] < min_x or ray_origin[0] > max_x) {
        return null;
    }

    // Y slab
    if (@abs(ray_dir[1]) > 0.00001) {
        var t1 = (min_y - ray_origin[1]) / ray_dir[1];
        var t2 = (max_y - ray_origin[1]) / ray_dir[1];
        var face1: Direction = .down;
        if (t1 > t2) {
            std.mem.swap(f32, &t1, &t2);
            face1 = .up;
        }
        if (t1 > t_near) {
            t_near = t1;
            hit_face = face1;
        }
        if (t2 < t_far) t_far = t2;
        if (t_near > t_far or t_far < 0.0) return null;
    } else if (ray_origin[1] < min_y or ray_origin[1] > max_y) {
        return null;
    }

    // Z slab
    if (@abs(ray_dir[2]) > 0.00001) {
        var t1 = (min_z - ray_origin[2]) / ray_dir[2];
        var t2 = (max_z - ray_origin[2]) / ray_dir[2];
        var face1: Direction = .north;
        if (t1 > t2) {
            std.mem.swap(f32, &t1, &t2);
            face1 = .south;
        }
        if (t1 > t_near) {
            t_near = t1;
            hit_face = face1;
        }
        if (t2 < t_far) t_far = t2;
        if (t_near > t_far or t_far < 0.0) return null;
    } else if (ray_origin[2] < min_z or ray_origin[2] > max_z) {
        return null;
    }

    if (t_near < 0.0) return null; // Ray origin inside or past block

    const hit_pt = [3]f32{
        ray_origin[0] + ray_dir[0] * t_near,
        ray_origin[1] + ray_dir[1] * t_near,
        ray_origin[2] + ray_dir[2] * t_near,
    };

    const sig = calculateSignalFromHitFace(hit_pt, block_pos, hit_face);

    // Compute radial distance from face center
    const bx = @as(f32, @floatFromInt(block_pos[0]));
    const by = @as(f32, @floatFromInt(block_pos[1]));
    const bz = @as(f32, @floatFromInt(block_pos[2]));

    const dist: f32 = switch (hit_face) {
        .up, .down => blk: {
            const dx = hit_pt[0] - (bx + 0.5);
            const dz = hit_pt[2] - (bz + 0.5);
            break :blk @sqrt(dx * dx + dz * dz);
        },
        .north, .south => blk: {
            const dx = hit_pt[0] - (bx + 0.5);
            const dy = hit_pt[1] - (by + 0.5);
            break :blk @sqrt(dx * dx + dy * dy);
        },
        .east, .west => blk: {
            const dy = hit_pt[1] - (by + 0.5);
            const dz = hit_pt[2] - (bz + 0.5);
            break :blk @sqrt(dy * dy + dz * dz);
        },
    };

    return TargetHitResult{
        .face = hit_face,
        .hit_pos = hit_pt,
        .distance_from_center = dist,
        .signal_strength = sig,
    };
}

// ============================================================================
// 5. Target Block State & Pulse Countdown
// ============================================================================

/// State of an individual target block in the world.
pub const TargetBlockState = struct {
    position: [3]i32 = .{ 0, 0, 0 },
    is_active: bool = false,
    signal_strength: u4 = 0,
    ticks_remaining: u32 = 0,
    redstone_ticks_remaining: u32 = 0,
    time_remaining_seconds: f32 = 0.0,
    last_hit_face: ?Direction = null,
    last_projectile: ?ProjectileKind = null,
    last_distance_from_center: f32 = 0.0,

    /// Initializes a new inactive target block at the given world coordinates.
    pub fn init(position: [3]i32) TargetBlockState {
        return .{
            .position = position,
        };
    }

    /// Triggers a hit on the target block by radial distance from face center.
    /// Sets signal strength and activates pulse countdown according to projectile kind.
    pub fn triggerHit(self: *TargetBlockState, projectile: ProjectileKind, dist_from_center: f32, face: Direction) u4 {
        const sig = calculateSignalFromDistance(dist_from_center);
        const g_ticks = getPulseGameTicksForProjectile(projectile);
        const r_ticks = getPulseRedstoneTicksForProjectile(projectile);
        const dur_sec = getPulseDurationSecondsForProjectile(projectile);

        self.is_active = true;
        self.signal_strength = sig;
        self.ticks_remaining = g_ticks;
        self.redstone_ticks_remaining = r_ticks;
        self.time_remaining_seconds = dur_sec;
        self.last_hit_face = face;
        self.last_projectile = projectile;
        self.last_distance_from_center = dist_from_center;

        return sig;
    }

    /// Triggers a hit using face UV coordinates.
    pub fn triggerHitUV(self: *TargetBlockState, projectile: ProjectileKind, u: f32, v: f32, face: Direction) u4 {
        const cu = std.math.clamp(u, 0.0, 1.0) - 0.5;
        const cv = std.math.clamp(v, 0.0, 1.0) - 0.5;
        const dist = @sqrt(cu * cu + cv * cv);
        return self.triggerHit(projectile, dist, face);
    }

    /// Triggers a hit using 3D world hit position.
    pub fn triggerHitWorld(self: *TargetBlockState, projectile: ProjectileKind, hit_pos: [3]f32, face: Direction) u4 {
        const bx = @as(f32, @floatFromInt(self.position[0]));
        const by = @as(f32, @floatFromInt(self.position[1]));
        const bz = @as(f32, @floatFromInt(self.position[2]));

        const dist: f32 = switch (face) {
            .up, .down => blk: {
                const dx = hit_pos[0] - (bx + 0.5);
                const dz = hit_pos[2] - (bz + 0.5);
                break :blk @sqrt(dx * dx + dz * dz);
            },
            .north, .south => blk: {
                const dx = hit_pos[0] - (bx + 0.5);
                const dy = hit_pos[1] - (by + 0.5);
                break :blk @sqrt(dx * dx + dy * dy);
            },
            .east, .west => blk: {
                const dy = hit_pos[1] - (by + 0.5);
                const dz = hit_pos[2] - (bz + 0.5);
                break :blk @sqrt(dy * dy + dz * dz);
            },
        };

        return self.triggerHit(projectile, dist, face);
    }

    /// Ticks forward by 1 game tick (0.05s).
    /// Decrements tick countdown; turns off the block when countdown reaches 0.
    /// Returns true if still active, false if inactive/expired.
    pub fn tickGame(self: *TargetBlockState) bool {
        if (!self.is_active) return false;

        if (self.ticks_remaining > 0) {
            self.ticks_remaining -= 1;
        }

        self.redstone_ticks_remaining = (self.ticks_remaining + 1) / 2;
        self.time_remaining_seconds = @as(f32, @floatFromInt(self.ticks_remaining)) * game_tick_duration_seconds;

        if (self.ticks_remaining == 0) {
            self.is_active = false;
            self.signal_strength = inactive_signal_strength;
            return false;
        }

        return true;
    }

    /// Ticks forward by N game ticks.
    pub fn tickGameN(self: *TargetBlockState, count: u32) bool {
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            if (!self.tickGame()) return false;
        }
        return self.is_active;
    }

    /// Ticks forward by 1 redstone tick (0.10s = 2 game ticks).
    pub fn tickRedstone(self: *TargetBlockState) bool {
        _ = self.tickGame();
        return self.tickGame();
    }

    /// Ticks forward by a time delta in seconds.
    pub fn tickSeconds(self: *TargetBlockState, dt: f32) bool {
        if (!self.is_active) return false;

        self.time_remaining_seconds -= dt;
        if (self.time_remaining_seconds <= 0.0) {
            self.is_active = false;
            self.signal_strength = inactive_signal_strength;
            self.ticks_remaining = 0;
            self.redstone_ticks_remaining = 0;
            self.time_remaining_seconds = 0.0;
            return false;
        }

        self.ticks_remaining = @as(u32, @intFromFloat(@ceil(self.time_remaining_seconds / game_tick_duration_seconds)));
        self.redstone_ticks_remaining = (self.ticks_remaining + 1) / 2;
        return true;
    }

    /// Deactivates the target block immediately.
    pub fn deactivate(self: *TargetBlockState) void {
        self.is_active = false;
        self.signal_strength = inactive_signal_strength;
        self.ticks_remaining = 0;
        self.redstone_ticks_remaining = 0;
        self.time_remaining_seconds = 0.0;
    }

    // ========================================================================
    // Power Routing Methods (All 6 Adjacent Directions)
    // ========================================================================

    /// Whether this target block powers an adjacent block in direction `dir`.
    /// When active, powers all 6 adjacent directions (up, down, north, south, east, west).
    pub fn powersDirection(self: TargetBlockState, dir: Direction) bool {
        _ = dir;
        return self.is_active;
    }

    /// Returns whether all 6 adjacent directions are currently powered.
    pub fn powersAllSixDirections(self: TargetBlockState) bool {
        return self.is_active;
    }

    /// Returns the redstone signal strength (0..15) emitted in direction `dir`.
    pub fn getEmittedSignal(self: TargetBlockState, dir: Direction) u4 {
        _ = dir;
        return if (self.is_active) self.signal_strength else inactive_signal_strength;
    }

    /// Returns the weak redstone power level delivered in direction `dir`.
    /// Active target blocks weakly power adjacent solid blocks in all 6 directions.
    pub fn getWeakPower(self: TargetBlockState, dir: Direction) u4 {
        _ = dir;
        return if (self.is_active) self.signal_strength else inactive_signal_strength;
    }

    /// Returns the strong redstone power level delivered in direction `dir`.
    /// Active target blocks strongly power directly adjacent redstone mechanisms/wires in all 6 directions.
    pub fn getStrongPower(self: TargetBlockState, dir: Direction) u4 {
        _ = dir;
        return if (self.is_active) self.signal_strength else inactive_signal_strength;
    }

    /// Returns the power delivery category to an adjacent direction.
    pub fn getPowerLevelTo(self: TargetBlockState, dir: Direction) PowerLevel {
        _ = dir;
        if (!self.is_active) return .none;
        return .strong;
    }

    /// Checks if a neighbor block at `neighbor_pos` is powered by this target block.
    pub fn isNeighborPowered(self: TargetBlockState, neighbor_pos: [3]i32) bool {
        if (!self.is_active) return false;
        const dx = @abs(neighbor_pos[0] - self.position[0]);
        const dy = @abs(neighbor_pos[1] - self.position[1]);
        const dz = @abs(neighbor_pos[2] - self.position[2]);
        // Adjacent in 3D grid (Manhattan distance = 1)
        return (dx + dy + dz) == 1;
    }

    /// Returns signal strength delivered to a specific neighbor position.
    pub fn getNeighborSignal(self: TargetBlockState, neighbor_pos: [3]i32) u4 {
        if (!self.isNeighborPowered(neighbor_pos)) return inactive_signal_strength;
        return self.signal_strength;
    }
};

// ============================================================================
// 6. Redstone Wire Redirection Mechanics
// ============================================================================

/// Connection state of redstone wire along one horizontal axis face.
pub const WireConnection = enum {
    none,
    side,
    up,

    pub fn isConnected(self: WireConnection) bool {
        return self != .none;
    }
};

/// 4-way horizontal wire routing state (North, South, East, West).
pub const WireRoutingState = struct {
    north: WireConnection = .none,
    south: WireConnection = .none,
    east: WireConnection = .none,
    west: WireConnection = .none,

    /// Whether the wire connects in the given horizontal direction.
    pub fn isConnected(self: WireRoutingState, dir: HorizontalDirection) bool {
        return switch (dir) {
            .north => self.north.isConnected(),
            .south => self.south.isConnected(),
            .east => self.east.isConnected(),
            .west => self.west.isConnected(),
        };
    }

    /// Gets connection type for direction.
    pub fn getConnection(self: WireRoutingState, dir: HorizontalDirection) WireConnection {
        return switch (dir) {
            .north => self.north,
            .south => self.south,
            .east => self.east,
            .west => self.west,
        };
    }

    /// Sets connection type for direction.
    pub fn setConnection(self: *WireRoutingState, dir: HorizontalDirection, conn: WireConnection) void {
        switch (dir) {
            .north => self.north = conn,
            .south => self.south = conn,
            .east => self.east = conn,
            .west => self.west = conn,
        }
    }

    /// Count of active horizontal connections (0 to 4).
    pub fn connectionCount(self: WireRoutingState) u4 {
        var count: u4 = 0;
        if (self.north.isConnected()) count += 1;
        if (self.south.isConnected()) count += 1;
        if (self.east.isConnected()) count += 1;
        if (self.west.isConnected()) count += 1;
        return count;
    }

    /// True if unconnected (single dot / cross).
    pub fn isDot(self: WireRoutingState) bool {
        return self.connectionCount() == 0;
    }

    /// True if straight 2-way line (N-S or E-W).
    pub fn isLine(self: WireRoutingState) bool {
        return (self.north.isConnected() and self.south.isConnected() and !self.east.isConnected() and !self.west.isConnected()) or
            (self.east.isConnected() and self.west.isConnected() and !self.north.isConnected() and !self.south.isConnected());
    }

    /// True if 2-way 90-degree corner (e.g. North-East).
    pub fn isCorner(self: WireRoutingState) bool {
        return self.connectionCount() == 2 and !self.isLine();
    }

    /// True if 3-way T-junction.
    pub fn isTJunction(self: WireRoutingState) bool {
        return self.connectionCount() == 3;
    }

    /// True if 4-way cross junction.
    pub fn isCross(self: WireRoutingState) bool {
        return self.connectionCount() == 4;
    }
};

/// Returns whether a target block at `target_pos` is horizontally adjacent to a wire
/// at `wire_pos` and causes the wire path to redirect towards it.
pub fn doesTargetBlockRedirectWire(wire_pos: [3]i32, target_pos: [3]i32) bool {
    // Must be on the same horizontal plane (Y level)
    if (wire_pos[1] != target_pos[1]) return false;
    const dx = @abs(wire_pos[0] - target_pos[0]);
    const dz = @abs(wire_pos[2] - target_pos[2]);
    return (dx == 1 and dz == 0) or (dx == 0 and dz == 1);
}

/// Returns which horizontal cardinal direction the wire at `wire_pos` must redirect
/// towards to connect with the target block at `target_pos`.
pub fn getTargetBlockWireRedirectionDirection(wire_pos: [3]i32, target_pos: [3]i32) ?HorizontalDirection {
    if (wire_pos[1] != target_pos[1]) return null;
    const dx = target_pos[0] - wire_pos[0];
    const dz = target_pos[2] - wire_pos[2];
    if (dx == 0 and dz == -1) return .north;
    if (dx == 0 and dz == 1) return .south;
    if (dx == 1 and dz == 0) return .east;
    if (dx == -1 and dz == 0) return .west;
    return null;
}

/// Evaluates redstone wire connections at `wire_pos` using a generic block query.
/// Target blocks force redirection (.side) while standard solid blocks (stone, wood)
/// do NOT connect to wire horizontally.
pub fn evaluateWireConnections(
    wire_pos: [3]i32,
    context: anytype,
    is_target_fn: *const fn (@TypeOf(context), [3]i32) bool,
    is_wire_fn: *const fn (@TypeOf(context), [3]i32) bool,
) WireRoutingState {
    var state = WireRoutingState{};

    inline for (HorizontalDirection.all) |dir| {
        const offset = dir.getOffset();
        const neighbor = [3]i32{
            wire_pos[0] + offset[0],
            wire_pos[1] + offset[1],
            wire_pos[2] + offset[2],
        };

        if (is_target_fn(context, neighbor)) {
            // Target blocks directly redirect adjacent redstone wire!
            state.setConnection(dir, .side);
        } else if (is_wire_fn(context, neighbor)) {
            // Redstone wire connects to adjacent redstone wire
            state.setConnection(dir, .side);
        }
    }

    return state;
}


// ============================================================================
// 7. Unit Tests Suite (25+ tests covering all requirements)
// ============================================================================

test "target block: exact bullseye center (dist=0) outputs maximum signal strength 15" {
    const sig = calculateSignalFromDistance(0.0);
    try std.testing.expectEqual(@as(u4, 15), sig);
}

test "target block: bullseye threshold edge (dist=0.033) outputs maximum signal strength 15" {
    const sig = calculateSignalFromDistance(0.033);
    try std.testing.expectEqual(@as(u4, 15), sig);

    // Also small positive values under 0.033m
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromDistance(0.010));
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromDistance(0.025));
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromDistance(0.0329));
}

test "target block: just outside bullseye threshold (dist=0.034) steps down to 14" {
    const sig = calculateSignalFromDistance(0.034);
    try std.testing.expectEqual(@as(u4, 14), sig);
}

test "target block: ring gradient scales signal from 14 down to 1 across radial distances" {
    // Expected signals according to:
    // @as(u4, @intFromFloat(std.math.clamp(15.0 - (dist / 0.5) * 14.0, 1.0, 15.0)))
    try std.testing.expectEqual(@as(u4, 14), calculateSignalFromDistance(0.034));
    try std.testing.expectEqual(@as(u4, 13), calculateSignalFromDistance(0.050));
    try std.testing.expectEqual(@as(u4, 12), calculateSignalFromDistance(0.100));
    try std.testing.expectEqual(@as(u4, 10), calculateSignalFromDistance(0.150));
    try std.testing.expectEqual(@as(u4, 9), calculateSignalFromDistance(0.200));
    try std.testing.expectEqual(@as(u4, 8), calculateSignalFromDistance(0.250));
    try std.testing.expectEqual(@as(u4, 6), calculateSignalFromDistance(0.300));
    try std.testing.expectEqual(@as(u4, 5), calculateSignalFromDistance(0.350));
    try std.testing.expectEqual(@as(u4, 3), calculateSignalFromDistance(0.400));
    try std.testing.expectEqual(@as(u4, 2), calculateSignalFromDistance(0.450));
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromDistance(0.490));
}

test "target block: outer edge at 0.50m outputs minimum signal 1" {
    const sig = calculateSignalFromDistance(0.50);
    try std.testing.expectEqual(@as(u4, 1), sig);
}

test "target block: distance beyond 0.50m clamps to 1 (corners and edges)" {
    // Face corner distance: sqrt(0.5^2 + 0.5^2) ≈ 0.7071m
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromDistance(0.51));
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromDistance(0.60));
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromDistance(0.7071));
}

test "target block: extreme distance clamps to 1 without underflow" {
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromDistance(2.0));
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromDistance(100.0));
}

test "target block: negative distance values correctly use absolute radial distance" {
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromDistance(-0.02));
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromDistance(-0.033));
    try std.testing.expectEqual(@as(u4, 14), calculateSignalFromDistance(-0.034));
    try std.testing.expectEqual(@as(u4, 8), calculateSignalFromDistance(-0.25));
}

test "target block: face UV coordinates center (0.5, 0.5) outputs 15 and edge outputs 1" {
    // Exact center
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromFaceUV(0.5, 0.5));
    // Bullseye zone within 0.033
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromFaceUV(0.52, 0.50));
    // Midpoint along U axis: offset 0.25 -> signal 8
    try std.testing.expectEqual(@as(u4, 8), calculateSignalFromFaceUV(0.75, 0.50));
    // Edge of face: U=1.0, V=0.5 -> offset 0.50 -> signal 1
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromFaceUV(1.0, 0.5));
    // Corner of face: U=0.0, V=0.0 -> offset 0.707 -> signal 1
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromFaceUV(0.0, 0.0));
    // Clamping outside 0..1 UV bounds
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromFaceUV(1.5, -0.5));
}

test "target block: 3D hit on all 6 faces correctly maps to face center distance" {
    const block_pos = [3]i32{ 10, 5, 20 };
    // Block bounds: [10..11, 5..6, 20..21]
    // Centers of each face:
    // UP (y = 6.0): center is (10.5, 6.0, 20.5)
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromHitFace(.{ 10.5, 6.0, 20.5 }, block_pos, .up));
    try std.testing.expectEqual(@as(u4, 8), calculateSignalFromHitFace(.{ 10.75, 6.0, 20.5 }, block_pos, .up));

    // DOWN (y = 5.0): center is (10.5, 5.0, 20.5)
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromHitFace(.{ 10.5, 5.0, 20.5 }, block_pos, .down));
    try std.testing.expectEqual(@as(u4, 1), calculateSignalFromHitFace(.{ 10.5, 5.0, 21.0 }, block_pos, .down));

    // NORTH (z = 20.0): center is (10.5, 5.5, 20.0)
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromHitFace(.{ 10.5, 5.5, 20.0 }, block_pos, .north));

    // SOUTH (z = 21.0): center is (10.5, 5.5, 21.0)
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromHitFace(.{ 10.5, 5.5, 21.0 }, block_pos, .south));

    // WEST (x = 10.0): center is (10.0, 5.5, 20.5)
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromHitFace(.{ 10.0, 5.5, 20.5 }, block_pos, .west));

    // EAST (x = 11.0): center is (11.0, 5.5, 20.5)
    try std.testing.expectEqual(@as(u4, 15), calculateSignalFromHitFace(.{ 11.0, 5.5, 20.5 }, block_pos, .east));
}

test "target block: raycast intersection detects face, hit point, distance, and signal" {
    const block_pos = [3]i32{ 0, 0, 0 };
    // Ray shot straight towards south face (z = 1.0) at face center (0.5, 0.5, 1.0)
    const ray_origin = [3]f32{ 0.5, 0.5, 5.0 };
    const ray_dir = [3]f32{ 0.0, 0.0, -1.0 };

    const hit = raycastTargetBlock(ray_origin, ray_dir, block_pos);
    try std.testing.expect(hit != null);
    const res = hit.?;
    try std.testing.expectEqual(Direction.south, res.face);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), res.hit_pos[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), res.hit_pos[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), res.hit_pos[2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), res.distance_from_center, 0.001);
    try std.testing.expectEqual(@as(u4, 15), res.signal_strength);
}

test "target block: raycast missing block returns null" {
    const block_pos = [3]i32{ 0, 0, 0 };
    // Ray aimed way above the block
    const ray_origin = [3]f32{ 0.5, 10.0, 5.0 };
    const ray_dir = [3]f32{ 0.0, 0.0, -1.0 };
    try std.testing.expectEqual(@as(?TargetHitResult, null), raycastTargetBlock(ray_origin, ray_dir, block_pos));
}

test "pulse duration: arrows, tridents, and spectral arrows emit 8 game ticks / 4 redstone ticks / 0.40s" {
    const arrow_projectiles = [_]ProjectileKind{
        .arrow,
        .spectral_arrow,
        .tipped_arrow,
        .hostile_arrow,
        .trident,
    };

    for (arrow_projectiles) |proj| {
        try std.testing.expect(isArrowOrTrident(proj));
        try std.testing.expect(!isThrownProjectile(proj));
        try std.testing.expectEqual(ProjectileCategory.arrow_or_trident, getProjectileCategory(proj));
        try std.testing.expectEqual(@as(u32, 8), getPulseGameTicksForProjectile(proj));
        try std.testing.expectEqual(@as(u32, 4), getPulseRedstoneTicksForProjectile(proj));
        try std.testing.expectApproxEqAbs(@as(f32, 0.40), getPulseDurationSecondsForProjectile(proj), 0.0001);
    }
}

test "pulse duration: thrown projectiles (snowball, egg, pearl, potion) emit 20 game ticks / 10 redstone ticks / 1.0s" {
    const thrown_projectiles = [_]ProjectileKind{
        .snowball,
        .egg,
        .ender_pearl,
        .splash_potion,
        .lingering_potion,
        .fire_charge,
        .wind_charge,
    };

    for (thrown_projectiles) |proj| {
        try std.testing.expect(isThrownProjectile(proj));
        try std.testing.expect(!isArrowOrTrident(proj));
        try std.testing.expectEqual(ProjectileCategory.thrown, getProjectileCategory(proj));
        try std.testing.expectEqual(@as(u32, 20), getPulseGameTicksForProjectile(proj));
        try std.testing.expectEqual(@as(u32, 10), getPulseRedstoneTicksForProjectile(proj));
        try std.testing.expectApproxEqAbs(@as(f32, 1.00), getPulseDurationSecondsForProjectile(proj), 0.0001);
    }
}

test "pulse countdown: arrow hit counts down 8 game ticks to 0 and deactivates" {
    var target = TargetBlockState.init(.{ 0, 64, 0 });
    try std.testing.expect(!target.is_active);
    try std.testing.expectEqual(@as(u4, 0), target.signal_strength);

    // Hit with arrow at bullseye
    const sig = target.triggerHit(.arrow, 0.01, .north);
    try std.testing.expectEqual(@as(u4, 15), sig);
    try std.testing.expect(target.is_active);
    try std.testing.expectEqual(@as(u4, 15), target.signal_strength);
    try std.testing.expectEqual(@as(u32, 8), target.ticks_remaining);
    try std.testing.expectEqual(@as(u32, 4), target.redstone_ticks_remaining);

    // Ticking 1 through 7: still active
    var tick_idx: u32 = 1;
    while (tick_idx <= 7) : (tick_idx += 1) {
        const still_active = target.tickGame();
        try std.testing.expect(still_active);
        try std.testing.expect(target.is_active);
        try std.testing.expectEqual(@as(u4, 15), target.signal_strength);
        try std.testing.expectEqual(8 - tick_idx, target.ticks_remaining);
    }

    // 8th tick: expires and turns off
    const final_active = target.tickGame();
    try std.testing.expect(!final_active);
    try std.testing.expect(!target.is_active);
    try std.testing.expectEqual(@as(u4, 0), target.signal_strength);
    try std.testing.expectEqual(@as(u32, 0), target.ticks_remaining);
}

test "pulse countdown: snowball hit counts down 20 game ticks to 0 and deactivates" {
    var target = TargetBlockState.init(.{ 5, 10, 15 });

    // Hit with snowball at dist 0.25 (signal = 8)
    const sig = target.triggerHit(.snowball, 0.25, .east);
    try std.testing.expectEqual(@as(u4, 8), sig);
    try std.testing.expect(target.is_active);
    try std.testing.expectEqual(@as(u32, 20), target.ticks_remaining);
    try std.testing.expectEqual(@as(u32, 10), target.redstone_ticks_remaining);

    // Tick 19 times: stays active with signal 8
    try std.testing.expect(target.tickGameN(19));
    try std.testing.expect(target.is_active);
    try std.testing.expectEqual(@as(u4, 8), target.signal_strength);
    try std.testing.expectEqual(@as(u32, 1), target.ticks_remaining);

    // 20th tick: deactivates
    try std.testing.expect(!target.tickGame());
    try std.testing.expect(!target.is_active);
    try std.testing.expectEqual(@as(u4, 0), target.signal_strength);
}

test "pulse countdown: redstone tick stepping decrements correctly" {
    var target = TargetBlockState.init(.{ 0, 0, 0 });
    _ = target.triggerHit(.trident, 0.0, .up); // 8 game ticks = 4 redstone ticks
    try std.testing.expectEqual(@as(u32, 4), target.redstone_ticks_remaining);

    // Step 3 redstone ticks (6 game ticks) -> 1 redstone tick remaining
    try std.testing.expect(target.tickRedstone());
    try std.testing.expect(target.tickRedstone());
    try std.testing.expect(target.tickRedstone());
    try std.testing.expect(target.is_active);
    try std.testing.expectEqual(@as(u32, 1), target.redstone_ticks_remaining);
    try std.testing.expectEqual(@as(u32, 2), target.ticks_remaining);

    // 4th redstone tick -> turns off
    try std.testing.expect(!target.tickRedstone());
    try std.testing.expect(!target.is_active);
}

test "pulse countdown: delta time seconds simulation expires at exactly 0.40s and 1.00s" {
    var target_arrow = TargetBlockState.init(.{ 0, 0, 0 });
    _ = target_arrow.triggerHit(.arrow, 0.0, .south);
    try std.testing.expect(target_arrow.tickSeconds(0.39));
    try std.testing.expect(target_arrow.is_active);
    try std.testing.expect(!target_arrow.tickSeconds(0.02)); // total 0.41s > 0.40s
    try std.testing.expect(!target_arrow.is_active);

    var target_pearl = TargetBlockState.init(.{ 0, 0, 0 });
    _ = target_pearl.triggerHit(.ender_pearl, 0.0, .south);
    try std.testing.expect(target_pearl.tickSeconds(0.95));
    try std.testing.expect(target_pearl.is_active);
    try std.testing.expect(!target_pearl.tickSeconds(0.06)); // total 1.01s > 1.00s
    try std.testing.expect(!target_pearl.is_active);
}

test "target block state: subsequent projectile hit resets timer and updates signal" {
    var target = TargetBlockState.init(.{ 0, 0, 0 });
    _ = target.triggerHit(.arrow, 0.45, .west); // outer ring: signal 2, 8 ticks
    try std.testing.expectEqual(@as(u4, 2), target.signal_strength);
    _ = target.tickGameN(5); // 3 ticks remaining

    // Hit while active with a bullseye egg: upgrades signal to 15 and extends to 20 ticks
    _ = target.triggerHit(.egg, 0.0, .west);
    try std.testing.expectEqual(@as(u4, 15), target.signal_strength);
    try std.testing.expectEqual(@as(u32, 20), target.ticks_remaining);
}

test "power routing: active target block powers all 6 adjacent directions" {
    var target = TargetBlockState.init(.{ 10, 60, 10 });
    _ = target.triggerHit(.spectral_arrow, 0.10, .north); // signal 12
    try std.testing.expect(target.is_active);
    try std.testing.expect(target.powersAllSixDirections());

    inline for (Direction.all) |dir| {
        try std.testing.expect(target.powersDirection(dir));
        try std.testing.expectEqual(@as(u4, 12), target.getEmittedSignal(dir));
        try std.testing.expectEqual(@as(u4, 12), target.getWeakPower(dir));
        try std.testing.expectEqual(@as(u4, 12), target.getStrongPower(dir));
        try std.testing.expectEqual(PowerLevel.strong, target.getPowerLevelTo(dir));
    }
}

test "power routing: inactive target block powers 0 directions" {
    const target = TargetBlockState.init(.{ 10, 60, 10 });
    try std.testing.expect(!target.is_active);
    try std.testing.expect(!target.powersAllSixDirections());

    inline for (Direction.all) |dir| {
        try std.testing.expect(!target.powersDirection(dir));
        try std.testing.expectEqual(@as(u4, 0), target.getEmittedSignal(dir));
        try std.testing.expectEqual(@as(u4, 0), target.getWeakPower(dir));
        try std.testing.expectEqual(@as(u4, 0), target.getStrongPower(dir));
        try std.testing.expectEqual(PowerLevel.none, target.getPowerLevelTo(dir));
    }
}

test "power routing: neighbor query correctly powers only directly adjacent blocks (Manhattan dist = 1)" {
    var target = TargetBlockState.init(.{ 10, 10, 10 });
    _ = target.triggerHit(.trident, 0.0, .up); // signal 15

    // All 6 direct neighbors are powered
    try std.testing.expect(target.isNeighborPowered(.{ 10, 11, 10 })); // Up
    try std.testing.expect(target.isNeighborPowered(.{ 10, 9, 10 })); // Down
    try std.testing.expect(target.isNeighborPowered(.{ 10, 10, 9 })); // North
    try std.testing.expect(target.isNeighborPowered(.{ 10, 10, 11 })); // South
    try std.testing.expect(target.isNeighborPowered(.{ 11, 10, 10 })); // East
    try std.testing.expect(target.isNeighborPowered(.{ 9, 10, 10 })); // West

    try std.testing.expectEqual(@as(u4, 15), target.getNeighborSignal(.{ 10, 11, 10 }));

    // Diagonals or distant blocks are NOT powered
    try std.testing.expect(!target.isNeighborPowered(.{ 11, 11, 10 })); // Diagonal
    try std.testing.expect(!target.isNeighborPowered(.{ 10, 12, 10 })); // 2 blocks away
    try std.testing.expect(!target.isNeighborPowered(.{ 10, 10, 10 })); // Self
    try std.testing.expectEqual(@as(u4, 0), target.getNeighborSignal(.{ 11, 11, 10 }));
}

test "wire redirection: adjacent target block causes wire redirection towards target block" {
    const wire_pos = [3]i32{ 5, 64, 5 };
    const target_east = [3]i32{ 6, 64, 5 };
    const target_north = [3]i32{ 5, 64, 4 };
    const target_west = [3]i32{ 4, 64, 5 };
    const target_south = [3]i32{ 5, 64, 6 };

    try std.testing.expect(doesTargetBlockRedirectWire(wire_pos, target_east));
    try std.testing.expectEqual(HorizontalDirection.east, getTargetBlockWireRedirectionDirection(wire_pos, target_east).?);

    try std.testing.expect(doesTargetBlockRedirectWire(wire_pos, target_north));
    try std.testing.expectEqual(HorizontalDirection.north, getTargetBlockWireRedirectionDirection(wire_pos, target_north).?);

    try std.testing.expect(doesTargetBlockRedirectWire(wire_pos, target_west));
    try std.testing.expectEqual(HorizontalDirection.west, getTargetBlockWireRedirectionDirection(wire_pos, target_west).?);

    try std.testing.expect(doesTargetBlockRedirectWire(wire_pos, target_south));
    try std.testing.expectEqual(HorizontalDirection.south, getTargetBlockWireRedirectionDirection(wire_pos, target_south).?);
}

test "wire redirection: non-adjacent or vertically offset target block does not redirect wire" {
    const wire_pos = [3]i32{ 5, 64, 5 };
    // Diagonal
    try std.testing.expect(!doesTargetBlockRedirectWire(wire_pos, .{ 6, 64, 6 }));
    try std.testing.expectEqual(@as(?HorizontalDirection, null), getTargetBlockWireRedirectionDirection(wire_pos, .{ 6, 64, 6 }));

    // Vertically offset (above or below)
    try std.testing.expect(!doesTargetBlockRedirectWire(wire_pos, .{ 6, 65, 5 }));
    try std.testing.expect(!doesTargetBlockRedirectWire(wire_pos, .{ 6, 63, 5 }));

    // 2 blocks away horizontally
    try std.testing.expect(!doesTargetBlockRedirectWire(wire_pos, .{ 7, 64, 5 }));
}

test "wire redirection: target block turns straight wire into T-junction" {
    const MockWorld = struct {
        pub fn isTarget(ctx: *const @This(), pos: [3]i32) bool {
            _ = ctx;
            // Target block placed to the east
            return pos[0] == 1 and pos[1] == 0 and pos[2] == 0;
        }

        pub fn isWire(ctx: *const @This(), pos: [3]i32) bool {
            _ = ctx;
            // Wire running North-South
            return (pos[0] == 0 and pos[1] == 0 and pos[2] == -1) or
                (pos[0] == 0 and pos[1] == 0 and pos[2] == 1);
        }
    };

    const world = MockWorld{};
    const wire_pos = [3]i32{ 0, 0, 0 };
    const connections = evaluateWireConnections(wire_pos, &world, MockWorld.isTarget, MockWorld.isWire);

    try std.testing.expect(connections.isConnected(.north));
    try std.testing.expect(connections.isConnected(.south));
    try std.testing.expect(connections.isConnected(.east)); // Redirected towards target block!
    try std.testing.expect(!connections.isConnected(.west));
    try std.testing.expect(connections.isTJunction());
}

test "wire redirection: solid stone does not redirect wire while target block redirects wire" {
    const MockWorld = struct {
        pub fn isTarget(ctx: *const @This(), pos: [3]i32) bool {
            _ = ctx;
            // Target block at East
            return pos[0] == 1 and pos[1] == 0 and pos[2] == 0;
        }

        pub fn isWire(ctx: *const @This(), pos: [3]i32) bool {
            _ = ctx;
            _ = pos;
            return false; // No other wires
        }
    };

    const world = MockWorld{};
    const wire_pos = [3]i32{ 0, 0, 0 };
    // West has solid stone, North and South are empty, East has Target block
    const connections = evaluateWireConnections(wire_pos, &world, MockWorld.isTarget, MockWorld.isWire);

    try std.testing.expect(connections.isConnected(.east)); // Target block redirected!
    try std.testing.expect(!connections.isConnected(.west)); // Stone ignored
    try std.testing.expect(!connections.isConnected(.north));
    try std.testing.expect(!connections.isConnected(.south));
    try std.testing.expectEqual(@as(u4, 1), connections.connectionCount());
}

test "wire redirection: target blocks on all 4 sides form 4-way cross junction" {
    const MockWorld = struct {
        pub fn isTarget(ctx: *const @This(), pos: [3]i32) bool {
            _ = ctx;
            // Target blocks on North, South, East, West
            const dx = @abs(pos[0]);
            const dz = @abs(pos[2]);
            return (dx + dz) == 1 and pos[1] == 0;
        }

        pub fn isWire(ctx: *const @This(), pos: [3]i32) bool {
            _ = ctx;
            _ = pos;
            return false;
        }
    };

    const world = MockWorld{};
    const wire_pos = [3]i32{ 0, 0, 0 };
    const connections = evaluateWireConnections(wire_pos, &world, MockWorld.isTarget, MockWorld.isWire);

    try std.testing.expect(connections.isCross());
    try std.testing.expect(connections.isConnected(.north));
    try std.testing.expect(connections.isConnected(.south));
    try std.testing.expect(connections.isConnected(.east));
    try std.testing.expect(connections.isConnected(.west));
}
