// 凭证页：展示 mop 二维码、保存到相册、进入主界面（多语言）
import UIKit

final class CredentialViewController: UIViewController {
    private let imageView = UIImageView()
    private let saveButton = UIButton(type: .system)
    private let enterButton = UIButton(type: .system)
    private var payload: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = L10n.string("credentialTitle")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle(L10n.string("credentialSave"), for: .normal)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveToGallery), for: .touchUpInside)
        enterButton.setTitle(L10n.string("credentialEnterMain"), for: .normal)
        enterButton.translatesAutoresizingMaskIntoConstraints = false
        enterButton.addTarget(self, action: #selector(enterMain), for: .touchUpInside)
        view.addSubview(imageView)
        view.addSubview(saveButton)
        view.addSubview(enterButton)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            imageView.widthAnchor.constraint(equalToConstant: 220),
            imageView.heightAnchor.constraint(equalToConstant: 220),
            saveButton.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 24),
            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            enterButton.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 16),
            enterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        loadQR()
    }

    private func loadQR() {
        guard let uid = AuthStorage.getUid(), let token = AuthStorage.getAccessToken(), !token.isEmpty else { return }
        let host = AuthStorage.getHost()
        payload = CredentialHelper.encodeMopPayload(host: host, uid: uid, token: token)
        guard let p = payload, let img = CredentialHelper.qrImage(payload: p, size: 220) else { return }
        imageView.image = img
    }

    @objc private func saveToGallery() {
        guard let p = payload, let data = CredentialHelper.qrImageData(payload: p) else { return }
        Task {
            do {
                try await GalleryService.saveQrToGallery(imageData: data)
                await MainActor.run {
                    let alert = UIAlertController(title: nil, message: L10n.string("savedToGallery"), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: L10n.string("confirm"), style: .default))
                    present(alert, animated: true)
                }
            } catch {
                await MainActor.run {
                    let alert = UIAlertController(title: L10n.string("saveFailed"), message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: L10n.string("confirm"), style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }

    @objc private func enterMain() {
        guard let window = view.window else { return }
        let tab = MainTabController()
        window.rootViewController = tab
    }
}
