const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const chunk_mesh = @import("world/chunk_mesh.zig");
const shader = @import("renderer/shader.zig");
const texture = @import("renderer/texture.zig");

/// Render a chunk mesh using a simple textured shader.
pub const ChunkRenderer = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,
    index_count: usize,
    program: c.GLuint,
    texture: c.GLuint,

    pub fn init(allocator: std.mem.Allocator, mesh: *const chunk_mesh.Mesh) !ChunkRenderer {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;
        var ebo: c.GLuint = 0;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glGenBuffers(1, &ebo);

        c.glBindVertexArray(vao);

        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        const vertex_byte_size = mesh.vertices.len * @sizeOf(chunk_mesh.Vertex);
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(vertex_byte_size), mesh.vertices.ptr, c.GL_STATIC_DRAW);

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
        const index_byte_size = mesh.indices.len * @sizeOf(u32);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(index_byte_size), mesh.indices.ptr, c.GL_STATIC_DRAW);

        // position
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(chunk_mesh.Vertex), @ptrFromInt(0));

        // normal
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(chunk_mesh.Vertex), @ptrFromInt(@sizeOf([3]f32)));

        // tex_coord
        c.glEnableVertexAttribArray(2);
        c.glVertexAttribPointer(2, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(chunk_mesh.Vertex), @ptrFromInt(@sizeOf([3]f32) + @sizeOf([3]f32)));

        c.glBindVertexArray(0);

        const program = try shader.createProgram(
            allocator,
            shader.chunk_vert,
            shader.chunk_frag,
        );

        const tex = texture.createBlockTexture();

        return .{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .index_count = mesh.indices.len,
            .program = program,
            .texture = tex,
        };
    }

    pub fn deinit(self: *ChunkRenderer) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteBuffers(1, &self.ebo);
        c.glDeleteProgram(self.program);
        c.glDeleteTextures(1, &self.texture);
    }

    pub fn draw(self: *ChunkRenderer, mvp_ptr: [*c]const f32) void {
        c.glUseProgram(self.program);
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        shader.setUniformInt(self.program, "u_texture", 0);
        shader.setUniformMat4(self.program, "u_mvp", mvp_ptr);
        c.glBindVertexArray(self.vao);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(self.index_count), c.GL_UNSIGNED_INT, @ptrFromInt(0));
    }
};

test "chunk renderer struct layout" {
    try std.testing.expect(@sizeOf(ChunkRenderer) >= 5 * 4);
}
