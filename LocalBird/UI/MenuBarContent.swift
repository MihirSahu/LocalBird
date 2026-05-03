import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var capture: CaptureController
    @EnvironmentObject private var routine: RoutineRunner

    var body: some View {
        Text("Capture: \(capture.status.label)")
        Button(capture.status.isPaused ? "Resume Capture" : "Pause Capture") {
            state.toggleCapturePause()
        }
        Divider()
        Button("Run Daily Routine Now") {
            state.runDailyRoutine()
        }
        .disabled(routine.isRunning)
        Button("Open Latest Overview") {
            state.openLatestOverview()
        }
        .disabled(routine.latestRun?.outputMarkdownPath == nil)
        Button("Open LocalBird") {
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Open Data Folder") {
            state.open(state.paths.root)
        }
        Divider()
        Button("Quit") {
            NSApp.terminate(nil)
        }
    }
}
