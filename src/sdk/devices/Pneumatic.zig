const adi = @import("ADI.zig");
const jmptbl = @import("velox_jumptable");

/// A VEX pneumatic solenoid, connected via an ADI digital output port.
///
/// Controls a single-acting or double-acting pneumatic cylinder.
///
/// ## Example
///
/// ```zig
/// var piston = velox_sdk.Pneumatic.init(1, 0);
/// piston.extend();
/// ```
pub const Pneumatic = struct {
    adi: adi.ADI,

    /// Initializes a pneumatic solenoid on the given ADI port.
    pub fn init(port: u8, expander: u32) Pneumatic {
        return .{
            ._adi = adi.ADI.init(port, .digitalOut, expander),
        };
    }

    /// Extends the pneumatic cylinder (sets output high).
    pub fn extend(self: *const Pneumatic) void {
        self._adi.set(true);
    }

    /// Retracts the pneumatic cylinder (sets output low).
    pub fn retract(self: *const Pneumatic) void {
        self._adi.set(false);
    }

    /// Toggles the pneumatic cylinder between extended and retracted.
    pub fn toggle(self: *const Pneumatic) void {
        self._adi.set(!self._adi.get());
    }

    /// Sets the pneumatic cylinder to the given state (`true` = extend, `false` = retract).
    pub fn set(self: *const Pneumatic, v: bool) void {
        self._adi.set(v);
    }
};
