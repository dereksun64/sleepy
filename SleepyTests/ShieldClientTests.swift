import FamilyControls
import ManagedSettings
import SwiftData
import XCTest
@testable import Sleepy

@MainActor
final class ShieldClientTests: XCTestCase {
    func testEmptySelectionRoundTrips() throws {
        let selection = FamilyActivitySelection(includeEntireCategory: true)
        let data = try ShieldClient.encode(selection)
        XCTAssertEqual(try ShieldClient.decode(data), selection)
    }

    func testInvalidSelectionDataThrows() {
        XCTAssertThrowsError(try ShieldClient.decode(Data([0xFF])))
    }

    func testMockApplyAndRepeatedClearAreSafe() throws {
        let client = ShieldClient(mocked: true)

        client.applyMockShield()
        XCTAssertTrue(client.isActive)
        client.clearShield()
        client.clearShield()
        XCTAssertFalse(client.isActive)
    }

    func testNormalClientDoesNotReportSimulatorMockStateAsActive() {
        let managedStore = makeManagedStore()
        let client = ShieldClient(store: managedStore)

        client.applyRealShieldIfAvailable()

        XCTAssertFalse(client.isActive)
    }

    func testUnshieldedApplyClearsStaleNamedStoreSettings() {
        let managedStore = makeManagedStore()
        managedStore.shield.applicationCategories = .all()
        let client = ShieldClient(store: managedStore)

        let result = client.apply(
            selection: FamilyActivitySelection(includeEntireCategory: true),
            interval: DateInterval(start: .now, duration: 60)
        )

        guard case .unshielded = result else {
            return XCTFail("Expected an unshielded result")
        }
        XCTAssertFalse(client.isActive)
    }

    func testSelectionPersistsAcrossRelaunch() throws {
        let container = try makeContainer()
        let store = SleepyStore()
        try store.configure(modelContext: ModelContext(container))
        let selection = FamilyActivitySelection(includeEntireCategory: true)

        try store.saveSelection(selection)
        XCTAssertFalse(store.settings.activitySelectionData.isEmpty)

        let relaunched = SleepyStore()
        try relaunched.configure(modelContext: ModelContext(container))
        XCTAssertEqual(relaunched.activitySelection, selection)
        XCTAssertFalse(relaunched.selectionNeedsRepair)
    }

    func testCorruptSelectionIsRepairedOnRelaunch() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let store = SleepyStore()
        try store.configure(modelContext: context)
        store.settings.activitySelectionData = Data([0xFF])
        try context.save()

        let relaunched = SleepyStore()
        try relaunched.configure(modelContext: ModelContext(container))

        XCTAssertEqual(
            relaunched.activitySelection,
            FamilyActivitySelection(includeEntireCategory: true)
        )
        XCTAssertTrue(relaunched.selectionNeedsRepair)
        XCTAssertTrue(relaunched.settings.activitySelectionData.isEmpty)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: UserSettings.self, SleepSession.self, ProgressProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeManagedStore() -> ManagedSettingsStore {
        let store = ManagedSettingsStore(
            named: ManagedSettingsStore.Name("test-\(UUID().uuidString)")
        )
        store.clearAllSettings()
        return store
    }
}
