import { useEffect, useState } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import { mallApi, ComputeOrder } from '@/services/mall';

const STATUS_META: Record<string, { label: string; color: string; bg: string }> = {
  pending: { label: '待支付', color: '#7c7a72', bg: 'rgba(124,122,114,0.10)' },
  paid: { label: '已支付', color: '#2f6f5e', bg: 'rgba(47,111,94,0.10)' },
  closed: { label: '已关闭', color: '#b06367', bg: 'rgba(176,99,103,0.10)' },
  refunded: { label: '已退款', color: '#4a6a8c', bg: 'rgba(74,106,140,0.10)' },
};

export default function ComputeOrders() {
  const [list, setList] = useState<ComputeOrder[]>([]);

  useEffect(() => {
    mallApi.compute.listOrders().then((r) => setList(r.list)).catch(() => undefined);
  }, []);

  return (
    <ScrollView scrollY className="container">
      <View className="title">算力订单</View>

      {list.length === 0 ? (
        <View className="card">
          <Text className="muted">还没有订单</Text>
        </View>
      ) : (
        list.map((o) => {
          const meta = STATUS_META[o.status] ?? STATUS_META.pending;
          return (
            <View key={o.id} className="card">
              <View style={{ display: 'flex', justifyContent: 'space-between' }}>
                <View>
                  <Text style={{ fontWeight: 600 }}>{o.package_code.toUpperCase()}</Text>
                  <Text className="muted">#{o.id}</Text>
                </View>
                <Text
                  style={{
                    fontSize: 10,
                    padding: '2px 8px',
                    borderRadius: 3,
                    background: meta.bg,
                    color: meta.color,
                    alignSelf: 'flex-start',
                  }}
                >
                  {meta.label}
                </Text>
              </View>
              <View style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
                <Text className="muted">金额</Text>
                <Text>¥{(o.amount_cents / 100).toFixed(2)}</Text>
              </View>
              {o.status === 'paid' && (
                <View style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
                  <Text className="muted">到账</Text>
                  <Text style={{ color: '#2f6f5e', fontWeight: 600 }}>
                    + {o.granted_tokens.toLocaleString()} token
                  </Text>
                </View>
              )}
              {o.paid_at > 0 && (
                <View style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
                  <Text className="muted">支付时间</Text>
                  <Text style={{ fontSize: 11 }}>
                    {new Date(o.paid_at * 1000).toLocaleString()}
                  </Text>
                </View>
              )}
            </View>
          );
        })
      )}
    </ScrollView>
  );
}