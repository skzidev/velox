//! User program validation
const std = @import("std");
const sdk = @import("velox_sdk");

fn validatePortDef(comptime pd: anytype) void {
    if (!@hasDecl(pd, "port") or !@TypeOf(pd.port) != i32 or (pd.port < 1 or pd.port > 21))
        @compileError("Port definitions must have an i32 'port' value between 1 and 21");
}

/// Ensures that the user program provides all of the things which it needs to (main and ports)
pub fn validateUserProgram(comptime mod: anytype) void {
    // validate decls exist
    if (!@hasDecl(mod, "main"))
        @compileError("User code must provide main.");
    if (!@hasDecl(mod, "ports"))
        @compileError("User code must provide a `ports` config struct");
    // validate main
    const fnInfo = @typeInfo(@TypeOf(mod.main)).@"fn";
    const return_type = fnInfo.return_type orelse @compileError("main should return a void error union");

    if (fnInfo.params.len < 1 or fnInfo.params[0].type != sdk.Init(mod.ports))
        @compileError("main should accept a juicy main");
    switch (@typeInfo(return_type)) {
        .error_union, .error_set => return,
        else => @compileError("main should return a void error union"),
    }
    // validate ports
    const ports = mod.ports;
    inline for (std.meta.fields(@TypeOf(ports))) |field| {
        validatePortDef(@field(ports, field.name));
    }
}
