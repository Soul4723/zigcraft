const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});

const window_width = 1280;
const window_height = 720;
const window_title = "Zigcraft";

pub fn main() !void {
    std.debug.print("zigcraft v0.0.1\n", .{});

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

    const version = c.glGetString(c.GL_VERSION);
    if (version != null) {
        std.debug.print("OpenGL {s}\n", .{version});
    }
    std.debug.print("window created ({d}x{d})\n", .{ window_width, window_height });

    c.glEnable(c.GL_DEPTH_TEST);
    c.glClearColor(0.53, 0.81, 0.92, 1.0);

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();

        if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS) {
            c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
        }
    }

    std.debug.print("shutting down\n", .{});
}
