const std = @import("std");

pub const FurnaceJob = struct { x: i32, y: i32, z: i32, t: f32, fuel: u8, input: u8 };
pub const furnace_cap: usize = 16;
pub const smelt_time: f32 = 10.0;

pub const RawPork: u8 = 18;
pub const RawMutton: u8 = 19;
pub const Sand: u8 = 14;
pub const IronOre: u8 = 13;
pub const CookedPork: u8 = 20;
pub const CookedMutton: u8 = 21;
pub const Glass: u8 = 15;
pub const IronIngot: u8 = 26;
pub const AncientDebris: u8 = 70;
pub const NetheriteScrap: u8 = 71;
pub const None: u8 = 0;

pub fn smeltResult(input: u8) u8 {
    return switch (input) {
        RawPork => CookedPork,
        RawMutton => CookedMutton,
        Sand => Glass,
        IronOre => IronIngot,
        AncientDebris => NetheriteScrap,
        else => None,
    };
}

pub fn isSmeltable(input: u8) bool {
    return smeltResult(input) != None;
}

test "smelting recipes" {
    try std.testing.expectEqual(smeltResult(RawPork), CookedPork);
    try std.testing.expectEqual(smeltResult(RawMutton), CookedMutton);
    try std.testing.expectEqual(smeltResult(Sand), Glass);
    try std.testing.expectEqual(smeltResult(IronOre), IronIngot);
    try std.testing.expectEqual(smeltResult(AncientDebris), NetheriteScrap);
    try std.testing.expectEqual(smeltResult(None), None);
    try std.testing.expectEqual(smeltResult(99), None);
}

test "smeltable check" {
    try std.testing.expect(isSmeltable(RawPork));
    try std.testing.expect(isSmeltable(AncientDebris));
    try std.testing.expect(!isSmeltable(None));
}

pub const SmeltTickOutcome = struct {
    done_item: ?u8,
    fuel_consumed: bool,
    reset_timer: bool,
};

pub fn tickJob(t: *f32, fuel: *u8, input: *u8, dt: f32) SmeltTickOutcome {
    if (input.* != None and fuel.* > 0) {
        t.* += dt;
        if (t.* >= smelt_time) {
            t.* = 0.0;
            fuel.* -= 1;
            const res = smeltResult(input.*);
            input.* = None;
            return .{
                .done_item = if (res != None) res else null,
                .fuel_consumed = true,
                .reset_timer = true,
            };
        }
        return .{
            .done_item = null,
            .fuel_consumed = false,
            .reset_timer = false,
        };
    } else {
        t.* = 0.0;
        return .{
            .done_item = null,
            .fuel_consumed = false,
            .reset_timer = true,
        };
    }
}

test "tickJob progress and completion" {
    var t: f32 = 0.0;
    var fuel: u8 = 2;
    var input: u8 = RawPork;

    // 5 seconds: not done
    const r1 = tickJob(&t, &fuel, &input, 5.0);
    try std.testing.expectEqual(@as(?u8, null), r1.done_item);
    try std.testing.expect(!r1.fuel_consumed);
    try std.testing.expectEqual(@as(f32, 5.0), t);

    // Another 5 seconds: completes smelting
    const r2 = tickJob(&t, &fuel, &input, 5.0);
    try std.testing.expectEqual(@as(?u8, CookedPork), r2.done_item);
    try std.testing.expect(r2.fuel_consumed);
    try std.testing.expectEqual(@as(u8, 1), fuel);
    try std.testing.expectEqual(None, input);
    try std.testing.expectEqual(@as(f32, 0.0), t);

    // No input: resets timer
    t = 4.0;
    const r3 = tickJob(&t, &fuel, &input, 1.0);
    try std.testing.expectEqual(@as(?u8, null), r3.done_item);
    try std.testing.expectEqual(@as(f32, 0.0), t);
}

pub const FeedAction = enum {
    add_fuel,
    set_input,
    none,
};

pub fn evaluateFurnaceFeed(is_coal: bool, is_smeltable_input: bool, current_fuel: u8, current_input: u8) FeedAction {
    if (is_coal and current_fuel < 8) return .add_fuel;
    if (is_smeltable_input and current_input == None) return .set_input;
    return .none;
}

test "evaluateFurnaceFeed actions" {
    try std.testing.expectEqual(FeedAction.add_fuel, evaluateFurnaceFeed(true, false, 0, None));
    try std.testing.expectEqual(FeedAction.none, evaluateFurnaceFeed(true, false, 8, None));
    try std.testing.expectEqual(FeedAction.set_input, evaluateFurnaceFeed(false, true, 2, None));
    try std.testing.expectEqual(FeedAction.none, evaluateFurnaceFeed(false, true, 2, RawPork));
    try std.testing.expectEqual(FeedAction.none, evaluateFurnaceFeed(false, false, 2, None));
}
