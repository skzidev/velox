const jmptbl = @import("jumptable");
const codeRoot = @import("code_root");

pub fn vmain() callconv(.c) i32 {
    jmptbl.vexDisplayCircleFill(100, 100, 50);
    return 0;
}
