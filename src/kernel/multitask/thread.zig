const jmptbl = @import("jumptable");

pub const Thread = struct {
    idx: u32,
    interval: i32,
    callback: *const fn () callconv(.c) i32,

    pub fn init(callback: *const fn () callconv(.c) i32, interval: i32, label: [:0]const u8) Thread {
        const idx = jmptbl.vexTaskAdd(
            callback,
            interval,
            label.ptr,
        );
        return Thread{
            .idx = idx,
            .interval = interval,
            .callback = callback,
        };
    }
};
