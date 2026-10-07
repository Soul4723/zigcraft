const std = @import("std");
pub const mob = @import("entity/mob.zig");
pub const mob_renderer = @import("entity/mob_renderer.zig");
pub const mob_manager = @import("entity/mob_manager.zig");
pub const pack_hunt = @import("entity/pack_hunt.zig");

test {
    std.testing.refAllDecls(mob);
    std.testing.refAllDecls(mob_renderer);
    std.testing.refAllDecls(mob_manager);
    std.testing.refAllDecls(pack_hunt);
}
