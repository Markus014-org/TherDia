import SwiftUI

struct DiaryEditorView: View {
    @ObservedObject var model: AppModel
    @State private var selectedDate = Date()
    @State private var draft = DayDraft()
    @State private var lastLoaded = DayDraft()
    @State private var peopleEnabled = false
    @State private var showReview = false
    @State private var changes: [FieldChange] = []
    @State private var newlySynced = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wie war dein Tag?")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                            .foregroundStyle(TherDiaTheme.navy)
                        Text("Ein Moment zum Festhalten, was wichtig war.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)

                    SectionCard("Datum", subtitle: "Heute oder ein vergangener Tag") {
                        Text(selectedDate.diaryHeading)
                            .font(.title3.bold()).foregroundStyle(TherDiaTheme.accent)
                        DatePicker("Eintrag für", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }

                    if newlySynced {
                        Label("Daten aus Dropbox aktualisiert. Ungespeicherte Eingaben bitte überprüfen.", systemImage: "arrow.triangle.2.circlepath")
                            .font(.footnote).foregroundStyle(TherDiaTheme.accent)
                    }

                    SectionCard("Tagesbefinden") {
                        HStack(spacing: 10) {
                            QualityDot(quality: draft.wellbeing, size: 23)
                            Text(draft.wellbeing.title).font(.title3.bold())
                        }
                        Slider(value: Binding(get: { Double(draft.wellbeing.rawValue) }, set: {
                            draft.wellbeing = Wellbeing(rawValue: Int($0.rounded())) ?? .fairlyGood
                        }), in: 0...4, step: 1)
                            .tint(TherDiaTheme.quality(draft.wellbeing))
                            .accessibilityLabel("Befinden")
                        HStack {
                            ForEach(Wellbeing.allCases) { value in
                                QualityDot(quality: value, size: draft.wellbeing == value ? 19 : 13)
                                    .frame(maxWidth: .infinity)
                                    .onTapGesture { draft.wellbeing = value }
                            }
                        }
                        HStack {
                            Text("Gut")
                            Spacer()
                            Text("Extrem schlecht")
                        }.font(.caption).foregroundStyle(.secondary)
                    }

                    SectionCard("Basis-Medikation", subtitle: "Vorausgefüllt aus den Einstellungen, täglich anpassbar") {
                        medicationFields(name: $draft.baseMedication.name, quantity: $draft.baseMedication.quantity)
                    }

                    SectionCard("Notmedikation") {
                        Toggle("Notmedikation angewendet?", isOn: $draft.rescueMedication.used)
                        if draft.rescueMedication.used {
                            medicationFields(name: $draft.rescueMedication.medication.name,
                                             quantity: $draft.rescueMedication.medication.quantity)
                            Label("Im Bericht mit blauem Punkt markiert", systemImage: "circle.fill")
                                .foregroundStyle(.blue).font(.caption)
                        }
                    }

                    SectionCard("Verletzungen") {
                        Toggle("Verletzung aufgetreten?", isOn: $draft.injuries.happened)
                        if draft.injuries.happened {
                            TextField("Welche Verletzung?", text: $draft.injuries.details, axis: .vertical)
                                .lineLimit(2...5).textFieldStyle(.roundedBorder)
                        }
                    }

                    SectionCard("Schule") {
                        Toggle("Am Unterricht teilgenommen?", isOn: $draft.school.attended)
                        if draft.school.attended {
                            Toggle("Online", isOn: $draft.school.online)
                            Toggle("In Präsenz", isOn: $draft.school.inPerson)
                            if draft.school.online || draft.school.inPerson {
                                Picker("Fächer", selection: $draft.school.subjects) {
                                    ForEach(Subjects.allCases) { subject in
                                        Text(subject.rawValue).tag(subject)
                                    }
                                }
                            }
                        } else {
                            Text("Wird gespeichert als: Nicht am Unterricht teilgenommen")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    SectionCard("Therapie") {
                        Toggle("Therapie vorgesehen?", isOn: $draft.therapy.scheduled)
                        if draft.therapy.scheduled {
                            Picker("Art", selection: $draft.therapy.kind) {
                                ForEach(TherapyType.allCases) { kind in
                                    Text(kind.rawValue).tag(kind)
                                }
                            }.pickerStyle(.segmented)
                            Toggle("Teilgenommen?", isOn: $draft.therapy.participated)
                        }
                    }

                    SectionCard("Unternehmung") {
                        Toggle("Etwas unternommen?", isOn: $draft.outing.happened)
                        if draft.outing.happened {
                            TextField("Was hast du unternommen?", text: $draft.outing.activity, axis: .vertical)
                                .lineLimit(2...4).textFieldStyle(.roundedBorder)
                            Toggle("Einfluss auf das Wohlbefinden?", isOn: $draft.outing.affectedWellbeing)
                            if draft.outing.affectedWellbeing {
                                Picker("Wie war der Einfluss?", selection: $draft.outing.effect) {
                                    ForEach(Wellbeing.allCases) { quality in
                                        Text(quality.title).tag(quality)
                                    }
                                }
                                HStack {
                                    ForEach(Wellbeing.allCases) { value in
                                        Button { draft.outing.effect = value } label: {
                                            QualityDot(quality: value, size: 22)
                                                .padding(6)
                                                .background(draft.outing.effect == value ? Color.gray.opacity(0.13) : .clear,
                                                            in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                TextField("Zusätzliche Anmerkung (optional)", text: $draft.outing.notes, axis: .vertical)
                                    .lineLimit(2...4).textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    SectionCard("Begegnungen außerhalb der Familie", subtitle: "Ein Name pro Feld · später einzeln filterbar") {
                        Toggle("Menschen getroffen?", isOn: Binding(get: { peopleEnabled }, set: { value in
                            peopleEnabled = value
                            if value && draft.people.isEmpty { draft.people = [""] }
                            if !value { draft.people = [] }
                        }))
                        if peopleEnabled {
                            ForEach(draft.people.indices, id: \.self) { index in
                                HStack {
                                    TextField("Name \(index + 1)", text: $draft.people[index])
                                        .textContentType(.name).textFieldStyle(.roundedBorder)
                                    Button(role: .destructive) {
                                        draft.people.remove(at: index)
                                        if draft.people.isEmpty { peopleEnabled = false }
                                    } label: { Image(systemName: "minus.circle") }
                                    .accessibilityLabel("Namen entfernen")
                                }
                            }
                            Button { draft.people.append("") } label: {
                                Label("Weiteren Namen hinzufügen", systemImage: "plus.circle")
                            }
                        }
                    }

                    PrimaryAction(title: "Tag speichern", disabled: !model.canEdit) { prepareSave() }
                    HStack(spacing: 7) {
                        Image(systemName: model.connectivity.isConnected ? "checkmark.icloud" : "wifi.slash")
                        Text(model.syncStatus)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 18)
                }.padding(.horizontal, 16)
            }
            .background(TherDiaTheme.canvas)
            .navigationTitle("Tagebuch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await model.sync() } } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                        .disabled(model.isSyncing || !model.connected)
                        .accessibilityLabel("Jetzt synchronisieren")
                }
            }
            .onAppear(perform: loadDay)
            .onChange(of: selectedDate) { _, _ in loadDay() }
            .onChange(of: model.database) { _, _ in
                if draft == lastLoaded { loadDay() }
                else { newlySynced = true }
            }
            .sheet(isPresented: $showReview) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 13) {
                            Text("Folgende gespeicherte Werte werden verändert. Bitte alte und neue Angaben vergleichen.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            ForEach(changes.filter { $0.oldValue != nil }) { change in
                                SectionCard(change.field.title) {
                                    Text("Bisher").font(.caption.bold()).foregroundStyle(.secondary)
                                    Text(FieldDescription.describe(change.field, json: change.oldValue!))
                                    Divider()
                                    Text("Neu").font(.caption.bold()).foregroundStyle(TherDiaTheme.accent)
                                    Text(FieldDescription.describe(change.field, json: change.newValue))
                                }
                            }
                        }.padding(16)
                    }
                    .background(TherDiaTheme.canvas)
                    .navigationTitle("Änderungen prüfen")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { showReview = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Überschreiben erlauben") {
                                showReview = false
                                model.save(draft, date: selectedDate)
                                lastLoaded = draft
                                newlySynced = false
                            }.bold()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func medicationFields(name: Binding<String>, quantity: Binding<String>) -> some View {
        TextField("Art / Bezeichnung", text: name)
            .textFieldStyle(.roundedBorder)
        TextField("Menge (inkl. Einheit, z. B. mg)", text: quantity)
            .textFieldStyle(.roundedBorder)
    }

    private func loadDay() {
        let newDraft = model.draft(for: selectedDate)
        draft = newDraft
        lastLoaded = newDraft
        peopleEnabled = !newDraft.people.isEmpty
        newlySynced = false
    }

    private func prepareSave() {
        guard model.canEdit else { return }
        if peopleEnabled && draft.people.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            model.errorMessage = "Bitte mindestens einen Namen angeben oder die Begegnung auf Nein stellen."
            return
        }
        var normalized = draft
        normalized.normalize()
        if let error = normalized.validationError { model.errorMessage = error; return }
        do {
            changes = try model.changes(for: normalized, date: selectedDate)
            if changes.contains(where: { $0.oldValue != nil }) { showReview = true }
            else {
                model.save(normalized, date: selectedDate)
                draft = normalized
                lastLoaded = normalized
                newlySynced = false
            }
        } catch { model.errorMessage = error.localizedDescription }
    }
}
