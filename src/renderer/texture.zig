const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});

pub const ATLAS_TILES_PER_ROW: f32 = 8.0;
pub const TILE_UV_SIZE: f32 = 1.0 / ATLAS_TILES_PER_ROW;

pub fn getTileUV(tile_x: u32, tile_y: u32) [4][2]f32 {
    const u_min = @as(f32, @floatFromInt(tile_x)) * TILE_UV_SIZE;
    const v_min = @as(f32, @floatFromInt(tile_y)) * TILE_UV_SIZE;
    return .{
        .{ u_min, v_min },
        .{ u_min + TILE_UV_SIZE, v_min },
        .{ u_min + TILE_UV_SIZE, v_min + TILE_UV_SIZE },
        .{ u_min, v_min + TILE_UV_SIZE },
    };
}

fn hash2(x: usize, y: usize, seed: u32) u32 {
    var h: u32 = seed +% @as(u32, @intCast(x)) *% 374761393 +% @as(u32, @intCast(y)) *% 668265263;
    h ^= h >> 13;
    h *%= 1274126177;
    h ^= h >> 16;
    return h;
}

pub fn tilePixel(tile_x: u32, tile_y: u32, x: usize, y: usize) [4]u8 {
    if (tile_x == 0 and tile_y == 0) {
        const n = hash2(x, y, 11) % 100;
        if (hash2(x / 2, y, 77) % 8 == 0) return .{ 38, 118, 32, 255 };
        if (hash2(x, y / 3, 55) % 11 == 0) return .{ 105, 200, 70, 255 };
        if (n < 12) return .{ 52, 140, 44, 255 };
        if (n < 30) return .{ 70, 168, 52, 255 };
        return .{ 82, 178, 58, 255 };
    }
    if (tile_x == 1 and tile_y == 0) {
        const fringe: usize = 2 + hash2(x, 0, 21) % 3;
        if (y < fringe) {
            if (hash2(x, y, 22) % 100 < 20) return .{ 52, 140, 44, 255 };
            return .{ 80, 172, 55, 255 };
        }
        if (y == fringe) return .{ 62, 120, 40, 255 };
        return dirtPixel(x, y);
    }
    if (tile_x == 2 and tile_y == 0) return dirtPixel(x, y);
    if (tile_x == 3 and tile_y == 0) return stonePixel(x, y, 31);
    if (tile_x == 0 and tile_y == 1) {
        const band = (x + y * 2) % 16 < 3;
        const n = hash2(x, y, 41) % 21;
        if (band) return .{ 55, 130, 225, 185 };
        return .{ 35 + @as(u8, @intCast(n / 2)), 95 + @as(u8, @intCast(n)), 210, 185 };
    }
    if (tile_x == 1 and tile_y == 1) {
        const ridge = x % 4 == 0;
        const knot = (x == 5 or x == 12) and (y == 4 or y == 11);
        const n = hash2(x, y, 51) % 20;
        if (knot) return .{ 55, 35, 18, 255 };
        if (ridge) return .{ 62 + @as(u8, @intCast(n / 2)), 40, 22, 255 };
        if (n < 4) return .{ 130, 92, 50, 255 };
        return .{ 98 + @as(u8, @intCast(n)), 64 + @as(u8, @intCast(n / 2)), 34, 255 };
    }
    if (tile_x == 2 and tile_y == 1) {
        const dx: i32 = @as(i32, @intCast(x)) - 7;
        const dy: i32 = @as(i32, @intCast(y)) - 7;
        const ax: usize = @intCast(@max(dx, -dx) + @max(dy, -dy));
        const ring = ax % 3 == 0;
        if (ax > 13) return .{ 95, 62, 32, 255 };
        if (ring) return .{ 128, 92, 52, 255 };
        const n = hash2(x, y, 52) % 10;
        return .{ 178 + @as(u8, @intCast(n)), 140 + @as(u8, @intCast(n)), 88, 255 };
    }
    if (tile_x == 3 and tile_y == 1) {
        const n = hash2(x, y, 61) % 100;
        if (hash2(x / 2, y / 2, 62) % 13 == 0) return .{ 12, 40, 12, 255 };
        if (n < 15) return .{ 96, 170, 50, 255 };
        if (n < 45) return .{ 52, 130, 34, 255 };
        return .{ 34, 105, 26, 255 };
    }
    if (tile_x == 0 and tile_y == 2) {
        const n = hash2(x, y, 71) % 15;
        const wc: u8 = 225 + @as(u8, @intCast(n));
        return .{ wc, wc, wc - 5, 255 };
    }
    if (tile_x == 1 and tile_y == 2) {
        const eye = (y >= 6 and y <= 8) and ((x >= 2 and x <= 5) or (x >= 10 and x <= 13));
        const pupil = (y >= 7 and y <= 8) and ((x >= 4 and x <= 5) or (x >= 10 and x <= 11));
        const muzzle = (y >= 9 and y <= 13) and (x >= 5 and x <= 10);
        if (pupil) return .{ 35, 30, 30, 255 };
        if (eye) return .{ 245, 245, 245, 255 };
        if (muzzle) return .{ 220, 180, 170, 255 };
        const n = hash2(x, y, 72) % 11;
        return .{ 205 + @as(u8, @intCast(n)), 190 + @as(u8, @intCast(n)), 175, 255 };
    }
    if (tile_x == 2 and tile_y == 2) {
        const seam_y = y % 4 == 0;
        const seam_x = (x + (y / 4) * 5 + 3) % 16 == 0;
        const knot = (x == 4 and y == 6) or (x == 11 and y == 13);
        if (knot) return .{ 88, 58, 28, 255 };
        if (seam_y or seam_x) return .{ 92, 62, 30, 255 };
        if (hash2(x, y / 2, 81) % 16 == 0) return .{ 148, 104, 55, 255 };
        const n = hash2(x, y, 82) % 14;
        return .{ 172 + @as(u8, @intCast(n)), 126 + @as(u8, @intCast(n / 2)), 70, 255 };
    }
    if (tile_x == 3 and tile_y == 2) {
        if (x < 2 or x > 13 or y < 2 or y > 13) return .{ 96, 62, 30, 255 };
        if ((x - 2) % 4 == 0 or (y - 2) % 4 == 0) return .{ 122, 84, 42, 255 };
        if ((x >= 6 and x <= 9 and y == 7) or (x == 8 and y >= 5 and y <= 9)) return .{ 70, 70, 74, 255 };
        const n = hash2(x, y, 83) % 12;
        return .{ 182 + @as(u8, @intCast(n)), 138 + @as(u8, @intCast(n / 2)), 80, 255 };
    }
    // Magma Block (4, 2): scorched obsidian crust with glowing molten lava fissures
    if (tile_x == 4 and tile_y == 2) {
        const fissure = ((x + y * 2) % 5 == 0) or ((x * 2 + y) % 7 == 0);
        if (fissure) {
            const hot = (x * 3 + y * 5) % 11 < 4;
            if (hot) return .{ 255, 230, 90, 255 }; // incandescent yellow heat
            return .{ 238, 92, 20, 255 }; // molten lava orange
        }
        const n = hash2(x, y, 179) % 24;
        return .{ 45 + @as(u8, @intCast(n)), 22 + @as(u8, @intCast(n / 3)), 20, 255 }; // dark scorched basalt
    }
    // Glowstone (5, 2): radiant crystalline golden-amber luminous mineral
    if (tile_x == 5 and tile_y == 2) {
        const crystal = (hash2(x, y, 193) % 7 == 0);
        if (crystal) return .{ 255, 250, 180, 255 }; // bright specular glint
        const n = hash2(x, y, 194) % 32;
        return .{ 245 + @as(u8, @intCast(n / 4)), 185 + @as(u8, @intCast(n)), 75 + @as(u8, @intCast(n / 2)), 255 };
    }
    // Nether Quartz Ore (6, 2): jagged crimson netherrack matrix embedded with crystalline white quartz veins
    if (tile_x == 6 and tile_y == 2) {
        const quartz_vein = ((x + y * 3) % 5 == 0 and x >= 3 and x <= 13) or ((x * 2 + y) % 7 == 0 and y >= 2 and y <= 14);
        if (quartz_vein) {
            const specular = hash2(x, y, 201) % 6 == 0;
            if (specular) return .{ 255, 255, 255, 255 }; // gleaming crystal glint
            const n = hash2(x, y, 202) % 20;
            return .{ 235 + @as(u8, @intCast(n)), 230 + @as(u8, @intCast(n)), 235 + @as(u8, @intCast(n / 2)), 255 };
        }
        // Crimson netherrack background
        const n = hash2(x, y, 203) % 25;
        return .{ 115 + @as(u8, @intCast(n)), 32 + @as(u8, @intCast(n / 3)), 32 + @as(u8, @intCast(n / 3)), 255 };
    }
    if (tile_x == 0 and tile_y == 3) {
        const cx = x / 4;
        const cy = y / 4;
        const lx: i32 = @as(i32, @intCast(x % 4)) - 1;
        const ly: i32 = @as(i32, @intCast(y % 4)) - 1;
        const corner = @max(lx, -lx) + @max(ly, -ly) >= 3;
        const shift = cy % 2;
        const mortar = corner or ((x + shift) % 4 == 0 and hash2(cx, cy, 91) % 3 == 0);
        if (mortar) return .{ 48, 48, 52, 255 };
        const n = hash2(x, y, 92) % 26;
        const shade: u8 = 118 + @as(u8, @intCast(n)) + @as(u8, @intCast((cx + cy) % 2 * 12));
        if ((lx == 0 and ly == -1) or (lx == -1 and ly == 0)) return .{ shade + 22, shade + 22, shade + 24, 255 };
        return .{ shade, shade, shade + 3, 255 };
    }
    if (tile_x == 1 and tile_y == 3) {
        const blob = isCoalBlob(x, y);
        if (blob == 2) return .{ 72, 72, 76, 255 };
        if (blob == 1) return .{ 18, 18, 20, 255 };
        return stonePixel(x, y, 93);
    }
    // Iron ore: stone base with rusty tan/peach metallic blobs
    if (tile_x == 2 and tile_y == 3) {
        const blob = isIronBlob(x, y);
        if (blob == 2) return .{ 225, 195, 170, 255 }; // light metallic specular
        if (blob == 1) return .{ 185, 138, 105, 255 }; // rusty peach core
        return stonePixel(x, y, 97);
    }
    // Sand tile: warm speckled golden beach sand
    if (tile_x == 3 and tile_y == 3) {
        return sandPixel(x, y);
    }
    // Glass tile (0, 4): transparent interior with cyan tint, border and specular streaks
    if (tile_x == 0 and tile_y == 4) {
        return glassPixel(x, y);
    }
    // Sandstone top (1, 4): smooth fine packed sand
    if (tile_x == 1 and tile_y == 4) {
        return sandstoneTopPixel(x, y);
    }
    // Sandstone side (2, 4): stratified layers with carved relief blocks at bottom
    if (tile_x == 2 and tile_y == 4) {
        return sandstoneSidePixel(x, y);
    }
    // Sandstone bottom (3, 4): rough cracked underside
    if (tile_x == 3 and tile_y == 4) {
        return sandstoneBottomPixel(x, y);
    }
    // Red Brick (4, 4): running bond bricks with light mortar seams
    if (tile_x == 4 and tile_y == 4) {
        return brickPixel(x, y);
    }
    // Pig skin (5, 4): soft pink with subtle tone shifts
    if (tile_x == 5 and tile_y == 4) {
        return pigSkinPixel(x, y);
    }
    // Pig face (6, 4): eyes and snout with nostrils
    if (tile_x == 6 and tile_y == 4) {
        return pigFacePixel(x, y);
    }
    // Furnace (0, 5): dark stone with glowing fire mouth
    if (tile_x == 0 and tile_y == 5) {
        const mouth = (y >= 9 and y <= 12) and (x >= 4 and x <= 11);
        const ember = mouth and hash2(x, y, 131) % 3 == 0;
        if (ember) return .{ 255, 140, 40, 255 };
        if (mouth) return .{ 30, 12, 8, 255 };
        const n = hash2(x, y, 132) % 26;
        const shade: u8 = 90 + @as(u8, @intCast(n));
        return .{ shade, shade, shade + 4, 255 };
    }
    // Snow (1, 5): sparkling white with blue shadow speckles
    if (tile_x == 1 and tile_y == 5) {
        const n = hash2(x, y, 141) % 20;
        const sparkle = hash2(x, y, 142) % 17 == 0;
        if (sparkle) return .{ 255, 255, 255, 255 };
        const base: u8 = 228 + @as(u8, @intCast(n));
        return .{ base - 8, base - 2, base, 255 };
    }
    // Wolf fur (2, 5): dark gray-brown matted coat
    if (tile_x == 2 and tile_y == 5) {
        const n = hash2(x, y, 151) % 22;
        const streak = (x + y) % 5 == 0;
        if (streak) return .{ 70 + @as(u8, @intCast(n / 2)), 62 + @as(u8, @intCast(n / 2)), 55, 255 };
        return .{ 95 + @as(u8, @intCast(n)), 86 + @as(u8, @intCast(n)), 76, 255 };
    }
    // Wolf face (3, 5): amber eyes, dark muzzle
    if (tile_x == 3 and tile_y == 5) {
        const eye = (y >= 6 and y <= 7) and ((x >= 2 and x <= 4) or (x >= 11 and x <= 13));
        if (eye) return .{ 230, 150, 40, 255 };
        const muzzle = (y >= 9 and y <= 13) and (x >= 5 and x <= 10);
        if (muzzle) return .{ 45, 40, 36, 255 };
        const n = hash2(x, y, 152) % 18;
        return .{ 100 + @as(u8, @intCast(n)), 90 + @as(u8, @intCast(n)), 80, 255 };
    }
    // Ladder (4, 5): wooden rungs on vertical rails
    if (tile_x == 4 and tile_y == 5) {
        const is_rail = (x <= 2 or x >= 13);
        const is_rung = (y % 4 == 0) and (x >= 2 and x <= 13);
        if (is_rail or is_rung) {
            const n = hash2(x, y, 161) % 15;
            return .{ 140 + @as(u8, @intCast(n)), 98 + @as(u8, @intCast(n / 2)), 52, 255 };
        }
        return .{ 0, 0, 0, 0 }; // transparent cutout between rungs
    }
    // TNT (5, 5): red dynamite sticks with white label stripe
    if (tile_x == 5 and tile_y == 5) {
        const is_band = (y >= 6 and y <= 9);
        if (is_band) return .{ 235, 235, 240, 255 };
        const seam = (x % 4 == 0);
        if (seam) return .{ 140, 25, 20, 255 };
        const n = hash2(x, y, 171) % 20;
        return .{ 215 + @as(u8, @intCast(n)), 35 + @as(u8, @intCast(n / 3)), 28, 255 };
    }
    // Torch (6, 5): vertical wooden shaft with glowing coal ember tip
    if (tile_x == 6 and tile_y == 5) {
        const is_shaft = (x >= 6 and x <= 9) and (y >= 4);
        const is_head = (x >= 5 and x <= 10) and (y <= 4);
        if (is_head) {
            const hot = (y <= 2) and (x >= 6 and x <= 9);
            if (hot) return .{ 255, 235, 120, 255 }; // yellow-white core
            return .{ 255, 130, 30, 255 }; // orange flame tip
        }
        if (is_shaft) {
            const n = hash2(x, y, 181) % 12;
            return .{ 120 + @as(u8, @intCast(n)), 80 + @as(u8, @intCast(n / 2)), 40, 255 };
        }
        return .{ 0, 0, 0, 0 };
    }
    // Wooden Door Closed (0, 6): vertical wooden planks with top square peephole window and iron knob
    if (tile_x == 0 and tile_y == 6) {
        // Window opening in upper quadrant (y: 3..5, x: 5..10)
        if (y >= 3 and y <= 5 and x >= 5 and x <= 10) {
            return .{ 30, 40, 50, 160 }; // glass tint cutout
        }
        // Iron door handle knob (y: 8..9, x: 12..13)
        if (y >= 8 and y <= 9 and x >= 12 and x <= 13) {
            return .{ 210, 210, 220, 255 };
        }
        // Plank panels & borders
        const is_border = (x == 1 or x == 14 or y == 1 or y == 14 or y == 7);
        if (is_border) return .{ 110, 75, 35, 255 };
        const n = hash2(x, y, 201) % 18;
        return .{ 145 + @as(u8, @intCast(n)), 95 + @as(u8, @intCast(n / 2)), 45, 255 };
    }
    // Wooden Door Open (1, 6): door swung 90 deg sideways, thin 3px edge strip visible with open air space
    if (tile_x == 1 and tile_y == 6) {
        if (x <= 2) {
            const is_handle = (y >= 8 and y <= 9 and x == 2);
            if (is_handle) return .{ 210, 210, 220, 255 };
            const n = hash2(x, y, 202) % 16;
            return .{ 130 + @as(u8, @intCast(n)), 85 + @as(u8, @intCast(n / 2)), 40, 255 };
        }
        return .{ 0, 0, 0, 0 }; // alpha pass-through
    }
    // Wooden Pressure Plate Unpressed (2, 6): central 10x10 wooden pad with raised chamfer edges
    if (tile_x == 2 and tile_y == 6) {
        if (x >= 2 and x <= 13 and y >= 2 and y <= 13) {
            const is_rim = (x == 2 or x == 13 or y == 2 or y == 13);
            if (is_rim) return .{ 110, 75, 35, 255 };
            const n = hash2(x, y, 211) % 16;
            return .{ 155 + @as(u8, @intCast(n)), 105 + @as(u8, @intCast(n / 2)), 50, 255 };
        }
        return .{ 0, 0, 0, 0 }; // transparent exterior margin
    }
    // Wooden Pressure Plate Pressed (3, 6): recessed darker pad with redstone contact pin in center
    if (tile_x == 3 and tile_y == 6) {
        if (x >= 3 and x <= 12 and y >= 3 and y <= 12) {
            const is_pin = (x >= 7 and x <= 8 and y >= 7 and y <= 8);
            if (is_pin) return .{ 220, 30, 20, 255 }; // redstone active spark center
            const is_rim = (x == 3 or x == 12 or y == 3 or y == 12);
            if (is_rim) return .{ 90, 60, 28, 255 };
            const n = hash2(x, y, 212) % 14;
            return .{ 125 + @as(u8, @intCast(n)), 80 + @as(u8, @intCast(n / 2)), 38, 255 };
        }
        return .{ 0, 0, 0, 0 }; // transparent margin
    }
    // Redstone Wire Off (4, 6): cross-pattern dust trail, dark crimson rust red
    if (tile_x == 4 and tile_y == 6) {
        const is_cross = (x >= 6 and x <= 9) or (y >= 6 and y <= 9);
        const is_dot = (x >= 4 and x <= 11 and y >= 4 and y <= 11) and (hash2(x, y, 221) % 4 != 0);
        if (is_cross or is_dot) {
            const n = hash2(x, y, 222) % 20;
            return .{ 120 + @as(u8, @intCast(n)), 16 + @as(u8, @intCast(n / 4)), 12, 255 };
        }
        return .{ 0, 0, 0, 0 };
    }
    // Redstone Wire On (5, 6): bright glowing neon vermilion dust trail with spark speckles
    if (tile_x == 5 and tile_y == 6) {
        const is_cross = (x >= 6 and x <= 9) or (y >= 6 and y <= 9);
        const is_dot = (x >= 4 and x <= 11 and y >= 4 and y <= 11) and (hash2(x, y, 223) % 4 != 0);
        if (is_cross or is_dot) {
            const spark = hash2(x, y, 224) % 9 == 0;
            if (spark) return .{ 255, 230, 180, 255 }; // bright electrical spark
            const n = hash2(x, y, 225) % 25;
            return .{ 230 + @as(u8, @intCast(n)), 45 + @as(u8, @intCast(n / 2)), 30, 255 };
        }
        return .{ 0, 0, 0, 0 };
    }
    // Lever Off (6, 6): cobblestone base mount with diagonal wooden handle pointing left
    if (tile_x == 6 and tile_y == 6) {
        // Cobblestone mounting plate at bottom: y: 11..14, x: 4..11
        if (y >= 11 and y <= 14 and x >= 4 and x <= 11) {
            const n = hash2(x, y, 231) % 20;
            return .{ 110 + @as(u8, @intCast(n)), 110 + @as(u8, @intCast(n)), 115, 255 };
        }
        // Wooden handle stick tilted up-left: x from 4..8, y from 4..11 (slope dy/dx ~ 1.5)
        const in_handle = (y >= 4 and y <= 11) and (x >= 4 and x <= 8) and (@as(i32, @intCast(y)) - @as(i32, @intCast(x)) >= -1 and @as(i32, @intCast(y)) - @as(i32, @intCast(x)) <= 5);
        if (in_handle) {
            const n = hash2(x, y, 232) % 15;
            return .{ 140 + @as(u8, @intCast(n)), 95 + @as(u8, @intCast(n / 2)), 45, 255 };
        }
        return .{ 0, 0, 0, 0 };
    }
    // Lever On (7, 6): cobblestone base mount with handle thrown down-right + glowing contact
    if (tile_x == 7 and tile_y == 6) {
        if (y >= 11 and y <= 14 and x >= 4 and x <= 11) {
            const is_spark = (x >= 9 and x <= 10 and y == 11);
            if (is_spark) return .{ 255, 60, 30, 255 }; // redstone active contact dot
            const n = hash2(x, y, 233) % 20;
            return .{ 110 + @as(u8, @intCast(n)), 110 + @as(u8, @intCast(n)), 115, 255 };
        }
        const in_handle_thrown = (y >= 7 and y <= 12) and (x >= 7 and x <= 12) and (@as(i32, @intCast(y)) + @as(i32, @intCast(x)) >= 17 and @as(i32, @intCast(y)) + @as(i32, @intCast(x)) <= 21);
        if (in_handle_thrown) {
            const n = hash2(x, y, 234) % 15;
            return .{ 140 + @as(u8, @intCast(n)), 95 + @as(u8, @intCast(n / 2)), 45, 255 };
        }
        return .{ 0, 0, 0, 0 };
    }
    // Redstone Repeater Off (0, 7): smooth stone slab base with two miniature dark redstone torches
    if (tile_x == 0 and tile_y == 7) {
        // Base plate: y: 2..13, x: 2..13
        if (x >= 2 and x <= 13 and y >= 2 and y <= 13) {
            // Two redstone torches along center vertical axis: (7, 4) and (7, 10)
            const is_torch1 = (x >= 7 and x <= 8 and y >= 3 and y <= 5);
            const is_torch2 = (x >= 7 and x <= 8 and y >= 9 and y <= 11);
            if (is_torch1 or is_torch2) {
                if (y == 3 or y == 9) return .{ 140, 20, 15, 255 }; // dark red tip
                return .{ 110, 80, 45, 255 }; // torch stick
            }
            const n = hash2(x, y, 241) % 16;
            return .{ 145 + @as(u8, @intCast(n)), 145 + @as(u8, @intCast(n)), 150, 255 }; // stone slab
        }
        return .{ 0, 0, 0, 0 };
    }
    // Redstone Repeater On (1, 7): stone slab base with two glowing lit redstone torches
    if (tile_x == 1 and tile_y == 7) {
        if (x >= 2 and x <= 13 and y >= 2 and y <= 13) {
            const is_torch1 = (x >= 7 and x <= 8 and y >= 3 and y <= 5);
            const is_torch2 = (x >= 7 and x <= 8 and y >= 9 and y <= 11);
            if (is_torch1 or is_torch2) {
                if (y == 3 or y == 9) return .{ 255, 60, 30, 255 }; // lit glowing redstone tip
                return .{ 130, 90, 50, 255 };
            }
            // Active power indicator line
            if (x >= 7 and x <= 8 and y >= 6 and y <= 8) return .{ 220, 40, 25, 255 };
            const n = hash2(x, y, 242) % 16;
            return .{ 145 + @as(u8, @intCast(n)), 145 + @as(u8, @intCast(n)), 150, 255 };
        }
        return .{ 0, 0, 0, 0 };
    }
    // Redstone Lamp Off (2, 7): dark amber glowstone glass framed in dark brass lattice
    if (tile_x == 2 and tile_y == 7) {
        const is_frame = (x <= 1 or x >= 14 or y <= 1 or y >= 14 or x == 7 or x == 8 or y == 7 or y == 8);
        if (is_frame) return .{ 65, 42, 22, 255 }; // dark wood/brass strut
        const n = hash2(x, y, 251) % 20;
        return .{ 115 + @as(u8, @intCast(n)), 60 + @as(u8, @intCast(n / 2)), 25, 255 }; // inactive reddish amber
    }
    // Redstone Lamp On (3, 7): brilliantly luminous bright golden-yellow incandescent glow with brass lattice
    if (tile_x == 3 and tile_y == 7) {
        const is_frame = (x <= 1 or x >= 14 or y <= 1 or y >= 14 or x == 7 or x == 8 or y == 7 or y == 8);
        if (is_frame) return .{ 95, 65, 30, 255 };
        const n = hash2(x, y, 252) % 15;
        return .{ 255, 225 + @as(u8, @intCast(n / 2)), 110 + @as(u8, @intCast(n)), 255 }; // glowing warm gold
    }
    // Iron Door Closed (4, 7): reinforced metallic iron plating with riveted borders and 2 square peepholes
    if (tile_x == 4 and tile_y == 7) {
        // Dual square viewing slits
        if ((y >= 3 and y <= 5 and x >= 4 and x <= 6) or (y >= 3 and y <= 5 and x >= 9 and x <= 11)) {
            return .{ 30, 35, 45, 140 }; // glass slit cutout
        }
        // Border frame and cross bracing
        const is_frame = (x == 1 or x == 14 or y == 1 or y == 14 or y == 7 or y == 8);
        if (is_frame) return .{ 150, 150, 155, 255 }; // dark metallic trim
        // Rivets at panel corners
        const is_rivet = (x == 3 or x == 12) and (y == 3 or y == 6 or y == 9 or y == 13);
        if (is_rivet) return .{ 240, 240, 245, 255 }; // specular rivet head
        const n = hash2(x, y, 261) % 20;
        return .{ 190 + @as(u8, @intCast(n)), 190 + @as(u8, @intCast(n)), 195 + @as(u8, @intCast(n / 2)), 255 };
    }
    // Iron Door Open (5, 7): 3px steel edge profile with alpha pass-through
    if (tile_x == 5 and tile_y == 7) {
        if (x <= 2) {
            const is_rivet = (y == 3 or y == 7 or y == 12);
            if (is_rivet and x == 1) return .{ 240, 240, 245, 255 };
            const n = hash2(x, y, 262) % 15;
            return .{ 175 + @as(u8, @intCast(n)), 175 + @as(u8, @intCast(n)), 180, 255 };
        }
        return .{ 0, 0, 0, 0 }; // alpha pass-through
    }
    // Redstone Torch Off (6, 7): wooden shaft with unlit dark crimson burnt redstone tip
    if (tile_x == 6 and tile_y == 7) {
        const is_shaft = (x >= 6 and x <= 9) and (y >= 5);
        const is_head = (x >= 5 and x <= 10) and (y <= 4);
        if (is_head) {
            const n = hash2(x, y, 271) % 16;
            return .{ 130 + @as(u8, @intCast(n)), 20 + @as(u8, @intCast(n / 4)), 15, 255 }; // dark red tip
        }
        if (is_shaft) {
            const n = hash2(x, y, 272) % 12;
            return .{ 120 + @as(u8, @intCast(n)), 80 + @as(u8, @intCast(n / 2)), 40, 255 };
        }
        return .{ 0, 0, 0, 0 };
    }
    // Redstone Torch On (7, 7): wooden shaft with radiant glowing neon redstone tip and electric aura
    if (tile_x == 7 and tile_y == 7) {
        const is_shaft = (x >= 6 and x <= 9) and (y >= 5);
        const is_head = (x >= 5 and x <= 10) and (y <= 4);
        if (is_head) {
            const hot = (y <= 2) and (x >= 6 and x <= 9);
            if (hot) return .{ 255, 120, 80, 255 }; // bright orange-red spark center
            const n = hash2(x, y, 273) % 20;
            return .{ 235 + @as(u8, @intCast(n)), 35 + @as(u8, @intCast(n / 3)), 25, 255 }; // radiant red head
        }
        if (is_shaft) {
            const n = hash2(x, y, 274) % 12;
            return .{ 120 + @as(u8, @intCast(n)), 80 + @as(u8, @intCast(n / 2)), 40, 255 };
        }
        return .{ 0, 0, 0, 0 };
    }
    // Chest (7, 5): oak wooden box with dark metal band and front latch
    if (tile_x == 7 and tile_y == 5) {
        // Latch on front center: 2x3 silver pixel
        if (x >= 7 and x <= 8 and y >= 6 and y <= 8) {
            return .{ 220, 220, 230, 255 };
        }
        // Metal rim/clasp band along middle-upper seam and outer edges
        const is_rim = (y == 0 or y == 15 or x == 0 or x == 15 or y == 7);
        if (is_rim) {
            const dark = hash2(x, y, 91) % 15;
            return .{ 45 + @as(u8, @intCast(dark)), 35 + @as(u8, @intCast(dark)), 25, 255 };
        }
        // Rich warm oak planks
        const n = hash2(x, y, 192) % 20;
        return .{ 165 + @as(u8, @intCast(n)), 110 + @as(u8, @intCast(n / 2)), 55, 255 };
    }
    // Wool (7, 4): soft off-white tufted fleece for sheep drops / beds
    if (tile_x == 7 and tile_y == 4) {
        const n = hash2(x, y, 118) % 18;
        const tuft = hash2(x / 2, y / 2, 119) % 5 == 0;
        if (tuft) return .{ 215 + @as(u8, @intCast(n / 2)), 208 + @as(u8, @intCast(n / 2)), 198, 255 };
        const base: u8 = 232 + @as(u8, @intCast(n));
        return .{ base, base - 4, base - 12, 255 };
    }
    return .{ 0, 0, 0, 0 };
}

fn pigSkinPixel(x: usize, y: usize) [4]u8 {
    const n = hash2(x, y, 115) % 15;
    const base_r: u8 = 240 + @as(u8, @intCast(n));
    const base_g: u8 = 165 + @as(u8, @intCast(n / 2));
    const base_b: u8 = 165 + @as(u8, @intCast(n / 2));
    return .{ base_r, base_g, base_b, 255 };
}

fn pigFacePixel(x: usize, y: usize) [4]u8 {
    const left_eye = (y >= 6 and y <= 7) and (x >= 2 and x <= 4);
    const right_eye = (y >= 6 and y <= 7) and (x >= 11 and x <= 13);
    const left_pupil = (y == 7) and (x == 3 or x == 4);
    const right_pupil = (y == 7) and (x == 11 or x == 12);
    if (left_pupil or right_pupil) return .{ 45, 30, 30, 255 };
    if (left_eye or right_eye) return .{ 255, 255, 255, 255 };

    const is_snout = (y >= 8 and y <= 11) and (x >= 5 and x <= 10);
    const is_nostril = (y == 9 or y == 10) and (x == 6 or x == 9);
    if (is_nostril) return .{ 140, 70, 70, 255 };
    if (is_snout) return .{ 215, 125, 125, 255 };

    return pigSkinPixel(x, y);
}

fn glassPixel(x: usize, y: usize) [4]u8 {
    const is_border = (x == 0 or x == 15 or y == 0 or y == 15);
    if (is_border) return .{ 220, 240, 255, 240 };
    if (x >= 3 and x <= 6 and y == x) return .{ 255, 255, 255, 210 };
    if (x >= 10 and x <= 12 and (y + 6 == x)) return .{ 245, 252, 255, 180 };
    return .{ 190, 225, 245, 30 };
}

fn sandstoneTopPixel(x: usize, y: usize) [4]u8 {
    const n = hash2(x, y, 105) % 100;
    if (n < 10) return .{ 215, 195, 140, 255 };
    if (n < 25) return .{ 240, 225, 175, 255 };
    return .{ 228, 210, 155, 255 };
}

fn sandstoneSidePixel(x: usize, y: usize) [4]u8 {
    if (y < 11) {
        const layer = (y / 3) % 2;
        const n = hash2(x, y, 106) % 20;
        const base_r: u8 = if (layer == 0) 228 else 215;
        const base_g: u8 = if (layer == 0) 210 else 195;
        const base_b: u8 = if (layer == 0) 155 else 140;
        return .{ base_r + @as(u8, @intCast(n / 2)), base_g + @as(u8, @intCast(n / 2)), base_b, 255 };
    }
    if (y == 11) return .{ 175, 150, 95, 255 };
    const block_sep = (x % 4 == 0);
    if (block_sep or y == 15) return .{ 185, 160, 105, 255 };
    return .{ 225, 205, 150, 255 };
}

fn sandstoneBottomPixel(x: usize, y: usize) [4]u8 {
    const crack = (x * 2 + y * 3) % 7 == 0;
    if (crack) return .{ 180, 155, 100, 255 };
    const n = hash2(x, y, 107) % 30;
    return .{ 205 + @as(u8, @intCast(n / 2)), 185 + @as(u8, @intCast(n / 2)), 135, 255 };
}

fn brickPixel(x: usize, y: usize) [4]u8 {
    const row = y / 4;
    const is_horiz_mortar = (y % 4 == 0);
    const shift: usize = if (row % 2 == 1) 4 else 0;
    const is_vert_mortar = ((x + shift) % 8 == 0);
    if (is_horiz_mortar or is_vert_mortar) {
        return .{ 215, 210, 205, 255 };
    }
    const n = hash2(x, y, 108) % 25;
    const shade: u8 = @as(u8, @intCast(n));
    return .{ 165 + shade, 65 + shade / 2, 52 + shade / 3, 255 };
}

fn sandPixel(x: usize, y: usize) [4]u8 {
    const n = hash2(x, y, 101) % 100;
    if (n < 8) return .{ 245, 230, 175, 255 };
    if (n < 22) return .{ 205, 185, 130, 255 };
    if (n < 50) return .{ 220, 202, 148, 255 };
    return .{ 232, 215, 160, 255 };
}

fn isIronBlob(x: usize, y: usize) u8 {
    // 3 distinct clusters offset from coal
    if (x >= 4 and x <= 6 and y >= 3 and y <= 5) {
        if (x == 5 and y == 4) return 1;
        if ((x == 4 or x == 6) and y == 4) return 2;
        if (x == 5 and (y == 3 or y == 5)) return 2;
        return 1;
    }
    if (x >= 11 and x <= 13 and y >= 8 and y <= 10) {
        if (x == 12 and y == 9) return 1;
        if ((x == 11 or x == 13) and y == 9) return 2;
        if (x == 12 and (y == 8 or y == 10)) return 2;
        return 1;
    }
    if (x >= 2 and x <= 4 and y >= 11 and y <= 13) {
        if (x == 3 and y == 12) return 1;
        return 2;
    }
    return 0;
}

fn dirtPixel(x: usize, y: usize) [4]u8 {
    const n = hash2(x, y, 23) % 100;
    if (n < 10) return .{ 78, 46, 24, 255 };
    if (n < 18) return .{ 150, 105, 62, 255 };
    if (n < 30) return .{ 108, 66, 34, 255 };
    return .{ 124, 76, 40, 255 };
}

fn stonePixel(x: usize, y: usize, seed: u32) [4]u8 {
    const n = hash2(x, y, seed) % 100;
    const crack = (x + 3 * y) % 16 == 0;
    if (crack) return .{ 70, 70, 73, 255 };
    if (n < 12) return .{ 88, 88, 92, 255 };
    if (n < 22) return .{ 152, 152, 156, 255 };
    return .{ 122, 122, 126, 255 };
}

fn isCoalBlob(x: usize, y: usize) u8 {
    if (x >= 2 and x <= 4 and y >= 2 and y <= 4) {
        if (x == 3 and y == 3) return 1;
        if (x == 3 and (y == 2 or y == 4)) return 1;
        if ((x == 2 or x == 4) and y == 3) return 1;
        return 2;
    }
    if (x >= 9 and x <= 11 and y >= 4 and y <= 6) {
        if (x == 10 and y == 5) return 1;
        if (x == 10 and (y == 4 or y == 6)) return 1;
        if ((x == 9 or x == 11) and y == 5) return 1;
        return 2;
    }
    if (x >= 5 and x <= 7 and y >= 10 and y <= 12) {
        if (x == 6 and y == 11) return 1;
        if (x == 6 and (y == 10 or y == 12)) return 1;
        if ((x == 5 or x == 7) and y == 11) return 1;
        return 2;
    }
    return 0;
}

pub fn createBlockTexture() c.GLuint {
    var texture: c.GLuint = 0;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    const atlas_size: usize = 128;
    var data: [128 * 128 * 4]u8 = undefined;
    @memset(&data, 0);
    var ty: usize = 0;
    while (ty < 8) : (ty += 1) {
        var tx: usize = 0;
        while (tx < 8) : (tx += 1) {
            var yy: usize = 0;
            while (yy < 16) : (yy += 1) {
                var xx: usize = 0;
                while (xx < 16) : (xx += 1) {
                    const px = tilePixel(@intCast(tx), @intCast(ty), xx, yy);
                    const idx = ((ty * 16 + yy) * 128 + (tx * 16 + xx)) * 4;
                    data[idx] = px[0];
                    data[idx + 1] = px[1];
                    data[idx + 2] = px[2];
                    data[idx + 3] = px[3];
                }
            }
        }
    }
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGBA, @intCast(atlas_size), @intCast(atlas_size), 0, c.GL_RGBA, c.GL_UNSIGNED_BYTE, &data);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);
    c.glBindTexture(c.GL_TEXTURE_2D, 0);
    return texture;
}

test "tile UV coordinates within unit quad" {
    const uv = getTileUV(1, 1);
    try std.testing.expectEqual(uv[0][0], 0.125);
    try std.testing.expectEqual(uv[0][1], 0.125);
    try std.testing.expectEqual(uv[2][0], 0.25);
    try std.testing.expectEqual(uv[2][1], 0.25);
}

test "all block tiles opaque, sand tile verified" {
    const tiles = [_][2]u32{ .{ 7, 5 }, .{ 7, 4 }, .{ 0, 5 }, .{ 1, 5 }, .{ 2, 5 }, .{ 3, 5 }, .{ 5, 5 }, .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 3, 0 }, .{ 1, 1 }, .{ 2, 1 }, .{ 3, 1 }, .{ 2, 2 }, .{ 3, 2 }, .{ 0, 3 }, .{ 1, 3 }, .{ 2, 3 }, .{ 3, 3 }, .{ 1, 4 }, .{ 2, 4 }, .{ 3, 4 }, .{ 4, 4 }, .{ 5, 4 }, .{ 6, 4 } };
    for (tiles) |t| {
        var yy: usize = 0;
        while (yy < 16) : (yy += 1) {
            var xx: usize = 0;
            while (xx < 16) : (xx += 1) {
                try std.testing.expectEqual(tilePixel(t[0], t[1], xx, yy)[3], 255);
            }
        }
    }
    // Sand tile golden tone check
    try std.testing.expect(tilePixel(3, 3, 0, 0)[0] > 200);
    try std.testing.expect(tilePixel(3, 3, 0, 0)[1] > 180);
    // Iron ore blob center check
    try std.testing.expectEqual(tilePixel(2, 3, 5, 4)[0], 185);
    try std.testing.expectEqual(tilePixel(0, 0, 3, 3)[1] > tilePixel(0, 0, 3, 3)[0], true);
    try std.testing.expectEqual(tilePixel(1, 3, 3, 3)[0], 18);
    try std.testing.expectEqual(tilePixel(1, 3, 10, 5)[0], 18);
    try std.testing.expectEqual(tilePixel(1, 3, 6, 11)[0], 18);
}

test "redstone torch tiles rendered with dark vs radiant tips" {
    try std.testing.expectEqual(tilePixel(6, 7, 0, 0)[3], 0); // transparent background
    try std.testing.expect(tilePixel(6, 7, 7, 3)[0] < 160); // dark red tip
    try std.testing.expectEqual(tilePixel(7, 7, 7, 1)[0], 255); // glowing center
    try std.testing.expectEqual(tilePixel(7, 7, 7, 8)[3], 255); // wood shaft
}

test "iron door tiles rendered with rivets and slit cutout" {
    try std.testing.expectEqual(tilePixel(4, 7, 5, 4)[3], 140); // window slit
    try std.testing.expectEqual(tilePixel(4, 7, 3, 3)[0], 240); // rivet head
    try std.testing.expectEqual(tilePixel(5, 7, 0, 0)[3], 255); // edge
    try std.testing.expectEqual(tilePixel(5, 7, 10, 10)[3], 0);  // pass-through
}

test "lamp tiles rendered with lattice frame and amber/golden cores" {
    try std.testing.expectEqual(tilePixel(2, 7, 0, 0)[0], 65); // frame
    try std.testing.expect(tilePixel(2, 7, 4, 4)[0] > 100); // dark amber
    try std.testing.expectEqual(tilePixel(3, 7, 4, 4)[0], 255); // brilliant glow
    try std.testing.expect(tilePixel(3, 7, 4, 4)[1] > 200);
}

test "repeater tiles rendered with stone slab base and dual torches" {
    try std.testing.expectEqual(tilePixel(0, 7, 0, 0)[3], 0);
    try std.testing.expectEqual(tilePixel(0, 7, 5, 5)[3], 255); // slab
    try std.testing.expectEqual(tilePixel(0, 7, 7, 3)[0], 140); // dark torch tip
    try std.testing.expectEqual(tilePixel(1, 7, 7, 3)[0], 255); // lit torch tip
}

test "lever tiles rendered with mount and handle" {
    try std.testing.expectEqual(tilePixel(6, 6, 0, 0)[3], 0);
    try std.testing.expectEqual(tilePixel(6, 6, 7, 12)[3], 255); // base plate
    try std.testing.expectEqual(tilePixel(7, 6, 0, 0)[3], 0);
    try std.testing.expectEqual(tilePixel(7, 6, 9, 11)[0], 255); // active contact dot
}

test "redstone wire tiles rendered with cross dust pattern" {
    try std.testing.expectEqual(tilePixel(4, 6, 0, 0)[3], 0);
    try std.testing.expectEqual(tilePixel(4, 6, 7, 7)[3], 255);
    try std.testing.expect(tilePixel(4, 6, 7, 7)[0] < 150); // dark red
    try std.testing.expectEqual(tilePixel(5, 6, 0, 0)[3], 0);
    try std.testing.expectEqual(tilePixel(5, 6, 7, 7)[3], 255);
    try std.testing.expect(tilePixel(5, 6, 7, 7)[0] >= 230); // bright neon red
}

test "pressure plate tiles rendered with transparent border" {
    try std.testing.expectEqual(tilePixel(2, 6, 0, 0)[3], 0);
    try std.testing.expectEqual(tilePixel(2, 6, 5, 5)[3], 255);
    try std.testing.expectEqual(tilePixel(3, 6, 0, 0)[3], 0);
    try std.testing.expectEqual(tilePixel(3, 6, 7, 7)[0], 220); // redstone pin red
}

test "grass side fringe green on top, dirt at bottom" {
    var xx: usize = 0;
    while (xx < 16) : (xx += 1) {
        const top = tilePixel(1, 0, xx, 0);
        try std.testing.expect(top[1] > top[0]);
        const bot = tilePixel(1, 0, xx, 15);
        try std.testing.expect(bot[0] > bot[1]);
    }
}
