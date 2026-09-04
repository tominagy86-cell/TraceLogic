import XCTest
@testable import HealthCore

final class InMemoryHealthDataSourceTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_767_225_600)
    private func s(_ offsetHours: Double, _ value: Double, _ metric: MetricType = .heartRate) -> MetricSample {
        let d = t0.addingTimeInterval(offsetHours * 3600)
        return MetricSample(id: UUID().uuidString, type: metric, value: value, start: d, end: d)
    }

    func testLatestSampleReturnsNewestByStart() async throws {
        let src = InMemoryHealthDataSource()
        await src.setSamples([s(1, 10), s(5, 50), s(3, 30)], for: .heartRate)
        let latest = try await src.latestSample(for: .heartRate)
        XCTAssertEqual(latest?.value, 50)
    }

    func testLatestSampleNilWhenEmpty() async throws {
        let src = InMemoryHealthDataSource()
        let latest = try await src.latestSample(for: .vo2Max)
        XCTAssertNil(latest)
    }

    func testSamplesFilteredHalfOpenAndSorted() async throws {
        let src = InMemoryHealthDataSource()
        await src.setSamples([s(0, 1), s(10, 2), s(20, 3), s(30, 4)], for: .heartRate)
        let out = try await src.samples(
            for: .heartRate,
            from: t0.addingTimeInterval(10 * 3600),
            to: t0.addingTimeInterval(30 * 3600)
        )
        XCTAssertEqual(out.map(\.value), [2, 3])   // 10 bekerül, 30 (end) nem
    }

    func testAuthorizationFlow() async throws {
        let src = InMemoryHealthDataSource()
        var status = await src.authorizationRequestStatus(for: [.heartRate, .stepCount])
        XCTAssertEqual(status, .shouldRequest)
        try await src.requestAuthorization(for: [.heartRate, .stepCount])
        status = await src.authorizationRequestStatus(for: [.heartRate, .stepCount])
        XCTAssertEqual(status, .unnecessary)
        status = await src.authorizationRequestStatus(for: [.heartRate, .sleepAnalysis])
        XCTAssertEqual(status, .shouldRequest)
    }

    func testNotAvailableThrowsAndReportsUnknown() async throws {
        let src = InMemoryHealthDataSource(isAvailable: false)
        XCTAssertFalse(src.isAvailable)
        let status = await src.authorizationRequestStatus(for: [.heartRate])
        XCTAssertEqual(status, .unknown)
        do {
            try await src.requestAuthorization(for: [.heartRate])
            XCTFail("dobnia kellett volna")
        } catch {
            XCTAssertEqual(error as? HealthDataError, .notAvailable)
        }
    }

    func testDailyStatsDelegatesToAggregator() async throws {
        let src = InMemoryHealthDataSource()
        await src.setSamples([s(1, 100, .stepCount), s(2, 200, .stepCount)], for: .stepCount)
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        let stats = try await src.dailyStats(
            for: .stepCount, from: t0, to: t0.addingTimeInterval(86_400), calendar: utc
        )
        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats[0].sum, 300)
    }
}
