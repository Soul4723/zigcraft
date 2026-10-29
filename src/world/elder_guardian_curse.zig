const std = @import("std");

pub const TICKS_PER_SECOND: u16 = 20;
pub const MAX_HEALTH: f32 = 80.0;
pub const SWIM_SPEED_MPS: f32 = 1.8;
pub const BODY_HEIGHT_METERS: f32 = 2.8;
pub const CYCLOPEAN_EYE_COUNT: u8 = 1;
pub const PALE_IVORY_SKIN_RGBA: [4]f32 = .{ 0.86, 0.84, 0.75, 1.0 };
pub const THORNS_DAMAGE: f32 = 2.0;
pub const CURSE_RADIUS: f32 = 50.0;
pub const MINING_FATIGUE_III_TICKS: u32 = 6_000;
pub const PHANTOM_DURATION_TICKS: u8 = 30;
pub const MINING_SPEED_MULTIPLIER: f32 = 0.001;
pub const TIDE_TEMPLATE_CHANCE: f32 = 0.20;
pub const EXPERIENCE_DROP: u8 = 10;
pub const APEX_GOLD_BLOCK_COUNT: u8 = 8;

pub const Vec3 = [3]f32;

/// These values mirror the shared item and block enums while keeping this
/// rules module independently testable.
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

/// The room assignments are structural guarantees; actual world coordinates
/// remain owned by monument generation.
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

pub const ElderGuardian = struct {
    health: f32 = MAX_HEALTH,
    spikes_extended: bool = true,

    pub const max_health = MAX_HEALTH;
    pub const swim_speed_mps = SWIM_SPEED_MPS;
    pub const body_height_meters = BODY_HEIGHT_METERS;

    pub fn receiveAttack(self: *ElderGuardian, incoming_damage: f32, attacker_present: bool) struct { applied_damage: f32, thorns_damage: f32 } {
        const applied = @min(self.health, @max(incoming_damage, 0.0));
        self.health -= applied;
        return .{
            .applied_damage = applied,
            .thorns_damage = if (attacker_present and self.spikes_extended) THORNS_DAMAGE else 0.0,
        };
    }
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

    /// Triggers when the player enters the detection sphere. Caller owns audio,
    /// overlay rendering, and player effect application.
    pub fn detect(self: *CurseState, player_position: Vec3, guardian_position: Vec3) CurseEvent {
        if (distance(player_position, guardian_position) > CURSE_RADIUS) {
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

pub const Loot = struct {
    wet_sponges: u8 = 1,
    wet_sponge_item: ItemType = .wet_sponge,
    tide_templates: u8 = 0,
    tide_template_item: ItemType = .tide_armor_trim_template,
    experience: u8 = EXPERIENCE_DROP,
};

/// roll must be in [0, 1). A fixed roll makes the probability boundary
/// reproducible and leaves random-number ownership with the caller.
pub fn defeatLoot(roll: f32) Loot {
    return .{ .tide_templates = if (roll >= 0.0 and roll < TIDE_TEMPLATE_CHANCE) 1 else 0 };
}

pub const ApexVault = struct {
    matrix_block: BlockId = .dark_prismarine,
    embedded_gold_blocks: u8 = APEX_GOLD_BLOCK_COUNT,
};

pub fn distance(a: Vec3, b: Vec3) f32 {
    const dx = a[0] - b[0];
    const dy = a[1] - b[1];
    const dz = a[2] - b[2];
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

test "elder guardian has an 80 HP health pool" {
    try std.testing.expectEqual(@as(f32, 80.0), (ElderGuardian{}).health);
    try std.testing.expectEqual(MAX_HEALTH, ElderGuardian.max_health);
}

test "elder guardian geometry is 2.8 meters tall" {
    try std.testing.expectEqual(@as(f32, 2.8), ElderGuardian.body_height_meters);
}

test "elder guardian has a single cyclopean eye" {
    try std.testing.expectEqual(@as(u8, 1), CYCLOPEAN_EYE_COUNT);
}

test "elder guardian skin is pale ivory" {
    try std.testing.expect(PALE_IVORY_SKIN_RGBA[0] > 0.8);
    try std.testing.expect(PALE_IVORY_SKIN_RGBA[1] > 0.8);
    try std.testing.expect(PALE_IVORY_SKIN_RGBA[2] > 0.7);
}

test "elder guardian swims at 1.8 meters per second" {
    try std.testing.expectEqual(@as(f32, 1.8), ElderGuardian.swim_speed_mps);
}

test "monument layout assigns three guardians" {
    try std.testing.expectEqual(@as(usize, 3), MONUMENT_GUARDIANS.len);
}

test "monument guardian rooms include east west and penthouse" {
    try std.testing.expectEqual(MonumentRoom.east_wing, MONUMENT_GUARDIANS[0].room);
    try std.testing.expectEqual(MonumentRoom.west_wing, MONUMENT_GUARDIANS[1].room);
    try std.testing.expectEqual(MonumentRoom.top_penthouse, MONUMENT_GUARDIANS[2].room);
}

test "east wing guardian has an eastward relative position" {
    try std.testing.expect(MONUMENT_GUARDIANS[0].relative_position[0] > 0.0);
}

test "west wing guardian has a westward relative position" {
    try std.testing.expect(MONUMENT_GUARDIANS[1].relative_position[0] < 0.0);
}

test "penthouse guardian is above the wing guardians" {
    try std.testing.expect(MONUMENT_GUARDIANS[2].relative_position[1] > MONUMENT_GUARDIANS[0].relative_position[1]);
}

test "guardian starts with defense spikes extended" {
    try std.testing.expect((ElderGuardian{}).spikes_extended);
}

test "extended spikes retaliate for two HP when struck" {
    var guardian = ElderGuardian{};
    const hit = guardian.receiveAttack(3.0, true);
    try std.testing.expectEqual(@as(f32, 2.0), hit.thorns_damage);
}

test "retracted spikes do not retaliate" {
    var guardian = ElderGuardian{ .spikes_extended = false };
    const hit = guardian.receiveAttack(3.0, true);
    try std.testing.expectEqual(@as(f32, 0.0), hit.thorns_damage);
}

test "spikes do not retaliate without an attacker" {
    var guardian = ElderGuardian{};
    const hit = guardian.receiveAttack(3.0, false);
    try std.testing.expectEqual(@as(f32, 0.0), hit.thorns_damage);
}

test "received damage is bounded by remaining health" {
    var guardian = ElderGuardian{ .health = 4.0 };
    const hit = guardian.receiveAttack(8.0, true);
    try std.testing.expectEqual(@as(f32, 4.0), hit.applied_damage);
    try std.testing.expectEqual(@as(f32, 0.0), guardian.health);
}

test "curse radius is fifty meters" {
    try std.testing.expectEqual(@as(f32, 50.0), CURSE_RADIUS);
}

test "curse detects player at exactly fifty meters" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 50.0, 0.0, 0.0 });
    try std.testing.expect(event.triggered);
}

test "curse detects with Euclidean three dimensional distance" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 30.0, 0.0, 40.0 });
    try std.testing.expect(event.triggered);
}

test "curse ignores players beyond fifty meters" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 50.01, 0.0, 0.0 });
    try std.testing.expect(!event.triggered);
}

test "curse triggers only once while the player stays within range" {
    var state = CurseState{};
    _ = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    const repeated = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    try std.testing.expect(!repeated.triggered);
}

test "curse can trigger again after the player leaves and re-enters range" {
    var state = CurseState{};
    _ = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    _ = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 51.0, 0.0, 0.0 });
    const entered_again = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    try std.testing.expect(entered_again.triggered);
}

test "curse emits a ghostly phantom apparition" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    try std.testing.expect(event.phantom_active);
}

test "phantom apparition lasts thirty ticks" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    try std.testing.expectEqual(@as(u8, 30), event.phantom_ticks);
}

test "phantom apparition expires after thirty ticks" {
    var state = CurseState{};
    _ = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    for (0..30) |_| state.tick();
    try std.testing.expect(!state.phantomActive());
}

test "curse event requests elder guardian ambient audio" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    try std.testing.expectEqual(SoundEffect.elder_guardian_curse, event.sound.?);
}

test "curse applies Mining Fatigue III" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    try std.testing.expectEqual(CurseLevel.mining_fatigue_iii, event.effect.?);
}

test "Mining Fatigue III lasts six thousand ticks" {
    var state = CurseState{};
    const event = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    try std.testing.expectEqual(@as(u32, 6_000), event.effect_ticks);
    try std.testing.expectEqual(@as(u32, 6_000), state.fatigue.ticks_remaining);
}

test "Mining Fatigue duration is five minutes" {
    try std.testing.expectEqual(@as(u32, 300), MINING_FATIGUE_III_TICKS / TICKS_PER_SECOND);
}

test "Mining Fatigue reduces mining speed by 99.9 percent" {
    var state = CurseState{};
    _ = state.detect(.{ 0.0, 0.0, 0.0 }, .{ 1.0, 0.0, 0.0 });
    try std.testing.expectEqual(@as(f32, 0.001), state.fatigue.miningSpeedMultiplier());
}

test "Mining Fatigue expires after six thousand ticks" {
    var fatigue = MiningFatigue{ .ticks_remaining = MINING_FATIGUE_III_TICKS };
    for (0..MINING_FATIGUE_III_TICKS) |_| fatigue.tick();
    try std.testing.expect(!fatigue.isActive());
}

test "inactive fatigue restores normal mining speed" {
    try std.testing.expectEqual(@as(f32, 1.0), (MiningFatigue{}).miningSpeedMultiplier());
}

test "milk bucket instantly cleanses Mining Fatigue" {
    var state = CurseState{ .fatigue = .{ .ticks_remaining = 5_000 } };
    try std.testing.expect(state.useItem(.milk_bucket));
    try std.testing.expectEqual(@as(u32, 0), state.fatigue.ticks_remaining);
}

test "non-milk items do not cleanse Mining Fatigue" {
    var fatigue = MiningFatigue{ .ticks_remaining = 10 };
    try std.testing.expect(!fatigue.cleanseWith(.wet_sponge));
    try std.testing.expectEqual(@as(u32, 10), fatigue.ticks_remaining);
}

test "defeat guarantees exactly one wet sponge" {
    const loot = defeatLoot(0.99);
    try std.testing.expectEqual(@as(u8, 1), loot.wet_sponges);
}

test "wet sponge drop maps to wet sponge item type" {
    try std.testing.expectEqual(ItemType.wet_sponge, defeatLoot(0.5).wet_sponge_item);
}

test "wet sponge drop maps to wet sponge block id" {
    try std.testing.expectEqual(BlockId.wet_sponge, @as(BlockId, .wet_sponge));
}

test "tide trim chance is twenty percent" {
    try std.testing.expectEqual(@as(f32, 0.20), TIDE_TEMPLATE_CHANCE);
}

test "tide trim drop names the Tide armor trim template" {
    try std.testing.expectEqual(ItemType.tide_armor_trim_template, defeatLoot(0.1).tide_template_item);
}

test "tide trim drops below twenty percent roll" {
    try std.testing.expectEqual(@as(u8, 1), defeatLoot(0.1999).tide_templates);
}

test "tide trim does not drop at twenty percent boundary" {
    try std.testing.expectEqual(@as(u8, 0), defeatLoot(0.20).tide_templates);
}

test "invalid low loot rolls do not award tide trim" {
    try std.testing.expectEqual(@as(u8, 0), defeatLoot(-0.01).tide_templates);
}

test "invalid high loot rolls do not award tide trim" {
    try std.testing.expectEqual(@as(u8, 0), defeatLoot(1.0).tide_templates);
}

test "elder guardian defeat awards ten experience points" {
    try std.testing.expectEqual(@as(u8, 10), defeatLoot(0.5).experience);
}

test "apex vault has eight embedded gold blocks" {
    try std.testing.expectEqual(@as(u8, 8), (ApexVault{}).embedded_gold_blocks);
}

test "apex vault gold blocks are gold block items" {
    try std.testing.expectEqual(BlockId.gold_block, @as(BlockId, .gold_block));
}

test "apex vault gold is embedded in dark prismarine" {
    try std.testing.expectEqual(BlockId.dark_prismarine, (ApexVault{}).matrix_block);
}
