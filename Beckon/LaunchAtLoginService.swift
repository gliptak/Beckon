import ServiceManagement

/// Thin wrapper around SMAppService so the rest of the app doesn't import ServiceManagement directly.
enum LaunchAtLoginService {
    /// Whether Beckon is currently registered as a login item.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register or unregister Beckon as a login item.
    /// Silently ignores errors that occur when the app is run from a non-stable path (e.g. .build/).
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration fails when the app bundle is unsigned or in a temporary location.
            // This is expected during development; safe to ignore.
        }
    }
}
