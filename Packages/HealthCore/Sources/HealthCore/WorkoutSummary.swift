import Foundation

/// Egy edzés összesítője (a HealthKit `HKWorkout` normalizált megfelelője).
///
/// Az `activityTypeRawValue` az `HKWorkoutActivityType.rawValue` — a HealthCore nem importál
/// HealthKitet, ezért nyers `Int`-ként tárolja; az App réteg (`WorkoutSummary+HealthKit.swift`)
/// felelős az emberi olvasható névre fordításért.
public struct WorkoutSummary: Equatable, Sendable, Codable, Identifiable {
    public let id: String
    public let activityTypeRawValue: Int
    public let start: Date
    public let end: Date
    public let duration: TimeInterval
    public let activeEnergyKcal: Double?
    public let distanceMeters: Double?
    public let averageHeartRate: Double?
    public let maxHeartRate: Double?
    public let minHeartRate: Double?
    public let sourceName: String

    public init(
        id: String,
        activityTypeRawValue: Int,
        start: Date,
        end: Date,
        duration: TimeInterval,
        activeEnergyKcal: Double? = nil,
        distanceMeters: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        minHeartRate: Double? = nil,
        sourceName: String = ""
    ) {
        self.id = id
        self.activityTypeRawValue = activityTypeRawValue
        self.start = start
        self.end = end
        self.duration = duration
        self.activeEnergyKcal = activeEnergyKcal
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.minHeartRate = minHeartRate
        self.sourceName = sourceName
    }
}
