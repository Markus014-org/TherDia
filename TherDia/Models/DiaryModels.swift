import Foundation

// Per-field revisions make it possible to merge changes on different days (or
// different questions on one day) without discarding either user's work.
enum DiaryField: String, CaseIterable, Codable, Identifiable {
    case wellbeing, baseMedication, rescueMedication, injuries, school, therapy, outing, people
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wellbeing: return "Tagesbefinden"
        case .baseMedication: return "Basis-Medikation"
        case .rescueMedication: return "Notmedikation"
        case .injuries: return "Verletzungen"
        case .school: return "Schule"
        case .therapy: return "Therapie"
        case .outing: return "Unternehmung"
        case .people: return "Begegnungen"
        }
    }
}

enum Wellbeing: Int, Codable, CaseIterable, Identifiable {
    case good = 0, fairlyGood, fairlyBad, bad, veryBad
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .good: return "Gut"
        case .fairlyGood: return "Mittelgut"
        case .fairlyBad: return "Mittelschlecht"
        case .bad: return "Schlecht"
        case .veryBad: return "Extrem schlecht"
        }
    }
    var score: Int { 5 - rawValue }
}

struct Medication: Codable, Equatable {
    var name: String = ""
    var quantity: String = ""
    var summary: String {
        [name, quantity].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " · ")
    }
}

struct RescueMedication: Codable, Equatable {
    var used: Bool = false
    var medication: Medication = Medication()
}

struct Injuries: Codable, Equatable {
    var happened: Bool = false
    var details: String = ""
}

enum Subjects: String, Codable, CaseIterable, Identifiable {
    case main = "Hauptfach"
    case mainAndOthers = "Hauptfach und Nebenfächer"
    case others = "Nur Nebenfächer"
    var id: String { rawValue }
}

struct School: Codable, Equatable {
    var attended: Bool = false
    var online: Bool = false
    var inPerson: Bool = false
    var subjects: Subjects = .main
}

enum TherapyType: String, Codable, CaseIterable, Identifiable {
    case kjp = "KJP", ass = "ASS"
    var id: String { rawValue }
}

struct Therapy: Codable, Equatable {
    var scheduled: Bool = false
    var kind: TherapyType = .kjp
    var participated: Bool = false
}

struct Outing: Codable, Equatable {
    var happened: Bool = false
    var activity: String = ""
    var affectedWellbeing: Bool = false
    var effect: Wellbeing = .fairlyGood
    var notes: String = ""
}

struct DayDraft: Equatable {
    var wellbeing: Wellbeing = .fairlyGood
    var baseMedication = Medication()
    var rescueMedication = RescueMedication()
    var injuries = Injuries()
    var school = School()
    var therapy = Therapy()
    var outing = Outing()
    var people: [String] = []

    mutating func normalize() {
        baseMedication.name = baseMedication.name.trimmingCharacters(in: .whitespacesAndNewlines)
        baseMedication.quantity = baseMedication.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        rescueMedication.medication.name = rescueMedication.medication.name.trimmingCharacters(in: .whitespacesAndNewlines)
        rescueMedication.medication.quantity = rescueMedication.medication.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rescueMedication.used { rescueMedication.medication = Medication() }
        injuries.details = injuries.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !injuries.happened { injuries.details = "" }
        if !school.attended { school.online = false; school.inPerson = false }
        if !therapy.scheduled { therapy.participated = false }
        outing.activity = outing.activity.trimmingCharacters(in: .whitespacesAndNewlines)
        outing.notes = outing.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !outing.happened { outing = Outing() }
        if !outing.affectedWellbeing { outing.notes = "" }
        var seen: Set<String> = []
        people = people.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted }
    }

    var validationError: String? {
        if baseMedication.name.isEmpty || baseMedication.quantity.isEmpty {
            return "Bitte Art und Menge der Basis-Medikation angeben. Die Standardwerte können in den Einstellungen hinterlegt werden."
        }
        if school.attended && !school.online && !school.inPerson {
            return "Bitte bei einem Schultag mindestens Online oder Präsenz auswählen."
        }
        if rescueMedication.used && (rescueMedication.medication.name.isEmpty || rescueMedication.medication.quantity.isEmpty) {
            return "Bitte Art und Menge der Notmedikation angeben."
        }
        if injuries.happened && injuries.details.isEmpty {
            return "Bitte die Verletzung beschreiben."
        }
        if outing.happened && outing.activity.isEmpty {
            return "Bitte die Unternehmung beschreiben."
        }
        return nil
    }
}

struct FieldRevision: Codable, Equatable {
    var value: String          // JSON-encoded value of the relevant field
    var timestamp: Date       // absolute creation time of this change
    var deviceID: String
    var changeID: String
}

struct DayRecord: Codable, Equatable {
    var fields: [String: FieldRevision] = [:]
    func field(_ key: DiaryField) -> FieldRevision? { fields[key.rawValue] }
}

struct DiaryDatabase: Codable, Equatable {
    var schemaVersion = 1
    var days: [String: DayRecord] = [:]
    var isEmpty: Bool { days.values.allSatisfy { $0.fields.isEmpty } }
}

enum DiaryCodec {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }()
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }()

    static func encode<T: Encodable>(_ value: T) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self)
    }
    static func decode<T: Decodable>(_ type: T.Type, _ value: String?) -> T? {
        guard let value, let data = value.data(using: .utf8) else { return nil }
        return try? decoder.decode(type, from: data)
    }
    static func dateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    static func date(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: key)
    }
}

extension DayRecord {
    func draft(fallbackBase: Medication = Medication(), fallbackRescue: Medication = Medication()) -> DayDraft {
        var draft = DayDraft()
        draft.wellbeing = DiaryCodec.decode(Wellbeing.self, field(.wellbeing)?.value) ?? .fairlyGood
        draft.baseMedication = DiaryCodec.decode(Medication.self, field(.baseMedication)?.value) ?? fallbackBase
        draft.rescueMedication = DiaryCodec.decode(RescueMedication.self, field(.rescueMedication)?.value) ?? RescueMedication(used: false, medication: fallbackRescue)
        if !draft.rescueMedication.used { draft.rescueMedication.medication = fallbackRescue }
        draft.injuries = DiaryCodec.decode(Injuries.self, field(.injuries)?.value) ?? Injuries()
        draft.school = DiaryCodec.decode(School.self, field(.school)?.value) ?? School()
        draft.therapy = DiaryCodec.decode(Therapy.self, field(.therapy)?.value) ?? Therapy()
        draft.outing = DiaryCodec.decode(Outing.self, field(.outing)?.value) ?? Outing()
        draft.people = DiaryCodec.decode([String].self, field(.people)?.value) ?? []
        return draft
    }
}

extension DayDraft {
    func serializedFields() throws -> [DiaryField: String] {
        [
            .wellbeing: try DiaryCodec.encode(wellbeing),
            .baseMedication: try DiaryCodec.encode(baseMedication),
            .rescueMedication: try DiaryCodec.encode(rescueMedication),
            .injuries: try DiaryCodec.encode(injuries),
            .school: try DiaryCodec.encode(school),
            .therapy: try DiaryCodec.encode(therapy),
            .outing: try DiaryCodec.encode(outing),
            .people: try DiaryCodec.encode(people)
        ]
    }
}

enum FieldDescription {
    static func describe(_ field: DiaryField, json: String) -> String {
        switch field {
        case .wellbeing:
            return DiaryCodec.decode(Wellbeing.self, json)?.title ?? "Unbekannt"
        case .baseMedication:
            return DiaryCodec.decode(Medication.self, json)?.summary.nilIfEmpty ?? "Keine Angabe"
        case .rescueMedication:
            guard let value = DiaryCodec.decode(RescueMedication.self, json) else { return "Unbekannt" }
            return value.used ? "Ja · \(value.medication.summary)" : "Nein"
        case .injuries:
            guard let value = DiaryCodec.decode(Injuries.self, json) else { return "Unbekannt" }
            return value.happened ? "Ja · \(value.details)" : "Nein"
        case .school:
            guard let value = DiaryCodec.decode(School.self, json) else { return "Unbekannt" }
            if !value.attended { return "Nicht am Unterricht teilgenommen" }
            var types: [String] = []
            if value.online { types.append("online") }
            if value.inPerson { types.append("in Präsenz") }
            return "Teilnahme \(types.joined(separator: " und ")) · \(value.subjects.rawValue)"
        case .therapy:
            guard let value = DiaryCodec.decode(Therapy.self, json) else { return "Unbekannt" }
            return value.scheduled ? "\(value.kind.rawValue) · \(value.participated ? "Teilgenommen" : "Nicht teilgenommen")" : "Keine Therapie"
        case .outing:
            guard let value = DiaryCodec.decode(Outing.self, json) else { return "Unbekannt" }
            if !value.happened { return "Keine Unternehmung" }
            return value.activity + (value.affectedWellbeing ? " · Einfluss: \(value.effect.title)" : " · Kein Einfluss")
                + (value.notes.isEmpty ? "" : " · \(value.notes)")
        case .people:
            return DiaryCodec.decode([String].self, json)?.joined(separator: ", ").nilIfEmpty ?? "Keine Begegnungen"
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
