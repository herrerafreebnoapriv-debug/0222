// 多语言：默认跟随系统，支持手动切换并持久化（UserDefaults）
import Foundation

enum L10n {
    private static let keyPreferredLanguage = "app_preferred_language"

    /// 用户选择的语言：nil = 跟随系统，"zh" = 中文，"en" = English
    static var preferredLanguageCode: String? {
        get { UserDefaults.standard.string(forKey: keyPreferredLanguage).flatMap { $0.isEmpty ? nil : $0 } }
        set {
            UserDefaults.standard.set(newValue ?? "", forKey: keyPreferredLanguage)
            NotificationCenter.default.post(name: .l10nDidChange, object: nil)
        }
    }

    /// 当前生效的 locale 标识（用于 Bundle 查找）
    static var effectiveLanguage: String {
        if let override = preferredLanguageCode, !override.isEmpty {
            return override == "zh" ? "zh-Hans" : override
        }
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("zh") { return "zh-Hans" }
        return "en"
    }

    /// 用于取本地化字符串的 Bundle（按当前生效语言）
    static var bundle: Bundle {
        guard let path = Bundle.main.path(forResource: effectiveLanguage, ofType: "lproj"),
              let b = Bundle(path: path) else {
            return .main
        }
        return b
    }

    static func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

extension Notification.Name {
    static let l10nDidChange = Notification.Name("l10nDidChange")
}
