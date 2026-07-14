import SwiftData
import SwiftUI

@main
struct SleepyApp: App {
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
            RootView(notifications: notifications)
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
