import Foundation
import UserNotifications
import Combine

/// Schedules one notification per local calendar day (30 days ahead).
/// Settings and dismissed dates live on this device, not in Dropbox.
/// iOS does not execute arbitrary code when a local notification fires:
/// the decision to notify is therefore made when scheduling / on save.
@MainActor
final class ReminderManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderManager()

    static let categoryID = "THERDIA_DAILY_REMINDER"
    static let actionDone = "THERDIA_DONE_TODAY"
    static let action15 = "THERDIA_SNOOZE_15"
    static let action30 = "THERDIA_SNOOZE_30"
    static let action60 = "THERDIA_SNOOZE_60"
    static let requestPrefix = "therdia-reminder-"
    private static let defaultsKey = "therdia-reminder-settings"
    private static let dismissedKey = "therdia-reminder-dismissed"
    private static let recordedDaysKey = "therdia-reminder-recorded-days"

    @Published private(set) var settings: ReminderSettings
    @Published private(set) var authorizationMessage = "Noch nicht überprüft"
    private var dismissedDays: Set<String>
    private var recordedDays: Set<String>
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private var configurationInProgress = false

    private override init() {
        if let raw = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode(ReminderSettings.self, from: raw) {
            settings = saved
        } else {
            settings = ReminderSettings()
        }
        dismissedDays = Set(UserDefaults.standard.stringArray(forKey: Self.dismissedKey) ?? [])
        recordedDays = Set(UserDefaults.standard.stringArray(forKey: Self.recordedDaysKey) ?? [])
        super.init()
        center.delegate = self
        registerActions()
    }

    func configure(_ updated: ReminderSettings) async {
        guard !configurationInProgress else { return }
        configurationInProgress = true
        defer { configurationInProgress = false }

        if updated.enabled {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                guard granted else {
                    authorizationMessage = "Mitteilungen sind nicht erlaubt. Bitte in iOS-Einstellungen → TherDia → Mitteilungen aktivieren."
                    await refresh()
                    return
                }
            } catch {
                authorizationMessage = "Die Mitteilungsberechtigung konnte nicht angefragt werden: \(error.localizedDescription)"
                return
            }
        }

        settings = updated
        if let raw = try? JSONEncoder().encode(updated) {
            defaults.set(raw, forKey: Self.defaultsKey)
        }
        await refresh()
    }

    func synchronize(database: DiaryDatabase) async {
        let days = Set(database.days.compactMap { key, value in
            value.fields.isEmpty ? nil : key
        })
        // Use the current encrypted local state as the source of truth.
        recordedDays = days
        defaults.set(Array(days), forKey: Self.recordedDaysKey)
        await refresh()
    }

    func markSaved(date: Date) async {
        let key = DiaryCodec.dateKey(date)
        recordedDays.insert(key)
        defaults.set(Array(recordedDays), forKey: Self.recordedDaysKey)
        await refresh()
    }

    func refresh() async {
        registerActions()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // Old per-day decisions do not need to be retained indefinitely.
        dismissedDays = Set(dismissedDays.filter { key in
            guard let date = DiaryCodec.date(from: key) else { return false }
            return date >= today
        })
        defaults.set(Array(dismissedDays), forKey: Self.dismissedKey)
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.filter { $0.identifier.hasPrefix(Self.requestPrefix) }.map(\.identifier)
        )

        let status = await center.notificationSettings()
        switch status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorizationMessage = "Mitteilungen erlaubt"
        case .denied:
            authorizationMessage = "Mitteilungen in iOS-Einstellungen deaktiviert"
        case .notDetermined:
            authorizationMessage = "Erlaubnis noch nicht erteilt"
        @unknown default:
            authorizationMessage = "Mitteilungsstatus unbekannt"
        }
        guard settings.enabled, status.authorizationStatus == .authorized ||
              (settings.enabled && status.authorizationStatus == .provisional) ||
              (settings.enabled && status.authorizationStatus == .ephemeral)
        else { return }

        // A finite rolling window respects Apple's pending-notification limit.
        // Rebuilt when the app starts, resumes, saves, or synchronizes.
        for offset in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let key = DiaryCodec.dateKey(date)
            if recordedDays.contains(key) || dismissedDays.contains(key) { continue }

            var parts = calendar.dateComponents([.year, .month, .day], from: date)
            parts.hour = settings.hour
            parts.minute = settings.minute
            parts.second = 0
            guard let fireDate = calendar.date(from: parts), fireDate > .now else { continue }
            let content = reminderContent(for: key)
            let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.requestPrefix + key,
                content: content, trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func reminderContent(for dayKey: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "TherDia · Tagebuch-Erinnerung"
        content.body = "Für heute ist noch kein Tagebucheintrag gespeichert. Möchtest du den Tag nachtragen?"
        content.categoryIdentifier = Self.categoryID
        content.threadIdentifier = "therdia-daily"
        content.userInfo = ["dayKey": dayKey]
        content.sound = settings.mode.usesSound ? settings.tone.notificationSound : nil
        return content
    }

    private func registerActions() {
        let actions: [UNNotificationAction] = [
            UNNotificationAction(identifier: Self.actionDone, title: "Für heute beenden", options: []),
            UNNotificationAction(identifier: Self.action15, title: "In 15 Min. erinnern", options: []),
            UNNotificationAction(identifier: Self.action30, title: "In 30 Min. erinnern", options: []),
            UNNotificationAction(identifier: Self.action60, title: "In 1 Std. erinnern", options: [])
        ]
        let category = UNNotificationCategory(
            identifier: Self.categoryID, actions: actions,
            intentIdentifiers: [], options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    // UNUserNotificationCenterDelegate callbacks arrive outside of MainActor.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = response.actionIdentifier
        let day = response.notification.request.content.userInfo["dayKey"] as? String ?? ""
        Task { @MainActor [weak self] in
            await self?.handle(actionID: id, dayKey: day)
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Task { @MainActor [weak self] in
            guard let self else { completionHandler([]); return }
            let key = notification.request.content.userInfo["dayKey"] as? String ?? ""
            guard self.shouldNotify(dayKey: key) else { completionHandler([]); return }
            switch self.settings.mode {
            case .visual: completionHandler([.banner, .list])
            case .sound: completionHandler([.sound])
            case .both: completionHandler([.banner, .list, .sound])
            }
        }
    }

    private func shouldNotify(dayKey: String) -> Bool {
        dayKey == DiaryCodec.dateKey(.now) &&
        !recordedDays.contains(dayKey) &&
        !dismissedDays.contains(dayKey) &&
        settings.enabled
    }

    private func handle(actionID: String, dayKey: String) async {
        guard shouldNotify(dayKey: dayKey) else { await refresh(); return }

        switch actionID {
        case Self.actionDone, UNNotificationDismissActionIdentifier:
            dismissedDays.insert(dayKey)
            defaults.set(Array(dismissedDays), forKey: Self.dismissedKey)
            await refresh()
        case Self.action15, Self.action30, Self.action60:
            let minutes = actionID == Self.action15 ? 15 : actionID == Self.action30 ? 30 : 60
            guard let fireDate = Calendar.current.date(byAdding: .minute, value: minutes, to: .now),
                  DiaryCodec.dateKey(fireDate) == dayKey else {
                dismissedDays.insert(dayKey)
                defaults.set(Array(dismissedDays), forKey: Self.dismissedKey)
                await refresh()
                return
            }
            await refresh()
            let request = UNNotificationRequest(
                identifier: Self.requestPrefix + dayKey + "-snooze",
                content: reminderContent(for: dayKey),
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
            )
            try? await center.add(request)
        default:
            // Tapping the notification itself opens TherDia; it does not mark the day as done.
            break
        }
    }
}
