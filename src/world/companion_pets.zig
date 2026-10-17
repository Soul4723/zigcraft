/// Standalone gameplay rules for parrots, cats, and biome-specific wolves.

pub const ParrotColor = enum {
    red_blue,
    blue,
    green,
    yellow_blue,
    gray,
};

pub const ParrotFeedResult = struct {
    tamed: bool,
    instant_fatal_poison: bool,
};

/// A successful taming roll is one of the ten equally likely outcomes (0..9).
pub fn feedParrotItem(is_seed: bool, is_cookie: bool, taming_roll_0_to_9: u8) ParrotFeedResult {
    if (is_cookie) return .{ .tamed = false, .instant_fatal_poison = true };
    return .{ .tamed = is_seed and taming_roll_0_to_9 < 1, .instant_fatal_poison = false };
}

pub const ParrotShoulderState = struct {
    left_shoulder: ?ParrotColor = null,
    right_shoulder: ?ParrotColor = null,

    /// Put a parrot walked into onto the first available shoulder.
    pub fn perch(self: *ParrotShoulderState, color: ParrotColor) bool {
        if (self.left_shoulder == null) {
            self.left_shoulder = color;
            return true;
        }
        if (self.right_shoulder == null) {
            self.right_shoulder = color;
            return true;
        }
        return false;
    }

    pub fn dismount(self: *ParrotShoulderState) void {
        self.left_shoulder = null;
        self.right_shoulder = null;
    }
};

pub const ParrotDismountCause = enum {
    fall,
    water,
    damage,
    elytra_deploy,
};

/// Walking, sprinting, and sneaking do not dismount; only the four listed events do.
pub fn shouldParrotDismountShoulder(cause: ParrotDismountCause, fall_distance: f32) bool {
    return switch (cause) {
        .fall => fall_distance > 0.5,
        .water, .damage, .elytra_deploy => true,
    };
}

pub const hostile_mimicry_radius: f32 = 20.0;

/// Parrots mimic hostile mob idle sounds within 20 blocks, one octave higher.
pub fn detectParrotHostileMimicry(nearest_hostile_dist: f32) bool {
    return nearest_hostile_dist >= 0.0 and nearest_hostile_dist <= hostile_mimicry_radius;
}

pub const CatMorningGift = enum {
    rabbit_foot,
    phantom_membrane,
    string,
    feather,
    chicken,
    rotten_flesh,
    rabbit_hide,
};

/// A sleeping player with an unseated tamed cat nearby has a 70% dawn-gift chance.
/// `gift_roll` selects one of the seven possible items (values are wrapped modulo 7).
pub fn rollCatMorningBedGift(cat_is_sitting: bool, player_slept_through_night: bool, roll_0_to_99: u8, gift_roll: u8) ?CatMorningGift {
    if (cat_is_sitting or !player_slept_through_night or roll_0_to_99 >= 70) return null;
    return switch (gift_roll % 7) {
        0 => .rabbit_foot,
        1 => .phantom_membrane,
        2 => .string,
        3 => .feather,
        4 => .chicken,
        5 => .rotten_flesh,
        6 => .rabbit_hide,
        else => unreachable,
    };
}

pub const WolfBiomeVariant = enum {
    pale, // Taiga
    woods, // Forest
    ashen, // Snowy Taiga
    black, // Old Growth Pine Taiga
    chestnut, // Old Growth Spruce Taiga
    rusty, // Sparse Jungle
    spotted, // Savanna Plateau
    striped, // Wooded Badlands
    snowy, // Grove
};

/// Tail angle is 0° at no health and 90° at full health.
pub fn computeWolfTailAngleDeg(current_hp: f32, max_hp: f32) f32 {
    if (!(max_hp > 0.0)) return 0.0;
    return @min(90.0, @max(0.0, current_hp / max_hp * 90.0));
}

test "parrot seeds tame on exactly one of ten rolls" {
    try @import("std").testing.expect(feedParrotItem(true, false, 0).tamed);
    try @import("std").testing.expect(!feedParrotItem(true, false, 1).tamed);
    try @import("std").testing.expect(!feedParrotItem(false, false, 0).tamed);
}

test "parrot cookies are instantly fatal poison and do not tame" {
    const result = feedParrotItem(false, true, 0);
    try @import("std").testing.expect(!result.tamed);
    try @import("std").testing.expect(result.instant_fatal_poison);
}

test "parrot cookie poison takes precedence over seed flag" {
    try @import("std").testing.expect(feedParrotItem(true, true, 0).instant_fatal_poison);
}

test "parrot shoulders fill left then right and cap at two" {
    var state = ParrotShoulderState{};
    try @import("std").testing.expect(state.perch(.red_blue));
    try @import("std").testing.expectEqual(ParrotColor.red_blue, state.left_shoulder.?);
    try @import("std").testing.expect(state.perch(.blue));
    try @import("std").testing.expectEqual(ParrotColor.blue, state.right_shoulder.?);
    try @import("std").testing.expect(!state.perch(.green));
}

test "parrot shoulder state can hold colors on both sides" {
    const state = ParrotShoulderState{ .left_shoulder = .gray, .right_shoulder = .yellow_blue };
    try @import("std").testing.expectEqual(ParrotColor.gray, state.left_shoulder.?);
    try @import("std").testing.expectEqual(ParrotColor.yellow_blue, state.right_shoulder.?);
}

test "parrots stay perched through ordinary movement" {
    try @import("std").testing.expect(!shouldParrotDismountShoulder(.fall, 0.0));
    try @import("std").testing.expect(!shouldParrotDismountShoulder(.fall, 0.5));
}

test "parrot fall dismount threshold is strictly over half a block" {
    try @import("std").testing.expect(shouldParrotDismountShoulder(.fall, 0.51));
}

test "parrots dismount on water damage or elytra deployment" {
    try @import("std").testing.expect(shouldParrotDismountShoulder(.water, 0.0));
    try @import("std").testing.expect(shouldParrotDismountShoulder(.damage, 0.0));
    try @import("std").testing.expect(shouldParrotDismountShoulder(.elytra_deploy, 0.0));
}

test "dismount clears both parrot shoulders" {
    var state = ParrotShoulderState{ .left_shoulder = .green, .right_shoulder = .gray };
    state.dismount();
    try @import("std").testing.expect(state.left_shoulder == null and state.right_shoulder == null);
}

test "parrot hostile mimicry detects up to and including 20 blocks" {
    try @import("std").testing.expect(detectParrotHostileMimicry(20.0));
    try @import("std").testing.expect(detectParrotHostileMimicry(12.5));
    try @import("std").testing.expect(!detectParrotHostileMimicry(20.01));
    try @import("std").testing.expect(!detectParrotHostileMimicry(-1.0));
}

test "cat morning gifts require sleep and a non-sitting cat" {
    try @import("std").testing.expect(rollCatMorningBedGift(false, true, 0, 0) != null);
    try @import("std").testing.expect(rollCatMorningBedGift(true, true, 0, 0) == null);
    try @import("std").testing.expect(rollCatMorningBedGift(false, false, 0, 0) == null);
}

test "cat morning gift chance is 70 percent with exclusive upper bound" {
    try @import("std").testing.expect(rollCatMorningBedGift(false, true, 69, 0) != null);
    try @import("std").testing.expect(rollCatMorningBedGift(false, true, 70, 0) == null);
    try @import("std").testing.expect(rollCatMorningBedGift(false, true, 99, 0) == null);
}

test "cat morning gift roll selects all seven gift kinds" {
    try @import("std").testing.expectEqual(CatMorningGift.rabbit_foot, rollCatMorningBedGift(false, true, 0, 0).?);
    try @import("std").testing.expectEqual(CatMorningGift.phantom_membrane, rollCatMorningBedGift(false, true, 0, 1).?);
    try @import("std").testing.expectEqual(CatMorningGift.string, rollCatMorningBedGift(false, true, 0, 2).?);
    try @import("std").testing.expectEqual(CatMorningGift.feather, rollCatMorningBedGift(false, true, 0, 3).?);
    try @import("std").testing.expectEqual(CatMorningGift.chicken, rollCatMorningBedGift(false, true, 0, 4).?);
    try @import("std").testing.expectEqual(CatMorningGift.rotten_flesh, rollCatMorningBedGift(false, true, 0, 5).?);
    try @import("std").testing.expectEqual(CatMorningGift.rabbit_hide, rollCatMorningBedGift(false, true, 0, 6).?);
}

test "wolf biome variant enum contains nine variants" {
    const variants = [_]WolfBiomeVariant{ .pale, .woods, .ashen, .black, .chestnut, .rusty, .spotted, .striped, .snowy };
    try @import("std").testing.expectEqual(@as(usize, 9), variants.len);
}

test "wolf tail angle tracks health and clamps to bounds" {
    try @import("std").testing.expectEqual(@as(f32, 90.0), computeWolfTailAngleDeg(20, 20));
    try @import("std").testing.expectEqual(@as(f32, 45.0), computeWolfTailAngleDeg(10, 20));
    try @import("std").testing.expectEqual(@as(f32, 0.0), computeWolfTailAngleDeg(0, 20));
    try @import("std").testing.expectEqual(@as(f32, 0.0), computeWolfTailAngleDeg(-2, 20));
    try @import("std").testing.expectEqual(@as(f32, 90.0), computeWolfTailAngleDeg(25, 20));
    try @import("std").testing.expectEqual(@as(f32, 0.0), computeWolfTailAngleDeg(5, 0));
}
