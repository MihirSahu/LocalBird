import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var settings: LocalBirdSettings
    @Published var settingsError: String?

    let paths: LocalBirdPaths
    let store: SQLiteStore
    let captureController: CaptureController
    let routineRunner: RoutineRunner

    init() {
        do {
            let paths = try LocalBirdPaths.live()
            try paths.ensureCreated()
            let store = try SQLiteStore(url: paths.database)
            let settings = try store.loadSettings()
            self.paths = paths
            self.store = store
            self.settings = settings
            let capture = CaptureController(paths: paths, store: store)
            self.captureController = capture
            let builder = ActivityBlockBuilder(maxRepresentatives: settings.maxDailyRepresentativeScreenshots)
            let packetGenerator = RoutinePacketGenerator(paths: paths)
            self.routineRunner = RoutineRunner(
                paths: paths,
                store: store,
                blockBuilder: builder,
                packetGenerator: packetGenerator,
                summarizer: OpencodeRoutineSummarizer()
            )
            if settings.captureEnabled, !Self.isRunningUnitTests {
                capture.start(settings: settings)
            }
        } catch {
            fatalError("LocalBird failed to initialize: \(error.localizedDescription)")
        }
    }

    func saveSettings() {
        do {
            try store.saveSettings(settings)
            settingsError = nil
            if settings.captureEnabled, !captureController.status.isPaused {
                captureController.stop()
                captureController.start(settings: settings)
            } else if !settings.captureEnabled {
                captureController.stop()
            }
        } catch {
            settingsError = error.localizedDescription
        }
    }

    func toggleCapturePause() {
        captureController.togglePause(settings: settings)
    }

    func runDailyRoutine() {
        Task {
            await routineRunner.runDailyNow()
        }
    }

    func open(_ url: URL?) {
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    func openLatestOverview() {
        guard let path = routineRunner.latestRun?.outputMarkdownPath else { return }
        open(URL(fileURLWithPath: path))
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
