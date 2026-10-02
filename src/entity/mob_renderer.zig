const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});
const math = @import("../math.zig");
const shader = @import("../renderer/shader.zig");
const texture = @import("../renderer/texture.zig");
const mob_mod = @import("mob.zig");

pub const MobVertex = extern struct {
    pos: [3]f32,
    normal: [3]f32,
    uv: [2]f32,
    ao: f32, // constant 1.0 for mobs
};

pub const MobRenderer = struct {
    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,
    program: c.GLuint,
    texture: c.GLuint,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, atlas_texture: c.GLuint) !MobRenderer {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;
        var ebo: c.GLuint = 0;

        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glGenBuffers(1, &ebo);

        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);

        // Attribute layout matches chunk shader: pos, normal, uv, ao
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(MobVertex), @ptrFromInt(0));

        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(MobVertex), @ptrFromInt(@sizeOf([3]f32)));

        c.glEnableVertexAttribArray(2);
        c.glVertexAttribPointer(2, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(MobVertex), @ptrFromInt(@sizeOf([3]f32) + @sizeOf([3]f32)));

        c.glEnableVertexAttribArray(3);
        c.glVertexAttribPointer(3, 1, c.GL_FLOAT, c.GL_FALSE, @sizeOf(MobVertex), @ptrFromInt(@sizeOf([3]f32) + @sizeOf([3]f32) + @sizeOf([2]f32)));

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

    pub fn deinit(self: *MobRenderer) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteBuffers(1, &self.ebo);
        c.glDeleteProgram(self.program);
    }

    /// Render all active mobs
    pub fn drawMobs(self: *MobRenderer, mobs: []const mob_mod.Mob, view_proj: math.Mat4, sun_dir: math.Vec3) !void {
        if (mobs.len == 0) return;

        var vertices = std.ArrayList(MobVertex).empty;
        defer vertices.deinit(self.allocator);
        var indices = std.ArrayList(u32).empty;
        defer indices.deinit(self.allocator);

        for (mobs) |mob| {
            try appendMobMesh(self.allocator, &vertices, &indices, mob);
        }

        if (indices.items.len == 0) return;

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferData(
            c.GL_ARRAY_BUFFER,
            @intCast(vertices.items.len * @sizeOf(MobVertex)),
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

        // Mobs are generated in world space directly, so model matrix is identity
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
    verts: *std.ArrayList(MobVertex),
    inds: *std.ArrayList(u32),
    center: math.Vec3,
    size: math.Vec3,
    yaw: f32,
    mob_center: math.Vec3,
    uv_front: [4][2]f32,
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
        const uv = if (f == 0) uv_front else uv_other;

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
                .pos = [3]f32{ mob_center.x + rx, mob_center.y + ly, mob_center.z + rz },
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

pub fn appendMobMesh(allocator: std.mem.Allocator, verts: *std.ArrayList(MobVertex), inds: *std.ArrayList(u32), mob: mob_mod.Mob) !void {
    const uv_wool = texture.getTileUV(0, 2);
    const uv_face = texture.getTileUV(1, 2);

    // Sheep geometry in local coordinate frame (Z = forward, Y = up, X = right)
    // 1. Body: 0.5 x 0.45 x 0.7, centered at (0, 0.45, 0)
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(0, 0.45, 0),
        math.Vec3.init(0.5, 0.45, 0.7),
        mob.yaw,
        mob.pos,
        uv_wool,
        uv_wool,
    );

    // 2. Head: 0.35 x 0.35 x 0.35, centered forward and up at (0, 0.65, 0.45)
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(0, 0.65, 0.45),
        math.Vec3.init(0.35, 0.35, 0.35),
        mob.yaw,
        mob.pos,
        uv_face,
        uv_wool,
    );

    // 3. Legs: 4 legs with alternating swing animation
    const leg_swing = @sin(mob.anim_time) * 0.12;

    // Front-Left (x = -0.16, z = 0.22)
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(-0.16, 0.15, 0.22 + leg_swing),
        math.Vec3.init(0.14, 0.3, 0.14),
        mob.yaw,
        mob.pos,
        uv_wool,
        uv_wool,
    );
    // Front-Right (x = 0.16, z = 0.22)
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(0.16, 0.15, 0.22 - leg_swing),
        math.Vec3.init(0.14, 0.3, 0.14),
        mob.yaw,
        mob.pos,
        uv_wool,
        uv_wool,
    );
    // Back-Left (x = -0.16, z = -0.22)
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(-0.16, 0.15, -0.22 - leg_swing),
        math.Vec3.init(0.14, 0.3, 0.14),
        mob.yaw,
        mob.pos,
        uv_wool,
        uv_wool,
    );
    // Back-Right (x = 0.16, z = -0.22)
    try appendBox(
        allocator,
        verts,
        inds,
        math.Vec3.init(0.16, 0.15, -0.22 + leg_swing),
        math.Vec3.init(0.14, 0.3, 0.14),
        mob.yaw,
        mob.pos,
        uv_wool,
        uv_wool,
    );
}

test "appendMobMesh generates correct vertex and index counts" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const mob = mob_mod.Mob.init(.sheep, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, mob);

    // 6 boxes (body, head, 4 legs) * 6 faces * 4 vertices = 144 vertices
    // 6 boxes * 6 faces * 6 indices = 216 indices
    try std.testing.expectEqual(@as(usize, 144), verts.items.len);
    try std.testing.expectEqual(@as(usize, 216), inds.items.len);
}
