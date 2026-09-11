const velox = @import("velox");

fn auton() void {}

fn teleop() void {}

/// Example user program for the Velox SDK.
///
/// Spins motor 1 on port 5 at 6 volts using the blue cartridge in
/// forward/coast mode, then sleeps forever.
pub fn main(init: velox.Init) !void {
    _ = try velox.Competition.compete(
        init.io,
        .{
            .autonomous = auton,
            .driverControl = teleop,
        },
    );
}
