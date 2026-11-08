import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var base = MedicationList()
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
                        ForEach(base.items.indices, id: \.self) { index in
                            HStack(spacing: 7) {
                                TextField("Medikament", text: $base.items[index].name)
                                    .textFieldStyle(.roundedBorder)
                                TextField("Menge", text: $base.items[index].quantity)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 110)
                                Button(role: .destructive) {
                                    base.items.remove(at: index)
                                } label: { Image(systemName: "minus.circle.fill") }
                                .accessibilityLabel("Medikament entfernen")
                            }
                        }
                        Button { base.items.append(Medication()) } label: {
                            Label("Weiteres Medikament", systemImage: "plus.circle.fill")
                        }
                    }
                    SectionCard("Voreinstellung Notmedikation") {
                        HStack(spacing: 8) {
                            TextField("Medikament", text: $rescue.name)
                                .textFieldStyle(.roundedBorder)
                            TextField("Menge", text: $rescue.quantity)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)
                        }
                    }
                    PrimaryAction(title: "Voreinstellungen speichern") {
                        guard !base.items.isEmpty && base.items.allSatisfy({
                            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                            !$0.quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }) else {
                            model.errorMessage = "Bitte bei jedem Basis-Medikament eine Bezeichnung und Menge angeben."
                            return
                        }
                        model.updateDefaults(base: base, rescue: rescue)
                        model.errorMessage = "Medikamenten-Voreinstellungen gespeichert."
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
