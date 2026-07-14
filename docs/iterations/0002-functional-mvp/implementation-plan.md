# Sleepy 0002 Functional MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the simulator-oriented skeleton into a durable bedtime accountability loop that schedules actionable notifications, shields a saved Screen Time selection on a real iPhone, clears shields after wake time or End early, and grants each reward at most once.

**Architecture:** Keep the existing SwiftUI → `SleepyStore` → SwiftData/Apple-framework-client shape. Make persisted `SleepSession` facts the source of truth, keep schedule math in one value type, and add only the Device Activity monitor extension required for out-of-process shield clearing. Platform clients remain concrete; pure request builders and injected clock/calendar values provide the test seams without a repository, reducer, or generic navigation layer.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Observation, UserNotifications, FamilyControls, ManagedSettings, DeviceActivity, XCTest, Xcode 26.6, iOS 17.0 deployment target.

## Global Constraints

- Native iOS only; use Swift, SwiftUI, SwiftData, UserNotifications, FamilyControls, ManagedSettings, and DeviceActivity.
- Keep the existing `SleepyStore` shape. Do not add a reducer framework or repository layer.
- Use standard SwiftUI controls and system symbols; visual identity, illustrations, animation, sound design, and custom shield appearance remain out of scope.
- The only routine steps are Brush and Sleep.
- Notification copy is exactly `Are you brushing your teeth now?` and `Alright man, it's getting late, stop trolling.`
- Snoozes are five minutes and capped at three per nightly session, including across relaunches.
- Done brushing grants 10 XP and 2 coins once. Skip brushing grants nothing.
- Reaching scheduled wake time grants 50 XP, 10 coins, and one streak step once. End early grants no sleep reward and resets the current streak to zero.
- Resolve local bedtime/wake intervals with `Calendar`; never add fixed 24-hour or five-minute second counts for calendar decisions.
- Favor clearing a possibly stale shield over preserving an uncertain active state.
- Use one stable named `ManagedSettingsStore` in the app and Device Activity extension.
- Do not add an App Group unless real-device implementation proves the named store cannot be cleared across the extension boundary.
- Do not add third-party dependencies.
- Preserve the existing uncommitted signing team and `com.dereksun.sleepy.dev` bundle identifier changes in `Sleepy.xcodeproj/project.pbxproj`.
- Test platform effects through the same production APIs used by the app. Do not add methods used only by tests or make concrete clients inheritable solely for mocks; prefer existing Simulator behavior or minimal initializer-injected closures at the Apple-framework boundary.
- A simulator-only pass does not complete 0002; record physical-iPhone model, iOS version, entitlement state, steps, and results.

---

## Ponytail Decisions

- Extend the three existing models and the existing store instead of introducing DTOs, repositories, use cases, coordinators, or a state-machine package.
- Add one domain file, `SleepSchedule.swift`, because notification scheduling, session identity, Device Activity, recovery, and streaks must share the same calendar rule.
- Keep selection encoding inside `ShieldClient`; a separate selection service would have only one caller.
- Keep notification response forwarding beside `NotificationClient`; a generic deep-link router is unnecessary for four fixed actions.
- Keep all functional screens in `RootView.swift` for this iteration. Split only if implementation makes that file materially hard to review.
- Share the named store/activity constants through one source file compiled into both targets. This is the only cross-target code; no shared container is needed.
- Use a single focused test file per non-UI boundary and expand the existing store tests. Do not add UI-test infrastructure.

## File Map

```text
Sleepy.xcodeproj/project.pbxproj                 modify: capabilities, extension target, target membership
Sleepy/
  Models.swift                                  modify: durable settings/session/profile facts
  SleepSchedule.swift                           create: all local-calendar nightly interval resolution
  ScreenTimeNames.swift                         create: stable store and activity names shared by two targets
  SleepyStore.swift                             modify: persistence, derived stage/progress, actions, recovery, rewards
  NotificationClient.swift                      modify: permission, categories, requests, cancellation, response forwarding
  ShieldClient.swift                            modify: authorization, selection coding, real shields, monitoring, safe clear
  RootView.swift                                modify: functional setup/home/routine/sleep/summary/settings UI
  SleepyApp.swift                               modify: delegate and launch/foreground reconciliation wiring
  Sleepy.entitlements                          create: Family Controls capability
SleepyDeviceActivityMonitor/
  DeviceActivityMonitorExtension.swift          create: clear the named store at interval end
  Info.plist                                    create: Device Activity monitor extension declaration
  SleepyDeviceActivityMonitor.entitlements      create: Family Controls capability
SleepyTests/
  SleepScheduleTests.swift                      create: same-day, overnight, time-zone, and DST rules
  SleepyStoreTests.swift                        modify: durable transitions, rewards, streaks, progress, recovery
  NotificationClientTests.swift                 create: identifiers, actions, dates, and replacement behavior
  ShieldClientTests.swift                       modify: selection coding and idempotent mock clearing
docs/iterations/0002-functional-mvp/
  checklist.md                                  create: acceptance checklist
  test-notes.md                                 create: commands and simulator/device evidence
```

---

### Task 1: Resolve One Canonical Nightly Interval and Persist All Required Facts

**Files:**
- Create: `Sleepy/SleepSchedule.swift`
- Modify: `Sleepy/Models.swift`
- Create: `SleepyTests/SleepScheduleTests.swift`

**Interfaces:**
- Produces: `SleepSchedule.interval(on:bedtime:wakeTime:calendar:) -> DateInterval`
- Produces: `SleepSchedule.currentOrNext(at:bedtime:wakeTime:calendar:) -> DateInterval`
- Produces: durable `UserSettings`, `SleepSession`, and `ProgressProfile` fields used by every later task

- [ ] **Step 1: Write failing schedule tests**

Create `SleepyTests/SleepScheduleTests.swift` with fixed Gregorian calendars and dates:

```swift
import XCTest
@testable import Sleepy

final class SleepScheduleTests: XCTestCase {
    private func calendar(_ identifier: String = "America/Los_Angeles") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(_ text: String, calendar: Calendar) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: text)!
    }

    func testWakeLaterThanBedtimeStaysOnSameDay() {
        let cal = calendar()
        let interval = SleepSchedule.interval(
            on: date("2026-07-14 12:00", calendar: cal),
            bedtime: date("2001-01-01 21:00", calendar: cal),
            wakeTime: date("2001-01-01 23:00", calendar: cal),
            calendar: cal
        )

        XCTAssertEqual(interval.start, date("2026-07-14 21:00", calendar: cal))
        XCTAssertEqual(interval.end, date("2026-07-14 23:00", calendar: cal))
    }

    func testEqualOrEarlierWakeMovesToFollowingDay() {
        let cal = calendar()
        let interval = SleepSchedule.interval(
            on: date("2026-07-14 12:00", calendar: cal),
            bedtime: date("2001-01-01 23:00", calendar: cal),
            wakeTime: date("2001-01-01 07:00", calendar: cal),
            calendar: cal
        )

        XCTAssertEqual(interval.start, date("2026-07-14 23:00", calendar: cal))
        XCTAssertEqual(interval.end, date("2026-07-15 07:00", calendar: cal))
    }

    func testAfterMidnightResolvesToPreviousBedtimeDate() {
        let cal = calendar()
        let interval = SleepSchedule.currentOrNext(
            at: date("2026-07-15 01:00", calendar: cal),
            bedtime: date("2001-01-01 23:00", calendar: cal),
            wakeTime: date("2001-01-01 07:00", calendar: cal),
            calendar: cal
        )

        XCTAssertEqual(interval.start, date("2026-07-14 23:00", calendar: cal))
        XCTAssertEqual(interval.end, date("2026-07-15 07:00", calendar: cal))
    }

    func testSpringDSTUsesCalendarWallClockTime() {
        let cal = calendar()
        let interval = SleepSchedule.interval(
            on: date("2026-03-07 12:00", calendar: cal),
            bedtime: date("2001-01-01 23:00", calendar: cal),
            wakeTime: date("2001-01-01 07:00", calendar: cal),
            calendar: cal
        )

        XCTAssertEqual(interval.end, date("2026-03-08 07:00", calendar: cal))
        XCTAssertEqual(interval.duration, 7 * 60 * 60)
    }

    func testSameInputsResolveInSelectedTimeZone() {
        let singapore = calendar("Asia/Singapore")
        let interval = SleepSchedule.interval(
            on: date("2026-07-14 12:00", calendar: singapore),
            bedtime: date("2001-01-01 23:00", calendar: singapore),
            wakeTime: date("2001-01-01 07:00", calendar: singapore),
            calendar: singapore
        )

        XCTAssertEqual(interval.start, date("2026-07-14 23:00", calendar: singapore))
        XCTAssertEqual(interval.end, date("2026-07-15 07:00", calendar: singapore))
    }
}
```

- [ ] **Step 2: Run the schedule tests and verify the red state**

Run:

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SleepyTests/SleepScheduleTests
```

Expected: compilation fails because `SleepSchedule` does not exist.

- [ ] **Step 3: Add the minimal calendar resolver**

Create `Sleepy/SleepSchedule.swift`:

```swift
import Foundation

enum SleepSchedule {
    static func interval(
        on bedtimeDay: Date,
        bedtime: Date,
        wakeTime: Date,
        calendar: Calendar = .current
    ) -> DateInterval {
        let start = date(on: bedtimeDay, usingTimeFrom: bedtime, calendar: calendar)
        let bedtimeMinutes = minutesSinceMidnight(bedtime, calendar: calendar)
        let wakeMinutes = minutesSinceMidnight(wakeTime, calendar: calendar)
        let wakeDay = wakeMinutes > bedtimeMinutes
            ? bedtimeDay
            : calendar.date(byAdding: .day, value: 1, to: bedtimeDay)!
        let end = date(on: wakeDay, usingTimeFrom: wakeTime, calendar: calendar)
        return DateInterval(start: start, end: end)
    }

    static func currentOrNext(
        at now: Date,
        bedtime: Date,
        wakeTime: Date,
        calendar: Calendar = .current
    ) -> DateInterval {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let previous = interval(on: yesterday, bedtime: bedtime, wakeTime: wakeTime, calendar: calendar)
        if previous.contains(now) { return previous }

        let today = interval(on: now, bedtime: bedtime, wakeTime: wakeTime, calendar: calendar)
        if now <= today.end { return today }

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        return interval(on: tomorrow, bedtime: bedtime, wakeTime: wakeTime, calendar: calendar)
    }

    private static func date(on day: Date, usingTimeFrom time: Date, calendar: Calendar) -> Date {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: day)
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = dayParts.year
        components.month = dayParts.month
        components.day = dayParts.day
        components.hour = timeParts.hour
        components.minute = timeParts.minute
        return calendar.date(from: components)!
    }

    private static func minutesSinceMidnight(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
```

- [ ] **Step 4: Replace the skeleton model fields with durable 0002 facts**

In `Sleepy/Models.swift`, retain `AppStage` and replace the remaining declarations with these exact enums and stored fields:

```swift
enum PermissionState: String, Codable {
    case unknown
    case approved
    case denied
    case unavailable
}

enum BrushingStatus: String, Codable {
    case notStarted
    case started
    case done
    case skipped
}

enum SleepStatus: String, Codable {
    case notStarted
    case active
    case completed
    case ended
}

@Model
final class UserSettings {
    var targetBedtime: Date
    var wakeTime: Date
    var hasCompletedOnboarding: Bool
    var notificationPermissionRawValue: String
    var screenTimePermissionRawValue: String
    var activitySelectionData: Data

    init(
        targetBedtime: Date = .now,
        wakeTime: Date = .now,
        hasCompletedOnboarding: Bool = false,
        notificationPermission: PermissionState = .unknown,
        screenTimePermission: PermissionState = .unknown,
        activitySelectionData: Data = Data()
    ) {
        self.targetBedtime = targetBedtime
        self.wakeTime = wakeTime
        self.hasCompletedOnboarding = hasCompletedOnboarding
        notificationPermissionRawValue = notificationPermission.rawValue
        screenTimePermissionRawValue = screenTimePermission.rawValue
        self.activitySelectionData = activitySelectionData
    }
}

@Model
final class SleepSession {
    @Attribute(.unique) var id: UUID
    var scheduledBedtime: Date
    var scheduledWakeTime: Date
    var actualStartTime: Date?
    var actualEndTime: Date?
    var brushingStatusRawValue: String
    var brushingRewardGranted: Bool
    var sleepStatusRawValue: String
    var snoozeCount: Int
    var endedEarly: Bool
    var sleepRewardGranted: Bool

    init(id: UUID = UUID(), interval: DateInterval) {
        self.id = id
        scheduledBedtime = interval.start
        scheduledWakeTime = interval.end
        brushingStatusRawValue = BrushingStatus.notStarted.rawValue
        brushingRewardGranted = false
        sleepStatusRawValue = SleepStatus.notStarted.rawValue
        snoozeCount = 0
        endedEarly = false
        sleepRewardGranted = false
    }
}

@Model
final class ProgressProfile {
    var xp: Int
    var coins: Int
    var currentStreak: Int
    var bestStreak: Int
    var lastCompletedSleepDate: Date?

    init(
        xp: Int = 0,
        coins: Int = 0,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        lastCompletedSleepDate: Date? = nil
    ) {
        self.xp = xp
        self.coins = coins
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.lastCompletedSleepDate = lastCompletedSleepDate
    }
}

extension UserSettings {
    var notificationPermission: PermissionState {
        get { PermissionState(rawValue: notificationPermissionRawValue) ?? .unknown }
        set { notificationPermissionRawValue = newValue.rawValue }
    }

    var screenTimePermission: PermissionState {
        get { PermissionState(rawValue: screenTimePermissionRawValue) ?? .unknown }
        set { screenTimePermissionRawValue = newValue.rawValue }
    }
}

extension SleepSession {
    var brushingStatus: BrushingStatus {
        get { BrushingStatus(rawValue: brushingStatusRawValue) ?? .notStarted }
        set { brushingStatusRawValue = newValue.rawValue }
    }

    var sleepStatus: SleepStatus {
        get { SleepStatus(rawValue: sleepStatusRawValue) ?? .notStarted }
        set { sleepStatusRawValue = newValue.rawValue }
    }
}
```

- [ ] **Step 5: Run the focused tests**

Run the Task 1 test command again.

Expected: `TEST SUCCEEDED`; five tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sleepy/Models.swift Sleepy/SleepSchedule.swift SleepyTests/SleepScheduleTests.swift
git commit -m "Add durable nightly schedule state"
```

---

### Task 2: Make `SleepyStore` Persist Transitions, Progress, Rewards, and Recovery

**Files:**
- Modify: `Sleepy/SleepyStore.swift`
- Modify: `SleepyTests/SleepyStoreTests.swift`

**Interfaces:**
- Consumes: Task 1 models and `SleepSchedule`
- Produces: `configure(modelContext:)`, derived `stage`, `routineProgress`, durable brush/sleep actions, `recover(at:calendar:)`, and idempotent rewards
- Produces: persisted shield-status messaging so the UI can state whether real shielding was applied

- [ ] **Step 1: Replace in-memory tests with an in-memory SwiftData harness**

Use this setup at the top of `SleepyStoreTests`:

```swift
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
        store.configure(modelContext: context)
        store.finishOnboarding()
        calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
    }
}
```

Add focused tests with these assertions:

```swift
func testBrushingRewardIsIdempotent() throws {
    let now = Date(timeIntervalSince1970: 1_752_500_000)
    try store.beginBrushing(at: now, calendar: calendar)
    try store.finishBrushing(at: now, calendar: calendar)
    try store.finishBrushing(at: now, calendar: calendar)

    XCTAssertEqual(store.profile.xp, 10)
    XCTAssertEqual(store.profile.coins, 2)
    XCTAssertEqual(store.routineProgress, 0.5)
}

func testSnoozeCountPersistsAndStopsAtThree() throws {
    let now = Date(timeIntervalSince1970: 1_752_500_000)
    XCTAssertTrue(try store.recordSnooze(at: now, calendar: calendar))
    XCTAssertTrue(try store.recordSnooze(at: now, calendar: calendar))
    XCTAssertTrue(try store.recordSnooze(at: now, calendar: calendar))
    XCTAssertFalse(try store.recordSnooze(at: now, calendar: calendar))

    let relaunched = SleepyStore()
    relaunched.configure(modelContext: context)
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
    try store.makeCompletedNight(at: calendar.date(byAdding: .day, value: 1, to: first)!, calendar: calendar)
    XCTAssertEqual(store.profile.currentStreak, 2)
    XCTAssertEqual(store.profile.bestStreak, 2)

    try store.makeCompletedNight(at: calendar.date(byAdding: .day, value: 3, to: first)!, calendar: calendar)
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
    XCTAssertEqual(store.routineProgress, 1)

    let next = calendar.date(byAdding: .day, value: 1, to: first)!
    try store.beginBrushing(at: next, calendar: calendar)
    XCTAssertEqual(store.routineProgress, 0)
}
```

`makeCompletedNight(at:calendar:)` is test-only shorthand placed in a private extension in the test file. It must call public store actions rather than mutate reward flags directly:

```swift
private extension SleepyStore {
    func makeCompletedNight(at date: Date, calendar: Calendar) throws {
        try beginBrushing(at: date, calendar: calendar)
        try finishBrushing(at: date, calendar: calendar)
        try markSleepActive(at: date, calendar: calendar)
        try recover(at: session!.scheduledWakeTime, calendar: calendar)
        showHome()
    }
}
```

- [ ] **Step 2: Run store tests and verify the red state**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SleepyTests/SleepyStoreTests
```

Expected: compilation fails because the durable store API does not exist.

- [ ] **Step 3: Implement the smallest persisted store surface**

Replace the scalar state in `SleepyStore` with:

```swift
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SleepyStore {
    private var modelContext: ModelContext?
    private(set) var settings = UserSettings()
    private(set) var profile = ProgressProfile()
    private(set) var session: SleepSession?
    private(set) var isShowingSettings = false
    private(set) var recoveryMessage: String?
    private(set) var shieldStatusMessage = "Distracting apps are not being blocked."

    var stage: AppStage {
        if !settings.hasCompletedOnboarding { return .onboarding }
        if isShowingSettings { return .settings }
        guard let session else { return .home }
        switch session.sleepStatus {
        case .active: return .sleepActive
        case .completed, .ended: return .summary
        case .notStarted:
            switch session.brushingStatus {
            case .started: return .brushing
            case .done, .skipped: return .startSleep
            case .notStarted: return .home
            }
        }
    }

    var routineProgress: Double {
        guard let session else { return 0 }
        var value = session.brushingStatus == .done || session.brushingStatus == .skipped ? 0.5 : 0
        if session.sleepStatus != .notStarted { value += 0.5 }
        return value
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        settings = fetch(UserSettings.self).first ?? insert(UserSettings())
        profile = fetch(ProgressProfile.self).first ?? insert(ProgressProfile())
        session = fetch(SleepSession.self)
            .sorted { $0.scheduledBedtime > $1.scheduledBedtime }
            .first
        try? modelContext.save()
    }
}
```

Implement direct action methods with these exact rules:

```swift
func beginBrushing(at now: Date = .now, calendar: Calendar = .current) throws {
    let current = try ensureSession(at: now, calendar: calendar)
    current.brushingStatus = .started
    try save()
}

func finishBrushing(at now: Date = .now, calendar: Calendar = .current) throws {
    let current = try ensureSession(at: now, calendar: calendar)
    current.brushingStatus = .done
    if !current.brushingRewardGranted {
        profile.xp += 10
        profile.coins += 2
        current.brushingRewardGranted = true
    }
    try save()
}

func skipBrushing(at now: Date = .now, calendar: Calendar = .current) throws {
    let current = try ensureSession(at: now, calendar: calendar)
    current.brushingStatus = .skipped
    try save()
}

func recordSnooze(at now: Date = .now, calendar: Calendar = .current) throws -> Bool {
    let current = try ensureSession(at: now, calendar: calendar)
    guard current.snoozeCount < 3 else {
        current.brushingStatus = .started
        try save()
        return false
    }
    current.snoozeCount += 1
    try save()
    return true
}

func markSleepActive(at now: Date = .now, calendar: Calendar = .current) throws {
    let current = try ensureSession(at: now, calendar: calendar)
    current.sleepStatus = .active
    current.actualStartTime = now
    try save()
}

func endEarly(at now: Date = .now) throws {
    guard let session else { return }
    session.sleepStatus = .ended
    session.endedEarly = true
    session.actualEndTime = now
    profile.currentStreak = 0
    try save()
}

func recover(at now: Date = .now, calendar: Calendar = .current) throws {
    guard let session, session.sleepStatus == .active, now >= session.scheduledWakeTime else { return }
    session.sleepStatus = .completed
    session.actualEndTime = session.scheduledWakeTime
    awardSleepIfNeeded(for: session, calendar: calendar)
    try save()
}
```

The private helpers must be concrete and local to `SleepyStore`:

```swift
private func ensureSession(at now: Date, calendar: Calendar) throws -> SleepSession {
    let interval = SleepSchedule.currentOrNext(
        at: now,
        bedtime: settings.targetBedtime,
        wakeTime: settings.wakeTime,
        calendar: calendar
    )
    if let session, calendar.isDate(session.scheduledBedtime, inSameDayAs: interval.start) {
        return session
    }
    if session?.sleepStatus == .active {
        recoveryMessage = "A stale Sleep Sanctuary was cleared before starting tonight."
    }
    let replacement = insert(SleepSession(interval: interval))
    session = replacement
    try save()
    return replacement
}

private func awardSleepIfNeeded(for session: SleepSession, calendar: Calendar) {
    guard !session.sleepRewardGranted else { return }
    profile.xp += 50
    profile.coins += 10
    let priorDay = calendar.date(byAdding: .day, value: -1, to: session.scheduledBedtime)!
    profile.currentStreak = profile.lastCompletedSleepDate.map {
        calendar.isDate($0, inSameDayAs: priorDay) ? profile.currentStreak + 1 : 1
    } ?? 1
    profile.bestStreak = max(profile.bestStreak, profile.currentStreak)
    profile.lastCompletedSleepDate = session.scheduledBedtime
    session.sleepRewardGranted = true
}

private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
    (try? modelContext?.fetch(FetchDescriptor<T>())) ?? []
}

@discardableResult
private func insert<T: PersistentModel>(_ value: T) -> T {
    modelContext?.insert(value)
    return value
}

private func save() throws {
    try modelContext?.save()
}
```

Add `finishOnboarding()`, `showSettings()`, `showHome()`, and a settings update method as thin mutations that save immediately. No second state model is needed.

- [ ] **Step 4: Run store tests**

Run the Task 2 test command again.

Expected: `TEST SUCCEEDED`; all durable transition, progress, recovery, reward, and streak tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sleepy/SleepyStore.swift SleepyTests/SleepyStoreTests.swift
git commit -m "Persist nightly flow and rewards"
```

---

### Task 3: Persist Screen Time Selection and Apply Honest Named Shields

**Files:**
- Create: `Sleepy/ScreenTimeNames.swift`
- Create: `Sleepy/Sleepy.entitlements`
- Modify: `Sleepy/ShieldClient.swift`
- Modify: `SleepyTests/ShieldClientTests.swift`
- Modify: `Sleepy.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `ScreenTimeNames.store` and `ScreenTimeNames.activity`
- Produces: `ShieldClient.authorizationStatus`, `requestAuthorization()`, selection encode/decode, `apply(selection:interval:)`, `clearShield()`, and store-derived `isActive`

- [ ] **Step 1: Add failing selection and clear tests**

Replace `ShieldClientTests.swift` with:

```swift
import FamilyControls
import XCTest
@testable import Sleepy

final class ShieldClientTests: XCTestCase {
    func testEmptySelectionRoundTrips() throws {
        let selection = FamilyActivitySelection(includeEntireCategory: true)
        let data = try ShieldClient.encode(selection)
        XCTAssertEqual(try ShieldClient.decode(data), selection)
    }

    func testInvalidSelectionDataThrows() {
        XCTAssertThrowsError(try ShieldClient.decode(Data([0xFF])))
    }

    func testMockApplyAndRepeatedClearAreSafe() throws {
        let client = ShieldClient(mocked: true)

        client.applyMockShield()
        XCTAssertTrue(client.isActive)
        client.clearShield()
        client.clearShield()
        XCTAssertFalse(client.isActive)
    }
}
```

- [ ] **Step 2: Run shield tests and verify the red state**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SleepyTests/ShieldClientTests
```

Expected: compilation fails because the selection API and named store do not exist.

- [ ] **Step 3: Add the shared names and app entitlement**

Create `Sleepy/ScreenTimeNames.swift` and include it in both the app and the extension target created in Task 4:

```swift
import DeviceActivity
import ManagedSettings

enum ScreenTimeNames {
    static let store = ManagedSettingsStore.Name("sleepy.sleep-sanctuary")
    static let activity = DeviceActivityName("sleepy.sleep-sanctuary")
}
```

Create `Sleepy/Sleepy.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.family-controls</key>
    <true/>
</dict>
</plist>
```

Set `CODE_SIGN_ENTITLEMENTS = Sleepy/Sleepy.entitlements` for both app build configurations. Keep the current development team and bundle identifier unchanged.

- [ ] **Step 4: Implement real authorization, coding, apply, schedule, and clear**

Use these types in `ShieldClient.swift`:

```swift
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation

enum ShieldStartResult: Equatable {
    case shielded
    case unshielded(String)
}

@Observable
class ShieldClient {
    private let store: ManagedSettingsStore
    private let center: DeviceActivityCenter
    private let mocked: Bool
    private var mockIsActive = false

    init(
        store: ManagedSettingsStore = ManagedSettingsStore(named: ScreenTimeNames.store),
        center: DeviceActivityCenter = DeviceActivityCenter(),
        mocked: Bool = false
    ) {
        self.store = store
        self.center = center
        self.mocked = mocked
    }

    var authorizationStatus: PermissionState {
        #if targetEnvironment(simulator)
        return .unavailable
        #else
        let status = AuthorizationCenter.shared.authorizationStatus
        if #available(iOS 26.4, *), status == .approvedWithDataAccess { return .approved }
        switch status {
        case .approved: return .approved
        case .denied: return .denied
        case .notDetermined: return .unknown
        @unknown default: return .unavailable
        }
        #endif
    }

    var isActive: Bool {
        if mocked { return mockIsActive }
        return store.shield.applications?.isEmpty == false
            || store.shield.webDomains?.isEmpty == false
            || store.shield.applicationCategories != nil
    }

    static func encode(_ selection: FamilyActivitySelection) throws -> Data {
        try PropertyListEncoder().encode(selection)
    }

    static func decode(_ data: Data) throws -> FamilyActivitySelection {
        guard !data.isEmpty else { return FamilyActivitySelection(includeEntireCategory: true) }
        return try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func requestAuthorization() async -> PermissionState {
        #if targetEnvironment(simulator)
        return .unavailable
        #else
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return authorizationStatus
        } catch {
            return authorizationStatus == .unknown ? .denied : authorizationStatus
        }
        #endif
    }
}
```

Add the apply/clear methods. Do not report a session as shielded unless the named store actually contains a configuration:

```swift
func apply(
    selection: FamilyActivitySelection,
    interval: DateInterval,
    calendar: Calendar = .current
) -> ShieldStartResult {
    guard authorizationStatus == .approved else {
        return .unshielded("Screen Time access is unavailable, so distracting apps are not being blocked.")
    }
    guard !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty else {
        return .unshielded("No distracting apps are selected, so nothing is being blocked.")
    }

    store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty
        ? nil
        : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens

    let schedule = DeviceActivitySchedule(
        intervalStart: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: interval.start),
        intervalEnd: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: interval.end),
        repeats: false
    )
    do {
        center.stopMonitoring([ScreenTimeNames.activity])
        try center.startMonitoring(ScreenTimeNames.activity, during: schedule)
        return .shielded
    } catch {
        clearShield()
        return .unshielded("Automatic wake-time clearing could not be scheduled, so Sleepy removed the shield.")
    }
}

func clearShield() {
    mockIsActive = false
    center.stopMonitoring([ScreenTimeNames.activity])
    store.clearAllSettings()
}

func applyMockShield() {
    guard mocked else { return }
    mockIsActive = true
}
```

- [ ] **Step 5: Add selection persistence to `SleepyStore`**

Add derived state and one save method:

```swift
private(set) var activitySelection = FamilyActivitySelection(includeEntireCategory: true)
private(set) var selectionNeedsRepair = false

func restoreSelection() {
    do {
        activitySelection = try ShieldClient.decode(settings.activitySelectionData)
        selectionNeedsRepair = false
    } catch {
        activitySelection = FamilyActivitySelection(includeEntireCategory: true)
        settings.activitySelectionData = Data()
        selectionNeedsRepair = true
        try? save()
    }
}

func saveSelection(_ selection: FamilyActivitySelection) throws {
    settings.activitySelectionData = try ShieldClient.encode(selection)
    activitySelection = selection
    selectionNeedsRepair = false
    try save()
}
```

Call `restoreSelection()` at the end of `configure(modelContext:)`. A cancelled picker never calls `saveSelection`, so the existing value is preserved.

- [ ] **Step 6: Run shield tests and build the app target**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SleepyTests/ShieldClientTests
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: tests and build succeed. The Simulator reports Screen Time as unavailable and does not claim real shields are active.

- [ ] **Step 7: Commit**

```bash
git add Sleepy/ScreenTimeNames.swift Sleepy/Sleepy.entitlements Sleepy/ShieldClient.swift Sleepy/SleepyStore.swift SleepyTests/ShieldClientTests.swift Sleepy.xcodeproj/project.pbxproj
git commit -m "Persist and apply Screen Time selection"
```

---

### Task 4: Clear the Named Store from a Minimal Device Activity Extension

**Files:**
- Create: `SleepyDeviceActivityMonitor/DeviceActivityMonitorExtension.swift`
- Create: `SleepyDeviceActivityMonitor/Info.plist`
- Create: `SleepyDeviceActivityMonitor/SleepyDeviceActivityMonitor.entitlements`
- Modify: `Sleepy.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `ScreenTimeNames.store` and `ScreenTimeNames.activity`
- Produces: `SleepyDeviceActivityMonitor.appex`, embedded in `Sleepy.app`

- [ ] **Step 1: Add the extension target using Xcode**

Use File → New → Target → Device Activity Monitor Extension with:

1. Product name: `SleepyDeviceActivityMonitor`.
2. Deployment target: iOS 17.0.
3. Bundle identifier: `com.dereksun.sleepy.dev.DeviceActivityMonitor`.
4. Development team: preserve `3TYHDNVA4Y` from the current project.
5. Embed the extension in the `Sleepy` app target.
6. Add `Sleepy/ScreenTimeNames.swift` to both target memberships.
7. Do not enable App Groups.

- [ ] **Step 2: Replace the template extension with the single required callback**

Create `SleepyDeviceActivityMonitor/DeviceActivityMonitorExtension.swift`:

```swift
import DeviceActivity
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == ScreenTimeNames.activity else { return }
        ManagedSettingsStore(named: ScreenTimeNames.store).clearAllSettings()
    }
}
```

Create `SleepyDeviceActivityMonitor/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.deviceactivity.monitor-extension</string>
        <key>NSExtensionPrincipalClass</key>
        <string>$(PRODUCT_MODULE_NAME).DeviceActivityMonitorExtension</string>
    </dict>
</dict>
</plist>
```

Create `SleepyDeviceActivityMonitor/SleepyDeviceActivityMonitor.entitlements` with the same Family Controls key used by the app. Set the extension's `CODE_SIGN_ENTITLEMENTS` and `INFOPLIST_FILE` to these paths.

- [ ] **Step 3: Build both targets**

```bash
xcodebuild -scheme Sleepy -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: `BUILD SUCCEEDED`, including `SleepyDeviceActivityMonitor.appex` in the app bundle.

- [ ] **Step 4: Run the first real-device gate before adding more architecture**

On one authorized iPhone:

1. Install the app with the app and extension Family Controls entitlements active.
2. Select at least one disposable test app.
3. Start a session ending a few minutes in the future.
4. Confirm the selected app is shielded.
5. Terminate Sleepy.
6. Use the device after the interval has ended.
7. Confirm the extension clears the shield on the first outside-interval device-use callback.

If step 7 fails, capture device console output and entitlement values, then revise the spec before adding an App Group or another extension. Do not add either preemptively.

- [ ] **Step 5: Commit**

```bash
git add SleepyDeviceActivityMonitor Sleepy/ScreenTimeNames.swift Sleepy.xcodeproj/project.pbxproj
git commit -m "Clear sleep shields at interval end"
```

---

### Task 5: Register Actionable Bedtime Notifications and Persist Every Response First

**Files:**
- Modify: `Sleepy/NotificationClient.swift`
- Create: `SleepyTests/NotificationClientTests.swift`
- Modify: `SleepyTests/SleepyStoreTests.swift`

**Interfaces:**
- Produces: `NotificationAction`, `NotificationID`, category registration, permission refresh, request builders, nightly replacement, snooze scheduling, follow-up cancellation
- Produces: `SleepyStore.handleNotificationAction(_:notifications:at:calendar:)`

- [ ] **Step 1: Write failing notification request tests**

Create `SleepyTests/NotificationClientTests.swift`:

```swift
import UserNotifications
import XCTest
@testable import Sleepy

final class NotificationClientTests: XCTestCase {
    func testStableIdentifiers() {
        XCTAssertEqual(NotificationID.prompt, "bedtime.prompt")
        XCTAssertEqual(NotificationID.noResponse, "bedtime.no-response")
        XCTAssertEqual(NotificationID.snooze(3), "bedtime.snooze.3")
    }

    func testPromptContainsCategoryCopyAndRequestedDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        let date = Date(timeIntervalSince1970: 1_752_500_000)
        let request = NotificationClient.makePromptRequest(id: NotificationID.prompt, at: date, calendar: calendar)

        XCTAssertEqual(request.identifier, "bedtime.prompt")
        XCTAssertEqual(request.content.body, "Are you brushing your teeth now?")
        XCTAssertEqual(request.content.categoryIdentifier, NotificationID.category)
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, calendar.component(.hour, from: date))
        XCTAssertEqual(trigger?.dateComponents.minute, calendar.component(.minute, from: date))
    }

    func testFollowUpHasStableCopyAndNoActionCategory() {
        let request = NotificationClient.makeNoResponseRequest(at: .now, calendar: .current)
        XCTAssertEqual(request.identifier, NotificationID.noResponse)
        XCTAssertEqual(request.content.body, "Alright man, it's getting late, stop trolling.")
        XCTAssertEqual(request.content.categoryIdentifier, "")
    }

    func testCategoryHasExactlyFourForegroundActions() {
        let category = NotificationClient.bedtimeCategory()
        XCTAssertEqual(category.identifier, NotificationID.category)
        XCTAssertEqual(category.actions.map(\.identifier), NotificationAction.allCases.map(\.rawValue))
        XCTAssertTrue(category.actions.allSatisfy { $0.options.contains(.foreground) })
    }
}
```

- [ ] **Step 2: Run notification tests and verify the red state**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SleepyTests/NotificationClientTests
```

Expected: compilation fails because the identifiers and builders do not exist.

- [ ] **Step 3: Add fixed identifiers and pure request builders**

At the top of `NotificationClient.swift`, add:

```swift
enum NotificationID {
    static let category = "bedtime.actions"
    static let prompt = "bedtime.prompt"
    static let noResponse = "bedtime.no-response"
    static func snooze(_ count: Int) -> String { "bedtime.snooze.\(count)" }
    static let all = [prompt, noResponse] + (1...3).map(snooze)
}

enum NotificationAction: String, CaseIterable {
    case startingNow = "bedtime.starting-now"
    case snooze = "bedtime.snooze"
    case alreadyDone = "bedtime.already-done"
    case skipTonight = "bedtime.skip-tonight"
}
```

Implement `bedtimeCategory()`, `makePromptRequest`, and `makeNoResponseRequest` as pure static functions. The category action titles must be exactly `Starting now`, `Remind me in 5 minutes`, `Already done`, and `Skip tonight`, in that order, with `.foreground` on every action so a fourth snooze can enter the in-app flow.

Implement concrete center operations:

```swift
func registerCategories() {
    center.setNotificationCategories([Self.bedtimeCategory()])
}

func permissionStatus() async -> PermissionState {
    switch await center.notificationSettings().authorizationStatus {
    case .authorized, .provisional, .ephemeral: return .approved
    case .denied: return .denied
    case .notDetermined: return .unknown
    @unknown default: return .unavailable
    }
}

func scheduleNight(interval: DateInterval, calendar: Calendar = .current) async throws {
    center.removePendingNotificationRequests(withIdentifiers: NotificationID.all)
    try await center.add(Self.makePromptRequest(id: NotificationID.prompt, at: interval.start, calendar: calendar))
    let followUp = calendar.date(byAdding: .minute, value: 10, to: interval.start)!
    try await center.add(Self.makeNoResponseRequest(at: followUp, calendar: calendar))
}

func scheduleSnooze(count: Int, from now: Date, calendar: Calendar = .current) async throws {
    let date = calendar.date(byAdding: .minute, value: 5, to: now)!
    try await center.add(Self.makePromptRequest(id: NotificationID.snooze(count), at: date, calendar: calendar))
}

func cancelNoResponseFollowUp() {
    center.removePendingNotificationRequests(withIdentifiers: [NotificationID.noResponse])
}
```

Make `NotificationClient` non-final and give it a default `UNUserNotificationCenter.current()` initializer parameter so tests can override only scheduling/cancellation while pure builders need no protocol. Retain `requestPermission()` and map its resulting authoritative settings through `permissionStatus()`.

- [ ] **Step 4: Add store action tests**

Add this recording client and one test for each notification action to `SleepyStoreTests`:

```swift
private final class RecordingNotificationClient: NotificationClient {
    var scheduledSnoozeCounts: [Int] = []
    var cancelCount = 0

    override func permissionStatus() async -> PermissionState { .approved }

    override func scheduleSnooze(count: Int, from now: Date, calendar: Calendar) async throws {
        scheduledSnoozeCounts.append(count)
    }

    override func cancelNoResponseFollowUp() {
        cancelCount += 1
    }
}

func testStartingNowPersistsStartedBrushing() async throws {
    let notifications = RecordingNotificationClient()
    let now = Date(timeIntervalSince1970: 1_752_500_000)
    try await store.handleNotificationAction(.startingNow, notifications: notifications, at: now, calendar: calendar)

    let relaunched = SleepyStore()
    relaunched.configure(modelContext: context)
    XCTAssertEqual(relaunched.session?.brushingStatus, .started)
    XCTAssertEqual(relaunched.stage, .brushing)
    XCTAssertEqual(notifications.cancelCount, 1)
}

func testAlreadyDonePersistsRewardBeforeRouting() async throws {
    let notifications = RecordingNotificationClient()
    let now = Date(timeIntervalSince1970: 1_752_500_000)
    try await store.handleNotificationAction(.alreadyDone, notifications: notifications, at: now, calendar: calendar)

    let relaunched = SleepyStore()
    relaunched.configure(modelContext: context)
    XCTAssertEqual(relaunched.session?.brushingStatus, .done)
    XCTAssertEqual(relaunched.profile.xp, 10)
    XCTAssertTrue(relaunched.session?.brushingRewardGranted == true)
    XCTAssertEqual(relaunched.stage, .startSleep)
}

func testSkipPersistsNoRewardBeforeRouting() async throws {
    let notifications = RecordingNotificationClient()
    let now = Date(timeIntervalSince1970: 1_752_500_000)
    try await store.handleNotificationAction(.skipTonight, notifications: notifications, at: now, calendar: calendar)

    let relaunched = SleepyStore()
    relaunched.configure(modelContext: context)
    XCTAssertEqual(relaunched.session?.brushingStatus, .skipped)
    XCTAssertEqual(relaunched.profile.xp, 0)
    XCTAssertFalse(relaunched.session?.brushingRewardGranted == true)
    XCTAssertEqual(relaunched.stage, .startSleep)
}

func testFourthSnoozeRoutesToBrushingWithoutSchedulingAnother() async throws {
    let notifications = RecordingNotificationClient()
    let now = Date(timeIntervalSince1970: 1_752_500_000)
    for _ in 0..<4 {
        try await store.handleNotificationAction(.snooze, notifications: notifications, at: now, calendar: calendar)
    }

    XCTAssertEqual(store.session?.snoozeCount, 3)
    XCTAssertEqual(store.stage, .brushing)
    XCTAssertEqual(notifications.scheduledSnoozeCounts, [1, 2, 3])
}
```

Each test must create an in-memory model context, invoke `handleNotificationAction`, create a second `SleepyStore` on the same context, and assert against the relaunched store. Use a small `RecordingNotificationClient` subclass that records `scheduledSnoozeCounts` and `cancelCount`; make only the scheduling/cancellation methods overridable rather than adding a broad notification protocol.

- [ ] **Step 5: Implement response handling in persistence-first order**

Add this switch to `SleepyStore`:

```swift
func handleNotificationAction(
    _ action: NotificationAction,
    notifications: NotificationClient,
    at now: Date = .now,
    calendar: Calendar = .current
) async throws {
    notifications.cancelNoResponseFollowUp()
    switch action {
    case .startingNow:
        try beginBrushing(at: now, calendar: calendar)
    case .alreadyDone:
        try finishBrushing(at: now, calendar: calendar)
    case .skipTonight:
        try skipBrushing(at: now, calendar: calendar)
    case .snooze:
        if try recordSnooze(at: now, calendar: calendar), let count = session?.snoozeCount {
            try await notifications.scheduleSnooze(count: count, from: now, calendar: calendar)
        }
    }
}
```

The state save occurs inside each store action before notification scheduling or UI routing. If scheduling fails, the persisted snooze count remains truthful and the UI exposes the error.

Add the schedule update path so onboarding completion and bedtime edits replace obsolete requests:

```swift
func updateSchedule(
    bedtime: Date,
    wakeTime: Date,
    notifications: NotificationClient,
    at now: Date = .now,
    calendar: Calendar = .current
) async throws {
    settings.targetBedtime = bedtime
    settings.wakeTime = wakeTime
    try save()
    let interval = SleepSchedule.currentOrNext(at: now, bedtime: bedtime, wakeTime: wakeTime, calendar: calendar)
    try await notifications.scheduleNight(interval: interval, calendar: calendar)
}
```

Call this before `finishOnboarding()` and whenever Settings saves changed times.

- [ ] **Step 6: Run notification and store tests**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SleepyTests/NotificationClientTests -only-testing:SleepyTests/SleepyStoreTests
```

Expected: all request and persisted-response tests pass.

- [ ] **Step 7: Commit**

```bash
git add Sleepy/NotificationClient.swift Sleepy/SleepyStore.swift SleepyTests/NotificationClientTests.swift SleepyTests/SleepyStoreTests.swift
git commit -m "Persist actionable bedtime notifications"
```

---

### Task 6: Wire App Launch, Foreground Recovery, Shield Safety, and Notification Forwarding

**Files:**
- Modify: `Sleepy/SleepyApp.swift`
- Modify: `Sleepy/NotificationClient.swift`
- Modify: `Sleepy/SleepyStore.swift`
- Modify: `SleepyTests/SleepyStoreTests.swift`

**Interfaces:**
- Produces: `AppDelegate` forwarding one of four known action identifiers
- Produces: `SleepyStore.activate(notifications:shield:at:calendar:)`
- Produces: coordinated `startSleep(shield:at:calendar:)` and `endEarly(shield:at:)`

- [ ] **Step 1: Add safety-first coordination tests**

Add this narrow recording client and the safety tests to `SleepyStoreTests`:

```swift
private final class RecordingShieldClient: ShieldClient {
    var clearCount = 0
    var applyResult = ShieldStartResult.shielded
    var reportsActive = false
    var onClear: (() -> Void)?

    override var authorizationStatus: PermissionState { .approved }
    override var isActive: Bool { reportsActive }

    override func apply(
        selection: FamilyActivitySelection,
        interval: DateInterval,
        calendar: Calendar
    ) -> ShieldStartResult {
        reportsActive = applyResult == .shielded
        return applyResult
    }

    override func clearShield() {
        onClear?()
        clearCount += 1
        reportsActive = false
    }
}

func testRecoveryAfterWakeClearsBeforeAwarding() async throws {
    let shield = RecordingShieldClient(mocked: true)
    let notifications = RecordingNotificationClient()
    let now = Date(timeIntervalSince1970: 1_752_500_000)
    try store.markSleepActive(at: now, calendar: calendar)
    shield.onClear = { XCTAssertEqual(self.store.session?.sleepStatus, .active) }

    await store.activate(
        notifications: notifications,
        shield: shield,
        at: store.session!.scheduledWakeTime,
        calendar: calendar
    )

    XCTAssertEqual(shield.clearCount, 1)
    XCTAssertEqual(store.session?.sleepStatus, .completed)
    XCTAssertTrue(store.session?.sleepRewardGranted == true)
}

func testSchedulingFailureContinuesAsVisibleUnshieldedSession() throws {
    let shield = RecordingShieldClient(mocked: true)
    shield.applyResult = .unshielded("Automatic wake-time clearing could not be scheduled, so Sleepy removed the shield.")
    let now = Date(timeIntervalSince1970: 1_752_500_000)

    try store.startSleep(shield: shield, at: now, calendar: calendar)

    XCTAssertEqual(store.session?.sleepStatus, .active)
    XCTAssertFalse(shield.isActive)
    XCTAssertEqual(
        store.shieldStatusMessage,
        "Automatic wake-time clearing could not be scheduled, so Sleepy removed the shield."
    )
}

func testEndEarlyRepeatedlyClearsAndNeverAwardsSleep() throws {
    let shield = RecordingShieldClient(mocked: true)
    let now = Date(timeIntervalSince1970: 1_752_500_000)
    try store.markSleepActive(at: now, calendar: calendar)

    try store.endEarly(shield: shield, at: now)
    try store.endEarly(shield: shield, at: now)

    XCTAssertEqual(shield.clearCount, 2)
    XCTAssertFalse(store.session?.sleepRewardGranted == true)
    XCTAssertEqual(store.profile.currentStreak, 0)
}

func testDecodeFailureClearsDataAndShowsRepairMessage() throws {
    store.settings.activitySelectionData = Data([0xFF])
    try context.save()

    let relaunched = SleepyStore()
    relaunched.configure(modelContext: context)

    XCTAssertTrue(relaunched.activitySelection.applicationTokens.isEmpty)
    XCTAssertTrue(relaunched.activitySelection.categoryTokens.isEmpty)
    XCTAssertTrue(relaunched.activitySelection.webDomainTokens.isEmpty)
    XCTAssertTrue(relaunched.selectionNeedsRepair)
    XCTAssertTrue(relaunched.settings.activitySelectionData.isEmpty)
}
```

Keep the mock specific: a `RecordingShieldClient` subclass overrides only `apply`, `clearShield`, `isActive`, and authorization state. Do not add a service registry.

- [ ] **Step 2: Run store tests and verify the red state**

Run the Task 5 combined test command.

Expected: new coordination tests fail because activation and shield-aware actions do not exist.

- [ ] **Step 3: Add coordinated store methods**

Implement the order explicitly:

```swift
func activate(
    notifications: NotificationClient,
    shield: ShieldClient,
    at now: Date = .now,
    calendar: Calendar = .current
) async {
    settings.notificationPermission = await notifications.permissionStatus()
    settings.screenTimePermission = shield.authorizationStatus
    if settings.screenTimePermission != .approved, session?.sleepStatus == .active {
        shield.clearShield()
        shieldStatusMessage = "Screen Time access is unavailable, so distracting apps are not being blocked."
    }
    if let session, session.sleepStatus == .active, now >= session.scheduledWakeTime {
        shield.clearShield()
        try? recover(at: now, calendar: calendar)
    }
    try? save()
}

func startSleep(
    shield: ShieldClient,
    at now: Date = .now,
    calendar: Calendar = .current
) throws {
    let current = try ensureSession(at: now, calendar: calendar)
    let result = shield.apply(
        selection: activitySelection,
        interval: DateInterval(start: current.scheduledBedtime, end: current.scheduledWakeTime),
        calendar: calendar
    )
    do {
        try markSleepActive(at: now, calendar: calendar)
        switch result {
        case .shielded:
            shieldStatusMessage = "Selected distractions are shielded."
        case .unshielded(let message):
            shieldStatusMessage = message
        }
    } catch {
        shield.clearShield()
        throw error
    }
}

func endEarly(shield: ShieldClient, at now: Date = .now) throws {
    shield.clearShield()
    try endEarly(at: now)
}
```

`unshieldedReason` must distinguish denied/unavailable Screen Time from an empty selection. On any inconsistent active-state fetch or decode error during `configure`, clear via `activate`, preserve recorded progress fields, and present `recoveryMessage`.

- [ ] **Step 4: Add a purpose-built app delegate**

Append to `NotificationClient.swift`:

```swift
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var responseHandler: ((NotificationAction) -> Void)?
    private var pendingAction: NotificationAction?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let action = NotificationAction(rawValue: response.actionIdentifier) else { return }
        if let responseHandler { responseHandler(action) } else { pendingAction = action }
    }

    func installResponseHandler(_ handler: @escaping (NotificationAction) -> Void) {
        responseHandler = handler
        if let pendingAction {
            self.pendingAction = nil
            handler(pendingAction)
        }
    }
}
```

- [ ] **Step 5: Wire the app entry and foreground scene phase**

Update `SleepyApp` to own one instance of each existing object, configure the store from `RootView`'s model context, register categories at startup, install the delegate callback, and call `activate` whenever `scenePhase` becomes `.active`:

```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
@Environment(\.scenePhase) private var scenePhase
```

The installed handler must call `store.handleNotificationAction` in a `Task { @MainActor in ... }`. Do not interpret URLs or add a navigation coordinator.

- [ ] **Step 6: Run tests and build**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SleepyTests/SleepyStoreTests
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: recovery/coordination tests pass and the app builds.

- [ ] **Step 7: Commit**

```bash
git add Sleepy/SleepyApp.swift Sleepy/NotificationClient.swift Sleepy/SleepyStore.swift SleepyTests/SleepyStoreTests.swift
git commit -m "Recover durable sessions on activation"
```

---

### Task 7: Make Every Required State Understandable with Plain SwiftUI

**Files:**
- Modify: `Sleepy/RootView.swift`

**Interfaces:**
- Consumes: store-derived `stage`, `routineProgress`, permission values, selection, profile, session, and shield status
- Produces: setup, home, brushing, start sleep, active sleep, summary, settings, picker, End early confirmation, and one-second completion hold

- [ ] **Step 1: Put the persistent header outside the screen switch**

Use this hierarchy so the header never moves into individual screen content:

```swift
NavigationStack {
    VStack(spacing: 0) {
        if displayedStage != .sleepActive {
            RoutineProgressHeader(progress: store.routineProgress)
                .padding()
        }
        ScrollView {
            stageContent
                .frame(maxWidth: .infinity)
                .padding()
        }
    }
}
```

Define `RoutineProgressHeader` in `RootView.swift` with one `ProgressView(value:total:)` and the text `Brush → Sleep`. Do not create a design system or animation wrapper.

- [ ] **Step 2: Implement honest setup and settings rows**

Both setup and settings must render:

- Bedtime and wake `DatePicker`s.
- Notification row showing Unknown, Allowed, Denied, or Unavailable.
- Screen Time row showing Unknown, Allowed, Denied, or Unavailable.
- `Allow notifications` and `Allow Screen Time` buttons only when useful.
- `Open System Settings` using `UIApplication.openSettingsURLString` for denied permission.
- `Choose distracting apps` only when Screen Time is approved and the picker is supported.
- Selection text computed from the three token sets: `No apps selected` or `N apps, N categories, N websites selected`.
- `Clear selection` in Settings, implemented by saving a new empty `FamilyActivitySelection`.
- A visible reselection message when `selectionNeedsRepair` is true.

Present the native picker with:

```swift
.familyActivityPicker(isPresented: $isPickerPresented, selection: $draftSelection)
```

Copy `store.activitySelection` into `draftSelection` before presentation. Save only from an explicit `Save selection` action; dismissing/cancelling leaves persisted data unchanged.

- [ ] **Step 3: Implement scheduled, limited, and ready Home states**

Home must show the next resolved bedtime, current XP/coins/streak, and exactly one of:

- `Ready for bedtime` when notifications and Screen Time are approved and selection is non-empty.
- `Scheduled; reminders are inactive` when notifications are denied/unavailable.
- `Scheduled; app blocking is unavailable` when Screen Time is denied/unavailable.
- `Scheduled; choose distracting apps to enable blocking` when selection is empty.

Keep the manual `Start brushing`/`Continue bedtime routine` action available in every permission state.

- [ ] **Step 4: Implement brush, sleep start, active, End early, and summary states**

Wire buttons directly to store actions:

```swift
Button("Done brushing") { try? store.finishBrushing() }
Button("Skip tonight") { try? store.skipBrushing() }
```

For starting sleep, the one-second hold must be tied to the successful persisted transition:

```swift
@State private var holdsCompletedProgress = false

private func startSleep() {
    holdsCompletedProgress = true
    do {
        try store.startSleep(shield: shield)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            holdsCompletedProgress = false
        }
    } catch {
        holdsCompletedProgress = false
    }
}

private var displayedStage: AppStage {
    holdsCompletedProgress ? .startSleep : store.stage
}
```

Because `routineProgress` reads the persisted active session, a failed attempt remains at 50%; a successful attempt renders 100% for one second, then the active screen replaces it. Relaunching an already-active session does not replay the hold.

The active screen shows scheduled wake time and `store.shieldStatusMessage`. `End early` first presents a standard `confirmationDialog`; only its destructive confirmation calls `store.endEarly(shield:)`.

The summary text must distinguish:

- completed: `Sleep Sanctuary reached your planned wake time.`
- ended early: `Sleep Sanctuary ended early. No sleep completion reward was granted.`

Both summary variants retain 100% routine progress, and returning Home keeps 100% for that same session.

- [ ] **Step 5: Add functional error/recovery presentation**

Use one `.alert` bound to store/client errors and one inline recovery message. Required visible cases are invalid saved selection, notification scheduling failure, Device Activity scheduling failure, and stale-session recovery. Do not add an error framework.

- [ ] **Step 6: Build and run the simulator checklist**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Manually verify:

1. Setup reaches Home with unavailable Screen Time.
2. Denied notifications leave the manual flow usable.
3. Empty selection text is accurate.
4. Brush → Start Sleep → End early → Summary works.
5. Header remains pinned, reaches 100% for one second, hides only on active Sleep Sanctuary, and returns at 100% on Summary.
6. Relaunch recovery can be exercised with persisted data and injected dates in tests.

- [ ] **Step 7: Commit**

```bash
git add Sleepy/RootView.swift
git commit -m "Show functional bedtime and recovery states"
```

---

### Task 8: Run Full Verification and Record Real-Device Evidence

**Files:**
- Create: `docs/iterations/0002-functional-mvp/checklist.md`
- Create: `docs/iterations/0002-functional-mvp/test-notes.md`

**Interfaces:**
- Consumes: all prior tasks
- Produces: auditable simulator and physical-device completion evidence

- [ ] **Step 1: Create the acceptance checklist**

Create `checklist.md` with one unchecked line for every acceptance criterion in spec section 13, plus separate lines for:

- simulator tests/build
- real Family Controls entitlement approval
- all four notification actions
- fourth-snooze behavior
- End early clearing
- outside-interval extension clearing while the main app is terminated
- relaunch reward idempotency
- denied/revoked/empty-selection states

- [ ] **Step 2: Create the evidence template**

Create `test-notes.md`:

```markdown
# Sleepy 0002 Functional MVP Test Notes

## Automated Commands

## Simulator

## Physical iPhone

- Device model:
- iOS version:
- App entitlement:
- Extension entitlement:
- Notification actions:
- FamilyActivityPicker save/restore:
- Shield apply:
- End early clear:
- Outside-interval extension clear with app terminated:
- Wake-time relaunch and reward idempotency:
- Permission denial/revocation:

## Known Platform Limits

The Device Activity interval-end callback is expected on the first device use outside the interval, not at an exact wake-time minute.
```

- [ ] **Step 3: Run the full automated suite and builds**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
xcodebuild -scheme Sleepy -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: every command ends with `SUCCEEDED`. Record the command, simulator/runtime, test count, and result in `test-notes.md`.

- [ ] **Step 4: Run the complete physical-iPhone matrix**

Execute every physical-iPhone check from spec section 12. Test the extension using first device use after the interval, not an exact-minute expectation. Terminate/relaunch between actions where persistence matters. Record the actual device model, iOS version, entitlement status, each result, and any console evidence.

- [ ] **Step 5: Re-run rewards and recovery after the device flow**

Reopen the same completed session twice and confirm XP, coins, current streak, and best streak do not change on the second recovery. Start a new nightly session and confirm routine progress resets to 0% only then.

- [ ] **Step 6: Mark only evidenced checklist items complete**

Leave any failed or unrun physical-device item unchecked. Simulator success alone must not mark iteration 0002 complete.

- [ ] **Step 7: Commit verification records**

```bash
git add docs/iterations/0002-functional-mvp/checklist.md docs/iterations/0002-functional-mvp/test-notes.md
git commit -m "Record functional MVP verification"
```

---

## Completion Gate

0002 is complete only when the full XCTest suite and both simulator/device builds pass, all persisted relaunch paths behave correctly, the real iPhone applies selected shields, End early clears them immediately, the Device Activity extension clears them on first outside-interval use with the app terminated, and the device evidence is recorded. App Groups, custom shield extensions, UI-test scaffolding, repositories, reducer frameworks, and third-party packages remain skipped; add one only after a measured platform or maintenance failure proves the smaller design insufficient.
