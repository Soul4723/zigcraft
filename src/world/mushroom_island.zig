const std = @import("std");

pub const MooshroomVariant = enum {
    red_mooshroom,
    brown_mooshroom,
};

pub const StewFlowerKind = enum {
    allium_fire_resistance_4s,
    azure_bluet_blindness_8s,
    blue_orchid_saturation_0_35s,
    cornflower_jump_boost_6s,
    dandelion_saturation_0_35s,
    lily_of_the_valley_poison_12s,
    oxeye_daisy_regeneration_8s,
    poppy_night_vision_5s,
    torchflower_night_vision_5s,
    tulip_weakness_9s,
    wither_rose_wither_8s,
    open_eyeblossom_blindness_7s,
    closed_eyeblossom_nausea_7s,
};

pub const MooshroomState = struct {
    variant: MooshroomVariant = .red_mooshroom,
    primed_stew_flower: ?StewFlowerKind = null,
    is_sheared_into_normal_cow: bool = false,
};

pub const InteractionResult = struct {
    output_item: []const u8,
    mushrooms_dropped: u8,
};

const no_output = InteractionResult{ .output_item = "", .mushrooms_dropped = 0 };

fn suspiciousStewForFlower(flower: StewFlowerKind) []const u8 {
    return switch (flower) {
        .allium_fire_resistance_4s => "SuspiciousStew:FireResistance:4s",
        .azure_bluet_blindness_8s => "SuspiciousStew:Blindness:8s",
        .blue_orchid_saturation_0_35s => "SuspiciousStew:Saturation:0.35s",
        .cornflower_jump_boost_6s => "SuspiciousStew:JumpBoost:6s",
        .dandelion_saturation_0_35s => "SuspiciousStew:Saturation:0.35s",
        .lily_of_the_valley_poison_12s => "SuspiciousStew:Poison:12s",
        .oxeye_daisy_regeneration_8s => "SuspiciousStew:Regeneration:8s",
        .poppy_night_vision_5s => "SuspiciousStew:NightVision:5s",
        .torchflower_night_vision_5s => "SuspiciousStew:NightVision:5s",
        .tulip_weakness_9s => "SuspiciousStew:Weakness:9s",
        .wither_rose_wither_8s => "SuspiciousStew:Wither:8s",
        .open_eyeblossom_blindness_7s => "SuspiciousStew:Blindness:7s",
        .closed_eyeblossom_nausea_7s => "SuspiciousStew:Nausea:7s",
    };
}

pub fn interactMooshroom(
    state: *MooshroomState,
    held_is_bowl: bool,
    held_is_bucket: bool,
    held_is_shears: bool,
    held_flower: ?StewFlowerKind,
) InteractionResult {
    if (state.is_sheared_into_normal_cow) {
        if (held_is_bucket) return .{ .output_item = "MilkBucket", .mushrooms_dropped = 0 };
        return no_output;
    }

    if (held_is_shears) {
        state.is_sheared_into_normal_cow = true;
        return .{
            .output_item = "Cow",
            .mushrooms_dropped = 5,
        };
    }

    if (held_is_bucket) return .{ .output_item = "MilkBucket", .mushrooms_dropped = 0 };

    if (held_is_bowl) {
        if (state.variant == .brown_mooshroom) {
            if (state.primed_stew_flower) |flower| {
                state.primed_stew_flower = null;
                return .{ .output_item = suspiciousStewForFlower(flower), .mushrooms_dropped = 0 };
            }
        }
        return .{ .output_item = "MushroomStew", .mushrooms_dropped = 0 };
    }

    if (state.variant == .brown_mooshroom) {
        if (held_flower) |flower| {
            state.primed_stew_flower = flower;
            return .{ .output_item = "", .mushrooms_dropped = 0 };
        }
    }

    return no_output;
}

pub fn canHostileMobSpawnInMushroomFields(in_mushroom_fields_biome: bool, is_spawner_or_raid: bool) bool {
    return !in_mushroom_fields_biome or is_spawner_or_raid;
}

test "mooshroom variants are distinct" {
    try std.testing.expect(MooshroomVariant.red_mooshroom != MooshroomVariant.brown_mooshroom);
    try std.testing.expectEqual(MooshroomVariant.red_mooshroom, (MooshroomState{}).variant);
}

test "bowl milking gives red mooshroom infinite mushroom stew" {
    var state = MooshroomState{};
    for (0..4) |_| {
        const result = interactMooshroom(&state, true, false, false, null);
        try std.testing.expectEqualStrings("MushroomStew", result.output_item);
    }
}

test "unprimed brown mooshroom bowl yields ordinary stew" {
    var state = MooshroomState{ .variant = .brown_mooshroom };
    const result = interactMooshroom(&state, true, false, false, null);
    try std.testing.expectEqualStrings("MushroomStew", result.output_item);
}

test "brown mooshroom can be primed by each of the thirteen flowers" {
    const flowers = [_]StewFlowerKind{
        .allium_fire_resistance_4s, .azure_bluet_blindness_8s,
        .blue_orchid_saturation_0_35s, .cornflower_jump_boost_6s,
        .dandelion_saturation_0_35s, .lily_of_the_valley_poison_12s,
        .oxeye_daisy_regeneration_8s, .poppy_night_vision_5s,
        .torchflower_night_vision_5s, .tulip_weakness_9s,
        .wither_rose_wither_8s, .open_eyeblossom_blindness_7s,
        .closed_eyeblossom_nausea_7s,
    };
    for (flowers) |flower| {
        var state = MooshroomState{ .variant = .brown_mooshroom };
        const feeding = interactMooshroom(&state, false, false, false, flower);
        try std.testing.expectEqualStrings("", feeding.output_item);
        try std.testing.expectEqual(flower, state.primed_stew_flower.?);
    }
}

test "brown mooshroom flower priming produces effect-specific stew and clears" {
    var state = MooshroomState{ .variant = .brown_mooshroom };
    _ = interactMooshroom(&state, false, false, false, .allium_fire_resistance_4s);
    const stew = interactMooshroom(&state, true, false, false, null);
    try std.testing.expectEqualStrings("SuspiciousStew:FireResistance:4s", stew.output_item);
    try std.testing.expect(state.primed_stew_flower == null);
}

test "all thirteen flower effects are preserved in suspicious stew" {
    const flowers = [_]StewFlowerKind{
        .allium_fire_resistance_4s, .azure_bluet_blindness_8s,
        .blue_orchid_saturation_0_35s, .cornflower_jump_boost_6s,
        .dandelion_saturation_0_35s, .lily_of_the_valley_poison_12s,
        .oxeye_daisy_regeneration_8s, .poppy_night_vision_5s,
        .torchflower_night_vision_5s, .tulip_weakness_9s,
        .wither_rose_wither_8s, .open_eyeblossom_blindness_7s,
        .closed_eyeblossom_nausea_7s,
    };
    for (flowers) |flower| {
        var state = MooshroomState{ .variant = .brown_mooshroom };
        _ = interactMooshroom(&state, false, false, false, flower);
        const result = interactMooshroom(&state, true, false, false, null);
        try std.testing.expectEqualStrings(suspiciousStewForFlower(flower), result.output_item);
        try std.testing.expect(state.primed_stew_flower == null);
    }
}

test "red mooshroom flowers do not prime suspicious stew" {
    var state = MooshroomState{};
    _ = interactMooshroom(&state, false, false, false, .poppy_night_vision_5s);
    try std.testing.expect(state.primed_stew_flower == null);
}

test "shears drop five variant-colored mushrooms and convert to cow" {
    inline for (.{ MooshroomVariant.red_mooshroom, MooshroomVariant.brown_mooshroom }) |variant| {
        var state = MooshroomState{ .variant = variant };
        const result = interactMooshroom(&state, false, false, true, null);
        try std.testing.expectEqual(@as(u8, 5), result.mushrooms_dropped);
        try std.testing.expectEqualStrings("Cow", result.output_item);
        try std.testing.expect(state.is_sheared_into_normal_cow);
    }
}

test "sheared cow cannot be sheared or bowl milked again" {
    var state = MooshroomState{};
    _ = interactMooshroom(&state, false, false, true, null);
    const shears = interactMooshroom(&state, false, false, true, null);
    const bowl = interactMooshroom(&state, true, false, false, null);
    try std.testing.expectEqual(@as(u8, 0), shears.mushrooms_dropped);
    try std.testing.expectEqualStrings("", bowl.output_item);
}

test "iron bucket milking yields milk bucket" {
    var state = MooshroomState{ .variant = .brown_mooshroom };
    _ = interactMooshroom(&state, false, false, false, .wither_rose_wither_8s);
    const result = interactMooshroom(&state, false, true, false, null);
    try std.testing.expectEqualStrings("MilkBucket", result.output_item);
}

test "bucket has priority and does not consume primed flower" {
    var state = MooshroomState{ .variant = .brown_mooshroom };
    _ = interactMooshroom(&state, false, false, false, .tulip_weakness_9s);
    _ = interactMooshroom(&state, false, true, false, null);
    try std.testing.expectEqual(StewFlowerKind.tulip_weakness_9s, state.primed_stew_flower.?);
}

test "natural hostile spawning is blocked in mushroom fields at every light level" {
    for (0..16) |_| {
        try std.testing.expect(!canHostileMobSpawnInMushroomFields(true, false));
    }
}

test "hostile spawning remains possible outside mushroom fields" {
    try std.testing.expect(canHostileMobSpawnInMushroomFields(false, false));
}

test "spawner or raid hostile spawning remains possible in mushroom fields" {
    try std.testing.expect(canHostileMobSpawnInMushroomFields(true, true));
}
