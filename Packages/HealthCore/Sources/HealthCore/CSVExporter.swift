import Foundation

/// CSV export a fő modelltípusokra — offline (Excel/Numbers/pandas) elemzéshez.
/// Minden dátum ISO-8601.
public enum CSVExporter {

    public static func csv(for samples: [MetricSample]) -> String {
        var lines = ["id,type,value,start,end,source_name,source_bundle_id,device,motion_context"]
        let iso = ISO8601DateFormatter()
        for s in samples {
            lines.append(row([
                s.id, s.type.rawValue, String(s.value),
                iso.string(from: s.start), iso.string(from: s.end),
                s.sourceName, s.sourceBundleID, s.deviceName ?? "",
                s.motionContext.map { String($0.rawValue) } ?? "",
            ]))
        }
        return lines.joined(separator: "\n")
    }

    public static func csv(for stats: [DailyStat]) -> String {
        var lines = ["day,metric,count,sum,average,min,max"]
        let iso = ISO8601DateFormatter()
        for stat in stats {
            lines.append(row([
                iso.string(from: stat.day), stat.metric.rawValue, String(stat.count),
                stat.sum.map { String($0) } ?? "", stat.average.map { String($0) } ?? "",
                stat.min.map { String($0) } ?? "", stat.max.map { String($0) } ?? "",
            ]))
        }
        return lines.joined(separator: "\n")
    }

    public static func csv(for sessions: [SleepSession]) -> String {
        var lines = ["night_of,in_bed_start,in_bed_end,total_asleep_min,core_min,deep_min,rem_min,awake_min,primary_source"]
        let iso = ISO8601DateFormatter()
        for s in sessions {
            lines.append(row([
                iso.string(from: s.nightOf),
                s.inBedStart.map(iso.string(from:)) ?? "",
                s.inBedEnd.map(iso.string(from:)) ?? "",
                minutes(s.totalAsleepSeconds), minutes(s.coreSeconds), minutes(s.deepSeconds),
                minutes(s.remSeconds), minutes(s.awakeSeconds), s.primarySource,
            ]))
        }
        return lines.joined(separator: "\n")
    }

    public static func csv(for workouts: [WorkoutSummary]) -> String {
        var lines = ["id,activity_type_raw,start,end,duration_min,active_energy_kcal,distance_m,avg_hr,max_hr,min_hr,source"]
        let iso = ISO8601DateFormatter()
        for w in workouts {
            lines.append(row([
                w.id, String(w.activityTypeRawValue), iso.string(from: w.start), iso.string(from: w.end),
                minutes(w.duration), w.activeEnergyKcal.map { String($0) } ?? "",
                w.distanceMeters.map { String($0) } ?? "", w.averageHeartRate.map { String($0) } ?? "",
                w.maxHeartRate.map { String($0) } ?? "", w.minHeartRate.map { String($0) } ?? "", w.sourceName,
            ]))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - private

    private static func minutes(_ seconds: TimeInterval) -> String {
        String(format: "%.1f", seconds / 60)
    }

    private static func row(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
