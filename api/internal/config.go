package internal

import (
	"fmt"
	"os"
)

// Config 运行配置
type Config struct {
	Port         string // 监听端口，默认 80
	DBPath       string // SQLite 路径，默认 ./mop.db
	APIHost      string // 对外 API Host（如 api.sdkdns.top），用于 invite_url
	WebHost     string // 用户端网页域名，用于 invite_url，默认 https://web.sdkdns.top
	TermsVersion   int    // 当前用户须知版本号，用于 GET /api/v1/config
	AdminToken     string // 管理端鉴权 Token（Bearer 或 X-Admin-Token）
	AdminUsername  string // 管理端登录用户名（可选；与 AdminPassword 同时设置时校验）
	AdminPassword  string // 管理端登录密码（可选）
	BuildToken     string // build-sync 鉴权（X-Build-Token），不设则拒绝 POST /api/v1/internal/build-sync
}

func LoadConfig() Config {
	c := Config{
		Port:         "80",
		DBPath:       "./mop.db",
		APIHost:      "https://api.sdkdns.top",
		WebHost:      "https://web.sdkdns.top",
		TermsVersion:  1,
		AdminToken:    "",
		AdminUsername: "",
		AdminPassword: "",
		BuildToken:    "",
	}
	if p := os.Getenv("PORT"); p != "" {
		c.Port = p
	}
	if d := os.Getenv("DB_PATH"); d != "" {
		c.DBPath = d
	}
	if h := os.Getenv("API_HOST"); h != "" {
		c.APIHost = h
	}
	if h := os.Getenv("WEB_HOST"); h != "" {
		c.WebHost = h
	}
	if t := os.Getenv("ADMIN_TOKEN"); t != "" {
		c.AdminToken = t
	}
	if u := os.Getenv("ADMIN_USERNAME"); u != "" {
		c.AdminUsername = u
	}
	if p := os.Getenv("ADMIN_PASSWORD"); p != "" {
		c.AdminPassword = p
	}
	if t := os.Getenv("BUILD_TOKEN"); t != "" {
		c.BuildToken = t
	}
	if v := os.Getenv("TERMS_VERSION"); v != "" {
		var n int
		if _, err := fmt.Sscanf(v, "%d", &n); err == nil {
			c.TermsVersion = n
		}
	}
	return c
}
