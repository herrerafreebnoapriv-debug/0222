package handlers

import (
	"encoding/json"
	"net/http"

	"mop-api/internal/store"
	"mop-api/pkg"
)

// BuildSync POST /api/v1/internal/build-sync（PROTOCOL 5，Header: X-Build-Token）
func (h *Handler) BuildSync(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Version     string `json:"version"`
		Build       int    `json:"build"`
		FileName    string `json:"file_name"`
		DownloadURL string `json:"download_url"`
		ChangeLog   string `json:"change_log"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	if body.FileName == "" || body.DownloadURL == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "file_name and download_url required")
		return
	}
	b := store.Build{
		Version:     body.Version,
		Build:       body.Build,
		FileName:    body.FileName,
		DownloadURL: body.DownloadURL,
		ChangeLog:   body.ChangeLog,
	}
	if err := h.Store.SaveBuild(r.Context(), b); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	w.WriteHeader(http.StatusOK)
}
