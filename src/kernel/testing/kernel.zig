//! # Kernel tests
//!
//! Tests for the kernel runtime itself: the build manifest version, the
//! banner's formatted version string, and user-program validation.
//! These run on the actual V5 hardware via the test runner.

const std = @import("std");
const assert = @import("../testing.zig").assert;
const sdk = @import("velox_sdk");
const banner = @import("../banner.zig");
const validation = @import("../validation.zig");
const manifest = @import("manifest");

test "kernel_manifest_version_parses" {
    // The build.zig.zon version must be valid semver for the build to
    // succeed at all; this pins that property in the test suite.
    const parsed = try std.SemanticVersion.parse(manifest.version);
    try assert(parsed.major >= 0);
}

test "kernel_banner_version_matches_manifest" {
    // The banner renders `major.minor.patch` from the manifest; with no
    // prerelease/build metadata the strings must be identical.
    try assert(std.mem.eql(u8, manifest.version, banner.VeloxVersionAsString));
}

test "kernel_banner_version_parses" {
    // The rendered version string must itself be valid semver.
    const parsed = try std.SemanticVersion.parse(banner.VeloxVersionAsString);
    try assert(parsed.major >= 0 and parsed.minor >= 0 and parsed.patch >= 0);
}

const MainReturningVoid = struct {
    pub fn main(_: sdk.Init) void {}
};

const MainReturningError = struct {
    pub fn main(_: sdk.Init) !void {}
};

const MainReturningValue = struct {
    pub fn main(_: sdk.Init) !u8 {
        return 1;
    }
};

test "kernel_validate_user_program_accepts_valid_shapes" {
    // A plain `main(init)` — returning value, error union, or void — must
    // pass the kernel's comptime user-program validation.
    comptime {
        validation.validateUserProgram(MainReturningVoid);
        validation.validateUserProgram(MainReturningError);
        validation.validateUserProgram(MainReturningValue);
    }
}
