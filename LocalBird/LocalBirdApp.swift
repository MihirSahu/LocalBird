import SwiftUI

@main
struct LocalBirdApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(state)
                .environmentObject(state.captureController)
                .environmentObject(state.routineRunner)
                .frame(minWidth: 760, minHeight: 560)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(state)
                .frame(width: 560, height: 460)
        }

        MenuBarExtra("LocalBird", systemImage: state.captureController.status.isPaused ? "pause.circle" : "bird") {
            MenuBarContent()
                .environmentObject(state)
                .environmentObject(state.captureController)
                .environmentObject(state.routineRunner)
        }
    }
}
