import Foundation

/// Platformfüggetlen absztrakció az egészségadat-forrás fölött.
/// Az iOS app egy `HealthKitAdapter` (actor) implementációt ad rá `HKHealthStore`-ral;
/// a tesztek és a SwiftUI preview-k az `InMemoryHealthDataSource`-t használják.
/// Későbbi platformok (Health Connect, Garmin…) ugyanezt a protokollt implementálják.
public protocol HealthDataSource: Sendable {

    /// Elérhető-e egyáltalán egészségadat ezen az eszközön (iPaden pl. nem).
    var isAvailable: Bool { get }

    /// Olvasási engedély kérése a megadott metrikákra. Akkor tér vissza, amikor a
    /// felhasználó válaszolt (vagy azonnal, ha már döntött).
    ///
    /// FONTOS (iOS): olvasásnál a rendszer **nem árulja el**, hogy engedélyezve van-e
    /// vagy megtagadva. Üres lekérdezési eredmény = „nincs adat VAGY megtagadva".
    func requestAuthorization(for metrics: [MetricType]) async throws

    /// Kell-e még engedélykérő promptot mutatni ezekre a metrikákra.
    func authorizationRequestStatus(for metrics: [MetricType]) async -> AuthorizationRequestStatus

    /// A metrika legfrissebb mintája, vagy `nil` ha nincs.
    func latestSample(for metric: MetricType) async throws -> MetricSample?

    /// A metrika összes mintája a `[start, end)` félig nyílt intervallumban,
    /// `start` szerint növekvő sorrendben.
    func samples(for metric: MetricType, from start: Date, to end: Date) async throws -> [MetricSample]

    /// Napi statisztikák a metrikára a `[start, end)` tartományon, naptári naponként
    /// egy elem (üres napokra is, `count == 0`).
    func dailyStats(
        for metric: MetricType,
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) async throws -> [DailyStat]

    /// Alvás-éjszakák (`SleepSessionBuilder`-rel összeállítva) a `[start, end)` tartományon.
    func sleepSessions(from start: Date, to end: Date, calendar: Calendar) async throws -> [SleepSession]

    /// Edzések a `[start, end)` tartományon, `start` szerint csökkenő sorrendben (legutóbbi elöl).
    func workouts(from start: Date, to end: Date) async throws -> [WorkoutSummary]
}

public extension HealthDataSource {
    /// Kényelmi overloadok az alapértelmezett naptárral.
    func dailyStats(for metric: MetricType, from start: Date, to end: Date) async throws -> [DailyStat] {
        try await dailyStats(for: metric, from: start, to: end, calendar: .current)
    }

    func sleepSessions(from start: Date, to end: Date) async throws -> [SleepSession] {
        try await sleepSessions(from: start, to: end, calendar: .current)
    }
}

/// A HealthKit `HKAuthorizationRequestStatus` platformfüggetlen megfelelője.
public enum AuthorizationRequestStatus: String, Sendable, Codable {
    /// Nem eldönthető (általában: még nem kértünk engedélyt).
    case unknown
    /// Érdemes megjeleníteni az engedélykérő promptot.
    case shouldRequest
    /// Nincs szükség promptra (már minden kért típusra döntött a felhasználó).
    case unnecessary
}

public enum HealthDataError: Error, Equatable, Sendable {
    /// Az eszköz nem támogat egészségadatot.
    case notAvailable
    /// Az engedélykérés meghiúsult.
    case authorizationFailed(String)
    /// A lekérdezés hibára futott.
    case queryFailed(String)
    /// A metrika nem kérdezhető le ezzel a hívással (pl. kategória-típus sample-lekérdezéssel).
    case unsupportedMetric(MetricType)
}
