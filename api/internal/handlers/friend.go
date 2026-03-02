package handlers

import (
	"encoding/json"
	"net/http"

	"mop-api/internal"
	"mop-api/internal/middleware"
)

// FriendRequest POST /api/v1/friend/request
func (h *Handler) FriendRequest(w http.ResponseWriter, r *http.Request) {
	fromUID := middleware.GetUID(r.Context())
	if fromUID == "" {
		internal.Err(w, http.StatusUnauthorized, "unauthorized", "")
		return
	}
	var body struct {
		TargetUID string `json:"target_uid"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.TargetUID == "" {
		internal.Err(w, http.StatusBadRequest, "bad_request", "")
		return
	}
	if body.TargetUID == fromUID {
		internal.Err(w, http.StatusBadRequest, "bad_request", "cannot add self")
		return
	}
	ok, _ := h.Store.IsFriend(r.Context(), fromUID, body.TargetUID)
	if ok {
		internal.JSON(w, http.StatusOK, map[string]string{"status": "already_friend"})
		return
	}
	if err := h.Store.AddFriend(r.Context(), fromUID, body.TargetUID); err != nil {
		internal.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	w.WriteHeader(http.StatusOK)
}
