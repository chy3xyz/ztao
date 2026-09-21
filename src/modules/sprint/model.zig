const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const Sprint = Schema("Sprint", .{
    .fields = &.{
        field.Int("tenant_id").Default(1),
        field.Int("project_id"),
        field.String("name"),
        field.String("goal").Default(""),
        field.Int("begin").Default(0),
        field.Int("end").Default(0),
        // status: planned | active | closed
        field.String("status").Default("planned"),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});