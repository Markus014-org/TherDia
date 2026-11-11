import Foundation
import UserNotifications
import Combine

/// Pure calendar-based schedule: one initial daily alarm, followed by unacknowledged
/// reminders every 30 minutes on the same local calendar day.
/// iOS owns delivery; there are no background timers or silent fetch dependencies.
enum ReminderSchedule {
    static let repeatInterval: TimeInterval = 30 * 60

    static func dates(on day: Date, hour: Int, minute: Int,
                      now: Date, snoozeUntil: Date? = nil,
                      calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        var parts = calendar.dateComponents([.year, .month, .day], from: start)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        guard var next = calendar.date(from: parts) else { return [] }
        if let snoozeUntil, snoozeUntil >= start && snoozeUntil < end {
            next = snoozeUntil
        }
        var dates: [Date] = []
        // 48 intervals are enough for one local day. The extra bound allows a
        // calendar day in a DST transition without unbounded scheduling.
        for _ in 0..<52 {
            if next >= end { break }
            if next > now { dates.append(next) }
            next = next.addingTimeInterval(repeatInterval)
        }
        return dates
    }
}

/// Identifies the reminder that was explicitly opened from a notification.
struct ReminderPrompt: Identifiable, Equatable {
    let dayKey: String
    var id: String { dayKey }
}

@MainActor
final class ReminderManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderManager()

    static let categoryID = "THERDIA_DAILY_REMINDER"
    static let actionDone = "THERDIA_DONE_TODAY"
    static let action15 = "THERDIA_SNOOZE_15"
    static let action30 = "THERDIA_SNOOZE_30"
    static let action60 = "THERDIA_SNOOZE_60"
    static let requestPrefix = "therdia-reminder-"
    private static let settingsKey = "therdia-reminder-settings"
    private static let dismissedKey = "therdia-reminder-dismissed"
    private static let recordedKey = "therdia-reminder-recorded-days"
    private static let snoozesKey = "therdia-reminder-snooze-until"

    @Published private(set) var settings: ReminderSettings
    @Published private(set) var authorizationMessage = "Noch nicht überprüft"
    @Published private(set) var activeReminderPrompt: ReminderPrompt?

    private var dismissedDays: Set<String>
    private var recordedDays: Set<String>
    private var snoozes: [String: Date]
    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private var configurationInProgress = false
    // Refresh is serialized even when bootstrap, foreground and Dropbox finish together.
    private var refreshInProgress = false
    private var refreshQueued = false

    private override init() {
        let stored = UserDefaults.standard
        if let data = stored.data(forKey: Self.settingsKey),
           let decoded = try? JSONDecoder().decode(ReminderSettings.self, from: data) {
            settings = decoded
        } else {
            settings = ReminderSettings()
        }
        dismissedDays = Set(stored.stringArray(forKey: Self.dismissedKey) ?? [])
        recordedDays = Set(stored.stringArray(forKey: Self.recordedKey) ?? [])
        snoozes = stored.dictionary(forKey: Self.snoozesKey) as? [String: Date] ?? [:]
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
                authorizationMessage = "Mitteilungen konnten nicht aktiviert werden: \(error.localizedDescription)"
                return
            }
        }
        settings = updated
        if !updated.enabled { activeReminderPrompt = nil }
        if let bytes = try? JSONEncoder().encode(updated) {
            defaults.set(bytes, forKey: Self.settingsKey)
        }
        // Changing the daily time resets the snooze choice for today.
        snoozes.removeAll()
        saveSnoozes()
        await refresh()
    }

    func synchronize(database: DiaryDatabase) async {
        recordedDays = Set(database.days.compactMap { key, record in
            record.fields.isEmpty ? nil : key
        })
        defaults.set(Array(recordedDays), forKey: Self.recordedKey)
        if let prompt = activeReminderPrompt, recordedDays.contains(prompt.dayKey) {
            activeReminderPrompt = nil
        }
        await refresh()
    }

    func markSaved(date: Date) async {
        let dayKey = DiaryCodec.dateKey(date)
        if activeReminderPrompt?.dayKey == dayKey {
            activeReminderPrompt = nil
        }
        recordedDays.insert(dayKey)
        snoozes.removeValue(forKey: dayKey)
        defaults.set(Array(recordedDays), forKey: Self.recordedKey)
        saveSnoozes()
        // The notification may already be visible. Only saving or explicit
        // 'For today end' is allowed to clear delivered notifications.
        let delivered = await center.deliveredNotifications()
        center.removeDeliveredNotifications(withIdentifiers:
            delivered.filter { ($0.request.content.userInfo["dayKey"] as? String) == dayKey }
                .map { $0.request.identifier }
        )
        await refresh()
    }

    /// Dismissing the in-app sheet does not dismiss or snooze the alarm.
    /// The default 30-minute repeat schedule remains active.
    func closeReminderPrompt() {
        activeReminderPrompt = nil
    }

    /// Called when an in-app choice is explicitly made. Unlike merely opening
    /// TherDia, this modifies the day's scheduled reminder notifications.
    func selectReminderAction(_ actionID: String, for dayKey: String) async {
        guard activeReminderPrompt?.dayKey == dayKey else { return }
        guard shouldNotify(dayKey: dayKey) else {
            activeReminderPrompt = nil
            return
        }
        // Dismiss first so it cannot race an incoming foreground refresh.
        activeReminderPrompt = nil
        await handle(actionID: actionID, dayKey: dayKey)
    }

    func refresh() async {
        if refreshInProgress {
            refreshQueued = true
            return
        }
        refreshInProgress = true
        repeat {
            refreshQueued = false
            await rebuildSchedule()
        } while refreshQueued
        refreshInProgress = false
    }

    private func rebuildSchedule() async {
        registerActions()
        let now = Date.now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        dismissedDays = Set(dismissedDays.filter { key in
            guard let date = DiaryCodec.date(from: key) else { return false }
            return date >= today
        })
        snoozes = snoozes.filter { key, date in
            guard let dayDate = DiaryCodec.date(from: key),
                  let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayDate) else { return false }
            return dayDate >= today && date < tomorrow &&
                !dismissedDays.contains(key) && !recordedDays.contains(key)
        }
        defaults.set(Array(dismissedDays), forKey: Self.dismissedKey)
        saveSnoozes()

        // Clear only pending reminders. Delivered banners/list notifications
        // are NEVER dismissed merely because TherDia was opened.
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers:
            pending.filter { $0.identifier.hasPrefix(Self.requestPrefix) }.map(\.identifier)
        )

        let status = await center.notificationSettings()
        switch status.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorizationMessage = "Mitteilungen erlaubt"
        case .denied:
            authorizationMessage = "Mitteilungen in den iOS-Einstellungen deaktiviert"
        case .notDetermined:
            authorizationMessage = "Erlaubnis noch nicht erteilt"
        @unknown default:
            authorizationMessage = "Mitteilungsstatus unbekannt"
        }
        let allowed: Bool
        switch status.authorizationStatus {
        case .authorized, .provisional, .ephemeral: allowed = true
        default: allowed = false
        }
        guard settings.enabled && allowed else { return }

        // iOS generally retains up to 64 pending local notifications. Reserve
        // headroom and prioritise today's 30-minute reminder sequence.
        var slots = 60
        for offset in 0..<60 where slots > 0 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let dayKey = DiaryCodec.dateKey(day)
            guard !recordedDays.contains(dayKey), !dismissedDays.contains(dayKey) else { continue }

            var dates = ReminderSchedule.dates(
                on: day, hour: settings.hour, minute: settings.minute,
                now: now, snoozeUntil: snoozes[dayKey], calendar: calendar
            )
            // Future days get one initial alarm; once the app is active on
            // that date, today's full repeat series is scheduled.
            if offset > 0 { dates = Array(dates.prefix(1)) }
            for (index, date) in dates.prefix(slots).enumerated() {
                let content = reminderContent(for: dayKey)
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute, .second], from: date
                    ),
                    repeats: false
                )
                let identifier = Self.requestPrefix + dayKey + "-repeat-" + String(index)
                do {
                    try await center.add(UNNotificationRequest(
                        identifier: identifier, content: content, trigger: trigger
                    ))
                    slots -= 1
                } catch {
                    authorizationMessage = "Erinnerung konnte nicht geplant werden: \(error.localizedDescription)"
                }
            }
        }
    }

    private func reminderContent(for dayKey: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "TherDia · Tagebuch-Erinnerung"
        content.body = "Für heute ist noch kein Tagebucheintrag gespeichert. Bitte den Tag dokumentieren oder die Erinnerung für heute beenden."
        content.categoryIdentifier = Self.categoryID
        content.threadIdentifier = "therdia-daily"
        content.userInfo = ["dayKey": dayKey]
        content.sound = settings.mode.usesSound ? settings.tone.notificationSound : nil
        return content
    }

    private func registerActions() {
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.categoryID,
                actions: [
                    UNNotificationAction(identifier: Self.actionDone, title: "Für heute beenden", options: []),
                    UNNotificationAction(identifier: Self.action15, title: "In 15 Min. erinnern", options: []),
                    UNNotificationAction(identifier: Self.action30, title: "In 30 Min. erinnern", options: []),
                    UNNotificationAction(identifier: Self.action60, title: "In 1 Std. erinnern", options: [])
                ],
                intentIdentifiers: [],
                options: [.customDismissAction]
            )
        ])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        let dayKey = response.notification.request.content.userInfo["dayKey"] as? String ?? ""
        Task { @MainActor [weak self] in
            await self?.handle(actionID: action, dayKey: dayKey)
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
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
            settings.enabled &&
            !recordedDays.contains(dayKey) &&
            !dismissedDays.contains(dayKey)
    }

    private func handle(actionID: String, dayKey: String) async {
        // Opening the app or swiping away a banner is NOT acknowledgement.
        // In particular, UNNotificationDismissActionIdentifier does not stop
        // further reminders. Only an explicit Done action can do that.
        guard shouldNotify(dayKey: dayKey) else { return }
        switch actionID {
        case UNNotificationDefaultActionIdentifier:
            // The user tapped the lock-screen banner itself, rather than an
            // expanded action. iOS launches TherDia; show choices *inside*
            // the app. Do not change the reminder schedule on this tap.
            activeReminderPrompt = ReminderPrompt(dayKey: dayKey)
        case Self.actionDone:
            activeReminderPrompt = nil
            dismissedDays.insert(dayKey)
            snoozes.removeValue(forKey: dayKey)
            defaults.set(Array(dismissedDays), forKey: Self.dismissedKey)
            saveSnoozes()
            let delivered = await center.deliveredNotifications()
            center.removeDeliveredNotifications(withIdentifiers:
                delivered.filter { ($0.request.content.userInfo["dayKey"] as? String) == dayKey }
                    .map { $0.request.identifier }
            )
            await refresh()
        case Self.action15, Self.action30, Self.action60:
            activeReminderPrompt = nil
            let minutes = actionID == Self.action15 ? 15 : actionID == Self.action30 ? 30 : 60
            guard let target = Calendar.current.date(byAdding: .minute, value: minutes, to: .now),
                  DiaryCodec.dateKey(target) == dayKey else {
                // Don't schedule a "yesterday" notification after midnight.
                return
            }
            snoozes[dayKey] = target
            saveSnoozes()
            await refresh()
        default:
            // Swiping away the notification is not acknowledgement.
            return
        }
    }

    private func saveSnoozes() {
        defaults.set(snoozes, forKey: Self.snoozesKey)
    }
}
