import Foundation

struct FieldChange: Identifiable {
    let field: DiaryField
    let oldValue: String?
    let newValue: String
    var id: String { field.rawValue }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var database = DiaryDatabase()
    @Published private(set) var isReady = false
    @Published private(set) var connected = KeychainStore.load("dropbox-refresh") != nil
    @Published private(set) var isSyncing = false
    @Published private(set) var syncStatus = "Noch nicht synchronisiert"
    @Published var errorMessage: String?
    @Published private(set) var conflicts: [SyncConflict] = []
    @Published private(set) var defaultBase = Medication()
    @Published private(set) var defaultRescue = Medication()
    @Published private(set) var lastSync: Date?

    let connectivity = Connectivity()
    private let localStore = LocalStore()
    private let defaults = UserDefaults.standard
    private let deviceID: String
    private let dropbox: DropboxClient
    private var generation = 0
    private var lastChangeTime: Date = .distantPast
    private var pendingPlan: MergePlan?
    private var pendingRevision: String?
    private var pendingGeneration = 0

    var cloudPath: String { defaults.string(forKey: "cloudPath") ?? "/TherDia/therdia.enc" }
    var cloudMode: String { defaults.string(forKey: "cloudMode") ?? "join" }
    var appKey: String { Bundle.main.object(forInfoDictionaryKey: "DropboxAppKey") as? String ?? "" }
    var hasPassword: Bool { KeychainStore.load("encryption-password") != nil }
    var canEdit: Bool { isReady && !isSyncing && conflicts.isEmpty }

    init() {
        let id = defaults.string(forKey: "deviceID") ?? UUID().uuidString
        defaults.set(id, forKey: "deviceID")
        deviceID = id
        dropbox = DropboxClient(appKey: Bundle.main.object(forInfoDictionaryKey: "DropboxAppKey") as? String ?? "")
        if let json = KeychainStore.load("default-base") {
            defaultBase = DiaryCodec.decode(Medication.self, json) ?? Medication()
        }
        if let json = KeychainStore.load("default-rescue") {
            defaultRescue = DiaryCodec.decode(Medication.self, json) ?? Medication()
        }
        lastSync = defaults.object(forKey: "lastSync") as? Date
    }

    func bootstrap() async {
        guard let password = KeychainStore.load("encryption-password") else { return }
        do {
            database = try localStore.read(password: password)
            isReady = true
            syncStatus = connected ? "Lokal geladen · Dropbox wird abgeglichen" : "Offline · Dropbox nicht verbunden"
            if connected { await sync() }
        } catch {
            // A corrupt local cache is never replaced without user interaction.
            isReady = false
            errorMessage = "Lokaler Datenbestand konnte nicht geöffnet werden: \(error.localizedDescription)"
        }
    }

    func openDropboxLogin() throws -> URL {
        try DropboxAuthorization.begin(appKey: appKey)
    }

    func completeDropboxLogin(code: String) async {
        do {
            try await DropboxAuthorization.finish(code: code, appKey: appKey)
            await dropbox.invalidateSession()
            connected = true
            syncStatus = "Dropbox verbunden"
            if isReady { await sync() }
        } catch { errorMessage = error.localizedDescription }
    }

    func configure(path: String, password: String, createNew: Bool) async {
        let clean = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.hasPrefix("/"), clean.hasSuffix(".enc"), !clean.contains(".."), !clean.contains("//"), clean.count > 5 else {
            errorMessage = "Bitte einen Dropbox-Pfad wie /TherDia/therdia.enc eingeben."
            return
        }
        guard password.count >= 12 else {
            errorMessage = "Bitte eine gemeinsame Passphrase mit mindestens 12 Zeichen verwenden."
            return
        }
        guard connected else { errorMessage = "Bitte zuerst Dropbox verbinden."; return }
        do {
            try KeychainStore.save(password, for: "encryption-password")
            defaults.set(clean, forKey: "cloudPath")
            defaults.set(createNew ? "create" : "join", forKey: "cloudMode")
            database = try localStore.read(password: password)
            isReady = true
            await sync()
            // First-time setup may have entered a wrong path or passphrase.
            if syncStatus.hasPrefix("Fehler") && database.isEmpty { isReady = false }
        } catch {
            isReady = false
            errorMessage = error.localizedDescription
        }
    }

    func updateDefaults(base: Medication, rescue: Medication) {
        do {
            try KeychainStore.save(try DiaryCodec.encode(base), for: "default-base")
            try KeychainStore.save(try DiaryCodec.encode(rescue), for: "default-rescue")
            defaultBase = base
            defaultRescue = rescue
        } catch { errorMessage = error.localizedDescription }
    }

    func draft(for date: Date) -> DayDraft {
        let key = DiaryCodec.dateKey(date)
        return (database.days[key] ?? DayRecord()).draft(fallbackBase: defaultBase, fallbackRescue: defaultRescue)
    }

    func changes(for input: DayDraft, date: Date) throws -> [FieldChange] {
        var normalized = input
        normalized.normalize()
        let old = database.days[DiaryCodec.dateKey(date)] ?? DayRecord()
        return try normalized.serializedFields().compactMap { field, text in
            let existing = old.field(field)?.value
            return existing == text ? nil : FieldChange(field: field, oldValue: existing, newValue: text)
        }.sorted { $0.field.title < $1.field.title }
    }

    func save(_ input: DayDraft, date: Date) {
        guard canEdit else { errorMessage = "Bitte zuerst die Synchronisation oder Konfliktprüfung abschließen."; return }
        var normalized = input
        normalized.normalize()
        if let error = normalized.validationError { errorMessage = error; return }
        do {
            let changes = try changes(for: normalized, date: date)
            guard !changes.isEmpty else { syncStatus = "Keine Änderungen"; return }
            var updated = database
            let dayKey = DiaryCodec.dateKey(date)
            var day = updated.days[dayKey] ?? DayRecord()
            for change in changes {
                let previous = day.fields[change.field.rawValue]?.timestamp ?? .distantPast
                let time = max(Date.now, max(lastChangeTime.addingTimeInterval(0.002),
                                              previous.addingTimeInterval(0.002)))
                lastChangeTime = time
                day.fields[change.field.rawValue] = FieldRevision(value: change.newValue, timestamp: time,
                    deviceID: deviceID, changeID: UUID().uuidString)
            }
            updated.days[dayKey] = day
            let password = try passwordOrThrow()
            try localStore.write(updated, password: password)
            database = updated
            generation += 1
            syncStatus = "Lokal verschlüsselt gespeichert · Synchronisation ausstehend"
            if connected && connectivity.isConnected {
                Task { await self.sync() }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func sync() async {
        guard isReady, connected, !isSyncing, conflicts.isEmpty else { return }
        guard connectivity.isConnected else { syncStatus = "Offline · Änderungen sicher lokal gespeichert"; return }
        isSyncing = true
        syncStatus = "Dropbox-Synchronisation läuft …"
        defer { isSyncing = false }
        do {
            let password = try passwordOrThrow()
            for _ in 0..<5 {
                let capturedGeneration = generation
                let snapshot = database
                let remote = try await dropbox.download(path: cloudPath)
                if capturedGeneration != generation { continue }

                if remote == nil {
                    guard cloudMode == "create" else {
                        throw AppError.network("Die Dropbox-Datei existiert unter \(cloudPath) nicht. Aus Sicherheitsgründen wird sie nicht automatisch neu angelegt.")
                    }
                    do {
                        _ = try await dropbox.upload(data: CryptoBox.encrypt(snapshot, password: password), path: cloudPath, revision: nil)
                        defaults.set("join", forKey: "cloudMode")
                        if capturedGeneration != generation { continue }
                        try finishSync(snapshot, password: password)
                        return
                    } catch is UploadConflict {
                        throw AppError.network("Am gewählten Pfad wurde bereits eine Datenbank angelegt. Bitte 'Bestehende öffnen' wählen.")
                    }
                }

                guard let remote else { continue }
                if cloudMode == "create" {
                    throw AppError.network("Unter diesem Pfad existiert bereits eine Datenbank. Bitte 'Bestehende öffnen' wählen, statt sie zu ersetzen.")
                }
                let remoteDatabase = try CryptoBox.decrypt(remote.bytes, password: password)
                let plan = MergeEngine.plan(local: snapshot, remote: remoteDatabase)
                if capturedGeneration != generation { continue }
                if !plan.conflicts.isEmpty {
                    pendingPlan = plan
                    pendingRevision = remote.revision
                    pendingGeneration = capturedGeneration
                    conflicts = plan.conflicts
                    syncStatus = "Änderungen prüfen · \(plan.conflicts.count) Feld(er)"
                    return
                }
                if plan.merged != remoteDatabase {
                    do {
                        _ = try await dropbox.upload(data: CryptoBox.encrypt(plan.merged, password: password),
                            path: cloudPath, revision: remote.revision)
                    } catch is UploadConflict {
                        // Another device won the race: download, re-merge and ask again if needed.
                        continue
                    }
                    if capturedGeneration != generation { continue }
                }
                try finishSync(plan.merged, password: password)
                return
            }
            throw AppError.network("Zeitgleiche Änderungen in Dropbox. Bitte erneut synchronisieren.")
        } catch {
            syncStatus = "Fehler · Synchronisation ausstehend"
            errorMessage = error.localizedDescription
        }
    }

    func resolveConflicts(acceptNewer: Set<String>) async {
        guard let plan = pendingPlan, let revision = pendingRevision else { return }
        let expectedGeneration = pendingGeneration
        pendingPlan = nil
        pendingRevision = nil
        conflicts = []
        if generation != expectedGeneration { await sync(); return }
        isSyncing = true
        syncStatus = "Geprüfte Änderungen werden synchronisiert …"
        do {
            let password = try passwordOrThrow()
            let resolved = MergeEngine.resolve(plan, acceptNewer: acceptNewer, deviceID: deviceID)
            _ = try await dropbox.upload(data: CryptoBox.encrypt(resolved, password: password), path: cloudPath, revision: revision)
            if generation == expectedGeneration {
                try finishSync(resolved, password: password)
            } else {
                syncStatus = "Zwischenzeitliche lokale Änderung · erneuter Abgleich nötig"
            }
        } catch is UploadConflict {
            syncStatus = "Dropbox wurde inzwischen geändert · erneute Prüfung nötig"
        } catch {
            syncStatus = "Fehler · Geprüfte Änderungen noch nicht übernommen"
            errorMessage = error.localizedDescription
        }
        isSyncing = false
        // A rejected update or network failure never triggers an unchecked overwrite.
        if connectivity.isConnected && syncStatus != "Synchronisiert" { await sync() }
    }

    private func finishSync(_ content: DiaryDatabase, password: String) throws {
        try localStore.write(content, password: password)
        database = content
        generation += 1
        lastSync = .now
        defaults.set(lastSync, forKey: "lastSync")
        syncStatus = "Synchronisiert"
    }

    func resetThisDevice() {
        guard !isSyncing else { return }
        do {
            try localStore.delete()
            for name in ["encryption-password", "dropbox-refresh", "oauth-verifier", "default-base", "default-rescue"] {
                KeychainStore.delete(name)
            }
            defaults.removeObject(forKey: "cloudPath")
            defaults.removeObject(forKey: "cloudMode")
            defaults.removeObject(forKey: "lastSync")
            database = DiaryDatabase()
            conflicts = []
            pendingPlan = nil
            isReady = false
            connected = false
            defaultBase = Medication()
            defaultRescue = Medication()
            syncStatus = "Gerät zurückgesetzt"
        } catch { errorMessage = error.localizedDescription }
    }

    private func passwordOrThrow() throws -> String {
        guard let value = KeychainStore.load("encryption-password") else {
            throw AppError.crypto("Verschlüsselungspasswort fehlt.")
        }
        return value
    }
}
