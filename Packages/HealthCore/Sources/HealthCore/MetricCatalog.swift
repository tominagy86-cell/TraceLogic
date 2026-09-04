import Foundation

/// Megjelenítési metaadat egy metrikához (nyelvfüggetlen kulcsok helyett most egyszerű
/// angol nevek — lokalizáció később a app rétegben).
public struct MetricInfo: Equatable, Sendable {
    public let type: MetricType
    public let displayName: String
    public let unitSymbol: String
    /// Dashboard-sorrend (kisebb = előrébb).
    public let sortOrder: Int
    public let isCategory: Bool
    /// Természeténél fogva ritka (pár napos hiány nem hiba) — az UI ne jelezze „elavultként".
    public let isSparse: Bool
}

public extension MetricUnit {
    /// Rövid, kijelzésre szánt mértékegység-jel.
    var symbol: String {
        switch self {
        case .count:          return ""
        case .countPerMinute: return "bpm"
        case .millisecond:    return "ms"
        case .percent:        return "%"
        case .mlPerKgMin:     return "mL/kg·min"
        case .meter:          return "m"
        case .kilocalorie:    return "kcal"
        case .minute:         return "min"
        case .kilogram:       return "kg"
        case .none:           return ""
        }
    }
}

public enum MetricCatalog {

    /// Minden metrika megjelenítési infója, `sortOrder` szerint rendezve.
    public static let all: [MetricInfo] = MetricType.allCases
        .map(info(for:))
        .sorted { $0.sortOrder < $1.sortOrder }

    public static func info(for type: MetricType) -> MetricInfo {
        MetricInfo(
            type: type,
            displayName: displayName(for: type),
            unitSymbol: unitSymbol(for: type),
            sortOrder: sortOrder(for: type),
            isCategory: type.isCategoryType,
            isSparse: type.isSparseByNature
        )
    }

    private static func unitSymbol(for type: MetricType) -> String {
        switch type {
        case .respiratoryRate: return "br/min"      // légvétel/perc, nem "bpm"
        default:               return type.unit.symbol
        }
    }

    private static func displayName(for type: MetricType) -> String {
        switch type {
        case .heartRate:                 return "Heart Rate"
        case .restingHeartRate:          return "Resting Heart Rate"
        case .heartRateVariabilitySDNN:  return "HRV (SDNN)"
        case .walkingHeartRateAverage:   return "Walking Heart Rate Avg"
        case .heartRateRecoveryOneMinute:return "Cardio Recovery (1 min)"
        case .oxygenSaturation:          return "Blood Oxygen"
        case .respiratoryRate:           return "Respiratory Rate"
        case .vo2Max:                    return "VO₂ Max"
        case .stepCount:                 return "Steps"
        case .distanceWalkingRunning:    return "Walking + Running Distance"
        case .activeEnergyBurned:        return "Active Energy"
        case .basalEnergyBurned:         return "Resting Energy"
        case .appleExerciseTime:         return "Exercise Minutes"
        case .appleStandTime:            return "Stand Minutes"
        case .bodyMass:                  return "Weight"
        case .sleepAnalysis:             return "Sleep"
        }
    }

    private static func sortOrder(for type: MetricType) -> Int {
        switch type {
        // Szív / keringés
        case .heartRate:                  return 0
        case .restingHeartRate:           return 1
        case .heartRateVariabilitySDNN:   return 2
        case .walkingHeartRateAverage:    return 3
        case .heartRateRecoveryOneMinute: return 4
        case .vo2Max:                     return 5
        // Légzés
        case .respiratoryRate:            return 10
        case .oxygenSaturation:           return 11
        // Alvás
        case .sleepAnalysis:              return 20
        // Aktivitás
        case .stepCount:                  return 30
        case .distanceWalkingRunning:     return 31
        case .activeEnergyBurned:         return 32
        case .basalEnergyBurned:          return 33
        case .appleExerciseTime:          return 34
        case .appleStandTime:             return 35
        // Test
        case .bodyMass:                   return 40
        }
    }
}
