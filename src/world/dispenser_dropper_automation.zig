//! dispenser_dropper_automation.zig
//!
//! Milestone 405: Dispenser vs Dropper Actuation Matrix, Bucket Fluid Placement/Scoop,
//! Shears/Bone-Meal/Armor Equip & TNT Priming.
//!
//! Implements deterministic logic for Droppers and Dispensers in Zigcraft:
//! - DropperVsDispenserCrafting:
//!     Dropper: 7 cobblestone + 1 redstone_dust -> 1 dropper (no bow required!).
//!     Dispenser: 7 cobblestone + 1 redstone_dust + 1 bow (damaged 1-durability bow works:
//!       canCraftDispenserWithDamagedBow() == true) -> 1 dispenser.
//! - DropperBehavior:
//!     On redstone rising edge (4-tick / 0.20s delay), if facing a container (chest, hopper,
//!     furnace, barrel, shulker_box, crafter, brewing_stand), transfers 1 item directly into
//!     the container inventory; otherwise ejects 1 item entity into the world WITHOUT activating
//!     it (alwaysEjectsRawItemWhenNotFacingContainer() == true).
//! - DispenserActuationBehavior:
//!     - .water_bucket / .lava_bucket / .powder_snow_bucket: places fluid/snow source block in front
//!       and leaves an .empty_bucket inside the dispenser;
//!     - .empty_bucket: scoops fluid/snow source block in front into a filled bucket!
//!     - .tnt: places and immediately primes a live PrimedTnt entity (4.0s / 80-tick fuse).
//!     - .flint_and_steel: ignites fire/portal/TNT in front and consumes 1 durability
//!       (breaksAtZeroDurability: bool = true);
//!     - .fire_charge: shoots a blaze fireball along the facing axis.
//!     - .bone_meal: fertilizes crops/saplings/moss in front and consumes 1 bone meal.
//!     - .shears: shears sheep or harvests honeycomb from a full level-5 beehive in front without
//!       angering bees, consuming 1 durability.
//!     - .armor_or_carved_pumpkin_or_elytra: equips directly onto a player, armor stand, or
//!       villager/zombie standing in the block in front!

const std = @import("std");

// ============================================================================
// Core Constants
// ============================================================================

/// Activation delay upon redstone rising edge: 4 game ticks (0.20 seconds at 20 ticks/sec).
pub const activation_delay_ticks: u32 = 4;
pub const activation_delay_seconds: f32 = 0.20;

/// Dropper specific alias constants.
pub const dropper_activation_delay_ticks: u32 = 4;
pub const dropper_activation_delay_seconds: f32 = 0.20;

/// Dispenser specific alias constants.
pub const dispenser_activation_delay_ticks: u32 = 4;
pub const dispenser_activation_delay_seconds: f32 = 0.20;

/// Live Primed TNT fuse duration: 80 game ticks = 4.0 seconds.
pub const tnt_fuse_ticks: u32 = 80;
pub const tnt_fuse_seconds: f32 = 4.0;

/// Durability tools break when reaching 0 durability.
pub const breaks_at_zero_durability: bool = true;

/// Honey level required for beehive shears harvesting.
pub const beehive_max_honey_level: u8 = 5;

/// Honeycomb yield when shearing a level-5 beehive.
pub const beehive_honeycomb_yield: u8 = 3;

// ============================================================================
// Geometry & Direction
// ============================================================================

pub const Facing = enum {
    down,
    up,
    north,
    south,
    west,
    east,

    pub fn offset(self: Facing) BlockPos {
        return switch (self) {
            .down => .{ .x = 0, .y = -1, .z = 0 },
            .up => .{ .x = 0, .y = 1, .z = 0 },
            .north => .{ .x = 0, .y = 0, .z = -1 },
            .south => .{ .x = 0, .y = 0, .z = 1 },
            .west => .{ .x = -1, .y = 0, .z = 0 },
            .east => .{ .x = 1, .y = 0, .z = 0 },
        };
    }

    pub fn vector(self: Facing) Vec3 {
        return switch (self) {
            .down => .{ .x = 0.0, .y = -1.0, .z = 0.0 },
            .up => .{ .x = 0.0, .y = 1.0, .z = 0.0 },
            .north => .{ .x = 0.0, .y = 0.0, .z = -1.0 },
            .south => .{ .x = 0.0, .y = 0.0, .z = 1.0 },
            .west => .{ .x = -1.0, .y = 0.0, .z = 0.0 },
            .east => .{ .x = 1.0, .y = 0.0, .z = 0.0 },
        };
    }
};

pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn add(self: BlockPos, other: BlockPos) BlockPos {
        return .{
            .x = self.x + other.x,
            .y = self.y + other.y,
            .z = self.z + other.z,
        };
    }

    pub fn equals(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }
};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn scale(self: Vec3, s: f32) Vec3 {
        return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
    }
};

// ============================================================================
// Item & Inventory Model
// ============================================================================

pub const ItemKind = enum {
    none,
    cobblestone,
    redstone_dust,
    bow,
    dropper,
    dispenser,
    empty_bucket,
    water_bucket,
    lava_bucket,
    powder_snow_bucket,
    tnt,
    flint_and_steel,
    fire_charge,
    bone_meal,
    shears,
    carved_pumpkin,
    leather_helmet,
    iron_helmet,
    golden_helmet,
    diamond_helmet,
    netherite_helmet,
    leather_chestplate,
    iron_chestplate,
    golden_chestplate,
    diamond_chestplate,
    netherite_chestplate,
    elytra,
    leather_leggings,
    iron_leggings,
    golden_leggings,
    diamond_leggings,
    netherite_leggings,
    leather_boots,
    iron_boots,
    golden_boots,
    diamond_boots,
    netherite_boots,
    arrow,
    snowball,
    egg,
    honeycomb,
    wool,
    apple,
    dirt,

    pub fn isArmorOrHeadwearOrElytra(self: ItemKind) bool {
        return switch (self) {
            .carved_pumpkin,
            .leather_helmet,
            .iron_helmet,
            .golden_helmet,
            .diamond_helmet,
            .netherite_helmet,
            .leather_chestplate,
            .iron_chestplate,
            .golden_chestplate,
            .diamond_chestplate,
            .netherite_chestplate,
            .elytra,
            .leather_leggings,
            .iron_leggings,
            .golden_leggings,
            .diamond_leggings,
            .netherite_leggings,
            .leather_boots,
            .iron_boots,
            .golden_boots,
            .diamond_boots,
            .netherite_boots,
            => true,
            else => false,
        };
    }

    pub fn isFluidOrSnowBucket(self: ItemKind) bool {
        return switch (self) {
            .water_bucket, .lava_bucket, .powder_snow_bucket => true,
            else => false,
        };
    }
};

pub fn getDefaultMaxDurability(kind: ItemKind) u16 {
    return switch (kind) {
        .bow => 384,
        .flint_and_steel => 64,
        .shears => 238,
        .elytra => 432,
        .leather_helmet => 55,
        .leather_chestplate => 80,
        .leather_leggings => 75,
        .leather_boots => 65,
        .iron_helmet => 165,
        .iron_chestplate => 240,
        .iron_leggings => 225,
        .iron_boots => 195,
        .golden_helmet => 77,
        .golden_chestplate => 112,
        .golden_leggings => 105,
        .golden_boots => 91,
        .diamond_helmet => 363,
        .diamond_chestplate => 528,
        .diamond_leggings => 495,
        .diamond_boots => 429,
        .netherite_helmet => 407,
        .netherite_chestplate => 592,
        .netherite_leggings => 555,
        .netherite_boots => 481,
        else => 0,
    };
}

pub const ItemStack = struct {
    kind: ItemKind = .none,
    count: u8 = 0,
    durability: u16 = 0,
    max_durability: u16 = 0,

    pub fn init(kind: ItemKind, count: u8) ItemStack {
        const max_dur = getDefaultMaxDurability(kind);
        return .{
            .kind = kind,
            .count = count,
            .durability = max_dur,
            .max_durability = max_dur,
        };
    }

    pub fn initTool(kind: ItemKind, count: u8, durability: u16, max_durability: u16) ItemStack {
        return .{
            .kind = kind,
            .count = count,
            .durability = durability,
            .max_durability = max_durability,
        };
    }

    pub fn isEmpty(self: ItemStack) bool {
        return self.kind == .none or self.count == 0;
    }

    pub fn isDamaged(self: ItemStack) bool {
        return self.max_durability > 0 and self.durability < self.max_durability;
    }

    pub fn damageAmount(self: ItemStack) u16 {
        if (self.max_durability == 0 or self.durability >= self.max_durability) return 0;
        return self.max_durability - self.durability;
    }

    /// Consumes durability. If remaining durability <= amount and breaksAtZeroDurability is true,
    /// the tool breaks and the item stack is cleared (returns true).
    pub fn consumeDurability(self: *ItemStack, amount: u16, breaksAtZeroDurability: bool) bool {
        if (self.max_durability == 0) return false;
        if (self.durability <= amount) {
            if (breaksAtZeroDurability) {
                self.* = .{};
                return true;
            } else {
                self.durability = 0;
                return false;
            }
        } else {
            self.durability -= amount;
            return false;
        }
    }
};

// ============================================================================
// Container Definitions (Dropper Container Targets)
// ============================================================================

pub const ContainerType = enum {
    none,
    chest,
    hopper,
    furnace,
    barrel,
    shulker_box,
    crafter,
    brewing_stand,

    pub fn isContainer(self: ContainerType) bool {
        return self != .none;
    }
};

pub fn isRecognizedContainer(container: ContainerType) bool {
    return switch (container) {
        .chest, .hopper, .furnace, .barrel, .shulker_box, .crafter, .brewing_stand => true,
        .none => false,
    };
}

pub const ContainerInventory = struct {
    container_type: ContainerType,
    slots: [27]ItemStack = [_]ItemStack{.{}} ** 27,
    slot_count: usize = 27,

    pub fn init(container_type: ContainerType, slot_count: usize) ContainerInventory {
        return .{
            .container_type = container_type,
            .slot_count = @min(slot_count, 27),
        };
    }

    pub fn insertOne(self: *ContainerInventory, item: ItemStack) bool {
        if (item.isEmpty()) return false;
        // Merge with existing non-damaged matching item stack
        if (item.max_durability == 0) {
            for (self.slots[0..self.slot_count]) |*slot| {
                if (slot.kind == item.kind and slot.count < 64) {
                    slot.count += 1;
                    return true;
                }
            }
        }
        // Insert into first empty slot
        for (self.slots[0..self.slot_count]) |*slot| {
            if (slot.isEmpty()) {
                slot.* = item;
                slot.count = 1;
                return true;
            }
        }
        return false;
    }

    pub fn countItem(self: ContainerInventory, kind: ItemKind) usize {
        var total: usize = 0;
        for (self.slots[0..self.slot_count]) |slot| {
            if (slot.kind == kind) total += slot.count;
        }
        return total;
    }
};

// ============================================================================
// World Blocks & Entities
// ============================================================================

pub const WorldBlockKind = enum {
    air,
    water_source,
    lava_source,
    powder_snow,
    tnt,
    fire,
    crops,
    sapling,
    moss_block,
    beehive,
    obsidian_portal_frame,
    nether_portal,
    solid_block,
    container_block,
};

pub const WorldBlockState = struct {
    kind: WorldBlockKind = .air,
    growth_stage: u8 = 0,
    honey_level: u8 = 0,
    container_type: ContainerType = .none,
    container_inventory: ?ContainerInventory = null,

    pub fn initAir() WorldBlockState {
        return .{ .kind = .air };
    }

    pub fn initBeehive(honey_level: u8) WorldBlockState {
        return .{
            .kind = .beehive,
            .honey_level = honey_level,
        };
    }

    pub fn initCrops(stage: u8) WorldBlockState {
        return .{
            .kind = .crops,
            .growth_stage = stage,
        };
    }

    pub fn initContainer(ctype: ContainerType, slot_count: usize) WorldBlockState {
        return .{
            .kind = .container_block,
            .container_type = ctype,
            .container_inventory = ContainerInventory.init(ctype, slot_count),
        };
    }
};

pub const LivingEntityType = enum {
    player,
    armor_stand,
    villager,
    zombie,
    sheep,

    pub fn canWearArmor(self: LivingEntityType) bool {
        return switch (self) {
            .player, .armor_stand, .villager, .zombie => true,
            .sheep => false,
        };
    }
};

pub const EquipmentSlot = enum {
    head,
    chest,
    legs,
    feet,
};

pub const LivingEntity = struct {
    entity_type: LivingEntityType,
    head_slot: ?ItemStack = null,
    chest_slot: ?ItemStack = null,
    legs_slot: ?ItemStack = null,
    feet_slot: ?ItemStack = null,

    // Sheep specific
    is_sheared: bool = false,
    wool_color: u8 = 0,

    pub fn init(entity_type: LivingEntityType) LivingEntity {
        return .{ .entity_type = entity_type };
    }

    pub fn getEquipSlot(kind: ItemKind) ?EquipmentSlot {
        return switch (kind) {
            .carved_pumpkin,
            .leather_helmet,
            .iron_helmet,
            .golden_helmet,
            .diamond_helmet,
            .netherite_helmet,
            => .head,

            .leather_chestplate,
            .iron_chestplate,
            .golden_chestplate,
            .diamond_chestplate,
            .netherite_chestplate,
            .elytra,
            => .chest,

            .leather_leggings,
            .iron_leggings,
            .golden_leggings,
            .diamond_leggings,
            .netherite_leggings,
            => .legs,

            .leather_boots,
            .iron_boots,
            .golden_boots,
            .diamond_boots,
            .netherite_boots,
            => .feet,

            else => null,
        };
    }

    pub fn hasSlotEmpty(self: LivingEntity, slot: EquipmentSlot) bool {
        return switch (slot) {
            .head => self.head_slot == null,
            .chest => self.chest_slot == null,
            .legs => self.legs_slot == null,
            .feet => self.feet_slot == null,
        };
    }

    pub fn equip(self: *LivingEntity, item: ItemStack) bool {
        if (!self.entity_type.canWearArmor()) return false;
        const slot = getEquipSlot(item.kind) orelse return false;
        if (!self.hasSlotEmpty(slot)) return false;

        var single = item;
        single.count = 1;
        switch (slot) {
            .head => self.head_slot = single,
            .chest => self.chest_slot = single,
            .legs => self.legs_slot = single,
            .feet => self.feet_slot = single,
        }
        return true;
    }
};

pub const PrimedTnt = struct {
    position: Vec3,
    velocity: Vec3,
    fuse_ticks: u32 = tnt_fuse_ticks,
    fuse_seconds: f32 = tnt_fuse_seconds,

    pub fn tick(self: *PrimedTnt) bool {
        if (self.fuse_ticks > 0) {
            self.fuse_ticks -= 1;
            self.fuse_seconds = @as(f32, @floatFromInt(self.fuse_ticks)) / 20.0;
        }
        return self.fuse_ticks == 0;
    }
};

pub const ItemEntity = struct {
    item: ItemStack,
    position: Vec3,
    velocity: Vec3,
};

pub const BlazeFireball = struct {
    position: Vec3,
    direction: Vec3,
    speed: f32 = 1.5,
};

// ============================================================================
// 1. DropperVsDispenserCrafting
// ============================================================================

pub const DropperVsDispenserCrafting = struct {
    pub const required_cobblestone: u32 = 7;
    pub const required_redstone_dust: u32 = 1;
    pub const required_bow: u32 = 1;

    /// Dispenser crafting accepts bows of any durability (including 1-durability damaged bows).
    pub fn canCraftDispenserWithDamagedBow() bool {
        return true;
    }

    /// Dropper crafting check: 7 cobblestone + 1 redstone dust. No bow required.
    pub fn canCraftDropper(cobblestone_count: u32, redstone_count: u32) bool {
        return cobblestone_count >= required_cobblestone and redstone_count >= required_redstone_dust;
    }

    /// Dispenser crafting check: 7 cobblestone + 1 redstone dust + 1 bow.
    /// Even a damaged 1-durability bow is valid.
    pub fn canCraftDispenser(cobblestone_count: u32, redstone_count: u32, bow: ?ItemStack) bool {
        if (cobblestone_count < required_cobblestone or redstone_count < required_redstone_dust) return false;
        const b = bow orelse return false;
        if (b.kind != .bow or b.count < 1) return false;
        return true;
    }

    /// Consumes 7 cobblestone and 1 redstone dust to produce 1 dropper.
    pub fn craftDropper(cobblestone_count: *u32, redstone_count: *u32) ?ItemStack {
        if (!canCraftDropper(cobblestone_count.*, redstone_count.*)) return null;
        cobblestone_count.* -= required_cobblestone;
        redstone_count.* -= required_redstone_dust;
        return ItemStack.init(.dropper, 1);
    }

    /// Consumes 7 cobblestone, 1 redstone dust, and 1 bow to produce 1 dispenser.
    pub fn craftDispenser(cobblestone_count: *u32, redstone_count: *u32, bow: *?ItemStack) ?ItemStack {
        if (!canCraftDispenser(cobblestone_count.*, redstone_count.*, bow.*)) return null;
        cobblestone_count.* -= required_cobblestone;
        redstone_count.* -= required_redstone_dust;
        if (bow.*) |*b| {
            if (b.count <= 1) {
                bow.* = null;
            } else {
                b.count -= 1;
            }
        }
        return ItemStack.init(.dispenser, 1);
    }

    /// Crafts from a 3x3 grid layout:
    /// Dropper:
    ///   [cobble, cobble,   cobble]
    ///   [cobble, air/null, cobble]
    ///   [cobble, redstone, cobble]
    /// Dispenser:
    ///   [cobble, cobble,   cobble]
    ///   [cobble, bow,      cobble]
    ///   [cobble, redstone, cobble]
    pub fn craftFromGrid(grid: [3][3]?ItemStack) ?ItemStack {
        const outer_cobble = [_][2]usize{
            .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 },
            .{ 1, 0 }, .{ 1, 2 }, .{ 2, 0 },
            .{ 2, 2 },
        };
        for (outer_cobble) |pos| {
            const item = grid[pos[0]][pos[1]] orelse return null;
            if (item.kind != .cobblestone or item.count < 1) return null;
        }

        const redstone = grid[2][1] orelse return null;
        if (redstone.kind != .redstone_dust or redstone.count < 1) return null;

        const center = grid[1][1];
        if (center == null or center.?.isEmpty()) {
            return ItemStack.init(.dropper, 1);
        } else if (center.?.kind == .bow and center.?.count >= 1) {
            // Bow can have any durability, even 1 durability!
            return ItemStack.init(.dispenser, 1);
        }

        return null;
    }
};

// ============================================================================
// 2. DropperBehavior
// ============================================================================

pub const DropperActionResult = union(enum) {
    transferred_to_container: struct {
        container_type: ContainerType,
        item: ItemStack,
    },
    ejected_item_entity: ItemEntity,
    container_full: ItemStack,
    empty: void,
};

pub const DropperBehavior = struct {
    pub const activation_delay_ticks: u32 = 4;
    pub const activation_delay_seconds: f32 = 0.20;

    /// Dropper always ejects raw item entities into the world without activating them
    /// when not facing a container (e.g., TNT is dropped as an item, not primed).
    pub fn alwaysEjectsRawItemWhenNotFacingContainer() bool {
        return true;
    }

    pub fn isContainer(container: ContainerType) bool {
        return isRecognizedContainer(container);
    }

    pub fn detectRisingEdge(previous_powered: bool, current_powered: bool) bool {
        return !previous_powered and current_powered;
    }

    /// Actuates the dropper against a direct container inventory target.
    pub fn actuate(
        slots: *[9]ItemStack,
        facing: Facing,
        dropper_pos: BlockPos,
        target_container: ?*ContainerInventory,
    ) DropperActionResult {
        // Find first non-empty slot
        var selected_slot: ?usize = null;
        for (slots, 0..) |slot, i| {
            if (!slot.isEmpty()) {
                selected_slot = i;
                break;
            }
        }

        const slot_idx = selected_slot orelse return .empty;
        const item_to_move = slots[slot_idx];
        var single_item = item_to_move;
        single_item.count = 1;

        if (target_container) |container| {
            if (isRecognizedContainer(container.container_type)) {
                if (container.insertOne(single_item)) {
                    slots[slot_idx].count -= 1;
                    if (slots[slot_idx].count == 0) {
                        slots[slot_idx] = .{};
                    }
                    return .{
                        .transferred_to_container = .{
                            .container_type = container.container_type,
                            .item = single_item,
                        },
                    };
                } else {
                    return .{ .container_full = single_item };
                }
            }
        }

        // When not facing a recognized container: always eject raw item into world without activating
        slots[slot_idx].count -= 1;
        if (slots[slot_idx].count == 0) {
            slots[slot_idx] = .{};
        }

        const target_pos = dropper_pos.add(facing.offset());
        const facing_vec = facing.vector();
        const spawn_pos = Vec3{
            .x = @as(f32, @floatFromInt(target_pos.x)) + 0.5,
            .y = @as(f32, @floatFromInt(target_pos.y)) + 0.5,
            .z = @as(f32, @floatFromInt(target_pos.z)) + 0.5,
        };
        const velocity = Vec3{
            .x = facing_vec.x * 0.3,
            .y = facing_vec.y * 0.3 + 0.1,
            .z = facing_vec.z * 0.3,
        };

        return .{
            .ejected_item_entity = .{
                .item = single_item,
                .position = spawn_pos,
                .velocity = velocity,
            },
        };
    }

    /// Actuates the dropper against a world block state. If the block is a container, transfers
    /// into its container inventory; otherwise ejects raw item entity.
    pub fn actuateWorld(
        slots: *[9]ItemStack,
        facing: Facing,
        dropper_pos: BlockPos,
        target_block: ?*WorldBlockState,
    ) DropperActionResult {
        if (target_block) |block| {
            if (block.container_inventory) |*inv| {
                return actuate(slots, facing, dropper_pos, inv);
            }
        }
        return actuate(slots, facing, dropper_pos, null);
    }
};

// ============================================================================
// 3. DispenserActuationBehavior
// ============================================================================

pub const DispenserActionResult = union(enum) {
    placed_fluid_or_snow: struct {
        placed_block: WorldBlockKind,
        leftover_in_dispenser: ItemStack,
    },
    scooped_fluid_or_snow: struct {
        scooped_block: WorldBlockKind,
        filled_bucket: ItemStack,
    },
    primed_tnt: PrimedTnt,
    ignited: struct {
        ignited_kind: enum { fire, nether_portal, primed_tnt },
        tool_broke: bool,
        remaining_durability: u16,
    },
    shot_fire_charge: BlazeFireball,
    fertilized: struct {
        target: WorldBlockKind,
        new_growth_stage: u8,
    },
    sheared_sheep: struct {
        wool_yield: u8,
        tool_broke: bool,
        remaining_durability: u16,
    },
    harvested_beehive: struct {
        honeycomb_yield: u8,
        bees_angered: bool,
        tool_broke: bool,
        remaining_durability: u16,
    },
    equipped_armor: struct {
        target_entity: LivingEntityType,
        slot: EquipmentSlot,
        equipped_item: ItemStack,
    },
    ejected_raw_item: ItemEntity,
    empty: void,
    failed_no_action: void,
};

pub const DispenserActuationBehavior = struct {
    pub const activation_delay_ticks: u32 = 4;
    pub const activation_delay_seconds: f32 = 0.20;
    pub const tnt_fuse_ticks: u32 = 80;
    pub const tnt_fuse_seconds: f32 = 4.0;
    pub const breaksAtZeroDurability: bool = true;
    pub const beehive_honey_level_ready: u8 = 5;
    pub const beehive_honeycomb_yield: u8 = 3;

    pub fn canCraftDispenserWithDamagedBow() bool {
        return true;
    }

    pub fn detectRisingEdge(previous_powered: bool, current_powered: bool) bool {
        return !previous_powered and current_powered;
    }

    /// Handles fluid / powder snow bucket placement:
    /// places source block in front and leaves an empty bucket inside the dispenser.
    pub fn actuateBucketPlacement(
        slots: *[9]ItemStack,
        slot_idx: usize,
        facing: Facing,
        dispenser_pos: BlockPos,
        target_block: *WorldBlockState,
    ) ?DispenserActionResult {
        _ = dispenser_pos;
        _ = facing;
        const bucket_kind = slots[slot_idx].kind;
        const target_kind: WorldBlockKind = switch (bucket_kind) {
            .water_bucket => .water_source,
            .lava_bucket => .lava_source,
            .powder_snow_bucket => .powder_snow,
            else => return null,
        };

        target_block.kind = target_kind;

        const empty_bucket = ItemStack.init(.empty_bucket, 1);
        if (slots[slot_idx].count == 1) {
            slots[slot_idx] = empty_bucket;
        } else {
            slots[slot_idx].count -= 1;
            var placed = false;
            for (slots) |*slot| {
                if (slot.kind == .empty_bucket and slot.count < 16) {
                    slot.count += 1;
                    placed = true;
                    break;
                }
            }
            if (!placed) {
                for (slots) |*slot| {
                    if (slot.isEmpty()) {
                        slot.* = empty_bucket;
                        placed = true;
                        break;
                    }
                }
            }
        }

        return .{
            .placed_fluid_or_snow = .{
                .placed_block = target_kind,
                .leftover_in_dispenser = empty_bucket,
            },
        };
    }

    /// Handles empty bucket scooping:
    /// scoops water source, lava source, or powder snow block in front into filled bucket.
    pub fn actuateBucketScoop(
        slots: *[9]ItemStack,
        slot_idx: usize,
        facing: Facing,
        dispenser_pos: BlockPos,
        target_block: *WorldBlockState,
    ) ?DispenserActionResult {
        _ = dispenser_pos;
        _ = facing;
        if (slots[slot_idx].kind != .empty_bucket) return null;

        const filled_kind: ItemKind = switch (target_block.kind) {
            .water_source => .water_bucket,
            .lava_source => .lava_bucket,
            .powder_snow => .powder_snow_bucket,
            else => return null,
        };

        const original_block = target_block.kind;
        target_block.kind = .air;

        const filled_bucket = ItemStack.init(filled_kind, 1);
        if (slots[slot_idx].count == 1) {
            slots[slot_idx] = filled_bucket;
        } else {
            slots[slot_idx].count -= 1;
            var placed = false;
            for (slots) |*slot| {
                if (slot.isEmpty()) {
                    slot.* = filled_bucket;
                    placed = true;
                    break;
                }
            }
            if (!placed) {
                // If dispenser is full, default to replacing the current slot
                slots[slot_idx] = filled_bucket;
            }
        }

        return .{
            .scooped_fluid_or_snow = .{
                .scooped_block = original_block,
                .filled_bucket = filled_bucket,
            },
        };
    }

    /// Handles TNT placement and priming:
    /// places and immediately primes a live PrimedTnt entity (4.0s / 80-tick fuse).
    pub fn actuateTnt(
        slots: *[9]ItemStack,
        slot_idx: usize,
        facing: Facing,
        dispenser_pos: BlockPos,
    ) DispenserActionResult {
        slots[slot_idx].count -= 1;
        if (slots[slot_idx].count == 0) {
            slots[slot_idx] = .{};
        }

        const target_pos = dispenser_pos.add(facing.offset());
        const facing_vec = facing.vector();
        const spawn_pos = Vec3{
            .x = @as(f32, @floatFromInt(target_pos.x)) + 0.5,
            .y = @as(f32, @floatFromInt(target_pos.y)) + 0.5,
            .z = @as(f32, @floatFromInt(target_pos.z)) + 0.5,
        };
        const velocity = Vec3{
            .x = facing_vec.x * 0.15,
            .y = facing_vec.y * 0.15 + 0.1,
            .z = facing_vec.z * 0.15,
        };

        return .{
            .primed_tnt = .{
                .position = spawn_pos,
                .velocity = velocity,
                .fuse_ticks = DispenserActuationBehavior.tnt_fuse_ticks,
                .fuse_seconds = DispenserActuationBehavior.tnt_fuse_seconds,
            },
        };
    }

    /// Handles flint and steel ignition:
    /// ignites fire/portal/TNT in front and consumes 1 durability (breaksAtZeroDurability: bool = true).
    pub fn actuateFlintAndSteel(
        slots: *[9]ItemStack,
        slot_idx: usize,
        facing: Facing,
        dispenser_pos: BlockPos,
        target_block: *WorldBlockState,
    ) DispenserActionResult {
        _ = facing;
        _ = dispenser_pos;
        var ignite_result: ?@typeInfo(DispenserActionResult).@"union".fields[3].type = null;

        if (target_block.kind == .tnt) {
            target_block.kind = .air;
            ignite_result = .{
                .ignited_kind = .primed_tnt,
                .tool_broke = false,
                .remaining_durability = 0,
            };
        } else if (target_block.kind == .obsidian_portal_frame) {
            target_block.kind = .nether_portal;
            ignite_result = .{
                .ignited_kind = .nether_portal,
                .tool_broke = false,
                .remaining_durability = 0,
            };
        } else if (target_block.kind == .air) {
            target_block.kind = .fire;
            ignite_result = .{
                .ignited_kind = .fire,
                .tool_broke = false,
                .remaining_durability = 0,
            };
        }

        const broke = slots[slot_idx].consumeDurability(1, breaksAtZeroDurability);
        const rem = if (broke) 0 else slots[slot_idx].durability;

        if (ignite_result) |*res| {
            res.tool_broke = broke;
            res.remaining_durability = rem;
            return .{ .ignited = res.* };
        }

        return .failed_no_action;
    }

    /// Handles fire charge launch: shoots a blaze fireball along the facing axis.
    pub fn actuateFireCharge(
        slots: *[9]ItemStack,
        slot_idx: usize,
        facing: Facing,
        dispenser_pos: BlockPos,
    ) DispenserActionResult {
        slots[slot_idx].count -= 1;
        if (slots[slot_idx].count == 0) {
            slots[slot_idx] = .{};
        }

        const target_pos = dispenser_pos.add(facing.offset());
        const facing_vec = facing.vector();
        const spawn_pos = Vec3{
            .x = @as(f32, @floatFromInt(target_pos.x)) + 0.5,
            .y = @as(f32, @floatFromInt(target_pos.y)) + 0.5,
            .z = @as(f32, @floatFromInt(target_pos.z)) + 0.5,
        };

        return .{
            .shot_fire_charge = .{
                .position = spawn_pos,
                .direction = facing_vec,
                .speed = 1.5,
            },
        };
    }

    /// Handles bone meal fertilization: fertilizes crops/saplings/moss in front and consumes 1 bone meal.
    pub fn actuateBoneMeal(
        slots: *[9]ItemStack,
        slot_idx: usize,
        target_block: *WorldBlockState,
    ) ?DispenserActionResult {
        if (slots[slot_idx].kind != .bone_meal) return null;

        switch (target_block.kind) {
            .crops => {
                slots[slot_idx].count -= 1;
                if (slots[slot_idx].count == 0) slots[slot_idx] = .{};
                target_block.growth_stage = @min(target_block.growth_stage + 1, 7);
                return .{
                    .fertilized = .{
                        .target = .crops,
                        .new_growth_stage = target_block.growth_stage,
                    },
                };
            },
            .sapling => {
                slots[slot_idx].count -= 1;
                if (slots[slot_idx].count == 0) slots[slot_idx] = .{};
                target_block.growth_stage += 1;
                return .{
                    .fertilized = .{
                        .target = .sapling,
                        .new_growth_stage = target_block.growth_stage,
                    },
                };
            },
            .moss_block => {
                slots[slot_idx].count -= 1;
                if (slots[slot_idx].count == 0) slots[slot_idx] = .{};
                target_block.growth_stage += 1;
                return .{
                    .fertilized = .{
                        .target = .moss_block,
                        .new_growth_stage = target_block.growth_stage,
                    },
                };
            },
            else => return null,
        }
    }

    /// Handles shears actuation:
    /// shears sheep or harvests honeycomb from a full level-5 beehive in front without angering bees,
    /// consuming 1 durability (breaksAtZeroDurability: bool = true).
    pub fn actuateShears(
        slots: *[9]ItemStack,
        slot_idx: usize,
        target_block: ?*WorldBlockState,
        target_entity: ?*LivingEntity,
    ) ?DispenserActionResult {
        if (slots[slot_idx].kind != .shears) return null;

        // Check living entity in front first (sheep)
        if (target_entity) |entity| {
            if (entity.entity_type == .sheep and !entity.is_sheared) {
                entity.is_sheared = true;
                const broke = slots[slot_idx].consumeDurability(1, breaksAtZeroDurability);
                const rem = if (broke) 0 else slots[slot_idx].durability;
                return .{
                    .sheared_sheep = .{
                        .wool_yield = 3,
                        .tool_broke = broke,
                        .remaining_durability = rem,
                    },
                };
            }
        }

        // Check beehive block
        if (target_block) |block| {
            if (block.kind == .beehive and block.honey_level >= beehive_honey_level_ready) {
                block.honey_level = 0;
                const broke = slots[slot_idx].consumeDurability(1, breaksAtZeroDurability);
                const rem = if (broke) 0 else slots[slot_idx].durability;
                return .{
                    .harvested_beehive = .{
                        .honeycomb_yield = DispenserActuationBehavior.beehive_honeycomb_yield,
                        .bees_angered = false, // Dispensers NEVER anger bees!
                        .tool_broke = broke,
                        .remaining_durability = rem,
                    },
                };
            }
        }

        return null;
    }

    /// Handles equipping armor / carved pumpkin / elytra directly onto an entity standing in front.
    pub fn actuateArmor(
        slots: *[9]ItemStack,
        slot_idx: usize,
        target_entity: ?*LivingEntity,
    ) ?DispenserActionResult {
        const item = slots[slot_idx];
        if (!item.kind.isArmorOrHeadwearOrElytra()) return null;

        const entity = target_entity orelse return null;
        if (!entity.entity_type.canWearArmor()) return null;

        const slot = LivingEntity.getEquipSlot(item.kind) orelse return null;
        if (entity.equip(item)) {
            slots[slot_idx].count -= 1;
            if (slots[slot_idx].count == 0) {
                slots[slot_idx] = .{};
            }
            return .{
                .equipped_armor = .{
                    .target_entity = entity.entity_type,
                    .slot = slot,
                    .equipped_item = item,
                },
            };
        }

        return null;
    }

    /// Master actuation logic for Dispenser:
    /// Dispatches actuation depending on the item kind in the selected slot.
    pub fn actuate(
        slots: *[9]ItemStack,
        facing: Facing,
        dispenser_pos: BlockPos,
        target_block: ?*WorldBlockState,
        target_entity: ?*LivingEntity,
    ) DispenserActionResult {
        var selected_slot: ?usize = null;
        for (slots, 0..) |slot, i| {
            if (!slot.isEmpty()) {
                selected_slot = i;
                break;
            }
        }

        const slot_idx = selected_slot orelse return .empty;
        const item = slots[slot_idx];

        // 1. Fluid & snow bucket placement
        if (item.kind.isFluidOrSnowBucket()) {
            if (target_block) |block| {
                if (block.kind == .air) {
                    if (actuateBucketPlacement(slots, slot_idx, facing, dispenser_pos, block)) |res| {
                        return res;
                    }
                }
            }
        }

        // 2. Empty bucket scoop
        if (item.kind == .empty_bucket) {
            if (target_block) |block| {
                if (actuateBucketScoop(slots, slot_idx, facing, dispenser_pos, block)) |res| {
                    return res;
                }
            }
        }

        // 3. TNT priming
        if (item.kind == .tnt) {
            return actuateTnt(slots, slot_idx, facing, dispenser_pos);
        }

        // 4. Flint and Steel
        if (item.kind == .flint_and_steel) {
            if (target_block) |block| {
                const res = actuateFlintAndSteel(slots, slot_idx, facing, dispenser_pos, block);
                if (res != .failed_no_action) return res;
            }
        }

        // 5. Fire Charge
        if (item.kind == .fire_charge) {
            return actuateFireCharge(slots, slot_idx, facing, dispenser_pos);
        }

        // 6. Bone Meal
        if (item.kind == .bone_meal) {
            if (target_block) |block| {
                if (actuateBoneMeal(slots, slot_idx, block)) |res| {
                    return res;
                }
            }
        }

        // 7. Shears
        if (item.kind == .shears) {
            if (actuateShears(slots, slot_idx, target_block, target_entity)) |res| {
                return res;
            }
        }

        // 8. Armor / Pumpkin / Elytra equip
        if (item.kind.isArmorOrHeadwearOrElytra()) {
            if (actuateArmor(slots, slot_idx, target_entity)) |res| {
                return res;
            }
        }

        // Fallback: Dispense item gently into the world as a raw item entity
        slots[slot_idx].count -= 1;
        var single_item = item;
        single_item.count = 1;
        if (slots[slot_idx].count == 0) {
            slots[slot_idx] = .{};
        }

        const target_pos = dispenser_pos.add(facing.offset());
        const facing_vec = facing.vector();
        const spawn_pos = Vec3{
            .x = @as(f32, @floatFromInt(target_pos.x)) + 0.5,
            .y = @as(f32, @floatFromInt(target_pos.y)) + 0.5,
            .z = @as(f32, @floatFromInt(target_pos.z)) + 0.5,
        };
        const velocity = Vec3{
            .x = facing_vec.x * 0.3,
            .y = facing_vec.y * 0.3 + 0.1,
            .z = facing_vec.z * 0.3,
        };

        return .{
            .ejected_raw_item = .{
                .item = single_item,
                .position = spawn_pos,
                .velocity = velocity,
            },
        };
    }
};

// ============================================================================
// State Machines for World Integration
// ============================================================================

pub const DispenserState = struct {
    slots: [9]ItemStack = [_]ItemStack{.{}} ** 9,
    facing: Facing = .north,
    position: BlockPos = .{ .x = 0, .y = 0, .z = 0 },
    is_powered: bool = false,
    scheduled_activation_ticks: u32 = 0,

    pub fn init(facing: Facing, pos: BlockPos) DispenserState {
        return .{
            .facing = facing,
            .position = pos,
        };
    }

    pub fn onRedstoneInput(self: *DispenserState, powered: bool) bool {
        const rising = !self.is_powered and powered;
        self.is_powered = powered;
        if (rising) {
            self.scheduled_activation_ticks = activation_delay_ticks;
        }
        return rising;
    }

    pub fn tick(
        self: *DispenserState,
        target_block: ?*WorldBlockState,
        target_entity: ?*LivingEntity,
    ) ?DispenserActionResult {
        if (self.scheduled_activation_ticks > 0) {
            self.scheduled_activation_ticks -= 1;
            if (self.scheduled_activation_ticks == 0) {
                return DispenserActuationBehavior.actuate(&self.slots, self.facing, self.position, target_block, target_entity);
            }
        }
        return null;
    }

    pub fn actuateImmediate(
        self: *DispenserState,
        target_block: ?*WorldBlockState,
        target_entity: ?*LivingEntity,
    ) DispenserActionResult {
        return DispenserActuationBehavior.actuate(&self.slots, self.facing, self.position, target_block, target_entity);
    }
};

pub const DropperState = struct {
    slots: [9]ItemStack = [_]ItemStack{.{}} ** 9,
    facing: Facing = .north,
    position: BlockPos = .{ .x = 0, .y = 0, .z = 0 },
    is_powered: bool = false,
    scheduled_activation_ticks: u32 = 0,

    pub fn init(facing: Facing, pos: BlockPos) DropperState {
        return .{
            .facing = facing,
            .position = pos,
        };
    }

    pub fn onRedstoneInput(self: *DropperState, powered: bool) bool {
        const rising = !self.is_powered and powered;
        self.is_powered = powered;
        if (rising) {
            self.scheduled_activation_ticks = activation_delay_ticks;
        }
        return rising;
    }

    pub fn tick(
        self: *DropperState,
        target_container: ?*ContainerInventory,
    ) ?DropperActionResult {
        if (self.scheduled_activation_ticks > 0) {
            self.scheduled_activation_ticks -= 1;
            if (self.scheduled_activation_ticks == 0) {
                return DropperBehavior.actuate(&self.slots, self.facing, self.position, target_container);
            }
        }
        return null;
    }

    pub fn actuateImmediate(
        self: *DropperState,
        target_container: ?*ContainerInventory,
    ) DropperActionResult {
        return DropperBehavior.actuate(&self.slots, self.facing, self.position, target_container);
    }
};

// ============================================================================
// Unit Tests
// ============================================================================

test "1: DropperVsDispenserCrafting: dropper crafting requires 7 cobblestone and 1 redstone dust without bow" {
    var cobble: u32 = 7;
    var redstone: u32 = 1;

    try std.testing.expect(DropperVsDispenserCrafting.canCraftDropper(cobble, redstone));
    try std.testing.expect(!DropperVsDispenserCrafting.canCraftDropper(6, redstone));
    try std.testing.expect(!DropperVsDispenserCrafting.canCraftDropper(cobble, 0));

    const dropper_output = DropperVsDispenserCrafting.craftDropper(&cobble, &redstone);
    try std.testing.expect(dropper_output != null);
    try std.testing.expectEqual(ItemKind.dropper, dropper_output.?.kind);
    try std.testing.expectEqual(@as(u8, 1), dropper_output.?.count);
    try std.testing.expectEqual(@as(u32, 0), cobble);
    try std.testing.expectEqual(@as(u32, 0), redstone);
}

test "2: DropperVsDispenserCrafting: dispenser crafting accepts undamaged bow" {
    var cobble: u32 = 10;
    var redstone: u32 = 2;
    var bow: ?ItemStack = ItemStack.init(.bow, 1);

    try std.testing.expect(DropperVsDispenserCrafting.canCraftDispenser(cobble, redstone, bow));
    const disp = DropperVsDispenserCrafting.craftDispenser(&cobble, &redstone, &bow);
    try std.testing.expect(disp != null);
    try std.testing.expectEqual(ItemKind.dispenser, disp.?.kind);
    try std.testing.expectEqual(@as(u32, 3), cobble);
    try std.testing.expectEqual(@as(u32, 1), redstone);
    try std.testing.expect(bow == null);
}

test "3: DropperVsDispenserCrafting: dispenser crafting accepts damaged 1-durability bow (canCraftDispenserWithDamagedBow == true)" {
    try std.testing.expect(DropperVsDispenserCrafting.canCraftDispenserWithDamagedBow());

    var cobble: u32 = 7;
    var redstone: u32 = 1;
    // Severely damaged bow with 1 durability remaining out of 384
    var damaged_bow: ?ItemStack = ItemStack.initTool(.bow, 1, 1, 384);
    try std.testing.expect(damaged_bow.?.isDamaged());
    try std.testing.expectEqual(@as(u16, 1), damaged_bow.?.durability);

    try std.testing.expect(DropperVsDispenserCrafting.canCraftDispenser(cobble, redstone, damaged_bow));
    const disp = DropperVsDispenserCrafting.craftDispenser(&cobble, &redstone, &damaged_bow);
    try std.testing.expect(disp != null);
    try std.testing.expectEqual(ItemKind.dispenser, disp.?.kind);
    try std.testing.expect(damaged_bow == null);
}

test "4: DropperVsDispenserCrafting: 3x3 grid crafting matches dropper and dispenser recipe layouts" {
    var grid: [3][3]?ItemStack = [_][3]?ItemStack{[_]?ItemStack{null} ** 3} ** 3;
    // Fill 7 cobblestone in outer ring
    grid[0][0] = ItemStack.init(.cobblestone, 1);
    grid[0][1] = ItemStack.init(.cobblestone, 1);
    grid[0][2] = ItemStack.init(.cobblestone, 1);
    grid[1][0] = ItemStack.init(.cobblestone, 1);
    grid[1][2] = ItemStack.init(.cobblestone, 1);
    grid[2][0] = ItemStack.init(.cobblestone, 1);
    grid[2][2] = ItemStack.init(.cobblestone, 1);
    // Redstone at bottom center
    grid[2][1] = ItemStack.init(.redstone_dust, 1);

    // Empty center -> crafts Dropper
    grid[1][1] = null;
    const dropper_item = DropperVsDispenserCrafting.craftFromGrid(grid);
    try std.testing.expect(dropper_item != null);
    try std.testing.expectEqual(ItemKind.dropper, dropper_item.?.kind);

    // Damaged bow in center -> crafts Dispenser
    grid[1][1] = ItemStack.initTool(.bow, 1, 5, 384);
    const dispenser_item = DropperVsDispenserCrafting.craftFromGrid(grid);
    try std.testing.expect(dispenser_item != null);
    try std.testing.expectEqual(ItemKind.dispenser, dispenser_item.?.kind);
}

test "5: DropperBehavior: redstone rising edge triggers 4-tick / 0.20s actuation delay" {
    try std.testing.expectEqual(@as(u32, 4), DropperBehavior.activation_delay_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 0.20), DropperBehavior.activation_delay_seconds, 0.001);

    var dropper = DropperState.init(.north, .{ .x = 10, .y = 64, .z = 20 });
    dropper.slots[0] = ItemStack.init(.cobblestone, 5);

    // Low to low: no rising edge
    try std.testing.expect(!dropper.onRedstoneInput(false));
    try std.testing.expectEqual(@as(u32, 0), dropper.scheduled_activation_ticks);

    // Low to high: rising edge schedules 4 ticks
    try std.testing.expect(dropper.onRedstoneInput(true));
    try std.testing.expectEqual(@as(u32, 4), dropper.scheduled_activation_ticks);

    // High to high: no rising edge
    try std.testing.expect(!dropper.onRedstoneInput(true));

    // Tick 1
    var res = dropper.tick(null);
    try std.testing.expect(res == null);
    try std.testing.expectEqual(@as(u32, 3), dropper.scheduled_activation_ticks);

    // Tick 2
    res = dropper.tick(null);
    try std.testing.expect(res == null);
    // Tick 3
    res = dropper.tick(null);
    try std.testing.expect(res == null);

    // Tick 4: actuates!
    res = dropper.tick(null);
    try std.testing.expect(res != null);
    try std.testing.expectEqual(std.meta.Tag(DropperActionResult).ejected_item_entity, std.meta.activeTag(res.?));
    try std.testing.expectEqual(ItemKind.cobblestone, res.?.ejected_item_entity.item.kind);
    try std.testing.expectEqual(@as(u8, 4), dropper.slots[0].count);
}

test "6: DropperBehavior: transfers 1 item directly into facing chest, hopper, furnace, barrel, shulker_box, crafter, brewing_stand" {
    const test_containers = [_]ContainerType{
        .chest,
        .hopper,
        .furnace,
        .barrel,
        .shulker_box,
        .crafter,
        .brewing_stand,
    };

    for (test_containers) |ctype| {
        try std.testing.expect(DropperBehavior.isContainer(ctype));

        var dropper = DropperState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dropper.slots[0] = ItemStack.init(.iron_helmet, 1);

        var container = ContainerInventory.init(ctype, 9);
        try std.testing.expectEqual(@as(usize, 0), container.countItem(.iron_helmet));

        const res = dropper.actuateImmediate(&container);
        try std.testing.expectEqual(std.meta.Tag(DropperActionResult).transferred_to_container, std.meta.activeTag(res));
        try std.testing.expectEqual(ctype, res.transferred_to_container.container_type);
        try std.testing.expectEqual(ItemKind.iron_helmet, res.transferred_to_container.item.kind);

        // Verify item is now in container and consumed from dropper
        try std.testing.expectEqual(@as(usize, 1), container.countItem(.iron_helmet));
        try std.testing.expect(dropper.slots[0].isEmpty());
    }
}

test "7: DropperBehavior: alwaysEjectsRawItemWhenNotFacingContainer is true, ejecting raw TNT and water bucket without activating" {
    try std.testing.expect(DropperBehavior.alwaysEjectsRawItemWhenNotFacingContainer());

    var dropper = DropperState.init(.east, .{ .x = 0, .y = 60, .z = 0 });
    dropper.slots[0] = ItemStack.init(.tnt, 2);
    dropper.slots[1] = ItemStack.init(.water_bucket, 1);

    // Actuate 1: TNT is ejected as raw item, NOT primed!
    const res1 = dropper.actuateImmediate(null);
    try std.testing.expectEqual(std.meta.Tag(DropperActionResult).ejected_item_entity, std.meta.activeTag(res1));
    try std.testing.expectEqual(ItemKind.tnt, res1.ejected_item_entity.item.kind);
    try std.testing.expectEqual(@as(u8, 1), res1.ejected_item_entity.item.count);
    try std.testing.expectEqual(@as(u8, 1), dropper.slots[0].count);

    // Actuate 2: Second TNT ejected as raw item
    const res2 = dropper.actuateImmediate(null);
    try std.testing.expectEqual(std.meta.Tag(DropperActionResult).ejected_item_entity, std.meta.activeTag(res2));
    try std.testing.expect(dropper.slots[0].isEmpty());

    // Actuate 3: Water bucket is ejected as raw item, NOT placing water!
    const res3 = dropper.actuateImmediate(null);
    try std.testing.expectEqual(std.meta.Tag(DropperActionResult).ejected_item_entity, std.meta.activeTag(res3));
    try std.testing.expectEqual(ItemKind.water_bucket, res3.ejected_item_entity.item.kind);
    try std.testing.expect(dropper.slots[1].isEmpty());
}

test "8: DispenserActuationBehavior: water, lava, and powder snow buckets place fluid/snow blocks and leave empty bucket" {
    const buckets = [_]struct { bucket: ItemKind, expected_block: WorldBlockKind }{
        .{ .bucket = .water_bucket, .expected_block = .water_source },
        .{ .bucket = .lava_bucket, .expected_block = .lava_source },
        .{ .bucket = .powder_snow_bucket, .expected_block = .powder_snow },
    };

    for (buckets) |b| {
        var dispenser = DispenserState.init(.north, .{ .x = 5, .y = 64, .z = 5 });
        dispenser.slots[0] = ItemStack.init(b.bucket, 1);

        var front_block = WorldBlockState.initAir();
        const res = dispenser.actuateImmediate(&front_block, null);

        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).placed_fluid_or_snow, std.meta.activeTag(res));
        try std.testing.expectEqual(b.expected_block, res.placed_fluid_or_snow.placed_block);
        try std.testing.expectEqual(b.expected_block, front_block.kind);

        // Dispenser slot must now contain empty_bucket!
        try std.testing.expectEqual(ItemKind.empty_bucket, dispenser.slots[0].kind);
        try std.testing.expectEqual(@as(u8, 1), dispenser.slots[0].count);
    }
}

test "9: DispenserActuationBehavior: empty bucket scoops water source, lava source, and powder snow block into filled buckets" {
    const scoops = [_]struct { target_block: WorldBlockKind, expected_bucket: ItemKind }{
        .{ .target_block = .water_source, .expected_bucket = .water_bucket },
        .{ .target_block = .lava_source, .expected_bucket = .lava_bucket },
        .{ .target_block = .powder_snow, .expected_bucket = .powder_snow_bucket },
    };

    for (scoops) |s| {
        var dispenser = DispenserState.init(.south, .{ .x = 1, .y = 64, .z = 1 });
        dispenser.slots[0] = ItemStack.init(.empty_bucket, 1);

        var front_block = WorldBlockState{ .kind = s.target_block };
        const res = dispenser.actuateImmediate(&front_block, null);

        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).scooped_fluid_or_snow, std.meta.activeTag(res));
        try std.testing.expectEqual(s.target_block, res.scooped_fluid_or_snow.scooped_block);
        try std.testing.expectEqual(s.expected_bucket, res.scooped_fluid_or_snow.filled_bucket.kind);

        // Target block scooped into air
        try std.testing.expectEqual(WorldBlockKind.air, front_block.kind);

        // Dispenser slot replaced with filled bucket
        try std.testing.expectEqual(s.expected_bucket, dispenser.slots[0].kind);
        try std.testing.expectEqual(@as(u8, 1), dispenser.slots[0].count);
    }
}

test "10: DispenserActuationBehavior: TNT placement primes live PrimedTnt with 4.0s / 80-tick fuse" {
    try std.testing.expectEqual(@as(u32, 80), DispenserActuationBehavior.tnt_fuse_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), DispenserActuationBehavior.tnt_fuse_seconds, 0.001);

    var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 10, .z = 0 });
    dispenser.slots[0] = ItemStack.init(.tnt, 3);

    const res = dispenser.actuateImmediate(null, null);
    try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).primed_tnt, std.meta.activeTag(res));

    var live_tnt = res.primed_tnt;
    try std.testing.expectEqual(@as(u32, 80), live_tnt.fuse_ticks);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), live_tnt.fuse_seconds, 0.001);
    try std.testing.expectEqual(@as(u8, 2), dispenser.slots[0].count);

    // Tick the primed TNT through 79 ticks: not detonated yet
    var i: usize = 0;
    while (i < 79) : (i += 1) {
        try std.testing.expect(!live_tnt.tick());
    }
    try std.testing.expectEqual(@as(u32, 1), live_tnt.fuse_ticks);

    // 80th tick: detonates!
    try std.testing.expect(live_tnt.tick());
    try std.testing.expectEqual(@as(u32, 0), live_tnt.fuse_ticks);
}

test "11: DispenserActuationBehavior: flint and steel ignites air fire, obsidian portal, and primes TNT block, consuming durability" {
    try std.testing.expect(DispenserActuationBehavior.breaksAtZeroDurability);

    // Case A: Air -> Fire
    {
        var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dispenser.slots[0] = ItemStack.initTool(.flint_and_steel, 1, 64, 64);
        var air_block = WorldBlockState.initAir();

        const res = dispenser.actuateImmediate(&air_block, null);
        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).ignited, std.meta.activeTag(res));
        try std.testing.expectEqual(.fire, res.ignited.ignited_kind);
        try std.testing.expectEqual(WorldBlockKind.fire, air_block.kind);
        try std.testing.expectEqual(@as(u16, 63), dispenser.slots[0].durability);
        try std.testing.expect(!res.ignited.tool_broke);
    }

    // Case B: Obsidian Frame -> Nether Portal
    {
        var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dispenser.slots[0] = ItemStack.initTool(.flint_and_steel, 1, 63, 64);
        var portal_frame = WorldBlockState{ .kind = .obsidian_portal_frame };

        const res = dispenser.actuateImmediate(&portal_frame, null);
        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).ignited, std.meta.activeTag(res));
        try std.testing.expectEqual(.nether_portal, res.ignited.ignited_kind);
        try std.testing.expectEqual(WorldBlockKind.nether_portal, portal_frame.kind);
        try std.testing.expectEqual(@as(u16, 62), dispenser.slots[0].durability);
    }

    // Case C: TNT block -> Primed TNT
    {
        var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dispenser.slots[0] = ItemStack.initTool(.flint_and_steel, 1, 62, 64);
        var tnt_block = WorldBlockState{ .kind = .tnt };

        const res = dispenser.actuateImmediate(&tnt_block, null);
        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).ignited, std.meta.activeTag(res));
        try std.testing.expectEqual(.primed_tnt, res.ignited.ignited_kind);
        try std.testing.expectEqual(WorldBlockKind.air, tnt_block.kind);
        try std.testing.expectEqual(@as(u16, 61), dispenser.slots[0].durability);
    }
}

test "12: DispenserActuationBehavior: flint and steel breaks at zero durability (breaksAtZeroDurability == true)" {
    var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
    // Flint and steel with only 1 durability left
    dispenser.slots[0] = ItemStack.initTool(.flint_and_steel, 1, 1, 64);
    var air_block = WorldBlockState.initAir();

    const res = dispenser.actuateImmediate(&air_block, null);
    try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).ignited, std.meta.activeTag(res));
    try std.testing.expect(res.ignited.tool_broke);
    try std.testing.expectEqual(@as(u16, 0), res.ignited.remaining_durability);

    // Tool should be broken and cleared from slot
    try std.testing.expect(dispenser.slots[0].isEmpty());
}

test "13: DispenserActuationBehavior: fire charge shoots blaze fireball along facing axis" {
    var dispenser = DispenserState.init(.east, .{ .x = 10, .y = 20, .z = 30 });
    dispenser.slots[0] = ItemStack.init(.fire_charge, 4);

    const res = dispenser.actuateImmediate(null, null);
    try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).shot_fire_charge, std.meta.activeTag(res));

    const fireball = res.shot_fire_charge;
    try std.testing.expectEqual(@as(f32, 1.0), fireball.direction.x);
    try std.testing.expectEqual(@as(f32, 0.0), fireball.direction.y);
    try std.testing.expectEqual(@as(f32, 0.0), fireball.direction.z);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), fireball.speed, 0.001);
    try std.testing.expectEqual(@as(u8, 3), dispenser.slots[0].count);
}

test "14: DispenserActuationBehavior: bone meal fertilizes crops advancing stage, saplings, and moss block" {
    // Crops
    {
        var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dispenser.slots[0] = ItemStack.init(.bone_meal, 3);
        var crops = WorldBlockState.initCrops(2);

        const res = dispenser.actuateImmediate(&crops, null);
        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).fertilized, std.meta.activeTag(res));
        try std.testing.expectEqual(@as(u8, 3), res.fertilized.new_growth_stage);
        try std.testing.expectEqual(@as(u8, 3), crops.growth_stage);
        try std.testing.expectEqual(@as(u8, 2), dispenser.slots[0].count);
    }

    // Sapling
    {
        var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dispenser.slots[0] = ItemStack.init(.bone_meal, 1);
        var sapling = WorldBlockState{ .kind = .sapling, .growth_stage = 0 };

        const res = dispenser.actuateImmediate(&sapling, null);
        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).fertilized, std.meta.activeTag(res));
        try std.testing.expectEqual(@as(u8, 1), sapling.growth_stage);
        try std.testing.expect(dispenser.slots[0].isEmpty());
    }

    // Moss block
    {
        var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dispenser.slots[0] = ItemStack.init(.bone_meal, 1);
        var moss = WorldBlockState{ .kind = .moss_block, .growth_stage = 0 };

        const res = dispenser.actuateImmediate(&moss, null);
        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).fertilized, std.meta.activeTag(res));
        try std.testing.expectEqual(@as(u8, 1), moss.growth_stage);
        try std.testing.expect(dispenser.slots[0].isEmpty());
    }
}

test "15: DispenserActuationBehavior: shears sheep yielding wool and harvests level-5 beehive without angering bees" {
    // Shearing sheep
    {
        var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dispenser.slots[0] = ItemStack.initTool(.shears, 1, 238, 238);
        var sheep = LivingEntity.init(.sheep);

        const res = dispenser.actuateImmediate(null, &sheep);
        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).sheared_sheep, std.meta.activeTag(res));
        try std.testing.expect(sheep.is_sheared);
        try std.testing.expectEqual(@as(u8, 3), res.sheared_sheep.wool_yield);
        try std.testing.expectEqual(@as(u16, 237), dispenser.slots[0].durability);
        try std.testing.expect(!res.sheared_sheep.tool_broke);
    }

    // Harvesting Beehive level 5: yields 3 honeycomb, does NOT anger bees!
    {
        var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dispenser.slots[0] = ItemStack.initTool(.shears, 1, 237, 238);
        var hive = WorldBlockState.initBeehive(5);

        const res = dispenser.actuateImmediate(&hive, null);
        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).harvested_beehive, std.meta.activeTag(res));
        try std.testing.expectEqual(@as(u8, 3), res.harvested_beehive.honeycomb_yield);
        try std.testing.expect(!res.harvested_beehive.bees_angered); // Safe harvesting without angering bees!
        try std.testing.expectEqual(@as(u8, 0), hive.honey_level);
        try std.testing.expectEqual(@as(u16, 236), dispenser.slots[0].durability);
    }

    // Shears with 1 durability left breaks on beehive harvest
    {
        var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
        dispenser.slots[0] = ItemStack.initTool(.shears, 1, 1, 238);
        var hive = WorldBlockState.initBeehive(5);

        const res = dispenser.actuateImmediate(&hive, null);
        try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).harvested_beehive, std.meta.activeTag(res));
        try std.testing.expect(res.harvested_beehive.tool_broke);
        try std.testing.expect(dispenser.slots[0].isEmpty());
    }
}

test "16: DispenserActuationBehavior: armor, carved pumpkin, and elytra equip directly onto player, armor stand, villager, zombie" {
    const targets = [_]LivingEntityType{ .player, .armor_stand, .villager, .zombie };

    for (targets) |target_type| {
        var entity = LivingEntity.init(target_type);

        // 1. Equip Carved Pumpkin on head
        {
            var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
            dispenser.slots[0] = ItemStack.init(.carved_pumpkin, 1);
            const res = dispenser.actuateImmediate(null, &entity);
            try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).equipped_armor, std.meta.activeTag(res));
            try std.testing.expectEqual(EquipmentSlot.head, res.equipped_armor.slot);
            try std.testing.expectEqual(ItemKind.carved_pumpkin, entity.head_slot.?.kind);
            try std.testing.expect(dispenser.slots[0].isEmpty());
        }

        // 2. Equip Elytra on chest
        {
            var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
            dispenser.slots[0] = ItemStack.init(.elytra, 1);
            const res = dispenser.actuateImmediate(null, &entity);
            try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).equipped_armor, std.meta.activeTag(res));
            try std.testing.expectEqual(EquipmentSlot.chest, res.equipped_armor.slot);
            try std.testing.expectEqual(ItemKind.elytra, entity.chest_slot.?.kind);
        }

        // 3. Equip Diamond Leggings on legs
        {
            var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
            dispenser.slots[0] = ItemStack.init(.diamond_leggings, 1);
            const res = dispenser.actuateImmediate(null, &entity);
            try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).equipped_armor, std.meta.activeTag(res));
            try std.testing.expectEqual(EquipmentSlot.legs, res.equipped_armor.slot);
            try std.testing.expectEqual(ItemKind.diamond_leggings, entity.legs_slot.?.kind);
        }

        // 4. Equip Netherite Boots on feet
        {
            var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
            dispenser.slots[0] = ItemStack.init(.netherite_boots, 1);
            const res = dispenser.actuateImmediate(null, &entity);
            try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).equipped_armor, std.meta.activeTag(res));
            try std.testing.expectEqual(EquipmentSlot.feet, res.equipped_armor.slot);
            try std.testing.expectEqual(ItemKind.netherite_boots, entity.feet_slot.?.kind);
        }
    }
}

test "17: DispenserActuationBehavior: armor equip fails and drops raw item when slot already occupied" {
    var entity = LivingEntity.init(.player);
    entity.head_slot = ItemStack.init(.diamond_helmet, 1);

    var dispenser = DispenserState.init(.north, .{ .x = 0, .y = 0, .z = 0 });
    dispenser.slots[0] = ItemStack.init(.iron_helmet, 1);

    // Head slot is already occupied, falls back to ejecting raw item entity
    const res = dispenser.actuateImmediate(null, &entity);
    try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).ejected_raw_item, std.meta.activeTag(res));
    try std.testing.expectEqual(ItemKind.iron_helmet, res.ejected_raw_item.item.kind);
    // Entity's diamond helmet remains intact
    try std.testing.expectEqual(ItemKind.diamond_helmet, entity.head_slot.?.kind);
}

test "18: DispenserState and DropperState: stateful simulation of redstone delays and immediate actuation" {
    var dispenser = DispenserState.init(.south, .{ .x = 10, .y = 60, .z = -5 });
    dispenser.slots[0] = ItemStack.init(.water_bucket, 1);

    var front_block = WorldBlockState.initAir();
    try std.testing.expect(dispenser.onRedstoneInput(true));
    try std.testing.expectEqual(@as(u32, 4), dispenser.scheduled_activation_ticks);

    _ = dispenser.tick(&front_block, null);
    _ = dispenser.tick(&front_block, null);
    _ = dispenser.tick(&front_block, null);
    const act_res = dispenser.tick(&front_block, null);

    try std.testing.expect(act_res != null);
    try std.testing.expectEqual(std.meta.Tag(DispenserActionResult).placed_fluid_or_snow, std.meta.activeTag(act_res.?));
    try std.testing.expectEqual(WorldBlockKind.water_source, front_block.kind);
    try std.testing.expectEqual(ItemKind.empty_bucket, dispenser.slots[0].kind);
}
