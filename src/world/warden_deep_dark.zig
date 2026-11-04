const std = @import("std");

/// Maximum range in blocks within which a mob death activates a Sculk Catalyst.
pub const catalyst_range: f32 = 8.0;

/// Squared detection radius for Sculk Catalyst mob death detection.
pub const catalyst_range_sq: f32 = catalyst_range * catalyst_range; // 64.0

/// High XP thresholds for spawning rare sculk growths during a catalyst soul bloom.
pub const high_xp_sensor_threshold: u16 = 20;
pub const high_xp_shrieker_threshold: u16 = 50;

/// Sculk Shrieker timing and warning thresholds.
pub const shriek_cooldown_seconds: f32 = 10.0;
pub const warning_decay_seconds: f32 = 600.0;
pub const darkness_duration_seconds: f32 = 12.0;
pub const max_warning_level: u3 = 4;
pub const warden_summon_level: u3 = 4;

/// Warden physical, sensory, and behavioral constants.
pub const warden_max_hp: f32 = 500.0;
pub const warden_melee_damage: f32 = 30.0;
pub const warden_smell_range: f32 = 24.0;
pub const warden_smell_range_sq: f32 = warden_smell_range * warden_smell_range; // 576.0
pub const warden_smell_interval: f32 = 5.0;
pub const smell_anger_bonus: u8 = 10;
pub const vibration_anger_bonus: u8 = 35;
pub const projectile_anger_bonus: u8 = 10;
pub const max_warden_anger: u8 = 150;
pub const agitated_anger_threshold: u8 = 40;
pub const roaring_attack_threshold: u8 = 80;
pub const burrow_timeout_seconds: f32 = 60.0;

/// Sonic Boom combat constants.
pub const sonic_boom_horizontal_range: f32 = 15.0;
pub const sonic_boom_vertical_range: f32 = 20.0;
pub const sonic_boom_base_damage: f32 = 10.0;
pub const sonic_boom_knockback_horiz_force: f32 = 2.5;
pub const sonic_boom_knockback_vert_force: f32 = 0.5;

/// Block identifiers relevant to Deep Dark generation and catalyst conversions.
pub const DeepDarkBlock = enum(u16) {
    air = 0,
    stone = 1,
    dirt = 2,
    deepslate = 3,
    sculk = 178,
    sculk_sensor = 179,
    sculk_vein = 181,
    sculk_shrieker = 182,
    sculk_catalyst = 183,
};

/// Returns whether `block` can be converted into sculk by a catalyst soul bloom.
pub fn isConvertibleBlock(block: DeepDarkBlock) bool {
    return block == .stone or block == .dirt or block == .deepslate;
}

/// Calculates the soul-bloom spread radius in blocks based on the dropped mob XP.
/// Scales progressively from 0 up to a maximum radius of 8 blocks.
pub fn sculkSpreadRadius(xp: u16) u8 {
    if (xp == 0) return 0;
    if (xp <= 5) return 1;
    if (xp <= 15) return 2;
    if (xp <= 30) return 3;
    if (xp <= 50) return 4;
    if (xp <= 80) return 5;
    if (xp <= 120) return 6;
    if (xp <= 200) return 7;
    return 8;
}

/// Determines the resulting block type when a convertible block is reached by a soul-bloom charge.
/// High-XP kills have a chance to generate Sculk Shriekers (XP >= 50) or Sculk Sensors (XP >= 20).
/// Inner regions convert to solid Sculk, while the perimeter converts to Sculk Veins.
pub fn convertBlock(block: DeepDarkBlock, xp: u16, distance_to_origin: f32, roll: u8) ?DeepDarkBlock {
    if (!isConvertibleBlock(block)) return null;

    if (xp >= high_xp_shrieker_threshold and roll < 15) {
        return .sculk_shrieker;
    } else if (xp >= high_xp_sensor_threshold and roll < 40) {
        return .sculk_sensor;
    }

    const max_rad = @as(f32, @floatFromInt(sculkSpreadRadius(xp)));
    if (distance_to_origin <= max_rad * 0.7) {
        return .sculk;
    } else {
        return .sculk_vein;
    }
}

/// A soul-bloom charge originating from a mob death near a catalyst.
pub const BloomCharge = struct {
    origin_x: i32,
    origin_y: i32,
    origin_z: i32,
    xp_amount: u16,
    spread_radius: u8,

    pub fn init(origin_x: i32, origin_y: i32, origin_z: i32, xp: u16) BloomCharge {
        return .{
            .origin_x = origin_x,
            .origin_y = origin_y,
            .origin_z = origin_z,
            .xp_amount = xp,
            .spread_radius = sculkSpreadRadius(xp),
        };
    }

    pub fn isWithinSpread(self: BloomCharge, bx: i32, by: i32, bz: i32) bool {
        const dx = bx - self.origin_x;
        const dy = by - self.origin_y;
        const dz = bz - self.origin_z;
        const dist_sq = dx * dx + dy * dy + dz * dz;
        const r = @as(i32, self.spread_radius);
        return dist_sq <= r * r;
    }
};

/// Sculk Catalyst block entity tracking nearby mob deaths and blooming soul charges.
pub const SculkCatalyst = struct {
    x: i32,
    y: i32,
    z: i32,
    bloom_active: bool = false,
    bloom_timer: f32 = 0.0,
    charges_absorbed: u32 = 0,
    total_xp_consumed: u32 = 0,

    pub fn init(x: i32, y: i32, z: i32) SculkCatalyst {
        return .{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    /// When a mob dies at (mob_x, mob_y, mob_z) dropping `xp_amount`.
    /// Returns a `BloomCharge` if the death occurred within 8.0 blocks (64.0 sq distance) and xp > 0.
    pub fn onMobDeath(self: *SculkCatalyst, mob_x: f32, mob_y: f32, mob_z: f32, xp_amount: u16) ?BloomCharge {
        if (xp_amount == 0) return null;

        const cx = @as(f32, @floatFromInt(self.x)) + 0.5;
        const cy = @as(f32, @floatFromInt(self.y)) + 0.5;
        const cz = @as(f32, @floatFromInt(self.z)) + 0.5;
        const dx = cx - mob_x;
        const dy = cy - mob_y;
        const dz = cz - mob_z;
        const dist_sq = dx * dx + dy * dy + dz * dz;

        if (dist_sq > catalyst_range_sq) return null;

        self.bloom_active = true;
        self.bloom_timer = 2.0;
        self.charges_absorbed += 1;
        self.total_xp_consumed += xp_amount;

        return BloomCharge.init(
            @intFromFloat(@floor(mob_x)),
            @intFromFloat(@floor(mob_y)),
            @intFromFloat(@floor(mob_z)),
            xp_amount,
        );
    }

    pub fn tick(self: *SculkCatalyst, dt: f32) void {
        if (self.bloom_timer > 0.0) {
            self.bloom_timer = @max(0.0, self.bloom_timer - dt);
            if (self.bloom_timer <= 0.0) {
                self.bloom_active = false;
            }
        }
    }
};

/// Result of attempting to trigger a Sculk Shrieker.
pub const ShriekResult = struct {
    shrieked: bool,
    warning_incremented: bool,
    warning_level: u3,
    summon_warden: bool,
    darkness_inflicted: bool,
};

/// Player warning level tracker for Sculk Shrieker activations and Warden summoning.
pub const SculkShriekerWarning = struct {
    warning_level: u3 = 0,
    cooldown_timer: f32 = 0.0,
    decay_timer: f32 = 0.0,
    darkness_timer: f32 = 0.0,

    pub fn init() SculkShriekerWarning {
        return .{};
    }

    /// Triggers a Sculk Shrieker.
    /// `can_summon` is true for naturally generated shriekers and false for player-placed ones.
    /// A 10.0s cooldown blocks rapid shriek increments. Warning decays 1 level every 600.0s.
    /// Warning level 4 summons the Warden and inflicts 12.0s of Darkness.
    pub fn triggerShriek(self: *SculkShriekerWarning, can_summon: bool) ShriekResult {
        if (self.cooldown_timer > 0.0) {
            return .{
                .shrieked = false,
                .warning_incremented = false,
                .warning_level = self.warning_level,
                .summon_warden = false,
                .darkness_inflicted = false,
            };
        }

        self.cooldown_timer = shriek_cooldown_seconds;

        if (!can_summon) {
            return .{
                .shrieked = true,
                .warning_incremented = false,
                .warning_level = self.warning_level,
                .summon_warden = false,
                .darkness_inflicted = false,
            };
        }

        self.decay_timer = warning_decay_seconds;

        if (self.warning_level < max_warning_level) {
            self.warning_level += 1;
        }

        const summon = (self.warning_level == warden_summon_level);
        if (summon) {
            self.darkness_timer = darkness_duration_seconds;
        }

        return .{
            .shrieked = true,
            .warning_incremented = true,
            .warning_level = self.warning_level,
            .summon_warden = summon,
            .darkness_inflicted = summon,
        };
    }

    /// Triggers the Sculk Shrieker from player interaction or stepping at (player_x, player_y, player_z)
    /// on shrieker block (shrieker_x, shrieker_y, shrieker_z).
    pub fn trigger(
        self: *SculkShriekerWarning,
        player_x: f32,
        player_y: f32,
        player_z: f32,
        shrieker_x: i32,
        shrieker_y: i32,
        shrieker_z: i32,
    ) ShriekResult {
        _ = player_x;
        _ = player_y;
        _ = player_z;
        _ = shrieker_x;
        _ = shrieker_y;
        _ = shrieker_z;
        return self.triggerShriek(true);
    }

    pub fn tick(self: *SculkShriekerWarning, dt: f32) void {
        if (self.cooldown_timer > 0.0) {
            self.cooldown_timer = @max(0.0, self.cooldown_timer - dt);
        }

        if (self.darkness_timer > 0.0) {
            self.darkness_timer = @max(0.0, self.darkness_timer - dt);
        }

        if (self.warning_level > 0) {
            self.decay_timer -= dt;
            if (self.decay_timer <= 0.0) {
                self.warning_level -= 1;
                if (self.warning_level > 0) {
                    self.decay_timer = warning_decay_seconds;
                } else {
                    self.decay_timer = 0.0;
                }
            }
        }
    }

    pub fn hasDarkness(self: SculkShriekerWarning) bool {
        return self.darkness_timer > 0.0;
    }

    pub fn applyDarkness(self: *SculkShriekerWarning, duration: f32) void {
        self.darkness_timer = @max(self.darkness_timer, duration);
    }
};

/// Computes the vision-pulsing fog factor [0.0..1.0] for the Darkness effect.
/// Modulates visibility rhythmically over the 12.0s duration.
pub fn computeDarknessFogIntensity(darkness_timer: f32) f32 {
    if (darkness_timer <= 0.0) return 0.0;
    const elapsed = darkness_duration_seconds - darkness_timer;
    const fade: f32 = if (elapsed < 0.8)
        elapsed / 0.8
    else if (darkness_timer < 1.0)
        darkness_timer / 1.0
    else
        1.0;

    const wave = 0.675 + 0.325 * @sin(elapsed * 2.5);
    return @max(0.0, @min(1.0, fade * wave));
}

/// Dynamic fog distances resulting from the Darkness status effect.
pub fn computeDarknessFogDistances(fog_intensity: f32) struct { start: f32, end: f32 } {
    const normal_start: f32 = 32.0;
    const normal_end: f32 = 64.0;
    const dark_start: f32 = 4.0;
    const dark_end: f32 = 15.0;
    return .{
        .start = normal_start - fog_intensity * (normal_start - dark_start),
        .end = normal_end - fog_intensity * (normal_end - dark_end),
    };
}

/// Behavioral state of the Warden.
pub const WardenState = enum {
    calm,
    agitated,
    roaring_attack,
    burrowing,
};

/// Warden anger tracker and sensory AI state machine.
pub const WardenAngerTracker = struct {
    hp: f32 = warden_max_hp,
    anger: u8 = 0,
    smell_cooldown: f32 = 0.0,
    decay_accumulator: f32 = 0.0,
    zero_vibration_timer: f32 = 0.0,
    is_burrowed: bool = false,

    pub fn init() WardenAngerTracker {
        return .{};
    }

    pub fn getState(self: WardenAngerTracker) WardenState {
        if (self.is_burrowed) return .burrowing;
        if (self.anger >= roaring_attack_threshold) return .roaring_attack;
        if (self.anger >= agitated_anger_threshold) return .agitated;
        return .calm;
    }

    pub fn addAnger(self: *WardenAngerTracker, amount: u8) void {
        const sum = @as(u16, self.anger) + @as(u16, amount);
        self.anger = @intCast(@min(@as(u16, max_warden_anger), sum));
    }

    pub fn decayAnger(self: *WardenAngerTracker, dt: f32) void {
        self.decay_accumulator += dt;
        while (self.decay_accumulator >= 1.0) : (self.decay_accumulator -= 1.0) {
            if (self.anger > 0) {
                self.anger -= 1;
            }
        }
    }

    /// Target tracking via smell (+10 anger every 5.0s within 24m)
    pub fn trackSmell(self: *WardenAngerTracker, target_dist: f32, dt: f32) bool {
        if (self.is_burrowed) return false;
        if (target_dist > warden_smell_range) return false;

        self.smell_cooldown += dt;
        if (self.smell_cooldown >= warden_smell_interval) {
            self.smell_cooldown -= warden_smell_interval;
            self.addAnger(smell_anger_bonus);
            return true;
        }
        return false;
    }

    /// Direct smell sniff event (+10 anger within 24m)
    pub fn onSmell(self: *WardenAngerTracker, target_dist: f32) bool {
        if (self.is_burrowed) return false;
        if (target_dist <= warden_smell_range) {
            self.addAnger(smell_anger_bonus);
            return true;
        }
        return false;
    }

    /// Vibration sensed (+35 anger per vibration, +10 if projectile distraction)
    pub fn onVibration(self: *WardenAngerTracker, is_projectile_distraction: bool) void {
        self.zero_vibration_timer = 0.0;
        self.is_burrowed = false;

        if (is_projectile_distraction) {
            self.addAnger(projectile_anger_bonus);
        } else {
            self.addAnger(vibration_anger_bonus);
        }
    }

    pub fn tick(self: *WardenAngerTracker, dt: f32) void {
        if (self.is_burrowed) return;

        // Anger decays by -1 per second
        self.decayAnger(dt);

        // Track duration with zero vibrations; burrows back underground after 60.0s
        self.zero_vibration_timer += dt;
        if (self.zero_vibration_timer >= burrow_timeout_seconds) {
            self.is_burrowed = true;
        }
    }
};

fn getCoordinate3D(pos: anytype) struct { x: f32, y: f32, z: f32 } {
    const T = @TypeOf(pos);
    if (@typeInfo(T) == .array) {
        return .{ .x = pos[0], .y = pos[1], .z = pos[2] };
    } else if (@typeInfo(T) == .@"struct") {
        if (@hasField(T, "x") and @hasField(T, "y") and @hasField(T, "z")) {
            return .{ .x = pos.x, .y = pos.y, .z = pos.z };
        } else if (@hasField(T, "0") and @hasField(T, "1") and @hasField(T, "2")) {
            return .{ .x = pos[0], .y = pos[1], .z = pos[2] };
        }
    }
    @compileError("Position must be [3]f32 or struct with fields x, y, z");
}

/// Checks if a target is within Sonic Boom horizontal (15m) and vertical (20m) range.
pub fn isTargetInSonicBoomRange(warden_pos: anytype, target_pos: anytype) bool {
    const wp = getCoordinate3D(warden_pos);
    const tp = getCoordinate3D(target_pos);
    const dx = tp.x - wp.x;
    const dy = tp.y - wp.y;
    const dz = tp.z - wp.z;
    const horiz_dist_sq = dx * dx + dz * dz;
    const vert_dist = @abs(dy);
    return horiz_dist_sq <= (sonic_boom_horizontal_range * sonic_boom_horizontal_range) and
        vert_dist <= sonic_boom_vertical_range;
}

/// Computes the Sonic Boom attack when target is unreachable by melee pathing.
/// Fires a block-piercing, shield-bypassing, armor-bypassing attack dealing 10.0 magic damage.
pub fn computeSonicBoomAttack(warden_pos: anytype, target_pos: anytype, armor_reduction: f32) struct {
    damage: f32,
    knockback_vx: f32,
    knockback_vy: f32,
    knockback_vz: f32,
} {
    // Sonic Boom completely bypasses armor; armor_reduction is ignored.
    _ = armor_reduction;

    const wp = getCoordinate3D(warden_pos);
    const tp = getCoordinate3D(target_pos);

    const dx = tp.x - wp.x;
    const dy = tp.y - wp.y;
    const dz = tp.z - wp.z;

    const horiz_dist_sq = dx * dx + dz * dz;
    const vert_dist = @abs(dy);

    if (horiz_dist_sq > (sonic_boom_horizontal_range * sonic_boom_horizontal_range) or
        vert_dist > sonic_boom_vertical_range)
    {
        return .{
            .damage = 0.0,
            .knockback_vx = 0.0,
            .knockback_vy = 0.0,
            .knockback_vz = 0.0,
        };
    }

    const horiz_dist = @sqrt(horiz_dist_sq);
    var vx: f32 = 0.0;
    var vz: f32 = 0.0;
    if (horiz_dist > 1e-4) {
        vx = (dx / horiz_dist) * sonic_boom_knockback_horiz_force;
        vz = (dz / horiz_dist) * sonic_boom_knockback_horiz_force;
    }
    const vy = sonic_boom_knockback_vert_force;

    return .{
        .damage = sonic_boom_base_damage,
        .knockback_vx = vx,
        .knockback_vy = vy,
        .knockback_vz = vz,
    };
}


// ============================================================================
// Warden Scent Blast Mechanics (unified from warden_scent_blast.zig)
// ============================================================================

pub const TICKS_PER_SECOND: u32 = 20;
pub const SCENT_RANGE: f32 = 16.0;
pub const SCENT_INTERVAL_TICKS: u32 = 84;
pub const SCENT_SUSPICION: u16 = 35;
pub const CALM_SUSPICION_LIMIT: u16 = 40;
pub const ROAR_SUSPICION_LIMIT: u16 = 80;
pub const CHASE_SUSPICION_LIMIT: u16 = 150;
pub const ROAR_DURATION_TICKS: u32 = 40;
pub const CALM_DECAY_INTERVAL_TICKS: u32 = 20;
pub const CALM_WANDER_SPEED: f32 = 1.0;
pub const CHASE_SPEED: f32 = 4.2;
pub const SONIC_BLAST_REACH: f32 = 15.0;
pub const SONIC_BLAST_DAMAGE: f32 = 10.0;
pub const SONIC_BLAST_VERTICAL_KNOCKBACK: f32 = 6.0;
pub const SONIC_BLAST_HORIZONTAL_KNOCKBACK: f32 = 8.0;

pub const Position = struct { x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0 };

pub fn distance(a: Position, b: Position) f32 {
    const dx = a.x - b.x;
    const dy = a.y - b.y;
    const dz = a.z - b.z;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

pub const Player = struct {
    id: u32,
    position: Position = .{},
    suspicion: u16 = 0,
    health: f32 = 20.0,
    armor_points: f32 = 0.0,
    shield_blocking: bool = false,
    velocity: Velocity = .{},
};

pub const Velocity = struct { x: f32 = 0.0, y: f32 = 0.0, z: f32 = 0.0 };

pub const State = enum { calm, agitated, roaring, chasing };

pub const TickEvents = struct {
    sniff_animation: bool = false,
    sniffed_player_id: ?u32 = null,
    roar_started: bool = false,
    turned_toward_player_id: ?u32 = null,
};

pub const Warden = struct {
    position: Position = .{},
    state: State = .calm,
    target_player_id: ?u32 = null,
    sniff_ticks: u32 = 0,
    calm_decay_ticks: u32 = 0,
    roar_ticks_remaining: u32 = 0,
    heard_vibration_this_tick: bool = false,

    pub fn init(position: Position) Warden {
        return .{ .position = position };
    }

    pub fn movementSpeed(self: Warden) f32 {
        return switch (self.state) {
            .calm => CALM_WANDER_SPEED,
            .agitated, .roaring => 0.0,
            .chasing => CHASE_SPEED,
        };
    }

    pub fn isChasing(self: Warden) bool {
        return self.state == .chasing;
    }

    /// A vibration identifies its source and raises that player's suspicion by
    /// the caller-supplied amount. Sniffing independently contributes 35 points.
    pub fn hearVibration(self: *Warden, player: *Player, suspicion: u16) void {
        player.suspicion = @min(std.math.maxInt(u16), player.suspicion +| suspicion);
        self.target_player_id = player.id;
        self.heard_vibration_this_tick = true;
        self.refreshState(player);
    }

    fn refreshState(self: *Warden, player: *Player) void {
        if (player.suspicion >= CHASE_SUSPICION_LIMIT) {
            self.state = .chasing;
            self.target_player_id = player.id;
            self.roar_ticks_remaining = 0;
        } else if (player.suspicion >= ROAR_SUSPICION_LIMIT) {
            if (self.state != .roaring) {
                self.state = .roaring;
                self.roar_ticks_remaining = ROAR_DURATION_TICKS;
            }
            self.target_player_id = player.id;
        } else if (player.suspicion >= CALM_SUSPICION_LIMIT) {
            self.state = .agitated;
            self.target_player_id = player.id;
            self.roar_ticks_remaining = 0;
        } else if (self.state != .chasing) {
            self.state = .calm;
            self.roar_ticks_remaining = 0;
        }
    }

    fn nearestPlayer(self: Warden, players: []Player) ?usize {
        var nearest: ?usize = null;
        var nearest_distance = SCENT_RANGE;
        for (players, 0..) |player, index| {
            const player_distance = distance(self.position, player.position);
            if (player_distance <= nearest_distance) {
                if (nearest == null or player_distance < nearest_distance) {
                    nearest = index;
                    nearest_distance = player_distance;
                }
            }
        }
        return nearest;
    }

    /// Advances one 20 Hz tick and returns animation/targeting events. Players
    /// are mutable because scent adds directly to their suspicion meters.
    pub fn tick(self: *Warden, players: []Player) TickEvents {
        const initial_state = self.state;
        var events = TickEvents{};

        if (self.state == .roaring) {
            if (self.roar_ticks_remaining > 0) self.roar_ticks_remaining -= 1;
            if (self.roar_ticks_remaining == 0) self.state = .agitated;
        }

        if (self.state != .chasing) {
            self.sniff_ticks += 1;
            if (self.sniff_ticks >= SCENT_INTERVAL_TICKS) {
                self.sniff_ticks = 0;
                events.sniff_animation = true;
                if (self.nearestPlayer(players)) |index| {
                    const suspect = &players[index];
                    suspect.suspicion = @min(std.math.maxInt(u16), suspect.suspicion +| SCENT_SUSPICION);
                    self.target_player_id = suspect.id;
                    events.sniffed_player_id = suspect.id;
                    self.refreshState(suspect);
                }
            }
        } else {
            self.sniff_ticks = 0;
        }

        if (self.state == .agitated) {
            if (self.target_player_id) |target_id| events.turned_toward_player_id = target_id;
        }

        if (self.state == .calm and !self.heard_vibration_this_tick) {
            self.calm_decay_ticks += 1;
            if (self.calm_decay_ticks >= CALM_DECAY_INTERVAL_TICKS) {
                self.calm_decay_ticks = 0;
                for (players) |*player| {
                    if (player.suspicion > 0) player.suspicion -= 1;
                }
            }
        } else {
            self.calm_decay_ticks = 0;
        }
        events.roar_started = initial_state != .roaring and self.state == .roaring;
        self.heard_vibration_this_tick = false;
        return events;
    }
};

pub const SonicBlastResult = struct {
    hit: bool,
    damage: f32 = 0.0,
    knockback: Velocity = .{},
};

/// Horizontal reach models the penetrating beam: terrain and walls do not
/// occlude it. Vertical separation does not shorten its horizontal travel.
pub fn resolveSonicBlast(warden: Position, target: Position) SonicBlastResult {
    const dx = target.x - warden.x;
    const dz = target.z - warden.z;
    const horizontal_distance = @sqrt(dx * dx + dz * dz);
    if (horizontal_distance > SONIC_BLAST_REACH) return .{ .hit = false };
    if (horizontal_distance <= 0.0001) return .{
        .hit = true,
        .damage = SONIC_BLAST_DAMAGE,
        .knockback = .{ .y = SONIC_BLAST_VERTICAL_KNOCKBACK },
    };
    return .{
        .hit = true,
        .damage = SONIC_BLAST_DAMAGE,
        .knockback = .{
            .x = dx / horizontal_distance * SONIC_BLAST_HORIZONTAL_KNOCKBACK,
            .y = SONIC_BLAST_VERTICAL_KNOCKBACK,
            .z = dz / horizontal_distance * SONIC_BLAST_HORIZONTAL_KNOCKBACK,
        },
    };
}

/// Applies the penetrating hit directly, bypassing armor and shields.
pub fn hitPlayerWithSonicBlast(warden: Position, player: *Player) bool {
    const result = resolveSonicBlast(warden, player.position);
    if (!result.hit) return false;
    player.health = @max(0.0, player.health - result.damage);
    player.velocity = result.knockback;
    return true;
}


// ============================================================================
// Warden Sonic Boom & Emergence Mechanics (unified from warden_sonic_boom.zig)
// ============================================================================

pub const WARDEN_MAX_HEALTH: f32 = 500.0;
pub const WARDEN_MELEE_DAMAGE: f32 = 30.0;
pub const WARDEN_HOSTILE_SPEED: f32 = 4.2;
pub const WARDEN_SNIFF_RANGE: f32 = 16.0;
pub const WARDEN_SNIFF_INTERVAL_TICKS: u32 = 100;
pub const WARDEN_OPTICAL_SIGHT_RANGE: f32 = 0.0;
pub const VIBRATION_AGITATION: u16 = 35;
pub const ROAR_AGITATION_THRESHOLD: u16 = 80;
pub const HOSTILE_AGITATION_THRESHOLD: u16 = 150;
pub const EMERGENCE_TICKS: u32 = 134;
pub const CALM_BURROW_TICKS: u32 = 1200;
pub const SONIC_BOOM_RANGE: f32 = 15.0;
pub const SONIC_BOOM_DAMAGE: f32 = 10.0;
pub const SONIC_BOOM_CHARGE_TICKS: u32 = 34;
pub const SONIC_BOOM_COOLDOWN_TICKS: u32 = 100;
pub const SONIC_BOOM_VERTICAL_IMPULSE: f32 = 6.0;
pub const SONIC_BOOM_HORIZONTAL_IMPULSE: f32 = 8.0;
pub const DARKNESS_RADIUS: f32 = 20.0;
pub const DARKNESS_PULSE_TICKS: u32 = 120;
pub const MELEE_RANGE: f32 = 3.0;


pub const SonicBoomImpulse = struct { vx: f32, vy: f32, vz: f32 };

/// The beam passes through blocks and bypasses armor and shields. Direction is
/// computed from Warden to target; a coincident target receives a vertical lift.
pub fn sonicBoomImpulse(warden: Position, target: Position) SonicBoomImpulse {
    const dx = target.x - warden.x;
    const dz = target.z - warden.z;
    const horizontal = @sqrt(dx * dx + dz * dz);
    if (horizontal <= 0.0001) return .{ .vx = 0.0, .vy = SONIC_BOOM_VERTICAL_IMPULSE, .vz = 0.0 };
    return .{
        .vx = dx / horizontal * SONIC_BOOM_HORIZONTAL_IMPULSE,
        .vy = SONIC_BOOM_VERTICAL_IMPULSE,
        .vz = dz / horizontal * SONIC_BOOM_HORIZONTAL_IMPULSE,
    };
}

pub const WardenBehavior = struct {
    // Compatibility aliases
    pub const WardenSonicBoom = WardenBehavior;

    position: Position = .{},
    health: f32 = WARDEN_MAX_HEALTH,
    agitation: u16 = 0,
    is_emerging: bool = true,
    emergence_ticks_remaining: u32 = EMERGENCE_TICKS,
    is_burrowing: bool = false,
    despawned: bool = false,
    hostile: bool = false,
    roaring: bool = false,
    tracked_target: bool = false,
    calm_ticks: u32 = 0,
    sniff_ticks: u32 = 0,
    boom_charge_ticks: u32 = 0,
    boom_cooldown_ticks: u32 = 0,
    darkness_ticks: u32 = DARKNESS_PULSE_TICKS,
    darkness_pulsed: bool = false,

    pub fn init(position: Position) WardenBehavior {
        return .{ .position = position };
    }

    pub fn movementSpeed(self: WardenBehavior) f32 {
        return if (self.hostile) WARDEN_HOSTILE_SPEED else 0.0;
    }

    /// Emergence is invulnerable, and burrowing/despawned Wardens cannot be hit.
    pub fn takeDamage(self: *WardenBehavior, amount: f32) f32 {
        if (self.is_emerging or self.is_burrowing or self.despawned or amount <= 0.0) return 0.0;
        const dealt = @min(amount, self.health);
        self.health -= dealt;
        return dealt;
    }

    fn resetCalm(self: *WardenBehavior) void {
        self.calm_ticks = 0;
        self.tracked_target = true;
    }

    pub fn hearVibration(self: *WardenBehavior) void {
        if (self.despawned) return;
        self.resetCalm();
        self.agitation = @min(HOSTILE_AGITATION_THRESHOLD, self.agitation + VIBRATION_AGITATION);
        self.roaring = self.agitation >= ROAR_AGITATION_THRESHOLD;
        self.hostile = self.agitation >= HOSTILE_AGITATION_THRESHOLD;
    }

    /// Scent is a periodic, omnidirectional target sense within 16m. It locates
    /// and keeps the target active without changing the vibration agitation score.
    pub fn sniffTarget(self: *WardenBehavior, target: Position) bool {
        if (distance(self.position, target) > WARDEN_SNIFF_RANGE) return false;
        self.resetCalm();
        return true;
    }

    pub fn canStartSonicBoom(self: WardenBehavior, target: Position) bool {
        const range = distance(self.position, target);
        return !self.is_emerging and !self.is_burrowing and !self.despawned and
            self.hostile and range > MELEE_RANGE and range <= SONIC_BOOM_RANGE and
            self.boom_charge_ticks == 0 and self.boom_cooldown_ticks == 0;
    }

    /// Advances fixed 20Hz simulation. The return value reports a newly fired
    /// boom; when a target remains eligible it charges for 34 ticks first.
    pub fn tick(self: *WardenBehavior, target: ?Position) bool {
        if (self.despawned) return false;
        self.darkness_pulsed = false;
        var just_emerged = false;
        if (self.is_emerging) {
            if (self.emergence_ticks_remaining > 0) self.emergence_ticks_remaining -= 1;
            if (self.emergence_ticks_remaining == 0) {
                self.is_emerging = false;
                just_emerged = true;
            }
        }

        if (self.boom_cooldown_ticks > 0) self.boom_cooldown_ticks -= 1;
        var fired = false;
        if (self.boom_charge_ticks > 0) {
            self.boom_charge_ticks -= 1;
            if (self.boom_charge_ticks == 0) {
                self.boom_cooldown_ticks = SONIC_BOOM_COOLDOWN_TICKS;
                fired = true;
            }
        } else if (target) |player| {
            if (self.canStartSonicBoom(player)) self.boom_charge_ticks = SONIC_BOOM_CHARGE_TICKS;
        }

        if (self.darkness_ticks > 0) self.darkness_ticks -= 1;
        if (self.darkness_ticks == 0) {
            self.darkness_pulsed = true;
            self.darkness_ticks = DARKNESS_PULSE_TICKS;
        }

        self.sniff_ticks += 1;
        if (self.sniff_ticks >= WARDEN_SNIFF_INTERVAL_TICKS) {
            self.sniff_ticks = 0;
            if (target) |player| _ = self.sniffTarget(player);
        }

        if (!just_emerged and !self.is_emerging and self.agitation == 0 and !self.tracked_target) {
            self.calm_ticks += 1;
            if (self.calm_ticks >= CALM_BURROW_TICKS) {
                self.is_burrowing = true;
                self.despawned = true;
            }
        }
        self.tracked_target = false;
        return fired;
    }

    pub fn darknessAffects(self: WardenBehavior, player: Position) bool {
        return distance(self.position, player) <= DARKNESS_RADIUS;
    }

    pub fn emitsDarknessTo(self: WardenBehavior, player: Position) bool {
        return self.darkness_pulsed and self.darknessAffects(player);
    }
};

pub const BoomResult = struct { hit: bool, damage: f32, impulse: SonicBoomImpulse };

pub const PlayerCombatState = struct {
    health: f32 = 20.0,
    armor_points: f32 = 0.0,
    shield_blocking: bool = false,
    velocity: SonicBoomImpulse = .{ .vx = 0.0, .vy = 0.0, .vz = 0.0 },
};

pub fn resolveSonicBoom(warden: Position, target: Position) BoomResult {
    if (distance(warden, target) > SONIC_BOOM_RANGE) return .{
        .hit = false,
        .damage = 0.0,
        .impulse = .{ .vx = 0.0, .vy = 0.0, .vz = 0.0 },
    };
    return .{ .hit = true, .damage = SONIC_BOOM_DAMAGE, .impulse = sonicBoomImpulse(warden, target) };
}

/// Applies a valid beam hit directly, deliberately ignoring armor and shield state.
pub fn hitPlayerWithSonicBoom(warden: Position, target: Position, player: *PlayerCombatState) bool {
    const result = resolveSonicBoom(warden, target);
    if (!result.hit) return false;
    player.health = @max(0.0, player.health - result.damage);
    player.velocity = result.impulse;
    return true;
}


pub const WardenSonicBoom = WardenBehavior;

// ============================================================================
// Unit Tests
// ============================================================================

test "deep dark constants match expected Minecraft specifications" {
    try std.testing.expectEqual(@as(f32, 8.0), catalyst_range);
    try std.testing.expectEqual(@as(f32, 64.0), catalyst_range_sq);
    try std.testing.expectEqual(@as(u16, 20), high_xp_sensor_threshold);
    try std.testing.expectEqual(@as(u16, 50), high_xp_shrieker_threshold);

    try std.testing.expectEqual(@as(f32, 10.0), shriek_cooldown_seconds);
    try std.testing.expectEqual(@as(f32, 600.0), warning_decay_seconds);
    try std.testing.expectEqual(@as(f32, 12.0), darkness_duration_seconds);
    try std.testing.expectEqual(@as(u3, 4), max_warning_level);
    try std.testing.expectEqual(@as(u3, 4), warden_summon_level);

    try std.testing.expectEqual(@as(f32, 500.0), warden_max_hp);
    try std.testing.expectEqual(@as(f32, 30.0), warden_melee_damage);
    try std.testing.expectEqual(@as(f32, 24.0), warden_smell_range);
    try std.testing.expectEqual(@as(f32, 576.0), warden_smell_range_sq);
    try std.testing.expectEqual(@as(f32, 5.0), warden_smell_interval);
    try std.testing.expectEqual(@as(u8, 10), smell_anger_bonus);
    try std.testing.expectEqual(@as(u8, 35), vibration_anger_bonus);
    try std.testing.expectEqual(@as(u8, 10), projectile_anger_bonus);
    try std.testing.expectEqual(@as(u8, 40), agitated_anger_threshold);
    try std.testing.expectEqual(@as(u8, 80), roaring_attack_threshold);
    try std.testing.expectEqual(@as(f32, 60.0), burrow_timeout_seconds);

    try std.testing.expectEqual(@as(f32, 15.0), sonic_boom_horizontal_range);
    try std.testing.expectEqual(@as(f32, 20.0), sonic_boom_vertical_range);
    try std.testing.expectEqual(@as(f32, 10.0), sonic_boom_base_damage);
}

test "sculkSpreadRadius scales with XP amount up to 8 blocks" {
    try std.testing.expectEqual(@as(u8, 0), sculkSpreadRadius(0));
    try std.testing.expectEqual(@as(u8, 1), sculkSpreadRadius(3));
    try std.testing.expectEqual(@as(u8, 1), sculkSpreadRadius(5));
    try std.testing.expectEqual(@as(u8, 2), sculkSpreadRadius(10));
    try std.testing.expectEqual(@as(u8, 2), sculkSpreadRadius(15));
    try std.testing.expectEqual(@as(u8, 3), sculkSpreadRadius(25));
    try std.testing.expectEqual(@as(u8, 4), sculkSpreadRadius(45));
    try std.testing.expectEqual(@as(u8, 5), sculkSpreadRadius(70));
    try std.testing.expectEqual(@as(u8, 6), sculkSpreadRadius(100));
    try std.testing.expectEqual(@as(u8, 7), sculkSpreadRadius(150));
    try std.testing.expectEqual(@as(u8, 8), sculkSpreadRadius(250));
    try std.testing.expectEqual(@as(u8, 8), sculkSpreadRadius(1000));
}

test "SculkCatalyst detects mob death within 8.0 blocks (64.0 sq distance)" {
    var catalyst = SculkCatalyst.init(10, 60, 10);
    // Mob dies at (12.0, 60.0, 14.0): dx = 1.5, dz = 3.5 -> dist_sq = 2.25 + 12.25 = 14.5 <= 64.0
    const charge = catalyst.onMobDeath(12.0, 60.0, 14.0, 20);
    try std.testing.expect(charge != null);
    if (charge) |c| {
        try std.testing.expectEqual(@as(i32, 12), c.origin_x);
        try std.testing.expectEqual(@as(i32, 60), c.origin_y);
        try std.testing.expectEqual(@as(i32, 14), c.origin_z);
        try std.testing.expectEqual(@as(u16, 20), c.xp_amount);
        try std.testing.expectEqual(@as(u8, 3), c.spread_radius);
    }
    try std.testing.expect(catalyst.bloom_active);
    try std.testing.expectEqual(@as(u32, 1), catalyst.charges_absorbed);
    try std.testing.expectEqual(@as(u32, 20), catalyst.total_xp_consumed);

    catalyst.tick(2.5);
    try std.testing.expect(!catalyst.bloom_active);
}

test "SculkCatalyst ignores mob death beyond 8.0 blocks or zero XP" {
    var catalyst = SculkCatalyst.init(0, 0, 0);

    // 0 XP drop
    try std.testing.expect(catalyst.onMobDeath(1.0, 0.0, 1.0, 0) == null);

    // Beyond 8.0 blocks: dx = 9.0 -> dist_sq >= 81.0 > 64.0
    try std.testing.expect(catalyst.onMobDeath(9.5, 0.5, 0.5, 50) == null);
    try std.testing.expectEqual(@as(u32, 0), catalyst.charges_absorbed);
}

test "convertBlock converts stone, deepslate, dirt to Sculk and SculkVein" {
    try std.testing.expect(isConvertibleBlock(.stone));
    try std.testing.expect(isConvertibleBlock(.deepslate));
    try std.testing.expect(isConvertibleBlock(.dirt));
    try std.testing.expect(!isConvertibleBlock(.air));

    // Core region becomes solid Sculk
    const core_sculk = convertBlock(.stone, 20, 1.0, 50);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk), core_sculk);

    const deepslate_sculk = convertBlock(.deepslate, 30, 0.5, 50);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk), deepslate_sculk);

    // Perimeter / outer region becomes SculkVein
    const edge_vein = convertBlock(.dirt, 20, 2.8, 50);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk_vein), edge_vein);

    // Non-convertible block returns null
    try std.testing.expectEqual(@as(?DeepDarkBlock, null), convertBlock(.air, 20, 1.0, 50));
}

test "convertBlock on high-XP kills spawns SculkSensor and SculkShrieker" {
    // High XP >= 50 and lucky roll spawns Sculk Shrieker
    const shrieker = convertBlock(.deepslate, 60, 1.0, 10);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk_shrieker), shrieker);

    // High XP >= 20 and roll spawns Sculk Sensor
    const sensor = convertBlock(.stone, 30, 1.0, 25);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk_sensor), sensor);

    // Low XP (< 20) with roll does NOT spawn sensor or shrieker, spawns Sculk
    const low_xp = convertBlock(.stone, 10, 0.5, 5);
    try std.testing.expectEqual(@as(?DeepDarkBlock, .sculk), low_xp);
}

test "BloomCharge isWithinSpread checks spherical expansion radius" {
    const charge = BloomCharge.init(0, 0, 0, 50); // spread_radius = 4
    try std.testing.expectEqual(@as(u8, 4), charge.spread_radius);
    try std.testing.expect(charge.isWithinSpread(2, 2, 2)); // dist_sq = 12 <= 16
    try std.testing.expect(charge.isWithinSpread(4, 0, 0)); // dist_sq = 16 <= 16
    try std.testing.expect(!charge.isWithinSpread(5, 0, 0)); // dist_sq = 25 > 16
}

test "SculkShriekerWarning increments warning levels 1 to 4 on natural shrieks" {
    var tracker = SculkShriekerWarning.init();
    try std.testing.expectEqual(@as(u3, 0), tracker.warning_level);

    // Shriek 1
    const r1 = tracker.triggerShriek(true);
    try std.testing.expect(r1.shrieked);
    try std.testing.expectEqual(@as(u3, 1), r1.warning_level);
    try std.testing.expect(!r1.summon_warden);

    tracker.tick(10.0); // Wait out cooldown

    // Shriek 2
    const r2 = tracker.triggerShriek(true);
    try std.testing.expect(r2.shrieked);
    try std.testing.expectEqual(@as(u3, 2), r2.warning_level);
    try std.testing.expect(!r2.summon_warden);

    tracker.tick(10.0);

    // Shriek 3
    const r3 = tracker.triggerShriek(true);
    try std.testing.expect(r3.shrieked);
    try std.testing.expectEqual(@as(u3, 3), r3.warning_level);
    try std.testing.expect(!r3.summon_warden);

    tracker.tick(10.0);

    // Shriek 4 -> Summons Warden & inflicts Darkness!
    const r4 = tracker.triggerShriek(true);
    try std.testing.expect(r4.shrieked);
    try std.testing.expectEqual(@as(u3, 4), r4.warning_level);
    try std.testing.expect(r4.summon_warden);
    try std.testing.expect(r4.darkness_inflicted);
    try std.testing.expect(tracker.hasDarkness());
}

test "SculkShriekerWarning 10.0s cooldown blocks rapid shriek increments" {
    var tracker = SculkShriekerWarning.init();

    const r1 = tracker.triggerShriek(true);
    try std.testing.expect(r1.shrieked);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);

    // Immediate second shriek blocked by cooldown
    const r2 = tracker.triggerShriek(true);
    try std.testing.expect(!r2.shrieked);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);

    // After 9 seconds, still on cooldown
    tracker.tick(9.0);
    const r3 = tracker.triggerShriek(true);
    try std.testing.expect(!r3.shrieked);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);

    // After remaining 1.1s, cooldown has elapsed
    tracker.tick(1.1);
    const r4 = tracker.triggerShriek(true);
    try std.testing.expect(r4.shrieked);
    try std.testing.expectEqual(@as(u3, 2), tracker.warning_level);
}

test "SculkShriekerWarning player-placed shrieker (can_summon=false) does not increase warning" {
    var tracker = SculkShriekerWarning.init();

    const res = tracker.triggerShriek(false);
    try std.testing.expect(res.shrieked);
    try std.testing.expect(!res.warning_incremented);
    try std.testing.expectEqual(@as(u3, 0), res.warning_level);
    try std.testing.expect(!res.summon_warden);
    try std.testing.expect(!res.darkness_inflicted);
}

test "SculkShriekerWarning decays 1 level every 600.0s without shrieks" {
    var tracker = SculkShriekerWarning.init();
    _ = tracker.triggerShriek(true); // level 1
    tracker.tick(10.0);
    _ = tracker.triggerShriek(true); // level 2
    try std.testing.expectEqual(@as(u3, 2), tracker.warning_level);

    // Advance 599.0s -> still level 2
    tracker.tick(599.0);
    try std.testing.expectEqual(@as(u3, 2), tracker.warning_level);

    // Advance 2.0s -> decays to level 1
    tracker.tick(2.0);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);

    // Advance another 600.0s -> decays to level 0
    tracker.tick(600.0);
    try std.testing.expectEqual(@as(u3, 0), tracker.warning_level);
    try std.testing.expectEqual(@as(f32, 0.0), tracker.decay_timer);
}

test "Darkness vision-pulsing fog factor oscillates and expires" {
    var tracker = SculkShriekerWarning.init();
    tracker.applyDarkness(12.0);
    try std.testing.expect(tracker.hasDarkness());

    const fog1 = computeDarknessFogIntensity(tracker.darkness_timer);
    try std.testing.expect(fog1 >= 0.0 and fog1 <= 1.0);

    const dists = computeDarknessFogDistances(0.8);
    try std.testing.expect(dists.start < 32.0);
    try std.testing.expect(dists.end < 64.0);

    // Advance 12.5s -> Darkness effect fades and expires
    tracker.tick(12.5);
    try std.testing.expect(!tracker.hasDarkness());
    try std.testing.expectEqual(@as(f32, 0.0), computeDarknessFogIntensity(tracker.darkness_timer));
}

test "WardenAngerTracker tracks targets via smell (+10 anger every 5s within 24m)" {
    var warden = WardenAngerTracker.init();
    try std.testing.expectEqual(@as(u8, 0), warden.anger);

    // Target at 15m (within 24m): tick 4.0s (not yet 5.0s)
    try std.testing.expect(!warden.trackSmell(15.0, 4.0));
    try std.testing.expectEqual(@as(u8, 0), warden.anger);

    // Additional 1.5s (total >= 5.0s): smells target and gains +10 anger
    try std.testing.expect(warden.trackSmell(15.0, 1.5));
    try std.testing.expectEqual(@as(u8, 10), warden.anger);

    // Target out of smell range (30m) does not increase anger
    try std.testing.expect(!warden.trackSmell(30.0, 10.0));
    try std.testing.expectEqual(@as(u8, 10), warden.anger);
}

test "WardenAngerTracker onSmell direct check" {
    var warden = WardenAngerTracker.init();
    try std.testing.expect(warden.onSmell(20.0));
    try std.testing.expectEqual(@as(u8, 10), warden.anger);

    try std.testing.expect(!warden.onSmell(25.0));
    try std.testing.expectEqual(@as(u8, 10), warden.anger);
}

test "WardenAngerTracker vibration adds +35, projectile distraction adds +10" {
    var warden = WardenAngerTracker.init();

    // Standard vibration: +35 anger
    warden.onVibration(false);
    try std.testing.expectEqual(@as(u8, 35), warden.anger);

    // Projectile distraction: +10 anger
    warden.onVibration(true);
    try std.testing.expectEqual(@as(u8, 45), warden.anger);
}

test "WardenAngerTracker transitions between calm, agitated (>=40), and roaring_attack (>=80)" {
    var warden = WardenAngerTracker.init();
    try std.testing.expectEqual(WardenState.calm, warden.getState());

    warden.anger = 39;
    try std.testing.expectEqual(WardenState.calm, warden.getState());

    warden.anger = 40;
    try std.testing.expectEqual(WardenState.agitated, warden.getState());

    warden.anger = 79;
    try std.testing.expectEqual(WardenState.agitated, warden.getState());

    warden.anger = 80;
    try std.testing.expectEqual(WardenState.roaring_attack, warden.getState());

    warden.anger = 120;
    try std.testing.expectEqual(WardenState.roaring_attack, warden.getState());
}

test "WardenAngerTracker decayAnger reduces anger by 1 per second" {
    var warden = WardenAngerTracker.init();
    warden.anger = 85;

    warden.tick(3.2);
    try std.testing.expectEqual(@as(u8, 82), warden.anger);

    warden.tick(2.8);
    try std.testing.expectEqual(@as(u8, 79), warden.anger);
    try std.testing.expectEqual(WardenState.agitated, warden.getState());
}

test "WardenAngerTracker automatically burrows back underground after 60.0s of zero vibrations" {
    var warden = WardenAngerTracker.init();
    try std.testing.expect(!warden.is_burrowed);

    warden.tick(55.0);
    try std.testing.expect(!warden.is_burrowed);

    // Vibration at 55s resets the idle timer
    warden.onVibration(false);
    try std.testing.expectEqual(@as(f32, 0.0), warden.zero_vibration_timer);

    // Tick 59.0s -> still active
    warden.tick(59.0);
    try std.testing.expect(!warden.is_burrowed);

    // Tick 1.5s (total > 60.0s) -> burrows underground
    warden.tick(1.5);
    try std.testing.expect(warden.is_burrowed);
    try std.testing.expectEqual(WardenState.burrowing, warden.getState());

    // Subsequent vibration un-burrows the Warden
    warden.onVibration(false);
    try std.testing.expect(!warden.is_burrowed);
}

test "computeSonicBoomAttack deals 10.0 magic damage bypassing armor completely" {
    const warden_pos = [3]f32{ 0.0, 60.0, 0.0 };
    const target_pos = [3]f32{ 6.0, 64.0, 8.0 }; // horiz dist = 10.0m <= 15m, vert dist = 4.0m <= 20m

    // Unarmored player (armor_reduction = 0.0): 10.0 damage
    const res_unarmored = computeSonicBoomAttack(warden_pos, target_pos, 0.0);
    try std.testing.expectEqual(@as(f32, 10.0), res_unarmored.damage);

    // Full Netherite armor player (armor_reduction = 0.75): still exactly 10.0 damage!
    const res_armored = computeSonicBoomAttack(warden_pos, target_pos, 0.75);
    try std.testing.expectEqual(@as(f32, 10.0), res_armored.damage);

    // Maximum armor reduction (1.0): still 10.0 damage
    const res_max = computeSonicBoomAttack(warden_pos, target_pos, 1.0);
    try std.testing.expectEqual(@as(f32, 10.0), res_max.damage);
}

test "computeSonicBoomAttack range boundaries (15.0 horizontal / 20.0 vertical)" {
    const warden_pos = [3]f32{ 0.0, 50.0, 0.0 };

    // Within range
    try std.testing.expect(isTargetInSonicBoomRange(warden_pos, [3]f32{ 15.0, 50.0, 0.0 }));
    try std.testing.expect(isTargetInSonicBoomRange(warden_pos, [3]f32{ 0.0, 70.0, 0.0 }));

    // Beyond horizontal range (> 15.0m): returns 0 damage
    const out_horiz = computeSonicBoomAttack(warden_pos, [3]f32{ 16.0, 50.0, 0.0 }, 0.5);
    try std.testing.expectEqual(@as(f32, 0.0), out_horiz.damage);
    try std.testing.expectEqual(@as(f32, 0.0), out_horiz.knockback_vx);

    // Beyond vertical range (> 20.0m): returns 0 damage
    const out_vert = computeSonicBoomAttack(warden_pos, [3]f32{ 0.0, 71.0, 0.0 }, 0.5);
    try std.testing.expectEqual(@as(f32, 0.0), out_vert.damage);
    try std.testing.expectEqual(@as(f32, 0.0), out_vert.knockback_vy);
}

test "computeSonicBoomAttack knockback direction and upward force" {
    const warden_pos = [3]f32{ 0.0, 50.0, 0.0 };
    const target_pos = [3]f32{ 10.0, 52.0, 0.0 };

    const boom = computeSonicBoomAttack(warden_pos, target_pos, 0.0);
    try std.testing.expectEqual(@as(f32, 10.0), boom.damage);
    // Knockback along +X direction
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), boom.knockback_vx, 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), boom.knockback_vz, 1e-4);
    // Upward vertical knockback lift
    try std.testing.expectEqual(@as(f32, 0.5), boom.knockback_vy);
}


test "SculkShriekerWarning trigger method advances warning level" {
    var tracker = SculkShriekerWarning.init();
    const res = tracker.trigger(0.5, 61.0, 0.5, 0, 60, 0);
    try std.testing.expect(res.shrieked);
    try std.testing.expectEqual(@as(u3, 1), res.warning_level);
    try std.testing.expectEqual(@as(u3, 1), tracker.warning_level);
}

// Scent blast unit tests
test "scent cadence does not animate during first 83 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 2 } }};
    for (0..83) |_| try std.testing.expect(!(w.tick(&p).sniff_animation));
}
test "sniff animation fires on tick 84" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..83) |_| _ = w.tick(&p);
    try std.testing.expect(w.tick(&p).sniff_animation);
}
test "sniff cadence repeats after another 84 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..84) |_| _ = w.tick(&p);
    for (0..83) |_| try std.testing.expect(!w.tick(&p).sniff_animation);
    try std.testing.expect(w.tick(&p).sniff_animation);
}
test "sniff detects player at exactly 16 meters" {
    var w = Warden.init(.{});
    // Start the calm decay window at its boundary so this asserts the direct
    // +35 acquisition before any subsequent calm decay can occur.
    w.calm_decay_ticks = CALM_DECAY_INTERVAL_TICKS - 1;
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 16 } }};
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 35), p[0].suspicion);
}
test "sniff excludes player beyond 16 meters" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 16.01 } }};
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "scent range uses three dimensional Euclidean distance" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 12, .y = 12 } }};
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "sniff selects nearest of multiple players" {
    var w = Warden.init(.{});
    var p = [_]Player{ .{ .id = 1, .position = .{ .x = 9 } }, .{ .id = 2, .position = .{ .x = 3 } } };
    for (0..83) |_| _ = w.tick(&p);
    const event = w.tick(&p);
    try std.testing.expectEqual(@as(?u32, 2), event.sniffed_player_id);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
    try std.testing.expectEqual(@as(u16, 35), p[1].suspicion);
}
test "sniff animation occurs with no player in range" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .position = .{ .x = 17 } }};
    for (0..83) |_| _ = w.tick(&p);
    const event = w.tick(&p);
    try std.testing.expect(event.sniff_animation);
    try std.testing.expectEqual(@as(?u32, null), event.sniffed_player_id);
}
test "scent adds 35 suspicion on each periodic acquisition" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..168) |_| _ = w.tick(&p);
    // The first 35-point increase is followed by four calm decay ticks before
    // the second sniff, so the net total is 66.
    try std.testing.expectEqual(@as(u16, 66), p[0].suspicion);
}
test "suspicion reaches agitated threshold at 40" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 39 }};
    w.hearVibration(&p[0], 1);
    try std.testing.expectEqual(State.agitated, w.state);
}
test "suspicion below 40 stays calm" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 39 }};
    w.hearVibration(&p[0], 0);
    try std.testing.expectEqual(State.calm, w.state);
}
test "agitated state turns toward identified suspect" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 7, .suspicion = 40 }};
    w.target_player_id = 7;
    w.state = .agitated;
    try std.testing.expectEqual(@as(?u32, 7), w.tick(&p).turned_toward_player_id);
}
test "suspicion 79 remains agitated" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 79 }};
    w.hearVibration(&p[0], 0);
    try std.testing.expectEqual(State.agitated, w.state);
}
test "suspicion reaches roar at 80" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 79 }};
    w.hearVibration(&p[0], 1);
    try std.testing.expectEqual(State.roaring, w.state);
    try std.testing.expectEqual(@as(u32, 40), w.roar_ticks_remaining);
}
test "suspicion 149 remains below chase" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 149 }};
    w.hearVibration(&p[0], 0);
    try std.testing.expectEqual(State.roaring, w.state);
}
test "suspicion reaches relentless chase at 150" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 149 }};
    w.hearVibration(&p[0], 1);
    try std.testing.expectEqual(State.chasing, w.state);
}
test "sniff accumulation escalates calm player through suspicion tiers" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..84 * 4) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 136), p[0].suspicion);
    try std.testing.expectEqual(State.roaring, w.state);
    for (0..84) |_| _ = w.tick(&p);
    try std.testing.expectEqual(State.chasing, w.state);
}
test "tick reports the start of the roar animation" {
    var w = Warden.init(.{});
    w.sniff_ticks = SCENT_INTERVAL_TICKS - 1;
    w.calm_decay_ticks = CALM_DECAY_INTERVAL_TICKS - 1;
    var p = [_]Player{.{ .id = 1, .suspicion = 45 }};
    try std.testing.expect(w.tick(&p).roar_started);
}
test "roar lasts exactly 40 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 80 }};
    w.hearVibration(&p[0], 0);
    for (0..39) |_| _ = w.tick(&p);
    try std.testing.expectEqual(State.roaring, w.state);
    _ = w.tick(&p);
    try std.testing.expectEqual(State.agitated, w.state);
}
test "chasing suppresses periodic sniff animation" {
    var w = Warden.init(.{});
    w.state = .chasing;
    var p = [_]Player{.{ .id = 1 }};
    for (0..168) |_| try std.testing.expect(!w.tick(&p).sniff_animation);
}
test "calm speed is one meter per second" {
    try std.testing.expectEqual(@as(f32, 1.0), Warden.init(.{}).movementSpeed());
}
test "agitated and roaring wardens stop moving" {
    var w = Warden.init(.{});
    w.state = .agitated;
    try std.testing.expectEqual(@as(f32, 0.0), w.movementSpeed());
    w.state = .roaring;
    try std.testing.expectEqual(@as(f32, 0.0), w.movementSpeed());
}
test "chase speed is 4.2 meters per second" {
    var w = Warden.init(.{});
    w.state = .chasing;
    try std.testing.expectEqual(@as(f32, 4.2), w.movementSpeed());
}
test "calm suspicion decays after 20 ticks" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 3 }};
    for (0..19) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 3), p[0].suspicion);
    _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 2), p[0].suspicion);
}
test "calm suspicion decays once per 20 tick interval" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 2 }};
    for (0..40) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "vibration interrupts the calm decay timer" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1, .suspicion = 5 }};
    for (0..19) |_| _ = w.tick(&p);
    w.hearVibration(&p[0], 0);
    _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 5), p[0].suspicion);
}
test "decay never underflows zero suspicion" {
    var w = Warden.init(.{});
    var p = [_]Player{.{ .id = 1 }};
    for (0..40) |_| _ = w.tick(&p);
    try std.testing.expectEqual(@as(u16, 0), p[0].suspicion);
}
test "blast hits target at 15 horizontal meters" {
    const result = resolveSonicBlast(.{}, .{ .x = 15 });
    try std.testing.expect(result.hit);
}
test "blast misses beyond 15 horizontal meters" {
    const result = resolveSonicBlast(.{}, .{ .x = 15.01 });
    try std.testing.expect(!result.hit);
}
test "blast uses horizontal reach despite vertical separation" {
    const result = resolveSonicBlast(.{}, .{ .x = 15, .y = 100 });
    try std.testing.expect(result.hit);
}
test "blast penetrates terrain because resolution has no block input" {
    const solid_wall_between = true;
    const result = resolveSonicBlast(.{}, .{ .x = 10 });
    try std.testing.expect(solid_wall_between);
    try std.testing.expect(result.hit);
}
test "blast damage is exactly ten health" {
    try std.testing.expectEqual(@as(f32, 10.0), resolveSonicBlast(.{}, .{ .x = 1 }).damage);
}
test "blast vertical knockback is six meters per second" {
    try std.testing.expectEqual(@as(f32, 6.0), resolveSonicBlast(.{}, .{ .x = 1 }).knockback.y);
}
test "blast horizontal knockback magnitude is eight meters per second" {
    const impulse = resolveSonicBlast(.{}, .{ .x = 3, .z = 4 }).knockback;
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), @sqrt(impulse.x * impulse.x + impulse.z * impulse.z), 0.0001);
}
test "blast applies unmitigated health loss and replaces velocity" {
    var player = Player{ .id = 1, .position = .{ .x = 2 }, .armor_points = 20, .shield_blocking = true };
    player.velocity = .{ .x = -1, .y = 1, .z = -1 };
    try std.testing.expect(hitPlayerWithSonicBlast(.{}, &player));
    try std.testing.expectEqual(@as(f32, 10.0), player.health);
    try std.testing.expectEqual(@as(f32, 8.0), player.velocity.x);
    try std.testing.expectEqual(@as(f32, 6.0), player.velocity.y);
}
test "blast does not alter player outside reach" {
    var player = Player{ .id = 1, .position = .{ .x = 16 } };
    try std.testing.expect(!hitPlayerWithSonicBlast(.{}, &player));
    try std.testing.expectEqual(@as(f32, 20.0), player.health);
}
test "blast damage cannot reduce health below zero" {
    var player = Player{ .id = 1, .position = .{ .x = 1 }, .health = 4 };
    _ = hitPlayerWithSonicBlast(.{}, &player);
    try std.testing.expectEqual(@as(f32, 0.0), player.health);
}

// Sonic boom unit tests
test "attributes specify 500 health and 30 melee damage" {
    const w = WardenBehavior.init(.{});
    try std.testing.expectEqual(@as(f32, 500.0), w.health);
    try std.testing.expectEqual(@as(f32, 500.0), WARDEN_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 30.0), WARDEN_MELEE_DAMAGE);
    try std.testing.expectEqual(@as(f32, 0.0), WARDEN_OPTICAL_SIGHT_RANGE);
}

test "vibration adds 35 agitation" {
    var w = WardenBehavior.init(.{});
    w.hearVibration();
    try std.testing.expectEqual(@as(u16, 35), w.agitation);
}
test "second vibration remains below roar threshold" {
    var w = WardenBehavior.init(.{});
    w.hearVibration();
    w.hearVibration();
    try std.testing.expect(!w.roaring);
}
test "roaring starts at exact 80 agitation threshold" {
    var w = WardenBehavior.init(.{});
    w.agitation = 79;
    w.hearVibration();
    try std.testing.expect(w.roaring);
}
test "fifth vibration reaches hostile chase at 150" {
    var w = WardenBehavior.init(.{});
    for (0..4) |_| w.hearVibration();
    try std.testing.expectEqual(@as(u16, 140), w.agitation);
    try std.testing.expect(!w.hostile);
    w.hearVibration();
    try std.testing.expectEqual(@as(u16, 150), w.agitation);
    try std.testing.expect(w.hostile);
}
test "agitation caps at 150" {
    var w = WardenBehavior.init(.{});
    for (0..8) |_| w.hearVibration();
    try std.testing.expectEqual(@as(u16, 150), w.agitation);
}
test "hostile movement speed is 4.2 meters per second" {
    var w = WardenBehavior.init(.{});
    w.hostile = true;
    try std.testing.expectEqual(@as(f32, 4.2), w.movementSpeed());
}
test "calm Warden has no hostile chase speed" {
    const w = WardenBehavior.init(.{});
    try std.testing.expectEqual(@as(f32, 0.0), w.movementSpeed());
}
test "emergence lasts exactly 134 ticks" {
    var w = WardenBehavior.init(.{});
    for (0..133) |_| _ = w.tick(null);
    try std.testing.expect(w.is_emerging);
    _ = w.tick(null);
    try std.testing.expect(!w.is_emerging);
}
test "emerging Warden is invulnerable" {
    var w = WardenBehavior.init(.{});
    try std.testing.expectEqual(@as(f32, 0.0), w.takeDamage(100));
    try std.testing.expectEqual(@as(f32, 500.0), w.health);
}
test "emergence damage works after the final tick" {
    var w = WardenBehavior.init(.{});
    for (0..134) |_| _ = w.tick(null);
    try std.testing.expectEqual(@as(f32, 10.0), w.takeDamage(10));
}
test "calm burrowing begins at 1200 quiet ticks" {
    var w = WardenBehavior.init(.{});
    for (0..134) |_| _ = w.tick(null);
    for (0..1199) |_| _ = w.tick(null);
    try std.testing.expect(!w.despawned);
    _ = w.tick(null);
    try std.testing.expect(w.is_burrowing);
    try std.testing.expect(w.despawned);
}
test "vibration resets calm despawn countdown" {
    var w = WardenBehavior.init(.{});
    for (0..134) |_| _ = w.tick(null);
    for (0..1100) |_| _ = w.tick(null);
    w.hearVibration();
    for (0..200) |_| _ = w.tick(null);
    try std.testing.expect(!w.despawned);
}
test "scent detection finds target at 16m" {
    var w = WardenBehavior.init(.{});
    try std.testing.expect(w.sniffTarget(.{ .x = 16 }));
}
test "scent detection rejects target beyond 16m" {
    var w = WardenBehavior.init(.{});
    try std.testing.expect(!w.sniffTarget(.{ .x = 16.01 }));
}
test "scent tracking resets calm countdown without adding agitation" {
    var w = WardenBehavior.init(.{});
    w.calm_ticks = 100;
    try std.testing.expect(w.sniffTarget(.{ .x = 4 }));
    try std.testing.expectEqual(@as(u32, 0), w.calm_ticks);
    try std.testing.expectEqual(@as(u16, 0), w.agitation);
}
test "periodic sniff detects nearby target" {
    var w = WardenBehavior.init(.{});
    for (0..100) |_| _ = w.tick(.{ .x = 8 });
    try std.testing.expectEqual(@as(u32, 0), w.calm_ticks);
}
test "sonic boom reaches exact 15m boundary" {
    const r = resolveSonicBoom(.{}, .{ .x = 15 });
    try std.testing.expect(r.hit);
}
test "sonic boom rejects target beyond 15m" {
    const r = resolveSonicBoom(.{}, .{ .x = 15.001 });
    try std.testing.expect(!r.hit);
}
test "sonic boom deals ten unmitigated damage through armor and shield" {
    var player = PlayerCombatState{ .health = 20, .armor_points = 20, .shield_blocking = true };
    try std.testing.expect(hitPlayerWithSonicBoom(.{}, .{ .x = 5 }, &player));
    try std.testing.expectEqual(@as(f32, 10), player.health);
}
test "sonic boom attack can target elevated players within spherical range" {
    const r = resolveSonicBoom(.{}, .{ .y = 14 });
    try std.testing.expect(r.hit);
}
test "sonic boom does not start within melee range" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    w.hostile = true;
    try std.testing.expect(!w.canStartSonicBoom(.{ .x = 2 }));
}
test "sonic boom requires hostile state" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    try std.testing.expect(!w.canStartSonicBoom(.{ .x = 8 }));
}
test "sonic boom requires a completed emergence" {
    var w = WardenBehavior.init(.{});
    w.hostile = true;
    try std.testing.expect(!w.canStartSonicBoom(.{ .x = 8 }));
}
test "sonic boom charge lasts exactly 34 ticks then fires" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    w.hostile = true;
    const target = Position{ .x = 8 };
    try std.testing.expect(!w.tick(target));
    try std.testing.expectEqual(@as(u32, 34), w.boom_charge_ticks);
    for (0..33) |_| try std.testing.expect(!w.tick(null));
    try std.testing.expect(w.tick(null));
}
test "sonic boom cooldown lasts 100 ticks" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    w.hostile = true;
    _ = w.tick(.{ .x = 8 });
    for (0..34) |_| _ = w.tick(null);
    try std.testing.expectEqual(@as(u32, 100), w.boom_cooldown_ticks);
    for (0..99) |_| _ = w.tick(.{ .x = 8 });
    try std.testing.expectEqual(@as(u32, 1), w.boom_cooldown_ticks);
    _ = w.tick(.{ .x = 8 });
    try std.testing.expectEqual(@as(u32, 0), w.boom_cooldown_ticks);
}
test "sonic boom applies upward velocity impulse of six" {
    const i = sonicBoomImpulse(.{}, .{ .x = 1 });
    try std.testing.expectEqual(@as(f32, 6), i.vy);
}
test "sonic boom applies horizontal push of eight along positive X" {
    const i = sonicBoomImpulse(.{}, .{ .x = 3 });
    try std.testing.expectEqual(@as(f32, 8), i.vx);
    try std.testing.expectEqual(@as(f32, 0), i.vz);
}
test "sonic boom horizontal push follows diagonal target direction" {
    const i = sonicBoomImpulse(.{}, .{ .x = 3, .z = 4 });
    try std.testing.expectApproxEqAbs(@as(f32, 4.8), i.vx, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.4), i.vz, 0.001);
}
test "sonic boom coincident target still receives upward impulse" {
    const i = sonicBoomImpulse(.{}, .{});
    try std.testing.expectEqual(@as(f32, 6), i.vy);
}
test "darkness aura includes player at 20m boundary" {
    const w = WardenBehavior.init(.{});
    try std.testing.expect(w.darknessAffects(.{ .z = 20 }));
}
test "darkness aura excludes player beyond 20m" {
    const w = WardenBehavior.init(.{});
    try std.testing.expect(!w.darknessAffects(.{ .z = 20.01 }));
}
test "darkness pulse emits effect to nearby player only during pulse" {
    var w = WardenBehavior.init(.{});
    try std.testing.expect(!w.emitsDarknessTo(.{ .x = 2 }));
    for (0..120) |_| _ = w.tick(null);
    try std.testing.expect(w.emitsDarknessTo(.{ .x = 2 }));
    try std.testing.expect(!w.emitsDarknessTo(.{ .x = 21 }));
}
test "darkness pulse is emitted every 120 ticks" {
    var w = WardenBehavior.init(.{});
    for (0..119) |_| {
        _ = w.tick(null);
        try std.testing.expect(!w.darkness_pulsed);
    }
    _ = w.tick(null);
    try std.testing.expect(w.darkness_pulsed);
    try std.testing.expectEqual(@as(u32, 120), w.darkness_ticks);
}
test "burrowing Warden ignores damage" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    w.is_burrowing = true;
    try std.testing.expectEqual(@as(f32, 0), w.takeDamage(50));
}
test "despawned Warden cannot be reactivated by a later vibration" {
    var w = WardenBehavior.init(.{});
    w.despawned = true;
    w.is_burrowing = true;
    w.hearVibration();
    try std.testing.expect(w.despawned);
    try std.testing.expectEqual(@as(u16, 0), w.agitation);
}
test "damage clamps health at zero" {
    var w = WardenBehavior.init(.{});
    w.is_emerging = false;
    try std.testing.expectEqual(@as(f32, 500), w.takeDamage(900));
    try std.testing.expectEqual(@as(f32, 0), w.health);
}

