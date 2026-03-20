import ApplicationServices
import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings: SettingsModel
    @State private var permissionState: Bool = AXIsProcessTrusted()
    @State private var debugMode: Bool = false
    @State private var lastEventTime: String = "—"
    @State private var lastWindowInfo: String = "—"
    private let debugRefreshTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    @MainActor
    private var currentBorderPreviewColor: NSColor {
        BorderAutoColorResolver.color(for: NSApp.effectiveAppearance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Focus Follows Mouse", isOn: $settings.isEnabled)

            if debugMode {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Info").font(.caption).fontWeight(.bold)
                    HStack(spacing: 4) {
                        Text("Permission: \(permissionState ? "✓" : "✗")").font(.caption2).monospaced()
                    }
                    Text("Last event: \(lastEventTime)").font(.caption2).monospaced()
                    Text("Window: \(lastWindowInfo)").font(.caption2).monospaced()
                }
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(3)
                .onReceive(debugRefreshTimer) { _ in
                    updateDebugInfo()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Hover delay: \(Int(settings.hoverDelayMilliseconds)) ms")
                    .font(.caption)
                Slider(value: $settings.hoverDelayMilliseconds, in: 0...500, step: 5)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Velocity sensitivity: \(settings.velocitySensitivity, specifier: "%.2f")")
                    .font(.caption)
                Slider(value: $settings.velocitySensitivity, in: 0...0.20, step: 0.01)
            }

            Toggle("Raise window when focused", isOn: $settings.raiseOnFocus)

            Toggle("Highlight focused window border", isOn: $settings.highlightBorder)

            if settings.highlightBorder {
                HStack {
                    Text("Border color")
                        .font(.caption)
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: currentBorderPreviewColor))
                        .frame(width: 28, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }

                Text("Auto mode adapts to light/dark appearance")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Border width: \(Int(settings.borderWidth)) px")
                        .font(.caption)
                    Slider(value: $settings.borderWidth, in: 1...8, step: 1)
                }
            }

            Divider()

            HStack {
                Toggle("Debug mode", isOn: $debugMode)
                Spacer()
                Button("Reset Settings") {
                    confirmAndResetSettings()
                }
                .font(.caption)
            }

            Divider()

            if permissionState {
                Label("Accessibility permission granted", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Accessibility permission required", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button("Request Accessibility Permission") {
                        requestAccessibilityPermissionPrompt()
                    }
                }
            }

            Divider()

            Button("Quit Beckon") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .onAppear {
            permissionState = AXIsProcessTrusted()
        }
    }

    private func requestAccessibilityPermissionPrompt() {
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options)

        // TCC updates can be delayed; poll briefly so UI reflects any change.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            permissionState = AXIsProcessTrusted()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            permissionState = AXIsProcessTrusted()
        }
    }

    private func updateDebugInfo() {
        permissionState = AXIsProcessTrusted()
        let manager = FocusFollowsMouseManager.shared
        lastEventTime = manager.debugLastEventTime
        lastWindowInfo = manager.debugLastWindowInfo
    }

    @MainActor
    private func confirmAndResetSettings() {
        let alert = NSAlert()
        alert.messageText = "Reset Settings?"
        alert.informativeText = "This will restore all Beckon settings, including highlight color and border width."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            settings.resetToDefaults()
        }
    }
}
