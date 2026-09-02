import XCTest
@testable import TraceLogic

final class AppSmokeTests: XCTestCase {
    func testBrandingIsSet() {
        XCTAssertFalse(Branding.appName.isEmpty)
    }
}
