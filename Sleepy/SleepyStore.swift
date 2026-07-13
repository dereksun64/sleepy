import Foundation
import Observation

@Observable
final class SleepyStore {
    var stage: AppStage = .onboarding
    var bedtime = Date()
    var wakeTime = Date()
    var brushingStatus: BrushingStatus = .notStarted
    var sleepStatus: SleepStatus = .notStarted
    var snoozeCount = 0
    var xp = 0
    var coins = 0
    var streak = 0

    func finishOnboarding() {
        stage = .home
    }

    func snooze() -> Bool {
        guard snoozeCount < 3 else { return false }
        snoozeCount += 1
        return true
    }

    func startBrushing() {
        stage = .brushing
    }

    func doneBrushing() {
        brushingStatus = .done
        xp += 10
        coins += 2
        stage = .startSleep
    }

    func skipBrushing() {
        brushingStatus = .skipped
        stage = .startSleep
    }

    func startSleep() {
        sleepStatus = .active
        stage = .sleepActive
    }

    func endSleep(endedEarly: Bool) {
        sleepStatus = .ended
        if !endedEarly {
            xp += 50
            coins += 10
            streak += 1
        }
        stage = .summary
    }

    func resetToHome() {
        stage = .home
    }
}
