//! User program validation

pub fn validateUserProgram(mod: anytype) void {
    if (!@hasDecl(mod, "main"))
        @compileError("User code must provide main.");
}
