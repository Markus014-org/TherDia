import XCTest
import PDFKit
@testable import TherDia

final class TherDiaTests: XCTestCase {
    private func revision(_ value: String, at timestamp: TimeInterval, device: String = "A") -> FieldRevision {
        FieldRevision(value: value, timestamp: Date(timeIntervalSince1970: timestamp),
                      deviceID: device, changeID: UUID().uuidString)
    }

    func testDifferentFieldsMergeWithoutConflict() {
        var local = DiaryDatabase()
        var remote = DiaryDatabase()
        local.days["2026-11-07"] = DayRecord(fields: [DiaryField.wellbeing.rawValue: revision("0", at: 1)])
        remote.days["2026-11-07"] = DayRecord(fields: [DiaryField.school.rawValue: revision("{}", at: 2)])
        let plan = MergeEngine.plan(local: local, remote: remote)
        XCTAssertTrue(plan.conflicts.isEmpty)
        XCTAssertEqual(plan.merged.days["2026-11-07"]?.fields.count, 2)
    }

    func testSameFieldRequiresApproval() {
        let old = revision("0", at: 10)
        let new = revision("1", at: 20, device: "B")
        let local = DiaryDatabase(days: ["2026-11-07": DayRecord(fields: ["wellbeing": old])])
        let remote = DiaryDatabase(days: ["2026-11-07": DayRecord(fields: ["wellbeing": new])])
        let plan = MergeEngine.plan(local: local, remote: remote)
        XCTAssertEqual(plan.conflicts.count, 1)
        XCTAssertEqual(plan.conflicts.first?.newer.value, "1")
        let accepted = MergeEngine.resolve(plan, acceptNewer: [plan.conflicts[0].id], deviceID: "A")
        XCTAssertEqual(accepted.days["2026-11-07"]?.fields["wellbeing"]?.value, "1")
    }

    func testRejectingNewerCreatesLatestCorrection() {
        let old = revision("0", at: 10)
        let new = revision("1", at: 20)
        let local = DiaryDatabase(days: ["2026-11-07": DayRecord(fields: ["wellbeing": old])])
        let remote = DiaryDatabase(days: ["2026-11-07": DayRecord(fields: ["wellbeing": new])])
        let merged = MergeEngine.resolve(MergeEngine.plan(local: local, remote: remote),
                                         acceptNewer: [], deviceID: "A", now: Date(timeIntervalSince1970: 25))
        XCTAssertEqual(merged.days["2026-11-07"]?.fields["wellbeing"]?.value, "0")
        XCTAssertEqual(merged.days["2026-11-07"]?.fields["wellbeing"]?.timestamp,
                       Date(timeIntervalSince1970: 25))
    }

    func testEncryptionAndWrongPassword() throws {
        let sample = DiaryDatabase(days: ["2026-11-07": DayRecord(fields: [
            "people": revision(try DiaryCodec.encode(["Anna", "Ben"]), at: 20)
        ])])
        let encoded = try CryptoBox.encrypt(sample, password: "Lange sichere Passphrase für Test")
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains("Anna"))
        XCTAssertEqual(try CryptoBox.decrypt(encoded, password: "Lange sichere Passphrase für Test"), sample)
        XCTAssertThrowsError(try CryptoBox.decrypt(encoded, password: "Falsches Passwort"))
    }

    func testOldSingleMedicationDecodesAsList() throws {
        let old = try DiaryCodec.encode(Medication(name: "Testmedikament", quantity: "10 mg"))
        let list = try XCTUnwrap(DiaryCodec.decode(MedicationList.self, old))
        XCTAssertEqual(list.items.count, 1)
        XCTAssertEqual(list.items[0].quantity, "10 mg")
        let new = try DiaryCodec.encode(MedicationList(items: [
            Medication(name: "A", quantity: "5 mg"),
            Medication(name: "B", quantity: "2 mg")
        ]))
        XCTAssertEqual(DiaryCodec.decode(MedicationList.self, new)?.items.count, 2)
    }

    func testOldSchoolEntryPreservesAttendanceMeaning() throws {
        let oldSchool = #"{"attended":false,"online":false,"inPerson":false,"subjects":"Hauptfach"}"#
        let decoded = try XCTUnwrap(DiaryCodec.decode(School.self, oldSchool))
        XCTAssertTrue(decoded.hasSchool)
        XCTAssertFalse(decoded.attended)
        var empty = School()
        empty.hasSchool = false
        let encoded = try DiaryCodec.encode(empty)
        XCTAssertEqual(DiaryCodec.decode(School.self, encoded)?.hasSchool, false)
    }

    func testNewEncounterImpactEncodedSeparately() throws {
        var draft = DayDraft()
        draft.people = ["Anna"]
        draft.peopleImpact = PeopleImpact(affectedWellbeing: true, effect: .good, notes: "Gutes Gespräch")
        let fields = try draft.serializedFields()
        XCTAssertNotNil(fields[.peopleImpact])
        XCTAssertEqual(DiaryCodec.decode(PeopleImpact.self, fields[.peopleImpact])?.effect, .good)
    }
    func testTimedEmergencyMedicationAndLegacyWithoutTime() throws {
        let old = #"{"used":true,"medication":{"name":"Test","quantity":"5 mg"}}"#
        let legacy = try XCTUnwrap(DiaryCodec.decode(RescueMedication.self, old))
        XCTAssertNil(legacy.time)
        let timed = RescueMedication(used: true, medication: Medication(name: "Test", quantity: "5 mg"), time: "08:30")
        let json = try DiaryCodec.encode(timed)
        XCTAssertEqual(DiaryCodec.decode(RescueMedication.self, json)?.time, "08:30")
    }

    func testBothAggressionCategoriesWithSeparateNotes() throws {
        var behavior = AggressiveBehavior()
        behavior.happened = true
        behavior.selfInjurious = true
        behavior.otherAggressive = true
        behavior.selfDescription = "Selbstverletzendes Verhalten"
        behavior.otherDescription = "Fremdaggressives Verhalten"
        let json = try DiaryCodec.encode(behavior)
        let decoded = try XCTUnwrap(DiaryCodec.decode(AggressiveBehavior.self, json))
        XCTAssertTrue(decoded.selfInjurious)
        XCTAssertTrue(decoded.otherAggressive)
        XCTAssertNotEqual(decoded.selfDescription, decoded.otherDescription)
    }

    func testScreenTimeHalfHourAndOptionalValue() throws {
        var draft = DayDraft()
        XCTAssertNil(draft.screenTime.halfHours)
        draft.screenTime.halfHours = 5
        XCTAssertEqual(draft.screenTime.hoursText, "2,5 Stunden")
        let fields = try draft.serializedFields()
        XCTAssertEqual(DiaryCodec.decode(ScreenTime.self, fields[.screenTime])?.halfHours, 5)
        draft.screenTime.halfHours = 0
        XCTAssertEqual(draft.screenTime.hoursText, "0 Stunden")
    }

    func testOlderInjuryFieldIsNotReclassified() throws {
        var old = DiaryDatabase()
        let original = FieldRevision(value: try DiaryCodec.encode(Injuries(happened: true, details: "Alter Eintrag")),
                                     timestamp: .now, deviceID: "device", changeID: UUID().uuidString)
        old.days["2026-11-08"] = DayRecord(fields: [DiaryField.injuries.rawValue: original])
        let record = try XCTUnwrap(old.days["2026-11-08"])
        let draft = record.draft()
        XCTAssertFalse(draft.aggression.happened)
        XCTAssertNil(record.field(.aggression))
        XCTAssertNil(try draft.serializedFields()[.injuries])
        XCTAssertNotNil(record.field(.injuries))
    }

    func testPDFDateRangeDoesNotLeakOtherDays() throws {
        let a = DayRecord(fields: [DiaryField.wellbeing.rawValue: FieldRevision(value: "0", timestamp: .now, deviceID: "a", changeID: "a")])
        let database = DiaryDatabase(days: ["2026-11-01": a, "2026-11-02": a])
        let start = try XCTUnwrap(DiaryCodec.date(from: "2026-11-02"))
        let selected = PDFReportData.selectedDays(in: database, from: start, through: start)
        XCTAssertEqual(selected.count, 1)
    }

    func testGeneratedPDFHasHeaderSelectedPartsAndNoUnselectedDetails() throws {
        let day = DayRecord(fields: [
            DiaryField.wellbeing.rawValue: revision(try DiaryCodec.encode(Wellbeing.good), at: 20),
            DiaryField.screenTime.rawValue: revision(try DiaryCodec.encode(ScreenTime(halfHours: 5)), at: 20)
        ])
        let date = try XCTUnwrap(DiaryCodec.date(from: "2026-11-08"))
        let options = PDFReportOptions(
            patientName: "Testperson",
            startDate: date,
            endDate: date,
            parts: [.overview, .screenTime],
            showNames: false,
            showNotes: false
        )
        let url = try PDFReportBuilder.create(days: [
            PDFReportDay(date: date, record: day, draft: day.draft())
        ], options: options)
        defer { try? FileManager.default.removeItem(at: url) }
        let pdf = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertGreaterThanOrEqual(pdf.pageCount, 1)
        let text = pdf.string ?? ""
        XCTAssertTrue(text.contains("TherDia"))
        XCTAssertTrue(text.contains("Testperson"))
        XCTAssertTrue(text.contains("Bildschirmzeit"))
        XCTAssertFalse(text.contains("Tagebucheinträge nach Datum"))
    }

    func testOptionalRescueTimeValidation() {
        var draft = DayDraft()
        draft.baseMedication = MedicationList(items: [Medication(name: "Basis", quantity: "5 mg")])
        draft.rescueMedication = RescueMedication(used: true,
            medication: Medication(name: "Notmedikament", quantity: "10 mg"), time: nil)
        draft.normalize()
        XCTAssertNil(draft.validationError)

        draft.rescueMedication.time = "08:30"
        XCTAssertNil(draft.validationError)
        draft.rescueMedication.time = "25:70"
        XCTAssertNotNil(draft.validationError)

        draft.rescueMedication.time = " "
        draft.normalize()
        XCTAssertNil(draft.rescueMedication.time)
        XCTAssertNil(draft.validationError)
    }

    func testReminderSettingsPersistAndKeepWheelTime() throws {
        var settings = ReminderSettings()
        XCTAssertFalse(settings.enabled)
        settings.enabled = true
        settings.hour = 17
        settings.minute = 45
        settings.mode = .visual
        settings.tone = .bell
        let encoded = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(ReminderSettings.self, from: encoded)
        XCTAssertEqual(restored.timeLabel, "17:45")
        XCTAssertEqual(restored.mode, .visual)
        XCTAssertFalse(restored.mode.usesSound)
        XCTAssertEqual(restored.tone, .bell)
        let fromWheel = restored.wheelValue
        var updated = restored
        updated.setWheelValue(fromWheel)
        XCTAssertEqual(updated.hour, 17)
        XCTAssertEqual(updated.minute, 45)
    }

    func testNotificationSoundFilesAreBundled() {
        // The XcodeGen-generated app must copy these WAV resources into the app.
        XCTAssertNotNil(Bundle.main.url(forResource: "TherDiaGentle", withExtension: "wav"))
        XCTAssertNotNil(Bundle.main.url(forResource: "TherDiaBell", withExtension: "wav"))
    }

    func testRescueWellbeingAndNotesAreBackwardCompatible() throws {
        let old = #"{"used":true,"medication":{"name":"Notfall","quantity":"5 mg"},"time":"10:30"}"#
        let legacy = try XCTUnwrap(DiaryCodec.decode(RescueMedication.self, old))
        XCTAssertNil(legacy.wellbeingAfter)
        XCTAssertEqual(legacy.wellbeingNotes, "")

        var draft = DayDraft()
        draft.rescueMedication = RescueMedication(
            used: true, medication: Medication(name: "Notfall", quantity: "5 mg"),
            time: "10:30", wellbeingAfter: .good, wellbeingNotes: "Danach ruhiger"
        )
        let serialized = try draft.serializedFields()
        let restored = try XCTUnwrap(DiaryCodec.decode(RescueMedication.self, serialized[.rescueMedication]))
        XCTAssertEqual(restored.wellbeingAfter, .good)
        XCTAssertEqual(restored.wellbeingNotes, "Danach ruhiger")
        XCTAssertTrue(restored.summary.contains("Danach ruhiger"))
        draft.rescueMedication.used = false
        draft.normalize()
        XCTAssertNil(draft.rescueMedication.wellbeingAfter)
        XCTAssertTrue(draft.rescueMedication.wellbeingNotes.isEmpty)
    }

    func testReminderSchedulesHalfHourlyAfterInitialAlertWithoutAppRunning() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 0, minute: 0)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 20, minute: 5)))
        let times = ReminderSchedule.dates(on: day, hour: 20, minute: 0, now: now, calendar: calendar)
        XCTAssertGreaterThanOrEqual(times.count, 6)
        XCTAssertEqual(calendar.component(.hour, from: times[0]), 20)
        XCTAssertEqual(calendar.component(.minute, from: times[0]), 30)
        XCTAssertEqual(times[1].timeIntervalSince(times[0]), 30 * 60)
    }

    func testReminderSnoozeIsReplannedFromChosenTime() throws {
        let calendar = Calendar(identifier: .gregorian)
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10)))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 20, minute: 5)))
        let snooze = now.addingTimeInterval(15 * 60)
        let times = ReminderSchedule.dates(on: day, hour: 20, minute: 0, now: now,
                                          snoozeUntil: snooze, calendar: calendar)
        XCTAssertEqual(times.first, snooze)
        XCTAssertEqual(times[1].timeIntervalSince(times[0]), 30 * 60)
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        XCTAssertTrue(times.allSatisfy { $0 < nextDay })
    }

    func testTestFlightVersionComparisonForSameMarketingVersion() {
        XCTAssertTrue(TestFlightVersionLogic.isNewer(
            availableVersion: "1.0.0", availableBuild: "12",
            installedVersion: "1.0.0", installedBuild: "9"))
        XCTAssertFalse(TestFlightVersionLogic.isNewer(
            availableVersion: "1.0.0", availableBuild: "9",
            installedVersion: "1.0.0", installedBuild: "9"))
        XCTAssertFalse(TestFlightVersionLogic.isNewer(
            availableVersion: "1.0.0", availableBuild: "8",
            installedVersion: "1.0.0", installedBuild: "9"))
    }

    func testTestFlightVersionComparisonAcrossMarketingVersions() {
        XCTAssertTrue(TestFlightVersionLogic.isNewer(
            availableVersion: "1.1.0", availableBuild: "1",
            installedVersion: "1.0.0", installedBuild: "99"))
        XCTAssertFalse(TestFlightVersionLogic.isNewer(
            availableVersion: "1.0.0", availableBuild: "99",
            installedVersion: "1.1.0", installedBuild: "1"))
        XCTAssertFalse(TestFlightVersionLogic.isNewer(
            availableVersion: "invalid", availableBuild: "20",
            installedVersion: "1.0.0", installedBuild: "1"))
    }

}
