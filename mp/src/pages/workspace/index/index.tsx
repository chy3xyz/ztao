import { View, Text, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { useEffect, useState } from 'react';
import { useAuthStore } from '@/stores/auth';
import { AgentCard } from '@/components/AgentCard/AgentCard';
import { api } from '@/services/api';
import { approvalApi } from '@/services/usage';

interface PendingApproval {
  id: number;
  tool_name: string;
  payload: string;
  requested_at: number;
}

export default function WorkspaceHome() {
  const me = useAuthStore((s) => s.me);
  const agents = useAuthStore((s) => s.agents);
  const [pending, setPending] = useState<PendingApproval[]>([]);

  useEffect(() => {
    if (!me) {
      api.me().then((m) => useAuthStore.getState().setMe(m)).catch(() => undefined);
    }
    refreshPending();
  }, [me]);

  const refreshPending = () => {
    approvalApi.listPending()
      .then((r) => setPending(r.list as PendingApproval[]))
      .catch(() => undefined);
  };

  const decide = async (id: number, decision: 'approved' | 'rejected') => {
    try {
      await approvalApi.decide(id, decision, '');
      Taro.showToast({ title: decision === 'approved' ? '已批准' : '已拒绝', icon: 'success' });
      refreshPending();
    } catch (e) {
      Taro.showToast({ title: (e as Error).message, icon: 'none' });
    }
  };

  const greeting = (() => {
    const h = new Date().getHours();
    if (h < 6) return '凌晨好';
    if (h < 12) return '早';
    if (h < 18) return '下午好';
    return '晚上好';
  })();

  return (
    <ScrollView scrollY className="container">
      <View className="card">
        <Text style={{ fontSize: 22, fontWeight: 600 }}>
          {greeting}，{me?.user.name || 'Founder'}
        </Text>
        <View style={{ marginTop: 4 }}>
          <Text className="muted">{me?.workspace?.name || '默认 Workspace'}</Text>
        </View>
      </View>

      <View style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
        <View
          className="card"
          style={{ flex: 1, marginBottom: 0, textAlign: 'center', padding: 14 }}
        >
          <Text style={{ fontSize: 22, color: '#2f6f5e', fontWeight: 600 }}>
            {(me?.balance?.tokens ?? 0).toLocaleString()}
          </Text>
          <Text className="muted" style={{ fontSize: 11 }}>
            Token 余量
          </Text>
        </View>
        <View
          className="card"
          style={{ flex: 1, marginBottom: 0, textAlign: 'center', padding: 14 }}
        >
          <Text style={{ fontSize: 22, color: pending.length > 0 ? '#b06367' : '#2f6f5e', fontWeight: 600 }}>
            {pending.length}
          </Text>
          <Text className="muted" style={{ fontSize: 11 }}>
            待审批
          </Text>
        </View>
      </View>

      {pending.length > 0 && (
        <View className="card" style={{ borderLeft: '4px solid #b06367' }}>
          <View className="title" style={{ color: '#b06367', marginBottom: 8 }}>
            ⏳ Agent 待审批
          </View>
          {pending.map((p) => (
            <View
              key={p.id}
              style={{
                padding: 10,
                marginBottom: 8,
                background: 'rgba(176,99,103,0.06)',
                borderRadius: 8,
              }}
            >
              <View style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                <Text style={{ fontWeight: 500 }}>{p.tool_name}</Text>
                <Text className="muted" style={{ fontSize: 10 }}>
                  {new Date(p.requested_at * 1000).toLocaleTimeString()}
                </Text>
              </View>
              <Text className="muted" style={{ fontSize: 11 }}>
                参数：{p.payload.slice(0, 60)}
                {p.payload.length > 60 ? '...' : ''}
              </Text>
              <View style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                <View
                  onClick={() => decide(p.id, 'approved')}
                  style={{
                    flex: 1,
                    textAlign: 'center',
                    padding: '6px 0',
                    background: '#2f6f5e',
                    color: '#fff',
                    borderRadius: 6,
                    fontSize: 12,
                  }}
                >
                  批准
                </View>
                <View
                  onClick={() => decide(p.id, 'rejected')}
                  style={{
                    flex: 1,
                    textAlign: 'center',
                    padding: '6px 0',
                    background: '#b06367',
                    color: '#fff',
                    borderRadius: 6,
                    fontSize: 12,
                  }}
                >
                  拒绝
                </View>
              </View>
            </View>
          ))}
        </View>
      )}

      <View className="title" style={{ marginTop: 8, marginBottom: 8 }}>
        AI 团队
      </View>
      <ScrollView scrollX style={{ whiteSpace: 'nowrap' }}>
        {agents.map((a) => (
          <View key={a.id} style={{ display: 'inline-block', marginRight: 10 }}>
            <AgentCard
              agent={a}
              onTap={() =>
                Taro.navigateTo({
                  url: `/pages/ai/chat/index?agent_id=${a.id}&name=${encodeURIComponent(a.name)}`,
                })
              }
            />
          </View>
        ))}
      </ScrollView>

      <View className="title" style={{ marginTop: 16, marginBottom: 8 }}>
        今日待办
      </View>
      <View className="card">
        <Text className="muted">还没有任务 · 去项目 Tab 创建第一个</Text>
      </View>
    </ScrollView>
  );
}