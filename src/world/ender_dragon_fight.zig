const std = @import("std");

pub const DRAGON_CRYSTAL_BEAM_RANGE: f32 = 32.0;
pub const CRYSTAL_SHATTER_RECOIL_DAMAGE: f32 = 10.0;
pub const DRAGON_HEAL_PER_SECOND: f32 = 2.0;
pub const MAX_END_GATEWAYS: usize = 20;
pub const END_GATEWAY_RING_RADIUS: f32 = 1024.0;
pub const END_GATEWAY_WARP_DISTANCE: f32 = 1024.0;
pub const FIRST_DRAGON_KILL_XP: u32 = 12000;
pub const SUBSEQUENT_DRAGON_KILL_XP: u32 = 500;

pub const EndCrystalTower = struct {
    pos: [3]f32,
    has_iron_cage: bool,
    is_alive: bool,
};

pub const DragonCrystalHealingTick = struct {
    new_hp: f32,
    tethered_beam_active: bool,
    /// Recoil damage to apply if the active, tethering crystal is destroyed this tick.
    recoil_damage_on_crystal_destroyed: f32,
};

/// Applies crystal healing when the dragon is close enough. The recoil field is
/// the damage that would be applied if that active tether is shattered.
pub fn tickDragonCrystalBeamHealing(dragon_hp: f32, max_hp: f32, dist_to_nearest_alive_crystal: f32, dt: f32) DragonCrystalHealingTick {
    const beam_active = dist_to_nearest_alive_crystal <= DRAGON_CRYSTAL_BEAM_RANGE;
    const healed_hp = if (beam_active) dragon_hp + DRAGON_HEAL_PER_SECOND * @max(0.0, dt) else dragon_hp;
    return .{
        .new_hp = @min(@max(0.0, max_hp), healed_hp),
        .tethered_beam_active = beam_active,
        .recoil_damage_on_crystal_destroyed = if (beam_active) CRYSTAL_SHATTER_RECOIL_DAMAGE else 0.0,
    };
}

pub const DragonCombatPhase = enum {
    circling_pillars,
    strafing_acid_ball,
    diving_charge,
    perched_on_fountain,
    dying_ascension,
};

/// The fountain perch deflects arrows and all other projectiles; melee and beds
/// remain valid ways to damage the dragon.
pub fn canDamageDragonWithProjectile(phase: DragonCombatPhase) bool {
    return phase != .perched_on_fountain;
}

pub fn dragonBreathesAtFountain(phase: DragonCombatPhase) bool {
    return phase == .perched_on_fountain;
}

pub const DragonBreathCloud = struct {
    pos: [3]f32,
    radius: f32 = 3.0,
    remaining_lifetime: f32 = 30.0,
    active: bool = true,

    pub fn tick(self: *DragonBreathCloud, dt: f32) void {
        self.remaining_lifetime = @max(0.0, self.remaining_lifetime - @max(0.0, dt));
        if (self.remaining_lifetime == 0.0) self.active = false;
    }

    /// A glass bottle collects breath from an active cloud it touches.
    pub fn collectWithGlassBottle(self: *DragonBreathCloud, bottle_touches_cloud: bool) bool {
        if (!self.active or !bottle_touches_cloud) return false;
        self.active = false;
        return true;
    }
};

pub const DragonBreathCollection = struct {
    dragons_breath_bottles: u32 = 0,

    pub fn collect(self: *DragonBreathCollection, cloud: *DragonBreathCloud, bottle_touches_cloud: bool) bool {
        if (!cloud.collectWithGlassBottle(bottle_touches_cloud)) return false;
        self.dragons_breath_bottles += 1;
        return true;
    }
};

/// Four crystals must occupy all cardinal positions around an active Exit Portal.
pub fn canTriggerDragonRespawnRitual(portal_active: bool, cardinal_crystals_on_portal_rim: [4]bool) bool {
    if (!portal_active) return false;
    for (cardinal_crystals_on_portal_rim) |placed| {
        if (!placed) return false;
    }
    return true;
}

pub const DragonRespawnRitualResult = struct {
    regenerated_pillar_crystal_count: u8,
    summoned_new_dragon: bool,
};

/// Resolves the ritual effects when all four crystals are placed on the active portal rim.
pub fn triggerDragonRespawnRitual(portal_active: bool, cardinal_crystals_on_portal_rim: [4]bool) ?DragonRespawnRitualResult {
    if (!canTriggerDragonRespawnRitual(portal_active, cardinal_crystals_on_portal_rim)) return null;
    return .{ .regenerated_pillar_crystal_count = 10, .summoned_new_dragon = true };
}

pub const DragonKillRewards = struct {
    xp: u32,
    drops_dragon_egg: bool,
};

pub fn dragonKillRewards(is_first_kill: bool) DragonKillRewards {
    return .{
        .xp = if (is_first_kill) FIRST_DRAGON_KILL_XP else SUBSEQUENT_DRAGON_KILL_XP,
        .drops_dragon_egg = is_first_kill,
    };
}

pub const EndGateway = struct {
    pos: [3]f32,
    beam_width_blocks: f32 = 1.0,

    /// An Ender Pearl must enter the one-block beam to activate the gateway.
    pub fn warpPearlTarget(self: EndGateway, pearl_entered_beam: bool, main_island_center: [3]f32) ?[3]f32 {
        if (!pearl_entered_beam) return null;
        var dx = self.pos[0] - main_island_center[0];
        var dz = self.pos[2] - main_island_center[2];
        const length = @sqrt(dx * dx + dz * dz);
        if (length == 0.0) {
            dx = 1.0;
            dz = 0.0;
        } else {
            dx /= length;
            dz /= length;
        }
        return .{
            self.pos[0] + dx * END_GATEWAY_WARP_DISTANCE,
            self.pos[1],
            self.pos[2] + dz * END_GATEWAY_WARP_DISTANCE,
        };
    }
};

pub const EndGatewayRing = struct {
    gateways: [MAX_END_GATEWAYS]EndGateway,
    count: usize,
};

/// Generates up to 20 gateways evenly spaced around the main island.
pub fn generateEndGatewayRing(main_island_center: [3]f32) EndGatewayRing {
    var result: EndGatewayRing = undefined;
    result.count = MAX_END_GATEWAYS;
    for (0..MAX_END_GATEWAYS) |i| {
        const angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(MAX_END_GATEWAYS));
        result.gateways[i] = .{ .pos = .{
            main_island_center[0] + @cos(angle) * END_GATEWAY_RING_RADIUS,
            main_island_center[1],
            main_island_center[2] + @sin(angle) * END_GATEWAY_RING_RADIUS,
        } };
    }
    return result;
}

test "End Crystal beams heal within 32 blocks, clamp at max, and expose shatter recoil" {
    const healing = tickDragonCrystalBeamHealing(90.0, 100.0, 32.0, 2.0);
    try std.testing.expectEqual(@as(f32, 94.0), healing.new_hp);
    try std.testing.expect(healing.tethered_beam_active);
    try std.testing.expectEqual(@as(f32, 10.0), healing.recoil_damage_on_crystal_destroyed);

    const capped = tickDragonCrystalBeamHealing(99.0, 100.0, 4.0, 5.0);
    try std.testing.expectEqual(@as(f32, 100.0), capped.new_hp);
}

test "End Crystal beam stops outside 32 blocks and has no shatter recoil" {
    const tick = tickDragonCrystalBeamHealing(80.0, 100.0, 32.01, 10.0);
    try std.testing.expectEqual(@as(f32, 80.0), tick.new_hp);
    try std.testing.expect(!tick.tethered_beam_active);
    try std.testing.expectEqual(@as(f32, 0.0), tick.recoil_damage_on_crystal_destroyed);
}

test "healing tick does not lower health for negative delta" {
    const tick = tickDragonCrystalBeamHealing(50.0, 100.0, 10.0, -1.0);
    try std.testing.expectEqual(@as(f32, 50.0), tick.new_hp);
}

test "crystal tower carries position cage and alive state" {
    const tower = EndCrystalTower{ .pos = .{ 1.0, 80.0, -2.0 }, .has_iron_cage = true, .is_alive = true };
    try std.testing.expect(tower.has_iron_cage and tower.is_alive);
    try std.testing.expectEqual(@as(f32, 80.0), tower.pos[1]);
}

test "fountain perch deflects projectiles but other phases do not" {
    try std.testing.expect(!canDamageDragonWithProjectile(.perched_on_fountain));
    try std.testing.expect(dragonBreathesAtFountain(.perched_on_fountain));
    try std.testing.expect(!dragonBreathesAtFountain(.diving_charge));
    try std.testing.expect(canDamageDragonWithProjectile(.circling_pillars));
    try std.testing.expect(canDamageDragonWithProjectile(.strafing_acid_ball));
    try std.testing.expect(canDamageDragonWithProjectile(.diving_charge));
    try std.testing.expect(canDamageDragonWithProjectile(.dying_ascension));
}

test "fountain perch Dragon Breath can be collected in a glass bottle" {
    var cloud = DragonBreathCloud{ .pos = .{ 0.0, 1.0, 0.0 } };
    var collection = DragonBreathCollection{};
    try std.testing.expect(!collection.collect(&cloud, false));
    try std.testing.expect(collection.collect(&cloud, true));
    try std.testing.expectEqual(@as(u32, 1), collection.dragons_breath_bottles);
    try std.testing.expect(!collection.collect(&cloud, true));
}

test "Dragon Breath cloud lingers until its lifetime expires" {
    var cloud = DragonBreathCloud{ .pos = .{ 0.0, 0.0, 0.0 }, .remaining_lifetime = 2.0 };
    cloud.tick(1.0);
    try std.testing.expect(cloud.active);
    cloud.tick(1.0);
    try std.testing.expect(!cloud.active);
}

test "respawn ritual requires active portal and four cardinal crystals" {
    try std.testing.expect(canTriggerDragonRespawnRitual(true, .{ true, true, true, true }));
    try std.testing.expect(!canTriggerDragonRespawnRitual(false, .{ true, true, true, true }));
    try std.testing.expect(!canTriggerDragonRespawnRitual(true, .{ true, true, false, true }));
}

test "ritual cardinal array rejects each missing crystal position" {
    try std.testing.expect(!canTriggerDragonRespawnRitual(true, .{ false, true, true, true }));
    try std.testing.expect(!canTriggerDragonRespawnRitual(true, .{ true, false, true, true }));
    try std.testing.expect(!canTriggerDragonRespawnRitual(true, .{ true, true, false, true }));
    try std.testing.expect(!canTriggerDragonRespawnRitual(true, .{ true, true, true, false }));
}

test "successful respawn ritual restores ten pillar crystals and summons dragon" {
    const effects = triggerDragonRespawnRitual(true, .{ true, true, true, true }).?;
    try std.testing.expectEqual(@as(u8, 10), effects.regenerated_pillar_crystal_count);
    try std.testing.expect(effects.summoned_new_dragon);
    try std.testing.expect(triggerDragonRespawnRitual(true, .{ true, true, false, true }) == null);
}

test "first kill grants 12000 XP and the sole dragon egg" {
    const rewards = dragonKillRewards(true);
    try std.testing.expectEqual(@as(u32, 12000), rewards.xp);
    try std.testing.expect(rewards.drops_dragon_egg);
}

test "subsequent kills grant 500 XP and no dragon egg" {
    const rewards = dragonKillRewards(false);
    try std.testing.expectEqual(@as(u32, 500), rewards.xp);
    try std.testing.expect(!rewards.drops_dragon_egg);
}

test "gateway ring generates 20 evenly spaced gateways around island" {
    const ring = generateEndGatewayRing(.{ 10.0, 64.0, -20.0 });
    try std.testing.expectEqual(@as(usize, 20), ring.count);
    for (ring.gateways) |gateway| {
        const dx = gateway.pos[0] - 10.0;
        const dz = gateway.pos[2] + 20.0;
        const distance = @sqrt(dx * dx + dz * dz);
        try std.testing.expectApproxEqAbs(END_GATEWAY_RING_RADIUS, distance, 0.01);
        try std.testing.expectEqual(@as(f32, 64.0), gateway.pos[1]);
    }
}

test "gateway pearl must enter beam and then warps over 1000 blocks outward" {
    const center = [3]f32{ 0.0, 70.0, 0.0 };
    const gateway = EndGateway{ .pos = .{ 1024.0, 70.0, 0.0 } };
    try std.testing.expect(gateway.warpPearlTarget(false, center) == null);
    const destination = gateway.warpPearlTarget(true, center).?;
    try std.testing.expect(destination[0] >= 2048.0);
    try std.testing.expectEqual(@as(f32, 70.0), destination[1]);
}

test "gateway at island center chooses a stable outward warp direction" {
    const gateway = EndGateway{ .pos = .{ 0.0, 70.0, 0.0 } };
    const destination = gateway.warpPearlTarget(true, .{ 0.0, 70.0, 0.0 }).?;
    try std.testing.expectEqual(END_GATEWAY_WARP_DISTANCE, destination[0]);
    try std.testing.expectEqual(@as(f32, 0.0), destination[2]);
}
