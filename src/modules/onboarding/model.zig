//! zent schema-as-code — 引导状态机。
//!
//! step 取值顺序：login → workspace → agents_ready → first_chat → first_task → done

const zent = @import("zent");
const field = zent.core.field;
const Schema = zent.core.schema.Schema;

pub const OnboardingState = Schema("OnboardingState", .{
    .fields = &.{
        field.Int("user_id").Unique(),
        field.String("step").Default("login"),
    },
    .mixins = &.{zent.core.mixin.TimeMixin},
});