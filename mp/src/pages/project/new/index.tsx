import { useEffect, useState } from 'react';
import { View, Text, Input, Button, Picker } from '@tarojs/components';
import Taro from '@tarojs/taro';
import { pmApi, Product } from '@/services/pm';

export default function NewProject() {
  const [products, setProducts] = useState<Product[]>([]);
  const [productIdx, setProductIdx] = useState(0);
  const [name, setName] = useState('');
  const [code, setCode] = useState('');
  const [model, setModel] = useState('scrum');

  useEffect(() => {
    pmApi.products.list().then((r) => setProducts(r.list)).catch(() => undefined);
  }, []);

  const submit = async () => {
    if (!name.trim()) {
      Taro.showToast({ title: '项目名不能为空', icon: 'none' });
      return;
    }
    if (!products[productIdx]) {
      Taro.showToast({ title: '请先选择产品', icon: 'none' });
      return;
    }
    try {
      const resp = await pmApi.projects.create({
        product_id: products[productIdx].id,
        name: name.trim(),
        code: code.trim(),
        model,
      });
      Taro.showToast({ title: '已创建', icon: 'success' });
      setTimeout(() => Taro.navigateBack(), 800);
    } catch (e) {
      Taro.showToast({ title: (e as Error).message, icon: 'none' });
    }
  };

  return (
    <View className="container">
      <View className="card">
        <Text className="title">新建项目</Text>

        <View style={{ marginTop: 16 }}>
          <Text className="muted">归属产品</Text>
          <Picker
            mode="selector"
            range={products.map((p) => p.name)}
            value={productIdx}
            onChange={(e) => setProductIdx(Number(e.detail.value))}
          >
            <View
              style={{
                padding: '10px 12px',
                background: '#fafafa',
                borderRadius: 8,
                marginTop: 4,
              }}
            >
              <Text>{products[productIdx]?.name || '选择产品'}</Text>
            </View>
          </Picker>
        </View>

        <View style={{ marginTop: 12 }}>
          <Text className="muted">项目名</Text>
          <Input
            value={name}
            onInput={(e) => setName(e.detail.value)}
            placeholder="MVP"
            style={{ padding: '10px 12px', background: '#fafafa', borderRadius: 8, marginTop: 4 }}
          />
        </View>

        <View style={{ marginTop: 12 }}>
          <Text className="muted">代号</Text>
          <Input
            value={code}
            onInput={(e) => setCode(e.detail.value)}
            placeholder="MVP"
            style={{ padding: '10px 12px', background: '#fafafa', borderRadius: 8, marginTop: 4 }}
          />
        </View>

        <View style={{ marginTop: 12 }}>
          <Text className="muted">模型</Text>
          <Picker
            mode="selector"
            range={['scrum', 'kanban', 'waterfall']}
            value={['scrum', 'kanban', 'waterfall'].indexOf(model)}
            onChange={(e) => setModel(['scrum', 'kanban', 'waterfall'][Number(e.detail.value)])}
          >
            <View
              style={{
                padding: '10px 12px',
                background: '#fafafa',
                borderRadius: 8,
                marginTop: 4,
              }}
            >
              <Text>{model}</Text>
            </View>
          </Picker>
        </View>

        <Button className="btn" onClick={submit}>
          创建
        </Button>
      </View>
    </View>
  );
}