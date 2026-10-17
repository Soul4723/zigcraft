const std = @import("std");

/// The two adhesive materials that can form a flying-machine cell.
pub const FlyingMachineMaterial = enum { slime, honey };

/// A compact two-way flying-machine state.  The two halves are kept one block
/// apart so that the observer/piston hand-off is explicit and deterministic.
pub const FlyingMachineCell = struct {
    pub const canonical_core_block_count: u8 = 4;
    pub const observer_count: u8 = 2;
    pub const sticky_piston_count: u8 = 2;
    pub const adhesive_block_count: u8 = 2;
    pub const observer_delay_redstone_ticks: u8 = 1;

    material: FlyingMachineMaterial,
    front_position: i32 = 0,
    rear_position: i32 = -1,
    direction: i8 = 1,
    redstone_ticks: u64 = 0,
    pending_front_push: bool = false,
    pending_rear_pull: bool = false,
    halted: bool = false,
    steps_completed: u64 = 0,

    pub fn init(material: FlyingMachineMaterial) FlyingMachineCell {
        return .{ .material = material };
    }

    pub fn isCanonical(self: FlyingMachineCell) bool {
        return self.front_position - self.rear_position == 1 and
            self.direction != 0 and !self.halted;
    }

    /// The front piston push starts the one-redstone-tick observer hand-off.
    pub fn triggerFrontPush(self: *FlyingMachineCell) void {
        if (!self.halted) self.pending_front_push = true;
    }

    /// Advance one redstone tick.  A push observed on the prior tick causes
    /// the rear observer to fire and its sticky piston to pull the rear half.
    /// Returns true exactly when a complete block step occurred.
    pub fn tickRedstone(self: *FlyingMachineCell) bool {
        if (self.halted) return false;
        self.redstone_ticks += 1;
        if (self.pending_front_push) {
            self.pending_front_push = false;
            self.pending_rear_pull = true;
            return false;
        }
        if (self.pending_rear_pull) {
            self.pending_rear_pull = false;
            return self.advanceFlyingMachineStep();
        }
        return false;
    }

    /// Pull the rear half forward by one block and re-arm the cycle.
    pub fn advanceFlyingMachineStep(self: *FlyingMachineCell) bool {
        if (self.halted or self.direction == 0) return false;
        const delta: i32 = @intCast(self.direction);
        self.front_position += delta;
        self.rear_position += delta;
        self.steps_completed += 1;
        return true;
    }

    pub fn reverseDirection(self: *FlyingMachineCell) void {
        if (!self.halted) self.direction = -self.direction;
    }

    pub fn dock(self: *FlyingMachineCell, stopper_is_immovable: bool) bool {
        if (!canDockAtImmovableStopper(stopper_is_immovable)) return false;
        self.halted = true;
        self.pending_front_push = false;
        self.pending_rear_pull = false;
        return true;
    }
};

/// Free-function spelling is convenient for systems that own the cell state.
pub fn advanceFlyingMachineStep(cell: *FlyingMachineCell) bool {
    return cell.advanceFlyingMachineStep();
}

pub const FlyingMachineSpeed = struct {
    pub const redstone_ticks_per_step: u8 = 4;
    pub const game_ticks_per_step: u8 = 8;
    pub const seconds_per_step: f32 = 0.40;
    pub const blocks_per_second: f32 = 2.5;

    pub fn cruisingSpeedBlocksPerSec() f32 {
        return blocks_per_second;
    }

    pub fn stepsForRedstoneTicks(redstone_ticks: u64) u64 {
        return redstone_ticks / redstone_ticks_per_step;
    }

    pub fn blocksForGameTicks(game_ticks: u64) u64 {
        return game_ticks / game_ticks_per_step;
    }
};

pub const SlimeVsHoneyRiderTraction = struct {
    pub const honey_sink_blocks: f32 = 0.0625;

    pub fn slimeNeedsPassengerSeatOrWall(bounced: bool, has_passenger_seat_or_wall: bool) bool {
        return !bounced and !has_passenger_seat_or_wall;
    }

    pub fn honeyDragsEntitiesOnTop() bool {
        return true;
    }

    pub fn honeyEntitySinkBlocks() f32 {
        return honey_sink_blocks;
    }
};

pub const SplitChannelTileability = struct {
    pub fn areSlimeAndHoneyMutuallyNonAdhesive() bool {
        return true;
    }

    pub fn isSubModuleWithinPushLimit(block_count: u8) bool {
        return block_count <= 12;
    }
};

pub const DockingStopper = enum { obsidian, crying_obsidian, furnace, lodestone };

pub const ObsidianDockingStation = struct {
    pub fn canDockAtImmovableStopper(stopper_is_immovable: bool) bool {
        return stopper_is_immovable;
    }

    pub fn isSupportedStopper(stopper: DockingStopper) bool {
        _ = stopper;
        return true;
    }

    pub fn canReverseAtReturnObserver(note_block_or_trapdoor_in_front: bool) bool {
        return note_block_or_trapdoor_in_front;
    }

    pub fn reverseAtReturnObserver(cell: *FlyingMachineCell, note_block_or_trapdoor_in_front: bool) bool {
        if (!canReverseAtReturnObserver(note_block_or_trapdoor_in_front) or cell.halted) return false;
        cell.reverseDirection();
        return true;
    }
};

pub fn canDockAtImmovableStopper(stopper_is_immovable: bool) bool {
    return ObsidianDockingStation.canDockAtImmovableStopper(stopper_is_immovable);
}

pub fn honeyDragsEntitiesOnTop() bool {
    return SlimeVsHoneyRiderTraction.honeyDragsEntitiesOnTop();
}

pub fn cruisingSpeedBlocksPerSec() f32 {
    return FlyingMachineSpeed.cruisingSpeedBlocksPerSec();
}

pub fn areSlimeAndHoneyMutuallyNonAdhesive() bool {
    return SplitChannelTileability.areSlimeAndHoneyMutuallyNonAdhesive();
}

pub fn isSubModuleWithinPushLimit(block_count: u8) bool {
    return SplitChannelTileability.isSubModuleWithinPushLimit(block_count);
}

test "canonical cell contains two observers, pistons, and adhesive blocks" {
    try std.testing.expectEqual(@as(u8, 4), FlyingMachineCell.canonical_core_block_count);
    try std.testing.expectEqual(@as(u8, 2), FlyingMachineCell.observer_count);
    try std.testing.expectEqual(@as(u8, 2), FlyingMachineCell.sticky_piston_count);
    try std.testing.expectEqual(@as(u8, 2), FlyingMachineCell.adhesive_block_count);
}

test "cell starts as a canonical forward pair" {
    const cell = FlyingMachineCell.init(.slime);
    try std.testing.expect(cell.isCanonical());
    try std.testing.expectEqual(@as(i32, 0), cell.front_position);
    try std.testing.expectEqual(@as(i32, -1), cell.rear_position);
}

test "front push waits one redstone tick before rear pull" {
    var cell = FlyingMachineCell.init(.slime);
    cell.triggerFrontPush();
    try std.testing.expect(!cell.tickRedstone());
    try std.testing.expectEqual(@as(i32, 0), cell.front_position);
    try std.testing.expect(cell.tickRedstone());
    try std.testing.expectEqual(@as(i32, 1), cell.front_position);
    try std.testing.expectEqual(@as(i32, 0), cell.rear_position);
}

test "free step function advances both halves together" {
    var cell = FlyingMachineCell.init(.honey);
    try std.testing.expect(advanceFlyingMachineStep(&cell));
    try std.testing.expectEqual(@as(i32, 1), cell.front_position);
    try std.testing.expectEqual(@as(i32, 0), cell.rear_position);
    try std.testing.expectEqual(@as(u64, 1), cell.steps_completed);
}

test "four redstone ticks make one cruising step" {
    var cell = FlyingMachineCell.init(.slime);
    var i: usize = 0;
    while (i < FlyingMachineSpeed.redstone_ticks_per_step) : (i += 1) {
        cell.triggerFrontPush();
        _ = cell.tickRedstone();
        _ = cell.tickRedstone();
    }
    try std.testing.expectEqual(@as(u64, 4), cell.steps_completed);
}

test "cruising speed is two point five blocks per second" {
    try std.testing.expectEqual(@as(f32, 2.5), cruisingSpeedBlocksPerSec());
    try std.testing.expectEqual(@as(f32, 0.40), FlyingMachineSpeed.seconds_per_step);
}

test "speed conversion uses eight game ticks per block" {
    try std.testing.expectEqual(@as(u64, 3), FlyingMachineSpeed.blocksForGameTicks(24));
    try std.testing.expectEqual(@as(u64, 2), FlyingMachineSpeed.stepsForRedstoneTicks(8));
}

test "slime rider slips without a seat or wall unless bounced" {
    try std.testing.expect(SlimeVsHoneyRiderTraction.slimeNeedsPassengerSeatOrWall(false, false));
    try std.testing.expect(!SlimeVsHoneyRiderTraction.slimeNeedsPassengerSeatOrWall(false, true));
    try std.testing.expect(!SlimeVsHoneyRiderTraction.slimeNeedsPassengerSeatOrWall(true, false));
}

test "honey drags entities and sinks one sixteenth block" {
    try std.testing.expect(honeyDragsEntitiesOnTop());
    try std.testing.expectEqual(@as(f32, 0.0625), SlimeVsHoneyRiderTraction.honeyEntitySinkBlocks());
}

test "slime and honey split channels are non adhesive" {
    try std.testing.expect(areSlimeAndHoneyMutuallyNonAdhesive());
}

test "each split channel honors twelve block push budget" {
    try std.testing.expect(isSubModuleWithinPushLimit(12));
    try std.testing.expect(!isSubModuleWithinPushLimit(13));
    try std.testing.expect(isSubModuleWithinPushLimit(0));
}

test "supported docking stoppers are all immovable" {
    try std.testing.expect(ObsidianDockingStation.isSupportedStopper(.obsidian));
    try std.testing.expect(ObsidianDockingStation.isSupportedStopper(.crying_obsidian));
    try std.testing.expect(ObsidianDockingStation.isSupportedStopper(.furnace));
    try std.testing.expect(ObsidianDockingStation.isSupportedStopper(.lodestone));
}

test "immovable stopper docks without breaking the machine" {
    var cell = FlyingMachineCell.init(.honey);
    try std.testing.expect(canDockAtImmovableStopper(true));
    try std.testing.expect(cell.dock(true));
    try std.testing.expect(cell.halted);
    try std.testing.expect(!cell.advanceFlyingMachineStep());
}

test "movable stopper does not dock" {
    var cell = FlyingMachineCell.init(.slime);
    try std.testing.expect(!cell.dock(false));
    try std.testing.expect(!cell.halted);
}

test "note block or trapdoor reverses return observer direction" {
    var cell = FlyingMachineCell.init(.slime);
    try std.testing.expect(ObsidianDockingStation.reverseAtReturnObserver(&cell, true));
    try std.testing.expectEqual(@as(i8, -1), cell.direction);
    try std.testing.expect(!ObsidianDockingStation.reverseAtReturnObserver(&cell, false));
}

test "docked machine cannot reverse" {
    var cell = FlyingMachineCell.init(.honey);
    try std.testing.expect(cell.dock(true));
    try std.testing.expect(!ObsidianDockingStation.reverseAtReturnObserver(&cell, true));
    try std.testing.expectEqual(@as(i8, 1), cell.direction);
}

test "reverse direction advances toward the return station" {
    var cell = FlyingMachineCell.init(.slime);
    cell.reverseDirection();
    try std.testing.expect(cell.advanceFlyingMachineStep());
    try std.testing.expectEqual(@as(i32, -1), cell.front_position);
    try std.testing.expectEqual(@as(i32, -2), cell.rear_position);
}
