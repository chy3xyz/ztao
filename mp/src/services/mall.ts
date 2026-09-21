/** 算力商城 API · M4 */

import { http } from './http';

export interface ComputePackage {
  code: string;
  name: string;
  description: string;
  tokens: number;
  bonus_tokens: number;
  price_cents: number;
  kind: string;
  seat: number;
}

export interface ComputeOrder {
  id: number;
  package_code: string;
  amount_cents: number;
  status: string;
  granted_tokens: number;
  paid_at: number;
}

export const mallApi = {
  compute: {
    list: () =>
      http.get<{ list: ComputePackage[] }>('/mp/mall/compute/packages'),
    buy: (package_code: string) =>
      http.post<{
        order_id: number;
        pay_params: {
          timeStamp: string;
          nonceStr: string;
          package: string;
          signType: string;
          paySign: string;
        };
        note: string;
      }>('/mp/mall/compute/buy', { package_code }),
    listOrders: () =>
      http.get<{ list: ComputeOrder[] }>('/mp/mall/compute/orders'),
  },
};