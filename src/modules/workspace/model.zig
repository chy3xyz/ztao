//! zent schema-as-code — Workspace (一人公司 默认 workspace；未来支持多团队).
//!
//! 一个 Tenant 默认有 1 个 kind='solo' 的 Workspace；
//! 切到 Team/Enterprise 模式后可创建多个 Workspace。
//! `owner_user_id` 是该 Workspace 的"创始人"。

const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const Workspace = Schema("Workspace", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.String("name"),
        // code: solo | team | enterprise
        field.String("kind").Default("solo"),
        field.Int("owner_user_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});