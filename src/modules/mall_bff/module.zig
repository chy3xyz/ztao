const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "mall_bff",
    .description = "商城 BFF（算力 / 礼品 / 配件）",
    .dependencies = &.{},
    .is_internal = false,
};

pub fn init() !void {}
pub fn deinit() void {}