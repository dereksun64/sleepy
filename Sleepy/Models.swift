import Foundation
import SwiftData

enum AppStage: String, Codable {
    case onboarding
    case home
    case brushing
    case startSleep
    case sleepActive
    case summary
    case settings
}

enum BrushingStatus: String, Codable {
    case notStarted
    case done
    case skipped
}

enum SleepStatus: String, Codable {
    case notStarted
    case active
    case ended
}

@Model
final class UserSettings {
    var targetBedtime: Date
    var wakeTime: Date
    var hasCompletedOnboarding: Bool

    init(targetBedtime: Date = .now, wakeTime: Date = .now, hasCompletedOnboarding: Bool = false) {
        self.targetBedtime = targetBedtime
        self.wakeTime = wakeTime
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}

@Model
final class SleepSession {
    var date: Date
    var brushingStatusRawValue: String
    var sleepStatusRawValue: String
    var snoozeCount: Int
    var endedEarly: Bool

    init(
        date: Date = .now,
        brushingStatus: BrushingStatus = .notStarted,
        sleepStatus: SleepStatus = .notStarted,
        snoozeCount: Int = 0,
        endedEarly: Bool = false
    ) {
        self.date = date
        self.brushingStatusRawValue = brushingStatus.rawValue
        self.sleepStatusRawValue = sleepStatus.rawValue
        self.snoozeCount = snoozeCount
        self.endedEarly = endedEarly
    }
}

@Model
final class ProgressProfile {
    var xp: Int
    var coins: Int
    var streak: Int

    init(xp: Int = 0, coins: Int = 0, streak: Int = 0) {
        self.xp = xp
        self.coins = coins
        self.streak = streak
    }
}
