const jmptbl = @import("jumptable");

const BUFFER_SIZE = 2048;
const SERIAL_CHANNEL: i32 = 1;

const SerialWriteError = error{InternalWriteError};

/// Writes a byte sequence to serial I/O.
/// May block while waiting for buffer space.
///
/// Unsafe to call from VEXos task context.
pub fn write(str: []const u8) SerialWriteError!void {
    var offset: usize = 0;

    while (offset < str.len) {
        const remaining = str.len - offset;
        const chunk_len: usize = @min(BUFFER_SIZE, remaining);
        const chunk = str[offset..][0..chunk_len];

        if (jmptbl.vexSerialWriteFree(SERIAL_CHANNEL) < @as(i32, @intCast(chunk_len))) {
            flush();
        }

        const count = jmptbl.vexSerialWriteBuffer(
            SERIAL_CHANNEL,
            @ptrCast(@constCast(chunk.ptr)),
            @intCast(chunk.len),
        );
        if (count < 0) return SerialWriteError.InternalWriteError;
        if (count == 0) {
            jmptbl.vexTaskSleep(2);
            continue;
        }

        offset += @intCast(count);
    }
}

/// Flushes serial I/O by waiting for the VEXos serial buffer to drain.
///
/// Unsafe to call from VEXos task context.
pub fn flush() void {
    while (jmptbl.vexSerialWriteFree(SERIAL_CHANNEL) < BUFFER_SIZE) {
        _ = jmptbl.vexTasksRun();
    }
}
