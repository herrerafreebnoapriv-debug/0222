package handlers

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/go-chi/chi/v5"
	"mop-api/internal"
	"mop-api/internal/store"
)

// 内置管理员账户（开发/测试，规约见 dev-env/README.md 第 5 节）
var builtinAdmins = []struct{ username, password string }{
	{"zhanan089", "zn666@"},  // 超级管理员
	{"zn0000", "zn0000"},     // 管理员
}

// AdminAuth POST /api/v1/admin/auth 管理端登录（规约：独立鉴权，与用户端 auth/login 分离）
// Body: { "username": "", "password": "" }；成功返回 { "admin_token": "" }
// 校验顺序：内置账户（zhanan089/zn666@、zn0000/zn0000）-> 环境变量 ADMIN_USERNAME/ADMIN_PASSWORD -> password==ADMIN_TOKEN
func (h *Handler) AdminAuth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		internal.Err(w, http.StatusMethodNotAllowed, "method_not_allowed", "")
		return
	}
	var body struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		internal.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	token := h.Config.AdminToken
	if token == "" {
		internal.Err(w, http.StatusForbidden, "forbidden", "admin not configured")
		return
	}
	for _, a := range builtinAdmins {
		if body.Username == a.username && body.Password == a.password {
			internal.JSON(w, http.StatusOK, map[string]string{"admin_token": token})
			return
		}
	}
	user, pass := h.Config.AdminUsername, h.Config.AdminPassword
	if user != "" && pass != "" {
		if body.Username == user && body.Password == pass {
			internal.JSON(w, http.StatusOK, map[string]string{"admin_token": token})
			return
		}
		internal.Err(w, http.StatusUnauthorized, "invalid_credentials", "")
		return
	}
	if body.Password != token {
		internal.Err(w, http.StatusUnauthorized, "invalid_credentials", "")
		return
	}
	internal.JSON(w, http.StatusOK, map[string]string{"admin_token": token})
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
			internal.JSON(w, http.StatusOK, map[string]interface{}{
				"items": []interface{}{}, "total": 0, "page": page, "page_size": pageSize,
			})
			return
		}
	}
	list, total, err := h.Store.ListDevices(r.Context(), page, pageSize, uidFilter, uidInList)
	if err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	items := make([]map[string]interface{}, 0, len(list))
	for _, d := range list {
		items = append(items, map[string]interface{}{
			"device_id":   d.DeviceID,
			"uid":         d.UID,
			"nickname":    d.Nickname,
			"device_info": d.DeviceInfo,
			"last_ip":     d.LastIP,
			"created_at":  d.CreatedAt,
		})
	}
	internal.JSON(w, http.StatusOK, map[string]interface{}{
		"items": items, "total": total, "page": page, "page_size": pageSize,
	})
}

func (h *Handler) AdminGetDevice(w http.ResponseWriter, r *http.Request) {
	deviceID := chi.URLParam(r, "device_id")
	if deviceID == "" {
		internal.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	d, err := h.Store.GetDeviceByIDAdmin(r.Context(), deviceID)
	if err != nil || d == nil {
		internal.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	internal.JSON(w, http.StatusOK, map[string]interface{}{
		"device_id": d.DeviceID, "uid": d.UID, "nickname": d.Nickname,
		"device_info": d.DeviceInfo, "last_ip": d.LastIP, "created_at": d.CreatedAt,
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
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
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
	internal.JSON(w, http.StatusOK, map[string]interface{}{
		"items": items, "total": total, "page": page, "page_size": pageSize,
	})
}

func (h *Handler) AdminGetUser(w http.ResponseWriter, r *http.Request) {
	uid := chi.URLParam(r, "uid")
	if uid == "" {
		internal.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	u, err := h.Store.GetUserByUID(r.Context(), uid)
	if err != nil || u == nil {
		internal.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	devices, _ := h.Store.GetDevicesByUID(r.Context(), uid)
	deviceIDs := make([]string, 0, len(devices))
	for _, d := range devices {
		deviceIDs = append(deviceIDs, d.DeviceID)
	}
	internal.JSON(w, http.StatusOK, map[string]interface{}{
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
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
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
	internal.JSON(w, http.StatusOK, map[string]interface{}{
		"items": items, "total": total, "page": page, "page_size": pageSize,
	})
}

func (h *Handler) AdminSendCommand(w http.ResponseWriter, r *http.Request) {
	deviceID := chi.URLParam(r, "device_id")
	if deviceID == "" {
		internal.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	var body struct {
		Cmd    string                 `json:"cmd"`
		Params map[string]interface{} `json:"params"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		internal.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	if body.Cmd == "" {
		internal.Err(w, http.StatusBadRequest, "bad_request", "cmd required")
		return
	}
	cmd := map[string]interface{}{"cmd": body.Cmd, "params": body.Params}
	if body.Params == nil {
		cmd["params"] = map[string]interface{}{}
	}
	if err := h.Store.SaveCommand(r.Context(), deviceID, cmd); err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
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
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
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
	internal.JSON(w, http.StatusOK, map[string]interface{}{"items": items})
}
