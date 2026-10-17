const std = @import("std");

pub const max_health: f32 = 300.0;
pub const combat_phase_threshold: f32 = 150.0;
pub const spawn_start_health: f32 = 150.0;
pub const spawn_duration_seconds: f32 = 11.0;
pub const spawn_duration_ticks: u16 = 220;
pub const birth_explosion_radius: f32 = 7.0;
pub const black_skull_damage: f32 = 8.0;
pub const wither_ii_damage_per_second: f32 = 1.0;
pub const wither_ii_duration_seconds: f32 = 10.0;
pub const kill_heal: f32 = 5.0;
pub const blue_skull_block_break_probability: f32 = 0.001;
pub const phase2_dashes_through_blocks = true;

/// The two horizontal arm blocks must have air directly beneath them.
pub fn canSummonWitherBoss(
    center_col_soul_sand_2_high: bool,
    left_arm_soul_sand: bool,
    right_arm_soul_sand: bool,
    skulls_count: u2,
    air_under_arms: bool,
) bool {
    return center_col_soul_sand_2_high and left_arm_soul_sand and right_arm_soul_sand and
        skulls_count == 3 and air_under_arms;
}

pub const WitherBossPhase = enum {
    spawning_invulnerable,
    aerial_phase_1,
    armored_phase_2_melee,
    defeated,
};

pub const WitherSkullKind = enum { black, blue };

pub const WitherSkull = struct {
    kind: WitherSkullKind,
    explosive: bool,
    direct_damage: f32,
    wither_damage_per_second: f32,
    wither_duration_seconds: f32,
    healing_on_kill: f32,
    block_break_probability: f32,
    /// Blue skulls ignore ordinary blast resistance, allowing the rare
    /// resistance override to break reinforced blocks around obsidian.
    overrides_block_blast_resistance: bool,
};

pub fn blackWitherSkull() WitherSkull {
    return .{
        .kind = .black,
        .explosive = true,
        .direct_damage = black_skull_damage,
        .wither_damage_per_second = wither_ii_damage_per_second,
        .wither_duration_seconds = wither_ii_duration_seconds,
        .healing_on_kill = kill_heal,
        .block_break_probability = 0.0,
        .overrides_block_blast_resistance = false,
    };
}

pub fn blueWitherSkull() WitherSkull {
    return .{
        .kind = .blue,
        .explosive = true,
        .direct_damage = black_skull_damage,
        .wither_damage_per_second = wither_ii_damage_per_second,
        .wither_duration_seconds = wither_ii_duration_seconds,
        .healing_on_kill = kill_heal,
        .block_break_probability = blue_skull_block_break_probability,
        .overrides_block_blast_resistance = true,
    };
}

pub const WitherSkullVolley = struct {
    skulls: [3]WitherSkull,
};

/// Aerial shots use a three-headed volley. The occasional blue skull is
/// selected by the caller; this helper describes the three-shot black volley.
pub fn blackSkullVolley() WitherSkullVolley {
    const skull = blackWitherSkull();
    return .{ .skulls = .{ skull, skull, skull } };
}

pub fn isProjectileImmuneInPhase2(phase: WitherBossPhase) bool {
    return phase == .armored_phase_2_melee;
}

pub const Phase2Movement = struct {
    target_ground_height: f32,
    dashes_through_blocks: bool,
};

/// In the armored phase, the Wither descends to its target's ground height and
/// can dash through intervening blocks.
pub fn phase2Movement(target_ground_height: f32) Phase2Movement {
    return .{
        .target_ground_height = target_ground_height,
        .dashes_through_blocks = phase2_dashes_through_blocks,
    };
}

pub fn phaseForHealth(health: f32) WitherBossPhase {
    if (health <= 0.0) return .defeated;
    return if (health <= combat_phase_threshold) .armored_phase_2_melee else .aerial_phase_1;
}

pub const WitherBoss = struct {
    phase: WitherBossPhase = .spawning_invulnerable,
    health: f32 = spawn_start_health,
    spawn_ticks: u16 = 0,
    birth_explosion_radius: f32 = 0.0,

    pub fn isInvulnerable(self: WitherBoss) bool {
        return self.phase == .spawning_invulnerable;
    }

    /// Advance the charge by one 20 Hz tick. Returns true exactly when the
    /// fully charged boss creates its birth explosion.
    pub fn advanceSpawnTick(self: *WitherBoss) bool {
        if (self.phase != .spawning_invulnerable) return false;
        if (self.spawn_ticks < spawn_duration_ticks) self.spawn_ticks += 1;
        const progress: f32 = @as(f32, @floatFromInt(self.spawn_ticks)) / @as(f32, @floatFromInt(spawn_duration_ticks));
        self.health = spawn_start_health + (max_health - spawn_start_health) * progress;
        if (self.spawn_ticks == spawn_duration_ticks) {
            self.birth_explosion_radius = @as(f32, 7.0);
            self.phase = .aerial_phase_1;
            return true;
        }
        return false;
    }

    pub fn applyDamage(self: *WitherBoss, amount: f32) bool {
        if (self.phase == .spawning_invulnerable or self.phase == .defeated or amount <= 0.0) return false;
        self.health = @max(0.0, self.health - amount);
        self.phase = phaseForHealth(self.health);
        return true;
    }

    pub fn healOnKill(self: *WitherBoss) void {
        if (self.phase != .defeated) self.health = @min(max_health, self.health + kill_heal);
    }

    pub fn onMobKilled(self: WitherBoss) WitherRoseEvent {
        _ = self;
        return .{ .plant_wither_rose = true };
    }
};

pub const WitherRoseEvent = struct { plant_wither_rose: bool };

pub const WitherBossDrops = struct {
    dropped_nether_star: u8,
    wither_roses_planted: u8,
};

pub fn onWitherBossDefeated() WitherBossDrops {
    return .{ .dropped_nether_star = 1, .wither_roses_planted = 0 };
}

pub const nether_star_unbreakable_by_explosions = true;

test "summon accepts a complete T-frame with three skulls and clear arm undersides" {
    try std.testing.expect(canSummonWitherBoss(true, true, true, 3, true));
}

test "summon rejects missing two-high center column" {
    try std.testing.expect(!canSummonWitherBoss(false, true, true, 3, true));
}

test "summon rejects missing left arm" {
    try std.testing.expect(!canSummonWitherBoss(true, false, true, 3, true));
}

test "summon rejects missing right arm" {
    try std.testing.expect(!canSummonWitherBoss(true, true, false, 3, true));
}

test "summon requires exactly three skulls" {
    try std.testing.expect(!canSummonWitherBoss(true, true, true, 2, true));
    try std.testing.expect(!canSummonWitherBoss(true, true, true, 1, true));
    try std.testing.expect(!canSummonWitherBoss(true, true, true, 0, true));
}

test "summon rejects blocked space beneath arms" {
    try std.testing.expect(!canSummonWitherBoss(true, true, true, 3, false));
}

test "new boss begins invulnerable at 150 health" {
    const boss = WitherBoss{};
    try std.testing.expectEqual(WitherBossPhase.spawning_invulnerable, boss.phase);
    try std.testing.expect(boss.isInvulnerable());
    try std.testing.expectApproxEqAbs(spawn_start_health, boss.health, 0.001);
}

test "spawn charge fills health gradually but remains invulnerable" {
    var boss = WitherBoss{};
    var tick: u16 = 0;
    while (tick < 110) : (tick += 1) _ = boss.advanceSpawnTick();
    try std.testing.expectApproxEqAbs(@as(f32, 225.0), boss.health, 0.001);
    try std.testing.expect(boss.isInvulnerable());
    try std.testing.expectEqual(@as(f32, 0.0), boss.birth_explosion_radius);
}

test "spawn charge completes at 11 seconds or 220 ticks with a radius 7 explosion" {
    var boss = WitherBoss{};
    var exploded = false;
    var tick: u16 = 0;
    while (tick < spawn_duration_ticks) : (tick += 1) exploded = boss.advanceSpawnTick();
    try std.testing.expect(exploded);
    try std.testing.expectEqual(@as(u16, 220), boss.spawn_ticks);
    try std.testing.expectEqual(WitherBossPhase.aerial_phase_1, boss.phase);
    try std.testing.expectApproxEqAbs(max_health, boss.health, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), boss.birth_explosion_radius, 0.001);
}

test "black skull has explosive damage, wither II and kill healing but no resistance override" {
    const skull = blackWitherSkull();
    try std.testing.expectEqual(WitherSkullKind.black, skull.kind);
    try std.testing.expect(skull.explosive);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), skull.direct_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), skull.wither_damage_per_second, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), skull.wither_duration_seconds, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), skull.healing_on_kill, 0.001);
    try std.testing.expect(!skull.overrides_block_blast_resistance);
}

test "blue skull carries the rare 0.1 percent block resistance override" {
    const skull = blueWitherSkull();
    try std.testing.expectEqual(WitherSkullKind.blue, skull.kind);
    try std.testing.expect(skull.explosive);
    try std.testing.expectApproxEqAbs(@as(f32, 0.001), skull.block_break_probability, 0.000001);
    try std.testing.expect(skull.overrides_block_blast_resistance);
}

test "black aerial volley has three heads" {
    const volley = blackSkullVolley();
    for (volley.skulls) |skull| try std.testing.expectEqual(WitherSkullKind.black, skull.kind);
}

test "phase 2 begins at exactly 150 health and grants projectile immunity" {
    try std.testing.expectEqual(WitherBossPhase.aerial_phase_1, phaseForHealth(150.01));
    try std.testing.expectEqual(WitherBossPhase.armored_phase_2_melee, phaseForHealth(150.0));
    try std.testing.expect(!isProjectileImmuneInPhase2(.aerial_phase_1));
    try std.testing.expect(isProjectileImmuneInPhase2(.armored_phase_2_melee));
}

test "phase 2 movement descends to target and dashes through blocks" {
    const movement = phase2Movement(64.5);
    try std.testing.expectEqual(@as(f32, 64.5), movement.target_ground_height);
    try std.testing.expect(movement.dashes_through_blocks);
}

test "damage is ignored during birth charge and phase updates at threshold" {
    var boss = WitherBoss{};
    try std.testing.expect(!boss.applyDamage(200.0));
    try std.testing.expectEqual(spawn_start_health, boss.health);
    boss.phase = .aerial_phase_1;
    boss.health = 155.0;
    try std.testing.expect(boss.applyDamage(5.0));
    try std.testing.expectEqual(WitherBossPhase.armored_phase_2_melee, boss.phase);
}

test "phase two killing blow defeats the boss" {
    var boss = WitherBoss{ .phase = .armored_phase_2_melee, .health = 10.0 };
    try std.testing.expect(boss.applyDamage(10.0));
    try std.testing.expectEqual(WitherBossPhase.defeated, boss.phase);
    try std.testing.expect(!isProjectileImmuneInPhase2(boss.phase));
}

test "Wither kills plant roses" {
    const boss = WitherBoss{};
    try std.testing.expect(boss.onMobKilled().plant_wither_rose);
}

test "defeat drops exactly one explosion-proof Nether Star" {
    const drops = onWitherBossDefeated();
    try std.testing.expectEqual(@as(u8, 1), drops.dropped_nether_star);
    try std.testing.expect(nether_star_unbreakable_by_explosions);
}

test "boss heals five health on kill up to its maximum" {
    var boss = WitherBoss{ .phase = .aerial_phase_1, .health = 100.0 };
    boss.healOnKill();
    try std.testing.expectEqual(@as(f32, 105.0), boss.health);
    boss.health = max_health - 2.0;
    boss.healOnKill();
    try std.testing.expectEqual(max_health, boss.health);
}
