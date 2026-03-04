package pkg

import (
	"net"
	"net/http"
	"strings"
)

// ClientIP 从请求中取客户端 IP：优先 X-Forwarded-For 首段、X-Real-IP，否则 RemoteAddr（去掉端口）
func ClientIP(r *http.Request) string {
	if r == nil {
		return ""
	}
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		if i := strings.Index(xff, ","); i > 0 {
			xff = strings.TrimSpace(xff[:i])
		} else {
			xff = strings.TrimSpace(xff)
		}
		if xff != "" {
			return xff
		}
	}
	if xri := strings.TrimSpace(r.Header.Get("X-Real-IP")); xri != "" {
		return xri
	}
	addr := r.RemoteAddr
	if addr == "" {
		return ""
	}
	if host, _, err := net.SplitHostPort(addr); err == nil {
		return host
	}
	return addr
}
