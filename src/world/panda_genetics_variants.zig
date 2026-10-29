const std = @import("std");

pub const PandaGene = enum {
    normal,
    lazy,
    worried,
    playful,
    aggressive,
    weak,
    brown,

    pub fn isRecessive(self: PandaGene) bool {
        return self == .weak or self == .brown;
    }
};

pub const PandaGenotype = struct {
    main_allele: PandaGene,
    hidden_allele: PandaGene,

    pub fn phenotype(self: PandaGenotype) PandaGene {
        return resolvePhenotype(self.main_allele, self.hidden_allele);
    }
};

pub const PandaBehavior = struct {
    curious_wandering: bool,
    walk_speed_mps: f32,
    lies_on_back: bool,
    follows_bamboo: bool,
    shakes_in_thunderstorm: bool,
    hides_face_near_hostiles: bool,
    performs_tumbling: bool,
    retaliates_when_harmed: bool,
    max_health_hp: f32,
    baby_sneeze_frequency_multiplier: f32,
    sneeze_self_damage_hp: f32,
    brown_and_white_coat: bool,
};

pub const PandaBehaviorState = struct {
    whimpering: bool,
    love_mode: bool,
};

pub const PandaGenetics = struct {
    pub const GENE_COUNT: u8 = 7;
    pub const MUTATION_ROLL_COUNT: u8 = 32;
    pub const MUTATION_CHANCE: f32 = 0.03125;
    pub const BREEDING_RADIUS: f32 = 5.0;
    pub const REQUIRED_BAMBOO_BLOCKS: u8 = 8;
    pub const AGGRESSIVE_DAMAGE_HP: f32 = 6.0;
    pub const LAZY_WALK_SPEED_MPS: f32 = 1.0;

    pub fn behavior(personality: PandaGene) PandaBehavior {
        return .{
            .walk_speed_mps = if (personality == .lazy) LAZY_WALK_SPEED_MPS else 1.5,
            .curious_wandering = personality == .normal,
            .lies_on_back = personality == .lazy,
            .follows_bamboo = personality != .lazy,
            .shakes_in_thunderstorm = personality == .worried,
            .hides_face_near_hostiles = personality == .worried,
            .performs_tumbling = personality == .playful,
            .retaliates_when_harmed = personality == .aggressive,
            .max_health_hp = if (personality == .weak) 10.0 else 20.0,
            .baby_sneeze_frequency_multiplier = if (personality == .weak) 11.0 else 1.0,
            .sneeze_self_damage_hp = if (personality == .weak) 1.0 else 0.0,
            .brown_and_white_coat = personality == .brown,
        };
    }

    pub fn retaliationDamage(personality: PandaGene, was_hit: bool, nearby_panda_harmed: bool) f32 {
        return if (personality == .aggressive and (was_hit or nearby_panda_harmed)) AGGRESSIVE_DAMAGE_HP else 0.0;
    }

    pub fn rollMutates(roll: u5) bool {
        return roll == 0;
    }

    pub fn breedingState(fed_bamboo: bool, father_nearby_bamboo: u8, mother_nearby_bamboo: u8) PandaBehaviorState {
        const enough_bamboo = father_nearby_bamboo >= REQUIRED_BAMBOO_BLOCKS and mother_nearby_bamboo >= REQUIRED_BAMBOO_BLOCKS;
        return .{
            .whimpering = fed_bamboo and !enough_bamboo,
            .love_mode = fed_bamboo and enough_bamboo,
        };
    }

    /// Each parent's selection roll is 0 for main and 1 for hidden. A mutation
    /// roll of zero mutates that inherited allele to mutation_gene.
    pub fn inheritOffspring(
        father: PandaGenotype,
        mother: PandaGenotype,
        father_allele_roll: u1,
        mother_allele_roll: u1,
        father_mutation_roll: u5,
        mother_mutation_roll: u5,
        father_mutation_gene: PandaGene,
        mother_mutation_gene: PandaGene,
    ) PandaGenotype {
        const father_allele = selectAllele(father, father_allele_roll);
        const mother_allele = selectAllele(mother, mother_allele_roll);
        return .{
            .main_allele = if (rollMutates(father_mutation_roll)) father_mutation_gene else father_allele,
            .hidden_allele = if (rollMutates(mother_mutation_roll)) mother_mutation_gene else mother_allele,
        };
    }
};

pub fn resolvePhenotype(main_allele: PandaGene, hidden_allele: PandaGene) PandaGene {
    if (main_allele == hidden_allele) return main_allele;
    const main_recessive = main_allele.isRecessive();
    const hidden_recessive = hidden_allele.isRecessive();
    if (main_recessive and hidden_recessive) return .normal;
    if (main_recessive) return hidden_allele;
    if (hidden_recessive) return main_allele;

    // Normal is the default phenotype and dominates all other dominant traits.
    if (main_allele == .normal or hidden_allele == .normal) return .normal;
    // Stable tie-break for two different non-normal dominant genes.
    return if (@intFromEnum(main_allele) < @intFromEnum(hidden_allele)) main_allele else hidden_allele;
}

fn selectAllele(parent: PandaGenotype, roll: u1) PandaGene {
    return if (roll == 0) parent.main_allele else parent.hidden_allele;
}

test "identical alleles express their gene" {
    inline for (@typeInfo(PandaGene).@"enum".fields) |field| {
        const gene: PandaGene = @enumFromInt(field.value);
        try std.testing.expectEqual(gene, resolvePhenotype(gene, gene));
    }
}

test "every dominant gene masks each recessive gene" {
    inline for (.{ .normal, .lazy, .worried, .playful, .aggressive }) |dominant| {
        inline for (.{ .weak, .brown }) |recessive| {
            try std.testing.expectEqual(dominant, resolvePhenotype(dominant, recessive));
            try std.testing.expectEqual(dominant, resolvePhenotype(recessive, dominant));
        }
    }
}

test "normal dominates every other dominant allele" {
    inline for (.{ .lazy, .worried, .playful, .aggressive }) |gene| {
        try std.testing.expectEqual(PandaGene.normal, resolvePhenotype(.normal, gene));
        try std.testing.expectEqual(PandaGene.normal, resolvePhenotype(gene, .normal));
    }
}

test "different non-normal dominant alleles use stable enum precedence" {
    try std.testing.expectEqual(PandaGene.lazy, resolvePhenotype(.lazy, .worried));
    try std.testing.expectEqual(PandaGene.playful, resolvePhenotype(.aggressive, .playful));
    try std.testing.expectEqual(PandaGene.worried, resolvePhenotype(.worried, .aggressive));
}

test "two different recessive alleles express normal" {
    try std.testing.expectEqual(PandaGene.normal, resolvePhenotype(.weak, .brown));
    try std.testing.expectEqual(PandaGene.normal, resolvePhenotype(.brown, .weak));
}

test "weak homozygous genotype expresses weak" {
    try std.testing.expectEqual(PandaGene.weak, (PandaGenotype{ .main_allele = .weak, .hidden_allele = .weak }).phenotype());
}

test "brown homozygous genotype expresses brown coat" {
    try std.testing.expectEqual(PandaGene.brown, (PandaGenotype{ .main_allele = .brown, .hidden_allele = .brown }).phenotype());
    try std.testing.expect(PandaGenetics.behavior(.brown).brown_and_white_coat);
}

test "normal personality has standard curious wandering attributes" {
    const b = PandaGenetics.behavior(.normal);
    try std.testing.expectEqual(@as(f32, 1.5), b.walk_speed_mps);
    try std.testing.expect(b.curious_wandering);
    try std.testing.expect(b.follows_bamboo);
    try std.testing.expect(!b.lies_on_back);
}

test "lazy pandas lie on their backs and ignore bamboo" {
    const b = PandaGenetics.behavior(.lazy);
    try std.testing.expect(b.lies_on_back);
    try std.testing.expect(!b.follows_bamboo);
    try std.testing.expectEqual(PandaGenetics.LAZY_WALK_SPEED_MPS, b.walk_speed_mps);
}

test "worried pandas shake in thunderstorms" {
    try std.testing.expect(PandaGenetics.behavior(.worried).shakes_in_thunderstorm);
}

test "worried pandas hide their faces near hostiles" {
    try std.testing.expect(PandaGenetics.behavior(.worried).hides_face_near_hostiles);
}

test "playful pandas tumble at every age" {
    try std.testing.expect(PandaGenetics.behavior(.playful).performs_tumbling);
}

test "aggressive pandas retaliate for self or nearby panda harm" {
    try std.testing.expectEqual(@as(f32, 6.0), PandaGenetics.retaliationDamage(.aggressive, true, false));
    try std.testing.expectEqual(@as(f32, 6.0), PandaGenetics.retaliationDamage(.aggressive, false, true));
    try std.testing.expectEqual(@as(f32, 0.0), PandaGenetics.retaliationDamage(.aggressive, false, false));
}

test "non-aggressive pandas do not retaliate" {
    try std.testing.expectEqual(@as(f32, 0.0), PandaGenetics.retaliationDamage(.playful, true, true));
}

test "weak pandas have ten health and take sneeze self damage" {
    const b = PandaGenetics.behavior(.weak);
    try std.testing.expectEqual(@as(f32, 10.0), b.max_health_hp);
    try std.testing.expectEqual(@as(f32, 1.0), b.sneeze_self_damage_hp);
}

test "weak baby pandas sneeze eleven times as often" {
    try std.testing.expectEqual(@as(f32, 11.0), PandaGenetics.behavior(.weak).baby_sneeze_frequency_multiplier);
}

test "non-weak pandas have standard health and no sneeze damage" {
    inline for (.{ .normal, .lazy, .worried, .playful, .aggressive, .brown }) |gene| {
        const b = PandaGenetics.behavior(gene);
        try std.testing.expectEqual(@as(f32, 20.0), b.max_health_hp);
        try std.testing.expectEqual(@as(f32, 0.0), b.sneeze_self_damage_hp);
    }
}

test "bamboo count requirement applies independently to each parent" {
    try std.testing.expect(!PandaGenetics.breedingState(true, 8, 7).love_mode);
    try std.testing.expect(!PandaGenetics.breedingState(true, 7, 8).love_mode);
    try std.testing.expect(PandaGenetics.breedingState(true, 8, 8).love_mode);
}

test "fed pandas without sufficient bamboo whimper" {
    const state = PandaGenetics.breedingState(true, 4, 8);
    try std.testing.expect(state.whimpering);
    try std.testing.expect(!state.love_mode);
}

test "bamboo prerequisite alone does not trigger love mode" {
    const state = PandaGenetics.breedingState(false, 8, 8);
    try std.testing.expect(!state.whimpering);
    try std.testing.expect(!state.love_mode);
}

test "feeding with eight bamboo blocks near each parent triggers love mode" {
    const state = PandaGenetics.breedingState(true, 8, 9);
    try std.testing.expect(state.love_mode);
    try std.testing.expect(!state.whimpering);
}

test "offspring inherits selected main alleles from father and mother" {
    const child = PandaGenetics.inheritOffspring(.{ .main_allele = .lazy, .hidden_allele = .weak }, .{ .main_allele = .playful, .hidden_allele = .brown }, 0, 0, 1, 1, .normal, .normal);
    try std.testing.expectEqual(PandaGene.lazy, child.main_allele);
    try std.testing.expectEqual(PandaGene.playful, child.hidden_allele);
}

test "punnett inheritance can select either parental allele" {
    const child = PandaGenetics.inheritOffspring(.{ .main_allele = .lazy, .hidden_allele = .weak }, .{ .main_allele = .playful, .hidden_allele = .brown }, 1, 1, 1, 1, .normal, .normal);
    try std.testing.expectEqual(PandaGene.weak, child.main_allele);
    try std.testing.expectEqual(PandaGene.brown, child.hidden_allele);
}

test "one-in-thirty-two mutation roll mutates inherited paternal allele" {
    const child = PandaGenetics.inheritOffspring(.{ .main_allele = .normal, .hidden_allele = .normal }, .{ .main_allele = .normal, .hidden_allele = .normal }, 0, 0, 0, 31, .brown, .weak);
    try std.testing.expectEqual(PandaGene.brown, child.main_allele);
    try std.testing.expectEqual(PandaGene.normal, child.hidden_allele);
}

test "one-in-thirty-two mutation roll mutates inherited maternal allele" {
    const child = PandaGenetics.inheritOffspring(.{ .main_allele = .normal, .hidden_allele = .normal }, .{ .main_allele = .normal, .hidden_allele = .normal }, 0, 0, 31, 0, .weak, .brown);
    try std.testing.expectEqual(PandaGene.normal, child.main_allele);
    try std.testing.expectEqual(PandaGene.brown, child.hidden_allele);
}

test "mutation roll has exactly one successful result in thirty-two" {
    var successful_rolls: u8 = 0;
    var roll: u8 = 0;
    while (roll < PandaGenetics.MUTATION_ROLL_COUNT) : (roll += 1) {
        if (PandaGenetics.rollMutates(@intCast(roll))) successful_rolls += 1;
    }
    try std.testing.expectEqual(@as(u8, 1), successful_rolls);
    try std.testing.expectEqual(@as(f32, 0.03125), PandaGenetics.MUTATION_CHANCE);
}

test "mutation allows a rare recessive brown phenotype to emerge" {
    const carrier = PandaGenetics.inheritOffspring(.{ .main_allele = .normal, .hidden_allele = .normal }, .{ .main_allele = .normal, .hidden_allele = .normal }, 0, 0, 0, 0, .brown, .brown);
    try std.testing.expectEqual(PandaGene.brown, carrier.phenotype());
}
