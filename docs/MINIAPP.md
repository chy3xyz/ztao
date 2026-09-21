# ztao Mini Program · 小程序端设计

> ztao 的主操作面。Taro 4（React + TS），一码多端（先发微信，后续可加支付宝/抖音）。
> 后端走 zweq 现有 REST API；新增 `/api/v1/mp/*` 移动端专用端点（字段精简、聚合、列表轻）。

---

## 0. 设计原则

1. **手机里能完成 80% 工作** — 任何需要查数据、改状态、看进度的操作必须能在小程序里完成
2. **极简录入** — 语音/拍照/转写/自然语言 → 自动归类
3. **AI 对话即工作** — Chat panel 是核心交互，不是辅助功能
4. **能少一步是一步** — 三次点击内必须触达；超过则改设计
5. **离线可用** — 弱网/无网时，本地缓存最近任务和草稿
6. **暗色优先** — 一人公司常晚上用；OLED 友好

---

## 1. 技术栈

| 层 | 选型 | 说明 |
|---|---|---|
| 框架 | **Taro 4** | React 18 + TS；编译到微信小程序 |
| 状态 | Zustand + 持久化 | 小而美；自动写本地 storage |
| 网络 | Taro.request + 拦截器 | 注入 token / 解析信封 / 重试 |
| 实时 | WebSocket（主）+ SSE（备） | AI 流式输出 |
| UI | 自研 + NutUI（如必要） | 统一设计语言 |
| 录音 | `Taro.getRecorderManager` + ASR | 语音录入 |
| 拍照 | `Taro.chooseImage` + OSS 直传 | 拍照提 Bug |
| 位置 | `Taro.getLocation`（按需） | 考勤 / 外勤打卡 |
| 推送 | 微信订阅消息 + 服务通知 | 8 个场景 |

---

## 2. 工程结构

```
mp/
├── config/                  # Taro 配置 + 环境变量
├── src/
│   ├── app.tsx              # 入口 / 全局 store / 推送初始化
│   ├── app.config.ts        # 微信小程序 app.json（pages / tabBar / window）
│   ├── pages/
│   │   ├── workspace/       # Tab 1 · 工作台
│   │   ├── project/         # Tab 2 · 项目
│   │   ├── mall/            # Tab 3 · 商城
│   │   ├── me/              # Tab 4 · 我的
│   │   ├── auth/            # 登录
│   │   ├── ai/              # AI 对话（被多 Tab 复用）
│   │   ├── story/           # 需求详情
│   │   ├── task/            # 任务详情
│   │   ├── bug/             # Bug 详情
│   │   ├── doc/             # 文档只读
│   │   ├── order/           # 订单详情
│   │   ├── agent/           # Agent 详情
│   │   └── approval/        # 审批中心
│   ├── components/
│   │   ├── ChatBubble/      # AI 对话气泡
│   │   ├── KanbanColumn/    # 看板列
│   │   ├── TaskCard/
│   │   ├── AgentAvatar/     # 头像 + 状态指示
│   │   ├── UsageRing/       # 用量环形
│   │   ├── VoiceInput/      # 录音 + 转写
│   │   ├── ScanQR/          # 扫码登录 Web
│   │   └── ...
│   ├── stores/
│   │   ├── auth.ts
│   │   ├── tenant.ts
│   │   ├── project.ts
│   │   ├── task.ts
│   │   ├── agent.ts
│   │   └── usage.ts
│   ├── services/
│   │   ├── http.ts          # axios-like 封装 + 拦截器
│   │   ├── auth.ts
│   │   ├── ai.ts            # 流式请求（SSE）
│   │   └── ws.ts            # WebSocket
│   └── utils/
│       ├── format.ts
│       ├── token.ts
│       └── recorder.ts
└── package.json
```

---

## 3. 页面与路由

### 3.1 Tab 栏

| Tab | 路径 | 图标 | 角标 |
|---|---|---|---|
| 工作台 | `pages/workspace/index` | 🏠 | 待办数 |
| 项目 | `pages/project/index` | 📁 | 当前项目未读 |
| 商城 | `pages/mall/index` | 🛍 | 新品 |
| 我的 | `pages/me/index` | 👤 | 未读通知 |

### 3.2 工作台（Tab 1）

| 页面 | 路由 | 入口 |
|---|---|---|
| 今日待办 | `workspace/today` | 默认 |
| 晨间简报 | `workspace/briefing` | 顶部卡 |
| AI 团队 | `workspace/agents` | 顶部卡 |
| 我的项目 | `workspace/projects` | 卡片 |
| 数据卡片 | `workspace/metrics` | 卡片组 |
| 语音录入 | `workspace/voice` | FAB（右下） |
| 全局搜索 | `workspace/search` | 顶栏 |

**关键交互**

- **晨间简报**：进入 App 推送；AI Agent 自动总结昨日 + 今日待办
- **数据卡片**：今日 token / 本月成本 / 本月产出；点击进 usage
- **语音录入**：长按 FAB 录音 → 松手自动 ASR → AI 分类 → 落到需求/任务/Bug
- **AI 团队**：横向滑动看 5 个 Agent；点击进对话；长按编辑/删除

### 3.3 项目（Tab 2）

| 页面 | 路由 | 说明 |
|---|---|---|
| 项目列表 | `project/list` | 默认 |
| 切换项目 | `project/switch` | 顶部项目选择器 |
| 迭代看板 | `project/board?sprintId=` | 拖拽改状态 |
| 需求列表 | `project/stories` | 按状态过滤 |
| 需求详情 | `story/detail?id=` | 评论 / 关联 / 转任务 |
| 任务列表 | `project/tasks` | 按指派人过滤 |
| 任务详情 | `task/detail?id=` | 工时 / 评论 / 改状态 |
| Bug 列表 | `project/bugs` | 按严重度 |
| Bug 详情 | `bug/detail?id=` | 拍照 / 重现 / 关联 |
| 用例列表 | `project/cases` | 看 AI 写的用例 |
| 文档 | `doc/list` | 树形 |
| 文档 | `doc/detail?id=` | 只读 + 简单编辑 |
| 版本 | `project/builds` | 列表 |

### 3.4 商城（Tab 3）

| 页面 | 路由 | 说明 |
|---|---|---|
| 商城首页 | `mall/index` | Banner + 三 Tab |
| 礼品商城 | `mall/gift` | 商品列表 |
| 配件商城 | `mall/accessory` | 商品列表 |
| 算力商城 | `mall/compute` | 套餐列表 |
| 商品详情 | `mall/product?id=` | 规格 / 评论 / 加购 |
| 购物车 | `mall/cart` | 仅礼品/配件 |
| 订单确认 | `mall/checkout` | 收货 / 优惠 / 支付 |
| 订单列表 | `mall/orders` | 我的订单 |
| 订单详情 | `order/detail?id=` | 物流 / 退款 |
| 算力账单 | `mall/usage` | 实时 token |
| 优惠券 | `mall/coupons` | 我的券 |
| 积分 | `mall/points` | 流水 + 商品 |
| 会员卡 | `mall/member` | 等级 + 权益 |
| 签到/抽奖 | `mall/checkin` | 每日福利 |

### 3.5 我的（Tab 4）

| 页面 | 路由 | 说明 |
|---|---|---|
| 我的主页 | `me/index` | 头像 / 身份 / 账单摘要 |
| 身份切换 | `me/role` | PM / RD / QA / 销售 / 客服 |
| AI 团队管理 | `me/agents` | 增删改 Agent |
| 我的 Agent 详情 | `agent/detail?id=` | 工具 / 记忆 / 统计 |
| 算力账单 | `me/billing` | 充值 / 余额 / 消费 |
| 我的订单 | `mall/orders` | 复用 |
| 优惠券/积分/卡 | `mall/coupons` 等 | 复用 |
| 数据出境 | `me/export` | 一键导出 JSON/CSV |
| 设置 | `me/settings` | 通知 / 隐私 |
| 关于 | `me/about` | 版本 / 协议 |
| 扫码登录 Web | `me/scan` | 切换 Tab 临时 |

---

## 4. 登录与身份

### 4.1 登录流程

```
┌──────────────────────────────────────────────────────────────┐
│ 用户首次打开                                                  │
│  ↓ wx.login → code                                           │
│  ↓ POST /api/v1/mp/auth/login { code, encryptedData? }       │
│  ↓ 后端 jscode2session → openid + session_key                │
│  ↓ 首次注册：自动创建 Tenant + Workspace + User + 5 Agent     │
│  ↓ 返回 JWT (tid + uid + role)                               │
│  ↓ 写入 Taro.setStorageSync('ztao_token', jwt)               │
└──────────────────────────────────────────────────────────────┘
```

### 4.2 身份切换（一人多角）

一人公司创始人一人多角：早上 PM、中午研发、晚上销售。小程序支持：

- **当前身份**：默认 `founder`；可手动切到 `pm` / `rd` / `qa` / `sales` / `viewer`
- **Agent 联动**：切换身份后，对应 Agent 进入"激活"状态，对话优先
- **工具 scope**：研发身份开放 `shell.run`；PM 身份开放 `doc.write`；销售身份开放 `notify.send`

### 4.3 扫码登录 Web 后台

- 小程序"我的"→ 临时切换 Tab "扫码登录"
- 扫 Web 端二维码 → 自动把 Web 端踢上登录态（同 zweq 扫码登录机制）

---

## 5. AI 对话交互（核心）

### 5.1 入口

- **AI 团队卡**：横向滑动 → 点击 Agent 进对话
- **任务详情右下 FAB**："问 Agent" → 自动带上任务上下文
- **Bug 详情**："让 Agent 帮我看看" → 自动带上 Bug 上下文
- **工作台"晨间简报"**：AI Agent 主动推送
- **语音录入**：转写后直接进对话 → 智能分类到 PM 模块

### 5.2 消息气泡

- **User**：右对齐，浅色背景
- **Agent**：左对齐，Agent 头像 + 名字
- **Tool call**：中间折叠块，标"调用了 file.edit"
- **流式输出**：单字追加，底部小竖线闪烁
- **错误**：红边，可重试
- **审批请求**：金色块，"是否允许 Agent 删除 x？" → 同意 / 拒绝

### 5.3 流式连接

- **首选 SSE**（`POST /api/v1/mp/ai/chat` with `text/event-stream`）
- **备选 WebSocket**（`wss://api.ztao.cn/mp/ai/stream?token=...`）
- 客户端断线自动重连，重连后带 `last_message_id` 续传

---

## 6. 通知与推送

### 8 个订阅消息场景（用户主动勾选）

| 场景 | 模板 |
|---|---|
| 任务被分配给我 | 任务标题 · 项目 · 优先级 |
| 任务被 @ | 任务标题 · 评论摘要 |
| Bug 紧急 | Bug 标题 · 严重度 |
| AI 完成 | 任务标题 · 耗时 · 摘要 |
| AI 需要审批 | 工具名 · 操作摘要 |
| 算力不足 | 余量 · 推荐套餐 |
| 商城订单状态 | 订单号 · 状态 |
| 团队里程碑达成 | 项目名 · 完成率 |

---

## 7. 后端 API 端点（小程序专用）

所有端点走 `/api/v1/mp/*`，鉴权：`Authorization: Bearer <jwt>`。

### 7.1 Auth
```
POST /api/v1/mp/auth/login          { code, encryptedData?, iv? }  → { token, user, tenant, agents }
POST /api/v1/mp/auth/refresh                                       → { token }
POST /api/v1/mp/auth/bind-phone    { phone, smsCode }              → { ok }
```

### 7.2 工作台
```
GET  /api/v1/mp/workspace/today                                    → { todos, metrics, briefing }
GET  /api/v1/mp/workspace/briefing                                 → { text, ts }
GET  /api/v1/mp/workspace/metrics?period=day|month                → { tokens, cost_cents, output_count }
POST /api/v1/mp/workspace/voice   { audio, format }                → { text, classified_as, target_id? }
```

### 7.3 项目 / 任务 / Bug
```
GET    /api/v1/mp/projects                                         → { list, total }
GET    /api/v1/mp/projects/{id}                                    → { project, sprints, members }
GET    /api/v1/mp/projects/{id}/board?sprintId=                   → { columns: { todo, doing, review, done } }
GET    /api/v1/mp/projects/{id}/stories?status=&assignedTo=        → { list }
GET    /api/v1/mp/stories/{id}                                     → { story, comments, related }
POST   /api/v1/mp/stories                                          → { id }
GET    /api/v1/mp/tasks?status=&mine=true                         → { list }
GET    /api/v1/mp/tasks/{id}                                       → { task, comments, time_logs, agent_run? }
PATCH  /api/v1/mp/tasks/{id}/status   { status }                  → { ok }
POST   /api/v1/mp/tasks/{id}/time     { hours, note }             → { ok }
POST   /api/v1/mp/tasks/{id}/comment  { content }                 → { ok }
GET    /api/v1/mp/bugs?status=&severity=                           → { list }
GET    /api/v1/mp/bugs/{id}                                        → { bug, steps, comments }
POST   /api/v1/mp/bugs           { images[], title? }              → { id }   ← 拍照直传
GET    /api/v1/mp/docs/{id}                                        → { doc }
```

### 7.4 AI
```
POST /api/v1/mp/ai/chat             { agent_id, message, context? } → SSE stream
GET  /api/v1/mp/ai/agents                                        → { list }
GET  /api/v1/mp/ai/runs?agentId=&limit=                          → { list }
GET  /api/v1/mp/ai/runs/{id}                                     → { run, messages }
POST /api/v1/mp/ai/approval/{runId}  { decision, comment? }       → { ok }
```

### 7.5 商城
```
GET  /api/v1/mp/mall/banners                                      → { list }
GET  /api/v1/mp/mall/{kind}              kind: gift|accessory|compute → { list, total }
GET  /api/v1/mp/mall/products/{id}                                → { product, skus, comments }
GET  /api/v1/mp/mall/compute/packages                             → { list }      ← 算力包
GET  /api/v1/mp/mall/compute/balance                              → { tokens, used_today, period_end }

POST /api/v1/mp/mall/cart                { sku_id, qty }          → { ok }
GET  /api/v1/mp/mall/cart                                         → { items, total }
POST /api/v1/mp/mall/checkout           { cart_ids[], coupon? }  → { order_id, pay_params }
POST /api/v1/mp/mall/pay/notify                                       ← 微信回调（不走 mp）
GET  /api/v1/mp/mall/orders                                         → { list }
GET  /api/v1/mp/mall/orders/{id}                                    → { order }
POST /api/v1/mp/mall/orders/{id}/refund                            → { ok }

GET  /api/v1/mp/mall/coupons                                       → { list }
GET  /api/v1/mp/mall/points                { balance, history }    → ...
GET  /api/v1/mp/mall/member               { level, benefits, points, balance }
POST /api/v1/mp/mall/checkin                                        → { points, today_done }
POST /api/v1/mp/mall/draw                                           → { prize? }
```

### 7.6 我的 / 团队
```
GET  /api/v1/mp/me                       { user, role, current_workspace, balance }
POST /api/v1/mp/me/role                  { role }                 → { ok, activated_agents }
GET  /api/v1/mp/me/billing               { plan, balance, history } → ...
GET  /api/v1/mp/me/usage                 { period, items }         → ...
POST /api/v1/mp/me/export                { scope }                 → { job_id }
GET  /api/v1/mp/me/export/{job_id}                                 → { url }
POST /api/v1/mp/me/scan/web              { token }                 → { ok }   ← 扫码登录 Web
POST /api/v1/mp/me/subscribe             { scene_ids[] }           → { ok }
```

---

## 8. 性能与体验

### 8.1 启动

- 启动 < 1.5s（P50）
- 首屏直接渲染缓存的工作区数据
- 并行请求：今日待办 + 简报 + 指标 + 通知数

### 8.2 网络

- 全局请求拦截器：注入 `Authorization` / `X-Request-Id`
- 统一信封：`{ code, msg, data }`
- 重试：网络错误自动重试 2 次；401 自动 refresh
- 离线缓存：最近任务列表 + 草稿（IndexedDB on h5；Storage on mp）

### 8.3 体验细节

- 所有列表支持**下拉刷新 + 触底加载**
- **左滑操作**：任务详情左滑 → 改状态 / 重新打开 / 指派
- **长按**：通用长按编辑 / 删除 / 复制
- **震动反馈**：完成任务 → 短震；审批通过 → 双震
- **暗色主题**：默认；可切换

---

## 9. 安全

- 后端校验 `X-MP-AppId` 与 `code` 对应关系
- 业务敏感数据（手机号、邮箱）走 `mp_auth` 中间件 + scope 检查
- 所有写操作产生 AuditLog
- 算力支付回调验签（沿用 zweq/payment）

---

## 10. 小程序审核合规清单

- ✅ 用户协议 + 隐私政策（首次启动弹窗）
- ✅ 微信支付仅用于实物/虚拟商品/订阅（合规类目：工具 / 效率）
- ✅ 不诱导分享 / 不强制关注公众号
- ✅ 订阅消息显式勾选，不默认开启
- ✅ 内容安全：文本走 `msgSecCheck`（小程序自带）；图片走 `imgSecCheck`
- ✅ 用户主动注销 / 数据导出 / 撤回授权