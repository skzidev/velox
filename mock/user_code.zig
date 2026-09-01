const std = @import("std");
const velox = @import("velox");

/// Example user program for the Velox SDK.
///
/// Spins motor 1 on port 5 at 6 volts using the blue cartridge in
/// forward/coast mode, then sleeps forever.
pub fn main(init: velox.Init) !void {
    const l1 = try velox.Motor.init(11, .blue, .reverse, .coast);
    const l2 = try velox.Motor.init(13, .blue, .reverse, .coast);
    const l3 = try velox.Motor.init(14, .blue, .reverse, .coast);
    const l: []const velox.Motor = &[_]velox.Motor{ l1, l2, l3 };
    //
    const r1 = try velox.Motor.init(20, .blue, .reverse, .coast);
    const r2 = try velox.Motor.init(19, .blue, .reverse, .coast);
    const r3 = try velox.Motor.init(18, .blue, .reverse, .coast);
    const r: []const velox.Motor = &[_]velox.Motor{ r1, r2, r3 };

    const intake = try velox.Motor.init(10, .blue, .forward, .coast);
    const claw = try velox.Motor.init(1, .green, .reverse, .coast);

    const controller = velox.Controller.init(.master);

    while (true) {
        if (controller.a.pressed()) {
            intake.spinAt(127000, .mvolts);
        } else intake.stop();
        if (controller.b.pressed()) {
            claw.spinAt(127000, .mvolts);
        } else claw.stop();

        var x = controller.axis3.get();
        x = if (x <= 5 and x >= -5) 0 else x;
        var y = controller.axis4.get();
        y = if (y <= 5 and y >= -5) 0 else y;

        for (l) |motor| {
            motor.spinAt(y + x, .volts);
        }
        for (r) |motor| {
            motor.spinAt(y - x, .volts);
        }

        try init.io.sleep(
            std.Io.Duration.fromMilliseconds(2),
            .awake,
        );
    }
}
