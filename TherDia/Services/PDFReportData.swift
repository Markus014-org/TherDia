import Foundation

enum PDFReportPart: String, CaseIterable, Identifiable, Hashable {
    case overview = "Überblick und Kennzahlen"
    case wellbeingTrend = "Verlauf des Tagesbefindens (Liniendiagramm)"
    case wellbeingPie = "Tagesbefinden (Kuchendiagramm)"
    case medication = "Basis-Medikamente"
    case emergency = "Notmedikation und Uhrzeiten"
    case school = "Schule und Unterricht"
    case therapy = "Therapie"
    case aggression = "Aggressives Verhalten"
    case activities = "Unternehmungen"
    case encounters = "Begegnungen"
    case screenTime = "Bildschirmzeit (Diagramm)"
    case dailyEntries = "Chronologische Tagebucheinträge"
    case legacyInjuries = "Ältere Verletzungseinträge"
    var id: String { rawValue }
}

enum PDFReportRange: String, CaseIterable, Identifiable {
    case week = "Letzte 7 Tage"
    case month = "Letzte 30 Tage"
    case three = "Letzte 3 Monate"
    case six = "Letzte 6 Monate"
    case twelve = "Letzte 12 Monate"
    case custom = "Eigener Zeitraum"

    var id: String { rawValue }
    var start: Date {
        let today = Calendar.current.startOfDay(for: .now)
        switch self {
        case .week: return Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
        case .month: return Calendar.current.date(byAdding: .day, value: -29, to: today) ?? today
        case .three: return Calendar.current.date(byAdding: .month, value: -3, to: today) ?? today
        case .six: return Calendar.current.date(byAdding: .month, value: -6, to: today) ?? today
        case .twelve: return Calendar.current.date(byAdding: .month, value: -12, to: today) ?? today
        case .custom: return today
        }
    }
}

struct PDFReportDay {
    let date: Date
    let record: DayRecord
    let draft: DayDraft
}

struct PDFReportOptions {
    let patientName: String
    let startDate: Date
    let endDate: Date
    let parts: Set<PDFReportPart>
    let showNames: Bool
    let showNotes: Bool
}

enum PDFReportData {
    static func selectedDays(in database: DiaryDatabase, from start: Date, through end: Date) -> [PDFReportDay] {
        let calendar = Calendar.current
        let from = calendar.startOfDay(for: start)
        let upper = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end)) ?? end
        return database.days.compactMap { key, day -> PDFReportDay? in
            guard let date = DiaryCodec.date(from: key), date >= from, date < upper else { return nil }
            return PDFReportDay(date: date, record: day, draft: day.draft())
        }.sorted { $0.date < $1.date }
    }
}
