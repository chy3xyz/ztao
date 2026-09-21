//! 小程序 BFF 模块（`/api/v1/mp/*`）。
const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "mp",
    .description = "微信小程序 BFF（登录 + 一人公司引导 + AI 入口）",
    .dependencies = &.{},
    .is_internal = false,
};

pub fn init() !void {}
pub fn deinit() void {}