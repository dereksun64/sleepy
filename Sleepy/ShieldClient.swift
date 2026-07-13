import Foundation
import Observation

#if canImport(ManagedSettings)
import ManagedSettings
#endif

@Observable
final class ShieldClient {
    private(set) var isActive = false

    #if canImport(ManagedSettings) && !targetEnvironment(simulator)
    private let store = ManagedSettingsStore()
    #endif

    func applyMockShield() {
        isActive = true
    }

    func applyRealShieldIfAvailable() {
        #if targetEnvironment(simulator)
        applyMockShield()
        #else
        isActive = true
        // ponytail: real FamilyActivitySelection token wiring waits until device entitlement testing.
        #endif
    }

    func clearShield() {
        #if canImport(ManagedSettings) && !targetEnvironment(simulator)
        store.clearAllSettings()
        #endif
        isActive = false
    }
}
