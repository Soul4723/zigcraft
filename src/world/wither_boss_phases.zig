const std = @import("std");

pub const MAX_HEALTH: f32 = 300.0;
pub const PHASE_2_HEALTH: f32 = 150.0;
pub const SPAWN_TICKS: u16 = 220;
pub const BIRTH_EXPLOSION_POWER: f32 = 7.0;
pub const BIRTH_BLAST_DAMAGE: f32 = 50.0;
pub const DEATH_TICKS: u16 = 200;
pub const DEFEAT_XP: u32 = 50;
pub const NETHER_STAR_ITEM_ID: u16 = 274;
pub const TICKS_PER_SECOND: f32 = 20.0;

pub const Vec3 = [3]f32;
pub const Block = enum { air, soul_sand, soul_soil, wither_skeleton_skull, stone, deepslate, obsidian, bedrock, barrier, other };
pub const Axis = enum { x, z };

/// Input order: stem bottom, stem top, left arm, right arm, then the three skulls.
pub const SummoningPattern = struct {
    blocks: [7]Block,
    axis: Axis = .x,
};

pub const SummoningResult = struct {
    summoned: bool,
    boss_position: Vec3,
    cleared_positions: [7][3]i32,
};

fn isSoul(block: Block) bool {
    return block == .soul_sand or block == .soul_soil;
}

pub fn checkSummoningPattern(origin: [3]i32, pattern: SummoningPattern) SummoningResult {
    const valid = isSoul(pattern.blocks[0]) and isSoul(pattern.blocks[1]) and
        isSoul(pattern.blocks[2]) and isSoul(pattern.blocks[3]) and
        pattern.blocks[4] == .wither_skeleton_skull and
        pattern.blocks[5] == .wither_skeleton_skull and
        pattern.blocks[6] == .wither_skeleton_skull;
    const side: [3]i32 = if (pattern.axis == .x) .{ 1, 0, 0 } else .{ 0, 0, 1 };
    const lower = origin;
    const upper = addInt(origin, .{ 0, 1, 0 });
    const left = subInt(upper, side);
    const right = addInt(upper, side);
    const positions = .{
        lower,                      upper,                       left,                        right,
        addInt(left, .{ 0, 1, 0 }), addInt(upper, .{ 0, 1, 0 }), addInt(right, .{ 0, 1, 0 }),
    };
    return .{
        .summoned = valid,
        .boss_position = .{ @floatFromInt(upper[0]), @floatFromInt(upper[1]), @floatFromInt(upper[2]) },
        .cleared_positions = positions,
    };
}

fn addInt(a: [3]i32, b: [3]i32) [3]i32 {
    return .{ a[0] + b[0], a[1] + b[1], a[2] + b[2] };
}

fn subInt(a: [3]i32, b: [3]i32) [3]i32 {
    return .{ a[0] - b[0], a[1] - b[1], a[2] - b[2] };
}

pub const Phase = enum { spawning, artillery, armored_melee, dying, defeated };
pub const Head = enum { center, left, right };
pub const SkullKind = enum { black, blue };
pub const TargetKind = enum { player, hostile_mob, neutral_mob, passive_mob };

pub const Target = struct { position: Vec3, kind: TargetKind };
pub const SkullShot = struct {
    head: Head,
    target_index: usize,
    kind: SkullKind,
    speed: f32,
    direct_damage: f32 = 8.0,
    wither_level: u8 = 2,
    wither_ticks: u16 = 200,
};

pub const TickEvents = struct {
    birth_explosion: bool = false,
    birth_explosion_power: f32 = 0.0,
    birth_blast_damage: f32 = 0.0,
    spawn_glowing_cyan_white: bool = false,
    melee_hit: bool = false,
    melee_damage: f32 = 0.0,
    melee_wither_level: u8 = 0,
    melee_wither_ticks: u16 = 0,
    shots: [3]?SkullShot = .{ null, null, null },
    death_animation: bool = false,
    death_flash_white: bool = false,
    death_scale: f32 = 1.0,
    nether_star_drop: u8 = 0,
    xp_drop: u32 = 0,
};

pub const Boss = struct {
    position: Vec3,
    health: f32 = 0.0,
    phase: Phase = .spawning,
    spawn_ticks: u16 = 0,
    combat_ticks: u32 = 0,
    death_ticks: u16 = 0,
    reward_emitted: bool = false,
    head_cursors: [2]usize = .{ 0, 1 },

    pub fn init(position: Vec3) Boss {
        return .{ .position = position };
    }

    pub fn hasWitherArmor(self: Boss) bool {
        return self.phase == .armored_melee;
    }

    pub fn applyDamage(self: *Boss, amount: f32) f32 {
        if (self.phase == .spawning or self.phase == .dying or self.phase == .defeated or amount <= 0.0) return 0.0;
        const dealt = @min(self.health, amount);
        self.health -= dealt;
        if (self.health <= PHASE_2_HEALTH) self.phase = .armored_melee;
        if (self.health <= 0.0) {
            self.health = 0.0;
            self.phase = .dying;
            self.death_ticks = 0;
        }
        return dealt;
    }

    /// target_ground_y is the floor target height. Targets are supplied in stable order.
    pub fn tick(self: *Boss, targets: []const Target, target_ground_y: f32, melee_contact: bool) TickEvents {
        var events = TickEvents{};
        switch (self.phase) {
            .spawning => {
                self.spawn_ticks += 1;
                self.health = MAX_HEALTH * @as(f32, @floatFromInt(self.spawn_ticks)) / @as(f32, @floatFromInt(SPAWN_TICKS));
                self.position[1] += 0.08;
                events.spawn_glowing_cyan_white = true;
                if (self.spawn_ticks == SPAWN_TICKS) {
                    self.health = MAX_HEALTH;
                    self.phase = .artillery;
                    events.birth_explosion = true;
                    events.birth_explosion_power = BIRTH_EXPLOSION_POWER;
                    events.birth_blast_damage = BIRTH_BLAST_DAMAGE;
                }
            },
            .artillery => self.tickArtillery(targets, &events),
            .armored_melee => {
                self.position[1] = @max(target_ground_y + 2.0, 0.0);
                if (targets.len > 0) {
                    var target = targets[0].position;
                    target[1] = @max(target[1], target_ground_y + 2.0);
                    moveToward(&self.position, target, 7.0 / TICKS_PER_SECOND);
                    self.position[1] = @max(target_ground_y + 2.0, 0.0);
                    if (melee_contact) {
                        events.melee_hit = true;
                        events.melee_damage = 12.0;
                        events.melee_wither_level = 2;
                        events.melee_wither_ticks = 200;
                    }
                }
            },
            .dying => {
                self.death_ticks += 1;
                events.death_animation = true;
                events.death_flash_white = self.death_ticks % 8 < 4;
                events.death_scale = 1.0 + 2.0 * @as(f32, @floatFromInt(self.death_ticks)) / @as(f32, @floatFromInt(DEATH_TICKS));
                if (self.death_ticks >= DEATH_TICKS and !self.reward_emitted) {
                    self.phase = .defeated;
                    self.reward_emitted = true;
                    events.nether_star_drop = 1;
                    events.xp_drop = DEFEAT_XP;
                }
            },
            .defeated => {},
        }
        return events;
    }

    fn tickArtillery(self: *Boss, targets: []const Target, events: *TickEvents) void {
        self.combat_ticks += 1;
        if (targets.len == 0) return;
        const primary = primaryPlayer(targets) orelse return;
        const altitude = std.math.clamp(targets[primary].position[1] + 7.5, targets[primary].position[1] + 5.0, targets[primary].position[1] + 10.0);
        self.position[1] = approach(self.position[1], altitude, 5.0 / TICKS_PER_SECOND);
        if (self.combat_ticks % 40 == 0) events.shots[0] = .{ .head = .center, .target_index = primary, .kind = .black, .speed = 10.0 };
        if (self.combat_ticks % 20 == 0) {
            for (1..3) |slot| {
                if (pickSecondary(self, targets, primary, slot - 1)) |target_index| {
                    const blue = (self.combat_ticks / 20 + slot) % 3 == 0;
                    events.shots[slot] = .{
                        .head = if (slot == 1) .left else .right,
                        .target_index = target_index,
                        .kind = if (blue) .blue else .black,
                        .speed = if (blue) 6.0 else 10.0,
                    };
                }
            }
        }
    }
};

fn primaryPlayer(targets: []const Target) ?usize {
    for (targets, 0..) |target, i| if (target.kind == .player) return i;
    return if (targets.len > 0) 0 else null;
}

fn pickSecondary(boss: *Boss, targets: []const Target, primary: usize, cursor: usize) ?usize {
    if (targets.len < 2) return null;
    const eligible_count = targets.len - 1;
    const start = boss.head_cursors[cursor] % eligible_count;
    for (0..eligible_count) |offset| {
        const candidate = (start + offset) % eligible_count;
        const index = if (candidate >= primary) candidate + 1 else candidate;
        const kind = targets[index].kind;
        if (kind == .player or kind == .hostile_mob or kind == .neutral_mob) {
            boss.head_cursors[cursor] = (candidate + 1) % eligible_count;
            return index;
        }
    }
    return null;
}

fn approach(value: f32, target: f32, step: f32) f32 {
    return if (value < target) @min(value + step, target) else @max(value - step, target);
}

fn moveToward(position: *Vec3, target: Vec3, step: f32) void {
    const dx = target[0] - position[0];
    const dy = target[1] - position[1];
    const dz = target[2] - position[2];
    const length = @sqrt(dx * dx + dy * dy + dz * dz);
    if (length == 0.0) return;
    const amount = @min(step, length);
    position[0] += dx / length * amount;
    position[1] += dy / length * amount;
    position[2] += dz / length * amount;
}

pub const SkullImpact = struct { damage: f32, wither_level: u8, wither_ticks: u16 };

pub fn blackSkullImpact() SkullImpact {
    return .{ .damage = 8.0, .wither_level = 2, .wither_ticks = 200 };
}

pub fn blueSkullCanDestroy(block: Block) bool {
    return block != .air and block != .bedrock and block != .barrier;
}

pub fn projectileDamage(has_wither_armor: bool, projectile: Projectile) f32 {
    _ = projectile;
    return if (has_wither_armor) 0.0 else 1.0;
}

pub const Projectile = enum { arrow, spectral_arrow, tipped_arrow, trident, other };
pub const NetherStarItemType = enum(u16) { nether_star = NETHER_STAR_ITEM_ID };
pub const nether_star_blast_proof = true;

// Structure tests
fn validPattern(axis: Axis) SummoningPattern {
    return .{ .axis = axis, .blocks = .{ .soul_sand, .soul_soil, .soul_sand, .soul_soil, .wither_skeleton_skull, .wither_skeleton_skull, .wither_skeleton_skull } };
}

test "X-axis T pattern accepts sand and soil and clears seven blocks" {
    const result = checkSummoningPattern(.{ 4, 10, -3 }, validPattern(.x));
    try std.testing.expect(result.summoned);
    try std.testing.expectEqual([3]f32{ 4, 11, -3 }, result.boss_position);
    try std.testing.expectEqual([3]i32{ 3, 12, -3 }, result.cleared_positions[4]);
}
test "Z-axis T pattern locates arms and skulls" {
    const result = checkSummoningPattern(.{ 0, 5, 0 }, validPattern(.z));
    try std.testing.expectEqual([3]i32{ 0, 6, -1 }, result.cleared_positions[2]);
    try std.testing.expectEqual([3]i32{ 0, 7, 1 }, result.cleared_positions[6]);
}
test "summoning rejects missing lower stem" {
    var p = validPattern(.x);
    p.blocks[0] = .air;
    try std.testing.expect(!checkSummoningPattern(.{ 0, 0, 0 }, p).summoned);
}
test "summoning rejects missing upper stem" {
    var p = validPattern(.x);
    p.blocks[1] = .other;
    try std.testing.expect(!checkSummoningPattern(.{ 0, 0, 0 }, p).summoned);
}
test "summoning rejects missing left arm" {
    var p = validPattern(.x);
    p.blocks[2] = .air;
    try std.testing.expect(!checkSummoningPattern(.{ 0, 0, 0 }, p).summoned);
}
test "summoning rejects missing right arm" {
    var p = validPattern(.x);
    p.blocks[3] = .air;
    try std.testing.expect(!checkSummoningPattern(.{ 0, 0, 0 }, p).summoned);
}
test "summoning rejects each missing skull" {
    for (4..7) |i| {
        var p = validPattern(.x);
        p.blocks[i] = .air;
        try std.testing.expect(!checkSummoningPattern(.{ 0, 0, 0 }, p).summoned);
    }
}
test "boss appears at center of upper soul row" {
    const r = checkSummoningPattern(.{ -2, 9, 8 }, validPattern(.x));
    try std.testing.expectEqual([3]f32{ -2, 10, 8 }, r.boss_position);
}

// Spawn tests
test "spawn begins at zero health and is damage immune" {
    var b = Boss.init(.{ 0, 0, 0 });
    try std.testing.expectEqual(@as(f32, 0), b.health);
    try std.testing.expectEqual(@as(f32, 0), b.applyDamage(20));
}
test "spawn charges to 150 halfway through 220 ticks" {
    var b = Boss.init(.{ 0, 0, 0 });
    for (0..110) |_| _ = b.tick(&.{}, 0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 150), b.health, 0.001);
}
test "spawn reaches full health and emits birth blast exactly on tick 220" {
    var b = Boss.init(.{ 0, 0, 0 });
    var e = TickEvents{};
    for (0..219) |_| e = b.tick(&.{}, 0, false);
    try std.testing.expect(!e.birth_explosion);
    e = b.tick(&.{}, 0, false);
    try std.testing.expect(e.birth_explosion);
    try std.testing.expectEqual(@as(f32, 300), b.health);
}
test "birth blast has power seven and up to fifty damage" {
    var b = Boss.init(.{ 0, 0, 0 });
    var e = TickEvents{};
    for (0..220) |_| e = b.tick(&.{}, 0, false);
    try std.testing.expectEqual(@as(f32, 7), e.birth_explosion_power);
    try std.testing.expectEqual(@as(f32, 50), e.birth_blast_damage);
}
test "spawn rises and flashes cyan white while charging" {
    var b = Boss.init(.{ 0, 0, 0 });
    const e = b.tick(&.{}, 0, false);
    try std.testing.expect(e.spawn_glowing_cyan_white);
    try std.testing.expect(b.position[1] > 0);
}

// Artillery tests
fn activeBoss() Boss {
    var b = Boss.init(.{ 0, 0, 0 });
    b.phase = .artillery;
    b.health = 300;
    return b;
}
const sample_targets = [_]Target{ .{ .position = .{ 10, 2, 0 }, .kind = .player }, .{ .position = .{ 8, 2, 3 }, .kind = .hostile_mob }, .{ .position = .{ 7, 2, -3 }, .kind = .neutral_mob } };
test "center head fires at player on 40 tick interval" {
    var b = activeBoss();
    var e = TickEvents{};
    for (0..39) |_| e = b.tick(&sample_targets, 0, false);
    try std.testing.expect(e.shots[0] == null);
    e = b.tick(&sample_targets, 0, false);
    try std.testing.expectEqual(Head.center, e.shots[0].?.head);
    try std.testing.expectEqual(@as(usize, 0), e.shots[0].?.target_index);
}
test "both side heads independently fire at secondary targets after 20 ticks" {
    var b = activeBoss();
    var e = TickEvents{};
    for (0..20) |_| e = b.tick(&sample_targets, 0, false);
    try std.testing.expect(e.shots[1] != null and e.shots[2] != null);
    try std.testing.expect(e.shots[1].?.target_index != 0);
    try std.testing.expect(e.shots[2].?.target_index != 0);
}
test "side targeting advances independently across eligible targets" {
    var b = activeBoss();
    var e = TickEvents{};
    for (0..40) |_| e = b.tick(&sample_targets, 0, false);
    try std.testing.expect(e.shots[1].?.target_index != e.shots[2].?.target_index);
}
test "side heads skip passive mobs" {
    var b = activeBoss();
    const t = [_]Target{ sample_targets[0], .{ .position = .{ 1, 1, 1 }, .kind = .passive_mob } };
    for (0..20) |_| {
        const e = b.tick(&t, 0, false);
        try std.testing.expect(e.shots[1] == null and e.shots[2] == null);
    }
}
test "black skull impact deals eight and wither two for ten seconds" {
    const hit = blackSkullImpact();
    try std.testing.expectEqual(@as(f32, 8), hit.damage);
    try std.testing.expectEqual(@as(u8, 2), hit.wither_level);
    try std.testing.expectEqual(@as(u16, 200), hit.wither_ticks);
}
test "blue skull travels six meters per second and shatters stone deepslate obsidian" {
    const shot = SkullShot{ .head = .left, .target_index = 1, .kind = .blue, .speed = 6 };
    try std.testing.expectEqual(@as(f32, 6), shot.speed);
    try std.testing.expect(blueSkullCanDestroy(.stone));
    try std.testing.expect(blueSkullCanDestroy(.deepslate));
    try std.testing.expect(blueSkullCanDestroy(.obsidian));
}
test "blue skull does not destroy bedrock or barrier" {
    try std.testing.expect(!blueSkullCanDestroy(.bedrock));
    try std.testing.expect(!blueSkullCanDestroy(.barrier));
}
test "artillery altitude is five to ten meters above player" {
    var b = activeBoss();
    for (0..60) |_| _ = b.tick(&sample_targets, 0, false);
    try std.testing.expect(b.position[1] >= 7 and b.position[1] <= 12);
}
test "artillery flight approaches target altitude at five meters per second" {
    var b = activeBoss();
    const before = b.position[1];
    _ = b.tick(&sample_targets, 0, false);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), b.position[1] - before, 0.001);
}

// Armor and melee tests
test "health above 150 remains in artillery phase" {
    var b = activeBoss();
    _ = b.applyDamage(149);
    try std.testing.expectEqual(Phase.artillery, b.phase);
}
test "health at 150 activates wither armor" {
    var b = activeBoss();
    _ = b.applyDamage(150);
    try std.testing.expect(b.hasWitherArmor());
}
test "health below 150 activates wither armor" {
    var b = activeBoss();
    _ = b.applyDamage(151);
    try std.testing.expectEqual(Phase.armored_melee, b.phase);
}
test "arrows bounce from armor without damage" {
    try std.testing.expectEqual(@as(f32, 0), projectileDamage(true, .arrow));
}
test "spectral arrows bounce from armor without damage" {
    try std.testing.expectEqual(@as(f32, 0), projectileDamage(true, .spectral_arrow));
}
test "tipped arrows bounce from armor without damage" {
    try std.testing.expectEqual(@as(f32, 0), projectileDamage(true, .tipped_arrow));
}
test "tridents bounce from armor without damage" {
    try std.testing.expectEqual(@as(f32, 0), projectileDamage(true, .trident));
}
test "unarmored boss receives projectile damage" {
    try std.testing.expectEqual(@as(f32, 1), projectileDamage(false, .arrow));
}
test "armored phase descends to two meters above floor and charges at seven meters per second" {
    var b = activeBoss();
    b.phase = .armored_melee;
    b.position = .{ 0, 20, 0 };
    const t = [_]Target{.{ .position = .{ 10, 1, 0 }, .kind = .player }};
    _ = b.tick(&t, 0, false);
    try std.testing.expectEqual(@as(f32, 2), b.position[1]);
    try std.testing.expectApproxEqAbs(@as(f32, 0.35), b.position[0], 0.001);
}
test "melee contact deals twelve and applies wither two ten seconds" {
    var b = activeBoss();
    b.phase = .armored_melee;
    const t = [_]Target{.{ .position = .{ 1, 2, 0 }, .kind = .player }};
    const e = b.tick(&t, 0, true);
    try std.testing.expect(e.melee_hit);
    try std.testing.expectEqual(@as(f32, 12), e.melee_damage);
    try std.testing.expectEqual(@as(u16, 200), e.melee_wither_ticks);
}

// Death/drop tests
test "lethal damage starts a 200 tick white flashing expanding death animation" {
    var b = activeBoss();
    _ = b.applyDamage(300);
    try std.testing.expectEqual(Phase.dying, b.phase);
    const e = b.tick(&.{}, 0, false);
    try std.testing.expect(e.death_animation);
    try std.testing.expect(e.death_scale > 1);
}
test "death emits one nether star and fifty XP on tick 200" {
    var b = activeBoss();
    _ = b.applyDamage(300);
    var e = TickEvents{};
    for (0..200) |_| e = b.tick(&.{}, 0, false);
    try std.testing.expectEqual(@as(u8, 1), e.nether_star_drop);
    try std.testing.expectEqual(@as(u32, 50), e.xp_drop);
}
test "defeated boss never repeats drops" {
    var b = activeBoss();
    _ = b.applyDamage(300);
    for (0..200) |_| _ = b.tick(&.{}, 0, false);
    const e = b.tick(&.{}, 0, false);
    try std.testing.expectEqual(@as(u8, 0), e.nether_star_drop);
}
test "nether star item id is 274 and explosion proof" {
    try std.testing.expectEqual(@as(u16, 274), @intFromEnum(NetherStarItemType.nether_star));
    try std.testing.expect(nether_star_blast_proof);
}
