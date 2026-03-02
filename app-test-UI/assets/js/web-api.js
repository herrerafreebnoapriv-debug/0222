/**
 * 用户端网页 API 层（规约 PROTOCOL 2.2：与 App 共用 auth/login，账密登录）
 */
(function () {
  var API_BASE_KEY = 'mop_web_api_base';
  var TOKEN_KEY = 'mop_web_access_token';
  var UID_KEY = 'mop_web_uid';
  var HOST_KEY = 'mop_web_host';

  /** 部署在 web.sdkdns.top 时默认使用 HTTPS 标准端口 API，无需用户填写 */
  function getDefaultApiBase() {
    try {
      if (typeof window !== 'undefined' && window.location && window.location.hostname === 'web.sdkdns.top')
        return 'https://api.sdkdns.top';
    } catch (e) {}
    return '';
  }

  function getApiBase() {
    var base = localStorage.getItem(API_BASE_KEY);
    if (base) return base.replace(/\/+$/, '');
    return getDefaultApiBase();
  }

  function setApiBase(base) {
    localStorage.setItem(API_BASE_KEY, (base || '').replace(/\/+$/, ''));
  }

  function getToken() { return localStorage.getItem(TOKEN_KEY) || ''; }
  function getUid() { return localStorage.getItem(UID_KEY) || ''; }
  function getHost() { return localStorage.getItem(HOST_KEY) || ''; }

  function setLoginResult(accessToken, uid, host, refreshToken) {
    if (accessToken) localStorage.setItem(TOKEN_KEY, accessToken);
    else localStorage.removeItem(TOKEN_KEY);
    if (uid) localStorage.setItem(UID_KEY, uid);
    else localStorage.removeItem(UID_KEY);
    if (host) localStorage.setItem(HOST_KEY, host);
    else localStorage.removeItem(HOST_KEY);
    if (refreshToken != null) {
      if (refreshToken) localStorage.setItem('mop_web_refresh_token', refreshToken);
      else localStorage.removeItem('mop_web_refresh_token');
    }
  }

  function clearAuth() {
    localStorage.removeItem(TOKEN_KEY);
    localStorage.removeItem(UID_KEY);
    localStorage.removeItem(HOST_KEY);
  }

  function getOrCreateWebDeviceId() {
    var key = 'mop_web_device_id';
    var id = localStorage.getItem(key);
    if (!id) {
      id = 'web_' + Date.now() + '_' + Math.random().toString(36).slice(2, 12);
      localStorage.setItem(key, id);
    }
    return id;
  }

  /**
   * POST /api/v1/auth/login Body: { identity, password }
   */
  function login(identity, password) {
    var base = getApiBase();
    var url = base ? (base + '/api/v1/auth/login') : '/api/v1/auth/login';
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ identity: identity, password: password })
    }).then(function (res) {
      if (res.status === 200) {
        return res.json().then(function (data) {
          var token = data.access_token;
          var uid = data.uid;
          var host = data.host || base || '';
          if (token && uid) {
            setLoginResult(token, uid, host, data.refresh_token);
            return { ok: true, uid: uid, host: host };
          }
          return { ok: false, message: 'no token/uid in response' };
        });
      }
      return res.json().catch(function () { return {}; }).then(function (body) {
        return { ok: false, status: res.status, code: body.code, message: body.message };
      });
    }).catch(function (err) {
      return { ok: false, message: err.message || 'network error' };
    });
  }

  /**
   * POST /api/v1/user/enroll 资料补全与设备绑定（规约 2.1）
   * payload: { country_code, phone, username, nickname, password, invite_code? }
   */
  function enroll(payload) {
    var base = getApiBase();
    var url = base ? (base + '/api/v1/user/enroll') : '/api/v1/user/enroll';
    var body = {
      country_code: payload.country_code || '+86',
      phone: (payload.phone || '').trim(),
      username: (payload.username || '').trim(),
      nickname: (payload.nickname || '').trim(),
      password: payload.password || '',
      device_id: getOrCreateWebDeviceId(),
      device_info: { model: 'Web', os: (navigator.userAgent || '').slice(0, 80), app_version: '1.0.0' },
      invite_code: (payload.invite_code || '').trim() || undefined
    };
    if (body.invite_code === '') delete body.invite_code;
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify(body)
    }).then(function (res) {
      if (res.status === 200) {
        return res.json().then(function (data) {
          if (data.access_token && data.uid) {
            setLoginResult(data.access_token, data.uid, data.host || base || '', data.refresh_token);
            return { ok: true, uid: data.uid, host: data.host };
          }
          return { ok: false, message: 'no token/uid in response' };
        });
      }
      return res.json().catch(function () { return {}; }).then(function (body) {
        return { ok: false, status: res.status, code: body.code, message: body.message };
      });
    }).catch(function (err) {
      return { ok: false, message: err.message || 'network error' };
    });
  }

  /**
   * GET /api/v1/user/profile 需鉴权，返回昵称、简介、头像等
   */
  function getProfile() {
    var base = getApiBase();
    var url = base ? (base + '/api/v1/user/profile') : '/api/v1/user/profile';
    var token = getToken();
    if (!token) return Promise.resolve({ ok: false, message: 'not logged in' });
    return fetch(url, {
      method: 'GET',
      headers: { 'Accept': 'application/json', 'Authorization': 'Bearer ' + token },
      credentials: 'same-origin'
    }).then(function (res) {
      if (res.status === 200) {
        return res.json().then(function (data) {
          return { ok: true, profile: data };
        });
      }
      return res.json().catch(function () { return {}; }).then(function (body) {
        return { ok: false, status: res.status, code: body.code, message: body.message };
      });
    }).catch(function (err) {
      return { ok: false, message: err.message || 'network error' };
    });
  }

  /**
   * PATCH /api/v1/user/profile 更新昵称、简介（Body: { nickname?, bio? }）
   */
  function updateProfile(payload) {
    var base = getApiBase();
    var url = base ? (base + '/api/v1/user/profile') : '/api/v1/user/profile';
    var token = getToken();
    if (!token) return Promise.resolve({ ok: false, message: 'not logged in' });
    return fetch(url, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer ' + token },
      credentials: 'same-origin',
      body: JSON.stringify(payload || {})
    }).then(function (res) {
      if (res.status === 200) return Promise.resolve({ ok: true });
      return res.json().catch(function () { return {}; }).then(function (body) {
        return { ok: false, status: res.status, code: body.code, message: body.message };
      });
    }).catch(function (err) {
      return { ok: false, message: err.message || 'network error' };
    });
  }

  /**
   * POST /api/v1/user/change-password Body: { old_password, new_password } 需鉴权
   */
  function changePassword(oldPassword, newPassword) {
    var base = getApiBase();
    var url = base ? (base + '/api/v1/user/change-password') : '/api/v1/user/change-password';
    var token = getToken();
    if (!token) return Promise.resolve({ ok: false, message: 'not logged in' });
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer ' + token },
      credentials: 'same-origin',
      body: JSON.stringify({ old_password: oldPassword, new_password: newPassword })
    }).then(function (res) {
      if (res.status === 200) return Promise.resolve({ ok: true });
      return res.json().catch(function () { return {}; }).then(function (body) {
        return { ok: false, status: res.status, code: body.code, message: body.message || 'change password failed' };
      });
    }).catch(function (err) {
      return { ok: false, message: err.message || 'network error' };
    });
  }

  /**
   * POST /api/v1/invite/generate 需鉴权，返回 invite_code、api、invite_url、invite_card
   */
  function inviteGenerate() {
    var base = getApiBase();
    var url = base ? (base + '/api/v1/invite/generate') : '/api/v1/invite/generate';
    var token = getToken();
    if (!token) return Promise.resolve({ ok: false, message: 'not logged in' });
    return fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer ' + token },
      credentials: 'same-origin',
      body: JSON.stringify({})
    }).then(function (res) {
      if (res.status === 200) {
        return res.json().then(function (data) {
          return { ok: true, invite_code: data.invite_code, api: data.api, invite_url: data.invite_url, invite_card: data.invite_card };
        });
      }
      return res.json().catch(function () { return {}; }).then(function (body) {
        return { ok: false, status: res.status, code: body.code, message: body.message };
      });
    }).catch(function (err) {
      return { ok: false, message: err.message || 'network error' };
    });
  }

  /**
   * POST /api/v1/user/avatar multipart "avatar" 需鉴权
   * @param {File} file 图片文件（相册选图或文件选择）
   */
  function uploadAvatar(file) {
    var base = getApiBase();
    var url = base ? (base + '/api/v1/user/avatar') : '/api/v1/user/avatar';
    var token = getToken();
    if (!token) return Promise.resolve({ ok: false, message: 'not logged in' });
    if (!file || !file.size) return Promise.resolve({ ok: false, message: 'no file' });
    var form = new FormData();
    form.append('avatar', file);
    return fetch(url, {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + token },
      credentials: 'same-origin',
      body: form
    }).then(function (res) {
      if (res.status === 200) {
        return res.json().then(function (data) {
          return { ok: true, avatar_url: data.avatar_url };
        });
      }
      return res.json().catch(function () { return {}; }).then(function (body) {
        return { ok: false, status: res.status, code: body.code, message: body.message || 'upload failed' };
      });
    }).catch(function (err) {
      return { ok: false, message: err.message || 'network error' };
    });
  }

  window.MOP_WEB_API = {
    getApiBase: getApiBase,
    setApiBase: setApiBase,
    getToken: getToken,
    getUid: getUid,
    getHost: getHost,
    setLoginResult: setLoginResult,
    clearAuth: clearAuth,
    login: login,
    enroll: enroll,
    getProfile: getProfile,
    updateProfile: updateProfile,
    uploadAvatar: uploadAvatar,
    changePassword: changePassword,
    inviteGenerate: inviteGenerate
  };
})();
