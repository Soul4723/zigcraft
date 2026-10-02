const std = @import("std");

/// 3-component vector. Used for positions, directions, colors.
pub const Vec3 = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return .{ .x = x, .y = y, .z = z };
    }

    pub fn add(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
    }

    pub fn sub(a: Vec3, b: Vec3) Vec3 {
        return .{ .x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z };
    }

    pub fn scale(v: Vec3, s: f32) Vec3 {
        return .{ .x = v.x * s, .y = v.y * s, .z = v.z * s };
    }

    pub fn dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }

    pub fn len(v: Vec3) f32 {
        return @sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
    }

    pub fn normalize(v: Vec3) Vec3 {
        const l = v.len();
        if (l == 0) return v;
        return v.scale(1.0 / l);
    }
};

test "Vec3 add" {
    const a = Vec3.init(1, 2, 3);
    const b = Vec3.init(4, 5, 6);
    const result = Vec3.add(a, b);
    try std.testing.expectEqual(result.x, 5);
    try std.testing.expectEqual(result.y, 7);
    try std.testing.expectEqual(result.z, 9);
}

test "Vec3 normalize" {
    const v = Vec3.init(3, 0, 0);
    const n = Vec3.normalize(v);
    try std.testing.expectEqual(n.x, 1.0);
    try std.testing.expectApproxEqAbs(n.len(), 1.0, 0.001);
}

test "Vec3 cross product" {
    const x = Vec3.init(1, 0, 0);
    const y = Vec3.init(0, 1, 0);
    const z = Vec3.cross(x, y);
    try std.testing.expectEqual(z.x, 0.0);
    try std.testing.expectEqual(z.y, 0.0);
    try std.testing.expectEqual(z.z, 1.0);
}

test "Vec3 zero length" {
    const z = Vec3.init(0, 0, 0);
    const n = Vec3.normalize(z);
    try std.testing.expectEqual(n.x, 0.0);
}

pub const Mat4 = extern struct {
    data: [4][4]f32,

    pub fn identity() Mat4 {
        return .{ .data = .{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ 0, 0, 0, 1 },
        }};
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var result: Mat4 = .{ .data = .{
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
            .{ 0, 0, 0, 0 },
        }};
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            var row: usize = 0;
            while (row < 4) : (row += 1) {
                var sum: f32 = 0;
                var k: usize = 0;
                while (k < 4) : (k += 1) {
                    sum += a.data[k][row] * b.data[col][k];
                }
                result.data[col][row] = sum;
            }
        }
        return result;
    }

    pub fn translate(v: Vec3) Mat4 {
        return .{ .data = .{
            .{ 1, 0, 0, 0 },
            .{ 0, 1, 0, 0 },
            .{ 0, 0, 1, 0 },
            .{ v.x, v.y, v.z, 1 },
        }};
    }

    pub fn perspective(fov_radians: f32, aspect: f32, near: f32, far: f32) Mat4 {
        const f = 1.0 / @tan(fov_radians / 2.0);
        const range_inv = 1.0 / (near - far);
        return .{ .data = .{
            .{ f / aspect, 0, 0, 0 },
            .{ 0, f, 0, 0 },
            .{ 0, 0, (far + near) * range_inv, -1 },
            .{ 0, 0, 2.0 * far * near * range_inv, 0 },
        }};
    }

    pub fn lookAt(eye: Vec3, center: Vec3, up: Vec3) Mat4 {
        const f = Vec3.normalize(Vec3.sub(center, eye));
        const s = Vec3.normalize(Vec3.cross(f, up));
        const u = Vec3.cross(s, f);
        return .{ .data = .{
            .{ s.x, u.x, -f.x, 0 },
            .{ s.y, u.y, -f.y, 0 },
            .{ s.z, u.z, -f.z, 0 },
            .{ -Vec3.dot(s, eye), -Vec3.dot(u, eye), Vec3.dot(f, eye), 1 },
        }};
    }

    pub fn ptr(self: *const Mat4) [*c]const f32 {
        return @ptrCast(&self.data);
    }
};

test "identity matrix" {
    const m = Mat4.identity();
    try std.testing.expectEqual(m.data[0][0], 1.0);
    try std.testing.expectEqual(m.data[1][1], 1.0);
    try std.testing.expectEqual(m.data[0][1], 0.0);
}

test "identity mul is identity" {
    const id = Mat4.identity();
    const result = Mat4.mul(id, id);
    try std.testing.expectEqual(result.data[0][0], 1.0);
    try std.testing.expectEqual(result.data[3][3], 1.0);
    try std.testing.expectEqual(result.data[1][0], 0.0);
}

test "translate matrix" {
    const m = Mat4.translate(Vec3.init(5, 10, 15));
    try std.testing.expectEqual(m.data[3][0], 5.0);
    try std.testing.expectEqual(m.data[3][1], 10.0);
    try std.testing.expectEqual(m.data[3][2], 15.0);
    try std.testing.expectEqual(m.data[3][3], 1.0);
}

test "perspective" {
    const fov = std.math.degreesToRadians(@as(f32, 70.0));
    const proj = Mat4.perspective(fov, 16.0 / 9.0, 0.1, 1000.0);
    try std.testing.expect(proj.data[0][0] != 0);
    try std.testing.expect(proj.data[1][1] != 0);
    try std.testing.expectApproxEqAbs(proj.data[3][3], 0.0, 0.001);
}

test "lookAt" {
    const view = Mat4.lookAt(
        Vec3.init(0, 0, 0),
        Vec3.init(0, 0, -1),
        Vec3.init(0, 1, 0),
    );
    try std.testing.expectApproxEqAbs(view.data[0][0], 1.0, 0.001);
    try std.testing.expectApproxEqAbs(view.data[1][1], 1.0, 0.001);
}

test "ptr" {
    const m = Mat4.identity();
    const p = m.ptr();
    try std.testing.expectEqual(p[0], 1.0);
    try std.testing.expectEqual(p[5], 1.0);
}
