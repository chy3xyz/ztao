const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "sprint",
    .description = "迭代 / 冲刺（PM）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}