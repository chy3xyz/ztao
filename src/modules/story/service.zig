const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const StoryRow = persist.StoryRow;
pub const StoryListResult = persist.StoryListResult;

pub const StoryService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.StoryStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.StoryStore) StoryService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *StoryService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    pub fn create(self: *StoryService, tenant_id: i64, product_id: i64, project_id: i64, title: []const u8, spec: []const u8, opened_by: i64, ai_assisted: bool) !i64 {
        const trimmed = std.mem.trim(u8, title, " \t");
        if (trimmed.len == 0) return error.InvalidTitle;
        return self.store.create(.{
            .tenant_id = tenant_id, .product_id = product_id, .project_id = project_id,
            .title = trimmed, .spec = spec, .pri = 3,
            .source = "user", .category = "feature", .estimate = 0,
            .keywords = "", .assigned_to = 0, .opened_by = opened_by,
            .ai_assisted = ai_assisted,
        }, self.now());
    }

    pub fn get(self: *StoryService, tenant_id: i64, id: i64) !?StoryRow {
        return self.store.getById(tenant_id, id);
    }

    pub fn listByProduct(self: *StoryService, tenant_id: i64, product_id: i64, page: usize, page_size: usize, status_filter: ?[]const u8) !StoryListResult {
        return self.store.listByProduct(tenant_id, product_id, page, page_size, status_filter);
    }

    pub fn listByProject(self: *StoryService, tenant_id: i64, project_id: i64, page: usize, page_size: usize) !StoryListResult {
        return self.store.listByProject(tenant_id, project_id, page, page_size);
    }

    pub fn updateStage(self: *StoryService, tenant_id: i64, id: i64, stage: []const u8) !bool {
        return self.store.updateStage(tenant_id, id, stage, self.now());
    }
};