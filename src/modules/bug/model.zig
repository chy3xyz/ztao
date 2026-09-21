const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const Bug = Schema("Bug", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("product_id").Default(0),
        field.Int("project_id").Default(0),
        field.String("title"),
        // severity: 1=致命 2=严重 3=一般 4=轻微
        field.Int("severity").Default(3),
        // type: code | data | interface | config | security | performance | standard | automation | design | other
        field.String("type").Default("code"),
        field.String("steps").Default(""),
        // status: active | resolved | closed
        field.String("status").Default("active"),
        field.Int("resolved_by").Default(0),
        field.Int("resolved_at").Default(0),
        // resolution: bydesign | duplicate | external | notrepro | fixed | postponed | wontfix
        field.String("resolution").Default(""),
        field.Int("build_id").Default(0),
        field.Int("assigned_to").Default(0),
        field.Int("opened_by").Default(0),
        field.String("ai_triage").Default(""),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});