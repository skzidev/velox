const jmptbl = @import("jumptable");
const codeRoot = @import("code_root");
const comp = @import("io/competition.zig");

pub fn vmain() callconv(.c) i32 {
    while (true) {
        jmptbl.vexTaskSleep(2);
    }
    return 0;
}
