import { useEffect, useState } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { pmApi, Task } from '@/services/pm';

const STATUS_META = {
  todo: { label: '待办', color: '#7c7a72', bg: 'rgba(124,122,114,0.08)' },
  doing: { label: '进行', color: '#2f6f5e', bg: 'rgba(47,111,94,0.08)' },
  done: { label: '完成', color: '#4a6a8c', bg: 'rgba(74,106,140,0.08)' },
} as const;

const PRI_LABEL: Record<number, string> = { 1: '高', 2: '中', 3: '低', 4: '低' };

export default function Board() {
  const [board, setBoard] = useState<{ todo: Task[]; doing: Task[]; done: Task[] }>({
    todo: [], doing: [], done: [],
  });
  const [projectName, setProjectName] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const params = Taro.getCurrentInstance().router?.params;
    const id = Number(params?.id || 0);
    if (params?.name) setProjectName(decodeURIComponent(params.name));
    if (id) refresh(id);
  }, []);

  const refresh = async (id: number) => {
    setBusy(true);
    try {
      const b = await pmApi.projects.board(id);
      setBoard(b);
    } finally {
      setBusy(false);
    }
  };

  const onTapTask = (t: Task) => {
    Taro.navigateTo({ url: `/pages/task/id/index?id=${t.id}` });
  };

  const renderColumn = (key: keyof typeof board) => {
    const meta = STATUS_META[key];
    const items = board[key];
    return (
      <View style={{ display: 'flex', flexDirection: 'column', flex: 1, paddingHorizontal: 4 }}>
        <View style={{ padding: '6px 0', borderBottom: `2px solid ${meta.color}`, marginBottom: 8 }}>
          <Text style={{ fontSize: 13, fontWeight: 600, color: meta.color }}>
            {meta.label} <Text style={{ color: '#7c7a72', fontSize: 11 }}>({items.length})</Text>
          </Text>
        </View>
        {items.length === 0 ? (
          <Text className="muted" style={{ fontSize: 11, textAlign: 'center' }}>
            —
          </Text>
        ) : (
          items.map((t) => (
            <View
              key={t.id}
              onClick={() => onTapTask(t)}
              style={{
                padding: 8,
                marginBottom: 6,
                borderRadius: 8,
                background: meta.bg,
              }}
            >
              <View style={{ fontSize: 12, fontWeight: 500 }}>{t.name}</View>
              <View style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4 }}>
                <Text style={{ fontSize: 10, color: meta.color }}>
                  P{PRI_LABEL[t.pri] ?? t.pri}
                </Text>
                <Text style={{ fontSize: 10, color: '#7c7a72' }}>
                  {t.consumed}/{t.estimate}h
                </Text>
              </View>
              {t.assignee_kind === 'agent' && (
                <Text style={{ fontSize: 9, color: '#c97b3f' }}>AI · {t.assignee_kind}</Text>
              )}
            </View>
          ))
        )}
      </View>
    );
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
        {projectName} · 看板
      </View>

      <View style={{ flex: 1, padding: 12, background: '#fafafa' }}>
        <ScrollView scrollY style={{ height: '100%' }}>
          <View style={{ display: 'flex' }}>
            {renderColumn('todo')}
            {renderColumn('doing')}
            {renderColumn('done')}
          </View>
        </ScrollView>
      </View>

      <View
        style={{
          padding: '10px 16px',
          borderTop: '1px solid #e9e3d6',
          background: '#fff',
          textAlign: 'center',
        }}
      >
        <Text
          style={{ color: '#2f6f5e', fontSize: 13 }}
          onClick={() => {
            const id = Number(Taro.getCurrentInstance().router?.params.id || 0);
            Taro.navigateTo({ url: `/pages/task/new/index?project_id=${id}` });
          }}
        >
          + 新建任务
        </Text>
      </View>
    </View>
  );
}