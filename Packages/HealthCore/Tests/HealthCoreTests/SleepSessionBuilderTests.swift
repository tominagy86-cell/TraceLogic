import XCTest
@testable import HealthCore

final class SleepSessionBuilderTests: XCTestCase {

    private var utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    // 2026-01-01 22:00:00 UTC — este elalvás
    private let bedtime = Date(timeIntervalSince1970: 1_767_297_600)

    private func seg(_ offsetMin: Double, _ lengthMin: Double, _ stage: SleepStage,
                      source: String = "Apple Watch", bundle: String = "com.apple.health.watch") -> SleepSegment {
        let start = bedtime.addingTimeInterval(offsetMin * 60)
        return SleepSegment(stage: stage, start: start, end: start.addingTimeInterval(lengthMin * 60),
                             sourceName: source, sourceBundleID: bundle)
    }

    func testCleanNightWithStages() {
        let segments = [
            seg(0, 20, .awake),
            seg(20, 90, .asleepCore),
            seg(110, 60, .asleepDeep),
            seg(170, 40, .asleepREM),
            seg(210, 100, .asleepCore),
        ]
        let sessions = SleepSessionBuilder.build(from: segments, calendar: utc)
        XCTAssertEqual(sessions.count, 1)
        let s = sessions[0]
        XCTAssertEqual(s.coreSeconds, (90 + 100) * 60, accuracy: 1)
        XCTAssertEqual(s.deepSeconds, 60 * 60, accuracy: 1)
        XCTAssertEqual(s.remSeconds, 40 * 60, accuracy: 1)
        XCTAssertEqual(s.awakeSeconds, 20 * 60, accuracy: 1)
        XCTAssertEqual(s.totalAsleepSeconds, (90 + 60 + 40 + 100) * 60, accuracy: 1)
        XCTAssertTrue(s.hasStageDetail)
        XCTAssertEqual(s.primarySource, "Apple Watch")
    }

    func testFragmentedSameStageSums() {
        let segments = [
            seg(0, 10, .asleepCore), seg(10, 5, .asleepCore), seg(15, 30, .asleepCore),
        ]
        let sessions = SleepSessionBuilder.build(from: segments, calendar: utc)
        XCTAssertEqual(sessions[0].coreSeconds, 45 * 60, accuracy: 1)
    }

    func testMultiSourcePreferredWins() {
        let segments = [
            seg(0, 480, .asleepUnspecified, source: "SomeApp", bundle: "com.thirdparty.app"),
            seg(0, 480, .asleepCore, source: "Apple Watch", bundle: "com.apple.health.watch"),
        ]
        let sessions = SleepSessionBuilder.build(
            from: segments, preferredSourceBundleID: "com.apple.health.watch", calendar: utc
        )
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].segments.count, 1)
        XCTAssertEqual(sessions[0].primarySource, "Apple Watch")
    }

    func testNoPreferredSourceKeepsAll() {
        let segments = [
            seg(0, 480, .asleepUnspecified, source: "SomeApp", bundle: "com.thirdparty.app"),
            seg(0, 480, .asleepCore, source: "Apple Watch", bundle: "com.apple.health.watch"),
        ]
        let sessions = SleepSessionBuilder.build(from: segments, calendar: utc)
        XCTAssertEqual(sessions[0].segments.count, 2)
    }

    func testMissingPreferredSourceFallsBackToAll() {
        let segments = [seg(0, 480, .asleepCore, source: "Other", bundle: "com.other")]
        let sessions = SleepSessionBuilder.build(
            from: segments, preferredSourceBundleID: "com.apple.health.watch", calendar: utc
        )
        XCTAssertEqual(sessions[0].segments.count, 1)
    }

    func testNoonNoonBoundaryGroupsEveningAndAfterMidnightTogether() {
        // 22:00 (day D) + 02:00 (day D+1) egy éjszaka
        let evening = SleepSegment(stage: .asleepCore, start: bedtime, end: bedtime.addingTimeInterval(3600))
        let afterMidnight = SleepSegment(
            stage: .asleepREM,
            start: bedtime.addingTimeInterval(5 * 3600),   // 03:00
            end: bedtime.addingTimeInterval(6 * 3600)
        )
        let sessions = SleepSessionBuilder.build(from: [evening, afterMidnight], calendar: utc)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].segments.count, 2)
    }

    func testOnlyUnspecifiedHasNoStageDetail() {
        let sessions = SleepSessionBuilder.build(from: [seg(0, 400, .asleepUnspecified)], calendar: utc)
        XCTAssertFalse(sessions[0].hasStageDetail)
        XCTAssertEqual(sessions[0].totalAsleepSeconds, 400 * 60, accuracy: 1)
    }

    func testEmptyInputYieldsNoSessions() {
        XCTAssertTrue(SleepSessionBuilder.build(from: [], calendar: utc).isEmpty)
    }

    func testTwoSeparateNightsSortedAscending() {
        let night1 = seg(0, 400, .asleepCore)
        let night2 = seg(24 * 60, 400, .asleepCore)   // +1 nap
        let sessions = SleepSessionBuilder.build(from: [night2, night1], calendar: utc)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertLessThan(sessions[0].nightOf, sessions[1].nightOf)
    }
}
