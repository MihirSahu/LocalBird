import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit

@MainActor
final class CaptureController: ObservableObject {
    @Published private(set) var status = CaptureStatus()

    private let paths: LocalBirdPaths
    private let store: SQLiteStore
    private let ocrService: OCRService
    private let metadataService: MetadataService
    private let hasher: ImageHasher
    private var captureTask: Task<Void, Never>?

    init(
        paths: LocalBirdPaths,
        store: SQLiteStore,
        ocrService: OCRService = OCRService(),
        metadataService: MetadataService = MetadataService(),
        hasher: ImageHasher = ImageHasher()
    ) {
        self.paths = paths
        self.store = store
        self.ocrService = ocrService
        self.metadataService = metadataService
        self.hasher = hasher
    }

    func start(settings: LocalBirdSettings) {
        guard captureTask == nil else { return }
        status.isRunning = true
        status.isPaused = false
        captureTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if settings.captureEnabled {
                    await self.captureOnce(settings: settings)
                }
                let interval = UInt64(max(settings.captureIntervalSeconds, 15) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: interval)
            }
        }
    }

    func stop() {
        captureTask?.cancel()
        captureTask = nil
        status.isRunning = false
        status.isPaused = false
    }

    func togglePause(settings: LocalBirdSettings) {
        if status.isPaused {
            start(settings: settings)
        } else {
            captureTask?.cancel()
            captureTask = nil
            status.isRunning = false
            status.isPaused = true
        }
    }

    func captureOnce(settings: LocalBirdSettings) async {
        do {
            let metadata = metadataService.activeWindowMetadata()
            if let bundleID = metadata.bundleID, settings.excludedBundleIDs.contains(bundleID) {
                return
            }

            let (image, displayID) = try await screenshot()
            let hash = hasher.averageHash(for: image)
            let duplicate = try hasher.isDuplicate(hash, store.latestCaptureHash())
            guard let data = image.pngData() else {
                throw LocalBirdError.imageEncodingFailed
            }

            let now = Date()
            let id = UUID().uuidString
            let time = DateFormatter.localBirdFilenameTime.string(from: now)
            let appSlug = (metadata.appName ?? "unknown").slugForFilename()
            let fileURL = paths.screenshots.appendingPathComponent("\(time)-\(appSlug)-\(id.prefix(8)).png")
            try data.write(to: fileURL, options: .atomic)

            let ocr = try await ocrService.recognizeText(in: image)
            let record = CaptureRecord(
                id: id,
                capturedAt: now,
                activeAppBundleID: metadata.bundleID,
                activeAppName: metadata.appName,
                windowTitle: metadata.windowTitle,
                displayID: displayID,
                screenshotPath: fileURL.path,
                ocrText: ocr,
                perceptualHash: hash,
                isDuplicate: duplicate,
                privacyRedacted: false,
                createdAt: now
            )
            try store.insertCapture(record)
            status.lastCaptureAt = now
            status.lastOCRAt = now
            status.lastError = nil
        } catch {
            status.lastError = error.localizedDescription
        }
    }

    private func screenshot() async throws -> (CGImage, String?) {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw LocalBirdError.screenContentUnavailable
        }
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        if #available(macOS 14.2, *) {
            filter.includeMenuBar = true
        }
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return (image, String(display.displayID))
    }
}
