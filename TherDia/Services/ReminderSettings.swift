import Foundation
import UserNotifications

enum ReminderMode: String, Codable, CaseIterable, Identifiable {
    case visual = "Nur optisch"
    case sound = "Nur akustisch"
    case both = "Optisch und akustisch"
    var id: String { rawValue }
    var usesSound: Bool { self != .visual }
}

enum ReminderTone: String, Codable, CaseIterable, Identifiable {
    case system = "iOS-Standardton"
    case gentle = "Sanfter Klang"
    case bell = "Heller Glockenton"
    var id: String { rawValue }

    var soundName: String? {
        switch self {
        case .system: return nil
        case .gentle: return "TherDiaGentle.wav"
        case .bell: return "TherDiaBell.wav"
        }
    }

    var notificationSound: UNNotificationSound {
        if let soundName {
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
        }
        return .default
    }
}

struct ReminderSettings: Codable, Equatable {
    var enabled = false
    var hour = 20
    var minute = 0
    var mode: ReminderMode = .both
    var tone: ReminderTone = .gentle

    var timeLabel: String { String(format: "%02d:%02d", hour, minute) }

    var wheelValue: Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        parts.hour = hour
        parts.minute = minute
        return Calendar.current.date(from: parts) ?? .now
    }

    mutating func setWheelValue(_ value: Date) {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
        hour = parts.hour ?? hour
        minute = parts.minute ?? minute
    }
}
