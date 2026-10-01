# OpenGL 3.3 Rendering Pipeline in Zig

Date: 2026-10-01
Question: How to set up a basic shader pipeline and render geometry in
OpenGL 3.3 using Zig's C interop?

## Overview

OpenGL 3.3 core profile requires explicit shader programs and vertex
specifications. No fixed-function pipeline.

## Shader Setup

Shaders are written in GLSL 330. Compile and link at runtime:

```zig
fn compileShader(shader_type: c.GLenum, source: [*c]const u8) !c.GLuint {
    const shader = c.glCreateShader(shader_type);
    c.glShaderSource(shader, 1, &source, null);
    c.glCompileShader(shader);

    var success: c.GLint = 0;
    c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        var info_log: [512]u8 = undefined;
        c.glGetShaderInfoLog(shader, 512, null, &info_log);
        std.debug.print("shader compile error: {s}\n", .{&info_log});
        return error.ShaderCompileFailed;
    }
    return shader;
}

fn createShaderProgram(vert_src: [*c]const u8, frag_src: [*c]const u8) !c.GLuint {
    const vert = try compileShader(c.GL_VERTEX_SHADER, vert_src);
    const frag = try compileShader(c.GL_FRAGMENT_SHADER, frag_src);

    const program = c.glCreateProgram();
    c.glAttachShader(program, vert);
    c.glAttachShader(program, frag);
    c.glLinkProgram(program);

    var success: c.GLint = 0;
    c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);
    if (success == 0) {
        var info_log: [512]u8 = undefined;
        c.glGetProgramInfoLog(program, 512, null, &info_log);
        std.debug.print("program link error: {s}\n", .{&info_log});
        return error.ProgramLinkFailed;
    }

    c.glDeleteShader(vert);
    c.glDeleteShader(frag);
    return program;
}
```

## Vertex Data

VAO (Vertex Array Object) + VBO (Vertex Buffer Object):

```zig
const vertices = [_]f32{
    // positions        // colors
    -0.5, -0.5, 0.0,   1.0, 0.0, 0.0,
     0.5, -0.5, 0.0,   0.0, 1.0, 0.0,
     0.0,  0.5, 0.0,   0.0, 0.0, 1.0,
};

var vao: c.GLuint = 0;
var vbo: c.GLuint = 0;
c.glGenVertexArrays(1, &vao);
c.glGenBuffers(1, &vbo);

c.glBindVertexArray(vao);
c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
c.glBufferData(c.GL_ARRAY_BUFFER, @intCast(@sizeOf(@TypeOf(vertices))),
    &vertices, c.GL_STATIC_DRAW);

// Position attribute (location = 0)
c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32),
    @ptrFromInt(0));
c.glEnableVertexAttribArray(0);

// Color attribute (location = 1)
c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32),
    @ptrFromInt(3 * @sizeOf(f32)));
c.glEnableVertexAttribArray(1);
```

## GLSL Shaders (330 core)

Vertex shader:
```glsl
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aColor;
out vec3 vertexColor;
uniform mat4 mvp;
void main() {
    gl_Position = mvp * vec4(aPos, 1.0);
    vertexColor = aColor;
}
```

Fragment shader:
```glsl
#version 330 core
in vec3 vertexColor;
out vec4 FragColor;
void main() {
    FragColor = vec4(vertexColor, 1.0);
}
```

## Draw Call

```zig
c.glUseProgram(shader_program);
c.glBindVertexArray(vao);
c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
```

## Zig C Interop Gotchas

- `@sizeOf` for buffer sizes — cast to `c.GLsizeiptr` with `@intCast`
- Null pointers for offset: use `@ptrFromInt(0)` not `null`
- GLSL source strings: use `[*c]const u8` type, Zig string literals work
- `glGetUniformLocation` returns `c.GLint`, -1 means not found
- Uniform matrix upload: `c.glUniformMatrix4fv(loc, 1, c.GL_FALSE, &mat)`

## Camera / MVP Matrix

For a first-person camera, you need:
- Model matrix: identity for now (world-space blocks)
- View matrix: from camera position + direction
- Projection matrix: perspective projection

Zig doesn't have a math library for this built in. Options:
1. Write your own mat4/vec3 (small, ~100 lines)
2. Use `@cImport` with a C math lib like `cglm`
3. Use a Zig package like `zlm`

Recommendation: write your own. It's educational and avoids dependency
management issues. The math is straightforward — see
`docs/research/linear-algebra.md` when needed.

## Texture Loading

When textures are needed (Phase 1, Item 5):
- Use `stb_image.h` via `@cImport` (vendor it as a single .h file)
- `c.glGenTextures`, `c.glBindTexture`, `c.glTexImage2D`
- Texture atlas for block faces (one texture, UV coordinates per face)
