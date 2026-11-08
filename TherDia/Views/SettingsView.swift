import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var base = Medication()
    @State private var rescue = Medication()
    @State private var showReset = false
    @State private var authCode = ""
    @State private var showReconnect = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionCard("Status") {
                        Label(model.connected ? "Dropbox verbunden" : "Nicht verbunden", systemImage: "externaldrive")
                        Label(model.syncStatus, systemImage: "arrow.triangle.2.circlepath")
                        Text("Datei: \(model.cloudPath)")
                            .font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
                        if let lastSync = model.lastSync {
                            Text("Zuletzt erfolgreich: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Button("Jetzt synchronisieren") { Task { await model.sync() } }
                            .disabled(model.isSyncing || !model.connected)
                        Button("Dropbox-Verbindung erneuern") { showReconnect.toggle() }
                        if showReconnect {
                            Button("Dropbox-Anmeldung im Browser öffnen") {
                                do { openURL(try model.openDropboxLogin()) }
                                catch { model.errorMessage = error.localizedDescription }
                            }
                            TextField("Einmalcode aus Dropbox", text: $authCode)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                            Button("Neuen Code bestätigen") {
                                Task {
                                    await model.completeDropboxLogin(code: authCode)
                                    showReconnect = false
                                }
                            }.disabled(authCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    SectionCard("Voreinstellung Basis-Medikation", subtitle: "Auf diesem Gerät verschlüsselt im Schlüsselbund gespeichert") {
                        TextField("Art", text: $base.name).textFieldStyle(.roundedBorder)
                        TextField("Menge inkl. Einheit", text: $base.quantity).textFieldStyle(.roundedBorder)
                    }
                    SectionCard("Voreinstellung Notmedikation") {
                        TextField("Art", text: $rescue.name).textFieldStyle(.roundedBorder)
                        TextField("Menge inkl. Einheit", text: $rescue.quantity).textFieldStyle(.roundedBorder)
                    }
                    PrimaryAction(title: "Voreinstellungen speichern") {
                        model.updateDefaults(base: base, rescue: rescue)
                    }
                    SectionCard("Datenschutz & Geräte") {
                        Label("Dropbox und Offline-Cache: AES-256-GCM", systemImage: "lock.shield")
                        Label("Passphrase und Token: iOS-Schlüsselbund", systemImage: "key")
                        Text("Die gesamte Datenhistorie bleibt auch offline auf diesem Gerät lesbar. Die Passphrase kann bei Verlust nicht zurückgesetzt werden.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Dieses Gerät zurücksetzen", role: .destructive) { showReset = true }
                    }
                }
                .padding(16)
            }
            .background(TherDiaTheme.canvas)
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { base = model.defaultBase; rescue = model.defaultRescue }
            .confirmationDialog("Gerät zurücksetzen?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Lokale Daten und Zugang löschen", role: .destructive) { model.resetThisDevice() }
            } message: {
                Text("Ungesendete Einträge auf diesem Gerät gehen verloren. Die Dropbox-Datei bleibt bestehen. Nur fortfahren, wenn alle Änderungen synchronisiert sind.")
            }
        }
    }
}
