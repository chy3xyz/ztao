const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const Task = Schema("PmsTask", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("project_id").Default(0),
        field.Int("sprint_id").Default(0),
        field.Int("story_id").Default(0),
        field.Int("parent_id").Default(0),
        field.String("name"),
        field.String("kind").Default("task"),  // task | design | devel | test | study
        field.Int("pri").Default(3),
        field.Float("estimate").Default(0),       // 预估工时
        field.Float("consumed").Default(0),       // 已消耗
        field.Float("left").Default(0),           // 剩余
        // status: wait | doing | done | closed | cancel
        field.String("status").Default("wait"),
        field.Int("assigned_to").Default(0),
        // assignee_kind: user | agent
        field.String("assignee_kind").Default("user"),
        field.Int("finished_by").Default(0),
        field.Int("finished_at").Default(0),
        field.Bool("ai_assisted").Default(false),
        field.Int("agent_run_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});