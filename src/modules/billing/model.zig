//! Billing — 订阅 Plan / Invoice / Subscription。

const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const Plan = Schema("Plan", .{
    .fields = &.{
        field.String("code").Unique(),         // free | lite | pro | team
        field.String("name"),
        field.Int("monthly_price_cents").Default(0),
        field.Int("seat_limit").Default(1),
        field.Int("ai_token_monthly").Default(50000),
        field.String("feature_flags").Default("{}"),
        field.Bool("active").Default(true),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

pub const Subscription = Schema("Subscription", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("plan_id"),
        field.String("plan_code").Default("free"),
        // status: active | past_due | canceled | expired
        field.String("status").Default("active"),
        field.Int("started_at").Default(0),
        field.Int("period_end").Default(0),
        field.Bool("auto_renew").Default(true),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

pub const Invoice = Schema("Invoice", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("subscription_id").Default(0),
        field.Int("compute_order_id").Default(0),
        field.Int("amount_cents").Default(0),
        field.String("currency").Default("CNY"),
        // status: draft | issued | paid | void
        field.String("status").Default("draft"),
        field.String("pdf_url").Default(""),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});