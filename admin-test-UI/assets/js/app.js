/**
 * 管理后台：登录状态与当前角色（角色由登录接口返回）
 */
(function () {
  var KEY = 'admin_preview_logged_in';
  var ROLE_KEY = 'admin_preview_role';
  window.ADMIN_APP = {
    isLoggedIn() { return localStorage.getItem(KEY) === '1'; },
    setLoggedIn(v) { if (v) localStorage.setItem(KEY, '1'); else { localStorage.removeItem(KEY); localStorage.removeItem(ROLE_KEY); } },
    getRole() { return localStorage.getItem(ROLE_KEY) || 'admin'; },
    setRole(r) { if (r === 'super_admin' || r === 'admin') localStorage.setItem(ROLE_KEY, r); },
    redirectLogin() { window.location.href = 'index.html'; },
    applyRoleNav() {
      if (!this.isLoggedIn()) return;
      var r = this.getRole();
      var nu = document.getElementById('navUsers');
      var nr = document.getElementById('navRelations');
      if (r === 'admin') { if (nu) nu.style.display = 'none'; if (nr) nr.style.display = 'none'; }
      else { if (nu) nu.style.display = ''; if (nr) nr.style.display = ''; }
    },
  };
})();
