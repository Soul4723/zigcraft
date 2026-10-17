const std = @import("std");

/// Timing and duration constants for Dried Ghast and Happy Ghast lifecycles.
pub const dried_ghast_hydration_duration: f32 = 1200.0; // 20 minutes (24000 ticks)
pub const dried_ghast_hydration_ticks: u32 = 24000;
pub const dehydration_rate_multiplier: f32 = 0.25; // Reverts 4x slower than hydration (4800s full dry)

pub const ghastling_growth_duration: f32 = 1200.0; // 20 minutes (24000 ticks)
pub const ghastling_growth_ticks: u32 = 24000;
pub const snowball_growth_reduction: f32 = 120.0; // 10% reduction per snowball (2400 ticks)
pub const snowball_growth_reduction_ticks: u32 = 2400;

pub const happy_ghast_seat_count: usize = 4;
pub const dorsal_top_y_offset: f32 = 2.0;

/// Crafting requirements for Dried Ghast block.
pub const bone_blocks_per_craft: u8 = 8;
pub const ghast_tears_per_craft: u8 = 1;

/// Harness recipe requirements: 3 Leather + 2 Glass + 1 Wool.
pub const harness_leather_required: u8 = 3;
pub const harness_glass_required: u8 = 2;
pub const harness_wool_required: u8 = 1;

/// 4 hydration stages for the Dried Ghast block.
pub const HydrationStage = enum(u8) {
    frowning = 0,
    neutral = 1,
    smiling = 2,
    hydrated_spawn = 3,
};

/// 3D offset relative to the Happy Ghast center.
pub const SeatOffset = struct {
    x: f32,
    y: f32,
    z: f32,
};

/// Seat positions relative to Happy Ghast center.
/// Driver at seat 0 (front center), passengers at 1 (left), 2 (right), 3 (rear).
pub const driver_seat_offset: SeatOffset = .{ .x = 0.0, .y = 1.0, .z = 1.2 };
pub const passenger_left_offset: SeatOffset = .{ .x = -0.9, .y = 1.0, .z = 0.0 };
pub const passenger_right_offset: SeatOffset = .{ .x = 0.9, .y = 1.0, .z = 0.0 };
pub const passenger_rear_offset: SeatOffset = .{ .x = 0.0, .y = 1.0, .z = -1.2 };

pub const seat_offsets = [happy_ghast_seat_count]SeatOffset{
    driver_seat_offset,
    passenger_left_offset,
    passenger_right_offset,
    passenger_rear_offset,
};

/// Returns the 3D local offset for the given seat index.
pub fn getSeatOffset(seat: u8) ?SeatOffset {
    if (seat >= happy_ghast_seat_count) return null;
    return seat_offsets[seat];
}

/// Computes the absolute world coordinates of a rider seat given the Happy Ghast's base position and yaw.
pub fn computeWorldSeatPosition(gx: f32, gy: f32, gz: f32, yaw: f32, seat: u8) ?struct { x: f32, y: f32, z: f32 } {
    const offset = getSeatOffset(seat) orelse return null;
    const sin_y = @sin(yaw);
    const cos_y = @cos(yaw);
    const forward_x = sin_y;
    const forward_z = cos_y;
    const right_x = cos_y;
    const right_z = -sin_y;

    return .{
        .x = gx + forward_x * offset.z + right_x * offset.x,
        .y = gy + offset.y,
        .z = gz + forward_z * offset.z + right_z * offset.x,
    };
}

/// Recipe validator for crafting a Dried Ghast block from Bone Blocks and Ghast Tears.
pub fn canCraftDriedGhast(bone_blocks: u8, ghast_tears: u8) bool {
    return bone_blocks >= bone_blocks_per_craft and ghast_tears >= ghast_tears_per_craft;
}

/// Crafts a Dried Ghast block if sufficient materials are provided.
pub fn craftDriedGhast(bone_blocks: u8, ghast_tears: u8) ?DriedGhastState {
    if (!canCraftDriedGhast(bone_blocks, ghast_tears)) return null;
    return DriedGhastState.init();
}

/// State for the renewable Dried Ghast block found in Nether Soul Sand Valleys or crafted.
/// When waterlogged, progresses through 4 hydration stages over 1200.0s (20 minutes).
/// If water is removed, regresses slowly (4x slower). Spawns a friendly Ghastling upon completion.
pub const DriedGhastState = struct {
    is_waterlogged: bool = false,
    hydration_progress: f32 = 0.0,
    ghastling_spawned: bool = false,

    pub fn init() DriedGhastState {
        return .{};
    }

    /// Returns the current hydration stage based on accumulated hydration progress.
    pub fn stage(self: DriedGhastState) HydrationStage {
        const quarter = dried_ghast_hydration_duration / 4.0;
        if (self.hydration_progress >= dried_ghast_hydration_duration) return .hydrated_spawn;
        if (self.hydration_progress >= quarter * 2.0) return .smiling;
        if (self.hydration_progress >= quarter) return .neutral;
        return .frowning;
    }

    /// Advances hydration while waterlogged and slowly reverses it when dry.
    /// Returns true exactly once, at the transition when the Ghastling becomes ready to spawn.
    pub fn update(self: *DriedGhastState, delta_seconds: f32) bool {
        if (delta_seconds <= 0.0 or self.ghastling_spawned) return false;
        if (self.is_waterlogged) {
            self.hydration_progress = @min(dried_ghast_hydration_duration, self.hydration_progress + delta_seconds);
            if (self.hydration_progress >= dried_ghast_hydration_duration) {
                self.ghastling_spawned = true;
                return true;
            }
        } else {
            // Dehydration takes four times longer than hydration (dehydration_rate_multiplier = 0.25).
            self.hydration_progress = @max(0.0, self.hydration_progress - delta_seconds * dehydration_rate_multiplier);
        }
        return false;
    }

    /// Advances the block state by one standard game tick (0.05 seconds).
    pub fn tick(self: *DriedGhastState) bool {
        return self.update(0.05);
    }
};

/// Passive baby flying mob state. Follows players holding Snowballs.
/// Feeding Snowballs accelerates growth by 10% (120.0s) toward maturing into a Happy Ghast.
pub const GhastlingState = struct {
    growth_timer: f32 = ghastling_growth_duration,
    is_baby: bool = true,
    follows_snowball_holder: bool = false,

    pub fn init() GhastlingState {
        return .{};
    }

    /// Advances growth timer by delta_seconds. Returns true once matured into a Happy Ghast.
    pub fn update(self: *GhastlingState, delta_seconds: f32) bool {
        if (self.is_baby and delta_seconds > 0.0) {
            self.growth_timer = @max(0.0, self.growth_timer - delta_seconds);
            if (self.growth_timer <= 0.0001) {
                self.is_baby = false;
                self.growth_timer = 0.0;
            }
        }
        return !self.is_baby;
    }

    /// Advances state by one standard game tick (0.05 seconds).
    pub fn tick(self: *GhastlingState) bool {
        return self.update(0.05);
    }

    /// Snowballs accelerate baby growth by 10% (120.0s); adults do not consume them.
    pub fn feedSnowball(self: *GhastlingState) bool {
        if (!self.is_baby) return false;
        self.growth_timer = @max(0.0, self.growth_timer - snowball_growth_reduction);
        if (self.growth_timer <= 0.0001) {
            self.is_baby = false;
            self.growth_timer = 0.0;
        }
        return true;
    }

    /// Checks and updates whether the ghastling should follow the player.
    pub fn shouldFollowPlayer(self: *GhastlingState, player_holds_snowball: bool) bool {
        self.follows_snowball_holder = self.is_baby and player_holds_snowball;
        return self.follows_snowball_holder;
    }
};

/// 16 dye colors supported for the Happy Ghast Harness.
pub const HarnessColor = enum(u8) {
    white = 0,
    orange = 1,
    magenta = 2,
    light_blue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    light_gray = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15,
};

/// Harness recipe: 3 Leather + 2 Glass + 1 Wool in any of 16 colors.
pub const Harness = struct {
    color: HarnessColor = .white,

    pub fn craft(leather: u8, glass: u8, wool: u8, color: HarnessColor) ?Harness {
        if (leather < harness_leather_required or glass < harness_glass_required or wool < harness_wool_required) {
            return null;
        }
        return .{ .color = color };
    }
};

/// Determines whether a player standing on or dismounting onto the dorsal top
/// allows walking on the Happy Ghast or stabilizes it.
pub fn canWalkOnHappyGhastTop(dismounted_on_roof: bool, ghast_has_riders: bool) bool {
    return dismounted_on_roof or ghast_has_riders;
}

/// 4-seat aerial mount (driver at seat 0 + 3 passengers at seats 1..3).
/// Requires equipping a Harness. Goggles fold down over the Happy Ghast's eyes
/// when a rider mounts. When players stand on the flat dorsal top (or dismount onto it),
/// the Happy Ghast freezes in mid-air as a stable floating construction platform.
pub const HappyGhastMount = struct {
    seats: [happy_ghast_seat_count]bool = .{ false, false, false, false },
    harness: ?Harness = null,
    is_stationary_platform: bool = false,
    player_on_roof: bool = false,

    pub fn init() HappyGhastMount {
        return .{};
    }

    /// Equips a crafted harness to the Happy Ghast mount.
    pub fn equipHarness(self: *HappyGhastMount, harness: Harness) void {
        self.harness = harness;
    }

    /// Unequips the harness if no riders are mounted.
    pub fn unequipHarness(self: *HappyGhastMount) ?Harness {
        if (self.riderCount() > 0) return null;
        const h = self.harness;
        self.harness = null;
        return h;
    }

    /// Mounts a rider into the first available seat (driver seat 0, then passenger seats 1-3).
    /// Requires an equipped harness.
    pub fn mountRider(self: *HappyGhastMount) ?u8 {
        if (self.harness == null) return null;
        for (&self.seats, 0..) |*occupied, i| {
            if (!occupied.*) {
                occupied.* = true;
                return @intCast(i);
            }
        }
        return null;
    }

    /// Dismounts a rider from the specified seat index.
    pub fn dismountRider(self: *HappyGhastMount, seat: u8) bool {
        if (seat >= happy_ghast_seat_count or !self.seats[seat]) return false;
        self.seats[seat] = false;
        if (self.riderCount() == 0 and !self.player_on_roof) {
            self.is_stationary_platform = false;
        }
        return true;
    }

    /// Dismounts a rider and places them directly on the flat dorsal top platform,
    /// freezing the mount as a floating construction platform.
    pub fn dismountRiderToRoof(self: *HappyGhastMount, seat: u8) bool {
        if (!self.dismountRider(seat)) return false;
        _ = self.updateDorsalPlatform(true);
        return true;
    }

    /// Returns the number of currently mounted riders (0 to 4).
    pub fn riderCount(self: HappyGhastMount) u8 {
        var count: u8 = 0;
        for (self.seats) |occupied| {
            if (occupied) count += 1;
        }
        return count;
    }

    /// Checks if a specific seat is occupied.
    pub fn isSeatOccupied(self: HappyGhastMount, seat: u8) bool {
        if (seat >= happy_ghast_seat_count) return false;
        return self.seats[seat];
    }

    /// Checks whether the driver seat (seat 0) is occupied.
    pub fn hasDriver(self: HappyGhastMount) bool {
        return self.seats[0];
    }

    /// Goggles fold down over the Happy Ghast's eyes when equipped with a Harness and a rider mounts.
    pub fn gogglesDown(self: HappyGhastMount) bool {
        return self.harness != null and self.riderCount() > 0;
    }

    /// Updates the dorsal top platform status. When players stand on the dorsal top (or dismount onto it),
    /// the Happy Ghast freezes in mid-air as a stable floating construction platform.
    pub fn updateDorsalPlatform(self: *HappyGhastMount, player_on_top: bool) bool {
        self.player_on_roof = player_on_top;
        self.is_stationary_platform = player_on_top or canWalkOnHappyGhastTop(false, self.riderCount() > 0);
        return self.is_stationary_platform;
    }
};

// ============================================================================
// Unit Tests (At least 14 tests covering all Milestone 305 features)
// ============================================================================

test "dried ghast begins frowning and does not progress when dry" {
    var block = DriedGhastState.init();
    try std.testing.expectEqual(HydrationStage.frowning, block.stage());
    _ = block.update(600.0);
    try std.testing.expectEqual(@as(f32, 0.0), block.hydration_progress);
    try std.testing.expectEqual(HydrationStage.frowning, block.stage());
}

test "waterlogged dried ghast progresses through neutral and smiling stages" {
    var block = DriedGhastState.init();
    block.is_waterlogged = true;
    _ = block.update(300.0);
    try std.testing.expectEqual(HydrationStage.neutral, block.stage());
    _ = block.update(300.0);
    try std.testing.expectEqual(HydrationStage.smiling, block.stage());
}

test "hydration completes after twenty minutes and spawns once" {
    var block = DriedGhastState.init();
    block.is_waterlogged = true;
    _ = block.update(1199.0);
    try std.testing.expectEqual(HydrationStage.smiling, block.stage());
    try std.testing.expect(block.update(1.0));
    try std.testing.expectEqual(HydrationStage.hydrated_spawn, block.stage());
    try std.testing.expect(block.ghastling_spawned);
    // Spawning should only happen once
    try std.testing.expect(!block.update(1.0));
}

test "dry dried ghast regresses slowly through stages" {
    var block = DriedGhastState.init();
    block.is_waterlogged = true;
    _ = block.update(600.0);
    try std.testing.expectEqual(HydrationStage.smiling, block.stage());
    block.is_waterlogged = false;
    _ = block.update(600.0); // 600 * 0.25 = 150 regression -> 450.0
    try std.testing.expectEqual(@as(f32, 450.0), block.hydration_progress);
    try std.testing.expectEqual(HydrationStage.neutral, block.stage());
}

test "dehydration clamps at zero" {
    var block = DriedGhastState.init();
    _ = block.update(100.0);
    try std.testing.expectEqual(@as(f32, 0.0), block.hydration_progress);
}

test "hydration can resume after rewetting" {
    var block = DriedGhastState.init();
    block.is_waterlogged = true;
    _ = block.update(500.0);
    try std.testing.expectEqual(@as(f32, 500.0), block.hydration_progress);

    block.is_waterlogged = false;
    _ = block.update(100.0); // 500 - 25 = 475.0
    try std.testing.expectEqual(@as(f32, 475.0), block.hydration_progress);

    block.is_waterlogged = true;
    _ = block.update(100.0); // 475 + 100 = 575.0
    try std.testing.expectEqual(@as(f32, 575.0), block.hydration_progress);
}

test "dried ghast crafting requires 8 bone blocks and 1 ghast tear" {
    try std.testing.expect(!canCraftDriedGhast(7, 1));
    try std.testing.expect(!canCraftDriedGhast(8, 0));
    try std.testing.expect(canCraftDriedGhast(8, 1));
    try std.testing.expect(canCraftDriedGhast(16, 2));

    try std.testing.expect(craftDriedGhast(7, 1) == null);
    const crafted = craftDriedGhast(8, 1);
    try std.testing.expect(crafted != null);
    try std.testing.expectEqual(HydrationStage.frowning, crafted.?.stage());
}

test "dried ghast tick helper advances hydration in game ticks" {
    var block = DriedGhastState.init();
    block.is_waterlogged = true;
    var i: usize = 0;
    while (i < 20) : (i += 1) { // 20 ticks = 1.0 second
        _ = block.tick();
    }
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), block.hydration_progress, 0.001);
}

test "ghastling follows players holding snowballs" {
    var baby = GhastlingState.init();
    try std.testing.expect(!baby.shouldFollowPlayer(false));
    try std.testing.expect(baby.shouldFollowPlayer(true));
}

test "feeding snowball removes ten percent of growth duration" {
    var baby = GhastlingState.init();
    try std.testing.expect(baby.feedSnowball());
    try std.testing.expectApproxEqAbs(@as(f32, 1080.0), baby.growth_timer, 0.001);
}

test "repeated snowballs mature ghastling into happy ghast" {
    var baby = GhastlingState.init();
    var i: usize = 0;
    while (i < 10) : (i += 1) _ = baby.feedSnowball();
    try std.testing.expect(!baby.is_baby);
    try std.testing.expectEqual(@as(f32, 0.0), baby.growth_timer);
}

test "ghastling matures with elapsed time and adults reject snowballs" {
    var baby = GhastlingState.init();
    try std.testing.expect(baby.update(ghastling_growth_duration));
    try std.testing.expect(!baby.is_baby);
    try std.testing.expect(!baby.feedSnowball());
    try std.testing.expect(!baby.shouldFollowPlayer(true));
}

test "ghastling tick advances growth timer" {
    var baby = GhastlingState.init();
    var i: usize = 0;
    while (i < 20) : (i += 1) { // 20 ticks = 1.0 second
        _ = baby.tick();
    }
    try std.testing.expectApproxEqAbs(@as(f32, ghastling_growth_duration - 1.0), baby.growth_timer, 0.001);
}

test "harness recipe checks ingredients" {
    try std.testing.expect(Harness.craft(2, 2, 1, .red) == null);
    try std.testing.expect(Harness.craft(3, 1, 1, .red) == null);
    try std.testing.expect(Harness.craft(3, 2, 0, .red) == null);
    try std.testing.expect(Harness.craft(3, 2, 1, .red) != null);
}

test "harness supports all sixteen colors" {
    const colors = [_]HarnessColor{
        .white, .orange, .magenta, .light_blue,
        .yellow, .lime, .pink, .gray,
        .light_gray, .cyan, .purple, .blue,
        .brown, .green, .red, .black,
    };
    for (colors, 0..) |color, i| {
        const crafted = Harness.craft(3, 2, 1, color).?;
        try std.testing.expectEqual(@as(u8, @intCast(i)), @intFromEnum(crafted.color));
    }
}

test "happy ghast requires harness and assigns four ordered seats" {
    var mount = HappyGhastMount.init();
    try std.testing.expect(mount.mountRider() == null);
    mount.equipHarness(Harness.craft(3, 2, 1, .white).?);
    try std.testing.expectEqual(@as(u8, 0), mount.mountRider().?);
    try std.testing.expect(mount.hasDriver());
    try std.testing.expectEqual(@as(u8, 1), mount.mountRider().?);
    try std.testing.expectEqual(@as(u8, 2), mount.mountRider().?);
    try std.testing.expectEqual(@as(u8, 3), mount.mountRider().?);
    try std.testing.expect(mount.mountRider() == null);
    try std.testing.expectEqual(@as(u8, 4), mount.riderCount());
    try std.testing.expect(mount.isSeatOccupied(0));
    try std.testing.expect(mount.isSeatOccupied(1));
    try std.testing.expect(mount.isSeatOccupied(2));
    try std.testing.expect(mount.isSeatOccupied(3));
}

test "vacated ghast seat is reused" {
    var mount = HappyGhastMount.init();
    mount.equipHarness(Harness.craft(3, 2, 1, .blue).?);
    _ = mount.mountRider(); // seat 0
    _ = mount.mountRider(); // seat 1
    try std.testing.expect(mount.dismountRider(0));
    try std.testing.expect(!mount.hasDriver());
    try std.testing.expectEqual(@as(u8, 0), mount.mountRider().?);
    try std.testing.expect(mount.hasDriver());
}

test "unequip harness rejects when riders mounted" {
    var mount = HappyGhastMount.init();
    mount.equipHarness(Harness.craft(3, 2, 1, .yellow).?);
    _ = mount.mountRider();
    try std.testing.expect(mount.unequipHarness() == null);
    _ = mount.dismountRider(0);
    const unequipped = mount.unequipHarness();
    try std.testing.expect(unequipped != null);
    try std.testing.expectEqual(HarnessColor.yellow, unequipped.?.color);
    try std.testing.expect(mount.harness == null);
}

test "goggles fold down only for mounted riders with harness" {
    var mount = HappyGhastMount.init();
    try std.testing.expect(!mount.gogglesDown());
    mount.equipHarness(Harness.craft(3, 2, 1, .green).?);
    try std.testing.expect(!mount.gogglesDown());
    _ = mount.mountRider();
    try std.testing.expect(mount.gogglesDown());
    _ = mount.dismountRider(0);
    try std.testing.expect(!mount.gogglesDown());
}

test "rider or dismount on roof freezes ghast as platform" {
    var mount = HappyGhastMount.init();
    mount.equipHarness(Harness.craft(3, 2, 1, .white).?);
    _ = mount.mountRider();
    try std.testing.expect(canWalkOnHappyGhastTop(false, true));
    try std.testing.expect(mount.updateDorsalPlatform(false));
    try std.testing.expect(mount.is_stationary_platform);
    try std.testing.expect(canWalkOnHappyGhastTop(true, false));
    try std.testing.expect(mount.updateDorsalPlatform(true));
}

test "dismount rider directly to roof maintains stationary platform" {
    var mount = HappyGhastMount.init();
    mount.equipHarness(Harness.craft(3, 2, 1, .red).?);
    _ = mount.mountRider();
    try std.testing.expect(mount.dismountRiderToRoof(0));
    try std.testing.expectEqual(@as(u8, 0), mount.riderCount());
    try std.testing.expect(mount.is_stationary_platform);
}

test "platform flag clears when no rider or player remains" {
    var mount = HappyGhastMount.init();
    mount.equipHarness(Harness.craft(3, 2, 1, .white).?);
    _ = mount.mountRider();
    _ = mount.updateDorsalPlatform(false);
    try std.testing.expect(mount.dismountRider(0));
    try std.testing.expect(!mount.is_stationary_platform);
}

test "seat offsets place driver at front and passengers around mount" {
    const drv = getSeatOffset(0).?;
    const left = getSeatOffset(1).?;
    const right = getSeatOffset(2).?;
    const rear = getSeatOffset(3).?;

    try std.testing.expect(drv.z > 0.0);
    try std.testing.expect(rear.z < 0.0);
    try std.testing.expect(left.x < 0.0);
    try std.testing.expect(right.x > 0.0);
    try std.testing.expect(getSeatOffset(4) == null);
}

test "computeWorldSeatPosition transforms seats by yaw" {
    // Ghast at (0, 100, 0) facing yaw 0 (+Z)
    const pos_north = computeWorldSeatPosition(0.0, 100.0, 0.0, 0.0, 0).?;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), pos_north.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 101.0), pos_north.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), pos_north.z, 0.001);

    // Ghast facing yaw pi/2 (+X)
    const pos_east = computeWorldSeatPosition(0.0, 100.0, 0.0, std.math.pi * 0.5, 0).?;
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), pos_east.x, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 101.0), pos_east.y, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), pos_east.z, 0.001);
}
