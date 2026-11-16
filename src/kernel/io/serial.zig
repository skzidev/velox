const jmptbl = @import("jumptable");

const BUFFER_SIZE = 2048;
const SERIAL_CHANNEL: i32 = 1;

const SerialWriteError = error{InternalWriteError};

/// Writes a byte sequence to serial I/O.
/// This function depends on flush() and cannot be called from with the VEXos scheduler.
pub fn write(str: []const u8) SerialWriteError!void {
    var offset: usize = 0;

    while (offset < str.len) {
        const chunk = str[offset..(offset + @min(BUFFER_SIZE, str.len - offset))];
        if (jmptbl.vexSerialWriteFree(SERIAL_CHANNEL) < chunk.len) {
            flush();
        }

        const count = jmptbl.vexSerialWriteBuffer(
            SERIAL_CHANNEL,
            @ptrCast(@constCast(chunk.ptr)),
            @intCast(chunk.len),
        );
        if (count == -1) return SerialWriteError.InternalWriteError;
        if (count != chunk.len) break;

        offset += chunk.len;
    }
}

/// Flushes serial I/O by calling vexTasksRun (which runs the serial I/O task).
/// This function can (and its dependents) therefore not be called from within the VEXos scheduler.
pub fn flush() void {
    while (jmptbl.vexSerialWriteFree(SERIAL_CHANNEL) != BUFFER_SIZE) {
        _ = jmptbl.vexTasksRun();
    }
}
