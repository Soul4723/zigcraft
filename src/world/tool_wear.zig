const std = @import("std");

pub const hotbar_slots: usize = 6;

pub const Wear = struct {
    uses: [hotbar_slots]u16 = [_]u16{0} ** hotbar_slots,

    pub fn clearIfNotTool(self: *Wear, slot: usize, is_tool: bool) void {
        if (!is_tool) self.uses[slot] = 0;
    }

    /// Record one use. Returns true when the tool breaks.
    pub fn use(self: *Wear, slot: usize, durability: u16) bool {
        self.uses[slot] += 1;
        if (self.uses[slot] >= durability) {
            self.uses[slot] = 0;
            return true;
        }
        return false;
    }
};

test "wear clears for non-tools" {
    var w = Wear{};
    w.uses[0] = 5;
    w.clearIfNotTool(0, false);
    try std.testing.expectEqual(w.uses[0], 0);
    w.uses[1] = 5;
    w.clearIfNotTool(1, true);
    try std.testing.expectEqual(w.uses[1], 5);
}

test "tool breaks at durability" {
    var w = Wear{};
    try std.testing.expect(!w.use(0, 25));
    try std.testing.expectEqual(w.uses[0], 1);
    var i: usize = 1;
    while (i < 24) : (i += 1) {
        try std.testing.expect(!w.use(0, 25));
    }
    try std.testing.expect(w.use(0, 25));
    try std.testing.expectEqual(w.uses[0], 0);
}
