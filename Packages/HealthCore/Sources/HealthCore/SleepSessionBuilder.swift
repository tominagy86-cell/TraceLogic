import Foundation

/// Nyers alvás-szegmensek éjszakákká csoportosítása.
public enum SleepSessionBuilder {

    /// - Parameters:
    ///   - segments: tetszőleges sorrendű, akár több forrásból származó szegmensek.
    ///   - preferredSourceBundleID: ha meg van adva, és egy adott éjszakára ad adatot,
    ///     azt az éjszakát **csak** az ő szegmensei alkotják (a többi forrás aznapi adata kimarad —
    ///     ez a "Apple Watch előnyben" dedup, ha átfedő adat jön több forrásból).
    ///     Ha `nil`, vagy arra az éjszakára nincs adata, minden forrás szegmense megmarad.
    ///   - calendar: az "alvás-nap" számításához (időzóna számít).
    /// - Returns: `nightOf` szerint növekvő sorrendben.
    ///
    /// Az "alvás-nap" dél→dél anchor: egy adott naptári nap 12:00-tól a következő nap 12:00-ig tartó
    /// ablak — így egy este elalvó, másnap hajnalban felébredő alvás egyetlen éjszakába esik.
    public static func build(
        from segments: [SleepSegment],
        preferredSourceBundleID: String? = nil,
        calendar: Calendar = .current
    ) -> [SleepSession] {
        guard !segments.isEmpty else { return [] }

        func nightOf(_ date: Date) -> Date {
            calendar.startOfDay(for: date.addingTimeInterval(-12 * 3600))
        }

        var byNight: [Date: [SleepSegment]] = [:]
        for segment in segments {
            byNight[nightOf(segment.start), default: []].append(segment)
        }

        return byNight.map { night, nightSegments in
            var chosen = nightSegments
            if let preferred = preferredSourceBundleID {
                let fromPreferred = nightSegments.filter { $0.sourceBundleID == preferred }
                if !fromPreferred.isEmpty { chosen = fromPreferred }
            }
            chosen.sort { $0.start < $1.start }

            let bySource = Dictionary(grouping: chosen, by: \.sourceName)
            let primary = bySource
                .max { lhs, rhs in
                    lhs.value.reduce(0) { $0 + $1.duration } < rhs.value.reduce(0) { $0 + $1.duration }
                }?.key ?? ""

            return SleepSession(nightOf: night, segments: chosen, primarySource: primary)
        }
        .sorted { $0.nightOf < $1.nightOf }
    }
}
