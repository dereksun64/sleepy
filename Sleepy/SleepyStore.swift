import Foundation
import FamilyControls
import Observation
import SwiftData

private enum StoreError: LocalizedError {
    case notConfigured
    case activeSessionConflict

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Sleepy storage is not configured."
        case .activeSessionConflict:
            "An active Sleep Sanctuary must be recovered or ended before starting another night."
        }
    }
}

private enum SnoozeMutationError: Error {
    case staleResponse
}

@MainActor
@Observable
final class SleepyStore {
    private var modelContext: ModelContext?
    private let saveModelContext: (ModelContext) throws -> Void
    private(set) var settings = UserSettings()
    private(set) var profile = ProgressProfile()
    private(set) var session: SleepSession?
    private(set) var isShowingSettings = false
    private var isShowingHome = false
    private(set) var recoveryMessage: String?
    private(set) var shieldStatusMessage = "Distracting apps are not being blocked."
    private(set) var activitySelection = FamilyActivitySelection(includeEntireCategory: true)
    private(set) var selectionNeedsRepair = false
    var isConfigured: Bool { modelContext != nil }

    init(saveModelContext: ((ModelContext) throws -> Void)? = nil) {
        self.saveModelContext = saveModelContext ?? { try $0.save() }
    }

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
        settings.targetBedtime
    }

    var wakeTime: Date {
        settings.wakeTime
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
            try saveModelContext(modelContext)
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
        try restoreSelection()
    }

    func configureForLaunch(modelContext: ModelContext) {
        do {
            try configure(modelContext: modelContext)
        } catch {
            recoveryMessage = "Sleepy couldn't load saved data: \(error.localizedDescription)"
        }
    }

    func finishOnboarding(
        notifications: NotificationClient,
        at now: Date = .now,
        calendar: Calendar = .current
    ) async throws {
        try await updateSchedule(
            bedtime: settings.targetBedtime,
            wakeTime: settings.wakeTime,
            notifications: notifications,
            at: now,
            calendar: calendar
        )
        try withRollback {
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

    func updateSettings(
        targetBedtime: Date,
        wakeTime: Date,
        at now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        try withRollback {
            synchronizePendingSession(
                bedtime: targetBedtime,
                wakeTime: wakeTime,
                at: now,
                calendar: calendar
            )
            settings.targetBedtime = targetBedtime
            settings.wakeTime = wakeTime
            try save()
        }
    }

    func updateSchedule(
        bedtime: Date,
        wakeTime: Date,
        notifications: NotificationClient,
        at now: Date = .now,
        calendar: Calendar = .current
    ) async throws {
        try updateSettings(
            targetBedtime: bedtime,
            wakeTime: wakeTime,
            at: now,
            calendar: calendar
        )
        let interval = SleepSchedule.currentOrNext(
            at: now,
            bedtime: bedtime,
            wakeTime: wakeTime,
            calendar: calendar
        )
        try await notifications.scheduleNight(interval: interval, calendar: calendar)
    }

    func restoreSelection() throws {
        do {
            activitySelection = try ShieldClient.decode(settings.activitySelectionData)
            selectionNeedsRepair = false
        } catch {
            try withRollback {
                activitySelection = FamilyActivitySelection(includeEntireCategory: true)
                settings.activitySelectionData = Data()
                selectionNeedsRepair = true
                try save()
            }
        }
    }

    func saveSelection(_ selection: FamilyActivitySelection) throws {
        try withRollback {
            settings.activitySelectionData = try ShieldClient.encode(selection)
            activitySelection = selection
            selectionNeedsRepair = false
            try save()
        }
    }

    func beginBrushing(at now: Date = .now, calendar: Calendar = .current) throws {
        try withRollback {
            let current = try ensureSession(at: now, calendar: calendar)
            current.brushingStatus = .started
            try save()
        }
    }

    func finishBrushing(at now: Date = .now, calendar: Calendar = .current) throws {
        try withRollback {
            let current = try ensureSession(at: now, calendar: calendar)
            current.brushingStatus = .done
            if !current.brushingRewardGranted {
                profile.xp += 10
                profile.coins += 2
                current.brushingRewardGranted = true
            }
            try save()
        }
    }

    func skipBrushing(at now: Date = .now, calendar: Calendar = .current) throws {
        try withRollback {
            let current = try ensureSession(at: now, calendar: calendar)
            current.brushingStatus = .skipped
            try save()
        }
    }

    func recordSnooze(at now: Date = .now, calendar: Calendar = .current) throws -> Bool {
        try withRollback {
            let current = try ensureSession(at: now, calendar: calendar)
            let shouldSchedule = mutateSnooze(current)
            try save()
            return shouldSchedule
        }
    }

    func handleNotificationAction(
        _ action: NotificationAction,
        requestIdentifier: String,
        notifications: NotificationClient,
        at now: Date = .now,
        calendar: Calendar = .current
    ) async throws {
        switch action {
        case .startingNow:
            try beginBrushing(at: now, calendar: calendar)
        case .snooze:
            guard let sourceCount = NotificationID.snoozeCount(for: requestIdentifier) else {
                notifications.cancelNoResponseFollowUp()
                return
            }
            let count: Int?
            do {
                count = try withRollback {
                    let current = try ensureSession(at: now, calendar: calendar)
                    guard current.snoozeCount == sourceCount,
                          current.brushingStatus == .notStarted else {
                        throw SnoozeMutationError.staleResponse
                    }
                    let shouldSchedule = mutateSnooze(current)
                    try save()
                    return shouldSchedule ? current.snoozeCount : nil
                }
            } catch SnoozeMutationError.staleResponse {
                notifications.cancelNoResponseFollowUp()
                return
            }
            notifications.cancelNoResponseFollowUp()
            if let count {
                try await notifications.scheduleSnooze(count: count, from: now, calendar: calendar)
            }
            return
        case .alreadyDone:
            try finishBrushing(at: now, calendar: calendar)
        case .skipTonight:
            try skipBrushing(at: now, calendar: calendar)
        }
        notifications.cancelNoResponseFollowUp()
    }

    func markSleepActive(at now: Date = .now, calendar: Calendar = .current) throws {
        try withRollback {
            let current = try ensureSession(at: now, calendar: calendar)
            current.sleepStatus = .active
            current.actualStartTime = now
            try save()
        }
    }

    func activate(
        notifications: NotificationClient,
        shield: ShieldClient,
        at now: Date = .now,
        calendar: Calendar = .current
    ) async {
        do {
            let notificationPermission = await notifications.permissionStatus()
            try withRollback {
                settings.notificationPermission = notificationPermission
                settings.screenTimePermission = shield.authorizationStatus
                if let session, session.sleepStatus == .active {
                    if now >= session.scheduledWakeTime {
                        shield.clearShield()
                        session.sleepStatus = .completed
                        session.actualEndTime = session.scheduledWakeTime
                        awardSleepIfNeeded(for: session, calendar: calendar)
                    } else if settings.screenTimePermission != .approved || selectionNeedsRepair {
                        shield.clearShield()
                        shieldStatusMessage = "Screen Time access is unavailable, so distracting apps are not being blocked."
                    } else {
                        shieldStatusMessage = shield.isActive
                            ? "Selected distractions are shielded."
                            : "Screen Time did not apply the selected shields."
                    }
                }
                try save()
            }
        } catch {
            recoveryMessage = "Sleepy couldn't recover saved data: \(error.localizedDescription)"
        }
    }

    func startSleep(
        shield: ShieldClient,
        at now: Date = .now,
        calendar: Calendar = .current
    ) throws {
        do {
            let result = try withRollback {
                let current = try ensureSession(at: now, calendar: calendar)
                let result = shield.apply(
                    selection: activitySelection,
                    interval: DateInterval(start: current.scheduledBedtime, end: current.scheduledWakeTime),
                    calendar: calendar
                )
                current.sleepStatus = .active
                current.actualStartTime = now
                try save()
                return result
            }
            switch result {
            case .shielded where shield.isActive:
                shieldStatusMessage = "Selected distractions are shielded."
            case .shielded:
                shieldStatusMessage = "Screen Time did not apply the selected shields."
            case .unshielded(let message):
                shieldStatusMessage = message
            }
        } catch {
            shield.clearShield()
            throw error
        }
    }

    func endEarly(at now: Date = .now) throws {
        try withRollback {
            guard let session else { return }
            session.sleepStatus = .ended
            session.endedEarly = true
            session.actualEndTime = now
            profile.currentStreak = 0
            try save()
        }
    }

    func endEarly(shield: ShieldClient, at now: Date = .now) throws {
        shield.clearShield()
        try endEarly(at: now)
    }

    func handleNotificationResponse(
        _ action: NotificationAction,
        requestIdentifier: String,
        notifications: NotificationClient
    ) async {
        do {
            try await handleNotificationAction(
                action,
                requestIdentifier: requestIdentifier,
                notifications: notifications
            )
        } catch {
            modelContext?.rollback()
            recoveryMessage = "Sleepy couldn't save that notification response: \(error.localizedDescription)"
        }
    }

    func recover(at now: Date = .now, calendar: Calendar = .current) throws {
        try withRollback {
            guard let session, session.sleepStatus == .active, now >= session.scheduledWakeTime else { return }
            session.sleepStatus = .completed
            session.actualEndTime = session.scheduledWakeTime
            awardSleepIfNeeded(for: session, calendar: calendar)
            try save()
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
        if let session,
           session.scheduledBedtime == interval.start,
           session.scheduledWakeTime == interval.end {
            return session
        }
        if session?.sleepStatus == .active {
            throw StoreError.activeSessionConflict
        }
        let replacement = SleepSession(interval: interval)
        modelContext.insert(replacement)
        session = replacement
        return replacement
    }

    private func mutateSnooze(_ session: SleepSession) -> Bool {
        guard session.snoozeCount < 3 else {
            session.brushingStatus = .started
            return false
        }
        session.snoozeCount += 1
        return true
    }

    private func synchronizePendingSession(
        bedtime: Date,
        wakeTime: Date,
        at now: Date,
        calendar: Calendar
    ) {
        guard let session, session.sleepStatus == .notStarted else { return }
        let oldInterval = SleepSchedule.currentOrNext(
            at: now,
            bedtime: settings.targetBedtime,
            wakeTime: settings.wakeTime,
            calendar: calendar
        )
        guard session.scheduledBedtime == oldInterval.start,
              session.scheduledWakeTime == oldInterval.end else { return }
        let interval = SleepSchedule.currentOrNext(
            at: now,
            bedtime: bedtime,
            wakeTime: wakeTime,
            calendar: calendar
        )
        session.scheduledBedtime = interval.start
        session.scheduledWakeTime = interval.end
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

    private struct SessionSnapshot {
        let model: SleepSession
        let scheduledBedtime: Date
        let scheduledWakeTime: Date
        let actualStartTime: Date?
        let actualEndTime: Date?
        let brushingStatusRawValue: String
        let brushingRewardGranted: Bool
        let sleepStatusRawValue: String
        let snoozeCount: Int
        let endedEarly: Bool
        let sleepRewardGranted: Bool

        init(_ model: SleepSession) {
            self.model = model
            scheduledBedtime = model.scheduledBedtime
            scheduledWakeTime = model.scheduledWakeTime
            actualStartTime = model.actualStartTime
            actualEndTime = model.actualEndTime
            brushingStatusRawValue = model.brushingStatusRawValue
            brushingRewardGranted = model.brushingRewardGranted
            sleepStatusRawValue = model.sleepStatusRawValue
            snoozeCount = model.snoozeCount
            endedEarly = model.endedEarly
            sleepRewardGranted = model.sleepRewardGranted
        }

        func restore() {
            model.scheduledBedtime = scheduledBedtime
            model.scheduledWakeTime = scheduledWakeTime
            model.actualStartTime = actualStartTime
            model.actualEndTime = actualEndTime
            model.brushingStatusRawValue = brushingStatusRawValue
            model.brushingRewardGranted = brushingRewardGranted
            model.sleepStatusRawValue = sleepStatusRawValue
            model.snoozeCount = snoozeCount
            model.endedEarly = endedEarly
            model.sleepRewardGranted = sleepRewardGranted
        }
    }

    private struct StoreSnapshot {
        let targetBedtime: Date
        let wakeTime: Date
        let hasCompletedOnboarding: Bool
        let notificationPermissionRawValue: String
        let screenTimePermissionRawValue: String
        let activitySelectionData: Data
        let xp: Int
        let coins: Int
        let currentStreak: Int
        let bestStreak: Int
        let lastCompletedSleepDate: Date?
        let session: SessionSnapshot?
        let isShowingSettings: Bool
        let isShowingHome: Bool
        let recoveryMessage: String?
        let shieldStatusMessage: String
        let activitySelection: FamilyActivitySelection
        let selectionNeedsRepair: Bool
    }

    private func snapshot() -> StoreSnapshot {
        StoreSnapshot(
            targetBedtime: settings.targetBedtime,
            wakeTime: settings.wakeTime,
            hasCompletedOnboarding: settings.hasCompletedOnboarding,
            notificationPermissionRawValue: settings.notificationPermissionRawValue,
            screenTimePermissionRawValue: settings.screenTimePermissionRawValue,
            activitySelectionData: settings.activitySelectionData,
            xp: profile.xp,
            coins: profile.coins,
            currentStreak: profile.currentStreak,
            bestStreak: profile.bestStreak,
            lastCompletedSleepDate: profile.lastCompletedSleepDate,
            session: session.map(SessionSnapshot.init),
            isShowingSettings: isShowingSettings,
            isShowingHome: isShowingHome,
            recoveryMessage: recoveryMessage,
            shieldStatusMessage: shieldStatusMessage,
            activitySelection: activitySelection,
            selectionNeedsRepair: selectionNeedsRepair
        )
    }

    private func restore(_ snapshot: StoreSnapshot, in modelContext: ModelContext) {
        let failedSession = session
        modelContext.rollback()
        if let failedSession,
           failedSession !== snapshot.session?.model,
           failedSession.modelContext != nil {
            modelContext.delete(failedSession)
        }
        settings.targetBedtime = snapshot.targetBedtime
        settings.wakeTime = snapshot.wakeTime
        settings.hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        settings.notificationPermissionRawValue = snapshot.notificationPermissionRawValue
        settings.screenTimePermissionRawValue = snapshot.screenTimePermissionRawValue
        settings.activitySelectionData = snapshot.activitySelectionData
        profile.xp = snapshot.xp
        profile.coins = snapshot.coins
        profile.currentStreak = snapshot.currentStreak
        profile.bestStreak = snapshot.bestStreak
        profile.lastCompletedSleepDate = snapshot.lastCompletedSleepDate
        snapshot.session?.restore()
        session = snapshot.session?.model
        isShowingSettings = snapshot.isShowingSettings
        isShowingHome = snapshot.isShowingHome
        recoveryMessage = snapshot.recoveryMessage
        shieldStatusMessage = snapshot.shieldStatusMessage
        activitySelection = snapshot.activitySelection
        selectionNeedsRepair = snapshot.selectionNeedsRepair
    }

    private func withRollback<T>(_ operation: () throws -> T) throws -> T {
        guard let modelContext else { throw StoreError.notConfigured }
        let snapshot = snapshot()
        do {
            return try operation()
        } catch {
            restore(snapshot, in: modelContext)
            throw error
        }
    }

    private func save() throws {
        guard let modelContext else { throw StoreError.notConfigured }
        try saveModelContext(modelContext)
    }
}
