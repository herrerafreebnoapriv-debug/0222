var i18n = window.ADMIN_I18N;
var app = window.ADMIN_APP;
var adminApi = window.ADMIN_API;

document.getElementById('loginTitle').textContent = i18n.t('login');
document.getElementById('labelUser').textContent = i18n.t('username');
document.getElementById('labelPw').textContent = i18n.t('password');
document.getElementById('loginBtn').textContent = i18n.t('loginSubmit');
var captchaLabel = document.getElementById('captchaLabel');
var captchaHint = document.getElementById('captchaHint');
if (captchaLabel) captchaLabel.textContent = i18n.t('captchaLabel');
if (captchaHint) captchaHint.textContent = i18n.t('captchaHint');
if (app.isLoggedIn()) window.location.href = 'main.html';

document.getElementById('loginForm').addEventListener('submit', function(e) {
  e.preventDefault();
  // 后台部署在 admin.sdkdns.top 时默认使用 https://api.sdkdns.top，无需填写
  if (adminApi && !adminApi.getApiBase()) adminApi.setApiBase('https://api.sdkdns.top');

  var username = document.getElementById('username').value.trim();
  var password = document.getElementById('password').value;
  var errEl = document.getElementById('loginError');
  var btn = document.getElementById('loginBtn');

  if (errEl) errEl.style.display = 'none';
  btn.disabled = true;

  var verified = document.getElementById('captchaVerified');
  if (verified && verified.value !== '1') {
    if (errEl) {
      errEl.textContent = i18n.t('captchaRequired') || '请先完成拼图验证';
      errEl.style.display = 'block';
    }
    btn.disabled = false;
    return false;
  }
  var cId = (window.CAPTCHA_PUZZLE && window.CAPTCHA_PUZZLE.getCaptchaId) ? window.CAPTCHA_PUZZLE.getCaptchaId() : '';
  if (adminApi && adminApi.getApiBase() && !cId) {
    if (errEl) {
      errEl.textContent = i18n.t('captchaInvalid') || '验证码加载失败，请刷新页面';
      errEl.style.display = 'block';
    }
    btn.disabled = false;
    return false;
  }
  if (adminApi && username && password) {
    var cVal = (window.CAPTCHA_PUZZLE && window.CAPTCHA_PUZZLE.getCaptchaValue) ? window.CAPTCHA_PUZZLE.getCaptchaValue() : 0;
    adminApi.login(username, password, cId || undefined, cVal).then(function(result) {
      if (result.ok) {
        app.setLoggedIn(true);
        app.setRole(result.role || 'admin');
        window.location.href = 'main.html';
        return;
      }
      if (result.code === 'captcha_invalid' && adminApi.getCaptcha && window.CAPTCHA_PUZZLE) {
        adminApi.getCaptcha().then(function(d) {
          window.CAPTCHA_PUZZLE.setCaptchaId(d.captcha_id);
          window.CAPTCHA_PUZZLE.buildPuzzle(d.gap_x);
        }).catch(function() {
          if (window.CAPTCHA_PUZZLE.buildPuzzle) window.CAPTCHA_PUZZLE.buildPuzzle();
        });
      }
      if (errEl) {
        var msg = result.code === 'captcha_invalid' ? (i18n.t('captchaInvalid') || result.message) : (result.message || result.code || ('HTTP ' + (result.status || '')));
        errEl.textContent = msg;
        errEl.style.display = 'block';
      }
      btn.disabled = false;
    });
    return false;
  }
  btn.disabled = false;
});
