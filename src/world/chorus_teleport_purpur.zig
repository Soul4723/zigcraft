const std = @import("std");
const block_mod = @import("block.zig");
pub const BlockId = block_mod.BlockId;

pub const teleport_radius: i32 = 8;
pub const teleport_attempts: usize = 16;
pub const eat_ticks: u16 = 32;
pub const hunger_restore: f32 = 4.0;
pub const saturation_restore: f32 = 2.4;
pub const popped_fruit_smelt_ticks: u32 = 200;

pub const Position = struct { x: i32, y: i32, z: i32 };
pub const FoodState = struct { hunger: f32, saturation: f32 };
pub const TeleportEffects = struct {
    sound: SoundEffect = .chorus_teleport,
    particles: ParticleBurst = .purple_portal,
    particle_count: u8 = 24,
    fall_distance: f32 = 0,
};
pub const SoundEffect = enum { chorus_teleport };
pub const ParticleBurst = enum { purple_portal };

pub fn consumeChorusFruit(food: *FoodState) void {
    food.hunger = @min(20.0, food.hunger + hunger_restore);
    food.saturation = @min(food.hunger, food.saturation + saturation_restore);
}

pub const BlockLookup = *const fn (context: *const anyopaque, x: i32, y: i32, z: i32) BlockId;

pub fn isSafeLanding(block_at: BlockLookup, context: *const anyopaque, target: Position) bool {
    const feet = block_at(context, target.x, target.y, target.z);
    const head = block_at(context, target.x, target.y + 1, target.z);
    const ground = block_at(context, target.x, target.y - 1, target.z);
    return isPassable(feet) and isPassable(head) and ground.is_solid();
}

fn isPassable(block: BlockId) bool {
    return block == .air or block == .ladder or block == .torch or block == .wooden_door_open or block == .iron_door_open or block == .nether_portal or block == .end_portal or block == .chorus_plant or block == .chorus_flower;
}

pub fn chooseTeleportDestination(origin: Position, offsets: []const Position, block_at: BlockLookup, context: *const anyopaque) ?Position {
    var attempts: usize = 0;
    for (offsets) |offset| {
        if (attempts == teleport_attempts) break;
        attempts += 1;
        if (@abs(offset.x) > teleport_radius or @abs(offset.y) > teleport_radius or @abs(offset.z) > teleport_radius) continue;
        const candidate = Position{ .x = origin.x + offset.x, .y = origin.y + offset.y, .z = origin.z + offset.z };
        if (isSafeLanding(block_at, context, candidate)) return candidate;
    }
    return null;
}

pub fn smelt(input: Item) ?Item {
    return if (input == .chorus_fruit) .popped_chorus_fruit else null;
}
pub const Item = enum { chorus_fruit, popped_chorus_fruit, purpur_block, purpur_pillar, purpur_slab, purpur_stairs };
pub const RecipeShape = enum { square_2x2, vertical_column, horizontal_row, stair_pattern };
pub const Recipe = struct { ingredients: []const Item, output: Item, count: u8, shape: RecipeShape };
pub const purpur_block_recipe = Recipe{ .ingredients = &.{ .popped_chorus_fruit, .popped_chorus_fruit, .popped_chorus_fruit, .popped_chorus_fruit }, .output = .purpur_block, .count = 4, .shape = .square_2x2 };
pub const purpur_pillar_recipe = Recipe{ .ingredients = &.{ .purpur_slab, .purpur_slab }, .output = .purpur_pillar, .count = 1, .shape = .vertical_column };
pub const purpur_slab_recipe = Recipe{ .ingredients = &.{ .purpur_block, .purpur_block, .purpur_block }, .output = .purpur_slab, .count = 6, .shape = .horizontal_row };
pub const purpur_stairs_recipe = Recipe{ .ingredients = &.{ .purpur_block, .purpur_block, .purpur_block, .purpur_block, .purpur_block, .purpur_block }, .output = .purpur_stairs, .count = 4, .shape = .stair_pattern };

const TestWorld = struct { blocked: ?Position = null, water_at: ?Position = null, lava_at: ?Position = null };
fn lookup(ctx: *const anyopaque, x: i32, y: i32, z: i32) BlockId {
    const world: *const TestWorld = @ptrCast(@alignCast(ctx));
    const p = Position{ .x = x, .y = y, .z = z };
    if (world.blocked) |b| if (same(p, b)) return .stone;
    if (world.water_at) |b| if (same(p, b)) return .water;
    if (world.lava_at) |b| if (same(p, b)) return .lava;
    return if (y == 0) .stone else .air;
}
fn same(a: Position, b: Position) bool { return a.x == b.x and a.y == b.y and a.z == b.z; }
fn safeWorld() TestWorld { return .{}; }

test "chorus fruit restores food even at full hunger" { var food = FoodState{ .hunger = 20, .saturation = 5 }; consumeChorusFruit(&food); try std.testing.expectEqual(@as(f32, 20), food.hunger); try std.testing.expectEqual(@as(f32, 7.4), food.saturation); }
test "chorus fruit restores four hunger" { var f = FoodState{ .hunger = 8, .saturation = 2 }; consumeChorusFruit(&f); try std.testing.expectEqual(@as(f32, 12), f.hunger); }
test "chorus fruit saturation is 2.4" { var f = FoodState{ .hunger = 10, .saturation = 0 }; consumeChorusFruit(&f); try std.testing.expectApproxEqAbs(@as(f32, 2.4), f.saturation, 0.001); }
test "chorus food clamps hunger" { var f = FoodState{ .hunger = 19, .saturation = 20 }; consumeChorusFruit(&f); try std.testing.expectEqual(@as(f32, 20), f.hunger); }
test "eating takes 32 ticks" { try std.testing.expectEqual(@as(u16, 32), eat_ticks); }
test "teleport attempt cap is sixteen" { try std.testing.expectEqual(@as(usize, 16), teleport_attempts); }
test "teleport radius is eight" { try std.testing.expectEqual(@as(i32, 8), teleport_radius); }
test "safe landing requires solid ground and clearance" { var w = safeWorld(); try std.testing.expect(isSafeLanding(lookup, &w, .{ .x = 0, .y = 1, .z = 0 })); }
test "stone feet rejected" { var w = safeWorld(); w.blocked = .{ .x = 0, .y = 1, .z = 0 }; try std.testing.expect(!isSafeLanding(lookup, &w, .{ .x = 0, .y = 1, .z = 0 })); }
test "stone head rejected" { var w = safeWorld(); w.blocked = .{ .x = 0, .y = 2, .z = 0 }; try std.testing.expect(!isSafeLanding(lookup, &w, .{ .x = 0, .y = 1, .z = 0 })); }
test "water feet rejected" { var w = safeWorld(); w.water_at = .{ .x = 0, .y = 1, .z = 0 }; try std.testing.expect(!isSafeLanding(lookup, &w, .{ .x = 0, .y = 1, .z = 0 })); }
test "lava feet rejected" { var w = safeWorld(); w.lava_at = .{ .x = 0, .y = 1, .z = 0 }; try std.testing.expect(!isSafeLanding(lookup, &w, .{ .x = 0, .y = 1, .z = 0 })); }
test "water head rejected" { var w = safeWorld(); w.water_at = .{ .x = 0, .y = 2, .z = 0 }; try std.testing.expect(!isSafeLanding(lookup, &w, .{ .x = 0, .y = 1, .z = 0 })); }
test "lava head rejected" { var w = safeWorld(); w.lava_at = .{ .x = 0, .y = 2, .z = 0 }; try std.testing.expect(!isSafeLanding(lookup, &w, .{ .x = 0, .y = 1, .z = 0 })); }
test "missing ground rejected" { const w = safeWorld(); try std.testing.expect(!isSafeLanding(lookup, &w, .{ .x = 0, .y = 0, .z = 0 })); }
test "safe candidate chosen within cube" { const w = safeWorld(); const p = chooseTeleportDestination(.{ .x = 2, .y = 1, .z = -3 }, &.{.{ .x = 8, .y = 0, .z = -8 }}, lookup, &w).?; try std.testing.expect(same(p, .{ .x = 10, .y = 1, .z = -11 })); }
test "x offset beyond range rejected" { const w = safeWorld(); try std.testing.expect(chooseTeleportDestination(.{ .x = 0, .y = 1, .z = 0 }, &.{.{ .x = 9, .y = 0, .z = 0 }}, lookup, &w) == null); }
test "y offset beyond range rejected" { const w = safeWorld(); try std.testing.expect(chooseTeleportDestination(.{ .x = 0, .y = 1, .z = 0 }, &.{.{ .x = 0, .y = -9, .z = 0 }}, lookup, &w) == null); }
test "z offset beyond range rejected" { const w = safeWorld(); try std.testing.expect(chooseTeleportDestination(.{ .x = 0, .y = 1, .z = 0 }, &.{.{ .x = 0, .y = 0, .z = 9 }}, lookup, &w) == null); }
test "attempts stop after sixteen" { const w = safeWorld(); var offsets: [17]Position = @splat(.{ .x = 9, .y = 0, .z = 0 }); offsets[16] = .{ .x = 0, .y = 0, .z = 0 }; try std.testing.expect(chooseTeleportDestination(.{ .x = 0, .y = 1, .z = 0 }, &offsets, lookup, &w) == null); }
test "no safe destination preserves origin by returning null" { var w = safeWorld(); w.blocked = .{ .x = 0, .y = 1, .z = 0 }; try std.testing.expect(chooseTeleportDestination(.{ .x = 0, .y = 1, .z = 0 }, &.{.{ .x = 0, .y = 0, .z = 0 }}, lookup, &w) == null); }
test "teleport effects reset fall distance" { const e = TeleportEffects{}; try std.testing.expectEqual(@as(f32, 0), e.fall_distance); }
test "teleport effects include chime" { const e = TeleportEffects{}; try std.testing.expectEqual(SoundEffect.chorus_teleport, e.sound); }
test "teleport effects include purple particles" { const e = TeleportEffects{}; try std.testing.expectEqual(ParticleBurst.purple_portal, e.particles); }
test "teleport effects emit a burst" { const e = TeleportEffects{}; try std.testing.expect(e.particle_count > 0); }
test "furnace smelts chorus fruit" { try std.testing.expectEqual(Item.popped_chorus_fruit, smelt(.chorus_fruit).?); }
test "furnace rejects non chorus item" { try std.testing.expect(smelt(.purpur_block) == null); }
test "chorus smelting takes 200 ticks" { try std.testing.expectEqual(@as(u32, 200), popped_fruit_smelt_ticks); }
test "four popped fruits craft four blocks in 2x2" { try std.testing.expectEqual(@as(u8, 4), purpur_block_recipe.count); try std.testing.expectEqual(@as(usize, 4), purpur_block_recipe.ingredients.len); try std.testing.expectEqual(RecipeShape.square_2x2, purpur_block_recipe.shape); }
test "two vertical purpur slabs craft one pillar" { try std.testing.expectEqual(@as(u8, 1), purpur_pillar_recipe.count); try std.testing.expectEqual(@as(usize, 2), purpur_pillar_recipe.ingredients.len); try std.testing.expectEqual(RecipeShape.vertical_column, purpur_pillar_recipe.shape); }
test "three purpur blocks craft six slabs" { try std.testing.expectEqual(@as(u8, 6), purpur_slab_recipe.count); try std.testing.expectEqual(@as(usize, 3), purpur_slab_recipe.ingredients.len); try std.testing.expectEqual(RecipeShape.horizontal_row, purpur_slab_recipe.shape); }
test "six purpur blocks craft four stairs" { try std.testing.expectEqual(@as(u8, 4), purpur_stairs_recipe.count); try std.testing.expectEqual(@as(usize, 6), purpur_stairs_recipe.ingredients.len); try std.testing.expectEqual(RecipeShape.stair_pattern, purpur_stairs_recipe.shape); }
