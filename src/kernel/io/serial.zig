const jmptbl = @import("jumptable");

const STDOUT: i32 = 1;

pub fn write(bytes: []const u8) void {
    _ = jmptbl.vexSerialWriteBuffer(STDOUT, @constCast(bytes.ptr), bytes.len);
}
