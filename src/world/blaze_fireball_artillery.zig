const std = @import("std");

pub const MAX_HEALTH: f32 = 20.0;
pub const ROD_COUNT: usize = 12;
pub const HOVER_SPEED_MIN: f32 = 0.5;
pub const HOVER_SPEED_MAX: f32 = 1.0;
pub const WATER_DAMAGE_PER_TICK: f32 = 1.0;
pub const CHARGE_TICKS: u16 = 60;
pub const VOLLEY_SHOTS: u8 = 3;
pub const SHOT_INTERVAL_TICKS: u8 = 6;
pub const VOLLEY_COOLDOWN_TICKS: u16 = 100;
pub const FIREBALL_SPEED: f32 = 14.0;
pub const FIREBALL_DAMAGE: f32 = 5.0;
pub const FIRE_TICKS: u16 = 100;
pub const EXPERIENCE_DROP: u8 = 10;
pub const BLAZE_ROD_DROP_CHANCE: f32 = 0.5;
pub const MAX_BLAZE_ROD_DROP: u8 = 4;
pub const TICKS_PER_SECOND: f32 = 20.0;

pub const Vec3 = [3]f32;
/// Inventory's blaze rod ItemType id, kept local for standalone module tests.
pub const BlazeRodItemType = enum(u16) { blaze_rod = 107 };
pub const BlazeRodPose = struct { pos: Vec3, angle: f32 };
pub const ParticleKind = enum { smoke, flame };
pub const AmbientParticle = struct { kind: ParticleKind, pos: Vec3, velocity: Vec3 };

pub const Blaze = struct {
    pos: Vec3 = .{ 0.0, 0.0, 0.0 },
    health: f32 = MAX_HEALTH,
    rod_angle: f32 = 0.0,

    pub const takes_fall_damage = false;
    pub const isImmuneToLava = true;
    pub const isImmuneToFire = true;

    pub fn applyEnvironmentalTick(self: *Blaze, in_water: bool, in_rain: bool) f32 {
        if (!in_water and !in_rain) return 0.0;
        const applied = @min(self.health, WATER_DAMAGE_PER_TICK);
        self.health -= applied;
        return applied;
    }

    pub fn applyFireOrLavaDamage(self: *Blaze, amount: f32, is_lava: bool) f32 {
        _ = self;
        _ = amount;
        _ = is_lava;
        return 0.0;
    }

    /// Moves toward a fixed hover altitude at 0.5–1 m/s and clamps at the target.
    pub fn holdAltitude(self: *Blaze, target_y: f32, dt: f32) f32 {
        if (dt <= 0.0) return 0.0;
        const difference = target_y - self.pos[1];
        if (@abs(difference) <= 0.000001) return 0.0;
        const speed = @min(HOVER_SPEED_MAX, @max(HOVER_SPEED_MIN, @abs(difference) / dt));
        const displacement = @min(@abs(difference), speed * dt) * std.math.sign(difference);
        self.pos[1] += displacement;
        return displacement / dt;
    }

    /// Updates the orbit and returns the current twelve-rod pose for rendering.
    pub fn tickRodOrbit(self: *Blaze, dt: f32) [ROD_COUNT]BlazeRodPose {
        self.rod_angle = @mod(self.rod_angle + @max(0.0, dt) * 2.0, 2.0 * std.math.pi);
        var rods: [ROD_COUNT]BlazeRodPose = undefined;
        for (0..ROD_COUNT) |i| {
            const angle = self.rod_angle + 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(ROD_COUNT));
            rods[i] = .{ .angle = angle, .pos = .{ self.pos[0] + @cos(angle) * 0.8, self.pos[1] + @sin(angle * 2.0) * 0.25, self.pos[2] + @sin(angle) * 0.8 } };
        }
        return rods;
    }

    /// Emits one rising smoke mote and one rising ember around the body.
    pub fn ambientParticles(self: Blaze, time: f32) [2]AmbientParticle {
        const phase = time * 3.0;
        return .{
            .{ .kind = .smoke, .pos = .{ self.pos[0] + @cos(phase) * 0.35, self.pos[1] + 0.7, self.pos[2] + @sin(phase) * 0.35 }, .velocity = .{ 0.0, 0.25, 0.0 } },
            .{ .kind = .flame, .pos = .{ self.pos[0] + @cos(phase + 1.5) * 0.45, self.pos[1] + 0.3, self.pos[2] + @sin(phase + 1.5) * 0.45 }, .velocity = .{ 0.0, 0.1, 0.0 } },
        };
    }
};

pub const AttackPhase = enum { charging, volley, cooldown };

pub const BlazeAttack = struct {
    phase: AttackPhase = .charging,
    charge_ticks: u16 = 0,
    cooldown_ticks: u16 = 0,
    shots_fired: u8 = 0,
    shot_timer: u8 = 0,

    /// Advances one game tick. The result is the number of fireballs launched.
    pub fn tick(self: *BlazeAttack) u8 {
        switch (self.phase) {
            .charging => {
                self.charge_ticks += 1;
                if (self.charge_ticks < CHARGE_TICKS) return 0;
                self.phase = .volley;
                self.shots_fired = 1;
                self.shot_timer = 0;
                return 1;
            },
            .volley => {
                self.shot_timer += 1;
                if (self.shot_timer < SHOT_INTERVAL_TICKS) return 0;
                self.shot_timer = 0;
                self.shots_fired += 1;
                if (self.shots_fired >= VOLLEY_SHOTS) {
                    self.phase = .cooldown;
                    self.cooldown_ticks = 0;
                }
                return 1;
            },
            .cooldown => {
                self.cooldown_ticks += 1;
                if (self.cooldown_ticks >= VOLLEY_COOLDOWN_TICKS) {
                    self.phase = .charging;
                    self.charge_ticks = 0;
                }
                return 0;
            },
        }
    }

    pub fn stemsAreIgnited(self: BlazeAttack) bool {
        return self.phase == .charging or self.phase == .volley;
    }
};

pub const Fireball = struct {
    pos: Vec3,
    velocity: Vec3,
    active: bool = true,

    pub fn launch(origin: Vec3, target: Vec3) Fireball {
        const delta = sub(target, origin);
        const length = @sqrt(delta[0] * delta[0] + delta[1] * delta[1] + delta[2] * delta[2]);
        const direction = if (length <= 0.000001) Vec3{ 0.0, 0.0, 1.0 } else scale(delta, 1.0 / length);
        return .{ .pos = origin, .velocity = scale(direction, FIREBALL_SPEED) };
    }

    /// Constant velocity keeps the projectile gravity-free.
    pub fn tick(self: *Fireball, dt: f32) void {
        if (!self.active or dt <= 0.0) return;
        self.pos = add(self.pos, scale(self.velocity, dt));
    }

    pub fn hitEntity(self: *Fireball) HitResult {
        if (!self.active) return .{};
        self.active = false;
        return .{ .damage = FIREBALL_DAMAGE, .fire_ticks = FIRE_TICKS, .ignite_block = false };
    }

    pub fn hitBlock(self: *Fireball) HitResult {
        if (!self.active) return .{};
        self.active = false;
        return .{ .ignite_block = true };
    }
};

pub const HitResult = struct { damage: f32 = 0.0, fire_ticks: u16 = 0, ignite_block: bool = false };
pub const BlazeRodDrop = struct { count: u8, experience: u8 = EXPERIENCE_DROP };

/// A successful 50% drop roll yields one rod plus one per Looting level, capped at four.
pub fn rollBlazeRodDrop(roll: f32, looting_level: u8) BlazeRodDrop {
    if (roll < 0.0 or roll >= BLAZE_ROD_DROP_CHANCE) return .{ .count = 0 };
    return .{ .count = @min(MAX_BLAZE_ROD_DROP, 1 +| looting_level) };
}

pub const Spawner = struct {
    activation_radius: f32 = 16.0,
    wave_size: u8 = 4,
    spawn_cooldown_ticks: u16 = 200,

    pub fn canActivate(self: Spawner, player_distance: f32) bool {
        return player_distance <= self.activation_radius;
    }
};

fn add(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] + b[0], a[1] + b[1], a[2] + b[2] };
}

fn sub(a: Vec3, b: Vec3) Vec3 {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}

fn scale(v: Vec3, amount: f32) Vec3 {
    return .{ v[0] * amount, v[1] * amount, v[2] * amount };
}

test "blaze has twenty hp" {
    try std.testing.expectEqual(@as(f32, 20.0), (Blaze{}).health);
    try std.testing.expectEqual(@as(f32, 20.0), MAX_HEALTH);
}

test "blaze has ten hearts of health" {
    try std.testing.expectEqual(@as(f32, 2.0), MAX_HEALTH / 10.0);
}

test "blaze never takes fall damage" {
    try std.testing.expect(!Blaze.takes_fall_damage);
}

test "blaze is immune to fire and lava" {
    try std.testing.expect(Blaze.isImmuneToFire);
    try std.testing.expect(Blaze.isImmuneToLava);
}

test "fire damage is ignored" {
    var blaze = Blaze{};
    try std.testing.expectEqual(@as(f32, 0.0), blaze.applyFireOrLavaDamage(12.0, false));
    try std.testing.expectEqual(MAX_HEALTH, blaze.health);
}

test "lava damage is ignored" {
    var blaze = Blaze{};
    try std.testing.expectEqual(@as(f32, 0.0), blaze.applyFireOrLavaDamage(20.0, true));
    try std.testing.expectEqual(MAX_HEALTH, blaze.health);
}

test "water damages one hp per tick" {
    var blaze = Blaze{};
    try std.testing.expectEqual(@as(f32, 1.0), blaze.applyEnvironmentalTick(true, false));
    try std.testing.expectEqual(@as(f32, 19.0), blaze.health);
}

test "rain damages one hp per tick" {
    var blaze = Blaze{};
    try std.testing.expectEqual(@as(f32, 1.0), blaze.applyEnvironmentalTick(false, true));
}

test "dry tick deals no water damage" {
    var blaze = Blaze{};
    try std.testing.expectEqual(@as(f32, 0.0), blaze.applyEnvironmentalTick(false, false));
    try std.testing.expectEqual(MAX_HEALTH, blaze.health);
}

test "water damage cannot reduce health below zero" {
    var blaze = Blaze{ .health = 0.5 };
    try std.testing.expectEqual(@as(f32, 0.5), blaze.applyEnvironmentalTick(true, false));
    try std.testing.expectEqual(@as(f32, 0.0), blaze.health);
}

test "hover rises toward target within speed range" {
    var blaze = Blaze{};
    const speed = blaze.holdAltitude(10.0, 1.0);
    try std.testing.expect(speed >= HOVER_SPEED_MIN and speed <= HOVER_SPEED_MAX);
    try std.testing.expectEqual(@as(f32, 1.0), blaze.pos[1]);
}

test "hover descends toward target within speed range" {
    var blaze = Blaze{ .pos = .{ 0.0, 10.0, 0.0 } };
    const speed = blaze.holdAltitude(0.0, 1.0);
    try std.testing.expect(speed <= -HOVER_SPEED_MIN and speed >= -HOVER_SPEED_MAX);
}

test "hover clamps without overshooting altitude" {
    var blaze = Blaze{ .pos = .{ 0.0, 0.25, 0.0 } };
    try std.testing.expectEqual(@as(f32, 0.25), blaze.holdAltitude(0.5, 1.0));
    try std.testing.expectEqual(@as(f32, 0.5), blaze.pos[1]);
}

test "hover leaves altitude unchanged at target" {
    var blaze = Blaze{ .pos = .{ 0.0, 3.0, 0.0 } };
    try std.testing.expectEqual(@as(f32, 0.0), blaze.holdAltitude(3.0, 0.5));
}

test "hover ignores nonpositive elapsed time" {
    var blaze = Blaze{};
    try std.testing.expectEqual(@as(f32, 0.0), blaze.holdAltitude(2.0, 0.0));
    try std.testing.expectEqual(@as(f32, 0.0), blaze.pos[1]);
}

test "blaze has twelve orbiting rods" {
    var blaze = Blaze{};
    const rods = blaze.tickRodOrbit(0.0);
    try std.testing.expectEqual(@as(usize, 12), rods.len);
}

test "rod orbit advances over time" {
    var blaze = Blaze{};
    _ = blaze.tickRodOrbit(0.5);
    try std.testing.expect(blaze.rod_angle > 0.0);
}

test "rods orbit around the blaze body" {
    var blaze = Blaze{ .pos = .{ 2.0, 4.0, 6.0 } };
    const rods = blaze.tickRodOrbit(0.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), @sqrt(std.math.pow(f32, rods[0].pos[0] - 2.0, 2) + std.math.pow(f32, rods[0].pos[2] - 6.0, 2)), 0.0001);
}

test "blaze emits floating smoke and fire particles" {
    const particles = (Blaze{}).ambientParticles(1.0);
    try std.testing.expectEqual(ParticleKind.smoke, particles[0].kind);
    try std.testing.expectEqual(ParticleKind.flame, particles[1].kind);
    try std.testing.expect(particles[0].velocity[1] > 0.0 and particles[1].velocity[1] > 0.0);
}

test "attack charges for exactly sixty ticks" {
    var attack = BlazeAttack{};
    for (0..59) |_| try std.testing.expectEqual(@as(u8, 0), attack.tick());
    try std.testing.expectEqual(AttackPhase.charging, attack.phase);
    try std.testing.expectEqual(@as(u8, 1), attack.tick());
}

test "charging ignites the blaze rods" {
    try std.testing.expect((BlazeAttack{}).stemsAreIgnited());
}

test "first shot starts volley at charge completion" {
    var attack = BlazeAttack{ .charge_ticks = 59 };
    try std.testing.expectEqual(@as(u8, 1), attack.tick());
    try std.testing.expectEqual(AttackPhase.volley, attack.phase);
    try std.testing.expectEqual(@as(u8, 1), attack.shots_fired);
}

test "second fireball launches six ticks after first" {
    var attack = BlazeAttack{ .phase = .volley, .shots_fired = 1 };
    for (0..5) |_| try std.testing.expectEqual(@as(u8, 0), attack.tick());
    try std.testing.expectEqual(@as(u8, 1), attack.tick());
    try std.testing.expectEqual(@as(u8, 2), attack.shots_fired);
}

test "third fireball launches six ticks after second" {
    var attack = BlazeAttack{ .phase = .volley, .shots_fired = 2 };
    for (0..5) |_| try std.testing.expectEqual(@as(u8, 0), attack.tick());
    try std.testing.expectEqual(@as(u8, 1), attack.tick());
    try std.testing.expectEqual(@as(u8, 3), attack.shots_fired);
}

test "three shot volley enters cooldown" {
    var attack = BlazeAttack{ .phase = .volley, .shots_fired = 2, .shot_timer = 5 };
    try std.testing.expectEqual(@as(u8, 1), attack.tick());
    try std.testing.expectEqual(AttackPhase.cooldown, attack.phase);
}

test "cooldown lasts one hundred ticks between volleys" {
    var attack = BlazeAttack{ .phase = .cooldown };
    for (0..99) |_| try std.testing.expectEqual(@as(u8, 0), attack.tick());
    try std.testing.expectEqual(AttackPhase.cooldown, attack.phase);
    try std.testing.expectEqual(@as(u8, 0), attack.tick());
    try std.testing.expectEqual(AttackPhase.charging, attack.phase);
}

test "cooldown rods stop glowing" {
    try std.testing.expect(!(BlazeAttack{ .phase = .cooldown }).stemsAreIgnited());
}

test "fireball speed is fourteen meters per second" {
    const fireball = Fireball.launch(.{ 0.0, 0.0, 0.0 }, .{ 3.0, 0.0, 4.0 });
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), @sqrt(fireball.velocity[0] * fireball.velocity[0] + fireball.velocity[2] * fireball.velocity[2]), 0.0001);
}

test "fireball travels without gravity decay" {
    var fireball = Fireball.launch(.{ 0.0, 0.0, 0.0 }, .{ 0.0, 1.0, 0.0 });
    const initial_y_velocity = fireball.velocity[1];
    fireball.tick(1.0);
    try std.testing.expectEqual(initial_y_velocity, fireball.velocity[1]);
    try std.testing.expectApproxEqAbs(@as(f32, 14.0), fireball.pos[1], 0.0001);
}

test "direct fireball hit deals five damage and burns for five seconds" {
    var fireball = Fireball.launch(.{ 0.0, 0.0, 0.0 }, .{ 0.0, 0.0, 1.0 });
    const hit = fireball.hitEntity();
    try std.testing.expectEqual(@as(f32, 5.0), hit.damage);
    try std.testing.expectEqual(@as(u16, 100), hit.fire_ticks);
}

test "fireball entity hit consumes projectile" {
    var fireball = Fireball.launch(.{ 0.0, 0.0, 0.0 }, .{ 0.0, 0.0, 1.0 });
    _ = fireball.hitEntity();
    try std.testing.expect(!fireball.active);
    try std.testing.expectEqual(@as(f32, 0.0), fireball.hitEntity().damage);
}

test "fireball impact ignites ground block" {
    var fireball = Fireball.launch(.{ 0.0, 0.0, 0.0 }, .{ 0.0, 0.0, 1.0 });
    try std.testing.expect(fireball.hitBlock().ignite_block);
}

test "fireball tick moves at constant velocity" {
    var fireball = Fireball.launch(.{ 0.0, 0.0, 0.0 }, .{ 0.0, 0.0, 1.0 });
    fireball.tick(0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), fireball.pos[2], 0.0001);
}

test "rod drop roll can yield zero rods" {
    try std.testing.expectEqual(@as(u8, 0), rollBlazeRodDrop(0.5, 0).count);
}

test "base rod drop yields one rod on success" {
    try std.testing.expectEqual(@as(u8, 1), rollBlazeRodDrop(0.0, 0).count);
}

test "looting adds one rod per level" {
    try std.testing.expectEqual(@as(u8, 2), rollBlazeRodDrop(0.0, 1).count);
    try std.testing.expectEqual(@as(u8, 3), rollBlazeRodDrop(0.0, 2).count);
}

test "looting rod drop caps at four" {
    try std.testing.expectEqual(@as(u8, 4), rollBlazeRodDrop(0.0, 3).count);
    try std.testing.expectEqual(@as(u8, 4), rollBlazeRodDrop(0.0, 10).count);
}

test "rod drops always award ten experience" {
    try std.testing.expectEqual(@as(u8, 10), rollBlazeRodDrop(0.0, 0).experience);
    try std.testing.expectEqual(@as(u8, 10), rollBlazeRodDrop(0.9, 3).experience);
}

test "rod reward identifies inventory blaze rod" {
    try std.testing.expectEqual(@as(u16, 107), @intFromEnum(BlazeRodItemType.blaze_rod));
}

test "blaze spawner activates within sixteen meters" {
    const spawner = Spawner{};
    try std.testing.expect(spawner.canActivate(16.0));
    try std.testing.expect(!spawner.canActivate(16.01));
}

test "blaze spawner emits a four blaze wave" {
    try std.testing.expectEqual(@as(u8, 4), (Spawner{}).wave_size);
}
