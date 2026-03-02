package handlers

import (
	"encoding/json"
	"net/http"

	"mop-api/internal/middleware"
	"mop-api/pkg"
)

// FriendRequest POST /api/v1/friend/request
func (h *Handler) FriendRequest(w http.ResponseWriter, r *http.Request) {
	fromUID := middleware.GetUID(r.Context())
	if fromUID == "" {
		pkg.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	var body struct {
		TargetUID string `json:"target_uid"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.TargetUID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	if body.TargetUID == fromUID {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "cannot add self")
		return
	}
	ok, _ := h.Store.IsFriend(r.Context(), fromUID, body.TargetUID)
	if ok {
		pkg.JSON(w, http.StatusOK, map[string]string{"status": "already_friend"})
		return
	}
	if err := h.Store.AddFriend(r.Context(), fromUID, body.TargetUID); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	w.WriteHeader(http.StatusOK)
}
