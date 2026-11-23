const std = @import("std");
const jmptbl = @import("jumptable");

const fiber = @import("./fiber.zig");
const Fiber = fiber.Fiber;

/// Task switching subroutine
extern fn _velox_task_switch(
    old: *fiber.CpuContext,
    new: *fiber.CpuContext,
) callconv(.{ .arm_aapcs = .{} }) noreturn;

fn cmpFiberPriorities(context: Fiber, item: Fiber) std.math.Order {
    return std.math.order(context.priority, item.priority);
}

/// Cooperative fiber scheduler.
pub const Scheduler = struct {
    rootCtx: fiber.CpuContext,
    tasks: std.ArrayList(Fiber),

    pub fn init() Scheduler {
        return .{
            .tasks = .empty,
            .rootCtx = undefined,
        };
    }

    pub fn runTasks(self: *const Scheduler) void {
        for (self.tasks.items) |task| {
            _velox_task_switch(&self.rootCtx, task.ctx);
        }
    }

    pub fn spawn(
        self: *const Scheduler,
        allocator: std.mem.Allocator,
    ) !void {
        _ = self;
        _ = allocator;
    }

    fn add(self: *const Scheduler, task: Fiber) !usize {
        const idx = std.sort.lowerBound(Fiber, self.tasks.items, task, cmpFiberPriorities);
        try self.tasks.insert(idx, task);
        return idx;
    }
};
