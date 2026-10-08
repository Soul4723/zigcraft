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


    /// Spawn a spray/burst of water splash particles erupting upward and outward.
    pub fn spawnWaterSplash(self: *ParticleSystem, pos: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 100.0)))) *% 31 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[1] * 100.0)))) *% 17 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 100.0)))) +%
            @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const rz = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;

            const shade = 0.85 + 0.3 * rx;
            const col = [3]f32{ 0.25 * shade, 0.55 * shade, 0.95 * shade };
            self.particles[self.count] = .{
                .x = pos[0] + (rx - 0.5) * 0.4,
                .y = pos[1] + 0.05 + ry * 0.2,
                .z = pos[2] + (rz - 0.5) * 0.4,
                .vx = (rx - 0.5) * 3.6,
                .vy = 2.4 + ry * 2.8,
                .vz = (rz - 0.5) * 3.6,
                .life = 0.35 + 0.25 * ry,
                .max_life = 0.35 + 0.25 * ry,
                .color = col,
                .size = 0.05 + 0.03 * rx,
            };
            self.count += 1;
        }
    }



    /// Spawn trailing foaming wake and bow spray particles when navigating in a boat.
    pub fn spawnBoatWake(self: *ParticleSystem, pos: [3]f32, move_dir: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 80.0)))) *% 29 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 80.0)))) *% 17 +%
            @as(u32, @intCast(self.count));
        // Perpendicular horizontal vector for lateral wake spread
        const perp_x = -move_dir[2];
        const perp_z = move_dir[0];

        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            const side: f32 = if (i % 2 == 0) 1.0 else -1.0;

            const spread_x = perp_x * side * (0.35 + 0.3 * rx);
            const spread_z = perp_z * side * (0.35 + 0.3 * rx);
            const col = [3]f32{ 0.75 + 0.2 * rx, 0.88 + 0.1 * rx, 1.0 }; // White-blue foaming spray

            self.particles[self.count] = .{
                .x = pos[0] + spread_x - move_dir[0] * 0.4,
                .y = pos[1] + 0.05 + ry * 0.15,
                .z = pos[2] + spread_z - move_dir[2] * 0.4,
                .vx = spread_x * 1.5 - move_dir[0] * 0.5,
                .vy = 0.8 + ry * 1.2,
                .vz = spread_z * 1.5 - move_dir[2] * 0.5,
                .life = 0.3 + 0.2 * ry,
                .max_life = 0.3 + 0.2 * ry,
                .color = col,
                .size = 0.05 + 0.03 * rx,
            };
            self.count += 1;
        }
    }

    /// Spawn a forward-drifting cloud of breath mist / gasping droplets.
    pub fn spawnBreathMist(self: *ParticleSystem, pos: [3]f32, look_dir: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 50.0)))) *% 19 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[1] * 50.0)))) *% 13 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 50.0)))) +%
            @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const rz = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;

            const spread = 0.25;
            self.particles[self.count] = .{
                .x = pos[0] + (rx - 0.5) * spread,
                .y = pos[1] + (ry - 0.5) * spread,
                .z = pos[2] + (rz - 0.5) * spread,
                .vx = look_dir[0] * 1.5 + (rx - 0.5) * 0.8,
                .vy = look_dir[1] * 1.5 + 0.3 + ry * 0.4,
                .vz = look_dir[2] * 1.5 + (rz - 0.5) * 0.8,
                .life = 0.45 + 0.2 * ry,
                .max_life = 0.45 + 0.2 * ry,
                .color = .{ 0.88, 0.94, 1.0 },
                .size = 0.04 + 0.03 * rx,
            };
            self.count += 1;
        }
    }

    /// Spawn rising translucent underwater bubbles around a 3D position
    pub fn spawnBubble(self: *ParticleSystem, pos: [3]f32, count: usize) void {
        var i: usize = 0;
        while (i < count) : (i += 1) {
            if (self.count >= MAX_PARTICLES) return;
            const seed_val = @as(u32, @intCast(self.count *% 37 +% i *% 19 +% 7));
            const jx = @as(f32, @floatFromInt(seed_val % 21)) / 50.0 - 0.2;
            const jz = @as(f32, @floatFromInt((seed_val / 21) % 21)) / 50.0 - 0.2;
            const jy = @as(f32, @floatFromInt((seed_val / 441) % 21)) / 50.0 - 0.2;
            self.particles[self.count] = .{
                .x = pos[0] + jx,
                .y = pos[1] + jy,
                .z = pos[2] + jz,
                .vx = jx * 0.5,
                .vy = 0.8 + @as(f32, @floatFromInt(seed_val % 10)) * 0.05,
                .vz = jz * 0.5,
                .life = 0.8,
                .max_life = 0.8,
                .color = .{ 0.65, 0.85, 0.98 },
                .size = 0.045,
            };
            self.count += 1;
        }
    }

    /// Spawn rising fiery embers and smoke sparks erupting from lava surface
    pub fn spawnLavaEmber(self: *ParticleSystem, pos: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 64.0)))) *% 23 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 64.0)))) *% 19 +%
            @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const rz = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;

            // Fiery orange/yellow ember spark vs dark smoke puff
            const is_smoke = (i % 3 == 0);
            const col = if (is_smoke)
                [3]f32{ 0.22 + 0.08 * rx, 0.20 + 0.05 * rx, 0.22 + 0.05 * rx }
            else
                [3]f32{ 1.0, 0.35 + 0.45 * ry, 0.05 };

            self.particles[self.count] = .{
                .x = pos[0] + (rx - 0.5) * 0.7,
                .y = pos[1] + 0.1 + ry * 0.1,
                .z = pos[2] + (rz - 0.5) * 0.7,
                .vx = (rx - 0.5) * 0.6,
                .vy = 0.9 + ry * 1.5,
                .vz = (rz - 0.5) * 0.6,
                .life = 0.5 + 0.4 * ry,
                .max_life = 0.5 + 0.4 * ry,
                .color = col,
                .size = if (is_smoke) 0.07 else 0.04,
            };
            self.count += 1;
        }
    }

    /// Spawn searing fiery sparks erupting from hot surface contact (magma/campfire contact)
    pub fn spawnBurnSparks(self: *ParticleSystem, pos: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 64.0)))) *% 29 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 64.0)))) *% 17 +%
            @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const rz = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;

            const is_bright = rx > 0.4;
            const col = if (is_bright)
                [3]f32{ 1.0, 0.65 + 0.25 * ry, 0.1 }
            else
                [3]f32{ 0.95, 0.25 + 0.15 * ry, 0.05 };

            self.particles[self.count] = .{
                .x = pos[0] + (rx - 0.5) * 0.35,
                .y = pos[1] + 0.05 + ry * 0.15,
                .z = pos[2] + (rz - 0.5) * 0.35,
                .vx = (rx - 0.5) * 2.2,
                .vy = 1.4 + ry * 2.0,
                .vz = (rz - 0.5) * 2.2,
                .life = 0.25 + 0.2 * ry,
                .max_life = 0.25 + 0.2 * ry,
                .color = col,
                .size = 0.04 + 0.03 * rx,
            };
            self.count += 1;
        }
    }

    /// Spawn mystical swirling purple portal particles inside a portal frame
    pub fn spawnPortalParticles(self: *ParticleSystem, pos: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 32.0)))) *% 37 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[1] * 32.0)))) *% 29 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 32.0)))) *% 17 +%
            @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const rz = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;

            // Vibrant ethereal purple / magenta hue
            const col = [3]f32{ 0.7 + 0.25 * rx, 0.15 + 0.1 * ry, 0.9 + 0.1 * rz };

            self.particles[self.count] = .{
                .x = pos[0] + (rx - 0.5) * 0.8,
                .y = pos[1] + (ry - 0.5) * 1.2,
                .z = pos[2] + (rz - 0.5) * 0.8,
                .vx = (rx - 0.5) * 0.5,
                .vy = (ry - 0.3) * 0.8,
                .vz = (rz - 0.5) * 0.5,
                .life = 0.6 + 0.4 * ry,
                .max_life = 0.6 + 0.4 * ry,
                .color = col,
                .size = 0.05 + 0.03 * rx,
            };
            self.count += 1;
        }
    }

    /// Spawn drifting Nether ash / cinder particles falling and drifting in the Nether atmosphere.
    pub fn spawnNetherAsh(self: *ParticleSystem, pos: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 48.0)))) *% 43 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[1] * 48.0)))) *% 29 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 48.0)))) *% 17 +%
            @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const rz = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;

            // Mostly dark grey ash flakes; occasional dim cinder ember flake
            const is_cinder = (rx > 0.82);
            const col = if (is_cinder)
                [3]f32{ 0.88, 0.35 + 0.2 * ry, 0.12 }
            else
                [3]f32{ 0.38 + 0.15 * rx, 0.28 + 0.12 * ry, 0.26 + 0.12 * rz };

            self.particles[self.count] = .{
                .x = pos[0] + (rx - 0.5) * 16.0,
                .y = pos[1] + 2.0 + ry * 5.0,
                .z = pos[2] + (rz - 0.5) * 16.0,
                .vx = (rx - 0.5) * 0.9 + 0.3,
                .vy = -0.5 - ry * 0.6,
                .vz = (rz - 0.5) * 0.9,
                .life = 1.8 + 1.2 * ry,
                .max_life = 1.8 + 1.2 * ry,
                .color = col,
                .size = if (is_cinder) 0.04 else 0.05 + 0.03 * rx,
            };
            self.count += 1;
        }
    }

    /// Spawn orbital vortex ring of ethereal particles circling player during portal charge
    pub fn spawnPortalVortex(self: *ParticleSystem, center: [3]f32, radius: f32, count: usize, time_offset: f32) void {
        var i: usize = 0;
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            const frac = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(count));
            const angle = frac * std.math.pi * 2.0 + time_offset * 3.5;
            const r = radius + 0.08 * @sin(frac * 12.0);
            const px = center[0] + @cos(angle) * r;
            const pz = center[2] + @sin(angle) * r;
            const py = center[1] + (frac - 0.5) * 1.4;

            // Tangential orbital velocity + upward lift
            const tang_x = -@sin(angle) * 2.2;
            const tang_z = @cos(angle) * 2.2;

            self.particles[self.count] = .{
                .x = px,
                .y = py,
                .z = pz,
                .vx = tang_x,
                .vy = 0.8 + 0.4 * frac,
                .vz = tang_z,
                .life = 0.45,
                .max_life = 0.45,
                .color = .{ 0.82, 0.20, 0.96 },
                .size = 0.05,
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
            // Bubbles float upward against gravity; embers/smoke drift upward softly; debris falls
            const is_bubble = (p.color[0] > 0.6 and p.color[1] > 0.8 and p.color[2] > 0.9);
            const is_ember = (p.color[0] > 0.9 and p.color[2] < 0.2); // Fiery orange/yellow
            const is_smoke = (p.color[0] < 0.35 and p.color[1] < 0.35 and p.color[2] < 0.35); // Dark smoke
            const is_portal = (p.color[0] > 0.6 and p.color[1] < 0.3 and p.color[2] > 0.8); // Purple ethereal
            const is_ash = (p.max_life >= 1.5 and p.color[0] < 0.9 and p.color[1] < 0.5 and p.color[2] < 0.45); // Nether ash flake
            if (is_bubble) {
                p.vy = @min(1.5, p.vy + 1.0 * dt);
            } else if (is_ember or is_smoke) {
                // Thermal lift: rising gently
                p.vy = @max(0.2, p.vy - 3.0 * dt);
            } else if (is_portal) {
                // Weightless swirling drift
                p.vy = p.vy * 0.98;
            } else if (is_ash) {
                // Slow ambient downward settling with horizontal air drift
                p.vy = @max(-0.9, p.vy - 0.4 * dt);
                p.vx += 0.05 * dt;
            } else {
                p.vy -= gravity * dt;
            }
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

test "bubble particle buoyancy and life" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnBubble(.{ 1.0, 2.0, 3.0 }, 4);
    try std.testing.expectEqual(ps.count, 4);
    const initial_y = ps.particles[0].y;
    // Tick forward 0.2s: bubbles rise upward
    ps.tick(0.2);
    try std.testing.expect(ps.particles[0].y > initial_y);
    // Tick forward 1.0s: bubbles expire
    ps.tick(1.0);
    try std.testing.expectEqual(ps.count, 0);
}

test "water splash particles spawn and vertical burst" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnWaterSplash(.{ 5.0, 10.0, 15.0 }, 8);
    try std.testing.expectEqual(ps.count, 8);
    try std.testing.expect(ps.particles[0].vy > 2.0);
    // Water splash has distinct blueish tint
    try std.testing.expect(ps.particles[0].color[2] > ps.particles[0].color[0]);
    ps.tick(0.1);
    try std.testing.expect(ps.particles[0].y > 10.0);
    // After 1.0s, short-lived droplets expire
    ps.tick(1.0);
    try std.testing.expectEqual(ps.count, 0);
}

test "spawnBreathMist forward direction and mist color" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnBreathMist(.{ 0.0, 1.6, 0.0 }, .{ 0.0, 0.0, 1.0 }, 6);
    try std.testing.expectEqual(ps.count, 6);
    // Forward velocity along Z > 0
    try std.testing.expect(ps.particles[0].vz > 0.5);
    // Pale mist color
    try std.testing.expect(ps.particles[0].color[0] > 0.8);
    try std.testing.expect(ps.particles[0].color[1] > 0.9);
    ps.tick(0.1);
    try std.testing.expect(ps.particles[0].z > 0.0);
    ps.tick(1.0);
    try std.testing.expectEqual(ps.count, 0);
}

test "spawnBoatWake lateral spread and foam coloring" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    // Cruising along +X: perp is along Z
    ps.spawnBoatWake(.{ 0.0, 1.0, 0.0 }, .{ 1.0, 0.0, 0.0 }, 4);
    try std.testing.expectEqual(ps.count, 4);
    // Whitish-blue foam color
    try std.testing.expect(ps.particles[0].color[0] >= 0.7);
    try std.testing.expect(ps.particles[0].color[2] >= 0.9);
    // Lateral Z velocity is non-zero
    try std.testing.expect(@abs(ps.particles[0].vz) > 0.1);
    ps.tick(0.1);
    try std.testing.expect(ps.particles[0].y > 1.0);
    ps.tick(1.0);
    try std.testing.expectEqual(ps.count, 0);
}

test "spawnLavaEmber rising embers and smoke coloring" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnLavaEmber(.{ 2.0, 5.0, 8.0 }, 6);
    try std.testing.expectEqual(ps.count, 6);
    // At least one ember and one smoke puff
    var found_ember = false;
    var found_smoke = false;
    for (ps.particles[0..6]) |p| {
        if (p.color[0] > 0.9 and p.color[2] < 0.2) found_ember = true;
        if (p.color[0] < 0.35 and p.color[1] < 0.35 and p.color[2] < 0.35) found_smoke = true;
    }
    try std.testing.expect(found_ember);
    try std.testing.expect(found_smoke);

    // Initial upwards velocity
    try std.testing.expect(ps.particles[0].vy > 0.5);
    const initial_y = ps.particles[0].y;
    ps.tick(0.1);
    try std.testing.expect(ps.particles[0].y > initial_y);
    // Expire after 1.5s
    ps.tick(1.5);
    try std.testing.expectEqual(ps.count, 0);
}

test "spawnBurnSparks fiery spark coloring and upward spray" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnBurnSparks(.{ 1.0, 2.0, 3.0 }, 4);
    try std.testing.expectEqual(ps.count, 4);
    for (ps.particles[0..4]) |p| {
        // Red component dominant
        try std.testing.expect(p.color[0] >= 0.9);
        try std.testing.expect(p.vy > 0.0);
    }
}

test "spawnPortalVortex orbital ring coordinate and velocity distribution" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnPortalVortex(.{ 5.0, 10.0, 15.0 }, 1.2, 8, 0.0);
    try std.testing.expectEqual(ps.count, 8);
    for (ps.particles[0..8]) |p| {
        // Ethereal purple color
        try std.testing.expect(p.color[0] >= 0.8);
        try std.testing.expect(p.color[2] >= 0.9);
        // Upward lift
        try std.testing.expect(p.vy >= 0.8);
        // Position within orbital radius roughly
        const dx = p.x - 5.0;
        const dz = p.z - 15.0;
        const dist = @sqrt(dx * dx + dz * dz);
        try std.testing.expectApproxEqAbs(@as(f32, 1.2), dist, 0.15);
    }
}

test "spawnPortalParticles purple color and weightless drift" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnPortalParticles(.{ 10.0, 5.0, 20.0 }, 4);
    try std.testing.expectEqual(ps.count, 4);
    // Purple color: high red & blue, low green
    try std.testing.expect(ps.particles[0].color[0] >= 0.6);
    try std.testing.expect(ps.particles[0].color[1] <= 0.3);
    try std.testing.expect(ps.particles[0].color[2] >= 0.8);

    ps.tick(0.1);
    try std.testing.expectEqual(ps.count, 4);
    ps.tick(1.5);
    try std.testing.expectEqual(ps.count, 0);
}

test "spawnNetherAsh particle distribution and gentle settling tick" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnNetherAsh(.{ 20.0, 10.0, 20.0 }, 6);
    try std.testing.expectEqual(ps.count, 6);
    for (ps.particles[0..6]) |p| {
        // Slow downward drift initial velocity
        try std.testing.expect(p.vy < 0.0);
        try std.testing.expect(p.life >= 1.5);
    }
    // Tick: ash particles must not plummet with heavy gravity (18 m/s^2)
    const initial_vy = ps.particles[0].vy;
    ps.tick(0.1);
    try std.testing.expect(ps.particles[0].vy > initial_vy - 1.0);
}
