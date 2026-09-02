import SwiftUI

// A projekt ideiglenes neve: TraceLogic.
// Átnevezés mindenhol: scripts/rename-project.ps1 -NewName <UjNev>
// (ez a fájl ilyenkor átnevezésre kerül, és a struct neve is változik)

@main
struct TraceLogicApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
