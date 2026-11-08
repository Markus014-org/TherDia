import SwiftUI

struct AppMenuView: View {
    @Binding var selectedTab: MainTab
    @Binding var selectedDate: Date
    @ObservedObject var model: AppModel
    @State private var showDatePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("TherDia")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(TherDiaTheme.accent)
                    SectionCard("Navigation") {
                        Button { selectedTab = .diary } label: {
                            Label("Tagebuch öffnen", systemImage: "book.closed")
                        }
                        Divider()
                        Button { showDatePicker = true } label: {
                            Label("Zu einem bestimmten Tag springen", systemImage: "calendar")
                        }
                        Divider()
                        Button { selectedTab = .reports } label: {
                            Label("Berichtswesen und Statistiken", systemImage: "chart.pie")
                        }
                        Divider()
                        Button { selectedTab = .settings } label: {
                            Label("Medikamente und Einstellungen", systemImage: "gearshape")
                        }
                    }
                    SectionCard("Synchronisation") {
                        Label(model.syncStatus, systemImage: "externaldrive")
                        Button("Jetzt synchronisieren") {
                            Task { await model.sync() }
                        }.disabled(!model.connected || model.isSyncing)
                    }
                }.padding(16)
            }
            .background(TherDiaTheme.canvas)
            .navigationTitle("Menü")
            .sheet(isPresented: $showDatePicker) {
                NavigationStack {
                    VStack {
                        DatePicker("Tag auswählen", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        Button("Tag öffnen") {
                            showDatePicker = false
                            selectedTab = .diary
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding(20)
                    .navigationTitle("Zum Datum springen")
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { showDatePicker = false }
                    }}
                }
            }
        }
    }
}
