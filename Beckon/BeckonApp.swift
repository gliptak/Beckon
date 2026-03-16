import AppKit
import SwiftUI

@main
struct BeckonApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = SettingsModel()

    var body: some Scene {
        MenuBarExtra("Beckon", systemImage: "cursorarrow.motionlines") {
            MenuBarView(settings: settings)
                .frame(minWidth: 280)
                .onAppear {
                    // Keep the manager in sync with initial persisted preferences.
                    syncManagerFromSettings()
                }
                .onChange(of: settings.isEnabled) { _ in
                    syncManagerFromSettings()
                }
                .onChange(of: settings.hoverDelayMilliseconds) { _ in
                    syncManagerFromSettings()
                }
                .onChange(of: settings.raiseOnFocus) { _ in
                    syncManagerFromSettings()
                }
        }
        .menuBarExtraStyle(.window)
    }

    private func syncManagerFromSettings() {
        let manager = FocusFollowsMouseManager.shared
        manager.hoverDelayMilliseconds = settings.hoverDelayMilliseconds
        manager.raiseOnFocus = settings.raiseOnFocus
        manager.setEnabled(settings.isEnabled)
    }
}

