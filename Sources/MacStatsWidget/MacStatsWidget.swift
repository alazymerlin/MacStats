import WidgetKit
import SwiftUI
import Foundation

// MARK: - 共享数据模型

struct WidgetStats: Codable {
    let cpuUsage: Double
    let memoryPercent: Double
    let memoryUsed: String
    let memoryTotal: String
    let gpuName: String
    let uploadSpeed: String
    let downloadSpeed: String
    let localIP: String
    let publicIP: String
    let diskFree: String
    let diskPercent: Double
    let batteryCycles: Int
    let batteryHealth: Int
    let batteryCharging: Bool
    let hasBattery: Bool
}

// MARK: - Timeline Entry

struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: WidgetStats?
}

// MARK: - 读取共享数据

func readSharedStats() -> WidgetStats? {
    var appCache = FileManager.default.homeDirectoryForCurrentUser
    appCache.appendPathComponent("Library/Caches/com.macstats")
    let url = appCache.appendingPathComponent("stats.json")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(WidgetStats.self, from: data)
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: Date(), stats: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        let entry = StatsEntry(date: Date(), stats: readSharedStats())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let stats = readSharedStats()
        let entry = StatsEntry(date: Date(), stats: stats)
        // Refresh every 5 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget View

struct MacStatsWidgetEntryView: View {
    var entry: StatsEntry

    var body: some View {
        if let s = entry.stats {
            VStack(alignment: .leading, spacing: 3) {
                header
                Divider()
                cpuRow(s: s)
                memRow(s: s)
                diskRow(s: s)
                netRow(s: s)
                if s.hasBattery {
                    battRow(s: s)
                }
            }
            .padding(10)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.title2)
                Text("启动 MacStats 后\n自动显示数据")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(cpuColor)
                .frame(width: 6, height: 6)
            Text("MacStats").font(.system(.caption, weight: .semibold))
            Spacer()
        }
    }

    private var cpuColor: Color {
        guard let s = entry.stats else { return .green }
        return s.cpuUsage > 80 ? .red : s.cpuUsage > 50 ? .yellow : .green
    }

    private func cpuRow(s: WidgetStats) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu").foregroundColor(cpuColor).font(.system(size: 10))
            Text("CPU").font(.system(.caption2, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.1f%%", s.cpuUsage)).font(.system(.caption, design: .monospaced))
        }
    }

    private func memRow(s: WidgetStats) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip").foregroundColor(.cyan).font(.system(size: 10))
            Text("RAM").font(.system(.caption2, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text("\(s.memoryUsed) / \(s.memoryTotal)").font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func diskRow(s: WidgetStats) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive").foregroundColor(.blue).font(.system(size: 10))
            Text("磁盘").font(.system(.caption2, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text(s.diskFree).font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func netRow(s: WidgetStats) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "network").foregroundColor(.blue).font(.system(size: 10))
            Text("网络").font(.system(.caption2, weight: .medium)).foregroundColor(.secondary)
            Spacer()
            Text("↑\(s.downloadSpeed) ↓\(s.uploadSpeed)").font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    private func battRow(s: WidgetStats) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "battery.100").foregroundColor(.green).font(.system(size: 10))
            Text("循环 \(s.batteryCycles)").font(.system(.caption2, design: .monospaced))
            Text("健康 \(s.batteryHealth)%").font(.system(.caption2)).foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Widget

@main
struct MacStatsWidget: Widget {
    let kind: String = "com.macstats.widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MacStatsWidgetEntryView(entry: entry)
                .containerBackground(.thickMaterial, for: .widget)
        }
        .configurationDisplayName("MacStats")
        .description("实时显示 CPU、内存、磁盘、网络和电池信息")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
