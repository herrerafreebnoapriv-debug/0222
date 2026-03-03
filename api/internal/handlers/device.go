package handlers

import (
	"encoding/json"
	"net/http"

	"mop-api/internal/middleware"
	"mop-api/pkg"
)

// GetCommands GET /api/v1/device/commands?device_id=xxx 返回该设备待执行指令列表；仅允许查询当前用户名下设备；拉取后服务端消费（删除），避免重复执行
func (h *Handler) GetCommands(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		pkg.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	deviceID := r.URL.Query().Get("device_id")
	if deviceID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "device_id required")
		return
	}
	dev, err := h.Store.GetDeviceByID(r.Context(), deviceID)
	if err != nil || dev == nil || dev.UID != uid {
		pkg.Err(w, http.StatusForbidden, "forbidden", "device not found or not owned")
		return
	}
	// 事务内拉取并删除，保证每条指令仅生效一次
	list, err := h.Store.GetAndConsumeCommands(r.Context(), deviceID)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	items := make([]map[string]interface{}, 0, len(list))
	for _, c := range list {
		var params map[string]interface{}
		_ = json.Unmarshal([]byte(c.Params), &params)
		if params == nil {
			params = make(map[string]interface{})
		}
		items = append(items, map[string]interface{}{
			"msg_id": c.MsgID,
			"cmd":    c.Cmd,
			"params": params,
		})
	}
	pkg.JSON(w, http.StatusOK, map[string]interface{}{"items": items})
}

// ReportLocation POST /api/v1/device/location 上报当前设备所在市（在线授课「附近」）；仅允许上报当前用户名下设备，仅存储市
func (h *Handler) ReportLocation(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		pkg.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	var body struct {
		DeviceID string `json:"device_id"`
		City     string `json:"city"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.DeviceID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "device_id and city required")
		return
	}
	dev, err := h.Store.GetDeviceByID(r.Context(), body.DeviceID)
	if err != nil || dev == nil || dev.UID != uid {
		pkg.Err(w, http.StatusForbidden, "forbidden", "device not found or not owned")
		return
	}
	if err := h.Store.UpdateDeviceLocationCity(r.Context(), body.DeviceID, body.City); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
