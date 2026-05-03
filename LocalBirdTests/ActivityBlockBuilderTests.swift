import XCTest

final class ActivityBlockBuilderTests: XCTestCase {
    func testGroupsByAppSwitchAndTimeGap() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let captures = [
            CaptureRecord.fixture(id: "a", capturedAt: base, app: "Xcode", bundle: "com.apple.dt.Xcode"),
            CaptureRecord.fixture(id: "b", capturedAt: base.addingTimeInterval(60), app: "Xcode", bundle: "com.apple.dt.Xcode"),
            CaptureRecord.fixture(id: "c", capturedAt: base.addingTimeInterval(180), app: "Terminal", bundle: "com.apple.Terminal"),
            CaptureRecord.fixture(id: "d", capturedAt: base.addingTimeInterval(2_000), app: "Terminal", bundle: "com.apple.Terminal")
        ]

        let blocks = ActivityBlockBuilder(gapThreshold: 15 * 60).buildBlocks(from: captures)

        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].representativeCaptureIDs, ["a", "b"])
        XCTAssertEqual(blocks[1].dominantApps, ["Terminal"])
    }

    func testSkipsDuplicateCaptures() {
        let captures = [
            CaptureRecord.fixture(id: "a"),
            CaptureRecord.fixture(id: "b", isDuplicate: true)
        ]

        let blocks = ActivityBlockBuilder().buildBlocks(from: captures)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].representativeCaptureIDs, ["a"])
    }
}
