const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const PmsTaskRow = persist.PmsTaskRow;
pub const PmsTaskListResult = persist.PmsTaskListResult;

pub const PmsTaskError = error{
    InvalidName,
    InvalidStatus,
    Unexpected,
};

pub const PmsTaskService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.PmsTaskStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.PmsTaskStore) PmsTaskService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *PmsTaskService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn create(self: *PmsTaskService, tenant_id: i64, project_id: i64, sprint_id: i64, story_id: i64, name: []const u8, pri: i64, estimate: f64, assigned_to: i64, assignee_kind: []const u8, ai_assisted: bool) PmsTaskError!i64 {
        const trimmed = std.mem.trim(u8, name, " \t");
        if (trimmed.len == 0) return error.InvalidName;
        return self.store.create(.{
            .tenant_id = tenant_id, .project_id = project_id,
            .sprint_id = sprint_id, .story_id = story_id,
            .name = trimmed, .pri = pri, .estimate = estimate, .left = estimate,
            .assigned_to = assigned_to, .assignee_kind = assignee_kind,
            .ai_assisted = ai_assisted,
        }, self.now()) catch error.Unexpected;
    }

    pub fn get(self: *PmsTaskService, tenant_id: i64, id: i64) PmsTaskError!?PmsTaskRow {
        return self.store.getById(tenant_id, id) catch error.Unexpected;
    }

    pub fn listByProject(self: *PmsTaskService, tenant_id: i64, project_id: i64, page: usize, page_size: usize) PmsTaskError!PmsTaskListResult {
        return self.store.listByProject(tenant_id, project_id, page, page_size) catch error.Unexpected;
    }

    pub fn listAssignedTo(self: *PmsTaskService, tenant_id: i64, user_id: i64, page: usize, page_size: usize) PmsTaskError!PmsTaskListResult {
        return self.store.listAssignedTo(tenant_id, user_id, page, page_size) catch error.Unexpected;
    }

    pub fn updateStatus(self: *PmsTaskService, tenant_id: i64, id: i64, status: []const u8, finished_by: i64) PmsTaskError!bool {
        const valid = std.mem.eql(u8, status, "wait") or
            std.mem.eql(u8, status, "doing") or
            std.mem.eql(u8, status, "done") or
            std.mem.eql(u8, status, "closed") or
            std.mem.eql(u8, status, "cancel");
        if (!valid) return error.InvalidStatus;
        return self.store.updateStatus(tenant_id, id, status, finished_by, self.now()) catch error.Unexpected;
    }

    pub fn logTime(self: *PmsTaskService, tenant_id: i64, id: i64, hours: f64) PmsTaskError!bool {
        if (hours < 0) return error.InvalidStatus;
        return self.store.logTime(tenant_id, id, hours, self.now()) catch error.Unexpected;
    }
};