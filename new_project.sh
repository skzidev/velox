#!/bin/sh

# This script creates a new Velox project using sh.
# This will create files in the current directory.

printf '%s\n' '                            /|        '
printf '%s\n' '  ______        ___________/_/        '
printf '%s\n' ' \\    \\      |     //     //        '
printf '%s\n' '   \\    \\    |___//     //          '
printf '%s\n' '     \\    \\    //     //            '
printf '%s\n' '       \\    \\//     //_____         '
printf '%s\n' '         \\         //       |        '
printf '%s\n' '          \\_______//________|        '
printf '%s\n' '                / /                   '
printf '%s\n' '                |/                    '
printf "Copyright (c) 2026 59218C, licensed under MIT.\n"

zig init > /dev/null 2>&1
rm ./src/main.zig
zig fetch --save git+https://github.com/skzidev/velox > /dev/null 2>&1
zig fetch --save git+https://github.com/skzidev/velox-jumptable > /dev/null 2>&1
cat << 'EOF' > build.zig
const std = @import("std");
const velox = @import("velox_core");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});

    const exe: *std.Build.Step.Compile = try velox.addExecutable(
        b,
        b.path("./src/root.zig"),
        optimize,
        b.dependency("velox_core", .{}).path("."),
        &.{},
    );
    b.default_step.dependOn(&exe.step);

    const upload = b.step("upload", "Upload to the V5 brain");
    const cmd = try velox.addUpload(b, exe, "Example", "Example Project", .cool_x, 1);
    upload.dependOn(b.default_step);
    upload.dependOn(&(cmd.step));
}
EOF

cat << 'EOF' > ./src/root.zig
const std = @import("std");
const velox = @import("velox");

pub fn main(init: velox.Init) !void {
    const stdout = velox.V5Io.File.stdout();
    try stdout.writeStreamingAll(init.io, "Hello, World!");

    // Write your code here.

    while (true) {
        try init.io.sleep(
            .fromMilliseconds(2),
            .awake,
        );
    }
}

EOF

cat << 'EOF' > .gitignore
zig-out/
zig-pkg/
.zig-cache/
EOF

echo "\nWelcome to Velox. Edit ./src/root.zig to get started."
