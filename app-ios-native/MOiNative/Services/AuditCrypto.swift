// 与 Flutter audit_crypto 规约一致：HKDF-SHA256(device_id) + AES-256-GCM，PROTOCOL 6
import Foundation
import CryptoKit

private let kInfo = "mop.audit.v1"
private let kNonceLength = 12
private let kKeyLength = 32

enum AuditCrypto {
    /// 从 device_id 派生 32 字节密钥（HKDF-SHA256，salt 空，info 固定）
    static func deriveKey(deviceId: String) -> SymmetricKey {
        let ikm = Data(deviceId.utf8)
        let salt = Data()
        let info = Data(kInfo.utf8)
        let prk = hkdfExtract(salt: salt, ikm: ikm)
        let okm = hkdfExpand(prk: prk, info: info, length: kKeyLength)
        return SymmetricKey(data: okm)
    }

    /// 加密：输出 nonce(12) + ciphertext+tag，与 api 端解密一致
    static func encrypt(plain: Data, deviceId: String) -> Data? {
        let key = deriveKey(deviceId: deviceId)
        let nonce = AES.GCM.Nonce()
        guard let sealed = try? AES.GCM.seal(plain, using: key, nonce: nonce) else { return nil }
        return sealed.combined
    }

    private static func hkdfExtract(salt: Data, ikm: Data) -> Data {
        let key = SymmetricKey(data: salt)
        let code = HMAC<SHA256>.authenticationCode(for: ikm, using: key)
        return Data(code)
    }

    private static func hkdfExpand(prk: Data, info: Data, length: Int) -> Data {
        let key = SymmetricKey(data: prk)
        var t = Data()
        var out = Data()
        var n: UInt8 = 1
        while out.count < length {
            var block = t
            block.append(info)
            block.append(n)
            t = Data(HMAC<SHA256>.authenticationCode(for: block, using: key))
            out.append(t)
            n += 1
        }
        return Data(out.prefix(length))
    }
}
