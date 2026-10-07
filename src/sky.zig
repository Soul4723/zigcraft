const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const shader = @import("renderer/shader.zig");
const math = @import("math.zig");

const cube_verts = [_][3]f32{
    .{ -1, -1, -1 }, .{ 1, -1, -1 }, .{ 1, 1, -1 }, .{ -1, 1, -1 },
    .{ -1, -1, 1 },  .{ 1, -1, 1 },  .{ 1, 1, 1 },  .{ -1, 1, 1 },
};
const cube_idx = [_]u32{
    0, 1, 2, 0, 2, 3, // back
    4, 6, 5, 4, 7, 6, // front
    0, 4, 5, 0, 5, 1, // bottom
    3, 2, 6, 3, 6, 7, // top
    1, 5, 6, 1, 6, 2, // right
    0, 3, 7, 0, 7, 4, // left
};

pub const SkyRenderer = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,
    program: c.GLuint,

    pub fn init(allocator: std.mem.Allocator) !SkyRenderer {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;
        var ebo: c.GLuint = 0;
        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glGenBuffers(1, &ebo);
        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(cube_verts.len * @sizeOf([3]f32)), &cube_verts, c.GL_STATIC_DRAW);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(cube_idx.len * @sizeOf(u32)), &cube_idx, c.GL_STATIC_DRAW);
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf([3]f32), @ptrFromInt(0));
        c.glBindVertexArray(0);
        const program = try shader.createProgram(allocator, shader.sky_vert, shader.sky_frag);
        return .{ .vao = vao, .vbo = vbo, .ebo = ebo, .program = program };
    }

    pub fn deinit(self: *SkyRenderer) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteBuffers(1, &self.ebo);
        c.glDeleteProgram(self.program);
    }

    /// Render sky dome with interpolated zenith/horizon colors based on sun angle.
    pub fn draw(self: *SkyRenderer, view_proj: math.Mat4, cam_pos: math.Vec3, top_color: math.Vec3, horizon_color: math.Vec3) void {
        const model = math.Mat4.translate(cam_pos);
        var mvp = math.Mat4.mul(view_proj, model);
        c.glDepthMask(c.GL_FALSE);
        c.glUseProgram(self.program);
        shader.setUniformMat4(self.program, "u_view_proj", mvp.ptr());
        shader.setUniformVec3(self.program, "u_top", top_color.x, top_color.y, top_color.z);
        shader.setUniformVec3(self.program, "u_horizon", horizon_color.x, horizon_color.y, horizon_color.z);
        c.glBindVertexArray(self.vao);
        c.glDrawElements(c.GL_TRIANGLES, 36, c.GL_UNSIGNED_INT, @ptrFromInt(0));
        c.glDepthMask(c.GL_TRUE);
    }
};

test "sky cube has 36 indices" {
    try std.testing.expectEqual(cube_idx.len, 36);
}

pub const day_length_scale: f32 = 0.05;
pub const dawn_angle: f32 = 0.25132741228718347; // pi * 0.08

pub fn advanceTime(t: f32, dt: f32) f32 {
    return t + dt * day_length_scale;
}

pub fn dayFactor(sun_y: f32) f32 {
    return @max(0.0, @min(1.0, (sun_y + 0.2) / 0.8));
}

pub fn timeState(sun_y: f32) []const u8 {
    if (sun_y > 0.1) return "day";
    if (sun_y > -0.1) return "dusk";
    return "night";
}

pub fn isSleepable(sun_y: f32) bool {
    return sun_y < 0.15;
}

test "day factor spans night to day" {
    try std.testing.expectEqual(dayFactor(-1.0), 0.0);
    try std.testing.expectEqual(dayFactor(1.0), 1.0);
    const mid = dayFactor(0.2);
    try std.testing.expect(mid > 0.4 and mid < 0.6);
}

test "time states and sleep window" {
    try std.testing.expectEqualStrings(timeState(0.5), "day");
    try std.testing.expectEqualStrings(timeState(0.0), "dusk");
    try std.testing.expectEqualStrings(timeState(-0.5), "night");
    try std.testing.expect(isSleepable(-0.5));
    try std.testing.expect(!isSleepable(0.5));
}
