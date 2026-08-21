const std = @import("std");
const velox = @import("velox_sdk");
pub const ports = @import("./ports.zon");

pub fn main(init: velox.Init(ports)) !void {
    // get the motor on port 1
    var motor: velox.Motor = init.devices.motor1 orelse try velox.Motor.init(1, false, .green);
    // spin the motor at 10 volts
    motor.spinAt(10, .volts);
}
