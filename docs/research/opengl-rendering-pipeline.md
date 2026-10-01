# OpenGL 3.3 Rendering Pipeline in Zig

Date: 2026-10-01
Status: **VERIFIED** — all code examples compile and run on Zig 0.16.0

## Library Linking Gotcha

The system has `libglfw.so` (not `libglfw3.so`) and `libGL.so` (capital GL).
But `build.zig` uses pkg-config names, which are different:

```zig
// In build.zig — these are pkg-config names, not library filenames
exe_mod.linkSystemLibrary("glfw3", .{});  // resolves to libglfw.so via pkg-config
exe_mod.linkSystemLibrary("gl", .{});     // resolves to libGL.so via pkg-config
```

If you use `zig build-exe` directly (not through build.zig), the flags are:
```bash
zig build-exe file.zig -lglfw -lGL -lc
```

**Stick to build.zig.** It handles this correctly.

## Shader Setup (Verified Working)

```zig
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});

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

## GLSL Shader Sources as Zig Multiline Strings (Verified Working)

Use Zig's multiline string syntax (`\\` per line). These compile to valid
`[*c]const u8` that OpenGL accepts:

```zig
const vert_shader_src: [*c]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aColor;
    \\out vec3 vertexColor;
    \\void main() {
    \\    gl_Position = vec4(aPos, 1.0);
    \\    vertexColor = aColor;
    \\}
;

const frag_shader_src: [*c]const u8 =
    \\#version 330 core
    \\in vec3 vertexColor;
    \\out vec4 FragColor;
    \\void main() {
    \\    FragColor = vec4(vertexColor, 1.0);
    \\}
;
```

When MVP matrix is added later, change the vertex shader to:
```glsl
uniform mat4 mvp;
void main() {
    gl_Position = mvp * vec4(aPos, 1.0);
    vertexColor = aColor;
}
```

## Vertex Data Setup (Verified Working)

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
c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

// Position attribute (location = 0)
c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32), @ptrFromInt(0));
c.glEnableVertexAttribArray(0);

// Color attribute (location = 1)
c.glVertexAttribPointer(1, 3, c.GL_FLOAT, c.GL_FALSE, 6 * @sizeOf(f32), @ptrFromInt(3 * @sizeOf(f32)));
c.glEnableVertexAttribArray(1);
```

### Zig C Interop Notes (from testing)

- `@sizeOf(@TypeOf(vertices))` works directly — no cast needed for `glBufferData`
- `@ptrFromInt(0)` for null offset — `null` doesn't work here
- `@ptrFromInt(3 * @sizeOf(f32))` for byte offset to second attribute
- Zig multiline strings with `\\` produce valid `[*c]const u8` for GLSL sources
- `[_]f32{...}` array literals work directly — no heap allocation needed

## Draw Call (Verified Working)

```zig
c.glClear(c.GL_COLOR_BUFFER_BIT | c.GL_DEPTH_BUFFER_BIT);
c.glUseProgram(shader_program);
c.glBindVertexArray(vao);
c.glDrawArrays(c.GL_TRIANGLES, 0, 3);
c.glfwSwapBuffers(window);
```

## Uniform Upload (For Camera MVP — Not Yet Verified)

```zig
const mvp_loc = c.glGetUniformLocation(shader_program, "mvp");
// mat4 is [4][4]f32 — pass pointer to first element
c.glUniformMatrix4fv(mvp_loc, 1, c.GL_FALSE, @ptrCast(&mvp));
```

This needs verification when the camera is implemented. The `@ptrCast`
for the matrix data is the likely gotcha — test it.

## Indexed Drawing (For Chunk Meshes)

When rendering chunks, use indexed drawing to avoid duplicate vertices:

```zig
var ebo: c.GLuint = 0;
c.glGenBuffers(1, &ebo);
c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, c.GL_STATIC_DRAW);

// Draw with indices instead of glDrawArrays
c.glDrawElements(c.GL_TRIANGLES, num_indices, c.GL_UNSIGNED_INT, @ptrFromInt(0));
```

## Cleanup Pattern

```zig
defer c.glDeleteVertexArrays(1, &vao);
defer c.glDeleteBuffers(1, &vbo);
defer c.glDeleteProgram(shader_program);
```

Use Zig `defer` for GL resource cleanup. Stack them right after creation.
