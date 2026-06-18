import SwiftUI
import AppKit

@main
struct MacStatsApp: App {
    @StateObject private var monitor = SystemMonitor()
    @AppStorage("showMenuBarPercent") private var showMenuBarPercent = false

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(monitor: monitor,
                             showMenuBarPercent: $showMenuBarPercent)
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "cpu")
                if showMenuBarPercent {
                    Text(monitor.cpuUsageFormatted)
                        .font(.system(size: 11, weight: .medium))
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - 菜单栏弹出面板

struct MenuBarContentView: View {
    @ObservedObject var monitor: SystemMonitor
    @Binding var showMenuBarPercent: Bool
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            // 标题
            HStack {
                Circle()
                    .fill(cpuIndicator)
                    .frame(width: 8, height: 8)
                Text("MacStats").font(.headline)
                Spacer()
            }

            Divider()

            // CPU
            StatRow(icon: "cpu", label: "CPU", value: monitor.cpuUsageFormatted,
                    progress: monitor.cpuUsage / 100.0,
                    color: cpuIndicator)

            // 内存
            StatRow(icon: "memorychip", label: "内存", value: monitor.memoryFormatted,
                    progress: monitor.memory.percent / 100.0,
                    color: monitor.memory.percent >= 85 ? .red : monitor.memory.percent >= 70 ? .yellow : .green)

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

            // 设置 & 退出
            VStack(spacing: 8) {
                if showSettings {
                    VStack(spacing: 4) {
                        Toggle("菜单栏显示 CPU 百分比", isOn: $showMenuBarPercent)
                            .toggleStyle(.switch)
                            .font(.subheadline)
                        VStack(spacing: 2) {
                            Text("更新频率: 每 2 秒").font(.caption2).foregroundColor(.secondary)
                            Text("公网 IP 刷新: 每 2 分钟").font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.5))
                    )
                    
                }

                HStack {
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
        .frame(width: 320)
    }

    private var cpuIndicator: Color {
        monitor.cpuUsage > 80 ? .red : monitor.cpuUsage > 50 ? .yellow : .green
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
