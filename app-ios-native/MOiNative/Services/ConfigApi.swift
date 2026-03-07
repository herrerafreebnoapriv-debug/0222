// GET /api/v1/config：当前须知版本等（与 Flutter ApiClient.getCurrentTermsVersion 规约一致）
import Foundation

struct ConfigResponse: Decodable {
    let terms_version: Int?
}

enum ConfigApi {
    /// 当前须知版本号；失败或未配置时返回 1
    static func getCurrentTermsVersion() async -> Int {
        let host = AuthStorage.getHost()
        let path = host.hasSuffix("/") ? host + "api/v1/config" : host + "/api/v1/config"
        guard let url = URL(string: path),
              let token = AuthStorage.getAccessToken(), !token.isEmpty else {
            return 1
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = ApiConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            if http?.statusCode == 200, let decoded = try? JSONDecoder().decode(ConfigResponse.self, from: data), let v = decoded.terms_version {
                return v
            }
        } catch {}
        return 1
    }
}
