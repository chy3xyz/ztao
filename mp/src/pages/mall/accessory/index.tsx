import { useEffect, useState } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { giftApi, MallProduct } from '@/services/gift';

export default function AccessoryMall() {
  const [list, setList] = useState<MallProduct[]>([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    refresh();
  }, []);

  const refresh = async () => {
    setBusy(true);
    try {
      const r = await giftApi.listAccessories();
      setList(r.list);
    } finally {
      setBusy(false);
    }
  };

  const onBuy = async (p: MallProduct) => {
    try {
      const resp = await giftApi.buy(p.code, 1);
      Taro.showModal({
        title: '已加入订单',
        content: `${p.name}\n¥${(p.price_cents / 100).toFixed(2)} · 订单 #${resp.order_id}\n${resp.note}`,
        showCancel: false,
        success: () => {
          Taro.navigateTo({ url: '/pages/mall/orders/index' });
        },
      });
    } catch (e) {
      Taro.showToast({ title: (e as Error).message, icon: 'none' });
    }
  };

  return (
    <ScrollView scrollY className="container">
      <View
        style={{
          padding: '20px 16px',
          borderRadius: 14,
          background: 'linear-gradient(135deg, #4a6a8c, #2f6f5e)',
          color: '#fff',
          marginBottom: 12,
        }}
      >
        <Text style={{ fontSize: 18, fontWeight: 600 }}>🛠 配件商城</Text>
        <View style={{ marginTop: 6 }}>
          <Text style={{ fontSize: 12, opacity: 0.85 }}>
            硬件 · 工具 SaaS · 课程 · 模板
          </Text>
        </View>
      </View>

      {list.map((p) => (
        <View key={p.code} className="card" style={{ borderLeft: '4px solid #4a6a8c' }}>
          <View style={{ display: 'flex', alignItems: 'center' }}>
            <View
              style={{
                fontSize: 36,
                width: 64,
                height: 64,
                borderRadius: 12,
                background: '#fafafa',
                textAlign: 'center',
                lineHeight: '64px',
                marginRight: 12,
              }}
            >
              {p.image}
            </View>
            <View style={{ flex: 1 }}>
              <View style={{ fontWeight: 600 }}>{p.name}</View>
              <Text className="muted" style={{ fontSize: 11 }}>
                {p.description}
              </Text>
              <View style={{ marginTop: 4 }}>
                <Text
                  style={{
                    fontSize: 10,
                    padding: '2px 6px',
                    borderRadius: 3,
                    background: 'rgba(74,106,140,0.10)',
                    color: '#4a6a8c',
                  }}
                >
                  {p.category}
                </Text>
              </View>
            </View>
          </View>

          <View
            style={{
              marginTop: 10,
              paddingTop: 10,
              borderTop: '1px dashed #e9e3d6',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
            }}
          >
            <View>
              <View style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
                <Text style={{ fontSize: 18, color: '#4a6a8c', fontWeight: 700 }}>
                  ¥{(p.price_cents / 100).toFixed(0)}
                </Text>
                {p.original_price_cents > p.price_cents && (
                  <Text className="muted" style={{ fontSize: 11, textDecoration: 'line-through' }}>
                    ¥{(p.original_price_cents / 100).toFixed(0)}
                  </Text>
                )}
              </View>
              <Text className="muted" style={{ fontSize: 10 }}>
                库存 {p.stock}
              </Text>
            </View>
            <View
              onClick={() => onBuy(p)}
              style={{
                padding: '6px 16px',
                background: '#4a6a8c',
                color: '#fff',
                borderRadius: 16,
                fontSize: 13,
              }}
            >
              购买
            </View>
          </View>
        </View>
      ))}
    </ScrollView>
  );
}