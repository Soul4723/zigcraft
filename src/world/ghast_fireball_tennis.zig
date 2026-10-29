const std = @import("std");

pub const Vec3 = [3]f32;
pub const MAX_HEALTH: f32 = 10.0;
pub const WIDTH: f32 = 4.0;
pub const HEIGHT: f32 = 4.0;
pub const DEPTH: f32 = 4.0;
pub const SIGHT_RANGE: f32 = 64.0;
pub const CHARGE_TICKS: u8 = 10;
pub const FIREBALL_SPEED: f32 = 20.0;
pub const EXPLOSION_POWER: f32 = 1.0;
pub const MAX_DIRECT_DAMAGE: f32 = 12.0;
pub const REFLECTED_GHAST_DAMAGE: f32 = 1000.0;
pub const EXPERIENCE_DROP: u8 = 5;
pub const GUNPOWDER_ITEM_TYPE: u16 = 146;
pub const GHAST_TEAR_ITEM_TYPE: u16 = 334;

pub const ItemType = enum(u16) {
    gunpowder = GUNPOWDER_ITEM_TYPE,
    ghast_tear = GHAST_TEAR_ITEM_TYPE,
};

pub const SoundEffect = enum { ghast_ambient, ghast_warn };
pub const AttackSource = enum { fist, sword, axe, arrow, snowball, fishing_rod_hook };
pub const ChargeAppearance = enum { normal, red_orange };

pub const Ghast = struct {
    id: u32 = 1,
    pos: Vec3 = .{ 0.0, 0.0, 0.0 },
    velocity: Vec3 = .{ 0.0, 0.0, 0.0 },
    health: f32 = MAX_HEALTH,
    dead: bool = false,

    pub const width = WIDTH;
    pub const height = HEIGHT;
    pub const depth = DEPTH;
    pub const takes_fall_damage = false;
    pub const isImmuneToFire = true;
    pub const isImmuneToLava = true;

    /// Applies a desired drift velocity, clamped to the ghast's 0.5–1.5 m/s flight range.
    pub fn setDrift(self: *Ghast, desired_velocity: Vec3) void {
        const magnitude = length(desired_velocity);
        if (magnitude <= 0.000001) {
            self.velocity = .{ 0.0, 0.5, 0.0 };
            return;
        }
        self.velocity = scale(desired_velocity, std.math.clamp(magnitude, 0.5, 1.5) / magnitude);
    }

    /// Moves in open air without gravity or fall damage.
    pub fn tickFlight(self: *Ghast, dt: f32) void {
        if (dt <= 0.0 or self.dead) return;
        self.pos = add(self.pos, scale(self.velocity, dt));
    }

    pub fn applyFireOrLavaDamage(self: *Ghast, amount: f32) f32 {
        _ = self;
        _ = amount;
        return 0.0;
    }

    pub fn takeDamage(self: *Ghast, amount: f32) f32 {
        if (self.dead or amount <= 0.0) return 0.0;
        const dealt = @min(self.health, amount);
        self.health -= dealt;
        if (self.health <= 0.0) {
            self.health = 0.0;
            self.dead = true;
        }
        return dealt;
    }

    pub fn ambientSound() SoundEffect {
        return .ghast_ambient;
    }
};

pub fn canSeeTarget(distance: f32, has_line_of_sight: bool) bool {
    return has_line_of_sight and distance >= 0.0 and distance <= SIGHT_RANGE;
}

pub const AttackPhase = enum { idle, charging, cooldown };

pub const GhastAttack = struct {
    phase: AttackPhase = .idle,
    charge_ticks: u8 = 0,

    /// Starts a ten-tick charge only while the player is visible and within range.
    pub fn tick(self: *GhastAttack, target_distance: f32, has_line_of_sight: bool) AttackEvent {
        if (!canSeeTarget(target_distance, has_line_of_sight)) {
            self.phase = .idle;
            self.charge_ticks = 0;
            return .{};
        }
        if (self.phase == .cooldown) self.phase = .idle;
        if (self.phase == .idle) {
            self.phase = .charging;
            self.charge_ticks = 0;
            return .{ .sound = .ghast_warn };
        }
        self.charge_ticks += 1;
        if (self.charge_ticks < CHARGE_TICKS) return .{ .appearance = .red_orange };
        self.phase = .cooldown;
        self.charge_ticks = 0;
        return .{ .appearance = .red_orange, .launch_fireball = true };
    }

    pub fn appearance(self: GhastAttack) ChargeAppearance {
        return if (self.phase == .charging) .red_orange else .normal;
    }
};

pub const AttackEvent = struct {
    sound: ?SoundEffect = null,
    appearance: ChargeAppearance = .normal,
    launch_fireball: bool = false,
};

pub const Explosion = struct {
    power: f32 = EXPLOSION_POWER,
    direct_damage: f32 = 0.0,
    sets_surrounding_blocks_on_fire: bool = true,
    active: bool = true,
};

pub const GhastFireball = struct {
    pos: Vec3,
    velocity: Vec3,
    owner_ghast_id: u32,
    is_deflected: bool = false,
    deflector_player_id: ?u32 = null,
    active: bool = true,

    pub fn launch(origin: Vec3, player_target: Vec3, owner_ghast_id: u32) GhastFireball {
        const direction = normalize(sub(player_target, origin), .{ 0.0, 0.0, 1.0 });
        return .{ .pos = origin, .velocity = scale(direction, FIREBALL_SPEED), .owner_ghast_id = owner_ghast_id };
    }

    /// Constant velocity gives a straight, gravity-free trajectory.
    pub fn tick(self: *GhastFireball, dt: f32) void {
        if (!self.active or dt <= 0.0) return;
        self.pos = add(self.pos, scale(self.velocity, dt));
    }

    pub fn deflectFireball(self: *GhastFireball, player_look_vector: Vec3, player_id: u32) bool {
        if (!self.active or self.is_deflected) return false;
        const direction = normalize(player_look_vector, .{ 0.0, 0.0, 0.0 });
        if (length(direction) <= 0.000001) return false;
        self.velocity = scale(direction, FIREBALL_SPEED);
        self.is_deflected = true;
        self.deflector_player_id = player_id;
        return true;
    }

    pub fn hitByAttack(self: *GhastFireball, source: AttackSource, player_look_vector: Vec3, player_id: u32) bool {
        _ = source;
        return self.deflectFireball(player_look_vector, player_id);
    }

    pub fn impact(self: *GhastFireball, direct_hit: bool) ?Explosion {
        if (!self.active) return null;
        self.active = false;
        return .{ .direct_damage = if (direct_hit) MAX_DIRECT_DAMAGE else 0.0 };
    }

    pub fn hitGhast(self: *GhastFireball, ghast: *Ghast) GhastImpact {
        if (!self.active) return .{};
        self.active = false;
        if (!self.is_deflected) return .{};
        _ = ghast.takeDamage(REFLECTED_GHAST_DAMAGE);
        return .{ .damage = REFLECTED_GHAST_DAMAGE, .return_to_sender_achievement = ghast.id == self.owner_ghast_id };
    }
};

pub const GhastImpact = struct {
    damage: f32 = 0.0,
    return_to_sender_achievement: bool = false,
};

pub const Loot = struct {
    gunpowder: u8 = 0,
    ghast_tear: u8 = 0,
    experience: u8 = EXPERIENCE_DROP,
};

/// Gunpowder base count is uniformly selected from 0–2; each Looting level adds one.
pub fn rollGunpowder(roll: f32, looting_level: u8) u8 {
    if (roll < 0.0 or roll >= 1.0) return 0;
    const base: u8 = @intFromFloat(@floor(roll * 3.0));
    return @min(5, base +| looting_level);
}

/// Ghast tear chance is 50%, increased by 10 percentage points per Looting level.
pub fn rollGhastTear(roll: f32, looting_level: u8) u8 {
    if (roll < 0.0 or roll >= 1.0) return 0;
    const chance = @min(1.0, 0.5 + @as(f32, @floatFromInt(looting_level)) * 0.1);
    return @intFromBool(roll < chance);
}

pub fn rollLoot(gunpowder_roll: f32, tear_roll: f32, looting_level: u8) Loot {
    return .{
        .gunpowder = rollGunpowder(gunpowder_roll, looting_level),
        .ghast_tear = rollGhastTear(tear_roll, looting_level),
    };
}

/// Explosion power 1 breaks low-resistance netherrack, but not cobblestone.
pub fn canExplosionBreakBlock(blast_resistance: f32) bool {
    return blast_resistance >= 0.0 and blast_resistance < EXPLOSION_POWER * 3.5;
}

fn add(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] + b[0], a[1] + b[1], a[2] + b[2] };
}

fn sub(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}

fn scale(v: Vec3, factor: f32) Vec3 {
    return .{ v[0] * factor, v[1] * factor, v[2] * factor };
}

fn length(v: Vec3) f32 {
    return @sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
}

fn normalize(v: Vec3, fallback: Vec3) Vec3 {
    const magnitude = length(v);
    if (magnitude <= 0.000001) return fallback;
    return scale(v, 1.0 / magnitude);
}

test "ghast has ten hp and a 4x4x4 metre collision box" {
    try std.testing.expectEqual(@as(f32, 10.0), (Ghast{}).health);
    try std.testing.expectEqual(@as(f32, 4.0), Ghast.width);
    try std.testing.expectEqual(@as(f32, 4.0), Ghast.height);
    try std.testing.expectEqual(@as(f32, 4.0), Ghast.depth);
}

test "ghast health is five hearts" {
    try std.testing.expectEqual(@as(f32, 2.0), MAX_HEALTH / 5.0);
}
test "ghast is immune to fire and lava" {
    try std.testing.expect(Ghast.isImmuneToFire and Ghast.isImmuneToLava);
}
test "ghast environmental fire and lava damage is ignored" {
    var g = Ghast{};
    try std.testing.expectEqual(@as(f32, 0), g.applyFireOrLavaDamage(8));
    try std.testing.expectEqual(MAX_HEALTH, g.health);
}
test "ghast cannot take fall damage" {
    try std.testing.expect(!Ghast.takes_fall_damage);
}
test "ghast drift clamps to minimum flight speed" {
    var g = Ghast{};
    g.setDrift(.{ 0.1, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), length(g.velocity), 0.001);
}
test "ghast drift clamps to maximum flight speed" {
    var g = Ghast{};
    g.setDrift(.{ 3, 0, 0 });
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), length(g.velocity), 0.001);
}
test "ghast flight has no gravity decay" {
    var g = Ghast{ .velocity = .{ 0, 1, 0 } };
    g.tickFlight(1);
    try std.testing.expectEqual(@as(f32, 1), g.velocity[1]);
    try std.testing.expectEqual(@as(f32, 1), g.pos[1]);
}
test "ghast flight ignores nonpositive delta" {
    var g = Ghast{};
    g.tickFlight(0);
    try std.testing.expectEqual(@as(f32, 0), g.pos[1]);
}
test "ghast ambient sound is haunting ambient cry cue" {
    try std.testing.expectEqual(SoundEffect.ghast_ambient, Ghast.ambientSound());
}
test "target is detected at 64m with line of sight" {
    try std.testing.expect(canSeeTarget(64, true));
}
test "target is detected inside 64m with line of sight" {
    try std.testing.expect(canSeeTarget(12, true));
}
test "target outside 64m is not detected" {
    try std.testing.expect(!canSeeTarget(64.01, true));
}
test "target behind an obstruction is not detected" {
    try std.testing.expect(!canSeeTarget(12, false));
}
test "negative distance is rejected" {
    try std.testing.expect(!canSeeTarget(-1, true));
}
test "attack emits piercing warn on charge start" {
    var a = GhastAttack{};
    try std.testing.expectEqual(SoundEffect.ghast_warn, a.tick(10, true).sound.?);
}
test "attack starts only for visible target" {
    var a = GhastAttack{};
    _ = a.tick(10, false);
    try std.testing.expectEqual(AttackPhase.idle, a.phase);
}
test "charge animation turns eyes and mouth red orange" {
    var a = GhastAttack{};
    _ = a.tick(10, true);
    try std.testing.expectEqual(ChargeAppearance.red_orange, a.appearance());
}
test "attack charges for ten ticks before launching" {
    var a = GhastAttack{};
    _ = a.tick(5, true);
    for (0..9) |_| try std.testing.expect(!a.tick(5, true).launch_fireball);
    try std.testing.expect(a.tick(5, true).launch_fireball);
}
test "attack charge resets when line of sight is lost" {
    var a = GhastAttack{};
    _ = a.tick(5, true);
    _ = a.tick(5, true);
    _ = a.tick(5, false);
    try std.testing.expectEqual(@as(u8, 0), a.charge_ticks);
}
test "fireball aims toward player at twenty metres per second" {
    const f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 3, 0, 4 }, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 12), f.velocity[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 16), f.velocity[2], 0.001);
}
test "fireball speed is twenty metres per second" {
    const f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 1, 2, 3 }, 1);
    try std.testing.expectApproxEqAbs(FIREBALL_SPEED, length(f.velocity), 0.001);
}
test "fireball travels straight with zero gravity" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 1, 0, 0 }, 1);
    f.tick(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 10), f.pos[0], 0.001);
    try std.testing.expectEqual(@as(f32, 0), f.pos[1]);
}
test "fireball zero target delta uses stable forward direction" {
    const f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 0 }, 1);
    try std.testing.expectEqual(@as(f32, 20), f.velocity[2]);
}
test "impact explosion has power one and ignites surrounding blocks" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 1, 0, 0 }, 1);
    const x = f.impact(false).?;
    try std.testing.expectEqual(EXPLOSION_POWER, x.power);
    try std.testing.expect(x.sets_surrounding_blocks_on_fire);
}
test "direct fireball hit deals at most twelve hp" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 1, 0, 0 }, 1);
    try std.testing.expectEqual(MAX_DIRECT_DAMAGE, f.impact(true).?.direct_damage);
}
test "fireball impact resolves only once" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 1, 0, 0 }, 1);
    _ = f.impact(false);
    try std.testing.expect(f.impact(false) == null);
}
test "explosion breaks netherrack" {
    try std.testing.expect(canExplosionBreakBlock(0.4));
}
test "explosion cannot break cobblestone" {
    try std.testing.expect(!canExplosionBreakBlock(6));
}
test "fist deflects fireball into camera look vector" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    try std.testing.expect(f.hitByAttack(.fist, .{ 1, 0, 0 }, 42));
    try std.testing.expectEqual(@as(f32, 20), f.velocity[0]);
    try std.testing.expectEqual(@as(?u32, 42), f.deflector_player_id);
}
test "sword deflects fireball" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    try std.testing.expect(f.hitByAttack(.sword, .{ 0, 1, 0 }, 3));
    try std.testing.expectEqual(@as(f32, 20), f.velocity[1]);
}
test "axe deflects fireball" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    try std.testing.expect(f.hitByAttack(.axe, .{ -1, 0, 0 }, 3));
    try std.testing.expectEqual(@as(f32, -20), f.velocity[0]);
}
test "arrow deflects fireball" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    try std.testing.expect(f.hitByAttack(.arrow, .{ 1, 0, 1 }, 9));
    try std.testing.expectApproxEqAbs(FIREBALL_SPEED, length(f.velocity), 0.001);
}
test "snowball deflects fireball" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    try std.testing.expect(f.hitByAttack(.snowball, .{ 0, 0, -1 }, 9));
}
test "fishing rod hook deflects fireball" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    try std.testing.expect(f.hitByAttack(.fishing_rod_hook, .{ 0, 0, -1 }, 9));
}
test "deflected fireball records player and cannot be deflected again" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    _ = f.deflectFireball(.{ 1, 0, 0 }, 99);
    try std.testing.expect(f.is_deflected);
    try std.testing.expectEqual(@as(?u32, 99), f.deflector_player_id);
    try std.testing.expect(!f.deflectFireball(.{ 0, 1, 0 }, 100));
}
test "zero camera direction cannot deflect" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 1);
    try std.testing.expect(!f.deflectFireball(.{ 0, 0, 0 }, 2));
}
test "reflected fireball instantly kills ghast and returns to sender" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    _ = f.deflectFireball(.{ 0, 0, -1 }, 9);
    var g = Ghast{ .id = 7 };
    const impact = f.hitGhast(&g);
    try std.testing.expectEqual(REFLECTED_GHAST_DAMAGE, impact.damage);
    try std.testing.expect(g.dead);
    try std.testing.expectEqual(@as(f32, 0), g.health);
    try std.testing.expect(impact.return_to_sender_achievement);
}
test "unreflected fireball does not damage ghast" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    var g = Ghast{ .id = 7 };
    const impact = f.hitGhast(&g);
    try std.testing.expectEqual(@as(f32, 0), impact.damage);
    try std.testing.expect(!g.dead);
}
test "reflected fireball hitting another ghast is lethal without sender achievement" {
    var f = GhastFireball.launch(.{ 0, 0, 0 }, .{ 0, 0, 1 }, 7);
    _ = f.deflectFireball(.{ 0, 0, -1 }, 9);
    var g = Ghast{ .id = 8 };
    const impact = f.hitGhast(&g);
    try std.testing.expect(g.dead);
    try std.testing.expect(!impact.return_to_sender_achievement);
}
test "gunpowder drop range is zero through two before looting" {
    try std.testing.expectEqual(@as(u8, 0), rollGunpowder(0.1, 0));
    try std.testing.expectEqual(@as(u8, 1), rollGunpowder(0.5, 0));
    try std.testing.expectEqual(@as(u8, 2), rollGunpowder(0.9, 0));
}
test "looting increases gunpowder drops" {
    try std.testing.expectEqual(@as(u8, 4), rollGunpowder(0.9, 2));
}
test "ghast tear drops on successful roll" {
    try std.testing.expectEqual(@as(u8, 1), rollGhastTear(0.2, 0));
}
test "ghast tear can fail its base chance roll" {
    try std.testing.expectEqual(@as(u8, 0), rollGhastTear(0.8, 0));
}
test "looting improves tear chance" {
    try std.testing.expectEqual(@as(u8, 1), rollGhastTear(0.75, 3));
}
test "loot bundle grants five experience and both item outcomes" {
    const loot = rollLoot(0.9, 0.2, 0);
    try std.testing.expectEqual(@as(u8, 5), loot.experience);
    try std.testing.expectEqual(@as(u8, 2), loot.gunpowder);
    try std.testing.expectEqual(@as(u8, 1), loot.ghast_tear);
}
test "drop item type identifiers identify gunpowder and ghast tear" {
    try std.testing.expectEqual(@as(u16, 146), @intFromEnum(ItemType.gunpowder));
    try std.testing.expectEqual(@as(u16, 334), @intFromEnum(ItemType.ghast_tear));
}
