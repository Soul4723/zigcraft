const std = @import("std");

/// The window uses logical coordinates for input and framebuffer pixels for drawing.
pub const WindowSize = struct {
    width: i32,
    height: i32,
    framebuffer_width: i32,
    framebuffer_height: i32,

    /// A zero-sized window or framebuffer cannot be rendered or used for input mapping.
    pub fn aspect(self: WindowSize) ?f32 {
        if (self.width <= 0 or self.height <= 0 or self.framebuffer_width <= 0 or self.framebuffer_height <= 0) return null;
        return @as(f32, @floatFromInt(self.framebuffer_width)) / @as(f32, @floatFromInt(self.framebuffer_height));
    }

    /// Convert GLFW cursor screen coordinates to the normalized UI coordinate system.
    pub fn cursor(self: WindowSize, x: f64, y: f64) [2]f32 {
        return .{
            @as(f32, @floatCast(x / @as(f64, @floatFromInt(self.width)))) * 2.0 - 1.0,
            1.0 - @as(f32, @floatCast(y / @as(f64, @floatFromInt(self.height)))) * 2.0,
        };
    }
};

test "framebuffer aspect and logical cursor coordinates follow resizing and HiDPI" {
    const narrow = WindowSize{ .width = 960, .height = 720, .framebuffer_width = 1920, .framebuffer_height = 1440 };
    try std.testing.expectApproxEqAbs(@as(f32, 4.0 / 3.0), narrow.aspect().?, 0.00001);
    const point = narrow.cursor(240, 540);
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), point[0], 0.00001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.5), point[1], 0.00001);
    const wide = WindowSize{ .width = 1500, .height = 720, .framebuffer_width = 1500, .framebuffer_height = 720 };
    try std.testing.expectApproxEqAbs(@as(f32, 1500.0 / 720.0), wide.aspect().?, 0.00001);
    const center = wide.cursor(750, 360);
    try std.testing.expectApproxEqAbs(@as(f32, 0), center[0], 0.00001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), center[1], 0.00001);
}

test "zero dimensions prevent rendering and cursor mapping" {
    var size = WindowSize{ .width = 960, .height = 720, .framebuffer_width = 960, .framebuffer_height = 720 };
    size.framebuffer_width = 0;
    try std.testing.expect(size.aspect() == null);
    size.framebuffer_width = 960;
    size.framebuffer_height = 0;
    try std.testing.expect(size.aspect() == null);
    size.framebuffer_height = 720;
    size.width = 0;
    try std.testing.expect(size.aspect() == null);
    size.width = 960;
    size.height = 0;
    try std.testing.expect(size.aspect() == null);
}
