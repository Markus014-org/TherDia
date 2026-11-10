import SwiftUI

struct DiaryEditorView: View {
    @ObservedObject var model: AppModel
    @Binding var selectedDate: Date
    @Binding var selectedTab: MainTab
    @ObservedObject var testFlightVersion: TestFlightVersionChecker
    @State private var showDateJump = false
    @State private var savedMessage = false
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
                    if testFlightVersion.updateAvailable {
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Eine neue Version von TherDia ist in TestFlight verfügbar. Bitte aktualisieren.")
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(Color(red: 0.0, green: 0.52, blue: 0.56))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("Neue TherDia-Version in TestFlight verfügbar")
                    }

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
                        ForEach(draft.baseMedication.items.indices, id: \.self) { index in
                            HStack(alignment: .center, spacing: 6) {
                                medicationFields(name: $draft.baseMedication.items[index].name,
                                                 quantity: $draft.baseMedication.items[index].quantity)
                                Button(role: .destructive) {
                                    draft.baseMedication.items.remove(at: index)
                                } label: { Image(systemName: "minus.circle.fill") }
                                    .accessibilityLabel("Medikament entfernen")
                            }
                        }
                        Button {
                            draft.baseMedication.items.append(Medication())
                        } label: {
                            Label("Medikament hinzufügen", systemImage: "plus.circle.fill")
                        }
                    }

                    SectionCard("Notmedikation") {
                        Toggle("Notmedikation angewendet?", isOn: $draft.rescueMedication.used)
                        if draft.rescueMedication.used {
                            medicationFields(name: $draft.rescueMedication.medication.name,
                                             quantity: $draft.rescueMedication.medication.quantity)
                            DatePicker("Uhrzeit der Einnahme",
                                selection: Binding(
                                    get: {
                                        let formatter = DateFormatter()
                                        formatter.locale = Locale(identifier: "de_DE")
                                        formatter.dateFormat = "HH:mm"
                                        return draft.rescueMedication.time.flatMap { formatter.date(from: $0) } ?? Date()
                                    },
                                    set: { chosenDate in
                                        let formatter = DateFormatter()
                                        formatter.locale = Locale(identifier: "de_DE")
                                        formatter.dateFormat = "HH:mm"
                                        draft.rescueMedication.time = formatter.string(from: chosenDate)
                                    }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(height: 165)
                            .clipped()
                            .accessibilityLabel("Uhrzeit der Notmedikation auswählen")
                            if draft.rescueMedication.time == nil {
                                Button("Angezeigte Uhrzeit übernehmen") {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "HH:mm"
                                    draft.rescueMedication.time = formatter.string(from: Date())
                                }
                                .font(.subheadline)
                            } else {
                                HStack {
                                    Text("Gespeichert: \(draft.rescueMedication.time ?? "") Uhr")
                                        .font(.subheadline)
                                    Spacer()
                                    Button("Uhrzeit löschen") {
                                        draft.rescueMedication.time = nil
                                    }
                                    .font(.subheadline)
                                }
                            }
                            Text("Die Uhrzeit ist optional. Der Wheel-Picker speichert erst, wenn du ihn veränderst oder „Übernehmen“ wählst.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Müdigkeit als Folge?")
                                    .font(.subheadline.bold())
                                Picker("Müdigkeit als Folge?", selection: $draft.rescueMedication.tirednessAfter) {
                                    Text("Nicht angegeben").tag(Optional<Bool>.none)
                                    Text("Nein").tag(Optional(false))
                                    Text("Ja").tag(Optional(true))
                                }
                                .pickerStyle(.segmented)
                                Text("Wähle Ja oder Nein, wenn die Folge der Medikation beurteilt wurde.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 9) {
                                Text("Wohlbefinden nach Medikation").font(.subheadline.bold())
                                if draft.rescueMedication.wellbeingAfter == nil {
                                    Text("Noch keine Bewertung ausgewählt")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                WellbeingControl(value: Binding(
                                    get: { draft.rescueMedication.wellbeingAfter ?? .fairlyGood },
                                    set: { draft.rescueMedication.wellbeingAfter = $0 }
                                ), label: "Wohlbefinden nach Notmedikation")
                                if draft.rescueMedication.wellbeingAfter != nil {
                                    Button("Bewertung entfernen") {
                                        draft.rescueMedication.wellbeingAfter = nil
                                    }
                                    .font(.caption)
                                }
                                TextField("Anmerkung nach der Medikation (optional)",
                                          text: $draft.rescueMedication.wellbeingNotes,
                                          axis: .vertical)
                                    .lineLimit(2...5)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .padding(.top, 8)
                            Label("Im Bericht mit blauem Punkt markiert", systemImage: "circle.fill")
                                .foregroundStyle(.blue).font(.caption)
                        }
                    }

                    SectionCard("Aggressives Verhalten") {
                        Toggle("Aggressives Verhalten aufgetreten?", isOn: $draft.aggression.happened)
                        if draft.aggression.happened {
                            Toggle("Selbstverletzend", isOn: $draft.aggression.selfInjurious)
                            if draft.aggression.selfInjurious {
                                TextField("Beschreibung selbstverletzendes Verhalten", text: $draft.aggression.selfDescription, axis: .vertical)
                                    .lineLimit(2...5).textFieldStyle(.roundedBorder)
                            }
                            Toggle("Fremdaggressiv", isOn: $draft.aggression.otherAggressive)
                            if draft.aggression.otherAggressive {
                                TextField("Beschreibung fremdaggressives Verhalten", text: $draft.aggression.otherDescription, axis: .vertical)
                                    .lineLimit(2...5).textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    if draft.injuries.happened {
                        SectionCard("Früherer Verletzungseintrag", subtitle: "Historische Angabe – bleibt unverändert gespeichert") {
                            Text(draft.injuries.details)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    SectionCard("Schule") {
                        Toggle("War an diesem Tag Schule?", isOn: $draft.school.hasSchool)
                        if draft.school.hasSchool {
                            Toggle("Am Unterricht teilgenommen?", isOn: $draft.school.attended)
                        }
                        if draft.school.hasSchool && draft.school.attended {
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
                            Text(draft.school.hasSchool ? "Wird gespeichert als: Nicht am Unterricht teilgenommen" : "Wird gespeichert als: Kein Schultag")
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
                                WellbeingControl(value: $draft.outing.effect, label: "Einfluss der Unternehmung")
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
                            Toggle("Einfluss auf das Wohlbefinden?", isOn: $draft.peopleImpact.affectedWellbeing)
                            if draft.peopleImpact.affectedWellbeing {
                                WellbeingControl(value: $draft.peopleImpact.effect, label: "Einfluss der Begegnungen")
                                TextField("Anmerkung (optional)", text: $draft.peopleImpact.notes, axis: .vertical)
                                    .lineLimit(2...4).textFieldStyle(.roundedBorder)
                            }
                        }
                    }

                    SectionCard("Bildschirmzeit", subtitle: "Halbstündige Schritte · 0 bis 24 Stunden") {
                        Toggle("Bildschirmzeit erfassen", isOn: Binding(
                            get: { draft.screenTime.halfHours != nil },
                            set: { draft.screenTime.halfHours = $0 ? (draft.screenTime.halfHours ?? 0) : nil }
                        ))
                        if draft.screenTime.halfHours != nil {
                            HStack {
                                Text(draft.screenTime.hoursText).font(.headline)
                                Spacer()
                                Stepper("Halbe Stunden", value: Binding(
                                    get: { draft.screenTime.halfHours ?? 0 },
                                    set: { draft.screenTime.halfHours = $0 }
                                ), in: 0...48, step: 1)
                                .labelsHidden()
                            }
                            Slider(value: Binding(
                                get: { Double(draft.screenTime.halfHours ?? 0) },
                                set: { draft.screenTime.halfHours = Int($0.rounded()) }
                            ), in: 0...48, step: 1)
                            .accessibilityLabel("Bildschirmzeit in halben Stunden")
                        }
                    }

                    PrimaryAction(title: "Tag speichern", disabled: !model.canEdit) { prepareSave() }
                    if savedMessage {
                        Label("Tag lokal gespeichert! " + selectedDate.formatted(date: .abbreviated, time: .omitted) +
                              " · Dropbox: " + model.syncStatus,
                              systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(TherDiaTheme.ink)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                    }
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
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Zu einem Datum springen", systemImage: "calendar") { showDateJump = true }
                        Button("Berichtswesen", systemImage: "chart.pie") { selectedTab = .reports }
                        Button("Menü öffnen", systemImage: "line.3.horizontal") { selectedTab = .menu }
                    } label: { Label("Menü", systemImage: "line.3.horizontal") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await model.sync() } } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                        .disabled(model.isSyncing || !model.connected)
                        .accessibilityLabel("Jetzt synchronisieren")
                }
            }
            .sheet(isPresented: $showDateJump) {
                NavigationStack {
                    VStack(spacing: 20) {
                        DatePicker("Datum wählen", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        Button("Diesen Tag öffnen") { showDateJump = false }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding(20)
                    .navigationTitle("Zum Datum springen")
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button("Schließen") { showDateJump = false }
                    }}
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
                                savedMessage = model.errorMessage == nil
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
        HStack(spacing: 8) {
            TextField("Medikament", text: name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: .infinity)
            TextField("Menge", text: quantity)
                .textFieldStyle(.roundedBorder)
                .frame(width: 112)
        }
    }

    private func loadDay() {
        let newDraft = model.draft(for: selectedDate)
        draft = newDraft
        lastLoaded = newDraft
        peopleEnabled = !newDraft.people.isEmpty
        newlySynced = false
        savedMessage = false
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
                savedMessage = model.errorMessage == nil
                draft = normalized
                lastLoaded = normalized
                newlySynced = false
            }
        } catch { model.errorMessage = error.localizedDescription }
    }
}
