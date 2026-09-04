import XCTest
@testable import HealthCore

final class DailyAggregatorTests: XCTestCase {

    // 2026-01-01 00:00:00 UTC
    private let day0 = Date(timeIntervalSince1970: 1_767_225_600)
    private var utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func at(day: Int, hour: Int, _ metric: MetricType, _ value: Double) -> MetricSample {
        let t = day0.addingTimeInterval(TimeInterval(day * 86_400 + hour * 3_600))
        return MetricSample(id: UUID().uuidString, type: metric, value: value, start: t, end: t)
    }

    func testCumulativeSumsPerDayWithEmptyDayInMiddle() {
        let samples = [
            at(day: 0, hour: 8,  .stepCount, 1000),
            at(day: 0, hour: 18, .stepCount, 2500),
            // day 1: nothing
            at(day: 2, hour: 9,  .stepCount, 500),
        ]
        let stats = DailyAggregator.aggregate(
            samples, metric: .stepCount,
            from: day0, to: day0.addingTimeInterval(3 * 86_400), calendar: utc
        )
        XCTAssertEqual(stats.count, 3)
        XCTAssertEqual(stats[0].sum, 3500)
        XCTAssertEqual(stats[0].count, 2)
        XCTAssertNil(stats[0].average)
        XCTAssertTrue(stats[1].isEmpty)
        XCTAssertEqual(stats[1].count, 0)
        XCTAssertNil(stats[1].sum)
        XCTAssertEqual(stats[2].sum, 500)
        XCTAssertEqual(stats[0].primaryValue, 3500)
    }

    func testDiscreteAverageMinMax() {
        let samples = [
            at(day: 0, hour: 1, .heartRate, 50),
            at(day: 0, hour: 2, .heartRate, 60),
            at(day: 0, hour: 3, .heartRate, 70),
        ]
        let stats = DailyAggregator.aggregate(
            samples, metric: .heartRate,
            from: day0, to: day0.addingTimeInterval(86_400), calendar: utc
        )
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].average, 60)
        XCTAssertEqual(stats[0].min, 50)
        XCTAssertEqual(stats[0].max, 70)
        XCTAssertNil(stats[0].sum)
        XCTAssertEqual(stats[0].primaryValue, 60)
    }

    func testEndIsExclusiveAndOutOfRangeExcluded() {
        let end = day0.addingTimeInterval(86_400)
        let samples = [
            at(day: -1, hour: 12, .heartRate, 99),   // before range
            MetricSample(id: "x", type: .heartRate, value: 42, start: end, end: end), // exactly at end
            at(day: 0, hour: 12, .heartRate, 55),
        ]
        let stats = DailyAggregator.aggregate(samples, metric: .heartRate, from: day0, to: end, calendar: utc)
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].count, 1)
        XCTAssertEqual(stats[0].average, 55)
    }

    func testEmptyRangeYieldsNoDays() {
        let stats = DailyAggregator.aggregate([], metric: .heartRate, from: day0, to: day0, calendar: utc)
        XCTAssertTrue(stats.isEmpty)
    }

    func testDaysCoverPartialStart() {
        // start mid-day → az a nap teljesen bekerül
        let start = day0.addingTimeInterval(15 * 3_600)
        let stats = DailyAggregator.aggregate(
            [at(day: 0, hour: 20, .stepCount, 10)],
            metric: .stepCount, from: start, to: day0.addingTimeInterval(2 * 86_400), calendar: utc
        )
        XCTAssertEqual(stats.count, 2)
        XCTAssertEqual(stats[0].day, day0)          // éjfélre igazítva
        XCTAssertEqual(stats[0].sum, 10)
    }
}
