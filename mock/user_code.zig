const std = @import("std");
const velox = @import("velox");

/// Example user program for the Velox SDK.
///
/// Spins motor 1 on port 5 at 6 volts using the blue cartridge in
/// forward/coast mode, then sleeps forever.
pub fn main(init: velox.Init) !void {
    const stdout = velox.V5Io.File.stdout();
    try stdout.writeStreamingAll(init.io, "test message");
    while (true) {
        try init.io.sleep(
            std.Io.Duration.fromMilliseconds(2),
            .awake,
        );
    }
}
