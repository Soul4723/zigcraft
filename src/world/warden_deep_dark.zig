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
