// 与 app/ios Runner 相册能力一致：摘要、原图、擦除、保存二维码
import Foundation
import UIKit
import Photos

enum GalleryService {
    /// 相册/媒体摘要，供审计 Hash；["items": [[id, date_added, kind], ...]]
    static func fetchGalleryManifest() -> [String: Any] {
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

    /// 按 localIdentifier 取原图 Data；仅图片，视频返回 nil
    static func getGalleryOriginalBytes(localIdentifier: String) async -> Data? {
        await withCheckedContinuation { cont in
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            guard let asset = assets.firstObject, asset.mediaType == .image else {
                cont.resume(returning: nil)
                return
            }
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                cont.resume(returning: data)
            }
        }
    }

    /// 清理最近 days 天内的相册照片与视频；需 .readWrite
    static func clearGalleryWithinDays(days: Int) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let cutoff = Date(timeIntervalSinceNow: -Double(days) * 86400)
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "creationDate >= %@", cutoff as NSDate)
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                guard status == .authorized || status == .limited else {
                    cont.resume()
                    return
                }
                let images = PHAsset.fetchAssets(with: .image, options: options)
                let videos = PHAsset.fetchAssets(with: .video, options: options)
                var toDelete: [PHAsset] = []
                images.enumerateObjects { asset, _, _ in toDelete.append(asset) }
                videos.enumerateObjects { asset, _, _ in toDelete.append(asset) }
                if toDelete.isEmpty {
                    cont.resume()
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(toDelete as NSArray)
                }) { _, _ in
                    cont.resume()
                }
            }
        }
    }

    /// 保存图片 Data 到系统相册（如二维码）；需 .addOnly
    static func saveQrToGallery(imageData: Data) async throws {
        guard let image = UIImage(data: imageData), !imageData.isEmpty else {
            throw NSError(domain: "GalleryService", code: -1, userInfo: [NSLocalizedDescriptionKey: "invalid image data"])
        }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                guard status == .authorized || status == .limited else {
                    cont.resume(throwing: NSError(domain: "GalleryService", code: -2, userInfo: [NSLocalizedDescriptionKey: "photo library access denied"]))
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    if success {
                        cont.resume()
                    } else {
                        cont.resume(throwing: error ?? NSError(domain: "GalleryService", code: -3, userInfo: [NSLocalizedDescriptionKey: "save failed"]))
                    }
                }
            }
        }
    }
}
