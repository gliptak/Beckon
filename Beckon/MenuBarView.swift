import ApplicationServices
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var settings: SettingsModel
    @State private var permissionState: Bool = AXIsProcessTrusted()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Focus Follows Mouse", isOn: $settings.isEnabled)

            VStack(alignment: .leading, spacing: 6) {
                Text("Hover delay: \(Int(settings.hoverDelayMilliseconds)) ms")
                    .font(.caption)
                Slider(value: $settings.hoverDelayMilliseconds, in: 0...500, step: 5)
            }

            Toggle("Raise window when focused", isOn: $settings.raiseOnFocus)

            Divider()

            if permissionState {
                Label("Accessibility permission granted", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Accessibility permission required", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button("Open Accessibility Settings") {
                        openAccessibilitySettings()
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

    private func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}
