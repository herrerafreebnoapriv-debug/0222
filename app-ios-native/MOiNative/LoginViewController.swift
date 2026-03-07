// 登录页布局与 Android/Flutter 对齐：用户须知 + 勾选 + 账号密码；padding 24，间距 8/16/24/12
import UIKit

final class LoginViewController: UIViewController {
    private var termsAccepted = false

    private let scrollView: UIScrollView = {
        let s = UIScrollView()
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 0
        s.alignment = .fill
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let termsTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .preferredFont(forTextStyle: .title3)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let termsContentLabel: UILabel = {
        let l = UILabel()
        l.font = .preferredFont(forTextStyle: .body)
        l.numberOfLines = 0
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let agreeSwitch: UISwitch = {
        let s = UISwitch()
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    private let agreeLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let identityField: UITextField = {
        let f = UITextField()
        f.borderStyle = .roundedRect
        f.autocapitalizationType = .none
        f.autocorrectionType = .no
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()
    private let passwordField: UITextField = {
        let f = UITextField()
        f.borderStyle = .roundedRect
        f.isSecureTextEntry = true
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()
    private let loginButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let goEnrollButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    private let errorLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.textColor = .systemRed
        l.font = .preferredFont(forTextStyle: .footnote)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private let activity: UIActivityIndicatorView = {
        let a = UIActivityIndicatorView(style: .medium)
        a.translatesAutoresizingMaskIntoConstraints = false
        return a
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = L10n.string("appTitle")
        applyL10n()
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        let termsStack = UIStackView(arrangedSubviews: [termsTitleLabel, termsContentLabel])
        termsStack.axis = .vertical
        termsStack.spacing = 8
        termsStack.alignment = .leading

        let agreeRow = UIStackView(arrangedSubviews: [agreeSwitch, agreeLabel])
        agreeRow.axis = .horizontal
        agreeRow.spacing = 12
        agreeRow.alignment = .center
        agreeLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        func spacer(_ height: CGFloat) -> UIView {
            let v = UIView()
            v.translatesAutoresizingMaskIntoConstraints = false
            v.heightAnchor.constraint(equalToConstant: height).isActive = true
            return v
        }

        contentStack.addArrangedSubview(termsStack)
        contentStack.addArrangedSubview(spacer(16))
        contentStack.addArrangedSubview(agreeRow)
        contentStack.addArrangedSubview(spacer(24))
        contentStack.addArrangedSubview(identityField)
        contentStack.addArrangedSubview(spacer(12))
        contentStack.addArrangedSubview(passwordField)
        contentStack.addArrangedSubview(errorLabel)
        contentStack.addArrangedSubview(spacer(24))
        contentStack.addArrangedSubview(loginButton)
        contentStack.addArrangedSubview(spacer(16))
        contentStack.addArrangedSubview(goEnrollButton)
        contentStack.addArrangedSubview(activity)

        identityField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        passwordField.heightAnchor.constraint(equalToConstant: 44).isActive = true
        loginButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        errorLabel.isHidden = true

        agreeSwitch.addTarget(self, action: #selector(agreeChanged), for: .valueChanged)
        loginButton.addTarget(self, action: #selector(doLogin), for: .touchUpInside)
        goEnrollButton.addTarget(self, action: #selector(goEnroll), for: .touchUpInside)

        updateLoginButtonState()
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 24),
            scrollView.contentLayoutGuide.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: 24),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            scrollView.contentLayoutGuide.bottomAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: 24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -48),
        ])
    }

    private func applyL10n() {
        termsTitleLabel.text = L10n.string("termsTitle")
        termsContentLabel.text = L10n.string("termsContent")
        agreeLabel.text = L10n.string("termsAgree")
        identityField.placeholder = L10n.string("identityPlaceholder")
        passwordField.placeholder = L10n.string("passwordPlaceholder")
        loginButton.setTitle(L10n.string("login"), for: .normal)
        goEnrollButton.setTitle(L10n.string("goEnroll"), for: .normal)
    }

    @objc private func agreeChanged() {
        termsAccepted = agreeSwitch.isOn
        updateLoginButtonState()
    }

    private func updateLoginButtonState() {
        loginButton.isEnabled = termsAccepted && !activity.isAnimating
    }

    @objc private func doLogin() {
        let identity = (identityField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.text ?? ""
        if identity.isEmpty || password.isEmpty {
            errorLabel.text = L10n.string("errorEmptyCredentials")
            errorLabel.isHidden = false
            return
        }
        errorLabel.text = nil
        errorLabel.isHidden = true
        loginButton.isEnabled = false
        activity.startAnimating()
        Task {
            let result = await LoginApi.login(identity: identity, password: password)
            await MainActor.run {
                activity.stopAnimating()
                switch result {
                case .success:
                    AuthStorage.setTermsAcceptedVersion(1)
                    showMain()
                case .failure(let statusCode, let code):
                    errorLabel.text = "\(L10n.string("loginFail")): \(code ?? "\(statusCode ?? 0)")"
                    errorLabel.isHidden = false
                    updateLoginButtonState()
                }
            }
        }
    }

    @objc private func goEnroll() {
        let alert = UIAlertController(title: nil, message: L10n.string("goEnroll"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: L10n.string("confirm"), style: .default))
        present(alert, animated: true)
    }

    private func showMain() {
        guard let window = view.window else { return }
        window.rootViewController = MainTabController()
    }
}
