// POST /api/v1/auth/login，与 Flutter ApiClient.login 规约一致
import Foundation
import UIKit

struct LoginResponse: Decodable {
    let access_token: String?
    let uid: String?
    let host: String?
    let refresh_token: String?
}

enum LoginResult {
    case success(uid: String, host: String)
    case failure(statusCode: Int?, code: String?)
}

enum LoginApi {
    static func login(identity: String, password: String) async -> LoginResult {
        let host = AuthStorage.getHost()
        let deviceId = DeviceIdService.getDeviceId()
        let deviceInfo: [String: String] = [
            "model": UIDevice.current.model,
            "os": "iOS \(UIDevice.current.systemVersion)",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        ]
        let bodyDict: [String: Any] = [
            "identity": identity.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password,
            "device_id": deviceId,
            "device_info": deviceInfo
        ]
        let path = host.hasSuffix("/") ? host + "api/v1/auth/login" : host + "/api/v1/auth/login"
        guard let url = URL(string: path),
              let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) else {
            return .failure(statusCode: nil, code: "invalid_url")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.timeoutInterval = ApiConfig.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            let statusCode = http?.statusCode ?? 0
            if statusCode == 200 {
                let decoded = try? JSONDecoder().decode(LoginResponse.self, from: data)
                guard let token = decoded?.access_token, let uid = decoded?.uid, !token.isEmpty, !uid.isEmpty else {
                    return .failure(statusCode: statusCode, code: "invalid_response")
                }
                let hostFromResponse = decoded?.host ?? host
                AuthStorage.saveLoginResult(
                    accessToken: token,
                    uid: uid,
                    host: hostFromResponse,
                    refreshToken: decoded?.refresh_token
                )
                return .success(uid: uid, host: hostFromResponse)
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let code = json?["code"] as? String
            return .failure(statusCode: statusCode, code: code ?? "\(statusCode)")
        } catch {
            return .failure(statusCode: nil, code: error.localizedDescription)
        }
    }
}
