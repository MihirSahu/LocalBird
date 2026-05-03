import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var excludedText = ""

    var body: some View {
        Form {
            Toggle("Capture enabled", isOn: $state.settings.captureEnabled)

            Picker("Capture interval", selection: $state.settings.captureIntervalSeconds) {
                Text("15 seconds").tag(TimeInterval(15))
                Text("30 seconds").tag(TimeInterval(30))
                Text("1 minute").tag(TimeInterval(60))
                Text("2 minutes").tag(TimeInterval(120))
                Text("5 minutes").tag(TimeInterval(300))
                Text("10 minutes").tag(TimeInterval(600))
            }

            Stepper("Screenshot retention: \(state.settings.screenshotRetentionDays) days", value: $state.settings.screenshotRetentionDays, in: 1...365)
            Stepper("OCR retention: \(state.settings.ocrRetentionDays) days", value: $state.settings.ocrRetentionDays, in: 1...365)
            Stepper("Representative screenshots: \(state.settings.maxDailyRepresentativeScreenshots)", value: $state.settings.maxDailyRepresentativeScreenshots, in: 1...100)

            VStack(alignment: .leading) {
                Text("Excluded app bundle IDs")
                TextEditor(text: $excludedText)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 90)
                    .onChange(of: excludedText) { _, value in
                        state.settings.excludedBundleIDs = value
                            .split(whereSeparator: \.isNewline)
                            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                    }
            }

            LabeledContent("Storage folder", value: state.paths.root.path)
            LabeledContent("opencode", value: opencodeStatus)

            HStack {
                Button("Save Settings") {
                    state.saveSettings()
                }
                Button("Open Data Folder") {
                    state.open(state.paths.root)
                }
            }

            if let error = state.settingsError {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .onAppear {
            excludedText = state.settings.excludedBundleIDs.joined(separator: "\n")
        }
    }

    private var opencodeStatus: String {
        do {
            return try OpencodeRoutineSummarizer.findOpencode().path
        } catch {
            return "Not found"
        }
    }
}
