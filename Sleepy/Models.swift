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

enum PermissionState: String, Codable {
    case unknown
    case approved
    case denied
    case unavailable
}

enum BrushingStatus: String, Codable {
    case notStarted
    case started
    case done
    case skipped
}

enum SleepStatus: String, Codable {
    case notStarted
    case active
    case completed
    case ended
}

@Model
final class UserSettings {
    var targetBedtime: Date
    var wakeTime: Date
    var hasCompletedOnboarding: Bool
    var notificationPermissionRawValue: String
    var screenTimePermissionRawValue: String
    var activitySelectionData: Data

    init(
        targetBedtime: Date = .now,
        wakeTime: Date = .now,
        hasCompletedOnboarding: Bool = false,
        notificationPermission: PermissionState = .unknown,
        screenTimePermission: PermissionState = .unknown,
        activitySelectionData: Data = Data()
    ) {
        self.targetBedtime = targetBedtime
        self.wakeTime = wakeTime
        self.hasCompletedOnboarding = hasCompletedOnboarding
        notificationPermissionRawValue = notificationPermission.rawValue
        screenTimePermissionRawValue = screenTimePermission.rawValue
        self.activitySelectionData = activitySelectionData
    }
}

@Model
final class SleepSession {
    @Attribute(.unique) var id: UUID
    var scheduledBedtime: Date
    var scheduledWakeTime: Date
    var actualStartTime: Date?
    var actualEndTime: Date?
    var brushingStatusRawValue: String
    var brushingRewardGranted: Bool
    var sleepStatusRawValue: String
    var snoozeCount: Int
    var endedEarly: Bool
    var sleepRewardGranted: Bool

    init(id: UUID = UUID(), interval: DateInterval) {
        self.id = id
        scheduledBedtime = interval.start
        scheduledWakeTime = interval.end
        brushingStatusRawValue = BrushingStatus.notStarted.rawValue
        brushingRewardGranted = false
        sleepStatusRawValue = SleepStatus.notStarted.rawValue
        snoozeCount = 0
        endedEarly = false
        sleepRewardGranted = false
    }
}

@Model
final class ProgressProfile {
    var xp: Int
    var coins: Int
    var currentStreak: Int
    var bestStreak: Int
    var lastCompletedSleepDate: Date?

    init(
        xp: Int = 0,
        coins: Int = 0,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        lastCompletedSleepDate: Date? = nil
    ) {
        self.xp = xp
        self.coins = coins
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.lastCompletedSleepDate = lastCompletedSleepDate
    }
}

extension UserSettings {
    var notificationPermission: PermissionState {
        get { PermissionState(rawValue: notificationPermissionRawValue) ?? .unknown }
        set { notificationPermissionRawValue = newValue.rawValue }
    }

    var screenTimePermission: PermissionState {
        get { PermissionState(rawValue: screenTimePermissionRawValue) ?? .unknown }
        set { screenTimePermissionRawValue = newValue.rawValue }
    }
}

extension SleepSession {
    var brushingStatus: BrushingStatus {
        get { BrushingStatus(rawValue: brushingStatusRawValue) ?? .notStarted }
        set { brushingStatusRawValue = newValue.rawValue }
    }

    var sleepStatus: SleepStatus {
        get { SleepStatus(rawValue: sleepStatusRawValue) ?? .notStarted }
        set { sleepStatusRawValue = newValue.rawValue }
    }
}
