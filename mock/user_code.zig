const velox = @import("velox");

const stdout = velox.V5Io.File.stdout();

fn auton() void {}

fn teleop() void {}

/// Example user program for the Velox SDK.
pub fn main(init: velox.Init) !void {
    try stdout.writeStreamingAll(init.io, "booting up...\n");

    var front = velox.Motor.init(velox.ports.smart(1), .green_18_1, .forward, .coast);
    var rear = velox.Motor.init(velox.ports.smart(2), .green_18_1, .forward, .coast);
    rear.follow(&front, 1.0);
    front.spinVelocity(.{ .percent = 50 });

    const rotation = velox.Rotation.init(velox.ports.smart(11));
    const imu = velox.Inertial.init(velox.ports.smart(12));
    const bumper = velox.Bumper.init(velox.ports.adi('A', null));

    try velox.Competition.compete(init.io, .{ .autonomous = &auton, .driverControl = &teleop });

    velox.Display.printLine(0, "imu={d:.1}", .{imu.heading()});
    _ = rotation.position();
    _ = bumper.pressed();
}
