package handlers

import (
	"encoding/json"
	"net/http"

	"mop-api/internal"
	"mop-api/internal/middleware"
	"mop-api/internal/store"
)

// GetProfile GET /api/v1/user/profile 返回当前用户昵称、简介、头像等（不含手机号）
func (h *Handler) GetProfile(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		internal.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	u, err := h.Store.GetUserByUID(r.Context(), uid)
	if err != nil || u == nil {
		internal.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	internal.JSON(w, http.StatusOK, map[string]string{
		"uid":      u.UID,
		"username": u.Username,
		"nickname": u.Nickname,
		"bio":      u.Bio,
		"avatar_url": u.AvatarPath,
	})
}

// UpdateProfile PATCH /api/v1/user/profile 更新昵称、简介
func (h *Handler) UpdateProfile(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		internal.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	var body struct {
		Nickname string `json:"nickname"`
		Bio      string `json:"bio"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)
	if err := h.Store.UpdateUserProfile(r.Context(), uid, body.Nickname, body.Bio); err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	w.WriteHeader(http.StatusOK)
}

// ChangePassword POST /api/v1/user/change-password
func (h *Handler) ChangePassword(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		internal.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	var body struct {
		OldPassword string `json:"old_password"`
		NewPassword string `json:"new_password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		internal.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	if len(body.NewPassword) < 6 || len(body.NewPassword) > 18 {
		internal.Err(w, http.StatusBadRequest, "bad_request", "password length 6-18")
		return
	}
	u, _ := h.Store.GetUserByUID(r.Context(), uid)
	if u == nil || !store.CheckPassword(u.PasswordHash, body.OldPassword) {
		internal.Err(w, http.StatusUnauthorized, "invalid_credentials", "")
		return
	}
	hash, err := store.HashPassword(body.NewPassword)
	if err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	if err := h.Store.UpdateUserPassword(r.Context(), uid, hash); err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	w.WriteHeader(http.StatusOK)
}

// GetFriends GET /api/v1/user/friends 好友列表，返回 uid、nickname、bio
func (h *Handler) GetFriends(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		internal.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	list, err := h.Store.GetFriends(r.Context(), uid)
	if err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	items := make([]map[string]string, 0, len(list))
	for _, f := range list {
		items = append(items, map[string]string{
			"uid":      f.UID,
			"nickname": f.Nickname,
			"bio":      f.Bio,
			"avatar_url": f.AvatarPath,
		})
	}
	internal.JSON(w, http.StatusOK, map[string]interface{}{"items": items})
}

// UserSearch GET /api/v1/user/search?q=xxx 精确匹配用户名或手机号，仅返回可展示字段（不含手机号）
func (h *Handler) UserSearch(w http.ResponseWriter, r *http.Request) {
	_ = middleware.GetUID(r.Context()) // 需鉴权，由路由中间件保证
	q := r.URL.Query().Get("q")
	if q == "" {
		internal.JSON(w, http.StatusOK, []interface{}{})
		return
	}
	ctx := r.Context()
	var u *store.User
	u, _ = h.Store.GetUserByUsername(ctx, q)
	if u == nil {
		u, _ = h.Store.GetUserByPhone(ctx, q)
	}
	if u == nil {
		internal.JSON(w, http.StatusOK, []interface{}{})
		return
	}
	internal.JSON(w, http.StatusOK, []map[string]string{
		{"uid": u.UID, "nickname": u.Nickname, "bio": u.Bio, "avatar_url": u.AvatarPath},
	})
}
