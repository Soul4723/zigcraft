const std = @import("std");

/// Chunk ticket constants used by portal and Ender Pearl loaders.
pub const portal_ticket_duration_ticks: u16 = 300;
pub const portal_ticket_duration_seconds: f32 = 15.0;
pub const ender_pearl_ticket_duration_ticks: u16 = 40;
pub const ender_pearl_ticket_duration_seconds: f32 = 2.0;
pub const random_tick_player_radius_blocks: f32 = 128.0;

/// Vanilla-style processing levels for a chunk loader ticket.
pub const ChunkLoadLevel = enum(u8) {
    entity_ticking_3x3 = 31,
    block_ticking_5x5 = 32,
    border_lazy_7x7 = 33,
    unloaded_inaccessible = 34,

    pub fn level(self: ChunkLoadLevel) u8 {
        return @intFromEnum(self);
    }

    pub fn radius(self: ChunkLoadLevel) u8 {
        return switch (self) {
            .entity_ticking_3x3 => 1,
            .block_ticking_5x5 => 2,
            .border_lazy_7x7 => 3,
            .unloaded_inaccessible => 0,
        };
    }

    pub fn fromLevel(level_value: u8) ChunkLoadLevel {
        return switch (level_value) {
            31 => .entity_ticking_3x3,
            32 => .block_ticking_5x5,
            33 => .border_lazy_7x7,
            else => .unloaded_inaccessible,
        };
    }

    pub fn ticksEntities(self: ChunkLoadLevel) bool {
        return self == .entity_ticking_3x3;
    }

    pub fn ticksRedstone(self: ChunkLoadLevel) bool {
        return self == .entity_ticking_3x3 or self == .block_ticking_5x5;
    }

    pub fn isLoaded(self: ChunkLoadLevel) bool {
        return self != .unloaded_inaccessible;
    }

    /// Returns whether a relative chunk lies in this ticket's square radius.
    pub fn containsOffset(self: ChunkLoadLevel, chunk_dx: i32, chunk_dz: i32) bool {
        if (!self.isLoaded()) return false;
        const distance_x: u32 = @intCast(@abs(chunk_dx));
        const distance_z: u32 = @intCast(@abs(chunk_dz));
        return distance_x <= self.radius() and distance_z <= self.radius();
    }

    /// The 5x5 ticket is a block-ticking outer ring around the 3x3 core.
    pub fn isOuterRingOffset(self: ChunkLoadLevel, chunk_dx: i32, chunk_dz: i32) bool {
        if (self != .block_ticking_5x5) return false;
        return self.containsOffset(chunk_dx, chunk_dz) and
            (@abs(chunk_dx) == self.radius() or @abs(chunk_dz) == self.radius());
    }
};

/// A portal ticket keeps its destination chunk entity-ticking for 300 ticks.
pub const PortalChunkTicket = struct {
    destination_chunk_x: i32,
    destination_chunk_z: i32,
    remaining_ticks: u16 = portal_ticket_duration_ticks,

    pub fn init(destination_chunk_x: i32, destination_chunk_z: i32) PortalChunkTicket {
        return .{
            .destination_chunk_x = destination_chunk_x,
            .destination_chunk_z = destination_chunk_z,
        };
    }

    pub fn level(self: PortalChunkTicket) ChunkLoadLevel {
        _ = self;
        return .entity_ticking_3x3;
    }

    pub fn isActive(self: PortalChunkTicket) bool {
        return self.remaining_ticks > 0;
    }

    /// Advances one game tick. Returns whether the ticket remains active.
    pub fn tick(self: *PortalChunkTicket) bool {
        if (self.remaining_ticks > 0) self.remaining_ticks -= 1;
        return self.isActive();
    }

    pub fn refresh(self: *PortalChunkTicket) void {
        self.remaining_ticks = portal_ticket_duration_ticks;
    }
};

/// A thrown or bubble-column-suspended Ender Pearl's short ticket.
pub const EnderPearlChunkTicket = struct {
    chunk_x: i32,
    chunk_z: i32,
    pearl_alive: bool = true,
    remaining_ticks: u16 = ender_pearl_ticket_duration_ticks,

    pub fn init(chunk_x: i32, chunk_z: i32) EnderPearlChunkTicket {
        return .{ .chunk_x = chunk_x, .chunk_z = chunk_z };
    }

    pub fn enderPearlLoadsChunk() bool {
        return true;
    }

    pub fn isActive(self: EnderPearlChunkTicket) bool {
        return self.pearl_alive and self.remaining_ticks > 0;
    }

    /// Refreshes the 40-tick ticket every tick while the pearl remains alive.
    pub fn tick(self: *EnderPearlChunkTicket, pearl_still_alive: bool) bool {
        self.pearl_alive = pearl_still_alive;
        if (!self.pearl_alive) {
            self.remaining_ticks = 0;
            return false;
        }
        self.remaining_ticks = ender_pearl_ticket_duration_ticks;
        return true;
    }

    pub fn expire(self: *EnderPearlChunkTicket) void {
        self.pearl_alive = false;
        self.remaining_ticks = 0;
    }
};

/// A loader cycle remains permanent when the next transit happens before expiry.
pub fn isPermanentChunkLoaderCycleValid(cycle_period_ticks: u16) bool {
    return cycle_period_ticks <= portal_ticket_duration_ticks;
}

/// Natural random ticks and hostile spawning retain their player dependency.
pub fn requiresHumanPlayerWithin128mForRandomTicksAndMobSpawns() bool {
    return true;
}

/// Portal and Pearl loaders permit autonomous machine/redstone processing.
pub fn autonomousFarmProcessingAllowed() bool {
    return true;
}

/// Convenience predicate for the entity types that can create portal tickets.
pub fn entityCanCreatePortalTicket(entity: enum { dropped_item, minecart, boat, arrow, mob }) bool {
    _ = entity;
    return true;
}

test "chunk load levels expose vanilla numeric levels" {
    try std.testing.expectEqual(@as(u8, 31), ChunkLoadLevel.entity_ticking_3x3.level());
    try std.testing.expectEqual(@as(u8, 32), ChunkLoadLevel.block_ticking_5x5.level());
    try std.testing.expectEqual(@as(u8, 33), ChunkLoadLevel.border_lazy_7x7.level());
    try std.testing.expectEqual(@as(u8, 34), ChunkLoadLevel.unloaded_inaccessible.level());
}

test "level conversion clamps inaccessible values" {
    try std.testing.expectEqual(ChunkLoadLevel.entity_ticking_3x3, ChunkLoadLevel.fromLevel(31));
    try std.testing.expectEqual(ChunkLoadLevel.unloaded_inaccessible, ChunkLoadLevel.fromLevel(34));
    try std.testing.expectEqual(ChunkLoadLevel.unloaded_inaccessible, ChunkLoadLevel.fromLevel(255));
}

test "processing radii are three by three five by five and seven by seven" {
    try std.testing.expectEqual(@as(u8, 1), ChunkLoadLevel.entity_ticking_3x3.radius());
    try std.testing.expectEqual(@as(u8, 2), ChunkLoadLevel.block_ticking_5x5.radius());
    try std.testing.expectEqual(@as(u8, 3), ChunkLoadLevel.border_lazy_7x7.radius());
}

test "entity ticking includes its complete 3x3 square" {
    const level = ChunkLoadLevel.entity_ticking_3x3;
    try std.testing.expect(level.containsOffset(-1, -1));
    try std.testing.expect(level.containsOffset(1, 1));
    try std.testing.expect(!level.containsOffset(2, 0));
    try std.testing.expect(level.ticksEntities());
    try std.testing.expect(level.ticksRedstone());
}

test "block ticking outer ring processes redstone but not entities" {
    const level = ChunkLoadLevel.block_ticking_5x5;
    try std.testing.expect(level.containsOffset(2, -2));
    try std.testing.expect(level.isOuterRingOffset(0, 2));
    try std.testing.expect(!level.isOuterRingOffset(1, 1));
    try std.testing.expect(!level.ticksEntities());
    try std.testing.expect(level.ticksRedstone());
}

test "border lazy ring is collision-only" {
    const level = ChunkLoadLevel.border_lazy_7x7;
    try std.testing.expect(level.containsOffset(3, 0));
    try std.testing.expect(level.containsOffset(-3, 3));
    try std.testing.expect(!level.containsOffset(4, 0));
    try std.testing.expect(!level.ticksEntities());
    try std.testing.expect(!level.ticksRedstone());
    try std.testing.expect(level.isLoaded());
}

test "inaccessible level is not loaded" {
    const level = ChunkLoadLevel.unloaded_inaccessible;
    try std.testing.expect(!level.isLoaded());
    try std.testing.expect(!level.containsOffset(0, 0));
}

test "portal ticket starts at 300 ticks and entity ticking" {
    var ticket = PortalChunkTicket.init(12, -8);
    try std.testing.expectEqual(@as(i32, 12), ticket.destination_chunk_x);
    try std.testing.expectEqual(@as(u16, 300), ticket.remaining_ticks);
    try std.testing.expectEqual(ChunkLoadLevel.entity_ticking_3x3, ticket.level());
}

test "portal ticket expires exactly after 300 ticks" {
    var ticket = PortalChunkTicket.init(0, 0);
    var i: usize = 0;
    while (i < 299) : (i += 1) try std.testing.expect(ticket.tick());
    try std.testing.expect(!ticket.tick());
    try std.testing.expect(!ticket.isActive());
    try std.testing.expectEqual(@as(u16, 0), ticket.remaining_ticks);
}

test "portal ticket refresh restores full duration" {
    var ticket = PortalChunkTicket.init(0, 0);
    _ = ticket.tick();
    ticket.refresh();
    try std.testing.expectEqual(portal_ticket_duration_ticks, ticket.remaining_ticks);
}

test "cycles at or below 300 ticks remain valid" {
    try std.testing.expect(isPermanentChunkLoaderCycleValid(0));
    try std.testing.expect(isPermanentChunkLoaderCycleValid(300));
    try std.testing.expect(!isPermanentChunkLoaderCycleValid(301));
}

test "ender pearl ticket refreshes every live tick" {
    var ticket = EnderPearlChunkTicket.init(4, 9);
    try std.testing.expect(EnderPearlChunkTicket.enderPearlLoadsChunk());
    _ = ticket.tick(true);
    try std.testing.expectEqual(@as(u16, 40), ticket.remaining_ticks);
    try std.testing.expect(ticket.isActive());
}

test "ender pearl ticket ends when pearl dies" {
    var ticket = EnderPearlChunkTicket.init(4, 9);
    try std.testing.expect(!ticket.tick(false));
    try std.testing.expect(!ticket.isActive());
    ticket.expire();
    try std.testing.expectEqual(@as(u16, 0), ticket.remaining_ticks);
}

test "random ticks and mob spawning require a human player" {
    try std.testing.expect(requiresHumanPlayerWithin128mForRandomTicksAndMobSpawns());
    try std.testing.expectEqual(@as(f32, 128.0), random_tick_player_radius_blocks);
}

test "automation remains autonomous under loader tickets" {
    try std.testing.expect(autonomousFarmProcessingAllowed());
    try std.testing.expect(entityCanCreatePortalTicket(.dropped_item));
    try std.testing.expect(entityCanCreatePortalTicket(.minecart));
    try std.testing.expect(entityCanCreatePortalTicket(.boat));
    try std.testing.expect(entityCanCreatePortalTicket(.arrow));
    try std.testing.expect(entityCanCreatePortalTicket(.mob));
}
