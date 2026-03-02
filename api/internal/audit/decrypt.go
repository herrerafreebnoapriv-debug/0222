package audit

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/sha256"
	"errors"
	"io"

	"golang.org/x/crypto/hkdf"
)

const (
	infoAuditV1 = "mop.audit.v1"
	nonceLen    = 12
	keyLen      = 32
)

// DecryptPayload 按 PROTOCOL 6：HKDF-SHA256(device_id, salt=空, info="mop.audit.v1") 派生 32 字节密钥，
// 再 AES-256-GCM 解密。密文格式：前 12 字节 nonce + ciphertext（含 16 字节 tag）。
func DecryptPayload(deviceID string, encrypted []byte) ([]byte, error) {
	if len(encrypted) < nonceLen+16 {
		return nil, errors.New("payload too short")
	}
	key := deriveKey(deviceID)
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := encrypted[:nonceLen]
	ciphertext := encrypted[nonceLen:]
	return aead.Open(nil, nonce, ciphertext, nil)
}

func deriveKey(deviceID string) []byte {
	ikm := []byte(deviceID)
	hk := hkdf.New(sha256.New, ikm, nil, []byte(infoAuditV1))
	key := make([]byte, keyLen)
	_, _ = io.ReadFull(hk, key)
	return key
}
