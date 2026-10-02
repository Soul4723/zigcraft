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

const window_width = 1280;
const window_height = 720;
const window_title = "Zigcraft";

var pick_manager: ?*chunk_manager_mod.ChunkManager = null;

fn pickSolid(x: i32, y: i32, z: i32) bool {
    return pick_manager.?.isSolidWorld(x, y, z);
}

pub fn main() !void {
    std.debug.print("zigcraft v0.0.5\n", .{});

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
    c.glClearColor(0.53, 0.81, 0.92, 1.0);

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

    // Hotbar selection: 0=stone, 1=dirt, 2=grass
    const hotbar_blocks = [3]block_mod.BlockId{ .stone, .dirt, .grass };
    var selected_slot: usize = 0;

    // Timing
    var last_time = c.glfwGetTime();
    var frame_count: u64 = 0;
    var hud_frames: u64 = 0;
    var hud_time: f32 = 0;
    var left_down = false;
    var right_down = false;

    // Mouse tracking
    var last_x: f64 = @floatFromInt(window_width / 2);
    var last_y: f64 = @floatFromInt(window_height / 2);
    var first_mouse = true;

    std.debug.print("ready. Dynamic chunk streaming (r=3, 7x7 grid) + Hotbar/Crosshair. Keys 1-3 select block.\n", .{});

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        // Delta time
        const current_time = c.glfwGetTime();
        const dt: f32 = @floatCast(current_time - last_time);
        last_time = current_time;

        // Hotbar selection keys 1, 2, 3
        if (c.glfwGetKey(window, c.GLFW_KEY_1) == c.GLFW_PRESS) selected_slot = 0;
        if (c.glfwGetKey(window, c.GLFW_KEY_2) == c.GLFW_PRESS) selected_slot = 1;
        if (c.glfwGetKey(window, c.GLFW_KEY_3) == c.GLFW_PRESS) selected_slot = 2;

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

        // Stream chunks dynamically around player
        try manager.update(player.pos.x, player.pos.z);

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

        // Render world
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        sky.draw(mvp, cam.position);
        const stats = manager.draw(mvp);

        // Render 2D UI overlay (crosshair + hotbar)
        ui.draw(aspect, selected_slot);

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
            const current_block = hotbar_blocks[selected_slot];
            if (pick_mod.raycast(&pickSolid, cam.position, dir, 8)) |hit| {
                std.debug.print("fps={d} xyz=({d},{d},{d}) slot={s} chunk=({d},{d}) loaded={d} drawn={d} culled={d} aim=({d},{d},{d})\n", .{ fps, px, py, pz, @tagName(current_block), @divFloor(px, 16), @divFloor(pz, 16), loaded, stats.drawn, stats.culled, hit.x, hit.y, hit.z });
            } else {
                std.debug.print("fps={d} xyz=({d},{d},{d}) slot={s} chunk=({d},{d}) loaded={d} drawn={d} culled={d} aim=none\n", .{ fps, px, py, pz, @tagName(current_block), @divFloor(px, 16), @divFloor(pz, 16), loaded, stats.drawn, stats.culled });
            }
            var title_buf: [128]u8 = undefined;
            const title = std.fmt.bufPrintZ(&title_buf, "Zigcraft  fps={d}  chunks={d}  block={s}", .{ fps, loaded, @tagName(current_block) }) catch "Zigcraft";
            c.glfwSetWindowTitle(window, title.ptr);
        }

        // Block edit: left-click destroy, right-click place (edge-triggered).
        const left = c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_LEFT) == c.GLFW_PRESS;
        const right = c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_RIGHT) == c.GLFW_PRESS;
        if ((left and !left_down) or (right and !right_down)) {
            const dir = cam.front();
            if (pick_mod.raycast(&pickSolid, cam.position, dir, 8)) |hit| {
                if (left) {
                    if (try manager.editAndRemesh(hit.x, hit.y, hit.z, .air)) {
                        std.debug.print("destroyed ({d},{d},{d})\n", .{ hit.x, hit.y, hit.z });
                    }
                } else {
                    const px = hit.x + hit.nx;
                    const py = hit.y + hit.ny;
                    const pz = hit.z + hit.nz;
                    if (!pickSolid(px, py, pz)) {
                        const place_type = hotbar_blocks[selected_slot];
                        if (try manager.editAndRemesh(px, py, pz, place_type)) {
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
