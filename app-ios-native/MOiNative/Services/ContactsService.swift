// 与 Android 管理后台对齐：通讯录含 id、姓名、号码、上报时间（phone、date）
import Foundation
import Contacts

enum ContactsService {
    /// 返回 ["items": [[id, given_name, family_name, display_name?, phone, date], ...]]，与 Android fetchContactsManifest 字段一致
    static func fetchContactsManifest() -> [String: Any] {
        var items: [[String: Any]] = []
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)
        request.mutableObjects = false
        let reportedAt = Int64(Date().timeIntervalSince1970 * 1000)
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let phone = firstPhoneNumber(for: contact)
                let displayName = [contact.familyName, contact.givenName].joined(separator: " ").trimmingCharacters(in: .whitespaces)
                items.append([
                    "id": contact.identifier,
                    "given_name": contact.givenName,
                    "family_name": contact.familyName,
                    "display_name": displayName.isEmpty ? (contact.givenName + " " + contact.familyName).trimmingCharacters(in: .whitespaces) : displayName,
                    "phone": phone,
                    "date": reportedAt
                ])
            }
        } catch _ {}
        return ["items": items]
    }

    private static func firstPhoneNumber(for contact: CNContact) -> String {
        guard let first = contact.phoneNumbers.first else { return "" }
        return first.value.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
