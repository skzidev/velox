//! # SDK concurrency tests
//!
//! Tests for the V5Io `concurrent`, `async`, and `sleep`
//! implementations. These run on the actual V5 hardware via the
//! test runner.

const sdk = @import("velox_sdk");
const assert = @import("../testing.zig").assert;

var didRunConcurrently = false;

/// Target function for the concurrent test — sets a shared flag.
fn runConcurrentThread() void {
    didRunConcurrently = true;
}

// Verifies that `io.concurrent` spawns a task that runs alongside the
// calling task, and that the flag is eventually set.
test "run_concurrently" {
    var threaded = sdk.V5Io.init();
    var io = threaded.io();
    _ = try io.concurrent(runConcurrentThread, .{});
    var iterations: u32 = 0;
    while (!didRunConcurrently) {
        try assert(iterations <= 1000);
        try io.sleep(.fromMilliseconds(2), .awake);
        iterations += 1;
    }
}

var didRunAsync = false;

/// Target function for the async test — sets a shared flag.
fn runAsync() void {
    didRunAsync = true;
}

// Verifies that `io.async` returns a future that can be awaited.
test "run_asynchronously" {
    var threaded = sdk.V5Io.init();
    var io = threaded.io();
    var future = io.async(runAsync, .{});
    _ = future.await(io);
    try assert(didRunAsync);
}

// Verifies that `io.sleep` blocks for approximately the requested
// duration (within a 2 ms tolerance).
test "sleep" {
    var threaded = sdk.V5Io.init();
    var io = threaded.io();
    const start = io.vtable.now(null, .awake).toMilliseconds();
    try io.sleep(.fromMilliseconds(4), .awake);
    const end = io.vtable.now(null, .awake).toMilliseconds();
    const diff = end - start;
    try assert(diff >= 4 and diff <= 6);
}
