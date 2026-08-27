const std = @import("std");
const jmptbl = @import("velox_jumptable");

const motor = @import("devices/Motor.zig");
const distance = @import("devices/Distance.zig");
const adi = @import("devices/ADI.zig");
const inertial = @import("devices/Inertial.zig");
const rotation = @import("devices/Rotation.zig");
const bumper = @import("devices/Bumper.zig");

fn isStruct(comptime ti: std.builtin.Type) bool {
    return switch (ti) {
        .@"struct" => true,
        else => false,
    };
}

/// Supported peripheral device types.
pub const DeviceType = enum {
    motor,
    distance,
    rotation,
    inertial,
    adi,
    bumper,
};

fn getPeripheralType(comptime dType: DeviceType) type {
    return switch (dType) {
        .motor => motor.Motor,
        .distance => distance.Distance,
        .inertial => inertial.Inertial,
        .bumper => bumper.Bumper,
        .rotation => rotation.Rotation,
        .adi => adi.ADI,
    };
}

/// Builds a struct of typed device handles from a user-supplied
/// configuration.
///
/// Each field in the config struct becomes a field in the resulting
/// [`Peripherals`] struct, with its type determined by the `.type` key.
///
/// ## Supported device types
///
/// | `.type` value | Resulting device type |
/// |---|---|
/// | `.motor` | [`Motor`](root.Motor) |
/// | `.distance` | [`Distance`](root.Distance) |
/// | `.inertial` | [`Inertial`](root.Inertial) |
/// | `.rotation` | [`Rotation`](root.Rotation) |
/// | `.adi` | [`ADI`](root.ADI) |
/// | `.bumper` | [`Bumper`](root.Bumper) |
///
/// ## Example
///
/// ```zig
/// const MyDevices = struct {
///     front_left: struct { .type = .motor },
///     front_right: struct { .type = .motor },
///     dist_front: struct { .type = .distance },
/// };
///
/// const Devices = velox_sdk.Peripherals(MyDevices);
/// ```
pub fn Peripherals(comptime config: anytype) type {
    const configT = @TypeOf(config);
    const configTInfo = @typeInfo(configT);
    if (!isStruct(configTInfo)) {
        @compileError("Configuration must be a struct");
    }
    const fields = configTInfo.@"struct".fields;
    var names: [fields.len][]const u8 = undefined;
    var types: [fields.len]type = undefined;
    var attrs: [fields.len]std.builtin.Type.StructField.Attributes = undefined;
    inline for (fields, 0..) |field, idx| {
        names[idx] = field.name;
        types[idx] = ?getPeripheralType(@field(@field(config, field.name), "kind"));
        attrs[idx] = .{
            .@"align" = @alignOf(types[idx]),
            .@"comptime" = false,
            .default_value_ptr = null,
        };
    }
    const T = @Struct(.auto, configTInfo.@"struct".backing_integer, &names, &types, &attrs);
    return T;
}
