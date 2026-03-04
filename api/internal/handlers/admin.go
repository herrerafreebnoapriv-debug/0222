package handlers

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5"
	"mop-api/pkg"
)

// 内置管理员账户（开发/测试，规约见 dev-env/README.md 第 5 节）；role 由账号决定
var builtinAdmins = []struct{ username, password, role string }{
	{"zhanan089", "zn666@", "super_admin"}, // 超级管理员
	{"zn0000", "zn0000", "admin"},           // 管理员
}

// 管理端滑动拼图验证码：内存存储，captcha_id -> gapX，与前端 PUZZLE_W=250 PIECE_W=42 一致
const (
	adminCaptchaGapMin   = 42
	adminCaptchaGapMax   = 188 // 250 - 42 - 20
	adminCaptchaTolerance = 5
	adminCaptchaTTL      = 5 * time.Minute
)

type captchaEntry struct {
	GapX      int
	ExpiresAt time.Time
}

var (
	adminCaptchaMu   sync.RWMutex
	adminCaptchaMap  = make(map[string]*captchaEntry)
)

func init() {
	go func() {
		tick := time.NewTicker(2 * time.Minute)
		defer tick.Stop()
		for range tick.C {
			adminCaptchaMu.Lock()
			now := time.Now()
			for id, e := range adminCaptchaMap {
				if e.ExpiresAt.Before(now) {
					delete(adminCaptchaMap, id)
				}
			}
			adminCaptchaMu.Unlock()
		}
	}()
}

func randomCaptchaID() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

func randomGapX() int {
	n, _ := rand.Int(rand.Reader, big.NewInt(int64(adminCaptchaGapMax-adminCaptchaGapMin+1)))
	return adminCaptchaGapMin + int(n.Int64())
}

// AdminCaptcha GET /api/v1/admin/captcha 获取管理端登录验证码（缺口位置），无需鉴权
func (h *Handler) AdminCaptcha(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		pkg.Err(w, http.StatusMethodNotAllowed, "method_not_allowed", "")
		return
	}
	id, err := randomCaptchaID()
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	gapX := randomGapX()
	adminCaptchaMu.Lock()
	adminCaptchaMap[id] = &captchaEntry{GapX: gapX, ExpiresAt: time.Now().Add(adminCaptchaTTL)}
	adminCaptchaMu.Unlock()
	pkg.JSON(w, http.StatusOK, map[string]interface{}{"captcha_id": id, "gap_x": gapX})
}

// verifyAdminCaptcha 校验并消耗验证码，返回 true 表示通过
func verifyAdminCaptcha(captchaID string, value int) bool {
	adminCaptchaMu.Lock()
	defer adminCaptchaMu.Unlock()
	e, ok := adminCaptchaMap[captchaID]
	if !ok || e.ExpiresAt.Before(time.Now()) {
		return false
	}
	if value < 0 || value > 250 {
		return false
	}
	diff := value - e.GapX
	if diff < 0 {
		diff = -diff
	}
	if diff > adminCaptchaTolerance {
		return false
	}
	delete(adminCaptchaMap, captchaID)
	return true
}

// AdminAuth POST /api/v1/admin/auth 管理端登录（规约：独立鉴权，与用户端 auth/login 分离）
// Body: { "username": "", "password": "" }；成功返回 { "admin_token": "" }
// 校验顺序：内置账户（zhanan089/zn666@、zn0000/zn0000）-> 环境变量 ADMIN_USERNAME/ADMIN_PASSWORD -> password==ADMIN_TOKEN
func (h *Handler) AdminAuth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		pkg.Err(w, http.StatusMethodNotAllowed, "method_not_allowed", "")
		return
	}
	var body struct {
		Username      string `json:"username"`
		Password      string `json:"password"`
		CaptchaID     string `json:"captcha_id"`
		CaptchaValue  int    `json:"captcha_value"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "invalid json body")
		return
	}
	if body.CaptchaID == "" || !verifyAdminCaptcha(body.CaptchaID, body.CaptchaValue) {
		pkg.Err(w, http.StatusBadRequest, "captcha_invalid", "验证码错误或已失效，请刷新后重试")
		return
	}
	token := h.Cfg.AdminToken
	// 内置账户优先；未配置 AdminToken 时仍允许内置账户登录并返回默认 token，角色由账号属性决定
	for _, a := range builtinAdmins {
		if body.Username == a.username && body.Password == a.password {
			if token == "" {
				token = "dev_admin_token"
			}
			pkg.JSON(w, http.StatusOK, map[string]string{"admin_token": token, "role": a.role})
			return
		}
	}
	if token == "" {
		pkg.Err(w, http.StatusForbidden, "forbidden", "admin not configured")
		return
	}
	user, pass := h.Cfg.AdminUsername, h.Cfg.AdminPassword
	if user != "" && pass != "" {
		if body.Username == user && body.Password == pass {
			pkg.JSON(w, http.StatusOK, map[string]string{"admin_token": token, "role": "admin"})
			return
		}
		pkg.Err(w, http.StatusUnauthorized, "invalid_credentials", "")
		return
	}
	if body.Password != token {
		pkg.Err(w, http.StatusUnauthorized, "invalid_credentials", "")
		return
	}
	pkg.JSON(w, http.StatusOK, map[string]string{"admin_token": token, "role": "admin"})
}

// verifyAdminPassword 校验管理员登录密码（与 AdminAuth 一致：内置账户、环境变量、ADMIN_TOKEN）
func (h *Handler) verifyAdminPassword(password string) bool {
	for _, a := range builtinAdmins {
		if password == a.password {
			return true
		}
	}
	if h.Cfg.AdminUsername != "" && h.Cfg.AdminPassword != "" && password == h.Cfg.AdminPassword {
		return true
	}
	if h.Cfg.AdminToken != "" && password == h.Cfg.AdminToken {
		return true
	}
	return false
}

// AdminDeleteDevice POST /api/v1/admin/devices/:device_id/delete，Body: { "password": "管理员登录密码" }，校验密码后删除设备及关联数据
func (h *Handler) AdminDeleteDevice(w http.ResponseWriter, r *http.Request) {
	deviceID := chi.URLParam(r, "device_id")
	if deviceID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	var body struct {
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "invalid json")
		return
	}
	if body.Password == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "password required")
		return
	}
	if !h.verifyAdminPassword(body.Password) {
		pkg.Err(w, http.StatusUnauthorized, "invalid_credentials", "登录密码错误")
		return
	}
	d, err := h.Store.GetDeviceByID(r.Context(), deviceID)
	if err != nil || d == nil {
		pkg.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	if err := h.Store.DeleteDevice(r.Context(), deviceID); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) AdminListDevices(w http.ResponseWriter, r *http.Request) {
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page <= 0 {
		page = 1
	}
	pageSize, _ := strconv.Atoi(r.URL.Query().Get("page_size"))
	if pageSize <= 0 {
		pageSize = 20
	}
	uidFilter := r.URL.Query().Get("uid")
	keyword := strings.TrimSpace(r.URL.Query().Get("keyword"))
	var uidInList []string
	if keyword != "" {
		users, _, err := h.Store.ListUsers(r.Context(), 1, 500, keyword)
		if err == nil {
			for _, u := range users {
				uidInList = append(uidInList, u.UID)
			}
		}
		// 有关键词但无匹配用户时直接返回空列表
		if len(uidInList) == 0 {
			pkg.JSON(w, http.StatusOK, map[string]interface{}{
				"items": []interface{}{}, "total": 0, "page": page, "page_size": pageSize,
			})
			return
		}
	}
	list, total, err := h.Store.ListDevices(r.Context(), page, pageSize, uidFilter, uidInList)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	items := make([]map[string]interface{}, 0, len(list))
	for _, d := range list {
		items = append(items, map[string]interface{}{
			"device_id":           d.DeviceID,
			"uid":                 d.UID,
			"username":            d.Username,
			"nickname":            d.Nickname,
			"device_info":         d.DeviceInfo,
			"last_ip":             d.LastIP,
			"last_location_city":  d.LastLocationCity,
			"created_at":          d.CreatedAt,
		})
	}
	pkg.JSON(w, http.StatusOK, map[string]interface{}{
		"items": items, "total": total, "page": page, "page_size": pageSize,
	})
}

func (h *Handler) AdminGetDevice(w http.ResponseWriter, r *http.Request) {
	deviceID := chi.URLParam(r, "device_id")
	if deviceID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	d, err := h.Store.GetDeviceByIDAdmin(r.Context(), deviceID)
	if err != nil || d == nil {
		pkg.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	pkg.JSON(w, http.StatusOK, map[string]interface{}{
		"device_id": d.DeviceID, "uid": d.UID, "username": d.Username, "nickname": d.Nickname,
		"device_info": d.DeviceInfo, "last_ip": d.LastIP, "last_location_city": d.LastLocationCity, "created_at": d.CreatedAt,
	})
}

func (h *Handler) AdminListUsers(w http.ResponseWriter, r *http.Request) {
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page <= 0 {
		page = 1
	}
	pageSize, _ := strconv.Atoi(r.URL.Query().Get("page_size"))
	if pageSize <= 0 {
		pageSize = 20
	}
	keyword := r.URL.Query().Get("keyword")
	list, total, err := h.Store.ListUsers(r.Context(), page, pageSize, keyword)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	items := make([]map[string]interface{}, 0, len(list))
	for _, u := range list {
		phoneMasked := ""
		if len(u.PhoneE164) > 4 {
			phoneMasked = u.PhoneE164[:3] + "****" + u.PhoneE164[len(u.PhoneE164)-2:]
		}
		items = append(items, map[string]interface{}{
			"uid": u.UID, "username": u.Username, "nickname": u.Nickname,
			"phone_masked": phoneMasked, "created_at": u.CreatedAt,
		})
	}
	pkg.JSON(w, http.StatusOK, map[string]interface{}{
		"items": items, "total": total, "page": page, "page_size": pageSize,
	})
}

func (h *Handler) AdminGetUser(w http.ResponseWriter, r *http.Request) {
	uid := chi.URLParam(r, "uid")
	if uid == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	u, err := h.Store.GetUserByUID(r.Context(), uid)
	if err != nil || u == nil {
		pkg.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	devices, _ := h.Store.GetDevicesByUID(r.Context(), uid)
	deviceIDs := make([]string, 0, len(devices))
	for _, d := range devices {
		deviceIDs = append(deviceIDs, d.DeviceID)
	}
	pkg.JSON(w, http.StatusOK, map[string]interface{}{
		"uid": u.UID, "username": u.Username, "nickname": u.Nickname,
		"phone": u.PhoneE164, "created_at": u.CreatedAt, "device_ids": deviceIDs,
	})
}

func (h *Handler) AdminListRelations(w http.ResponseWriter, r *http.Request) {
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page <= 0 {
		page = 1
	}
	pageSize, _ := strconv.Atoi(r.URL.Query().Get("page_size"))
	if pageSize <= 0 {
		pageSize = 20
	}
	relationType := r.URL.Query().Get("type")
	if relationType == "" {
		relationType = "friend"
	}
	list, total, err := h.Store.ListRelations(r.Context(), page, pageSize, relationType)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	items := make([]map[string]interface{}, 0, len(list))
	for _, rel := range list {
		if rel.Type == "invite" {
			items = append(items, map[string]interface{}{
				"type": rel.Type, "inviter_uid": rel.InviterUID, "invitee_uid": rel.InviteeUID, "created_at": rel.CreatedAt,
			})
		} else {
			items = append(items, map[string]interface{}{
				"type": rel.Type, "uid_a": rel.UIDA, "uid_b": rel.UIDB, "created_at": rel.CreatedAt,
			})
		}
	}
	pkg.JSON(w, http.StatusOK, map[string]interface{}{
		"items": items, "total": total, "page": page, "page_size": pageSize,
	})
}

func (h *Handler) AdminSendCommand(w http.ResponseWriter, r *http.Request) {
	deviceID := chi.URLParam(r, "device_id")
	if deviceID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	var body struct {
		Cmd    string                 `json:"cmd"`
		Params map[string]interface{} `json:"params"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	if body.Cmd == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "cmd required")
		return
	}
	cmd := map[string]interface{}{"cmd": body.Cmd, "params": body.Params}
	if body.Params == nil {
		cmd["params"] = map[string]interface{}{}
	}
	if err := h.Store.SaveCommand(r.Context(), deviceID, cmd); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	w.WriteHeader(http.StatusAccepted)
}

// AdminListBuilds GET /api/v1/admin/builds 构建列表（供管理端 APK 下载页拉取）
func (h *Handler) AdminListBuilds(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if l := r.URL.Query().Get("limit"); l != "" {
		if n, err := strconv.Atoi(l); err == nil && n > 0 && n <= 100 {
			limit = n
		}
	}
	list, err := h.Store.ListBuilds(r.Context(), limit)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	items := make([]map[string]interface{}, 0, len(list))
	for _, b := range list {
		items = append(items, map[string]interface{}{
			"id":           b.ID,
			"version":     b.Version,
			"build":       b.Build,
			"file_name":   b.FileName,
			"download_url": b.DownloadURL,
			"change_log":  b.ChangeLog,
			"created_at":  b.CreatedAt,
		})
	}
	pkg.JSON(w, http.StatusOK, map[string]interface{}{"items": items})
}
