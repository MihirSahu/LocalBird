import Foundation

enum RoutineType: String, Codable, CaseIterable, Sendable {
    case daily
    case weekly
}

enum RoutineStatus: String, Codable, Sendable {
    case pending
    case running
    case completed
    case failed
}

struct LocalBirdSettings: Equatable, Codable, Sendable {
    var captureEnabled: Bool
    var captureIntervalSeconds: TimeInterval
    var screenshotRetentionDays: Int
    var ocrRetentionDays: Int
    var summaryRetentionDays: Int?
    var excludedBundleIDs: [String]
    var maxDailyRepresentativeScreenshots: Int

    static let defaults = LocalBirdSettings(
        captureEnabled: true,
        captureIntervalSeconds: 60,
        screenshotRetentionDays: 30,
        ocrRetentionDays: 90,
        summaryRetentionDays: nil,
        excludedBundleIDs: [],
        maxDailyRepresentativeScreenshots: 30
    )
}

struct CaptureRecord: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var capturedAt: Date
    var activeAppBundleID: String?
    var activeAppName: String?
    var windowTitle: String?
    var displayID: String?
    var screenshotPath: String
    var ocrText: String?
    var perceptualHash: String?
    var isDuplicate: Bool
    var privacyRedacted: Bool
    var createdAt: Date
}

struct ActivityBlock: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var startTime: Date
    var endTime: Date
    var dominantApps: [String]
    var dominantWindowTitles: [String]
    var summaryHint: String
    var representativeCaptureIDs: [String]
    var createdAt: Date
}

struct RoutineRun: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var routineType: RoutineType
    var startedAt: Date
    var completedAt: Date?
    var inputPacketPath: String
    var outputMarkdownPath: String?
    var backend: String
    var status: RoutineStatus
    var errorMessage: String?
    var createdAt: Date
}

struct RoutineResult: Equatable, Sendable {
    var outputMarkdownURL: URL
    var markdown: String
}

struct CaptureStatus: Equatable, Sendable {
    var isRunning: Bool = false
    var isPaused: Bool = false
    var lastCaptureAt: Date?
    var lastOCRAt: Date?
    var lastError: String?

    var label: String {
        if isPaused { return "Paused" }
        if isRunning { return "Capturing" }
        return "Stopped"
    }
}

struct RoutinePacket: Equatable, Sendable {
    var folderURL: URL
    var outputURL: URL
}

enum LocalBirdError: LocalizedError {
    case applicationSupportUnavailable
    case screenContentUnavailable
    case imageEncodingFailed
    case sqlite(String)
    case noCapturesForRoutine
    case opencodeUnavailable
    case opencodeFailed(String)
    case outputMissing

    var errorDescription: String? {
        switch self {
        case .applicationSupportUnavailable:
            return "Could not locate the Application Support folder."
        case .screenContentUnavailable:
            return "No capturable screen content was available."
        case .imageEncodingFailed:
            return "Could not encode the screenshot as PNG."
        case .sqlite(let message):
            return "SQLite error: \(message)"
        case .noCapturesForRoutine:
            return "There are no captures available for this routine."
        case .opencodeUnavailable:
            return "Could not find the opencode executable."
        case .opencodeFailed(let message):
            return "opencode failed: \(message)"
        case .outputMissing:
            return "opencode did not write output.md."
        }
    }
}
