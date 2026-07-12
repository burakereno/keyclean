import XCTest
@testable import KeyClean

final class PopoverLayoutTests: XCTestCase {
    func testPreferredHeightIsKeptWithinVisibleScreenBounds() {
        XCTAssertEqual(
            KeyCleanPopoverLayout.clampedHeight(420, visibleScreenHeight: 900),
            420
        )
        XCTAssertEqual(
            KeyCleanPopoverLayout.clampedHeight(120, visibleScreenHeight: 900),
            KeyCleanPopoverLayout.minimumHeight
        )
        XCTAssertEqual(
            KeyCleanPopoverLayout.clampedHeight(900, visibleScreenHeight: 600),
            600 - KeyCleanPopoverLayout.screenEdgeMargin
        )
    }
}
