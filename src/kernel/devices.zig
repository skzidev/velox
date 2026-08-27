const velox_sdk = @import("velox_sdk");
const std = @import("std");

fn configType(comptime dt: velox_sdk.Peripherals.DeviceType) type {
    return switch (dt) {
        .motor => struct {
            reversed: bool,
            cartridge: velox_sdk.Motor.MotorCartridge,
        },
        .distance => null,
        .bumper => struct { adi: u8 },
        .adi => struct { adi: u8, adiKind: velox_sdk.ADI.ADIKind },
        .inertial => null,
        .rotation => null,
    };
}

fn deviceConfig(dt: velox_sdk.Peripherals.DeviceType) type {
    return struct {
        port: u32,
        kind: velox_sdk.Peripherals.DeviceType,
        config: configType(dt),
    };
}

pub fn createDevices(comptime config: anytype) velox_sdk.Peripherals.Peripherals(config) {
    const T = @TypeOf(config);
    const TInfo = @typeInfo(T);

    std.debug.assert(TInfo == .@"struct");

    var devices: velox_sdk.Peripherals.Peripherals(config) = undefined;

    inline for (TInfo.@"struct".fields) |field| {
        const raw_item = @field(config, field.name);

        //: deviceConfig(@field(raw_item, "kind"))
        const value = raw_item;

        @field(devices, field.name) = switch (value.kind) {
            .motor => velox_sdk.Motor.init(
                value.port,
                if (value.config.reversed) .reverse else .forward,
                value.config.cartridge,
            ) catch null,
            .adi => velox_sdk.ADI.init(value.config.adi, value.config.adiKind, value.port),
            .bumper => velox_sdk.Bumper.init(value.config.adi, value.port),
            .distance => velox_sdk.Distance.init(value.port),
            .inertial => velox_sdk.Inertial.init(value.port),
            .rotation => velox_sdk.Rotation.init(value.port),
            else => @compileError("Unsupported device type"),
        };
    }

    return devices;
}
