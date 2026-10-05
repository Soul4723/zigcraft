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
    const Thrown = struct { pos: math.Vec3, vel: math.Vec3, life: f32 };
    var thrown: [8]Thrown = undefined;
    var thrown_count: usize = 0;
    const FurnaceJob = struct { x: i32, y: i32, z: i32, t: f32, fuel: u8, input: inventory_mod.ItemType };
    var furnaces: [16]FurnaceJob = undefined;
    var furnace_count: usize = 0;
    var sprouts: [16]struct { x: i32, y: i32, z: i32, t: f32 } = undefined;
    var sprout_count: usize = 0;
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
        const stats = manager.draw(mvp, sun_dir);
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
        // F: flint spark — ignite aimed flammable block (edge triggered, 0.5s cooldown)
        flint_cooldown = @max(0.0, flint_cooldown - dt);
        if (!inventory_open and flint_cooldown <= 0.0 and c.glfwGetKey(window, c.GLFW_KEY_F) == c.GLFW_PRESS) {
            const dir_f = cam.front();
            if (pick_mod.raycast(&pickSolid, cam.position, dir_f, 5)) |hit_f| {
                const target = manager.getBlockWorld(hit_f.x, hit_f.y, hit_f.z);
                if (target == .furnace) {
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
