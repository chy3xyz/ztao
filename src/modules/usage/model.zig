//! zent schema-as-code — 算力计量与配额告警。
//!
//! metric: ai_input_token | ai_output_token | tool_call | api_call | storage_gb

const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const UsageMeter = Schema("UsageMeter", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("user_id").Default(0),
        field.String("metric"),     // ai_input_token | ai_output_token | tool_call | api_call | storage_gb
        field.String("period"),     // 2026-09 | 2026-09-20
        field.Int("quantity").Default(0),
        field.String("unit").Default("count"),  // token | count | gb
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

pub const ComputeBalance = Schema("ComputeBalance", .{
    .fields = &.{
        field.Int("tenant_id").Unique(),
        field.Int("balance_tokens").Default(0),
        field.Int("period_end").Default(0),
        field.String("plan_code").Default("free"),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

pub const QuotaAlert = Schema("QuotaAlert", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.String("metric"),
        field.Int("threshold"),
        field.Int("fired_at").Default(0),
        field.Int("handled_at").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});