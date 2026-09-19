//! V5 brain display (§15): 480×240 color LCD, 28 columns by 8 rows at
//! the default font size. All drawing coordinates are clamped to the
//! screen; lines are truncated (never overflow) and wrapped text never
//! runs past row 7.

const std = @import("std");

const jmptbl = @import("velox_jumptable");

pub const display_width = 480;
pub const display_height = 240;
/// Character cells per row at the default font size.
pub const line_width = 28;
pub const line_count = 8;

/// An RGB color packed from three 8-bit channels.
pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

fn packRgb(c: Color) u32 {
    return (@as(u32, c.r) << 16) | (@as(u32, c.g) << 8) | c.b;
}

/// The brain's display. Namespace-style API: call methods as
/// `Display.printLine(...)`.
pub const Display = struct {
    /// Print `fmt` on `line`, truncating from the right rather than
    /// overflowing. `line` is a compile-time constant 0..7.
    pub fn printLine(comptime row: u3, comptime fmt: []const u8, args: anytype) void {
        var buf: [128:0]u8 = undefined;
        _ = formatRow(&buf, fmt, args);
        jmptbl.display.vexDisplayString(@intCast(row), @ptrCast(&buf));
    }

    /// Print `fmt` starting on `line`, wrapping at 28 columns onto the
    /// following rows and clipping at the last row (§15.3).
    pub fn printLineWrapped(comptime start_row: u3, comptime fmt: []const u8, args: anytype) void {
        var full_buf: [line_width * line_count]u8 = undefined;
        const full = formatTrunc(&full_buf, fmt, args);

        var pos: u3 = start_row;
        var i: usize = 0;
        while (i < full.len) : (i += line_width) {
            var chunk: [line_width + 1:0]u8 = undefined;
            const end = @min(i + line_width, full.len);
            @memcpy(chunk[0 .. end - i], full[i..end]);
            chunk[end - i] = 0;
            jmptbl.display.vexDisplayString(@intCast(pos), @ptrCast(&chunk));
            if (pos == line_count - 1) break;
            pos += 1;
        }
    }

    /// Clear a whole line by printing blank cells.
    pub fn clearLine(comptime row: u3) void {
        jmptbl.display.vexDisplayString(@intCast(row), @ptrCast(&blank_row));
    }

    /// Erase the entire screen.
    pub fn erase() void {
        jmptbl.display.vexDisplayErase();
    }

    /// Set the font scale for subsequent text; values below 1 are
    /// clamped up (§15.2).
    pub fn setTextSize(scale: u3) void {
        jmptbl.display.vexDisplayTextSize(@max(scale, 1), 1);
    }

    /// Set the text color.
    pub fn setForeground(color: Color) void {
        jmptbl.display.vexDisplayForegroundColor(packRgb(color));
    }

    /// Set the background color (fills the erase/clear area).
    pub fn setBackground(color: Color) void {
        jmptbl.display.vexDisplayBackgroundColor(packRgb(color));
    }

    /// Draw (on) or clear (off) a single pixel, clamped to the screen.
    pub fn pixel(x: i32, y: i32, on: bool) void {
        const cx = std.math.clamp(x, 0, display_width - 1);
        const cy = std.math.clamp(y, 0, display_height - 1);
        if (on)
            jmptbl.display.vexDisplayPixelSet(@intCast(cx), @intCast(cy))
        else
            jmptbl.display.vexDisplayPixelClear(@intCast(cx), @intCast(cy));
    }

    /// Draw a line between two points, clamping coordinates.
    pub fn line(a: Point, b: Point) void {
        jmptbl.display.vexDisplayLineDraw(
            @intCast(std.math.clamp(a.x, 0, display_width - 1)),
            @intCast(std.math.clamp(a.y, 0, display_height - 1)),
            @intCast(std.math.clamp(b.x, 0, display_width - 1)),
            @intCast(std.math.clamp(b.y, 0, display_height - 1)),
        );
    }

    /// Draw an axis-aligned rectangle between two corners; `fill`
    /// controls whether the interior is filled.
    pub fn rect(a: Point, b: Point, fill: bool) void {
        const x1 = std.math.clamp(@min(a.x, b.x), 0, display_width - 1);
        const y1 = std.math.clamp(@min(a.y, b.y), 0, display_height - 1);
        const x2 = std.math.clamp(@max(a.x, b.x), 0, display_width - 1);
        const y2 = std.math.clamp(@max(a.y, b.y), 0, display_height - 1);
        if (fill)
            jmptbl.display.vexDisplayRectFill(x1, y1, x2, y2)
        else
            jmptbl.display.vexDisplayRectDraw(x1, y1, x2, y2);
    }

    /// Draw a circle around `center` with `radius`, optionally filled.
    pub fn circle(center: Point, radius: i32, fill: bool) void {
        const cx = std.math.clamp(center.x, 0, display_width - 1);
        const cy = std.math.clamp(center.y, 0, display_height - 1);
        const r = std.math.clamp(radius, 0, display_height);
        if (fill)
            jmptbl.display.vexDisplayCircleFill(cx, cy, r)
        else
            jmptbl.display.vexDisplayCircleDraw(cx, cy, r);
    }

    /// Commit the double-buffered frame (§15.5).
    pub fn render() void {
        _ = jmptbl.display.vexDisplayRender(1, 1);
    }
};

/// A point on the display.
pub const Point = struct {
    x: i32,
    y: i32,
};

const blank_row = "                            ";

/// Format into `row`, truncating from the right so a NUL always fits.
/// The formatted text is written and NUL-terminated in `row`; the
/// returned slice calls the caller's `vexDisplayString` pointer.
fn formatRow(row: *[128:0]u8, comptime fmt: []const u8, args: anytype) []const u8 {
    if (row.len == 1) {
        row[0] = 0;
        return row[0..0];
    }
    var n: usize = row.len - 1;
    while (true) {
        if (std.fmt.bufPrint(row[0..n], fmt, args)) |s| {
            row[s.len] = 0;
            return s;
        } else |_| {}
        if (n == 0) {
            row[0] = 0;
            return row[0..0];
        }
        n -= 1;
    }
}

/// Format into `buf`, truncating from the right (deterministic longest
/// prefix that fits).
fn formatTrunc(buf: []u8, comptime fmt: []const u8, args: anytype) []const u8 {
    var n: usize = buf.len;
    while (true) {
        if (std.fmt.bufPrint(buf[0..n], fmt, args)) |s| return s else |_| {}
        if (n == 0) return buf[0..0];
        n -= 1;
    }
}
