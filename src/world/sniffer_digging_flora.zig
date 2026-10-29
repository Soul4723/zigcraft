const std = @import("std");

pub const ticks_per_second: u32 = 20;
pub const search_duration: u32 = 30;
pub const excited_duration: u32 = 20;
pub const digging_duration: u32 = 200;
pub const rising_duration: u32 = 20;
pub const scent_cooldown: u32 = 9_600;
pub const scent_radius: i32 = 16;
pub const egg_hatch_ticks: u32 = 48_000;
pub const moss_egg_hatch_ticks: u32 = 24_000;
pub const snifflet_growth_ticks: u32 = 48_000;

pub const Position = struct { x: i32, y: i32, z: i32 };

/// The substrate vocabulary mirrors the terrain names used by the world model.
pub const Substrate = enum {
    dirt,
    grass_block,
    podzol,
    coarse_dirt,
    rooted_dirt,
    moss_block,
    mud,
    muddy_mangrove_roots,
    stone,
    sand,
    wood,
    metal,
    glass,
    water,
    air,
};

pub fn isSniffable(block: Substrate) bool {
    return switch (block) {
        .dirt, .grass_block, .podzol, .coarse_dirt, .rooted_dirt, .moss_block, .mud, .muddy_mangrove_roots => true,
        else => false,
    };
}

pub const SnifferState = enum { idle, searching_sniff, excited_sniff, digging, rising, cooldown };
pub const SeedLoot = enum { torchflower_seeds, pitcher_pod };
pub const SnifferEvent = struct {
    sound: bool = false,
    target_locked: bool = false,
    digging_particle_burst: bool = false,
    extruded_loot: ?SeedLoot = null,
};

const scent_slots = 128;
const Scent = struct { position: Position = .{ .x = 0, .y = 0, .z = 0 }, tick: u64 = 0, used: bool = false };

pub const Sniffer = struct {
    state: SnifferState = .idle,
    state_ticks: u32 = 0,
    world_tick: u64 = 0,
    target: ?Position = null,
    scents: [scent_slots]Scent = [_]Scent{.{}} ** scent_slots,
    next_scent: usize = 0,

    pub fn hasVisitedRecently(self: *const Sniffer, position: Position) bool {
        for (self.scents) |scent| {
            if (!scent.used or self.world_tick -| scent.tick >= scent_cooldown) continue;
            if (withinScentRadius(scent.position, position)) return true;
        }
        return false;
    }

    pub fn beginSearch(self: *Sniffer, position: Position, substrate: Substrate) bool {
        if (self.state != .idle) return false;
        if (!isSniffable(substrate) or self.hasVisitedRecently(position)) return false;
        self.target = position;
        self.state = .searching_sniff;
        self.state_ticks = 0;
        self.scents[self.next_scent] = .{ .position = position, .tick = self.world_tick, .used = true };
        self.next_scent = (self.next_scent + 1) % scent_slots;
        return true;
    }

    /// Advance one game tick. A supplied seed_roll in 0..99 makes the 50/50
    /// loot split reproducible for both gameplay callers and tests.
    pub fn tick(self: *Sniffer, seed_roll: u8) SnifferEvent {
        self.world_tick += 1;
        var event = SnifferEvent{};
        switch (self.state) {
            .idle => {},
            .searching_sniff => {
                self.state_ticks += 1;
                if (self.state_ticks >= search_duration) {
                    self.state = .excited_sniff;
                    self.state_ticks = 0;
                    event.sound = true;
                    event.target_locked = true;
                }
            },
            .excited_sniff => {
                self.state_ticks += 1;
                if (self.state_ticks >= excited_duration) {
                    self.state = .digging;
                    self.state_ticks = 0;
                    event.digging_particle_burst = true;
                }
            },
            .digging => {
                self.state_ticks += 1;
                if (self.state_ticks % 20 == 0) event.digging_particle_burst = true;
                if (self.state_ticks >= digging_duration) {
                    self.state = .rising;
                    self.state_ticks = 0;
                    event.extruded_loot = if (seed_roll < 50) .torchflower_seeds else .pitcher_pod;
                }
            },
            .rising => {
                self.state_ticks += 1;
                if (self.state_ticks >= rising_duration) {
                    self.state = .cooldown;
                    self.state_ticks = 0;
                }
            },
            .cooldown => {
                self.state_ticks += 1;
                if (self.state_ticks >= scent_cooldown) {
                    self.state = .idle;
                    self.state_ticks = 0;
                    self.target = null;
                }
            },
        }
        return event;
    }
};

fn withinScentRadius(a: Position, b: Position) bool {
    const dx = @as(i64, a.x) - b.x;
    const dy = @as(i64, a.y) - b.y;
    const dz = @as(i64, a.z) - b.z;
    const radius = @as(i64, scent_radius);
    return dx * dx + dy * dy + dz * dz <= radius * radius;
}

pub const TorchflowerStage = enum(u8) { stage_0, stage_1, mature };
pub const CropDrop = struct { item: SeedLootOrFlora, count: u8 };
pub const SeedLootOrFlora = enum { torchflower_seeds, torchflower, pitcher_pod, pitcher_plant };

pub const TorchflowerCrop = struct {
    stage: TorchflowerStage = .stage_0,
    exists: bool = true,
    pub fn canPlantOn(soil: CropSoil) bool {
        return soil == .farmland;
    }
    pub fn advance(self: *TorchflowerCrop) bool {
        if (!self.exists) return false;
        switch (self.stage) {
            .stage_0 => self.stage = .stage_1,
            .stage_1 => self.stage = .mature,
            .mature => return false,
        }
        return true;
    }
    pub fn boneMeal(self: *TorchflowerCrop) bool {
        return self.advance();
    }
    pub fn harvest(self: *TorchflowerCrop) [2]CropDrop {
        if (!self.exists) return .{ .{ .item = .torchflower_seeds, .count = 0 }, .{ .item = .torchflower_seeds, .count = 0 } };
        self.exists = false;
        if (self.stage == .mature) return .{ .{ .item = .torchflower, .count = 1 }, .{ .item = .torchflower_seeds, .count = 1 } };
        return .{ .{ .item = .torchflower_seeds, .count = 1 }, .{ .item = .torchflower_seeds, .count = 0 } };
    }
};

pub const CropSoil = enum { farmland, other };
pub const PitcherStage = enum(u8) { stage_0, stage_1, stage_2, stage_3, stage_4 };
pub const PitcherHalf = enum { lower, upper };
pub const PitcherPlantCrop = struct {
    stage: PitcherStage = .stage_0,
    base: Position = .{ .x = 0, .y = 0, .z = 0 },
    exists: bool = true,
    pub fn canPlantOn(soil: CropSoil) bool {
        return soil == .farmland;
    }
    pub fn height(self: PitcherPlantCrop) u8 {
        return if (@intFromEnum(self.stage) >= @intFromEnum(PitcherStage.stage_3)) 2 else 1;
    }
    pub fn occupies(self: PitcherPlantCrop, position: Position) ?PitcherHalf {
        if (!self.exists) return null;
        if (position.x != self.base.x or position.z != self.base.z) return null;
        if (position.y == self.base.y) return .lower;
        if (self.height() == 2 and position.y == self.base.y + 1) return .upper;
        return null;
    }
    pub fn advance(self: *PitcherPlantCrop) bool {
        if (!self.exists or self.stage == .stage_4) return false;
        self.stage = @enumFromInt(@intFromEnum(self.stage) + 1);
        return true;
    }
    pub fn boneMeal(self: *PitcherPlantCrop) bool {
        return self.advance();
    }
    /// Breaking either occupied half removes the whole plant.
    pub fn breakHalf(self: *PitcherPlantCrop, position: Position) bool {
        if (self.occupies(position) == null) return false;
        self.exists = false;
        return true;
    }
    pub fn harvest(self: *PitcherPlantCrop) ?CropDrop {
        if (!self.exists or self.stage != .stage_4) return null;
        self.exists = false;
        return .{ .item = .pitcher_plant, .count = 1 };
    }
};

pub const SnifferEgg = struct {
    ticks_to_hatch: u32 = egg_hatch_ticks,
    pub fn place(on_moss_block: bool) SnifferEgg {
        return .{ .ticks_to_hatch = if (on_moss_block) moss_egg_hatch_ticks else egg_hatch_ticks };
    }
    pub fn tick(self: *SnifferEgg, ticks: u32) bool {
        self.ticks_to_hatch -|= ticks;
        return self.ticks_to_hatch == 0;
    }
};

pub const BreedingResult = struct { love_mode: bool, egg_drop: bool };
pub fn feedForBreeding(first_is_adult: bool, second_is_adult: bool, first_fed_seed: bool, second_fed_seed: bool) BreedingResult {
    const love = first_is_adult and second_is_adult and first_fed_seed and second_fed_seed;
    return .{ .love_mode = love, .egg_drop = love };
}

pub const Snifflet = struct {
    remaining_growth_ticks: u32 = snifflet_growth_ticks,
    pub fn feedTorchflowerSeeds(self: *Snifflet, count: u32) void {
        const reduction: u64 = @as(u64, count) * (snifflet_growth_ticks / 10);
        self.remaining_growth_ticks -|= @intCast(@min(reduction, snifflet_growth_ticks));
    }
    pub fn tick(self: *Snifflet, ticks: u32) bool {
        self.remaining_growth_ticks -|= ticks;
        return self.remaining_growth_ticks == 0;
    }
};

// Sniffer kinematics

test "idle sniffer begins search only on valid substrate" {
    var sniffer = Sniffer{};
    try std.testing.expect(!sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .stone));
    try std.testing.expect(sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .dirt));
    try std.testing.expectEqual(SnifferState.searching_sniff, sniffer.state);
}
test "searching sniff lasts thirty ticks then excites with lock and sound" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 1, .y = 2, .z = 3 }, .grass_block);
    for (0..29) |_| try std.testing.expect(!sniffer.tick(0).sound);
    const event = sniffer.tick(0);
    try std.testing.expectEqual(SnifferState.excited_sniff, sniffer.state);
    try std.testing.expect(event.sound and event.target_locked);
}
test "excited sniff transitions after twenty ticks" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .dirt);
    for (0..30) |_| _ = sniffer.tick(0);
    for (0..19) |_| _ = sniffer.tick(0);
    try std.testing.expectEqual(SnifferState.excited_sniff, sniffer.state);
    try std.testing.expect(sniffer.tick(0).digging_particle_burst);
    try std.testing.expectEqual(SnifferState.digging, sniffer.state);
}
test "digging emits periodic particles for two hundred ticks" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .podzol);
    for (0..50) |_| _ = sniffer.tick(0);
    var bursts: u32 = 0;
    for (0..200) |_| if (sniffer.tick(0).digging_particle_burst) {
        bursts += 1;
    };
    try std.testing.expectEqual(@as(u32, 10), bursts);
    try std.testing.expectEqual(SnifferState.rising, sniffer.state);
}
test "digging completes with loot and rising state" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .moss_block);
    for (0..249) |_| _ = sniffer.tick(99);
    const event = sniffer.tick(0);
    try std.testing.expectEqual(SeedLoot.torchflower_seeds, event.extruded_loot.?);
    try std.testing.expectEqual(SnifferState.rising, sniffer.state);
}
test "rising lasts twenty ticks before cooldown" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .dirt);
    for (0..250) |_| _ = sniffer.tick(0);
    for (0..19) |_| _ = sniffer.tick(0);
    try std.testing.expectEqual(SnifferState.rising, sniffer.state);
    _ = sniffer.tick(0);
    try std.testing.expectEqual(SnifferState.cooldown, sniffer.state);
}
test "cooldown lasts nine thousand six hundred ticks" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .dirt);
    for (0..270) |_| _ = sniffer.tick(0);
    for (0..9599) |_| _ = sniffer.tick(0);
    try std.testing.expectEqual(SnifferState.cooldown, sniffer.state);
    _ = sniffer.tick(0);
    try std.testing.expectEqual(SnifferState.idle, sniffer.state);
}
test "sniffer cannot begin another search during cooldown" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .dirt);
    for (0..270) |_| _ = sniffer.tick(0);
    try std.testing.expect(!sniffer.beginSearch(.{ .x = 32, .y = 0, .z = 0 }, .dirt));
}
test "sniffer target locks when excited" {
    var sniffer = Sniffer{};
    const target = Position{ .x = 5, .y = 4, .z = -3 };
    _ = sniffer.beginSearch(target, .dirt);
    for (0..30) |_| _ = sniffer.tick(0);
    try std.testing.expectEqual(target, sniffer.target.?);
}
test "visited scent blocks nearby area during cooldown" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .dirt);
    try std.testing.expect(sniffer.hasVisitedRecently(.{ .x = 4, .y = 0, .z = 0 }));
    try std.testing.expect(!sniffer.beginSearch(.{ .x = 4, .y = 0, .z = 0 }, .dirt));
}
test "scent radius includes sixteen blocks and excludes farther positions" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .dirt);
    try std.testing.expect(sniffer.hasVisitedRecently(.{ .x = 16, .y = 0, .z = 0 }));
    try std.testing.expect(!sniffer.hasVisitedRecently(.{ .x = 17, .y = 0, .z = 0 }));
}
test "expired scent permits repeat search" {
    var sniffer = Sniffer{};
    _ = sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .dirt);
    for (0..270 + scent_cooldown) |_| _ = sniffer.tick(0);
    try std.testing.expect(sniffer.beginSearch(.{ .x = 0, .y = 0, .z = 0 }, .dirt));
}
test "sniffer rejects all non organic substrates" {
    const bad = [_]Substrate{ .stone, .sand, .wood, .metal, .glass, .water, .air };
    for (bad) |block| try std.testing.expect(!isSniffable(block));
}
test "sniffer accepts each specified organic substrate" {
    const good = [_]Substrate{ .dirt, .grass_block, .podzol, .coarse_dirt, .rooted_dirt, .moss_block, .mud, .muddy_mangrove_roots };
    for (good) |block| try std.testing.expect(isSniffable(block));
}
test "seed loot has an even deterministic split across roll range" {
    var seeds: u32 = 0;
    var pods: u32 = 0;
    for (0..100) |roll| {
        var sniffer = Sniffer{};
        _ = sniffer.beginSearch(.{ .x = @intCast(roll), .y = 0, .z = 0 }, .dirt);
        for (0..249) |_| _ = sniffer.tick(@intCast(roll));
        if (sniffer.tick(@intCast(roll)).extruded_loot.? == .torchflower_seeds) seeds += 1 else pods += 1;
    }
    try std.testing.expectEqual(@as(u32, 50), seeds);
    try std.testing.expectEqual(@as(u32, 50), pods);
}

// Torchflower lifecycle

test "torchflower accepts farmland" {
    try std.testing.expect(TorchflowerCrop.canPlantOn(.farmland));
}
test "torchflower rejects other soil" {
    try std.testing.expect(!TorchflowerCrop.canPlantOn(.other));
}
test "torchflower grows from seedling through growing to mature" {
    var crop = TorchflowerCrop{};
    try std.testing.expect(crop.advance());
    try std.testing.expectEqual(TorchflowerStage.stage_1, crop.stage);
    try std.testing.expect(crop.advance());
    try std.testing.expectEqual(TorchflowerStage.mature, crop.stage);
}
test "torchflower bone meal advances one stage" {
    var crop = TorchflowerCrop{};
    try std.testing.expect(crop.boneMeal());
    try std.testing.expectEqual(TorchflowerStage.stage_1, crop.stage);
}
test "torchflower mature crop does not advance beyond mature" {
    var crop = TorchflowerCrop{ .stage = .mature };
    try std.testing.expect(!crop.boneMeal());
}
test "immature torchflower harvest yields one seed" {
    var crop = TorchflowerCrop{};
    const drops = crop.harvest();
    try std.testing.expectEqual(SeedLootOrFlora.torchflower_seeds, drops[0].item);
    try std.testing.expectEqual(@as(u8, 1), drops[0].count);
    try std.testing.expectEqual(@as(u8, 0), drops[1].count);
}
test "mature torchflower harvest yields flower and seed" {
    var crop = TorchflowerCrop{ .stage = .mature };
    const drops = crop.harvest();
    try std.testing.expectEqual(SeedLootOrFlora.torchflower, drops[0].item);
    try std.testing.expectEqual(SeedLootOrFlora.torchflower_seeds, drops[1].item);
}
test "torchflower harvest removes crop and cannot be repeated" {
    var crop = TorchflowerCrop{ .stage = .mature };
    _ = crop.harvest();
    try std.testing.expect(!crop.exists);
    try std.testing.expect(!crop.advance());
    try std.testing.expectEqual(@as(u8, 0), crop.harvest()[0].count);
}

// Pitcher plant lifecycle

test "pitcher plant requires farmland" {
    try std.testing.expect(PitcherPlantCrop.canPlantOn(.farmland));
}
test "pitcher plant rejects non farmland soil" {
    try std.testing.expect(!PitcherPlantCrop.canPlantOn(.other));
}
test "pitcher plant advances through all five stages" {
    var crop = PitcherPlantCrop{};
    for (1..5) |stage| {
        try std.testing.expect(crop.advance());
        try std.testing.expectEqual(@as(u8, @intCast(stage)), @intFromEnum(crop.stage));
    }
    try std.testing.expect(!crop.advance());
}
test "pitcher bone meal advances one stage" {
    var crop = PitcherPlantCrop{};
    try std.testing.expect(crop.boneMeal());
    try std.testing.expectEqual(PitcherStage.stage_1, crop.stage);
}
test "pitcher lower stages occupy one block" {
    const crop = PitcherPlantCrop{ .stage = .stage_2, .base = .{ .x = 2, .y = 3, .z = 4 } };
    try std.testing.expectEqual(@as(u8, 1), crop.height());
    try std.testing.expectEqual(PitcherHalf.lower, crop.occupies(.{ .x = 2, .y = 3, .z = 4 }).?);
    try std.testing.expect(crop.occupies(.{ .x = 2, .y = 4, .z = 4 }) == null);
}
test "pitcher stage three occupies lower and upper coordinates" {
    const crop = PitcherPlantCrop{ .stage = .stage_3, .base = .{ .x = 1, .y = 10, .z = 1 } };
    try std.testing.expectEqual(@as(u8, 2), crop.height());
    try std.testing.expectEqual(PitcherHalf.lower, crop.occupies(.{ .x = 1, .y = 10, .z = 1 }).?);
    try std.testing.expectEqual(PitcherHalf.upper, crop.occupies(.{ .x = 1, .y = 11, .z = 1 }).?);
}
test "pitcher stage four occupies two blocks" {
    const crop = PitcherPlantCrop{ .stage = .stage_4 };
    try std.testing.expectEqual(@as(u8, 2), crop.height());
}
test "breaking pitcher upper half removes whole plant" {
    var crop = PitcherPlantCrop{ .stage = .stage_4, .base = .{ .x = 0, .y = 7, .z = 0 } };
    try std.testing.expect(crop.breakHalf(.{ .x = 0, .y = 8, .z = 0 }));
    try std.testing.expect(!crop.exists);
    try std.testing.expect(crop.occupies(.{ .x = 0, .y = 7, .z = 0 }) == null);
    try std.testing.expect(crop.occupies(.{ .x = 0, .y = 8, .z = 0 }) == null);
}
test "breaking pitcher lower half removes whole plant" {
    var crop = PitcherPlantCrop{ .stage = .stage_3, .base = .{ .x = 0, .y = 7, .z = 0 } };
    try std.testing.expect(crop.breakHalf(.{ .x = 0, .y = 7, .z = 0 }));
    try std.testing.expect(!crop.exists);
}
test "pitcher ignores breaking an unrelated coordinate" {
    var crop = PitcherPlantCrop{ .stage = .stage_4 };
    try std.testing.expect(!crop.breakHalf(.{ .x = 3, .y = 0, .z = 0 }));
}
test "mature pitcher harvest yields one pitcher plant" {
    var crop = PitcherPlantCrop{ .stage = .stage_4 };
    const drop = crop.harvest().?;
    try std.testing.expectEqual(SeedLootOrFlora.pitcher_plant, drop.item);
    try std.testing.expectEqual(@as(u8, 1), drop.count);
    try std.testing.expect(!crop.exists);
    try std.testing.expect(crop.harvest() == null);
}
test "immature pitcher crop cannot be harvested for plant" {
    var crop = PitcherPlantCrop{ .stage = .stage_3 };
    try std.testing.expect(crop.harvest() == null);
}

// Eggs, breeding and baby growth

test "sniffer egg standard placement hatches after forty eight thousand ticks" {
    var egg = SnifferEgg.place(false);
    try std.testing.expect(!egg.tick(47_999));
    try std.testing.expect(egg.tick(1));
}
test "sniffer egg moss placement hatches after twenty four thousand ticks" {
    var egg = SnifferEgg.place(true);
    try std.testing.expectEqual(moss_egg_hatch_ticks, egg.ticks_to_hatch);
    try std.testing.expect(!egg.tick(23_999));
    try std.testing.expect(egg.tick(1));
}
test "two fed adults enter love mode and lay egg" {
    const result = feedForBreeding(true, true, true, true);
    try std.testing.expect(result.love_mode and result.egg_drop);
}
test "breeding requires both adults and both seeds" {
    try std.testing.expect(!feedForBreeding(false, true, true, true).love_mode);
    try std.testing.expect(!feedForBreeding(true, true, true, false).egg_drop);
}
test "snifflet takes forty eight thousand ticks to grow" {
    var baby = Snifflet{};
    try std.testing.expect(!baby.tick(47_999));
    try std.testing.expect(baby.tick(1));
}
test "each torchflower seed reduces snifflet growth by ten percent" {
    var baby = Snifflet{};
    baby.feedTorchflowerSeeds(1);
    try std.testing.expectEqual(@as(u32, 43_200), baby.remaining_growth_ticks);
}
test "snifflet multiple seed growth boost clamps at zero" {
    var baby = Snifflet{};
    baby.feedTorchflowerSeeds(10);
    try std.testing.expectEqual(@as(u32, 0), baby.remaining_growth_ticks);
}
