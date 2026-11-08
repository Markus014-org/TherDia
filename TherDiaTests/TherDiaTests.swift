import XCTest
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
        let oldSchool = #"{\"attended\":false,\"online\":false,\"inPerson\":false,\"subjects\":\"Hauptfach\"}"#
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
}
