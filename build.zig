const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    exe_mod.linkSystemLibrary("glfw3", .{});
    exe_mod.linkSystemLibrary("gl", .{});
    exe_mod.linkSystemLibrary("asound", .{});

    const exe = b.addExecutable(.{
        .name = "zigcraft",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run zigcraft");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run all tests");

    const exe_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    test_step.dependOn(&run_exe_tests.step);

    // Modules that can be tested in isolation (root at src/ or self-contained)
    const test_files = [_][]const u8{
        "src/world/block.zig",
        "src/world/chunk.zig",
        "src/world/chunk_mesh.zig",
        "src/world/terrain.zig",
        "src/world/persistence.zig",
        "src/chunk_manager.zig",
        "src/frustum.zig",
        "src/pick.zig",
        "src/renderer/shader.zig",
        "src/renderer/texture.zig",
        "src/renderer/ui.zig",
        "src/renderer/mesh.zig",
        "src/camera.zig",
        "src/player.zig",
        "src/sky.zig",
        "src/math.zig",
        "src/audio/synth.zig",
        "src/audio/audio.zig",
        "src/entity.zig",
        "src/net.zig",
    };

    for (test_files) |test_file| {
        const test_mod = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .link_libc = true,
        });
        test_mod.linkSystemLibrary("gl", .{});
        test_mod.linkSystemLibrary("glfw3", .{});
        test_mod.linkSystemLibrary("asound", .{});
        const test_exe = b.addTest(.{
            .root_module = test_mod,
        });
        const run_test = b.addRunArtifact(test_exe);
        test_step.dependOn(&run_test.step);
    }
}
