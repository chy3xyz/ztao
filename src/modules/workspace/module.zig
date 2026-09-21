//! ZigModu module `workspace` — one-person-company workspace container.
const zigmodu = @import("zigmodu");

pub const info = zigmodu.api.Module{
    .name = "workspace",
    .description = "Workspace（一人公司 默认 workspace，未来支持多团队）",
    .dependencies = &.{},
    .is_internal = true,
};

pub fn init() !void {}
pub fn deinit() void {}