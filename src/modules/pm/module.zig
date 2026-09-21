const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "pm",
    .description = "PM BFF（产品/项目/需求/任务/Bug）",
    .dependencies = &.{},
    .is_internal = false,
};

pub fn init() !void {}
pub fn deinit() void {}