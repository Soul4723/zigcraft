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
    emissive: f32, // 0.0; mobs never glow
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

        c.glEnableVertexAttribArray(4);
        c.glVertexAttribPointer(4, 1, c.GL_FLOAT, c.GL_FALSE, @sizeOf(MobVertex), @ptrFromInt(@sizeOf([3]f32) + @sizeOf([3]f32) + @sizeOf([2]f32) + @sizeOf(f32)));

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
    pub fn drawMobs(self: *MobRenderer, mobs: []const mob_mod.Mob, view_proj: math.Mat4, sun_dir: math.Vec3, cam_pos: math.Vec3, is_underwater: bool, is_nether: bool) !void {
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
        shader.setUniformVec3(self.program, "u_chunk_origin", 0, 0, 0);
        shader.setUniformFloat(self.program, "u_lamp_count", 0);
        shader.setUniformFloat(self.program, "u_night", 0);
        shader.setUniformFloat(self.program, "u_underwater", if (is_underwater) 1.0 else 0.0);
        shader.setUniformFloat(self.program, "u_nether", if (is_nether) 1.0 else 0.0);
        shader.setUniformVec3(self.program, "u_cam_pos", cam_pos.x, cam_pos.y, cam_pos.z);

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
                .ao = 1.0, .emissive = 0.0,
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
    const leg_swing = if (mob.in_water) @sin(mob.anim_time * 2.5) * 0.08 else @sin(mob.anim_time) * 0.12;
    // Head bobs up and down when swimming to keep snout out of water
    const head_bob_y: f32 = if (mob.in_water) 0.08 + @sin(mob.anim_time * 4.0) * 0.04 else 0.0;

    switch (mob.mob_type) {
        .sheep => {
            const uv_wool = texture.getTileUV(0, 2);
            const uv_face = texture.getTileUV(1, 2);

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
                math.Vec3.init(0, 0.65 + head_bob_y, 0.45),
                math.Vec3.init(0.35, 0.35, 0.35),
                mob.yaw,
                mob.pos,
                uv_face,
                uv_wool,
            );

            // 3. Legs: 4 legs with alternating swing animation
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
        },
        .pig => {
            const uv_skin = texture.getTileUV(5, 4);
            const uv_face = texture.getTileUV(6, 4);

            // 1. Body: 0.48 x 0.40 x 0.64, centered at (0, 0.36, 0)
            try appendBox(
                allocator,
                verts,
                inds,
                math.Vec3.init(0, 0.36, 0),
                math.Vec3.init(0.48, 0.40, 0.64),
                mob.yaw,
                mob.pos,
                uv_skin,
                uv_skin,
            );

            // 2. Head: 0.34 x 0.32 x 0.34, forward at (0, 0.52, 0.42)
            try appendBox(
                allocator,
                verts,
                inds,
                math.Vec3.init(0, 0.52 + head_bob_y, 0.42),
                math.Vec3.init(0.34, 0.32, 0.34),
                mob.yaw,
                mob.pos,
                uv_face,
                uv_skin,
            );

            // 3. Snout protrusion box: 0.16 x 0.10 x 0.08, at (0, 0.48, 0.61)
            try appendBox(
                allocator,
                verts,
                inds,
                math.Vec3.init(0, 0.48 + head_bob_y, 0.61),
                math.Vec3.init(0.16, 0.10, 0.08),
                mob.yaw,
                mob.pos,
                uv_face,
                uv_skin,
            );

            // 4. Stumpy legs (height 0.22)
            try appendBox(
                allocator,
                verts,
                inds,
                math.Vec3.init(-0.15, 0.11, 0.20 + leg_swing),
                math.Vec3.init(0.12, 0.22, 0.12),
                mob.yaw,
                mob.pos,
                uv_skin,
                uv_skin,
            );
            try appendBox(
                allocator,
                verts,
                inds,
                math.Vec3.init(0.15, 0.11, 0.20 - leg_swing),
                math.Vec3.init(0.12, 0.22, 0.12),
                mob.yaw,
                mob.pos,
                uv_skin,
                uv_skin,
            );
            try appendBox(
                allocator,
                verts,
                inds,
                math.Vec3.init(-0.15, 0.11, -0.20 - leg_swing),
                math.Vec3.init(0.12, 0.22, 0.12),
                mob.yaw,
                mob.pos,
                uv_skin,
                uv_skin,
            );
            try appendBox(
                allocator,
                verts,
                inds,
                math.Vec3.init(0.15, 0.11, -0.20 + leg_swing),
                math.Vec3.init(0.12, 0.22, 0.12),
                mob.yaw,
                mob.pos,
                uv_skin,
                uv_skin,
            );
        },
        .emberbeast => {
            const uv_hide = texture.getTileUV(4, 2);
            const uv_face = texture.getTileUV(3, 3);

            // 1. Body: bulky 0.55 x 0.48 x 0.78 at (0, 0.50, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.50, 0), math.Vec3.init(0.55, 0.48, 0.78), mob.yaw, mob.pos, uv_hide, uv_hide);
            // 2. Head: 0.36 cube forward-up at (0, 0.74, 0.48)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.74 + head_bob_y, 0.48), math.Vec3.init(0.36, 0.36, 0.36), mob.yaw, mob.pos, uv_face, uv_hide);
            // 3. Snout: 0.16 x 0.12 x 0.14 at (0, 0.66, 0.68)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.66 + head_bob_y, 0.68), math.Vec3.init(0.16, 0.12, 0.14), mob.yaw, mob.pos, uv_face, uv_hide);
            // 4. Back ridges: two ember plates along spine
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.80, 0.05), math.Vec3.init(0.12, 0.14, 0.16), mob.yaw, mob.pos, uv_face, uv_hide);
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.80, -0.25), math.Vec3.init(0.12, 0.14, 0.16), mob.yaw, mob.pos, uv_face, uv_hide);
            // 6-9. Sturdy legs (0.36 high)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.17, 0.18, 0.26 + leg_swing), math.Vec3.init(0.13, 0.36, 0.13), mob.yaw, mob.pos, uv_hide, uv_hide);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.17, 0.18, 0.26 - leg_swing), math.Vec3.init(0.13, 0.36, 0.13), mob.yaw, mob.pos, uv_hide, uv_hide);
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.17, 0.18, -0.26 - leg_swing), math.Vec3.init(0.13, 0.36, 0.13), mob.yaw, mob.pos, uv_hide, uv_hide);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.17, 0.18, -0.26 + leg_swing), math.Vec3.init(0.13, 0.36, 0.13), mob.yaw, mob.pos, uv_hide, uv_hide);
        },
        .wolf => {
            const uv_fur = texture.getTileUV(2, 5);
            const uv_face = texture.getTileUV(3, 5);

            // 1. Body: lean 0.42 x 0.38 x 0.72 at (0, 0.42, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.42, 0), math.Vec3.init(0.42, 0.38, 0.72), mob.yaw, mob.pos, uv_fur, uv_fur);
            // 2. Head: 0.30 cube forward-up at (0, 0.62, 0.44)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.62 + head_bob_y, 0.44), math.Vec3.init(0.30, 0.30, 0.30), mob.yaw, mob.pos, uv_face, uv_fur);
            // 3. Snout: 0.14 x 0.10 x 0.12 at (0, 0.56, 0.62)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.56 + head_bob_y, 0.62), math.Vec3.init(0.14, 0.10, 0.12), mob.yaw, mob.pos, uv_face, uv_fur);
            // 4. Tail: angled 0.10 x 0.10 x 0.30 at back (0, 0.52, -0.46)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.52, -0.46), math.Vec3.init(0.10, 0.10, 0.30), mob.yaw, mob.pos, uv_fur, uv_fur);
            // 5-8. Tall legs (0.32 high)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.14, 0.16, 0.24 + leg_swing), math.Vec3.init(0.11, 0.32, 0.11), mob.yaw, mob.pos, uv_fur, uv_fur);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.14, 0.16, 0.24 - leg_swing), math.Vec3.init(0.11, 0.32, 0.11), mob.yaw, mob.pos, uv_fur, uv_fur);
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.14, 0.16, -0.24 - leg_swing), math.Vec3.init(0.11, 0.32, 0.11), mob.yaw, mob.pos, uv_fur, uv_fur);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.14, 0.16, -0.24 + leg_swing), math.Vec3.init(0.11, 0.32, 0.11), mob.yaw, mob.pos, uv_fur, uv_fur);
        },
        .wither_skeleton => {
            const uv_bone = texture.getTileUV(7, 2);
            const uv_skull = texture.getTileUV(6, 2);
            // 1. Ribcage: tall thin 0.4 x 0.55 x 0.3 at (0, 0.85, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.85, 0), math.Vec3.init(0.4, 0.55, 0.3), mob.yaw, mob.pos, uv_bone, uv_bone);
            // 2. Skull: 0.3 cube at (0, 1.3, 0.1)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.3 + head_bob_y, 0.1), math.Vec3.init(0.3, 0.3, 0.3), mob.yaw, mob.pos, uv_skull, uv_bone);
            // 3-4. Long arms
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.28, 0.85, 0 + leg_swing), math.Vec3.init(0.1, 0.6, 0.1), mob.yaw, mob.pos, uv_bone, uv_bone);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.28, 0.85, 0 - leg_swing), math.Vec3.init(0.1, 0.6, 0.1), mob.yaw, mob.pos, uv_bone, uv_bone);
            // 5. Stone sword held low
            try appendBox(allocator, verts, inds, math.Vec3.init(0.28, 0.45, 0.15 - leg_swing), math.Vec3.init(0.08, 0.5, 0.08), mob.yaw, mob.pos, uv_skull, uv_skull);
            // 6-7. Long legs
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.12, 0.3, 0 + leg_swing), math.Vec3.init(0.12, 0.6, 0.12), mob.yaw, mob.pos, uv_bone, uv_bone);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.12, 0.3, 0 - leg_swing), math.Vec3.init(0.12, 0.6, 0.12), mob.yaw, mob.pos, uv_bone, uv_bone);
        },
    }
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

    // Emberbeast: 9 boxes (body, head, snout, 2 ridges, 4 legs) = 216 verts, 324 indices
    verts.clearRetainingCapacity();
    inds.clearRetainingCapacity();
    const ember = mob_mod.Mob.init(.emberbeast, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, ember);
    try std.testing.expectEqual(@as(usize, 216), verts.items.len);
    try std.testing.expectEqual(@as(usize, 324), inds.items.len);

    // Wither skeleton: 7 boxes (ribcage, skull, 2 arms, sword, 2 legs) = 168 verts, 252 indices
    verts.clearRetainingCapacity();
    inds.clearRetainingCapacity();
    const wither = mob_mod.Mob.init(.wither_skeleton, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, wither);
    try std.testing.expectEqual(@as(usize, 168), verts.items.len);
    try std.testing.expectEqual(@as(usize, 252), inds.items.len);

    // Pig test: 7 boxes (body, head, snout, 4 legs) = 7 * 24 = 168 verts, 7 * 36 = 252 indices
    verts.clearRetainingCapacity();
    inds.clearRetainingCapacity();
    const pig = mob_mod.Mob.init(.pig, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, pig);
    try std.testing.expectEqual(@as(usize, 168), verts.items.len);
    try std.testing.expectEqual(@as(usize, 252), inds.items.len);
}

test "appendMobMesh water swimming head bob elevates head" {
    var verts_land = std.ArrayList(MobVertex).empty;
    defer verts_land.deinit(std.testing.allocator);
    var inds_land = std.ArrayList(u32).empty;
    defer inds_land.deinit(std.testing.allocator);

    var mob_land = mob_mod.Mob.init(.sheep, 0, 0, 0);
    mob_land.in_water = false;
    try appendMobMesh(std.testing.allocator, &verts_land, &inds_land, mob_land);

    var verts_water = std.ArrayList(MobVertex).empty;
    defer verts_water.deinit(std.testing.allocator);
    var inds_water = std.ArrayList(u32).empty;
    defer inds_water.deinit(std.testing.allocator);

    var mob_water = mob_mod.Mob.init(.sheep, 0, 0, 0);
    mob_water.in_water = true;
    try appendMobMesh(std.testing.allocator, &verts_water, &inds_water, mob_water);

    // Vertex count remains consistent (6 boxes * 24 vertices = 144 verts)
    try std.testing.expectEqual(verts_land.items.len, verts_water.items.len);
    // Head vertices (box 2, indices 24..48) have higher Y in water
    try std.testing.expect(verts_water.items[24].pos[1] > verts_land.items[24].pos[1]);
}
