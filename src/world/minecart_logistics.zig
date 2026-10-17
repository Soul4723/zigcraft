const std = @import("std");

/// Minecart storage uses the normal Minecraft stack limit for comparator math.
pub const minecart_slot_count: usize = 5;
pub const minecart_stack_limit: u8 = 64;
pub const hopper_suction_cooldown_seconds: f32 = 0.05;
pub const stationary_hopper_cooldown_seconds: f32 = 0.4;
pub const hopper_suction_rate: f32 = 20.0;
pub const furnace_traction_speed: f32 = 4.0;
pub const coal_fuel_seconds: f32 = 180.0;
pub const max_fuel_seconds: f32 = 1800.0;
pub const activator_fuse_ticks: u16 = 80;
pub const tnt_minimum_impact_speed: f32 = 6.0;
pub const tnt_minimum_fall_distance: f32 = 3.0;
pub const tnt_base_blast_radius: f32 = 4.0;
pub const tnt_max_blast_radius: f32 = 8.0;
pub const coal_item_id: u16 = 12;

pub const InventorySlot = struct {
    item_id: u16 = 0,
    count: u8 = 0,
};

pub const ItemStack = InventorySlot;

/// A five-slot hopper minecart. The cooldown is intentionally eight times
/// shorter than a stationary hopper's 0.4 second transfer interval.
pub const HopperMinecart = struct {
    slots: [minecart_slot_count]InventorySlot = emptySlots(),
    is_locked_by_activator_rail: bool = false,
    suction_cooldown: f32 = 0.0,

    pub fn init() HopperMinecart {
        return .{};
    }

    pub fn setActivatorRailPowered(self: *HopperMinecart, powered: bool) void {
        self.is_locked_by_activator_rail = powered;
    }

    pub fn lock(self: *HopperMinecart) void {
        self.is_locked_by_activator_rail = true;
    }

    pub fn unlock(self: *HopperMinecart) void {
        self.is_locked_by_activator_rail = false;
    }

    pub fn totalItems(self: HopperMinecart) u16 {
        var total: u16 = 0;
        for (self.slots) |slot| total += slot.count;
        return total;
    }

    pub fn occupiedSlots(self: HopperMinecart) u8 {
        var occupied: u8 = 0;
        for (self.slots) |slot| {
            if (slot.count != 0) occupied += 1;
        }
        return occupied;
    }

    /// Pull items from stacks directly above the cart. One item is transferred
    /// every 0.05 seconds, up to the elapsed time supplied by `dt`.
    pub fn suctionTick(self: *HopperMinecart, above: []ItemStack, dt: f32) u8 {
        if (self.is_locked_by_activator_rail or dt <= 0.0) return 0;
        self.suction_cooldown += dt;
        var moved: u8 = 0;
        while (self.suction_cooldown + 0.000001 >= hopper_suction_cooldown_seconds) {
            const source_index = findSource(above) orelse break;
            if (!self.insertOne(above[source_index].item_id)) break;
            above[source_index].count -= 1;
            self.suction_cooldown -= hopper_suction_cooldown_seconds;
            moved += 1;
        }
        return moved;
    }

    pub fn suctionFromContainer(self: *HopperMinecart, container: []ItemStack, dt: f32) u8 {
        return self.suctionTick(container, dt);
    }

    pub fn suctionFromGround(self: *HopperMinecart, ground_item: *ItemStack, dt: f32) u8 {
        return self.suctionTick(ground_item[0..1], dt);
    }

    fn insertOne(self: *HopperMinecart, item_id: u16) bool {
        for (&self.slots) |*slot| {
            if (slot.count != 0 and slot.item_id == item_id and slot.count < minecart_stack_limit) {
                slot.count += 1;
                return true;
            }
        }
        for (&self.slots) |*slot| {
            if (slot.count == 0) {
                slot.item_id = item_id;
                slot.count = 1;
                return true;
            }
        }
        return false;
    }
};

fn emptySlots() [minecart_slot_count]InventorySlot {
    return .{ .{}, .{}, .{}, .{}, .{} };
}

fn findSource(stacks: []const ItemStack) ?usize {
    for (stacks, 0..) |stack, index| {
        if (stack.count != 0 and stack.item_id != 0) return index;
    }
    return null;
}

/// Vanilla-style fullness readout: empty is 0, a non-empty partial inventory
/// is 1..14, and a full five-slot inventory is 15.
pub fn detectorRailComparatorSignal(cart: HopperMinecart) u4 {
    return comparatorSignalForSlots(&cart.slots);
}

pub fn comparatorSignalForSlots(slots: []const InventorySlot) u4 {
    if (slots.len == 0) return 0;
    var total: u32 = 0;
    for (slots) |slot| total += slot.count;
    if (total == 0) return 0;
    const capacity: u32 = @as(u32, @intCast(slots.len)) * minecart_stack_limit;
    if (total >= capacity) return 15;
    return @as(u4, @intCast(1 + (total * 14) / capacity));
}

pub const RailAxis = enum { x, z };

pub const FuelKind = enum { coal, charcoal };

pub const CoupledCart = struct {
    position_along_axis: f32 = 0.0,
    velocity_along_axis: f32 = 0.0,
};

/// Furnace minecart engine state. Coal and charcoal each add three minutes,
/// while fuel is capped at thirty minutes to prevent runaway accumulation.
pub const FurnaceMinecartEngine = struct {
    fuel_seconds: f32 = 0.0,
    rail_axis: RailAxis = .x,
    direction: f32 = 1.0,

    pub fn init(axis: RailAxis) FurnaceMinecartEngine {
        return .{ .rail_axis = axis };
    }

    pub fn addFuel(self: *FurnaceMinecartEngine, kind: FuelKind, count: u8) f32 {
        _ = kind;
        const before = self.fuel_seconds;
        self.fuel_seconds = @min(max_fuel_seconds, self.fuel_seconds + @as(f32, @floatFromInt(count)) * coal_fuel_seconds);
        return self.fuel_seconds - before;
    }

    pub fn addCoal(self: *FurnaceMinecartEngine, count: u8) f32 {
        return self.addFuel(.coal, count);
    }

    pub fn addCharcoal(self: *FurnaceMinecartEngine, count: u8) f32 {
        return self.addFuel(.charcoal, count);
    }

    pub fn setDirection(self: *FurnaceMinecartEngine, direction: f32) void {
        self.direction = if (direction < 0.0) -1.0 else 1.0;
    }

    pub fn isBurning(self: FurnaceMinecartEngine) bool {
        return self.fuel_seconds > 0.0;
    }

    pub fn tractionVelocity(self: FurnaceMinecartEngine) f32 {
        if (!self.isBurning()) return 0.0;
        return furnace_traction_speed * self.direction;
    }

    pub fn tick(self: *FurnaceMinecartEngine, dt: f32) void {
        if (dt <= 0.0) return;
        self.fuel_seconds = @max(0.0, self.fuel_seconds - dt);
    }

    /// Push all coupled carts along the engine's rail axis at 4 m/s while fuel burns.
    pub fn shuntCoupledCarts(self: *FurnaceMinecartEngine, carts: []CoupledCart, dt: f32) void {
        if (dt <= 0.0 or !self.isBurning()) return;
        const velocity = self.tractionVelocity();
        for (carts) |*cart| {
            cart.velocity_along_axis = velocity;
            cart.position_along_axis += velocity * dt;
        }
        self.tick(dt);
    }
};

/// TNT minecart fuse and impact model. Activator rails use a normal four-second
/// fuse; high-speed collisions and sufficiently long falls detonate immediately.
pub const TntMinecartFuse = struct {
    fuse_ticks: u16 = 0,
    primed: bool = false,
    detonated: bool = false,
    blast_radius: f32 = tnt_base_blast_radius,
    tick_accumulator: f32 = 0.0,

    pub fn init() TntMinecartFuse {
        return .{};
    }

    pub fn primeByActivatorRail(self: *TntMinecartFuse, powered: bool) bool {
        if (!powered or self.detonated or self.primed) return false;
        self.primed = true;
        self.fuse_ticks = activator_fuse_ticks;
        self.blast_radius = tnt_base_blast_radius;
        return true;
    }

    pub fn primeByHighSpeedCollision(self: *TntMinecartFuse, speed: f32) bool {
        if (speed < tnt_minimum_impact_speed or self.detonated) return false;
        self.detonateAtImpactSpeed(speed);
        return true;
    }

    pub fn primeByFall(self: *TntMinecartFuse, fall_distance: f32) bool {
        if (fall_distance < tnt_minimum_fall_distance or self.detonated) return false;
        const impact_velocity = @sqrt(@as(f32, 2.0) * 9.81 * fall_distance);
        self.detonateAtImpactSpeed(impact_velocity);
        return true;
    }

    pub fn primeByFallWithVelocity(self: *TntMinecartFuse, fall_distance: f32, impact_velocity: f32) bool {
        if (fall_distance < tnt_minimum_fall_distance or self.detonated) return false;
        self.detonateAtImpactSpeed(impact_velocity);
        return true;
    }

    pub fn detonateAtImpactSpeed(self: *TntMinecartFuse, impact_velocity: f32) void {
        if (self.detonated) return;
        self.primed = true;
        self.fuse_ticks = 0;
        self.blast_radius = blastRadiusForImpactVelocity(impact_velocity);
        self.detonated = true;
    }

    pub fn tick(self: *TntMinecartFuse, dt: f32) bool {
        if (!self.primed or self.detonated or dt <= 0.0) return self.detonated;
        self.tick_accumulator += dt * 20.0;
        while (self.tick_accumulator >= 1.0 and self.fuse_ticks > 0) {
            self.tick_accumulator -= 1.0;
            self.fuse_ticks -= 1;
        }
        if (self.fuse_ticks == 0) self.detonated = true;
        return self.detonated;
    }
};

pub fn blastRadiusForImpactVelocity(velocity: f32) f32 {
    if (velocity <= 0.0) return tnt_base_blast_radius;
    return @min(tnt_max_blast_radius, @max(tnt_base_blast_radius, tnt_base_blast_radius + velocity * velocity * 0.0625));
}

test "hopper starts with five empty slots" {
    const cart = HopperMinecart.init();
    try std.testing.expectEqual(@as(usize, 5), cart.slots.len);
    try std.testing.expectEqual(@as(u16, 0), cart.totalItems());
    try std.testing.expect(!cart.is_locked_by_activator_rail);
}

test "hopper suction transfers one item every 0.05 seconds" {
    var cart = HopperMinecart.init();
    var above = [_]ItemStack{.{ .item_id = 42, .count = 8 }};
    try std.testing.expectEqual(@as(u8, 1), cart.suctionTick(&above, 0.05));
    try std.testing.expectEqual(@as(u8, 1), cart.suctionTick(&above, 0.05));
    try std.testing.expectEqual(@as(u8, 6), above[0].count);
    try std.testing.expectEqual(@as(u16, 2), cart.totalItems());
}

test "hopper is eight times faster than stationary hopper" {
    try std.testing.expectEqual(@as(f32, 0.05), hopper_suction_cooldown_seconds);
    try std.testing.expectEqual(@as(f32, 0.4), stationary_hopper_cooldown_seconds);
    try std.testing.expectEqual(@as(f32, 8.0), stationary_hopper_cooldown_seconds / hopper_suction_cooldown_seconds);
    var cart = HopperMinecart.init();
    var above = [_]ItemStack{.{ .item_id = 7, .count = 32 }};
    try std.testing.expectEqual(@as(u8, 20), cart.suctionTick(&above, 1.0));
}

test "activator rail locks and unlocks hopper suction" {
    var cart = HopperMinecart.init();
    var above = [_]ItemStack{.{ .item_id = 9, .count = 4 }};
    cart.lock();
    try std.testing.expectEqual(@as(u8, 0), cart.suctionTick(&above, 1.0));
    cart.unlock();
    try std.testing.expectEqual(@as(u8, 4), cart.suctionTick(&above, 1.0));
    try std.testing.expectEqual(@as(u16, 4), cart.totalItems());
}

test "hopper fills matching slots and then distinct slots" {
    var cart = HopperMinecart.init();
    var above = [_]ItemStack{ .{ .item_id = 1, .count = 64 }, .{ .item_id = 2, .count = 2 } };
    _ = cart.suctionTick(&above, 0.1);
    try std.testing.expectEqual(@as(u8, 2), cart.slots[0].count);
    _ = cart.suctionTick(&above, 3.2);
    try std.testing.expectEqual(@as(u8, 64), cart.slots[0].count);
    try std.testing.expectEqual(@as(u8, 2), cart.slots[1].count);
}

test "hopper suction also accepts a ground item entity" {
    var cart = HopperMinecart.init();
    var ground = ItemStack{ .item_id = 88, .count = 3 };
    try std.testing.expectEqual(@as(u8, 3), cart.suctionFromGround(&ground, 0.15));
    try std.testing.expectEqual(@as(u8, 0), ground.count);
}

test "detector comparator reads empty, partial, and full hopper" {
    var cart = HopperMinecart.init();
    try std.testing.expectEqual(@as(u4, 0), detectorRailComparatorSignal(cart));
    cart.slots[0] = .{ .item_id = 5, .count = 1 };
    try std.testing.expectEqual(@as(u4, 1), detectorRailComparatorSignal(cart));
    for (&cart.slots) |*slot| slot.* = .{ .item_id = 5, .count = 64 };
    try std.testing.expectEqual(@as(u4, 15), detectorRailComparatorSignal(cart));
}

test "detector comparator spans all 0..15 readout strengths" {
    var cart = HopperMinecart.init();
    var previous: u4 = 0;
    var count: u16 = 0;
    while (count <= 320) : (count += 1) {
        for (&cart.slots) |*slot| slot.* = .{};
        var remaining = count;
        for (&cart.slots) |*slot| {
            const fill: u8 = @intCast(@min(@as(u16, 64), remaining));
            slot.* = .{ .item_id = if (fill == 0) 0 else 1, .count = fill };
            remaining -= fill;
        }
        const signal = detectorRailComparatorSignal(cart);
        try std.testing.expect(signal >= previous);
        previous = signal;
    }
    try std.testing.expectEqual(@as(u4, 15), previous);
}

test "furnace coal adds 180 seconds and caps at 1800" {
    var engine = FurnaceMinecartEngine.init(.x);
    try std.testing.expectEqual(@as(f32, 180.0), engine.addCoal(1));
    try std.testing.expectEqual(@as(f32, 180.0), engine.fuel_seconds);
    try std.testing.expectEqual(@as(f32, 1620.0), engine.addCharcoal(10));
    try std.testing.expectEqual(@as(f32, 1800.0), engine.fuel_seconds);
    try std.testing.expectEqual(@as(f32, 0.0), engine.addCoal(1));
}

test "furnace minecart shunts coupled carts at four metres per second" {
    var engine = FurnaceMinecartEngine.init(.z);
    _ = engine.addCoal(1);
    engine.setDirection(-1.0);
    var carts = [_]CoupledCart{.{}};
    engine.shuntCoupledCarts(&carts, 2.0);
    try std.testing.expectEqual(@as(f32, -4.0), carts[0].velocity_along_axis);
    try std.testing.expectEqual(@as(f32, -8.0), carts[0].position_along_axis);
    try std.testing.expectEqual(@as(f32, 178.0), engine.fuel_seconds);
}

test "furnace traction stops after fuel expires" {
    var engine = FurnaceMinecartEngine.init(.x);
    _ = engine.addCoal(1);
    engine.tick(180.0);
    try std.testing.expect(!engine.isBurning());
    try std.testing.expectEqual(@as(f32, 0.0), engine.tractionVelocity());
}

test "activator rail primes an eighty tick TNT fuse" {
    var fuse = TntMinecartFuse.init();
    try std.testing.expect(fuse.primeByActivatorRail(true));
    try std.testing.expectEqual(@as(u16, 80), fuse.fuse_ticks);
    try std.testing.expect(!fuse.detonated);
    try std.testing.expect(!fuse.tick(3.9));
    try std.testing.expect(fuse.tick(0.1));
    try std.testing.expect(fuse.detonated);
    try std.testing.expectEqual(@as(f32, 4.0), fuse.blast_radius);
}

test "unpowered activator rail does not prime TNT" {
    var fuse = TntMinecartFuse.init();
    try std.testing.expect(!fuse.primeByActivatorRail(false));
    try std.testing.expectEqual(@as(u16, 0), fuse.fuse_ticks);
}

test "high speed TNT collision detonates instantly" {
    var fuse = TntMinecartFuse.init();
    try std.testing.expect(fuse.primeByHighSpeedCollision(6.0));
    try std.testing.expect(fuse.detonated);
    try std.testing.expectEqual(@as(u16, 0), fuse.fuse_ticks);
    try std.testing.expect(fuse.blast_radius > 4.0);
}

test "TNT impact blast radius scales with velocity squared and clamps" {
    try std.testing.expectEqual(@as(f32, 4.0), blastRadiusForImpactVelocity(0.0));
    try std.testing.expect(blastRadiusForImpactVelocity(8.0) > blastRadiusForImpactVelocity(6.0));
    try std.testing.expectEqual(@as(f32, 8.0), blastRadiusForImpactVelocity(20.0));
}

test "falling TNT from three blocks detonates immediately" {
    var fuse = TntMinecartFuse.init();
    try std.testing.expect(fuse.primeByFall(3.0));
    try std.testing.expect(fuse.detonated);
    try std.testing.expect(fuse.blast_radius >= 4.0 and fuse.blast_radius <= 8.0);
    var safe = TntMinecartFuse.init();
    try std.testing.expect(!safe.primeByFall(2.99));
    try std.testing.expect(!safe.detonated);
}
