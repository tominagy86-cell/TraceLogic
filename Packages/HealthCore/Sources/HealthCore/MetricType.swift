import Foundation

/// A V0-ban vizsgált egészség-metrikák — HealthKit-független szemantikai leírás.
/// A HKQuantityTypeIdentifier / HKCategoryTypeIdentifier leképezés az App rétegben él
/// (`MetricCatalog+HealthKit`), hogy ez a csomag import-mentes maradjon.
public enum MetricType: String, CaseIterable, Sendable, Codable {

    // Szív
    case heartRate
    case restingHeartRate
    case heartRateVariabilitySDNN
    case walkingHeartRateAverage
    case heartRateRecoveryOneMinute

    // Légzés / oxigén
    case oxygenSaturation
    case respiratoryRate

    // Fittség
    case vo2Max

    // Aktivitás
    case stepCount
    case distanceWalkingRunning
    case activeEnergyBurned
    case basalEnergyBurned
    case appleExerciseTime
    case appleStandTime

    // Test
    case bodyMass

    // Alvás (kategória-típus, külön feldolgozás)
    case sleepAnalysis

    /// A V0 olvasási halmaz (mindent olvasunk).
    public static let v0ReadSet: [MetricType] = MetricType.allCases

    /// Hogyan összegezhető napi bontásban.
    public var aggregation: AggregationKind {
        switch self {
        case .stepCount, .distanceWalkingRunning, .activeEnergyBurned,
             .basalEnergyBurned, .appleExerciseTime, .appleStandTime:
            return .cumulative
        case .sleepAnalysis:
            return .none
        default:
            return .discrete
        }
    }

    public var unit: MetricUnit {
        switch self {
        case .heartRate, .restingHeartRate, .walkingHeartRateAverage,
             .heartRateRecoveryOneMinute, .respiratoryRate:
            return .countPerMinute
        case .heartRateVariabilitySDNN:
            return .millisecond
        case .oxygenSaturation:
            return .percent
        case .vo2Max:
            return .mlPerKgMin
        case .stepCount:
            return .count
        case .distanceWalkingRunning:
            return .meter
        case .activeEnergyBurned, .basalEnergyBurned:
            return .kilocalorie
        case .appleExerciseTime, .appleStandTime:
            return .minute
        case .bodyMass:
            return .kilogram
        case .sleepAnalysis:
            return .none
        }
    }

    /// Természetéből adódóan ritka mintázatú — pár napos hiány nem hiba.
    public var isSparseByNature: Bool {
        switch self {
        case .vo2Max, .heartRateRecoveryOneMinute, .bodyMass:
            return true
        default:
            return false
        }
    }

    public var isCategoryType: Bool { self == .sleepAnalysis }
}

public enum AggregationKind: String, Sendable, Codable {
    case cumulative   // .cumulativeSum
    case discrete     // .discreteAverage / min / max
    case none
}

public enum MetricUnit: String, Sendable, Codable {
    case count
    case countPerMinute
    case millisecond
    case percent
    case mlPerKgMin
    case meter
    case kilocalorie
    case minute
    case kilogram
    case none
}
