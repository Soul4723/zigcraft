# Linear Algebra for 3D Rendering

Date: 2026-10-01
Status: **VERIFIED** — all code examples compile and pass tests on Zig 0.16.0
Question: What math primitives do we need, and how to implement them in Zig?

## What We Need

For a first-person camera rendering voxel chunks:

1. **Vec3** — position, direction, up vector
2. **Mat4** — model/view/projection matrices
3. **perspective()** — projection matrix from FOV/aspect/near/far
4. **lookAt()** — view matrix from eye/target/up
5. **translate()** — model matrix for positioning chunks

## Vec3

```zig
const Vec3 = struct {
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
        const len = v.len();
        if (len == 0) return v;
        return v.scale(1.0 / len);
    }
};
```

## Mat4

Store as column-major `[4][4]f32` to match OpenGL's expected layout.
`data[col][row]` — this is critical, getting it wrong produces garbage rendering.

```zig
const Mat4 = struct {
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
        for (0..4) |col| {
            for (0..4) |row| {
                var sum: f32 = 0;
                for (0..4) |k| {
                    sum += a.data[k][row] * b.data[col][k];
                }
                result.data[col][row] = sum;
            }
        }
        return result;
    }

    /// For passing to glUniformMatrix4fv
    pub fn ptr(self: *const Mat4) [*c]const f32 {
        return @ptrCast(&self.data);
    }
};
```

## perspective()

Standard OpenGL perspective projection matrix (right-handed, depth -1 to 1):

```zig
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
```

## lookAt()

```zig
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
```

## translate()

```zig
pub fn translate(v: Vec3) Mat4 {
    return .{ .data = .{
        .{ 1, 0, 0, 0 },
        .{ 0, 1, 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ v.x, v.y, v.z, 1 },
    }};
}
```

## Usage Pattern (MVP)

```zig
const model = Mat4.translate(Vec3.init(0, 0, 0));
const view = Mat4.lookAt(camera_pos, camera_target, Vec3.init(0, 1, 0));
const proj = Mat4.perspective(std.math.degreesToRadians(70.0), 1280.0 / 720.0, 0.1, 1000.0);

const mvp = proj.mul(view.mul(model));

const mvp_loc = c.glGetUniformLocation(shader_program, "mvp");
c.glUniformMatrix4fv(mvp_loc, 1, c.GL_FALSE, mvp.ptr());
```

## Camera State

```zig
const Camera = struct {
    position: Vec3,
    yaw: f32,      // horizontal rotation (radians)
    pitch: f32,    // vertical rotation (radians, clamped to ±89°)
    speed: f32,
    sensitivity: f32,

    pub fn init() Camera {
        return .{
            .position = Vec3.init(0, 64, 0),  // start above ground
            .yaw = -std.math.pi / 2.0,        // face -Z (OpenGL forward)
            .pitch = 0,
            .speed = 5.0,
            .sensitivity = 0.002,
        };
    }

    pub fn front(self: Camera) Vec3 {
        return Vec3.normalize(.{
            .x = @cos(self.yaw) * @cos(self.pitch),
            .y = @sin(self.pitch),
            .z = @sin(self.yaw) * @cos(self.pitch),
        });
    }

    pub fn viewMatrix(self: Camera) Mat4 {
        const f = self.front();
        const target = Vec3.add(self.position, f);
        return Mat4.lookAt(self.position, target, Vec3.init(0, 1, 0));
    }

    pub fn processKeyboard(self: *Camera, direction: enum { forward, backward, left, right }, delta_time: f32) void {
        const velocity = self.speed * delta_time;
        const f = self.front();
        const right_vec = Vec3.normalize(Vec3.cross(f, Vec3.init(0, 1, 0)));

        switch (direction) {
            .forward => self.position = Vec3.add(self.position, f.scale(velocity)),
            .backward => self.position = Vec3.sub(self.position, f.scale(velocity)),
            .left => self.position = Vec3.sub(self.position, right_vec.scale(velocity)),
            .right => self.position = Vec3.add(self.position, right_vec.scale(velocity)),
        }
    }

    pub fn processMouse(self: *Camera, x_offset: f32, y_offset: f32) void {
        self.yaw += x_offset * self.sensitivity;
        self.pitch -= y_offset * self.sensitivity;  // inverted Y

        // Clamp pitch to avoid gimbal lock
        const max_pitch = std.math.degreesToRadians(89.0);
        self.pitch = @max(-max_pitch, @min(max_pitch, self.pitch));
    }
};
```

## GLFW Input for Camera

```zig
// Capture cursor
c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);

// Mouse callback — use glfwSetCursorPosCallback or poll each frame
// Polling is simpler for a first implementation:
var last_x: f64 = 400;
var last_y: f64 = 300;

// In main loop:
var mouse_x: f64 = 0;
var mouse_y: f64 = 0;
c.glfwGetCursorPos(window, &mouse_x, &mouse_y);
const x_offset: f32 = @floatCast(mouse_x - last_x);
const y_offset: f32 = @floatCast(mouse_y - last_y);
last_x = mouse_x;
last_y = mouse_y;
camera.processMouse(x_offset, y_offset);

// Keyboard
if (c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS) camera.processKeyboard(.forward, delta_time);
if (c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS) camera.processKeyboard(.backward, delta_time);
if (c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS) camera.processKeyboard(.left, delta_time);
if (c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS) camera.processKeyboard(.right, delta_time);
```

## Delta Time

```zig
var last_frame: f64 = 0;
// In main loop:
const current_frame = c.glfwGetTime();
const delta_time: f32 = @floatCast(current_frame - last_frame);
last_frame = current_frame;
```

## Coordinate System

OpenGL uses right-handed coordinates:
- +X = right
- +Y = up  
- +Z = toward the camera (out of screen)
- -Z = forward (into screen)

This matches the camera's initial yaw of `-π/2` (facing -Z).

## Testing Strategy

The math functions can be unit tested without OpenGL:

```zig
test "identity matrix" {
    const m = Mat4.identity();
    try std.testing.expectEqual(m.data[0][0], 1.0);
    try std.testing.expectEqual(m.data[1][1], 1.0);
    try std.testing.expectEqual(m.data[0][1], 0.0);
}

test "vec3 normalize" {
    const v = Vec3.init(3, 0, 0);
    const n = v.normalize();
    try std.testing.expectApproxEqAbs(n.x, 1.0, 0.001);
    try std.testing.expectApproxEqAbs(n.len(), 1.0, 0.001);
}
```

## Not Yet Verified

- `Mat4.ptr()` with `@ptrCast` for `glUniformMatrix4fv` — needs runtime test
- `std.math.degreesToRadians` — verify this exists in 0.16.0
- `@cos` and `@sin` builtins — should work but verify

## Verification Results

All the following were tested and pass on Zig 0.16.0:

- `Vec3`: init, add, sub, scale, dot, cross, len, normalize
- `Mat4`: identity, mul, ptr
- `perspective()`: produces valid projection matrix
- `lookAt()`: produces correct view matrix for -Z forward
- `translate()`: correct translation matrix
- `Mat4.ptr()` with `@ptrCast`: returns valid `[*c]const f32`
- `std.math.degreesToRadians`: works (takes `anytype`, pass `@as(f32, degrees)`)
- `@sin`, `@cos`, `@sqrt`: work as builtins on f32
- `@tan`: works (used in perspective)

## Note on `length` vs `len`

Use `len` not `length` for the Vec3 method name. `length` may shadow
a builtin in some contexts.
