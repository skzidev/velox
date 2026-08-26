const builtin = @import("builtin");
const std = @import("std");
const velox = @import("velox_sdk");

pub const std_options = std.Options{
    .page_size_max = 4096,
    .page_size_min = 4096,
};

pub const ports = .{};

pub fn main(init: velox.Init(ports)) anyerror!void {
    const stdout = velox.V5Io.File.stdout();
    const stderr = velox.V5Io.File.stderr();
    if (!builtin.is_test or !@hasDecl(builtin, "test_functions")) {
        try stderr.writeStreamingAll(init.io, "This runner MUST be run in a test");
        return;
    }

    try stdout.writeStreamingAll(init.io, "Hello, World!");

    const allocator = @constCast(&init.arena).allocator();

    const testFunctions: []const std.builtin.TestFn = builtin.test_functions;

    var pass: u32 = 0;
    var fail: u32 = 0;

    for (testFunctions, 1..) |testFunc, i| {
        try stdout.writeStreamingAll(
            init.io,
            try std.fmt.allocPrint(
                allocator,
                "test #{d} \"{s}\"...",
                .{ i, testFunc.name },
            ),
        );
        testFunc.func() catch {
            try stdout.writeStreamingAll(init.io, "FAIL\n");
            fail += 1;
            continue;
        };
        try stdout.writeStreamingAll(init.io, "PASS\n");
        pass += 1;
    }

    try stdout.writeStreamingAll(
        init.io,
        try std.fmt.allocPrint(
            allocator,
            "{d} pass, {d} fail",
            .{ pass, fail },
        ),
    );
}
