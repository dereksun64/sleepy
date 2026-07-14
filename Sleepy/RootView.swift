import FamilyControls
import SwiftUI
import UIKit

enum HomeReadiness {
    static func message(
        notification: PermissionState,
        screenTime: PermissionState,
        hasSelection: Bool
    ) -> String {
        guard notification == .approved else {
            return "Scheduled; reminders are inactive"
        }
        guard screenTime == .approved else {
            return "Scheduled; app blocking is unavailable"
        }
        guard hasSelection else {
            return "Scheduled; choose distracting apps to enable blocking"
        }
        return "Ready for bedtime"
    }
}

enum ActivitySelectionSummary {
    static func text(applications: Int, categories: Int, websites: Int) -> String {
        guard applications + categories + websites > 0 else { return "No apps selected" }
        return "\(applications) apps, \(categories) categories, \(websites) websites selected"
    }
}

struct RoutineProgressHeader: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Brush → Sleep")
                .font(.headline)
            ProgressView(value: progress, total: 1)
        }
    }
}

struct RootView: View {
    @Environment(SleepyStore.self) private var store
    @Environment(ShieldClient.self) private var shield
    @State private var alertMessage = ""
    @State private var isShowingAlert = false
    @State private var isShowingEndEarlyConfirmation = false
    @State private var isPickerPresented = false
    @State private var hasSelectionDraft = false
    @State private var holdsCompletedProgress = false
    @State private var draftSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var draftBedtime = Date.now
    @State private var draftWakeTime = Date.now
    let notifications: NotificationClient

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if displayedStage != .sleepActive {
                    RoutineProgressHeader(progress: store.routineProgress)
                        .padding()
                }
                ScrollView {
                    VStack(spacing: 24) {
                        stageContent
                        if let recoveryMessage = store.recoveryMessage {
                            inlineMessage(recoveryMessage)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
        }
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $draftSelection)
        .confirmationDialog(
            "End Sleep Sanctuary early?",
            isPresented: $isShowingEndEarlyConfirmation,
            titleVisibility: .visible
        ) {
            Button("End early", role: .destructive) { endEarly() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Distracting apps will stop being blocked, and no sleep completion reward will be granted.")
        }
        .alert("Sleepy couldn't finish that action", isPresented: $isShowingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch displayedStage {
        case .onboarding:
            onboarding
        case .home:
            home
        case .brushing:
            brushing
        case .startSleep:
            startSleep
        case .sleepActive:
            activeSleep
        case .summary:
            summary
        case .settings:
            settings
        }
    }

    private var onboarding: some View {
        VStack(spacing: 16) {
            Text("Sleepy").font(.largeTitle)
            scheduleAndPermissions(allowsClearSelection: false)
            Button("Finish setup") {
                Task { await saveSchedule(finishingOnboarding: true) }
            }
            .buttonStyle(.borderedProminent)
        }
        .onAppear { loadScheduleDraft() }
    }

    private var home: some View {
        VStack(spacing: 24) {
            HStack {
                stat("Streak", "\(store.streak)")
                stat("XP", "\(store.xp)")
                stat("Coins", "\(store.coins)")
            }
            Text("Next bedtime").font(.headline)
            Text(nextBedtime.formatted(date: .abbreviated, time: .shortened))
                .font(.title2)
            Text(homeReadinessMessage)
                .multilineTextAlignment(.center)
            Button(primaryActionTitle) { primaryAction() }
                .buttonStyle(.borderedProminent)
            Button("Settings") { store.showSettings() }
        }
    }

    private var brushing: some View {
        VStack(spacing: 16) {
            Text("Brush your teeth").font(.title)
            Button("Done brushing") {
                perform { try store.finishBrushing() }
            }
            .buttonStyle(.borderedProminent)
            Button("Skip tonight") {
                perform { try store.skipBrushing(at: .now, calendar: .current) }
            }
        }
    }

    private var startSleep: some View {
        VStack(spacing: 16) {
            Text("Start Sleep Sanctuary").font(.title)
            Text(startSleepMessage)
                .multilineTextAlignment(.center)
            Button("Start Sleep Sanctuary") { startSleepNow() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var activeSleep: some View {
        VStack(spacing: 16) {
            Text("Sleep Sanctuary is active").font(.title)
            Text("Scheduled wake time")
                .font(.headline)
            Text((store.session?.scheduledWakeTime ?? store.wakeTime), style: .time)
                .font(.title2)
            Text(store.shieldStatusMessage)
                .multilineTextAlignment(.center)
            Button("End early", role: .destructive) {
                isShowingEndEarlyConfirmation = true
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Text("Morning Summary").font(.title)
            Text(store.session?.endedEarly == true
                ? "Sleep Sanctuary ended early. No sleep completion reward was granted."
                : "Sleep Sanctuary reached your planned wake time.")
                .multilineTextAlignment(.center)
            HStack {
                stat("Streak", "\(store.streak)")
                stat("XP", "\(store.xp)")
                stat("Coins", "\(store.coins)")
            }
            Button("Back home") { store.resetToHome() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var settings: some View {
        VStack(spacing: 16) {
            Text("Settings").font(.title)
            scheduleAndPermissions(allowsClearSelection: true)
            HStack {
                Button("Cancel") {
                    cancelSelection()
                    store.showHome()
                }
                Button("Save settings") {
                    Task { await saveSchedule(finishingOnboarding: false) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear { loadScheduleDraft() }
    }

    private func scheduleAndPermissions(allowsClearSelection: Bool) -> some View {
        VStack(spacing: 16) {
            DatePicker("Bedtime", selection: $draftBedtime, displayedComponents: .hourAndMinute)
            DatePicker("Wake time", selection: $draftWakeTime, displayedComponents: .hourAndMinute)
            permissionRow(title: "Notifications", state: store.settings.notificationPermission) {
                notificationPermissionAction(for: store.settings.notificationPermission)
            }
            permissionRow(title: "Screen Time", state: store.settings.screenTimePermission) {
                screenTimePermissionAction(for: store.settings.screenTimePermission)
            }
            Text(selectionText)
                .frame(maxWidth: .infinity, alignment: .leading)
            if store.settings.screenTimePermission == .approved {
                Button("Choose distracting apps") { beginSelectingApps() }
            }
            if hasSelectionDraft {
                HStack {
                    Button("Cancel selection") { cancelSelection() }
                    Button("Save selection") { saveSelection() }
                        .buttonStyle(.borderedProminent)
                }
            }
            if allowsClearSelection && hasSelection {
                Button("Clear selection", role: .destructive) { clearSelection() }
            }
            if store.selectionNeedsRepair {
                inlineMessage("Saved app selection couldn't be restored. Choose distracting apps again.")
            }
        }
    }

    private func permissionRow<Action: View>(
        title: String,
        state: PermissionState,
        @ViewBuilder action: () -> Action
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(state.label).foregroundStyle(.secondary)
            }
            action()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func notificationPermissionAction(for state: PermissionState) -> some View {
        switch state {
        case .unknown:
            Button("Allow notifications") { requestNotificationPermission() }
        case .denied:
            Button("Open System Settings") { openSystemSettings() }
        case .approved, .unavailable:
            EmptyView()
        }
    }

    @ViewBuilder
    private func screenTimePermissionAction(for state: PermissionState) -> some View {
        switch state {
        case .unknown:
            Button("Allow Screen Time") { requestScreenTimePermission() }
        case .denied:
            Button("Open System Settings") { openSystemSettings() }
        case .approved, .unavailable:
            EmptyView()
        }
    }

    private var displayedStage: AppStage {
        holdsCompletedProgress ? .startSleep : store.stage
    }

    private var hasSelection: Bool {
        !store.activitySelection.applicationTokens.isEmpty
            || !store.activitySelection.categoryTokens.isEmpty
            || !store.activitySelection.webDomainTokens.isEmpty
    }

    private var selectionText: String {
        ActivitySelectionSummary.text(
            applications: store.activitySelection.applicationTokens.count,
            categories: store.activitySelection.categoryTokens.count,
            websites: store.activitySelection.webDomainTokens.count
        )
    }

    private var homeReadinessMessage: String {
        HomeReadiness.message(
            notification: store.settings.notificationPermission,
            screenTime: store.settings.screenTimePermission,
            hasSelection: hasSelection
        )
    }

    private var startSleepMessage: String {
        guard store.settings.screenTimePermission == .approved else {
            return "Screen Time access is unavailable, so distracting apps will not be blocked."
        }
        return hasSelection
            ? "Selected distracting apps will be shielded until wake time."
            : "No distracting apps are selected, so nothing will be blocked."
    }

    private var nextBedtime: Date {
        SleepSchedule.currentOrNext(
            at: .now,
            bedtime: store.bedtime,
            wakeTime: store.wakeTime
        ).start
    }

    private var primaryActionTitle: String {
        if store.sleepStatus == .active { return "View Sleep Sanctuary" }
        if store.sleepStatus == .completed || store.sleepStatus == .ended {
            return "View morning summary"
        }
        if store.brushingStatus == .done || store.brushingStatus == .skipped {
            return "Continue bedtime routine"
        }
        return "Start brushing"
    }

    private func primaryAction() {
        if store.sleepStatus == .active {
            store.stage = .sleepActive
        } else if store.sleepStatus == .completed || store.sleepStatus == .ended {
            store.stage = .summary
        } else if store.brushingStatus == .done || store.brushingStatus == .skipped {
            store.stage = .startSleep
        } else {
            perform { try store.beginBrushing() }
        }
    }

    private func startSleepNow() {
        holdsCompletedProgress = true
        do {
            try store.startSleep(shield: shield)
            Task { @MainActor in
                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                }
                holdsCompletedProgress = false
            }
        } catch {
            holdsCompletedProgress = false
            show(error)
        }
    }

    private func endEarly() {
        perform { try store.endEarly(shield: shield) }
    }

    private func requestNotificationPermission() {
        Task {
            _ = await notifications.requestPermission()
            await store.activate(notifications: notifications, shield: shield)
        }
    }

    private func requestScreenTimePermission() {
        Task {
            _ = await shield.requestAuthorization()
            await store.activate(notifications: notifications, shield: shield)
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            showMessage("System Settings couldn't be opened.")
            return
        }
        Task {
            if await UIApplication.shared.open(url) == false {
                showMessage("System Settings couldn't be opened.")
            }
        }
    }

    private func beginSelectingApps() {
        draftSelection = store.activitySelection
        hasSelectionDraft = true
        isPickerPresented = true
    }

    private func saveSelection() {
        perform {
            try store.saveSelection(draftSelection)
            hasSelectionDraft = false
        }
    }

    private func cancelSelection() {
        draftSelection = store.activitySelection
        hasSelectionDraft = false
    }

    private func clearSelection() {
        perform {
            try store.saveSelection(FamilyActivitySelection(includeEntireCategory: true))
            draftSelection = store.activitySelection
            hasSelectionDraft = false
        }
    }

    private func loadScheduleDraft() {
        draftBedtime = store.bedtime
        draftWakeTime = store.wakeTime
    }

    private func saveSchedule(finishingOnboarding: Bool) async {
        do {
            if finishingOnboarding {
                try store.updateSettings(targetBedtime: draftBedtime, wakeTime: draftWakeTime)
                try await store.finishOnboarding(notifications: notifications)
                cancelSelection()
            } else {
                try await store.updateSchedule(
                    bedtime: draftBedtime,
                    wakeTime: draftWakeTime,
                    notifications: notifications
                )
                cancelSelection()
                store.showHome()
            }
        } catch {
            show(error)
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            show(error)
        }
    }

    private func show(_ error: Error) {
        showMessage(error.localizedDescription)
    }

    private func showMessage(_ message: String) {
        alertMessage = message
        isShowingAlert = true
    }

    private func inlineMessage(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title2)
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}

private extension PermissionState {
    var label: String {
        switch self {
        case .unknown: "Unknown"
        case .approved: "Allowed"
        case .denied: "Denied"
        case .unavailable: "Unavailable"
        }
    }
}

#Preview {
    RootView(notifications: NotificationClient())
        .environment(SleepyStore())
        .environment(ShieldClient())
}
