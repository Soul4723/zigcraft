const hotbar_mod = @import("world/hotbar.zig");
const interact_mod = @import("world/interact.zig");
const wear_mod = @import("world/tool_wear.zig");
const mining_mod = @import("world/mining.zig");
const toast_mod = @import("renderer/toast.zig");
const combat_mod = @import("world/combat.zig");
const proj_mod = @import("world/projectile.zig");
const smelt_mod = @import("world/smelting.zig");
const boom_mod = @import("world/explosives.zig");
const sapling_mod = @import("world/sapling.zig");
const cache_mod = @import("world/component_cache.zig");
const fluid_mod = @import("world/fluid_wash.zig");
const falling_mod = @import("world/falling_blocks.zig");
const hazard_mod = @import("world/hazard.zig");
const portal_mod = @import("world/portal.zig");
const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
const camera_mod = @import("camera.zig");
const math = @import("math.zig");
const chunk_manager_mod = @import("chunk_manager.zig");
const pick_mod = @import("pick.zig");
const sky_mod = @import("sky.zig");
const player_mod = @import("player.zig");
const block_mod = @import("world/block.zig");
const redstone_mod = @import("world/redstone.zig");
const ui_mod = @import("renderer/ui.zig");
const audio_mod = @import("audio/audio.zig");
const texture_mod = @import("renderer/texture.zig");
const entity_mod = @import("entity.zig");
const inventory_mod = @import("inventory.zig");
const highlight_mod = @import("renderer/highlight.zig");
const particles_mod = @import("renderer/particles.zig");

const window_width = 1280;
const window_height = 720;
const window_title = "Zigcraft";

var pick_manager: ?*chunk_manager_mod.ChunkManager = null;


fn pickBlockWorld(x: i32, y: i32, z: i32) block_mod.BlockId {
    const mgr = pick_manager orelse return .air;
    return mgr.getBlockWorld(x, y, z);
}
fn pickSolid(x: i32, y: i32, z: i32) bool {
    return pick_manager.?.isSolidWorld(x, y, z);
}

fn pickFluid(x: i32, y: i32, z: i32) bool {
    const mgr = pick_manager orelse return false;
    return mgr.getBlockWorld(x, y, z) == .water;
}

fn pickLadder(x: i32, y: i32, z: i32) bool {
    const mgr = pick_manager orelse return false;
    return mgr.getBlockWorld(x, y, z).is_ladder();
}



fn getFootstepSound(block: block_mod.BlockId) audio_mod.synth.SoundType {
    return switch (block_mod.footstepType(block)) {
        .grass => .step_grass,
        .stone => .step_stone,
        .wood => .step_wood,
        .dirt => .step_dirt,
        .sand => .step_sand,
        .snow => .step_snow,
        .wool => .step_wool,
    };
}

pub fn main() !void {
    std.debug.print("zigcraft v0.0.8\n", .{});

    if (c.glfwInit() == c.GLFW_FALSE) {
        std.debug.print("failed to initialize GLFW\n", .{});
        return error.GlfwInitFailed;
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const window = c.glfwCreateWindow(
        window_width,
        window_height,
        window_title,
        null,
        null,
    ) orelse {
        std.debug.print("failed to create GLFW window\n", .{});
        return error.WindowCreationFailed;
    };
    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);

    const gl_version = c.glGetString(c.GL_VERSION);
    if (gl_version != null) {
        std.debug.print("OpenGL {s}\n", .{gl_version});
    }

    c.glEnable(c.GL_DEPTH_TEST);
    c.glClearColor(0.05, 0.05, 0.1, 1.0);

    // Hide and capture cursor for first-person camera control
    c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);

    // Initial player position: center of world
    var player = player_mod.Player.init(24, 20, 24);
    var cam = camera_mod.Camera.init();
    cam.yaw = -std.math.pi / 2.0 - 0.35;
    cam.pitch = -0.3;
    cam.position = player.eyePos();

    // World chunk manager: radius 3 (7x7 = 49 chunks streaming around player)
    const init_cx = @as(i32, @intFromFloat(@floor(player.pos.x / 16.0)));
    const init_cz = @as(i32, @intFromFloat(@floor(player.pos.z / 16.0)));
    var manager = try chunk_manager_mod.ChunkManager.init(std.heap.page_allocator, 3, init_cx, init_cz, 1337, "saves");
    defer manager.deinit();
    pick_manager = &manager;

    var sky = try sky_mod.SkyRenderer.init(std.heap.page_allocator);
    defer sky.deinit();

    var ui = try ui_mod.UIRenderer.init(std.heap.page_allocator);
    defer ui.deinit();

    var highlight = try highlight_mod.HighlightRenderer.init(std.heap.page_allocator);
    defer highlight.deinit();

    var particles = try particles_mod.ParticleSystem.init(std.heap.page_allocator);
    defer particles.deinit();

    var audio = audio_mod.AudioSystem.init();
    defer audio.deinit();

    const atlas_texture = texture_mod.createBlockTexture();
    defer c.glDeleteTextures(1, &atlas_texture);
    var mob_manager = try entity_mod.mob_manager.MobManager.init(std.heap.page_allocator, atlas_texture);
    defer mob_manager.deinit();

    // Player Inventory & Crafting state
    var inventory = inventory_mod.Inventory.init();
    var cursor_stack = inventory_mod.ItemStack{};
    var inventory_open = false;
    var e_key_down = false;
    var selected_slot: usize = 0;
    var mine = mining_mod.MineState{};
    var tool_wear = wear_mod.Wear{};

    // Timing & Day/Night cycle
    var last_time = c.glfwGetTime();
    var frame_count: u64 = 0;
    var hud_frames: u64 = 0;
    var hud_time: f32 = 0;
    var left_down = false;
    var right_down = false;
    var mob_hit_cooldown: f32 = 0.0;
    var bed_cooldown: f32 = 0.0;
    var flint_cooldown: f32 = 0.0;
    var throw_cooldown: f32 = 0.0;
    var wolf_bite_cooldown: f32 = 0.0;
    const Fuse = boom_mod.Fuse;
    var fuses: [boom_mod.fuse_cap]Fuse = undefined;
    var fuse_count: usize = 0;
    const Torch = cache_mod.Torch;
    var torches: [cache_mod.torch_cap]Torch = undefined;
    var torch_count: usize = 0;
    var torch_puff_timer: f32 = 0.0;
    const Thrown = struct { pos: math.Vec3, vel: math.Vec3, life: f32 };
    var thrown: [proj_mod.thrown_cap]Thrown = undefined;
    var thrown_count: usize = 0;
    const FurnaceJob = smelt_mod.FurnaceJob;
    var furnaces: [smelt_mod.furnace_cap]FurnaceJob = undefined;
    var furnace_count: usize = 0;
    const Chest = struct { x: i32, y: i32, z: i32, items: [4]inventory_mod.ItemStack };
    var chests: [cache_mod.chest_cap]Chest = undefined;
    var chest_count: usize = 0;
    var sprouts: [sapling_mod.sprout_cap]sapling_mod.Sprout = undefined;
    var sprout_count: usize = 0;
    const Plate = cache_mod.Plate;
    var plates: [cache_mod.plate_cap]Plate = undefined;
    var plate_count: usize = 0;
    const Wire = cache_mod.Wire;
    var wires: [cache_mod.wire_cap]Wire = undefined;
    var wire_count: usize = 0;
    const Repeater = cache_mod.Repeater;
    var repeaters: [cache_mod.repeater_cap]Repeater = undefined;
    var repeater_count: usize = 0;
    var known_stage_chunks: [64]struct { x: i32, z: i32 } = undefined;
    var known_stage_count: usize = 0;
    const Lamp = cache_mod.Lamp;
    var lamps: [cache_mod.lamp_cap]Lamp = undefined;
    var lamp_count: usize = 0;
    const RedTorch = cache_mod.RedTorch;
    var red_torches: [cache_mod.red_torch_cap]RedTorch = undefined;
    var red_torch_count: usize = 0;
    var toast = toast_mod.Toast{};
    var rs_cap_warned_plate = false;
    var rs_cap_warned_wire = false;
    var rs_cap_warned_rep = false;
    var rs_cap_warned_lamp = false;
    var rs_cap_warned_torch = false;
    const FallSand = falling_mod.FallSand;
    var fallings: [falling_mod.falling_cap]FallSand = undefined;
    var falling_count: usize = 0;
    var sand_scan: u8 = 0;
    var flow_timer: f32 = 0.0;
    var lava_ambient_timer: f32 = 0.0;
    var burn_sizzle_cooldown: f32 = 0.0;
    var portal_ambient_timer: f32 = 0.0;
    var portal_transit = portal_mod.PortalTransitState{};
    var chunk_retry_timer: f32 = 0.0;
    var world_time: f32 = 45.0; // Start at morning daylight
    var last_step_dist: f32 = 0.0;
    var was_in_water: bool = false;
    var was_eye_underwater: bool = false;

    // Mouse tracking
    var last_x: f64 = @floatFromInt(window_width / 2);
    var last_y: f64 = @floatFromInt(window_height / 2);
    var first_mouse = true;

    std.debug.print("ready. Dynamic chunks + AO + Day/Night Cycle + Audio. WASD move, mouse look, ESC close.\n", .{});

    while (c.glfwWindowShouldClose(window) == c.GLFW_FALSE) {
        // Delta time
        const current_time = c.glfwGetTime();
        const dt: f32 = @floatCast(current_time - last_time);
        last_time = current_time;

        // Advance 2-minute day/night cycle
        world_time = sky_mod.advanceTime(world_time, dt);

        // Toggle inventory screen with 'E' key (edge triggered)
        const e_key = c.glfwGetKey(window, c.GLFW_KEY_E) == c.GLFW_PRESS;
        if (e_key and !e_key_down) {
            inventory_open = !inventory_open;
            if (inventory_open) {
                c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_NORMAL);
            } else {
                c.glfwSetInputMode(window, c.GLFW_CURSOR, c.GLFW_CURSOR_DISABLED);
                first_mouse = true;
                // If cursor item was held when closing, return to inventory
                if (!cursor_stack.isEmpty()) {
                    _ = inventory.addItem(cursor_stack.item, cursor_stack.count);
                    cursor_stack.clear();
                }
            }
        }
        e_key_down = e_key;

        // Hotbar selection keys 1 through 6
        const hot_keys = [_]c_int{ c.GLFW_KEY_1, c.GLFW_KEY_2, c.GLFW_KEY_3, c.GLFW_KEY_4, c.GLFW_KEY_5, c.GLFW_KEY_6 };
        for (hot_keys, 0..) |hk, hi| {
            if (c.glfwGetKey(window, hk) == c.GLFW_PRESS) {
                if (hotbar_mod.slotForKey(@intCast(hi))) |slot| selected_slot = slot;
            }
        }
        selected_slot = hotbar_mod.clampSlot(selected_slot);

        // Keyboard input: poll movement keys and calculate wish direction
        const walk_vecs = player_mod.computeWalkVectors(cam.front());
        const walk_speed = 6.0;
        const key_w = c.glfwGetKey(window, c.GLFW_KEY_W) == c.GLFW_PRESS;
        const key_s = c.glfwGetKey(window, c.GLFW_KEY_S) == c.GLFW_PRESS;
        const key_d = c.glfwGetKey(window, c.GLFW_KEY_D) == c.GLFW_PRESS;
        const key_a = c.glfwGetKey(window, c.GLFW_KEY_A) == c.GLFW_PRESS;
        const norm_wish = player_mod.computeWishDirection(walk_vecs, key_w, key_s, key_d, key_a, inventory_open);
        const key_shift = c.glfwGetKey(window, c.GLFW_KEY_LEFT_SHIFT) == c.GLFW_PRESS;
        if (player.in_boat and key_shift) {
            // Dismount boat: recover boat into inventory or drop
            player.in_boat = false;
            _ = inventory.addItem(.boat, 1);
            audio.play(.click_off, 0.6);
            std.debug.print("dismounted boat\n", .{});
        }
        const jump = !inventory_open and (c.glfwGetKey(window, c.GLFW_KEY_SPACE) == c.GLFW_PRESS);

        // Detect soul sand floor contact for movement deceleration drag
        const f_px: i32 = @intFromFloat(@floor(player.pos.x));
        const f_py: i32 = @intFromFloat(@floor(player.pos.y - 0.1));
        const f_pz: i32 = @intFromFloat(@floor(player.pos.z));
        const floor_blk = manager.getBlockWorld(f_px, f_py, f_pz);
        player.on_soulsand = (floor_blk == .soul_sand);

        // Detect bubble column: water cell with soul sand (upward) or magma (downward whirlpool) underneath
        const p_col_type = hazard_mod.detectBubbleColumn(&pickBlockWorld, f_px, @intFromFloat(@floor(player.pos.y)), f_pz);
        player.in_bubble_column = (p_col_type == .upward);
        player.in_whirlpool = (p_col_type == .downward);
        if (player.in_bubble_column) {
            particles.spawnBubble(.{ player.pos.x, player.pos.y + 0.3, player.pos.z }, 3);
        } else if (player.in_whirlpool) {
            particles.spawnBubble(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 4);
        }

        player.tickPhysics(&pickSolid, &pickLadder, &pickFluid, norm_wish.x * walk_speed * dt, norm_wish.z * walk_speed * dt, jump, dt);
        player.tickVitals(dt);
        if (player.pos.y < -30.0) {
            // Fell out of world: damage through vitals path
            player.health = @max(0.0, player.health - 20.0 * dt);
        } else {
            // Suffocation: eye position inside solid opaque block damages player (1 hp/sec)
            const eye = player.eyePos();
            const ex: i32 = @intFromFloat(@floor(eye.x));
            const ey: i32 = @intFromFloat(@floor(eye.y));
            const ez: i32 = @intFromFloat(@floor(eye.z));
            const eye_block = manager.getBlockWorld(ex, ey, ez);
            if (hazard_mod.checkSuffocation(eye_block)) {
                player.health = @max(0.0, player.health - 1.0 * dt);
            }
            const is_underwater = hazard_mod.checkDrowning(eye_block);
            if (is_underwater and !was_eye_underwater) {
                audio.play(.underwater_submerge, 0.7);
            } else if (hazard_mod.shouldGaspOnSurface(was_eye_underwater, is_underwater, player.oxygen)) {
                // Surfaced with low oxygen: play splash gasp audio and emit mist droplets
                audio.play(.splash, 0.85);
                const front = cam.front();
                particles.spawnBreathMist(.{ eye.x, eye.y - 0.1, eye.z }, .{ front.x, front.y, front.z }, 8);
            }
            was_eye_underwater = is_underwater;

            if (player.in_water != was_in_water) {
                const splash_vol: f32 = if (player.in_water and player.water_entry_speed > 6.0) 0.9 else 0.6;
                audio.play(.splash, splash_vol);
                if (player.in_water) {
                    const splash_count = fluid_mod.calculateSplashParticleCount(player.water_entry_speed);
                    if (splash_count > 0) {
                        particles.spawnWaterSplash(.{ player.pos.x, player.pos.y, player.pos.z }, splash_count);
                    }
                }
                was_in_water = player.in_water;
            }

            player.oxygen = hazard_mod.tickOxygen(player.oxygen, is_underwater, dt);
            const drown_dmg = hazard_mod.calculateDrowningDamage(player.oxygen, dt);
            if (drown_dmg > 0.0) {
                player.health = @max(0.0, player.health - drown_dmg);
                // Drowning gasp emits bubble burst
                particles.spawnBubble(.{ eye.x, eye.y, eye.z }, 4);
            } else if (player.in_boat and player.in_water and (norm_wish.x != 0 or norm_wish.z != 0)) {
                // Boat cruising wake & bow spray particles
                if (@as(u32, @intFromFloat(current_time * 16.0)) % 2 == 0) {
                    particles.spawnBoatWake(.{ player.pos.x, player.pos.y, player.pos.z }, .{ norm_wish.x, 0.0, norm_wish.z }, 2);
                }
            } else if (player.in_water and (norm_wish.x != 0 or norm_wish.z != 0 or jump)) {
                // Swimming trail bubbles
                if (@as(u32, @intFromFloat(current_time * 12.0)) % 4 == 0) {
                    particles.spawnBubble(.{ player.pos.x, player.pos.y + 0.6, player.pos.z }, 1);
                }
            }

            const px_i: i32 = @intFromFloat(@floor(player.pos.x));
            const py_i: i32 = @intFromFloat(@floor(player.pos.y));
            const pz_i: i32 = @intFromFloat(@floor(player.pos.z));
            if (hazard_mod.checkCactusContact(&pickBlockWorld, px_i, py_i, pz_i)) {
                player.health = hazard_mod.applyDamageClamped(player.health, hazard_mod.contact_rate, dt);
            }

            // Campfire / magma / lava contact burn hazard (negated by fire resistance immunity)
            const feet_b = manager.getBlockWorld(px_i, py_i, pz_i);
            const head_b = manager.getBlockWorld(px_i, py_i + 1, pz_i);
            burn_sizzle_cooldown = @max(0.0, burn_sizzle_cooldown - dt);
            const is_in_lava = hazard_mod.checkLavaHazard(feet_b) or hazard_mod.checkLavaHazard(head_b);
            const is_in_burn = hazard_mod.checkBurnContact(feet_b) or hazard_mod.checkBurnContact(head_b);

            if (is_in_lava) {
                particles.spawnFlame(px_i, py_i, pz_i, 3);
                if (!player.isFireImmune()) {
                    player.health = hazard_mod.applyDamageClamped(player.health, hazard_mod.lava_burn_rate, dt);
                    if (burn_sizzle_cooldown <= 0.0) {
                        audio.play(.burn_sizzle, 0.7);
                        burn_sizzle_cooldown = 0.5;
                    }
                }
            } else if (is_in_burn) {
                particles.spawnBurnSparks(.{ player.pos.x, player.pos.y, player.pos.z }, 2);
                if (!player.isFireImmune()) {
                    player.health = hazard_mod.applyDamageClamped(player.health, hazard_mod.burn_rate, dt);
                    if (burn_sizzle_cooldown <= 0.0) {
                        audio.play(.burn_sizzle, 0.6);
                        burn_sizzle_cooldown = 0.6;
                    }
                }
            }

            // Periodic ambient lava bubbling and smoke ember emission around player
            lava_ambient_timer += dt;
            if (lava_ambient_timer >= 0.25) {
                lava_ambient_timer = 0.0;
                // Sample random offset in 16x16x8 cylinder around player
                const l_seed = @as(u32, @intFromFloat(current_time * 100.0)) ^ @as(u32, @bitCast(px_i *% 31 +% pz_i));
                const l_dx: i32 = @as(i32, @intCast(l_seed % 17)) - 8;
                const l_dz: i32 = @as(i32, @intCast((l_seed / 17) % 17)) - 8;
                const l_dy: i32 = @as(i32, @intCast((l_seed / 289) % 9)) - 4;
                const lx = px_i + l_dx;
                const ly = py_i + l_dy;
                const lz = pz_i + l_dz;
                if (manager.getBlockWorld(lx, ly, lz) == .lava) {
                    // Check if block above is open to air/transparency for bubbling surface
                    const above = manager.getBlockWorld(lx, ly + 1, lz);
                    if (above == .air or above.is_transparent()) {
                        const l_pos = [3]f32{ @as(f32, @floatFromInt(lx)) + 0.5, @as(f32, @floatFromInt(ly)) + 0.9, @as(f32, @floatFromInt(lz)) + 0.5 };
                        particles.spawnLavaEmber(l_pos, 3);
                        // Emit pop or simmer bubble with spatial attenuation
                        const snd_type: audio_mod.synth.SoundType = if ((l_seed & 1) == 0) .lava_pop else .lava_bubble;
                        audio.playAt(snd_type, l_pos, .{ player.pos.x, player.pos.y, player.pos.z }, 0.7, 16.0);
                    }
                }
            }

            // Check if player is standing inside a nether portal block
            const in_portal = (feet_b == .nether_portal or head_b == .nether_portal);
            if (in_portal) {
                // Emit continuous swirls and accelerating orbital vortex ring while charging transit
                particles.spawnPortalParticles(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 2);
                const charge_frac = portal_transit.inside_timer / portal_mod.PORTAL_TRIGGER_TIME;
                const ring_radius = 1.0 - 0.3 * charge_frac;
                particles.spawnPortalVortex(.{ player.pos.x, player.pos.y + 0.9, player.pos.z }, ring_radius, 4, @floatCast(current_time));
            }
            if (portal_transit.tick(in_portal, dt)) {
                // Dimension warp triggered!
                const warp_target = portal_mod.PortalTransitState.calculateWarpPosition(
                    if (portal_transit.current_dim == .nether) .overworld else .nether,
                    player.pos.x,
                    player.pos.y,
                    player.pos.z,
                );
                player.pos.x = warp_target[0];
                player.pos.z = warp_target[2];
                manager.is_nether = (portal_transit.current_dim == .nether);
                // Burst effects and audio warp
                particles.spawnPortalParticles(.{ player.pos.x, player.pos.y + 1.0, player.pos.z }, 24);
                audio.play(.portal_warp, 1.0);
                std.debug.print("dimension transit: warped to {s} at ({d:.1}, {d:.1}, {d:.1})\n", .{
                    @tagName(portal_transit.current_dim),
                    player.pos.x,
                    player.pos.y,
                    player.pos.z,
                });
            }

            // Periodic ambient nether portal hum and particle swirl around player
            portal_ambient_timer += dt;
            if (portal_ambient_timer >= 0.3) {
                portal_ambient_timer = 0.0;
                const p_seed = @as(u32, @intFromFloat(current_time * 80.0)) ^ @as(u32, @bitCast(px_i *% 19 +% pz_i));
                const p_dx: i32 = @as(i32, @intCast(p_seed % 17)) - 8;
                const p_dz: i32 = @as(i32, @intCast((p_seed / 17) % 17)) - 8;
                const p_dy: i32 = @as(i32, @intCast((p_seed / 289) % 9)) - 4;
                const pox = px_i + p_dx;
                const poy = py_i + p_dy;
                const poz = pz_i + p_dz;
                if (manager.getBlockWorld(pox, poy, poz) == .nether_portal) {
                    const po_pos = [3]f32{ @as(f32, @floatFromInt(pox)) + 0.5, @as(f32, @floatFromInt(poy)) + 0.5, @as(f32, @floatFromInt(poz)) + 0.5 };
                    particles.spawnPortalParticles(po_pos, 4);
                    audio.playAt(.portal_hum, po_pos, .{ player.pos.x, player.pos.y, player.pos.z }, 0.75, 18.0);
                }
            }
        }
        if (player.isDead()) {
            audio.play(.hurt, 0.8);
            std.debug.print("you died; respawning\n", .{});
            player.respawn(player.spawn_point.x, player.spawn_point.y, player.spawn_point.z);
        }
        cam.position = player.eyePos();

        // Sync redstone caches from world state so TNT/mining/streaming/persistence
        // edits (which bypass placement tracking) are still simulated. Power flags
        // are re-derived from block ids; only repeater delay timers persist in session.
        // Throttled to every 4th frame: ~50k block reads/frame average.
        if (frame_count % 4 == 0) {
            {
                var snap: [64][4]i32 = undefined;
                var sn: usize = 0;
                for (repeaters[0..repeater_count]) |rep| {
                    if (sn >= snap.len) break;
                    snap[sn] = .{ rep.x, rep.y, rep.z, rep.stage };
                    sn += 1;
                }
                chunk_manager_mod.ChunkManager.setStageSnapshot(snap[0..sn]);
                var bsnap: [64][4]i32 = undefined;
                var bn: usize = 0;
                for (red_torches[0..red_torch_count]) |bt| {
                    if (bn >= bsnap.len) break;
                    if (bt.burnout > 0.0) {
                        bsnap[bn] = .{ bt.x, bt.y, bt.z, @intFromFloat(bt.burnout) };
                        bn += 1;
                    }
                }
                chunk_manager_mod.ChunkManager.setBurnoutSnapshot(bsnap[0..bn]);
            }
            // Apply persisted repeater stages for newly seen chunks
            var stage_iter = manager.chunks.iterator();
            while (stage_iter.next()) |entry| {
                const scx = entry.key_ptr.x;
                const scz = entry.key_ptr.z;
                var known = false;
                for (known_stage_chunks[0..known_stage_count]) |kc| {
                    if (kc.x == scx and kc.z == scz) {
                        known = true;
                        break;
                    }
                }
                if (!known) {
                    if (known_stage_count < known_stage_chunks.len) {
                        known_stage_chunks[known_stage_count] = .{ .x = scx, .z = scz };
                        known_stage_count += 1;
                    }
                    var burned = [_][4]i32{.{ 0, 0, 0, 0 }} ** 64;
                    const nburned = manager.loadBurnout(scx, scz, &burned);
                    var bi: usize = 0;
                    while (bi < nburned) : (bi += 1) {
                        for (red_torches[0..red_torch_count]) |*rt| {
                            if (rt.x == burned[bi][0] and rt.y == burned[bi][1] and rt.z == burned[bi][2]) {
                                rt.burnout = @floatFromInt(burned[bi][3]);
                                break;
                            }
                        }
                    }
                    var staged = [_][4]i32{.{ 0, 0, 0, 0 }} ** 64;
                    const nstaged = manager.loadStages(scx, scz, &staged);
                    var si: usize = 0;
                    while (si < nstaged) : (si += 1) {
                        for (repeaters[0..repeater_count]) |*rep| {
                            if (rep.x == staged[si][0] and rep.y == staged[si][1] and rep.z == staged[si][2]) {
                                rep.stage = @intCast(staged[si][3] & 3);
                                break;
                            }
                        }
                    }
                }
            }
            var rs_iter = manager.chunks.iterator();
            while (rs_iter.next()) |entry| {
                const rcx = entry.key_ptr.x;
                const rcz = entry.key_ptr.z;
                const rch = &entry.value_ptr.chunk;
                var ry: usize = 0;
                while (ry < 16) : (ry += 1) {
                    var rz: usize = 0;
                    while (rz < 16) : (rz += 1) {
                        var rx: usize = 0;
                        while (rx < 16) : (rx += 1) {
                            const rb = rch.blocks[ry][rz][rx];
                            if (!cache_mod.isTrackedRedstoneComponent(rb)) continue;
                            const wx: i32 = rcx * 16 + @as(i32, @intCast(rx));
                            const wy: i32 = @as(i32, @intCast(ry));
                            const wz: i32 = rcz * 16 + @as(i32, @intCast(rz));
                            switch (rb) {
                                .pressure_plate_up, .pressure_plate_down => {
                                    if (cache_mod.findPlate(&plates, plate_count, wx, wy, wz) == null) {
                                        if (plate_count < plates.len) {
                                            plates[plate_count] = .{ .x = wx, .y = wy, .z = wz, .down = (rb == .pressure_plate_down) };
                                            plate_count += 1;
                                        } else if (!rs_cap_warned_plate) {
                                            rs_cap_warned_plate = true;
                                            std.debug.print("redstone cap: plates full ({d}), some plates unsimulated\n", .{plates.len});
                                        }
                                    }
                                },
                                .redstone_wire_off, .redstone_wire_on => {
                                    if (cache_mod.findWire(&wires, wire_count, wx, wy, wz) == null) {
                                        if (wire_count < wires.len) {
                                            wires[wire_count] = .{ .x = wx, .y = wy, .z = wz, .powered = (rb == .redstone_wire_on) };
                                            wire_count += 1;
                                        } else if (!rs_cap_warned_wire) {
                                            rs_cap_warned_wire = true;
                                            std.debug.print("redstone cap: wires full ({d}), some wires unsimulated\n", .{wires.len});
                                            toast.showCapWarning();
                                        }
                                    }
                                },
                                .repeater_off, .repeater_on => {
                                    if (cache_mod.findRepeater(&repeaters, repeater_count, wx, wy, wz)) |idx| {
                                        if ((rb == .repeater_on) == repeaters[idx].powered) repeaters[idx].timer = 0.0;
                                    } else {
                                        if (repeater_count < repeaters.len) {
                                            repeaters[repeater_count] = .{ .x = wx, .y = wy, .z = wz, .powered = (rb == .repeater_on), .timer = 0.0, .stage = 0 };
                                            repeater_count += 1;
                                        } else if (!rs_cap_warned_rep) {
                                            rs_cap_warned_rep = true;
                                            std.debug.print("redstone cap: repeaters full ({d})\n", .{repeaters.len});
                                        }
                                    }
                                },
                                .redstone_lamp_off, .redstone_lamp_on => {
                                    if (cache_mod.findLamp(&lamps, lamp_count, wx, wy, wz)) |idx| {
                                        lamps[idx].lit = (rb == .redstone_lamp_on);
                                    } else {
                                        if (lamp_count < lamps.len) {
                                            lamps[lamp_count] = .{ .x = wx, .y = wy, .z = wz, .lit = (rb == .redstone_lamp_on) };
                                            lamp_count += 1;
                                        } else if (!rs_cap_warned_lamp) {
                                            rs_cap_warned_lamp = true;
                                            std.debug.print("redstone cap: lamps full ({d})\n", .{lamps.len});
                                        }
                                    }
                                },
                                .redstone_torch_off, .redstone_torch_on => {
                                    if (cache_mod.findRedTorch(&red_torches, red_torch_count, wx, wy, wz)) |idx| {
                                        red_torches[idx].lit = (rb == .redstone_torch_on);
                                    } else {
                                        if (red_torch_count < red_torches.len) {
                                            red_torches[red_torch_count] = .{ .x = wx, .y = wy, .z = wz, .lit = (rb == .redstone_torch_on), .flips = [_]f32{-100.0} ** 8, .flip_count = 0, .burnout = 0.0 };
                                            red_torch_count += 1;
                                        } else if (!rs_cap_warned_torch) {
                                            rs_cap_warned_torch = true;
                                            std.debug.print("redstone cap: torches full ({d})\n", .{red_torches.len});
                                        }
                                    }
                                },
                                else => {},
                            }
                        }
                    }
                }
            }
        }

        // Pressure plate trigger logic: test player and mob positions on active plates
        {
            var pi: usize = 0;
            while (pi < plate_count) {
                const pl = &plates[pi];
                const blk = manager.getBlockWorld(pl.x, pl.y, pl.z);
                if (blk != .pressure_plate_up and blk != .pressure_plate_down) {
                    cache_mod.swapRemove(&plates, &plate_count, pi);
                    continue;
                }

                // Check if player or any mob is standing within plate bounds
                var stepped = cache_mod.isPosOnPlate(player.pos.x, player.pos.y, player.pos.z, pl.x, pl.y, pl.z, 0.2);
                if (!stepped) {
                    for (mob_manager.mobs.items) |m| {
                        if (cache_mod.isPosOnPlate(m.pos.x, m.pos.y, m.pos.z, pl.x, pl.y, pl.z, 0.3)) {
                            stepped = true;
                            break;
                        }
                    }
                }

                switch (cache_mod.evaluatePlateStep(pl.down, stepped)) {
                    .trigger => {
                        pl.down = true;
                        _ = try manager.editAndRemesh(pl.x, pl.y, pl.z, .pressure_plate_down);
                        audio.playAt(.click_on, .{ @as(f32, @floatFromInt(pl.x)) + 0.5, @as(f32, @floatFromInt(pl.y)) + 0.1, @as(f32, @floatFromInt(pl.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.85, 20.0);
                        for (cache_mod.plate_door_offsets) |off| {
                            const dx = pl.x + off[0];
                            const dy = pl.y + off[1];
                            const dz = pl.z + off[2];
                            const pdb = manager.getBlockWorld(dx, dy, dz);
                            if (redstone_mod.targetDoorState(pdb, true)) |target_db| {
                                _ = try manager.editAndRemesh(dx, dy, dz, target_db);
                                std.debug.print("plate triggered: opened door ({d},{d},{d})\n", .{ dx, dy, dz });
                            }
                        }
                    },
                    .release => {
                        pl.down = false;
                        _ = try manager.editAndRemesh(pl.x, pl.y, pl.z, .pressure_plate_up);
                        audio.playAt(.click_off, .{ @as(f32, @floatFromInt(pl.x)) + 0.5, @as(f32, @floatFromInt(pl.y)) + 0.1, @as(f32, @floatFromInt(pl.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.7, 20.0);
                        for (cache_mod.plate_door_offsets) |off| {
                            const dx = pl.x + off[0];
                            const dy = pl.y + off[1];
                            const dz = pl.z + off[2];
                            const pdb = manager.getBlockWorld(dx, dy, dz);
                            if (redstone_mod.targetDoorState(pdb, false)) |target_db| {
                                _ = try manager.editAndRemesh(dx, dy, dz, target_db);
                                std.debug.print("plate released: closed door ({d},{d},{d})\n", .{ dx, dy, dz });
                            }
                        }
                    },
                    .none => {},
                }
                pi += 1;
            }
        }

        // Water washes away redstone: wire/torch/repeater/plate/lever in water pops
        {
            var wri: usize = 0;
            while (wri < wire_count) {
                const w = &wires[wri];
                const wb = manager.getBlockWorld(w.x, w.y, w.z);
                if (fluid_mod.evaluateComponentWash(wb, manager.getBlockWorld(w.x, w.y + 1, w.z)) == .wash) {
                    _ = try manager.editAndRemesh(w.x, w.y, w.z, .air);
                    if (fluid_mod.componentWashDebris(wb)) |deb| particles.spawnBlockDebris(w.x, w.y, w.z, .{ deb.r, deb.g, deb.b }, 4);
                    if (fluid_mod.inPickupRange(@floatFromInt(w.x), @floatFromInt(w.z), player.pos.x, player.pos.z)) _ = inventory.addItem(.redstone_dust, 1);
                    cache_mod.swapRemove(&wires, &wire_count, wri);
                    continue;
                }
                wri += 1;
            }
            var rti2: usize = 0;
            while (rti2 < red_torch_count) {
                const rt = &red_torches[rti2];
                if (fluid_mod.evaluateComponentWash(manager.getBlockWorld(rt.x, rt.y, rt.z), .air) == .wash) {
                    _ = try manager.editAndRemesh(rt.x, rt.y, rt.z, .air);
                    if (fluid_mod.componentWashDebris(.redstone_torch_on)) |deb| particles.spawnBlockDebris(rt.x, rt.y, rt.z, .{ deb.r, deb.g, deb.b }, 4);
                    if (fluid_mod.inPickupRange(@floatFromInt(rt.x), @floatFromInt(rt.z), player.pos.x, player.pos.z)) _ = inventory.addItem(.redstone_torch, 1);
                    cache_mod.swapRemove(&red_torches, &red_torch_count, rti2);
                    continue;
                }
                rti2 += 1;
            }
            var rpi: usize = 0;
            while (rpi < repeater_count) {
                const rep = &repeaters[rpi];
                if (fluid_mod.evaluateComponentWash(manager.getBlockWorld(rep.x, rep.y, rep.z), .air) == .wash) {
                    _ = try manager.editAndRemesh(rep.x, rep.y, rep.z, .air);
                    if (fluid_mod.componentWashDebris(.repeater_off)) |deb| particles.spawnBlockDebris(rep.x, rep.y, rep.z, .{ deb.r, deb.g, deb.b }, 4);
                    if (fluid_mod.inPickupRange(@floatFromInt(rep.x), @floatFromInt(rep.z), player.pos.x, player.pos.z)) _ = inventory.addItem(.redstone_repeater, 1);
                    cache_mod.swapRemove(&repeaters, &repeater_count, rpi);
                    continue;
                }
                rpi += 1;
            }
            var ppi: usize = 0;
            while (ppi < plate_count) {
                const pl = &plates[ppi];
                if (fluid_mod.evaluateComponentWash(manager.getBlockWorld(pl.x, pl.y, pl.z), .air) == .wash) {
                    _ = try manager.editAndRemesh(pl.x, pl.y, pl.z, .air);
                    if (fluid_mod.componentWashDebris(.pressure_plate_up)) |deb| particles.spawnBlockDebris(pl.x, pl.y, pl.z, .{ deb.r, deb.g, deb.b }, 4);
                    if (fluid_mod.inPickupRange(@floatFromInt(pl.x), @floatFromInt(pl.z), player.pos.x, player.pos.z)) _ = inventory.addItem(.pressure_plate, 1);
                    cache_mod.swapRemove(&plates, &plate_count, ppi);
                    continue;
                }
                ppi += 1;
            }
        }

                // Redstone wire power: BFS signal strength from sources (15 max, -1/wire).
        // Order-independent; session flags only mirror block state.
        {
            const adj_dirs = [_][3]i32{
                .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
                .{ 0, -1, 0 }, .{ 0, 1, 0 },
            };
            {
                var wi: usize = 0;
                while (wi < wire_count) {
                    const w = &wires[wi];
                    const cur_b = manager.getBlockWorld(w.x, w.y, w.z);
                    if (cur_b != .redstone_wire_off and cur_b != .redstone_wire_on) {
                        cache_mod.swapRemove(&wires, &wire_count, wi);
                        continue;
                    }
                    wi += 1;
                }
            }
            var strength: [256]u4 = [_]u4{0} ** 256;
            var wi: usize = 0;
            while (wi < wire_count) : (wi += 1) {
                const w = &wires[wi];
                for (adj_dirs) |ad| {
                    const nb = manager.getBlockWorld(w.x + ad[0], w.y + ad[1], w.z + ad[2]);
                    if (redstone_mod.isSource(nb)) {
                        strength[wi] = redstone_mod.max_strength;
                        break;
                    }
                }
            }
            // Relax along wire graph until no strength rises (Bellman-Ford style,
            // capped at wire_count passes; typically settles in chain-length passes).
            var pass: usize = 0;
            var rising = true;
            while (rising and pass < wire_count) : (pass += 1) {
                rising = false;
                wi = 0;
                while (wi < wire_count) : (wi += 1) {
                    const w = &wires[wi];
                    var best: u4 = strength[wi];
                    for (adj_dirs) |ad| {
                        const nx = w.x + ad[0];
                        const ny = w.y + ad[1];
                        const nz = w.z + ad[2];
                        const nb = manager.getBlockWorld(nx, ny, nz);
                        if (nb != .redstone_wire_on and nb != .redstone_wire_off) continue;
                        var ni: usize = 0;
                        while (ni < wire_count) : (ni += 1) {
                            const o = &wires[ni];
                            if (o.x == nx and o.y == ny and o.z == nz) {
                                best = redstone_mod.relaxWireStrength(best, &.{strength[ni]});
                                break;
                            }
                        }
                    }
                    if (best > strength[wi]) {
                        strength[wi] = best;
                        rising = true;
                    }
                }
            }
            wi = 0;
            while (wi < wire_count) : (wi += 1) {
                const w = &wires[wi];
                const want = strength[wi] > 0;
                if (want and !w.powered) {
                    w.powered = true;
                    _ = try manager.editAndRemesh(w.x, w.y, w.z, .redstone_wire_on);
                    particles.spawnFlame(w.x, w.y, w.z, 2);
                    for (adj_dirs) |ad| {
                        const tx = w.x + ad[0];
                        const ty = w.y + ad[1];
                        const tz = w.z + ad[2];
                        if (manager.getBlockWorld(tx, ty, tz) == .tnt and fuse_count < fuses.len) {
                            if (boom_mod.findFuse(fuses[0..fuse_count], tx, ty, tz) == null) {
                                fuses[fuse_count] = .{ .x = tx, .y = ty, .z = tz, .t = boom_mod.fuse_time };
                                fuse_count += 1;
                                audio.play(.place_block, 0.8);
                                std.debug.print("redstone wire ignited TNT ({d},{d},{d})\n", .{ tx, ty, tz });
                            }
                        }
                        const wb = manager.getBlockWorld(tx, ty, tz);
                        if (redstone_mod.targetDoorState(wb, true)) |target_db| {
                            _ = try manager.editAndRemesh(tx, ty, tz, target_db);
                        }
                    }
                } else if (!want and w.powered) {
                    w.powered = false;
                    _ = try manager.editAndRemesh(w.x, w.y, w.z, .redstone_wire_off);
                    for (adj_dirs) |ad| {
                        const tx = w.x + ad[0];
                        const ty = w.y + ad[1];
                        const tz = w.z + ad[2];
                        const wb = manager.getBlockWorld(tx, ty, tz);
                        if (redstone_mod.targetDoorState(wb, false)) |target_db| {
                            _ = try manager.editAndRemesh(tx, ty, tz, target_db);
                        }
                    }
                }
            }
        }

        // Redstone Repeater logic: 1-tick (0.1s) delay, unidirectional diode amplifier
        {
            var ri: usize = 0;
            while (ri < repeater_count) {
                const rep = &repeaters[ri];
                const cur_b = manager.getBlockWorld(rep.x, rep.y, rep.z);
                if (cur_b != .repeater_off and cur_b != .repeater_on) {
                    cache_mod.swapRemove(&repeaters, &repeater_count, ri);
                    continue;
                }

                const input_powered = redstone_mod.isRepeaterInputPowered(&pickBlockWorld, rep.x, rep.y, rep.z);

                const delay: f32 = redstone_mod.repeaterDelay(rep.stage);
                if (input_powered and !rep.powered) {
                    rep.timer += dt;
                    if (rep.timer >= delay) {
                        rep.powered = true;
                        rep.timer = 0.0;
                        _ = try manager.editAndRemesh(rep.x, rep.y, rep.z, .repeater_on);
                        particles.spawnFlame(rep.x, rep.y, rep.z, 1);
                        audio.play(.click_on, 0.4);
                        std.debug.print("repeater powered ({d},{d},{d})\n", .{ rep.x, rep.y, rep.z });
                        for (redstone_mod.torch_door_dirs) |dd| {
                            const db = manager.getBlockWorld(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2]);
                            if (redstone_mod.targetDoorState(db, true)) |target_db| {
                                _ = try manager.editAndRemesh(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2], target_db);
                            }
                        }
                    }
                } else if (!input_powered and rep.powered) {
                    rep.timer += dt;
                    if (rep.timer >= delay) {
                        rep.powered = false;
                        rep.timer = 0.0;
                        _ = try manager.editAndRemesh(rep.x, rep.y, rep.z, .repeater_off);
                        for (redstone_mod.torch_door_dirs) |dd| {
                            const db = manager.getBlockWorld(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2]);
                            if (redstone_mod.targetDoorState(db, false)) |target_db| {
                                _ = try manager.editAndRemesh(rep.x + dd[0], rep.y + dd[1], rep.z + dd[2], target_db);
                            }
                        }
                    }
                } else {
                    rep.timer = 0.0;
                }
                ri += 1;
            }
        }

        // Redstone Lamp: checks 6 adjacent neighbors for active power (wire, plate, lever, repeater)
        {
            var li: usize = 0;
            while (li < lamp_count) {
                const la = &lamps[li];
                const cur_b = manager.getBlockWorld(la.x, la.y, la.z);
                if (cur_b != .redstone_lamp_off and cur_b != .redstone_lamp_on) {
                    cache_mod.swapRemove(&lamps, &lamp_count, li);
                    continue;
                }

                const power_in = redstone_mod.isLampPowered(&pickBlockWorld, la.x, la.y, la.z);
                switch (redstone_mod.resolveLampState(la.lit, power_in)) {
                    .turn_on => {
                        la.lit = true;
                        _ = try manager.editAndRemesh(la.x, la.y, la.z, .redstone_lamp_on);
                        particles.spawnFlame(la.x, la.y, la.z, 2);
                        std.debug.print("lamp lit ({d},{d},{d})\n", .{ la.x, la.y, la.z });
                    },
                    .turn_off => {
                        la.lit = false;
                        _ = try manager.editAndRemesh(la.x, la.y, la.z, .redstone_lamp_off);
                    },
                    .none => {},
                }
                li += 1;
            }
        }

        // Redstone Torch: NOT-gate inverter! Lit by default; turns OFF when supporting block below is powered
        {
            var rti: usize = 0;
            while (rti < red_torch_count) {
                const rt = &red_torches[rti];
                const cur_b = manager.getBlockWorld(rt.x, rt.y, rt.z);
                if (cur_b != .redstone_torch_on and cur_b != .redstone_torch_off) {
                    cache_mod.swapRemove(&red_torches, &red_torch_count, rti);
                    continue;
                }

                const base_powered = redstone_mod.isTorchBasePowered(&pickBlockWorld, rt.x, rt.y, rt.z);

                // Burnout: 8 flips within 3.2s -> 30s dead torch (MC clock protection)
                if (rt.burnout > 0.0) {
                    rt.burnout -= dt;
                    if (rt.burnout <= 0.0) {
                        rt.flip_count = 0;
                        std.debug.print("torch recovered ({d},{d},{d})\n", .{ rt.x, rt.y, rt.z });
                    }
                    rti += 1;
                    continue;
                }
                const flip_now: f32 = @floatCast(current_time);
                if (base_powered and rt.lit) {
                    rt.lit = false;
                    _ = try manager.editAndRemesh(rt.x, rt.y, rt.z, .redstone_torch_off);
                    for (redstone_mod.torch_door_dirs) |dd| {
                        const db = manager.getBlockWorld(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2]);
                        if (redstone_mod.targetDoorState(db, false)) |target_db| {
                            _ = try manager.editAndRemesh(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2], target_db);
                        }
                    }
                    rt.flips[@as(usize, rt.flip_count) % rt.flips.len] = flip_now;
                    rt.flip_count +%= 1;
                    if (redstone_mod.torchBurnedOut(rt.flips, flip_now)) {
                        rt.burnout = 30.0;
                        audio.play(.click_off, 0.5);
                        std.debug.print("torch burned out ({d},{d},{d})\n", .{ rt.x, rt.y, rt.z }); toast.showBurnoutWarning();
                    }
                } else if (!base_powered and !rt.lit) {
                    rt.lit = true;
                    _ = try manager.editAndRemesh(rt.x, rt.y, rt.z, .redstone_torch_on);
                    for (redstone_mod.torch_door_dirs) |dd| {
                        const db = manager.getBlockWorld(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2]);
                        if (redstone_mod.targetDoorState(db, true)) |target_db| {
                            _ = try manager.editAndRemesh(rt.x + dd[0], rt.y + dd[1], rt.z + dd[2], target_db);
                        }
                    }
                    particles.spawnFlame(rt.x, rt.y, rt.z, 2);
                    rt.flips[@as(usize, rt.flip_count) % rt.flips.len] = flip_now;
                    rt.flip_count +%= 1;
                    if (redstone_mod.torchBurnedOut(rt.flips, flip_now)) {
                        rt.burnout = 30.0;
                        audio.play(.click_off, 0.5);
                        std.debug.print("torch burned out ({d},{d},{d})\n", .{ rt.x, rt.y, rt.z }); toast.showBurnoutWarning();
                    }
                }
                rti += 1;
            }
        }

        // Footstep audio triggered periodically while walking on ground
        if (player.on_ground and player.distance_walked - last_step_dist >= 1.7) {
            last_step_dist = player.distance_walked;
            const ground_x: i32 = @intFromFloat(@floor(player.pos.x));
            const ground_y: i32 = @intFromFloat(@floor(player.pos.y - 0.1));
            const ground_z: i32 = @intFromFloat(@floor(player.pos.z));
            const ground_block = manager.getBlockWorld(ground_x, ground_y, ground_z);
            audio.play(getFootstepSound(ground_block), 0.5);
        }

        // Grow planted sprouts after 30s into 4-high trees with canopy
        var si: usize = 0;
        while (si < sprout_count) {
            sprouts[si].t += dt;
            if (sapling_mod.isReady(sprouts[si].t)) {
                const sx = sprouts[si].x;
                const sy = sprouts[si].y;
                const sz = sprouts[si].z;
                for (sapling_mod.tree_structure) |tb| {
                    if (manager.getBlockWorld(sx + tb.dx, sy + tb.dy, sz + tb.dz) == .air) {
                        _ = try manager.editAndRemesh(sx + tb.dx, sy + tb.dy, sz + tb.dz, tb.block);
                    }
                }
                std.debug.print("sapling grew\n", .{});
                cache_mod.swapRemove(&sprouts, &sprout_count, si);
            } else {
                si += 1;
            }
        }

        // Stream chunks dynamically around player
        chunk_retry_timer = @max(0.0, chunk_retry_timer - dt);
        if (chunk_retry_timer == 0.0) {
            manager.update(player.pos.x, player.pos.z) catch |err| switch (err) {
                error.ChunkSaveFailed, error.SidecarSaveFailed => {
                    std.debug.print("chunk streaming paused: {s}; unsaved chunks retained, retrying in 1 second\n", .{@errorName(err)});
                    chunk_retry_timer = 1.0;
                },
                else => return err,
            };
        }

        // Mob spawning and physics AI tick
        const is_night_spawn = @sin(world_time) <= 0.0;
        try mob_manager.ensureSpawnPopulation(&manager, player.pos.x, player.pos.z, is_night_spawn);
        mob_manager.tick(&pickSolid, &pickFluid, &pickBlockWorld, player.pos, player.radius, &audio, dt);

        // Wolf bites: contact damage with per-second cooldown
        wolf_bite_cooldown = combat_mod.tickCooldown(wolf_bite_cooldown, dt);
        if (wolf_bite_cooldown <= 0.0) {
            for (mob_manager.mobs.items) |m| {
                if (m.mob_type != .wolf) continue;
                const bdx = m.pos.x - player.pos.x;
                const bdz = m.pos.z - player.pos.z;
                const bdy = m.pos.y - player.pos.y;
                if (combat_mod.inBiteRange(bdx, bdz, bdy)) {
                    const pack_count = mob_manager.countNearbyWolves(m.pos, entity_mod.pack_hunt.pack_rally_radius);
                    const bonus = entity_mod.pack_hunt.packBonus(pack_count);
                    const hit = combat_mod.calculateWolfBite(bdx, bdz, bonus);
                    player.health = @max(0.0, player.health - hit.damage);
                    audio.play(.hurt, 0.8);
                    player.pos.x -= hit.knockback_x;
                    player.pos.z -= hit.knockback_z;
                    std.debug.print("wolf bite (hp={d:.1}, pack={d}, bonus={d:.1})\n", .{ player.health, pack_count, bonus });
                    wolf_bite_cooldown = combat_mod.wolf_bite_cooldown;
                    break;
                }
            }
        }

        // Mouse look
        var xpos: f64 = 0;
        var ypos: f64 = 0;
        c.glfwGetCursorPos(window, &xpos, &ypos);

        if (!inventory_open) {
            if (first_mouse) {
                last_x = xpos;
                last_y = ypos;
                first_mouse = false;
            }

            const x_offset: f32 = @floatCast(xpos - last_x);
            const y_offset: f32 = @floatCast(ypos - last_y);
            last_x = xpos;
            last_y = ypos;

            cam.processMouse(x_offset, y_offset);
        }

        // Normalized mouse coordinates in [-1, 1] for GUI
        var win_w: c_int = 1280;
        var win_h: c_int = 720;
        c.glfwGetFramebufferSize(window, &win_w, &win_h);
        const mouse_norm_x: f32 = @as(f32, @floatCast(xpos / @as(f64, @floatFromInt(win_w)))) * 2.0 - 1.0;
        const mouse_norm_y: f32 = 1.0 - @as(f32, @floatCast(ypos / @as(f64, @floatFromInt(win_h)))) * 2.0;

        // Build MVP: projection * view with portal dwell roll disorientation wobble
        const aspect: f32 = 1280.0 / 720.0;
        const proj = cam.projectionMatrix(aspect);
        const portal_roll: f32 = if (portal_transit.inside_timer > 0.0)
            @sin(@as(f32, @floatCast(current_time)) * 5.0) * (portal_transit.inside_timer / portal_mod.PORTAL_TRIGGER_TIME) * 0.12
        else
            0.0;
        const view = cam.viewMatrixWithRoll(portal_roll);
        const mvp = math.Mat4.mul(proj, view);

        // Calculate celestial orbit: sun direction and sky dome colors
        const sun_angle = world_time;
        const sun_y = @sin(sun_angle);
        const sun_x = @cos(sun_angle) * 0.8;
        const sun_dir = math.Vec3.normalize(math.Vec3.init(sun_x, @max(0.05, sun_y), 0.3));

        // Interpolate sky colors based on day factor
        const day_factor = sky_mod.dayFactor(sun_y);
        const day_top = math.Vec3.init(0.25, 0.50, 0.95);
        const night_top = math.Vec3.init(0.02, 0.03, 0.08);
        const day_horizon = math.Vec3.init(0.75, 0.87, 0.95);
        const night_horizon = math.Vec3.init(0.08, 0.10, 0.18);

        const sky_top = math.Vec3.init(
            night_top.x + (day_top.x - night_top.x) * day_factor,
            night_top.y + (day_top.y - night_top.y) * day_factor,
            night_top.z + (day_top.z - night_top.z) * day_factor,
        );
        const sky_horizon = math.Vec3.init(
            night_horizon.x + (day_horizon.x - night_horizon.x) * day_factor,
            night_horizon.y + (day_horizon.y - night_horizon.y) * day_factor,
            night_horizon.z + (day_horizon.z - night_horizon.z) * day_factor,
        );

        // Check if camera is underwater
        const cam_block = manager.getBlockWorld(
            @intFromFloat(@floor(cam.position.x)),
            @intFromFloat(@floor(cam.position.y)),
            @intFromFloat(@floor(cam.position.z)),
        );
        const cam_underwater = (cam_block == .water);

        // Render world
        if (cam_underwater) {
            c.glClearColor(0.08, 0.28, 0.58, 1.0);
        } else {
            c.glClearColor(0.1, 0.1, 0.1, 1.0);
        }
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        if (cam_underwater) {
            const water_deep = math.Vec3.init(0.04, 0.14, 0.32);
            const water_hzn = math.Vec3.init(0.08, 0.28, 0.58);
            sky.draw(mvp, cam.position, water_deep, water_hzn);
        } else {
            sky.draw(mvp, cam.position, sky_top, sky_horizon);
        }
        var lamp_spots: [8][3]f32 = [_][3]f32{.{ 0, -100, 0 }} ** 8;
        var lamp_spot_count: usize = 0;
        for (lamps[0..lamp_count]) |la| {
            if (lamp_spot_count >= lamp_spots.len) break;
            if (manager.getBlockWorld(la.x, la.y, la.z) != .redstone_lamp_on) continue;
            const dx: f32 = @as(f32, @floatFromInt(la.x)) + 0.5 - player.pos.x;
            const dz: f32 = @as(f32, @floatFromInt(la.z)) + 0.5 - player.pos.z;
            if (dx * dx + dz * dz > 48.0 * 48.0) continue;
            lamp_spots[lamp_spot_count] = .{ @as(f32, @floatFromInt(la.x)) + 0.5, @as(f32, @floatFromInt(la.y)) + 0.5, @as(f32, @floatFromInt(la.z)) + 0.5 };
            lamp_spot_count += 1;
        }
        const night_factor = 1.0 - day_factor;
        const stats = manager.draw(mvp, sun_dir, lamp_spots[0..lamp_spot_count], night_factor, cam.position, cam_underwater);
        try mob_manager.draw(mvp, sun_dir, cam.position, cam_underwater);

        // Update and render block debris particles
        particles.tick(dt);
        particles.draw(mvp.ptr());

        // Block highlight outline on aimed voxel (skip while mining-gui open)
        if (!inventory_open) {
            const dir_h = cam.front();
            if (pick_mod.raycast(&pickSolid, cam.position, dir_h, 8)) |hit_h| {
                const pulse = 0.5 + 0.5 * @sin(@as(f32, @floatCast(current_time)) * 4.0);
                highlight.draw(mvp.ptr(), hit_h.x, hit_h.y, hit_h.z, pulse);
            }
        }

        // Extract inventory slot colors and counts for rendering
        var hotbar_colors: [6][4]f32 = undefined;
        var hotbar_counts: [6]u8 = undefined;
        for (0..6) |i| {
            hotbar_colors[i] = inventory.slots[i].item.getColor();
            hotbar_counts[i] = inventory.slots[i].count;
        }

        if (!inventory_open) {
            const mine_frac: f32 = mine.fraction();
            ui.drawHUDWithBuffs(aspect, selected_slot, &hotbar_colors, &hotbar_counts, mine_frac, player.health, player.hunger, player.regen_timer > 0.0, player.oxygen, player.fire_resistance_timer);
            if (portal_transit.inside_timer > 0.0) {
                const vignette_intensity = portal_transit.inside_timer / portal_mod.PORTAL_TRIGGER_TIME;
                ui.drawPortalVignette(aspect, vignette_intensity);
            }
            if (toast.visible()) {
                const t_alpha = toast.tick(dt);
                ui.drawToast(aspect, t_alpha, toast.color);
            }
        } else {
            var main_colors: [18][4]f32 = undefined;
            var main_counts: [18]u8 = undefined;
            for (0..18) |i| {
                main_colors[i] = inventory.slots[6 + i].item.getColor();
                main_counts[i] = inventory.slots[6 + i].count;
            }

            var craft_colors: [4][4]f32 = undefined;
            var craft_counts: [4]u8 = undefined;
            for (0..4) |i| {
                craft_colors[i] = inventory.craft_grid[i].item.getColor();
                craft_counts[i] = inventory.craft_grid[i].count;
            }

            ui.drawInventory(
                aspect,
                &main_colors,
                &main_counts,
                &hotbar_colors,
                &hotbar_counts,
                &craft_colors,
                &craft_counts,
                inventory.craft_output.item.getColor(),
                inventory.craft_output.count,
                cursor_stack.item.getColor(),
                cursor_stack.count,
                mouse_norm_x,
                mouse_norm_y,
            );
        }

        // Update audio device buffer
        audio.update();

        frame_count += 1;
        hud_frames += 1;
        hud_time += dt;
        if (hud_time >= 0.5) {
            const fps: u64 = @intFromFloat(@as(f32, @floatFromInt(hud_frames)) / hud_time);
            hud_frames = 0;
            hud_time = 0;
            const px = @as(i32, @intFromFloat(@floor(player.pos.x)));
            const py = @as(i32, @intFromFloat(@floor(player.pos.y)));
            const pz = @as(i32, @intFromFloat(@floor(player.pos.z)));
            const dir = cam.front();
            const loaded = manager.loadedChunkCount();
            const mob_count = mob_manager.mobs.items.len;
            const current_item = inventory.slots[selected_slot].item;
            const time_state = sky_mod.timeState(sun_y);
            if (pick_mod.raycast(&pickSolid, cam.position, dir, 8)) |hit| {
                std.debug.print("fps={d} xyz=({d},{d},{d}) time={s} slot={s} chunk=({d},{d}) loaded={d} mobs={d} drawn={d} culled={d} aim=({d},{d},{d})\n", .{ fps, px, py, pz, time_state, current_item.name(), @divFloor(px, 16), @divFloor(pz, 16), loaded, mob_count, stats.drawn, stats.culled, hit.x, hit.y, hit.z });
            } else {
                std.debug.print("fps={d} xyz=({d},{d},{d}) time={s} slot={s} chunk=({d},{d}) loaded={d} mobs={d} drawn={d} culled={d} aim=none\n", .{ fps, px, py, pz, time_state, current_item.name(), @divFloor(px, 16), @divFloor(pz, 16), loaded, mob_count, stats.drawn, stats.culled });
            }
            var title_buf: [128]u8 = undefined;
            const title = std.fmt.bufPrintZ(&title_buf, "Zigcraft  fps={d}  time={s}  chunks={d}  mobs={d}  block={s}  hp={d:.0} hu={d:.0}", .{ fps, time_state, loaded, mob_count, current_item.name(), player.health, player.hunger }) catch "Zigcraft";
            c.glfwSetWindowTitle(window, title.ptr);
        }

        // Reset wear counters for slots not holding a damaged tool
        for (0..6) |ws| {
            tool_wear.clearIfNotTool(ws, inventory.slots[ws].item.isTool());
        }

        // Mouse click handling: In-game block editing or Inventory slot clicking
        const left = c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_LEFT) == c.GLFW_PRESS;
        const right = c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_RIGHT) == c.GLFW_PRESS;
        if ((left and !left_down) or (right and !right_down)) {
            if (inventory_open) {
                // Handle slot interaction in inventory GUI
                const slot_w: f32 = 0.055 / aspect;
                const slot_h: f32 = 0.055;
                const gap: f32 = 0.012 / aspect;

                // Check 2x2 Crafting Grid slots
                const craft_start_x = 0.02;
                const craft_start_y = 0.16;
                var handled = false;
                for (0..2) |r| {
                    for (0..2) |c_idx| {
                        const idx = r * 2 + c_idx;
                        const sx0 = craft_start_x + @as(f32, @floatFromInt(c_idx)) * (slot_w + gap);
                        const sx1 = sx0 + slot_w;
                        const sy1 = craft_start_y - @as(f32, @floatFromInt(r)) * (slot_h + gap * aspect);
                        const sy0 = sy1 - slot_h;
                        if (mouse_norm_x >= sx0 and mouse_norm_x <= sx1 and mouse_norm_y >= sy0 and mouse_norm_y <= sy1) {
                            // Swap or transfer item with cursor
                            const temp = inventory.craft_grid[idx];
                            inventory.craft_grid[idx] = cursor_stack;
                            cursor_stack = temp;
                            inventory.updateCrafting();
                            handled = true;
                            break;
                        }
                    }
                    if (handled) break;
                }

                // Check Crafting Output Slot
                if (!handled) {
                    const arrow_x = craft_start_x + 2.0 * (slot_w + gap) + 0.02 / aspect;
                    const arrow_y = craft_start_y - slot_h * 0.8;
                    const out_x0 = arrow_x + 0.045 / aspect;
                    const out_x1 = out_x0 + slot_w * 1.25;
                    const out_y0 = arrow_y - slot_h * 0.625;
                    const out_y1 = arrow_y + slot_h * 0.625;
                    if (mouse_norm_x >= out_x0 and mouse_norm_x <= out_x1 and mouse_norm_y >= out_y0 and mouse_norm_y <= out_y1) {
                        if (inventory.takeCraftResult(&cursor_stack)) {
                            audio.play(.craft_item, 0.8);
                        }
                        handled = true;
                    }
                }

                // Check Main Inventory (18 slots)
                if (!handled) {
                    const main_start_x = -0.32;
                    const main_start_y = 0.02;
                    for (0..3) |mr| {
                        for (0..6) |mc| {
                            const idx = 6 + mr * 6 + mc;
                            const sx0 = main_start_x + @as(f32, @floatFromInt(mc)) * (slot_w + gap);
                            const sx1 = sx0 + slot_w;
                            const sy1 = main_start_y - @as(f32, @floatFromInt(mr)) * (slot_h + gap * aspect);
                            const sy0 = sy1 - slot_h;
                            if (mouse_norm_x >= sx0 and mouse_norm_x <= sx1 and mouse_norm_y >= sy0 and mouse_norm_y <= sy1) {
                                const temp = inventory.slots[idx];
                                inventory.slots[idx] = cursor_stack;
                                cursor_stack = temp;
                                handled = true;
                                break;
                            }
                        }
                        if (handled) break;
                    }
                }

                // Check Bottom Hotbar (6 slots)
                if (!handled) {
                    const main_start_x = -0.32;
                    const hot_y = -0.32;
                    for (0..6) |hc| {
                        const sx0 = main_start_x + @as(f32, @floatFromInt(hc)) * (slot_w + gap);
                        const sx1 = sx0 + slot_w;
                        const sy0 = hot_y;
                        const sy1 = hot_y + slot_h;
                        if (mouse_norm_x >= sx0 and mouse_norm_x <= sx1 and mouse_norm_y >= sy0 and mouse_norm_y <= sy1) {
                            const temp = inventory.slots[hc];
                            inventory.slots[hc] = cursor_stack;
                            cursor_stack = temp;
                            break;
                        }
                    }
                }
            } else {
                // In-game: hold left to mine (timed by hardness/tool), right click place
                const dir = cam.front();
                mob_hit_cooldown = combat_mod.tickCooldown(mob_hit_cooldown, dt);
                const held_weapon = inventory.slots[selected_slot].item;
                const hit_dmg: u8 = combat_mod.meleeDamage(held_weapon == .iron_sword);
                const hit_mob_opt = if (left and mob_hit_cooldown <= 0.0) mob_manager.tryHitMobDmg(cam.position, dir, combat_mod.melee_range, hit_dmg) else null;
                if (hit_mob_opt) |hit_mob| {
                    mob_hit_cooldown = combat_mod.melee_cooldown;
                    if (held_weapon.isTool()) {
                        if (tool_wear.use(selected_slot, held_weapon.maxDurability())) {
                            inventory.slots[selected_slot].clear();
                        }
                    }
                    if (entity_mod.mob.getSound(hit_mob.mob_type)) |hit_sound| {
                        audio.playAt(hit_sound, .{ hit_mob.pos.x, hit_mob.pos.y, hit_mob.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                    }
                    const px: i32 = @intFromFloat(@floor(hit_mob.pos.x));
                    const py: i32 = @intFromFloat(@floor(hit_mob.pos.y));
                    const pz: i32 = @intFromFloat(@floor(hit_mob.pos.z));
                    particles.spawnBlockDebris(px, py, pz, .{ 0.85, 0.2, 0.2 }, 8);
                    if (hit_mob.died) {
                        const drop = inventory_mod.getMobMeatDrop(hit_mob.mob_type);
                        _ = inventory.addItem(drop, 1);
                        if (hit_mob.wool) _ = inventory.addItem(.wool, 1);
                        std.debug.print("killed {s}, dropped {s}\n", .{ @tagName(hit_mob.mob_type), drop.name() });
                    }
                    mine.reset();
                } else if (pick_mod.raycast(&pickSolid, cam.position, dir, 8)) |hit| {
                    if (left) {
                        const broken_block = manager.getBlockWorld(hit.x, hit.y, hit.z);
                        const held_item_now = inventory.slots[selected_slot].item;
                        const need = block_mod.mineTime(broken_block, @intFromEnum(held_item_now));
                        const key: i64 = mining_mod.targetKey(hit.x, hit.y, hit.z);
                        if (!mine.valid or mine.key != key) {
                            mine.retarget(key, need);
                        } else {
                            mine.advance(dt);
                        }
                        if (mine.done(need)) {
                            mine.reset();
                            if (try manager.editAndRemesh(hit.x, hit.y, hit.z, .air)) {
                                audio.play(.break_block, 0.7);
                                const drop_col = inventory_mod.ItemType.fromBlockId(broken_block).getColor();
                                particles.spawnBlockDebris(hit.x, hit.y, hit.z, .{ drop_col[0], drop_col[1], drop_col[2] }, 16);
                                const held = inventory.slots[selected_slot].item;
                                const tier_ok = inventory_mod.canHarvestBlock(held, broken_block);
                                if (tier_ok) {
                                    if (broken_block == .chest) {
                                        if (cache_mod.findChest(&chests, chest_count, hit.x, hit.y, hit.z)) |ci| {
                                            for (chests[ci].items) |citem| {
                                                if (!citem.isEmpty()) _ = inventory.addItem(citem.item, citem.count);
                                            }
                                            cache_mod.swapRemove(&chests, &chest_count, ci);
                                        }
                                    }
                                    var drops_buf: [2]inventory_mod.BlockDrop = undefined;
                                    const drop_count = inventory_mod.getBlockDrops(broken_block, &drops_buf);
                                    for (drops_buf[0..drop_count]) |d| {
                                        _ = inventory.addItem(d.item, d.count);
                                    }
                                    if (broken_block == .leaves) {
                                        const bonus = mining_mod.checkLeafBonuses(hit.x, hit.y, hit.z);
                                        if (bonus.apple) _ = inventory.addItem(.apple, 1);
                                        if (bonus.sapling) _ = inventory.addItem(.sapling, 1);
                                    }
                                } else {
                                    std.debug.print("too hard: {s} needs pickaxe\n", .{@tagName(broken_block)});
                                }
                                // Tools wear down one use per mined block
                                if (held.isTool()) {
                                    if (tool_wear.use(selected_slot, held.maxDurability())) {
                                        inventory.slots[selected_slot].clear();
                                        std.debug.print("pickaxe broke\n", .{});
                                    }
                                }
                                std.debug.print("destroyed {s} ({d},{d},{d})\n", .{ @tagName(broken_block), hit.x, hit.y, hit.z });
                            }
                        }
                    } else {
                        const px = hit.x + hit.nx;
                        const py = hit.y + hit.ny;
                        const pz = hit.z + hit.nz;
                        if (!pickSolid(px, py, pz)) {
                            var hotbar_slot = &inventory.slots[selected_slot];
                            if (hotbar_slot.item == .sapling) {
                                const soil = manager.getBlockWorld(hit.x, hit.y, hit.z);
                                if (sapling_mod.canPlant(soil, hit.ny, py)) {
                                    if (manager.getBlockWorld(px, py + 1, pz) == .air and manager.getBlockWorld(px, py + 2, pz) == .air) {
                                        var ok = try manager.editAndRemesh(px, py, pz, .wood);
                                        ok = (try manager.editAndRemesh(px, py + 1, pz, .wood)) and ok;
                                        ok = (try manager.editAndRemesh(px, py + 2, pz, .leaves)) and ok;
                                        if (ok) {
                                            audio.play(.place_block, 0.7);
                                            hotbar_slot.decrement(1);
                                            if (sprout_count < sprouts.len) {
                                                sprouts[sprout_count] = .{ .x = px, .y = py, .z = pz, .t = 0.0 };
                                                sprout_count += 1;
                                            }
                                            std.debug.print("planted sapling\n", .{});
                                        }
                                    }
                                }
                            } else if (!hotbar_slot.isEmpty() and hotbar_slot.item == .boat) {
                                // Deploy boat into water or board boat
                                const target_block = manager.getBlockWorld(hit.x, hit.y, hit.z);
                                if (target_block == .water or pickFluid(px, py, pz)) {
                                    hotbar_slot.decrement(1);
                                    player.in_boat = true;
                                    audio.play(.splash, 0.75);
                                    particles.spawnWaterSplash(.{ player.pos.x, player.pos.y, player.pos.z }, 10);
                                    std.debug.print("boarded wooden boat\n", .{});
                                }
                            } else if (!hotbar_slot.isEmpty()) {
                                if (hotbar_slot.item.toBlockId()) |place_type| {
                                    const is_furnace_place = place_type == .furnace;
                                    if (try manager.editAndRemesh(px, py, pz, place_type)) {
                                        if (place_type == .water) _ = manager.setWaterLevel(px, py, pz, 7);
                                        // Fluid reaction on placement: adjacent water and lava interact
                                        if (place_type == .water or place_type == .lava) {
                                            const neighbors = [_][3]i32{ .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 1, 0 }, .{ 0, -1, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 } };
                                            for (neighbors) |nb| {
                                                const nx = px + nb[0];
                                                const ny = py + nb[1];
                                                const nz = pz + nb[2];
                                                const adj_b = manager.getBlockWorld(nx, ny, nz);
                                                const react = fluid_mod.evaluateFluidReaction(place_type, adj_b, true);
                                                if (react == .obsidian) {
                                                    _ = try manager.editAndRemesh(px, py, pz, .obsidian);
                                                    audio.play(.break_block, 0.8);
                                                    particles.spawnFlame(px, py, pz, 4);
                                                    break;
                                                } else if (react == .cobblestone) {
                                                    _ = try manager.editAndRemesh(px, py, pz, .cobblestone);
                                                    audio.play(.break_block, 0.7);
                                                    particles.spawnBlockDebris(px, py, pz, .{ 0.5, 0.5, 0.5 }, 6);
                                                    break;
                                                }
                                            }
                                        }
                                        audio.play(.place_block, 0.7);
                                        const pcol = hotbar_slot.item.getColor();
                                        particles.spawnBlockDebris(px, py, pz, .{ pcol[0], pcol[1], pcol[2] }, 8);
                                        if (place_type == .torch and cache_mod.canCreateTorch(torch_count, torches.len)) {
                                            torches[torch_count] = .{ .x = px, .y = py, .z = pz };
                                            torch_count += 1;
                                        }
                                        if (place_type == .chest and cache_mod.canCreateChest(chest_count, chests.len)) {
                                            chests[chest_count] = .{ .x = px, .y = py, .z = pz, .items = [_]inventory_mod.ItemStack{.{}} ** 4 };
                                            chest_count += 1;
                                        }
                                        if (is_furnace_place and cache_mod.canCreateFurnace(furnace_count, furnaces.len)) {
                                            furnaces[furnace_count] = .{ .x = px, .y = py, .z = pz, .t = 0, .fuel = 0, .input = smelt_mod.None };
                                            furnace_count += 1;
                                        }
                                        hotbar_slot.decrement(1);
                                        std.debug.print("placed {s} ({d},{d},{d})\n", .{ @tagName(place_type), px, py, pz });
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if (!left) {
            mine.reset();
        }
        // Sleep on wool block at night: aim at wool + press B sets spawn, skips to dawn
        bed_cooldown = interact_mod.tickCooldown(bed_cooldown, dt);
        const sun_y_now = @sin(world_time);
        if (!inventory_open and interact_mod.ready(bed_cooldown) and c.glfwGetKey(window, c.GLFW_KEY_B) == c.GLFW_PRESS) {
            const dir_b = cam.front();
            if (pick_mod.raycast(&pickSolid, cam.position, dir_b, 5)) |hit_b| {
                if (manager.getBlockWorld(hit_b.x, hit_b.y, hit_b.z) == .wool) {
                    const sleep_res = sky_mod.trySleep(sun_y_now, world_time, player.health);
                    if (sleep_res.slept) {
                        world_time = sleep_res.new_world_time;
                        player.spawn_point = player.pos;
                        player.health = sleep_res.new_health;
                        audio.play(.craft_item, 0.7);
                        std.debug.print("slept; spawn set\n", .{});
                    } else {
                        std.debug.print("sleep only at night\n", .{});
                    }
                    bed_cooldown = interact_mod.bed_cooldown;
                }
            }
        }
        // Furnace tick: cook stored input using fuel, 10s per item
        {
            var fi: usize = 0;
            while (fi < furnace_count) {
                const f = &furnaces[fi];
                if (manager.getBlockWorld(f.x, f.y, f.z) != .furnace) {
                    cache_mod.swapRemove(&furnaces, &furnace_count, fi);
                    continue;
                }
                const outcome = smelt_mod.tickJob(&f.t, &f.fuel, &f.input, dt);
                if (outcome.done_item) |done_tag| {
                    const done: inventory_mod.ItemType = @enumFromInt(done_tag);
                    _ = inventory.addItem(done, 1);
                    audio.play(.craft_item, 0.7);
                    std.debug.print("smelted {s}\n", .{done.name()});
                }
                fi += 1;
            }
        }
        // Falling sand: unsupported sand drops one block per 0.15s
        {
            sand_scan +%= 1;
            if (sand_scan % 10 == 0) {
                var fiter = manager.chunks.iterator();
                while (fiter.next()) |entry| {
                    if (falling_count >= fallings.len) break;
                    const fcx = entry.key_ptr.x;
                    const fcz = entry.key_ptr.z;
                    const fch = &entry.value_ptr.chunk;
                    var fy: usize = 1;
                    while (fy < 16) : (fy += 1) {
                        var fz: usize = 0;
                        while (fz < 16) : (fz += 1) {
                            var fx: usize = 0;
                            while (fx < 16) : (fx += 1) {
                                if (fch.blocks[fy][fz][fx] != .sand) continue;
                                if (fch.blocks[fy - 1][fz][fx] != .air) continue;
                                const wx: i32 = fcx * 16 + @as(i32, @intCast(fx));
                                const wy: i32 = @as(i32, @intCast(fy));
                                const wz: i32 = fcz * 16 + @as(i32, @intCast(fz));
                                if (falling_mod.findFalling(&fallings, falling_count, wx, wy, wz) == null and falling_count < fallings.len) {
                                    fallings[falling_count] = .{ .x = wx, .y = wy, .z = wz, .t = 0.0, .dist = 0 };
                                    falling_count += 1;
                                }
                                if (falling_count >= fallings.len) break;
                            }
                            if (falling_count >= fallings.len) break;
                        }
                        if (falling_count >= fallings.len) break;
                    }
                }
            }
            var fi2: usize = 0;
            while (fi2 < falling_count) {
                const f = &fallings[fi2];
                if (manager.getBlockWorld(f.x, f.y, f.z) != .sand) {
                    cache_mod.swapRemove(&fallings, &falling_count, fi2);
                    continue;
                }
                f.t += dt;
                if (f.t >= falling_mod.fall_interval) {
                    f.t = 0.0;
                    const below = manager.getBlockWorld(f.x, f.y - 1, f.z);
                    const action = falling_mod.evaluateFallingStep(below, f.y);
                    switch (action) {
                        .drop_into_air => {
                            _ = try manager.editAndRemesh(f.x, f.y - 1, f.z, .sand);
                            _ = try manager.editAndRemesh(f.x, f.y, f.z, .air);
                            f.y -= 1;
                            f.dist += 1;
                        },
                        .splash_into_water => {
                            _ = try manager.editAndRemesh(f.x, f.y - 1, f.z, .sand);
                            _ = try manager.editAndRemesh(f.x, f.y, f.z, .air);
                            f.y -= 1;
                            f.dist += 1;
                            particles.spawnWaterSplash(.{ @as(f32, @floatFromInt(f.x)) + 0.5, @as(f32, @floatFromInt(f.y)), @as(f32, @floatFromInt(f.z)) + 0.5 }, 12);
                        },
                        .crush_non_solid => {
                            _ = try manager.editAndRemesh(f.x, f.y - 1, f.z, .sand);
                            _ = try manager.editAndRemesh(f.x, f.y, f.z, .air);
                            f.y -= 1;
                            f.dist += 1;
                            particles.spawnBlockDebris(f.x, f.y, f.z, .{ 0.8, 0.7, 0.5 }, 4);
                        },
                        .land, .none => {
                            const dmg = falling_mod.calculateImpactDamage(f.dist);
                            if (dmg > 0) {
                                for (mob_manager.mobs.items, 0..) |*m, mi| {
                                    if (falling_mod.isHitByBlock(m.pos.x, m.pos.y, m.pos.z, f.x, f.y, f.z)) {
                                        if (m.takeHitDmg(math.Vec3.init(0, 1, 0), dmg)) {
                                            _ = mob_manager.mobs.swapRemove(mi);
                                        }
                                        break;
                                    }
                                }
                                if (falling_mod.isHitByBlock(player.pos.x, player.pos.y, player.pos.z, f.x, f.y, f.z)) {
                                    player.health = @max(0.0, player.health - @as(f32, @floatFromInt(dmg)));
                                    audio.play(.hurt, 0.8);
                                }
                            }
                            cache_mod.swapRemove(&fallings, &falling_count, fi2);
                            continue;
                        },
                    }
                }
                fi2 += 1;
            }
        }
        // Water flow: spread laterally/downward from water edges near player (bounded).
        flow_timer += dt;
        if (flow_timer >= fluid_mod.flow_tick) {
            flow_timer = 0.0;
            _ = try fluid_mod.step(&manager, .{
                @intFromFloat(@floor(player.pos.x)),
                @intFromFloat(@floor(player.pos.y)),
                @intFromFloat(@floor(player.pos.z)),
            });
        }
                // Torch flame particles: nearby active torches emit flame tips
        torch_puff_timer += dt;
        if (torch_puff_timer >= 0.2) {
            torch_puff_timer = 0.0;
            var ti: usize = 0;
            while (ti < torch_count) {
                const tr = &torches[ti];
                const cur_tb = manager.getBlockWorld(tr.x, tr.y, tr.z);
                if (fluid_mod.isWashable(cur_tb, manager.getBlockWorld(tr.x, tr.y + 1, tr.z))) {
                    _ = try manager.editAndRemesh(tr.x, tr.y, tr.z, .air);
                    particles.spawnBlockDebris(tr.x, tr.y, tr.z, .{ 0.8, 0.6, 0.2 }, 4);
                    if (fluid_mod.inPickupRange(@floatFromInt(tr.x), @floatFromInt(tr.z), player.pos.x, player.pos.z)) _ = inventory.addItem(.torch, 1);
                    cache_mod.swapRemove(&torches, &torch_count, ti);
                    continue;
                }
                if (cur_tb != .torch) {
                    cache_mod.swapRemove(&torches, &torch_count, ti);
                    continue;
                }
                if (cache_mod.isWithinFlameDist(tr.x, tr.z, player.pos.x, player.pos.z)) {
                    particles.spawnFlame(tr.x, tr.y, tr.z, 1);
                }
                ti += 1;
            }
        }

        // Thrown snowball physics: gravity arc, mob hit = 1 dmg + knockback, block hit = puff
        {
            var ti: usize = 0;
            while (ti < thrown_count) {
                var t = &thrown[ti];
                const st = proj_mod.stepMotion(t.pos.x, t.pos.y, t.pos.z, t.vel.x, t.vel.y, t.vel.z, t.life, dt);
                t.pos = math.Vec3.init(st.pos[0], st.pos[1], st.pos[2]);
                t.vel = math.Vec3.init(st.vel[0], st.vel[1], st.vel[2]);
                t.life = st.life;
                const mbc = proj_mod.projectileBlockCoords(t.pos.x, t.pos.y, t.pos.z);
                const mbx = mbc[0];
                const mby = mbc[1];
                const mbz = mbc[2];
                var dead = proj_mod.isExpired(t.life);
                if (!dead) {
                    if (pickSolid(mbx, mby, mbz)) {
                        particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.93, 0.95, 1.0 }, 6);
                        dead = true;
                    } else {
                        // mob hit test (generous radius)
                        for (mob_manager.mobs.items, 0..) |*m, mi| {
                            const d = proj_mod.mobDelta(m.pos.x, m.pos.y, m.pos.z, t.pos.x, t.pos.y, t.pos.z);
                            if (proj_mod.hitsMob(d[0], d[1], d[2])) {
                                const died = m.takeHit(cam.front());
                                audio.play(.hurt, 0.5);
                                particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.93, 0.95, 1.0 }, 8);
                                if (died) {
                                    const md = inventory_mod.getMobMeatDrop(m.mob_type);
                                    const mp = m.pos;
                                    _ = mob_manager.mobs.swapRemove(mi);
                                    _ = inventory.addItem(md, 1);
                                    if (m.mob_type == .sheep) _ = inventory.addItem(.wool, 1);
                                    _ = mp;
                                }
                                dead = true;
                                break;
                            }
                        }
                    }
                }
                if (dead) {
                    cache_mod.swapRemove(&thrown, &thrown_count, ti);
                } else {
                    // trail puff
                    particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.9, 0.92, 1.0 }, 1);
                    ti += 1;
                }
            }
        }
        // G throws snowball
        throw_cooldown = @max(0.0, throw_cooldown - dt);
        if (!inventory_open and throw_cooldown <= 0.0 and c.glfwGetKey(window, c.GLFW_KEY_G) == c.GLFW_PRESS) {
            if (inventory.slots[selected_slot].item == .snowball and thrown_count < thrown.len) {
                const dir_g = cam.front();
                const vel_g = proj_mod.initialVelocity(dir_g.x, dir_g.y, dir_g.z);
                thrown[thrown_count] = .{ .pos = cam.position, .vel = math.Vec3.init(vel_g[0], vel_g[1], vel_g[2]), .life = proj_mod.throw_life };
                thrown_count += 1;
                inventory.slots[selected_slot].decrement(1);
                audio.play(.place_block, 0.4);
                throw_cooldown = proj_mod.throw_cooldown;
            }
        }
        // TNT tick: white/smoke pulses during fuse; explode on 0
        {
            var fsi: usize = 0;
            while (fsi < fuse_count) {
                var fu = &fuses[fsi];
                fu.t -= dt;
                // fuse particles
                particles.spawnFlame(fu.x, fu.y + 1, fu.z, 2);
                if (boom_mod.isDetonated(fu.t)) {
                    const ex = fu.x;
                    const ey = fu.y;
                    const ez = fu.z;
                    // remove TNT block itself
                    _ = try manager.editAndRemesh(ex, ey, ez, .air);
                    // explode 3-block sphere
                    var rx: i32 = -boom_mod.blast_radius;
                    while (rx <= boom_mod.blast_radius) : (rx += 1) {
                        var ry: i32 = -boom_mod.blast_radius;
                        while (ry <= boom_mod.blast_radius) : (ry += 1) {
                            var rz: i32 = -boom_mod.blast_radius;
                            while (rz <= boom_mod.blast_radius) : (rz += 1) {
                                if (boom_mod.inBlast(rx, ry, rz)) {
                                    const bx = ex + rx;
                                    const by = ey + ry;
                                    const bz = ez + rz;
                                    const old_b = manager.getBlockWorld(bx, by, bz);
                                    switch (boom_mod.evaluateBlastBlock(old_b, by)) {
                                        .chain_tnt => {
                                            if (boom_mod.canChainFuse(fuses[0..fuse_count], bx, by, bz, fuses.len)) {
                                                fuses[fuse_count] = .{ .x = bx, .y = by, .z = bz, .t = boom_mod.chain_fuse_time };
                                                fuse_count += 1;
                                                std.debug.print("chain-detonated TNT ({d},{d},{d})\n", .{ bx, by, bz });
                                            }
                                        },
                                        .destroy_chest => {
                                            if (cache_mod.findChest(&chests, chest_count, bx, by, bz)) |ci| {
                                                for (chests[ci].items) |citem| {
                                                    if (!citem.isEmpty()) _ = inventory.addItem(citem.item, citem.count);
                                                }
                                                cache_mod.swapRemove(&chests, &chest_count, ci);
                                            }
                                            _ = try manager.editAndRemesh(bx, by, bz, .air);
                                        },
                                        .destroy_block => {
                                            _ = try manager.editAndRemesh(bx, by, bz, .air);
                                        },
                                        .ignore => {},
                                    }
                                }
                            }
                        }
                    }
                    audio.playAt(.break_block, .{ @as(f32, @floatFromInt(ex)) + 0.5, @as(f32, @floatFromInt(ey)) + 0.5, @as(f32, @floatFromInt(ez)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 40.0);
                    particles.spawnBlockDebris(ex, ey, ez, .{ 1.0, 0.3, 0.1 }, 64);
                    // mob blast damage
                    for (mob_manager.mobs.items, 0..) |*m, mi| {
                        if (boom_mod.calculateMobBlastHit(m.pos.x, m.pos.y, m.pos.z, ex, ey, ez)) |h| {
                            const died = m.takeHitDmg(math.Vec3.init(h.knockback[0], h.knockback[1], h.knockback[2]), h.damage);
                            if (died) {
                                _ = mob_manager.mobs.swapRemove(mi);
                            }
                        }
                    }
                    // player blast damage + launch
                    if (boom_mod.calculatePlayerBlastImpulse(player.pos.x, player.pos.y, player.pos.z, ex, ey, ez)) |imp| {
                        player.health = @max(0.0, player.health - imp.damage);
                        player.vel_y = imp.vel_y;
                        player.pos.x += imp.push_x;
                        player.pos.z += imp.push_z;
                        audio.play(.hurt, 1.0);
                    }
                    cache_mod.swapRemove(&fuses, &fuse_count, fsi);
                } else {
                    fsi += 1;
                }
            }
        }
        // F: flint spark — ignite aimed flammable block (edge triggered, 0.5s cooldown)
        flint_cooldown = interact_mod.tickCooldown(flint_cooldown, dt);
        if (!inventory_open and interact_mod.ready(flint_cooldown) and c.glfwGetKey(window, c.GLFW_KEY_F) == c.GLFW_PRESS) {
            const dir_f = cam.front();
            if (pick_mod.raycast(&pickSolid, cam.position, dir_f, 5)) |hit_f| {
                const target = manager.getBlockWorld(hit_f.x, hit_f.y, hit_f.z);
                if (target == .repeater_off or target == .repeater_on) {
                    var found_stage = false;
                    if (cache_mod.findRepeater(&repeaters, repeater_count, hit_f.x, hit_f.y, hit_f.z)) |rep_idx| {
                        const rep = &repeaters[rep_idx];
                        rep.stage +%= 1;
                        rep.timer = 0.0;
                        found_stage = true;
                        audio.play(.click_on, 0.6);
                        std.debug.print("repeater delay stage {d} ({d},{d},{d})\n", .{ @as(u8, rep.stage) + 1, hit_f.x, hit_f.y, hit_f.z });
                        {
                            var snap: [64][4]i32 = undefined;
                            var sn: usize = 0;
                            for (repeaters[0..repeater_count]) |sr| {
                                if (sn >= snap.len) break;
                                snap[sn] = .{ sr.x, sr.y, sr.z, sr.stage };
                                sn += 1;
                            }
                            chunk_manager_mod.ChunkManager.setStageSnapshot(snap[0..sn]);
                            if (manager.chunks.getPtr(.{ .x = @divFloor(hit_f.x, 16), .z = @divFloor(hit_f.z, 16) })) |e| {
                                e.modified = true;
                                if (!manager.saveStages(@divFloor(hit_f.x, 16), @divFloor(hit_f.z, 16), &e.chunk)) {
                                    std.debug.print("failed to save repeater stage; chunk retained for retry\n", .{});
                                }
                            }
                        }
                    }
                    if (!found_stage and repeater_count < repeaters.len) {
                        repeaters[repeater_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .powered = (target == .repeater_on), .timer = 0.0, .stage = 1 };
                        repeater_count += 1;
                        audio.play(.click_on, 0.6);
                        std.debug.print("repeater delay stage 2 ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (interact_mod.toggleLever(target)) |toggled| {
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, toggled)) {
                        if (toggled == .lever_on) {
                            audio.play(.click_on, 0.9);
                            particles.spawnFlame(hit_f.x, hit_f.y, hit_f.z, 2);
                        } else {
                            audio.play(.click_off, 0.7);
                            particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.5, 0.5, 0.5 }, 3);
                        }
                        const adj_offsets = [_][3]i32{
                            .{ 1, 0, 0 }, .{ -1, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, -1 },
                            .{ 1, 1, 0 }, .{ -1, 1, 0 }, .{ 0, 1, 1 }, .{ 0, 1, -1 },
                            .{ 0, 1, 0 }, .{ 0, -1, 0 },
                        };
                        for (adj_offsets) |off| {
                            const dx = hit_f.x + off[0];
                            const dy = hit_f.y + off[1];
                            const dz = hit_f.z + off[2];
                            const db = manager.getBlockWorld(dx, dy, dz);
                            if (interact_mod.toggleDoor(db, toggled == .lever_on)) |new_db| {
                                _ = try manager.editAndRemesh(dx, dy, dz, new_db);
                            }
                        }
                        std.debug.print("toggled lever to {s} ({d},{d},{d})\n", .{ @tagName(toggled), hit_f.x, hit_f.y, hit_f.z });
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .iron_door_closed or target == .iron_door_open) {
                    audio.play(.step_stone, 0.7);
                    std.debug.print("iron door locked; requires redstone signal\n", .{});
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (interact_mod.toggleWoodenDoor(target)) |toggled| {
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, toggled)) {
                        audio.play(.place_block, 0.9);
                        std.debug.print("toggled door to {s} ({d},{d},{d})\n", .{ @tagName(toggled), hit_f.x, hit_f.y, hit_f.z });
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .tnt and fuse_count < fuses.len) {
                    fuses[fuse_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .t = 2.5 };
                    fuse_count += 1;
                    audio.play(.place_block, 0.8);
                    std.debug.print("lit TNT fuse\n", .{});
                    flint_cooldown = interact_mod.flint_edge_cooldown;
                } else if (target == .chest) {
                    var k_opt = cache_mod.findChest(&chests, chest_count, hit_f.x, hit_f.y, hit_f.z);
                    if (k_opt == null and cache_mod.canCreateChest(chest_count, chests.len)) {
                        chests[chest_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .items = [_]inventory_mod.ItemStack{.{}} ** 4 };
                        k_opt = chest_count;
                        chest_count += 1;
                    }
                    if (k_opt) |k| {
                        const held_item = inventory.slots[selected_slot].item;
                        if (held_item != .none) {
                            if (cache_mod.findDepositSlot(&chests[k].items, held_item)) |slot_idx| {
                                var cslot = &chests[k].items[slot_idx];
                                if (cslot.isEmpty()) {
                                    cslot.* = .{ .item = held_item, .count = 1 };
                                } else {
                                    cslot.count += 1;
                                }
                                inventory.slots[selected_slot].decrement(1);
                                audio.play(.place_block, 0.7);
                                std.debug.print("deposited {s} into chest\n", .{held_item.name()});
                            }
                        } else {
                            for (&chests[k].items) |*cslot| {
                                if (!cslot.isEmpty()) {
                                    const take_cnt = cslot.count;
                                    const itm = cslot.item;
                                    const rem = inventory.addItem(itm, take_cnt);
                                    if (rem < take_cnt) {
                                        cslot.count = rem;
                                        if (rem == 0) cslot.clear();
                                        audio.play(.break_block, 0.7);
                                        std.debug.print("withdrew {d} {s} from chest\n", .{take_cnt, itm.name()});
                                    }
                                    break;
                                }
                            }
                        }
                    }
                    flint_cooldown = interact_mod.flint_feed_cooldown;
                } else if (target == .furnace) {
                    // feed held item as input or fuel
                    const held_f = inventory.slots[selected_slot];
                    const smeltable = switch (held_f.item) {
                        .raw_pork, .raw_mutton, .sand, .iron_ore => true,
                        else => false,
                    };
                    var fed = false;
                    var k_opt = cache_mod.findFurnace(&furnaces, furnace_count, hit_f.x, hit_f.y, hit_f.z);
                    if (k_opt == null and cache_mod.canCreateFurnace(furnace_count, furnaces.len)) {
                        furnaces[furnace_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .t = 0, .fuel = 0, .input = smelt_mod.None };
                        k_opt = furnace_count;
                        furnace_count += 1;
                    }
                    if (k_opt) |k| {
                        switch (smelt_mod.evaluateFurnaceFeed(held_f.item == .coal, smeltable, furnaces[k].fuel, furnaces[k].input)) {
                            .add_fuel => {
                                furnaces[k].fuel += 1;
                                inventory.slots[selected_slot].decrement(1);
                                fed = true;
                            },
                            .set_input => {
                                furnaces[k].input = @intFromEnum(held_f.item);
                                inventory.slots[selected_slot].decrement(1);
                                fed = true;
                            },
                            .none => {},
                        }
                    }
                    if (fed) audio.play(.place_block, 0.6);
                    flint_cooldown = interact_mod.flint_edge_cooldown;
                } else
                if (target == .obsidian) {
                    // Check if adjacent open face is inside a valid 2x3 nether portal frame
                    const adj_inside = [_][3]i32{
                        .{ hit_f.x, hit_f.y + 1, hit_f.z },
                        .{ hit_f.x + 1, hit_f.y, hit_f.z },
                        .{ hit_f.x - 1, hit_f.y, hit_f.z },
                        .{ hit_f.x, hit_f.y, hit_f.z + 1 },
                        .{ hit_f.x, hit_f.y, hit_f.z - 1 },
                    };
                    var activated = false;
                    for (adj_inside) |cpos| {
                        if (portal_mod.detectPortalFrame(&pickBlockWorld, cpos[0], cpos[1], cpos[2])) |frame| {
                            var h: i32 = 0;
                            while (h < frame.height) : (h += 1) {
                                var w: i32 = 0;
                                while (w < frame.width) : (w += 1) {
                                    const cx = if (frame.axis == .x_axis) frame.interior_min_x + w else frame.interior_min_x;
                                    const cy = frame.interior_min_y + h;
                                    const cz = if (frame.axis == .z_axis) frame.interior_min_z + w else frame.interior_min_z;
                                    _ = try manager.editAndRemesh(cx, cy, cz, .nether_portal);
                                    particles.spawnPortalParticles(.{ @as(f32, @floatFromInt(cx)) + 0.5, @as(f32, @floatFromInt(cy)) + 0.5, @as(f32, @floatFromInt(cz)) + 0.5 }, 5);
                                }
                            }
                            audio.play(.portal_hum, 0.9);
                            std.debug.print("activated nether portal frame ({d}x{d}) at ({d},{d},{d})\n", .{ frame.width, frame.height, frame.interior_min_x, frame.interior_min_y, frame.interior_min_z });
                            activated = true;
                            break;
                        }
                    }
                    if (!activated) {
                        particles.spawnFlame(hit_f.x, hit_f.y, hit_f.z, 4);
                        audio.play(.click_on, 0.5);
                    }
                    flint_cooldown = interact_mod.flint_edge_cooldown;
                } else
                if (target.isFlammable()) {
                    particles.spawnFlame(hit_f.x, hit_f.y, hit_f.z, 14);
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, .air)) {
                        audio.play(.break_block, 0.6);
                        const drop_item = inventory_mod.ItemType.fromBlockId(target);
                        _ = inventory.addItem(drop_item, 1);
                        std.debug.print("burned {s}\n", .{@tagName(target)});
                    }
                    flint_cooldown = interact_mod.flint_edge_cooldown;
                }
            }
        }
        // Right-click eats held meat (edge triggered, in-game only)
        if (right and !right_down and !inventory_open) {
            const held_eat = inventory.slots[selected_slot];
            const cooked = switch (held_eat.item) {
                .cooked_pork, .cooked_mutton => true,
                .raw_pork, .raw_mutton => false,
                else => null,
            };
            if (held_eat.item == .fire_resistance_potion) {
                player.drinkFireResistance();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnBurnSparks(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 8);
                std.debug.print("drank fire resistance potion (timer={d:.1}s)\n", .{player.fire_resistance_timer});
            } else if (held_eat.item == .golden_apple) {
                player.eatGolden();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                std.debug.print("ate golden apple (hp={d:.1})\n", .{player.health});
            } else if (held_eat.item == .apple and player.hunger < 20.0) {
                player.eatApple();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.7);
                std.debug.print("ate apple (hunger={d:.1})\n", .{player.hunger});
            } else
            if (cooked) |is_cooked| {
                if (player.hunger < 20.0) {
                    player.eat(is_cooked);
                    inventory.slots[selected_slot].decrement(1);
                    audio.play(.eat, 0.7);
                    std.debug.print("ate {s} (hunger={d:.1})\n", .{ held_eat.item.name(), player.hunger });
                }
            }
        }
        left_down = left;
        right_down = right;

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();

        if (c.glfwGetKey(window, c.GLFW_KEY_ESCAPE) == c.GLFW_PRESS) {
            c.glfwSetWindowShouldClose(window, c.GLFW_TRUE);
        }
    }

    std.debug.print("shutting down\n", .{});
}
