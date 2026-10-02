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

/// Procedural 64x64 texture atlas containing grass top, grass side, dirt, stone, and water tiles.
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

            // Tile (0,1): Water - animated/vibrant blue water with alpha 190
            const w_noise = (x * 17 + y * 7) % 21;
            const water_idx = ((16 + y) * 64 + x) * 4;
            data[water_idx] = 35 + @as(u8, @intCast(w_noise / 2));
            data[water_idx + 1] = 95 + @as(u8, @intCast(w_noise));
            data[water_idx + 2] = 210 + @as(u8, @intCast(w_noise * 2));
            data[water_idx + 3] = 185; // 72% opacity
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

    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
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

    const uv_water = getTileUV(0, 1);
    try std.testing.expectEqual(uv_water[0][0], 0.0);
    try std.testing.expectEqual(uv_water[0][1], 0.25);
    try std.testing.expectEqual(uv_water[2][0], 0.25);
    try std.testing.expectEqual(uv_water[2][1], 0.50);
}
