import Foundation
import HealthKit
import HealthCore

/// `HealthDataSource` HealthKit-tel. Csak fizikai iOS eszközön ad valós adatot.
public actor HealthKitAdapter: HealthDataSource {

    private let store = HKHealthStore()

    public init() {}

    public nonisolated var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Engedély

    public func requestAuthorization(for metrics: [MetricType]) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthDataError.notAvailable }
        do {
            try await store.requestAuthorization(toShare: [], read: HealthKitReadSet.types(for: metrics))
        } catch {
            throw HealthDataError.authorizationFailed(error.localizedDescription)
        }
    }

    public func authorizationRequestStatus(for metrics: [MetricType]) async -> AuthorizationRequestStatus {
        guard HKHealthStore.isHealthDataAvailable() else { return .unknown }
        do {
            let status = try await store.statusForAuthorizationRequest(
                toShare: [], read: HealthKitReadSet.types(for: metrics)
            )
            switch status {
            case .unknown:       return .unknown
            case .shouldRequest: return .shouldRequest
            case .unnecessary:   return .unnecessary
            @unknown default:    return .unknown
            }
        } catch {
            return .unknown
        }
    }

    // MARK: - Lekérdezés

    public func latestSample(for metric: MetricType) async throws -> MetricSample? {
        try await runSampleQuery(for: metric, predicate: nil, limit: 1, ascending: false).first
    }

    public func samples(for metric: MetricType, from start: Date, to end: Date) async throws -> [MetricSample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
        return try await runSampleQuery(
            for: metric, predicate: predicate, limit: HKObjectQueryNoLimit, ascending: true
        )
    }

    public func dailyStats(
        for metric: MetricType,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) async throws -> [DailyStat] {
        // V0: a mintákból aggregálunk a HealthCore referenciájával.
        // Később: HKStatisticsCollectionQuery (pontosabb az éjfélen átnyúló mintáknál).
        let s = try await samples(for: metric, from: start, to: end)
        return DailyAggregator.aggregate(s, metric: metric, from: start, to: end, calendar: calendar)
    }

    // MARK: - private

    private func runSampleQuery(
        for metric: MetricType,
        predicate: NSPredicate?,
        limit: Int,
        ascending: Bool
    ) async throws -> [MetricSample] {
        guard let sampleType = metric.hkSampleType else {
            throw HealthDataError.unsupportedMetric(metric)
        }
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: ascending)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: sort
            ) { _, hkSamples, error in
                if let error {
                    continuation.resume(throwing: HealthDataError.queryFailed(error.localizedDescription))
                    return
                }
                // A HKSample nem Sendable → itt, a handlerben mappeljük Sendable MetricSample-re.
                let mapped = (hkSamples ?? []).compactMap { MetricSample(hkSample: $0, metric: metric) }
                continuation.resume(returning: mapped)
            }
            store.execute(query)
        }
    }
}
