const std = @import("std");

pub const cap_warn_time: f32 = 3.0;
pub const burnout_warn_time: f32 = 2.5;
pub const cap_warn_color: [3]f32 = .{ 0.95, 0.45, 0.1 };
pub const burnout_warn_color: [3]f32 = .{ 0.85, 0.25, 0.15 };

pub const Toast = struct {
    timer: f32 = 0.0,
    color: [3]f32 = .{ 1.0, 0.8, 0.2 },

    pub fn showCapWarning(self: *Toast) void {
        self.timer = cap_warn_time;
        self.color = cap_warn_color;
    }

    pub fn showBurnoutWarning(self: *Toast) void {
        self.timer = burnout_warn_time;
        self.color = burnout_warn_color;
    }

    pub fn tick(self: *Toast, dt: f32) f32 {
        self.timer = @max(0.0, self.timer - dt);
        return @min(1.0, self.timer);
    }

    pub fn visible(self: *const Toast) bool {
        return self.timer > 0.0;
    }
};

test "toast warnings set timer and color" {
    var t = Toast{};
    try std.testing.expect(!t.visible());
    t.showCapWarning();
    try std.testing.expect(t.visible());
    try std.testing.expectEqual(t.timer, cap_warn_time);
    try std.testing.expectEqual(t.color, cap_warn_color);
    t.showBurnoutWarning();
    try std.testing.expectEqual(t.timer, burnout_warn_time);
    try std.testing.expectEqual(t.color, burnout_warn_color);
}

test "toast tick fades alpha" {
    var t = Toast{};
    t.showCapWarning();
    const a0 = t.tick(1.0);
    try std.testing.expect(a0 > 0.9 and a0 <= 1.0);
    const a1 = t.tick(5.0);
    try std.testing.expectEqual(a1, 0.0);
    try std.testing.expect(!t.visible());
}
