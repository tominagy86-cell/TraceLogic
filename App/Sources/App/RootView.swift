import SwiftUI
import HealthCore

/// Ideiglenes belépő képernyő. A V0-ban ebből lesz a PermissionGate → Dashboard.
struct RootView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Projekt") {
                    LabeledContent("Név", value: Branding.appName)
                    LabeledContent("HealthCore", value: "v\(HealthCore.version)")
                    LabeledContent("V0 metrikák", value: "\(MetricType.v0ReadSet.count)")
                }
                Section("Következő lépés") {
                    Text("PermissionGate + HealthKitAdapter (lásd docs/v0-plan.md, B fázis).")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(Branding.appName)
        }
    }
}

#Preview {
    RootView()
}
