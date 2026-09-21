//! ZigModu module `onboarding` — 一人公司引导状态机。
const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "onboarding",
    .description = "一人公司引导状态机",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}