const std = @import("std");

pub const threat_radius: f32 = 7.0;
pub const unthreatened_ticks_to_unroll: u16 = 200;
pub const natural_scute_interval_ticks: u32 = 24_000;
pub const brush_durability_cost: u16 = 16;
pub const wolf_armor_durability: u16 = 64;
pub const scute_repair_amount: u16 = 8;

pub const ArmadilloState = enum { standing, rolling_up, curled_ball, unrolling };
pub const ThreatKind = enum {
    sprinting_player,
    zombie,
    husk,
    drowned,
    skeleton,
    spider,
    cave_spider,
    environmental_damage,
    other,
};
pub const DamageKind = enum { weak, blast, melee, other };
pub const Sound = enum { shell_clack, armor_shatter };

pub const Threat = struct {
    kind: ThreatKind,
    distance: f32 = 0,

    pub fn isRelevant(self: Threat) bool {
        if (self.kind == .environmental_damage) return true;
        return self.distance >= 0 and self.distance <= threat_radius and self.kind != .other;
    }
};

pub fn distance3d(ax: f32, ay: f32, az: f32, bx: f32, by: f32, bz: f32) f32 {
    const dx = ax - bx;
    const dy = ay - by;
    const dz = az - bz;
    return @sqrt(dx * dx + dy * dy + dz * dz);
}

pub fn isThreatWithinRadius(distance: f32) bool {
    return distance >= 0 and distance <= threat_radius;
}

pub const TickResult = struct { sound: ?Sound = null };

pub const Armadillo = struct {
    state: ArmadilloState = .standing,
    state_ticks: u8 = 0,
    threat_clear_ticks: u16 = 0,
    ticks_since_scute_drop: u32 = 0,

    pub fn tick(self: *Armadillo, threats: []const Threat) TickResult {
        var threatened = false;
        for (threats) |threat| {
            if (threat.isRelevant()) {
                threatened = true;
                break;
            }
        }

        var began_rolling = false;
        if (threatened) {
            self.threat_clear_ticks = 0;
            if (self.state == .standing or self.state == .unrolling) {
                self.state = .rolling_up;
                self.state_ticks = 0;
                began_rolling = true;
            }
        } else if (self.state == .curled_ball) {
            self.threat_clear_ticks +|= 1;
        }

        self.state_ticks +|= 1;
        switch (self.state) {
            .standing => {},
            .rolling_up => {
                if (began_rolling) return .{};
                if (self.state_ticks >= 1) {
                    self.state = .curled_ball;
                    self.state_ticks = 0;
                    return .{ .sound = .shell_clack };
                }
            },
            .curled_ball => {
                if (self.threat_clear_ticks >= unthreatened_ticks_to_unroll) {
                    self.state = .unrolling;
                    self.state_ticks = 0;
                }
            },
            .unrolling => {
                if (self.state_ticks >= 1) {
                    self.state = .standing;
                    self.state_ticks = 0;
                }
            },
        }
        return .{};
    }

    pub fn applyDamage(self: *Armadillo, amount: f32, kind: DamageKind) f32 {
        if (self.state != .curled_ball) return amount;
        return switch (kind) {
            .weak => 0,
            .blast, .melee => amount * 0.15,
            .other => amount,
        };
    }

    pub fn brush(_: Armadillo, tool: InteractionItem, brush_durability: u16) BrushResult {
        if (tool != .brush or brush_durability == 0) return .{};
        return .{ .scutes_dropped = 1, .brush_durability_used = @min(brush_durability, brush_durability_cost) };
    }

    pub fn tickNaturalScute(self: *Armadillo) bool {
        self.ticks_since_scute_drop += 1;
        if (self.ticks_since_scute_drop < natural_scute_interval_ticks) return false;
        self.ticks_since_scute_drop = 0;
        return true;
    }
};

pub const InteractionItem = enum { brush, armadillo_scute, wolf_armor, shears, other };
pub const BrushResult = struct { scutes_dropped: u8 = 0, brush_durability_used: u16 = 0 };

pub const CrackStage = enum { pristine, slightly_cracked, moderately_cracked, heavily_cracked, broken };
pub const DyeColor = enum(u8) {
    white,
    orange,
    magenta,
    light_blue,
    yellow,
    lime,
    pink,
    gray,
    light_gray,
    cyan,
    purple,
    blue,
    brown,
    green,
    red,
    black,

    pub fn rgb(self: DyeColor) u32 {
        return switch (self) {
            .white => 0xF9FFFE,
            .orange => 0xF9801D,
            .magenta => 0xC74EBD,
            .light_blue => 0x3AB3DA,
            .yellow => 0xFED83D,
            .lime => 0x80C71F,
            .pink => 0xF38BAA,
            .gray => 0x474F52,
            .light_gray => 0x9D9D97,
            .cyan => 0x169C9C,
            .purple => 0x8932B8,
            .blue => 0x3C44AA,
            .brown => 0x835432,
            .green => 0x5E7C16,
            .red => 0xB02E26,
            .black => 0x1D1D21,
        };
    }
};

pub const WolfArmor = struct {
    durability: u16 = wolf_armor_durability,
    color: ?DyeColor = null,

    pub fn crackStage(self: WolfArmor) CrackStage {
        if (self.durability == 0) return .broken;
        if (self.durability == wolf_armor_durability) return .pristine;
        if (self.durability >= 48) return .slightly_cracked;
        if (self.durability >= 32) return .moderately_cracked;
        return .heavily_cracked;
    }
};

pub const CraftResult = struct { item: InteractionItem = .other, count: u8 = 0, scutes_consumed: u8 = 0 };

pub fn craftWolfArmor(scutes: u8) CraftResult {
    if (scutes < 6) return .{};
    return .{ .item = .wolf_armor, .count = 1, .scutes_consumed = 6 };
}

pub const Wolf = struct {
    owner_id: u64,
    armor: ?WolfArmor = null,

    pub fn interact(self: *Wolf, player_id: u64, item: InteractionItem) WolfInteractionResult {
        if (player_id != self.owner_id) return .{ .action = .not_owner };
        if (self.armor) |*armor| {
            switch (item) {
                .armadillo_scute => {
                    if (armor.durability == wolf_armor_durability) return .{ .action = .nothing_to_repair };
                    armor.durability = @min(wolf_armor_durability, armor.durability + scute_repair_amount);
                    return .{ .action = .repaired, .consumed_item = .armadillo_scute };
                },
                .shears => {
                    const returned_armor = armor.*;
                    self.armor = null;
                    return .{ .action = .armor_removed, .returned_armor = returned_armor };
                },
                else => return .{ .action = .no_interaction },
            }
        }
        if (item == .wolf_armor) {
            self.armor = WolfArmor{};
            return .{ .action = .armor_equipped, .consumed_item = .wolf_armor };
        }
        return .{ .action = .no_interaction };
    }

    pub fn applyDamage(self: *Wolf, damage: u16) WolfDamageResult {
        if (self.armor) |*armor| {
            if (damage == 0) return .{};
            armor.durability -|= damage;
            if (armor.durability == 0) {
                self.armor = null;
                return .{ .damage_to_wolf = 0, .armor_broke = true, .sound = .armor_shatter };
            }
            return .{ .damage_to_wolf = 0 };
        }
        return .{ .damage_to_wolf = damage };
    }

    pub fn dyeArmor(self: *Wolf, player_id: u64, color: DyeColor) bool {
        if (player_id != self.owner_id) return false;
        const armor = if (self.armor) |*value| value else return false;
        armor.color = color;
        return true;
    }
};

pub const WolfInteractionResult = struct {
    action: WolfInteractionAction,
    consumed_item: ?InteractionItem = null,
    returned_armor: ?WolfArmor = null,
};
pub const WolfInteractionAction = enum { armor_equipped, armor_removed, repaired, nothing_to_repair, no_interaction, not_owner };
pub const WolfDamageResult = struct { damage_to_wolf: u16 = 0, armor_broke: bool = false, sound: ?Sound = null };

pub fn washArmorInCauldron(armor: *WolfArmor) bool {
    if (armor.color == null) return false;
    armor.color = null;
    return true;
}

test "threat radius includes exactly seven meters and rejects farther entities" {
    try std.testing.expect(isThreatWithinRadius(7));
    try std.testing.expect(!isThreatWithinRadius(7.001));
    try std.testing.expect(!(Threat{ .kind = .zombie, .distance = 7.01 }).isRelevant());
}

test "threat range uses three dimensional Euclidean distance" {
    try std.testing.expectApproxEqAbs(@as(f32, 7), distance3d(0, 0, 0, 3, 4, @sqrt(@as(f32, 24))), 0.0001);
    try std.testing.expect(!isThreatWithinRadius(distance3d(0, 0, 0, 3, 4, 5)));
}

test "sprinting player triggers roll-up" {
    var armadillo = Armadillo{};
    _ = armadillo.tick(&.{.{ .kind = .sprinting_player, .distance = 2 }});
    try std.testing.expectEqual(ArmadilloState.rolling_up, armadillo.state);
}

test "zombies trigger roll-up" {
    try threatStartsRoll(.zombie);
}
test "husks trigger roll-up" {
    try threatStartsRoll(.husk);
}
test "drowned trigger roll-up" {
    try threatStartsRoll(.drowned);
}
test "skeletons trigger roll-up" {
    try threatStartsRoll(.skeleton);
}
test "spiders trigger roll-up" {
    try threatStartsRoll(.spider);
}
test "cave spiders trigger roll-up" {
    try threatStartsRoll(.cave_spider);
}

fn threatStartsRoll(kind: ThreatKind) !void {
    var armadillo = Armadillo{};
    _ = armadillo.tick(&.{.{ .kind = kind, .distance = 6.9 }});
    try std.testing.expectEqual(ArmadilloState.rolling_up, armadillo.state);
}

test "environmental damage triggers roll-up" {
    var armadillo = Armadillo{};
    _ = armadillo.tick(&.{.{ .kind = .environmental_damage, .distance = 100 }});
    try std.testing.expectEqual(ArmadilloState.rolling_up, armadillo.state);
}

test "ordinary nearby entity is ignored" {
    var armadillo = Armadillo{};
    _ = armadillo.tick(&.{.{ .kind = .other, .distance = 1 }});
    try std.testing.expectEqual(ArmadilloState.standing, armadillo.state);
}

test "rolling closes into curled ball and emits clack" {
    var armadillo = Armadillo{};
    _ = armadillo.tick(&.{.{ .kind = .sprinting_player, .distance = 1 }});
    const result = armadillo.tick(&.{});
    try std.testing.expectEqual(ArmadilloState.curled_ball, armadillo.state);
    try std.testing.expectEqual(Sound.shell_clack, result.sound.?);
}

test "weak attack is fully negated while curled" {
    var armadillo = Armadillo{ .state = .curled_ball };
    try std.testing.expectEqual(@as(f32, 0), armadillo.applyDamage(10, .weak));
}

test "blast attack is reduced by eighty five percent" {
    var armadillo = Armadillo{ .state = .curled_ball };
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), armadillo.applyDamage(10, .blast), 0.0001);
}

test "melee attack is reduced by eighty five percent" {
    var armadillo = Armadillo{ .state = .curled_ball };
    try std.testing.expectApproxEqAbs(@as(f32, 0.75), armadillo.applyDamage(5, .melee), 0.0001);
}

test "uncurled armadillo takes full damage" {
    var armadillo = Armadillo{};
    try std.testing.expectEqual(@as(f32, 5), armadillo.applyDamage(5, .weak));
}

test "threat resets the 200 tick clear counter" {
    var armadillo = Armadillo{ .state = .curled_ball, .threat_clear_ticks = 199 };
    _ = armadillo.tick(&.{.{ .kind = .spider, .distance = 7 }});
    try std.testing.expectEqual(@as(u16, 0), armadillo.threat_clear_ticks);
    try std.testing.expectEqual(ArmadilloState.curled_ball, armadillo.state);
}

test "starts unrolling on the two hundredth clear tick" {
    var armadillo = Armadillo{ .state = .curled_ball };
    for (0..199) |_| _ = armadillo.tick(&.{});
    try std.testing.expectEqual(ArmadilloState.curled_ball, armadillo.state);
    _ = armadillo.tick(&.{});
    try std.testing.expectEqual(ArmadilloState.unrolling, armadillo.state);
}

test "unrolling returns to standing after transition tick" {
    var armadillo = Armadillo{ .state = .unrolling };
    _ = armadillo.tick(&.{});
    try std.testing.expectEqual(ArmadilloState.standing, armadillo.state);
}

test "brush drops one scute and consumes sixteen durability" {
    const result = (Armadillo{}).brush(.brush, 64);
    try std.testing.expectEqual(@as(u8, 1), result.scutes_dropped);
    try std.testing.expectEqual(@as(u16, 16), result.brush_durability_used);
}

test "wrong tool does not brush armadillo" {
    const result = (Armadillo{}).brush(.other, 64);
    try std.testing.expectEqual(@as(u8, 0), result.scutes_dropped);
}

test "broken brush yields no scute" {
    const result = (Armadillo{}).brush(.brush, 0);
    try std.testing.expectEqual(@as(u8, 0), result.scutes_dropped);
}

test "brush use never spends more remaining durability" {
    const result = (Armadillo{}).brush(.brush, 5);
    try std.testing.expectEqual(@as(u16, 5), result.brush_durability_used);
}

test "natural scute drop occurs every 24000 ticks" {
    var armadillo = Armadillo{ .ticks_since_scute_drop = 23_998 };
    try std.testing.expect(!armadillo.tickNaturalScute());
    try std.testing.expect(armadillo.tickNaturalScute());
    try std.testing.expectEqual(@as(u32, 0), armadillo.ticks_since_scute_drop);
}

test "crafting requires six scutes and consumes six" {
    try std.testing.expectEqual(@as(u8, 0), craftWolfArmor(5).count);
    const result = craftWolfArmor(6);
    try std.testing.expectEqual(InteractionItem.wolf_armor, result.item);
    try std.testing.expectEqual(@as(u8, 1), result.count);
    try std.testing.expectEqual(@as(u8, 6), result.scutes_consumed);
}

test "only owner may equip wolf armor" {
    var wolf = Wolf{ .owner_id = 12 };
    try std.testing.expectEqual(WolfInteractionAction.not_owner, wolf.interact(13, .wolf_armor).action);
    try std.testing.expectEqual(@as(?WolfArmor, null), wolf.armor);
    const equipped = wolf.interact(12, .wolf_armor);
    try std.testing.expectEqual(WolfInteractionAction.armor_equipped, equipped.action);
    try std.testing.expectEqual(InteractionItem.wolf_armor, equipped.consumed_item.?);
}

test "only owner may remove armor with shears" {
    var wolf = Wolf{ .owner_id = 12, .armor = .{ .durability = 23, .color = .cyan } };
    try std.testing.expectEqual(WolfInteractionAction.not_owner, wolf.interact(13, .shears).action);
    try std.testing.expect(wolf.armor != null);
    const removed = wolf.interact(12, .shears);
    try std.testing.expectEqual(WolfInteractionAction.armor_removed, removed.action);
    try std.testing.expectEqual(@as(u16, 23), removed.returned_armor.?.durability);
    try std.testing.expectEqual(DyeColor.cyan, removed.returned_armor.?.color.?);
    try std.testing.expect(wolf.armor == null);
}

test "wolf armor absorbs damage and loses matching durability" {
    var wolf = Wolf{ .owner_id = 1, .armor = .{} };
    const result = wolf.applyDamage(10);
    try std.testing.expectEqual(@as(u16, 0), result.damage_to_wolf);
    try std.testing.expectEqual(@as(u16, 54), wolf.armor.?.durability);
}

test "wolf armor break absorbs final hit and emits shatter sound" {
    var wolf = Wolf{ .owner_id = 1, .armor = .{ .durability = 3 } };
    const result = wolf.applyDamage(10);
    try std.testing.expectEqual(@as(u16, 0), result.damage_to_wolf);
    try std.testing.expect(result.armor_broke);
    try std.testing.expectEqual(Sound.armor_shatter, result.sound.?);
    try std.testing.expect(wolf.armor == null);
}

test "unarmored wolf takes full damage" {
    var wolf = Wolf{ .owner_id = 1 };
    try std.testing.expectEqual(@as(u16, 9), wolf.applyDamage(9).damage_to_wolf);
}

test "armor crack stages match requested durability ranges" {
    try std.testing.expectEqual(CrackStage.pristine, (WolfArmor{ .durability = 64 }).crackStage());
    try std.testing.expectEqual(CrackStage.slightly_cracked, (WolfArmor{ .durability = 63 }).crackStage());
    try std.testing.expectEqual(CrackStage.slightly_cracked, (WolfArmor{ .durability = 48 }).crackStage());
    try std.testing.expectEqual(CrackStage.moderately_cracked, (WolfArmor{ .durability = 47 }).crackStage());
    try std.testing.expectEqual(CrackStage.moderately_cracked, (WolfArmor{ .durability = 32 }).crackStage());
    try std.testing.expectEqual(CrackStage.heavily_cracked, (WolfArmor{ .durability = 31 }).crackStage());
    try std.testing.expectEqual(CrackStage.heavily_cracked, (WolfArmor{ .durability = 1 }).crackStage());
    try std.testing.expectEqual(CrackStage.broken, (WolfArmor{ .durability = 0 }).crackStage());
}

test "owner repairs armor by eight durability with scute" {
    var wolf = Wolf{ .owner_id = 1, .armor = .{ .durability = 40 } };
    const repair = wolf.interact(1, .armadillo_scute);
    try std.testing.expectEqual(WolfInteractionAction.repaired, repair.action);
    try std.testing.expectEqual(InteractionItem.armadillo_scute, repair.consumed_item.?);
    try std.testing.expectEqual(@as(u16, 48), wolf.armor.?.durability);
    try std.testing.expectEqual(CrackStage.slightly_cracked, wolf.armor.?.crackStage());
}

test "scute repair caps armor durability at sixty four" {
    var wolf = Wolf{ .owner_id = 1, .armor = .{ .durability = 60 } };
    _ = wolf.interact(1, .armadillo_scute);
    try std.testing.expectEqual(@as(u16, 64), wolf.armor.?.durability);
}

test "dye enum exposes all sixteen named colors and RGB values" {
    const colors = [_]DyeColor{ .white, .orange, .magenta, .light_blue, .yellow, .lime, .pink, .gray, .light_gray, .cyan, .purple, .blue, .brown, .green, .red, .black };
    try std.testing.expectEqual(@as(usize, 16), colors.len);
    for (colors) |color| try std.testing.expect(color.rgb() != 0);
    try std.testing.expectEqual(@as(u32, 0xF9FFFE), DyeColor.white.rgb());
    try std.testing.expectEqual(@as(u32, 0x1D1D21), DyeColor.black.rgb());
}

test "owner can dye armor and cauldron washes it" {
    var wolf = Wolf{ .owner_id = 4, .armor = .{} };
    try std.testing.expect(!wolf.dyeArmor(5, .cyan));
    try std.testing.expect(wolf.dyeArmor(4, .cyan));
    try std.testing.expectEqual(DyeColor.cyan, wolf.armor.?.color.?);
    if (wolf.armor) |*armor| {
        try std.testing.expect(washArmorInCauldron(armor));
    } else {
        return error.TestUnexpectedResult;
    }
    try std.testing.expect(wolf.armor.?.color == null);
}

test "washing undyed armor is a no-op" {
    var armor = WolfArmor{};
    try std.testing.expect(!washArmorInCauldron(&armor));
}
