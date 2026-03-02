/**
 * 流程预览用：模拟登录状态、跳转、以及界面文案刷新
 */
(function () {
  const STORAGE_KEY = 'mop_preview_logged_in';
  const TERMS_VERSION_KEY = 'mop_preview_terms_version';
  const REMARKS_KEY = 'mop_preview_remarks';
  const CONTACT_PROFILES_KEY = 'mop_preview_contact_profiles';
  const REMARK_MAX_LEN = 20; // 备注最多 20 个字符（汉字与英文等均按 1 字符计）
  const TERMS_VERSION = '1.0';
  var DEFAULT_BIOS = { '张三': '产品经理 · 喜欢跑步', '李四': 'UI 设计师', '王五': '后端开发', '项目组': '团队工作群' };

  window.MOP_APP = {
    isLoggedIn() {
      return localStorage.getItem(STORAGE_KEY) === '1';
    },
    setLoggedIn(value) {
      if (value) localStorage.setItem(STORAGE_KEY, '1');
      else localStorage.removeItem(STORAGE_KEY);
    },
    getTermsAcceptedVersion() {
      return localStorage.getItem(TERMS_VERSION_KEY) || '';
    },
    setTermsAccepted(version) {
      localStorage.setItem(TERMS_VERSION_KEY, version || TERMS_VERSION);
    },
    needShowTerms() {
      return this.getTermsAcceptedVersion() !== TERMS_VERSION;
    },
    redirectToLogin() {
      window.location.href = 'index.html';
    },
    redirectToMain() {
      window.location.href = 'main.html';
    },
    redirectToSettings() {
      window.location.href = 'settings.html';
    },
    logout() {
      this.setLoggedIn(false);
      this.redirectToLogin();
    },
    getRemarks() {
      try {
        var raw = localStorage.getItem(REMARKS_KEY);
        return raw ? JSON.parse(raw) : {};
      } catch (e) { return {}; }
    },
    setRemark(name, remark) {
      var o = this.getRemarks();
      name = (name || '').trim();
      if (!name) return;
      var val = (remark || '').trim();
      if (val === '') delete o[name]; else o[name] = val.slice(0, REMARK_MAX_LEN);
      localStorage.setItem(REMARKS_KEY, JSON.stringify(o));
    },
    getRemarkDisplay(remarkOrName) {
      var s = (remarkOrName || '').trim();
      return s.slice(0, REMARK_MAX_LEN);
    },
    getContactProfiles() {
      try {
        var raw = localStorage.getItem(CONTACT_PROFILES_KEY);
        var o = raw ? JSON.parse(raw) : {};
        var out = {};
        for (var k in DEFAULT_BIOS) out[k] = (o[k] && o[k].bio != null) ? o[k].bio : DEFAULT_BIOS[k];
        for (var k in o) if (!out[k] && o[k] && o[k].bio != null) out[k] = o[k].bio;
        return out;
      } catch (e) { return DEFAULT_BIOS; }
    },
    setContactBio(name, bio) {
      var o = {};
      try {
        var raw = localStorage.getItem(CONTACT_PROFILES_KEY);
        if (raw) o = JSON.parse(raw);
      } catch (e) {}
      name = (name || '').trim();
      if (!name) return;
      if (!o[name]) o[name] = {};
      o[name].bio = (bio || '').trim();
      localStorage.setItem(CONTACT_PROFILES_KEY, JSON.stringify(o));
    },
    remarkMaxLen: REMARK_MAX_LEN,
  };
})();
