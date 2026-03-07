// 凭证二维码：mop://base64(host|uid|token|timestamp)，与 Flutter CredentialScreen 一致
import Foundation
import UIKit
import CoreImage

enum CredentialHelper {
    static func encodeMopPayload(host: String, uid: String, token: String) -> String {
        let t = Int(Date().timeIntervalSince1970)
        let plain = "\(host)|\(uid)|\(token)|\(t)"
        let data = Data(plain.utf8)
        let base64 = data.base64EncodedString()
        return "mop://\(base64)"
    }

    /// 生成 QR 码图片，size 为边长（点）
    static func qrImage(payload: String, size: CGFloat = 512) -> UIImage? {
        let data = Data(payload.utf8)
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scale = size / ciImage.extent.width
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// 将 QR 图转为 PNG Data 供保存相册
    static func qrImageData(payload: String, size: CGFloat = 512) -> Data? {
        guard let img = qrImage(payload: payload, size: size) else { return nil }
        return img.pngData()
    }
}
