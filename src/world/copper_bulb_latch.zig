const std = @import("std");

/// Copper oxidation state and the light level available while the bulb is lit.
pub const OxidationStage = enum(u8) {
    unoxidized,
    exposed,
    weathered,
    oxidized,

    pub fn lightLevel(self: OxidationStage) u8 {
        return switch (self) {
            .unoxidized => 15,
            .exposed => 12,
            .weathered => 8,
            .oxidized => 4,
        };
    }

    pub fn next(self: OxidationStage) ?OxidationStage {
        return switch (self) {
            .unoxidized => .exposed,
            .exposed => .weathered,
            .weathered => .oxidized,
            .oxidized => null,
        };
    }

    pub fn previous(self: OxidationStage) ?OxidationStage {
        return switch (self) {
            .unoxidized => null,
            .exposed => .unoxidized,
            .weathered => .exposed,
            .oxidized => .weathered,
        };
    }
};

pub const GAME_TICKS_PER_TOGGLE = 2;

pub const IndicatorDot = enum {
    off,
    yellow_red,
};

pub const ParticleEffect = enum {
    wax,
    copper_scrape,
};

pub const ScrapeResult = struct {
    changed: bool,
    particles: ?ParticleEffect,
};

/// Stateful copper bulb. Call `setPower` when its input signal changes and
/// `tick` once for each game tick to advance the delayed rising-edge toggle.
pub const CopperBulb = struct {
    is_lit: bool = false,
    is_powered: bool = false,
    oxidation_stage: OxidationStage = .unoxidized,
    is_waxed: bool = false,
    pending_toggle_ticks: u8 = 0,

    /// Record a redstone signal level. Only a low-to-high transition schedules
    /// a toggle; a falling edge only updates the powered state.
    pub fn setPower(self: *CopperBulb, signal_strength: u8) void {
        const now_powered = signal_strength > 0;
        if (!self.is_powered and now_powered) {
            self.pending_toggle_ticks +|= GAME_TICKS_PER_TOGGLE;
        }
        self.is_powered = now_powered;
    }

    /// Advance one game tick. Returns true exactly when the bulb toggles.
    pub fn tick(self: *CopperBulb) bool {
        if (self.pending_toggle_ticks == 0) return false;
        self.pending_toggle_ticks -= 1;
        if (self.pending_toggle_ticks != 0) return false;
        self.is_lit = !self.is_lit;
        return true;
    }

    pub fn getLightLevel(self: CopperBulb) u8 {
        return if (self.is_lit) self.oxidation_stage.lightLevel() else 0;
    }

    /// The center indicator dot follows the bulb's lit state.
    pub fn getIndicatorDot(self: CopperBulb) IndicatorDot {
        return if (self.is_lit) .yellow_red else .off;
    }

    /// Comparator strength is independent of the oxidation light decay.
    pub fn getComparatorOutput(self: CopperBulb) u8 {
        return if (self.is_lit) 15 else 0;
    }

    /// Waxing with honeycomb preserves the current oxidation stage.
    pub fn applyWaxing(self: *CopperBulb) bool {
        if (self.is_waxed) return false;
        self.is_waxed = true;
        return true;
    }

    /// Apply one natural oxidation step. A waxed or fully oxidized bulb stays put.
    pub fn advanceOxidation(self: *CopperBulb) bool {
        if (self.is_waxed) return false;
        if (self.oxidation_stage.next()) |next_stage| {
            self.oxidation_stage = next_stage;
            return true;
        }
        return false;
    }

    /// Scrape wax first; otherwise remove one oxidation tier if possible.
    pub fn scrapeWithAxe(self: *CopperBulb) ScrapeResult {
        if (self.is_waxed) {
            self.is_waxed = false;
            return .{ .changed = true, .particles = .wax };
        }
        if (self.oxidation_stage.previous()) |previous_stage| {
            self.oxidation_stage = previous_stage;
            return .{ .changed = true, .particles = .copper_scrape };
        }
        return .{ .changed = false, .particles = null };
    }
};

test "copper bulb starts unlit and unpowered" {
    const bulb = CopperBulb{};
    try std.testing.expect(!bulb.is_lit);
    try std.testing.expect(!bulb.is_powered);
}

test "a rising edge toggles on after the two game tick delay" {
    var bulb = CopperBulb{};
    bulb.setPower(1);
    try std.testing.expect(!bulb.tick());
    try std.testing.expect(!bulb.is_lit);
    try std.testing.expect(bulb.tick());
    try std.testing.expect(bulb.is_lit);
}

test "a subsequent rising edge toggles a lit bulb off" {
    var bulb = CopperBulb{ .is_lit = true };
    bulb.setPower(15);
    _ = bulb.tick();
    try std.testing.expect(bulb.tick());
    try std.testing.expect(!bulb.is_lit);
}

test "continuous power does not schedule repeated toggles" {
    var bulb = CopperBulb{};
    bulb.setPower(15);
    _ = bulb.tick();
    _ = bulb.tick();
    for (0..8) |_| try std.testing.expect(!bulb.tick());
    try std.testing.expect(bulb.is_lit);
}

test "falling edge preserves the lit state" {
    var bulb = CopperBulb{ .is_lit = true, .is_powered = true };
    bulb.setPower(0);
    for (0..4) |_| try std.testing.expect(!bulb.tick());
    try std.testing.expect(bulb.is_lit);
}

test "zero signal does not count as powered" {
    var bulb = CopperBulb{};
    bulb.setPower(0);
    try std.testing.expect(!bulb.is_powered);
    try std.testing.expectEqual(@as(u8, 0), bulb.pending_toggle_ticks);
}

test "any positive signal counts as powered" {
    var bulb = CopperBulb{};
    bulb.setPower(1);
    try std.testing.expect(bulb.is_powered);
}

test "a high signal can fall before the delayed toggle completes" {
    var bulb = CopperBulb{};
    bulb.setPower(15);
    bulb.setPower(0);
    _ = bulb.tick();
    try std.testing.expect(bulb.tick());
    try std.testing.expect(bulb.is_lit);
}

test "a new rising edge after a falling edge schedules another toggle" {
    var bulb = CopperBulb{};
    bulb.setPower(15);
    _ = bulb.tick();
    _ = bulb.tick();
    bulb.setPower(0);
    bulb.setPower(1);
    _ = bulb.tick();
    try std.testing.expect(bulb.tick());
    try std.testing.expect(!bulb.is_lit);
}

test "repeated high samples do not create extra edges" {
    var bulb = CopperBulb{};
    bulb.setPower(2);
    bulb.setPower(14);
    bulb.setPower(1);
    _ = bulb.tick();
    _ = bulb.tick();
    try std.testing.expectEqual(@as(u8, 0), bulb.pending_toggle_ticks);
    try std.testing.expect(bulb.is_lit);
}

test "unoxidized lit bulb emits level fifteen" {
    try std.testing.expectEqual(@as(u8, 15), (CopperBulb{ .is_lit = true }).getLightLevel());
}

test "exposed lit bulb emits level twelve" {
    try std.testing.expectEqual(@as(u8, 12), (CopperBulb{ .is_lit = true, .oxidation_stage = .exposed }).getLightLevel());
}

test "weathered lit bulb emits level eight" {
    try std.testing.expectEqual(@as(u8, 8), (CopperBulb{ .is_lit = true, .oxidation_stage = .weathered }).getLightLevel());
}

test "oxidized lit bulb emits level four" {
    try std.testing.expectEqual(@as(u8, 4), (CopperBulb{ .is_lit = true, .oxidation_stage = .oxidized }).getLightLevel());
}

test "unlit bulbs emit no light at any oxidation stage" {
    inline for (.{ .unoxidized, .exposed, .weathered, .oxidized }) |stage| {
        const bulb = CopperBulb{ .oxidation_stage = stage };
        try std.testing.expectEqual(@as(u8, 0), bulb.getLightLevel());
    }
}

test "light levels match all oxidation stages" {
    const stages = [_]OxidationStage{ .unoxidized, .exposed, .weathered, .oxidized };
    const levels = [_]u8{ 15, 12, 8, 4 };
    for (stages, levels) |stage, level| {
        try std.testing.expectEqual(level, stage.lightLevel());
    }
}

test "waxing succeeds and preserves oxidation stage" {
    var bulb = CopperBulb{ .oxidation_stage = .weathered };
    try std.testing.expect(bulb.applyWaxing());
    try std.testing.expect(bulb.is_waxed);
    try std.testing.expectEqual(OxidationStage.weathered, bulb.oxidation_stage);
}

test "waxed bulb does not naturally oxidize" {
    var bulb = CopperBulb{ .oxidation_stage = .exposed, .is_waxed = true };
    try std.testing.expect(!bulb.advanceOxidation());
    try std.testing.expectEqual(OxidationStage.exposed, bulb.oxidation_stage);
}

test "a bulb can age one oxidation tier at a time" {
    var bulb = CopperBulb{};
    try std.testing.expect(bulb.advanceOxidation());
    try std.testing.expectEqual(OxidationStage.exposed, bulb.oxidation_stage);
    try std.testing.expect(bulb.advanceOxidation());
    try std.testing.expectEqual(OxidationStage.weathered, bulb.oxidation_stage);
}

test "oxidized bulb cannot age further" {
    var bulb = CopperBulb{ .oxidation_stage = .oxidized };
    try std.testing.expect(!bulb.advanceOxidation());
    try std.testing.expectEqual(OxidationStage.oxidized, bulb.oxidation_stage);
}

test "waxing an already waxed bulb has no effect" {
    var bulb = CopperBulb{ .is_waxed = true, .oxidation_stage = .weathered };
    try std.testing.expect(!bulb.applyWaxing());
    try std.testing.expectEqual(OxidationStage.weathered, bulb.oxidation_stage);
}

test "axe scraping removes wax and returns wax particles" {
    var bulb = CopperBulb{ .is_waxed = true, .oxidation_stage = .weathered };
    const result = bulb.scrapeWithAxe();
    try std.testing.expect(result.changed);
    try std.testing.expectEqual(ParticleEffect.wax, result.particles.?);
    try std.testing.expect(!bulb.is_waxed);
    try std.testing.expectEqual(OxidationStage.weathered, bulb.oxidation_stage);
}

test "axe scraping regresses oxidized stage and returns copper particles" {
    var bulb = CopperBulb{ .oxidation_stage = .oxidized };
    const result = bulb.scrapeWithAxe();
    try std.testing.expect(result.changed);
    try std.testing.expectEqual(ParticleEffect.copper_scrape, result.particles.?);
    try std.testing.expectEqual(OxidationStage.weathered, bulb.oxidation_stage);
}

test "axe scraping regresses weathered to exposed" {
    var bulb = CopperBulb{ .oxidation_stage = .weathered };
    _ = bulb.scrapeWithAxe();
    try std.testing.expectEqual(OxidationStage.exposed, bulb.oxidation_stage);
}

test "axe scraping regresses exposed to unoxidized" {
    var bulb = CopperBulb{ .oxidation_stage = .exposed };
    _ = bulb.scrapeWithAxe();
    try std.testing.expectEqual(OxidationStage.unoxidized, bulb.oxidation_stage);
}

test "unoxidized bulb cannot be scraped further" {
    var bulb = CopperBulb{};
    const result = bulb.scrapeWithAxe();
    try std.testing.expect(!result.changed);
    try std.testing.expectEqual(@as(?ParticleEffect, null), result.particles);
}

test "indicator dot lights yellow red when bulb is lit" {
    const bulb = CopperBulb{ .is_lit = true };
    try std.testing.expectEqual(IndicatorDot.yellow_red, bulb.getIndicatorDot());
}

test "indicator dot is off when bulb is unlit" {
    try std.testing.expectEqual(IndicatorDot.off, (CopperBulb{}).getIndicatorDot());
}

test "comparator emits fifteen for lit bulb at every oxidation stage" {
    inline for (.{ .unoxidized, .exposed, .weathered, .oxidized }) |stage| {
        const bulb = CopperBulb{ .is_lit = true, .oxidation_stage = stage };
        try std.testing.expectEqual(@as(u8, 15), bulb.getComparatorOutput());
    }
}

test "comparator emits zero for unlit bulb at every oxidation stage" {
    inline for (.{ .unoxidized, .exposed, .weathered, .oxidized }) |stage| {
        const bulb = CopperBulb{ .oxidation_stage = stage };
        try std.testing.expectEqual(@as(u8, 0), bulb.getComparatorOutput());
    }
}
