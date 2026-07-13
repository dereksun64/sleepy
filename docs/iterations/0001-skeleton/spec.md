# Sleepy 0001 Skeleton Spec

Date: 2026-07-13
Status: Approved for planning

## Purpose

Sleepy is a native iOS bedtime accountability app. The product goal is to help the user move from "I should go to sleep" to brushing their teeth, starting a sleep session, and putting their phone down.

This first iteration builds the working skeleton. It should prove the native app shape, data model, navigation, bedtime reminder flow, brushing confirmation, sleep session state, progress tracking, and real-versus-mock app shielding boundary. It should not attempt polished screen design.

## Scope

Build a real Xcode iOS project skeleton using:

- Swift
- SwiftUI
- SwiftData
- UserNotifications
- FamilyControls
- ManagedSettings
- DeviceActivity where needed for the sleep/shield lifecycle
- App Groups only if an extension needs shared state

The app should be native iOS. React Native is out of scope because app shielding, Screen Time permissions, notifications, extensions, haptics, and later HealthKit/iCloud features are core product constraints.

## Non-Goals

Do not build these in iteration 0001:

- polished visual design
- custom bedtime routines beyond brush and sleep
- low-energy routine modes
- accountability partners
- weekly reports
- widgets
- Live Activities
- HealthKit
- iCloud sync
- shared challenges
- collectible sanctuary systems
- advanced analytics
- production App Store polish

## User Flow

### Guided Setup

First launch uses a short guided setup:

1. Welcome and product purpose.
2. Set target bedtime.
3. Set wake-up time.
4. Request notification permission.
5. Request Screen Time permission.
6. Choose distracting apps/categories to shield.
7. Land on the home screen.

If notification permission is denied, the app remains usable manually and shows a clear status. If Screen Time permission is denied or unavailable, the app continues in limited/mock shielding mode.

### Bedtime Notification

At bedtime, schedule a notification asking:

> Are you brushing your teeth now?

Notification actions:

- Starting now
- Remind me in 5 minutes
- Already done
- Skip tonight

Behavior:

- Starting now opens the brushing confirmation flow.
- Remind me in 5 minutes schedules another reminder, capped at 3 snoozes per night.
- Already done marks brushing complete and moves the user toward starting sleep.
- Skip tonight marks brushing skipped and still moves the user toward starting sleep.
- If the user does not respond, send one follow-up notification after 10 minutes with: "Alright man, it's getting late, stop trolling."

### Brushing Flow

The brushing flow is intentionally simple:

- Starting now opens a brushing screen.
- The primary action is Done brushing.
- There is no timer in iteration 0001.
- Tapping Done brushing is the completion moment before the app asks the user to start sleep.
- Skip tonight remains available as an escape path.

### Sleep Flow

After brushing is complete or skipped:

1. The app prompts the user to start Sleep Sanctuary.
2. Starting Sleep Sanctuary creates or updates tonight's sleep session.
3. On a real device with permission, selected apps/categories are shielded.
4. In Simulator or unavailable-permission mode, shield state is mocked.
5. The active session screen shows the session is running and when it will end.
6. The session ends automatically at wake time.
7. The user can end early from the app.
8. Ending the session clears active shields.

The app should encourage phone-down behavior through the flow, but it must not claim to detect that the phone was actually put down.

### Morning Summary

In the morning, show a simple progress summary:

- XP earned
- coins earned
- current streak
- brushing done or skipped
- simple Sleep Sanctuary completion message

The summary should be functional and clear. Detailed game visuals are deferred.

## Screens

Iteration 0001 screens are functional skeleton screens, not final layouts:

- Onboarding
- Settings
- Home
- Brushing
- Start Sleep
- Active Sleep
- Morning Summary

The home screen should keep this rough hierarchy:

1. Streak, XP, and coins at the top.
2. Today's routine progress.
3. Target bedtime.
4. One primary action based on the current state.

The MVP routine progress contains only two steps:

- Brush
- Sleep

This shape should leave room for later routine steps without building a custom routine engine now.

## App State

Nightly flow states:

- waitingForBedtime
- bedtimePromptSent
- brushingStarted
- brushingDone
- brushingSkipped
- readyToStartSleep
- sleepActive
- sleepEnded
- morningSummaryReady
- morningSummaryShown

The implementation should keep these states explicit enough to prevent impossible flows, while avoiding a heavy framework or complex reducer architecture.

## Data Model

Minimal SwiftData models:

### UserSettings

- targetBedtime
- wakeTime
- hasCompletedOnboarding
- notificationPermissionState
- screenTimePermissionState
- selectedShieldApplications
- selectedShieldCategories
- selectedShieldWebDomains

### SleepSession

- id
- date
- scheduledBedtime
- scheduledWakeTime
- actualStartTime
- actualEndTime
- brushingStatus
- sleepStatus
- snoozeCount
- endedEarly

### ProgressProfile

- xp
- coins
- currentStreak
- bestStreak
- lastCompletedSleepDate

Selected shield tokens may require storage types that match Apple's Screen Time APIs. If a token type cannot be stored directly in SwiftData, store it through the smallest reliable local persistence mechanism available, using App Groups only when extension sharing requires it.

## Architecture

Use SwiftUI MVVM-lite with services:

```text
SwiftUI Screens
  -> small ViewModels / AppState where useful
    -> SwiftData models
    -> NotificationService
    -> ShieldService
    -> SleepSessionService
    -> ProgressService
```

Guidelines:

- Views render state and send user actions.
- Models store durable facts.
- Services own platform work and business logic.
- ViewModels are optional and should stay small.
- Do not introduce TCA, Clean Architecture, or broad repository layers in iteration 0001.

## Services

### NotificationService

Responsibilities:

- request notification permission
- schedule the bedtime prompt
- schedule 5-minute snooze reminders
- enforce the 3-snooze nightly cap
- schedule the one 10-minute no-response follow-up
- route notification actions into the app state

### ShieldService

Responsibilities:

- expose a common interface for applying and clearing shields
- use ManagedSettings on real devices when authorized
- use MockShieldService in Simulator or unavailable-permission mode
- apply selected app/category/domain shields when Sleep Sanctuary starts
- clear shields at wake time or manual early end

### AuthorizationService

Responsibilities:

- request Screen Time authorization through FamilyControls
- track approved, denied, or unknown state
- allow the skeleton app to continue in mock mode when authorization is unavailable

### SleepSessionService

Responsibilities:

- create or update tonight's sleep session
- move through brushing, ready-to-sleep, active-sleep, and ended states
- recover state on app launch if wake time has already passed
- call ShieldService when sessions start or end

### ProgressService

Responsibilities:

- award basic XP and coins
- update current and best streak
- produce the morning summary

Iteration 0001 scoring should be simple and deterministic:

- Done brushing earns 10 XP and 2 coins.
- Skip tonight earns no brushing bonus.
- A sleep session that reaches the scheduled wake time earns 50 XP and 10 coins.
- A sleep session that reaches the scheduled wake time increments the current streak.
- Ending early records the session but does not grant the sleep completion reward or increment the streak.

## Shielding

Real device behavior:

- The user grants Screen Time permission.
- The user selects distracting apps/categories using FamilyActivityPicker.
- Starting Sleep Sanctuary applies shields through ManagedSettingsStore.
- Opening a shielded app shows Apple's system shield UI.
- Ending sleep clears shields.

Simulator/mock behavior:

- The app stores the intended selection or a small mock selection state.
- Starting Sleep Sanctuary marks mock shield state as active.
- Ending sleep clears mock shield state.
- The UI should clearly indicate when shielding is mocked or unavailable.

## Error Handling

- Notification permission denied: allow manual use and show a settings prompt.
- Screen Time permission denied: continue with mock shielding and show that real blocking is inactive.
- No apps selected: allow sleep to start, but show that no distracting apps are currently shielded.
- App opened after wake time while a session is active: end the session, clear shields, and show morning summary.
- Shield clearing failure: retry on next launch and expose End early / Clear shield behavior from the active session path.

## Testing

Focused automated tests:

- bedtime and wake-time overnight calculations
- snooze count max of 3
- brushing and sleep session state transitions
- XP, coins, and streak calculations
- morning summary generation
- mock shield apply and clear behavior
- notification scheduling identifiers and dates through test doubles where practical

Manual Simulator checklist:

- guided setup completes
- bedtime and wake time can be changed
- brushing flow works
- Start Sleep Sanctuary enters mock active state
- End early clears mock active state
- morning summary appears

Manual real-device checklist:

- notification permission prompt appears
- Screen Time permission prompt appears
- FamilyActivityPicker allows app/category selection
- selected app is shielded after Start Sleep
- shield clears at wake time
- End early clears shield

## Documentation Structure

Use stable top-level docs plus iteration-specific docs:

```text
docs/
  agents.md
  product.md
  architecture.md
  changelog.md

  iterations/
    0001-skeleton/
      spec.md
      implementation-plan.md
      checklist.md
      test-notes.md

  decisions/
    0001-native-ios.md
    0002-swiftdata-local-first.md

  checklists/
    release-checklist.md
    app-store-checklist.md

  testing/
    manual-testing.md
    test-plan.md
```

Iteration 0001 should create only the docs needed to support the skeleton plan. The full structure may be filled in as implementation begins.

## Done Criteria

Iteration 0001 is done when:

- The native iOS project skeleton exists.
- Minimal SwiftData models are defined.
- Guided setup can save bedtime and wake time.
- Notification scheduling logic exists behind a service boundary.
- Brushing confirmation flow is wired.
- Sleep session start/end flow is wired.
- Shielding has real and mock service paths.
- Morning summary uses stored progress state.
- Focused tests cover the core non-UI logic where practical.
- Project docs include the skeleton spec, implementation plan, checklist, and test notes.
