const std = @import("std");

pub const ACOUSTIC_RADIUS: f32 = 256.0;
pub const HORN_COOLDOWN_TICKS: u16 = 140;
pub const SCULK_SENSOR_FREQUENCY: u4 = 10;
pub const HIGH_REGISTER_MAX_PITCH_DEGREES: f32 = -30.0;
pub const LOW_REGISTER_MIN_PITCH_DEGREES: f32 = 30.0;

pub const GoatHornTheme = enum {
    ponder,
    sing,
    seek,
    feel,
    admire,
    call,
    yearn,
    dream,
};

pub const PitchRegister = enum {
    high,
    mid,
    low,

    pub fn multiplier(self: PitchRegister) f32 {
        return switch (self) {
            .high => 1.33,
            .mid => 1.0,
            .low => 0.75,
        };
    }
};

pub fn registerForCameraPitch(theta_degrees: f32) PitchRegister {
    if (theta_degrees <= HIGH_REGISTER_MAX_PITCH_DEGREES) return .high;
    if (theta_degrees >= LOW_REGISTER_MIN_PITCH_DEGREES) return .low;
    return .mid;
}

pub const VibratoMode = enum { steady, sneaking_vibrato };

pub const CraftingIngredient = union(enum) {
    empty,
    goat_horn: GoatHornTheme,
    copper_ingot,
};

pub const CraftingRecipe = struct {
    theme: GoatHornTheme,

    /// A 2x2 recipe: one horn of any call and one ingot in each remaining slot.
    pub fn match(grid: [4]CraftingIngredient) ?CraftingRecipe {
        var horn: ?GoatHornTheme = null;
        var ingots: u8 = 0;
        for (grid) |ingredient| switch (ingredient) {
            .empty => return null,
            .goat_horn => |theme| {
                if (horn != null) return null;
                horn = theme;
            },
            .copper_ingot => ingots += 1,
        };
        if (ingots != 3) return null;
        return .{ .theme = horn orelse return null };
    }
};

pub const CopperHorn = struct {
    theme: GoatHornTheme,

    pub fn craft(theme: GoatHornTheme) CopperHorn {
        return .{ .theme = theme };
    }
};

pub const Vec3 = struct { x: f32, y: f32, z: f32 };

pub const HornWave = struct {
    theme: GoatHornTheme,
    origin: Vec3,
    radius: f32 = ACOUSTIC_RADIUS,
    pitch_register: PitchRegister,
    pitch_multiplier: f32,
    vibrato_mode: VibratoMode,
    sculk_frequency: u4 = SCULK_SENSOR_FREQUENCY,

    pub fn distanceTo(self: HornWave, listener: Vec3) f32 {
        const dx = listener.x - self.origin.x;
        const dy = listener.y - self.origin.y;
        const dz = listener.z - self.origin.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    pub fn reaches(self: HornWave, listener: Vec3) bool {
        return self.distanceTo(listener) <= self.radius;
    }
};

pub const PlaybackState = struct {
    cooldown_ticks: u16 = 0,

    pub fn tick(self: *PlaybackState, ticks: u16) void {
        self.cooldown_ticks -|= ticks;
    }

    pub fn play(self: *PlaybackState, horn: CopperHorn, origin: Vec3, camera_pitch_degrees: f32, sneaking: bool) ?HornWave {
        if (self.cooldown_ticks > 0) return null;
        const register = registerForCameraPitch(camera_pitch_degrees);
        self.cooldown_ticks = HORN_COOLDOWN_TICKS;
        return .{
            .theme = horn.theme,
            .origin = origin,
            .pitch_register = register,
            .pitch_multiplier = register.multiplier(),
            .vibrato_mode = if (sneaking) .sneaking_vibrato else .steady,
        };
    }
};

fn playOnce(theme: GoatHornTheme, pitch: f32, sneaking: bool) HornWave {
    var state = PlaybackState{};
    return state.play(CopperHorn.craft(theme), .{ .x = 0, .y = 0, .z = 0 }, pitch, sneaking).?;
}

test "copper horn crafting accepts one Ponder horn and three ingots" {
    const recipe = CraftingRecipe.match(.{ .{ .goat_horn = .ponder }, .copper_ingot, .copper_ingot, .copper_ingot }).?;
    try std.testing.expectEqual(GoatHornTheme.ponder, recipe.theme);
}
test "crafting retains Sing theme" { try std.testing.expectEqual(GoatHornTheme.sing, CraftingRecipe.match(.{ .copper_ingot, .{ .goat_horn = .sing }, .copper_ingot, .copper_ingot }).?.theme); }
test "crafting retains Seek theme" { try std.testing.expectEqual(GoatHornTheme.seek, CraftingRecipe.match(.{ .copper_ingot, .copper_ingot, .{ .goat_horn = .seek }, .copper_ingot }).?.theme); }
test "crafting retains Feel theme" { try std.testing.expectEqual(GoatHornTheme.feel, CraftingRecipe.match(.{ .copper_ingot, .copper_ingot, .copper_ingot, .{ .goat_horn = .feel } }).?.theme); }
test "crafting retains Admire theme" { try std.testing.expectEqual(GoatHornTheme.admire, CraftingRecipe.match(.{ .{ .goat_horn = .admire }, .copper_ingot, .copper_ingot, .copper_ingot }).?.theme); }
test "crafting retains Call theme" { try std.testing.expectEqual(GoatHornTheme.call, CraftingRecipe.match(.{ .{ .goat_horn = .call }, .copper_ingot, .copper_ingot, .copper_ingot }).?.theme); }
test "crafting retains Yearn theme" { try std.testing.expectEqual(GoatHornTheme.yearn, CraftingRecipe.match(.{ .{ .goat_horn = .yearn }, .copper_ingot, .copper_ingot, .copper_ingot }).?.theme); }
test "crafting retains Dream theme" { try std.testing.expectEqual(GoatHornTheme.dream, CraftingRecipe.match(.{ .{ .goat_horn = .dream }, .copper_ingot, .copper_ingot, .copper_ingot }).?.theme); }
test "crafting rejects two goat horns" { try std.testing.expect(CraftingRecipe.match(.{ .{ .goat_horn = .ponder }, .{ .goat_horn = .sing }, .copper_ingot, .copper_ingot }) == null); }
test "crafting rejects two copper ingots" { try std.testing.expect(CraftingRecipe.match(.{ .{ .goat_horn = .ponder }, .copper_ingot, .copper_ingot, .empty }) == null); }
test "crafting rejects four copper ingots" { try std.testing.expect(CraftingRecipe.match(.{ .copper_ingot, .copper_ingot, .copper_ingot, .copper_ingot }) == null); }
test "crafting rejects an empty grid" { try std.testing.expect(CraftingRecipe.match(.{ .empty, .empty, .empty, .empty }) == null); }
test "crafting rejects a horn with an empty slot" { try std.testing.expect(CraftingRecipe.match(.{ .{ .goat_horn = .dream }, .copper_ingot, .empty, .copper_ingot }) == null); }
test "crafted horn stores the source theme" { try std.testing.expectEqual(GoatHornTheme.yearn, CopperHorn.craft(.yearn).theme); }
test "camera pitch at minus 30 degrees selects high register" { try std.testing.expectEqual(PitchRegister.high, registerForCameraPitch(-30)); }
test "camera pitch above minus 30 selects mid register" { try std.testing.expectEqual(PitchRegister.mid, registerForCameraPitch(-29.99)); }
test "camera pitch at zero selects mid register" { try std.testing.expectEqual(PitchRegister.mid, registerForCameraPitch(0)); }
test "camera pitch below plus 30 selects mid register" { try std.testing.expectEqual(PitchRegister.mid, registerForCameraPitch(29.99)); }
test "camera pitch at plus 30 degrees selects low register" { try std.testing.expectEqual(PitchRegister.low, registerForCameraPitch(30)); }
test "camera pitch looking far up selects high register" { try std.testing.expectEqual(PitchRegister.high, registerForCameraPitch(-90)); }
test "camera pitch looking far down selects low register" { try std.testing.expectEqual(PitchRegister.low, registerForCameraPitch(90)); }
test "high register pitch multiplier is soprano 1.33" { try std.testing.expectApproxEqAbs(@as(f32, 1.33), PitchRegister.high.multiplier(), 0.0001); }
test "mid register pitch multiplier is standard 1.0" { try std.testing.expectEqual(@as(f32, 1.0), PitchRegister.mid.multiplier()); }
test "low register pitch multiplier is bass 0.75" { try std.testing.expectEqual(@as(f32, 0.75), PitchRegister.low.multiplier()); }
test "sneaking enables alternate vibrato mode" { try std.testing.expectEqual(VibratoMode.sneaking_vibrato, playOnce(.ponder, 0, true).vibrato_mode); }
test "standing keeps steady timbre" { try std.testing.expectEqual(VibratoMode.steady, playOnce(.ponder, 0, false).vibrato_mode); }
test "sneaking does not change pitch register" { try std.testing.expectEqual(PitchRegister.high, playOnce(.ponder, -45, true).pitch_register); }
test "sound reaches listener at the 256 meter boundary" { try std.testing.expect(playOnce(.call, 0, false).reaches(.{ .x = 256, .y = 0, .z = 0 })); }
test "sound does not reach listener beyond 256 meters" { try std.testing.expect(!playOnce(.call, 0, false).reaches(.{ .x = 256.01, .y = 0, .z = 0 })); }
test "sound radius is exactly 256 meters" { try std.testing.expectEqual(@as(f32, 256), ACOUSTIC_RADIUS); }
test "sound propagation includes vertical distance" { try std.testing.expect(!playOnce(.call, 0, false).reaches(.{ .x = 0, .y = 257, .z = 0 })); }
test "playback applies 140 tick cooldown" { var state = PlaybackState{}; _ = state.play(CopperHorn.craft(.feel), .{ .x = 0, .y = 0, .z = 0 }, 0, false); try std.testing.expectEqual(@as(u16, 140), state.cooldown_ticks); }
test "cooldown blocks immediate retrigger" { var state = PlaybackState{}; _ = state.play(CopperHorn.craft(.feel), .{ .x = 0, .y = 0, .z = 0 }, 0, false); try std.testing.expect(state.play(CopperHorn.craft(.feel), .{ .x = 0, .y = 0, .z = 0 }, 0, false) == null); }
test "cooldown remains after 139 ticks" { var state = PlaybackState{ .cooldown_ticks = 140 }; state.tick(139); try std.testing.expectEqual(@as(u16, 1), state.cooldown_ticks); }
test "cooldown expires after 140 ticks" { var state = PlaybackState{ .cooldown_ticks = 140 }; state.tick(140); try std.testing.expectEqual(@as(u16, 0), state.cooldown_ticks); }
test "cooldown tick saturates at zero" { var state = PlaybackState{ .cooldown_ticks = 10 }; state.tick(20); try std.testing.expectEqual(@as(u16, 0), state.cooldown_ticks); }
test "playback emits frequency ten for sculk sensor activation" { try std.testing.expectEqual(@as(u4, 10), playOnce(.admire, 0, false).sculk_frequency); }
test "playback carries original melodic theme into wave" { try std.testing.expectEqual(GoatHornTheme.dream, playOnce(.dream, 0, false).theme); }
