const std = @import("std");
pub const copper = @import("copper.zig");

/// Maximum number of copper fixtures tracked in a spatial collection.
pub const max_tracked_fixtures: usize = 64;

/// Time in seconds required for one oxidation stage progression (45 seconds, matching copper.zig).
pub const oxidation_stage_time: f32 = 45.0;

/// Default bulb light emission levels per oxidation stage when lit.
pub const bulb_light_unoxidized: u8 = 15;
pub const bulb_light_exposed: u8 = 12;
pub const bulb_light_weathered: u8 = 8;
pub const bulb_light_oxidized: u8 = 4;
pub const bulb_light_unlit: u8 = 0;

/// Comparator signal levels for copper bulb.
pub const bulb_comparator_signal_lit: u8 = 15;
pub const bulb_comparator_signal_unlit: u8 = 0;

/// Types of copper fixtures introduced in Milestone 303.
pub const CopperFixtureKind = enum(u8) {
    copper_door = 0,
    copper_trapdoor = 1,
    copper_grate = 2,
    chiseled_copper = 3,
    copper_bulb = 4,

    pub fn isDoorOrTrapdoor(self: CopperFixtureKind) bool {
        return self == .copper_door or self == .copper_trapdoor;
    }

    pub fn isBulb(self: CopperFixtureKind) bool {
        return self == .copper_bulb;
    }

    pub fn isGrate(self: CopperFixtureKind) bool {
        return self == .copper_grate;
    }

    pub fn isChiseled(self: CopperFixtureKind) bool {
        return self == .chiseled_copper;
    }
};

/// Oxidation stages for copper fixtures:
/// unoxidized (clean copper) -> exposed -> weathered -> oxidized.
pub const CopperOxidationStage = enum(u8) {
    unoxidized = 0,
    exposed = 1,
    weathered = 2,
    oxidized = 3,

    pub fn next(self: CopperOxidationStage) ?CopperOxidationStage {
        return switch (self) {
            .unoxidized => .exposed,
            .exposed => .weathered,
            .weathered => .oxidized,
            .oxidized => null,
        };
    }

    pub fn prev(self: CopperOxidationStage) ?CopperOxidationStage {
        return switch (self) {
            .oxidized => .weathered,
            .weathered => .exposed,
            .exposed => .unoxidized,
            .unoxidized => null,
        };
    }

    pub fn toCopperOxidation(self: CopperOxidationStage) copper.OxidationStage {
        return switch (self) {
            .unoxidized => .clean,
            .exposed => .exposed,
            .weathered => .weathered,
            .oxidized => .oxidized,
        };
    }

    pub fn fromCopperOxidation(stage: copper.OxidationStage) CopperOxidationStage {
        return switch (stage) {
            .clean => .unoxidized,
            .exposed => .exposed,
            .weathered => .weathered,
            .oxidized => .oxidized,
        };
    }
};

pub fn nextStage(stage: CopperOxidationStage) ?CopperOxidationStage {
    return stage.next();
}

pub fn prevStage(stage: CopperOxidationStage) ?CopperOxidationStage {
    return stage.prev();
}

pub fn nextOxidationStage(stage: CopperOxidationStage) ?CopperOxidationStage {
    return stage.next();
}

pub fn prevOxidationStage(stage: CopperOxidationStage) ?CopperOxidationStage {
    return stage.prev();
}

pub fn toCopperOxidation(stage: CopperOxidationStage) copper.OxidationStage {
    return stage.toCopperOxidation();
}

pub fn fromCopperOxidation(stage: copper.OxidationStage) CopperOxidationStage {
    return CopperOxidationStage.fromCopperOxidation(stage);
}

/// State tracking for any copper fixture block instance.
pub const CopperFixtureState = struct {
    kind: CopperFixtureKind,
    stage: CopperOxidationStage = .unoxidized,
    is_waxed: bool = false,
    is_open: bool = false,
    powered_prev: bool = false,
    bulb_lit: bool = false,
    oxidation_timer: f32 = 0.0,
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,

    pub fn init(kind: CopperFixtureKind, stage: CopperOxidationStage) CopperFixtureState {
        return .{
            .kind = kind,
            .stage = stage,
            .is_waxed = false,
            .is_open = false,
            .powered_prev = false,
            .bulb_lit = false,
            .oxidation_timer = 0.0,
            .x = 0,
            .y = 0,
            .z = 0,
        };
    }

    pub fn initWaxed(kind: CopperFixtureKind, stage: CopperOxidationStage) CopperFixtureState {
        var s = init(kind, stage);
        s.is_waxed = true;
        return s;
    }

    pub fn initAt(kind: CopperFixtureKind, stage: CopperOxidationStage, x: i32, y: i32, z: i32) CopperFixtureState {
        var s = init(kind, stage);
        s.x = x;
        s.y = y;
        s.z = z;
        return s;
    }

    /// Player hand right-click interaction.
    /// Toggles is_open for copper doors and copper trapdoors.
    /// Returns true if toggled, false if fixture does not respond to hand toggling.
    pub fn interactHand(self: *CopperFixtureState) bool {
        if (self.kind.isDoorOrTrapdoor()) {
            self.is_open = !self.is_open;
            return true;
        }
        return false;
    }

    /// Redstone power state update.
    /// For copper doors & trapdoors:
    ///   - Rising edge (!powered_prev and powered_now): opens the door/trapdoor (is_open = true).
    ///   - Falling edge (powered_prev and !powered_now): closes the door/trapdoor (is_open = false).
    /// For copper bulb:
    ///   - Acts as a T-flip-flop: rising edge (!powered_prev and powered_now) toggles bulb_lit.
    ///   - Falling edge updates powered_prev but preserves bulb_lit.
    /// Returns true if an edge was processed and produced a state change.
    pub fn updateRedstonePower(self: *CopperFixtureState, powered_now: bool) bool {
        if (self.powered_prev == powered_now) return false;
        const is_rising = !self.powered_prev and powered_now;
        self.powered_prev = powered_now;

        switch (self.kind) {
            .copper_door, .copper_trapdoor => {
                self.is_open = powered_now;
                return true;
            },
            .copper_bulb => {
                if (is_rising) {
                    self.bulb_lit = !self.bulb_lit;
                    return true;
                }
                return false;
            },
            .copper_grate, .chiseled_copper => return false,
        }
    }

    /// Wind Charge burst impact.
    /// Toggles is_open for copper doors and copper trapdoors.
    /// Returns true if toggled.
    pub fn triggerWindBurst(self: *CopperFixtureState) bool {
        if (self.kind.isDoorOrTrapdoor()) {
            self.is_open = !self.is_open;
            return true;
        }
        return false;
    }

    /// Apply honeycomb to wax the fixture, preventing further oxidation.
    /// Returns true if successfully waxed, false if already waxed.
    pub fn applyHoneycomb(self: *CopperFixtureState) bool {
        if (self.is_waxed) return false;
        self.is_waxed = true;
        self.oxidation_timer = 0.0;
        return true;
    }

    /// Synonym for applyHoneycomb.
    pub fn applyWax(self: *CopperFixtureState) bool {
        return self.applyHoneycomb();
    }

    /// Scrape the fixture with an axe:
    /// 1. If waxed, strips the wax layer (resets timer, keeps stage).
    /// 2. If unwaxed and oxidized/weathered/exposed, regresses one oxidation stage (resets timer).
    /// 3. If unwaxed and already unoxidized, cannot be scraped further (returns false).
    pub fn scrapeWithAxe(self: *CopperFixtureState) bool {
        if (self.is_waxed) {
            self.is_waxed = false;
            self.oxidation_timer = 0.0;
            return true;
        }
        if (self.stage.prev()) |prev_stage| {
            self.stage = prev_stage;
            self.oxidation_timer = 0.0;
            return true;
        }
        return false;
    }

    /// Ticks the oxidation timer.
    /// If unwaxed and not fully oxidized, advances oxidation_timer.
    /// When oxidation_timer reaches oxidation_stage_time, steps up stage.
    /// Returns true if the oxidation stage advanced.
    pub fn tickOxidation(self: *CopperFixtureState, dt: f32) bool {
        if (self.is_waxed or self.stage == .oxidized) return false;
        self.oxidation_timer += dt;
        if (self.oxidation_timer >= oxidation_stage_time) {
            self.oxidation_timer -= oxidation_stage_time;
            if (self.stage.next()) |next_stage| {
                self.stage = next_stage;
            }
            if (self.stage == .oxidized) {
                self.oxidation_timer = 0.0;
            }
            return true;
        }
        return false;
    }

    /// Emitted light level:
    /// - For copper bulb: 15 (unoxidized), 12 (exposed), 8 (weathered), 4 (oxidized) when lit, 0 when unlit.
    /// - For other fixtures: 0.
    pub fn getLightLevel(self: CopperFixtureState) u8 {
        if (self.kind != .copper_bulb or !self.bulb_lit) return 0;
        return bulbLightLevel(self.stage, self.bulb_lit);
    }

    /// Redstone comparator output:
    /// - For copper bulb: 15 when lit, 0 when unlit.
    /// - For other fixtures: 0.
    pub fn getComparatorOutput(self: CopperFixtureState) u8 {
        if (self.kind != .copper_bulb) return 0;
        return if (self.bulb_lit) bulb_comparator_signal_lit else bulb_comparator_signal_unlit;
    }

    pub fn getComparatorSignal(self: CopperFixtureState) u8 {
        return self.getComparatorOutput();
    }

    /// Copper Grate allows waterlogging; other fixtures do not.
    pub fn allowsWaterlogging(self: CopperFixtureState) bool {
        return self.kind == .copper_grate;
    }

    /// Projectile collision blocking:
    /// - Copper grates allow projectiles to pass through (false).
    /// - Doors & trapdoors block projectiles when closed (!is_open), allow through when open.
    /// - Chiseled copper and bulbs block projectiles (true).
    pub fn blocksProjectiles(self: CopperFixtureState) bool {
        return switch (self.kind) {
            .copper_grate => false,
            .copper_door, .copper_trapdoor => !self.is_open,
            .chiseled_copper, .copper_bulb => true,
        };
    }

    /// Mob suffocation:
    /// - Mobs never suffocate inside copper grates (immunity) or open/closed doors/trapdoors.
    /// - Solid fixtures (chiseled copper, copper bulbs) suffocate mobs.
    pub fn suffocatesMobs(self: CopperFixtureState) bool {
        return switch (self.kind) {
            .copper_grate, .copper_door, .copper_trapdoor => false,
            .chiseled_copper, .copper_bulb => true,
        };
    }
};

// -------------------------------------------------------------------------
// Free-standing procedural wrappers and query helpers
// -------------------------------------------------------------------------

pub fn interactHand(state: *CopperFixtureState) bool {
    return state.interactHand();
}

pub fn updateRedstonePower(state: *CopperFixtureState, powered_now: bool) bool {
    return state.updateRedstonePower(powered_now);
}

pub fn triggerWindBurst(state: *CopperFixtureState) bool {
    return state.triggerWindBurst();
}

pub fn applyHoneycomb(state: *CopperFixtureState) bool {
    return state.applyHoneycomb();
}

pub fn applyWax(state: *CopperFixtureState) bool {
    return state.applyWax();
}

pub fn scrapeWithAxe(state: *CopperFixtureState) bool {
    return state.scrapeWithAxe();
}

pub fn tickOxidation(state: *CopperFixtureState, dt: f32) bool {
    return state.tickOxidation(dt);
}

pub fn getLightLevel(state: CopperFixtureState) u8 {
    return state.getLightLevel();
}

pub fn getComparatorOutput(state: CopperFixtureState) u8 {
    return state.getComparatorOutput();
}

pub fn getComparatorSignal(state: CopperFixtureState) u8 {
    return state.getComparatorSignal();
}

pub fn allowsWaterlogging(kind: CopperFixtureKind) bool {
    return kind == .copper_grate;
}

pub fn blocksProjectiles(kind: CopperFixtureKind) bool {
    return kind != .copper_grate;
}

pub fn suffocatesMobs(kind: CopperFixtureKind) bool {
    return switch (kind) {
        .copper_grate, .copper_door, .copper_trapdoor => false,
        .chiseled_copper, .copper_bulb => true,
    };
}

/// Calculate bulb light level directly given stage and lit state.
pub fn bulbLightLevel(stage: CopperOxidationStage, is_lit: bool) u8 {
    if (!is_lit) return bulb_light_unlit;
    return switch (stage) {
        .unoxidized => bulb_light_unoxidized,
        .exposed => bulb_light_exposed,
        .weathered => bulb_light_weathered,
        .oxidized => bulb_light_oxidized,
    };
}

/// Calculate bulb comparator signal directly given lit state.
pub fn bulbComparatorSignal(is_lit: bool) u8 {
    return if (is_lit) bulb_comparator_signal_lit else bulb_comparator_signal_unlit;
}

/// Find a tracked copper fixture in a slice by coordinates.
pub fn findFixture(items: []const CopperFixtureState, count: usize, x: i32, y: i32, z: i32) ?usize {
    const n = @min(count, items.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const it = items[i];
        if (it.x == x and it.y == y and it.z == z) return i;
    }
    return null;
}

/// Canonical human-readable display name for any fixture variant.
pub fn getDisplayName(kind: CopperFixtureKind, stage: CopperOxidationStage, is_waxed: bool) []const u8 {
    return switch (kind) {
        .copper_door => switch (stage) {
            .unoxidized => if (is_waxed) "Waxed Copper Door" else "Copper Door",
            .exposed => if (is_waxed) "Waxed Exposed Copper Door" else "Exposed Copper Door",
            .weathered => if (is_waxed) "Waxed Weathered Copper Door" else "Weathered Copper Door",
            .oxidized => if (is_waxed) "Waxed Oxidized Copper Door" else "Oxidized Copper Door",
        },
        .copper_trapdoor => switch (stage) {
            .unoxidized => if (is_waxed) "Waxed Copper Trapdoor" else "Copper Trapdoor",
            .exposed => if (is_waxed) "Waxed Exposed Copper Trapdoor" else "Exposed Copper Trapdoor",
            .weathered => if (is_waxed) "Waxed Weathered Copper Trapdoor" else "Weathered Copper Trapdoor",
            .oxidized => if (is_waxed) "Waxed Oxidized Copper Trapdoor" else "Oxidized Copper Trapdoor",
        },
        .copper_grate => switch (stage) {
            .unoxidized => if (is_waxed) "Waxed Copper Grate" else "Copper Grate",
            .exposed => if (is_waxed) "Waxed Exposed Copper Grate" else "Exposed Copper Grate",
            .weathered => if (is_waxed) "Waxed Weathered Copper Grate" else "Weathered Copper Grate",
            .oxidized => if (is_waxed) "Waxed Oxidized Copper Grate" else "Oxidized Copper Grate",
        },
        .chiseled_copper => switch (stage) {
            .unoxidized => if (is_waxed) "Waxed Chiseled Copper" else "Chiseled Copper",
            .exposed => if (is_waxed) "Waxed Exposed Chiseled Copper" else "Exposed Chiseled Copper",
            .weathered => if (is_waxed) "Waxed Weathered Chiseled Copper" else "Weathered Chiseled Copper",
            .oxidized => if (is_waxed) "Waxed Oxidized Chiseled Copper" else "Oxidized Chiseled Copper",
        },
        .copper_bulb => switch (stage) {
            .unoxidized => if (is_waxed) "Waxed Copper Bulb" else "Copper Bulb",
            .exposed => if (is_waxed) "Waxed Exposed Copper Bulb" else "Exposed Copper Bulb",
            .weathered => if (is_waxed) "Waxed Weathered Copper Bulb" else "Weathered Copper Bulb",
            .oxidized => if (is_waxed) "Waxed Oxidized Copper Bulb" else "Oxidized Copper Bulb",
        },
    };
}

// -------------------------------------------------------------------------
// Unit Tests (At least 14 tests required by Milestone 303)
// -------------------------------------------------------------------------

test "constants: oxidation stage time and bulb levels" {
    try std.testing.expectEqual(@as(usize, 64), max_tracked_fixtures);
    try std.testing.expectEqual(@as(f32, 45.0), oxidation_stage_time);
    try std.testing.expectEqual(@as(u8, 15), bulb_light_unoxidized);
    try std.testing.expectEqual(@as(u8, 12), bulb_light_exposed);
    try std.testing.expectEqual(@as(u8, 8), bulb_light_weathered);
    try std.testing.expectEqual(@as(u8, 4), bulb_light_oxidized);
    try std.testing.expectEqual(@as(u8, 0), bulb_light_unlit);
    try std.testing.expectEqual(@as(u8, 15), bulb_comparator_signal_lit);
    try std.testing.expectEqual(@as(u8, 0), bulb_comparator_signal_unlit);
}

test "kind enum helpers: door, trapdoor, grate, chiseled, bulb identification" {
    const door = CopperFixtureKind.copper_door;
    const trapdoor = CopperFixtureKind.copper_trapdoor;
    const grate = CopperFixtureKind.copper_grate;
    const chiseled = CopperFixtureKind.chiseled_copper;
    const bulb = CopperFixtureKind.copper_bulb;

    try std.testing.expect(door.isDoorOrTrapdoor());
    try std.testing.expect(trapdoor.isDoorOrTrapdoor());
    try std.testing.expect(!grate.isDoorOrTrapdoor());
    try std.testing.expect(!chiseled.isDoorOrTrapdoor());
    try std.testing.expect(!bulb.isDoorOrTrapdoor());

    try std.testing.expect(grate.isGrate());
    try std.testing.expect(!door.isGrate());

    try std.testing.expect(chiseled.isChiseled());
    try std.testing.expect(!grate.isChiseled());

    try std.testing.expect(bulb.isBulb());
    try std.testing.expect(!chiseled.isBulb());
}

test "oxidation stage progression next and prev" {
    try std.testing.expectEqual(CopperOxidationStage.exposed, CopperOxidationStage.unoxidized.next().?);
    try std.testing.expectEqual(CopperOxidationStage.weathered, CopperOxidationStage.exposed.next().?);
    try std.testing.expectEqual(CopperOxidationStage.oxidized, CopperOxidationStage.weathered.next().?);
    try std.testing.expectEqual(@as(?CopperOxidationStage, null), CopperOxidationStage.oxidized.next());

    try std.testing.expectEqual(CopperOxidationStage.weathered, CopperOxidationStage.oxidized.prev().?);
    try std.testing.expectEqual(CopperOxidationStage.exposed, CopperOxidationStage.weathered.prev().?);
    try std.testing.expectEqual(CopperOxidationStage.unoxidized, CopperOxidationStage.exposed.prev().?);
    try std.testing.expectEqual(@as(?CopperOxidationStage, null), CopperOxidationStage.unoxidized.prev());

    try std.testing.expectEqual(CopperOxidationStage.exposed, nextStage(.unoxidized).?);
    try std.testing.expectEqual(CopperOxidationStage.unoxidized, prevStage(.exposed).?);
}

test "parity conversion with world/copper.zig OxidationStage" {
    try std.testing.expectEqual(copper.OxidationStage.clean, toCopperOxidation(.unoxidized));
    try std.testing.expectEqual(copper.OxidationStage.exposed, toCopperOxidation(.exposed));
    try std.testing.expectEqual(copper.OxidationStage.weathered, toCopperOxidation(.weathered));
    try std.testing.expectEqual(copper.OxidationStage.oxidized, toCopperOxidation(.oxidized));

    try std.testing.expectEqual(CopperOxidationStage.unoxidized, fromCopperOxidation(.clean));
    try std.testing.expectEqual(CopperOxidationStage.exposed, fromCopperOxidation(.exposed));
    try std.testing.expectEqual(CopperOxidationStage.weathered, fromCopperOxidation(.weathered));
    try std.testing.expectEqual(CopperOxidationStage.oxidized, fromCopperOxidation(.oxidized));
}

test "hand right-click toggles copper door and trapdoor" {
    var door = CopperFixtureState.init(.copper_door, .unoxidized);
    try std.testing.expect(!door.is_open);

    // Hand interaction toggles door open
    try std.testing.expect(door.interactHand());
    try std.testing.expect(door.is_open);

    // Second hand interaction toggles door closed
    try std.testing.expect(interactHand(&door));
    try std.testing.expect(!door.is_open);

    // Hand interaction toggles trapdoor open and closed
    var trapdoor = CopperFixtureState.init(.copper_trapdoor, .weathered);
    try std.testing.expect(!trapdoor.is_open);
    try std.testing.expect(trapdoor.interactHand());
    try std.testing.expect(trapdoor.is_open);
    try std.testing.expect(trapdoor.interactHand());
    try std.testing.expect(!trapdoor.is_open);
}

test "hand right-click fails on non-door fixtures" {
    var bulb = CopperFixtureState.init(.copper_bulb, .unoxidized);
    var grate = CopperFixtureState.init(.copper_grate, .unoxidized);
    var chiseled = CopperFixtureState.init(.chiseled_copper, .unoxidized);

    try std.testing.expect(!bulb.interactHand());
    try std.testing.expect(!bulb.is_open);

    try std.testing.expect(!grate.interactHand());
    try std.testing.expect(!grate.is_open);

    try std.testing.expect(!chiseled.interactHand());
    try std.testing.expect(!chiseled.is_open);
}

test "wind charge burst impact toggles copper door and trapdoor" {
    var door = CopperFixtureState.init(.copper_door, .exposed);
    try std.testing.expect(!door.is_open);

    // First burst opens the door
    try std.testing.expect(door.triggerWindBurst());
    try std.testing.expect(door.is_open);

    // Second burst closes the door
    try std.testing.expect(triggerWindBurst(&door));
    try std.testing.expect(!door.is_open);

    // Trapdoor reacts similarly
    var trapdoor = CopperFixtureState.init(.copper_trapdoor, .oxidized);
    try std.testing.expect(trapdoor.triggerWindBurst());
    try std.testing.expect(trapdoor.is_open);
    try std.testing.expect(trapdoor.triggerWindBurst());
    try std.testing.expect(!trapdoor.is_open);
}

test "wind charge burst impact does not affect grate, chiseled, or bulb" {
    var bulb = CopperFixtureState.init(.copper_bulb, .unoxidized);
    var grate = CopperFixtureState.init(.copper_grate, .weathered);
    var chiseled = CopperFixtureState.init(.chiseled_copper, .oxidized);

    try std.testing.expect(!bulb.triggerWindBurst());
    try std.testing.expect(!bulb.bulb_lit);

    try std.testing.expect(!grate.triggerWindBurst());
    try std.testing.expect(!grate.is_open);

    try std.testing.expect(!chiseled.triggerWindBurst());
    try std.testing.expect(!chiseled.is_open);
}

test "redstone power rising edge opens and falling edge closes copper door" {
    var door = CopperFixtureState.init(.copper_door, .unoxidized);
    try std.testing.expect(!door.is_open);
    try std.testing.expect(!door.powered_prev);

    // Rising edge: power applied -> door opens
    try std.testing.expect(door.updateRedstonePower(true));
    try std.testing.expect(door.is_open);
    try std.testing.expect(door.powered_prev);

    // Falling edge: power removed -> door closes
    try std.testing.expect(updateRedstonePower(&door, false));
    try std.testing.expect(!door.is_open);
    try std.testing.expect(!door.powered_prev);
}

test "redstone power rising edge opens and falling edge closes copper trapdoor" {
    var trapdoor = CopperFixtureState.init(.copper_trapdoor, .exposed);

    // Rising edge opens trapdoor
    try std.testing.expect(trapdoor.updateRedstonePower(true));
    try std.testing.expect(trapdoor.is_open);

    // Falling edge closes trapdoor
    try std.testing.expect(trapdoor.updateRedstonePower(false));
    try std.testing.expect(!trapdoor.is_open);
}

test "redstone power edge filtering ignores unchanged level" {
    var door = CopperFixtureState.init(.copper_door, .weathered);

    // First rising edge processes
    try std.testing.expect(door.updateRedstonePower(true));
    try std.testing.expect(door.is_open);

    // Same continuous high signal does not re-trigger
    try std.testing.expect(!door.updateRedstonePower(true));
    try std.testing.expect(door.is_open);

    // Falling edge processes
    try std.testing.expect(door.updateRedstonePower(false));
    try std.testing.expect(!door.is_open);

    // Same continuous low signal does not re-trigger
    try std.testing.expect(!door.updateRedstonePower(false));
    try std.testing.expect(!door.is_open);
}

test "copper bulb T-flip-flop toggles lit state on rising edge only" {
    var bulb = CopperFixtureState.init(.copper_bulb, .unoxidized);
    try std.testing.expect(!bulb.bulb_lit);
    try std.testing.expect(!bulb.powered_prev);

    // First rising edge: unlit -> lit
    try std.testing.expect(bulb.updateRedstonePower(true));
    try std.testing.expect(bulb.bulb_lit);
    try std.testing.expect(bulb.powered_prev);

    // Falling edge: bulb remains lit (T-flip-flop maintains internal bit)
    try std.testing.expect(!bulb.updateRedstonePower(false));
    try std.testing.expect(bulb.bulb_lit);
    try std.testing.expect(!bulb.powered_prev);

    // Second rising edge: lit -> unlit
    try std.testing.expect(updateRedstonePower(&bulb, true));
    try std.testing.expect(!bulb.bulb_lit);
    try std.testing.expect(bulb.powered_prev);

    // Falling edge: bulb remains unlit
    try std.testing.expect(!bulb.updateRedstonePower(false));
    try std.testing.expect(!bulb.bulb_lit);
}

test "copper bulb T-flip-flop continuous power holds state" {
    var bulb = CopperFixtureState.init(.copper_bulb, .exposed);

    _ = bulb.updateRedstonePower(true);
    try std.testing.expect(bulb.bulb_lit);

    // Holding power steady does not toggle the bulb
    try std.testing.expect(!bulb.updateRedstonePower(true));
    try std.testing.expect(bulb.bulb_lit);
}

test "copper bulb emits oxidation-dependent light levels: 15, 12, 8, 4 when lit and 0 when unlit" {
    var bulb_unox = CopperFixtureState.init(.copper_bulb, .unoxidized);
    var bulb_exp = CopperFixtureState.init(.copper_bulb, .exposed);
    var bulb_weath = CopperFixtureState.init(.copper_bulb, .weathered);
    var bulb_oxid = CopperFixtureState.init(.copper_bulb, .oxidized);

    // All unlit initially -> light level 0
    try std.testing.expectEqual(@as(u8, 0), bulb_unox.getLightLevel());
    try std.testing.expectEqual(@as(u8, 0), bulb_exp.getLightLevel());
    try std.testing.expectEqual(@as(u8, 0), bulb_weath.getLightLevel());
    try std.testing.expectEqual(@as(u8, 0), bulb_oxid.getLightLevel());

    // Power them on via rising edge
    _ = bulb_unox.updateRedstonePower(true);
    _ = bulb_exp.updateRedstonePower(true);
    _ = bulb_weath.updateRedstonePower(true);
    _ = bulb_oxid.updateRedstonePower(true);

    // Lit states emit oxidation-dependent levels
    try std.testing.expectEqual(@as(u8, 15), bulb_unox.getLightLevel());
    try std.testing.expectEqual(@as(u8, 12), bulb_exp.getLightLevel());
    try std.testing.expectEqual(@as(u8, 8), bulb_weath.getLightLevel());
    try std.testing.expectEqual(@as(u8, 4), bulb_oxid.getLightLevel());

    // Free function getLightLevel
    try std.testing.expectEqual(@as(u8, 15), getLightLevel(bulb_unox));
    try std.testing.expectEqual(@as(u8, 12), bulbLightLevel(.exposed, true));
    try std.testing.expectEqual(@as(u8, 0), bulbLightLevel(.unoxidized, false));

    // Non-bulb fixtures never emit light
    const door = CopperFixtureState.init(.copper_door, .unoxidized);
    try std.testing.expectEqual(@as(u8, 0), door.getLightLevel());
}

test "copper bulb comparator output emits 15 when lit and 0 when unlit across all stages" {
    var bulb = CopperFixtureState.init(.copper_bulb, .oxidized);

    // Unlit -> comparator 0
    try std.testing.expectEqual(@as(u8, 0), bulb.getComparatorOutput());
    try std.testing.expectEqual(@as(u8, 0), bulb.getComparatorSignal());
    try std.testing.expectEqual(@as(u8, 0), getComparatorOutput(bulb));
    try std.testing.expectEqual(@as(u8, 0), bulbComparatorSignal(false));

    // Turn lit via redstone pulse
    _ = bulb.updateRedstonePower(true);
    try std.testing.expect(bulb.bulb_lit);

    // Lit -> comparator 15 (even for oxidized stage)
    try std.testing.expectEqual(@as(u8, 15), bulb.getComparatorOutput());
    try std.testing.expectEqual(@as(u8, 15), bulb.getComparatorSignal());
    try std.testing.expectEqual(@as(u8, 15), getComparatorSignal(bulb));
    try std.testing.expectEqual(@as(u8, 15), bulbComparatorSignal(true));

    // Non-bulb fixture comparator is 0
    const grate = CopperFixtureState.init(.copper_grate, .unoxidized);
    try std.testing.expectEqual(@as(u8, 0), grate.getComparatorOutput());
}

test "copper grate allows waterlogging, does not block projectiles, and grants mob suffocation immunity" {
    const grate = CopperFixtureState.init(.copper_grate, .unoxidized);

    // Waterlogging allowed
    try std.testing.expect(grate.allowsWaterlogging());
    try std.testing.expect(allowsWaterlogging(.copper_grate));

    // Does NOT block projectiles (projectiles pass through)
    try std.testing.expect(!grate.blocksProjectiles());
    try std.testing.expect(!blocksProjectiles(.copper_grate));

    // Does NOT suffocate mobs (mob suffocation immunity)
    try std.testing.expect(!grate.suffocatesMobs());
    try std.testing.expect(!suffocatesMobs(.copper_grate));
}

test "chiseled copper and bulb block projectiles and suffocate mobs, cannot be waterlogged" {
    const chiseled = CopperFixtureState.init(.chiseled_copper, .unoxidized);
    const bulb = CopperFixtureState.init(.copper_bulb, .unoxidized);

    // Waterlogging disallowed
    try std.testing.expect(!chiseled.allowsWaterlogging());
    try std.testing.expect(!allowsWaterlogging(.chiseled_copper));
    try std.testing.expect(!bulb.allowsWaterlogging());
    try std.testing.expect(!allowsWaterlogging(.copper_bulb));

    // Blocks projectiles
    try std.testing.expect(chiseled.blocksProjectiles());
    try std.testing.expect(blocksProjectiles(.chiseled_copper));
    try std.testing.expect(bulb.blocksProjectiles());
    try std.testing.expect(blocksProjectiles(.copper_bulb));

    // Suffocates mobs
    try std.testing.expect(chiseled.suffocatesMobs());
    try std.testing.expect(suffocatesMobs(.chiseled_copper));
    try std.testing.expect(bulb.suffocatesMobs());
    try std.testing.expect(suffocatesMobs(.copper_bulb));
}

test "door and trapdoor projectile blocking is based on open state" {
    var door = CopperFixtureState.init(.copper_door, .unoxidized);
    try std.testing.expect(door.blocksProjectiles()); // Closed door blocks

    _ = door.interactHand();
    try std.testing.expect(door.is_open);
    try std.testing.expect(!door.blocksProjectiles()); // Open door allows passage

    // Doors and trapdoors do not suffocate mobs
    try std.testing.expect(!door.suffocatesMobs());
    try std.testing.expect(!suffocatesMobs(.copper_door));
    try std.testing.expect(!suffocatesMobs(.copper_trapdoor));
}

test "applyHoneycomb waxes fixture and resets oxidation timer" {
    var fixture = CopperFixtureState.init(.copper_door, .exposed);
    fixture.oxidation_timer = 20.0;

    // Apply honeycomb
    try std.testing.expect(fixture.applyHoneycomb());
    try std.testing.expect(fixture.is_waxed);
    try std.testing.expectEqual(@as(f32, 0.0), fixture.oxidation_timer);

    // Subsequent wax attempt fails
    try std.testing.expect(!fixture.applyHoneycomb());
    try std.testing.expect(!applyWax(&fixture));
}

test "scrapeWithAxe removes wax before stepping down oxidation stage" {
    var fixture = CopperFixtureState.initWaxed(.copper_bulb, .weathered);
    fixture.oxidation_timer = 15.0;

    // First scrape: removes wax, leaves stage at weathered
    try std.testing.expect(fixture.scrapeWithAxe());
    try std.testing.expect(!fixture.is_waxed);
    try std.testing.expectEqual(CopperOxidationStage.weathered, fixture.stage);
    try std.testing.expectEqual(@as(f32, 0.0), fixture.oxidation_timer);

    // Second scrape: steps down stage from weathered to exposed
    try std.testing.expect(scrapeWithAxe(&fixture));
    try std.testing.expectEqual(CopperOxidationStage.exposed, fixture.stage);
    try std.testing.expectEqual(@as(f32, 0.0), fixture.oxidation_timer);

    // Third scrape: steps down stage from exposed to unoxidized
    try std.testing.expect(fixture.scrapeWithAxe());
    try std.testing.expectEqual(CopperOxidationStage.unoxidized, fixture.stage);

    // Fourth scrape: unwaxed unoxidized cannot be scraped further
    try std.testing.expect(!fixture.scrapeWithAxe());
    try std.testing.expectEqual(CopperOxidationStage.unoxidized, fixture.stage);
}

test "tickOxidation advances stage after oxidation_stage_time" {
    var fixture = CopperFixtureState.init(.copper_grate, .unoxidized);

    // Advance 44 seconds: stage remains unoxidized
    try std.testing.expect(!fixture.tickOxidation(44.0));
    try std.testing.expectEqual(CopperOxidationStage.unoxidized, fixture.stage);
    try std.testing.expectEqual(@as(f32, 44.0), fixture.oxidation_timer);

    // Advance 1 second: threshold 45.0 reached, advances to exposed
    try std.testing.expect(fixture.tickOxidation(1.0));
    try std.testing.expectEqual(CopperOxidationStage.exposed, fixture.stage);
    try std.testing.expectEqual(@as(f32, 0.0), fixture.oxidation_timer);

    // Advance 50 seconds: remainder 5.0 carried
    try std.testing.expect(tickOxidation(&fixture, 50.0));
    try std.testing.expectEqual(CopperOxidationStage.weathered, fixture.stage);
    try std.testing.expectEqual(@as(f32, 5.0), fixture.oxidation_timer);

    // Advance another 45 seconds: reaches oxidized
    try std.testing.expect(fixture.tickOxidation(45.0));
    try std.testing.expectEqual(CopperOxidationStage.oxidized, fixture.stage);

    // Further ticking on oxidized does not advance
    try std.testing.expect(!fixture.tickOxidation(100.0));
    try std.testing.expectEqual(CopperOxidationStage.oxidized, fixture.stage);
}

test "tickOxidation halted when fixture is waxed" {
    var fixture = CopperFixtureState.initWaxed(.copper_door, .exposed);

    // Waxed fixture never oxidizes
    try std.testing.expect(!fixture.tickOxidation(500.0));
    try std.testing.expectEqual(CopperOxidationStage.exposed, fixture.stage);
    try std.testing.expectEqual(@as(f32, 0.0), fixture.oxidation_timer);
}

test "findFixture spatial lookup in array of fixtures" {
    var fixtures = [_]CopperFixtureState{
        CopperFixtureState.initAt(.copper_door, .unoxidized, 10, 64, 20),
        CopperFixtureState.initAt(.copper_bulb, .exposed, -5, 12, 40),
        CopperFixtureState.initAt(.copper_grate, .oxidized, 0, 70, 0),
    };

    try std.testing.expectEqual(@as(?usize, 0), findFixture(&fixtures, fixtures.len, 10, 64, 20));
    try std.testing.expectEqual(@as(?usize, 1), findFixture(&fixtures, fixtures.len, -5, 12, 40));
    try std.testing.expectEqual(@as(?usize, 2), findFixture(&fixtures, fixtures.len, 0, 70, 0));

    // Non-existent positions
    try std.testing.expect(findFixture(&fixtures, fixtures.len, 99, 99, 99) == null);
    try std.testing.expect(findFixture(&fixtures, 1, -5, 12, 40) == null);
}

test "canonical display names for waxed and unwaxed fixture variants" {
    try std.testing.expectEqualStrings("Copper Door", getDisplayName(.copper_door, .unoxidized, false));
    try std.testing.expectEqualStrings("Waxed Oxidized Copper Door", getDisplayName(.copper_door, .oxidized, true));
    try std.testing.expectEqualStrings("Exposed Copper Trapdoor", getDisplayName(.copper_trapdoor, .exposed, false));
    try std.testing.expectEqualStrings("Waxed Copper Grate", getDisplayName(.copper_grate, .unoxidized, true));
    try std.testing.expectEqualStrings("Weathered Chiseled Copper", getDisplayName(.chiseled_copper, .weathered, false));
    try std.testing.expectEqualStrings("Waxed Weathered Copper Bulb", getDisplayName(.copper_bulb, .weathered, true));
}
