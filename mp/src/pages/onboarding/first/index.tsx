import { useState } from 'react';
import { View, Text, Button } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { api } from '@/services/api';
import { useAuthStore } from '@/stores/auth';

const steps = [
  { id: 'agents_ready', title: '我们为你建好"公司"和 5 名 AI 员工', emoji: '🎉' },
  { id: 'first_chat', title: '对 PM Agent 说一句话试试', emoji: '💬' },
  { id: 'first_task', title: '让 Dev Agent 拆 3 个任务', emoji: '📋' },
  { id: 'done', title: '完成 · 进工作台', emoji: '🚀' },
];

export default function OnboardingFirst() {
  const [idx, setIdx] = useState(0);
  const cur = steps[idx];

  const next = async () => {
    try {
      const resp = await api.me.onboardingNext(cur.id);
      if (resp.next_step) {
        const nextStep = steps.find((s) => s.id === resp.next_step);
        if (nextStep) setIdx(steps.indexOf(nextStep));
      } else {
        Taro.switchTab({ url: '/pages/workspace/index/index' });
      }
      useAuthStore.setState((s) => ({
        me: s.me
          ? {
              ...s.me,
              onboarding: {
                step: resp.next_step || 'done',
                completed_steps: [
                  ...s.me.onboarding.completed_steps,
                  cur.id,
                ],
              },
            }
          : s.me,
      }));
    } catch (e) {
      Taro.showToast({ title: (e as Error).message, icon: 'none' });
    }
  };

  return (
    <View className="container" style={{ paddingTop: '20%' }}>
      <View style={{ textAlign: 'center', marginBottom: 24 }}>
        <Text style={{ fontSize: 80 }}>{cur.emoji}</Text>
      </View>
      <View style={{ textAlign: 'center', marginBottom: 24 }}>
        <Text style={{ fontSize: 18, fontWeight: 600 }}>
          Step {idx + 1} / {steps.length}
        </Text>
        <View style={{ marginTop: 12 }}>
          <Text style={{ fontSize: 16, color: '#3a4256' }}>{cur.title}</Text>
        </View>
      </View>
      <Button className="btn" onClick={next}>
        {idx + 1 < steps.length ? '下一步' : '进工作台'}
      </Button>
      <View style={{ textAlign: 'center', marginTop: 12 }}>
        <Text
          className="muted"
          onClick={() => Taro.switchTab({ url: '/pages/workspace/index/index' })}
          style={{ fontSize: 12 }}
        >
          跳过引导
        </Text>
      </View>
    </View>
  );
}