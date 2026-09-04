import Foundation
import SwiftData
import HealthCore

/// Nem-Sendable pillanatkép egy metrika szinkron-állapotáról — ezt adja vissza a `MetricStore`
/// a `@Model` objektum helyett, hogy biztonságosan átadható legyen más actoroknak (pl. `SyncCoordinator`).
public struct SyncStateSnapshot: Sendable, Equatable {
    public let lastRunAt: Date?
    public let lastSampleEnd: Date?
}

/// SwiftData-alapú lokális tár.
///
/// Dedup: `StoredSample.hkUUID` és `StoredWorkout.hkUUID` `.unique` — új mintáknál update-or-insert,
/// úgyhogy ismételt szinkron nem duplikál. A `@Model` objektumok SOHA nem lépik át ezt az actor-határt —
/// minden publikus API Sendable value type-ot ad vissza/vár (`MetricSample`, `SyncStateSnapshot`, …).
// FIGYELEM (Mac build): a @ModelActor makró generálja az init(modelContainer:)-t; ha nem
// `public`, és külső modulból/target-ből kell hívni, egészítsd ki explicit `public init`-tel.
@ModelActor
public actor MetricStore {

    // MARK: - Minták

    public func save(_ samples: [MetricSample]) throws {
        for sample in samples {
            let id = sample.id
            var descriptor = FetchDescriptor<StoredSample>(predicate: #Predicate { $0.hkUUID == id })
            descriptor.fetchLimit = 1
            if let existing = try modelContext.fetch(descriptor).first {
                existing.value = sample.value
                existing.start = sample.start
                existing.end = sample.end
                existing.sourceName = sample.sourceName
                existing.sourceBundleID = sample.sourceBundleID
            } else {
                modelContext.insert(StoredSample(sample: sample))
            }
        }
        try modelContext.save()
    }

    public func samples(for type: MetricType, from start: Date, to end: Date) throws -> [MetricSample] {
        let typeRaw = type.rawValue
        let descriptor = FetchDescriptor<StoredSample>(
            predicate: #Predicate { $0.typeRaw == typeRaw && $0.start >= start && $0.start < end },
            sortBy: [SortDescriptor(\.start)]
        )
        return try modelContext.fetch(descriptor).compactMap(\.asMetricSample)
    }

    // MARK: - Napi statisztikák

    public func save(_ stats: [DailyStat]) throws {
        for stat in stats {
            let day = stat.day
            let typeRaw = stat.metric.rawValue
            var descriptor = FetchDescriptor<StoredDailyStat>(
                predicate: #Predicate { $0.day == day && $0.typeRaw == typeRaw }
            )
            descriptor.fetchLimit = 1
            if let existing = try modelContext.fetch(descriptor).first {
                existing.count = stat.count
                existing.sum = stat.sum
                existing.average = stat.average
                existing.min = stat.min
                existing.max = stat.max
            } else {
                modelContext.insert(StoredDailyStat(stat: stat))
            }
        }
        try modelContext.save()
    }

    // MARK: - Edzések

    public func save(_ workouts: [WorkoutSummary]) throws {
        for workout in workouts {
            let id = workout.id
            var descriptor = FetchDescriptor<StoredWorkout>(predicate: #Predicate { $0.hkUUID == id })
            descriptor.fetchLimit = 1
            if try modelContext.fetch(descriptor).first == nil {
                modelContext.insert(StoredWorkout(workout: workout))
            }
        }
        try modelContext.save()
    }

    // MARK: - Alvás

    public func save(_ sessions: [SleepSession]) throws {
        for session in sessions {
            let night = session.nightOf
            var descriptor = FetchDescriptor<StoredSleepSession>(predicate: #Predicate { $0.nightOf == night })
            descriptor.fetchLimit = 1
            if let existing = try modelContext.fetch(descriptor).first {
                existing.update(from: session)
            } else {
                modelContext.insert(StoredSleepSession(session: session))
            }
        }
        try modelContext.save()
    }

    // MARK: - Szinkron-állapot

    public func syncStateSnapshot(for type: MetricType) throws -> SyncStateSnapshot {
        let state = try fetchOrCreateSyncState(for: type)
        return SyncStateSnapshot(lastRunAt: state.lastRunAt, lastSampleEnd: state.lastSampleEnd)
    }

    public func updateSyncState(for type: MetricType, lastRunAt: Date, lastSampleEnd: Date?) throws {
        let state = try fetchOrCreateSyncState(for: type)
        state.lastRunAt = lastRunAt
        if let lastSampleEnd { state.lastSampleEnd = lastSampleEnd }
        try modelContext.save()
    }

    public func logSync(typeRaw: String, syncedAt: Date, newestSampleEnd: Date?, newCount: Int, trigger: String) throws {
        modelContext.insert(SyncLogEntry(
            typeRaw: typeRaw, syncedAt: syncedAt, newestSampleEnd: newestSampleEnd,
            newCount: newCount, trigger: trigger
        ))
        try modelContext.save()
    }

    // MARK: - private

    private func fetchOrCreateSyncState(for type: MetricType) throws -> SyncState {
        let typeRaw = type.rawValue
        var descriptor = FetchDescriptor<SyncState>(predicate: #Predicate { $0.typeRaw == typeRaw })
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first { return existing }
        let created = SyncState(typeRaw: typeRaw)
        modelContext.insert(created)
        try modelContext.save()
        return created
    }
}
