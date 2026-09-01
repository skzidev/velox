const jmptbl = @import("velox_jumptable");

// TODO setup individual buttons/axes

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
/// A VEX V5 Controller.
///
/// Provides access to button state and joystick axis values for the
/// master or partner controller. Use the comptime [`Input`] function to
/// get a typed handle for a specific button or axis.
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
    /// The controller kind (master or partner).
    kind: ControllerKind,

    a: Input(.a) = .{ ._idx = .a, ._owner = .master },
    b: Input(.b) = .{ ._idx = .b, ._owner = .master },
    x: Input(.x) = .{ ._idx = .x, ._owner = .master },
    y: Input(.y) = .{ ._idx = .y, ._owner = .master },

    up: Input(.up) = .{ ._idx = .up, ._owner = .master },
    down: Input(.down) = .{ ._idx = .down, ._owner = .master },
    left: Input(.left) = .{ ._idx = .left, ._owner = .master },
    right: Input(.right) = .{ ._idx = .right, ._owner = .master },

    axis1: Input(.axis1) = .{ ._idx = .axis1, ._owner = .master },
    axis2: Input(.axis2) = .{ ._idx = .axis2, ._owner = .master },
    axis3: Input(.axis3) = .{ ._idx = .axis3, ._owner = .master },
    axis4: Input(.axis4) = .{ ._idx = .axis4, ._owner = .master },

    /// Identifies whether this is the master or partner controller.
    ///
    /// | Variant | Meaning |
    /// |---|---|
    /// | `.master` | The primary controller (port 0) |
    /// | `.partner` | The secondary / partner controller |
    pub const ControllerKind = enum(c_int) {
        /// The primary (master) controller.
        master = 0,
        /// The secondary (partner) controller.
        partner,
        _,
    };

    /// Identifies a controller input — either a button or a joystick axis.
    ///
    /// Buttons have a binary state (pressed / released). Axes return a
    /// signed integer value from -127 to 127.
    ///
    /// | Variant | Type | Description |
    /// |---|---|---|
    /// | `.axis1` | Axis | Left joystick horizontal (left/right) |
    /// | `.axis2` | Axis | Left joystick vertical (up/down) |
    /// | `.axis3` | Axis | Right joystick vertical (up/down) |
    /// | `.axis4` | Axis | Right joystick horizontal (left/right) |
    /// | `.l1`, `.l2` | Button | Left shoulder buttons |
    /// | `.r1`, `.r2` | Button | Right shoulder buttons |
    /// | `.up`, `.down`, `.left`, `.right` | Button | D-pad buttons |
    /// | `.a`, `.b`, `.x`, `.y` | Button | Face buttons |
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

    /// A handle to a single controller button. Created via
    /// [`Controller.Input`].
    const Button = struct {
        /// The button identifier.
        _idx: ControllerInput,
        /// The controller this button belongs to.
        _owner: ControllerKind,

        /// Returns `true` if the button is currently pressed.
        ///
        /// ```zig
        /// if (controller.Input(.a).pressed()) {
        ///     // button A is held
        /// }
        /// ```
        pub fn pressed(self: *const Button) bool {
            return jmptbl.controller.vexControllerGet(@enumFromInt(@intFromEnum(self._owner)), @enumFromInt(@intFromEnum(self._idx))) == 1;
        }
    };

    /// A handle to a single joystick axis. Created via
    /// [`Controller.Input`].
    const Axis = struct {
        /// The axis identifier.
        _idx: ControllerInput,
        /// The controller this axis belongs to.
        _owner: ControllerKind,

        /// Returns the joystick axis value (-127 to 127).
        ///
        /// Positive values are right/down; negative values are left/up.
        ///
        /// ```zig
        /// const value = controller.Input(.axis3).get();
        /// ```
        pub fn get(self: *const Axis) i32 {
            return jmptbl.controller.vexControllerGet(@enumFromInt(@intFromEnum(self._owner)), @enumFromInt(@intFromEnum(self._idx)));
        }
    };

    /// Returns the type ([`Button`] or [`Axis`]) for the given controller
    /// input at compile time.
    ///
    /// This is a comptime function — the input is resolved at compile
    /// time, so there is zero runtime overhead.
    ///
    /// ## Example
    ///
    /// ```zig
    /// // Button type
    /// const btn = controller.Input(.a);
    /// if (btn.pressed()) { ... }
    ///
    /// // Axis type
    /// const ax = controller.Input(.axis3);
    /// const val = ax.get();
    /// ```
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

            else => Button,
        };
    }

    /// Creates a controller instance for the given controller type.
    ///
    /// ## Example
    ///
    /// ```zig
    /// var controller = velox_sdk.Controller.init(.master);
    /// ```
    pub fn init(
        kind: ControllerKind,
    ) Controller {
        return Controller{ .kind = kind };
    }
};
