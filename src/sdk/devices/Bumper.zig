const adiModule = @import("./ADI.zig");
const errors = @import("../error.zig");

/// A VEX bumper switch sensor, connected via an ADI digital input port.
///
/// Returns `.pressed` when actuated and `.released` when not.
///
/// ## Example
///
/// ```zig
/// var bumper = velox_sdk.Bumper.init(1, 0);
///
/// if (bumper.state() == .pressed) {
///     velox_sdk.Display.printOnLine("Bumper pressed!", 0);
/// }
/// ```
pub const Bumper = struct {
    adi: adiModule.ADI,

    /// The state of a bumper switch sensor.
    pub const BumperState = enum(c_int) {
        /// The bumper is currently pressed (actuated).
        pressed = 0,
        /// The bumper is currently released (not actuated).
        released,
    };

    /// Initializes a bumper sensor on the given ADI port.
    ///
    /// The port is configured as a digital input automatically.
    ///
    /// ## Example
    ///
    /// ```zig
    /// var bumper = velox_sdk.Bumper.init(1);
    /// ```
    pub fn init(
        /// The ADI port number (1–8, corresponding to A–H).
        port: u8,
        expander: u32,
    ) errors.DeviceInitError!Bumper {
        const adiInstance = try adiModule.ADI.init(port, adiModule.ADI.ADIKind.digitalIn, expander);
        return Bumper{
            .adi = adiInstance,
        };
    }

    /// Returns the current state of the bumper switch.
    ///
    /// Returns `.pressed` if the bumper is actuated, or `.released` if
    /// it is not.
    ///
    /// ```zig
    /// switch (bumper.state()) {
    ///     .pressed => { /* actuated */ },
    ///     .released => { /* not actuated */ },
    /// }
    /// ```
    pub fn state(self: *Bumper) BumperState {
        return if (self.adi.get() <= 1) .pressed else .released;
    }
};
