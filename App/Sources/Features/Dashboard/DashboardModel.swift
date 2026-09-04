import SwiftUI
import HealthCore

@MainActor
@Observable
final class DashboardModel {

    struct Row: Identifiable {
        let info: MetricInfo
        var latest: MetricSample?
        var loaded = false
        var id: MetricType { info.type }
    }

    private(set) var rows: [Row]
    private(set) var isLoading = false
    private let source: any HealthDataSource

    init(source: any HealthDataSource) {
        self.source = source
        self.rows = MetricCatalog.all.map { Row(info: $0) }
    }

    /// Metrikák, amelyekre van friss minta.
    var withData: [Row] { rows.filter { $0.latest != nil } }
    /// Metrikák adat nélkül (megtagadva / nincs / nem elérhető ezen az eszközön).
    var withoutData: [Row] { rows.filter { $0.loaded && $0.latest == nil } }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let results = await withTaskGroup(of: (MetricType, MetricSample?).self) { group in
            for row in rows {
                let metric = row.info.type
                group.addTask { [source] in
                    (metric, try? await source.latestSample(for: metric))
                }
            }
            var acc: [MetricType: MetricSample?] = [:]
            for await (metric, sample) in group { acc[metric] = sample }
            return acc
        }

        for index in rows.indices {
            rows[index].latest = results[rows[index].id] ?? nil
            rows[index].loaded = true
        }
    }
}
