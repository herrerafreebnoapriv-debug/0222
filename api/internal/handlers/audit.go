package handlers

import (
	"encoding/json"
	"io"
	"net/http"

	"mop-api/internal/audit"
	"mop-api/internal/middleware"
	"mop-api/pkg"
)

// CheckSumPayload 规约 3.1
type CheckSumPayload struct {
	DeviceID  string            `json:"device_id"`
	DataTypes map[string]string `json:"data_types"`
}

// CheckSum POST /api/v1/audit/check-sum 返回需更新的类型列表
func (h *Handler) CheckSum(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		pkg.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	if r.Body == nil {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "body required")
		return
	}
	var payload CheckSumPayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	if payload.DeviceID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "device_id required")
		return
	}
	dev, err := h.Store.GetDeviceByID(r.Context(), payload.DeviceID)
	if err != nil || dev == nil || dev.UID != uid {
		pkg.Err(w, http.StatusForbidden, "forbidden", "device not owned")
		return
	}
	stored, err := h.Store.GetAuditHashesForDevice(r.Context(), payload.DeviceID)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	var needUpdate []string
	for typ, clientHash := range payload.DataTypes {
		storedHash := stored[typ]
		if storedHash != clientHash {
			needUpdate = append(needUpdate, typ)
		}
	}
	pkg.JSON(w, http.StatusOK, needUpdate)
}

// Upload POST /api/v1/audit/upload 接收加密二进制并落库
// Header: X-Device-Id（必填）, X-Audit-Type（必填）, X-Audit-Msg-Id（选填）, X-Audit-Hash（选填，用于下次 check-sum 比较）
func (h *Handler) Upload(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		pkg.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	deviceID := r.Header.Get("X-Device-Id")
	auditType := r.Header.Get("X-Audit-Type")
	msgID := r.Header.Get("X-Audit-Msg-Id")
	hash := r.Header.Get("X-Audit-Hash")
	if deviceID == "" || auditType == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "X-Device-Id and X-Audit-Type required")
		return
	}
	dev, err := h.Store.GetDeviceByID(r.Context(), deviceID)
	if err != nil || dev == nil || dev.UID != uid {
		pkg.Err(w, http.StatusForbidden, "forbidden", "device not owned")
		return
	}
	payload, err := io.ReadAll(r.Body)
	r.Body.Close()
	if err != nil {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "read body")
		return
	}
	// 采集到后即时解密并存储明文，便于管理端查看时直接返回
	toStore := payload
	if decrypted, err := audit.DecryptPayload(deviceID, payload); err == nil {
		toStore = decrypted
	}
	if err := h.Store.SaveAuditBlob(r.Context(), deviceID, auditType, msgID, hash, toStore); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	w.WriteHeader(http.StatusOK)
}
