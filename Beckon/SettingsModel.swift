import Foundation

final class SettingsModel: ObservableObject {
    private enum Defaults {
        static let isEnabled = true
        static let hoverDelayMilliseconds = 25.0
        static let raiseOnFocus = false
        static let velocitySensitivity = 0.08
        static let highlightBorder = true
        static let borderWidth = 2.0
    }

    private enum Key {
        static let isEnabled = "isEnabled"
        static let hoverDelayMilliseconds = "hoverDelayMilliseconds"
        static let raiseOnFocus = "raiseOnFocus"
        static let velocitySensitivity = "velocitySensitivity"
        static let highlightBorder = "highlightBorder"
        static let borderWidth = "borderWidth"
        static let highlightStyleMigratedV1 = "highlightStyleMigratedV1"
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

    @Published var highlightBorder: Bool {
        didSet { defaults.set(highlightBorder, forKey: Key.highlightBorder) }
    }

    @Published var borderWidth: Double {
        didSet { defaults.set(borderWidth, forKey: Key.borderWidth) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Defaults are explicit so behavior is stable on first launch.
        if defaults.object(forKey: Key.isEnabled) == nil {
            defaults.set(Defaults.isEnabled, forKey: Key.isEnabled)
        }
        if defaults.object(forKey: Key.hoverDelayMilliseconds) == nil {
            defaults.set(Defaults.hoverDelayMilliseconds, forKey: Key.hoverDelayMilliseconds)
        }
        if defaults.object(forKey: Key.raiseOnFocus) == nil {
            defaults.set(Defaults.raiseOnFocus, forKey: Key.raiseOnFocus)
        }
        if defaults.object(forKey: Key.velocitySensitivity) == nil {
            defaults.set(Defaults.velocitySensitivity, forKey: Key.velocitySensitivity)
        }
        if defaults.object(forKey: Key.highlightBorder) == nil {
            defaults.set(Defaults.highlightBorder, forKey: Key.highlightBorder)
        }
        if defaults.object(forKey: Key.borderWidth) == nil {
            defaults.set(Defaults.borderWidth, forKey: Key.borderWidth)
        }

        // One-time migration: if user is still on the old default border preset,
        // move to the newer Janky-style preset.
        if !defaults.bool(forKey: Key.highlightStyleMigratedV1) {
            let savedWidth = defaults.double(forKey: Key.borderWidth)
            if abs(savedWidth - 3.0) < 0.0001 {
                defaults.set(Defaults.borderWidth, forKey: Key.borderWidth)
            }
            defaults.set(true, forKey: Key.highlightStyleMigratedV1)
        }

        self.isEnabled = defaults.bool(forKey: Key.isEnabled)
        self.hoverDelayMilliseconds = defaults.double(forKey: Key.hoverDelayMilliseconds)
        self.raiseOnFocus = defaults.bool(forKey: Key.raiseOnFocus)
        self.velocitySensitivity = defaults.double(forKey: Key.velocitySensitivity)
        self.highlightBorder = defaults.bool(forKey: Key.highlightBorder)
        self.borderWidth = defaults.double(forKey: Key.borderWidth)
    }

    func resetToDefaults() {
        isEnabled = Defaults.isEnabled
        hoverDelayMilliseconds = Defaults.hoverDelayMilliseconds
        raiseOnFocus = Defaults.raiseOnFocus
        velocitySensitivity = Defaults.velocitySensitivity
        highlightBorder = Defaults.highlightBorder
        borderWidth = Defaults.borderWidth
        defaults.set(true, forKey: Key.highlightStyleMigratedV1)
    }
}
