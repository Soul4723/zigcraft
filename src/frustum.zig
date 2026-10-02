const std = @import("std");
const math = @import("math.zig");

/// Plane: normal + distance, normalized. Inside = dot(n,p) + d >= 0.
pub const Plane = struct {
    normal: math.Vec3,
    d: f32,

    pub fn distanceTo(self: Plane, p: math.Vec3) f32 {
        return math.Vec3.dot(self.normal, p) + self.d;
    }
};

pub const Frustum = struct {
    planes: [6]Plane,

    /// Extract 6 planes from column-major viewProj (data[col][row]).
    /// Rows of the matrix give the plane combos.
    pub fn fromMatrix(m: math.Mat4) Frustum {
        const d = m.data;
        // row r = (d[0][r], d[1][r], d[2][r], d[3][r])
        const row0 = .{ d[0][0], d[1][0], d[2][0], d[3][0] };
        const row1 = .{ d[0][1], d[1][1], d[2][1], d[3][1] };
        const row2 = .{ d[0][2], d[1][2], d[2][2], d[3][2] };
        const row3 = .{ d[0][3], d[1][3], d[2][3], d[3][3] };
        return .{ .planes = .{
            normPlane(row3[0] + row0[0], row3[1] + row0[1], row3[2] + row0[2], row3[3] + row0[3]), // left
            normPlane(row3[0] - row0[0], row3[1] - row0[1], row3[2] - row0[2], row3[3] - row0[3]), // right
            normPlane(row3[0] + row1[0], row3[1] + row1[1], row3[2] + row1[2], row3[3] + row1[3]), // bottom
            normPlane(row3[0] - row1[0], row3[1] - row1[1], row3[2] - row1[2], row3[3] - row1[3]), // top
            normPlane(row3[0] + row2[0], row3[1] + row2[1], row3[2] + row2[2], row3[3] + row2[3]), // near
            normPlane(row3[0] - row2[0], row3[1] - row2[1], row3[2] - row2[2], row3[3] - row2[3]), // far
        } };
    }

    /// AABB test: culled only if ALL 8 corners outside any one plane.
    pub fn containsBox(self: Frustum, min: math.Vec3, max: math.Vec3) bool {
        for (self.planes) |pl| {
            var outside: u32 = 0;
            var i: usize = 0;
            while (i < 8) : (i += 1) {
                const px = if (i & 1 == 0) min.x else max.x;
                const py = if (i & 2 == 0) min.y else max.y;
                const pz = if (i & 4 == 0) min.z else max.z;
                if (pl.distanceTo(math.Vec3.init(px, py, pz)) < 0) outside += 1;
            }
            if (outside == 8) return false;
        }
        return true;
    }
};

fn normPlane(a: f32, b: f32, cc: f32, dd: f32) Plane {
    const len = @sqrt(a * a + b * b + cc * cc);
    return .{ .normal = math.Vec3.init(a / len, b / len, cc / len), .d = dd / len };
}

test "box in front of camera is inside" {
    const proj = math.Mat4.perspective(std.math.degreesToRadians(@as(f32, 70)), 16.0 / 9.0, 0.1, 1000.0);
    const view = math.Mat4.lookAt(
        math.Vec3.init(0, 0, 5),
        math.Vec3.init(0, 0, 0),
        math.Vec3.init(0, 1, 0),
    );
    const vp = math.Mat4.mul(proj, view);
    const fr = Frustum.fromMatrix(vp);
    try std.testing.expect(fr.containsBox(math.Vec3.init(-1, -1, -1), math.Vec3.init(1, 1, 1)));
}

test "box behind camera is culled" {
    const proj = math.Mat4.perspective(std.math.degreesToRadians(@as(f32, 70)), 16.0 / 9.0, 0.1, 1000.0);
    const view = math.Mat4.lookAt(
        math.Vec3.init(0, 0, 5),
        math.Vec3.init(0, 0, 0),
        math.Vec3.init(0, 1, 0),
    );
    const vp = math.Mat4.mul(proj, view);
    const fr = Frustum.fromMatrix(vp);
    // Fully behind camera (z > 5, camera looks -z).
    try std.testing.expect(!fr.containsBox(math.Vec3.init(-1, -1, 10), math.Vec3.init(1, 1, 12)));
}

test "box far beyond far plane is culled" {
    const proj = math.Mat4.perspective(std.math.degreesToRadians(@as(f32, 70)), 16.0 / 9.0, 0.1, 100.0);
    const view = math.Mat4.lookAt(
        math.Vec3.init(0, 0, 5),
        math.Vec3.init(0, 0, 0),
        math.Vec3.init(0, 1, 0),
    );
    const vp = math.Mat4.mul(proj, view);
    const fr = Frustum.fromMatrix(vp);
    try std.testing.expect(!fr.containsBox(math.Vec3.init(-1, -1, -500), math.Vec3.init(1, 1, -400)));
}

test "gigantic box containing frustum is inside" {
    const proj = math.Mat4.perspective(std.math.degreesToRadians(@as(f32, 70)), 16.0 / 9.0, 0.1, 1000.0);
    const view = math.Mat4.lookAt(
        math.Vec3.init(0, 0, 5),
        math.Vec3.init(0, 0, 0),
        math.Vec3.init(0, 1, 0),
    );
    const vp = math.Mat4.mul(proj, view);
    const fr = Frustum.fromMatrix(vp);
    try std.testing.expect(fr.containsBox(math.Vec3.init(-1000, -1000, -1000), math.Vec3.init(1000, 1000, 1000)));
}
