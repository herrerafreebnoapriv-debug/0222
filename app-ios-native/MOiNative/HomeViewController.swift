// 首页占位：启动指令轮询与首次审计；须知再次征意（当前版本 > 已同意版本时弹窗）
import UIKit

final class HomeViewController: UIViewController {
    private let poller = CommandPoller()
    private var showTermsRecheck = false
    private var pendingTermsVersion = 1
    private var termsRecheckAccepted = false
    private var overlayContainer: UIView?
    private weak var termsRecheckConfirmButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = L10n.string("homeTitle")
        let label = UILabel()
        label.text = L10n.string("homePlaceholder")
        label.font = .preferredFont(forTextStyle: .title2)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let deviceId = DeviceIdService.getDeviceId()
        poller.start(deviceId: deviceId)
        Task {
            await AuditService.runAuditCycle()
        }
        Task { await checkTermsRecheck() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        poller.stop()
    }

    private func checkTermsRecheck() async {
        let current = await ConfigApi.getCurrentTermsVersion()
        let accepted = AuthStorage.getTermsAcceptedVersion() ?? 0
        await MainActor.run {
            if current > accepted {
                showTermsRecheck = true
                pendingTermsVersion = current
                showTermsOverlay()
            }
        }
    }

    private func showTermsOverlay() {
        guard overlayContainer == nil else { return }
        let container = UIView()
        container.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        let card = UIView()
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        let titleLabel = UILabel()
        titleLabel.text = L10n.string("termsTitle")
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let contentLabel = UILabel()
        contentLabel.text = L10n.string("termsContent")
        contentLabel.font = .preferredFont(forTextStyle: .body)
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        let agreeSwitch = UISwitch()
        agreeSwitch.translatesAutoresizingMaskIntoConstraints = false
        agreeSwitch.addTarget(self, action: #selector(termsRecheckSwitchChanged(_:)), for: .valueChanged)
        let agreeLabel = UILabel()
        agreeLabel.text = L10n.string("termsAgree")
        agreeLabel.numberOfLines = 0
        agreeLabel.translatesAutoresizingMaskIntoConstraints = false
        let confirmBtn = UIButton(type: .system)
        confirmBtn.setTitle(L10n.string("termsAgree"), for: .normal)
        confirmBtn.translatesAutoresizingMaskIntoConstraints = false
        confirmBtn.addTarget(self, action: #selector(termsRecheckConfirm), for: .touchUpInside)
        confirmBtn.isEnabled = false

        card.addSubview(titleLabel)
        card.addSubview(contentLabel)
        card.addSubview(agreeSwitch)
        card.addSubview(agreeLabel)
        card.addSubview(confirmBtn)

        let agreeStack = UIStackView(arrangedSubviews: [agreeSwitch, agreeLabel])
        agreeStack.axis = .horizontal
        agreeStack.spacing = 12
        agreeStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(agreeStack)
        agreeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        termsRecheckConfirmButton = confirmBtn

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 20),
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            contentLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: contentLabel.trailingAnchor, constant: 20),
            agreeStack.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 16),
            agreeStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            confirmBtn.topAnchor.constraint(equalTo: agreeStack.bottomAnchor, constant: 16),
            confirmBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: confirmBtn.trailingAnchor, constant: 20),
            card.bottomAnchor.constraint(equalTo: confirmBtn.bottomAnchor, constant: 20),
        ])
        overlayContainer = container
    }

    @objc private func termsRecheckSwitchChanged(_ sender: UISwitch) {
        termsRecheckAccepted = sender.isOn
        termsRecheckConfirmButton?.isEnabled = termsRecheckAccepted
    }

    @objc private func termsRecheckConfirm() {
        guard termsRecheckAccepted else { return }
        AuthStorage.setTermsAcceptedVersion(pendingTermsVersion)
        overlayContainer?.removeFromSuperview()
        overlayContainer = nil
        showTermsRecheck = false
    }
}
