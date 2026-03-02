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
	list, err := h.Store.GetPendingCommands(r.Context(), deviceID)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	msgIDs := make([]string, 0, len(list))
	items := make([]map[string]interface{}, 0, len(list))
	for _, c := range list {
		msgIDs = append(msgIDs, c.MsgID)
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
	// 拉取后消费，避免客户端下次轮询再次执行同一条指令
	_ = h.Store.DeleteCommandsByMsgIDs(r.Context(), deviceID, msgIDs)
	pkg.JSON(w, http.StatusOK, map[string]interface{}{"items": items})
}
