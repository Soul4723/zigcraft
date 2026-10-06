const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const camera_mod = @import("camera.zig");
const math = @import("math.zig");
const chunk_manager_mod = @import("chunk_manager.zig");
const pick_mod = @import("pick.zig");
const sky_mod = @import("sky.zig");
const player_mod = @import("player.zig");
const block_mod = @import("world/block.zig");
const redstone_mod = @import("world/redstone.zig");
const ui_mod = @import("renderer/ui.zig");
const audio_mod = @import("audio/audio.zig");
const texture_mod = @import("renderer/texture.zig");
const entity_mod = @import("entity.zig");
const inventory_mod = @import("inventory.zig");
const highlight_mod = @import("renderer/highlight.zig");
const particles_mod = @import("renderer/particles.zig");

const window_width = 1280;
const window_height = 720;
const window_title = "Zigcraft";

var pick_manager: ?*chunk_manager_mod.ChunkManager = null;

fn pickSolid(x: i32, y: i32, z: i32) bool {
    return pick_manager.?.isSolidWorld(x, y, z);
}

fn pickLadder(x: i32, y: i32, z: i32) bool {
    const mgr = pick_manager orelse return false;
    return mgr.getBlockWorld(x, y, z).is_ladder();
}

/// Number of blocks a fresh wooden pickaxe can mine.
fn defaultPickDurability() i32 {
    return @intCast(inventory_mod.ItemType.wooden_pickaxe.maxDurability());
}

/// True when the held item meets the block's required tool tier.
fn blkTierOk(held: inventory_mod.ItemType, block: block_mod.BlockId) bool {
    const need = block_mod.requiredTier(block);
    if (need == .hand) return true;
    return held == .wooden_pickaxe or held == .iron_pickaxe;
}

fn getFootstepSound(block: block_mod.BlockId) audio_mod.synth.SoundType {
    return switch (block) {
        .grass => .step_grass,
        .stone => .step_stone,
        .wood => .step_wood,
        .dirt => .step_dirt,
        .cobblestone => .step_stone,
        .coal_ore => .step_stone,
        .iron_ore => .step_stone,
        .sand => .step_dirt,
        .glass => .step_stone,
        .sandstone => .step_stone,
        .brick => .step_stone,
        .snow => .step_snow,
        .wool => .step_wool,
        else => .step_grass,
    };
}

pub fn main() !void {
    std.debug.print("zigcraft v0.0.8\n", .{});

    if (c.glfwInit() == c.GLFW_FALSE) {
        std.debug.print("failed to initialize GLFW\n", .{});
        return error.GlfwInitFailed;
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const window = c.glfwCreateWindow(
        window_width,
        window_height,
        window_title,
        null,
        null,
    ) orelse {
        std.debug.print("failed to create GLFW window\n", .{});
        return error.WindowCreationFailed;
    };
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    const gl_version = c.glGetString(c.GL_VERSION);
    if (gl_version != null) {
        std.debug.print("OpenGL {s}\n", .{gl_version});
    }

    c.glEnable(c.GL_DEPTH_TEST);
    c.glClearColor(0.05, 0.05, 0.1, 1.0);

    // Hide and capture cursor for first-person camera control
    c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);

    // Initial player position: center of world
    var player = player_mod.Player.init(24, 20, 24);
    var cam = camera_mod.Camera.init();
    cam.yaw = -std.math.pi / 2.0 - 0.35;
    cam.pitch = -0.3;
    cam.position = player.eyePos();

    // World chunk manager: radius 3 (7x7 = 49 chunks streaming around player)
    const init_cx = @as(i32, @intFromFloat(@floor(player.pos.x / 16.0)));
    const init_cz = @as(i32, @intFromFloat(@floor(player.pos.z / 16.0)));
    var manager = try chunk_manager_mod.ChunkManager.init(std.heap.page_allocator, 3, init_cx, init_cz, 1337, "saves");
    defer manager.deinit();
    pick_manager = &manager;

    var sky = try sky_mod.SkyRenderer.init(std.heap.page_allocator);
    defer sky.deinit();

    var ui = try ui_mod.UIRenderer.init(std.heap.page_allocator);
    defer ui.deinit();

    var highlight = try highlight_mod.HighlightRenderer.init(std.heap.page_allocator);
    defer highlight.deinit();

    var particles = try particles_mod.ParticleSystem.init(std.heap.page_allocator);
    defer particles.deinit();

    var audio = audio_mod.AudioSystem.init();
    defer audio.deinit();

    const atlas_texture = texture_mod.createBlockTexture();
    defer c.glDeleteTextures(1, &atlas_texture);
    var mob_manager = try entity_mod.mob_manager.MobManager.init(std.heap.page_allocator, atlas_texture);
    defer mob_manager.deinit();

    // Player Inventory & Crafting state
    var inventory = inventory_mod.Inventory.init();
    var cursor_stack = inventory_mod.ItemStack{};
    var inventory_open = false;
    var e_key_down = false;
    var selected_slot: usize = 0;
    var mine_target_valid = false;
    var mine_key: i64 = 0;
    var mine_progress: f32 = 0.0;
    var mine_need: f32 = 1.0;
    var tool_wear: [6]u16 = [_]u16{0} ** 6;

    // Timing & Day/Night cycle
    var last_time = c.glfwGetTime();
    var frame_count: u64 = 0;
    var hud_frames: u64 = 0;
    var hud_time: f32 = 0;
    var left_down = false;
    var right_down = false;
    var mob_hit_cooldown: f32 = 0.0;
    var bed_cooldown: f32 = 0.0;
    var flint_cooldown: f32 = 0.0;
    var throw_cooldown: f32 = 0.0;
    var wolf_bite_cooldown: f32 = 0.0;
    const Fuse = struct { x: i32, y: i32, z: i32, t: f32 };
    var fuses: [16]Fuse = undefined;
    var fuse_count: usize = 0;
    const Torch = struct { x: i32, y: i32, z: i32 };
    var torches: [32]Torch = undefined;
    var torch_count: usize = 0;
    var torch_puff_timer: f32 = 0.0;
    const Thrown = struct { pos: math.Vec3, vel: math.Vec3, life: f32 };
    var thrown: [8]Thrown = undefined;
    var thrown_count: usize = 0;
    const FurnaceJob = struct { x: i32, y: i32, z: i32, t: f32, fuel: u8, input: inventory_mod.ItemType };
    var furnaces: [16]FurnaceJob = undefined;
    var furnace_count: usize = 0;
    const Chest = struct { x: i32, y: i32, z: i32, items: [4]inventory_mod.ItemStack };
    var chests: [16]Chest = undefined;
    var chest_count: usize = 0;
    var sprouts: [16]struct { x: i32, y: i32, z: i32, t: f32 } = undefined;
    var sprout_count: usize = 0;
    const Plate = struct { x: i32, y: i32, z: i32, down: bool };
    var plates: [64]Plate = undefined;
    var plate_count: usize = 0;
    const Wire = struct { x: i32, y: i32, z: i32, powered: bool };
    var wires: [256]Wire = undefined;
    var wire_count: usize = 0;
    const Repeater = struct { x: i32, y: i32, z: i32, powered: bool, timer: f32, stage: u2 };
    var repeaters: [64]Repeater = undefined;
    var repeater_count: usize = 0;
    var known_stage_chunks: [64]struct { x: i32, z: i32 } = undefined;
    var known_stage_count: usize = 0;
    const Lamp = struct { x: i32, y: i32, z: i32, lit: bool };
    var lamps: [64]Lamp = undefined;
    var lamp_count: usize = 0;
    const RedTorch = struct { x: i32, y: i32, z: i32, lit: bool, flips: [8]f32, flip_count: u8, burnout: f32 };
    var red_torches: [64]RedTorch = undefined;
    var red_torch_count: usize = 0;
    var rs_cap_warned_plate = false;
    var rs_cap_warned_wire = false;
    var rs_cap_warned_rep = false;
    var rs_cap_warned_lamp = false;
    var rs_cap_warned_torch = false;
    const FallSand = struct { x: i32, y: i32, z: i32, t: f32, dist: i32 };
    var fallings: [32]FallSand = undefined;
    var falling_count: usize = 0;
    var sand_scan: u8 = 0;
    var world_time: f32 = 45.0; // Start at morning daylight
    var last_step_dist: f32 = 0.0;

    // Mouse tracking
    var last_x: f64 = @floatFromInt(window_width / 2);
    var last_y: f64 = @floatFromInt(window_height / 2);
    var first_mouse = true;

    std.debug.print("ready. Dynamic chunks + AO + Day/Night Cycle + Audio. WASD move, mouse look, ESC close.\n", .{});

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        // Delta time
        const current_time = c.glfwGetTime();
        const dt: f32 = @floatCast(current_time - last_time);
        last_time = current_time;

        // Advance 2-minute day/night cycle
        world_time += dt * 0.05;

        // Toggle inventory screen with 'E' key (edge triggered)
        const e_key = c.glfwGetKey(window, c.GLFW_KEY_E) == c.GLFW_PRESS;
        if (e_key and !e_key_down) {
            inventory_open = !inventory_open;
            if (inventory_open) {
                c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_NORMAL);
            } else {
                c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
                first_mouse = true;
                // If cursor item was held when closing, return to inventory
                if (!cursor_stack.isEmpty()) {
                    _ = inventory.addItem(cursor_stack.item, cursor_stack.count);
                    cursor_stack.clear();
                }
            }
        }
        e_key_down = e_key;

        // Hotbar selection keys 1 through 6
        if (c.glfwGetKey(window, c.GLFW_KEY_1) == c.GLFW_PRESS) selected_slot = 0;
        if (c.glfwGetKey(window, c.GLFW_KEY_2) == c.GLFW_PRESS) selected_slot = 1;
        if (c.glfwGetKey(window, c.GLFW_KEY_3) == c.GLFW_PRESS) selected_slot = 2;
        if (c.glfwGetKey(window, c.GLFW_KEY_4) == c.GLFW_PRESS) selected_slot = 3;
        if (c.glfwGetKey(window, c.GLFW_KEY_5) == c.GLFW_PRESS) selected_slot = 4;
        if (c.glfwGetKey(window, c.GLFW_KEY_6) == c.GLFW_PRESS) selected_slot = 5;

        // Keyboard input: poll each movement key and forward to camera.
        const fwd = cam.front();
        const flat_f = math.Vec3.init(fwd.x, 0, fwd.z);
        const flat_len = math.Vec3.len(flat_f);
        const walk_f = if (flat_len > 0.001) flat_f.scale(1.0 / flat_len) else math.Vec3.init(0, 0, -1);
        const walk_r = math.Vec3.normalize(math.Vec3.cross(walk_f, math.Vec3.init(0, 1, 0)));
        const walk_speed = 6.0;
        var wish = math.Vec3.init(0, 0, 0);
        if (c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) wish = math.Vec3.add(wish, walk_f);
        if (c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS) wish = math.Vec3.sub(wish, walk_f);
        if (c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS) wish = math.Vec3.add(wish, walk_r);
        if (c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS) wish = math.Vec3.sub(wish, walk_r);
        const wish_len = math.Vec3.len(wish);
        const norm_wish = if (!inventory_open and wish_len > 0.001) wish.scale(1.0 / wish_len) else math.Vec3.init(0, 0, 0);
        const jump = !inventory_open and (c.glfwGetKey(window, c.GLFW_KEY_SPACE) == c.GLFW_PRESS);
        player.tickLadder(&pickSolid, &pickLadder, norm_wish.x * walk_speed * dt, norm_wish.z * walk_speed * dt, jump, dt);
        player.tickVitals(dt);
        if (player.pos.y < -30.0) {
            // Fell out of world: damage through vitals path
            player.health = @max(0.0, player.health - 20.0 * dt);
        }
        if (player.isDead()) {
            audio.play(.hurt, 0.8);
            std.debug.print("you died; respawning\n", .{});
            player.respawn(player.spawn_point.x, player.spawn_point.y, player.spawn_point.z);
        }
        cam.position = player.eyePos();

        // Sync redstone caches from world state so TNT/mining/streaming/persistence
        // edits (which bypass placement tracking) are still simulated. Power flags
        // are re-derived from block ids; only repeater delay timers persist in session.
        // Throttled to every 4th frame: ~50k block reads/frame average.
        if (frame_count % 4 == 0) {
            {
                var snap: [64][4]i32 = undefined;
                var sn: usize = 0;
                for (repeaters[0..repeater_count]) |rep| {
                    if (sn >= snap.len) break;
                    snap[sn] = .{ rep.x, rep.y, rep.z, rep.stage };
                    sn += 1;
                }
                chunk_manager_mod.ChunkManager.setStageSnapshot(snap[0..sn]);
                var bsnap: [64][4]i32 = undefined;
                var bn: usize = 0;
                for (red_torches[0..red_torch_count]) |bt| {
                    if (bn >= bsnap.len) break;
                    if (bt.burnout > 0.0) {
                        bsnap[bn] = .{ bt.x, bt.y, bt.z, @intFromFloat(bt.burnout) };
                        bn += 1;
                    }
                }
                chunk_manager_mod.ChunkManager.setBurnoutSnapshot(bsnap[0..bn]);
            }
            // Apply persisted repeater stages for newly seen chunks
            var stage_iter = manager.chunks.iterator();
            while (stage_iter.next()) |entry| {
                const scx = entry.key_ptr.x;
                const scz = entry.key_ptr.z;
                var known = false;
                for (known_stage_chunks[0..known_stage_count]) |kc| {
                    if (kc.x == scx and kc.z == scz) {
                        known = true;
                        break;
                    }
                }
                if (!known) {
                    if (known_stage_count < known_stage_chunks.len) {
                        known_stage_chunks[known_stage_count] = .{ .x = scx, .z = scz };
                        known_stage_count += 1;
                    }
                    var burned = [_][4]i32{.{ 0, 0, 0, 0 }} ** 64;
                    const nburned = manager.loadBurnout(scx, scz, &burned);
                    var bi: usize = 0;
                    while (bi < nburned) : (bi += 1) {
                        for (red_torches[0..red_torch_count]) |*rt| {
                            if (rt.x == burned[bi][0] and rt.y == burned[bi][1] and rt.z == burned[bi][2]) {
                                rt.burnout = @floatFromInt(burned[bi][3]);
                                break;
                            }
                        }
                    }
                    var staged = [_][4]i32{.{ 0, 0, 0, 0 }} ** 64;
                    const nstaged = manager.loadStages(scx, scz, &staged);
                    var si: usize = 0;
                    while (si < nstaged) : (si += 1) {
                        for (repeaters[0..repeater_count]) |*rep| {
                            if (rep.x == staged[si][0] and rep.y == staged[si][1] and rep.z == staged[si][2]) {
                                rep.stage = @intCast(staged[si][3] & 3);
                                break;
                            }
                        }
                    }
                }
            }
            var rs_iter = manager.chunks.iterator();
            while (rs_iter.next()) |entry| {
                const rcx = entry.key_ptr.x;
                const rcz = entry.key_ptr.z;
                const rch = &entry.value_ptr.chunk;
                var ry: usize = 0;
                while (ry < 16) : (ry += 1) {
                    var rz: usize = 0;
                    while (rz < 16) : (rz += 1) {
                        var rx: usize = 0;
                        while (rx < 16) : (rx += 1) {
                            const rb = rch.blocks[ry][rz][rx];
                            switch (rb) {
                                .pressure_plate_up, .pressure_plate_down, .redstone_wire_off, .redstone_wire_on, .repeater_off, .repeater_on, .redstone_lamp_off, .redstone_lamp_on, .redstone_torch_off, .redstone_torch_on => {},
                                else => continue,
                            }
                            const wx: i32 = rcx * 16 + @as(i32, @intCast(rx));
                            const wy: i32 = @as(i32, @intCast(ry));
                            const wz: i32 = rcz * 16 + @as(i32, @intCast(rz));
                            switch (rb) {
                                .pressure_plate_up, .pressure_plate_down => {
                                    var found = false;
                                    for (plates[0..plate_count]) |pp| {
                                        if (pp.x == wx and pp.y == wy and pp.z == wz) {
                                            found = true;
                                            break;
                                        }
                                    }
                                    if (!found and plate_count < plates.len) {
                                        plates[plate_count] = .{ .x = wx, .y = wy, .z = wz, .down = (rb == .pressure_plate_down) };
                                        plate_count += 1;
                                    } else if (!found and !rs_cap_warned_plate) {
                                        rs_cap_warned_plate = true;
                                        std.debug.print("redstone cap: plates full ({d}), some plates unsimulated\n", .{plates.len});
                                    }
                                },
                                .redstone_wire_off, .redstone_wire_on => {
                                    var found = false;
                                    for (wires[0..wire_count]) |ww| {
                                        if (ww.x == wx and ww.y == wy and ww.z == wz) {
                                            found = true;
                                            break;
                                        }
                                    }
                                    if (!found and wire_count < wires.len) {
                                        wires[wire_count] = .{ .x = wx, .y = wy, .z = wz, .powered = (rb == .redstone_wire_on) };
                                        wire_count += 1;
                                    } else if (!found and !rs_cap_warned_wire) {
                                        rs_cap_warned_wire = true;
                                        std.debug.print("redstone cap: wires full ({d}), some wires unsimulated\n", .{wires.len});
                                    }
                                },
                                .repeater_off, .repeater_on => {
                                    var found = false;
                                    for (repeaters[0..repeater_count]) |*rep| {
                                        if (rep.x == wx and rep.y == wy and rep.z == wz) {
                                            // Do not clobber in-flight delay: only register
                                            // repeaters already settled to their block state.
                                            if ((rb == .repeater_on) == rep.powered) rep.timer = 0.0;
                                            found = true;
                                            break;
                                        }
                                    }
                                    if (!found and repeater_count < repeaters.len) {
                                        repeaters[repeater_count] = .{ .x = wx, .y = wy, .z = wz, .powered = (rb == .repeater_on), .timer = 0.0, .stage = 0 };
                                        repeater_count += 1;
                                    } else if (!found and !rs_cap_warned_rep) {
                                        rs_cap_warned_rep = true;
                                        std.debug.print("redstone cap: repeaters full ({d})\n", .{repeaters.len});
                                    }
                                },
                                .redstone_lamp_off, .redstone_lamp_on => {
                                    var found = false;
                                    for (lamps[0..lamp_count]) |*la| {
                                        if (la.x == wx and la.y == wy and la.z == wz) {
                                            la.lit = (rb == .redstone_lamp_on);
                                            found = true;
                                            break;
                                        }
                                    }
                                    if (!found and lamp_count < lamps.len) {
                                        lamps[lamp_count] = .{ .x = wx, .y = wy, .z = wz, .lit = (rb == .redstone_lamp_on) };
                                        lamp_count += 1;
                                    } else if (!found and !rs_cap_warned_lamp) {
                                        rs_cap_warned_lamp = true;
                                        std.debug.print("redstone cap: lamps full ({d})\n", .{lamps.len});
                                    }
                                },
                                .redstone_torch_off, .redstone_torch_on => {
                                    var found = false;
                                    for (red_torches[0..red_torch_count]) |*rt| {
                                        if (rt.x == wx and rt.y == wy and rt.z == wz) {
                                            rt.lit = (rb == .redstone_torch_on);
                                            found = true;
                                            break;
                                        }
                                    }
                                    if (!found and red_torch_count < red_torches.len) {
                                        red_torches[red_torch_count] = .{ .x = wx, .y = wy, .z = wz, .lit = (rb == .redstone_torch_on), .flips = [_]f32{-100} ** 8, .flip_count = 0, .burnout = 0.0 };
                                        red_torch_count += 1;
                                    } else if (!found and !rs_cap_warned_torch) {
                                        rs_cap_warned_torch = true;
                                        std.debug.print("redstone cap: torches full ({d})\n", .{red_torches.len});
                                    }
                                },
                                else => {},
                            }
                        }
                    }
                }
            }
        }

        // Pressure plate trigger logic: test player and mob positions on active plates
        {
            var pi: usize = 0;
            while (pi < plate_count) {
                const pl = &plates[pi];
                const blk = manager.getBlockWorld(pl.x, pl.y, pl.z);
                if (blk != .pressure_plate_up and blk != .pressure_plate_down) {
                    plates[pi] = plates[plate_count - 1];
                    plate_count -= 1;
                    continue;
                }

                // Check if player is standing within plate bounds:
                // plate is at (pl.x, pl.y, pl.z), foot pos (player.pos.x, player.pos.y, player.pos.z)
                var stepped = false;
                const fx = player.pos.x;
                const fy = player.pos.y;
                const fz = player.pos.z;
                if (fx >= @as(f32, @floatFromInt(pl.x)) - 0.2 and fx <= @as(f32, @floatFromInt(pl.x)) + 1.2 and
                    fz >= @as(f32, @floatFromInt(pl.z)) - 0.2 and fz <= @as(f32, @floatFromInt(pl.z)) + 1.2 and
                    fy >= @as(f32, @floatFromInt(pl.y)) - 0.1 and fy <= @as(f32, @floatFromInt(pl.y)) + 0.6)
                {
                    stepped = true;
                }

                // Also check any mob standing on it
                if (!stepped) {
                    for (mob_manager.mobs.items) |m| {
                        if (m.pos.x >= @as(f32, @floatFromInt(pl.x)) - 0.3 and m.pos.x <= @as(f32, @floatFromInt(pl.x)) + 1.3 and
                            m.pos.z >= @as(f32, @floatFromInt(pl.z)) - 0.3 and m.pos.z <= @as(f32, @floatFromInt(pl.z)) + 1.3 and
                            m.pos.y >= @as(f32, @floatFromInt(pl.y)) - 0.1 and m.pos.y <= @as(f32, @floatFromInt(pl.y)) + 0.6)
                        {
                            stepped = true;
                            break;
                        }
                    }
                }

                if (stepped and !pl.down) {
                    pl.down = true;
                    _ = try manager.editAndRemesh(pl.x, pl.y, pl.z, .pressure_plate_down);
                    audio.play(.click_on, 0.85);

                    // Open any adjacent wooden doors (within Manhattan dist 1 horizontal or 1 above/below)
                    const adj_offsets = [_][3]i32{
                        .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
                        .{ 1, 1, 0 }, .{ -1, 1, 0 }, .{ 0, 1, 1 }, .{ 0, 1, -1 },
                        .{ 0, 1, 0 },
                    };
                    for (adj_offsets) |off| {
                        const dx = pl.x + off[0];
                        const dy = pl.y + off[1];
                        const dz = pl.z + off[2];
                        const pdb = manager.getBlockWorld(dx, dy, dz);
                        if (pdb == .wooden_door_closed) {
                            _ = try manager.editAndRemesh(dx, dy, dz, .wooden_door_open);
                            std.debug.print("plate triggered: opened door ({d},{d},{d})\n", .{ dx, dy, dz });
                        } else if (pdb == .iron_door_closed) {
                            _ = try manager.editAndRemesh(dx, dy, dz, .iron_door_open);
                            std.debug.print("plate triggered: opened iron door ({d},{d},{d})\n", .{ dx, dy, dz });
                        }
                    }
                } else if (!stepped and pl.down) {
                    pl.down = false;
                    _ = try manager.editAndRemesh(pl.x, pl.y, pl.z, .pressure_plate_up);
                    audio.play(.click_off, 0.7);

                    // Close any adjacent wooden doors
                    const adj_offsets = [_][3]i32{
                        .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
                        .{ 1, 1, 0 }, .{ -1, 1, 0 }, .{ 0, 1, 1 }, .{ 0, 1, -1 },
                        .{ 0, 1, 0 },
                    };
                    for (adj_offsets) |off| {
                        const dx = pl.x + off[0];
                        const dy = pl.y + off[1];
                        const dz = pl.z + off[2];
                        const pdb = manager.getBlockWorld(dx, dy, dz);
                        if (pdb == .wooden_door_open) {
                            _ = try manager.editAndRemesh(dx, dy, dz, .wooden_door_closed);
                            std.debug.print("plate released: closed door ({d},{d},{d})\n", .{ dx, dy, dz });
                        } else if (pdb == .iron_door_open) {
                            _ = try manager.editAndRemesh(dx, dy, dz, .iron_door_closed);
                            std.debug.print("plate released: closed iron door ({d},{d},{d})\n", .{ dx, dy, dz });
                        }
                    }
                }
                pi += 1;
            }
        }

        // Water washes away redstone: wire/torch/repeater/plate/lever in water pops
        {
            var wri: usize = 0;
            while (wri < wire_count) {
                const w = &wires[wri];
                if (manager.getBlockWorld(w.x, w.y, w.z) == .water or manager.getBlockWorld(w.x, w.y + 1, w.z) == .water) {
                    _ = try manager.editAndRemesh(w.x, w.y, w.z, .air);
                    particles.spawnBlockDebris(w.x, w.y, w.z, .{ 0.6, 0.1, 0.1 }, 4);
                    wires[wri] = wires[wire_count - 1];
                    wire_count -= 1;
                    continue;
                }
                wri += 1;
            }
            var rti2: usize = 0;
            while (rti2 < red_torch_count) {
                const rt = &red_torches[rti2];
                if (manager.getBlockWorld(rt.x, rt.y, rt.z) == .water) {
                    _ = try manager.editAndRemesh(rt.x, rt.y, rt.z, .air);
                    particles.spawnBlockDebris(rt.x, rt.y, rt.z, .{ 0.7, 0.2, 0.1 }, 4);
                    red_torches[rti2] = red_torches[red_torch_count - 1];
                    red_torch_count -= 1;
                    continue;
                }
                rti2 += 1;
            }
        }

                // Redstone wire power: BFS signal strength from sources (15 max, -1/wire).
        // Order-independent; session flags only mirror block state.
        {
            const adj_dirs = [_][3]i32{
                .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
                .{ 0, -1, 0 }, .{ 0, 1, 0 },
            };
            {
                var wi: usize = 0;
                while (wi < wire_count) {
                    const w = &wires[wi];
                    const cur_b = manager.getBlockWorld(w.x, w.y, w.z);
                    if (cur_b != .redstone_wire_off and cur_b != .redstone_wire_on) {
                        wires[wi] = wires[wire_count - 1];
                        wire_count -= 1;
                        continue;
                    }
                    wi += 1;
                }
            }
            var strength: [256]u4 = [_]u4{0} ** 256;
            var wi: usize = 0;
            while (wi < wire_count) : (wi += 1) {
                const w = &wires[wi];
                for (adj_dirs) |ad| {
                    const nb = manager.getBlockWorld(w.x + ad[0], w.y + ad[1], w.z + ad[2]);
                    if (redstone_mod.isSource(nb)) {
                        strength[wi] = redstone_mod.max_strength;
                        break;
                    }
                }
            }
            // Relax along wire graph until no strength rises (Bellman-Ford style,
            // capped at wire_count passes; typically settles in chain-length passes).
            var pass: usize = 0;
            var rising = true;
            while (rising and pass < wire_count) : (pass += 1) {
                rising = false;
                wi = 0;
                while (wi < wire_count) : (wi += 1) {
                    const w = &wires[wi];
                    var best: u4 = strength[wi];
                    for (adj_dirs) |ad| {
                        const nx = w.x + ad[0];
                        const ny = w.y + ad[1];
                        const nz = w.z + ad[2];
                        const nb = manager.getBlockWorld(nx, ny, nz);
                        if (nb != .redstone_wire_on and nb != .redstone_wire_off) continue;
                        var ni: usize = 0;
                        while (ni < wire_count) : (ni += 1) {
                            const o = &wires[ni];
                            if (o.x == nx and o.y == ny and o.z == nz and strength[ni] > 1) {
                                const via: u4 = strength[ni] - 1;
                                if (via > best) best = via;
                                break;
                            }
                        }
                    }
                    if (best > strength[wi]) {
                        strength[wi] = best;
                        rising = true;
                    }
                }
            }
            wi = 0;
            while (wi < wire_count) : (wi += 1) {
                const w = &wires[wi];
                const want = strength[wi] > 0;
                if (want and !w.powered) {
                    w.powered = true;
                    _ = try manager.editAndRemesh(w.x, w.y, w.z, .redstone_wire_on);
                    particles.spawnFlame(w.x, w.y, w.z, 2);
                    for (adj_dirs) |ad| {
                        const tx = w.x + ad[0];
                        const ty = w.y + ad[1];
                        const tz = w.z + ad[2];
                        if (manager.getBlockWorld(tx, ty, tz) == .tnt and fuse_count < fuses.len) {
                            var dup = false;
                            for (fuses[0..fuse_count]) |f| {
                                if (f.x == tx and f.y == ty and f.z == tz) {
                                    dup = true;
                                    break;
                                }
                            }
                            if (!dup) {
                                fuses[fuse_count] = .{ .x = tx, .y = ty, .z = tz, .t = 2.0 };
                                fuse_count += 1;
                                audio.play(.place_block, 0.8);
                                std.debug.print("redstone wire ignited TNT ({d},{d},{d})\n", .{ tx, ty, tz });
                            }
                        }
                        const wb = manager.getBlockWorld(tx, ty, tz);
                        if (wb == .wooden_door_closed) {
                            _ = try manager.editAndRemesh(tx, ty, tz, .wooden_door_open);
                        } else if (wb == .iron_door_closed) {
                            _ = try manager.editAndRemesh(tx, ty, tz, .iron_door_open);
                        }
                    }
                } else if (!want and w.powered) {
                    w.powered = false;
                    _ = try manager.editAndRemesh(w.x, w.y, w.z, .redstone_wire_off);
                    for (adj_dirs) |ad| {
                        const tx = w.x + ad[0];
                        const ty = w.y + ad[1];
                        const tz = w.z + ad[2];
                        const wb = manager.getBlockWorld(tx, ty, tz);
                        if (wb == .wooden_door_open) {
                            _ = try manager.editAndRemesh(tx, ty, tz, .wooden_door_closed);
                        } else if (wb == .iron_door_open) {
                            _ = try manager.editAndRemesh(tx, ty, tz, .iron_door_closed);
                        }
                    }
                }
            }
        }

        // Redstone Repeater logic: 1-tick (0.1s) delay, unidirectional diode amplifier
        {
            var ri: usize = 0;
            while (ri < repeater_count) {
                const rep = &repeaters[ri];
                const cur_b = manager.getBlockWorld(rep.x, rep.y, rep.z);
                if (cur_b != .repeater_off and cur_b != .repeater_on) {
                    repeaters[ri] = repeaters[repeater_count - 1];
                    repeater_count -= 1;
                    continue;
                }

                // Check power input from south/west (-Z, -X) adjacent blocks
                var input_powered = false;
                const in_offsets = [_][3]i32{ .{ 0, 0, -1 }, .{ -1, 0, 0 }, .{ 0, -1, 0 } };
                for (in_offsets) |io| {
                    const ib = manager.getBlockWorld(rep.x + io[0], rep.y + io[1], rep.z + io[2]);
                    if (ib == .redstone_wire_on or ib == .lever_on or ib == .pressure_plate_down or ib == .redstone_torch_on) {
                        input_powered = true;
                        break;
                    }
                }

                const delay: f32 = redstone_mod.repeaterDelay(rep.stage);
                if (input_powered and !rep.powered) {
                    rep.timer += dt;
                    if (rep.timer >= delay) {
                        rep.powered = true;
                        rep.timer = 0.0;
                        _ = try manager.editAndRemesh(rep.x, rep.y, rep.z, .repeater_on);
                        particles.spawnFlame(rep.x, rep.y, rep.z, 1);
                        audio.play(.click_on, 0.4);
                        std.debug.print("repeater powered ({d},{d},{d})\n", .{ rep.x, rep.y, rep.z });
                        const door_dirs = [_][3]i32{ .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 }, .{ 0, 1, 0 }, .{ 0, -1, 0 } };
                        for (door_dirs) |dd| {
                            const db = manager.getBlockWorld(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2]);
                            if (db == .wooden_door_closed) {
                                _ = try manager.editAndRemesh(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2], .wooden_door_open);
                            } else if (db == .iron_door_closed) {
                                _ = try manager.editAndRemesh(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2], .iron_door_open);
                            }
                        }
                    }
                } else if (!input_powered and rep.powered) {
                    rep.timer += dt;
                    if (rep.timer >= delay) {
                        rep.powered = false;
                        rep.timer = 0.0;
                        _ = try manager.editAndRemesh(rep.x, rep.y, rep.z, .repeater_off);
                        const door_dirs = [_][3]i32{ .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 }, .{ 0, 1, 0 }, .{ 0, -1, 0 } };
                        for (door_dirs) |dd| {
                            const db = manager.getBlockWorld(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2]);
                            if (db == .wooden_door_open) {
                                _ = try manager.editAndRemesh(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2], .wooden_door_closed);
                            } else if (db == .iron_door_open) {
                                _ = try manager.editAndRemesh(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2], .iron_door_closed);
                            }
                        }
                    }
                } else {
                    rep.timer = 0.0;
                }
                ri += 1;
            }
        }

        // Redstone Lamp: checks 6 adjacent neighbors for active power (wire, plate, lever, repeater)
        {
            var li: usize = 0;
            while (li < lamp_count) {
                const la = &lamps[li];
                const cur_b = manager.getBlockWorld(la.x, la.y, la.z);
                if (cur_b != .redstone_lamp_off and cur_b != .redstone_lamp_on) {
                    lamps[li] = lamps[lamp_count - 1];
                    lamp_count -= 1;
                    continue;
                }

                var power_in = false;
                const adj_dirs = [_][3]i32{
                    .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
                    .{ 0, 1, 0 }, .{ 0, -1, 0 },
                };
                for (adj_dirs) |ad| {
                    const nb = manager.getBlockWorld(la.x + ad[0], la.y + ad[1], la.z + ad[2]);
                    if (nb == .redstone_wire_on or nb == .pressure_plate_down or nb == .lever_on or nb == .repeater_on or nb == .redstone_torch_on) {
                        power_in = true;
                        break;
                    }
                }

                if (power_in and !la.lit) {
                    la.lit = true;
                    _ = try manager.editAndRemesh(la.x, la.y, la.z, .redstone_lamp_on);
                    particles.spawnFlame(la.x, la.y, la.z, 2);
                    std.debug.print("lamp lit ({d},{d},{d})\n", .{ la.x, la.y, la.z });
                } else if (!power_in and la.lit) {
                    la.lit = false;
                    _ = try manager.editAndRemesh(la.x, la.y, la.z, .redstone_lamp_off);
                }
                li += 1;
            }
        }

        // Redstone Torch: NOT-gate inverter! Lit by default; turns OFF when supporting block below is powered
        {
            var rti: usize = 0;
            while (rti < red_torch_count) {
                const rt = &red_torches[rti];
                const cur_b = manager.getBlockWorld(rt.x, rt.y, rt.z);
                if (cur_b != .redstone_torch_on and cur_b != .redstone_torch_off) {
                    red_torches[rti] = red_torches[red_torch_count - 1];
                    red_torch_count -= 1;
                    continue;
                }

                // Base block directly below the torch
                const base_y = rt.y - 1;
                // Base block receives power from adjacent wires or levers
                var base_powered = false;
                const adj_dirs = [_][3]i32{
                    .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
                    .{ 0, -1, 0 },
                };
                for (adj_dirs) |ad| {
                    const nb = manager.getBlockWorld(rt.x + ad[0], base_y + ad[1], rt.z + ad[2]);
                    if (nb == .redstone_wire_on or nb == .lever_on or nb == .pressure_plate_down) {
                        base_powered = true;
                        break;
                    }
                }

                // Burnout: 8 flips within 3.2s -> 30s dead torch (MC clock protection)
                if (rt.burnout > 0.0) {
                    rt.burnout -= dt;
                    if (rt.burnout <= 0.0) {
                        rt.flip_count = 0;
                        std.debug.print("torch recovered ({d},{d},{d})\n", .{ rt.x, rt.y, rt.z });
                    }
                    rti += 1;
                    continue;
                }
                const flip_now: f32 = @floatCast(current_time);
                const torch_door_dirs = [_][3]i32{ .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 }, .{ 0, 1, 0 }, .{ 0, -1, 0 } };
                if (base_powered and rt.lit) {
                    rt.lit = false;
                    _ = try manager.editAndRemesh(rt.x, rt.y, rt.z, .redstone_torch_off);
                    for (torch_door_dirs) |dd| {
                        const db = manager.getBlockWorld(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2]);
                        if (db == .wooden_door_open) {
                            _ = try manager.editAndRemesh(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2], .wooden_door_closed);
                        } else if (db == .iron_door_open) {
                            _ = try manager.editAndRemesh(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2], .iron_door_closed);
                        }
                    }
                    rt.flips[@as(usize, rt.flip_count) % rt.flips.len] = flip_now;
                    rt.flip_count +%= 1;
                    if (redstone_mod.torchBurnedOut(rt.flips, flip_now)) {
                        rt.burnout = 30.0;
                        audio.play(.click_off, 0.5);
                        std.debug.print("torch burned out ({d},{d},{d})\n", .{ rt.x, rt.y, rt.z });
                    }
                } else if (!base_powered and !rt.lit) {
                    rt.lit = true;
                    _ = try manager.editAndRemesh(rt.x, rt.y, rt.z, .redstone_torch_on);
                    for (torch_door_dirs) |dd| {
                        const db = manager.getBlockWorld(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2]);
                        if (db == .wooden_door_closed) {
                            _ = try manager.editAndRemesh(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2], .wooden_door_open);
                        } else if (db == .iron_door_closed) {
                            _ = try manager.editAndRemesh(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2], .iron_door_open);
                        }
                    }
                    particles.spawnFlame(rt.x, rt.y, rt.z, 2);
                    rt.flips[@as(usize, rt.flip_count) % rt.flips.len] = flip_now;
                    rt.flip_count +%= 1;
                    if (redstone_mod.torchBurnedOut(rt.flips, flip_now)) {
                        rt.burnout = 30.0;
                        audio.play(.click_off, 0.5);
                        std.debug.print("torch burned out ({d},{d},{d})\n", .{ rt.x, rt.y, rt.z });
                    }
                }
                rti += 1;
            }
        }

        // Footstep audio triggered periodically while walking on ground
        if (player.on_ground and player.distance_walked - last_step_dist >= 1.7) {
            last_step_dist = player.distance_walked;
            const ground_x: i32 = @intFromFloat(@floor(player.pos.x));
            const ground_y: i32 = @intFromFloat(@floor(player.pos.y - 0.1));
            const ground_z: i32 = @intFromFloat(@floor(player.pos.z));
            const ground_block = manager.getBlockWorld(ground_x, ground_y, ground_z);
            audio.play(getFootstepSound(ground_block), 0.5);
        }

        // Grow planted sprouts after 30s into 4-high trees with canopy
        var si: usize = 0;
        while (si < sprout_count) {
            sprouts[si].t += dt;
            if (sprouts[si].t >= 30.0) {
                const sx = sprouts[si].x;
                const sy = sprouts[si].y;
                const sz = sprouts[si].z;
                var gi: i32 = 1;
                while (gi <= 3) : (gi += 1) {
                    if (manager.getBlockWorld(sx, sy + gi, sz) == .air) _ = try manager.editAndRemesh(sx, sy + gi, sz, .wood);
                }
                var ox: i32 = -1;
                while (ox <= 1) : (ox += 1) {
                    var oz: i32 = -1;
                    while (oz <= 1) : (oz += 1) {
                        if (ox == 0 and oz == 0) continue;
                        if (manager.getBlockWorld(sx + ox, sy + 4, sz + oz) == .air) _ = try manager.editAndRemesh(sx + ox, sy + 4, sz + oz, .leaves);
                    }
                }
                if (manager.getBlockWorld(sx, sy + 4, sz) == .air) _ = try manager.editAndRemesh(sx, sy + 4, sz, .leaves);
                std.debug.print("sapling grew\n", .{});
                sprouts[si] = sprouts[sprout_count - 1];
                sprout_count -= 1;
            } else {
                si += 1;
            }
        }

        // Stream chunks dynamically around player
        try manager.update(player.pos.x, player.pos.z);

        // Mob spawning and physics AI tick
        try mob_manager.ensureSpawnPopulation(&manager, player.pos.x, player.pos.z);
        mob_manager.tick(&pickSolid, player.pos, player.radius, &audio, dt);

        // Wolf bites: contact damage with per-second cooldown
        wolf_bite_cooldown = @max(0.0, wolf_bite_cooldown - dt);
        if (wolf_bite_cooldown <= 0.0) {
            for (mob_manager.mobs.items) |m| {
                if (m.mob_type != .wolf) continue;
                const bdx = m.pos.x - player.pos.x;
                const bdz = m.pos.z - player.pos.z;
                const bdy = m.pos.y - player.pos.y;
                if (bdx * bdx + bdz * bdz < 1.2 * 1.2 and @abs(bdy) < 2.0) {
                    player.health = @max(0.0, player.health - 2.0);
                    audio.play(.hurt, 0.8);
                    // knock player slightly away
                    const bl = @max(0.5, @sqrt(bdx * bdx + bdz * bdz));
                    player.pos.x -= bdx / bl * 0.6;
                    player.pos.z -= bdz / bl * 0.6;
                    std.debug.print("wolf bite (hp={d:.1})\n", .{player.health});
                    wolf_bite_cooldown = 1.0;
                    break;
                }
            }
        }

        // Mouse look
        var xpos: f64 = 0;
        var ypos: f64 = 0;
        c.glfwGetCursorPos(window, &xpos, &ypos);

        if (!inventory_open) {
            if (first_mouse) {
                last_x = xpos;
                last_y = ypos;
                first_mouse = false;
            }

            const x_offset: f32 = @floatCast(xpos - last_x);
            const y_offset: f32 = @floatCast(ypos - last_y);
            last_x = xpos;
            last_y = ypos;

            cam.processMouse(x_offset, y_offset);
        }

        // Normalized mouse coordinates in [-1, 1] for GUI
        var win_w: c_int = 1280;
        var win_h: c_int = 720;
        c.glfwGetFramebufferSize(window, &win_w, &win_h);
        const mouse_norm_x: f32 = @as(f32, @floatCast(xpos / @as(f64, @floatFromInt(win_w)))) * 2.0 - 1.0;
        const mouse_norm_y: f32 = 1.0 - @as(f32, @floatCast(ypos / @as(f64, @floatFromInt(win_h)))) * 2.0;

        // Build MVP: projection * view
        const aspect: f32 = 1280.0 / 720.0;
        const proj = cam.projectionMatrix(aspect);
        const view = cam.viewMatrix();
        const mvp = math.Mat4.mul(proj, view);

        // Calculate celestial orbit: sun direction and sky dome colors
        const sun_angle = world_time;
        const sun_y = @sin(sun_angle);
        const sun_x = @cos(sun_angle) * 0.8;
        const sun_dir = math.Vec3.normalize(math.Vec3.init(sun_x, @max(0.05, sun_y), 0.3));

        // Interpolate sky colors based on day factor
        const day_factor = @max(0.0, @min(1.0, (sun_y + 0.2) / 0.8));
        const day_top = math.Vec3.init(0.25, 0.50, 0.95);
        const night_top = math.Vec3.init(0.02, 0.03, 0.08);
        const day_horizon = math.Vec3.init(0.75, 0.87, 0.95);
        const night_horizon = math.Vec3.init(0.08, 0.10, 0.18);

        const sky_top = math.Vec3.init(
            night_top.x + (day_top.x - night_top.x) * day_factor,
            night_top.y + (day_top.y - night_top.y) * day_factor,
            night_top.z + (day_top.z - night_top.z) * day_factor,
        );
        const sky_horizon = math.Vec3.init(
            night_horizon.x + (day_horizon.x - night_horizon.x) * day_factor,
            night_horizon.y + (day_horizon.y - night_horizon.y) * day_factor,
            night_horizon.z + (day_horizon.z - night_horizon.z) * day_factor,
        );

        // Render world
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        sky.draw(mvp, cam.position, sky_top, sky_horizon);
        var lamp_spots: [8][3]f32 = [_][3]f32{.{ 0, -100, 0 }} ** 8;
        var lamp_spot_count: usize = 0;
        for (lamps[0..lamp_count]) |la| {
            if (lamp_spot_count >= lamp_spots.len) break;
            if (manager.getBlockWorld(la.x, la.y, la.z) != .redstone_lamp_on) continue;
            const dx: f32 = @as(f32, @floatFromInt(la.x)) + 0.5 - player.pos.x;
            const dz: f32 = @as(f32, @floatFromInt(la.z)) + 0.5 - player.pos.z;
            if (dx * dx + dz * dz > 48.0 * 48.0) continue;
            lamp_spots[lamp_spot_count] = .{ @as(f32, @floatFromInt(la.x)) + 0.5, @as(f32, @floatFromInt(la.y)) + 0.5, @as(f32, @floatFromInt(la.z)) + 0.5 };
            lamp_spot_count += 1;
        }
        const night_factor = 1.0 - day_factor;
        const stats = manager.draw(mvp, sun_dir, lamp_spots[0..lamp_spot_count], night_factor);
        try mob_manager.draw(mvp, sun_dir);

        // Update and render block debris particles
        particles.tick(dt);
        particles.draw(mvp.ptr());

        // Block highlight outline on aimed voxel (skip while mining-gui open)
        if (!inventory_open) {
            const dir_h = cam.front();
            if (pick_mod.raycast(&pickSolid, cam.position, dir_h, 8)) |hit_h| {
                const pulse = 0.5 + 0.5 * @sin(@as(f32, @floatCast(current_time)) * 4.0);
                highlight.draw(mvp.ptr(), hit_h.x, hit_h.y, hit_h.z, pulse);
            }
        }

        // Extract inventory slot colors and counts for rendering
        var hotbar_colors: [6][4]f32 = undefined;
        var hotbar_counts: [6]u8 = undefined;
        for (0..6) |i| {
            hotbar_colors[i] = inventory.slots[i].item.getColor();
            hotbar_counts[i] = inventory.slots[i].count;
        }

        if (!inventory_open) {
            const mine_frac: f32 = if (mine_target_valid and mine_need > 0.0) mine_progress / mine_need else -1.0;
            ui.drawHUDWithBuffs(aspect, selected_slot, &hotbar_colors, &hotbar_counts, mine_frac, player.health, player.hunger, player.regen_timer > 0.0);
        } else {
            var main_colors: [18][4]f32 = undefined;
            var main_counts: [18]u8 = undefined;
            for (0..18) |i| {
                main_colors[i] = inventory.slots[6 + i].item.getColor();
                main_counts[i] = inventory.slots[6 + i].count;
            }

            var craft_colors: [4][4]f32 = undefined;
            var craft_counts: [4]u8 = undefined;
            for (0..4) |i| {
                craft_colors[i] = inventory.craft_grid[i].item.getColor();
                craft_counts[i] = inventory.craft_grid[i].count;
            }

            ui.drawInventory(
                aspect,
                &main_colors,
                &main_counts,
                &hotbar_colors,
                &hotbar_counts,
                &craft_colors,
                &craft_counts,
                inventory.craft_output.item.getColor(),
                inventory.craft_output.count,
                cursor_stack.item.getColor(),
                cursor_stack.count,
                mouse_norm_x,
                mouse_norm_y,
            );
        }

        // Update audio device buffer
        audio.update();

        frame_count += 1;
        hud_frames += 1;
        hud_time += dt;
        if (hud_time >= 0.5) {
            const fps: u64 = @intFromFloat(@as(f32, @floatFromInt(hud_frames)) / hud_time);
            hud_frames = 0;
            hud_time = 0;
            const px = @as(i32, @intFromFloat(@floor(player.pos.x)));
            const py = @as(i32, @intFromFloat(@floor(player.pos.y)));
            const pz = @as(i32, @intFromFloat(@floor(player.pos.z)));
            const dir = cam.front();
            const loaded = manager.loadedChunkCount();
            const mob_count = mob_manager.mobs.items.len;
            const current_item = inventory.slots[selected_slot].item;
            const time_state = if (sun_y > 0.1) "day" else if (sun_y > -0.1) "dusk" else "night";
            if (pick_mod.raycast(&pickSolid, cam.position, dir, 8)) |hit| {
                std.debug.print("fps={d} xyz=({d},{d},{d}) time={s} slot={s} chunk=({d},{d}) loaded={d} mobs={d} drawn={d} culled={d} aim=({d},{d},{d})\n", .{ fps, px, py, pz, time_state, current_item.name(), @divFloor(px, 16), @divFloor(pz, 16), loaded, mob_count, stats.drawn, stats.culled, hit.x, hit.y, hit.z });
            } else {
                std.debug.print("fps={d} xyz=({d},{d},{d}) time={s} slot={s} chunk=({d},{d}) loaded={d} mobs={d} drawn={d} culled={d} aim=none\n", .{ fps, px, py, pz, time_state, current_item.name(), @divFloor(px, 16), @divFloor(pz, 16), loaded, mob_count, stats.drawn, stats.culled });
            }
            var title_buf: [128]u8 = undefined;
            const title = std.fmt.bufPrintZ(&title_buf, "Zigcraft  fps={d}  time={s}  chunks={d}  mobs={d}  block={s}  hp={d:.0} hu={d:.0}", .{ fps, time_state, loaded, mob_count, current_item.name(), player.health, player.hunger }) catch "Zigcraft";
            c.glfwSetWindowTitle(window, title.ptr);
        }

        // Reset wear counters for slots not holding a damaged tool
        for (0..6) |ws| {
            if (!inventory.slots[ws].item.isTool()) tool_wear[ws] = 0;
        }

        // Mouse click handling: In-game block editing or Inventory slot clicking
        const left = c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_LEFT) == c.GLFW_PRESS;
        const right = c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_RIGHT) == c.GLFW_PRESS;
        if ((left and !left_down) or (right and !right_down)) {
            if (inventory_open) {
                // Handle slot interaction in inventory GUI
                const slot_w: f32 = 0.055 / aspect;
                const slot_h: f32 = 0.055;
                const gap: f32 = 0.012 / aspect;

                // Check 2x2 Crafting Grid slots
                const craft_start_x = 0.02;
                const craft_start_y = 0.16;
                var handled = false;
                for (0..2) |r| {
                    for (0..2) |c_idx| {
                        const idx = r * 2 + c_idx;
                        const sx0 = craft_start_x + @as(f32, @floatFromInt(c_idx)) * (slot_w + gap);
                        const sx1 = sx0 + slot_w;
                        const sy1 = craft_start_y - @as(f32, @floatFromInt(r)) * (slot_h + gap * aspect);
                        const sy0 = sy1 - slot_h;
                        if (mouse_norm_x >= sx0 and mouse_norm_x <= sx1 and mouse_norm_y >= sy0 and mouse_norm_y <= sy1) {
                            // Swap or transfer item with cursor
                            const temp = inventory.craft_grid[idx];
                            inventory.craft_grid[idx] = cursor_stack;
                            cursor_stack = temp;
                            inventory.updateCrafting();
                            handled = true;
                            break;
                        }
                    }
                    if (handled) break;
                }

                // Check Crafting Output Slot
                if (!handled) {
                    const arrow_x = craft_start_x + 2.0 * (slot_w + gap) + 0.02 / aspect;
                    const arrow_y = craft_start_y - slot_h * 0.8;
                    const out_x0 = arrow_x + 0.045 / aspect;
                    const out_x1 = out_x0 + slot_w * 1.25;
                    const out_y0 = arrow_y - slot_h * 0.625;
                    const out_y1 = arrow_y + slot_h * 0.625;
                    if (mouse_norm_x >= out_x0 and mouse_norm_x <= out_x1 and mouse_norm_y >= out_y0 and mouse_norm_y <= out_y1) {
                        if (inventory.takeCraftResult(&cursor_stack)) {
                            audio.play(.craft_item, 0.8);
                        }
                        handled = true;
                    }
                }

                // Check Main Inventory (18 slots)
                if (!handled) {
                    const main_start_x = -0.32;
                    const main_start_y = 0.02;
                    for (0..3) |mr| {
                        for (0..6) |mc| {
                            const idx = 6 + mr * 6 + mc;
                            const sx0 = main_start_x + @as(f32, @floatFromInt(mc)) * (slot_w + gap);
                            const sx1 = sx0 + slot_w;
                            const sy1 = main_start_y - @as(f32, @floatFromInt(mr)) * (slot_h + gap * aspect);
                            const sy0 = sy1 - slot_h;
                            if (mouse_norm_x >= sx0 and mouse_norm_x <= sx1 and mouse_norm_y >= sy0 and mouse_norm_y <= sy1) {
                                const temp = inventory.slots[idx];
                                inventory.slots[idx] = cursor_stack;
                                cursor_stack = temp;
                                handled = true;
                                break;
                            }
                        }
                        if (handled) break;
                    }
                }

                // Check Bottom Hotbar (6 slots)
                if (!handled) {
                    const main_start_x = -0.32;
                    const hot_y = -0.32;
                    for (0..6) |hc| {
                        const sx0 = main_start_x + @as(f32, @floatFromInt(hc)) * (slot_w + gap);
                        const sx1 = sx0 + slot_w;
                        const sy0 = hot_y;
                        const sy1 = hot_y + slot_h;
                        if (mouse_norm_x >= sx0 and mouse_norm_x <= sx1 and mouse_norm_y >= sy0 and mouse_norm_y <= sy1) {
                            const temp = inventory.slots[hc];
                            inventory.slots[hc] = cursor_stack;
                            cursor_stack = temp;
                            break;
                        }
                    }
                }
            } else {
                // In-game: hold left to mine (timed by hardness/tool), right click place
                const dir = cam.front();
                mob_hit_cooldown = @max(0.0, mob_hit_cooldown - dt);
                const held_weapon = inventory.slots[selected_slot].item;
                const hit_dmg: u8 = if (held_weapon == .iron_sword) 2 else 1;
                const hit_mob_opt = if (left and mob_hit_cooldown <= 0.0) mob_manager.tryHitMobDmg(cam.position, dir, 4.0, hit_dmg) else null;
                if (hit_mob_opt) |hit_mob| {
                    mob_hit_cooldown = 0.35;
                    if (held_weapon.isTool()) {
                        tool_wear[selected_slot] += 1;
                        if (tool_wear[selected_slot] >= held_weapon.maxDurability()) {
                            inventory.slots[selected_slot].clear();
                            tool_wear[selected_slot] = 0;
                        }
                    }
                    const hit_sound: audio_mod.synth.SoundType = switch (hit_mob.mob_type) {
                        .sheep => .mob_baa,
                        .pig => .mob_oink,
                        .wolf => .mob_growl,
                    };
                    audio.play(hit_sound, 0.8);
                    const px: i32 = @intFromFloat(@floor(hit_mob.pos.x));
                    const py: i32 = @intFromFloat(@floor(hit_mob.pos.y));
                    const pz: i32 = @intFromFloat(@floor(hit_mob.pos.z));
                    particles.spawnBlockDebris(px, py, pz, .{ 0.85, 0.2, 0.2 }, 8);
                    if (hit_mob.died) {
                        const drop: inventory_mod.ItemType = switch (hit_mob.mob_type) {
                            .pig => .raw_pork,
                            .sheep => .raw_mutton,
                            .wolf => .none,
                        };
                        _ = inventory.addItem(drop, 1);
                        if (hit_mob.wool) _ = inventory.addItem(.wool, 1);
                        std.debug.print("killed {s}, dropped {s}\n", .{ @tagName(hit_mob.mob_type), drop.name() });
                    }
                    mine_target_valid = false;
                } else if (pick_mod.raycast(&pickSolid, cam.position, dir, 8)) |hit| {
                    if (left) {
                        const broken_block = manager.getBlockWorld(hit.x, hit.y, hit.z);
                        const held_item_now = inventory.slots[selected_slot].item;
                        const need = block_mod.mineTime(broken_block, @intFromEnum(held_item_now));
                        const key: i64 = (@as(i64, hit.x) << 42) ^ (@as(i64, hit.y) << 21) ^ @as(i64, hit.z);
                        if (!mine_target_valid or mine_key != key) {
                            mine_target_valid = true;
                            mine_key = key;
                            mine_progress = 0.0;
                            mine_need = @max(need, 0.001);
                        } else {
                            mine_progress += dt;
                        }
                        if (mine_progress + 0.0001 >= need and need > 0.0) {
                            mine_target_valid = false;
                            mine_progress = 0.0;
                            if (try manager.editAndRemesh(hit.x, hit.y, hit.z, .air)) {
                                audio.play(.break_block, 0.7);
                                const drop_col = inventory_mod.ItemType.fromBlockId(broken_block).getColor();
                                particles.spawnBlockDebris(hit.x, hit.y, hit.z, .{ drop_col[0], drop_col[1], drop_col[2] }, 16);
                                const held = inventory.slots[selected_slot].item;
                                const tier_ok = blkTierOk(held, broken_block);
                                const drop_item = inventory_mod.ItemType.fromBlockId(broken_block);
                                if (tier_ok) {
                                    if (broken_block == .chest) {
                                        var ci: usize = 0;
                                        while (ci < chest_count) : (ci += 1) {
                                            if (chests[ci].x == hit.x and chests[ci].y == hit.y and chests[ci].z == hit.z) {
                                                for (chests[ci].items) |citem| {
                                                    if (!citem.isEmpty()) _ = inventory.addItem(citem.item, citem.count);
                                                }
                                                chests[ci] = chests[chest_count - 1];
                                                chest_count -= 1;
                                                break;
                                            }
                                        }
                                    }
                                    if (broken_block == .coal_ore) {
                                        _ = inventory.addItem(.coal, 1);
                                        _ = inventory.addItem(.cobblestone, 1);
                                    } else if (broken_block == .snow) {
                                        _ = inventory.addItem(.snowball, 2);
                                    } else {
                                        _ = inventory.addItem(drop_item, 1);
                                    }
                                    if (broken_block == .leaves) {
                                        // Orchard + decay: ~1/7 leaf breaks drop an apple, ~1/12 a sapling
                                        const h: u32 = @as(u32, @bitCast(hit.x *% 31 +% hit.y *% 17 +% hit.z)) % 7;
                                        if (h == 0) {
                                            _ = inventory.addItem(.apple, 1);
                                            std.debug.print("apple dropped\n", .{});
                                        }
                                        const sh: u32 = @as(u32, @bitCast(hit.x *% 13 +% hit.y *% 29 +% hit.z *% 7)) % 12;
                                        if (sh == 0) {
                                            _ = inventory.addItem(.sapling, 1);
                                            std.debug.print("sapling dropped\n", .{});
                                        }
                                    }
                                } else {
                                    std.debug.print("too hard: {s} needs pickaxe\n", .{@tagName(broken_block)});
                                }
                                // Tools wear down one use per mined block
                                if (held.isTool()) {
                                    tool_wear[selected_slot] += 1;
                                    if (tool_wear[selected_slot] >= held.maxDurability()) {
                                        inventory.slots[selected_slot].clear();
                                        tool_wear[selected_slot] = 0;
                                        std.debug.print("pickaxe broke\n", .{});
                                    }
                                }
                                std.debug.print("destroyed {s} ({d},{d},{d})\n", .{ @tagName(broken_block), hit.x, hit.y, hit.z });
                            }
                        }
                    } else {
                        const px = hit.x + hit.nx;
                        const py = hit.y + hit.ny;
                        const pz = hit.z + hit.nz;
                        if (!pickSolid(px, py, pz)) {
                            var hotbar_slot = &inventory.slots[selected_slot];
                            if (hotbar_slot.item == .sapling) {
                                const soil = manager.getBlockWorld(hit.x, hit.y, hit.z);
                                if ((soil == .grass or soil == .dirt) and hit.ny == 1 and py + 2 < 16) {
                                    if (manager.getBlockWorld(px, py + 1, pz) == .air and manager.getBlockWorld(px, py + 2, pz) == .air) {
                                        var ok = try manager.editAndRemesh(px, py, pz, .wood);
                                        ok = (try manager.editAndRemesh(px, py + 1, pz, .wood)) and ok;
                                        ok = (try manager.editAndRemesh(px, py + 2, pz, .leaves)) and ok;
                                        if (ok) {
                                            audio.play(.place_block, 0.7);
                                            hotbar_slot.decrement(1);
                                            if (sprout_count < sprouts.len) {
                                                sprouts[sprout_count] = .{ .x = px, .y = py, .z = pz, .t = 0.0 };
                                                sprout_count += 1;
                                            }
                                            std.debug.print("planted sapling\n", .{});
                                        }
                                    }
                                }
                            } else if (!hotbar_slot.isEmpty()) {
                                if (hotbar_slot.item.toBlockId()) |place_type| {
                                    const is_furnace_place = place_type == .furnace;
                                    if (try manager.editAndRemesh(px, py, pz, place_type)) {
                                        audio.play(.place_block, 0.7);
                                        const pcol = hotbar_slot.item.getColor();
                                        particles.spawnBlockDebris(px, py, pz, .{ pcol[0], pcol[1], pcol[2] }, 8);
                                        if (place_type == .torch and torch_count < torches.len) {
                                            torches[torch_count] = .{ .x = px, .y = py, .z = pz };
                                            torch_count += 1;
                                        }
                                        if (place_type == .chest and chest_count < chests.len) {
                                            chests[chest_count] = .{ .x = px, .y = py, .z = pz, .items = [_]inventory_mod.ItemStack{.{}} ** 4 };
                                            chest_count += 1;
                                        }
                                        if (is_furnace_place and furnace_count < furnaces.len) {
                                            furnaces[furnace_count] = .{ .x = px, .y = py, .z = pz, .t = 0, .fuel = 0, .input = .none };
                                            furnace_count += 1;
                                        }
                                        hotbar_slot.decrement(1);
                                        std.debug.print("placed {s} ({d},{d},{d})\n", .{ @tagName(place_type), px, py, pz });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if (!left) {
            mine_target_valid = false;
            mine_progress = 0.0;
            mine_need = 1.0;
        }
        // Sleep on wool block at night: aim at wool + press B sets spawn, skips to dawn
        bed_cooldown = @max(0.0, bed_cooldown - dt);
        const sun_y_now = @sin(world_time);
        if (!inventory_open and bed_cooldown <= 0.0 and c.glfwGetKey(window, c.GLFW_KEY_B) == c.GLFW_PRESS) {
            const dir_b = cam.front();
            if (pick_mod.raycast(&pickSolid, cam.position, dir_b, 5)) |hit_b| {
                if (manager.getBlockWorld(hit_b.x, hit_b.y, hit_b.z) == .wool) {
                    if (sun_y_now < 0.15) {
                        world_time = std.math.pi * 0.08; // dawn
                        player.spawn_point = player.pos;
                        player.health = 20.0;
                        audio.play(.craft_item, 0.7);
                        std.debug.print("slept; spawn set\n", .{});
                    } else {
                        std.debug.print("sleep only at night\n", .{});
                    }
                    bed_cooldown = 1.0;
                }
            }
        }
        // Furnace tick: cook stored input using fuel, 10s per item
        {
            var fi: usize = 0;
            while (fi < furnace_count) {
                const f = &furnaces[fi];
                if (manager.getBlockWorld(f.x, f.y, f.z) != .furnace) {
                    furnaces[fi] = furnaces[furnace_count - 1];
                    furnace_count -= 1;
                    continue;
                }
                if (f.input != .none and f.fuel > 0) {
                    f.t += dt;
                    if (f.t >= 10.0) {
                        f.t = 0.0;
                        f.fuel -= 1;
                        const done: inventory_mod.ItemType = switch (f.input) {
                            .raw_pork => .cooked_pork,
                            .raw_mutton => .cooked_mutton,
                            .sand => .glass,
                            .iron_ore => .iron_ingot,
                            else => .none,
                        };
                        f.input = .none;
                        if (done != .none) {
                            _ = inventory.addItem(done, 1);
                            audio.play(.craft_item, 0.7);
                            std.debug.print("smelted {s}\n", .{done.name()});
                        }
                    }
                } else {
                    f.t = 0.0;
                }
                fi += 1;
            }
        }
        // Falling sand: unsupported sand drops one block per 0.15s
        {
            sand_scan +%= 1;
            if (sand_scan % 10 == 0) {
                var fiter = manager.chunks.iterator();
                while (fiter.next()) |entry| {
                    if (falling_count >= fallings.len) break;
                    const fcx = entry.key_ptr.x;
                    const fcz = entry.key_ptr.z;
                    const fch = &entry.value_ptr.chunk;
                    var fy: usize = 1;
                    while (fy < 16) : (fy += 1) {
                        var fz: usize = 0;
                        while (fz < 16) : (fz += 1) {
                            var fx: usize = 0;
                            while (fx < 16) : (fx += 1) {
                                if (fch.blocks[fy][fz][fx] != .sand) continue;
                                if (fch.blocks[fy - 1][fz][fx] != .air) continue;
                                const wx: i32 = fcx * 16 + @as(i32, @intCast(fx));
                                const wy: i32 = @as(i32, @intCast(fy));
                                const wz: i32 = fcz * 16 + @as(i32, @intCast(fz));
                                var known = false;
                                for (fallings[0..falling_count]) |f| {
                                    if (f.x == wx and f.y == wy and f.z == wz) {
                                        known = true;
                                        break;
                                    }
                                }
                                if (!known and falling_count < fallings.len) {
                                    fallings[falling_count] = .{ .x = wx, .y = wy, .z = wz, .t = 0.0, .dist = 0 };
                                    falling_count += 1;
                                }
                                if (falling_count >= fallings.len) break;
                            }
                            if (falling_count >= fallings.len) break;
                        }
                        if (falling_count >= fallings.len) break;
                    }
                }
            }
            var fi2: usize = 0;
            while (fi2 < falling_count) {
                const f = &fallings[fi2];
                if (manager.getBlockWorld(f.x, f.y, f.z) != .sand) {
                    fallings[fi2] = fallings[falling_count - 1];
                    falling_count -= 1;
                    continue;
                }
                f.t += dt;
                if (f.t >= 0.15) {
                    f.t = 0.0;
                    const below = manager.getBlockWorld(f.x, f.y - 1, f.z);
                    if (below == .air and f.y > 0) {
                        _ = try manager.editAndRemesh(f.x, f.y - 1, f.z, .sand);
                        _ = try manager.editAndRemesh(f.x, f.y, f.z, .air);
                        f.y -= 1;
                        f.dist += 1;
                    } else if (!below.is_solid() and f.y > 0) {
                        // Sand crushes torches/wires/plates/etc: pop cell, keep falling
                        _ = try manager.editAndRemesh(f.x, f.y - 1, f.z, .sand);
                        _ = try manager.editAndRemesh(f.x, f.y, f.z, .air);
                        f.y -= 1;
                        f.dist += 1;
                        particles.spawnBlockDebris(f.x, f.y, f.z, .{ 0.8, 0.7, 0.5 }, 4);
                    } else {
                        // Landing: 1 dmg per 3 fallen blocks to whoever is inside
                        if (f.dist >= 3) {
                            const dmg: u8 = @intCast(@min(@divTrunc(f.dist, 3), 20));
                            for (mob_manager.mobs.items, 0..) |*m, mi| {
                                const mbx: i32 = @intFromFloat(@floor(m.pos.x));
                                const mby: i32 = @intFromFloat(@floor(m.pos.y));
                                const mbz: i32 = @intFromFloat(@floor(m.pos.z));
                                if (mbx == f.x and (mby == f.y or mby == f.y + 1) and mbz == f.z) {
                                    if (m.takeHitDmg(math.Vec3.init(0, 1, 0), dmg)) {
                                        _ = mob_manager.mobs.swapRemove(mi);
                                    }
                                    break;
                                }
                            }
                            const pbx: i32 = @intFromFloat(@floor(player.pos.x));
                            const pby: i32 = @intFromFloat(@floor(player.pos.y));
                            const pbz: i32 = @intFromFloat(@floor(player.pos.z));
                            if (pbx == f.x and (pby == f.y or pby == f.y + 1) and pbz == f.z) {
                                player.health = @max(0.0, player.health - @as(f32, @floatFromInt(dmg)));
                                audio.play(.hurt, 0.8);
                            }
                        }
                        fallings[fi2] = fallings[falling_count - 1];
                        falling_count -= 1;
                        continue;
                    }
                }
                fi2 += 1;
            }
        }
                // Torch flame particles: nearby active torches emit flame tips
        torch_puff_timer += dt;
        if (torch_puff_timer >= 0.2) {
            torch_puff_timer = 0.0;
            var ti: usize = 0;
            while (ti < torch_count) {
                const tr = &torches[ti];
                if (manager.getBlockWorld(tr.x, tr.y, tr.z) != .torch) {
                    torches[ti] = torches[torch_count - 1];
                    torch_count -= 1;
                    continue;
                }
                const tdx = @as(f32, @floatFromInt(tr.x)) - player.pos.x;
                const tdz = @as(f32, @floatFromInt(tr.z)) - player.pos.z;
                if (tdx * tdx + tdz * tdz < 20.0 * 20.0) {
                    particles.spawnFlame(tr.x, tr.y, tr.z, 1);
                }
                ti += 1;
            }
        }

        // Thrown snowball physics: gravity arc, mob hit = 1 dmg + knockback, block hit = puff
        {
            var ti: usize = 0;
            while (ti < thrown_count) {
                var t = &thrown[ti];
                t.life -= dt;
                t.vel.y -= 12.0 * dt;
                t.pos.x += t.vel.x * dt;
                t.pos.y += t.vel.y * dt;
                t.pos.z += t.vel.z * dt;
                var dead = t.life <= 0.0;
                if (!dead) {
                    const mbx: i32 = @intFromFloat(@floor(t.pos.x));
                    const mby: i32 = @intFromFloat(@floor(t.pos.y));
                    const mbz: i32 = @intFromFloat(@floor(t.pos.z));
                    if (pickSolid(mbx, mby, mbz)) {
                        particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.93, 0.95, 1.0 }, 6);
                        dead = true;
                    } else {
                        // mob hit test (generous radius)
                        for (mob_manager.mobs.items, 0..) |*m, mi| {
                            const ddx = m.pos.x - t.pos.x;
                            const ddy = (m.pos.y + 0.4) - t.pos.y;
                            const ddz = m.pos.z - t.pos.z;
                            if (ddx * ddx + ddy * ddy + ddz * ddz < 0.8 * 0.8) {
                                const died = m.takeHit(cam.front());
                                audio.play(.hurt, 0.5);
                                particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.93, 0.95, 1.0 }, 8);
                                if (died) {
                                    const md: inventory_mod.ItemType = switch (m.mob_type) {
                                        .pig => .raw_pork,
                                        .sheep => .raw_mutton,
                                        .wolf => .none,
                                    };
                                    const mp = m.pos;
                                    _ = mob_manager.mobs.swapRemove(mi);
                                    _ = inventory.addItem(md, 1);
                                    if (m.mob_type == .sheep) _ = inventory.addItem(.wool, 1);
                                    _ = mp;
                                }
                                dead = true;
                                break;
                            }
                        }
                    }
                }
                if (dead) {
                    thrown[ti] = thrown[thrown_count - 1];
                    thrown_count -= 1;
                } else {
                    // trail puff
                    particles.spawnBlockDebris(@intFromFloat(@floor(t.pos.x)), @intFromFloat(@floor(t.pos.y)), @intFromFloat(@floor(t.pos.z)), .{ 0.9, 0.92, 1.0 }, 1);
                    ti += 1;
                }
            }
        }
        // G throws snowball
        throw_cooldown = @max(0.0, throw_cooldown - dt);
        if (!inventory_open and throw_cooldown <= 0.0 and c.glfwGetKey(window, c.GLFW_KEY_G) == c.GLFW_PRESS) {
            if (inventory.slots[selected_slot].item == .snowball and thrown_count < thrown.len) {
                const dir_g = cam.front();
                thrown[thrown_count] = .{ .pos = cam.position, .vel = math.Vec3.init(dir_g.x * 18.0, dir_g.y * 18.0 + 2.0, dir_g.z * 18.0), .life = 3.0 };
                thrown_count += 1;
                inventory.slots[selected_slot].decrement(1);
                audio.play(.place_block, 0.4);
                throw_cooldown = 0.4;
            }
        }
        // TNT tick: white/smoke pulses during fuse; explode on 0
        {
            var fsi: usize = 0;
            while (fsi < fuse_count) {
                var fu = &fuses[fsi];
                fu.t -= dt;
                // fuse particles
                particles.spawnFlame(fu.x, fu.y + 1, fu.z, 2);
                if (fu.t <= 0.0) {
                    const ex = fu.x;
                    const ey = fu.y;
                    const ez = fu.z;
                    // remove TNT block itself
                    _ = try manager.editAndRemesh(ex, ey, ez, .air);
                    // explode 3-block sphere
                    var rx: i32 = -3;
                    while (rx <= 3) : (rx += 1) {
                        var ry: i32 = -3;
                        while (ry <= 3) : (ry += 1) {
                            var rz: i32 = -3;
                            while (rz <= 3) : (rz += 1) {
                                if (rx * rx + ry * ry + rz * rz <= 10) {
                                    const bx = ex + rx;
                                    const by = ey + ry;
                                    const bz = ez + rz;
                                    if (by > 0) {
                                        const old_b = manager.getBlockWorld(bx, by, bz);
                                        if (old_b == .tnt) {
                                            // Chain-detonate: light neighbor TNT with short fuse
                                            var already = false;
                                            for (fuses[0..fuse_count]) |f| {
                                                if (f.x == bx and f.y == by and f.z == bz) {
                                                    already = true;
                                                    break;
                                                }
                                            }
                                            if (!already and fuse_count < fuses.len) {
                                                fuses[fuse_count] = .{ .x = bx, .y = by, .z = bz, .t = 0.5 };
                                                fuse_count += 1;
                                                std.debug.print("chain-detonated TNT ({d},{d},{d})\n", .{ bx, by, bz });
                                            }
                                        } else if (old_b != .air) {
                                            _ = try manager.editAndRemesh(bx, by, bz, .air);
                                        }
                                    }
                                }
                            }
                        }
                    }
                    audio.play(.break_block, 1.0);
                    particles.spawnBlockDebris(ex, ey, ez, .{ 1.0, 0.3, 0.1 }, 64);
                    // mob blast damage
                    for (mob_manager.mobs.items, 0..) |*m, mi| {
                        const mdx = m.pos.x - @as(f32, @floatFromInt(ex));
                        const mdy = m.pos.y - @as(f32, @floatFromInt(ey));
                        const mdz = m.pos.z - @as(f32, @floatFromInt(ez));
                        const dist_sq = mdx * mdx + mdy * mdy + mdz * mdz;
                        if (dist_sq < 36.0) {
                            const died = m.takeHitDmg(math.Vec3.init(mdx, mdy + 2.0, mdz), 8);
                            if (died) {
                                _ = mob_manager.mobs.swapRemove(mi);
                            }
                        }
                    }
                    // player blast damage + launch
                    const pdx = player.pos.x - @as(f32, @floatFromInt(ex));
                    const pdy = player.pos.y - @as(f32, @floatFromInt(ey));
                    const pdz = player.pos.z - @as(f32, @floatFromInt(ez));
                    const pdist = @sqrt(pdx * pdx + pdy * pdy + pdz * pdz);
                    if (pdist < 7.0 and pdist > 0.1) {
                        const blast_force = (7.0 - pdist) / 7.0;
                        player.health = @max(0.0, player.health - blast_force * 14.0);
                        player.vel_y = blast_force * 12.0;
                        player.pos.x += (pdx / pdist) * blast_force * 3.0;
                        player.pos.z += (pdz / pdist) * blast_force * 3.0;
                        audio.play(.hurt, 1.0);
                    }
                    fuses[fsi] = fuses[fuse_count - 1];
                    fuse_count -= 1;
                } else {
                    fsi += 1;
                }
            }
        }
        // F: flint spark — ignite aimed flammable block (edge triggered, 0.5s cooldown)
        flint_cooldown = @max(0.0, flint_cooldown - dt);
        if (!inventory_open and flint_cooldown <= 0.0 and c.glfwGetKey(window, c.GLFW_KEY_F) == c.GLFW_PRESS) {
            const dir_f = cam.front();
            if (pick_mod.raycast(&pickSolid, cam.position, dir_f, 5)) |hit_f| {
                const target = manager.getBlockWorld(hit_f.x, hit_f.y, hit_f.z);
                if (target == .repeater_off or target == .repeater_on) {
                    var found_stage = false;
                    for (repeaters[0..repeater_count]) |*rep| {
                        if (rep.x == hit_f.x and rep.y == hit_f.y and rep.z == hit_f.z) {
                            rep.stage +%= 1;
                            rep.timer = 0.0;
                            found_stage = true;
                            audio.play(.click_on, 0.6);
                            std.debug.print("repeater delay stage {d} ({d},{d},{d})\n", .{ @as(u8, rep.stage) + 1, hit_f.x, hit_f.y, hit_f.z });
                            {
                                var snap: [64][4]i32 = undefined;
                                var sn: usize = 0;
                                for (repeaters[0..repeater_count]) |sr| {
                                    if (sn >= snap.len) break;
                                    snap[sn] = .{ sr.x, sr.y, sr.z, sr.stage };
                                    sn += 1;
                                }
                                chunk_manager_mod.ChunkManager.setStageSnapshot(snap[0..sn]);
                                if (manager.chunks.getPtr(.{ .x = @divFloor(hit_f.x, 16), .z = @divFloor(hit_f.z, 16) })) |e| {
                                    manager.saveStages(@divFloor(hit_f.x, 16), @divFloor(hit_f.z, 16), &e.chunk);
                                }
                            }
                            break;
                        }
                    }
                    if (!found_stage and repeater_count < repeaters.len) {
                        repeaters[repeater_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .powered = (target == .repeater_on), .timer = 0.0, .stage = 1 };
                        repeater_count += 1;
                        audio.play(.click_on, 0.6);
                        std.debug.print("repeater delay stage 2 ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                    }
                    flint_cooldown = 0.25;
                } else if (target == .lever_off or target == .lever_on) {
                    const toggled: block_mod.BlockId = if (target == .lever_off) .lever_on else .lever_off;
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, toggled)) {
                        if (toggled == .lever_on) audio.play(.click_on, 0.9) else audio.play(.click_off, 0.7);
                        const adj_offsets = [_][3]i32{
                            .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
                            .{ 1, 1, 0 }, .{ -1, 1, 0 }, .{ 0, 1, 1 }, .{ 0, 1, -1 },
                            .{ 0, 1, 0 }, .{ 0, -1, 0 },
                        };
                        for (adj_offsets) |off| {
                            const dx = hit_f.x + off[0];
                            const dy = hit_f.y + off[1];
                            const dz = hit_f.z + off[2];
                            const db = manager.getBlockWorld(dx, dy, dz);
                            if (toggled == .lever_on and db == .wooden_door_closed) {
                                _ = try manager.editAndRemesh(dx, dy, dz, .wooden_door_open);
                            } else if (toggled == .lever_off and db == .wooden_door_open) {
                                _ = try manager.editAndRemesh(dx, dy, dz, .wooden_door_closed);
                            } else if (toggled == .lever_on and db == .iron_door_closed) {
                                _ = try manager.editAndRemesh(dx, dy, dz, .iron_door_open);
                            } else if (toggled == .lever_off and db == .iron_door_open) {
                                _ = try manager.editAndRemesh(dx, dy, dz, .iron_door_closed);
                            }
                        }
                        std.debug.print("toggled lever to {s} ({d},{d},{d})\n", .{ @tagName(toggled), hit_f.x, hit_f.y, hit_f.z });
                    }
                    flint_cooldown = 0.25;
                } else if (target == .iron_door_closed or target == .iron_door_open) {
                    audio.play(.step_stone, 0.7);
                    std.debug.print("iron door locked; requires redstone signal\n", .{});
                    flint_cooldown = 0.25;
                } else if (target == .wooden_door_closed or target == .wooden_door_open) {
                    const toggled: block_mod.BlockId = if (target == .wooden_door_closed) .wooden_door_open else .wooden_door_closed;
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, toggled)) {
                        audio.play(.place_block, 0.9);
                        std.debug.print("toggled door to {s} ({d},{d},{d})\n", .{ @tagName(toggled), hit_f.x, hit_f.y, hit_f.z });
                    }
                    flint_cooldown = 0.25;
                } else if (target == .tnt and fuse_count < fuses.len) {
                    fuses[fuse_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .t = 2.5 };
                    fuse_count += 1;
                    audio.play(.place_block, 0.8);
                    std.debug.print("lit TNT fuse\n", .{});
                    flint_cooldown = 0.5;
                } else if (target == .chest) {
                    var k: usize = 0;
                    while (k < chest_count) : (k += 1) {
                        if (chests[k].x == hit_f.x and chests[k].y == hit_f.y and chests[k].z == hit_f.z) break;
                    }
                    if (k >= chest_count and chest_count < chests.len) {
                        chests[chest_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .items = [_]inventory_mod.ItemStack{.{}} ** 4 };
                        chest_count += 1;
                    }
                    if (k < chests.len and chests[k].x == hit_f.x and chests[k].y == hit_f.y and chests[k].z == hit_f.z) {
                        const held_item = inventory.slots[selected_slot].item;
                        if (held_item != .none) {
                            var stored = false;
                            for (&chests[k].items) |*cslot| {
                                if (cslot.item == held_item and cslot.count < 64) {
                                    cslot.count += 1;
                                    inventory.slots[selected_slot].decrement(1);
                                    stored = true;
                                    break;
                                }
                            }
                            if (!stored) {
                                for (&chests[k].items) |*cslot| {
                                    if (cslot.isEmpty()) {
                                        cslot.* = .{ .item = held_item, .count = 1 };
                                        inventory.slots[selected_slot].decrement(1);
                                        stored = true;
                                        break;
                                    }
                                }
                            }
                            if (stored) {
                                audio.play(.place_block, 0.7);
                                std.debug.print("deposited {s} into chest\n", .{held_item.name()});
                            }
                        } else {
                            for (&chests[k].items) |*cslot| {
                                if (!cslot.isEmpty()) {
                                    const take_cnt = cslot.count;
                                    const itm = cslot.item;
                                    const rem = inventory.addItem(itm, take_cnt);
                                    if (rem < take_cnt) {
                                        cslot.count = rem;
                                        if (rem == 0) cslot.clear();
                                        audio.play(.break_block, 0.7);
                                        std.debug.print("withdrew {d} {s} from chest\n", .{take_cnt, itm.name()});
                                    }
                                    break;
                                }
                            }
                        }
                    }
                    flint_cooldown = 0.3;
                } else if (target == .furnace) {
                    // feed held item as input or fuel
                    const held_f = inventory.slots[selected_slot];
                    const smeltable = switch (held_f.item) {
                        .raw_pork, .raw_mutton, .sand, .iron_ore => true,
                        else => false,
                    };
                    var fed = false;
                    var k: usize = 0;
                    while (k < furnace_count) : (k += 1) {
                        if (furnaces[k].x == hit_f.x and furnaces[k].y == hit_f.y and furnaces[k].z == hit_f.z) break;
                    }
                    if (k >= furnace_count and furnace_count < furnaces.len) {
                        furnaces[furnace_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .t = 0, .fuel = 0, .input = .none };
                        furnace_count += 1;
                    }
                    if (k < furnaces.len and furnaces[k].x == hit_f.x and furnaces[k].y == hit_f.y and furnaces[k].z == hit_f.z) {
                        if (held_f.item == .coal and furnaces[k].fuel < 8) {
                            furnaces[k].fuel += 1;
                            inventory.slots[selected_slot].decrement(1);
                            fed = true;
                        } else if (smeltable and furnaces[k].input == .none) {
                            furnaces[k].input = held_f.item;
                            inventory.slots[selected_slot].decrement(1);
                            fed = true;
                        }
                    }
                    if (fed) audio.play(.place_block, 0.6);
                    flint_cooldown = 0.5;
                } else
                if (target.isFlammable()) {
                    particles.spawnFlame(hit_f.x, hit_f.y, hit_f.z, 14);
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, .air)) {
                        audio.play(.break_block, 0.6);
                        const drop_item = inventory_mod.ItemType.fromBlockId(target);
                        _ = inventory.addItem(drop_item, 1);
                        std.debug.print("burned {s}\n", .{@tagName(target)});
                    }
                    flint_cooldown = 0.5;
                }
            }
        }
        // Right-click eats held meat (edge triggered, in-game only)
        if (right and !right_down and !inventory_open) {
            const held_eat = inventory.slots[selected_slot];
            const cooked = switch (held_eat.item) {
                .cooked_pork, .cooked_mutton => true,
                .raw_pork, .raw_mutton => false,
                else => null,
            };
            if (held_eat.item == .golden_apple) {
                player.eatGolden();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                std.debug.print("ate golden apple (hp={d:.1})\n", .{player.health});
            } else if (held_eat.item == .apple and player.hunger < 20.0) {
                player.eatApple();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.7);
                std.debug.print("ate apple (hunger={d:.1})\n", .{player.hunger});
            } else
            if (cooked) |is_cooked| {
                if (player.hunger < 20.0) {
                    player.eat(is_cooked);
                    inventory.slots[selected_slot].decrement(1);
                    audio.play(.eat, 0.7);
                    std.debug.print("ate {s} (hunger={d:.1})\n", .{ held_eat.item.name(), player.hunger });
                }
            }
        }
        left_down = left;
        right_down = right;

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();

        if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS) {
            c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
        }
    }

    std.debug.print("shutting down\n", .{});
}
