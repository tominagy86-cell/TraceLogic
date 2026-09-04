import XCTest
@testable import HealthCore

final class MetricCatalogTests: XCTestCase {

    func testEveryTypeHasNonEmptyDisplayName() {
        for type in MetricType.allCases {
            XCTAssertFalse(MetricCatalog.info(for: type).displayName.isEmpty, "\(type)")
        }
    }

    func testAllCoversEveryTypeExactlyOnce() {
        let types = MetricCatalog.all.map(\.type)
        XCTAssertEqual(Set(types), Set(MetricType.allCases))
        XCTAssertEqual(types.count, MetricType.allCases.count)
    }

    func testAllIsSortedAndSortOrderUnique() {
        let orders = MetricCatalog.all.map(\.sortOrder)
        XCTAssertEqual(orders, orders.sorted())
        XCTAssertEqual(Set(orders).count, orders.count, "sortOrder ütközik")
    }

    func testUnitSymbols() {
        XCTAssertEqual(MetricCatalog.info(for: .heartRate).unitSymbol, "bpm")
        XCTAssertEqual(MetricCatalog.info(for: .heartRateVariabilitySDNN).unitSymbol, "ms")
        XCTAssertEqual(MetricCatalog.info(for: .oxygenSaturation).unitSymbol, "%")
        XCTAssertEqual(MetricCatalog.info(for: .stepCount).unitSymbol, "")
    }

    func testCategoryAndSparseFlags() {
        XCTAssertTrue(MetricCatalog.info(for: .sleepAnalysis).isCategory)
        XCTAssertFalse(MetricCatalog.info(for: .heartRate).isCategory)
        XCTAssertTrue(MetricCatalog.info(for: .vo2Max).isSparse)
        XCTAssertTrue(MetricCatalog.info(for: .heartRateRecoveryOneMinute).isSparse)
        XCTAssertFalse(MetricCatalog.info(for: .stepCount).isSparse)
    }
}
