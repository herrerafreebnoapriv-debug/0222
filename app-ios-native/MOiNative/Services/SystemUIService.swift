// 与 app/ios Runner 一致：拨号、短信
import Foundation
import UIKit

enum SystemUIService {
    static func openDialer(number: String) {
        let n = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let encoded = n.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "tel:\(encoded)") else { return }
        UIApplication.shared.open(url)
    }

    static func openSms(number: String, content: String? = nil) {
        let n = number.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        let body = content?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = body.isEmpty ? "smsto:\(n)" : "sms:\(n)&body=\(body)"
        guard let url = URL(string: urlStr) else { return }
        UIApplication.shared.open(url)
    }
}
