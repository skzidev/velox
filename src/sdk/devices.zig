const std = @import("std");

var ports = std.mem.zeroes([21]bool);

pub const DevPoolAccessError = error{
    InvalidPort,
    AlreadyUsed,
    AlreadyUnused,
};

pub fn claim(idx: usize) DevPoolAccessError!void {
    if (isClaimed(idx)) return DevPoolAccessError.AlreadyUsed;
    ports[idx] = true;
}

pub fn unclaim(idx: usize) DevPoolAccessError!void {
    if (!isClaimed(idx)) return DevPoolAccessError.AlreadyUnused;
    ports[idx] = false;
}

pub fn isClaimed(idx: usize) bool {
    return ports[idx];
}
