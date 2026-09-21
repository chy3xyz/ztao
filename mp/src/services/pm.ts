/** PM 模块 API 封装（M2）。 */

import { http } from './http';

export interface Product { id: number; name: string; code: string; status: string; description: string }
export interface Project { id: number; product_id: number; name: string; code: string; status: string; model: string }
export interface Story {
  id: number; product_id: number; project_id: number;
  title: string; spec: string; pri: number; status: string;
  stage: string; ai_assisted: boolean;
}
export interface Task {
  id: number; project_id: number; sprint_id: number; story_id: number;
  name: string; pri: number; status: string;
  estimate: number; consumed: number; left: number;
  assigned_to: number; assignee_kind: string; finished_at: number;
}
export interface Bug {
  id: number; product_id: number; project_id: number;
  title: string; severity: number; type_: string;
  status: string; resolution: string; assigned_to: number;
}

export const pmApi = {
  products: {
    list: () => http.get<{ list: Product[]; total: number }>('/mp/products'),
    create: (body: { name: string; code?: string; description?: string }) =>
      http.post<{ id: number }>('/mp/products', body),
  },
  projects: {
    list: () => http.get<{ list: Project[]; total: number }>('/mp/projects'),
    create: (body: { product_id: number; name: string; code?: string; model?: string }) =>
      http.post<{ id: number }>('/mp/projects', body),
    board: (id: number) =>
      http.get<{ todo: Task[]; doing: Task[]; done: Task[] }>(`/mp/projects/${id}/board`),
  },
  stories: {
    list: (product_id: number, status?: string) =>
      http.get<{ list: Story[]; total: number }>(
        `/mp/stories?product_id=${product_id}${status ? `&status=${status}` : ''}`,
      ),
    create: (body: { product_id: number; project_id?: number; title: string; spec?: string; ai_assisted?: boolean }) =>
      http.post<{ id: number }>('/mp/stories', body),
  },
  tasks: {
    list: (q: { mine?: boolean; project_id?: number }) => {
      const params = new URLSearchParams();
      if (q.mine) params.set('mine', 'true');
      if (q.project_id) params.set('project_id', String(q.project_id));
      return http.get<{ list: Task[]; total: number }>(`/mp/tasks?${params.toString()}`);
    },
    create: (body: {
      project_id: number; sprint_id?: number; story_id?: number;
      name: string; pri?: number; estimate?: number;
      assigned_to?: number; assignee_kind?: string;
    }) => http.post<{ id: number }>('/mp/tasks', body),
    get: (id: number) => http.get<Task>(`/mp/tasks/${id}`),
    patchStatus: (id: number, status: string) =>
      http.patch<{ ok: boolean }>(`/mp/tasks/${id}/status`, { status }),
    logTime: (id: number, hours: number) =>
      http.post<{ ok: boolean }>(`/mp/tasks/${id}/time`, { hours }),
  },
  bugs: {
    list: (product_id: number, status?: string) =>
      http.get<{ list: Bug[]; total: number }>(
        `/mp/bugs?product_id=${product_id}${status ? `&status=${status}` : ''}`,
      ),
    create: (body: {
      product_id: number; project_id?: number; title: string;
      severity?: number; type_?: string; steps?: string;
    }) => http.post<{ id: number }>('/mp/bugs', body),
    get: (id: number) => http.get<Bug>(`/mp/bugs/${id}`),
    resolve: (id: number, resolution: string) =>
      http.post<{ ok: boolean }>(`/mp/bugs/${id}/resolve`, { resolution }),
  },
};