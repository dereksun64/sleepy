import FamilyControls
import SwiftData
import XCTest
@testable import Sleepy

@MainActor
final class SleepyStoreTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var store: SleepyStore!
    private var calendar: Calendar!

    override func setUpWithError() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: UserSettings.self, SleepSession.self, ProgressProfile.self,
            configurations: configuration
        )
        context = ModelContext(container)
        store = SleepyStore()
        try store.configure(modelContext: context)
        store.finishOnboarding()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
    }

    func testBrushingRewardIsIdempotent() throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.beginBrushing(at: now, calendar: calendar)
        try store.finishBrushing(at: now, calendar: calendar)
        try store.finishBrushing(at: now, calendar: calendar)

        XCTAssertEqual(store.profile.xp, 10)
        XCTAssertEqual(store.profile.coins, 2)
        XCTAssertEqual(store.routineProgress, 0.5)
    }

    func testThrowingActionRequiresConfiguration() {
        let unconfigured = SleepyStore()

        XCTAssertThrowsError(try unconfigured.beginBrushing())
        XCTAssertNil(unconfigured.session)
    }

    func testCompatibilityActionReportsConfigurationFailureWithoutAdvancing() {
        let unconfigured = SleepyStore()

        unconfigured.finishOnboarding()

        XCTAssertEqual(unconfigured.stage, .onboarding)
        XCTAssertNotNil(unconfigured.recoveryMessage)
    }

    func testSnoozeCountPersistsAndStopsAtThree() throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        XCTAssertTrue(try store.recordSnooze(at: now, calendar: calendar))
        XCTAssertTrue(try store.recordSnooze(at: now, calendar: calendar))
        XCTAssertTrue(try store.recordSnooze(at: now, calendar: calendar))
        XCTAssertFalse(try store.recordSnooze(at: now, calendar: calendar))

        let relaunched = SleepyStore()
        try relaunched.configure(modelContext: ModelContext(container))
        XCTAssertEqual(relaunched.session?.snoozeCount, 3)
    }

    func testSleepCompletionRewardAndStreakAreIdempotent() throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.beginBrushing(at: now, calendar: calendar)
        try store.finishBrushing(at: now, calendar: calendar)
        try store.markSleepActive(at: now, calendar: calendar)
        let wake = store.session!.scheduledWakeTime

        try store.recover(at: wake, calendar: calendar)
        try store.recover(at: wake.addingTimeInterval(60), calendar: calendar)

        XCTAssertEqual(store.profile.xp, 60)
        XCTAssertEqual(store.profile.coins, 12)
        XCTAssertEqual(store.profile.currentStreak, 1)
        XCTAssertEqual(store.profile.bestStreak, 1)
        XCTAssertTrue(store.session!.sleepRewardGranted)
    }

    func testConsecutiveNightsContinueStreakAndGapResetsToOne() throws {
        let first = Date(timeIntervalSince1970: 1_752_500_000)
        try store.makeCompletedNight(at: first, calendar: calendar)
        try store.makeCompletedNight(
            at: calendar.date(byAdding: .day, value: 1, to: first)!,
            calendar: calendar
        )
        XCTAssertEqual(store.profile.currentStreak, 2)
        XCTAssertEqual(store.profile.bestStreak, 2)

        try store.makeCompletedNight(
            at: calendar.date(byAdding: .day, value: 3, to: first)!,
            calendar: calendar
        )
        XCTAssertEqual(store.profile.currentStreak, 1)
        XCTAssertEqual(store.profile.bestStreak, 2)
    }

    func testEndEarlyResetsCurrentStreakWithoutSleepReward() throws {
        store.profile.currentStreak = 4
        store.profile.bestStreak = 6
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.markSleepActive(at: now, calendar: calendar)
        try store.endEarly(at: now)

        XCTAssertEqual(store.profile.currentStreak, 0)
        XCTAssertEqual(store.profile.bestStreak, 6)
        XCTAssertFalse(store.session!.sleepRewardGranted)
        XCTAssertEqual(store.routineProgress, 1)
        XCTAssertEqual(store.stage, .summary)
    }

    func testRecoveryBeforeWakeRestoresActiveAndAfterWakeCompletes() throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.markSleepActive(at: now, calendar: calendar)
        let wake = store.session!.scheduledWakeTime

        try store.recover(at: wake.addingTimeInterval(-1), calendar: calendar)
        XCTAssertEqual(store.stage, .sleepActive)

        try store.recover(at: wake, calendar: calendar)
        XCTAssertEqual(store.stage, .summary)
        XCTAssertEqual(store.session!.sleepStatus, .completed)
    }

    func testNewNightResetsRoutineProgressOnlyWhenSessionRollsOver() throws {
        let first = Date(timeIntervalSince1970: 1_752_500_000)
        try store.makeCompletedNight(at: first, calendar: calendar)
        store.showHome()
        XCTAssertEqual(store.stage, .home)
        XCTAssertEqual(store.routineProgress, 1)

        let next = calendar.date(byAdding: .day, value: 1, to: first)!
        try store.beginBrushing(at: next, calendar: calendar)
        XCTAssertEqual(store.routineProgress, 0)
    }
}

private extension SleepyStore {
    func makeCompletedNight(at date: Date, calendar: Calendar) throws {
        try beginBrushing(at: date, calendar: calendar)
        try finishBrushing(at: date, calendar: calendar)
        try markSleepActive(at: date, calendar: calendar)
        try recover(at: session!.scheduledWakeTime, calendar: calendar)
        showHome()
    }
}
