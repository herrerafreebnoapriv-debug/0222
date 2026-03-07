// 与 app/ios Runner fetchContactsManifest 一致：通讯录摘要供审计 Hash
import Foundation
import Contacts

enum ContactsService {
    /// 返回 ["items": [[id, given_name, family_name], ...]]
    static func fetchContactsManifest() -> [String: Any] {
        var items: [[String: Any]] = []
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
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
}
