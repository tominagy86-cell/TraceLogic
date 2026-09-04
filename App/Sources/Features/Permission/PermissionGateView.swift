import SwiftUI
import HealthCore

@MainActor
@Observable
final class PermissionGateModel {
    enum Phase: Equatable { case checking, needsPermission, ready, unavailable }

    private(set) var phase: Phase = .checking
    private let source: any HealthDataSource

    init(source: any HealthDataSource) { self.source = source }

    func check() async {
        guard source.isAvailable else { phase = .unavailable; return }
        let status = await source.authorizationRequestStatus(for: MetricType.v0ReadSet)
        phase = (status == .unnecessary) ? .ready : .needsPermission
    }

    func requestAccess() async {
        // iOS: olvasásnál nem derül ki, engedélyezték-e vagy megtagadták. Bármi is történt,
        // továbbengedünk — a Dashboard kezeli a "nincs adat" állapotot metrikánként.
        try? await source.requestAuthorization(for: MetricType.v0ReadSet)
        phase = .ready
    }
}

/// Engedélykapu: amíg nincs Health-hozzáférés kérve, ezt mutatja; utána a `content`-et.
struct PermissionGateView<Content: View>: View {
    @State private var model: PermissionGateModel
    private let content: () -> Content

    init(source: any HealthDataSource, @ViewBuilder content: @escaping () -> Content) {
        _model = State(initialValue: PermissionGateModel(source: source))
        self.content = content
    }

    var body: some View {
        switch model.phase {
        case .checking:
            ProgressView("Ellenőrzés…")
                .task { await model.check() }

        case .unavailable:
            ContentUnavailableView(
                "Nincs egészségadat",
                systemImage: "heart.slash",
                description: Text("Ez az eszköz nem támogatja a HealthKitet.")
            )

        case .needsPermission:
            VStack(spacing: 16) {
                Image(systemName: "heart.text.square")
                    .font(.system(size: 48))
                    .foregroundStyle(.pink)
                Text("\(Branding.appName) a Health adataidból épít személyes baseline-t")
                    .font(.title3).bold()
                    .multilineTextAlignment(.center)
                Text("Az adatok az eszközödön maradnak.")
                    .foregroundStyle(.secondary)
                Button("Csatlakozás az Apple Health-hez") {
                    Task { await model.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(32)

        case .ready:
            content()
        }
    }
}
