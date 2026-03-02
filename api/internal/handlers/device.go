package handlers

import (
	"encoding/json"
	"net/http"

	"mop-api/internal"
	"mop-api/internal/middleware"
)

// GetCommands GET /api/v1/device/commands?device_id=xxx 返回待执行指令列表
func (h *Handler) GetCommands(w http.ResponseWriter, r *http.Request) {
	_ = middleware.GetUID(r.Context())
	deviceID := r.URL.Query().Get("device_id")
	if deviceID == "" {
		internal.Err(w, http.StatusBadRequest, "bad_request", "device_id required")
		return
	}
	list, err := h.Store.GetPendingCommands(r.Context(), deviceID)
	if err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
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
	internal.JSON(w, http.StatusOK, map[string]interface{}{"items": items})
}
