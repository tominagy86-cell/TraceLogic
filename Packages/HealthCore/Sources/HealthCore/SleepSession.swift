import Foundation

/// Egy nyers alvás-szegmens (egy HealthKit `HKCategorySample` normalizált megfelelője).
public struct SleepSegment: Equatable, Sendable, Codable {
    public let stage: SleepStage
    public let start: Date
    public let end: Date
    public let sourceName: String
    public let sourceBundleID: String

    public init(stage: SleepStage, start: Date, end: Date, sourceName: String = "", sourceBundleID: String = "") {
        self.stage = stage
        self.start = start
        self.end = end
        self.sourceName = sourceName
        self.sourceBundleID = sourceBundleID
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Egy éjszakára összeálló alvás-szegmensek (lásd `SleepSessionBuilder`).
public struct SleepSession: Equatable, Sendable, Codable, Identifiable {
    /// Az "alvás-nap" kezdete — dél→dél anchor (lásd `SleepSessionBuilder`), nem a tényleges elalvás időpontja.
    public let nightOf: Date
    public let segments: [SleepSegment]
    /// A domináns forrás neve (a legtöbb alvásidőt adó forrás).
    public let primarySource: String

    public init(nightOf: Date, segments: [SleepSegment], primarySource: String) {
        self.nightOf = nightOf
        self.segments = segments
        self.primarySource = primarySource
    }

    public var id: Date { nightOf }

    public var inBedStart: Date? { segments.map(\.start).min() }
    public var inBedEnd: Date? { segments.map(\.end).max() }

    private func totalSeconds(_ stage: SleepStage) -> TimeInterval {
        segments.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }

    public var coreSeconds: TimeInterval { totalSeconds(.asleepCore) }
    public var deepSeconds: TimeInterval { totalSeconds(.asleepDeep) }
    public var remSeconds: TimeInterval { totalSeconds(.asleepREM) }
    public var unspecifiedAsleepSeconds: TimeInterval { totalSeconds(.asleepUnspecified) }
    public var awakeSeconds: TimeInterval { totalSeconds(.awake) }

    public var totalAsleepSeconds: TimeInterval {
        segments.filter { $0.stage.isAsleep }.reduce(0) { $0 + $1.duration }
    }

    /// Van-e részletes fázisbontás (watchOS 9+), vagy csak "alszik valamikor" (`asleepUnspecified`).
    public var hasStageDetail: Bool { coreSeconds > 0 || deepSeconds > 0 || remSeconds > 0 }
}
