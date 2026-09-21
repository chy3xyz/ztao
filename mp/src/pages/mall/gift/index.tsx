import { useEffect, useState } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { giftApi, MallProduct } from '@/services/gift';

export default function GiftMall() {
  const [list, setList] = useState<MallProduct[]>([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    refresh();
  }, []);

  const refresh = async () => {
    setBusy(true);
    try {
      const r = await giftApi.listGifts();
      setList(r.list);
    } finally {
      setBusy(false);
    }
  };

  const onRedeem = async (p: MallProduct) => {
    try {
      const resp = await giftApi.buy(p.code, 1);
      Taro.showModal({
        title: '兑换成功',
        content: `${p.name}\n订单 #${resp.order_id}\n${resp.note}`,
        showCancel: false,
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
          background: 'linear-gradient(135deg, #b06367, #4a6a8c)',
          color: '#fff',
          marginBottom: 12,
        }}
      >
        <Text style={{ fontSize: 18, fontWeight: 600 }}>🎁 礼品商城</Text>
        <View style={{ marginTop: 6 }}>
          <Text style={{ fontSize: 12, opacity: 0.85 }}>
            任务奖励 · 客户答谢 · 节日福利
          </Text>
        </View>
      </View>

      {list.map((p) => (
        <View key={p.code} className="card" style={{ borderLeft: '4px solid #b06367' }}>
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
                    background: 'rgba(176,99,103,0.10)',
                    color: '#b06367',
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
              {p.price_cents === 0 ? (
                <Text style={{ fontSize: 16, color: '#2f6f5e', fontWeight: 600 }}>
                  积分兑换
                </Text>
              ) : (
                <View style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
                  <Text style={{ fontSize: 18, color: '#b06367', fontWeight: 700 }}>
                    ¥{(p.price_cents / 100).toFixed(2)}
                  </Text>
                  {p.original_price_cents > p.price_cents && (
                    <Text className="muted" style={{ fontSize: 11, textDecoration: 'line-through' }}>
                      ¥{(p.original_price_cents / 100).toFixed(2)}
                    </Text>
                  )}
                </View>
              )}
              <Text className="muted" style={{ fontSize: 10 }}>
                库存 {p.stock}
              </Text>
            </View>
            <View
              onClick={() => onRedeem(p)}
              style={{
                padding: '6px 16px',
                background: '#b06367',
                color: '#fff',
                borderRadius: 16,
                fontSize: 13,
              }}
            >
              兑换
            </View>
          </View>
        </View>
      ))}
    </ScrollView>
  );
}