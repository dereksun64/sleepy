import SwiftData
import SwiftUI

@main
struct SleepyApp: App {
    @State private var store = SleepyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(for: [
            UserSettings.self,
            SleepSession.self,
            ProgressProfile.self
        ])
    }
}
