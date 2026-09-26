const std = @import("std");
const zent = @import("zent");
const crud = zent.crud_helpers;
const model = @import("model.zig");
const schema = @import("../../schema.zig");

const graph = zent.codegen.graph.buildGraph(&.{model.Story});
pub const infos = graph.types;
pub const Client = schema.Client;
pub const StoryInfo = infos[0];

pub const StoryRow = struct {
    id: i64,
    tenant_id: i64,
    product_id: i64,
    project_id: i64,
    title: []const u8,
    spec: []const u8,
    pri: i64,
    status: []const u8,
    stage: []const u8,
    source: []const u8,
    category: []const u8,
    estimate: f64,
    parent_id: i64,
    keywords: []const u8,
    assigned_to: i64,
    opened_by: i64,
    ai_assisted: bool,
    ai_prompt_id: i64,
    created_at: i64,
    updated_at: i64,

    pub fn free(self: StoryRow, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
        allocator.free(self.spec);
        allocator.free(self.status);
        allocator.free(self.stage);
        allocator.free(self.source);
        allocator.free(self.category);
        allocator.free(self.keywords);
    }
};

pub const StoryListResult = struct {
    items: []StoryRow,
    total: i64,

    pub fn free(self: *const StoryListResult, allocator: std.mem.Allocator) void {
        for (self.items) |r| r.free(allocator);
        allocator.free(self.items);
    }
};

pub const StoryStore = struct {
    allocator: std.mem.Allocator,
    client: Client,

    pub fn init(allocator: std.mem.Allocator, client: Client) StoryStore {
        return .{ .allocator = allocator, .client = client };
    }

    fn dup(self: *StoryStore, e: anytype) !StoryRow {
        const title = try self.allocator.dupe(u8, e.title);
        errdefer self.allocator.free(title);
        const spec = try self.allocator.dupe(u8, e.spec);
        errdefer self.allocator.free(spec);
        const status = try self.allocator.dupe(u8, e.status);
        errdefer self.allocator.free(status);
        const stage = try self.allocator.dupe(u8, e.stage);
        errdefer self.allocator.free(stage);
        const source = try self.allocator.dupe(u8, e.source);
        errdefer self.allocator.free(source);
        const category = try self.allocator.dupe(u8, e.category);
        errdefer self.allocator.free(category);
        const keywords = try self.allocator.dupe(u8, e.keywords);
        return .{
            .id = e.id,
            .tenant_id = e.tenant_id,
            .product_id = e.product_id,
            .project_id = e.project_id,
            .title = title,
            .spec = spec,
            .pri = e.pri,
            .status = status,
            .stage = stage,
            .source = source,
            .category = category,
            .estimate = e.estimate,
            .parent_id = e.parent_id,
            .keywords = keywords,
            .assigned_to = e.assigned_to,
            .opened_by = e.opened_by,
            .ai_assisted = e.ai_assisted,
            .ai_prompt_id = e.ai_prompt_id,
            .created_at = e.created_at orelse 0,
            .updated_at = e.updated_at orelse 0,
        };
    }

    pub fn create(self: *StoryStore, s: struct {
        tenant_id: i64,
        product_id: i64,
        project_id: i64,
        title: []const u8,
        spec: []const u8,
        pri: i64,
        source: []const u8,
        category: []const u8,
        estimate: f64,
        keywords: []const u8,
        assigned_to: i64,
        opened_by: i64,
        ai_assisted: bool,
    }, now: i64) !i64 {
        var created = try crud.create(self.client.story, .{
            .tenant_id = s.tenant_id,
            .product_id = s.product_id,
            .project_id = s.project_id,
            .title = s.title,
            .spec = s.spec,
            .pri = s.pri,
            .status = "draft",
            .stage = "wait",
            .source = s.source,
            .category = s.category,
            .estimate = s.estimate,
            .parent_id = 0,
            .keywords = s.keywords,
            .assigned_to = s.assigned_to,
            .opened_by = s.opened_by,
            .ai_assisted = s.ai_assisted,
            .ai_prompt_id = 0,
            .created_at = now,
            .updated_at = now,
        });
        defer self.client.story.deinitRow(@constCast(&created));
        return created.id;
    }

    pub fn getById(self: *StoryStore, tenant_id: i64, id: i64) !?StoryRow {
        const preds = self.client.story.predicates;
        var e = (try crud.first(self.client.story, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        })) orelse return null;
        defer self.client.story.deinitRow(@constCast(&e));
        return try self.dup(e);
    }

    pub fn listByProduct(self: *StoryStore, tenant_id: i64, product_id: i64, page: usize, page_size: usize, status_filter: ?[]const u8) !StoryListResult {
        var q = self.client.story.Query();
        defer q.deinit();
        const preds = self.client.story.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.product_idEQ(.{ .int = product_id })});
        if (status_filter) |st| {
            _ = try q.Where(.{preds.statusEQ(.{ .string = st })});
        }
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});
        var paged = try q.paged(page, page_size);
        defer paged.deinit();
        var out = try self.allocator.alloc(StoryRow, paged.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (paged.items.items) |e| {
            out[n] = try self.dup(e);
            n += 1;
        }
        return .{ .items = out, .total = paged.total };
    }

    pub fn listByProject(self: *StoryStore, tenant_id: i64, project_id: i64, page: usize, page_size: usize) !StoryListResult {
        var q = self.client.story.Query();
        defer q.deinit();
        const preds = self.client.story.predicates;
        _ = try q.Where(.{preds.tenant_idEQ(.{ .int = tenant_id })});
        _ = try q.Where(.{preds.project_idEQ(.{ .int = project_id })});
        _ = try q.OrderBy(&[_]zent.sql.Order{zent.sql.OrderDesc("id")});
        var paged = try q.paged(page, page_size);
        defer paged.deinit();
        var out = try self.allocator.alloc(StoryRow, paged.items.items.len);
        var n: usize = 0;
        errdefer {
            for (out[0..n]) |r| r.free(self.allocator);
            self.allocator.free(out);
        }
        for (paged.items.items) |e| {
            out[n] = try self.dup(e);
            n += 1;
        }
        return .{ .items = out, .total = paged.total };
    }

    pub fn updateStage(self: *StoryStore, tenant_id: i64, id: i64, stage: []const u8, now: i64) !bool {
        const preds = self.client.story.predicates;
        const affected = try crud.update(self.client.story, .{
            .stage = stage,
            .updated_at = now,
        }, .{
            preds.tenant_idEQ(.{ .int = tenant_id }),
            preds.idEQ(.{ .int = id }),
        });
        return affected > 0;
    }
};