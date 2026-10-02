const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});
const math = @import("../math.zig");
const shader = @import("../renderer/shader.zig");
const texture = @import("../renderer/texture.zig");
const client_mod = @import("client.zig");

pub const PlayerVertex = extern struct {
    pos: [3]f32,
    normal: [3]f32,
    uv: [2]f32,
    ao: f32, // 1.0 for player meshes
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
        c.glVertexAttribPointer(2, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(PlayerVertex), @ptrFromInt(@sizeOf([3]f32) + @sizeOf([3]f32)));

        c.glEnableVertexAttribArray(3);
        c.glVertexAttribPointer(3, 1, c.GL_FLOAT, c.GL_FALSE, @sizeOf(PlayerVertex), @ptrFromInt(@sizeOf([3]f32) + @sizeOf([3]f32) + @sizeOf([2]f32)));

        c.glBindVertexArray(0);

        const program = try shader.createProgram(allocator, shader.chunk_vert, shader.chunk_frag);

        return .{
            .vao = vao,
            .vbo = vbo,
            .ebo = ebo,
            .program = program,
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

    pub fn drawPlayers(self: *PlayerRenderer, remotes: []const client_mod.RemotePlayer, view_proj: math.Mat4, sun_dir: math.Vec3) !void {
        var active_count: usize = 0;
        for (remotes) |r| {
            if (r.active) active_count += 1;
        }
        if (active_count == 0) return;

        var vertices = std.ArrayList(PlayerVertex).empty;
        defer vertices.deinit(self.allocator);
        var indices = std.ArrayList(u32).empty;
        defer indices.deinit(self.allocator);

        for (remotes) |r| {
            if (r.active) {
                try appendPlayerMesh(self.allocator, &vertices, &indices, r);
            }
        }

        if (indices.items.len == 0) return;

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @intCast(vertices.items.len * @sizeOf(PlayerVertex)),
            vertices.items.ptr,
            c.GL_DYNAMIC_DRAW,
        );

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.ebo);
        c.glBufferData(
            c.GL_ELEMENT_ARRAY_BUFFER,
            @intCast(indices.items.len * @sizeOf(u32)),
            indices.items.ptr,
            c.GL_DYNAMIC_DRAW,
        );

        c.glUseProgram(self.program);
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        shader.setUniformInt(self.program, "u_texture", 0);

        var vp = view_proj;
        shader.setUniformMat4(self.program, "u_mvp", vp.ptr());
        shader.setUniformVec3(self.program, "u_light_dir", sun_dir.x, sun_dir.y, sun_dir.z);

        c.glBindVertexArray(self.vao);
        c.glDrawElements(c.GL_TRIANGLES, @intCast(indices.items.len), c.GL_UNSIGNED_INT, @ptrFromInt(0));
        c.glBindVertexArray(0);
    }
};

fn appendBox(
    allocator: std.mem.Allocator,
    verts: *std.ArrayList(PlayerVertex),
    inds: *std.ArrayList(u32),
    center: math.Vec3,
    size: math.Vec3,
    yaw: f32,
    base_pos: math.Vec3,
    uv_face: [4][2]f32,
    uv_other: [4][2]f32,
) !void {
    const half = math.Vec3.init(size.x * 0.5, size.y * 0.5, size.z * 0.5);

    const face_signs = [6][4][3]f32{
        // Front (+Z)
        .{ .{ -1, -1, 1 }, .{ 1, -1, 1 }, .{ 1, 1, 1 }, .{ -1, 1, 1 } },
        // Back (-Z)
        .{ .{ 1, -1, -1 }, .{ -1, -1, -1 }, .{ -1, 1, -1 }, .{ 1, 1, -1 } },
        // Top (+Y)
        .{ .{ -1, 1, 1 }, .{ 1, 1, 1 }, .{ 1, 1, -1 }, .{ -1, 1, -1 } },
        // Bottom (-Y)
        .{ .{ -1, -1, -1 }, .{ 1, -1, -1 }, .{ 1, -1, 1 }, .{ -1, -1, 1 } },
        // Right (+X)
        .{ .{ 1, -1, 1 }, .{ 1, -1, -1 }, .{ 1, 1, -1 }, .{ 1, 1, 1 } },
        // Left (-X)
        .{ .{ -1, -1, -1 }, .{ -1, -1, 1 }, .{ -1, 1, 1 }, .{ -1, 1, -1 } },
    };
    const face_norms = [6][3]f32{
        .{ 0, 0, 1 },
        .{ 0, 0, -1 },
        .{ 0, 1, 0 },
        .{ 0, -1, 0 },
        .{ 1, 0, 0 },
        .{ -1, 0, 0 },
    };

    const cos_y = @cos(yaw);
    const sin_y = @sin(yaw);

    var f: usize = 0;
    while (f < 6) : (f += 1) {
        const base_idx: u32 = @intCast(verts.items.len);
        const uv = if (f == 0) uv_face else uv_other;

        const norm = face_norms[f];
        const r_nx = norm[0] * cos_y + norm[2] * sin_y;
        const r_nz = -norm[0] * sin_y + norm[2] * cos_y;
        const r_normal = [3]f32{ r_nx, norm[1], r_nz };

        var i: usize = 0;
        while (i < 4) : (i += 1) {
            const sign = face_signs[f][i];
            const lx = center.x + half.x * sign[0];
            const ly = center.y + half.y * sign[1];
            const lz = center.z + half.z * sign[2];

            const rx = lx * cos_y + lz * sin_y;
            const rz = -lx * sin_y + lz * cos_y;

            try verts.append(allocator, .{
                .pos = [3]f32{ base_pos.x + rx, base_pos.y + ly, base_pos.z + rz },
                .normal = r_normal,
                .uv = uv[i],
                .ao = 1.0,
            });
        }

        try inds.append(allocator, base_idx);
        try inds.append(allocator, base_idx + 1);
        try inds.append(allocator, base_idx + 2);
        try inds.append(allocator, base_idx);
        try inds.append(allocator, base_idx + 2);
        try inds.append(allocator, base_idx + 3);
    }
}

pub fn appendPlayerMesh(allocator: std.mem.Allocator, verts: *std.ArrayList(PlayerVertex), inds: *std.ArrayList(u32), p: client_mod.RemotePlayer) !void {
    const uv_face = texture.getTileUV(1, 2); // Mob Face tile
    const uv_shirt = texture.getTileUV(0, 1); // Water/Blue cloth tile
    const uv_pants = texture.getTileUV(2, 0); // Dirt/Brown pants tile

    const pos = math.Vec3.init(p.x, p.y, p.z);
    const leg_swing = @sin(p.anim_time) * 0.15;

    // 1. Head: 0.4 x 0.4 x 0.4 at y = 1.6
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(0, 1.6, 0),
        math.Vec3.init(0.4, 0.4, 0.4),
        p.yaw,
        pos,
        uv_face,
        uv_face,
    );

    // 2. Torso: 0.5 x 0.7 x 0.25 at y = 1.05
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(0, 1.05, 0),
        math.Vec3.init(0.5, 0.7, 0.25),
        p.yaw,
        pos,
        uv_shirt,
        uv_shirt,
    );

    // 3. Left Leg: 0.2 x 0.7 x 0.2 at y = 0.35, swinging forward/back
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(-0.13, 0.35, leg_swing),
        math.Vec3.init(0.2, 0.7, 0.2),
        p.yaw,
        pos,
        uv_pants,
        uv_pants,
    );

    // 4. Right Leg: 0.2 x 0.7 x 0.2 at y = 0.35, opposite swing
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(0.13, 0.35, -leg_swing),
        math.Vec3.init(0.2, 0.7, 0.2),
        p.yaw,
        pos,
        uv_pants,
        uv_pants,
    );
}

test "appendPlayerMesh vertex and index count" {
    var verts = std.ArrayList(PlayerVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const player = client_mod.RemotePlayer{
        .id = 1,
        .x = 0,
        .y = 0,
        .z = 0,
        .active = true,
    };

    try appendPlayerMesh(std.testing.allocator, &verts, &inds, player);

    // 4 boxes (head, torso, 2 legs) * 6 faces * 4 vertices = 96 vertices
    // 4 boxes * 6 faces * 6 indices = 144 indices
    try std.testing.expectEqual(@as(usize, 96), verts.items.len);
    try std.testing.expectEqual(@as(usize, 144), inds.items.len);
}
