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

    /// Spawn ascending luminous sky-beam particles from an active beacon block
        /// Spawn soaring celestial violet / magenta End Gateway sky-beam particles
    pub fn spawnGatewayBeam(self: *ParticleSystem, bx: i32, by: i32, bz: i32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(bx *% 89 +% by *% 31 +% bz *% 53)) +% @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const angle = @as(f32, @floatFromInt((seed >> 16) % 360)) * (std.math.pi / 180.0);
            const radius = 0.05 + @as(f32, @floatFromInt((seed >> 8) % 25)) / 100.0;
            const px = @as(f32, @floatFromInt(bx)) + 0.5 + @cos(angle) * radius;
            const pz = @as(f32, @floatFromInt(bz)) + 0.5 + @sin(angle) * radius;
            const py = @as(f32, @floatFromInt(by)) + 0.5;

            // Cosmic violet core to radiant magenta aura
            const is_core = ((seed >> 4) % 3) == 0;
            const col: [3]f32 = if (is_core) .{ 0.85, 0.40, 1.0 } else .{ 0.60, 0.15, 0.95 };
            const vy = 14.0 + @as(f32, @floatFromInt((seed >> 12) % 40)) / 10.0;

            self.particles[self.count] = .{
                .x = px,
                .y = py,
                .z = pz,
                .vx = @cos(angle) * 0.08,
                .vy = vy,
                .vz = @sin(angle) * 0.08,
                .life = 0.9,
                .max_life = 0.9,
                .color = col,
                .size = 0.08,
            };
            self.count += 1;
        }
    }

pub fn spawnBeaconBeam(self: *ParticleSystem, bx: i32, by: i32, bz: i32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(bx *% 83 +% by *% 29 +% bz *% 47)) +% @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const angle = @as(f32, @floatFromInt((seed >> 16) % 360)) * (std.math.pi / 180.0);
            const radius = 0.05 + @as(f32, @floatFromInt((seed >> 8) % 20)) / 100.0;
            const px = @as(f32, @floatFromInt(bx)) + 0.5 + @cos(angle) * radius;
            const pz = @as(f32, @floatFromInt(bz)) + 0.5 + @sin(angle) * radius;
            const py = @as(f32, @floatFromInt(by)) + 1.05;

            // Radiant cyan to pure white core tint
            const is_core = ((seed >> 4) % 3) == 0;
            const col: [3]f32 = if (is_core) .{ 0.95, 1.0, 1.0 } else .{ 0.35, 0.88, 1.0 };
            const vy = 12.0 + @as(f32, @floatFromInt((seed >> 12) % 40)) / 10.0;

            self.particles[self.count] = .{
                .x = px,
                .y = py,
                .z = pz,
                .vx = @cos(angle) * 0.1,
                .vy = vy,
                .vz = @sin(angle) * 0.1,
                .life = 0.8,
                .max_life = 0.8,
                .color = col,
                .size = 0.09,
            };
            self.count += 1;
        }
    }

    /// Spawn spinning ember sparks swirling around an active spawner cage
    pub fn spawnSpawnerFlames(self: *ParticleSystem, bx: i32, by: i32, bz: i32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(bx *% 73 +% by *% 19 +% bz *% 37)) +% @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const angle = @as(f32, @floatFromInt((seed >> 16) % 360)) * (std.math.pi / 180.0);
            const radius = 0.2 + @as(f32, @floatFromInt((seed >> 8) % 25)) / 100.0;
            const px = @as(f32, @floatFromInt(bx)) + 0.5 + @cos(angle) * radius;
            const pz = @as(f32, @floatFromInt(bz)) + 0.5 + @sin(angle) * radius;
            const py = @as(f32, @floatFromInt(by)) + 0.3 + @as(f32, @floatFromInt((seed >> 4) % 40)) / 100.0;

            self.particles[self.count] = .{
                .x = px,
                .y = py,
                .z = pz,
                .vx = -@sin(angle) * 0.8,
                .vy = 0.4 + @as(f32, @floatFromInt((seed >> 12) % 30)) / 100.0,
                .vz = @cos(angle) * 0.8,
                .life = 0.4,
                .max_life = 0.4,
                .color = .{ 1.0, 0.55, 0.1 },
                .size = 0.05,
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

    /// Spawn radiant golden-amber shimmer sparkle particles drifting from glowing glowstone clusters
    pub fn spawnGlowstoneShimmer(self: *ParticleSystem, pos: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 64.0)))) *% 37 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[1] * 64.0)))) *% 29 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 64.0)))) *% 19 +%
            @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const rz = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;

            // Radiant golden-yellow amber with bright crystalline specular core
            const is_glint = (rx > 0.7);
            const col = if (is_glint)
                [3]f32{ 1.0, 0.96, 0.70 }
            else
                [3]f32{ 0.98, 0.82 + 0.12 * ry, 0.28 };

            self.particles[self.count] = .{
                .x = pos[0] + (rx - 0.5) * 0.9,
                .y = pos[1] - 0.1 - ry * 0.4,
                .z = pos[2] + (rz - 0.5) * 0.9,
                .vx = (rx - 0.5) * 0.35,
                .vy = -0.25 - ry * 0.45, // Gentle downward drift as radiant dust falls
                .vz = (rz - 0.5) * 0.35,
                .life = 0.7 + 0.4 * ry,
                .max_life = 0.7 + 0.4 * ry,
                .color = col,
                .size = if (is_glint) 0.05 else 0.035,
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

    /// Spawn rising campfire smoke particles. When signal_fire is true (hay bale beneath), particles rise much higher and persist longer.
    pub fn spawnCampfireSmoke(self: *ParticleSystem, bx: i32, by: i32, bz: i32, is_soul: bool, signal_fire: bool, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(bx *% 73 +% by *% 37 +% bz *% 53)) +% @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0 - 0.5;
            const rz = @as(f32, @floatFromInt((seed >> 8) % 100)) / 100.0 - 0.5;
            const px = @as(f32, @floatFromInt(bx)) + 0.5 + rx * 0.4;
            const py = @as(f32, @floatFromInt(by)) + 0.45;
            const pz = @as(f32, @floatFromInt(bz)) + 0.5 + rz * 0.4;

            const base_color: [3]f32 = if (is_soul)
                .{ 0.15, 0.28, 0.32 } // Ethereal cyan-tinted soul smoke
            else
                .{ 0.25, 0.25, 0.26 }; // Charcoal wood smoke

            // Signal fire smoke particles live 3.5s and climb faster (up to ~24 blocks high)
            const life: f32 = if (signal_fire) 3.5 else 1.4;
            const vy: f32 = if (signal_fire) 4.2 + (rx * 0.5) else 1.6 + (rx * 0.3);

            self.particles[self.count] = .{
                .x = px,
                .y = py,
                .z = pz,
                .vx = rx * 0.2,
                .vy = vy,
                .vz = rz * 0.2,
                .life = life,
                .max_life = life,
                .color = base_color,
                .size = if (signal_fire) 0.13 else 0.08,
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

    /// Spawn magnetic attunement particles swirling around a lodestone block upon compass binding
    pub fn spawnLodestoneAttunement(self: *ParticleSystem, pos: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 64.0)))) *% 43 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[1] * 64.0)))) *% 31 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 64.0)))) *% 23 +%
            @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const ry = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const rz = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;

            const angle = rx * std.math.pi * 2.0;
            const dist = 0.5 + 0.5 * ry;
            const px = pos[0] + @cos(angle) * dist;
            const pz = pos[2] + @sin(angle) * dist;
            const py = pos[1] + 0.1 + 0.8 * rz;

            // Swirling inward magnetic velocity
            const inward_x = (pos[0] - px) * 1.5;
            const inward_z = (pos[2] - pz) * 1.5;
            const tang_x = -@sin(angle) * 1.2;
            const tang_z = @cos(angle) * 1.2;

            // Radiant cyan-teal magnetic hue
            const col = [3]f32{ 0.20 + 0.15 * rx, 0.85 + 0.12 * ry, 0.95 };

            self.particles[self.count] = .{
                .x = px,
                .y = py,
                .z = pz,
                .vx = inward_x + tang_x,
                .vy = 0.4 + 0.5 * rz,
                .vz = inward_z + tang_z,
                .life = 0.6 + 0.3 * ry,
                .max_life = 0.6 + 0.3 * ry,
                .color = col,
                .size = 0.05 + 0.03 * rx,
            };
            self.count += 1;
        }
    }

    /// Spawn gentle radiant white crystalline sparkle particles ascending from an end rod
    pub fn spawnEndRodSparks(self: *ParticleSystem, bx: i32, by: i32, bz: i32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(bx *% 89 +% by *% 31 +% bz *% 43)) +% @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const rx = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0 - 0.5;
            const rz = @as(f32, @floatFromInt((seed >> 8) % 100)) / 100.0 - 0.5;
            const px = @as(f32, @floatFromInt(bx)) + 0.5 + rx * 0.25;
            const py = @as(f32, @floatFromInt(by)) + 0.5;
            const pz = @as(f32, @floatFromInt(bz)) + 0.5 + rz * 0.25;

            // Pure radiant white core with faint lavender tint
            const col = [3]f32{ 0.94, 0.94, 1.0 };

            self.particles[self.count] = .{
                .x = px,
                .y = py,
                .z = pz,
                .vx = rx * 0.15,
                .vy = 0.45 + (rx * 0.1),
                .vz = rz * 0.15,
                .life = 0.8,
                .max_life = 0.8,
                .color = col,
                .size = 0.04,
            };
            self.count += 1;
        }
    }

    /// Spawn vibrant radial multicolored firework burst particles
    pub fn spawnFireworkBurst(self: *ParticleSystem, pos: [3]f32, count: usize) void {
        var i: usize = 0;
        var seed: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(pos[0] * 64.0)))) *% 59 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[1] * 64.0)))) *% 41 +%
            @as(u32, @bitCast(@as(i32, @intFromFloat(pos[2] * 64.0)))) *% 29 +%
            @as(u32, @intCast(self.count));
        while (i < count and self.count < MAX_PARTICLES) : (i += 1) {
            seed = seed *% 1103515245 +% 12345;
            const u = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const v = @as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0;
            seed = seed *% 1103515245 +% 12345;
            const speed_mult = 3.5 + 3.0 * (@as(f32, @floatFromInt((seed >> 16) % 100)) / 100.0);

            // Uniform sphere distribution
            const theta = u * 2.0 * std.math.pi;
            const phi = std.math.acos(2.0 * v - 1.0);
            const dx = @sin(phi) * @cos(theta);
            const dy = @cos(phi);
            const dz = @sin(phi) * @sin(theta);

            // Multicolored palette: red, green, blue, gold, purple, cyan
            const col_idx = (seed >> 8) % 6;
            const col = switch (col_idx) {
                0 => [3]f32{ 1.0, 0.20, 0.25 }, // Ruby red
                1 => [3]f32{ 0.20, 0.95, 0.30 }, // Emerald green
                2 => [3]f32{ 0.25, 0.55, 1.0 },  // Sapphire blue
                3 => [3]f32{ 1.0, 0.85, 0.15 },  // Gold
                4 => [3]f32{ 0.90, 0.25, 0.95 }, // Magenta
                else => [3]f32{ 0.20, 0.90, 0.95 }, // Cyan
            };

            self.particles[self.count] = .{
                .x = pos[0],
                .y = pos[1],
                .z = pos[2],
                .vx = dx * speed_mult,
                .vy = dy * speed_mult + 1.2,
                .vz = dz * speed_mult,
                .life = 0.75 + 0.35 * u,
                .max_life = 0.75 + 0.35 * u,
                .color = col,
                .size = 0.07 + 0.03 * v,
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
            const is_signal_smoke = is_smoke and (p.max_life > 2.0);
            const is_portal = (p.color[0] > 0.6 and p.color[1] < 0.3 and p.color[2] > 0.8); // Purple ethereal
            const is_ash = (p.max_life >= 1.5 and p.color[0] < 0.9 and p.color[1] < 0.5 and p.color[2] < 0.45); // Nether ash flake
            const is_shimmer = (p.color[0] > 0.95 and p.color[1] > 0.8 and p.color[2] > 0.25); // Golden shimmer sparkle
            const is_lodestone_spark = (p.color[0] < 0.40 and p.color[1] > 0.80 and p.color[2] > 0.90); // Cyan magnetic attunement spark
            const is_firework = (p.max_life >= 0.75 and p.max_life <= 1.20 and (@abs(p.vx) > 0.5 or @abs(p.vz) > 0.5));
            if (is_bubble) {
                p.vy = @min(1.5, p.vy + 1.0 * dt);
            } else if (is_signal_smoke) {
                // High-altitude signal smoke lift
                p.vy = @max(1.8, p.vy - 0.7 * dt);
                p.size = @min(0.35, p.size + 0.04 * dt);
            } else if (is_ember or is_smoke) {
                // Thermal lift: rising gently
                p.vy = @max(0.2, p.vy - 3.0 * dt);
                p.size = @min(0.22, p.size + 0.03 * dt);
            } else if (is_portal) {
                // Weightless swirling drift
                p.vy = p.vy * 0.98;
            } else if (is_ash) {
                // Slow ambient downward settling with horizontal air drift
                p.vy = @max(-0.9, p.vy - 0.4 * dt);
                p.vx += 0.05 * dt;
            } else if (is_shimmer) {
                // Weightless glittering float with gentle deceleration
                p.vy = @max(-0.4, p.vy * 0.96);
                p.vx = p.vx * 0.96;
                p.vz = p.vz * 0.96;
            } else if (is_lodestone_spark) {
                // Magnetic spark gentle upward float and drag
                p.vy = @max(0.05, p.vy * 0.95);
                p.vx = p.vx * 0.94;
                p.vz = p.vz * 0.94;
            } else if (is_firework) {
                // High-speed firework spark deceleration & slow downward arc
                p.vy -= 6.0 * dt;
                p.vx *= 0.92;
                p.vz *= 0.92;
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

test "spawnGlowstoneShimmer particle properties and gentle floating physics" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnGlowstoneShimmer(.{ 10.0, 15.0, 20.0 }, 4);
    try std.testing.expectEqual(ps.count, 4);
    for (ps.particles[0..4]) |p| {
        // Radiant golden-yellow color (high red and green)
        try std.testing.expect(p.color[0] >= 0.95);
        try std.testing.expect(p.color[1] >= 0.8);
        try std.testing.expect(p.vy < 0.0);
    }
    const initial_vy = ps.particles[0].vy;
    ps.tick(0.1);
    // Does not fall with heavy gravity (-18 m/s^2)
    try std.testing.expect(ps.particles[0].vy > initial_vy - 0.5);
}

test "spawnSpawnerFlames creates orbiting particles" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnSpawnerFlames(10, 8, 10, 4);
    try std.testing.expectEqual(@as(usize, 4), ps.count);
    try std.testing.expect(ps.particles[0].y >= 8.3);
    try std.testing.expectEqual(ps.particles[0].color[0], 1.0);
}

test "spawnCampfireSmoke creates standard and high-altitude signal smoke" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    // Standard campfire smoke
    ps.spawnCampfireSmoke(10, 5, 10, false, false, 2);
    try std.testing.expectEqual(@as(usize, 2), ps.count);
    try std.testing.expect(ps.particles[0].max_life < 2.0);
    try std.testing.expect(ps.particles[0].vy < 3.0);

    // Signal fire smoke
    ps.spawnCampfireSmoke(10, 5, 10, false, true, 2);
    try std.testing.expectEqual(@as(usize, 4), ps.count);
    try std.testing.expect(ps.particles[2].max_life > 2.0);
    try std.testing.expect(ps.particles[2].vy > 3.0);
}

test "spawnBeaconBeam creates ascending beam particles" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnBeaconBeam(5, 4, 5, 4);
    try std.testing.expectEqual(@as(usize, 4), ps.count);
    try std.testing.expect(ps.particles[0].vy > 10.0);
    try std.testing.expect(ps.particles[0].y > 5.0);
    // Colors should be cyan or white core
    try std.testing.expect(ps.particles[0].color[2] > 0.8);
}

test "spawnLodestoneAttunement creates cyan magnetic sparks with inward swirl" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnLodestoneAttunement(.{ 10.0, 15.0, 20.0 }, 6);
    try std.testing.expectEqual(@as(usize, 6), ps.count);
    for (ps.particles[0..6]) |p| {
        try std.testing.expect(p.color[0] < 0.40);
        try std.testing.expect(p.color[1] > 0.80);
        try std.testing.expect(p.color[2] > 0.90);
        try std.testing.expect(p.max_life >= 0.6);
    }
}

test "spawnEndRodSparks creates ascending white sparkle particles" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnEndRodSparks(5, 4, 5, 4);
    try std.testing.expectEqual(@as(usize, 4), ps.count);
    try std.testing.expect(ps.particles[0].vy > 0.3);
    try std.testing.expect(ps.particles[0].y >= 4.5);
    try std.testing.expect(ps.particles[0].color[0] >= 0.9);
    try std.testing.expect(ps.particles[0].color[2] >= 0.95);
}

test "spawnFireworkBurst creates radial multicolored spark sphere" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    ps.spawnFireworkBurst(.{ 5.0, 10.0, 5.0 }, 16);
    try std.testing.expectEqual(@as(usize, 16), ps.count);
    var has_positive_vx = false;
    var has_negative_vx = false;
    for (ps.particles[0..16]) |p| {
        if (p.vx > 0.5) has_positive_vx = true;
        if (p.vx < -0.5) has_negative_vx = true;
        try std.testing.expect(p.max_life >= 0.75);
    }
    try std.testing.expect(has_positive_vx and has_negative_vx);
}

test "spawnGatewayBeam creates ascending celestial violet beam particles" {
    var ps = ParticleSystem{
        .particles = undefined,
        .count = 0,
        .vao = 0,
        .vbo = 0,
        .program = 0,
    };
    try std.testing.expectEqual(@as(usize, 0), ps.count);

    ps.spawnGatewayBeam(32, 10, 0, 6);
    try std.testing.expectEqual(@as(usize, 6), ps.count);

    // Verify upward soaring velocity and violet/magenta color bounds
    for (ps.particles[0..6]) |p| {
        try std.testing.expect(p.vy >= 14.0);
        try std.testing.expect(p.color[0] >= 0.5); // red/magenta
        try std.testing.expect(p.color[2] >= 0.9); // violet blue channel
    }
}
