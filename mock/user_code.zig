const std = @import("std");
const velox = @import("velox");

fn monitorThread(io: std.Io) !void {
    const stdout = velox.V5Io.File.stdout();
    while (true) {
        try stdout.writeStreamingAll(io, "task is running!");
    }
}

pub fn teleop() void {
    //
}

pub fn auton() void {
    //
}

pub fn main(init: velox.Init) !void {
    const motor = try velox.Motor.init(5, .blue, .forward, .coast);
    motor.spinAt(100, .rpm);

    while (true) {
        try init.io.sleep(
            std.Io.Duration.fromMilliseconds(2),
            .awake,
        );
    }
}
