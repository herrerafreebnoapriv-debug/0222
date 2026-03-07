// 跳转系统拨号/短信界面（与 app/ios Runner 一致）
import Foundation
import UIKit

enum SystemUIService {
    /// 跳转到系统拨号界面（Phone 应用），不在 App 内弹窗
    static func openDialer(number: String) {
        let n = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        let allowed = CharacterSet(charactersIn: "0123456789+*#,").union(.whitespaces)
        let encoded = n.addingPercentEncoding(withAllowedCharacters: allowed) ?? n
        guard let url = URL(string: "tel:\(encoded)") else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }

    /// 跳转到系统短信界面
    static func openSms(number: String, content: String? = nil) {
        let n = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        let body = content?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = body.isEmpty ? "smsto:\(n)" : "sms:\(n)&body=\(body)"
        guard let url = URL(string: urlStr) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }
}
