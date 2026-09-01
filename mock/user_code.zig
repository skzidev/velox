const std = @import("std");
const velox = @import("velox");

pub fn main(init: velox.Init) !void {
    const motor = try velox.Motor.init(
        5,
        .blue,
        .forward,
        .coast,
    );
    motor.spinAt(127000, .mvolts);

    while (true) {
        try init.io.sleep(
            std.Io.Duration.fromMilliseconds(2),
            .awake,
        );
    }
}
