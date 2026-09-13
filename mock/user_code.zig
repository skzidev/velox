const velox = @import("velox");

const stdout = velox.V5Io.File.stdout();

fn auton() void {}

fn teleop() void {}

/// Example user program for the Velox SDK.
pub fn main(init: velox.Init) !void {
    try stdout.writeStreamingAll(init.io, "booting up...\n");
    const motor = try velox.Motor.init(1, .blue, .forward, .coast);
    motor.spinAt(100, .rpm);
}
