//! ZigModu module `fan_identity` — 用户身份绑定（openid/unionid）。
const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "fan_identity",
    .description = "用户跨平台身份绑定（小程序 / H5 / Apple / Email）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}