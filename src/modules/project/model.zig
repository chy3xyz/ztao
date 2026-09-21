const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const Project = Schema("Project", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("product_id").Default(0),
        field.String("name"),
        field.String("code").Default(""),
        // type: internal | external 内外项目
        field.String("type").Default("internal"),
        // status: wait | doing | suspended | closed | done
        field.String("status").Default("wait"),
        // model: scrum | kanban | waterfall | empty
        field.String("model").Default("scrum"),
        field.Int("parent_id").Default(0),       // 父子项目
        field.Int("begin").Default(0),
        field.Int("end").Default(0),
        field.Int("owner_id").Default(0),
        field.Int("budget_hours").Default(0),
        field.Bool("ai_enabled").Default(true),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});

pub const ProjectMember = Schema("ProjectMember", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("project_id"),
        field.Int("user_id"),
        field.String("role").Default("dev"),
        field.Int("joined_at").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});