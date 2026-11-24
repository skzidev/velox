/// CPU register context struct.
pub const CpuContext = extern struct {
    r4: u32,
    r5: u32,
    r6: u32,
    r7: u32,
    r8: u32,
    r9: u32,
    r10: u32,
    r11: u32,

    lr: u32,
    sp: u32,
};

/// Fiber state enum.
pub const FiberState = enum {
    ready,
    running,
    blocked,
    finished,
};

/// Fiber struct
pub const Fiber = struct {
    ctx: *CpuContext,
    priority: u8,
    stack: []u8,
    task: *const fn () void,
};
