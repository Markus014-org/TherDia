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
}
