import { useState, useEffect } from 'react';
import { View, Text, Input, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { api } from '@/services/api';

interface Msg {
  role: 'user' | 'agent';
  content: string;
  ts: number;
  tokens?: { input: number; output: number; cost_cents: number };
  pending?: boolean;
}

export default function ChatPage() {
  const [agentId, setAgentId] = useState(0);
  const [agentName, setAgentName] = useState('Agent');
  const [messages, setMessages] = useState<Msg[]>([]);
  const [input, setInput] = useState('');
  const [busy, setBusy] = useState(false);
  const [streamBuffer, setStreamBuffer] = useState('');

  useEffect(() => {
    const params = Taro.getCurrentInstance().router?.params;
    if (params) {
      const id = Number(params.agent_id || 0);
      const name = decodeURIComponent(params.name || 'Agent');
      setAgentId(id);
      setAgentName(name);
    }
  }, []);

  const send = async () => {
    const text = input.trim();
    if (!text || busy || !agentId) return;
    setBusy(true);
    setInput('');
    const ts = Date.now();
    setMessages((m) => [...m, { role: 'user', content: text, ts }]);

    // 占位 agent message（pending）
    setMessages((m) => [
      ...m,
      { role: 'agent', content: '...', ts: Date.now(), pending: true },
    ]);

    try {
      // M3 阶段是阻塞响应；M3+ 改 SSE / WebSocket 流式
      const resp = await api.ai.chat(agentId, text);
      setMessages((m) => {
        const copy = [...m];
        for (let i = copy.length - 1; i >= 0; i--) {
          if (copy[i].pending) {
            copy[i] = {
              role: 'agent',
              content: resp.stub_reply,
              ts: Date.now(),
              tokens: {
                input: resp.tokens_input,
                output: resp.tokens_output,
                cost_cents: resp.cost_cents,
              },
            };
            break;
          }
        }
        return copy;
      });
    } catch (e) {
      setMessages((m) => {
        const copy = [...m];
        for (let i = copy.length - 1; i >= 0; i--) {
          if (copy[i].pending) {
            copy[i] = { role: 'agent', content: `错误：${(e as Error).message}`, ts: Date.now() };
            break;
          }
        }
        return copy;
      });
    } finally {
      setBusy(false);
    }
  };

  return (
    <View style={{ display: 'flex', flexDirection: 'column', height: '100vh' }}>
      <View
        style={{
          padding: '12px 16px',
          borderBottom: '1px solid #e9e3d6',
          background: '#fff',
          fontWeight: 600,
        }}
      >
        {agentName}
      </View>

      <ScrollView scrollY style={{ flex: 1, padding: 12 }}>
        {messages.length === 0 && (
          <View style={{ textAlign: 'center', marginTop: 60 }}>
            <Text className="muted">说点什么开始对话</Text>
            <View style={{ marginTop: 8 }}>
              <Text className="muted" style={{ fontSize: 11 }}>
                {streamBuffer ? streamBuffer : 'M3 · 阻塞响应；M3+ 切流式'}
              </Text>
            </View>
          </View>
        )}
        {messages.map((m, i) => (
          <View
            key={i}
            style={{
              display: 'flex',
              justifyContent: m.role === 'user' ? 'flex-end' : 'flex-start',
              marginBottom: 8,
            }}
          >
            <View
              style={{
                maxWidth: '78%',
                padding: '8px 12px',
                borderRadius: 12,
                background: m.role === 'user' ? '#2f6f5e' : m.pending ? '#f0ead9' : '#fafafa',
                color: m.role === 'user' ? '#fff' : '#14171e',
                fontSize: 14,
                minWidth: 60,
              }}
            >
              <Text style={{ color: m.role === 'user' ? '#fff' : '#14171e' }}>
                {m.pending ? '...' : m.content}
              </Text>
              {m.tokens && (
                <View style={{ marginTop: 6, fontSize: 10, opacity: 0.7 }}>
                  <Text style={{ color: m.role === 'user' ? '#fff' : '#14171e' }}>
                    {m.tokens.input + m.tokens.output} tokens · ¥
                    {(m.tokens.cost_cents / 100).toFixed(2)}
                  </Text>
                </View>
              )}
            </View>
          </View>
        ))}
      </ScrollView>

      <View
        style={{
          display: 'flex',
          alignItems: 'center',
          padding: 8,
          borderTop: '1px solid #e9e3d6',
          background: '#fff',
        }}
      >
        <Input
          value={input}
          onInput={(e) => setInput(e.detail.value)}
          placeholder="说点什么..."
          confirmHold={false}
          onConfirm={send}
          style={{
            flex: 1,
            height: 36,
            background: '#fafafa',
            borderRadius: 18,
            padding: '0 12px',
            fontSize: 14,
          }}
        />
        <View
          onClick={send}
          style={{
            marginLeft: 8,
            padding: '0 16px',
            height: 36,
            lineHeight: '36px',
            borderRadius: 18,
            background: busy ? '#7c7a72' : '#2f6f5e',
            color: '#fff',
            fontSize: 14,
          }}
        >
          发送
        </View>
      </View>
    </View>
  );
}