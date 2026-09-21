const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "project",
    .description = "项目 + 成员（PM）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}