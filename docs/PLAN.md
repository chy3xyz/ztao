# ztao · 产品技术方案 v0.2

> 基于 [chy3xyz/zweq](https://github.com/chy3xyz/zweq) 二次开发。
> 面向 **一人公司** 的 **后 AI 开发** PM 产品。
> **用户端主要在 微信小程序**；后台是 Web。
> **商城体系保留并重新定位**为 礼品商城 / 配件商城 / 算力商城。
>
> 业务模型参照 `_ref/zentaopms`（禅道开源版）。

---

## 选型决策（已锁 v0.2）

| 项 | 决策 | 理由 |
|---|---|---|
| M1 顺序 | **先打通小程序登录 + AI 入口** | 最快出 Day-One 价值 |
| 小程序框架 | **Taro 4 + React + TS** | 一码多端；生态熟 |
| 支付渠道 | **国内为主**（微信 v3 + 支付宝） | 一人公司国内最主流；海外 Stripe 预留 |
| 部署形态 | **SaaS 公网**（api.ztao.cn + admin.ztao.cn） | License 双模式：cloud / onprem |

详细施工图见 [`M1.md`](M1.md) · 合规清单 [`COMPLIANCE.md`](COMPLIANCE.md) · API 契约 [`API.md`](API.md) · 小程序设计 [`MINIAPP.md`](MINIAPP.md) · 商城设计 [`MALL.md`](MALL.md)。

---

## 0. 一句话定位

> **ztao = 一个 AI 团队 + 一套 PM 工具 + 一个小程序入口 + 一座小商城。**
> 一个人也能跑一家公司：早上说一句"今天做 X"，晚上看仪表盘知道花了多少钱、产出了什么。

| 维度 | 定位 |
|---|---|
| 目标用户 | **一人公司 / 极小团队（1~5 人）** · 个人开发者 · 独立产品人 · 工作室 |
| 产品哲学 | 一个以 AI 团队替代真人员工的「数字公司」 |
| 用户端 | **微信小程序（主）** + Web 后台（次） |
| 业务域 | 产品 / 项目 / 需求 / 任务 / Bug / 用例 / 版本 / 文档 / 迭代 / AI 团队 + 礼品 / 配件 / 算力 3 套小商城 |
| 计费 | **能力按席位 + 算力按 token**；商城用 **微信支付 v3**；订阅制 |
| 差异化 | **AI 是一等公民**（Agent = 虚拟员工）；**一个产品覆盖 PM + 商城**；**小程序即工作台** |

---

## 1. 为什么是「一人公司」

一人公司（Solopreneur / Micro-business）的痛点：

1. **一个人做所有事** — 产品 / 开发 / 测试 / 销售 / 客服 / 财务，每件事都切换身份
2. **缺人手** — 没有 QA、没有设计师、没有运营
3. **缺工具链** — Jira 太重、Notion 太散、禅道太传统
4. **成本敏感** — 月费不能超过一杯咖啡；按用量付费
5. **移动为先** — 灵感在路上、对话在客户那里、出差在高铁上
6. **数据归属** — 必须能随时带走全部数据

ztao 的解：

- **AI 团队** = 1 名 Founder + N 名 Agent（产品 Agent / 开发 Agent / 测试 Agent / 客服 Agent / 运营 Agent）
- **小程序为主** — 手机里能完成 80% 工作
- **极简录入** — 语音 / 拍照 / 转写 / 自然语言 → 自动归类为需求 / Bug / 任务
- **透明账单** — 每个 AI 员工的工资 = token 成本，明细可见
- **商城闭环** — 客户礼品 / 办公配件 / 加算力，都在一个 App 里

---

## 2. 三套商城（保留并重新定位 zweq 商城模块）

zweq 原生商城体系（shop / coupon / points / distribution / member_card / seckill / vote / lucky_draw / material）功能完整、模型成熟。**全部保留**，按用途分为三套：

| 商城 | 用途 | 复用 zweq 模块 | 关键差异化 |
|---|---|---|---|
| 🎁 **礼品商城** | 任务/版本/里程碑达成时兑换给"客户/家人/自己"；节日福利；邀请奖励 | `shop`（商品）+ `coupon`（券）+ `points`（积分）+ `material`（图文） | 商品来源支持"AI 任务奖励自动发券" |
| 🛠 **配件商城** | 硬件 / 外设 / SaaS 工具 / 课程 / 模板 — 一人公司工作台相关 | `shop`（商品）+ `material`（详情页）+ `menu`（类目导航） | 商品与 PM 工作流打通（如买显示器自动登记资产） |
| ⚡ **算力商城** | AI Token 包 / 模型包 / 工具调用包 / 团队席位数 | `payment`（支付）+ `cloud`（License / MarketPackage）+ `points`（积分抵扣） | **直接关联 aiagent 模块消耗，售完即降级** |

计费矩阵：

```
┌────────────────────┬──────────────┬──────────────┬──────────────┐
│                    │ 礼品商城      │ 配件商城      │ 算力商城      │
├────────────────────┼──────────────┼──────────────┼──────────────┤
│ 支付               │ 微信 v3 购物  │ 微信 v3 购物  │ 微信 v3 购物  │
│ 订单               │ ShopOrder    │ ShopOrder    │ RechargeOrder│
│ 优惠券             │ Coupon       │ Coupon       │ —            │
│ 积分抵扣           │ PointsOrder  │ PointsOrder  │ —            │
│ 限时 / 拼团         │ Seckill      │ Seckill      │ —            │
│ 抽奖               │ LuckyDraw    │ —            │ —            │
│ 投票               │ Vote（选品）  │ —            │ —            │
│ 会员卡             │ MemberCard   │ MemberCard   │ MemberCard   │
│ 分销               │ Distributor  │ Distributor  │ —            │
│ 退款               │ ShopRefund   │ ShopRefund   │ 自动退余额    │
└────────────────────┴──────────────┴──────────────┴──────────────┘
```

详见 [`docs/MALL.md`](MALL.md)。

---

## 3. 小程序端（用户主操作面）

### 3.1 技术选型

- **小程序框架**：**Taro 4**（React + TS）— 一码多端（微信 / 支付宝 / 抖音小程序可选）
- **状态管理**：Zustand / Jotai（小而美）
- **网络**：自带 `Taro.request` + 拦截器（注入 token、统一信封解析）
- **实时**：WebSocket / SSE 接收 AI 流式输出
- **后端协议**：复用 zweq 现有 REST API；新增 `/api/v1/mp/*` 移动端专用端点（字段裁剪、聚合、列表轻分页）

### 3.2 小程序页面架构（Tab + 路由）

```
┌──────────────────────────────────────────────────────────────┐
│  Tab 1  · 工作台（Home）                                        │
│   ├─ 今日待办 (我的任务 + AI Agent 进度)                       │
│   ├─ AI 团队（@Agent · 对话 · 任务委托）                       │
│   ├─ 数据卡片：今日算力消耗 / 本月成本 / 本月产出              │
│   └─ 晨间简报（AI 自动总结昨日 + 今日建议）                    │
├──────────────────────────────────────────────────────────────┤
│  Tab 2  · 项目（PMS）                                          │
│   ├─ 我的项目（列表 / 切换当前项目）                           │
│   ├─ 迭代（看板 / 列表）                                       │
│   ├─ 需求 / 任务 / Bug（按角色视图切换）                       │
│   ├─ 文档（只读 + 简单编辑）                                   │
│   └─ 版本 / 发布                                               │
├──────────────────────────────────────────────────────────────┤
│  Tab 3  · 商城（Mall）                                         │
│   ├─ Banner（礼品 / 配件 / 算力 三 Tab）                      │
│   ├─ 礼品商城（积分 + 现金）                                  │
│   ├─ 配件商城（现金）                                          │
│   └─ 算力商城（现金 · 月包 / 年包 / 团队包）                  │
├──────────────────────────────────────────────────────────────┤
│  Tab 4  · 我的（Me）                                           │
│   ├─ 身份切换（PM / 研发 / QA / 销售 / 客服 — 一人多角）       │
│   ├─ 算力账单（实时 token 消耗）                              │
│   ├─ 我的订单 / 优惠券 / 积分 / 会员卡                        │
│   ├─ AI 团队管理（增删 Agent · 设置权限）                     │
│   ├─ 数据出境（一键导出）                                      │
│   └─ 设置（通知 / 订阅消息 / 隐私）                           │
└──────────────────────────────────────────────────────────────┘
```

### 3.3 入口与登录

- **首次进入**：手机号一键登录 + 微信授权（`wx.login` → 拿 `code` → 后端 `jscode2session`）
- **扫码登录 Web 后台**：小程序"我的"→ 扫一扫 → 自动在 Web 端登录（复用 zweq 已有扫码登录）
- **订阅消息**：用户主动勾选关心的 8 个场景（任务分配 / Bug 紧急 / AI 完成 / 审批请求…）

### 3.4 与 Web 后台的分工

| 场景 | 小程序 | Web 后台 |
|---|---|---|
| 看任务、勾任务、写评论、改状态 | ✅ 主 | ✅ 次 |
| 创建需求 / 任务 / Bug（语音/拍照） | ✅ 主 | ✅ |
| 看仪表盘 / 报表 | ✅ 简化版 | ✅ 全量 |
| 配置 AI Provider / 模型 / Token | ❌ | ✅ |
| 管理团队 / 角色 / 权限 | ❌ | ✅ |
| 商城运营（上架 / 活动） | ❌ | ✅ |
| 财务 / 订阅 / 发票 | ✅ 看 | ✅ 管 |
| AI 工作流编排 | 模板套用 | ✅ 全量编辑 |
| 系统设置 / 审计 | ❌ | ✅ |
| 极简操作（语音录入、AI 对话） | ✅ 主 | ✅ 次 |

**规则**：能用小程序完成的，绝不引导去 Web。

---

## 4. 后台 Web 端（次操作面）

- 复用 zweq/web 整个工程（Vue 3 + TS + Vite + Element Plus / Naive UI）
- 新增 PM 视图：产品 / 项目 / 需求 / 任务 / Bug / 用例 / 版本 / 文档 / 迭代
- 新增 AI 视图：Provider / Agent / Prompt / Workflow / Run 监控
- 新增商城运营视图：礼品 / 配件 / 算力 三套商品 / 订单 / 退款 / 营销
- 新增 SaaS 视图：套餐 / 订阅 / 发票 / 用量 / 审计

---

## 5. 整体技术架构

```
┌──────────────────────┐  ┌──────────────────────┐
│ 微信小程序 (Taro)     │  │ Web 后台 (Vue 3)      │
│ Tabs: 工作台/项目/   │  │ Admin / PMS / Mall /  │
│       商城/我的      │  │ SaaS Console         │
└──────────┬───────────┘  └──────────┬───────────┘
           │  wx.login              │  JWT
           │  wx.request              │  HTTPS
           ▼                         ▼
┌──────────────────────────────────────────────────────────────┐
│  Zig Single Binary (zweq runtime)                              │
│                                                               │
│  /api/v1/mp/*  小程序专用 API（精简、移动友好）                 │
│  /api/v1/*     Web 后台 API（完整）                            │
│                                                               │
│  ┌── Modules (model→persistence→service→api→module) ──────┐  │
│  │  base : tenant · user · role · permission · fan_auth    │  │
│  │  pm   : product · project · sprint · story · task · bug │  │
│  │        · testcase · build · release · doc               │  │
│  │  ai   : ai · aiagent · aiprompt · aiworkflow            │  │
│  │  saas : billing · license · subscription · usage        │  │
│  │  mall : shop · coupon · points · distribution           │  │
│  │        · member_card · seckill · lucky_draw · vote      │  │
│  │        · material · menu                                │  │
│  │  ops  : notification · webhook · audit · file           │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                               │
│  Middleware: real_ip · jwtAuth · tokenVersionGuard ·          │
│              catalog_permissions · rate_limit · license ·     │
│              envelope · access_log · metrics · request_log    │
└──────────┬──────────────────────────────────┬─────────────────┘
           │                                  │
           ▼                                  ▼
   ┌───────────────┐                  ┌────────────────────┐
   │ Postgres      │                  │ AI Providers       │
   │ (主库)        │                  │ openai / claude /  │
   │               │                  │ qwen / doubao /    │
   │ SQLite for dev│                  │ ollama / 自定义    │
   └───────────────┘                  └────────────────────┘
```

---

## 6. 目录与模块布局

> 严格遵循 zweq 约定 `model → persistence → service → api → module`。所有 zent schema 集中注册到 `src/schema.zig`。

```
ztao/
├── build.zig
├── docker-compose.yml
├── mp/                          # 🆕 微信小程序工程（Taro 4 + React + TS）
│   ├── src/pages/
│   │   ├── workspace/           # 工作台 Tab
│   │   ├── project/             # 项目 Tab
│   │   ├── mall/                # 商城 Tab
│   │   └── me/                  # 我的 Tab
│   ├── src/components/          # 通用组件（卡片/列表/AI 对话气泡…）
│   ├── src/stores/              # Zustand stores
│   └── src/services/           # API client
├── web/                         # 复用 zweq/web（Vue 3 + TS）
│   └── src/views/              # PM / AI / Mall / SaaS 视图
└── src/                        # Zig 后端
    ├── main.zig
    ├── config.zig              # ZTAO_ 前缀
    ├── schema.zig              # 全部 zent schema 注册
    ├── jobs.zig
    ├── middleware/
    │   ├── mp_auth.zig         # 🆕 小程序授权中间件
    │   └── ... (复用 zweq)
    ├── http/
    └── modules/
        ├── tenant/             # base
        ├── user/               # base
        ├── role/               # base
        ├── permission/         # base
        ├── fan/                # 🆕 微信粉丝/小程序用户（合并 zweq/member）
        ├── product/            # pm
        ├── project/            # pm
        ├── sprint/             # pm (execution→sprint)
        ├── story/              # pm
        ├── task/               # pm
        ├── bug/                # pm
        ├── testcase/           # pm
        ├── build/              # pm
        ├── release/            # pm
        ├── doc/                # pm
        ├── ai/                 # ai（直接复用 zweq/ai）
        ├── aiagent/            # ai（🆕 Agent 一等公民）
        ├── aiprompt/           # ai
        ├── aiworkflow/         # ai
        ├── notification/       # ops
        ├── webhook/            # ops
        ├── audit/              # ops（直接复用 zweq/audit）
        ├── file/               # ops（直接复用）
        ├── shop/               # mall（直接复用 zweq/shop）
        ├── coupon/             # mall
        ├── points/             # mall
        ├── distribution/       # mall
        ├── member_card/        # mall
        ├── seckill/            # mall
        ├── lucky_draw/         # mall
        ├── vote/               # mall
        ├── material/           # mall
        ├── menu/               # mall（自定义类目导航）
        ├── payment/            # mall（直接复用，微信 v3）
        ├── cloud/              # saas（License / MarketPackage）
        ├── module/             # saas（动态模块绑定）
        ├── license/            # 🆕 套餐 / 席位 / 限额
        ├── subscription/       # 🆕 订阅
        ├── billing/            # 🆕 发票
        └── usage/              # 🆕 token 用量计量
    └── services/
        ├── cache.zig           # 复用
        ├── wire.zig            # 复用
        ├── mail.zig            # 复用
        └── ai_runtime.zig      # 🆕 Agent runtime（流式、工具、沙箱）
```

---

## 7. 数据库设计

> 沿用禅道命名（product / story / task / bug / testcase / build…）便于老用户认知。
> 每张业务表带 `tenant_id BIGINT NOT NULL` 物理列做强隔离。
> AI 与 SaaS 表是 ztao 的差异化层。

### 7.1 组织 / 身份

```sql
Tenant(id, name, slug, status, plan_code, seat_limit, ai_token_monthly,
       ai_token_used, owner_user_id, created_at, updated_at)
Workspace(id, tenant_id, name, kind)             -- 默认每人一个 Workspace = 一人公司
User(id, tenant_id, workspace_id, name, phone, email, password,
     verified, status, token_version, current_role, avatar)
UserRole(id, tenant_id, user_id, role_id)
UserIdentity(id, user_id, channel, openid, unionid, mp_appid)  -- 微信 openid 等
Role(id, tenant_id, name, code, description)
Permission(id, tenant_id, module, action)
RolePermission(role_id, permission_id)
```

> **一人公司模式下**：注册即创建 Tenant + 默认 Workspace + 默认 User + 一组预置 AI Agent（PM Agent / Dev Agent / QA Agent）。`workspace` 概念保留以便未来扩到 2~5 人团队。

### 7.2 产品 / 项目 / 迭代（沿用禅道）

```sql
Product(id, tenant_id, name, code, type, status, owner_id, description, acl)
ProductPlan(id, tenant_id, product_id, title, begin, end, status)

Project(id, tenant_id, name, code, type, status, model, parent_id,
        begin, end, owner_id, budget_hours, ai_enabled)
ProjectMember(id, tenant_id, project_id, user_id, role, joined_at)

Sprint(id, tenant_id, project_id, name, goal, begin, end, status)
SprintMember(id, sprint_id, user_id, planned_hours)
```

### 7.3 需求 / 任务 / Bug / 用例 / 版本 / 文档

```sql
Story(id, tenant_id, product_id, project_id?, title, spec, pri, status, stage,
      source, source_id, category, estimate, parent_id, keywords,
      assigned_to, opened_by, ai_assisted BOOL, ai_prompt_id)
StoryReview(id, tenant_id, story_id, reviewer_id, result, comment)

Task(id, tenant_id, project_id, sprint_id?, story_id?, parent_id,
     name, type, pri, estimate, consumed, left, status,
     assigned_to,                    -- 可以是 user_id 或 agent_id
     assignee_kind ENUM('user','agent'),    -- 🆕 一人多角 + Agent 是成员
     finished_by, finished_at,
     ai_assisted BOOL, agent_run_id)

Bug(id, tenant_id, product_id, project_id?, title, severity, type,
    steps, status, resolved_by, resolution, build_id, ai_triage JSON)

TestCase(id, tenant_id, product_id, lib_id?, title, pri, type, stage, status,
         preconditions, steps JSON, expected, version, ai_generated BOOL)
TestRun(id, tenant_id, case_id, build_id, runner_id, runner_kind ENUM('user','agent'),
        status, result, duration_ms, log)

Build(id, tenant_id, project_id, product_id?, name, builder, date, scm_path, scm_revision)
Release(id, tenant_id, build_id, product_id, name, date, marker)
Doc(id, tenant_id, product_id?, project_id?, space_id, title, content_md, lib, acl)
DocSpace(id, tenant_id, name, type, parent_id)
```

### 7.4 🆕 AI 后开发层（差异化核心）

```sql
-- Agent 是虚拟员工，可被指派为任务执行人
AIAgent(id, tenant_id, name, avatar, kind, system_prompt, model,
        tools JSON, capabilities JSON, scopes JSON,
        memory_policy, status, max_daily_cost_cents)
AgentRun(id, tenant_id, agent_id, project_id?, story_id?, task_id?,
         trigger_kind, trigger_by, prompt, status, started_at, finished_at,
         input_tokens, output_tokens, cost_cents, sandbox_id)
AgentMessage(id, tenant_id, run_id, role, content, tool_calls JSON, ts, token_count)
AgentMemory(id, tenant_id, agent_id, project_id?, key, value JSON,
            embedding vector?, source, ttl, created_at)
AgentTool(id, tenant_id, name, kind, config JSON, requires_approval BOOL)
AgentApproval(id, tenant_id, run_id, tool_name, payload JSON,
              requested_at, decided_by, decision, comment)

-- Prompt 模板与版本
PromptTemplate(id, tenant_id, name, version, body, vars JSON, owner_id, status)
PromptVersion(id, prompt_id, version, body, diff_from_prev, evaluated_score)

-- 多 Agent 工作流
WorkflowDef(id, tenant_id, name, graph JSON, status)
WorkflowRun(id, workflow_id, tenant_id, run_id, status, started_at, finished_at)

-- 一人公司预设 Agent
AgentPreset(id, code, name, avatar, kind, system_prompt, tools, scopes,
            is_default BOOL)
--  示例 preset: code='pm', 'dev', 'qa', 'support', 'ops'
```

### 7.5 🆕 SaaS 计费层

```sql
Plan(id, code, name, monthly_price_cents, seat_limit, ai_token_monthly,
     feature_flags JSON, status)                -- Free / Lite / Pro / Team
Subscription(id, tenant_id, plan_id, status, started_at, period_end, auto_renew)
Invoice(id, tenant_id, subscription_id?, amount_cents, currency, status, pdf_url)
SeatAssignment(id, tenant_id, user_id, assigned_at, source)

-- 算力商城
ComputePackage(id, code, name, tokens, valid_days, price_cents, status)  -- 月包/年包
ComputeOrder(id, tenant_id, package_id, amount_cents, status, paid_at, external_id)
ComputeBalance(id, tenant_id, balance_tokens, updated_at)

-- 用量计量
UsageMeter(id, tenant_id, metric, period, quantity, unit, recorded_at)
-- metric: ai_input_token / ai_output_token / tool_call / api_call / storage_gb
QuotaAlert(id, tenant_id, metric, threshold, fired_at)
```

### 7.6 商城体系（直接复用 zweq，建表沿用）

```sql
ShopProduct(id, tenant_id, kind, name, ...)              -- kind: gift / accessory / compute
ShopProductSku(id, product_id, attrs, price_cents, stock)
ShopOrder(id, tenant_id, user_id, total, status, ...)
ShopOrderProduct(id, order_id, sku_id, qty, price)
ShopAddress / ShopCart / ShopRefund / ShopComment / ShopFavorite
ShopCategory(id, tenant_id, parent_id, kind, name)      -- kind: gift/accessory/compute
ShopOutlet / ShopGroupon / ShopArticle / ShopWebhook
ShopBalancePlan / ShopInviteGift / ShopInviteRecord

Coupon(id, tenant_id, code, kind, value, valid_from, valid_to, status)
CouponUser(id, coupon_id, user_id, used_at)
PointsProduct / PointsOrder
MemberCardLevel(id, tenant_id, name, threshold, benefits JSON)
MemberAccount(id, user_id, level_id, points, balance_cents)

SeckillActivity / SeckillOrder
DrawRecord(id, tenant_id, user_id, prize_id, drawn_at)
Vote / VoteRecord
Distributor / CommissionRecord

MaterialNews(id, tenant_id, title, content, category, status)
MaterialFile(id, name, url, size, mime, category)

WechatMenu(id, tenant_id, mp_appid, menu JSON, status)  -- 自定义菜单
```

### 7.7 通知 / 审计 / 集成

```sql
Notification(id, tenant_id, user_id, type, payload JSON, read_at, channel)
AuditLog(id, tenant_id, actor_id, actor_kind, action, target_type, target_id,
         meta JSON, ip, ua, ts)
Webhook(id, tenant_id, name, url, secret, events JSON, status, last_delivery_at)
WebhookDelivery(id, webhook_id, event, payload, status, attempts, response)
IntegrationConfig(id, tenant_id, kind, config_encrypted JSON, status)
-- kind: gitlab / github / gitea / jenkins / lark / wecom
```

---

## 8. AI 团队设计（一人公司的核心差异化）

### 8.1 预置 Agent 模板

| 代码 | 名字 | 职责 | 默认工具 |
|---|---|---|---|
| `pm` | 产品 Agent | 写需求 / 拆任务 / 评审 / 出方案 | `doc.write` `task.write` `story.write` |
| `dev` | 开发 Agent | 编码 / 改 Bug / 重构 / PR | `git.read` `git.write` `file.edit` `shell.run*` `test.run` |
| `qa` | 测试 Agent | 写用例 / 跑测试 / 回归 / 报告 | `testcase.write` `test.run` `bug.write` |
| `support` | 客服 Agent | 回答工单 / 路由 / 复盘 | `ticket.read` `ticket.write` `notify.send` |
| `ops` | 运营 Agent | 监控 / 报表 / 提醒 / 排程 | `report.read` `cron.write` `notify.send` |

> `*` 表示需审批。

### 8.2 Agent 是一人多角的"分身"

在小程序"我的"→"身份切换"，用户可以一键切换当前角色（PM / 研发 / QA / 销售 / 客服），同时激活对应的 Agent 团队：
- 切到"PM"：高亮 PM Agent，默认对话入口
- 切到"研发"：高亮 Dev Agent，开放 `shell.run` 等高危工具
- 切到"销售"：高亮 Support Agent

### 8.3 Agent 可见 / 可指派 / 可审计

- **可见**：`assigned_to` 字段既可以指向 `user_id`，也可以指向 `agent_id`
- **指派**：把任务拖给小程序的 Agent 卡片 = 把任务分配给 Agent
- **审计**：每次 Run 完整记录，Webhook 通知用户
- **回滚**：代码类操作产生可回滚 patch；审批中可一键拒绝

---

## 9. 多租户与一人公司并存

zweq 原本支持多租户。ztao 在保留能力的同时提供 **一人公司模式**：

| 模式 | 适用 | 行为 |
|---|---|---|
| **Solo（默认）** | 1 人 | 注册即建 Tenant + Workspace + User + 5 个预置 Agent；不显示团队设置 |
| **Team** | 2~5 人 | 邀请成员；席位管理；共享 Agent |
| **Enterprise** | > 5 人 | 多 Workspace；SSO；审计留长；License 报价 |

切换入口在 Web 后台"组织设置"。

---

## 10. RBAC（精简版）

| Code | 中文 | 权限 |
|---|---|---|
| `founder` | 创始人 | 一切 + 计费 |
| `admin` | 管理员 | PM + 团队管理（不含计费） |
| `pm` | PM | 产品 / 需求 / 文档 |
| `rd` | 研发 | 任务 / Bug / 代码 |
| `qa` | 测试 | 用例 / 测试 / Bug 验证 |
| `sales` | 销售 | 商城 / 客户 / 工单 |
| `viewer` | 只读 | 只读 |
| `aiagent` | AI 员工 | 系统角色 · 受 tool scope 约束 |

一人公司模式下，默认 `founder` + 全套 Agent。

---

## 11. API 风格（沿用 zweq）

- 路径：`/api/v1/{module}/{id?}/{action?}`
- **小程序专用**：`/api/v1/mp/{module}/{action}`（字段精简、聚合友好）
- 参数：`{id}` 统一
- 响应：`{ code, msg, data }` / `{ code, msg, data: { list, total, page, page_size } }`
- 鉴权：`Authorization: Bearer <jwt>`；小程序走 `X-MP-Code` 拿 token
- 多租户：JWT `tid` claim，DTO 不含 `tenant_id`
- 错误码：`10000+` 通用 / `20000+` 业务 / `30000+` 鉴权

---

## 12. 部署与运行

```bash
# 后端（dev）
zig build test           # 单元 + 集成（SQLite 内存）
zig build run

# 小程序
cd mp && npm run dev:weapp
cd mp && npm run build:weapp

# Web 后台
cd web && npm run dev
cd web && npm run build

# 生产：Postgres
ZTAO_DB_DRIVER=postgres ZTAO_PG_CONNINFO=postgres://... ./ztao

# Docker
docker compose up -d      # postgres + ztao binary + minio
```

环境变量（`ZTAO_` 前缀）：
- `ZTAO_DB_DRIVER` `ZTAO_PG_CONNINFO`
- `ZTAO_JWT_SECRET` `ZTAO_AI_KEY_SECRET`
- `ZTAO_MP_APPID` `ZTAO_MP_SECRET` `ZTAO_PAY_MCHID` ...
- `ZTAO_DEFAULT_MODE` (solo | team)
- `ZTAO_DEFAULT_PLAN` (free)

---

## 13. 交付路线图（重排：小程序优先）

### M0 · 方案与脚手架（已完成 ✅）
- v0.2 方案落地 ✅
- README ✅

### M1 · 骨架 + 小程序登录（2 周）
- 迁移 zweq 工程脚手架；CI / Docker
- 注册基础 schema：tenant / user / role / permission / fan / identity
- 注册微信 BFF：`/api/v1/mp/auth/login`（`jscode2session`）
- 小程序工程脚手架（Taro 4）：Tab 壳 + 登录页 + 我的页占位
- 一人公司引导流：注册 → 自动建 tenant/workspace/user/agent 模板

### M2 · PM 核心 + 工作台（4 周）
- 注册 schema：product / project / sprint / story / task / bug / testcase / build / doc
- API 完整 + 小程序专用精简版
- 小程序工作台 Tab：今日待办 / 项目列表 / 任务详情 / Bug 详情 / 文档只读
- 小程序项目 Tab：迭代看板 / 需求 / Bug 列表
- 语音录入 → 自动归类为需求 / 任务 / Bug
- Web 后台 PM 视图：复盘用

### M3 · AI Copilot + Agent 团队（3 周）
- AI Providers 抽象（复用 zweq/ai）
- 5 个预置 Agent 模板注册
- 小程序 AI 对话气泡（流式输出 / 工具调用可视化）
- Agent 可被指派为任务执行人（task.assignee_kind='agent'）
- 审批流 + 成本仪表盘

### M4 · 算力商城 + 支付（3 周）
- 注册 schema：plan / subscription / computePackage / computeOrder / computeBalance
- 微信支付 v3（订阅 + 单次）
- 小程序算力商城：月包 / 年包 / 团队包
- 用量实时计量 + 阈值告警
- 算力耗尽自动降级 Agent 行为

### M5 · 礼品商城 + 配件商城（3 周）
- 复用 zweq/shop + coupon + points + distribution + member_card + seckill + vote + lucky_draw + material
- 三 Tab 商城：礼品 / 配件 / 算力（算力已上）
- 礼品商城：积分 + 现金；任务完成自动发券
- 配件商城：硬件 / 工具 / 模板；与 PM 工作流打通（资产登记）
- Web 后台运营视图

### M6 · 集成 + 打磨（持续）
- 飞书 / 企微通知 + 审批
- Git / GitLab / Jenkins 集成
- Open API + OpenAPI 文档
- SSO / 多语言 i18n
- 报表 / BI / AI Insights
- 多区域部署

---

## 14. 风险与对策

| 风险 | 对策 |
|---|---|
| 小程序审核被拒 | 避免诱导分享 / 虚拟支付合规；订阅消息显式授权 |
| AI 误操作 | 默认审批；高危工具（shell / deploy / db write）必须人工 confirm |
| AI 成本失控 | 实时计量 + 硬上限 + 模型路由用小模型优先；预算告警 |
| 算力耗尽降级 | Agent 自动进入 read-only 模式；用户收到提醒；推送续费券 |
| 多租户数据泄漏 | 物理列 + DAO 强制 + 跨租户 negative test |
| 商城支付合规 | 单 source 配置 License；订阅与一次性分离；退款走原路 |
| Agent 越权 | tool scope 强约束；按"身份切换"动态调整可用工具 |

---

## 15. 与禅道 / zweq 的能力差异

| 维度 | 禅道开源版 | zweq 原生 | ztao |
|---|---|---|---|
| 部署 | 单组织 self-host | 多租户 SaaS 底座 | 多租户 SaaS · 含商城 |
| 业务 | PM | 微信栈 + 商城 | PM + AI 团队 + 3 套商城 |
| 用户端 | Web | 微信小程序 + Web | **小程序为主 + Web 为辅** |
| AI | 无 | AI Provider 抽象 | **Agent = 一等公民 + 工作流** |
| 商城 | 无 | 完整电商 | **礼品 / 配件 / 算力 三套** |
| 计费 | License | 微信支付 v3 | **订阅 + 算力 + 商城** |
| 一人公司 | 不适合 | 通用 | **Solo 模式默认** |

---

## 16. Day-One 价值闭环

注册 → 1 分钟内拿到：

1. ✅ 一家"数字公司"（Tenant + Workspace + User）
2. ✅ 5 名 AI 员工（PM / Dev / QA / Support / Ops Agent）
3. ✅ 一个小程序入口（扫码登录）
4. ✅ 一句话让 PM Agent 写第一条需求
5. ✅ 一句话让 Dev Agent 拆 3 个任务
6. ✅ 一句话让 QA Agent 写 5 个用例
7. ✅ 微信付 1 元买 1000 token 开始用
8. ✅ 月底看仪表盘：花了多少、产出了什么、Agent 表现如何

这就是 ztao 的 Day-One 闭环。