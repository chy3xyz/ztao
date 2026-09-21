//! zent schema-as-code — 算力商城（商品 + 订单）。

const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

/// 算力包商品
pub const ComputePackage = Schema("ComputePackage", .{
    .fields = &.{
        field.String("code").Unique(),
        field.String("name"),
        field.String("description").Default(""),
        field.Int("tokens").Default(0),
        field.Int("valid_days").Default(30),
        field.Int("price_cents").Default(0),
        field.Int("bonus_tokens").Default(0),
        field.String("kind").Default("month"),    // month | year | team | custom
        field.Int("seat").Default(1),
        field.Bool("active").Default(true),
        field.Int("sort").Default(100),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

/// 算力订单（待支付 / 已支付 / 已关闭）
pub const ComputeOrder = Schema("ComputeOrder", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("user_id"),
        field.Int("package_id"),
        field.String("package_code").Default(""),
        field.Int("amount_cents").Default(0),
        // status: pending | paid | closed | refunded
        field.String("status").Default("pending"),
        // channel: wechat | alipay | admin
        field.String("channel").Default("wechat"),
        field.String("external_id").Default(""),
        field.Int("paid_at").Default(0),
        field.Int("granted_tokens").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});