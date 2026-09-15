const std = @import("std");

pub const SmartPort = struct {
    idx: usize,
    portNo: usize,

    pub fn smart(comptime portNo: usize) SmartPort {
        const src = @src();
        if (portNo == 0 or portNo > 21) @compileError(std.fmt.comptimePrint("[{s}:{d}:{d}]: Invalid port '{d}', port must be a valid SmartPort (1-21)", .{ src.file, src.line, src.column, portNo }));
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
