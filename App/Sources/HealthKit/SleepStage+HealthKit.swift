import HealthKit
import HealthCore

extension SleepStage {
    /// `HKCategoryValueSleepAnalysis.rawValue` → `SleepStage`. `nil`, ha ismeretlen érték.
    ///
    /// FIGYELEM (Mac build): ha a fordító "switch must be exhaustive" hibát ad a régi,
    /// deprecated `.asleep` esetre, egészítsd ki: `case .asleep: self = .asleepUnspecified`.
    /// Windows-on nem ellenőrizhető, melyik SDK-verzióban van jelen külön case-ként.
    init?(hkValue: Int) {
        guard let value = HKCategoryValueSleepAnalysis(rawValue: hkValue) else { return nil }
        switch value {
        case .inBed:             self = .inBed
        case .awake:              self = .awake
        case .asleepUnspecified: self = .asleepUnspecified
        case .asleepCore:        self = .asleepCore
        case .asleepDeep:        self = .asleepDeep
        case .asleepREM:         self = .asleepREM
        @unknown default:        return nil
        }
    }
}
