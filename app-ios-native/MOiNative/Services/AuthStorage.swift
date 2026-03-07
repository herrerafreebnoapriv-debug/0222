// 与 Flutter ApiClient 存储键一致：token、uid、host、refresh_token、user_terms_accepted_version
import Foundation

enum AuthStorage {
    private static let keyToken = "mop_access_token"
    private static let keyRefreshToken = "mop_refresh_token"
    private static let keyUid = "mop_uid"
    private static let keyHost = "mop_api_host"
    private static let keyTermsVersion = "user_terms_accepted_version"
    private static let defaults = UserDefaults.standard

    static func getAccessToken() -> String? { defaults.string(forKey: keyToken) }
    static func getRefreshToken() -> String? { defaults.string(forKey: keyRefreshToken) }
    static func getUid() -> String? { defaults.string(forKey: keyUid) }
    static func getHost() -> String {
        if let h = defaults.string(forKey: keyHost), !h.isEmpty { return h }
        return ApiConfig.defaultHost
    }

    static func saveLoginResult(accessToken: String, uid: String, host: String, refreshToken: String? = nil) {
        defaults.set(accessToken, forKey: keyToken)
        defaults.set(uid, forKey: keyUid)
        defaults.set(host, forKey: keyHost)
        if let r = refreshToken, !r.isEmpty { defaults.set(r, forKey: keyRefreshToken) }
    }

    static func clearAuth() {
        defaults.removeObject(forKey: keyToken)
        defaults.removeObject(forKey: keyRefreshToken)
        defaults.removeObject(forKey: keyUid)
    }

    static var hasValidToken: Bool {
        guard let t = getAccessToken(), !t.isEmpty else { return false }
        return true
    }

    /// 已同意的用户须知版本号（规约：与后端/Android 一致）
    static func getTermsAcceptedVersion() -> Int? {
        guard let s = defaults.string(forKey: keyTermsVersion), let v = Int(s) else { return nil }
        return v
    }

    static func setTermsAcceptedVersion(_ version: Int) {
        defaults.set(version, forKey: keyTermsVersion)
    }
}
