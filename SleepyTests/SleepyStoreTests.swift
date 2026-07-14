import FamilyControls
import ManagedSettings
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
        context.insert(UserSettings(hasCompletedOnboarding: true))
        try context.save()
        store = SleepyStore()
        try store.configure(modelContext: context)
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
    }

    func testHomeReadinessUsesExactLimitedAndReadyCopy() {
        XCTAssertEqual(
            HomeReadiness.message(
                notification: .approved,
                screenTime: .approved,
                hasSelection: true
            ),
            "Ready for bedtime"
        )
        XCTAssertEqual(
            HomeReadiness.message(
                notification: .denied,
                screenTime: .approved,
                hasSelection: true
            ),
            "Scheduled; reminders are inactive"
        )
        XCTAssertEqual(
            HomeReadiness.message(
                notification: .approved,
                screenTime: .unavailable,
                hasSelection: true
            ),
            "Scheduled; app blocking is unavailable"
        )
        XCTAssertEqual(
            HomeReadiness.message(
                notification: .approved,
                screenTime: .approved,
                hasSelection: false
            ),
            "Scheduled; choose distracting apps to enable blocking"
        )
    }

    func testSelectionSummaryCountsAllThreeTokenKinds() {
        XCTAssertEqual(
            ActivitySelectionSummary.text(applications: 0, categories: 0, websites: 0),
            "No apps selected"
        )
        XCTAssertEqual(
            ActivitySelectionSummary.text(applications: 2, categories: 3, websites: 4),
            "2 apps, 3 categories, 4 websites selected"
        )
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

    func testFinishBrushingSaveFailureRestoresStatusRewardAndLaterPersistence() throws {
        var failSaves = false
        let failingStore = SleepyStore(saveModelContext: { context in
            if failSaves { throw TestError.persistence }
            try context.save()
        })
        try failingStore.configure(modelContext: context)
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try failingStore.beginBrushing(at: now, calendar: calendar)

        failSaves = true
        XCTAssertThrowsError(try failingStore.finishBrushing(at: now, calendar: calendar))
        XCTAssertEqual(failingStore.session?.brushingStatus, .started)
        XCTAssertFalse(failingStore.session?.brushingRewardGranted == true)
        XCTAssertEqual(failingStore.profile.xp, 0)
        XCTAssertEqual(failingStore.profile.coins, 0)

        failSaves = false
        try failingStore.updateSettings(
            targetBedtime: failingStore.bedtime,
            wakeTime: failingStore.wakeTime
        )
        let relaunched = SleepyStore()
        try relaunched.configure(modelContext: ModelContext(container))
        XCTAssertEqual(relaunched.session?.brushingStatus, .started)
        XCTAssertEqual(relaunched.profile.xp, 0)
        XCTAssertEqual(relaunched.profile.coins, 0)
    }

    func testBeginSkipAndSnoozeSaveFailuresRestoreObservableState() throws {
        var failSaves = false
        let failingStore = SleepyStore(saveModelContext: { context in
            if failSaves { throw TestError.persistence }
            try context.save()
        })
        try failingStore.configure(modelContext: context)
        let now = Date(timeIntervalSince1970: 1_752_500_000)

        failSaves = true
        XCTAssertThrowsError(try failingStore.beginBrushing(at: now, calendar: calendar))
        XCTAssertNil(failingStore.session)

        failSaves = false
        try failingStore.beginBrushing(at: now, calendar: calendar)
        failSaves = true
        XCTAssertThrowsError(try failingStore.skipBrushing(at: now, calendar: calendar))
        XCTAssertEqual(failingStore.session?.brushingStatus, .started)
        XCTAssertThrowsError(try failingStore.recordSnooze(at: now, calendar: calendar))
        XCTAssertEqual(failingStore.session?.snoozeCount, 0)
    }

    func testSelectionAndScheduleSaveFailuresRestoreObservableState() async throws {
        var failSaves = false
        let failingStore = SleepyStore(saveModelContext: { context in
            if failSaves { throw TestError.persistence }
            try context.save()
        })
        try failingStore.configure(modelContext: context)
        let oldBedtime = failingStore.bedtime
        let oldWakeTime = failingStore.wakeTime
        let oldSelectionData = failingStore.settings.activitySelectionData
        let newBedtime = oldBedtime.addingTimeInterval(60 * 60)
        let newWakeTime = oldWakeTime.addingTimeInterval(60 * 60)

        failSaves = true
        XCTAssertThrowsError(
            try failingStore.saveSelection(FamilyActivitySelection(includeEntireCategory: false))
        )
        XCTAssertEqual(failingStore.settings.activitySelectionData, oldSelectionData)
        do {
            try await failingStore.updateSchedule(
                bedtime: newBedtime,
                wakeTime: newWakeTime,
                notifications: RecordingNotifications().client,
                at: oldBedtime,
                calendar: calendar
            )
            XCTFail("Expected schedule persistence to fail")
        } catch TestError.persistence {
        }
        XCTAssertEqual(failingStore.bedtime, oldBedtime)
        XCTAssertEqual(failingStore.wakeTime, oldWakeTime)
    }

    func testRecoverSaveFailureRestoresCompletionAndRewards() throws {
        var failSaves = false
        let failingStore = SleepyStore(saveModelContext: { context in
            if failSaves { throw TestError.persistence }
            try context.save()
        })
        try failingStore.configure(modelContext: context)
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try failingStore.markSleepActive(at: now, calendar: calendar)

        failSaves = true
        XCTAssertThrowsError(
            try failingStore.recover(
                at: failingStore.session!.scheduledWakeTime,
                calendar: calendar
            )
        )
        XCTAssertEqual(failingStore.session?.sleepStatus, .active)
        XCTAssertNil(failingStore.session?.actualEndTime)
        XCTAssertFalse(failingStore.session?.sleepRewardGranted == true)
        XCTAssertEqual(failingStore.profile.xp, 0)
        XCTAssertEqual(failingStore.profile.coins, 0)
        XCTAssertEqual(failingStore.profile.currentStreak, 0)
    }

    func testThrowingActionRequiresConfiguration() {
        let unconfigured = SleepyStore()

        XCTAssertThrowsError(try unconfigured.beginBrushing())
        XCTAssertNil(unconfigured.session)
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

    func testSameNightScheduleEditSynchronizesPendingSessionAcrossRelaunch() async throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.updateSettings(
            targetBedtime: calendar.date(byAdding: .hour, value: 1, to: now)!,
            wakeTime: calendar.date(byAdding: .hour, value: 8, to: now)!,
            at: now,
            calendar: calendar
        )
        try store.beginBrushing(at: now, calendar: calendar)
        let bedtime = calendar.date(byAdding: .minute, value: 30, to: store.bedtime)!
        let wakeTime = calendar.date(byAdding: .minute, value: 45, to: store.wakeTime)!
        let expected = SleepSchedule.currentOrNext(
            at: now,
            bedtime: bedtime,
            wakeTime: wakeTime,
            calendar: calendar
        )

        try await store.updateSchedule(
            bedtime: bedtime,
            wakeTime: wakeTime,
            notifications: RecordingNotifications().client,
            at: now,
            calendar: calendar
        )

        let relaunched = try relaunchedStore()
        XCTAssertEqual(relaunched.session?.scheduledBedtime, expected.start)
        XCTAssertEqual(relaunched.session?.scheduledWakeTime, expected.end)
        try relaunched.finishBrushing(at: now, calendar: calendar)
        XCTAssertEqual(relaunched.session?.id, store.session?.id)
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

    func testActivationAfterWakeClearsBeforeAwardingAndIsRepeatSafe() async throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.markSleepActive(at: now, calendar: calendar)
        let managedStore = makeManagedStore()
        managedStore.shield.applicationCategories = .all()
        var clearCount = 0
        let shield = ShieldClient(
            store: managedStore,
            authorizationStatus: { .approved },
            stopMonitoring: { _ in
                clearCount += 1
                XCTAssertEqual(self.store.session?.sleepStatus, .active)
            }
        )
        let notifications = RecordingNotifications(permission: .approved)
        let wake = store.session!.scheduledWakeTime

        await store.activate(notifications: notifications.client, shield: shield, at: wake, calendar: calendar)
        await store.activate(notifications: notifications.client, shield: shield, at: wake, calendar: calendar)

        XCTAssertEqual(clearCount, 1)
        XCTAssertFalse(shield.isActive)
        XCTAssertEqual(store.session?.sleepStatus, .completed)
        XCTAssertEqual(store.profile.xp, 50)
        XCTAssertTrue(store.session?.sleepRewardGranted == true)
    }

    func testRevokedScreenTimeClearsActiveShieldWithoutCompletingEarly() async throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.markSleepActive(at: now, calendar: calendar)
        let managedStore = makeManagedStore()
        managedStore.shield.applicationCategories = .all()
        let shield = ShieldClient(
            store: managedStore,
            authorizationStatus: { .denied },
            stopMonitoring: { _ in }
        )

        await store.activate(
            notifications: RecordingNotifications(permission: .approved).client,
            shield: shield,
            at: store.session!.scheduledWakeTime.addingTimeInterval(-1),
            calendar: calendar
        )

        XCTAssertFalse(shield.isActive)
        XCTAssertEqual(store.session?.sleepStatus, .active)
        XCTAssertEqual(store.settings.screenTimePermission, .denied)
        XCTAssertEqual(
            store.shieldStatusMessage,
            "Screen Time access is unavailable, so distracting apps are not being blocked."
        )
    }

    func testActivationAfterWakeCompletesEvenWhenScreenTimeWasRevoked() async throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.markSleepActive(at: now, calendar: calendar)
        let shield = ShieldClient(
            store: makeManagedStore(),
            authorizationStatus: { .denied },
            stopMonitoring: { _ in }
        )

        await store.activate(
            notifications: RecordingNotifications(permission: .approved).client,
            shield: shield,
            at: store.session!.scheduledWakeTime,
            calendar: calendar
        )

        XCTAssertEqual(store.session?.sleepStatus, .completed)
        XCTAssertTrue(store.session?.sleepRewardGranted == true)
    }

    func testActivationDerivesShieldMessageFromNamedStoreBeforeWake() async throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.markSleepActive(at: now, calendar: calendar)
        let managedStore = makeManagedStore()
        managedStore.shield.applicationCategories = .all()
        let shield = ShieldClient(
            store: managedStore,
            authorizationStatus: { .approved },
            stopMonitoring: { _ in }
        )

        await store.activate(
            notifications: RecordingNotifications(permission: .approved).client,
            shield: shield,
            at: store.session!.scheduledWakeTime.addingTimeInterval(-1),
            calendar: calendar
        )

        XCTAssertEqual(store.shieldStatusMessage, "Selected distractions are shielded.")
    }

    func testDifferentNightCannotReplaceAnActiveSession() throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.markSleepActive(at: now, calendar: calendar)
        let originalID = store.session?.id
        let nextNight = calendar.date(byAdding: .day, value: 1, to: now)!

        XCTAssertThrowsError(try store.beginBrushing(at: nextNight, calendar: calendar))
        XCTAssertEqual(store.session?.id, originalID)
        XCTAssertEqual(store.session?.sleepStatus, .active)
    }

    func testStartSleepPersistsVisibleUnshieldedState() throws {
        let shield = ShieldClient(
            store: makeManagedStore(),
            authorizationStatus: { .denied },
            stopMonitoring: { _ in }
        )

        try store.startSleep(
            shield: shield,
            at: Date(timeIntervalSince1970: 1_752_500_000),
            calendar: calendar
        )

        XCTAssertEqual(store.session?.sleepStatus, .active)
        XCTAssertFalse(shield.isActive)
        XCTAssertEqual(
            store.shieldStatusMessage,
            "Screen Time access is unavailable, so distracting apps are not being blocked."
        )
        XCTAssertEqual(try relaunchedStore().session?.sleepStatus, .active)
    }

    func testStartSleepClearsShieldWhenActivePersistenceFails() throws {
        var failSaves = false
        let failingStore = SleepyStore(saveModelContext: { context in
            if failSaves { throw TestError.persistence }
            try context.save()
        })
        try failingStore.configure(modelContext: context)
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try failingStore.beginBrushing(at: now, calendar: calendar)
        var clearCount = 0
        let shield = ShieldClient(
            store: makeManagedStore(),
            authorizationStatus: { .denied },
            stopMonitoring: { _ in clearCount += 1 }
        )

        failSaves = true
        XCTAssertThrowsError(
            try failingStore.startSleep(
                shield: shield,
                at: now,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? TestError, .persistence)
        }
        XCTAssertEqual(clearCount, 1)
        XCTAssertFalse(shield.isActive)
        XCTAssertEqual(failingStore.session?.sleepStatus, .notStarted)
        XCTAssertNil(failingStore.session?.actualStartTime)
        XCTAssertEqual(failingStore.stage, .brushing)
        XCTAssertEqual(failingStore.routineProgress, 0)

        failSaves = false
        try failingStore.updateSettings(
            targetBedtime: failingStore.bedtime,
            wakeTime: failingStore.wakeTime
        )
        let relaunched = SleepyStore()
        try relaunched.configure(modelContext: ModelContext(container))
        XCTAssertEqual(relaunched.session?.sleepStatus, .notStarted)
        XCTAssertNil(relaunched.session?.actualStartTime)
    }

    func testEndEarlySaveFailureKeepsShieldClearedAndRestoresActiveState() throws {
        var failSaves = false
        let failingStore = SleepyStore(saveModelContext: { context in
            if failSaves { throw TestError.persistence }
            try context.save()
        })
        try failingStore.configure(modelContext: context)
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try failingStore.markSleepActive(at: now, calendar: calendar)
        failingStore.profile.currentStreak = 4
        try context.save()
        var clearCount = 0
        let shield = ShieldClient(
            store: makeManagedStore(),
            stopMonitoring: { _ in clearCount += 1 }
        )

        failSaves = true
        XCTAssertThrowsError(try failingStore.endEarly(shield: shield, at: now)) { error in
            XCTAssertEqual(error as? TestError, .persistence)
        }

        XCTAssertEqual(clearCount, 1)
        XCTAssertFalse(shield.isActive)
        XCTAssertEqual(failingStore.session?.sleepStatus, .active)
        XCTAssertFalse(failingStore.session?.endedEarly == true)
        XCTAssertNil(failingStore.session?.actualEndTime)
        XCTAssertEqual(failingStore.profile.currentStreak, 4)
        XCTAssertEqual(failingStore.stage, .sleepActive)
        XCTAssertEqual(failingStore.routineProgress, 1)

        failSaves = false
        try failingStore.updateSettings(
            targetBedtime: failingStore.bedtime,
            wakeTime: failingStore.wakeTime
        )
        let relaunched = SleepyStore()
        try relaunched.configure(modelContext: ModelContext(container))
        XCTAssertEqual(relaunched.session?.sleepStatus, .active)
        XCTAssertFalse(relaunched.session?.endedEarly == true)
        XCTAssertNil(relaunched.session?.actualEndTime)
        XCTAssertEqual(relaunched.profile.currentStreak, 4)
    }

    func testActivationSurfacesPersistenceFailure() async throws {
        var saveCount = 0
        let failingStore = SleepyStore(saveModelContext: { context in
            saveCount += 1
            if saveCount == 2 { throw TestError.persistence }
            try context.save()
        })
        try failingStore.configure(modelContext: context)

        await failingStore.activate(
            notifications: RecordingNotifications(permission: .approved).client,
            shield: ShieldClient(store: makeManagedStore()),
            at: .now,
            calendar: calendar
        )

        XCTAssertTrue(failingStore.recoveryMessage?.contains("couldn't recover saved data") == true)
    }

    func testEndEarlyAlwaysClearsFirstAndNeverAwardsSleep() throws {
        let now = Date(timeIntervalSince1970: 1_752_500_000)
        try store.markSleepActive(at: now, calendar: calendar)
        var clearCount = 0
        let shield = ShieldClient(
            store: makeManagedStore(),
            stopMonitoring: { _ in
                clearCount += 1
                if clearCount == 1 {
                    XCTAssertEqual(self.store.session?.sleepStatus, .active)
                }
            }
        )

        try store.endEarly(shield: shield, at: now)
        try store.endEarly(shield: shield, at: now)

        XCTAssertEqual(clearCount, 2)
        XCTAssertEqual(store.session?.sleepStatus, .ended)
        XCTAssertFalse(store.session?.sleepRewardGranted == true)
        XCTAssertEqual(store.profile.currentStreak, 0)
    }

    func testDecodeRepairPreservesProgressAndSurfacesRepair() throws {
        store.profile.xp = 42
        store.profile.coins = 7
        store.settings.activitySelectionData = Data([0xFF])
        try context.save()

        let relaunched = try relaunchedStore()

        XCTAssertEqual(relaunched.profile.xp, 42)
        XCTAssertEqual(relaunched.profile.coins, 7)
        XCTAssertTrue(relaunched.selectionNeedsRepair)
        XCTAssertTrue(relaunched.settings.activitySelectionData.isEmpty)
    }

    private func relaunchedStore() throws -> SleepyStore {
        let relaunched = SleepyStore()
        try relaunched.configure(modelContext: context)
        return relaunched
    }

    private func makeManagedStore() -> ManagedSettingsStore {
        let store = ManagedSettingsStore(named: .init("store-test-\(UUID().uuidString)"))
        store.clearAllSettings()
        return store
    }
}

private enum TestError: Error, Equatable {
    case scheduling, persistence
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
    let permission: PermissionState

    init(
        context: ModelContext? = nil,
        addError: Error? = nil,
        permission: PermissionState = .unknown
    ) {
        self.context = context
        self.addError = addError
        self.permission = permission
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
            removeRequests: { self.removedIdentifiers.append($0) },
            permissionStatus: { self.permission }
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
