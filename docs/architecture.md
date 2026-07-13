# Sleepy Architecture

Sleepy is a native iOS bedtime accountability app. The current architecture is intentionally small: SwiftUI screens, SwiftData models for durable local state, one small store object for skeleton flow state, and thin clients only where the app touches Apple frameworks.

The first implementation phase is `0001-skeleton`. Its job is to prove the native app shape and the core bedtime flow before investing in polished UI, extensions, sync, analytics, or larger architecture.

## 1. High-Level Architecture

The app is local-first and native-first.

```text
SwiftUI screens
  -> SleepyStore
    -> SwiftData models
    -> NotificationClient
    -> ShieldClient
```

Responsibilities are kept plain:

- SwiftUI screens render current state and call user actions.
- `SleepyStore` owns the in-app skeleton flow, basic rewards, and simple state transitions.
- SwiftData stores durable user settings, sleep sessions, and progress.
- `NotificationClient` owns `UserNotifications` calls.
- `ShieldClient` owns the boundary to `FamilyControls` / `ManagedSettings`, with mock behavior in Simulator.

There is no TCA, Clean Architecture, repository layer, coordinator system, or large view model tree in this phase. Those would add more structure than the skeleton needs.

## 2. Current `0001-skeleton` Architecture

`0001-skeleton` should fit in a small number of files:

```text
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
```

This phase favors one-file skeletons over folders and abstractions. Screens may live in `RootView.swift` until they become large enough to split naturally.

The app starts with:

- a SwiftData `modelContainer`
- one `SleepyStore` injected into the SwiftUI environment
- one `ShieldClient` injected into the SwiftUI environment
- one `NotificationClient` passed where notification permission or scheduling is needed

Services are added only when they touch Apple frameworks or create a useful test seam. Business logic should stay in `SleepyStore` until it becomes clearly too large.

## 3. Main App Flow

The skeleton flow is:

1. First launch shows onboarding.
2. User sets target bedtime and wake time.
3. User requests notification permission.
4. User requests or sees Screen Time / shielding availability.
5. User reaches Home.
6. At bedtime, the app can prompt brushing through a local notification.
7. User starts brushing, marks brushing done, or skips.
8. App prompts the user to start Sleep Sanctuary.
9. Starting Sleep Sanctuary creates or updates tonight's sleep session and applies shields.
10. Active sleep shows the session state and allows ending early.
11. At wake time, or after manual end, shields are cleared.
12. Morning summary shows XP, coins, streak, and completion state.

The UI is intentionally plain. This document should not lock in final screen layout because the design is still expected to change.

## 4. Data Model Overview

SwiftData is the durable local store for first-party app data.

### `UserSettings`

Stores setup and preference state:

- target bedtime
- wake time
- onboarding completion
- notification permission state
- Screen Time permission state
- selected shield apps, categories, and web domains where storage is practical

Shield selection tokens may need special handling depending on Apple's API constraints. If they cannot be stored directly in SwiftData, use the smallest reliable local persistence option. Do not add App Groups unless an extension needs shared state.

### `SleepSession`

Stores one night's routine and sleep result:

- id
- date
- scheduled bedtime
- scheduled wake time
- actual start time
- actual end time
- brushing status
- sleep status
- snooze count
- ended early flag

The skeleton only needs one active-or-recent session at a time. More advanced history views can come later.

### `ProgressProfile`

Stores simple progress:

- XP
- coins
- current streak
- best streak
- last completed sleep date

Scoring for `0001-skeleton` is deterministic:

- done brushing: `+10 XP`, `+2 coins`
- sleep completed at wake time: `+50 XP`, `+10 coins`, `+1 streak`
- skipped brushing: no brushing reward
- ended early: session is recorded, but no sleep completion reward

## 5. State Management Approach

Use SwiftUI's native observation tools and a small `SleepyStore`.

`SleepyStore` should hold the current skeleton state:

- current app stage
- selected bedtime and wake time while editing
- brushing status
- sleep status
- snooze count
- displayed XP, coins, and streak

The store should expose direct methods for user actions, such as:

- finish onboarding
- start brushing
- mark brushing done
- skip brushing
- snooze
- start sleep
- end sleep
- reset to home

Keep state transitions explicit enough to prevent impossible flows, but do not introduce reducer architecture yet. If one screen later needs local-only UI state, keep that state inside the view.

## 6. Notification Approach

Use `UserNotifications` through `NotificationClient`.

`NotificationClient` is responsible for:

- requesting notification permission
- scheduling the bedtime brushing prompt
- scheduling 5-minute snooze reminders
- enforcing or supporting the 3-snooze nightly cap with `SleepyStore`
- scheduling the one no-response follow-up notification
- giving notification requests stable identifiers

The core notification copy for this phase is:

- bedtime prompt: `Are you brushing your teeth now?`
- no-response follow-up: `Alright man, it's getting late, stop trolling.`

If notification permission is denied, the app remains usable manually. The UI should show that reminders are inactive rather than blocking the rest of the skeleton.

## 7. Shielding Approach

Use `FamilyControls` for authorization and selection, and `ManagedSettings` for applying shields when available.

`ShieldClient` is the boundary for shielding:

- in Simulator, it uses mock shield state
- on a real device with permission, it applies selected shields
- ending sleep clears active shields
- app launch should be able to clear stale shields if a session has passed wake time

In `0001-skeleton`, compile the real ManagedSettings boundary but keep behavior minimal. Do not add DeviceActivity extensions, custom shield extensions, or App Groups until real-device testing proves they are needed.

No selected apps is a valid state. Sleep can still start, but the UI should make clear that no distracting apps are currently shielded.

## 8. Simulator vs Real-Device Behavior

Simulator behavior is allowed to be mocked:

- notification scheduling can compile and be manually inspected
- Screen Time authorization may be unavailable
- app/category shield selection may be unavailable
- starting Sleep Sanctuary marks mock shielding active
- ending sleep clears mock shielding

Real-device behavior is where Screen Time features must be validated:

- notification permission prompt appears
- Screen Time authorization prompt appears
- FamilyActivityPicker can select apps/categories
- selected apps are shielded after sleep starts
- shields clear at wake time or when ending early

The app should always be honest about mode. If shielding is mocked, denied, unavailable, or empty, the user-facing state should say so.

## 9. Testing Approach

Automated tests should focus on non-UI logic:

- snooze cap stops at 3
- brushing done awards brushing XP and coins
- skipping brushing awards no brushing bonus
- sleep completion awards XP, coins, and streak
- ending early does not award sleep completion progress
- basic stage transitions are valid
- mock shield apply and clear works
- notification identifiers and scheduled dates are stable where practical

Manual testing covers the native surfaces:

- onboarding reaches Home
- bedtime and wake time can be changed
- notification permission can be requested
- brushing flow works
- Start Sleep enters active state
- Simulator shielding uses mock state
- End early clears shield state
- morning summary appears
- real-device shield selection and blocking work when entitlements allow it

Do not overbuild test infrastructure in this phase. Add small test seams where Apple framework calls would otherwise make behavior hard to verify.

## 10. Known Deferred Architecture Decisions

These are intentionally deferred:

- DeviceActivity extension target
- custom ShieldConfiguration extension
- App Groups
- HealthKit
- iCloud sync
- widgets
- Live Activities
- accountability partners
- weekly reports
- advanced analytics
- durable notification action routing strategy
- richer bedtime routine engine
- polished navigation architecture
- large per-screen view model hierarchy
- repository layer
- TCA or another reducer framework

Add these only when the product need is concrete and the native skeleton has proven the simpler path is insufficient.
