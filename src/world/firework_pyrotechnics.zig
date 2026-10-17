const std = @import("std");

// ============================================================================
// Milestone 379: Firework Stars, Pyrotechnic Burst Shapes, Flight Duration 1..3
// & Crossbow Star Explosions
// ============================================================================

/// Pyrotechnic burst shapes for firework star explosions.
/// Each shape corresponds to a specific crafting modifier item added to the star recipe:
/// - `.small_ball`: Default shape crafted with just Gunpowder + Dyes (no shape modifier).
/// - `.large_ball`: Crafted with a Fire Charge.
/// - `.star_shaped`: Crafted with a Gold Nugget.
/// - `.creeper_face`: Crafted with any Mob Head (Skeleton, Wither, Zombie, Player, Creeper, Piglin).
/// - `.burst`: Crafted with a Feather.
pub const FireworkBurstShape = enum {
    small_ball,
    large_ball,
    star_shaped,
    creeper_face,
    burst,

    pub fn default() FireworkBurstShape {
        return .small_ball;
    }

    /// Returns the canonical crafting modifier item name, or null for default small ball.
    pub fn craftingModifier(self: FireworkBurstShape) ?[]const u8 {
        return switch (self) {
            .small_ball => null,
            .large_ball => "fire_charge",
            .star_shaped => "gold_nugget",
            .creeper_face => "mob_head",
            .burst => "feather",
        };
    }

    /// User-facing display name.
    pub fn name(self: FireworkBurstShape) []const u8 {
        return switch (self) {
            .small_ball => "Small Ball",
            .large_ball => "Large Ball",
            .star_shaped => "Star-shaped",
            .creeper_face => "Creeper-shaped",
            .burst => "Burst",
        };
    }

    /// Base number of pyrotechnic particles spawned on burst detonation.
    pub fn particleCount(self: FireworkBurstShape) u16 {
        return switch (self) {
            .small_ball => 24,
            .large_ball => 56,
            .star_shaped => 35,
            .creeper_face => 32,
            .burst => 42,
        };
    }

    /// Relative blast visual radius scaling multiplier.
    pub fn visualRadiusMultiplier(self: FireworkBurstShape) f32 {
        return switch (self) {
            .small_ball => 1.0,
            .large_ball => 2.0,
            .star_shaped => 1.35,
            .creeper_face => 1.15,
            .burst => 1.5,
        };
    }

    /// Generates a deterministic normalized 3D velocity/offset vector for particle index `i` out of `total`.
    pub fn generateParticleVelocity(self: FireworkBurstShape, index: usize, total: usize) [3]f32 {
        if (total == 0) return .{ 0.0, 1.0, 0.0 };
        const idx_f: f32 = @floatFromInt(index);
        const tot_f: f32 = @floatFromInt(total);

        switch (self) {
            .small_ball => {
                // Fibonacci sphere lattice for uniform radial distribution
                const phi = 0.5 * (1.0 + @sqrt(5.0));
                const y = 1.0 - (idx_f / @max(1.0, tot_f - 1.0)) * 2.0;
                const radius_at_y = @sqrt(@max(0.0, 1.0 - y * y));
                const theta = 2.0 * std.math.pi * idx_f / phi;
                return .{
                    radius_at_y * @cos(theta),
                    y,
                    radius_at_y * @sin(theta),
                };
            },
            .large_ball => {
                // Double-speed uniform spherical shell
                const phi = 0.5 * (1.0 + @sqrt(5.0));
                const y = 1.0 - (idx_f / @max(1.0, tot_f - 1.0)) * 2.0;
                const radius_at_y = @sqrt(@max(0.0, 1.0 - y * y));
                const theta = 2.0 * std.math.pi * idx_f / phi;
                const mult = self.visualRadiusMultiplier();
                return .{
                    radius_at_y * @cos(theta) * mult,
                    y * mult,
                    radius_at_y * @sin(theta) * mult,
                };
            },
            .star_shaped => {
                // 5-pointed star in horizontal plane with minor vertical spread
                const points: f32 = 5.0;
                const angle = (idx_f / tot_f) * (2.0 * std.math.pi);
                const r = 0.5 + 0.5 * @cos(points * angle);
                const vz = (idx_f - tot_f * 0.5) / tot_f * 0.2;
                return .{
                    @cos(angle) * (r + 0.3) * 1.5,
                    vz,
                    @sin(angle) * (r + 0.3) * 1.5,
                };
            },
            .creeper_face => {
                // Planar grid layout depicting creeper silhouette features
                const u = (idx_f / tot_f) * 2.0 - 1.0;
                const v = @sin(idx_f * 1.7) * 0.8;
                return .{ u, v, 0.1 * @cos(idx_f) };
            },
            .burst => {
                // Exploding spiked trails with erratic high-velocity outward thrusts
                const theta = idx_f * 2.39996; // Golden angle in radians
                const z = 1.0 - (idx_f / @max(1.0, tot_f - 1.0)) * 2.0;
                const r = @sqrt(@max(0.0, 1.0 - z * z));
                const speed = 1.2 + 0.6 * @sin(idx_f * 3.1);
                return .{
                    @cos(theta) * r * speed,
                    z * speed,
                    @sin(theta) * r * speed,
                };
            },
        }
    }
};

/// 16 standard Minecraft dye colors with official Java Edition sRGB values.
pub const DyeColor = enum(u4) {
    black = 0,
    red = 1,
    green = 2,
    brown = 3,
    blue = 4,
    purple = 5,
    cyan = 6,
    light_gray = 7,
    gray = 8,
    pink = 9,
    lime = 10,
    yellow = 11,
    light_blue = 12,
    magenta = 13,
    orange = 14,
    white = 15,

    pub fn toRgb(self: DyeColor) [3]u8 {
        return switch (self) {
            .black => .{ 0x1E, 0x1B, 0x1B },
            .red => .{ 0xB0, 0x2E, 0x26 },
            .green => .{ 0x5E, 0x7C, 0x16 },
            .brown => .{ 0x83, 0x54, 0x32 },
            .blue => .{ 0x3C, 0x44, 0xAA },
            .purple => .{ 0x89, 0x32, 0xB8 },
            .cyan => .{ 0x16, 0x9C, 0x9C },
            .light_gray => .{ 0x9D, 0x9D, 0x97 },
            .gray => .{ 0x47, 0x4F, 0x52 },
            .pink => .{ 0xF3, 0x8B, 0xAA },
            .lime => .{ 0x80, 0xC7, 0x1F },
            .yellow => .{ 0xFE, 0xD8, 0x3D },
            .light_blue => .{ 0x3A, 0xB3, 0xDA },
            .magenta => .{ 0xC7, 0x4E, 0xBD },
            .orange => .{ 0xF9, 0x80, 0x1D },
            .white => .{ 0xF9, 0xFF, 0xFE },
        };
    }

    pub fn toRgbF32(self: DyeColor) [3]f32 {
        const rgb = self.toRgb();
        return .{
            @as(f32, @floatFromInt(rgb[0])) / 255.0,
            @as(f32, @floatFromInt(rgb[1])) / 255.0,
            @as(f32, @floatFromInt(rgb[2])) / 255.0,
        };
    }

    pub fn name(self: DyeColor) []const u8 {
        return @tagName(self);
    }
};

/// Pyrotechnic visual effect flags and color capacity.
/// - `has_twinkle`: Glowstone dust adds twinkling/crackle effect.
/// - `has_trail`: Diamond adds trailing sparks behind particles.
/// - `primary_colors`: 1..8 dyes combined in crafting grid for initial burst colors.
/// - `fade_colors`: 0..8 dyes combined in a secondary crafting step for color transitions.
pub const FireworkEffectFlags = struct {
    has_twinkle: bool = false,
    has_trail: bool = false,
    primary_colors: u8 = 1,
    fade_colors: u8 = 0,

    pub const max_primary_colors: u8 = 8;
    pub const max_fade_colors: u8 = 8;

    pub fn isValid(self: FireworkEffectFlags) bool {
        return self.primary_colors >= 1 and
            self.primary_colors <= max_primary_colors and
            self.fade_colors <= max_fade_colors;
    }

    pub fn totalDyes(self: FireworkEffectFlags) u8 {
        return self.primary_colors + self.fade_colors;
    }

    pub fn canAddPrimary(self: FireworkEffectFlags, count: u8) bool {
        return (@as(u16, self.primary_colors) + @as(u16, count)) <= max_primary_colors;
    }

    pub fn canAddFade(self: FireworkEffectFlags, count: u8) bool {
        return (@as(u16, self.fade_colors) + @as(u16, count)) <= max_fade_colors;
    }
};

/// Complete Firework Star data model representing a crafted star item.
pub const FireworkStar = struct {
    shape: FireworkBurstShape = .small_ball,
    flags: FireworkEffectFlags = .{},
    primary_palette: [8]?DyeColor = [_]?DyeColor{null} ** 8,
    fade_palette: [8]?DyeColor = [_]?DyeColor{null} ** 8,

    pub fn init(shape: FireworkBurstShape, flags: FireworkEffectFlags) FireworkStar {
        return .{
            .shape = shape,
            .flags = flags,
        };
    }

    /// Craft a firework star from gunpowder, optional shape item, dye list (1..8), and effect items.
    pub fn craft(
        has_gunpowder: bool,
        shape: ?FireworkBurstShape,
        dyes: []const DyeColor,
        glowstone_dust: bool,
        diamond: bool,
    ) !FireworkStar {
        if (!has_gunpowder) return error.MissingGunpowder;
        if (dyes.len == 0) return error.NoPrimaryDyes;
        if (dyes.len > FireworkEffectFlags.max_primary_colors) return error.TooManyPrimaryDyes;

        var star = FireworkStar{
            .shape = shape orelse .small_ball,
            .flags = .{
                .has_twinkle = glowstone_dust,
                .has_trail = diamond,
                .primary_colors = @intCast(dyes.len),
                .fade_colors = 0,
            },
        };

        for (dyes, 0..) |dye, i| {
            star.primary_palette[i] = dye;
        }

        return star;
    }

    /// Apply fade dyes in a secondary crafting grid operation (0..8 dyes).
    pub fn applyFade(self: *FireworkStar, fade_dyes: []const DyeColor) !void {
        if (fade_dyes.len == 0) return;
        if (fade_dyes.len > FireworkEffectFlags.max_fade_colors) return error.TooManyFadeDyes;

        self.flags.fade_colors = @intCast(fade_dyes.len);
        for (fade_dyes, 0..) |dye, i| {
            self.fade_palette[i] = dye;
        }
    }

    /// Computes the average sRGB color of the primary dyes.
    pub fn averagePrimaryRgb(self: FireworkStar) [3]f32 {
        var r: f32 = 0.0;
        var g: f32 = 0.0;
        var b: f32 = 0.0;
        var count: f32 = 0.0;

        for (self.primary_palette) |maybe_dye| {
            if (maybe_dye) |dye| {
                const c = dye.toRgbF32();
                r += c[0];
                g += c[1];
                b += c[2];
                count += 1.0;
            }
        }

        if (count == 0.0) return .{ 1.0, 1.0, 1.0 };
        return .{ r / count, g / count, b / count };
    }
};

/// Flight duration corresponding to 1..3 gunpowder crafted with 1 paper -> 3 firework rockets.
/// In seconds:
/// - 1 gunpowder => 1.0s (20 game ticks)
/// - 2 gunpowder => 1.75s (35 game ticks)
/// - 3 gunpowder => 2.5s (50 game ticks)
pub const FlightDuration = enum(u2) {
    duration_1 = 1,
    duration_2 = 2,
    duration_3 = 3,

    pub const rockets_per_craft: u8 = 3;
    pub const paper_per_craft: u8 = 1;

    /// Altitude range in meters/blocks achieved during vertical vertical ascent.
    pub const AltitudeRange = struct {
        min: f32,
        max: f32,

        pub fn average(self: AltitudeRange) f32 {
            return (self.min + self.max) * 0.5;
        }

        pub fn contains(self: AltitudeRange, alt: f32) bool {
            return alt >= self.min and alt <= self.max;
        }
    };

    /// Resolves flight duration enum from gunpowder count (1..3).
    pub fn fromGunpowder(gunpowder_count: u8) ?FlightDuration {
        return switch (gunpowder_count) {
            1 => .duration_1,
            2 => .duration_2,
            3 => .duration_3,
            else => null,
        };
    }

    /// Returns the number of gunpowder items required to craft this duration.
    pub fn gunpowderCount(self: FlightDuration) u8 {
        return @intFromEnum(self);
    }

    /// Flight duration in seconds: 1 => 1.0, 2 => 1.75, 3 => 2.5.
    pub fn toSeconds(self: FlightDuration) f32 {
        return switch (self) {
            .duration_1 => 1.0,
            .duration_2 => 1.75,
            .duration_3 => 2.5,
        };
    }

    /// Total flight duration converted to 20-Hz game ticks.
    pub fn toTicks(self: FlightDuration) u32 {
        return switch (self) {
            .duration_1 => 20,
            .duration_2 => 35,
            .duration_3 => 50,
        };
    }

    /// Vertical flight altitude range in meters/blocks reached before detonation.
    pub fn altitudeRange(self: FlightDuration) AltitudeRange {
        return switch (self) {
            .duration_1 => .{ .min = 12.0, .max = 22.0 },
            .duration_2 => .{ .min = 18.0, .max = 34.0 },
            .duration_3 => .{ .min = 32.0, .max = 54.0 },
        };
    }
};

/// Standalone helper returning flight duration in seconds for a given FlightDuration.
pub fn flightDurationToSeconds(duration: FlightDuration) f32 {
    return duration.toSeconds();
}

/// Standalone helper returning the altitude range for a given FlightDuration.
pub fn flightDurationAltitudeRange(duration: FlightDuration) FlightDuration.AltitudeRange {
    return duration.altitudeRange();
}

/// Firework explosion damage rules and calculations.
/// - Rockets without firework stars deal 0.0 explosion damage (completely safe for Elytra boosting!).
/// - Rockets with 1..7 firework stars deal:
///     `5.0 + @as(f32, @floatFromInt(star_count - 1)) * 2.0`
///   at explosion center (ranging from 5.0 HP up to 17.0 HP for 7 stars).
/// - If used for Elytra boost, explosive rockets inflict fatal/heavy self-damage!
pub const FireworkDamage = struct {
    pub const max_stars: u8 = 7;
    pub const base_damage: f32 = 5.0;
    pub const damage_per_additional_star: f32 = 2.0;
    pub const max_center_damage: f32 = 17.0;
    pub const safe_damage: f32 = 0.0;
    pub const default_aoe_radius: f32 = 4.5;

    /// Computes center explosion damage:
    /// - 0 stars => 0.0 HP
    /// - 1..7 stars => 5.0 + (star_count - 1) * 2.0 HP (up to 17.0 HP)
    pub fn compute(star_count: u8) f32 {
        if (star_count == 0) return safe_damage;
        const clamped_stars = @min(star_count, max_stars);
        return base_damage + @as(f32, @floatFromInt(clamped_stars - 1)) * damage_per_additional_star;
    }

    /// Whether this rocket is completely safe for Elytra propulsion boost.
    pub fn isSafeForElytra(star_count: u8) bool {
        return star_count == 0;
    }

    /// Damage inflicted directly on the player when activating an Elytra boost with an explosive rocket.
    pub fn elytraBoostSelfDamage(star_count: u8) f32 {
        return compute(star_count);
    }

    /// Explosion damage with linear distance fall-off within `aoe_radius`.
    pub fn damageAtDistance(star_count: u8, distance: f32, aoe_radius: f32) f32 {
        const center = compute(star_count);
        if (center <= 0.0 or distance >= aoe_radius or aoe_radius <= 0.0) return 0.0;
        const falloff = 1.0 - (distance / aoe_radius);
        return center * falloff;
    }

    /// Evaluates if damage dealt is fatal to an entity with given current health.
    pub fn isFatal(damage_amount: f32, current_health: f32) bool {
        return damage_amount >= current_health;
    }
};

/// Standalone convenience function calculating firework damage.
pub fn computeFireworkDamage(star_count: u8) f32 {
    return FireworkDamage.compute(star_count);
}

/// Standalone convenience function checking Elytra boost safety.
pub fn isSafeForElytraBoost(star_count: u8) bool {
    return FireworkDamage.isSafeForElytra(star_count);
}

/// Standalone convenience function calculating self-damage when boosting Elytra.
pub fn computeElytraBoostDamage(star_count: u8) f32 {
    return FireworkDamage.elytraBoostSelfDamage(star_count);
}

/// Standalone convenience function calculating damage at given distance with falloff.
pub fn computeDamageAtDistance(center_damage: f32, distance: f32, aoe_radius: f32) f32 {
    if (center_damage <= 0.0 or distance >= aoe_radius or aoe_radius <= 0.0) return 0.0;
    const factor = 1.0 - (distance / aoe_radius);
    return center_damage * factor;
}

/// Detonation cause for firework explosions.
pub const ExplosionCause = enum {
    entity_impact,
    block_impact,
    range_exhausted,
    timer_exhausted,
    manual_detonation,
};

/// Result of a firework pyrotechnic explosion event.
pub const ExplosionResult = struct {
    position: [3]f32,
    aoe_radius: f32 = 4.5,
    center_damage: f32,
    star_count: u8,
    cause: ExplosionCause,

    /// Computes damage delivered to an entity at a given radial distance from explosion origin.
    pub fn damageAtDistance(self: ExplosionResult, distance: f32) f32 {
        if (self.center_damage <= 0.0 or distance >= self.aoe_radius or self.aoe_radius <= 0.0) return 0.0;
        const falloff = 1.0 - (distance / self.aoe_radius);
        return self.center_damage * falloff;
    }

    /// Computes damage delivered to an entity at an arbitrary 3D position.
    pub fn damageAtPosition(self: ExplosionResult, target_pos: [3]f32) f32 {
        const dx = target_pos[0] - self.position[0];
        const dy = target_pos[1] - self.position[1];
        const dz = target_pos[2] - self.position[2];
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);
        return self.damageAtDistance(dist);
    }

    /// Returns true if target position is within the effective blast radius.
    pub fn isWithinAoE(self: ExplosionResult, target_pos: [3]f32) bool {
        const dx = target_pos[0] - self.position[0];
        const dy = target_pos[1] - self.position[1];
        const dz = target_pos[2] - self.position[2];
        const dist_sq = dx * dx + dy * dy + dz * dz;
        return dist_sq <= (self.aoe_radius * self.aoe_radius);
    }
};

/// High-speed firework projectile fired from a Crossbow.
/// - Loaded in offhand (or main inventory) into crossbow.
/// - Explodes on entity impact, block impact, or max flight range with a 4.5m AoE radius.
/// - Multishot fires 3 fan-out firework rockets (-10°, 0°, +10°) for 1 rocket item ammunition cost.
pub const CrossbowFireworkShot = struct {
    position: [3]f32,
    velocity: [3]f32,
    star_count: u8,
    flight_duration: FlightDuration = .duration_1,
    ticks_alive: u32 = 0,
    max_ticks: u32 = 50,
    distance_traveled: f32 = 0.0,
    max_flight_range: f32 = 96.0,
    aoe_radius: f32 = 4.5,
    is_exploded: bool = false,
    from_offhand: bool = true,
    has_multishot: bool = false,
    fan_angle_deg: f32 = 0.0,

    pub const default_aoe_radius: f32 = 4.5;
    pub const launch_speed: f32 = 38.0; // 38.0 m/s matching projectile.crossbow_rocket_speed
    pub const fan_angles_deg: [3]f32 = .{ -10.0, 0.0, 10.0 };
    pub const multishot_durability_cost: u8 = 3;
    pub const standard_durability_cost: u8 = 1;
    pub const multishot_item_ammo_cost: u8 = 1;
    pub const standard_item_ammo_cost: u8 = 1;

    /// Initialize a single crossbow firework rocket projectile.
    pub fn init(
        pos: [3]f32,
        direction: [3]f32,
        star_count: u8,
        duration: FlightDuration,
        from_offhand: bool,
    ) CrossbowFireworkShot {
        const norm_dir = normalizeVec3(direction);
        const vel = [3]f32{
            norm_dir[0] * launch_speed,
            norm_dir[1] * launch_speed + 0.4, // Slight ballistic compensation
            norm_dir[2] * launch_speed,
        };

        return .{
            .position = pos,
            .velocity = vel,
            .star_count = star_count,
            .flight_duration = duration,
            .max_ticks = duration.toTicks(),
            .from_offhand = from_offhand,
            .has_multishot = false,
            .fan_angle_deg = 0.0,
        };
    }

    /// Initialize 3 fan-out firework rockets for a Multishot crossbow firing.
    /// Fires left (-10°), center (0°), and right (+10°) while consuming only 1 rocket item!
    pub fn initMultishot(
        pos: [3]f32,
        base_direction: [3]f32,
        star_count: u8,
        duration: FlightDuration,
        from_offhand: bool,
    ) [3]CrossbowFireworkShot {
        const norm_base = normalizeVec3(base_direction);
        var shots: [3]CrossbowFireworkShot = undefined;

        for (fan_angles_deg, 0..) |angle_deg, i| {
            const rotated_dir = rotateYaw(norm_base, angle_deg);
            const vel = [3]f32{
                rotated_dir[0] * launch_speed,
                rotated_dir[1] * launch_speed + 0.4,
                rotated_dir[2] * launch_speed,
            };

            shots[i] = .{
                .position = pos,
                .velocity = vel,
                .star_count = star_count,
                .flight_duration = duration,
                .max_ticks = duration.toTicks(),
                .from_offhand = from_offhand,
                .has_multishot = true,
                .fan_angle_deg = angle_deg,
            };
        }

        return shots;
    }

    /// Steps the projectile physics forward by `dt` seconds.
    /// Returns an `ExplosionResult` if the shot detonates (range exhausted, max duration reached).
    pub fn tick(self: *CrossbowFireworkShot, dt: f32) ?ExplosionResult {
        if (self.is_exploded) return null;

        self.ticks_alive += 1;
        const step_x = self.velocity[0] * dt;
        const step_y = self.velocity[1] * dt;
        const step_z = self.velocity[2] * dt;
        const step_dist = @sqrt(step_x * step_x + step_y * step_y + step_z * step_z);

        self.position[0] += step_x;
        self.position[1] += step_y;
        self.position[2] += step_z;
        self.distance_traveled += step_dist;

        // Apply slight atmospheric drag
        self.velocity[0] *= (1.0 - 0.01 * dt);
        self.velocity[1] -= 0.05 * dt; // Gravity
        self.velocity[2] *= (1.0 - 0.01 * dt);

        if (self.distance_traveled >= self.max_flight_range) {
            return self.explode(.range_exhausted);
        }

        if (self.ticks_alive >= self.max_ticks) {
            return self.explode(.timer_exhausted);
        }

        return null;
    }

    /// Checks collision against an entity bounding sphere.
    /// If collision occurs, immediately detonates and returns `ExplosionResult`.
    pub fn checkEntityImpact(self: *CrossbowFireworkShot, entity_pos: [3]f32, entity_radius: f32) ?ExplosionResult {
        if (self.is_exploded) return null;

        const dx = self.position[0] - entity_pos[0];
        const dy = self.position[1] - entity_pos[1];
        const dz = self.position[2] - entity_pos[2];
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);

        const projectile_radius: f32 = 0.25;
        if (dist <= (entity_radius + projectile_radius)) {
            return self.explode(.entity_impact);
        }
        return null;
    }

    /// Detonates against terrain or a solid block surface.
    pub fn checkBlockImpact(self: *CrossbowFireworkShot, is_solid_block: bool) ?ExplosionResult {
        if (self.is_exploded or !is_solid_block) return null;
        return self.explode(.block_impact);
    }

    /// Manually or automatically trigger rocket explosion.
    pub fn explode(self: *CrossbowFireworkShot, cause: ExplosionCause) ExplosionResult {
        self.is_exploded = true;
        const center_dmg = FireworkDamage.compute(self.star_count);

        return .{
            .position = self.position,
            .aoe_radius = self.aoe_radius,
            .center_damage = center_dmg,
            .star_count = self.star_count,
            .cause = cause,
        };
    }

    /// Computes damage delivered to an entity at target_pos if exploded right now.
    pub fn calculateDamageToTarget(self: CrossbowFireworkShot, target_pos: [3]f32) f32 {
        const center_dmg = FireworkDamage.compute(self.star_count);
        const dx = target_pos[0] - self.position[0];
        const dy = target_pos[1] - self.position[1];
        const dz = target_pos[2] - self.position[2];
        const dist = @sqrt(dx * dx + dy * dy + dz * dz);
        return computeDamageAtDistance(center_dmg, dist, self.aoe_radius);
    }
};

/// Complete Firework Rocket item structure holding 0..7 firework stars and flight duration.
pub const FireworkRocket = struct {
    flight_duration: FlightDuration = .duration_1,
    star_count: u8 = 0,
    stars: [7]?FireworkStar = [_]?FireworkStar{null} ** 7,

    /// Crafts firework rockets: 1 paper + 1..3 gunpowder + 0..7 stars -> 3 rockets.
    pub fn craft(paper: u8, gunpowder: u8, stars: []const FireworkStar) !FireworkRocket {
        if (paper < FlightDuration.paper_per_craft) return error.MissingPaper;
        const duration = FlightDuration.fromGunpowder(gunpowder) orelse return error.InvalidGunpowderCount;
        if (stars.len > FireworkDamage.max_stars) return error.TooManyStars;

        var rocket = FireworkRocket{
            .flight_duration = duration,
            .star_count = @intCast(stars.len),
        };

        for (stars, 0..) |star, i| {
            rocket.stars[i] = star;
        }

        return rocket;
    }

    /// Crafts pure Elytra propulsion boost rocket (0 stars, duration 1..3).
    pub fn craftBoostOnly(paper: u8, gunpowder: u8) !FireworkRocket {
        return craft(paper, gunpowder, &.{});
    }

    /// Center explosion damage produced by this rocket.
    pub fn explosionDamage(self: FireworkRocket) f32 {
        return FireworkDamage.compute(self.star_count);
    }

    /// Returns true if this rocket is completely safe for Elytra boosting (0 stars).
    pub fn isSafeForElytra(self: FireworkRocket) bool {
        return FireworkDamage.isSafeForElytra(self.star_count);
    }
};

/// Simulated inventory state for crossbow ammunition loading from offhand.
pub const CrossbowAmmunitionLoader = struct {
    offhand_item: ?FireworkRocket = null,
    main_hand_has_crossbow: bool = true,
    crossbow_has_multishot: bool = false,

    pub const LoadOutcome = struct {
        loaded_rocket: FireworkRocket,
        consumed_rocket_count: u8,
        durability_wear: u8,
        shot_count: u8,
    };

    /// Loads rocket from offhand and resolves firing resource costs.
    pub fn loadAndFire(self: *CrossbowAmmunitionLoader) !LoadOutcome {
        if (!self.main_hand_has_crossbow) return error.NoCrossbowInMainHand;
        const rocket = self.offhand_item orelse return error.NoOffhandAmmunition;

        // Ammunition consumed is strictly 1 rocket item regardless of Multishot
        self.offhand_item = null;

        const durability = if (self.crossbow_has_multishot)
            CrossbowFireworkShot.multishot_durability_cost
        else
            CrossbowFireworkShot.standard_durability_cost;

        const count: u8 = if (self.crossbow_has_multishot) 3 else 1;

        return .{
            .loaded_rocket = rocket,
            .consumed_rocket_count = 1,
            .durability_wear = durability,
            .shot_count = count,
        };
    }
};

// ============================================================================
// Internal Vector Math Utilities
// ============================================================================

fn normalizeVec3(v: [3]f32) [3]f32 {
    const len_sq = v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
    if (len_sq <= 0.000001) return .{ 0.0, 1.0, 0.0 };
    const inv_len = 1.0 / @sqrt(len_sq);
    return .{ v[0] * inv_len, v[1] * inv_len, v[2] * inv_len };
}

fn rotateYaw(v: [3]f32, angle_deg: f32) [3]f32 {
    if (angle_deg == 0.0) return v;
    const rad = angle_deg * (std.math.pi / 180.0);
    const cos_a = @cos(rad);
    const sin_a = @sin(rad);

    // Rotation around Y axis (vertical)
    return .{
        v[0] * cos_a + v[2] * sin_a,
        v[1],
        -v[0] * sin_a + v[2] * cos_a,
    };
}

// ============================================================================
// Comprehensive Unit Tests
// ============================================================================

test "FireworkBurstShape variants, crafting modifiers and names" {
    try std.testing.expectEqual(FireworkBurstShape.default(), .small_ball);
    try std.testing.expectEqualStrings("Small Ball", FireworkBurstShape.small_ball.name());
    try std.testing.expectEqualStrings("Large Ball", FireworkBurstShape.large_ball.name());
    try std.testing.expectEqualStrings("Star-shaped", FireworkBurstShape.star_shaped.name());
    try std.testing.expectEqualStrings("Creeper-shaped", FireworkBurstShape.creeper_face.name());
    try std.testing.expectEqualStrings("Burst", FireworkBurstShape.burst.name());

    try std.testing.expect(FireworkBurstShape.small_ball.craftingModifier() == null);
    try std.testing.expectEqualStrings("fire_charge", FireworkBurstShape.large_ball.craftingModifier().?);
    try std.testing.expectEqualStrings("gold_nugget", FireworkBurstShape.star_shaped.craftingModifier().?);
    try std.testing.expectEqualStrings("mob_head", FireworkBurstShape.creeper_face.craftingModifier().?);
    try std.testing.expectEqualStrings("feather", FireworkBurstShape.burst.craftingModifier().?);
}

test "FireworkBurstShape particle counts and visual multipliers" {
    try std.testing.expectEqual(@as(u16, 24), FireworkBurstShape.small_ball.particleCount());
    try std.testing.expectEqual(@as(u16, 56), FireworkBurstShape.large_ball.particleCount());
    try std.testing.expectEqual(@as(u16, 35), FireworkBurstShape.star_shaped.particleCount());
    try std.testing.expectEqual(@as(u16, 32), FireworkBurstShape.creeper_face.particleCount());
    try std.testing.expectEqual(@as(u16, 42), FireworkBurstShape.burst.particleCount());

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), FireworkBurstShape.small_ball.visualRadiusMultiplier(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), FireworkBurstShape.large_ball.visualRadiusMultiplier(), 0.001);
}

test "FireworkBurstShape particle trajectory generation" {
    const total = 20;
    for (0..total) |i| {
        const vel_small = FireworkBurstShape.small_ball.generateParticleVelocity(i, total);
        const len_sq = vel_small[0] * vel_small[0] + vel_small[1] * vel_small[1] + vel_small[2] * vel_small[2];
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), @sqrt(len_sq), 0.01);

        const vel_large = FireworkBurstShape.large_ball.generateParticleVelocity(i, total);
        const len_large = @sqrt(vel_large[0] * vel_large[0] + vel_large[1] * vel_large[1] + vel_large[2] * vel_large[2]);
        try std.testing.expectApproxEqAbs(@as(f32, 2.0), len_large, 0.01);

        const vel_star = FireworkBurstShape.star_shaped.generateParticleVelocity(i, total);
        try std.testing.expect(!std.math.isNan(vel_star[0]));
        try std.testing.expect(!std.math.isNan(vel_star[1]));
        try std.testing.expect(!std.math.isNan(vel_star[2]));
    }
}

test "DyeColor sRGB values and conversions" {
    const red_rgb = DyeColor.red.toRgb();
    try std.testing.expectEqual(@as(u8, 0xB0), red_rgb[0]);
    try std.testing.expectEqual(@as(u8, 0x2E), red_rgb[1]);
    try std.testing.expectEqual(@as(u8, 0x26), red_rgb[2]);

    const white_rgb = DyeColor.white.toRgb();
    try std.testing.expectEqual(@as(u8, 0xF9), white_rgb[0]);
    try std.testing.expectEqual(@as(u8, 0xFF), white_rgb[1]);
    try std.testing.expectEqual(@as(u8, 0xFE), white_rgb[2]);

    const blue_f32 = DyeColor.blue.toRgbF32();
    try std.testing.expect(blue_f32[0] >= 0.0 and blue_f32[0] <= 1.0);
    try std.testing.expect(blue_f32[1] >= 0.0 and blue_f32[1] <= 1.0);
    try std.testing.expect(blue_f32[2] >= 0.0 and blue_f32[2] <= 1.0);
}

test "FireworkEffectFlags validation, twinkle and trail modifiers" {
    var flags = FireworkEffectFlags{
        .has_twinkle = true,
        .has_trail = true,
        .primary_colors = 3,
        .fade_colors = 2,
    };

    try std.testing.expect(flags.isValid());
    try std.testing.expectEqual(@as(u8, 5), flags.totalDyes());
    try std.testing.expect(flags.canAddPrimary(5));
    try std.testing.expect(!flags.canAddPrimary(6)); // 3 + 6 > 8
    try std.testing.expect(flags.canAddFade(6));
    try std.testing.expect(!flags.canAddFade(7)); // 2 + 7 > 8

    flags.primary_colors = 0;
    try std.testing.expect(!flags.isValid()); // minimum 1 primary color required

    flags.primary_colors = 9;
    try std.testing.expect(!flags.isValid()); // max 8
}

test "FireworkStar crafting, color limits and fade transitions" {
    const dyes = [_]DyeColor{ .red, .yellow, .blue };
    var star = try FireworkStar.craft(true, .star_shaped, &dyes, true, false);

    try std.testing.expectEqual(FireworkBurstShape.star_shaped, star.shape);
    try std.testing.expect(star.flags.has_twinkle);
    try std.testing.expect(!star.flags.has_trail);
    try std.testing.expectEqual(@as(u8, 3), star.flags.primary_colors);
    try std.testing.expectEqual(DyeColor.red, star.primary_palette[0].?);
    try std.testing.expectEqual(DyeColor.yellow, star.primary_palette[1].?);
    try std.testing.expectEqual(DyeColor.blue, star.primary_palette[2].?);
    try std.testing.expect(star.primary_palette[3] == null);

    const fade = [_]DyeColor{ .white, .light_blue };
    try star.applyFade(&fade);
    try std.testing.expectEqual(@as(u8, 2), star.flags.fade_colors);
    try std.testing.expectEqual(DyeColor.white, star.fade_palette[0].?);
    try std.testing.expectEqual(DyeColor.light_blue, star.fade_palette[1].?);

    // Missing gunpowder failure
    try std.testing.expectError(error.MissingGunpowder, FireworkStar.craft(false, null, &dyes, false, false));
    // Empty dyes failure
    try std.testing.expectError(error.NoPrimaryDyes, FireworkStar.craft(true, null, &.{}, false, false));
}

test "FlightDuration 1..3 enum, seconds and tick conversions" {
    try std.testing.expectEqual(FlightDuration.duration_1, FlightDuration.fromGunpowder(1).?);
    try std.testing.expectEqual(FlightDuration.duration_2, FlightDuration.fromGunpowder(2).?);
    try std.testing.expectEqual(FlightDuration.duration_3, FlightDuration.fromGunpowder(3).?);
    try std.testing.expect(FlightDuration.fromGunpowder(0) == null);
    try std.testing.expect(FlightDuration.fromGunpowder(4) == null);

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), FlightDuration.duration_1.toSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.75), FlightDuration.duration_2.toSeconds(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), FlightDuration.duration_3.toSeconds(), 0.001);

    try std.testing.expectEqual(@as(u32, 20), FlightDuration.duration_1.toTicks());
    try std.testing.expectEqual(@as(u32, 35), FlightDuration.duration_2.toTicks());
    try std.testing.expectEqual(@as(u32, 50), FlightDuration.duration_3.toTicks());
}

test "FlightDuration altitude ranges" {
    const r1 = FlightDuration.duration_1.altitudeRange();
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), r1.min, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 22.0), r1.max, 0.01);
    try std.testing.expect(r1.contains(17.0));
    try std.testing.expect(!r1.contains(10.0));

    const r2 = FlightDuration.duration_2.altitudeRange();
    try std.testing.expectApproxEqAbs(@as(f32, 18.0), r2.min, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 34.0), r2.max, 0.01);

    const r3 = FlightDuration.duration_3.altitudeRange();
    try std.testing.expectApproxEqAbs(@as(f32, 32.0), r3.min, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 54.0), r3.max, 0.01);
}

test "FireworkDamage: 0 stars deal 0.0 damage (safe for Elytra boost)" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), computeFireworkDamage(0), 0.0001);
    try std.testing.expect(isSafeForElytraBoost(0));
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), computeElytraBoostDamage(0), 0.0001);
}

test "FireworkDamage: 1..7 stars exact formula 5.0 + (star_count - 1) * 2.0" {
    // 1 star: 5.0 + 0 = 5.0 HP
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), computeFireworkDamage(1), 0.0001);
    // 2 stars: 5.0 + 2.0 = 7.0 HP
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), computeFireworkDamage(2), 0.0001);
    // 3 stars: 5.0 + 4.0 = 9.0 HP
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), computeFireworkDamage(3), 0.0001);
    // 4 stars: 5.0 + 6.0 = 11.0 HP
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), computeFireworkDamage(4), 0.0001);
    // 5 stars: 5.0 + 8.0 = 13.0 HP
    try std.testing.expectApproxEqAbs(@as(f32, 13.0), computeFireworkDamage(5), 0.0001);
    // 6 stars: 5.0 + 10.0 = 15.0 HP
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), computeFireworkDamage(6), 0.0001);
    // 7 stars: 5.0 + 12.0 = 17.0 HP (max)
    try std.testing.expectApproxEqAbs(@as(f32, 17.0), computeFireworkDamage(7), 0.0001);

    // Clamps at max 7 stars
    try std.testing.expectApproxEqAbs(@as(f32, 17.0), computeFireworkDamage(8), 0.0001);
}

test "FireworkDamage: Elytra boost self-damage and fatal hazard" {
    try std.testing.expect(!isSafeForElytraBoost(1));
    try std.testing.expect(!isSafeForElytraBoost(7));

    // Boosting with a 7-star rocket deals 17.0 HP directly to player
    const self_damage = computeElytraBoostDamage(7);
    try std.testing.expectApproxEqAbs(@as(f32, 17.0), self_damage, 0.0001);

    // A player with 16.0 HP will suffer fatal damage
    try std.testing.expect(FireworkDamage.isFatal(self_damage, 16.0));
    // A player with full 20.0 HP survives with only 3.0 HP
    try std.testing.expect(!FireworkDamage.isFatal(self_damage, 20.0));
}

test "FireworkDamage: distance falloff and AoE radius" {
    const center_dmg = computeFireworkDamage(7); // 17.0 HP
    const aoe = 4.5;

    // At origin: 100% damage
    try std.testing.expectApproxEqAbs(@as(f32, 17.0), computeDamageAtDistance(center_dmg, 0.0, aoe), 0.001);
    // At half radius (2.25m): 50% damage
    try std.testing.expectApproxEqAbs(@as(f32, 8.5), computeDamageAtDistance(center_dmg, 2.25, aoe), 0.001);
    // At boundary (4.5m): 0 damage
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), computeDamageAtDistance(center_dmg, 4.5, aoe), 0.001);
    // Beyond boundary: 0 damage
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), computeDamageAtDistance(center_dmg, 5.0, aoe), 0.001);
}

test "CrossbowFireworkShot: offhand loading and single-shot initialization" {
    const pos = [3]f32{ 0.0, 64.0, 0.0 };
    const dir = [3]f32{ 0.0, 0.0, 1.0 }; // Looking south
    const shot = CrossbowFireworkShot.init(pos, dir, 5, .duration_2, true);

    try std.testing.expect(shot.from_offhand);
    try std.testing.expect(!shot.has_multishot);
    try std.testing.expectEqual(@as(u8, 5), shot.star_count);
    try std.testing.expectEqual(FlightDuration.duration_2, shot.flight_duration);
    try std.testing.expectEqual(@as(u32, 35), shot.max_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), shot.aoe_radius, 0.001);

    // Velocity forward along +Z with slight 0.4 vertical loft
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shot.velocity[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), shot.velocity[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 38.0), shot.velocity[2], 0.001);
}

test "CrossbowFireworkShot: Multishot fan-out creates 3 rockets (-10, 0, +10 deg)" {
    const pos = [3]f32{ 10.0, 70.0, 10.0 };
    const dir = [3]f32{ 0.0, 0.0, 1.0 };
    const shots = CrossbowFireworkShot.initMultishot(pos, dir, 3, .duration_1, true);

    try std.testing.expectEqual(@as(usize, 3), shots.len);

    // Left fan (-10°)
    try std.testing.expectApproxEqAbs(@as(f32, -10.0), shots[0].fan_angle_deg, 0.001);
    try std.testing.expect(shots[0].has_multishot);
    try std.testing.expect(shots[0].velocity[0] < 0.0); // angled left (-X)

    // Center fan (0°)
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shots[1].fan_angle_deg, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), shots[1].velocity[0], 0.001); // straight ahead

    // Right fan (+10°)
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), shots[2].fan_angle_deg, 0.001);
    try std.testing.expect(shots[2].velocity[0] > 0.0); // angled right (+X)
}

test "CrossbowFireworkShot: Multishot costs only 1 rocket item and 3 durability" {
    var loader = CrossbowAmmunitionLoader{
        .offhand_item = FireworkRocket{
            .flight_duration = .duration_1,
            .star_count = 4,
        },
        .main_hand_has_crossbow = true,
        .crossbow_has_multishot = true,
    };

    const outcome = try loader.loadAndFire();
    // Strictly 1 firework rocket consumed from offhand
    try std.testing.expectEqual(@as(u8, 1), outcome.consumed_rocket_count);
    // Multishot consumes 3 durability points
    try std.testing.expectEqual(@as(u8, 3), outcome.durability_wear);
    // Fires 3 fan-out projectiles
    try std.testing.expectEqual(@as(u8, 3), outcome.shot_count);
    // Offhand is now empty
    try std.testing.expect(loader.offhand_item == null);
}

test "CrossbowFireworkShot: standard shot costs 1 rocket item and 1 durability" {
    var loader = CrossbowAmmunitionLoader{
        .offhand_item = FireworkRocket{
            .flight_duration = .duration_2,
            .star_count = 2,
        },
        .main_hand_has_crossbow = true,
        .crossbow_has_multishot = false,
    };

    const outcome = try loader.loadAndFire();
    try std.testing.expectEqual(@as(u8, 1), outcome.consumed_rocket_count);
    try std.testing.expectEqual(@as(u8, 1), outcome.durability_wear);
    try std.testing.expectEqual(@as(u8, 1), outcome.shot_count);
}

test "CrossbowFireworkShot: entity impact detonation and 4.5m AoE blast" {
    var shot = CrossbowFireworkShot.init(.{ 0.0, 64.0, 0.0 }, .{ 0.0, 0.0, 1.0 }, 7, .duration_1, true);

    // Entity at Z = 1.0 with radius 0.8
    shot.position = .{ 0.0, 64.0, 0.5 };
    const impact = shot.checkEntityImpact(.{ 0.0, 64.0, 1.0 }, 0.8);

    try std.testing.expect(impact != null);
    const expl = impact.?;
    try std.testing.expect(shot.is_exploded);
    try std.testing.expectEqual(ExplosionCause.entity_impact, expl.cause);
    try std.testing.expectApproxEqAbs(@as(f32, 17.0), expl.center_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), expl.aoe_radius, 0.001);

    // Damage to adjacent entity 1.5m away
    const neighbor_damage = expl.damageAtDistance(1.5);
    // 17.0 * (1 - 1.5/4.5) = 17.0 * (2/3) = 11.333 HP
    try std.testing.expectApproxEqAbs(@as(f32, 11.333), neighbor_damage, 0.01);
}

test "CrossbowFireworkShot: flight tick and max flight range detonation" {
    var shot = CrossbowFireworkShot.init(.{ 0.0, 64.0, 0.0 }, .{ 1.0, 0.0, 0.0 }, 3, .duration_1, true);
    shot.max_flight_range = 10.0; // small range for test

    var exploded: ?ExplosionResult = null;
    while (exploded == null) {
        exploded = shot.tick(0.1);
    }

    try std.testing.expect(exploded != null);
    try std.testing.expectEqual(ExplosionCause.range_exhausted, exploded.?.cause);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), exploded.?.center_damage, 0.001);
}

test "FireworkRocket crafting: 1 paper + 1..3 gunpowder -> 3 rockets with up to 7 stars" {
    const dyes = [_]DyeColor{.red};
    const star1 = try FireworkStar.craft(true, null, &dyes, false, false);
    const star2 = try FireworkStar.craft(true, .large_ball, &dyes, true, true);
    const stars = [_]FireworkStar{ star1, star2 };

    const rocket = try FireworkRocket.craft(1, 2, &stars);
    try std.testing.expectEqual(FlightDuration.duration_2, rocket.flight_duration);
    try std.testing.expectEqual(@as(u8, 2), rocket.star_count);
    try std.testing.expect(!rocket.isSafeForElytra());
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), rocket.explosionDamage(), 0.001);

    // Pure boost rocket
    const boost_rocket = try FireworkRocket.craftBoostOnly(1, 3);
    try std.testing.expectEqual(FlightDuration.duration_3, boost_rocket.flight_duration);
    try std.testing.expectEqual(@as(u8, 0), boost_rocket.star_count);
    try std.testing.expect(boost_rocket.isSafeForElytra());
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), boost_rocket.explosionDamage(), 0.001);
}
