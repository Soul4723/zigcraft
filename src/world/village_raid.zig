const std = @import("std");

pub const ticks_per_second: f32 = 20.0;
pub const ravager_stun_duration: f32 = 2.0;
pub const ravager_roar_damage: f32 = 6.0;
pub const ravager_roar_radius: f32 = 4.0;
pub const evoker_fang_damage: f32 = 6.0;
pub const evoker_fang_spacing: f32 = 1.0;
pub const evoker_fang_warmup_step: f32 = 0.1;

pub const RaidDifficulty = enum { easy, normal, hard };

pub const RaidState = struct {
    active: bool = false,
    raid_omen_level: u3 = 1,
    // u3 cannot represent the valid eight-wave Hard + bonus raid in Zig;
    // wave indices/counts therefore use u4 while omen and Hero levels stay u3.
    current_wave: u4 = 0,
    total_waves: u4 = 3,
    raiders_remaining: u8 = 0,
    bell_ring_highlight_timer: f32 = 0.0,
    victory_fireworks_timer: f32 = 0.0,
    hero_of_the_village_level: u3 = 0,

    pub fn init(difficulty: RaidDifficulty, omen_level: u3) RaidState {
        const omen = @min(@as(u3, 5), @max(@as(u3, 1), omen_level));
        return .{ .raid_omen_level = omen, .total_waves = raidWaveCount(difficulty, omen) };
    }

    pub fn begin(self: *RaidState) void {
        self.active = true;
        self.current_wave = 1;
        self.raiders_remaining = compositionCount(waveComposition(self.current_wave));
        self.bell_ring_highlight_timer = 3.0;
        self.victory_fireworks_timer = 0.0;
    }

    pub fn recordRaiderDefeated(self: *RaidState) void {
        if (!self.active or self.raiders_remaining == 0) return;
        self.raiders_remaining -= 1;
        if (self.raiders_remaining != 0) return;
        if (self.current_wave < self.total_waves) {
            self.current_wave += 1;
            self.raiders_remaining = compositionCount(waveComposition(self.current_wave));
            self.bell_ring_highlight_timer = 3.0;
        } else {
            self.complete();
        }
    }

    pub fn complete(self: *RaidState) void {
        self.active = false;
        self.current_wave = self.total_waves;
        self.raiders_remaining = 0;
        self.hero_of_the_village_level = self.raid_omen_level;
        self.victory_fireworks_timer = 5.0;
    }

    pub fn tick(self: *RaidState, dt: f32) void {
        if (dt <= 0.0) return;
        self.bell_ring_highlight_timer = @max(0.0, self.bell_ring_highlight_timer - dt);
        self.victory_fireworks_timer = @max(0.0, self.victory_fireworks_timer - dt);
    }
};

pub fn triggerRaid(difficulty: RaidDifficulty, raid_omen_level: u3) RaidState {
    var raid = RaidState.init(difficulty, raid_omen_level);
    raid.begin();
    return raid;
}

pub fn triggerRaidWithOmen(raid_omen_level: u3, difficulty: RaidDifficulty) RaidState {
    return triggerRaid(difficulty, raid_omen_level);
}

pub fn raidWaveCount(difficulty: RaidDifficulty, raid_omen_level: u3) u4 {
    const base: u4 = switch (difficulty) { .easy => 3, .normal => 5, .hard => 7 };
    return base + @as(u4, @intFromBool(raid_omen_level > 1));
}

pub const WaveComposition = struct {
    pillagers: u8 = 0,
    vindicators: u8 = 0,
    witches: u8 = 0,
    ravagers: u8 = 0,
    evokers: u8 = 0,
};

/// Fixed representative Java raid composition, with canonical counts chosen
/// from the standard wave tables. Wave 8 is the ominous bonus-wave composition.
pub fn waveComposition(wave: u4) WaveComposition {
    return switch (wave) {
        1 => .{ .pillagers = 4 },
        2 => .{ .pillagers = 3, .vindicators = 2 },
        3 => .{ .pillagers = 3, .ravagers = 1, .witches = 1 },
        4 => .{ .pillagers = 4, .vindicators = 1, .witches = 3 },
        5 => .{ .pillagers = 4, .vindicators = 4, .witches = 1, .ravagers = 1, .evokers = 1 },
        6 => .{ .pillagers = 4, .vindicators = 2, .witches = 1, .evokers = 1 },
        7 => .{ .pillagers = 2, .vindicators = 5, .witches = 1, .ravagers = 2, .evokers = 2 },
        8 => .{ .pillagers = 2, .vindicators = 5, .witches = 1, .ravagers = 2, .evokers = 2 },
        else => .{},
    };
}

fn compositionCount(composition: WaveComposition) u8 {
    return composition.pillagers + composition.vindicators + composition.witches + composition.ravagers + composition.evokers;
}

pub const RavagerShieldBlock = struct {
    ravager_stunned: bool,
    stun_duration: f32,
    roar_after_stun: bool,
    roar_knockback_radius: f32,
    roar_damage: f32,
};

/// A successful shield block stuns on the lower half of the full u8 roll range.
pub fn resolveRavagerShieldBlock(blocked_with_shield: bool, roll: u8) RavagerShieldBlock {
    const stunned = blocked_with_shield and roll < 128;
    return .{
        .ravager_stunned = stunned,
        .stun_duration = if (stunned) ravager_stun_duration else 0.0,
        .roar_after_stun = stunned,
        .roar_knockback_radius = if (stunned) ravager_roar_radius else 0.0,
        .roar_damage = if (stunned) ravager_roar_damage else 0.0,
    };
}

pub const EvokerFang = struct { x: f32, z: f32, warmup_delay: f32, snap_damage: f32 };

/// Computes a jaw position on a 16-fang line, progressing from the evoker
/// toward the target at one-block intervals with a short sequential warmup.
pub fn computeEvokerFangLine(evoker_pos: [2]f32, target_pos: [2]f32, fang_index: u4) EvokerFang {
    const dx = target_pos[0] - evoker_pos[0];
    const dz = target_pos[1] - evoker_pos[1];
    const length = @sqrt(dx * dx + dz * dz);
    const ux = if (length > 0.0001) dx / length else 0.0;
    const uz = if (length > 0.0001) dz / length else 0.0;
    const distance = @as(f32, @floatFromInt(fang_index)) * evoker_fang_spacing;
    return .{
        .x = evoker_pos[0] + ux * distance,
        .z = evoker_pos[1] + uz * distance,
        .warmup_delay = @as(f32, @floatFromInt(fang_index)) * evoker_fang_warmup_step,
        .snap_damage = evoker_fang_damage,
    };
}

/// Applies the level-scaled Hero of the Village percentage discount. The
/// returned price is floored to whole emeralds and never falls below one.
pub fn applyHeroOfTheVillageDiscount(base_emerald_price: u8, hero_level: u3) u8 {
    if (base_emerald_price == 0) return 0;
    if (hero_level == 0) return base_emerald_price;
    const level = @min(hero_level, 5);
    const discount_basis_points: u32 = 3000 + 625 * (@as(u32, level) - 1);
    const discounted = @as(u32, base_emerald_price) * (10_000 - discount_basis_points) / 10_000;
    return @as(u8, @intCast(@max(@as(u32, 1), discounted)));
}

pub const VillagerGiftThrow = struct { enabled: bool, cooldown_min_seconds: u16 = 30, cooldown_max_seconds: u16 = 300 };

/// Hero of the Village also enables profession-themed villager gift throws.
pub fn villagerGiftThrow(hero_level: u3) VillagerGiftThrow {
    return .{ .enabled = hero_level > 0 };
}

test "raid wave counts by difficulty and omen bonus" {
    try std.testing.expectEqual(@as(u4, 3), raidWaveCount(.easy, 1));
    try std.testing.expectEqual(@as(u4, 4), raidWaveCount(.easy, 2));
    try std.testing.expectEqual(@as(u4, 5), raidWaveCount(.normal, 1));
    try std.testing.expectEqual(@as(u4, 6), raidWaveCount(.normal, 5));
    try std.testing.expectEqual(@as(u4, 7), raidWaveCount(.hard, 1));
    try std.testing.expectEqual(@as(u4, 8), raidWaveCount(.hard, 2));
}

test "RaidState initializes omen and difficulty wave count" {
    const state = RaidState.init(.hard, 3);
    try std.testing.expectEqual(@as(u3, 3), state.raid_omen_level);
    try std.testing.expectEqual(@as(u4, 8), state.total_waves);
    try std.testing.expect(!state.active);
}

test "wave composition covers deterministic canonical waves one through four" {
    const one = waveComposition(1);
    try std.testing.expectEqual(@as(u8, 4), one.pillagers);
    try std.testing.expectEqual(@as(u8, 0), one.vindicators);
    const two = waveComposition(2);
    try std.testing.expectEqual(@as(u8, 3), two.pillagers);
    try std.testing.expectEqual(@as(u8, 2), two.vindicators);
    const three = waveComposition(3);
    try std.testing.expectEqual(@as(u8, 1), three.ravagers);
    try std.testing.expectEqual(@as(u8, 1), three.witches);
    const four = waveComposition(4);
    try std.testing.expectEqual(@as(u8, 3), four.witches);
}

test "wave composition later waves include evokers and bonus wave mirrors final" {
    const five = waveComposition(5);
    try std.testing.expectEqual(@as(u8, 1), five.evokers);
    try std.testing.expectEqual(@as(u8, 4), five.vindicators);
    const seven = waveComposition(7);
    const bonus = waveComposition(8);
    try std.testing.expectEqual(@as(u8, 2), seven.evokers);
    try std.testing.expectEqual(@as(u8, 2), seven.ravagers);
    try std.testing.expectEqual(seven, bonus);
}

test "wave composition invalid zero returns empty" {
    try std.testing.expectEqual(WaveComposition{}, waveComposition(0));
}

test "Ravager shield block has 50 percent stun boundary" {
    try std.testing.expect(resolveRavagerShieldBlock(true, 0).ravager_stunned);
    try std.testing.expect(resolveRavagerShieldBlock(true, 127).ravager_stunned);
    try std.testing.expect(!resolveRavagerShieldBlock(true, 128).ravager_stunned);
    try std.testing.expect(!resolveRavagerShieldBlock(true, 255).ravager_stunned);
}

test "Ravager stun schedules 40 tick six damage four block roar" {
    const result = resolveRavagerShieldBlock(true, 12);
    try std.testing.expectEqual(@as(f32, 2.0), result.stun_duration);
    try std.testing.expectEqual(@as(f32, 40.0), result.stun_duration * ticks_per_second);
    try std.testing.expect(result.roar_after_stun);
    try std.testing.expectEqual(@as(f32, 4.0), result.roar_knockback_radius);
    try std.testing.expectEqual(@as(f32, 6.0), result.roar_damage);
}

test "Ravager does not stun or roar without shield or on failed roll" {
    for ([_]RavagerShieldBlock{ resolveRavagerShieldBlock(false, 0), resolveRavagerShieldBlock(true, 255) }) |result| {
        try std.testing.expect(!result.ravager_stunned);
        try std.testing.expect(!result.roar_after_stun);
        try std.testing.expectEqual(@as(f32, 0.0), result.roar_damage);
    }
}

test "Evoker fang line starts at source and carries magic damage" {
    const fang = computeEvokerFangLine(.{ 2.0, 3.0 }, .{ 10.0, 3.0 }, 0);
    try std.testing.expectEqual(@as(f32, 2.0), fang.x);
    try std.testing.expectEqual(@as(f32, 3.0), fang.z);
    try std.testing.expectEqual(@as(f32, 6.0), fang.snap_damage);
}

test "Evoker fang line advances sequentially toward target" {
    const fang = computeEvokerFangLine(.{ 0.0, 0.0 }, .{ 0.0, 12.0 }, 5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), fang.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), fang.z, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), fang.warmup_delay, 0.0001);
}

test "Evoker fang line normalizes diagonal direction" {
    const fang = computeEvokerFangLine(.{ 1.0, 1.0 }, .{ 9.0, 9.0 }, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 + @sqrt(@as(f32, 2.0))), fang.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 + @sqrt(@as(f32, 2.0))), fang.z, 0.0001);
}

test "Evoker fang zero direction remains at evoker" {
    const fang = computeEvokerFangLine(.{ 4.0, -2.0 }, .{ 4.0, -2.0 }, 15);
    try std.testing.expectEqual(@as(f32, 4.0), fang.x);
    try std.testing.expectEqual(@as(f32, -2.0), fang.z);
}

test "Hero discount scales by level and floors emerald price" {
    try std.testing.expectEqual(@as(u8, 70), applyHeroOfTheVillageDiscount(100, 1));
    try std.testing.expectEqual(@as(u8, 63), applyHeroOfTheVillageDiscount(100, 2));
    try std.testing.expectEqual(@as(u8, 45), applyHeroOfTheVillageDiscount(100, 5));
    try std.testing.expectEqual(@as(u8, 6), applyHeroOfTheVillageDiscount(10, 2));
}

test "Hero discount never reduces positive trade below one emerald" {
    try std.testing.expectEqual(@as(u8, 1), applyHeroOfTheVillageDiscount(1, 5));
    try std.testing.expectEqual(@as(u8, 1), applyHeroOfTheVillageDiscount(2, 5));
    try std.testing.expectEqual(@as(u8, 0), applyHeroOfTheVillageDiscount(0, 5));
}

test "no Hero level leaves trade prices unchanged" {
    try std.testing.expectEqual(@as(u8, 19), applyHeroOfTheVillageDiscount(19, 0));
}

test "Hero of the Village enables profession gift throws" {
    try std.testing.expect(!villagerGiftThrow(0).enabled);
    const gift = villagerGiftThrow(1);
    try std.testing.expect(gift.enabled);
    try std.testing.expectEqual(@as(u16, 30), gift.cooldown_min_seconds);
    try std.testing.expectEqual(@as(u16, 300), gift.cooldown_max_seconds);
}
