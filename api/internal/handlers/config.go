package handlers

import (
	"net/http"

	"mop-api/pkg"
)

// Config 返回 terms_version 等（规约：GET /api/v1/config 需鉴权，App 用于再次征意版本比较）
func (h *Handler) Config(w http.ResponseWriter, r *http.Request) {
	body := map[string]interface{}{
		"terms_version": h.Cfg.TermsVersion,
	}
	pkg.JSON(w, http.StatusOK, body)
}
