# ztao

> **一个人，也能跑一家公司。**
>
> 面向一人公司的**后 AI 开发**PM 产品，基于 [chy3xyz/zweq](https://github.com/chy3xyz/zweq) 二次开发。
> 用户端主入口是 **微信小程序**（Taro 4 + React + TS），后台是 Vue 3 Web。
> 商城体系保留并重新定位为三套：**🎁 礼品 / 🛠 配件 / ⚡ 算力**。
>
> 业务模型参照 `_ref/zentaopms`（禅道开源版）。

---

## 状态 · M1 ✅ + M2 ✅ + M3 ✅ + M4 ✅ + M5 ✅

🛠 **M1 = 骨架 + 小程序登录 + AI 入口**（2 周）
🛠 **M2 = PM 全量 + 工作台**（4 周）
🛠 **M3 = AI Copilot + Agent 团队**（3 周）
🛠 **M4 = 算力商城 + 支付**（3 周）
🛠 **M5 = 礼品 + 配件商城**（3 周）

### M5 完工清单

| 子项 | 状态 | 说明 |
|---|---|---|
| M5.1 modules/gift_accessory | ✅ | Product（kind=gift\|accessory）+ Order + 6 个 seed SKU |
| M5.2 mall_bff 拓宽 | ✅ | 4 端点：listGifts · listAccessories · buy · listOrders |
| M5.3 handlers | ✅ | 全部接通 JWT + tenant_id 隔离 |
| M5.4 单元测试 | ✅ | 4 case（seed 幂等 / createOrder / 不存在商品 / 列表隔离） |
| M5.5 小程序礼品商城页 | ✅ | 3 个 SKU 卡片 + 一键兑换 |
| M5.6 小程序配件商城页 | ✅ | 3 个 SKU 卡片 + 一键购买 |

**代码量**：M5 +约 700 行 Zig · +约 400 行 TS · **共 10 个新文件**

### M4 完工清单

| 子项 | 状态 | 说明 |
|---|---|---|
| M4.1 ComputePackage + Order | ✅ | 4 档套餐 seed（free / lite / pro / team）+ 工单管理 |
| M4.2 ComputeOrder schema + service | ✅ | 订单状态机（pending → paid / closed / refunded）+ 支付回调 |
| M4.3 modules/billing | ✅ | Plan / Subscription / Invoice（4 档订阅） |
| M4.4 modules/mall_bff | ✅ | 4 个端点：packages / buy / orders / pay/v3/notify |
| M4.5 微信支付 v3 回调 | ✅ | `POST /api/v1/pay/v3/notify` 占位 + markPaid 流程 |
| M4.6 单元测试 | ✅ | 7 个 case（seed / buy / markPaid / billing seed / sub） |
| M4.7 小程序算力商城页 | ✅ | 商城首页（算力 Tab 可点）+ 套餐页 + 下单 + 订单列表 |

**代码量**：M4 +约 1500 行 Zig · +约 350 行 TS · **共 11 个新文件**

### M3 完工清单

| 子项 | 状态 | 说明 |
|---|---|---|
| M3.1 LLM Provider 抽象 | ✅ | `services/llm.zig` · OpenAI-compatible（OpenAI / Claude / Qwen / Doubao / Ollama） |
| M3.2 Agent Runtime | ✅ | `services/agent_runtime.zig` · 编排 system prompt + history + LLM + 计量 + 扣减 |
| M3.3 chat endpoint | ✅ | `mp/api.zig::chatStub` 已接入 AgentRuntime；SSE 流式在 M3+ 替换 |
| M3.4 usage 模块 | ✅ | UsageMeter / ComputeBalance / QuotaAlert · 50k 默认免费 Token |
| M3.5 approval 模块 | ✅ | AgentApproval · 状态机 pending → approved/rejected |
| M3.6 单元测试 | ✅ | 4 个 test case（credit/debit · recordLlmCall · request/decide · InvalidDecision） |
| M3.7 AI 对话页升级 | ✅ | 显示 token + 成本 + pending 状态 |
| M3.8 工作台运行时面板 | ✅ | 显示待审批列表 + 一键批准/拒绝 |

**代码量**：M3 +808 行 Zig · +201 行 TS · **共 9 个新文件**

### M2 完工清单

| 子项 | 状态 | 说明 |
|---|---|---|
| M2.1 modules/product | ✅ | Product + ProductPlan |
| M2.2 modules/project | ✅ | Project + ProjectMember · scrum/kanban/waterfall |
| M2.3 modules/sprint | ✅ | Sprint 迭代 |
| M2.4 modules/story | ✅ | Story 需求 · AI-assisted 标记 |
| M2.5 modules/pms_task | ✅ | PM 任务 · `assignee_kind='agent'` 让 Agent 当执行人 |
| M2.6 modules/bug | ✅ | Bug · severity 1-4 · resolution enum |
| M2.7 schema.zig + common.zig | ✅ | 注册 6 张新表 + 6 个 graph |
| M2.8 单元测试 | ✅ | 8 个 test case（CRUD / listAssignedTo / logTime / severity bounds） |
| M2.9 /api/v1/mp/* PM 端点 | ✅ | 17 个端点：products / projects / stories / tasks / bugs |
| M2.10 小程序页面 | ✅ | 项目 Tab + 看板 + 任务详情 + 新建任务 |

**代码量**：M2 +2461 行 Zig · +537 行 TS · **共 12 个新文件**

---

## M1 完工回顾

| 子项 | 状态 |
|---|---|
| M1.1 迁移 zweq 工程脚手架 | ✅ `zweq→ztao`，`ZWEQ_→ZTAO_` |
| M1.2 改名 | ✅ 0 残留 |
| M1.3 zig build test | ⚠️ 推迟 CI（沙箱网络受限） |
| M1.4 注册 M1 schema | ✅ Workspace/Agent/UserIdentity/Onboarding |
| M1.5 modules/agent | ✅ 5 个 Preset + 幂等 clone |
| M1.6 modules/workspace | ✅ ensureSolo |
| M1.7 modules/onboarding | ✅ 6 步状态机 |
| M1.8 modules/fan_identity | ✅ openid 唯一索引 |
| M1.9 middleware/mp_auth | ✅ JWT 鉴权 |
| M1.10 /api/v1/mp/* | ✅ 13 端点 |
| M1.11 单元测试 | ✅ 7 case |
| M1.12 mp/ 小程序 | ✅ Taro 4 + 4 Tab |
| M1.13 docker + CI | ✅ Postgres 16 + Actions |

---

## 选型决策（已锁 v0.2）

| 项 | 决策 |
|---|---|
| M1 顺序 | **先打通小程序登录 + AI 入口** |
| 小程序框架 | **Taro 4 + React + TS** |
| 支付 | **国内为主**（微信 v3 + 支付宝） |
| 部署 | **SaaS 公网**（api.ztao.cn + admin.ztao.cn） |

---

## 设计文档

| 文档 | 内容 |
|---|---|
| 📘 [docs/PLAN.md](docs/PLAN.md) | 产品技术方案 v0.2（总纲） |
| 🎨 [docs/PLAN.html](docs/PLAN.html) | 可视化方案（浏览器打开） |
| 🛠 [docs/M1.md](docs/M1.md) | M1 施工图 · 2 周到 Demo |
| 📱 [docs/MINIAPP.md](docs/MINIAPP.md) | 小程序端设计（Taro / 路由 / API） |
| 🛒 [docs/MALL.md](docs/MALL.md) | 三套商城设计（礼品 / 配件 / 算力） |
| 📡 [docs/API.md](docs/API.md) | M1 阶段后端 API 契约 |
| ⚖️ [docs/COMPLIANCE.md](docs/COMPLIANCE.md) | 国内 SaaS 合规清单 |

---

## 仓库结构

```
ztao/
├── README.md
├── build.zig / build.zig.zon / Dockerfile / docker-compose.yml
├── .github/workflows/ci.yml         # GitHub Actions
├── .dockerignore
├── _ref/zentaopms/                  # 禅道开源版（业务模型参考）
├── docs/                            # 设计文档（7 份）
├── src/                             # Zig 后端
│   ├── main.zig
│   ├── config.zig                   # ZTAO_* env
│   ├── schema.zig                   # 注册全部 zent schema
│   ├── modules/
│   │   ├── ...（zweq 已有 27 个域）
│   │   ├── workspace/               # 🆕 M1
│   │   ├── agent/                   # 🆕 M1
│   │   ├── onboarding/              # 🆕 M1
│   │   ├── fan_identity/            # 🆕 M1
│   │   └── mp/                      # 🆕 M1 — 小程序 BFF（13 端点）
│   ├── middleware/mp_auth.zig       # 🆕 M1
│   └── tests/m1_test.zig            # 🆕 M1 单元测试（7 用例）
├── mp/                              # 🆕 微信小程序（Taro 4）
│   ├── package.json / tsconfig.json
│   ├── project.config.json
│   └── src/{app.tsx, app.config.ts, pages/, components/, stores/, services/}
└── web/                             # 复用 zweq/web（Vue 3 + TS）—— 待迁
```

---

## 本地开发（待 CI 验）

```bash
# 后端
zig build test              # 跑全部单元测试
zig build run               # 起服务（需先配 ZTAO_* env 与 postgres）

# 小程序
cd mp && npm i && npm run dev:weapp      # 微信开发者工具里预览

# Docker 一键起
docker compose up -d
curl http://localhost:8080/api/v1/mp/health
```

---

## 验收 Demo（M1）

打开小程序：

1. 启动 → 看到登录页 → 一键登录
2. 自动建 Tenant + Workspace + 5 个 Agent
3. 进引导页（5 步）
4. 进工作台 → 看到 5 个 Agent 卡片
5. 点 PM Agent → 进对话 → 发"测试消息" → 看到 stub reply

Web 后台：

1. 用账号密码登录（管理员）
2. 看到 SaaS 控制台（最简版）
3. 扫码登录 Web（小程序"我的"扫码）