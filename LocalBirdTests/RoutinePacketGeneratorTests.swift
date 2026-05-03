import XCTest

final class RoutinePacketGeneratorTests: XCTestCase {
    func testGeneratesDailyPacketFiles() throws {
        let root = temporaryDirectory()
        let paths = LocalBirdPaths(root: root)
        try paths.ensureCreated()
        let imageURL = root.appendingPathComponent("source.png")
        try testImage(color: .black).pngData()?.write(to: imageURL)

        let capture = CaptureRecord.fixture(id: "capture-1", screenshotPath: imageURL.path)
        let block = ActivityBlock(
            id: "block-1",
            startTime: capture.capturedAt,
            endTime: capture.capturedAt,
            dominantApps: ["Xcode"],
            dominantWindowTitles: ["LocalBird"],
            summaryHint: "Building LocalBird",
            representativeCaptureIDs: [capture.id],
            createdAt: Date()
        )

        let packet = try RoutinePacketGenerator(paths: paths).generateDailyPacket(
            for: capture.capturedAt,
            captures: [capture],
            blocks: [block],
            representativeIDs: [capture.id]
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: packet.folderURL.appendingPathComponent("AGENTS.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: packet.folderURL.appendingPathComponent("prompt.md").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: packet.folderURL.appendingPathComponent("timeline.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: packet.outputURL.path))
    }
}
