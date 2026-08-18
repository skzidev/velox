const velox_sdk = @import("velox_sdk");

pub fn createDevices(comptime config: anytype) velox_sdk.Peripherals.Peripherals(config) {
    const T = @TypeOf(config);
    const TInfo = @typeInfo(T);

    // this code assumes that TInfo.@"struct" is not null, which we validated

    var devices: velox_sdk.Peripherals.Peripherals(config) = .{};

    inline for (TInfo.@"struct".fields) |field| {
        @field(devices, field.name) = switch (field.type) {
            // TODO add types
            // Initialize all the types to a default value
        };
    }

    return devices;
}
