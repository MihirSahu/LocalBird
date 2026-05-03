import Foundation

struct LocalBirdPaths: Sendable {
    let root: URL
    let database: URL
    let screenshots: URL
    let routineRuns: URL
    let summaries: URL
    let logs: URL

    static func live(fileManager: FileManager = .default) throws -> LocalBirdPaths {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw LocalBirdError.applicationSupportUnavailable
        }
        return LocalBirdPaths(root: appSupport.appendingPathComponent("LocalBird", isDirectory: true))
    }

    init(root: URL) {
        self.root = root
        database = root.appendingPathComponent("LocalBird.sqlite")
        screenshots = root.appendingPathComponent("screenshots", isDirectory: true)
        routineRuns = root.appendingPathComponent("routine-runs", isDirectory: true)
        summaries = root.appendingPathComponent("summaries", isDirectory: true)
        logs = root.appendingPathComponent("logs", isDirectory: true)
    }

    func ensureCreated(fileManager: FileManager = .default) throws {
        for directory in [root, screenshots, routineRuns, summaries, logs] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}

extension DateFormatter {
    static let localBirdDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let localBirdTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static let localBirdFilenameTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH-mm-ss"
        return formatter
    }()
}
