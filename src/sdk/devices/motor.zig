pub const Motor = struct {
    port: u8,

    pub fn init(port: u8) Motor {
        return .{ .port = port };
    }
};
