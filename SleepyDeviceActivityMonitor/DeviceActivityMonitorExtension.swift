import DeviceActivity
import ManagedSettings

final class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == ScreenTimeNames.activity else { return }
        ManagedSettingsStore(named: ScreenTimeNames.store).clearAllSettings()
    }
}
