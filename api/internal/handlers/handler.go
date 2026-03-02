package handlers

import (
	"mop-api/internal/store"
	"mop-api/pkg"
)

// Handler 持有 Store 与 Cfg（运行配置），供各子 handler 使用；方法名 Config 用于 GET /api/v1/config 路由
type Handler struct {
	Store store.Store
	Cfg   pkg.Config
}
