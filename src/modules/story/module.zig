const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "story",
    .description = "需求 / 用户故事（PM）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}