import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var capture: CaptureController
    @EnvironmentObject private var routine: RoutineRunner

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()
            statusGrid
            actionBar
            privacyNotice
            summaryPanel
        }
        .padding(24)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LocalBird")
                .font(.largeTitle.bold())
            Text("Local screenshots and OCR stay on this Mac. Daily routine generation may send selected packet content through opencode to its configured model provider.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var statusGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 10) {
            GridRow {
                statusLabel("Capture", capture.status.label)
                statusLabel("Last Capture", capture.status.lastCaptureAt.map(DateFormatter.localBirdTimestamp.string) ?? "None")
            }
            GridRow {
                statusLabel("OCR", capture.status.lastOCRAt.map(DateFormatter.localBirdTimestamp.string) ?? "None")
                statusLabel("Daily Routine", routine.isRunning ? "Running" : routine.latestRun?.status.rawValue.capitalized ?? "Not run")
            }
            if let error = capture.status.lastError ?? routine.lastError ?? state.settingsError {
                GridRow {
                    statusLabel("Latest Error", error)
                        .gridCellColumns(2)
                }
            }
        }
    }

    private func statusLabel(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
                .lineLimit(2)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                state.runDailyRoutine()
            } label: {
                Label("Run Daily Routine Now", systemImage: "play.fill")
            }
            .disabled(routine.isRunning)

            Button {
                state.toggleCapturePause()
            } label: {
                Label(capture.status.isPaused ? "Resume Capture" : "Pause Capture", systemImage: capture.status.isPaused ? "play.circle" : "pause.circle")
            }

            Button {
                state.openLatestOverview()
            } label: {
                Label("Open Latest Overview", systemImage: "doc.text")
            }
            .disabled(routine.latestRun?.outputMarkdownPath == nil)

            Button {
                state.open(state.paths.root)
            } label: {
                Label("Open Data Folder", systemImage: "folder")
            }

            Button {
                state.open(routine.latestPacketURL)
            } label: {
                Label("Open Latest Packet", systemImage: "shippingbox")
            }
            .disabled(routine.latestPacketURL == nil)
        }
    }

    private var privacyNotice: some View {
        Text("Storage: \(state.paths.root.path)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Daily Overview")
                .font(.headline)
            ScrollView {
                Text(routine.latestMarkdown.isEmpty ? "No daily overview generated yet." : routine.latestMarkdown)
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(12)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
