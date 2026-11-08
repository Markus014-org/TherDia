import SwiftUI

struct ConflictReviewView: View {
    @ObservedObject var model: AppModel
    @State private var acceptNewer: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Label("Änderungen benötigen deine Zustimmung", systemImage: "exclamationmark.shield")
                        .font(.headline).foregroundStyle(TherDiaTheme.ink)
                    Text("Auf zwei Geräten wurde dasselbe Feld unterschiedlich gespeichert. Der jüngere Eintrag ist vorausgewählt, wird aber erst nach deiner Bestätigung übernommen.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(model.conflicts) { conflict in
                        SectionCard("\(conflict.dayKey) · \(conflict.field.title)") {
                            HStack {
                                Label("Älter", systemImage: "clock")
                                Spacer()
                                Text(conflict.older.timestamp.formatted(date: .abbreviated, time: .shortened))
                            }.font(.caption).foregroundStyle(.secondary)
                            Text(FieldDescription.describe(conflict.field, json: conflict.older.value))
                            Divider()
                            HStack {
                                Label("Jünger", systemImage: "clock.badge.checkmark")
                                Spacer()
                                Text(conflict.newer.timestamp.formatted(date: .abbreviated, time: .shortened))
                            }.font(.caption).foregroundStyle(TherDiaTheme.accent)
                            Text(FieldDescription.describe(conflict.field, json: conflict.newer.value))
                            Toggle("Jüngeren Eintrag übernehmen", isOn: Binding(
                                get: { acceptNewer[conflict.id] ?? true },
                                set: { acceptNewer[conflict.id] = $0 }
                            )).tint(TherDiaTheme.accent)
                            Text("Älter: \(conflict.isLocalNewer ? "Dropbox" : "dieses Gerät") · Jünger: \(conflict.isLocalNewer ? "dieses Gerät" : "Dropbox")")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Text("Wenn du den älteren Eintrag behältst, wird dies als neue bestätigte Korrektur gespeichert.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(16)
            }
            .background(TherDiaTheme.canvas)
            .navigationTitle("Synchronisation prüfen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Auswahl bestätigen") {
                        let selected = Set(model.conflicts.filter { acceptNewer[$0.id] ?? true }.map(\.id))
                        Task { await model.resolveConflicts(acceptNewer: selected) }
                    }.bold()
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
