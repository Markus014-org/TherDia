import Foundation
import UIKit

/// Native PDF renderer. Generated files are kept in the temporary directory;
/// Dropbox does not receive plaintext PDFs.
enum PDFReportBuilder {
    private static let orange = UIColor(red: 0.92, green: 0.38, blue: 0.05, alpha: 1)
    private static let ink = UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1)
    private static let muted = UIColor.darkGray

    static func create(days: [PDFReportDay], options: PDFReportOptions) throws -> URL {
        guard !days.isEmpty else {
            throw NSError(domain: "TherDiaPDF", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Im gewählten Zeitraum sind keine Einträge vorhanden."])
        }
        guard !options.parts.isEmpty else {
            throw NSError(domain: "TherDiaPDF", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Bitte mindestens einen Berichtsteil auswählen."])
        }

        let page = CGRect(x: 0, y: 0, width: 595.28, height: 841.89) // A4, 72 dpi
        let margin: CGFloat = 48
        let usable = page.width - margin * 2
        let footer: CGFloat = page.height - 48
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let fileName = "TherDia-Bericht-" + UUID().uuidString + ".pdf"
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let dateRange = "\(options.startDate.formatted(date: .abbreviated, time: .omitted)) – \(options.endDate.formatted(date: .abbreviated, time: .omitted))"
        let timestamp = Date.now.formatted(date: .abbreviated, time: .shortened)
        let patient = options.patientName.trimmingCharacters(in: .whitespacesAndNewlines)

        let content = renderer.pdfData { context in
            drawReport(context: context, days: days, options: options,
                       page: page, margin: margin, usable: usable, footer: footer,
                       dateRange: dateRange, timestamp: timestamp, patient: patient)
        }
        try content.write(to: target, options: Data.WritingOptions.atomic)
        return target
    }

    // Kept separate from UIGraphicsPDFRenderer.pdfData's closure so the Swift
    // compiler can type-check the reporting logic as a regular function.
    private static func drawReport(
        context: UIGraphicsPDFRendererContext,
        days: [PDFReportDay],
        options: PDFReportOptions,
        page: CGRect,
        margin: CGFloat,
        usable: CGFloat,
        footer: CGFloat,
        dateRange: String,
        timestamp: String,
        patient: String
    ) {
            var y: CGFloat = 0
            var pageNumber = 0

            func drawTextAt(_ string: String, x: CGFloat, top: CGFloat, width: CGFloat,
                            font: UIFont, color: UIColor = ink) -> CGFloat {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                paragraph.lineSpacing = 2
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font, .foregroundColor: color, .paragraphStyle: paragraph
                ]
                let box = (string as NSString).boundingRect(
                    with: CGSize(width: width, height: 20_000),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes, context: nil
                )
                let h = max(font.lineHeight, ceil(box.height)) + 3
                (string as NSString).draw(in: CGRect(x: x, y: top, width: width, height: h),
                                          withAttributes: attributes)
                return h
            }

            func newPage() {
                context.beginPage()
                pageNumber += 1
                y = 104
                _ = drawTextAt("TherDia", x: margin, top: 35, width: 240,
                               font: .boldSystemFont(ofSize: 21), color: orange)
                _ = drawTextAt("Therapie-Tagebuch · Bericht", x: margin, top: 65, width: usable,
                               font: .systemFont(ofSize: 10), color: muted)
                let rule = UIBezierPath()
                rule.move(to: CGPoint(x: margin, y: 91))
                rule.addLine(to: CGPoint(x: page.width - margin, y: 91))
                orange.setStroke()
                rule.lineWidth = 1.8
                rule.stroke()
                _ = drawTextAt("TherDia · vertraulicher Bericht", x: margin, top: footer,
                               width: usable - 80, font: .systemFont(ofSize: 8), color: muted)
                _ = drawTextAt("Seite \(pageNumber)", x: page.width - margin - 75, top: footer,
                               width: 75, font: .systemFont(ofSize: 8), color: muted)
            }

            func room(_ height: CGFloat) {
                if y + height > footer - 12 { newPage() }
            }

            func line(_ text: String, font: UIFont = .systemFont(ofSize: 10.5),
                      color: UIColor = ink, indent: CGFloat = 0) {
                // Split very long notes so they cannot overflow a whole page.
                let paragraphs = text.isEmpty ? ["–"] : text.components(separatedBy: .newlines)
                for paragraph in paragraphs {
                    let letters = Array(paragraph.isEmpty ? " " : paragraph)
                    var offset = 0
                    while offset < letters.count {
                        let end = min(offset + 260, letters.count)
                        let piece = String(letters[offset..<end])
                        let maxWidth = usable - indent
                        let attributes: [NSAttributedString.Key: Any] = [.font: font]
                        let bounds = (piece as NSString).boundingRect(
                            with: CGSize(width: maxWidth, height: 20_000),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            attributes: attributes, context: nil)
                        room(ceil(bounds.height) + 12)
                        let height = drawTextAt(piece, x: margin + indent, top: y,
                                                width: maxWidth, font: font, color: color)
                        y += height + 4
                        offset = end
                    }
                }
            }

            func heading(_ title: String) {
                room(53)
                y += 12
                line(title, font: .boldSystemFont(ofSize: 15), color: orange)
                y += 5
            }

            func distribution(_ entries: [(String, Int, UIColor)], pie: Bool = true) {
                let total = entries.reduce(0) { $0 + $1.1 }
                if total == 0 {
                    line("Keine erfassten Angaben in dieser Kategorie.", color: muted)
                    return
                }
                if pie {
                    let diameter: CGFloat = 125
                    room(diameter + 16)
                    let center = CGPoint(x: margin + diameter / 2 + 8, y: y + diameter / 2)
                    var angle = -CGFloat.pi / 2
                    for (_, count, color) in entries where count > 0 {
                        let arc = (CGFloat(count) / CGFloat(total)) * 2 * .pi
                        let slice = UIBezierPath()
                        slice.move(to: center)
                        slice.addArc(withCenter: center, radius: diameter / 2,
                                     startAngle: angle, endAngle: angle + arc, clockwise: true)
                        slice.close()
                        color.setFill()
                        slice.fill()
                        angle += arc
                    }
                    y += diameter + 14
                }
                for (name, count, _) in entries {
                    let percentage = Int((Double(count) / Double(total) * 100).rounded())
                    line("• \(name): \(count) (\(percentage) %)")
                }
            }

            func lineChart(_ values: [(Date, Int)]) {
                if values.isEmpty { line("Keine Daten.", color: muted); return }
                let sample = Array(values.suffix(60))
                room(180)
                let x0 = margin + 26
                let top = y + 8
                let h: CGFloat = 132
                let w = usable - 42
                for score in 1...5 {
                    let py = top + h * (1 - CGFloat(score - 1) / 4)
                    let grid = UIBezierPath()
                    grid.move(to: CGPoint(x: x0, y: py))
                    grid.addLine(to: CGPoint(x: x0 + w, y: py))
                    UIColor.systemGray4.setStroke()
                    grid.lineWidth = 0.6
                    grid.stroke()
                    _ = drawTextAt("\(score)", x: margin, top: py - 7, width: 20,
                                   font: .systemFont(ofSize: 8), color: muted)
                }
                let path = UIBezierPath()
                for (i, item) in sample.enumerated() {
                    let px = x0 + (sample.count == 1 ? w / 2 : CGFloat(i) / CGFloat(sample.count - 1) * w)
                    let py = top + h * (1 - CGFloat(item.1 - 1) / 4)
                    if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
                    else { path.addLine(to: CGPoint(x: px, y: py)) }
                }
                orange.setStroke()
                path.lineWidth = 2
                path.stroke()
                y += 164
                line("Verlauf: 1 = extrem schlecht, 5 = gut · bis zu 60 letzte Einträge", color: muted)
            }

            func barChart(_ values: [(Date, Int)]) {
                if values.isEmpty { line("Keine Bildschirmzeit erfasst.", color: muted); return }
                let sample = Array(values.suffix(35))
                room(180)
                let x0 = margin + 15, top = y + 10
                let height: CGFloat = 130, width = usable - 25
                let maxValue = max(4, sample.map { $0.1 }.max() ?? 4)
                let barWidth = width / CGFloat(sample.count)
                for (index, item) in sample.enumerated() {
                    let fraction = CGFloat(item.1) / CGFloat(maxValue)
                    let rect = CGRect(x: x0 + CGFloat(index) * barWidth + 1,
                                      y: top + height * (1 - fraction),
                                      width: max(2, barWidth - 2), height: height * fraction)
                    orange.setFill()
                    UIBezierPath(roundedRect: rect, cornerRadius: 1).fill()
                }
                y += 165
                line("Bildschirmzeit nach Tagen · bis zu 35 letzte erfasste Tage", color: muted)
            }

            func count(_ test: (PDFReportDay) -> Bool) -> Int {
                days.filter(test).count
            }

            func yesNo(_ title: String, _ test: (PDFReportDay) -> Bool) {
                heading(title)
                let yes = count(test)
                distribution([("Ja", yes, orange), ("Nein", days.count - yes, UIColor.systemGray3)])
            }

            newPage()
            line("Zeitraum: \(dateRange)", font: .boldSystemFont(ofSize: 11))
            line("Erstellt: \(timestamp)", color: muted)
            if !patient.isEmpty { line("Patient/in: \(patient)") }
            line("Datengrundlage: \(days.count) dokumentierte Tage. Prozentwerte beziehen sich jeweils auf die angegebene Bezugsmenge.",
                 color: muted)
            y += 8

            for part in PDFReportPart.allCases where options.parts.contains(part) {
                switch part {
                case .overview:
                    heading("Überblick und Kennzahlen")
                    line("Dokumentierte Tage: \(days.count)")
                    let average = Double(days.reduce(0) { $0 + $1.draft.wellbeing.score }) / Double(days.count)
                    line("Mittleres Tagesbefinden: \(String(format: "%.1f", average)) von 5")
                    line("Tage mit Notmedikation: \(count { $0.draft.rescueMedication.used })")
                    line("Tage mit Unterrichtsteilnahme: \(count { $0.draft.school.attended })")
                    line("Tage mit Therapie: \(count { $0.draft.therapy.scheduled })")
                    line("Tage mit Begegnungen: \(count { !$0.draft.people.isEmpty })")
                case .wellbeingTrend:
                    heading("Tagesbefinden – Verlauf")
                    lineChart(days.map { ($0.date, $0.draft.wellbeing.score) })
                case .wellbeingPie:
                    heading("Tagesbefinden – Verteilung")
                    distribution(Wellbeing.allCases.map { wellbeing in
                        (wellbeing.title, count { $0.draft.wellbeing == wellbeing },
                         UIColor(red: [0.13,0.89,0.96,0.83,0.43][wellbeing.rawValue],
                                 green: [0.66,0.74,0.50,0.22,0.06][wellbeing.rawValue],
                                 blue: [0.35,0.17,0.16,0.24,0.12][wellbeing.rawValue], alpha: 1))
                    })
                case .medication:
                    heading("Basis-Medikamente")
                    let names = days.flatMap { $0.draft.baseMedication.items }
                        .filter { !$0.name.isEmpty }
                        .map { $0.summary }
                    let frequencies = Dictionary(grouping: names, by: { $0 })
                    if frequencies.isEmpty { line("Keine Medikamente erfasst.") }
                    for (name, items) in frequencies.sorted(by: { $0.key < $1.key }) {
                        line("• \(name): \(items.count) Angaben")
                    }
                case .emergency:
                    yesNo("Notmedikation", { $0.draft.rescueMedication.used })
                    heading("Wohlbefinden nach Notmedikation")
                    distribution(Wellbeing.allCases.map { quality in
                        (quality.title,
                         days.flatMap { $0.draft.rescueMedication.items }.filter { $0.wellbeingAfter == quality }.count,
                         UIColor(red: [0.13,0.89,0.96,0.83,0.43][quality.rawValue],
                                 green: [0.66,0.74,0.50,0.22,0.06][quality.rawValue],
                                 blue: [0.35,0.17,0.16,0.24,0.12][quality.rawValue], alpha: 1))
                    })
                    for day in days where day.draft.rescueMedication.used {
                        for (index, rescue) in day.draft.rescueMedication.items.enumerated() {
                            var detailParts: [String] = [rescue.medication.summary]
                            if let time = rescue.time { detailParts.append(time + " Uhr") }
                            if let tired = rescue.tirednessAfter {
                                detailParts.append("Müdigkeit als Folge: " + (tired ? "Ja" : "Nein"))
                            }
                            if let wellbeing = rescue.wellbeingAfter {
                                detailParts.append("Befinden danach: " + wellbeing.title)
                            }
                            let details = detailParts.filter { !$0.isEmpty }.joined(separator: " · ")
                            line("\(day.date.formatted(date: .abbreviated, time: .omitted)) · \(index + 1): \(details)")
                            if options.showNotes && !rescue.wellbeingNotes.isEmpty {
                                line("Anmerkung: " + rescue.wellbeingNotes, indent: 10)
                            }
                        }
                    }
                case .school:
                    heading("Schule und Unterricht")
                    distribution([
                        ("Kein Schultag", count { !$0.draft.school.hasSchool }, UIColor.systemGray3),
                        ("Keine Teilnahme", count { $0.draft.school.hasSchool && !$0.draft.school.attended }, orange),
                        ("Teilgenommen", count { $0.draft.school.hasSchool && $0.draft.school.attended }, UIColor.systemGreen)
                    ])
                case .therapy:
                    heading("Therapie")
                    distribution([
                        ("Keine Therapie", count { !$0.draft.therapy.scheduled }, UIColor.systemGray3),
                        ("KJP", count { $0.draft.therapy.scheduled && $0.draft.therapy.kind == .kjp }, orange),
                        ("ASS", count { $0.draft.therapy.scheduled && $0.draft.therapy.kind == .ass }, UIColor.systemBlue)
                    ])
                case .aggression:
                    heading("Aggressives Verhalten")
                    let recorded = days.filter { $0.record.field(.aggression) != nil }
                    let countNo = recorded.filter { !$0.draft.aggression.happened }.count
                    distribution([
                        ("Nein", countNo, UIColor.systemGray3),
                        ("Selbstverletzend", recorded.filter { $0.draft.aggression.selfInjurious && !$0.draft.aggression.otherAggressive }.count, orange),
                        ("Fremdaggressiv", recorded.filter { !$0.draft.aggression.selfInjurious && $0.draft.aggression.otherAggressive }.count, UIColor.systemRed),
                        ("Beides", recorded.filter { $0.draft.aggression.selfInjurious && $0.draft.aggression.otherAggressive }.count, UIColor.systemPurple)
                    ])
                    if options.showNotes {
                        for day in recorded where day.draft.aggression.happened {
                            line("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.draft.aggression.summary)")
                        }
                    }
                    line("Hinweis: Ältere Verletzungseinträge werden nicht als aggressives Verhalten eingeordnet.", color: muted)
                case .activities:
                    yesNo("Unternehmungen", { $0.draft.outing.happened })
                    if options.showNotes {
                        for day in days where day.draft.outing.happened {
                            line("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.draft.outing.activity)")
                        }
                    }
                case .encounters:
                    yesNo("Begegnungen", { !$0.draft.people.isEmpty })
                    if options.showNames {
                        for day in days where !day.draft.people.isEmpty {
                            line("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.draft.people.joined(separator: ", "))")
                        }
                    }
                case .screenTime:
                    heading("Bildschirmzeit")
                    let available = days.compactMap { day -> (Date, Int)? in
                        guard let value = day.draft.screenTime.halfHours else { return nil }
                        return (day.date, value)
                    }
                    if !available.isEmpty {
                        let mean = Double(available.reduce(0) { $0 + $1.1 }) / Double(available.count) / 2
                        line("Durchschnitt an \(available.count) erfassten Tagen: \(String(format: "%.1f", mean)) Stunden")
                    }
                    barChart(available)
                case .dailyEntries:
                    heading("Tagebucheinträge nach Datum")
                    for day in days {
                        room(55)
                        line(day.date.formatted(date: .complete, time: .omitted),
                             font: .boldSystemFont(ofSize: 11), color: orange)
                        for field in DiaryField.allCases {
                            if field == .injuries && !options.parts.contains(.legacyInjuries) { continue }
                            if let raw = day.record.field(field)?.value {
                                var value = FieldDescription.describe(field, json: raw)
                                if field == .rescueMedication && !options.showNotes {
                                    let medications = day.draft.rescueMedication.items
                                    value = medications.isEmpty ? "Nein" : medications.enumerated().map { index, rescue in
                                        "\(index + 1). " + rescue.medication.summary +
                                        (rescue.time.map { " · " + $0 + " Uhr" } ?? "") +
                                        (rescue.tirednessAfter.map { " · Müdigkeit: " + ($0 ? "Ja" : "Nein") } ?? "") +
                                        (rescue.wellbeingAfter.map { " · Befinden danach: " + $0.title } ?? "")
                                    }.joined(separator: " | ")
                                }
                                if field == .people && !options.showNames {
                                    value = "\(day.draft.people.count) Person(en) – Namen ausgeblendet"
                                }
                                if field == .aggression && !options.showNotes {
                                    value = day.draft.aggression.happened ?
                                        (["Selbstverletzend", "Fremdaggressiv"].enumerated().compactMap { index, name in
                                            let active = index == 0 ? day.draft.aggression.selfInjurious : day.draft.aggression.otherAggressive
                                            return active ? name : nil
                                        }.joined(separator: ", ")) : "Nein"
                                }
                                if field == .outing && !options.showNotes {
                                    value = day.draft.outing.happened ? "Ja" : "Nein"
                                }
                                if field == .peopleImpact && !options.showNotes {
                                    value = day.draft.peopleImpact.affectedWellbeing ?
                                        day.draft.peopleImpact.effect.title : "Kein Einfluss"
                                }
                                if field == .injuries && !options.showNotes { value = "Historischer Eintrag vorhanden" }
                                line("\(field.title): \(value)", indent: 12)
                            }
                        }
                        y += 9
                    }
                case .legacyInjuries:
                    if !options.parts.contains(.dailyEntries) {
                        heading("Ältere Verletzungseinträge – historisch")
                        let old = days.filter { $0.draft.injuries.happened }
                        if old.isEmpty { line("Keine älteren Verletzungseinträge vorhanden.") }
                        for day in old {
                            line("\(day.date.formatted(date: .abbreviated, time: .omitted)): " +
                                 (options.showNotes ? day.draft.injuries.details : "Eintrag vorhanden"))
                        }
                    }
                }
                y += 10
            }
    }
}
