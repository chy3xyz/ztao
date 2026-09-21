import { View, Text } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { useAuthStore } from '@/stores/auth';
import { api } from '@/services/api';

export default function MeIndex() {
  const me = useAuthStore((s) => s.me);

  const onSwitchRole = async (role: string) => {
    try {
      await api.me.switchRole(role);
      Taro.showToast({ title: `已切到 ${role}`, icon: 'success' });
    } catch (e) {
      Taro.showToast({ title: (e as Error).message, icon: 'none' });
    }
  };

  const onLogout = () => {
    Taro.removeStorageSync('ztao_token');
    useAuthStore.getState().logout();
    Taro.reLaunch({ url: '/pages/auth/login/index' });
  };

  return (
    <View className="container">
      <View className="card" style={{ textAlign: 'center' }}>
        <View
          style={{
            width: 64,
            height: 64,
            borderRadius: 32,
            background: 'linear-gradient(135deg, #2f6f5e, #c97b3f)',
            margin: '0 auto 8px',
            color: '#fff',
            fontSize: 28,
            lineHeight: '64px',
            fontWeight: 600,
          }}
        >
          {(me?.user.name || 'F').charAt(0).toUpperCase()}
        </View>
        <View style={{ fontSize: 18, fontWeight: 600 }}>
          {me?.user.name || 'Founder'}
        </View>
        <Text className="muted">{me?.user.role?.toUpperCase() || 'FOUNDER'}</Text>
      </View>

      <View className="title" style={{ marginTop: 8 }}>
        身份切换（一人多角）
      </View>
      <View style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
        {(['pm', 'rd', 'qa', 'sales', 'ops'] as const).map((r) => (
          <View
            key={r}
            onClick={() => onSwitchRole(r)}
            className="tag"
            style={{
              fontSize: 12,
              padding: '6px 12px',
              cursor: 'pointer',
            }}
          >
            {r.toUpperCase()}
          </View>
        ))}
      </View>

      <View className="title" style={{ marginTop: 16 }}>
        账单
      </View>
      <View className="card">
        <View style={{ display: 'flex', justifyContent: 'space-between' }}>
          <Text className="muted">套餐</Text>
          <Text>{me?.plan.name || 'Free'}</Text>
        </View>
        <View style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
          <Text className="muted">Token 余量</Text>
          <Text>{(me?.balance.tokens ?? 0).toLocaleString()}</Text>
        </View>
      </View>

      <View className="title" style={{ marginTop: 16 }}>
        操作
      </View>
      <View className="card" onClick={onLogout}>
        <Text style={{ color: '#b06367' }}>退出登录</Text>
      </View>
    </View>
  );
}