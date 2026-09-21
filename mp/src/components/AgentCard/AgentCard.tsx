import { View, Text } from '@tarojs/components';
import type { Agent } from '@/services/api';

interface Props {
  agent: Agent;
  onTap?: () => void;
}

const presetHint: Record<Agent['preset_code'], string> = {
  pm: '写需求 · 拆任务',
  dev: '改 Bug · 出 PR',
  qa: '写用例 · 跑测试',
  support: '答工单 · 复盘',
  ops: '监控 · 报表',
};

export function AgentCard({ agent, onTap }: Props) {
  return (
    <View
      onClick={onTap}
      style={{
        width: 140,
        padding: 12,
        background: '#ffffff',
        borderRadius: 14,
        boxShadow: '0 2px 8px rgba(0,0,0,0.04)',
        textAlign: 'center',
      }}
    >
      <View style={{ fontSize: 36, marginBottom: 6 }}>{agent.avatar}</View>
      <View style={{ fontWeight: 600, fontSize: 14 }}>{agent.name}</View>
      <Text className="muted" style={{ fontSize: 10 }}>
        {presetHint[agent.preset_code]}
      </Text>
      <View style={{ marginTop: 6 }}>
        <Text
          style={{
            fontSize: 9,
            padding: '1px 6px',
            borderRadius: 3,
            background:
              agent.status === 'active' ? 'rgba(47,111,94,0.08)' : 'rgba(176,99,103,0.08)',
            color: agent.status === 'active' ? '#2f6f5e' : '#b06367',
            fontFamily: 'JetBrains Mono, monospace',
          }}
        >
          {agent.status.toUpperCase()}
        </Text>
      </View>
    </View>
  );
}