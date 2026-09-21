import { useEffect, useState } from 'react';
import { View, Text, ScrollView } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { pmApi, Project, Product } from '@/services/pm';

export default function ProjectIndex() {
  const [products, setProducts] = useState<Product[]>([]);
  const [projects, setProjects] = useState<Project[]>([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    refresh();
  }, []);

  const refresh = async () => {
    setBusy(true);
    try {
      const [prods, projs] = await Promise.all([pmApi.products.list(), pmApi.projects.list()]);
      setProducts(prods.list);
      setProjects(projs.list);
    } finally {
      setBusy(false);
    }
  };

  const onCreate = () => {
    if (products.length === 0) {
      Taro.showModal({
        title: '先建一个产品',
        content: '项目归属于产品。先去工作台用 AI 创建一个吧。',
        showCancel: false,
      });
      return;
    }
    Taro.navigateTo({ url: '/pages/project/new/index' });
  };

  const onOpen = (p: Project) => {
    Taro.navigateTo({ url: `/pages/project/board/index?id=${p.id}&name=${encodeURIComponent(p.name)}` });
  };

  return (
    <ScrollView scrollY className="container">
      <View className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Text className="title" style={{ margin: 0 }}>项目</Text>
        <Text
          style={{ fontSize: 12, color: '#2f6f5e', padding: '4px 10px', border: '1px solid #2f6f5e', borderRadius: 12 }}
          onClick={onCreate}
        >
          + 新建
        </Text>
      </View>

      {projects.length === 0 ? (
        <View className="card">
          <Text className="muted">还没有项目 · M2 演示：试试在右上点"+ 新建"</Text>
          <Text className="muted" style={{ fontSize: 11, marginTop: 4 }}>
            （需要先有产品，工作台有"AI 写需求"入口能自动建）
          </Text>
        </View>
      ) : (
        projects.map((p) => (
          <View key={p.id} className="card" onClick={() => onOpen(p)}>
            <View style={{ display: 'flex', justifyContent: 'space-between' }}>
              <View>
                <View style={{ fontWeight: 600 }}>{p.name}</View>
                <Text className="muted">{p.code} · {p.model}</Text>
              </View>
              <Text
                style={{
                  fontSize: 10,
                  padding: '2px 6px',
                  borderRadius: 3,
                  background:
                    p.status === 'doing'
                      ? 'rgba(47,111,94,0.1)'
                      : p.status === 'done'
                        ? 'rgba(74,106,140,0.1)'
                        : 'rgba(124,122,114,0.1)',
                  color: p.status === 'doing' ? '#2f6f5e' : p.status === 'done' ? '#4a6a8c' : '#7c7a72',
                  alignSelf: 'flex-start',
                }}
              >
                {p.status.toUpperCase()}
              </Text>
            </View>
          </View>
        ))
      )}

      <View style={{ marginTop: 16 }}>
        <Text className="title" style={{ fontSize: 14 }}>产品（{products.length}）</Text>
      </View>
      {products.map((p) => (
        <View key={p.id} className="card">
          <View style={{ fontWeight: 600 }}>{p.name}</View>
          <Text className="muted">{p.code} · {p.status}</Text>
        </View>
      ))}
    </ScrollView>
  );
}