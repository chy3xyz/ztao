/** M3：算力账单与 Agent 审批 API */

import { http } from './http';

export const usageApi = {
  balance: () =>
    http.get<{
      tenant_id: number;
      balance_tokens: number;
      period_end: number;
      plan_code: string;
    }>('/mp/usage/balance'),
};

export const approvalApi = {
  listPending: () =>
    http.get<{
      list: {
        id: number;
        run_id: number;
        agent_id: number;
        tool_name: string;
        payload: string;
        requested_at: number;
      }[];
    }>('/mp/approval/pending'),
  decide: (id: number, decision: 'approved' | 'rejected', comment: string) =>
    http.post<{ ok: boolean }>(`/mp/approval/${id}/decide`, { decision, comment }),
};