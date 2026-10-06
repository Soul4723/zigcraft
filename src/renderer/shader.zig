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

/// Set a 4x4 matrix uniform (column-major, as produced by Mat4.ptr()).
pub fn setUniformMat4(program: c.GLuint, name: [:0]const u8, matrix_ptr: [*c]const f32) void {
    const loc = getUniformLocation(program, name);
    c.glUniformMatrix4fv(loc, 1, c.GL_FALSE, matrix_ptr);
}

/// Set an integer uniform (used for sampler2D texture units).
pub fn setUniformInt(program: c.GLuint, name: [:0]const u8, value: c.GLint) void {
    const loc = getUniformLocation(program, name);
    c.glUniform1i(loc, value);
}

pub fn setUniformVec3(program: c.GLuint, name: [:0]const u8, x: f32, y: f32, z: f32) void {
    const loc = getUniformLocation(program, name);
    c.glUniform3f(loc, x, y, z);
}

/// Default shader sources for a colored triangle with MVP transform.
pub const default_vert: [:0]const u8 =
\\#version 330 core
\\layout (location = 0) in vec3 aPos;
\\layout (location = 1) in vec3 aColor;
\\uniform mat4 u_mvp;
\\out vec3 vertexColor;
\\void main() {
\\    gl_Position = u_mvp * vec4(aPos, 1.0);
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

/// Chunk shader sources for textured rendering with MVP transform and per-vertex Ambient Occlusion.
/// Vertex layout: position (loc 0), normal (loc 1), tex_coord (loc 2), ao (loc 3).
pub const chunk_vert: [:0]const u8 =
\\#version 330 core
\\layout (location = 0) in vec3 aPos;
\\layout (location = 1) in vec3 aNormal;
\\layout (location = 2) in vec2 aTexCoord;
\\layout (location = 3) in float aAO;
\\layout (location = 4) in float aEmissive;
\\uniform mat4 u_mvp;
\\out vec2 FragTexCoord;
\\out vec3 FragNormal;
\\out float FragAO;
\\out float FragEmissive;
\\void main() {
\\    gl_Position = u_mvp * vec4(aPos, 1.0);
\\    FragTexCoord = aTexCoord;
\\    FragNormal = aNormal;
\\    FragAO = aAO;
\\    FragEmissive = aEmissive;
\\}
;
/// Wireframe box shader: position (loc 0), MVP + solid color.
pub const line_vert: [:0]const u8 =
\\#version 330 core
\\layout (location = 0) in vec3 aPos;
\\uniform mat4 u_mvp;
\\void main() {
\\    gl_Position = u_mvp * vec4(aPos, 1.0);
\\}
;

pub const line_frag: [:0]const u8 =
\\#version 330 core
\\out vec4 FragColor;
\\uniform vec3 u_color;
\\void main() {
\\    FragColor = vec4(u_color, 1.0);
\\}
;


pub const sky_vert: [:0]const u8 =
\\#version 330 core
\\layout (location = 0) in vec3 aPos;
\\out vec3 FragDir;
\\uniform mat4 u_view_proj;
\\void main() {
\\    FragDir = aPos;
\\    vec4 pos = u_view_proj * vec4(aPos * 500.0 + vec3(0.0, 0.0, 0.0), 1.0);
\\    gl_Position = pos.xyww;
\\}
;

pub const sky_frag: [:0]const u8 =
\\#version 330 core
\\in vec3 FragDir;
\\out vec4 FragColor;
\\uniform vec3 u_top;
\\uniform vec3 u_horizon;
\\void main() {
\\    float t = clamp(normalize(FragDir).y * 0.5 + 0.5, 0.0, 1.0);
\\    vec3 col = mix(u_horizon, u_top, pow(t, 0.8));
\\    FragColor = vec4(col, 1.0);
\\}
;

pub const chunk_frag: [:0]const u8 =
\\#version 330 core
\\in vec2 FragTexCoord;
\\in vec3 FragNormal;
\\in float FragAO;
\\in float FragEmissive;
\\out vec4 FragColor;
\\uniform sampler2D u_texture;
\\uniform vec3 u_light_dir;
\\void main() {
\\    float diff = max(dot(normalize(FragNormal), normalize(u_light_dir)), 0.0);
\\    float ambient = 0.35;
\\    // FragAO in [0.0..1.0]: 1.0 = fully open, 0.0 = deeply occluded
\\    float ao_factor = 0.55 + 0.45 * FragAO;
\\    float sun = (ambient + 0.65 * diff) * ao_factor;
\\    float light = mix(sun, 1.0, clamp(FragEmissive, 0.0, 1.0));
\\    vec4 tex = texture(u_texture, FragTexCoord);
\\    FragColor = vec4(tex.rgb * light, tex.a);
\\}
;
