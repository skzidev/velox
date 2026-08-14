//! # Banner and Version
//! This file contains the version and the banner which is printed on bootup

const std = @import("std");
const jmptbl = @import("velox_jumptable");
const builtin = @import("builtin");

const VeloxVersion: std.SemanticVersion = .{
    .major = 0,
    .minor = 0,
    .patch = 0,
};
const VeloxVersionAsString = std.fmt.comptimePrint("{d}.{d}.{d}", .{ VeloxVersion.major, VeloxVersion.minor, VeloxVersion.patch });

pub const banner =
    \\                                                    _——
    \\                                                 _*"/'
    \\ ¸___________             _____________________#__/"
    \\  =„.       ¹#            h           _/.      .d=
    \\   "\        '\¸          h          #"       ./"
    \\     \_        =L         h        _/        _/
    \\      ¹#        '\.       ¹———————="        #"
    \\       '\¸        \_            ¸/'       ¸/.
    \\         =L        ¹#          d=        /=
    \\          '\.       .\¸      ¸/'       ¸/'
    \\            #_        ¹L    d¹        d¹
    \\             ¹\        '\../'       ./"
    \\              .\¸        ==        _/.
    \\                ¹\                #""""""""][
    \\                 '\¸            ¸/.        ][
    \\                   ¹„          d=          ][
    \\                    "—————————ƒ—————————————[
    \\                          / /"
    \\                        ¸//"
    \\                       ¸="
    \\
;

pub fn printBanner() void {
    _ = jmptbl.serial.vexSerialWriteBuffer(1, @constCast(banner), banner.len);
    const dataline = "Welcome to Velox v" ++ VeloxVersionAsString ++ ". Running on Zig " ++ builtin.zig_version_string ++ ".\n";
    _ = jmptbl.serial.vexSerialWriteBuffer(1, @constCast(dataline), dataline.len);
}
