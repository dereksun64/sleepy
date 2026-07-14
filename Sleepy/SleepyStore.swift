import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SleepyStore {
    private var modelContext: ModelContext?
    private(set) var settings = UserSettings()
    private(set) var profile = ProgressProfile()
    private(set) var session: SleepSession?
    private(set) var isShowingSettings = false
    private var isShowingHome = false
    private(set) var recoveryMessage: String?
    private(set) var shieldStatusMessage = "Distracting apps are not being blocked."

    var stage: AppStage {
        get {
            if !settings.hasCompletedOnboarding { return .onboarding }
            if isShowingSettings { return .settings }
            if isShowingHome { return .home }
            guard let session else { return .home }
            switch session.sleepStatus {
            case .active:
                return .sleepActive
            case .completed, .ended:
                return .summary
            case .notStarted:
                switch session.brushingStatus {
                case .started:
                    return .brushing
                case .done, .skipped:
                    return .startSleep
                case .notStarted:
                    return .home
                }
            }
        }
        set {
            isShowingSettings = newValue == .settings
            isShowingHome = newValue == .home
            try? save()
        }
    }

    var routineProgress: Double {
        guard let session else { return 0 }
        if session.sleepStatus != .notStarted { return 1 }
        return session.brushingStatus == .done || session.brushingStatus == .skipped ? 0.5 : 0
    }

    var bedtime: Date {
        get { settings.targetBedtime }
        set {
            settings.targetBedtime = newValue
            try? save()
        }
    }

    var wakeTime: Date {
        get { settings.wakeTime }
        set {
            settings.wakeTime = newValue
            try? save()
        }
    }

    var brushingStatus: BrushingStatus { session?.brushingStatus ?? .notStarted }
    var sleepStatus: SleepStatus { session?.sleepStatus ?? .notStarted }
    var snoozeCount: Int { session?.snoozeCount ?? 0 }
    var xp: Int { profile.xp }
    var coins: Int { profile.coins }
    var streak: Int { profile.currentStreak }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        settings = fetch(UserSettings.self).first ?? insert(UserSettings())
        profile = fetch(ProgressProfile.self).first ?? insert(ProgressProfile())
        session = fetch(SleepSession.self)
            .sorted { $0.scheduledBedtime > $1.scheduledBedtime }
            .first
        try? modelContext.save()
    }

    func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        try? save()
    }

    func showSettings() {
        isShowingSettings = true
        isShowingHome = false
        try? save()
    }

    func showHome() {
        isShowingSettings = false
        isShowingHome = true
        try? save()
    }

    func updateSettings(targetBedtime: Date, wakeTime: Date) throws {
        settings.targetBedtime = targetBedtime
        settings.wakeTime = wakeTime
        try save()
    }

    func beginBrushing(at now: Date = .now, calendar: Calendar = .current) throws {
        let current = try ensureSession(at: now, calendar: calendar)
        current.brushingStatus = .started
        try save()
    }

    func finishBrushing(at now: Date = .now, calendar: Calendar = .current) throws {
        let current = try ensureSession(at: now, calendar: calendar)
        current.brushingStatus = .done
        if !current.brushingRewardGranted {
            profile.xp += 10
            profile.coins += 2
            current.brushingRewardGranted = true
        }
        try save()
    }

    func skipBrushing(at now: Date = .now, calendar: Calendar = .current) throws {
        let current = try ensureSession(at: now, calendar: calendar)
        current.brushingStatus = .skipped
        try save()
    }

    func recordSnooze(at now: Date = .now, calendar: Calendar = .current) throws -> Bool {
        let current = try ensureSession(at: now, calendar: calendar)
        guard current.snoozeCount < 3 else {
            current.brushingStatus = .started
            try save()
            return false
        }
        current.snoozeCount += 1
        try save()
        return true
    }

    func markSleepActive(at now: Date = .now, calendar: Calendar = .current) throws {
        let current = try ensureSession(at: now, calendar: calendar)
        current.sleepStatus = .active
        current.actualStartTime = now
        try save()
    }

    func endEarly(at now: Date = .now) throws {
        guard let session else { return }
        session.sleepStatus = .ended
        session.endedEarly = true
        session.actualEndTime = now
        profile.currentStreak = 0
        try save()
    }

    func recover(at now: Date = .now, calendar: Calendar = .current) throws {
        guard let session, session.sleepStatus == .active, now >= session.scheduledWakeTime else { return }
        session.sleepStatus = .completed
        session.actualEndTime = session.scheduledWakeTime
        awardSleepIfNeeded(for: session, calendar: calendar)
        try save()
    }

    func snooze() -> Bool {
        (try? recordSnooze()) ?? false
    }

    func startBrushing() {
        try? beginBrushing()
    }

    func doneBrushing() {
        try? finishBrushing()
    }

    func skipBrushing() {
        try? skipBrushing(at: .now, calendar: .current)
    }

    func startSleep() {
        try? markSleepActive()
    }

    func endSleep(endedEarly: Bool) {
        if endedEarly {
            try? endEarly()
        } else if let session {
            try? recover(at: session.scheduledWakeTime)
        }
    }

    func resetToHome() {
        showHome()
    }

    private func ensureSession(at now: Date, calendar: Calendar) throws -> SleepSession {
        isShowingHome = false
        let interval = SleepSchedule.currentOrNext(
            at: now,
            bedtime: settings.targetBedtime,
            wakeTime: settings.wakeTime,
            calendar: calendar
        )
        if let session, calendar.isDate(session.scheduledBedtime, inSameDayAs: interval.start) {
            return session
        }
        if session?.sleepStatus == .active {
            recoveryMessage = "A stale Sleep Sanctuary was cleared before starting tonight."
        }
        let replacement = insert(SleepSession(interval: interval))
        session = replacement
        try save()
        return replacement
    }

    private func awardSleepIfNeeded(for session: SleepSession, calendar: Calendar) {
        guard !session.sleepRewardGranted else { return }
        profile.xp += 50
        profile.coins += 10
        let priorDay = calendar.date(byAdding: .day, value: -1, to: session.scheduledBedtime)!
        profile.currentStreak = profile.lastCompletedSleepDate.map {
            calendar.isDate($0, inSameDayAs: priorDay) ? profile.currentStreak + 1 : 1
        } ?? 1
        profile.bestStreak = max(profile.bestStreak, profile.currentStreak)
        profile.lastCompletedSleepDate = session.scheduledBedtime
        session.sleepRewardGranted = true
    }

    private func fetch<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? modelContext?.fetch(FetchDescriptor<T>())) ?? []
    }

    @discardableResult
    private func insert<T: PersistentModel>(_ value: T) -> T {
        modelContext?.insert(value)
        return value
    }

    private func save() throws {
        try modelContext?.save()
    }
}
