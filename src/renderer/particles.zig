const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const shader = @import("shader.zig");

pub const Particle = struct {
    x: f32,
    y: f32,
    z: f32,
    vx: f32,
    vy: f32,
    vz: f32,
    life: f32, // remaining seconds
    max_life: f32,
    color: [3]f32,
    size: f32,
};

pub const MAX_PARTICLES: usize = 256;

pub const Flame = struct { x: i32, y: i32, z: i32, life: f32 };

/// Lightweight CPU particle system rendering textured/colored billboard-free cubes
/// or cross quads with point-sprites/quads. Uses dynamic VBO of 12 triangles (24 verts)
/// per active particle or small cubes. To keep vertex buffer small and fast, each
/// particle is a tiny 3D box (12 triangles = 36 vertices) or 3 quads (18 verts).
/// Here: tiny 6-face cube (36 verts per particle, 0.08m side) rendered with
/// simple color shader (reusing line_vert/line_frag-style color MVP shader).
pub const ParticleSystem = struct {
    particles: [MAX_PARTICLES]Particle,
    count: usize,
    vao: c.GLuint,
    vbo: c.GLuint,
    program: c.GLuint,

    const Vert = extern struct {
        pos: [3]f32,
        color: [3]f32,
    };

    const vert_src: [:0]const u8 =
        \\#version 330 core
        \\layout (location = 0) in vec3 aPos;
        \\layout (location = 1) in vec3 aColor;
        \\uniform mat4 u_mvp;
        \\out vec3 vColor;
        \\void main() {
        \\    gl_Position = u_mvp * vec4(aPos, 1.0);
        \\    vColor = aColor;
        \\}
    ;

    const frag_src: [:0]const u8 =
        \\#version 330 core
        \\in vec3 vColor;
        \\out vec4 FragColor;
        \\void main() {
        \\    FragColor = vec4(vColor, 1.0);
        \\}
    ;

    pub fn init(allocator: std.mem.Allocator) !ParticleSystem {
        var vao: c.GLuint = 0;
        var vbo: c.GLuint = 0;
        c.glGenVertexArrays(1, &vao);
        c.glGenBuffers(1, &vbo);
        c.glBindVertexArray(vao);
        c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
        // 256 particles * 36 verts * sizeof(Vert)
        c.glBufferData(c.GL_ARRAY_BUFFER, MAX_PARTICLES * 36 * @sizeOf(Vert), null, c.GL_DYNAMIC_DRAW);
        c.glEnableVertexAttribArray(0);
        c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vert), @ptrFromInt(0));
        c.glEnableVertexAttribArray(1);
        c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Vert), @ptrFromInt(@sizeOf([3]f32)));
        c.glBindVertexArray(0);
        const program = try shader.createProgram(allocator, vert_src, frag_src);
        return .{
            .particles = undefined,
            .count = 0,
            .vao = vao,
            .vbo = vbo,
            .program = program,
        };
    }

    pub fn deinit(self: *ParticleSystem) void {
        c.glDeleteVertexArrays(1, &self.vao);
        c.glDeleteBuffers(1, &self.vbo);
        c.glDeleteProgram(self.program);
    }

    /// Spawn a burst of debris particles centered at block (bx,by,bz).
    pub fn spawnBlockDebris(self: *ParticleSystem, bx: i32, by: i32, bz: i32, color: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(bx)) *% 31 +% @as(u32, @bitCast(by)) *% 17 +% @as(u32, @bitCast(bz));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const rz = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            // slight color jitter
            const shade = 0.8 + 0.4 * rx;
            const col = [3]f32{ color[0] * shade, color[1] * shade, color[2] * shade };
            self.particles[self.count] = .{
                .x = @as(f32, @floatFromInt(bx)) + 0.2 + 0.6 * rx,
                .y = @as(f32, @floatFromInt(by)) + 0.2 + 0.6 * ry,
                .z = @as(f32, @floatFromInt(bz)) + 0.2 + 0.6 * rz,
                .vx = (rx - 0.5) * 4.0,
                .vy = 2.0 + ry * 3.5,
                .vz = (rz - 0.5) * 4.0,
                .life = 0.6 + 0.4 * rx,
                .max_life = 0.6 + 0.4 * rx,
                .color = col,
                .size = 0.08 + 0.04 * ry,
            };
            self.count += 1;
        }
    }

    /// Advance physics (gravity + velocity), remove expired particles in place.
    /// Emit rising orange/yellow ember debris at a block cell (fire visual).
    pub fn spawnFlame(self: *ParticleSystem, bx: i32, by: i32, bz: i32, count: usize) void {
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const hx = @mod(bx * 7 + by * 13 + bz * 17 + @as(i32, @intCast(i * 31)), 60);
            const hz = @mod(bx * 3 + by * 11 + bz * 5 + @as(i32, @intCast(i * 17)), 60);
            const fx = @as(f32, @floatFromInt(bx)) + 0.2 + @as(f32, @floatFromInt(hx)) / 100.0;
            const fz = @as(f32, @floatFromInt(bz)) + 0.2 + @as(f32, @floatFromInt(hz)) / 100.0;
            const warm: f32 = @as(f32, @floatFromInt(i % 3)) / 2.0;
            if (self.count >= MAX_PARTICLES) return;
            self.particles[self.count] = .{
                .x = fx,
                .y = @as(f32, @floatFromInt(by)) + 0.1,
                .z = fz,
                .vx = 0.0,
                .vy = 1.2 + warm,
                .vz = 0.0,
                .life = 0.5,
                .max_life = 0.5,
                .color = .{ 1.0, 0.45 + warm * 0.25, 0.1 },
                .size = 0.09,
            };
            self.count += 1;
        }
    }

    pub fn tick(self: *ParticleSystem, dt: f32) void {
        var i: usize = 0;
        const gravity: f32 = 18.0;
        while (i < self.count) {
            var p = &self.particles[i];
            p.life -= dt;
            if (p.life <= 0.0) {
                // Swap-remove
                self.particles[i] = self.particles[self.count - 1];
                self.count -= 1;
                continue;
            }
            p.vy -= gravity * dt;
            p.x += p.vx * dt;
            p.y += p.vy * dt;
            p.z += p.vz * dt;
            i += 1;
        }
    }

    /// Render all active particles using raw MVP pointer.
    pub fn draw(self: *ParticleSystem, mvp_ptr: [*c]const f32) void {
        if (self.count == 0) return;
        var verts: [MAX_PARTICLES * 36]Vert = undefined;
        var vert_count: usize = 0;
        for (self.particles[0..self.count]) |p| {
            const h = p.size * 0.5;
            const x0 = p.x - h;
            const x1 = p.x + h;
            const y0 = p.y - h;
            const y1 = p.y + h;
            const z0 = p.z - h;
            const z1 = p.z + h;
            // 8 corners
            const c0 = [3]f32{ x0, y0, z0 };
            const c1 = [3]f32{ x1, y0, z0 };
            const c2 = [3]f32{ x1, y1, z0 };
            const c3 = [3]f32{ x0, y1, z0 };
            const c4 = [3]f32{ x0, y0, z1 };
            const c5 = [3]f32{ x1, y0, z1 };
            const c6 = [3]f32{ x1, y1, z1 };
            const c7 = [3]f32{ x0, y1, z1 };

            // 6 faces * 2 tris * 3 verts = 36 verts
            // South (+Z): 4, 5, 6, 4, 6, 7
            appendTri(&verts, &vert_count, c4, c5, c6, p.color);
            appendTri(&verts, &vert_count, c4, c6, c7, p.color);
            // North (-Z): 1, 0, 3, 1, 3, 2
            appendTri(&verts, &vert_count, c1, c0, c3, p.color);
            appendTri(&verts, &vert_count, c1, c3, c2, p.color);
            // Top (+Y): 3, 2, 6, 3, 6, 7
            appendTri(&verts, &vert_count, c3, c2, c6, p.color);
            appendTri(&verts, &vert_count, c3, c6, c7, p.color);
            // Bottom (-Y): 0, 1, 5, 0, 5, 4
            appendTri(&verts, &vert_count, c0, c1, c5, p.color);
            appendTri(&verts, &vert_count, c0, c5, c4, p.color);
            // East (+X): 5, 1, 2, 5, 2, 6
            appendTri(&verts, &vert_count, c5, c1, c2, p.color);
            appendTri(&verts, &vert_count, c5, c2, c6, p.color);
            // West (-X): 0, 4, 7, 0, 7, 3
            appendTri(&verts, &vert_count, c0, c4, c7, p.color);
            appendTri(&verts, &vert_count, c0, c7, c3, p.color);
        }

        c.glBindBuffer(c.GL_ARRAY_BUFFER, self.vbo);
        c.glBufferSubData(c.GL_ARRAY_BUFFER, 0, @intCast(vert_count * @sizeOf(Vert)), &verts);

        c.glUseProgram(self.program);
        shader.setUniformMat4(self.program, "u_mvp", mvp_ptr);
        c.glBindVertexArray(self.vao);
        c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(vert_count));
        c.glBindVertexArray(0);
        c.glUseProgram(0);
    }

    fn appendTri(verts: []Vert, count: *usize, p0: [3]f32, p1: [3]f32, p2: [3]f32, col: [3]f32) void {
        const i = count.*;
        verts[i] = .{ .pos = p0, .color = col };
        verts[i + 1] = .{ .pos = p1, .color = col };
        verts[i + 2] = .{ .pos = p2, .color = col };
        count.* += 3;
    }
};

test "particle system spawn, gravity, and expiration" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnBlockDebris(10, 5, -2, .{ 0.5, 0.4, 0.2 }, 12);
    try std.testing.expectEqual(ps.count, 12);
    const start_y = ps.particles[0].y;
    // Tick 0.1s: y should change, count remains 12
    ps.tick(0.1);
    try std.testing.expectEqual(ps.count, 12);
    try std.testing.expect(ps.particles[0].y != start_y);
    // Tick 2.0s: all should expire
    ps.tick(2.0);
    try std.testing.expectEqual(ps.count, 0);
}

test "particle capacity limit clamped at MAX_PARTICLES" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnBlockDebris(0, 0, 0, .{ 1, 1, 1 }, 300);
    try std.testing.expectEqual(ps.count, MAX_PARTICLES);
}
