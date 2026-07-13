import XCTest
@testable import Sleepy

final class SleepyStoreTests: XCTestCase {
    func testSnoozeStopsAtThree() {
        let store = SleepyStore()

        XCTAssertTrue(store.snooze())
        XCTAssertTrue(store.snooze())
        XCTAssertTrue(store.snooze())
        XCTAssertFalse(store.snooze())
        XCTAssertEqual(store.snoozeCount, 3)
    }

    func testBrushThenEndEarlyAwardsOnlyBrushing() {
        let store = SleepyStore()

        store.doneBrushing()
        store.startSleep()
        store.endSleep(endedEarly: true)

        XCTAssertEqual(store.xp, 10)
        XCTAssertEqual(store.coins, 2)
        XCTAssertEqual(store.streak, 0)
        XCTAssertEqual(store.stage, .summary)
    }

    func testCompletedSleepAwardsFullProgress() {
        let store = SleepyStore()

        store.doneBrushing()
        store.startSleep()
        store.endSleep(endedEarly: false)

        XCTAssertEqual(store.xp, 60)
        XCTAssertEqual(store.coins, 12)
        XCTAssertEqual(store.streak, 1)
        XCTAssertEqual(store.stage, .summary)
    }
}
