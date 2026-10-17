const std = @import("std");
const block = @import("block.zig");
pub const BlockId = block.BlockId;

// ============================================================================
// Workstation Block Types
// ============================================================================

/// The 13 functional workstation blocks in Minecraft corresponding to the 13
/// employable villager professions.
pub const WorkstationBlock = enum(u8) {
    blast_furnace,
    smoker,
    cartography_table,
    brewing_stand,
    composter,
    barrel,
    fletching_table,
    cauldron,
    lectern,
    stonecutter,
    loom,
    smithing_table,
    grindstone,

    /// Convert to the engine's canonical BlockId.
    pub fn toBlockId(self: WorkstationBlock) BlockId {
        return switch (self) {
            .blast_furnace => .blast_furnace,
            .smoker => .smoker,
            .cartography_table => .cartography_table,
            .brewing_stand => .brewing_stand,
            .composter => .composter,
            .barrel => .barrel,
            .fletching_table => .fletching_table,
            .cauldron => .cauldron,
            .lectern => .lectern,
            .stonecutter => .stonecutter,
            .loom => .loom,
            .smithing_table => .smithing_table,
            .grindstone => .grindstone,
        };
    }

    /// Match a world BlockId to a WorkstationBlock if it is one.
    pub fn fromBlockId(id: BlockId) ?WorkstationBlock {
        return switch (id) {
            .blast_furnace => .blast_furnace,
            .smoker => .smoker,
            .cartography_table => .cartography_table,
            .brewing_stand => .brewing_stand,
            .composter => .composter,
            .barrel => .barrel,
            .fletching_table => .fletching_table,
            .cauldron => .cauldron,
            .lectern => .lectern,
            .stonecutter => .stonecutter,
            .loom => .loom,
            .smithing_table => .smithing_table,
            .grindstone => .grindstone,
            else => null,
        };
    }

    /// User-facing display name for the workstation.
    pub fn displayName(self: WorkstationBlock) []const u8 {
        return switch (self) {
            .blast_furnace => "Blast Furnace",
            .smoker => "Smoker",
            .cartography_table => "Cartography Table",
            .brewing_stand => "Brewing Stand",
            .composter => "Composter",
            .barrel => "Barrel",
            .fletching_table => "Fletching Table",
            .cauldron => "Cauldron",
            .lectern => "Lectern",
            .stonecutter => "Stonecutter",
            .loom => "Loom",
            .smithing_table => "Smithing Table",
            .grindstone => "Grindstone",
        };
    }
};

// ============================================================================
// Villager Professions
// ============================================================================

/// Villager professions. Includes:
/// - `.unemployed` (can claim any workstation to acquire a profession)
/// - `.nitwit_green_robe` (green robe; can never claim a job site or work)
/// - 13 working professions, each tied to a unique workstation block.
pub const VillagerProfession = enum(u8) {
    unemployed,
    nitwit_green_robe,
    armorer,
    butcher,
    cartographer,
    cleric,
    farmer,
    fisherman,
    fletcher,
    leatherworker,
    librarian,
    mason,
    shepherd,
    toolsmith,
    weaponsmith,

    /// Whether this villager type is capable of claiming a job-site workstation.
    /// Nitwits (`.nitwit_green_robe`) can NEVER claim a job site.
    /// Unemployed villagers and employed villagers can claim job sites.
    pub fn canClaimJobSite(self: VillagerProfession) bool {
        return self != .nitwit_green_robe;
    }

    /// The workstation block associated with this profession, or null for
    /// unemployed and nitwit.
    pub fn workstation(self: VillagerProfession) ?WorkstationBlock {
        return switch (self) {
            .armorer => .blast_furnace,
            .butcher => .smoker,
            .cartographer => .cartography_table,
            .cleric => .brewing_stand,
            .farmer => .composter,
            .fisherman => .barrel,
            .fletcher => .fletching_table,
            .leatherworker => .cauldron,
            .librarian => .lectern,
            .mason => .stonecutter,
            .shepherd => .loom,
            .toolsmith => .smithing_table,
            .weaponsmith => .grindstone,
            .unemployed, .nitwit_green_robe => null,
        };
    }

    /// The canonical BlockId for this profession's workstation, if any.
    pub fn workstationBlock(self: VillagerProfession) ?BlockId {
        if (self.workstation()) |ws| {
            return ws.toBlockId();
        }
        return null;
    }

    /// Map a workstation block to its corresponding profession.
    pub fn fromWorkstation(ws: WorkstationBlock) VillagerProfession {
        return switch (ws) {
            .blast_furnace => .armorer,
            .smoker => .butcher,
            .cartography_table => .cartographer,
            .brewing_stand => .cleric,
            .composter => .farmer,
            .barrel => .fisherman,
            .fletching_table => .fletcher,
            .cauldron => .leatherworker,
            .lectern => .librarian,
            .stonecutter => .mason,
            .loom => .shepherd,
            .smithing_table => .toolsmith,
            .grindstone => .weaponsmith,
        };
    }

    /// Map an engine BlockId to a profession if it is a workstation.
    pub fn fromBlockId(id: BlockId) ?VillagerProfession {
        if (WorkstationBlock.fromBlockId(id)) |ws| {
            return VillagerProfession.fromWorkstation(ws);
        }
        return null;
    }

    /// Check whether this villager profession can claim a specific workstation block.
    /// - Nitwits cannot claim any workstation.
    /// - Unemployed villagers can claim any of the 13 workstations.
    /// - Employed villagers can only claim their matching workstation.
    pub fn canClaimWorkstation(self: VillagerProfession, ws: WorkstationBlock) bool {
        if (!self.canClaimJobSite()) return false;
        if (self == .unemployed) return true;
        if (self.workstation()) |my_ws| {
            return my_ws == ws;
        }
        return false;
    }

    /// Whether this profession has an active occupation (not unemployed and not nitwit).
    pub fn isEmployed(self: VillagerProfession) bool {
        return self != .unemployed and self != .nitwit_green_robe;
    }

    /// Whether this is a green-robed nitwit.
    pub fn isNitwit(self: VillagerProfession) bool {
        return self == .nitwit_green_robe;
    }

    /// User-visible name of the profession.
    pub fn displayName(self: VillagerProfession) []const u8 {
        return switch (self) {
            .unemployed => "Unemployed",
            .nitwit_green_robe => "Nitwit",
            .armorer => "Armorer",
            .butcher => "Butcher",
            .cartographer => "Cartographer",
            .cleric => "Cleric",
            .farmer => "Farmer",
            .fisherman => "Fisherman",
            .fletcher => "Fletcher",
            .leatherworker => "Leatherworker",
            .librarian => "Librarian",
            .mason => "Mason",
            .shepherd => "Shepherd",
            .toolsmith => "Toolsmith",
            .weaponsmith => "Weaponsmith",
        };
    }
};

pub const fromWorkstation = VillagerProfession.fromWorkstation;
pub const fromBlockId = VillagerProfession.fromBlockId;

// ============================================================================
// Villager Trade Tiers
// ============================================================================

/// Trade tiers in Minecraft trading:
/// - Novice: 0 XP
/// - Apprentice: 10 XP
/// - Journeyman: 70 XP
/// - Expert: 150 XP
/// - Master: 250 XP
pub const VillagerTradeTier = enum(u8) {
    novice = 1,
    apprentice = 2,
    journeyman = 3,
    expert = 4,
    master = 5,

    /// Returns the minimum XP required to achieve this tier.
    pub fn minXp(self: VillagerTradeTier) u16 {
        return switch (self) {
            .novice => 0,
            .apprentice => 10,
            .journeyman => 70,
            .expert => 150,
            .master => 250,
        };
    }

    /// Resolves the trade tier corresponding to the given cumulative XP.
    pub fn tierForXp(xp: u16) VillagerTradeTier {
        if (xp >= 250) return .master;
        if (xp >= 150) return .expert;
        if (xp >= 70) return .journeyman;
        if (xp >= 10) return .apprentice;
        return .novice;
    }

    /// 1-based level index (1 = Novice .. 5 = Master).
    pub fn level(self: VillagerTradeTier) u8 {
        return @intFromEnum(self);
    }

    /// Minecraft belt badge material name.
    pub fn badgeName(self: VillagerTradeTier) []const u8 {
        return switch (self) {
            .novice => "Stone",
            .apprentice => "Iron",
            .journeyman => "Gold",
            .expert => "Emerald",
            .master => "Diamond",
        };
    }

    /// The next trade tier, or null if already at Master.
    pub fn nextTier(self: VillagerTradeTier) ?VillagerTradeTier {
        return switch (self) {
            .novice => .apprentice,
            .apprentice => .journeyman,
            .journeyman => .expert,
            .expert => .master,
            .master => null,
        };
    }

    /// Minimum XP required to reach the next tier, or null if Master.
    pub fn xpForNextTier(self: VillagerTradeTier) ?u16 {
        if (self.nextTier()) |next| {
            return next.minXp();
        }
        return null;
    }
};

/// Resolves trade tier from XP.
pub const tierForXp = VillagerTradeTier.tierForXp;

// ============================================================================
// Profession Lock Rule & Trade Re-rolling
// ============================================================================

/// Rules governing profession locking and trade re-rolling.
/// A Villager with `xp == 0` loses its profession and reverts to `.unemployed`
/// if its claimed workstation is broken, allowing players to re-roll Novice trades
/// (such as Librarian enchanted books!). Once traded at least once (`xp > 0`),
/// the Villager's profession and trade offers are permanently locked.
pub const ProfessionLockRule = struct {
    /// Returns true if the villager has traded at least once (xp > 0),
    /// which permanently locks their profession and trade offers.
    pub fn isProfessionLocked(xp: u16) bool {
        return xp > 0;
    }

    /// Determines the resulting profession when a claimed workstation is broken.
    /// If xp == 0, the villager loses their profession and reverts to .unemployed.
    /// If xp > 0, the villager's profession is locked and retained.
    /// Nitwits remain nitwits.
    pub fn onWorkstationBroken(current_profession: VillagerProfession, xp: u16) VillagerProfession {
        if (current_profession == .nitwit_green_robe) return .nitwit_green_robe;
        if (ProfessionLockRule.isProfessionLocked(xp)) {
            return current_profession;
        }
        return .unemployed;
    }

    /// Returns true if the villager can change profession. Only allowed when xp == 0
    /// and not a nitwit.
    pub fn canChangeProfession(current_profession: VillagerProfession, xp: u16) bool {
        if (current_profession == .nitwit_green_robe) return false;
        return !ProfessionLockRule.isProfessionLocked(xp);
    }

    /// Returns true if the villager's novice trades can be re-rolled by breaking
    /// and replacing their workstation.
    pub fn canRerollTrades(xp: u16) bool {
        return !ProfessionLockRule.isProfessionLocked(xp);
    }
};

pub const isProfessionLocked = ProfessionLockRule.isProfessionLocked;
pub const onWorkstationBroken = ProfessionLockRule.onWorkstationBroken;
pub const canChangeProfession = ProfessionLockRule.canChangeProfession;
pub const canRerollTrades = ProfessionLockRule.canRerollTrades;

// ============================================================================
// Workstation Twice-Daily Restock Schedule
// ============================================================================

pub const max_restocks_per_day: u2 = 2;
pub const work_start_tick: u16 = 2000;
pub const work_end_tick: u16 = 9000;
pub const ticks_per_day: u16 = 24000;

/// Villagers restock depleted trades at their claimed workstation up to 2 times
/// per day (`max_restocks_per_day: u2 = 2`) during working hours
/// (`work_start_tick: u16 = 2000`, `work_end_tick: u16 = 9000`).
pub const WorkstationRestockSchedule = struct {
    pub const max_restocks_per_day: u2 = 2;
    pub const work_start_tick: u16 = 2000;
    pub const work_end_tick: u16 = 9000;
    pub const ticks_per_day: u16 = 24000;

    restocks_today: u2 = 0,
    last_restock_day: u32 = 0,

    /// Returns true if a villager can restock trade offers at the given time of day.
    /// Requirements:
    /// 1. Must be physically at their claimed workstation (`at_workstation == true`).
    /// 2. Must not have exceeded 2 restocks today (`restocks_today < 2`).
    /// 3. Time of day tick must fall within working hours (2000..9000 ticks).
    pub fn canRestockAtTick(time_of_day_tick: u16, restocks_today: u2, at_workstation: bool) bool {
        if (!at_workstation) return false;
        if (restocks_today >= WorkstationRestockSchedule.max_restocks_per_day) return false;
        const tod = time_of_day_tick % WorkstationRestockSchedule.ticks_per_day;
        return tod >= WorkstationRestockSchedule.work_start_tick and tod <= WorkstationRestockSchedule.work_end_tick;
    }

    /// Evaluates if this schedule instance can restock right now.
    pub fn canRestock(self: WorkstationRestockSchedule, time_of_day_tick: u16, at_workstation: bool) bool {
        return WorkstationRestockSchedule.canRestockAtTick(time_of_day_tick, self.restocks_today, at_workstation);
    }

    /// Attempts to record a restock on a given world day and time of day tick.
    /// Automatically resets daily restock counter if the day has rolled over.
    /// Returns true if restock was granted, false otherwise.
    pub fn tryRestock(self: *WorkstationRestockSchedule, day: u32, time_of_day_tick: u16, at_workstation: bool) bool {
        if (day != self.last_restock_day) {
            self.last_restock_day = day;
            self.restocks_today = 0;
        }
        if (!WorkstationRestockSchedule.canRestockAtTick(time_of_day_tick, self.restocks_today, at_workstation)) {
            return false;
        }
        self.restocks_today += 1;
        return true;
    }

    /// Explicitly resets the daily restock counter for a new day.
    pub fn resetDailyRestocks(self: *WorkstationRestockSchedule, day: u32) void {
        self.last_restock_day = day;
        self.restocks_today = 0;
    }
};

pub const canRestockAtTick = WorkstationRestockSchedule.canRestockAtTick;

// ============================================================================
// Job-Site Registry & Coordinates
// ============================================================================

/// Integer 3D block coordinate.
pub const BlockPos = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn equals(self: BlockPos, other: BlockPos) bool {
        return self.x == other.x and self.y == other.y and self.z == other.z;
    }

    pub fn manhattanDistance(self: BlockPos, other: BlockPos) u32 {
        const dx = @abs(self.x - other.x);
        const dy = @abs(self.y - other.y);
        const dz = @abs(self.z - other.z);
        return @intCast(dx + dy + dz);
    }

    pub fn distanceSquared(self: BlockPos, other: BlockPos) u64 {
        const dx: i64 = @as(i64, self.x) - other.x;
        const dy: i64 = @as(i64, self.y) - other.y;
        const dz: i64 = @as(i64, self.z) - other.z;
        return @intCast(dx * dx + dy * dy + dz * dz);
    }
};

/// A job site representing a placed workstation block in the world.
pub const JobSite = struct {
    pos: BlockPos,
    workstation: WorkstationBlock,
    claimed_by_villager_id: ?u32 = null,

    pub fn isClaimed(self: JobSite) bool {
        return self.claimed_by_villager_id != null;
    }

    pub fn isClaimedBy(self: JobSite, villager_id: u32) bool {
        if (self.claimed_by_villager_id) |id| {
            return id == villager_id;
        }
        return false;
    }

    pub fn claim(self: *JobSite, villager_id: u32) bool {
        if (self.claimed_by_villager_id != null) return false;
        self.claimed_by_villager_id = villager_id;
        return true;
    }

    pub fn release(self: *JobSite) void {
        self.claimed_by_villager_id = null;
    }

    pub fn matchingProfession(self: JobSite) VillagerProfession {
        return fromWorkstation(self.workstation);
    }
};

pub const max_registered_job_sites: usize = 128;

/// World registry of workstation job sites for village POI (Point of Interest) discovery.
pub const JobSiteRegistry = struct {
    sites: [max_registered_job_sites]JobSite = undefined,
    count: usize = 0,

    pub fn init() JobSiteRegistry {
        return .{};
    }

    pub fn registerSite(self: *JobSiteRegistry, pos: BlockPos, workstation: WorkstationBlock) !*JobSite {
        if (self.findSiteAt(pos) != null) return error.SiteAlreadyRegistered;
        if (self.count >= max_registered_job_sites) return error.RegistryFull;
        self.sites[self.count] = .{
            .pos = pos,
            .workstation = workstation,
            .claimed_by_villager_id = null,
        };
        const ptr = &self.sites[self.count];
        self.count += 1;
        return ptr;
    }

    pub fn unregisterSite(self: *JobSiteRegistry, pos: BlockPos) ?JobSite {
        for (0..self.count) |i| {
            if (self.sites[i].pos.equals(pos)) {
                const removed = self.sites[i];
                if (i + 1 < self.count) {
                    self.sites[i] = self.sites[self.count - 1];
                }
                self.count -= 1;
                return removed;
            }
        }
        return null;
    }

    pub fn findSiteAt(self: *JobSiteRegistry, pos: BlockPos) ?*JobSite {
        for (0..self.count) |i| {
            if (self.sites[i].pos.equals(pos)) {
                return &self.sites[i];
            }
        }
        return null;
    }

    pub fn findSiteClaimedBy(self: *JobSiteRegistry, villager_id: u32) ?*JobSite {
        for (0..self.count) |i| {
            if (self.sites[i].isClaimedBy(villager_id)) {
                return &self.sites[i];
            }
        }
        return null;
    }

    /// Finds the nearest unclaimed workstation suitable for the villager's profession.
    pub fn findNearestAvailableSite(
        self: *JobSiteRegistry,
        profession: VillagerProfession,
        pos: BlockPos,
        max_dist_squared: u64,
    ) ?*JobSite {
        if (!profession.canClaimJobSite()) return null;
        var best_site: ?*JobSite = null;
        var best_dist: u64 = max_dist_squared;

        for (0..self.count) |i| {
            const site = &self.sites[i];
            if (site.isClaimed()) continue;

            const matches = switch (profession) {
                .unemployed => true,
                .nitwit_green_robe => false,
                else => profession.workstation() == site.workstation,
            };
            if (!matches) continue;

            const dist = pos.distanceSquared(site.pos);
            if (dist <= best_dist) {
                best_dist = dist;
                best_site = site;
            }
        }
        return best_site;
    }
};

// ============================================================================
// Trade Offer Representation
// ============================================================================

/// Trade offer representing an exchange of items for emeralds or goods.
pub const TradeOffer = struct {
    buy_item_tag: u16,
    buy_count: u8,
    buy_item_tag_2: ?u16 = null,
    buy_count_2: u8 = 0,
    sell_item_tag: u16,
    sell_count: u8,
    uses: u8 = 0,
    max_uses: u8 = 12,
    xp_reward: u8 = 1,
    /// Special offer metadata tag (e.g. enchanted book enchantment ID or roll).
    special_meta: u32 = 0,

    pub fn isDepleted(self: TradeOffer) bool {
        return self.uses >= self.max_uses;
    }

    pub fn recordTrade(self: *TradeOffer) bool {
        if (self.isDepleted()) return false;
        self.uses += 1;
        return true;
    }

    pub fn restock(self: *TradeOffer) void {
        self.uses = 0;
    }
};

// ============================================================================
// Villager State Entity
// ============================================================================

pub const max_active_trades: usize = 10;

/// Complete Villager entity trading and job-site state.
pub const Villager = struct {
    id: u32,
    pos: BlockPos = .{ .x = 0, .y = 0, .z = 0 },
    profession: VillagerProfession = .unemployed,
    xp: u16 = 0,
    claimed_workstation_pos: ?BlockPos = null,
    restock_schedule: WorkstationRestockSchedule = .{},
    trades: [max_active_trades]TradeOffer = undefined,
    trade_count: u8 = 0,

    pub fn init(id: u32, profession: VillagerProfession) Villager {
        var v = Villager{
            .id = id,
            .profession = profession,
        };
        v.initTradesForNovice(0);
        return v;
    }

    pub fn initUnemployed(id: u32) Villager {
        return init(id, .unemployed);
    }

    pub fn initNitwit(id: u32) Villager {
        return init(id, .nitwit_green_robe);
    }

    /// Current trade tier based on cumulative XP.
    pub fn tier(self: Villager) VillagerTradeTier {
        return tierForXp(self.xp);
    }

    /// Whether this villager's profession and trades are locked.
    pub fn isLocked(self: Villager) bool {
        return isProfessionLocked(self.xp);
    }

    /// Whether this villager is capable of claiming a job site.
    pub fn canClaimJobSite(self: Villager) bool {
        return self.profession.canClaimJobSite();
    }

    /// Whether this villager can claim a specific workstation block.
    pub fn canClaimWorkstation(self: Villager, ws: WorkstationBlock) bool {
        return self.profession.canClaimWorkstation(ws);
    }

    /// Claim a workstation at the specified location.
    /// If unemployed, acquires the profession matching the workstation.
    /// Generates novice trades for the new profession.
    pub fn claimWorkstation(self: *Villager, pos: BlockPos, ws: WorkstationBlock, trade_seed: u32) bool {
        if (!self.canClaimWorkstation(ws)) return false;
        if (self.claimed_workstation_pos != null) return false;

        if (self.profession == .unemployed) {
            self.profession = fromWorkstation(ws);
            self.initTradesForNovice(trade_seed);
        }
        self.claimed_workstation_pos = pos;
        return true;
    }

    /// Generates or re-rolls Novice trades for the villager's current profession.
    pub fn initTradesForNovice(self: *Villager, seed: u32) void {
        self.trade_count = 0;
        if (!self.profession.isEmployed()) return;

        // Populate 2 novice trade offers based on profession
        switch (self.profession) {
            .librarian => {
                // Novice Librarian: 24 Paper -> 1 Emerald; Emerald + Book -> Enchanted Book (variable seed)
                self.trades[0] = .{
                    .buy_item_tag = 339, // Paper
                    .buy_count = 24,
                    .sell_item_tag = 388, // Emerald
                    .sell_count = 1,
                    .max_uses = 16,
                    .xp_reward = 2,
                };
                self.trades[1] = .{
                    .buy_item_tag = 388, // Emerald
                    .buy_count = @intCast(@max(5, (seed % 64) + 1)), // 5..64 emerald cost
                    .buy_item_tag_2 = 270, // Book
                    .buy_count_2 = 1,
                    .sell_item_tag = 403, // Enchanted Book
                    .sell_count = 1,
                    .max_uses = 12,
                    .xp_reward = 1,
                    .special_meta = seed, // Encodes book enchantment type/level
                };
                self.trade_count = 2;
            },
            .armorer => {
                // 15 Coal -> 1 Emerald; 5 Emeralds -> Iron Helmet
                self.trades[0] = .{
                    .buy_item_tag = 263, // Coal
                    .buy_count = 15,
                    .sell_item_tag = 388,
                    .sell_count = 1,
                    .max_uses = 16,
                    .xp_reward = 2,
                };
                self.trades[1] = .{
                    .buy_item_tag = 388,
                    .buy_count = 5,
                    .sell_item_tag = 306, // Iron Helmet
                    .sell_count = 1,
                    .max_uses = 12,
                    .xp_reward = 1,
                };
                self.trade_count = 2;
            },
            .farmer => {
                // 20 Wheat -> 1 Emerald; 1 Emerald -> 6 Bread
                self.trades[0] = .{
                    .buy_item_tag = 296, // Wheat
                    .buy_count = 20,
                    .sell_item_tag = 388,
                    .sell_count = 1,
                    .max_uses = 16,
                    .xp_reward = 2,
                };
                self.trades[1] = .{
                    .buy_item_tag = 388,
                    .buy_count = 1,
                    .sell_item_tag = 297, // Bread
                    .sell_count = 6,
                    .max_uses = 16,
                    .xp_reward = 1,
                };
                self.trade_count = 2;
            },
            .fletcher => {
                // 32 Sticks -> 1 Emerald; 1 Emerald -> 16 Arrows
                self.trades[0] = .{
                    .buy_item_tag = 280, // Stick
                    .buy_count = 32,
                    .sell_item_tag = 388,
                    .sell_count = 1,
                    .max_uses = 16,
                    .xp_reward = 2,
                };
                self.trades[1] = .{
                    .buy_item_tag = 388,
                    .buy_count = 1,
                    .sell_item_tag = 262, // Arrow
                    .sell_count = 16,
                    .max_uses = 12,
                    .xp_reward = 1,
                };
                self.trade_count = 2;
            },
            else => {
                // Generic Novice Trade
                self.trades[0] = .{
                    .buy_item_tag = 263, // Coal/Resource
                    .buy_count = 16,
                    .sell_item_tag = 388,
                    .sell_count = 1,
                    .max_uses = 16,
                    .xp_reward = 2,
                };
                self.trade_count = 1;
            },
        }
    }

    /// Handles a workstation being broken or destroyed.
    /// If xp == 0, reverts to .unemployed and clears trade offers (allowing re-rolls).
    /// If xp > 0, profession and trades remain locked.
    pub fn onWorkstationBroken(self: *Villager) void {
        self.claimed_workstation_pos = null;
        const new_prof = ProfessionLockRule.onWorkstationBroken(self.profession, self.xp);
        if (new_prof != self.profession) {
            self.profession = new_prof;
            self.trade_count = 0;
        }
    }

    /// Execute a trade at the given index.
    /// Awards trade XP and permanently locks profession once xp > 0.
    pub fn executeTrade(self: *Villager, trade_idx: usize) bool {
        if (trade_idx >= self.trade_count) return false;
        var offer = &self.trades[trade_idx];
        if (!offer.recordTrade()) return false;
        self.xp = self.xp +| offer.xp_reward;
        return true;
    }

    /// Directly award trade XP (e.g. from manual trade transaction).
    pub fn addTradeXp(self: *Villager, xp_gained: u16) VillagerTradeTier {
        self.xp = self.xp +| xp_gained;
        return self.tier();
    }

    /// Checks if villager can restock at the current time and position.
    pub fn canRestock(self: Villager, time_of_day_tick: u16, at_workstation: bool) bool {
        if (!self.profession.isEmployed() or self.claimed_workstation_pos == null) return false;
        return self.restock_schedule.canRestock(time_of_day_tick, at_workstation);
    }

    /// Attempts twice-daily restock. If successful, resets uses on all depleted trades.
    pub fn restock(self: *Villager, day: u32, time_of_day_tick: u16, at_workstation: bool) bool {
        if (!self.profession.isEmployed() or self.claimed_workstation_pos == null) return false;
        if (!self.restock_schedule.tryRestock(day, time_of_day_tick, at_workstation)) {
            return false;
        }
        for (0..self.trade_count) |i| {
            self.trades[i].restock();
        }
        return true;
    }
};

// ============================================================================
// Unit Tests (At least 12 comprehensive test suites)
// ============================================================================

test "1: VillagerProfession enum has 15 distinct variants and display names" {
    const professions = [_]VillagerProfession{
        .unemployed,
        .nitwit_green_robe,
        .armorer,
        .butcher,
        .cartographer,
        .cleric,
        .farmer,
        .fisherman,
        .fletcher,
        .leatherworker,
        .librarian,
        .mason,
        .shepherd,
        .toolsmith,
        .weaponsmith,
    };
    try std.testing.expectEqual(@as(usize, 15), professions.len);

    for (professions) |p| {
        try std.testing.expect(p.displayName().len > 0);
    }
    try std.testing.expectEqualStrings("Unemployed", VillagerProfession.unemployed.displayName());
    try std.testing.expectEqualStrings("Nitwit", VillagerProfession.nitwit_green_robe.displayName());
    try std.testing.expectEqualStrings("Librarian", VillagerProfession.librarian.displayName());
}

test "2: 13 working professions map bi-directionally to their unique workstations" {
    const expected_mappings = [_]struct { prof: VillagerProfession, ws: WorkstationBlock }{
        .{ .prof = .armorer, .ws = .blast_furnace },
        .{ .prof = .butcher, .ws = .smoker },
        .{ .prof = .cartographer, .ws = .cartography_table },
        .{ .prof = .cleric, .ws = .brewing_stand },
        .{ .prof = .farmer, .ws = .composter },
        .{ .prof = .fisherman, .ws = .barrel },
        .{ .prof = .fletcher, .ws = .fletching_table },
        .{ .prof = .leatherworker, .ws = .cauldron },
        .{ .prof = .librarian, .ws = .lectern },
        .{ .prof = .mason, .ws = .stonecutter },
        .{ .prof = .shepherd, .ws = .loom },
        .{ .prof = .toolsmith, .ws = .smithing_table },
        .{ .prof = .weaponsmith, .ws = .grindstone },
    };

    for (expected_mappings) |m| {
        try std.testing.expectEqual(m.ws, m.prof.workstation().?);
        try std.testing.expectEqual(m.prof, fromWorkstation(m.ws));
        try std.testing.expect(m.prof.isEmployed());
    }

    try std.testing.expectEqual(@as(?WorkstationBlock, null), VillagerProfession.unemployed.workstation());
    try std.testing.expectEqual(@as(?WorkstationBlock, null), VillagerProfession.nitwit_green_robe.workstation());
    try std.testing.expect(!VillagerProfession.unemployed.isEmployed());
    try std.testing.expect(!VillagerProfession.nitwit_green_robe.isEmployed());
}

test "3: canClaimJobSite returns false for nitwit and true for unemployed & employed" {
    try std.testing.expect(!VillagerProfession.nitwit_green_robe.canClaimJobSite());
    try std.testing.expect(VillagerProfession.unemployed.canClaimJobSite());
    try std.testing.expect(VillagerProfession.librarian.canClaimJobSite());
    try std.testing.expect(VillagerProfession.armorer.canClaimJobSite());
    try std.testing.expect(VillagerProfession.farmer.canClaimJobSite());
}

test "4: canClaimWorkstation logic: unemployed claims any, employed claims matching only, nitwit claims none" {
    // Nitwit cannot claim any workstation
    try std.testing.expect(!VillagerProfession.nitwit_green_robe.canClaimWorkstation(.lectern));
    try std.testing.expect(!VillagerProfession.nitwit_green_robe.canClaimWorkstation(.blast_furnace));
    try std.testing.expect(!VillagerProfession.nitwit_green_robe.canClaimWorkstation(.composter));

    // Unemployed can claim any workstation
    try std.testing.expect(VillagerProfession.unemployed.canClaimWorkstation(.lectern));
    try std.testing.expect(VillagerProfession.unemployed.canClaimWorkstation(.blast_furnace));
    try std.testing.expect(VillagerProfession.unemployed.canClaimWorkstation(.barrel));

    // Librarian can only claim lectern
    try std.testing.expect(VillagerProfession.librarian.canClaimWorkstation(.lectern));
    try std.testing.expect(!VillagerProfession.librarian.canClaimWorkstation(.blast_furnace));
    try std.testing.expect(!VillagerProfession.librarian.canClaimWorkstation(.smoker));

    // Armorer can only claim blast furnace
    try std.testing.expect(VillagerProfession.armorer.canClaimWorkstation(.blast_furnace));
    try std.testing.expect(!VillagerProfession.armorer.canClaimWorkstation(.grindstone));
}

test "5: VillagerTradeTier XP threshold mappings for novice, apprentice, journeyman, expert, master" {
    // Novice: 0..9 XP
    try std.testing.expectEqual(VillagerTradeTier.novice, tierForXp(0));
    try std.testing.expectEqual(VillagerTradeTier.novice, tierForXp(5));
    try std.testing.expectEqual(VillagerTradeTier.novice, tierForXp(9));

    // Apprentice: 10..69 XP
    try std.testing.expectEqual(VillagerTradeTier.apprentice, tierForXp(10));
    try std.testing.expectEqual(VillagerTradeTier.apprentice, tierForXp(40));
    try std.testing.expectEqual(VillagerTradeTier.apprentice, tierForXp(69));

    // Journeyman: 70..149 XP
    try std.testing.expectEqual(VillagerTradeTier.journeyman, tierForXp(70));
    try std.testing.expectEqual(VillagerTradeTier.journeyman, tierForXp(100));
    try std.testing.expectEqual(VillagerTradeTier.journeyman, tierForXp(149));

    // Expert: 150..249 XP
    try std.testing.expectEqual(VillagerTradeTier.expert, tierForXp(150));
    try std.testing.expectEqual(VillagerTradeTier.expert, tierForXp(200));
    try std.testing.expectEqual(VillagerTradeTier.expert, tierForXp(249));

    // Master: 250+ XP
    try std.testing.expectEqual(VillagerTradeTier.master, tierForXp(250));
    try std.testing.expectEqual(VillagerTradeTier.master, tierForXp(300));
    try std.testing.expectEqual(VillagerTradeTier.master, tierForXp(65535));
}

test "6: VillagerTradeTier metadata, badges, and tier progression" {
    try std.testing.expectEqual(@as(u8, 1), VillagerTradeTier.novice.level());
    try std.testing.expectEqual(@as(u8, 5), VillagerTradeTier.master.level());

    try std.testing.expectEqualStrings("Stone", VillagerTradeTier.novice.badgeName());
    try std.testing.expectEqualStrings("Iron", VillagerTradeTier.apprentice.badgeName());
    try std.testing.expectEqualStrings("Gold", VillagerTradeTier.journeyman.badgeName());
    try std.testing.expectEqualStrings("Emerald", VillagerTradeTier.expert.badgeName());
    try std.testing.expectEqualStrings("Diamond", VillagerTradeTier.master.badgeName());

    try std.testing.expectEqual(VillagerTradeTier.apprentice, VillagerTradeTier.novice.nextTier().?);
    try std.testing.expectEqual(@as(?VillagerTradeTier, null), VillagerTradeTier.master.nextTier());

    try std.testing.expectEqual(@as(?u16, 10), VillagerTradeTier.novice.xpForNextTier());
    try std.testing.expectEqual(@as(?u16, 70), VillagerTradeTier.apprentice.xpForNextTier());
    try std.testing.expectEqual(@as(?u16, null), VillagerTradeTier.master.xpForNextTier());
}

test "7: ProfessionLockRule isProfessionLocked only locks when xp > 0" {
    try std.testing.expect(!isProfessionLocked(0));
    try std.testing.expect(isProfessionLocked(1));
    try std.testing.expect(isProfessionLocked(10));
    try std.testing.expect(isProfessionLocked(250));
    try std.testing.expect(canRerollTrades(0));
    try std.testing.expect(!canRerollTrades(1));
}

test "8: ProfessionLockRule onWorkstationBroken: reverts to unemployed at 0 XP, locks at >0 XP" {
    // Un-traded librarian (0 XP) loses job on workstation destruction
    const reverted = onWorkstationBroken(.librarian, 0);
    try std.testing.expectEqual(VillagerProfession.unemployed, reverted);

    // Traded librarian (e.g. 5 XP) retains librarian profession
    const locked_prof = onWorkstationBroken(.librarian, 5);
    try std.testing.expectEqual(VillagerProfession.librarian, locked_prof);

    // Nitwit stays nitwit regardless of XP
    try std.testing.expectEqual(VillagerProfession.nitwit_green_robe, onWorkstationBroken(.nitwit_green_robe, 0));
}

test "9: Librarian Novice trade re-rolling mechanics when workstation is broken and replaced" {
    var villager = Villager.initUnemployed(101);
    const lectern_pos = BlockPos{ .x = 10, .y = 64, .z = 20 };

    // Claim lectern with seed 10 (roll #1: enchanted book costs 11 emeralds)
    try std.testing.expect(villager.claimWorkstation(lectern_pos, .lectern, 10));
    try std.testing.expectEqual(VillagerProfession.librarian, villager.profession);
    try std.testing.expectEqual(@as(u16, 0), villager.xp);
    try std.testing.expect(!villager.isLocked());
    try std.testing.expectEqual(@as(u32, 10), villager.trades[1].special_meta);

    // Player dislikes trade; breaks lectern! Villager loses job and reverts to unemployed
    villager.onWorkstationBroken();
    try std.testing.expectEqual(VillagerProfession.unemployed, villager.profession);
    try std.testing.expectEqual(@as(?BlockPos, null), villager.claimed_workstation_pos);
    try std.testing.expectEqual(@as(u8, 0), villager.trade_count);

    // Player replaces lectern with seed 42 (roll #2: Mending trade!)
    try std.testing.expect(villager.claimWorkstation(lectern_pos, .lectern, 42));
    try std.testing.expectEqual(VillagerProfession.librarian, villager.profession);
    try std.testing.expectEqual(@as(u32, 42), villager.trades[1].special_meta);

    // Player trades once; villager gains XP and locks!
    try std.testing.expect(villager.executeTrade(0));
    try std.testing.expect(villager.xp > 0);
    try std.testing.expect(villager.isLocked());

    // Breaking lectern now does NOT clear profession or trades
    villager.onWorkstationBroken();
    try std.testing.expectEqual(VillagerProfession.librarian, villager.profession);
    try std.testing.expectEqual(@as(u8, 2), villager.trade_count);
    try std.testing.expectEqual(@as(u32, 42), villager.trades[1].special_meta);
}

test "10: WorkstationRestockSchedule working hours boundaries (2000 to 9000 ticks)" {
    // Before working hours (e.g. dawn wander: tick 0, 1000, 1999)
    try std.testing.expect(!canRestockAtTick(0, 0, true));
    try std.testing.expect(!canRestockAtTick(1000, 0, true));
    try std.testing.expect(!canRestockAtTick(1999, 0, true));

    // During working hours (tick 2000..9000)
    try std.testing.expect(canRestockAtTick(2000, 0, true));
    try std.testing.expect(canRestockAtTick(5000, 0, true));
    try std.testing.expect(canRestockAtTick(9000, 0, true));

    // After working hours (gathering at bell: tick 9001, sleeping: tick 12000)
    try std.testing.expect(!canRestockAtTick(9001, 0, true));
    try std.testing.expect(!canRestockAtTick(12000, 0, true));
    try std.testing.expect(!canRestockAtTick(23999, 0, true));
}

test "11: WorkstationRestockSchedule max 2 restocks per day limit and workstation check" {
    // At workstation, during work hours (tick 4000)
    try std.testing.expect(canRestockAtTick(4000, 0, true)); // 0 restocks used
    try std.testing.expect(canRestockAtTick(4000, 1, true)); // 1 restock used
    try std.testing.expect(!canRestockAtTick(4000, 2, true)); // 2 restocks used (maxed out!)
    try std.testing.expect(!canRestockAtTick(4000, 3, true));

    // Not at workstation: always false even during work hours with 0 restocks
    try std.testing.expect(!canRestockAtTick(4000, 0, false));
    try std.testing.expect(!canRestockAtTick(4000, 1, false));
}

test "12: WorkstationRestockSchedule daily cycle, twice-daily limits and next-day rollover" {
    var schedule = WorkstationRestockSchedule{};

    // Day 1: First restock during work hours
    try std.testing.expect(schedule.tryRestock(1, 3000, true));
    try std.testing.expectEqual(@as(u2, 1), schedule.restocks_today);

    // Day 1: Second restock during work hours
    try std.testing.expect(schedule.tryRestock(1, 6000, true));
    try std.testing.expectEqual(@as(u2, 2), schedule.restocks_today);

    // Day 1: Third attempt fails because max_restocks_per_day is 2
    try std.testing.expect(!schedule.tryRestock(1, 7000, true));
    try std.testing.expectEqual(@as(u2, 2), schedule.restocks_today);

    // Day 2 rolls over: counter resets automatically and allows 2 more restocks
    try std.testing.expect(schedule.tryRestock(2, 2500, true));
    try std.testing.expectEqual(@as(u2, 1), schedule.restocks_today);
    try std.testing.expect(schedule.tryRestock(2, 8500, true));
    try std.testing.expectEqual(@as(u2, 2), schedule.restocks_today);
    try std.testing.expect(!schedule.tryRestock(2, 8800, true));
}

test "13: JobSite and JobSiteRegistry POI registration, search, and claiming" {
    var registry = JobSiteRegistry.init();
    const pos1 = BlockPos{ .x = 100, .y = 64, .z = 200 };
    const pos2 = BlockPos{ .x = 105, .y = 64, .z = 200 };

    _ = try registry.registerSite(pos1, .composter);
    _ = try registry.registerSite(pos2, .blast_furnace);

    try std.testing.expectEqual(@as(usize, 2), registry.count);

    // Farmer looks for job site
    const found_farmer_site = registry.findNearestAvailableSite(.farmer, BlockPos{ .x = 101, .y = 64, .z = 200 }, 100);
    try std.testing.expect(found_farmer_site != null);
    try std.testing.expectEqual(WorkstationBlock.composter, found_farmer_site.?.workstation);

    // Claim site for villager 7
    try std.testing.expect(found_farmer_site.?.claim(7));
    try std.testing.expect(found_farmer_site.?.isClaimed());
    try std.testing.expect(found_farmer_site.?.isClaimedBy(7));

    // Now site is claimed, searching farmer finds nothing within range
    const search_again = registry.findNearestAvailableSite(.farmer, BlockPos{ .x = 101, .y = 64, .z = 200 }, 100);
    try std.testing.expect(search_again == null);

    // Unregistering site
    const removed = registry.unregisterSite(pos1);
    try std.testing.expect(removed != null);
    try std.testing.expectEqual(@as(usize, 1), registry.count);
}

test "14: TradeOffer depletion and full villager restock integration" {
    var villager = Villager.initUnemployed(50);
    const barrel_pos = BlockPos{ .x = 0, .y = 64, .z = 0 };

    try std.testing.expect(villager.claimWorkstation(barrel_pos, .barrel, 1));
    try std.testing.expectEqual(VillagerProfession.fisherman, villager.profession);
    try std.testing.expectEqual(@as(u8, 1), villager.trade_count);

    // Exhaust trade offers up to max_uses (16)
    var i: usize = 0;
    while (i < 16) : (i += 1) {
        try std.testing.expect(villager.executeTrade(0));
    }
    // Trade is now depleted
    try std.testing.expect(villager.trades[0].isDepleted());
    try std.testing.expect(!villager.executeTrade(0));

    // Outside workstation, restock fails
    try std.testing.expect(!villager.restock(1, 4000, false));
    try std.testing.expect(villager.trades[0].isDepleted());

    // At workstation during work hours, restock succeeds
    try std.testing.expect(villager.restock(1, 4000, true));
    try std.testing.expect(!villager.trades[0].isDepleted());
    try std.testing.expectEqual(@as(u8, 0), villager.trades[0].uses);

    // Can trade again!
    try std.testing.expect(villager.executeTrade(0));
}

test "15: BlockId integration conversions for all 13 workstations" {
    const workstations = [_]WorkstationBlock{
        .blast_furnace,
        .smoker,
        .cartography_table,
        .brewing_stand,
        .composter,
        .barrel,
        .fletching_table,
        .cauldron,
        .lectern,
        .stonecutter,
        .loom,
        .smithing_table,
        .grindstone,
    };

    for (workstations) |ws| {
        const block_id = ws.toBlockId();
        const back = WorkstationBlock.fromBlockId(block_id);
        try std.testing.expectEqual(ws, back.?);

        const prof = fromBlockId(block_id);
        try std.testing.expect(prof != null);
        try std.testing.expectEqual(block_id, prof.?.workstationBlock().?);
    }

    try std.testing.expectEqual(@as(?WorkstationBlock, null), WorkstationBlock.fromBlockId(.dirt));
    try std.testing.expectEqual(@as(?VillagerProfession, null), fromBlockId(.stone));
}

test "16: Villager leveling progression from Novice through Master" {
    var villager = Villager.init(99, .armorer);
    try std.testing.expectEqual(VillagerTradeTier.novice, villager.tier());

    // Novice -> Apprentice at 10 XP
    _ = villager.addTradeXp(10);
    try std.testing.expectEqual(VillagerTradeTier.apprentice, villager.tier());

    // Apprentice -> Journeyman at 70 XP
    _ = villager.addTradeXp(60);
    try std.testing.expectEqual(VillagerTradeTier.journeyman, villager.tier());

    // Journeyman -> Expert at 150 XP
    _ = villager.addTradeXp(80);
    try std.testing.expectEqual(VillagerTradeTier.expert, villager.tier());

    // Expert -> Master at 250 XP
    _ = villager.addTradeXp(100);
    try std.testing.expectEqual(VillagerTradeTier.master, villager.tier());
    try std.testing.expectEqualStrings("Diamond", villager.tier().badgeName());
}

test "17: BlockPos distance calculation metrics" {
    const p1 = BlockPos{ .x = 0, .y = 64, .z = 0 };
    const p2 = BlockPos{ .x = 3, .y = 68, .z = 0 };

    try std.testing.expectEqual(@as(u32, 7), p1.manhattanDistance(p2)); // 3 + 4 = 7
    try std.testing.expectEqual(@as(u64, 25), p1.distanceSquared(p2)); // 3^2 + 4^2 = 25
}
