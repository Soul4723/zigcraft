const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const chunk_mesh = @import("world/chunk_mesh.zig");
const shader = @import("renderer/shader.zig");
const texture = @import("renderer/texture.zig");
const math = @import("math.zig");

/// Render a chunk mesh using a simple textured shader with ambient occlusion and dynamic lighting.
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

        // position (loc 0)
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(chunk_mesh.Vertex), @ptrFromInt(0));

        // normal (loc 1)
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(chunk_mesh.Vertex), @ptrFromInt(@sizeOf([3]f32)));

        // tex_coord (loc 2)
        c.glEnableVertexAttribArray(2);
        c.glVertexAttribPointer(2, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(chunk_mesh.Vertex), @ptrFromInt(@sizeOf([3]f32) + @sizeOf([3]f32)));

        // ao (loc 3)
        c.glEnableVertexAttribArray(3);
        c.glVertexAttribPointer(3, 1, c.GL_FLOAT, c.GL_FALSE, @sizeOf(chunk_mesh.Vertex), @ptrFromInt(@sizeOf([3]f32) + @sizeOf([3]f32) + @sizeOf([2]f32)));

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

    /// Replace GPU buffers with a new mesh. Keeps VAO/program/texture.
    pub fn remesh(self: *ChunkRenderer, mesh: *const chunk_mesh.Mesh) void {
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        const vertex_byte_size = mesh.vertices.len * @sizeOf(chunk_mesh.Vertex);
        if (vertex_byte_size > 0) {
            c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(vertex_byte_size), mesh.vertices.ptr, c.GL_STATIC_DRAW);
        } else {
            c.glBufferData(c.GL_ARRAY_BUFFER, 0, null, c.GL_STATIC_DRAW);
        }
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.ebo);
        const index_byte_size = mesh.indices.len * @sizeOf(u32);
        if (index_byte_size > 0) {
            c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(index_byte_size), mesh.indices.ptr, c.GL_STATIC_DRAW);
        } else {
            c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, 0, null, c.GL_STATIC_DRAW);
        }
        self.index_count = mesh.indices.len;
    }

    pub fn deinit(self: *ChunkRenderer) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteBuffers(1, &self.ebo);
        c.glDeleteProgram(self.program);
        c.glDeleteTextures(1, &self.texture);
    }

    pub fn draw(self: *ChunkRenderer, mvp_ptr: [*c]const f32, sun_dir: math.Vec3) void {
        if (self.index_count == 0) return;
        c.glEnable(c.GL_BLEND);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
        c.glUseProgram(self.program);
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        shader.setUniformInt(self.program, "u_texture", 0);
        shader.setUniformMat4(self.program, "u_mvp", mvp_ptr);
        shader.setUniformVec3(self.program, "u_light_dir", sun_dir.x, sun_dir.y, sun_dir.z);
        c.glBindVertexArray(self.vao);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(self.index_count), c.GL_UNSIGNED_INT, @ptrFromInt(0));
        c.glDisable(c.GL_BLEND);
    }
};

test "chunk renderer struct layout" {
    try std.testing.expect(@sizeOf(ChunkRenderer) >= 5 * 4);
}
