//! # Testing utilities
//!
//! Provides a lightweight `assert` function for use in on-hardware
//! tests. When built in test mode, this module also pulls in the
//! allocator tests (`umm.zig`) and SDK concurrency tests (`sdk.zig`).

const builtin = @import("builtin");
const std = @import("std");

/// Error set for test assertions.
pub const TestErrors = error{
    /// The assertion condition was false.
    assertionFailed,
};

/// Asserts that `cond` is true. Returns `error.assertionFailed` if
/// the condition is false.
///
/// ## Example
///
/// ```zig
/// try assert(1 + 1 == 2);
/// ```
pub fn assert(cond: bool) TestErrors!void {
    if (!cond) return TestErrors.assertionFailed;
}

test "true_condition" {
    if (assert(1 == 1) == TestErrors.assertionFailed) {
        return TestErrors.assertionFailed;
    }
}

test "false_condition" {
    if (assert(1 == 0) != TestErrors.assertionFailed) {
        return TestErrors.assertionFailed;
    }
}

// don't include ./testing if this isn't a test build (it may increase binary sizes).
comptime {
    if (builtin.is_test) {
        std.testing.refAllDecls(@import("./testing/umm.zig"));
        _ = @import("./testing/sdk.zig");
        _ = @import("./testing/kernel.zig");
    }
}
