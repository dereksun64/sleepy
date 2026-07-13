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

## Simulator

Using iPhone 17 Pro (iOS 26.5) because the plan's iPhone 16 simulator is unavailable.

## Real Device

Not tested in 0001 unless explicitly noted.
