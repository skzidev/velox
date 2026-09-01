//! # Test Runner Shim
//!
//! Minimal runtime for the on-hardware test runner. Provides:
//!
//! - A fixed-buffer page allocator (64 KB) that overrides
//!   `std.heap.page_allocator`.
//! - An empty `panic` handler that spins forever (tests that panic
//!   will hang the brain).
//! - Empty `main` (the real entry point is `runner.zig`).
//!
//! This file is used as the `--test-runner` argument to `zig build test`.

const std = @import("std");

pub const std_options = std.Options{
    .page_size_max = 4096,
    .page_size_min = 4096,
    .networking = false,
};

/// 64 KB buffer backing the page allocator.
var page_buf: [1024 * 64]u8 = undefined;
/// Fixed-buffer allocator initialized over `page_buf`.
var page_fba = std.heap.FixedBufferAllocator.init(&page_buf);

/// Overrides the default `std.heap.page_allocator` with a fixed-buffer
/// allocator. This avoids the need for a full heap on the test runner.
pub const os = struct {
    pub const heap = struct {
        pub const page_allocator = page_fba.allocator();
    };
};

/// Panic handler for the test runner. Spins forever — tests that
/// trigger a panic will hang the brain until power-cycled.
pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}

/// Empty main — the real entry point is `runner.zig`.
pub fn main() void {}
