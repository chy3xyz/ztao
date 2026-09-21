const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "usage",
    .description = "算力计量与配额",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}