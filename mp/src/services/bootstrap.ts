/** 启动期一次性：拉取 /meta，注入未授权回调 */

import Taro from '@tarojs/taro';
import { api, LoginResp } from './api';
import { setUnauthorizedHandler } from './http';
import { useAuthStore } from '@/stores/auth';

export const AuthBootstrap = {
  start() {
    setUnauthorizedHandler(() => {
      Taro.removeStorageSync('ztao_token');
      useAuthStore.setState({ me: null, agents: [] });
      Taro.reLaunch({ url: '/pages/auth/login/index' });
    });

    // 后台拉 meta（容错）
    api.meta().catch(() => undefined);

    // 启动期有 token 就尝试刷新 me
    const token = Taro.getStorageSync('ztao_token');
    if (token) {
      api.me()
        .then((me) => useAuthStore.setState({ me }))
        .catch(() => Taro.removeStorageSync('ztao_token'));
    }
  },

  /** 微信登录 + 一人公司引导 */
  async login(): Promise<LoginResp> {
    const { code } = await Taro.login();
    // M1：暂不调用 getUserProfile（避免每次授权）；M2 接 profile
    const resp = await api.auth.login({ code });
    Taro.setStorageSync('ztao_token', resp.token);
    Taro.setStorageSync('ztao_user_id', resp.user.id);
    Taro.setStorageSync('ztao_onboarding_step', resp.onboarding.step);
    useAuthStore.setState({
      me: {
        user: resp.user,
        tenant: resp.tenant,
        workspace: resp.workspace,
        plan: { code: 'free', name: 'Free', seat_limit: 1, ai_token_monthly: 50000 },
        balance: { tokens: 50000, tokens_used_this_month: 0, period_end: 0 },
        agents: resp.agents,
        onboarding: resp.onboarding,
      },
      agents: resp.agents,
    });
    return resp;
  },
};