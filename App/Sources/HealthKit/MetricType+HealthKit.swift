import HealthKit
import HealthCore

// HealthKit-leképezés a HealthCore `MetricType`-hoz.
// Ez a fájl (és az egész App/Sources/HealthKit mappa) CSAK iOS-en fordul (kölcsön Mac).
// A HealthCore csomag szándékosan HealthKit-mentes marad.

extension MetricType {

    /// A hozzá tartozó `HKQuantityTypeIdentifier`, ha kvantitatív metrika.
    var hkQuantityIdentifier: HKQuantityTypeIdentifier? {
        switch self {
        case .heartRate:                  return .heartRate
        case .restingHeartRate:           return .restingHeartRate
        case .heartRateVariabilitySDNN:   return .heartRateVariabilitySDNN
        case .walkingHeartRateAverage:    return .walkingHeartRateAverage
        case .heartRateRecoveryOneMinute: return .heartRateRecoveryOneMinute
        case .oxygenSaturation:           return .oxygenSaturation
        case .respiratoryRate:            return .respiratoryRate
        case .vo2Max:                     return .vo2Max
        case .stepCount:                  return .stepCount
        case .distanceWalkingRunning:     return .distanceWalkingRunning
        case .activeEnergyBurned:         return .activeEnergyBurned
        case .basalEnergyBurned:          return .basalEnergyBurned
        case .appleExerciseTime:          return .appleExerciseTime
        case .appleStandTime:             return .appleStandTime
        case .bodyMass:                   return .bodyMass
        case .sleepAnalysis:              return nil
        }
    }

    /// A lekérdezéshez használt `HKSampleType` (kvantitatív vagy kategória).
    var hkSampleType: HKSampleType? {
        if let id = hkQuantityIdentifier { return HKQuantityType(id) }
        if self == .sleepAnalysis { return HKCategoryType(.sleepAnalysis) }
        return nil
    }

    /// Az engedélykéréshez használt `HKObjectType`.
    var hkObjectType: HKObjectType? { hkSampleType }

    /// A `MetricSample.value` ebben a HealthKit unitban van tárolva
    /// (a HealthCore `unit`-tal összhangban). `oxygenSaturation` külön kezelve: ×100 a mappingnél.
    var hkUnit: HKUnit? {
        switch unit {
        case .count:          return .count()
        case .countPerMinute: return HKUnit.count().unitDivided(by: .minute())
        case .millisecond:    return .secondUnit(with: .milli)
        case .percent:        return .percent()
        case .mlPerKgMin:     return HKUnit(from: "ml/kg*min")
        case .meter:          return .meter()
        case .kilocalorie:    return .kilocalorie()
        case .minute:         return .minute()
        case .kilogram:       return .gramUnit(with: .kilo)
        case .none:           return nil
        }
    }
}

enum HealthKitReadSet {

    /// A V0 teljes olvasási halmaza (minden `MetricType` + edzések).
    static var all: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        for metric in MetricType.v0ReadSet {
            if let type = metric.hkObjectType { set.insert(type) }
        }
        set.insert(HKObjectType.workoutType())
        return set
    }

    static func types(for metrics: [MetricType]) -> Set<HKObjectType> {
        Set(metrics.compactMap(\.hkObjectType))
    }
}
