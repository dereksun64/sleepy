# Sleepy 0002 Functional MVP Test Notes

## Automated Commands

Environment:

- Date: 2026-07-14 (Asia/Singapore, UTC+08:00)
- Xcode: 26.6 (build 17F113)
- Simulator: iPhone 17 Pro (`9697FC75-2E0F-4C50-B661-D93A46707DFD`)
- Runtime: iOS 26.5

### Full automated suite

```bash
xcodebuild test -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- Result: exit 0, `** TEST SUCCEEDED **`.
- Count: 50 tests executed, 0 failures, 0 unexpected failures.
- Suites: 10 `NotificationClientTests`, 7 `ShieldClientTests`, 5 `SleepScheduleTests`, and 28 `SleepyStoreTests`.
- XCTest duration: 0.330 seconds (0.358 seconds total).
- Xcode test-operation elapsed time: 6.125 seconds.
- Result bundle: `/Users/dereksun/Library/Developer/Xcode/DerivedData/Sleepy-akrzxfzgltdyvvdtbwookzuxopxx/Logs/Test/Test-Sleepy-2026.07.14_16-43-43-+0800.xcresult`.
- Non-failing runtime diagnostic: one Core Animation app-launch measurement event could not be sent.

The first sandbox-restricted attempt of the same command could not connect to CoreSimulatorService and exited 70 because no simulator destination was visible. The command was rerun unchanged with standard Xcode/CoreSimulator access; the successful result above is the verification result.

### Simulator build

```bash
xcodebuild -scheme Sleepy -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

- Result: exit 0, `** BUILD SUCCEEDED **`.
- Destination/runtime: iPhone 17 Pro, iOS 26.5.
- SDK observed in output: `iPhoneSimulator26.5.sdk`.
- Non-failing diagnostic: App Intents metadata extraction was skipped because the targets have no AppIntents framework dependency.

### Unsigned generic iOS device build

```bash
xcodebuild -scheme Sleepy -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

- Result: exit 0, `** BUILD SUCCEEDED **`.
- SDK observed in output: `iPhoneOS26.5.sdk`.
- Architecture/deployment target observed in output: `arm64-apple-ios17.0`.
- Signing: disabled only through the plan-prescribed `CODE_SIGNING_ALLOWED=NO`; no source exclusions, extra build-setting overrides, or DerivedData changes were used.
- Non-failing diagnostic: App Intents metadata/training found no AppIntents or App Shortcuts content; Swift library copying noted that bitcode stripping was ignored because signing was disabled.

## Simulator

- The required automated suite and simulator build ran against the booted iPhone 17 Pro on iOS 26.5 and passed as recorded above.
- Automated evidence directly covers schedule/DST behavior, stable notification requests, notification action state transitions, three-snooze persistence and fourth-snooze routing, selection persistence/repair, repeated shield clearing, routine-progress state transitions/reset, recovery, reward/streak idempotency, End early state handling, and denied/revoked/empty-state copy or state derivation.
- No fresh interactive Task 8 simulator matrix was performed. In particular, the visible one-second progress hold, full Brush -> Start Sleep -> End early -> Summary flow, and injected persisted-data relaunch flow remain unverified interactively in this task.
- Simulator evidence does not prove real notification delivery/actions, native picker behavior, entitlement approval, or real shield behavior.

## Physical iPhone

- Device model: Not tested.
- iOS version: Not tested.
- App entitlement: Pending approval/verification.
- Extension entitlement: Pending approval/verification.
- Notification actions: Not tested; real delivery and all four routes remain pending.
- FamilyActivityPicker save/restore: Not tested.
- Shield apply: Not tested with real selected targets.
- End early clear: Not tested with real selected-target shields.
- Outside-interval extension clear with app terminated: Not tested.
- Wake-time relaunch and reward idempotency: Not tested interactively on a physical device.
- Permission denial/revocation: Not tested on a physical device.

## Known Platform Limits

The Device Activity interval-end callback is expected on the first device use outside the interval, not at an exact wake-time minute.

Passing Simulator tests alone is not sufficient to complete iteration 0002.
