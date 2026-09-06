const jmptbl = @import("velox_jumptable");
const std = @import("std");

// TODO implement display

/// An abstraction over the V5 Brain's built-in LCD display.
///
/// Supports line-based text output. Lines are numbered 0–7.
/// Each call to [`printOnLine`] overwrites the content of the specified line.
///
/// ## Example
///
/// ```zig
/// velox_sdk.Display.printOnLine("Velox SDK v0.1", 0);
/// velox_sdk.Display.printOnLine("Motor temp: 42C", 1);
/// velox_sdk.Display.printOnLine("Battery: 100%", 2);
/// ```
pub const Display = struct {
    /// A position on the V5 Brain's LCD screen, specified in pixel coordinates.
    pub const ScreenPos = struct {
        /// The horizontal pixel coordinate.
        x: i32,
        /// The vertical pixel coordinate.
        y: i32,
    };

    /// Errors that can occur when interacting with the V5 display.
    pub const DisplayError = error{
        /// The specified line number is invalid (less than 0).
        InvalidLineError,
    };

    /// Prints a string to the LCD on the specified line.
    ///
    /// The string is displayed immediately on the given line. Previous
    /// content on that line is replaced. Lines are numbered 0–7.
    ///
    /// ## Example
    ///
    /// ```zig
    /// velox_sdk.Display.printOnLine(init.gpa.allocator(), "Status: OK", 0);
    /// velox_sdk.Display.printOnLine(init.arena.allocator(), "RPM: 200", 3);
    /// ```
    pub fn printOnLine(
        allocator: std.mem.Allocator,
        /// The text to display on the line.
        str: []const u8,
        /// The line number (0–7). Negative values return an error.
        line: i32,
    ) (DisplayError || error{OutOfMemory})!void {
        if (line < 0) return DisplayError.InvalidLineError;

        const c_string = try allocator.dupeZ(u8, str);
        defer allocator.free(c_string);

        const c_ptr: [*:0]const u8 = @ptrCast(c_string.ptr);
        jmptbl.display.vexDisplayString(line, c_ptr);
    }
};
