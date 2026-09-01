//! # On-Hardware Test Runner
//!
//! This is the user program for the test executable. It iterates over
//! all Zig test functions (available via `builtin.test_functions`),
//! runs each one, and prints `PASS` or `FAIL` to the serial console.
//!
//! The test runner is built using `runner/shim.zig` as the test runner
//! shim, which provides a minimal `page_allocator` and empty `panic`
//! handler for on-hardware execution.

const builtin = @import("builtin");
const std = @import("std");
const velox = @import("velox");

pub const std_options = std.Options{
    .page_size_max = 4096,
    .page_size_min = 4096,
};

/// Entry point for the test runner. Must be compiled in test mode.
///
/// Iterates over all registered test functions, executes each one,
/// and writes the result (`PASS` or `FAIL`) to serial. Prints a
/// summary line when all tests complete.
pub fn main(init: velox.Init) anyerror!void {
    const stdout = velox.V5Io.File.stdout();
    defer stdout.close(init.io);
    const stderr = velox.V5Io.File.stderr();
    defer stderr.close(init.io);
    if (!builtin.is_test or !@hasDecl(builtin, "test_functions")) {
        try stderr.writeStreamingAll(init.io, "this runner MUST be run in a test");
        return;
    }

    const allocator: std.mem.Allocator = @constCast(&init.arena).allocator();

    const testFunctions: []const std.builtin.TestFn = builtin.test_functions;

    var pass: u32 = 0;
    var fail: u32 = 0;

    for (testFunctions) |testFunc| {
        const msg = try std.fmt.allocPrint(
            allocator,
            "\"{s}\"...",
            .{testFunc.name},
        );
        try stdout.writeStreamingAll(
            init.io,
            msg,
        );
        defer allocator.free(msg);
        testFunc.func() catch {
            try stdout.writeStreamingAll(init.io, "FAIL\n");
            fail += 1;
            continue;
        };
        try stdout.writeStreamingAll(init.io, "PASS\n");
        pass += 1;
    }
    try velox.V5Io.File.stdout().writeStreamingAll(init.io, "testing complete\n");
}
