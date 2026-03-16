import Foundation

final class SettingsModel: ObservableObject {
    private enum Key {
        static let isEnabled = "isEnabled"
        static let hoverDelayMilliseconds = "hoverDelayMilliseconds"
        static let raiseOnFocus = "raiseOnFocus"
    }

    private let defaults: UserDefaults

    @Published var isEnabled: Bool {
        didSet { defaults.set(isEnabled, forKey: Key.isEnabled) }
    }

    @Published var hoverDelayMilliseconds: Double {
        didSet { defaults.set(hoverDelayMilliseconds, forKey: Key.hoverDelayMilliseconds) }
    }

    @Published var raiseOnFocus: Bool {
        didSet { defaults.set(raiseOnFocus, forKey: Key.raiseOnFocus) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Defaults are explicit so behavior is stable on first launch.
        if defaults.object(forKey: Key.isEnabled) == nil {
            defaults.set(true, forKey: Key.isEnabled)
        }
        if defaults.object(forKey: Key.hoverDelayMilliseconds) == nil {
            defaults.set(25.0, forKey: Key.hoverDelayMilliseconds)
        }
        if defaults.object(forKey: Key.raiseOnFocus) == nil {
            defaults.set(true, forKey: Key.raiseOnFocus)
        }

        self.isEnabled = defaults.bool(forKey: Key.isEnabled)
        self.hoverDelayMilliseconds = defaults.double(forKey: Key.hoverDelayMilliseconds)
        self.raiseOnFocus = defaults.bool(forKey: Key.raiseOnFocus)
    }
}
