//! ZigModu module `agent` — AI Agent 模板与实例。
const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "agent",
    .description = "AI Agent（pm / dev / qa / support / ops）模板与实例",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}