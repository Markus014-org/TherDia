import Foundation

// Per-field revisions make it possible to merge changes on different days (or
// different questions on one day) without discarding either user's work.
enum DiaryField: String, CaseIterable, Codable, Identifiable {
    case wellbeing, baseMedication, rescueMedication, injuries, school, therapy, outing, people, peopleImpact, aggression, screenTime
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wellbeing: return "Tagesbefinden"
        case .baseMedication: return "Basis-Medikation"
        case .rescueMedication: return "Notmedikation"
        case .injuries: return "Verletzungen (ältere Einträge)"
        case .school: return "Schule"
        case .therapy: return "Therapie"
        case .outing: return "Unternehmung"
        case .people: return "Begegnungen"
        case .peopleImpact: return "Einfluss von Begegnungen"
        case .aggression: return "Aggressives Verhalten"
        case .screenTime: return "Bildschirmzeit"
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

// Reads both older single-medication entries and the new multi-medication format.
struct MedicationList: Codable, Equatable {
    var items: [Medication] = [Medication()]

    init(items: [Medication] = [Medication()]) { self.items = items }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let list = try? container.decode([Medication].self) {
            items = list
        } else {
            items = [try container.decode(Medication.self)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(items)
    }

    var summary: String {
        items.map(\.summary).filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

struct PeopleImpact: Codable, Equatable {
    var affectedWellbeing = false
    var effect: Wellbeing = .fairlyGood
    var notes = ""
}

struct RescueMedication: Codable, Equatable {
    var used: Bool = false
    var medication: Medication = Medication()
    // Optional local time as HH:mm; old Dropbox entries without time still decode.
    var time: String? = nil
    // nil = not assessed (including previously saved entries); true/false = explicit answer.
    var tirednessAfter: Bool? = nil
    // nil means "not evaluated". Older entries remain unchanged.
    var wellbeingAfter: Wellbeing? = nil
    var wellbeingNotes: String = ""

    init(used: Bool = false, medication: Medication = Medication(), time: String? = nil,
         wellbeingAfter: Wellbeing? = nil, wellbeingNotes: String = "",
         tirednessAfter: Bool? = nil) {
        self.used = used
        self.medication = medication
        self.time = time
        self.tirednessAfter = tirednessAfter
        self.wellbeingAfter = wellbeingAfter
        self.wellbeingNotes = wellbeingNotes
    }

    enum CodingKeys: String, CodingKey { case used, medication, time, tirednessAfter, wellbeingAfter, wellbeingNotes }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        used = try values.decodeIfPresent(Bool.self, forKey: .used) ?? false
        medication = try values.decodeIfPresent(Medication.self, forKey: .medication) ?? Medication()
        time = try values.decodeIfPresent(String.self, forKey: .time)
        tirednessAfter = try values.decodeIfPresent(Bool.self, forKey: .tirednessAfter)
        wellbeingAfter = try values.decodeIfPresent(Wellbeing.self, forKey: .wellbeingAfter)
        wellbeingNotes = try values.decodeIfPresent(String.self, forKey: .wellbeingNotes) ?? ""
    }

    var summary: String {
        guard used else { return "Nein" }
        var parts = [medication.summary]
        if let time { parts.append(time + " Uhr") }
        if let tirednessAfter { parts.append("Müdigkeit als Folge: " + (tirednessAfter ? "Ja" : "Nein")) }
        if let wellbeingAfter { parts.append("Wohlbefinden danach: " + wellbeingAfter.title) }
        if !wellbeingNotes.isEmpty { parts.append("Anmerkung: " + wellbeingNotes) }
        return parts.joined(separator: " · ")
    }
}

/// Kept separate from legacy 'injuries' records so earlier injury notes are never
/// silently reinterpreted as aggressive behavior.
struct AggressiveBehavior: Codable, Equatable {
    var happened = false
    var selfInjurious = false
    var selfDescription = ""
    var otherAggressive = false
    var otherDescription = ""

    var summary: String {
        guard happened else { return "Nein" }
        var details: [String] = []
        if selfInjurious { details.append("Selbstverletzend" + (selfDescription.isEmpty ? "" : ": " + selfDescription)) }
        if otherAggressive { details.append("Fremdaggressiv" + (otherDescription.isEmpty ? "" : ": " + otherDescription)) }
        return details.isEmpty ? "Ja" : details.joined(separator: " · ")
    }
}

struct ScreenTime: Codable, Equatable {
    // nil means not reported. Increments of one half-hour; 0 is a valid value.
    var halfHours: Int? = nil
    var hoursText: String {
        guard let halfHours else { return "Nicht erfasst" }
        let hours = halfHours / 2
        return "\(hours)" + (halfHours.isMultiple(of: 2) ? "" : ",5") + " Stunden"
    }
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
    var hasSchool: Bool = false
    var attended: Bool = false
    var online: Bool = false
    var inPerson: Bool = false
    var subjects: Subjects = .main

    enum CodingKeys: String, CodingKey { case hasSchool, attended, online, inPerson, subjects }
    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Existing records had no hasSchool question; preserve their meaning.
        hasSchool = try values.decodeIfPresent(Bool.self, forKey: .hasSchool) ?? true
        attended = try values.decodeIfPresent(Bool.self, forKey: .attended) ?? false
        online = try values.decodeIfPresent(Bool.self, forKey: .online) ?? false
        inPerson = try values.decodeIfPresent(Bool.self, forKey: .inPerson) ?? false
        subjects = try values.decodeIfPresent(Subjects.self, forKey: .subjects) ?? .main
    }
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
    var baseMedication = MedicationList()
    var rescueMedication = RescueMedication()
    var injuries = Injuries()
    var school = School()
    var therapy = Therapy()
    var outing = Outing()
    var people: [String] = []
    var peopleImpact = PeopleImpact()
    var aggression = AggressiveBehavior()
    var screenTime = ScreenTime()

    mutating func normalize() {
        baseMedication.items = baseMedication.items.map {
            Medication(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                       quantity: $0.quantity.trimmingCharacters(in: .whitespacesAndNewlines))
        }.filter { !$0.name.isEmpty || !$0.quantity.isEmpty }
        rescueMedication.medication.name = rescueMedication.medication.name.trimmingCharacters(in: .whitespacesAndNewlines)
        rescueMedication.medication.quantity = rescueMedication.medication.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        if let enteredTime = rescueMedication.time {
            let cleaned = enteredTime.trimmingCharacters(in: .whitespacesAndNewlines)
            rescueMedication.time = cleaned.isEmpty ? nil : cleaned
        }
        rescueMedication.wellbeingNotes = rescueMedication.wellbeingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rescueMedication.used {
            rescueMedication.medication = Medication()
            rescueMedication.time = nil
            rescueMedication.tirednessAfter = nil
            rescueMedication.wellbeingAfter = nil
            rescueMedication.wellbeingNotes = ""
        }
        injuries.details = injuries.details.trimmingCharacters(in: .whitespacesAndNewlines)
        if !injuries.happened { injuries.details = "" }
        if !aggression.happened {
            aggression = AggressiveBehavior()
        } else {
            aggression.selfDescription = aggression.selfDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            aggression.otherDescription = aggression.otherDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if !aggression.selfInjurious { aggression.selfDescription = "" }
            if !aggression.otherAggressive { aggression.otherDescription = "" }
        }
        if let value = screenTime.halfHours { screenTime.halfHours = min(48, max(0, value)) }
        if !school.hasSchool { school.attended = false }
        if !school.attended { school.online = false; school.inPerson = false }
        if !therapy.scheduled { therapy.participated = false }
        outing.activity = outing.activity.trimmingCharacters(in: .whitespacesAndNewlines)
        outing.notes = outing.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !outing.happened { outing = Outing() }
        if !outing.affectedWellbeing { outing.notes = "" }
        var seen: Set<String> = []
        people = people.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)).inserted }
        peopleImpact.notes = peopleImpact.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if people.isEmpty { peopleImpact = PeopleImpact() }
        else if !peopleImpact.affectedWellbeing { peopleImpact.notes = "" }
    }

    var validationError: String? {
        if baseMedication.items.isEmpty || baseMedication.items.contains(where: { $0.name.isEmpty || $0.quantity.isEmpty }) {
            return "Bitte mindestens ein Basis-Medikament mit Art und Menge angeben."
        }
        if school.hasSchool && school.attended && !school.online && !school.inPerson {
            return "Bitte bei einem Schultag mindestens Online oder Präsenz auswählen."
        }
        if rescueMedication.used && (rescueMedication.medication.name.isEmpty || rescueMedication.medication.quantity.isEmpty) {
            return "Bitte Art und Menge der Notmedikation angeben."
        }
        if rescueMedication.used, let entered = rescueMedication.time {
            let parts = entered.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  parts[0].count == 2, parts[1].count == 2,
                  parts[0].allSatisfy({ $0.isASCII && $0.isNumber }),
                  parts[1].allSatisfy({ $0.isASCII && $0.isNumber }),
                  let hour = Int(parts[0]), let minute = Int(parts[1]),
                  (0...23).contains(hour), (0...59).contains(minute) else {
                return "Bitte die Uhrzeit der Notmedikation als HH:mm eingeben (z. B. 08:30) oder das Feld leer lassen."
            }
        }
        if aggression.happened && !aggression.selfInjurious && !aggression.otherAggressive {
            return "Bitte bei aggressivem Verhalten Selbstverletzend und/oder Fremdaggressiv auswählen."
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
    func draft(fallbackBase: MedicationList = MedicationList(), fallbackRescue: Medication = Medication()) -> DayDraft {
        var draft = DayDraft()
        draft.wellbeing = DiaryCodec.decode(Wellbeing.self, field(.wellbeing)?.value) ?? .fairlyGood
        draft.baseMedication = DiaryCodec.decode(MedicationList.self, field(.baseMedication)?.value) ?? fallbackBase
        draft.rescueMedication = DiaryCodec.decode(RescueMedication.self, field(.rescueMedication)?.value) ?? RescueMedication(used: false, medication: fallbackRescue)
        if !draft.rescueMedication.used { draft.rescueMedication.medication = fallbackRescue }
        draft.injuries = DiaryCodec.decode(Injuries.self, field(.injuries)?.value) ?? Injuries()
        draft.school = DiaryCodec.decode(School.self, field(.school)?.value) ?? School()
        draft.therapy = DiaryCodec.decode(Therapy.self, field(.therapy)?.value) ?? Therapy()
        draft.outing = DiaryCodec.decode(Outing.self, field(.outing)?.value) ?? Outing()
        draft.people = DiaryCodec.decode([String].self, field(.people)?.value) ?? []
        draft.peopleImpact = DiaryCodec.decode(PeopleImpact.self, field(.peopleImpact)?.value) ?? PeopleImpact()
        draft.aggression = DiaryCodec.decode(AggressiveBehavior.self, field(.aggression)?.value) ?? AggressiveBehavior()
        draft.screenTime = DiaryCodec.decode(ScreenTime.self, field(.screenTime)?.value) ?? ScreenTime()
        return draft
    }
}

extension DayDraft {
    func serializedFields() throws -> [DiaryField: String] {
        [
            .wellbeing: try DiaryCodec.encode(wellbeing),
            .baseMedication: try DiaryCodec.encode(baseMedication),
            .rescueMedication: try DiaryCodec.encode(rescueMedication),
            // Legacy .injuries is read-only: do not create or rewrite old notes as aggression.
            .aggression: try DiaryCodec.encode(aggression),
            .screenTime: try DiaryCodec.encode(screenTime),
            .school: try DiaryCodec.encode(school),
            .therapy: try DiaryCodec.encode(therapy),
            .outing: try DiaryCodec.encode(outing),
            .people: try DiaryCodec.encode(people),
            .peopleImpact: try DiaryCodec.encode(peopleImpact)
        ]
    }
}

enum FieldDescription {
    static func describe(_ field: DiaryField, json: String) -> String {
        switch field {
        case .wellbeing:
            return DiaryCodec.decode(Wellbeing.self, json)?.title ?? "Unbekannt"
        case .baseMedication:
            return DiaryCodec.decode(MedicationList.self, json)?.summary.nilIfEmpty ?? "Keine Angabe"
        case .rescueMedication:
            guard let value = DiaryCodec.decode(RescueMedication.self, json) else { return "Unbekannt" }
            return value.used ? "Ja · \(value.summary)" : "Nein"
        case .injuries:
            guard let value = DiaryCodec.decode(Injuries.self, json) else { return "Unbekannt" }
            return value.happened ? "Ja · \(value.details)" : "Nein"
        case .school:
            guard let value = DiaryCodec.decode(School.self, json) else { return "Unbekannt" }
            if !value.hasSchool { return "Kein Schultag" }
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
        case .peopleImpact:
            guard let value = DiaryCodec.decode(PeopleImpact.self, json) else { return "Unbekannt" }
            return value.affectedWellbeing ? "Einfluss: \(value.effect.title)" + (value.notes.isEmpty ? "" : " · \(value.notes)") : "Kein Einfluss"
        case .aggression:
            return DiaryCodec.decode(AggressiveBehavior.self, json)?.summary ?? "Unbekannt"
        case .screenTime:
            return DiaryCodec.decode(ScreenTime.self, json)?.hoursText ?? "Nicht erfasst"
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
