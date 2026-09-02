const std = @import("std");
const velox = @import("velox");

/// Example user program for the Velox SDK.
///
/// Spins motor 1 on port 5 at 6 volts using the blue cartridge in
/// forward/coast mode, then sleeps forever.
pub fn main(init: velox.Init) !void {
    const stdout = velox.V5Io.File.stdout();
    const pneumatic = velox.Pneumatic.init(0, 0) catch |err| {
        try stdout.writeStreamingAll(init.io, @errorName(err));
        return;
    };
    pneumatic.extend();
    try init.io.sleep(
        std.Io.Duration.fromSeconds(2),
        .awake,
    );
    pneumatic.retract();
    while (true) {
        try init.io.sleep(
            std.Io.Duration.fromMilliseconds(2),
            .awake,
        );
    }
}
