import { PropsWithChildren } from 'react';
import { useLaunch } from '@tarojs/taro';
import { AuthBootstrap } from './services/bootstrap';

import './app.scss';

function App({ children }: PropsWithChildren) {
  useLaunch(() => {
    console.log('[ztao] app launched');
    // 后台拉一下 /meta + 自动登录
    AuthBootstrap.start();
  });

  return children as any;
}

export default App;