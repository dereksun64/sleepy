# Sleepy Product Brief

## 1. Product Summary

Sleepy is a native iOS bedtime accountability app that helps the user move from "I should go to sleep" to taking the next concrete bedtime action.

The first product version is intentionally small: prompt the user to brush their teeth, guide them into a Sleep Sanctuary session, shield distracting apps during sleep, and show a simple morning summary with basic progress rewards.

Sleepy should feel like a clear nightly nudge, not a full wellness platform.

## 2. User Problem

The user already knows they should go to bed, but the gap between intention and action is easy to lose to late-night scrolling, friction, and vague routines.

The product focuses on the moment where the user needs a direct prompt and a short path:

1. Start brushing.
2. Confirm brushing is done.
3. Start Sleep Sanctuary.
4. Put the phone down because distracting apps are shielded.

Sleepy should reduce decision-making at bedtime. It should not ask the user to design a perfect routine before it can help.

## 3. Target User

Sleepy is for iPhone users who want a firmer bedtime boundary but do not need a complex sleep tracker.

The target user:

- Has a target bedtime and wake-up time they are trying to respect.
- Gets pulled into distracting apps at night.
- Benefits from a concrete prompt like "Are you brushing your teeth now?"
- Wants lightweight progress feedback without managing a large habit system.
- Is comfortable granting iOS permissions when the value is clear.

The first version should serve one user on one device.

## 4. Core User Journey

1. The user sets a target bedtime and wake-up time.
2. The user chooses distracting apps to shield during sleep.
3. At bedtime, Sleepy sends: "Are you brushing your teeth now?"
4. The user chooses one of four actions:
   - Starting now
   - Remind me in 5 minutes
   - Already done
   - Skip tonight
5. If the user chooses Starting now, Sleepy opens brushing confirmation.
6. The user taps Done brushing.
7. Sleepy prompts the user to start Sleep Sanctuary.
8. The user starts Sleep Sanctuary.
9. Sleepy shields the selected apps during the sleep session.
10. The session ends automatically at wake time, or the user ends it manually with End early.
11. Sleepy shows a morning summary with basic XP, coins, streak, and last-night status.

## 5. MVP Scope

The MVP should include only the smallest complete bedtime accountability loop.

In scope:

- Set target bedtime.
- Set target wake-up time.
- Choose distracting apps to shield.
- Send the bedtime notification: "Are you brushing your teeth now?"
- Support notification and in-app actions:
  - Starting now
  - Remind me in 5 minutes
  - Already done
  - Skip tonight
- Open brushing confirmation from Starting now.
- Let the user tap Done brushing.
- Prompt the user to start Sleep Sanctuary after brushing is done or skipped.
- Shield selected apps during sleep.
- End the session automatically at wake time.
- Let the user manually choose End early.
- Show a morning summary.
- Track basic XP, coins, and streak.

The MVP should be useful even with plain screens and minimal visual polish. The important product proof is the nightly flow from reminder to app shielding to morning feedback.

## 6. Non-Goals

These are intentionally out of scope for the current phase:

- Custom routines
- Low-energy routine modes
- Accountability partners
- Weekly reports
- Widgets
- Live Activities
- HealthKit
- iCloud sync
- Shared challenges
- Collectible sanctuary systems
- Detailed analytics

These ideas may return later, but they should not influence the first version's information architecture, data model, or UI beyond leaving reasonable room for extension.

## 7. Reward Loop

Sleepy's reward loop should reinforce completion without becoming the main product.

The basic loop:

1. The user responds to the bedtime prompt.
2. The user confirms brushing or chooses an explicit skip.
3. The user starts Sleep Sanctuary.
4. The user makes it to wake time or ends early.
5. Sleepy shows XP, coins, streak, and a simple completion message in the morning.

Rewards should be lightweight:

- XP reflects completed bedtime actions.
- Coins provide a simple sense of accumulation.
- Streak reflects consistency across nights.
- The morning summary closes the loop and prepares the user for the next night.

For the MVP, rewards should not require a store, collectibles, complex leveling, or social comparison.

## 8. Success Criteria

The first version is successful if it proves the core bedtime accountability loop on a real iPhone.

Product success criteria:

- A user can complete setup without needing advanced configuration.
- The bedtime notification clearly asks for the next action.
- The four bedtime actions lead to predictable states.
- Brushing confirmation is fast and unambiguous.
- The transition from brushing to Sleep Sanctuary is clear.
- Selected distracting apps are shielded during an active sleep session when permissions allow.
- Shields end at wake time or when the user chooses End early.
- The morning summary makes last night's outcome understandable.
- XP, coins, and streak update consistently enough to make returning tomorrow feel worthwhile.

Scope success criteria:

- The app does not expand into custom routines, social accountability, analytics, or rich gamification during the MVP.
- Every MVP feature supports the core journey from bedtime prompt to phone-down behavior.

## 9. Future Expansion Ideas

Future ideas should be evaluated only after the small native MVP works reliably.

Possible expansions:

- Custom bedtime routines with additional steps.
- Low-energy routine modes for difficult nights.
- Accountability partners or check-ins.
- Weekly sleep and routine reports.
- Widgets for quick bedtime status.
- Live Activities for an active Sleep Sanctuary session.
- HealthKit integration for richer sleep context.
- iCloud sync across devices.
- Shared challenges with friends.
- Collectible or customizable sanctuary systems.
- More detailed analytics around bedtime consistency and app shielding.

The guiding rule for future expansion: add features only if they strengthen the user's path from bedtime intention to concrete action and phone-down behavior.
