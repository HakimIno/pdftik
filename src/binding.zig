const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "pdftik",
        .root_source_file = .{ .cwd_relative = "src/binding.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Node.js headers
    lib.addIncludePath(.{ .cwd_relative = "node_modules/node-api-headers/include" });

    // Library paths
    lib.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    lib.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/node/lib" });

    lib.linkSystemLibrary("wkhtmltox");
    lib.linkLibC();

    b.installArtifact(lib);
}
