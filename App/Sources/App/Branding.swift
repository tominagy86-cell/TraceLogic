import Foundation

/// Az alkalmazás megjelenített neve egy helyen.
/// A végleges név még nincs meg — addig `TraceLogic`.
/// Változtatás: `scripts/rename-project.ps1 -NewName <UjNev>` (ne csak itt írd át).
public enum Branding {
    public static let appName = "TraceLogic"
    public static let bundleIdPrefix = "com.tracelogic"
}
