const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});

/// A GPU-side mesh: vertex array object + vertex buffer + element buffer.
pub const Mesh = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,
    vertex_count: usize,
    index_count: usize,

    pub fn init(vertices: []const u8, indices: []const u8) Mesh {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;
        var ebo: c.GLuint = 0;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glGenBuffers(1, &ebo);

        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(vertices.len), vertices.ptr, c.GL_STATIC_DRAW);

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(indices.len), indices.ptr, c.GL_STATIC_DRAW);

        // Position attribute (vec3)
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(0));

        // Color attribute (vec3)
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vertex), @ptrFromInt(@sizeOf([3]f32)));

        return .{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .vertex_count = vertices.len / @sizeOf(Vertex),
            .index_count = indices.len / @sizeOf(u32),
        };
    }

    pub fn deinit(self: *Mesh) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteBuffers(1, &self.ebo);
    }

    pub fn draw(self: *Mesh) void {
        c.glBindVertexArray(self.vao);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(self.index_count), c.GL_UNSIGNED_INT, @ptrFromInt(0));
    }
};

/// A vertex with position and color.
pub const Vertex = extern struct {
    position: [3]f32,
    color: [3]f32,
};

/// Create a simple triangle mesh.
pub fn createTriangle(allocator: std.mem.Allocator) !Mesh {
    _ = allocator;
    const vertices = [_]Vertex{
        .{ .position = .{ -0.5, -0.5, 0.0 }, .color = .{ 1.0, 0.0, 0.0 } },
        .{ .position = .{  0.5, -0.5, 0.0 }, .color = .{ 0.0, 1.0, 0.0 } },
        .{ .position = .{  0.0,  0.5, 0.0 }, .color = .{ 0.0, 0.0, 1.0 } },
    };

    const indices = [_]u32{ 0, 1, 2 };

    return Mesh.init(
        std.mem.asBytes(&vertices),
        std.mem.asBytes(&indices),
    );
}

test "Vertex is 24 bytes" {
    try std.testing.expectEqual(@sizeOf(Vertex), 24);
}
