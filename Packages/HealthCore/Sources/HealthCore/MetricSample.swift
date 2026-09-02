import Foundation

/// Egy normalizált minta — a HealthKit `HKSample` platformfüggetlen megfelelője.
public struct MetricSample: Equatable, Sendable, Codable, Identifiable {
    public let id: String            // HKObject.uuid string, vagy determinisztikus kulcs
    public let type: MetricType
    public let value: Double         // `type.unit`-ban
    public let start: Date
    public let end: Date
    public let sourceName: String
    public let sourceBundleID: String
    public let deviceName: String?
    public let motionContext: MotionContext?

    public init(
        id: String,
        type: MetricType,
        value: Double,
        start: Date,
        end: Date,
        sourceName: String = "",
        sourceBundleID: String = "",
        deviceName: String? = nil,
        motionContext: MotionContext? = nil
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.start = start
        self.end = end
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
        self.deviceName = deviceName
        self.motionContext = motionContext
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
    public var isInstantaneous: Bool { end <= start }
}

/// A `heartRate` mintákhoz tartozó mozgáskontextus (HKMetadataKeyHeartRateMotionContext).
public enum MotionContext: Int, Sendable, Codable {
    case notSet = 0
    case sedentary = 1
    case active = 2
}
