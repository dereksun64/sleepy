# Sleepy

Sleepy is a native iOS bedtime accountability app. The goal is to help a user move from "I should go to sleep" to brushing their teeth, starting a sleep session, and putting their phone down.

The app is intentionally native Swift/SwiftUI because the product depends on iOS features like notifications, Screen Time permissions, app shielding, extensions, haptics, and later HealthKit or iCloud support.

## Current Status

This repo is at the planning/skeleton stage.

The first build pass is `0001-skeleton`: a bare-bones native iOS app that proves the core flow works without polished design.

Planned skeleton flow:

1. Set bedtime and wake time.
2. Choose distracting apps to shield.
3. Receive a bedtime brushing prompt.
4. Confirm brushing or skip.
5. Start Sleep Sanctuary.
6. Shield selected apps during sleep.
7. Show a simple morning summary.
8. Track basic XP, coins, and streak.

## Iteration Plan

### 0001 Skeleton

Build the smallest working native app:

- Xcode iOS project
- minimal SwiftData models
- plain SwiftUI screens
- brushing and sleep flow
- mock shielding in Simulator
- real shielding boundary for device testing
- basic XP, coins, and streak logic

### 0002 Functional MVP

Make the skeleton reliable on a real iPhone:

- Screen Time permission flow
- FamilyActivityPicker app selection
- real ManagedSettings shielding
- notification actions
- wake-time shield clearing
- manual End early behavior

### 0003 Product Polish

Improve the user experience without expanding scope too much:

- cleaner home screen
- better setup flow
- clearer permission states
- simple Sleep Sanctuary visual treatment
- better morning summary copy

### Later

Possible future directions:

- richer bedtime routines
- HealthKit sleep integration
- iCloud sync
- widgets or Live Activities
- accountability partners
- weekly reports
- shared challenges

These are intentionally out of scope until the native MVP works.

## Docs

Project docs live in `docs/`.

Iteration-specific work lives in:

```text
docs/iterations/0001-skeleton/
```

Key files:

- `spec.md`: what the skeleton should build
- `implementation-plan.md`: task-by-task build plan
- `checklist.md`: progress checklist
- `test-notes.md`: verification notes
