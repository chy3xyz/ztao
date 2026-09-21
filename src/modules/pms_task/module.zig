const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "pms_task",
    .description = "PM 任务（与 task 后台队列隔离）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}