import { useState } from 'react';
import { View, Text, Input, Button } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { pmApi } from '@/services/pm';

export default function NewTask() {
  const [name, setName] = useState('');
  const [estimate, setEstimate] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    if (!name.trim()) {
      Taro.showToast({ title: '任务名不能为空', icon: 'none' });
      return;
    }
    const projectId = Number(Taro.getCurrentInstance().router?.params.project_id || 0);
    if (!projectId) {
      Taro.showToast({ title: '缺少 project_id', icon: 'none' });
      return;
    }
    setBusy(true);
    try {
      const r = await pmApi.tasks.create({
        project_id: projectId,
        name: name.trim(),
        estimate: Number(estimate) || 0,
      });
      Taro.showToast({ title: '已创建', icon: 'success' });
      setTimeout(() => Taro.navigateBack(), 800);
    } catch (e) {
      Taro.showToast({ title: (e as Error).message, icon: 'none' });
    } finally {
      setBusy(false);
    }
  };

  return (
    <View className="container">
      <View className="card">
        <Text className="title">新建任务</Text>

        <View style={{ marginTop: 12 }}>
          <Text className="muted">任务名</Text>
          <Input
            value={name}
            onInput={(e) => setName(e.detail.value)}
            placeholder="写登录页 UI"
            style={{ padding: '10px 12px', background: '#fafafa', borderRadius: 8, marginTop: 4 }}
          />
        </View>

        <View style={{ marginTop: 12 }}>
          <Text className="muted">预估工时（小时）</Text>
          <Input
            type="digit"
            value={estimate}
            onInput={(e) => setEstimate(e.detail.value)}
            placeholder="4"
            style={{ padding: '10px 12px', background: '#fafafa', borderRadius: 8, marginTop: 4 }}
          />
        </View>

        <Button className="btn" loading={busy} onClick={submit}>
          创建
        </Button>
      </View>
    </View>
  );
}