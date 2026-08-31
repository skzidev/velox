const builtin = @import("builtin");
const std = @import("std");

pub const TestErrors = error{
    assertionFailed,
};

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

const umm_sym = @import("./testing/umm.zig");

comptime {
    std.testing.refAllDecls(umm_sym);
}
