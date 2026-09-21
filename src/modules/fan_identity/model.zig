//! zent schema-as-code — 跨平台用户身份绑定。
//!
//! 一对多：一个 User 可绑定多个 openid（小程序 / H5 / 公众号 / Apple / 邮箱）。
//! M1 重点是 `wechat-mp`。

const zent = @import("zent");
const field = zent.core.field;
const index = zent.core.index;
const Schema = zent.core.schema.Schema;

pub const UserIdentity = Schema("UserIdentity", .{
    .fields = &.{
        field.Int("user_id"),
        // channel: wechat-mp | wechat-h5 | apple | email
        field.String("channel"),
        field.String("openid"),
        field.String("unionid").Default(""),
        field.String("appid").Default(""),
        field.String("encrypted_session_key").Default("").Sensitive(),
    },
    .indexes = &.{
        // 一个 (channel, appid, openid) 只对应一个 user
        index.Fields(&.{ "channel", "appid", "openid" }).Unique(),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});