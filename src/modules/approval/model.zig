//! Agent 审批流（高危工具默认走人工）。
//!
//! 当 Agent 调用 `requires_approval=true` 的工具时，先落 AgentApproval（status=pending），
//! Run 状态为 `awaiting_approval`；用户在前端确认或拒绝后 Run 继续。

const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const AgentApproval = Schema("AgentApproval", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("run_id"),
        field.Int("agent_id"),
        field.String("tool_name"),
        field.String("payload").Default(""),
        field.Int("requested_at").Default(0),
        // decision: pending | approved | rejected | expired
        field.String("decision").Default("pending"),
        field.Int("decided_by").Default(0),
        field.Int("decided_at").Default(0),
        field.String("comment").Default(""),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});