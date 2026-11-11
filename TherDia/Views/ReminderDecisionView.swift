import SwiftUI

/// Opens after a user taps a TherDia notification on the lock screen.
/// Closing without choosing intentionally leaves recurring reminders active.
struct ReminderDecisionView: View {
    let dayKey: String
    let onOpenDiary: () -> Void

    @ObservedObject private var reminders = ReminderManager.shared
    @State private var isApplying = false

    private var validToday: Bool {
        dayKey == DiaryCodec.dateKey(.now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(TherDiaTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Tagebuch-Erinnerung")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text("Für heute ist noch kein Eintrag gespeichert. Was möchtest du tun?")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button {
                        reminders.closeReminderPrompt()
                        onOpenDiary()
                    } label: {
                        Label("Jetzt Tagebuch eintragen", systemImage: "book.closed")
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.borderedProminent)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Später erneut erinnern")
                            .font(.headline)
                            .foregroundStyle(TherDiaTheme.ink)

                        Button { choose(ReminderManager.action15) } label: {
                            Label("In 15 Minuten", systemImage: "clock.arrow.circlepath")
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(.bordered)

                        Button { choose(ReminderManager.action30) } label: {
                            Label("In 30 Minuten", systemImage: "clock.arrow.circlepath")
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(.bordered)

                        Button { choose(ReminderManager.action60) } label: {
                            Label("In 1 Stunde", systemImage: "clock.arrow.circlepath")
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    Button(role: .destructive) {
                        choose(ReminderManager.actionDone)
                    } label: {
                        Label("Für heute beenden", systemImage: "bell.slash")
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.bordered)

                    Text("„Für heute beenden“ schaltet nur die Erinnerungen für heute ab, ohne einen Tagebucheintrag zu speichern. Wenn du das Fenster schließt, bleiben die automatischen Erinnerungen aktiv.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(TherDiaTheme.canvas)
            .navigationTitle("Erinnerung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Später entscheiden") {
                        reminders.closeReminderPrompt()
                    }
                }
            }
            .disabled(isApplying || !validToday)
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .onChange(of: validToday) { _, isValid in
            if !isValid { reminders.closeReminderPrompt() }
        }
    }

    private func choose(_ action: String) {
        guard !isApplying && validToday else { return }
        isApplying = true
        Task {
            await reminders.selectReminderAction(action, for: dayKey)
            isApplying = false
        }
    }
}
