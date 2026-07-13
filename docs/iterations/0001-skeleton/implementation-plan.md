# Sleepy 0001 Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the smallest native iOS skeleton that proves Sleepy can guide setup, run the brush -> sleep flow, track basic rewards, and mock/clear app shielding.

**Architecture:** SwiftUI screens plus SwiftData models and one small app store object. Add a service only when it touches an Apple framework or needs a test seam.

**Tech Stack:** Swift, SwiftUI, SwiftData, UserNotifications, FamilyControls, ManagedSettings, XCTest, Xcode 26.6.

## Global Constraints

- Native iOS only. Do not use React Native.
- Build a real Xcode app project.
- Keep screens plain and functional; defer visual polish.
- MVP routine steps are only Brush and Sleep.
- Snoozes are capped at 3 per night.
- Notification copy: "Are you brushing your teeth now?"
- No-response follow-up copy: "Alright man, it's getting late, stop trolling."
- Done brushing earns 10 XP and 2 coins.
- Sleep completed at wake time earns 50 XP, 10 coins, and +1 streak.
- Ending early records the session but does not grant sleep completion reward or streak.
- Use mock shielding in Simulator.
- Compile the real ManagedSettings boundary, but do not build extension targets in this iteration.

---

## Files

```text
Sleepy.xcodeproj/
Sleepy/
  SleepyApp.swift
  Models.swift
  SleepyStore.swift
  NotificationClient.swift
  ShieldClient.swift
  RootView.swift
SleepyTests/
  SleepyStoreTests.swift
  ShieldClientTests.swift
docs/iterations/0001-skeleton/
  spec.md
  implementation-plan.md
  checklist.md
  test-notes.md
```

Skipped for 0001: separate per-screen folders, view models, repository layer, DeviceActivity extension, App Groups, production shield customization.

---

### Task 1: Create The Xcode Skeleton

**Files:**
- Create: `Sleepy.xcodeproj`
- Create: `Sleepy/SleepyApp.swift`
- Create: `Sleepy/RootView.swift`
- Create: `SleepyTests/SleepyStoreTests.swift`
- Create: `.gitignore`
- Create: `docs/iterations/0001-skeleton/checklist.md`
- Create: `docs/iterations/0001-skeleton/test-notes.md`

**Interfaces:**
- Produces app target `Sleepy`
- Produces test target `SleepyTests`

- [ ] **Step 1: Create the Xcode project**

Use Xcode:

1. File > New > Project.
2. iOS > App.
3. Product Name: `Sleepy`.
4. Interface: `SwiftUI`.
5. Language: `Swift`.
6. Storage: `SwiftData`.
7. Include Tests: enabled.
8. Save into `/Users/dereksun/VSCode/sleepy`.

- [ ] **Step 2: Add `.gitignore`**

```gitignore
.DS_Store
DerivedData/
build/
*.xcuserdata/
*.xcuserstate
```

- [ ] **Step 3: Add docs checklists**

Create `docs/iterations/0001-skeleton/checklist.md`:

```markdown
# Sleepy 0001 Skeleton Checklist

- [ ] App builds in Simulator.
- [ ] Core store tests pass.
- [ ] Mock shield tests pass.
- [ ] Setup can reach Home.
- [ ] Brush -> Sleep -> Summary flow works.
- [ ] Notification scheduling code compiles.
- [ ] Real shield boundary compiles.
```

Create `docs/iterations/0001-skeleton/test-notes.md`:

```markdown
# Sleepy 0001 Skeleton Test Notes

## Commands

## Simulator

## Real Device

Not tested in 0001 unless explicitly noted.
```

- [ ] **Step 4: Replace the app entry**

`Sleepy/SleepyApp.swift`:

```swift
import SwiftData
import SwiftUI

@main
struct SleepyApp: App {
    @State private var store = SleepyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(for: [
            UserSettings.self,
            SleepSession.self,
            ProgressProfile.self
        ])
    }
}
```

`Sleepy/RootView.swift` for now:

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
        .environment(SleepyStore())
}
```

- [ ] **Step 5: Build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds. If that simulator name is unavailable, run:

```bash
xcrun simctl list devices available
```

Use any available iPhone simulator.

- [ ] **Step 6: Commit**

```bash
git add .
git commit -m "Add iOS app skeleton"
```

---

### Task 2: Add Models And Store Logic

**Files:**
- Create: `Sleepy/Models.swift`
- Create: `Sleepy/SleepyStore.swift`
- Create: `SleepyTests/SleepyStoreTests.swift`

**Interfaces:**
- Produces `@Model UserSettings`
- Produces `@Model SleepSession`
- Produces `@Model ProgressProfile`
- Produces `@Observable final class SleepyStore`

- [ ] **Step 1: Write failing store tests**

`SleepyTests/SleepyStoreTests.swift`:

```swift
import XCTest
@testable import Sleepy

final class SleepyStoreTests: XCTestCase {
    func testSnoozeStopsAtThree() {
        let store = SleepyStore()

        XCTAssertTrue(store.snooze())
        XCTAssertTrue(store.snooze())
        XCTAssertTrue(store.snooze())
        XCTAssertFalse(store.snooze())
        XCTAssertEqual(store.snoozeCount, 3)
    }

    func testBrushThenEndEarlyAwardsOnlyBrushing() {
        let store = SleepyStore()

        store.doneBrushing()
        store.startSleep()
        store.endSleep(endedEarly: true)

        XCTAssertEqual(store.xp, 10)
        XCTAssertEqual(store.coins, 2)
        XCTAssertEqual(store.streak, 0)
        XCTAssertEqual(store.stage, .summary)
    }

    func testCompletedSleepAwardsFullProgress() {
        let store = SleepyStore()

        store.doneBrushing()
        store.startSleep()
        store.endSleep(endedEarly: false)

        XCTAssertEqual(store.xp, 60)
        XCTAssertEqual(store.coins, 12)
        XCTAssertEqual(store.streak, 1)
        XCTAssertEqual(store.stage, .summary)
    }
}
```

- [ ] **Step 2: Run and verify failure**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/SleepyStoreTests
```

Expected: fails because `SleepyStore` does not exist.

- [ ] **Step 3: Add models**

`Sleepy/Models.swift`:

```swift
import Foundation
import SwiftData

enum AppStage: String, Codable {
    case onboarding
    case home
    case brushing
    case startSleep
    case sleepActive
    case summary
    case settings
}

enum BrushingStatus: String, Codable {
    case notStarted
    case done
    case skipped
}

enum SleepStatus: String, Codable {
    case notStarted
    case active
    case ended
}

@Model
final class UserSettings {
    var targetBedtime: Date
    var wakeTime: Date
    var hasCompletedOnboarding: Bool

    init(targetBedtime: Date = .now, wakeTime: Date = .now, hasCompletedOnboarding: Bool = false) {
        self.targetBedtime = targetBedtime
        self.wakeTime = wakeTime
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

@Model
final class SleepSession {
    var date: Date
    var brushingStatusRawValue: String
    var sleepStatusRawValue: String
    var snoozeCount: Int
    var endedEarly: Bool

    init(
        date: Date = .now,
        brushingStatus: BrushingStatus = .notStarted,
        sleepStatus: SleepStatus = .notStarted,
        snoozeCount: Int = 0,
        endedEarly: Bool = false
    ) {
        self.date = date
        self.brushingStatusRawValue = brushingStatus.rawValue
        self.sleepStatusRawValue = sleepStatus.rawValue
        self.snoozeCount = snoozeCount
        self.endedEarly = endedEarly
    }
}

@Model
final class ProgressProfile {
    var xp: Int
    var coins: Int
    var streak: Int

    init(xp: Int = 0, coins: Int = 0, streak: Int = 0) {
        self.xp = xp
        self.coins = coins
        self.streak = streak
    }
}
```

- [ ] **Step 4: Add store**

`Sleepy/SleepyStore.swift`:

```swift
import Foundation
import Observation

@Observable
final class SleepyStore {
    var stage: AppStage = .onboarding
    var bedtime = Date()
    var wakeTime = Date()
    var brushingStatus: BrushingStatus = .notStarted
    var sleepStatus: SleepStatus = .notStarted
    var snoozeCount = 0
    var xp = 0
    var coins = 0
    var streak = 0

    func finishOnboarding() {
        stage = .home
    }

    func snooze() -> Bool {
        guard snoozeCount < 3 else { return false }
        snoozeCount += 1
        return true
    }

    func startBrushing() {
        stage = .brushing
    }

    func doneBrushing() {
        brushingStatus = .done
        xp += 10
        coins += 2
        stage = .startSleep
    }

    func skipBrushing() {
        brushingStatus = .skipped
        stage = .startSleep
    }

    func startSleep() {
        sleepStatus = .active
        stage = .sleepActive
    }

    func endSleep(endedEarly: Bool) {
        sleepStatus = .ended
        if !endedEarly {
            xp += 50
            coins += 10
            streak += 1
        }
        stage = .summary
    }

    func resetToHome() {
        stage = .home
    }
}
```

- [ ] **Step 5: Run tests**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/SleepyStoreTests
```

Expected: tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sleepy/Models.swift Sleepy/SleepyStore.swift SleepyTests/SleepyStoreTests.swift
git commit -m "Add sleepy store"
```

---

### Task 3: Add Mock And Real Shield Boundary

**Files:**
- Create: `Sleepy/ShieldClient.swift`
- Create: `SleepyTests/ShieldClientTests.swift`

**Interfaces:**
- Produces `@Observable final class ShieldClient`
- Produces `applyMockShield()`
- Produces `clearShield()`

- [ ] **Step 1: Write failing shield test**

`SleepyTests/ShieldClientTests.swift`:

```swift
import XCTest
@testable import Sleepy

final class ShieldClientTests: XCTestCase {
    func testMockShieldApplyAndClear() {
        let shield = ShieldClient()

        shield.applyMockShield()
        XCTAssertTrue(shield.isActive)

        shield.clearShield()
        XCTAssertFalse(shield.isActive)
    }
}
```

- [ ] **Step 2: Run and verify failure**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/ShieldClientTests
```

Expected: fails because `ShieldClient` does not exist.

- [ ] **Step 3: Add shield client**

`Sleepy/ShieldClient.swift`:

```swift
import Foundation
import Observation

#if canImport(ManagedSettings)
import ManagedSettings
#endif

@Observable
final class ShieldClient {
    private(set) var isActive = false

    #if canImport(ManagedSettings)
    private let store = ManagedSettingsStore()
    #endif

    func applyMockShield() {
        isActive = true
    }

    func applyRealShieldIfAvailable() {
        #if targetEnvironment(simulator)
        applyMockShield()
        #else
        isActive = true
        // ponytail: real FamilyActivitySelection token wiring waits until device entitlement testing.
        #endif
    }

    func clearShield() {
        #if canImport(ManagedSettings)
        store.clearAllSettings()
        #endif
        isActive = false
    }
}
```

- [ ] **Step 4: Run test**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:SleepyTests/ShieldClientTests
```

Expected: tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sleepy/ShieldClient.swift SleepyTests/ShieldClientTests.swift
git commit -m "Add shield client"
```

---

### Task 4: Add Notification Client

**Files:**
- Create: `Sleepy/NotificationClient.swift`

**Interfaces:**
- Produces `final class NotificationClient`
- Produces `requestPermission() async -> Bool`
- Produces `scheduleBedtimePrompt(at:) async throws`
- Produces `scheduleNoResponseFollowUp(at:) async throws`

- [ ] **Step 1: Add notification client**

`Sleepy/NotificationClient.swift`:

```swift
import Foundation
import UserNotifications

final class NotificationClient {
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleBedtimePrompt(at date: Date) async throws {
        try await schedule(
            id: "bedtime.prompt",
            body: "Are you brushing your teeth now?",
            at: date
        )
    }

    func scheduleNoResponseFollowUp(at date: Date) async throws {
        try await schedule(
            id: "bedtime.no-response",
            body: "Alright man, it's getting late, stop trolling.",
            at: date
        )
    }

    private func schedule(id: String, body: String, at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Sleepy"
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        try await UNUserNotificationCenter.current().add(request)
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sleepy/NotificationClient.swift
git commit -m "Add notification client"
```

---

### Task 5: Add Plain SwiftUI Flow

**Files:**
- Modify: `Sleepy/RootView.swift`
- Modify: `Sleepy/SleepyApp.swift`

**Interfaces:**
- Consumes `SleepyStore`
- Consumes `ShieldClient`
- Consumes `NotificationClient`

- [ ] **Step 1: Inject shield and notification clients**

`Sleepy/SleepyApp.swift`:

```swift
import SwiftData
import SwiftUI

@main
struct SleepyApp: App {
    @State private var store = SleepyStore()
    @State private var shield = ShieldClient()
    private let notifications = NotificationClient()

    var body: some Scene {
        WindowGroup {
            RootView(notifications: notifications)
                .environment(store)
                .environment(shield)
        }
        .modelContainer(for: [
            UserSettings.self,
            SleepSession.self,
            ProgressProfile.self
        ])
    }
}
```

- [ ] **Step 2: Replace root view with all skeleton screens in one file**

`Sleepy/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @Environment(SleepyStore.self) private var store
    @Environment(ShieldClient.self) private var shield
    let notifications: NotificationClient

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch store.stage {
                case .onboarding:
                    onboarding
                case .home:
                    home
                case .brushing:
                    brushing
                case .startSleep:
                    startSleep
                case .sleepActive:
                    activeSleep
                case .summary:
                    summary
                case .settings:
                    settings
                }
            }
            .padding()
        }
    }

    private var onboarding: some View {
        VStack(spacing: 16) {
            Text("Sleepy").font(.largeTitle)
            DatePicker("Bedtime", selection: Bindable(store).bedtime, displayedComponents: .hourAndMinute)
            DatePicker("Wake time", selection: Bindable(store).wakeTime, displayedComponents: .hourAndMinute)
            Button("Allow notifications") {
                Task { _ = await notifications.requestPermission() }
            }
            Text("Shield selection uses mock mode in Simulator.")
            Button("Finish setup") {
                store.finishOnboarding()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var home: some View {
        VStack(spacing: 24) {
            HStack {
                stat("Streak", "\(store.streak)")
                stat("XP", "\(store.xp)")
                stat("Coins", "\(store.coins)")
            }
            ProgressView(value: progress)
            Text("Brush -> Sleep").font(.caption)
            Text("Bedtime").font(.headline)
            Text(store.bedtime, style: .time).font(.title)
            Button(primaryActionTitle) {
                primaryAction()
            }
            .buttonStyle(.borderedProminent)
            Button("Settings") {
                store.stage = .settings
            }
        }
    }

    private var brushing: some View {
        VStack(spacing: 16) {
            Text("Brush your teeth").font(.title)
            Button("Done brushing") { store.doneBrushing() }
                .buttonStyle(.borderedProminent)
            Button("Skip tonight") { store.skipBrushing() }
        }
    }

    private var startSleep: some View {
        VStack(spacing: 16) {
            Text("Start Sleep Sanctuary").font(.title)
            Text("Selected distracting apps will be shielded until wake time.")
                .multilineTextAlignment(.center)
            Button("Start Sleep Sanctuary") {
                shield.applyRealShieldIfAvailable()
                store.startSleep()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var activeSleep: some View {
        VStack(spacing: 16) {
            Text("Sleep Sanctuary is active").font(.title)
            Text(shield.isActive ? "Shield active" : "Shield inactive")
            Button("End early") {
                shield.clearShield()
                store.endSleep(endedEarly: true)
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Text("Morning Summary").font(.title)
            Text("XP: \(store.xp)")
            Text("Coins: \(store.coins)")
            Text("Streak: \(store.streak)")
            Text("Sleep session recorded.")
            Button("Back home") { store.resetToHome() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var settings: some View {
        VStack(spacing: 16) {
            DatePicker("Bedtime", selection: Bindable(store).bedtime, displayedComponents: .hourAndMinute)
            DatePicker("Wake time", selection: Bindable(store).wakeTime, displayedComponents: .hourAndMinute)
            Button("Done") { store.stage = .home }
        }
    }

    private var progress: Double {
        var value = 0.0
        if store.brushingStatus == .done || store.brushingStatus == .skipped { value += 0.5 }
        if store.sleepStatus == .ended { value += 0.5 }
        return value
    }

    private var primaryActionTitle: String {
        switch store.stage {
        case .home:
            if store.sleepStatus == .active { return "View Sleep Sanctuary" }
            if store.sleepStatus == .ended { return "View morning summary" }
            if store.brushingStatus == .done || store.brushingStatus == .skipped { return "Start Sleep Sanctuary" }
            return "Start brushing"
        default:
            return "Continue"
        }
    }

    private func primaryAction() {
        if store.sleepStatus == .active {
            store.stage = .sleepActive
        } else if store.sleepStatus == .ended {
            store.stage = .summary
        } else if store.brushingStatus == .done || store.brushingStatus == .skipped {
            store.stage = .startSleep
        } else {
            store.startBrushing()
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title2)
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RootView(notifications: NotificationClient())
        .environment(SleepyStore())
        .environment(ShieldClient())
}
```

- [ ] **Step 3: Build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 4: Manual Simulator check**

Run the app and verify:

```text
Onboarding -> Home -> Start brushing -> Done brushing -> Start Sleep Sanctuary -> End early -> Summary -> Home
```

Record the result in `docs/iterations/0001-skeleton/test-notes.md`.

- [ ] **Step 5: Commit**

```bash
git add Sleepy/SleepyApp.swift Sleepy/RootView.swift docs/iterations/0001-skeleton/test-notes.md
git commit -m "Add plain SwiftUI skeleton flow"
```

---

### Task 6: Final Check And Push

**Files:**
- Modify: `docs/iterations/0001-skeleton/checklist.md`
- Modify: `docs/iterations/0001-skeleton/test-notes.md`

- [ ] **Step 1: Run tests**

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: tests pass.

- [ ] **Step 2: Run build**

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: build succeeds.

- [ ] **Step 3: Update docs**

Mark completed skeleton checks in `docs/iterations/0001-skeleton/checklist.md`.

Add command results to `docs/iterations/0001-skeleton/test-notes.md`:

```markdown
## Commands

- `xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16'`
  - Result:
- `xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 16' build`
  - Result:
```

- [ ] **Step 4: Commit and push**

```bash
git add docs/iterations/0001-skeleton/checklist.md docs/iterations/0001-skeleton/test-notes.md
git commit -m "Record skeleton verification"
git push origin develop
```

---

## Ponytail Cuts

- One `SleepyStore` instead of view models plus separate session/progress services.
- One `Models.swift` instead of three model files.
- One `RootView.swift` for skeleton screens; split later when layout stabilizes.
- No notification test double; system notification scheduling is thin Apple API glue.
- No DeviceActivity extension until real device shielding proves it is needed.
- No App Group until an extension needs shared state.
