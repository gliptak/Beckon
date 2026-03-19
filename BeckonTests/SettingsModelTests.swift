import XCTest
@testable import Beckon

final class SettingsModelTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "SettingsModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testInitialDefaultsAreAppliedOnFirstLaunch() {
        let settings = SettingsModel(defaults: defaults)

        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.hoverDelayMilliseconds, 25.0, accuracy: 0.0001)
        XCTAssertTrue(settings.raiseOnFocus)
        XCTAssertEqual(settings.velocitySensitivity, 0.08, accuracy: 0.0001)
    }

    func testMutationsPersistAcrossNewModelInstance() {
        var settings: SettingsModel? = SettingsModel(defaults: defaults)
        settings?.isEnabled = false
        settings?.hoverDelayMilliseconds = 180.0
        settings?.raiseOnFocus = false
        settings?.velocitySensitivity = 0.14

        settings = nil

        let reloaded = SettingsModel(defaults: defaults)
        XCTAssertFalse(reloaded.isEnabled)
        XCTAssertEqual(reloaded.hoverDelayMilliseconds, 180.0, accuracy: 0.0001)
        XCTAssertFalse(reloaded.raiseOnFocus)
        XCTAssertEqual(reloaded.velocitySensitivity, 0.14, accuracy: 0.0001)
    }
}
