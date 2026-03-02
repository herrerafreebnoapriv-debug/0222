package pkg

import (
	"encoding/json"
	"net/http"
)

// JSON 写入 JSON 并设置 Content-Type
func JSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// ErrBody 规约第 7 节：统一错误响应 code + message
type ErrBody struct {
	Code    string `json:"code"`
	Message string `json:"message,omitempty"`
}

// Err 写入统一错误响应
func Err(w http.ResponseWriter, status int, code, message string) {
	JSON(w, status, ErrBody{Code: code, Message: message})
}
