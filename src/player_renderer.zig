const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});
const math = @import("math.zig");
const shader = @import("renderer/shader.zig");
const texture = @import("renderer/texture.zig");
const client_mod = @import("net/client.zig");
const RemotePlayer = client_mod.RemotePlayer;

pub const PlayerVertex = extern struct {
    pos: [3]f32,
    normal: [3]f32,
    uv: [2]f32,
    ao: f32, // constant 1.0
};

pub const PlayerRenderer = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,
    program: c.GLuint,
    texture: c.GLuint,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, atlas_texture: c.GLuint) !PlayerRenderer {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;
        var ebo: c.GLuint = 0;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glGenBuffers(1, &ebo);

        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);

        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(PlayerVertex), @ptrFromInt(0));

        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(PlayerVertex), @ptrFromInt(@sizeOf([3]f32)));

        c.glEnableVertexAttribArray(2);
        c.glVertexAttribPointer(2, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(PlayerVertex), @ptrFromInt(@sizeOf([3]f32) * 2));

        c.glEnableVertexAttribArray(3);
        c.glVertexAttribPointer(3, 1, c.GL_FLOAT, c.GL_FALSE, @sizeOf(PlayerVertex), @ptrFromInt(@sizeOf([3]f32) * 2 + @sizeOf([2]f32)));

        c.glBindVertexArray(0);

        const prog = try shader.createProgram(allocator, shader.chunk_vert, shader.chunk_frag);

        return .{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .program = prog,
            .texture = atlas_texture,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PlayerRenderer) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteBuffers(1, &self.ebo);
        c.glDeleteProgram(self.program);
    }

    pub fn drawPlayers(self: *PlayerRenderer, players: []const RemotePlayer, mvp: math.Mat4, sun_dir: math.Vec3) !void {
        var active_count: usize = 0;
        for (players) |p| {
            if (p.active) active_count += 1;
        }
        if (active_count == 0) return;

        var vertices = try std.ArrayList(PlayerVertex).initCapacity(self.allocator, active_count * 144);
        defer vertices.deinit(self.allocator);
        var indices = try std.ArrayList(c.GLuint).initCapacity(self.allocator, active_count * 216);
        defer indices.deinit(self.allocator);

        for (players) |p| {
            if (!p.active) continue;
            self.generatePlayerMesh(&vertices, &indices, p);
        }

        if (vertices.items.len == 0) return;

        c.glBindVertexArray(self.vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(vertices.items.len * @sizeOf(PlayerVertex)), vertices.items.ptr, c.GL_DYNAMIC_DRAW);

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.ebo);
        c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @intCast(indices.items.len * @sizeOf(c.GLuint)), indices.items.ptr, c.GL_DYNAMIC_DRAW);

        c.glUseProgram(self.program);
        var vp = mvp;
        shader.setUniformMat4(self.program, "u_mvp", vp.ptr());
        shader.setUniformVec3(self.program, "u_sun_dir", sun_dir.x, sun_dir.y, sun_dir.z);

        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        shader.setUniformInt(self.program, "u_texture", 0);

        c.glDrawElements(c.GL_TRIANGLES, @intCast(indices.items.len), c.GL_UNSIGNED_INT, null);
        c.glBindVertexArray(0);
    }

    fn generatePlayerMesh(self: *PlayerRenderer, vertices: *std.ArrayList(PlayerVertex), indices: *std.ArrayList(c.GLuint), p: RemotePlayer) void {
        const rad = p.yaw * std.math.pi / 180.0;
        const cos_y = @cos(rad);
        const sin_y = @sin(rad);

        // Body: center at (p.x, p.y + 0.9, p.z), size (0.5, 0.7, 0.3)
        // Texture: wood planks (tile 2, 2)
        const body_uv = texture.getTileUV(2, 2);
        self.addBox(vertices, indices, p.x, p.y + 0.9, p.z, 0.5, 0.7, 0.3, cos_y, sin_y, body_uv);

        // Head: center at (p.x, p.y + 1.5, p.z), size (0.4, 0.4, 0.4)
        // Texture: sheep face (tile 1, 2)
        const head_uv = texture.getTileUV(1, 2);
        self.addBox(vertices, indices, p.x, p.y + 1.5, p.z, 0.4, 0.4, 0.4, cos_y, sin_y, head_uv);

        // Left Leg & Right Leg: (0.2, 0.6, 0.2)
        const leg_uv = texture.getTileUV(3, 0); // stone gray pants/boots
        const leg_sep = 0.14;
        const lx_off = -leg_sep * cos_y;
        const lz_off = leg_sep * sin_y;
        self.addBox(vertices, indices, p.x + lx_off, p.y + 0.3, p.z + lz_off, 0.2, 0.6, 0.2, cos_y, sin_y, leg_uv);
        self.addBox(vertices, indices, p.x - lx_off, p.y + 0.3, p.z - lz_off, 0.2, 0.6, 0.2, cos_y, sin_y, leg_uv);
    }

    fn addBox(
        self: *PlayerRenderer,
        vertices: *std.ArrayList(PlayerVertex),
        indices: *std.ArrayList(c.GLuint),
        cx: f32,
        cy: f32,
        cz: f32,
        sx: f32,
        sy: f32,
        sz: f32,
        cos_y: f32,
        sin_y: f32,
        uvs: [4][2]f32,
    ) void {
        const hx = sx / 2.0;
        const hy = sy / 2.0;
        const hz = sz / 2.0;

        const faces = [6]struct {
            norm: [3]f32,
            corners: [4][3]f32,
        }{
            // Up (+Y)
            .{ .norm = .{ 0, 1, 0 }, .corners = .{ .{ -hx, hy, -hz }, .{ hx, hy, -hz }, .{ hx, hy, hz }, .{ -hx, hy, hz } } },
            // Down (-Y)
            .{ .norm = .{ 0, -1, 0 }, .corners = .{ .{ -hx, -hy, hz }, .{ hx, -hy, hz }, .{ hx, -hy, -hz }, .{ -hx, -hy, -hz } } },
            // North (-Z)
            .{ .norm = .{ 0, 0, -1 }, .corners = .{ .{ hx, -hy, -hz }, .{ -hx, -hy, -hz }, .{ -hx, hy, -hz }, .{ hx, hy, -hz } } },
            // South (+Z)
            .{ .norm = .{ 0, 0, 1 }, .corners = .{ .{ -hx, -hy, hz }, .{ hx, -hy, hz }, .{ hx, hy, hz }, .{ -hx, hy, hz } } },
            // East (+X)
            .{ .norm = .{ 1, 0, 0 }, .corners = .{ .{ hx, -hy, hz }, .{ hx, -hy, -hz }, .{ hx, hy, -hz }, .{ hx, hy, hz } } },
            // West (-X)
            .{ .norm = .{ -1, 0, 0 }, .corners = .{ .{ -hx, -hy, -hz }, .{ -hx, -hy, hz }, .{ -hx, hy, hz }, .{ -hx, hy, -hz } } },
        };

        for (faces) |face| {
            const start_idx: c.GLuint = @intCast(vertices.items.len);
            const rot_nx = face.norm[0] * cos_y + face.norm[2] * sin_y;
            const rot_nz = -face.norm[0] * sin_y + face.norm[2] * cos_y;
            const norm = [3]f32{ rot_nx, face.norm[1], rot_nz };

            for (0..4) |k| {
                const corner = face.corners[k];
                const rx = corner[0] * cos_y + corner[2] * sin_y;
                const rz = -corner[0] * sin_y + corner[2] * cos_y;

                vertices.append(self.allocator, .{
                    .pos = .{ cx + rx, cy + corner[1], cz + rz },
                    .normal = norm,
                    .uv = uvs[k],
                    .ao = 1.0,
                }) catch return;
            }

            indices.append(self.allocator, start_idx + 0) catch return;
            indices.append(self.allocator, start_idx + 1) catch return;
            indices.append(self.allocator, start_idx + 2) catch return;
            indices.append(self.allocator, start_idx + 0) catch return;
            indices.append(self.allocator, start_idx + 2) catch return;
            indices.append(self.allocator, start_idx + 3) catch return;
        }
    }
};

test "player vertex struct size" {
    try std.testing.expectEqual(@sizeOf(PlayerVertex), 36);
}
