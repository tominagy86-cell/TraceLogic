import SwiftUI
import HealthCore

@MainActor
@Observable
final class DataInspectorModel {

    enum Window: String, CaseIterable, Identifiable {
        case day = "1 nap", week = "7 nap", month = "28 nap"
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 28
            }
        }
    }

    var metric: MetricType = .heartRate { didSet { reload() } }
    var window: Window = .week { didSet { reload() } }

    private(set) var stats: GapStats?
    private(set) var samples: [MetricSample] = []
    private(set) var isLoading = false

    private let source: any HealthDataSource

    init(source: any HealthDataSource) {
        self.source = source
    }

    func reload() {
        Task { await load() }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        let end = Date()
        guard let start = Calendar.current.date(byAdding: .day, value: -window.days, to: end) else { return }

        let fetched = (try? await source.samples(for: metric, from: start, to: end)) ?? []
        samples = fetched.sorted { $0.start > $1.start }
        stats = SampleGapAnalyzer.analyze(samples: fetched, window: DateInterval(start: start, end: end))
    }
}
