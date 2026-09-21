const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "compute",
    .description = "算力商城（商品 + 订单）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}