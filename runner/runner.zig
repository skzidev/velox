//! # On-Hardware Test Runner
//!
//! Iterates over Zig test functions and prints PASS/FAIL over serial.
//! Built as a freestanding VEX V5 executable; it depends on kernel serial.

const builtin = @import("builtin");
const std = @import("std");
const serial = @import("serial");

pub fn main() void {
    if (!builtin.is_test) {
        serial.write("this runner MUST be built in test mode\n") catch {};
        return;
    }

    const test_functions = builtin.test_functions;
    var pass: u32 = 0;
    var fail: u32 = 0;

    for (test_functions) |t| {
        serial.write("\"") catch {};
        serial.write(t.name) catch {};
        serial.write("\"...") catch {};
        t.func() catch {
            serial.write("\x1b[31mFAIL\x1b[0m\n") catch {};
            fail += 1;
            continue;
        };
        serial.write("\x1b[32mPASS\x1b[0m\n") catch {};
        pass += 1;
    }

    var buf: [128]u8 = undefined;
    const summary = std.fmt.bufPrint(
        &buf,
        "ran {d} tests ({d} passed, {d} failed)\n",
        .{ test_functions.len, pass, fail },
    ) catch "testing complete\n";
    serial.write(summary) catch {};
    serial.flush();
}
