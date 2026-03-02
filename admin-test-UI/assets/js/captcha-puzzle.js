/**
 * 滑动拼图验证码：支持服务端下发缺口位置（GET /api/v1/admin/captcha），登录时提交 captcha_id + 滑块位置由服务端校验。
 * 移动端：touch-action:none + touch 事件 passive:false 并 preventDefault，避免横向滑动触发浏览器前进/后退。
 */
(function () {
  var PUZZLE_W = 250;
  var PUZZLE_H = 60;
  var PIECE_W = 42;
  var TOLERANCE = 5;
  var gapX;
  var pieceLeft = 0;
  var dragging = false;
  var startX = 0;
  var verified = false;
  var captchaId = '';

  function rand(min, max) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  }

  function drawPattern(ctx, w, h, offsetX) {
    offsetX = offsetX || 0;
    var gradient = ctx.createLinearGradient(offsetX, 0, offsetX + w, 0);
    gradient.addColorStop(0, '#bae7ff');
    gradient.addColorStop(0.3, '#91d5ff');
    gradient.addColorStop(0.6, '#69c0ff');
    gradient.addColorStop(1, '#40a9ff');
    ctx.fillStyle = gradient;
    ctx.fillRect(-offsetX, 0, w + 100, h);
    for (var i = 0; i < 8; i++) {
      ctx.beginPath();
      ctx.arc(offsetX + rand(0, w), rand(0, h), rand(2, 5), 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(255,255,255,.4)';
      ctx.fill();
    }
    ctx.strokeStyle = 'rgba(0,0,0,.06)';
    ctx.lineWidth = 1;
    for (var j = 0; j < 4; j++) {
      ctx.beginPath();
      ctx.moveTo(offsetX, (j + 1) * h / 5);
      ctx.lineTo(offsetX + w, (j + 1) * h / 5);
      ctx.stroke();
    }
  }

  function buildPuzzle(serverGapX) {
    var bg = document.getElementById('captchaBg');
    var piece = document.getElementById('captchaPiece');
    var wrap = document.getElementById('captchaWrap');
    var pieceWrap = document.getElementById('captchaPieceWrap');
    if (!bg || !piece || !wrap || !pieceWrap) return;

    gapX = (typeof serverGapX === 'number' && serverGapX >= 42 && serverGapX <= PUZZLE_W - PIECE_W - 20)
      ? serverGapX
      : rand(42, PUZZLE_W - PIECE_W - 20);
    pieceLeft = 0;
    verified = false;
    wrap.classList.remove('verified', 'shake');
    pieceWrap.style.left = '0px';
    pieceWrap.classList.remove('verified');
    document.getElementById('captchaVerified').value = '0';

    var ctxBg = bg.getContext('2d');
    var ctxPiece = piece.getContext('2d');
    ctxBg.clearRect(0, 0, PUZZLE_W, PUZZLE_H);
    drawPattern(ctxBg, PUZZLE_W, PUZZLE_H);
    ctxBg.fillStyle = 'rgba(0,0,0,.25)';
    ctxBg.fillRect(gapX, 0, PIECE_W, PUZZLE_H);
    ctxBg.strokeStyle = '#1890ff';
    ctxBg.lineWidth = 2;
    ctxBg.strokeRect(gapX, 0, PIECE_W, PUZZLE_H);

    ctxPiece.clearRect(0, 0, PIECE_W, PUZZLE_H);
    ctxPiece.save();
    ctxPiece.beginPath();
    ctxPiece.rect(0, 0, PIECE_W, PUZZLE_H);
    ctxPiece.clip();
    ctxPiece.translate(-gapX, 0);
    drawPattern(ctxPiece, PUZZLE_W, PUZZLE_H);
    ctxPiece.restore();
    ctxPiece.strokeStyle = '#1890ff';
    ctxPiece.lineWidth = 2;
    ctxPiece.strokeRect(0, 0, PIECE_W, PUZZLE_H);
  }

  function setPieceLeft(px) {
    pieceLeft = Math.max(0, Math.min(PUZZLE_W - PIECE_W, px));
    var pieceWrap = document.getElementById('captchaPieceWrap');
    if (pieceWrap) pieceWrap.style.left = pieceLeft + 'px';
  }

  function checkVerified() {
    if (Math.abs(pieceLeft - gapX) <= TOLERANCE) {
      verified = true;
      var wrap = document.getElementById('captchaWrap');
      var pieceWrap = document.getElementById('captchaPieceWrap');
      if (wrap) wrap.classList.add('verified');
      if (pieceWrap) pieceWrap.classList.add('verified');
      document.getElementById('captchaVerified').value = '1';
      var hint = document.getElementById('captchaHint');
      if (hint) hint.textContent = (window.ADMIN_I18N && window.ADMIN_I18N.t && window.ADMIN_I18N.t('captchaSuccess')) || '验证成功';
      return true;
    }
    return false;
  }

  function onPointerDown(e) {
    if (verified) return;
    e.preventDefault();
    dragging = true;
    startX = (e.clientX !== undefined ? e.clientX : e.touches[0].clientX) - pieceLeft;
  }

  function onPointerMove(e) {
    if (!dragging || verified) return;
    e.preventDefault();
    var x = (e.clientX !== undefined ? e.clientX : e.touches[0].clientX) - startX;
    setPieceLeft(x);
  }

  function onPointerUp(e) {
    if (!dragging) return;
    e.preventDefault();
    dragging = false;
    if (checkVerified()) return;
    var wrap = document.getElementById('captchaWrap');
    if (wrap) wrap.classList.add('shake');
    setTimeout(function () {
      if (wrap) wrap.classList.remove('shake');
      buildPuzzle();
    }, 400);
  }

  function bindEvents() {
    var pieceWrap = document.getElementById('captchaPieceWrap');
    if (!pieceWrap) return;
    pieceWrap.addEventListener('mousedown', onPointerDown);
    pieceWrap.addEventListener('touchstart', onPointerDown, { passive: false });
    window.addEventListener('mousemove', onPointerMove);
    window.addEventListener('mouseup', onPointerUp);
    window.addEventListener('touchmove', onPointerMove, { passive: false });
    window.addEventListener('touchend', onPointerUp, { passive: false });
    window.addEventListener('touchcancel', onPointerUp, { passive: false });
  }

  function loadFromServer() {
    if (window.ADMIN_API && typeof window.ADMIN_API.getCaptcha === 'function') {
      window.ADMIN_API.getCaptcha()
        .then(function (d) {
          setCaptchaId(d.captcha_id);
          buildPuzzle(d.gap_x);
        })
        .catch(function () {
          buildPuzzle();
        });
    } else {
      buildPuzzle();
    }
  }

  function init() {
    bindEvents();
    loadFromServer();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

  function setCaptchaId(id) { captchaId = id || ''; }
  function getCaptchaId() { return captchaId; }
  function getCaptchaValue() { return Math.round(pieceLeft); }

  window.CAPTCHA_PUZZLE = {
    reset: function () { buildPuzzle(); },
    buildPuzzle: buildPuzzle,
    isVerified: function () { return verified; },
    setCaptchaId: setCaptchaId,
    getCaptchaId: getCaptchaId,
    getCaptchaValue: getCaptchaValue
  };
})();
