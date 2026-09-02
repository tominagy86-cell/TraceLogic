import Foundation

/// Egy metrika tényleges mintavételi sűrűségének jellemzése egy időablakon.
/// A V0 fő kérdésére válaszol: „mit ad valójában a saját órám?"
public struct GapStats: Equatable, Sendable, Codable {
    public let sampleCount: Int
    public let windowDuration: TimeInterval
    public let coveredDuration: TimeInterval
    /// Rések másodpercben, növekvő sorrendben. Tartalmazza a vezető és záró rést is.
    public let gaps: [TimeInterval]
    public let medianGap: TimeInterval?
    public let p10Gap: TimeInterval?
    public let p90Gap: TimeInterval?
    public let maxGap: TimeInterval?
    /// Forrásonkénti mintaszám (pl. "Apple Watch" vs "iPhone" vs 3rd party).
    public let countBySource: [String: Int]

    public var coverageFraction: Double {
        windowDuration > 0 ? coveredDuration / windowDuration : 0
    }
    public var samplesPerHour: Double {
        windowDuration > 0 ? Double(sampleCount) / (windowDuration / 3600) : 0
    }
}

public enum SampleGapAnalyzer {

    public static func analyze(
        samples: [MetricSample],
        window: DateInterval
    ) -> GapStats {
        let windowDuration = window.duration

        // 1. ablakra vágott, nem-üres intervallumok, kezdet szerint rendezve
        let clipped: [(start: Date, end: Date)] = samples
            .compactMap { s in
                let start = max(s.start, window.start)
                let end = min(max(s.end, s.start), window.end)
                guard end > start || (end == start && s.isInstantaneous) else {
                    // pillanatszerű minta az ablakon belül: nulla hosszú, de létező esemény
                    if s.start >= window.start && s.start <= window.end {
                        return (s.start, s.start)
                    }
                    return nil
                }
                return (start, end)
            }
            .sorted { $0.start < $1.start }

        // 2. átfedő intervallumok összevonása
        var merged: [(start: Date, end: Date)] = []
        for iv in clipped {
            if let last = merged.last, iv.start <= last.end {
                if iv.end > last.end {
                    merged[merged.count - 1].end = iv.end
                }
            } else {
                merged.append(iv)
            }
        }

        let covered = merged.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }

        // 3. rések: vezető + intervallumok közti + záró
        var gaps: [TimeInterval] = []
        if merged.isEmpty {
            gaps = [windowDuration]
        } else {
            let leading = merged[0].start.timeIntervalSince(window.start)
            if leading > 0 { gaps.append(leading) }
            for i in 1..<merged.count {
                let g = merged[i].start.timeIntervalSince(merged[i - 1].end)
                if g > 0 { gaps.append(g) }
            }
            let trailing = window.end.timeIntervalSince(merged[merged.count - 1].end)
            if trailing > 0 { gaps.append(trailing) }
        }
        gaps.sort()

        // 4. forrásbontás
        var countBySource: [String: Int] = [:]
        for s in samples {
            let lo = min(s.start, s.end)
            let hi = max(s.start, s.end)
            guard lo <= window.end && hi >= window.start else { continue }
            let key = s.sourceName.isEmpty ? "(ismeretlen)" : s.sourceName
            countBySource[key, default: 0] += 1
        }

        return GapStats(
            sampleCount: countBySource.values.reduce(0, +),
            windowDuration: windowDuration,
            coveredDuration: covered,
            gaps: gaps,
            medianGap: percentile(gaps, 0.5),
            p10Gap: percentile(gaps, 0.10),
            p90Gap: percentile(gaps, 0.90),
            maxGap: gaps.last,
            countBySource: countBySource
        )
    }

    /// Lineárisan interpolált percentilis egy növekvően rendezett tömbön.
    static func percentile(_ sorted: [TimeInterval], _ p: Double) -> TimeInterval? {
        guard !sorted.isEmpty else { return nil }
        guard sorted.count > 1 else { return sorted[0] }
        let rank = p * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        let frac = rank - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * frac
    }
}
