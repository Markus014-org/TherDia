import Foundation

struct SyncConflict: Identifiable, Equatable {
    let dayKey: String
    let field: DiaryField
    let local: FieldRevision
    let remote: FieldRevision

    var id: String { "\(dayKey)|\(field.rawValue)" }
    var newer: FieldRevision { isLocalNewer ? local : remote }
    var older: FieldRevision { isLocalNewer ? remote : local }
    var isLocalNewer: Bool { MergeEngine.isNewer(local, than: remote) }
}

struct MergePlan {
    var merged: DiaryDatabase
    var conflicts: [SyncConflict]
}

enum MergeEngine {
    // Deterministic tie-breaker protects replicas against identical clocks.
    static func isNewer(_ a: FieldRevision, than b: FieldRevision) -> Bool {
        if a.timestamp != b.timestamp { return a.timestamp > b.timestamp }
        if a.deviceID != b.deviceID { return a.deviceID > b.deviceID }
        return a.changeID > b.changeID
    }

    static func plan(local: DiaryDatabase, remote: DiaryDatabase) -> MergePlan {
        var merged = remote
        var conflicts: [SyncConflict] = []
        for (day, localDay) in local.days {
            var result = merged.days[day] ?? DayRecord()
            for (key, localField) in localDay.fields {
                guard let remoteField = result.fields[key] else {
                    result.fields[key] = localField
                    continue
                }
                if remoteField.changeID == localField.changeID { continue }
                if remoteField.value == localField.value {
                    result.fields[key] = isNewer(localField, than: remoteField) ? localField : remoteField
                    continue
                }
                guard let field = DiaryField(rawValue: key) else { continue }
                conflicts.append(SyncConflict(dayKey: day, field: field, local: localField, remote: remoteField))
                // Pending explicit approval, leave remote untouched.
            }
            merged.days[day] = result
        }
        conflicts.sort { a, b in
            if a.dayKey != b.dayKey { return a.dayKey > b.dayKey }
            return a.field.rawValue < b.field.rawValue
        }
        return MergePlan(merged: merged, conflicts: conflicts)
    }

    // `acceptNewer` contains IDs of explicitly approved newer revisions.
    // Rejecting one makes the older value a NEW deliberate decision (new clock),
    // preventing stale replicas from silently restoring the rejected value.
    static func resolve(_ plan: MergePlan, acceptNewer: Set<String>, deviceID: String, now: Date = .now) -> DiaryDatabase {
        var result = plan.merged
        for conflict in plan.conflicts {
            var day = result.days[conflict.dayKey] ?? DayRecord()
            if acceptNewer.contains(conflict.id) {
                day.fields[conflict.field.rawValue] = conflict.newer
            } else {
                var selected = conflict.older
                selected.timestamp = max(now, conflict.newer.timestamp.addingTimeInterval(0.001))
                selected.deviceID = deviceID
                selected.changeID = UUID().uuidString
                day.fields[conflict.field.rawValue] = selected
            }
            result.days[conflict.dayKey] = day
        }
        return result
    }
}
