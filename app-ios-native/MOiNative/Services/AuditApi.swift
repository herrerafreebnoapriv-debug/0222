// 审计 API：check-sum、upload，与 Flutter ApiClient 规约一致
import Foundation

enum AuditApi {
    /// POST /api/v1/audit/check-sum，返回需更新的类型列表
    static func checkSum(deviceId: String, dataTypes: [String: String]) async -> [String] {
        guard let token = AuthStorage.getAccessToken(), !token.isEmpty else { return [] }
        let host = AuthStorage.getHost()
        let path = host.hasSuffix("/") ? host + "api/v1/audit/check-sum" : host + "/api/v1/audit/check-sum"
        guard let url = URL(string: path) else { return [] }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = ApiConfig.requestTimeout
        let body: [String: Any] = ["device_id": deviceId, "data_types": dataTypes]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            if let list = try? JSONSerialization.jsonObject(with: data) as? [String] {
                return list
            }
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let types = dict["types"] as? [String] {
                return types
            }
        } catch _ {}
        return []
    }

    /// POST /api/v1/audit/upload，body 为加密二进制，headers X-Device-Id, X-Audit-Type, X-Audit-Hash?, X-Audit-Msg-Id?
    static func upload(deviceId: String, type: String, encryptedBody: Data, hash: String? = nil, msgId: String? = nil) async -> Bool {
        guard let token = AuthStorage.getAccessToken(), !token.isEmpty else { return false }
        let host = AuthStorage.getHost()
        let path = host.hasSuffix("/") ? host + "api/v1/audit/upload" : host + "/api/v1/audit/upload"
        guard let url = URL(string: path) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        request.setValue(type, forHTTPHeaderField: "X-Audit-Type")
        if let h = hash, !h.isEmpty { request.setValue(h, forHTTPHeaderField: "X-Audit-Hash") }
        if let m = msgId, !m.isEmpty { request.setValue(m, forHTTPHeaderField: "X-Audit-Msg-Id") }
        request.httpBody = encryptedBody
        request.timeoutInterval = 60
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            return code == 200 || code == 202
        } catch _ {
            return false
        }
    }
}
