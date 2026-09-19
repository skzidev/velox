//! Device-handle resolution and identity helpers for the SDK device
//! layer. Handles are resolved once at construction (§18.1).

const std = @import("std");

const jmptbl = @import("velox_jumptable");
const types = jmptbl.types;
const ports = @import("../ports.zig");

/// Number of entries in the brain's device table, one per port slot
/// including the ADI host.
const device_table_len = 21;

/// Resolve the device handle for a smart port, or null if the port is
/// not claimed.
pub fn smartDevice(port: ports.SmartPort) ?*anyopaque {
    const idx = port.index;
    if (idx >= ports.smart_port_count) return null;
    return jmptbl.devices.vexDeviceGetByIndex(idx);
}

/// Resolve the device handle for a port's ADI host, or null if unclaimed.
pub fn adiHost(port: ports.AdiPort) ?*anyopaque {
    if (!port.isConnected()) return null;
    return jmptbl.devices.vexDeviceGetByIndex(port.host);
}

/// Ask the OS for the device type installed at a smart port (§18.1).
///
/// If the OS status query is unavailable (non-zero return), deterministically
/// fall back to "the port is connected" for claimed ports.
pub fn smartPortTypeIs(port: ports.SmartPort, expected: types.V5_DeviceType) bool {
    if (!port.isConnected()) return false;
    var buf: [device_table_len]types.V5_DeviceType = undefined;
    if (jmptbl.devices.vexDeviceGetStatus(@ptrCast(&buf)) != 0) return true;
    return buf[port.index] == expected;
}
