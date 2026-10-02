const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const shader = @import("shader.zig");

pub const UIVertex = extern struct {
    position: [2]f32,
    color: [4]f32,
};

pub const UIRenderer = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    program: c.GLuint,

    const vert_src =
        \\#version 330 core
        \\layout (location = 0) in vec2 aPos;
        \\layout (location = 1) in vec4 aColor;
        \\out vec4 vColor;
        \\void main() {
        \\    vColor = aColor;
        \\    gl_Position = vec4(aPos, 0.0, 1.0);
        \\}
    ;

    const frag_src =
        \\#version 330 core
        \\in vec4 vColor;
        \\out vec4 FragColor;
        \\void main() {
        \\    FragColor = vColor;
        \\}
    ;

    pub fn init(allocator: std.mem.Allocator) !UIRenderer {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);

        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);

        // Max 128 UI vertices
        c.glBufferData(c.GL_ARRAY_BUFFER, 128 * @sizeOf(UIVertex), null, c.GL_DYNAMIC_DRAW);

        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(UIVertex), @ptrFromInt(0));

        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 4, c.GL_FLOAT, c.GL_FALSE, @sizeOf(UIVertex), @ptrFromInt(@sizeOf([2]f32)));

        c.glBindVertexArray(0);

        const program = try shader.createProgram(allocator, vert_src, frag_src);

        return .{
            .vao = vao,
            .vbo = vbo,
            .program = program,
        };
    }

    pub fn deinit(self: *UIRenderer) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteProgram(self.program);
    }

    /// Render crosshair and hotbar block indicators.
    /// screen aspect = width / height.
    pub fn draw(self: *UIRenderer, aspect: f32, selected_slot: usize) void {
        var verts: [64]UIVertex = undefined;
        var count: usize = 0;

        // 1. Crosshair in screen center: two quads (horizontal and vertical bars)
        const ch_thickness: f32 = 0.003;
        const ch_len_y: f32 = 0.025;
        const ch_len_x: f32 = ch_len_y / aspect;
        const ch_th_x: f32 = ch_thickness / aspect;
        const crosshair_color = [4]f32{ 1.0, 1.0, 1.0, 0.85 };

        // Horizontal bar (2 triangles = 6 verts)
        verts[count] = .{ .position = .{ -ch_len_x, -ch_thickness }, .color = crosshair_color };
        verts[count + 1] = .{ .position = .{ ch_len_x, -ch_thickness }, .color = crosshair_color };
        verts[count + 2] = .{ .position = .{ ch_len_x, ch_thickness }, .color = crosshair_color };
        verts[count + 3] = .{ .position = .{ -ch_len_x, -ch_thickness }, .color = crosshair_color };
        verts[count + 4] = .{ .position = .{ ch_len_x, ch_thickness }, .color = crosshair_color };
        verts[count + 5] = .{ .position = .{ -ch_len_x, ch_thickness }, .color = crosshair_color };
        count += 6;

        // Vertical bar (2 triangles = 6 verts)
        verts[count] = .{ .position = .{ -ch_th_x, -ch_len_y }, .color = crosshair_color };
        verts[count + 1] = .{ .position = .{ ch_th_x, -ch_len_y }, .color = crosshair_color };
        verts[count + 2] = .{ .position = .{ ch_th_x, ch_len_y }, .color = crosshair_color };
        verts[count + 3] = .{ .position = .{ -ch_th_x, -ch_len_y }, .color = crosshair_color };
        verts[count + 4] = .{ .position = .{ ch_th_x, ch_len_y }, .color = crosshair_color };
        verts[count + 5] = .{ .position = .{ -ch_th_x, ch_len_y }, .color = crosshair_color };
        count += 6;

        // 2. Hotbar at bottom center (4 slots: Stone, Dirt, Grass, Water)
        const slot_w: f32 = 0.055 / aspect;
        const slot_h: f32 = 0.055;
        const spacing: f32 = 0.012 / aspect;
        const base_y: f32 = -0.92;
        const total_w = 4.0 * slot_w + 3.0 * spacing;
        const start_x = -total_w / 2.0;

        const slot_colors = [4][4]f32{
            .{ 0.6, 0.6, 0.62, 0.9 }, // Stone
            .{ 0.55, 0.35, 0.2, 0.9 }, // Dirt
            .{ 0.25, 0.75, 0.25, 0.9 }, // Grass
            .{ 0.2, 0.45, 0.85, 0.9 }, // Water
        };

        var i: usize = 0;
        while (i < 4) : (i += 1) {
            const x0 = start_x + @as(f32, @floatFromInt(i)) * (slot_w + spacing);
            const x1 = x0 + slot_w;
            const y0 = base_y;
            const y1 = base_y + slot_h;

            const is_sel = (i == selected_slot);
            const color = if (is_sel) [4]f32{ 1.0, 1.0, 1.0, 1.0 } else slot_colors[i];

            verts[count] = .{ .position = .{ x0, y0 }, .color = color };
            verts[count + 1] = .{ .position = .{ x1, y0 }, .color = color };
            verts[count + 2] = .{ .position = .{ x1, y1 }, .color = color };
            verts[count + 3] = .{ .position = .{ x0, y0 }, .color = color };
            verts[count + 4] = .{ .position = .{ x1, y1 }, .color = color };
            verts[count + 5] = .{ .position = .{ x0, y1 }, .color = color };
            count += 6;
        }

        c.glDisable(c.GL_DEPTH_TEST);
        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

        c.glUseProgram(self.program);
        c.glBindVertexArray(self.vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @intCast(count * @sizeOf(UIVertex)), &verts);
        c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(count));

        c.glEnable(c.GL_DEPTH_TEST);
        c.glDisable(c.GL_BLEND);
    }
};

test "ui vertex layout" {
    try std.testing.expectEqual(@sizeOf(UIVertex), 24);
}
