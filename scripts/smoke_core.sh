#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/main.swift" <<'SWIFT'
import Foundation
func revision(_ value: String, time: TimeInterval, device: String) -> FieldRevision {
    FieldRevision(value: value, timestamp: Date(timeIntervalSince1970: time),
                  deviceID: device, changeID: UUID().uuidString)
}
let older = revision("3", time: 100, device: "A")
let newer = revision("4", time: 200, device: "B")
let local = DiaryDatabase(days: ["2026-11-08": DayRecord(fields: ["wellbeing": older])])
let remote = DiaryDatabase(days: ["2026-11-08": DayRecord(fields: ["wellbeing": newer])])
let plan = MergeEngine.plan(local: local, remote: remote)
assert(plan.conflicts.count == 1)
assert(plan.conflicts[0].newer == newer)
assert(MergeEngine.resolve(plan, acceptNewer: [plan.conflicts[0].id], deviceID: "A")
    .days["2026-11-08"]?.field(.wellbeing)?.value == "4")
let oldDecision = MergeEngine.resolve(plan, acceptNewer: [], deviceID: "A")
assert(oldDecision.days["2026-11-08"]?.field(.wellbeing)?.value == "3")
assert(oldDecision.days["2026-11-08"]!.field(.wellbeing)!.timestamp > newer.timestamp)
let disjoint = DiaryDatabase(days: ["2026-11-08": DayRecord(fields: ["school": revision("{}", time: 300, device: "C")])])
let merged = MergeEngine.plan(local: disjoint, remote: remote)
assert(merged.conflicts.isEmpty)
assert(merged.merged.days["2026-11-08"]?.fields.count == 2)
print("Core model/merge smoke tests passed")
SWIFT
swiftc TherDia/Models/DiaryModels.swift TherDia/Services/MergeEngine.swift "$tmp/main.swift" -o "$tmp/smoke"
"$tmp/smoke"
