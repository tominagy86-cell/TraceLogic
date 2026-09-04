import XCTest
@testable import HealthCore

final class ExportTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_767_225_600)

    private func sample(_ value: Double, source: String = "Apple Watch") -> MetricSample {
        MetricSample(id: "s1", type: .heartRate, value: value, start: t0, end: t0,
                      sourceName: source, sourceBundleID: "com.apple.health")
    }

    // MARK: JSON

    func testJSONRoundTripsSamples() throws {
        let original = [sample(61), sample(65)]
        let data = try JSONExporter.data(original)
        let decoded = try JSONDecoder(dateDecodingStrategy: .iso8601).decode([MetricSample].self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testJSONStringIsValidUTF8AndNonEmpty() throws {
        let s = try JSONExporter.string([sample(61)])
        XCTAssertFalse(s.isEmpty)
        XCTAssertTrue(s.contains("\"heartRate\""))
    }

    func testJSONRoundTripsSleepSession() throws {
        let session = SleepSession(
            nightOf: t0,
            segments: [SleepSegment(stage: .asleepCore, start: t0, end: t0.addingTimeInterval(1800))],
            primarySource: "Apple Watch"
        )
        let data = try JSONExporter.data(session)
        let decoded = try JSONDecoder(dateDecodingStrategy: .iso8601).decode(SleepSession.self, from: data)
        XCTAssertEqual(decoded, session)
    }

    // MARK: CSV

    func testCSVSamplesHasHeaderPlusOneRowPerSample() {
        let csv = CSVExporter.csv(for: [sample(61), sample(65)])
        let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)
        XCTAssertEqual(lines.count, 3)
        XCTAssertTrue(lines[0].hasPrefix("id,type,value"))
    }

    func testCSVEscapesCommaAndQuotes() {
        let csv = CSVExporter.csv(for: [sample(61, source: "My, \"Watch\"")])
        XCTAssertTrue(csv.contains("\"My, \"\"Watch\"\"\""))
    }

    func testCSVDailyStatsFormatsEmptyDayFields() {
        let stat = DailyStat(day: t0, metric: .heartRate, count: 0)
        let csv = CSVExporter.csv(for: [stat])
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines[1].components(separatedBy: ",").count, 7)
        XCTAssertTrue(lines[1].hasSuffix(",,,,"))   // sum,average,min,max mind üres
    }

    func testCSVSleepSessionMinutesConversion() {
        let session = SleepSession(
            nightOf: t0,
            segments: [SleepSegment(stage: .asleepCore, start: t0, end: t0.addingTimeInterval(1800))], // 30 min
            primarySource: "Apple Watch"
        )
        let csv = CSVExporter.csv(for: [session])
        XCTAssertTrue(csv.contains("30.0"))
    }

    func testCSVWorkoutsRoundTripBasicFields() {
        let workout = WorkoutSummary(
            id: "w1", activityTypeRawValue: 37, start: t0, end: t0.addingTimeInterval(3600),
            duration: 3600, activeEnergyKcal: 250, sourceName: "Apple Watch"
        )
        let csv = CSVExporter.csv(for: [workout])
        XCTAssertTrue(csv.contains("w1"))
        XCTAssertTrue(csv.contains("250.0"))
    }
}

private extension JSONDecoder {
    convenience init(dateDecodingStrategy: JSONDecoder.DateDecodingStrategy) {
        self.init()
        self.dateDecodingStrategy = dateDecodingStrategy
    }
}
