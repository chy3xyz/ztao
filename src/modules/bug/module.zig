const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "bug",
    .description = "Bug / 缺陷（PM）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}