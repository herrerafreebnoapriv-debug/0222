package handlers

import (
	"net/http"
	"os"
	"path/filepath"

	"mop-api/internal"
	"mop-api/internal/middleware"
)

// UploadAvatar POST /api/v1/user/avatar multipart form "avatar"
func (h *Handler) UploadAvatar(w http.ResponseWriter, r *http.Request) {
	uid := middleware.GetUID(r.Context())
	if uid == "" {
		internal.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	file, _, err := r.FormFile("avatar")
	if err != nil {
		internal.Err(w, http.StatusBadRequest, "bad_request", "avatar file required")
		return
	}
	defer file.Close()
	// 简单落盘：./uploads/avatars/<uid>.jpg
	uploadDir := "uploads/avatars"
	_ = os.MkdirAll(uploadDir, 0755)
	ext := ".jpg"
	path := filepath.Join(uploadDir, uid+ext)
	f, err := os.Create(path)
	if err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	_, err = f.ReadFrom(file)
	f.Close()
	if err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	// 存相对路径或 URL；客户端用 host + path 拼接
	relativePath := path
	if err := h.Store.SetUserAvatarPath(r.Context(), uid, relativePath); err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	internal.JSON(w, http.StatusOK, map[string]string{"avatar_url": relativePath})
}
