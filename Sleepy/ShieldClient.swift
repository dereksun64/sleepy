import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import Observation

enum ShieldStartResult: Equatable {
    case shielded
    case unshielded(String)
}

@Observable
final class ShieldClient {
    private let store: ManagedSettingsStore
    private let center: DeviceActivityCenter
    private let mocked: Bool
    private var mockIsActive = false

    init(
        store: ManagedSettingsStore = ManagedSettingsStore(named: ScreenTimeNames.store),
        center: DeviceActivityCenter = DeviceActivityCenter(),
        mocked: Bool = false
    ) {
        self.store = store
        self.center = center
        self.mocked = mocked
    }

    var authorizationStatus: PermissionState {
        #if targetEnvironment(simulator)
        return .unavailable
        #else
        let status = AuthorizationCenter.shared.authorizationStatus
        if #available(iOS 26.4, *) {
            switch status {
            case .approved, .approvedWithDataAccess: return .approved
            case .denied: return .denied
            case .notDetermined: return .unknown
            @unknown default: return .unavailable
            }
        }
        if status == .approved { return .approved }
        if status == .denied { return .denied }
        if status == .notDetermined { return .unknown }
        return .unavailable
        #endif
    }

    var isActive: Bool {
        if mocked { return mockIsActive }
        return store.shield.applications?.isEmpty == false
            || store.shield.webDomains?.isEmpty == false
            || store.shield.applicationCategories != nil
    }

    static func encode(_ selection: FamilyActivitySelection) throws -> Data {
        try PropertyListEncoder().encode(selection)
    }

    static func decode(_ data: Data) throws -> FamilyActivitySelection {
        guard !data.isEmpty else {
            return FamilyActivitySelection(includeEntireCategory: true)
        }
        return try PropertyListDecoder().decode(FamilyActivitySelection.self, from: data)
    }

    func requestAuthorization() async -> PermissionState {
        #if targetEnvironment(simulator)
        return .unavailable
        #else
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            return authorizationStatus
        } catch {
            return authorizationStatus
        }
        #endif
    }

    func apply(
        selection: FamilyActivitySelection,
        interval: DateInterval,
        calendar: Calendar = .current
    ) -> ShieldStartResult {
        store.clearAllSettings()
        guard authorizationStatus == .approved else {
            return .unshielded(
                "Screen Time access is unavailable, so distracting apps are not being blocked."
            )
        }
        guard !selection.applicationTokens.isEmpty
                || !selection.categoryTokens.isEmpty
                || !selection.webDomainTokens.isEmpty else {
            return .unshielded("No distracting apps are selected, so nothing is being blocked.")
        }

        store.shield.applications = selection.applicationTokens.isEmpty
            ? nil
            : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty
            ? nil
            : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty
            ? nil
            : selection.webDomainTokens

        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: interval.start
            ),
            intervalEnd: calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: interval.end
            ),
            repeats: false
        )
        do {
            center.stopMonitoring([ScreenTimeNames.activity])
            try center.startMonitoring(ScreenTimeNames.activity, during: schedule)
            return isActive
                ? .shielded
                : .unshielded("Screen Time did not apply the selected shields.")
        } catch {
            clearShield()
            return .unshielded(
                "Automatic wake-time clearing could not be scheduled, so Sleepy removed the shield."
            )
        }
    }

    func clearShield() {
        mockIsActive = false
        guard !mocked else { return }
        center.stopMonitoring([ScreenTimeNames.activity])
        store.clearAllSettings()
    }

    func applyRealShieldIfAvailable() {
        #if targetEnvironment(simulator)
        mockIsActive = true
        #endif
    }

    func applyMockShield() {
        guard mocked else { return }
        mockIsActive = true
    }
}
