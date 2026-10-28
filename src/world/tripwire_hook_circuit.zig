const std = @import("std");
const block_mod = @import("block.zig");
const BlockId = block_mod.BlockId;

// ============================================================================
// Constants
// ============================================================================

/// Maximum distance between two tripwire hooks along a horizontal axis (40 blocks).
pub const max_distance_between_hooks: u32 = 40;

/// Maximum number of unbroken string/tripwire blocks between hooks (up to 40 blocks).
pub const max_string_span: u32 = 40;

/// Alias for maximum span.
pub const max_tripwire_span: u32 = 40;

/// Minimum distance between two tripwire hooks (2 blocks, meaning 1 string block in between).
pub const min_hook_distance: u32 = 2;

/// Maximum redstone signal strength emitted by an active tripwire hook (15).
pub const signal_strength_active: u4 = 15;

/// Minimum redstone signal strength when inactive or unpowered (0).
pub const signal_strength_inactive: u4 = 0;

/// Delay in game ticks that hooks remain powered after all entities exit the tripwire (10 ticks = 0.5s).
pub const exit_delay_game_ticks: u32 = 10;

/// Duration of the redstone pulse triggered when tensioned string is broken without shears (10 ticks = 0.5s).
pub const snap_pulse_game_ticks: u32 = 10;

/// Standard Minecraft game tick duration in seconds (1/20 s = 0.05 s).
pub const game_tick_duration_seconds: f32 = 0.05;

// ============================================================================
// Spatial and Direction Enums
// ============================================================================

/// 3D discrete block coordinate position.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) BlockPos {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn equals(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub fn add(self: BlockPos, other: BlockPos) BlockPos {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn offset(self: BlockPos, dx: i32, dy: i32, dz: i32) BlockPos {
        return .{
            .x = self.x + dx,
            .y = self.y + dy,
            .z = self.z + dz,
        };
    }

    pub fn manhattanDistance(self: BlockPos, other: BlockPos) u32 {
        const dx = @abs(self.x - other.x);
        const dy = @abs(self.y - other.y);
        const dz = @abs(self.z - other.z);
        return @intCast(dx + dy + dz);
    }
};

/// Horizontal axis along which a tripwire line can stretch.
pub const HorizontalAxis = enum {
    x,
    z,
};

/// Cardinal direction a tripwire hook is facing (pointing toward the string line).
pub const HookFacing = enum {
    north,
    south,
    east,
    west,

    pub fn toAxis(self: HookFacing) HorizontalAxis {
        return switch (self) {
            .east, .west => .x,
            .north, .south => .z,
        };
    }

    pub fn opposite(self: HookFacing) HookFacing {
        return switch (self) {
            .north => .south,
            .south => .north,
            .east => .west,
            .west => .east,
        };
    }

    /// Offset from hook position in the direction it faces (toward the string line).
    pub fn forwardOffset(self: HookFacing) BlockPos {
        return switch (self) {
            .east => .{ .x = 1, .y = 0, .z = 0 },
            .west => .{ .x = -1, .y = 0, .z = 0 },
            .south => .{ .x = 0, .y = 0, .z = 1 },
            .north => .{ .x = 0, .y = 0, .z = -1 },
        };
    }

    /// Offset from hook position to the solid block behind it that supports it.
    pub fn attachmentOffset(self: HookFacing) BlockPos {
        return switch (self) {
            .east => .{ .x = -1, .y = 0, .z = 0 },
            .west => .{ .x = 1, .y = 0, .z = 0 },
            .south => .{ .x = 0, .y = 0, .z = -1 },
            .north => .{ .x = 0, .y = 0, .z = 1 },
        };
    }

    /// Validates if two hooks face each other along a straight horizontal axis.
    pub fn areFacingEachOther(pos_a: BlockPos, facing_a: HookFacing, pos_b: BlockPos, facing_b: HookFacing) bool {
        if (pos_a.y != pos_b.y) return false;

        if (pos_a.z == pos_b.z and pos_a.x != pos_b.x) {
            if (pos_a.x < pos_b.x) {
                return facing_a == .east and facing_b == .west;
            } else {
                return facing_a == .west and facing_b == .east;
            }
        }

        if (pos_a.x == pos_b.x and pos_a.z != pos_b.z) {
            if (pos_a.z < pos_b.z) {
                return facing_a == .south and facing_b == .north;
            } else {
                return facing_a == .north and facing_b == .south;
            }
        }

        return false;
    }
};

/// Audio sound events emitted during tripwire circuit lifecycle.
pub const SoundEvent = enum {
    none,
    mechanical_click,
    click_on,
    click_off,
    tension_snap,
};

/// Physical entity types that can collide with tripwire string.
pub const EntityKind = enum {
    player,
    mob,
    arrow,
    dropped_item,
    boat,
    minecart,

    /// Returns true if this entity kind is physical and interacts with tripwire.
    pub fn isPhysical(self: EntityKind) bool {
        return switch (self) {
            .player, .mob, .arrow, .dropped_item, .boat, .minecart => true,
        };
    }

    /// Whether this entity triggers tripwire power upon entering a string block.
    pub fn triggersTripwire(self: EntityKind) bool {
        return self.isPhysical();
    }
};

/// Axis-aligned bounding box for physical entity position checking.
pub const AABB = struct {
    min_x: f32,
    min_y: f32,
    min_z: f32,
    max_x: f32,
    max_y: f32,
    max_z: f32,

    pub fn init(min_x: f32, min_y: f32, min_z: f32, max_x: f32, max_y: f32, max_z: f32) AABB {
        return .{
            .min_x = min_x,
            .min_y = min_y,
            .min_z = min_z,
            .max_x = max_x,
            .max_y = max_y,
            .max_z = max_z,
        };
    }

    pub fn fromCenterSize(center_x: f32, center_y: f32, center_z: f32, width: f32, height: f32) AABB {
        const hw = width * 0.5;
        return .{
            .min_x = center_x - hw,
            .min_y = center_y,
            .min_z = center_z - hw,
            .max_x = center_x + hw,
            .max_y = center_y + height,
            .max_z = center_z + hw,
        };
    }

    pub fn intersectsBlock(self: AABB, pos: BlockPos) bool {
        const bx = @as(f32, @floatFromInt(pos.x));
        const by = @as(f32, @floatFromInt(pos.y));
        const bz = @as(f32, @floatFromInt(pos.z));
        return self.max_x > bx and self.min_x < bx + 1.0 and
            self.max_y > by and self.min_y < by + 1.0 and
            self.max_z > bz and self.min_z < bz + 1.0;
    }
};

/// Tools or methods used to break or defuse tripwire string blocks.
pub const DefusalTool = enum {
    shears,
    bare_hand,
    sword,
    pickaxe,
    axe,
    shovel,
    hoe,
    projectile,
    other,

    pub fn isShears(self: DefusalTool) bool {
        return self == .shears;
    }

    pub fn triggersTensionSnap(self: DefusalTool) bool {
        return self != .shears;
    }
};

/// Result of breaking a string block in an active or inactive tripwire circuit.
pub const BreakResult = struct {
    string_removed: bool,
    defused_safely: bool,
    tension_snapped: bool,
    triggered_pulse: bool,
    pulse_duration_ticks: u32,
    redstone_signal: u4,
    sound: SoundEvent,
};

/// Error states during circuit formation or validation.
pub const CircuitError = error{
    MisalignedAxis,
    DifferentElevation,
    InvalidFacing,
    NotFacingEachOther,
    TooClose,
    DistanceExceeded,
    AttachmentNotSolid,
    BrokenStringLine,
    MissingHook,
};

// ============================================================================
// State Representations
// ============================================================================

/// State of an individual tripwire hook.
pub const TripwireHookState = struct {
    pos: BlockPos,
    facing: HookFacing,
    attached: bool = false,
    powered: bool = false,
    signal: u4 = signal_strength_inactive,

    pub fn getBlockId(self: TripwireHookState) BlockId {
        return if (self.powered) .tripwire_hook_on else .tripwire_hook_off;
    }
};

/// State of an individual string / tripwire block.
pub const TripwireStringState = struct {
    pos: BlockPos,
    attached: bool = false,
    powered: bool = false,
    disarmed: bool = false,
};

// ============================================================================
// Circuit Validation Helpers
// ============================================================================

/// Validates hook distance is within valid bounds (2..40 blocks).
pub fn validateCircuitDistance(distance: u32) !void {
    if (distance < min_hook_distance) return error.TooClose;
    if (distance > max_distance_between_hooks) return error.DistanceExceeded;
}

/// Validates number of string blocks between hooks (1..40 blocks).
pub fn validateStringCount(string_count: u32) !void {
    if (string_count < 1) return error.TooClose;
    if (string_count > max_string_span) return error.DistanceExceeded;
}

/// Helper to validate if a string span count is in acceptable range (1..40).
pub fn isValidStringSpan(count: u32) bool {
    return count >= 1 and count <= max_string_span;
}

/// Validates geometry and alignment between two potential hook positions and facings.
pub fn validateCircuitPositions(
    pos_a: BlockPos,
    facing_a: HookFacing,
    pos_b: BlockPos,
    facing_b: HookFacing,
) !struct { axis: HorizontalAxis, distance: u32, string_count: u32 } {
    if (pos_a.y != pos_b.y) return error.DifferentElevation;

    if (pos_a.z == pos_b.z) {
        // Horizontal axis X
        if (pos_a.x == pos_b.x) return error.TooClose;
        const dx = @as(i64, pos_b.x) - @as(i64, pos_a.x);
        const dist: u32 = @intCast(@abs(dx));
        try validateCircuitDistance(dist);

        if (dx > 0) {
            // A is west of B -> A must face East, B must face West
            if (facing_a != .east or facing_b != .west) return error.NotFacingEachOther;
        } else {
            // A is east of B -> A must face West, B must face East
            if (facing_a != .west or facing_b != .east) return error.NotFacingEachOther;
        }
        return .{
            .axis = .x,
            .distance = dist,
            .string_count = dist - 1,
        };
    } else if (pos_a.x == pos_b.x) {
        // Horizontal axis Z
        const dz = @as(i64, pos_b.z) - @as(i64, pos_a.z);
        const dist: u32 = @intCast(@abs(dz));
        try validateCircuitDistance(dist);

        if (dz > 0) {
            // A is north of B -> A must face South, B must face North
            if (facing_a != .south or facing_b != .north) return error.NotFacingEachOther;
        } else {
            // A is south of B -> A must face North, B must face South
            if (facing_a != .north or facing_b != .south) return error.NotFacingEachOther;
        }
        return .{
            .axis = .z,
            .distance = dist,
            .string_count = dist - 1,
        };
    } else {
        return error.MisalignedAxis;
    }
}

/// Generic block lookup adapter supporting function pointers, structs, or closures.
fn worldGetBlock(world: anytype, pos: BlockPos) BlockId {
    const W = @TypeOf(world);
    if (W == *const fn (i32, i32, i32) BlockId or W == fn (i32, i32, i32) BlockId) {
        return world(pos.x, pos.y, pos.z);
    } else if (W == *const fn (BlockPos) BlockId or W == fn (BlockPos) BlockId) {
        return world(pos);
    } else if (@typeInfo(W) == .pointer and @hasDecl(std.meta.Child(W), "getBlock")) {
        return world.getBlock(pos.x, pos.y, pos.z);
    } else if (@hasDecl(W, "getBlock")) {
        return world.getBlock(pos.x, pos.y, pos.z);
    } else {
        @compileError("Unsupported world lookup type: expected fn(x,y,z) BlockId or getBlock method");
    }
}

// ============================================================================
// Tripwire Circuit Implementation
// ============================================================================

/// Tripwire tension circuit linking two hooks and an unbroken span of string blocks.
pub const TripwireCircuit = struct {
    hook_a: TripwireHookState,
    hook_b: TripwireHookState,
    axis: HorizontalAxis,
    string_count: u32,
    distance: u32,

    attached: bool = false,
    powered: bool = false,
    active_entities: u32 = 0,
    delay_ticks_remaining: u32 = 0,
    is_snap_pulsing: bool = false,
    string_broken: bool = false,
    last_sound: SoundEvent = .none,

    /// Initializes a valid circuit along the given axis with a specified hook distance (2..40 blocks).
    pub fn init(axis: HorizontalAxis, distance: u32) !TripwireCircuit {
        try validateCircuitDistance(distance);
        const string_count = distance - 1;

        const pos_a = BlockPos.init(0, 64, 0);
        const facing_a: HookFacing = if (axis == .x) .east else .south;
        const pos_b = if (axis == .x)
            BlockPos.init(@intCast(distance), 64, 0)
        else
            BlockPos.init(0, 64, @intCast(distance));
        const facing_b: HookFacing = if (axis == .x) .west else .north;

        return initFromValidGeometry(pos_a, facing_a, pos_b, facing_b, axis, string_count);
    }

    /// Initializes a circuit specifying the number of string blocks between hooks (1..39 strings).
    pub fn initWithStringCount(axis: HorizontalAxis, string_count: u32) !TripwireCircuit {
        return init(axis, string_count + 1);
    }

    /// Initializes a valid circuit from validated hook positions and facings.
    pub fn initFromValidGeometry(
        pos_a: BlockPos,
        facing_a: HookFacing,
        pos_b: BlockPos,
        facing_b: HookFacing,
        axis: HorizontalAxis,
        string_count: u32,
    ) !TripwireCircuit {
        return .{
            .hook_a = .{
                .pos = pos_a,
                .facing = facing_a,
                .attached = true,
                .powered = false,
                .signal = signal_strength_inactive,
            },
            .hook_b = .{
                .pos = pos_b,
                .facing = facing_b,
                .attached = true,
                .powered = false,
                .signal = signal_strength_inactive,
            },
            .axis = axis,
            .string_count = string_count,
            .distance = string_count + 1,
            .attached = true,
            .powered = false,
            .active_entities = 0,
            .delay_ticks_remaining = 0,
            .is_snap_pulsing = false,
            .string_broken = false,
            .last_sound = .mechanical_click,
        };
    }

    /// Initializes and validates a circuit from arbitrary hook coordinates.
    pub fn initFromHooks(
        pos_a: BlockPos,
        facing_a: HookFacing,
        pos_b: BlockPos,
        facing_b: HookFacing,
    ) !TripwireCircuit {
        const geom = try validateCircuitPositions(pos_a, facing_a, pos_b, facing_b);
        return initFromValidGeometry(pos_a, facing_a, pos_b, facing_b, geom.axis, geom.string_count);
    }

    /// Computes the 3D block coordinate of the string at zero-based index `i`.
    pub fn getStringPos(self: *const TripwireCircuit, index: u32) ?BlockPos {
        if (index >= self.string_count) return null;
        const fwd = self.hook_a.facing.forwardOffset();
        const step: i32 = @intCast(index + 1);
        return .{
            .x = self.hook_a.pos.x + fwd.x * step,
            .y = self.hook_a.pos.y,
            .z = self.hook_a.pos.z + fwd.z * step,
        };
    }

    /// Checks if a given coordinate lies on the circuit's string line.
    pub fn containsStringPos(self: *const TripwireCircuit, pos: BlockPos) bool {
        if (pos.y != self.hook_a.pos.y) return false;
        if (self.axis == .x) {
            if (pos.z != self.hook_a.pos.z) return false;
            const min_x = @min(self.hook_a.pos.x, self.hook_b.pos.x);
            const max_x = @max(self.hook_a.pos.x, self.hook_b.pos.x);
            return pos.x > min_x and pos.x < max_x;
        } else {
            if (pos.x != self.hook_a.pos.x) return false;
            const min_z = @min(self.hook_a.pos.z, self.hook_b.pos.z);
            const max_z = @max(self.hook_a.pos.z, self.hook_b.pos.z);
            return pos.z > min_z and pos.z < max_z;
        }
    }

    /// An entity enters the string line. Triggers redstone power (strength 15).
    pub fn entityEnter(self: *TripwireCircuit, kind: EntityKind) void {
        if (!kind.isPhysical()) return;
        self.active_entities += 1;
        self.powered = true;
        self.hook_a.powered = true;
        self.hook_b.powered = true;
        self.hook_a.signal = signal_strength_active;
        self.hook_b.signal = signal_strength_active;
        self.delay_ticks_remaining = exit_delay_game_ticks;
        self.last_sound = .click_on;
    }

    /// An entity exits the string line. Hooks remain powered for 10 game ticks.
    pub fn entityExit(self: *TripwireCircuit, kind: EntityKind) void {
        _ = kind;
        if (self.active_entities > 0) {
            self.active_entities -= 1;
        }
        if (self.active_entities == 0) {
            // Re-arm or refresh 10-tick countdown starting now
            self.delay_ticks_remaining = exit_delay_game_ticks;
        }
    }

    /// Checks bounding box collision with any string block of the circuit.
    pub fn checkEntityCollision(self: *TripwireCircuit, kind: EntityKind, box: AABB) bool {
        if (!kind.isPhysical()) return false;
        var i: u32 = 0;
        while (i < self.string_count) : (i += 1) {
            if (self.getStringPos(i)) |spos| {
                if (box.intersectsBlock(spos)) {
                    self.entityEnter(kind);
                    return true;
                }
            }
        }
        return false;
    }

    /// Breaks a string in the circuit using the specified tool.
    /// - Shears: defuses safely with zero power and no pulse.
    /// - Non-shears: snaps tension and triggers a 10-tick redstone pulse (signal 15).
    pub fn breakString(self: *TripwireCircuit, tool: DefusalTool) BreakResult {
        self.string_broken = true;
        const was_attached = self.attached;
        self.attached = false;
        self.hook_a.attached = false;
        self.hook_b.attached = false;

        if (tool.isShears()) {
            // Safe shears defusal
            self.powered = false;
            self.hook_a.powered = false;
            self.hook_b.powered = false;
            self.hook_a.signal = signal_strength_inactive;
            self.hook_b.signal = signal_strength_inactive;
            self.delay_ticks_remaining = 0;
            self.is_snap_pulsing = false;
            self.last_sound = .none;

            return .{
                .string_removed = true,
                .defused_safely = true,
                .tension_snapped = false,
                .triggered_pulse = false,
                .pulse_duration_ticks = 0,
                .redstone_signal = signal_strength_inactive,
                .sound = .none,
            };
        } else {
            // Non-shears break: bare hand, weapon, tool, projectile
            if (was_attached) {
                // Tension snap pulse
                self.powered = true;
                self.hook_a.powered = true;
                self.hook_b.powered = true;
                self.hook_a.signal = signal_strength_active;
                self.hook_b.signal = signal_strength_active;
                self.delay_ticks_remaining = snap_pulse_game_ticks;
                self.is_snap_pulsing = true;
                self.last_sound = .tension_snap;

                return .{
                    .string_removed = true,
                    .defused_safely = false,
                    .tension_snapped = true,
                    .triggered_pulse = true,
                    .pulse_duration_ticks = snap_pulse_game_ticks,
                    .redstone_signal = signal_strength_active,
                    .sound = .tension_snap,
                };
            } else {
                return .{
                    .string_removed = true,
                    .defused_safely = false,
                    .tension_snapped = false,
                    .triggered_pulse = false,
                    .pulse_duration_ticks = 0,
                    .redstone_signal = signal_strength_inactive,
                    .sound = .none,
                };
            }
        }
    }

    /// Convenience wrapper taking boolean `with_shears`.
    pub fn breakStringSafeOrSnap(self: *TripwireCircuit, with_shears: bool) BreakResult {
        return self.breakString(if (with_shears) .shears else .bare_hand);
    }

    /// Advances the circuit state by one 20 Hz game tick (0.05 s).
    pub fn tick(self: *TripwireCircuit) void {
        self.last_sound = .none;

        if (self.active_entities > 0) {
            // Entity remains inside the tripwire
            self.powered = true;
            self.hook_a.powered = true;
            self.hook_b.powered = true;
            self.hook_a.signal = signal_strength_active;
            self.hook_b.signal = signal_strength_active;
            self.delay_ticks_remaining = exit_delay_game_ticks;
        } else if (self.delay_ticks_remaining > 0) {
            // Counting down the 10-tick delay or snap pulse
            self.delay_ticks_remaining -= 1;
            if (self.delay_ticks_remaining == 0) {
                // Timer expired: hooks turn off
                self.powered = false;
                self.hook_a.powered = false;
                self.hook_b.powered = false;
                self.hook_a.signal = signal_strength_inactive;
                self.hook_b.signal = signal_strength_inactive;
                self.is_snap_pulsing = false;
                self.last_sound = .click_off;
            } else {
                // Still within active pulse/delay window
                self.powered = true;
                self.hook_a.powered = true;
                self.hook_b.powered = true;
                self.hook_a.signal = signal_strength_active;
                self.hook_b.signal = signal_strength_active;
            }
        } else {
            // Idle and unpowered
            self.powered = false;
            self.hook_a.powered = false;
            self.hook_b.powered = false;
            self.hook_a.signal = signal_strength_inactive;
            self.hook_b.signal = signal_strength_inactive;
            self.is_snap_pulsing = false;
        }
    }

    /// Advances the circuit by multiple game ticks.
    pub fn advanceTicks(self: *TripwireCircuit, count: u32) void {
        var i: u32 = 0;
        while (i < count) : (i += 1) {
            self.tick();
        }
    }

    /// Returns current emitted redstone signal strength.
    pub fn getSignal(self: *const TripwireCircuit) u4 {
        return self.hook_a.signal;
    }

    /// Whether the hooks are currently emitting redstone signal strength 15.
    pub fn isEmittingRedstone(self: *const TripwireCircuit) bool {
        return self.powered and self.hook_a.signal == signal_strength_active;
    }

    /// Disarms / detaches the circuit (e.g. when hooks or attachments are destroyed).
    pub fn detach(self: *TripwireCircuit) void {
        self.attached = false;
        self.hook_a.attached = false;
        self.hook_b.attached = false;
        self.last_sound = .click_off;
    }
};

// ============================================================================
// World Validation & Scanning
// ============================================================================

/// Validates world blocks and forms a circuit between two hooks.
/// - Checks hook presence and opposing facings.
/// - Checks solid attachment blocks behind both hooks.
/// - Checks unbroken string blocks between the hooks.
/// - Distance must be <= 40 blocks.
pub fn validateWorldCircuit(
    world: anytype,
    pos_a: BlockPos,
    facing_a: HookFacing,
    pos_b: BlockPos,
    facing_b: HookFacing,
) !TripwireCircuit {
    const geom = try validateCircuitPositions(pos_a, facing_a, pos_b, facing_b);

    // Verify hooks are placed at both positions
    const block_a = worldGetBlock(world, pos_a);
    if (block_a != .tripwire_hook_off and block_a != .tripwire_hook_on) {
        return error.MissingHook;
    }
    const block_b = worldGetBlock(world, pos_b);
    if (block_b != .tripwire_hook_off and block_b != .tripwire_hook_on) {
        return error.MissingHook;
    }

    // Verify solid attachment block behind hook A
    const attach_a = pos_a.add(facing_a.attachmentOffset());
    const block_attach_a = worldGetBlock(world, attach_a);
    if (!block_attach_a.is_solid()) {
        return error.AttachmentNotSolid;
    }

    // Verify solid attachment block behind hook B
    const attach_b = pos_b.add(facing_b.attachmentOffset());
    const block_attach_b = worldGetBlock(world, attach_b);
    if (!block_attach_b.is_solid()) {
        return error.AttachmentNotSolid;
    }

    // Verify unbroken string line between hooks
    const fwd = facing_a.forwardOffset();
    var cur = pos_a.add(fwd);
    var i: u32 = 0;
    while (i < geom.string_count) : (i += 1) {
        const b = worldGetBlock(world, cur);
        if (b != .tripwire) {
            return error.BrokenStringLine;
        }
        cur = cur.add(fwd);
    }

    return TripwireCircuit.initFromValidGeometry(pos_a, facing_a, pos_b, facing_b, geom.axis, geom.string_count);
}

/// Scans forward from a hook position in facing direction to discover and form a circuit.
pub fn scanAndFormCircuit(world: anytype, hook_pos: BlockPos, facing: HookFacing) ?TripwireCircuit {
    // Check hook block at hook_pos
    const start_block = worldGetBlock(world, hook_pos);
    if (start_block != .tripwire_hook_off and start_block != .tripwire_hook_on) return null;

    // Check solid attachment block behind starting hook
    const attach_start = hook_pos.add(facing.attachmentOffset());
    if (!worldGetBlock(world, attach_start).is_solid()) return null;

    const fwd = facing.forwardOffset();
    var cur = hook_pos.add(fwd);
    var dist: u32 = 1;

    while (dist <= max_distance_between_hooks) : (dist += 1) {
        const b = worldGetBlock(world, cur);
        if (b == .tripwire_hook_off or b == .tripwire_hook_on) {
            if (dist < min_hook_distance) return null; // Adjacent hooks without string
            const other_facing = facing.opposite();
            const attach_end = cur.add(other_facing.attachmentOffset());
            if (!worldGetBlock(world, attach_end).is_solid()) return null;

            return TripwireCircuit.initFromValidGeometry(
                hook_pos,
                facing,
                cur,
                other_facing,
                facing.toAxis(),
                dist - 1,
            ) catch null;
        }

        if (b != .tripwire) {
            return null; // Broken string or obstruction
        }

        cur = cur.add(fwd);
    }

    return null;
}

// ============================================================================
// Unit Tests
// ============================================================================

test "1. Circuit formation: valid 2-block distance (1 string block) forms attached circuit" {
    const circuit = try TripwireCircuit.init(.x, 2);
    try std.testing.expect(circuit.attached);
    try std.testing.expect(circuit.hook_a.attached);
    try std.testing.expect(circuit.hook_b.attached);
    try std.testing.expectEqual(@as(u32, 2), circuit.distance);
    try std.testing.expectEqual(@as(u32, 1), circuit.string_count);
    try std.testing.expectEqual(SoundEvent.mechanical_click, circuit.last_sound);
}

test "2. Circuit formation: valid 40-block maximum distance forms attached circuit" {
    // Maximum distance: 40 blocks (39 string blocks between hooks)
    const circuit = try TripwireCircuit.initFromHooks(
        BlockPos.init(0, 64, 0),
        .east,
        BlockPos.init(40, 64, 0),
        .west,
    );
    try std.testing.expect(circuit.attached);
    try std.testing.expectEqual(@as(u32, 40), circuit.distance);
    try std.testing.expectEqual(@as(u32, 39), circuit.string_count);
    try std.testing.expectEqual(SoundEvent.mechanical_click, circuit.last_sound);
}

test "3. Circuit formation: valid 40-block distance via init(.x, 40)" {
    const circuit = try TripwireCircuit.init(.x, 40);
    try std.testing.expect(circuit.attached);
    try std.testing.expectEqual(@as(u32, 40), circuit.distance);
    try std.testing.expectEqual(@as(u32, 39), circuit.string_count);
    try std.testing.expect(circuit.hook_a.attached);
    try std.testing.expect(circuit.hook_b.attached);
}

test "4. Circuit formation: rejection beyond 40-block distance (41 blocks distance rejected)" {
    const err = TripwireCircuit.initFromHooks(
        BlockPos.init(0, 64, 0),
        .east,
        BlockPos.init(41, 64, 0),
        .west,
    );
    try std.testing.expectError(error.DistanceExceeded, err);
}

test "5. Circuit formation: rejection beyond 40-block distance via init(.x, 41)" {
    const err = TripwireCircuit.init(.x, 41);
    try std.testing.expectError(error.DistanceExceeded, err);
}

test "6. Circuit formation: hook facing alignment on X axis (East faces West)" {
    const valid = try TripwireCircuit.initFromHooks(
        BlockPos.init(10, 64, 5),
        .east,
        BlockPos.init(15, 64, 5),
        .west,
    );
    try std.testing.expect(valid.attached);
    try std.testing.expectEqual(HorizontalAxis.x, valid.axis);
}

test "7. Circuit formation: hook facing alignment on Z axis (South faces North)" {
    const valid = try TripwireCircuit.initFromHooks(
        BlockPos.init(5, 64, 10),
        .south,
        BlockPos.init(5, 64, 25),
        .north,
    );
    try std.testing.expect(valid.attached);
    try std.testing.expectEqual(HorizontalAxis.z, valid.axis);
    try std.testing.expectEqual(@as(u32, 15), valid.distance);
    try std.testing.expectEqual(@as(u32, 14), valid.string_count);
}

test "8. Circuit formation: rejection when hooks face same direction" {
    const err = TripwireCircuit.initFromHooks(
        BlockPos.init(0, 64, 0),
        .east,
        BlockPos.init(10, 64, 0),
        .east, // Both facing East!
    );
    try std.testing.expectError(error.NotFacingEachOther, err);
}

test "9. Circuit formation: rejection when hooks face away from each other" {
    const err = TripwireCircuit.initFromHooks(
        BlockPos.init(0, 64, 0),
        .west, // Facing away (-X)
        BlockPos.init(10, 64, 0),
        .east, // Facing away (+X)
    );
    try std.testing.expectError(error.NotFacingEachOther, err);
}

test "10. Circuit formation: rejection when hooks are misaligned diagonally" {
    const err = TripwireCircuit.initFromHooks(
        BlockPos.init(0, 64, 0),
        .east,
        BlockPos.init(10, 64, 5), // diagonal Z offset
        .west,
    );
    try std.testing.expectError(error.MisalignedAxis, err);
}

test "11. Circuit formation: rejection when hooks are at different Y elevations" {
    const err = TripwireCircuit.initFromHooks(
        BlockPos.init(0, 64, 0),
        .east,
        BlockPos.init(10, 65, 0), // Y = 65 vs 64
        .west,
    );
    try std.testing.expectError(error.DifferentElevation, err);
}

test "12. Circuit formation: rejection when hooks are too close (distance 1, 0 strings)" {
    const err = TripwireCircuit.initFromHooks(
        BlockPos.init(0, 64, 0),
        .east,
        BlockPos.init(1, 64, 0), // distance 1
        .west,
    );
    try std.testing.expectError(error.TooClose, err);
}

test "13. Circuit formation: rejection when attachment block behind hook is air (not solid)" {
    const MockWorld = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (x == 0 and y == 64 and z == 0) return .tripwire_hook_off;
            if (x == 5 and y == 64 and z == 0) return .tripwire_hook_off;
            if (x > 0 and x < 5 and y == 64 and z == 0) return .tripwire;
            if (x == -1 and y == 64 and z == 0) return .air; // Non-solid behind hook A!
            if (x == 6 and y == 64 and z == 0) return .stone; // Solid behind hook B
            return .air;
        }
    };

    const err = validateWorldCircuit(
        MockWorld.get,
        BlockPos.init(0, 64, 0),
        .east,
        BlockPos.init(5, 64, 0),
        .west,
    );
    try std.testing.expectError(error.AttachmentNotSolid, err);
}

test "14. Circuit formation: rejection when string line is broken by non-string block" {
    const MockWorld = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (x == 0 and y == 64 and z == 0) return .tripwire_hook_off;
            if (x == 5 and y == 64 and z == 0) return .tripwire_hook_off;
            if (x == -1 and y == 64 and z == 0) return .cobblestone; // Solid behind A
            if (x == 6 and y == 64 and z == 0) return .cobblestone; // Solid behind B
            if (x == 1 or x == 2 or x == 4) return .tripwire;
            if (x == 3) return .air; // String line broken!
            return .air;
        }
    };

    const err = validateWorldCircuit(
        MockWorld.get,
        BlockPos.init(0, 64, 0),
        .east,
        BlockPos.init(5, 64, 0),
        .west,
    );
    try std.testing.expectError(error.BrokenStringLine, err);
}

test "15. Circuit formation: successful world validation with solid backing and unbroken strings" {
    const MockWorld = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (x == 0 and y == 64 and z == 0) return .tripwire_hook_off;
            if (x == 6 and y == 64 and z == 0) return .tripwire_hook_off;
            if (x == -1 and y == 64 and z == 0) return .wood_planks; // Solid
            if (x == 7 and y == 64 and z == 0) return .stone; // Solid
            if (x >= 1 and x <= 5 and y == 64 and z == 0) return .tripwire;
            return .air;
        }
    };

    const circuit = try validateWorldCircuit(
        MockWorld.get,
        BlockPos.init(0, 64, 0),
        .east,
        BlockPos.init(6, 64, 0),
        .west,
    );
    try std.testing.expect(circuit.attached);
    try std.testing.expectEqual(@as(u32, 5), circuit.string_count);
    try std.testing.expectEqual(SoundEvent.mechanical_click, circuit.last_sound);
}

test "16. Entity collision: player entering string block triggers powered=true and signal 15" {
    var circuit = try TripwireCircuit.init(.x, 6);
    try std.testing.expect(!circuit.powered);
    try std.testing.expectEqual(@as(u4, 0), circuit.getSignal());

    circuit.entityEnter(.player);
    try std.testing.expect(circuit.powered);
    try std.testing.expect(circuit.hook_a.powered);
    try std.testing.expect(circuit.hook_b.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.hook_a.signal);
    try std.testing.expectEqual(@as(u4, 15), circuit.hook_b.signal);
    try std.testing.expectEqual(BlockId.tripwire_hook_on, circuit.hook_a.getBlockId());
    try std.testing.expectEqual(BlockId.tripwire_hook_on, circuit.hook_b.getBlockId());
}

test "17. Entity collision: mob entering string block triggers powered=true and signal 15" {
    var circuit = try TripwireCircuit.init(.z, 4);
    circuit.entityEnter(.mob);
    try std.testing.expect(circuit.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());
}

test "18. Entity collision: projectile arrow entering string block triggers powered=true and signal 15" {
    var circuit = try TripwireCircuit.init(.x, 5);
    circuit.entityEnter(.arrow);
    try std.testing.expect(circuit.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());
}

test "19. Entity collision: dropped item entering string block triggers powered=true and signal 15" {
    var circuit = try TripwireCircuit.init(.x, 3);
    circuit.entityEnter(.dropped_item);
    try std.testing.expect(circuit.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());
}

test "20. Entity collision: boat and minecart vehicles trigger powered=true and signal 15" {
    var circuit_boat = try TripwireCircuit.init(.x, 5);
    circuit_boat.entityEnter(.boat);
    try std.testing.expect(circuit_boat.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit_boat.getSignal());

    var circuit_cart = try TripwireCircuit.init(.x, 5);
    circuit_cart.entityEnter(.minecart);
    try std.testing.expect(circuit_cart.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit_cart.getSignal());
}

test "21. Redstone pulse timing: entity exit retains signal 15 for exactly 10 game ticks then drops to 0" {
    var circuit = try TripwireCircuit.init(.x, 6);
    circuit.entityEnter(.player);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());

    // Entity exits
    circuit.entityExit(.player);
    try std.testing.expect(circuit.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());
    try std.testing.expectEqual(@as(u32, 10), circuit.delay_ticks_remaining);

    // Ticks 1 to 9: still powered with signal 15
    var tick_idx: u32 = 1;
    while (tick_idx <= 9) : (tick_idx += 1) {
        circuit.tick();
        try std.testing.expect(circuit.powered);
        try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());
        try std.testing.expectEqual(10 - tick_idx, circuit.delay_ticks_remaining);
    }

    // Tick 10: 10th tick elapses, timer reaches 0, hooks turn OFF
    circuit.tick();
    try std.testing.expect(!circuit.powered);
    try std.testing.expect(!circuit.hook_a.powered);
    try std.testing.expect(!circuit.hook_b.powered);
    try std.testing.expectEqual(@as(u4, 0), circuit.getSignal());
    try std.testing.expectEqual(@as(u32, 0), circuit.delay_ticks_remaining);
    try std.testing.expectEqual(SoundEvent.click_off, circuit.last_sound);
}

test "22. Redstone pulse timing: entity re-entry during delay countdown maintains active signal" {
    var circuit = try TripwireCircuit.init(.x, 6);
    circuit.entityEnter(.player);
    circuit.entityExit(.player);

    // Tick 4 times (delay at 6)
    circuit.advanceTicks(4);
    try std.testing.expectEqual(@as(u32, 6), circuit.delay_ticks_remaining);
    try std.testing.expect(circuit.powered);

    // Mob enters during countdown!
    circuit.entityEnter(.mob);
    circuit.tick();
    try std.testing.expect(circuit.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());
    try std.testing.expectEqual(@as(u32, 10), circuit.delay_ticks_remaining);

    // Mob stays for 5 ticks
    circuit.advanceTicks(5);
    try std.testing.expect(circuit.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());

    // Mob exits: full 10 ticks countdown starts fresh
    circuit.entityExit(.mob);
    circuit.advanceTicks(9);
    try std.testing.expect(circuit.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());

    circuit.tick(); // 10th tick
    try std.testing.expect(!circuit.powered);
    try std.testing.expectEqual(@as(u4, 0), circuit.getSignal());
}

test "23. Shears defusal: breaking string with shears removes string safely WITHOUT powering hooks or signal" {
    var circuit = try TripwireCircuit.init(.x, 6);
    try std.testing.expect(circuit.attached);

    const result = circuit.breakString(.shears);
    try std.testing.expect(result.string_removed);
    try std.testing.expect(result.defused_safely);
    try std.testing.expect(!result.tension_snapped);
    try std.testing.expect(!result.triggered_pulse);
    try std.testing.expectEqual(@as(u32, 0), result.pulse_duration_ticks);
    try std.testing.expectEqual(@as(u4, 0), result.redstone_signal);

    // Hooks are disarmed without emitting any redstone power
    try std.testing.expect(!circuit.attached);
    try std.testing.expect(!circuit.powered);
    try std.testing.expect(!circuit.hook_a.powered);
    try std.testing.expect(!circuit.hook_b.powered);
    try std.testing.expectEqual(@as(u4, 0), circuit.getSignal());
    try std.testing.expectEqual(@as(u32, 0), circuit.delay_ticks_remaining);

    // Ticking produces no pulses
    circuit.tick();
    try std.testing.expect(!circuit.powered);
    try std.testing.expectEqual(@as(u4, 0), circuit.getSignal());
}

test "24. Non-shears breaking: breaking string with bare hand triggers 10-tick redstone pulse on hooks" {
    var circuit = try TripwireCircuit.init(.x, 6);
    try std.testing.expect(circuit.attached);

    const result = circuit.breakString(.bare_hand);
    try std.testing.expect(result.string_removed);
    try std.testing.expect(!result.defused_safely);
    try std.testing.expect(result.tension_snapped);
    try std.testing.expect(result.triggered_pulse);
    try std.testing.expectEqual(@as(u32, 10), result.pulse_duration_ticks);
    try std.testing.expectEqual(@as(u4, 15), result.redstone_signal);
    try std.testing.expectEqual(SoundEvent.tension_snap, result.sound);

    // Circuit is broken, but emits a 10-tick pulse of strength 15
    try std.testing.expect(!circuit.attached);
    try std.testing.expect(circuit.powered);
    try std.testing.expect(circuit.hook_a.powered);
    try std.testing.expect(circuit.hook_b.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());
    try std.testing.expectEqual(@as(u32, 10), circuit.delay_ticks_remaining);

    // Ticks 1 to 9: still pulsing with signal 15
    circuit.advanceTicks(9);
    try std.testing.expect(circuit.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());

    // Tick 10: pulse ends, power drops to 0
    circuit.tick();
    try std.testing.expect(!circuit.powered);
    try std.testing.expectEqual(@as(u4, 0), circuit.getSignal());
}

test "25. Non-shears breaking: breaking string with sword or pickaxe triggers tension snap pulse" {
    var circuit_sword = try TripwireCircuit.init(.x, 4);
    const res_sword = circuit_sword.breakString(.sword);
    try std.testing.expect(res_sword.tension_snapped);
    try std.testing.expect(res_sword.triggered_pulse);
    try std.testing.expectEqual(@as(u4, 15), res_sword.redstone_signal);

    var circuit_pick = try TripwireCircuit.init(.x, 4);
    const res_pick = circuit_pick.breakString(.pickaxe);
    try std.testing.expect(res_pick.tension_snapped);
    try std.testing.expect(res_pick.triggered_pulse);
    try std.testing.expectEqual(@as(u4, 15), res_pick.redstone_signal);
}

test "26. Non-shears breaking: projectile breaking string triggers tension snap pulse" {
    var circuit = try TripwireCircuit.init(.x, 7);
    const result = circuit.breakString(.projectile);
    try std.testing.expect(result.tension_snapped);
    try std.testing.expect(result.triggered_pulse);
    try std.testing.expectEqual(@as(u4, 15), result.redstone_signal);
    try std.testing.expectEqual(SoundEvent.tension_snap, result.sound);
}

test "27. World scanner: scanAndFormCircuit finds and attaches remote hook" {
    const MockWorld = struct {
        fn get(x: i32, y: i32, z: i32) BlockId {
            if (x == 0 and y == 64 and z == 0) return .tripwire_hook_off;
            if (x == 10 and y == 64 and z == 0) return .tripwire_hook_off;
            if (x == -1 and y == 64 and z == 0) return .stone;
            if (x == 11 and y == 64 and z == 0) return .stone;
            if (x >= 1 and x <= 9 and y == 64 and z == 0) return .tripwire;
            return .air;
        }
    };

    const circuit = scanAndFormCircuit(
        MockWorld.get,
        BlockPos.init(0, 64, 0),
        .east,
    );
    try std.testing.expect(circuit != null);
    const c = circuit.?;
    try std.testing.expect(c.attached);
    try std.testing.expectEqual(@as(u32, 9), c.string_count);
    try std.testing.expectEqual(@as(u32, 10), c.distance);
    try std.testing.expectEqual(BlockPos.init(10, 64, 0), c.hook_b.pos);
    try std.testing.expectEqual(HookFacing.west, c.hook_b.facing);
}

test "28. Bounding box entity collision triggers string activation" {
    var circuit = try TripwireCircuit.init(.x, 6);
    // String blocks are at x=1..5, y=64, z=0
    const entity_box = AABB.fromCenterSize(3.5, 64.0, 0.5, 0.6, 1.8);
    try std.testing.expect(circuit.checkEntityCollision(.player, entity_box));
    try std.testing.expect(circuit.powered);
    try std.testing.expectEqual(@as(u4, 15), circuit.getSignal());
}
