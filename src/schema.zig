//! Shared zent schema graph for the whole application.
//!
//! Every module registers its schemas here so a single `StoreEnv` can
//! migrate the full schema and expose one type-safe client to all stores
//! (zigmodu + zent best practice: one client, schema-as-code in one place).

const zent = @import("zent");

const user_model = @import("modules/user/model.zig");
const task_model = @import("modules/task/model.zig");
const file_model = @import("modules/file/model.zig");
const notify_model = @import("modules/notify/model.zig");
const tenant_model = @import("modules/tenant/model.zig");
const audit_model = @import("modules/audit/model.zig");
const mail_template_model = @import("modules/mail_template/model.zig");
const ai_model = @import("modules/ai/model.zig");
const account_model = @import("modules/account/model.zig");
const permission_model = @import("modules/permission/model.zig");
const setting_model = @import("modules/setting/model.zig");
const rule_model = @import("modules/rule/model.zig");
const member_model = @import("modules/member/model.zig");
const message_model = @import("modules/message/model.zig");
const app_module_model = @import("modules/module/model.zig");
const payment_model = @import("modules/payment/model.zig");
const cloud_model = @import("modules/cloud/model.zig");
const material_model = @import("modules/material/model.zig");
const checkin_model = @import("modules/checkin/model.zig");
const shop_model = @import("modules/shop/model.zig");
const distribution_model = @import("modules/distribution/model.zig");
const member_card_model = @import("modules/member_card/model.zig");
const seckill_model = @import("modules/seckill/model.zig");
const vote_model = @import("modules/vote/model.zig");
const coupon_model = @import("modules/coupon/model.zig");
const lucky_draw_model = @import("modules/lucky_draw/model.zig");
const menu_model = @import("modules/menu/model.zig");
const points_model = @import("modules/points/model.zig");

// ── ztao M1 new modules ──
const workspace_model = @import("modules/workspace/model.zig");
const agent_model = @import("modules/agent/model.zig");
const fan_identity_model = @import("modules/fan_identity/model.zig");
const onboarding_model = @import("modules/onboarding/model.zig");

// ── ztao M2 PM core ──
const product_model = @import("modules/product/model.zig");
const project_model = @import("modules/project/model.zig");
const sprint_model = @import("modules/sprint/model.zig");
const story_model = @import("modules/story/model.zig");
const pms_task_model = @import("modules/pms_task/model.zig");
const bug_model = @import("modules/bug/model.zig");

// ── ztao M3 AI runtime ──
const usage_model = @import("modules/usage/model.zig");
const approval_model = @import("modules/approval/model.zig");

// ── ztao M4 SaaS billing / compute mall ──
const compute_model = @import("modules/compute/model.zig");
const billing_model = @import("modules/billing/model.zig");

// ── ztao M5 gift + accessory mall ──
const gift_accessory_model = @import("modules/gift_accessory/model.zig");

// zent's `buildGraph` comptime edge-resolution has a per-call branch quota;
// keeping the graph small avoids it, so the app schema and each domain
// cluster are built as small graphs and their types merged.
const graph = zent.codegen.graph.buildGraph(&.{
    tenant_model.Tenant,
    user_model.User,
    user_model.PasswordToken,
    user_model.EmailVerification,
    task_model.Task,
    file_model.File,
    file_model.UploadGroup,
    notify_model.Notification,
    audit_model.AuditLog,
});
const template_graph = zent.codegen.graph.buildGraph(&.{mail_template_model.EmailTemplate});
const ai_graph = zent.codegen.graph.buildGraph(&.{
    ai_model.AiProvider,
    ai_model.AiSession,
    ai_model.AiMessage,
    ai_model.AiApproval,
    ai_model.AiRun,
});
const account_graph = zent.codegen.graph.buildGraph(&.{
    account_model.Account,
    account_model.AccountWechat,
});
const permission_graph = zent.codegen.graph.buildGraph(&.{
    permission_model.Role,
    permission_model.Permission,
    permission_model.UserRole,
    permission_model.RolePermission,
});
const setting_graph = zent.codegen.graph.buildGraph(&.{setting_model.SiteSetting});
const rule_graph = zent.codegen.graph.buildGraph(&.{
    rule_model.Rule,
    rule_model.RuleKeyword,
    rule_model.RuleReply,
});
const member_graph = zent.codegen.graph.buildGraph(&.{ member_model.Fan, member_model.FanTag });
const message_graph = zent.codegen.graph.buildGraph(&.{message_model.MessageLog});
const app_module_graph = zent.codegen.graph.buildGraph(&.{
    app_module_model.AppModule,
    app_module_model.ModuleBinding,
});
const payment_graph = zent.codegen.graph.buildGraph(&.{
    payment_model.Wallet,
    payment_model.RechargeOrder,
    payment_model.Withdraw,
});
const cloud_graph = zent.codegen.graph.buildGraph(&.{
    cloud_model.License,
    cloud_model.MarketPackage,
    cloud_model.DynamicTable,
});
const material_graph = zent.codegen.graph.buildGraph(&.{
    material_model.MaterialNews,
    material_model.MaterialFile,
});
const checkin_graph = zent.codegen.graph.buildGraph(&.{checkin_model.CheckinRecord});
const shop_graph = zent.codegen.graph.buildGraph(&.{ shop_model.ShopCategory, shop_model.ShopProduct, shop_model.ShopProductSku, shop_model.ShopCart, shop_model.ShopAddress, shop_model.ShopOrder, shop_model.ShopOrderProduct, shop_model.ShopRefund, shop_model.ShopComment, shop_model.ShopFavorite, shop_model.ShopOutlet, shop_model.ShopBalancePlan, shop_model.ShopGroupon, shop_model.ShopGrouponTeam, shop_model.ShopInviteGift, shop_model.ShopInviteRecord, shop_model.ShopArticle, shop_model.ShopWebhook });
const distribution_graph = zent.codegen.graph.buildGraph(&.{ distribution_model.Distributor, distribution_model.CommissionRecord });
const member_card_graph = zent.codegen.graph.buildGraph(&.{ member_card_model.MemberCardLevel, member_card_model.MemberAccount });
const seckill_graph = zent.codegen.graph.buildGraph(&.{ seckill_model.SeckillActivity, seckill_model.SeckillOrder });
const vote_graph = zent.codegen.graph.buildGraph(&.{ vote_model.Vote, vote_model.VoteRecord });
const lucky_draw_graph = zent.codegen.graph.buildGraph(&.{lucky_draw_model.DrawRecord});
const coupon_graph = zent.codegen.graph.buildGraph(&.{ coupon_model.Coupon, coupon_model.CouponUser });
const menu_graph = zent.codegen.graph.buildGraph(&.{menu_model.WechatMenu});
const points_graph = zent.codegen.graph.buildGraph(&.{ points_model.PointsProduct, points_model.PointsOrder });

// ── ztao M1 graphs ──
const workspace_graph = zent.codegen.graph.buildGraph(&.{workspace_model.Workspace});
const agent_graph = zent.codegen.graph.buildGraph(&.{
    agent_model.AgentPreset,
    agent_model.AgentInstance,
    agent_model.AgentMemory,
});
const fan_identity_graph = zent.codegen.graph.buildGraph(&.{fan_identity_model.UserIdentity});
const onboarding_graph = zent.codegen.graph.buildGraph(&.{onboarding_model.OnboardingState});

// ── ztao M2 PM core graphs ──
const product_graph = zent.codegen.graph.buildGraph(&.{
    product_model.Product,
    product_model.ProductPlan,
});
const project_graph = zent.codegen.graph.buildGraph(&.{
    project_model.Project,
    project_model.ProjectMember,
});
const sprint_graph = zent.codegen.graph.buildGraph(&.{sprint_model.Sprint});
const story_graph = zent.codegen.graph.buildGraph(&.{story_model.Story});
const pms_task_graph = zent.codegen.graph.buildGraph(&.{pms_task_model.Task});
const bug_graph = zent.codegen.graph.buildGraph(&.{bug_model.Bug});

// ── ztao M3 AI runtime graphs ──
const usage_graph = zent.codegen.graph.buildGraph(&.{
    usage_model.UsageMeter,
    usage_model.ComputeBalance,
    usage_model.QuotaAlert,
});
const approval_graph = zent.codegen.graph.buildGraph(&.{approval_model.AgentApproval});

// ── ztao M4 SaaS / compute mall graphs ──
const compute_graph = zent.codegen.graph.buildGraph(&.{
    compute_model.ComputePackage,
    compute_model.ComputeOrder,
});
const billing_graph = zent.codegen.graph.buildGraph(&.{
    billing_model.Plan,
    billing_model.Subscription,
    billing_model.Invoice,
});

// ── ztao M5 graphs ──
const gift_accessory_graph = zent.codegen.graph.buildGraph(&.{
    gift_accessory_model.Product,
    gift_accessory_model.Order,
});

pub const infos = graph.types ++
    template_graph.types ++
    ai_graph.types ++
    account_graph.types ++
    permission_graph.types ++
    setting_graph.types ++
    rule_graph.types ++
    member_graph.types ++
    message_graph.types ++
    app_module_graph.types ++
    payment_graph.types ++
    cloud_graph.types ++
    material_graph.types ++
    checkin_graph.types ++
    lucky_draw_graph.types ++
    coupon_graph.types ++
    vote_graph.types ++
    seckill_graph.types ++
    member_card_graph.types ++
    distribution_graph.types ++
    shop_graph.types ++
    menu_graph.types ++
    points_graph.types ++
    // ── ztao M1 ──
    workspace_graph.types ++
    agent_graph.types ++
    fan_identity_graph.types ++
    onboarding_graph.types ++
    // ── ztao M2 PM ──
    product_graph.types ++
    project_graph.types ++
    sprint_graph.types ++
    story_graph.types ++
    pms_task_graph.types ++
    bug_graph.types ++
    // ── ztao M3 AI runtime ──
    usage_graph.types ++
    approval_graph.types ++
    // ── ztao M4 ──
    compute_graph.types ++
    billing_graph.types ++
    // ── ztao M5 ──
    gift_accessory_graph.types;
pub const Client = zent.codegen.client.Client(infos);
