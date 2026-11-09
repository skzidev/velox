const umm = @import("umm");
const std = @import("std");
const codeRoot = @import("code_root");

export fn velox_startup() noreturn {
    while (true) {}
}

pub const std_options = std.Options{
    .networking = false,
    .page_size_max = 4096,
    .page_size_min = 4096,
};

pub const os = struct {
    pub const heap = struct {
        //pub const page_allocator = umm.
    };
};
