const std = @import("std");

pub const MAX_HEALTH: f32 = 10.0;
pub const WALK_SPEED: f32 = 3.0;
pub const SPRINT_SPEED: f32 = 6.0;
pub const PREY_BITE_DAMAGE: f32 = 2.0;
pub const POUNCE_MAX_DISTANCE: f32 = 5.0;
pub const POUNCE_MAX_HEIGHT: f32 = 2.5;
pub const POUNCE_GRAVITY: f32 = 20.0;
pub const AIM_TICKS: u16 = 30;
pub const SNOW_STUCK_TICKS: u16 = 40;
pub const SNOW_STUCK_CHANCE: f32 = 0.20;
pub const PLAYER_WAKE_DISTANCE: f32 = 3.0;
pub const FOOD_CONSUME_TICKS: u16 = 600;
pub const FOOD_HEAL: f32 = 4.0;

pub const FoxVariant = enum { red, snow };
pub const Biome = enum { taiga, old_growth_taiga, snowy_taiga, snowy_plains, other };
pub const PreyType = enum { chicken, rabbit, cod, salmon, tropical_fish, other };
pub const ItemType = enum { sweet_berries, raw_chicken, cooked_chicken, raw_rabbit, cooked_rabbit, raw_cod, cooked_cod, raw_salmon, cooked_salmon, tropical_fish, other };

pub const ItemStack = struct {
    item: ItemType,
    count: u8 = 1,
};

pub const Fox = struct {
    variant: FoxVariant,
    health: f32 = MAX_HEALTH,
    is_sleeping: bool = false,
    is_curled_up: bool = false,
    is_aiming: bool = false,
    is_pouncing: bool = false,
    is_stuck_in_snow: bool = false,
    is_baby: bool = false,
    isImmuneToBerryBush: bool = true,
    mouth_item: ?ItemStack = null,
    aim_ticks: u16 = 0,
    snow_stuck_ticks: u16 = 0,
    food_ticks: u16 = 0,
    love_mode_ticks: u16 = 0,

    pub fn init(variant: FoxVariant) Fox {
        return .{ .variant = variant };
    }

    pub fn canSpawnIn(self: Fox, biome: Biome) bool {
        return switch (self.variant) {
            .red => biome == .taiga or biome == .old_growth_taiga,
            .snow => biome == .snowy_taiga or biome == .snowy_plains,
        };
    }

    pub fn tickDaylight(self: *Fox, daytime: bool, shaded: bool, light_level: u8) void {
        self.is_sleeping = daytime and shaded and light_level <= 7;
        self.is_curled_up = self.is_sleeping;
    }

    pub fn wakeForPlayer(self: *Fox, distance: f32, player_sneaking: bool) bool {
        if (self.is_sleeping and !player_sneaking and distance <= PLAYER_WAKE_DISTANCE) {
            self.is_sleeping = false;
            self.is_curled_up = false;
            return true;
        }
        return false;
    }

    pub fn startAim(self: *Fox) void {
        self.is_aiming = true;
        self.aim_ticks = 0;
    }

    pub fn tickAim(self: *Fox, ticks: u16) bool {
        if (!self.is_aiming) return false;
        self.aim_ticks = @min(AIM_TICKS, self.aim_ticks +| ticks);
        if (self.aim_ticks == AIM_TICKS) {
            self.is_aiming = false;
            self.is_pouncing = true;
            return true;
        }
        return false;
    }

    pub fn landPounce(self: *Fox, prey_hit: bool, landing_in_snow: bool, chance_roll: f32) f32 {
        self.is_pouncing = false;
        if (landing_in_snow and chance_roll < SNOW_STUCK_CHANCE) {
            self.is_stuck_in_snow = true;
            self.snow_stuck_ticks = SNOW_STUCK_TICKS;
        }
        return if (prey_hit) PREY_BITE_DAMAGE else 0.0;
    }

    pub fn tickSnowStuck(self: *Fox, ticks: u16) void {
        self.snow_stuck_ticks -|= ticks;
        self.is_stuck_in_snow = self.snow_stuck_ticks > 0;
    }

    pub fn pickUpItem(self: *Fox, stack: ItemStack) bool {
        if (stack.count == 0) return false;
        if (self.mouth_item == null or (isEdible(stack.item) and !isEdible(self.mouth_item.?.item))) {
            self.mouth_item = .{ .item = stack.item, .count = 1 };
            self.food_ticks = 0;
            return true;
        }
        return false;
    }

    pub fn tickFood(self: *Fox, ticks: u16) f32 {
        const held = self.mouth_item orelse return 0;
        if (!isEdible(held.item)) return 0;
        self.food_ticks = @min(FOOD_CONSUME_TICKS, self.food_ticks +| ticks);
        if (self.food_ticks < FOOD_CONSUME_TICKS) return 0;
        self.mouth_item = null;
        self.food_ticks = 0;
        const healed = @min(FOOD_HEAL, MAX_HEALTH - self.health);
        self.health += healed;
        return healed;
    }

    pub fn breedWith(self: *Fox, mate: *Fox, offered: ItemType) bool {
        if (offered != .sweet_berries or self.is_sleeping or mate.is_sleeping) return false;
        self.love_mode_ticks = 600;
        mate.love_mode_ticks = 600;
        return true;
    }

    pub fn produceBaby(self: *Fox, mate: *Fox, variant_roll: f32) ?Fox {
        if (self.love_mode_ticks == 0 or mate.love_mode_ticks == 0) return null;
        self.love_mode_ticks = 0;
        mate.love_mode_ticks = 0;
        var baby = Fox.init(babyFoxVariant(self.variant, mate.variant, variant_roll));
        baby.is_baby = true;
        return baby;
    }
};

pub const PounceVelocity = struct { vx: f32, vy: f32, vz: f32, flight_time: f32 };

pub fn pounceVelocity(dx: f32, dz: f32) PounceVelocity {
    const distance = @sqrt(dx * dx + dz * dz);
    const travel = @min(distance, POUNCE_MAX_DISTANCE);
    const scale = if (distance > 0) travel / distance else 0;
    const vy = @sqrt(2.0 * POUNCE_GRAVITY * POUNCE_MAX_HEIGHT);
    const flight = 2.0 * vy / POUNCE_GRAVITY;
    return .{ .vx = dx * scale / flight, .vy = vy, .vz = dz * scale / flight, .flight_time = flight };
}

pub fn isPrey(prey: PreyType) bool {
    return prey != .other;
}

pub fn isEdible(item: ItemType) bool {
    return switch (item) {
        .raw_chicken, .cooked_chicken, .raw_rabbit, .cooked_rabbit, .raw_cod, .cooked_cod, .raw_salmon, .cooked_salmon, .tropical_fish, .sweet_berries => true,
        .other => false,
    };
}

pub const BerryHarvest = struct { drops: u8, next_stage: u2 };

pub fn harvestBerryBush(stage: u2, drop_roll: u8) ?BerryHarvest {
    if (stage < 2) return null;
    return .{ .drops = 2 + @as(u8, @intCast(drop_roll % 2)), .next_stage = 1 };
}

pub fn berryBushDamage(fox: Fox, prick_damage: f32) f32 {
    return if (fox.isImmuneToBerryBush) 0 else prick_damage;
}

pub fn babyFoxVariant(parent_a: FoxVariant, parent_b: FoxVariant, variant_roll: f32) FoxVariant {
    if (variant_roll < 0.05) return if (parent_a == .snow) .red else .snow;
    return if (variant_roll < 0.5) parent_a else parent_b;
}

test "red variant spawns in taiga biomes" {
    const fox = Fox.init(.red);
    try std.testing.expect(fox.canSpawnIn(.taiga));
    try std.testing.expect(fox.canSpawnIn(.old_growth_taiga));
    try std.testing.expect(!fox.canSpawnIn(.snowy_plains));
}
test "snow variant spawns in snowy biomes" {
    const fox = Fox.init(.snow);
    try std.testing.expect(fox.canSpawnIn(.snowy_taiga));
    try std.testing.expect(fox.canSpawnIn(.snowy_plains));
    try std.testing.expect(!fox.canSpawnIn(.taiga));
}
test "fox health is five hearts" { try std.testing.expectEqual(@as(f32, 10), Fox.init(.red).health); }
test "movement speed constants" { try std.testing.expectEqual(@as(f32, 3), WALK_SPEED); try std.testing.expectEqual(@as(f32, 6), SPRINT_SPEED); }
test "chickens are prey" { try std.testing.expect(isPrey(.chicken)); }
test "rabbits are prey" { try std.testing.expect(isPrey(.rabbit)); }
test "cod are prey" { try std.testing.expect(isPrey(.cod)); }
test "salmon are prey" { try std.testing.expect(isPrey(.salmon)); }
test "tropical fish are prey" { try std.testing.expect(isPrey(.tropical_fish)); }
test "other mobs are not prey" { try std.testing.expect(!isPrey(.other)); }
test "aim lasts thirty ticks before pounce" {
    var fox = Fox.init(.red); fox.startAim();
    try std.testing.expect(!fox.tickAim(29));
    try std.testing.expect(fox.is_aiming);
    try std.testing.expect(fox.tickAim(1));
    try std.testing.expect(fox.is_pouncing);
}
test "pounce launch velocity produces 2.5m apex" {
    const v = pounceVelocity(3, 4);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), v.vy * v.vy / (2 * POUNCE_GRAVITY), 0.001);
}
test "pounce covers five meters horizontally" {
    const v = pounceVelocity(6, 0);
    try std.testing.expectApproxEqAbs(POUNCE_MAX_DISTANCE, v.vx * v.flight_time, 0.001);
}
test "pounce velocity aims along target vector" {
    const v = pounceVelocity(3, 4);
    try std.testing.expectApproxEqAbs(@as(f32, 3), v.vx * v.flight_time, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4), v.vz * v.flight_time, 0.001);
}
test "landing bite deals two hp" { var fox = Fox.init(.red); try std.testing.expectEqual(PREY_BITE_DAMAGE, fox.landPounce(true, false, 1)); }
test "missed pounce deals no damage" { var fox = Fox.init(.red); try std.testing.expectEqual(@as(f32, 0), fox.landPounce(false, false, 1)); }
test "snow landing can stick head for forty ticks" { var fox = Fox.init(.snow); _ = fox.landPounce(false, true, 0.1); try std.testing.expectEqual(SNOW_STUCK_TICKS, fox.snow_stuck_ticks); }
test "snow landing avoids stick when roll misses chance" { var fox = Fox.init(.snow); _ = fox.landPounce(false, true, 0.2); try std.testing.expect(!fox.is_stuck_in_snow); }
test "snow stuck timer releases fox" { var fox = Fox.init(.snow); _ = fox.landPounce(false, true, 0); fox.tickSnowStuck(40); try std.testing.expect(!fox.is_stuck_in_snow); }
test "berry bush damage immunity blocks prick damage" { try std.testing.expectEqual(@as(f32, 0), berryBushDamage(Fox.init(.red), 1)); }
test "mature stage two bush drops two berries and regresses" { const harvest = harvestBerryBush(2, 0).?; try std.testing.expectEqual(@as(u8, 2), harvest.drops); try std.testing.expectEqual(@as(u2, 1), harvest.next_stage); }
test "mature stage three bush drops three berries and regresses" { const harvest = harvestBerryBush(3, 1).?; try std.testing.expectEqual(@as(u8, 3), harvest.drops); try std.testing.expectEqual(@as(u2, 1), harvest.next_stage); }
test "immature berry bush cannot be harvested" { try std.testing.expect(harvestBerryBush(1, 0) == null); }
test "fox holds one item stack in mouth" { var fox = Fox.init(.red); try std.testing.expect(fox.pickUpItem(.{ .item = .other, .count = 8 })); try std.testing.expectEqual(@as(u8, 1), fox.mouth_item.?.count); }
test "edible pickup can replace held nonfood item" { var fox = Fox.init(.red); _ = fox.pickUpItem(.{ .item = .other }); try std.testing.expect(fox.pickUpItem(.{ .item = .raw_chicken, .count = 3 })); try std.testing.expectEqual(ItemType.raw_chicken, fox.mouth_item.?.item); }
test "food heals after six hundred ticks" { var fox = Fox.init(.red); fox.health = 4; _ = fox.pickUpItem(.{ .item = .raw_chicken }); try std.testing.expectEqual(@as(f32, 0), fox.tickFood(599)); try std.testing.expectEqual(@as(f32, 4), fox.tickFood(1)); try std.testing.expectEqual(@as(f32, 8), fox.health); }
test "food healing clamps at maximum health" { var fox = Fox.init(.red); fox.health = 9; _ = fox.pickUpItem(.{ .item = .sweet_berries }); try std.testing.expectEqual(@as(f32, 1), fox.tickFood(600)); try std.testing.expectEqual(MAX_HEALTH, fox.health); }
test "daytime shaded low light causes curled sleep" { var fox = Fox.init(.red); fox.tickDaylight(true, true, 7); try std.testing.expect(fox.is_sleeping); try std.testing.expect(fox.is_curled_up); }
test "bright or unshaded daytime does not cause sleep" { var fox = Fox.init(.red); fox.tickDaylight(true, true, 8); try std.testing.expect(!fox.is_sleeping); fox.tickDaylight(true, false, 0); try std.testing.expect(!fox.is_sleeping); }
test "approaching player wakes fox at three meters" { var fox = Fox.init(.red); fox.is_sleeping = true; fox.is_curled_up = true; try std.testing.expect(fox.wakeForPlayer(3, false)); try std.testing.expect(!fox.is_sleeping); try std.testing.expect(!fox.is_curled_up); }
test "sneaking player does not wake fox" { var fox = Fox.init(.red); fox.is_sleeping = true; try std.testing.expect(!fox.wakeForPlayer(1, true)); try std.testing.expect(fox.is_sleeping); }
test "distant player does not wake fox" { var fox = Fox.init(.red); fox.is_sleeping = true; try std.testing.expect(!fox.wakeForPlayer(3.1, false)); }
test "sweet berries trigger love mode and produce baby fox" { var a = Fox.init(.red); var b = Fox.init(.snow); try std.testing.expect(a.breedWith(&b, .sweet_berries)); const baby = a.produceBaby(&b, 0.2).?; try std.testing.expect(baby.is_baby); try std.testing.expectEqual(FoxVariant.red, baby.variant); }
test "non-berry food does not trigger breeding" { var a = Fox.init(.red); var b = Fox.init(.red); try std.testing.expect(!a.breedWith(&b, .raw_chicken)); }
