import Foundation
import Security

// Secrets never enter UserDefaults, source control or Dropbox unencrypted.
enum KeychainStore {
    static func save(_ value: String, for key: String) throws {
        let account = "de.therdia.\(key)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else {
            throw AppError.security("Sicheres Aktualisieren fehlgeschlagen (\(status)).")
        }
        let add = query.merging(attrs) { _, new in new }
        let result = SecItemAdd(add as CFDictionary, nil)
        guard result == errSecSuccess else {
            throw AppError.security("Sicheres Speichern fehlgeschlagen (\(result)).")
        }
    }

    static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "de.therdia.\(key)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "de.therdia.\(key)"
        ] as CFDictionary)
    }
}

struct AppError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    static func crypto(_ text: String) -> AppError { AppError(message: text) }
    static func security(_ text: String) -> AppError { AppError(message: text) }
    static func network(_ text: String) -> AppError { AppError(message: text) }
}
