import { View, Text } from '@tarojs/components';
import { useState, useEffect } from 'react';
import Taro from '@tarojs/taro';
import { api } from '@/services/api';

export default function AgentDetail() {
  const [info, setInfo] = useState<any>(null);

  useEffect(() => {
    const id = Number(Taro.getCurrentInstance().router?.params.id || 0);
    if (id) api.ai.getAgent(id).then(setInfo).catch(() => undefined);
  }, []);

  if (!info) {
    return (
      <View className="container">
        <Text className="muted">加载中...</Text>
      </View>
    );
  }

  return (
    <View className="container">
      <View className="card" style={{ textAlign: 'center' }}>
        <View style={{ fontSize: 64 }}>{info.agent.avatar}</View>
        <View style={{ fontSize: 20, fontWeight: 600, marginTop: 8 }}>
          {info.agent.name}
        </View>
        <View style={{ marginTop: 4 }}>
          <Text className="muted">{info.agent.preset_code}</Text>
        </View>
      </View>

      <View className="card">
        <View className="title">能力</View>
        <View style={{ marginTop: 4 }}>
          <Text className="muted">Tools: {info.agent.tools || '默认'}</Text>
        </View>
        <View style={{ marginTop: 4 }}>
          <Text className="muted">Scopes: {info.agent.scopes || '默认'}</Text>
        </View>
      </View>

      <View className="card">
        <View className="title">统计</View>
        <View style={{ marginTop: 4 }}>
          <Text className="muted">累计调用：{info.stats?.runs ?? 0} 次</Text>
        </View>
        <View style={{ marginTop: 4 }}>
          <Text className="muted">累计花费：¥{((info.stats?.cost_cents ?? 0) / 100).toFixed(2)}</Text>
        </View>
      </View>
    </View>
  );
}