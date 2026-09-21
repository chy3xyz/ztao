import { useEffect, useState } from 'react';
import { View, Text, Button } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { pmApi, Task } from '@/services/pm';

const STATUS_CYCLE = ['wait', 'doing', 'done'] as const;

const STATUS_LABEL: Record<string, string> = {
  wait: '待办',
  doing: '进行',
  done: '完成',
  closed: '关闭',
  cancel: '取消',
};

export default function TaskDetail() {
  const [task, setTask] = useState<Task | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const id = Number(Taro.getCurrentInstance().router?.params.id || 0);
    if (id) refresh(id);
  }, []);

  const refresh = async (id: number) => {
    setBusy(true);
    try {
      const t = await pmApi.tasks.get(id);
      setTask(t);
    } finally {
      setBusy(false);
    }
  };

  const onChangeStatus = async () => {
    if (!task) return;
    const idx = STATUS_CYCLE.indexOf(task.status as any);
    const next = STATUS_CYCLE[(idx + 1) % STATUS_CYCLE.length];
    try {
      await pmApi.tasks.patchStatus(task.id, next);
      Taro.showToast({ title: `已切到 ${STATUS_LABEL[next]}`, icon: 'success' });
      refresh(task.id);
    } catch (e) {
      Taro.showToast({ title: (e as Error).message, icon: 'none' });
    }
  };

  const onLogTime = () => {
    if (!task) return;
    Taro.showModal({
      title: '登记工时',
      editable: true,
      placeholderText: '输入小时数',
      success: async (res) => {
        if (!res.confirm || !res.content) return;
        const hours = Number(res.content);
        if (!hours || hours <= 0) {
          Taro.showToast({ title: '请输入有效数字', icon: 'none' });
          return;
        }
        try {
          await pmApi.tasks.logTime(task.id, hours);
          Taro.showToast({ title: '已登记', icon: 'success' });
          refresh(task.id);
        } catch (e) {
          Taro.showToast({ title: (e as Error).message, icon: 'none' });
        }
      },
    });
  };

  if (!task) {
    return (
      <View className="container">
        <Text className="muted">加载中...</Text>
      </View>
    );
  }

  return (
    <View className="container">
      <View className="card">
        <View style={{ fontSize: 18, fontWeight: 600 }}>{task.name}</View>
        <View style={{ marginTop: 6 }}>
          <Text className="muted">#{task.id} · P{task.pri} · {STATUS_LABEL[task.status]}</Text>
        </View>
      </View>

      <View className="card">
        <View className="title">工时</View>
        <View style={{ display: 'flex', justifyContent: 'space-between', marginTop: 8 }}>
          <Text className="muted">已消耗</Text>
          <Text>{task.consumed}h</Text>
        </View>
        <View style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
          <Text className="muted">剩余</Text>
          <Text>{task.left}h</Text>
        </View>
        <View style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
          <Text className="muted">预估</Text>
          <Text>{task.estimate}h</Text>
        </View>
      </View>

      <View className="card">
        <View className="title">归属</View>
        <View style={{ marginTop: 4 }}>
          <Text className="muted">项目 #{task.project_id} · Sprint #{task.sprint_id || '—'} · Story #{task.story_id || '—'}</Text>
        </View>
        <View style={{ marginTop: 4 }}>
          <Text className="muted">指派人 #{task.assigned_to} ({task.assignee_kind})</Text>
        </View>
        {task.finished_at > 0 && (
          <View style={{ marginTop: 4 }}>
            <Text className="muted">完成时间：{new Date(task.finished_at * 1000).toLocaleString()}</Text>
          </View>
        )}
      </View>

      <Button className="btn" onClick={onChangeStatus}>
        切到下一状态
      </Button>
      <Button className="btn ghost" onClick={onLogTime}>
        登记工时
      </Button>
    </View>
  );
}