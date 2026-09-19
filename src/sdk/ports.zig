//! Physical port identities (spec §5).
//!
//! Smart ports and ADI pins are value types: they carry only what is
//! needed to reach a V5 device handle and are cheap to copy.

const std = @import("std");

/// Get a smart port by compile-time literal: `ports.smart(1)` (§5.1).
pub fn smart(comptime n: comptime_int) SmartPort {
    return SmartPort.smart(n);
}

/// Get a smart port by runtime value; out of range yields a disconnected
/// port.
pub fn smartAt(n: u8) SmartPort {
    return SmartPort.smartAt(n);
}

/// Get an ADI pin on the brain (`'A'..'H'`) or an expander (§5.2).
pub fn adi(comptime p: comptime_int, expander: ?SmartPort) AdiPort {
    return AdiPort.adi(p, expander);
}

/// Get an ADI pin at runtime; invalid letters yield a disconnected port.
pub fn adiAt(p: u8, expander: ?SmartPort) AdiPort {
    return AdiPort.adiAt(p, expander);
}

/// Number of smart ports on the brain. Spec §5.1 pins the valid range
/// to 1..20; `ports.smart(0)` and `ports.smart(21)` are compile errors.
pub const smart_port_count = 20;

/// Device-table index of the brain's internal ADI host (spec §5.2).
/// Smart port devices occupy device-table indices 0..19; the ADI host
/// lives at index 21. Pinned on hardware before release.
pub const brain_adi_host_index = 21;

/// Sentinel device-table index for an unclaimed/disconnected port.
const disconnected: u8 = 0xFF;

/// A V5 smart-port identity (port 1..20).
///
/// Internally stores the zero-based device-table index (0..19) so a
/// device may be reached via `vexDeviceGetByIndex`. See `SmartPort`
/// (§5.1).
pub const SmartPort = struct {
    index: u8,

    /// Get a smart port by its literal number, 1..20.
    ///
    /// The port number is a compile-time constant ("smart(1)"); values
    /// outside 1..20 are compile errors (§5.1).
    pub fn smart(comptime n: comptime_int) SmartPort {
        const info = @src();
        if (n < 1 or n > smart_port_count) {
            @compileError(std.fmt.comptimePrint("{s}:{d}:{d}: invalid smart port {d}; must be 1..{d}", .{ info.file, info.line, info.column, n, smart_port_count }));
        }
        return .{ .index = @intCast(n - 1) };
    }

    /// Get a smart port by a runtime value, 1..20.
    ///
    /// Out-of-range values yield a disconnected port (every call then
    /// deterministically no-ops or returns zero, rather than erroring).
    pub fn smartAt(n: u8) SmartPort {
        if (n < 1 or n > smart_port_count) return .{ .index = disconnected };
        return .{ .index = n - 1 };
    }

    /// Whether this port identity maps to a claimed device.
    pub fn isConnected(self: SmartPort) bool {
        return self.index < smart_port_count;
    }
};

/// An ADI (three-wire) pin identity, either on the brain (`'A'..'H'`)
/// or on a smart-port ADI expander.
///
/// Stores the zero-based pin number (0..7 for `'A'..'H'`) and the
/// device-table index of the ADI host that owns it. Everything below
/// `'A'..'H'` handling is per §5.2.
pub const AdiPort = struct {
    /// Zero-based pin number, 0 = 'A'. `0xFF` when disconnected.
    pin: u8,
    /// Device-table index of the owning ADI host (brain = 21, expander
    /// = its smart port index). `0xFF` when disconnected.
    host: u8,

    /// Get an ADI pin by letter on the brain header, e.g. `ports.adi('D', null)`.
    ///
    /// The pin is a compile-time constant; anything other than `'A'..'H'`
    /// is a compile error. Pass a connected smart port as `expander` to
    /// address the expander's ADI header instead of the brain's. A
    /// disconnect (from a smart port) yields a disconnected pin, never
    /// an error.
    pub fn adi(comptime p: comptime_int, expander: ?SmartPort) AdiPort {
        const info = @src();
        if (p < 'A' or p > 'H') {
            @compileError(std.fmt.comptimePrint("{s}:{d}:{d}: invalid ADI pin {c}; must be 'A'..'H'", .{ info.file, info.line, info.column, p }));
        }
        const host: u8 = if (expander) |sp| sp.index else brain_adi_host_index;
        return .{ .pin = @intCast(p - 'A'), .host = host };
    }

    /// Get an ADI pin by letter at runtime. Invalid letters yield a
    /// disconnected port.
    pub fn adiAt(p: u8, expander: ?SmartPort) AdiPort {
        if (p < 'A' or p > 'H') return .{ .pin = disconnected, .host = disconnected };
        const host: u8 = if (expander) |sp| sp.index else brain_adi_host_index;
        return .{ .pin = @intCast(p - 'A'), .host = host };
    }

    /// Whether this pin maps to a claimed host with a valid pin number.
    pub fn isConnected(self: AdiPort) bool {
        return self.pin < 8 and self.host != disconnected and self.host < 0xFF;
    }
};
