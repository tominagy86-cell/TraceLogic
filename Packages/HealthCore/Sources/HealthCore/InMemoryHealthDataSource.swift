import Foundation

/// Memóriában tartott `HealthDataSource` — unit tesztekhez és SwiftUI preview-khoz.
/// Nem HealthKit; determinisztikus.
public actor InMemoryHealthDataSource: HealthDataSource {

    private var samplesByType: [MetricType: [MetricSample]]
    private var authorizedMetrics: Set<MetricType>
    private let available: Bool
    private var sleepSegmentsStore: [SleepSegment] = []
    private var workoutsStore: [WorkoutSummary] = []

    public init(
        samples: [MetricType: [MetricSample]] = [:],
        authorized: Set<MetricType> = [],
        isAvailable: Bool = true
    ) {
        self.samplesByType = samples
        self.authorizedMetrics = authorized
        self.available = isAvailable
    }

    public nonisolated var isAvailable: Bool { available }

    // MARK: - Beállítók (teszthez)

    public func setSamples(_ samples: [MetricSample], for metric: MetricType) {
        samplesByType[metric] = samples.sorted { $0.start < $1.start }
    }

    public func add(_ sample: MetricSample) {
        samplesByType[sample.type, default: []].append(sample)
        samplesByType[sample.type]?.sort { $0.start < $1.start }
    }

    public func setSleepSegments(_ segments: [SleepSegment]) {
        sleepSegmentsStore = segments
    }

    public func setWorkouts(_ workouts: [WorkoutSummary]) {
        workoutsStore = workouts.sorted { $0.start < $1.start }
    }

    // MARK: - HealthDataSource

    public func requestAuthorization(for metrics: [MetricType]) async throws {
        guard available else { throw HealthDataError.notAvailable }
        authorizedMetrics.formUnion(metrics)
    }

    public func authorizationRequestStatus(for metrics: [MetricType]) async -> AuthorizationRequestStatus {
        guard available else { return .unknown }
        return authorizedMetrics.isSuperset(of: metrics) ? .unnecessary : .shouldRequest
    }

    public func latestSample(for metric: MetricType) async throws -> MetricSample? {
        (samplesByType[metric] ?? []).max { $0.start < $1.start }
    }

    public func samples(for metric: MetricType, from start: Date, to end: Date) async throws -> [MetricSample] {
        guard end > start else { return [] }
        return (samplesByType[metric] ?? [])
            .filter { $0.start >= start && $0.start < end }
            .sorted { $0.start < $1.start }
    }

    public func dailyStats(
        for metric: MetricType,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) async throws -> [DailyStat] {
        let s = try await samples(for: metric, from: start, to: end)
        return DailyAggregator.aggregate(s, metric: metric, from: start, to: end, calendar: calendar)
    }

    public func sleepSessions(from start: Date, to end: Date, calendar: Calendar) async throws -> [SleepSession] {
        guard end > start else { return [] }
        let inRange = sleepSegmentsStore.filter { $0.start >= start && $0.start < end }
        return SleepSessionBuilder.build(from: inRange, calendar: calendar)
    }

    public func workouts(from start: Date, to end: Date) async throws -> [WorkoutSummary] {
        guard end > start else { return [] }
        return workoutsStore
            .filter { $0.start >= start && $0.start < end }
            .sorted { $0.start > $1.start }
    }
}
