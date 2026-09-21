const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "product",
    .description = "产品（PM）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}