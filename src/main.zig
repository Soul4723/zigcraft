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

const window_width = 1280;
const window_height = 720;
const window_title = "Zigcraft";

var pick_manager: ?*chunk_manager_mod.ChunkManager = null;

fn pickSolid(x: i32, y: i32, z: i32) bool {
    return pick_manager.?.isSolidWorld(x, y, z);
}

fn getFootstepSound(block: block_mod.BlockId) audio_mod.synth.SoundType {
    return switch (block) {
        .grass => .step_grass,
        .stone => .step_stone,
        .wood => .step_wood,
        .dirt => .step_dirt,
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

    var audio = audio_mod.AudioSystem.init();
    defer audio.deinit();

    const atlas_texture = texture_mod.createBlockTexture();
    defer c.glDeleteTextures(1, &atlas_texture);
    var mob_manager = try entity_mod.mob_manager.MobManager.init(std.heap.page_allocator, atlas_texture);
    defer mob_manager.deinit();

    // Hotbar selection: 0=stone, 1=dirt, 2=grass, 3=water, 4=wood, 5=leaves
    const hotbar_blocks = [6]block_mod.BlockId{ .stone, .dirt, .grass, .water, .wood, .leaves };
    var selected_slot: usize = 0;

    // Timing & Day/Night cycle
    var last_time = c.glfwGetTime();
    var frame_count: u64 = 0;
    var hud_frames: u64 = 0;
    var hud_time: f32 = 0;
    var left_down = false;
    var right_down = false;
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
        const norm_wish = if (wish_len > 0.001) wish.scale(1.0 / wish_len) else wish;
        const jump = c.glfwGetKey(window, c.GLFW_KEY_SPACE) == c.GLFW_PRESS;
        player.tick(&pickSolid, norm_wish.x * walk_speed * dt, norm_wish.z * walk_speed * dt, jump, dt);
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

        // Stream chunks dynamically around player
        try manager.update(player.pos.x, player.pos.z);

        // Mob spawning and physics AI tick
        try mob_manager.ensureSpawnPopulation(&manager, player.pos.x, player.pos.z);
        mob_manager.tick(&pickSolid, player.pos, player.radius, &audio, dt);

        // Mouse look
        var xpos: f64 = 0;
        var ypos: f64 = 0;
        c.glfwGetCursorPos(window, &xpos, &ypos);

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

        // Render 2D UI overlay (crosshair + hotbar)
        ui.draw(aspect, selected_slot);

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
            const current_block = hotbar_blocks[selected_slot];
            const time_state = if (sun_y > 0.1) "day" else if (sun_y > -0.1) "dusk" else "night";
            if (pick_mod.raycast(&pickSolid, cam.position, dir, 8)) |hit| {
                std.debug.print("fps={d} xyz=({d},{d},{d}) time={s} slot={s} chunk=({d},{d}) loaded={d} mobs={d} drawn={d} culled={d} aim=({d},{d},{d})\n", .{ fps, px, py, pz, time_state, @tagName(current_block), @divFloor(px, 16), @divFloor(pz, 16), loaded, mob_count, stats.drawn, stats.culled, hit.x, hit.y, hit.z });
            } else {
                std.debug.print("fps={d} xyz=({d},{d},{d}) time={s} slot={s} chunk=({d},{d}) loaded={d} mobs={d} drawn={d} culled={d} aim=none\n", .{ fps, px, py, pz, time_state, @tagName(current_block), @divFloor(px, 16), @divFloor(pz, 16), loaded, mob_count, stats.drawn, stats.culled });
            }
            var title_buf: [128]u8 = undefined;
            const title = std.fmt.bufPrintZ(&title_buf, "Zigcraft  fps={d}  time={s}  chunks={d}  mobs={d}  block={s}", .{ fps, time_state, loaded, mob_count, @tagName(current_block) }) catch "Zigcraft";
            c.glfwSetWindowTitle(window, title.ptr);
        }

        // Block edit: left-click destroy, right-click place (edge-triggered).
        const left = c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_LEFT) == c.GLFW_PRESS;
        const right = c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_RIGHT) == c.GLFW_PRESS;
        if ((left and !left_down) or (right and !right_down)) {
            const dir = cam.front();
            if (left and mob_manager.tryHitMob(cam.position, dir, 4.0)) {
                audio.play(.mob_baa, 0.8);
            } else if (pick_mod.raycast(&pickSolid, cam.position, dir, 8)) |hit| {
                if (left) {
                    if (try manager.editAndRemesh(hit.x, hit.y, hit.z, .air)) {
                        audio.play(.break_block, 0.7);
                        std.debug.print("destroyed ({d},{d},{d})\n", .{ hit.x, hit.y, hit.z });
                    }
                } else {
                    const px = hit.x + hit.nx;
                    const py = hit.y + hit.ny;
                    const pz = hit.z + hit.nz;
                    if (!pickSolid(px, py, pz)) {
                        const place_type = hotbar_blocks[selected_slot];
                        if (try manager.editAndRemesh(px, py, pz, place_type)) {
                            audio.play(.place_block, 0.7);
                            std.debug.print("placed {s} ({d},{d},{d})\n", .{ @tagName(place_type), px, py, pz });
                        }
                    }
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
