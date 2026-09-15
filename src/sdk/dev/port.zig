const std = @import("std");

pub const SmartPort = struct {
    idx: usize,
    portNo: usize,

    pub fn smart(comptime portNo: usize) SmartPort {
        if (portNo == 0 or portNo > 21) @compileError(std.fmt.comptimePrint("Invalid port '{d}', port must be 1-21", .{portNo}));
        return .{
            .idx = portNo - 1,
            .portNo = portNo,
        };
    }
};

pub const ADIPort = struct {
    expander: usize,
    portNo: usize,

    pub fn adi(comptime expander: usize, comptime portNo: usize) ADIPort {
        return .{
            .expander = expander,
            .portNo = portNo,
        };
    }
};
