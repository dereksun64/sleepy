import FamilyControls
import SwiftData
import UserNotifications
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

    func testStartingNowPersistsStartedBrushingBeforeRouting() async throws {
        let notifications = RecordingNotifications()
        let now = Date(timeIntervalSince1970: 1_752_500_000)

        try await store.handleNotificationAction(
            .startingNow,
            requestIdentifier: NotificationID.prompt,
            notifications: notifications.client,
            at: now,
            calendar: calendar
        )

        let relaunched = try relaunchedStore()
        XCTAssertEqual(relaunched.session?.brushingStatus, .started)
        XCTAssertEqual(relaunched.stage, .brushing)
        XCTAssertEqual(notifications.cancelCount, 1)
    }

    func testAlreadyDonePersistsRewardBeforeRouting() async throws {
        let notifications = RecordingNotifications()
        let now = Date(timeIntervalSince1970: 1_752_500_000)

        try await store.handleNotificationAction(
            .alreadyDone,
            requestIdentifier: NotificationID.prompt,
            notifications: notifications.client,
            at: now,
            calendar: calendar
        )

        let relaunched = try relaunchedStore()
        XCTAssertEqual(relaunched.session?.brushingStatus, .done)
        XCTAssertEqual(relaunched.profile.xp, 10)
        XCTAssertEqual(relaunched.profile.coins, 2)
        XCTAssertTrue(relaunched.session?.brushingRewardGranted == true)
        XCTAssertEqual(relaunched.stage, .startSleep)
        XCTAssertEqual(notifications.cancelCount, 1)
    }

    func testSkipPersistsNoRewardBeforeRouting() async throws {
        let notifications = RecordingNotifications()
        let now = Date(timeIntervalSince1970: 1_752_500_000)

        try await store.handleNotificationAction(
            .skipTonight,
            requestIdentifier: NotificationID.prompt,
            notifications: notifications.client,
            at: now,
            calendar: calendar
        )

        let relaunched = try relaunchedStore()
        XCTAssertEqual(relaunched.session?.brushingStatus, .skipped)
        XCTAssertEqual(relaunched.profile.xp, 0)
        XCTAssertEqual(relaunched.profile.coins, 0)
        XCTAssertFalse(relaunched.session?.brushingRewardGranted == true)
        XCTAssertEqual(relaunched.stage, .startSleep)
        XCTAssertEqual(notifications.cancelCount, 1)
    }

    func testFirstThreeSnoozesPersistBeforeSchedulingAndFourthRoutesToBrushing() async throws {
        let notifications = RecordingNotifications(context: context)
        let now = Date(timeIntervalSince1970: 1_752_500_000)

        let requestIdentifiers = [NotificationID.prompt] + (1...3).map(NotificationID.snooze)
        for requestIdentifier in requestIdentifiers {
            try await store.handleNotificationAction(
                .snooze,
                requestIdentifier: requestIdentifier,
                notifications: notifications.client,
                at: now,
                calendar: calendar
            )
        }

        let relaunched = try relaunchedStore()
        XCTAssertEqual(relaunched.session?.snoozeCount, 3)
        XCTAssertEqual(relaunched.stage, .brushing)
        XCTAssertEqual(notifications.scheduledSnoozeCounts, [1, 2, 3])
        XCTAssertEqual(notifications.persistedCountsAtScheduling, [1, 2, 3])
        XCTAssertEqual(notifications.cancelCount, 4)
    }

    func testDuplicateSnoozeCallbackAfterRelaunchIsIgnored() async throws {
        let notifications = RecordingNotifications()
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try await store.handleNotificationAction(
            .snooze,
            requestIdentifier: NotificationID.prompt,
            notifications: notifications.client,
            at: now,
            calendar: calendar
        )

        let relaunched = try relaunchedStore()
        try await relaunched.handleNotificationAction(
            .snooze,
            requestIdentifier: NotificationID.prompt,
            notifications: notifications.client,
            at: now,
            calendar: calendar
        )

        XCTAssertEqual(try relaunchedStore().session?.snoozeCount, 1)
        XCTAssertEqual(notifications.scheduledSnoozeCounts, [1])
    }

    func testSchedulingFailureIsThrownAfterSnoozePersists() async throws {
        let notifications = RecordingNotifications(addError: TestError.scheduling)
        let now = Date(timeIntervalSince1970: 1_752_500_000)

        do {
            try await store.handleNotificationAction(
                .snooze,
                requestIdentifier: NotificationID.prompt,
                notifications: notifications.client,
                at: now,
                calendar: calendar
            )
            XCTFail("Expected scheduling to fail")
        } catch TestError.scheduling {
        }

        XCTAssertEqual(try relaunchedStore().session?.snoozeCount, 1)
    }

    func testUpdateSchedulePersistsTimesBeforeReplacingNotifications() async throws {
        let bedtime = Date(timeIntervalSince1970: 1_752_500_000)
        let wakeTime = bedtime.addingTimeInterval(8 * 60 * 60)
        let notifications = RecordingNotifications(context: context)

        try await store.updateSchedule(
            bedtime: bedtime,
            wakeTime: wakeTime,
            notifications: notifications.client,
            at: bedtime,
            calendar: calendar
        )

        XCTAssertEqual(notifications.persistedBedtimeAtScheduling, bedtime)
        XCTAssertEqual(notifications.persistedWakeTimeAtScheduling, wakeTime)
        let relaunched = try relaunchedStore()
        XCTAssertEqual(relaunched.settings.targetBedtime, bedtime)
        XCTAssertEqual(relaunched.settings.wakeTime, wakeTime)
        XCTAssertEqual(notifications.removedIdentifiers, [NotificationID.all])
    }

    func testOnboardingFinishesOnlyAfterNotificationsAreScheduled() async throws {
        store.settings.hasCompletedOnboarding = false
        try context.save()
        let notifications = RecordingNotifications()
        let now = Date(timeIntervalSince1970: 1_752_500_000)

        try await store.finishOnboarding(notifications: notifications.client, at: now, calendar: calendar)

        XCTAssertTrue(try relaunchedStore().settings.hasCompletedOnboarding)
        XCTAssertEqual(notifications.removedIdentifiers, [NotificationID.all])
        XCTAssertEqual(notifications.requests.map(\.identifier), [NotificationID.prompt, NotificationID.noResponse])
    }

    func testOnboardingSchedulingFailureIsThrownWithoutFinishing() async throws {
        store.settings.hasCompletedOnboarding = false
        try context.save()
        let notifications = RecordingNotifications(addError: TestError.scheduling)

        do {
            try await store.finishOnboarding(notifications: notifications.client, at: .now, calendar: calendar)
            XCTFail("Expected scheduling to fail")
        } catch TestError.scheduling {
        }

        XCTAssertFalse(try relaunchedStore().settings.hasCompletedOnboarding)
    }

    private func relaunchedStore() throws -> SleepyStore {
        let relaunched = SleepyStore()
        try relaunched.configure(modelContext: context)
        return relaunched
    }
}

private enum TestError: Error {
    case scheduling
}

@MainActor
private final class RecordingNotifications {
    var requests: [UNNotificationRequest] = []
    var removedIdentifiers: [[String]] = []
    var persistedCountsAtScheduling: [Int] = []
    var persistedBedtimeAtScheduling: Date?
    var persistedWakeTimeAtScheduling: Date?
    let context: ModelContext?
    let addError: Error?

    init(context: ModelContext? = nil, addError: Error? = nil) {
        self.context = context
        self.addError = addError
    }

    var client: NotificationClient {
        NotificationClient(
            addRequest: { request in
                if let addError = self.addError { throw addError }
                self.requests.append(request)
                if request.identifier.hasPrefix("bedtime.snooze.") {
                    self.persistedCountsAtScheduling.append(try self.persistedSession()?.snoozeCount ?? 0)
                } else if request.identifier == NotificationID.prompt {
                    let settings = try self.persistedSettings()
                    self.persistedBedtimeAtScheduling = settings?.targetBedtime
                    self.persistedWakeTimeAtScheduling = settings?.wakeTime
                }
            },
            removeRequests: { self.removedIdentifiers.append($0) }
        )
    }

    var scheduledSnoozeCounts: [Int] {
        requests.compactMap {
            Int($0.identifier.replacingOccurrences(of: "bedtime.snooze.", with: ""))
        }
    }

    var cancelCount: Int {
        removedIdentifiers.filter { $0 == [NotificationID.noResponse] }.count
    }

    private func persistedSession() throws -> SleepSession? {
        try context?.fetch(FetchDescriptor<SleepSession>()).first
    }

    private func persistedSettings() throws -> UserSettings? {
        try context?.fetch(FetchDescriptor<UserSettings>()).first
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
