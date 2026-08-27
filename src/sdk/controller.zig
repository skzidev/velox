const jmptbl = @import("velox_jumptable");

/// A VEX V5 Controller.
///
/// Provides access to button state and joystick axis values.
///
/// ## Example
///
/// ```zig
/// var controller = velox_sdk.Controller.init(.master);
///
/// // Check a button
/// if (controller.Input(.a).pressed()) {
///     // button A is held
/// }
///
/// // Read a joystick axis
/// const value = controller.Input(.axis3).get();  // -127 to 127
/// ```
pub const Controller = struct {
    _kind: ControllerKind,

    /// The controller type (master or partner).
    pub const ControllerKind = enum(c_int) { master = 0, partner, _ };

    /// Identifies a controller input (button or axis).
    pub const ControllerInput = enum(c_int) {
        axis4 = 0,
        axis3,
        axis1,
        axis2,
        axisSpare1,
        axisSpare2,
        l1,
        l2,
        r1,
        r2,
        up,
        down,
        left,
        right,
        x,
        b,
        y,
        a,
        ButtonSEL,
        BatteryLevel,
        ButtonAll,
        Flags,
        BatteryCapacity,
        _,
    };

    const Button = struct {
        _idx: ControllerInput,
        _owner: ControllerKind,

        /// Returns `true` if the button is currently pressed.
        pub fn pressed(self: *Button) bool {
            return jmptbl.controller.vexControllerGet(self._owner, self._idx);
        }
    };

    const Axis = struct {
        _idx: ControllerInput,
        _owner: ControllerKind,

        /// Returns the joystick axis value (-127 to 127).
        pub fn get(self: *Axis) i32 {
            return jmptbl.controller.vexControllerGet(self._owner, self._idx);
        }
    };

    /// Returns the type ([`Button`] or [`Axis`]) for the given controller input.
    pub fn Input(comptime ci: ControllerInput) type {
        return switch (ci) {
            .a => Button,
            .b => Button,
            .x => Button,
            .y => Button,

            .left => Button,
            .right => Button,
            .up => Button,
            .down => Button,

            .r1 => Button,
            .r2 => Button,
            .l1 => Button,
            .l2 => Button,

            .axis1 => Axis,
            .axis2 => Axis,
            .axis3 => Axis,
            .axis4 => Axis,
        };
    }

    /// Creates a controller instance for the given controller type.
    pub fn init(
        kind: ControllerKind,
    ) Controller {
        return Controller{ ._kind = kind };
    }
};
