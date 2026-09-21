import { useEffect, useState } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { mallApi, ComputePackage } from '@/services/mall';

const KIND_ACCENT: Record<string, { color: string; bg: string; label: string }> = {
  month: { color: '#2f6f5e', bg: 'rgba(47,111,94,0.10)', label: '月包' },
  year: { color: '#c97b3f', bg: 'rgba(201,123,63,0.10)', label: '年包' },
  team: { color: '#4a6a8c', bg: 'rgba(74,106,140,0.10)', label: '团队' },
  custom: { color: '#b06367', bg: 'rgba(176,99,103,0.10)', label: '定制' },
};

export default function ComputeMall() {
  const [list, setList] = useState<ComputePackage[]>([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    refresh();
  }, []);

  const refresh = async () => {
    setBusy(true);
    try {
      const r = await mallApi.compute.list();
      setList(r.list);
    } finally {
      setBusy(false);
    }
  };

  const onBuy = async (pkg: ComputePackage) => {
    if (pkg.price_cents === 0) {
      Taro.showToast({ title: '免费套餐无需购买', icon: 'none' });
      return;
    }
    try {
      const resp = await mallApi.compute.buy(pkg.code);
      Taro.showModal({
        title: `${pkg.name} ¥${(pkg.price_cents / 100).toFixed(2)}`,
        content: `${(pkg.tokens + pkg.bonus_tokens).toLocaleString()} token\nM4 占位：未接入微信支付 v3；点确认模拟下单成功`,
        confirmText: '确认',
        success: (r) => {
          if (r.confirm) {
            Taro.showToast({ title: `订单 #${resp.order_id} 已创建`, icon: 'success' });
            setTimeout(() => Taro.navigateTo({ url: '/pages/mall/orders/index' }), 1000);
          }
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
          background: 'linear-gradient(135deg, #c97b3f, #b06367)',
          color: '#fff',
          marginBottom: 12,
        }}
      >
        <Text style={{ fontSize: 18, fontWeight: 600 }}>⚡ 算力商城</Text>
        <View style={{ marginTop: 6 }}>
          <Text style={{ fontSize: 12, opacity: 0.85 }}>
            买 Token · 升级套餐 · 团队席位
          </Text>
        </View>
      </View>

      {list.map((p) => {
        const accent = KIND_ACCENT[p.kind] ?? KIND_ACCENT.month;
        const totalTokens = p.tokens + p.bonus_tokens;
        const isFree = p.price_cents === 0;
        return (
          <View key={p.code} className="card" style={{ borderLeft: `4px solid ${accent.color}` }}>
            <View style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <View style={{ flex: 1 }}>
                <View style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <Text style={{ fontSize: 16, fontWeight: 600 }}>{p.name}</Text>
                  <Text
                    style={{
                      fontSize: 10,
                      padding: '2px 6px',
                      borderRadius: 3,
                      background: accent.bg,
                      color: accent.color,
                    }}
                  >
                    {accent.label}
                  </Text>
                </View>
                <View style={{ marginTop: 4 }}>
                  <Text className="muted">{p.description}</Text>
                </View>
              </View>
              <View style={{ textAlign: 'right' }}>
                {isFree ? (
                  <Text style={{ fontSize: 18, color: accent.color, fontWeight: 600 }}>免费</Text>
                ) : (
                  <Text style={{ fontSize: 20, color: accent.color, fontWeight: 700 }}>
                    ¥{(p.price_cents / 100).toFixed(0)}
                  </Text>
                )}
                <View>
                  <Text className="muted" style={{ fontSize: 10 }}>
                    {p.seat} 席
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
              }}
            >
              <View>
                <Text style={{ fontSize: 13, fontWeight: 600 }}>
                  {(p.tokens / 1000).toFixed(0)}k token
                </Text>
                {p.bonus_tokens > 0 && (
                  <Text className="muted" style={{ fontSize: 10 }}>
                    + 赠送 {(p.bonus_tokens / 1000).toFixed(0)}k
                  </Text>
                )}
              </View>
              <View
                onClick={() => onBuy(p)}
                style={{
                  padding: '6px 16px',
                  background: accent.color,
                  color: '#fff',
                  borderRadius: 16,
                  fontSize: 13,
                }}
              >
                {isFree ? '使用中' : '购买'}
              </View>
            </View>
          </View>
        );
      })}
    </ScrollView>
  );
}