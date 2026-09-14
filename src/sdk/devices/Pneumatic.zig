const adiModule = @import("ADI.zig");

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
    adi: adiModule.ADI,

    /// Initializes a pneumatic solenoid on the given ADI port.
    pub fn init(port: u8, expander: u32) !Pneumatic {
        return .{
            .adi = try adiModule.ADI.init(port, .digitalOut, expander),
        };
    }

    /// Extends the pneumatic cylinder (sets output high).
    pub fn extend(self: *const Pneumatic) void {
        self.adi.set(@intFromBool(true));
    }

    /// Retracts the pneumatic cylinder (sets output low).
    pub fn retract(self: *const Pneumatic) void {
        self.adi.set(@intFromBool(false));
    }

    /// Toggles the pneumatic cylinder between extended and retracted.
    pub fn toggle(self: *const Pneumatic) void {
        self.adi.set(@intFromBool(!(self.adi.get() == 1)));
    }

    /// Sets the pneumatic cylinder to the given state (`true` = extend, `false` = retract).
    pub fn set(self: *const Pneumatic, v: bool) void {
        self.adi.set(@intFromBool(v));
    }
};
