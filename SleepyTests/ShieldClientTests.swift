import XCTest
@testable import Sleepy

final class ShieldClientTests: XCTestCase {
    func testMockShieldApplyAndClear() {
        let shield = ShieldClient()

        shield.applyMockShield()
        XCTAssertTrue(shield.isActive)

        shield.clearShield()
        XCTAssertFalse(shield.isActive)
    }
}
