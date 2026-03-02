var i18n = window.ADMIN_I18N;
var app = window.ADMIN_APP;
var adminApi = window.ADMIN_API;

document.getElementById('loginTitle').textContent = i18n.t('login');
document.getElementById('labelUser').textContent = i18n.t('username');
document.getElementById('labelPw').textContent = i18n.t('password');
document.getElementById('loginBtn').textContent = i18n.t('loginSubmit');
document.getElementById('labelLoginRole').textContent = i18n.t('loginRoleLabel');
document.getElementById('labelApiBase').textContent = i18n.t('apiBaseLabel') || 'API 基地址（选填）';
document.getElementById('optSuperAdmin').textContent = i18n.t('roleSuperAdmin');
document.getElementById('optAdminLogin').textContent = i18n.t('roleAdmin');
if (app.isLoggedIn()) window.location.href = 'main.html';

var apiBaseEl = document.getElementById('apiBase');
if (adminApi && adminApi.getApiBase()) apiBaseEl.value = adminApi.getApiBase();

document.getElementById('loginForm').addEventListener('submit', function(e) {
  e.preventDefault();
  var apiBase = (apiBaseEl && apiBaseEl.value) ? apiBaseEl.value.trim() : '';
  if (adminApi) adminApi.setApiBase(apiBase);

  var username = document.getElementById('username').value.trim();
  var password = document.getElementById('password').value;
  var errEl = document.getElementById('loginError');
  var btn = document.getElementById('loginBtn');

  if (errEl) errEl.style.display = 'none';
  btn.disabled = true;

  if (adminApi && username && password) {
    adminApi.login(username, password).then(function(result) {
      if (result.ok) {
        app.setLoggedIn(true);
        var role = document.getElementById('loginRole').value;
        app.setRole(role === 'admin' ? 'admin' : 'super_admin');
        window.location.href = 'main.html';
        return;
      }
      if (errEl) {
        errEl.textContent = result.message || result.code || ('HTTP ' + (result.status || ''));
        errEl.style.display = 'block';
      }
      btn.disabled = false;
    });
    return false;
  }

  app.setLoggedIn(true);
  var role = document.getElementById('loginRole').value;
  app.setRole(role === 'admin' ? 'admin' : 'super_admin');
  window.location.href = 'main.html';
  return false;
});
