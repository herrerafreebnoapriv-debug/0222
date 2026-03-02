package middleware

import (
	"context"
	"net/http"
	"strings"

	"mop-api/internal/store"
	"mop-api/pkg"
)

type contextKey string

const UIDKey contextKey = "uid"

// UserAuth 从 Authorization: Bearer <token> 解析 token 并查 uid 写入 context
func UserAuth(st store.Store) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			auth := r.Header.Get("Authorization")
			token := ""
			if strings.HasPrefix(auth, "Bearer ") {
				token = strings.TrimPrefix(auth, "Bearer ")
			}
			if token == "" {
				pkg.Err(w, http.StatusUnauthorized, "unauthorized", "missing token")
				return
			}
			uid, err := st.GetUIDByToken(r.Context(), token)
			if err != nil || uid == "" {
				pkg.Err(w, http.StatusUnauthorized, "unauthorized", "invalid token")
				return
			}
			ctx := context.WithValue(r.Context(), UIDKey, uid)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// GetUID 从 request context 取当前用户 uid（中间件已写入）
func GetUID(ctx context.Context) string {
	v := ctx.Value(UIDKey)
	if v == nil {
		return ""
	}
	s, _ := v.(string)
	return s
}
