const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});

pub const ATLAS_TILES_PER_ROW: f32 = 4.0;
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
    return .{ 0, 0, 0, 0 };
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
    const atlas_size: usize = 64;
    var data: [64 * 64 * 4]u8 = undefined;
    @memset(&data, 0);
    var ty: usize = 0;
    while (ty < 4) : (ty += 1) {
        var tx: usize = 0;
        while (tx < 4) : (tx += 1) {
            var yy: usize = 0;
            while (yy < 16) : (yy += 1) {
                var xx: usize = 0;
                while (xx < 16) : (xx += 1) {
                    const px = tilePixel(@intCast(tx), @intCast(ty), xx, yy);
                    const idx = ((ty * 16 + yy) * 64 + (tx * 16 + xx)) * 4;
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
    try std.testing.expectEqual(uv[0][0], 0.25);
    try std.testing.expectEqual(uv[0][1], 0.25);
    try std.testing.expectEqual(uv[2][0], 0.5);
    try std.testing.expectEqual(uv[2][1], 0.5);
}

test "all block tiles opaque, reserved transparent" {
    const tiles = [_][2]u32{ .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 3, 0 }, .{ 1, 1 }, .{ 2, 1 }, .{ 3, 1 }, .{ 2, 2 }, .{ 3, 2 }, .{ 0, 3 }, .{ 1, 3 }, .{ 2, 3 } };
    for (tiles) |t| {
        var yy: usize = 0;
        while (yy < 16) : (yy += 1) {
            var xx: usize = 0;
            while (xx < 16) : (xx += 1) {
                try std.testing.expectEqual(tilePixel(t[0], t[1], xx, yy)[3], 255);
            }
        }
    }
    try std.testing.expectEqual(tilePixel(3, 3, 4, 4)[3], 0);
    // Iron ore blob center check
    try std.testing.expectEqual(tilePixel(2, 3, 5, 4)[0], 185);
    try std.testing.expectEqual(tilePixel(0, 0, 3, 3)[1] > tilePixel(0, 0, 3, 3)[0], true);
    try std.testing.expectEqual(tilePixel(1, 3, 3, 3)[0], 18);
    try std.testing.expectEqual(tilePixel(1, 3, 10, 5)[0], 18);
    try std.testing.expectEqual(tilePixel(1, 3, 6, 11)[0], 18);
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
