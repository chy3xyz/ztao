import { View, Text } from '@tarojs/components';
import Taro from '@tarojs/taro';

const tabs = [
  { kind: 'gift', emoji: '🎁', label: '礼品商城', sub: '任务奖励·客户答谢', accent: '#b06367', enabled: true, url: '/pages/mall/gift/index' },
  { kind: 'accessory', emoji: '🛠', label: '配件商城', sub: '硬件·工具·课程', accent: '#4a6a8c', enabled: true, url: '/pages/mall/accessory/index' },
  { kind: 'compute', emoji: '⚡', label: '算力商城', sub: 'Token 包·团队席位', accent: '#c97b3f', enabled: true, url: '/pages/mall/compute/index' },
];

export default function MallIndex() {
  return (
    <View className="container">
      <View
        style={{
          padding: '20px 16px',
          borderRadius: 14,
          background: 'linear-gradient(135deg, #b06367, #c97b3f)',
          color: '#fff',
          marginBottom: 12,
        }}
      >
        <Text style={{ fontSize: 18, fontWeight: 600 }}>三套商城 · 已上线</Text>
        <View style={{ marginTop: 6 }}>
          <Text style={{ fontSize: 12, opacity: 0.85 }}>
            任务奖励 · 办公配件 · 算力加量
          </Text>
        </View>
      </View>

      {tabs.map((t) => (
        <View
          key={t.kind}
          className="card"
          onClick={() => {
            if (t.enabled && t.url) {
              Taro.navigateTo({ url: t.url });
            }
          }}
          style={{ borderLeft: `4px solid ${t.accent}` }}
        >
          <View style={{ display: 'flex', alignItems: 'center' }}>
            <Text style={{ fontSize: 32, marginRight: 14 }}>{t.emoji}</Text>
            <View style={{ flex: 1 }}>
              <View style={{ fontWeight: 600 }}>{t.label}</View>
              <Text className="muted">{t.sub}</Text>
            </View>
            <Text style={{ color: t.accent, fontSize: 12 }}>→</Text>
          </View>
        </View>
      ))}

      <View className="card" onClick={() => Taro.navigateTo({ url: '/pages/mall/orders/index' })}>
        <View style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Text>我的订单</Text>
          <Text style={{ color: '#2f6f5e', fontSize: 12 }}>→</Text>
        </View>
      </View>
    </View>
  );
}