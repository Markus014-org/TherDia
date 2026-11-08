import Foundation

struct LocalStore {
    private let fileName = "therdia-cache.enc"
    private var url: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent(fileName)
    }

    func read(password: String) throws -> DiaryDatabase {
        guard FileManager.default.fileExists(atPath: url.path) else { return DiaryDatabase() }
        return try CryptoBox.decrypt(Data(contentsOf: url), password: password)
    }

    func write(_ database: DiaryDatabase, password: String) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try CryptoBox.encrypt(database, password: password)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }

    func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}
