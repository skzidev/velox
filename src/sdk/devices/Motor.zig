const jmptbl = @import("velox_jumptable");
const units = @import("../units.zig");
const errors = @import("../error.zig");
const convert = @import("../convert.zig");
const pool = @import("../devices.zig");

/// A VEX V5 Smart Motor — supports both the 11 W (276-4840) and
/// 5.5 W (276-4842) variants.
///
/// ## Supported operations
///
/// | Method | Description |
/// |---|---|
/// | [`spinAt`] | Set motor speed in RPM, mvolts, volts, or percent |
/// | [`temp`] | Read motor temperature |
/// | [`isOverheating`] | Check if the motor is overheating |
/// | [`setBrakingMode`] | Set coast / brake / hold mode |
/// | [`pos`] / [`setPos`] | Read / write encoder position |
/// | [`kind`] | Query whether the motor is 11 W or 5.5 W |
/// | [`efficiency`] | Read motor efficiency (0–100%) |
///
/// ## Example
///
/// ```zig
/// var motor = try velox_sdk.Motor.init(1, false, .green);
/// motor.spinAt(100, .percent);
///
/// const temp_c = motor.temp(.celsius);
/// motor.setBrakingMode(.brake);
/// ```
pub const Motor = struct {
    /// The available VEX V5 motor cartridges, each with a different
    /// gear ratio and maximum RPM.
    ///
    /// | Variant | Gear ratio | Free speed |
    /// |---|---|---|
    /// | `.red` | 36:1 | 100 RPM |
    /// | `.green` | 18:1 | 200 RPM |
    /// | `.blue` | 6:1 | 600 RPM |
    pub const MotorCartridge = enum(c_int) {
        /// V5 Red Cartridge (276-5840) — 36:1 gear ratio, 100 RPM free speed.
        red = 0,
        /// V5 Green Cartridge (276-5841) — 18:1 gear ratio, 200 RPM free speed.
        green,
        /// V5 Blue Cartridge (276-5842) — 6:1 gear ratio, 600 RPM free speed.
        blue,
        _,
    };

    /// Identifies whether a motor is the full-size 11 W variant or the
    /// compact 5.5 W variant.
    pub const MotorKind = enum(c_int) {
        /// Full-size 11 W Smart Motor (276-4840).
        full = 0,
        /// Compact 5.5 W Smart Motor (276-4842).
        half,
        _,
    };

    /// The braking mode applied when the motor is not actively spinning.
    ///
    /// | Variant | Behavior |
    /// |---|---|
    /// | `.coast` | No active braking; motor coasts to a stop via friction |
    /// | `.brake` | Active braking, but does not hold position |
    /// | `.hold` | Actively locks the motor at its current position |
    pub const BrakeMode = enum(c_int) {
        /// Coast mode — no active braking. The motor slows down naturally
        /// through friction.
        coast = 0,
        /// Brake mode — actively slows the motor but does not hold it in
        /// place.
        brake,
        /// Hold mode — actively locks the motor at its current position.
        /// The motor will resist external forces trying to move it.
        hold,
        _,
    };

    pub const Direction = enum(u1) {
        forward = 0,
        reverse = 1,
    };

    pub fn direction(self: *const Motor) Direction {
        return @intFromEnum(jmptbl.motor.vexDeviceMotorReverseFlagGet(self.handle));
    }

    pub fn setDirection(self: *const Motor, spinDirection: Direction) void {
        jmptbl.motor.vexDeviceMotorReverseFlagSet(self.handle, @intFromEnum(spinDirection));
    }

    handle: ?*anyopaque,

    /// Spins the motor at the given speed in the specified units.
    ///
    /// The sign of `speed` controls direction: positive values spin
    /// forward (unless the motor is reversed), negative values spin
    /// backward.
    ///
    /// ## Units
    ///
    /// - `.rpm` — target speed in revolutions per minute. The motor uses
    ///   its internal PID to hold this speed.
    /// - `.mvolts` — voltage in millivolts (range: -12000 to 12000).
    /// - `.volts` — voltage in volts (range: -12.0 to 12.0). Internally
    ///   converted to millivolts (`volts * 1000`).
    /// - `.percent` — percentage of maximum speed (-100 to 100). Internally
    ///   converted to millivolts.
    ///
    /// ## Example
    ///
    /// ```zig
    /// motor.spinAt(200, .rpm);       // 200 RPM forward
    /// motor.spinAt(-100, .percent);  // 100% reverse
    /// motor.spinAt(12000, .mvolts);   // full voltage forward
    /// motor.spinAt(6, .volts);       // 6 volts forward
    /// ```
    pub fn spinAt(
        self: *const Motor,
        /// The speed value. Sign determines direction.
        speed: i32,
        /// The unit of the speed value.
        unit: units.MotorUnit,
    ) void {
        if (unit == .rpm) {
            jmptbl.motor.vexDeviceMotorVelocitySet(self.handle, speed);
            return;
        }
        jmptbl.motor.vexDeviceMotorVoltageSet(self.handle, convert.motorSpeedToMvolts(speed, unit).?);
    }

    /// Initializes a motor on the given port.
    ///
    /// The `reversed` flag determines whether positive speed values spin
    /// the motor backward. The `cart` parameter specifies the installed
    /// cartridge.
    ///
    /// ## Example
    ///
    /// ```zig
    /// var motor = try velox_sdk.Motor.init(1, false, .green);
    /// motor.spinAt(100, .percent);
    /// ```
    pub fn init(
        /// The smart port number (1–20).
        port: u32,
        /// The installed cartridge.
        cart: MotorCartridge,
        /// The direction in which the motor should spin
        dir: Direction,
        /// The braking mode which the motor should use
        braking: BrakeMode,
    ) errors.DeviceInitError!Motor {
        if (!errors.portIsValid(port))
            return errors.DeviceInitError.InvalidPort;
        const poolIdx: usize = @intCast(port);
        // we know it's a valid port because we already validated it so the only reason that a pool
        // claim could throw an error is if the port is used
        pool.claim(poolIdx) catch {
            return errors.DeviceInitError.PortUsed;
        };
        const handle = jmptbl.devices.vexDeviceGetByIndex(port - 1);
        jmptbl.motor.vexDeviceMotorGearingSet(handle, @enumFromInt(@intFromEnum(cart)));
        jmptbl.motor.vexDeviceMotorReverseFlagSet(handle, if (dir == .reverse) 1 else 0);
        jmptbl.motor.vexDeviceMotorBrakeModeSet(handle, @enumFromInt(@intFromEnum(braking)));
        return Motor{
            .handle = handle,
        };
    }

    /// Returns the motor's current temperature in the specified units.
    ///
    /// The V5 motor reports temperature from its internal thermistor.
    /// Typical operating range is 20–50°C; the motor begins throttling
    /// around 55°C.
    ///
    /// ## Example
    ///
    /// ```zig
    /// const temp_c = motor.temp(.celsius);
    /// const temp_f = motor.temp(.fahrenheit);
    /// ```
    pub fn temp(
        self: *const Motor,
        /// The unit for the returned temperature.
        unit: units.TempUnit,
    ) f64 {
        const cTemp = jmptbl.motor.vexDeviceMotorTemperatureGet(self.handle);
        return convert.tempToUnit(cTemp, unit);
    }

    /// Returns `true` if the motor is currently overheating.
    ///
    /// The V5 motor sets an over-temperature flag when its internal
    /// temperature exceeds the safe operating threshold. While this flag
    /// is set, the motor may automatically reduce power (throttle).
    ///
    /// ```zig
    /// if (motor.isOverheating()) {
    ///     velox_sdk.Display.printOnLine("MOTOR HOT!", 0);
    /// }
    /// ```
    pub fn isOverheating(self: *const Motor) bool {
        return jmptbl.motor.vexDeviceMotorOverTempFlagGet(self.handle);
    }

    /// Sets the motor's braking mode.
    ///
    /// The braking mode determines how the motor behaves when not actively
    /// spinning. See [`BrakeMode`] for a description of each mode.
    ///
    /// ```zig
    /// motor.setBrakingMode(.brake);  // actively slow down
    /// motor.setBrakingMode(.hold);   // lock in place
    /// motor.setBrakingMode(.coast);  // coast freely
    /// ```
    pub fn setBrakingMode(self: *const Motor, mode: BrakeMode) void {
        jmptbl.motor.vexDeviceMotorBrakeModeSet(self.handle, mode);
    }

    /// Returns the motor's encoder position in the specified rotational
    /// units.
    ///
    /// The position is cumulative and can be positive or negative. The V5
    /// motor encoder has a resolution of 0.05625 degrees per tick.
    ///
    /// ## Units
    ///
    /// - `.degree` — position in degrees (may exceed 360 for multiple
    ///   rotations).
    /// - `.turn` — position in full turns / revolutions.
    /// - `.radian` — position in radians.
    ///
    /// ```zig
    /// const degrees = motor.pos(.degree);
    /// const turns = motor.pos(.turn);
    /// ```
    pub fn pos(self: *const Motor, unit: units.RotationalUnit) f64 {
        if (unit == .degree or unit == .radian) {
            jmptbl.motor.vexDeviceMotorEncoderUnitsSet(self.handle, .kMotorEncoderDegrees);
            return convert.angleFromDegrees(jmptbl.motor.vexDeviceMotorPositionGet(self.handle), unit);
        }
        jmptbl.motor.vexDeviceMotorEncoderUnitsSet(self.handle, .kMotorEncoderRotations);
        return jmptbl.motor.vexDeviceMotorPositionGet(self.handle);
    }

    /// Returns the motor kind (full-size 11 W or compact 5.5 W).
    ///
    /// This queries the hardware directly, so it can be used to detect
    /// which motor variant is physically connected.
    ///
    /// ```zig
    /// const kind = motor.kind();
    /// if (kind == .half) {
    ///     // 5.5 W motor
    /// }
    /// ```
    pub fn kind(self: *const Motor) MotorKind {
        return jmptbl.motor.vexDeviceMotorTypeGet(self.handle);
    }

    /// Returns the motor's current efficiency as a percentage (0–100).
    ///
    /// Efficiency is the ratio of power output to electrical power input.
    /// A value near 100% means the motor is running freely; lower values
    /// indicate the motor is under load.
    ///
    /// ```zig
    /// const eff = motor.efficiency();
    /// ```
    pub fn efficiency(self: *const Motor) f64 {
        return jmptbl.motor.vexDeviceMotorEfficiencyGet(self.handle);
    }

    /// Sets the motor's encoder position to the given value.
    ///
    /// This does not move the motor — it redefines the encoder's current
    /// reading to the specified value. Use this to establish a reference
    /// point.
    ///
    /// ## Units
    ///
    /// - `.degree` — value in degrees.
    /// - `.turn` — value in full turns / revolutions.
    /// - `.radian` — value in radians.
    ///
    /// ```zig
    /// motor.setPos(0, .degree);  // reset encoder to 0 degrees
    /// motor.setPos(1.0, .turn);  // set to 1 full turn
    /// ```
    pub fn setPos(self: *const Motor, value: f64, unit: units.RotationalUnit) void {
        if (unit == .degree or unit == .radian) {
            jmptbl.motor.vexDeviceMotorEncoderUnitsSet(self.handle, .kMotorEncoderDegrees);
            jmptbl.motor.vexDeviceMotorPositionSet(self.handle, convert.positionToDegrees(value, unit));
        } else {
            jmptbl.motor.vexDeviceMotorEncoderUnitsSet(self.handle, .kMotorEncoderRotations);
            jmptbl.motor.vexDeviceMotorPositionSet(self.handle, value);
        }
    }

    // TODO add units to speed
    pub fn spinToPos(self: *const Motor, position: f64, posUnit: units.RotationalUnit, speed: i32) void {
        jmptbl.motor.vexDeviceMotorAbsoluteTargetSet(
            self.handle,
            convert.positionToDegrees(position, posUnit),
            speed,
        );
    }

    /// Stops the motor.
    ///
    /// ```zig
    /// motor.stop();
    /// ```
    pub fn stop(self: *const Motor) void {
        jmptbl.motor.vexDeviceMotorVelocitySet(self.handle, 0);
    }
};
