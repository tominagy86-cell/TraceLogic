import SwiftUI
import HealthCore

/// Mintavételi sűrűség vizsgálata — a V0 fő célja: számokkal dokumentálni, mit ad a saját órád.
/// A `docs/metric-findings.md` ebből a képernyőből (és a JSON/CSV exportból) töltendő ki.
struct DataInspectorView: View {
    @State private var model: DataInspectorModel

    init(source: any HealthDataSource) {
        _model = State(initialValue: DataInspectorModel(source: source))
    }

    var body: some View {
        List {
            Section {
                Picker("Metrika", selection: $model.metric) {
                    ForEach(MetricCatalog.all, id: \.type) { info in
                        Text(info.displayName).tag(info.type)
                    }
                }
                Picker("Ablak", selection: $model.window) {
                    ForEach(DataInspectorModel.Window.allCases) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
                .pickerStyle(.segmented)
            }

            if model.isLoading {
                Section { ProgressView() }
            }

            if let stats = model.stats {
                Section("Statisztika") {
                    LabeledContent("Minták", value: "\(stats.sampleCount)")
                    LabeledContent("Lefedettség", value: stats.coverageFraction, format: .percent.precision(.fractionLength(0)))
                    LabeledContent("Minta/óra", value: stats.samplesPerHour, format: .number.precision(.fractionLength(1)))
                    if let median = stats.medianGap { LabeledContent("Medián rés", value: durationLabel(median)) }
                    if let p10 = stats.p10Gap { LabeledContent("p10 rés", value: durationLabel(p10)) }
                    if let p90 = stats.p90Gap { LabeledContent("p90 rés", value: durationLabel(p90)) }
                    if let maxGap = stats.maxGap { LabeledContent("Max rés", value: durationLabel(maxGap)) }
                }

                if !stats.countBySource.isEmpty {
                    Section("Forrás szerint") {
                        ForEach(stats.countBySource.sorted { $0.value > $1.value }, id: \.key) { name, count in
                            LabeledContent(name, value: "\(count)")
                        }
                    }
                }
            }

            Section("Nyers minták (\(model.samples.count), max 200 mutatva)") {
                ForEach(model.samples.prefix(200)) { sample in
                    HStack {
                        Text(sample.start, format: .dateTime.month().day().hour().minute().second())
                        Spacer()
                        Text(sample.value, format: .number.precision(.fractionLength(0...2)))
                            .monospacedDigit()
                        Text(sample.sourceName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Data Inspector")
        .task { await model.load() }
        .refreshable { await model.load() }
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }
}
