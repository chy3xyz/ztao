const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const AgentApprovalRow = persist.AgentApprovalRow;
pub const ApprovalListResult = persist.ApprovalListResult;

pub const ApprovalService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.ApprovalStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.ApprovalStore) ApprovalService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *ApprovalService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn request(self: *ApprovalService, tenant_id: i64, run_id: i64, agent_id: i64, tool_name: []const u8, payload: []const u8) !i64 {
        return self.store.create(.{
            .tenant_id = tenant_id, .run_id = run_id, .agent_id = agent_id,
            .tool_name = tool_name, .payload = payload,
        }, self.now());
    }

    pub fn listPending(self: *ApprovalService, tenant_id: i64, user_id: i64) !ApprovalListResult {
        return self.store.listPending(tenant_id, user_id);
    }

    pub fn decide(self: *ApprovalService, tenant_id: i64, id: i64, decision: []const u8, decided_by: i64, comment: []const u8) !bool {
        const valid = std.mem.eql(u8, decision, "approved") or std.mem.eql(u8, decision, "rejected");
        if (!valid) return error.InvalidDecision;
        return self.store.decide(tenant_id, id, decision, decided_by, comment, self.now());
    }
};