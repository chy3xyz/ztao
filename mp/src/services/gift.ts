/** M5 · 礼品 / 配件商城 API */

import { http } from './http';

export interface MallProduct {
  code: string;
  name: string;
  description: string;
  image: string;
  price_cents: number;
  original_price_cents: number;
  stock: number;
  category: string;
}

export interface MallOrder {
  id: number;
  kind: string;
  product_code: string;
  quantity: number;
  amount_cents: number;
  status: string;
  created_at: number;
}

export const giftApi = {
  listGifts: () => http.get<{ list: MallProduct[] }>('/mp/mall/gift'),
  listAccessories: () => http.get<{ list: MallProduct[] }>('/mp/mall/accessory'),
  buy: (code: string, quantity?: number) =>
    http.post<{ order_id: number; note: string }>('/mp/mall/buy', {
      code,
      quantity: quantity ?? 1,
    }),
  listOrders: () => http.get<{ list: MallOrder[] }>('/mp/mall/orders'),
};