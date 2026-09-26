//! Agent service — preset seed + clone-to-user + list/get.
//!
//! 启动期应调用 `seedDefaults()` 把 5 个 Preset 写入 DB（幂等）。

const std = @import("std");
const zigmodu = @import("zigmodu");
const persist = @import("persistence.zig");

pub const AgentPresetRow = persist.AgentPresetRow;
pub const AgentInstanceRow = persist.AgentInstanceRow;

pub const AgentError = error{
    Unexpected,
};

pub const AgentService = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    store: *persist.AgentStore,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, store: *persist.AgentStore) AgentService {
        return .{ .allocator = allocator, .io = io, .store = store };
    }

    fn now(self: *AgentService) i64 {
        return zigmodu.time.wallClockSeconds(self.io);
    }

    /// Seed the 5 default presets. Idempotent — safe to call on every boot.
    pub fn seedDefaults(self: *AgentService) !void {
        const presets = [_]struct {
            code: []const u8,
            name: []const u8,
            avatar: []const u8,
            kind: []const u8,
            sp: []const u8,
            tools: []const u8,
            caps: []const u8,
            scopes: []const u8,
            sort: i64,
        }{
            .{
                .code = "pm", .name = "产品 Agent", .avatar = "📋", .kind = "pm",
                .sp = "你是 Founder 的产品经理 Agent，擅长写需求、拆任务、评审、出方案。回复简洁、可执行。",
                .tools = "[\"doc.write\",\"task.write\",\"story.write\"]",
                .caps = "[\"prd\",\"user_story\",\"task_breakdown\",\"review\"]",
                .scopes = "[\"product\",\"story\",\"task\",\"doc\"]",
                .sort = 1,
            },
            .{
                .code = "dev", .name = "开发 Agent", .avatar = "💻", .kind = "dev",
                .sp = "你是 Founder 的开发 Agent，擅长编码、改 Bug、重构、提 PR。改代码前先理解上下文；高危操作（deploy / rm / force-push）必须等审批。",
                .tools = "[\"git.read\",\"git.write\",\"file.read\",\"file.edit\",\"shell.run*\",\"test.run\"]",
                .caps = "[\"code\",\"refactor\",\"bugfix\",\"test\"]",
                .scopes = "[\"task\",\"bug\",\"code\"]",
                .sort = 2,
            },
            .{
                .code = "qa", .name = "测试 Agent", .avatar = "🧪", .kind = "qa",
                .sp = "你是 Founder 的测试 Agent，擅长写用例、跑测试、回归、写报告。",
                .tools = "[\"testcase.write\",\"test.run\",\"bug.write\"]",
                .caps = "[\"testcase\",\"regression\",\"report\"]",
                .scopes = "[\"testcase\",\"bug\",\"report\"]",
                .sort = 3,
            },
            .{
                .code = "support", .name = "客服 Agent", .avatar = "🎧", .kind = "support",
                .sp = "你是 Founder 的客服 Agent，擅长回答工单、路由、复盘。回复礼貌、信息完整。",
                .tools = "[\"ticket.read\",\"ticket.write\",\"notify.send\"]",
                .caps = "[\"ticket\",\"routing\",\"review\"]",
                .scopes = "[\"ticket\",\"notify\"]",
                .sort = 4,
            },
            .{
                .code = "ops", .name = "运营 Agent", .avatar = "📊", .kind = "ops",
                .sp = "你是 Founder 的运营 Agent，擅长监控、报表、提醒、排程。",
                .tools = "[\"report.read\",\"cron.write\",\"notify.send\"]",
                .caps = "[\"report\",\"cron\",\"monitor\"]",
                .scopes = "[\"report\",\"cron\",\"notify\"]",
                .sort = 5,
            },
        };
        for (presets) |p| {
            _ = try self.store.upsertPreset(.{
                .code = p.code, .name = p.name, .avatar = p.avatar,
                .kind = p.kind, .system_prompt = p.sp,
                .tools = p.tools, .capabilities = p.caps, .scopes = p.scopes,
                .is_default = true, .sort = p.sort,
            }, self.now());
        }
    }

    pub fn listDefaults(self: *AgentService) AgentError![]AgentPresetRow {
        return self.store.listDefaults() catch error.Unexpected;
    }

    pub fn getPresetByCode(self: *AgentService, code: []const u8) AgentError!?AgentPresetRow {
        return self.store.getPresetByCode(code) catch error.Unexpected;
    }

    /// Idempotently clone every default preset into a personal AgentInstance
    /// for the given (tenant_id, user_id). Returns the list of newly-created
    /// or already-existing instance rows.
    pub fn clonePresetsToUser(self: *AgentService, tenant_id: i64, user_id: i64) AgentError![]AgentInstanceRow {
        const presets = self.store.listDefaults() catch return error.Unexpected;
        defer {
            for (presets) |p| p.free(self.allocator);
            self.allocator.free(presets);
        }
        var out = std.array_list.Managed(AgentInstanceRow).init(self.allocator);
        errdefer {
            for (out.items) |r| r.free(self.allocator);
            out.deinit();
        }
        for (presets) |p| {
            if ((self.store.findInstance(tenant_id, user_id, p.id) catch return error.Unexpected)) |existing| {
                // dupInstance 已用 self.allocator 分配字符串；out.append 按值
                // 复制结构（含字符串切片指针）→ ownership 转移给 out，
                // 此处不能 defer existing.free，否则 out 里的 row 字符串悬空。
                out.append(existing) catch return error.Unexpected;
                continue;
            }
            const id = self.store.createInstance(.{
                .tenant_id = tenant_id,
                .user_id = user_id,
                .preset_id = p.id,
                .preset_code = p.code,
                .name = p.name,
                .avatar = p.avatar,
                .model = "stub",
                .max_daily_cost_cents = 5000,
            }, self.now()) catch return error.Unexpected;
            const row_opt = self.store.getInstance(id) catch return error.Unexpected;
            const row = row_opt orelse continue;
            out.append(row) catch return error.Unexpected;
        }
        return out.toOwnedSlice() catch return error.Unexpected;
    }

    pub fn listByUser(self: *AgentService, tenant_id: i64, user_id: i64) AgentError![]AgentInstanceRow {
        return self.store.listInstancesByUser(tenant_id, user_id) catch error.Unexpected;
    }

    pub fn get(self: *AgentService, id: i64) AgentError!?AgentInstanceRow {
        return self.store.getInstance(id) catch error.Unexpected;
    }
};