const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "approval",
    .description = "Agent 工具调用审批流",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}