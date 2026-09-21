import { create } from 'zustand';
import type { Agent, User, Tenant } from '@/services/api';

export interface Me {
  user: User;
  tenant: Tenant;
  workspace: { id: number; tenant_id: number; kind: string; name: string };
  plan: { code: string; name: string; seat_limit: number; ai_token_monthly: number };
  balance: { tokens: number; tokens_used_this_month: number; period_end: number };
  agents: Agent[];
  onboarding: { step: string; completed_steps: string[] };
}

interface AuthState {
  me: Me | null;
  agents: Agent[];
  setMe: (me: Me) => void;
  setAgents: (agents: Agent[]) => void;
  logout: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  me: null,
  agents: [],
  setMe: (me) => set({ me }),
  setAgents: (agents) => set({ agents }),
  logout: () => set({ me: null, agents: [] }),
}));