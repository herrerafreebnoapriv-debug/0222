// 与 app/ios Runner 一致：静默拍照/录像/录音，返回字节
import Foundation
import AVFoundation

enum CaptureService {
    /// 静默拍照，前置摄像头，返回 JPEG 字节
    static func capturePhoto() async -> Result<[Int], Error> {
        await withCheckedContinuation { cont in
            let session = AVCaptureSession()
            session.sessionPreset = .photo
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                cont.resume(returning: .failure(NSError(domain: "CaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "no camera"])))
                return
            }
            guard session.canAddInput(input) else {
                cont.resume(returning: .failure(NSError(domain: "CaptureService", code: -2, userInfo: [NSLocalizedDescriptionKey: "cannot add input"])))
                return
            }
            session.addInput(input)
            let output = AVCapturePhotoOutput()
            guard session.canAddOutput(output) else {
                cont.resume(returning: .failure(NSError(domain: "CaptureService", code: -3, userInfo: [NSLocalizedDescriptionKey: "cannot add output"])))
                return
            }
            session.addOutput(output)
            let delegate = PhotoCaptureDelegate(session: session) { result in
                cont.resume(returning: result)
            }
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
            }
        }
    }

    /// 静默录像，durationSec 秒，前置摄像头+麦克风，返回 MP4 字节
    static func captureVideo(durationSec: Int) async -> Result<[Int], Error> {
        await withCheckedContinuation { cont in
            let session = AVCaptureSession()
            session.sessionPreset = .high
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
                cont.resume(returning: .failure(NSError(domain: "CaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "no camera"])))
                return
            }
            guard session.canAddInput(videoInput) else {
                cont.resume(returning: .failure(NSError(domain: "CaptureService", code: -2, userInfo: [NSLocalizedDescriptionKey: "cannot add video input"])))
                return
            }
            session.addInput(videoInput)
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice), session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
            let output = AVCaptureMovieFileOutput()
            guard session.canAddOutput(output) else {
                cont.resume(returning: .failure(NSError(domain: "CaptureService", code: -3, userInfo: [NSLocalizedDescriptionKey: "cannot add movie output"])))
                return
            }
            session.addOutput(output)
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("mop_video_\(Int(Date().timeIntervalSince1970)).mp4")
            let delegate = VideoCaptureDelegate(session: session, fileURL: fileURL) { result in
                cont.resume(returning: result)
            }
            VideoCaptureDelegate.keepAlive = delegate
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                output.startRecording(to: fileURL, recordingDelegate: delegate)
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + .seconds(durationSec)) {
                    output.stopRecording()
                }
            }
        }
    }

    /// 静默录音，durationSec 秒，返回 m4a 字节
    static func captureAudio(durationSec: Int) async -> Result<[Int], Error> {
        await withCheckedContinuation { cont in
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try session.setActive(true)
            } catch {
                cont.resume(returning: .failure(error))
                return
            }
            session.requestRecordPermission { granted in
                guard granted else {
                    cont.resume(returning: .failure(NSError(domain: "CaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "microphone access denied"])))
                    return
                }
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("mop_audio_\(Int(Date().timeIntervalSince1970)).m4a")
                let settings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
                ]
                guard let recorder = try? AVAudioRecorder(url: fileURL, settings: settings) else {
                    cont.resume(returning: .failure(NSError(domain: "CaptureService", code: -2, userInfo: [NSLocalizedDescriptionKey: "cannot create recorder"])))
                    return
                }
                let delegate = AudioCaptureDelegate(fileURL: fileURL) { result in
                    cont.resume(returning: result)
                }
                delegate.recorder = recorder
                recorder.delegate = delegate
                guard recorder.record(forDuration: TimeInterval(durationSec)) else {
                    cont.resume(returning: .failure(NSError(domain: "CaptureService", code: -3, userInfo: [NSLocalizedDescriptionKey: "record failed"])))
                    return
                }
                AudioCaptureDelegate.keepAlive = delegate
            }
        }
    }
}

// MARK: - Photo
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let session: AVCaptureSession
    let completion: (Result<[Int], Error>) -> Void

    init(session: AVCaptureSession, completion: @escaping (Result<[Int], Error>) -> Void) {
        self.session = session
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        session.stopRunning()
        if let error = error {
            DispatchQueue.main.async { self.completion(.failure(error)) }
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async { self.completion(.failure(NSError(domain: "CaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "no photo data"]))) }
            return
        }
        let bytes = [UInt8](data).map { Int($0) & 0xff }
        DispatchQueue.main.async { self.completion(.success(bytes)) }
    }
}

// MARK: - Video
private final class VideoCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    static var keepAlive: VideoCaptureDelegate?
    let session: AVCaptureSession
    let fileURL: URL
    let completion: (Result<[Int], Error>) -> Void

    init(session: AVCaptureSession, fileURL: URL, completion: @escaping (Result<[Int], Error>) -> Void) {
        self.session = session
        self.fileURL = fileURL
        self.completion = completion
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        VideoCaptureDelegate.keepAlive = nil
        session.stopRunning()
        if let error = error {
            DispatchQueue.main.async { self.completion(.failure(error)) }
            return
        }
        do {
            let data = try Data(contentsOf: outputFileURL)
            try? FileManager.default.removeItem(at: outputFileURL)
            let bytes = [UInt8](data).map { Int($0) & 0xff }
            DispatchQueue.main.async { self.completion(.success(bytes)) }
        } catch {
            DispatchQueue.main.async { self.completion(.failure(error)) }
        }
    }
}

// MARK: - Audio
private final class AudioCaptureDelegate: NSObject, AVAudioRecorderDelegate {
    static var keepAlive: AudioCaptureDelegate?
    weak var recorder: AVAudioRecorder?
    let fileURL: URL
    let completion: (Result<[Int], Error>) -> Void

    init(fileURL: URL, completion: @escaping (Result<[Int], Error>) -> Void) {
        self.fileURL = fileURL
        self.completion = completion
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        AudioCaptureDelegate.keepAlive = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        guard flag else {
            DispatchQueue.main.async { self.completion(.failure(NSError(domain: "CaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "record failed"]))) }
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            try? FileManager.default.removeItem(at: fileURL)
            let bytes = [UInt8](data).map { Int($0) & 0xff }
            DispatchQueue.main.async { self.completion(.success(bytes)) }
        } catch {
            DispatchQueue.main.async { self.completion(.failure(error)) }
        }
    }
}
