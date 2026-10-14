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
    const start_v = verts.items.len;
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
        .skeleton => {
            const uv_bone = texture.getTileUV(7, 2); // bone / light ivory texture
            const uv_skull = texture.getTileUV(1, 2); // ivory skull face
            const uv_bow = texture.getTileUV(2, 2); // wooden bow stave

            // 1. Ribcage: 0.38 x 0.52 x 0.28 at (0, 0.85, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.85, 0), math.Vec3.init(0.38, 0.52, 0.28), mob.yaw, mob.pos, uv_bone, uv_bone);
            // 2. Skull: 0.32 cube at (0, 1.30 + head_bob_y, 0.08)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.30 + head_bob_y, 0.08), math.Vec3.init(0.32, 0.32, 0.32), mob.yaw, mob.pos, uv_skull, uv_bone);
            // 3. Left arm: 0.1 x 0.56 x 0.1
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.26, 0.85, 0 + leg_swing), math.Vec3.init(0.10, 0.56, 0.10), mob.yaw, mob.pos, uv_bone, uv_bone);
            // 4. Right arm raised holding bow forward
            try appendBox(allocator, verts, inds, math.Vec3.init(0.26, 0.90, 0.20), math.Vec3.init(0.10, 0.10, 0.50), mob.yaw, mob.pos, uv_bone, uv_bone);
            // 5. Wooden Bow held in right hand: 0.06 x 0.60 x 0.06
            try appendBox(allocator, verts, inds, math.Vec3.init(0.26, 0.90, 0.45), math.Vec3.init(0.06, 0.60, 0.06), mob.yaw, mob.pos, uv_bow, uv_bow);
            // 6-7. Legs
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.12, 0.30, 0 + leg_swing), math.Vec3.init(0.11, 0.58, 0.11), mob.yaw, mob.pos, uv_bone, uv_bone);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.12, 0.30, 0 - leg_swing), math.Vec3.init(0.11, 0.58, 0.11), mob.yaw, mob.pos, uv_bone, uv_bone);
        },
        .zombie => {
            const uv_shirt = texture.getTileUV(7, 1); // cyan/teal shirt
            const uv_skin = texture.getTileUV(7, 0); // rotting moss green skin
            const uv_pants = texture.getTileUV(6, 1); // dark blue/purple trousers

            // 1. Torso (teal shirt): 0.44 x 0.60 x 0.28 at (0, 0.90, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.90, 0), math.Vec3.init(0.44, 0.60, 0.28), mob.yaw, mob.pos, uv_shirt, uv_shirt);
            // 2. Head (green zombie face): 0.36 cube at (0, 1.34 + head_bob_y, 0.04)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.34 + head_bob_y, 0.04), math.Vec3.init(0.36, 0.36, 0.36), mob.yaw, mob.pos, uv_skin, uv_skin);
            // 3. Left arm outstretched forward: 0.12 x 0.12 x 0.52 at (-0.28, 0.95, 0.22)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.28, 0.95, 0.22), math.Vec3.init(0.12, 0.12, 0.52), mob.yaw, mob.pos, uv_skin, uv_shirt);
            // 4. Right arm outstretched forward: 0.12 x 0.12 x 0.52 at (0.28, 0.95, 0.22)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.28, 0.95, 0.22), math.Vec3.init(0.12, 0.12, 0.52), mob.yaw, mob.pos, uv_skin, uv_shirt);
            // 5-6. Legs (pants): 0.14 x 0.60 x 0.14
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.12, 0.30, 0 + leg_swing), math.Vec3.init(0.14, 0.60, 0.14), mob.yaw, mob.pos, uv_pants, uv_pants);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.12, 0.30, 0 - leg_swing), math.Vec3.init(0.14, 0.60, 0.14), mob.yaw, mob.pos, uv_pants, uv_pants);
        },
        .creeper => {
            const uv_green = texture.getTileUV(7, 0); // mottled green creeper hide
            const uv_face = texture.getTileUV(6, 4); // frowning dark mouth/eyes face

            // 1. Torso: 0.40 x 0.64 x 0.24 at (0, 0.82, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.82, 0), math.Vec3.init(0.40, 0.64, 0.24), mob.yaw, mob.pos, uv_green, uv_green);
            // 2. Head: 0.36 cube at (0, 1.28 + head_bob_y, 0.02)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.28 + head_bob_y, 0.02), math.Vec3.init(0.36, 0.36, 0.36), mob.yaw, mob.pos, uv_face, uv_green);
            // 3. Front-left leg: 0.14 x 0.50 x 0.14 at (-0.14, 0.25, 0.14 + leg_swing)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.14, 0.25, 0.14 + leg_swing), math.Vec3.init(0.14, 0.50, 0.14), mob.yaw, mob.pos, uv_green, uv_green);
            // 4. Front-right leg: 0.14 x 0.50 x 0.14 at (0.14, 0.25, 0.14 - leg_swing)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.14, 0.25, 0.14 - leg_swing), math.Vec3.init(0.14, 0.50, 0.14), mob.yaw, mob.pos, uv_green, uv_green);
            // 5. Back-left leg: 0.14 x 0.50 x 0.14 at (-0.14, 0.25, -0.14 - leg_swing)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.14, 0.25, -0.14 - leg_swing), math.Vec3.init(0.14, 0.50, 0.14), mob.yaw, mob.pos, uv_green, uv_green);
            // 6. Back-right leg: 0.14 x 0.50 x 0.14 at (0.14, 0.25, -0.14 + leg_swing)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.14, 0.25, -0.14 + leg_swing), math.Vec3.init(0.14, 0.50, 0.14), mob.yaw, mob.pos, uv_green, uv_green);
        },
        .enderman => {
            const uv_obsidian = texture.getTileUV(5, 2); // obsidian jet black body
            const uv_eyes = texture.getTileUV(7, 6); // glowing purple/magenta ender eyes face

            // 1. Torso: 0.36 x 0.72 x 0.20 at (0, 1.80, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.80, 0), math.Vec3.init(0.36, 0.72, 0.20), mob.yaw, mob.pos, uv_obsidian, uv_obsidian);
            // 2. Head: 0.32 cube at (0, 2.32 + head_bob_y, 0.04)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 2.32 + head_bob_y, 0.04), math.Vec3.init(0.32, 0.32, 0.32), mob.yaw, mob.pos, uv_eyes, uv_obsidian);
            // 3. Left arm: thin slender 0.08 x 1.40 x 0.08 at (-0.22, 1.46, 0 + leg_swing)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.22, 1.46, 0 + leg_swing), math.Vec3.init(0.08, 1.40, 0.08), mob.yaw, mob.pos, uv_obsidian, uv_obsidian);
            // 4. Right arm: thin slender 0.08 x 1.40 x 0.08 at (0.22, 1.46, 0 - leg_swing)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.22, 1.46, 0 - leg_swing), math.Vec3.init(0.08, 1.40, 0.08), mob.yaw, mob.pos, uv_obsidian, uv_obsidian);
            // 5-6. Long slender legs: 0.09 x 1.44 x 0.09
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.10, 0.72, 0 + leg_swing), math.Vec3.init(0.09, 1.44, 0.09), mob.yaw, mob.pos, uv_obsidian, uv_obsidian);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.10, 0.72, 0 - leg_swing), math.Vec3.init(0.09, 1.44, 0.09), mob.yaw, mob.pos, uv_obsidian, uv_obsidian);
        },
        .piglin, .piglin_brute => {
            const uv_skin = if (mob.mob_type == .piglin_brute) texture.getTileUV(2, 5) else texture.getTileUV(5, 4); // Brute dark charcoal armor
            const uv_face = texture.getTileUV(6, 4);
            const uv_gold = texture.getTileUV(3, 5); // gold battleaxe / golden weapon

            // 1. Torso: bipedal 0.44 x 0.58 x 0.30 at (0, 0.82, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.82, 0), math.Vec3.init(0.44, 0.58, 0.30), mob.yaw, mob.pos, uv_skin, uv_skin);
            // 2. Head: 0.34 cube at (0, 1.22 + head_bob_y, 0.06)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.22 + head_bob_y, 0.06), math.Vec3.init(0.34, 0.34, 0.34), mob.yaw, mob.pos, uv_face, uv_skin);
            // 3. Snout: 0.16 x 0.10 x 0.10 at (0, 1.15 + head_bob_y, 0.25)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.15 + head_bob_y, 0.25), math.Vec3.init(0.16, 0.10, 0.10), mob.yaw, mob.pos, uv_face, uv_face);
            // 4-5. Floppy ears flanking head
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.21, 1.18 + head_bob_y, 0.06), math.Vec3.init(0.06, 0.20, 0.08), mob.yaw, mob.pos, uv_skin, uv_skin);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.21, 1.18 + head_bob_y, 0.06), math.Vec3.init(0.06, 0.20, 0.08), mob.yaw, mob.pos, uv_skin, uv_skin);
            // 6-7. Arms with walking swing
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.28, 0.82, 0 + leg_swing), math.Vec3.init(0.12, 0.55, 0.12), mob.yaw, mob.pos, uv_skin, uv_skin);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.28, 0.82, 0 - leg_swing), math.Vec3.init(0.12, 0.55, 0.12), mob.yaw, mob.pos, uv_skin, uv_skin);
            // 8. Golden battleaxe / sword held in right hand
            const weapon_h: f32 = if (mob.mob_type == .piglin_brute) 0.54 else 0.44;
            try appendBox(allocator, verts, inds, math.Vec3.init(0.28, 0.46, 0.16 - leg_swing), math.Vec3.init(0.10, weapon_h, 0.10), mob.yaw, mob.pos, uv_gold, uv_gold);
            // 9-10. Legs
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.12, 0.28, 0 + leg_swing), math.Vec3.init(0.13, 0.56, 0.13), mob.yaw, mob.pos, uv_skin, uv_skin);
            try appendBox(allocator, verts, inds, math.Vec3.init(0.12, 0.28, 0 - leg_swing), math.Vec3.init(0.13, 0.56, 0.13), mob.yaw, mob.pos, uv_skin, uv_skin);
        },
                .shulker => {
            const uv_shell = texture.getTileUV(6, 5); // Purpur shell
            const uv_eye = texture.getTileUV(7, 6);   // Glowing yellow-white shulker eyes / inner head

            // Peeking shell animation: shell opens upwards by peek_h (up to 0.28m)
            const peek_h = @sin(mob.anim_time * 2.5) * 0.14 + 0.14;

            // 1. Lower shell base: 0.72 x 0.36 x 0.72 at (0, 0.18, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.18, 0), math.Vec3.init(0.72, 0.36, 0.72), mob.yaw, mob.pos, uv_shell, uv_shell);

            // 2. Inner peeking head: 0.38 x 0.38 x 0.38 at (0, 0.30 + peek_h * 0.5, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.30 + peek_h * 0.5, 0), math.Vec3.init(0.38, 0.38, 0.38), mob.yaw, mob.pos, uv_eye, uv_shell);

            // 3. Upper shell lid: 0.72 x 0.36 x 0.72 at (0, 0.54 + peek_h, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.54 + peek_h, 0), math.Vec3.init(0.72, 0.36, 0.72), mob.yaw, mob.pos, uv_shell, uv_shell);
        },
        .endermite => {
            // Endermite: tiny undulating 4-segment crawling arthropod body (0.4m length, 0.28m width, 0.22m height)
            const uv_body = texture.getTileUV(5, 2); // Dark obsidian scales
            const uv_eyes = texture.getTileUV(7, 6); // Glowing radiant purple eye specks

            const crawl_wobble = @sin(mob.anim_time * 12.0) * 0.04;
            // 1. Head segment (front): 0.24 x 0.20 x 0.18 at (0, 0.10, 0.15)
            try appendBox(allocator, verts, inds, math.Vec3.init(crawl_wobble, 0.10, 0.15), math.Vec3.init(0.24, 0.20, 0.18), mob.yaw, mob.pos, uv_eyes, uv_body);

            // 2. Thorax segment (middle front): 0.28 x 0.22 x 0.16 at (0, 0.11, 0.02)
            try appendBox(allocator, verts, inds, math.Vec3.init(-crawl_wobble * 0.6, 0.11, 0.02), math.Vec3.init(0.28, 0.22, 0.16), mob.yaw, mob.pos, uv_body, uv_body);

            // 3. Abdomen segment (middle rear): 0.26 x 0.20 x 0.16 at (0, 0.10, -0.11)
            try appendBox(allocator, verts, inds, math.Vec3.init(crawl_wobble * 0.8, 0.10, -0.11), math.Vec3.init(0.26, 0.20, 0.16), mob.yaw, mob.pos, uv_body, uv_body);

            // 4. Posterior tail segment (rear): 0.18 x 0.16 x 0.14 at (0, 0.08, -0.22)
            try appendBox(allocator, verts, inds, math.Vec3.init(-crawl_wobble, 0.08, -0.22), math.Vec3.init(0.18, 0.16, 0.14), mob.yaw, mob.pos, uv_body, uv_body);
        },
        .turtle => {
            // Turtle: amphibious marine reptile geometry (0.9m width, 0.4m height, 1.0m length)
            const uv_carapace = texture.getTileUV(7, 0); // Mottled green scute carapace shell
            const uv_flipper = texture.getTileUV(6, 4);  // Olive-tan flipper & reptilian skin
            const uv_head = texture.getTileUV(1, 2);     // Head with facial features

            const paddle = @sin(mob.anim_time * 5.0) * 0.12;

            // 1. Carapace dome shell: 0.82 x 0.24 x 0.86 at (0, 0.18, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.18, 0), math.Vec3.init(0.82, 0.24, 0.86), mob.yaw, mob.pos, uv_carapace, uv_carapace);

            // 2. Head with gentle bobbing: 0.24 x 0.18 x 0.24 at (0, 0.16, 0.50)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.16 + paddle * 0.2, 0.50), math.Vec3.init(0.24, 0.18, 0.24), mob.yaw, mob.pos, uv_head, uv_flipper);

            // 3. Front-left flipper paddle: 0.28 x 0.08 x 0.36 at (-0.46, 0.10, 0.30)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.46, 0.10, 0.30 + paddle), math.Vec3.init(0.28, 0.08, 0.36), mob.yaw, mob.pos, uv_flipper, uv_flipper);

            // 4. Front-right flipper paddle: 0.28 x 0.08 x 0.36 at (0.46, 0.10, 0.30)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.46, 0.10, 0.30 - paddle), math.Vec3.init(0.28, 0.08, 0.36), mob.yaw, mob.pos, uv_flipper, uv_flipper);

            // 5. Rear-left hind flipper: 0.22 x 0.08 x 0.26 at (-0.38, 0.08, -0.40)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.38, 0.08, -0.40 - paddle), math.Vec3.init(0.22, 0.08, 0.26), mob.yaw, mob.pos, uv_flipper, uv_flipper);

            // 6. Rear-right hind flipper: 0.22 x 0.08 x 0.26 at (0.38, 0.08, -0.40)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.38, 0.08, -0.40 + paddle), math.Vec3.init(0.22, 0.08, 0.26), mob.yaw, mob.pos, uv_flipper, uv_flipper);
        },
        .drowned => {
            // Drowned: waterlogged submerged zombie with teal/cyan skin, dark sunken tunic, and raised arms
            const uv_aqua_skin = texture.getTileUV(7, 1); // Cyan-teal waterlogged decaying flesh
            const uv_tunic = texture.getTileUV(6, 1);     // Dark mossy navy drenched tunic
            const uv_pants = texture.getTileUV(7, 0);     // Algae-stained tattered pants
            const uv_trident = texture.getTileUV(7, 6);   // Radiant cyan-teal trident head / weapon

            const walk_swing = @sin(mob.anim_time * 4.0) * 0.25;

            // 1. Torso: 0.50 x 0.65 x 0.30 centered at (0, 0.95, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.95, 0), math.Vec3.init(0.50, 0.65, 0.30), mob.yaw, mob.pos, uv_tunic, uv_tunic);

            // 2. Head: 0.40 x 0.40 x 0.40 centered at (0, 1.45, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.45, 0), math.Vec3.init(0.40, 0.40, 0.40), mob.yaw, mob.pos, uv_aqua_skin, uv_aqua_skin);

            // 3. Left Arm (reaching forward in zombie stance): 0.18 x 0.55 x 0.18 at (-0.35, 1.05, 0.25)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.35, 1.05, 0.25 + walk_swing * 0.2), math.Vec3.init(0.18, 0.55, 0.18), mob.yaw, mob.pos, uv_aqua_skin, uv_tunic);

            // 4. Right Arm holding Trident: 0.18 x 0.55 x 0.18 at (0.35, 1.05, 0.25)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.35, 1.05, 0.25 - walk_swing * 0.2), math.Vec3.init(0.18, 0.55, 0.18), mob.yaw, mob.pos, uv_aqua_skin, uv_tunic);

            // 5. Trident weapon in right hand: 0.08 x 0.85 x 0.08 at (0.42, 1.15, 0.35)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.42, 1.15, 0.35 - walk_swing * 0.2), math.Vec3.init(0.08, 0.85, 0.08), mob.yaw, mob.pos, uv_trident, uv_trident);

            // 6. Left Leg: 0.20 x 0.60 x 0.20 at (-0.14, 0.30 + walk_swing * 0.1, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.14, 0.30, walk_swing), math.Vec3.init(0.20, 0.60, 0.20), mob.yaw, mob.pos, uv_pants, uv_pants);

            // 7. Right Leg: 0.20 x 0.60 x 0.20 at (0.14, 0.30 - walk_swing * 0.1, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.14, 0.30, -walk_swing), math.Vec3.init(0.20, 0.60, 0.20), mob.yaw, mob.pos, uv_pants, uv_pants);
        },
        .phantom => {
            // Phantom: undead aerial predator with indigo wings, bone ribs, glowing green eyes, and trailing tail
            const uv_indigo = texture.getTileUV(6, 1); // Dark midnight indigo dorsal body & wings
            const uv_bone = texture.getTileUV(7, 2);   // Exposed pale ventral skeleton & bone ribbing
            const uv_eyes = texture.getTileUV(7, 6);   // Radiant luminous yellow-green phantom eyes

            const wing_flap = @sin(mob.anim_time * 6.0) * 0.35;

            // 1. Central body fuselage: 0.38 x 0.16 x 0.70 at (0, 0.20, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.20, 0), math.Vec3.init(0.38, 0.16, 0.70), mob.yaw, mob.pos, uv_indigo, uv_bone);

            // 2. Head with menacing eyes: 0.26 x 0.14 x 0.26 at (0, 0.18, 0.42)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.18, 0.42), math.Vec3.init(0.26, 0.14, 0.26), mob.yaw, mob.pos, uv_eyes, uv_indigo);

            // 3. Left Wing (articulated flap): 0.55 x 0.05 x 0.45 at (-0.46, 0.22 + wing_flap * 0.4, 0.05)
            try appendBox(allocator, verts, inds, math.Vec3.init(-0.46, 0.22 + wing_flap * 0.4, 0.05), math.Vec3.init(0.55, 0.05, 0.45), mob.yaw, mob.pos, uv_indigo, uv_bone);

            // 4. Right Wing (articulated flap): 0.55 x 0.05 x 0.45 at (0.46, 0.22 + wing_flap * 0.4, 0.05)
            try appendBox(allocator, verts, inds, math.Vec3.init(0.46, 0.22 + wing_flap * 0.4, 0.05), math.Vec3.init(0.55, 0.05, 0.45), mob.yaw, mob.pos, uv_indigo, uv_bone);

            // 5. Tail segment (trailing rudder): 0.16 x 0.10 x 0.40 at (0, 0.18 - wing_flap * 0.15, -0.48)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.18 - wing_flap * 0.15, -0.48), math.Vec3.init(0.16, 0.10, 0.40), mob.yaw, mob.pos, uv_indigo, uv_bone);
        }, .target_dummy => {
            const uv_hay = texture.getTileUV(1, 4); // Hay bale textured body
            const uv_post = texture.getTileUV(2, 2); // Wood post & crossbar
            const uv_head = texture.getTileUV(3, 3); // Medallion practice face

            // 1. Vertical mounting post: 0.15 x 0.6 x 0.15 centered at (0, 0.3, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.3, 0), math.Vec3.init(0.15, 0.6, 0.15), mob.yaw, mob.pos, uv_post, uv_post);

            // 2. Hay bale stuffed torso: 0.5 x 0.7 x 0.4 centered at (0, 0.9, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.9, 0), math.Vec3.init(0.5, 0.7, 0.4), mob.yaw, mob.pos, uv_hay, uv_hay);

            // 3. Wooden crossbar shoulder arms: 0.9 x 0.12 x 0.12 centered at (0, 1.1, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.1, 0), math.Vec3.init(0.9, 0.12, 0.12), mob.yaw, mob.pos, uv_post, uv_post);

            // 4. Stuffed sack target head: 0.35 x 0.35 x 0.35 centered at (0, 1.45, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 1.45, 0), math.Vec3.init(0.35, 0.35, 0.35), mob.yaw, mob.pos, uv_head, uv_head);
        },
        .blaze => {
            const uv_core = texture.getTileUV(4, 2); // fiery ember texture
            const uv_rod = texture.getTileUV(5, 2); // golden blaze rod texture

            // 1. Central head/core: 0.36 cube centered at (0, 1.25, 0)
            const head_y = 1.25 + @sin(mob.anim_time * 2.0) * 0.05;
            try appendBox(allocator, verts, inds, math.Vec3.init(0, head_y, 0), math.Vec3.init(0.36, 0.36, 0.36), mob.yaw, mob.pos, uv_core, uv_core);

            // 12 orbiting rods in 3 tiers (4 rods per tier)
            const tiers = [_]struct { y: f32, radius: f32, speed: f32, offset: f32 }{
                .{ .y = 1.15, .radius = 0.38, .speed = 2.5, .offset = 0.0 },
                .{ .y = 0.70, .radius = 0.32, .speed = -2.0, .offset = 0.785 },
                .{ .y = 0.25, .radius = 0.26, .speed = 1.8, .offset = 0.392 },
            };

            for (tiers) |t| {
                var ri: usize = 0;
                while (ri < 4) : (ri += 1) {
                    const angle = mob.anim_time * t.speed + t.offset + @as(f32, @floatFromInt(ri)) * (std.math.pi * 0.5);
                    const rx = @cos(angle) * t.radius;
                    const rz = @sin(angle) * t.radius;
                    try appendBox(allocator, verts, inds, math.Vec3.init(rx, t.y, rz), math.Vec3.init(0.08, 0.32, 0.08), mob.yaw, mob.pos, uv_rod, uv_rod);
                }
            }
        },
        .spider => {
            const uv_abdomen = texture.getTileUV(2, 5); // dark arachnid chitin
            const uv_eyes = texture.getTileUV(3, 5); // glowing red eyes & markings
            const uv_leg = texture.getTileUV(7, 2); // jointed leg segments

            // 1. Cephalothorax (front body): 0.40 x 0.25 x 0.40 at (0, 0.22, 0.12)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.22, 0.12), math.Vec3.init(0.40, 0.25, 0.40), mob.yaw, mob.pos, uv_eyes, uv_abdomen);
            // 2. Abdomen (rear body): 0.52 x 0.35 x 0.55 at (0, 0.28, -0.32)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.28, -0.32), math.Vec3.init(0.52, 0.35, 0.55), mob.yaw, mob.pos, uv_abdomen, uv_abdomen);

            // 3-10. 8 arachnid splayed legs (4 left, 4 right) with alternating walking swing
            const leg_z_offsets = [_]f32{ 0.24, 0.12, -0.02, -0.16 };
            for (leg_z_offsets, 0..) |lz, i| {
                const swing = if (i % 2 == 0) leg_swing else -leg_swing;
                // Left leg: splayed outward at -0.35 x
                try appendBox(allocator, verts, inds, math.Vec3.init(-0.35, 0.16, lz + swing), math.Vec3.init(0.36, 0.08, 0.08), mob.yaw, mob.pos, uv_leg, uv_leg);
                // Right leg: splayed outward at +0.35 x
                try appendBox(allocator, verts, inds, math.Vec3.init(0.35, 0.16, lz - swing), math.Vec3.init(0.36, 0.08, 0.08), mob.yaw, mob.pos, uv_leg, uv_leg);
            }
        },
        .ender_dragon => {
            // Ender Dragon: 6-box draconic wyrm geometry (elongated body, horned draconic skull, 2 flapping wings, 2-segment tail)
            const uv_scales = texture.getTileUV(5, 2); // Obsidian black draconic scales
            const uv_head = texture.getTileUV(7, 6);   // Luminous purple draconic eyes & horned muzzle
            const uv_wing = texture.getTileUV(5, 0);   // Dark membrane leathery wing

            const wing_flap = @sin(mob.anim_time) * 0.42;

            // 1. Central Body Torso: 0.8 x 0.7 x 1.6 at (0, 0.6, 0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.6, 0), math.Vec3.init(0.8, 0.7, 1.6), mob.yaw, mob.pos, uv_scales, uv_scales);

            // 2. Head & Horned Muzzle: 0.6 x 0.5 x 0.8 at (0, 0.75, 1.1)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.75, 1.1), math.Vec3.init(0.6, 0.5, 0.8), mob.yaw, mob.pos, uv_head, uv_scales);

            // 3. Left Wing: 1.4 x 0.08 x 0.9 extended laterally at (-1.0, 0.85 + wing_flap, 0.1)
            try appendBox(allocator, verts, inds, math.Vec3.init(-1.0, 0.85 + wing_flap, 0.1), math.Vec3.init(1.4, 0.08, 0.9), mob.yaw, mob.pos, uv_wing, uv_wing);

            // 4. Right Wing: 1.4 x 0.08 x 0.9 extended laterally at (+1.0, 0.85 - wing_flap, 0.1)
            try appendBox(allocator, verts, inds, math.Vec3.init(1.0, 0.85 - wing_flap, 0.1), math.Vec3.init(1.4, 0.08, 0.9), mob.yaw, mob.pos, uv_wing, uv_wing);

            // 5. Tail Segment 1: 0.45 x 0.4 x 0.7 at (0, 0.55, -1.0)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.55, -1.0), math.Vec3.init(0.45, 0.4, 0.7), mob.yaw, mob.pos, uv_scales, uv_scales);

            // 6. Tail Segment 2 (tip): 0.3 x 0.3 x 0.7 at (0, 0.50, -1.6)
            try appendBox(allocator, verts, inds, math.Vec3.init(0, 0.50, -1.6), math.Vec3.init(0.3, 0.3, 0.7), mob.yaw, mob.pos, uv_scales, uv_scales);
        },
    }

    if (mob.isGlowing()) {
        for (verts.items[start_v..]) |*v| {
            v.emissive = 1.0;
        }
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

    // Piglin: 10 boxes (torso, head, snout, 2 ears, 2 arms, sword, 2 legs) = 240 verts, 360 indices
    verts.clearRetainingCapacity();
    inds.clearRetainingCapacity();
    const piglin = mob_mod.Mob.init(.piglin, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, piglin);
    try std.testing.expectEqual(@as(usize, 240), verts.items.len);
    try std.testing.expectEqual(@as(usize, 360), inds.items.len);

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

test "piglin brute mob mesh generation" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const brute = mob_mod.Mob.init(.piglin_brute, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, brute);
    // 10 boxes (torso, head, snout, 2 ears, 2 arms, weapon, 2 legs) = 240 verts, 360 indices
    try std.testing.expectEqual(@as(usize, 240), verts.items.len);
    try std.testing.expectEqual(@as(usize, 360), inds.items.len);
}

test "appendMobMesh glowing mob sets emissive vertices" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    var mob = mob_mod.Mob.init(.sheep, 0, 0, 0);
    mob.glow_timer = 10.0;
    try appendMobMesh(std.testing.allocator, &verts, &inds, mob);
    try std.testing.expect(verts.items.len > 0);
    for (verts.items) |v| {
        try std.testing.expectEqual(@as(f32, 1.0), v.emissive);
    }
}

test "appendMobMesh blaze mob generates head and 12 orbiting rods" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const blaze = mob_mod.Mob.init(.blaze, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, blaze);

    // 1 head + 12 rods = 13 boxes
    // 13 boxes * 24 verts = 312 verts
    // 13 boxes * 36 inds = 468 inds
    try std.testing.expectEqual(@as(usize, 312), verts.items.len);
    try std.testing.expectEqual(@as(usize, 468), inds.items.len);
}

test "target dummy mob mesh generation" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const dummy = mob_mod.Mob.init(.target_dummy, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, dummy);
    // 4 boxes * 24 = 96 verts, 4 boxes * 36 = 144 indices
    try std.testing.expectEqual(@as(usize, 96), verts.items.len);
    try std.testing.expectEqual(@as(usize, 144), inds.items.len);
}

test "spider mob mesh generation" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const spider = mob_mod.Mob.init(.spider, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, spider);
    // 10 boxes (cephalothorax, abdomen, 8 legs) * 24 = 240 verts, * 36 = 360 indices
    try std.testing.expectEqual(@as(usize, 240), verts.items.len);
    try std.testing.expectEqual(@as(usize, 360), inds.items.len);
}

test "skeleton mob mesh generation" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const skeleton = mob_mod.Mob.init(.skeleton, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, skeleton);
    // 7 boxes (ribcage, skull, 2 arms, bow, 2 legs) = 168 verts, 252 indices
    try std.testing.expectEqual(@as(usize, 168), verts.items.len);
    try std.testing.expectEqual(@as(usize, 252), inds.items.len);
}

test "zombie mob mesh generation" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const zombie = mob_mod.Mob.init(.zombie, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, zombie);
    // 6 boxes (torso, head, 2 forward arms, 2 legs) = 144 verts, 216 indices
    try std.testing.expectEqual(@as(usize, 144), verts.items.len);
    try std.testing.expectEqual(@as(usize, 216), inds.items.len);
}

test "creeper mob mesh generation" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const creeper = mob_mod.Mob.init(.creeper, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, creeper);
    // 6 boxes (torso, head, 4 quadruped legs) = 144 verts, 216 indices
    try std.testing.expectEqual(@as(usize, 144), verts.items.len);
    try std.testing.expectEqual(@as(usize, 216), inds.items.len);
}

test "enderman mob mesh generation" {
    var verts = std.ArrayList(MobVertex).empty;
    defer verts.deinit(std.testing.allocator);
    var inds = std.ArrayList(u32).empty;
    defer inds.deinit(std.testing.allocator);

    const enderman = mob_mod.Mob.init(.enderman, 0, 0, 0);
    try appendMobMesh(std.testing.allocator, &verts, &inds, enderman);
    // 6 boxes (torso, head, 2 long arms, 2 long legs) = 144 verts, 216 indices
    try std.testing.expectEqual(@as(usize, 144), verts.items.len);
    try std.testing.expectEqual(@as(usize, 216), inds.items.len);
}
