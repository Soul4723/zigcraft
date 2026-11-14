const std = @import("std");

pub const hoglin_max_health: f32 = 40.0;
pub const hoglin_porkchop_min: u8 = 2;
pub const hoglin_porkchop_max: u8 = 4;
pub const hoglin_leather_min: u8 = 0;
pub const hoglin_leather_max: u8 = 1;
pub const hoglin_fungus_repulsion_radius: f32 = 7.0;
pub const hoglin_zombification_duration_seconds: f32 = 15.0;
pub const hoglin_zombification_ticks: u32 = 300;
pub const hoglin_tusk_launch_velocity: f32 = 6.5;

pub const MAX_HEALTH: f32 = 40.0;
pub const BABY_MAX_HEALTH: f32 = 20.0;
pub const REPELLENT_RADIUS: f32 = 7.0;
pub const FLEE_SPEED: f32 = 4.5;
pub const VERTICAL_TOSS_VELOCITY: f32 = 7.0;
pub const BABY_MATURATION_TICKS: u32 = 24_000;
pub const ZOMBIFICATION_TICKS: u32 = 300;
pub const ZOMBIFICATION_SECONDS: f32 = 15.0;

pub const HoglinState = struct {
    health: f32 = hoglin_max_health,
    zombify_timer_seconds: f32 = 0.0,
    is_zoglin: bool = false,

    pub fn init() HoglinState {
        return .{};
    }

    /// Pork chops are cooked when the Hoglin dies while burning. `pork_roll`
    /// and `leather_roll` provide deterministic inputs from the caller's RNG.
    pub fn deathDrops(_: HoglinState, is_burning: bool, pork_roll: u8, leather_roll: u8) HoglinDrops {
        return .{
            .porkchop_item = if (is_burning) "Cooked Porkchop" else "Raw Porkchop",
            .porkchop_count = hoglin_porkchop_min + @min(pork_roll, hoglin_porkchop_max - hoglin_porkchop_min),
            .leather_count = @min(leather_roll, hoglin_leather_max),
        };
    }
};

pub const HoglinDrops = struct {
    porkchop_item: []const u8,
    porkchop_count: u8,
    leather_count: u8,
};

/// `block_is_warped_fungus_or_portal_or_anchor` is true for a placed block,
/// including potted warped fungus; the caller supplies the nearest distance.
pub fn isHoglinRepelledByBlock(
    is_zoglin: bool,
    block_is_warped_fungus_or_portal_or_anchor: bool,
    dist_blocks: f32,
) bool {
    return !is_zoglin and block_is_warped_fungus_or_portal_or_anchor and
        dist_blocks >= 0.0 and dist_blocks <= hoglin_fungus_repulsion_radius;
}

pub const TuskFlingImpulse = struct {
    vx: f32,
    vy: f32,
    vz: f32,
    ignores_netherite_knockback_resistance_for_vy: bool,
};

/// Adult tusks launch targets upward. The vertical impulse is applied through
/// Netherite knockback resistance; babies deliver a weaker, non-launching hit.
pub fn computeTuskFlingImpulse(attacker_dir_xz: [2]f32, target_is_baby: bool) TuskFlingImpulse {
    const scale: f32 = if (target_is_baby) 0.5 else 1.0;
    return .{
        .vx = attacker_dir_xz[0] * scale,
        .vy = if (target_is_baby) 2.0 else hoglin_tusk_launch_velocity,
        .vz = attacker_dir_xz[1] * scale,
        .ignores_netherite_knockback_resistance_for_vy = !target_is_baby,
    };
}

/// Returns true on the transformation tick. The timer is frozen outside the
/// Overworld/End and clamped to the 15-second threshold.
pub fn tickHoglinOverworldZombification(in_overworld_or_end: bool, zombify_timer_seconds: *f32, dt: f32) bool {
    if (!in_overworld_or_end or dt <= 0.0) return false;
    zombify_timer_seconds.* = @min(
        hoglin_zombification_duration_seconds,
        zombify_timer_seconds.* + dt,
    );
    return zombify_timer_seconds.* >= hoglin_zombification_duration_seconds;
}

/// Zoglins attack every target except their own kind and Creepers.
pub fn shouldZoglinAttackEntity(entity_is_zoglin: bool, entity_is_creeper: bool, entity_is_ghast: bool) bool {
    _ = entity_is_ghast; // Ghasts are living mobs and are not an exception.
    return !entity_is_zoglin and !entity_is_creeper;
}

/// Hoglins breed only when fed Crimson Fungus; Zoglins cannot be bred.
pub fn canBreedHoglin(is_zoglin: bool, fed_crimson_fungus: bool) bool {
    return !is_zoglin and fed_crimson_fungus;
}

pub const Difficulty = enum { easy, normal, hard };

pub fn attackDamage(difficulty: Difficulty) f32 {
    return switch (difficulty) {
        .easy => 3.0,
        .normal => 6.0,
        .hard => 9.0,
    };
}

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn distance(self: Vec3, other: Vec3) f32 {
        const dx = self.x - other.x;
        const dy = self.y - other.y;
        const dz = self.z - other.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

pub const Repellent = enum {
    warped_fungus,
    potted_warped_fungus,
    warped_roots,
    active_nether_portal,
    active_respawn_anchor,
    other,

    pub fn repels(self: Repellent) bool {
        return self != .other;
    }
};

pub const RepellentResult = struct {
    detected: bool = false,
    is_fleeing: bool = false,
    direction: Vec3 = .{},
    velocity: Vec3 = .{},
};

pub fn detectRepellent(position: Vec3, source_position: Vec3, source: Repellent) RepellentResult {
    const delta = Vec3{
        .x = position.x - source_position.x,
        .y = position.y - source_position.y,
        .z = position.z - source_position.z,
    };
    const distance = position.distance(source_position);
    if (!source.repels() or distance > REPELLENT_RADIUS) return .{};
    if (distance == 0.0) return .{ .detected = true, .is_fleeing = true };
    const direction = Vec3{ .x = delta.x / distance, .y = delta.y / distance, .z = delta.z / distance };
    return .{
        .detected = true,
        .is_fleeing = true,
        .direction = direction,
        .velocity = .{ .x = direction.x * FLEE_SPEED, .y = direction.y * FLEE_SPEED, .z = direction.z * FLEE_SPEED },
    };
}

pub const Knockback = struct { vx: f32, vy: f32, vz: f32 };

/// `horizontal_away` is normalized by the caller and points from the attacker to its target.
pub fn computeAttackKnockback(horizontal_away: [2]f32, horizontal_speed: f32) Knockback {
    return .{
        .vx = horizontal_away[0] * horizontal_speed,
        .vy = VERTICAL_TOSS_VELOCITY,
        .vz = horizontal_away[1] * horizontal_speed,
    };
}

pub const Drops = struct {
    raw_porkchops: u8,
    leather: u8,
};

pub fn drops(pork_roll: u8, leather_roll: u8) Drops {
    return .{ .raw_porkchops = @as(u8, 2) + @min(pork_roll, @as(u8, 2)), .leather = @min(leather_roll, @as(u8, 1)) };
}

pub const Dimension = enum { nether, overworld, the_end };

pub const Hoglin = struct {
    health: f32 = MAX_HEALTH,
    is_baby: bool = false,
    scale: f32 = 1.0,
    is_love_mode: bool = false,
    is_fleeing: bool = false,
    flee_velocity: Vec3 = .{},
    is_shivering: bool = false,
    zombification_ticks: u32 = 0,
    is_zoglin: bool = false,
    is_undead: bool = false,
    immune_to_fire: bool = false,
    immune_to_lava: bool = false,
    maturation_ticks_remaining: u32 = 0,

    pub fn init() Hoglin {
        return .{};
    }

    pub fn baby() Hoglin {
        return .{ .health = BABY_MAX_HEALTH, .is_baby = true, .scale = 0.5, .maturation_ticks_remaining = BABY_MATURATION_TICKS };
    }

    pub fn updateRepellent(self: *Hoglin, position: Vec3, source_position: Vec3, source: Repellent) RepellentResult {
        if (self.is_zoglin) {
            self.is_fleeing = false;
            self.flee_velocity = .{};
            return .{};
        }
        const result = detectRepellent(position, source_position, source);
        self.is_fleeing = result.is_fleeing;
        self.flee_velocity = result.velocity;
        return result;
    }

    pub fn feedCrimsonFungus(self: *Hoglin) void {
        if (self.is_baby) {
            self.maturation_ticks_remaining -|= BABY_MATURATION_TICKS / 10;
        } else if (!self.is_zoglin) {
            self.is_love_mode = true;
        }
    }

    pub fn mature(self: *Hoglin, ticks: u32) bool {
        if (!self.is_baby) return false;
        self.maturation_ticks_remaining -|= ticks;
        if (self.maturation_ticks_remaining == 0) {
            self.is_baby = false;
            self.scale = 1.0;
            self.health = MAX_HEALTH;
            return true;
        }
        return false;
    }

    pub fn tickDimension(self: *Hoglin, dimension: Dimension, ticks: u32) bool {
        if (self.is_zoglin or dimension == .nether or ticks == 0) return false;
        self.is_shivering = true;
        const previous = self.zombification_ticks;
        self.zombification_ticks = @min(ZOMBIFICATION_TICKS, self.zombification_ticks +| ticks);
        if (self.zombification_ticks < ZOMBIFICATION_TICKS) return false;
        self.is_zoglin = true;
        self.is_undead = true;
        self.immune_to_fire = true;
        self.immune_to_lava = true;
        self.is_shivering = false;
        return previous < ZOMBIFICATION_TICKS;
    }

    pub fn attacks(self: Hoglin, target_is_zoglin: bool, target_is_creeper: bool) bool {
        _ = target_is_zoglin;
        _ = target_is_creeper;
        return self.is_zoglin;
    }
};

pub const BreedingResult = struct { first_love_mode: bool, second_love_mode: bool, baby: ?Hoglin };

/// Both adults must be fed Crimson Fungus before breeding can create a baby.
pub fn feedBreedingPair(first: *Hoglin, second: *Hoglin) BreedingResult {
    first.feedCrimsonFungus();
    second.feedCrimsonFungus();
    const can_pair = !first.is_baby and !second.is_baby and !first.is_zoglin and !second.is_zoglin and first.is_love_mode and second.is_love_mode;
    const first_entered_love = first.is_love_mode;
    const second_entered_love = second.is_love_mode;
    if (can_pair) {
        first.is_love_mode = false;
        second.is_love_mode = false;
    }
    return .{
        .first_love_mode = first_entered_love,
        .second_love_mode = second_entered_love,
        .baby = if (can_pair) Hoglin.baby() else null,
    };
}

test "Hoglin has forty health and normal death drops raw pork" {
    const hoglin = HoglinState.init();
    try std.testing.expectEqual(@as(f32, 40.0), hoglin.health);
    const d = hoglin.deathDrops(false, 0, 0);
    try std.testing.expectEqualStrings("Raw Porkchop", d.porkchop_item);
    try std.testing.expectEqual(@as(u8, 2), d.porkchop_count);
}

test "Hoglin pork drops span two through four" {
    const hoglin = HoglinState.init();
    try std.testing.expectEqual(@as(u8, 2), hoglin.deathDrops(false, 0, 0).porkchop_count);
    try std.testing.expectEqual(@as(u8, 3), hoglin.deathDrops(false, 1, 0).porkchop_count);
    try std.testing.expectEqual(@as(u8, 4), hoglin.deathDrops(false, 2, 0).porkchop_count);
    try std.testing.expectEqual(@as(u8, 4), hoglin.deathDrops(false, 255, 0).porkchop_count);
}

test "burning Hoglin drops cooked porkchops" {
    const d = HoglinState.init().deathDrops(true, 2, 0);
    try std.testing.expectEqualStrings("Cooked Porkchop", d.porkchop_item);
    try std.testing.expectEqual(@as(u8, 4), d.porkchop_count);
}

test "Hoglin leather drop is zero or one" {
    const hoglin = HoglinState.init();
    try std.testing.expectEqual(@as(u8, 0), hoglin.deathDrops(false, 0, 0).leather_count);
    try std.testing.expectEqual(@as(u8, 1), hoglin.deathDrops(false, 0, 1).leather_count);
    try std.testing.expectEqual(@as(u8, 1), hoglin.deathDrops(false, 0, 255).leather_count);
}

test "Hoglin flees warped fungus at seven blocks including boundary" {
    try std.testing.expect(isHoglinRepelledByBlock(false, true, 0.0));
    try std.testing.expect(isHoglinRepelledByBlock(false, true, 7.0));
    try std.testing.expect(!isHoglinRepelledByBlock(false, true, 7.01));
}

test "Hoglin flees portal blocks within seven blocks" {
    try std.testing.expect(isHoglinRepelledByBlock(false, true, 6.5));
}

test "Hoglin flees respawn anchors within seven blocks" {
    try std.testing.expect(isHoglinRepelledByBlock(false, true, 1.0));
}

test "Hoglin is not repelled beyond range or by unrelated blocks" {
    try std.testing.expect(!isHoglinRepelledByBlock(false, true, 7.1));
    try std.testing.expect(!isHoglinRepelledByBlock(false, false, 1.0));
    try std.testing.expect(!isHoglinRepelledByBlock(false, true, -1.0));
}

test "Zoglins ignore warped fungus and other repellent blocks" {
    try std.testing.expect(!isHoglinRepelledByBlock(true, true, 0.0));
}

test "adult tusk fling launches upward through Netherite resistance" {
    const impulse = computeTuskFlingImpulse(.{ 1.0, 0.0 }, false);
    try std.testing.expectEqual(@as(f32, 1.0), impulse.vx);
    try std.testing.expectEqual(@as(f32, 6.5), impulse.vy);
    try std.testing.expectEqual(@as(f32, 0.0), impulse.vz);
    try std.testing.expect(impulse.ignores_netherite_knockback_resistance_for_vy);
}

test "baby targets receive a weaker tusk impulse" {
    const impulse = computeTuskFlingImpulse(.{ 0.0, 1.0 }, true);
    try std.testing.expectEqual(@as(f32, 0.5), impulse.vz);
    try std.testing.expectEqual(@as(f32, 2.0), impulse.vy);
    try std.testing.expect(!impulse.ignores_netherite_knockback_resistance_for_vy);
}

test "Overworld zombification takes exactly fifteen seconds" {
    var timer: f32 = 0.0;
    try std.testing.expect(!tickHoglinOverworldZombification(true, &timer, 14.9));
    try std.testing.expect(!tickHoglinOverworldZombification(true, &timer, 0.09));
    try std.testing.expect(tickHoglinOverworldZombification(true, &timer, 0.01));
    try std.testing.expectEqual(@as(f32, 15.0), timer);
    try std.testing.expectEqual(@as(u32, 300), hoglin_zombification_ticks);
}

test "Nether timer is frozen and nonpositive delta does not advance" {
    var timer: f32 = 3.0;
    try std.testing.expect(!tickHoglinOverworldZombification(false, &timer, 5.0));
    try std.testing.expect(!tickHoglinOverworldZombification(true, &timer, 0.0));
    try std.testing.expectEqual(@as(f32, 3.0), timer);
}

test "Zoglins attack piglins, skeletons, zombies, golems and ghasts" {
    try std.testing.expect(shouldZoglinAttackEntity(false, false, false));
    try std.testing.expect(shouldZoglinAttackEntity(false, false, true));
}

test "Zoglins exclude other Zoglins and Creepers" {
    try std.testing.expect(!shouldZoglinAttackEntity(true, false, false));
    try std.testing.expect(!shouldZoglinAttackEntity(false, true, false));
}

test "Crimson Fungus breeds Hoglins but not Zoglins" {
    try std.testing.expect(canBreedHoglin(false, true));
    try std.testing.expect(!canBreedHoglin(false, false));
    try std.testing.expect(!canBreedHoglin(true, true));
}

test "adult hoglin starts with forty HP" {
    try std.testing.expectEqual(@as(f32, 40), Hoglin.init().health);
}
test "baby starts with twenty HP and half scale" {
    const h = Hoglin.baby();
    try std.testing.expectEqual(@as(f32, 20), h.health);
    try std.testing.expectEqual(@as(f32, 0.5), h.scale);
    try std.testing.expect(h.is_baby);
}
test "easy attack damage is three HP" {
    try std.testing.expectEqual(@as(f32, 3), attackDamage(.easy));
}
test "normal attack damage is six HP" {
    try std.testing.expectEqual(@as(f32, 6), attackDamage(.normal));
}
test "hard attack damage is nine HP" {
    try std.testing.expectEqual(@as(f32, 9), attackDamage(.hard));
}
test "adult attack has seven meters per second vertical toss" {
    const k = computeAttackKnockback(.{ 1, 0 }, 2);
    try std.testing.expectEqual(@as(f32, 7), k.vy);
    try std.testing.expectEqual(@as(f32, 2), k.vx);
}
test "horizontal toss follows target-away direction" {
    const k = computeAttackKnockback(.{ 0, -1 }, 3.5);
    try std.testing.expectEqual(@as(f32, 0), k.vx);
    try std.testing.expectEqual(@as(f32, -3.5), k.vz);
}
test "zero horizontal impulse retains vertical toss" {
    const k = computeAttackKnockback(.{ 0, 0 }, 0);
    try std.testing.expectEqual(@as(f32, 7), k.vy);
    try std.testing.expectEqual(@as(f32, 0), k.vx);
}
test "warped fungus repels at seven meter boundary" {
    try std.testing.expect(detectRepellent(.{ .x = 7 }, .{}, .warped_fungus).detected);
}
test "warped fungus outside seven meters does not repel" {
    try std.testing.expect(!detectRepellent(.{ .x = 7.01 }, .{}, .warped_fungus).detected);
}
test "potted warped fungus repels hoglin" {
    try std.testing.expect(detectRepellent(.{ .z = 1 }, .{}, .potted_warped_fungus).detected);
}
test "warped roots repel hoglin" {
    try std.testing.expect(detectRepellent(.{ .z = 2 }, .{}, .warped_roots).detected);
}
test "active portal repels hoglin" {
    try std.testing.expect(detectRepellent(.{ .z = 3 }, .{}, .active_nether_portal).detected);
}
test "active respawn anchor repels hoglin" {
    try std.testing.expect(detectRepellent(.{ .z = 4 }, .{}, .active_respawn_anchor).detected);
}
test "inactive or unrelated blocks do not repel" {
    try std.testing.expect(!detectRepellent(.{ .x = 1 }, .{}, .other).detected);
}
test "repellent distance is three dimensional Euclidean distance" {
    try std.testing.expect(!detectRepellent(.{ .x = 5, .y = 5 }, .{}, .warped_fungus).detected);
}
test "flee vector points away from source" {
    const r = detectRepellent(.{ .x = 2 }, .{}, .warped_fungus);
    try std.testing.expectEqual(@as(f32, 1), r.direction.x);
}
test "flee velocity uses sprint speed four point five" {
    const r = detectRepellent(.{ .x = -1 }, .{}, .warped_roots);
    try std.testing.expectEqual(@as(f32, -4.5), r.velocity.x);
}
test "flee vector normalizes diagonal displacement" {
    const r = detectRepellent(.{ .x = 3, .z = 4 }, .{}, .active_nether_portal);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), r.direction.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), r.direction.z, 0.0001);
}
test "hoglin records immediate fleeing state" {
    var h = Hoglin.init();
    _ = h.updateRepellent(.{ .x = 1 }, .{}, .warped_fungus);
    try std.testing.expect(h.is_fleeing);
}
test "hoglin stops fleeing when repellent leaves range" {
    var h = Hoglin.init();
    _ = h.updateRepellent(.{ .x = 1 }, .{}, .warped_fungus);
    _ = h.updateRepellent(.{ .x = 9 }, .{}, .warped_fungus);
    try std.testing.expect(!h.is_fleeing);
}
test "both fed adults enter love mode and spawn baby" {
    var a = Hoglin.init();
    var b = Hoglin.init();
    const result = feedBreedingPair(&a, &b);
    try std.testing.expect(result.first_love_mode and result.second_love_mode);
    try std.testing.expect(result.baby.?.is_baby);
}
test "successful breeding consumes adult love mode" {
    var a = Hoglin.init();
    var b = Hoglin.init();
    _ = feedBreedingPair(&a, &b);
    try std.testing.expect(!a.is_love_mode and !b.is_love_mode);
}
test "baby breeding result has half scale and twenty HP" {
    var a = Hoglin.init();
    var b = Hoglin.init();
    const child = feedBreedingPair(&a, &b).baby.?;
    try std.testing.expectEqual(@as(f32, 0.5), child.scale);
    try std.testing.expectEqual(@as(f32, 20), child.health);
}
test "baby has twenty four thousand maturation ticks" {
    try std.testing.expectEqual(@as(u32, 24_000), Hoglin.baby().maturation_ticks_remaining);
}
test "each baby fungus feed accelerates maturation by ten percent" {
    var h = Hoglin.baby();
    h.feedCrimsonFungus();
    try std.testing.expectEqual(@as(u32, 21_600), h.maturation_ticks_remaining);
}
test "baby matures after full timer and becomes adult" {
    var h = Hoglin.baby();
    try std.testing.expect(h.mature(24_000));
    try std.testing.expect(!h.is_baby);
    try std.testing.expectEqual(@as(f32, 1), h.scale);
    try std.testing.expectEqual(@as(f32, 40), h.health);
}
test "maturation partial tick countdown remains baby" {
    var h = Hoglin.baby();
    try std.testing.expect(!h.mature(23_999));
    try std.testing.expect(h.is_baby);
}
test "adult Crimson Fungus feeding enters love mode" {
    var h = Hoglin.init();
    h.feedCrimsonFungus();
    try std.testing.expect(h.is_love_mode);
}
test "Hoglin entering Overworld begins shivering" {
    var h = Hoglin.init();
    try std.testing.expect(!h.tickDimension(.overworld, 1));
    try std.testing.expect(h.is_shivering);
}
test "Hoglin entering End begins shivering" {
    var h = Hoglin.init();
    try std.testing.expect(!h.tickDimension(.the_end, 1));
    try std.testing.expect(h.is_shivering);
}
test "Nether ticks do not advance zombification" {
    var h = Hoglin.init();
    try std.testing.expect(!h.tickDimension(.nether, 300));
    try std.testing.expectEqual(@as(u32, 0), h.zombification_ticks);
}
test "Overworld conversion occurs at exactly three hundred ticks" {
    var h = Hoglin.init();
    try std.testing.expect(!h.tickDimension(.overworld, 299));
    try std.testing.expect(h.tickDimension(.overworld, 1));
    try std.testing.expect(h.is_zoglin);
}
test "End conversion occurs at three hundred ticks" {
    var h = Hoglin.init();
    try std.testing.expect(h.tickDimension(.the_end, 300));
    try std.testing.expect(h.is_zoglin);
}
test "conversion marks zoglin undead and fire immune" {
    var h = Hoglin.init();
    _ = h.tickDimension(.overworld, 300);
    try std.testing.expect(h.is_undead and h.immune_to_fire and h.immune_to_lava);
}
test "conversion transformation event fires once" {
    var h = Hoglin.init();
    try std.testing.expect(h.tickDimension(.overworld, 300));
    try std.testing.expect(!h.tickDimension(.overworld, 1));
}
test "zoglin attacks players and ordinary mobs indiscriminately" {
    var h = Hoglin.init();
    _ = h.tickDimension(.overworld, 300);
    try std.testing.expect(h.attacks(false, false));
}
test "zoglin attacks other zoglins indiscriminately" {
    var h = Hoglin.init();
    _ = h.tickDimension(.overworld, 300);
    try std.testing.expect(h.attacks(true, false));
}
test "zoglin attacks creepers indiscriminately" {
    var h = Hoglin.init();
    _ = h.tickDimension(.overworld, 300);
    try std.testing.expect(h.attacks(false, true));
}
test "hoglin drops raw porkchops in range" {
    const d = drops(0, 0);
    try std.testing.expectEqual(@as(u8, 2), d.raw_porkchops);
}
test "porkchop drops cap at four" {
    try std.testing.expectEqual(@as(u8, 4), drops(255, 0).raw_porkchops);
}
test "leather drops range from zero to one" {
    try std.testing.expectEqual(@as(u8, 0), drops(0, 0).leather);
    try std.testing.expectEqual(@as(u8, 1), drops(0, 1).leather);
}
