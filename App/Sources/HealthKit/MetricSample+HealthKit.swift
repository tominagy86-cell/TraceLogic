import HealthKit
import HealthCore

extension MetricSample {

    /// HealthKit sample → normalizált `MetricSample`.
    /// Kategória-mintákra (alvás) `nil` — azt a `SleepSessionBuilder` dolgozza fel (phase D).
    init?(hkSample: HKSample, metric: MetricType) {
        guard let quantitySample = hkSample as? HKQuantitySample,
              let unit = metric.hkUnit
        else { return nil }

        var value = quantitySample.quantity.doubleValue(for: unit)
        if metric == .oxygenSaturation { value *= 100 }   // 0–1 tört → 0–100 (%)

        let source = hkSample.sourceRevision.source
        let motion: MotionContext? = {
            guard metric == .heartRate,
                  let raw = (quantitySample.metadata?[HKMetadataKeyHeartRateMotionContext] as? NSNumber)?.intValue
            else { return nil }
            return MotionContext(rawValue: raw)
        }()

        self.init(
            id: hkSample.uuid.uuidString,
            type: metric,
            value: value,
            start: hkSample.startDate,
            end: hkSample.endDate,
            sourceName: source.name,
            sourceBundleID: source.bundleIdentifier,
            deviceName: hkSample.device?.name,
            motionContext: motion
        )
    }
}
