package middleware

import (
	"net/http"

	"mop-api/internal"
)

// BuildTokenAuth 校验 X-Build-Token（PROTOCOL 5：build-sync 鉴权）
func BuildTokenAuth(buildToken string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if buildToken == "" {
				internal.Err(w, http.StatusForbidden, "forbidden", "build sync not configured")
				return
			}
			token := r.Header.Get("X-Build-Token")
			if token != buildToken {
				internal.Err(w, http.StatusUnauthorized, "invalid_token", "X-Build-Token missing or invalid")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
