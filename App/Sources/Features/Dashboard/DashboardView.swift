import SwiftUI
import HealthCore

struct DashboardView: View {
    @State private var model: DashboardModel
    private let source: any HealthDataSource

    init(source: any HealthDataSource) {
        self.source = source
        _model = State(initialValue: DashboardModel(source: source))
    }

    var body: some View {
        NavigationStack {
            List {
                if model.rows.allSatisfy({ !$0.loaded }) {
                    Section { ProgressView() }
                }

                if !model.withData.isEmpty {
                    Section("Legfrissebb értékek") {
                        ForEach(model.withData) { MetricRow(row: $0) }
                    }
                }

                if !model.withoutData.isEmpty {
                    Section("Nincs adat / nem elérhető") {
                        ForEach(model.withoutData) { row in
                            Text(row.info.displayName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(Branding.appName)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Inspector") {
                        DataInspectorView(source: source)
                    }
                }
            }
            .task { await model.load() }
            .refreshable { await model.load() }
        }
    }
}

private struct MetricRow: View {
    let row: DashboardModel.Row

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.info.displayName)
                if let sample = row.latest {
                    Text(sample.end, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let sample = row.latest {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(formatted(sample.value))
                        .font(.body).monospacedDigit()
                    if !row.info.unitSymbol.isEmpty {
                        Text(row.info.unitSymbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        let fractionDigits = abs(value) >= 100 ? 0 : 1
        return value.formatted(.number.precision(.fractionLength(0...fractionDigits)))
    }
}
