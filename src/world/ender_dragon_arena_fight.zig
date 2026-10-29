const std = @import("std");
const BlockId = @import("block.zig").BlockId;

pub const MAX_HEALTH: f32 = 200.0;
pub const CRYSTAL_COUNT: usize = 10;
pub const PILLAR_RING_RADIUS: f32 = 42.0;
pub const CIRCLING_RADIUS: f32 = 45.0;
pub const CRYSTAL_BEAM_RANGE: f32 = 32.0;
pub const CRYSTAL_HEAL_PER_TICK: f32 = 1.0;
pub const CRYSTAL_EXPLOSION_POWER: f32 = 6.0;
pub const CRYSTAL_BACKLASH_DAMAGE: f32 = 10.0;
pub const FIREBALL_DIRECT_DAMAGE: f32 = 6.0;
pub const DRAGON_BREATH_RADIUS: f32 = 3.5;
pub const PERCHED_BREATH_DAMAGE_PER_SECOND: f32 = 3.0;
pub const CHARGE_SPEED: f32 = 10.0;
pub const CHARGE_DAMAGE: f32 = 10.0;
pub const DEATH_ANIMATION_TICKS: u16 = 200;
pub const DEFEAT_XP: u32 = 12_000;
pub const TICKS_PER_SECOND: f32 = 20.0;
// The generated End terrain's existing fountain base is at world Y=8.
pub const PORTAL_Y: i32 = 8;

pub const Vec3 = [3]f32;
/// Inventory's dragon egg ItemType id, duplicated to keep standalone module imports local.
pub const DragonEggItemType = enum(u16) { dragon_egg = 152 };

pub const Phase = enum { circling, strafing, perching, charging, dying, defeated };
pub const BossBarColor = enum { purple };
pub const BossBarStyle = enum { segmented_10 };

pub const BossBar = struct {
    name: []const u8 = "Ender Dragon",
    health_ratio: f32,
    color: BossBarColor = .purple,
    style: BossBarStyle = .segmented_10,
};

pub const Dragon = struct {
    pos: Vec3 = .{ CIRCLING_RADIUS, 78.0, 0.0 },
    velocity: Vec3 = .{ 0.0, 0.0, 0.0 },
    forward: Vec3 = .{ -1.0, 0.0, 0.0 },
    health: f32 = MAX_HEALTH,
    phase: Phase = .circling,
    phase_ticks: u16 = 0,
    perch_duration_ticks: u16 = 300,
    death_ticks: u16 = 0,
    reward_emitted: bool = false,
    portal_activated: bool = false,
    charge_hit_registered: bool = false,

    pub fn bossBar(self: Dragon) BossBar {
        return .{ .health_ratio = std.math.clamp(self.health / MAX_HEALTH, 0.0, 1.0) };
    }

    pub fn applyDamage(self: *Dragon, amount: f32) f32 {
        if (self.phase == .dying or self.phase == .defeated or amount <= 0.0) return 0.0;
        const before = self.health;
        self.health = @max(0.0, self.health - amount);
        if (self.health == 0.0) {
            self.phase = .dying;
            self.phase_ticks = 0;
            self.death_ticks = 0;
            self.velocity = .{ 0.0, 0.0, 0.0 };
        }
        return before - self.health;
    }

    /// Advances one 20 Hz combat tick and returns combat/world events for the caller.
    pub fn tick(self: *Dragon, target: Vec3) TickEvents {
        var events = TickEvents{};
        if (self.phase == .dying or self.phase == .defeated) {
            if (self.phase == .dying) {
                self.death_ticks += 1;
                self.pos[1] += 0.05;
                events.death_beams = true;
                events.death_beam_intensity = @min(1.0, @as(f32, @floatFromInt(self.death_ticks)) / @as(f32, @floatFromInt(DEATH_ANIMATION_TICKS)));
                if (self.death_ticks == DEATH_ANIMATION_TICKS) {
                    self.phase = .defeated;
                    events.explosion_burst = true;
                    events.xp_drop = DEFEAT_XP;
                    events.activate_exit_portal = true;
                    events.generate_dragon_egg = true;
                    self.portal_activated = true;
                    self.reward_emitted = true;
                }
            }
            return events;
        }

        self.phase_ticks +|= 1;
        switch (self.phase) {
            .circling => {
                const angle = @as(f32, @floatFromInt(self.phase_ticks)) * 0.02;
                self.pos = .{ @cos(angle) * CIRCLING_RADIUS, 77.5 + @sin(angle * 0.7) * 7.5, @sin(angle) * CIRCLING_RADIUS };
                self.forward = normalize(.{ -@sin(angle), 0.0, @cos(angle) });
                if (self.phase_ticks >= 100) self.setPhase(.strafing);
            },
            .strafing => {
                self.moveToward(target, 0.8);
                if (self.phase_ticks == 1) events.launch_fireball = true;
                if (self.phase_ticks >= 80) {
                    self.pos = .{ 0.0, 76.0, 0.0 };
                    self.setPhase(.perching);
                }
            },
            .perching => {
                self.pos = .{ 0.0, 67.0, 0.0 };
                events.perched_breath_active = true;
                if (self.phase_ticks >= self.perch_duration_ticks) self.setPhase(.charging);
            },
            .charging => {
                self.forward = normalize(sub(target, self.pos));
                self.velocity = scale(self.forward, CHARGE_SPEED / TICKS_PER_SECOND);
                self.pos = add(self.pos, self.velocity);
                if (!self.charge_hit_registered and distance(self.pos, target) <= 2.5) {
                    events.charge_hit = true;
                    self.charge_hit_registered = true;
                    events.target_damage = CHARGE_DAMAGE;
                    events.knockback = .{ self.forward[0] * 8.0, 12.0, self.forward[2] * 8.0 };
                }
                if (self.phase_ticks >= 40) self.setPhase(.circling);
            },
            .dying, .defeated => unreachable,
        }
        return events;
    }

    fn setPhase(self: *Dragon, phase: Phase) void {
        self.phase = phase;
        self.phase_ticks = 0;
        if (phase == .charging) self.charge_hit_registered = false;
    }

    fn moveToward(self: *Dragon, target: Vec3, amount: f32) void {
        self.forward = normalize(sub(target, self.pos));
        self.pos = add(self.pos, scale(self.forward, amount));
    }
};

pub const TickEvents = struct {
    launch_fireball: bool = false,
    perched_breath_active: bool = false,
    charge_hit: bool = false,
    target_damage: f32 = 0.0,
    knockback: Vec3 = .{ 0.0, 0.0, 0.0 },
    death_beams: bool = false,
    death_beam_palette: DeathBeamPalette = .white_magenta,
    death_beam_intensity: f32 = 0.0,
    explosion_burst: bool = false,
    xp_drop: u32 = 0,
    activate_exit_portal: bool = false,
    generate_dragon_egg: bool = false,
};

pub const DeathBeamPalette = enum { white_magenta };

pub const Crystal = struct {
    pos: Vec3,
    intact: bool = true,
};

pub fn generateArenaCrystals() [CRYSTAL_COUNT]Crystal {
    var crystals: [CRYSTAL_COUNT]Crystal = undefined;
    for (0..CRYSTAL_COUNT) |i| {
        const angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(CRYSTAL_COUNT));
        crystals[i] = .{ .pos = .{ @cos(angle) * PILLAR_RING_RADIUS, 82.0, @sin(angle) * PILLAR_RING_RADIUS } };
    }
    return crystals;
}

pub const CrystalTick = struct { healed: f32, beam_active: bool, crystal_index: ?usize };

/// Applies exactly one tick of healing from the closest intact crystal in range.
pub fn applyCrystalHealing(dragon: *Dragon, crystals: [CRYSTAL_COUNT]Crystal) CrystalTick {
    var nearest: ?usize = null;
    var nearest_distance = CRYSTAL_BEAM_RANGE;
    for (crystals, 0..) |crystal, i| {
        if (!crystal.intact) continue;
        const d = distance(dragon.pos, crystal.pos);
        if (d <= nearest_distance) {
            nearest = i;
            nearest_distance = d;
        }
    }
    if (nearest == null or dragon.health <= 0.0 or dragon.phase == .dying or dragon.phase == .defeated) return .{ .healed = 0.0, .beam_active = false, .crystal_index = null };
    const before = dragon.health;
    dragon.health = @min(MAX_HEALTH, dragon.health + CRYSTAL_HEAL_PER_TICK);
    return .{ .healed = dragon.health - before, .beam_active = true, .crystal_index = nearest };
}

pub const CrystalDestruction = struct { destroyed: bool, explosion_power: f32, dragon_backlash: f32 };

/// An intact crystal always explodes when destroyed; backlash occurs only while it tethers this dragon.
pub fn shatterCrystal(dragon: *Dragon, crystal: *Crystal) CrystalDestruction {
    if (!crystal.intact) return .{ .destroyed = false, .explosion_power = 0.0, .dragon_backlash = 0.0 };
    const tethering = distance(dragon.pos, crystal.pos) <= CRYSTAL_BEAM_RANGE and dragon.phase != .dying and dragon.phase != .defeated;
    crystal.intact = false;
    const backlash = if (tethering) dragon.applyDamage(CRYSTAL_BACKLASH_DAMAGE) else 0.0;
    return .{ .destroyed = true, .explosion_power = CRYSTAL_EXPLOSION_POWER, .dragon_backlash = backlash };
}

pub const AttackKind = enum { arrow, melee, other_projectile };

pub fn damageFromAttack(dragon: *Dragon, kind: AttackKind, amount: f32) f32 {
    if (dragon.phase == .perching and kind != .melee) return 0.0;
    return dragon.applyDamage(amount);
}

pub const Fireball = struct {
    pos: Vec3,
    velocity: Vec3,
    active: bool = true,

    pub fn launch(pos: Vec3, target: Vec3, speed: f32) Fireball {
        return .{ .pos = pos, .velocity = scale(normalize(sub(target, pos)), speed) };
    }

    pub fn tick(self: *Fireball, dt: f32) void {
        if (!self.active) return;
        self.pos = add(self.pos, scale(self.velocity, @max(0.0, dt)));
    }

    pub fn impact(self: *Fireball, target_is_player: bool) ?FireballImpact {
        if (!self.active) return null;
        self.active = false;
        return .{ .direct_damage = if (target_is_player) FIREBALL_DIRECT_DAMAGE else 0.0, .breath_cloud = .{ .pos = self.pos } };
    }
};

pub const FireballImpact = struct { direct_damage: f32, breath_cloud: BreathCloud };

pub const BreathCloud = struct {
    pos: Vec3,
    radius: f32 = DRAGON_BREATH_RADIUS,
    remaining_ticks: u16 = 600,
    active: bool = true,

    pub fn tick(self: *BreathCloud) void {
        if (!self.active) return;
        if (self.remaining_ticks > 0) self.remaining_ticks -= 1;
        if (self.remaining_ticks == 0) self.active = false;
    }
};

pub const BreathConeHit = struct { hit: bool, damage: f32 };

/// The frontal cone has a 60 degree full angle and a 16m reach.
pub fn perchedBreathHit(dragon: Dragon, target: Vec3, dt: f32) BreathConeHit {
    if (dragon.phase != .perching or dt <= 0.0) return .{ .hit = false, .damage = 0.0 };
    const toward = sub(target, dragon.pos);
    const d = length(toward);
    if (d > 16.0 or d == 0.0) return .{ .hit = false, .damage = 0.0 };
    const cosine = dot(normalize(toward), normalize(dragon.forward));
    if (cosine < @cos(std.math.pi / 6.0)) return .{ .hit = false, .damage = 0.0 };
    return .{ .hit = true, .damage = PERCHED_BREATH_DAMAGE_PER_SECOND * dt };
}

pub const PortalActivation = struct {
    active: bool,
    portal_blocks: [9]BlockId,
    egg_block: BlockId,
    egg_item: DragonEggItemType,
    egg_pos: [3]i32,
};

pub fn activateExitPortal() PortalActivation {
    return .{
        .active = true,
        .portal_blocks = .{ .end_portal, .end_portal, .end_portal, .end_portal, .end_portal, .end_portal, .end_portal, .end_portal, .end_portal },
        .egg_block = .dragon_egg,
        .egg_item = .dragon_egg,
        .egg_pos = .{ 0, PORTAL_Y + 2, 0 },
    };
}

pub fn updateArena(fight: *DragonArenaFight, target: Vec3) ArenaEvents {
    const events = fight.dragon.tick(target);
    var result = ArenaEvents{ .dragon = events };
    if (events.activate_exit_portal and !fight.exit_portal.active) {
        fight.exit_portal = activateExitPortal();
        result.portal = fight.exit_portal;
    }
    return result;
}

pub const ArenaEvents = struct { dragon: TickEvents, portal: ?PortalActivation = null };

pub const DragonArenaFight = struct {
    dragon: Dragon = .{},
    crystals: [CRYSTAL_COUNT]Crystal = generateArenaCrystals(),
    exit_portal: PortalActivation = .{ .active = false, .portal_blocks = .{ .air, .air, .air, .air, .air, .air, .air, .air, .air }, .egg_block = .air, .egg_item = .dragon_egg, .egg_pos = .{ 0, 0, 0 } },

    pub fn healFromNearbyCrystal(self: *DragonArenaFight) CrystalTick {
        return applyCrystalHealing(&self.dragon, self.crystals);
    }

    pub fn destroyArenaCrystal(self: *DragonArenaFight, crystal_index: usize) CrystalDestruction {
        if (crystal_index >= CRYSTAL_COUNT) return .{ .destroyed = false, .explosion_power = 0.0, .dragon_backlash = 0.0 };
        return shatterCrystal(&self.dragon, &self.crystals[crystal_index]);
    }
};

fn add(a: Vec3, b: Vec3) Vec3 { return .{ a[0] + b[0], a[1] + b[1], a[2] + b[2] }; }
fn sub(a: Vec3, b: Vec3) Vec3 { return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] }; }
fn scale(a: Vec3, amount: f32) Vec3 { return .{ a[0] * amount, a[1] * amount, a[2] * amount }; }
fn dot(a: Vec3, b: Vec3) f32 { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
fn length(a: Vec3) f32 { return @sqrt(dot(a, a)); }
fn distance(a: Vec3, b: Vec3) f32 { return length(sub(a, b)); }
fn normalize(a: Vec3) Vec3 { const d = length(a); return if (d == 0.0) .{ 0.0, 0.0, 0.0 } else scale(a, 1.0 / d); }

test "dragon starts with 200 HP and a full purple segmented boss bar" {
    const dragon = Dragon{};
    const bar = dragon.bossBar();
    try std.testing.expectEqual(MAX_HEALTH, dragon.health);
    try std.testing.expectEqualStrings("Ender Dragon", bar.name);
    try std.testing.expectEqual(@as(f32, 1.0), bar.health_ratio);
    try std.testing.expectEqual(BossBarColor.purple, bar.color);
    try std.testing.expectEqual(BossBarStyle.segmented_10, bar.style);
}

test "boss bar ratio tracks health and clamps to zero" { var d = Dragon{}; _ = d.applyDamage(50); try std.testing.expectEqual(@as(f32, 0.75), d.bossBar().health_ratio); _ = d.applyDamage(500); try std.testing.expectEqual(@as(f32, 0.0), d.bossBar().health_ratio); }
test "dragon begins circling at the arena ring altitude" { const d = Dragon{}; try std.testing.expectEqual(Phase.circling, d.phase); try std.testing.expectApproxEqAbs(CIRCLING_RADIUS, length(.{ d.pos[0], 0, d.pos[2] }), 0.001); try std.testing.expect(d.pos[1] >= 70 and d.pos[1] <= 85); }
test "circling phase transitions to strafing at 100 ticks" { var d = Dragon{ .phase_ticks = 99 }; _ = d.tick(.{ 0, 64, 0 }); try std.testing.expectEqual(Phase.strafing, d.phase); }
test "strafing emits a fireball launch event" { var d = Dragon{ .phase = .strafing }; const event = d.tick(.{ 0, 64, 0 }); try std.testing.expect(event.launch_fireball); }
test "strafing phase transitions to perch after 80 ticks" { var d = Dragon{ .phase = .strafing, .phase_ticks = 79 }; _ = d.tick(.{ 0, 64, 0 }); try std.testing.expectEqual(Phase.perching, d.phase); }
test "perching duration is inside the 200 to 400 tick range" { const d = Dragon{}; try std.testing.expect(d.perch_duration_ticks >= 200 and d.perch_duration_ticks <= 400); }
test "perching phase transitions to charging after selected duration" { var d = Dragon{ .phase = .perching, .phase_ticks = 299, .perch_duration_ticks = 300 }; _ = d.tick(.{ 0, 64, 0 }); try std.testing.expectEqual(Phase.charging, d.phase); }
test "charging transitions back to circling" { var d = Dragon{ .phase = .charging, .phase_ticks = 39 }; _ = d.tick(.{ 40, 64, 0 }); try std.testing.expectEqual(Phase.circling, d.phase); }
test "combat phases cycle in required order" { var d = Dragon{ .phase_ticks = 99 }; _ = d.tick(.{ 30, 64, 0 }); try std.testing.expectEqual(Phase.strafing, d.phase); d.phase_ticks = 79; _ = d.tick(.{ 30, 64, 0 }); try std.testing.expectEqual(Phase.perching, d.phase); d.phase_ticks = 299; _ = d.tick(.{ 30, 64, 0 }); try std.testing.expectEqual(Phase.charging, d.phase); }
test "arena creates ten crystals on a 42m radius ring" { const c = generateArenaCrystals(); try std.testing.expectEqual(@as(usize, 10), c.len); for (c) |v| try std.testing.expectApproxEqAbs(PILLAR_RING_RADIUS, length(.{ v.pos[0], 0, v.pos[2] }), 0.001); }
test "crystal positions use distinct evenly spaced angles" { const c = generateArenaCrystals(); try std.testing.expect(c[0].pos[0] > 41); try std.testing.expect(@abs(c[0].pos[2] - c[5].pos[2]) < 0.001); try std.testing.expect(c[0].intact); }
test "crystal at 32m heals exactly one HP in one tick" { var d = Dragon{ .pos = .{ 0, 82, 0 }, .health = 100 }; var c = generateArenaCrystals(); c[0] = .{ .pos = .{ 32, 82, 0 } }; const r = applyCrystalHealing(&d, c); try std.testing.expectEqual(@as(f32, 1.0), r.healed); try std.testing.expectEqual(@as(f32, 101), d.health); try std.testing.expect(r.beam_active); }
test "crystal healing selects closest tether" { var d = Dragon{ .pos = .{ 0, 82, 0 }, .health = 100 }; var c = generateArenaCrystals(); c[0] = .{ .pos = .{ 10, 82, 0 } }; c[1] = .{ .pos = .{ 2, 82, 0 } }; try std.testing.expectEqual(@as(?usize, 1), applyCrystalHealing(&d, c).crystal_index); }
test "crystal at 32.01m does not heal" { var d = Dragon{ .pos = .{ 0, 82, 0 }, .health = 100 }; var c = generateArenaCrystals(); c[0] = .{ .pos = .{ 32.01, 82, 0 } }; const r = applyCrystalHealing(&d, c); try std.testing.expect(!r.beam_active); try std.testing.expectEqual(@as(f32, 100), d.health); }
test "destroyed crystal no longer heals dragon" { var d = Dragon{ .pos = .{ 0, 82, 0 }, .health = 100 }; var c = generateArenaCrystals(); c[0] = .{ .pos = .{ 1, 82, 0 } }; _ = shatterCrystal(&d, &c[0]); const r = applyCrystalHealing(&d, c); try std.testing.expectEqual(@as(f32, 0), r.healed); }
test "healing does not exceed 200 HP" { var d = Dragon{ .pos = .{ 0, 82, 0 }, .health = 200 }; var c = generateArenaCrystals(); c[0] = .{ .pos = .{ 1, 82, 0 } }; try std.testing.expectEqual(@as(f32, 0), applyCrystalHealing(&d, c).healed); }
test "tethered crystal destruction has power six and ten backlash" { var d = Dragon{ .pos = .{ 0, 82, 0 }, .health = 150 }; var c = Crystal{ .pos = .{ 5, 82, 0 } }; const r = shatterCrystal(&d, &c); try std.testing.expect(r.destroyed); try std.testing.expectEqual(CRYSTAL_EXPLOSION_POWER, r.explosion_power); try std.testing.expectEqual(CRYSTAL_BACKLASH_DAMAGE, r.dragon_backlash); try std.testing.expectEqual(@as(f32, 140), d.health); }
test "untethered crystal destruction has no dragon backlash" { var d = Dragon{ .pos = .{ 100, 82, 0 }, .health = 150 }; var c = Crystal{ .pos = .{ 0, 82, 0 } }; const r = shatterCrystal(&d, &c); try std.testing.expect(r.destroyed); try std.testing.expectEqual(@as(f32, 0), r.dragon_backlash); }
test "destroying an already destroyed crystal has no second explosion" { var d = Dragon{}; var c = Crystal{ .pos = .{ 0, 0, 0 }, .intact = false }; const r = shatterCrystal(&d, &c); try std.testing.expect(!r.destroyed); try std.testing.expectEqual(@as(f32, 0), r.explosion_power); }
test "perched arrows and projectiles deal zero damage" { var d = Dragon{ .phase = .perching }; try std.testing.expectEqual(@as(f32, 0), damageFromAttack(&d, .arrow, 30)); try std.testing.expectEqual(@as(f32, 0), damageFromAttack(&d, .other_projectile, 30)); try std.testing.expectEqual(MAX_HEALTH, d.health); }
test "perched dragon remains vulnerable to melee" { var d = Dragon{ .phase = .perching }; try std.testing.expectEqual(@as(f32, 7), damageFromAttack(&d, .melee, 7)); try std.testing.expectEqual(@as(f32, 193), d.health); }
test "dragon accepts ranged damage while airborne" { var d = Dragon{ .phase = .circling }; try std.testing.expectEqual(@as(f32, 6), damageFromAttack(&d, .arrow, 6)); }
test "fireball launch points toward target and advances in flight" { var f = Fireball.launch(.{ 0, 0, 0 }, .{ 10, 0, 0 }, 12); f.tick(0.5); try std.testing.expectApproxEqAbs(@as(f32, 6), f.pos[0], 0.001); try std.testing.expectApproxEqAbs(@as(f32, 0), f.pos[2], 0.001); }
test "fireball impact creates 3.5m lingering breath cloud" { var f = Fireball.launch(.{ 0, 0, 0 }, .{ 1, 0, 0 }, 10); const impact = f.impact(false).?; try std.testing.expectEqual(DRAGON_BREATH_RADIUS, impact.breath_cloud.radius); try std.testing.expect(impact.breath_cloud.active); }
test "fireball direct player hit deals six damage and leaves breath cloud" { var f = Fireball.launch(.{ 0, 0, 0 }, .{ 1, 0, 0 }, 10); const impact = f.impact(true).?; try std.testing.expectEqual(FIREBALL_DIRECT_DAMAGE, impact.direct_damage); try std.testing.expect(impact.breath_cloud.active); }
test "fireball can only impact once" { var f = Fireball.launch(.{ 0, 0, 0 }, .{ 1, 0, 0 }, 10); _ = f.impact(false); try std.testing.expect(f.impact(false) == null); }
test "breath cloud remains active for its linger duration" { var c = BreathCloud{ .pos = .{ 0, 0, 0 }, .remaining_ticks = 2 }; c.tick(); try std.testing.expect(c.active); c.tick(); try std.testing.expect(!c.active); }
test "perched cone damages a target in front at three HP per second" { const d = Dragon{ .phase = .perching, .pos = .{ 0, 0, 0 }, .forward = .{ 1, 0, 0 } }; const hit = perchedBreathHit(d, .{ 10, 0, 0 }, 1); try std.testing.expect(hit.hit); try std.testing.expectEqual(@as(f32, 3), hit.damage); }
test "perched cone scales damage by elapsed time" { const d = Dragon{ .phase = .perching, .pos = .{ 0, 0, 0 }, .forward = .{ 1, 0, 0 } }; try std.testing.expectApproxEqAbs(@as(f32, 0.75), perchedBreathHit(d, .{ 5, 0, 0 }, 0.25).damage, 0.0001); }
test "perched cone rejects a target outside its 60 degree arc" { const d = Dragon{ .phase = .perching, .pos = .{ 0, 0, 0 }, .forward = .{ 1, 0, 0 } }; try std.testing.expect(!perchedBreathHit(d, .{ 0, 0, 5 }, 1).hit); }
test "perched cone rejects targets past its reach" { const d = Dragon{ .phase = .perching, .pos = .{ 0, 0, 0 }, .forward = .{ 1, 0, 0 } }; try std.testing.expect(!perchedBreathHit(d, .{ 17, 0, 0 }, 1).hit); }
test "breath cone is disabled outside perch phase" { const d = Dragon{ .phase = .circling, .pos = .{ 0, 0, 0 }, .forward = .{ 1, 0, 0 } }; try std.testing.expect(!perchedBreathHit(d, .{ 1, 0, 0 }, 1).hit); }
test "charge moves at ten meters per second and applies hit knockback" { var d = Dragon{ .phase = .charging, .pos = .{ 0, 0, 0 }, .phase_ticks = 10 }; const event = d.tick(.{ 1, 0, 0 }); try std.testing.expect(event.charge_hit); try std.testing.expectEqual(CHARGE_DAMAGE, event.target_damage); try std.testing.expectEqual(@as(f32, 0.5), d.pos[0]); try std.testing.expect(event.knockback[1] > 0 and event.knockback[0] > 0); }
test "charge velocity magnitude is ten meters per second" { var d = Dragon{ .phase = .charging }; _ = d.tick(.{ 100, 0, 0 }); try std.testing.expectApproxEqAbs(CHARGE_SPEED / TICKS_PER_SECOND, length(d.velocity), 0.001); }
test "one charge deals damage at most once before next charge" { var d = Dragon{ .phase = .charging, .pos = .{ 0, 0, 0 } }; try std.testing.expect(d.tick(.{ 1, 0, 0 }).charge_hit); try std.testing.expect(!d.tick(.{ 1, 0, 0 }).charge_hit); }
test "negative damage does not heal dragon" { var d = Dragon{ .health = 100 }; try std.testing.expectEqual(@as(f32, 0), d.applyDamage(-3)); try std.testing.expectEqual(@as(f32, 100), d.health); }
test "lethal damage starts death animation and prevents further damage" { var d = Dragon{ .health = 4 }; try std.testing.expectEqual(@as(f32, 4), d.applyDamage(8)); try std.testing.expectEqual(Phase.dying, d.phase); try std.testing.expectEqual(@as(f32, 0), d.applyDamage(10)); }
test "death animation lasts 200 ticks before XP and portal event" { var d = Dragon{ .phase = .dying, .health = 0 }; for (0..199) |_| { const e = d.tick(.{ 0, 0, 0 }); try std.testing.expectEqual(@as(u32, 0), e.xp_drop); } try std.testing.expectEqual(Phase.dying, d.phase); const e = d.tick(.{ 0, 0, 0 }); try std.testing.expectEqual(Phase.defeated, d.phase); try std.testing.expectEqual(DEFEAT_XP, e.xp_drop); try std.testing.expect(e.explosion_burst and e.activate_exit_portal and e.generate_dragon_egg); }
test "death ascent emits radiant white and magenta beams with rising intensity" { var d = Dragon{ .phase = .dying, .health = 0 }; const e1 = d.tick(.{ 0, 0, 0 }); const e2 = d.tick(.{ 0, 0, 0 }); try std.testing.expect(e1.death_beams); try std.testing.expectEqual(DeathBeamPalette.white_magenta, e1.death_beam_palette); try std.testing.expect(e2.death_beam_intensity > e1.death_beam_intensity); try std.testing.expect(d.pos[1] > 0); }
test "defeat reward event occurs once" { var d = Dragon{ .phase = .dying, .health = 0, .death_ticks = 199 }; const e = d.tick(.{ 0, 0, 0 }); try std.testing.expectEqual(DEFEAT_XP, e.xp_drop); const again = d.tick(.{ 0, 0, 0 }); try std.testing.expectEqual(@as(u32, 0), again.xp_drop); }
test "exit portal fills nine central blocks and creates dragon egg at origin" { const p = activateExitPortal(); try std.testing.expect(p.active); for (p.portal_blocks) |block| try std.testing.expectEqual(BlockId.end_portal, block); try std.testing.expectEqual(BlockId.dragon_egg, p.egg_block); try std.testing.expectEqual(DragonEggItemType.dragon_egg, p.egg_item); try std.testing.expectEqual(@as(i32, 0), p.egg_pos[0]); try std.testing.expectEqual(@as(i32, 0), p.egg_pos[2]); }
test "arena emits portal activation only when death animation completes" { var fight = DragonArenaFight{ .dragon = .{ .phase = .dying, .health = 0, .death_ticks = 199 } }; const e = updateArena(&fight, .{ 0, 0, 0 }); try std.testing.expect(e.portal != null); try std.testing.expect(fight.exit_portal.active); }
test "arena crystal destruction validates out of range indices" { var fight = DragonArenaFight{}; try std.testing.expect(!fight.destroyArenaCrystal(CRYSTAL_COUNT).destroyed); }
