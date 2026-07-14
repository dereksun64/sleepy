import SwiftUI

struct RootView: View {
    @Environment(SleepyStore.self) private var store
    @Environment(ShieldClient.self) private var shield
    @State private var isShowingScheduleError = false
    @State private var scheduleErrorMessage = ""
    let notifications: NotificationClient

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch store.stage {
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
            .padding()
        }
        .alert("Couldn't schedule reminders", isPresented: $isShowingScheduleError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(scheduleErrorMessage)
        }
    }

    private var onboarding: some View {
        VStack(spacing: 16) {
            Text("Sleepy").font(.largeTitle)
            DatePicker("Bedtime", selection: Bindable(store).bedtime, displayedComponents: .hourAndMinute)
            DatePicker("Wake time", selection: Bindable(store).wakeTime, displayedComponents: .hourAndMinute)
            Button("Allow notifications") {
                Task { _ = await notifications.requestPermission() }
            }
            Text("Shield selection uses mock mode in Simulator.")
            Button("Finish setup") {
                Task { await saveSchedule(finishingOnboarding: true) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var home: some View {
        VStack(spacing: 24) {
            HStack {
                stat("Streak", "\(store.streak)")
                stat("XP", "\(store.xp)")
                stat("Coins", "\(store.coins)")
            }
            ProgressView(value: progress)
            Text("Brush -> Sleep").font(.caption)
            Text("Bedtime").font(.headline)
            Text(store.bedtime, style: .time).font(.title)
            Button(primaryActionTitle) {
                primaryAction()
            }
            .buttonStyle(.borderedProminent)
            Button("Settings") {
                store.stage = .settings
            }
        }
    }

    private var brushing: some View {
        VStack(spacing: 16) {
            Text("Brush your teeth").font(.title)
            Button("Done brushing") { store.doneBrushing() }
                .buttonStyle(.borderedProminent)
            Button("Skip tonight") { store.skipBrushing() }
        }
    }

    private var startSleep: some View {
        VStack(spacing: 16) {
            Text("Start Sleep Sanctuary").font(.title)
            Text("Selected distracting apps will be shielded until wake time.")
                .multilineTextAlignment(.center)
            Button("Start Sleep Sanctuary") {
                shield.applyRealShieldIfAvailable()
                store.startSleep()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var activeSleep: some View {
        VStack(spacing: 16) {
            Text("Sleep Sanctuary is active").font(.title)
            Text(shield.isActive ? "Shield active" : "Shield inactive")
            Button("End early") {
                shield.clearShield()
                store.endSleep(endedEarly: true)
            }
        }
    }

    private var summary: some View {
        VStack(spacing: 16) {
            Text("Morning Summary").font(.title)
            Text("XP: \(store.xp)")
            Text("Coins: \(store.coins)")
            Text("Streak: \(store.streak)")
            Text("Sleep session recorded.")
            Button("Back home") { store.resetToHome() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var settings: some View {
        VStack(spacing: 16) {
            DatePicker("Bedtime", selection: Bindable(store).bedtime, displayedComponents: .hourAndMinute)
            DatePicker("Wake time", selection: Bindable(store).wakeTime, displayedComponents: .hourAndMinute)
            Button("Done") {
                Task { await saveSchedule(finishingOnboarding: false) }
            }
        }
    }

    private var progress: Double {
        var value = 0.0
        if store.brushingStatus == .done || store.brushingStatus == .skipped { value += 0.5 }
        if store.sleepStatus == .ended { value += 0.5 }
        return value
    }

    private var primaryActionTitle: String {
        switch store.stage {
        case .home:
            if store.sleepStatus == .active { return "View Sleep Sanctuary" }
            if store.sleepStatus == .ended { return "View morning summary" }
            if store.brushingStatus == .done || store.brushingStatus == .skipped { return "Start Sleep Sanctuary" }
            return "Start brushing"
        default:
            return "Continue"
        }
    }

    private func primaryAction() {
        if store.sleepStatus == .active {
            store.stage = .sleepActive
        } else if store.sleepStatus == .ended {
            store.stage = .summary
        } else if store.brushingStatus == .done || store.brushingStatus == .skipped {
            store.stage = .startSleep
        } else {
            store.startBrushing()
        }
    }

    private func saveSchedule(finishingOnboarding: Bool) async {
        do {
            if finishingOnboarding {
                try await store.finishOnboarding(notifications: notifications)
            } else {
                try await store.updateSchedule(
                    bedtime: store.bedtime,
                    wakeTime: store.wakeTime,
                    notifications: notifications
                )
                store.showHome()
            }
        } catch {
            scheduleErrorMessage = error.localizedDescription
            isShowingScheduleError = true
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack {
            Text(value).font(.title2)
            Text(title).font(.caption)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RootView(notifications: NotificationClient())
        .environment(SleepyStore())
        .environment(ShieldClient())
}
