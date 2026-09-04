import Foundation
import HealthCore

/// Historikus feltöltés + inkrementális szinkron a `HealthDataSource` protokollra építve
/// (nem közvetlenül HealthKit-re — újrafuttatható bármelyik implementációval, tesztben az
/// `InMemoryHealthDataSource`-szal is).
///
/// V0 egyszerűsítés: nincs valódi `HKAnchoredObjectQuery`-alapú anchor. Az inkrementális szinkron
/// a `SyncState.lastSampleEnd`-től mostanáig kér le mindent újra — a `MetricStore` dedup-ja
/// (`.unique` a `hkUUID`-n) miatt ez helyes, csak nem a leghatékonyabb. Optimalizálás (valódi anchor)
/// az F fázisban, ha a re-query túl lassúnak bizonyul.
public actor SyncCoordinator {

    private let source: any HealthDataSource
    private let store: MetricStore

    public init(source: any HealthDataSource, store: MetricStore) {
        self.source = source
        self.store = store
    }

    /// Egyszeri historikus feltöltés `days` napra visszamenőleg minden V0 metrikára + alvás + edzés.
    public func backfill(days: Int = 90, calendar: Calendar = .current) async {
        let end = Date()
        guard let start = calendar.date(byAdding: .day, value: -days, to: end) else { return }
        await syncAllMetrics(from: start, to: end, trigger: "backfill")
        await syncSleepAndWorkouts(from: start, to: end)
    }

    /// A legutóbbi szinkron óta eltelt új adatok — metrikánként a saját `lastSampleEnd`-jétől.
    public func incrementalSync(calendar: Calendar = .current) async {
        let end = Date()
        for metric in MetricType.v0ReadSet where !metric.isCategoryType {
            let snapshot = try? await store.syncStateSnapshot(for: metric)
            let start = snapshot?.lastSampleEnd
                ?? calendar.date(byAdding: .day, value: -1, to: end)
                ?? end
            await sync(metric: metric, from: start, to: end, trigger: "incremental")
        }

        let sleepSnapshot = try? await store.syncStateSnapshot(for: .sleepAnalysis)
        let sleepStart = sleepSnapshot?.lastSampleEnd
            ?? calendar.date(byAdding: .day, value: -1, to: end)
            ?? end
        await syncSleepAndWorkouts(from: sleepStart, to: end)
    }

    // MARK: - private

    private func syncAllMetrics(from start: Date, to end: Date, trigger: String) async {
        for metric in MetricType.v0ReadSet where !metric.isCategoryType {
            await sync(metric: metric, from: start, to: end, trigger: trigger)
        }
    }

    private func sync(metric: MetricType, from start: Date, to end: Date, trigger: String) async {
        do {
            let samples = try await source.samples(for: metric, from: start, to: end)
            try await store.save(samples)

            let dailyStats = try await source.dailyStats(for: metric, from: start, to: end)
            try await store.save(dailyStats)

            let newestEnd = samples.map(\.end).max()
            try await store.updateSyncState(for: metric, lastRunAt: Date(), lastSampleEnd: newestEnd)
            try await store.logSync(
                typeRaw: metric.rawValue, syncedAt: Date(), newestSampleEnd: newestEnd,
                newCount: samples.count, trigger: trigger
            )
        } catch {
            // V0: csendben kihagyjuk — a DebugView (F/G fázis) majd felszínre hozza a hibát.
        }
    }

    private func syncSleepAndWorkouts(from start: Date, to end: Date) async {
        if let sessions = try? await source.sleepSessions(from: start, to: end) {
            try? await store.save(sessions)
            try? await store.updateSyncState(for: .sleepAnalysis, lastRunAt: Date(), lastSampleEnd: end)
        }
        if let workouts = try? await source.workouts(from: start, to: end) {
            try? await store.save(workouts)
        }
    }
}
