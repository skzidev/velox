//! VEX V5 controller (gamepad) (§14).
//!
//! Raw channels are read with a single `vexControllerGet` per query.
//! Edge-state queries (`justPressed`, `pressedMillis`, `clickCount`)
//! advance this instance's poll state: call them once per main-loop
//! iteration (every ≥100 ms) to get `justPressed` report-once semantics.
//! The button-to-channel mapping (§14.1) and axis assignment (§14.2)
//! follow the layout used by PROS; mapping is pinned on hardware.
//! Device-time readings are in whole milliseconds since the brain
//! powered on.

const std = @import("std");

const jmptbl = @import("velox_jumptable");
const types = jmptbl.types;

/// Which controller this instance addresses.
pub const Id = enum(u2) {
    master,
    partner,

    fn toNative(self: Id) types.V5_ControllerId {
        return switch (self) {
            .master => .kControllerMaster,
            .partner => .kControllerPartner,
        };
    }
};

/// 12 digital buttons on the controller face, in logical order.
pub const Button = enum(u4) {
    a,
    b,
    x,
    y,
    up,
    down,
    left,
    right,
    l1,
    l2,
    r1,
    r2,

    fn toNative(self: Button) types.V5_ControllerIndex {
        return switch (self) {
            .a => .Button8D,
            .b => .Button8R,
            .x => .Button8U,
            .y => .Button8L,
            .up => .Button7U,
            .down => .Button7D,
            .left => .Button7L,
            .right => .Button7R,
            .l1 => .Button5U,
            .l2 => .Button5D,
            .r1 => .Button6U,
            .r2 => .Button6D,
        };
    }
};

/// The two analog joysticks, canonical order.
pub const Axis = enum(u2) {
    axis1,
    axis2,
    axis3,
    axis4,

    fn toNative(self: Axis) types.V5_ControllerIndex {
        return switch (self) {
            .axis1 => .AnaLeftX,
            .axis2 => .AnaLeftY,
            // Right stick: X and Y are swapped on the controller.
            .axis3 => .AnaRightY,
            .axis4 => .AnaRightX,
        };
    }
};

const button_count = 12;

const all_buttons = [_]Button{ .a, .b, .x, .y, .up, .down, .left, .right, .l1, .l2, .r1, .r2 };

/// A gamepad handle with edge-state tracking.
pub const Controller = struct {
    id: Id,
    /// Bitmask snapshot of the 12 buttons from the last poll (bit i =
    /// the i-th entry of `all_buttons`).
    prev: u12 = 0,
    /// Press edges observed in the last poll, pending `justPressed`.
    rising: u12 = 0,
    press_start: [button_count]u32 = [_]u32{0} ** button_count,
    release_start: [button_count]u32 = [_]u32{0} ** button_count,
    click_count: [button_count]u32 = [_]u32{0} ** button_count,

    /// Create a controller handle for `id`.
    pub fn init(id: Id) Controller {
        return .{ .id = id };
    }

    /// True when the controller is physically connected.
    pub fn isConnected(self: *const Controller) bool {
        return jmptbl.controller.vexControllerConnectionStatusGet(self.id.toNative()) != .kV5ControllerOffline;
    }

    /// Current state of a digital button.
    pub fn button(self: *const Controller, comptime b: Button) bool {
        return jmptbl.controller.vexControllerGet(self.id.toNative(), b.toNative()) != 0;
    }

    /// Normalized joystick position, [-1, 1]. The hardware reports raw
    /// counts in [-127, 127]; the read is clamped to that range before
    /// normalization.
    pub fn axis(self: *const Controller, comptime a: Axis) f64 {
        const raw: f64 = @floatFromInt(jmptbl.controller.vexControllerGet(self.id.toNative(), a.toNative()));
        return std.math.clamp(raw / 127.0, -1.0, 1.0);
    }

    /// Edge state: true for exactly one poll after `b` goes from released
    /// to pressed. Advances this instance's poll state.
    pub fn justPressed(self: *Controller, comptime b: Button) bool {
        self.poll();
        const bit = bitOf(b);
        const result = (self.prev & bit) != 0 and (self.rising & bit) != 0;
        self.rising &= ~bit;
        return result;
    }

    /// Edge state: milliseconds since `b` was last pressed while it is
    /// currently held; 0 while released. Advances poll state.
    pub fn pressedMillis(self: *Controller, comptime b: Button) u32 {
        self.poll();
        const bit = bitOf(b);
        if ((self.prev & bit) == 0) return 0;
        return nowMs() -% self.press_start[@intFromEnum(b)];
    }

    /// Edge state: milliseconds since `b` was last released while it is
    /// currently released; 0 while held. Advances poll state.
    pub fn releaseMillis(self: *Controller, comptime b: Button) u32 {
        self.poll();
        const bit = bitOf(b);
        if ((self.prev & bit) != 0) return 0;
        return nowMs() -% self.release_start[@intFromEnum(b)];
    }

    /// Edge state: number of `b` release edges seen so far. Advances poll
    /// state.
    pub fn clickCount(self: *Controller, comptime b: Button) u32 {
        self.poll();
        return self.click_count[@intFromEnum(b)];
    }

    /// Snapshot the 12 buttons once, diff against the previous poll, and
    /// update press/release timestamps and click counts.
    pub fn poll(self: *Controller) void {
        const now = nowMs();
        const curr = self.snapshot();
        const pressed = curr & ~self.prev;
        const released = ~curr & self.prev;
        self.rising = pressed;
        self.prev = curr;
        inline for (all_buttons, 0..) |_, i| {
            const bit: u12 = @as(u12, 1) << @intCast(i);
            if ((pressed & bit) != 0) self.press_start[i] = now;
            if ((released & bit) != 0) {
                self.release_start[i] = now;
                self.click_count[i] +%= 1;
            }
        }
    }

    fn snapshot(self: *const Controller) u12 {
        var mask: u12 = 0;
        const id = self.id.toNative();
        inline for (all_buttons, 0..) |btn, i| {
            if (jmptbl.controller.vexControllerGet(id, btn.toNative()) != 0)
                mask |= @as(u12, 1) << @intCast(i);
        }
        return mask;
    }
};

fn bitOf(b: Button) u12 {
    return @as(u12, 1) << @intCast(@intFromEnum(b));
}

fn nowMs() u32 {
    return @intCast(jmptbl.system.vexSystemHighResTimeGet() / 1000);
}
