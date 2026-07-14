import FamilyControls
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
}
