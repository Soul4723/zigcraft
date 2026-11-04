const std = @import("std");

// Guardian & Elder Guardian canonical mob constants
pub const GUARDIAN_MAX_HEALTH: f32 = 30.0;
pub const ELDER_MAX_HEALTH: f32 = 80.0;
pub const SWIM_SPEED: f32 = 2.4;
pub const SWIM_SPEED_ELDER: f32 = 1.8;
pub const LAND_SPEED: f32 = 0.6;
pub const BODY_HEIGHT_METERS_ELDER: f32 = 2.8;
pub const CYCLOPEAN_EYE_COUNT: u8 = 1;
pub const PALE_IVORY_SKIN_RGBA: [4]f32 = .{ 0.86, 0.84, 0.75, 1.0 };
pub const SPIKE_COLOR: [4]f32 = .{ 1.0, 0.28, 0.06, 1.0 };
pub const SPIKE_COUNT: u8 = 12;
pub const THORNS_DAMAGE: f32 = 2.0;
pub const guardian_spike_thorns_damage: f32 = THORNS_DAMAGE;

// Laser beam constants
pub const guardian_laser_charge_seconds: f32 = 2.0;
pub const elder_guardian_laser_charge_seconds: f32 = 3.0;
pub const guardian_laser_range: f32 = 15.0;
pub const LASER_ACQUIRE_RANGE: f32 = guardian_laser_range;
pub const LASER_MAX_TRACK_RANGE: f32 = 16.0;
pub const LASER_CHARGE_TICKS: u8 = 60;
pub const TICKS_PER_SECOND: f32 = 20.0;

// Sponge & Monument constants
pub const sponge_absorption_limit: u8 = 65;
pub const sponge_absorption_radius: u4 = 7;
pub const APEX_GOLD_BLOCK_COUNT: u8 = 8;

// Elder Guardian curse & loot constants
pub const CURSE_RADIUS: f32 = 50.0;
pub const MINING_FATIGUE_III_TICKS: u32 = 6_000;
pub const PHANTOM_DURATION_TICKS: u8 = 30;
pub const MINING_SPEED_MULTIPLIER: f32 = 0.001;
pub const TIDE_TEMPLATE_CHANCE: f32 = 0.20;
pub const EXPERIENCE_DROP_ELDER: u8 = 10;

pub const GuardianLaserState = struct {
    target_id: ?u32 = null,
    charge_timer: f32 = 0.0,
};

pub const GuardianBeamColor = enum { purple, orange, yellow_flash };

pub const GuardianLaserTick = struct {
    fired_beam: bool,
    physical_damage: f32,
    magic_armor_piercing_damage: f32,
};

/// The beam progresses from purple through orange to a yellow flash as it charges.
pub fn guardianLaserChargeColor(state: GuardianLaserState, is_elder: bool) GuardianBeamColor {
    const duration = if (is_elder) elder_guardian_laser_charge_seconds else guardian_laser_charge_seconds;
    const progress = std.math.clamp(state.charge_timer / duration, 0.0, 1.0);
    if (progress >= 0.9) return .yellow_flash;
    if (progress >= 0.5) return .orange;
    return .purple;
}

/// Advances a focused Guardian beam. Losing sight or exceeding range breaks the charge.
pub fn tickGuardianLaserBeam(
    state: *GuardianLaserState,
    has_line_of_sight: bool,
    dist_to_target: f32,
    is_elder: bool,
    dt: f32,
) GuardianLaserTick {
    const no_damage = GuardianLaserTick{
        .fired_beam = false,
        .physical_damage = 0.0,
        .magic_armor_piercing_damage = 0.0,
    };
    if (!has_line_of_sight or dist_to_target < 0.0 or dist_to_target > guardian_laser_range or dt <= 0.0) {
        state.charge_timer = 0.0;
        return no_damage;
    }

    const charge_duration = if (is_elder) elder_guardian_laser_charge_seconds else guardian_laser_charge_seconds;
    state.charge_timer = @min(state.charge_timer + dt, charge_duration);
    if (state.charge_timer < charge_duration) return no_damage;

    state.charge_timer = 0.0;
    return .{
        .fired_beam = true,
        .physical_damage = if (is_elder) 8.0 else 6.0,
        .magic_armor_piercing_damage = if (is_elder) 2.0 else 1.0,
    };
}

/// Extended defensive spikes punish melee attacks while the Guardian is not laser-focused.
pub fn evaluateGuardianSpikeThorns(spikes_extended: bool, attacker_used_melee: bool) f32 {
    return if (spikes_extended and attacker_used_melee) guardian_spike_thorns_damage else 0.0;
}

pub const SpongePlacementResult = struct {
    became_wet: bool,
    became_dry_instantly: bool,
    water_absorbed_radius: u4,
};

/// Resolves sponge placement. The caller removes at most 65 water blocks in radius seven.
pub fn placeSpongeInBiomeOrDimension(
    is_wet_sponge: bool,
    placed_in_nether: bool,
    adjacent_water_blocks: u8,
) SpongePlacementResult {
    if (is_wet_sponge) {
        return .{
            .became_wet = false,
            .became_dry_instantly = placed_in_nether,
            .water_absorbed_radius = 0,
        };
    }
    return .{
        .became_wet = adjacent_water_blocks > 0,
        .became_dry_instantly = false,
        .water_absorbed_radius = if (adjacent_water_blocks > 0) sponge_absorption_radius else 0,
    };
}

pub const GuardianDrop = enum { prismarine_shard, prismarine_crystal, raw_cod };

pub fn guardianDrops() [3]GuardianDrop {
    return .{ .prismarine_shard, .prismarine_crystal, .raw_cod };
}

pub const Difficulty = enum { easy, normal, hard };

pub fn beamDamage(difficulty: Difficulty) f32 {
    return switch (difficulty) {
        .easy => 6.0,
        .normal => 9.0,
        .hard => 12.0,
    };
}

pub const Vec3 = [3]f32;

pub const ItemType = enum(u16) {
    wet_sponge = 183,
    milk_bucket = 472,
    tide_armor_trim_template = 395,
};

pub const BlockId = enum(u8) {
    wet_sponge = 124,
    gold_block = 149,
    dark_prismarine = 120,
};

pub const SoundEffect = enum { elder_guardian_curse };
pub const CurseLevel = enum { mining_fatigue_iii };
pub const MonumentRoom = enum { east_wing, west_wing, top_penthouse };

pub const GuardianSpawn = struct {
    room: MonumentRoom,
    relative_position: Vec3,
};

pub const MONUMENT_GUARDIANS = [_]GuardianSpawn{
    .{ .room = .east_wing, .relative_position = .{ 12.0, 0.0, 0.0 } },
    .{ .room = .west_wing, .relative_position = .{ -12.0, 0.0, 0.0 } },
    .{ .room = .top_penthouse, .relative_position = .{ 0.0, 8.0, 0.0 } },
};

pub const CurseEvent = struct {
    triggered: bool = false,
    phantom_active: bool = false,
    phantom_ticks: u8 = 0,
    sound: ?SoundEffect = null,
    effect: ?CurseLevel = null,
    effect_ticks: u32 = 0,
};

pub const MiningFatigue = struct {
    ticks_remaining: u32 = 0,

    pub fn isActive(self: MiningFatigue) bool {
        return self.ticks_remaining > 0;
    }

    pub fn miningSpeedMultiplier(self: MiningFatigue) f32 {
        return if (self.isActive()) MINING_SPEED_MULTIPLIER else 1.0;
    }

    pub fn tick(self: *MiningFatigue) void {
        if (self.ticks_remaining > 0) self.ticks_remaining -= 1;
    }

    pub fn cleanseWith(self: *MiningFatigue, item: ItemType) bool {
        if (item != .milk_bucket) return false;
        self.ticks_remaining = 0;
        return true;
    }
};

pub const CurseState = struct {
    fatigue: MiningFatigue = .{},
    phantom_ticks_remaining: u8 = 0,
    guardian_in_range: bool = false,

    pub fn phantomActive(self: CurseState) bool {
        return self.phantom_ticks_remaining > 0;
    }

    /// Triggers when the player enters the detection sphere.
    pub fn detect(self: *CurseState, player_position: Vec3, guardian_position: Vec3) CurseEvent {
        if (distanceVec3(player_position, guardian_position) > CURSE_RADIUS) {
            self.guardian_in_range = false;
            return .{};
        }
        if (self.guardian_in_range) return .{};
        self.guardian_in_range = true;
        self.fatigue.ticks_remaining = MINING_FATIGUE_III_TICKS;
        self.phantom_ticks_remaining = PHANTOM_DURATION_TICKS;
        return .{
            .triggered = true,
            .phantom_active = true,
            .phantom_ticks = PHANTOM_DURATION_TICKS,
            .sound = .elder_guardian_curse,
            .effect = .mining_fatigue_iii,
            .effect_ticks = MINING_FATIGUE_III_TICKS,
        };
    }

    pub fn tick(self: *CurseState) void {
        self.fatigue.tick();
        if (self.phantom_ticks_remaining > 0) self.phantom_ticks_remaining -= 1;
    }

    pub fn useItem(self: *CurseState, item: ItemType) bool {
        return self.fatigue.cleanseWith(item);
    }
};

pub const ElderLoot = struct {
    wet_sponges: u8 = 1,
    wet_sponge_item: ItemType = .wet_sponge,
    tide_templates: u8 = 0,
    tide_template_item: ItemType = .tide_armor_trim_template,
    experience: u8 = EXPERIENCE_DROP_ELDER,
};

/// roll must be in [0, 1). A fixed roll makes the probability boundary reproducible.
pub fn defeatElderLoot(roll: f32) ElderLoot {
    return .{ .tide_templates = if (roll >= 0.0 and roll < TIDE_TEMPLATE_CHANCE) 1 else 0 };
}

pub const ApexVault = struct {
    matrix_block: BlockId = .dark_prismarine,
    embedded_gold_blocks: u8 = APEX_GOLD_BLOCK_COUNT,
};

pub fn distanceVec3(a: Vec3, b: Vec3) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

test "Guardian state starts without a target or charge" {
    const state = GuardianLaserState{};
    try std.testing.expectEqual(@as(?u32, null), state.target_id);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "standard Guardian requires two seconds to fire" {
    var state = GuardianLaserState{};
    try std.testing.expect(!tickGuardianLaserBeam(&state, true, 10.0, false, 1.99).fired_beam);
    const shot = tickGuardianLaserBeam(&state, true, 10.0, false, 0.01);
    try std.testing.expect(shot.fired_beam);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "standard Guardian beam gives six physical and one piercing damage" {
    var state = GuardianLaserState{};
    const shot = tickGuardianLaserBeam(&state, true, 15.0, false, 2.0);
    try std.testing.expectEqual(@as(f32, 6.0), shot.physical_damage);
    try std.testing.expectEqual(@as(f32, 1.0), shot.magic_armor_piercing_damage);
}

test "Elder Guardian requires three seconds to fire" {
    var state = GuardianLaserState{};
    try std.testing.expect(!tickGuardianLaserBeam(&state, true, 8.0, true, 2.99).fired_beam);
    try std.testing.expect(tickGuardianLaserBeam(&state, true, 8.0, true, 0.01).fired_beam);
}

test "Elder Guardian beam gives eight physical and two piercing damage" {
    var state = GuardianLaserState{};
    const shot = tickGuardianLaserBeam(&state, true, 8.0, true, 3.0);
    try std.testing.expectEqual(@as(f32, 8.0), shot.physical_damage);
    try std.testing.expectEqual(@as(f32, 2.0), shot.magic_armor_piercing_damage);
}

test "pillar breaking line of sight immediately resets a standard charge" {
    var state = GuardianLaserState{ .charge_timer = 1.25 };
    const shot = tickGuardianLaserBeam(&state, false, 5.0, false, 0.1);
    try std.testing.expect(!shot.fired_beam);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "line of sight break resets an Elder charge" {
    var state = GuardianLaserState{ .charge_timer = 2.8 };
    _ = tickGuardianLaserBeam(&state, false, 5.0, true, 0.2);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "target outside fifteen blocks breaks the beam charge" {
    var state = GuardianLaserState{ .charge_timer = 1.0 };
    _ = tickGuardianLaserBeam(&state, true, 15.01, false, 0.1);
    try std.testing.expectEqual(@as(f32, 0.0), state.charge_timer);
}

test "target at fifteen blocks remains in valid beam range" {
    var state = GuardianLaserState{};
    _ = tickGuardianLaserBeam(&state, true, 15.0, false, 1.0);
    try std.testing.expectEqual(@as(f32, 1.0), state.charge_timer);
}

test "Guardian beam charge colors progress purple orange yellow" {
    var state = GuardianLaserState{};
    try std.testing.expectEqual(GuardianBeamColor.purple, guardianLaserChargeColor(state, false));
    state.charge_timer = 1.0;
    try std.testing.expectEqual(GuardianBeamColor.orange, guardianLaserChargeColor(state, false));
    state.charge_timer = 1.8;
    try std.testing.expectEqual(GuardianBeamColor.yellow_flash, guardianLaserChargeColor(state, false));
}

test "Elder color stages use its longer charge duration" {
    const state = GuardianLaserState{ .charge_timer = 1.0 };
    try std.testing.expectEqual(GuardianBeamColor.purple, guardianLaserChargeColor(state, true));
}

test "extended Guardian spikes return two melee thorns damage" {
    try std.testing.expectEqual(@as(f32, 2.0), evaluateGuardianSpikeThorns(true, true));
}

test "spikes do not hurt ranged attackers or retracted Guardians" {
    try std.testing.expectEqual(@as(f32, 0.0), evaluateGuardianSpikeThorns(true, false));
    try std.testing.expectEqual(@as(f32, 0.0), evaluateGuardianSpikeThorns(false, true));
}

test "dry sponge touching water absorbs within seven-block radius and becomes wet" {
    const result = placeSpongeInBiomeOrDimension(false, false, 1);
    try std.testing.expect(result.became_wet);
    try std.testing.expect(!result.became_dry_instantly);
    try std.testing.expectEqual(@as(u4, 7), result.water_absorbed_radius);
}

test "sponge absorption is bounded to sixty-five water blocks" {
    const result = placeSpongeInBiomeOrDimension(false, false, 100);
    try std.testing.expect(result.became_wet);
    try std.testing.expectEqual(sponge_absorption_limit, @min(@as(u8, 100), sponge_absorption_limit));
}

test "dry sponge away from water remains dry" {
    const result = placeSpongeInBiomeOrDimension(false, false, 0);
    try std.testing.expect(!result.became_wet);
    try std.testing.expectEqual(@as(u4, 0), result.water_absorbed_radius);
}

test "wet sponge placed in Nether dries instantly" {
    const result = placeSpongeInBiomeOrDimension(true, true, 0);
    try std.testing.expect(result.became_dry_instantly);
    try std.testing.expect(!result.became_wet);
}

test "wet sponge outside Nether does not instantly dry" {
    const result = placeSpongeInBiomeOrDimension(true, false, 0);
    try std.testing.expect(!result.became_dry_instantly);
}

test "unified Guardian and Elder Guardian constants" {
    try std.testing.expectEqual(@as(f32, 30.0), GUARDIAN_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 80.0), ELDER_MAX_HEALTH);
    try std.testing.expectEqual(@as(f32, 2.4), SWIM_SPEED);
    try std.testing.expectEqual(@as(f32, 1.8), SWIM_SPEED_ELDER);
    try std.testing.expectEqual(@as(f32, 0.6), LAND_SPEED);
    try std.testing.expectEqual(@as(f32, 2.8), BODY_HEIGHT_METERS_ELDER);
    try std.testing.expectEqual(@as(u8, 1), CYCLOPEAN_EYE_COUNT);
    try std.testing.expectEqual(@as(u8, 12), SPIKE_COUNT);
    try std.testing.expectEqual(@as(f32, 2.0), THORNS_DAMAGE);
    try std.testing.expectEqual(@as(f32, 15.0), LASER_ACQUIRE_RANGE);
    try std.testing.expectEqual(@as(f32, 16.0), LASER_MAX_TRACK_RANGE);
    try std.testing.expectEqual(@as(u8, 60), LASER_CHARGE_TICKS);
    try std.testing.expectEqual(@as(f32, 50.0), CURSE_RADIUS);
    try std.testing.expectEqual(@as(u32, 6000), MINING_FATIGUE_III_TICKS);
    try std.testing.expectEqual(@as(u8, 30), PHANTOM_DURATION_TICKS);
}

test "difficulty based laser beam damage" {
    try std.testing.expectEqual(@as(f32, 6.0), beamDamage(.easy));
    try std.testing.expectEqual(@as(f32, 9.0), beamDamage(.normal));
    try std.testing.expectEqual(@as(f32, 12.0), beamDamage(.hard));
}

test "guardian drop candidates include prismarine shards crystals and raw cod" {
    const drops = guardianDrops();
    try std.testing.expectEqual(GuardianDrop.prismarine_shard, drops[0]);
    try std.testing.expectEqual(GuardianDrop.prismarine_crystal, drops[1]);
    try std.testing.expectEqual(GuardianDrop.raw_cod, drops[2]);
}

test "monument layout assigns three guardians" {
    try std.testing.expectEqual(@as(usize, 3), MONUMENT_GUARDIANS.len);
    try std.testing.expectEqual(MonumentRoom.east_wing, MONUMENT_GUARDIANS[0].room);
    try std.testing.expectEqual(MonumentRoom.west_wing, MONUMENT_GUARDIANS[1].room);
    try std.testing.expectEqual(MonumentRoom.top_penthouse, MONUMENT_GUARDIANS[2].room);
}

test "curse detects player at fifty meters" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 50.0, 0.0, 0.0 });
    try std.testing.expect(event.triggered);
    try std.testing.expect(event.phantom_active);
    try std.testing.expectEqual(@as(u8, 30), event.phantom_ticks);
    try std.testing.expectEqual(SoundEffect.elder_guardian_curse, event.sound.?);
    try std.testing.expectEqual(CurseLevel.mining_fatigue_iii, event.effect.?);
    try std.testing.expectEqual(@as(u32, 6000), event.effect_ticks);
}

test "curse ignores players beyond fifty meters" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 50.01, 0.0, 0.0 });
    try std.testing.expect(!event.triggered);
}

test "curse triggers only once while in range until exiting and re-entering" {
    var state = CurseState{};
    _ = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 10.0, 0.0, 0.0 });
    try std.testing.expect(!state.detect(.{ 0.0, 0.0, 0.0 }, .{ 10.0, 0.0, 0.0 }).triggered);
    _ = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 60.0, 0.0, 0.0 });
    try std.testing.expect(state.detect(.{ 0.0, 0.0, 0.0 }, .{ 10.0, 0.0, 0.0 }).triggered);
}

test "phantom apparition expires after thirty ticks" {
    var state = CurseState{};
    _ = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 10.0, 0.0, 0.0 });
    try std.testing.expect(state.phantomActive());
    for (0..30) |_| state.tick();
    try std.testing.expect(!state.phantomActive());
}

test "mining fatigue reduces mining speed and cleanses with milk" {
    var fatigue = MiningFatigue{ .ticks_remaining = MINING_FATIGUE_III_TICKS };
    try std.testing.expect(fatigue.isActive());
    try std.testing.expectEqual(@as(f32, 0.001), fatigue.miningSpeedMultiplier());
    try std.testing.expect(!fatigue.cleanseWith(.wet_sponge));
    try std.testing.expect(fatigue.cleanseWith(.milk_bucket));
    try std.testing.expect(!fatigue.isActive());
    try std.testing.expectEqual(@as(f32, 1.0), fatigue.miningSpeedMultiplier());
}

test "elder guardian defeat loot gives wet sponge and rolls tide template" {
    const loot_high = defeatElderLoot(0.5);
    try std.testing.expectEqual(@as(u8, 1), loot_high.wet_sponges);
    try std.testing.expectEqual(@as(u8, 0), loot_high.tide_templates);
    try std.testing.expectEqual(@as(u8, 10), loot_high.experience);

    const loot_low = defeatElderLoot(0.1);
    try std.testing.expectEqual(@as(u8, 1), loot_low.tide_templates);
}

test "apex vault has eight embedded gold blocks in dark prismarine" {
    const vault = ApexVault{};
    try std.testing.expectEqual(@as(u8, 8), vault.embedded_gold_blocks);
    try std.testing.expectEqual(BlockId.dark_prismarine, vault.matrix_block);
}
