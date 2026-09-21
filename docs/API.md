# ztao · API 契约（M1 版）

> M1 阶段后端 API 完整契约。所有端点均走 `/api/v1/mp/*`（小程序专用前缀）。
> 鉴权：`Authorization: Bearer <jwt>`，除标注 `public` 外均需鉴权。
> 统一响应信封：`{ code: number, msg: string, data: T }`，`code === 0` 为成功。

---

## 0. 通用约定

### 0.1 通用 Header

| Header | 必填 | 说明 |
|---|---|---|
| `Authorization` | 大部分 | `Bearer <jwt>` |
| `X-Mp-AppId` | 必填 | 微信小程序 AppID |
| `X-Request-Id` | 建议 | 客户端 UUID；后端原样回写，便于排查 |
| `X-Client-Version` | 建议 | 小程序版本（如 `1.0.0`） |

### 0.2 错误码

| 区间 | 含义 |
|---|---|
| `0` | 成功 |
| `10001~10999` | 通用错误（参数错误 / 服务异常 / 资源不存在） |
| `20001~20999` | 业务错误（鉴权失败 / 算力不足 / 商品下架） |
| `30001~30999` | 安全（IP 黑名单 / 风控 / 频控） |
| `40001~40999` | 第三方（微信 / 支付宝 / AI Provider 错误） |

### 0.3 分页响应

```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "list": [],
    "total": 123,
    "page": 1,
    "page_size": 20
  }
}
```

---

## 1. Auth

### 1.1 `POST /api/v1/mp/auth/login`  (public)

微信小程序登录，同时完成一人公司引导。

**Request Body**
```json
{
  "code": "081aBcD1kF2gH3iJ",
  "encryptedData": "CiQ0eHBhA...",   // 可选 · 用于拿 unionid
  "iv": "rF1nC2jW3kK4lL5",            // 可选
  "nickname": "Neo",                  // 可选 · 用户主动填
  "avatar": "https://..."             // 可选
}
```

**Response 200**
```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "token": "eyJhbGciOi...",
    "expires_at": 1789872310,
    "user": {
      "id": 1,
      "tenant_id": 1,
      "workspace_id": 1,
      "name": "Neo",
      "avatar": "https://...",
      "role": "founder",
      "plan": "free"
    },
    "tenant": {
      "id": 1,
      "name": "Neo 的公司",
      "slug": "neo-7f8a",
      "plan_code": "free"
    },
    "workspace": {
      "id": 1,
      "tenant_id": 1,
      "kind": "solo",
      "name": "默认 Workspace"
    },
    "agents": [
      { "id": 1, "preset_code": "pm",       "name": "产品 Agent",   "avatar": "📋", "status": "active" },
      { "id": 2, "preset_code": "dev",      "name": "开发 Agent",   "avatar": "💻", "status": "active" },
      { "id": 3, "preset_code": "qa",       "name": "测试 Agent",   "avatar": "🧪", "status": "active" },
      { "id": 4, "preset_code": "support",  "name": "客服 Agent",   "avatar": "🎧", "status": "active" },
      { "id": 5, "preset_code": "ops",      "name": "运营 Agent",   "avatar": "📊", "status": "active" }
    ],
    "onboarding": {
      "step": "agents_ready",
      "completed_steps": ["login", "workspace", "agents_ready"]
    }
  }
}
```

**错误码**
- `10401` `code` 缺失或格式错
- `40401` 微信 jscode2session 失败（code 无效 / appid 配置错）
- `10500` 服务器错误

### 1.2 `POST /api/v1/mp/auth/refresh`

**Request Body**
```json
{ "token": "eyJhbGciOi..." }
```

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": { "token": "eyJhbGciOi...", "expires_at": 1789872310 }
}
```

**错误码**
- `30001` token 已过期且 refresh 失败

### 1.3 `POST /api/v1/mp/auth/logout`

**Response 200**
```json
{ "code": 0, "msg": "ok", "data": { "ok": true } }
```

### 1.4 `GET /api/v1/mp/auth/qr`  (public)

生成扫码登录 Web 后台的二维码。

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "qr_token": "uuid-v4-string",
    "expires_at": 1789872370,
    "qr_url": "weixin://wxpay/bizpayurl?pr=..." 
  }
}
```

### 1.5 `POST /api/v1/mp/auth/scan-confirm`

小程序扫了 Web 二维码后调用，确认登录。

**Request Body**
```json
{ "qr_token": "uuid-v4-string", "platform": "web" }
```

**Response 200**
```json
{ "code": 0, "msg": "ok", "data": { "ok": true } }
```

---

## 2. Me

### 2.1 `GET /api/v1/mp/me`

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "user": { "id": 1, "tenant_id": 1, "name": "Neo", "avatar": "...", "role": "founder" },
    "workspace": { "id": 1, "kind": "solo", "name": "默认 Workspace" },
    "plan": { "code": "free", "name": "Free", "seat_limit": 1, "ai_token_monthly": 50000 },
    "balance": { "tokens": 50000, "tokens_used_this_month": 0, "period_end": 1792464000 },
    "agents": [ ... 同登录返回 ],
    "onboarding": { "step": "first_chat", "completed_steps": ["login", "workspace", "agents_ready"] }
  }
}
```

### 2.2 `POST /api/v1/mp/me/onboarding/next`

推进引导状态。

**Request Body**
```json
{ "step": "first_chat" }
```

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": { "ok": true, "next_step": "first_task" }
}
```

**错误码**
- `20402` 步骤顺序错（不能跳过）
- `20403` 步骤已完成

### 2.3 `POST /api/v1/mp/me/role`

切换当前角色（一人多角）。

**Request Body**
```json
{ "role": "rd" }
```

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "ok": true,
    "role": "rd",
    "activated_agents": [2]   // Dev Agent
  }
}
```

### 2.4 `POST /api/v1/mp/me/subscribe`

批量开启订阅消息场景。

**Request Body**
```json
{ "scene_ids": ["task_assigned", "ai_done", "quota_alert"] }
```

**Response 200**
```json
{ "code": 0, "msg": "ok", "data": { "ok": true, "subscribed": ["task_assigned", "ai_done", "quota_alert"] } }
```

---

## 3. AI

### 3.1 `GET /api/v1/mp/ai/agents`

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "list": [
      {
        "id": 1, "preset_code": "pm", "name": "产品 Agent", "avatar": "📋",
        "status": "active", "model": "stub",
        "stats": { "runs": 0, "tokens": 0, "cost_cents": 0 }
      },
      ...
    ]
  }
}
```

### 3.2 `GET /api/v1/mp/ai/agents/{id}`

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "agent": {
      "id": 1, "preset_code": "pm", "name": "产品 Agent", "avatar": "📋",
      "system_prompt": "你是 Founder 的产品经理 Agent...",
      "tools": ["doc.write", "task.write", "story.write"],
      "scopes": ["product", "story", "task", "doc"],
      "memory_policy": "session",
      "max_daily_cost_cents": 5000,
      "status": "active"
    },
    "stats": { "runs": 0, "tokens": 0, "cost_cents": 0, "last_run_at": null }
  }
}
```

### 3.3 `POST /api/v1/mp/ai/chat`  (M1 stub)

**Request Body**
```json
{
  "agent_id": 1,
  "message": "我想做一个登录功能",
  "context": { "project_id": null, "task_id": null }
}
```

**Response 200**（M1 stub）
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "session_id": 12,
    "run_id": 0,
    "stub_reply": "M1 占位 · M3 接真实模型。已收到：「我想做一个登录功能」",
    "tokens_input": 0,
    "tokens_output": 0,
    "cost_cents": 0,
    "is_stub": true
  }
}
```

> M1 固定返回 `stub_reply`；M3 接 LLM + 流式 SSE。

### 3.4 `GET /api/v1/mp/ai/runs`

**Query**
- `agent_id?` `limit?`（默认 20）`cursor?`

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "list": [
      {
        "id": 1, "agent_id": 1, "session_id": 12,
        "prompt": "我想做一个登录功能",
        "status": "stub_done",
        "started_at": 1789872310, "finished_at": 1789872311,
        "tokens_input": 0, "tokens_output": 0, "cost_cents": 0
      }
    ],
    "cursor": null
  }
}
```

### 3.5 `GET /api/v1/mp/ai/runs/{id}`

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "run": { "id": 1, "agent_id": 1, "status": "stub_done", "...": "..." },
    "messages": [
      { "id": 1, "role": "user", "content": "我想做一个登录功能", "ts": 1789872310 },
      { "id": 2, "role": "agent", "content": "M1 占位 ...", "ts": 1789872311 }
    ]
  }
}
```

---

## 4. Health & Meta

### 4.1 `GET /api/v1/mp/health`  (public)

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "ok": true,
    "version": "0.1.0",
    "build_at": "2026-09-20T10:00:00Z",
    "db": "postgres",
    "uptime_seconds": 3600
  }
}
```

### 4.2 `GET /api/v1/mp/meta`  (public)

应用级元信息（用于前端拉取 tab / banner 文案）。

**Response 200**
```json
{
  "code": 0, "msg": "ok",
  "data": {
    "app_name": "ztao",
    "tabs": ["workspace", "project", "mall", "me"],
    "subscribe_scenes": [
      { "id": "task_assigned", "title": "任务分配通知", "keywords": ["任务名", "项目名"] },
      ...
    ],
    "support_qq": "888-8888",
    "links": {
      "user_agreement": "https://ztao.cn/legal/user",
      "privacy": "https://ztao.cn/legal/privacy"
    }
  }
}
```

---

## 5. 错误响应示例

```json
{
  "code": 10401,
  "msg": "code 不能为空",
  "data": null,
  "request_id": "uuid-v4"
}
```

```json
{
  "code": 20401,
  "msg": "算力不足，请购买 Token 包",
  "data": {
    "balance": { "tokens": 0 },
    "suggest_package_id": 2
  },
  "request_id": "uuid-v4"
}
```

---

## 6. M1 实现检查清单

后端实现时确保：

- [ ] 所有 MP 路由 `module_name = "mp"`，`nest = &.{}`（统一前缀 `/api/v1/mp`）
- [ ] 所有 handler 第一行 `mp_auth.requireFanOpenid(ctx)`
- [ ] 所有 DB 写入带 `tenant_id`（从 JWT `tid` 读）
- [ ] 所有写操作落 `AuditLog`
- [ ] 错误响应统一用 `ctx.sendErrorResponse(code, httpStatus, msg)`
- [ ] `health` / `auth/login` / `auth/refresh` / `meta` 标记 `public` 跳过 JWT
- [ ] 所有时间字段为 Unix 秒（i64）
- [ ] `M1.md` 验收清单 8 项全过

---

## 7. 后续 M 阶段 API 增量

| 阶段 | 新增端点 |
|---|---|
| M2 | `/mp/projects/*` `/mp/tasks/*` `/mp/bugs/*` `/mp/stories/*` `/mp/docs/*` `/mp/workspace/voice` |
| M3 | `/mp/ai/chat` 改 SSE 流式 + `/mp/ai/approval/*` + `/mp/ai/agents/{id}/tools` |
| M4 | `/mp/mall/compute/*` `/mp/billing/*` 微信支付回调 `/pay/v3/notify` |
| M5 | `/mp/mall/gift/*` `/mp/mall/accessory/*` `/mp/mall/cart` `/mp/mall/checkout` `/mp/mall/orders` `/mp/mall/coupons` `/mp/mall/points` `/mp/mall/member` `/mp/mall/checkin` `/mp/mall/draw` |
| M6 | `/mp/integrations/*` `/mp/reports/*` `/mp/export/*` |

---

## 8. 参考：zweq 已有的 MP 端点（可复用）

来源：`/tmp/zweq-src/src/modules/app_bff/fan_api.zig`

```
GET  /api/v1/app/fan/profile
GET  /api/v1/app/points/products
POST /api/v1/app/points/redeem
GET  /api/v1/app/points/orders
GET  /api/v1/app/coupons
POST /api/v1/app/coupons/{id}/claim
GET  /api/v1/app/my-coupons
GET  /api/v1/app/lucky-draw/records
GET  /api/v1/app/lucky-draw/config
POST /api/v1/app/lucky-draw/draw
GET  /api/v1/app/wallet
```

> ztao M1 不复用这套（M1 不接商单）；但 M5 可重命名后挂在 `/mp/mall/*` 下，作为商城基座。
> 鉴权中间件：沿用 `src/middleware/fan_auth.zig`（`fan_auth.requireFanOpenid`）。

---

## 9. 自动化测试清单（M1 必过）

- [ ] 集成测试：`auth/login` happy path
- [ ] 集成测试：`auth/login` 二次登录同账号不重复建 tenant
- [ ] 集成测试：`auth/login` 二次登录不同账号自动建第二个 tenant
- [ ] 集成测试：`onboarding/next` 顺序约束
- [ ] 集成测试：`me` 401 无 token / 200 有 token
- [ ] 集成测试：`ai/agents` 返回 5 个
- [ ] 集成测试：`ai/chat` 返回 stub_reply
- [ ] 集成测试：`health` public 200
- [ ] 集成测试：错误信封格式（`code !== 0` 时 `msg` 有值）

> 框架：沿用 zweq 的 `src/tests.zig` + `openMemory` helper（M1 用 Postgres test container，更稳）。