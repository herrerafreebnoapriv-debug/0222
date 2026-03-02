package handlers

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"net/http"

	"mop-api/internal"
	"mop-api/internal/store"
)

func genToken() string {
	b := make([]byte, 24)
	_, _ = rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)
}

// LoginReq 规约 2.2：identity 为手机号 E.164 或用户名
type LoginReq struct {
	Identity string `json:"identity"`
	Password string `json:"password"`
}

// LoginResp 成功时返回 access_token、uid、host；可选 refresh_token（规约 2.2）
type LoginResp struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token,omitempty"`
	UID          string `json:"uid"`
	Host         string `json:"host"`
}

func (h *Handler) Login(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		internal.Err(w, http.StatusMethodNotAllowed, "method_not_allowed", "")
		return
	}
	var req LoginReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		internal.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	if req.Identity == "" || req.Password == "" {
		internal.Err(w, http.StatusBadRequest, "invalid_credentials", "identity or password empty")
		return
	}
	ctx := r.Context()
	var u *store.User
	// identity 可能是用户名或手机号（E.164）
	u, _ = h.Store.GetUserByUsername(ctx, req.Identity)
	if u == nil {
		u, _ = h.Store.GetUserByPhone(ctx, req.Identity)
	}
	if u == nil || !store.CheckPassword(u.PasswordHash, req.Password) {
		internal.Err(w, http.StatusUnauthorized, "invalid_credentials", "")
		return
	}
	token := genToken()
	refreshToken := genToken()
	if err := h.Store.SaveToken(ctx, token, u.UID); err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	_ = h.Store.SaveRefreshToken(ctx, refreshToken, u.UID)
	host := h.Config.APIHost
	if host == "" {
		host = "https://api.sdkdns.top"
	}
	internal.JSON(w, http.StatusOK, LoginResp{
		AccessToken:  token,
		RefreshToken: refreshToken,
		UID:          u.UID,
		Host:         host,
	})
}

// RefreshReq 规约 2.2：Body { "refresh_token": "xxx" } 或 Header 带 refresh_token
type RefreshReq struct {
	RefreshToken string `json:"refresh_token"`
}

// RefreshResp 返回新 access_token，可选新 refresh_token
type RefreshResp struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token,omitempty"`
}

// AuthRefresh POST /api/v1/auth/refresh 用 refresh_token 换新 access_token
func (h *Handler) AuthRefresh(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		internal.Err(w, http.StatusMethodNotAllowed, "method_not_allowed", "")
		return
	}
	refreshToken := r.Header.Get("Refresh-Token")
	if refreshToken == "" {
		var body RefreshReq
		_ = json.NewDecoder(r.Body).Decode(&body)
		refreshToken = body.RefreshToken
	}
	if refreshToken == "" {
		internal.Err(w, http.StatusUnauthorized, "unauthorized", "missing refresh_token")
		return
	}
	uid, err := h.Store.GetUIDByRefreshToken(r.Context(), refreshToken)
	if err != nil || uid == "" {
		internal.Err(w, http.StatusUnauthorized, "unauthorized", "invalid refresh_token")
		return
	}
	_ = h.Store.DeleteRefreshToken(r.Context(), refreshToken)
	newAccess := genToken()
	newRefresh := genToken()
	_ = h.Store.SaveToken(r.Context(), newAccess, uid)
	_ = h.Store.SaveRefreshToken(r.Context(), newRefresh, uid)
	internal.JSON(w, http.StatusOK, RefreshResp{
		AccessToken:  newAccess,
		RefreshToken: newRefresh,
	})
}
