const std = @import("std");
const BlockId = @import("block.zig").BlockId;

pub const Vec3 = [3]f32;
pub const IVec3 = [3]i32;
pub const RITUAL_DURATION_TICKS: u16 = 600;
pub const CHARGING_END_TICK: u16 = 100;
pub const PILLAR_REGENERATION_END_TICK: u16 = 400;
pub const CONVERGENCE_END_TICK: u16 = 500;
pub const PILLAR_CRYSTAL_COUNT: usize = 10;
pub const FOUNTAIN_CRYSTAL_COUNT: usize = 4;
pub const DRAGON_MAX_HEALTH: f32 = 200.0;
pub const FINAL_EXPLOSION_POWER: f32 = 12.0;
pub const PILLAR_EXPLOSION_POWER: f32 = 6.0;
pub const SKY_APEX: Vec3 = .{ 0.0, 100.0, 0.0 };
pub const PORTAL_BLOCK_COUNT: usize = 9;

/// The generated fountain bedrock surface is at Y=8; crystals stand one block above it.
pub const FOUNTAIN_CRYSTAL_Y: i32 = 9;
pub const FOUNTAIN_CRYSTAL_POSITIONS: [FOUNTAIN_CRYSTAL_COUNT]IVec3 = .{
    .{ 0, FOUNTAIN_CRYSTAL_Y, -3 }, // north
    .{ 0, FOUNTAIN_CRYSTAL_Y, 3 }, // south
    .{ 3, FOUNTAIN_CRYSTAL_Y, 0 }, // east
    .{ -3, FOUNTAIN_CRYSTAL_Y, 0 }, // west
};

pub const RitualPhase = enum {
    charging_crystals,
    regenerating_pillars,
    sky_convergence,
    dragon_emerging,
    complete,
};

pub const Beam = struct {
    from: Vec3,
    to: Vec3,
    color: BeamColor,
};

pub const BeamColor = enum { magenta, purple };

pub const TickEvents = struct {
    phase: RitualPhase,
    ritual_tick: u16 = 0,
    fountain_beams: [FOUNTAIN_CRYSTAL_COUNT]?Beam = .{ null, null, null, null },
    sweep_beam: ?Beam = null,
    regenerated_pillar_index: ?usize = null,
    pillar_explosion_power: f32 = 0.0,
    pillar_crystals: [PILLAR_CRYSTAL_COUNT]?Vec3 = .{ null, null, null, null, null, null, null, null, null, null },
    convergence_beams: [PILLAR_CRYSTAL_COUNT]?Beam = .{ null, null, null, null, null, null, null, null, null, null },
    sphere_center: ?Vec3 = null,
    sphere_radius: f32 = 0.0,
    final_explosion: bool = false,
    final_explosion_power: f32 = 0.0,
    fountain_crystals_consumed: bool = false,
    portal_blocks: ?[PORTAL_BLOCK_COUNT]BlockId = null,
    dragon_respawned: bool = false,
    dragon_health: f32 = 0.0,
};

pub const PortalState = struct {
    active: bool = false,
    blocks: [PORTAL_BLOCK_COUNT]BlockId = portalBlocks(.air),
};

pub const DragonRespawnRitual = struct {
    phase: RitualPhase = .charging_crystals,
    is_ritual_active: bool = false,
    elapsed_ticks: u16 = 0,
    fountain_crystals: [FOUNTAIN_CRYSTAL_COUNT]bool = .{ false, false, false, false },
    pillar_crystals: [PILLAR_CRYSTAL_COUNT]bool = .{ false, false, false, false, false, false, false, false, false, false },
    dragon_alive: bool = true,
    exit_portal: PortalState = .{},

    /// Adds a crystal at one of the four exact cardinal fountain positions.
    /// The fourth distinct valid placement starts the 600-tick ritual.
    pub fn placeFountainCrystal(self: *DragonRespawnRitual, pos: IVec3) bool {
        if (!self.exit_portal.active or self.dragon_alive or self.is_ritual_active) return false;
        for (FOUNTAIN_CRYSTAL_POSITIONS, 0..) |required, index| {
            if (!samePosition(pos, required)) continue;
            if (self.fountain_crystals[index]) return false;
            self.fountain_crystals[index] = true;
            if (allFountainCrystals(self.fountain_crystals)) {
                self.is_ritual_active = true;
                self.phase = .charging_crystals;
                self.elapsed_ticks = 0;
            }
            return true;
        }
        return false;
    }

    /// Advances exactly one 20 Hz ritual tick and returns caller-applied visual/world events.
    pub fn tick(self: *DragonRespawnRitual) TickEvents {
        var events = TickEvents{ .phase = self.phase };
        if (!self.is_ritual_active or self.phase == .complete) return events;

        self.elapsed_ticks += 1;
        events.ritual_tick = self.elapsed_ticks;
        self.phase = phaseAtTick(self.elapsed_ticks);
        events.phase = self.phase;

        if (self.elapsed_ticks < CHARGING_END_TICK) {
            for (FOUNTAIN_CRYSTAL_POSITIONS, 0..) |pos, index| {
                events.fountain_beams[index] = .{
                    .from = .{ @floatFromInt(pos[0]), @floatFromInt(pos[1]), @floatFromInt(pos[2]) },
                    .to = .{ @floatFromInt(pos[0]), 256.0, @floatFromInt(pos[2]) },
                    .color = .magenta,
                };
            }
        } else if (self.elapsed_ticks < PILLAR_REGENERATION_END_TICK) {
            const regeneration_index: usize = @intCast((self.elapsed_ticks - CHARGING_END_TICK) / 30);
            if (regeneration_index < PILLAR_CRYSTAL_COUNT and (self.elapsed_ticks - CHARGING_END_TICK) % 30 == 0) {
                self.pillar_crystals[regeneration_index] = true;
                events.regenerated_pillar_index = regeneration_index;
                events.pillar_explosion_power = PILLAR_EXPLOSION_POWER;
                events.pillar_crystals[regeneration_index] = pillarCrystalPosition(regeneration_index);
            }
            events.sweep_beam = radialSweepBeam(self.elapsed_ticks);
        } else if (self.elapsed_ticks < CONVERGENCE_END_TICK) {
            for (0..PILLAR_CRYSTAL_COUNT) |index| {
                const from = pillarCrystalPosition(index);
                events.convergence_beams[index] = .{ .from = from, .to = SKY_APEX, .color = .purple };
            }
        } else if (self.elapsed_ticks < RITUAL_DURATION_TICKS) {
            events.sphere_center = SKY_APEX;
            events.sphere_radius = @as(f32, @floatFromInt(self.elapsed_ticks - CONVERGENCE_END_TICK)) * 0.2;
        } else {
            self.phase = .complete;
            self.is_ritual_active = false;
            self.dragon_alive = true;
            self.exit_portal.active = false;
            self.exit_portal.blocks = portalBlocks(.air);
            self.fountain_crystals = .{ false, false, false, false };
            events.phase = .complete;
            events.final_explosion = true;
            events.final_explosion_power = FINAL_EXPLOSION_POWER;
            events.fountain_crystals_consumed = true;
            events.portal_blocks = self.exit_portal.blocks;
            events.dragon_respawned = true;
            events.dragon_health = DRAGON_MAX_HEALTH;
        }
        return events;
    }

    /// The arena fight calls this after the respawned dragon is defeated.
    pub fn dragonDefeated(self: *DragonRespawnRitual) void {
        self.dragon_alive = false;
        self.exit_portal.active = true;
        self.exit_portal.blocks = portalBlocks(.end_portal);
        self.phase = .charging_crystals;
        self.elapsed_ticks = 0;
        self.fountain_crystals = .{ false, false, false, false };
    }
};

pub fn isCardinalFountainPosition(pos: IVec3) bool {
    for (FOUNTAIN_CRYSTAL_POSITIONS) |required| {
        if (samePosition(pos, required)) return true;
    }
    return false;
}

pub fn phaseAtTick(tick: u16) RitualPhase {
    if (tick < CHARGING_END_TICK) return .charging_crystals;
    if (tick < PILLAR_REGENERATION_END_TICK) return .regenerating_pillars;
    if (tick < CONVERGENCE_END_TICK) return .sky_convergence;
    if (tick < RITUAL_DURATION_TICKS) return .dragon_emerging;
    return .complete;
}

pub fn pillarCrystalPosition(index: usize) Vec3 {
    if (index >= PILLAR_CRYSTAL_COUNT) return .{ 0.0, 82.0, 0.0 };
    const angle = 2.0 * std.math.pi * @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(PILLAR_CRYSTAL_COUNT));
    return .{ @cos(angle) * 42.0, 82.0, @sin(angle) * 42.0 };
}

fn radialSweepBeam(tick: u16) Beam {
    const progress = @as(f32, @floatFromInt(tick - CHARGING_END_TICK)) / @as(f32, @floatFromInt(PILLAR_REGENERATION_END_TICK - CHARGING_END_TICK));
    const angle = progress * 2.0 * std.math.pi;
    return .{
        .from = .{ 0.0, 100.0, 0.0 },
        .to = .{ @cos(angle) * 64.0, 82.0, @sin(angle) * 64.0 },
        .color = .magenta,
    };
}

fn allFountainCrystals(crystals: [FOUNTAIN_CRYSTAL_COUNT]bool) bool {
    for (crystals) |present| if (!present) return false;
    return true;
}

fn samePosition(a: IVec3, b: IVec3) bool {
    return a[0] == b[0] and a[1] == b[1] and a[2] == b[2];
}

fn portalBlocks(comptime block: BlockId) [PORTAL_BLOCK_COUNT]BlockId {
    return .{ block, block, block, block, block, block, block, block, block };
}

test "north cardinal crystal placement coordinate is valid" {
    try std.testing.expect(isCardinalFountainPosition(.{ 0, FOUNTAIN_CRYSTAL_Y, -3 }));
}
test "south cardinal crystal placement coordinate is valid" {
    try std.testing.expect(isCardinalFountainPosition(.{ 0, FOUNTAIN_CRYSTAL_Y, 3 }));
}
test "east cardinal crystal placement coordinate is valid" {
    try std.testing.expect(isCardinalFountainPosition(.{ 3, FOUNTAIN_CRYSTAL_Y, 0 }));
}
test "west cardinal crystal placement coordinate is valid" {
    try std.testing.expect(isCardinalFountainPosition(.{ -3, FOUNTAIN_CRYSTAL_Y, 0 }));
}
test "north crystal rejects a one-block coordinate offset" {
    try std.testing.expect(!isCardinalFountainPosition(.{ 1, FOUNTAIN_CRYSTAL_Y, -3 }));
}
test "south crystal rejects a one-block coordinate offset" {
    try std.testing.expect(!isCardinalFountainPosition(.{ 0, FOUNTAIN_CRYSTAL_Y, 2 }));
}
test "east crystal rejects a one-block coordinate offset" {
    try std.testing.expect(!isCardinalFountainPosition(.{ 2, FOUNTAIN_CRYSTAL_Y, 0 }));
}
test "west crystal rejects a one-block coordinate offset" {
    try std.testing.expect(!isCardinalFountainPosition(.{ -2, FOUNTAIN_CRYSTAL_Y, 0 }));
}
test "cardinal positions require the fountain crystal height" {
    try std.testing.expect(!isCardinalFountainPosition(.{ 0, FOUNTAIN_CRYSTAL_Y + 1, -3 }));
}
test "a living dragon keeps the exit portal inactive and rejects crystal placement" {
    var r = DragonRespawnRitual{};
    try std.testing.expect(r.dragon_alive);
    try std.testing.expect(!r.exit_portal.active);
    try std.testing.expect(!r.placeFountainCrystal(FOUNTAIN_CRYSTAL_POSITIONS[0]));
}
test "one placed fountain crystal leaves the ritual dormant" {
    var r = readyRitual();
    try std.testing.expect(r.placeFountainCrystal(FOUNTAIN_CRYSTAL_POSITIONS[0]));
    try std.testing.expect(!r.is_ritual_active);
}
test "two placed fountain crystals leave the ritual dormant" {
    var r = readyRitual();
    _ = r.placeFountainCrystal(FOUNTAIN_CRYSTAL_POSITIONS[0]);
    _ = r.placeFountainCrystal(FOUNTAIN_CRYSTAL_POSITIONS[1]);
    try std.testing.expect(!r.is_ritual_active);
}
test "three placed fountain crystals leave the ritual dormant" {
    var r = readyRitual();
    for (FOUNTAIN_CRYSTAL_POSITIONS[0..3]) |pos| _ = r.placeFountainCrystal(pos);
    try std.testing.expect(!r.is_ritual_active);
}
test "all four distinct cardinal crystals activate the ritual" {
    var r = readyRitual();
    for (FOUNTAIN_CRYSTAL_POSITIONS) |pos| _ = r.placeFountainCrystal(pos);
    try std.testing.expect(r.is_ritual_active);
}
test "duplicate placement does not count as another fountain crystal" {
    var r = readyRitual();
    _ = r.placeFountainCrystal(FOUNTAIN_CRYSTAL_POSITIONS[0]);
    try std.testing.expect(!r.placeFountainCrystal(FOUNTAIN_CRYSTAL_POSITIONS[0]));
    try std.testing.expect(!r.is_ritual_active);
}
test "off-rim placement is rejected without changing the ritual" {
    var r = readyRitual();
    try std.testing.expect(!r.placeFountainCrystal(.{ 2, FOUNTAIN_CRYSTAL_Y, -2 }));
    try std.testing.expect(!r.is_ritual_active);
}
test "ritual begins in the charging phase at tick zero" {
    const r = startedRitual();
    try std.testing.expectEqual(RitualPhase.charging_crystals, r.phase);
    try std.testing.expectEqual(@as(u16, 0), r.elapsed_ticks);
}
test "first ritual tick emits four upward magenta beams" {
    var r = startedRitual();
    const e = r.tick();
    for (e.fountain_beams) |beam| {
        try std.testing.expect(beam != null);
        try std.testing.expectEqual(BeamColor.magenta, beam.?.color);
        try std.testing.expectEqual(@as(f32, 256.0), beam.?.to[1]);
    }
}
test "charging phase lasts through tick 99" {
    try std.testing.expectEqual(RitualPhase.charging_crystals, phaseAtTick(99));
}
test "pillar regeneration phase starts at tick 100" {
    try std.testing.expectEqual(RitualPhase.regenerating_pillars, phaseAtTick(100));
}
test "pillar convergence phase starts at tick 400" {
    try std.testing.expectEqual(RitualPhase.sky_convergence, phaseAtTick(400));
}
test "dragon emergence phase starts at tick 500" {
    try std.testing.expectEqual(RitualPhase.dragon_emerging, phaseAtTick(500));
}
test "ritual completes at tick 600" {
    try std.testing.expectEqual(RitualPhase.complete, phaseAtTick(600));
}
test "ritual remains dormant without a full crystal set" {
    var r = DragonRespawnRitual{};
    _ = r.tick();
    try std.testing.expectEqual(@as(u16, 0), r.elapsed_ticks);
}
test "pillar crystals regenerate one at a time every thirty ticks" {
    var r = startedRitual();
    var regen_count: usize = 0;
    for (0..400) |_| {
        const e = r.tick();
        if (e.regenerated_pillar_index) |index| {
            try std.testing.expectEqual(regen_count, index);
            regen_count += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 10), regen_count);
}
test "pillar regeneration heals every previously broken crystal" {
    var r = startedRitual();
    for (0..400) |_| _ = r.tick();
    for (r.pillar_crystals) |intact| try std.testing.expect(intact);
}
test "pillar regeneration event includes a crystal and explosion burst" {
    var r = startedRitual();
    for (0..99) |_| _ = r.tick();
    const e = r.tick();
    try std.testing.expectEqual(@as(usize, 0), e.regenerated_pillar_index.?);
    try std.testing.expectEqual(PILLAR_EXPLOSION_POWER, e.pillar_explosion_power);
    try std.testing.expect(e.pillar_crystals[0] != null);
}
test "pillar crystal positions form ten points around the obsidian pillar ring" {
    for (0..PILLAR_CRYSTAL_COUNT) |i| {
        const p = pillarCrystalPosition(i);
        try std.testing.expectApproxEqAbs(@as(f32, 42.0), @sqrt(p[0] * p[0] + p[2] * p[2]), 0.01);
        try std.testing.expectEqual(@as(f32, 82.0), p[1]);
    }
}
test "radial sweep beam is emitted during pillar regeneration" {
    var r = startedRitual();
    for (0..100) |_| _ = r.tick();
    const e = r.tick();
    try std.testing.expect(e.sweep_beam != null);
    try std.testing.expectEqual(BeamColor.magenta, e.sweep_beam.?.color);
}
test "convergence emits ten purple tethers to the sky apex" {
    var r = startedRitual();
    for (0..400) |_| _ = r.tick();
    const e = r.tick();
    for (e.convergence_beams) |beam| {
        try std.testing.expect(beam != null);
        try std.testing.expectEqual(BeamColor.purple, beam.?.color);
        try std.testing.expectEqualSlices(f32, &SKY_APEX, &beam.?.to);
    }
}
test "convergence apex is exactly zero one hundred zero" {
    try std.testing.expectEqualSlices(f32, &([_]f32{ 0.0, 100.0, 0.0 }), &SKY_APEX);
}
test "emergence sphere expands from the convergence apex" {
    var r = startedRitual();
    for (0..500) |_| _ = r.tick();
    const e = r.tick();
    try std.testing.expectEqualSlices(f32, &SKY_APEX, &e.sphere_center.?);
    try std.testing.expect(e.sphere_radius > 0.0);
}
test "ritual duration is exactly six hundred ticks" {
    var r = startedRitual();
    for (0..599) |_| _ = r.tick();
    try std.testing.expect(r.dragon_alive == false);
    const e = r.tick();
    try std.testing.expectEqual(@as(u16, 600), e.ritual_tick);
    try std.testing.expect(e.dragon_respawned);
}
test "final tick emits a power twelve explosion" {
    var r = startedRitual();
    for (0..600) |_| {
        const e = r.tick();
        if (e.final_explosion) try std.testing.expectEqual(FINAL_EXPLOSION_POWER, e.final_explosion_power);
    }
    try std.testing.expect(r.dragon_alive);
}
test "completion consumes all four fountain crystals" {
    var r = startedRitual();
    for (0..600) |_| _ = r.tick();
    try std.testing.expectEqual([4]bool{ false, false, false, false }, r.fountain_crystals);
}
test "completion deactivates the exit portal into empty air" {
    var r = startedRitual();
    for (0..600) |_| _ = r.tick();
    try std.testing.expect(!r.exit_portal.active);
    for (r.exit_portal.blocks) |block| try std.testing.expectEqual(BlockId.air, block);
}
test "portal deactivation event reports nine air blocks" {
    var r = startedRitual();
    var final = TickEvents{ .phase = .complete };
    for (0..600) |_| final = r.tick();
    for (final.portal_blocks.?) |block| try std.testing.expectEqual(BlockId.air, block);
}
test "respawned Ender Dragon has full two hundred health" {
    var r = startedRitual();
    var final = TickEvents{ .phase = .complete };
    for (0..600) |_| final = r.tick();
    try std.testing.expectEqual(DRAGON_MAX_HEALTH, final.dragon_health);
}
test "crystals cannot restart the ritual while the dragon lives" {
    var r = startedRitual();
    for (0..600) |_| _ = r.tick();
    try std.testing.expect(!r.placeFountainCrystal(FOUNTAIN_CRYSTAL_POSITIONS[0]));
}
test "dragon defeat restores the exit portal and permits another ritual" {
    var r = startedRitual();
    for (0..600) |_| _ = r.tick();
    r.dragonDefeated();
    try std.testing.expect(!r.dragon_alive);
    try std.testing.expect(r.exit_portal.active);
    for (r.exit_portal.blocks) |block| try std.testing.expectEqual(BlockId.end_portal, block);
    try std.testing.expect(r.placeFountainCrystal(FOUNTAIN_CRYSTAL_POSITIONS[0]));
}

fn startedRitual() DragonRespawnRitual {
    var ritual = readyRitual();
    for (FOUNTAIN_CRYSTAL_POSITIONS) |pos| _ = ritual.placeFountainCrystal(pos);
    return ritual;
}

fn readyRitual() DragonRespawnRitual {
    var ritual = DragonRespawnRitual{};
    ritual.dragonDefeated();
    return ritual;
}
