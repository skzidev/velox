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
    allocator: std.mem.Allocator,

    const Self = *Scheduler;

    pub fn init(gpa: std.mem.Allocator) Scheduler {
        return .{
            .tasks = .empty,
            .rootCtx = undefined,
            .allocator = gpa,
        };
    }

    pub fn deinit(self: Self) void {
        for (self.tasks.items) |task| {
            self.allocator.destroy(task.ctx);
        }
    }

    pub fn runTasks(self: Self) void {
        for (self.tasks.items) |task| {
            _velox_task_switch(&self.rootCtx, task.ctx);
        }
    }

    pub fn spawn(
        self: Self,
        func: *const fn () void,
        priority: u8,
    ) !void {
        const task = Fiber{
            .ctx = try self.allocator.create(fiber.CpuContext),
            .priority = priority,
            .stack = try self.allocator.alloc(u8, 255),
            .task = func,
        };
        _ = try self.add(task);
    }

    fn add(self: Self, task: Fiber) !usize {
        const idx = std.sort.lowerBound(
            Fiber,
            self.tasks.items,
            task,
            cmpFiberPriorities,
        );
        try self.tasks.insert(self.allocator, idx, task);
        return idx;
    }
};
