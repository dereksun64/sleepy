import Foundation
import FamilyControls
import Observation
import SwiftData

private enum StoreError: LocalizedError {
    case notConfigured

    var errorDescription: String? { "Sleepy storage is not configured." }
}

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
    private(set) var activitySelection = FamilyActivitySelection(includeEntireCategory: true)
    private(set) var selectionNeedsRepair = false

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
            attempt {
                settings.targetBedtime = newValue
                try save()
            }
        }
    }

    var wakeTime: Date {
        get { settings.wakeTime }
        set {
            attempt {
                settings.wakeTime = newValue
                try save()
            }
        }
    }

    var brushingStatus: BrushingStatus { session?.brushingStatus ?? .notStarted }
    var sleepStatus: SleepStatus { session?.sleepStatus ?? .notStarted }
    var snoozeCount: Int { session?.snoozeCount ?? 0 }
    var xp: Int { profile.xp }
    var coins: Int { profile.coins }
    var streak: Int { profile.currentStreak }

    func configure(modelContext: ModelContext) throws {
        let storedSettings = try fetch(UserSettings.self, from: modelContext)
        let storedProfiles = try fetch(ProgressProfile.self, from: modelContext)
        let storedSessions = try fetch(SleepSession.self, from: modelContext)
        let configuredSettings = storedSettings.first ?? UserSettings()
        let configuredProfile = storedProfiles.first ?? ProgressProfile()
        if storedSettings.isEmpty { modelContext.insert(configuredSettings) }
        if storedProfiles.isEmpty { modelContext.insert(configuredProfile) }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
        self.modelContext = modelContext
        settings = configuredSettings
        profile = configuredProfile
        session = storedSessions
            .sorted { $0.scheduledBedtime > $1.scheduledBedtime }
            .first
        restoreSelection()
    }

    func finishOnboarding() {
        attempt {
            settings.hasCompletedOnboarding = true
            try save()
        }
    }

    func showSettings() {
        isShowingSettings = true
        isShowingHome = false
    }

    func showHome() {
        isShowingSettings = false
        isShowingHome = true
    }

    func updateSettings(targetBedtime: Date, wakeTime: Date) throws {
        settings.targetBedtime = targetBedtime
        settings.wakeTime = wakeTime
        try save()
    }

    func restoreSelection() {
        do {
            activitySelection = try ShieldClient.decode(settings.activitySelectionData)
            selectionNeedsRepair = false
        } catch {
            activitySelection = FamilyActivitySelection(includeEntireCategory: true)
            settings.activitySelectionData = Data()
            selectionNeedsRepair = true
            try? save()
        }
    }

    func saveSelection(_ selection: FamilyActivitySelection) throws {
        settings.activitySelectionData = try ShieldClient.encode(selection)
        activitySelection = selection
        selectionNeedsRepair = false
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
        attempt { try recordSnooze() } ?? false
    }

    func startBrushing() {
        attempt { try beginBrushing() }
    }

    func doneBrushing() {
        attempt { try finishBrushing() }
    }

    func skipBrushing() {
        attempt { try skipBrushing(at: .now, calendar: .current) }
    }

    func startSleep() {
        attempt { try markSleepActive() }
    }

    func endSleep(endedEarly: Bool) {
        if endedEarly {
            attempt { try endEarly() }
        } else if let session {
            attempt { try recover(at: session.scheduledWakeTime) }
        }
    }

    func resetToHome() {
        showHome()
    }

    private func ensureSession(at now: Date, calendar: Calendar) throws -> SleepSession {
        guard let modelContext else { throw StoreError.notConfigured }
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
        let replacement = SleepSession(interval: interval)
        modelContext.insert(replacement)
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

    private func fetch<T: PersistentModel>(_ type: T.Type, from modelContext: ModelContext) throws -> [T] {
        try modelContext.fetch(FetchDescriptor<T>())
    }

    @discardableResult
    private func attempt<T>(_ operation: () throws -> T) -> T? {
        guard modelContext != nil else {
            recoveryMessage = StoreError.notConfigured.localizedDescription
            return nil
        }
        let previousSession = session
        let previousIsShowingHome = isShowingHome
        do {
            return try operation()
        } catch {
            modelContext?.rollback()
            session = previousSession
            isShowingHome = previousIsShowingHome
            recoveryMessage = "Sleepy couldn't save that change. Please try again."
            return nil
        }
    }

    private func save() throws {
        guard let modelContext else { throw StoreError.notConfigured }
        try modelContext.save()
    }
}
