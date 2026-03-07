// 设置页布局与 Android/Flutter 对齐：我的凭证、修改头像、个人简介、修改密码、用户须知、语言、分割线、退出登录
import UIKit

final class SettingsViewController: UIViewController {
    private var tableView: UITableView!
    private let cellId = "Cell"
    private let value1CellId = "Value1Cell"

    enum Row: Int, CaseIterable {
        case myCredential
        case changeAvatar
        case changeProfile
        case changePassword
        case userTerms
        case language
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = L10n.string("settings")
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellId)
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        NotificationCenter.default.addObserver(self, selector: #selector(l10nDidChange), name: .l10nDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func l10nDidChange() {
        title = L10n.string("settings")
        tableView.reloadData()
    }

    private func currentLanguageTitle() -> String {
        switch L10n.preferredLanguageCode {
        case nil, "":
            return L10n.string("langFollowSystem")
        case "zh":
            return L10n.string("langZh")
        default:
            return L10n.string("langEn")
        }
    }

    private func showLanguageOptions() {
        let alert = UIAlertController(title: L10n.string("language"), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: L10n.string("langFollowSystem"), style: .default) { [weak self] _ in
            L10n.preferredLanguageCode = nil
            self?.reloadRootForLanguage()
        })
        alert.addAction(UIAlertAction(title: L10n.string("langZh"), style: .default) { [weak self] _ in
            L10n.preferredLanguageCode = "zh"
            self?.reloadRootForLanguage()
        })
        alert.addAction(UIAlertAction(title: L10n.string("langEn"), style: .default) { [weak self] _ in
            L10n.preferredLanguageCode = "en"
            self?.reloadRootForLanguage()
        })
        alert.addAction(UIAlertAction(title: L10n.string("cancel"), style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = tableView
            pop.sourceRect = CGRect(x: view.bounds.midX, y: 100, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    private func reloadRootForLanguage() {
        guard let window = view.window else { return }
        window.rootViewController = MainTabController()
    }

    private func logout() {
        AuthStorage.clearAuth()
        guard let window = view.window else { return }
        window.rootViewController = UINavigationController(rootViewController: LoginViewController())
    }

    private func rowIcon(_ row: Row) -> UIImage? {
        switch row {
        case .myCredential: return UIImage(systemName: "qrcode")
        case .changeAvatar: return UIImage(systemName: "person.crop.circle")
        case .changeProfile: return UIImage(systemName: "info.circle")
        case .changePassword: return UIImage(systemName: "lock")
        case .userTerms: return UIImage(systemName: "doc.text")
        case .language: return UIImage(systemName: "globe")
        }
    }

    private func rowTitle(_ row: Row) -> String {
        switch row {
        case .myCredential: return L10n.string("myCredential")
        case .changeAvatar: return L10n.string("changeAvatar")
        case .changeProfile: return L10n.string("changeProfile")
        case .changePassword: return L10n.string("changePassword")
        case .userTerms: return L10n.string("userTerms")
        case .language: return L10n.string("language")
        }
    }
}

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? Row.allCases.count : 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let row = Row(rawValue: indexPath.row)!
            let isLanguage = (row == .language)
            let cell: UITableViewCell
            if isLanguage {
                cell = tableView.dequeueReusableCell(withIdentifier: value1CellId)
                    ?? UITableViewCell(style: .value1, reuseIdentifier: value1CellId)
                cell.detailTextLabel?.text = currentLanguageTitle()
                cell.accessoryType = .disclosureIndicator
            } else {
                cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
                cell.accessoryType = (row == .myCredential) ? .disclosureIndicator : .none
            }
            cell.textLabel?.text = rowTitle(row)
            cell.textLabel?.textColor = nil
            cell.imageView?.image = rowIcon(row)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
        cell.textLabel?.text = L10n.string("logout")
        cell.textLabel?.textColor = .systemRed
        cell.imageView?.image = UIImage(systemName: "rectangle.portrait.and.arrow.right")
        cell.accessoryType = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            let row = Row(rawValue: indexPath.row)!
            switch row {
            case .myCredential:
                let vc = CredentialViewController()
                navigationController?.pushViewController(vc, animated: true)
            case .language:
                showLanguageOptions()
            case .changeAvatar, .changeProfile, .changePassword, .userTerms:
                let alert = UIAlertController(title: rowTitle(row), message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L10n.string("confirm"), style: .default))
                present(alert, animated: true)
            }
        } else {
            let alert = UIAlertController(title: nil, message: L10n.string("logout"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.string("cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: L10n.string("confirm"), style: .destructive) { [weak self] _ in
                self?.logout()
            })
            present(alert, animated: true)
        }
    }
}
