const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const Story = Schema("Story", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("product_id").Default(0),
        field.Int("project_id").Default(0),
        field.String("title"),
        field.String("spec").Default(""),
        // pri: 1 | 2 | 3 | 4
        field.Int("pri").Default(3),
        // status: draft | active | closed
        field.String("status").Default("draft"),
        // stage: wait | planned | projected | developing | developed | testing | tested | verified | released | closed
        field.String("stage").Default("wait"),
        // source: customer | market | user | competitor | service | support | dev | qa | boss | partner | other
        field.String("source").Default("user"),
        field.String("category").Default("feature"),
        field.Float("estimate").Default(0),
        field.Int("parent_id").Default(0),
        field.String("keywords").Default(""),
        field.Int("assigned_to").Default(0),
        field.Int("opened_by").Default(0),
        field.Bool("ai_assisted").Default(false),
        field.Int("ai_prompt_id").Default(0),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});