const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

pub const Camera = struct {
    position: Vec3,
    yaw: f32,
    pitch: f32,
    speed: f32,
    sensitivity: f32,
    fov: f32,

    pub fn init() Camera {
        return .{
            .position = Vec3.init(0, 64, 0),
            .yaw = -std.math.pi / 2.0,
            .pitch = 0,
            .speed = 5.0,
            .sensitivity = 0.002,
            .fov = 70.0,
        };
    }

    pub fn front(self: Camera) Vec3 {
        return Vec3.normalize(.{
            .x = @cos(self.yaw) * @cos(self.pitch),
            .y = @sin(self.pitch),
            .z = @sin(self.yaw) * @cos(self.pitch),
        });
    }

    pub fn right(self: Camera) Vec3 {
        const f = self.front();
        return Vec3.normalize(Vec3.cross(f, Vec3.init(0, 1, 0)));
    }

    pub fn viewMatrix(self: Camera) Mat4 {
        const target = Vec3.add(self.position, self.front());
        return Mat4.lookAt(self.position, target, Vec3.init(0, 1, 0));
    }

    pub fn projectionMatrix(self: Camera, aspect: f32) Mat4 {
        return Mat4.perspective(
            std.math.degreesToRadians(@as(f32, self.fov)),
            aspect, 0.1, 1000.0,
        );
    }

    /// Handle a single key press/release event.
    /// Call from the render loop: poll glfwGetKey for each movement key
    /// and pass the result here.
    pub fn processKey(self: *Camera, key: c_int, action: c_int, dt: f32) void {
        if (action != c.GLFW_PRESS) return;
        const vel = self.speed * dt;
        const f = self.front();
        const r = self.right();
        switch (key) {
            c.GLFW_KEY_W => self.position = Vec3.add(self.position, f.scale(vel)),
            c.GLFW_KEY_S => self.position = Vec3.sub(self.position, f.scale(vel)),
            c.GLFW_KEY_A => self.position = Vec3.sub(self.position, r.scale(vel)),
            c.GLFW_KEY_D => self.position = Vec3.add(self.position, r.scale(vel)),
            c.GLFW_KEY_SPACE => self.position.y += vel,
            c.GLFW_KEY_LEFT_SHIFT => self.position.y -= vel,
            else => {},
        }
    }

    pub fn processMouse(self: *Camera, x_offset: f32, y_offset: f32) void {
        self.yaw += x_offset * self.sensitivity;
        self.pitch -= y_offset * self.sensitivity;
        const max_pitch = std.math.degreesToRadians(@as(f32, 89.0));
        self.pitch = @max(-max_pitch, @min(max_pitch, self.pitch));
    }
};

test "camera default position" {
    const cam = Camera.init();
    try std.testing.expectEqual(cam.position.x, 0);
    try std.testing.expectEqual(cam.position.y, 64);
}

test "camera default yaw faces -Z" {
    const cam = Camera.init();
    const f = cam.front();
    try std.testing.expectApproxEqAbs(f.x, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(f.y, 0.0, 0.001);
    try std.testing.expectApproxEqAbs(f.z, -1.0, 0.001);
}

test "camera right vector" {
    const cam = Camera.init();
    const r = cam.right();
    try std.testing.expectApproxEqAbs(r.x, 1.0, 0.001);
}

test "camera view matrix" {
    const cam = Camera.init();
    const view = cam.viewMatrix();
    try std.testing.expectApproxEqAbs(view.data[0][0], 1.0, 0.001);
}

test "camera projection matrix" {
    const cam = Camera.init();
    const proj = cam.projectionMatrix(16.0 / 9.0);
    try std.testing.expect(proj.data[0][0] != 0);
}
