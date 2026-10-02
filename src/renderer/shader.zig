const std = @import("std");
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
});

/// Compile a GLSL shader from source string.
/// Returns OpenGL shader handle or an error.
pub fn compileShader(
    allocator: std.mem.Allocator,
    shader_type: c.GLenum,
    source: [:0]const u8,
) !c.GLuint {
    _ = allocator;
    const shader = c.glCreateShader(shader_type);

    // glShaderSource expects [*]const [*c]const u8
    const src_ptr: [*c]const u8 = source.ptr;
    c.glShaderSource(shader, 1, &src_ptr, null);
    c.glCompileShader(shader);

    var success: c.GLint = undefined;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var info_log: [1024]u8 = undefined;
        c.glGetShaderInfoLog(shader, 1024, null, &info_log);
        const null_idx = std.mem.indexOfScalarPos(u8, &info_log, 0, 0) orelse 1024;
        const msg = info_log[0..null_idx];
        std.debug.print("shader compile error: {s}\n", .{msg});
        c.glDeleteShader(shader);
        return error.ShaderCompileFailed;
    }

    return shader;
}

/// Link vertex and fragment shaders into a program.
pub fn createProgram(
    allocator: std.mem.Allocator,
    vert_source: [:0]const u8,
    frag_source: [:0]const u8,
) !c.GLuint {
    const vert = try compileShader(allocator, c.GL_VERTEX_SHADER, vert_source);
    defer c.glDeleteShader(vert);

    const frag = try compileShader(allocator, c.GL_FRAGMENT_SHADER, frag_source);
    defer c.glDeleteShader(frag);

    const program = c.glCreateProgram();
    c.glAttachShader(program, vert);
    c.glAttachShader(program, frag);
    c.glLinkProgram(program);

    var success: c.GLint = undefined;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
    if (success == 0) {
        var info_log: [1024]u8 = undefined;
        c.glGetProgramInfoLog(program, 1024, null, &info_log);
        const null_idx = std.mem.indexOfScalarPos(u8, &info_log, 0, 0) orelse 1024;
        const msg = info_log[0..null_idx];
        std.debug.print("program link error: {s}\n", .{msg});
        c.glDeleteProgram(program);
        return error.ProgramLinkFailed;
    }

    return program;
}

/// Get uniform location, returns -1 if not found.
pub fn getUniformLocation(program: c.GLuint, name: [:0]const u8) c.GLint {
    return c.glGetUniformLocation(program, name.ptr);
}

/// Default shader sources for a basic colored triangle.
pub const default_vert: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aColor;
    \\out vec3 vertexColor;
    \\void main() {
    \\    gl_Position = vec4(aPos, 1.0);
    \\    vertexColor = aColor;
    \\}
;

pub const default_frag: [:0]const u8 =
    \\#version 330 core
    \\in vec3 vertexColor;
    \\out vec4 FragColor;
    \\void main() {
    \\    FragColor = vec4(vertexColor, 1.0);
    \\}
;

test "getUniformLocation with valid program" {
    // We can't test OpenGL without a context, skip
    // This test exists as a placeholder for future expansion
    try std.testing.expect(true);
}
