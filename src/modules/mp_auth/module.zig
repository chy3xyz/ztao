//! Stub module 名字，让 src/modules/mp_auth/ 存在可识别的文件。
//! 真正的中间件在 src/middleware/mp_auth.zig。
const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "mp_auth",
    .description = "小程序鉴权中间件（占位）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}