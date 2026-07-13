# Agents Guide

## Project Summary

Sleepy is a native iOS bedtime accountability app. The 0001-skeleton goal is to prove a small working flow: remind the user to brush teeth, start a Sleep Sanctuary session, shield distracting apps during sleep where iOS allows it, and show a simple morning reward.

Build the simplest native SwiftUI MVP that works. Prefer a plain, reliable app over flexible future architecture.

## Hard Scope Boundaries

- Native iOS only: Swift, SwiftUI, SwiftData, UserNotifications, FamilyControls, ManagedSettings.
- Use DeviceActivity only if the sleep/shield lifecycle truly needs it.
- Use App Groups only if an extension needs shared state.
- Keep the 0001 routine to two steps: Brush and Sleep.
- Simulator or unavailable Screen Time permission must use mock shielding.
- Do not build React Native.
- Do not add custom routines, low-energy modes, accountability partners, weekly reports, widgets, Live Activities, HealthKit, iCloud sync, shared challenges, or collectible systems yet.
- Do not add TCA, Clean Architecture, broad repository layers, analytics platforms, or speculative plugin systems.

## Coding Principles

- Keep files few and code boring.
- Use SwiftUI views for rendering and small actions.
- Add a ViewModel only when a view is becoming hard to read.
- Put platform work behind small services such as notifications and shielding.
- Use SwiftData for local durable state.
- Prefer explicit simple state over a generic state machine framework.
- Reuse local code before creating helpers.
- Add dependencies only when the platform or standard library cannot reasonably solve the problem.
- Do not scaffold for future phases.

## Documentation Rules

- Treat `docs/iterations/0001-skeleton/spec.md` as the current product source of truth.
- Keep docs short and actionable.
- Update iteration docs when behavior, scope, commands, or done criteria change.
- Put test commands and manual results in `docs/iterations/0001-skeleton/test-notes.md`.
- Put checklist progress in `docs/iterations/0001-skeleton/checklist.md`.
- Do not write long architecture essays before the app exists.

## Git Workflow Expectations

- Check `git status --short` before changing files.
- Do not revert user changes unless explicitly asked.
- Keep commits small and tied to one task.
- Use clear commit messages such as `Add iOS app skeleton` or `Wire brushing flow`.
- Do not mix formatting churn with behavior changes.
- Do not commit broken builds unless the user explicitly asks for a checkpoint.

## Testing Expectations

- Add focused XCTest coverage for core non-UI logic.
- Prioritize tests for bedtime/wake calculations, snooze cap, sleep state transitions, rewards, streaks, mock shield apply/clear, and notification scheduling inputs.
- Keep UI tests out of 0001 unless they become necessary.
- Run the smallest relevant test or build command before reporting success.
- If a real-device-only capability cannot be tested, document that clearly in test notes.

## iOS-Specific Constraints

- Screen Time APIs require real permissions and may not behave fully in Simulator.
- FamilyControls selection and ManagedSettings shielding must degrade to mock mode when unavailable.
- Real shielding should be isolated behind a small boundary so the app still builds and runs in Simulator.
- Clear shields when sleep ends, when the user ends early, and on launch if an active session has passed wake time.
- Notification permission denial must not block manual app use.
- Do not claim the app detects that the phone was put down.

## Before Changing Code

- Read this file and the current iteration spec.
- Check the worktree for existing changes.
- Identify the smallest file set needed for the task.
- Confirm the change is inside 0001 scope.
- Prefer using the existing app shape over adding a new layer.
- Decide how the change will be verified before editing.

## Avoid

- Future-proof architecture.
- Extra screens beyond the current flow.
- Generic routine builders.
- Reward economies beyond simple XP, coins, and streak.
- Background behavior that iOS does not allow.
- Silent failure around notification or Screen Time permissions.
- Large refactors while implementing a narrow task.
- New dependencies for simple local logic.
- Polished visual design work in 0001 unless explicitly requested.
