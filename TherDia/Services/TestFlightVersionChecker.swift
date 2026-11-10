import Foundation
import Combine

/// Checks a credential-free status manifest published from Apple's actual
/// App Store Connect TestFlight internal-testing state by GitHub Actions.
/// No App Store Connect credentials are ever shipped to the iPhone.
struct TestFlightAvailability: Decodable {
    let schemaVersion: Int
    let bundleId: String
    let availableVersion: String?
    let availableBuild: String?
}

enum TestFlightVersionLogic {
    static func isNewer(availableVersion: String, availableBuild: String,
                        installedVersion: String, installedBuild: String) -> Bool {
        let lhs = availableVersion.split(separator: ".", omittingEmptySubsequences: false)
        let rhs = installedVersion.split(separator: ".", omittingEmptySubsequences: false)
        let length = max(lhs.count, rhs.count)
        for i in 0..<length {
            let left = i < lhs.count ? Int(lhs[i]) : 0
            let right = i < rhs.count ? Int(rhs[i]) : 0
            // Fail closed for unsupported version strings.
            guard let left, let right else { return false }
            if left != right { return left > right }
        }
        guard let latest = Int(availableBuild), let current = Int(installedBuild) else {
            return false
        }
        return latest > current
    }
}

@MainActor
final class TestFlightVersionChecker: ObservableObject {
    @Published private(set) var updateAvailable = false
    @Published private(set) var newBuild: String?

    private let manifestURL = URL(string:
        "https://raw.githubusercontent.com/Markus014-org/TherDia/main/testflight-availability.json"
    )!
    private var lastChecked: Date = .distantPast
    private var isChecking = false

    func refresh() async {
        // Recheck after opening the app, but avoid repeated network requests
        // triggered by rapid SwiftUI scene transitions.
        guard !isChecking, Date.now.timeIntervalSince(lastChecked) >= 300 else { return }
        isChecking = true
        defer { isChecking = false }
        lastChecked = .now

        var request = URLRequest(url: manifestURL)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  data.count < 4096 else { return }
            let manifest = try JSONDecoder().decode(TestFlightAvailability.self, from: data)
            let bundle = Bundle.main.bundleIdentifier ?? ""
            guard manifest.schemaVersion == 1, manifest.bundleId == bundle else { return }
            guard let availableVersion = manifest.availableVersion,
                  let availableBuild = manifest.availableBuild else {
                updateAvailable = false
                newBuild = nil
                return
            }
            let installedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            let installedBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
            let newer = TestFlightVersionLogic.isNewer(
                availableVersion: availableVersion,
                availableBuild: availableBuild,
                installedVersion: installedVersion,
                installedBuild: installedBuild
            )
            updateAvailable = newer
            newBuild = newer ? availableBuild : nil
        } catch {
            // A network outage cannot prove an update exists. Never invent
            // availability or show an error over the diary.
            updateAvailable = false
            newBuild = nil
        }
    }
}
