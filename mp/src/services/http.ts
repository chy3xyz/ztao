/**
 * 统一 HTTP 客户端：Taro.request + 拦截器 + 信封解析。
 *
 * 约定：
 *   - 所有响应 `{ code: number; msg: string; data: T }`，code === 0 为成功
 *   - 自动注入 Authorization / X-Mp-AppId / X-Request-Id
 *   - 401 时清 token + 通知上层
 */

import Taro from '@tarojs/taro';
import { nanoid } from 'nanoid';

const API_BASE = process.env.ZTAO_API_BASE || 'https://api.ztao.cn/api/v1';
const APP_ID = process.env.ZTAO_MP_APPID || 'wx0000000000000000';

export interface Envelope<T> {
  code: number;
  msg: string;
  data: T;
  request_id?: string;
}

export class ApiError extends Error {
  constructor(public code: number, public msg: string, public raw?: unknown) {
    super(msg);
    this.name = 'ApiError';
  }
}

let _unauthorizedHandler: () => void = () => {};

export function setUnauthorizedHandler(fn: () => void) {
  _unauthorizedHandler = fn;
}

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
  const token = Taro.getStorageSync('ztao_token');
  const headers: Record<string, string> = {
    'X-Mp-AppId': APP_ID,
    'X-Request-Id': nanoid(),
  };
  if (token) headers['Authorization'] = `Bearer ${token}`;

  let res: Taro.request.SuccessCallbackResult<Envelope<T>>;
  try {
    res = await Taro.request({
      url: `${API_BASE}${path}`,
      method: method as any,
      data: body,
      header: headers,
      timeout: 15000,
    });
  } catch (e) {
    throw new ApiError(10500, `网络错误：${(e as Error).message}`);
  }

  const env = res.data as Envelope<T>;
  if (env.code === 40101 || env.code === 30001 || env.code === 401) {
    _unauthorizedHandler();
    throw new ApiError(env.code, env.msg || '未登录');
  }
  if (env.code !== 0) {
    throw new ApiError(env.code, env.msg || '操作失败', env);
  }
  return env.data;
}

export const http = {
  get: <T>(p: string) => request<T>('GET', p),
  post: <T>(p: string, b?: unknown) => request<T>('POST', p, b),
  put: <T>(p: string, b?: unknown) => request<T>('PUT', p, b),
  delete: <T>(p: string) => request<T>('DELETE', p),
};