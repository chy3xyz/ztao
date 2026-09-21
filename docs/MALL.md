# ztao Mall · 三套商城设计

> ztao 保留 zweq 全套商城模块，并重新定位为 **礼品商城 / 配件商城 / 算力商城**。
> 本文档说明每个模块在三套商城里的复用方式与差异化定制点。

---

## 0. 三大商城一览

| 商城 | 主用户 | 核心场景 | 复用 zweq 模块 | 定价 |
|---|---|---|---|---|
| 🎁 **礼品商城** | 用户 / 团队成员 | 任务达成 / 节日福利 / 客户答谢 / 邀请奖励 | `shop` + `coupon` + `points` + `member_card` + `seckill` + `lucky_draw` + `vote` + `material` + `distribution` | 现金 + 积分 + 券 |
| 🛠 **配件商城** | 一人公司 | 硬件 / 工具 / SaaS / 课程 / 模板 | `shop` + `material` + `menu` | 现金 |
| ⚡ **算力商城** | 一人公司 | AI Token / 模型包 / 团队席位 | `payment` + `cloud`（License/MarketPackage） + `computePackage/computeOrder/computeBalance`（🆕） | 现金 + 自动充值 |

> **关键差异化**：算力商城的购买结果是 **AI 可用资源**，与 `aiagent` 模块消耗直接挂钩；耗尽/降级会触发用户通知。

---

## 1. 🎁 礼品商城

### 1.1 商品分类

| 子类 | 例子 |
|---|---|
| 实物礼品 | 茶杯、钢笔、键鼠、小家电 |
| 数字礼品 | 电子书、模板、课程、字体、音乐 |
| 自定义礼品 | 上传图片 → AI 配文 → 生成电子贺卡 |
| 任务奖励 | 完成任务自动发的实物/券 |

### 1.2 复用 zweq 模块

| 模块 | 复用方式 |
|---|---|
| `shop` | 商品 / SKU / 订单 / 评价；`ShopProduct.kind='gift'` |
| `coupon` | 满减 / 折扣 / 兑换券；任务达成自动发 |
| `points` | 积分商城；签到/抽奖得积分；积分可抵现/兑换 |
| `member_card` | 等级体系（普通 / 银 / 金 / 钻石）；等级享包邮/折扣 |
| `seckill` | 节日秒杀 / 任务完成者独享 |
| `lucky_draw` | 每日抽奖 / 节日抽奖 |
| `vote` | 用户投票选品（"下一季新品"） |
| `material` | 营销图文、首页 banner |
| `distribution` | 邀请好友得积分（一级分销） |

### 1.3 差异化定制点

- **`gift.task_redeem`**：任务完成自动发券 — 新增 `ShopProduct.trigger_task_id`
- **`gift.bundle_with_task`**：礼品可与任务绑定（如完成任务送咖啡券）
- **`gift.auto_to_team`**：可一键把礼品送给团队成员（远程发券）

---

## 2. 🛠 配件商城

### 2.1 商品分类

| 子类 | 例子 |
|---|---|
| 硬件 | 显示器 / 机械键盘 / 笔记本支架 / 降噪耳机 / 摄像头 |
| 工具 SaaS | Notion / Figma / Cursor / JetBrains / 域名 / 云服务 |
| 模板 | PRD 模板 / 商业计划书 / 合同 / 发票模板 |
| 课程 | 创业课 / 产品课 / AI 课 / 编程课 |
| 实体书 | PM 必读 / 技术书 / 创业书 |

### 2.2 复用 zweq 模块

| 模块 | 复用方式 |
|---|---|
| `shop` | 商品 / SKU / 订单 / 评价；`ShopProduct.kind='accessory'` |
| `material` | 商品详情页图文 / 评测文章 |
| `menu` | 自定义类目导航（小程序底部 Tab 内二级菜单） |
| `coupon` | 通用券 |

### 2.3 差异化定制点

- **`accessory.asset_register`**：购买后自动登记到资产表（`UserAsset`，🆕）
  - 例：买显示器 → 自动加一条"戴尔 U2723QE · 2026-01-15 · 折旧率"
- **`accessory.workspace_aware`**：根据用户当前 Workspace 推荐（开发用机械键盘，销售用录音笔）
- **`accessory.review`**：必须含"使用场景"标签（"远程会议"、"编程"）

---

## 3. ⚡ 算力商城

### 3.1 商品分类

| 类型 | 例子 | 计费单位 |
|---|---|---|
| 月包 | Lite 100k / Pro 500k / Team 2M | token |
| 年包 | Pro 年包（折 8 折）/ Team 年包 | token |
| 团队包 | 5席 / 10席 | 席位 |
| 模型包 | 顶级模型 1M token 包 | token |
| 工具包 | 1000 次 `git.commit` + 1000 次 `test.run` | 次 |
| 自定义包 | 联系商务 | 现金 |

### 3.2 复用 zweq 模块

| 模块 | 复用方式 |
|---|---|
| `payment` | 微信支付 v3；`RechargeOrder`（已存在）+ `ComputeOrder`（🆕） |
| `cloud` | `License`（已有）用作能力开关；`MarketPackage`（已有）用作商品上架 |
| `cloud.MarketPackage` | 重定向：当作 `ComputePackage` 商品用 |

### 3.3 🆕 算力商城专有表

```sql
ComputePackage(id, code, name, tokens, valid_days, price_cents, status, sort)
ComputeOrder(id, tenant_id, package_id, amount_cents, status, paid_at, external_id)
ComputeBalance(id, tenant_id, balance_tokens, period_end, updated_at)

UsageMeter(id, tenant_id, metric, period, quantity, unit, recorded_at)
-- metric: ai_input_token / ai_output_token / tool_call / api_call / storage_gb
QuotaAlert(id, tenant_id, metric, threshold, fired_at, handled_at)
```

### 3.4 与 AI Agent 的联动

```
购买算力包 ─→ 微信支付 v3 ─→ 回调校验 ─→ ComputeBalance 加算力
                                              ↓
              AgentRun(input_tokens + output_tokens) 扣减
                                              ↓
                余量 < 阈值 ─→ 推送 + 商城入口
                                              ↓
               余量 = 0 ─→ Agent 自动进入 read-only 模式
```

**关键设计**：

- 算力扣减在 `AgentRun` 落库时同步减 `ComputeBalance`（事务）
- 算力耗尽：Agent 不报错，进入 read-only（仅可读，不可写）
- 购买算力后自动恢复 Agent 全功能
- 算力包可叠加购买；过期按购买时间倒序扣减

### 3.5 订阅（Plan）

| Plan | 月费 | 包含 |
|---|---|---|
| Free | ¥0 | 1 席 / 50k token / 基础 Agent |
| Lite | ¥29 | 1 席 / 200k token / 全 Agent |
| Pro | ¥99 | 1 席 / 1M token / 全 Agent + 工作流 |
| Team | ¥299 | 5 席 / 3M token / 全 Agent + API |

> 订阅通过 `subscription` 表管理；到期自动降级到 Free。
> 算力包与订阅分开购买（按需额外加量）。

---

## 4. 三套商城的统一架构

```
┌──────────────────────────────────────────────────────────────┐
│  商城前端（Taro 小程序 + Web 后台）                            │
│  ┌─────────────┬─────────────┬─────────────┐                │
│  │  礼品 Tab   │  配件 Tab   │  算力 Tab   │                │
│  └──────┬──────┴──────┬──────┴──────┬──────┘                │
└─────────┼─────────────┼─────────────┼───────────────────────┘
          │             │             │
          ▼             ▼             ▼
┌──────────────────────────────────────────────────────────────┐
│  统一商城 API（zweq/shop + payment + cloud + 🆕 compute）     │
│                                                              │
│  ShopCatalog · ShopTrade · ShopMarketing · Cloud / License     │
└──────────────┬───────────────────────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────┐
│  复用 + 扩展的 zweq 模块                                       │
│                                                              │
│  基础    : shop · coupon · points · member_card · seckill     │
│            · lucky_draw · vote · material · menu · payment    │
│            · cloud · module                                  │
│  新增 🆕 : ComputePackage · ComputeOrder · ComputeBalance     │
│            · UsageMeter · QuotaAlert · Subscription · Invoice │
└──────────────────────────────────────────────────────────────┘
```

---

## 5. 复用 vs 重写的取舍

| 决策 | 复用 | 自研 | 原因 |
|---|---|---|---|
| 商品 / SKU / 订单 | ✅ 复用 `shop` | — | 模型成熟、字段完整 |
| 优惠券 | ✅ 复用 `coupon` | — | 通用逻辑 |
| 积分 | ✅ 复用 `points` | — | 通用逻辑 |
| 会员卡 | ✅ 复用 `member_card` | — | 通用逻辑 |
| 秒杀 / 拼团 / 抽奖 / 投票 | ✅ 复用 | — | 通用逻辑 |
| 微信支付 | ✅ 复用 `payment` | — | v3 验签/回调完整 |
| License / 套餐 | ✅ 复用 `cloud.License` | — | 已有能力开关 |
| 算力商品 | — | 🆕 `ComputePackage/Order/Balance` | 必须与 AI 强联动 |
| 用量计量 | — | 🆕 `UsageMeter/QuotaAlert` | 通用但 zweq 没做 |
| 订阅 | — | 🆕 `Subscription/Invoice` | SaaS 必需 |

---

## 6. 数据流：用户从注册到第一次购物

```
注册 → 自动建 Tenant + Workspace + User + 5 个 Agent
  ↓
进入工作台 → AI 团队激活（PM/Dev/QA/Support/Ops）
  ↓
PM Agent 写第一条需求 → Dev Agent 拆 3 个任务 → QA Agent 写 5 个用例
  ↓
发现算力不够 → 弹"还剩 12k token，是否购买？"
  ↓
一键进算力商城 → 选月包 → 微信支付 v3 → 回调 → ComputeBalance 加算力
  ↓
继续工作 → 任务完成 → 系统自动发"任务完成券" → 礼品商城出现"咖啡券"
  ↓
兑换咖啡券 → 收货地址 → 微信支付（小额/积分） → 实物发货
  ↓
同时：完成里程碑 → 弹出"配件商城推荐：键鼠套装"（任务相关推荐）
```

---

## 7. Web 后台运营视图

Web 后台给"店主"用，必须看到：

- 商品管理：上架 / 下架 / 改价 / 改库存
- 订单管理：列表 / 详情 / 发货 / 退款
- 营销：优惠券 / 秒杀 / 拼团 / 抽奖 配置
- 算力管理：套餐上架 / 调价 / 阈值告警
- 会员卡：等级配置 / 权益调整
- 素材：首页 banner / 商品详情图
- 数据：GMV / 订单量 / 用户分布 / 算力消耗趋势

---

## 8. 合规与运营

- **商品审核**：上架需后台审核（资质 / 类目 / 价格）
- **退款**：原路退回（微信 v3 支持）
- **发票**：个人开发者可月累计开票（`Invoice` 表）
- **物流**：对接快递 100 / 菜鸟；`ShopOrder` 带物流单号
- **分销**：合规三级以内；提现走 `payment.Withdraw`
- **数据安全**：地址 / 手机号加密存储