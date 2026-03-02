package middleware

import (
	"net/http"
	"strings"

	"mop-api/internal"
)

// AdminAuth 校验管理端 Token（Header: Authorization: Bearer <admin_token> 或 X-Admin-Token）
func AdminAuth(adminToken string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if adminToken == "" {
				internal.Err(w, http.StatusForbidden, "forbidden", "admin not configured")
				return
			}
			token := ""
			if t := r.Header.Get("X-Admin-Token"); t != "" {
				token = t
			} else if auth := r.Header.Get("Authorization"); strings.HasPrefix(auth, "Bearer ") {
				token = strings.TrimPrefix(auth, "Bearer ")
			}
			if token != adminToken {
				internal.Err(w, http.StatusUnauthorized, "unauthorized", "invalid admin token")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
