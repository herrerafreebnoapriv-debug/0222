package handlers

import (
	"encoding/json"
	"net/http"
	"regexp"
	"strings"
	"time"

	"mop-api/internal/store"
	"mop-api/pkg"
)

// EnrollPayload 规约 2.1
type EnrollPayload struct {
	CountryCode string            `json:"country_code"`
	Phone       string            `json:"phone"`
	Username    string            `json:"username"`
	Nickname    string            `json:"nickname"`
	Password    string            `json:"password"`
	DeviceID    string            `json:"device_id"`
	DeviceInfo  map[string]string `json:"device_info"`
	InviteCode  string            `json:"invite_code"`
}

func (h *Handler) Enroll(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		pkg.Err(w, http.StatusMethodNotAllowed, "method_not_allowed", "")
		return
	}
	var payload EnrollPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	ctx := r.Context()
	if payload.Username == "" || payload.Nickname == "" || payload.Password == "" || payload.DeviceID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "missing required fields")
		return
	}
	phoneE164 := payload.Phone
	if payload.CountryCode != "" && !strings.HasPrefix(phoneE164, "+") {
		phoneE164 = strings.TrimPrefix(payload.CountryCode, "+") + strings.TrimLeft(phoneE164, "0")
		if !strings.HasPrefix(phoneE164, "+") {
			phoneE164 = "+" + phoneE164
		}
	}
	if phoneE164 == "" || phoneE164 == "+" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "phone required")
		return
	}
	if len(payload.Password) < 6 || len(payload.Password) > 18 {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "password length 6-18")
		return
	}
	if !regexp.MustCompile(`^[a-zA-Z0-9_]+$`).MatchString(payload.Username) {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "invalid username")
		return
	}
	if u, _ := h.Store.GetUserByUsername(ctx, payload.Username); u != nil {
		pkg.Err(w, http.StatusConflict, "username_exists", "")
		return
	}
	if u, _ := h.Store.GetUserByPhone(ctx, phoneE164); u != nil {
		pkg.Err(w, http.StatusConflict, "phone_exists", "")
		return
	}
	inviterUID := ""
	if payload.InviteCode != "" {
		inv, _ := h.Store.GetInviteByCode(ctx, payload.InviteCode)
		if inv == nil {
			pkg.Err(w, http.StatusBadRequest, "invite_invalid", "")
			return
		}
		if inv.UsedCount >= inv.MaxUse {
			pkg.Err(w, http.StatusBadRequest, "invite_used", "")
			return
		}
		if inv.ExpireAt < time.Now().Unix() {
			pkg.Err(w, http.StatusBadRequest, "invite_expired", "")
			return
		}
		inviterUID = inv.InviterUID
	}
	// 设备已绑定时允许继续 enroll：BindDevice 为 upsert，新用户覆盖该设备绑定（擦除后重注册、换账号注册）。PROTOCOL 2.1 将 device_already_bound 列为典型错误码，此处选择允许覆盖以支持上述场景。
	passwordHash, err := store.HashPassword(payload.Password)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	uid, err := h.Store.CreateUser(ctx, phoneE164, payload.Username, payload.Nickname, passwordHash)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	if err := h.Store.BindDevice(ctx, payload.DeviceID, uid, payload.DeviceInfo); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	_ = h.Store.UpdateDeviceLastIP(ctx, payload.DeviceID, pkg.ClientIP(r))
	if inviterUID != "" {
		_ = h.Store.UseInvite(ctx, payload.InviteCode)
		_ = h.Store.AddFriend(ctx, inviterUID, uid)
		_ = h.Store.SaveInviteRelation(ctx, inviterUID, uid)
	}
	token := genToken()
	refreshToken := genToken()
	_ = h.Store.SaveToken(ctx, token, uid)
	_ = h.Store.SaveRefreshToken(ctx, refreshToken, uid)
	host := h.Cfg.APIHost
	if host == "" {
		host = "https://api.sdkdns.top"
	}
	pkg.JSON(w, http.StatusOK, map[string]string{
		"access_token":  token,
		"refresh_token": refreshToken,
		"uid":           uid,
		"host":          host,
	})
}
