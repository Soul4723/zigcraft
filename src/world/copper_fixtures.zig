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

    /// Return the light level emitted by a lit copper bulb at this oxidation stage.
    pub fn lightLevel(self: CopperOxidationStage) u8 {
        return switch (self) {
            .unoxidized => bulb_light_unoxidized,
            .exposed => bulb_light_exposed,
            .weathered => bulb_light_weathered,
            .oxidized => bulb_light_oxidized,
        };
    }

    /// Return the previous less-oxidized stage, or null if already unoxidized.
    pub fn previous(self: CopperOxidationStage) ?CopperOxidationStage {
        return self.prev();
    }
};

/// Alias for CopperOxidationStage used by CopperBulb and 7-segment display rules.
pub const OxidationStage = CopperOxidationStage;

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

/// Find an existing copper fixture at (x, y, z) or append a new one if capacity allows.
pub fn ensureFixture(
    items: []CopperFixtureState,
    count: *usize,
    kind: CopperFixtureKind,
    stage: CopperOxidationStage,
    x: i32,
    y: i32,
    z: i32,
) ?*CopperFixtureState {
    if (findFixture(items, count.*, x, y, z)) |idx| {
        return &items[idx];
    }
    if (count.* >= items.len) return null;
    items[count.*] = CopperFixtureState.initAt(kind, stage, x, y, z);
    const ptr = &items[count.*];
    count.* += 1;
    return ptr;
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
// Delayed Copper Bulb T-Flip-Flop Latch & 7-Segment Display Matrix
// -------------------------------------------------------------------------

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

    /// Return the emitted light level (15/12/8/4 when lit, 0 when unlit).
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

pub const DISPLAY_WIDTH: u8 = 3;
pub const DISPLAY_HEIGHT: u8 = 5;
pub const DISPLAY_DEPTH: u8 = 1;
pub const BULB_COUNT: usize = 13;

pub const Segment = enum(u3) {
    segment_a,
    segment_b,
    segment_c,
    segment_d,
    segment_e,
    segment_f,
    segment_g,

    /// Return the bitmask corresponding to this segment.
    pub fn bit(self: Segment) u7 {
        return @as(u7, 1) << @intFromEnum(self);
    }
};

pub const segment_a: u7 = 0x01;
pub const segment_b: u7 = 0x02;
pub const segment_c: u7 = 0x04;
pub const segment_d: u7 = 0x08;
pub const segment_e: u7 = 0x10;
pub const segment_f: u7 = 0x20;
pub const segment_g: u7 = 0x40;
pub const ALL_SEGMENTS: u7 = 0x7f;

pub const Coord = struct { x: u8, y: u8, z: u8 = 0 };
pub const SegmentLayout = struct { coords: [3]Coord, len: u2 };

/// Horizontal bars have three bulbs; the 3-by-5 layout gives each vertical
/// segment one bulb between its adjacent horizontal bars.
pub const segment_layout = [_]SegmentLayout{
    .{ .coords = .{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 2, .y = 0 } }, .len = 3 }, // a
    .{ .coords = .{ .{ .x = 2, .y = 1 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } }, .len = 1 }, // b
    .{ .coords = .{ .{ .x = 2, .y = 3 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } }, .len = 1 }, // c
    .{ .coords = .{ .{ .x = 0, .y = 4 }, .{ .x = 1, .y = 4 }, .{ .x = 2, .y = 4 } }, .len = 3 }, // d
    .{ .coords = .{ .{ .x = 0, .y = 3 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } }, .len = 1 }, // e
    .{ .coords = .{ .{ .x = 0, .y = 1 }, .{ .x = 0, .y = 0 }, .{ .x = 0, .y = 0 } }, .len = 1 }, // f
    .{ .coords = .{ .{ .x = 0, .y = 2 }, .{ .x = 1, .y = 2 }, .{ .x = 2, .y = 2 } }, .len = 3 }, // g
};

pub const digit_masks = [_]u7{
    0x3f, 0x06, 0x5b, 0x4f, 0x66,
    0x6d, 0x7d, 0x07, 0x7f, 0x6f,
};

/// Decode a decimal digit (0..9) into its 7-segment bitmask, or null if out of range.
pub fn decodeDigit(digit: u8) ?u7 {
    if (digit >= digit_masks.len) return null;
    return digit_masks[digit];
}

/// Saturate values above 9 to 9 for callers that explicitly want clamping.
pub fn decodeDigitClamped(digit: u8) u7 {
    return digit_masks[@min(digit, 9)];
}

pub const Refresh = struct {
    changed_segments: u7 = 0,
    pulses: u8 = 0,
};

pub const DigitUpdate = struct {
    valid: bool,
    refresh: Refresh,
};

/// Matrix of individually oxidizing copper bulbs for one seven-segment digit.
pub const CopperBulbDisplay = struct {
    bulbs: [BULB_COUNT]CopperBulb = [_]CopperBulb{.{}} ** BULB_COUNT,
    current_mask: u7 = 0,

    /// Toggle only the segments that differ from the current display mask.
    pub fn setMask(self: *CopperBulbDisplay, desired_mask: u7) Refresh {
        const desired = desired_mask & ALL_SEGMENTS;
        const changed = desired ^ self.current_mask;
        var report = Refresh{ .changed_segments = changed };
        for (segment_layout, 0..) |layout, segment_index| {
            const bit: u7 = @as(u7, 1) << @intCast(segment_index);
            if ((changed & bit) == 0) continue;
            const start = segmentStart(segment_index);
            for (0..layout.len) |offset| {
                self.bulbs[start + offset].is_lit = (desired & bit) != 0;
                report.pulses += 1;
            }
        }
        self.current_mask = desired;
        return report;
    }

    /// Invalid digits blank the display and report `valid = false`.
    pub fn setDigit(self: *CopperBulbDisplay, digit: u8) DigitUpdate {
        if (decodeDigit(digit)) |mask| return .{ .valid = true, .refresh = self.setMask(mask) };
        return .{ .valid = false, .refresh = self.setMask(0) };
    }

    /// Return the emitted light level of the bulb at `coord`, or null if outside the matrix.
    pub fn getLightLevel(self: CopperBulbDisplay, coord: Coord) ?u8 {
        for (self.bulbs, 0..) |bulb, index| {
            if (std.meta.eql(coord, bulbCoord(index))) return bulb.getLightLevel();
        }
        return null;
    }

    /// Sum emitted light levels across all 13 bulbs in the digit display.
    pub fn totalLightEmission(self: CopperBulbDisplay) u16 {
        var total: u16 = 0;
        for (self.bulbs) |bulb| total += bulb.getLightLevel();
        return total;
    }
};

pub const Cascade = struct {
    tens: CopperBulbDisplay = .{},
    ones: CopperBulbDisplay = .{},

    /// Display values 0..99 as two digits. Out-of-range input blanks both.
    pub fn showNumber(self: *Cascade, value: u8) bool {
        if (value > 99) {
            _ = self.tens.setMask(0);
            _ = self.ones.setMask(0);
            return false;
        }
        _ = self.tens.setDigit(value / 10);
        _ = self.ones.setDigit(value % 10);
        return true;
    }
};

fn segmentStart(segment_index: usize) usize {
    return switch (segment_index) {
        0 => 0,
        1 => 3,
        2 => 4,
        3 => 5,
        4 => 8,
        5 => 9,
        6 => 10,
        else => unreachable,
    };
}

/// Return the grid coordinate of the `index`th bulb in the 7-segment display matrix.
pub fn bulbCoord(index: usize) Coord {
    for (segment_layout, 0..) |layout, segment_index| {
        const start = segmentStart(segment_index);
        if (index >= start and index < start + layout.len) return layout.coords[index - start];
    }
    unreachable;
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

    // ensureFixture reuses existing slot or allocates a new one up to capacity
    var tracked: [2]CopperFixtureState = undefined;
    var tracked_count: usize = 0;
    const first = ensureFixture(&tracked, &tracked_count, .copper_bulb, .unoxidized, 1, 2, 3).?;
    first.bulb_lit = true;
    const same = ensureFixture(&tracked, &tracked_count, .copper_bulb, .oxidized, 1, 2, 3).?;
    try std.testing.expect(same.bulb_lit);
    try std.testing.expectEqual(@as(usize, 1), tracked_count);
    try std.testing.expect(ensureFixture(&tracked, &tracked_count, .copper_door, .unoxidized, 4, 5, 6) != null);
    try std.testing.expect(ensureFixture(&tracked, &tracked_count, .copper_grate, .unoxidized, 7, 8, 9) == null);
}

test "canonical display names for waxed and unwaxed fixture variants" {
    try std.testing.expectEqualStrings("Copper Door", getDisplayName(.copper_door, .unoxidized, false));
    try std.testing.expectEqualStrings("Waxed Oxidized Copper Door", getDisplayName(.copper_door, .oxidized, true));
    try std.testing.expectEqualStrings("Exposed Copper Trapdoor", getDisplayName(.copper_trapdoor, .exposed, false));
    try std.testing.expectEqualStrings("Waxed Copper Grate", getDisplayName(.copper_grate, .unoxidized, true));
    try std.testing.expectEqualStrings("Weathered Chiseled Copper", getDisplayName(.chiseled_copper, .weathered, false));
    try std.testing.expectEqualStrings("Waxed Weathered Copper Bulb", getDisplayName(.copper_bulb, .weathered, true));
}

// --- Unified Copper Bulb Latch tests ---

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

// --- Unified Copper Bulb Display tests ---

test "display bounds are three by five by one" {
    try std.testing.expectEqual(@as(u8, 3), DISPLAY_WIDTH);
    try std.testing.expectEqual(@as(u8, 5), DISPLAY_HEIGHT);
    try std.testing.expectEqual(@as(u8, 1), DISPLAY_DEPTH);
}

test "segment bits use a through g ordering" {
    try std.testing.expectEqual(@as(u7, 0x01), segment_a);
    try std.testing.expectEqual(@as(u7, 0x02), segment_b);
    try std.testing.expectEqual(@as(u7, 0x04), segment_c);
    try std.testing.expectEqual(@as(u7, 0x08), segment_d);
    try std.testing.expectEqual(@as(u7, 0x10), segment_e);
    try std.testing.expectEqual(@as(u7, 0x20), segment_f);
    try std.testing.expectEqual(@as(u7, 0x40), segment_g);
}

test "seven segments contain thirteen bulbs with unique coordinates" {
    try std.testing.expectEqual(@as(usize, 13), BULB_COUNT);
    for (0..BULB_COUNT) |i| for (i + 1..BULB_COUNT) |j| {
        try std.testing.expect(!std.meta.eql(bulbCoord(i), bulbCoord(j)));
    };
}

test "each segment lies within display bounds" {
    for (segment_layout) |layout| for (layout.coords[0..layout.len]) |coord| {
        try std.testing.expect(coord.x < DISPLAY_WIDTH);
        try std.testing.expect(coord.y < DISPLAY_HEIGHT);
        try std.testing.expect(coord.z < DISPLAY_DEPTH);
    };
}

test "top bar a occupies the top row" {
    for (segment_layout[0].coords) |coord| try std.testing.expectEqual(@as(u8, 0), coord.y);
}
test "segment b occupies upper right column" {
    for (segment_layout[1].coords[0..1]) |coord| try std.testing.expectEqual(@as(u8, 2), coord.x);
}
test "segment c occupies lower right column" {
    for (segment_layout[2].coords[0..1]) |coord| try std.testing.expectEqual(@as(u8, 2), coord.x);
}
test "segment d occupies bottom row" {
    for (segment_layout[3].coords) |coord| try std.testing.expectEqual(@as(u8, 4), coord.y);
}
test "segment e occupies lower left column" {
    for (segment_layout[4].coords[0..1]) |coord| try std.testing.expectEqual(@as(u8, 0), coord.x);
}
test "segment f occupies upper left column" {
    for (segment_layout[5].coords[0..1]) |coord| try std.testing.expectEqual(@as(u8, 0), coord.x);
}
test "segment g occupies center row" {
    for (segment_layout[6].coords) |coord| try std.testing.expectEqual(@as(u8, 2), coord.y);
}

test "decoder returns zero mask" { try std.testing.expectEqual(@as(?u7, 0x3f), decodeDigit(0)); }
test "decoder returns one mask" { try std.testing.expectEqual(@as(?u7, 0x06), decodeDigit(1)); }
test "decoder returns two mask" { try std.testing.expectEqual(@as(?u7, 0x5b), decodeDigit(2)); }
test "decoder returns three mask" { try std.testing.expectEqual(@as(?u7, 0x4f), decodeDigit(3)); }
test "decoder returns four mask" { try std.testing.expectEqual(@as(?u7, 0x66), decodeDigit(4)); }
test "decoder returns five mask" { try std.testing.expectEqual(@as(?u7, 0x6d), decodeDigit(5)); }
test "decoder returns six mask" { try std.testing.expectEqual(@as(?u7, 0x7d), decodeDigit(6)); }
test "decoder returns seven mask" { try std.testing.expectEqual(@as(?u7, 0x07), decodeDigit(7)); }
test "decoder returns eight mask" { try std.testing.expectEqual(@as(?u7, 0x7f), decodeDigit(8)); }
test "decoder returns nine mask" { try std.testing.expectEqual(@as(?u7, 0x6f), decodeDigit(9)); }
test "decoder rejects values outside decimal digits" { try std.testing.expectEqual(@as(?u7, null), decodeDigit(10)); }
test "clamped decoder saturates invalid values to nine" { try std.testing.expectEqual(@as(u7, 0x6f), decodeDigitClamped(255)); }

test "initial blank matrix sends no pulses" {
    var display = CopperBulbDisplay{};
    const report = display.setMask(0);
    try std.testing.expectEqual(@as(u8, 0), report.pulses);
    try std.testing.expectEqual(@as(u7, 0), report.changed_segments);
}
test "minimal toggle uses desired xor current mask" {
    var display = CopperBulbDisplay{};
    _ = display.setMask(segment_a | segment_b);
    const report = display.setMask(segment_a | segment_c);
    try std.testing.expectEqual(segment_b | segment_c, report.changed_segments);
    try std.testing.expectEqual(@as(u8, 2), report.pulses);
}
test "repeating the same mask sends no pulses" {
    var display = CopperBulbDisplay{};
    _ = display.setMask(digit_masks[8]);
    const report = display.setMask(digit_masks[8]);
    try std.testing.expectEqual(@as(u8, 0), report.pulses);
    try std.testing.expectEqual(@as(u7, 0), report.changed_segments);
}
test "all seven bits can be activated" {
    var display = CopperBulbDisplay{};
    _ = display.setMask(ALL_SEGMENTS);
    try std.testing.expectEqual(ALL_SEGMENTS, display.current_mask);
}
test "oxidation state is preserved when its bulb toggles" {
    var display = CopperBulbDisplay{};
    display.bulbs[0].oxidation_stage = .weathered;
    _ = display.setMask(segment_a);
    try std.testing.expectEqual(OxidationStage.weathered, display.bulbs[0].oxidation_stage);
    _ = display.setMask(0);
    try std.testing.expectEqual(OxidationStage.weathered, display.bulbs[0].oxidation_stage);
}
test "lit bulb light level follows oxidation tier" {
    const stages = [_]OxidationStage{ .unoxidized, .exposed, .weathered, .oxidized };
    const levels = [_]u8{ 15, 12, 8, 4 };
    for (stages, levels) |stage, level| {
        var display = CopperBulbDisplay{};
        display.bulbs[0].oxidation_stage = stage;
        _ = display.setMask(segment_a);
        try std.testing.expectEqual(level, display.getLightLevel(bulbCoord(0)).?);
    }
}
test "unlit bulb contributes zero emission" {
    try std.testing.expectEqual(@as(u8, 0), (CopperBulbDisplay{}).getLightLevel(bulbCoord(0)).?);
}
test "unknown coordinate has no bulb light level" {
    try std.testing.expectEqual(@as(?u8, null), (CopperBulbDisplay{}).getLightLevel(.{ .x = 3, .y = 0 }));
}
test "aggregate light emission sums individually oxidized bulbs" {
    var display = CopperBulbDisplay{};
    display.bulbs[3].oxidation_stage = .oxidized;
    display.bulbs[4].oxidation_stage = .weathered;
    _ = display.setMask(segment_b | segment_c);
    try std.testing.expectEqual(@as(u16, 12), display.totalLightEmission());
}
test "invalid digit blanks active display" {
    var display = CopperBulbDisplay{};
    _ = display.setDigit(8);
    const update = display.setDigit(42);
    try std.testing.expect(!update.valid);
    try std.testing.expectEqual(@as(u7, 0), display.current_mask);
}
test "invalid digit on blank display does not pulse" {
    var display = CopperBulbDisplay{};
    const update = display.setDigit(10);
    try std.testing.expect(!update.valid);
    try std.testing.expectEqual(@as(u8, 0), update.refresh.pulses);
}
test "cascade renders every number from zero through ninety nine" {
    var cascade = Cascade{};
    for (0..100) |value| {
        try std.testing.expect(cascade.showNumber(@intCast(value)));
        try std.testing.expectEqual(digit_masks[value / 10], cascade.tens.current_mask);
        try std.testing.expectEqual(digit_masks[value % 10], cascade.ones.current_mask);
    }
}
test "cascade renders leading zero for single digit values" {
    var cascade = Cascade{};
    try std.testing.expect(cascade.showNumber(7));
    try std.testing.expectEqual(digit_masks[0], cascade.tens.current_mask);
    try std.testing.expectEqual(digit_masks[7], cascade.ones.current_mask);
}
test "cascade rejects and blanks values above ninety nine" {
    var cascade = Cascade{};
    _ = cascade.showNumber(42);
    try std.testing.expect(!cascade.showNumber(100));
    try std.testing.expectEqual(@as(u7, 0), cascade.tens.current_mask);
    try std.testing.expectEqual(@as(u7, 0), cascade.ones.current_mask);
}
