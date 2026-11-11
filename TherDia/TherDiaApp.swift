import SwiftUI

enum MainTab: Hashable { case diary, reports, settings, menu }

@main
struct TherDiaApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var reminders = ReminderManager.shared
    @StateObject private var testFlightVersion = TestFlightVersionChecker()
    @State private var selectedTab: MainTab = .diary
    @State private var selectedDate = Date()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if model.isReady {
                    TabView(selection: $selectedTab) {
                        DiaryEditorView(model: model, selectedDate: $selectedDate, selectedTab: $selectedTab, testFlightVersion: testFlightVersion)
                            .tag(MainTab.diary)
                            .tabItem { Label("Tagebuch", systemImage: "book.closed.fill") }
                        ReportsView(model: model)
                            .tag(MainTab.reports)
                            .tabItem { Label("Berichte", systemImage: "chart.pie.fill") }
                        SettingsView(model: model)
                            .tag(MainTab.settings)
                            .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
                        AppMenuView(selectedTab: $selectedTab, selectedDate: $selectedDate, model: model)
                            .tag(MainTab.menu)
                            .tabItem { Label("Menü", systemImage: "line.3.horizontal") }
                    }
                } else {
                    SetupView(model: model)
                }
            }
            .preferredColorScheme(.light)
            .tint(TherDiaTheme.accent)
            .task {
                await model.bootstrap()
                await testFlightVersion.refresh()
                if model.isReady { await reminders.synchronize(database: model.database) }
                else { await reminders.refresh() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await testFlightVersion.refresh()
                        await reminders.refresh()
                        await model.sync()
                        if model.isReady { await reminders.synchronize(database: model.database) }
                    }
                }
            }
            .onChange(of: model.database) { _, database in
                Task { await reminders.synchronize(database: database) }
            }
            .onReceive(model.connectivity.$isConnected) { connected in
                if connected { Task { await model.sync() } }
            }
            .sheet(item: Binding(
                get: { reminders.activeReminderPrompt },
                set: { if $0 == nil { reminders.closeReminderPrompt() } }
            )) { prompt in
                ReminderDecisionView(dayKey: prompt.dayKey) {
                    selectedDate = .now
                    selectedTab = .diary
                }
            }
            .sheet(isPresented: Binding(
                get: { !model.conflicts.isEmpty },
                set: { _ in } // Cannot dismiss until the user makes an explicit choice.
            )) {
                ConflictReviewView(model: model)
            }
            .alert("TherDia", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK") { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "")
            }
        }
    }
}
