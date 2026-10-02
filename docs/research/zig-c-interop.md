# Zig C Interop Patterns

Date: 2026-10-01
Status: **VERIFIED** — tested on Zig 0.16.0

## Basic Pattern

```zig
const c = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", "1");
    @cInclude("GL/glcorearb.h");
    @cInclude("GLFW/glfw3.h");
});
```

All C symbols accessed as `c.symbolname`. Constants, functions, types.

## Type Conversions

### C int types

C functions expecting `int`, `unsigned int`, etc. Zig passes these automatically
for literals and small integers. For computed values, use `@intCast`:

```zig
// This works — literal fits
c.glViewport(0, 0, 1280, 720);

// For variables, cast if needed
const width: u32 = 1280;
c.glViewport(0, 0, @intCast(width), @intCast(height));
```

### Pointers

```zig
// Zig pointer to C pointer — usually automatic
var value: c.GLint = 0;
c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &value);  // &value becomes c pointer

// Array to C pointer — use &array for pointer to first element
var info_log: [512]u8 = undefined;
c.glGetShaderInfoLog(shader, 512, null, &info_log);

// Zig slice to C pointer — use .ptr
const data: []const f32 = &vertices;
_ = data.ptr;  // this is [*c]const f32

// Null pointer for offset (e.g., glVertexAttribPointer)
@ptrFromInt(0)     // use this, not null
@ptrFromInt(12)    // byte offset of 12
```

### Float casts

```zig
// C double to Zig f32
const glfwTime: f64 = c.glfwGetTime();  // returns double
const delta: f32 = @floatCast(glfwTime);

// Zig f32 to C float — usually automatic for function args
c.glClearColor(0.5, 0.8, 0.9, 1.0);  // comptime_float auto-converts
```

### Strings

```zig
// Zig string literal as C string — works directly
c.glfwCreateWindow(800, 600, "title", null, null);

// C string to Zig string (for printing)
const version = c.glGetString(c.GL_VERSION);
if (version != null) {
    std.debug.print("OpenGL {s}\n", .{version});
}

// Multiline GLSL source
const shader_src: [*c]const u8 =
    \\#version 330 core
    \\void main() { }
;
```

### Size calculations

```zig
// @sizeOf for buffer sizes — works directly with glBufferData
const vertices = [_]f32{ 1, 2, 3, 4, 5, 6 };
c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, c.GL_STATIC_DRAW);

// Stride calculations
const stride = 6 * @sizeOf(f32);  // 6 floats per vertex
c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, stride, @ptrFromInt(0));
```

## Common Gotchas

1. **`null` vs `@ptrFromInt(0)`**: For GL offset parameters (like in
   `glVertexAttribPointer`), use `@ptrFromInt(0)`, not `null`. They're
   semantically different to the type system.

2. **GLEW doesn't work on Wayland**: Use `GL_GLEXT_PROTOTYPES` with
   `glcorearb.h` instead. GLEW tries to use GLX which requires X11.

3. **Library names vs pkg-config names**: In `build.zig`, use pkg-config
   names (`glfw3`, `gl`). For direct `zig build-exe`, use library names
   (`-lglfw -lGL -lc`).

4. **Optional C pointers**: Many C functions return nullable pointers.
   Zig models these as optionals — use `orelse` for error handling:
   ```zig
   const window = c.glfwCreateWindow(...) orelse return error.Failed;
   ```

5. **`@ptrCast` for matrix data**: When passing a `[4][4]f32` to
   `glUniformMatrix4fv`, cast with `@ptrCast(&data)` to get `[*c]const f32`.

## build.zig Linking

```zig
const exe_mod = b.createModule(.{
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
    .link_libc = true,  // REQUIRED for any C interop
});

exe_mod.linkSystemLibrary("glfw3", .{});  // pkg-config name
exe_mod.linkSystemLibrary("gl", .{});     // pkg-config name
```

`link_libc = true` is mandatory. Without it, `@cImport` fails to find headers.
