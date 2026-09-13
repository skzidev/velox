const std = @import("std");

var ports = std.mem.zeroes([21]bool);

pub const DevPoolAccessError = error{
    InvalidPort,
};

pub fn claim(idx: usize) DevPoolAccessError!void {
    ports[idx] = true;
}

pub fn unclaim(idx: usize) DevPoolAccessError!void {
    ports[idx] = false;
}

pub fn isClaimed(idx: usize) DevPoolAccessError!bool {
    return ports[idx];
}
