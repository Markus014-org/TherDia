import SwiftUI

struct SetupView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openURL) private var openURL
    @State private var authorizationCode = ""
    @State private var path = "/TherDia/therdia.enc"
    @State private var passphrase = ""
    @State private var createNew = true
    @State private var showingPassphrase = false
    @State private var baseDefault = Medication()
    @State private var rescueDefault = Medication()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 44)).foregroundStyle(TherDiaTheme.accent)
                        Text("TherDia").font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(TherDiaTheme.navy)
                        Text("Dein geschütztes Tagebuch. Gemeinsam nutzbar, auch offline.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)

                    SectionCard("1 · Dropbox verbinden", subtitle: "Einmal pro Gerät · ohne Dropbox-Passwort in der App") {
                        Label(model.connected ? "Dropbox verbunden" : "Noch nicht verbunden",
                              systemImage: model.connected ? "checkmark.shield.fill" : "externaldrive")
                            .foregroundStyle(model.connected ? Color.green : Color.secondary)
                        if !model.connected {
                            Button("Dropbox-Anmeldung öffnen") {
                                do { openURL(try model.openDropboxLogin()) }
                                catch { model.errorMessage = error.localizedDescription }
                            }.buttonStyle(.bordered)
                            Text("Dropbox zeigt danach einen einmaligen Code an. Diesen hier einfügen:")
                                .font(.caption).foregroundStyle(.secondary)
                            TextField("Dropbox-Code", text: $authorizationCode)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                            Button("Code bestätigen") {
                                Task { await model.completeDropboxLogin(code: authorizationCode) }
                            }
                            .disabled(authorizationCode.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    SectionCard("2 · Gemeinsame Datenbank", subtitle: "Auf jedem Gerät denselben Dateipfad verwenden") {
                        Picker("Datenbank", selection: $createNew) {
                            Text("Neu erstellen").tag(true)
                            Text("Bestehende öffnen").tag(false)
                        }.pickerStyle(.segmented)
                        TextField("Dropbox-Dateipfad", text: $path)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Text("Für verschiedene Dropbox-Konten muss der Ordner für alle Personen freigegeben sein und in jedem Konto unter demselben Pfad liegen.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    SectionCard("3 · Verschlüsselung", subtitle: "Alle Geräte benötigen dieselbe Passphrase") {
                        HStack {
                            Group {
                                if showingPassphrase {
                                    TextField("Gemeinsame Passphrase (mind. 12 Zeichen)", text: $passphrase)
                                } else {
                                    SecureField("Gemeinsame Passphrase (mind. 12 Zeichen)", text: $passphrase)
                                }
                            }
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            Button { showingPassphrase.toggle() } label: {
                                Image(systemName: showingPassphrase ? "eye.slash" : "eye")
                            }.accessibilityLabel("Passphrase anzeigen oder verbergen")
                        }
                        .textFieldStyle(.roundedBorder)
                        Text("Wichtig: Ohne Passphrase können auch die Entwickler die Daten nicht wiederherstellen. Bewahre sie außerhalb der App sicher auf.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    SectionCard("4 · Medikamenten-Voreinstellungen", subtitle: "Pro Gerät hinterlegen; jeder Tag kann davon abweichen") {
                        Text("Basis-Medikation").font(.subheadline.bold())
                        TextField("Bezeichnung", text: $baseDefault.name).textFieldStyle(.roundedBorder)
                        TextField("Menge mit Einheit", text: $baseDefault.quantity).textFieldStyle(.roundedBorder)
                        Text("Notmedikation (optional)").font(.subheadline.bold())
                        TextField("Bezeichnung", text: $rescueDefault.name).textFieldStyle(.roundedBorder)
                        TextField("Menge mit Einheit", text: $rescueDefault.quantity).textFieldStyle(.roundedBorder)
                    }

                    PrimaryAction(title: createNew ? "Datenbank sicher anlegen" : "Datenbank öffnen",
                                  disabled: !model.connected || passphrase.count < 12) {
                        model.updateDefaults(base: baseDefault, rescue: rescueDefault)
                        Task { await model.configure(path: path, password: passphrase, createNew: createNew) }
                    }
                    Text("Die lokalen Daten bleiben verschlüsselt gespeichert. Die Synchronisation erfolgt beim Start, bei Rückkehr in die App und wenn die Internetverbindung zurückkommt.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(TherDiaTheme.canvas)
            .navigationTitle("Einrichtung")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                path = model.cloudPath
                baseDefault = model.defaultBase
                rescueDefault = model.defaultRescue
            }
        }
    }
}
