import SwiftUI
import Charts

private struct ReportDay: Identifiable {
    let key: String
    let date: Date
    let draft: DayDraft
    var id: String { key }
}

private enum ReportPeriod: String, CaseIterable, Identifiable {
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
        case .week: return Calendar.current.date(byAdding: .day, value: -6, to: today)!
        case .month: return Calendar.current.date(byAdding: .day, value: -29, to: today)!
        case .three: return Calendar.current.date(byAdding: .month, value: -3, to: today)!
        case .six: return Calendar.current.date(byAdding: .month, value: -6, to: today)!
        case .twelve: return Calendar.current.date(byAdding: .month, value: -12, to: today)!
        case .custom: return today
        }
    }
}

private struct DistributionItem: Identifiable {
    let name: String
    let count: Int
    let color: Color
    var id: String { name }
}

private struct DistributionCard: View {
    let title: String
    let items: [DistributionItem]
    var total: Int { items.reduce(0) { $0 + $1.count } }
    var nonzero: [DistributionItem] { items.filter { $0.count > 0 } }

    var body: some View {
        SectionCard(title, subtitle: "Bezogen auf \(total) erfasste Angaben") {
            if total == 0 { Text("Keine passenden Daten").foregroundStyle(.secondary) }
            else {
                Chart(nonzero) { segment in
                    SectorMark(angle: .value("Anzahl", segment.count), innerRadius: .ratio(0.58), angularInset: 1)
                        .foregroundStyle(segment.color)
                }
                .frame(height: 170)
                .accessibilityLabel("Kuchendiagramm: \(title)")
                ForEach(items) { segment in
                    HStack(spacing: 9) {
                        Circle().fill(segment.color).frame(width: 10, height: 10)
                        Text(segment.name).font(.subheadline).lineLimit(2)
                        Spacer(minLength: 5)
                        Text("\(segment.count) · \(Int((Double(segment.count) / Double(total) * 100).rounded())) %")
                            .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct ReportsView: View {
    @ObservedObject var model: AppModel
    @State private var period: ReportPeriod = .month
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -29, to: .now) ?? .now
    @State private var endDate = Date()
    @State private var selectedQuality = -1
    @State private var emergencyFilter = "Alle"
    @State private var schoolFilter = "Alle"
    @State private var schoolDayFilter = "Alle"
    @State private var selectedPerson = "Alle"
    @State private var selectedTherapy = "Alle"
    @State private var selectedInjury = "Alle"
    @State private var selectedOuting = "Alle"
    @State private var selectedMedication = "Alle"
    @State private var visibleFields = Set(DiaryField.allCases)
    @State private var showStats = true

    private var allDays: [ReportDay] {
        model.database.days.compactMap { key, record in
            guard let date = DiaryCodec.date(from: key) else { return nil }
            return ReportDay(key: key, date: date, draft: record.draft())
        }.sorted { $0.date > $1.date }
    }

    private var names: [String] {
        Array(Set(allDays.flatMap { $0.draft.people })).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var medicationNames: [String] {
        Array(Set(allDays.flatMap { $0.draft.baseMedication.items.compactMap { $0.name.nilIfBlank } })).sorted()
    }

    private var filtered: [ReportDay] {
        let from = Calendar.current.startOfDay(for: period == .custom ? startDate : period.start)
        let to = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: period == .custom ? endDate : .now)) ?? .now
        return allDays.filter { day in
            guard day.date >= from && day.date < to else { return false }
            if selectedQuality >= 0 && day.draft.wellbeing.rawValue != selectedQuality { return false }
            if emergencyFilter == "Ja" && !day.draft.rescueMedication.used { return false }
            if emergencyFilter == "Nein" && day.draft.rescueMedication.used { return false }
            if schoolDayFilter == "Ja" && !day.draft.school.hasSchool { return false }
            if schoolDayFilter == "Nein" && day.draft.school.hasSchool { return false }
            if schoolFilter == "Ja" && !day.draft.school.attended { return false }
            if schoolFilter == "Nein" && day.draft.school.attended { return false }
            if selectedPerson != "Alle" && !day.draft.people.contains(where: { $0 == selectedPerson }) { return false }
            if selectedTherapy == "Keine" && day.draft.therapy.scheduled { return false }
            if selectedTherapy == "KJP" && (!day.draft.therapy.scheduled || day.draft.therapy.kind != .kjp) { return false }
            if selectedTherapy == "ASS" && (!day.draft.therapy.scheduled || day.draft.therapy.kind != .ass) { return false }
            if selectedInjury == "Ja" && !day.draft.injuries.happened { return false }
            if selectedInjury == "Nein" && day.draft.injuries.happened { return false }
            if selectedOuting == "Ja" && !day.draft.outing.happened { return false }
            if selectedOuting == "Nein" && day.draft.outing.happened { return false }
            if selectedMedication != "Alle" && !day.draft.baseMedication.items.contains(where: { $0.name == selectedMedication }) { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dein Überblick").font(.system(size: 29, weight: .bold, design: .rounded))
                            .foregroundStyle(TherDiaTheme.navy)
                        Text("Trends sehen, Zusammenhänge entdecken.").foregroundStyle(.secondary)
                    }.padding(.top, 8)
                    SectionCard("Berichtszeitraum") {
                        Picker("Zeitraum", selection: $period) {
                            ForEach(ReportPeriod.allCases) { option in Text(option.rawValue).tag(option) }
                        }.pickerStyle(.menu)
                        if period == .custom {
                            DatePicker("Von", selection: $startDate, displayedComponents: .date)
                            DatePicker("Bis", selection: $endDate, displayedComponents: .date)
                            if startDate > endDate {
                                Text("Das Startdatum muss vor dem Enddatum liegen.")
                                    .foregroundStyle(.red).font(.footnote)
                            }
                        }
                    }
                    SectionCard("Filter", subtitle: "Alle Filter wirken auch auf die Statistiken") {
                        Picker("Befinden", selection: $selectedQuality) {
                            Text("Alle").tag(-1)
                            ForEach(Wellbeing.allCases) { value in
                                Text(value.title).tag(value.rawValue)
                            }
                        }
                        Picker("Notmedikation", selection: $emergencyFilter) {
                            Text("Alle").tag("Alle"); Text("Ja").tag("Ja"); Text("Nein").tag("Nein")
                        }
                        Picker("Schultag", selection: $schoolDayFilter) {
                            Text("Alle").tag("Alle"); Text("Ja").tag("Ja"); Text("Nein").tag("Nein")
                        }
                        Picker("Unterrichtsteilnahme", selection: $schoolFilter) {
                            Text("Alle").tag("Alle"); Text("Ja").tag("Ja"); Text("Nein").tag("Nein")
                        }
                        Picker("Therapie", selection: $selectedTherapy) {
                            Text("Alle").tag("Alle"); Text("KJP").tag("KJP")
                            Text("ASS").tag("ASS"); Text("Keine").tag("Keine")
                        }
                        Picker("Verletzungen", selection: $selectedInjury) {
                            Text("Alle").tag("Alle"); Text("Ja").tag("Ja"); Text("Nein").tag("Nein")
                        }
                        Picker("Unternehmungen", selection: $selectedOuting) {
                            Text("Alle").tag("Alle"); Text("Ja").tag("Ja"); Text("Nein").tag("Nein")
                        }
                        Picker("Basis-Medikament", selection: $selectedMedication) {
                            Text("Alle").tag("Alle")
                            ForEach(medicationNames, id: \.self) { name in Text(name).tag(name) }
                        }
                        Picker("Begegnung mit", selection: $selectedPerson) {
                            Text("Alle").tag("Alle")
                            ForEach(names, id: \.self) { name in Text(name).tag(name) }
                        }
                        Button("Filter zurücksetzen") {
                            selectedQuality = -1; emergencyFilter = "Alle"; schoolFilter = "Alle"; schoolDayFilter = "Alle"
                            selectedTherapy = "Alle"; selectedInjury = "Alle"; selectedOuting = "Alle"
                            selectedPerson = "Alle"; selectedMedication = "Alle"
                        }.font(.footnote)
                    }

                    SectionCard("\(filtered.count) dokumentierte Tage") {
                        Picker("Ansicht", selection: $showStats) {
                            Text("Statistik").tag(true)
                            Text("Alle Einträge").tag(false)
                        }.pickerStyle(.segmented)
                        Text("Prozentangaben beziehen sich auf Tage mit einem Eintrag, nicht auf alle Kalendertage im Zeitraum.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if showStats { statistics }
                    else {
                        SectionCard("Angezeigte Kategorien") {
                            ForEach(DiaryField.allCases.filter { $0 != .wellbeing }) { field in
                                Toggle(field.title, isOn: Binding(
                                    get: { visibleFields.contains(field) },
                                    set: { show in
                                        if show { visibleFields.insert(field) }
                                        else { visibleFields.remove(field) }
                                    }
                                ))
                            }
                        }
                        chronological
                    }
                }.padding(16)
            }
            .background(TherDiaTheme.canvas)
            .navigationTitle("Berichte")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder private var chronological: some View {
        if filtered.isEmpty {
            ContentUnavailableView("Keine Einträge", systemImage: "calendar.badge.exclamationmark",
                                   description: Text("Zeitraum oder Filter anpassen."))
        } else {
            ForEach(filtered) { day in
                SectionCard(day.date.diaryHeading) {
                    HStack(spacing: 8) {
                        QualityDot(quality: day.draft.wellbeing, size: 20)
                        if day.draft.rescueMedication.used {
                            Circle().fill(.blue).frame(width: 12, height: 12)
                                .accessibilityLabel("Notmedikation")
                        }
                    }
                    ForEach(DiaryField.allCases.filter { visibleFields.contains($0) && $0 != .wellbeing }) { field in
                        if let value = model.database.days[day.key]?.field(field)?.value {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(field.title).font(.caption).foregroundStyle(.secondary)
                                Text(FieldDescription.describe(field, json: value)).font(.subheadline)
                            }
                            if field != .people { Divider().opacity(0.4) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var statistics: some View {
        if filtered.isEmpty {
            ContentUnavailableView("Keine Daten für diese Auswahl", systemImage: "chart.pie",
                                   description: Text("Einträge erfassen oder Filter ändern."))
        } else {
            let count = filtered.count
            let rescueDays = filtered.filter { $0.draft.rescueMedication.used }.count
            let schoolDays = filtered.filter { $0.draft.school.hasSchool }.count
            let schoolAttended = filtered.filter { $0.draft.school.hasSchool && $0.draft.school.attended }.count
            let therapyDays = filtered.filter { $0.draft.therapy.scheduled }.count
            let outings = filtered.filter { $0.draft.outing.happened }.count
            let injuries = filtered.filter { $0.draft.injuries.happened }.count
            let contacts = filtered.filter { !$0.draft.people.isEmpty }.count

            SectionCard("Kennzahlen") {
                HStack {
                    numberMetric("Notmedikation", value: rescueDays, denominator: count)
                    Spacer()
                    numberMetric("Schultage", value: schoolDays, denominator: count)
                }
                Divider()
                HStack {
                    numberMetric("Therapietage", value: therapyDays, denominator: count)
                    Spacer()
                    numberMetric("Begegnungen", value: contacts, denominator: count)
                }
            }

            SectionCard("Verlauf des Befindens", subtitle: "5 = gut · 1 = extrem schlecht") {
                Chart(filtered.sorted { $0.date < $1.date }) { item in
                    LineMark(x: .value("Tag", item.date), y: .value("Wert", item.draft.wellbeing.score))
                        .interpolationMethod(.linear)
                        .foregroundStyle(TherDiaTheme.accent)
                    PointMark(x: .value("Tag", item.date), y: .value("Wert", item.draft.wellbeing.score))
                        .foregroundStyle(TherDiaTheme.quality(item.draft.wellbeing))
                }
                .chartYScale(domain: 1...5)
                .frame(height: 195)
                Text("Durchschnitt: \(String(format: "%.1f", Double(filtered.reduce(0) { $0 + $1.draft.wellbeing.score }) / Double(count))) von 5")
                    .font(.subheadline.bold())
            }

            DistributionCard(title: "Tagesbefinden", items: Wellbeing.allCases.map { quality in
                DistributionItem(name: quality.title, count: filtered.filter { $0.draft.wellbeing == quality }.count,
                                 color: TherDiaTheme.quality(quality))
            })
            DistributionCard(title: "Notmedikation", items: yesNo(rescueDays, count: count))
            DistributionCard(title: "Verletzungen", items: yesNo(injuries, count: count))
            DistributionCard(title: "Unterrichtsteilnahme", items: [
                DistributionItem(name: "Kein Schultag", count: count - schoolDays, color: .gray),
                DistributionItem(name: "Nicht teilgenommen", count: schoolDays - schoolAttended, color: .brown),
                DistributionItem(name: "Online", count: filtered.filter { $0.draft.school.attended && $0.draft.school.online && !$0.draft.school.inPerson }.count, color: .teal),
                DistributionItem(name: "Präsenz", count: filtered.filter { $0.draft.school.attended && !$0.draft.school.online && $0.draft.school.inPerson }.count, color: .blue),
                DistributionItem(name: "Online & Präsenz", count: filtered.filter { $0.draft.school.attended && $0.draft.school.online && $0.draft.school.inPerson }.count, color: .indigo)
            ])
            DistributionCard(title: "Fächer bei Unterrichtsteilnahme", items: Subjects.allCases.enumerated().map { index, subject in
                DistributionItem(name: subject.rawValue,
                                 count: filtered.filter { $0.draft.school.attended && $0.draft.school.subjects == subject }.count,
                                 color: [.teal, .blue, .purple][index])
            })
            DistributionCard(title: "Therapie", items: [
                DistributionItem(name: "Keine Therapie", count: count - therapyDays, color: .gray),
                DistributionItem(name: "KJP teilgenommen", count: filtered.filter { $0.draft.therapy.scheduled && $0.draft.therapy.kind == .kjp && $0.draft.therapy.participated }.count, color: .green),
                DistributionItem(name: "KJP nicht teilgenommen", count: filtered.filter { $0.draft.therapy.scheduled && $0.draft.therapy.kind == .kjp && !$0.draft.therapy.participated }.count, color: .orange),
                DistributionItem(name: "ASS teilgenommen", count: filtered.filter { $0.draft.therapy.scheduled && $0.draft.therapy.kind == .ass && $0.draft.therapy.participated }.count, color: .teal),
                DistributionItem(name: "ASS nicht teilgenommen", count: filtered.filter { $0.draft.therapy.scheduled && $0.draft.therapy.kind == .ass && !$0.draft.therapy.participated }.count, color: .red)
            ])
            DistributionCard(title: "Unternehmungen", items: yesNo(outings, count: count))
            DistributionCard(title: "Einfluss der Unternehmungen", items: [
                DistributionItem(name: "Kein Einfluss", count: filtered.filter { $0.draft.outing.happened && !$0.draft.outing.affectedWellbeing }.count, color: .gray)
            ] + Wellbeing.allCases.map { quality in
                DistributionItem(name: quality.title,
                                 count: filtered.filter { $0.draft.outing.happened && $0.draft.outing.affectedWellbeing && $0.draft.outing.effect == quality }.count,
                                 color: TherDiaTheme.quality(quality))
            })
            DistributionCard(title: "Begegnungen außerhalb der Familie", items: yesNo(contacts, count: count))
            DistributionCard(title: "Einfluss der Begegnungen", items: [
                DistributionItem(name: "Kein Einfluss", count: filtered.filter { !$0.draft.people.isEmpty && !$0.draft.peopleImpact.affectedWellbeing }.count, color: .gray)
            ] + Wellbeing.allCases.map { quality in
                DistributionItem(name: quality.title,
                    count: filtered.filter { !$0.draft.people.isEmpty && $0.draft.peopleImpact.affectedWellbeing && $0.draft.peopleImpact.effect == quality }.count,
                    color: TherDiaTheme.quality(quality))
            })

            let baseMedicationCounts = frequencies(filtered.flatMap { $0.draft.baseMedication.items.compactMap { $0.name.nilIfBlank } })
            DistributionCard(title: "Basis-Medikamente (Art)", items: coloredDistribution(baseMedicationCounts))
            let rescueMedicationCounts = frequencies(filtered.filter { $0.draft.rescueMedication.used }
                .compactMap { $0.draft.rescueMedication.medication.name.nilIfBlank })
            DistributionCard(title: "Notmedikamente (Art)", items: coloredDistribution(rescueMedicationCounts))
            DistributionCard(title: "Basis-Medikation (Art und Menge)", items: coloredDistribution(
                frequencies(filtered.flatMap { $0.draft.baseMedication.items.map(\.summary) }.filter { !$0.isEmpty })
            ))
            DistributionCard(title: "Notmedikation (Art und Menge)", items: coloredDistribution(
                frequencies(filtered.filter { $0.draft.rescueMedication.used }
                    .map { $0.draft.rescueMedication.medication.summary }.filter { !$0.isEmpty })
            ))
            SectionCard("Häufigste Begegnungen", subtitle: "Anzahl Tage pro Person · mehrere Personen pro Tag möglich") {
                let frequency = frequencies(filtered.flatMap { $0.draft.people })
                if frequency.isEmpty { Text("Keine Begegnungen erfasst").foregroundStyle(.secondary) }
                else {
                    ForEach(frequency, id: \.0) { pair in
                        let name = pair.0
                        let count = pair.1
                        HStack {
                            Text(name)
                            Spacer()
                            Text("\(count) Tage · \(Int((Double(count) / Double(filtered.count) * 100).rounded())) %")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                        }.font(.subheadline)
                    }
                }
            }
            SectionCard("Dokumentierte Verletzungen") {
                let notes = filtered.filter { $0.draft.injuries.happened }
                if notes.isEmpty { Text("Keine Verletzungen erfasst").foregroundStyle(.secondary) }
                else {
                    ForEach(notes) { item in
                        Text("\(item.date.formatted(date: .abbreviated, time: .omitted)): \(item.draft.injuries.details)")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    private func yesNo(_ yes: Int, count: Int) -> [DistributionItem] {
        [DistributionItem(name: "Ja", count: yes, color: TherDiaTheme.accent),
         DistributionItem(name: "Nein", count: count - yes, color: .gray)]
    }

    private func frequencies(_ values: [String]) -> [(String, Int)] {
        let grouped = Dictionary(grouping: values, by: { $0 })
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.1 == $1.1 ? $0.0 < $1.0 : $0.1 > $1.1 }
    }

    private func coloredDistribution(_ values: [(String, Int)]) -> [DistributionItem] {
        let colors: [Color] = [.teal, .blue, .mint, .indigo, .orange, .purple, .pink]
        return values.enumerated().map { index, value in
            DistributionItem(name: value.0, count: value.1, color: colors[index % colors.count])
        }
    }

    private func numberMetric(_ title: String, value: Int, denominator: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text("\(Int((Double(value) / Double(denominator) * 100).rounded())) %")
                .font(.title2.bold()).foregroundStyle(TherDiaTheme.accent)
            Text("\(value) von \(denominator) Tagen").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private extension String {
    var nilIfBlank: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
