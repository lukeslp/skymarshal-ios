import XCTest
@testable import SkymarshalCore

/// Unit coverage for the pure Guided Mode Tier 1 setting logic
/// (`GuidedModeSettings`): enum value mappings, default fallbacks,
/// `UserDefaults` round-trips, and the extended-timeouts ×3 math.
@available(iOS 17, *)
final class GuidedModeSettingsTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "GuidedModeSettingsTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Target size floor

    func test_targetSizeFloor_pointValues() {
        XCTAssertEqual(GuidedModeSettings.TargetSizeFloor.standard.points, 44)
        XCTAssertEqual(GuidedModeSettings.TargetSizeFloor.large.points, 60)
        XCTAssertEqual(GuidedModeSettings.TargetSizeFloor.max.points, 88)
    }

    func test_targetSizeFloor_defaultsToStandardWhenAbsent() {
        XCTAssertEqual(GuidedModeSettings.targetSizeFloor(from: defaults), .standard)
    }

    func test_targetSizeFloor_roundTrips() {
        defaults.set(GuidedModeSettings.TargetSizeFloor.max.rawValue,
                     forKey: GuidedModeSettings.targetSizeFloorKey)
        XCTAssertEqual(GuidedModeSettings.targetSizeFloor(from: defaults), .max)
    }

    func test_targetSizeFloor_fallsBackOnGarbage() {
        defaults.set("not-a-floor", forKey: GuidedModeSettings.targetSizeFloorKey)
        XCTAssertEqual(GuidedModeSettings.targetSizeFloor(from: defaults), .standard)
    }

    // MARK: - Max choices per screen

    func test_maxChoices_limitValues() {
        XCTAssertNil(GuidedModeSettings.MaxChoicesPerScreen.full.limit)
        XCTAssertEqual(GuidedModeSettings.MaxChoicesPerScreen.six.limit, 6)
        XCTAssertEqual(GuidedModeSettings.MaxChoicesPerScreen.four.limit, 4)
    }

    func test_maxChoices_defaultsToFull() {
        XCTAssertEqual(GuidedModeSettings.maxChoicesPerScreen(from: defaults), .full)
    }

    // MARK: - Confirmation style

    func test_confirmationStyle_defaultsToAutomatic() {
        XCTAssertEqual(GuidedModeSettings.confirmationStyle(from: defaults), .automatic)
    }

    func test_confirmationStyle_roundTrips() {
        defaults.set(GuidedModeSettings.ConfirmationStyle.hold.rawValue,
                     forKey: GuidedModeSettings.confirmationStyleKey)
        XCTAssertEqual(GuidedModeSettings.confirmationStyle(from: defaults), .hold)
    }

    // MARK: - Extended timeouts

    func test_extendedTimeouts_defaultsOff() {
        XCTAssertFalse(GuidedModeSettings.extendedTimeoutsEnabled(from: defaults))
    }

    func test_extendedTimeouts_multiplierIsThree() {
        XCTAssertEqual(GuidedModeSettings.applyExtendedTimeouts(true, to: 10), 30)
        XCTAssertEqual(GuidedModeSettings.applyExtendedTimeouts(true, to: 3), 9)
    }

    func test_extendedTimeouts_passthroughWhenOff() {
        XCTAssertEqual(GuidedModeSettings.applyExtendedTimeouts(false, to: 10), 10)
        XCTAssertEqual(GuidedModeSettings.applyExtendedTimeouts(false, to: 3), 3)
    }

    // MARK: - Dwell

    func test_dwell_defaults() {
        XCTAssertFalse(GuidedModeSettings.dwellActivationEnabled(from: defaults))
        XCTAssertEqual(GuidedModeSettings.dwellThreshold(from: defaults),
                       GuidedModeSettings.dwellThresholdDefault)
    }

    func test_dwellThreshold_clampsOutOfRangeToDefault() {
        defaults.set(9.0, forKey: GuidedModeSettings.dwellThresholdKey)
        XCTAssertEqual(GuidedModeSettings.dwellThreshold(from: defaults),
                       GuidedModeSettings.dwellThresholdDefault)
    }

    func test_dwellThreshold_acceptsInRangeValue() {
        defaults.set(2.5, forKey: GuidedModeSettings.dwellThresholdKey)
        XCTAssertEqual(GuidedModeSettings.dwellThreshold(from: defaults), 2.5)
    }
}
