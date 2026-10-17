const std = @import("std");

/// The vanilla lead recipe consumes four string and one slimeball and creates
/// two leads.  The recipe is intentionally kept independent of inventory IDs
/// so it can be used by both crafting screens and automated crafting.
pub const LeadCraftingRecipe = struct {
    pub const strings_required: u8 = 4;
    pub const slimeballs_required: u8 = 1;
    pub const leads_output: u8 = 2;

    pub fn craftLeads(strings: u8, slimeballs: u8) u8 {
        const batches = @min(strings / strings_required, slimeballs);
        return batches * leads_output;
    }
};

/// Returns the number of leads crafted from the supplied ingredients. Partial
/// recipes are ignored, and multiple complete recipes may be crafted at once.
pub fn craftLeads(strings: u8, slimeballs: u8) u8 {
    const batches = @min(strings / LeadCraftingRecipe.strings_required, slimeballs);
    return batches * LeadCraftingRecipe.leads_output;
}

pub const leash_slack_distance_m: f32 = 6.0;
pub const snap_distance_m: f32 = 10.0;
/// A unit spring constant makes the force easy for callers to apply as an
/// acceleration: every metre beyond the six-metre slack length adds one unit.
pub const leash_spring_constant: f32 = 1.0;

/// Computes the scalar spring pull toward the lead holder.  A leash is slack
/// through six metres, stretches elastically through ten metres, and has no
/// pull once it has snapped.
pub fn computeLeashPullForce(distance_m: f32) f32 {
    if (distance_m <= leash_slack_distance_m or distance_m > snap_distance_m) {
        return 0.0;
    }
    return (distance_m - leash_slack_distance_m) * leash_spring_constant;
}

pub fn shouldLeashSnap(distance_m: f32) bool {
    return distance_m > snap_distance_m;
}

/// Entity categories relevant to lead attachment.  `passive` and `neutral`
/// represent the ordinary attachable mob groups; special categories make the
/// exceptions explicit for callers that do not otherwise classify a mob.
pub const LeashTargetKind = enum {
    passive,
    neutral,
    iron_golem,
    snow_golem,
    dolphin,
    squid,
    hoglin,
    zoglin,
    slime,
    boat,
    chest_boat,
    villager,
    wandering_trader,
    bat,
    panda,
    hostile,
};

/// Returns whether a target can hold a lead. Villagers, wandering traders,
/// bats, pandas, and ordinary hostile mobs are deliberately excluded.
pub fn canAttachLeadToTarget(kind: LeashTargetKind) bool {
    return switch (kind) {
        .passive, .neutral, .iron_golem, .snow_golem, .dolphin, .squid,
        .hoglin, .zoglin, .slime, .boat, .chest_boat => true,
        .villager, .wandering_trader, .bat, .panda, .hostile => false,
    };
}

pub fn isLeashableEntity(kind: LeashTargetKind) bool {
    return canAttachLeadToTarget(kind);
}

/// A suspended lead target receives a small upward bounce. Ground and water
/// contact clear accumulated fall distance; while suspended, only downward
/// movement contributes to the accumulator.
pub const leash_bounce_velocity_mps: f32 = 0.42;

pub const LeashFallAccumulation = struct {
    fall_distance_m: f32 = 0.0,

    pub fn init() LeashFallAccumulation {
        return .{};
    }

    pub fn record(self: *LeashFallAccumulation, downward_distance_m: f32, touching_ground: bool, touching_water: bool) f32 {
        if (touching_ground or touching_water) {
            self.fall_distance_m = 0.0;
            return self.fall_distance_m;
        }
        self.fall_distance_m += @max(0.0, downward_distance_m);
        return self.fall_distance_m;
    }

    pub fn reset(self: *LeashFallAccumulation) void {
        self.fall_distance_m = 0.0;
    }
};

pub fn shouldAccumulateLeashFall(touching_ground: bool, touching_water: bool) bool {
    return !touching_ground and !touching_water;
}

pub fn computeLeashBounceVelocity(suspended: bool) f32 {
    return if (suspended) leash_bounce_velocity_mps else 0.0;
}

/// A right-click on any fence with at least one held lead creates one knot and
/// moves every currently held lead onto it.
pub fn tieLeadsToFencePost(held_leashed_count: u8, target_is_fence: bool) bool {
    return target_is_fence and held_leashed_count > 0;
}

/// Punching or right-clicking a knot returns one lead for each attached target.
pub fn releaseLeadsFromKnot(attached_leashed_count: u8, target_is_knot: bool) u8 {
    return if (target_is_knot) attached_leashed_count else 0;
}

pub fn canLeashBoat() bool {
    return true;
}

test "lead recipe produces two leads from four string and one slimeball" {
    try std.testing.expectEqual(@as(u8, 2), craftLeads(4, 1));
    try std.testing.expectEqual(@as(u8, 2), LeadCraftingRecipe.craftLeads(4, 1));
}

test "lead recipe supports multiple batches and ignores leftovers" {
    try std.testing.expectEqual(@as(u8, 6), craftLeads(13, 3));
    try std.testing.expectEqual(@as(u8, 4), craftLeads(8, 9));
}

test "lead recipe rejects incomplete ingredients" {
    try std.testing.expectEqual(@as(u8, 0), craftLeads(3, 1));
    try std.testing.expectEqual(@as(u8, 0), craftLeads(4, 0));
}

test "leash remains slack through six blocks" {
    try std.testing.expectEqual(@as(f32, 0.0), computeLeashPullForce(0.0));
    try std.testing.expectEqual(@as(f32, 0.0), computeLeashPullForce(6.0));
}

test "leash spring force grows linearly between slack and snap" {
    try std.testing.expectEqual(@as(f32, 0.5), computeLeashPullForce(6.5));
    try std.testing.expectEqual(@as(f32, 4.0), computeLeashPullForce(10.0));
}

test "leash snaps only beyond ten blocks" {
    try std.testing.expect(!shouldLeashSnap(10.0));
    try std.testing.expect(shouldLeashSnap(10.001));
    try std.testing.expectEqual(@as(f32, 0.0), computeLeashPullForce(10.1));
}

test "attachable passive special mobs and vehicles are accepted" {
    const allowed = [_]LeashTargetKind{ .passive, .neutral, .iron_golem, .snow_golem, .dolphin, .squid, .hoglin, .zoglin, .slime, .boat, .chest_boat };
    for (allowed) |kind| try std.testing.expect(canAttachLeadToTarget(kind));
}

test "villagers traders bats pandas and ordinary hostiles are rejected" {
    const rejected = [_]LeashTargetKind{ .villager, .wandering_trader, .bat, .panda, .hostile };
    for (rejected) |kind| try std.testing.expect(!isLeashableEntity(kind));
}

test "suspended leash target bounces vertically" {
    try std.testing.expectEqual(@as(f32, 0.42), computeLeashBounceVelocity(true));
    try std.testing.expectEqual(@as(f32, 0.0), computeLeashBounceVelocity(false));
}

test "fall distance accumulates while suspended" {
    var fall = LeashFallAccumulation.init();
    try std.testing.expectEqual(@as(f32, 1.5), fall.record(1.5, false, false));
    try std.testing.expectEqual(@as(f32, 2.0), fall.record(0.5, false, false));
    try std.testing.expect(shouldAccumulateLeashFall(false, false));
}

test "fall distance resets on ground or water contact" {
    var fall = LeashFallAccumulation.init();
    _ = fall.record(3.0, false, false);
    try std.testing.expectEqual(@as(f32, 0.0), fall.record(0.0, true, false));
    _ = fall.record(2.0, false, false);
    try std.testing.expectEqual(@as(f32, 0.0), fall.record(0.0, false, true));
    try std.testing.expect(!shouldAccumulateLeashFall(true, false));
    try std.testing.expect(!shouldAccumulateLeashFall(false, true));
}

test "fence knot ties all held leads only on a fence" {
    try std.testing.expect(tieLeadsToFencePost(1, true));
    try std.testing.expect(tieLeadsToFencePost(255, true));
    try std.testing.expect(!tieLeadsToFencePost(0, true));
    try std.testing.expect(!tieLeadsToFencePost(1, false));
}

test "knot release returns one lead per attached target" {
    try std.testing.expectEqual(@as(u8, 3), releaseLeadsFromKnot(3, true));
    try std.testing.expectEqual(@as(u8, 0), releaseLeadsFromKnot(3, false));
}

test "boats and chest boats can be leashed for towing" {
    try std.testing.expect(canLeashBoat());
    try std.testing.expect(canAttachLeadToTarget(.boat));
    try std.testing.expect(canAttachLeadToTarget(.chest_boat));
}
