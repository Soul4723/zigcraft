const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});

/// Atlas layout: 4 columns x 4 rows of 16x16 tiles (total 64x64 RGBA).
/// Tile indices:
/// (0, 0) = Grass Top
/// (1, 0) = Grass Side
/// (2, 0) = Dirt
/// (3, 0) = Stone
/// (0, 1) = Water (Translucent blue)
/// (1, 1) = Wood Log Side (Brown bark)
/// (2, 1) = Wood Log Top (Ring pattern)
/// (3, 1) = Leaves (Lush dark green foliage)
/// (0, 2) = Mob Body (Fluffy wool/skin texture)
/// (1, 2) = Mob Face (Pig / Sheep / Creature face with eyes)
/// (2, 2) = Wood Planks (Clean horizontal lumber boards)
/// (3, 2) = Crafting Table Top/Side (Grid pattern & crafting tools)
pub const ATLAS_TILES_PER_ROW: f32 = 4.0;
pub const TILE_UV_SIZE: f32 = 1.0 / ATLAS_TILES_PER_ROW; // 0.25

pub fn getTileUV(tile_x: u32, tile_y: u32) [4][2]f32 {
    const u_min = @as(f32, @floatFromInt(tile_x)) * TILE_UV_SIZE;
    const v_min = @as(f32, @floatFromInt(tile_y)) * TILE_UV_SIZE;
    const u_max = u_min + TILE_UV_SIZE;
    const v_max = v_min + TILE_UV_SIZE;

    return .{
        .{ u_min, v_min },
        .{ u_max, v_min },
        .{ u_max, v_max },
        .{ u_min, v_max },
    };
}

/// Procedural 64x64 texture atlas containing blocks and mob textures.
pub fn createBlockTexture() c.GLuint {
    var texture: c.GLuint = 0;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);

    const atlas_size: usize = 64;
    var data: [64 * 64 * 4]u8 = undefined;

    // Fill all with default black/transparent
    @memset(&data, 0);

    var y: usize = 0;
    while (y < 16) : (y += 1) {
        var x: usize = 0;
        while (x < 16) : (x += 1) {
            // Tile (0,0): Grass Top - lush green noise
            const noise1 = (x * 7 + y * 13) % 17;
            const gt_idx = (y * 64 + x) * 4;
            data[gt_idx] = 45 + @as(u8, @intCast(noise1));
            data[gt_idx + 1] = 160 + @as(u8, @intCast(noise1 * 2));
            data[gt_idx + 2] = 40;
            data[gt_idx + 3] = 255;

            // Tile (1,0): Grass Side - green top 4px, dirt below
            const gs_idx = (y * 64 + (16 + x)) * 4;
            if (y < 4) {
                data[gs_idx] = 45 + @as(u8, @intCast(noise1));
                data[gs_idx + 1] = 160 + @as(u8, @intCast(noise1 * 2));
                data[gs_idx + 2] = 40;
            } else {
                const dirt_noise = (x * 11 + y * 5) % 19;
                data[gs_idx] = 120 + @as(u8, @intCast(dirt_noise));
                data[gs_idx + 1] = 72 + @as(u8, @intCast(dirt_noise / 2));
                data[gs_idx + 2] = 38;
            }
            data[gs_idx + 3] = 255;

            // Tile (2,0): Dirt - rich brown soil texture
            const dirt_idx = (y * 64 + (32 + x)) * 4;
            const d_noise = (x * 11 + y * 5) % 23;
            data[dirt_idx] = 120 + @as(u8, @intCast(d_noise));
            data[dirt_idx + 1] = 72 + @as(u8, @intCast(d_noise / 2));
            data[dirt_idx + 2] = 38;
            data[dirt_idx + 3] = 255;

            // Tile (3,0): Stone - mottled gray rock texture
            const stone_idx = (y * 64 + (48 + x)) * 4;
            const s_noise = (x * 13 + y * 17) % 29;
            const gray = 115 + @as(u8, @intCast(s_noise));
            data[stone_idx] = gray;
            data[stone_idx + 1] = gray;
            data[stone_idx + 2] = gray + 3;
            data[stone_idx + 3] = 255;

            // Tile (0,1): Water - vibrant blue water with alpha 185
            const w_noise = (x * 17 + y * 7) % 21;
            const water_idx = ((16 + y) * 64 + x) * 4;
            data[water_idx] = 35 + @as(u8, @intCast(w_noise / 2));
            data[water_idx + 1] = 95 + @as(u8, @intCast(w_noise));
            data[water_idx + 2] = 210 + @as(u8, @intCast(w_noise * 2));
            data[water_idx + 3] = 185;

            // Tile (1,1): Wood Log Side - vertical tree bark grain
            const log_side_idx = ((16 + y) * 64 + (16 + x)) * 4;
            const bark = (x * 19 + y * 3) % 25;
            data[log_side_idx] = 95 + @as(u8, @intCast(bark));
            data[log_side_idx + 1] = 60 + @as(u8, @intCast(bark / 2));
            data[log_side_idx + 2] = 30;
            data[log_side_idx + 3] = 255;

            // Tile (2,1): Wood Log Top - circular ring pattern
            const log_top_idx = ((16 + y) * 64 + (32 + x)) * 4;
            const dx: f32 = @as(f32, @floatFromInt(x)) - 7.5;
            const dy: f32 = @as(f32, @floatFromInt(y)) - 7.5;
            const dist: u8 = @intFromFloat(@sqrt(dx * dx + dy * dy) * 3.0);
            const ring = if (dist % 4 == 0) @as(u8, 20) else @as(u8, 0);
            data[log_top_idx] = 150 - ring;
            data[log_top_idx + 1] = 115 - ring;
            data[log_top_idx + 2] = 70;
            data[log_top_idx + 3] = 255;

            // Tile (3,1): Leaves - dappled dark green foliage
            const leaf_idx = ((16 + y) * 64 + (48 + x)) * 4;
            const l_noise = (x * 13 + y * 23) % 35;
            data[leaf_idx] = 30 + @as(u8, @intCast(l_noise / 3));
            data[leaf_idx + 1] = 100 + @as(u8, @intCast(l_noise));
            data[leaf_idx + 2] = 25;
            data[leaf_idx + 3] = 255;

            // Tile (0,2): Mob Wool Body - off-white soft fleece texture
            const wool_idx = ((32 + y) * 64 + x) * 4;
            const wool_n = (x * 9 + y * 11) % 15;
            const wool_c: u8 = 225 + @as(u8, @intCast(wool_n));
            data[wool_idx] = wool_c;
            data[wool_idx + 1] = wool_c;
            data[wool_idx + 2] = wool_c - 5;
            data[wool_idx + 3] = 255;

            // Tile (1,2): Mob Face - sheep face with eyes and pinkish muzzle
            const face_idx = ((32 + y) * 64 + (16 + x)) * 4;
            // Eyes at y in [6..8], x in [3..4] and [11..12]
            const is_eye_white = (y >= 6 and y <= 8) and ((x >= 2 and x <= 5) or (x >= 10 and x <= 13));
            const is_pupil = (y >= 7 and y <= 8) and ((x >= 4 and x <= 5) or (x >= 10 and x <= 11));
            // Muzzle at y in [9..13], x in [5..10]
            const is_muzzle = (y >= 9 and y <= 13) and (x >= 5 and x <= 10);

            if (is_pupil) {
                data[face_idx] = 35;
                data[face_idx + 1] = 30;
                data[face_idx + 2] = 30;
            } else if (is_eye_white) {
                data[face_idx] = 245;
                data[face_idx + 1] = 245;
                data[face_idx + 2] = 245;
            } else if (is_muzzle) {
                data[face_idx] = 220;
                data[face_idx + 1] = 180;
                data[face_idx + 2] = 170;
            } else {
                // Tan face skin
                const face_n = (x * 7 + y * 5) % 11;
                data[face_idx] = 205 + @as(u8, @intCast(face_n));
                data[face_idx + 1] = 190 + @as(u8, @intCast(face_n));
                data[face_idx + 2] = 175;
            }
            data[face_idx + 3] = 255;

            // Tile (2,2): Wood Planks - horizontal lumber planks with seams
            const plank_idx = ((32 + y) * 64 + (32 + x)) * 4;
            const is_seam_y = (y % 4 == 0);
            const is_seam_x = (y < 4 and x == 8) or (y >= 4 and y < 8 and x == 14) or (y >= 8 and y < 12 and x == 4) or (y >= 12 and x == 10);
            const plank_n = (x * 13 + y * 7) % 15;
            if (is_seam_y or is_seam_x) {
                data[plank_idx] = 95;
                data[plank_idx + 1] = 65;
                data[plank_idx + 2] = 32;
            } else {
                data[plank_idx] = 170 + @as(u8, @intCast(plank_n));
                data[plank_idx + 1] = 125 + @as(u8, @intCast(plank_n / 2));
                data[plank_idx + 2] = 72;
            }
            data[plank_idx + 3] = 255;

            // Tile (3,2): Crafting Table - wooden borders with 3x3 checkered grid top
            const craft_idx = ((32 + y) * 64 + (48 + x)) * 4;
            const is_border = (x == 0 or x == 15 or y == 0 or y == 15);
            const grid_cell = ((x / 5) + (y / 5)) % 2 == 0;
            if (is_border) {
                data[craft_idx] = 110;
                data[craft_idx + 1] = 70;
                data[craft_idx + 2] = 35;
            } else if (grid_cell) {
                data[craft_idx] = 190;
                data[craft_idx + 1] = 145;
                data[craft_idx + 2] = 85;
            } else {
                data[craft_idx] = 160;
                data[craft_idx + 1] = 115;
                data[craft_idx + 2] = 65;
            }
            data[craft_idx + 3] = 255;
        }
    }

    c.glTexImage2D(
        c.GL_TEXTURE_2D,
        0,
        c.GL_RGBA,
        @intCast(atlas_size),
        @intCast(atlas_size),
        0,
        c.GL_RGBA,
        c.GL_UNSIGNED_BYTE,
        &data,
    );

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_NEAREST);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_NEAREST);

    c.glBindTexture(c.GL_TEXTURE_2D, 0);
    return texture;
}

test "tile UV coordinates within unit quad" {
    const uv_gt = getTileUV(0, 0);
    try std.testing.expectEqual(uv_gt[0][0], 0.0);
    try std.testing.expectEqual(uv_gt[0][1], 0.0);
    try std.testing.expectEqual(uv_gt[2][0], 0.25);
    try std.testing.expectEqual(uv_gt[2][1], 0.25);

    const uv_wood = getTileUV(1, 1);
    try std.testing.expectEqual(uv_wood[0][0], 0.25);
    try std.testing.expectEqual(uv_wood[0][1], 0.25);

    const uv_mob_face = getTileUV(1, 2);
    try std.testing.expectEqual(uv_mob_face[0][0], 0.25);
    try std.testing.expectEqual(uv_mob_face[0][1], 0.50);
}
