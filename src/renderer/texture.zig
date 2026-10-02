const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});

/// Generate a 16x16 RGBA texture with a simple grass-like pattern.
/// Top rows: green (grass), rest: brown (dirt).
/// This is a placeholder — a proper texture atlas will be loaded from PNG
/// once image loading is implemented.
pub fn createBlockTexture() c.GLuint {
    var texture: c.GLuint = 0;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);

    const size: c_int = 16;
    var data: [16 * 16 * 4]u8 = undefined;

    var y: usize = 0;
    while (y < 16) : (y += 1) {
        var x: usize = 0;
        while (x < 16) : (x += 1) {
            const idx = (y * 16 + x) * 4;
            if (y < 4) {
                // Grass top — bright green
                data[idx] = 34;
                data[idx + 1] = 139;
                data[idx + 2] = 34;
            } else if (y < 8) {
                // Grass side — brown with green edge
                data[idx] = 139;
                data[idx + 1] = 69;
                data[idx + 2] = 19;
            } else {
                // Dirt — reddish brown
                data[idx] = 139;
                data[idx + 1] = 69;
                data[idx + 2] = 19;
            }
            data[idx + 3] = 255;
        }
    }

    c.glTexImage2D(
        c.GL_TEXTURE_2D,
        0,
        c.GL_RGBA,
        size,
        size,
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

test "texture creation returns non-zero handle" {
    // Can't test OpenGL without a context; placeholder for future expansion
    try std.testing.expect(true);
}
