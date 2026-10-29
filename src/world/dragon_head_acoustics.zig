const std = @import("std");

pub const EquipmentSlot = enum { head, chest, legs, feet };
pub const ItemType = enum { dragon_head };

pub fn equipmentSlot(item: ItemType) EquipmentSlot {
    return switch (item) {
        .dragon_head => .head,
    };
}

pub const DRAGON_HEAD_EYE_EMISSIVE: f32 = 0.25;
pub const JAW_ANIMATION_CYCLE_TICKS: u8 = 20;

pub const DragonHeadAnimation = struct {
    animation_tick: u8 = 0,
    is_jaw_snapping: bool = false,
    jaw_hinge_angle_degrees: f32 = 0.0,

    /// A powered mounted head, or a worn head while its wearer walks, snaps its jaw.
    pub fn tick(self: *DragonHeadAnimation, redstone_powered: bool, worn_while_walking: bool) void {
        self.is_jaw_snapping = redstone_powered or worn_while_walking;
        if (!self.is_jaw_snapping) {
            self.animation_tick = 0;
            self.jaw_hinge_angle_degrees = 0.0;
            return;
        }

        self.animation_tick = (self.animation_tick + 1) % JAW_ANIMATION_CYCLE_TICKS;
        const cycle_ticks: f32 = @floatFromInt(JAW_ANIMATION_CYCLE_TICKS);
        const phase: f32 = @as(f32, @floatFromInt(self.animation_tick)) * (2.0 * std.math.pi / cycle_ticks);
        self.jaw_hinge_angle_degrees = 22.5 * (1.0 - @cos(phase));
    }
};

pub const MobHeadKind = enum { skeleton, wither_skeleton, zombie, creeper, piglin, dragon };

pub const SoundEffect = enum {
    default_note_block_instrument,
    skeleton_ambient,
    wither_skeleton_ambient,
    zombie_ambient,
    creeper_primed,
    piglin_ambient,
    ender_dragon_growl,
};

/// A skull directly above a Note Block replaces its normal instrument sound.
pub fn resolveNoteBlockSound(head_on_top: ?MobHeadKind, default_instrument: SoundEffect) SoundEffect {
    const head = head_on_top orelse return default_instrument;
    return switch (head) {
        .skeleton => .skeleton_ambient,
        .wither_skeleton => .wither_skeleton_ambient,
        .zombie => .zombie_ambient,
        .creeper => .creeper_primed,
        .piglin => .piglin_ambient,
        .dragon => .ender_dragon_growl,
    };
}

pub const BowMountOrientation = enum {
    vertical_forward,
    vertical_left,
    vertical_right,
    angled_forward,
    angled_left,
    angled_right,
};

pub const FigureheadMount = struct {
    orientation: BowMountOrientation,
    is_mounted_figurehead: bool = true,
};

pub fn mountFigurehead(orientation: BowMountOrientation) FigureheadMount {
    return .{ .orientation = orientation };
}

test "dragon head is equippable in the head slot" {
    try std.testing.expectEqual(EquipmentSlot.head, equipmentSlot(.dragon_head));
}

test "dragon head eye emissive intensity is one quarter" {
    try std.testing.expectEqual(@as(f32, 0.25), DRAGON_HEAD_EYE_EMISSIVE);
}

test "jaw cycle is twenty ticks" {
    try std.testing.expectEqual(@as(u8, 20), JAW_ANIMATION_CYCLE_TICKS);
}

test "redstone power starts jaw snapping" {
    var animation = DragonHeadAnimation{};
    animation.tick(true, false);
    try std.testing.expect(animation.is_jaw_snapping);
}

test "redstone jaw animation advances one tick" {
    var animation = DragonHeadAnimation{};
    animation.tick(true, false);
    try std.testing.expectEqual(@as(u8, 1), animation.animation_tick);
}

test "redstone jaw animation cycles continuously" {
    var animation = DragonHeadAnimation{};
    for (0..40) |_| animation.tick(true, false);
    try std.testing.expect(animation.is_jaw_snapping);
    try std.testing.expectEqual(@as(u8, 0), animation.animation_tick);
}

test "redstone jaw hinge moves during animation" {
    var animation = DragonHeadAnimation{};
    animation.tick(true, false);
    try std.testing.expect(animation.jaw_hinge_angle_degrees > 0.0);
}

test "walking while wearing dragon head starts jaw snapping" {
    var animation = DragonHeadAnimation{};
    animation.tick(false, true);
    try std.testing.expect(animation.is_jaw_snapping);
}

test "walking wear advances the jaw animation" {
    var animation = DragonHeadAnimation{};
    animation.tick(false, true);
    try std.testing.expectEqual(@as(u8, 1), animation.animation_tick);
}

test "not powered and not walking leaves jaw still" {
    var animation = DragonHeadAnimation{};
    animation.tick(false, false);
    try std.testing.expect(!animation.is_jaw_snapping);
    try std.testing.expectEqual(@as(u8, 0), animation.animation_tick);
}

test "stopping power resets jaw hinge to rest" {
    var animation = DragonHeadAnimation{};
    animation.tick(true, false);
    animation.tick(false, false);
    try std.testing.expectEqual(@as(f32, 0.0), animation.jaw_hinge_angle_degrees);
}

test "either redstone or walking activates snapping" {
    var animation = DragonHeadAnimation{};
    animation.tick(true, false);
    try std.testing.expect(animation.is_jaw_snapping);
    animation.tick(false, true);
    try std.testing.expect(animation.is_jaw_snapping);
}

test "skeleton skull selects skeleton ambient sound" {
    try std.testing.expectEqual(SoundEffect.skeleton_ambient, resolveNoteBlockSound(.skeleton, .default_note_block_instrument));
}

test "wither skeleton skull selects wither skeleton ambient sound" {
    try std.testing.expectEqual(SoundEffect.wither_skeleton_ambient, resolveNoteBlockSound(.wither_skeleton, .default_note_block_instrument));
}

test "zombie head selects zombie ambient sound" {
    try std.testing.expectEqual(SoundEffect.zombie_ambient, resolveNoteBlockSound(.zombie, .default_note_block_instrument));
}

test "creeper head selects priming hiss" {
    try std.testing.expectEqual(SoundEffect.creeper_primed, resolveNoteBlockSound(.creeper, .default_note_block_instrument));
}

test "piglin head selects piglin ambient sound" {
    try std.testing.expectEqual(SoundEffect.piglin_ambient, resolveNoteBlockSound(.piglin, .default_note_block_instrument));
}

test "dragon head selects Ender Dragon growl" {
    try std.testing.expectEqual(SoundEffect.ender_dragon_growl, resolveNoteBlockSound(.dragon, .default_note_block_instrument));
}

test "non skull note block preserves harp default" {
    try std.testing.expectEqual(SoundEffect.default_note_block_instrument, resolveNoteBlockSound(null, .default_note_block_instrument));
}

test "non skull note block preserves any selected default instrument" {
    try std.testing.expectEqual(SoundEffect.piglin_ambient, resolveNoteBlockSound(null, .piglin_ambient));
}

test "figurehead mounts on vertical bow face" {
    const mount = mountFigurehead(.vertical_forward);
    try std.testing.expect(mount.is_mounted_figurehead);
    try std.testing.expectEqual(BowMountOrientation.vertical_forward, mount.orientation);
}

test "figurehead mounts on angled bow face" {
    const mount = mountFigurehead(.angled_forward);
    try std.testing.expect(mount.is_mounted_figurehead);
    try std.testing.expectEqual(BowMountOrientation.angled_forward, mount.orientation);
}

test "figurehead retains left vertical orientation" {
    try std.testing.expectEqual(BowMountOrientation.vertical_left, mountFigurehead(.vertical_left).orientation);
}

test "figurehead retains right vertical orientation" {
    try std.testing.expectEqual(BowMountOrientation.vertical_right, mountFigurehead(.vertical_right).orientation);
}

test "figurehead retains left angled orientation" {
    try std.testing.expectEqual(BowMountOrientation.angled_left, mountFigurehead(.angled_left).orientation);
}

test "figurehead retains right angled orientation" {
    try std.testing.expectEqual(BowMountOrientation.angled_right, mountFigurehead(.angled_right).orientation);
}

test "each mob skull chooses a distinct acoustic sound" {
    const heads = [_]MobHeadKind{ .skeleton, .wither_skeleton, .zombie, .creeper, .piglin, .dragon };
    const sounds = [_]SoundEffect{ .skeleton_ambient, .wither_skeleton_ambient, .zombie_ambient, .creeper_primed, .piglin_ambient, .ender_dragon_growl };
    for (heads, sounds) |head, sound| {
        try std.testing.expectEqual(sound, resolveNoteBlockSound(head, .default_note_block_instrument));
    }
}
