const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "billing",
    .description = "订阅 / 计划 / 发票",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}