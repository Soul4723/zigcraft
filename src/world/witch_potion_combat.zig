const std = @import("std");

/// Max health of a witch entity (13 hearts = 26.0 HP).
pub const witch_max_health: f32 = 26.0;

/// Drinking animation duration in ticks (32 ticks = 1.6 seconds).
pub const witch_drinking_duration_ticks: u32 = 32;
pub const witch_drinking_duration_seconds: f32 = 1.6;

/// Attack/throw cooldown in ticks (40 ticks = 2.0 seconds).
pub const witch_attack_cooldown_ticks: u32 = 40;
pub const witch_attack_cooldown_seconds: f32 = 2.0;

/// Maximum range for throwing splash potions (10.0 meters).
pub const witch_throw_range_max: f32 = 10.0;

/// Witch innate magic resistance: reduces magic damage by 85% (receives 15%).
pub const witch_magic_damage_multiplier: f32 = 0.15;
pub const witch_magic_resistance_percent: f32 = 85.0;

/// Splash potion effect radius (3.0 meters).
pub const splash_potion_radius: f32 = 3.0;

/// Raid medic scan radius for wounded allies (10.0 meters).
pub const raid_scan_radius: f32 = 10.0;

/// Threshold ratio for wounded raid allies: health < 80% of max health.
pub const raid_wounded_health_threshold_ratio: f32 = 0.80;

/// Offensive potion range thresholds.
pub const slowness_range_threshold: f32 = 8.0;
pub const close_combat_range_threshold: f32 = 3.0;

/// Health thresholds.
pub const low_health_threshold: f32 = 11.0;
pub const target_low_health_threshold: f32 = 8.0;

/// Target distance threshold for drinking swiftness.
pub const far_distance_threshold: f32 = 11.0;

/// Potion effect durations (in 20-tick seconds).
pub const fire_resistance_duration_ticks: u32 = 3600; // 3 minutes = 180s * 20
pub const water_breathing_duration_ticks: u32 = 3600; // 3 minutes = 180s * 20
pub const swiftness_duration_ticks: u32 = 3600; // 3 minutes = 180s * 20
pub const swiftness_speed_multiplier: f32 = 1.20; // +20% movement speed

pub const healing_i_restore_amount: f32 = 4.0; // +4.0 HP
pub const harming_i_damage_amount: f32 = 6.0; // 6.0 HP direct magic damage

pub const slowness_i_duration_ticks: u32 = 600; // 30s * 20
pub const slowness_i_speed_multiplier: f32 = 0.85; // -15% speed reduction

pub const poison_i_duration_ticks: u32 = 900; // 45s * 20
pub const poison_i_interval_ticks: u32 = 25; // 1.25s * 20
pub const poison_i_damage_per_interval: f32 = 1.0; // 1.0 HP / 1.25s
pub const poison_i_min_health_limit: f32 = 1.0; // Poison cannot kill below 1.0 HP

pub const weakness_i_duration_ticks: u32 = 1800; // 90s * 20
pub const weakness_i_attack_reduction: f32 = 4.0; // -4.0 attack damage
pub const weakness_chance_close_combat: f32 = 0.25; // 25% chance

pub const regeneration_i_duration_ticks: u32 = 900; // 45s * 20
pub const regeneration_i_interval_ticks: u32 = 50; // 2.5s * 20
pub const regeneration_i_heal_per_interval: f32 = 1.0; // 1.0 HP per interval

/// Potion types consumed defensively by the witch.
pub const DrinkPotionType = enum {
    none,
    fire_resistance,
    water_breathing,
    healing,
    swiftness,
};

/// Offensive splash potions thrown at enemies.
pub const OffensivePotionType = enum {
    slowness,
    poison,
    weakness,
    harming,
};

/// Healing potions thrown at raid ally clusters.
pub const RaidHealPotionType = enum {
    healing,
    regeneration,
};

/// Types of damage for combat mitigation calculation.
pub const DamageType = enum {
    generic,
    physical,
    magic,
    poison,
    fire,
    fall,
    drowning,
};

/// Roles of Illager allies in a village raid.
pub const RaidIllagerRole = enum {
    pillager,
    vindicator,
    ravager,
    evoker,
    witch,
};

/// Witch defeat item drop types.
pub const WitchDropItem = enum {
    glass_bottle,
    glowstone_dust,
    redstone_dust,
    gunpowder,
    sugar,
    spider_eye,
    stick,
    potion_held,
};

/// 3D position vector for entity spatial kinematics and distance math.
pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn distanceTo(self: Vec3, other: Vec3) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    pub fn horizontalDistanceTo(self: Vec3, other: Vec3) f32 {
        const dx = self.x - other.x;
        const dz = self.z - other.z;
        return @sqrt(dx * dx + dz * dz);
    }
};

/// Raid ally representation for village raid medic behaviors.
pub const RaidAlly = struct {
    role: RaidIllagerRole,
    position: Vec3,
    health: f32,
    max_health: f32,
    has_regeneration: bool = false,
    regeneration_ticks: u32 = 0,
    active: bool = true,

    pub fn isWounded(self: RaidAlly) bool {
        return self.active and self.health > 0.0 and self.health < (self.max_health * raid_wounded_health_threshold_ratio);
    }

    pub fn healthPercentage(self: RaidAlly) f32 {
        if (self.max_health <= 0.0) return 0.0;
        return (self.health / self.max_health) * 100.0;
    }
};

/// Enemy target representation (Player or hostile entity).
pub const TargetEntity = struct {
    position: Vec3,
    health: f32 = 20.0,
    max_health: f32 = 20.0,
    is_alive: bool = true,

    // Status effect flags & timers
    has_slowness: bool = false,
    slowness_ticks: u32 = 0,
    has_poison: bool = false,
    poison_ticks: u32 = 0,
    poison_step_timer: u32 = 0,
    has_weakness: bool = false,
    weakness_ticks: u32 = 0,

    // Combat attributes
    base_attack_damage: f32 = 5.0,
    current_attack_damage: f32 = 5.0,
    base_movement_speed: f32 = 0.25,
    current_movement_speed: f32 = 0.25,

    pub fn applySplashEffect(self: *TargetEntity, effect: OffensivePotionType) void {
        switch (effect) {
            .slowness => {
                self.has_slowness = true;
                self.slowness_ticks = slowness_i_duration_ticks;
                self.current_movement_speed = self.base_movement_speed * slowness_i_speed_multiplier;
            },
            .poison => {
                self.has_poison = true;
                self.poison_ticks = poison_i_duration_ticks;
                self.poison_step_timer = 0;
            },
            .weakness => {
                self.has_weakness = true;
                self.weakness_ticks = weakness_i_duration_ticks;
                self.current_attack_damage = @max(0.0, self.base_attack_damage - weakness_i_attack_reduction);
            },
            .harming => {
                const dmg = harming_i_damage_amount;
                if (self.health > dmg) {
                    self.health -= dmg;
                } else {
                    self.health = 0.0;
                    self.is_alive = false;
                }
            },
        }
    }

    pub fn tickEffects(self: *TargetEntity) void {
        if (self.slowness_ticks > 0) {
            self.slowness_ticks -= 1;
            if (self.slowness_ticks == 0) {
                self.has_slowness = false;
                self.current_movement_speed = self.base_movement_speed;
            }
        }
        if (self.weakness_ticks > 0) {
            self.weakness_ticks -= 1;
            if (self.weakness_ticks == 0) {
                self.has_weakness = false;
                self.current_attack_damage = self.base_attack_damage;
            }
        }
        if (self.poison_ticks > 0) {
            self.poison_ticks -= 1;
            self.poison_step_timer += 1;
            if (self.poison_step_timer >= poison_i_interval_ticks) {
                self.poison_step_timer = 0;
                // Deals 1.0 HP per 1.25s down to 1.0 HP
                if (self.health > poison_i_min_health_limit) {
                    self.health = @max(poison_i_min_health_limit, self.health - poison_i_damage_per_interval);
                }
            }
            if (self.poison_ticks == 0) {
                self.has_poison = false;
            }
        }
    }
};

/// Result of a splash potion effect on area entities.
pub const SplashEffectResult = struct {
    potion_type: OffensivePotionType,
    entities_affected: u32,
    total_damage_or_healing: f32,
};

/// Result of a raid medic heal splash on ally entities.
pub const RaidHealSplashResult = struct {
    potion_type: RaidHealPotionType,
    target_cluster: Vec3,
    allies_healed: u32,
    total_health_restored: f32,
};

/// Individual loot drop record.
pub const ItemDrop = struct {
    item: WitchDropItem,
    count: u8,
    potion_type: DrinkPotionType = .none,
};

/// Complete witch defeat loot drop collection.
pub const WitchDefeatDrops = struct {
    drops: [8]ItemDrop = [_]ItemDrop{.{ .item = .glass_bottle, .count = 0 }} ** 8,
    count: u8 = 0,
    held_potion: ?DrinkPotionType = null,

    pub fn addDrop(self: *WitchDefeatDrops, item: WitchDropItem, count: u8, potion: DrinkPotionType) void {
        if (self.count < self.drops.len) {
            self.drops[self.count] = .{ .item = item, .count = count, .potion_type = potion };
            self.count += 1;
        }
    }
};

// ============================================================================
// Core Decision & Mitigation Logic Functions
// ============================================================================

/// Evaluates self-drinking priority for the witch:
/// Priority order:
/// 1. Fire / burning damage -> Potion of Fire Resistance (3 minutes).
/// 2. Underwater / drowning -> Potion of Water Breathing (3 minutes).
/// 3. Low HP (< 11.0 HP) -> Potion of Healing I (+4.0 HP).
/// 4. Far distance (> 11.0m) -> Potion of Swiftness I (+20% speed for 3 minutes).
pub fn selectDefensiveDrink(
    on_fire_or_burning: bool,
    has_fire_resistance: bool,
    underwater_or_drowning: bool,
    has_water_breathing: bool,
    current_health: f32,
    dist_to_target: f32,
    has_swiftness: bool,
) DrinkPotionType {
    if (on_fire_or_burning and !has_fire_resistance) {
        return .fire_resistance;
    }
    if (underwater_or_drowning and !has_water_breathing) {
        return .water_breathing;
    }
    if (current_health < low_health_threshold) {
        return .healing;
    }
    if (dist_to_target > far_distance_threshold and !has_swiftness) {
        return .swiftness;
    }
    return .none;
}

/// Evaluates offensive splash potion selection:
/// Priority order:
/// 1. If target within 8.0m and does not have Slowness: Splash Potion of Slowness I.
/// 2. If target health >= 8.0 HP and not poisoned: Splash Potion of Poison I.
/// 3. If target in close combat (< 3.0m) and 25% chance roll succeeds: Splash Potion of Weakness I.
/// 4. If target health < 8.0 HP: Splash Potion of Harming I.
/// 5. Fallback: Splash Potion of Harming I.
pub fn selectOffensiveSplashThrow(
    dist_to_target: f32,
    target_health: f32,
    target_has_slowness: bool,
    target_has_poison: bool,
    target_has_weakness: bool,
    weakness_roll_percent: f32,
) ?OffensivePotionType {
    if (dist_to_target > witch_throw_range_max) {
        return null; // Target out of 10.0m throw range
    }
    if (dist_to_target <= slowness_range_threshold and !target_has_slowness) {
        return .slowness;
    }
    if (target_health >= target_low_health_threshold and !target_has_poison) {
        return .poison;
    }
    if (dist_to_target < close_combat_range_threshold and !target_has_weakness and weakness_roll_percent < 25.0) {
        return .weakness;
    }
    if (target_health < target_low_health_threshold) {
        return .harming;
    }
    return .harming;
}

/// Applies witch's innate 85% magic resistance to incoming magic damage.
pub fn applyWitchMagicResistance(incoming_damage: f32) f32 {
    return incoming_damage * witch_magic_damage_multiplier;
}

/// Witches are 100% immune to poison status effect and poison damage.
pub fn isWitchPoisonImmune() bool {
    return true;
}

/// Computes net damage taken by a witch based on damage type and active buffs.
pub fn computeWitchNetDamage(
    incoming_damage: f32,
    damage_type: DamageType,
    has_fire_resistance: bool,
    has_water_breathing: bool,
) f32 {
    switch (damage_type) {
        .magic => return applyWitchMagicResistance(incoming_damage),
        .poison => return 0.0, // Complete poison immunity
        .fire => if (has_fire_resistance) return 0.0 else return incoming_damage,
        .drowning => if (has_water_breathing) return 0.0 else return incoming_damage,
        .generic, .physical, .fall => return incoming_damage,
    }
}

/// Scans for wounded raid allies within 10.0m (health < 80% max HP).
/// Returns count of wounded allies and populates indices in the output buffer.
pub fn scanWoundedRaidAllies(
    witch_position: Vec3,
    allies: []const RaidAlly,
    out_indices: []usize,
) usize {
    var count: usize = 0;
    for (allies, 0..) |ally, idx| {
        if (!ally.active or ally.health <= 0.0) continue;
        const dist = witch_position.distanceTo(ally.position);
        if (dist <= raid_scan_radius and ally.isWounded()) {
            if (count < out_indices.len) {
                out_indices[count] = idx;
                count += 1;
            }
        }
    }
    return count;
}

/// Computes the cluster centroid coordinates of wounded raid allies.
pub fn computeAllyClusterCentroid(
    allies: []const RaidAlly,
    indices: []const usize,
) ?Vec3 {
    if (indices.len == 0) return null;
    var sum_x: f32 = 0.0;
    var sum_y: f32 = 0.0;
    var sum_z: f32 = 0.0;
    for (indices) |idx| {
        sum_x += allies[idx].position.x;
        sum_y += allies[idx].position.y;
        sum_z += allies[idx].position.z;
    }
    const n = @as(f32, @floatFromInt(indices.len));
    return Vec3{ .x = sum_x / n, .y = sum_y / n, .z = sum_z / n };
}

/// Selects heal potion type: Healing I (+4.0 HP instant) or Regeneration I.
/// Chooses Healing I if any ally is critically low (< 50% max HP) or if already regenerating,
/// otherwise Regeneration I.
pub fn selectRaidHealPotion(
    allies: []const RaidAlly,
    indices: []const usize,
) RaidHealPotionType {
    for (indices) |idx| {
        const ally = allies[idx];
        if (ally.health < ally.max_health * 0.50) {
            return .healing; // Critical health requires immediate burst healing
        }
    }
    return .regeneration;
}

/// Resolves a splash healing potion impact on allies within 3.0m splash radius.
pub fn applySplashHealingToAllies(
    cluster_pos: Vec3,
    allies: []RaidAlly,
    potion_type: RaidHealPotionType,
) RaidHealSplashResult {
    var healed_count: u32 = 0;
    var total_restored: f32 = 0.0;

    for (allies) |*ally| {
        if (!ally.active or ally.health <= 0.0) continue;
        const dist = cluster_pos.distanceTo(ally.position);
        if (dist <= splash_potion_radius) {
            switch (potion_type) {
                .healing => {
                    const before = ally.health;
                    ally.health = @min(ally.max_health, ally.health + healing_i_restore_amount);
                    total_restored += (ally.health - before);
                    healed_count += 1;
                },
                .regeneration => {
                    ally.has_regeneration = true;
                    ally.regeneration_ticks = regeneration_i_duration_ticks;
                    healed_count += 1;
                },
            }
        }
    }

    return .{
        .potion_type = potion_type,
        .target_cluster = cluster_pos,
        .allies_healed = healed_count,
        .total_health_restored = total_restored,
    };
}

/// Maximum drop count per item based on Looting level (0..2 base, +1 per Looting level up to III).
pub fn maxDropCountForLooting(looting_level: u8) u8 {
    const clamped_looting: u8 = @min(looting_level, @as(u8, 3));
    return @as(u8, 2) + clamped_looting;
}

/// Evaluates if the witch drops the potion being consumed upon defeat.
/// If killed while drinking (`is_drinking = true`), the potion is guaranteed to drop!
pub fn evaluateDrinkingPotionDeathDrop(
    is_drinking: bool,
    drinking_potion: DrinkPotionType,
) ?DrinkPotionType {
    if (is_drinking and drinking_potion != .none) {
        return drinking_potion;
    }
    return null;
}

// ============================================================================
// Witch Entity & AI Controller
// ============================================================================

pub const WitchEntity = struct {
    position: Vec3 = .{},
    health: f32 = witch_max_health,
    max_health: f32 = witch_max_health,
    is_alive: bool = true,

    // Environmental state
    is_on_fire: bool = false,
    in_water: bool = false,
    is_in_raid: bool = false,

    // Status effect timers (ticks)
    fire_resistance_ticks: u32 = 0,
    water_breathing_ticks: u32 = 0,
    swiftness_ticks: u32 = 0,
    slowness_ticks: u32 = 0,
    regeneration_ticks: u32 = 0,

    // Movement speed
    base_movement_speed: f32 = 0.25,
    current_movement_speed: f32 = 0.25,

    // Drinking state machine
    is_drinking: bool = false,
    drinking_potion: DrinkPotionType = .none,
    drinking_ticks: u32 = 0, // Counts from 0 up to 32

    // Combat cooldowns
    attack_cooldown_ticks: u32 = 0, // Counts down from 40 to 0

    pub fn init(pos: Vec3) WitchEntity {
        return .{
            .position = pos,
            .health = witch_max_health,
            .max_health = witch_max_health,
            .is_alive = true,
            .current_movement_speed = 0.25,
        };
    }

    pub fn hasFireResistance(self: WitchEntity) bool {
        return self.fire_resistance_ticks > 0;
    }

    pub fn hasWaterBreathing(self: WitchEntity) bool {
        return self.water_breathing_ticks > 0;
    }

    pub fn hasSwiftness(self: WitchEntity) bool {
        return self.swiftness_ticks > 0;
    }

    /// Inflicts damage on the witch with magic resistance and poison immunity.
    pub fn takeDamage(self: *WitchEntity, damage: f32, damage_type: DamageType) f32 {
        if (!self.is_alive) return 0.0;
        const net_dmg = computeWitchNetDamage(
            damage,
            damage_type,
            self.hasFireResistance(),
            self.hasWaterBreathing(),
        );

        if (self.health > net_dmg) {
            self.health -= net_dmg;
        } else {
            self.health = 0.0;
            self.is_alive = false;
        }
        return net_dmg;
    }

    /// Starts the 32-tick drinking animation. Pauses movement.
    pub fn startDrinking(self: *WitchEntity, potion: DrinkPotionType) bool {
        if (potion == .none or self.is_drinking or !self.is_alive) {
            return false;
        }
        self.is_drinking = true;
        self.drinking_potion = potion;
        self.drinking_ticks = 0;
        self.current_movement_speed = 0.0; // Movement paused while drinking
        return true;
    }

    /// Completes the drinking animation and applies the consumed potion effect.
    pub fn finishDrinking(self: *WitchEntity) void {
        if (!self.is_drinking) return;

        switch (self.drinking_potion) {
            .fire_resistance => {
                self.fire_resistance_ticks = fire_resistance_duration_ticks;
                self.is_on_fire = false; // Fire resistance immediately extinguishes flame damage
            },
            .water_breathing => {
                self.water_breathing_ticks = water_breathing_duration_ticks;
            },
            .healing => {
                self.health = @min(self.max_health, self.health + healing_i_restore_amount);
            },
            .swiftness => {
                self.swiftness_ticks = swiftness_duration_ticks;
            },
            .none => {},
        }

        self.is_drinking = false;
        self.drinking_potion = .none;
        self.drinking_ticks = 0;
        self.updateSpeed();
    }

    /// Updates current movement speed based on active status effects and drinking state.
    pub fn updateSpeed(self: *WitchEntity) void {
        if (self.is_drinking) {
            self.current_movement_speed = 0.0;
            return;
        }
        var speed = self.base_movement_speed;
        if (self.hasSwiftness()) {
            speed *= swiftness_speed_multiplier;
        }
        if (self.slowness_ticks > 0) {
            speed *= slowness_i_speed_multiplier;
        }
        self.current_movement_speed = speed;
    }

    /// Ticks active effect durations, drinking animation, and combat cooldowns.
    pub fn tickState(self: *WitchEntity) void {
        if (!self.is_alive) return;

        // Status effect timers
        if (self.fire_resistance_ticks > 0) self.fire_resistance_ticks -= 1;
        if (self.water_breathing_ticks > 0) self.water_breathing_ticks -= 1;
        if (self.swiftness_ticks > 0) self.swiftness_ticks -= 1;
        if (self.slowness_ticks > 0) self.slowness_ticks -= 1;
        if (self.regeneration_ticks > 0) {
            self.regeneration_ticks -= 1;
            if (self.regeneration_ticks % regeneration_i_interval_ticks == 0) {
                self.health = @min(self.max_health, self.health + regeneration_i_heal_per_interval);
            }
        }

        // Combat throw cooldown
        if (self.attack_cooldown_ticks > 0) {
            self.attack_cooldown_ticks -= 1;
        }

        // Drinking progression
        if (self.is_drinking) {
            self.drinking_ticks += 1;
            if (self.drinking_ticks >= witch_drinking_duration_ticks) {
                self.finishDrinking();
            }
        } else {
            self.updateSpeed();
        }
    }

    /// Full AI turn tick: evaluates defensive drinking, raid medic healing, and offensive attacks.
    pub fn updateAI(
        self: *WitchEntity,
        target: ?*TargetEntity,
        raid_allies: ?[]RaidAlly,
        weakness_roll_percent: f32,
    ) void {
        if (!self.is_alive) return;

        self.tickState();
        if (self.is_drinking) return; // Cannot act while drinking

        const dist_to_target = if (target) |t| self.position.distanceTo(t.position) else 0.0;

        // Step 1: Defensive self-drinking evaluation
        const defensive_potion = selectDefensiveDrink(
            self.is_on_fire,
            self.hasFireResistance(),
            self.in_water,
            self.hasWaterBreathing(),
            self.health,
            dist_to_target,
            self.hasSwiftness(),
        );

        if (defensive_potion != .none) {
            _ = self.startDrinking(defensive_potion);
            return;
        }

        // If attack cooldown is active, witch cannot throw potions yet
        if (self.attack_cooldown_ticks > 0) return;

        // Step 2: Village Raid Medic Behavior
        if (self.is_in_raid and raid_allies != null) {
            var wounded_indices: [16]usize = undefined;
            const wounded_count = scanWoundedRaidAllies(self.position, raid_allies.?, &wounded_indices);
            if (wounded_count > 0) {
                const cluster = computeAllyClusterCentroid(raid_allies.?, wounded_indices[0..wounded_count]);
                if (cluster) |pos| {
                    const heal_potion = selectRaidHealPotion(raid_allies.?, wounded_indices[0..wounded_count]);
                    _ = applySplashHealingToAllies(pos, raid_allies.?, heal_potion);
                    self.attack_cooldown_ticks = witch_attack_cooldown_ticks;
                    return;
                }
            }
        }

        // Step 3: Offensive Splash Potion Attacks against enemy target
        if (target) |tgt| {
            if (!tgt.is_alive) return;
            const offensive_potion = selectOffensiveSplashThrow(
                dist_to_target,
                tgt.health,
                tgt.has_slowness,
                tgt.has_poison,
                tgt.has_weakness,
                weakness_roll_percent,
            );

            if (offensive_potion) |pot| {
                tgt.applySplashEffect(pot);
                self.attack_cooldown_ticks = witch_attack_cooldown_ticks;
            }
        }
    }

    /// Generates defeat drops including normal ingredient drops and held drinking potion if killed while drinking.
    pub fn generateDefeatDrops(
        self: WitchEntity,
        looting_level: u8,
        fixed_drop_count: ?u8,
    ) WitchDefeatDrops {
        var drops = WitchDefeatDrops{};
        const max_drop = maxDropCountForLooting(looting_level);
        const count_per_item = fixed_drop_count orelse @min(1, max_drop);

        drops.addDrop(.glass_bottle, count_per_item, .none);
        drops.addDrop(.glowstone_dust, count_per_item, .none);
        drops.addDrop(.redstone_dust, count_per_item, .none);
        drops.addDrop(.gunpowder, count_per_item, .none);
        drops.addDrop(.sugar, count_per_item, .none);
        drops.addDrop(.spider_eye, count_per_item, .none);
        drops.addDrop(.stick, count_per_item, .none);

        const dropped_held = evaluateDrinkingPotionDeathDrop(self.is_drinking, self.drinking_potion);
        if (dropped_held) |potion| {
            drops.held_potion = potion;
            drops.addDrop(.potion_held, 1, potion);
        }

        return drops;
    }
};

// ============================================================================
// Unit Tests (25+ comprehensive tests)
// ============================================================================

test "01: witch entity constants match Minecraft specification" {
    try std.testing.expectEqual(@as(f32, 26.0), witch_max_health);
    try std.testing.expectEqual(@as(u32, 32), witch_drinking_duration_ticks);
    try std.testing.expectEqual(@as(f32, 1.6), witch_drinking_duration_seconds);
    try std.testing.expectEqual(@as(u32, 40), witch_attack_cooldown_ticks);
    try std.testing.expectEqual(@as(f32, 2.0), witch_attack_cooldown_seconds);
    try std.testing.expectEqual(@as(f32, 10.0), witch_throw_range_max);
    try std.testing.expectEqual(@as(f32, 0.15), witch_magic_damage_multiplier);
    try std.testing.expectEqual(@as(f32, 85.0), witch_magic_resistance_percent);
    try std.testing.expectEqual(@as(f32, 3.0), splash_potion_radius);
    try std.testing.expectEqual(@as(f32, 10.0), raid_scan_radius);
    try std.testing.expectEqual(@as(f32, 0.80), raid_wounded_health_threshold_ratio);
}

test "02: defensive drinking priority 1: fire triggers fire resistance potion" {
    // on_fire=true, healthy, near target -> drinks fire resistance
    const potion = selectDefensiveDrink(true, false, false, false, 26.0, 5.0, false);
    try std.testing.expectEqual(DrinkPotionType.fire_resistance, potion);
}

test "03: defensive drinking priority: fire takes precedence over underwater drowning" {
    // Both on fire and underwater -> fire resistance prioritized
    const potion = selectDefensiveDrink(true, false, true, false, 26.0, 5.0, false);
    try std.testing.expectEqual(DrinkPotionType.fire_resistance, potion);
}

test "04: defensive drinking priority: fire takes precedence over low health" {
    // On fire and low health (10.0 HP < 11.0 HP) -> fire resistance first to stop fatal burning
    const potion = selectDefensiveDrink(true, false, false, false, 10.0, 5.0, false);
    try std.testing.expectEqual(DrinkPotionType.fire_resistance, potion);
}

test "05: defensive drinking priority 2: underwater triggers water breathing" {
    // Not on fire, underwater=true -> water breathing
    const potion = selectDefensiveDrink(false, false, true, false, 26.0, 5.0, false);
    try std.testing.expectEqual(DrinkPotionType.water_breathing, potion);
}

test "06: defensive drinking priority: underwater takes precedence over low health" {
    // Underwater and low health -> water breathing first to avoid asphyxiation
    const potion = selectDefensiveDrink(false, false, true, false, 9.0, 5.0, false);
    try std.testing.expectEqual(DrinkPotionType.water_breathing, potion);
}

test "07: defensive drinking priority 3: low health (< 11.0 HP) triggers healing potion" {
    // Healthy environment, HP = 10.9 HP (< 11.0) -> healing
    const potion = selectDefensiveDrink(false, false, false, false, 10.9, 5.0, false);
    try std.testing.expectEqual(DrinkPotionType.healing, potion);
}

test "08: defensive drinking: health at 11.0 HP does not trigger healing" {
    // Exactly 11.0 HP -> does not trigger healing
    const potion = selectDefensiveDrink(false, false, false, false, 11.0, 5.0, false);
    try std.testing.expectEqual(DrinkPotionType.none, potion);
}

test "09: defensive drinking priority 4: far target (> 11.0m) triggers swiftness potion" {
    // Far distance 12.0m > 11.0m, healthy -> swiftness
    const potion = selectDefensiveDrink(false, false, false, false, 26.0, 12.0, false);
    try std.testing.expectEqual(DrinkPotionType.swiftness, potion);
}

test "10: defensive drinking: target at 11.0m does not trigger swiftness" {
    // Exactly 11.0m -> does not trigger swiftness
    const potion = selectDefensiveDrink(false, false, false, false, 26.0, 11.0, false);
    try std.testing.expectEqual(DrinkPotionType.none, potion);
}

test "11: defensive drinking skips active effects to proceed to next priority" {
    // On fire, but ALREADY has fire resistance -> checks next: HP is 8.0 (< 11.0) -> drinks healing!
    const potion = selectDefensiveDrink(true, true, false, false, 8.0, 5.0, false);
    try std.testing.expectEqual(DrinkPotionType.healing, potion);
}

test "12: drinking animation lasts exactly 32 ticks and pauses movement" {
    var witch = WitchEntity.init(.{});
    try std.testing.expectEqual(@as(f32, 0.25), witch.current_movement_speed);
    try std.testing.expect(!witch.is_drinking);

    // Start drinking Fire Resistance
    const started = witch.startDrinking(.fire_resistance);
    try std.testing.expect(started);
    try std.testing.expect(witch.is_drinking);
    try std.testing.expectEqual(DrinkPotionType.fire_resistance, witch.drinking_potion);
    try std.testing.expectEqual(@as(f32, 0.0), witch.current_movement_speed); // Movement paused

    // Advance 31 ticks: still drinking, still paused
    var t: u32 = 0;
    while (t < 31) : (t += 1) {
        witch.tickState();
        try std.testing.expect(witch.is_drinking);
        try std.testing.expectEqual(@as(f32, 0.0), witch.current_movement_speed);
    }
    try std.testing.expectEqual(@as(u32, 31), witch.drinking_ticks);

    // Tick 32 completes drinking!
    witch.tickState();
    try std.testing.expect(!witch.is_drinking);
    try std.testing.expectEqual(DrinkPotionType.none, witch.drinking_potion);
    try std.testing.expect(witch.hasFireResistance());
    try std.testing.expectEqual(fire_resistance_duration_ticks, witch.fire_resistance_ticks);
    try std.testing.expect(witch.current_movement_speed > 0.0); // Movement resumed
}

test "13: drinking Healing I restores +4.0 HP capped at max health" {
    var witch = WitchEntity.init(.{});
    witch.health = 10.0;
    _ = witch.startDrinking(.healing);

    var t: u32 = 0;
    while (t < 32) : (t += 1) {
        witch.tickState();
    }

    try std.testing.expectEqual(@as(f32, 14.0), witch.health);
    try std.testing.expect(!witch.is_drinking);
}

test "14: drinking Swiftness I increases movement speed by +20% for 3 minutes" {
    var witch = WitchEntity.init(.{});
    _ = witch.startDrinking(.swiftness);

    var t: u32 = 0;
    while (t < 32) : (t += 1) {
        witch.tickState();
    }

    try std.testing.expect(witch.hasSwiftness());
    try std.testing.expectEqual(swiftness_duration_ticks, witch.swiftness_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25 * 1.20), witch.current_movement_speed, 0.001);
}

test "15: offensive splash throw: target out of 10.0m range cannot be targeted" {
    const pot = selectOffensiveSplashThrow(10.1, 20.0, false, false, false, 50.0);
    try std.testing.expect(pot == null);
}

test "16: offensive splash throw priority 1: within 8.0m and not slowed throws Slowness I" {
    // Target at 7.0m, no slowness -> throws Slowness
    const pot = selectOffensiveSplashThrow(7.0, 20.0, false, false, false, 50.0);
    try std.testing.expectEqual(OffensivePotionType.slowness, pot.?);
}

test "17: offensive splash throw priority 2: target health >= 8.0 HP and not poisoned throws Poison I" {
    // Target at 7.0m already slowed, HP = 20.0, not poisoned -> throws Poison
    const pot = selectOffensiveSplashThrow(7.0, 20.0, true, false, false, 50.0);
    try std.testing.expectEqual(OffensivePotionType.poison, pot.?);
}

test "18: offensive splash throw priority 3: close combat (< 3.0m) 25% chance throws Weakness I" {
    // Target at 2.5m, already slowed & poisoned, weakness roll 10.0 (< 25.0) -> Weakness
    const pot = selectOffensiveSplashThrow(2.5, 20.0, true, true, false, 10.0);
    try std.testing.expectEqual(OffensivePotionType.weakness, pot.?);
}

test "19: offensive splash throw: close combat weakness roll failure (> 25%) falls back to Harming" {
    // Target at 2.5m, slowed & poisoned, weakness roll 35.0 (>= 25.0) -> Harming
    const pot = selectOffensiveSplashThrow(2.5, 20.0, true, true, false, 35.0);
    try std.testing.expectEqual(OffensivePotionType.harming, pot.?);
}

test "20: offensive splash throw priority 4: target health < 8.0 HP throws Harming I" {
    // Target at 5.0m, slowed and poisoned, HP = 6.0 (< 8.0) -> Harming
    const pot = selectOffensiveSplashThrow(5.0, 6.0, true, true, false, 50.0);
    try std.testing.expectEqual(OffensivePotionType.harming, pot.?);
}

test "21: offensive splash potion cooldown is 40 ticks (2.0s)" {
    var witch = WitchEntity.init(.{});
    var target = TargetEntity{ .position = .{ .x = 5.0, .y = 0.0, .z = 0.0 }, .health = 20.0 };

    witch.updateAI(&target, null, 50.0);
    // Witch throws Slowness and triggers 40-tick cooldown
    try std.testing.expect(target.has_slowness);
    try std.testing.expectEqual(witch_attack_cooldown_ticks, witch.attack_cooldown_ticks);

    // Advance 39 ticks: cooldown still active, witch cannot throw
    var t: u32 = 0;
    while (t < 39) : (t += 1) {
        witch.updateAI(&target, null, 50.0);
    }
    try std.testing.expectEqual(@as(u32, 1), witch.attack_cooldown_ticks);
    try std.testing.expect(!target.has_poison); // Has not thrown poison yet

    // Tick 40 expires cooldown, next AI turn throws Poison!
    witch.updateAI(&target, null, 50.0);
    try std.testing.expect(target.has_poison);
    try std.testing.expectEqual(witch_attack_cooldown_ticks, witch.attack_cooldown_ticks);
}

test "22: target entity status effect ticking: poison deals 1 HP / 1.25s down to 1 HP" {
    var target = TargetEntity{ .position = .{}, .health = 3.0 };
    target.applySplashEffect(.poison);
    try std.testing.expect(target.has_poison);

    // Advance 25 ticks (1.25s) -> deals 1.0 HP
    var t: u32 = 0;
    while (t < 25) : (t += 1) {
        target.tickEffects();
    }
    try std.testing.expectEqual(@as(f32, 2.0), target.health);

    // Advance another 25 ticks -> deals 1.0 HP down to 1.0 HP
    t = 0;
    while (t < 25) : (t += 1) {
        target.tickEffects();
    }
    try std.testing.expectEqual(@as(f32, 1.0), target.health);

    // Another 25 ticks -> poison cannot kill below 1.0 HP
    t = 0;
    while (t < 25) : (t += 1) {
        target.tickEffects();
    }
    try std.testing.expectEqual(@as(f32, 1.0), target.health);
    try std.testing.expect(target.is_alive);
}

test "23: 85% magic resistance mitigates incoming magic damage" {
    var witch = WitchEntity.init(.{});
    // Instant Damage / Harming deals 6.0 direct magic damage
    const taken = witch.takeDamage(6.0, .magic);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0 * 0.15), taken, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.90), taken, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 26.0 - 0.90), witch.health, 0.001);
}

test "24: witch is 100% immune to poison damage" {
    var witch = WitchEntity.init(.{});
    try std.testing.expect(isWitchPoisonImmune());
    const taken = witch.takeDamage(10.0, .poison);
    try std.testing.expectEqual(@as(f32, 0.0), taken);
    try std.testing.expectEqual(@as(f32, 26.0), witch.health);
}

test "25: village raid medic scans wounded allies within 10.0m (< 80% HP)" {
    const witch_pos = Vec3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    var allies = [_]RaidAlly{
        .{ .role = .pillager, .position = .{ .x = 4.0, .y = 0.0, .z = 0.0 }, .health = 15.0, .max_health = 24.0 }, // 15/24 = 62.5% < 80% -> wounded
        .{ .role = .vindicator, .position = .{ .x = 8.0, .y = 0.0, .z = 0.0 }, .health = 23.0, .max_health = 24.0 }, // 23/24 = 95.8% -> healthy
        .{ .role = .ravager, .position = .{ .x = 12.0, .y = 0.0, .z = 0.0 }, .health = 50.0, .max_health = 100.0 }, // 12.0m > 10.0m -> out of range
        .{ .role = .witch, .position = .{ .x = -3.0, .y = 0.0, .z = 0.0 }, .health = 18.0, .max_health = 26.0 }, // 18/26 = 69.2% < 80% -> wounded
    };

    var indices: [8]usize = undefined;
    const count = scanWoundedRaidAllies(witch_pos, &allies, &indices);
    try std.testing.expectEqual(@as(usize, 2), count);
    try std.testing.expectEqual(@as(usize, 0), indices[0]); // Pillager
    try std.testing.expectEqual(@as(usize, 3), indices[1]); // Witch
}

test "26: village raid medic computes cluster centroid of wounded allies" {
    const allies = [_]RaidAlly{
        .{ .role = .pillager, .position = .{ .x = 2.0, .y = 0.0, .z = 4.0 }, .health = 10.0, .max_health = 24.0 },
        .{ .role = .vindicator, .position = .{ .x = 6.0, .y = 0.0, .z = 8.0 }, .health = 10.0, .max_health = 24.0 },
    };
    const indices = [_]usize{ 0, 1 };
    const centroid = computeAllyClusterCentroid(&allies, &indices).?;
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), centroid.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), centroid.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), centroid.z, 0.001);
}

test "27: splash healing restores health to all allies in 3.0m splash radius" {
    var allies = [_]RaidAlly{
        .{ .role = .pillager, .position = .{ .x = 4.0, .y = 0.0, .z = 0.0 }, .health = 15.0, .max_health = 24.0 }, // 0m from cluster
        .{ .role = .vindicator, .position = .{ .x = 6.0, .y = 0.0, .z = 0.0 }, .health = 10.0, .max_health = 24.0 }, // 2m from cluster <= 3.0m
        .{ .role = .ravager, .position = .{ .x = 8.0, .y = 0.0, .z = 0.0 }, .health = 50.0, .max_health = 100.0 }, // 4m from cluster > 3.0m
    };

    const cluster_pos = Vec3{ .x = 4.0, .y = 0.0, .z = 0.0 };
    const res = applySplashHealingToAllies(cluster_pos, &allies, .healing);

    try std.testing.expectEqual(@as(u32, 2), res.allies_healed);
    try std.testing.expectEqual(@as(f32, 19.0), allies[0].health); // 15 + 4 = 19
    try std.testing.expectEqual(@as(f32, 14.0), allies[1].health); // 10 + 4 = 14
    try std.testing.expectEqual(@as(f32, 50.0), allies[2].health); // Unchanged (outside 3m)
    try std.testing.expectEqual(@as(f32, 8.0), res.total_health_restored);
}

test "28: village raid witch AI acts as medic when raid allies are wounded" {
    var witch = WitchEntity.init(.{ .x = 0.0, .y = 0.0, .z = 0.0 });
    witch.is_in_raid = true;

    var allies = [_]RaidAlly{
        .{ .role = .pillager, .position = .{ .x = 5.0, .y = 0.0, .z = 0.0 }, .health = 10.0, .max_health = 24.0 }, // Critical < 50%
    };

    witch.updateAI(null, &allies, 50.0);
    try std.testing.expectEqual(witch_attack_cooldown_ticks, witch.attack_cooldown_ticks);
    try std.testing.expectEqual(@as(f32, 14.0), allies[0].health); // Healed +4 HP
}

test "29: defeat drops: 7 standard ingredients boosted by looting level" {
    const witch = WitchEntity.init(.{});
    try std.testing.expectEqual(@as(u8, 2), maxDropCountForLooting(0));
    try std.testing.expectEqual(@as(u8, 3), maxDropCountForLooting(1));
    try std.testing.expectEqual(@as(u8, 4), maxDropCountForLooting(2));
    try std.testing.expectEqual(@as(u8, 5), maxDropCountForLooting(3));

    const drops = witch.generateDefeatDrops(2, 4);
    try std.testing.expectEqual(@as(u8, 7), drops.count);
    try std.testing.expect(drops.held_potion == null);
}

test "30: defeat drops: witch killed while drinking drops the potion being consumed" {
    var witch = WitchEntity.init(.{});
    _ = witch.startDrinking(.fire_resistance);
    try std.testing.expect(witch.is_drinking);

    // Killed while drinking
    const drops = witch.generateDefeatDrops(0, 1);
    try std.testing.expectEqual(DrinkPotionType.fire_resistance, drops.held_potion.?);
    try std.testing.expectEqual(@as(u8, 8), drops.count); // 7 standard + 1 held potion
    try std.testing.expectEqual(WitchDropItem.potion_held, drops.drops[7].item);
    try std.testing.expectEqual(DrinkPotionType.fire_resistance, drops.drops[7].potion_type);
}

test "31: defeat drops: witch killed while drinking water breathing drops water breathing" {
    var witch = WitchEntity.init(.{});
    _ = witch.startDrinking(.water_breathing);

    const drops = witch.generateDefeatDrops(3, 2);
    try std.testing.expectEqual(DrinkPotionType.water_breathing, drops.held_potion.?);
}

test "32: weakness effect reduces target attack damage by -4.0" {
    var target = TargetEntity{ .position = .{}, .base_attack_damage = 7.0, .current_attack_damage = 7.0 };
    target.applySplashEffect(.weakness);
    try std.testing.expect(target.has_weakness);
    try std.testing.expectEqual(@as(f32, 3.0), target.current_attack_damage); // 7.0 - 4.0 = 3.0
    try std.testing.expectEqual(weakness_i_duration_ticks, target.weakness_ticks);

    // After duration expires, damage restores
    var t: u32 = 0;
    while (t < weakness_i_duration_ticks) : (t += 1) {
        target.tickEffects();
    }
    try std.testing.expect(!target.has_weakness);
    try std.testing.expectEqual(@as(f32, 7.0), target.current_attack_damage);
}

test "33: slowness effect reduces target movement speed by -15%" {
    var target = TargetEntity{ .position = .{}, .base_movement_speed = 0.20, .current_movement_speed = 0.20 };
    target.applySplashEffect(.slowness);
    try std.testing.expect(target.has_slowness);
    try std.testing.expectApproxEqAbs(@as(f32, 0.20 * 0.85), target.current_movement_speed, 0.001);

    var t: u32 = 0;
    while (t < slowness_i_duration_ticks) : (t += 1) {
        target.tickEffects();
    }
    try std.testing.expect(!target.has_slowness);
    try std.testing.expectEqual(@as(f32, 0.20), target.current_movement_speed);
}

test "34: raid splash regeneration applies regeneration effect to allies within 3m" {
    var allies = [_]RaidAlly{
        .{ .role = .pillager, .position = .{ .x = 1.0, .y = 0.0, .z = 0.0 }, .health = 18.0, .max_health = 24.0 },
        .{ .role = .vindicator, .position = .{ .x = 2.0, .y = 0.0, .z = 0.0 }, .health = 19.0, .max_health = 24.0 },
    };
    const cluster = Vec3{ .x = 1.5, .y = 0.0, .z = 0.0 };
    const res = applySplashHealingToAllies(cluster, &allies, .regeneration);

    try std.testing.expectEqual(@as(u32, 2), res.allies_healed);
    try std.testing.expect(allies[0].has_regeneration);
    try std.testing.expect(allies[1].has_regeneration);
    try std.testing.expectEqual(regeneration_i_duration_ticks, allies[0].regeneration_ticks);
}

test "35: fire hazard damage is completely blocked by active fire resistance" {
    var witch = WitchEntity.init(.{});
    // Without fire resistance
    const dmg_unprotected = witch.takeDamage(4.0, .fire);
    try std.testing.expectEqual(@as(f32, 4.0), dmg_unprotected);
    try std.testing.expectEqual(@as(f32, 22.0), witch.health);

    // With fire resistance
    witch.fire_resistance_ticks = 100;
    const dmg_protected = witch.takeDamage(4.0, .fire);
    try std.testing.expectEqual(@as(f32, 0.0), dmg_protected);
    try std.testing.expectEqual(@as(f32, 22.0), witch.health);
}

test "36: drowning hazard damage is completely blocked by active water breathing" {
    var witch = WitchEntity.init(.{});
    // Without water breathing
    const dmg_unprotected = witch.takeDamage(2.0, .drowning);
    try std.testing.expectEqual(@as(f32, 2.0), dmg_unprotected);

    // With water breathing
    witch.water_breathing_ticks = 200;
    const dmg_protected = witch.takeDamage(2.0, .drowning);
    try std.testing.expectEqual(@as(f32, 0.0), dmg_protected);
}

test "37: witch cannot start drinking when already drinking" {
    var witch = WitchEntity.init(.{});
    try std.testing.expect(witch.startDrinking(.healing));
    try std.testing.expect(!witch.startDrinking(.fire_resistance)); // Blocked
    try std.testing.expectEqual(DrinkPotionType.healing, witch.drinking_potion);
}

test "38: witch cannot throw offensive potion while drinking animation is playing" {
    var witch = WitchEntity.init(.{});
    var target = TargetEntity{ .position = .{ .x = 4.0, .y = 0.0, .z = 0.0 }, .health = 20.0 };

    _ = witch.startDrinking(.swiftness);
    try std.testing.expect(witch.is_drinking);

    // Update AI during drinking
    witch.updateAI(&target, null, 50.0);
    // Still drinking, target not attacked
    try std.testing.expect(witch.is_drinking);
    try std.testing.expect(!target.has_slowness);
    try std.testing.expectEqual(@as(u32, 0), witch.attack_cooldown_ticks);
}
