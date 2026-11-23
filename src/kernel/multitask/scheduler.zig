const std = @import("std");
const jmptbl = @import("jumptable");

const fiber = @import("./fiber.zig");
const Fiber = fiber.Fiber;

extern fn switchTaskCtx(old: *fiber.CpuContext, new: *fiber.CpuContext) noreturn;

pub const Scheduler = struct {
    tasks: std.ArrayList(Fiber),
    allocator: std.mem.Allocator,
    current: *fiber.CpuContext,

    pub fn init(gpa: std.mem.Allocator) Scheduler {
        return .{
            .tasks = .empty,
            .allocator = gpa,
        };
    }

    pub fn runTasks(self: *const Scheduler) void {
        for (self.tasks.items) |task| {
            switchTaskCtx(self.current, &task.ctx);
        }
    }

    pub fn spawn(self: *const Scheduler, priority: u8) !Fiber {
        const task = Fiber{
            .ctx = try self.allocator.create(fiber.CpuContext),
            .priority = priority,
            .stack = try self.allocator.alloc(u8, 255),
        };
        try self.tasks.addOne(task);
        return task;
    }
};
