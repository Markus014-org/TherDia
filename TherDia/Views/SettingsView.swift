import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var reminderManager = ReminderManager.shared
    @State private var reminderSettings = ReminderSettings()
    @State private var reminderWheel = Date()
    @State private var reminderSaving = false
    @State private var tonePreview: AVAudioPlayer?
    @State private var base = MedicationList()
    @State private var rescue = Medication()
    @State private var showReset = false
    @State private var authCode = ""
    @State private var showReconnect = false
    @Environment(\.openURL) private var openURL

    private func previewReminderTone() {
        let selected = reminderSettings.tone
        guard let sound = selected.soundName,
              let url = Bundle.main.url(forResource: sound, withExtension: nil) else {
            model.errorMessage = "Die Tondatei ist in diesem Build nicht verfügbar."
            return
        }
        do {
            tonePreview = try AVAudioPlayer(contentsOf: url)
            tonePreview?.prepareToPlay()
            tonePreview?.play()
        } catch {
            model.errorMessage = "Ton konnte nicht abgespielt werden: \(error.localizedDescription)"
        }
    }

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
                    SectionCard("Tägliche Tagebuch-Erinnerung", subtitle: "Nur für heute, falls noch kein Eintrag gespeichert wurde") {
                        Toggle("Einmal täglich erinnern", isOn: $reminderSettings.enabled)
                        if reminderSettings.enabled {
                            Text("Erinnerungszeit").font(.subheadline.bold())
                            DatePicker("Uhrzeit", selection: $reminderWheel, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("Uhrzeit der täglichen Erinnerung")
                            Picker("Art der Erinnerung", selection: $reminderSettings.mode) {
                                ForEach(ReminderMode.allCases) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            if reminderSettings.mode.usesSound {
                                Picker("Erinnerungston", selection: $reminderSettings.tone) {
                                    ForEach(ReminderTone.allCases) { tone in
                                        Text(tone.rawValue).tag(tone)
                                    }
                                }
                                .pickerStyle(.menu)
                                if reminderSettings.tone == .system {
                                    Text("Der iOS-Standardton kann nicht direkt in TherDia vorgespielt werden.")
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Button {
                                        previewReminderTone()
                                    } label: {
                                        Label("Ton anhören", systemImage: "play.circle")
                                    }
                                    .font(.subheadline)
                                }
                            }
                            Text("Bei der Benachrichtigung kannst du „Für heute beenden“ oder „In 15 Min.“, „In 30 Min.“ und „In 1 Std.“ wählen.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Button {
                            guard !reminderSaving else { return }
                            reminderSaving = true
                            var newValue = reminderSettings
                            newValue.setWheelValue(reminderWheel)
                            Task {
                                await reminderManager.configure(newValue)
                                reminderSettings = reminderManager.settings
                                reminderWheel = reminderManager.settings.wheelValue
                                reminderSaving = false
                            }
                        } label: {
                            Label(reminderSaving ? "Wird gespeichert …" : "Erinnerungseinstellungen speichern",
                                  systemImage: "bell.badge")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(reminderSaving)
                        Label(reminderManager.authorizationMessage, systemImage: "bell")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("iOS-Mitteilungen müssen erlaubt sein. Reine Tonerinnerungen können je nach iOS-Mitteilungseinstellungen dennoch sichtbar sein. Lautlos-Modus und Fokus können Töne unterdrücken. Nach dem Speichern eines Tages werden geplante Erinnerungen für diesen Tag gelöscht.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("Erinnerungen gelten für dieses iPhone. Wenn ein anderes Gerät einen Tag speichert, erkennt dieses iPhone das erst nach dem nächsten Dropbox-Abgleich. iOS kann Erinnerungen nicht bei jedem Alarm im Hintergrund mit Dropbox abgleichen.")
                            .font(.footnote).foregroundStyle(.secondary)
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
            .onAppear {
                base = model.defaultBase
                rescue = model.defaultRescue
                reminderSettings = reminderManager.settings
                reminderWheel = reminderManager.settings.wheelValue
                Task { await reminderManager.refresh() }
            }
            .confirmationDialog("Gerät zurücksetzen?", isPresented: $showReset, titleVisibility: .visible) {
                Button("Lokale Daten und Zugang löschen", role: .destructive) { model.resetThisDevice() }
            } message: {
                Text("Ungesendete Einträge auf diesem Gerät gehen verloren. Die Dropbox-Datei bleibt bestehen. Nur fortfahren, wenn alle Änderungen synchronisiert sind.")
            }
        }
    }
}
