const serialIo = @import("../io/serial.zig");

pub const Io = struct {
    serial: @TypeOf(serialIo) = serialIo,
};
