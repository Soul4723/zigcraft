const std = @import("std");

pub const evoker_fang_damage: f32 = 6.0;
pub const vex_health: f32 = 14.0;
pub const vex_melee_damage: f32 = 9.0;
pub const vex_starvation_damage_per_second: f32 = 2.0;
pub const vindicator_health: f32 = 24.0;
pub const vindicator_axe_damage: f32 = 13.0;
pub const shield_disable_duration: f32 = 5.0;
pub const vex_summon_count: u8 = 3;
pub const vex_active_limit: u8 = 8;

pub const EvokerSpell = enum { none, summon_vexes, fang_ring_close_defense, fang_line_ranged_attack, wololo_sheep_dye };

/// Spell cooldown suppresses a cast regardless of its otherwise eligible target.
/// In combat, close defense takes priority, then Vex support, then ranged fangs.
pub fn selectEvokerSpell(dist_to_target: f32, active_vex_count: u8, spell_cooldown: f32, blue_sheep_within_16m: bool, in_combat: bool) EvokerSpell {
    if (spell_cooldown > 0.0) return .none;
    if (in_combat) {
        if (dist_to_target < 3.0) return .fang_ring_close_defense;
        if (active_vex_count < vex_active_limit) return .summon_vexes;
        return .fang_line_ranged_attack;
    }
    return if (blue_sheep_within_16m) .wololo_sheep_dye else .none;
}

pub const FangRing = struct { inner_fangs: u8 = 5, outer_fangs: u8 = 8, total_fangs: u8 = 13, damage_per_fang: f32 = evoker_fang_damage };
pub fn evokerCloseDefense() FangRing { return .{}; }

pub const SheepColor = enum { white, orange, magenta, light_blue, yellow, lime, pink, gray, light_gray, cyan, purple, blue, brown, green, red, black };
pub const WololoResult = struct { chanted: bool, converted: bool, color: SheepColor };
/// A nearby blue sheep is converted and the Evoker chants its characteristic call.
pub fn wololoSheep(color: SheepColor) WololoResult {
    const converted = color == .blue;
    return .{ .chanted = converted, .converted = converted, .color = if (converted) .red else color };
}

pub const vex_starvation_min_delay: f32 = 30.0;
pub const vex_starvation_max_delay: f32 = 119.0;

pub const VexState = struct {
    health: f32 = vex_health,
    summon_age: f32 = 0.0,
    starvation_delay: f32 = vex_starvation_min_delay,
    lunging: bool = false,
    summoner_alive: bool = true,
    alive: bool = true,

    pub fn init(starvation_delay: f32) VexState {
        return .{ .starvation_delay = std.math.clamp(starvation_delay, vex_starvation_min_delay, vex_starvation_max_delay) };
    }
    /// Vexes ignore all block collision, including solid walls.
    pub fn vexCollidesWithBlocks() bool { return false; }
    pub fn glowColor(self: VexState) ?[3]u8 { return if (self.lunging) .{ 255, 0, 0 } else null; }
    pub fn setLunging(self: *VexState, lunging: bool) void { self.lunging = lunging; }
    pub fn summonerKilled(self: *VexState) void { self.summoner_alive = false; }
    pub fn tick(self: *VexState, dt: f32) void {
        if (!self.alive or dt <= 0.0) return;
        const previous_age = self.summon_age;
        self.summon_age += dt;
        const starvation_time = if (!self.summoner_alive)
            dt
        else
            @max(0.0, self.summon_age - self.starvation_delay) - @max(0.0, previous_age - self.starvation_delay);
        if (starvation_time > 0.0) {
            self.health = @max(0.0, self.health - vex_starvation_damage_per_second * starvation_time);
            if (self.health == 0.0) self.alive = false;
        }
    }
};

pub const VindicatorState = struct {
    health: f32 = vindicator_health,
    axe_damage: f32 = vindicator_axe_damage,
    shield_disable_seconds: f32 = shield_disable_duration,
    is_named_johnny: bool = false,

    pub fn init(is_named_johnny: bool) VindicatorState { return .{ .is_named_johnny = is_named_johnny }; }
    pub fn shouldJohnnyAttackMob(self: VindicatorState, target_is_illager: bool, target_is_ghast: bool) bool {
        return self.is_named_johnny and !target_is_illager and !target_is_ghast;
    }
};

test "combat Evoker uses close fang ring inside three blocks" {
    try std.testing.expectEqual(EvokerSpell.fang_ring_close_defense, selectEvokerSpell(2.99, 0, 0, false, true));
    try std.testing.expectEqual(EvokerSpell.fang_ring_close_defense, selectEvokerSpell(0, 8, 0, false, true));
}
test "close fang ring contains concentric five and eight fang circles" {
    const ring = evokerCloseDefense();
    try std.testing.expectEqual(@as(u8, 5), ring.inner_fangs);
    try std.testing.expectEqual(@as(u8, 8), ring.outer_fangs);
    try std.testing.expectEqual(@as(u8, 13), ring.total_fangs);
}
test "combat Evoker summons three Vexes while below active limit" {
    try std.testing.expectEqual(EvokerSpell.summon_vexes, selectEvokerSpell(8, 0, 0, false, true));
    try std.testing.expectEqual(@as(u8, 3), vex_summon_count);
}
test "combat Evoker uses ranged fang line at Vex cap" {
    try std.testing.expectEqual(EvokerSpell.fang_line_ranged_attack, selectEvokerSpell(8, 8, 0, false, true));
    try std.testing.expectEqual(EvokerSpell.fang_line_ranged_attack, selectEvokerSpell(8, 9, 0, false, true));
}
test "spell cooldown suppresses combat casts" {
    try std.testing.expectEqual(EvokerSpell.none, selectEvokerSpell(1, 0, 0.01, false, true));
}
test "Wololo chants and changes blue sheep wool to red" {
    const result = wololoSheep(.blue);
    try std.testing.expect(result.chanted);
    try std.testing.expect(result.converted);
    try std.testing.expectEqual(SheepColor.red, result.color);
}
test "Wololo does not convert non-blue sheep" {
    const result = wololoSheep(.white);
    try std.testing.expect(!result.chanted);
    try std.testing.expect(!result.converted);
    try std.testing.expectEqual(SheepColor.white, result.color);
}
test "noncombat Evoker chooses Wololo only for nearby blue sheep" {
    try std.testing.expectEqual(EvokerSpell.wololo_sheep_dye, selectEvokerSpell(0, 8, 0, true, false));
    try std.testing.expectEqual(EvokerSpell.none, selectEvokerSpell(0, 0, 0, false, false));
}
test "cooldown also suppresses Wololo" {
    try std.testing.expectEqual(EvokerSpell.none, selectEvokerSpell(0, 0, 1, true, false));
}
test "Vex phases through solid blocks and walls" {
    try std.testing.expect(!VexState.vexCollidesWithBlocks());
}
test "Vex has ghost swordsman health and sword damage" {
    const vex = VexState.init(50);
    try std.testing.expectEqual(@as(f32, 14), vex.health);
    try std.testing.expectEqual(@as(f32, 9), vex_melee_damage);
}
test "Vex summon decay delay clamps to documented range" {
    try std.testing.expectEqual(@as(f32, 30), VexState.init(0).starvation_delay);
    try std.testing.expectEqual(@as(f32, 119), VexState.init(200).starvation_delay);
    try std.testing.expectEqual(@as(f32, 75), VexState.init(75).starvation_delay);
}
test "Vex starvation begins after summon delay at two health per second" {
    var vex = VexState.init(30);
    vex.tick(29);
    try std.testing.expectEqual(@as(f32, 14), vex.health);
    vex.tick(1);
    try std.testing.expectEqual(@as(f32, 14), vex.health);
    vex.tick(1);
    try std.testing.expectEqual(@as(f32, 12), vex.health);
}
test "Vex tick crossing starvation deadline decays only post-deadline time" {
    var vex = VexState.init(30);
    vex.tick(29.5);
    vex.tick(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 13), vex.health, 0.0001);
}
test "killing Evoker summoner immediately starts Vex starvation" {
    var vex = VexState.init(119);
    vex.summonerKilled();
    vex.tick(1);
    try std.testing.expectEqual(@as(f32, 12), vex.health);
}
test "Vex starvation eventually kills Vex and does not heal" {
    var vex = VexState.init(30);
    vex.tick(40);
    try std.testing.expectEqual(@as(f32, 0), vex.health);
    try std.testing.expect(!vex.alive);
    vex.tick(1);
    try std.testing.expectEqual(@as(f32, 0), vex.health);
}
test "Vex glows red only during a lunge" {
    var vex = VexState.init(30);
    try std.testing.expectEqual(@as(?[3]u8, null), vex.glowColor());
    vex.setLunging(true);
    try std.testing.expectEqual(@as(?[3]u8, .{ 255, 0, 0 }), vex.glowColor());
}
test "Vindicator carries axe stats and shield disable duration" {
    const vindicator = VindicatorState.init(false);
    try std.testing.expectEqual(@as(f32, 24), vindicator.health);
    try std.testing.expectEqual(@as(f32, 13), vindicator.axe_damage);
    try std.testing.expectEqual(@as(f32, 5), vindicator.shield_disable_seconds);
}
test "Johnny attacks non-Illager mobs but spares Illagers and Ghasts" {
    const johnny = VindicatorState.init(true);
    try std.testing.expect(johnny.shouldJohnnyAttackMob(false, false));
    try std.testing.expect(!johnny.shouldJohnnyAttackMob(true, false));
    try std.testing.expect(!johnny.shouldJohnnyAttackMob(false, true));
}
test "ordinary Vindicator does not enter Johnny berserk mode" {
    const ordinary = VindicatorState.init(false);
    try std.testing.expect(!ordinary.shouldJohnnyAttackMob(false, false));
}
