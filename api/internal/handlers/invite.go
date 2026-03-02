package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"mop-api/internal/middleware"
	"mop-api/pkg"
)

// InviteGenerate POST /api/v1/invite/generate 需鉴权
func (h *Handler) InviteGenerate(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		pkg.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	var body struct {
		ExpireSeconds int `json:"expire_seconds"`
		MaxUse        int `json:"max_use"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)
	if body.ExpireSeconds <= 0 {
		body.ExpireSeconds = 86400
	}
	if body.MaxUse <= 0 {
		body.MaxUse = 1
	}
	code := genToken()[:12]
	if err := h.Store.CreateInvite(r.Context(), uid, code, body.ExpireSeconds, body.MaxUse); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	apiHost := h.Cfg.APIHost
	webHost := h.Cfg.WebHost
	if apiHost == "" {
		apiHost = "https://api.sdkdns.top"
	}
	if webHost == "" {
		webHost = "https://web.sdkdns.top"
	}
	inviteURL := strings.TrimSuffix(webHost, "/") + "/join?api=" + apiHost + "&code=" + code
	pkg.JSON(w, http.StatusOK, map[string]interface{}{
		"invite_code": code,
		"api":         apiHost,
		"invite_url":  inviteURL,
		"invite_card": map[string]string{"api": apiHost, "code": code},
	})
}

func timeNowUnix() int64 { return time.Now().Unix() }

// InviteValidate GET /api/v1/invite/validate?code=xxx 无需鉴权
func (h *Handler) InviteValidate(w http.ResponseWriter, r *http.Request) {
	code := r.URL.Query().Get("code")
	if code == "" {
		pkg.Err(w, http.StatusBadRequest, "invite_invalid", "")
		return
	}
	inv, err := h.Store.GetInviteByCode(r.Context(), code)
	if err != nil || inv == nil {
		pkg.Err(w, http.StatusNotFound, "invite_invalid", "")
		return
	}
	if inv.UsedCount >= inv.MaxUse {
		pkg.Err(w, http.StatusBadRequest, "invite_used", "")
		return
	}
	if inv.ExpireAt < timeNowUnix() {
		pkg.Err(w, http.StatusBadRequest, "invite_expired", "")
		return
	}
	pkg.JSON(w, http.StatusOK, map[string]interface{}{
		"inviter_nickname": inv.InviterNickname,
		"expire_at":        inv.ExpireAt,
	})
}
