import Foundation

/// Egy metrika napi összesített értéke egy naptári napra.
///
/// - Kumulatív metrikáknál (lépés, energia, edzésperc…) a `sum` a releváns.
/// - Diszkrét metrikáknál (pulzus, HRV, SpO₂…) az `average` / `min` / `max`.
public struct DailyStat: Equatable, Sendable, Codable, Identifiable {
    /// A nap kezdete a megadott naptárban (helyi éjfél).
    public let day: Date
    public let metric: MetricType
    /// Hány minta esett erre a napra.
    public let count: Int
    public let sum: Double?
    public let average: Double?
    public let min: Double?
    public let max: Double?

    public var id: Date { day }
    public var isEmpty: Bool { count == 0 }

    public init(
        day: Date,
        metric: MetricType,
        count: Int,
        sum: Double? = nil,
        average: Double? = nil,
        min: Double? = nil,
        max: Double? = nil
    ) {
        self.day = day
        self.metric = metric
        self.count = count
        self.sum = sum
        self.average = average
        self.min = min
        self.max = max
    }

    /// A nap „reprezentatív" értéke: kumulatívnál az összeg, egyébként az átlag.
    public var primaryValue: Double? {
        switch metric.aggregation {
        case .cumulative: return sum
        case .discrete, .none: return average
        }
    }
}
