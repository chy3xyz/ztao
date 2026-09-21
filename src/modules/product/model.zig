//! zent schema-as-code — 产品（沿用禅道命名）。
//!
//! acl: open | private | custom
//! status: active | closed | archived

const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const Product = Schema("Product", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.String("name"),
        field.String("code").Default(""),
        field.String("type").Default("normal"),     // normal | multi
        field.String("status").Default("active"),  // active | closed | archived
        field.Int("owner_id").Default(0),
        field.String("description").Default(""),
        field.String("acl").Default("open"),        // open | private | custom
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

/// 产品计划（产品路线图 / 版本节点）
pub const ProductPlan = Schema("ProductPlan", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("product_id"),
        field.String("title"),
        field.Int("begin").Default(0),
        field.Int("end").Default(0),
        field.String("status").Default("planned"),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});