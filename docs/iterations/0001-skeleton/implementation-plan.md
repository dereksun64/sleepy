# Sleepy 0001 Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first native iOS skeleton for Sleepy: guided setup, bedtime reminder flow, brushing confirmation, Sleep Sanctuary session state, mock/real shield boundary, and morning progress summary.

**Architecture:** Use SwiftUI MVVM-lite with services. Keep app screens functional and plain, put platform work behind small services, and keep core flow/progress calculations testable without launching the app.

**Tech Stack:** Swift, SwiftUI, SwiftData, UserNotifications, FamilyControls, ManagedSettings, DeviceActivity, XCTest, Xcode 26.6.

## Global Constraints

- Build a real Xcode iOS project skeleton.
- Use native iOS, not React Native.
- Use SwiftUI for screens.
- Use SwiftData for local durable app state.
- Use UserNotifications for bedtime prompts and follow-ups.
- Use FamilyControls for Screen Time authorization and app/category selection.
- Use ManagedSettings for real app shielding.
- Use DeviceActivity only where needed for the sleep/shield lifecycle.
- Use App Groups only if extension state sharing requires it.
- Include a Simulator/mock shielding path.
- Do not build polished visual design in iteration 0001.
- Do not build custom bedtime routines beyond Brush and Sleep.
- Do not build low-energy routine modes, accountability partners, weekly reports, widgets, Live Activities, HealthKit, iCloud sync, shared challenges, collectible sanctuary systems, advanced analytics, or production App Store polish.
- Bedtime notification copy: "Are you brushing your teeth now?"
- No-response follow-up copy: "Alright man, it's getting late, stop trolling."
- Bedtime notification actions: Starting now, Remind me in 5 minutes, Already done, Skip tonight.
- Snoozes are capped at 3 per night.
- Done brushing earns 10 XP and 2 coins.
- A sleep session that reaches scheduled wake time earns 50 XP and 10 coins.
- A sleep session that reaches scheduled wake time increments the current streak.
- Ending early records the session but does not grant the sleep completion reward or increment the streak.

---

## Planned File Structure

Create the Xcode project with this source layout:

```text
Sleepy.xcodeproj/
Sleepy/
  App/
    SleepyApp.swift
    AppRoute.swift
    AppEnvironment.swift
  Models/
    UserSettings.swift
    SleepSession.swift
    ProgressProfile.swift
    SleepyEnums.swift
  Services/
    AuthorizationService.swift
    NotificationService.swift
    ShieldService.swift
    SleepSessionService.swift
    ProgressService.swift
    ScheduleCalculator.swift
  Screens/
    RootView.swift
    Onboarding/
      OnboardingView.swift
      BedtimeSetupView.swift
      PermissionSetupView.swift
      ShieldSelectionView.swift
    Home/
      HomeView.swift
    Brushing/
      BrushingView.swift
    Sleep/
      StartSleepView.swift
      ActiveSleepView.swift
    Summary/
      MorningSummaryView.swift
    Settings/
      SettingsView.swift
SleepyTests/
  ScheduleCalculatorTests.swift
  SleepSessionServiceTests.swift
  ProgressServiceTests.swift
  MockShieldServiceTests.swift
  NotificationServiceTests.swift
docs/
  iterations/
    0001-skeleton/
      spec.md
      implementation-plan.md
      checklist.md
      test-notes.md
```

Do not add extension targets until the main app skeleton compiles. Add extension targets only after the app target can build and the real shield boundary is in place.

---

### Task 1: Create The Native Xcode Project Shell

**Files:**
- Create: `Sleepy.xcodeproj`
- Create: `Sleepy/App/SleepyApp.swift`
- Create: `Sleepy/Screens/RootView.swift`
- Create: `SleepyTests/SleepyTests.swift`
- Modify: `.gitignore`
- Create: `docs/iterations/0001-skeleton/checklist.md`
- Create: `docs/iterations/0001-skeleton/test-notes.md`

**Interfaces:**
- Produces: app target named `Sleepy`
- Produces: test target named `SleepyTests`
- Produces: root SwiftUI entry point `SleepyApp`
- Produces: `RootView`

- [ ] **Step 1: Create the Xcode app project**

Use Xcode:

1. Open Xcode.
2. Choose File > New > Project.
3. Choose iOS > App.
4. Product Name: `Sleepy`.
5. Interface: `SwiftUI`.
6. Language: `Swift`.
7. Storage: `SwiftData`.
8. Include Tests: enabled.
9. Save into `/Users/dereksun/VSCode/sleepy`.

Expected files after creation:

```text
Sleepy.xcodeproj
Sleepy/
SleepyTests/
```

- [ ] **Step 2: Add `.gitignore`**

Create `.gitignore`:

```gitignore
.DS_Store
DerivedData/
*.xcuserdata/
*.xcuserstate
*.moved-aside
*.xccheckout
*.xcscmblueprint
build/
```

- [ ] **Step 3: Replace the generated app entry with a minimal shell**

Edit `Sleepy/App/SleepyApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct SleepyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

Edit `Sleepy/Screens/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    var body: some View {
        Text("Sleepy")
            .font(.largeTitle)
            .padding()
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 4: Add iteration checklist**

Create `docs/iterations/0001-skeleton/checklist.md`:

```markdown
# Sleepy 0001 Skeleton Checklist

- [ ] Native Xcode project builds.
- [ ] SwiftData models exist.
- [ ] Guided setup saves bedtime and wake time.
- [ ] Notification service schedules bedtime prompts.
- [ ] Brushing flow reaches Done brushing.
- [ ] Sleep flow starts and ends a session.
- [ ] Mock shield service applies and clears state.
- [ ] Real shield service compiles behind the native API boundary.
- [ ] Morning summary shows XP, coins, streak, and brushing status.
- [ ] Focused unit tests pass.
- [ ] Manual Simulator notes are recorded in test-notes.md.
```

- [ ] **Step 5: Add test notes file**

Create `docs/iterations/0001-skeleton/test-notes.md`:

```markdown
# Sleepy 0001 Skeleton Test Notes

## Automated Tests

Record test command, date, and result here after each implementation task.

## Simulator Checks

- Guided setup:
- Bedtime and wake time:
- Brushing flow:
- Sleep session:
- Mock shield state:
- Morning summary:

## Real Device Checks

- Notification permission:
- Screen Time permission:
- FamilyActivityPicker:
- Real app shield:
- Wake-time shield clearing:
- End early shield clearing:
```

- [ ] **Step 6: Build the empty shell**

Run:

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds. If `iPhone 16` is unavailable, list simulators with:

```bash
xcrun simctl list devices available
```

Then rerun using an available iPhone simulator name.

- [ ] **Step 7: Commit**

```bash
git add .gitignore Sleepy.xcodeproj Sleepy SleepyTests docs/iterations/0001-skeleton/checklist.md docs/iterations/0001-skeleton/test-notes.md
git commit -m "Add native iOS project shell"
```

---

### Task 2: Add Core Types And Schedule Calculation Tests

**Files:**
- Create: `Sleepy/Models/SleepyEnums.swift`
- Create: `Sleepy/Services/ScheduleCalculator.swift`
- Create: `SleepyTests/ScheduleCalculatorTests.swift`

**Interfaces:**
- Produces: `enum BrushingStatus: String, Codable, CaseIterable`
- Produces: `enum SleepStatus: String, Codable, CaseIterable`
- Produces: `enum NightFlowState: String, Codable, CaseIterable`
- Produces: `struct SleepWindow: Equatable`
- Produces: `struct ScheduleCalculator`
- Produces: `ScheduleCalculator.sleepWindow(for:bedtime:wakeTime:calendar:) -> SleepWindow`

- [ ] **Step 1: Write failing schedule tests**

Create `SleepyTests/ScheduleCalculatorTests.swift`:

```swift
import XCTest
@testable import Sleepy

final class ScheduleCalculatorTests: XCTestCase {
    func testOvernightSleepWindowEndsNextMorning() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let day = DateComponents(calendar: calendar, year: 2026, month: 7, day: 13).date!
        let bedtime = DateComponents(calendar: calendar, hour: 22, minute: 30).date!
        let wakeTime = DateComponents(calendar: calendar, hour: 6, minute: 45).date!

        let window = ScheduleCalculator.sleepWindow(
            for: day,
            bedtime: bedtime,
            wakeTime: wakeTime,
            calendar: calendar
        )

        XCTAssertEqual(calendar.component(.day, from: window.start), 13)
        XCTAssertEqual(calendar.component(.hour, from: window.start), 22)
        XCTAssertEqual(calendar.component(.minute, from: window.start), 30)
        XCTAssertEqual(calendar.component(.day, from: window.end), 14)
        XCTAssertEqual(calendar.component(.hour, from: window.end), 6)
        XCTAssertEqual(calendar.component(.minute, from: window.end), 45)
    }

    func testSameDayWakeTimeStaysSameDayWhenAfterBedtime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let day = DateComponents(calendar: calendar, year: 2026, month: 7, day: 13).date!
        let bedtime = DateComponents(calendar: calendar, hour: 1, minute: 0).date!
        let wakeTime = DateComponents(calendar: calendar, hour: 8, minute: 0).date!

        let window = ScheduleCalculator.sleepWindow(
            for: day,
            bedtime: bedtime,
            wakeTime: wakeTime,
            calendar: calendar
        )

        XCTAssertEqual(calendar.component(.day, from: window.start), 13)
        XCTAssertEqual(calendar.component(.hour, from: window.start), 1)
        XCTAssertEqual(calendar.component(.day, from: window.end), 13)
        XCTAssertEqual(calendar.component(.hour, from: window.end), 8)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/ScheduleCalculatorTests
```

Expected: fails because `ScheduleCalculator` does not exist.

- [ ] **Step 3: Add enums**

Create `Sleepy/Models/SleepyEnums.swift`:

```swift
import Foundation

enum BrushingStatus: String, Codable, CaseIterable {
    case notStarted
    case started
    case done
    case skipped
}

enum SleepStatus: String, Codable, CaseIterable {
    case notStarted
    case readyToStart
    case active
    case ended
}

enum NightFlowState: String, Codable, CaseIterable {
    case waitingForBedtime
    case bedtimePromptSent
    case brushingStarted
    case brushingDone
    case brushingSkipped
    case readyToStartSleep
    case sleepActive
    case sleepEnded
    case morningSummaryReady
    case morningSummaryShown
}
```

- [ ] **Step 4: Add schedule calculator**

Create `Sleepy/Services/ScheduleCalculator.swift`:

```swift
import Foundation

struct SleepWindow: Equatable {
    let start: Date
    let end: Date
}

struct ScheduleCalculator {
    static func sleepWindow(
        for day: Date,
        bedtime: Date,
        wakeTime: Date,
        calendar: Calendar = .current
    ) -> SleepWindow {
        let dayComponents = calendar.dateComponents([.year, .month, .day], from: day)
        let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: bedtime)
        let wakeComponents = calendar.dateComponents([.hour, .minute], from: wakeTime)

        var startComponents = DateComponents()
        startComponents.calendar = calendar
        startComponents.year = dayComponents.year
        startComponents.month = dayComponents.month
        startComponents.day = dayComponents.day
        startComponents.hour = bedtimeComponents.hour
        startComponents.minute = bedtimeComponents.minute

        var endComponents = DateComponents()
        endComponents.calendar = calendar
        endComponents.year = dayComponents.year
        endComponents.month = dayComponents.month
        endComponents.day = dayComponents.day
        endComponents.hour = wakeComponents.hour
        endComponents.minute = wakeComponents.minute

        let start = calendar.date(from: startComponents)!
        var end = calendar.date(from: endComponents)!

        if end <= start {
            end = calendar.date(byAdding: .day, value: 1, to: end)!
        }

        return SleepWindow(start: start, end: end)
    }
}
```

- [ ] **Step 5: Run tests and verify pass**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/ScheduleCalculatorTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sleepy/Models/SleepyEnums.swift Sleepy/Services/ScheduleCalculator.swift SleepyTests/ScheduleCalculatorTests.swift
git commit -m "Add sleep schedule calculation"
```

---

### Task 3: Add SwiftData Models

**Files:**
- Create: `Sleepy/Models/UserSettings.swift`
- Create: `Sleepy/Models/SleepSession.swift`
- Create: `Sleepy/Models/ProgressProfile.swift`
- Modify: `Sleepy/App/SleepyApp.swift`

**Interfaces:**
- Produces: `@Model final class UserSettings`
- Produces: `@Model final class SleepSession`
- Produces: `@Model final class ProgressProfile`
- Consumes: `BrushingStatus`, `SleepStatus`

- [ ] **Step 1: Add `UserSettings`**

Create `Sleepy/Models/UserSettings.swift`:

```swift
import Foundation
import SwiftData

@Model
final class UserSettings {
    var targetBedtime: Date
    var wakeTime: Date
    var hasCompletedOnboarding: Bool
    var notificationPermissionState: String
    var screenTimePermissionState: String
    var selectedShieldApplicationsData: Data?
    var selectedShieldCategoriesData: Data?
    var selectedShieldWebDomainsData: Data?

    init(
        targetBedtime: Date,
        wakeTime: Date,
        hasCompletedOnboarding: Bool = false,
        notificationPermissionState: String = "unknown",
        screenTimePermissionState: String = "unknown",
        selectedShieldApplicationsData: Data? = nil,
        selectedShieldCategoriesData: Data? = nil,
        selectedShieldWebDomainsData: Data? = nil
    ) {
        self.targetBedtime = targetBedtime
        self.wakeTime = wakeTime
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.notificationPermissionState = notificationPermissionState
        self.screenTimePermissionState = screenTimePermissionState
        self.selectedShieldApplicationsData = selectedShieldApplicationsData
        self.selectedShieldCategoriesData = selectedShieldCategoriesData
        self.selectedShieldWebDomainsData = selectedShieldWebDomainsData
    }
}
```

- [ ] **Step 2: Add `SleepSession`**

Create `Sleepy/Models/SleepSession.swift`:

```swift
import Foundation
import SwiftData

@Model
final class SleepSession {
    var id: UUID
    var date: Date
    var scheduledBedtime: Date
    var scheduledWakeTime: Date
    var actualStartTime: Date?
    var actualEndTime: Date?
    var brushingStatusRawValue: String
    var sleepStatusRawValue: String
    var snoozeCount: Int
    var endedEarly: Bool

    var brushingStatus: BrushingStatus {
        get { BrushingStatus(rawValue: brushingStatusRawValue) ?? .notStarted }
        set { brushingStatusRawValue = newValue.rawValue }
    }

    var sleepStatus: SleepStatus {
        get { SleepStatus(rawValue: sleepStatusRawValue) ?? .notStarted }
        set { sleepStatusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        scheduledBedtime: Date,
        scheduledWakeTime: Date,
        actualStartTime: Date? = nil,
        actualEndTime: Date? = nil,
        brushingStatus: BrushingStatus = .notStarted,
        sleepStatus: SleepStatus = .notStarted,
        snoozeCount: Int = 0,
        endedEarly: Bool = false
    ) {
        self.id = id
        self.date = date
        self.scheduledBedtime = scheduledBedtime
        self.scheduledWakeTime = scheduledWakeTime
        self.actualStartTime = actualStartTime
        self.actualEndTime = actualEndTime
        self.brushingStatusRawValue = brushingStatus.rawValue
        self.sleepStatusRawValue = sleepStatus.rawValue
        self.snoozeCount = snoozeCount
        self.endedEarly = endedEarly
    }
}
```

- [ ] **Step 3: Add `ProgressProfile`**

Create `Sleepy/Models/ProgressProfile.swift`:

```swift
import Foundation
import SwiftData

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
```

- [ ] **Step 4: Register SwiftData model container**

Edit `Sleepy/App/SleepyApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct SleepyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            UserSettings.self,
            SleepSession.self,
            ProgressProfile.self
        ])
    }
}
```

- [ ] **Step 5: Build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 6: Commit**

```bash
git add Sleepy/Models/UserSettings.swift Sleepy/Models/SleepSession.swift Sleepy/Models/ProgressProfile.swift Sleepy/App/SleepyApp.swift
git commit -m "Add SwiftData models"
```

---

### Task 4: Add Progress Calculation

**Files:**
- Create: `Sleepy/Services/ProgressService.swift`
- Create: `SleepyTests/ProgressServiceTests.swift`

**Interfaces:**
- Produces: `struct ProgressAward: Equatable`
- Produces: `struct MorningSummary: Equatable`
- Produces: `struct ProgressService`
- Produces: `ProgressService.award(for:completedAt:calendar:) -> ProgressAward`
- Produces: `ProgressService.apply(_:to:completedAt:calendar:)`

- [ ] **Step 1: Write failing tests**

Create `SleepyTests/ProgressServiceTests.swift`:

```swift
import XCTest
@testable import Sleepy

final class ProgressServiceTests: XCTestCase {
    func testCompletedSessionWithBrushingAwardsFullProgress() {
        let session = SleepSession(
            date: Date(timeIntervalSince1970: 100),
            scheduledBedtime: Date(timeIntervalSince1970: 100),
            scheduledWakeTime: Date(timeIntervalSince1970: 200),
            brushingStatus: .done,
            sleepStatus: .ended,
            endedEarly: false
        )

        let award = ProgressService.award(for: session, completedAt: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(award.xp, 60)
        XCTAssertEqual(award.coins, 12)
        XCTAssertTrue(award.incrementsStreak)
    }

    func testSkippedBrushingStillAllowsSleepReward() {
        let session = SleepSession(
            date: Date(timeIntervalSince1970: 100),
            scheduledBedtime: Date(timeIntervalSince1970: 100),
            scheduledWakeTime: Date(timeIntervalSince1970: 200),
            brushingStatus: .skipped,
            sleepStatus: .ended,
            endedEarly: false
        )

        let award = ProgressService.award(for: session, completedAt: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(award.xp, 50)
        XCTAssertEqual(award.coins, 10)
        XCTAssertTrue(award.incrementsStreak)
    }

    func testEndingEarlyDoesNotAwardSleepCompletion() {
        let session = SleepSession(
            date: Date(timeIntervalSince1970: 100),
            scheduledBedtime: Date(timeIntervalSince1970: 100),
            scheduledWakeTime: Date(timeIntervalSince1970: 200),
            brushingStatus: .done,
            sleepStatus: .ended,
            endedEarly: true
        )

        let award = ProgressService.award(for: session, completedAt: Date(timeIntervalSince1970: 150))

        XCTAssertEqual(award.xp, 10)
        XCTAssertEqual(award.coins, 2)
        XCTAssertFalse(award.incrementsStreak)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/ProgressServiceTests
```

Expected: fails because `ProgressService` does not exist.

- [ ] **Step 3: Add progress service**

Create `Sleepy/Services/ProgressService.swift`:

```swift
import Foundation

struct ProgressAward: Equatable {
    let xp: Int
    let coins: Int
    let incrementsStreak: Bool
}

struct MorningSummary: Equatable {
    let xpEarned: Int
    let coinsEarned: Int
    let currentStreak: Int
    let brushingStatus: BrushingStatus
    let message: String
}

struct ProgressService {
    static func award(
        for session: SleepSession,
        completedAt: Date,
        calendar: Calendar = .current
    ) -> ProgressAward {
        var xp = 0
        var coins = 0

        if session.brushingStatus == .done {
            xp += 10
            coins += 2
        }

        let completedSleep = !session.endedEarly && completedAt >= session.scheduledWakeTime
        if completedSleep {
            xp += 50
            coins += 10
        }

        return ProgressAward(xp: xp, coins: coins, incrementsStreak: completedSleep)
    }

    static func apply(
        _ award: ProgressAward,
        to profile: ProgressProfile,
        completedAt: Date,
        calendar: Calendar = .current
    ) {
        profile.xp += award.xp
        profile.coins += award.coins

        if award.incrementsStreak {
            profile.currentStreak += 1
            profile.bestStreak = max(profile.bestStreak, profile.currentStreak)
            profile.lastCompletedSleepDate = completedAt
        }
    }

    static func summary(
        for session: SleepSession,
        award: ProgressAward,
        profile: ProgressProfile
    ) -> MorningSummary {
        MorningSummary(
            xpEarned: award.xp,
            coinsEarned: award.coins,
            currentStreak: profile.currentStreak,
            brushingStatus: session.brushingStatus,
            message: award.incrementsStreak ? "Sleep Sanctuary completed." : "Sleep session recorded."
        )
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/ProgressServiceTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sleepy/Services/ProgressService.swift SleepyTests/ProgressServiceTests.swift
git commit -m "Add progress rewards"
```

---

### Task 5: Add Shield Service Boundary And Mock Implementation

**Files:**
- Create: `Sleepy/Services/ShieldService.swift`
- Create: `SleepyTests/MockShieldServiceTests.swift`

**Interfaces:**
- Produces: `protocol ShieldServicing`
- Produces: `struct ShieldSelection: Equatable, Codable`
- Produces: `final class MockShieldService: ShieldServicing`
- Produces: `final class ManagedSettingsShieldService: ShieldServicing`

- [ ] **Step 1: Write failing mock shield tests**

Create `SleepyTests/MockShieldServiceTests.swift`:

```swift
import XCTest
@testable import Sleepy

final class MockShieldServiceTests: XCTestCase {
    func testMockShieldApplyAndClear() async throws {
        let service = MockShieldService()
        let selection = ShieldSelection(mockNames: ["TikTok", "Instagram"])

        try await service.apply(selection)

        XCTAssertTrue(await service.isShieldActive)
        XCTAssertEqual(await service.activeSelection, selection)

        try await service.clear()

        XCTAssertFalse(await service.isShieldActive)
        XCTAssertNil(await service.activeSelection)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/MockShieldServiceTests
```

Expected: fails because `MockShieldService` does not exist.

- [ ] **Step 3: Add shield services**

Create `Sleepy/Services/ShieldService.swift`:

```swift
import Foundation

#if canImport(ManagedSettings)
import ManagedSettings
#endif

struct ShieldSelection: Equatable, Codable {
    var mockNames: [String]

    static let empty = ShieldSelection(mockNames: [])
}

protocol ShieldServicing {
    func apply(_ selection: ShieldSelection) async throws
    func clear() async throws
}

actor MockShieldService: ShieldServicing {
    private(set) var isShieldActive = false
    private(set) var activeSelection: ShieldSelection?

    func apply(_ selection: ShieldSelection) async throws {
        activeSelection = selection
        isShieldActive = true
    }

    func clear() async throws {
        activeSelection = nil
        isShieldActive = false
    }
}

final class ManagedSettingsShieldService: ShieldServicing {
    #if canImport(ManagedSettings)
    private let store = ManagedSettingsStore()
    #endif

    func apply(_ selection: ShieldSelection) async throws {
        #if targetEnvironment(simulator)
        return
        #else
        #if canImport(ManagedSettings)
        _ = selection
        // Real token application is wired after FamilyActivitySelection persistence is added.
        #endif
        #endif
    }

    func clear() async throws {
        #if canImport(ManagedSettings)
        store.clearAllSettings()
        #endif
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/MockShieldServiceTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sleepy/Services/ShieldService.swift SleepyTests/MockShieldServiceTests.swift
git commit -m "Add shield service boundary"
```

---

### Task 6: Add Sleep Session Service

**Files:**
- Create: `Sleepy/Services/SleepSessionService.swift`
- Create: `SleepyTests/SleepSessionServiceTests.swift`

**Interfaces:**
- Consumes: `ShieldServicing`
- Consumes: `SleepSession`
- Produces: `final class SleepSessionService`
- Produces: `SleepSessionService.startBrushing(session:)`
- Produces: `SleepSessionService.finishBrushing(session:)`
- Produces: `SleepSessionService.skipBrushing(session:)`
- Produces: `SleepSessionService.startSleep(session:selection:now:) async throws`
- Produces: `SleepSessionService.endSleep(session:endedEarly:now:) async throws`
- Produces: `SleepSessionService.snooze(session:) -> Bool`

- [ ] **Step 1: Write failing session service tests**

Create `SleepyTests/SleepSessionServiceTests.swift`:

```swift
import XCTest
@testable import Sleepy

final class SleepSessionServiceTests: XCTestCase {
    func testBrushingTransitionsToReadyToStartSleep() {
        let service = SleepSessionService(shieldService: MockShieldService())
        let session = SleepSession(
            date: Date(),
            scheduledBedtime: Date(),
            scheduledWakeTime: Date().addingTimeInterval(3600)
        )

        service.startBrushing(session: session)
        XCTAssertEqual(session.brushingStatus, .started)

        service.finishBrushing(session: session)
        XCTAssertEqual(session.brushingStatus, .done)
        XCTAssertEqual(session.sleepStatus, .readyToStart)
    }

    func testSnoozeCapsAtThree() {
        let service = SleepSessionService(shieldService: MockShieldService())
        let session = SleepSession(
            date: Date(),
            scheduledBedtime: Date(),
            scheduledWakeTime: Date().addingTimeInterval(3600)
        )

        XCTAssertTrue(service.snooze(session: session))
        XCTAssertTrue(service.snooze(session: session))
        XCTAssertTrue(service.snooze(session: session))
        XCTAssertFalse(service.snooze(session: session))
        XCTAssertEqual(session.snoozeCount, 3)
    }

    func testStartAndEndSleepCallsShieldService() async throws {
        let shield = MockShieldService()
        let service = SleepSessionService(shieldService: shield)
        let session = SleepSession(
            date: Date(),
            scheduledBedtime: Date(),
            scheduledWakeTime: Date().addingTimeInterval(3600),
            brushingStatus: .done,
            sleepStatus: .readyToStart
        )

        try await service.startSleep(
            session: session,
            selection: ShieldSelection(mockNames: ["TikTok"]),
            now: Date(timeIntervalSince1970: 10)
        )

        XCTAssertEqual(session.sleepStatus, .active)
        XCTAssertEqual(session.actualStartTime, Date(timeIntervalSince1970: 10))
        XCTAssertTrue(await shield.isShieldActive)

        try await service.endSleep(
            session: session,
            endedEarly: true,
            now: Date(timeIntervalSince1970: 20)
        )

        XCTAssertEqual(session.sleepStatus, .ended)
        XCTAssertTrue(session.endedEarly)
        XCTAssertFalse(await shield.isShieldActive)
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/SleepSessionServiceTests
```

Expected: fails because `SleepSessionService` does not exist.

- [ ] **Step 3: Add session service**

Create `Sleepy/Services/SleepSessionService.swift`:

```swift
import Foundation

final class SleepSessionService {
    private let shieldService: ShieldServicing

    init(shieldService: ShieldServicing) {
        self.shieldService = shieldService
    }

    func startBrushing(session: SleepSession) {
        session.brushingStatus = .started
    }

    func finishBrushing(session: SleepSession) {
        session.brushingStatus = .done
        session.sleepStatus = .readyToStart
    }

    func skipBrushing(session: SleepSession) {
        session.brushingStatus = .skipped
        session.sleepStatus = .readyToStart
    }

    @discardableResult
    func snooze(session: SleepSession) -> Bool {
        guard session.snoozeCount < 3 else {
            return false
        }

        session.snoozeCount += 1
        return true
    }

    func startSleep(
        session: SleepSession,
        selection: ShieldSelection,
        now: Date = .now
    ) async throws {
        session.sleepStatus = .active
        session.actualStartTime = now
        try await shieldService.apply(selection)
    }

    func endSleep(
        session: SleepSession,
        endedEarly: Bool,
        now: Date = .now
    ) async throws {
        session.sleepStatus = .ended
        session.actualEndTime = now
        session.endedEarly = endedEarly
        try await shieldService.clear()
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/SleepSessionServiceTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sleepy/Services/SleepSessionService.swift SleepyTests/SleepSessionServiceTests.swift
git commit -m "Add sleep session state service"
```

---

### Task 7: Add Notification Service Boundary

**Files:**
- Create: `Sleepy/Services/NotificationService.swift`
- Create: `SleepyTests/NotificationServiceTests.swift`

**Interfaces:**
- Produces: `enum BedtimeNotificationAction: String`
- Produces: `protocol NotificationScheduling`
- Produces: `struct ScheduledNotification: Equatable`
- Produces: `final class MockNotificationScheduler`
- Produces: `final class NotificationService`
- Produces: `NotificationService.bedtimePrompt(at:) async throws`
- Produces: `NotificationService.snoozeReminder(at:snoozeNumber:) async throws`
- Produces: `NotificationService.noResponseFollowUp(at:) async throws`

- [ ] **Step 1: Write failing notification tests**

Create `SleepyTests/NotificationServiceTests.swift`:

```swift
import XCTest
@testable import Sleepy

final class NotificationServiceTests: XCTestCase {
    func testSchedulesBedtimePromptWithExpectedCopy() async throws {
        let scheduler = MockNotificationScheduler()
        let service = NotificationService(scheduler: scheduler)
        let date = Date(timeIntervalSince1970: 100)

        try await service.bedtimePrompt(at: date)

        XCTAssertEqual(scheduler.scheduled, [
            ScheduledNotification(
                identifier: "bedtime.prompt",
                title: "Sleepy",
                body: "Are you brushing your teeth now?",
                date: date
            )
        ])
    }

    func testSchedulesNoResponseFollowUpWithExpectedCopy() async throws {
        let scheduler = MockNotificationScheduler()
        let service = NotificationService(scheduler: scheduler)
        let date = Date(timeIntervalSince1970: 700)

        try await service.noResponseFollowUp(at: date)

        XCTAssertEqual(scheduler.scheduled.first?.identifier, "bedtime.no-response-follow-up")
        XCTAssertEqual(scheduler.scheduled.first?.body, "Alright man, it's getting late, stop trolling.")
    }
}
```

- [ ] **Step 2: Run tests and verify failure**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/NotificationServiceTests
```

Expected: fails because notification service types do not exist.

- [ ] **Step 3: Add notification service**

Create `Sleepy/Services/NotificationService.swift`:

```swift
import Foundation
import UserNotifications

enum BedtimeNotificationAction: String {
    case startingNow = "STARTING_NOW"
    case remindInFive = "REMIND_IN_FIVE"
    case alreadyDone = "ALREADY_DONE"
    case skipTonight = "SKIP_TONIGHT"
}

struct ScheduledNotification: Equatable {
    let identifier: String
    let title: String
    let body: String
    let date: Date
}

protocol NotificationScheduling {
    func schedule(_ notification: ScheduledNotification) async throws
}

final class MockNotificationScheduler: NotificationScheduling {
    private(set) var scheduled: [ScheduledNotification] = []

    func schedule(_ notification: ScheduledNotification) async throws {
        scheduled.append(notification)
    }
}

final class UserNotificationScheduler: NotificationScheduling {
    func schedule(_ notification: ScheduledNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: notification.date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notification.identifier,
            content: content,
            trigger: trigger
        )

        try await UNUserNotificationCenter.current().add(request)
    }
}

final class NotificationService {
    private let scheduler: NotificationScheduling

    init(scheduler: NotificationScheduling) {
        self.scheduler = scheduler
    }

    func bedtimePrompt(at date: Date) async throws {
        try await scheduler.schedule(ScheduledNotification(
            identifier: "bedtime.prompt",
            title: "Sleepy",
            body: "Are you brushing your teeth now?",
            date: date
        ))
    }

    func snoozeReminder(at date: Date, snoozeNumber: Int) async throws {
        try await scheduler.schedule(ScheduledNotification(
            identifier: "bedtime.snooze.\(snoozeNumber)",
            title: "Sleepy",
            body: "Are you brushing your teeth now?",
            date: date
        ))
    }

    func noResponseFollowUp(at date: Date) async throws {
        try await scheduler.schedule(ScheduledNotification(
            identifier: "bedtime.no-response-follow-up",
            title: "Sleepy",
            body: "Alright man, it's getting late, stop trolling.",
            date: date
        ))
    }
}
```

- [ ] **Step 4: Run tests and verify pass**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/NotificationServiceTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sleepy/Services/NotificationService.swift SleepyTests/NotificationServiceTests.swift
git commit -m "Add notification scheduling boundary"
```

---

### Task 8: Add Authorization Service And App Environment

**Files:**
- Create: `Sleepy/Services/AuthorizationService.swift`
- Create: `Sleepy/App/AppEnvironment.swift`
- Modify: `Sleepy/App/SleepyApp.swift`

**Interfaces:**
- Produces: `enum PermissionState: String, Codable`
- Produces: `@MainActor final class AuthorizationService`
- Produces: `@MainActor final class AppEnvironment: ObservableObject`

- [ ] **Step 1: Add authorization service**

Create `Sleepy/Services/AuthorizationService.swift`:

```swift
import Foundation
import UserNotifications

#if canImport(FamilyControls)
import FamilyControls
#endif

enum PermissionState: String, Codable {
    case unknown
    case approved
    case denied
    case unavailable
}

@MainActor
final class AuthorizationService: ObservableObject {
    @Published private(set) var notificationState: PermissionState = .unknown
    @Published private(set) var screenTimeState: PermissionState = .unknown

    func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            notificationState = granted ? .approved : .denied
        } catch {
            notificationState = .denied
        }
    }

    func requestScreenTime() async {
        #if targetEnvironment(simulator)
        screenTimeState = .unavailable
        #else
        #if canImport(FamilyControls)
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            screenTimeState = .approved
        } catch {
            screenTimeState = .denied
        }
        #else
        screenTimeState = .unavailable
        #endif
        #endif
    }
}
```

- [ ] **Step 2: Add app environment**

Create `Sleepy/App/AppEnvironment.swift`:

```swift
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let authorizationService: AuthorizationService
    let notificationService: NotificationService
    let shieldService: ShieldServicing
    let sleepSessionService: SleepSessionService

    init(
        authorizationService: AuthorizationService = AuthorizationService(),
        notificationService: NotificationService = NotificationService(scheduler: UserNotificationScheduler()),
        shieldService: ShieldServicing = MockShieldService()
    ) {
        self.authorizationService = authorizationService
        self.notificationService = notificationService
        self.shieldService = shieldService
        self.sleepSessionService = SleepSessionService(shieldService: shieldService)
    }
}
```

- [ ] **Step 3: Inject environment into app**

Edit `Sleepy/App/SleepyApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct SleepyApp: App {
    @StateObject private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
        }
        .modelContainer(for: [
            UserSettings.self,
            SleepSession.self,
            ProgressProfile.self
        ])
    }
}
```

- [ ] **Step 4: Build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add Sleepy/Services/AuthorizationService.swift Sleepy/App/AppEnvironment.swift Sleepy/App/SleepyApp.swift
git commit -m "Add app environment and authorization service"
```

---

### Task 9: Add Skeleton Screens And Routing

**Files:**
- Create: `Sleepy/App/AppRoute.swift`
- Modify: `Sleepy/Screens/RootView.swift`
- Create: `Sleepy/Screens/Onboarding/OnboardingView.swift`
- Create: `Sleepy/Screens/Onboarding/BedtimeSetupView.swift`
- Create: `Sleepy/Screens/Onboarding/PermissionSetupView.swift`
- Create: `Sleepy/Screens/Onboarding/ShieldSelectionView.swift`
- Create: `Sleepy/Screens/Home/HomeView.swift`
- Create: `Sleepy/Screens/Brushing/BrushingView.swift`
- Create: `Sleepy/Screens/Sleep/StartSleepView.swift`
- Create: `Sleepy/Screens/Sleep/ActiveSleepView.swift`
- Create: `Sleepy/Screens/Summary/MorningSummaryView.swift`
- Create: `Sleepy/Screens/Settings/SettingsView.swift`

**Interfaces:**
- Produces: `enum AppRoute`
- Consumes: `AppEnvironment`
- Consumes: SwiftData model container

- [ ] **Step 1: Add routes**

Create `Sleepy/App/AppRoute.swift`:

```swift
import Foundation

enum AppRoute: Hashable {
    case onboarding
    case home
    case brushing
    case startSleep
    case activeSleep
    case morningSummary
    case settings
}
```

- [ ] **Step 2: Add root routing**

Edit `Sleepy/Screens/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @State private var route: AppRoute = .onboarding

    var body: some View {
        NavigationStack {
            screen
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch route {
        case .onboarding:
            OnboardingView(route: $route)
        case .home:
            HomeView(route: $route)
        case .brushing:
            BrushingView(route: $route)
        case .startSleep:
            StartSleepView(route: $route)
        case .activeSleep:
            ActiveSleepView(route: $route)
        case .morningSummary:
            MorningSummaryView(route: $route)
        case .settings:
            SettingsView(route: $route)
        }
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 3: Add onboarding screen**

Create `Sleepy/Screens/Onboarding/OnboardingView.swift`:

```swift
import SwiftUI

struct OnboardingView: View {
    @Binding var route: AppRoute
    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case 0:
                Text("Sleepy")
                    .font(.largeTitle)
                Text("Set bedtime, brush your teeth, start Sleep Sanctuary, and block distractions.")
                    .multilineTextAlignment(.center)
            case 1:
                BedtimeSetupView()
            case 2:
                PermissionSetupView()
            default:
                ShieldSelectionView()
            }

            Button(step == 3 ? "Finish setup" : "Continue") {
                if step == 3 {
                    route = .home
                } else {
                    step += 1
                }
            }
        }
        .padding()
    }
}
```

- [ ] **Step 4: Add home screen skeleton**

Create `Sleepy/Screens/Home/HomeView.swift`:

```swift
import SwiftUI

struct HomeView: View {
    @Binding var route: AppRoute

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                stat(title: "Streak", value: "0")
                stat(title: "XP", value: "0")
                stat(title: "Coins", value: "0")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.headline)
                ProgressView(value: 0.0)
                Text("Brush -> Sleep")
                    .font(.caption)
            }

            VStack(spacing: 8) {
                Text("Bedtime")
                    .font(.headline)
                Text("10:30 PM")
                    .font(.title)
            }

            Button("Start brushing") {
                route = .brushing
            }
            .buttonStyle(.borderedProminent)

            Button("Settings") {
                route = .settings
            }
        }
        .padding()
    }

    private func stat(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.title2)
            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 5: Add flow screens**

Create `Sleepy/Screens/Brushing/BrushingView.swift`:

```swift
import SwiftUI

struct BrushingView: View {
    @Binding var route: AppRoute

    var body: some View {
        VStack(spacing: 24) {
            Text("Brush your teeth")
                .font(.title)
            Button("Done brushing") {
                route = .startSleep
            }
            .buttonStyle(.borderedProminent)
            Button("Skip tonight") {
                route = .startSleep
            }
        }
        .padding()
    }
}
```

Create `Sleepy/Screens/Sleep/StartSleepView.swift`:

```swift
import SwiftUI

struct StartSleepView: View {
    @Binding var route: AppRoute

    var body: some View {
        VStack(spacing: 24) {
            Text("Start Sleep Sanctuary")
                .font(.title)
            Text("Selected distracting apps will be shielded until wake time.")
                .multilineTextAlignment(.center)
            Button("Start Sleep Sanctuary") {
                route = .activeSleep
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

Create `Sleepy/Screens/Sleep/ActiveSleepView.swift`:

```swift
import SwiftUI

struct ActiveSleepView: View {
    @Binding var route: AppRoute

    var body: some View {
        VStack(spacing: 24) {
            Text("Sleep Sanctuary is active")
                .font(.title)
            Text("Shielding is active in real mode or simulated in mock mode.")
                .multilineTextAlignment(.center)
            Button("End early") {
                route = .morningSummary
            }
        }
        .padding()
    }
}
```

Create `Sleepy/Screens/Summary/MorningSummaryView.swift`:

```swift
import SwiftUI

struct MorningSummaryView: View {
    @Binding var route: AppRoute

    var body: some View {
        VStack(spacing: 24) {
            Text("Morning Summary")
                .font(.title)
            Text("+0 XP")
            Text("+0 coins")
            Text("Streak: 0")
            Text("Sleep session recorded.")
            Button("Back home") {
                route = .home
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

- [ ] **Step 6: Add setup/settings screens**

Create `Sleepy/Screens/Onboarding/BedtimeSetupView.swift`:

```swift
import SwiftUI

struct BedtimeSetupView: View {
    @State private var bedtime = Date()
    @State private var wakeTime = Date()

    var body: some View {
        Form {
            DatePicker("Bedtime", selection: $bedtime, displayedComponents: .hourAndMinute)
            DatePicker("Wake time", selection: $wakeTime, displayedComponents: .hourAndMinute)
        }
        .navigationTitle("Sleep schedule")
    }
}
```

Create `Sleepy/Screens/Onboarding/PermissionSetupView.swift`:

```swift
import SwiftUI

struct PermissionSetupView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        Form {
            Button("Request notifications") {
                Task { await environment.authorizationService.requestNotifications() }
            }
            Button("Request Screen Time") {
                Task { await environment.authorizationService.requestScreenTime() }
            }
            Text("Notifications: \(environment.authorizationService.notificationState.rawValue)")
            Text("Screen Time: \(environment.authorizationService.screenTimeState.rawValue)")
        }
        .navigationTitle("Permissions")
    }
}
```

Create `Sleepy/Screens/Onboarding/ShieldSelectionView.swift`:

```swift
import SwiftUI

struct ShieldSelectionView: View {
    var body: some View {
        Form {
            Text("App selection will use FamilyActivityPicker on device.")
            Text("Simulator uses mock shield selection.")
        }
        .navigationTitle("Shielded apps")
    }
}
```

Create `Sleepy/Screens/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Binding var route: AppRoute

    var body: some View {
        Form {
            Section("Schedule") {
                BedtimeSetupView()
            }
            Section("Permissions") {
                PermissionSetupView()
            }
            Section("Shielding") {
                ShieldSelectionView()
            }
            Button("Done") {
                route = .home
            }
        }
        .navigationTitle("Settings")
    }
}
```

- [ ] **Step 7: Build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 8: Commit**

```bash
git add Sleepy/App/AppRoute.swift Sleepy/Screens
git commit -m "Add skeleton screens and routing"
```

---

### Task 10: Wire The Skeleton Flow To Services And State

**Files:**
- Modify: `Sleepy/Screens/Home/HomeView.swift`
- Modify: `Sleepy/Screens/Brushing/BrushingView.swift`
- Modify: `Sleepy/Screens/Sleep/StartSleepView.swift`
- Modify: `Sleepy/Screens/Sleep/ActiveSleepView.swift`
- Modify: `Sleepy/Screens/Summary/MorningSummaryView.swift`
- Modify: `Sleepy/Screens/RootView.swift`

**Interfaces:**
- Consumes: `SleepSessionService`
- Consumes: `ProgressService`
- Consumes: `ShieldSelection`

- [ ] **Step 1: Add root in-memory skeleton state**

Edit `Sleepy/Screens/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @State private var route: AppRoute = .onboarding
    @State private var brushingStatus: BrushingStatus = .notStarted
    @State private var sleepStatus: SleepStatus = .notStarted
    @State private var xp = 0
    @State private var coins = 0
    @State private var streak = 0

    var body: some View {
        NavigationStack {
            screen
        }
    }

    @ViewBuilder
    private var screen: some View {
        switch route {
        case .onboarding:
            OnboardingView(route: $route)
        case .home:
            HomeView(
                route: $route,
                brushingStatus: brushingStatus,
                sleepStatus: sleepStatus,
                xp: xp,
                coins: coins,
                streak: streak
            )
        case .brushing:
            BrushingView(
                route: $route,
                onDone: {
                    brushingStatus = .done
                    sleepStatus = .readyToStart
                },
                onSkip: {
                    brushingStatus = .skipped
                    sleepStatus = .readyToStart
                }
            )
        case .startSleep:
            StartSleepView(
                route: $route,
                onStart: {
                    sleepStatus = .active
                }
            )
        case .activeSleep:
            ActiveSleepView(
                route: $route,
                onEnd: {
                    sleepStatus = .ended
                    xp += brushingStatus == .done ? 10 : 0
                    coins += brushingStatus == .done ? 2 : 0
                }
            )
        case .morningSummary:
            MorningSummaryView(
                route: $route,
                xp: xp,
                coins: coins,
                streak: streak,
                brushingStatus: brushingStatus
            )
        case .settings:
            SettingsView(route: $route)
        }
    }
}

#Preview {
    RootView()
}
```

- [ ] **Step 2: Replace `HomeView` with state-aware skeleton**

Edit `Sleepy/Screens/Home/HomeView.swift`:

```swift
import SwiftUI

struct HomeView: View {
    @Binding var route: AppRoute
    let brushingStatus: BrushingStatus
    let sleepStatus: SleepStatus
    let xp: Int
    let coins: Int
    let streak: Int

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                stat(title: "Streak", value: "\(streak)")
                stat(title: "XP", value: "\(xp)")
                stat(title: "Coins", value: "\(coins)")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.headline)
                ProgressView(value: progressValue)
                Text("Brush -> Sleep")
                    .font(.caption)
            }

            VStack(spacing: 8) {
                Text("Bedtime")
                    .font(.headline)
                Text("10:30 PM")
                    .font(.title)
            }

            Button(primaryActionTitle) {
                route = primaryActionRoute
            }
            .buttonStyle(.borderedProminent)

            Button("Settings") {
                route = .settings
            }
        }
        .padding()
    }

    private var progressValue: Double {
        var completed = 0.0
        if brushingStatus == .done || brushingStatus == .skipped {
            completed += 1.0
        }
        if sleepStatus == .ended {
            completed += 1.0
        }
        return completed / 2.0
    }

    private var primaryActionTitle: String {
        if sleepStatus == .active { return "View Sleep Sanctuary" }
        if sleepStatus == .ended { return "View morning summary" }
        if sleepStatus == .readyToStart { return "Start Sleep Sanctuary" }
        if brushingStatus == .started { return "Done brushing" }
        return "Start brushing"
    }

    private var primaryActionRoute: AppRoute {
        if sleepStatus == .active { return .activeSleep }
        if sleepStatus == .ended { return .morningSummary }
        if sleepStatus == .readyToStart { return .startSleep }
        return .brushing
    }

    private func stat(title: String, value: String) -> some View {
        VStack {
            Text(value)
                .font(.title2)
            Text(title)
                .font(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 3: Replace `BrushingView` with callbacks**

Edit `Sleepy/Screens/Brushing/BrushingView.swift`:

```swift
import SwiftUI

struct BrushingView: View {
    @Binding var route: AppRoute
    let onDone: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Brush your teeth")
                .font(.title)
            Button("Done brushing") {
                onDone()
                route = .startSleep
            }
            .buttonStyle(.borderedProminent)
            Button("Skip tonight") {
                onSkip()
                route = .startSleep
            }
        }
        .padding()
    }
}
```

- [ ] **Step 4: Replace `StartSleepView` with callback**

Edit `Sleepy/Screens/Sleep/StartSleepView.swift`:

```swift
import SwiftUI

struct StartSleepView: View {
    @Binding var route: AppRoute
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Start Sleep Sanctuary")
                .font(.title)
            Text("Selected distracting apps will be shielded until wake time.")
                .multilineTextAlignment(.center)
            Button("Start Sleep Sanctuary") {
                onStart()
                route = .activeSleep
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

- [ ] **Step 5: Replace `ActiveSleepView` with callback**

Edit `Sleepy/Screens/Sleep/ActiveSleepView.swift`:

```swift
import SwiftUI

struct ActiveSleepView: View {
    @Binding var route: AppRoute
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Sleep Sanctuary is active")
                .font(.title)
            Text("Shielding is active in real mode or simulated in mock mode.")
                .multilineTextAlignment(.center)
            Button("End early") {
                onEnd()
                route = .morningSummary
            }
        }
        .padding()
    }
}
```

- [ ] **Step 6: Replace `MorningSummaryView` with state display**

Edit `Sleepy/Screens/Summary/MorningSummaryView.swift`:

```swift
import SwiftUI

struct MorningSummaryView: View {
    @Binding var route: AppRoute
    let xp: Int
    let coins: Int
    let streak: Int
    let brushingStatus: BrushingStatus

    var body: some View {
        VStack(spacing: 24) {
            Text("Morning Summary")
                .font(.title)
            Text("XP: \(xp)")
            Text("Coins: \(coins)")
            Text("Streak: \(streak)")
            Text("Brushing: \(brushingStatus.rawValue)")
            Text("Sleep session recorded.")
            Button("Back home") {
                route = .home
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
```

- [ ] **Step 7: Build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 8: Manual Simulator check**

Run the app in Simulator from Xcode and verify:

```text
Onboarding -> Home -> Start brushing -> Done brushing -> Start Sleep Sanctuary -> End early -> Morning Summary -> Home
```

Record result in `docs/iterations/0001-skeleton/test-notes.md`.

- [ ] **Step 9: Commit**

```bash
git add Sleepy/Screens docs/iterations/0001-skeleton/test-notes.md
git commit -m "Wire skeleton bedtime flow"
```

---

### Task 11: Add FamilyActivityPicker Skeleton

**Files:**
- Modify: `Sleepy/Screens/Onboarding/ShieldSelectionView.swift`
- Modify: `Sleepy/Services/ShieldService.swift`

**Interfaces:**
- Consumes: `FamilyControls` when available
- Produces: device-only picker path
- Keeps: mock selection path for Simulator

- [ ] **Step 1: Update shield selection screen**

Edit `Sleepy/Screens/Onboarding/ShieldSelectionView.swift`:

```swift
import SwiftUI

#if canImport(FamilyControls)
import FamilyControls
#endif

struct ShieldSelectionView: View {
    #if canImport(FamilyControls)
    @State private var selection = FamilyActivitySelection()
    #endif

    var body: some View {
        Form {
            #if targetEnvironment(simulator)
            Text("Simulator uses mock shield selection.")
            Text("Mock selected apps: TikTok, Instagram")
            #else
            #if canImport(FamilyControls)
            FamilyActivityPicker(selection: $selection)
            #else
            Text("FamilyControls is unavailable in this build.")
            #endif
            #endif
        }
        .navigationTitle("Shielded apps")
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: Simulator build succeeds and shows mock selection text.

- [ ] **Step 3: Commit**

```bash
git add Sleepy/Screens/Onboarding/ShieldSelectionView.swift Sleepy/Services/ShieldService.swift
git commit -m "Add shield selection skeleton"
```

---

### Task 12: Final Verification And Push

**Files:**
- Modify: `docs/iterations/0001-skeleton/checklist.md`
- Modify: `docs/iterations/0001-skeleton/test-notes.md`

**Interfaces:**
- Consumes: all prior tasks
- Produces: verified 0001 skeleton branch state

- [ ] **Step 1: Run all tests**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: all tests pass.

- [ ] **Step 2: Run app build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 3: Update checklist**

Mark completed items in `docs/iterations/0001-skeleton/checklist.md`. Leave real-device checks unchecked until they are tested on an iPhone.

- [ ] **Step 4: Update test notes**

Add the exact build/test commands and results to `docs/iterations/0001-skeleton/test-notes.md`.

- [ ] **Step 5: Commit verification docs**

```bash
git add docs/iterations/0001-skeleton/checklist.md docs/iterations/0001-skeleton/test-notes.md
git commit -m "Record skeleton verification"
```

- [ ] **Step 6: Push**

```bash
git push origin main
```

Expected: push succeeds and GitHub shows the project skeleton and iteration docs.

---

## Self-Review

Spec coverage:

- Native Xcode skeleton: Task 1.
- Minimal data model: Task 3.
- Guided setup/settings controls: Tasks 8, 9, and 11.
- Notification scheduling: Task 7.
- Toothbrushing flow: Tasks 6, 9, and 10.
- Sleep session flow: Tasks 5, 6, 9, and 10.
- App shielding during session: Tasks 5 and 11.
- Morning summary: Tasks 4, 9, and 10.
- XP, coins, and streak foundations: Task 4.
- Focused tests: Tasks 2, 4, 5, 6, 7, and 12.
- Iteration docs: Tasks 1 and 12.

Type consistency:

- `BrushingStatus`, `SleepStatus`, and `NightFlowState` are defined before use.
- `ShieldSelection`, `ShieldServicing`, and `MockShieldService` are defined before `SleepSessionService`.
- `ProgressAward` and `MorningSummary` are defined in `ProgressService`.
- `NotificationScheduling` and `ScheduledNotification` are defined before `NotificationService`.

Scope check:

- This plan builds a functional skeleton only.
- Real extension targets and production entitlements are deferred until the main app skeleton compiles.
- Detailed screen layout and visual polish are deferred to a later iteration.
