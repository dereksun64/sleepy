# Sleepy 0002 Functional MVP Acceptance Checklist

Iteration 0002 remains incomplete until every acceptance criterion and the required physical-iPhone matrix are directly evidenced. Automated coverage does not substitute for real notification delivery, Family Controls entitlement approval, or physical shield behavior.

## Spec Section 13 Acceptance Criteria

- [x] The app builds and all automated tests pass. Evidence: the standard full suite executed 50 tests with 0 failures, and both required builds ended with `BUILD SUCCEEDED` on 2026-07-14.
- [ ] The complete bedtime loop works after terminating and relaunching the app.
- [x] Settings, selection, session, snooze count, and progress persist. Evidence: the full suite passed direct persistence/relaunch coverage including schedule updates, selection persistence, session recovery, snooze persistence, and nightly progress rollover.
- [ ] Real selected targets are shielded on a physical iPhone.
- [ ] End early reliably removes those shields.
- [ ] After wake time, shields are removed on the system's first outside-interval device-use callback without requiring the main app to run.
- [ ] Notification actions produce the documented state transitions.
- [ ] The routine-progress header follows the documented visibility, completion, one-second hold, and nightly-reset rules.
- [x] Rewards and streaks cannot be granted twice for one session. Evidence: `testBrushingRewardIsIdempotent`, `testSleepCompletionRewardAndStreakAreIdempotent`, and repeat-safe wake recovery passed in the full suite.
- [ ] Denied, revoked, empty-selection, and recovery states are represented honestly.
- [ ] Real-device results and any entitlement requirements are documented.

## Additional Verification Lines

- [x] Standard full automated suite passes on the named iOS Simulator destination. Evidence: iPhone 17 Pro, iOS 26.5, 50 tests, 0 failures, exit 0, `TEST SUCCEEDED`.
- [x] Standard simulator build succeeds on the named iOS Simulator destination. Evidence: iPhone 17 Pro, iOS 26.5, exit 0, `BUILD SUCCEEDED`.
- [x] Standard unsigned generic iOS device build succeeds. Evidence: iPhoneOS 26.5 SDK, `CODE_SIGNING_ALLOWED=NO`, exit 0, `BUILD SUCCEEDED`.
- [ ] Real Family Controls entitlement approval is confirmed for both the app and Device Activity monitor extension.
- [ ] Bedtime notification action "Starting now" routes to the documented state transition on a physical iPhone.
- [ ] Bedtime notification action "Already done" routes to the documented state transition on a physical iPhone.
- [ ] Bedtime notification action "Skip tonight" routes to the documented state transition on a physical iPhone.
- [ ] Bedtime notification snooze action routes to the documented state transition on a physical iPhone.
- [ ] A fourth snooze is not scheduled on a physical iPhone.
- [ ] End early clears real selected-target shields immediately on a physical iPhone.
- [ ] The Device Activity extension clears shields on first outside-interval device use while the main app is terminated.
- [ ] Reopening the same completed session twice leaves XP, coins, current streak, and best streak unchanged on the second recovery.
- [ ] Notification-denied, Screen Time-denied/revoked, and empty-selection states remain usable and are represented honestly.

## Pending Physical and Interactive Evidence

- Physical iPhone model and iOS version: pending; no physical-device matrix was performed in Task 8.
- App and extension Family Controls entitlement approval: pending.
- Real notification display, delivery, and all four action routes: pending.
- Native `FamilyActivityPicker` save/restore: pending.
- Real selected-target shield application and End early clearing: pending.
- Outside-interval extension clearing with the app terminated: pending. The callback is expected on first device use outside the interval, not at an exact wake-time minute.
- Terminated/relaunched complete bedtime loop, repeated recovery rewards, and new-night progress reset: pending interactive execution.
- Physical permission denial/revocation behavior: pending.
