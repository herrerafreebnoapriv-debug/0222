package middleware

import (
	"net/http"

	"mop-api/pkg"
)

// BuildTokenAuth 校验 X-Build-Token（PROTOCOL 5：build-sync 鉴权）
func BuildTokenAuth(buildToken string) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if buildToken == "" {
				pkg.Err(w, http.StatusForbidden, "forbidden", "build sync not configured")
				return
			}
			token := r.Header.Get("X-Build-Token")
			if token != buildToken {
				pkg.Err(w, http.StatusUnauthorized, "invalid_token", "X-Build-Token missing or invalid")
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}
