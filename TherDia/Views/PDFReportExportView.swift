import SwiftUI
import PDFKit

struct PDFReportExportView: View {
    let database: DiaryDatabase

    @Environment(\.dismiss) private var dismiss
    @State private var period: PDFReportRange = .month
    @State private var from = Calendar.current.date(byAdding: .day, value: -29, to: .now) ?? .now
    @State private var until = Date()
    @State private var patientName = ""
    @State private var selected = Set<PDFReportPart>([
        .overview, .wellbeingTrend, .wellbeingPie,
        .emergency, .school, .aggression, .screenTime
    ])
    @State private var showNames = false
    @State private var showNotes = false
    @State private var pdfURL: URL?
    @State private var showPreview = false
    @State private var failureMessage: String?
    @State private var generated = false

    private var firstDay: Date { period == .custom ? from : period.start }
    private var lastDay: Date { period == .custom ? until : .now }
    private var days: [PDFReportDay] {
        PDFReportData.selectedDays(in: database, from: firstDay, through: lastDay)
    }

    private var valid: Bool {
        Calendar.current.startOfDay(for: firstDay) <= Calendar.current.startOfDay(for: lastDay)
            && !selected.isEmpty && !days.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    SectionCard("Berichtszeitraum") {
                        Picker("Zeitraum", selection: $period) {
                            ForEach(PDFReportRange.allCases) { range in
                                Text(range.rawValue).tag(range)
                            }
                        }
                        .pickerStyle(.menu)
                        if period == .custom {
                            DatePicker("Von", selection: $from, displayedComponents: .date)
                            DatePicker("Bis", selection: $until, displayedComponents: .date)
                        }
                        if firstDay > lastDay {
                            Text("Das Anfangsdatum muss vor dem Enddatum liegen.")
                                .foregroundStyle(.red).font(.footnote)
                        }
                        Text("\(days.count) dokumentierte Tage im ausgewählten Zeitraum")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    SectionCard("Patient/in (optional)") {
                        TextField("Name für die PDF-Kopfzeile", text: $patientName)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.words)
                        Text("Der Name wird nur in das erzeugte PDF geschrieben, nicht in Dropbox gespeichert.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    SectionCard("Inhalt des PDF-Berichts", subtitle: "Wähle einzeln die gewünschten Diagramme und Berichtsabschnitte") {
                        HStack {
                            Button("Alle auswählen") { selected = Set(PDFReportPart.allCases); generated = false }
                            Spacer()
                            Button("Keine auswählen") { selected.removeAll(); generated = false }
                        }.font(.footnote)
                        ForEach(PDFReportPart.allCases) { part in
                            Toggle(part.rawValue, isOn: Binding(
                                get: { selected.contains(part) },
                                set: { enabled in
                                    if enabled { selected.insert(part) } else { selected.remove(part) }
                                    generated = false
                                }
                            ))
                            .toggleStyle(.switch)
                        }
                    }

                    SectionCard("Datenschutz und Details") {
                        Toggle("Namen von Begegnungen im PDF zeigen", isOn: $showNames)
                        Toggle("Freitexte und Beschreibungen einbeziehen", isOn: $showNotes)
                        Label("Das PDF ist nach dem Export nicht verschlüsselt. Bitte nur über vertrauenswürdige Wege versenden und sicher speichern.",
                              systemImage: "lock.open")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("Die PDF-Auswahl verwendet den oben gewählten Zeitraum unabhängig von den Filtern der Berichtsansicht.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Button {
                        generate()
                    } label: {
                        Label("PDF jetzt erstellen", systemImage: "doc.richtext")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!valid)

                    if let pdfURL, generated {
                        SectionCard("PDF fertig") {
                            Label("Bericht wurde erstellt und kann angesehen, in Dateien gespeichert oder per Mail beziehungsweise anderen Apps geteilt werden.",
                                  systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.subheadline)
                            Button("PDF ansehen") { showPreview = true }
                                .buttonStyle(.bordered)
                            ShareLink(item: pdfURL) {
                                Label("PDF teilen oder sichern", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }.padding(16)
            }
            .background(TherDiaTheme.canvas)
            .navigationTitle("PDF-Bericht")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: period) { _, _ in generated = false }
            .onChange(of: from) { _, _ in generated = false }
            .onChange(of: until) { _, _ in generated = false }
            .onChange(of: patientName) { _, _ in generated = false }
            .onChange(of: showNames) { _, _ in generated = false }
            .onChange(of: showNotes) { _, _ in generated = false }
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Schließen") { dismiss() }
            }}
            .sheet(isPresented: $showPreview) {
                if let pdfURL {
                    NavigationStack {
                        PDFDocumentPreview(url: pdfURL)
                            .navigationTitle("TherDia-Bericht")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar { ToolbarItem(placement: .confirmationAction) {
                                Button("Fertig") { showPreview = false }
                            }}
                    }
                }
            }
            .alert("PDF konnte nicht erstellt werden", isPresented: Binding(
                get: { failureMessage != nil },
                set: { if !$0 { failureMessage = nil } }
            )) {
                Button("OK") { failureMessage = nil }
            } message: {
                Text(failureMessage ?? "")
            }
        }
    }

    private func generate() {
        guard valid else { return }
        let options = PDFReportOptions(
            patientName: patientName,
            startDate: firstDay,
            endDate: lastDay,
            parts: selected,
            showNames: showNames,
            showNotes: showNotes
        )
        do {
            // Remove the previous temporary PDF only when explicitly regenerating it.
            let oldURL = pdfURL
            let created = try PDFReportBuilder.create(days: days, options: options)
            pdfURL = created
            generated = true
            if let oldURL { try? FileManager.default.removeItem(at: oldURL) }
        } catch {
            generated = false
            failureMessage = error.localizedDescription
        }
    }
}

private struct PDFDocumentPreview: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.backgroundColor = UIColor.systemGroupedBackground
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
