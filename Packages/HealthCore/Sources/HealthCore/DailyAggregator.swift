import Foundation

/// `[MetricSample]` → naptári napokra bontott `[DailyStat]`.
///
/// V0 egyszerűsítés: minden minta ahhoz a naphoz tartozik, amelyre a `start`-ja esik
/// (az éjfélen átnyúló mintát nem vágjuk szét). A HealthKit `HKStatisticsCollectionQuery`
/// pontosabb — a valós appban azt is használjuk majd, ez a fallback / tesztelhető referencia.
public enum DailyAggregator {

    /// - Parameters:
    ///   - samples: a metrika mintái (tetszőleges sorrend).
    ///   - metric: a metrika típusa (ez dönti el: `sum` vagy `average`).
    ///   - start: a tartomány kezdete (a nap, amire esik, teljesen bekerül).
    ///   - end: a tartomány vége, **kizárólagos**.
    ///   - calendar: a napokra bontáshoz használt naptár (időzónával).
    /// - Returns: naponként egy `DailyStat`, `start` napjától `end` előtti utolsó napig,
    ///   üres napokra is (`count == 0`).
    public static func aggregate(
        _ samples: [MetricSample],
        metric: MetricType,
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [DailyStat] {
        guard end > start else { return [] }

        // Napok listája: start napjának éjfelétől, amíg < end.
        var days: [Date] = []
        var cursor = calendar.startOfDay(for: start)
        while cursor < end {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }

        // Minták vödrözése a start-juk napja szerint, a [start, end) ablakra szűrve.
        var valuesByDay: [Date: [Double]] = [:]
        for sample in samples where sample.start >= start && sample.start < end {
            let key = calendar.startOfDay(for: sample.start)
            valuesByDay[key, default: []].append(sample.value)
        }

        return days.map { day in
            let values = valuesByDay[day] ?? []
            guard !values.isEmpty else {
                return DailyStat(day: day, metric: metric, count: 0)
            }
            let total = values.reduce(0, +)
            let lo = values.min()
            let hi = values.max()
            switch metric.aggregation {
            case .cumulative:
                return DailyStat(day: day, metric: metric, count: values.count,
                                 sum: total, average: nil, min: lo, max: hi)
            case .discrete, .none:
                return DailyStat(day: day, metric: metric, count: values.count,
                                 sum: nil, average: total / Double(values.count), min: lo, max: hi)
            }
        }
    }
}
