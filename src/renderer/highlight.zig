const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const shader = @import("shader.zig");

/// Raw 16-float MVP pointer: avoids importing math.zig (cross-dir test rule).
pub const MvpPtr = [*c]const f32;

/// GL line-box renderer: draws a unit-cube wireframe around the aimed block
/// plus an optional quads highlight on the aimed face. Single VAO/VBO/EBO,
/// rewritten per frame (tiny: 8 verts / 24 indices for box + 4/6 for face).
pub const HighlightRenderer = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,
    program: c.GLuint,

    const box_edges = [24]u32{ 0, 1, 1, 3, 3, 2, 2, 0, 4, 5, 5, 7, 7, 6, 6, 4, 0, 4, 1, 5, 2, 6, 3, 7 };

    pub fn init(allocator: std.mem.Allocator) !HighlightRenderer {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;
        var ebo: c.GLuint = 0;
        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glGenBuffers(1, &ebo);
        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, 12 * @sizeOf([3]f32), null, c.GL_DYNAMIC_DRAW);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        var edges = box_edges;
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(edges)), &edges, c.GL_STATIC_DRAW);
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf([3]f32), @ptrFromInt(0));
        c.glBindVertexArray(0);
        const program = try shader.createProgram(allocator, shader.line_vert, shader.line_frag);
        return .{ .vao = vao, .vbo = vbo, .ebo = ebo, .program = program };
    }

    pub fn deinit(self: *HighlightRenderer) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteBuffers(1, &self.ebo);
        c.glDeleteProgram(self.program);
    }

    /// 8 corners of block (bx,by,bz)..(bx+1,by+1,bz+1), inset by eps to avoid z-fight.
    pub fn boxCorners(bx: i32, by: i32, bz: i32, eps: f32) [8][3]f32 {
        const x0: f32 = @as(f32, @floatFromInt(bx)) + eps;
        const y0: f32 = @as(f32, @floatFromInt(by)) + eps;
        const z0: f32 = @as(f32, @floatFromInt(bz)) + eps;
        const x1: f32 = @as(f32, @floatFromInt(bx + 1)) - eps;
        const y1: f32 = @as(f32, @floatFromInt(by + 1)) - eps;
        const z1: f32 = @as(f32, @floatFromInt(bz + 1)) - eps;
        return .{
            .{ x0, y0, z0 }, .{ x1, y0, z0 }, .{ x0, y1, z0 }, .{ x1, y1, z0 },
            .{ x0, y0, z1 }, .{ x1, y0, z1 }, .{ x0, y1, z1 }, .{ x1, y1, z1 },
        };
    }

    /// Draw wireframe box around (bx,by,bz). Color pulses white/yellow.
    pub fn draw(self: *HighlightRenderer, mvp: MvpPtr, bx: i32, by: i32, bz: i32, pulse: f32) void {
        const corners = boxCorners(bx, by, bz, 0.002);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @sizeOf(@TypeOf(corners)), &corners);
        c.glUseProgram(self.program);
        shader.setUniformMat4(self.program, "u_mvp", mvp);
        const t = @min(1.0, @max(0.0, pulse));
        shader.setUniformVec3(self.program, "u_color", 1.0, 0.85 + 0.15 * t, 0.3 + 0.5 * (1.0 - t));
        c.glBindVertexArray(self.vao);
        c.glDrawElements(c.GL_LINES, 24, c.GL_UNSIGNED_INT, null);
        c.glBindVertexArray(0);
        c.glUseProgram(0);
    }
};

test "box corners span unit cube with inset" {
    const cs = HighlightRenderer.boxCorners(10, 5, -3, 0.002);
    try std.testing.expect(cs[0][0] < cs[1][0]);
    try std.testing.expect(cs[0][1] < cs[2][1]);
    try std.testing.expect(cs[0][2] < cs[4][2]);
    try std.testing.expectApproxEqAbs(cs[1][0] - cs[0][0], 1.0 - 0.004, 0.0001);
    try std.testing.expectApproxEqAbs(cs[7][1] - cs[0][1], 1.0 - 0.004, 0.0001);
}

test "box edge index table has 12 edges" {
    try std.testing.expectEqual(HighlightRenderer.box_edges.len, 24);
    for (HighlightRenderer.box_edges) |idx| {
        try std.testing.expect(idx < 8);
    }
}
