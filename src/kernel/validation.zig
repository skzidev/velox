//! User program validation
const std = @import("std");
const sdk = @import("velox_sdk");

/// Ensures that the user program provides all of the things which it needs to (main and ports)
pub fn validateUserProgram(comptime mod: anytype) void {
    // validate decls exist
    if (!@hasDecl(mod, "main"))
        @compileError("User code must provide main.");
    // validate main
    // TODO maybe don't require an error union?
    const fnInfo = @typeInfo(@TypeOf(mod.main)).@"fn";
    //const return_type = fnInfo.return_type orelse @compileError("main should return a void error union");

    if (fnInfo.params.len < 1 or fnInfo.params[0].type != sdk.Init)
        @compileError("main should accept a juicy main");
}

test "valid_program" {
    const exampleModule = struct {
        pub fn main(_: sdk.Init) !void {}
    };
    comptime validateUserProgram(exampleModule);
}
