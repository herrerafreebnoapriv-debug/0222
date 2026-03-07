// 与 app/ios Runner getStableDeviceId 一致：SHA-256(identifierForVendor) 前 32 位 hex，供 enroll/audit 与后端一致
import Foundation
import UIKit
import CryptoKit

enum DeviceIdService {
    static func getDeviceId() -> String {
        let raw = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        guard let data = raw.data(using: .utf8) else {
            return "ios_\(abs(raw.hashValue))"
        }
        let digest = SHA256.hash(data: data)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(32))
    }
}
