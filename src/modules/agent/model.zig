//! zent schema-as-code — AI Agent 模板与实例（M1）。
//!
//! 设计：
//! - `AgentPreset` 是平台级预置模板（pm / dev / qa / support / ops），全平台共用
//! - `AgentInstance` 是 user 维度实例，源自某个 Preset，可改名/调参/启停
//! - `AgentMemory` 简单 KV（M4 加向量）

const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

/// 平台预置模板。seed by `seed.zig`。
pub const AgentPreset = Schema("AgentPreset", .{
    .fields = &.{
        // 业务唯一 code: pm / dev / qa / support / ops ...
        field.String("code").Unique(),
        field.String("name"),
        field.String("avatar").Default(""),
        field.String("kind").Default(""),
        field.String("system_prompt").Default(""),
        field.String("tools").Default("[]"),
        field.String("capabilities").Default("[]"),
        field.String("scopes").Default("[]"),
        field.Bool("is_default").Default(false),
        field.Int("sort").Default(100),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

/// 用户拥有的 Agent 实例（一人公司启动时自动注入 5 个 Preset）。
pub const AgentInstance = Schema("AgentInstance", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("user_id"),
        field.Int("preset_id").Default(0),
        field.String("preset_code").Default(""),
        field.String("name"),
        field.String("avatar").Default(""),
        field.String("model").Default("stub"),
        field.String("tools_override").Default(""),
        field.String("scopes_override").Default(""),
        // status: active | paused | deleted
        field.String("status").Default("active"),
        field.String("memory_policy").Default("session"),
        field.Int("max_daily_cost_cents").Default(5000),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

/// M1 用 JSON 字符串存值；M4 切到向量。
pub const AgentMemory = Schema("AgentMemory", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("agent_id"),
        field.Int("project_id").Default(0),
        field.String("key"),
        field.String("value").Default(""),
        // source: user | agent | auto
        field.String("source").Default("user"),
        field.Int("ttl").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});