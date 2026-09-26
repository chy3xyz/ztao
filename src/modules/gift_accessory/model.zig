//! 礼品商城 + 配件商城（M5）。
//!
//! 复用 ztao ComputePackage 模式：商品 + 订单。
//! kind: gift | accessory

const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const Product = Schema("MallProduct", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        // kind: gift | accessory
        field.String("kind"),
        field.String("code").Unique(),
        field.String("name"),
        field.String("description").Default(""),
        field.String("image").Default(""),
        field.Int("price_cents").Default(0),
        field.Int("original_price_cents").Default(0),
        field.Int("stock").Default(0),
        field.Int("sales").Default(0),
        // status: on | off
        field.String("status").Default("on"),
        // 可选 category 字符串（"咖啡 / 礼盒 / 显示器 / 键盘"）
        field.String("category").Default(""),
        // reward_points: 礼品类兑换所需积分（可选）
        field.Int("reward_points").Default(0),
        field.Int("sort").Default(100),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

pub const Order = Schema("ProductOrder", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("user_id"),
        field.String("kind"),
        field.String("product_code").Default(""),
        field.Int("quantity").Default(1),
        field.Int("amount_cents").Default(0),
        field.String("receiver_name").Default(""),
        field.String("receiver_phone").Default(""),
        field.String("address").Default(""),
        field.String("status").Default("pending"),  // pending | paid | shipped | closed
        field.String("tracking_no").Default(""),
        field.Int("paid_at").Default(0),
        field.Int("shipped_at").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});