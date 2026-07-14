# Sleepy 0002 Functional MVP Spec

Date: 2026-07-14
Status: Draft for review

## 1. Purpose

Iteration 0002 turns the Simulator-oriented skeleton into a reliable bedtime accountability loop on one real iPhone.

The iteration should prove that a user can grant the required permissions, choose distracting apps, receive and respond to the bedtime prompt, start Sleep Sanctuary, have the selected apps shielded, and have those shields removed after wake time or after choosing End early. Settings, session state, and rewards must survive app relaunches.

The UI should remain plain and native. Visual identity, illustrations, animation, and production polish belong in iteration 0003.

## 2. Outcomes

At the end of 0002:

- Setup works on a physical iPhone.
- Notification and Screen Time permission states are shown accurately.
- A persistent routine-progress header stays at the top of every app screen except active Sleep Sanctuary.
- The user can select apps, categories, or web domains with `FamilyActivityPicker`.
- The selection persists across app launches.
- Starting Sleep Sanctuary applies real Managed Settings shields when authorized and a selection exists.
- The bedtime notification supports Starting now, Remind me in 5 minutes, Already done, and Skip tonight.
- Snoozes are limited to three per night, including across app relaunches.
- The session becomes complete at the scheduled wake time, and shields clear without requiring the main app to be relaunched.
- End early clears shields immediately.
- Relaunching the app recovers the correct nightly state and clears stale shields.
- XP, coins, and streak rewards are durable and are granted at most once per session.
- The complete flow is verified on a physical iPhone.

## 3. Non-Goals

Do not add these in 0002:

- polished visual design or a custom design system
- production illustrations, animations, or sound design
- custom shield appearance
- custom bedtime routines beyond Brush and Sleep
- low-energy modes
- widgets or Live Activities
- HealthKit
- iCloud sync
- accountability partners or social features
- weekly reports or advanced analytics
- a reward store, collectibles, or a larger game economy
- multiple user profiles or cross-device support
- third-party architecture or persistence dependencies

## 4. Core User Journey

### Setup

1. The user chooses a target bedtime and wake time.
2. The app requests notification permission and shows the resulting status.
3. The app requests individual Screen Time authorization and shows the resulting status.
4. Once Screen Time access is available, the user opens `FamilyActivityPicker` and chooses apps, categories, or web domains.
5. The app persists the selection and schedules the bedtime notifications.
6. The user reaches Home even if either permission is denied.

### Bedtime prompt

At the target bedtime, Sleepy sends:

> Are you brushing your teeth now?

The notification provides four actions:

- **Starting now:** mark brushing started and open the brushing screen.
- **Remind me in 5 minutes:** schedule a reminder five minutes later if the nightly snooze count is below three.
- **Already done:** mark brushing done, grant the brushing reward once, and open the Start Sleep screen.
- **Skip tonight:** mark brushing skipped and open the Start Sleep screen without a brushing reward.

Sleepy also schedules one no-response follow-up for ten minutes after the original prompt:

> Alright man, it's getting late, stop trolling.

Any response to the original prompt cancels that follow-up. A snooze schedules a new actionable bedtime prompt but does not schedule additional no-response follow-ups.

If the user attempts a fourth snooze, Sleepy does not schedule another reminder. The next interaction should lead into the in-app bedtime flow.

### Brushing

- Starting now opens the brushing screen.
- Done brushing marks brushing complete and grants 10 XP and 2 coins once.
- Skip tonight marks brushing skipped and grants no brushing reward.
- Either completion path leads to Start Sleep Sanctuary.

### Sleep Sanctuary

1. Starting Sleep Sanctuary creates or updates tonight's pending session.
2. If Screen Time is authorized and the saved selection is non-empty, Sleepy applies shields to the selected applications, categories, and web domains.
3. When real shields are applied, Sleepy attempts to schedule a Device Activity interval ending at the selected wake time. If scheduling fails, Sleepy clears the shields and continues only in visibly unshielded mode.
4. Sleepy persists the session as active.
5. Once the session enters the active state, the Sleep routine step completes and fills the progress bar to 100%.
6. Sleepy holds that completed progress state on screen for one second before transitioning to active Sleep Sanctuary. This is a functional pause for later completion feedback; 0002 does not add animation, sound, or other dopamine effects.
7. The progress header disappears on the active Sleep Sanctuary page.
8. The active screen shows the planned wake time and the actual shield state.
9. When iOS delivers the interval-end callback, a Device Activity monitor extension clears the named Managed Settings store even if the main app is not running.
10. On the next app launch, Sleepy recognizes that the session reached wake time, marks it complete, grants the sleep reward once, and shows the morning summary.

If Screen Time access is denied, unavailable, or has been revoked, the session may still start but the UI must state that distracting apps are not being blocked.

If the selection is empty, the session may still start but the UI must state that no apps are selected.

### End early

- End early requires a confirmation step.
- Confirming clears the named Managed Settings store immediately.
- The session is recorded as ended early.
- The Sleep routine step remains complete and the restored progress header remains at 100%.
- No sleep-completion XP, coins, or streak increment is granted.
- The morning summary explains that Sleep Sanctuary ended early.

### Morning recovery

When the app launches or becomes active, it reconciles the current time with the active session:

- If wake time has passed, clear shields defensively and complete the session.
- If the session was already completed, do not grant rewards again.
- If wake time has not passed, restore the active Sleep Sanctuary screen.
- If persisted state is inconsistent, prefer clearing shields and preserving recorded progress over leaving a stale block active.

## 5. Overnight Time Rules

- Bedtime and wake time are user-selected local wall-clock times.
- If wake time is later than bedtime, both times belong to the same calendar day.
- If wake time is equal to or earlier than bedtime, wake time belongs to the following calendar day.
- A nightly session is identified by its scheduled bedtime date, not by the date after midnight.
- Notification, Device Activity, recovery, and streak calculations must use the same resolved session interval.
- Time-zone or daylight-saving changes should resolve through `Calendar` rather than fixed second offsets.

## 6. State and Persistence

SwiftData remains the durable store for first-party app state.

### `UserSettings`

Persist:

- target bedtime
- wake time
- onboarding completion
- last known notification permission state
- last known Screen Time authorization state
- encoded `FamilyActivitySelection`

Permission values are cached only for display and recovery. The app must refresh the authoritative system status when it launches or becomes active.

The Screen Time selection should be encoded into `Data` using Apple's codable token types and stored with the user settings. A decode failure should produce an empty selection and a visible prompt to choose apps again.

### `SleepSession`

Persist:

- stable identifier
- scheduled bedtime and wake time
- actual start and end times
- brushing status and its reward-granted state
- sleep status
- snooze count
- ended-early flag
- sleep-completion reward-granted state

Only one session may be active at a time. Starting a new session must first reconcile or close any stale active session.

### `ProgressProfile`

Persist:

- XP
- coins
- current streak
- best streak
- last completed sleep date

Reward rules remain:

- Done brushing: +10 XP and +2 coins.
- Skip brushing: no brushing reward.
- Reach scheduled wake time: +50 XP, +10 coins, and +1 streak.
- End early: no sleep-completion reward and the current streak resets to zero.

For a completed session, set the streak to one when there is no previous completion or the previous completed-night date is not the immediately preceding local calendar day. Otherwise, increment it by one. Update best streak only when current streak exceeds it. Reprocessing the same session does not change either value.

Reward-granted flags on the session make every award idempotent.

## 7. App State and Coordination

Keep the existing SwiftUI and `SleepyStore` shape. Do not add a reducer framework or repository layer.

`SleepyStore` coordinates the current flow and writes durable facts through a SwiftData `ModelContext`. It should derive the displayed stage from the current persisted session rather than treating its in-memory stage as the source of truth.

Platform boundaries remain small:

- `NotificationClient`: permission, categories, scheduling, cancellation, and notification identifiers.
- `ShieldClient`: Screen Time authorization status and applying or clearing a stable named `ManagedSettingsStore`.
- `ActivitySelectionStore` or equivalent small helper: encoding and decoding `FamilyActivitySelection` if that logic does not fit cleanly in `ShieldClient`.
- `SleepSchedule`: resolves bedtime and wake time into one nightly interval.

The app delegate or notification-center delegate forwards notification responses into `SleepyStore`. Deep-link routing should remain internal and purpose-built for these four actions; do not introduce a generic navigation framework.

## 8. Screen Time and Shielding

### Authorization and selection

- Request individual authorization through `AuthorizationCenter`.
- Show unknown, approved, denied, and unavailable states honestly.
- Present `FamilyActivityPicker` only when the platform supports it.
- Preserve an existing selection when the picker is cancelled.
- Allow the user to replace or clear the saved selection from Settings.

### Applying shields

Use one stable named `ManagedSettingsStore` shared by the app and Device Activity monitor extension.

When sleep starts, apply all non-empty parts of the saved selection:

- application tokens
- category tokens
- web-domain tokens

`ShieldClient.isActive` must describe whether Sleepy's named store contains an active shield configuration, not merely whether a session is active. It must not claim to know whether that configuration wins against every other system setting.

### Automatic clearing

Add a minimal Device Activity monitor extension whose only 0002 responsibility is clearing Sleepy's named Managed Settings store when the sleep interval ends.

Apple delivers `intervalDidEnd` when the device is first used outside the scheduled interval, rather than guaranteeing execution at the exact wake-time minute. The product guarantee is therefore that the session is logically complete at wake time and that the extension clears shields when the user next uses the device. Launch recovery also clears the store defensively. The UI and test notes must not claim exact-minute background execution.

The extension should not calculate rewards, own product state, or render custom shield UI. The main app awards completion progress during its next recovery pass.

Do not add an App Group unless implementation proves that the extension requires shared custom data. Clearing the stable named Managed Settings store should not depend on reading the app's SwiftData store.

## 9. Notifications

Register one bedtime notification category with stable action identifiers at app startup.

Use stable request identifiers for:

- original bedtime prompt
- no-response follow-up
- each nightly snooze reminder

Scheduling a new night's notifications first removes obsolete requests for the previous schedule. Changing bedtime reschedules pending bedtime notifications.

Notification response handling must update the persisted session before routing the UI. This prevents relaunches or repeated delegate callbacks from duplicating rewards or snoozes.

If notification permission is denied, Home and Settings show reminders as inactive and provide a route to system settings. Manual bedtime actions remain available.

## 10. Functional UI Requirements

UI work in 0002 is limited to making states understandable and testable.

### Routine progress header

- Keep the routine-progress header pinned at the top of every Sleepy-owned app screen except active Sleep Sanctuary.
- System-owned permission prompts and `FamilyActivityPicker` sheets are outside this rule.
- The header must not move into or out of the normal content hierarchy as the user navigates; screens render beneath it.
- The bar represents completion of the nightly Brush and Sleep actions, not whether the night earned rewards.
- Before Brush resolves, progress is 0%.
- Done brushing or Skip tonight completes Brush and sets progress to 50%.
- Successfully entering Sleep Sanctuary completes Sleep and sets progress to 100%.
- Show the 100% state for one second before replacing the current screen with active Sleep Sanctuary.
- Hide the entire header during active Sleep Sanctuary.
- Restore the header at 100% on Morning Summary, including when the user chose End early.
- Keep the completed state after returning Home for that same nightly session. Reset to 0% only when the app creates or rolls over to the next nightly session.

The one-second completion hold must be driven by the transition into persisted active-session state. A failed attempt that never starts a session must not fill the bar or navigate to active Sleep Sanctuary.

Required UI changes:

- accurate notification and Screen Time permission rows
- an app-selection row showing whether a selection is empty
- clear actions to request permission, choose apps, and open system settings
- a Home status that distinguishes scheduled, permission-limited, and ready states
- the persistent routine-progress header and its completed-state transition
- an active Sleep Sanctuary screen showing wake time and real shield status
- an End early confirmation
- a morning summary that distinguishes completed and ended-early sessions
- readable error or recovery messaging when saved selection or schedule state cannot be restored

Use standard SwiftUI components and system symbols. Production assets are not required.

## 11. Error Handling and Safety

- Notification denied: keep manual flow available and show reminders inactive.
- Screen Time denied or revoked: do not claim shields are active; allow an unshielded session.
- Empty selection: allow sleep, but show that no apps are blocked.
- Selection decode failure: clear the invalid selection and prompt for reselection.
- Device Activity scheduling failure: clear any newly applied shield and explain that automatic wake-time clearing is unavailable.
- Stale active session: clear shields before reconciling or starting another session.
- Repeated notification callback or recovery pass: rely on persisted state and reward flags to avoid duplicate effects.
- Shield clearing must be safe to call repeatedly.

The app must favor avoiding a stale shield over preserving an uncertain active-session state.

## 12. Testing

### Automated tests

Add focused tests for:

- same-day and overnight schedule resolution
- calendar behavior around time-zone and daylight-saving changes
- snooze persistence and the three-snooze cap
- each notification action's state transition
- routine progress for unresolved Brush, resolved Brush, active Sleep, completed Sleep, and End early
- progress reset when a new nightly session replaces the previous session
- stable notification identifiers and requested dates
- brushing reward idempotency
- sleep reward idempotency
- streak continuation, gap reset, ended-early reset, and best-streak updates
- active-session recovery before and after wake time
- End early behavior
- encoded selection round trip where Apple token construction permits it
- mock shield apply and repeated clear behavior

### Simulator checks

Verify:

- setup reaches Home with mocked or unavailable Screen Time state
- notification-denied and Screen Time-unavailable states remain usable
- selection-empty messaging is correct
- Brush -> Start Sleep -> End early -> Summary works
- the progress header stays visible across app screens, briefly reaches 100%, hides in active Sleep Sanctuary, and returns complete on Summary
- relaunch-style recovery can be exercised with injected dates and persisted test data

### Physical-iPhone checks

Verify on at least one supported iPhone:

- notification permission and Screen Time authorization prompts appear
- `FamilyActivityPicker` saves and restores a selection
- the bedtime notification displays all four actions
- Starting now, Already done, Skip tonight, and snooze route correctly
- a fourth snooze is not scheduled
- starting Sleep Sanctuary shields selected targets
- End early clears shields immediately
- after wake time, first device use causes the Device Activity monitor to clear shields while the main app is not running
- reopening after wake time grants completion rewards exactly once
- denying or revoking permissions produces honest limited-mode UI

Record the device model, iOS version, commands, and results in `test-notes.md` for this iteration.

## 13. Acceptance Criteria

Iteration 0002 is complete only when:

- the app builds and all automated tests pass
- the complete bedtime loop works after terminating and relaunching the app
- settings, selection, session, snooze count, and progress persist
- real selected targets are shielded on a physical iPhone
- End early reliably removes those shields
- after wake time, shields are removed on the system's first outside-interval device-use callback without requiring the main app to run
- notification actions produce the documented state transitions
- the routine-progress header follows the documented visibility, completion, one-second hold, and nightly-reset rules
- rewards and streaks cannot be granted twice for one session
- denied, revoked, empty-selection, and recovery states are represented honestly
- real-device results and any entitlement requirements are documented

Passing Simulator tests alone is not sufficient to complete 0002.

## 14. Suggested Delivery Order

1. Add schedule calculation and durable settings/session/progress state.
2. Prove authorization, selection persistence, and manual shield apply/clear on a real iPhone.
3. Add the minimal Device Activity monitor extension and verify wake-time clearing.
4. Add notification categories, actions, snoozes, and persisted routing.
5. Add launch/foreground recovery and idempotent reward updates.
6. Finish the functional permission, error, and summary UI states.
7. Run the full Simulator and physical-device acceptance checks.

If real-device testing reveals an Apple-platform constraint, revise this spec before expanding architecture or adding another extension.
