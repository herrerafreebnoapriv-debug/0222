// GET /api/v1/device/commands?device_id=xxx，返回待执行指令列表
import Foundation

struct CommandItem {
    let msgId: String
    let cmd: String
    let params: [String: Any]
}

enum CommandsApi {
    static func fetchPending(deviceId: String) async -> [CommandItem] {
        guard let token = AuthStorage.getAccessToken(), !token.isEmpty else { return [] }
        var host = AuthStorage.getHost()
        if !host.hasSuffix("/") { host += "/" }
        guard var comp = URLComponents(string: host + "api/v1/device/commands") else { return [] }
        comp.queryItems = [URLQueryItem(name: "device_id", value: deviceId)]
        guard let url = comp.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = ApiConfig.requestTimeout
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else { return [] }
            return items.compactMap { item in
                guard let cmd = item["cmd"] as? String else { return nil }
                let msgId = (item["msg_id"] as? String) ?? (item["msg_id"] as? Int).map { "\($0)" } ?? ""
                let params = (item["params"] as? [String: Any]) ?? [:]
                return CommandItem(msgId: msgId, cmd: cmd, params: params)
            }
        } catch _ {}
        return []
    }
}
