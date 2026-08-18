//! # Mock user code
//! Provides all of the utilities
//! **This does not get shipped when users install the package**

const velox = @import("velox_sdk");

pub const ports = @import("ports.zon");

pub fn main(init: velox.Init(ports)) !void {
    _ = init.devices;
    while (true) {}
    return 0;
}
