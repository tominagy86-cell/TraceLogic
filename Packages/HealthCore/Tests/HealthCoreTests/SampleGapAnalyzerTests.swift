import XCTest
@testable import HealthCore

final class SampleGapAnalyzerTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    private func window(_ seconds: TimeInterval) -> DateInterval {
        DateInterval(start: t0, end: t0.addingTimeInterval(seconds))
    }

    private func sample(_ startOffset: TimeInterval,
                        _ endOffset: TimeInterval,
                        source: String = "Apple Watch") -> MetricSample {
        MetricSample(
            id: UUID().uuidString,
            type: .heartRate,
            value: 60,
            start: t0.addingTimeInterval(startOffset),
            end: t0.addingTimeInterval(endOffset),
            sourceName: source
        )
    }

    func testEmptyWindow() {
        let stats = SampleGapAnalyzer.analyze(samples: [], window: window(3600))
        XCTAssertEqual(stats.sampleCount, 0)
        XCTAssertEqual(stats.coveredDuration, 0)
        XCTAssertEqual(stats.coverageFraction, 0)
        XCTAssertEqual(stats.maxGap, 3600)
        XCTAssertEqual(stats.medianGap, 3600)
    }

    func testTwoSegmentsInOneHour() {
        // [600..900] és [1800..2100] egy 3600 s-os ablakban
        let stats = SampleGapAnalyzer.analyze(
            samples: [sample(600, 900), sample(1800, 2100)],
            window: window(3600)
        )
        XCTAssertEqual(stats.sampleCount, 2)
        XCTAssertEqual(stats.coveredDuration, 600, accuracy: 0.001)          // 300 + 300
        XCTAssertEqual(stats.coverageFraction, 1.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(stats.gaps, [600, 900, 1500])                        // vezető, közti, záró
        XCTAssertEqual(stats.medianGap!, 900, accuracy: 0.001)
        XCTAssertEqual(stats.maxGap!, 1500, accuracy: 0.001)
        XCTAssertEqual(stats.samplesPerHour, 2, accuracy: 0.001)
    }

    func testFullCoverageSingleSample() {
        let stats = SampleGapAnalyzer.analyze(samples: [sample(0, 3600)], window: window(3600))
        XCTAssertEqual(stats.coverageFraction, 1.0, accuracy: 0.0001)
        XCTAssertTrue(stats.gaps.isEmpty)
        XCTAssertNil(stats.maxGap)
    }

    func testOverlappingSegmentsMergeAndClip() {
        // átfedő + ablakon túlnyúló minták
        let stats = SampleGapAnalyzer.analyze(
            samples: [sample(-100, 500), sample(400, 1000)],
            window: window(3600)
        )
        XCTAssertEqual(stats.coveredDuration, 1000, accuracy: 0.001)  // [0..1000] összevonva, elejét vágva
        XCTAssertEqual(stats.gaps, [2600])                           // csak a záró rés
    }

    func testSourceBreakdown() {
        let stats = SampleGapAnalyzer.analyze(
            samples: [
                sample(100, 200, source: "Apple Watch"),
                sample(300, 400, source: "iPhone"),
                sample(500, 600, source: "Apple Watch"),
            ],
            window: window(3600)
        )
        XCTAssertEqual(stats.countBySource["Apple Watch"], 2)
        XCTAssertEqual(stats.countBySource["iPhone"], 1)
    }

    func testPercentileInterpolation() {
        XCTAssertEqual(SampleGapAnalyzer.percentile([10, 20, 30], 0.5)!, 20, accuracy: 0.001)
        XCTAssertEqual(SampleGapAnalyzer.percentile([10, 20, 30, 40], 0.5)!, 25, accuracy: 0.001)
        XCTAssertEqual(SampleGapAnalyzer.percentile([10], 0.9)!, 10, accuracy: 0.001)
        XCTAssertNil(SampleGapAnalyzer.percentile([], 0.5))
    }
}

final class MetricTypeTests: XCTestCase {
    func testEveryTypeHasUnitExceptSleep() {
        for type in MetricType.allCases {
            if type == .sleepAnalysis {
                XCTAssertEqual(type.unit, .none)
            } else {
                XCTAssertNotEqual(type.unit, .none, "\(type) unit hiányzik")
            }
        }
    }

    func testCumulativeClassification() {
        XCTAssertEqual(MetricType.stepCount.aggregation, .cumulative)
        XCTAssertEqual(MetricType.heartRate.aggregation, .discrete)
        XCTAssertEqual(MetricType.sleepAnalysis.aggregation, .none)
    }

    func testV0ReadSetCoversAll() {
        XCTAssertEqual(Set(MetricType.v0ReadSet), Set(MetricType.allCases))
    }
}
