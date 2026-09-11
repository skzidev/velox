const jmptbl = @import("velox_jumptable");
const errors = @import("../error.zig");

/// A VEX ADI (Analog/Digital Interface) port on the 3-wire expander.
///
/// Provides 8 ports (A–H) that support analog and digital I/O.
/// Use [`init`] to configure a port with the desired mode, then use
/// [`get`] and [`set`] to read/write values.
///
/// ## Example
///
/// ```zig
/// // Digital input (e.g. limit switch)
/// var sw = velox_sdk.ADI.init(1, .digitalIn);
/// const pressed = sw.get() != 0;
///
/// // Analog input (e.g. potentiometer)
/// var pot = velox_sdk.ADI.init(2, .analogIn);
/// const value = pot.get();  // 0–4095
/// ```
pub const ADI = struct {
    /// The mode of an ADI port.
    ///
    /// | Variant | Description |
    /// |---|---|
    /// | `.analogIn` | Analog input (0–4095, 12-bit ADC) |
    /// | `.analogOut` | Analog output (PWM) |
    /// | `.digitalIn` | Digital input (high/low) |
    /// | `.digitalOut` | Digital output (high/low) |
    /// | `.unknown` | Port not configured (default) |
    pub const ADIKind = enum(c_int) {
        /// Analog input — reads a 12-bit value (0–4095) from the port.
        analogIn = 0,
        /// Analog output — drives a PWM signal on the port.
        analogOut,
        /// Digital input — reads a boolean (high/low) from the port.
        digitalIn,
        /// Digital output — drives a boolean (high/low) on the port.
        digitalOut,
        /// Unknown / unconfigured port state.
        unknown = 255,
    };

    var expander: ?*anyopaque = undefined;
    var port: u32 = undefined;
    var kind: ADIKind = undefined;

    /// Initializes an ADI port with the specified mode.
    ///
    /// ## Example
    ///
    /// ```zig
    /// var adi = velox_sdk.ADI.init(1, .digitalIn, 0);
    /// ```
    ///
    pub fn init(
        /// The ADI port letter (A–H).
        portLetter: u8,
        /// The mode to configure the port in.
        adiKind: ADIKind,
        /// The port of the expander (0 if it is on the brain)
        expanderPort: u32,
    ) errors.DeviceInitError!ADI {
        // TODO find out why serial is not flushing
        // TODO add support for using ADI expanders
        // This just means that the user can pass this port in if they would like
        if (expanderPort >= 21) return errors.DeviceInitError.InvalidPortError;
        const validatedExpanderPort = if (expanderPort == 0) 21 else expanderPort - 1;
        const ex = jmptbl.devices.vexDeviceGetByIndex(validatedExpanderPort);
        jmptbl.adi.vexDeviceAdiPortConfigSet(expander, port, @enumFromInt(@intFromEnum(kind)));
        return ADI{
            .expander = ex,
            .port = portLetter,
            .kind = adiKind,
        };
    }

    /// Reads the current value from the ADI port.
    ///
    /// For analog inputs, returns a 12-bit value (0–4095). For digital
    /// inputs, returns `0` (low) or `1` (high).
    ///
    /// ```zig
    /// const value = adi.get();
    /// ```
    pub fn get(self: *const ADI) u32 {
        return jmptbl.adi.vexDeviceAdiValueGet(self.expander, self.port);
    }

    /// Writes a value to the ADI port.
    ///
    /// For digital outputs, pass `0` for low or any non-zero value for
    /// high. For analog outputs, the value is used as a PWM duty cycle.
    ///
    /// ```zig
    /// adi.set(1);  // set digital output high
    /// adi.set(0);  // set digital output low
    /// ```
    pub fn set(self: *const ADI, value: i32) void {
        jmptbl.adi.vexDeviceAdiValueSet(self.expander, self.port, value);
    }
};
