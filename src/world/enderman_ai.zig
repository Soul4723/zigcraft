const std = @import("std");

/// Physical, behavioral, and combat constants for Endermen.
pub const enderman_max_health: f32 = 40.0; // 20 hearts
pub const enderman_height: f32 = 2.9; // 2.9 blocks tall
pub const enderman_eye_height: f32 = 2.6; // 2.6 blocks above feet
pub const enderman_width: f32 = 0.6; // 0.6 x 0.6 block horizontal bounding box
pub const enderman_teleport_range: f32 = 32.0; // standard random teleport radius
pub const max_gaze_distance: f32 = 64.0; // max block distance for eye-contact provocation
pub const max_gaze_distance_sq: f32 = max_gaze_distance * max_gaze_distance; // 4096.0
pub const gaze_provocation_dot_threshold: f32 = 0.999; // narrow cone threshold (~2.56 degrees half-angle)

/// Environmental hydrophobia damage constants.
pub const water_damage_interval: f32 = 0.5; // 0.5 seconds per damage tick
pub const water_damage_amount: f32 = 1.0; // 1.0 HP per 0.5s tick (2.0 HP/s)
pub const default_teleport_cooldown: f32 = 1.0; // 1.0 second cooldown between voluntary teleports

/// Block tags corresponding to blocks Endermen can or cannot pick up.
pub const BlockTag = struct {
    pub const air: u16 = 0;
    pub const stone: u16 = 1;
    pub const dirt: u16 = 2;
    pub const grass: u16 = 3;
    pub const water: u16 = 4;
    pub const wood: u16 = 5;
    pub const leaves: u16 = 6;
    pub const wood_planks: u16 = 7;
    pub const cobblestone: u16 = 9;
    pub const sand: u16 = 12;
    pub const glass: u16 = 13;
    pub const tnt: u16 = 20;
    pub const chest: u16 = 22;
    pub const cactus: u16 = 39;
    pub const obsidian: u16 = 42;
    pub const netherrack: u16 = 44;
    pub const soul_sand: u16 = 45;
    pub const nether_wart: u16 = 54;
    pub const spawner_cage: u16 = 57;
    pub const crying_obsidian: u16 = 62;
    pub const crimson_fungus: u16 = 71;
    pub const warped_fungus: u16 = 72;
    pub const chorus_plant: u16 = 113;
    pub const chorus_flower: u16 = 114;
    pub const pumpkin: u16 = 175;
    pub const carved_pumpkin: u16 = 176;
    pub const melon: u16 = 187;
    pub const clay: u16 = 195;
    pub const sweet_berry_bush: u16 = 204;
    pub const ender_chest: u16 = 205;
    pub const mud: u16 = 206;
    pub const packed_mud: u16 = 207;
    pub const suspicious_sand: u16 = 213;
    pub const trial_spawner: u16 = 217;
    pub const mangrove_roots: u16 = 227;
    pub const muddy_mangrove_roots: u16 = 228;
    pub const torchflower_crop: u16 = 232;
    pub const torchflower: u16 = 233;
    pub const pitcher_plant: u16 = 234;
    pub const pink_petals: u16 = 238;
    pub const open_eyeblossom: u16 = 244;
    pub const firefly_bush: u16 = 254;
    pub const leaf_litter: u16 = 255;
    pub const bedrock: u16 = 999;
};

/// Evaluates whether a player's gaze provokes an Enderman into screaming hostility.
/// Provokes hostility when the player looks directly at its head within 64.0 blocks
/// (dot product >= 0.999 narrow cone ~2.56 degrees), unless the player is wearing
/// a Carved Pumpkin (wearing_carved_pumpkin == true grants 100% immunity!).
pub fn isEndermanProvokedByGaze(
    enderman_eye_pos: [3]f32,
    player_eye_pos: [3]f32,
    player_look_dir: [3]f32,
    wearing_carved_pumpkin: bool,
) bool {
    // Wearing a carved pumpkin grants complete gaze immunity
    if (wearing_carved_pumpkin) {
        return false;
    }

    const dx = enderman_eye_pos[0] - player_eye_pos[0];
    const dy = enderman_eye_pos[1] - player_eye_pos[1];
    const dz = enderman_eye_pos[2] - player_eye_pos[2];
    const dist_sq = dx * dx + dy * dy + dz * dz;

    // Must be within 64.0 blocks max gaze distance
    if (dist_sq > max_gaze_distance_sq) {
        return false;
    }

    // Direct overlap (player eye inside enderman head)
    if (dist_sq < 0.000001) {
        return true;
    }

    const look_sq = player_look_dir[0] * player_look_dir[0] +
        player_look_dir[1] * player_look_dir[1] +
        player_look_dir[2] * player_look_dir[2];

    // Invalid look direction vector
    if (look_sq < 0.000001) {
        return false;
    }

    const inv_dist = 1.0 / @sqrt(dist_sq);
    const to_head_x = dx * inv_dist;
    const to_head_y = dy * inv_dist;
    const to_head_z = dz * inv_dist;

    const inv_look = 1.0 / @sqrt(look_sq);
    const look_x = player_look_dir[0] * inv_look;
    const look_y = player_look_dir[1] * inv_look;
    const look_z = player_look_dir[2] * inv_look;

    const dot = to_head_x * look_x + to_head_y * look_y + to_head_z * look_z;

    return dot >= gaze_provocation_dot_threshold;
}

/// Result of resolving an incoming projectile against an Enderman.
pub const ProjectileResolution = struct {
    dodged_by_teleport: bool,
    splash_water_damage: f32,
};

/// Endermen automatically teleport away to dodge all incoming arrows, tridents, and
/// wind charges (dodged_by_teleport = true) before impact — except Splash Water Bottles,
/// which hit and deal 1.0 hydrophobia damage + force teleportation!
pub fn resolveProjectileAgainstEnderman(is_splash_water_bottle: bool) ProjectileResolution {
    if (is_splash_water_bottle) {
        return .{
            .dodged_by_teleport = false,
            .splash_water_damage = water_damage_amount,
        };
    } else {
        return .{
            .dodged_by_teleport = true,
            .splash_water_damage = 0.0,
        };
    }
}

/// Incoming projectile types for convenience.
pub const ProjectileType = enum {
    arrow,
    spectral_arrow,
    trident,
    wind_charge,
    snowball,
    egg,
    splash_water_bottle,
    lingering_water_bottle,
};

/// Resolves projectile dodge/damage given a projectile enum variant.
pub fn resolveProjectileTypeAgainstEnderman(proj_type: ProjectileType) ProjectileResolution {
    const is_water = (proj_type == .splash_water_bottle or proj_type == .lingering_water_bottle);
    return resolveProjectileAgainstEnderman(is_water);
}

/// Determines whether an Enderman can pick up and place a given block.
/// Endermen can pick up and place only natural earth, flora, fungi, melon, pumpkin, and tnt blocks.
/// They NEVER pick up bedrock, obsidian, chests, or spawners (or standard masonry/metal/wood).
pub fn canEndermanPickUpBlock(block_tag: u16) bool {
    // Explicit blacklist: Endermen NEVER pick up bedrock, obsidian, chests, or spawners
    if (block_tag == BlockTag.bedrock) return false;
    if (block_tag == BlockTag.obsidian or block_tag == BlockTag.crying_obsidian) return false;
    if (block_tag == BlockTag.chest or block_tag == BlockTag.ender_chest) return false;
    if (block_tag == BlockTag.spawner_cage or block_tag == BlockTag.trial_spawner) return false;

    // Whitelist: natural earth/flora/fungi/melon/pumpkin/tnt blocks
    return switch (block_tag) {
        // Natural Earth
        BlockTag.dirt,
        BlockTag.grass,
        BlockTag.sand,
        BlockTag.soul_sand,
        BlockTag.netherrack,
        BlockTag.clay,
        BlockTag.mud,
        BlockTag.packed_mud,
        BlockTag.suspicious_sand,
        BlockTag.mangrove_roots,
        BlockTag.muddy_mangrove_roots,
        // Flora
        BlockTag.cactus,
        BlockTag.chorus_plant,
        BlockTag.chorus_flower,
        BlockTag.sweet_berry_bush,
        BlockTag.torchflower_crop,
        BlockTag.torchflower,
        BlockTag.pitcher_plant,
        BlockTag.pink_petals,
        BlockTag.open_eyeblossom,
        BlockTag.firefly_bush,
        BlockTag.leaf_litter,
        // Fungi
        BlockTag.nether_wart,
        BlockTag.crimson_fungus,
        BlockTag.warped_fungus,
        // Melon & Pumpkin
        BlockTag.pumpkin,
        BlockTag.carved_pumpkin,
        BlockTag.melon,
        // TNT
        BlockTag.tnt,
        => true,

        else => false,
    };
}

/// Evaluates whether a location provides dry shelter safe for an Enderman.
/// A shelter is dry if the Enderman is not in water, and if raining, has overhead cover.
pub fn isDryShelter(in_water: bool, has_overhead_cover: bool, is_raining: bool) bool {
    if (in_water) return false;
    if (is_raining and !has_overhead_cover) return false;
    return true;
}

/// Generates a pseudo-random 3D offset for panic or dodge teleportation.
pub fn generateTeleportOffset(seed: u64, max_radius: f32) [3]f32 {
    var s = seed ^ 0x9E3779B97F4A7C15;
    s = (s ^ (s >> 30)) *% 0xBF58476D1CE4E5B9;
    s = (s ^ (s >> 27)) *% 0x94D049BB133111EB;
    s = s ^ (s >> 31);

    const r_x = @as(f32, @floatFromInt(@as(i16, @bitCast(@as(u16, @truncate(s)))))) / 32768.0;
    const r_y = @as(f32, @floatFromInt(@as(i16, @bitCast(@as(u16, @truncate(s >> 16)))))) / 32768.0;
    const r_z = @as(f32, @floatFromInt(@as(i16, @bitCast(@as(u16, @truncate(s >> 32)))))) / 32768.0;

    return .{
        r_x * max_radius,
        r_y * (max_radius * 0.25),
        r_z * max_radius,
    };
}

/// State tracking for an Enderman entity.
pub const EndermanState = struct {
    pos: [3]f32 = .{ 0.0, 0.0, 0.0 },
    health: f32 = enderman_max_health,
    is_screaming_angry: bool = false,
    stare_frozen_by_player: bool = false,
    carried_block_id: ?u16 = null,
    teleport_cooldown: f32 = 0.0,
    water_damage_timer: f32 = 0.0,
    is_vibrating: bool = false,
    eye_height: f32 = enderman_eye_height,

    pub fn init(pos: [3]f32) EndermanState {
        return .{
            .pos = pos,
            .health = enderman_max_health,
            .is_screaming_angry = false,
            .stare_frozen_by_player = false,
            .carried_block_id = null,
            .teleport_cooldown = 0.0,
            .water_damage_timer = 0.0,
            .is_vibrating = false,
            .eye_height = enderman_eye_height,
        };
    }

    /// Returns the world position of the Enderman's eyes/head.
    pub fn getEyePos(self: *const EndermanState) [3]f32 {
        return .{ self.pos[0], self.pos[1] + self.eye_height, self.pos[2] };
    }

    /// Updates eye-contact provocation and stare-freeze status.
    /// When player stares directly into the Enderman's eyes within 64 blocks without a pumpkin:
    /// - It becomes screaming angry (provoked).
    /// - While angry, direct eye contact freezes it in place, vibrating intensely until the player looks away!
    pub fn updateGaze(
        self: *EndermanState,
        player_eye_pos: [3]f32,
        player_look_dir: [3]f32,
        wearing_carved_pumpkin: bool,
    ) void {
        const eye_pos = self.getEyePos();
        const gaze_contact = isEndermanProvokedByGaze(eye_pos, player_eye_pos, player_look_dir, wearing_carved_pumpkin);

        if (gaze_contact) {
            self.is_screaming_angry = true;
            self.stare_frozen_by_player = true;
            self.is_vibrating = true;
        } else {
            self.stare_frozen_by_player = false;
            self.is_vibrating = false;
        }
    }

    /// Provokes the Enderman into screaming hostility (e.g. from damage or external trigger).
    pub fn provoke(self: *EndermanState) void {
        self.is_screaming_angry = true;
    }

    /// Calms the Enderman hostility.
    pub fn calm(self: *EndermanState) void {
        self.is_screaming_angry = false;
        self.stare_frozen_by_player = false;
        self.is_vibrating = false;
    }

    /// Handles incoming projectile against this Enderman.
    /// Non-water projectiles (arrows, tridents, wind charges) are dodged by teleporting away.
    /// Splash water bottles hit, deal 1.0 damage, and force panic teleportation.
    pub fn onProjectileIncoming(
        self: *EndermanState,
        is_splash_water_bottle: bool,
        teleport_dest: ?[3]f32,
    ) ProjectileResolution {
        const res = resolveProjectileAgainstEnderman(is_splash_water_bottle);
        if (res.dodged_by_teleport) {
            if (teleport_dest) |dest| {
                self.pos = dest;
                self.teleport_cooldown = default_teleport_cooldown;
            }
        } else {
            self.health = @max(0.0, self.health - res.splash_water_damage);
            if (teleport_dest) |dest| {
                self.pos = dest;
                self.teleport_cooldown = default_teleport_cooldown;
            }
        }
        return res;
    }

    /// Updates water and rain contact damage.
    /// Endermen take 1.0 HP damage per 0.5s of contact, triggering panic random teleportation to dry shelter.
    pub fn updateWaterAndRain(
        self: *EndermanState,
        dt: f32,
        in_water_or_rain: bool,
        dry_shelter_target: ?[3]f32,
    ) struct { damage_dealt: f32, panicked_teleport: bool } {
        if (!in_water_or_rain) {
            self.water_damage_timer = 0.0;
            return .{ .damage_dealt = 0.0, .panicked_teleport = false };
        }

        self.water_damage_timer += dt;
        var total_damage: f32 = 0.0;
        var panic_tp = false;

        while (self.water_damage_timer >= water_damage_interval) {
            self.water_damage_timer -= water_damage_interval;
            self.health = @max(0.0, self.health - water_damage_amount);
            total_damage += water_damage_amount;
            panic_tp = true;
        }

        if (panic_tp) {
            if (dry_shelter_target) |target| {
                self.pos = target;
                self.teleport_cooldown = default_teleport_cooldown;
            }
        }

        return .{
            .damage_dealt = total_damage,
            .panicked_teleport = panic_tp,
        };
    }

    /// Applies direct water damage and triggers panic teleport to dry shelter.
    pub fn takeWaterDamage(self: *EndermanState, amount: f32, dry_shelter_target: ?[3]f32) void {
        self.health = @max(0.0, self.health - amount);
        if (dry_shelter_target) |target| {
            self.pos = target;
            self.teleport_cooldown = default_teleport_cooldown;
        }
    }

    /// Attempts to pick up a block from the world.
    /// Returns true if successfully picked up, false if carried slot is full or block is not allowed.
    pub fn pickUpBlock(self: *EndermanState, block_tag: u16) bool {
        if (self.carried_block_id != null) return false;
        if (!canEndermanPickUpBlock(block_tag)) return false;
        self.carried_block_id = block_tag;
        return true;
    }

    /// Places the carried block, returning its ID, or null if holding nothing.
    pub fn placeCarriedBlock(self: *EndermanState) ?u16 {
        const block = self.carried_block_id;
        self.carried_block_id = null;
        return block;
    }

    /// Checks if the Enderman is currently holding a block.
    pub fn hasCarriedBlock(self: *const EndermanState) bool {
        return self.carried_block_id != null;
    }

    /// Teleports the Enderman to a destination.
    pub fn teleport(self: *EndermanState, target_pos: [3]f32) bool {
        if (self.health <= 0.0) return false;
        self.pos = target_pos;
        self.teleport_cooldown = default_teleport_cooldown;
        return true;
    }

    /// Ticks cooldowns.
    pub fn tick(self: *EndermanState, dt: f32) void {
        if (self.teleport_cooldown > 0.0) {
            self.teleport_cooldown = @max(0.0, self.teleport_cooldown - dt);
        }
    }

    /// Checks if teleportation is ready.
    pub fn canTeleport(self: *const EndermanState) bool {
        return self.teleport_cooldown <= 0.0;
    }
};

// ============================================================================
// Comprehensive Unit Tests
// ============================================================================

test "isEndermanProvokedByGaze triggers when player looks directly at enderman head within 64 blocks" {
    const enderman_head = [3]f32{ 0.0, 2.6, 10.0 };
    const player_eyes = [3]f32{ 0.0, 1.62, 0.0 };
    // Exact look direction towards enderman head
    const dx = enderman_head[0] - player_eyes[0];
    const dy = enderman_head[1] - player_eyes[1];
    const dz = enderman_head[2] - player_eyes[2];
    const look_dir = [3]f32{ dx, dy, dz };

    const provoked = isEndermanProvokedByGaze(enderman_head, player_eyes, look_dir, false);
    try std.testing.expect(provoked);
}

test "isEndermanProvokedByGaze returns false beyond 64 blocks" {
    // 65 blocks away
    const enderman_head = [3]f32{ 0.0, 1.62, 65.0 };
    const player_eyes = [3]f32{ 0.0, 1.62, 0.0 };
    const look_dir = [3]f32{ 0.0, 0.0, 1.0 }; // Direct look

    const provoked = isEndermanProvokedByGaze(enderman_head, player_eyes, look_dir, false);
    try std.testing.expect(!provoked);

    // Barely within 64 blocks (63.9 blocks)
    const enderman_head_near = [3]f32{ 0.0, 1.62, 63.9 };
    const provoked_near = isEndermanProvokedByGaze(enderman_head_near, player_eyes, look_dir, false);
    try std.testing.expect(provoked_near);
}

test "isEndermanProvokedByGaze narrow cone boundary dot >= 0.999" {
    const player_eyes = [3]f32{ 0.0, 0.0, 0.0 };
    const enderman_head = [3]f32{ 0.0, 0.0, 20.0 }; // along +Z

    // Look dir with dot = 1.0 (dead center)
    try std.testing.expect(isEndermanProvokedByGaze(enderman_head, player_eyes, .{ 0.0, 0.0, 1.0 }, false));

    // Look dir slightly tilted: 0.03 rad (~1.7 degrees) -> cos(0.03) ≈ 0.99955 >= 0.999
    // Normalized vector: (0.03, 0, 0.99955)
    try std.testing.expect(isEndermanProvokedByGaze(enderman_head, player_eyes, .{ 0.03, 0.0, 0.99955 }, false));

    // Look dir tilted past boundary: 0.1 rad (~5.7 degrees) -> cos(0.1) ≈ 0.9950 < 0.999
    try std.testing.expect(!isEndermanProvokedByGaze(enderman_head, player_eyes, .{ 0.1, 0.0, 0.995 }, false));

    // Looking perpendicular (+X) or opposite (-Z)
    try std.testing.expect(!isEndermanProvokedByGaze(enderman_head, player_eyes, .{ 1.0, 0.0, 0.0 }, false));
    try std.testing.expect(!isEndermanProvokedByGaze(enderman_head, player_eyes, .{ 0.0, 0.0, -1.0 }, false));
}

test "isEndermanProvokedByGaze wearing carved pumpkin grants 100% immunity" {
    const enderman_head = [3]f32{ 0.0, 2.6, 5.0 };
    const player_eyes = [3]f32{ 0.0, 1.62, 0.0 };
    const look_dir = [3]f32{ 0.0, 0.98, 5.0 }; // Direct look into eyes at close range

    // Without pumpkin -> provoked
    try std.testing.expect(isEndermanProvokedByGaze(enderman_head, player_eyes, look_dir, false));

    // With carved pumpkin -> 100% immunity!
    try std.testing.expect(!isEndermanProvokedByGaze(enderman_head, player_eyes, look_dir, true));
}

test "EndermanState initialization defaults" {
    const state = EndermanState.init(.{ 10.0, 64.0, 20.0 });
    try std.testing.expectEqual(@as(f32, 40.0), state.health);
    try std.testing.expect(!state.is_screaming_angry);
    try std.testing.expect(!state.stare_frozen_by_player);
    try std.testing.expect(!state.is_vibrating);
    try std.testing.expectEqual(@as(?u16, null), state.carried_block_id);
    try std.testing.expectEqual(@as(f32, 0.0), state.teleport_cooldown);
    try std.testing.expectEqual([3]f32{ 10.0, 66.6, 20.0 }, state.getEyePos());
}

test "EndermanState stare-freeze when player stares directly at angry enderman" {
    var enderman = EndermanState.init(.{ 0.0, 0.0, 10.0 });
    const player_eyes = [3]f32{ 0.0, 2.6, 0.0 };
    const direct_look = [3]f32{ 0.0, 0.0, 1.0 }; // Looking directly at head (0, 2.6, 10)

    // Initial state: not angry, not frozen
    try std.testing.expect(!enderman.is_screaming_angry);
    try std.testing.expect(!enderman.stare_frozen_by_player);

    // Player looks directly at its head: provokes into screaming hostility + freezes vibrating
    enderman.updateGaze(player_eyes, direct_look, false);
    try std.testing.expect(enderman.is_screaming_angry);
    try std.testing.expect(enderman.stare_frozen_by_player);
    try std.testing.expect(enderman.is_vibrating);
}

test "EndermanState unfreezes and remains angry when player looks away" {
    var enderman = EndermanState.init(.{ 0.0, 0.0, 10.0 });
    const player_eyes = [3]f32{ 0.0, 2.6, 0.0 };
    const direct_look = [3]f32{ 0.0, 0.0, 1.0 };
    const look_away = [3]f32{ 1.0, 0.0, 0.0 }; // looking to the side

    // Gaze triggers screaming anger and freeze
    enderman.updateGaze(player_eyes, direct_look, false);
    try std.testing.expect(enderman.stare_frozen_by_player);
    try std.testing.expect(enderman.is_screaming_angry);

    // Player looks away: unfreezes so Enderman can attack, but remains screaming angry!
    enderman.updateGaze(player_eyes, look_away, false);
    try std.testing.expect(!enderman.stare_frozen_by_player);
    try std.testing.expect(!enderman.is_vibrating);
    try std.testing.expect(enderman.is_screaming_angry);

    // Player stares directly at its eyes again: freezes in place vibrating again!
    enderman.updateGaze(player_eyes, direct_look, false);
    try std.testing.expect(enderman.stare_frozen_by_player);
    try std.testing.expect(enderman.is_vibrating);
}

test "EndermanState stare-freeze bypassed when wearing carved pumpkin" {
    var enderman = EndermanState.init(.{ 0.0, 0.0, 10.0 });
    const player_eyes = [3]f32{ 0.0, 2.6, 0.0 };
    const direct_look = [3]f32{ 0.0, 0.0, 1.0 };

    // Player wearing carved pumpkin stares at Enderman
    enderman.updateGaze(player_eyes, direct_look, true);
    try std.testing.expect(!enderman.is_screaming_angry);
    try std.testing.expect(!enderman.stare_frozen_by_player);
    try std.testing.expect(!enderman.is_vibrating);

    // Even if provoked by external means (e.g. hit by weapon)
    enderman.provoke();
    try std.testing.expect(enderman.is_screaming_angry);

    // Staring with carved pumpkin does not freeze it
    enderman.updateGaze(player_eyes, direct_look, true);
    try std.testing.expect(!enderman.stare_frozen_by_player);
}

test "resolveProjectileAgainstEnderman arrow dodge teleportation" {
    // Arrow incoming (is_splash_water_bottle = false)
    const res = resolveProjectileAgainstEnderman(false);
    try std.testing.expect(res.dodged_by_teleport);
    try std.testing.expectEqual(@as(f32, 0.0), res.splash_water_damage);
}

test "resolveProjectileAgainstEnderman trident and wind charge dodged by teleportation" {
    // Tridents, wind charges, and standard projectiles are all dodged
    const trident_res = resolveProjectileTypeAgainstEnderman(.trident);
    try std.testing.expect(trident_res.dodged_by_teleport);
    try std.testing.expectEqual(@as(f32, 0.0), trident_res.splash_water_damage);

    const wind_charge_res = resolveProjectileTypeAgainstEnderman(.wind_charge);
    try std.testing.expect(wind_charge_res.dodged_by_teleport);
    try std.testing.expectEqual(@as(f32, 0.0), wind_charge_res.splash_water_damage);
}

test "resolveProjectileAgainstEnderman splash water bottle hits and deals 1.0 damage" {
    // Splash water bottle incoming (is_splash_water_bottle = true)
    const res = resolveProjectileAgainstEnderman(true);
    try std.testing.expect(!res.dodged_by_teleport); // hits, not dodged!
    try std.testing.expectEqual(@as(f32, 1.0), res.splash_water_damage);

    const enum_res = resolveProjectileTypeAgainstEnderman(.splash_water_bottle);
    try std.testing.expect(!enum_res.dodged_by_teleport);
    try std.testing.expectEqual(@as(f32, 1.0), enum_res.splash_water_damage);
}

test "EndermanState onProjectileIncoming arrow causes dodge and 0 damage" {
    var enderman = EndermanState.init(.{ 5.0, 64.0, 5.0 });
    const dodge_pos = [3]f32{ 15.0, 64.0, 20.0 };

    const res = enderman.onProjectileIncoming(false, dodge_pos);
    try std.testing.expect(res.dodged_by_teleport);
    try std.testing.expectEqual(@as(f32, 40.0), enderman.health); // took 0 damage
    try std.testing.expectEqual(dodge_pos, enderman.pos); // dodged to new pos
    try std.testing.expectEqual(@as(f32, 1.0), enderman.teleport_cooldown);
}

test "EndermanState onProjectileIncoming splash water bottle damages and forces panic teleport" {
    var enderman = EndermanState.init(.{ 5.0, 64.0, 5.0 });
    const panic_dest = [3]f32{ -10.0, 65.0, 12.0 };

    const res = enderman.onProjectileIncoming(true, panic_dest);
    try std.testing.expect(!res.dodged_by_teleport);
    try std.testing.expectEqual(@as(f32, 1.0), res.splash_water_damage);
    try std.testing.expectEqual(@as(f32, 39.0), enderman.health); // took 1.0 damage
    try std.testing.expectEqual(panic_dest, enderman.pos); // forced panic teleport
}

test "canEndermanPickUpBlock whitelist for natural earth, flora, fungi, melon, pumpkin, tnt" {
    // Natural Earth
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.dirt));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.grass));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.sand));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.soul_sand));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.netherrack));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.clay));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.mud));

    // Flora
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.cactus));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.chorus_plant));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.chorus_flower));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.torchflower));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.open_eyeblossom));

    // Fungi
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.crimson_fungus));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.warped_fungus));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.nether_wart));

    // Melons, Pumpkins & TNT
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.pumpkin));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.carved_pumpkin));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.melon));
    try std.testing.expect(canEndermanPickUpBlock(BlockTag.tnt));
}

test "canEndermanPickUpBlock blacklist never picks up bedrock, obsidian, chests, or spawners" {
    // Bedrock
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.bedrock));

    // Obsidian
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.obsidian));
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.crying_obsidian));

    // Chests
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.chest));
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.ender_chest));

    // Spawners
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.spawner_cage));
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.trial_spawner));

    // Structural / man-made / stone / fluids
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.stone));
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.cobblestone));
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.wood));
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.wood_planks));
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.air));
    try std.testing.expect(!canEndermanPickUpBlock(BlockTag.water));
}

test "EndermanState pickUpBlock and placeCarriedBlock lifecycle" {
    var enderman = EndermanState.init(.{ 0.0, 64.0, 0.0 });
    try std.testing.expect(!enderman.hasCarriedBlock());

    // Fails to pick up forbidden obsidian
    try std.testing.expect(!enderman.pickUpBlock(BlockTag.obsidian));
    try std.testing.expect(!enderman.hasCarriedBlock());

    // Successfully picks up grass
    try std.testing.expect(enderman.pickUpBlock(BlockTag.grass));
    try std.testing.expect(enderman.hasCarriedBlock());
    try std.testing.expectEqual(@as(?u16, BlockTag.grass), enderman.carried_block_id);

    // Cannot pick up another block while hands are full
    try std.testing.expect(!enderman.pickUpBlock(BlockTag.dirt));
    try std.testing.expectEqual(@as(?u16, BlockTag.grass), enderman.carried_block_id);

    // Place the carried block down
    const placed = enderman.placeCarriedBlock();
    try std.testing.expectEqual(@as(?u16, BlockTag.grass), placed);
    try std.testing.expect(!enderman.hasCarriedBlock());

    // Placing again yields null
    try std.testing.expectEqual(@as(?u16, null), enderman.placeCarriedBlock());
}

test "water and rain contact deals 1.0 HP per 0.5s and triggers panic teleport" {
    var enderman = EndermanState.init(.{ 0.0, 64.0, 0.0 });
    const shelter = [3]f32{ 20.0, 64.0, 20.0 };

    // Submerged in water for 0.4s: under interval -> 0 damage, no panic teleport
    const tick1 = enderman.updateWaterAndRain(0.4, true, shelter);
    try std.testing.expectEqual(@as(f32, 0.0), tick1.damage_dealt);
    try std.testing.expect(!tick1.panicked_teleport);
    try std.testing.expectEqual(@as(f32, 40.0), enderman.health);

    // Another 0.1s in water (total 0.5s): hits 0.5s interval -> 1.0 damage, panic teleports to shelter!
    const tick2 = enderman.updateWaterAndRain(0.1, true, shelter);
    try std.testing.expectEqual(@as(f32, 1.0), tick2.damage_dealt);
    try std.testing.expect(tick2.panicked_teleport);
    try std.testing.expectEqual(@as(f32, 39.0), enderman.health);
    try std.testing.expectEqual(shelter, enderman.pos);

    // Another 0.5s in rain triggers second 1.0 damage tick and panic
    const shelter2 = [3]f32{ 30.0, 64.0, 30.0 };
    const tick3 = enderman.updateWaterAndRain(0.5, true, shelter2);
    try std.testing.expectEqual(@as(f32, 1.0), tick3.damage_dealt);
    try std.testing.expect(tick3.panicked_teleport);
    try std.testing.expectEqual(@as(f32, 38.0), enderman.health);
    try std.testing.expectEqual(shelter2, enderman.pos);
}

test "rain contact stops dealing damage when sheltered" {
    var enderman = EndermanState.init(.{ 0.0, 64.0, 0.0 });

    // In rain for 0.3s
    _ = enderman.updateWaterAndRain(0.3, true, null);

    // Moved to dry shelter (in_water_or_rain = false): timer resets
    const dry_tick = enderman.updateWaterAndRain(0.3, false, null);
    try std.testing.expectEqual(@as(f32, 0.0), dry_tick.damage_dealt);
    try std.testing.expect(!dry_tick.panicked_teleport);
    try std.testing.expectEqual(@as(f32, 0.0), enderman.water_damage_timer);
    try std.testing.expectEqual(@as(f32, 40.0), enderman.health);
}

test "isDryShelter verifies roof protection from rain and absence of water" {
    // In water is never dry shelter regardless of rain or roof
    try std.testing.expect(!isDryShelter(true, true, false));
    try std.testing.expect(!isDryShelter(true, false, true));

    // Raining with no overhead cover -> not dry shelter
    try std.testing.expect(!isDryShelter(false, false, true));

    // Raining with overhead cover -> valid dry shelter!
    try std.testing.expect(isDryShelter(false, true, true));

    // Not raining and not in water -> dry shelter!
    try std.testing.expect(isDryShelter(false, false, false));
}

test "generateTeleportOffset produces bounded 3D offsets within radius" {
    var seed: u64 = 12345;
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const offset = generateTeleportOffset(seed, 32.0);
        try std.testing.expect(offset[0] >= -32.0 and offset[0] <= 32.0);
        try std.testing.expect(offset[1] >= -8.0 and offset[1] <= 8.0);
        try std.testing.expect(offset[2] >= -32.0 and offset[2] <= 32.0);
        seed +%= 101;
    }
}
