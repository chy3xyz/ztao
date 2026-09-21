import { useState } from 'react';
import { View, Text, Button } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { AuthBootstrap } from '@/services/bootstrap';

export default function LoginPage() {
  const [busy, setBusy] = useState(false);

  const onLogin = async () => {
    if (busy) return;
    setBusy(true);
    try {
      const resp = await AuthBootstrap.login();
      // 未填写昵称 → 引导页；否则进工作台
      if (!resp.user.name || resp.user.name === 'Founder') {
        Taro.redirectTo({ url: '/pages/onboarding/first/index' });
      } else {
        Taro.switchTab({ url: '/pages/workspace/index/index' });
      }
    } catch (e) {
      const msg = (e as Error).message || '登录失败';
      Taro.showToast({ title: msg, icon: 'none', duration: 2000 });
    } finally {
      setBusy(false);
    }
  };

  return (
    <View className="container" style={{ paddingTop: '40%' }}>
      <View style={{ textAlign: 'center', marginBottom: 32 }}>
        <Text style={{ fontSize: 56, lineHeight: 1 }}>🛠️</Text>
        <View>
          <Text style={{ fontSize: 36, fontWeight: 600, color: '#2f6f5e' }}>ztao</Text>
        </View>
        <View style={{ marginTop: 8 }}>
          <Text className="muted">一个人，也能跑一家公司</Text>
        </View>
      </View>

      <Button
        className="btn"
        loading={busy}
        onClick={onLogin}
        openType="getUserInfo"
      >
        微信一键登录
      </Button>

      <View style={{ textAlign: 'center', marginTop: 24 }}>
        <Text className="muted" style={{ fontSize: 11 }}>
          登录即同意《用户协议》《隐私政策》
        </Text>
      </View>
    </View>
  );
}