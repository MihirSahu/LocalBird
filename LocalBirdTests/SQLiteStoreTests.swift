import XCTest

final class SQLiteStoreTests: XCTestCase {
    func testSettingsAndRecordsRoundTrip() throws {
        let root = temporaryDirectory()
        let paths = LocalBirdPaths(root: root)
        try paths.ensureCreated()
        let store = try SQLiteStore(url: paths.database)

        var settings = LocalBirdSettings.defaults
        settings.captureIntervalSeconds = 120
        settings.excludedBundleIDs = ["com.apple.Terminal"]
        try store.saveSettings(settings)
        XCTAssertEqual(try store.loadSettings(), settings)

        let capture = CaptureRecord.fixture(screenshotPath: root.appendingPathComponent("one.png").path)
        try store.insertCapture(capture)
        XCTAssertEqual(try store.recentCaptures(limit: 5).first?.id, capture.id)

        let block = ActivityBlock(
            id: "block-1",
            startTime: capture.capturedAt,
            endTime: capture.capturedAt,
            dominantApps: ["Terminal"],
            dominantWindowTitles: ["Tests"],
            summaryHint: "Testing",
            representativeCaptureIDs: [capture.id],
            createdAt: capture.capturedAt
        )
        try store.insertActivityBlocks([block])
        XCTAssertEqual(try store.activityBlocks(), [block])

        let run = RoutineRun(
            id: "run-1",
            routineType: .daily,
            startedAt: Date(),
            completedAt: Date(),
            inputPacketPath: root.path,
            outputMarkdownPath: root.appendingPathComponent("summary.md").path,
            backend: "opencode",
            status: .completed,
            errorMessage: nil,
            createdAt: Date()
        )
        try store.insertRoutineRun(run)
        XCTAssertEqual(try store.latestRoutineRun(type: .daily)?.id, run.id)
    }
}
