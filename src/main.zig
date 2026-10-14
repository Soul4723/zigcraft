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
const spawn_mod = @import("world/spawn_rules.zig");
const cache_mod = @import("world/component_cache.zig");
const fluid_mod = @import("world/fluid_wash.zig");
const falling_mod = @import("world/falling_blocks.zig");
const hazard_mod = @import("world/hazard.zig");
const portal_mod = @import("world/portal.zig");
const summon_mod = @import("world/summon.zig");
const compass_mod = @import("world/compass.zig");
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
const WartCrop = struct { x: i32, y: i32, z: i32, t: f32 };

fn isWartTracked(warts: []const WartCrop, x: i32, y: i32, z: i32) bool {
    for (warts) |w| {
        if (w.x == x and w.y == y and w.z == z) return true;
    }
    return false;
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

fn pickHay(x: i32, y: i32, z: i32) bool {
    const mgr = pick_manager orelse return false;
    return mgr.getBlockWorld(x, y, z).is_hay_bale();
}

fn pickSlime(x: i32, y: i32, z: i32) bool {
    const mgr = pick_manager orelse return false;
    return mgr.getBlockWorld(x, y, z).is_slime_block();
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
    var space_down = false;
    var mob_hit_cooldown: f32 = 0.0;
    var bed_cooldown: f32 = 0.0;
    var flint_cooldown: f32 = 0.0;
    var throw_cooldown: f32 = 0.0;
    var bow_charge: f32 = 0.0;
    var crossbow_charge: f32 = 0.0;
    var crossbow_loaded: bool = false;
    var crossbow_loaded_kind: ?inventory_mod.ItemType = null;
    var wolf_bite_cooldown: f32 = 0.0;
    var fireball_cooldown: f32 = 0.0;
    var skeleton_shot_cooldown: f32 = 0.0;
    var shulker_shot_cooldown: f32 = 0.0;
    var compass_cooldown: f32 = 0.0;
    const Fuse = boom_mod.Fuse;
    var fuses: [boom_mod.fuse_cap]Fuse = undefined;
    var fuse_count: usize = 0;
    const Torch = cache_mod.Torch;
    var torches: [cache_mod.torch_cap]Torch = undefined;
    var torch_count: usize = 0;
    var torch_puff_timer: f32 = 0.0;
    const Spawner = struct { x: i32, y: i32, z: i32 };
    var spawners: [16]Spawner = undefined;
    var spawner_count: usize = 0;
    const VaporCloud = hazard_mod.VaporCloud;
    var vapor_clouds: [16]VaporCloud = undefined;
    var vapor_cloud_count: usize = 0;
    const Beacon = struct { x: i32, y: i32, z: i32 };
    var beacons: [16]Beacon = undefined;
    var beacon_count: usize = 0;
    const Campfire = struct { x: i32, y: i32, z: i32, is_soul: bool };
    var campfires: [32]Campfire = undefined;
    var campfire_count: usize = 0;
    const EndRod = struct { x: i32, y: i32, z: i32 };
    var end_rods: [32]EndRod = undefined;
    var end_rod_count: usize = 0;
    const Conduit = struct { x: i32, y: i32, z: i32 };
    var conduits: [16]Conduit = undefined;
    var conduit_count: usize = 0;
    const AnchorState = struct { x: i32, y: i32, z: i32, charges: u8 };
    var anchors: [16]AnchorState = undefined;
    var anchor_count: usize = 0;
    const PortalTarget = portal_mod.PortalTarget;
    var portal_targets: [32]PortalTarget = undefined;
    var portal_target_count: usize = 0;
    const ThrownKind = enum { snowball, hostile_fireball, hostile_arrow, player_fire_charge, spectral_arrow, arrow, firework_rocket, ender_pearl, eye_of_ender, shulker_bullet, trident };
    const Thrown = struct { pos: math.Vec3, vel: math.Vec3, life: f32, kind: ThrownKind = .snowball, damage: u8 = 1, pierce: u8 = 0, last_hit_mob: ?usize = null };
    var thrown: [proj_mod.thrown_cap]Thrown = undefined;
    var thrown_count: usize = 0;
    const FurnaceJob = smelt_mod.FurnaceJob;
    var furnaces: [smelt_mod.furnace_cap]FurnaceJob = undefined;
    var furnace_count: usize = 0;
    var smokers: [smelt_mod.furnace_cap]FurnaceJob = undefined;
    var smoker_count: usize = 0;
    var blast_furnaces: [smelt_mod.furnace_cap]FurnaceJob = undefined;
    var blast_furnace_count: usize = 0;
    const Chest = struct { x: i32, y: i32, z: i32, items: [4]inventory_mod.ItemStack };
    var chests: [cache_mod.chest_cap]Chest = undefined;
    var chest_count: usize = 0;
    var sprouts: [sapling_mod.sprout_cap]sapling_mod.Sprout = undefined;
    var sprout_count: usize = 0;
    var warts: [sapling_mod.sprout_cap]WartCrop = undefined;
    var wart_count: usize = 0;
    const IgnitedFlame = struct { x: i32, y: i32, z: i32, t: f32 };
    var flames: [32]IgnitedFlame = undefined;
    var flame_count: usize = 0;
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
    const HopperState = struct { x: i32, y: i32, z: i32, cooldown: f32 = 0.0, items: [4]inventory_mod.ItemStack = undefined };
    var hoppers: [32]HopperState = undefined;
    var hopper_count: usize = 0;
    const BrewingStandState = struct { x: i32, y: i32, z: i32, progress: f32 = 0.0, fuel: u8 = 0, wart: u8 = 0, spider_eyes: u8 = 0, fermented_eyes: u8 = 0, bottles: u8 = 0, potions: u8 = 0, poison_potions: u8 = 0, weakness_potions: u8 = 0 };
    var brewing_stands: [32]BrewingStandState = undefined;
    var brewing_stand_count: usize = 0;
    const CauldronFluid = enum { empty, water, lava };
    const CauldronState = struct { x: i32, y: i32, z: i32, fluid: CauldronFluid = .empty, level: u8 = 0 };
    var cauldrons: [32]CauldronState = undefined;
    var cauldron_count: usize = 0;
    const NoteBlockState = struct { x: i32, y: i32, z: i32, pitch: u5 = 0, powered: bool = false };
    var note_blocks: [32]NoteBlockState = undefined;
    var note_block_count: usize = 0;
    const JukeboxState = struct { x: i32, y: i32, z: i32, playing_disc: ?inventory_mod.ItemType = null, play_timer: f32 = 0.0 };
    var jukeboxes: [cache_mod.jukebox_cap]JukeboxState = undefined;
    var jukebox_count: usize = 0;
    const ArmorStandPose = enum(u8) { default_standing, salute, pointing, guarding };
    const ArmorStandState = struct {
        x: i32,
        y: i32,
        z: i32,
        pose: ArmorStandPose = .default_standing,
        head: ?inventory_mod.ItemType = null,
        chest: ?inventory_mod.ItemType = null,
        legs: ?inventory_mod.ItemType = null,
        feet: ?inventory_mod.ItemType = null,
    };
    var armor_stands: [cache_mod.armor_stand_cap]ArmorStandState = undefined;
    var armor_stand_count: usize = 0;
    const EnchantmentTableState = struct { x: i32, y: i32, z: i32 };
    var enchantment_tables: [cache_mod.enchantment_table_cap]EnchantmentTableState = undefined;
    var enchantment_table_count: usize = 0;
    const AnvilState = struct { x: i32, y: i32, z: i32, uses_left: u8 = 25 };
    var anvils: [cache_mod.anvil_cap]AnvilState = undefined;
    var anvil_count: usize = 0;
    const GrindstoneState = struct { x: i32, y: i32, z: i32 };
    var grindstones: [cache_mod.grindstone_cap]GrindstoneState = undefined;
    var grindstone_count: usize = 0;
    const SmithingTableState = struct { x: i32, y: i32, z: i32 };
    var smithing_tables: [cache_mod.smithing_table_cap]SmithingTableState = undefined;
    var smithing_table_count: usize = 0;
    const CartographyTableState = struct { x: i32, y: i32, z: i32 };
    var cartography_tables: [cache_mod.cartography_table_cap]CartographyTableState = undefined;
    var cartography_table_count: usize = 0;
    const FletchingTableState = struct { x: i32, y: i32, z: i32 };
    var fletching_tables: [cache_mod.fletching_table_cap]FletchingTableState = undefined;
    var fletching_table_count: usize = 0;
    const ComposterState = struct { x: i32, y: i32, z: i32, level: u8 = 0 };
    var composters: [cache_mod.composter_cap]ComposterState = undefined;
    var composter_count: usize = 0;
    const LoomState = struct { x: i32, y: i32, z: i32 };
    var looms: [cache_mod.loom_cap]LoomState = undefined;
    var loom_count: usize = 0;
    const StonecutterState = struct { x: i32, y: i32, z: i32 };
    var stonecutters: [cache_mod.stonecutter_cap]StonecutterState = undefined;
    var stonecutter_count: usize = 0;
    const DropperState = struct { x: i32, y: i32, z: i32, powered: bool = false, items: [4]inventory_mod.ItemStack = undefined, count: usize = 0 };
    var droppers: [32]DropperState = undefined;
    var dropper_count: usize = 0;
    const DispenserState = struct { x: i32, y: i32, z: i32, powered: bool = false, ammo_count: u8 = 9 };
    var dispensers: [32]DispenserState = undefined;
    var dispenser_count: usize = 0;
    const TargetPulse = struct { x: i32, y: i32, z: i32, t: f32, strength: u4 };
    var target_pulses: [16]TargetPulse = undefined;
    var target_pulse_count: usize = 0;
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
    var nether_ambient_timer: f32 = 0.0;
    var portal_transit = portal_mod.PortalTransitState{};
    var end_portal_transit = portal_mod.EndPortalTransitState{};
    var portal_flash_timer: f32 = 0.0;
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
        const is_blocking = !inventory_open and (c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_RIGHT) == c.GLFW_PRESS) and inventory.slots[selected_slot].item == .shield;
        const walk_vecs = player_mod.computeWalkVectors(cam.front());
        const is_loading_crossbow = !inventory_open and (c.glfwGetMouseButton(window, c.GLFW_MOUSE_BUTTON_RIGHT) == c.GLFW_PRESS) and inventory.slots[selected_slot].item == .crossbow and !crossbow_loaded;
        const walk_speed: f32 = if (is_blocking or is_loading_crossbow) 6.0 * combat_mod.shield_blocking_speed_mult else 6.0;
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
        } else if (player.in_minecart and key_shift) {
            // Dismount minecart: recover vehicle into inventory
            player.in_minecart = false;
            _ = inventory.addItem(.minecart, 1);
            audio.play(.click_off, 0.6);
            std.debug.print("dismounted minecart\n", .{});
        }
        const space_pressed = !inventory_open and (c.glfwGetKey(window, c.GLFW_KEY_SPACE) == c.GLFW_PRESS);
        const jump = space_pressed;
        if (space_pressed and !space_down and !player.on_ground and !player.in_water and inventory.hasItem(.elytra)) {
            if (!player.is_gliding) {
                player.startGliding();
                audio.play(.nether_wind, 0.9);
                std.debug.print("elytra glide deployed\n", .{});
            }
        }
        space_down = space_pressed;

        // Detect floor and rail block contact for player kinematics
        const f_px: i32 = @intFromFloat(@floor(player.pos.x));
        const f_py: i32 = @intFromFloat(@floor(player.pos.y - 0.1));
        const f_pz: i32 = @intFromFloat(@floor(player.pos.z));
        const floor_blk = manager.getBlockWorld(f_px, f_py, f_pz);
        const at_feet_blk = manager.getBlockWorld(f_px, @intFromFloat(@floor(player.pos.y)), f_pz);
        player.on_soulsand = (floor_blk == .soul_sand);
        player.on_rail = (floor_blk.is_rail() or at_feet_blk.is_rail());
        player.on_powered_rail = (floor_blk == .powered_rail or at_feet_blk == .powered_rail);
        player.on_detector_rail = (floor_blk == .detector_rail or at_feet_blk == .detector_rail);
        player.on_activator_rail = (floor_blk == .activator_rail or at_feet_blk == .activator_rail);

        // Activator Rail auto-ejection: when minecart passes over activator rail, eject passenger
        if (player.in_minecart and player.on_activator_rail) {
            player.in_minecart = false;
            _ = inventory.addItem(.minecart, 1);
            player.vel_y = 5.0; // ejection hop
            audio.play(.click_off, 0.8);
            particles.spawnBlockDebris(f_px, f_py, f_pz, .{ 0.85, 0.40, 0.30 }, 6);
            std.debug.print("activator rail ejected passenger from minecart\n", .{});
        }
        const body_blk = manager.getBlockWorld(f_px, @intFromFloat(@floor(player.pos.y + 0.5)), f_pz);
        player.in_cobweb = (floor_blk == .cobweb or body_blk == .cobweb);
        player.has_soul_speed = inventory.hasItem(.soul_speed_boots);

        // Detect bubble column: water cell with soul sand (upward) or magma (downward whirlpool) underneath
        const p_col_type = hazard_mod.detectBubbleColumn(&pickBlockWorld, f_px, @intFromFloat(@floor(player.pos.y)), f_pz);
        player.in_bubble_column = (p_col_type == .upward);
        player.in_whirlpool = (p_col_type == .downward);
        if (player.in_bubble_column) {
            particles.spawnBubble(.{ player.pos.x, player.pos.y + 0.3, player.pos.z }, 3);
        } else if (player.in_whirlpool) {
            particles.spawnBubble(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 4);
        }

        player.tickPhysicsCustom(&pickSolid, &pickLadder, &pickFluid, &pickHay, &pickSlime, norm_wish.x * walk_speed * dt, norm_wish.z * walk_speed * dt, jump, dt);
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

            const has_water_breathing = player.hasWaterBreathing() or inventory.hasItem(.turtle_helmet);
            player.oxygen = hazard_mod.tickOxygenRespiration(player.oxygen, is_underwater, inventory.hasItem(.netherite_helmet), has_water_breathing, dt);
            const drown_dmg = hazard_mod.calculateDrowningDamage(player.oxygen, dt);
            if (drown_dmg > 0.0) {
                player.health = @max(0.0, player.health - drown_dmg);
                // Drowning gasp emits bubble burst
                particles.spawnBubble(.{ eye.x, eye.y, eye.z }, 4);
            } else if (player.in_minecart and player.on_rail and (norm_wish.x != 0 or norm_wish.z != 0)) {
                // Minecart rail friction sparks and metallic clatter
                if (@as(u32, @intFromFloat(current_time * 16.0)) % 4 == 0) {
                    particles.spawnBlockDebris(f_px, f_py, f_pz, if (player.on_powered_rail) .{ 1.0, 0.8, 0.2 } else .{ 0.8, 0.8, 0.8 }, 2);
                }
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

            // Dolphin proximity aura: swimming within 8m of a live dolphin grants Dolphin's Grace buff
            if (player.in_water) {
                for (mob_manager.mobs.items) |m| {
                    if (m.mob_type == .dolphin and m.health > 0) {
                        const mdx = m.pos.x - player.pos.x;
                        const mdy = m.pos.y - player.pos.y;
                        const mdz = m.pos.z - player.pos.z;
                        if (mdx * mdx + mdy * mdy + mdz * mdz <= 64.0) {
                            if (!player.hasDolphinsGrace()) {
                                player.applyDolphinsGrace();
                                audio.play(.mob_baa, 0.7);
                                particles.spawnBubble(.{ player.pos.x, player.pos.y + 0.5, player.pos.z }, 8);
                                toast.timer = 2.5;
                                toast.color = .{ 0.35, 0.85, 0.95 };
                                std.debug.print("Dolphin's Grace buff acquired! Swim speed boosted.\n", .{});
                            }
                            break;
                        }
                    }
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
                if (!player.isFireImmune() and !inventory.hasFullNetheriteSet()) {
                    player.health = hazard_mod.applyDamageClamped(player.health, hazard_mod.lava_burn_rate, dt);
                    if (burn_sizzle_cooldown <= 0.0) {
                        audio.play(.burn_sizzle, 0.7);
                        burn_sizzle_cooldown = 0.5;
                    }
                }
            } else if (is_in_burn) {
                particles.spawnBurnSparks(.{ player.pos.x, player.pos.y, player.pos.z }, 2);
                if (!player.isFireImmune() and !inventory.hasFullNetheriteSet()) {
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

            // Check if player enters an End Gateway block (instantaneous regional gateway warp)
            const in_end_gateway = (feet_b == .end_gateway or head_b == .end_gateway);
            if (in_end_gateway) {
                if (player.pos.x < 50.0) {
                    // Warp from central island to outer island gateway landing near End City
                    player.pos = math.Vec3.init(72.5, 10.0, 11.5);
                    player.vel_y = 0.0;
                } else {
                    // Warp from outer island back to central island gateway landing
                    player.pos = math.Vec3.init(32.5, 10.0, -2.5);
                    player.vel_y = 0.0;
                }
                audio.play(.portal_warp, 1.0);
                audio.play(.mob_teleport, 1.0);
                particles.spawnPortalParticles(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 32);
                particles.spawnPortalVortex(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 1.5, 24, 0.0);
                toast.timer = 2.5;
                toast.color = .{ 0.82, 0.20, 0.96 };
                std.debug.print("traversed End Gateway: warped to ({d:.1}, {d:.1}, {d:.1})\n", .{ player.pos.x, player.pos.y, player.pos.z });
            }

            // Check if player is standing inside an End Portal block (instantaneous dimension jump)
            const in_end_portal = (feet_b == .end_portal or head_b == .end_portal);
            if (in_end_portal) {
                particles.spawnPortalParticles(.{ player.pos.x, player.pos.y + 0.5, player.pos.z }, 4);
                particles.spawnGlowstoneShimmer(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 2);
            }
            if (end_portal_transit.tick(in_end_portal, dt)) {
                // Dimension warp between Overworld and The End!
                if (end_portal_transit.current_dim == .the_end) {
                    manager.is_end = true;
                    manager.is_nether = false;
                    // Spawn on obsidian arrival platform at (0, 11, 0)
                    player.pos = math.Vec3.init(0.5, 11.2, 0.5);
                    player.vel_y = 0.0;

                    // Spawn boss: Ender Dragon soaring above the central End Island if not already present
                    var dragon_exists = false;
                    for (mob_manager.mobs.items) |m| {
                        if (m.mob_type == .ender_dragon) {
                            dragon_exists = true;
                            break;
                        }
                    }
                    if (!dragon_exists) {
                        try mob_manager.spawnMob(.ender_dragon, 0.0, 16.0, 12.0);
                        audio.play(.dragon_roar, 1.0);
                        std.debug.print("Ender Dragon boss spawned in The End (200 HP)!\n", .{});
                    }
                    // Spawn End Ship Shulker Guard on the outer island vessel
                    var shulker_exists = false;
                    for (mob_manager.mobs.items) |m| {
                        if (m.mob_type == .shulker) {
                            shulker_exists = true;
                            break;
                        }
                    }
                    if (!shulker_exists) {
                        try mob_manager.spawnMob(.shulker, 84.5, 13.0, 0.5);
                        std.debug.print("End Ship Shulker guard stationed on vessel!\n", .{});
                    }
                } else {
                    manager.is_end = false;
                    // Return to Overworld spawn point
                    player.pos = player.spawn_point;
                    player.vel_y = 0.0;
                }
                portal_flash_timer = 1.0;
                particles.spawnPortalParticles(.{ player.pos.x, player.pos.y + 1.0, player.pos.z }, 32);
                particles.spawnPortalVortex(.{ player.pos.x, player.pos.y + 0.9, player.pos.z }, 1.4, 24, 0.0);
                audio.play(.portal_warp, 1.0);
                audio.play(.mob_teleport, 0.9);
                toast.timer = 3.0;
                toast.color = if (manager.is_end) .{ 0.82, 0.20, 0.96 } else .{ 0.20, 0.80, 0.35 };
                std.debug.print("dimension transit: warped to {s} at ({d:.1}, {d:.1}, {d:.1})\n", .{
                    @tagName(end_portal_transit.current_dim),
                    player.pos.x,
                    player.pos.y,
                    player.pos.z,
                });
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
                const from_dim: portal_mod.Dimension = if (portal_transit.current_dim == .nether) .overworld else .nether;
                // Query linked portal in target destination dimension
                if (portal_mod.findLinkedPortal(portal_targets[0..portal_target_count], from_dim, player.pos.x, player.pos.y, player.pos.z, portal_mod.PORTAL_LINK_SEARCH_RADIUS)) |linked| {
                    player.pos.x = @as(f32, @floatFromInt(linked.x)) + 0.5;
                    player.pos.y = @as(f32, @floatFromInt(linked.y)) + 0.1;
                    player.pos.z = @as(f32, @floatFromInt(linked.z)) + 0.5;
                    std.debug.print("linked portal matched at ({d},{d},{d})\n", .{ linked.x, linked.y, linked.z });
                } else {
                    const warp_target = portal_mod.PortalTransitState.calculateWarpPosition(
                        from_dim,
                        player.pos.x,
                        player.pos.y,
                        player.pos.z,
                    );
                    player.pos.x = warp_target[0];
                    player.pos.z = warp_target[2];
                }
                manager.is_nether = (portal_transit.current_dim == .nether);
                portal_flash_timer = 1.0;
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

            // In The End dimension: emit ambient purple void shimmer and portal drift
            if (manager.is_end) {
                particles.spawnPortalParticles(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 1);
            }

            // In Nether dimension: emit ambient falling ash flakes, cinder particles, and subterranean wind drone
            if (manager.is_nether) {
                particles.spawnNetherAsh(.{ player.pos.x, player.pos.y, player.pos.z }, 2);
                nether_ambient_timer += dt;
                if (nether_ambient_timer >= 4.0) {
                    nether_ambient_timer = 0.0;
                    audio.play(.nether_wind, 0.65);
                }
            } else {
                nether_ambient_timer = 0.0;
            }

    


        // Armor stand block maintenance & equipment visual shimmer
        {
            var asi: usize = 0;
            while (asi < armor_stand_count) {
                const as_stand = &armor_stands[asi];
                const cur_b = manager.getBlockWorld(as_stand.x, as_stand.y, as_stand.z);
                if (cur_b != .armor_stand) {
                    // Dropped items when stand is destroyed
                    if (as_stand.head) |it| _ = inventory.addItem(it, 1);
                    if (as_stand.chest) |it| _ = inventory.addItem(it, 1);
                    if (as_stand.legs) |it| _ = inventory.addItem(it, 1);
                    if (as_stand.feet) |it| _ = inventory.addItem(it, 1);
                    cache_mod.swapRemove(&armor_stands, &armor_stand_count, asi);
                    continue;
                }
                // Ambient particle hint if holding equipped armor
                if (as_stand.head != null or as_stand.chest != null or as_stand.legs != null or as_stand.feet != null) {
                    if (asi % 4 == sand_scan % 4) {
                        particles.spawnBlockDebris(as_stand.x, as_stand.y, as_stand.z, .{ 0.75, 0.60, 0.42 }, 1);
                    }
                }
                asi += 1;
            }
        }

        // Enchantment table celestial mystic glyph shimmer particles
        {
            var eti: usize = 0;
            while (eti < enchantment_table_count) {
                const et = &enchantment_tables[eti];
                const cur_b = manager.getBlockWorld(et.x, et.y, et.z);
                if (cur_b != .enchantment_table) {
                    cache_mod.swapRemove(&enchantment_tables, &enchantment_table_count, eti);
                    continue;
                }
                // Floating mystical rune particles ascending from pedestal
                particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(et.x)) + 0.5, @as(f32, @floatFromInt(et.y)) + 0.85, @as(f32, @floatFromInt(et.z)) + 0.5 }, 1);
                eti += 1;
            }
        }

        // Jukebox vinyl record playback and musical note particle shimmer
        {
            var jbi: usize = 0;
            while (jbi < jukebox_count) {
                const jb = &jukeboxes[jbi];
                const cur_b = manager.getBlockWorld(jb.x, jb.y, jb.z);
                if (cur_b != .jukebox) {
                    cache_mod.swapRemove(&jukeboxes, &jukebox_count, jbi);
                    continue;
                }

                if (jb.play_timer > 0.0) {
                    jb.play_timer -= dt;
                    // Spawn musical shimmer particle effect above jukebox while record spins
                    particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(jb.x)) + 0.5, @as(f32, @floatFromInt(jb.y)) + 1.1, @as(f32, @floatFromInt(jb.z)) + 0.5 }, 1);
                    if (jb.play_timer <= 0.0) {
                        jb.playing_disc = null;
                        jb.play_timer = 0.0;
                    }
                }
                jbi += 1;
            }
        }

        // Note Block redstone rising-edge acoustic trigger
        {
            var nbi: usize = 0;
            while (nbi < note_block_count) {
                const nb = &note_blocks[nbi];
                const cur_b = manager.getBlockWorld(nb.x, nb.y, nb.z);
                if (cur_b != .note_block) {
                    cache_mod.swapRemove(&note_blocks, &note_block_count, nbi);
                    continue;
                }

                const is_pwr = redstone_mod.isDispenserPowered(&pickBlockWorld, nb.x, nb.y, nb.z);
                if (is_pwr and !nb.powered) {
                    nb.powered = true;
                    // Play note instrument based on floor block underneath (y - 1)
                    const floor_b = manager.getBlockWorld(nb.x, nb.y - 1, nb.z);
                    const inst = redstone_mod.getNoteInstrument(floor_b);
                    const snd: audio_mod.synth.SoundType = switch (inst) {
                        .bass => .note_bass,
                        .snare => .note_snare,
                        .chime => .note_chime,
                        .harp => .note_harp,
                    };
                    audio.playAt(snd, .{ @as(f32, @floatFromInt(nb.x)) + 0.5, @as(f32, @floatFromInt(nb.y)) + 0.5, @as(f32, @floatFromInt(nb.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 32.0);
                    particles.spawnFlame(nb.x, nb.y + 1, nb.z, 2);
                    std.debug.print("note block struck by redstone: {s} (pitch={d})\n", .{ @tagName(inst), nb.pitch });
                } else if (!is_pwr) {
                    nb.powered = false;
                }

                nbi += 1;
            }
        }

        // Brewing Stand: autonomous 2.5s distillation pipeline converting nether wart + glass into fire resistance potions
        {
            var bsi: usize = 0;
            while (bsi < brewing_stand_count) {
                const bs = &brewing_stands[bsi];
                const cur_b = manager.getBlockWorld(bs.x, bs.y, bs.z);
                if (cur_b != .brewing_stand) {
                    cache_mod.swapRemove(&brewing_stands, &brewing_stand_count, bsi);
                    continue;
                }

                // If active brew conditions are met (has fuel, bottle, and ingredient)
                const total_potions = bs.potions + bs.poison_potions + bs.weakness_potions;
                const can_brew_weakness = bs.fuel > 0 and bs.fermented_eyes > 0 and bs.bottles > 0 and total_potions < 3;
                const can_brew_poison = bs.fuel > 0 and bs.spider_eyes > 0 and bs.bottles > 0 and total_potions < 3;
                const can_brew_fire = bs.fuel > 0 and bs.wart > 0 and bs.bottles > 0 and total_potions < 3;
                if (can_brew_weakness) {
                    bs.progress += dt;
                    if (bs.progress >= 2.5) {
                        bs.progress = 0.0;
                        bs.fuel -= 1;
                        bs.fermented_eyes -= 1;
                        bs.bottles -= 1;
                        bs.weakness_potions += 1;
                        audio.playAt(.lava_pop, .{ @as(f32, @floatFromInt(bs.x)) + 0.5, @as(f32, @floatFromInt(bs.y)) + 0.5, @as(f32, @floatFromInt(bs.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                        particles.spawnBlockDebris(bs.x, bs.y, bs.z, .{ 0.45, 0.40, 0.50 }, 12);
                        std.debug.print("brewed potion of weakness at ({d},{d},{d}) (weakness potions={d})\n", .{ bs.x, bs.y, bs.z, bs.weakness_potions });
                    }
                } else if (can_brew_poison) {
                    bs.progress += dt;
                    if (bs.progress >= 2.5) {
                        bs.progress = 0.0;
                        bs.fuel -= 1;
                        bs.spider_eyes -= 1;
                        bs.bottles -= 1;
                        bs.poison_potions += 1;
                        audio.playAt(.lava_pop, .{ @as(f32, @floatFromInt(bs.x)) + 0.5, @as(f32, @floatFromInt(bs.y)) + 0.5, @as(f32, @floatFromInt(bs.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                        particles.spawnBlockDebris(bs.x, bs.y, bs.z, .{ 0.35, 0.75, 0.25 }, 12);
                        std.debug.print("brewed potion of poison at ({d},{d},{d}) (poison potions={d})\n", .{ bs.x, bs.y, bs.z, bs.poison_potions });
                    }
                } else if (can_brew_fire) {
                    bs.progress += dt;
                    if (bs.progress >= 2.5) {
                        bs.progress = 0.0;
                        bs.fuel -= 1;
                        bs.wart -= 1;
                        bs.bottles -= 1;
                        bs.potions += 1;
                        audio.playAt(.lava_pop, .{ @as(f32, @floatFromInt(bs.x)) + 0.5, @as(f32, @floatFromInt(bs.y)) + 0.5, @as(f32, @floatFromInt(bs.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                        particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(bs.x)) + 0.5, @as(f32, @floatFromInt(bs.y)) + 0.7, @as(f32, @floatFromInt(bs.z)) + 0.5 }, 12);
                        std.debug.print("brewed fire resistance potion at ({d},{d},{d}) (total potions={d})\n", .{ bs.x, bs.y, bs.z, bs.potions });
                    }
                } else {
                    bs.progress = 0.0;
                }

                bsi += 1;
            }
        }

        // Hopper block: autonomous 4-tick (0.4s) item pipeline siphoning from above & funneling downward
        {
            var hpi: usize = 0;
            while (hpi < hopper_count) {
                const hop = &hoppers[hpi];
                const cur_b = manager.getBlockWorld(hop.x, hop.y, hop.z);
                if (cur_b != .hopper) {
                    cache_mod.swapRemove(&hoppers, &hopper_count, hpi);
                    continue;
                }

                hop.cooldown = @max(0.0, hop.cooldown - dt);
                // Hoppers locked when receiving redstone power
                const locked = redstone_mod.isDispenserPowered(&pickBlockWorld, hop.x, hop.y, hop.z);
                if (!locked and hop.cooldown <= 0.0) {
                    var did_action = false;

                    // 1. Siphon item from container above (y + 1)
                    const above_x = hop.x;
                    const above_y = hop.y + 1;
                    const above_z = hop.z;
                    const above_b = manager.getBlockWorld(above_x, above_y, above_z);

                    if (above_b == .chest or above_b == .shulker_box) {
                        for (chests[0..chest_count]) |*ch| {
                            if (ch.x == above_x and ch.y == above_y and ch.z == above_z) {
                                for (&ch.items) |*cs| {
                                    if (!cs.isEmpty()) {
                                        // Try inserting into hopper slots
                                        for (&hop.items) |*hs| {
                                            if (hs.item == cs.item and hs.count < 64) {
                                                hs.count += 1;
                                                cs.count -= 1;
                                                if (cs.count == 0) cs.item = .none;
                                                did_action = true;
                                                break;
                                            } else if (hs.isEmpty()) {
                                                hs.* = .{ .item = cs.item, .count = 1 };
                                                cs.count -= 1;
                                                if (cs.count == 0) cs.item = .none;
                                                did_action = true;
                                                break;
                                            }
                                        }
                                        if (did_action) break;
                                    }
                                }
                                break;
                            }
                        }
                    }

                    // 2. Funnel/push item to container below (y - 1)
                    if (!did_action) {
                        const below_x = hop.x;
                        const below_y = hop.y - 1;
                        const below_z = hop.z;
                        const below_b = manager.getBlockWorld(below_x, below_y, below_z);

                        if (below_b == .chest or below_b == .shulker_box) {
                            for (chests[0..chest_count]) |*ch| {
                                if (ch.x == below_x and ch.y == below_y and ch.z == below_z) {
                                    for (&hop.items) |*hs| {
                                        if (!hs.isEmpty()) {
                                            for (&ch.items) |*cs| {
                                                if (cs.item == hs.item and cs.count < 64) {
                                                    cs.count += 1;
                                                    hs.count -= 1;
                                                    if (hs.count == 0) hs.item = .none;
                                                    did_action = true;
                                                    break;
                                                } else if (cs.isEmpty()) {
                                                    cs.* = .{ .item = hs.item, .count = 1 };
                                                    hs.count -= 1;
                                                    if (hs.count == 0) hs.item = .none;
                                                    did_action = true;
                                                    break;
                                                }
                                            }
                                            if (did_action) break;
                                        }
                                    }
                                    break;
                                }
                            }
                        }
                    }

                    if (did_action) {
                        hop.cooldown = 0.4; // 8 game ticks (0.4s) standard hopper speed
                        audio.play(.click_on, 0.4);
                        particles.spawnBlockDebris(hop.x, hop.y, hop.z, .{ 0.4, 0.4, 0.45 }, 2);
                        std.debug.print("hopper transferred item\n", .{});
                    }
                }
                hpi += 1;
            }
        }

        // Dropper block: gentle item drop or container insertion upon redstone pulse
        {
            var dpi: usize = 0;
            while (dpi < dropper_count) {
                const drop = &droppers[dpi];
                const cur_b = manager.getBlockWorld(drop.x, drop.y, drop.z);
                if (cur_b != .dropper) {
                    cache_mod.swapRemove(&droppers, &dropper_count, dpi);
                    continue;
                }

                const powered_now = redstone_mod.isDispenserPowered(&pickBlockWorld, drop.x, drop.y, drop.z);
                if (powered_now and !drop.powered) {
                    drop.powered = true;
                    // Find first non-empty item stack in dropper
                    var found_idx: ?usize = null;
                    for (drop.items[0..4], 0..) |sl, si| {
                        if (sl.item != .none and sl.count > 0) {
                            found_idx = si;
                            break;
                        }
                    }

                    if (found_idx) |si| {
                        const dropped_item = drop.items[si].item;
                        drop.items[si].count -= 1;
                        if (drop.items[si].count == 0) drop.items[si].item = .none;

                        // Target in front of dropper nozzle (north / -Z)
                        const front_x = drop.x;
                        const front_y = drop.y;
                        const front_z = drop.z - 1;
                        const front_block = manager.getBlockWorld(front_x, front_y, front_z);

                        if (front_block == .chest) {
                            // Transfer directly into chest container if one exists at (front_x, front_y, front_z)
                            var chest_found = false;
                            for (chests[0..chest_count]) |*ch| {
                                if (ch.x == front_x and ch.y == front_y and ch.z == front_z) {
                                    for (&ch.items) |*cs| {
                                        if (cs.item == dropped_item and cs.count < 64) {
                                            cs.count += 1;
                                            chest_found = true;
                                            break;
                                        } else if (cs.isEmpty()) {
                                            cs.* = .{ .item = dropped_item, .count = 1 };
                                            chest_found = true;
                                            break;
                                        }
                                    }
                                    break;
                                }
                            }
                            audio.play(.click_on, 0.7);
                            particles.spawnBlockDebris(front_x, front_y, front_z, .{ 0.8, 0.8, 0.8 }, 3);
                            std.debug.print("dropper inserted {s} into chest\n", .{@tagName(dropped_item)});
                        } else {
                            // Gentle item drop into world: adds directly to player inventory if within pickup range
                            const pdx = player.pos.x - (@as(f32, @floatFromInt(front_x)) + 0.5);
                            const pdy = player.pos.y - @as(f32, @floatFromInt(front_y));
                            const pdz = player.pos.z - (@as(f32, @floatFromInt(front_z)) + 0.5);
                            const dist_sq = pdx * pdx + pdy * pdy + pdz * pdz;

                            if (dist_sq < 16.0) {
                                _ = inventory.addItem(dropped_item, 1);
                                audio.play(.click_on, 0.8);
                            } else {
                                audio.play(.click_off, 0.6);
                            }
                            particles.spawnBlockDebris(front_x, front_y, front_z, .{ 0.8, 0.8, 0.8 }, 4);
                            std.debug.print("dropper dropped {s}\n", .{@tagName(dropped_item)});
                        }
                    } else {
                        audio.play(.click_off, 0.5);
                    }
                } else if (!powered_now and drop.powered) {
                    drop.powered = false;
                }
                dpi += 1;
            }
        }

        // Dispenser block: launches projectile into world upon redstone rising edge pulse
        {
            var di: usize = 0;
            while (di < dispenser_count) {
                const disp = &dispensers[di];
                const cur_b = manager.getBlockWorld(disp.x, disp.y, disp.z);
                if (cur_b != .dispenser) {
                    cache_mod.swapRemove(&dispensers, &dispenser_count, di);
                    continue;
                }

                const powered_now = redstone_mod.isDispenserPowered(&pickBlockWorld, disp.x, disp.y, disp.z);
                if (powered_now and !disp.powered) {
                    disp.powered = true;
                    if (disp.ammo_count > 0 and thrown_count < thrown.len) {
                        disp.ammo_count -= 1;
                        // Determine launch vector (front face: north / -Z)
                        const launch_x = @as(f32, @floatFromInt(disp.x)) + 0.5;
                        const launch_y = @as(f32, @floatFromInt(disp.y)) + 0.5;
                        const launch_z = @as(f32, @floatFromInt(disp.z)) - 0.6; // eject out front nozzle

                        // Launch projectile (arrow / fireworks rocket / snowball)
                        const cycle = disp.ammo_count % 3;
                        if (cycle == 0) {
                            // Arrow
                            thrown[thrown_count] = .{
                                .pos = math.Vec3.init(launch_x, launch_y, launch_z),
                                .vel = math.Vec3.init(0.0, 1.0, -22.0),
                                .life = proj_mod.throw_life,
                                .kind = .arrow,
                                .damage = 4,
                            };
                            thrown_count += 1;
                            audio.play(.bow_shoot, 0.9);
                        } else if (cycle == 1) {
                            // Fireworks Rocket
                            thrown[thrown_count] = .{
                                .pos = math.Vec3.init(launch_x, launch_y, launch_z),
                                .vel = math.Vec3.init(0.0, 2.5, -26.0),
                                .life = proj_mod.firework_rocket_life,
                                .kind = .firework_rocket,
                                .damage = proj_mod.firework_explosion_damage,
                            };
                            thrown_count += 1;
                            audio.play(.burn_sizzle, 0.8);
                        } else {
                            // Spectral Arrow
                            thrown[thrown_count] = .{
                                .pos = math.Vec3.init(launch_x, launch_y, launch_z),
                                .vel = math.Vec3.init(0.0, 1.0, -22.0),
                                .life = proj_mod.throw_life,
                                .kind = .spectral_arrow,
                                .damage = proj_mod.spectral_arrow_damage,
                            };
                            thrown_count += 1;
                            audio.play(.glowstone_chime, 0.8);
                        }
                        particles.spawnFlame(disp.x, disp.y, disp.z, 4);
                        particles.spawnCampfireSmoke(disp.x, disp.y, disp.z, false, false, 2);
                        std.debug.print("dispenser triggered: projectile launched ({d} ammo remaining)\n", .{disp.ammo_count});
                    } else {
                        audio.play(.click_off, 0.6);
                    }
                } else if (!powered_now and disp.powered) {
                    disp.powered = false;
                }
                di += 1;
            }
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
                const near_b = manager.getBlockWorld(pox, poy, poz);
                if (near_b == .nether_portal) {
                    const po_pos = [3]f32{ @as(f32, @floatFromInt(pox)) + 0.5, @as(f32, @floatFromInt(poy)) + 0.5, @as(f32, @floatFromInt(poz)) + 0.5 };
                    particles.spawnPortalParticles(po_pos, 4);
                    audio.playAt(.portal_hum, po_pos, .{ player.pos.x, player.pos.y, player.pos.z }, 0.75, 18.0);
                } else if (near_b == .glowstone) {
                    const gl_pos = [3]f32{ @as(f32, @floatFromInt(pox)) + 0.5, @as(f32, @floatFromInt(poy)) + 0.5, @as(f32, @floatFromInt(poz)) + 0.5 };
                    particles.spawnGlowstoneShimmer(gl_pos, 3);
                    audio.playAt(.glowstone_chime, gl_pos, .{ player.pos.x, player.pos.y, player.pos.z }, 0.6, 16.0);
                } else if (near_b == .lodestone) {
                    const lode_pos = [3]f32{ @as(f32, @floatFromInt(pox)) + 0.5, @as(f32, @floatFromInt(poy)) + 0.5, @as(f32, @floatFromInt(poz)) + 0.5 };
                    particles.spawnLodestoneAttunement(lode_pos, 2);
                }
            }
        }
        if (player.isDead()) {
            audio.play(.hurt, 0.8);
            std.debug.print("you died; respawning\n", .{});
            // If spawn point is near an anchor, consume 1 charge from it
            const spx: i32 = @intFromFloat(@floor(player.spawn_point.x));
            const spy: i32 = @intFromFloat(@floor(player.spawn_point.y - 0.5));
            const spz: i32 = @intFromFloat(@floor(player.spawn_point.z));
            var found_anc: ?usize = null;
            for (anchors[0..anchor_count], 0..) |anc, ai| {
                if (anc.x == spx and anc.y == spy and anc.z == spz) {
                    found_anc = ai;
                    break;
                }
            }
            if (found_anc) |ai| {
                if (anchors[ai].charges > 0) {
                    anchors[ai].charges -= 1;
                    std.debug.print("respawn anchor charge consumed ({d}/4 remain)\n", .{anchors[ai].charges});
                }
            }
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

        // Target block pulse decay: pulse expires after 0.4s
        {
            var tpi: usize = 0;
            while (tpi < target_pulse_count) {
                target_pulses[tpi].t -= dt;
                if (target_pulses[tpi].t <= 0.0 or manager.getBlockWorld(target_pulses[tpi].x, target_pulses[tpi].y, target_pulses[tpi].z) != .target_block) {
                    target_pulses[tpi] = target_pulses[target_pulse_count - 1];
                    target_pulse_count -= 1;
                } else {
                    tpi += 1;
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
            // Water contact quenches nether portal: check 8x8 volume around player
            const pxi_w: i32 = @intFromFloat(@floor(player.pos.x));
            const pyi_w: i32 = @intFromFloat(@floor(player.pos.y));
            const pzi_w: i32 = @intFromFloat(@floor(player.pos.z));
            var qx: i32 = -4;
            while (qx <= 4) : (qx += 1) {
                var qy: i32 = -2;
                while (qy <= 3) : (qy += 1) {
                    var qz: i32 = -4;
                    while (qz <= 4) : (qz += 1) {
                        const wx = pxi_w + qx;
                        const wy = pyi_w + qy;
                        const wz = pzi_w + qz;
                        if (manager.getBlockWorld(wx, wy, wz) == .nether_portal) {
                            const adj_water = (manager.getBlockWorld(wx, wy + 1, wz) == .water or
                                               manager.getBlockWorld(wx + 1, wy, wz) == .water or
                                               manager.getBlockWorld(wx - 1, wy, wz) == .water or
                                               manager.getBlockWorld(wx, wy, wz + 1) == .water or
                                               manager.getBlockWorld(wx, wy, wz - 1) == .water);
                            if (adj_water) {
                                _ = try manager.editAndRemesh(wx, wy, wz, .air);
                                particles.spawnPortalParticles(.{ @as(f32, @floatFromInt(wx)) + 0.5, @as(f32, @floatFromInt(wy)) + 0.5, @as(f32, @floatFromInt(wz)) + 0.5 }, 12);
                                audio.play(.burn_sizzle, 0.7);
                                std.debug.print("water quenched nether portal at ({d},{d},{d})\n", .{ wx, wy, wz });
                            }
                        }
                    }
                }
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
                    } else if (nb == .daylight_detector or nb == .daylight_detector_inverted) {
                        const dl_str = if (manager.is_nether) 0 else redstone_mod.daylightSignalStrength(@sin(world_time), nb == .daylight_detector_inverted);
                        strength[wi] = @max(strength[wi], dl_str);
                    } else if (nb == .target_block) {
                        for (target_pulses[0..target_pulse_count]) |tp| {
                            if (tp.x == w.x + ad[0] and tp.y == w.y + ad[1] and tp.z == w.z + ad[2]) {
                                strength[wi] = @max(strength[wi], tp.strength);
                                break;
                            }
                        }
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

        // Ripen planted nether wart after 60s into bonus-yield mature crop
        var wi: usize = 0;
        while (wi < wart_count) {
            warts[wi].t += dt;
            if (sapling_mod.isWartReady(warts[wi].t)) {
                std.debug.print("nether wart ripened\n", .{});
                cache_mod.swapRemove(&warts, &wart_count, wi);
            } else {
                wi += 1;
            }
        }

        // Burn out fireball-ignited flames after lifetime; player campfires are permanent.
        var flame_i: usize = 0;
        while (flame_i < flame_count) {
            flames[flame_i].t += dt;
            if (flames[flame_i].t >= hazard_mod.ignited_flame_life) {
                const cur_flame = manager.getBlockWorld(flames[flame_i].x, flames[flame_i].y, flames[flame_i].z);
                if (cur_flame == .campfire or cur_flame == .soul_campfire) {
                    _ = try manager.editAndRemesh(flames[flame_i].x, flames[flame_i].y, flames[flame_i].z, .air);
                    particles.spawnBlockDebris(flames[flame_i].x, flames[flame_i].y, flames[flame_i].z, .{ 0.3, 0.3, 0.3 }, 6);
                    std.debug.print("ignited flame burned out\n", .{});
                }
                cache_mod.swapRemove(&flames, &flame_count, flame_i);
            } else {
                flame_i += 1;
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

        // Insomnia aerial night spawn: spawn Phantoms circling above insomniac players
        if (is_night_spawn and player.hasInsomnia() and mob_manager.mobs.items.len < 8 and !manager.is_nether and !manager.is_end) {
            // 2% chance per tick when insomniac at night to summon a predatory Phantom
            const p_seed = @as(u32, @bitCast(@as(i32, @intFromFloat(player.pos.x * 23.0)))) ^ @as(u32, @bitCast(@as(i32, @intFromFloat(player.pos.z * 41.0)))) ^ @as(u32, @intFromFloat(player.insomnia_timer * 10.0));
            if ((p_seed % 50) == 0) {
                try mob_manager.spawnMob(.phantom, player.pos.x + 4.0, 15.0, player.pos.z + 4.0);
                audio.play(.mob_roar, 0.85);
                std.debug.print("Insomnia summoned Phantom circling above at y=15!\n", .{});
            }
        }
        const held_warped_fungus = (inventory.slots[selected_slot].item == .warped_fungus or inventory.slots[selected_slot].item == .warped_fungus_on_a_stick);
        mob_manager.tick(&pickSolid, &pickFluid, &pickBlockWorld, player.pos, player.radius, held_warped_fungus, &audio, dt);
        // In The End: emit soaring celestial violet gateway sky-beams from nearby End Gateways
        if (manager.is_end) {
            if (@abs(player.pos.x - 32.0) <= 64.0 and @abs(player.pos.z - 0.0) <= 64.0) {
                particles.spawnGatewayBeam(32, 11, 0, 3);
            }
            if (@abs(player.pos.x - 72.0) <= 64.0 and @abs(player.pos.z - 14.0) <= 64.0) {
                particles.spawnGatewayBeam(72, 11, 14, 3);
            }
        }

        // In The End: Ender Dragon links to intact End Crystals for radiant health regeneration
        if (manager.is_end) {
            const crystal_coords = [_][3]i32{
                .{ 16, 15, 16 },
                .{ -16, 15, 16 },
                .{ 16, 15, -16 },
                .{ -16, 15, -16 },
            };
            for (mob_manager.mobs.items) |*m| {
                if (m.mob_type == .ender_dragon and m.health > 0) {
                    for (crystal_coords) |c_pos| {
                        if (manager.getBlockWorld(c_pos[0], c_pos[1], c_pos[2]) == .end_crystal) {
                            const cx = @as(f32, @floatFromInt(c_pos[0])) + 0.5;
                            const cy = @as(f32, @floatFromInt(c_pos[1])) + 0.5;
                            const cz = @as(f32, @floatFromInt(c_pos[2])) + 0.5;
                            // Emit beam tether particles between crystal and dragon
                            const t_frac = 0.5 + 0.5 * @sin(@as(f32, @floatCast(current_time)) * 6.0);
                            const bx = cx + (m.pos.x - cx) * t_frac;
                            const by = cy + (m.pos.y - cy) * t_frac;
                            const bz = cz + (m.pos.z - cz) * t_frac;
                            particles.spawnPortalVortex(.{ bx, by, bz }, 0.4, 2, 0.0);
                            particles.spawnGlowstoneShimmer(.{ bx, by, bz }, 1);

                            // Healing pulse (restores health capped at 200)
                            if (m.health < 200 and @sin(@as(f32, @floatCast(current_time)) * 4.0) > 0.95) {
                                m.health = @min(200, m.health + 1);
                            }
                        }
                    }
                    // Periodic dragon breath strafe attack: drops a harmful AoE dragon breath cloud onto island
                    if (@as(u32, @intFromFloat(current_time * 10.0)) % 180 == 0 and vapor_cloud_count < vapor_clouds.len) {
                        vapor_clouds[vapor_cloud_count] = .{
                            .pos = .{ m.pos.x, 8.5, m.pos.z },
                            .radius = 4.0,
                            .life = 12.0,
                            .max_life = 12.0,
                            .effect = .dragons_breath,
                        };
                        vapor_cloud_count += 1;
                        audio.playAt(.dragon_roar, .{ m.pos.x, 8.5, m.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 30.0);
                        std.debug.print("Ender Dragon spewed Dragon's Breath hazard cloud!\n", .{});
                    }
                }
            }
        }

        // Vapor clouds tick: decay lifetime, emit colored swirling particles, and apply AoE hazards
        {
            var vci: usize = 0;
            while (vci < vapor_cloud_count) {
                var vc = &vapor_clouds[vci];
                vc.life -= dt;
                if (vc.life <= 0.0) {
                    cache_mod.swapRemove(&vapor_clouds, &vapor_cloud_count, vci);
                    continue;
                }
                // Emit radial swirling mist particles
                const mist_col: [3]f32 = switch (vc.effect) {
                    .dragons_breath => .{ 0.85, 0.25, 0.90 },
                    .lingering_poison => .{ 0.35, 0.85, 0.20 },
                    .lingering_weakness => .{ 0.45, 0.40, 0.55 },
                };
                particles.spawnPortalParticles(vc.pos, 2);
                particles.spawnBlockDebris(@intFromFloat(vc.pos[0]), @intFromFloat(vc.pos[1]), @intFromFloat(vc.pos[2]), mist_col, 2);

                // Player hazard check
                if (vc.isInside(player.pos.x, player.pos.y, player.pos.z)) {
                    switch (vc.effect) {
                        .dragons_breath => {
                            player.health = @max(0.0, player.health - 2.0 * dt);
                        },
                        .lingering_poison => {
                            player.applyPoison();
                        },
                        .lingering_weakness => {
                            player.applyWeakness();
                        },
                    }
                }
                vci += 1;
            }
        }

        for (mob_manager.mobs.items) |*m| {
            if (m.isGlowing()) {
                particles.spawnGlowstoneShimmer(.{ m.pos.x, m.pos.y + 0.4, m.pos.z }, 1);
            }
            if (m.leashed_to_player) {
                const broke = entity_mod.mob.applyLeashTension(&m.pos, &m.vel, player.pos, dt);
                if (broke) {
                    m.leashed_to_player = false;
                    _ = inventory.addItem(.lead, 1);
                    audio.play(.click_off, 0.7);
                    std.debug.print("lead snapped: excessive distance from player\n", .{});
                } else {
                    // Visual knot/tether string particles connecting mob to player
                    particles.spawnBlockDebris(@intFromFloat(m.pos.x), @intFromFloat(m.pos.y + 0.5), @intFromFloat(m.pos.z), .{ 0.82, 0.74, 0.52 }, 1);
                }
            } else if (m.fence_post) |fp| {
                const anchor = math.Vec3.init(@as(f32, @floatFromInt(fp.x)) + 0.5, @as(f32, @floatFromInt(fp.y)) + 0.5, @as(f32, @floatFromInt(fp.z)) + 0.5);
                const cur_b = manager.getBlockWorld(fp.x, fp.y, fp.z);
                if (!cur_b.is_fence()) {
                    m.fence_post = null;
                    _ = inventory.addItem(.lead, 1);
                } else {
                    const broke = entity_mod.mob.applyLeashTension(&m.pos, &m.vel, anchor, dt);
                    if (broke) {
                        m.fence_post = null;
                        _ = inventory.addItem(.lead, 1);
                        audio.play(.click_off, 0.7);
                        std.debug.print("lead snapped: excessive distance from hitching post\n", .{});
                    } else {
                        particles.spawnBlockDebris(fp.x, fp.y, fp.z, .{ 0.82, 0.74, 0.52 }, 1);
                    }
                }
            }
        }

        // Wolf bites & mob melee attacks: contact damage with per-second cooldown
        wolf_bite_cooldown = combat_mod.tickCooldown(wolf_bite_cooldown, dt);
        if (wolf_bite_cooldown <= 0.0) {
            const held_gold = (inventory.slots[selected_slot].item == .gold_nugget or inventory.slots[selected_slot].item == .golden_apple or inventory.hasAnyGoldenArmor());
            for (mob_manager.mobs.items) |*m| {
                if (m.mob_type != .wolf and m.mob_type != .emberbeast and m.mob_type != .wither_skeleton and m.mob_type != .piglin and m.mob_type != .piglin_brute and m.mob_type != .blaze and m.mob_type != .spider and m.mob_type != .cave_spider and m.mob_type != .endermite and m.mob_type != .drowned and m.mob_type != .phantom and m.mob_type != .guardian and m.mob_type != .elder_guardian and m.mob_type != .slime) continue;
                if (m.mob_type == .piglin and (held_gold or m.barter_timer > 0.0 or entity_mod.mob_manager.MobManager.isPiglinRepelled(m.pos, player.pos, held_warped_fungus, &pickBlockWorld) != null)) continue;
                const bdx = m.pos.x - player.pos.x;
                const bdz = m.pos.z - player.pos.z;
                const bdy = m.pos.y - player.pos.y;
                if (combat_mod.inBiteRange(bdx, bdz, bdy)) {
                    const pack_count = mob_manager.countNearbyWolves(m.pos, entity_mod.pack_hunt.pack_rally_radius);
                    const bonus = entity_mod.pack_hunt.packBonus(pack_count);
                    const hit = combat_mod.calculateWolfBite(bdx, bdz, bonus);
                    const cf = cam.front();
                    const blocked = is_blocking and combat_mod.canBlockAttack(cf.x, cf.z, bdx, bdz);
                    if (blocked) {
                        audio.play(.shield_block, 0.9);
                        const bx: i32 = @intFromFloat(@floor(player.pos.x + cf.x * 0.6));
                        const by: i32 = @intFromFloat(@floor(player.pos.y + 0.8));
                        const bz: i32 = @intFromFloat(@floor(player.pos.z + cf.z * 0.6));
                        particles.spawnBlockDebris(bx, by, bz, .{ 0.72, 0.68, 0.60 }, 8);
                        player.pos.x -= hit.knockback_x * (1.0 - combat_mod.shield_knockback_absorption);
                        player.pos.z -= hit.knockback_z * (1.0 - combat_mod.shield_knockback_absorption);
                        m.vel.x = bdx * 1.5;
                        m.vel.z = bdz * 1.5;
                        if (tool_wear.use(selected_slot, inventory_mod.ItemType.shield.maxDurability())) {
                            inventory.slots[selected_slot].clear();
                            audio.play(.break_block, 0.8);
                            std.debug.print("shield broke\n", .{});
                        }
                        std.debug.print("shield blocked attack from {s}\n", .{@tagName(m.mob_type)});
                    } else {
                        const raw_dmg = if (m.is_champion) hit.damage * 2.5 else if (m.mob_type == .piglin_brute) hit.damage * 2.5 else if (m.mob_type == .blaze or m.mob_type == .emberbeast) hit.damage * 2.0 else if (m.mob_type == .wither_skeleton or m.mob_type == .piglin) hit.damage * 1.5 else hit.damage;
                        const dmg = combat_mod.applyArmorReductionAllTiers(raw_dmg, inventory.hasItem(.netherite_chestplate), inventory.hasFullNetheriteSet(), inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet());
                        player.health = @max(0.0, player.health - dmg);
                        if (m.mob_type == .wither_skeleton) {
                            player.applyWither();
                            std.debug.print("withered", .{});
                        } else if (m.mob_type == .spider or m.mob_type == .cave_spider) {
                            player.applyPoison();
                            std.debug.print("poisoned by {s} venom\n", .{@tagName(m.mob_type)});
                                                } else if (m.mob_type == .enderman) {
                            // Enderman melee strike on player deals 4 damage
                            const em_dmg = combat_mod.applyArmorReductionAllTiers(4.0, inventory.hasItem(.netherite_chestplate), inventory.hasFullNetheriteSet(), inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet());
                            player.health = @max(0.0, player.health - em_dmg);
                            audio.play(.hurt, 0.9);
                            std.debug.print("enderman struck player (dmg={d:.1}, hp={d:.1})\n", .{ em_dmg, player.health });
                        } else if (m.mob_type == .zombie) {
                            player.applyHungerDebuff();
                            std.debug.print("infected with hunger by zombie bite", .{});
                        } else if (m.mob_type == .drowned) {
                            // Drowned melee attack deals 3 bonus damage (trident strike)
                            const dr_dmg = combat_mod.applyArmorReductionAllTiers(3.0, inventory.hasItem(.netherite_chestplate), inventory.hasFullNetheriteSet(), inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet());
                            player.health = @max(0.0, player.health - dr_dmg);
                            audio.play(.splash, 0.7);
                            std.debug.print("drowned trident strike (dmg={d:.1}, hp={d:.1})\n", .{ dr_dmg, player.health });
                        } else if (m.mob_type == .phantom) {
                            // Phantom swoop strike deals 3 damage with aerial roar
                            const ph_dmg = combat_mod.applyArmorReductionAllTiers(3.0, inventory.hasItem(.netherite_chestplate), inventory.hasFullNetheriteSet(), inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet());
                            player.health = @max(0.0, player.health - ph_dmg);
                            audio.play(.mob_roar, 0.85);
                            std.debug.print("phantom swoop attack struck player (dmg={d:.1}, hp={d:.1})\n", .{ ph_dmg, player.health });
                        } else if (m.mob_type == .guardian) {
                            // Guardian marine beam / thorn prick: 4 damage + splash acoustic
                            const g_dmg = combat_mod.applyArmorReductionAllTiers(4.0, inventory.hasItem(.netherite_chestplate), inventory.hasFullNetheriteSet(), inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet());
                            player.health = @max(0.0, player.health - g_dmg);
                            audio.play(.mob_roar, 0.9);
                            audio.play(.splash, 0.8);
                            std.debug.print("guardian laser beam struck player (dmg={d:.1}, hp={d:.1})\n", .{ g_dmg, player.health });
                        } else if (m.mob_type == .elder_guardian) {
                            // Elder Guardian boss laser beam: 6 damage + splash & heavy roar + Mining Fatigue affliction
                            const eg_dmg = combat_mod.applyArmorReductionAllTiers(6.0, inventory.hasItem(.netherite_chestplate), inventory.hasFullNetheriteSet(), inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet());
                            player.health = @max(0.0, player.health - eg_dmg);
                            player.applyMiningFatigue();
                            audio.play(.mob_roar, 1.0);
                            audio.play(.splash, 0.9);
                            std.debug.print("elder guardian laser beam struck player (dmg={d:.1}, hp={d:.1}, fatigue=60s)\n", .{ eg_dmg, player.health });
                        }
                        audio.play(.hurt, 0.8);
                        const has_leggings = inventory.hasItem(.netherite_leggings);
                        player.pos.x -= combat_mod.applyKnockbackResistance(hit.knockback_x, has_leggings);
                        player.pos.z -= combat_mod.applyKnockbackResistance(hit.knockback_z, has_leggings);
                        std.debug.print("mob attack (hp={d:.1}, type={s})\n", .{ player.health, @tagName(m.mob_type) });
                    }
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

        // Dimension atmosphere palettes
        const nether_sky_top = math.Vec3.init(0.18, 0.04, 0.04);
        const nether_sky_horizon = math.Vec3.init(0.32, 0.08, 0.06);
        const end_sky_top = math.Vec3.init(0.02, 0.01, 0.04);
        const end_sky_horizon = math.Vec3.init(0.08, 0.03, 0.12);

        // Render world
        if (cam_underwater) {
            c.glClearColor(0.08, 0.28, 0.58, 1.0);
        } else if (manager.is_end) {
            c.glClearColor(0.04, 0.02, 0.06, 1.0);
        } else if (manager.is_nether) {
            c.glClearColor(0.24, 0.06, 0.05, 1.0);
        } else {
            c.glClearColor(0.1, 0.1, 0.1, 1.0);
        }
        c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);

        if (cam_underwater) {
            const water_deep = math.Vec3.init(0.04, 0.14, 0.32);
            const water_hzn = math.Vec3.init(0.08, 0.28, 0.58);
            sky.draw(mvp, cam.position, water_deep, water_hzn);
        } else if (manager.is_end) {
            sky.draw(mvp, cam.position, end_sky_top, end_sky_horizon);
        } else if (manager.is_nether) {
            sky.draw(mvp, cam.position, nether_sky_top, nether_sky_horizon);
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
        // In Nether: scan nearby radius (~8 blocks) around player for hanging glowstone clusters
        if (manager.is_nether and lamp_spot_count < lamp_spots.len) {
            const p_ix: i32 = @intFromFloat(@floor(player.pos.x));
            const p_iy: i32 = @intFromFloat(@floor(player.pos.y));
            const p_iz: i32 = @intFromFloat(@floor(player.pos.z));
            var g_dx: i32 = -6;
            outer_g: while (g_dx <= 6) : (g_dx += 2) {
                var g_dz: i32 = -6;
                while (g_dz <= 6) : (g_dz += 2) {
                    var g_dy: i32 = -4;
                    while (g_dy <= 6) : (g_dy += 2) {
                        if (lamp_spot_count >= lamp_spots.len) break :outer_g;
                        const gx = p_ix + g_dx;
                        const gy = p_iy + g_dy;
                        const gz = p_iz + g_dz;
                        if (manager.getBlockWorld(gx, gy, gz) == .glowstone) {
                            lamp_spots[lamp_spot_count] = .{
                                @as(f32, @floatFromInt(gx)) + 0.5,
                                @as(f32, @floatFromInt(gy)) + 0.5,
                                @as(f32, @floatFromInt(gz)) + 0.5,
                            };
                            lamp_spot_count += 1;
                        }
                    }
                }
            }
        }
        const night_factor = 1.0 - day_factor;
        const stats = manager.draw(mvp, sun_dir, lamp_spots[0..lamp_spot_count], night_factor, cam.position, cam_underwater);
        try mob_manager.draw(mvp, sun_dir, cam.position, cam_underwater, manager.is_nether);

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
            const has_compass = inventory.hasItem(.compass);
            const has_lode_compass = inventory.hasItem(.lodestone_compass);
            var is_lodestone = false;
            const compass_rel: f32 = if (player.lodestone_target) |lt| blk: {
                if (has_lode_compass or has_compass or manager.is_nether) {
                    is_lodestone = true;
                    break :blk compass_mod.calculateNeedleAngle(lt.x, lt.z, player.pos.x, player.pos.z, cam.yaw);
                }
                break :blk compass_mod.compass_hidden;
            } else if (manager.is_nether) blk: {
                if (has_compass) {
                    break :blk compass_mod.netherSpinAngle(world_time, cam.yaw);
                } else {
                    const j = spawn_mod.nearestJunction(player.pos.x, player.pos.z);
                    break :blk compass_mod.calculateNeedleAngle(@as(f32, @floatFromInt(j.jx)), @as(f32, @floatFromInt(j.jz)), player.pos.x, player.pos.z, cam.yaw);
                }
            } else if (has_compass) blk: {
                break :blk compass_mod.calculateNeedleAngle(0.0, 0.0, player.pos.x, player.pos.z, cam.yaw);
            } else compass_mod.compass_hidden;

            // Query if Ender Dragon or Elder Guardian boss is present for boss health bar
            var boss_health_frac: f32 = -1.0;
            if (manager.is_end) {
                for (mob_manager.mobs.items) |m| {
                    if (m.mob_type == .ender_dragon and m.health > 0) {
                        boss_health_frac = @as(f32, @floatFromInt(m.health)) / 200.0;
                        break;
                    }
                }
            } else {
                for (mob_manager.mobs.items) |m| {
                    if (m.mob_type == .elder_guardian and m.health > 0) {
                        boss_health_frac = @as(f32, @floatFromInt(m.health)) / 80.0;
                        break;
                    }
                }
            }

            const hud_progress = if (bow_charge > 0.0) bow_charge else if (crossbow_charge > 0.0) crossbow_charge else if (crossbow_loaded and inventory.slots[selected_slot].item == .crossbow) 1.0 else mine_frac;
            ui.drawHUDWithCompass(aspect, selected_slot, &hotbar_colors, &hotbar_counts, hud_progress, player.health, player.hunger, player.regen_timer > 0.0, player.oxygen, player.fire_resistance_timer, player.wither_timer, compass_rel, is_lodestone, boss_health_frac);
            if (portal_transit.inside_timer > 0.0) {
                const vignette_intensity = portal_transit.inside_timer / portal_mod.PORTAL_TRIGGER_TIME;
                ui.drawPortalVignette(aspect, vignette_intensity);
            }
            if (portal_flash_timer > 0.0) {
                portal_flash_timer = @max(0.0, portal_flash_timer - dt * 1.5);
                ui.drawPortalFlash(aspect, portal_flash_timer * 0.85);
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
                const hit_dmg: u8 = combat_mod.calculatePlayerAttackDamageAllTiers(held_weapon == .netherite_sword, held_weapon == .diamond_sword, held_weapon == .iron_sword, held_weapon == .stone_sword, player.isWeakened());

                var bartered = false;
                if (right and !right_down and inventory.slots[selected_slot].item == .gold_nugget) {
                    if (mob_manager.tryBarter(cam.position, dir, combat_mod.melee_range)) |b| {
                        inventory.slots[selected_slot].decrement(1);
                        _ = inventory.addItem(b.item, b.count);
                        audio.play(.glowstone_chime, 0.9);
                        particles.spawnBurnSparks(.{ b.pos.x, b.pos.y + 0.8, b.pos.z }, 12);
                        toast.timer = 1.5;
                        toast.color = .{ 1.0, 0.85, 0.2 };
                        std.debug.print("bartered with piglin: {s} x{d}\n", .{ b.item.name(), b.count });
                        bartered = true;
                    }
                }
                var sheared_sheep = false;
                if (right and !right_down and !bartered and inventory.slots[selected_slot].item == .shears) {
                    if (mob_manager.tryShearSheep(cam.position, dir, combat_mod.melee_range)) |sh| {
                        _ = inventory.addItem(.wool, sh.wool_count);
                        audio.playAt(.shears_snip, .{ sh.pos.x, sh.pos.y + 0.5, sh.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 24.0);
                        particles.spawnBlockDebris(@intFromFloat(sh.pos.x), @intFromFloat(sh.pos.y + 0.5), @intFromFloat(sh.pos.z), .{ 0.92, 0.90, 0.85 }, 12);
                        if (tool_wear.use(selected_slot, inventory.slots[selected_slot].item.maxDurability())) {
                            inventory.slots[selected_slot].clear();
                        }
                        toast.timer = 1.5;
                        toast.color = .{ 0.90, 0.90, 0.90 };
                        std.debug.print("sheared sheep, acquired {d} wool\n", .{sh.wool_count});
                        sheared_sheep = true;
                    }
                }
                var leashed_mob = false;
                if (right and !right_down and !bartered) {
                    const has_lead = inventory.slots[selected_slot].item == .lead;
                    const leash_action = mob_manager.tryInteractLeash(cam.position, dir, combat_mod.melee_range, has_lead);
                    if (leash_action == .attached_to_player) {
                        inventory.slots[selected_slot].decrement(1);
                        audio.play(.step_wood, 0.8);
                        particles.spawnBlockDebris(@intFromFloat(player.pos.x), @intFromFloat(player.pos.y), @intFromFloat(player.pos.z), .{ 0.82, 0.74, 0.52 }, 6);
                        std.debug.print("attached lead to mob\n", .{});
                        leashed_mob = true;
                    } else if (leash_action == .unleashed_to_item) {
                        _ = inventory.addItem(.lead, 1);
                        audio.play(.click_off, 0.8);
                        std.debug.print("unleashed mob, lead recovered\n", .{});
                        leashed_mob = true;
                    }
                }

                const hit_mob_opt = if (!bartered and !sheared_sheep and !leashed_mob and left and mob_hit_cooldown <= 0.0) mob_manager.tryHitMobDmg(cam.position, dir, combat_mod.melee_range, hit_dmg) else null;
                if (!bartered) {
                if (hit_mob_opt) |hit_mob| {
                    mob_hit_cooldown = combat_mod.melee_cooldown;
                    if (held_weapon.isTool()) {
                        if (tool_wear.use(selected_slot, held_weapon.maxDurability())) {
                            inventory.slots[selected_slot].clear();
                        }
                    }
                    const px: i32 = @intFromFloat(@floor(hit_mob.pos.x));
                    const py: i32 = @intFromFloat(@floor(hit_mob.pos.y));
                    const pz: i32 = @intFromFloat(@floor(hit_mob.pos.z));
                    if (hit_mob.mob_type == .target_dummy) {
                        // Target dummy practice feedback
                        audio.playAt(.step_wood, .{ hit_mob.pos.x, hit_mob.pos.y, hit_mob.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 30.0);
                        particles.spawnBlockDebris(px, py, pz, .{ 0.90, 0.80, 0.35 }, 12);
                        particles.spawnGlowstoneShimmer(.{ hit_mob.pos.x, hit_mob.pos.y + 1.2, hit_mob.pos.z }, 4);
                        toast.timer = 1.2;
                        toast.color = .{ 1.0, 0.6, 0.2 };
                        std.debug.print("hit target dummy: dmg={d} (died={})\n", .{ hit_dmg, hit_mob.died });
                    } else {
                        if (entity_mod.mob.getSound(hit_mob.mob_type)) |hit_sound| {
                            audio.playAt(hit_sound, .{ hit_mob.pos.x, hit_mob.pos.y, hit_mob.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                        }
                        particles.spawnBlockDebris(px, py, pz, .{ 0.85, 0.2, 0.2 }, 8);
                    }
                    if (hit_mob.died) {
                        const drop = inventory_mod.getMobMeatDrop(hit_mob.mob_type);
                        _ = inventory.addItem(drop, 1);
                        if (hit_mob.mob_type == .emberbeast) {
                            const bonus = inventory_mod.getEmberBonus(px, pz);
                            if (bonus > 0) _ = inventory.addItem(.nether_wart, bonus);
                            particles.spawnFlame(px, py, pz, 6);
                        }
                        if (hit_mob.is_champion) {
                            _ = inventory.addItem(.nether_star, 1);
                            _ = inventory.addItem(.wither_skull, 2);
                            std.debug.print("wither champion slain: nether star dropped\n", .{});
                        } else if (hit_mob.mob_type == .wither_skeleton and inventory_mod.dropsWitherSkull(px, py, pz)) {
                            _ = inventory.addItem(.wither_skull, 1);
                            std.debug.print("wither skull dropped\n", .{});
                        } else if (hit_mob.mob_type == .spider and inventory_mod.dropsSpiderEye(px, py, pz)) {
                            _ = inventory.addItem(.spider_eye, 1);
                            std.debug.print("spider eye harvested\n", .{});
                        } else if (hit_mob.mob_type == .skeleton and inventory_mod.dropsSkeletonArrow(px, py, pz)) {
                            _ = inventory.addItem(.arrow, 2);
                            std.debug.print("skeleton dropped reserve arrows\n", .{});
                        } else if (hit_mob.mob_type == .zombie and inventory_mod.dropsZombieIron(px, py, pz)) {
                            _ = inventory.addItem(.iron_ingot, 1);
                            std.debug.print("zombie dropped rare iron ingot\n", .{});
                        } else if (hit_mob.mob_type == .drowned) {
                            if (inventory_mod.dropsDrownedTrident(px, py, pz)) {
                                _ = inventory.addItem(.trident, 1);
                                std.debug.print("drowned dropped rare trident!\n", .{});
                            } else if (inventory_mod.dropsDrownedNautilus(px, py, pz)) {
                                _ = inventory.addItem(.nautilus_shell, 1);
                                std.debug.print("drowned dropped nautilus shell!\n", .{});
                            }
                        }
                        if (hit_mob.mob_type == .ender_dragon) {
                            // Ender Dragon Defeat: celestial victory explosion and return portal fountain
                            audio.play(.dragon_roar, 1.0);
                            audio.play(.end_portal_open, 1.0);
                            particles.spawnFireworkBurst(.{ hit_mob.pos.x, hit_mob.pos.y, hit_mob.pos.z }, 64);
                            particles.spawnPortalVortex(.{ hit_mob.pos.x, hit_mob.pos.y, hit_mob.pos.z }, 3.5, 48, 0.0);
                            toast.timer = 5.0;
                            toast.color = .{ 1.0, 0.85, 0.20 };

                            // Generate Exit Portal Altar and Dragon Egg trophy at center (0, y, 0)
                            const exit_y: i32 = 8;
                            _ = manager.editAndRemesh(0, exit_y, 0, .obsidian) catch false;
                            _ = manager.editAndRemesh(0, exit_y + 1, 0, .obsidian) catch false;
                            _ = manager.editAndRemesh(0, exit_y + 2, 0, .dragon_egg) catch false;
                            // Surround base with horizontal return portal cells
                            const portal_rim = [_][2]i32{ .{ 1, 0 }, .{ -1, 0 }, .{ 0, 1 }, .{ 0, -1 } };
                            for (portal_rim) |pr| {
                                _ = manager.editAndRemesh(pr[0], exit_y, pr[1], .end_portal) catch false;
                            }
                            std.debug.print("Ender Dragon Defeated! Exit portal and Dragon Egg generated at (0, {d}, 0)!\n", .{exit_y});
                        }
                        if (hit_mob.wool) _ = inventory.addItem(.wool, 1);
                        std.debug.print("killed {s}, dropped {s}\n", .{ @tagName(hit_mob.mob_type), drop.name() });
                    }
                    mine.reset();
                } else if (pick_mod.raycast(&pickSolid, cam.position, dir, 8)) |hit| {
                    if (left) {
                        const broken_block = manager.getBlockWorld(hit.x, hit.y, hit.z);
                        const held_item_now = inventory.slots[selected_slot].item;
                        var need = block_mod.mineTime(broken_block, @intFromEnum(held_item_now));
                        if (player.hasMiningFatigue()) need /= 0.3;
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
                                // End Crystal destruction: violent concussive detonation and crater carving
                                if (broken_block == .end_crystal) {
                                    audio.play(.firework_blast, 1.0);
                                    particles.spawnFireworkBurst(.{ @as(f32, @floatFromInt(hit.x)) + 0.5, @as(f32, @floatFromInt(hit.y)) + 0.5, @as(f32, @floatFromInt(hit.z)) + 0.5 }, 36);
                                    particles.spawnPortalVortex(.{ @as(f32, @floatFromInt(hit.x)) + 0.5, @as(f32, @floatFromInt(hit.y)) + 0.5, @as(f32, @floatFromInt(hit.z)) + 0.5 }, 2.0, 24, 0.0);
                                    // Carve explosive blast crater in adjacent blocks
                                    var cr_x: i32 = -boom_mod.creeper_blast_radius;
                                    while (cr_x <= boom_mod.creeper_blast_radius) : (cr_x += 1) {
                                        var cr_y: i32 = -boom_mod.creeper_blast_radius;
                                        while (cr_y <= boom_mod.creeper_blast_radius) : (cr_y += 1) {
                                            var cr_z: i32 = -boom_mod.creeper_blast_radius;
                                            while (cr_z <= boom_mod.creeper_blast_radius) : (cr_z += 1) {
                                                if (boom_mod.inBlast(cr_x, cr_y, cr_z)) {
                                                    const bx = hit.x + cr_x;
                                                    const by = hit.y + cr_y;
                                                    const bz = hit.z + cr_z;
                                                    const b_to_break = manager.getBlockWorld(bx, by, bz);
                                                    if (b_to_break != .obsidian and b_to_break != .air) {
                                                        _ = try manager.editAndRemesh(bx, by, bz, .air);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    if (boom_mod.calculatePlayerBlastImpulse(player.pos.x, player.pos.y, player.pos.z, hit.x, hit.y, hit.z)) |imp| {
                                        player.health = @max(0.0, player.health - imp.damage * 1.5);
                                        player.vel_y = imp.vel_y * 1.2;
                                        player.pos.x += imp.push_x * 1.2;
                                        player.pos.z += imp.push_z * 1.2;
                                        audio.play(.hurt, 1.0);
                                    }
                                    std.debug.print("End Crystal detonated at ({d},{d},{d})!\n", .{ hit.x, hit.y, hit.z });
                                }

                                // If obsidian is broken, extinguish adjacent portal cells whose frame is no longer intact
                                if (broken_block == .obsidian) {
                                    var ext_cells: [6][3]i32 = undefined;
                                    const ext_n = portal_mod.collectPortalCellsToExtinguish(&pickBlockWorld, hit.x, hit.y, hit.z, &ext_cells);
                                    for (ext_cells[0..ext_n]) |cell_coord| {
                                        if (!portal_mod.isPortalCellValid(&pickBlockWorld, cell_coord[0], cell_coord[1], cell_coord[2])) {
                                            _ = try manager.editAndRemesh(cell_coord[0], cell_coord[1], cell_coord[2], .air);
                                            particles.spawnPortalParticles(.{ @as(f32, @floatFromInt(cell_coord[0])) + 0.5, @as(f32, @floatFromInt(cell_coord[1])) + 0.5, @as(f32, @floatFromInt(cell_coord[2])) + 0.5 }, 12);
                                            audio.play(.burn_sizzle, 0.7);
                                            std.debug.print("portal frame broken; extinguished portal cell at ({d},{d},{d})\n", .{ cell_coord[0], cell_coord[1], cell_coord[2] });
                                        }
                                    }
                                }
                                // Dragon Egg right/left click interactive teleportation mechanic
                                if (broken_block == .dragon_egg) {
                                    audio.play(.mob_teleport, 1.0);
                                    particles.spawnPortalParticles(.{ @as(f32, @floatFromInt(hit.x)) + 0.5, @as(f32, @floatFromInt(hit.y)) + 0.5, @as(f32, @floatFromInt(hit.z)) + 0.5 }, 24);
                                    // Teleport egg to random nearby solid ledge within 5 blocks if player does not pick it up
                                    const u_key: u64 = @bitCast(mine.key);
                                    const tx = hit.x + @as(i32, @intCast(u_key & 7)) - 3;
                                    const tz = hit.z + @as(i32, @intCast((u_key >> 3) & 7)) - 3;
                                    if (tx != hit.x or tz != hit.z) {
                                        _ = manager.editAndRemesh(tx, hit.y, tz, .dragon_egg) catch false;
                                        std.debug.print("Dragon Egg teleported to ({d}, {d}, {d})!\n", .{ tx, hit.y, tz });
                                    }
                                }

                                if (tier_ok) {
                                    if (broken_block == .chest or broken_block == .shulker_box) {
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
                                    if (broken_block == .nether_wart and !isWartTracked(warts[0..wart_count], hit.x, hit.y, hit.z)) {
                                        _ = inventory.addItem(.nether_wart, sapling_mod.wart_mature_bonus);
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
                    } else if (inventory.slots[selected_slot].item == .eye_of_ender and manager.getBlockWorld(hit.x, hit.y, hit.z) == .end_portal_frame) {
                        if (try manager.editAndRemesh(hit.x, hit.y, hit.z, .end_portal_frame_filled)) {
                            inventory.slots[selected_slot].decrement(1);
                            audio.play(.glowstone_chime, 0.95);
                            audio.play(.click_on, 0.8);
                            const fx: f32 = @as(f32, @floatFromInt(hit.x)) + 0.5;
                            const fy: f32 = @as(f32, @floatFromInt(hit.y)) + 0.8;
                            const fz: f32 = @as(f32, @floatFromInt(hit.z)) + 0.5;
                            particles.spawnPortalParticles(.{ fx, fy, fz }, 16);
                            particles.spawnGlowstoneShimmer(.{ fx, fy, fz }, 8);
                            std.debug.print("eye of ender inserted into portal frame at ({d},{d},{d})\n", .{ hit.x, hit.y, hit.z });

                            // Check if this insertion completes a 12-frame End Portal Altar!
                            if (portal_mod.detectEndPortalAltar(&pickBlockWorld, hit.x, hit.y, hit.z)) |altar| {
                                var filled_portal_count: usize = 0;
                                var dx: i32 = -1;
                                while (dx <= 1) : (dx += 1) {
                                    var dz: i32 = -1;
                                    while (dz <= 1) : (dz += 1) {
                                        if (try manager.editAndRemesh(altar.center_x + dx, altar.center_y, altar.center_z + dz, .end_portal)) {
                                            filled_portal_count += 1;
                                        }
                                    }
                                }
                                audio.play(.end_portal_open, 1.0);
                                const acx: f32 = @as(f32, @floatFromInt(altar.center_x)) + 0.5;
                                const acy: f32 = @as(f32, @floatFromInt(altar.center_y)) + 0.5;
                                const acz: f32 = @as(f32, @floatFromInt(altar.center_z)) + 0.5;
                                particles.spawnPortalParticles(.{ acx, acy, acz }, 48);
                                particles.spawnPortalVortex(.{ acx, acy, acz }, 1.5, 32, 0.0);
                                particles.spawnGlowstoneShimmer(.{ acx, acy, acz }, 24);
                                toast.timer = 3.0;
                                toast.color = .{ 0.82, 0.20, 0.96 };
                                std.debug.print("activated 3x3 End Portal altar at ({d},{d},{d})! (cells={d})\n", .{ altar.center_x, altar.center_y, altar.center_z, filled_portal_count });
                            }
                        }
                    } else if (inventory.slots[selected_slot].item != .bow and inventory.slots[selected_slot].item != .crossbow and !is_blocking) {
                        const px = hit.x + hit.nx;
                        const py = hit.y + hit.ny;
                        const pz = hit.z + hit.nz;
                        if (!pickSolid(px, py, pz)) {
                            var hotbar_slot = &inventory.slots[selected_slot];
                            if (hotbar_slot.item == .nether_wart) {
                                const soil = manager.getBlockWorld(hit.x, hit.y, hit.z);
                                if (sapling_mod.canPlantWart(soil, hit.ny)) {
                                    if (try manager.editAndRemesh(px, py, pz, .nether_wart)) {
                                        audio.play(.place_block, 0.7);
                                        hotbar_slot.decrement(1);
                                        if (wart_count < warts.len) {
                                            warts[wart_count] = .{ .x = px, .y = py, .z = pz, .t = 0.0 };
                                            wart_count += 1;
                                        }
                                        std.debug.print("planted nether wart\n", .{});
                                    }
                                }
                            } else if (hotbar_slot.item == .sapling) {
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
                            } else if (!hotbar_slot.isEmpty() and (hotbar_slot.item == .minecart or hotbar_slot.item == .tnt_minecart or hotbar_slot.item == .chest_minecart or hotbar_slot.item == .furnace_minecart or hotbar_slot.item == .hopper_minecart)) {
                                const target_block = manager.getBlockWorld(hit.x, hit.y, hit.z);
                                if (target_block.is_rail() or manager.getBlockWorld(px, py, pz).is_rail()) {
                                    const placed_cart = hotbar_slot.item;
                                    hotbar_slot.decrement(1);
                                    if (placed_cart == .tnt_minecart and fuse_count < fuses.len) {
                                        // TNT Minecart arms instant concussive kinetic fuse on track
                                        fuses[fuse_count] = .{ .x = hit.x, .y = hit.y, .z = hit.z, .t = 1.2 };
                                        fuse_count += 1;
                                        audio.play(.place_block, 0.9);
                                        particles.spawnFlame(hit.x, hit.y, hit.z, 8);
                                        std.debug.print("deployed TNT minecart: fuse armed!\n", .{});
                                    } else {
                                        player.in_minecart = true;
                                        audio.play(.click_on, 0.8);
                                        particles.spawnBlockDebris(hit.x, hit.y, hit.z, .{ 0.85, 0.85, 0.85 }, 8);
                                        std.debug.print("deployed and boarded {s} on rail\n", .{@tagName(placed_cart)});
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
                            } else if (!hotbar_slot.isEmpty() and hotbar_slot.item == .sea_pickle) {
                                // Plant Sea Pickle underwater on solid seafloor: emits luminous green light underwater
                                const below_b = manager.getBlockWorld(px, py - 1, pz);
                                const cur_b = manager.getBlockWorld(px, py, pz);
                                if (below_b.is_solid() and (cur_b == .water or pickFluid(px, py, pz) or cur_b == .air)) {
                                    if (try manager.editAndRemesh(px, py, pz, .sea_pickle)) {
                                        audio.play(.splash, 0.7);
                                        hotbar_slot.decrement(1);
                                        particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(px)) + 0.5, @as(f32, @floatFromInt(py)) + 0.5, @as(f32, @floatFromInt(pz)) + 0.5 }, 6);
                                        std.debug.print("planted bioluminescent sea pickle underwater\n", .{});
                                    }
                                }
                            } else if (!hotbar_slot.isEmpty() and hotbar_slot.item == .kelp) {
                                // Plant Kelp underwater on solid floor (sand, dirt, gravel, stone) or on existing kelp
                                const below_b = manager.getBlockWorld(px, py - 1, pz);
                                const cur_b = manager.getBlockWorld(px, py, pz);
                                if ((below_b.is_solid() or below_b == .kelp) and (cur_b == .water or pickFluid(px, py, pz) or cur_b == .air)) {
                                    if (try manager.editAndRemesh(px, py, pz, .kelp)) {
                                        audio.play(.splash, 0.7);
                                        hotbar_slot.decrement(1);
                                        std.debug.print("planted kelp frond underwater\n", .{});
                                    }
                                }
                            } else if (!hotbar_slot.isEmpty() and hotbar_slot.item == .twisting_vines) {
                                const below_b = manager.getBlockWorld(px, py - 1, pz);
                                if (below_b.is_solid() or below_b == .twisting_vines) {
                                    if (try manager.editAndRemesh(px, py, pz, .twisting_vines)) {
                                        audio.play(.place_block, 0.7);
                                        hotbar_slot.decrement(1);
                                        std.debug.print("planted twisting vines\n", .{});
                                    }
                                }
                            } else if (!hotbar_slot.isEmpty() and (hotbar_slot.item == .crimson_fungus or hotbar_slot.item == .warped_fungus)) {
                                const below_b = manager.getBlockWorld(px, py - 1, pz);
                                // Fungi plant on solid floors (netherrack, soul sand, dirt, grass)
                                if (below_b.is_solid()) {
                                    const fungus_block = hotbar_slot.item.toBlockId().?;
                                    if (try manager.editAndRemesh(px, py, pz, fungus_block)) {
                                        audio.play(.place_block, 0.7);
                                        hotbar_slot.decrement(1);
                                        std.debug.print("planted {s}\n", .{ @tagName(fungus_block) });
                                    }
                                }
                            } else if (!hotbar_slot.isEmpty() and hotbar_slot.item == .weeping_vines) {
                                const above_b = manager.getBlockWorld(px, py + 1, pz);
                                if (above_b.is_solid() or above_b == .weeping_vines) {
                                    if (try manager.editAndRemesh(px, py, pz, .weeping_vines)) {
                                        audio.play(.place_block, 0.7);
                                        hotbar_slot.decrement(1);
                                        std.debug.print("hung weeping vines\n", .{});
                                    }
                                }
                            } else if (!hotbar_slot.isEmpty() and hotbar_slot.item == .target_dummy) {
                                const dx: f32 = @as(f32, @floatFromInt(px)) + 0.5;
                                const dy: f32 = @as(f32, @floatFromInt(py));
                                const dz: f32 = @as(f32, @floatFromInt(pz)) + 0.5;
                                try mob_manager.spawnMob(.target_dummy, dx, dy, dz);
                                hotbar_slot.decrement(1);
                                audio.play(.place_block, 0.8);
                                particles.spawnBlockDebris(px, py, pz, .{ 0.90, 0.80, 0.35 }, 8);
                                std.debug.print("placed target dummy at ({d},{d},{d})\n", .{ px, py, pz });
                            } else if (!hotbar_slot.isEmpty() and hotbar_slot.item == .fire_charge and manager.getBlockWorld(hit.x, hit.y, hit.z) == .tnt and fuse_count < fuses.len) {
                                fuses[fuse_count] = .{ .x = hit.x, .y = hit.y, .z = hit.z, .t = 2.5 };
                                fuse_count += 1;
                                hotbar_slot.decrement(1);
                                audio.play(.place_block, 0.8);
                                particles.spawnFlame(hit.x, hit.y, hit.z, 6);
                                std.debug.print("fire charge lit TNT fuse\n", .{});
                            } else if (!hotbar_slot.isEmpty()) {
                                if (hotbar_slot.item.toBlockId()) |place_type| {
                                    if (((place_type == .lantern or place_type == .soul_lantern) and !block_mod.canSupportLantern(&pickBlockWorld, px, py, pz)) or (place_type == .end_rod and !block_mod.canSupportEndRod(&pickBlockWorld, px, py, pz)) or ((place_type == .chorus_plant or place_type == .chorus_flower) and !block_mod.canSupportChorusPlant(&pickBlockWorld, px, py, pz))) {
                                        // Lantern requires solid floor or ceiling support
                                    } else {
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
                                        if ((place_type == .torch or place_type == .soul_torch) and cache_mod.canCreateTorch(torch_count, torches.len)) {
                                            torches[torch_count] = .{ .x = px, .y = py, .z = pz };
                                            torch_count += 1;
                                        }
                                        if (place_type == .chest and cache_mod.canCreateChest(chest_count, chests.len)) {
                                            chests[chest_count] = .{ .x = px, .y = py, .z = pz, .items = [_]inventory_mod.ItemStack{.{}} ** 4 };
                                            chest_count += 1;
                                        }
                                        if (place_type == .brewing_stand and brewing_stand_count < brewing_stands.len) {
                                            brewing_stands[brewing_stand_count] = .{ .x = px, .y = py, .z = pz };
                                            brewing_stand_count += 1;
                                        }
                                        if (place_type == .cauldron and cauldron_count < cauldrons.len) {
                                            cauldrons[cauldron_count] = .{ .x = px, .y = py, .z = pz };
                                            cauldron_count += 1;
                                        }
                                        if (place_type == .note_block and note_block_count < note_blocks.len) {
                                            note_blocks[note_block_count] = .{ .x = px, .y = py, .z = pz, .pitch = 0 };
                                            note_block_count += 1;
                                        }
                                        if (place_type == .jukebox and jukebox_count < jukeboxes.len) {
                                            jukeboxes[jukebox_count] = .{ .x = px, .y = py, .z = pz };
                                            jukebox_count += 1;
                                        }
                                        if (place_type == .armor_stand and armor_stand_count < armor_stands.len) {
                                            armor_stands[armor_stand_count] = .{ .x = px, .y = py, .z = pz };
                                            armor_stand_count += 1;
                                        }
                                        if (place_type == .enchantment_table and enchantment_table_count < enchantment_tables.len) {
                                            enchantment_tables[enchantment_table_count] = .{ .x = px, .y = py, .z = pz };
                                            enchantment_table_count += 1;
                                        }
                                        if (place_type == .anvil and anvil_count < anvils.len) {
                                            anvils[anvil_count] = .{ .x = px, .y = py, .z = pz };
                                            anvil_count += 1;
                                        }
                                        if (place_type == .grindstone and grindstone_count < grindstones.len) {
                                            grindstones[grindstone_count] = .{ .x = px, .y = py, .z = pz };
                                            grindstone_count += 1;
                                        }
                                        if (place_type == .smithing_table and smithing_table_count < smithing_tables.len) {
                                            smithing_tables[smithing_table_count] = .{ .x = px, .y = py, .z = pz };
                                            smithing_table_count += 1;
                                        }
                                        if (place_type == .cartography_table and cartography_table_count < cartography_tables.len) {
                                            cartography_tables[cartography_table_count] = .{ .x = px, .y = py, .z = pz };
                                            cartography_table_count += 1;
                                        }
                                        if (place_type == .fletching_table and fletching_table_count < fletching_tables.len) {
                                            fletching_tables[fletching_table_count] = .{ .x = px, .y = py, .z = pz };
                                            fletching_table_count += 1;
                                        }
                                        if (place_type == .composter and composter_count < composters.len) {
                                            composters[composter_count] = .{ .x = px, .y = py, .z = pz };
                                            composter_count += 1;
                                        }
                                        if (place_type == .loom and loom_count < looms.len) {
                                            looms[loom_count] = .{ .x = px, .y = py, .z = pz };
                                            loom_count += 1;
                                        }
                                        if (place_type == .stonecutter and stonecutter_count < stonecutters.len) {
                                            stonecutters[stonecutter_count] = .{ .x = px, .y = py, .z = pz };
                                            stonecutter_count += 1;
                                        }
                                        if (place_type == .spawner_cage and spawner_count < spawners.len) {
                                            spawners[spawner_count] = .{ .x = px, .y = py, .z = pz };
                                            spawner_count += 1;
                                        }
                                        if (place_type == .beacon and beacon_count < beacons.len) {
                                            beacons[beacon_count] = .{ .x = px, .y = py, .z = pz };
                                            beacon_count += 1;
                                        }
                                        if (place_type.is_campfire() and campfire_count < campfires.len) {
                                            campfires[campfire_count] = .{ .x = px, .y = py, .z = pz, .is_soul = (place_type == .soul_campfire) };
                                            campfire_count += 1;
                                        }
                                        if (place_type == .end_rod and end_rod_count < end_rods.len) {
                                            end_rods[end_rod_count] = .{ .x = px, .y = py, .z = pz };
                                            end_rod_count += 1;
                                        }
                                        if (place_type == .conduit and conduit_count < conduits.len) {
                                            conduits[conduit_count] = .{ .x = px, .y = py, .z = pz };
                                            conduit_count += 1;
                                        }
                                        if (place_type == .sponge) {
                                            var absorbed: usize = 0;
                                            var sx: i32 = -3;
                                            while (sx <= 3) : (sx += 1) {
                                                var sy: i32 = -3;
                                                while (sy <= 3) : (sy += 1) {
                                                    var sz: i32 = -3;
                                                    while (sz <= 3) : (sz += 1) {
                                                        if (sx == 0 and sy == 0 and sz == 0) continue;
                                                        if (sx * sx + sy * sy + sz * sz <= 9) {
                                                            const wx = px + sx;
                                                            const wy = py + sy;
                                                            const wz = pz + sz;
                                                            if (manager.getBlockWorld(wx, wy, wz) == .water) {
                                                                _ = try manager.editAndRemesh(wx, wy, wz, .air);
                                                                absorbed += 1;
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            if (absorbed > 0) {
                                                _ = try manager.editAndRemesh(px, py, pz, .wet_sponge);
                                                audio.play(.splash, 0.85);
                                                particles.spawnWaterSplash(.{ @as(f32, @floatFromInt(px)) + 0.5, @as(f32, @floatFromInt(py)) + 0.5, @as(f32, @floatFromInt(pz)) + 0.5 }, 24);
                                                std.debug.print("sponge absorbed {d} water blocks into wet sponge!\n", .{absorbed});
                                            }
                                        }
                                        // Wither summon: completed skull-T consumes the pattern
                                        // and raises an empowered wither champion (30 HP).
                                        // ponytail: dedicated boss mob type + ranged skull attack
                                        // when the mob roster grows past shared-type buffs.
                                        if (place_type == .wither_skull_block) {
                                            if (summon_mod.detectWitherPattern(&pickBlockWorld, px, py, pz)) |site| {
                                                const cells = if (site.axis == .x_axis)
                                                    [_][3]i32{ .{ -1, 0, 0 }, .{ 0, 0, 0 }, .{ 1, 0, 0 }, .{ -1, 1, 0 }, .{ 0, 1, 0 }, .{ 1, 1, 0 }, .{ 0, -1, 0 } }
                                                else
                                                    [_][3]i32{ .{ 0, 0, -1 }, .{ 0, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 1, -1 }, .{ 0, 1, 0 }, .{ 0, 1, 1 }, .{ 0, -1, 0 } };
                                                for (cells) |cell| {
                                                    _ = try manager.editAndRemesh(site.base_x + cell[0], site.base_y + cell[1], site.base_z + cell[2], .air);
                                                }
                                                mob_manager.spawnMob(.wither_skeleton, @as(f32, @floatFromInt(site.base_x)) + 0.5, @as(f32, @floatFromInt(site.base_y)) + 1.0, @as(f32, @floatFromInt(site.base_z)) + 0.5) catch {};
                                                if (mob_manager.mobs.items.len > 0) {
                                                    mob_manager.mobs.items[mob_manager.mobs.items.len - 1].health = 30;
                                                    mob_manager.mobs.items[mob_manager.mobs.items.len - 1].is_champion = true;
                                                }
                                                audio.playAt(.mob_roar, .{ @as(f32, @floatFromInt(site.base_x)) + 0.5, @as(f32, @floatFromInt(site.base_y)) + 1.0, @as(f32, @floatFromInt(site.base_z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 40.0);
                                                particles.spawnFlame(site.base_x, site.base_y + 1, site.base_z, 24);
                                                std.debug.print("wither champion summoned at ({d},{d},{d})\n", .{ site.base_x, site.base_y, site.base_z });
                                            }
                                        }
                                        if (is_furnace_place and cache_mod.canCreateFurnace(furnace_count, furnaces.len)) {
                                            furnaces[furnace_count] = .{ .x = px, .y = py, .z = pz, .t = 0, .fuel = 0, .input = smelt_mod.None };
                                            furnace_count += 1;
                                        }
                                        if (place_type == .smoker and cache_mod.canCreateFurnace(smoker_count, smokers.len)) {
                                            smokers[smoker_count] = .{ .x = px, .y = py, .z = pz, .t = 0, .fuel = 0, .input = smelt_mod.None };
                                            smoker_count += 1;
                                        }
                                        if (place_type == .blast_furnace and cache_mod.canCreateFurnace(blast_furnace_count, blast_furnaces.len)) {
                                            blast_furnaces[blast_furnace_count] = .{ .x = px, .y = py, .z = pz, .t = 0, .fuel = 0, .input = smelt_mod.None };
                                            blast_furnace_count += 1;
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
            }
        }
        if (!left) {
            mine.reset();
        }
        // Sleep on wool block at night: aim at wool + press B sets spawn, skips to dawn
        bed_cooldown = interact_mod.tickCooldown(bed_cooldown, dt);
        compass_cooldown = interact_mod.tickCooldown(compass_cooldown, dt);
        const sun_y_now = @sin(world_time);
        if (!inventory_open and (manager.is_nether or player.lodestone_target != null or inventory.hasItem(.compass) or inventory.hasItem(.lodestone_compass)) and c.glfwGetKey(window, c.GLFW_KEY_C) == c.GLFW_PRESS and interact_mod.ready(compass_cooldown)) {
            if (player.lodestone_target) |lt| {
                const dx = lt.x - player.pos.x;
                const dz = lt.z - player.pos.z;
                const dist = @sqrt(dx * dx + dz * dz);
                audio.play(.glowstone_chime, 0.6);
                std.debug.print("lodestone compass: target ({d:.0},{d:.0},{d:.0}) {d:.0}m\n", .{ lt.x, lt.y, lt.z, dist });
            } else if (manager.is_nether) {
                if (inventory.hasItem(.compass)) {
                    audio.play(.click_on, 0.6);
                    std.debug.print("compass: spinning erratically in nether\n", .{});
                } else {
                    const j = spawn_mod.nearestJunction(player.pos.x, player.pos.z);
                    audio.play(.click_on, 0.5);
                    std.debug.print("fortress compass: junction ({d},{d}) {d:.0}m\n", .{ j.jx, j.jz, j.dist });
                }
            } else if (inventory.hasItem(.compass)) {
                const dist = @sqrt(player.pos.x * player.pos.x + player.pos.z * player.pos.z);
                audio.play(.click_on, 0.5);
                std.debug.print("compass: pointing to world spawn (0,0) {d:.0}m\n", .{dist});
            }
            compass_cooldown = 1.0;
        }
        if (!inventory_open and interact_mod.ready(bed_cooldown) and c.glfwGetKey(window, c.GLFW_KEY_B) == c.GLFW_PRESS) {
            const dir_b = cam.front();
            if (pick_mod.raycast(&pickSolid, cam.position, dir_b, 5)) |hit_b| {
                if (manager.getBlockWorld(hit_b.x, hit_b.y, hit_b.z) == .wool) {
                    const sleep_res = sky_mod.trySleep(sun_y_now, world_time, player.health);
                    if (sleep_res.slept) {
                        world_time = sleep_res.new_world_time;
                        player.spawn_point = player.pos;
                        player.health = sleep_res.new_health;
                        player.resetInsomnia();
                        audio.play(.craft_item, 0.7);
                        std.debug.print("slept; spawn set\n", .{});
                    } else {
                        std.debug.print("sleep only at night\n", .{});
                    }
                    bed_cooldown = interact_mod.bed_cooldown;
                }
            }
        }
        // Smoker tick: high-speed food smoking (5s per item) and aromatic chimney smoke plume
        {
            var smk_i: usize = 0;
            while (smk_i < smoker_count) {
                const s = &smokers[smk_i];
                if (manager.getBlockWorld(s.x, s.y, s.z) != .smoker) {
                    cache_mod.swapRemove(&smokers, &smoker_count, smk_i);
                    continue;
                }
                const outcome = smelt_mod.tickSmokerJob(&s.t, &s.fuel, &s.input, dt);
                if (s.fuel > 0 and s.input != smelt_mod.None) {
                    // Ascending smoke plume particles from chimney vent top
                    particles.spawnCampfireSmoke(s.x, s.y, s.z, false, false, 2);
                }
                if (outcome.done_item) |done_tag| {
                    const done: inventory_mod.ItemType = @enumFromInt(done_tag);
                    _ = inventory.addItem(done, 1);
                    audio.play(.craft_item, 0.8);
                    particles.spawnFlame(s.x, s.y + 1, s.z, 4);
                    std.debug.print("smoked food: {s}\n", .{done.name()});
                }
                smk_i += 1;
            }
        }

        // Blast Furnace tick: high-speed ore smelting (5s per item) and fiery spark burst
        {
            var bfi: usize = 0;
            while (bfi < blast_furnace_count) {
                const bf = &blast_furnaces[bfi];
                if (manager.getBlockWorld(bf.x, bf.y, bf.z) != .blast_furnace) {
                    cache_mod.swapRemove(&blast_furnaces, &blast_furnace_count, bfi);
                    continue;
                }
                const outcome = smelt_mod.tickBlastFurnaceJob(&bf.t, &bf.fuel, &bf.input, dt);
                if (bf.fuel > 0 and bf.input != smelt_mod.None) {
                    // Fiery sparks spraying from blast smelting chamber
                    particles.spawnBurnSparks(.{ @as(f32, @floatFromInt(bf.x)) + 0.5, @as(f32, @floatFromInt(bf.y)) + 0.9, @as(f32, @floatFromInt(bf.z)) + 0.5 }, 3);
                }
                if (outcome.done_item) |done_tag| {
                    const done: inventory_mod.ItemType = @enumFromInt(done_tag);
                    _ = inventory.addItem(done, 1);
                    audio.play(.craft_item, 0.8);
                    particles.spawnFlame(bf.x, bf.y + 1, bf.z, 4);
                    std.debug.print("blast smelted ore: {s}\n", .{done.name()});
                }
                bfi += 1;
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
                                const f_block = fch.blocks[fy][fz][fx];
                                if (!f_block.is_falling()) continue;
                                if (fch.blocks[fy - 1][fz][fx] != .air) continue;
                                const wx: i32 = fcx * 16 + @as(i32, @intCast(fx));
                                const wy: i32 = @as(i32, @intCast(fy));
                                const wz: i32 = fcz * 16 + @as(i32, @intCast(fz));
                                if (falling_mod.findFalling(&fallings, falling_count, wx, wy, wz) == null and falling_count < fallings.len) {
                                    fallings[falling_count] = .{ .x = wx, .y = wy, .z = wz, .t = 0.0, .dist = 0, .block_type = f_block };
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
                if (manager.getBlockWorld(f.x, f.y, f.z) != f.block_type) {
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
                            _ = try manager.editAndRemesh(f.x, f.y - 1, f.z, f.block_type);
                            _ = try manager.editAndRemesh(f.x, f.y, f.z, .air);
                            f.y -= 1;
                            f.dist += 1;
                        },
                        .splash_into_water => {
                            _ = try manager.editAndRemesh(f.x, f.y - 1, f.z, f.block_type);
                            _ = try manager.editAndRemesh(f.x, f.y, f.z, .air);
                            f.y -= 1;
                            f.dist += 1;
                            particles.spawnWaterSplash(.{ @as(f32, @floatFromInt(f.x)) + 0.5, @as(f32, @floatFromInt(f.y)), @as(f32, @floatFromInt(f.z)) + 0.5 }, 12);
                            if (f.block_type == .anvil) {
                                audio.playAt(.anvil_clang, .{ @as(f32, @floatFromInt(f.x)) + 0.5, @as(f32, @floatFromInt(f.y)), @as(f32, @floatFromInt(f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 30.0);
                            }
                        },
                        .crush_non_solid => {
                            _ = try manager.editAndRemesh(f.x, f.y - 1, f.z, f.block_type);
                            _ = try manager.editAndRemesh(f.x, f.y, f.z, .air);
                            f.y -= 1;
                            f.dist += 1;
                            particles.spawnBlockDebris(f.x, f.y, f.z, .{ 0.8, 0.7, 0.5 }, 4);
                        },
                        .land, .none => {
                            const dmg: u8 = if (f.block_type == .anvil) falling_mod.calculateAnvilImpactDamage(f.dist) else falling_mod.calculateImpactDamage(f.dist);
                            if (f.block_type == .anvil and f.dist > 0) {
                                audio.playAt(.anvil_clang, .{ @as(f32, @floatFromInt(f.x)) + 0.5, @as(f32, @floatFromInt(f.y)) + 0.5, @as(f32, @floatFromInt(f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 40.0);
                                particles.spawnBlockDebris(f.x, f.y, f.z, .{ 0.5, 0.5, 0.55 }, 8);
                            }
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
                if (cur_tb != .torch and cur_tb != .soul_torch) {
                    cache_mod.swapRemove(&torches, &torch_count, ti);
                    continue;
                }
                if (cache_mod.isWithinFlameDist(tr.x, tr.z, player.pos.x, player.pos.z)) {
                    particles.spawnFlame(tr.x, tr.y, tr.z, 1);
                }
                ti += 1;
            }
            // Spawner cage embers: active cages within 16m emit spinning flames
            var si2: usize = 0;
            while (si2 < spawner_count) {
                const sp = &spawners[si2];
                const cur_sb = manager.getBlockWorld(sp.x, sp.y, sp.z);
                if (cur_sb != .spawner_cage) {
                    spawners[si2] = spawners[spawner_count - 1];
                    spawner_count -= 1;
                    continue;
                }
                if (spawn_mod.isSpawnerActive(sp.x, sp.z, player.pos.x, player.pos.z)) {
                    particles.spawnSpawnerFlames(sp.x, sp.y, sp.z, 2);
                }
                si2 += 1;
            }
            // Beacon sky beam & regeneration aura: active beacons with clear sky above
            var bi2: usize = 0;
            while (bi2 < beacon_count) {
                const bc = &beacons[bi2];
                const cur_bb = manager.getBlockWorld(bc.x, bc.y, bc.z);
                if (cur_bb != .beacon) {
                    beacons[bi2] = beacons[beacon_count - 1];
                    beacon_count -= 1;
                    continue;
                }
                if (block_mod.isBeaconSkyClear(&pickBlockWorld, bc.x, bc.y, bc.z)) {
                    particles.spawnBeaconBeam(bc.x, bc.y, bc.z, 2);
                    const bdx = @as(f32, @floatFromInt(bc.x)) + 0.5 - player.pos.x;
                    const bdz = @as(f32, @floatFromInt(bc.z)) + 0.5 - player.pos.z;
                    const bdy = @as(f32, @floatFromInt(bc.y)) - player.pos.y;
                    const bdist_sq = bdx * bdx + bdz * bdz + bdy * bdy;
                    if (bdist_sq <= 24.0 * 24.0) {
                        player.regen_timer = @max(player.regen_timer, 3.0);
                    }
                }
                bi2 += 1;
            }
            // Campfire smoke & signal fire emission
            var cfi: usize = 0;
            while (cfi < campfire_count) {
                const cf = &campfires[cfi];
                const cur_cb = manager.getBlockWorld(cf.x, cf.y, cf.z);
                if (!cur_cb.is_campfire()) {
                    campfires[cfi] = campfires[campfire_count - 1];
                    campfire_count -= 1;
                    continue;
                }
                const cdx = @as(f32, @floatFromInt(cf.x)) + 0.5 - player.pos.x;
                const cdz = @as(f32, @floatFromInt(cf.z)) + 0.5 - player.pos.z;
                if (cdx * cdx + cdz * cdz <= 32.0 * 32.0) {
                    const block_below = manager.getBlockWorld(cf.x, cf.y - 1, cf.z);
                    const is_signal = block_below.is_hay_bale();
                    particles.spawnCampfireSmoke(cf.x, cf.y, cf.z, cf.is_soul, is_signal, 1);
                }
                cfi += 1;
            }
            // End rod radiant white light sparkle emission
            var eri: usize = 0;
            while (eri < end_rod_count) {
                const er = &end_rods[eri];
                const cur_eb = manager.getBlockWorld(er.x, er.y, er.z);
                if (cur_eb != .end_rod) {
                    end_rods[eri] = end_rods[end_rod_count - 1];
                    end_rod_count -= 1;
                    continue;
                }
                const edx = @as(f32, @floatFromInt(er.x)) + 0.5 - player.pos.x;
                const edz = @as(f32, @floatFromInt(er.z)) + 0.5 - player.pos.z;
                if (edx * edx + edz * edz <= 32.0 * 32.0) {
                    particles.spawnEndRodSparks(er.x, er.y, er.z, 1);
                }
                eri += 1;
            }
            // Oceanic Conduit Power field: emit pulsing cyan vortex particles & refresh water breathing
            var ci: usize = 0;
            while (ci < conduit_count) {
                const c_block = &conduits[ci];
                const cur_cb = manager.getBlockWorld(c_block.x, c_block.y, c_block.z);
                if (cur_cb != .conduit) {
                    conduits[ci] = conduits[conduit_count - 1];
                    conduit_count -= 1;
                    continue;
                }
                const cdx = @as(f32, @floatFromInt(c_block.x)) + 0.5 - player.pos.x;
                const cdy = @as(f32, @floatFromInt(c_block.y)) + 0.5 - player.pos.y;
                const cdz = @as(f32, @floatFromInt(c_block.z)) + 0.5 - player.pos.z;
                const dist_sq = cdx * cdx + cdy * cdy + cdz * cdz;
                if (dist_sq <= 32.0 * 32.0) {
                    // Pulse cyan oceanic vortex particles around conduit core
                    particles.spawnPortalVortex(.{ @as(f32, @floatFromInt(c_block.x)) + 0.5, @as(f32, @floatFromInt(c_block.y)) + 0.5, @as(f32, @floatFromInt(c_block.z)) + 0.5 }, 1.2, 2, 0.0);
                    // Conduit Power aura: restores player oxygen & refreshes water breathing timer
                    player.water_breathing_timer = @max(player.water_breathing_timer, 15.0);
                    player.oxygen = 15.0;
                }
                ci += 1;
            }
        }

                    // Elder Guardian Mining Fatigue curse & monument aura within 24m
            const monument_dist_x = player.pos.x - 0.0;
            const monument_dist_z = player.pos.z - (-16.0);
            const monument_dist_sq = monument_dist_x * monument_dist_x + monument_dist_z * monument_dist_z;
            if (monument_dist_sq <= 24.0 * 24.0 and !manager.is_nether and !manager.is_end) {
                var eg_found = false;
                for (mob_manager.mobs.items) |m| {
                    if (m.mob_type == .elder_guardian and m.health > 0) {
                        eg_found = true;
                        break;
                    }
                }
                // If player enters monument sanctuary and no Elder Guardian exists, spawn one in the apex vault
                if (!eg_found and mob_manager.mobs.items.len < 8) {
                    mob_manager.spawnMob(.elder_guardian, 0.5, 6.0, -15.5) catch {};
                    audio.play(.mob_roar, 1.0);
                    std.debug.print("Elder Guardian boss awakened at Ocean Monument apex!\n", .{});
                }
                if (!player.hasMiningFatigue()) {
                    player.applyMiningFatigue();
                    audio.play(.mob_roar, 0.9);
                    toast.timer = 3.0;
                    toast.color = .{ 0.85, 0.70, 0.20 };
                    std.debug.print("Elder Guardian afflicted player with Mining Fatigue!\n", .{});
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
                if (dead and t.kind == .trident) {
                    particles.spawnWaterSplash(.{ t.pos.x, t.pos.y, t.pos.z }, 8);
                    audio.playAt(.splash, .{ t.pos.x, t.pos.y, t.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.6, 25.0);
                    _ = inventory.addItem(.trident, 1);
                    std.debug.print("thrown trident flight completed and recovered\n", .{});
                }
                if (dead and t.kind == .eye_of_ender) {
                    const seed_roll: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(t.pos.x * 13.0 + t.pos.z * 29.0))));
                    if (inventory_mod.dropsEyeShatter(seed_roll)) {
                        particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 20);
                        audio.playAt(.break_block, .{ t.pos.x, t.pos.y, t.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                        std.debug.print("eye of ender shattered into mystic dust\n", .{});
                    } else {
                        particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 8);
                        audio.playAt(.glowstone_chime, .{ t.pos.x, t.pos.y, t.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.6, 25.0);
                        _ = inventory.addItem(.eye_of_ender, 1);
                        std.debug.print("eye of ender completed trajectory and recovered\n", .{});
                    }
                }
                if (dead and t.kind == .firework_rocket) {
                    // Firework fuse expired in flight -> blast!
                    particles.spawnFireworkBurst(.{ t.pos.x, t.pos.y, t.pos.z }, 32);
                    audio.playAt(.firework_blast, .{ t.pos.x, t.pos.y, t.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 35.0);
                    // Area of effect damage to nearby mobs
                    for (mob_manager.mobs.items) |*m| {
                        const mdx = m.pos.x - t.pos.x;
                        const mdy = m.pos.y - t.pos.y;
                        const mdz = m.pos.z - t.pos.z;
                        if (mdx * mdx + mdy * mdy + mdz * mdz <= proj_mod.firework_explosion_radius * proj_mod.firework_explosion_radius) {
                            m.health = if (m.health > proj_mod.firework_explosion_damage) m.health - proj_mod.firework_explosion_damage else 0;
                            audio.play(.hurt, 0.6);
                        }
                    }
                    std.debug.print("firework rocket airburst exploded\n", .{});
                }
                if (!dead) {
                    if (t.kind == .shulker_bullet) {
                        // Shulker bullet strikes player: 4 damage, inflicts levitation debuff, creates white spark burst
                        const pdx = player.pos.x - t.pos.x;
                        const pdy = (player.pos.y + 1.0) - t.pos.y;
                        const pdz = player.pos.z - t.pos.z;
                        if (pdx * pdx + pdy * pdy + pdz * pdz < 1.2) {
                            const cf = cam.front();
                            const blocked = is_blocking and combat_mod.canBlockAttack(cf.x, cf.z, -pdx, -pdz);
                            if (blocked) {
                                audio.play(.shield_block, 0.9);
                                particles.spawnBlockDebris(@intFromFloat(@floor(player.pos.x + cf.x * 0.6)), @intFromFloat(@floor(player.pos.y + 0.8)), @intFromFloat(@floor(player.pos.z + cf.z * 0.6)), .{ 0.85, 0.85, 0.85 }, 8);
                            } else {
                                const has_chestplate = inventory.hasItem(.netherite_chestplate);
                                const has_full = inventory.hasFullNetheriteSet();
                                const bullet_dmg = combat_mod.applyArmorReductionAllTiers(4.0, has_chestplate, has_full, inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet());
                                player.health = @max(0.0, player.health - bullet_dmg);
                                player.applyLevitation();
                                audio.play(.hurt, 0.8);
                                particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 16);
                                std.debug.print("shulker bullet hit player: 4 dmg + levitation! (hp={d:.1})\n", .{player.health});
                            }
                            dead = true;
                        } else if (pickSolid(mbx, mby, mbz)) {
                            particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 12);
                            dead = true;
                        }
                    } else if (t.kind == .hostile_arrow) {
                        // Skeleton hostile arrow vs player: deals 2 damage on impact, blocked by shield
                        const pdx = player.pos.x - t.pos.x;
                        const pdy = (player.pos.y + 1.0) - t.pos.y;
                        const pdz = player.pos.z - t.pos.z;
                        if (pdx * pdx + pdy * pdy + pdz * pdz < 1.0) {
                            const cf = cam.front();
                            const blocked = is_blocking and combat_mod.canBlockAttack(cf.x, cf.z, -pdx, -pdz);
                            if (blocked) {
                                audio.play(.shield_block, 0.9);
                                particles.spawnBlockDebris(@intFromFloat(@floor(player.pos.x + cf.x * 0.6)), @intFromFloat(@floor(player.pos.y + 0.8)), @intFromFloat(@floor(player.pos.z + cf.z * 0.6)), .{ 0.85, 0.85, 0.85 }, 8);
                                if (tool_wear.use(selected_slot, inventory_mod.ItemType.shield.maxDurability())) {
                                    inventory.slots[selected_slot].clear();
                                    audio.play(.break_block, 0.8);
                                    std.debug.print("shield broke\n", .{});
                                }
                                std.debug.print("shield blocked skeleton arrow\n", .{});
                            } else {
                                const arrow_dmg = combat_mod.applyArmorReductionAllTiers(2.0, inventory.hasItem(.netherite_chestplate), inventory.hasFullNetheriteSet(), inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet());
                                player.health = @max(0.0, player.health - arrow_dmg);
                                audio.play(.hurt, 0.8);
                                particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.85, 0.20, 0.20 }, 8);
                                std.debug.print("skeleton arrow struck player (hp={d:.1})\n", .{player.health});
                            }
                            dead = true;
                        } else if (pickSolid(mbx, mby, mbz)) {
                            particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.85, 0.85, 0.85 }, 3);
                            audio.playAt(.step_wood, .{ t.pos.x, t.pos.y, t.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.6, 20.0);
                            dead = true;
                        }
                    } else if (t.kind == .shulker_bullet) {
                        particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 1);
                    } else if (t.kind == .hostile_arrow) {
                        particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.85, 0.85, 0.85 }, 1);
                    } else if (t.kind == .eye_of_ender) {
                        particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 2);
                        particles.spawnGlowstoneShimmer(.{ t.pos.x, t.pos.y, t.pos.z }, 1);
                    } else if (t.kind == .ender_pearl) {
                        particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 2);
                    } else if (t.kind == .hostile_fireball) {
                        // Fireball vs player: 3 dmg on close pass, flame burst on block
                        const pdx = player.pos.x - t.pos.x;
                        const pdy = (player.pos.y + 1.0) - t.pos.y;
                        const pdz = player.pos.z - t.pos.z;
                        if (pdx * pdx + pdy * pdy + pdz * pdz < 1.0) {
                            const cf = cam.front();
                            const blocked = is_blocking and combat_mod.canBlockAttack(cf.x, cf.z, -pdx, -pdz);
                            if (blocked) {
                                audio.play(.shield_block, 0.9);
                                particles.spawnBurnSparks(.{ player.pos.x + cf.x * 0.6, player.pos.y + 0.8, player.pos.z + cf.z * 0.6 }, 10);
                                if (tool_wear.use(selected_slot, inventory_mod.ItemType.shield.maxDurability())) {
                                    inventory.slots[selected_slot].clear();
                                    audio.play(.break_block, 0.8);
                                    std.debug.print("shield broke\n", .{});
                                }
                                std.debug.print("shield blocked fireball\n", .{});
                            } else {
                                const resist = player.fire_resistance_timer > 0.0;
                                if (!resist) {
                                    player.health = @max(0.0, player.health - combat_mod.applyArmorReductionAllTiers(proj_mod.fireball_damage, inventory.hasItem(.netherite_chestplate), inventory.hasFullNetheriteSet(), inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet()));
                                    audio.play(.hurt, 0.8);
                                    std.debug.print("fireball hit (hp={d:.1})\n", .{player.health});
                                } else {
                                    std.debug.print("fireball resisted\n", .{});
                                }
                                particles.spawnFlame(mbx, mby, mbz, 8);
                            }
                            dead = true;
                        } else if (pickSolid(mbx, mby, mbz)) {
                            // Ignite flammable floors: set struck cell's air above ablaze as campfire or soul campfire.
                            const struck = manager.getBlockWorld(mbx, mby, mbz);
                            if (hazard_mod.isFlammable(struck) and manager.getBlockWorld(mbx, mby + 1, mbz) == .air) {
                                const flame_block = hazard_mod.ignitedFlameBlock(struck);
                                if (try manager.editAndRemesh(mbx, mby + 1, mbz, flame_block)) {
                                    if (flame_count < flames.len) {
                                        flames[flame_count] = .{ .x = mbx, .y = mby + 1, .z = mbz, .t = 0.0 };
                                        flame_count += 1;
                                    }
                                    if (campfire_count < campfires.len) {
                                        campfires[campfire_count] = .{ .x = mbx, .y = mby + 1, .z = mbz, .is_soul = (flame_block == .soul_campfire) };
                                        campfire_count += 1;
                                    }
                                    std.debug.print("fireball ignited flame\n", .{});
                                }
                            }
                            if (struck == .target_block) {
                                const sig_str = redstone_mod.targetSignalStrength(t.pos.x, t.pos.y, t.pos.z, mbx, mby, mbz);
                                var found_tp = false;
                                for (target_pulses[0..target_pulse_count]) |*tp| {
                                    if (tp.x == mbx and tp.y == mby and tp.z == mbz) {
                                        tp.t = redstone_mod.target_pulse_duration;
                                        tp.strength = sig_str;
                                        found_tp = true;
                                        break;
                                    }
                                }
                                if (!found_tp and target_pulse_count < target_pulses.len) {
                                    target_pulses[target_pulse_count] = .{ .x = mbx, .y = mby, .z = mbz, .t = redstone_mod.target_pulse_duration, .strength = sig_str };
                                    target_pulse_count += 1;
                                }
                                audio.play(.click_on, 0.8);
                            }
                            particles.spawnFlame(mbx, mby, mbz, 8);
                            audio.play(.burn_sizzle, 0.4);
                            dead = true;
                        }
                    }
                    if (!dead and t.kind != .hostile_fireball and t.kind != .hostile_arrow and pickSolid(mbx, mby, mbz)) {
                        if (t.kind == .firework_rocket) {
                            particles.spawnFireworkBurst(.{ t.pos.x, t.pos.y, t.pos.z }, 32);
                            audio.playAt(.firework_blast, .{ t.pos.x, t.pos.y, t.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 35.0);
                            for (mob_manager.mobs.items) |*m| {
                                const mdx = m.pos.x - t.pos.x;
                                const mdy = m.pos.y - t.pos.y;
                                const mdz = m.pos.z - t.pos.z;
                                if (mdx * mdx + mdy * mdy + mdz * mdz <= proj_mod.firework_explosion_radius * proj_mod.firework_explosion_radius) {
                                    m.health = if (m.health > proj_mod.firework_explosion_damage) m.health - proj_mod.firework_explosion_damage else 0;
                                    audio.play(.hurt, 0.6);
                                }
                            }
                            dead = true;
                            std.debug.print("firework rocket impact burst\n", .{});
                        }
                        const struck = manager.getBlockWorld(mbx, mby, mbz);
                        if (t.kind == .player_fire_charge) {
                            if (struck == .tnt and fuse_count < fuses.len) {
                                fuses[fuse_count] = .{ .x = mbx, .y = mby, .z = mbz, .t = 2.5 };
                                fuse_count += 1;
                                audio.play(.place_block, 0.8);
                                std.debug.print("fire charge lit TNT fuse\n", .{});
                            } else 
                            if (hazard_mod.isFlammable(struck) and manager.getBlockWorld(mbx, mby + 1, mbz) == .air) {
                                const flame_block = hazard_mod.ignitedFlameBlock(struck);
                                if (try manager.editAndRemesh(mbx, mby + 1, mbz, flame_block)) {
                                    if (flame_count < flames.len) {
                                        flames[flame_count] = .{ .x = mbx, .y = mby + 1, .z = mbz, .t = 0.0 };
                                        flame_count += 1;
                                    }
                                    if (campfire_count < campfires.len) {
                                        campfires[campfire_count] = .{ .x = mbx, .y = mby + 1, .z = mbz, .is_soul = (flame_block == .soul_campfire) };
                                        campfire_count += 1;
                                    }
                                }
                            }
                            particles.spawnFlame(mbx, mby, mbz, 8);
                            audio.play(.burn_sizzle, 0.4);
                        } else if (t.kind == .spectral_arrow or t.kind == .arrow) {
                            if (t.kind == .spectral_arrow) {
                                particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(mbx)) + 0.5, @as(f32, @floatFromInt(mby)) + 0.5, @as(f32, @floatFromInt(mbz)) + 0.5 }, 10);
                                audio.play(.glowstone_chime, 0.7);
                            } else {
                                particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.8, 0.75, 0.7 }, 6);
                                audio.play(.place_block, 0.6);
                            }
                            if (struck == .target_block) {
                                const sig_str = redstone_mod.targetSignalStrength(t.pos.x, t.pos.y, t.pos.z, mbx, mby, mbz);
                                var found_tp = false;
                                for (target_pulses[0..target_pulse_count]) |*tp| {
                                    if (tp.x == mbx and tp.y == mby and tp.z == mbz) {
                                        tp.t = redstone_mod.target_pulse_duration;
                                        tp.strength = sig_str;
                                        found_tp = true;
                                        break;
                                    }
                                }
                                if (!found_tp and target_pulse_count < target_pulses.len) {
                                    target_pulses[target_pulse_count] = .{ .x = mbx, .y = mby, .z = mbz, .t = redstone_mod.target_pulse_duration, .strength = sig_str };
                                    target_pulse_count += 1;
                                }
                                audio.play(.click_on, 0.8);
                                particles.spawnBurnSparks(.{ @as(f32, @floatFromInt(mbx)) + 0.5, @as(f32, @floatFromInt(mby)) + 0.5, @as(f32, @floatFromInt(mbz)) + 0.5 }, 12);
                                std.debug.print("target block struck (strength={d}/15): emitting redstone signal\n", .{sig_str});
                            }
                        } else if (t.kind == .trident) {
                            particles.spawnWaterSplash(.{ t.pos.x, t.pos.y, t.pos.z }, 12);
                            audio.playAt(.place_block, .{ t.pos.x, t.pos.y, t.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 30.0);
                            _ = inventory.addItem(.trident, 1);
                            std.debug.print("thrown trident struck block and recovered to inventory\n", .{});
                            dead = true;
                        } else if (t.kind == .eye_of_ender) {
                            particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 12);
                            audio.playAt(.glowstone_chime, .{ t.pos.x, t.pos.y, t.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.7, 25.0);
                            _ = inventory.addItem(.eye_of_ender, 1);
                            std.debug.print("eye of ender struck block and recovered\n", .{});
                            dead = true;
                        } else if (t.kind == .ender_pearl) {
                            // Ender Pearl impact: teleports player to (t.pos.x, t.pos.y + 0.1, t.pos.z), deals 5 damage, spawns portal particles
                            particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 24);
                            player.pos = math.Vec3.init(t.pos.x, t.pos.y + 0.1, t.pos.z);
                            player.vel_y = 0.0;
                            const has_boots = inventory.hasItem(.netherite_boots);
                            const pearl_dmg = combat_mod.applyArmorReduction(5.0, has_boots);
                            player.health = @max(0.0, player.health - pearl_dmg);
                            audio.play(.mob_teleport, 1.0);
                            audio.play(.hurt, 0.8);
                            std.debug.print("ender pearl teleported player to ({d:.1},{d:.1},{d:.1}) (dmg={d:.1}, hp={d:.1})\n", .{ player.pos.x, player.pos.y, player.pos.z, pearl_dmg, player.health });

                            // 15% probability: pearl teleportation infests landing with an Endermite
                            const seed_m: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(t.pos.x * 37.0)))) ^ @as(u32, @bitCast(@as(i32, @intFromFloat(t.pos.z * 53.0))));
                            if ((seed_m % 20) <= 2) {
                                try mob_manager.spawnMob(.endermite, t.pos.x, t.pos.y + 0.1, t.pos.z);
                                audio.play(.mob_hiss, 0.9);
                                std.debug.print("Endermite spawned from ender pearl teleportation infestation!\n", .{});
                            }
                        } else {
                            particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.93, 0.95, 1.0 }, 6);
                            if (struck == .target_block) {
                                const sig_str = redstone_mod.targetSignalStrength(t.pos.x, t.pos.y, t.pos.z, mbx, mby, mbz);
                                var found_tp = false;
                                for (target_pulses[0..target_pulse_count]) |*tp| {
                                    if (tp.x == mbx and tp.y == mby and tp.z == mbz) {
                                        tp.t = redstone_mod.target_pulse_duration;
                                        tp.strength = sig_str;
                                        found_tp = true;
                                        break;
                                    }
                                }
                                if (!found_tp and target_pulse_count < target_pulses.len) {
                                    target_pulses[target_pulse_count] = .{ .x = mbx, .y = mby, .z = mbz, .t = redstone_mod.target_pulse_duration, .strength = sig_str };
                                    target_pulse_count += 1;
                                }
                                audio.play(.click_on, 0.8);
                                particles.spawnBurnSparks(.{ @as(f32, @floatFromInt(mbx)) + 0.5, @as(f32, @floatFromInt(mby)) + 0.5, @as(f32, @floatFromInt(mbz)) + 0.5 }, 12);
                                std.debug.print("target block struck (strength={d}/15): emitting redstone signal\n", .{sig_str});
                            }
                        }
                        dead = true;
                    } else if (!dead and t.kind != .hostile_fireball and t.kind != .hostile_arrow) {
                        // mob hit test (generous radius)
                        for (mob_manager.mobs.items, 0..) |*m, mi| {
                            if (t.last_hit_mob != null and t.last_hit_mob.? == mi) continue;
                            const d = proj_mod.mobDelta(m.pos.x, m.pos.y, m.pos.z, t.pos.x, t.pos.y, t.pos.z);
                            if (proj_mod.hitsMob(d[0], d[1], d[2])) {
                                const is_fc = (t.kind == .player_fire_charge);
                                const is_sa = (t.kind == .spectral_arrow);
                                const is_arr = (t.kind == .arrow);
                                const is_trident = (t.kind == .trident);
                                const hit_dmg = if (is_trident) t.damage else if (is_sa or is_arr) t.damage else if (is_fc) @as(u8, 2) else @as(u8, 1);
                                const died = m.takeHitDmg(cam.front(), hit_dmg);
                                if (is_fc) particles.spawnFlame(mbx, mby, mbz, 8);
                                if (is_sa) {
                                    m.glow_timer = proj_mod.spectral_arrow_glow_duration;
                                    particles.spawnGlowstoneShimmer(.{ m.pos.x, m.pos.y + 0.5, m.pos.z }, 12);
                                    audio.play(.glowstone_chime, 0.9);
                                    std.debug.print("spectral arrow hit: mob glowing 10s\n", .{});
                                }
                                audio.play(.hurt, 0.5);
                                particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.93, 0.95, 1.0 }, 8);
                                if (is_trident) {
                                    particles.spawnWaterSplash(.{ m.pos.x, m.pos.y + 0.5, m.pos.z }, 14);
                                    _ = inventory.addItem(.trident, 1);
                                    std.debug.print("trident struck mob ({d} dmg) and returned to inventory!\n", .{hit_dmg});
                                }
                                if (died) {
                                    const md = inventory_mod.getMobMeatDrop(m.mob_type);
                                    const mp = m.pos;
                                    const was_ember = (m.mob_type == .emberbeast);
                                    _ = mob_manager.mobs.swapRemove(mi);
                                    _ = inventory.addItem(md, 1);
                                    if (was_ember) {
                                        const bonus = inventory_mod.getEmberBonus(mbx, mbz);
                                        if (bonus > 0) _ = inventory.addItem(.nether_wart, bonus);
                                        particles.spawnFlame(mbx, mby, mbz, 6);
                                    }
                                    if (m.is_champion) {
                                        _ = inventory.addItem(.nether_star, 1);
                                        _ = inventory.addItem(.wither_skull, 2);
                                        std.debug.print("wither champion slain: nether star dropped\n", .{});
                                    } else if (m.mob_type == .wither_skeleton and inventory_mod.dropsWitherSkull(mbx, mby, mbz)) {
                                        _ = inventory.addItem(.wither_skull, 1);
                                        std.debug.print("wither skull dropped\n", .{});
                                    } else if (m.mob_type == .spider and inventory_mod.dropsSpiderEye(mbx, mby, mbz)) {
                                        _ = inventory.addItem(.spider_eye, 1);
                                        std.debug.print("spider eye harvested\n", .{});
                                    } else if (m.mob_type == .skeleton and inventory_mod.dropsSkeletonArrow(mbx, mby, mbz)) {
                                        _ = inventory.addItem(.arrow, 2);
                                        std.debug.print("skeleton dropped reserve arrows\n", .{});
                                    } else if (m.mob_type == .zombie and inventory_mod.dropsZombieIron(mbx, mby, mbz)) {
                                        _ = inventory.addItem(.iron_ingot, 1);
                                        std.debug.print("zombie dropped rare iron ingot\n", .{});
                                    } else if (m.mob_type == .drowned) {
                                        if (inventory_mod.dropsDrownedTrident(mbx, mby, mbz)) {
                                            _ = inventory.addItem(.trident, 1);
                                            std.debug.print("drowned dropped rare trident!\n", .{});
                                        } else if (inventory_mod.dropsDrownedNautilus(mbx, mby, mbz)) {
                                            _ = inventory.addItem(.nautilus_shell, 1);
                                            std.debug.print("drowned dropped nautilus shell!\n", .{});
                                        }
                                    }
                                    if (m.mob_type == .sheep) _ = inventory.addItem(.wool, 1);
                                    _ = mp;
                                }
                                if (t.pierce > 0) {
                                    const p_res = proj_mod.decrementPierce(t.pierce);
                                    t.pierce = p_res.next_pierce;
                                    dead = p_res.dead;
                                    t.last_hit_mob = if (died) null else mi;
                                    particles.spawnBurnSparks(.{ t.pos.x, t.pos.y, t.pos.z }, 6);
                                    std.debug.print("bolt pierced through mob ({d} pierces remain)\n", .{t.pierce});
                                } else {
                                    dead = true;
                                }
                                break;
                            }
                        }
                    }
                }
                if (dead) {
                    cache_mod.swapRemove(&thrown, &thrown_count, ti);
                } else {
                    // trail puff
                    if (t.kind == .shulker_bullet) {
                        particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 1);
                    } else if (t.kind == .hostile_arrow) {
                        particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.85, 0.85, 0.85 }, 1);
                    } else if (t.kind == .eye_of_ender) {
                        particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 2);
                        particles.spawnGlowstoneShimmer(.{ t.pos.x, t.pos.y, t.pos.z }, 1);
                    } else if (t.kind == .ender_pearl) {
                        particles.spawnPortalParticles(.{ t.pos.x, t.pos.y, t.pos.z }, 2);
                    } else if (t.kind == .hostile_fireball) {
                        particles.spawnFlame(mbx, mby, mbz, 1);
                    } else if (t.kind == .spectral_arrow) {
                        particles.spawnGlowstoneShimmer(.{ t.pos.x, t.pos.y, t.pos.z }, 1);
                    } else if (t.kind == .firework_rocket) {
                        particles.spawnFlame(mbx, mby, mbz, 1);
                        particles.spawnCampfireSmoke(mbx, mby, mbz, false, false, 1);
                    } else if (t.kind == .trident) {
                        particles.spawnWaterSplash(.{ t.pos.x, t.pos.y, t.pos.z }, 2);
                    } else if (t.kind == .arrow) {
                        particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.85, 0.85, 0.85 }, 1);
                    } else {
                        particles.spawnBlockDebris(mbx, mby, mbz, .{ 0.9, 0.92, 1.0 }, 1);
                    }
                    ti += 1;
                }
            }
        }

        // Crossbow loading & firing mechanics
        const held_crossbow = inventory.slots[selected_slot].item == .crossbow;
        if (held_crossbow and !inventory_open) {
            if (crossbow_loaded) {
                // Loaded crossbow: right-click releases loaded projectile instantly with high speed (42 m/s)
                if (right and !right_down) {
                    if (thrown_count < thrown.len) {
                        const dir_cb = cam.front();
                        const is_rocket = (crossbow_loaded_kind == .fireworks_rocket);
                        const vel_cb = if (is_rocket)
                            proj_mod.crossbowRocketVelocity(dir_cb.x, dir_cb.y, dir_cb.z)
                        else
                            proj_mod.crossbowInitialVelocity(dir_cb.x, dir_cb.y, dir_cb.z);
                        const k: ThrownKind = if (is_rocket)
                            .firework_rocket
                        else if (crossbow_loaded_kind == .spectral_arrow)
                            .spectral_arrow
                        else
                            .arrow;
                        const dmg: u8 = if (is_rocket) proj_mod.firework_explosion_damage else proj_mod.crossbow_arrow_damage;
                        const life_cb: f32 = if (is_rocket) proj_mod.firework_rocket_life else proj_mod.throw_life;

                        const pierce_cb: u8 = if (is_rocket) 0 else proj_mod.crossbow_pierce_count;
                        thrown[thrown_count] = .{
                            .pos = cam.position,
                            .vel = math.Vec3.init(vel_cb[0], vel_cb[1], vel_cb[2]),
                            .life = life_cb,
                            .kind = k,
                            .damage = dmg,
                            .pierce = pierce_cb,
                            .last_hit_mob = null,
                        };
                        thrown_count += 1;
                        audio.play(.crossbow_shoot, 0.95);
                        if (is_rocket) {
                            audio.play(.burn_sizzle, 0.9);
                            particles.spawnBurnSparks(.{ cam.position.x + dir_cb.x * 0.8, cam.position.y + dir_cb.y * 0.8, cam.position.z + dir_cb.z * 0.8 }, 12);
                            std.debug.print("crossbow firework rocket launched (speed={d:.1})\n", .{proj_mod.crossbow_rocket_speed});
                        } else {
                            particles.spawnBurnSparks(.{ cam.position.x + dir_cb.x * 0.9, cam.position.y + dir_cb.y * 0.9, cam.position.z + dir_cb.z * 0.9 }, 8);
                            std.debug.print("crossbow bolt fired (dmg={d}, speed={d:.1})\n", .{ proj_mod.crossbow_arrow_damage, proj_mod.crossbow_arrow_speed });
                        }

                        if (tool_wear.use(selected_slot, inventory_mod.ItemType.crossbow.maxDurability())) {
                            inventory.slots[selected_slot].clear();
                            audio.play(.break_block, 0.8);
                            std.debug.print("crossbow broke\n", .{});
                        }
                    }
                    crossbow_loaded = false;
                    crossbow_loaded_kind = null;
                    crossbow_charge = 0.0;
                }
            } else {
                // Unloaded crossbow: holding right-click loads bolt (1.25s)
                if (right) {
                    const prev_charge = crossbow_charge;
                    crossbow_charge = @min(1.0, crossbow_charge + dt / proj_mod.crossbow_load_time);
                    if (prev_charge < 0.2 and crossbow_charge >= 0.2) {
                        audio.play(.crossbow_load, 0.7);
                    }
                    if (crossbow_charge >= 1.0) {
                        if (inventory.consumeCrossbowAmmo()) |arrow_kind| {
                            crossbow_loaded = true;
                            crossbow_loaded_kind = arrow_kind;
                            crossbow_charge = 0.0;
                            audio.play(.click_on, 0.8);
                            std.debug.print("crossbow loaded with {s}\n", .{@tagName(arrow_kind)});
                        } else {
                            crossbow_charge = 0.0;
                            audio.play(.click_off, 0.5);
                        }
                    }
                } else {
                    crossbow_charge = 0.0;
                }
            }
        } else {
            crossbow_charge = 0.0;
        }

        // Bow charging & shooting
        const held_bow = inventory.slots[selected_slot].item == .bow;
        if (held_bow and !inventory_open) {
            if (right) {
                bow_charge = @min(1.0, bow_charge + dt / proj_mod.bow_draw_time);
            } else if (bow_charge > 0.05) {
                if (inventory.consumeArrow()) |arrow_kind| {
                    if (thrown_count < thrown.len) {
                        const dir_b = cam.front();
                        const speed = proj_mod.bowArrowSpeed(bow_charge);
                        const dmg = proj_mod.bowArrowDamage(bow_charge);
                        const vel_b = proj_mod.bowInitialVelocity(dir_b.x, dir_b.y, dir_b.z, speed);
                        const k: ThrownKind = if (arrow_kind == .spectral_arrow) .spectral_arrow else .arrow;
                        thrown[thrown_count] = .{
                            .pos = cam.position,
                            .vel = math.Vec3.init(vel_b[0], vel_b[1], vel_b[2]),
                            .life = proj_mod.throw_life,
                            .kind = k,
                            .damage = dmg,
                        };
                        thrown_count += 1;
                        audio.play(.bow_shoot, 0.9);
                        if (bow_charge >= 0.95) {
                            particles.spawnBurnSparks(.{ cam.position.x + dir_b.x * 0.8, cam.position.y + dir_b.y * 0.8, cam.position.z + dir_b.z * 0.8 }, 6);
                            std.debug.print("bow critical shot (charge={d:.2}, dmg={d}, speed={d:.1})\n", .{ bow_charge, dmg, speed });
                        } else {
                            std.debug.print("bow shot (charge={d:.2}, dmg={d}, speed={d:.1})\n", .{ bow_charge, dmg, speed });
                        }
                        if (tool_wear.use(selected_slot, inventory_mod.ItemType.bow.maxDurability())) {
                            inventory.slots[selected_slot].clear();
                            audio.play(.break_block, 0.8);
                            std.debug.print("bow broke\n", .{});
                        }
                    }
                } else {
                    audio.play(.click_off, 0.5);
                }
                bow_charge = 0.0;
            } else {
                bow_charge = 0.0;
            }
        } else {
            bow_charge = 0.0;
        }

        // G throws snowball / fire charge / spectral arrow / arrow / fireworks rocket
        throw_cooldown = @max(0.0, throw_cooldown - dt);
        if (!inventory_open and throw_cooldown <= 0.0 and c.glfwGetKey(window, c.GLFW_KEY_G) == c.GLFW_PRESS) {
            const held_throw = inventory.slots[selected_slot].item;
            if ((held_throw == .snowball or held_throw == .fire_charge or held_throw == .spectral_arrow or held_throw == .arrow or held_throw == .fireworks_rocket or held_throw == .ender_pearl or held_throw == .eye_of_ender or held_throw == .trident) and thrown_count < thrown.len) {
                const dir_g = cam.front();
                const vel_g = proj_mod.initialVelocity(dir_g.x, dir_g.y, dir_g.z);
                const k: ThrownKind = if (held_throw == .fire_charge)
                    .player_fire_charge
                else if (held_throw == .spectral_arrow)
                    .spectral_arrow
                else if (held_throw == .arrow)
                    .arrow
                else if (held_throw == .fireworks_rocket)
                    .firework_rocket
                else if (held_throw == .ender_pearl)
                    .ender_pearl
                else if (held_throw == .eye_of_ender)
                    .eye_of_ender
                else if (held_throw == .trident)
                    .trident
                else
                    .snowball;
                const dmg: u8 = if (held_throw == .trident)
                    proj_mod.trident_damage
                else if (held_throw == .spectral_arrow)
                    proj_mod.spectral_arrow_damage
                else if (held_throw == .arrow)
                    2
                else if (held_throw == .fire_charge)
                    2
                else if (held_throw == .fireworks_rocket)
                    proj_mod.firework_explosion_damage
                else
                    1;
                const life_g: f32 = if (held_throw == .fireworks_rocket) proj_mod.firework_rocket_life else if (held_throw == .eye_of_ender) 2.5 else if (held_throw == .trident) proj_mod.trident_life else proj_mod.throw_life;
                var vel_final = if (held_throw == .fireworks_rocket)
                    proj_mod.fireworkInitialVelocity(dir_g.x, dir_g.y, dir_g.z)
                else if (held_throw == .trident)
                    proj_mod.tridentInitialVelocity(dir_g.x, dir_g.y, dir_g.z)
                else
                    vel_g;
                if (held_throw == .eye_of_ender) {
                    // Navigate towards Stronghold origin (0, 0)
                    const sdx = 0.0 - cam.position.x;
                    const sdz = 0.0 - cam.position.z;
                    const sdist = @sqrt(sdx * sdx + sdz * sdz);
                    const speed: f32 = 12.0;
                    if (sdist > 1.0) {
                        vel_final[0] = (sdx / sdist) * speed;
                        vel_final[1] = 4.0; // gentle ascension
                        vel_final[2] = (sdz / sdist) * speed;
                    } else {
                        vel_final[0] = 0.0;
                        vel_final[1] = 5.0;
                        vel_final[2] = 0.0;
                    }
                }
                thrown[thrown_count] = .{ .pos = cam.position, .vel = math.Vec3.init(vel_final[0], vel_final[1], vel_final[2]), .life = life_g, .kind = k, .damage = dmg };
                thrown_count += 1;
                inventory.slots[selected_slot].decrement(1);
                if (held_throw == .trident) {
                    audio.play(.splash, 0.9);
                    audio.play(.break_block, 0.7);
                } else if (held_throw == .fire_charge) {
                    audio.play(.lava_pop, 0.6);
                } else if (held_throw == .spectral_arrow) {
                    audio.play(.glowstone_chime, 0.8);
                } else if (held_throw == .fireworks_rocket) {
                    audio.play(.burn_sizzle, 0.8);
                } else {
                    audio.play(.place_block, 0.4);
                }
                throw_cooldown = proj_mod.throw_cooldown;
            }
        }
        // Emberbeast fireballs: ranged 3-dmg flame bolts with fire trail
        fireball_cooldown = combat_mod.tickCooldown(fireball_cooldown, dt);
        if (fireball_cooldown <= 0.0) {
            for (mob_manager.mobs.items) |m| {
                if (m.mob_type != .emberbeast and m.mob_type != .wither_skeleton and m.mob_type != .blaze) continue;
                const fdx = player.pos.x - m.pos.x;
                const fdz = player.pos.z - m.pos.z;
                const fdy = (player.pos.y + 1.0) - (m.pos.y + 0.7);
                if (!proj_mod.inFireballRange(fdx, fdz)) continue;
                if (thrown_count < thrown.len) {
                    const fv = proj_mod.fireballVelocity(fdx, fdy, fdz);
                    thrown[thrown_count] = .{
                        .pos = math.Vec3.init(m.pos.x, m.pos.y + 0.7, m.pos.z),
                        .vel = math.Vec3.init(fv[0], fv[1], fv[2]),
                        .life = proj_mod.fireball_life,
                        .kind = .hostile_fireball,
                    };
                    thrown_count += 1;
                    audio.playAt(.lava_pop, .{ m.pos.x, m.pos.y, m.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                    particles.spawnFlame(@intFromFloat(@floor(m.pos.x)), @intFromFloat(@floor(m.pos.y + 1)), @intFromFloat(@floor(m.pos.z)), 6);
                    std.debug.print("emberbeast fireball\n", .{});
                }
                fireball_cooldown = proj_mod.fireball_cooldown;
                break;
            }
        }
        // Creeper detonation AI: approaches player, hisses & primes within 3m, explodes at 0
        {
            var mi: usize = 0;
            while (mi < mob_manager.mobs.items.len) {
                var m = &mob_manager.mobs.items[mi];
                if (m.mob_type == .creeper) {
                    const cdx = player.pos.x - m.pos.x;
                    const cdy = player.pos.y - m.pos.y;
                    const cdz = player.pos.z - m.pos.z;
                    const dist_sq = cdx * cdx + cdy * cdy + cdz * cdz;

                    if (m.is_primed) {
                        m.fuse_timer -= dt;
                        // White smoke and sparking fuse pulses while swelling
                        particles.spawnCampfireSmoke(@intFromFloat(@floor(m.pos.x)), @intFromFloat(@floor(m.pos.y + 1.2)), @intFromFloat(@floor(m.pos.z)), false, false, 2);
                        particles.spawnBlockDebris(@intFromFloat(@floor(m.pos.x)), @intFromFloat(@floor(m.pos.y + 1.0)), @intFromFloat(@floor(m.pos.z)), .{ 0.95, 0.95, 0.95 }, 3);

                        if (m.fuse_timer <= 0.0) {
                            // Detonate!
                            const ex: i32 = @intFromFloat(@floor(m.pos.x));
                            const ey: i32 = @intFromFloat(@floor(m.pos.y + 0.8));
                            const ez: i32 = @intFromFloat(@floor(m.pos.z));

                            // Carve blast crater
                            var rx: i32 = -boom_mod.creeper_blast_radius;
                            while (rx <= boom_mod.creeper_blast_radius) : (rx += 1) {
                                var ry: i32 = -boom_mod.creeper_blast_radius;
                                while (ry <= boom_mod.creeper_blast_radius) : (ry += 1) {
                                    var rz: i32 = -boom_mod.creeper_blast_radius;
                                    while (rz <= boom_mod.creeper_blast_radius) : (rz += 1) {
                                        if (boom_mod.inBlast(rx, ry, rz)) {
                                            const bx = ex + rx;
                                            const by = ey + ry;
                                            const bz = ez + rz;
                                            const old_b = manager.getBlockWorld(bx, by, bz);
                                            switch (boom_mod.evaluateBlastBlock(old_b, by)) {
                                                .destroy_block => {
                                                    _ = try manager.editAndRemesh(bx, by, bz, .air);
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
                                                .chain_tnt => {
                                                    if (boom_mod.canChainFuse(fuses[0..fuse_count], bx, by, bz, fuses.len)) {
                                                        fuses[fuse_count] = .{ .x = bx, .y = by, .z = bz, .t = boom_mod.chain_fuse_time };
                                                        fuse_count += 1;
                                                    }
                                                },
                                                .ignore => {},
                                            }
                                        }
                                    }
                                }
                            }

                            // Blast acoustics & VFX
                            audio.playAt(.break_block, .{ m.pos.x, m.pos.y, m.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 45.0);
                            particles.spawnBlockDebris(ex, ey, ez, .{ 0.40, 0.85, 0.30 }, 64);
                            particles.spawnFlame(ex, ey, ez, 16);

                            // Blast mob hit
                            for (mob_manager.mobs.items, 0..) |*other_m, omi| {
                                if (omi == mi) continue;
                                if (boom_mod.calculateMobBlastHit(other_m.pos.x, other_m.pos.y, other_m.pos.z, ex, ey, ez)) |h| {
                                    _ = other_m.takeHitDmg(math.Vec3.init(h.knockback[0], h.knockback[1], h.knockback[2]), h.damage);
                                }
                            }

                            // Player damage & launch impulse
                            if (boom_mod.calculatePlayerBlastImpulse(player.pos.x, player.pos.y, player.pos.z, ex, ey, ez)) |imp| {
                                const has_chest = inventory.hasItem(.netherite_chestplate);
                                const has_full = inventory.hasFullNetheriteSet();
                                const blast_dmg = combat_mod.applyArmorReductionAllTiers(imp.damage, has_chest, has_full, inventory.hasItem(.diamond_chestplate), inventory.hasFullDiamondSet(), inventory.hasItem(.iron_chestplate), inventory.hasFullIronSet(), inventory.hasItem(.golden_chestplate), inventory.hasFullGoldenSet());
                                player.health = @max(0.0, player.health - blast_dmg);
                                player.vel_y = imp.vel_y;
                                player.pos.x += imp.push_x;
                                player.pos.z += imp.push_z;
                                audio.play(.hurt, 1.0);
                                std.debug.print("creeper explosion hit player (dmg={d:.1}, hp={d:.1})\n", .{ blast_dmg, player.health });
                            }

                            // Remove detonated creeper
                            _ = mob_manager.mobs.swapRemove(mi);
                            std.debug.print("creeper detonated at ({d},{d},{d})\n", .{ ex, ey, ez });
                            continue;
                        } else if (boom_mod.shouldAbortCreeper(dist_sq)) {
                            // Player fled beyond abort range: cancel fuse!
                            m.is_primed = false;
                            m.fuse_timer = 0.0;
                            std.debug.print("creeper fuse aborted (player escaped)\n", .{});
                        }
                    } else if (boom_mod.shouldPrimeCreeper(dist_sq)) {
                        m.is_primed = true;
                        m.fuse_timer = boom_mod.creeper_fuse_time;
                        audio.playAt(.mob_hiss, .{ m.pos.x, m.pos.y, m.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 25.0);
                        std.debug.print("creeper hissed & primed fuse!\n", .{});
                    }
                }
                mi += 1;
            }
        }


        // Shulker bullet fire: homing levitation missile cadence every 3.0s when player is within 20m
        shulker_shot_cooldown = combat_mod.tickCooldown(shulker_shot_cooldown, dt);
        if (shulker_shot_cooldown <= 0.0) {
            for (mob_manager.mobs.items) |m| {
                if (m.mob_type != .shulker) continue;
                const sdx = player.pos.x - m.pos.x;
                const sdz = player.pos.z - m.pos.z;
                const sdy = (player.pos.y + 0.8) - (m.pos.y + 0.5);
                const sdist_sq = sdx * sdx + sdz * sdz;
                if (sdist_sq <= 20.0 * 20.0 and sdist_sq > 1.0) {
                    if (thrown_count < thrown.len) {
                        const dist = @sqrt(sdist_sq + sdy * sdy);
                        const b_speed: f32 = 8.0;
                        const vx = (sdx / dist) * b_speed;
                        const vy = (sdy / dist) * b_speed;
                        const vz = (sdz / dist) * b_speed;
                        thrown[thrown_count] = .{
                            .pos = math.Vec3.init(m.pos.x, m.pos.y + 0.6, m.pos.z),
                            .vel = math.Vec3.init(vx, vy, vz),
                            .life = 6.0,
                            .kind = .shulker_bullet,
                            .damage = 4,
                        };
                        thrown_count += 1;
                        audio.playAt(.mob_roar, .{ m.pos.x, m.pos.y, m.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.7, 25.0);
                        particles.spawnPortalParticles(.{ m.pos.x, m.pos.y + 0.6, m.pos.z }, 10);
                        std.debug.print("shulker fired levitation bullet\n", .{});
                    }
                    shulker_shot_cooldown = 3.0;
                    break;
                }
            }
        }

        // Skeleton archery: ranged arrow barrage with 1.8s cadence when player is within 16m
        skeleton_shot_cooldown = combat_mod.tickCooldown(skeleton_shot_cooldown, dt);
        if (skeleton_shot_cooldown <= 0.0) {
            for (mob_manager.mobs.items) |m| {
                if (m.mob_type != .skeleton) continue;
                const adx = player.pos.x - m.pos.x;
                const adz = player.pos.z - m.pos.z;
                const ady = (player.pos.y + 1.0) - (m.pos.y + 1.3);
                const dist_sq = adx * adx + adz * adz;
                if (dist_sq >= 2.0 * 2.0 and dist_sq <= 16.0 * 16.0) {
                    if (thrown_count < thrown.len) {
                        const dist = @sqrt(dist_sq + ady * ady);
                        const arrow_speed: f32 = 18.0;
                        const vx = (adx / dist) * arrow_speed;
                        const vy = (ady / dist) * arrow_speed + 1.5; // slight loft
                        const vz = (adz / dist) * arrow_speed;
                        thrown[thrown_count] = .{
                            .pos = math.Vec3.init(m.pos.x, m.pos.y + 1.3, m.pos.z),
                            .vel = math.Vec3.init(vx, vy, vz),
                            .life = proj_mod.throw_life,
                            .kind = .hostile_arrow,
                            .damage = 2,
                        };
                        thrown_count += 1;
                        audio.playAt(.bow_shoot, .{ m.pos.x, m.pos.y, m.pos.z }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                        particles.spawnBlockDebris(@intFromFloat(@floor(m.pos.x)), @intFromFloat(@floor(m.pos.y + 1)), @intFromFloat(@floor(m.pos.z)), .{ 0.85, 0.85, 0.85 }, 4);
                        std.debug.print("skeleton archer fired arrow\n", .{});
                    }
                    skeleton_shot_cooldown = 1.8;
                    break;
                }
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
                                            if (old_b == .obsidian or old_b == .nether_portal) {
                                                var ext_cells: [6][3]i32 = undefined;
                                                const ext_n = portal_mod.collectPortalCellsToExtinguish(&pickBlockWorld, bx, by, bz, &ext_cells);
                                                for (ext_cells[0..ext_n]) |cell_coord| {
                                                    if (!portal_mod.isPortalCellValid(&pickBlockWorld, cell_coord[0], cell_coord[1], cell_coord[2])) {
                                                        _ = try manager.editAndRemesh(cell_coord[0], cell_coord[1], cell_coord[2], .air);
                                                        particles.spawnPortalParticles(.{ @as(f32, @floatFromInt(cell_coord[0])) + 0.5, @as(f32, @floatFromInt(cell_coord[1])) + 0.5, @as(f32, @floatFromInt(cell_coord[2])) + 0.5 }, 8);
                                                    }
                                                }
                                            }
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
                } else if (interact_mod.toggleComparator(target)) |toggled| {
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, toggled)) {
                        if (toggled == .redstone_comparator_on) {
                            audio.play(.click_on, 0.7);
                            particles.spawnFlame(hit_f.x, hit_f.y, hit_f.z, 2);
                        } else {
                            audio.play(.click_off, 0.6);
                        }
                        std.debug.print("toggled redstone comparator to {s} ({d},{d},{d})\n", .{ @tagName(toggled), hit_f.x, hit_f.y, hit_f.z });
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (interact_mod.toggleTripwireHook(target)) |toggled| {
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, toggled)) {
                        if (toggled == .tripwire_hook_on) {
                            audio.play(.click_on, 0.9);
                            particles.spawnFlame(hit_f.x, hit_f.y, hit_f.z, 2);
                        } else {
                            audio.play(.click_off, 0.7);
                            particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.6, 0.5, 0.3 }, 3);
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
                            if (interact_mod.toggleDoor(db, toggled == .tripwire_hook_on)) |new_db| {
                                _ = try manager.editAndRemesh(dx, dy, dz, new_db);
                            }
                        }
                        std.debug.print("toggled tripwire hook to {s} ({d},{d},{d})\n", .{ @tagName(toggled), hit_f.x, hit_f.y, hit_f.z });
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
                } else if (target == .iron_door_closed or target == .iron_door_open or target == .iron_trapdoor_closed or target == .iron_trapdoor_open) {
                    audio.play(.step_stone, 0.7);
                    std.debug.print("iron door/trapdoor locked; requires redstone signal\n", .{});
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .redstone_ore) {
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, .lit_redstone_ore)) {
                        audio.play(.step_stone, 0.9);
                        std.debug.print("lit redstone ore ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                    }
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
                } else if (target == .chest or target == .shulker_box) {
                    var k_opt = cache_mod.findChest(&chests, chest_count, hit_f.x, hit_f.y, hit_f.z);
                    if (k_opt == null and cache_mod.canCreateChest(chest_count, chests.len)) {
                        chests[chest_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .items = [_]inventory_mod.ItemStack{.{}} ** 4 };
                        // Fortress loot: pre-fill Nether-generated chests with deterministic junction loot on first open.
                        if (manager.is_nether and manager.nether.isFortressLoot(hit_f.x, hit_f.y, hit_f.z)) {
                            var loot: [4]inventory_mod.ItemStack = undefined;
                            inventory_mod.fortressLoot(hit_f.x, hit_f.z, &loot);
                            for (loot, 0..) |li, idx| {
                                chests[chest_count].items[idx] = li;
                            }
                            std.debug.print("fortress loot chest opened\n", .{});
                            // Loot guard: 50% deterministic chance an emberbeast stalks the opened junction.
                            const guard_roll: u32 = @as(u32, @bitCast(hit_f.x *% 13 +% hit_f.z *% 29)) % 2;
                            if (guard_roll == 0) {
                                const gx: f32 = @as(f32, @floatFromInt(hit_f.x)) + 0.5;
                                const gz: f32 = @as(f32, @floatFromInt(hit_f.z)) + 0.5;
                                const gy: f32 = @as(f32, @floatFromInt(hit_f.y + 1));
                                try mob_manager.spawnMob(.emberbeast, gx, gy, gz);
                                audio.playAt(.mob_roar, .{ gx, gy, gz }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 30.0);
                                std.debug.print("loot guard emberbeast spawned\n", .{});
                            }
                        }
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
                } else if (target.is_fence()) {
                    // Fence hitching post interaction
                    const hitched = mob_manager.tryHitchToFence(hit_f.x, hit_f.y, hit_f.z);
                    if (hitched > 0) {
                        audio.play(.step_wood, 0.9);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.82, 0.74, 0.52 }, 8);
                        std.debug.print("hitched {d} mob(s) to fence post at ({d},{d},{d})\n", .{ hitched, hit_f.x, hit_f.y, hit_f.z });
                    } else {
                        // Unhitch any mobs tied to this fence post
                        const unhitched = mob_manager.unhitchFence(hit_f.x, hit_f.y, hit_f.z);
                        if (unhitched > 0) {
                            _ = inventory.addItem(.lead, @intCast(unhitched));
                            audio.play(.click_off, 0.85);
                            std.debug.print("unhitched {d} mob(s) from fence post at ({d},{d},{d})\n", .{ unhitched, hit_f.x, hit_f.y, hit_f.z });
                        }
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .armor_stand) {
                    var as_opt = cache_mod.findArmorStand(&armor_stands, armor_stand_count, hit_f.x, hit_f.y, hit_f.z);
                    if (as_opt == null and armor_stand_count < armor_stands.len) {
                        armor_stands[armor_stand_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        as_opt = armor_stand_count;
                        armor_stand_count += 1;
                    }

                    if (as_opt) |ai| {
                        const as_stand = &armor_stands[ai];
                        const held_slot = &inventory.slots[selected_slot];
                        const held_item = held_slot.item;

                        if (held_item.isArmor()) {
                            // Mount armor into appropriate equipment slot
                            var mounted = false;
                            switch (held_item) {
                                .netherite_helmet => {
                                    if (as_stand.head) |prev| _ = inventory.addItem(prev, 1);
                                    as_stand.head = held_item;
                                    mounted = true;
                                },
                                .netherite_chestplate => {
                                    if (as_stand.chest) |prev| _ = inventory.addItem(prev, 1);
                                    as_stand.chest = held_item;
                                    mounted = true;
                                },
                                .netherite_leggings => {
                                    if (as_stand.legs) |prev| _ = inventory.addItem(prev, 1);
                                    as_stand.legs = held_item;
                                    mounted = true;
                                },
                                .netherite_boots, .soul_speed_boots => {
                                    if (as_stand.feet) |prev| _ = inventory.addItem(prev, 1);
                                    as_stand.feet = held_item;
                                    mounted = true;
                                },
                                else => {},
                            }
                            if (mounted) {
                                held_slot.decrement(1);
                                audio.playAt(.step_wood, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 30.0);
                                particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.85, 0.75, 0.60 }, 8);
                                std.debug.print("mounted {s} onto armor stand at ({d},{d},{d})\n", .{ held_item.name(), hit_f.x, hit_f.y, hit_f.z });
                            }
                        } else if (held_item == .none) {
                            // Cycle pose when empty-handed
                            as_stand.pose = switch (as_stand.pose) {
                                .default_standing => .salute,
                                .salute => .pointing,
                                .pointing => .guarding,
                                .guarding => .default_standing,
                            };
                            audio.playAt(.click_on, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                            particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.75, 0.60, 0.42 }, 4);
                            std.debug.print("armor stand pose cycled to {s}\n", .{ @tagName(as_stand.pose) });
                        } else {
                            // Eject topmost equipped armor piece back to player
                            if (as_stand.head) |it| {
                                _ = inventory.addItem(it, 1);
                                as_stand.head = null;
                            } else if (as_stand.chest) |it| {
                                _ = inventory.addItem(it, 1);
                                as_stand.chest = null;
                            } else if (as_stand.legs) |it| {
                                _ = inventory.addItem(it, 1);
                                as_stand.legs = null;
                            } else if (as_stand.feet) |it| {
                                _ = inventory.addItem(it, 1);
                                as_stand.feet = null;
                            }
                            audio.playAt(.click_off, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                        }
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .stonecutter) {
                    var sc_opt = cache_mod.findStonecutter(&stonecutters, stonecutter_count, hit_f.x, hit_f.y, hit_f.z);
                    if (sc_opt == null and stonecutter_count < stonecutters.len) {
                        stonecutters[stonecutter_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        sc_opt = stonecutter_count;
                        stonecutter_count += 1;
                    }

                    const held_slot = &inventory.slots[selected_slot];
                    if (held_slot.item == .stone) {
                        // Masonry precision shaping: 1 Stone -> 1 Brick
                        held_slot.decrement(1);
                        _ = inventory.addItem(.brick, 1);
                        audio.playAt(.stonecutter_saw, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 30.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.75, 0.75, 0.75 }, 8);
                        std.debug.print("precision stonecut 1 stone into brick at ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                    } else if (held_slot.item == .cobblestone) {
                        // Masonry cobblestone smoothing: 1 Cobblestone -> 1 Stone
                        held_slot.decrement(1);
                        _ = inventory.addItem(.stone, 1);
                        audio.playAt(.stonecutter_saw, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 30.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.65, 0.65, 0.65 }, 8);
                        std.debug.print("precision shaped 1 cobblestone into smooth stone at ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                    } else if (held_slot.item == .wooden_pickaxe or held_slot.item == .iron_pickaxe or held_slot.item == .diamond_pickaxe or held_slot.item == .netherite_pickaxe) {
                        // True the pickaxe chisel head on circular saw guide
                        tool_wear.uses[selected_slot] = 0;
                        audio.playAt(.stonecutter_saw, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 28.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.80, 0.80, 0.85 }, 8);
                        std.debug.print("trued pickaxe head on stonecutter: {s}\n", .{ held_slot.item.name() });
                    } else {
                        audio.playAt(.stonecutter_saw, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.6, 20.0);
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .loom) {
                    var lm_opt = cache_mod.findLoom(&looms, loom_count, hit_f.x, hit_f.y, hit_f.z);
                    if (lm_opt == null and loom_count < looms.len) {
                        looms[loom_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        lm_opt = loom_count;
                        loom_count += 1;
                    }

                    const held_slot = &inventory.slots[selected_slot];
                    if (held_slot.item == .wool) {
                        // Textile weaving: weave raw wool into woven cloth banner crafting
                        audio.playAt(.loom_shuttle, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 28.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.90, 0.90, 0.90 }, 8);
                        std.debug.print("wove textile fabric on loom at ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                    } else if (held_slot.item.isTool()) {
                        // Honing shears / tool calibration
                        tool_wear.uses[selected_slot] = 0;
                        audio.playAt(.loom_shuttle, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 28.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.70, 0.60, 0.45 }, 6);
                    } else {
                        // Shuttle batten click inspect
                        audio.playAt(.loom_shuttle, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.7, 20.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.60, 0.50, 0.35 }, 3);
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .composter) {
                    var cp_opt = cache_mod.findComposter(&composters, composter_count, hit_f.x, hit_f.y, hit_f.z);
                    if (cp_opt == null and composter_count < composters.len) {
                        composters[composter_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .level = 0 };
                        cp_opt = composter_count;
                        composter_count += 1;
                    }

                    if (cp_opt) |ci| {
                        const cp = &composters[ci];
                        const held_slot = &inventory.slots[selected_slot];
                        if (cp.level >= 7) {
                            // Ready for harvesting Bone Meal!
                            cp.level = 0;
                            _ = inventory.addItem(.bone_meal, 1);
                            audio.playAt(.composter_fill, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 30.0);
                            particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.90, 0.90, 0.85 }, 12);
                            std.debug.print("harvested Bone Meal from composter at ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                        } else if (held_slot.item.isCompostable()) {
                            // Deposit organic material to advance compost level
                            held_slot.decrement(1);
                            cp.level += 1;
                            audio.playAt(.composter_fill, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 28.0);
                            particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.45, 0.65, 0.30 }, 6);
                            std.debug.print("added compost to composter (level={d}/7)\n", .{ cp.level });
                        } else {
                            audio.playAt(.composter_fill, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.6, 20.0);
                        }
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .fletching_table) {
                    var ft_opt = cache_mod.findFletchingTable(&fletching_tables, fletching_table_count, hit_f.x, hit_f.y, hit_f.z);
                    if (ft_opt == null and fletching_table_count < fletching_tables.len) {
                        fletching_tables[fletching_table_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        ft_opt = fletching_table_count;
                        fletching_table_count += 1;
                    }

                    const held_slot = &inventory.slots[selected_slot];
                    if (held_slot.item == .stick) {
                        // Quick fletching: 1 Stick -> 2 Arrows
                        held_slot.decrement(1);
                        _ = inventory.addItem(.arrow, 2);
                        audio.playAt(.fletching_snap, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 28.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.85, 0.75, 0.50 }, 6);
                        std.debug.print("fletched 2 arrows at ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                    } else if (held_slot.item == .bow or held_slot.item == .crossbow) {
                        // Honing bow/crossbow string & alignment
                        tool_wear.uses[selected_slot] = 0;
                        audio.playAt(.fletching_snap, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 28.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.70, 0.55, 0.35 }, 6);
                        std.debug.print("calibrated ranged weapon: {s}\n", .{ held_slot.item.name() });
                    } else {
                        // Wooden nock snap tap
                        audio.playAt(.fletching_snap, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.7, 20.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.60, 0.45, 0.30 }, 3);
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .cartography_table) {
                    var ct_opt = cache_mod.findCartographyTable(&cartography_tables, cartography_table_count, hit_f.x, hit_f.y, hit_f.z);
                    if (ct_opt == null and cartography_table_count < cartography_tables.len) {
                        cartography_tables[cartography_table_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        ct_opt = cartography_table_count;
                        cartography_table_count += 1;
                    }

                    const held_slot = &inventory.slots[selected_slot];
                    if (held_slot.item == .compass or held_slot.item == .lodestone_compass) {
                        // Navigation survey: calibrate compass & plot geographic bearing
                        audio.playAt(.map_rustle, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 28.0);
                        particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 6);
                        std.debug.print("cartography table surveyed coordinates ({d},{d},{d}) with {s}\n", .{ hit_f.x, hit_f.y, hit_f.z, held_slot.item.name() });
                    } else if (held_slot.item.isTool()) {
                        // Honing surveyor tool
                        tool_wear.uses[selected_slot] = 0;
                        audio.playAt(.map_rustle, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 25.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.80, 0.75, 0.60 }, 5);
                    } else {
                        // Paper parchment rustle inspect
                        audio.playAt(.map_rustle, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.7, 20.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.85, 0.80, 0.65 }, 3);
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .smithing_table) {
                    var st_opt = cache_mod.findSmithingTable(&smithing_tables, smithing_table_count, hit_f.x, hit_f.y, hit_f.z);
                    if (st_opt == null and smithing_table_count < smithing_tables.len) {
                        smithing_tables[smithing_table_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        st_opt = smithing_table_count;
                        smithing_table_count += 1;
                    }

                    const held_slot = &inventory.slots[selected_slot];
                    if (held_slot.item.isTool()) {
                        // Workstation forging: restore tool wear and reinforce
                        tool_wear.uses[selected_slot] = 0;
                        audio.playAt(.smithing_strike, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 32.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.85, 0.75, 0.45 }, 8);
                        std.debug.print("upgraded/hardened tool on smithing table: {s}\n", .{ held_slot.item.name() });
                    } else {
                        // Bench tap clack
                        audio.playAt(.smithing_strike, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.6, 22.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.55, 0.40, 0.25 }, 3);
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .grindstone) {
                    var gs_opt = cache_mod.findGrindstone(&grindstones, grindstone_count, hit_f.x, hit_f.y, hit_f.z);
                    if (gs_opt == null and grindstone_count < grindstones.len) {
                        grindstones[grindstone_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        gs_opt = grindstone_count;
                        grindstone_count += 1;
                    }

                    const held_slot = &inventory.slots[selected_slot];
                    if (held_slot.item.isTool()) {
                        // Abrasive stone grinding wheel sharpening & restoration
                        tool_wear.uses[selected_slot] = 0;
                        audio.playAt(.grindstone_scrape, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 30.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.70, 0.70, 0.75 }, 8);
                        std.debug.print("sharpened and restored tool on grindstone: {s}\n", .{ held_slot.item.name() });
                    } else {
                        // Spinning stone wheel friction scrape tap
                        audio.playAt(.grindstone_scrape, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.6, 20.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.50, 0.50, 0.55 }, 3);
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .anvil) {
                    var an_opt = cache_mod.findAnvil(&anvils, anvil_count, hit_f.x, hit_f.y, hit_f.z);
                    if (an_opt == null and anvil_count < anvils.len) {
                        anvils[anvil_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        an_opt = anvil_count;
                        anvil_count += 1;
                    }

                    const held_slot = &inventory.slots[selected_slot];
                    if (held_slot.item.isTool()) {
                        // Heavy smithing metalworking: forge-repair worn tool completely
                        tool_wear.uses[selected_slot] = 0;
                        audio.playAt(.anvil_clang, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 36.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.85, 0.70, 0.20 }, 10);
                        std.debug.print("forged and restored tool: {s}\n", .{ held_slot.item.name() });
                    } else {
                        // Metallic resonant hammer tap
                        audio.playAt(.anvil_clang, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.6, 24.0);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.45, 0.45, 0.50 }, 4);
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .enchantment_table) {
                    var et_opt = cache_mod.findEnchantmentTable(&enchantment_tables, enchantment_table_count, hit_f.x, hit_f.y, hit_f.z);
                    if (et_opt == null and enchantment_table_count < enchantment_tables.len) {
                        enchantment_tables[enchantment_table_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        et_opt = enchantment_table_count;
                        enchantment_table_count += 1;
                    }

                    const held_slot = &inventory.slots[selected_slot];
                    if (held_slot.item.isTool()) {
                        // Mystic enchantment honing: restore wear / repair held tool
                        tool_wear.uses[selected_slot] = 0;
                        audio.playAt(.glowstone_chime, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 32.0);
                        particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 12);
                        std.debug.print("enchantment table sharpened/repaired {s} at ({d},{d},{d})\n", .{ held_slot.item.name(), hit_f.x, hit_f.y, hit_f.z });
                    } else {
                        // Celestial grimoire glyph spark inspection
                        audio.playAt(.click_on, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.7, 24.0);
                        particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 4);
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .jukebox) {
                    var jb_opt = cache_mod.findJukebox(&jukeboxes, jukebox_count, hit_f.x, hit_f.y, hit_f.z);
                    if (jb_opt == null and jukebox_count < jukeboxes.len) {
                        jukeboxes[jukebox_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        jb_opt = jukebox_count;
                        jukebox_count += 1;
                    }

                    if (jb_opt) |ji| {
                        const jb = &jukeboxes[ji];
                        if (jb.playing_disc) |disc| {
                            // Eject currently inserted disc back to player
                            _ = inventory.addItem(disc, 1);
                            jb.playing_disc = null;
                            jb.play_timer = 0.0;
                            audio.playAt(.click_off, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.8, 30.0);
                            std.debug.print("jukebox ejected {s} at ({d},{d},{d})\n", .{ disc.name(), hit_f.x, hit_f.y, hit_f.z });
                        } else {
                            // Check if player holds a music disc
                            const held_slot = &inventory.slots[selected_slot];
                            if (held_slot.item == .music_disc_13 or held_slot.item == .music_disc_cat) {
                                const disc = held_slot.item;
                                held_slot.count -= 1;
                                if (held_slot.count == 0) held_slot.clear();

                                jb.playing_disc = disc;
                                jb.play_timer = 3.0;
                                const track_sound: audio_mod.synth.SoundType = if (disc == .music_disc_13) .record_13 else .record_cat;
                                audio.playAt(track_sound, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 1.0, 48.0);
                                particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 8);
                                std.debug.print("jukebox now playing {s} at ({d},{d},{d})\n", .{ disc.name(), hit_f.x, hit_f.y, hit_f.z });
                            }
                        }
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .note_block) {
                    var nb_opt = cache_mod.findNoteBlock(&note_blocks, note_block_count, hit_f.x, hit_f.y, hit_f.z);
                    if (nb_opt == null and note_block_count < note_blocks.len) {
                        note_blocks[note_block_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .pitch = 0 };
                        nb_opt = note_block_count;
                        note_block_count += 1;
                    }

                    if (nb_opt) |ni| {
                        const nb = &note_blocks[ni];
                        nb.pitch = if (nb.pitch < 24) nb.pitch + 1 else 0;

                        // Play sound when tuned
                        const floor_b = manager.getBlockWorld(hit_f.x, hit_f.y - 1, hit_f.z);
                        const inst = redstone_mod.getNoteInstrument(floor_b);
                        const snd: audio_mod.synth.SoundType = switch (inst) {
                            .bass => .note_bass,
                            .snare => .note_snare,
                            .chime => .note_chime,
                            .harp => .note_harp,
                        };
                        audio.playAt(snd, .{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, .{ player.pos.x, player.pos.y, player.pos.z }, 0.9, 32.0);
                        particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 4);
                        std.debug.print("tuned note block: {s} (semitones={d})\n", .{ @tagName(inst), nb.pitch });
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .daylight_detector or target == .daylight_detector_inverted) {
                    const new_mode: block_mod.BlockId = if (target == .daylight_detector) .daylight_detector_inverted else .daylight_detector;
                    if (try manager.editAndRemesh(hit_f.x, hit_f.y, hit_f.z, new_mode)) {
                        audio.play(.click_on, 0.7);
                        particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.85, 0.75, 0.45 }, 4);
                        std.debug.print("toggled daylight detector to {s}\n", .{@tagName(new_mode)});
                    }
                    flint_cooldown = interact_mod.flint_action_cooldown;
                } else if (target == .cauldron) {
                    var cs_opt = cache_mod.findCauldron(&cauldrons, cauldron_count, hit_f.x, hit_f.y, hit_f.z);
                    if (cs_opt == null and cauldron_count < cauldrons.len) {
                        cauldrons[cauldron_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        cs_opt = cauldron_count;
                        cauldron_count += 1;
                    }

                    if (cs_opt) |ci| {
                        const cs = &cauldrons[ci];
                        const held_item = inventory.slots[selected_slot].item;

                        if (held_item == .water_bucket and cs.fluid != .lava) {
                            cs.fluid = .water;
                            cs.level = 3;
                            inventory.slots[selected_slot].decrement(1);
                            audio.play(.splash, 0.8);
                            particles.spawnWaterSplash(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 8);
                            std.debug.print("filled cauldron with water (level=3)\n", .{});
                        } else if (held_item == .lava_bucket and cs.fluid != .water) {
                            cs.fluid = .lava;
                            cs.level = 3;
                            inventory.slots[selected_slot].decrement(1);
                            audio.play(.lava_pop, 0.85);
                            particles.spawnFlame(hit_f.x, hit_f.y + 1, hit_f.z, 8);
                            std.debug.print("filled cauldron with lava (level=3)\n", .{});
                        } else if (held_item == .glass and cs.fluid == .water and cs.level > 0) {
                            // Dip glass vial into water cauldron to scoop a water bottle
                            cs.level -= 1;
                            if (cs.level == 0) cs.fluid = .empty;
                            inventory.slots[selected_slot].decrement(1);
                            _ = inventory.addItem(.fire_resistance_potion, 1);
                            audio.play(.splash, 0.7);
                            particles.spawnWaterSplash(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.8, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 4);
                            std.debug.print("scooped water flask from cauldron (remaining level={d})\n", .{cs.level});
                        } else if (held_item == .none and cs.level > 0) {
                            // Empty-handed ladle scoops a bucket back if full basin
                            if (cs.level == 3 and cs.fluid == .water) {
                                _ = inventory.addItem(.water_bucket, 1);
                                cs.fluid = .empty;
                                cs.level = 0;
                                audio.play(.splash, 0.8);
                                std.debug.print("retrieved water bucket from cauldron\n", .{});
                            } else if (cs.level == 3 and cs.fluid == .lava) {
                                _ = inventory.addItem(.lava_bucket, 1);
                                cs.fluid = .empty;
                                cs.level = 0;
                                audio.play(.lava_pop, 0.85);
                                std.debug.print("retrieved lava bucket from cauldron\n", .{});
                            } else {
                                std.debug.print("cauldron status: fluid={s}, level={d}\n", .{ @tagName(cs.fluid), cs.level });
                            }
                        } else {
                            std.debug.print("cauldron status: fluid={s}, level={d}\n", .{ @tagName(cs.fluid), cs.level });
                        }
                    }
                    flint_cooldown = interact_mod.flint_feed_cooldown;
                } else if (target == .brewing_stand) {
                    var bs_opt = cache_mod.findBrewingStand(&brewing_stands, brewing_stand_count, hit_f.x, hit_f.y, hit_f.z);
                    if (bs_opt == null and brewing_stand_count < brewing_stands.len) {
                        brewing_stands[brewing_stand_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z };
                        bs_opt = brewing_stand_count;
                        brewing_stand_count += 1;
                    }

                    if (bs_opt) |bi| {
                        const bs = &brewing_stands[bi];
                        const held_item = inventory.slots[selected_slot].item;

                        if (held_item == .blaze_powder and bs.fuel < 20) {
                            bs.fuel += 1;
                            inventory.slots[selected_slot].decrement(1);
                            audio.play(.place_block, 0.7);
                            particles.spawnFlame(hit_f.x, hit_f.y + 1, hit_f.z, 4);
                            std.debug.print("loaded blaze powder fuel (fuel={d})\n", .{bs.fuel});
                        } else if (held_item == .fermented_spider_eye and bs.fermented_eyes < 16) {
                            bs.fermented_eyes += 1;
                            inventory.slots[selected_slot].decrement(1);
                            audio.play(.place_block, 0.7);
                            std.debug.print("loaded fermented spider eye reagent (eyes={d})\n", .{bs.fermented_eyes});
                        } else if (held_item == .spider_eye and bs.spider_eyes < 16) {
                            bs.spider_eyes += 1;
                            inventory.slots[selected_slot].decrement(1);
                            audio.play(.place_block, 0.7);
                            std.debug.print("loaded spider eye reagent (eyes={d})\n", .{bs.spider_eyes});
                        } else if (held_item == .nether_wart and bs.wart < 16) {
                            bs.wart += 1;
                            inventory.slots[selected_slot].decrement(1);
                            audio.play(.place_block, 0.7);
                            std.debug.print("loaded nether wart reagent (wart={d})\n", .{bs.wart});
                        } else if (held_item == .glass and bs.bottles < 3) {
                            bs.bottles += 1;
                            inventory.slots[selected_slot].decrement(1);
                            audio.play(.place_block, 0.7);
                            std.debug.print("loaded glass vial flask (bottles={d})\n", .{bs.bottles});
                        } else if (held_item == .none and bs.weakness_potions > 0) {
                            _ = inventory.addItem(.weakness_potion, 1);
                            bs.weakness_potions -= 1;
                            audio.play(.break_block, 0.7);
                            particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.45, 0.40, 0.50 }, 6);
                            std.debug.print("retrieved potion of weakness (remaining={d})\n", .{bs.weakness_potions});
                        } else if (held_item == .none and bs.poison_potions > 0) {
                            _ = inventory.addItem(.poison_potion, 1);
                            bs.poison_potions -= 1;
                            audio.play(.break_block, 0.7);
                            particles.spawnBlockDebris(hit_f.x, hit_f.y, hit_f.z, .{ 0.35, 0.75, 0.25 }, 6);
                            std.debug.print("retrieved potion of poison (remaining={d})\n", .{bs.poison_potions});
                        } else if (held_item == .none and bs.potions > 0) {
                            _ = inventory.addItem(.fire_resistance_potion, 1);
                            bs.potions -= 1;
                            audio.play(.break_block, 0.7);
                            particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 6);
                            std.debug.print("retrieved fire resistance potion (remaining={d})\n", .{bs.potions});
                        } else {
                            std.debug.print("brewing stand status: fuel={d}, ferm={d}, eyes={d}, wart={d}, bottles={d}, fire={d}, poison={d}, weak={d}\n", .{ bs.fuel, bs.fermented_eyes, bs.spider_eyes, bs.wart, bs.bottles, bs.potions, bs.poison_potions, bs.weakness_potions });
                        }
                    }
                    flint_cooldown = interact_mod.flint_feed_cooldown;
                } else if (target == .blast_furnace) {
                    const held_f = inventory.slots[selected_slot];
                    const is_ore = smelt_mod.isOreItem(@intFromEnum(held_f.item));
                    var fed = false;
                    var k_opt = cache_mod.findBlastFurnace(&blast_furnaces, blast_furnace_count, hit_f.x, hit_f.y, hit_f.z);
                    if (k_opt == null and cache_mod.canCreateFurnace(blast_furnace_count, blast_furnaces.len)) {
                        blast_furnaces[blast_furnace_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .t = 0, .fuel = 0, .input = smelt_mod.None };
                        k_opt = blast_furnace_count;
                        blast_furnace_count += 1;
                    }
                    if (k_opt) |k| {
                        switch (smelt_mod.evaluateFurnaceFeed(held_f.item == .coal, is_ore, blast_furnaces[k].fuel, blast_furnaces[k].input)) {
                            .add_fuel => {
                                blast_furnaces[k].fuel += 1;
                                inventory.slots[selected_slot].decrement(1);
                                fed = true;
                            },
                            .set_input => {
                                blast_furnaces[k].input = @intFromEnum(held_f.item);
                                inventory.slots[selected_slot].decrement(1);
                                fed = true;
                            },
                            .none => {},
                        }
                    }
                    if (fed) {
                        audio.play(.place_block, 0.7);
                        particles.spawnBurnSparks(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.9, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 6);
                    }
                    flint_cooldown = interact_mod.flint_edge_cooldown;
                } else if (target == .smoker) {
                    const held_f = inventory.slots[selected_slot];
                    const is_meat = smelt_mod.isFoodItem(@intFromEnum(held_f.item));
                    var fed = false;
                    var k_opt = cache_mod.findSmoker(&smokers, smoker_count, hit_f.x, hit_f.y, hit_f.z);
                    if (k_opt == null and cache_mod.canCreateFurnace(smoker_count, smokers.len)) {
                        smokers[smoker_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .t = 0, .fuel = 0, .input = smelt_mod.None };
                        k_opt = smoker_count;
                        smoker_count += 1;
                    }
                    if (k_opt) |k| {
                        switch (smelt_mod.evaluateFurnaceFeed(held_f.item == .coal, is_meat, smokers[k].fuel, smokers[k].input)) {
                            .add_fuel => {
                                smokers[k].fuel += 1;
                                inventory.slots[selected_slot].decrement(1);
                                fed = true;
                            },
                            .set_input => {
                                smokers[k].input = @intFromEnum(held_f.item);
                                inventory.slots[selected_slot].decrement(1);
                                fed = true;
                            },
                            .none => {},
                        }
                    }
                    if (fed) {
                        audio.play(.place_block, 0.7);
                        particles.spawnCampfireSmoke(hit_f.x, hit_f.y, hit_f.z, false, false, 4);
                    }
                    flint_cooldown = interact_mod.flint_edge_cooldown;
                } else if (target == .furnace) {
                    // feed held item as input or fuel
                    const held_f = inventory.slots[selected_slot];
                    const smeltable = switch (held_f.item) {
                        .raw_pork, .raw_mutton, .raw_cod, .raw_salmon, .kelp, .sand, .iron_ore, .ancient_debris => true,
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
                        const is_fuel = (held_f.item == .coal or held_f.item == .dried_kelp_block);
                        switch (smelt_mod.evaluateFurnaceFeed(is_fuel, smeltable, furnaces[k].fuel, furnaces[k].input)) {
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
                            if (portal_target_count < portal_targets.len) {
                                const cur_dim: portal_mod.Dimension = if (manager.is_nether) .nether else .overworld;
                                portal_targets[portal_target_count] = .{
                                    .x = frame.interior_min_x,
                                    .y = frame.interior_min_y,
                                    .z = frame.interior_min_z,
                                    .dim = cur_dim,
                                };
                                portal_target_count += 1;
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
                if (target == .lodestone) {
                    player.lodestone_target = math.Vec3.init(@as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5);
                    var attuned_item = false;
                    if (inventory.slots[selected_slot].item == .compass) {
                        inventory.slots[selected_slot].item = .lodestone_compass;
                        attuned_item = true;
                    }
                    audio.play(.glowstone_chime, 0.9);
                    particles.spawnLodestoneAttunement(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 0.5, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 24);
                    particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 12);
                    if (attuned_item) {
                        std.debug.print("lodestone compass attuned at ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                    } else {
                        std.debug.print("lodestone target bound ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                    }
                    flint_cooldown = interact_mod.flint_edge_cooldown;
                } else
                if (target == .respawn_anchor) {
                    var anc_idx: ?usize = null;
                    for (anchors[0..anchor_count], 0..) |anc, ai| {
                        if (anc.x == hit_f.x and anc.y == hit_f.y and anc.z == hit_f.z) {
                            anc_idx = ai;
                            break;
                        }
                    }
                    if (anc_idx == null and anchor_count < anchors.len) {
                        anchors[anchor_count] = .{ .x = hit_f.x, .y = hit_f.y, .z = hit_f.z, .charges = 0 };
                        anc_idx = anchor_count;
                        anchor_count += 1;
                    }
                    const cur_charges = if (anc_idx) |ai| anchors[ai].charges else 0;
                    const held_glow = (inventory.slots[selected_slot].item == .glowstone);
                    const action = interact_mod.evaluateAnchorInteract(manager.is_nether, cur_charges, held_glow);
                    switch (action) {
                        .charge_success => {
                            if (anc_idx) |ai| {
                                anchors[ai].charges += 1;
                                inventory.slots[selected_slot].decrement(1);
                                audio.play(.glowstone_chime, 0.9);
                                particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 16);
                                std.debug.print("respawn anchor charged: {d}/4\n", .{anchors[ai].charges});
                            }
                        },
                        .set_spawn => {
                            player.spawn_point = math.Vec3.init(@as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5);
                            audio.play(.portal_hum, 0.85);
                            particles.spawnGlowstoneShimmer(.{ @as(f32, @floatFromInt(hit_f.x)) + 0.5, @as(f32, @floatFromInt(hit_f.y)) + 1.0, @as(f32, @floatFromInt(hit_f.z)) + 0.5 }, 12);
                            std.debug.print("respawn anchor spawn point set ({d},{d},{d})\n", .{ hit_f.x, hit_f.y, hit_f.z });
                        },
                        .overworld_explode => {
                            // Violent overcharge detonation in Overworld!
                            const ex = hit_f.x;
                            const ey = hit_f.y;
                            const ez = hit_f.z;
                            _ = try manager.editAndRemesh(ex, ey, ez, .air);
                            audio.play(.break_block, 1.0);
                            particles.spawnBlockDebris(ex, ey, ez, .{ 0.95, 0.85, 0.2 }, 32);
                            particles.spawnFlame(ex, ey, ez, 24);
                            if (anc_idx) |ai| {
                                anchors[ai] = anchors[anchor_count - 1];
                                anchor_count -= 1;
                            }
                            // Sphere crater
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
                                            if (by > 0) _ = try manager.editAndRemesh(bx, by, bz, .air);
                                        }
                                    }
                                }
                            }
                            if (boom_mod.calculatePlayerBlastImpulse(player.pos.x, player.pos.y, player.pos.z, ex, ey, ez)) |imp| {
                                player.health = @max(0.0, player.health - imp.damage);
                                player.vel_y = imp.vel_y;
                                player.pos.x += imp.push_x;
                                player.pos.z += imp.push_z;
                                audio.play(.hurt, 1.0);
                            }
                            std.debug.print("overcharged respawn anchor exploded in Overworld!\n", .{});
                        },
                        .already_full => {
                            std.debug.print("respawn anchor already fully charged (4/4)\n", .{});
                        },
                        .no_charge_cannot_set => {
                            audio.play(.click_off, 0.6);
                            std.debug.print("respawn anchor has no charges (glowstone required)\n", .{});
                        },
                    }
                    flint_cooldown = interact_mod.flint_edge_cooldown;
                } else
                if (target.isFlammable()) {
                    particles.spawnFlame(hit_f.x, hit_f.y, hit_f.z, 14);
                    if (inventory.slots[selected_slot].item == .flint_and_steel) {
                        _ = tool_wear.use(selected_slot, inventory.slots[selected_slot].item.maxDurability());
                    }
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
                .cooked_pork, .cooked_mutton, .cooked_cod, .cooked_salmon => true,
                .raw_pork, .raw_mutton, .raw_cod, .raw_salmon => false,
                else => null,
            };
            if (held_eat.item == .fishing_rod) {
                // Cast fishing line into water: if aimed at water within 8m or player standing in water, catch fish
                const cast_dir = cam.front();
                const cast_hit = pick_mod.raycast(&pickSolid, cam.position, cast_dir, 8);
                var water_hit = player.in_water;
                if (!water_hit and cast_hit != null) {
                    const h = cast_hit.?;
                    const b_at = manager.getBlockWorld(h.x, h.y, h.z);
                    const b_above = manager.getBlockWorld(h.x + h.nx, h.y + h.ny, h.z + h.nz);
                    if (b_at == .water or b_above == .water or pickFluid(h.x, h.y, h.z) or pickFluid(h.x + h.nx, h.y + h.ny, h.z + h.nz)) {
                        water_hit = true;
                    }
                }
                if (water_hit) {
                    audio.play(.splash, 0.85);
                    particles.spawnWaterSplash(.{ player.pos.x + cast_dir.x * 2.0, player.pos.y, player.pos.z + cast_dir.z * 2.0 }, 10);
                    particles.spawnBubble(.{ player.pos.x + cast_dir.x * 2.0, player.pos.y + 0.3, player.pos.z + cast_dir.z * 2.0 }, 6);
                    // Deterministic fishing catch loot table:
                    // 50% Raw Cod, 25% Raw Salmon, 11% Tropical Fish, 8% Pufferfish, 6% Nautilus Shell (rare treasure)
                    const fish_roll: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(player.pos.x * 43.0 + player.pos.z * 67.0 + current_time * 19.0)))) % 100;
                    const caught_fish: inventory_mod.ItemType = if (fish_roll < 50)
                        .raw_cod
                    else if (fish_roll < 75)
                        .raw_salmon
                    else if (fish_roll < 86)
                        .tropical_fish
                    else if (fish_roll < 94)
                        .pufferfish
                    else
                        .nautilus_shell;

                    _ = inventory.addItem(caught_fish, 1);
                    if (tool_wear.use(selected_slot, inventory_mod.ItemType.fishing_rod.maxDurability())) {
                        inventory.slots[selected_slot].clear();
                        audio.play(.break_block, 0.8);
                        std.debug.print("fishing rod broke\n", .{});
                    }
                    toast.timer = 2.0;
                    toast.color = .{ 0.40, 0.75, 0.90 };
                    std.debug.print("caught {s} via fishing rod!\n", .{caught_fish.name()});
                } else {
                    audio.play(.bow_shoot, 0.6);
                    std.debug.print("cast fishing rod (no water caught)\n", .{});
                }
            } else if (held_eat.item == .trident) {
                // Right click with Trident:
                // If player is in water or eye underwater, activate Riptide surge!
                // Propels player swiftly in look direction with spiraling aquatic vortex.
                if (player.in_water or was_eye_underwater) {
                    player.launchRiptide();
                    const cf = cam.front();
                    player.vel_y = @max(player.vel_y, cf.y * 14.0 + 4.0);
                    // Riptide wears trident durability
                    if (tool_wear.use(selected_slot, inventory_mod.ItemType.trident.maxDurability())) {
                        inventory.slots[selected_slot].clear();
                        audio.play(.break_block, 0.8);
                        std.debug.print("trident broke during riptide surge\n", .{});
                    }
                    audio.play(.splash, 1.0);
                    audio.play(.mob_teleport, 0.7);
                    particles.spawnRiptideSpiral(.{ player.pos.x, player.pos.y, player.pos.z }, 16);
                    particles.spawnWaterSplash(.{ player.pos.x, player.pos.y, player.pos.z }, 12);
                    toast.timer = 2.0;
                    toast.color = .{ 0.25, 0.85, 0.95 };
                    std.debug.print("Trident Riptide surge launched!\n", .{});
                } else {
                    audio.play(.bow_shoot, 0.5);
                    std.debug.print("trident riptide requires water\n", .{});
                }
            } else if (player.is_gliding and held_eat.item == .fireworks_rocket) {
                player.boostWithRocket();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.burn_sizzle, 0.9);
                particles.spawnBurnSparks(.{ player.pos.x, player.pos.y, player.pos.z }, 12);
                std.debug.print("elytra rocket boost ignited!\n", .{});
            } else if (held_eat.item == .weakness_potion) {
                player.applyWeakness();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnBlockDebris(@intFromFloat(@floor(player.pos.x)), @intFromFloat(@floor(player.pos.y + 1)), @intFromFloat(@floor(player.pos.z)), .{ 0.45, 0.40, 0.50 }, 8);
                std.debug.print("drank potion of weakness (timer={d:.1}s)\n", .{player.weakness_timer});
            } else if (held_eat.item == .fermented_spider_eye) {
                player.applyWeakness();
                player.hunger = @min(20.0, player.hunger + 1.0);
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnBlockDebris(@intFromFloat(@floor(player.pos.x)), @intFromFloat(@floor(player.pos.y + 1)), @intFromFloat(@floor(player.pos.z)), .{ 0.45, 0.12, 0.22 }, 6);
                std.debug.print("ate fermented spider eye (weakened, timer={d:.1}s)\n", .{player.weakness_timer});
            } else if (held_eat.item == .poison_potion) {
                player.applyPoison();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnBlockDebris(@intFromFloat(@floor(player.pos.x)), @intFromFloat(@floor(player.pos.y + 1)), @intFromFloat(@floor(player.pos.z)), .{ 0.35, 0.75, 0.25 }, 8);
                std.debug.print("drank potion of poison (timer={d:.1}s)\n", .{player.poison_timer});
            } else if (held_eat.item == .pufferfish) {
                // Eating Pufferfish inflicts 10s Poison + 15s Hunger debuff, restores 1 hunger
                player.applyPoison();
                player.applyHungerDebuff();
                player.hunger = @min(20.0, player.hunger + 1.0);
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnBlockDebris(@intFromFloat(@floor(player.pos.x)), @intFromFloat(@floor(player.pos.y + 1)), @intFromFloat(@floor(player.pos.z)), .{ 0.80, 0.75, 0.20 }, 8);
                std.debug.print("ate pufferfish: severe toxic poisoning & hunger debuff!\n", .{});
            } else if (held_eat.item == .tropical_fish and player.hunger < 20.0) {
                player.hunger = @min(20.0, player.hunger + 1.0);
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.6);
                std.debug.print("ate tropical fish (hunger={d:.1})\n", .{player.hunger});
            } else if (held_eat.item == .spider_eye) {
                player.applyPoison();
                player.hunger = @min(20.0, player.hunger + 2.0);
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnBlockDebris(@intFromFloat(@floor(player.pos.x)), @intFromFloat(@floor(player.pos.y + 1)), @intFromFloat(@floor(player.pos.z)), .{ 0.65, 0.12, 0.18 }, 6);
                std.debug.print("ate spider eye (poisoned, timer={d:.1}s)\n", .{player.poison_timer});
            } else if (held_eat.item == .rotten_flesh) {
                player.applyHungerDebuff();
                player.hunger = @min(20.0, player.hunger + 4.0);
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnBlockDebris(@intFromFloat(@floor(player.pos.x)), @intFromFloat(@floor(player.pos.y + 1)), @intFromFloat(@floor(player.pos.z)), .{ 0.60, 0.38, 0.22 }, 6);
                std.debug.print("ate rotten flesh (hunger debuff active, timer={d:.1}s)\n", .{player.hunger_debuff_timer});
            } else if (held_eat.item == .fire_resistance_potion) {
                player.drinkFireResistance();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnBurnSparks(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 8);
                std.debug.print("drank fire resistance potion (timer={d:.1}s)\n", .{player.fire_resistance_timer});
            } else if (held_eat.item == .slow_falling_potion) {
                player.drinkSlowFalling();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnGlowstoneShimmer(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 12);
                std.debug.print("drank slow falling potion (timer={d:.1}s)\n", .{player.slow_falling_timer});
            } else if (held_eat.item == .water_breathing_potion) {
                player.drinkWaterBreathing();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                particles.spawnWaterSplash(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 10);
                std.debug.print("drank water breathing potion (timer={d:.1}s)\n", .{player.water_breathing_timer});
            } else if (held_eat.item == .chorus_fruit) {
                // Eating chorus fruit restores 4 hunger and teleports player to a random spot within 8 blocks
                player.hunger = @min(20.0, player.hunger + 4.0);
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                audio.play(.mob_teleport, 1.0);
                particles.spawnPortalParticles(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 20);

                // Disperse player randomly +/- 8 blocks horizontally
                const seed_u: u32 = @as(u32, @bitCast(@as(i32, @intFromFloat(player.pos.x * 16.0)))) *% 31 +%
                    @as(u32, @bitCast(@as(i32, @intFromFloat(player.pos.z * 16.0)))) *% 17 +%
                    @as(u32, @intFromFloat(player.hunger * 10.0));
                const dx: f32 = @as(f32, @floatFromInt(@as(i32, @intCast((seed_u >> 4) % 15)) - 7));
                const dz: f32 = @as(f32, @floatFromInt(@as(i32, @intCast((seed_u >> 12) % 15)) - 7));
                const new_x = player.pos.x + dx;
                const new_z = player.pos.z + dz;
                player.pos.x = new_x;
                player.pos.z = new_z;
                player.vel_y = 0.0;
                particles.spawnPortalParticles(.{ player.pos.x, player.pos.y + 0.8, player.pos.z }, 24);
                std.debug.print("ate chorus fruit; teleported to ({d:.1}, {d:.1}, {d:.1})\n", .{ player.pos.x, player.pos.y, player.pos.z });
            } else if (held_eat.item == .glass) {
                // If standing inside or near a dragon breath cloud, bottle Dragon's Breath!
                var bottled = false;
                for (vapor_clouds[0..vapor_cloud_count]) |vc| {
                    if (vc.effect == .dragons_breath and vc.isInside(player.pos.x, player.pos.y, player.pos.z)) {
                        inventory.slots[selected_slot].decrement(1);
                        _ = inventory.addItem(.dragons_breath, 1);
                        audio.play(.splash, 0.8);
                        particles.spawnPortalParticles(.{ player.pos.x, player.pos.y + 0.5, player.pos.z }, 8);
                        std.debug.print("bottled Dragon's Breath!\n", .{});
                        bottled = true;
                        break;
                    }
                }
                if (!bottled and player.hunger < 20.0) {
                    // Normal idle
                }
            } else if (held_eat.item == .lingering_poison_potion and vapor_cloud_count < vapor_clouds.len) {
                const target_pos = [3]f32{ player.pos.x + cam.front().x * 3.0, player.pos.y, player.pos.z + cam.front().z * 3.0 };
                vapor_clouds[vapor_cloud_count] = .{
                    .pos = target_pos,
                    .radius = 3.5,
                    .life = 10.0,
                    .max_life = 10.0,
                    .effect = .lingering_poison,
                };
                vapor_cloud_count += 1;
                inventory.slots[selected_slot].decrement(1);
                audio.play(.splash, 0.8);
                audio.play(.burn_sizzle, 0.7);
                particles.spawnPortalVortex(target_pos, 2.0, 16, 0.0);
                std.debug.print("deployed Lingering Poison Potion cloud!\n", .{});
            } else if (held_eat.item == .lingering_weakness_potion and vapor_cloud_count < vapor_clouds.len) {
                const target_pos = [3]f32{ player.pos.x + cam.front().x * 3.0, player.pos.y, player.pos.z + cam.front().z * 3.0 };
                vapor_clouds[vapor_cloud_count] = .{
                    .pos = target_pos,
                    .radius = 3.5,
                    .life = 10.0,
                    .max_life = 10.0,
                    .effect = .lingering_weakness,
                };
                vapor_cloud_count += 1;
                inventory.slots[selected_slot].decrement(1);
                audio.play(.splash, 0.8);
                audio.play(.burn_sizzle, 0.7);
                particles.spawnPortalVortex(target_pos, 2.0, 16, 0.0);
                std.debug.print("deployed Lingering Weakness Potion cloud!\n", .{});
            } else if (held_eat.item == .golden_apple) {
                player.eatGolden();
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.8);
                std.debug.print("ate golden apple (hp={d:.1})\n", .{player.health});
            } else if (held_eat.item == .dried_kelp and player.hunger < 20.0) {
                player.hunger = @min(20.0, player.hunger + 1.0);
                inventory.slots[selected_slot].decrement(1);
                audio.play(.eat, 0.6);
                std.debug.print("ate dried kelp (hunger={d:.1})\n", .{player.hunger});
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
