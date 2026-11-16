const jmptbl = @import("jumptable");

const BUFFER_SIZE = 2048;
const SERIAL_CHANNEL: i32 = 1;

const SerialWriteError = error{InternalWriteError};

pub fn write(str: []const u8) SerialWriteError!void {
    var offset: usize = 0;

    while (offset < str.len) {
        const chunk = str[offset .. offset + @min(BUFFER_SIZE, str.len - offset)];
        if (jmptbl.vexSerialWriteFree(SERIAL_CHANNEL) < chunk.len) {
            flush();
        }

        const count = jmptbl.vexSerialWriteBuffer(
            SERIAL_CHANNEL,
            chunk.ptr,
            @intCast(chunk.len),
        );
        if (count == -1) return SerialWriteError.InternalWriteError;
        if (count != chunk.len) break;

        offset += chunk.len;
    }
}

pub fn flush() void {
    while (jmptbl.vexSerialWriteFree(SERIAL_CHANNEL) != BUFFER_SIZE) {
        jmptbl.vexTasksRun();
    }
}
