import SwiftData
import SwiftUI

@main
struct SleepyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = SleepyStore()
    @State private var shield = ShieldClient()
    private let notifications: NotificationClient

    init() {
        let notifications = NotificationClient()
        notifications.registerCategories()
        self.notifications = notifications
    }

    var body: some Scene {
        WindowGroup {
            SleepyAppRoot(
                store: store,
                shield: shield,
                notifications: notifications,
                appDelegate: appDelegate
            )
                .environment(store)
                .environment(shield)
        }
        .modelContainer(for: [
            UserSettings.self,
            SleepSession.self,
            ProgressProfile.self
        ])
    }
}

private struct SleepyAppRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    let store: SleepyStore
    let shield: ShieldClient
    let notifications: NotificationClient
    let appDelegate: AppDelegate
    @State private var didLaunch = false

    var body: some View {
        RootView(notifications: notifications)
            .task {
                guard !didLaunch else { return }
                didLaunch = true
                store.configureForLaunch(modelContext: modelContext)
                appDelegate.installResponseHandler { action, requestIdentifier in
                    Task { @MainActor in
                        await store.handleNotificationResponse(
                            action,
                            requestIdentifier: requestIdentifier,
                            notifications: notifications
                        )
                    }
                }
                await store.activate(notifications: notifications, shield: shield)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, store.isConfigured else { return }
                Task { await store.activate(notifications: notifications, shield: shield) }
            }
    }
}
