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
pub const None: u8 = 0;

pub fn smeltResult(input: u8) u8 {
    return switch (input) {
        RawPork => CookedPork,
        RawMutton => CookedMutton,
        Sand => Glass,
        IronOre => IronIngot,
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
    try std.testing.expectEqual(smeltResult(None), None);
    try std.testing.expectEqual(smeltResult(99), None);
}

test "smeltable check" {
    try std.testing.expect(isSmeltable(RawPork));
    try std.testing.expect(!isSmeltable(None));
}
