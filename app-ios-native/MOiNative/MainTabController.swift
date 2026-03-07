// 主界面 Tab：首页、设置、凭证（多语言）
import UIKit

final class MainTabController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(title: L10n.string("tabHome"), image: nil, tag: 0)
        let settings = UINavigationController(rootViewController: SettingsViewController())
        settings.tabBarItem = UITabBarItem(title: L10n.string("tabSettings"), image: nil, tag: 1)
        let credential = UINavigationController(rootViewController: CredentialViewController())
        credential.tabBarItem = UITabBarItem(title: L10n.string("tabCredential"), image: nil, tag: 2)
        viewControllers = [home, settings, credential]
    }
}
