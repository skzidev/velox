//! # SDK tests
//!
//! Comprehensive tests for the Velox SDK, run on the actual V5 hardware
//! via the test runner. The suite covers:
//!
//! * The hardware-free unit conversion helpers ([`Convert`]).
//! * The `Units` and `Errors` namespaces.
//! * Device initialization validation (invalid port / expander errors).
//! * The V5Io `std.Io` implementation (console files, clocks, random,
//!   futures, futexes, cancellation, file error paths).
//!
//! Tests exercise real hardware behavior where possible (concurrency,
//! sleep) and pure logic elsewhere (everything that fails before touching
//! the VEXos jumptable).

const std = @import("std");
const sdk = @import("velox_sdk");
const assert = @import("../testing.zig").assert;

// ---------------------------------------------------------------------------
// Convert helpers (pure, host-testable)
// ---------------------------------------------------------------------------

test "convert_temp_to_unit" {
    // Celsius is the identity.
    try assert(sdk.Convert.tempToUnit(21.5, .celsius) == 21.5);
    // Freezing / boiling points of water and the classic -40 crossover.
    try assert(std.math.approxEqAbs(f64, try_unit(.fahrenheit, 0), 32, 1e-9));
    try assert(std.math.approxEqAbs(f64, try_unit(.fahrenheit, 100), 212, 1e-9));
    try assert(std.math.approxEqAbs(f64, try_unit(.fahrenheit, -40), -40, 1e-9));
    // Body temperature.
    try assert(std.math.approxEqAbs(f64, try_unit(.fahrenheit, 37), 98.6, 1e-9));
}

test "convert_distance_from_millimeters" {
    const C = sdk.Convert;
    // Native millimeters are passed through.
    try assert(C.distanceFromMillimeters(42, .millimeter) == 42);
    // Metric.
    try assert(std.math.approxEqAbs(f32, C.distanceFromMillimeters(10, .centimeter), 1, 1e-6));
    try assert(std.math.approxEqAbs(f32, C.distanceFromMillimeters(254, .centimeter), 25.4, 1e-6));
    // Imperial.
    try assert(std.math.approxEqAbs(f32, C.distanceFromMillimeters(25.4, .inch), 1, 1e-6));
    try assert(std.math.approxEqAbs(f32, C.distanceFromMillimeters(254, .inch), 10, 1e-6));
    try assert(std.math.approxEqAbs(f32, C.distanceFromMillimeters(304.8, .foot), 1, 1e-6));
    try assert(std.math.approxEqAbs(f32, C.distanceFromMillimeters(3048, .foot), 10, 1e-6));
    // Zero stays zero in every unit.
    try assert(C.distanceFromMillimeters(0, .millimeter) == 0);
    try assert(C.distanceFromMillimeters(0, .centimeter) == 0);
    try assert(C.distanceFromMillimeters(0, .inch) == 0);
    try assert(C.distanceFromMillimeters(0, .foot) == 0);
}

test "convert_angle_from_degrees" {
    const C = sdk.Convert;
    // Degrees are the identity.
    try assert(C.angleFromDegrees(270, .degree) == 270);
    // Radians: 180° -> π, 360° -> 2π.
    try assert(std.math.approxEqAbs(f64, C.angleFromDegrees(180, .radian), std.math.pi, 1e-9));
    try assert(std.math.approxEqAbs(f64, C.angleFromDegrees(360, .radian), 2 * std.math.pi, 1e-9));
    try assert(std.math.approxEqAbs(f64, C.angleFromDegrees(90, .radian), 0.5 * std.math.pi, 1e-9));
    // Turns: 360° -> 1 turn.
    try assert(std.math.approxEqAbs(f64, C.angleFromDegrees(360, .turn), 1, 1e-9));
    try assert(std.math.approxEqAbs(f64, C.angleFromDegrees(180, .turn), 0.5, 1e-9));
    try assert(std.math.approxEqAbs(f64, C.angleFromDegrees(90, .turn), 0.25, 1e-9));
    try assert(std.math.approxEqAbs(f64, C.angleFromDegrees(720, .turn), 2, 1e-9));
}

test "convert_position_to_degrees" {
    const C = sdk.Convert;
    // Degrees are the identity.
    try assert(C.positionToDegrees(-45, .degree) == -45);
    // Radians to degrees.
    try assert(std.math.approxEqAbs(f64, C.positionToDegrees(std.math.pi, .radian), 180, 1e-9));
    try assert(std.math.approxEqAbs(f64, C.positionToDegrees(2 * std.math.pi, .radian), 360, 1e-9));
    // Turns to degrees.
    try assert(std.math.approxEqAbs(f64, C.positionToDegrees(1, .turn), 360, 1e-9));
    try assert(std.math.approxEqAbs(f64, C.positionToDegrees(0.5, .turn), 180, 1e-9));
    try assert(std.math.approxEqAbs(f64, C.positionToDegrees(-0.25, .turn), -90, 1e-9));
    try assert(std.math.approxEqAbs(f64, C.positionToDegrees(2, .turn), 720, 1e-9));
}

test "convert_angle_roundtrip" {
    const C = sdk.Convert;
    const degrees = [4]f64{ 0, 72.5, 180, 359.9 };
    for (degrees) |delta| {
        // degrees -> radian -> degrees
        const via_rad = C.positionToDegrees(C.angleFromDegrees(delta, .radian), .radian);
        try assert(std.math.approxEqAbs(f64, via_rad, delta, 1e-9));
        // degrees -> turn -> degrees
        const via_turn = C.positionToDegrees(C.angleFromDegrees(delta, .turn), .turn);
        try assert(std.math.approxEqAbs(f64, via_turn, delta, 1e-9));
    }
}

test "convert_motor_speed_to_mvolts" {
    const C = sdk.Convert;
    // RPM is not a voltage.
    try assert(C.motorSpeedToMvolts(200, .rpm) == null);
    // Millivolts pass through.
    try assert((C.motorSpeedToMvolts(12000, .mvolts)).? == 12000);
    try assert((C.motorSpeedToMvolts(-12000, .mvolts)).? == -12000);
    try assert((C.motorSpeedToMvolts(0, .mvolts)).? == 0);
    // Volts scale by 1000.
    try assert((C.motorSpeedToMvolts(6, .volts)).? == 6000);
    try assert((C.motorSpeedToMvolts(-6, .volts)).? == -6000);
    try assert((C.motorSpeedToMvolts(12, .volts)).? == 12000);
    // Percent approximates millivolts as (speed * 127) / 100.
    try assert((C.motorSpeedToMvolts(100, .percent)).? == 127);
    try assert((C.motorSpeedToMvolts(-100, .percent)).? == -127);
    try assert((C.motorSpeedToMvolts(0, .percent)).? == 0);
    try assert((C.motorSpeedToMvolts(50, .percent)).? == 63);
    try assert((C.motorSpeedToMvolts(-50, .percent)).? == -63);
    try assert((C.motorSpeedToMvolts(45, .percent)).? == 57);
}

// ---------------------------------------------------------------------------
// Units
// ---------------------------------------------------------------------------

test "units_enum_field_counts" {
    try assert(std.meta.fields(sdk.Units.MotorUnit).len == 4);
    try assert(std.meta.fields(sdk.Units.TempUnit).len == 2);
    try assert(std.meta.fields(sdk.Units.LengthUnit).len == 4);
    try assert(std.meta.fields(sdk.Units.RotationalUnit).len == 3);
}

test "units_motor_unit_tags" {
    const U = sdk.Units.MotorUnit;
    // Every variant the SDK documents must exist.
    try assert(@TypeOf(U.rpm) == U);
    try assert(@TypeOf(U.mvolts) == U);
    try assert(@TypeOf(U.volts) == U);
    try assert(@TypeOf(U.percent) == U);
    try assert(@intFromEnum(U.rpm) != @intFromEnum(U.percent));
}

test "units_temp_unit_tags" {
    const U = sdk.Units.TempUnit;
    try assert(@TypeOf(U.celsius) == U);
    try assert(@TypeOf(U.fahrenheit) == U);
}

test "units_length_unit_tags" {
    const U = sdk.Units.LengthUnit;
    try assert(@TypeOf(U.millimeter) == U);
    try assert(@TypeOf(U.centimeter) == U);
    try assert(@TypeOf(U.inch) == U);
    try assert(@TypeOf(U.foot) == U);
}

test "units_rotational_unit_tags" {
    const U = sdk.Units.RotationalUnit;
    try assert(@TypeOf(U.degree) == U);
    try assert(@TypeOf(U.radian) == U);
    try assert(@TypeOf(U.turn) == U);
}

test "motor_enum_values" {
    try assert(@intFromEnum(sdk.Motor.MotorCartridge.red) == 0);
    try assert(@intFromEnum(sdk.Motor.MotorCartridge.green) == 1);
    try assert(@intFromEnum(sdk.Motor.MotorCartridge.blue) == 2);

    try assert(@intFromEnum(sdk.Motor.MotorKind.full) == 0);
    try assert(@intFromEnum(sdk.Motor.MotorKind.half) == 1);

    try assert(@intFromEnum(sdk.Motor.BrakeMode.coast) == 0);
    try assert(@intFromEnum(sdk.Motor.BrakeMode.brake) == 1);
    try assert(@intFromEnum(sdk.Motor.BrakeMode.hold) == 2);

    try assert(@intFromEnum(sdk.Motor.Direction.forward) == 0);
    try assert(@intFromEnum(sdk.Motor.Direction.reverse) == 1);
}

test "adi_and_bumper_enum_values" {
    try assert(@intFromEnum(sdk.ADI.ADIKind.analogIn) == 0);
    try assert(@intFromEnum(sdk.ADI.ADIKind.analogOut) == 1);
    try assert(@intFromEnum(sdk.ADI.ADIKind.digitalIn) == 2);
    try assert(@intFromEnum(sdk.ADI.ADIKind.digitalOut) == 3);
    try assert(@intFromEnum(sdk.ADI.ADIKind.unknown) == 255);

    try assert(@intFromEnum(sdk.Bumper.BumperState.pressed) == 0);
    try assert(@intFromEnum(sdk.Bumper.BumperState.released) == 1);
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

test "errors_port_is_valid_boundaries" {
    const E = sdk.Errors;
    try assert(!E.portIsValid(0));
    try assert(E.portIsValid(1));
    try assert(E.portIsValid(8));
    try assert(E.portIsValid(20));
    try assert(!E.portIsValid(21));
    try assert(!E.portIsValid(22));
    try assert(!E.portIsValid(std.math.maxInt(u32)));
}

test "errors_device_init_error_defined" {
    // Referencing the field forces the error set to be analyzed.
    const err: sdk.Errors.DeviceInitError = sdk.Errors.DeviceInitError.InvalidPortError;
    if (err == error.InvalidPortError) {
        return;
    }
    return error.InvalidPortError;
}

// ---------------------------------------------------------------------------
// Device initialization validation (error paths only — no hardware)
// ---------------------------------------------------------------------------

test "motor_init_rejects_invalid_ports" {
    // 0 is not a smart port.
    if (sdk.Motor.init(0, .green, .forward, .coast)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.InvalidPortError);
    // Above 20 is out of range.
    if (sdk.Motor.init(21, .green, .forward, .coast)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.InvalidPortError);
    if (sdk.Motor.init(22, .green, .forward, .coast)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.InvalidPortError);
}

test "distance_init_rejects_invalid_ports" {
    if (sdk.Distance.init(0)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
    if (sdk.Distance.init(21)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
}

test "rotation_init_rejects_invalid_ports" {
    if (sdk.Rotation.init(0)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
    if (sdk.Rotation.init(21)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
}

test "inertial_init_rejects_invalid_ports" {
    if (sdk.Inertial.init(0)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
    if (sdk.Inertial.init(21)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
}

test "optical_init_rejects_invalid_ports" {
    if (sdk.Optical.init(0)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
    if (sdk.Optical.init(21)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
}

test "adi_init_rejects_invalid_expander" {
    if (sdk.ADI.init(1, .digitalIn, 21)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
    if (sdk.ADI.init(1, .digitalIn, 22)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
}

test "bumper_init_rejects_invalid_expander" {
    if (sdk.Bumper.init(1, 21)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
}

test "pneumatic_init_rejects_invalid_expander" {
    if (sdk.Pneumatic.init(1, 21)) |_| return error.Rejected else |err| try assert(err == error.InvalidPortError);
}

// ---------------------------------------------------------------------------
// Display
// ---------------------------------------------------------------------------

test "display_print_on_line_rejects_negative_lines" {
    const line: i32 = -1;
    if (sdk.Display.printOnLine(std.heap.page_allocator, "x", line)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.InvalidLineError);
}

// ---------------------------------------------------------------------------
// V5Io implementation
// ---------------------------------------------------------------------------

test "io_init_returns_wired_interface" {
    var v5io = sdk.V5Io.init();
    const stdio = v5io.io();
    // The io interface must reference the instance that created it.
    try assert(stdio.userdata == @as(?*anyopaque, @ptrCast(&v5io)));
    // The key vtable slots must be provided (they are, since the instance
    // type is fully constructed at compile time).
    _ = stdio.vtable.now;
    _ = stdio.vtable.sleep;
    _ = stdio.vtable.concurrent;
    _ = stdio.vtable.checkCancel;
}

test "io_console_file_descriptors" {
    const stdout = sdk.V5Io.File.stdout();
    const stderr = sdk.V5Io.File.stderr();
    const stdin = sdk.V5Io.File.stdin();
    // Console streams have blocking semantics (SD files are non-blocking).
    try assert(!stdout.flags.nonblocking);
    try assert(!stderr.flags.nonblocking);
    try assert(!stdin.flags.nonblocking);
}

test "io_file_open_rejects_overlong_paths" {
    var v5io = sdk.V5Io.init();
    // Exactly the buffer size fails.
    var path_256: [256]u8 = [_]u8{'a'} ** 256;
    if (sdk.V5Io.File.open(&v5io, &path_256, .{ .mode = .read_only })) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.NameTooLong);
    // Longer paths fail too.
    var path_300: [300]u8 = [_]u8{'b'} ** 300;
    if (sdk.V5Io.File.open(&v5io, &path_300, .{ .mode = .read_only })) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.NameTooLong);
}

test "io_file_close_without_open_file_is_noop" {
    var v5io = sdk.V5Io.init();
    sdk.V5Io.File.close(&v5io);
}

test "io_console_file_stat_is_streaming" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    const stdout = sdk.V5Io.File.stdout();
    if (std.Io.File.stat(stdout, io)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.Streaming);
}

test "io_console_file_length_is_streaming" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    const stdout = sdk.V5Io.File.stdout();
    if (std.Io.File.length(stdout, io)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.Streaming);
}

test "io_console_file_not_resizable" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    const stdout = sdk.V5Io.File.stdout();
    if (std.Io.File.setLength(stdout, io, 0)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.NonResizable);
}

test "io_console_file_unseekable" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    const stdout = sdk.V5Io.File.stdout();

    var bufs: [1][]u8 = undefined;
    if (std.Io.File.readPositional(stdout, io, &bufs, 0)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.Unseekable);

    if (io.vtable.fileSeekBy(io.userdata, stdout, 1)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.Unseekable);

    if (io.vtable.fileSeekTo(io.userdata, stdout, 5)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.Unseekable);
}

test "io_unopened_sd_file_error_paths" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    // Mark a console fd as non-blocking to model an SD file with no open
    // handle behind it. These checks must fail before touching hardware.
    var sd_like = sdk.V5Io.File.stdout();
    sd_like.flags.nonblocking = true;

    if (std.Io.File.stat(sd_like, io)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.AccessDenied);

    if (std.Io.File.length(sd_like, io)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.AccessDenied);

    if (std.Io.File.sync(sd_like, io)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.AccessDenied);

    if (io.vtable.fileSeekBy(io.userdata, sd_like, 1)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.Unseekable);

    if (io.vtable.fileSeekTo(io.userdata, sd_like, 1)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.Unseekable);

    var bufs: [1][]u8 = undefined;
    if (std.Io.File.readPositional(sd_like, io, &bufs, 0)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.NotOpenForReading);
}

test "io_console_filedescriptor_capabilities" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    const stdout = sdk.V5Io.File.stdout();
    var sd_like = sdk.V5Io.File.stdout();
    sd_like.flags.nonblocking = true;

    // Console streams are terminals and support ANSI escapes; SD files are not.
    try assert((try std.Io.File.isTty(stdout, io)) == true);
    try assert((try std.Io.File.isTty(sd_like, io)) == false);
    try std.Io.File.enableAnsiEscapeCodes(stdout, io);
    if (std.Io.File.enableAnsiEscapeCodes(sd_like, io)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.NotTerminalDevice);
    try assert((try std.Io.File.supportsAnsiEscapeCodes(stdout, io)) == true);
    try assert((try std.Io.File.supportsAnsiEscapeCodes(sd_like, io)) == false);
}

test "io_console_sync_is_noop" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    // Syncing a console stream does nothing (no error).
    try std.Io.File.sync(sdk.V5Io.File.stdout(), io);
}

test "io_check_cancel_succeeds_when_idle" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    // No outstanding cancellation request on the main task.
    try io.checkCancel();
}

test "io_random_produces_varying_bytes" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    var a: [32]u8 = undefined;
    var b: [32]u8 = undefined;
    io.random(&a);
    io.random(&b);
    try assert(!std.mem.allEqual(u8, &a, 0));
    try assert(!std.mem.eql(u8, &a, &b));
}

test "io_random_secure_unavailable" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    var buf: [16]u8 = undefined;
    if (io.randomSecure(&buf)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.EntropyUnavailable);
}

test "io_unsupported_clocks_report_epoch" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    try assert(std.Io.Clock.now(.real, io).nanoseconds == 0);
    try assert(std.Io.Clock.now(.cpu_process, io).nanoseconds == 0);
    try assert(std.Io.Clock.now(.cpu_thread, io).nanoseconds == 0);
}

test "io_real_clock_resolution_unavailable" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    if (std.Io.Clock.resolution(.real, io)) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.ClockUnavailable);
}

test "io_awake_clock_resolution_is_microseconds" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    const res = try std.Io.Clock.resolution(.awake, io);
    try assert(res.nanoseconds == std.time.ns_per_us);
}

test "io_boot_clock_monotonic" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    const t0 = std.Io.Clock.now(.awake, io).nanoseconds;
    try io.sleep(.fromMicroseconds(100), .awake);
    const t1 = std.Io.Clock.now(.awake, io).nanoseconds;
    try assert(t1 >= t0);
}

test "io_operate_device_io_control_returns_error" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    const stdout = sdk.V5Io.File.stdout();
    const operation = std.Io.Operation{ .device_io_control = .{
        .file = stdout,
        .code = 0,
        .arg = null,
    } };
    const result = try io.operate(operation);
    try assert(result.device_io_control == -1);
}

test "io_futex_wait_returns_when_value_differs" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    var value: u32 = 0;
    // The value does not match `expected`, so the wait returns immediately.
    try io.futexWait(u32, &value, 1);
    io.futexWaitUncancelable(u32, &value, 1);
    io.futexWake(u32, &value, 1);
}

test "io_futex_wait_timeout_and_deadline" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    var value: u32 = 1;
    // A matching value blocks, but a zero deadline unblocks immediately.
    try io.futexWaitTimeout(u32, &value, 1, .{ .deadline = .{
        .raw = std.Io.Timestamp.zero,
        .clock = .awake,
    } });
}

test "io_group_concurrent_runs_eagerly" {
    var v5io = sdk.V5Io.init();
    const io = v5io.io();
    var ran = false;
    const Worker = struct {
        fn run(ptr: *bool) std.Io.Cancelable!void {
            ptr.* = true;
            return;
        }
    };
    var group: std.Io.Group = .init;
    try std.Io.Group.concurrent(&group, io, Worker.run, .{&ran});
    try std.Io.Group.await(&group, io);
    try assert(ran);
}

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

test "concurrency_unavailable_for_oversized_context" {
    var threaded = sdk.V5Io.init();
    var io = threaded.io();
    const Worker = struct {
        fn consume(_: [80]u8) void {}
    };
    const big: [80]u8 = undefined;
    // 80 bytes exceeds the fixed 64-byte task context pool.
    if (io.concurrent(Worker.consume, .{big})) |_| {
        return error.Rejected;
    } else |err| try assert(err == error.ConcurrencyUnavailable);
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

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

fn try_unit(unit: sdk.Units.TempUnit, celsius: f64) f64 {
    return sdk.Convert.tempToUnit(celsius, unit);
}
