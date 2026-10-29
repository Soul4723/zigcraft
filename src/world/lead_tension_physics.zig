const std = @import("std");

pub const rest_length_m: f32 = 3.0;
pub const snap_distance_m: f32 = 10.0;
pub const spring_scale: f32 = 0.06;
pub const max_leash_entities: usize = 64;

pub const Vec3 = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    z: f32 = 0.0,

    pub fn distance(a: Vec3, b: Vec3) f32 {
        const dx = a.x - b.x;
        const dy = a.y - b.y;
        const dz = a.z - b.z;
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }
};

pub const LeadCraftingRecipe = struct {
    pub const strings_required: u8 = 4;
    pub const slimeballs_required: u8 = 1;
    pub const leads_output: u8 = 2;

    pub fn craft(strings: u8, slimeballs: u8) u8 {
        return @min(strings / strings_required, slimeballs) * leads_output;
    }
};

pub const EntityKind = enum {
    passive_mob,
    horse,
    camel,
    allay,
    iron_golem,
    strider,
    boat,
    hostile_mob,
};

pub fn canBeLeashed(kind: EntityKind) bool {
    return kind != .hostile_mob;
}

pub const Holder = union(enum) {
    player,
    fence_knot: Vec3,
};

pub const LeashTarget = struct {
    entity_id: u32,
    kind: EntityKind,
    position: Vec3,
    holder: Holder = .player,
    attached: bool = true,
};

pub const TensionResult = struct {
    distance_m: f32,
    acceleration: Vec3 = .{},
    is_snapped: bool = false,
    dropped_leads: u8 = 0,
    drop_position: Vec3 = .{},
    snapping_sound: bool = false,
};

/// Computes the elastic acceleration of one tether. A snapped lead drops at
/// the entity's position and emits the snap sound exactly once to the caller.
pub fn resolveTension(holder: Vec3, entity: Vec3) TensionResult {
    const d = Vec3.distance(holder, entity);
    if (d > snap_distance_m) {
        return .{
            .distance_m = d,
            .is_snapped = true,
            .dropped_leads = 1,
            .drop_position = entity,
            .snapping_sound = true,
        };
    }
    if (d <= rest_length_m or d == 0.0) return .{ .distance_m = d };

    const magnitude = (d - rest_length_m) * spring_scale;
    return .{
        .distance_m = d,
        .acceleration = .{
            .x = ((holder.x - entity.x) / d) * magnitude,
            .y = ((holder.y - entity.y) / d) * magnitude,
            .z = ((holder.z - entity.z) / d) * magnitude,
        },
    };
}

pub const LeashKnot = struct {
    position: Vec3,
    attached_count: usize = 0,
};

pub const InteractionResult = struct {
    success: bool = false,
    leads_dropped: u8 = 0,
    knot_spawned: bool = false,
    knot_removed: bool = false,
};

/// Small deterministic leash registry. A game world owns entity positions and
/// applies returned accelerations/drops; this module owns tether state.
pub const LeashSystem = struct {
    targets: [max_leash_entities]LeashTarget = undefined,
    count: usize = 0,
    knot: ?LeashKnot = null,

    pub fn attachToPlayer(self: *LeashSystem, entity_id: u32, kind: EntityKind, position: Vec3, has_lead: bool) bool {
        if (!has_lead or !canBeLeashed(kind) or self.find(entity_id) != null) return false;
        for (self.targets[0..self.count], 0..) |*target, index| {
            if (target.attached) continue;
            self.targets[index] = .{ .entity_id = entity_id, .kind = kind, .position = position, .holder = .player };
            return true;
        }
        if (self.count == max_leash_entities) return false;
        self.targets[self.count] = .{ .entity_id = entity_id, .kind = kind, .position = position, .holder = .player };
        self.count += 1;
        return true;
    }

    pub fn tieToFence(self: *LeashSystem, fence_position: Vec3, clicked_fence: bool) InteractionResult {
        if (!clicked_fence or self.activeCount() == 0 or self.knot != null) return .{};
        var tied: usize = 0;
        for (self.targets[0..self.count]) |*target| {
            if (!target.attached) continue;
            target.holder = .{ .fence_knot = fence_position };
            tied += 1;
        }
        self.knot = .{ .position = fence_position, .attached_count = tied };
        return .{ .success = true, .knot_spawned = true };
    }

    pub fn breakKnot(self: *LeashSystem, clicked_knot: bool) InteractionResult {
        if (!clicked_knot or self.knot == null) return .{};
        const released: u8 = @intCast(self.knot.?.attached_count);
        for (self.targets[0..self.count]) |*target| {
            if (target.attached and target.holder == .fence_knot) target.attached = false;
        }
        self.knot = null;
        return .{ .success = true, .leads_dropped = released, .knot_removed = true };
    }

    pub fn updatePosition(self: *LeashSystem, entity_id: u32, position: Vec3) bool {
        const index = self.find(entity_id) orelse return false;
        self.targets[index].position = position;
        return true;
    }

    pub fn tick(self: *LeashSystem, entity_id: u32, player_position: Vec3) ?TensionResult {
        const index = self.find(entity_id) orelse return null;
        var target = &self.targets[index];
        if (!target.attached) return null;
        const anchor = switch (target.holder) {
            .player => player_position,
            .fence_knot => |position| position,
        };
        const result = resolveTension(anchor, target.position);
        if (result.is_snapped) {
            target.attached = false;
            if (self.knot) |*knot| {
                if (knot.attached_count > 0) knot.attached_count -= 1;
                if (knot.attached_count == 0) self.knot = null;
            }
        }
        return result;
    }

    fn find(self: *const LeashSystem, entity_id: u32) ?usize {
        for (self.targets[0..self.count], 0..) |target, index| {
            if (target.entity_id == entity_id and target.attached) return index;
        }
        return null;
    }

    fn activeCount(self: *const LeashSystem) usize {
        var active: usize = 0;
        for (self.targets[0..self.count]) |target| active += @intFromBool(target.attached);
        return active;
    }
};

test "lead recipe crafts two from four strings and one slimeball" {
    try std.testing.expectEqual(@as(u8, 2), LeadCraftingRecipe.craft(4, 1));
}
test "lead recipe returns zero without strings" {
    try std.testing.expectEqual(@as(u8, 0), LeadCraftingRecipe.craft(0, 1));
}
test "lead recipe returns zero without slimeball" {
    try std.testing.expectEqual(@as(u8, 0), LeadCraftingRecipe.craft(4, 0));
}
test "lead recipe ignores incomplete string batch" {
    try std.testing.expectEqual(@as(u8, 0), LeadCraftingRecipe.craft(3, 1));
}
test "lead recipe crafts multiple complete batches" {
    try std.testing.expectEqual(@as(u8, 4), LeadCraftingRecipe.craft(8, 2));
}
test "lead recipe limits output by slimeballs" {
    try std.testing.expectEqual(@as(u8, 2), LeadCraftingRecipe.craft(12, 1));
}
test "lead recipe ignores string and slimeball leftovers" {
    try std.testing.expectEqual(@as(u8, 4), LeadCraftingRecipe.craft(9, 2));
}
test "target types allow passive mobs" {
    try std.testing.expect(canBeLeashed(.passive_mob));
}
test "target types allow horses" {
    try std.testing.expect(canBeLeashed(.horse));
}
test "target types allow camels" {
    try std.testing.expect(canBeLeashed(.camel));
}
test "target types allow allays" {
    try std.testing.expect(canBeLeashed(.allay));
}
test "target types allow iron golems" {
    try std.testing.expect(canBeLeashed(.iron_golem));
}
test "target types allow striders" {
    try std.testing.expect(canBeLeashed(.strider));
}
test "target types allow boats" {
    try std.testing.expect(canBeLeashed(.boat));
}
test "hostile mobs cannot be leashed" {
    try std.testing.expect(!canBeLeashed(.hostile_mob));
}
test "leash is slack at the holder" {
    try std.testing.expectEqual(@as(f32, 0), resolveTension(.{}, .{}).acceleration.x);
}
test "leash is slack below three meters" {
    try std.testing.expectEqual(@as(f32, 0), resolveTension(.{}, .{ .x = 2.9 }).acceleration.x);
}
test "leash is slack at three meter rest length" {
    try std.testing.expectEqual(@as(f32, 0), resolveTension(.{}, .{ .x = 3 }).acceleration.x);
}
test "four meter lead pulls at 0.06 meters per second squared" {
    try std.testing.expectApproxEqAbs(@as(f32, -0.06), resolveTension(.{}, .{ .x = 4 }).acceleration.x, 0.00001);
}
test "spring pulls toward the holder on x axis" {
    try std.testing.expect(resolveTension(.{}, .{ .x = 5 }).acceleration.x < 0);
}
test "spring acceleration follows normalized diagonal" {
    const a = resolveTension(.{}, .{ .x = 4, .z = 3 }).acceleration;
    try std.testing.expectApproxEqAbs(@as(f32, -0.096), a.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.072), a.z, 0.0001);
}
test "spring has no vertical acceleration for level tether" {
    try std.testing.expectEqual(@as(f32, 0), resolveTension(.{}, .{ .x = 4 }).acceleration.y);
}
test "ten meter tether does not snap" {
    try std.testing.expect(!resolveTension(.{}, .{ .x = 10 }).is_snapped);
}
test "tether snaps above ten meters" {
    try std.testing.expect(resolveTension(.{}, .{ .x = 10.01 }).is_snapped);
}
test "snap drops one lead" {
    try std.testing.expectEqual(@as(u8, 1), resolveTension(.{}, .{ .x = 11 }).dropped_leads);
}
test "snap drop is at tethered entity location" {
    const r = resolveTension(.{}, .{ .x = 11, .y = 2, .z = 4 });
    try std.testing.expectEqual(@as(f32, 2), r.drop_position.y);
}
test "snap emits snapping sound event" {
    try std.testing.expect(resolveTension(.{}, .{ .x = 11 }).snapping_sound);
}
test "distance uses three dimensional Euclidean length" {
    try std.testing.expectApproxEqAbs(@as(f32, 5), Vec3.distance(.{}, .{ .x = 3, .y = 4 }), 0.0001);
}
test "right click attaches compatible mob when lead held" {
    var s = LeashSystem{};
    try std.testing.expect(s.attachToPlayer(1, .passive_mob, .{}, true));
}
test "right click without a lead does not attach" {
    var s = LeashSystem{};
    try std.testing.expect(!s.attachToPlayer(1, .horse, .{}, false));
}
test "rejected target cannot consume a lead" {
    var s = LeashSystem{};
    try std.testing.expect(!s.attachToPlayer(1, .hostile_mob, .{}, true));
}
test "same entity cannot receive duplicate leash attachments" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(1, .horse, .{}, true);
    try std.testing.expect(!s.attachToPlayer(1, .horse, .{}, true));
}
test "fence click creates a knot at fence coordinates" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(1, .horse, .{}, true);
    const r = s.tieToFence(.{ .x = 5, .y = 2, .z = -1 }, true);
    try std.testing.expect(r.knot_spawned);
    try std.testing.expectEqual(@as(f32, 5), s.knot.?.position.x);
}
test "non fence click does not spawn a knot" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(1, .horse, .{}, true);
    try std.testing.expect(!s.tieToFence(.{}, false).success);
}
test "empty fence interaction does not spawn a knot" {
    var s = LeashSystem{};
    try std.testing.expect(!s.tieToFence(.{}, true).success);
}
test "fence knot holds all attached caravan entities" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(1, .horse, .{}, true);
    _ = s.attachToPlayer(2, .camel, .{}, true);
    const r = s.tieToFence(.{}, true);
    try std.testing.expect(r.knot_spawned);
    try std.testing.expectEqual(@as(usize, 2), s.knot.?.attached_count);
}
test "knot click removes knot and drops one lead per entity" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(1, .horse, .{}, true);
    _ = s.attachToPlayer(2, .boat, .{}, true);
    _ = s.tieToFence(.{}, true);
    const r = s.breakKnot(true);
    try std.testing.expect(r.knot_removed);
    try std.testing.expectEqual(@as(u8, 2), r.leads_dropped);
    try std.testing.expect(s.knot == null);
}
test "non knot click leaves fence knot intact" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(1, .horse, .{}, true);
    _ = s.tieToFence(.{}, true);
    try std.testing.expect(!s.breakKnot(false).success);
    try std.testing.expect(s.knot != null);
}
test "breaking knot frees attached entities" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(1, .horse, .{}, true);
    _ = s.tieToFence(.{}, true);
    _ = s.breakKnot(true);
    try std.testing.expect(s.tick(1, .{}) == null);
}
test "snapped target is excluded when remaining leads tie to a knot" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(1, .horse, .{ .x = 11 }, true);
    _ = s.attachToPlayer(2, .camel, .{}, true);
    _ = s.tick(1, .{});
    _ = s.tieToFence(.{}, true);
    try std.testing.expectEqual(@as(usize, 1), s.knot.?.attached_count);
}
test "boat can attach for towing" {
    var s = LeashSystem{};
    try std.testing.expect(s.attachToPlayer(42, .boat, .{ .x = 5 }, true));
}
test "boat receives spring acceleration while being towed" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(42, .boat, .{ .x = 5 }, true);
    const r = s.tick(42, .{}).?;
    try std.testing.expect(r.acceleration.x < 0);
}
test "multiple leads attach independent caravan targets" {
    var s = LeashSystem{};
    try std.testing.expect(s.attachToPlayer(1, .passive_mob, .{}, true));
    try std.testing.expect(s.attachToPlayer(2, .camel, .{}, true));
    try std.testing.expect(s.attachToPlayer(3, .horse, .{}, true));
    try std.testing.expectEqual(@as(usize, 3), s.count);
}
test "tension tick snaps only the distant attached target" {
    var s = LeashSystem{};
    _ = s.attachToPlayer(1, .horse, .{ .x = 11 }, true);
    _ = s.attachToPlayer(2, .camel, .{ .x = 2 }, true);
    try std.testing.expect(s.tick(1, .{}).?.is_snapped);
    try std.testing.expect(!s.tick(2, .{}).?.is_snapped);
}
