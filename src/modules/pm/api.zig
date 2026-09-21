//! PM BFF（/api/v1/mp/* 扩展）— 产品 / 项目 / 需求 / 任务 / Bug。
//!
//! M2 提供：
//!   GET  /api/v1/mp/products             我的产品列表
//!   POST /api/v1/mp/products             建产品
//!   GET  /api/v1/mp/projects             我的项目列表
//!   POST /api/v1/mp/projects             建项目
//!   GET  /api/v1/mp/projects/{id}/board  看板（按状态聚合任务）
//!   GET  /api/v1/mp/stories              我的需求列表
//!   POST /api/v1/mp/stories              建需求
//!   GET  /api/v1/mp/tasks?mine=true       我的任务
//!   GET  /api/v1/mp/tasks/{id}           任务详情
//!   POST /api/v1/mp/tasks                建任务
//!   PATCH /api/v1/mp/tasks/{id}/status   改状态
//!   POST /api/v1/mp/tasks/{id}/time      登记工时
//!   GET  /api/v1/mp/bugs                 Bug 列表
//!   POST /api/v1/mp/bugs                 建 Bug
//!   GET  /api/v1/mp/bugs/{id}            Bug 详情
//!   POST /api/v1/mp/bugs/{id}/resolve    解决 Bug

const std = @import("std");
const zigmodu = @import("zigmodu");
const http = zigmodu.http;
const mp_mw = @import("../../middleware/mp_auth.zig");

const user_svc = @import("../user/service.zig");
const product_svc = @import("../product/service.zig");
const project_svc = @import("../project/service.zig");
const story_svc = @import("../story/service.zig");
const pms_task_svc = @import("../pms_task/service.zig");
const bug_svc = @import("../bug/service.zig");

// ---------- DTOs ----------

const ProductDto = struct {
    id: i64,
    name: []const u8,
    code: []const u8,
    status: []const u8,
    description: []const u8,
};

const ProjectDto = struct {
    id: i64,
    product_id: i64,
    name: []const u8,
    code: []const u8,
    status: []const u8,
    model: []const u8,
};

const StoryDto = struct {
    id: i64,
    product_id: i64,
    project_id: i64,
    title: []const u8,
    spec: []const u8,
    pri: i64,
    status: []const u8,
    stage: []const u8,
    ai_assisted: bool,
};

const TaskDto = struct {
    id: i64,
    project_id: i64,
    sprint_id: i64,
    story_id: i64,
    name: []const u8,
    pri: i64,
    status: []const u8,
    estimate: f32,
    consumed: f32,
    left: f32,
    assigned_to: i64,
    assignee_kind: []const u8,
    finished_at: i64,
};

const BugDto = struct {
    id: i64,
    product_id: i64,
    project_id: i64,
    title: []const u8,
    severity: i64,
    type_: []const u8,
    status: []const u8,
    resolution: []const u8,
    assigned_to: i64,
};

const BoardColumn = struct {
    todo: []TaskDto,
    doing: []TaskDto,
    done: []TaskDto,
};

// ---------- API ----------

pub fn PmApi(comptime UserService: type, comptime ProductService: type,
    comptime ProjectService: type, comptime StoryService: type,
    comptime PmsTaskService: type, comptime BugService: type) type {
    return struct {
        const S = @This();
        users: *UserService,
        products: *ProductService,
        projects: *ProjectService,
        stories: *StoryService,
        pms_tasks: *PmsTaskService,
        bugs: *BugService,

        pub const module_name = "pm";
        pub const nest: []const []const u8 = &.{};
        pub const State = S;

        pub const routes: []const http.RouteSpec(S) = &.{
            .{ .method = .GET, .path = "mp/products", .handler = http.wrapHandler(S, listProducts), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/products", .handler = http.wrapHandler(S, createProduct), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/projects", .handler = http.wrapHandler(S, listProjects), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/projects", .handler = http.wrapHandler(S, createProject), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/projects/{id}/board", .handler = http.wrapHandler(S, projectBoard), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/stories", .handler = http.wrapHandler(S, listStories), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/stories", .handler = http.wrapHandler(S, createStory), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/tasks", .handler = http.wrapHandler(S, listTasks), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/tasks", .handler = http.wrapHandler(S, createTask), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/tasks/{id}", .handler = http.wrapHandler(S, getTask), .meta = .{ .auth = .jwt } },
            .{ .method = .PATCH, .path = "mp/tasks/{id}/status", .handler = http.wrapHandler(S, patchTaskStatus), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/tasks/{id}/time", .handler = http.wrapHandler(S, postTaskTime), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/bugs", .handler = http.wrapHandler(S, listBugs), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/bugs", .handler = http.wrapHandler(S, createBug), .meta = .{ .auth = .jwt } },
            .{ .method = .GET, .path = "mp/bugs/{id}", .handler = http.wrapHandler(S, getBug), .meta = .{ .auth = .jwt } },
            .{ .method = .POST, .path = "mp/bugs/{id}/resolve", .handler = http.wrapHandler(S, resolveBug), .meta = .{ .auth = .jwt } },
        };

        pub fn init(
            users: *UserService,
            products: *ProductService,
            projects: *ProjectService,
            stories: *StoryService,
            pms_tasks: *PmsTaskService,
            bugs: *BugService,
        ) S {
            return .{
                .users = users,
                .products = products,
                .projects = projects,
                .stories = stories,
                .pms_tasks = pms_tasks,
                .bugs = bugs,
            };
        }

        // ---------- helpers ----------

        fn requireUser(ctx: *http.Context) !?user_svc.UserRow {
            const uid = mp_mw.mpUserId(ctx) orelse {
                try ctx.sendErrorResponse(401, 401, "未登录");
                return null;
            };
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const row = (try self.users.getUserById(uid)) orelse {
                try ctx.sendErrorResponse(404, 404, "用户不存在");
                return null;
            };
            return row;
        }

        // ---------- handlers ----------

        fn listProducts(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const result = self.products.list(user_row.tenant_id, 1, 100) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer result.free(self.products.allocator);

            const dtos = try ctx.allocator.alloc(ProductDto, result.items.len);
            for (result.items, 0..) |p, i| {
                dtos[i] = .{
                    .id = p.id, .name = p.name, .code = p.code,
                    .status = p.status, .description = p.description,
                };
            }
            try ctx.okValue(.{ .list = dtos, .total = result.total });
        }

        const CreateProductReq = struct {
            name: []const u8,
            code: ?[]const u8 = null,
            description: ?[]const u8 = null,
        };

        fn createProduct(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const req = ctx.bindJson(CreateProductReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.name);
            if (req.code) |c| defer ctx.allocator.free(c);
            if (req.description) |d| defer ctx.allocator.free(d);

            const id = self.products.create(
                user_row.tenant_id,
                req.name,
                req.code orelse "",
                user_row.id,
                req.description orelse "",
                "open",
            ) catch |err| {
                const msg = switch (err) {
                    error.InvalidName => "产品名不能为空",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(400, 400, msg);
                return;
            };
            try ctx.okValue(.{ .id = id });
        }

        fn listProjects(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const result = self.projects.list(user_row.tenant_id, 1, 100) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer result.free(self.projects.allocator);

            const dtos = try ctx.allocator.alloc(ProjectDto, result.items.len);
            for (result.items, 0..) |p, i| {
                dtos[i] = .{
                    .id = p.id, .product_id = p.product_id,
                    .name = p.name, .code = p.code,
                    .status = p.status, .model = p.model,
                };
            }
            try ctx.okValue(.{ .list = dtos, .total = result.total });
        }

        const CreateProjectReq = struct {
            product_id: i64,
            name: []const u8,
            code: ?[]const u8 = null,
            model: ?[]const u8 = null,
        };

        fn createProject(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const req = ctx.bindJson(CreateProjectReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.name);
            if (req.code) |c| defer ctx.allocator.free(c);
            if (req.model) |m| defer ctx.allocator.free(m);

            const id = self.projects.create(
                user_row.tenant_id,
                req.product_id,
                req.name,
                req.code orelse "",
                req.model orelse "scrum",
                user_row.id,
            ) catch |err| {
                const msg = switch (err) {
                    error.InvalidName => "项目名不能为空",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(400, 400, msg);
                return;
            };
            try ctx.okValue(.{ .id = id });
        }

        fn projectBoard(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const pid = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的项目 ID");
                return;
            };
            const result = self.pms_tasks.listByProject(user_row.tenant_id, pid, 1, 200) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer result.free(self.pms_tasks.allocator);

            var todo = std.ArrayList(TaskDto).init(ctx.allocator);
            defer todo.deinit();
            var doing = std.ArrayList(TaskDto).init(ctx.allocator);
            defer doing.deinit();
            var done = std.ArrayList(TaskDto).init(ctx.allocator);
            defer done.deinit();

            for (result.items) |t| {
                const dto: TaskDto = .{
                    .id = t.id, .project_id = t.project_id,
                    .sprint_id = t.sprint_id, .story_id = t.story_id,
                    .name = t.name, .pri = t.pri, .status = t.status,
                    .estimate = t.estimate, .consumed = t.consumed, .left = t.left,
                    .assigned_to = t.assigned_to, .assignee_kind = t.assignee_kind,
                    .finished_at = t.finished_at,
                };
                if (std.mem.eql(u8, t.status, "wait")) try todo.append(dto)
                else if (std.mem.eql(u8, t.status, "doing")) try doing.append(dto)
                else if (std.mem.eql(u8, t.status, "done") or std.mem.eql(u8, t.status, "closed")) try done.append(dto);
            }

            try ctx.okValue(.{
                .todo = todo.items,
                .doing = doing.items,
                .done = done.items,
            });
        }

        const CreateStoryReq = struct {
            product_id: i64,
            project_id: ?i64 = null,
            title: []const u8,
            spec: ?[]const u8 = null,
            ai_assisted: ?bool = null,
        };

        fn createStory(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const req = ctx.bindJson(CreateStoryReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.title);
            if (req.spec) |s| defer ctx.allocator.free(s);

            const id = self.stories.create(
                user_row.tenant_id,
                req.product_id,
                req.project_id orelse 0,
                req.title,
                req.spec orelse "",
                user_row.id,
                req.ai_assisted orelse false,
            ) catch |err| {
                const msg = switch (err) {
                    error.InvalidTitle => "需求标题不能为空",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(400, 400, msg);
                return;
            };
            try ctx.okValue(.{ .id = id });
        }

        fn listStories(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const product_id = ctx.queryInt(i64, "product_id") orelse 0;
            if (product_id == 0) {
                try ctx.sendErrorResponse(400, 400, "缺少 product_id");
                return;
            }
            const status_filter = ctx.queryStr("status", null);
            const result = self.stories.listByProduct(user_row.tenant_id, product_id, 1, 100, status_filter) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer result.free(self.stories.allocator);

            const dtos = try ctx.allocator.alloc(StoryDto, result.items.len);
            for (result.items, 0..) |s, i| {
                dtos[i] = .{
                    .id = s.id, .product_id = s.product_id, .project_id = s.project_id,
                    .title = s.title, .spec = s.spec, .pri = s.pri,
                    .status = s.status, .stage = s.stage, .ai_assisted = s.ai_assisted,
                };
            }
            try ctx.okValue(.{ .list = dtos, .total = result.total });
        }

        fn listTasks(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const result = if (ctx.queryBool("mine") orelse false)
                self.pms_tasks.listAssignedTo(user_row.tenant_id, user_row.id, 1, 100) catch {
                    try ctx.sendErrorResponse(500, 500, "服务器错误");
                    return;
                }
            else blk: {
                const pid = ctx.queryInt(i64, "project_id") orelse {
                    try ctx.sendErrorResponse(400, 400, "缺少 project_id");
                    return;
                };
                break :blk self.pms_tasks.listByProject(user_row.tenant_id, pid, 1, 100) catch {
                    try ctx.sendErrorResponse(500, 500, "服务器错误");
                    return;
                };
            };
            defer result.free(self.pms_tasks.allocator);

            const dtos = try ctx.allocator.alloc(TaskDto, result.items.len);
            for (result.items, 0..) |t, i| {
                dtos[i] = .{
                    .id = t.id, .project_id = t.project_id,
                    .sprint_id = t.sprint_id, .story_id = t.story_id,
                    .name = t.name, .pri = t.pri, .status = t.status,
                    .estimate = t.estimate, .consumed = t.consumed, .left = t.left,
                    .assigned_to = t.assigned_to, .assignee_kind = t.assignee_kind,
                    .finished_at = t.finished_at,
                };
            }
            try ctx.okValue(.{ .list = dtos, .total = result.total });
        }

        const CreateTaskReq = struct {
            project_id: i64,
            sprint_id: ?i64 = null,
            story_id: ?i64 = null,
            name: []const u8,
            pri: ?i64 = null,
            estimate: ?f32 = null,
            assigned_to: ?i64 = null,
            assignee_kind: ?[]const u8 = null,
        };

        fn createTask(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);

            const req = ctx.bindJson(CreateTaskReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.name);
            if (req.assignee_kind) |k| defer ctx.allocator.free(k);

            const id = self.pms_tasks.create(
                user_row.tenant_id,
                req.project_id,
                req.sprint_id orelse 0,
                req.story_id orelse 0,
                req.name,
                req.pri orelse 3,
                req.estimate orelse 0,
                req.assigned_to orelse user_row.id,
                req.assignee_kind orelse "user",
                false,
            ) catch |err| {
                const msg = switch (err) {
                    error.InvalidName => "任务名不能为空",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(400, 400, msg);
                return;
            };
            try ctx.okValue(.{ .id = id });
        }

        fn getTask(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);
            const id = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的任务 ID");
                return;
            };
            const row = (try self.pms_tasks.get(user_row.tenant_id, id)) orelse {
                try ctx.sendErrorResponse(404, 404, "任务不存在");
                return;
            };
            defer row.free(self.pms_tasks.allocator);
            try ctx.okValue(.{
                .id = row.id, .project_id = row.project_id,
                .sprint_id = row.sprint_id, .story_id = row.story_id,
                .name = row.name, .pri = row.pri, .status = row.status,
                .estimate = row.estimate, .consumed = row.consumed, .left = row.left,
                .assigned_to = row.assigned_to, .assignee_kind = row.assignee_kind,
                .finished_at = row.finished_at,
            });
        }

        const PatchStatusReq = struct { status: []const u8 };
        fn patchTaskStatus(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);
            const id = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的任务 ID");
                return;
            };
            const req = ctx.bindJson(PatchStatusReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.status);

            const ok = self.pms_tasks.updateStatus(user_row.tenant_id, id, req.status, user_row.id) catch |err| {
                const msg = switch (err) {
                    error.InvalidStatus => "状态值无效",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(400, 400, msg);
                return;
            };
            if (!ok) {
                try ctx.sendErrorResponse(404, 404, "任务不存在");
                return;
            }
            try ctx.okValue(.{ .ok = true });
        }

        const LogTimeReq = struct { hours: f32 };
        fn postTaskTime(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);
            const id = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的任务 ID");
                return;
            };
            const req = ctx.bindJson(LogTimeReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            const ok = self.pms_tasks.logTime(user_row.tenant_id, id, req.hours) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            try ctx.okValue(.{ .ok = ok });
        }

        fn listBugs(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);
            const product_id = ctx.queryInt(i64, "product_id") orelse 0;
            if (product_id == 0) {
                try ctx.sendErrorResponse(400, 400, "缺少 product_id");
                return;
            }
            const status_filter = ctx.queryStr("status", null);
            const result = self.bugs.list(user_row.tenant_id, product_id, 1, 100, status_filter) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            defer result.free(self.bugs.allocator);

            const dtos = try ctx.allocator.alloc(BugDto, result.items.len);
            for (result.items, 0..) |b, i| {
                dtos[i] = .{
                    .id = b.id, .product_id = b.product_id, .project_id = b.project_id,
                    .title = b.title, .type_ = b.type_, .severity = b.severity,
                    .status = b.status, .resolution = b.resolution,
                    .assigned_to = b.assigned_to,
                };
            }
            try ctx.okValue(.{ .list = dtos, .total = result.total });
        }

        const CreateBugReq = struct {
            product_id: i64,
            project_id: ?i64 = null,
            title: []const u8,
            severity: ?i64 = null,
            type_: ?[]const u8 = null,
            steps: ?[]const u8 = null,
        };

        fn createBug(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);
            const req = ctx.bindJson(CreateBugReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.title);
            if (req.type_) |t| defer ctx.allocator.free(t);
            if (req.steps) |s| defer ctx.allocator.free(s);

            const id = self.bugs.create(
                user_row.tenant_id,
                req.product_id,
                req.project_id orelse 0,
                req.title,
                req.severity orelse 3,
                req.type_ orelse "code",
                req.steps orelse "",
                0,
                user_row.id,
            ) catch |err| {
                const msg = switch (err) {
                    error.InvalidTitle => "标题不能为空",
                    error.InvalidSeverity => "严重度必须在 1-4 之间",
                    else => "服务器错误",
                };
                try ctx.sendErrorResponse(400, 400, msg);
                return;
            };
            try ctx.okValue(.{ .id = id });
        }

        fn getBug(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);
            const id = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的 Bug ID");
                return;
            };
            const row = (try self.bugs.get(user_row.tenant_id, id)) orelse {
                try ctx.sendErrorResponse(404, 404, "Bug 不存在");
                return;
            };
            defer row.free(self.bugs.allocator);
            try ctx.okValue(.{
                .id = row.id, .product_id = row.product_id, .project_id = row.project_id,
                .title = row.title, .severity = row.severity, .type_ = row.type_,
                .steps = row.steps, .status = row.status,
                .resolution = row.resolution, .assigned_to = row.assigned_to,
            });
        }

        const ResolveReq = struct { resolution: []const u8 };
        fn resolveBug(ctx: *http.Context) !void {
            const self: *S = @ptrCast(@alignCast(ctx.user_data orelse return error.UnexpectedError));
            const user_row = (try requireUser(ctx)) orelse return;
            defer user_row.free(self.users.store.allocator);
            const id = ctx.paramInt(i64, "id") catch {
                try ctx.sendErrorResponse(400, 400, "无效的 Bug ID");
                return;
            };
            const req = ctx.bindJson(ResolveReq) catch {
                try ctx.sendErrorResponse(400, 400, "请求体格式错误");
                return;
            };
            defer ctx.allocator.free(req.resolution);

            const ok = self.bugs.resolve(user_row.tenant_id, id, user_row.id, req.resolution) catch {
                try ctx.sendErrorResponse(500, 500, "服务器错误");
                return;
            };
            if (!ok) {
                try ctx.sendErrorResponse(404, 404, "Bug 不存在");
                return;
            }
            try ctx.okValue(.{ .ok = true });
        }
    };
}

pub const PmApiDefault = PmApi(
    user_svc.UserService,
    product_svc.ProductService,
    project_svc.ProjectService,
    story_svc.StoryService,
    pms_task_svc.PmsTaskService,
    bug_svc.BugService,
);