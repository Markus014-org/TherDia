import SwiftUI

@main
struct TherDiaApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if model.isReady {
                    TabView {
                        DiaryEditorView(model: model)
                            .tabItem { Label("Tagebuch", systemImage: "book.closed.fill") }
                        ReportsView(model: model)
                            .tabItem { Label("Berichte", systemImage: "chart.pie.fill") }
                        SettingsView(model: model)
                            .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
                    }
                } else {
                    SetupView(model: model)
                }
            }
            .tint(TherDiaTheme.accent)
            .task { await model.bootstrap() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.sync() } }
            }
            .onReceive(model.connectivity.$isConnected) { connected in
                if connected { Task { await model.sync() } }
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
