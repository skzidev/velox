//! V5 smart-port motor (§8).
//!
//! Motors are value types that resolve their device handle once at
//! construction. Every command is a no-op on an unclaimed port, and every
//! telemetry value reads zero on an unclaimed port. Write power and
//! velocity are clamped to the canonical bounds (§8.8, §4): ±12000 mV and
//! the gearset's free speed.
//!
//! ## Followers (§18.4 "software fan-out")
//!
//! There is no firmware follower call in the jump table, so follow() is a
//! software push fan-out: when a master motor is commanded, each registered
//! follower is sent the master's command scaled by its ratio with one
//! extra jump-table call. A follower ignores its own `spin*`/`stop` calls
//! entirely. The registry is a fixed static table of value-based entries
//! (device handles, not pointers to Motor instances), so no allocation and
//! no task is involved. follow() re-registers a follower's entry; when the
//! table is full follow() is a documented no-op (the motor stays independent).
//! Re-follow() after changing a follower's gearset to refresh its clamp.

const std = @import("std");

const jmptbl = @import("velox_jumptable");
const types = jmptbl.types;
const ports = @import("../ports.zig");
const units = @import("../units.zig");
const convert = @import("../internal/convert.zig");
const dev = @import("../internal/dev.zig");

/// Number of follower registrations the software fan-out table holds.
const follower_max = 24;

const FollowerEntry = struct {
    master: ?*anyopaque,
    slave: ?*anyopaque,
    slave_gearset: Motor.Gearset,
    ratio: f64,
};

var follower_table: [follower_max]FollowerEntry = undefined;
var follower_count: usize = 0;

fn gearsetMaxRpm(gearset: Motor.Gearset) f64 {
    return gearset.maxRpm();
}

/// The motor's chirality of mounting.
pub const Motor = struct {
    device: ?*anyopaque,
    port: ports.SmartPort,
    /// The device handle of this motor's master, if it is following (§18.4).
    master: ?*anyopaque = null,
    /// Ratio applied to the master's velocity/voltage while following.
    ratio: f64 = 1.0,

    pub const Gearset = enum(u3) {
        /// 36:1 red gearset, 100 rpm free speed.
        red_36_1,
        /// 18:1 green gearset, 200 rpm free speed.
        green_18_1,
        /// 6:1 blue gearset, 600 rpm free speed.
        blue_6_1,
        /// Unknown/forbidden gearset; treated as green for safety.
        _,

        pub fn maxRpm(self: Gearset) f64 {
            return switch (self) {
                .red_36_1 => 100.0,
                .green_18_1 => 200.0,
                .blue_6_1 => 600.0,
                _ => 200.0,
            };
        }

        fn toNative(self: Gearset) types.V5MotorGearset {
            return switch (self) {
                .red_36_1 => .kMotorGearSet_36,
                .green_18_1 => .kMotorGearSet_18,
                .blue_6_1 => .kMotorGearSet_06,
                _ => .kMotorGearSet_18,
            };
        }

        fn fromNative(native: types.V5MotorGearset) Gearset {
            return switch (native) {
                .kMotorGearSet_36 => .red_36_1,
                .kMotorGearSet_18 => .green_18_1,
                .kMotorGearSet_06 => .blue_6_1,
                _ => .green_18_1,
            };
        }
    };

    pub const Direction = enum(u1) {
        forward,
        reverse,
    };

    pub const BrakeMode = enum(u2) {
        coast,
        brake,
        hold,

        fn toNative(self: BrakeMode) types.V5MotorBrakeMode {
            return switch (self) {
                .coast => .kV5MotorBrakeModeCoast,
                .brake => .kV5MotorBrakeModeBrake,
                .hold => .kV5MotorBrakeModeHold,
            };
        }

        fn fromNative(native: types.V5MotorBrakeMode) BrakeMode {
            return switch (native) {
                .kV5MotorBrakeModeCoast => .coast,
                .kV5MotorBrakeModeBrake => .brake,
                .kV5MotorBrakeModeHold => .hold,
                _ => .coast,
            };
        }
    };

    /// Whether the device is a 393-style half motor (no encoder).
    pub const Kind = enum(u1) {
        full,
        half,
    };

    /// Motor health flags, decoded from the raw fault register (§18.6).
    pub const Faults = struct {
        over_current: bool = false,
        over_temperature: bool = false,
        low_battery: bool = false,
        bad_connection: bool = false,
        no_power: bool = false,
    };

    /// Create a motor on `port`, applying default configuration once
    /// (§8.1). The device handle is resolved here; the brake mode,
    /// gearset, reverse flag and encoder units are written to the device
    /// only if the port is claimed.
    pub fn init(port: ports.SmartPort, g: Gearset, dir: Direction, brake_mode: BrakeMode) Motor {
        var self = Motor{ .device = null, .port = port };
        const d = dev.smartDevice(port) orelse return self;
        self.device = d;
        jmptbl.motor.vexDeviceMotorEncoderUnitsSet(d, .kMotorEncoderDegrees);
        jmptbl.motor.vexDeviceMotorGearingSet(d, g.toNative());
        jmptbl.motor.vexDeviceMotorReverseFlagSet(d, @intFromBool(dir == .reverse));
        jmptbl.motor.vexDeviceMotorBrakeModeSet(d, brake_mode.toNative());
        return self;
    }

    /// Make this motor follow `master`. While following, this motor
    /// ignores its own `spin*` and `stop` calls; commands issued to
    /// `master` are pushed to this motor scaled by `ratio`. `ratio` < 1
    /// is a speed reduction (output gearing), > 1 a speed increase.
    pub fn follow(self: *Motor, master: *const Motor, ratio: f64) void {
        const mdev = master.device orelse return;
        const sdev = self.device orelse return;
        self.master = mdev;
        self.ratio = ratio;
        for (follower_table[0..follower_count]) |*e| {
            if (e.slave == sdev) {
                e.master = mdev;
                e.slave_gearset = self.gearset();
                e.ratio = ratio;
                return;
            }
        }
        if (follower_count == follower_max) {
            // Table full: documented no-op. The motor stays independent.
            self.master = null;
            self.ratio = 1.0;
            return;
        }
        follower_table[follower_count] = .{
            .master = mdev,
            .slave = sdev,
            .slave_gearset = self.gearset(),
            .ratio = ratio,
        };
        follower_count += 1;
    }

    /// Stop following any master; remove this motor from the fan-out table.
    pub fn unfollow(self: *Motor) void {
        self.master = null;
        self.ratio = 1.0;
        const sdev = self.device orelse return;
        for (follower_table[0..follower_count], 0..) |*e, i| {
            if (e.slave == sdev) {
                follower_table[i] = follower_table[follower_count - 1];
                follower_count -= 1;
                return;
            }
        }
    }

    /// Command a raw voltage, clamped to ±12000 mV (§8.8).
    pub fn spin(self: *Motor, power: units.Power) void {
        if (self.master != null) return;
        const d = self.device orelse return;
        const mvolts = convert.powerToMvolts(power);
        jmptbl.motor.vexDeviceMotorVoltageSet(d, mvolts);
        fanoutMvolts(self.device, mvolts);
    }

    /// Command a velocity, clamped to the gearset's free speed (§8.9).
    pub fn spinVelocity(self: *Motor, v: units.Velocity) void {
        if (self.master != null) return;
        const d = self.device orelse return;
        const rpm = convert.velocityToRpm(v, self.gearset().maxRpm());
        jmptbl.motor.vexDeviceMotorVelocitySet(d, rpm);
        fanoutRpm(self.device, rpm);
    }

    /// Drive to `position` at `velocity` (absolute move). Followers are
    /// pushed the commanded velocity, not the position target (§8.11).
    pub fn spinTo(self: *Motor, pos: units.Position, vel: units.Velocity) void {
        if (self.master != null) return;
        const d = self.device orelse return;
        const degrees = convert.positionToDegrees(pos);
        const rpm = convert.velocityToRpm(vel, self.gearset().maxRpm());
        // Two jump-table calls: select the "profile" (absolute target) mode
        // so both targets read as a move, then set the target (§8.11).
        jmptbl.motor.vexDeviceMotorModeSet(d, .kMotorControlModePROFILE);
        jmptbl.motor.vexDeviceMotorAbsoluteTargetSet(d, degrees, rpm);
        fanoutRpm(self.device, rpm);
    }

    /// Stop the motor (drive velocity to zero).
    pub fn stop(self: *Motor) void {
        if (self.master != null) return;
        const d = self.device orelse return;
        jmptbl.motor.vexDeviceMotorVelocitySet(d, 0);
        fanoutRpm(self.device, 0);
    }

    /// Set brake mode to coast, then stop (§8.7).
    pub fn coast(self: *Motor) void {
        self.setBrakeMode(.coast);
        self.stop();
    }

    /// Set brake mode to brake, then stop (§8.7).
    pub fn brake(self: *Motor) void {
        self.setBrakeMode(.brake);
        self.stop();
    }

    /// Set brake mode to hold, then stop (§8.7).
    pub fn hold(self: *Motor) void {
        self.setBrakeMode(.hold);
        self.stop();
    }

    /// Replace the motor's current angular position (§8.12).
    pub fn setPosition(self: *Motor, pos: units.Position) void {
        const d = self.device orelse return;
        jmptbl.motor.vexDeviceMotorPositionSet(d, convert.positionToDegrees(pos));
    }

    /// Zero the motor's angular position.
    pub fn resetPosition(self: *Motor) void {
        const d = self.device orelse return;
        jmptbl.motor.vexDeviceMotorPositionReset(d);
    }

    /// Change how the motor behaves when the commanded velocity is zero.
    pub fn setBrakeMode(self: *Motor, mode: BrakeMode) void {
        const d = self.device orelse return;
        jmptbl.motor.vexDeviceMotorBrakeModeSet(d, mode.toNative());
    }

    /// Change the effective gearset. Clamps future velocity targets and
    /// refreshes the follower clamp for this motor.
    pub fn setGearset(self: *Motor, g: Gearset) void {
        const d = self.device orelse return;
        jmptbl.motor.vexDeviceMotorGearingSet(d, g.toNative());
        for (follower_table[0..follower_count]) |*e| {
            if (e.slave == d) e.slave_gearset = g;
        }
    }

    /// Reverse or restore the motor's direction.
    pub fn setDirection(self: *Motor, dir: Direction) void {
        const d = self.device orelse return;
        jmptbl.motor.vexDeviceMotorReverseFlagSet(d, @intFromBool(dir == .reverse));
    }

    /// The motor's current gearset.
    pub fn gearset(self: *const Motor) Gearset {
        const d = self.device orelse return .green_18_1;
        return Gearset.fromNative(jmptbl.motor.vexDeviceMotorGearingGet(d));
    }

    /// The motor's current direction setting.
    pub fn direction(self: *const Motor) Direction {
        const d = self.device orelse return .forward;
        return if (jmptbl.motor.vexDeviceMotorReverseFlagGet(d) != 0) .reverse else .forward;
    }

    /// Whether the motor is a 393-style half motor or a full V5 motor.
    pub fn kind(self: *const Motor) Kind {
        const d = self.device orelse return .half;
        return if (jmptbl.motor.vexDeviceMotorTypeGet(d) == 0) .full else .half;
    }

    /// Current angular position, degrees.
    pub fn position(self: *const Motor) f64 {
        const d = self.device orelse return 0.0;
        return jmptbl.motor.vexDeviceMotorPositionGet(d);
    }

    /// Current rotational velocity, rpm.
    pub fn velocity(self: *const Motor) f64 {
        const d = self.device orelse return 0.0;
        return jmptbl.motor.vexDeviceMotorActualVelocityGet(d);
    }

    /// Current current draw, amps (signed; discharge positive).
    pub fn current(self: *const Motor) f64 {
        const d = self.device orelse return 0.0;
        return @as(f64, @floatFromInt(jmptbl.motor.vexDeviceMotorCurrentGet(d))) / 1000.0;
    }

    /// Voltage delivered to the motor, volts (signed).
    pub fn voltage(self: *const Motor) f64 {
        const d = self.device orelse return 0.0;
        return @as(f64, @floatFromInt(jmptbl.motor.vexDeviceMotorVoltageGet(d))) / 1000.0;
    }

    /// Motor temperature, degrees Celsius.
    pub fn temperature(self: *const Motor) f64 {
        const d = self.device orelse return 0.0;
        return jmptbl.motor.vexDeviceMotorTemperatureGet(d);
    }

    /// Electrical efficiency, percent.
    pub fn efficiency(self: *const Motor) f64 {
        const d = self.device orelse return 0.0;
        return jmptbl.motor.vexDeviceMotorEfficiencyGet(d);
    }

    /// Decode the motor's fault register (§18.6). A fault is present when
    /// its bit is set in the raw register.
    pub fn faults(self: *const Motor) Faults {
        const d = self.device orelse return .{};
        const raw = jmptbl.motor.vexDeviceMotorFaultsGet(d);
        return .{
            .over_current = (raw & 0x4) != 0,
            .over_temperature = (raw & 0x1) != 0,
            .low_battery = (raw & 0x100) != 0,
            .bad_connection = (raw & 0x40) != 0,
            .no_power = (raw & 0x800) != 0,
        };
    }

    /// True while the motor's control loop is not at rest. The raw
    /// "zero velocity flag" is inverted by the OS (the flag goes away
    /// once the motor is moving).
    pub fn isSpinning(self: *const Motor) bool {
        const d = self.device orelse return false;
        return jmptbl.motor.vexDeviceMotorZeroVelocityFlagGet(d) == 0;
    }

    /// True when the motor is within the 5° deadband of its commanded
    /// target (§8.11).
    pub fn isOnTarget(self: *const Motor) bool {
        const d = self.device orelse return false;
        const target = jmptbl.motor.vexDeviceMotorTargetGet(d);
        return @abs(jmptbl.motor.vexDeviceMotorPositionGet(d) - target) <= 5.0;
    }

    /// True when the port is claimed and the OS reports a motor (or
    /// 393-cartridge motor) installed there (§18.1).
    pub fn isConnected(self: *const Motor) bool {
        if (self.device == null) return false;
        if (dev.smartPortTypeIs(self.port, types.V5_DeviceType.kDeviceTypeMotorSensor)) return true;
        return dev.smartPortTypeIs(self.port, types.V5_DeviceType.kDeviceTypeCrMotorSensor);
    }
};

/// Push a velocity command, scaled by each follower's ratio, to every
/// follower of `master` (one extra jump-table call per follower).
fn fanoutRpm(master: ?*anyopaque, rpm: i32) void {
    const mdev = master orelse return;
    for (follower_table[0..follower_count]) |e| {
        const sdev = e.slave orelse continue;
        if (e.master != mdev) continue;
        const max = gearsetMaxRpm(e.slave_gearset);
        const scaled = std.math.clamp(@as(i32, @intFromFloat(std.math.round(@as(f64, @floatFromInt(rpm)) * e.ratio))), @as(i32, @intFromFloat(-max)), @as(i32, @intFromFloat(max)));
        jmptbl.motor.vexDeviceMotorVelocitySet(sdev, scaled);
    }
}

/// Push a voltage command, scaled by each follower's ratio, to every
/// follower of `master`.
fn fanoutMvolts(master: ?*anyopaque, mvolts: i32) void {
    const mdev = master orelse return;
    for (follower_table[0..follower_count]) |e| {
        const sdev = e.slave orelse continue;
        if (e.master != mdev) continue;
        const scaled = std.math.clamp(@as(i32, @intFromFloat(std.math.round(@as(f64, @floatFromInt(mvolts)) * e.ratio))), -convert.max_mvolts, convert.max_mvolts);
        jmptbl.motor.vexDeviceMotorVoltageSet(sdev, scaled);
    }
}
