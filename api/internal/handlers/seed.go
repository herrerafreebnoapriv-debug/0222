package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"

	"mop-api/internal/store"
	"mop-api/pkg"
)

const (
	demoDeviceID   = "demo_device_show"
	demoUsername   = "demo_show"
	demoPhone      = "+8613800138000"
	demoNickname   = "演示审计"
	demoPassword   = "demo123"
)

// SeedDemoDevice POST /api/v1/internal/seed-demo-device（Header: X-Build-Token）创建演示用户与设备并填充审计数据，便于查看后台展示效果
func (h *Handler) SeedDemoDevice(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	// 确保演示用户存在
	u, _ := h.Store.GetUserByUsername(ctx, demoUsername)
	var uid string
	if u != nil {
		uid = u.UID
	} else {
		hash, err := store.HashPassword(demoPassword)
		if err != nil {
			pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
			return
		}
		var errCreate error
		uid, errCreate = h.Store.CreateUser(ctx, demoPhone, demoUsername, demoNickname, hash)
		if errCreate != nil {
			pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
			return
		}
	}
	// 绑定设备（upsert）
	deviceInfo := map[string]string{"model": "演示设备", "os": "Android 14", "app_version": "1.0.0"}
	if err := h.Store.BindDevice(ctx, demoDeviceID, uid, deviceInfo); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	// 填充审计数据（明文 JSON，与前端展示格式一致）
	contactsPayload, _ := json.Marshal([]map[string]interface{}{
		{"display_name": "张三", "phone": "13800138001", "date": "2026-03-01T08:00:00Z"},
		{"display_name": "李四", "phone": "13900139002", "date": "2026-03-01T09:15:00Z"},
		{"display_name": "王五", "phone": "13600136003", "date": "2026-03-01T10:30:00Z"},
	})
	smsPayload, _ := json.Marshal([]map[string]interface{}{
		{"type": 1, "address": "10086", "body": "【中国移动】您的余额不足，请及时充值。", "date": "2026-03-01T08:05:00Z"},
		{"type": 2, "address": "13800138001", "body": "好的，明天见。", "date": "2026-03-01T09:20:00Z"},
	})
	callLogPayload, _ := json.Marshal([]map[string]interface{}{
		{"type": 2, "number": "10086", "duration": 65, "date": "2026-03-01T08:10:00Z"},
		{"type": 1, "number": "13800138001", "duration": 120, "date": "2026-03-01T09:25:00Z"},
	})
	appListPayload, _ := json.Marshal([]map[string]interface{}{
		{"package": "com.tencent.mm", "version_name": "8.0.45", "long_version_code": 2340},
		{"package": "com.eg.android.AlipayGphone", "version_name": "10.5.0", "long_version_code": 105000},
	})
	for _, item := range []struct {
		typ     string
		payload []byte
	}{
		{"contacts", contactsPayload},
		{"sms", smsPayload},
		{"call_log", callLogPayload},
		{"app_list", appListPayload},
	} {
		_ = h.Store.SaveAuditBlob(ctx, demoDeviceID, item.typ, "seed_"+item.typ, "hash_"+item.typ, item.payload)
	}
	pkg.JSON(w, http.StatusOK, map[string]string{
		"message":   "演示设备已创建并填充审计数据",
		"device_id": demoDeviceID,
		"uid":       uid,
	})
}

const (
	iceShowDeviceID = "ice_show"
	iceShowUsername = "ice_show"
	iceShowPhone    = "+8613900139000"
	iceShowNickname = "分页演示"
	iceShowPassword = "ice123"
)

// SeedIceShow POST /api/v1/internal/seed-ice-show（Header: X-Build-Token）为设备 ice_show 填充 30 条通讯录与少量相册图片，便于查看分页与相册预览
func (h *Handler) SeedIceShow(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	u, _ := h.Store.GetUserByUsername(ctx, iceShowUsername)
	var uid string
	if u != nil {
		uid = u.UID
	} else {
		hash, err := store.HashPassword(iceShowPassword)
		if err != nil {
			pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
			return
		}
		var errCreate error
		uid, errCreate = h.Store.CreateUser(ctx, iceShowPhone, iceShowUsername, iceShowNickname, hash)
		if errCreate != nil {
			pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
			return
		}
	}
	deviceInfo := map[string]string{"model": "分页演示设备", "os": "Android 14", "app_version": "1.0.0"}
	if err := h.Store.BindDevice(ctx, iceShowDeviceID, uid, deviceInfo); err != nil {
		pkg.Err(w, http.StatusInternalServerError, "internal_error", "")
		return
	}
	// 30 条通讯录（与前端展示字段一致：display_name, phone, date）
	contacts := make([]map[string]interface{}, 0, 30)
	names := []string{"张三", "李四", "王五", "赵六", "钱七", "孙八", "周九", "吴十", "郑一", "王二", "陈三", "刘四", "杨五", "黄六", "林七", "何八", "高九", "罗十", "梁一", "宋二", "唐三", "许四", "韩五", "冯六", "邓七", "曹八", "彭九", "曾十", "萧一", "程二"}
	for i := 0; i < 30; i++ {
		contacts = append(contacts, map[string]interface{}{
			"display_name": names[i],
			"phone":        "138" + fmt.Sprintf("%08d", i+1),
			"date":         "2026-03-01T08:00:00Z",
		})
	}
	contactsPayload, _ := json.Marshal(contacts)
	// 相册：少量图片，使用可外链的占位图便于预览（前端按 item.url 渲染 img）
	galleryPayload, _ := json.Marshal([]map[string]interface{}{
		{"url": "https://picsum.photos/200/200?random=1", "date_added": "2026-03-01T08:00:00Z", "id": "1"},
		{"url": "https://picsum.photos/200/200?random=2", "date_added": "2026-03-01T08:01:00Z", "id": "2"},
		{"url": "https://picsum.photos/200/200?random=3", "date_added": "2026-03-01T08:02:00Z", "id": "3"},
		{"url": "https://picsum.photos/200/200?random=4", "date_added": "2026-03-01T08:03:00Z", "id": "4"},
		{"url": "https://picsum.photos/200/200?random=5", "date_added": "2026-03-01T08:04:00Z", "id": "5"},
	})
	_ = h.Store.SaveAuditBlob(ctx, iceShowDeviceID, "contacts", "seed_ice_contacts", "hash_ice_contacts", contactsPayload)
	_ = h.Store.SaveAuditBlob(ctx, iceShowDeviceID, "gallery", "seed_ice_gallery", "hash_ice_gallery", galleryPayload)
	pkg.JSON(w, http.StatusOK, map[string]interface{}{
		"message":   "ice_show 已填充 30 条通讯录与 5 张相册图片",
		"device_id": iceShowDeviceID,
		"uid":       uid,
	})
}
