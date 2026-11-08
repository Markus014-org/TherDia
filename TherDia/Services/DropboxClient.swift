import Foundation
import CryptoKit
import Network
import Security

struct RemoteFile {
    let bytes: Data
    let revision: String
}

enum DropboxAuthorization {
    static func begin(appKey: String) throws -> URL {
        guard !appKey.isEmpty, !appKey.contains("$("), !appKey.hasPrefix("SET_") else {
            throw AppError.network("Dropbox-App-Key fehlt. Siehe README und Build-Konfiguration.")
        }
        var random = [UInt8](repeating: 0, count: 32)
        let randomStatus = random.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, buffer.count, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else {
            throw AppError.security("Sichere Zufallszahlen nicht verfügbar.")
        }
        let verifierString = Data(random).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        try KeychainStore.save(verifierString, for: "oauth-verifier")
        let digest = SHA256.hash(data: Data(verifierString.utf8))
        let challenge = Data(digest).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        var parts = URLComponents(string: "https://www.dropbox.com/oauth2/authorize")!
        parts.queryItems = [
            URLQueryItem(name: "client_id", value: appKey),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "token_access_type", value: "offline"),
            URLQueryItem(name: "scope", value: "files.content.read files.content.write")
        ]
        // Dropbox only accepts HTTPS/localhost redirects. Without redirect_uri,
        // the browser shows a code to copy back into the iOS app.
        return parts.url!
    }

    static func finish(code: String, appKey: String) async throws {
        guard let verifier = KeychainStore.load("oauth-verifier"), !verifier.isEmpty else {
            throw AppError.network("Bitte zuerst die Dropbox-Anmeldung starten.")
        }
        let form = [
            "grant_type": "authorization_code",
            "client_id": appKey,
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            "code_verifier": verifier
        ]
        let response = try await DropboxClient.token(form: form)
        guard let refresh = response.refresh_token, !refresh.isEmpty else {
            throw AppError.network("Kein dauerhaftes Dropbox-Token erhalten. Anmeldung bitte erneut starten.")
        }
        try KeychainStore.save(refresh, for: "dropbox-refresh")
        KeychainStore.delete("oauth-verifier")
    }
}

fileprivate struct TokenResponse: Decodable {
    let access_token: String
    let expires_in: Int?
    let refresh_token: String?
}

actor DropboxClient {
    private let appKey: String
    private var token: String?
    private var tokenExpires: Date = .distantPast

    init(appKey: String) { self.appKey = appKey }

    func invalidateSession() {
        token = nil
        tokenExpires = .distantPast
    }

    fileprivate static func token(form: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://api.dropboxapi.com/oauth2/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AppError.network("Dropbox-Antwort ist ungültig.") }
        guard (200..<300).contains(http.statusCode) else {
            throw AppError.network("Dropbox-Anmeldung fehlgeschlagen (HTTP \(http.statusCode)). Code ggf. erneut erzeugen.")
        }
        return try JSONDecoder().decode(TokenResponse.self, from: data)
    }

    private func accessToken() async throws -> String {
        if let token, tokenExpires > Date().addingTimeInterval(90) { return token }
        guard let refresh = KeychainStore.load("dropbox-refresh") else {
            throw AppError.network("Dropbox ist nicht verbunden.")
        }
        let result = try await Self.token(form: [
            "grant_type": "refresh_token", "refresh_token": refresh, "client_id": appKey
        ])
        token = result.access_token
        tokenExpires = Date().addingTimeInterval(TimeInterval(result.expires_in ?? 14_400))
        return result.access_token
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AppError.network("Dropbox-Antwort fehlt.") }
        if http.statusCode == 401 { token = nil; throw AppError.network("Dropbox-Anmeldung abgelaufen. Bitte erneut verbinden.") }
        if http.statusCode == 429 { throw AppError.network("Dropbox begrenzt aktuell die Anfragen. Später erneut synchronisieren.") }
        return (data, http)
    }

    func download(path: String) async throws -> RemoteFile? {
        var request = URLRequest(url: URL(string: "https://content.dropboxapi.com/2/files/download")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue(jsonHeader(["path": path]), forHTTPHeaderField: "Dropbox-API-Arg")
        let (data, response) = try await send(request)
        if response.statusCode == 409 {
            // Missing and inaccessible files must never be mistaken for an empty database.
            if errorSummary(data).hasPrefix("path/not_found/") { return nil }
            throw AppError.network("Dropbox-Datei kann nicht gelesen werden: \(errorSummary(data))")
        }
        guard response.statusCode == 200 else {
            throw AppError.network("Dropbox-Download fehlgeschlagen: HTTP \(response.statusCode).")
        }
        guard let metadata = response.value(forHTTPHeaderField: "Dropbox-API-Result"),
              let metaData = metadata.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any],
              let revision = dict["rev"] as? String else {
            throw AppError.network("Dropbox hat keine Dateirevision geliefert.")
        }
        return RemoteFile(bytes: data, revision: revision)
    }

    func upload(data: Data, path: String, revision: String?) async throws -> String {
        var request = URLRequest(url: URL(string: "https://content.dropboxapi.com/2/files/upload")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let mode: [String: String] = revision.map { [".tag": "update", "update": $0] } ?? [".tag": "add"]
        request.setValue(jsonHeader([
            "path": path, "mode": mode, "autorename": false, "mute": true, "strict_conflict": true
        ]), forHTTPHeaderField: "Dropbox-API-Arg")
        request.httpBody = data
        let (result, response) = try await send(request)
        if response.statusCode == 409 {
            throw UploadConflict()
        }
        guard response.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: result) as? [String: Any],
              let newRevision = json["rev"] as? String else {
            throw AppError.network("Dropbox-Upload fehlgeschlagen (HTTP \(response.statusCode)): \(errorSummary(result))")
        }
        return newRevision
    }

    private func jsonHeader(_ value: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else { return "{}" }
        return string
    }

    private func errorSummary(_ bytes: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return "Unbekannter API-Fehler" }
        return json["error_summary"] as? String ?? "Unbekannter API-Fehler"
    }
}

struct UploadConflict: Error {}

final class Connectivity: ObservableObject {
    @Published private(set) var isConnected = true
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "TherDia.Network")
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.isConnected = path.status == .satisfied }
        }
        monitor.start(queue: queue)
    }
    deinit { monitor.cancel() }
}
