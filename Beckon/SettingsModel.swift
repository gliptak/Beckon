import Foundation

final class SettingsModel: ObservableObject {
    private enum Key {
        static let isEnabled = "isEnabled"
        static let hoverDelayMilliseconds = "hoverDelayMilliseconds"
        static let raiseOnFocus = "raiseOnFocus"
        static let velocitySensitivity = "velocitySensitivity"
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

    @Published var velocitySensitivity: Double {
        didSet { defaults.set(velocitySensitivity, forKey: Key.velocitySensitivity) }
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
        if defaults.object(forKey: Key.velocitySensitivity) == nil {
            defaults.set(0.08, forKey: Key.velocitySensitivity)
        }

        self.isEnabled = defaults.bool(forKey: Key.isEnabled)
        self.hoverDelayMilliseconds = defaults.double(forKey: Key.hoverDelayMilliseconds)
        self.raiseOnFocus = defaults.bool(forKey: Key.raiseOnFocus)
        self.velocitySensitivity = defaults.double(forKey: Key.velocitySensitivity)
    }
}
