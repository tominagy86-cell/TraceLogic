import Foundation

/// A HealthKit `HKCategoryValueSleepAnalysis` platformfüggetlen megfelelője.
public enum SleepStage: String, Sendable, Codable, CaseIterable {
    case inBed
    case awake
    /// Alszik, de a fázis nincs megkülönböztetve (pl. óra nélküli / régebbi mérés).
    case asleepUnspecified
    /// Könnyű/köztes alvás (AASM 1–2. stádium).
    case asleepCore
    case asleepDeep
    case asleepREM

    /// Ténylegesen alvásnak számít-e (szemben az ébren/ágyban léttel).
    public var isAsleep: Bool {
        switch self {
        case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM: return true
        case .inBed, .awake: return false
        }
    }
}
