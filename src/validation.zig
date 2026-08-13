//! User program validation

pub fn validateUserProgram(comptime mod: anytype) void {
    if (!@hasDecl(mod, "main"))
        @compileError("User code must provide main.");
    const return_type = @typeInfo(@TypeOf(mod.main)).@"fn".return_type orelse @compileError("main should return an error union");
    switch (@typeInfo(return_type)) {
        .error_union, .error_set => return,
        else => @compileError("main should return an error union"),
    }
}
