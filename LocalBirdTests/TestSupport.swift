import AppKit
import Foundation
import XCTest

extension XCTestCase {
    func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    func testImage(color: NSColor) throws -> CGImage {
        let size = CGSize(width: 16, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            XCTFail("Could not create test image")
            throw NSError(domain: "LocalBirdTests", code: 1)
        }
        return cgImage
    }
}

extension CaptureRecord {
    static func fixture(
        id: String = UUID().uuidString,
        capturedAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
        app: String = "Xcode",
        bundle: String = "com.apple.dt.Xcode",
        screenshotPath: String = "/tmp/screenshot.png",
        isDuplicate: Bool = false
    ) -> CaptureRecord {
        CaptureRecord(
            id: id,
            capturedAt: capturedAt,
            activeAppBundleID: bundle,
            activeAppName: app,
            windowTitle: "LocalBird",
            displayID: "1",
            screenshotPath: screenshotPath,
            ocrText: "Visible OCR text from the app",
            perceptualHash: "ffffffffffffffff",
            isDuplicate: isDuplicate,
            privacyRedacted: false,
            createdAt: capturedAt
        )
    }
}
