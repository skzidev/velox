const sdk = @import("velox_sdk");
const assert = @import("../testing.zig").assert;

var didRunConcurrently = false;

fn runConcurrentThread() void {
    didRunConcurrently = true;
}

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

fn runAsync() void {
    didRunAsync = true;
}

test "run_asynchronously" {
    var threaded = sdk.V5Io.init();
    var io = threaded.io();
    var future = io.async(runAsync, .{});
    _ = future.await(io);
    try assert(didRunAsync);
}

test "sleep" {
    var threaded = sdk.V5Io.init();
    var io = threaded.io();
    const start = io.vtable.now(null, .awake).toMilliseconds();
    try io.sleep(.fromMilliseconds(4), .awake);
    const end = io.vtable.now(null, .awake).toMilliseconds();
    const diff = end - start;
    try assert(diff >= 4 and diff <= 6);
}
