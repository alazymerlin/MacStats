import SwiftUI
import AppKit

@main
struct MacStatsApp: App {
    @StateObject private var monitor = SystemMonitor()
    @AppStorage("showMenuBarPercent") private var showMenuBarPercent = false
    @AppStorage("menuBarIcon") private var menuBarIcon: String = "cpu"
    @AppStorage("refreshInterval") private var refreshInterval: Double = 2.0

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(monitor: monitor,
                             showMenuBarPercent: $showMenuBarPercent,
                             menuBarIcon: $menuBarIcon,
                             refreshInterval: $refreshInterval)
        } label: {
            HStack(spacing: 2) {
                switch menuBarIcon {
                case "cpu":
                    Image(systemName: "cpu")
                    if showMenuBarPercent {
                        Text(monitor.cpuUsageFormatted)
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                    }
                case "memory":
                    Image(systemName: "memorychip")
                    Text(monitor.memoryPercentFormatted)
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                case "network":
                    Image(systemName: "network")
                    Text(monitor.networkCompactFormatted)
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                default:
                    Image(systemName: "cpu")
                }
            }
        }
        .menuBarExtraStyle(.window)
        .onChange(of: refreshInterval) { _, newValue in
            monitor.updateRefreshInterval(newValue)
        }
    }
}

// MARK: - 菜单栏弹出面板

struct MenuBarContentView: View {
    @ObservedObject var monitor: SystemMonitor
    @Binding var showMenuBarPercent: Bool
    @Binding var menuBarIcon: String
    @Binding var refreshInterval: Double
    @State private var showSettings = false
    @State private var showProcesses = false

    var body: some View {
        VStack(spacing: 10) {
            // 标题
            HStack {
                Circle()
                    .fill(cpuIndicator)
                    .frame(width: 8, height: 8)
                Text("MacStats").font(.headline)
                Spacer()
                Text(refreshIntervalText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Divider()

            // CPU + Sparkline
            StatRow(icon: "cpu", label: "CPU", value: monitor.cpuUsageFormatted,
                    progress: monitor.cpuUsage / 100.0,
                    color: cpuIndicator)
            SparklineView(values: monitor.cpuHistory, threshold: 80, color: cpuIndicator)
                .padding(.leading, 56)
                .frame(height: 30)

            // 内存 + Sparkline
            StatRow(icon: "memorychip", label: "内存", value: monitor.memoryFormatted,
                    progress: monitor.memory.percent / 100.0,
                    color: monitor.memory.percent >= 85 ? .red : monitor.memory.percent >= 70 ? .yellow : .green)
            SparklineView(values: monitor.memoryHistory, threshold: 85, color: monitor.memory.percent >= 85 ? .red : monitor.memory.percent >= 70 ? .yellow : .green)
                .padding(.leading, 56)
                .frame(height: 24)

            // GPU
            StatRow(icon: "display", label: "GPU", value: monitor.gpu.name,
                    progress: nil, color: .blue)

            // 网络
            HStack(spacing: 0) {
                Image(systemName: "network").frame(width: 20).foregroundColor(.blue)
                Text("网络").font(.subheadline).frame(width: 36, alignment: .leading)
                Text(monitor.networkFormatted)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 2)

            // IP
            HStack(spacing: 0) {
                Image(systemName: "globe").frame(width: 20).foregroundColor(.blue)
                Text("IP").font(.subheadline).frame(width: 36, alignment: .leading)
                VStack(alignment: .leading, spacing: 1) {
                    Text("内网: \(monitor.localIP)")
                        .font(.system(.caption, design: .monospaced))
                    Text("公网: \(monitor.publicIP)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 2)

            // 磁盘
            StatRow(icon: "internaldrive", label: "磁盘", value: monitor.diskFormatted,
                    progress: monitor.disk.usedPercent / 100.0,
                    color: monitor.disk.usedPercent >= 90 ? .red : monitor.disk.usedPercent >= 75 ? .yellow : .green)

            Divider()

            // 电池
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    Image(systemName: "battery.100").frame(width: 20).foregroundColor(.green)
                    Text("电池").font(.subheadline).frame(width: 36, alignment: .leading)
                    Text(monitor.batterySummary).font(.subheadline)
                    Spacer()
                }
                if monitor.hasBattery {
                    ProgressView(value: Double(monitor.battery.capacityPercent) / 100.0)
                        .tint(monitor.battery.capacityPercent <= 20 ? .red : monitor.battery.capacityPercent <= 50 ? .yellow : .green)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.vertical, 2)

            Divider()

            // ---- 进程列表 ----
            if showProcesses {
                VStack(spacing: 0) {
                    HStack {
                        Text("进程 (CPU)")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Text("内存")
                            .font(.caption).foregroundColor(.secondary)
                            .frame(width: 60, alignment: .trailing)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)

                    ForEach(monitor.topProcesses) { proc in
                        HStack(spacing: 4) {
                            Text(proc.name)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Text(proc.cpuFormatted)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(cpuColor(for: proc.cpuUsage))
                                .frame(width: 48, alignment: .trailing)
                            Text(proc.memoryFormatted)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .trailing)
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
                )
            }

            // ---- 设置 & 退出 ----
            VStack(spacing: 8) {
                if showSettings {
                    settingsPanel
                }

                HStack {
                    Button("进程") {
                        showProcesses.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundColor(showProcesses ? .orange : .blue)

                    Button(showSettings ? "收起设置 ▲" : "设置 ▼") {
                        showSettings.toggle()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundColor(.blue)

                    Spacer()

                    Button("退出") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: - 设置面板

    private var settingsPanel: some View {
        VStack(spacing: 8) {
            // 菜单栏图标
            HStack {
                Text("菜单栏图标").font(.subheadline)
                Spacer()
                Picker("", selection: $menuBarIcon) {
                    Text("CPU").tag("cpu")
                    Text("内存").tag("memory")
                    Text("网络").tag("network")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 120)
            }

            Divider()

            // 菜单栏显示 CPU 百分比
            Toggle("菜单栏显示 CPU 百分比", isOn: $showMenuBarPercent)
                .toggleStyle(.switch)
                .font(.subheadline)

            Divider()

            // 刷新间隔
            HStack {
                Text("刷新间隔").font(.subheadline)
                Spacer()
                Text("\(String(format: "%.1f", refreshInterval)) 秒")
                    .font(.subheadline.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Slider(value: $refreshInterval, in: 0.5...10.0, step: 0.5) {
                Text("刷新间隔")
            } minimumValueLabel: {
                Text("0.5s").font(.caption2)
            } maximumValueLabel: {
                Text("10s").font(.caption2)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        )
    }

    // MARK: - Helpers

    private var cpuIndicator: Color {
        monitor.cpuUsage > 80 ? .red : monitor.cpuUsage > 50 ? .yellow : .green
    }

    private func cpuColor(for usage: Double) -> Color {
        usage > 50 ? .red : usage > 20 ? .orange : .secondary
    }

    private var refreshIntervalText: String {
        "每 \(String(format: "%.1f", refreshInterval))s"
    }
}

// MARK: - Sparkline View

struct SparklineView: View {
    let values: [Double]
    let threshold: Double
    var color: Color = .blue

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2 {
                let h = geo.size.height
                let w = geo.size.width
                let stepX = w / CGFloat(values.count - 1)
                let currentVal = values.last ?? 0
                let maxVal = values.max() ?? 0

                ZStack(alignment: .topTrailing) {

                    // ---- 警戒线 ----
                    let thresholdY = h * (1 - CGFloat(threshold / 100))
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: thresholdY))
                        path.addLine(to: CGPoint(x: w, y: thresholdY))
                    }
                    .stroke(color.opacity(0.3), style: .init(lineWidth: 1, dash: [3, 3]))

                    // ---- 填充 ----
                    Path { path in
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h * (1 - CGFloat(min(v, 100) / 100))
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.1))

                    // ---- 折线 ----
                    Path { path in
                        for (i, v) in values.enumerated() {
                            let x = CGFloat(i) * stepX
                            let y = h * (1 - CGFloat(min(v, 100) / 100))
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(color, lineWidth: 1.5)

                    // ---- 数字标签 ----
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(String(format: "%.0f", currentVal))%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(color)
                        Text("↑\(String(format: "%.0f", maxVal))%")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(color.opacity(0.6))
                    }
                    .offset(x: -2, y: 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 单行统计组件

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let progress: Double?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Image(systemName: icon).frame(width: 20).foregroundColor(color)
                Text(label).font(.subheadline).frame(width: 36, alignment: .leading)
                Text(value)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
            }
            if let p = progress {
                ProgressView(value: min(max(p, 0.001), 1))
                    .tint(color)
                    .padding(.leading, 60)
            }
        }
        .padding(.vertical, 2)
    }
}
