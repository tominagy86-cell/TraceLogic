import SwiftUI
import HealthCore

/// Belépő nézet: engedélykapu → Dashboard.
/// A `HealthDataSource`-t egyszer hozzuk létre és adjuk tovább.
struct RootView: View {
    private let healthSource: any HealthDataSource

    init(healthSource: any HealthDataSource = HealthKitAdapter()) {
        self.healthSource = healthSource
    }

    var body: some View {
        PermissionGateView(source: healthSource) {
            DashboardView(source: healthSource)
        }
    }
}

#Preview {
    // Preview-hoz memóriában lévő forrás (nem HealthKit).
    RootView(healthSource: PreviewData.source)
}

private enum PreviewData {
    static let source: any HealthDataSource = {
        let src = InMemoryHealthDataSource(authorized: Set(MetricType.v0ReadSet))
        let now = Date()
        Task {
            await src.setSamples(
                [MetricSample(id: "hr", type: .heartRate, value: 61,
                              start: now.addingTimeInterval(-3600), end: now.addingTimeInterval(-3600),
                              sourceName: "Apple Watch")],
                for: .heartRate
            )
            await src.setSamples(
                [MetricSample(id: "steps", type: .stepCount, value: 8423,
                              start: now.addingTimeInterval(-1800), end: now.addingTimeInterval(-1800),
                              sourceName: "iPhone")],
                for: .stepCount
            )
        }
        return src
    }()
}
