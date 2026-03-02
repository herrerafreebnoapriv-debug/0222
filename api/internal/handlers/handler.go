package handlers

import (
	"mop-api/internal"
	"mop-api/internal/store"
)

// Handler 持有 Store 与 Config，供各子 handler 使用
type Handler struct {
	Store  store.Store
	Config internal.Config
}
