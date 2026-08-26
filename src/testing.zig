pub const TestErrors = error{
    assertionFailed,
};

pub fn assert(cond: bool) TestErrors!void {
    if (!cond) return TestErrors.assertionFailed;
}

test "assert true statement" {
    if (assert(1 == 1) == TestErrors.assertionFailed) {
        return TestErrors.assertionFailed;
    }
}

test "assert false statement" {
    if (assert(1 == 0) != TestErrors.assertionFailed) {
        return TestErrors.assertionFailed;
    }
}
