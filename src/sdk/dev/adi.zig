//! ADI (three-wire) devices (§13): universal 8-pin port configuration.
//!
//! Each device resolves its ADI host handle at construction and writes
//! its pin configuration once (set-once). Every command no-ops and every
//! read returns zero on a disconnected or misconfigured pin.

const std = @import("std");

const jmptbl = @import("velox_jumptable");
const types = jmptbl.types;
const ports = @import("../ports.zig");
const units = @import("../units.zig");
const dev = @import("../internal/dev.zig");
const convert = @import("../internal/convert.zig");

/// A configured ADI pin. Owned privately by each public device.
const Host = struct {
    device: ?*anyopaque,
    pin: u32,
    config: types.V5_AdiPortConfiguration,

    fn init(port: ports.AdiPort, config: types.V5_AdiPortConfiguration) Host {
        var h = Host{ .device = null, .pin = port.pin, .config = config };
        const d = dev.adiHost(port) orelse return h;
        h.device = d;
        jmptbl.adi.vexDeviceAdiPortConfigSet(d, port.pin, config);
        return h;
    }

    fn isConnected(self: *const Host) bool {
        if (self.device == null) return false;
        return jmptbl.adi.vexDeviceAdiPortConfigGet(self.device, self.pin) == self.config;
    }

    fn valueGet(self: *const Host) i32 {
        if (!self.isConnected()) return 0;
        return jmptbl.adi.vexDeviceAdiValueGet(self.device, self.pin);
    }

    fn valueSet(self: *const Host, value: i32) void {
        if (!self.isConnected()) return;
        jmptbl.adi.vexDeviceAdiValueSet(self.device, self.pin, value);
    }
};

/// 12-bit analog full-scale.
const analog_range: f64 = 4095.0;
/// Potentiometer full-scale sweep, degrees (§13.4).
const pot_sweep: f64 = 270.0;
/// Analog rail, volts.
const rail_volts: f64 = 5.0;

/// Momentary-contact push button; true while held.
pub const Bumper = struct {
    host: Host,

    pub fn init(port: ports.AdiPort) Bumper {
        return .{ .host = Host.init(port, .kAdiPortTypeLegacyButton) };
    }

    /// True while the bumper is depressed. The raw digital line reads 0
    /// (pressed) or 1 (released); the canonical output is inverted.
    pub fn pressed(self: *const Bumper) bool {
        return self.host.valueGet() == 0;
    }

    pub fn isConnected(self: *const Bumper) bool {
        return self.host.isConnected();
    }
};

/// Limit switch; true while the roller is triggered.
pub const LimitSwitch = struct {
    host: Host,

    pub fn init(port: ports.AdiPort) LimitSwitch {
        return .{ .host = Host.init(port, .kAdiPortTypeLegacyButton) };
    }

    pub fn pressed(self: *const LimitSwitch) bool {
        return self.host.valueGet() == 0;
    }

    pub fn isConnected(self: *const LimitSwitch) bool {
        return self.host.isConnected();
    }
};

/// Infrared reflectance sensor that detects a line. Reports the fraction
/// of the analog rail as a percentage.
pub const LineTracker = struct {
    host: Host,

    pub fn init(port: ports.AdiPort) LineTracker {
        return .{ .host = Host.init(port, .kAdiPortTypeLegacyLineSensor) };
    }

    /// Reflectance, 0..100 percent.
    pub fn reflectance(self: *const LineTracker) f64 {
        const raw: f64 = @floatFromInt(self.host.valueGet());
        return std.math.clamp(raw / analog_range * 100.0, 0.0, 100.0);
    }

    pub fn isConnected(self: *const LineTracker) bool {
        return self.host.isConnected();
    }
};

/// Rotary potentiometer. The shaft sweeps ~270° over the analog rail.
pub const Potentiometer = struct {
    host: Host,

    pub fn init(port: ports.AdiPort) Potentiometer {
        return .{ .host = Host.init(port, .kAdiPortTypeLegacyPotentiometer) };
    }

    /// Shaft angle, degrees.
    pub fn angle(self: *const Potentiometer) f64 {
        const raw: f64 = @floatFromInt(self.host.valueGet());
        return raw / analog_range * pot_sweep;
    }

    /// Voltage on the wiper, volts.
    pub fn voltage(self: *const Potentiometer) f64 {
        const raw: f64 = @floatFromInt(self.host.valueGet());
        return raw / analog_range * rail_volts;
    }

    pub fn isConnected(self: *const Potentiometer) bool {
        return self.host.isConnected();
    }
};

/// Generic 12-bit analog input.
pub const AnalogInput = struct {
    host: Host,

    pub fn init(port: ports.AdiPort) AnalogInput {
        return .{ .host = Host.init(port, .kAdiPortTypeAnalogIn) };
    }

    /// Raw 12-bit reading, 0..4095.
    pub fn value(self: *const AnalogInput) u16 {
        return @intCast(self.host.valueGet());
    }

    /// Voltage, volts (raw / 4095 * 5).
    pub fn voltage(self: *const AnalogInput) f64 {
        return @as(f64, @floatFromInt(self.host.valueGet())) / analog_range * rail_volts;
    }

    pub fn isConnected(self: *const AnalogInput) bool {
        return self.host.isConnected();
    }
};

/// Analog-capable output: software PWM at ±127 duty. Power is mapped to
/// ±100% duty; ±12 V rail power is clamped to the firmware's ±12 V.
pub const AnalogOutput = struct {
    host: Host,

    pub fn init(port: ports.AdiPort) AnalogOutput {
        return .{ .host = Host.init(port, .kAdiPortTypeAnalogOut) };
    }

    /// Send a power level, mapped to ±127 PWM duty, clamped to ±100%.
    pub fn setVoltage(self: *const AnalogOutput, power: units.Power) void {
        const percent = convert.powerToAdiPercent(power);
        const pwm = @as(i32, @intFromFloat(std.math.round(percent * 127.0 / 100.0)));
        self.host.valueSet(std.math.clamp(pwm, -127, 127));
    }

    pub fn isConnected(self: *const AnalogOutput) bool {
        return self.host.isConnected();
    }
};

/// Digital 3.3/5 V output with a software pulse-width-modulated signal.
pub const DigitalOutput = struct {
    host: Host,

    pub fn init(port: ports.AdiPort) DigitalOutput {
        return .{ .host = Host.init(port, .kAdiPortTypeDigitalOut) };
    }

    /// Drive the pin high (true) or low (false).
    pub fn set(self: *const DigitalOutput, value: bool) void {
        self.host.valueSet(@intFromBool(value));
    }

    /// Invert the pin's current output level.
    pub fn toggle(self: *const DigitalOutput) void {
        self.set(self.host.valueGet() == 0);
    }

    pub fn isConnected(self: *const DigitalOutput) bool {
        return self.host.isConnected();
    }
};

/// Digital input, typically a switch wired to ground.
pub const DigitalInput = struct {
    host: Host,

    pub fn init(port: ports.AdiPort) DigitalInput {
        return .{ .host = Host.init(port, .kAdiPortTypeDigitalIn) };
    }

    /// True while the line reads high.
    pub fn get(self: *const DigitalInput) bool {
        return self.host.valueGet() != 0;
    }

    pub fn isConnected(self: *const DigitalInput) bool {
        return self.host.isConnected();
    }
};

/// Ultrasonic range finder: a sonar module across one ADI header. The
/// echo pin is configured as legacy PWM. Distance is reported in mm; the
/// raw read is in cm (the ×10 factor is hardware-pinned in §13.4).
pub const Ultrasonic = struct {
    ping: Host,

    pub fn init(ping: ports.AdiPort, echo: ports.AdiPort) Ultrasonic {
        const e = Host.init(echo, .kAdiPortTypeLegacyPwm);
        _ = e;
        return .{ .ping = Host.init(ping, .kAdiPortTypeSonar) };
    }

    /// Distance to the nearest object, mm; 0 when out of range. Only the
    /// brain's ADI header supports sonar in this SDK (§5.2).
    pub fn distance(self: *const Ultrasonic) f64 {
        const device = self.ping.device orelse return 0.0;
        if (!self.isConnected()) return 0.0;
        const cm = jmptbl.sonar.vexDeviceSonarValueGet(device);
        return @as(f64, @floatFromInt(cm)) * 10.0;
    }

    pub fn isConnected(self: *const Ultrasonic) bool {
        return self.ping.isConnected();
    }
};

/// Pneumatic solenoid: a digital output that engages or vents a valve.
pub const Solenoid = struct {
    host: Host,

    pub fn init(port: ports.AdiPort) Solenoid {
        return .{ .host = Host.init(port, .kAdiPortTypeDigitalOut) };
    }

    /// Drive the solenoid to its extended (active) position.
    pub fn extend(self: *const Solenoid) void {
        self.host.valueSet(1);
    }

    /// Drive the solenoid to its retracted (rest) position.
    pub fn retract(self: *const Solenoid) void {
        self.host.valueSet(0);
    }

    /// Set the solenoid's state explicitly.
    pub fn set(self: *const Solenoid, extended: bool) void {
        self.host.valueSet(@intFromBool(extended));
    }

    /// Invert the solenoid's current state. Reads the output back; on an
    /// unconnected pin this is a no-op.
    pub fn toggle(self: *const Solenoid) void {
        self.set(self.host.valueGet() == 0);
    }

    pub fn isConnected(self: *const Solenoid) bool {
        return self.host.isConnected();
    }
};

/// Backwards-compatible alias for a single-solenoid device (§13.10).
pub const Pneumatic = Solenoid;

/// A two-position pneumatic device driven by two solenoid outputs. Both
/// outputs are always driven opposite, never released together.
pub const DoubleSolenoid = struct {
    /// Valve position: which output is driven.
    pub const State = enum(u1) {
        extended,
        retracted,
    };

    a: Host,
    b: Host,
    state: State,

    pub fn init(a: ports.AdiPort, b: ports.AdiPort) DoubleSolenoid {
        return .{
            .a = Host.init(a, .kAdiPortTypeDigitalOut),
            .b = Host.init(b, .kAdiPortTypeDigitalOut),
            .state = .retracted,
        };
    }

    /// Move the valve to `state`.
    pub fn set(self: *const DoubleSolenoid, state: State) void {
        switch (state) {
            .extended => {
                self.a.valueSet(1);
                self.b.valueSet(0);
            },
            .retracted => {
                self.a.valueSet(0);
                self.b.valueSet(1);
            },
        }
    }

    /// Move the valve to its extended position.
    pub fn extend(self: *const DoubleSolenoid) void {
        self.set(.extended);
    }

    /// Move the valve to its retracted position.
    pub fn retract(self: *const DoubleSolenoid) void {
        self.set(.retracted);
    }

    pub fn isConnected(self: *const DoubleSolenoid) bool {
        return self.a.isConnected() and self.b.isConnected();
    }
};
