const jmptbl = @import("velox_jumptable");
const errors = @import("../error.zig");

/// A VEX V5 Optical Sensor — detects color and proximity.
///
/// The Optical Sensor uses a photodiode and an RGB LED to detect
/// ambient light, proximity, and color. This driver is currently a
/// **stub** — only [`init`] is implemented. Color, proximity, gesture,
/// and LED control will be added in a future release.
///
/// ## Example
///
/// ```zig
/// var optical = try velox_sdk.Optical.init(7);
/// // TODO: add proximity / color reading once implemented
/// ```
pub const Optical = struct {
    /// The device handle returned by the VEXos jumptable.
    handle: ?*anyopaque,

    /// Initializes an Optical Sensor on the given smart port.
    ///
    /// ## Arguments
    ///
    /// - `port` — the smart port number (1–20).
    ///
    /// ## Errors
    ///
    /// Returns `error.InvalidPortError` if the port is out of range.
    ///
    /// ## Example
    ///
    /// ```zig
    /// var optical = try velox_sdk.Optical.init(7);
    /// ```
    pub fn init(port: u32) errors.DeviceInitError!Optical {
        if (!errors.portIsValid(port))
            return errors.DeviceInitError.InvalidPort;
        return .{ .handle = jmptbl.devices.vexDeviceGetByIndex(port) };
    }

    // TODO implement optical sensor: proximity, color, gesture, LED control
};
