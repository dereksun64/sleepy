# Sleepy 0001 Skeleton Test Notes

## Commands

- `xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
  - Result: Passed (`BUILD SUCCEEDED`).
  - Device: iPhone 17 Pro simulator (iOS 26.5).
  - Note: The first sandboxed attempt could not access CoreSimulator or Xcode DerivedData and was stopped; rerunning with macOS service access passed.
- `xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SleepyTests/SleepyStoreTests`
  - Red result: Failed as expected because `SleepyStore` was not in scope.
  - Green result: Passed; 3 tests, 0 failures.
  - Device: iPhone 17 Pro simulator (iOS 26.5).
- `xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SleepyTests/ShieldClientTests`
  - Red result: Failed as expected because `ShieldClient` was not in scope.
  - Green result: Passed; 1 test, 0 failures.
  - Device: iPhone 17 Pro simulator (iOS 26.5).
  - Note: Simulator clear initially reached `ManagedSettingsStore` and logged an unavailable-agent warning. The boundary was narrowed so Simulator uses mock state only; the rerun passed without that warning.
- `xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` after adding `NotificationClient`
  - Result: Passed (`BUILD SUCCEEDED`).
  - Device: iPhone 17 Pro simulator (iOS 26.5).
- `xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` after adding the SwiftUI flow
  - Result: Passed (`BUILD SUCCEEDED`).
  - Device: iPhone 17 Pro simulator (iOS 26.5).
- Final: `xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
  - Result: Passed (`TEST SUCCEEDED`); 4 tests, 0 failures.
  - Device: iPhone 17 Pro simulator (iOS 26.5).
- Final: `xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
  - Result: Passed (`BUILD SUCCEEDED`).
  - Device: iPhone 17 Pro simulator (iOS 26.5).

## Simulator

Using iPhone 17 Pro (iOS 26.5) because the plan's iPhone 16 simulator is unavailable.

Manual check passed on iPhone 17 Pro Simulator:

- Onboarding reached Home.
- Brush -> Done brushing -> Start Sleep Sanctuary -> End early reached Morning Summary.
- Morning Summary showed 10 XP, 2 coins, and a 0 streak after ending early.
- Back home returned to Home.
- Settings updated bedtime and wake time.

## Real Device

No real-device checks were run. The following remain unverified on hardware:

- Notification permission prompts and delivery.
- Screen Time authorization and app selection.
- Applying and clearing a real Managed Settings shield.
- Wake-time shield clearing.

These require device entitlements and real-token wiring outside the 0001 skeleton. The native shield boundary compiles, while Simulator tests use mock state.
