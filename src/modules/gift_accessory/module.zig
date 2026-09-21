const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "gift_accessory",
    .description = "礼品商城 + 配件商城（M5）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}