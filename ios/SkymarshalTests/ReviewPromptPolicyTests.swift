import XCTest
@testable import SkymarshalCore

final class ReviewPromptPolicyTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "ReviewPromptPolicyTests"
    private var calendar: Calendar!
    private let epoch = Date(timeIntervalSince1970: 1_767_225_600)

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        calendar = nil
        super.tearDown()
    }

    func test_requiresUsageAgeAndThreeSuccessfulActions() {
        let policy = makePolicy()
        policy.noteAppOpened(at: date(day: 0))

        XCTAssertFalse(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 1)))
        XCTAssertFalse(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 6)))
        // Third success still before the 7-day floor.
        XCTAssertFalse(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 6)))
        // Need another success at/after day 7 to clear both counters and age.
        XCTAssertTrue(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 7)))
        XCTAssertTrue(policy.isEligible(appVersion: "1.0", at: date(day: 7)))
    }

    func test_successThresholdDoesNotBypassMinimumUsageAge() {
        let policy = makePolicy()
        policy.noteAppOpened(at: date(day: 0))

        XCTAssertFalse(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 0)))
        XCTAssertFalse(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 0)))
        XCTAssertFalse(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 0)))
    }

    func test_destructiveSuccessAccruesCreditWithoutPrompting() {
        let policy = makePolicy(minimumUsageDays: 0, minimumSuccessfulActions: 1)

        XCTAssertFalse(
            policy.registerSuccessfulAction(
                appVersion: "1.0",
                allowsPrompt: false,
                at: date(day: 0)
            )
        )
        XCTAssertTrue(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 1)))
    }

    func test_eligibilityPersistsUntilRequestAttemptIsRecorded() {
        let policy = makePolicy(minimumUsageDays: 0, minimumSuccessfulActions: 1)

        XCTAssertTrue(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 0)))
        XCTAssertTrue(policy.isEligible(appVersion: "1.0", at: date(day: 1)))

        policy.recordRequestAttempt(appVersion: "1.0", at: date(day: 1))

        XCTAssertFalse(policy.isEligible(appVersion: "1.0", at: date(day: 1)))
    }

    func test_sameVersionDoesNotRequestAgain() {
        let policy = makePolicy(minimumUsageDays: 0, minimumSuccessfulActions: 1, cooldownDays: 0)

        XCTAssertTrue(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 0)))
        policy.recordRequestAttempt(appVersion: "1.0", at: date(day: 0))
        XCTAssertFalse(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 1)))
    }

    func test_newVersionStillHonorsCooldown() {
        let policy = makePolicy(minimumUsageDays: 0, minimumSuccessfulActions: 1, cooldownDays: 120)

        XCTAssertTrue(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 0)))
        policy.recordRequestAttempt(appVersion: "1.0", at: date(day: 0))
        XCTAssertFalse(policy.registerSuccessfulAction(appVersion: "1.1", at: date(day: 119)))
        XCTAssertTrue(policy.registerSuccessfulAction(appVersion: "1.1", at: date(day: 120)))
    }

    func test_clockRollbackDoesNotBecomeEligible() {
        let policy = makePolicy(minimumUsageDays: 3, minimumSuccessfulActions: 1)
        policy.noteAppOpened(at: date(day: 5))

        XCTAssertFalse(policy.registerSuccessfulAction(appVersion: "1.0", at: date(day: 4)))
    }

    private func makePolicy(
        minimumUsageDays: Int = 7,
        minimumSuccessfulActions: Int = 3,
        cooldownDays: Int = 120
    ) -> ReviewPromptPolicy {
        ReviewPromptPolicy(
            defaults: defaults,
            calendar: calendar,
            configuration: .init(
                minimumUsageDays: minimumUsageDays,
                minimumSuccessfulActions: minimumSuccessfulActions,
                cooldownDays: cooldownDays
            )
        )
    }

    private func date(day: Int) -> Date {
        calendar.date(byAdding: .day, value: day, to: epoch)!
    }
}
