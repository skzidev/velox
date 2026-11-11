const jmptbl = @import("jumptable");

pub fn vmain() callconv(.c) i32 {
    jmptbl.vexDisplayCircleFill(100, 100, 50);
    return 0;
}
