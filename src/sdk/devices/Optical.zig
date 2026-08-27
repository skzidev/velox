const jmptbl = @import("velox_jumptable");
const errors = @import("../error.zig");

/// A VEX V5 Optical Sensor — detects color and proximity.
///
/// ## Example
///
/// ```zig
/// var optical = try velox_sdk.Optical.init(7);
/// ```
pub const Optical = struct {
    _handle: ?*anyopaque,

    /// Initializes an Optical Sensor on the given port.
    pub fn init(port: u32) errors.DeviceInitError!Optical {
        if (!errors.portIsValid(port))
            return errors.DeviceInitError.InvalidPortError;
        return .{ ._handle = jmptbl.devices.vexDeviceGetByIndex(port) };
    }

    // TODO implement optical sensor defs
};
