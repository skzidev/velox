pub const Motor = @import("./devices/motor.zig").Motor;

pub const Competition = struct {
    autonomous: *const fn () void,
    driver: *const fn () void,
};
