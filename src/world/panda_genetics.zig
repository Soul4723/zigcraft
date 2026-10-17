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

pub const SneezeResult = struct {
    sneezed: bool,
    startled_adults_jump: bool,
    dropped_slimeball: bool,
};

pub fn resolveExpressedPandaPersonality(main_gene: PandaGene, hidden_gene: PandaGene) PandaGene {
    if (!main_gene.isRecessive()) return main_gene;
    if (hidden_gene == main_gene) return main_gene;
    return .normal;
}

pub fn pandaMaxHealth(personality: PandaGene) f32 {
    return if (personality == .weak) 10.0 else 20.0;
}

/// `roll_sneeze` uses the low end of the u16 range as the sneeze event:
/// normal babies sneeze on 0, while weak babies sneeze on 0 through 10 (11x).
pub fn rollBabyPandaSneeze(is_weak_baby: bool, roll_sneeze: u16, roll_slimeball_0_to_699: u16) SneezeResult {
    const sneezed = if (is_weak_baby) roll_sneeze < 11 else roll_sneeze == 0;
    return .{
        .sneezed = sneezed,
        .startled_adults_jump = sneezed,
        .dropped_slimeball = sneezed and roll_slimeball_0_to_699 == 0,
    };
}

pub fn canBreedPandasWithBamboo(fed_bamboo: bool, bamboo_blocks_within_5m_radius: u8) bool {
    return fed_bamboo and bamboo_blocks_within_5m_radius >= 8;
}

pub fn isWorriedShakingHidingFace(personality: PandaGene, is_thunderstorming: bool) bool {
    return personality == .worried and is_thunderstorming;
}

pub fn canPlayfulRollFlip(personality: PandaGene) bool {
    return personality == .playful;
}

test "dominant personalities always express the main gene" {
    inline for ([_]PandaGene{ .normal, .lazy, .worried, .playful, .aggressive }) |gene| {
        try std.testing.expectEqual(gene, resolveExpressedPandaPersonality(gene, .brown));
    }
}

test "weak expresses only when homozygous recessive" {
    try std.testing.expectEqual(PandaGene.weak, resolveExpressedPandaPersonality(.weak, .weak));
    try std.testing.expectEqual(PandaGene.normal, resolveExpressedPandaPersonality(.weak, .normal));
    try std.testing.expectEqual(PandaGene.normal, resolveExpressedPandaPersonality(.weak, .brown));
}

test "brown expresses only when homozygous recessive" {
    try std.testing.expectEqual(PandaGene.brown, resolveExpressedPandaPersonality(.brown, .brown));
    try std.testing.expectEqual(PandaGene.normal, resolveExpressedPandaPersonality(.brown, .normal));
    try std.testing.expectEqual(PandaGene.normal, resolveExpressedPandaPersonality(.brown, .weak));
}

test "only weak and brown genes are recessive" {
    try std.testing.expect(PandaGene.weak.isRecessive());
    try std.testing.expect(PandaGene.brown.isRecessive());
    inline for ([_]PandaGene{ .normal, .lazy, .worried, .playful, .aggressive }) |gene| {
        try std.testing.expect(!gene.isRecessive());
    }
}

test "weak pandas have five hearts and other personalities have ten" {
    try std.testing.expectEqual(@as(f32, 10.0), pandaMaxHealth(.weak));
    inline for (.{ PandaGene.normal, .lazy, .worried, .playful, .aggressive, .brown }) |gene| {
        try std.testing.expectEqual(@as(f32, 20.0), pandaMaxHealth(gene));
    }
}

test "normal baby sneeze roll succeeds only on zero" {
    try std.testing.expect(rollBabyPandaSneeze(false, 0, 1).sneezed);
    try std.testing.expect(!rollBabyPandaSneeze(false, 1, 0).sneezed);
}

test "weak baby sneeze has eleven successful roll values" {
    try std.testing.expect(rollBabyPandaSneeze(true, 10, 1).sneezed);
    try std.testing.expect(!rollBabyPandaSneeze(true, 11, 0).sneezed);
}

test "sneeze startles nearby adults into jumping" {
    try std.testing.expect(rollBabyPandaSneeze(false, 0, 1).startled_adults_jump);
    try std.testing.expect(!rollBabyPandaSneeze(false, 1, 0).startled_adults_jump);
}

test "sneeze drops a slimeball on one of 700 rolls" {
    try std.testing.expect(rollBabyPandaSneeze(false, 0, 0).dropped_slimeball);
    try std.testing.expect(!rollBabyPandaSneeze(false, 0, 1).dropped_slimeball);
    try std.testing.expect(!rollBabyPandaSneeze(false, 1, 0).dropped_slimeball);
}

test "pandas require feeding and eight nearby bamboo blocks to breed" {
    try std.testing.expect(!canBreedPandasWithBamboo(false, 8));
    try std.testing.expect(!canBreedPandasWithBamboo(true, 7));
    try std.testing.expect(canBreedPandasWithBamboo(true, 8));
    try std.testing.expect(canBreedPandasWithBamboo(true, 9));
}

test "worried pandas shake and hide face during thunderstorms" {
    try std.testing.expect(isWorriedShakingHidingFace(.worried, true));
    try std.testing.expect(!isWorriedShakingHidingFace(.worried, false));
    try std.testing.expect(!isWorriedShakingHidingFace(.normal, true));
}

test "playful pandas can roll and flip" {
    try std.testing.expect(canPlayfulRollFlip(.playful));
    try std.testing.expect(!canPlayfulRollFlip(.normal));
}
