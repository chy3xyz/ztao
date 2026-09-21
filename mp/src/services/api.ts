/** 类型定义 + 各端点封装 */

import { http } from './http';

export interface User {
  id: number;
  tenant_id: number;
  workspace_id: number;
  name: string;
  avatar: string;
  role: 'founder' | 'admin' | 'pm' | 'rd' | 'qa' | 'sales' | 'viewer';
  plan: 'free' | 'lite' | 'pro' | 'team';
}

export interface Tenant {
  id: number;
  name: string;
  slug: string;
  plan_code: string;
}

export interface Workspace {
  id: number;
  tenant_id: number;
  kind: 'solo' | 'team' | 'enterprise';
  name: string;
}

export interface Agent {
  id: number;
  preset_code: 'pm' | 'dev' | 'qa' | 'support' | 'ops';
  name: string;
  avatar: string;
  status: 'active' | 'paused' | 'deleted';
  model: string;
}

export interface LoginResp {
  token: string;
  expires_at: number;
  user: User;
  tenant: Tenant;
  workspace: Workspace;
  agents: Agent[];
  onboarding: { step: string; completed_steps: string[] };
}

export const api = {
  auth: {
    login: (body: {
      code: string;
      encryptedData?: string;
      iv?: string;
      nickname?: string;
      avatar?: string;
    }) => http.post<LoginResp>('/mp/auth/login', body),
    refresh: () => http.post<{ token: string; expires_at: number }>('/mp/auth/refresh'),
    logout: () => http.post<{ ok: true }>('/mp/auth/logout'),
    qr: () =>
      http.get<{ qr_token: string; expires_at: number; qr_url: string }>('/mp/auth/qr'),
  },
  me: {
    get: () =>
      http.get<{
        user: User;
        plan: { code: string; name: string; seat_limit: number; ai_token_monthly: number };
        balance: { tokens: number; tokens_used_this_month: number; period_end: number };
        agents: Agent[];
        onboarding: { step: string; completed_steps: string[] };
      }>('/mp/me'),
    onboardingNext: (step: string) =>
      http.post<{ ok: true; next_step: string | null }>('/mp/me/onboarding/next', { step }),
    switchRole: (role: string) =>
      http.post<{ ok: true; role: string; activated_agents: number[] }>('/mp/me/role', { role }),
  },
  ai: {
    listAgents: () => http.get<{ list: Agent[] }>('/mp/ai/agents'),
    getAgent: (id: number) =>
      http.get<{ agent: Agent & Record<string, unknown>; stats: unknown }>(`/mp/ai/agents/${id}`),
    chat: (agent_id: number, message: string) =>
      http.post<{
        session_id: number;
        run_id: number;
        stub_reply: string;
        tokens_input: number;
        tokens_output: number;
        cost_cents: number;
        is_stub: boolean;
      }>('/mp/ai/chat', { agent_id, message }),
  },
  health: () => http.get<{ ok: true; version: string; build_at: string }>('/mp/health'),
  meta: () =>
    http.get<{
      app_name: string;
      tabs: string[];
      subscribe_scenes: { id: string; title: string; keywords: string[] }[];
      support_qq: string;
      links: { user_agreement: string; privacy: string };
    }>('/mp/meta'),
};