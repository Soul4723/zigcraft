const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const camera_mod = @import("camera.zig");
const math = @import("math.zig");
const chunk_manager_mod = @import("chunk_manager.zig");

const window_width = 1280;
const window_height = 720;
const window_title = "Zigcraft";

pub fn main() !void {
    std.debug.print("zigcraft v0.0.3\n", .{});

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

    // Demo world: 3x3 terrain chunks (seed 1337) via chunk manager.
    var manager = try chunk_manager_mod.ChunkManager.init(std.heap.page_allocator, 3, 0, 0, 1337);
    defer manager.deinit();

    // Camera setup — pulled back so the chunk grid fills the view.
    var cam = camera_mod.Camera.init();
    cam.position = math.Vec3.init(24, 20, 48);
    cam.yaw = -std.math.pi / 2.0 - 0.35;
    cam.pitch = -0.3;

    // Timing
    var last_time = c.glfwGetTime();
    var frame_count: u64 = 0;

    // Mouse tracking
    var last_x: f64 = @floatFromInt(window_width / 2);
    var last_y: f64 = @floatFromInt(window_height / 2);
    var first_mouse = true;

    std.debug.print("ready. 3x3 terrain + frustum culling. WASD to move, mouse to look, ESC to close.\n", .{});

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        // Delta time
        const current_time = c.glfwGetTime();
        const dt: f32 = @floatCast(current_time - last_time);
        last_time = current_time;

        // Keyboard input: poll each movement key and forward to camera.
        // processKey ignores non-press actions, so this is safe to call
        // unconditionally for every key each frame.
        cam.processKey(c.GLFW_KEY_W, c.glfwGetKey(window, c.GLFW_KEY_W), dt);
        cam.processKey(c.GLFW_KEY_S, c.glfwGetKey(window, c.GLFW_KEY_S), dt);
        cam.processKey(c.GLFW_KEY_A, c.glfwGetKey(window, c.GLFW_KEY_A), dt);
        cam.processKey(c.GLFW_KEY_D, c.glfwGetKey(window, c.GLFW_KEY_D), dt);
        cam.processKey(c.GLFW_KEY_SPACE, c.glfwGetKey(window, c.GLFW_KEY_SPACE), dt);
        cam.processKey(c.GLFW_KEY_LEFT_SHIFT, c.glfwGetKey(window, c.GLFW_KEY_LEFT_SHIFT), dt);

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

        // Build MVP: projection * view (model is identity — mesh is in world coords)
        const aspect: f32 = 1280.0 / 720.0;
        const proj = cam.projectionMatrix(aspect);
        const view = cam.viewMatrix();
        const mvp = math.Mat4.mul(proj, view);

        // Render
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        const stats = manager.draw(mvp);
        frame_count += 1;
        if (frame_count % 300 == 0) {
            std.debug.print("chunks drawn={d} culled={d}\n", .{ stats.drawn, stats.culled });
        }

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();

        if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS) {
            c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
        }
    }

    std.debug.print("shutting down\n", .{});
}
