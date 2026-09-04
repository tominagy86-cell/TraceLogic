import Foundation
import SwiftData
import HealthCore

// SwiftData perzisztencia-modellek. Lásd docs/v0-plan.md 5. szakasz.
// Csak a Mac-en fordul (SwiftData iOS/macOS-only).

@Model
public final class StoredSample {
    @Attribute(.unique) public var hkUUID: String
    public var typeRaw: String
    public var value: Double
    public var start: Date
    public var end: Date
    public var sourceName: String
    public var sourceBundleID: String
    public var deviceName: String?
    public var motionContextRaw: Int?

    public init(sample: MetricSample) {
        hkUUID = sample.id
        typeRaw = sample.type.rawValue
        value = sample.value
        start = sample.start
        end = sample.end
        sourceName = sample.sourceName
        sourceBundleID = sample.sourceBundleID
        deviceName = sample.deviceName
        motionContextRaw = sample.motionContext?.rawValue
    }

    /// `nil`, ha a `typeRaw` már nem ismert `MetricType` (pl. régi adat egy törölt típusra).
    public var asMetricSample: MetricSample? {
        guard let type = MetricType(rawValue: typeRaw) else { return nil }
        return MetricSample(
            id: hkUUID, type: type, value: value, start: start, end: end,
            sourceName: sourceName, sourceBundleID: sourceBundleID, deviceName: deviceName,
            motionContext: motionContextRaw.flatMap(MotionContext.init(rawValue:))
        )
    }
}

@Model
public final class StoredDailyStat {
    public var day: Date
    public var typeRaw: String
    public var count: Int
    public var sum: Double?
    public var average: Double?
    public var min: Double?
    public var max: Double?

    public init(stat: DailyStat) {
        day = stat.day
        typeRaw = stat.metric.rawValue
        count = stat.count
        sum = stat.sum
        average = stat.average
        min = stat.min
        max = stat.max
    }
}

@Model
public final class StoredWorkout {
    @Attribute(.unique) public var hkUUID: String
    public var activityTypeRawValue: Int
    public var start: Date
    public var end: Date
    public var duration: TimeInterval
    public var activeEnergyKcal: Double?
    public var distanceMeters: Double?
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?
    public var minHeartRate: Double?
    public var sourceName: String

    public init(workout: WorkoutSummary) {
        hkUUID = workout.id
        activityTypeRawValue = workout.activityTypeRawValue
        start = workout.start
        end = workout.end
        duration = workout.duration
        activeEnergyKcal = workout.activeEnergyKcal
        distanceMeters = workout.distanceMeters
        averageHeartRate = workout.averageHeartRate
        maxHeartRate = workout.maxHeartRate
        minHeartRate = workout.minHeartRate
        sourceName = workout.sourceName
    }
}

@Model
public final class StoredSleepSession {
    /// A "nightOf" napra egyedi (napi egy session).
    @Attribute(.unique) public var nightOf: Date
    /// JSON-kódolt `[SleepSegment]` — nincs SwiftData-relációra szükség egy V0 alvás-listához.
    public var segmentsData: Data
    public var primarySource: String

    public init(session: SleepSession) {
        nightOf = session.nightOf
        primarySource = session.primarySource
        segmentsData = (try? JSONExporter.data(session.segments)) ?? Data()
    }

    public func update(from session: SleepSession) {
        segmentsData = (try? JSONExporter.data(session.segments)) ?? segmentsData
        primarySource = session.primarySource
    }

    public var asSleepSession: SleepSession? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let segments = try? decoder.decode([SleepSegment].self, from: segmentsData) else { return nil }
        return SleepSession(nightOf: nightOf, segments: segments, primarySource: primarySource)
    }
}

@Model
public final class SyncState {
    @Attribute(.unique) public var typeRaw: String
    public var lastRunAt: Date?
    public var lastSampleEnd: Date?

    public init(typeRaw: String) {
        self.typeRaw = typeRaw
    }
}

@Model
public final class SyncLogEntry {
    public var typeRaw: String
    public var syncedAt: Date
    public var newestSampleEnd: Date?
    public var latencySeconds: Double?
    public var newCount: Int
    /// "backfill" | "incremental" | "observer"
    public var trigger: String

    public init(typeRaw: String, syncedAt: Date, newestSampleEnd: Date?, newCount: Int, trigger: String) {
        self.typeRaw = typeRaw
        self.syncedAt = syncedAt
        self.newestSampleEnd = newestSampleEnd
        latencySeconds = newestSampleEnd.map { syncedAt.timeIntervalSince($0) }
        self.newCount = newCount
        self.trigger = trigger
    }
}
