import Foundation
import CryptoKit
import CommonCrypto
import Security

struct SealedDatabase: Codable {
    let magic: String
    let iterations: Int
    let salt: Data
    let ciphertext: Data   // AES-GCM combined: nonce, ciphertext, tag
}

enum CryptoBox {
    static let minimumIterations = 450_000

    static func encrypt(_ database: DiaryDatabase, password: String) throws -> Data {
        var salt = Data(count: 16)
        let randomStatus: Int32 = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 16, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { throw AppError.crypto("Zufallszahlen konnten nicht erstellt werden.") }
        let key = try deriveKey(password: password, salt: salt, iterations: minimumIterations)
        let plaintext = try DiaryCodec.encoder.encode(database)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw AppError.crypto("Verschlüsselung fehlgeschlagen.") }
        return try DiaryCodec.encoder.encode(SealedDatabase(magic: "THERDIA1", iterations: minimumIterations, salt: salt, ciphertext: combined))
    }

    static func decrypt(_ data: Data, password: String) throws -> DiaryDatabase {
        let envelope = try DiaryCodec.decoder.decode(SealedDatabase.self, from: data)
        guard envelope.magic == "THERDIA1", (minimumIterations...2_000_000).contains(envelope.iterations), envelope.salt.count == 16 else {
            throw AppError.crypto("Unbekanntes oder ungültiges Dateiformat.")
        }
        let key = try deriveKey(password: password, salt: envelope.salt, iterations: envelope.iterations)
        do {
            let box = try AES.GCM.SealedBox(combined: envelope.ciphertext)
            let plaintext = try AES.GCM.open(box, using: key)
            let result = try DiaryCodec.decoder.decode(DiaryDatabase.self, from: plaintext)
            guard result.schemaVersion == 1 else { throw AppError.crypto("Diese Datenbankversion wird nicht unterstützt.") }
            return result
        } catch {
            throw AppError.crypto("Die Datei konnte nicht entschlüsselt werden. Passwort prüfen; die Dropbox-Datei bleibt unverändert.")
        }
    }

    private static func deriveKey(password: String, salt: Data, iterations: Int) throws -> SymmetricKey {
        var derived = [UInt8](repeating: 0, count: 32)
        let result: Int32 = password.withCString { passwordBytes in
            salt.withUnsafeBytes { saltBuffer in
                CCCryptorStatus(CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes,
                    password.utf8.count,
                    saltBuffer.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    &derived,
                    derived.count
                ))
            }
        }
        guard result == kCCSuccess else { throw AppError.crypto("Schlüsselableitung fehlgeschlagen.") }
        return SymmetricKey(data: Data(derived))
    }
}
