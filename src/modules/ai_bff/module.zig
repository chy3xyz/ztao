const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "ai_bff",
    .description = "AI BFF（算力余额 / Agent 审批）",
    .dependencies = &.{},
    .is_internal = false,
};

pub fn init() !void {}
pub fn deinit() void {}